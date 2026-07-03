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
import { WithdrawRFLRHookV2 } from "../../../../../src/hooks/claim/flare/WithdrawRFLRHookV2.sol";
import { IRNat } from "../../../../../src/vendor/flare/IRNat.sol";

contract WithdrawRFLRHookV2Test is Helpers {
    WithdrawRFLRHookV2 public hook;

    address public rNat;
    address public wflr;
    address public account;

    function setUp() public {
        rNat = makeAddr("rNat");
        wflr = makeAddr("wflr");
        account = makeAddr("account");

        hook = new WithdrawRFLRHookV2(rNat, wflr);
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
        new WithdrawRFLRHookV2(address(0), wflr);
    }

    function test_Constructor_RevertIf_WFLRZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new WithdrawRFLRHookV2(rNat, address(0));
    }

    function test_Constructor_RevertIf_BothZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new WithdrawRFLRHookV2(address(0), address(0));
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
        vm.mockCall(
            wflr, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialWflrBalance + withdrawnAmount)
        );

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
                   SLIPPAGE PROTECTION (Variant A) TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PostExecute_MinOut_Passes() public {
        uint256 initialWflrBalance = 100 ether;
        uint256 withdrawnAmount = 50 ether;
        uint256 minOut = 50 ether;

        vm.mockCall(wflr, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialWflrBalance));
        hook.setExecutionContext(account);

        vm.prank(account);
        hook.preExecute(address(0), account, "");

        vm.mockCall(
            wflr, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialWflrBalance + withdrawnAmount)
        );

        // 52-byte header + 1 byte ack (0x00) + 32 bytes minOut
        bytes memory data = abi.encodePacked(bytes32(0), bytes20(0), uint8(0), minOut);

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

        bytes memory data = abi.encodePacked(bytes32(0), bytes20(0), uint8(0), minOut);

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

        bytes memory data = abi.encodePacked(bytes32(0), bytes20(0), uint8(0), minOut);

        vm.expectRevert(WithdrawRFLRHookV2.SLIPPAGE_EXCEEDED.selector);
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

        bytes memory data = abi.encodePacked(bytes32(0), bytes20(0), uint8(0), minOut);

        vm.expectRevert(WithdrawRFLRHookV2.SLIPPAGE_EXCEEDED.selector);
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
        bytes memory data = abi.encodePacked(bytes32(0), bytes20(0), uint8(0), uint256(0));

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

        // Empty data — backward compatible, no slippage check
        vm.prank(account);
        hook.postExecute(address(0), account, "");
        assertEq(hook.getOutAmount(account), withdrawnAmount);
    }

    function test_PostExecute_OnlyAckByte_NoSlippageCheck() public {
        uint256 initialWflrBalance = 100 ether;
        uint256 withdrawnAmount = 1;

        vm.mockCall(wflr, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialWflrBalance));
        hook.setExecutionContext(account);

        vm.prank(account);
        hook.preExecute(address(0), account, "");

        vm.mockCall(
            wflr, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialWflrBalance + withdrawnAmount)
        );

        // 52-byte header + only 1 byte (ack) — no minOut field, no slippage check
        bytes memory data = abi.encodePacked(bytes32(0), bytes20(0), uint8(1));

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
