// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { ISentinelData } from "src/interfaces/sentinel/ISentinelData.sol";

interface ISentinel {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event DecoderStatusUpdated(address indexed decoder_, bool indexed status_);
    event Notification(address indexed decoder_, ISentinelData.Entry entry_);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ADDRESS_NOT_VALID();
    error DECODER_NOT_WHITELISTED();

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Add or remove a decoder to the whitelist
    /// @param decoder_ The address of the decoder to whitelist
    /// @param status_ The status of the decoder
    function updateDecoderStatus(address decoder_, bool status_) external;

    /// @dev Notify the sentinel
    /// @param entry_ The entry.
    function notify(ISentinelData.Entry memory entry_) external;
}
