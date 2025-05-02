// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Superform
import { VaultBankAsset } from "./VaultBankAsset.sol";
import { IVaultBankDestination } from "../interfaces/IVaultBank.sol";

abstract contract VaultBankDestination is IVaultBankDestination {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    // synthetic assets
    mapping(uint64 srcChainId => mapping(address srcTokenAddress => address superPositions)) internal
        _tokenToSyntheticAssets;
    mapping(address syntheticToken => mapping(uint64 srcChainId => address srcTokenAddress)) internal
        _syntheticAssetsToToken;
    mapping(address syntheticToken => bool wasCreated) internal _syntheticAssets;

    //TODO: should we enforce this or allow burning more than it was initially by checking just the `balanceOf` ?
    mapping(address syntheticToken => mapping(address account => uint256 balance)) internal _tokenBalances;

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IVaultBankDestination
    function getSpForAsset(uint64 srcChainId, address srcAsset) external view returns (address) {
        return _tokenToSyntheticAssets[srcChainId][srcAsset];
    }

    /// @inheritdoc IVaultBankDestination
    function getAssetForSp(uint64 srcChainId, address syntheticAsset) external view returns (address) {
        return _syntheticAssetsToToken[syntheticAsset][srcChainId];
    }

    /// @inheritdoc IVaultBankDestination
    function isSpCreated(address syntheticAsset) external view returns (bool) {
        return _syntheticAssets[syntheticAsset];
    }

    /// @inheritdoc IVaultBankDestination
    function getBalance(address syntheticAsset, address account) external view returns (uint256) {
        return _tokenBalances[syntheticAsset][account];
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _retrieveSyntheticAsset(
        uint64 srcChainId,
        address srcAsset,
        string calldata _srcName,
        string calldata _srcSymbol,
        uint8 _srcDecimals
    )
        internal
        returns (address)
    {
        address _created = _tokenToSyntheticAssets[srcChainId][srcAsset];
        if (_created != address(0)) return _created;

        _created = address(new VaultBankAsset(_srcName, _srcSymbol, _srcDecimals));
        _tokenToSyntheticAssets[srcChainId][srcAsset] = _created;
        _syntheticAssetsToToken[_created][srcChainId] = srcAsset;
        _syntheticAssets[_created] = true;
        return _created;
    }

    function _mintSP(address account, address syntheticAsset, uint256 amount) internal {
        // at this point the asset should exist
        if (!_syntheticAssets[syntheticAsset]) revert SYNTHETIC_ASSET_NOT_FOUND();

        // mint the synthetic asset
        VaultBankAsset(syntheticAsset).mint(account, amount);
        _tokenBalances[syntheticAsset][account] += amount;
    }

    function _burnSP(address account, address syntheticAsset, uint256 amount) internal {
        // at this point the asset should exist
        if (!_syntheticAssets[syntheticAsset]) revert SYNTHETIC_ASSET_NOT_FOUND();

        if (amount > _tokenBalances[syntheticAsset][account]) revert INVALID_BURN_AMOUNT();

        // burn the synthetic asset
        VaultBankAsset(syntheticAsset).burn(account, amount);
        _tokenBalances[syntheticAsset][account] -= amount;
    }
}
