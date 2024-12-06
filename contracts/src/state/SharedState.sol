// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Superform
import { ISharedStateWriter } from "src/interfaces/state/ISharedStateWriter.sol";
import { ISharedStateReader } from "src/interfaces/state/ISharedStateReader.sol";
import { ISharedStateOperations } from "src/interfaces/state/ISharedStateOperations.sol";

import { SuperformValueOperations, IntValue, UintValue } from "src/libraries/SuperformValueOperations.sol";

contract SharedState is ISharedStateWriter, ISharedStateReader, ISharedStateOperations {
    using SuperformValueOperations for IntValue;
    using SuperformValueOperations for UintValue;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    /// @dev Bool storage data
    mapping(address account => uint256) public lastBoolValuesIndex;
    mapping(bytes32 key => mapping(address account => mapping(uint256 index => bool value))) public boolValues;

    /// @dev Int storage data
    mapping(address account => uint256) public lastIntValuesIndex;
    mapping(bytes32 key => mapping(address account => mapping(uint256 index => IntValue value))) public intValues;

    /// @dev Bytes storage data
    mapping(address account => uint256) public lastByteValuesIndex;
    mapping(bytes32 key => mapping(address account => mapping(uint256 index => bytes value))) public byteValues;

    /// @dev Bytes32 storage data
    mapping(address account => uint256) public lastHashValuesIndex;
    mapping(bytes32 key => mapping(address account => mapping(uint256 index => bytes32 value))) public hashValues;

    /// @dev Uint storage data
    mapping(address account => uint256) public lastUintValuesIndex;
    mapping(bytes32 key => mapping(address account => mapping(uint256 index => UintValue value))) public uintValues;

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
        return UintValue.unwrap(uintValues[key_][account_][index_]);
    }
    /// @inheritdoc ISharedStateReader

    function getUint(bytes32 key_, address account_) external view returns (uint256) {
        return UintValue.unwrap(uintValues[key_][account_][lastUintValuesIndex[account_]]);
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
        return byteValues[key_][account_][lastByteValuesIndex[account_]];
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
        return IntValue.unwrap(intValues[key_][account_][index_]);
    }
    /// @inheritdoc ISharedStateReader

    function getInt(bytes32 key_, address account_) external view returns (int256) {
        return IntValue.unwrap(intValues[key_][account_][lastIntValuesIndex[account_]]);
    }

    /// @inheritdoc ISharedStateReader
    function getBytes32(bytes32 key_, address account_, uint256 index_) external view returns (bytes32) {
        return hashValues[key_][account_][index_];
    }
    /// @inheritdoc ISharedStateReader

    function getBytes32(bytes32 key_, address account_) external view returns (bytes32) {
        return hashValues[key_][account_][lastHashValuesIndex[account_]];
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
        lastByteValuesIndex[msg.sender]++;
        _setBytes(key_, value_, lastByteValuesIndex[msg.sender]);
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
        lastHashValuesIndex[msg.sender]++;
        _setBytes32(key_, value_, lastHashValuesIndex[msg.sender]);
    }
    /// @inheritdoc ISharedStateWriter

    function setBytes32(bytes32 key_, bytes32 value_, uint256 index_) external {
        _setBytes32(key_, value_, index_);
    }

    /// @inheritdoc ISharedStateOperations
    function addUint(bytes32 key_, uint256 index_, uint256 value_) external {
        UintValue currentValue = uintValues[key_][msg.sender][index_];
        uintValues[key_][msg.sender][index_] = currentValue.add(UintValue.wrap(value_));
    }
    /// @inheritdoc ISharedStateOperations

    function subUint(bytes32 key_, uint256 index_, uint256 value_) external {
        UintValue currentValue = uintValues[key_][msg.sender][index_];
        uintValues[key_][msg.sender][index_] = currentValue.sub(UintValue.wrap(value_));
    }
    /// @inheritdoc ISharedStateOperations

    function mulUint(bytes32 key_, uint256 index_, uint256 value_) external {
        UintValue currentValue = uintValues[key_][msg.sender][index_];
        uintValues[key_][msg.sender][index_] = currentValue.mul(UintValue.wrap(value_));
    }
    /// @inheritdoc ISharedStateOperations

    function divUint(bytes32 key_, uint256 index_, uint256 value_) external {
        UintValue currentValue = uintValues[key_][msg.sender][index_];
        uintValues[key_][msg.sender][index_] = currentValue.div(UintValue.wrap(value_));
    }

    /// @inheritdoc ISharedStateOperations
    function addInt(bytes32 key_, uint256 index_, int256 value_) external {
        IntValue currentValue = intValues[key_][msg.sender][index_];
        intValues[key_][msg.sender][index_] = currentValue.add(IntValue.wrap(value_));
    }
    /// @inheritdoc ISharedStateOperations

    function subInt(bytes32 key_, uint256 index_, int256 value_) external {
        IntValue currentValue = intValues[key_][msg.sender][index_];
        intValues[key_][msg.sender][index_] = currentValue.sub(IntValue.wrap(value_));
    }
    /// @inheritdoc ISharedStateOperations

    function mulInt(bytes32 key_, uint256 index_, int256 value_) external {
        IntValue currentValue = intValues[key_][msg.sender][index_];
        intValues[key_][msg.sender][index_] = currentValue.mul(IntValue.wrap(value_));
    }
    /// @inheritdoc ISharedStateOperations

    function divInt(bytes32 key_, uint256 index_, int256 value_) external {
        IntValue currentValue = intValues[key_][msg.sender][index_];
        intValues[key_][msg.sender][index_] = currentValue.div(IntValue.wrap(value_));
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _setAddress(bytes32 key_, address value_, uint256 index_) private {
        addressValues[key_][msg.sender][index_] = value_;
    }

    function _setUint(bytes32 key_, uint256 value_, uint256 index_) private {
        uintValues[key_][msg.sender][index_] = UintValue.wrap(value_);
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
        intValues[key_][msg.sender][index_] = IntValue.wrap(value_);
    }

    function _setBytes32(bytes32 key_, bytes32 value_, uint256 index_) private {
        hashValues[key_][msg.sender][index_] = value_;
    }
}
