// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// Superform
import { ISuperRegistry } from "src/interfaces/ISuperRegistry.sol";

abstract contract BaseHook {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    ISuperRegistry public superRegistry;

    error AMOUNT_NOT_VALID();
    error ADDRESS_NOT_VALID();

    constructor(address registry_) {
        if (registry_ == address(0)) revert ADDRESS_NOT_VALID();
        superRegistry = ISuperRegistry(registry_);
    }
}
