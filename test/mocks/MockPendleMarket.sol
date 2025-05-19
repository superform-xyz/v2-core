// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

contract MockPendleMarket {
    address public syToken;
    address public ptToken;
    address public ytToken;


    uint256 public ptToAssetRate;

    constructor(address syToken_, address ptToken_, address ytToken_) {
        ptToken = ptToken_;
        syToken = syToken_;
        ytToken = ytToken_;
    }

    function readTokens() external view returns (address, address, address) {
        return (syToken, ptToken, ytToken);
    }

    function setPtToAssetRate(uint256 _rate) external {
        ptToAssetRate = _rate;
    }
    function getPtToAssetRate() external view returns (uint256) {
        return ptToAssetRate;
    }

    function expiry() external view returns (uint256) {
        return block.timestamp + 100 days;
    }

    function observe(uint32[] memory) external pure returns (uint216[] memory) {
        uint216[] memory results = new uint216[](2);
        results[0] = 1e18;
        results[1] = 1e18;
        return results;
    }
}
