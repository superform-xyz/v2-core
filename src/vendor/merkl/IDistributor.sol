// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IDistributor {
    struct MerkleTree {
        // Root of a Merkle tree which leaves are `(address user, address token, uint amount)`
        // representing an amount of tokens accumulated by `user`.
        // The Merkle tree is assumed to have only increasing amounts: that is to say if a user can claim 1,
        // then after the amount associated in the Merkle tree for this token should be x > 1
        bytes32 merkleRoot;
        // Ipfs hash of the tree data
        bytes32 ipfsHash;
    }

    event Claimed(address indexed user, address indexed token, uint256 amount);

    /// @notice Claims rewards for a given set of users
    /// @dev Anyone may call this function for anyone else, funds go to destination regardless, it's just a question of
    /// who provides the proof and pays the gas: `msg.sender` is used only for addresses that require a trusted operator
    /// @param users Recipient of tokens
    /// @param tokens ERC20 claimed
    /// @param amounts Amount of tokens that will be sent to the corresponding users
    /// @param proofs Array of hashes bridging from a leaf `(hash of user | token | amount)` to the Merkle root
    function claim(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    )
        external;

    /// @notice Updates Merkle Tree
    function updateTree(MerkleTree calldata _tree) external;

    /// @notice Sets the dispute period
    /// @param _disputePeriod The new dispute period in seconds
    function setDisputePeriod(uint48 _disputePeriod) external;

    /// @notice Returns the MerkleRoot that is currently live for the contract
    function getMerkleRoot() external view returns (bytes32);
}
