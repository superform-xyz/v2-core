// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import "forge-std/console2.sol";

// Superform
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { MinimalBaseIntegrationTest } from "./MinimalBaseIntegrationTest.t.sol";
import { MockDex } from "../mocks/MockDex.sol";
import { MockDexHook } from "../mocks/MockDexHook.sol";
import { ISuperNativePaymaster } from "../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperNativePaymaster } from "../../src/paymaster/SuperNativePaymaster.sol";

contract MockDexHookIntegrationTest is MinimalBaseIntegrationTest {
    MockDex public mockDex;
    MockDexHook public mockDexHook;
    ISuperNativePaymaster public superNativePaymaster;

    uint256 public swapAmount;
    uint256 public expectedOutput;

    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();

        // Deploy MockDex
        mockDex = new MockDex();

        // Deploy MockDexHook with MockDex address
        mockDexHook = new MockDexHook(address(mockDex));

        // Deploy SuperNativePaymaster
        superNativePaymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));

        swapAmount = 1_000_000; // 1 USDC
        expectedOutput = 2_000_000; // 2 USDC worth of WBTC (mock rate)

        // Get some test tokens for the account
        _getTokens(CHAIN_1_USDC, accountEth, 10_000_000); // 10 USDC
        _getTokens(CHAIN_1_WBTC, accountEth, 1e8); // 1 WBTC

        // Add high liquidity to MockDex for testing using deal
        deal(CHAIN_1_USDC, address(mockDex), 1_000_000_000_000); // 1M USDC
        deal(CHAIN_1_WBTC, address(mockDex), 1000e8); // 1000 WBTC

        // Pre-approve MockDex to spend tokens from the account
        vm.prank(accountEth);
        IERC20(CHAIN_1_USDC).approve(address(mockDex), type(uint256).max);
        vm.prank(accountEth);
        IERC20(CHAIN_1_WBTC).approve(address(mockDex), type(uint256).max);
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                      TESTS
    //////////////////////////////////////////////////////////////*/
    function test_MockDexHook_BasicSwap_USDC_to_WBTC() external {
        console2.log("=== MockDexHook Basic Swap Test: USDC to WBTC ===");

        address inputToken = CHAIN_1_USDC;
        address outputToken = CHAIN_1_WBTC;

        // Log initial balances
        uint256 usdcBefore = IERC20(inputToken).balanceOf(accountEth);
        uint256 wbtcBefore = IERC20(outputToken).balanceOf(accountEth);

        console2.log("Initial Balances:");
        console2.log("  USDC:", usdcBefore);
        console2.log("  WBTC:", wbtcBefore);

        // Create hook data for swapping USDC to WBTC
        bytes memory hookData = mockDexHook.createSwapData(
            inputToken,
            swapAmount,
            outputToken,
            expectedOutput,
            false // don't use prev hook amount
        );

        // Setup hook execution
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(mockDexHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = hookData;

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        // Execute the swap operation
        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);

        // Get post-execution balances
        uint256 usdcAfter = IERC20(inputToken).balanceOf(accountEth);
        uint256 wbtcAfter = IERC20(outputToken).balanceOf(accountEth);

        console2.log("Post-Execution Balances:");
        console2.log("  USDC:", usdcAfter);
        console2.log("  WBTC:", wbtcAfter);

        // Verify the swap worked correctly
        assertEq(usdcBefore - usdcAfter, swapAmount, "USDC input amount should match");
        assertEq(wbtcAfter - wbtcBefore, expectedOutput, "WBTC output amount should match");
    }

    function test_MockDexHook_SwapWithPrevHookAmount() external view {
        console2.log("=== MockDexHook Swap with Previous Hook Amount ===");

        address inputToken = CHAIN_1_USDC;
        address outputToken = CHAIN_1_WBTC;
        uint256 prevHookOutput = 500_000; // 0.5 USDC

        // Create a simple approve hook first to simulate previous hook output
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = address(0x1); // Mock previous hook address (for simulation)
        hooksAddresses[1] = address(mockDexHook);

        bytes[] memory hooksData = new bytes[](2);
        // First hook data (mock - won't actually execute)
        hooksData[0] = "";

        // Second hook data - uses previous hook amount
        hooksData[1] = mockDexHook.createSwapData(
            inputToken,
            0, // Amount will be overridden by prevHook amount
            outputToken,
            prevHookOutput, // Expected output based on prev hook amount
            true // use prev hook amount
        );

        // For this test, we'll manually set up the scenario
        // In a real scenario, the previous hook would set its output amount
        console2.log("Testing prevHook amount usage in hook data creation");

        // Verify that when usePrevHookAmount is true, the hook data is created correctly
        bytes memory hookDataWithPrevAmount = mockDexHook.createSwapData(
            inputToken,
            swapAmount, // This should be ignored when usePrevHookAmount is true
            outputToken,
            expectedOutput,
            true // use prev hook amount
        );

        // The data should contain the usePrevHookAmount flag as true
        // Verify the flag is set correctly in the last byte
        bytes1 lastByte = hookDataWithPrevAmount[hookDataWithPrevAmount.length - 1];
        assertEq(lastByte, bytes1(0x01), "usePrevHookAmount flag should be set to true");
    }

    function test_MockDexHook_MultipleSwaps() external {
        console2.log("=== MockDexHook Multiple Swaps Test ===");

        // Setup multiple swaps with simplified variables
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = address(mockDexHook);
        hooksAddresses[1] = address(mockDexHook);

        bytes[] memory hooksData = new bytes[](2);
        // First swap: USDC -> WBTC
        hooksData[0] = mockDexHook.createSwapData(CHAIN_1_USDC, 500_000, CHAIN_1_WBTC, 1_000_000, false);
        // Second swap: WBTC -> USDC
        hooksData[1] = mockDexHook.createSwapData(CHAIN_1_WBTC, 500_000, CHAIN_1_USDC, 250_000, false);

        // Get initial balances
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        uint256 wbtcBefore = IERC20(CHAIN_1_WBTC).balanceOf(accountEth);

        console2.log("Initial Balances:");
        console2.log("  USDC:", usdcBefore);
        console2.log("  WBTC:", wbtcBefore);

        // Execute swaps
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);

        // Get final balances
        uint256 usdcAfter = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        uint256 wbtcAfter = IERC20(CHAIN_1_WBTC).balanceOf(accountEth);

        console2.log("Final Balances:");
        console2.log("  USDC:", usdcAfter);
        console2.log("  WBTC:", wbtcAfter);

        // Verify net changes (simplified)
        // Net USDC: -500_000 + 250_000 = -250_000
        assertEq(int256(usdcAfter) - int256(usdcBefore), -250_000, "Net USDC change should be -250,000");
        // Net WBTC: +1_000_000 - 500_000 = +500_000
        assertEq(int256(wbtcAfter) - int256(wbtcBefore), 500_000, "Net WBTC change should be +500,000");
    }

    function test_MockDexHook_DataStructure() external {
        console2.log("=== MockDexHook Data Structure Test ===");

        address inputToken = address(0x123);
        uint256 inputAmount = 1000;
        address outputToken = address(0x456);
        uint256 outputAmount = 2000;
        bool usePrevHookAmount = true;

        // Create hook data using the helper function
        MockDexHook tempHook = new MockDexHook(address(0x789));
        bytes memory hookData =
            tempHook.createSwapData(inputToken, inputAmount, outputToken, outputAmount, usePrevHookAmount);

        // Verify data structure by manually decoding
        // Note: Using assembly or BytesLib would be more accurate, but for testing we'll check length
        uint256 expectedLength = 20 + 32 + 20 + 32 + 1; // address + uint256 + address + uint256 + bool = 105 bytes
        assertEq(hookData.length, expectedLength, "Hook data should have correct length");

        console2.log("Hook data length:", hookData.length);
        console2.log("Expected length:", expectedLength);
    }
}
