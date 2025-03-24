// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { ISuperRegistry } from "../interfaces/ISuperRegistry.sol";

/// @title SuperRegistryImplementer
/// @author Superform Labs
/// @notice Abstract contract for implementing the SuperRegistry
abstract contract SuperRegistryImplementer {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    ISuperRegistry public immutable superRegistry;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZERO_ADDRESS();

    constructor(address superRegistry_) {
        if (superRegistry_ == address(0)) revert ZERO_ADDRESS();
        superRegistry = ISuperRegistry(superRegistry_);
    }
}
