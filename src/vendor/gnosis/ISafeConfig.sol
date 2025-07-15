// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

interface ISafeConfig {
    function getOwners() external view returns (address[] memory);
    function getThreshold() external view returns (uint256);
    function isOwner(address owner) external view returns (bool);
}
