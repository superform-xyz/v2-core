// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IGyldNavFeed } from "../../../src/vendor/gyld/IGyldNavFeed.sol";

/// @notice Gyld-native NAV feed stand-in: exposes BOTH clocks so the observation-vs-publication split can be
///         driven independently, which a Chainlink-style mock cannot do.
contract MockGyldNavFeed is IGyldNavFeed {
    uint8 private _decimals;

    mapping(address bondToken => uint256 nav) public navOf;
    mapping(address bondToken => uint256 navAsOf) public observedAtOf;
    mapping(address bondToken => uint256 publishedAt) public publishedAtOf;

    constructor(uint8 decimals_) {
        _decimals = decimals_;
    }

    function setNav(address bondToken, uint256 nav, uint256 navAsOf, uint256 publishedAt) external {
        navOf[bondToken] = nav;
        observedAtOf[bondToken] = navAsOf;
        publishedAtOf[bondToken] = publishedAt;
    }

    /// @notice Publishes `nav` as of now on both clocks
    function setFreshNav(address bondToken, uint256 nav) external {
        navOf[bondToken] = nav;
        observedAtOf[bondToken] = block.timestamp;
        publishedAtOf[bondToken] = block.timestamp;
    }

    function latestNav(address bondToken) external view returns (uint256, uint256, uint256) {
        return (navOf[bondToken], observedAtOf[bondToken], publishedAtOf[bondToken]);
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }
}
