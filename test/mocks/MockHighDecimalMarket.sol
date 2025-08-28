// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract MockHighDecimalMarket {
    address public sy;
    address public pt;
    address public yt;
    uint256 public ptToAssetRate;

    constructor(address _sy, address _pt, address _yt) {
        sy = _sy;
        pt = _pt;
        yt = _yt;
        ptToAssetRate = 1e18; // Default rate
    }

    function readTokens() external view returns (address, address, address) {
        return (sy, pt, yt);
    }

    function getPtToAssetRate(uint32) external view returns (uint256) {
        return ptToAssetRate;
    }

    function setPtToAssetRate(uint256 _rate) external {
        ptToAssetRate = _rate;
    }

    function expiry() external pure returns (uint256) {
        return 1e18;
    }

    function observe(uint32[] calldata) external pure returns (uint216[] memory, uint216[] memory) {
        uint216[] memory logImpliedRates = new uint216[](2);
        uint216[] memory logPYIndexes = new uint216[](2);

        // Return mock values
        logImpliedRates[0] = uint216(1e18);
        logImpliedRates[1] = uint216(1e18);
        logPYIndexes[0] = uint216(1e18);
        logPYIndexes[1] = uint216(1e18);

        return (logImpliedRates, logPYIndexes);
    }
}
