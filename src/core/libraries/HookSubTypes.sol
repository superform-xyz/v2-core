// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

/// @title HookSubTypes
/// @author Superform Labs
/// @notice Library for hook subtypes
library HookSubTypes {
    string constant BRIDGE = "Bridge";
    string constant CLAIM = "Claim";
    string constant COOLDOWN = "Cooldown";
    string constant ERC4626 = "ERC4626";
    string constant ERC5115 = "ERC5115";
    string constant ERC7540 = "ERC7540";
    string constant LOAN = "Loan";
    string constant LOAN_REPAY = "LoanRepay";
    string constant MISC = "Misc";
    string constant STAKE = "Stake";
    string constant SWAP = "Swap";
    string constant TOKEN = "Token";
    string constant UNSTAKE = "Unstake";

    function getHookSubType(string memory hookSubtype) internal pure returns (bytes32) {
        return keccak256(bytes(hookSubtype));
    }
}