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
/// @notice         uint256 attestationPayloadLength = BytesLib.toUint256(data, 0);
/// @notice         bytes attestationPayload = BytesLib.slice(data, 32, attestationPayloadLength);
/// @notice         uint256 signatureLength = BytesLib.toUint256(data, 32 + attestationPayloadLength);
/// @notice         bytes signature = BytesLib.slice(data, 64 + attestationPayloadLength, signatureLength);
contract CircleGatewayMinterHook is BaseHook {
    using BytesLib for bytes;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Circle Gateway Minter contract address
    address public immutable GATEWAY_MINTER;

    /// @notice Error for usdc address not being valid
    error TOKEN_ADDRESS_INVALID();

    /// @notice Error for invalid data length
    error INVALID_DATA_LENGTH();

    /// @notice Error for attestation payload being too short
    error LENGTH_MISMATCH();

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

        if (attestationPayload.length == 0) {
            revert INVALID_DATA_LENGTH();
        }

        if (signature.length == 0) {
            revert INVALID_DATA_LENGTH();
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
        // Extract usdc address from attestation payload
        address usdc = _extractTokenFromAttestation(data);
        return abi.encodePacked(usdc);
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
        // Extract usdc address from attestation payload
        address usdc = _extractTokenFromAttestation(data);
        if (usdc == address(0)) revert TOKEN_ADDRESS_INVALID();

        // Store the usdc address for later use
        asset = usdc;

        // Record initial balance before minting
        uint256 initialBalance = IERC20(usdc).balanceOf(account);
        _setOutAmount(initialBalance, account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        // Extract usdc address from attestation payload
        address usdc = _extractTokenFromAttestation(data);

        // Get final balance after minting
        uint256 finalBalance = IERC20(usdc).balanceOf(account);

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

    /// @notice Extract usdc address from the attestation payload
    /// @param data The hook data containing attestation payload and signature
    /// @return usdc The destination usdc address from the attestation
    function _extractTokenFromAttestation(bytes memory data) internal pure returns (address usdc) {
        // Decode attestation payload from data
        (bytes memory attestationPayload,) = _decodeAttestationData(data);

        // Validate and get attestation view
        bytes29 attestationView = AttestationLib._validate(attestationPayload);

        // Get the transfer spec from the attestation
        bytes29 transferSpec = AttestationLib.getTransferSpec(attestationView);

        // Extract the destination usdc from the transfer spec
        bytes32 usdcBytes32 = TransferSpecLib.getDestinationToken(transferSpec);

        // Convert bytes32 to address
        usdc = AddressLib._bytes32ToAddress(usdcBytes32);

        if (usdc == address(0)) revert TOKEN_ADDRESS_INVALID();
    }
}
