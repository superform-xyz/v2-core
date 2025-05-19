// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { StdCheats } from "forge-std/StdCheats.sol";
import { Helpers } from "./Helpers.sol";

abstract contract MerkleTreeHelper is StdCheats, Helpers {
    mapping(uint64 chainId => bytes32[]) public hookLeavesPerChain;
    mapping(uint64 chainId => bytes32[][]) public hookProofsPerChain;
    mapping(uint64 chainId => bytes32) public hookRootPerChain;

    /*//////////////////////////////////////////////////////////////
                                 HOOKS TREE HELPERS
    //////////////////////////////////////////////////////////////*/
    function _createHooksTree(
        uint64 chainId,
        address[] memory hooksAddresses
    )
        internal
        returns (bytes32[][] memory proof, bytes32 root)
    {
        bytes32[] memory leaves = new bytes32[](hooksAddresses.length);
        for (uint256 i = 0; i < hooksAddresses.length; i++) {
            leaves[i] = keccak256(bytes.concat(keccak256(abi.encode(hooksAddresses[i]))));
        }

        hookLeavesPerChain[chainId] = leaves;

        (proof, root) = _createValidatorMerkleTree(hookLeavesPerChain[chainId]);
        hookProofsPerChain[chainId] = proof;
        hookRootPerChain[chainId] = root;
    }

    /*//////////////////////////////////////////////////////////////
                                 SOURCE CHAIN HELPERS
    //////////////////////////////////////////////////////////////*/
    function _createSourceValidatorLeaf(bytes32 userOpHash, uint48 validUntil) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(userOpHash, validUntil))));
    }

    /*//////////////////////////////////////////////////////////////
                                 DESTINATION CHAIN HELPERS
    //////////////////////////////////////////////////////////////*/
    function _createDestinationValidatorLeaf(
        bytes memory executionData,
        uint64 dstChainId,
        address account,
        address executor,
        address[] memory dstTokens,
        uint256[] memory intentAmounts,
        uint48 validUntil
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(executionData, dstChainId, account, executor, dstTokens, intentAmounts, validUntil)
                )
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 GENERIC HELPER METHODS
    //////////////////////////////////////////////////////////////*/
    function _sortAndHashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    function _createValidatorMerkleTree(bytes32[] memory leaves)
        internal
        pure
        returns (bytes32[][] memory proof, bytes32 root)
    {
        require(leaves.length > 0, "At least one leaf required");

        uint256 n = leaves.length;
        while ((n & (n - 1)) != 0) {
            // Not power of 2
            n++;
        }

        bytes32[] memory nodes = new bytes32[](n);
        for (uint256 i = 0; i < leaves.length; i++) {
            nodes[i] = leaves[i];
        }
        for (uint256 i = leaves.length; i < n; i++) {
            nodes[i] = leaves[leaves.length - 1]; // Duplicate last leaf
        }

        // Construct Merkle Tree
        uint256 totalLevels = 1;
        while (n > 1) {
            n = n / 2;
            totalLevels++;
        }

        bytes32[][] memory tree = new bytes32[][](totalLevels);
        tree[0] = nodes;

        uint256 levelSize = nodes.length;
        uint256 level = 0;
        while (levelSize > 1) {
            levelSize /= 2;
            tree[level + 1] = new bytes32[](levelSize);
            for (uint256 i = 0; i < levelSize; i++) {
                tree[level + 1][i] = _sortAndHashPair(tree[level][2 * i], tree[level][2 * i + 1]);
            }
            level++;
        }

        root = tree[level][0]; // Root of the tree

        // Generate proofs
        proof = new bytes32[][](leaves.length);
        for (uint256 i = 0; i < leaves.length; i++) {
            proof[i] = _generateProof(i, tree);
        }

        return (proof, root);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _generateProof(uint256 index, bytes32[][] memory tree) private pure returns (bytes32[] memory) {
        uint256 levels = tree.length;
        bytes32[] memory proof = new bytes32[](levels - 1);

        for (uint256 level = 0; level < levels - 1; level++) {
            uint256 siblingIndex = index ^ 1; // XOR to find sibling
            proof[level] = tree[level][siblingIndex];
            index /= 2;
        }

        return proof;
    }
}
