// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

/**
 * @title IVaultEncoderRegistry
 * @notice Interface for managing hook data encoders for a specific vault
 */
interface IVaultEncoderRegistry {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when an encoder is registered
    event EncoderRegistered(string type_, address encoder);

    /// @notice Emitted when an encoder is removed
    event EncoderRemoved(string type_);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Invalid encoder address
    error INVALID_ENCODER();

    /// @notice Type not found in registry
    error TYPE_NOT_FOUND();

    /// @notice Type already has an encoder
    error TYPE_ALREADY_EXISTS();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Register an encoder for a vault type
    /// @param encoder The encoder to register
    function registerEncoder(address encoder) external;

    /// @notice Remove an encoder for a vault type
    /// @param vaultType The vault type to remove the encoder for
    function removeEncoder(string calldata vaultType) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the encoder for a vault type
    /// @param vaultType The vault type to get the encoder for
    /// @return The encoder address
    function getEncoder(string calldata vaultType) external view returns (address);

    /// @notice Get all supported types
    /// @return Array of supported types
    function getSupportedTypes() external view returns (string[] memory);

    /// @notice Get encoder for a specific type
    /// @param type_ The type to get encoder for
    /// @return The encoder address
    function encoders(string calldata type_) external view returns (address);

    /// @notice Get type at specific index
    /// @param index The index to get type for
    /// @return The type at the index
    function types(uint256 index) external view returns (string memory);
} 