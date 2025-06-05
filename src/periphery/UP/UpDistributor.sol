// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title UpDistributor
 * @notice A contract for distributing tokens using a merkle tree for verification
 * @dev The foundation can update the merkle root and reclaim unclaimed tokens
 */
contract UpDistributor is Ownable2Step {
    IERC20 public immutable token;

    bytes32 public merkleRoot;

    /// @notice Track which addresses have claimed their tokens
    mapping(address => bool) public hasClaimed;

    event MerkleRootSet(bytes32 merkleRoot);
    event TokensClaimed(address indexed user, uint256 amount);
    event TokensReclaimed(uint256 amount);
    
    error AlreadyClaimed();
    error TransferFailed();
    error NoTokensToReclaim();
    error InvalidMerkleProof();

    constructor(address _token, address initialOwner) Ownable(initialOwner) {
        token = IERC20(_token);
    }

    /**
     * @notice Set a new merkle root for the distribution
     * @param _merkleRoot The new merkle root
     */
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
        emit MerkleRootSet(_merkleRoot);
    }

    /**
     * @notice Claim tokens if you are part of the merkle tree
     * @param amount The amount of tokens to claim
     * @param merkleProof A proof of inclusion in the merkle tree
     */
    function claim(uint256 amount, bytes32[] calldata merkleProof) external {
        // Verify user hasn't already claimed
        if (hasClaimed[msg.sender]) revert AlreadyClaimed();

        // Verify the merkle proof
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, amount))));
        if (!MerkleProof.verify(merkleProof, merkleRoot, leaf)) revert InvalidMerkleProof();

        // Mark as claimed and transfer tokens
        hasClaimed[msg.sender] = true;
        if (!token.transfer(msg.sender, amount)) revert TransferFailed();
        emit TokensClaimed(msg.sender, amount);
    }

    /**
     * @notice Allow the foundation to reclaim unclaimed tokens
     * @param amount The amount of tokens to reclaim
     */
    function reclaimTokens(uint256 amount) external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        if (amount > balance) revert NoTokensToReclaim();

        if (!token.transfer(owner(), amount)) revert TransferFailed();
        emit TokensReclaimed(amount);
    }
}
