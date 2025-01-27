// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

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
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Set the address of an ID.
    /// @param id_ The ID.
    /// @param address_ The address.
    function setAddress(bytes32 id_, address address_) external;

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Get the address of an ID.
    /// @param id_ The ID.
    /// @return The address.
    function getAddress(bytes32 id_) external view returns (address);

    // ids
    // -- executors
    /// @dev Get the ID of the super executor.
    function SUPER_EXECUTOR_ID() external view returns (bytes32);

    /// @dev Get the ID of the super gateway executor.
    function SUPER_GATEWAY_EXECUTOR_ID() external view returns (bytes32);

    // -- RBAC
    /// @dev Get the ID of the SuperRbac.
    function SUPER_RBAC_ID() external view returns (bytes32);

    // -- SuperPositions
    /// @dev Get the ID of the super positions.
    function SUPER_POSITIONS_ID() external view returns (bytes32);

    // -- actions
    /// @dev Get the ID of the super actions.
    function SUPER_LEDGER_ID() external view returns (bytes32);

    // -- sentinels
    /// @dev Get the ID of the super position sentinel.
    function SUPER_POSITION_SENTINEL_ID() external view returns (bytes32);

    // -- bridges
    /// @dev Get the ID of the Across receive funds and execute gateway.
    function ACROSS_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_ID() external view returns (bytes32);

    /// @dev Get the ID of the DeBridge receive funds and execute gateway.
    function DEBRIDGE_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_ID() external view returns (bytes32);

    // -- paymaster
    /// @dev Get the ID of the paymaster.
    function PAYMASTER_ID() external view returns (bytes32);

    // -- SuperBundler
    /// @dev Get the ID of the super bundler.
    function SUPER_BUNDLER_ID() external view returns (bytes32);

    // -- SuperCollectiveVault
    /// @dev Get the ID of the super collective vault.
    function SUPER_COLLECTIVE_VAULT_ID() external view returns (bytes32);
}
