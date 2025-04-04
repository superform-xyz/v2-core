// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { console2 } from "forge-std/console2.sol";
import { BaseTest } from "../../../BaseTest.t.sol";
import { MockHook } from "../../../mocks/MockHook.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";

import { BaseHook } from "../../../../src/core/hooks/BaseHook.sol";
import { IOracle } from "../../../../src/vendor/morpho/IOracle.sol";
import { IMorphoBase, IMorphoStaticTyping, Id, MarketParams } from "../../../../src/vendor/morpho/IMorpho.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ISuperHook, ISuperHookResult } from "../../../../src/core/interfaces/ISuperHook.sol";
import { MorphoRepayHook } from "../../../../src/core/hooks/borrow/MorphoRepayHook.sol";

contract MockOracle is IOracle {
    function price() external pure returns (uint256) {
        return 2e36; // 1 collateral = 2 loan tokens
    }
}

contract MorphoRepayHookTest is BaseTest {
    MorphoRepayHook public hook;
    MockERC20 public loan;
    MockERC20 public collateral;
    MockOracle public oracle;
    address public irm;
    address public morpho;
    uint256 public amount;
    uint256 public lltv;

    IMorphoBase public morphoBase;
    IMorphoStaticTyping public morphoStaticTyping;

    function setUp() public override {
        super.setUp();

        // Deploy mock contracts
        loan = new MockERC20("Loan Token", "LOAN", 18);
        collateral = new MockERC20("Collateral Token", "COLL", 18);
        oracle = new MockOracle();
        irm = address(0x123); // Mock IRM address
        morpho = MORPHO;
        morphoBase = IMorphoBase(morpho);
        morphoStaticTyping = IMorphoStaticTyping(morpho);

        // Initialize hook
        hook = new MorphoRepayHook(address(this), morpho);

        // Set test values
        amount = 1000e18;
        lltv = 0.8e18; // 80% LLTV
    }

    function test_RepayHook_Constructor() public view {
        assertEq(address(hook.morpho()), morpho);
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_RepayHook_Constructor_RevertIf_ZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MorphoRepayHook(address(this), address(0));
    }

    function test_RepayHook_Build_PartialRepayment() public view {
        bytes memory data = _encodeData(false, false);
        Execution[] memory executions = hook.build(address(0), address(this), data);

        assertEq(executions.length, 3);

        // Check approve(0) call
        assertEq(executions[0].target, address(loan));
        assertEq(executions[0].value, 0);

        // Check approve(amount) call
        assertEq(executions[1].target, address(loan));
        assertEq(executions[1].value, 0);

        // Check repay call
        assertEq(executions[2].target, morpho);
        assertEq(executions[2].value, 0);
    }

    function test_RepayHook_Build_FullRepayment() public {
        // Give some tokens to test with
        _getTokens(address(loan), address(this), amount);

        bytes memory data = _encodeData(false, true);
        Execution[] memory executions = hook.build(address(0), address(this), data);

        assertEq(executions.length, 3);

        // Check approve(0) call
        assertEq(executions[0].target, address(loan));
        assertEq(executions[0].value, 0);

        // Check approve(full balance) call
        assertEq(executions[1].target, address(loan));
        assertEq(executions[1].value, 0);

        // Check repay call
        assertEq(executions[2].target, morpho);
        assertEq(executions[2].value, 0);
    }

    function test_RepayHook_Build_WithPrevHook() public {
        uint256 prevHookAmount = 2000e18;
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, address(loan)));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeData(true, false);
        Execution[] memory executions = hook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 3);
        // Similar assertions as test_Build_PartialRepayment()
    }

    function test_RepayHook_Build_RevertIf_InvalidAddresses() public {
        address oldLoan = address(loan);
        loan = MockERC20(address(0));
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), _encodeData(false, false));

        loan = MockERC20(oldLoan);
        collateral = MockERC20(address(0));
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), _encodeData(false, false));
    }

    function test_RepayHook_PreAndPostExecute() public {
        bytes memory data = _encodeData(false, false);

        // Give some tokens to test with
        _getTokens(address(loan), address(this), amount);

        hook.preExecute(address(0), address(this), data);
        assertEq(hook.outAmount(), amount);

        // Simulate repayment by burning tokens
        loan.burn(address(this), amount / 2);

        hook.postExecute(address(0), address(this), data);
        assertEq(hook.outAmount(), amount / 2);
    }

    function _encodeData(bool usePrevHook, bool isFullRepayment) internal view returns (bytes memory) {
        return abi.encodePacked(
            address(loan),
            address(collateral),
            address(oracle),
            irm,
            amount,
            lltv,
            usePrevHook,
            isFullRepayment
        );
    }
}
