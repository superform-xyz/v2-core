// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

interface ISuperRegistry {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event AddressSet(bytes32 indexed id, address indexed addr);
    event FeeSplitUpdated(uint256 superformFeeSplit);
    event FeeSplitProposed(uint256 superformFeeSplit, uint256 effectiveTime);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_ADDRESS();
    error INVALID_FEE_SPLIT();
    error TIMELOCK_NOT_EXPIRED();

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Set the address of an ID.
    /// @param id_ The ID.
    /// @param address_ The address.
    function setAddress(bytes32 id_, address address_) external;

    /// @dev Propose a new fee split for Superform.
    /// @param feeSplit_ The new fee split in basis points (0-10000).
    function proposeFeeSplit(uint256 feeSplit_) external;

    /// @dev Execute the proposed fee split update after timelock.
    function executeFeeSplitUpdate() external;

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Get the address of an ID.
    /// @param id_ The ID.
    /// @return The address.
    function getAddress(bytes32 id_) external view returns (address);

    /// @dev Get the current Superform fee split.
    /// @return The fee split in basis points (0-10000).
    function getSuperformFeeSplit() external view returns (uint256);

    /// @dev Get the treasury address.
    /// @return The treasury address.
    function getTreasury() external view returns (address);
}