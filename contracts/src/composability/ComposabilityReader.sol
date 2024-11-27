// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// Superform
import { IComposabilityStackKeys } from "src/interfaces/composability/IComposabilityStackKeys.sol";
import { IComposabilityStackReader } from "src/interfaces/composability/IComposabilityStackReader.sol";

// TODO: update based on MEE composability stack
// left it ownable for now, but we should switch it to rbac
contract ComposabilityReader is IComposabilityStackReader, Ownable {
    IComposabilityStackKeys public composabilityStackKeys;

    constructor(address owner_) Ownable(owner_) { }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event KeysSet(address indexed keys_);

    /*//////////////////////////////////////////////////////////////
                                 OWNER METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Set the composability keys contract
    /// @param keys_ The address of the composability keys contract
    function setComposabilityKeysContract(address keys_) external onlyOwner {
        if (keys_ == address(0)) revert ADDRESS_NOT_VALID();
        composabilityStackKeys = IComposabilityStackKeys(keys_);
        emit KeysSet(keys_);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IComposabilityStackReader
    function get(address target_, bytes4 selector_) external view returns (bytes memory) {
        if (address(composabilityStackKeys) == address(0)) revert KEYS_NOT_SET();

        bytes32 key = composabilityStackKeys.getKey(target_, selector_);
        if (key == bytes32(0)) revert KEY_NOT_FOUND();

        // TODO: add MEE composability stack integration
        return "";
    }
}
