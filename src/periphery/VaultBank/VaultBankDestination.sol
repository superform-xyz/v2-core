// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Superform
import { VaultBankSuperPosition } from "./VaultBankSuperPosition.sol";
import { IVaultBankDestination } from "../interfaces/VaultBank/IVaultBank.sol";

abstract contract VaultBankDestination is IVaultBankDestination {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    // synthetic assets
    mapping(uint64 srcChainId => mapping(bytes32 yieldSourceOracleId => mapping(address srcTokenAddress => address superPositions))) internal
        _tokenToSuperPosition;
    mapping(address spToken => SpAsset) internal _spAssetsInfo;

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IVaultBankDestination
    function getSuperPositionForAsset(uint64 srcChainId, address srcAsset, bytes32 yieldSourceOracleId) external view returns (address) {
        return _tokenToSuperPosition[srcChainId][yieldSourceOracleId][srcAsset];
    }

    /// @inheritdoc IVaultBankDestination
    function getAssetForSuperPosition(uint64 srcChainId, address superPosition, bytes32 yieldSourceOracleId) external view returns (address) {
        return _spAssetsInfo[superPosition].spToToken[srcChainId][yieldSourceOracleId];
    }

    /// @inheritdoc IVaultBankDestination
    function isSuperPositionCreated(address superPosition) external view returns (bool) {
        return _spAssetsInfo[superPosition].wasCreated;
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _retrieveSuperPosition(
        bytes32 yieldSourceOracleId,
        uint64 srcChainId,
        address srcAsset,
        string calldata _srcName,
        string calldata _srcSymbol,
        uint8 _srcDecimals
    )
        internal
        returns (address)
    {
        address _created = _tokenToSuperPosition[srcChainId][yieldSourceOracleId][srcAsset];
        if (_created != address(0)) return _created;

        _created = address(new VaultBankSuperPosition(_srcName, _srcSymbol, _srcDecimals, yieldSourceOracleId));
        _tokenToSuperPosition[srcChainId][yieldSourceOracleId][srcAsset] = _created;
        _spAssetsInfo[_created].spToToken[srcChainId][yieldSourceOracleId] = srcAsset;
        _spAssetsInfo[_created].wasCreated = true;
        return _created;
    }

    function _mintSP(address account, address superPosition, uint256 amount) internal {
        // at this point the asset should exist
        if (!_spAssetsInfo[superPosition].wasCreated) revert SUPERPOSITION_ASSET_NOT_FOUND();

        // mint the synthetic asset
        VaultBankSuperPosition(superPosition).mint(account, amount);
    }

    function _burnSP(address account, address superPosition, uint256 amount) internal {
        // at this point the asset should exist
        if (!_spAssetsInfo[superPosition].wasCreated) revert SUPERPOSITION_ASSET_NOT_FOUND();

        if (amount > VaultBankSuperPosition(superPosition).balanceOf(account)) revert INVALID_BURN_AMOUNT();

        // burn the synthetic asset
        VaultBankSuperPosition(superPosition).burn(account, amount);
    }
}
