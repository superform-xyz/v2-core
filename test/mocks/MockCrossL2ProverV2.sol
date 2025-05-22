// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { IVaultBank } from "src/periphery/interfaces/IVaultBank.sol";
import { BytesLib } from "src/vendor/BytesLib.sol";

/// @notice Mock implementation of CrossL2ProverV2 for testing
contract MockCrossL2ProverV2 {
    using BytesLib for bytes;

    uint32 private _chainId;
    address private _emittingContract;
    bytes private _topics;
    bytes private _unindexedData;

    function setValidateEventReturn(
        uint32 chainId_,
        address emittingContract_,
        bytes memory topics_,
        bytes memory unindexedData_
    ) external {
        _chainId = chainId_;
        _emittingContract = emittingContract_;
        _topics = topics_;
        _unindexedData = unindexedData_;
    }
    
    function setEmittingContract(address emittingContract_) external {
        _emittingContract = emittingContract_;
    }

    function validateEvent(bytes calldata /*proof*/)
        external
        view
        returns (uint32 chainId, address emittingContract, bytes memory topics, bytes memory unindexedData)
    {
        return (_chainId, _emittingContract, _topics, _unindexedData);
    }

    function inspectLogIdentifier(bytes calldata /*proof*/)
        external
        pure
        returns (uint32 srcChain, uint64 blockNumber, uint16 receiptIndex, uint8 logIndex)
    {
        return (0, 0, 0, 0);
    }

    function mockSuperpositionsBurnedEvent(
        address account,
        address token,
        uint256 amount,
        uint64 targetChainId,
        uint256 nonce,
        uint32 chainId_
    ) external {
        // Set the chain ID first
        _chainId = chainId_;
        
        // Create event topics
        bytes memory topics = new bytes(128); // 4 topics * 32 bytes
        bytes32 eventSelector = IVaultBank.SuperpositionsBurned.selector;
        bytes32 encodedAccount = keccak256(abi.encodePacked(account));
        bytes32 encodedToken = keccak256(abi.encodePacked(token));

        // Write to bytes at correct offsets
        assembly {
            mstore(add(topics, 32), eventSelector) // First 32 bytes
            mstore(add(topics, 64), encodedAccount) // Next 32 bytes
            mstore(add(topics, 128), encodedToken) // Next 32 bytes
        }

        // Create event data
        bytes memory data = abi.encode(amount, targetChainId, nonce);

        // We need to pass the vaultBank address explicitly through setEmittingContract
        
        // Set the return values
        _topics = topics;
        _unindexedData = data;
    }
    
    /// @notice Mock implementation of inspectPolymerState - returns dummy values
    /// @dev This implementation is required to satisfy the ICrossL2ProverV2 interface
    function inspectPolymerState(bytes calldata /*proof*/)
        external
        view
        returns (bytes32 stateRoot, uint64 height, bytes memory signature)
    {
        // Return dummy values for testing purposes
        return (
            bytes32(uint256(0x123456)), // dummy state root
            uint64(block.number),        // current block as height
            new bytes(65)                // empty signature of standard length
        );
    }
}
