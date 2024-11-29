// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// Superform
import { IComposabilityStackKeys } from "src/interfaces/composability/IComposabilityStackKeys.sol";

// TODO: update based on MEE composability stack
// left it ownable for now, but we should switch it to rbac
contract ComposabilityKeys is Ownable, IComposabilityStackKeys {
    mapping(address => mapping(bytes4 => bytes32)) public keys;

    constructor(address owner_) Ownable(owner_) { }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event KeyAdded(address indexed target_, bytes4 indexed selector_, bytes32 indexed key_);

    /*//////////////////////////////////////////////////////////////
                                 OWNER METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Add a key for the composability stack
    /// @param target_ The target address
    /// @param selector_ The selector of the function
    /// @param key_ The key for the composability stack
    function addKey(address target_, bytes4 selector_, bytes32 key_) external onlyOwner {
        keys[target_][selector_] = key_;
        emit KeyAdded(target_, selector_, key_);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IComposabilityStackKeys
    function getKey(address target_, bytes4 selector_) external view returns (bytes32) {
        return keys[target_][selector_];
    }
}
