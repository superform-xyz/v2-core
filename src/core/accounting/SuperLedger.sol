// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { BaseLedger } from "./BaseLedger.sol";

/// @title SuperLedger
/// @author Superform Labs
/// @notice Default ISuperLedger implementation
contract SuperLedger is BaseLedger {
    constructor(
        address ledgerConfiguration_,
        address[] memory allowedExecutors_
    )
        BaseLedger(ledgerConfiguration_, allowedExecutors_)
    { }
}
