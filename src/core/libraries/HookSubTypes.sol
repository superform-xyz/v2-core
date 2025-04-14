// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

/// @title HookSubTypes
/// @author Superform Labs
/// @notice Library for hook subtypes
library HookSubTypes {
    bytes32 constant BRIDGE = keccak256(bytes("Bridge"));
    bytes32 constant CLAIM = keccak256(bytes("Claim"));
    bytes32 constant COOLDOWN = keccak256(bytes("Cooldown"));
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

    function getHookSubType(string memory hookSubtype) internal pure returns (bytes32) {
        return keccak256(bytes(hookSubtype));
    }
}