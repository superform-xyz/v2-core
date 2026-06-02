// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title ILZMultiCall
/// @notice Minimal interface for LayerZero's multicall contract
interface ILZMultiCall {
    struct Call {
        address target;
        uint256 value;
        bytes data;
    }

    function execute(Call[] calldata _calls, bytes32 _quoteId) external payable;
}
