// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface ISentinel {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Processed(uint256 actionId, address yieldSourceAddress);

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
    /// @param yieldSourceAddress_ The yield source address
    /// @param entry_ The entry
    function notify(uint256 actionId_, address yieldSourceAddress_, bytes memory entry_) external;
}
