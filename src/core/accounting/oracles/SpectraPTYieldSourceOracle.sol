// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import { IPrincipalToken } from "../../../vendor/spectra/IPrincipalToken.sol";
// Superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";

/// @title SpectraPTYieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for Spectra Principal Tokens (PTs)
contract SpectraPTYieldSourceOracle is AbstractYieldSourceOracle {
    constructor() AbstractYieldSourceOracle() { }

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
        public
        view
        override
        returns (bool)
    {
        return IPrincipalToken(yieldSourceAddress).underlying() == expectedUnderlying;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function isValidUnderlyingAssets(
        address[] memory yieldSourceAddresses,
        address[] memory expectedUnderlying
    )
        external
        view
        override
        returns (bool[] memory isValid)
    {
        uint256 length = yieldSourceAddresses.length;
        if (length != expectedUnderlying.length) revert ARRAY_LENGTH_MISMATCH();

        isValid = new bool[](length);
        for (uint256 i; i < length; ++i) {
            // Reuse the public logic directly
            isValid[i] = isValidUnderlyingAsset(yieldSourceAddresses[i], expectedUnderlying[i]);
        }
    }

    function _decimals(address ptAddress) internal view returns (uint8) {
        return IERC20Metadata(ptAddress).decimals();
    }

    function _balanceOf(address ptAddress, address owner) internal view returns (uint256) {
        return IERC20Metadata(ptAddress).balanceOf(owner);
    }
}
