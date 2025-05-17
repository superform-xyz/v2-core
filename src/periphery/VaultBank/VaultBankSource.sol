// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ExcessivelySafeCall } from "excessivelySafeCall/ExcessivelySafeCall.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// Superform
import { IVaultBankSource } from "../interfaces/IVaultBank.sol";

abstract contract VaultBankSource is IVaultBankSource {
    using SafeERC20 for IERC20;
    using ExcessivelySafeCall for address;
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    // locked assets
    mapping(address => mapping(uint64 => EnumerableSet.AddressSet)) internal _lockedAssets;
    mapping(address account => mapping(uint64 dstChainId => mapping(address token => uint256 amount))) internal
        _lockedAmounts;
    mapping(address account => mapping(address token => uint256 amount)) internal _totalLocked;

    uint64 internal immutable _chainId;

    constructor() {
        _chainId = uint64(block.chainid);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IVaultBankSource
    function viewLockedAmount(address account, address token, uint64 dstChainId) external view returns (uint256) {
        return _lockedAmounts[account][dstChainId][token];
    }

    /// @inheritdoc IVaultBankSource
    function viewAllLockedAssets(address account, uint64 dstChainId) external view returns (address[] memory) {
        return _lockedAssets[account][dstChainId].values();
    }

    /// @inheritdoc IVaultBankSource
    function viewTotalLockedAsset(address account, address token) external view returns (uint256) {
        return _totalLocked[account][token];
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
        _lockedAssets[account][toChainId].add(token);
        _totalLocked[account][token] += amount;

        IERC20(token).safeTransferFrom(account, address(this), amount);
        emit SharesLocked(account, token, amount, _chainId, toChainId, nonce);
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
        _lockedAssets[account][fromChainId].remove(token);

        IERC20(token).safeTransfer(account, amount);

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
}
