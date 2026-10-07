// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { WebAuthn } from "solady/utils/WebAuthn.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";
import { LibBytes } from "solady/utils/LibBytes.sol";

// Superform
import { ICoinbaseSmartWallet } from "../vendor/coinbase/ICoinbaseSmartWallet.sol";
import { ISuperValidator } from "../interfaces/ISuperValidator.sol";

/// @title ChainAgnosticCoinbaseSmartWalletValidation
/// @author Superform Labs
/// @notice Chain-agnostic signature validation for a Coinbase Smart Wallet ("Base Smart Wallet") owner.
/// @dev THE PROBLEM THIS SOLVES, measured rather than assumed. A Base Smart Wallet is a CONTRACT account
///      whose owners are passkeys — secp256r1 / WebAuthn public keys, not ECDSA keys — so there is no
///      secp256k1 key available to sign with and its signature is a `SignatureWrapper` carrying a WebAuthn
///      bundle (~300 bytes, which is the "600 character signature" originally reported).
///      Two things therefore had to change in `SuperValidatorBase`:
///      (1) `owner.code.length == 0` cannot be read as "owner is an EOA". A Base Smart Wallet address is
///          deterministic but has NO CODE on a chain until its first transaction there, so a counterfactual
///          wallet fell through to `ECDSA.recover`, which reverts on a ~300-byte signature;
///      (2) delegating to the wallet's own ERC-1271 cannot work for this protocol. Verified on-chain against
///          the live implementation (`0x000100abaad02f1cfC8Bbe32bD5a564817339E72`, reached through the
///          factory `0x0BA5ED0c6AA8c49038F819E587E2633c4A9F428a`): `eip712Domain()` returns
///          `name "Coinbase Smart Wallet"`, `version "1"`, **`chainId` = the executing chain** and
///          **`verifyingContract` = the wallet**. So `isValidSignature` → `replaySafeHash` binds a signature
///          to ONE chain and ONE wallet, which would destroy the single-signature-many-chains property that
///          is the entire point of `SuperValidator`'s merkle design.
/// @dev SO THIS LIBRARY DOES NOT DELEGATE. Exactly like `ChainAgnosticSafeSignatureValidation` — which exists
///      for the same reason, Safe's native ERC-1271 also being chain-bound — it reads the owner set off the
///      wallet and verifies the signature ITSELF against a FIXED domain with `FIXED_CHAIN_ID`, so one
///      signature authorises the same merkle root on every chain.
/// @dev P-256 verification is delegated to `solady/P256` via `solady/WebAuthn`, which tries the RIP-7212
///      precompile at `0x100` and falls back to a deployed Solidity verifier when a canary contract shows the
///      precompile is absent. Measured 2026-10-06: the precompile answers correctly on Ethereum, Base,
///      Optimism, Linea and Flare (valid → 1, corrupted → empty). On a chain with NEITHER the precompile NOR
///      the verifier, `P256` returns false rather than reverting — a liveness failure for passkey owners on
///      that chain, never a fail-open. Check both before enabling this path on a new chain.
/// @dev CONTRACT WITH THE CALLER: returns `false` — never reverts — when the target is not a Coinbase Smart
///      Wallet or the signature does not match, so the caller can fall through to its generic ERC-1271 path.
///      Same contract as the Safe library, but implemented differently and deliberately so: every probe here
///      is a LOW-LEVEL `staticcall` with explicit returndata validation, NOT `try`/`catch`.
///      `try ICoinbaseSmartWallet(w).nextOwnerIndex() returns (uint256)` does not satisfy the contract,
///      because the ABI decode of the return value happens in the CALLER's frame AFTER the try succeeds —
///      so a target that returns no data (any contract with a permissive fallback, which a Coinbase Smart
///      Wallet itself has: unknown selectors return `0x`) makes the decode revert where `catch` cannot see
///      it. `ChainAgnosticSafeSignatureValidation` has exactly that shape at its `getOwners()` probe; this
///      library must not repeat it, because a detector that reverts instead of returning `false` cannot be
///      used to route between account families at all.
/// @dev `isCoinbaseSmartWallet` is separated from `validateChainAgnosticPasskey` for the same routing reason:
///      the caller needs to know "is this family mine" independently of "did this signature verify", so that
///      an INVALID Coinbase signature is reported as invalid instead of falling through into a Safe probe
///      that would then revert against the Coinbase wallet's permissive fallback.
library ChainAgnosticCoinbaseSmartWalletValidation {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Chain-agnostic domain separator type hash
    /// @dev Identical layout to `ChainAgnosticSafeSignatureValidation`'s: a fixed domain, so the digest does
    ///      not move between chains.
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
    bytes32 private constant CHAIN_AGNOSTIC_DOMAIN_TYPEHASH =
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    /// @notice Fixed chain ID, so one signature is valid on every chain
    /// @dev The whole point of not delegating to the wallet's ERC-1271, which would pin the executing chain.
    uint256 private constant FIXED_CHAIN_ID = 1;

    /// @notice Domain name — distinct from the Safe library's "SuperformSafe" so the two account families can
    ///         never produce a colliding digest for the same root and wallet address.
    string private constant DOMAIN_NAME = "SuperformCoinbaseSmartWallet";
    string private constant DOMAIN_VERSION = "1.0.0";

    /// @notice `keccak256("CoinbaseSmartWalletMessage(bytes32 hash)")`
    /// @dev Deliberately NOT the wallet's own `CoinbaseSmartWalletMessage` typehash under its own domain —
    ///      that is the chain-bound construction this library replaces. The struct name is reused only so the
    ///      off-chain signer has a recognisable EIP-712 payload to display.
    bytes32 private constant MESSAGE_TYPEHASH = keccak256("CoinbaseSmartWalletMessage(bytes32 hash)");

    /// @notice Length of a P-256 public key owner entry: `abi.encode(x, y)`
    uint256 private constant PASSKEY_OWNER_LENGTH = 64;

    /// @notice Length of an address owner entry: a left-padded `abi.encode(address)`
    uint256 private constant ADDRESS_OWNER_LENGTH = 32;

    /// @notice Smallest well-formed `SignatureWrapper` blob: tuple offset + index + bytes offset + length
    /// @dev FOUR words, not three. See `_decodeWrapper` for why the leading word exists.
    uint256 private constant MIN_WRAPPER_LENGTH = 0x80;

    /*//////////////////////////////////////////////////////////////
                             EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Whether `wallet` presents the Coinbase Smart Wallet owner-set interface
    /// @dev The ROUTING question, answered without reverting and without trusting the answer for anything
    ///      except routing. A positive answer only means "ask this library about its signatures"; all key
    ///      material is still read from the wallet and verified cryptographically in
    ///      `validateChainAgnosticPasskey`.
    /// @param wallet The candidate account owner
    /// @return True when `nextOwnerIndex()` answers with a single word and at least one index is occupied
    function isCoinbaseSmartWallet(address wallet) internal view returns (bool) {
        (bool ok, uint256 indexBound) = _nextOwnerIndex(wallet);
        return ok && indexBound != 0;
    }

    /// @notice Validates `sigData.signature` against `wallet`'s owner set, chain-agnostically
    /// @dev ORDER OF CHECKS, and why: the cheap non-reverting probe first (is this even a Coinbase Smart
    ///      Wallet), then the owner lookup, then the cryptography. Every failure returns `false` so the
    ///      caller falls through rather than bricking an account whose owner is some other 1271 contract.
    /// @param wallet The account owner being validated — expected to be a Coinbase Smart Wallet
    /// @param sigData Signature data; only `merkleRoot` and `signature` are read here
    /// @param rawHash The protocol's own chain-agnostic message hash (namespace + merkle root)
    /// @return True when the signature is a valid owner signature over `rawHash`
    function validateChainAgnosticPasskey(
        address wallet,
        ISuperValidator.SignatureData memory sigData,
        bytes32 rawHash
    )
        internal
        view
        returns (bool)
    {
        // A Coinbase Smart Wallet must be DEPLOYED for its owner set to be readable. A counterfactual wallet
        // cannot be validated here and must not be mistaken for an EOA — see the caller's handling.
        // `_nextOwnerIndex` would also reject a codeless address (empty returndata), but checking here keeps
        // the counterfactual case explicit and skips the call.
        if (wallet.code.length == 0) return false;

        // Probe: not a Coinbase Smart Wallet -> fall through to generic ERC-1271.
        (bool probed, uint256 indexBound) = _nextOwnerIndex(wallet);
        if (!probed || indexBound == 0) return false;

        // The wrapper's `ownerIndex` is attacker-supplied calldata. It is never trusted: it only SELECTS
        // which registered owner to check, and the key material is then read from the wallet itself.
        (uint256 ownerIndex, bytes memory signatureData) = _decodeWrapper(sigData.signature);
        if (ownerIndex >= indexBound) return false;

        // A removed owner reads back as empty — `removeOwnerAtIndex` zeroes the entry without reindexing.
        (bool read, bytes memory owner) = _ownerAtIndex(wallet, ownerIndex);
        if (!read || owner.length == 0) return false;

        bytes32 digest = chainAgnosticDigest(wallet, rawHash);

        if (owner.length == PASSKEY_OWNER_LENGTH) {
            return _verifyPasskey(owner, signatureData, digest);
        }
        if (owner.length == ADDRESS_OWNER_LENGTH) {
            return _verifyAddressOwner(owner, signatureData, digest);
        }
        // Any other length is not an owner shape this wallet version produces.
        return false;
    }

    /// @notice The chain-agnostic EIP-712 digest an owner must have signed
    /// @dev Exposed so tests and off-chain signers derive it from one place. `wallet` is in the domain's
    ///      `verifyingContract`, so a signature for one wallet cannot be replayed against another; the chain
    ///      is deliberately NOT bound.
    /// @param wallet The Coinbase Smart Wallet whose owner signs
    /// @param rawHash The protocol's own message hash
    /// @return The EIP-712 digest
    function chainAgnosticDigest(address wallet, bytes32 rawHash) internal pure returns (bytes32) {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                CHAIN_AGNOSTIC_DOMAIN_TYPEHASH,
                keccak256(bytes(DOMAIN_NAME)),
                keccak256(bytes(DOMAIN_VERSION)),
                FIXED_CHAIN_ID,
                wallet
            )
        );
        return keccak256(
            abi.encodePacked(
                bytes1(0x19), bytes1(0x01), domainSeparator, keccak256(abi.encode(MESSAGE_TYPEHASH, rawHash))
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev `nextOwnerIndex()` via low-level `staticcall`. `ok` is false — never a revert — for a codeless
    ///      address, a reverting target, a target with a permissive fallback (empty returndata), or any
    ///      target that does not answer with exactly one word. The strict `== 32` is the point: it is what
    ///      distinguishes "answered" from "silently returned nothing", which is the distinction `try`/`catch`
    ///      cannot make.
    function _nextOwnerIndex(address wallet) private view returns (bool ok, uint256 indexBound) {
        (bool success, bytes memory ret) = wallet.staticcall(abi.encodeCall(ICoinbaseSmartWallet.nextOwnerIndex, ()));
        if (!success || ret.length != 32) return (false, 0);
        assembly ("memory-safe") {
            indexBound := mload(add(ret, 0x20))
        }
        ok = true;
    }

    /// @dev `ownerAtIndex(index)` via low-level `staticcall`, with the dynamic `bytes` return decoded by hand.
    ///      `abi.decode` is avoided for the same reason as in `_decodeWrapper`: it reverts on a malformed
    ///      head, and an owner entry is data coming from an untrusted address.
    function _ownerAtIndex(address wallet, uint256 index) private view returns (bool ok, bytes memory owner) {
        (bool success, bytes memory ret) = wallet.staticcall(abi.encodeCall(ICoinbaseSmartWallet.ownerAtIndex, (index)));
        // Head of a `bytes` return is an offset word plus a length word.
        if (!success || ret.length < 0x40) return (false, "");

        uint256 offset;
        uint256 length;
        assembly ("memory-safe") {
            offset := mload(add(ret, 0x20))
            length := mload(add(ret, 0x40))
        }
        // The canonical encoder always emits 0x20 for a single `bytes` return.
        if (offset != 0x20) return (false, "");
        if (length > ret.length - 0x40) return (false, "");

        owner = LibBytes.slice(ret, 0x40, 0x40 + length);
        ok = true;
    }

    /// @dev Decodes `SignatureWrapper{uint256 ownerIndex, bytes signatureData}` WITHOUT reverting on a
    ///      malformed blob — the input is attacker-controlled, and a revert here would turn an invalid
    ///      signature into a different failure mode than an unrecognised one.
    ///      A bad decode yields `(type(uint256).max, "")`, which the caller rejects on its
    ///      `ownerIndex >= ownerCount` bound. `abi.decode` is deliberately NOT used: it reverts on malformed
    ///      input and Solidity cannot `try` an internal call, so the head words are read and bounds-checked
    ///      directly and the payload is copied with Solady's audited `LibBytes.slice`.
    /// @dev THE LAYOUT IS THE STRUCT ONE, and this is the easiest thing in the whole file to get wrong.
    ///      A Coinbase Smart Wallet does `abi.decode(signature, (SignatureWrapper))`, so what it is handed —
    ///      and what the Coinbase SDK / viem `encodeAbiParameters` produce — is `abi.encode(theStruct)`:
    ///      a dynamic tuple, which carries a LEADING `0x20` offset word before `ownerIndex`:
    ///
    ///          0x00  0x20          <- offset to the tuple (this word is the one that is easy to forget)
    ///          0x20  ownerIndex
    ///          0x40  0x40          <- offset to `signatureData`, relative to 0x20
    ///          0x60  length
    ///          0x80  payload...
    ///
    ///      `abi.encode(uint256, bytes)` — two separate arguments rather than one struct — omits that first
    ///      word and is NOT what any wallet emits. An earlier revision of this function read that flat shape,
    ///      which meant it parsed `0x20` as the owner index and `ownerIndex` as the payload offset: every
    ///      real signature was rejected, and only a hand-rolled blob no wallet produces could pass. Verified
    ///      against the live wallet by probing `isValidSignature`: the struct layout reaches the owner lookup
    ///      and fails with a typed `InvalidOwnerBytesLength`, the flat layout reverts with no data at all.
    ///      Only the canonical struct shape is accepted; anything else is rejected rather than coerced.
    /// @param signature The raw `SignatureWrapper` blob
    /// @return ownerIndex The selected owner index, or `type(uint256).max` when undecodable
    /// @return signatureData The inner signature payload
    function _decodeWrapper(bytes memory signature)
        private
        pure
        returns (uint256 ownerIndex, bytes memory signatureData)
    {
        if (signature.length < MIN_WRAPPER_LENGTH) return (type(uint256).max, "");

        uint256 tupleOffset;
        uint256 dataOffset;
        uint256 dataLength;
        assembly ("memory-safe") {
            tupleOffset := mload(add(signature, 0x20))
            ownerIndex := mload(add(signature, 0x40))
            dataOffset := mload(add(signature, 0x60))
            dataLength := mload(add(signature, 0x80))
        }
        // The canonical encoder always emits these two. Anything else is a hand-rolled blob.
        if (tupleOffset != 0x20 || dataOffset != 0x40) return (type(uint256).max, "");
        // The declared payload length must fit inside the blob that carries it.
        if (dataLength > signature.length - MIN_WRAPPER_LENGTH) return (type(uint256).max, "");

        signatureData = LibBytes.slice(signature, MIN_WRAPPER_LENGTH, MIN_WRAPPER_LENGTH + dataLength);
    }

    /// @dev Passkey owner: `abi.encode(x, y)`. The WebAuthn challenge is OUR chain-agnostic digest, so the
    ///      authenticator committed to this protocol's merkle root and not to the wallet's replay-safe hash.
    /// @dev `requireUserVerification` is false to match the wallet's own ERC-1271 behaviour — a passkey that
    ///      only proves user PRESENCE is still a valid owner signature there, and being stricter here would
    ///      reject signatures the wallet itself accepts.
    function _verifyPasskey(bytes memory owner, bytes memory signatureData, bytes32 digest)
        private
        view
        returns (bool)
    {
        (bytes32 x, bytes32 y) = abi.decode(owner, (bytes32, bytes32));
        // `tryDecodeAuth` does not revert on a malformed blob — it returns a ZEROED struct, so failure is
        // detected by the empty `clientDataJSON` rather than by a bool. `verify` would also return false on
        // a zeroed struct; the explicit check keeps the reason legible.
        WebAuthn.WebAuthnAuth memory auth = WebAuthn.tryDecodeAuth(signatureData);
        if (bytes(auth.clientDataJSON).length == 0) return false;
        return WebAuthn.verify(abi.encode(digest), false, auth, x, y);
    }

    /// @dev Address owner: a Coinbase Smart Wallet may also hold plain ECDSA owners, so the same path serves
    ///      both. `ECDSA.tryRecover` returns `address(0)` instead of reverting on a malformed signature.
    /// @dev The word is masked by hand rather than `abi.decode(owner, (address))`, which REVERTS on a
    ///      non-canonically-encoded entry (dirty upper 96 bits). The entry is read from an untrusted address,
    ///      so a reverting decode here would break this library's never-revert contract.
    /// @dev CONTRACT OWNERS ARE EXPLICITLY NOT SUPPORTED, by design rather than by accident. A Coinbase Smart
    ///      Wallet can register a contract as an address owner, but verifying one chain-agnostically means
    ///      recursing into whatever signature scheme THAT contract uses, and the obvious route — its own
    ///      ERC-1271 — is the chain-bound construction this entire library exists to avoid. So such an owner
    ///      returns false and the caller falls through to generic ERC-1271 against the wallet, where the
    ///      wallet's own (chain-bound) rules apply. Making this a `code.length` check rather than leaving it
    ///      implicit in `tryRecover` matters: the old form looked like it supported contract owners and
    ///      silently could not, because a recovered ECDSA address can never equal a contract that did not
    ///      sign with a secp256k1 key.
    function _verifyAddressOwner(
        bytes memory owner,
        bytes memory signatureData,
        bytes32 digest
    )
        private
        view
        returns (bool)
    {
        uint256 word;
        assembly ("memory-safe") {
            word := mload(add(owner, 0x20))
        }
        if (word >> 160 != 0) return false;

        address ownerAddress = address(uint160(word));
        if (ownerAddress == address(0)) return false;
        if (ownerAddress.code.length != 0) return false;

        return ECDSA.tryRecover(digest, signatureData) == ownerAddress;
    }
}
