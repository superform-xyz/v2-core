// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// External
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Superform
import { ISuperBank } from "./interfaces/ISuperBank.sol";
import { ISuperGovernor } from "./interfaces/ISuperGovernor.sol";
import { ISuperHook, Execution } from "../core/interfaces/ISuperHook.sol";

/// @title SuperBank
/// @notice Compounds protocol revenue into sUP by executing registered hooks verified by Merkle proofs.
contract SuperBank is ISuperBank, Ownable2Step {
    using SafeERC20 for IERC20;

    ISuperGovernor public immutable SUPER_GOVERNOR;

    constructor(address superGovernor_, address owner_) Ownable(owner_) {
        if (superGovernor_ == address(0)) revert INVALID_ADDRESS();
        SUPER_GOVERNOR = ISuperGovernor(superGovernor_);
    }

    /// @inheritdoc ISuperBank
    function executeHooks(ISuperBank.HookExecutionData calldata executionData) external onlyOwner {
        uint256 hooksLength = executionData.hooks.length;
        if (hooksLength == 0) revert ZERO_LENGTH_ARRAY();

        // Validate arrays have matching lengths
        if (hooksLength != executionData.data.length || hooksLength != executionData.merkleProofs.length) {
            revert INVALID_ARRAY_LENGTH();
        }

        address prevHook;

        for (uint256 i; i < hooksLength; i++) {
            address hookAddress = executionData.hooks[i];
            bytes memory hookData = executionData.data[i];
            bytes32[] memory merkleProof = executionData.merkleProofs[i];

            ISuperHook hook = ISuperHook(hookAddress);

            // 1. Get the Merkle root specific to this hook
            bytes32 merkleRoot = SUPER_GOVERNOR.getSuperBankHookMerkleRoot(hookAddress);

            // 2. Pre-Execute Hook
            hook.preExecute(prevHook, address(this), hookData);

            // 3. Build Execution Steps
            Execution[] memory executions = hook.build(prevHook, address(this), hookData);

            // 4. Execute Target Calls and verify each target
            for (uint256 j; j < executions.length; ++j) {
                Execution memory executionStep = executions[j];

                // Verify that this target is allowed for this hook using the Merkle proof
                // The leaf is the hash of the target address
                bytes32 targetLeaf = keccak256(bytes.concat(keccak256(abi.encodePacked(executionStep.target))));

                // Verify this target is allowed using the corresponding Merkle proof
                if (!MerkleProof.verify(merkleProof, merkleRoot, targetLeaf)) {
                    revert INVALID_MERKLE_PROOF();
                }

                // Execute the call after verification
                (bool success,) = executionStep.target.call{ value: executionStep.value }(executionStep.callData);
                if (!success) {
                    revert HOOK_EXECUTION_FAILED();
                }
            }

            // 5. Post-Execute Hook
            hook.postExecute(prevHook, address(this), hookData);

            prevHook = hookAddress;
        }

        emit HooksExecuted(executionData.hooks, executionData.data);
    }

    // Receive function to accept direct ETH transfers if needed for hooks/executions
    receive() external payable { }
}
