// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { AttestationLib } from "evm-gateway/lib/AttestationLib.sol";
import { Attestation, AttestationSet } from "evm-gateway/lib/Attestations.sol";
import { TransferSpec } from "evm-gateway/lib/TransferSpec.sol";
import { TransferSpecLib } from "evm-gateway/lib/TransferSpecLib.sol";
import { AddressLib } from "evm-gateway/lib/AddressLib.sol";

/// @dev The live GatewayMinter surface the fork suites drive (admin + views), beyond IGatewayMinter.
interface IGatewayMinterLive {
    function owner() external view returns (address);
    function domain() external view returns (uint32);
    function denylister() external view returns (address);
    function denylist(address addr) external;
    function unDenylist(address addr) external;
    function addAttestationSigner(address signer) external;
    function isAttestationSigner(address signer) external view returns (bool);
    function isTransferSpecHashUsed(bytes32 hash) external view returns (bool);
    function tokenMintAuthority(address token) external view returns (address);
    function gatewayMint(bytes memory attestationPayload, bytes memory signature) external;
}

interface IFiatTokenBlacklist {
    function blacklister() external view returns (address);
    function blacklist(address account) external;
    function unBlacklist(address account) external;
}

/// @title GatewayAttestationHelpers
/// @notice Builds and signs Circle Gateway attestations exactly as the attestation service does (EIP-191 over
///         keccak256(payload), NOT EIP-712), against the REAL GatewayMinter proxy on a fork.
/// @dev Verified in specs/circle-gateway-destination-adapter/research/framework-docs.md §7b: owner prank →
///      addAttestationSigner → gatewayMint mints real USDC (the live minter holds a large FiatToken minter
///      allowance; no MasterMinter pranks needed).
abstract contract GatewayAttestationHelpers is Test {
    using MessageHashUtils for bytes32;

    address internal constant GATEWAY_WALLET = 0x77777777Dcc4d5A8B6E418Fd04D8997ef11000eE;
    address internal constant GATEWAY_MINTER = 0x2222222d7164433c4C09B0b0D809a9b52C04C205;
    address internal constant USDC_ETH = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    uint32 internal constant DOMAIN_ETH = 0;
    uint32 internal constant DOMAIN_BASE = 6;
    uint256 internal constant GATEWAY_SIGNER_PK = 0xC1AC1E;

    uint256 private saltNonce;

    function _enrollSigner() internal {
        address signer = vm.addr(GATEWAY_SIGNER_PK);
        IGatewayMinterLive m = IGatewayMinterLive(GATEWAY_MINTER);
        if (!m.isAttestationSigner(signer)) {
            vm.prank(m.owner());
            m.addAttestationSigner(signer);
        }
    }

    /// @dev A TransferSpec funded from the OTHER mainnet domain (so the same-domain token-equality rule is moot).
    function _gwSpec(
        address recipient,
        address caller,
        address dstToken,
        address depositor,
        uint256 value,
        bytes memory hookData
    )
        internal
        returns (TransferSpec memory)
    {
        uint32 dst = IGatewayMinterLive(GATEWAY_MINTER).domain();
        (uint32 src, address srcToken) = dst == DOMAIN_BASE ? (DOMAIN_ETH, USDC_ETH) : (DOMAIN_BASE, USDC_BASE);
        return TransferSpec({
            version: 1,
            sourceDomain: src,
            destinationDomain: dst,
            sourceContract: AddressLib._addressToBytes32(GATEWAY_WALLET),
            destinationContract: AddressLib._addressToBytes32(GATEWAY_MINTER),
            sourceToken: AddressLib._addressToBytes32(srcToken),
            destinationToken: AddressLib._addressToBytes32(dstToken),
            sourceDepositor: AddressLib._addressToBytes32(depositor),
            destinationRecipient: AddressLib._addressToBytes32(recipient),
            sourceSigner: AddressLib._addressToBytes32(depositor),
            destinationCaller: AddressLib._addressToBytes32(caller),
            value: value,
            salt: keccak256(abi.encode("superform-gateway-test", ++saltNonce)),
            hookData: hookData
        });
    }

    function _gwEncode(TransferSpec memory s, uint256 maxBlockHeight) internal pure returns (bytes memory) {
        return AttestationLib.encodeAttestation(Attestation({ maxBlockHeight: maxBlockHeight, spec: s }));
    }

    function _gwEncode(TransferSpec memory s) internal view returns (bytes memory) {
        return _gwEncode(s, block.number + 100);
    }

    function _gwEncodeSet(TransferSpec[] memory specs) internal view returns (bytes memory) {
        Attestation[] memory atts = new Attestation[](specs.length);
        for (uint256 i; i < specs.length; ++i) {
            atts[i] = Attestation({ maxBlockHeight: block.number + 100, spec: specs[i] });
        }
        return AttestationLib.encodeAttestationSet(AttestationSet({ attestations: atts }));
    }

    /// @dev Circle-style attestation signature: EIP-191 personal_sign over keccak256(payload).
    function _gwSign(bytes memory payload) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(GATEWAY_SIGNER_PK, keccak256(payload).toEthSignedMessageHash());
        return abi.encodePacked(r, s, v);
    }

    function _gwSignWith(bytes memory payload, uint256 pk) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, keccak256(payload).toEthSignedMessageHash());
        return abi.encodePacked(r, s, v);
    }

    function _gwHash(TransferSpec memory s) internal pure returns (bytes32) {
        return keccak256(TransferSpecLib.encodeTransferSpec(s));
    }
}
