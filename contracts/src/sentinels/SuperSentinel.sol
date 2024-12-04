// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// Superform
import { ISentinel } from "src/interfaces/sentinel/ISentinel.sol";
import { ISentinelData } from "src/interfaces/sentinel/ISentinelData.sol";
import { ISentinelProcessor } from "src/interfaces/sentinel/ISentinelProcessor.sol";
import { SuperRegistryImplementer } from "src/utils/SuperRegistryImplementer.sol";

// The following contract notifies based on received input and output
contract SuperSentinel is ISentinel, SuperRegistryImplementer, Ownable {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(address => bool) public processors;

    constructor(address registry_, address owner_) SuperRegistryImplementer(registry_) Ownable(owner_) { }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISentinel
    function updateProcessorStatus(address processor_, bool status_) external onlyOwner {
        if (processor_ == address(0)) revert ADDRESS_NOT_VALID();
        processors[processor_] = status_;
        emit ProcessorStatusUpdated(processor_, status_);
    }

    /// @inheritdoc ISentinel
    function notify(ISentinelData.Entry memory entry_) external {
        _process(entry_.target, entry_.selector, entry_.input, entry_.inputProcessor);
        _process(entry_.target, entry_.selector, entry_.output, entry_.outputProcessor);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _process(address target_, bytes4 selector_, bytes memory data_, address processor_) private {
        if (processor_ == address(0)) return; // nothing to process
        if (!processors[processor_]) revert PROCESSOR_NOT_WHITELISTED();
        ISentinelProcessor(processor_).process(target_, selector_, data_);
    }
}
