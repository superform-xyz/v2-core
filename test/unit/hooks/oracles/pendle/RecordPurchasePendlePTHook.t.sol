// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { RecordPurchasePendlePTHook } from "../../../../../src/hooks/oracles/pendle/RecordPurchasePendlePTHook.sol";
import { IPendlePTHookResult } from "../../../../../src/interfaces/IPendlePTHookResult.sol";
import { ISuperHook, ISuperHookInflowOutflow } from "../../../../../src/interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../../../src/libraries/HookSubTypes.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { MockPendlePTAmortizedOracle } from "../../../../mocks/MockPendlePTAmortizedOracle.sol";

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

/// @dev Mock SY exposing assetInfo() with a configurable accounting-asset decimals.
contract MockSY {
    uint8 public immutable assetDecimals;

    constructor(uint8 assetDecimals_) {
        assetDecimals = assetDecimals_;
    }

    function assetInfo() external view returns (uint8 assetType, address assetAddress, uint8 assetDecimals_) {
        return (0, address(0), assetDecimals);
    }
}

/// @dev Mock token exposing decimals() (used as the market's PT).
contract MockDecimalsToken {
    uint8 public immutable decimals;

    constructor(uint8 decimals_) {
        decimals = decimals_;
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
    MockPendlePTAmortizedOracle public mockOracle;

    address public oracle;
    address public account = makeAddr("account");
    // sy/pt are real mocks (the hook reads assetInfo()/decimals() for the V1 unit invariant).
    address public sy;
    address public pt;
    address public yt = makeAddr("yt");
    address public asset = makeAddr("asset");

    uint256 constant MARKET_POSITION = 52;
    uint256 constant PT_AMOUNT_POSITION = 72;
    uint256 constant TWAP_DURATION_POSITION = 104;
    uint256 constant USE_PREV_HOOK_AMOUNT_POSITION = 108;
    uint32 constant TWAP_15_MIN = 900;

    function setUp() public {
        prevHook = new MockPendlePTHookResult();
        // Matched decimals (18 == 18): the V1 unit invariant holds for the default market.
        sy = address(new MockSY(18));
        pt = address(new MockDecimalsToken(18));
        market = new MockPendleMarket(sy, pt, yt);
        mockOracle = new MockPendlePTAmortizedOracle();
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
        assertEq(address(hook.ORACLE()), oracle);
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
            ex[1].callData,
            abi.encodeWithSignature(
                "recordPurchase(address,uint256,uint256)", address(market), uint256(99e18), uint256(110e18)
            )
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
            ex[1].callData,
            abi.encodeWithSignature(
                "recordPurchase(address,uint256,uint256)", address(market), uint256(110.7e18), uint256(123e18)
            )
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

        MockPendlePTAmortizedOracle.PurchaseRecord memory p = mockOracle.getLastPurchase();
        assertEq(p.caller, account, "position holder = strategy");
        assertEq(p.market, address(market), "market");
        assertEq(p.ptAmount, 123e18, "records ACTUAL PT received");
        assertEq(p.sySpent, 110.7e18, "sySpent = oracle TWAP valuation of recorded PT");
        assertGt(mockOracle.getBookValue(account, address(market)), 0, "book value (PPS) registered");
        assertTrue(mockOracle.hasPosition(account, address(market)), "position exists");
    }

    function test_Oracle_Manual_RecordsEncodedAmount() public {
        bytes memory data = _encodeData(address(market), 200e18, TWAP_15_MIN, false);
        Execution[] memory ex = hook.build(address(0), account, data);
        vm.prank(account);
        (bool ok,) = ex[1].target.call(ex[1].callData);
        assertTrue(ok);
        assertEq(mockOracle.getLastPurchase().ptAmount, 200e18, "manual amount recorded");
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
        outAmt = bound(outAmt, 2, type(uint128).max); // >= 2 so mock valuation (90%) stays non-zero
        twap = uint32(bound(twap, TWAP_15_MIN, 3600)); // must satisfy the oracle's configured minimum
        _buy(outAmt);
        bytes memory data = _encodeData(address(market), 0, twap, true);
        Execution[] memory ex = hook.build(address(prevHook), account, data);
        uint256 expectedSySpent = outAmt * 0.9e18 / 1e18;
        assertEq(
            ex[1].callData,
            abi.encodeWithSignature(
                "recordPurchase(address,uint256,uint256)", address(market), expectedSySpent, outAmt
            )
        );
    }

    /* ------------------------- V1 binding regression guards ------------------- */

    /// @notice twapDuration below the oracle's configured minimum (TWAP_DURATION) must revert.
    function test_Build_RevertsOnTwapBelowOracleMinimum() public {
        bytes memory data = _encodeData(address(market), 110e18, TWAP_15_MIN - 1, false);
        vm.expectRevert(RecordPurchasePendlePTHook.TWAP_DURATION_TOO_SHORT.selector);
        hook.build(address(0), account, data);
    }

    /// @notice V1 unit invariant: a market whose PT decimals differ from the SY accounting-asset
    ///         decimals must be refused (the V1 oracle mixes the two units).
    function test_Build_RevertsOnDecimalsMismatch() public {
        MockPendleMarket badMarket =
            new MockPendleMarket(address(new MockSY(18)), address(new MockDecimalsToken(6)), yt);
        bytes memory data = _encodeData(address(badMarket), 110e18, TWAP_15_MIN, false);
        vm.expectRevert(RecordPurchasePendlePTHook.DECIMALS_MISMATCH.selector);
        hook.build(address(0), account, data);
    }

    /// @notice Matched PT/asset decimals pass the invariant (sanity companion to the mismatch test).
    function test_Build_MatchedDecimals_Pass() public view {
        bytes memory data = _encodeData(address(market), 110e18, TWAP_15_MIN, false);
        Execution[] memory ex = hook.build(address(0), account, data);
        assertEq(ex[1].target, oracle);
    }

    /// @notice Zero oracle valuation of the recorded PT reverts with its own (oracle-side) error,
    ///         distinct from a zero PT amount.
    function test_Build_RevertsOnZeroValuation() public {
        mockOracle.setAssetOutputRate(0);
        bytes memory data = _encodeData(address(market), 110e18, TWAP_15_MIN, false);
        vm.expectRevert(RecordPurchasePendlePTHook.SY_VALUE_NOT_VALID.selector);
        hook.build(address(0), account, data);
    }

    /// @notice Pins the V1 argument ORDER in the encoded calldata: (market, sySpent, ptAmount).
    ///         sySpent is the SECOND argument — swapping it with ptAmount would not revert on-chain
    ///         and would silently corrupt book values.
    function test_CallData_ArgumentOrder_MarketSySpentPtAmount() public view {
        uint256 ptAmount = 100e18;
        uint256 expectedSySpent = 90e18; // mock rate 0.9e18
        bytes memory data = _encodeData(address(market), ptAmount, TWAP_15_MIN, false);
        Execution[] memory ex = hook.build(address(0), account, data);

        bytes memory cd = ex[1].callData;
        assertEq(cd.length, 4 + 32 * 3, "selector + 3 words");
        // word 0: market, word 1: sySpent, word 2: ptAmount
        uint256 w0;
        uint256 w1;
        uint256 w2;
        assembly {
            w0 := mload(add(cd, 36))
            w1 := mload(add(cd, 68))
            w2 := mload(add(cd, 100))
        }
        assertEq(address(uint160(w0)), address(market), "word0 = market");
        assertEq(w1, expectedSySpent, "word1 = sySpent (oracle valuation)");
        assertEq(w2, ptAmount, "word2 = ptAmount");
    }
}
