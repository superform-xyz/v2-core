// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

interface ISuperRegistry {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event AddressSet(bytes32 indexed id, address indexed addr);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_ADDRESS();

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Get the address of an ID.
    /// @param id_ The ID.
    /// @return The address.
    function getAddress(bytes32 id_) external view returns (address);

    // ids
    /// @dev Get the ID of the SuperRbac.
    function SUPER_RBAC_ID() external view returns (bytes32);

    /// @dev Get the ID of the relayer.
    function RELAYER_ID() external view returns (bytes32);

    /// @dev Get the ID of the relayer sentinel.
    function RELAYER_SENTINEL_ID() external view returns (bytes32);
}
