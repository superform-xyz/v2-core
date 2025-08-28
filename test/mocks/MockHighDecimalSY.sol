// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract MockHighDecimalSY {
    enum AssetType {
        TOKEN,
        LIQUIDITY
    }

    address public assetToken;
    uint8 public assetDecimals;

    constructor(address _assetToken, uint8 _assetDecimals) {
        assetToken = _assetToken;
        assetDecimals = _assetDecimals;
    }

    function assetInfo() external view returns (AssetType assetType, address assetAddress, uint8 decimals) {
        assetType = AssetType.TOKEN;
        assetAddress = assetToken;
        decimals = assetDecimals;
    }

    function exchangeRate() external pure returns (uint256) {
        return 1e18;
    }

    function pyIndexStored() external pure returns (uint256) {
        return 1e18;
    }

    function doCacheIndexSameBlock() external pure returns (bool) {
        return true;
    }

    function pyIndexLastUpdatedBlock() external pure returns (uint256) {
        return 1e18;
    }
}
