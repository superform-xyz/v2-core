// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// Superform
import { SuperRegistryImplementer } from "src/utils/SuperRegistryImplementer.sol";

abstract contract BaseHook is SuperRegistryImplementer {
    address public immutable author;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error AMOUNT_NOT_VALID();
    error ADDRESS_NOT_VALID();

    constructor(address registry_, address author_) SuperRegistryImplementer(registry_) {
        author = author_;
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _returnDefaultTransientStorage()
        internal
        pure
        returns (address _addr, uint256 _value, bytes32 _data, bool _flag)
    {
        return (address(0), 0, bytes32(0), false);
    }
}
