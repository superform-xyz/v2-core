// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

contract MockSpectraPrincipalToken {
    address public yt;
    address public ibt;
    address public underlying;

    mapping(address => uint256) public balances;
    uint256 public totalAssets;
    uint256 public underlyingAmount;

    constructor(address _yt, address _ibt, address _underlying) {
        yt = _yt;
        ibt = _ibt;
        underlying = _underlying;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function convertToPrincipal(uint256 _underlyingAmount) external pure returns (uint256) {
        return _underlyingAmount;
    }

    function convertToUnderlying(uint256 _principalAmount) external pure returns (uint256) {
        return _principalAmount;
    }

    function balanceOf(address acc) external view returns (uint256) {
        return balances[acc];
    }

    function setUnderlying(address _underlying) external {
        underlying = _underlying;
    }

    function setUnderlyingAmount(uint256 _underlyingAmount) external {
        underlyingAmount = _underlyingAmount;
    }

    function mint(address _to, uint256 _amount) external {
        balances[_to] += _amount;
        totalAssets += _amount;
    }
}
