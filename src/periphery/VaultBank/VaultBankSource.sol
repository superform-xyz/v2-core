// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ExcessivelySafeCall } from "excessivelySafeCall/ExcessivelySafeCall.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// Superform
import { IVaultBankSource } from "../interfaces/VaultBank/IVaultBank.sol";

abstract contract VaultBankSource is IVaultBankSource {
    using SafeERC20 for IERC20;
    using ExcessivelySafeCall for address;
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    // locked assets
    EnumerableSet.AddressSet internal _lockedAssets;
    mapping(address token => uint256 amount) internal _lockedAmounts;

    uint64 internal immutable _chainId;

    constructor() {
        _chainId = uint64(block.chainid);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IVaultBankSource
    function viewTotalLockedAsset(address token) external view returns (uint256) {
        return _lockedAmounts[token];
    }

    /// @inheritdoc IVaultBankSource
    function viewAllLockedAssets() external view returns (address[] memory) {
        return _lockedAssets.values();
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    // ------------------ SYNTHETIC ASSETS ------------------
    function _lockAssetForChain(
        bytes32 yieldSourceOracleId,
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
        if (yieldSourceOracleId == bytes32(0)) revert INVALID_YIELD_SOURCE_ORACLE_ID();

        if (!_lockedAssets.contains(token)) {
            _lockedAssets.add(token);
        }
        _lockedAmounts[token] += amount;

        IERC20(token).safeTransferFrom(account, address(this), amount);
        emit SharesLocked(yieldSourceOracleId, account, token, amount, _chainId, toChainId, nonce);
    }

    function _releaseAssetFromChain(
        bytes32 yieldSourceOracleId,
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
        if (amount == 0 || amount > _lockedAmounts[token]) revert INVALID_AMOUNT();
        if (yieldSourceOracleId == bytes32(0)) revert INVALID_YIELD_SOURCE_ORACLE_ID();

        _lockedAmounts[token] -= amount;
        if (_lockedAmounts[token] == 0) {
            _lockedAssets.remove(token);
        }

        IERC20(token).safeTransfer(account, amount);
        emit SharesUnlocked(yieldSourceOracleId, account, token, amount, _chainId, fromChainId, nonce);
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
