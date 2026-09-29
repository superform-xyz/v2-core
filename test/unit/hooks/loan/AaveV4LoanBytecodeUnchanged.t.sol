// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Helpers } from "../../../utils/Helpers.sol";

import { AaveV4SupplyHook } from "../../../../src/hooks/loan/aave-v4/AaveV4SupplyHook.sol";
import { AaveV4WithdrawHook } from "../../../../src/hooks/loan/aave-v4/AaveV4WithdrawHook.sol";
import { AaveV4BorrowHook } from "../../../../src/hooks/loan/aave-v4/AaveV4BorrowHook.sol";
import { AaveV4RepayHook } from "../../../../src/hooks/loan/aave-v4/AaveV4RepayHook.sol";
import { AaveV4SupplyAndBorrowHook } from "../../../../src/hooks/loan/aave-v4/AaveV4SupplyAndBorrowHook.sol";
import { AaveV4RepayAndWithdrawHook } from "../../../../src/hooks/loan/aave-v4/AaveV4RepayAndWithdrawHook.sol";
import { AaveV4SupplyAndBorrowHookV2 } from "../../../../src/hooks/loan/aave-v4/AaveV4SupplyAndBorrowHookV2.sol";
import { AaveV4RepayHookV2 } from "../../../../src/hooks/loan/aave-v4/AaveV4RepayHookV2.sol";
import { AaveV4RepayAndWithdrawHookV2 } from "../../../../src/hooks/loan/aave-v4/AaveV4RepayAndWithdrawHookV2.sol";

/// @title AaveV4LoanBytecodeUnchangedTest
/// @notice SUP-21142 acceptance: adding the idle MONEY_MARKET hooks must not change any LOAN V1/V2
///         hook's bytecode. With `bytecode_hash = "none"` the creation code is a deterministic
///         function of the sources, so equality against the locked artifact is an exact proof.
///         Deployment wiring for the idle hooks is deferred, so no idle artifact is asserted here yet.
contract AaveV4LoanBytecodeUnchangedTest is Helpers {
    function _locked(string memory name) internal returns (bytes32) {
        return keccak256(vm.getCode(string(abi.encodePacked("script/locked-bytecode/", name, ".json"))));
    }

    function test_LoanV1_BytecodeUnchanged() public {
        assertEq(keccak256(type(AaveV4SupplyHook).creationCode), _locked("AaveV4SupplyHook"));
        assertEq(keccak256(type(AaveV4WithdrawHook).creationCode), _locked("AaveV4WithdrawHook"));
        assertEq(keccak256(type(AaveV4BorrowHook).creationCode), _locked("AaveV4BorrowHook"));
        assertEq(keccak256(type(AaveV4RepayHook).creationCode), _locked("AaveV4RepayHook"));
        assertEq(keccak256(type(AaveV4SupplyAndBorrowHook).creationCode), _locked("AaveV4SupplyAndBorrowHook"));
        assertEq(keccak256(type(AaveV4RepayAndWithdrawHook).creationCode), _locked("AaveV4RepayAndWithdrawHook"));
    }

    function test_LoanV2_BytecodeUnchanged() public {
        assertEq(keccak256(type(AaveV4SupplyAndBorrowHookV2).creationCode), _locked("AaveV4SupplyAndBorrowHookV2"));
        assertEq(keccak256(type(AaveV4RepayHookV2).creationCode), _locked("AaveV4RepayHookV2"));
        assertEq(keccak256(type(AaveV4RepayAndWithdrawHookV2).creationCode), _locked("AaveV4RepayAndWithdrawHookV2"));
    }
}
