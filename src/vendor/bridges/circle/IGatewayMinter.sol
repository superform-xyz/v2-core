// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IGatewayMinter
/// @author Superform Labs
/// @notice Minimal interface for Circle Gateway's GatewayMinter (mint side of the unified USDC balance)
/// @dev See https://developers.circle.com/gateway and circlefin/evm-gateway-contracts `src/GatewayMinter.sol` /
///      `src/modules/minter/Mints.sol`. Only the surface the CircleGatewayAdapter and its deploy script need is
///      declared, so the adapter's bytecode never depends on the vendored upgradeable tree. The deployed proxy
///      (0x2222222d7164433c4C09B0b0D809a9b52C04C205 on every chain) is UUPS and owner-upgradeable.
interface IGatewayMinter {
    /// @notice Mints funds for one attestation or an attestation set signed by a Circle attestation signer
    /// @dev Reverts on: pause, denylisted caller/recipient, bad signer, structural errors, expiry (`maxBlockHeight`),
    ///      wrong domain/contract, unsupported token, replay (`TransferSpecHashUsed`). Marks each TransferSpec
    ///      hash used and mints exactly `value` to `destinationRecipient`; `hookData` is ignored.
    /// @param attestationPayload The raw Attestation / AttestationSet bytes exactly as attested
    /// @param signature EIP-191 signature over keccak256(attestationPayload) by an attestation signer
    function gatewayMint(bytes calldata attestationPayload, bytes calldata signature) external;

    /// @notice Circle Gateway domain id of this chain (Ethereum is 0)
    /// @return domainId The domain id
    function domain() external view returns (uint32 domainId);

    /// @notice Whether `token` may be minted by this minter
    /// @param token The token to query
    /// @return supported True if the minter mints `token`
    function isTokenSupported(address token) external view returns (bool supported);

    /// @notice Whether the TransferSpec with this hash has already been minted
    /// @dev Written only inside `gatewayMint`, after the attestation signature was verified — the adapter's
    ///      witness that Circle signed and minted a byte-identical spec.
    /// @param transferSpecHash keccak256 of the encoded TransferSpec (== `AttestationUsed.transferSpecHash`)
    /// @return used True once minted
    function isTransferSpecHashUsed(bytes32 transferSpecHash) external view returns (bool used);
}
