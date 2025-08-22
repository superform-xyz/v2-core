// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract MockStandardizedYield {
    /// @dev check `assetInfo()` for more information
    enum AssetType {
        TOKEN,
        LIQUIDITY
    }

    address public syToken;
    address public ptToken;
    address public ytToken;

    address public assetToken;
    AssetType public assetTokenType;

    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;

    address[] public tokensIn;
    address[] public tokensOut;

    constructor(address syToken_, address ptToken_, address ytToken_) {
        ptToken = ptToken_;
        syToken = syToken_;
        ytToken = ytToken_;

        assetToken = syToken;
        assetTokenType = AssetType.TOKEN;

        tokensIn.push(syToken);
        tokensIn.push(ptToken);
        tokensIn.push(ytToken);

        tokensOut.push(syToken);
        tokensOut.push(ptToken);
        tokensOut.push(ytToken);
    }

    error NOT_AVAILABLE();

    function assetInfo() external view returns (AssetType assetType, address assetAddress, uint8 assetDecimals) {
        assetType = assetTokenType;
        assetAddress = assetToken;
        assetDecimals = 18;
    }

    function setAssetType(uint256 _assetType) external {
        assetTokenType = AssetType(_assetType);
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

    function getTokensIn() external view returns (address[] memory) {
        return tokensIn;
    }

    function setTokensIn(address[] memory _tokensIn) external {
        tokensIn = _tokensIn;
    }

    function getTokensOut() external view returns (address[] memory) {
        return tokensOut;
    }

    function setTokensOut(address[] memory _tokensOut) external {
        tokensOut = _tokensOut;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function setBalanceForAccount(address acc, uint256 amount) external {
        balanceOf[acc] = amount;
        totalSupply = amount;
    }

    function setTotalAsset(uint256 amount) external {
        totalSupply = amount;
    }
}
