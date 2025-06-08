// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title UpDistributor
 * @notice A contract for distributing tokens using a merkle tree for verification
 * @dev The foundation can reclaim unclaimed tokens
 */
contract UpDistributor is Ownable2Step {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    bytes32 public merkleRoot;

    /// @notice Track which addresses have claimed their tokens
    mapping(address => bool) public hasClaimed;

    event MerkleRootSet(bytes32 merkleRoot);
    event TokensClaimed(address indexed user, uint256 amount);
    event TokensReclaimed(uint256 amount);

    error ALREADY_CLAIMED();
    error NO_TOKENS_TO_RECLAIM();
    error INVALID_MERKLE_PROOF();
    error INVALID_TOKEN_ADDRESS();

    constructor(address _token, address initialOwner) Ownable(initialOwner) {
        if (_token == address(0)) revert INVALID_TOKEN_ADDRESS();
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
        if (hasClaimed[msg.sender]) revert ALREADY_CLAIMED();

        // Verify the merkle proof
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, amount))));
        if (!MerkleProof.verify(merkleProof, merkleRoot, leaf)) revert INVALID_MERKLE_PROOF();

        // Mark as claimed and transfer tokens
        hasClaimed[msg.sender] = true;
        emit TokensClaimed(msg.sender, amount);
        token.safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Claim tokens for a recipient
     * @dev This function can be called by users with smart accounts
     * @param recipient The address to claim tokens for
     * @param amount The amount of tokens to claim
     * @param merkleProof A proof of inclusion in the merkle tree
     */
    function claimOnBehalf(
        address recipient,
        uint256 amount,
        bytes32[] calldata merkleProof
    )
        external
    {
        // Verify user hasn't already claimed
        if (hasClaimed[recipient]) revert ALREADY_CLAIMED();

        // Verify the merkle proof
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(recipient, amount))));
        if (!MerkleProof.verify(merkleProof, merkleRoot, leaf)) revert INVALID_MERKLE_PROOF();

        // Mark as claimed and transfer tokens
        hasClaimed[recipient] = true;
        emit TokensClaimed(recipient, amount);
        token.safeTransfer(recipient, amount);
    }

    /**
     * @notice Allow the foundation to reclaim unclaimed tokens
     * @param amount The amount of tokens to reclaim
     */
    function reclaimTokens(uint256 amount) external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        if (amount > balance) revert NO_TOKENS_TO_RECLAIM();

        emit TokensReclaimed(amount);
        token.safeTransfer(owner(), amount);
    }
}
