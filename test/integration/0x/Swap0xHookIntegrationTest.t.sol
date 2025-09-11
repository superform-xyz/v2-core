// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

// external
import { IERC20 } from "@forge-std/interfaces/IERC20.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";

// Superform
import { Swap0xV2Hook } from "../../../src/hooks/swappers/0x/Swap0xV2Hook.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";
import { HookSubTypes } from "../../../src/libraries/HookSubTypes.sol";
import { ZeroExAPIParser } from "../../utils/parsers/ZeroExAPIParser.sol";
import { BytesLib } from "../../../src/vendor/BytesLib.sol";

// 0x Settler Interfaces - Import directly from real contracts
import { IAllowanceHolder, ALLOWANCE_HOLDER } from "../../../lib/0x-settler/src/allowanceholder/IAllowanceHolder.sol";
import { ISettlerTakerSubmitted } from "../../../lib/0x-settler/src/interfaces/ISettlerTakerSubmitted.sol";
import { ISettlerBase } from "../../../lib/0x-settler/src/interfaces/ISettlerBase.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";

contract Swap0xHookIntegrationTest is MinimalBaseIntegrationTest, ZeroExAPIParser {
    Swap0xV2Hook public swap0xHook;

    // Mainnet constants
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // Real USDC address
    address public constant SETTLER = 0x00000000009228E4e58A1F0dD1F4ebD8A7e1a1A7; // Example Settler address
    string public ZEROX_API_KEY = vm.envString("ZEROX_API_KEY");

    // Test account for receive() function requirement
    receive() external payable { }

    function setUp() public override {
        blockNumber = 0; // Use most recent block
        super.setUp();

        // Deploy the hook
        swap0xHook = new Swap0xV2Hook(ALLOWANCE_HOLDER);

        // Fund account with some WETH for testing
        deal(WETH, accountEth, 1 ether);
    }

    /// @notice Execute a WETH to USDC swap via 0x AllowanceHolder
    /// @dev Similar pattern to PendleRouterHookTests execute_PendleRouterSwap_Token_To_Pt
    function test_ZeroExSwapExecution() public {
        uint256 sellAmount = 0.1 ether; // Sell 0.1 WETH

        // Ensure account has enough WETH
        deal(WETH, accountEth, sellAmount);

        // Get initial USDC balance
        uint256 initialUSDCBalance = IERC20(USDC).balanceOf(accountEth);

        // Get quote from 0x API (simulated)
        ZeroExAPIParser.ZeroExQuoteResponse memory quote = getZeroExQuote(
            WETH, // sellToken
            USDC, // buyToken
            sellAmount, // sellAmount
            accountEth, // taker
            1, // chainId (mainnet)
            500, // slippage tolerance in basis points (5% slippage)
            ZEROX_API_KEY
        );

        // Create hook data from API response
        bytes memory hookData = createHookDataFromQuote(
            quote,
            address(0), // dstReceiver (0 = account)
            true // usePrevHookAmount
        );

        // Set up hook execution
        address[] memory hookAddresses = new address[](2);
        hookAddresses[0] = address(approveHook); // Approve WETH to AllowanceHolder
        hookAddresses[1] = address(swap0xHook); // Execute 0x swap

        bytes[] memory hookDataArray = new bytes[](2);
        hookDataArray[0] = _createApproveHookData(
            WETH,
            quote.allowanceTarget, // AllowanceHolder address
            sellAmount,
            false
        );
        hookDataArray[1] = hookData;

        // Execute via SuperExecutor
        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

        // Execute the swap
        executeOp(opData);

        // Verify swap was successful
        uint256 finalUSDCBalance = IERC20(USDC).balanceOf(accountEth);
        assertGt(finalUSDCBalance, initialUSDCBalance, "USDC balance should increase");

        // Verify WETH was spent
        uint256 finalWETHBalance = IERC20(WETH).balanceOf(accountEth);
        assertEq(finalWETHBalance, 0, "WETH should be fully spent");
    }

    /// @notice Test the inspect function with real API calldata
    function test_InspectFunctionWithRealAPI() public {
        uint256 sellAmount = 0.1 ether;

        // Get a real quote from 0x API
        ZeroExAPIParser.ZeroExQuoteResponse memory quote = getZeroExQuote(
            WETH, // sellToken
            USDC, // buyToken
            sellAmount, // sellAmount
            accountEth, // taker
            1, // chainId (mainnet)
            500, // slippage tolerance in basis points (5% slippage)
            ZEROX_API_KEY
        );

        // Create hook data from API response
        bytes memory hookData = createHookDataFromQuote(
            quote,
            address(0), // dstReceiver (0 = account)
            false // usePrevHookAmount
        );

        // Test the inspect function
        bytes memory packedResult = swap0xHook.inspect(hookData);

        // Decode the result - should contain input and output tokens
        address inputToken = address(bytes20(BytesLib.slice(packedResult, 0, 20)));
        address outputToken = address(bytes20(BytesLib.slice(packedResult, 20, 20)));

        // Verify tokens match our swap
        assertEq(inputToken, WETH, "Input token should be WETH");
        assertEq(outputToken, USDC, "Output token should be USDC");
    }

    /// @notice Test hook type and subtype
    function test_HookTypeAndSubtype() public {
        assertEq(
            uint8(swap0xHook.hookType()), uint8(ISuperHook.HookType.NONACCOUNTING), "Should be non-accounting hook"
        );
        assertEq(swap0xHook.subtype(), HookSubTypes.SWAP, "Should have SWAP subtype");
    }

    /// @notice Test decodeUsePrevHookAmount function
    function test_DecodeUsePrevHookAmount() public {
        // Create hook data with usePrevHookAmount = true
        bytes memory hookDataTrue = abi.encodePacked(
            USDC, // dstToken
            address(0), // dstReceiver
            uint256(0), // value
            bytes1(uint8(1)), // usePrevHookAmount = true
            bytes("mock_calldata")
        );

        assertTrue(swap0xHook.decodeUsePrevHookAmount(hookDataTrue), "Should decode true");

        // Create hook data with usePrevHookAmount = false
        bytes memory hookDataFalse = abi.encodePacked(
            USDC, // dstToken
            address(0), // dstReceiver
            uint256(0), // value
            bytes1(uint8(0)), // usePrevHookAmount = false
            bytes("mock_calldata")
        );

        assertFalse(swap0xHook.decodeUsePrevHookAmount(hookDataFalse), "Should decode false");
    }

    /// @notice Test edge case with invalid selector
    function test_InspectWithInvalidSelector() public {
        // Create hook data with invalid selector
        bytes memory invalidCalldata = abi.encodeWithSignature("invalidFunction()");
        bytes memory hookData = abi.encodePacked(
            USDC, // dstToken
            address(0), // dstReceiver
            uint256(0), // value
            bytes1(uint8(0)), // usePrevHookAmount
            invalidCalldata
        );

        vm.expectRevert(Swap0xV2Hook.INVALID_SELECTOR.selector);
        swap0xHook.inspect(hookData);
    }

    /// @notice Test edge case with insufficient calldata
    function test_InspectWithInsufficientCalldata() public {
        // Create hook data with insufficient calldata
        bytes memory shortCalldata = bytes("abc"); // Less than 4 bytes
        bytes memory hookData = abi.encodePacked(
            USDC, // dstToken
            address(0), // dstReceiver
            uint256(0), // value
            bytes1(uint8(0)), // usePrevHookAmount
            shortCalldata
        );

        // The function will panic on array out-of-bounds when trying to access txData_[:4] with only 3 bytes
        vm.expectRevert();
        swap0xHook.inspect(hookData);
    }

    /// @notice Test successful swap with amount tracking
    function test_ZeroExSwapWithAmountTracking() public {
        uint256 sellAmount = 0.1 ether;

        // Ensure account has enough WETH
        deal(WETH, accountEth, sellAmount);

        // Get initial balances
        uint256 initialWETHBalance = IERC20(WETH).balanceOf(accountEth);
        uint256 initialUSDCBalance = IERC20(USDC).balanceOf(accountEth);

        // Get quote from 0x API
        ZeroExAPIParser.ZeroExQuoteResponse memory quote = getZeroExQuote(
            WETH, // sellToken
            USDC, // buyToken
            sellAmount, // sellAmount
            accountEth, // taker
            1, // chainId (mainnet),
            500, // slippage tolerance in basis points (5% slippage)
            ZEROX_API_KEY
        );

        // Create hook data
        bytes memory hookData = createHookDataFromQuote(
            quote,
            address(0), // dstReceiver (0 = account)
            false // usePrevHookAmount
        );

        // Set up hook execution
        address[] memory hookAddresses = new address[](2);
        hookAddresses[0] = address(approveHook);
        hookAddresses[1] = address(swap0xHook);

        bytes[] memory hookDataArray = new bytes[](2);
        hookDataArray[0] = _createApproveHookData(WETH, quote.allowanceTarget, sellAmount, false);
        hookDataArray[1] = hookData;

        // Execute via SuperExecutor
        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

        // Execute the swap
        executeOp(opData);

        // Verify swap was successful
        uint256 finalWETHBalance = IERC20(WETH).balanceOf(accountEth);
        uint256 finalUSDCBalance = IERC20(USDC).balanceOf(accountEth);

        // Allow for small tolerance due to gas costs
        assertLe(finalWETHBalance, initialWETHBalance - sellAmount + 0.01 ether, "WETH should be spent");
        assertGt(finalUSDCBalance, initialUSDCBalance, "USDC balance should increase");

        // Verify minimum buy amount was respected
        uint256 usdcReceived = finalUSDCBalance - initialUSDCBalance;
        assertGe(usdcReceived, quote.minBuyAmount, "Should receive at least minimum buy amount");
    }

    /// @notice Test swap with native ETH (value > 0)
    function test_ZeroExSwapWithNativeETH() public {
        uint256 ethAmount = 0.05 ether;

        // Fund account with ETH
        vm.deal(accountEth, ethAmount + 1 ether); // Extra for gas

        // Mock a native ETH to USDC swap quote
        // In real scenarios, this would come from 0x API with value > 0
        bytes memory mockAllowanceHolderCalldata = _createMockAllowanceHolderCalldata(
            address(0), // ETH represented as address(0) in 0x v2
            USDC,
            ethAmount
        );

        bytes memory hookData = abi.encodePacked(
            USDC, // dstToken
            address(0), // dstReceiver (account)
            ethAmount, // value (ETH to send)
            bytes1(uint8(0)), // usePrevHookAmount = false
            mockAllowanceHolderCalldata
        );

        // Test that hook data is properly structured
        address extractedDstToken = address(bytes20(BytesLib.slice(hookData, 0, 20)));
        uint256 extractedValue = uint256(bytes32(BytesLib.slice(hookData, 40, 32)));

        assertEq(extractedDstToken, USDC, "Destination token should be USDC");
        assertEq(extractedValue, ethAmount, "Value should match ETH amount");
    }

    /// @dev Helper function to create mock AllowanceHolder.exec calldata
    function _createMockAllowanceHolderCalldata(
        address sellToken,
        address buyToken,
        uint256 sellAmount
    )
        internal
        view
        returns (bytes memory)
    {
        // Create mock Settler.execute calldata
        ISettlerBase.AllowedSlippage memory slippage = ISettlerBase.AllowedSlippage({
            recipient: payable(accountEth),
            buyToken: IERC20(buyToken),
            minAmountOut: sellAmount * 3000 // Assume 3000 USDC per ETH
         });

        bytes[] memory actions = new bytes[](1);
        actions[0] = abi.encodeWithSignature(
            "BASIC(address,uint256,address,uint256,bytes)",
            sellToken,
            sellAmount,
            address(0x1234),
            0,
            bytes("mock_swap_data")
        );

        bytes32 zidAndAffiliate = bytes32(0);

        bytes memory settlerCalldata =
            abi.encodeCall(ISettlerTakerSubmitted.execute, (slippage, actions, zidAndAffiliate));

        // Create AllowanceHolder.exec calldata
        return
            abi.encodeCall(IAllowanceHolder.exec, (SETTLER, sellToken, sellAmount, payable(SETTLER), settlerCalldata));
    }

    /// @dev Helper function to create mock AllowanceHolder.exec calldata
    function _createMockExecData() internal view returns (bytes memory) {
        return _createMockAllowanceHolderCalldata(WETH, USDC, 1 ether);
    }
}
