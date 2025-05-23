// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/StdJson.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";

import { Helpers } from "../../Helpers.sol";

import { console2 } from "forge-std/console2.sol";

// Custom errors for MerkleReader
error NoProofFoundForArgs();
error NoProofFoundForHookAndArgs();
error InvalidArrayLengths();
error EmptyInput();

abstract contract MerkleReader is StdCheats, Helpers {
    using stdJson for string;

    // Updated paths to the new output files
    string private basePathForRoot = "/test/utils/merkle/output/jsGeneratedRoot_1";
    string private basePathForTreeDump = "/test/utils/merkle/output/jsTreeDump_1";

    string private prepend = ".values[";

    // Updated appends for the new structure
    string private hookNameQueryAppend = "].hookName";
    string private hookAddressQueryAppend = "].hookAddress"; // Added to access hook address
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
        console2.log("\n[DEBUG] Starting _getMerkleRoot()");

        // Read owner_list.json for debugging
        string memory ownerListPath = string.concat(vm.projectRoot(), "/test/utils/merkle/target/owner_list.json");
        try vm.readFile(ownerListPath) returns (string memory content) {
            console2.log("[DEBUG] Current owner_list.json in _getMerkleRoot:", content);
        } catch {
            console2.log("[DEBUG] Could not read owner_list.json in _getMerkleRoot");
        }

        LocalVars memory v;
        string memory rootFilePath = string.concat(vm.projectRoot(), basePathForRoot, ".json");
        console2.log("[DEBUG] Reading Merkle root from file:", rootFilePath);

        v.rootJson = vm.readFile(rootFilePath);
        console2.log("[DEBUG] Root JSON content:", v.rootJson);

        v.encodedRoot = vm.parseJson(v.rootJson, ".root");
        root = abi.decode(v.encodedRoot, (bytes32));

        console2.log("\n");
        console2.log("----------ROoot   ----------");
        console2.logBytes32(root);
        console2.log("[DEBUG] _getMerkleRoot completed");
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
        bytes memory encodedValuesLength = vm.parseJson(v.treeJson, ".count");
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
     * @notice Get Merkle proof for a hook with specific arguments
     * @param hookAddress Address of the hook contract
     * @param encodedHookArgs Packed-encoded hook arguments
     * @return proof Merkle proof for the hook/args combination
     */
    function _getMerkleProofForHook(
        address hookAddress,
        bytes memory encodedHookArgs
    )
        internal
        view
        returns (bytes32[] memory proof)
    {
        LocalVars memory v;

        v.treeJson = vm.readFile(string.concat(vm.projectRoot(), basePathForTreeDump, ".json"));

        // Get the total number of values in the tree
        bytes memory encodedValuesLength = vm.parseJson(v.treeJson, ".count");
        uint256 valuesLength = abi.decode(encodedValuesLength, (uint256));

        // Search for the matching hook address and encoded args
        for (uint256 i = 0; i < valuesLength; ++i) {
            // Get hook address for each entry
            bytes memory encodedHookAddress =
                vm.parseJson(v.treeJson, string.concat(prepend, Strings.toString(i), hookAddressQueryAppend));
            address currentHookAddress = abi.decode(encodedHookAddress, (address));

            // Only check values for the specified hook
            if (currentHookAddress == hookAddress) {
                // Get encoded args directly as bytes
                string memory valueQuery = string.concat(prepend, Strings.toString(i), valueQueryAppend);
                bytes memory valueBytes = abi.decode(vm.parseJson(v.treeJson, valueQuery), (bytes));

                // Compare the encoded args
                if (keccak256(valueBytes) == keccak256(encodedHookArgs)) {
                    v.encodedProof =
                        vm.parseJson(v.treeJson, string.concat(prepend, Strings.toString(i), proofQueryAppend));
                    proof = abi.decode(v.encodedProof, (bytes32[]));
                    break;
                }
            }
        }

        if (proof.length == 0) revert NoProofFoundForHookAndArgs();
    }

    /**
     * @notice Get Merkle proofs for multiple hooks with specific arguments
     * @dev Optimized for batch processing multiple hooks by reading the JSON only once
     * @param hookAddresses Array of hook contract addresses
     * @param encodedHookArgs Array of packed-encoded hook arguments corresponding to each hook
     * @return proofs Array of Merkle proofs for each hook/args combination
     */
    function _getMerkleProofsForHooks(
        address[] memory hookAddresses,
        bytes[] memory encodedHookArgs
    )
        internal
        view
        returns (bytes32[][] memory proofs)
    {
        // Input validation
        if (hookAddresses.length != encodedHookArgs.length) revert InvalidArrayLengths();
        if (hookAddresses.length == 0) revert EmptyInput();

        LocalVars memory v;
        v.treeJson = vm.readFile(string.concat(vm.projectRoot(), basePathForTreeDump, ".json"));

        // Get the total number of values in the tree
        bytes memory encodedValuesLength = vm.parseJson(v.treeJson, ".count");
        uint256 valuesLength = abi.decode(encodedValuesLength, (uint256));

        // Create a properly sized array for proofs
        proofs = new bytes32[][](hookAddresses.length);

        // Cache data from JSON to minimize redundant reads
        address[] memory cachedHookAddresses = new address[](valuesLength);
        bytes[] memory cachedValueBytes = new bytes[](valuesLength);
        string[] memory cachedProofQueries = new string[](valuesLength);

        for (uint256 i = 0; i < valuesLength; ++i) {
            string memory hookAddressQuery = string.concat(prepend, Strings.toString(i), hookAddressQueryAppend);
            bytes memory encodedHookAddress = vm.parseJson(v.treeJson, hookAddressQuery);

            cachedHookAddresses[i] = abi.decode(encodedHookAddress, (address));
            string memory valueQuery = string.concat(prepend, Strings.toString(i), valueQueryAppend);
            bytes memory encodedValue = vm.parseJson(v.treeJson, valueQuery);

            if (encodedValue.length > 32) {
                cachedValueBytes[i] = abi.decode(encodedValue, (bytes));
            } else {
                cachedValueBytes[i] = abi.encodePacked(abi.decode(encodedValue, (address)));
            }

            cachedProofQueries[i] = string.concat(prepend, Strings.toString(i), proofQueryAppend);
        }

        // Process each hook address and find its proof
        for (uint256 h = 0; h < hookAddresses.length; h++) {
            address targetHookAddress = hookAddresses[h];
            bytes memory targetArgs = encodedHookArgs[h];

            bool found = false;

            // Search through cached entries
            for (uint256 i = 0; i < valuesLength; ++i) {
                // Check if hook address matches
                if (cachedHookAddresses[i] == targetHookAddress) {
                    // Compare the encoded args
                    if (keccak256(cachedValueBytes[i]) == keccak256(targetArgs)) {
                        // Get proof for this leaf
                        bytes memory encodedProof = vm.parseJson(v.treeJson, cachedProofQueries[i]);
                        proofs[h] = abi.decode(encodedProof, (bytes32[]));
                        found = true;
                        break;
                    }
                }
            }

            // If we couldn't find a proof for this hook/args pair
            if (!found) {
                // Log debugging information
                console2.log("No proof found for hook address:", targetHookAddress);
                revert NoProofFoundForHookAndArgs();
            }
        }

        return proofs;
    }

    /**
     * @notice Generate the complete Merkle tree data
     * @dev Returns the root, all encoded args and their proofs
     * @return root The Merkle root
     * @return encodedArgsList List of all encoded arguments in the tree
     * @return hookNames List of hook names corresponding to each encoded argument
     * @return hookAddresses List of hook addresses corresponding to each encoded argument
     * @return proofs List of proofs corresponding to each encoded argument
     */
    function _generateMerkleTree()
        internal
        view
        returns (
            bytes32 root,
            bytes[] memory encodedArgsList,
            string[] memory hookNames,
            address[] memory hookAddresses,
            bytes32[][] memory proofs
        )
    {
        LocalVars memory v;

        v.rootJson = vm.readFile(string.concat(vm.projectRoot(), basePathForRoot, ".json"));
        v.encodedRoot = vm.parseJson(v.rootJson, ".root");
        root = abi.decode(v.encodedRoot, (bytes32));

        v.treeJson = vm.readFile(string.concat(vm.projectRoot(), basePathForTreeDump, ".json"));

        // Get the total number of values in the tree
        bytes memory encodedValuesLength = vm.parseJson(v.treeJson, ".count");
        uint256 valuesLength = abi.decode(encodedValuesLength, (uint256));

        // Initialize arrays to store results
        encodedArgsList = new bytes[](valuesLength);
        hookNames = new string[](valuesLength);
        hookAddresses = new address[](valuesLength);
        proofs = new bytes32[][](valuesLength);

        // Fill arrays with data from the tree dump
        for (uint256 i = 0; i < valuesLength; ++i) {
            // Get hook name
            v.encodedHookName =
                vm.parseJson(v.treeJson, string.concat(prepend, Strings.toString(i), hookNameQueryAppend));
            hookNames[i] = abi.decode(v.encodedHookName, (string));

            // Get hook address
            bytes memory encodedHookAddress =
                vm.parseJson(v.treeJson, string.concat(prepend, Strings.toString(i), hookAddressQueryAppend));
            hookAddresses[i] = abi.decode(encodedHookAddress, (address));

            // Get encoded args directly as bytes
            string memory valueQuery = string.concat(prepend, Strings.toString(i), ".value[0]");
            encodedArgsList[i] = abi.decode(vm.parseJson(v.treeJson, valueQuery), (bytes));

            // Get proof
            v.encodedProof = vm.parseJson(v.treeJson, string.concat(prepend, Strings.toString(i), proofQueryAppend));
            proofs[i] = abi.decode(v.encodedProof, (bytes32[]));
        }
    }
}
