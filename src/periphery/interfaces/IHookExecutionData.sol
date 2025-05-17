// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

interface IHookExecutionData {
    /// @notice Data required for executing hooks with Merkle proof verification.
    /// @param hooks Array of addresses of hooks to execute.
    /// @param data Array of arbitrary data to pass to each hook.
    /// @param merkleProofs Double array of Merkle proofs verifying each hook's allowed targets.
    struct HookExecutionData {
        address[] hooks;
        bytes[] data;
        bytes32[][] merkleProofs;
    }   
}