// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../../src/hooks/BaseHook.sol";
import { HookSubTypes } from "../../../src/libraries/HookSubTypes.sol";
import {
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware,
    ISuperHookInspector
} from "../../../src/interfaces/ISuperHook.sol";

/// @title MultiCallHook
/// @author Superform Labs
/// @notice Hook for executing multiple calls in a single transaction
/// @dev data has the following structure
/// @notice         bytes32 placeholder = bytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         uint256 arraysLength = BytesLib.toUint256(data, 32);
/// @notice         address[] targets = BytesLib.slice(data, 64, arraysLength * 20);
/// @notice         uint256[] calldataLengths = BytesLib.slice(data, 64 + arraysLength * 20, arraysLength * 32);
/// @notice         bytes[] calldata = remaining bytes after lengths, concatenated
contract MultiCallHook is BaseHook, ISuperHookInflowOutflow, ISuperHookOutflow, ISuperHookContextAware {
    using BytesLib for bytes;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_LENGTH();
    error LENGTH_MISMATCH();
    error INVALID_ENCODING();
    error CALL_FAILED(uint256 index);

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct MultiCallParams {
        uint256 arraysLength;
        address[] targets;
        bytes[] calldatas;
    }

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.MISC) { }

    /*//////////////////////////////////////////////////////////////
                              VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address,
        address,
        bytes calldata data
    )
        internal
        pure
        override
        returns (Execution[] memory executions)
    {
        MultiCallParams memory params = _decodeMultiCallParams(data);

        if (params.targets.length != params.calldatas.length) revert LENGTH_MISMATCH();
        if (params.targets.length == 0) revert INVALID_LENGTH();

        executions = new Execution[](params.targets.length);
        
        for (uint256 i = 0; i < params.targets.length; i++) {
            executions[i] = Execution({
                target: params.targets[i],
                value: 0,
                callData: params.calldatas[i]
            });
        }
    }

    /*//////////////////////////////////////////////////////////////
                              EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmount(bytes memory) external pure returns (uint256) {
        return 0;
    }

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory) external pure returns (bool) {
        return false;
    }

    /// @inheritdoc ISuperHookOutflow
    function replaceCalldataAmount(bytes memory data, uint256) external pure returns (bytes memory) {
        return data;
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        MultiCallParams memory params = _decodeMultiCallParams(data);
        
        bytes memory addressData = "";
        for (uint256 i = 0; i < params.targets.length; i++) {
            addressData = bytes.concat(addressData, bytes20(params.targets[i]));
        }
        
        return addressData;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata) internal override {
        _setOutAmount(0, account);
    }

    function _postExecute(address, address account, bytes calldata) internal override {
        _setOutAmount(0, account);
    }

    function _decodeMultiCallParams(bytes calldata data) internal pure returns (MultiCallParams memory params) {
        if (data.length < 64) revert INVALID_ENCODING();

        // Skip placeholder (first 32 bytes)
        // Decode arrays length
        params.arraysLength = BytesLib.toUint256(data, 32);
        if (params.arraysLength == 0) revert INVALID_LENGTH();

        uint256 cursor = 64;

        // Decode targets
        params.targets = new address[](params.arraysLength);
        for (uint256 i = 0; i < params.arraysLength; i++) {
            if (cursor + 20 > data.length) revert INVALID_ENCODING();
            params.targets[i] = BytesLib.toAddress(data, cursor);
            if (params.targets[i] == address(0)) revert ADDRESS_NOT_VALID();
            cursor += 20;
        }

        // Decode calldata lengths
        uint256[] memory calldataLengths = new uint256[](params.arraysLength);
        for (uint256 i = 0; i < params.arraysLength; i++) {
            if (cursor + 32 > data.length) revert INVALID_ENCODING();
            calldataLengths[i] = BytesLib.toUint256(data, cursor);
            cursor += 32;
        }

        // Decode calldata
        params.calldatas = new bytes[](params.arraysLength);
        for (uint256 i = 0; i < params.arraysLength; i++) {
            if (cursor + calldataLengths[i] > data.length) revert INVALID_ENCODING();
            params.calldatas[i] = BytesLib.slice(data, cursor, calldataLengths[i]);
            cursor += calldataLengths[i];
        }

        // Sanity check: cursor should equal data.length
        if (cursor != data.length) revert INVALID_ENCODING();
    }
}