// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Superform
import { VaultBankSuperPosition } from "./VaultBankSuperPosition.sol";
import { IVaultBankDestination } from "../interfaces/IVaultBank.sol";

abstract contract VaultBankDestination is IVaultBankDestination {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    // synthetic assets
    mapping(uint64 srcChainId => mapping(address srcTokenAddress => address superPositions)) internal
        _tokenToSuperPosition;
    mapping(address spToken => mapping(uint64 srcChainId => address srcTokenAddress)) internal
        _superPositionToToken;
    mapping(address spToken => bool wasCreated) internal _syntheticAssets;

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IVaultBankDestination
    function getSuperPositionForAsset(uint64 srcChainId, address srcAsset) external view returns (address) {
        return _tokenToSuperPosition[srcChainId][srcAsset];
    }

    /// @inheritdoc IVaultBankDestination
    function getAssetForSuperPosition(uint64 srcChainId, address superPosition) external view returns (address) {
        return _superPositionToToken[superPosition][srcChainId];
    }

    /// @inheritdoc IVaultBankDestination
    function isSuperPositionCreated(address superPosition) external view returns (bool) {
        return _syntheticAssets[superPosition];
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _retrieveSuperPosition(
        uint64 srcChainId,
        address srcAsset,
        string calldata _srcName,
        string calldata _srcSymbol,
        uint8 _srcDecimals
    )
        internal
        returns (address)
    {
        address _created = _tokenToSuperPosition[srcChainId][srcAsset];
        if (_created != address(0)) return _created;

        _created = address(new VaultBankSuperPosition(_srcName, _srcSymbol, _srcDecimals));
        _tokenToSuperPosition[srcChainId][srcAsset] = _created;
        _superPositionToToken[_created][srcChainId] = srcAsset;
        _syntheticAssets[_created] = true;
        return _created;
    }

    function _mintSP(address account, address superPosition, uint256 amount) internal {
        // at this point the asset should exist
        if (!_syntheticAssets[superPosition]) revert SYNTHETIC_ASSET_NOT_FOUND();

        // mint the synthetic asset
        VaultBankSuperPosition(superPosition).mint(account, amount);
    }

    function _burnSP(address account, address superPosition, uint256 amount) internal {
        // at this point the asset should exist
        if (!_syntheticAssets[superPosition]) revert SYNTHETIC_ASSET_NOT_FOUND();

        if (amount > VaultBankSuperPosition(superPosition).balanceOf(account)) revert INVALID_BURN_AMOUNT();

        // burn the synthetic asset
        VaultBankSuperPosition(superPosition).burn(account, amount);
    }
}
