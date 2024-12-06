// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface ISharedStateWriter {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event DataStored(bytes32 key, bytes data);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_KEY();

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Set address data
    /// @param key_ The key of the stored data
    /// @param value_ The value of the stored data
    function setAddress(bytes32 key_, address value_) external;
    /// @notice Set address data
    /// @param key_ The key of the stored data
    /// @param value_ The value of the stored data
    /// @param index_ The index of the stored data
    function setAddress(bytes32 key_, address value_, uint256 index_) external;

    /// @notice Set uint data
    /// @param key_ The key of the stored data
    /// @param value_ The value of the stored data
    function setUint(bytes32 key_, uint256 value_) external;
    /// @notice Set uint data
    /// @param key_ The key of the stored data
    /// @param value_ The value of the stored data
    /// @param index_ The index of the stored data
    function setUint(bytes32 key_, uint256 value_, uint256 index_) external;

    /// @notice Set int data
    /// @param key_ The key of the stored data
    /// @param value_ The value of the stored data
    function setInt(bytes32 key_, int256 value_) external;
    /// @notice Set int data
    /// @param key_ The key of the stored data
    /// @param value_ The value of the stored data
    /// @param index_ The index of the stored data
    function setInt(bytes32 key_, int256 value_, uint256 index_) external;

    /// @notice Set string data
    /// @param key_ The key of the stored data
    /// @param value_ The value of the stored data
    function setString(bytes32 key_, string calldata value_) external;
    /// @notice Set string data
    /// @param key_ The key of the stored data
    /// @param value_ The value of the stored data
    /// @param index_ The index of the stored data
    function setString(bytes32 key_, string calldata value_, uint256 index_) external;

    /// @notice Set bool data
    /// @param key_ The key of the stored data
    /// @param value_ The value of the stored data
    function setBool(bytes32 key_, bool value_) external;
    /// @notice Set bool data
    /// @param key_ The key of the stored data
    /// @param value_ The value of the stored data
    /// @param index_ The index of the stored data
    function setBool(bytes32 key_, bool value_, uint256 index_) external;

    /// @notice Set bytes32 data
    /// @param key_ The key of the stored data
    /// @param value_ The value of the stored data
    function setBytes32(bytes32 key_, bytes32 value_) external;
    /// @notice Set bytes32 data
    /// @param key_ The key of the stored data
    /// @param value_ The value of the stored data
    /// @param index_ The index of the stored data
    function setBytes32(bytes32 key_, bytes32 value_, uint256 index_) external;

    /// @notice Set bytes data
    /// @param key_ The key of the stored data
    /// @param value_ The value of the stored data
    function setBytes(bytes32 key_, bytes calldata value_) external;
    /// @notice Set bytes data
    /// @param key_ The key of the stored data
    /// @param value_ The value of the stored data
    /// @param index_ The index of the stored data
    function setBytes(bytes32 key_, bytes calldata value_, uint256 index_) external;
}
