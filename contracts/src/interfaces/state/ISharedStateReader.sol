// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface ISharedStateReader {
    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get address data
    /// @param key_ The key of the stored data
    /// @param account_ The account of the stored data
    function getAddress(bytes32 key_, address account_) external view returns (address);
    /// @notice Get address data
    /// @param key_ The key of the stored data
    /// @param account_ The account of the stored data
    /// @param index_ The index of the stored data
    /// @return The address data
    function getAddress(bytes32 key_, address account_, uint256 index_) external view returns (address);

    /// @notice Get uint data
    /// @param key_ The key of the stored data
    /// @param account_ The account of the stored data
    /// @return The uint data
    function getUint(bytes32 key_, address account_) external view returns (uint256);
    /// @notice Get uint data
    /// @param key_ The key of the stored data
    /// @param account_ The account of the stored data
    /// @param index_ The index of the stored data
    /// @return The uint data
    function getUint(bytes32 key_, address account_, uint256 index_) external view returns (uint256);

    /// @notice Get string data
    /// @param key_ The key of the stored data
    /// @param account_ The account of the stored data
    /// @return The string data
    function getString(bytes32 key_, address account_) external view returns (string memory);
    /// @notice Get string data
    /// @param key_ The key of the stored data
    /// @param account_ The account of the stored data
    /// @param index_ The index of the stored data
    /// @return The string data
    function getString(bytes32 key_, address account_, uint256 index_) external view returns (string memory);

    /// @notice Get bytes data
    /// @param key_ The key of the stored data
    /// @param account_ The account of the stored data
    /// @return The bytes data
    function getBytes(bytes32 key_, address account_) external view returns (bytes memory);
    /// @notice Get bytes data
    /// @param key_ The key of the stored data
    /// @param account_ The account of the stored data
    /// @param index_ The index of the stored data
    /// @return The bytes data
    function getBytes(bytes32 key_, address account_, uint256 index_) external view returns (bytes memory);

    /// @notice Get bool data
    /// @param key_ The key of the stored data
    /// @param account_ The account of the stored data
    /// @return The bool data
    function getBool(bytes32 key_, address account_) external view returns (bool);
    /// @notice Get bool data
    /// @param key_ The key of the stored data
    /// @param account_ The account of the stored data
    /// @param index_ The index of the stored data
    /// @return The bool data
    function getBool(bytes32 key_, address account_, uint256 index_) external view returns (bool);

    /// @notice Get int data
    /// @param key_ The key of the stored data
    /// @param account_ The account of the stored data
    /// @return The int data
    function getInt(bytes32 key_, address account_) external view returns (int256);
    /// @notice Get int data
    /// @param key_ The key of the stored data
    /// @param account_ The account of the stored data
    /// @param index_ The index of the stored data
    /// @return The int data
    function getInt(bytes32 key_, address account_, uint256 index_) external view returns (int256);

    /// @notice Get bytes32 data
    /// @param key_ The key of the stored data
    /// @param account_ The account of the stored data
    /// @return The bytes32 data
    function getBytes32(bytes32 key_, address account_) external view returns (bytes32);
    /// @notice Get bytes32 data
    /// @param key_ The key of the stored data
    /// @param account_ The account of the stored data
    /// @param index_ The index of the stored data
    /// @return The bytes32 data
    function getBytes32(bytes32 key_, address account_, uint256 index_) external view returns (bytes32);
}
