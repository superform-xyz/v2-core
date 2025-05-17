// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

// Superform
import { SuperOracleBase } from "./SuperOracleBase.sol";

/// @title SuperOracle
/// @author Superform Labs
/// @notice Oracle for Superform
contract SuperOracle is SuperOracleBase {
    constructor(
        address owner_,
        address[] memory bases,
        address[] memory quotes,
        bytes32[] memory providers,
        address[] memory feeds
    )
        SuperOracleBase(owner_, bases, quotes, providers, feeds)
    { }
}
