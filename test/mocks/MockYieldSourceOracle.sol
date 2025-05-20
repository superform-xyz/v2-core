// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import { IYieldSourceOracle } from "../../src/core/interfaces/accounting/IYieldSourceOracle.sol";

// Mock YieldSourceOracle implementation for testing
contract MockYieldSourceOracle is IYieldSourceOracle {
    uint256 public pricePerShare;
    uint256 public tvl;
    uint256 public tvlByOwner;
    bool public validity;
    mapping(address => bool) public validAssetMap;

    constructor(uint256 _pricePerShare, uint256 _tvl, uint256 _tvlByOwner, bool _validity) {
        pricePerShare = _pricePerShare;
        tvl = _tvl;
        tvlByOwner = _tvlByOwner;
        validity = _validity;
    }

    function setPricePerShare(uint256 _pricePerShare) external {
        pricePerShare = _pricePerShare;
    }

    function setTVL(uint256 _tvl) external {
        tvl = _tvl;
    }

    function setTVLByOwner(uint256 _tvlByOwner) external {
        tvlByOwner = _tvlByOwner;
    }

    function setValidity(bool _validity) external {
        validity = _validity;
    }

    function setValidAsset(address asset, bool isValid) external {
        validAssetMap[asset] = isValid;
    }

    function decimals(address) external pure returns (uint8) {
        return 18;
    }

    function getShareOutput(address, address, uint256 assetsIn) external pure returns (uint256) {
        return assetsIn;
    }

    function getAssetOutput(address, address, uint256 sharesIn) external pure returns (uint256) {
        return sharesIn;
    }

    function getBalanceOfOwner(address, address) external view returns (uint256) {
        return tvlByOwner;
    }

    function getPricePerShare(address) external view returns (uint256) {
        return pricePerShare;
    }

    function getTVLByOwnerOfShares(address, address) external view returns (uint256) {
        return tvlByOwner;
    }

    function getTVL(address) external view returns (uint256) {
        return tvl;
    }

    function getPricePerShareMultiple(address[] memory) external view returns (uint256[] memory) {
        uint256[] memory prices = new uint256[](1);
        prices[0] = pricePerShare;
        return prices;
    }

    function getTVLByOwnerOfSharesMultiple(
        address[] memory yieldSources,
        address[][] memory
    )
        external
        view
        returns (uint256[][] memory)
    {
        uint256[][] memory result = new uint256[][](yieldSources.length);
        for (uint256 i = 0; i < yieldSources.length; i++) {
            result[i] = new uint256[](1);
            result[i][0] = tvlByOwner;
        }
        return result;
    }

    function getTVLMultiple(address[] memory) external view returns (uint256[] memory) {
        uint256[] memory tvls = new uint256[](1);
        tvls[0] = tvl;
        return tvls;
    }

    function isValidUnderlyingAsset(address, address asset) external view returns (bool) {
        return validAssetMap[asset];
    }

    function isValidUnderlyingAssets(address[] memory, address[] memory) external view returns (bool[] memory) {
        bool[] memory validities = new bool[](1);
        validities[0] = validity;
        return validities;
    }
}