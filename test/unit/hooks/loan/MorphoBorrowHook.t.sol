// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { console2 } from "forge-std/console2.sol";
import { BaseTest } from "../../../BaseTest.t.sol";
import { MockHook } from "../../../mocks/MockHook.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { BaseHook } from "../../../../src/core/hooks/BaseHook.sol";
import { IOracle } from "../../../../src/vendor/morpho/IOracle.sol";
import { IMorphoBase } from "../../../../src/vendor/morpho/IMorpho.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ISuperHook, ISuperHookResult } from "../../../../src/core/interfaces/ISuperHook.sol";
import { MorphoBorrowHook } from "../../../../src/core/hooks/loan/morpho/MorphoBorrowHook.sol";

struct MarketParams {
    address loanToken;
    address collateralToken;
    address oracle;
    address irm;
    uint256 lltv;
}

contract MockOracle is IOracle {
    function price() external pure returns (uint256) {
        return 2e36; // 1 collateral = 2 loan tokens
    }
}

contract MorphoBorrowHookTest is BaseTest {
    MorphoBorrowHook public hook;
    MockERC20 public loanToken;
    MockERC20 public collateralToken;
    MockOracle public oracle;
    address public irm;
    address public morpho;
    uint256 public amount;
    uint256 public lltv;
    uint256 public ltvRatio;

    IMorphoBase public morphoBase;

    function setUp() public override {
        super.setUp();

        // Deploy mock contracts
        loanToken = new MockERC20("Loan Token", "LOAN", 18);
        collateralToken = new MockERC20("Collateral Token", "COLL", 18);
        oracle = new MockOracle();
        irm = address(0x123); // Mock IRM address
        morpho = MORPHO;
        morphoBase = IMorphoBase(morpho);

        // Initialize hook
        hook = new MorphoBorrowHook(address(this), morpho);

        // Set test values
        amount = 1000e18;
        lltv = 0.8e18; // 80% LLTV
        ltvRatio = 0.75e18; // 75% LTV ratio
    }

    function test_Constructor() public view {
        assertEq(address(hook.morpho()), morpho);
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_Constructor_RevertIf_ZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MorphoBorrowHook(address(this), address(0));
    }

    function test_Build() public view {
        bytes memory data = _encodeData(false);
        Execution[] memory executions = hook.build(address(0), address(this), data);

        assertEq(executions.length, 4);

        // Check approve(0) call
        assertEq(executions[0].target, address(collateralToken));
        assertEq(executions[0].value, 0);

        // Check approve(collateralAmount) call
        assertEq(executions[1].target, address(collateralToken));
        assertEq(executions[1].value, 0);

        // Check supplyCollateral call
        assertEq(executions[2].target, morpho);
        assertEq(executions[2].value, 0);

        // Check borrow call
        assertEq(executions[3].target, morpho);
        assertEq(executions[3].value, 0);
    }

    function test_Build_WithPrevHook() public {
        uint256 prevHookAmount = 2000e18;
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, address(loanToken)));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeData(true);
        Execution[] memory executions = hook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 4);
    }

    function test_Build_RevertIf_ZeroAmount() public {
        amount = 0;
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(
            address(0),
            address(this),
            abi.encodePacked(
                address(loanToken),
                address(collateralToken),
                address(oracle),
                irm,
                uint256(0),
                ltvRatio,
                false,
                lltv,
                false
            )
        );
    }

    function test_Build_RevertIf_InvalidAddresses() public {
        address oldLoanToken = address(loanToken);
        loanToken = MockERC20(address(0));
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), _encodeData(false));

        loanToken = MockERC20(oldLoanToken);
        collateralToken = MockERC20(address(0));
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), _encodeData(false));
    }

    function _encodeData(bool usePrevHook) internal view returns (bytes memory) {
        return abi.encodePacked(
            address(loanToken),
            address(collateralToken),
            address(oracle),
            irm,
            amount,
            ltvRatio,
            usePrevHook,
            lltv,
            false
        );
    }
}
