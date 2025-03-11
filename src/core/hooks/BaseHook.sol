// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// Superform
import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";
import { ISuperHook } from "../interfaces/ISuperHook.sol";

/// @title BaseHook
/// @author Superform Labs
/// @notice Base hook for all hooks
abstract contract BaseHook is SuperRegistryImplementer {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    // forgefmt: disable-start
    uint256 public transient outAmount;
    uint256 public transient usedShares;
    bool public transient lockForSP;
    address public transient spToken;
    address public transient asset;
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

    function _replaceCalldataAmount(bytes memory data, uint256 amount, uint256 offset) internal pure returns (bytes memory) {
        bytes memory newAmountEncoded = abi.encodePacked(amount);
        for (uint256 i; i < 32;) {
            data[offset + i] = newAmountEncoded[i];
            unchecked { ++i; }
        }
        return data;
    }   

    function _getAddress(bytes32 id_) internal view returns (address) {
        return superRegistry.getAddress(id_);
    }
}
