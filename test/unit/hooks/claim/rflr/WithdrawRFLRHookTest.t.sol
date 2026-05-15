// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { Helpers } from "../../../../utils/Helpers.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { BytesLib } from "../../../../../src/vendor/BytesLib.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { WithdrawRFLRHook } from "../../../../../src/hooks/claim/flare/WithdrawRFLRHook.sol";
import { IRNat } from "../../../../../src/vendor/flare/IRNat.sol";

contract WithdrawRFLRHookTest is Helpers {
    WithdrawRFLRHook public hook;

    address public rNat;
    address public wflr;
    address public account;

    function setUp() public {
        rNat = makeAddr("rNat");
        wflr = makeAddr("wflr");
        account = makeAddr("account");

        hook = new WithdrawRFLRHook(rNat, wflr);
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
        new WithdrawRFLRHook(address(0), wflr);
    }

    function test_Constructor_RevertIf_WFLRZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new WithdrawRFLRHook(rNat, address(0));
    }

    function test_Constructor_RevertIf_BothZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new WithdrawRFLRHook(address(0), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                              BUILD TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Build() public view {
        Execution[] memory executions = hook.build(address(0), account, "");

        // preExecute + withdrawAll + postExecute = 3
        assertEq(executions.length, 3);
        assertEq(executions[0].target, address(hook)); // preExecute
        assertEq(executions[1].target, rNat); // withdrawAll
        assertEq(executions[1].value, 0);
        assertEq(executions[2].target, address(hook)); // postExecute

        // Verify calldata
        bytes memory expectedCallData = abi.encodeCall(IRNat.withdrawAll, (true));
        assertEq(keccak256(executions[1].callData), keccak256(expectedCallData));
    }

    function test_Build_EmptyData() public view {
        // Build with empty data still works
        Execution[] memory executions = hook.build(address(0), account, "");
        assertEq(executions.length, 3);
        assertEq(executions[1].target, rNat);
    }

    /*//////////////////////////////////////////////////////////////
                        PRE/POST EXECUTE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PreAndPostExecute() public {
        uint256 initialWflrBalance = 200 ether;
        uint256 withdrawnAmount = 50 ether;

        // Mock WFLR.balanceOf for pre
        vm.mockCall(wflr, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialWflrBalance));

        // Set up execution context
        hook.setExecutionContext(account);

        // Pre-execute
        vm.prank(account);
        hook.preExecute(address(0), account, "");
        assertEq(hook.getOutAmount(account), initialWflrBalance);

        // Mock increased WFLR balance for post
        vm.mockCall(wflr, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialWflrBalance + withdrawnAmount));

        // Post-execute
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

    /*//////////////////////////////////////////////////////////////
                           INSPECT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Inspector() public view {
        bytes memory argsEncoded = hook.inspect("");

        assertEq(argsEncoded.length, 20);
        assertEq(BytesLib.toAddress(argsEncoded, 0), rNat);
    }
}
