// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { ISentinelData } from "src/interfaces/sentinel/ISentinelData.sol";

interface ISentinel {
    enum ProcessType {
        INPUT,
        OUTPUT
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event ProcessorStatusUpdated(address indexed processor_, bool indexed status_);
    event Processed(
        ProcessType indexed processType_, address indexed target_, bytes4 indexed selector_, bytes eventOutput_
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NOT_AUTHORIZED();
    error ADDRESS_NOT_VALID();
    error PROCESSOR_NOT_WHITELISTED();

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Add or remove a processor to the whitelist
    /// @param processor_ The address of the processor to whitelist
    /// @param status_ The status of the processor
    function updateProcessorStatus(address processor_, bool status_) external;

    /// @dev Notify the sentinel
    /// @param entry_ The entry.
    function notify(ISentinelData.Entry memory entry_) external;
}
