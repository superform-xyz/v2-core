// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../../../hooks/BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

// Circle Gateway
import { TransferSpecLib } from "../../../../lib/evm-gateway-contracts/src/lib/TransferSpecLib.sol";
import { AttestationLib, Cursor } from "../../../../lib/evm-gateway-contracts/src/lib/AttestationLib.sol";
import { AddressLib } from "../../../../lib/evm-gateway-contracts/src/lib/AddressLib.sol";

interface IGatewayMinter {
    function gatewayMint(bytes memory attestationPayload, bytes memory signature) external;
}

/// @title CircleGatewayMinterHook
/// @author Superform Labs
/// @notice Hook for minting tokens from Circle Gateway Minter
/// @dev data has the following structure:
/// @notice         uint256 attestationPayloadLength = BytesLib.toUint256(data, 0);
/// @notice         bytes attestationPayload = BytesLib.slice(data, 32, attestationPayloadLength);
/// @notice         uint256 signatureLength = BytesLib.toUint256(data, 32 + attestationPayloadLength);
/// @notice         bytes signature = BytesLib.slice(data, 64 + attestationPayloadLength, signatureLength);
contract CircleGatewayMinterHook is BaseHook {
    using TransferSpecLib for bytes29;
    using AttestationLib for bytes29;
    using AttestationLib for Cursor;
    using BytesLib for bytes;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Circle Gateway Minter contract address
    address public immutable GATEWAY_MINTER;

    /// @notice Error for multiple destination token addresses
    error DESTINATION_TOKENS_DIFFER();

    /// @notice Error for invalid destination caller
    error INVALID_DESTINATION_CALLER();

    /// @notice Error for zero token address
    error TOKEN_ADDRESS_INVALID();

    /// @notice Error for invalid data length
    error INVALID_DATA_LENGTH();

    constructor(address gatewayMinterAddress) BaseHook(HookType.NONACCOUNTING, HookSubTypes.BRIDGE) {
        if (gatewayMinterAddress == address(0)) revert ADDRESS_NOT_VALID();
        GATEWAY_MINTER = gatewayMinterAddress;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        // Decode attestation payload and signature from data
        (bytes memory attestationPayload, bytes memory signature) = _decodeAttestationData(data);

        if (attestationPayload.length == 0) {
            revert INVALID_DATA_LENGTH();
        }

        // Validate destination caller
        _validateDestinationCaller(data, account);

        executions = new Execution[](1);

        // Call gatewayMint with attestation and signature
        executions[0] = Execution({
            target: GATEWAY_MINTER,
            value: 0,
            callData: abi.encodeCall(IGatewayMinter.gatewayMint, (attestationPayload, signature))
        });
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        // Extract token address from attestation payload
        address token = _extractTokenFromAttestation(data);
        return abi.encodePacked(token);
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Decode attestation data from hook data
    /// @param data The hook data containing attestation payload and signature
    /// @return attestationPayload The attestation payload
    /// @return signature The signature
    function decodeAttestationData(bytes memory data)
        external
        pure
        returns (bytes memory attestationPayload, bytes memory signature)
    {
        return _decodeAttestationData(data);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    function _preExecute(address, address account, bytes calldata data) internal override {
        // Extract token address from attestation payload
        address token = _extractTokenFromAttestation(data);

        // Store the token address for later use
        asset = token;

        // Record initial balance before minting
        uint256 initialBalance = IERC20(token).balanceOf(account);
        _setOutAmount(initialBalance, account);
    }

    function _postExecute(address, address account, bytes calldata) internal override {
        // Get final balance after minting
        uint256 finalBalance = IERC20(asset).balanceOf(account);

        // Calculate the difference (minted amount)
        uint256 initialBalance = getOutAmount(account);
        uint256 mintedAmount = finalBalance - initialBalance;

        // Update outAmount to reflect the minted amount
        _setOutAmount(mintedAmount, account);
    }

    /// @notice Internal function to decode attestation payload and signature from data
    /// @param data The encoded data containing both attestation payload and signature
    /// @return attestationPayload The decoded attestation payload
    /// @return signature The decoded signature
    function _decodeAttestationData(bytes memory data)
        internal
        pure
        returns (bytes memory attestationPayload, bytes memory signature)
    {
        if (data.length < 64) {
            revert INVALID_DATA_LENGTH();
        }

        uint256 offset = 0;

        // First 32 bytes contain the length of attestationPayload
        uint256 attestationPayloadLength = BytesLib.toUint256(data, offset);
        offset += 32;

        // Validate there's sufficient data for the attestation payload and signature length
        if (data.length < offset + attestationPayloadLength + 32) {
            revert INVALID_DATA_LENGTH();
        }

        // Extract attestation payload
        attestationPayload = BytesLib.slice(data, offset, attestationPayloadLength);
        offset += attestationPayloadLength;

        // Next 32 bytes contain the length of signature
        uint256 signatureLength = BytesLib.toUint256(data, offset);
        offset += 32;

        // Validate there's sufficient data for the signature
        if (data.length < offset + signatureLength) {
            revert INVALID_DATA_LENGTH();
        }

        // Validate minimum signature length (ECDSA signatures should be at least 65 bytes)
        if (signatureLength < 65) {
            revert INVALID_DATA_LENGTH();
        }

        // Extract signature
        signature = BytesLib.slice(data, offset, signatureLength);
    }

    /// @notice Extract token address from the attestation payload
    /// @param data The hook data containing attestation payload and signature
    /// @return token The destination token address from the attestation
    function _extractTokenFromAttestation(bytes memory data) internal pure returns (address token) {
        // Decode attestation payload from data
        (bytes memory attestationPayload,) = _decodeAttestationData(data);

        // Validate and get cursor for iteration
        Cursor memory cursor = AttestationLib.cursor(attestationPayload);

        // Ensure there is at least one attestation
        if (cursor.numElements == 0) {
            revert INVALID_DATA_LENGTH();
        }

        bytes29 attestation;
        address destinationToken;
        while (!cursor.done) {
            attestation = cursor.next();

            // Extract and validate the `TransferSpec`
            bytes29 spec = attestation.getTransferSpec();
            destinationToken = AddressLib._bytes32ToAddress(spec.getDestinationToken());

            if (destinationToken == address(0)) {
                    revert TOKEN_ADDRESS_INVALID();
                }

            if (token != address(0)) {
                if (token != destinationToken) {
                    revert DESTINATION_TOKENS_DIFFER();
                }
            }

            token = destinationToken;
        }
    }

    function _validateDestinationCaller(bytes memory data, address account) internal pure {
        // Decode attestation payload from data
        (bytes memory attestationPayload,) = _decodeAttestationData(data);

        // Validate the attestation(s) and get an iteration cursor
        Cursor memory cursor = AttestationLib.cursor(attestationPayload);

        // Ensure there is at least one attestation
        if (cursor.numElements == 0) {
            revert INVALID_DATA_LENGTH();
        }

        // Iterate over the attestations, validating and processing each one
        bytes29 attestation;
        while (!cursor.done) {
            attestation = cursor.next();

            // Extract and validate the `TransferSpec`
            bytes29 spec = attestation.getTransferSpec();

            // Ensure the caller is the specified destination caller
            address destinationCaller = AddressLib._bytes32ToAddress(spec.getDestinationCaller());

            if (destinationCaller != address(0)) {
                if (destinationCaller != account) {
                    revert INVALID_DESTINATION_CALLER();
                }
            }
        }
    }
}
