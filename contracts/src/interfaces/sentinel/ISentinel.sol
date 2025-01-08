// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface ISentinel {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Processed(uint256 actionId, address finalTarget);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NOT_AUTHORIZED();
    error ADDRESS_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Notify the sentinel
    /// @param actionId_ The action id
    /// @param finalTarget_ The final target
    /// @param entry_ The entry
    function notify(uint256 actionId_, address finalTarget_, bytes memory entry_) external;
}
