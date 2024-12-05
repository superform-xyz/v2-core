// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface ISharedStateOperations {
    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Add uint data
    /// @param key_ The key of the stored data
    /// @param index_ The index of the stored data
    /// @param value_ The value of the stored data
    function addUint(bytes32 key_, uint256 index_, uint256 value_) external;
    /// @notice Sub uint data
    /// @param key_ The key of the stored data
    /// @param index_ The index of the stored data
    /// @param value_ The value of the stored data
    function subUint(bytes32 key_, uint256 index_, uint256 value_) external;
    /// @notice Mul uint data
    /// @param key_ The key of the stored data
    /// @param index_ The index of the stored data
    /// @param value_ The value of the stored data
    function mulUint(bytes32 key_, uint256 index_, uint256 value_) external;
    /// @notice Div uint data
    /// @param key_ The key of the stored data
    /// @param index_ The index of the stored data
    /// @param value_ The value of the stored data
    function divUint(bytes32 key_, uint256 index_, uint256 value_) external;

    /// @notice Add int data
    /// @param key_ The key of the stored data
    /// @param index_ The index of the stored data
    /// @param value_ The value of the stored data
    function addInt(bytes32 key_, uint256 index_, int256 value_) external;
    /// @notice Sub int data
    /// @param key_ The key of the stored data
    /// @param index_ The index of the stored data
    /// @param value_ The value of the stored data
    function subInt(bytes32 key_, uint256 index_, int256 value_) external;
    /// @notice Mul int data
    /// @param key_ The key of the stored data
    /// @param index_ The index of the stored data
    /// @param value_ The value of the stored data
    function mulInt(bytes32 key_, uint256 index_, int256 value_) external;
    /// @notice Div int data
    /// @param key_ The key of the stored data
    /// @param index_ The index of the stored data
    /// @param value_ The value of the stored data
    function divInt(bytes32 key_, uint256 index_, int256 value_) external;
}
