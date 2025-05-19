// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { IERC20Metadata } from "openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";

/// @title AssetMetadataLib
/// @author Superform Labs
/// @notice Library for handling ERC20 metadata operations
library AssetMetadataLib {
    /**
     * @notice Attempts to fetch an asset's decimals
     * @dev A return value of false indicates that the attempt failed in some way
     * @param asset_ The address of the token to query
     * @return ok Boolean indicating if the operation was successful
     * @return assetDecimals The token's decimals if successful, 0 otherwise
     */
    function tryGetAssetDecimals(address asset_) internal view returns (bool ok, uint8 assetDecimals) {
        (bool success, bytes memory encodedDecimals) =
            address(asset_).staticcall(abi.encodeCall(IERC20Metadata.decimals, ()));
        if (success && encodedDecimals.length >= 32) {
            uint256 returnedDecimals = abi.decode(encodedDecimals, (uint256));
            if (returnedDecimals <= type(uint8).max) {
                return (true, uint8(returnedDecimals));
            }
        }
        return (false, 0);
    }
}
