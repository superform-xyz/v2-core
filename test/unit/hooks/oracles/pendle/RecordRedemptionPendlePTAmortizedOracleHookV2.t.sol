// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { RecordRedemptionPendlePTAmortizedOracleHookV2 } from
    "../../../../../src/hooks/oracles/pendle/RecordRedemptionPendlePTAmortizedOracleHookV2.sol";
import { IPendlePTAmortizedOracle } from "../../../../../src/vendor/pendle/IPendlePTAmortizedOracle.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../../../src/libraries/HookSubTypes.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { MockPendlePTAmortizedOracle } from "../../../../mocks/MockPendlePTAmortizedOracle.sol";
import { MockPendleRouterSwapHook } from "../../../../mocks/MockPendleRouterSwapHook.sol";

/// @title RecordRedemptionPendlePTAmortizedOracleHookV2Test
/// @notice Unit tests for RecordRedemptionPendlePTAmortizedOracleHookV2
contract RecordRedemptionPendlePTAmortizedOracleHookV2Test is Test {
    RecordRedemptionPendlePTAmortizedOracleHookV2 public hook;
    MockPendlePTAmortizedOracle public oracle;
    MockPendleRouterSwapHook public prevHook;

    address public market = makeAddr("market");
    address public account = makeAddr("account");

    // Data structure offsets
    uint256 constant MARKET_POSITION = 0;
    uint256 constant PT_SOLD_POSITION = 20;
    uint256 constant USE_PREV_HOOK_AMOUNT_POSITION = 52;

    function setUp() public {
        oracle = new MockPendlePTAmortizedOracle();
        prevHook = new MockPendleRouterSwapHook();
        hook = new RecordRedemptionPendlePTAmortizedOracleHookV2(address(oracle));
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
        new RecordRedemptionPendlePTAmortizedOracleHookV2(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                            VERSION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Version_IsTwo() public view {
        assertEq(hook.VERSION(), 2);
    }

    /*//////////////////////////////////////////////////////////////
                        BUILD HOOK EXECUTIONS TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Tests realistic flow: ptSold passed directly (typical case)
    /// @dev In typical redemption: RecordRedemptionHook -> PendleRouterSwapHook (swapExactPtForToken)
    ///      ptSold is the INPUT to the swap, so it's known ahead of time
    function test_Build_ReturnsCorrectExecution_PtSoldDirect() public view {
        uint256 ptSold = 100e18; // Known ahead of time - input to swapExactPtForToken

        // usePrevHookAmount=false: ptSold passed directly
        bytes memory data = _encodeData(market, ptSold, false);

        Execution[] memory executions = hook.build(address(0), account, data);

        // build() returns [preExecute, hookExecution, postExecute]
        assertEq(executions.length, 3);
        // Middle execution (index 1) is the oracle call
        assertEq(executions[1].target, address(oracle));
        assertEq(executions[1].value, 0);
        assertEq(executions[1].callData, abi.encodeCall(IPendlePTAmortizedOracle.recordRedemption, (market, ptSold)));
    }

    /// @notice Tests usePrevHookAmount when PT comes from another source (not typical swap flow)
    /// @dev Useful when PT comes from: transfer hook, unstake hook, or other PT source
    ///      NOT from PendleRouterSwapHook (which outputs underlying token, not PT)
    function test_Build_UsesPrevHookAmount_PtFromAnotherSource() public {
        uint256 staticPtSold = 100e18;
        uint256 ptFromPrevHook = 150e18; // PT from transfer/unstake hook

        // Simulate PT coming from another hook (not swapExactPtForToken)
        prevHook.setOutAmount(account, ptFromPrevHook);

        // usePrevHookAmount=true: ptSold comes from prev hook
        bytes memory data = _encodeData(market, staticPtSold, true);

        Execution[] memory executions = hook.build(address(prevHook), account, data);

        // build() returns [preExecute, hookExecution, postExecute]
        assertEq(executions.length, 3);
        // Should use ptFromPrevHook instead of staticPtSold
        assertEq(
            executions[1].callData, abi.encodeCall(IPendlePTAmortizedOracle.recordRedemption, (market, ptFromPrevHook))
        );
    }

    function test_Build_RevertsOnZeroMarket() public {
        bytes memory data = _encodeData(address(0), 100e18, false);

        vm.expectRevert(RecordRedemptionPendlePTAmortizedOracleHookV2.MARKET_NOT_VALID.selector);
        hook.build(address(0), account, data);
    }

    function test_Build_RevertsOnZeroPtSold() public {
        bytes memory data = _encodeData(market, 0, false);

        vm.expectRevert(RecordRedemptionPendlePTAmortizedOracleHookV2.PT_SOLD_NOT_VALID.selector);
        hook.build(address(0), account, data);
    }

    function test_Build_RevertsOnZeroPtSoldFromPrevHook() public {
        prevHook.setOutAmount(account, 0);
        bytes memory data = _encodeData(market, 0, true);

        vm.expectRevert(RecordRedemptionPendlePTAmortizedOracleHookV2.PT_SOLD_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                          DECODE FUNCTIONS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DecodeUsePrevHookAmount_True() public view {
        bytes memory data = _encodeData(market, 100e18, true);
        assertTrue(hook.decodeUsePrevHookAmount(data));
    }

    function test_DecodeUsePrevHookAmount_False() public view {
        bytes memory data = _encodeData(market, 100e18, false);
        assertFalse(hook.decodeUsePrevHookAmount(data));
    }

    function test_DecodeMarket() public view {
        bytes memory data = _encodeData(market, 100e18, false);
        assertEq(hook.decodeMarket(data), market);
    }

    function test_DecodePtSold() public view {
        uint256 ptSold = 456e18;
        bytes memory data = _encodeData(market, ptSold, false);
        assertEq(hook.decodePtSold(data), ptSold);
    }

    /*//////////////////////////////////////////////////////////////
                            INSPECT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Inspect_ReturnsMarket() public view {
        bytes memory data = _encodeData(market, 100e18, false);
        bytes memory inspected = hook.inspect(data);
        assertEq(inspected, abi.encodePacked(market));
    }

    /*//////////////////////////////////////////////////////////////
                        PRE/POST EXECUTE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PreExecute_NoOp() public {
        bytes memory data = _encodeData(market, 100e18, false);
        // preExecute requires msg.sender == account
        vm.prank(account);
        hook.setExecutionContext(account);
        vm.prank(account);
        // Should not revert - this hook has no-op pre/post execute
        hook.preExecute(address(0), account, data);
    }

    function test_PostExecute_NoOp() public {
        bytes memory data = _encodeData(market, 100e18, false);
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

    function testFuzz_Build_ValidAmounts(uint256 ptSold) public view {
        ptSold = bound(ptSold, 1, type(uint128).max);

        bytes memory data = _encodeData(market, ptSold, false);
        Execution[] memory executions = hook.build(address(0), account, data);

        // build() returns [preExecute, hookExecution, postExecute]
        assertEq(executions.length, 3);
        assertEq(executions[1].callData, abi.encodeCall(IPendlePTAmortizedOracle.recordRedemption, (market, ptSold)));
    }

    function testFuzz_Build_WithPrevHookAmount(uint256 prevAmount) public {
        prevAmount = bound(prevAmount, 1, type(uint128).max);

        prevHook.setOutAmount(account, prevAmount);
        bytes memory data = _encodeData(market, 0, true);

        Execution[] memory executions = hook.build(address(prevHook), account, data);

        // build() returns [preExecute, hookExecution, postExecute]
        assertEq(executions.length, 3);
        assertEq(
            executions[1].callData, abi.encodeCall(IPendlePTAmortizedOracle.recordRedemption, (market, prevAmount))
        );
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _encodeData(address _market, uint256 _ptSold, bool _usePrevHookAmount) internal pure returns (bytes memory) {
        return abi.encodePacked(_market, _ptSold, _usePrevHookAmount);
    }
}
