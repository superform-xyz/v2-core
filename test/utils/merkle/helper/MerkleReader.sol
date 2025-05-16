// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.23;

import "forge-std/StdJson.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";

import { Helpers } from "../../Helpers.sol";

// Custom errors for MerkleReader
error NoProofFoundForArgs();
error NoProofFoundForHookAndArgs();

abstract contract MerkleReader is StdCheats, Helpers {
    using stdJson for string;

    // Updated paths to the new output files
    string private basePathForRoot = "/test/utils/merkle/output/jsGeneratedRoot_1";
    string private basePathForTreeDump = "/test/utils/merkle/output/jsTreeDump_1";

    string private prepend = ".values[";

    // Updated appends for the new structure
    string private hookNameQueryAppend = "].hookName";
    string private valueQueryAppend = "].value[0]"; // First element in the value array
    string private proofQueryAppend = "].proof";

    struct LocalVars {
        string rootJson;
        bytes encodedRoot;
        string treeJson;
        bytes encodedHookName;
        bytes encodedValue;
        bytes encodedProof;
    }

    /**
     * @notice Get the Merkle root from the jsGeneratedRoot file
     * @return root The Merkle root
     */
    function _getMerkleRoot() internal view returns (bytes32 root) {
        LocalVars memory v;

        v.rootJson = vm.readFile(string.concat(vm.projectRoot(), basePathForRoot, ".json"));
        v.encodedRoot = vm.parseJson(v.rootJson, ".root");
        root = abi.decode(v.encodedRoot, (bytes32));
    }

    /**
     * @notice Get the Merkle proof for specific encoded hook arguments
     * @param encodedHookArgs The packed-encoded hook arguments (from inspect function)
     * @return proof The Merkle proof for the given encoded arguments
     */
    function _getMerkleProofForArgs(bytes memory encodedHookArgs) internal view returns (bytes32[] memory proof) {
        LocalVars memory v;

        v.treeJson = vm.readFile(string.concat(vm.projectRoot(), basePathForTreeDump, ".json"));

        // Get the total number of values in the tree
        bytes memory encodedValuesLength = vm.parseJson(v.treeJson, ".values.length");
        uint256 valuesLength = abi.decode(encodedValuesLength, (uint256));

        // Search for the matching encoded args
        for (uint256 i = 0; i < valuesLength; ++i) {
            // Get encoded args directly as bytes
            string memory valueQuery = string.concat(prepend, Strings.toString(i), ".value[0]");
            bytes memory valueBytes = abi.decode(vm.parseJson(v.treeJson, valueQuery), (bytes));
            
            // Compare the encoded args
            if (keccak256(valueBytes) == keccak256(encodedHookArgs)) {
                v.encodedProof = vm.parseJson(v.treeJson, string.concat(prepend, Strings.toString(i), proofQueryAppend));
                proof = abi.decode(v.encodedProof, (bytes32[]));
                break;
            }
        }

        if (proof.length == 0) revert NoProofFoundForArgs();
    }

    /**
     * @notice Get the Merkle proof for a specific hook with specific arguments
     * @param hookName Name of the hook (e.g. "ApproveAndRedeem4626VaultHook")
     * @param encodedHookArgs The packed-encoded hook arguments (from inspect function)
     * @return proof The Merkle proof for the given hook and arguments
     */
    function _getMerkleProofForHook(
        string memory hookName,
        bytes memory encodedHookArgs
    ) internal view returns (bytes32[] memory proof) {
        LocalVars memory v;

        v.treeJson = vm.readFile(string.concat(vm.projectRoot(), basePathForTreeDump, ".json"));

        // Get the total number of values in the tree
        bytes memory encodedValuesLength = vm.parseJson(v.treeJson, ".values.length");
        uint256 valuesLength = abi.decode(encodedValuesLength, (uint256));

        // Search for the matching hook name and encoded args
        for (uint256 i = 0; i < valuesLength; ++i) {
            v.encodedHookName = vm.parseJson(v.treeJson, string.concat(prepend, Strings.toString(i), hookNameQueryAppend));
            string memory currentHookName = abi.decode(v.encodedHookName, (string));
            
            // Only check values for the specified hook
            if (keccak256(bytes(currentHookName)) == keccak256(bytes(hookName))) {
                // Get encoded args directly as bytes
                string memory valueQuery = string.concat(prepend, Strings.toString(i), ".value[0]");
                bytes memory valueBytes = abi.decode(vm.parseJson(v.treeJson, valueQuery), (bytes));
                
                // Compare the encoded args
                if (keccak256(valueBytes) == keccak256(encodedHookArgs)) {
                    v.encodedProof = vm.parseJson(v.treeJson, string.concat(prepend, Strings.toString(i), proofQueryAppend));
                    proof = abi.decode(v.encodedProof, (bytes32[]));
                    break;
                }
            }
        }

        if (proof.length == 0) revert NoProofFoundForHookAndArgs();
    }

    /**
     * @notice Generate the complete Merkle tree data
     * @dev Returns the root, all encoded args and their proofs
     * @return root The Merkle root
     * @return encodedArgsList List of all encoded arguments in the tree
     * @return hookNames List of hook names corresponding to each encoded argument
     * @return proofs List of proofs corresponding to each encoded argument
     */
    function _generateMerkleTree()
        internal
        view
        returns (
            bytes32 root,
            bytes[] memory encodedArgsList,
            string[] memory hookNames,
            bytes32[][] memory proofs
        )
    {
        LocalVars memory v;

        v.rootJson = vm.readFile(string.concat(vm.projectRoot(), basePathForRoot, ".json"));
        v.encodedRoot = vm.parseJson(v.rootJson, ".root");
        root = abi.decode(v.encodedRoot, (bytes32));

        v.treeJson = vm.readFile(string.concat(vm.projectRoot(), basePathForTreeDump, ".json"));

        // Get the total number of values in the tree
        bytes memory encodedValuesLength = vm.parseJson(v.treeJson, ".values.length");
        uint256 valuesLength = abi.decode(encodedValuesLength, (uint256));

        // Initialize arrays to store results
        encodedArgsList = new bytes[](valuesLength);
        hookNames = new string[](valuesLength);
        proofs = new bytes32[][](valuesLength);

        // Fill arrays with data from the tree dump
        for (uint256 i = 0; i < valuesLength; ++i) {
            // Get hook name
            v.encodedHookName = vm.parseJson(v.treeJson, string.concat(prepend, Strings.toString(i), hookNameQueryAppend));
            hookNames[i] = abi.decode(v.encodedHookName, (string));

            // Get encoded args directly as bytes
            string memory valueQuery = string.concat(prepend, Strings.toString(i), ".value[0]");
            encodedArgsList[i] = abi.decode(vm.parseJson(v.treeJson, valueQuery), (bytes));

            // Get proof
            v.encodedProof = vm.parseJson(v.treeJson, string.concat(prepend, Strings.toString(i), proofQueryAppend));
            proofs[i] = abi.decode(v.encodedProof, (bytes32[]));
        }
    }
}
