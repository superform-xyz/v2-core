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

// 0x Settler Interfaces - Import directly from real contracts
import { IAllowanceHolder, ALLOWANCE_HOLDER } from "../../../lib/0x-settler/src/allowanceholder/IAllowanceHolder.sol";
import { ISettlerTakerSubmitted } from "../../../lib/0x-settler/src/interfaces/ISettlerTakerSubmitted.sol";
import { ISettlerBase } from "../../../lib/0x-settler/src/interfaces/ISettlerBase.sol";

contract Swap0xHookIntegrationTest is MinimalBaseIntegrationTest, ZeroExAPIParser {
    Swap0xV2Hook public swap0xHook;

    // Mainnet constants
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // Real USDC address
    address public constant SETTLER = 0x00000000009228E4e58A1F0dD1F4ebD8A7e1a1A7; // Example Settler address

    function setUp() public override {
        blockNumber = 0; // Use most recent block
        super.setUp();

        // Deploy the hook
        swap0xHook = new Swap0xV2Hook();

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
            1 // chainId (mainnet)
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

    /// @dev Helper function to create mock AllowanceHolder.exec calldata
    function _createMockExecData() internal view returns (bytes memory) {
        // Create mock Settler.execute calldata
        ISettlerBase.AllowedSlippage memory slippage = ISettlerBase.AllowedSlippage({
            recipient: payable(accountEth),
            buyToken: IERC20(USDC),
            minAmountOut: 1000e6 // 1000 USDC
         });

        bytes[] memory actions = new bytes[](1);
        actions[0] = abi.encodeWithSignature(
            "BASIC(address,uint256,address,uint256,bytes)", WETH, 10_000, address(0x1234), 0, bytes("mock_swap_data")
        );

        bytes32 zidAndAffiliate = bytes32(0);

        bytes memory settlerCalldata =
            abi.encodeCall(ISettlerTakerSubmitted.execute, (slippage, actions, zidAndAffiliate));

        // Create AllowanceHolder.exec calldata
        return abi.encodeCall(IAllowanceHolder.exec, (SETTLER, WETH, 1 ether, payable(SETTLER), settlerCalldata));
    }
}
