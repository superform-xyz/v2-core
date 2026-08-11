// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { RecordRedemptionPendlePTHook } from
    "../../../../../src/hooks/oracles/pendle/RecordRedemptionPendlePTHook.sol";
import { IPendlePTHookResult } from "../../../../../src/interfaces/IPendlePTHookResult.sol";
import { ISuperHook, ISuperHookInflowOutflow } from "../../../../../src/interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../../../src/libraries/HookSubTypes.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";

/// @dev Mock PendlePTHook exposing a settable IPendlePTHookResult TradeResult per account.
contract MockPendlePTHookResult is IPendlePTHookResult {
    mapping(address => TradeResult) internal _r;

    function set(address account, TradeResult memory r) external {
        _r[account] = r;
    }

    function getPendleTradeResult(address account) external view returns (TradeResult memory) {
        return _r[account];
    }
}

/// @dev Mock Pendle market returning a configurable (SY, PT, YT) from readTokens().
contract MockPendleMarket {
    address public immutable SY;
    address public immutable PT;
    address public immutable YT;

    constructor(address sy_, address pt_, address yt_) {
        SY = sy_;
        PT = pt_;
        YT = yt_;
    }

    function readTokens() external view returns (address, address, address) {
        return (SY, PT, YT);
    }
}

contract RecordRedemptionPendlePTHookTest is Test {
    RecordRedemptionPendlePTHook public hook;
    MockPendlePTHookResult public prevHook;
    MockPendleMarket public market;

    address public oracle = makeAddr("oracle");
    address public account = makeAddr("account");
    address public sy = makeAddr("sy");
    address public pt = makeAddr("pt");
    address public yt = makeAddr("yt");
    address public asset = makeAddr("asset");

    function setUp() public {
        prevHook = new MockPendlePTHookResult();
        market = new MockPendleMarket(sy, pt, yt);
        hook = new RecordRedemptionPendlePTHook(oracle, address(prevHook));
    }

    function _encodeData(address market_, uint256 amount_, bool usePrev_) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes(new bytes(52)), market_, amount_, usePrev_);
    }

    function _sellOrRedeem(
        IPendlePTHookResult.Operation op,
        uint256 inputAmount,
        uint256 outputAmount
    )
        internal
    {
        prevHook.set(
            account,
            IPendlePTHookResult.TradeResult({
                operation: op,
                market: address(market),
                inputToken: pt,
                outputToken: asset,
                inputAmount: inputAmount,
                outputAmount: outputAmount
            })
        );
    }

    /* ------------------------------- constructor ------------------------------ */

    function test_Constructor() public view {
        assertEq(hook.ORACLE(), oracle);
        assertEq(hook.APPROVED_PENDLE_PT_HOOK(), address(prevHook));
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(hook.subtype(), HookSubTypes.PTYT);
    }

    function test_Constructor_RevertsOnZeroOracle() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new RecordRedemptionPendlePTHook(address(0), address(prevHook));
    }

    /* -------------------------------- manual mode ----------------------------- */

    function test_Build_Manual_UsesEncodedAmount() public view {
        bytes memory data = _encodeData(address(market), 77e18, false);
        Execution[] memory ex = hook.build(address(0), account, data);
        assertEq(ex.length, 3);
        assertEq(ex[1].target, oracle);
        assertEq(ex[1].callData, abi.encodeWithSignature("recordRedemption(address,uint256)", address(market), uint256(77e18)));
    }

    function test_Build_Manual_RevertsOnZeroAmount() public {
        bytes memory data = _encodeData(address(market), 0, false);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), account, data);
    }

    /* ------------------------------ automatic mode ---------------------------- */

    /// @notice Records the actual PT SPENT (inputAmount), NOT the output asset received (outputAmount).
    function test_Build_Auto_Sell_RecordsInputAmount_NotOutput() public {
        _sellOrRedeem(IPendlePTHookResult.Operation.SELL_PT, 100e18, 95e18); // input=PT 100, output=asset 95
        bytes memory data = _encodeData(address(market), 0, true);
        Execution[] memory ex = hook.build(address(prevHook), account, data);
        assertEq(ex[1].callData, abi.encodeWithSignature("recordRedemption(address,uint256)", address(market), uint256(100e18)));
    }

    function test_Build_Auto_MaturedRedeem_RecordsInputAmount() public {
        _sellOrRedeem(IPendlePTHookResult.Operation.REDEEM_PT, 200e18, 201e18);
        bytes memory data = _encodeData(address(market), 0, true);
        Execution[] memory ex = hook.build(address(prevHook), account, data);
        assertEq(ex[1].callData, abi.encodeWithSignature("recordRedemption(address,uint256)", address(market), uint256(200e18)));
    }

    function test_Build_Auto_RejectsBuyResult() public {
        prevHook.set(
            account,
            IPendlePTHookResult.TradeResult({
                operation: IPendlePTHookResult.Operation.BUY_PT,
                market: address(market),
                inputToken: asset,
                outputToken: pt,
                inputAmount: 0,
                outputAmount: 100e18
            })
        );
        bytes memory data = _encodeData(address(market), 0, true);
        vm.expectRevert(RecordRedemptionPendlePTHook.OPERATION_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_Auto_RejectsEmptyContext() public {
        bytes memory data = _encodeData(address(market), 0, true);
        vm.expectRevert(RecordRedemptionPendlePTHook.OPERATION_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_Auto_RevertsOnZeroResolved() public {
        _sellOrRedeem(IPendlePTHookResult.Operation.SELL_PT, 0, 95e18);
        bytes memory data = _encodeData(address(market), 0, true);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_Auto_RevertsOnWrongPrevHook() public {
        _sellOrRedeem(IPendlePTHookResult.Operation.SELL_PT, 100e18, 95e18);
        bytes memory data = _encodeData(address(market), 0, true);
        vm.expectRevert(RecordRedemptionPendlePTHook.PREV_HOOK_NOT_VALID.selector);
        hook.build(makeAddr("notApproved"), account, data);
    }

    function test_Build_Auto_RevertsOnMarketMismatch() public {
        prevHook.set(
            account,
            IPendlePTHookResult.TradeResult({
                operation: IPendlePTHookResult.Operation.SELL_PT,
                market: makeAddr("otherMarket"),
                inputToken: pt,
                outputToken: asset,
                inputAmount: 100e18,
                outputAmount: 95e18
            })
        );
        bytes memory data = _encodeData(address(market), 0, true);
        vm.expectRevert(RecordRedemptionPendlePTHook.MARKET_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_Auto_RevertsOnWrongPtToken() public {
        prevHook.set(
            account,
            IPendlePTHookResult.TradeResult({
                operation: IPendlePTHookResult.Operation.SELL_PT,
                market: address(market),
                inputToken: makeAddr("notPt"),
                outputToken: asset,
                inputAmount: 100e18,
                outputAmount: 95e18
            })
        );
        bytes memory data = _encodeData(address(market), 0, true);
        vm.expectRevert(RecordRedemptionPendlePTHook.PT_TOKEN_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    /* ------------------------------- metadata --------------------------------- */

    function test_Inspect_ReturnsMarket() public view {
        bytes memory data = _encodeData(address(market), 77e18, false);
        assertEq(hook.inspect(data), abi.encodePacked(address(market)));
    }

    function test_S2_Sizeless() public view {
        bytes memory data = _encodeData(address(market), 77e18, false);
        assertEq(hook.decodeAmounts(data).length, 0);
        assertEq(hook.amountRoles(data).length, 0);
        assertTrue(hook.supportsInterface(type(ISuperHookInflowOutflow).interfaceId));
    }

    function test_Decode() public view {
        bytes memory data = _encodeData(address(market), 456e18, true);
        assertEq(hook.decodeMarket(data), address(market));
        assertEq(hook.decodePtSold(data), 456e18);
        assertTrue(hook.decodeUsePrevHookAmount(data));
    }

    /* --------------------------------- fuzz ----------------------------------- */

    function testFuzz_Auto_RecordsInputAmount(uint256 inAmt, uint256 outAmt) public {
        inAmt = bound(inAmt, 1, type(uint128).max);
        outAmt = bound(outAmt, 0, type(uint128).max);
        _sellOrRedeem(IPendlePTHookResult.Operation.SELL_PT, inAmt, outAmt);
        bytes memory data = _encodeData(address(market), 0, true);
        Execution[] memory ex = hook.build(address(prevHook), account, data);
        // Always the INPUT (PT spent), never the output asset.
        assertEq(ex[1].callData, abi.encodeWithSignature("recordRedemption(address,uint256)", address(market), inAmt));
    }
}
