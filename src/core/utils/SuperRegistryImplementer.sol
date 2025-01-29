// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { ISuperRegistry } from "../interfaces/ISuperRegistry.sol";

abstract contract SuperRegistryImplementer {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    ISuperRegistry public superRegistry;

    constructor(address superRegistry_) {
        superRegistry = ISuperRegistry(superRegistry_);
    }
}
