// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

interface ISpectraPTToken {
    function deposit(uint256 assets, address ptReceiver, address ytReceiver) external returns (uint256 shares);

    function underlying() external view returns (address);
}
