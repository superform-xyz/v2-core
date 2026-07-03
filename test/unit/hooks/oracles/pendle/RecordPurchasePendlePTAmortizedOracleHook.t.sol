// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { RecordPurchasePendlePTAmortizedOracleHook } from
    "../../../../../src/hooks/oracles/pendle/RecordPurchasePendlePTAmortizedOracleHook.sol";
import { IPendlePTAmortizedOracle } from "../../../../../src/vendor/pendle/IPendlePTAmortizedOracle.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../../../src/libraries/HookSubTypes.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { MockPendlePTAmortizedOracle } from "../../../../mocks/MockPendlePTAmortizedOracle.sol";
import { MockPendleRouterSwapHook } from "../../../../mocks/MockPendleRouterSwapHook.sol";

/// @title RecordPurchasePendlePTAmortizedOracleHookTest
/// @notice Unit tests for RecordPurchasePendlePTAmortizedOracleHook
contract RecordPurchasePendlePTAmortizedOracleHookTest is Test {
    RecordPurchasePendlePTAmortizedOracleHook public hook;
    MockPendlePTAmortizedOracle public oracle;
    MockPendleRouterSwapHook public prevHook;

    address public market = makeAddr("market");
    address public account = makeAddr("account");

    // Data structure offsets (include 52-byte placeholder)
    uint256 constant MARKET_POSITION = 52;
    uint256 constant SY_SPENT_POSITION = 72;
    uint256 constant PT_AMOUNT_POSITION = 104;
    uint256 constant USE_PREV_HOOK_AMOUNT_POSITION = 136;

    function setUp() public {
        oracle = new MockPendlePTAmortizedOracle();
        prevHook = new MockPendleRouterSwapHook();
        hook = new RecordPurchasePendlePTAmortizedOracleHook(address(oracle));
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
        new RecordPurchasePendlePTAmortizedOracleHook(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                        BUILD HOOK EXECUTIONS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Build_ReturnsCorrectExecution() public view {
        uint256 sySpent = 100e18;
        uint256 ptAmount = 110e18;
        bytes memory data = _encodeData(market, sySpent, ptAmount, false);

        Execution[] memory executions = hook.build(address(0), account, data);

        // build() returns [preExecute, hookExecution, postExecute]
        assertEq(executions.length, 3);
        // Middle execution (index 1) is the oracle call
        assertEq(executions[1].target, address(oracle));
        assertEq(executions[1].value, 0);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IPendlePTAmortizedOracle.recordPurchase, (market, sySpent, ptAmount))
        );
    }

    /// @notice Tests realistic flow: PendleRouterSwapHook (swapExactTokenForPt) → RecordPurchaseHook
    /// @dev ptAmount comes from swap hook's outAmount (PT received from swap)
    function test_Build_UsesPrevHookAmount_RealisticFlow() public {
        uint256 sySpent = 100e18;
        uint256 staticPtAmount = 110e18;
        uint256 ptFromSwapHook = 120e18; // PT received from PendleRouterSwapHook

        // Simulate PendleRouterSwapHook output (PT received)
        prevHook.setOutAmount(account, ptFromSwapHook);

        // usePrevHookAmount=true: ptAmount comes from swap hook's outAmount
        bytes memory data = _encodeData(market, sySpent, staticPtAmount, true);

        Execution[] memory executions = hook.build(address(prevHook), account, data);

        // build() returns [preExecute, hookExecution, postExecute]
        assertEq(executions.length, 3);
        // Should use ptFromSwapHook instead of staticPtAmount
        assertEq(
            executions[1].callData,
            abi.encodeCall(IPendlePTAmortizedOracle.recordPurchase, (market, sySpent, ptFromSwapHook))
        );
    }

    function test_Build_RevertsOnZeroMarket() public {
        bytes memory data = _encodeData(address(0), 100e18, 110e18, false);

        vm.expectRevert(RecordPurchasePendlePTAmortizedOracleHook.MARKET_NOT_VALID.selector);
        hook.build(address(0), account, data);
    }

    function test_Build_RevertsOnZeroSySpent() public {
        bytes memory data = _encodeData(market, 0, 110e18, false);

        vm.expectRevert(RecordPurchasePendlePTAmortizedOracleHook.SY_SPENT_NOT_VALID.selector);
        hook.build(address(0), account, data);
    }

    function test_Build_RevertsOnZeroPtAmount() public {
        bytes memory data = _encodeData(market, 100e18, 0, false);

        vm.expectRevert(RecordPurchasePendlePTAmortizedOracleHook.PT_AMOUNT_NOT_VALID.selector);
        hook.build(address(0), account, data);
    }

    function test_Build_RevertsOnZeroPtAmountFromPrevHook() public {
        prevHook.setOutAmount(account, 0);
        bytes memory data = _encodeData(market, 100e18, 0, true);

        vm.expectRevert(RecordPurchasePendlePTAmortizedOracleHook.PT_AMOUNT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                          DECODE FUNCTIONS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DecodeUsePrevHookAmount_True() public view {
        bytes memory data = _encodeData(market, 100e18, 110e18, true);
        assertTrue(hook.decodeUsePrevHookAmount(data));
    }

    function test_DecodeUsePrevHookAmount_False() public view {
        bytes memory data = _encodeData(market, 100e18, 110e18, false);
        assertFalse(hook.decodeUsePrevHookAmount(data));
    }

    function test_DecodeMarket() public view {
        bytes memory data = _encodeData(market, 100e18, 110e18, false);
        assertEq(hook.decodeMarket(data), market);
    }

    function test_DecodeSySpent() public view {
        uint256 sySpent = 123e18;
        bytes memory data = _encodeData(market, sySpent, 110e18, false);
        assertEq(hook.decodeSySpent(data), sySpent);
    }

    function test_DecodePtAmount() public view {
        uint256 ptAmount = 456e18;
        bytes memory data = _encodeData(market, 100e18, ptAmount, false);
        assertEq(hook.decodePtAmount(data), ptAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            INSPECT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Inspect_ReturnsMarket() public view {
        bytes memory data = _encodeData(market, 100e18, 110e18, false);
        bytes memory inspected = hook.inspect(data);
        assertEq(inspected, abi.encodePacked(market));
    }

    /*//////////////////////////////////////////////////////////////
                        PRE/POST EXECUTE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PreExecute_NoOp() public {
        bytes memory data = _encodeData(market, 100e18, 110e18, false);
        // preExecute requires msg.sender == account
        vm.prank(account);
        hook.setExecutionContext(account);
        vm.prank(account);
        // Should not revert - this hook has no-op pre/post execute
        hook.preExecute(address(0), account, data);
    }

    function test_PostExecute_NoOp() public {
        bytes memory data = _encodeData(market, 100e18, 110e18, false);
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

    function testFuzz_Build_ValidAmounts(uint256 sySpent, uint256 ptAmount) public view {
        sySpent = bound(sySpent, 1, type(uint128).max);
        ptAmount = bound(ptAmount, 1, type(uint128).max);

        bytes memory data = _encodeData(market, sySpent, ptAmount, false);
        Execution[] memory executions = hook.build(address(0), account, data);

        // build() returns [preExecute, hookExecution, postExecute]
        assertEq(executions.length, 3);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IPendlePTAmortizedOracle.recordPurchase, (market, sySpent, ptAmount))
        );
    }

    function testFuzz_Build_WithPrevHookAmount(uint256 sySpent, uint256 prevAmount) public {
        sySpent = bound(sySpent, 1, type(uint128).max);
        prevAmount = bound(prevAmount, 1, type(uint128).max);

        prevHook.setOutAmount(account, prevAmount);
        bytes memory data = _encodeData(market, sySpent, 0, true);

        // Note: This will fail with PT_AMOUNT_NOT_VALID if prevAmount is 0
        // but we bounded it to be >= 1
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        // build() returns [preExecute, hookExecution, postExecute]
        assertEq(executions.length, 3);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IPendlePTAmortizedOracle.recordPurchase, (market, sySpent, prevAmount))
        );
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _encodeData(
        address _market,
        uint256 _sySpent,
        uint256 _ptAmount,
        bool _usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(bytes(new bytes(52)), _market, _sySpent, _ptAmount, _usePrevHookAmount);
    }
}
