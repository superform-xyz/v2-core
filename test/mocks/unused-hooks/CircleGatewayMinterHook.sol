// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../../../src/hooks/BaseHook.sol";
import { HookSubTypes } from "../../../src/libraries/HookSubTypes.sol";
import { ISuperHookInspector } from "../../../src/interfaces/ISuperHook.sol";

// Circle Gateway
import { AttestationLib } from "../../../lib/evm-gateway-contracts/src/lib/AttestationLib.sol";
import { TransferSpecLib } from "../../../lib/evm-gateway-contracts/src/lib/TransferSpecLib.sol";
import { AddressLib } from "../../../lib/evm-gateway-contracts/src/lib/AddressLib.sol";

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
    address public immutable GATEWAY_MINTER;

    /// @notice Error for token address not being valid
    error TOKEN_ADDRESS_INVALID();

    /// @notice Error for invalid data length
    error INVALID_DATA_LENGTH();

    /// @notice Error for attestation payload being too short
    error ATTESTATION_PAYLOAD_TOO_SHORT();

    constructor(address gatewayMinterAddress) BaseHook(HookType.NONACCOUNTING, HookSubTypes.BRIDGE) {
        GATEWAY_MINTER = gatewayMinterAddress;
    }

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
        view
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
        if (token == address(0)) revert TOKEN_ADDRESS_INVALID();

        // Store the token address for later use
        asset = token;

        // Record initial balance before minting
        uint256 initialBalance = IERC20(token).balanceOf(account);
        _setOutAmount(initialBalance, account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        // Extract token address from attestation payload
        address token = _extractTokenFromAttestation(data);

        // Get final balance after minting
        uint256 finalBalance = IERC20(token).balanceOf(account);

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
        if (data.length < 32) {
            revert INVALID_DATA_LENGTH();
        }

        // First 32 bytes contain the length of attestationPayload
        uint256 attestationPayloadLength = BytesLib.toUint256(data, 0);

        if (data.length < 32 + attestationPayloadLength) {
            revert ATTESTATION_PAYLOAD_TOO_SHORT();
        }

        // Extract attestation payload
        attestationPayload = BytesLib.slice(data, 32, attestationPayloadLength);

        // Extract signature (remaining bytes)
        uint256 signatureStart = 32 + attestationPayloadLength;
        uint256 signatureLength = data.length - signatureStart;
        signature = BytesLib.slice(data, signatureStart, signatureLength);
    }

    /// @notice Extract token address from the attestation payload
    /// @param data The hook data containing attestation payload and signature
    /// @return token The destination token address from the attestation
    function _extractTokenFromAttestation(bytes memory data) internal pure returns (address token) {
        // Decode attestation payload from data
        (bytes memory attestationPayload,) = _decodeAttestationData(data);

        // Validate and get attestation view
        bytes29 attestationView = AttestationLib._validate(attestationPayload);

        // Get the transfer spec from the attestation
        bytes29 transferSpec = AttestationLib.getTransferSpec(attestationView);

        // Extract the destination token from the transfer spec
        bytes32 destinationToken = TransferSpecLib.getDestinationToken(transferSpec);

        // Convert bytes32 to address
        token = AddressLib._bytes32ToAddress(destinationToken);
    }
}
