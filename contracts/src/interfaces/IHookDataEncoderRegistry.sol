// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IHookDataEncoder } from "./IHookDataEncoder.sol";

/**
 * @title IHookDataEncoderRegistry
 * @notice Interface for registry that manages encoders for different vault types
 * @dev Each vault type (ERC4626, ERC7540, etc.) has its own encoder for hook data
 */
interface IHookDataEncoderRegistry {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new encoder is registered
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

    /// @notice Register a new encoder for a vault type
    /// @param encoder The encoder to register
    function registerEncoder(IHookDataEncoder encoder) external;

    /// @notice Remove an encoder for a vault type
    /// @param type_ The type to remove encoder for
    function removeEncoder(string calldata type_) external;

    /// @notice Get encoder for a vault type
    /// @param type_ The type to get encoder for
    /// @return The encoder for the type
    function getEncoder(string calldata type_) external view returns (IHookDataEncoder);

    /// @notice Get all supported types
    /// @return Array of supported types
    function getSupportedTypes() external view returns (string[] memory);

    /// @notice Get encoder for a specific type
    /// @param type_ The type to get encoder for
    /// @return The encoder address
    function encoders(string calldata type_) external view returns (IHookDataEncoder);

    /// @notice Get type at specific index
    /// @param index The index to get type for
    /// @return The type at the index
    function types(uint256 index) external view returns (string memory);
} 