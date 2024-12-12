// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Superform
import { ISharedStateWriter } from "src/interfaces/state/ISharedStateWriter.sol";
import { ISharedStateReader } from "src/interfaces/state/ISharedStateReader.sol";

contract SharedState is ISharedStateWriter, ISharedStateReader {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    /// @dev Bool storage data
    mapping(address account => uint256) public lastBoolValuesIndex;
    mapping(bytes32 key => mapping(address account => mapping(uint256 index => bool value))) public boolValues;

    /// @dev Int storage data
    mapping(address account => uint256) public lastIntValuesIndex;
    mapping(bytes32 key => mapping(address account => mapping(uint256 index => int256 value))) public intValues;

    /// @dev Bytes storage data
    mapping(address account => uint256) public lastBytesValuesIndex;
    mapping(bytes32 key => mapping(address account => mapping(uint256 index => bytes value))) public byteValues;

    /// @dev Bytes32 storage data
    mapping(address account => uint256) public lastBytes32ValuesIndex;
    mapping(bytes32 key => mapping(address account => mapping(uint256 index => bytes32 value))) public hashValues;

    /// @dev Uint storage data
    mapping(address account => uint256) public lastUintValuesIndex;
    mapping(bytes32 key => mapping(address account => mapping(uint256 index => uint256 value))) public uintValues;

    /// @dev String storage data
    mapping(address account => uint256) public lastStringValuesIndex;
    mapping(bytes32 key => mapping(address account => mapping(uint256 index => string value))) public stringValues;

    /// @dev Address storage data
    mapping(address account => uint256) public lastAddressValuesIndex;
    mapping(bytes32 key => mapping(address account => mapping(uint256 index => address value))) public addressValues;

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISharedStateReader
    function getAddress(bytes32 key_, address account_, uint256 index_) external view returns (address) {
        return addressValues[key_][account_][index_];
    }
    /// @inheritdoc ISharedStateReader

    function getAddress(bytes32 key_, address account_) external view returns (address) {
        return addressValues[key_][account_][lastAddressValuesIndex[account_]];
    }

    /// @inheritdoc ISharedStateReader
    function getUint(bytes32 key_, address account_, uint256 index_) external view returns (uint256) {
        return uintValues[key_][account_][index_];
    }
    /// @inheritdoc ISharedStateReader

    function getUint(bytes32 key_, address account_) external view returns (uint256) {
        return uintValues[key_][account_][lastUintValuesIndex[account_]];
    }

    /// @inheritdoc ISharedStateReader
    function getString(bytes32 key_, address account_, uint256 index_) external view returns (string memory) {
        return stringValues[key_][account_][index_];
    }
    /// @inheritdoc ISharedStateReader

    function getString(bytes32 key_, address account_) external view returns (string memory) {
        return stringValues[key_][account_][lastStringValuesIndex[account_]];
    }

    /// @inheritdoc ISharedStateReader
    function getBytes(bytes32 key_, address account_, uint256 index_) external view returns (bytes memory) {
        return byteValues[key_][account_][index_];
    }
    /// @inheritdoc ISharedStateReader

    function getBytes(bytes32 key_, address account_) external view returns (bytes memory) {
        return byteValues[key_][account_][lastBytesValuesIndex[account_]];
    }

    /// @inheritdoc ISharedStateReader
    function getBool(bytes32 key_, address account_, uint256 index_) external view returns (bool) {
        return boolValues[key_][account_][index_];
    }
    /// @inheritdoc ISharedStateReader

    function getBool(bytes32 key_, address account_) external view returns (bool) {
        return boolValues[key_][account_][lastBoolValuesIndex[account_]];
    }

    /// @inheritdoc ISharedStateReader
    function getInt(bytes32 key_, address account_, uint256 index_) external view returns (int256) {
        return intValues[key_][account_][index_];
    }
    /// @inheritdoc ISharedStateReader

    function getInt(bytes32 key_, address account_) external view returns (int256) {
        return intValues[key_][account_][lastIntValuesIndex[account_]];
    }

    /// @inheritdoc ISharedStateReader
    function getBytes32(bytes32 key_, address account_, uint256 index_) external view returns (bytes32) {
        return hashValues[key_][account_][index_];
    }
    /// @inheritdoc ISharedStateReader

    function getBytes32(bytes32 key_, address account_) external view returns (bytes32) {
        return hashValues[key_][account_][lastBytes32ValuesIndex[account_]];
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISharedStateWriter
    function setAddress(bytes32 key_, address value_) external {
        lastAddressValuesIndex[msg.sender]++;
        _setAddress(key_, value_, lastAddressValuesIndex[msg.sender]);
    }
    /// @inheritdoc ISharedStateWriter

    function setAddress(bytes32 key_, address value_, uint256 index_) external {
        _setAddress(key_, value_, index_);
    }

    /// @inheritdoc ISharedStateWriter
    function setUint(bytes32 key_, uint256 value_) external {
        lastUintValuesIndex[msg.sender]++;
        _setUint(key_, value_, lastUintValuesIndex[msg.sender]);
    }
    /// @inheritdoc ISharedStateWriter

    function setUint(bytes32 key_, uint256 value_, uint256 index_) external {
        _setUint(key_, value_, index_);
    }

    /// @inheritdoc ISharedStateWriter
    function setString(bytes32 key_, string calldata value_) external {
        lastStringValuesIndex[msg.sender]++;
        _setString(key_, value_, lastStringValuesIndex[msg.sender]);
    }
    /// @inheritdoc ISharedStateWriter

    function setString(bytes32 key_, string calldata value_, uint256 index_) external {
        _setString(key_, value_, index_);
    }

    /// @inheritdoc ISharedStateWriter
    function setBytes(bytes32 key_, bytes calldata value_) external {
        lastBytesValuesIndex[msg.sender]++;
        _setBytes(key_, value_, lastBytesValuesIndex[msg.sender]);
    }
    /// @inheritdoc ISharedStateWriter

    function setBytes(bytes32 key_, bytes calldata value_, uint256 index_) external {
        _setBytes(key_, value_, index_);
    }

    /// @inheritdoc ISharedStateWriter
    function setBool(bytes32 key_, bool value_) external {
        lastBoolValuesIndex[msg.sender]++;
        _setBool(key_, value_, lastBoolValuesIndex[msg.sender]);
    }
    /// @inheritdoc ISharedStateWriter

    function setBool(bytes32 key_, bool value_, uint256 index_) external {
        _setBool(key_, value_, index_);
    }

    /// @inheritdoc ISharedStateWriter
    function setInt(bytes32 key_, int256 value_) external {
        lastIntValuesIndex[msg.sender]++;
        _setInt(key_, value_, lastIntValuesIndex[msg.sender]);
    }
    /// @inheritdoc ISharedStateWriter

    function setInt(bytes32 key_, int256 value_, uint256 index_) external {
        _setInt(key_, value_, index_);
    }

    /// @inheritdoc ISharedStateWriter
    function setBytes32(bytes32 key_, bytes32 value_) external {
        lastBytes32ValuesIndex[msg.sender]++;
        _setBytes32(key_, value_, lastBytes32ValuesIndex[msg.sender]);
    }
    /// @inheritdoc ISharedStateWriter

    function setBytes32(bytes32 key_, bytes32 value_, uint256 index_) external {
        _setBytes32(key_, value_, index_);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _setAddress(bytes32 key_, address value_, uint256 index_) private {
        addressValues[key_][msg.sender][index_] = value_;
    }

    function _setUint(bytes32 key_, uint256 value_, uint256 index_) private {
        uintValues[key_][msg.sender][index_] =value_;
    }

    function _setString(bytes32 key_, string calldata value_, uint256 index_) private {
        stringValues[key_][msg.sender][index_] = value_;
    }

    function _setBytes(bytes32 key_, bytes calldata value_, uint256 index_) private {
        byteValues[key_][msg.sender][index_] = value_;
    }

    function _setBool(bytes32 key_, bool value_, uint256 index_) private {
        boolValues[key_][msg.sender][index_] = value_;
    }

    function _setInt(bytes32 key_, int256 value_, uint256 index_) private {
        intValues[key_][msg.sender][index_] = value_;
    }

    function _setBytes32(bytes32 key_, bytes32 value_, uint256 index_) private {
        hashValues[key_][msg.sender][index_] = value_;
    }
}
