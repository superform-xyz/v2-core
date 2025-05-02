// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ExcessivelySafeCall } from "excessivelySafeCall/ExcessivelySafeCall.sol";

// Superform
import { IVaultBankSource } from "../interfaces/IVaultBank.sol";

abstract contract VaultBankSource is IVaultBankSource {
    using SafeERC20 for IERC20;
    using ExcessivelySafeCall for address;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    // Rewards merkle roots
    mapping(bytes32 => bool) internal _registeredMerkleRoots;

    // locked assets
    mapping(address account => mapping(uint64 dstChainId => address[] tokens)) internal _lockedAssets;
    mapping(address account => mapping(uint64 dstChainId => mapping(address token => uint256 amount))) internal
        _lockedAmounts;
    mapping(address account => mapping(address token => uint256 amount)) internal _totalLocked;

    // rewards
    mapping(address account => mapping(address token => mapping(bytes32 merkleRoot => bool))) internal
        _hasBeenDistributed;

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IVaultBankSource
    function viewLockedAmount(address account, address token, uint64 dstChainId) external view returns (uint256) {
        return _lockedAmounts[account][dstChainId][token];
    }

    /// @inheritdoc IVaultBankSource
    function viewAllLockedAssets(address account, uint64 dstChainId) external view returns (address[] memory) {
        return _lockedAssets[account][dstChainId];
    }

    /// @inheritdoc IVaultBankSource
    function viewTotalLockedAsset(address account, address token) external view returns (uint256) {
        return _totalLocked[account][token];
    }

    /// @inheritdoc IVaultBankSource
    function isMerkleRootRegistered(bytes32 merkleRoot) external view returns (bool) {
        return _registeredMerkleRoots[merkleRoot];
    }

    /// @inheritdoc IVaultBankSource
    function canClaim(
        bytes32 merkleRoot,
        address account,
        address rewardToken,
        uint256 amount,
        bytes32[] calldata proof
    )
        public
        view
        returns (bool)
    {
        if (!_registeredMerkleRoots[merkleRoot]) revert MERKLE_ROOT_NOT_REGISTERED();
        bytes32 leaf = keccak256(abi.encodePacked(account, rewardToken, amount));
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    // ------------------ SYNTHETIC ASSETS ------------------
    function _lockAssetForChain(
        address account,
        address token,
        uint256 amount,
        uint64 toChainId,
        uint256 nonce
    )
        internal
    {
        if (amount == 0) revert INVALID_AMOUNT();
        if (token == address(0)) revert INVALID_TOKEN();
        if (account == address(0)) revert INVALID_ACCOUNT();
        _lockedAmounts[account][toChainId][token] += amount;
        _lockedAssets[account][toChainId].push(token);
        _totalLocked[account][token] += amount;

        IERC20(token).safeTransferFrom(account, address(this), amount);
        emit SharesLocked(account, token, amount, uint64(block.chainid), toChainId, nonce);
    }

    function _releaseAssetFromChain(
        address account,
        address token,
        uint256 amount,
        uint64 fromChainId,
        uint256 nonce
    )
        internal
    {
        if (account == address(0)) revert INVALID_ACCOUNT();
        if (token == address(0)) revert INVALID_TOKEN();
        if (amount == 0 || amount > _lockedAmounts[account][fromChainId][token]) revert INVALID_AMOUNT();
        _lockedAmounts[account][fromChainId][token] -= amount;
        _totalLocked[account][token] -= amount;
        _removeFromLockedAssets(account, token, fromChainId);

        IERC20(token).safeTransfer(account, amount);

        uint64 _chainId = uint64(block.chainid);
        emit SharesUnlocked(account, token, amount, _chainId, fromChainId, nonce);
    }
    // ------------------ MANAGE REWARDS ------------------

    function _claimRewards(
        address target,
        uint256 gasLimit,
        uint256 value,
        uint16 maxReturnDataCopy,
        bytes calldata data
    )
        internal
        returns (bytes memory)
    {
        if (target == address(0) || target == address(this)) revert INVALID_CLAIM_TARGET();
        (bool success, bytes memory result) = target.excessivelySafeCall(gasLimit, value, maxReturnDataCopy, data);
        if (!success) revert CLAIM_FAILED();
        return result;
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    // ------------------ SYNTHETIC ASSETS ------------------
    function _removeFromLockedAssets(address account, address token, uint64 dstChainId) private {
        uint256 len = _lockedAssets[account][dstChainId].length;
        if (len == 0) revert NO_LOCKED_ASSETS();

        uint256 index;
        bool found = false;
        for (uint256 i = 0; i < len; ++i) {
            if (_lockedAssets[account][dstChainId][i] == token) {
                index = i;
                found = true;
                break;
            }
        }

        if (!found) revert TOKEN_NOT_FOUND();

        if (index != len - 1) {
            _lockedAssets[account][dstChainId][index] = _lockedAssets[account][dstChainId][len - 1];
        }
        _lockedAssets[account][dstChainId].pop();
    }
}
