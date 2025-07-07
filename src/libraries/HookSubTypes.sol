// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

/// @title HookSubTypes
/// @author Superform Labs
/// @notice Library for hook subtypes
library HookSubTypes {
    bytes32 constant BRIDGE = keccak256(bytes("Bridge"));
    bytes32 constant CANCEL_DEPOSIT = keccak256(bytes("CancelDeposit"));
    bytes32 constant CANCEL_DEPOSIT_REQUEST = keccak256(bytes("CancelDepositRequest"));
    bytes32 constant CANCEL_REDEEM = keccak256(bytes("CancelRedeem"));
    bytes32 constant CANCEL_REDEEM_REQUEST = keccak256(bytes("CancelRedeemRequest"));
    bytes32 constant CLAIM = keccak256(bytes("Claim"));
    bytes32 constant CLAIM_CANCEL_DEPOSIT_REQUEST = keccak256(bytes("ClaimCancelDepositRequest"));
    bytes32 constant CLAIM_CANCEL_REDEEM_REQUEST = keccak256(bytes("ClaimCancelRedeemRequest"));
    bytes32 constant COOLDOWN = keccak256(bytes("Cooldown"));
    bytes32 constant ETHENA = keccak256(bytes("Ethena"));
    bytes32 constant ERC4626 = keccak256(bytes("ERC4626"));
    bytes32 constant ERC5115 = keccak256(bytes("ERC5115"));
    bytes32 constant ERC7540 = keccak256(bytes("ERC7540"));
    bytes32 constant LOAN = keccak256(bytes("Loan"));
    bytes32 constant LOAN_REPAY = keccak256(bytes("LoanRepay"));
    bytes32 constant MISC = keccak256(bytes("Misc"));
    bytes32 constant STAKE = keccak256(bytes("Stake"));
    bytes32 constant SWAP = keccak256(bytes("Swap"));
    bytes32 constant TOKEN = keccak256(bytes("Token"));
    bytes32 constant UNSTAKE = keccak256(bytes("Unstake"));
    bytes32 constant PTYT = keccak256(bytes("PTYT"));
    bytes32 constant VAULT_BANK = keccak256(bytes("VaultBank"));

    function getHookSubType(string memory hookSubtype) internal pure returns (bytes32) {
        return keccak256(bytes(hookSubtype));
    }
}
