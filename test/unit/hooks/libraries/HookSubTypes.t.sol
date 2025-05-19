// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { Helpers } from "../../../utils/Helpers.sol";
import { HookSubTypes } from "../../../../src/core/libraries/HookSubTypes.sol";

contract HookSubTypesTest is Helpers {
    function test_Constants() public pure {
        // Test all constant values
        assertEq(HookSubTypes.BRIDGE, keccak256(bytes("Bridge")));
        assertEq(HookSubTypes.CANCEL_DEPOSIT, keccak256(bytes("CancelDeposit")));
        assertEq(HookSubTypes.CANCEL_DEPOSIT_REQUEST, keccak256(bytes("CancelDepositRequest")));
        assertEq(HookSubTypes.CANCEL_REDEEM, keccak256(bytes("CancelRedeem")));
        assertEq(HookSubTypes.CANCEL_REDEEM_REQUEST, keccak256(bytes("CancelRedeemRequest")));
        assertEq(HookSubTypes.CLAIM, keccak256(bytes("Claim")));
        assertEq(HookSubTypes.CLAIM_CANCEL_DEPOSIT_REQUEST, keccak256(bytes("ClaimCancelDepositRequest")));
        assertEq(HookSubTypes.CLAIM_CANCEL_REDEEM_REQUEST, keccak256(bytes("ClaimCancelRedeemRequest")));
        assertEq(HookSubTypes.COOLDOWN, keccak256(bytes("Cooldown")));
        assertEq(HookSubTypes.ERC4626, keccak256(bytes("ERC4626")));
        assertEq(HookSubTypes.ERC5115, keccak256(bytes("ERC5115")));
        assertEq(HookSubTypes.ERC7540, keccak256(bytes("ERC7540")));
        assertEq(HookSubTypes.LOAN, keccak256(bytes("Loan")));
        assertEq(HookSubTypes.LOAN_REPAY, keccak256(bytes("LoanRepay")));
        assertEq(HookSubTypes.MISC, keccak256(bytes("Misc")));
        assertEq(HookSubTypes.STAKE, keccak256(bytes("Stake")));
        assertEq(HookSubTypes.SWAP, keccak256(bytes("Swap")));
        assertEq(HookSubTypes.TOKEN, keccak256(bytes("Token")));
        assertEq(HookSubTypes.UNSTAKE, keccak256(bytes("Unstake")));
        assertEq(HookSubTypes.PTYT, keccak256(bytes("PTYT")));
    }

    function test_GetHookSubType() public pure {
        // Test getHookSubType function with various inputs
        assertEq(HookSubTypes.getHookSubType("Bridge"), HookSubTypes.BRIDGE);
        assertEq(HookSubTypes.getHookSubType("LoanRepay"), HookSubTypes.LOAN_REPAY);
        assertEq(HookSubTypes.getHookSubType("Stake"), HookSubTypes.STAKE);
        assertEq(HookSubTypes.getHookSubType("Unstake"), HookSubTypes.UNSTAKE);
        assertEq(HookSubTypes.getHookSubType("Swap"), HookSubTypes.SWAP);
    }

    function test_GetHookSubType_CaseSensitive() public pure {
        // Test that getHookSubType is case sensitive
        assertTrue(HookSubTypes.getHookSubType("Bridge") != HookSubTypes.getHookSubType("bridge"));
        assertTrue(HookSubTypes.getHookSubType("LoanRepay") != HookSubTypes.getHookSubType("loanrepay"));
    }

    function test_GetHookSubType_EmptyString() public pure {
        // Test getHookSubType with empty string
        assertEq(HookSubTypes.getHookSubType(""), keccak256(bytes("")));
    }

    function test_GetHookSubType_SpecialCharacters() public pure {
        // Test getHookSubType with special characters
        string memory specialString = "Special!@#$%^&*()";
        assertEq(HookSubTypes.getHookSubType(specialString), keccak256(bytes(specialString)));
    }
}
