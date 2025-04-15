// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import { IPrincipalToken } from "../../../vendor/spectra/IPrincipalToken.sol";
// Superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";

/// @title SpectraYieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for Spectra Principal Tokens (PTs)
contract SpectraYieldSourceOracle is AbstractYieldSourceOracle {
    constructor(address _superRegistry) AbstractYieldSourceOracle(_superRegistry) { }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc AbstractYieldSourceOracle
    function decimals(address ptAddress) external view override returns (uint8) {
        return _decimals(ptAddress);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getShareOutput(address ptAddress, address, uint256 assetsIn) external view override returns (uint256) {
        // Use convertToPrincipal to get shares (PTs) for assets
        return IPrincipalToken(ptAddress).convertToPrincipal(assetsIn);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getAssetOutput(
        address ptAddress,
        address,
        uint256 sharesIn // sharesIn represents the PT amount
    )
        external
        view
        override
        returns (uint256)
    {
        // Use convertToUnderlying to get assets for shares (PTs)
        return IPrincipalToken(ptAddress).convertToUnderlying(sharesIn);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getPricePerShare(address ptAddress) public view override returns (uint256) {
        IPrincipalToken yieldSource = IPrincipalToken(ptAddress);

        // Convert 1 full PT unit (10**decimals) to underlying asset amount
        return yieldSource.convertToUnderlying(10 ** _decimals(ptAddress));
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getBalanceOfOwner(address ptAddress, address ownerOfShares) public view override returns (uint256) {
        // PT balance is directly available via balanceOf
        return _balanceOf(ptAddress, ownerOfShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getTVLByOwnerOfShares(address ptAddress, address ownerOfShares) public view override returns (uint256) {
        IPrincipalToken yieldSource = IPrincipalToken(ptAddress);
        uint256 shares = _balanceOf(ptAddress, ownerOfShares);
        if (shares == 0) return 0;
        // Convert the owner's PT balance to underlying asset value
        return yieldSource.convertToUnderlying(shares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getTVL(address ptAddress) public view override returns (uint256) {
        // Use totalAssets to get the total underlying value held by the PT contract
        return IPrincipalToken(ptAddress).totalAssets();
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function isValidUnderlyingAsset(
        address yieldSourceAddress,
        address expectedUnderlying
    )
        external
        view
        override
        returns (bool)
    {
        return IPrincipalToken(yieldSourceAddress).underlying() == expectedUnderlying;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function _validateBaseAsset(address ptAddress, address base) internal view override {
        // Use underlying() to get the PT's base asset
        if (base != IPrincipalToken(ptAddress).underlying()) revert INVALID_BASE_ASSET();
    }

    function _decimals(address ptAddress) internal view returns (uint8) {
        return IERC20Metadata(ptAddress).decimals();
    }

    function _balanceOf(address ptAddress, address owner) internal view returns (uint256) {
        return IERC20Metadata(ptAddress).balanceOf(owner);
    }
}
