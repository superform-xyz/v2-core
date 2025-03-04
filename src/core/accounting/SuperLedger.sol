// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { BaseLedger } from "./BaseLedger.sol";

/// @title SuperLedger
/// @author Superform Labs
/// @notice Default ISuperLedger implementation
contract SuperLedger is BaseLedger {
    constructor(address registry_) BaseLedger(registry_) { }
}
