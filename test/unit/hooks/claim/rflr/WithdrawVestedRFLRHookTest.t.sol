// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

// Superform
import { Helpers } from "../../../../utils/Helpers.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { BytesLib } from "../../../../../src/vendor/BytesLib.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { WithdrawVestedRFLRHook } from "../../../../../src/hooks/claim/flare/WithdrawVestedRFLRHook.sol";
import { IRNat } from "../../../../../src/vendor/flare/IRNat.sol";

contract WithdrawVestedRFLRHookTest is Helpers {
    WithdrawVestedRFLRHook public hook;

    address public rNat;
    address public wflr;
    address public account;

    function setUp() public {
        rNat = makeAddr("rNat");
        wflr = makeAddr("wflr");
        account = makeAddr("account");

        hook = new WithdrawVestedRFLRHook(rNat, wflr);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(hook.RNAT(), rNat);
        assertEq(hook.WFLR(), wflr);
    }

    function test_Constructor_RevertIf_RNatZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new WithdrawVestedRFLRHook(address(0), wflr);
    }

    function test_Constructor_RevertIf_WFLRZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new WithdrawVestedRFLRHook(rNat, address(0));
    }

    function test_Constructor_RevertIf_BothZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new WithdrawVestedRFLRHook(address(0), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                              BUILD TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Build() public {
        uint256 rNatBalance = 100 ether;
        uint256 lockedBalance = 40 ether;
        uint128 expectedWithdrawAmount = 60 ether;

        // Mock getBalancesOf to return vested amount
        vm.mockCall(
            rNat,
            abi.encodeCall(IRNat.getBalancesOf, (account)),
            abi.encode(uint256(0), rNatBalance, lockedBalance)
        );

        Execution[] memory executions = hook.build(address(0), account, "");

        // preExecute + withdraw + postExecute = 3
        assertEq(executions.length, 3);
        assertEq(executions[0].target, address(hook)); // preExecute
        assertEq(executions[1].target, rNat); // withdraw
        assertEq(executions[1].value, 0);
        assertEq(executions[2].target, address(hook)); // postExecute

        // Verify calldata is withdraw(vestedAmount, true)
        bytes memory expectedCallData = abi.encodeCall(IRNat.withdraw, (expectedWithdrawAmount, true));
        assertEq(keccak256(executions[1].callData), keccak256(expectedCallData));
    }

    function test_Build_FullyVested() public {
        uint256 rNatBalance = 100 ether;
        uint256 lockedBalance = 0;
        uint128 expectedWithdrawAmount = 100 ether;

        vm.mockCall(
            rNat,
            abi.encodeCall(IRNat.getBalancesOf, (account)),
            abi.encode(uint256(0), rNatBalance, lockedBalance)
        );

        Execution[] memory executions = hook.build(address(0), account, "");
        assertEq(executions.length, 3);

        bytes memory expectedCallData = abi.encodeCall(IRNat.withdraw, (expectedWithdrawAmount, true));
        assertEq(keccak256(executions[1].callData), keccak256(expectedCallData));
    }

    function test_Build_RevertIf_NothingVested_ZeroBalance() public {
        vm.mockCall(
            rNat, abi.encodeCall(IRNat.getBalancesOf, (account)), abi.encode(uint256(0), uint256(0), uint256(0))
        );

        vm.expectRevert(WithdrawVestedRFLRHook.NOTHING_TO_WITHDRAW.selector);
        hook.build(address(0), account, "");
    }

    function test_Build_RevertIf_NothingVested_FullyLocked() public {
        uint256 rNatBalance = 100 ether;
        uint256 lockedBalance = 100 ether;

        vm.mockCall(
            rNat,
            abi.encodeCall(IRNat.getBalancesOf, (account)),
            abi.encode(uint256(0), rNatBalance, lockedBalance)
        );

        vm.expectRevert(WithdrawVestedRFLRHook.NOTHING_TO_WITHDRAW.selector);
        hook.build(address(0), account, "");
    }

    function test_Build_RevertIf_NothingVested_LockedExceedsBalance() public {
        // Edge case: lockedBalance > rNatBalance (possible after partial withdrawals)
        uint256 rNatBalance = 50 ether;
        uint256 lockedBalance = 80 ether;

        vm.mockCall(
            rNat,
            abi.encodeCall(IRNat.getBalancesOf, (account)),
            abi.encode(uint256(0), rNatBalance, lockedBalance)
        );

        vm.expectRevert(WithdrawVestedRFLRHook.NOTHING_TO_WITHDRAW.selector);
        hook.build(address(0), account, "");
    }

    function test_Build_RevertIf_SafeCastOverflow() public {
        // Mock values where vestedAmount > type(uint128).max
        uint256 rNatBalance = type(uint256).max;
        uint256 lockedBalance = 0;

        vm.mockCall(
            rNat,
            abi.encodeCall(IRNat.getBalancesOf, (account)),
            abi.encode(uint256(0), rNatBalance, lockedBalance)
        );

        vm.expectRevert(
            abi.encodeWithSelector(SafeCast.SafeCastOverflowedUintDowncast.selector, 128, rNatBalance)
        );
        hook.build(address(0), account, "");
    }

    /*//////////////////////////////////////////////////////////////
                        PRE/POST EXECUTE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PreAndPostExecute() public {
        uint256 initialWflrBalance = 200 ether;
        uint256 withdrawnAmount = 60 ether;

        // Mock WFLR.balanceOf for pre
        vm.mockCall(wflr, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialWflrBalance));

        hook.setExecutionContext(account);

        vm.prank(account);
        hook.preExecute(address(0), account, "");
        assertEq(hook.getOutAmount(account), initialWflrBalance);

        // Mock increased WFLR balance for post
        vm.mockCall(
            wflr, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialWflrBalance + withdrawnAmount)
        );

        vm.prank(account);
        hook.postExecute(address(0), account, "");
        assertEq(hook.getOutAmount(account), withdrawnAmount);
    }

    function test_PreExecute_SetsAsset() public {
        vm.mockCall(wflr, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(0));

        hook.setExecutionContext(account);

        vm.prank(account);
        hook.preExecute(address(0), account, "");

        assertEq(hook.asset(), wflr);
    }

    function test_PostExecute_ZeroDelta() public {
        uint256 initialWflrBalance = 100 ether;

        vm.mockCall(wflr, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialWflrBalance));
        hook.setExecutionContext(account);

        vm.prank(account);
        hook.preExecute(address(0), account, "");

        // Balance unchanged — delta is 0
        vm.mockCall(wflr, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialWflrBalance));

        vm.prank(account);
        hook.postExecute(address(0), account, "");
        assertEq(hook.getOutAmount(account), 0);
    }

    /*//////////////////////////////////////////////////////////////
                       SLIPPAGE PROTECTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PostExecute_MinOut_Passes() public {
        uint256 initialWflrBalance = 100 ether;
        uint256 withdrawnAmount = 60 ether;
        uint256 minOut = 60 ether;

        vm.mockCall(wflr, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialWflrBalance));
        hook.setExecutionContext(account);

        vm.prank(account);
        hook.preExecute(address(0), account, "");

        vm.mockCall(
            wflr, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialWflrBalance + withdrawnAmount)
        );

        bytes memory data = abi.encode(minOut);

        vm.prank(account);
        hook.postExecute(address(0), account, data);
        assertEq(hook.getOutAmount(account), withdrawnAmount);
    }

    function test_PostExecute_MinOut_ExactlyMet() public {
        uint256 initialWflrBalance = 100 ether;
        uint256 withdrawnAmount = 30 ether;
        uint256 minOut = 30 ether;

        vm.mockCall(wflr, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialWflrBalance));
        hook.setExecutionContext(account);

        vm.prank(account);
        hook.preExecute(address(0), account, "");

        vm.mockCall(
            wflr, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialWflrBalance + withdrawnAmount)
        );

        bytes memory data = abi.encode(minOut);

        vm.prank(account);
        hook.postExecute(address(0), account, data);
        assertEq(hook.getOutAmount(account), withdrawnAmount);
    }

    function test_PostExecute_MinOut_Exceeded_Reverts() public {
        uint256 initialWflrBalance = 100 ether;
        uint256 withdrawnAmount = 30 ether;
        uint256 minOut = 50 ether; // delta (30) < minOut (50)

        vm.mockCall(wflr, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialWflrBalance));
        hook.setExecutionContext(account);

        vm.prank(account);
        hook.preExecute(address(0), account, "");

        vm.mockCall(
            wflr, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialWflrBalance + withdrawnAmount)
        );

        bytes memory data = abi.encode(minOut);

        vm.expectRevert(WithdrawVestedRFLRHook.SLIPPAGE_EXCEEDED.selector);
        vm.prank(account);
        hook.postExecute(address(0), account, data);
    }

    function test_PostExecute_MinOut_ZeroDelta_Reverts() public {
        uint256 initialWflrBalance = 100 ether;
        uint256 minOut = 1 ether;

        vm.mockCall(wflr, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialWflrBalance));
        hook.setExecutionContext(account);

        vm.prank(account);
        hook.preExecute(address(0), account, "");

        // Balance unchanged — delta is 0
        vm.mockCall(wflr, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialWflrBalance));

        bytes memory data = abi.encode(minOut);

        vm.expectRevert(WithdrawVestedRFLRHook.SLIPPAGE_EXCEEDED.selector);
        vm.prank(account);
        hook.postExecute(address(0), account, data);
    }

    function test_PostExecute_MinOut_ZeroValue_NoCheck() public {
        uint256 initialWflrBalance = 100 ether;
        uint256 withdrawnAmount = 1; // tiny delta

        vm.mockCall(wflr, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialWflrBalance));
        hook.setExecutionContext(account);

        vm.prank(account);
        hook.preExecute(address(0), account, "");

        vm.mockCall(
            wflr, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialWflrBalance + withdrawnAmount)
        );

        // minOut = 0 means no check
        bytes memory data = abi.encode(uint256(0));

        vm.prank(account);
        hook.postExecute(address(0), account, data);
        assertEq(hook.getOutAmount(account), withdrawnAmount);
    }

    function test_PostExecute_EmptyData_NoSlippageCheck() public {
        uint256 initialWflrBalance = 100 ether;
        uint256 withdrawnAmount = 1; // tiny delta, no revert since no minOut

        vm.mockCall(wflr, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialWflrBalance));
        hook.setExecutionContext(account);

        vm.prank(account);
        hook.preExecute(address(0), account, "");

        vm.mockCall(
            wflr, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialWflrBalance + withdrawnAmount)
        );

        // Empty data — no slippage check
        vm.prank(account);
        hook.postExecute(address(0), account, "");
        assertEq(hook.getOutAmount(account), withdrawnAmount);
    }

    function test_PostExecute_ShortData_NoSlippageCheck() public {
        uint256 initialWflrBalance = 100 ether;
        uint256 withdrawnAmount = 1;

        vm.mockCall(wflr, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialWflrBalance));
        hook.setExecutionContext(account);

        vm.prank(account);
        hook.preExecute(address(0), account, "");

        vm.mockCall(
            wflr, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialWflrBalance + withdrawnAmount)
        );

        // Only 16 bytes — less than 32, no slippage check
        bytes memory data = abi.encodePacked(uint128(999 ether));

        vm.prank(account);
        hook.postExecute(address(0), account, data);
        assertEq(hook.getOutAmount(account), withdrawnAmount);
    }

    /*//////////////////////////////////////////////////////////////
                           INSPECT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Inspector() public view {
        bytes memory argsEncoded = hook.inspect("");

        assertEq(argsEncoded.length, 20);
        assertEq(BytesLib.toAddress(argsEncoded, 0), rNat);
    }
}
