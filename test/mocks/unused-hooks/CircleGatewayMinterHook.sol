// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../../src/hooks/BaseHook.sol";
import { HookSubTypes } from "../../../src/libraries/HookSubTypes.sol";

// Circle Gateway
interface IGatewayMinter {
    function gatewayMint(bytes memory attestationPayload, bytes memory signature) external;
}

/// @title CircleGatewayMinterHook
/// @author Superform Labs
/// @notice Hook for minting tokens from Circle Gateway Minter
/// @dev data has the following structure:
/// @notice         bytes attestationPayload = bytes(data[0:attestationPayloadLength]);
/// @notice         bytes signature = bytes(data[attestationPayloadLength:]);
/// @notice         The first 32 bytes contain the length of attestationPayload
contract CircleGatewayMinterHook is BaseHook {
    using BytesLib for bytes;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Circle Gateway Minter contract address
    address public constant GATEWAY_MINTER = 0x0022222ABE238Cc2C7Bb1f21003F0a260052475B;

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.BRIDGE) { }

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
        // Decode attestation payload and signature from data
        (bytes memory attestationPayload, bytes memory signature) = _decodeAttestationData(data);

        if (attestationPayload.length == 0 || signature.length == 0) {
            revert AMOUNT_NOT_VALID(); // Reusing error for invalid data
        }

        executions = new Execution[](1);
        
        // Call gatewayMint with attestation and signature
        executions[0] = Execution({
            target: GATEWAY_MINTER,
            value: 0,
            callData: abi.encodeCall(IGatewayMinter.gatewayMint, (attestationPayload, signature))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Decode attestation data from hook data
    /// @param data The hook data containing attestation payload and signature
    /// @return attestationPayload The attestation payload
    /// @return signature The signature
    function decodeAttestationData(bytes memory data) external pure returns (bytes memory attestationPayload, bytes memory signature) {
        return _decodeAttestationData(data);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    
    function _preExecute(address, address, bytes calldata) internal override {
        // No pre-execution logic needed
    }

    function _postExecute(address, address, bytes calldata) internal override {
        // No post-execution logic needed for bridge operations
        // The minted amount is determined by the Circle Gateway attestation
    }

    /// @notice Internal function to decode attestation payload and signature from data
    /// @param data The encoded data containing both attestation payload and signature
    /// @return attestationPayload The decoded attestation payload
    /// @return signature The decoded signature
    function _decodeAttestationData(bytes memory data) internal pure returns (bytes memory attestationPayload, bytes memory signature) {
        if (data.length < 32) {
            revert("Invalid data length");
        }

        // First 32 bytes contain the length of attestationPayload
        uint256 attestationPayloadLength = BytesLib.toUint256(data, 0);
        
        if (data.length < 32 + attestationPayloadLength) {
            revert("Data too short for attestation payload");
        }

        // Extract attestation payload
        attestationPayload = BytesLib.slice(data, 32, attestationPayloadLength);
        
        // Extract signature (remaining bytes)
        uint256 signatureStart = 32 + attestationPayloadLength;
        uint256 signatureLength = data.length - signatureStart;
        signature = BytesLib.slice(data, signatureStart, signatureLength);
    }
}