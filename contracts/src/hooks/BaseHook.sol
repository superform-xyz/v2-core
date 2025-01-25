// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// Superform
import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";

import { ISuperHook } from "../interfaces/ISuperHook.sol";

abstract contract BaseHook is SuperRegistryImplementer {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    // forgefmt: disable-start
    bool public transient isInflow;
    uint256 public transient outAmount;
    // forgefmt: disable-end
    address public immutable author;
    ISuperHook.HookType public hookType;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NOT_AUTHORIZED();
    error AMOUNT_NOT_VALID();
    error ADDRESS_NOT_VALID();

    constructor(address registry_, address author_, ISuperHook.HookType hookType_) SuperRegistryImplementer(registry_) {
        author = author_;
        hookType = hookType_;
    }


    modifier onlyExecutor() {
        if (_getAddress(superRegistry.SUPER_EXECUTOR_ID()) != msg.sender) revert NOT_AUTHORIZED();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _decodeBool(bytes memory data, uint256 offset) internal pure returns (bool) {
        require(data.length >= offset + 1, "Data length insufficient");
        uint8 value;
        assembly {
            value := byte(0, mload(add(data, add(offset, 32))))
        }
        return value != 0;
    }

    function _getAddress(bytes32 id_) internal view returns (address) {
        return superRegistry.getAddress(id_);
    }
}
