// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { WebAuthn } from "solady/utils/WebAuthn.sol";
import { P256 } from "solady/utils/P256.sol";
import {
    ChainAgnosticCoinbaseSmartWalletValidation
} from "../../../src/libraries/ChainAgnosticCoinbaseSmartWalletValidation.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";

/// @dev Minimal Coinbase Smart Wallet stand-in. Only the owner-set surface the library reads, with the same
///      return shapes verified against the live implementation: `abi.encode(x, y)` for a passkey owner,
///      `abi.encode(address)` for an ECDSA owner, empty bytes for a removed index.
contract MockCoinbaseSmartWallet {
    mapping(uint256 => bytes) public owners;
    uint256 public nextOwnerIndexValue;
    bool public revertOnProbe;

    function setPasskeyOwner(uint256 index, bytes32 x, bytes32 y) external {
        owners[index] = abi.encode(x, y);
        if (index + 1 > nextOwnerIndexValue) nextOwnerIndexValue = index + 1;
    }

    function setAddressOwner(uint256 index, address owner) external {
        owners[index] = abi.encode(owner);
        if (index + 1 > nextOwnerIndexValue) nextOwnerIndexValue = index + 1;
    }

    function removeOwner(uint256 index) external {
        delete owners[index];
    }

    function setRevertOnProbe(bool flag) external {
        revertOnProbe = flag;
    }

    function nextOwnerIndex() external view returns (uint256) {
        if (revertOnProbe) revert("not a coinbase smart wallet");
        return nextOwnerIndexValue;
    }

    function ownerAtIndex(uint256 index) external view returns (bytes memory) {
        return owners[index];
    }

    /// @dev THE REAL WALLET HAS THIS, and leaving it out of the mock was hiding a bug. A Coinbase Smart
    ///      Wallet answers unknown selectors from a permissive fallback that returns `0x` rather than
    ///      reverting. Any probe shaped as `try target.f() returns (T)` therefore succeeds and then reverts
    ///      in the CALLER's frame when it decodes nothing into `T` — uncatchably. A mock without a fallback
    ///      reverts instead, which `catch` handles, so the probe looked safe when it was not.
    fallback() external { }
}

/// @dev A contract that is NOT a Coinbase Smart Wallet but answers everything with `0x`, exactly as the real
///      wallet's fallback does. This is the shape that breaks `try`/`catch` probing.
contract PermissiveFallbackContract {
    fallback() external { }
}

/// @dev Answers `nextOwnerIndex()` with fewer than 32 bytes — "answered, but not with a word".
contract ShortReturnContract {
    fallback() external {
        assembly {
            mstore(0x00, 1)
            return(0x00, 0x01)
        }
    }
}

/// @dev Claims to be a wallet but returns a malformed dynamic `bytes` head from `ownerAtIndex`.
contract MalformedOwnerEntryContract {
    function nextOwnerIndex() external pure returns (uint256) {
        return 1;
    }

    function ownerAtIndex(uint256) external pure returns (bytes memory) {
        assembly {
            // A bogus offset word where the canonical encoder would emit 0x20.
            mstore(0x00, 0xff)
            mstore(0x20, 0x20)
            return(0x00, 0x40)
        }
    }
}

/// @dev Claims to be a wallet but reverts on `ownerAtIndex`. A revert IS catchable, unlike a decode failure,
///      so this covers the other half of the probe contract.
contract RevertingOwnerEntryContract {
    function nextOwnerIndex() external pure returns (uint256) {
        return 1;
    }

    function ownerAtIndex(uint256) external pure returns (bytes memory) {
        revert("no");
    }
}

/// @dev Reports a huge `nextOwnerIndex`, so the caller's `ownerIndex >= indexBound` bound cannot reject an
///      out-of-range index on its own. Guards the `type(uint256).max` decode sentinel.
contract HugeIndexBoundContract {
    function nextOwnerIndex() external pure returns (uint256) {
        return type(uint256).max;
    }

    function ownerAtIndex(uint256) external pure returns (bytes memory) {
        return "";
    }
}

/// @dev Returns an owner entry of a length no wallet version produces (neither 32 nor 64).
contract OddLengthOwnerContract {
    uint256 public len;

    function setLen(uint256 len_) external {
        len = len_;
    }

    function nextOwnerIndex() external pure returns (uint256) {
        return 1;
    }

    function ownerAtIndex(uint256) external view returns (bytes memory) {
        return new bytes(len);
    }
}

/// @dev A wallet whose `ownerAtIndex` returns a 32-byte entry with dirty upper bits — not a canonical
///      `abi.encode(address)`, so `abi.decode(entry, (address))` would revert.
contract DirtyAddressOwnerContract {
    function nextOwnerIndex() external pure returns (uint256) {
        return 1;
    }

    function ownerAtIndex(uint256) external pure returns (bytes memory) {
        return abi.encodePacked(type(uint256).max);
    }
}

/// @dev Exposes the library's internals for direct testing.
contract CbswHarness {
    using ChainAgnosticCoinbaseSmartWalletValidation for address;

    function validate(address wallet, bytes memory signature, bytes32 rawHash) external view returns (bool) {
        ISuperValidator.SignatureData memory sigData;
        sigData.signature = signature;
        sigData.merkleRoot = rawHash;
        return wallet.validateChainAgnosticPasskey(sigData, rawHash);
    }

    function digest(address wallet, bytes32 rawHash) external pure returns (bytes32) {
        return ChainAgnosticCoinbaseSmartWalletValidation.chainAgnosticDigest(wallet, rawHash);
    }

    function isCbsw(address wallet) external view returns (bool) {
        return wallet.isCoinbaseSmartWallet();
    }
}

contract CoinbaseSmartWalletValidationTest is Test {
    /// @dev The wallet's own signature envelope, declared so `abi.encode` produces the dynamic-tuple layout.
    struct SignatureWrapper {
        uint256 ownerIndex;
        bytes signatureData;
    }

    CbswHarness internal harness;
    MockCoinbaseSmartWallet internal wallet;

    /// @dev Fixed so the EIP-712 digest is deterministic and the off-chain WebAuthn fixture below stays valid.
    address internal constant WALLET_ADDR = 0x00000000000000000000000000000000cB5C0001;
    bytes32 internal constant RAW_HASH = bytes32(uint256(0xBEEF));

    /// @dev Pinned Base fork. REQUIRED, not incidental: P-256 verification needs the RIP-7212 precompile at
    ///      `0x100`, which Foundry's local EVM does not provide (it reverts `P256VerificationFailed`) and
    ///      which no deployed Solidity verifier backs locally either. Base has it — verified by staticcalling
    ///      `0x100` with a known-good vector (valid -> 1, corrupted -> empty) on 2026-10-06, alongside
    ///      Ethereum, Optimism, Linea and Flare. Forking is therefore also the higher-fidelity test: it
    ///      exercises the same precompile production will use.
    uint256 internal constant BASE_FORK_BLOCK = 51_778_000;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), BASE_FORK_BLOCK);
        harness = new CbswHarness();
        MockCoinbaseSmartWallet deployed = new MockCoinbaseSmartWallet();
        vm.etch(WALLET_ADDR, address(deployed).code);
        wallet = MockCoinbaseSmartWallet(WALLET_ADDR);
    }

    /// @notice Guards the fixture's own precondition, and documents WHAT ACTUALLY VERIFIES P-256 here.
    /// @dev Not the RIP-7212 precompile. The precompile at `0x100` is live on Base in production (probed
    ///      directly on 2026-10-06: valid vector -> 1, corrupted -> empty, alongside Ethereum, Optimism,
    ///      Linea and Flare), but Foundry does not emulate it, and a fork does not carry it either — so
    ///      `0x100` is codeless in this environment and the staticcall to it returns nothing. What answers
    ///      instead is solady's fallback path: the deployed Solidity verifier at
    ///      `0x000000000000D01eA45F9eFD5c54f037Fa57Ea1a`, which exists on the pinned Base fork. That costs
    ///      ~291k gas here versus the ~3.4k the precompile costs in production, so DO NOT read gas numbers
    ///      from the passkey tests below as production costs.
    ///      This matters beyond bookkeeping: on solady 0.1.9 (the version `foundry.toml` remaps `solady/` to)
    ///      `P256.verifySignature` REVERTS `P256VerificationFailed()` when neither backend exists, rather
    ///      than returning false. If the verifier ever stops existing at the pinned block, every passkey test
    ///      below would fail with that revert for a reason unrelated to this library. Fail here first.
    function test_Precondition_P256VerificationIsAvailable() public view {
        assertEq(address(0x100).code.length, 0, "fork unexpectedly provides the RIP-7212 precompile");
        assertGt(
            address(0x000000000000D01eA45F9eFD5c54f037Fa57Ea1a).code.length,
            0,
            "solady's P256 verifier is absent on the pinned fork"
        );

        // The fixture's own signature, verified through the same backend the library uses. The WebAuthn
        // message is `sha256(authenticatorData || sha256(clientDataJSON))`.
        bytes32 webAuthnHash = sha256(abi.encodePacked(AUTHENTICATOR_DATA, sha256(bytes(CLIENT_DATA_JSON))));
        assertTrue(
            P256.verifySignature(webAuthnHash, SIG_R, SIG_S, PUBKEY_X, PUBKEY_Y),
            "the pinned P-256 fixture no longer verifies"
        );
    }

    /// @dev The off-chain WebAuthn fixture, generated against `DIGEST` below with a real secp256r1 key.
    ///      Regenerate if `WALLET_ADDR`, `RAW_HASH` or the library's domain constants ever change — the
    ///      `test_Digest_IsStable` assertion exists to make that failure loud instead of silent.
    bytes32 internal constant DIGEST = 0x2c8e66de7970221da747bb24d6747064fc779a92e409799a2120226345419d73;
    bytes32 internal constant PUBKEY_X = 0x6be0c7ec06e1465fc084ffc8795a2c873d9acb6c56d29623e66d7e8489fc613f;
    bytes32 internal constant PUBKEY_Y = 0x1431631f92faa3b6b2bda15375e238b162e4c6cd7779b78e67e33257c54d3413;
    bytes32 internal constant SIG_R = 0x041da052edb83ffbc2418acbeef5cfb882bb806218df1e1806d53679aaf7a19f;
    bytes32 internal constant SIG_S = 0x513b178e13d9fabdff1c512f5f99ed29fbebf12e477482a62c53fe3cd4175268;
    bytes internal constant AUTHENTICATOR_DATA =
        hex"f198086b2db17256731bc456673b96bcef23f51d1fbacdd7c4379ef65465572f0500000000";
    string internal constant CLIENT_DATA_JSON =
        "{\"type\":\"webauthn.get\",\"challenge\":\"LI5m3nlwIh2nR7sk1nRwZPx3mpLkCXmaISAiY0VBnXM\",\"origin\":\"https://keys.coinbase.com\",\"crossOrigin\":false}";
    uint256 internal constant CHALLENGE_INDEX = 23;
    uint256 internal constant TYPE_INDEX = 1;

    /// @dev Builds the `SignatureWrapper{ownerIndex, signatureData}` a Coinbase Smart Wallet produces.
    ///      ENCODED AS A STRUCT, which is the whole point: the wallet does
    ///      `abi.decode(signature, (SignatureWrapper))`, so the blob is a dynamic tuple carrying a leading
    ///      `0x20` offset word. An earlier revision of this helper used `abi.encode(ownerIndex, data)` — the
    ///      FLAT two-argument encoding, which omits that word and which no wallet emits — and it shared that
    ///      bug with the library, so the suite passed against a blob that could never occur in production.
    ///      `_wrapFlat` below keeps the wrong shape around purely so a regression test can assert it is
    ///      rejected.
    function _wrap(uint256 ownerIndex, bytes memory signatureData) internal pure returns (bytes memory) {
        return abi.encode(SignatureWrapper({ ownerIndex: ownerIndex, signatureData: signatureData }));
    }

    function _wrapFlat(uint256 ownerIndex, bytes memory signatureData) internal pure returns (bytes memory) {
        return abi.encode(ownerIndex, signatureData);
    }

    function _webAuthnAuth() internal pure returns (WebAuthn.WebAuthnAuth memory) {
        return WebAuthn.WebAuthnAuth({
            authenticatorData: AUTHENTICATOR_DATA,
            clientDataJSON: CLIENT_DATA_JSON,
            challengeIndex: CHALLENGE_INDEX,
            typeIndex: TYPE_INDEX,
            r: SIG_R,
            s: SIG_S
        });
    }

    function _passkeySignature(uint256 ownerIndex) internal pure returns (bytes memory) {
        return _wrap(ownerIndex, abi.encode(_webAuthnAuth()));
    }

    /*//////////////////////////////////////////////////////////////
                        THE DIGEST IS CHAIN-AGNOSTIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Pins the digest the fixture was signed against, so a change to the domain constants fails here
    ///         with a legible message instead of making every signature test mysteriously fail.
    function test_Digest_IsStable() public view {
        assertEq(harness.digest(WALLET_ADDR, RAW_HASH), DIGEST, "regenerate the WebAuthn fixture");
    }

    /// @notice THE WHOLE POINT OF OPTION B. The digest does NOT move with the chain id, so ONE passkey
    ///         signature authorises the same merkle root everywhere. Delegating to the wallet's own ERC-1271
    ///         could never do this: its EIP-712 domain carries `chainId` AND `verifyingContract` (verified
    ///         on-chain against the live implementation).
    function test_Digest_DoesNotDependOnChainId() public {
        bytes32 onBase = harness.digest(WALLET_ADDR, RAW_HASH);
        vm.chainId(1);
        assertEq(harness.digest(WALLET_ADDR, RAW_HASH), onBase, "digest moved with the chain");
        vm.chainId(42_161);
        assertEq(harness.digest(WALLET_ADDR, RAW_HASH), onBase, "digest moved with the chain");
    }

    /// @notice But it IS bound to the wallet, so a signature cannot be replayed against another wallet.
    function test_Digest_IsBoundToTheWallet() public view {
        assertTrue(
            harness.digest(WALLET_ADDR, RAW_HASH) != harness.digest(address(0xBEEF), RAW_HASH),
            "digest must bind the wallet"
        );
        assertTrue(
            harness.digest(WALLET_ADDR, RAW_HASH) != harness.digest(WALLET_ADDR, bytes32(uint256(1))),
            "digest must bind the root"
        );
    }

    /*//////////////////////////////////////////////////////////////
                      A REAL P-256 PASSKEY SIGNATURE
    //////////////////////////////////////////////////////////////*/

    /// @notice THE FEATURE: a genuine secp256r1 WebAuthn assertion from a registered passkey owner validates.
    ///         The signature was produced off-chain by a real P-256 key over
    ///         `sha256(authenticatorData || sha256(clientDataJSON))`, with the challenge being this library's
    ///         chain-agnostic digest — i.e. exactly what a Base Smart Wallet passkey produces.
    function test_PasskeyOwner_ValidSignatureIsAccepted() public {
        wallet.setPasskeyOwner(0, PUBKEY_X, PUBKEY_Y);
        assertTrue(harness.validate(WALLET_ADDR, _passkeySignature(0), RAW_HASH), "valid passkey rejected");
    }

    /// @notice And it still validates on another chain id — the end-to-end form of `test_Digest_...`.
    function test_PasskeyOwner_ValidOnAnyChain() public {
        wallet.setPasskeyOwner(0, PUBKEY_X, PUBKEY_Y);
        vm.chainId(1);
        assertTrue(harness.validate(WALLET_ADDR, _passkeySignature(0), RAW_HASH), "rejected on mainnet");
        vm.chainId(10);
        assertTrue(harness.validate(WALLET_ADDR, _passkeySignature(0), RAW_HASH), "rejected on optimism");
    }

    /// @notice A different root is a different digest, so the same assertion must NOT validate.
    function test_PasskeyOwner_RejectsADifferentRoot() public {
        wallet.setPasskeyOwner(0, PUBKEY_X, PUBKEY_Y);
        assertFalse(
            harness.validate(WALLET_ADDR, _passkeySignature(0), bytes32(uint256(0xDEAD))),
            "signature must not cover a different root"
        );
    }

    /// @notice A valid assertion from a key that is NOT a registered owner is refused.
    function test_PasskeyOwner_RejectsAnUnregisteredKey() public {
        wallet.setPasskeyOwner(0, bytes32(uint256(1)), bytes32(uint256(2)));
        assertFalse(harness.validate(WALLET_ADDR, _passkeySignature(0), RAW_HASH), "wrong key accepted");
    }

    /// @notice `ownerIndex` is attacker-supplied calldata and is never trusted: out of range is refused, and
    ///         pointing at a DIFFERENT registered owner does not transfer the signature's validity.
    function test_OwnerIndex_IsNotTrusted() public {
        wallet.setPasskeyOwner(0, PUBKEY_X, PUBKEY_Y);
        wallet.setPasskeyOwner(1, bytes32(uint256(3)), bytes32(uint256(4)));

        assertFalse(harness.validate(WALLET_ADDR, _passkeySignature(5), RAW_HASH), "out-of-range accepted");
        assertFalse(harness.validate(WALLET_ADDR, _passkeySignature(1), RAW_HASH), "index swap accepted");
        assertTrue(harness.validate(WALLET_ADDR, _passkeySignature(0), RAW_HASH), "correct index still works");
    }

    /// @notice A removed owner reads back as empty bytes — `removeOwnerAtIndex` zeroes the entry without
    ///         reindexing — and must not validate even though the index is still in range.
    function test_RemovedOwner_IsRefused() public {
        wallet.setPasskeyOwner(0, PUBKEY_X, PUBKEY_Y);
        assertTrue(harness.validate(WALLET_ADDR, _passkeySignature(0), RAW_HASH));
        wallet.removeOwner(0);
        assertFalse(harness.validate(WALLET_ADDR, _passkeySignature(0), RAW_HASH), "removed owner accepted");
    }

    /*//////////////////////////////////////////////////////////////
                   FALL-THROUGH: never revert, return false
    //////////////////////////////////////////////////////////////*/

    /// @notice The caller's contract: a non-Coinbase owner returns FALSE so `SuperValidatorBase` can fall
    ///         through to generic ERC-1271, rather than reverting and bricking that account.
    function test_NotACoinbaseWallet_ReturnsFalse() public {
        wallet.setRevertOnProbe(true);
        assertFalse(harness.validate(WALLET_ADDR, _passkeySignature(0), RAW_HASH), "probe must fall through");
    }

    /// @notice A codeless (counterfactual) wallet cannot have its owner set read, so it returns false here —
    ///         the caller turns that into `UNDEPLOYED_CONTRACT_SIGNER` rather than an ECDSA length revert.
    function test_CodelessWallet_ReturnsFalse() public view {
        assertFalse(harness.validate(address(0xC0DE1E55), _passkeySignature(0), RAW_HASH));
    }

    /// @notice An empty owner set returns false.
    function test_NoOwners_ReturnsFalse() public view {
        assertFalse(harness.validate(WALLET_ADDR, _passkeySignature(0), RAW_HASH));
    }

    /// @notice MALFORMED SIGNATURES MUST NOT REVERT — the blob is attacker-controlled, and a revert would be
    ///         a different failure mode than "unrecognised". Covers: too short, a bogus ABI offset, an inner
    ///         length that overruns the blob, and a garbage WebAuthn payload.
    function test_MalformedSignatures_ReturnFalseAndNeverRevert() public {
        wallet.setPasskeyOwner(0, PUBKEY_X, PUBKEY_Y);

        bytes[5] memory bad = [
            bytes(""),
            abi.encodePacked(bytes32(uint256(0))),
            abi.encode(uint256(0), uint256(0x99)),
            abi.encodePacked(abi.encode(uint256(0), uint256(0x40)), bytes32(type(uint256).max)),
            _wrap(0, hex"deadbeef")
        ];
        for (uint256 i; i < bad.length; ++i) {
            assertFalse(harness.validate(WALLET_ADDR, bad[i], RAW_HASH), "malformed blob accepted");
        }
    }

    /// @notice Fuzzed garbage never validates and never reverts.
    /// forge-config: default.fuzz.runs = 512
    function testFuzz_RandomSignatureNeverValidates(bytes calldata blob) public {
        wallet.setPasskeyOwner(0, PUBKEY_X, PUBKEY_Y);
        assertFalse(harness.validate(WALLET_ADDR, blob, RAW_HASH));
    }

    /*//////////////////////////////////////////////////////////////
                        ECDSA OWNERS ON THE SAME WALLET
    //////////////////////////////////////////////////////////////*/

    /// @notice A Coinbase Smart Wallet may also hold plain ECDSA owners, so the same path serves both. The
    ///         signature is over the SAME chain-agnostic digest, not over the wallet's replay-safe hash.
    function test_AddressOwner_ValidSignatureIsAccepted() public {
        (address signer, uint256 pk) = makeAddrAndKey("cbsw-ecdsa-owner");
        wallet.setAddressOwner(0, signer);

        (uint8 v, bytes32 r, bytes32 sVal) = vm.sign(pk, harness.digest(WALLET_ADDR, RAW_HASH));
        assertTrue(harness.validate(WALLET_ADDR, _wrap(0, abi.encodePacked(r, sVal, v)), RAW_HASH));
    }

    /// @notice And a signature from a non-owner key is refused.
    function test_AddressOwner_RejectsANonOwner() public {
        (address signer,) = makeAddrAndKey("cbsw-ecdsa-owner");
        (, uint256 otherPk) = makeAddrAndKey("not-an-owner");
        wallet.setAddressOwner(0, signer);

        (uint8 v, bytes32 r, bytes32 sVal) = vm.sign(otherPk, harness.digest(WALLET_ADDR, RAW_HASH));
        assertFalse(harness.validate(WALLET_ADDR, _wrap(0, abi.encodePacked(r, sVal, v)), RAW_HASH));
    }

    /*//////////////////////////////////////////////////////////////
          WEBAUTHN SEMANTICS THAT MUST BE ENFORCED, NOT ASSUMED
    //////////////////////////////////////////////////////////////*/

    /// @dev The SAME signature as the valid fixture with `s` replaced by `n - s`: still a mathematically
    ///      valid ECDSA signature over the same message and key, but with HIGH s.
    bytes32 internal constant SIG_S_HIGH = 0x815418685597d574e591422ee2131b5ffac06490d85046a2622e5d8ff2dab070;

    /// @dev A perfectly valid assertion whose authenticator flags byte is `0x00` — neither User Present nor
    ///      User Verified. Real signature over real authenticator data; only the flags differ.
    bytes internal constant AUTH_DATA_NO_UP =
        hex"f198086b2db17256731bc456673b96bcef23f51d1fbacdd7c4379ef65465572f0000000000";
    bytes32 internal constant SIG_R_NO_UP = 0x6bcc5a2fcbb1b1b20c6b83a754a3f11abb39a057dcc15d2361d3112a9f0d3239;
    bytes32 internal constant SIG_S_NO_UP = 0x1ff0f90f00bfe57018b3aabf1854260a14964d8c3510bfdd244b5d00b36dce85;

    /// @dev A validly signed REGISTRATION ceremony (`"type":"webauthn.create"`) over the same challenge.
    string internal constant CLIENT_DATA_JSON_CREATE =
        "{\"type\":\"webauthn.create\",\"challenge\":\"Ruscp3HnzJ75fIx9S4XSZqHLLuBvfcfOinGBpDIo1Kw\",\"origin\":\"https://keys.coinbase.com\",\"crossOrigin\":false}";
    uint256 internal constant CHALLENGE_INDEX_CREATE = 26;
    bytes32 internal constant SIG_R_CREATE = 0xec51e44ed856960a55e81047f5cfd0f019dc90c62b1a061f7f1a8fbe0b14f911;
    bytes32 internal constant SIG_S_CREATE = 0x72ed80c1f381de2ab853a38296c85994d3ff9100e5fa6a6b01995d159f18c33e;

    function _signatureWith(
        bytes memory authData,
        string memory clientData,
        uint256 challengeIndex,
        uint256 typeIndex,
        bytes32 r,
        bytes32 sVal
    )
        internal
        pure
        returns (bytes memory)
    {
        return _wrap(
            0,
            abi.encode(
                WebAuthn.WebAuthnAuth({
                    authenticatorData: authData,
                    clientDataJSON: clientData,
                    challengeIndex: challengeIndex,
                    typeIndex: typeIndex,
                    r: r,
                    s: sVal
                })
            )
        );
    }

    /// @notice SIGNATURE MALLEABILITY. `(r, n - s)` is as valid a curve signature as `(r, s)`, so a verifier
    ///         that accepts both lets the same authorisation be presented under two different byte strings.
    ///         Solady's `P256.verifySignature` enforces low-s (its `verifySignatureAllowMalleability` sibling
    ///         does not, and is deliberately NOT what this library calls). Asserted against a high-s twin of
    ///         the fixture that is otherwise byte-identical.
    function test_Malleability_HighSSignatureIsRejected() public {
        wallet.setPasskeyOwner(0, PUBKEY_X, PUBKEY_Y);

        // Positive control first, so a blanket failure cannot pass this test.
        assertTrue(harness.validate(WALLET_ADDR, _passkeySignature(0), RAW_HASH), "low-s must validate");

        bytes memory highS =
            _signatureWith(AUTHENTICATOR_DATA, CLIENT_DATA_JSON, CHALLENGE_INDEX, TYPE_INDEX, SIG_R, SIG_S_HIGH);
        assertFalse(harness.validate(WALLET_ADDR, highS, RAW_HASH), "high-s signature accepted");
    }

    /// @notice USER PRESENCE IS MANDATORY. The library passes `requireUserVerification = false`, which is
    ///         correct — it matches what the wallet's own ERC-1271 accepts — but that must not be mistaken for
    ///         "no authenticator flags are checked at all". WebAuthn's User Present bit says a human
    ///         interacted with the authenticator; an assertion without it could be produced silently. This
    ///         fixture is a real signature over real authenticator data whose flags byte is `0x00`, so it
    ///         fails on the flag check and nothing else.
    function test_Flags_AssertionWithoutUserPresenceIsRejected() public {
        wallet.setPasskeyOwner(0, PUBKEY_X, PUBKEY_Y);
        bytes memory noUp =
            _signatureWith(AUTH_DATA_NO_UP, CLIENT_DATA_JSON, CHALLENGE_INDEX, TYPE_INDEX, SIG_R_NO_UP, SIG_S_NO_UP);
        assertFalse(harness.validate(WALLET_ADDR, noUp, RAW_HASH), "assertion without user presence accepted");
    }

    /// @notice CEREMONY TYPE IS CHECKED. `webauthn.create` is a registration, `webauthn.get` an
    ///         authentication. Accepting the former would mean a credential-registration signature could
    ///         authorise a transaction. The fixture is a VALID signature over a `webauthn.create` client data
    ///         JSON carrying the correct challenge, so only the ceremony type distinguishes it.
    function test_ClientData_RegistrationCeremonyIsRejected() public {
        wallet.setPasskeyOwner(0, PUBKEY_X, PUBKEY_Y);
        bytes memory create = _signatureWith(
            AUTHENTICATOR_DATA, CLIENT_DATA_JSON_CREATE, CHALLENGE_INDEX_CREATE, TYPE_INDEX, SIG_R_CREATE, SIG_S_CREATE
        );
        assertFalse(harness.validate(WALLET_ADDR, create, RAW_HASH), "webauthn.create assertion accepted");
    }

    /// @notice `challengeIndex` and `typeIndex` are attacker-supplied pointers INTO the client data, not
    ///         derived from it. A lie about where the challenge sits must not let a signature through, and an
    ///         out-of-range index must not read out of bounds. Tested with the otherwise-valid fixture so the
    ///         indices are the only thing wrong.
    function test_ClientData_LyingIndicesAreRejected() public {
        wallet.setPasskeyOwner(0, PUBKEY_X, PUBKEY_Y);

        uint256[4] memory badChallenge = [uint256(0), 22, 24, type(uint256).max];
        for (uint256 i; i < badChallenge.length; ++i) {
            assertFalse(
                harness.validate(
                    WALLET_ADDR,
                    _signatureWith(AUTHENTICATOR_DATA, CLIENT_DATA_JSON, badChallenge[i], TYPE_INDEX, SIG_R, SIG_S),
                    RAW_HASH
                ),
                "bogus challengeIndex accepted"
            );
        }

        uint256[3] memory badType = [uint256(0), 2, type(uint256).max];
        for (uint256 i; i < badType.length; ++i) {
            assertFalse(
                harness.validate(
                    WALLET_ADDR,
                    _signatureWith(AUTHENTICATOR_DATA, CLIENT_DATA_JSON, CHALLENGE_INDEX, badType[i], SIG_R, SIG_S),
                    RAW_HASH
                ),
                "bogus typeIndex accepted"
            );
        }
    }

    /// @notice Truncated authenticator data (no flags byte to read) is rejected rather than read out of
    ///         bounds: solady requires length > 32 before touching the flags.
    function test_AuthenticatorData_TruncatedIsRejected() public {
        wallet.setPasskeyOwner(0, PUBKEY_X, PUBKEY_Y);
        assertFalse(
            harness.validate(
                WALLET_ADDR,
                _signatureWith(new bytes(32), CLIENT_DATA_JSON, CHALLENGE_INDEX, TYPE_INDEX, SIG_R, SIG_S),
                RAW_HASH
            ),
            "truncated authenticator data accepted"
        );
    }

    /*//////////////////////////////////////////////////////////////
                      OWNER ENTRIES FROM AN UNTRUSTED WALLET
    //////////////////////////////////////////////////////////////*/

    /// @notice Only 32-byte (address) and 64-byte (P-256 key) entries are owner shapes this wallet version
    ///         produces. Anything else is refused rather than interpreted.
    function test_OwnerEntry_UnexpectedLengthsAreRefused() public {
        OddLengthOwnerContract odd = new OddLengthOwnerContract();
        uint256[6] memory lengths = [uint256(1), 31, 33, 63, 65, 96];
        for (uint256 i; i < lengths.length; ++i) {
            odd.setLen(lengths[i]);
            assertFalse(harness.validate(address(odd), _passkeySignature(0), RAW_HASH), "odd-length owner accepted");
        }
    }

    /// @notice A reverting `ownerAtIndex` returns false. Unlike a decode failure this one IS catchable, so it
    ///         covers the other half of the probe's contract.
    function test_OwnerEntry_RevertingLookupReturnsFalse() public {
        address reverting = address(new RevertingOwnerEntryContract());
        assertTrue(harness.isCbsw(reverting), "probe should route here");
        assertFalse(harness.validate(reverting, _passkeySignature(0), RAW_HASH));
    }

    /// @notice A hostile wallet reporting `nextOwnerIndex() == type(uint256).max` cannot smuggle the decode
    ///         sentinel through. `_decodeWrapper` returns `type(uint256).max` for an undecodable blob, and the
    ///         caller's only bound is `ownerIndex >= indexBound` — which still holds at the boundary
    ///         (`max >= max`). This test exists because that is the one place where a wallet-supplied number
    ///         meets an internal sentinel, and it would be an authorisation bypass if the comparison were
    ///         `>` instead of `>=`.
    function test_OwnerIndex_SentinelCannotPassAHugeIndexBound() public {
        address huge = address(new HugeIndexBoundContract());
        assertTrue(harness.isCbsw(huge), "probe should route here");
        // A blob too short to decode -> ownerIndex == type(uint256).max
        assertFalse(harness.validate(huge, hex"00", RAW_HASH), "decode sentinel passed the bound");
        // And a well-formed blob at the top of the range still finds no owner.
        assertFalse(harness.validate(huge, _passkeySignature(type(uint256).max), RAW_HASH));
    }

    /// @notice DOCUMENTED, DELIBERATE MALLEABILITY at the envelope level: trailing bytes after the payload
    ///         do not invalidate a blob, so the same authorisation has more than one valid byte string.
    /// @dev This is asserted rather than fixed, and the reasoning should outlive the decision.
    ///      Why it is benign here: the blob is never used as a uniqueness key. Replay protection comes from
    ///      the merkle root, and `userOpHash` excludes the signature, so a bundler can already re-encode it
    ///      without changing what is authorised. `SuperValidatorV2` additionally refuses destination
    ///      execution, so the blob never reaches `storeSignature` either.
    ///      Why NOT tightened to an exact length: the wallet's own decoder is
    ///      `abi.decode(signature, (SignatureWrapper))`, and ABI decoding ignores trailing data — so a strict
    ///      check here would reject blobs the wallet itself accepts, turning a harmless encoding difference
    ///      into a liveness failure for a producer we have not inspected. Matching the wallet's tolerance is
    ///      the safer asymmetry.
    ///      If this is ever tightened, this test is the one that should flip to `assertFalse`.
    function test_Wrapper_TrailingBytesDoNotInvalidate() public {
        wallet.setPasskeyOwner(0, PUBKEY_X, PUBKEY_Y);
        bytes memory canonical = _passkeySignature(0);
        bytes memory padded = abi.encodePacked(canonical, hex"deadbeefdeadbeef");

        assertTrue(harness.validate(WALLET_ADDR, canonical, RAW_HASH), "canonical blob must validate");
        assertTrue(harness.validate(WALLET_ADDR, padded, RAW_HASH), "trailing bytes currently tolerated");
        assertTrue(keccak256(canonical) != keccak256(padded), "the two blobs must differ");
    }

    /// @notice But a blob whose declared payload length OVERRUNS the bytes carrying it is rejected, which is
    ///         the part that actually matters: tolerating extra bytes is harmless, reading past the end is
    ///         not.
    function test_Wrapper_OverrunningLengthIsRejected() public {
        wallet.setPasskeyOwner(0, PUBKEY_X, PUBKEY_Y);
        bytes memory canonical = _passkeySignature(0);

        // Overwrite the payload-length word (4th word) with something larger than the blob.
        bytes memory overrun = canonical;
        assembly {
            mstore(add(overrun, 0xa0), 0xffff)
        }
        assertFalse(harness.validate(WALLET_ADDR, overrun, RAW_HASH), "overrunning length accepted");
    }

    /*//////////////////////////////////////////////////////////////
                        DOMAIN SEPARATION ACROSS FAMILIES
    //////////////////////////////////////////////////////////////*/

    /// @notice The Coinbase digest must never collide with the Safe library's for the same wallet and root.
    ///         Both use the same EIP-712 domain TYPEHASH, the same `FIXED_CHAIN_ID` and the same version, so
    ///         the ONLY thing keeping them apart is the domain name ("SuperformCoinbaseSmartWallet" versus
    ///         "SuperformSafe") and the message typehash. If either were ever aligned, one owner family's
    ///         signature would authorise the other's — this recomputes the Safe construction independently
    ///         and asserts the two differ.
    function test_Domain_CoinbaseDigestCannotCollideWithSafe() public view {
        bytes32 coinbase = harness.digest(WALLET_ADDR, RAW_HASH);

        bytes32 safeDomain = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("SuperformSafe")),
                keccak256(bytes("1.0.0")),
                uint256(1),
                WALLET_ADDR
            )
        );
        bytes32 safeDigest = keccak256(
            abi.encodePacked(
                bytes1(0x19),
                bytes1(0x01),
                safeDomain,
                keccak256(abi.encode(keccak256("SafeMessage(bytes message)"), keccak256(abi.encode(RAW_HASH))))
            )
        );

        assertTrue(coinbase != safeDigest, "Coinbase and Safe digests must never collide");
    }

    /*//////////////////////////////////////////////////////////////
          ROUTING: THE DETECTOR MUST ANSWER, NEVER REVERT
    //////////////////////////////////////////////////////////////*/

    /// @notice REGRESSION. A contract that answers every selector with `0x` — which is what a Coinbase Smart
    ///         Wallet's own permissive fallback does, and what any number of other contracts do — must be
    ///         reported as "not a Coinbase Smart Wallet" rather than reverting.
    ///         This is why the probe is a low-level `staticcall` with a `returndatasize` check instead of
    ///         `try target.nextOwnerIndex() returns (uint256)`: with `try`, the call SUCCEEDS and the ABI
    ///         decode of the absent return value then reverts in the caller's frame, where `catch` cannot
    ///         reach it. `ChainAgnosticSafeSignatureValidation` still has that shape at its `getOwners()`
    ///         probe, which is precisely why `SuperValidatorV2` routes the two wallet families apart instead
    ///         of chaining them.
    function test_Probe_PermissiveFallbackIsNotMistakenForAWallet() public {
        address permissive = address(new PermissiveFallbackContract());
        assertFalse(harness.isCbsw(permissive), "permissive fallback detected as a wallet");
        assertFalse(harness.validate(permissive, _passkeySignature(0), RAW_HASH), "validation must be false");
    }

    /// @notice A target that answers with fewer than 32 bytes has not answered with a word.
    function test_Probe_ShortReturnIsRejected() public {
        address shortReturn = address(new ShortReturnContract());
        assertFalse(harness.isCbsw(shortReturn), "short return accepted");
        assertFalse(harness.validate(shortReturn, _passkeySignature(0), RAW_HASH));
    }

    /// @notice A codeless address is not a wallet, and the detector says so without calling anything.
    function test_Probe_CodelessAddressIsNotAWallet() public view {
        assertFalse(harness.isCbsw(address(0xC0DE1E55)));
    }

    /// @notice A wallet with an occupied index IS detected — the positive control for the three above.
    function test_Probe_RealWalletIsDetected() public {
        wallet.setPasskeyOwner(0, PUBKEY_X, PUBKEY_Y);
        assertTrue(harness.isCbsw(WALLET_ADDR), "wallet not detected");
    }

    /// @notice An empty owner set is not routable: there is no owner to verify against, so the caller should
    ///         keep looking rather than treat the signature as ours and fail it.
    function test_Probe_EmptyOwnerSetIsNotRoutable() public view {
        assertFalse(harness.isCbsw(WALLET_ADDR), "empty wallet routed to this library");
    }

    /// @notice A malformed dynamic `bytes` head from `ownerAtIndex` is rejected, not decoded. The entry comes
    ///         from an untrusted address, so `abi.decode` — which reverts on a bad head — is not used.
    function test_OwnerEntry_MalformedReturnDoesNotRevert() public {
        address malformed = address(new MalformedOwnerEntryContract());
        assertTrue(harness.isCbsw(malformed), "probe should still route here");
        assertFalse(harness.validate(malformed, _passkeySignature(0), RAW_HASH), "malformed entry accepted");
    }

    /*//////////////////////////////////////////////////////////////
                     THE WRAPPER LAYOUT IS THE STRUCT ONE
    //////////////////////////////////////////////////////////////*/

    /// @notice REGRESSION, and the one that invalidated an entire earlier green suite. The flat
    ///         `abi.encode(uint256, bytes)` encoding omits the dynamic tuple's leading `0x20` word, so it is
    ///         not what any wallet emits; it must be rejected, while the struct encoding of the SAME
    ///         signature is accepted. Asserting both in one test is deliberate: either assertion alone could
    ///         be satisfied by a decoder that is simply broken.
    function test_Wrapper_StructLayoutAcceptedFlatLayoutRejected() public {
        wallet.setPasskeyOwner(0, PUBKEY_X, PUBKEY_Y);
        bytes memory inner = abi.encode(_webAuthnAuth());

        assertTrue(harness.validate(WALLET_ADDR, _wrap(0, inner), RAW_HASH), "struct layout rejected");
        assertFalse(harness.validate(WALLET_ADDR, _wrapFlat(0, inner), RAW_HASH), "flat layout accepted");
    }

    /// @notice And the two really are different bytes — guards against the helpers silently converging.
    function test_Wrapper_LayoutsDiffer() public pure {
        assertTrue(
            keccak256(_wrap(7, hex"deadbeef")) != keccak256(_wrapFlat(7, hex"deadbeef")),
            "the two encodings must differ"
        );
        // The struct encoding is exactly one word longer, and that word is the tuple offset.
        assertEq(_wrap(7, hex"deadbeef").length, _wrapFlat(7, hex"deadbeef").length + 0x20);
    }

    /*//////////////////////////////////////////////////////////////
                  ADDRESS OWNERS: CONTRACTS AND DIRTY WORDS
    //////////////////////////////////////////////////////////////*/

    /// @notice A CONTRACT registered as an address owner is refused, by design and now explicitly. Verifying
    ///         one chain-agnostically would mean recursing into its own signature scheme, and the obvious
    ///         route — its ERC-1271 — is the chain-bound construction this library exists to avoid. The
    ///         caller falls through to generic ERC-1271 against the wallet instead.
    function test_AddressOwner_ContractOwnerIsRefused() public {
        address contractOwner = address(new PermissiveFallbackContract());
        wallet.setAddressOwner(0, contractOwner);
        // A syntactically valid 65-byte signature, so the refusal is about the owner being a contract.
        (, uint256 pk) = makeAddrAndKey("whoever");
        (uint8 v, bytes32 r, bytes32 sVal) = vm.sign(pk, harness.digest(WALLET_ADDR, RAW_HASH));
        assertFalse(harness.validate(WALLET_ADDR, _wrap(0, abi.encodePacked(r, sVal, v)), RAW_HASH));
    }

    /// @notice An owner entry whose upper 96 bits are dirty is not a canonical `abi.encode(address)`.
    ///         `abi.decode` would REVERT on it; the library masks and rejects instead, because the entry is
    ///         data returned by an untrusted address and reverting would break the never-revert contract.
    function test_AddressOwner_DirtyWordIsRejectedWithoutReverting() public {
        address dirty = address(new DirtyAddressOwnerContract());
        assertTrue(harness.isCbsw(dirty), "probe should still route here");
        assertFalse(harness.validate(dirty, _wrap(0, new bytes(65)), RAW_HASH), "dirty owner word accepted");
    }
}
