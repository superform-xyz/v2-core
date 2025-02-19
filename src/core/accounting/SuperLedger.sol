// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { ISuperLedger } from "../interfaces/accounting/ISuperLedger.sol";


import {BaseLedger} from "./BaseLedger.sol";

/// @notice Default ISuperLedger implementation
contract SuperLedger is BaseLedger {
    constructor(address registry_) BaseLedger(registry_) { }
}