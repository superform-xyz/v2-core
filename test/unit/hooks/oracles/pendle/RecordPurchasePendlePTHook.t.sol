// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { RecordPurchasePendlePTHook } from "../../../../../src/hooks/oracles/pendle/RecordPurchasePendlePTHook.sol";
import { IPendlePTHookResult } from "../../../../../src/interfaces/IPendlePTHookResult.sol";
import { ISuperHook, ISuperHookInflowOutflow } from "../../../../../src/interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../../../src/libraries/HookSubTypes.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { MockPendlePTAmortizedOracleV2 } from "../../../../mocks/MockPendlePTAmortizedOracleV2.sol";

/// @dev Mock PendlePTHook exposing a settable IPendlePTHookResult TradeResult and ISuperHookResult
///      output (getOutAmount/getOutToken, used to verify PASSTHROUGH forwarding), per account.
contract MockPendlePTHookResult is IPendlePTHookResult {
    mapping(address => TradeResult) internal _r;
    mapping(address => uint256) internal _outAmt;
    mapping(address => address) internal _outTok;

    function set(address account, TradeResult memory r) external {
        _r[account] = r;
    }

    function setOut(address account, uint256 amt, address tok) external {
        _outAmt[account] = amt;
        _outTok[account] = tok;
    }

    function getPendleTradeResult(address account) external view returns (TradeResult memory) {
        return _r[account];
    }

    function getOutAmount(address account) external view returns (uint256) {
        return _outAmt[account];
    }

    function getOutToken(address account) external view returns (address) {
        return _outTok[account];
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

contract RecordPurchasePendlePTHookTest is Test {
    RecordPurchasePendlePTHook public hook;
    MockPendlePTHookResult public prevHook;
    MockPendleMarket public market;
    MockPendlePTAmortizedOracleV2 public mockOracle;

    address public oracle;
    address public account = makeAddr("account");
    address public sy = makeAddr("sy");
    address public pt = makeAddr("pt");
    address public yt = makeAddr("yt");
    address public asset = makeAddr("asset");

    uint256 constant MARKET_POSITION = 52;
    uint256 constant PT_AMOUNT_POSITION = 72;
    uint256 constant TWAP_DURATION_POSITION = 104;
    uint256 constant USE_PREV_HOOK_AMOUNT_POSITION = 108;
    uint32 constant TWAP_15_MIN = 900;

    function setUp() public {
        prevHook = new MockPendlePTHookResult();
        market = new MockPendleMarket(sy, pt, yt);
        mockOracle = new MockPendlePTAmortizedOracleV2();
        oracle = address(mockOracle);
        hook = new RecordPurchasePendlePTHook(oracle, address(prevHook));
    }

    function _encodeData(
        address market_,
        uint256 amount_,
        uint32 twap_,
        bool usePrev_
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(bytes(new bytes(52)), market_, amount_, twap_, usePrev_);
    }

    function _buy(uint256 outputAmount) internal returns (IPendlePTHookResult.TradeResult memory r) {
        r = IPendlePTHookResult.TradeResult({
            operation: IPendlePTHookResult.Operation.BUY_PT,
            market: address(market),
            inputToken: asset,
            outputToken: pt,
            inputAmount: 0,
            outputAmount: outputAmount
        });
        prevHook.set(account, r);
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
        new RecordPurchasePendlePTHook(address(0), address(prevHook));
    }

    function test_Constructor_RevertsOnZeroApprovedHook() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new RecordPurchasePendlePTHook(oracle, address(0));
    }

    /* -------------------------------- manual mode ----------------------------- */

    function test_Build_Manual_UsesEncodedAmount() public view {
        bytes memory data = _encodeData(address(market), 110e18, TWAP_15_MIN, false);
        Execution[] memory ex = hook.build(address(0), account, data);
        assertEq(ex.length, 3);
        assertEq(ex[1].target, oracle);
        assertEq(
            ex[1].callData, abi.encodeWithSignature("recordPurchase(address,uint256,uint32)", address(market), uint256(110e18), TWAP_15_MIN)
        );
    }

    function test_Build_Manual_RevertsOnZeroAmount() public {
        bytes memory data = _encodeData(address(market), 0, TWAP_15_MIN, false);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), account, data);
    }

    /* ------------------------------ automatic mode ---------------------------- */

    function test_Build_Auto_UsesTradeOutputAmount() public {
        _buy(123e18);
        bytes memory data = _encodeData(address(market), 0, TWAP_15_MIN, true); // encoded amount ignored
        Execution[] memory ex = hook.build(address(prevHook), account, data);
        assertEq(
            ex[1].callData, abi.encodeWithSignature("recordPurchase(address,uint256,uint32)", address(market), uint256(123e18), TWAP_15_MIN)
        );
    }

    function test_Build_Auto_RevertsOnZeroResolved() public {
        _buy(0); // genuine zero-fill -> always reverts (G-1)
        bytes memory data = _encodeData(address(market), 0, TWAP_15_MIN, true);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_Auto_RevertsOnWrongPrevHook() public {
        _buy(100e18);
        bytes memory data = _encodeData(address(market), 0, TWAP_15_MIN, true);
        vm.expectRevert(RecordPurchasePendlePTHook.PREV_HOOK_NOT_VALID.selector);
        hook.build(makeAddr("notApproved"), account, data);
    }

    function test_Build_Auto_RejectsSellResult() public {
        IPendlePTHookResult.TradeResult memory r = IPendlePTHookResult.TradeResult({
            operation: IPendlePTHookResult.Operation.SELL_PT,
            market: address(market),
            inputToken: pt,
            outputToken: asset,
            inputAmount: 100e18,
            outputAmount: 99e18
        });
        prevHook.set(account, r);
        bytes memory data = _encodeData(address(market), 0, TWAP_15_MIN, true);
        vm.expectRevert(RecordPurchasePendlePTHook.OPERATION_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_Auto_RejectsEmptyContext() public {
        // No trade set -> operation NONE
        bytes memory data = _encodeData(address(market), 0, TWAP_15_MIN, true);
        vm.expectRevert(RecordPurchasePendlePTHook.OPERATION_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_Auto_RevertsOnMarketMismatch() public {
        IPendlePTHookResult.TradeResult memory r = IPendlePTHookResult.TradeResult({
            operation: IPendlePTHookResult.Operation.BUY_PT,
            market: makeAddr("otherMarket"),
            inputToken: asset,
            outputToken: pt,
            inputAmount: 0,
            outputAmount: 100e18
        });
        prevHook.set(account, r);
        bytes memory data = _encodeData(address(market), 0, TWAP_15_MIN, true);
        vm.expectRevert(RecordPurchasePendlePTHook.MARKET_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_Auto_RevertsOnWrongPtToken() public {
        IPendlePTHookResult.TradeResult memory r = IPendlePTHookResult.TradeResult({
            operation: IPendlePTHookResult.Operation.BUY_PT,
            market: address(market),
            inputToken: asset,
            outputToken: makeAddr("notPt"),
            inputAmount: 0,
            outputAmount: 100e18
        });
        prevHook.set(account, r);
        bytes memory data = _encodeData(address(market), 0, TWAP_15_MIN, true);
        vm.expectRevert(RecordPurchasePendlePTHook.PT_TOKEN_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertsOnZeroMarket() public {
        bytes memory data = _encodeData(address(0), 110e18, TWAP_15_MIN, false);
        vm.expectRevert(RecordPurchasePendlePTHook.MARKET_NOT_VALID.selector);
        hook.build(address(0), account, data);
    }

    /* ------------------------------- metadata --------------------------------- */

    function test_Inspect_ReturnsMarket() public view {
        bytes memory data = _encodeData(address(market), 110e18, TWAP_15_MIN, false);
        assertEq(hook.inspect(data), abi.encodePacked(address(market)));
    }

    function test_S2_Sizeless() public view {
        bytes memory data = _encodeData(address(market), 110e18, TWAP_15_MIN, false);
        assertEq(hook.decodeAmounts(data).length, 0);
        assertEq(hook.amountRoles(data).length, 0);
        assertTrue(hook.supportsInterface(type(ISuperHookInflowOutflow).interfaceId));
    }

    function test_Decode() public view {
        bytes memory data = _encodeData(address(market), 456e18, 600, true);
        assertEq(hook.decodeMarket(data), address(market));
        assertEq(hook.decodePtAmount(data), 456e18);
        assertEq(hook.decodeTwapDuration(data), uint32(600));
        assertTrue(hook.decodeUsePrevHookAmount(data));
    }

    /* --------------------- oracle recording / PPS (executed) ------------------ */

    /// @notice Execute the built oracle call and assert the oracle RECORDS the actual PT + registers
    ///         book value (PPS) against the strategy.
    function test_Oracle_RecordsActualPt_And_BookValue() public {
        _buy(123e18);
        bytes memory data = _encodeData(address(market), 0, TWAP_15_MIN, true);
        Execution[] memory ex = hook.build(address(prevHook), account, data);

        // The strategy (account) is msg.sender when the executor runs the oracle call.
        vm.prank(account);
        (bool ok,) = ex[1].target.call(ex[1].callData);
        assertTrue(ok, "recordPurchase executed");

        MockPendlePTAmortizedOracleV2.PurchaseRecord memory p = mockOracle.getLastPurchase();
        assertEq(p.caller, account, "position holder = strategy");
        assertEq(p.market, address(market), "market");
        assertEq(p.ptBought, 123e18, "records ACTUAL PT received");
        assertEq(p.twapDuration, TWAP_15_MIN, "twapDuration forwarded");
        assertGt(mockOracle.getBookValue(account, address(market)), 0, "book value (PPS) registered");
        assertTrue(mockOracle.hasPosition(account, address(market)), "position exists");
    }

    function test_Oracle_Manual_RecordsEncodedAmount() public {
        bytes memory data = _encodeData(address(market), 200e18, TWAP_15_MIN, false);
        Execution[] memory ex = hook.build(address(0), account, data);
        vm.prank(account);
        (bool ok,) = ex[1].target.call(ex[1].callData);
        assertTrue(ok);
        assertEq(mockOracle.getLastPurchase().ptBought, 200e18, "manual amount recorded");
    }

    /* --------------------- context isolation / passthrough -------------------- */

    /// @notice A BUY result belonging to accountA must NOT be usable for accountB (empty context).
    function test_CrossAccount_Isolation() public {
        address accountA = makeAddr("accountA");
        address accountB = makeAddr("accountB");
        prevHook.set(
            accountA,
            IPendlePTHookResult.TradeResult({
                operation: IPendlePTHookResult.Operation.BUY_PT,
                market: address(market),
                inputToken: asset,
                outputToken: pt,
                inputAmount: 0,
                outputAmount: 100e18
            })
        );
        bytes memory data = _encodeData(address(market), 0, TWAP_15_MIN, true);
        // accountB has no trade -> operation NONE -> rejected (no leakage from accountA)
        vm.expectRevert(RecordPurchasePendlePTHook.OPERATION_NOT_VALID.selector);
        hook.build(address(prevHook), accountB, data);
    }

    /// @notice PASSTHROUGH: preExecute forwards the previous hook's outAmount + outToken downstream.
    function test_Passthrough_ForwardsPrevOutput() public {
        prevHook.setOut(account, 555e18, pt);
        vm.prank(account);
        hook.setExecutionContext(account);
        bytes memory data = _encodeData(address(market), 110e18, TWAP_15_MIN, false);
        vm.prank(account);
        hook.preExecute(address(prevHook), account, data);
        assertEq(hook.getOutAmount(account), 555e18, "forwards prev outAmount");
        assertEq(hook.getOutToken(account), pt, "forwards prev outToken");
    }

    function test_Build_Auto_RejectsRedeem() public {
        IPendlePTHookResult.TradeResult memory r = IPendlePTHookResult.TradeResult({
            operation: IPendlePTHookResult.Operation.REDEEM_PT,
            market: address(market),
            inputToken: pt,
            outputToken: asset,
            inputAmount: 100e18,
            outputAmount: 99e18
        });
        prevHook.set(account, r);
        bytes memory data = _encodeData(address(market), 0, TWAP_15_MIN, true);
        vm.expectRevert(RecordPurchasePendlePTHook.OPERATION_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    /* --------------------------------- fuzz ----------------------------------- */

    function testFuzz_Auto_RecordsOutputAmount(uint256 outAmt, uint32 twap) public {
        outAmt = bound(outAmt, 1, type(uint128).max);
        twap = uint32(bound(twap, 0, 3600));
        _buy(outAmt);
        bytes memory data = _encodeData(address(market), 0, twap, true);
        Execution[] memory ex = hook.build(address(prevHook), account, data);
        assertEq(
            ex[1].callData, abi.encodeWithSignature("recordPurchase(address,uint256,uint32)", address(market), outAmt, twap)
        );
    }
}
