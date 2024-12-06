// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Superform
import { ISuperRbac } from "src/interfaces/ISuperRbac.sol";
import { ISentinel } from "src/interfaces/sentinel/ISentinel.sol";
import { ISentinelData } from "src/interfaces/sentinel/ISentinelData.sol";
import { ISentinelProcessor } from "src/interfaces/sentinel/ISentinelProcessor.sol";

import { SuperRegistryImplementer } from "src/utils/SuperRegistryImplementer.sol";

// The following contract notifies based on received input and output
contract SuperSentinel is ISentinel, SuperRegistryImplementer {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(address => bool) public whitelistedProcessors;

    constructor(address registry_) SuperRegistryImplementer(registry_) { }

    modifier onlySentinelConfigurator() {
        ISuperRbac rbac = ISuperRbac(superRegistry.getAddress(superRegistry.SUPER_RBAC_ID()));
        if (!rbac.hasRole(msg.sender, rbac.SENTINEL_CONFIGURATOR())) revert NOT_AUTHORIZED();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISentinel
    function updateProcessorStatus(address processor_, bool status_) external onlySentinelConfigurator {
        if (processor_ == address(0)) revert ADDRESS_NOT_VALID();
        whitelistedProcessors[processor_] = status_;
        emit ProcessorStatusUpdated(processor_, status_);
    }

    /// @inheritdoc ISentinel
    function notify(ISentinelData.Entry memory entry_) external {
        bytes memory eventOutput_;

        if (entry_.processInput) {
            eventOutput_ = _process(entry_.target, entry_.selector, entry_.input, entry_.inputProcessor);
            emit Processed(ProcessType.INPUT, entry_.target, entry_.selector, eventOutput_);
        }

        eventOutput_ = _process(entry_.target, entry_.selector, entry_.output, entry_.outputProcessor);
        emit Processed(ProcessType.OUTPUT, entry_.target, entry_.selector, eventOutput_);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _process(
        address target_,
        bytes4 selector_,
        bytes memory data_,
        address processor_
    )
        private
        returns (bytes memory eventOutput_)
    {
        if (processor_ == address(0)) return ""; // nothing to process
        if (!whitelistedProcessors[processor_]) revert PROCESSOR_NOT_WHITELISTED();
        eventOutput_ =
            ISentinelProcessor(processor_).process(_getSharedStateKey(target_, selector_), target_, selector_, data_);
    }

    function _getSharedStateKey(address target_, bytes4 selector_) private view returns (bytes32) {
        return keccak256(abi.encodePacked(superRegistry.sharedStateNamespace(), target_, selector_));
    }
}
