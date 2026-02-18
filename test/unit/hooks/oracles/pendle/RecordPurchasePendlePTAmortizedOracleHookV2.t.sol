// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { RecordPurchasePendlePTAmortizedOracleHookV2 } from
    "../../../../../src/hooks/oracles/pendle/RecordPurchasePendlePTAmortizedOracleHookV2.sol";
import { IPendlePTAmortizedOracleV2 } from "../../../../../src/vendor/pendle/IPendlePTAmortizedOracleV2.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../../../src/libraries/HookSubTypes.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { MockPendlePTAmortizedOracleV2 } from "../../../../mocks/MockPendlePTAmortizedOracleV2.sol";
import { MockPendleRouterSwapHook } from "../../../../mocks/MockPendleRouterSwapHook.sol";

/// @title RecordPurchasePendlePTAmortizedOracleHookV2Test
/// @notice Unit tests for RecordPurchasePendlePTAmortizedOracleHookV2
/// @dev V2 differences from V1:
///      - No sySpent parameter (oracle calculates from PT rate)
///      - Includes twapDuration parameter for per-call TWAP configuration
contract RecordPurchasePendlePTAmortizedOracleHookV2Test is Test {
    RecordPurchasePendlePTAmortizedOracleHookV2 public hook;
    MockPendlePTAmortizedOracleV2 public oracle;
    MockPendleRouterSwapHook public prevHook;

    address public market = makeAddr("market");
    address public account = makeAddr("account");

    // V2 Data structure offsets (different from V1)
    uint256 constant MARKET_POSITION = 0;
    uint256 constant PT_AMOUNT_POSITION = 20;
    uint256 constant TWAP_DURATION_POSITION = 52;
    uint256 constant USE_PREV_HOOK_AMOUNT_POSITION = 56;

    // Common TWAP durations
    uint32 constant TWAP_15_MIN = 900;
    uint32 constant TWAP_SPOT = 0;

    function setUp() public {
        oracle = new MockPendlePTAmortizedOracleV2();
        prevHook = new MockPendleRouterSwapHook();
        hook = new RecordPurchasePendlePTAmortizedOracleHookV2(address(oracle));
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_SetsOracle() public view {
        assertEq(address(hook.ORACLE()), address(oracle));
    }

    function test_Constructor_SetsHookType() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_Constructor_SetsSubtype() public view {
        assertEq(hook.subtype(), HookSubTypes.PTYT);
    }

    function test_Constructor_RevertsOnZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new RecordPurchasePendlePTAmortizedOracleHookV2(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                        BUILD HOOK EXECUTIONS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Build_ReturnsCorrectExecution() public view {
        uint256 ptAmount = 110e18;
        uint32 twapDuration = TWAP_15_MIN;
        bytes memory data = _encodeData(market, ptAmount, twapDuration, false);

        Execution[] memory executions = hook.build(address(0), account, data);

        // build() returns [preExecute, hookExecution, postExecute]
        assertEq(executions.length, 3);
        // Middle execution (index 1) is the oracle call
        assertEq(executions[1].target, address(oracle));
        assertEq(executions[1].value, 0);
        // V2: Call includes twapDuration, no sySpent
        assertEq(
            executions[1].callData,
            abi.encodeCall(IPendlePTAmortizedOracleV2.recordPurchase, (market, ptAmount, twapDuration))
        );
    }

    function test_Build_SpotPrice() public view {
        uint256 ptAmount = 100e18;
        uint32 twapDuration = TWAP_SPOT; // 0 = spot price
        bytes memory data = _encodeData(market, ptAmount, twapDuration, false);

        Execution[] memory executions = hook.build(address(0), account, data);

        assertEq(executions.length, 3);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IPendlePTAmortizedOracleV2.recordPurchase, (market, ptAmount, TWAP_SPOT))
        );
    }

    /// @notice Tests realistic flow: PendleRouterSwapHook (swapExactTokenForPt) → RecordPurchaseHookV2
    /// @dev ptAmount comes from swap hook's outAmount (PT received from swap)
    function test_Build_UsesPrevHookAmount_RealisticFlow() public {
        uint256 staticPtAmount = 110e18;
        uint256 ptFromSwapHook = 120e18; // PT received from PendleRouterSwapHook
        uint32 twapDuration = TWAP_15_MIN;

        // Simulate PendleRouterSwapHook output (PT received)
        prevHook.setOutAmount(account, ptFromSwapHook);

        // usePrevHookAmount=true: ptAmount comes from swap hook's outAmount
        bytes memory data = _encodeData(market, staticPtAmount, twapDuration, true);

        Execution[] memory executions = hook.build(address(prevHook), account, data);

        // build() returns [preExecute, hookExecution, postExecute]
        assertEq(executions.length, 3);
        // Should use ptFromSwapHook instead of staticPtAmount
        assertEq(
            executions[1].callData,
            abi.encodeCall(IPendlePTAmortizedOracleV2.recordPurchase, (market, ptFromSwapHook, twapDuration))
        );
    }

    function test_Build_RevertsOnZeroMarket() public {
        bytes memory data = _encodeData(address(0), 110e18, TWAP_15_MIN, false);

        vm.expectRevert(RecordPurchasePendlePTAmortizedOracleHookV2.MARKET_NOT_VALID.selector);
        hook.build(address(0), account, data);
    }

    function test_Build_RevertsOnZeroPtAmount() public {
        bytes memory data = _encodeData(market, 0, TWAP_15_MIN, false);

        vm.expectRevert(RecordPurchasePendlePTAmortizedOracleHookV2.PT_AMOUNT_NOT_VALID.selector);
        hook.build(address(0), account, data);
    }

    function test_Build_RevertsOnZeroPtAmountFromPrevHook() public {
        prevHook.setOutAmount(account, 0);
        bytes memory data = _encodeData(market, 0, TWAP_15_MIN, true);

        vm.expectRevert(RecordPurchasePendlePTAmortizedOracleHookV2.PT_AMOUNT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                          DECODE FUNCTIONS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DecodeUsePrevHookAmount_True() public view {
        bytes memory data = _encodeData(market, 110e18, TWAP_15_MIN, true);
        assertTrue(hook.decodeUsePrevHookAmount(data));
    }

    function test_DecodeUsePrevHookAmount_False() public view {
        bytes memory data = _encodeData(market, 110e18, TWAP_15_MIN, false);
        assertFalse(hook.decodeUsePrevHookAmount(data));
    }

    function test_DecodeMarket() public view {
        bytes memory data = _encodeData(market, 110e18, TWAP_15_MIN, false);
        assertEq(hook.decodeMarket(data), market);
    }

    function test_DecodePtAmount() public view {
        uint256 ptAmount = 456e18;
        bytes memory data = _encodeData(market, ptAmount, TWAP_15_MIN, false);
        assertEq(hook.decodePtAmount(data), ptAmount);
    }

    function test_DecodeTwapDuration() public view {
        uint32 twapDuration = 600; // 10 min TWAP
        bytes memory data = _encodeData(market, 100e18, twapDuration, false);
        assertEq(hook.decodeTwapDuration(data), twapDuration);
    }

    function test_DecodeTwapDuration_Spot() public view {
        bytes memory data = _encodeData(market, 100e18, TWAP_SPOT, false);
        assertEq(hook.decodeTwapDuration(data), TWAP_SPOT);
    }

    /*//////////////////////////////////////////////////////////////
                            INSPECT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Inspect_ReturnsMarket() public view {
        bytes memory data = _encodeData(market, 110e18, TWAP_15_MIN, false);
        bytes memory inspected = hook.inspect(data);
        assertEq(inspected, abi.encodePacked(market));
    }

    /*//////////////////////////////////////////////////////////////
                        PRE/POST EXECUTE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PreExecute_NoOp() public {
        bytes memory data = _encodeData(market, 110e18, TWAP_15_MIN, false);
        // preExecute requires msg.sender == account
        vm.prank(account);
        hook.setExecutionContext(account);
        vm.prank(account);
        // Should not revert - this hook has no-op pre/post execute
        hook.preExecute(address(0), account, data);
    }

    function test_PostExecute_NoOp() public {
        bytes memory data = _encodeData(market, 110e18, TWAP_15_MIN, false);
        // preExecute/postExecute require msg.sender == account
        vm.prank(account);
        hook.setExecutionContext(account);
        vm.prank(account);
        // Need to call preExecute first
        hook.preExecute(address(0), account, data);
        vm.prank(account);
        // Should not revert
        hook.postExecute(address(0), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Build_ValidAmounts(uint256 ptAmount, uint32 twapDuration) public view {
        ptAmount = bound(ptAmount, 1, type(uint128).max);
        twapDuration = uint32(bound(twapDuration, 0, 3600)); // 0 to 1 hour

        bytes memory data = _encodeData(market, ptAmount, twapDuration, false);
        Execution[] memory executions = hook.build(address(0), account, data);

        // build() returns [preExecute, hookExecution, postExecute]
        assertEq(executions.length, 3);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IPendlePTAmortizedOracleV2.recordPurchase, (market, ptAmount, twapDuration))
        );
    }

    function testFuzz_Build_WithPrevHookAmount(uint256 prevAmount, uint32 twapDuration) public {
        prevAmount = bound(prevAmount, 1, type(uint128).max);
        twapDuration = uint32(bound(twapDuration, 0, 3600));

        prevHook.setOutAmount(account, prevAmount);
        bytes memory data = _encodeData(market, 0, twapDuration, true);

        // Note: This will fail with PT_AMOUNT_NOT_VALID if prevAmount is 0
        // but we bounded it to be >= 1
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        // build() returns [preExecute, hookExecution, postExecute]
        assertEq(executions.length, 3);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IPendlePTAmortizedOracleV2.recordPurchase, (market, prevAmount, twapDuration))
        );
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Encode V2 hook data
    /// @dev V2 structure: market (20) + ptAmount (32) + twapDuration (4) + usePrevHookAmount (1)
    function _encodeData(
        address _market,
        uint256 _ptAmount,
        uint32 _twapDuration,
        bool _usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(_market, _ptAmount, _twapDuration, _usePrevHookAmount);
    }
}
