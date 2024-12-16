// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Superform
import { ISentinel } from "../interfaces/sentinel/ISentinel.sol";

import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";

contract SuperPositionSentinel is ISentinel, SuperRegistryImplementer {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    constructor(address registry_) SuperRegistryImplementer(registry_) { }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event SuperPositionMint(uint256 indexed actionId_, address indexed finalTarget_, uint256 amount_);
    event SuperPositionBurn(uint256 indexed actionId_, address indexed finalTarget_, uint256 amount_);

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISentinel

    function notify(uint256 actionId_, address finalTarget_, bytes memory entry_) external {
        (uint256 amount, bool mint) = abi.decode(entry_, (uint256, bool));
        if (mint) {
            emit SuperPositionMint(actionId_, finalTarget_, amount);
        } else {
            emit SuperPositionBurn(actionId_, finalTarget_, amount);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getSharedStateKey(address target_, bytes4 selector_) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                bytes32(
                    uint256(keccak256(abi.encodePacked(superRegistry.sharedStateNamespace(), target_, selector_))) - 1
                ) & ~bytes32(uint256(0xff))
            )
        );
    }
}
