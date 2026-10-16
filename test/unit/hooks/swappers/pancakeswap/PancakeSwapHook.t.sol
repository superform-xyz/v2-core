// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { SwapPancakeSwapHook } from "../../../../../src/hooks/swappers/pancakeswap/SwapPancakeSwapHook.sol";
import {
    ApproveAndSwapPancakeSwapHook
} from "../../../../../src/hooks/swappers/pancakeswap/ApproveAndSwapPancakeSwapHook.sol";
import { PancakeSwapAmountUpdater } from "../../../../../src/libraries/PancakeSwapAmountUpdater.sol";
import { IPancakeSwapRouter } from "../../../../../src/vendor/pancakeswap/IPancakeSwapRouter.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware,
    ISuperHookInspector
} from "../../../../../src/interfaces/ISuperHook.sol";
import { ISuperHookSwap } from "../../../../../src/interfaces/ISuperHookSwap.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";

contract PancakeSwapHookTest is Test {
    bytes4 private constant SWAP_EXACT_IN = 0xedad400c;
    address private constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address private constant ARC_NATIVE = 0x3600000000000000000000000000000000000000;
    address private constant ROUTER = 0x2f68417A18dA681589F4eA64B9Cc9839209acfF7;

    SwapPancakeSwapHook private swapHook;
    ApproveAndSwapPancakeSwapHook private approveHook;
    SwapPancakeSwapHook private arcSwapHook; // AGGREGATOR_NATIVE = ARC_NATIVE
    MockHook private prevHook;

    address private account;
    address private inputToken;
    address private outputToken;

    function setUp() public {
        account = address(this);
        inputToken = address(new MockERC20("Input", "IN", 18));
        outputToken = address(new MockERC20("Output", "OUT", 18));
        prevHook = new MockHook(ISuperHook.HookType.INFLOW, inputToken);

        swapHook = new SwapPancakeSwapHook(ROUTER, NATIVE, NATIVE);
        approveHook = new ApproveAndSwapPancakeSwapHook(ROUTER, NATIVE, NATIVE);
        arcSwapHook = new SwapPancakeSwapHook(ROUTER, ARC_NATIVE, NATIVE); // (router, aggregatorNative, native)
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_RevertsOnZeroAddress() public {
        vm.expectRevert();
        new SwapPancakeSwapHook(address(0), NATIVE, NATIVE);
        vm.expectRevert();
        new SwapPancakeSwapHook(ROUTER, address(0), NATIVE);
        vm.expectRevert();
        new SwapPancakeSwapHook(ROUTER, NATIVE, address(0));
    }

    function test_Constructor_ApproveVariant_RevertsOnZeroAddress() public {
        vm.expectRevert();
        new ApproveAndSwapPancakeSwapHook(address(0), NATIVE, NATIVE);
        vm.expectRevert();
        new ApproveAndSwapPancakeSwapHook(ROUTER, address(0), NATIVE);
        vm.expectRevert();
        new ApproveAndSwapPancakeSwapHook(ROUTER, NATIVE, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                              BUILD SHAPE
    //////////////////////////////////////////////////////////////*/

    function test_Swap_FixedAmount_SingleExecutionToRouter() public view {
        bytes memory txData = _txData(inputToken, outputToken, 900, 1000, 0, account);
        bytes memory data = _hookData(inputToken, outputToken, 1000, 950, false, txData);

        Execution[] memory ex = swapHook.build(address(prevHook), account, data);
        // build() wraps as [preExecute, ...hookExecutions, postExecute]
        assertEq(ex.length, 3);
        assertEq(ex[1].target, ROUTER);
        assertEq(ex[1].value, 0); // ERC20 input
        assertEq(ex[1].callData, txData);
    }

    function test_ApproveAndSwap_FixedAmount_ApproveSwapReset() public view {
        bytes memory txData = _txData(inputToken, outputToken, 900, 1000, 0, account);
        bytes memory data = _hookData(inputToken, outputToken, 1000, 950, false, txData);

        Execution[] memory ex = approveHook.build(address(prevHook), account, data);
        assertEq(ex.length, 6); // preExecute + 4 + postExecute
        assertEq(ex[1].target, inputToken);
        assertEq(ex[1].callData, abi.encodeCall(IERC20.approve, (ROUTER, 0)));
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (ROUTER, 1000)));
        assertEq(ex[3].target, ROUTER);
        assertEq(ex[3].value, 0);
        assertEq(ex[3].callData, txData);
        assertEq(ex[4].callData, abi.encodeCall(IERC20.approve, (ROUTER, 0)));
    }

    function test_NativeInput_ForwardsValue_SingleExecution() public view {
        bytes memory txData = _txData(NATIVE, outputToken, 900, 1000, 0, account);
        bytes memory data = _hookData(NATIVE, outputToken, 1000, 950, false, txData);

        Execution[] memory ex = approveHook.build(address(prevHook), account, data);
        assertEq(ex.length, 3); // native -> single hook execution, wrapped
        assertEq(ex[1].target, ROUTER);
        assertEq(ex[1].value, 1000);
    }

    function test_ArcNativePlaceholder_TreatedAsNative() public view {
        // Header carries Superform NATIVE, router calldata carries Arc's 0x3600 placeholder.
        bytes memory txData = _txData(ARC_NATIVE, outputToken, 900, 1000, 0, account);
        bytes memory data = _hookData(NATIVE, outputToken, 1000, 950, false, txData);

        Execution[] memory ex = arcSwapHook.build(address(prevHook), account, data);
        assertEq(ex.length, 3);
        assertEq(ex[1].value, 1000); // native input recognized via AGGREGATOR_NATIVE
    }

    /*//////////////////////////////////////////////////////////////
                              VALIDATION
    //////////////////////////////////////////////////////////////*/

    function test_Revert_OutputTokenMismatch() public {
        address wrongOut = address(new MockERC20("Wrong", "W", 18));
        bytes memory txData = _txData(inputToken, wrongOut, 900, 1000, 0, account);
        bytes memory data = _hookData(inputToken, outputToken, 1000, 950, false, txData);
        vm.expectRevert(SwapPancakeSwapHook.OUTPUT_TOKEN_MISMATCH.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_Revert_InputTokenMismatch() public {
        address wrongIn = address(new MockERC20("Wrong", "W", 18));
        bytes memory txData = _txData(wrongIn, outputToken, 900, 1000, 0, account);
        bytes memory data = _hookData(inputToken, outputToken, 1000, 950, false, txData);
        vm.expectRevert(SwapPancakeSwapHook.INPUT_TOKEN_MISMATCH.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_Revert_SameInputOutputToken() public {
        bytes memory txData = _txData(inputToken, inputToken, 900, 1000, 0, account);
        bytes memory data = _hookData(inputToken, inputToken, 1000, 950, false, txData);
        vm.expectRevert(SwapPancakeSwapHook.SAME_INPUT_OUTPUT_TOKEN.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_Revert_RecipientNotAccount() public {
        bytes memory txData = _txData(inputToken, outputToken, 900, 1000, 0, makeAddr("stranger"));
        bytes memory data = _hookData(inputToken, outputToken, 1000, 950, false, txData);
        vm.expectRevert(SwapPancakeSwapHook.INVALID_RECIPIENT.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_Revert_InvalidSelector() public {
        bytes memory bad = abi.encodeWithSelector(bytes4(0xdeadbeef), uint256(0));
        // pad so length passes the head-length guard but selector is wrong
        bytes memory txData = bytes.concat(bad, new bytes(300));
        bytes memory data = _hookData(inputToken, outputToken, 1000, 950, false, txData);
        vm.expectRevert(PancakeSwapAmountUpdater.INVALID_SELECTOR.selector);
        swapHook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                         usePrevHookAmount (single route)
    //////////////////////////////////////////////////////////////*/

    function test_UsePrevHookAmount_SingleRoute_PatchesAmountAndMinOut() public {
        prevHook.setOutAmount(2000, account);
        // original: input 1000, minOut 900 -> new input 2000 should scale minOut to 1800
        bytes memory txData = _txData(inputToken, outputToken, 900, 1000, 0, account);
        bytes memory data = _hookData(inputToken, outputToken, 1000, 900, true, txData);

        Execution[] memory ex = swapHook.build(address(prevHook), account, data);
        (, IPancakeSwapRouter.BaseExactInRequest memory req, uint256[] memory routesAmount,,,) =
            _decodeSwapExactIn(ex[1].callData);
        assertEq(routesAmount[0], 2000, "routesAmount patched");
        assertEq(req.minOutputAmount, 1800, "minOut scaled proportionally");
    }

    function test_Revert_UsePrevHookAmount_MultiRoute() public {
        prevHook.setOutAmount(2000, account);
        bytes memory txData = _txDataMultiRoute(inputToken, outputToken, 900, 0, account);
        bytes memory data = _hookData(inputToken, outputToken, 1000, 900, true, txData);
        vm.expectRevert(PancakeSwapAmountUpdater.SINGLE_ROUTE_REQUIRED.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_Revert_UsePrevHookAmount_NonZeroFeeConfig() public {
        prevHook.setOutAmount(2000, account);
        bytes memory txData = _txData(inputToken, outputToken, 900, 1000, 1, account); // feeConfig = 1
        bytes memory data = _hookData(inputToken, outputToken, 1000, 900, true, txData);
        vm.expectRevert(PancakeSwapAmountUpdater.FEE_CONFIG_UNSUPPORTED.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_Revert_UsePrevHookAmount_ZeroPrevAmount() public {
        prevHook.setOutAmount(0, account);
        bytes memory txData = _txData(inputToken, outputToken, 900, 1000, 0, account);
        bytes memory data = _hookData(inputToken, outputToken, 1000, 900, true, txData);
        vm.expectRevert(SwapPancakeSwapHook.ZERO_EXECUTION_AMOUNT.selector);
        swapHook.build(address(prevHook), account, data);
    }

    // Multi-route is fine for FIXED-amount (non-chained) swaps.
    function test_MultiRoute_FixedAmount_Ok() public view {
        bytes memory txData = _txDataMultiRoute(inputToken, outputToken, 900, 0, account);
        bytes memory data = _hookData(inputToken, outputToken, 1000, 900, false, txData);
        Execution[] memory ex = swapHook.build(address(prevHook), account, data);
        assertEq(ex.length, 3);
        assertEq(ex[1].callData, txData);
    }

    /*//////////////////////////////////////////////////////////////
                         DECODERS / INSPECT
    //////////////////////////////////////////////////////////////*/

    function test_Inspect_ReturnsOutputTokenOnly() public view {
        bytes memory txData = _txData(inputToken, outputToken, 900, 1000, 0, account);
        bytes memory data = _hookData(inputToken, outputToken, 1000, 950, false, txData);
        bytes memory got = swapHook.inspect(data);
        assertEq(got, abi.encodePacked(outputToken));
        assertEq(got.length, 20);
    }

    function test_Decoders_RoundTrip() public view {
        bytes memory txData = _txData(inputToken, outputToken, 900, 1000, 0, account);
        bytes memory data = _hookData(inputToken, outputToken, 1000, 950, false, txData);
        assertEq(swapHook.decodeInputToken(data), inputToken);
        assertEq(swapHook.decodeOutputToken(data), outputToken);
        assertEq(swapHook.decodeInputAmount(data), 1000);
        assertEq(swapHook.decodeOutputMin(data), 950);
        assertEq(swapHook.decodeUsePrevHookAmount(data), false);
        assertEq(swapHook.decodePayload(data), abi.encode(txData));
        uint256[] memory amts = swapHook.decodeAmounts(data);
        assertEq(amts.length, 1);
        assertEq(amts[0], 1000);
    }

    /*//////////////////////////////////////////////////////////////
               BOTH HOOKS: shared external methods + validation
    //////////////////////////////////////////////////////////////*/

    function _hooks() private view returns (address[2] memory) {
        return [address(swapHook), address(approveHook)];
    }

    function test_Both_NameAndDescription() public view {
        assertEq(swapHook.name(), "Swap PancakeSwap");
        assertEq(swapHook.description(), "Swaps tokens via PancakeSwap aggregator");
        assertEq(approveHook.name(), "Approve and Swap PancakeSwap");
        assertEq(approveHook.description(), "Approves and swaps tokens via PancakeSwap aggregator");
    }

    function test_Both_AmountRoles_InToken() public view {
        address[2] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; i++) {
            ISuperHookInflowOutflow.AmountMeta[] memory meta = ISuperHookInflowOutflow(hooks[i]).amountRoles("");
            assertEq(meta.length, 1);
            assertTrue(meta[0].dir == ISuperHookInflowOutflow.Direction.IN);
            assertTrue(meta[0].denom == ISuperHookInflowOutflow.Denomination.TOKEN);
        }
    }

    function test_Both_SupportsInterface() public view {
        address[2] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; i++) {
            IERC165 h = IERC165(hooks[i]);
            assertTrue(h.supportsInterface(type(ISuperHookInflowOutflow).interfaceId), "inflowoutflow");
            assertTrue(h.supportsInterface(type(ISuperHookOutflow).interfaceId), "outflow");
            assertTrue(h.supportsInterface(type(IERC165).interfaceId), "erc165");
            assertTrue(h.supportsInterface(type(ISuperHook).interfaceId), "superhook");
            assertTrue(h.supportsInterface(type(ISuperHookResult).interfaceId), "result");
            assertTrue(h.supportsInterface(type(ISuperHookInspector).interfaceId), "inspector");
            assertFalse(h.supportsInterface(bytes4(0xffffffff)), "unknown");
        }
    }

    function test_Both_EncodeSwapData_RoundTrip() public view {
        bytes memory txData = _txData(inputToken, outputToken, 900, 1000, 0, account);
        ISuperHookSwap.SwapHeader memory header = ISuperHookSwap.SwapHeader({
            inputToken: inputToken,
            outputToken: outputToken,
            inputAmount: 1000,
            outputQuote: 980,
            outputMin: 950,
            usePrevHookAmount: true
        });
        address[2] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; i++) {
            ISuperHookSwap h = ISuperHookSwap(hooks[i]);
            bytes memory data = h.encodeSwapData(header, abi.encode(txData));
            assertEq(h.decodeInputToken(data), inputToken);
            assertEq(h.decodeOutputToken(data), outputToken);
            assertEq(h.decodeInputAmount(data), 1000);
            assertEq(h.decodeOutputQuote(data), 980);
            assertEq(h.decodeOutputMin(data), 950);
            assertEq(ISuperHookContextAware(hooks[i]).decodeUsePrevHookAmount(data), true);
            assertEq(h.decodePayload(data), abi.encode(txData));
        }
    }

    function test_Both_ReplaceCalldataAmounts() public view {
        bytes memory txData = _txData(inputToken, outputToken, 900, 1000, 0, account);
        bytes memory data = _hookData(inputToken, outputToken, 1000, 950, false, txData);
        uint256[] memory amts = new uint256[](1);
        amts[0] = 4242;
        address[2] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; i++) {
            bytes memory replaced = ISuperHookOutflow(hooks[i]).replaceCalldataAmounts(data, amts);
            assertEq(ISuperHookSwap(hooks[i]).decodeInputAmount(replaced), 4242);
        }
    }

    function test_Both_Revert_ReplaceCalldataAmounts_WrongLength() public {
        bytes memory txData = _txData(inputToken, outputToken, 900, 1000, 0, account);
        bytes memory data = _hookData(inputToken, outputToken, 1000, 950, false, txData);
        uint256[] memory amts = new uint256[](2);
        vm.expectRevert(); // INVALID_AMOUNTS_LENGTH
        swapHook.replaceCalldataAmounts(data, amts);
        vm.expectRevert();
        approveHook.replaceCalldataAmounts(data, amts);
    }

    function test_Both_Inspect() public view {
        bytes memory txData = _txData(inputToken, outputToken, 900, 1000, 0, account);
        bytes memory data = _hookData(inputToken, outputToken, 1000, 950, false, txData);
        assertEq(swapHook.inspect(data), abi.encodePacked(outputToken));
        assertEq(approveHook.inspect(data), abi.encodePacked(outputToken));
    }

    /*//////////////////////////////////////////////////////////////
          ApproveAndSwap: validation + usePrevHookAmount reverts
          (its own copy of the lines, so exercised directly)
    //////////////////////////////////////////////////////////////*/

    function test_Approve_Revert_OutputTokenMismatch() public {
        address wrongOut = address(new MockERC20("W", "W", 18));
        bytes memory txData = _txData(inputToken, wrongOut, 900, 1000, 0, account);
        bytes memory data = _hookData(inputToken, outputToken, 1000, 950, false, txData);
        vm.expectRevert(ApproveAndSwapPancakeSwapHook.OUTPUT_TOKEN_MISMATCH.selector);
        approveHook.build(address(prevHook), account, data);
    }

    function test_Approve_Revert_InputTokenMismatch() public {
        address wrongIn = address(new MockERC20("W", "W", 18));
        bytes memory txData = _txData(wrongIn, outputToken, 900, 1000, 0, account);
        bytes memory data = _hookData(inputToken, outputToken, 1000, 950, false, txData);
        vm.expectRevert(ApproveAndSwapPancakeSwapHook.INPUT_TOKEN_MISMATCH.selector);
        approveHook.build(address(prevHook), account, data);
    }

    function test_Approve_Revert_SameInputOutput() public {
        bytes memory txData = _txData(inputToken, inputToken, 900, 1000, 0, account);
        bytes memory data = _hookData(inputToken, inputToken, 1000, 950, false, txData);
        vm.expectRevert(ApproveAndSwapPancakeSwapHook.SAME_INPUT_OUTPUT_TOKEN.selector);
        approveHook.build(address(prevHook), account, data);
    }

    function test_Approve_Revert_RecipientNotAccount() public {
        bytes memory txData = _txData(inputToken, outputToken, 900, 1000, 0, makeAddr("stranger"));
        bytes memory data = _hookData(inputToken, outputToken, 1000, 950, false, txData);
        vm.expectRevert(ApproveAndSwapPancakeSwapHook.INVALID_RECIPIENT.selector);
        approveHook.build(address(prevHook), account, data);
    }

    function test_Approve_Revert_InvalidSelector() public {
        bytes memory txData = bytes.concat(abi.encodeWithSelector(bytes4(0xdeadbeef)), new bytes(300));
        bytes memory data = _hookData(inputToken, outputToken, 1000, 950, false, txData);
        vm.expectRevert(PancakeSwapAmountUpdater.INVALID_SELECTOR.selector);
        approveHook.build(address(prevHook), account, data);
    }

    function test_Approve_Revert_UsePrevHookAmount_MultiRoute() public {
        prevHook.setOutAmount(2000, account);
        bytes memory txData = _txDataMultiRoute(inputToken, outputToken, 900, 0, account);
        bytes memory data = _hookData(inputToken, outputToken, 1000, 900, true, txData);
        vm.expectRevert(PancakeSwapAmountUpdater.SINGLE_ROUTE_REQUIRED.selector);
        approveHook.build(address(prevHook), account, data);
    }

    function test_Approve_Revert_UsePrevHookAmount_ZeroPrev() public {
        prevHook.setOutAmount(0, account);
        bytes memory txData = _txData(inputToken, outputToken, 900, 1000, 0, account);
        bytes memory data = _hookData(inputToken, outputToken, 1000, 900, true, txData);
        vm.expectRevert(ApproveAndSwapPancakeSwapHook.ZERO_EXECUTION_AMOUNT.selector);
        approveHook.build(address(prevHook), account, data);
    }

    function test_Approve_UsePrevHookAmount_SingleRoute_Patches() public {
        prevHook.setOutAmount(2000, account);
        bytes memory txData = _txData(inputToken, outputToken, 900, 1000, 0, account);
        bytes memory data = _hookData(inputToken, outputToken, 1000, 900, true, txData);
        Execution[] memory ex = approveHook.build(address(prevHook), account, data);
        // ERC20 input -> [pre, approve0, approveAmt, swap, approve0, post]; approve amount uses scaled amount
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (ROUTER, 2000)));
        (, IPancakeSwapRouter.BaseExactInRequest memory req, uint256[] memory routesAmount,,,) =
            _decodeSwapExactIn(ex[3].callData);
        assertEq(routesAmount[0], 2000);
        assertEq(req.minOutputAmount, 1800);
    }

    /*//////////////////////////////////////////////////////////////
          Zero-address native sentinel path in txData
    //////////////////////////////////////////////////////////////*/

    function test_Native_HeaderZeroAddress_RouterNative_TreatedSame() public view {
        // header inputToken = address(0), router calldata srcToken = NATIVE -> _isSameToken via _isNative both sides
        bytes memory txData = _txData(NATIVE, outputToken, 0, 1000, 0, account);
        bytes memory data = _hookData(address(0), outputToken, 1000, 0, false, txData);
        Execution[] memory ex = swapHook.build(address(prevHook), account, data);
        assertEq(ex[1].value, 1000);
    }

    function test_ZeroAddressNativeInput_TreatedAsNative() public view {
        // router calldata uses address(0) as native; header uses NATIVE -> _isSameToken via _isNative
        bytes memory txData = _txData(address(0), outputToken, 0, 1000, 0, account);
        bytes memory data = _hookData(NATIVE, outputToken, 1000, 0, false, txData);
        Execution[] memory ex = swapHook.build(address(prevHook), account, data);
        assertEq(ex[1].value, 1000); // native recognized via address(0)
    }

    /*//////////////////////////////////////////////////////////////
                    SECURITY: swap-through hardening
    //////////////////////////////////////////////////////////////*/

    /// @notice The fixed-offset reads assume the swapExactIn head layout. A different entrypoint
    ///         (swapExactInWithRefundTo, extra arg -> different recipient/feeConfig offsets) MUST be
    ///         rejected by the selector guard, not mis-decoded. Both hooks.
    function test_Security_Revert_SwapExactInWithRefundTo_Selector() public {
        bytes memory txData = _txDataWithRefundTo(inputToken, outputToken, 900, 1000, account, account);
        bytes memory data = _hookData(inputToken, outputToken, 1000, 950, false, txData);
        vm.expectRevert(PancakeSwapAmountUpdater.INVALID_SELECTOR.selector);
        swapHook.build(address(prevHook), account, data);
        vm.expectRevert(PancakeSwapAmountUpdater.INVALID_SELECTOR.selector);
        approveHook.build(address(prevHook), account, data);
    }

    /// @notice Recipient is validated even on the usePrevHookAmount (rescale) path, so a chained swap
    ///         can't be redirected to a third party.
    function test_Security_Revert_UsePrevHookAmount_WrongRecipient() public {
        prevHook.setOutAmount(2000, account);
        bytes memory txData = _txData(inputToken, outputToken, 900, 1000, 0, makeAddr("thief"));
        bytes memory data = _hookData(inputToken, outputToken, 1000, 900, true, txData);
        vm.expectRevert(SwapPancakeSwapHook.INVALID_RECIPIENT.selector);
        swapHook.build(address(prevHook), account, data);
    }

    /// @notice CHARACTERIZATION (matches the whole swap-hook fleet): the hook does NOT cross-check the
    ///         router's minOutputAmount against the intent's header outputMin. Slippage protection is the
    ///         min embedded in the signed router calldata. A low router-min with a high header-min does
    ///         NOT revert here — documented, inherited trust model. (See research notes for the optional
    ///         `request.minOutputAmount >= headerOutputMin` hardening.)
    function test_Security_Characterization_HeaderOutputMinNotEnforced() public view {
        bytes memory txData = _txData(inputToken, outputToken, 0 /*router min*/, 1000, 0, account);
        bytes memory data = _hookData(inputToken, outputToken, 1000, 999e18 /*header min*/, false, txData);
        Execution[] memory ex = swapHook.build(address(prevHook), account, data);
        assertEq(ex.length, 3); // builds fine; no on-chain cross-check
        assertEq(ex[1].callData, txData);
    }

    /// @notice Execution target is ALWAYS the pinned router (never read from txData), so calldata cannot
    ///         redirect the call to an attacker contract.
    function test_Security_TargetAlwaysPinnedRouter() public view {
        bytes memory txData = _txData(inputToken, outputToken, 900, 1000, 0, account);
        bytes memory data = _hookData(inputToken, outputToken, 1000, 950, false, txData);
        Execution[] memory ex = swapHook.build(address(prevHook), account, data);
        assertEq(ex[1].target, ROUTER);
        Execution[] memory ex2 = approveHook.build(address(prevHook), account, data);
        assertEq(ex2[3].target, ROUTER); // swap leg
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    function _emptyRoute(address fromToken) private pure returns (IPancakeSwapRouter.RouterPath memory p) {
        p = IPancakeSwapRouter.RouterPath({
            mixAdapters: new uint256[](0),
            assetTo: new address[](0),
            rawData: new uint256[](0),
            extraData: new bytes[](0),
            fromToken: fromToken
        });
    }

    function _txData(
        address src,
        address dst,
        uint256 minOut,
        uint256 amount,
        uint256 feeConfig,
        address recipient
    )
        private
        view
        returns (bytes memory)
    {
        IPancakeSwapRouter.BaseExactInRequest memory req = IPancakeSwapRouter.BaseExactInRequest({
            inputToken: src,
            outputToken: dst,
            minOutputAmount: minOut,
            deadline: block.timestamp + 1
        });
        uint256[] memory routesAmount = new uint256[](1);
        routesAmount[0] = amount;
        IPancakeSwapRouter.RouterPath[][] memory routes = new IPancakeSwapRouter.RouterPath[][](1);
        routes[0] = new IPancakeSwapRouter.RouterPath[](1);
        routes[0][0] = _emptyRoute(src);
        return abi.encodeWithSelector(SWAP_EXACT_IN, uint256(1), req, routesAmount, routes, feeConfig, recipient);
    }

    function _txDataWithRefundTo(
        address src,
        address dst,
        uint256 minOut,
        uint256 amount,
        address recipient,
        address refundTo
    )
        private
        view
        returns (bytes memory)
    {
        IPancakeSwapRouter.BaseExactInRequest memory req = IPancakeSwapRouter.BaseExactInRequest({
            inputToken: src,
            outputToken: dst,
            minOutputAmount: minOut,
            deadline: block.timestamp + 1
        });
        uint256[] memory routesAmount = new uint256[](1);
        routesAmount[0] = amount;
        IPancakeSwapRouter.RouterPath[][] memory routes = new IPancakeSwapRouter.RouterPath[][](1);
        routes[0] = new IPancakeSwapRouter.RouterPath[](1);
        routes[0][0] = _emptyRoute(src);
        // swapExactInWithRefundTo selector 0x71069e99 — extra trailing refundTo arg
        return abi.encodeWithSelector(
            bytes4(0x71069e99), uint256(1), req, routesAmount, routes, uint256(0), recipient, refundTo
        );
    }

    function _txDataMultiRoute(
        address src,
        address dst,
        uint256 minOut,
        uint256 feeConfig,
        address recipient
    )
        private
        view
        returns (bytes memory)
    {
        IPancakeSwapRouter.BaseExactInRequest memory req = IPancakeSwapRouter.BaseExactInRequest({
            inputToken: src,
            outputToken: dst,
            minOutputAmount: minOut,
            deadline: block.timestamp + 1
        });
        uint256[] memory routesAmount = new uint256[](2);
        routesAmount[0] = 600;
        routesAmount[1] = 400;
        IPancakeSwapRouter.RouterPath[][] memory routes = new IPancakeSwapRouter.RouterPath[][](2);
        routes[0] = new IPancakeSwapRouter.RouterPath[](1);
        routes[0][0] = _emptyRoute(src);
        routes[1] = new IPancakeSwapRouter.RouterPath[](1);
        routes[1][0] = _emptyRoute(src);
        return abi.encodeWithSelector(SWAP_EXACT_IN, uint256(1), req, routesAmount, routes, feeConfig, recipient);
    }

    function _decodeSwapExactIn(bytes memory callData)
        private
        pure
        returns (
            uint256 orderId,
            IPancakeSwapRouter.BaseExactInRequest memory request,
            uint256[] memory routesAmount,
            IPancakeSwapRouter.RouterPath[][] memory routes,
            uint256 feeConfig,
            address recipient
        )
    {
        bytes memory args = new bytes(callData.length - 4);
        for (uint256 i = 0; i < args.length; i++) {
            args[i] = callData[i + 4];
        }
        (orderId, request, routesAmount, routes, feeConfig, recipient) = abi.decode(
            args,
            (
                uint256,
                IPancakeSwapRouter.BaseExactInRequest,
                uint256[],
                IPancakeSwapRouter.RouterPath[][],
                uint256,
                address
            )
        );
    }

    function _hookData(
        address inputToken_,
        address outputToken_,
        uint256 inputAmount_,
        uint256 outputMin_,
        bool usePrevHookAmount_,
        bytes memory txData_
    )
        private
        pure
        returns (bytes memory)
    {
        bytes memory payload = abi.encode(txData_);
        return bytes.concat(
            bytes(new bytes(52)),
            bytes20(inputToken_),
            bytes20(outputToken_),
            bytes32(inputAmount_),
            bytes32(uint256(0)), // outputQuote
            bytes32(outputMin_),
            bytes1(usePrevHookAmount_ ? uint8(1) : uint8(0)),
            bytes32(payload.length),
            payload
        );
    }
}
