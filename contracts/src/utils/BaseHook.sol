// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// Superform
import { ISuperRegistry } from "src/interfaces/ISuperRegistry.sol";
import { SuperRegistryImplementer } from "src/utils/SuperRegistryImplementer.sol";

abstract contract BaseHook is SuperRegistryImplementer {
    address public immutable author;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error AMOUNT_NOT_VALID();
    error ADDRESS_NOT_VALID();

    constructor(address registry_, address author_) SuperRegistryImplementer(registry_) {
        author = author_;
    }
}
