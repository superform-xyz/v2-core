// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";

// Superform
import { SuperValidator } from "./SuperValidator.sol";
import { ChainAgnosticSafeSignatureValidation } from "../libraries/ChainAgnosticSafeSignatureValidation.sol";
import {
    ChainAgnosticCoinbaseSmartWalletValidation
} from "../libraries/ChainAgnosticCoinbaseSmartWalletValidation.sol";

/// @title SuperValidatorV2
/// @author Superform Labs
/// @notice `SuperValidator` plus chain-agnostic signature validation for a Coinbase Smart Wallet ("Base Smart
///         Wallet") owner, whose owners are passkeys rather than secp256k1 keys (SUP-17924).
/// @dev WHY A NEW CONTRACT RATHER THAN AN EDIT TO `SuperValidatorBase`. The capability belongs in the shared
///      base conceptually, but `SuperValidator` and `SuperDestinationValidator` both inherit that base and
///      both are deployed from locked bytecode. Any source change to the base re-pins BOTH of them, and the
///      CREATE2 salt is derived from the deploy NAME only —
///      `keccak256("SuperformV2" || namespace || name || "v2.0")` — not from the bytecode. So an in-place
///      edit cannot be redeployed at the live addresses: it would need a fresh deploy under a new name on
///      every chain anyway, and every account holding the old module would have to reinstall it. Adding a
///      new contract pays that same cost once, deliberately, while leaving the two deployed validators
///      byte-identical — which `ValidatorBytecodeUnchangedTest` asserts.
/// @dev V2 IS A SUPERSET OF V1, on purpose. Every signature V1 accepts, V2 accepts: EOA owners, EIP-7702
///      accounts, Safe owners via the chain-agnostic multisig path, and any other owner via generic
///      ERC-1271. It adds two things — a Coinbase Smart Wallet passkey path, and a legible error for a
///      counterfactual (codeless) contract owner instead of a revert inside `ECDSA.recover`. An account can
///      therefore install V2 alongside V1 and migrate intents across without a behavioural cliff.
/// @dev SIGNATURES DO NOT CROSS BETWEEN V1 AND V2, in both directions and by two independent mechanisms:
///      `SuperValidator._createLeaf` commits `address(this)` into every leaf, so a merkle proof built for one
///      validator address cannot verify against the other; and `_namespace()` is overridden here, so the
///      signed message hash (`keccak256(namespace, merkleRoot)`) differs too. Either alone would be
///      sufficient; both are asserted in the E2E suite.
contract SuperValidatorV2 is SuperValidator {
    using ChainAgnosticSafeSignatureValidation for address;
    using ChainAgnosticCoinbaseSmartWalletValidation for address;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Exact byte length of an `(r, s, v)` ECDSA signature
    /// @dev Used only to separate "owner is a plain EOA" from "owner is an undeployed contract account" when
    ///      the owner address has no code — see `_processSignatureForAccountType`.
    uint256 internal constant ECDSA_SIGNATURE_LENGTH = 65;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a CODELESS owner supplies a non-ECDSA-length signature
    /// @dev The counterfactual smart-wallet case. A Coinbase Smart Wallet's address is deterministic and
    ///      exists before its code does, so a passkey signature can arrive for an owner with no deployed
    ///      bytecode on this chain. There is nothing on-chain to verify it against yet — the owner set lives
    ///      in the undeployed wallet — so this fails with a legible error rather than reverting inside
    ///      `ECDSA.recover` on the signature length, which is the originally reported symptom ("the signature
    ///      is 600 characters … not valid for our bundler and contract"). The user's fix is to deploy the
    ///      wallet on this chain (any transaction) and retry.
    error UNDEPLOYED_CONTRACT_SIGNER();

    /// @notice Thrown when an intent carries destination execution, which this validator cannot yet serve
    /// @dev FAIL CLOSED, DELIBERATELY, because the alternative strands funds. The cross-chain flow works like
    ///      this: `SuperValidator.validateUserOp` stashes the signature in transient storage when
    ///      `chainsWithDestinationExecution` is non-empty, and a bridge hook later reads it back with
    ///      `ISuperSignatureStorage(VALIDATOR).retrieveSignatureData(account)` to forward into the
    ///      destination message. That `VALIDATOR` is an IMMUTABLE constructor argument, and all eleven
    ///      deployed bridge hooks were constructed with `SuperValidator`'s address.
    ///      So a V2-validated cross-chain intent would store its signature in V2's transient storage while
    ///      the hook read V1's — getting empty bytes, bridging the funds anyway, and leaving the destination
    ///      execution unauthorisable. Reverting here happens during VALIDATION, before anything moves.
    ///      Lifting this requires bridge hooks bound to V2's address, which is another set of deploy names
    ///      and another set of addresses — a separate decision, not a side effect of this validator.
    ///      Same-chain intents are unaffected, and so is the headline property: one passkey signature
    ///      authorising the same root independently on every chain needs no destination execution.
    error DESTINATION_EXECUTION_NOT_SUPPORTED();

    /*//////////////////////////////////////////////////////////////
                                INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the namespace identifier for this validator
    /// @dev Distinct from V1's `"SuperValidator"`, so the signed message hash differs and a V1 signature can
    ///      never be presented to V2 (or the reverse) even if the merkle leaf somehow matched.
    function _namespace() internal pure override returns (string memory) {
        return "SuperValidatorV2";
    }

    /// @notice Processes a signature for any account type, extended for passkey-owned smart wallets
    /// @dev Identical in structure to the base's, with two additions. Assumes the merkle proof has already
    ///      been verified by the caller.
    /// @param sender The account address being operated on
    /// @param sigData Signature data including merkle root, proofs, and actual signature
    /// @return signer The address that signed the message
    function _processSignatureForAccountType(
        address sender,
        SignatureData memory sigData
    )
        internal
        view
        override
        returns (address signer)
    {
        /// @dev Refused before any signature work, and before any execution: see
        ///      `DESTINATION_EXECUTION_NOT_SUPPORTED`. Placed here rather than in `validateUserOp` because
        ///      this is the one hook both entry points share, so neither `validateUserOp` nor
        ///      `isValidSignatureWithSender` can bypass it, and no change to `SuperValidator` is needed.
        if (sigData.chainsWithDestinationExecution.length != 0) {
            revert DESTINATION_EXECUTION_NOT_SUPPORTED();
        }

        /// @dev For EIP-7702 accounts, the signer is the account itself (EOA with delegated code)
        if (_is7702Account(sender.code)) {
            return _processECDSASignature(sigData);
        }

        address owner = _accountOwners[sender];

        /// @dev CODELESS IS NOT THE SAME AS "EOA", which is what the base assumes here. A Coinbase Smart
        ///      Wallet has a deterministic address but NO CODE on a chain until its first transaction there,
        ///      and its owners are passkeys — so a counterfactual one used to land on the ECDSA branch and
        ///      `ECDSA.recover` reverted on its ~300-byte WebAuthn signature. An ECDSA signature is exactly
        ///      65 bytes, so the length separates the two cases without needing a new storage flag: anything
        ///      else against a codeless owner is a contract-account signature that cannot be verified yet,
        ///      and it fails with a specific error instead of a cryptic ECDSA revert.
        if (owner.code.length == 0 || _is7702Account(owner.code)) {
            if (owner.code.length == 0 && sigData.signature.length != ECDSA_SIGNATURE_LENGTH) {
                revert UNDEPLOYED_CONTRACT_SIGNER();
            }
            return _processECDSASignature(sigData);
        }

        bytes32 messageHash = _createMessageHash(sigData.merkleRoot);

        /// @dev At this point the owner is a smart contract (not an EOA, not EIP-7702). The two
        ///      chain-agnostic paths are tried first, then generic ERC-1271. Both chain-agnostic paths exist
        ///      because the respective wallets' NATIVE ERC-1271 binds `chainId` into its digest (and, for the
        ///      Coinbase wallet, the wallet address too), which would defeat one-signature-many-chains — the
        ///      entire point of the merkle design.
        /// @dev THE TWO FAMILIES ARE ROUTED, NOT CHAINED, and that is a correctness requirement rather than an
        ///      optimisation. `ChainAgnosticSafeSignatureValidation`'s probe is
        ///      `try ISafeConfiguration(owner).getOwners() returns (address[] memory)`, and the ABI decode of
        ///      that return happens in THIS frame after the try succeeds — so against a target that returns
        ///      no data the decode reverts where `catch` cannot see it. A Coinbase Smart Wallet is exactly
        ///      such a target: it has a permissive fallback that returns `0x` for unknown selectors. Running
        ///      the Safe probe against one would therefore revert the whole validation instead of returning
        ///      false. Detecting the family first — with a probe that is a low-level `staticcall` and so can
        ///      actually report "not mine" — keeps each wallet type away from the other's probe.
        if (owner.isCoinbaseSmartWallet()) {
            if (owner.validateChainAgnosticPasskey(sigData, messageHash)) {
                return owner;
            }
        } else if (owner.validateChainAgnosticMultisig(sigData, messageHash)) {
            return owner;
        }

        /// @dev Generic ERC-1271, reached by every owner family. For a Coinbase Smart Wallet this is the
        ///      chain-BOUND fallback: it accepts a signature over the wallet's own `replaySafeHash`, valid on
        ///      one chain only. Keeping it reachable is what makes V2 a superset of V1 rather than a
        ///      different validator — nothing that worked before stops working.
        /// @dev A low-level `staticcall` rather than `try IERC1271(owner).isValidSignature(...)`, for the same
        ///      reason the family probe above is one: with `try`, the ABI decode of the `bytes4` return
        ///      happens in THIS frame after the call succeeds, so an owner that returns no data makes the
        ///      decode revert WITHOUT DATA where `catch` cannot see it. Any contract with a permissive
        ///      fallback is such an owner, a Coinbase Smart Wallet included. The E2E suite caught exactly
        ///      that: a wallet whose chain-agnostic passkey check failed reverted dataless here instead of
        ///      with `NOT_EIP1271_SIGNER`, which is indistinguishable from out-of-gas to a bundler. The
        ///      returned word is read without `abi.decode`, which would itself revert on a `bytes4` whose
        ///      low 28 bytes are not zero.
        (bool answered, bytes memory returned) =
            owner.staticcall(abi.encodeCall(IERC1271.isValidSignature, (messageHash, sigData.signature)));
        if (answered && returned.length == 32) {
            bytes4 result;
            assembly ("memory-safe") {
                result := mload(add(returned, 0x20))
            }
            if (result == EIP1271_MAGIC_VALUE) {
                return owner;
            }
        }

        revert NOT_EIP1271_SIGNER();
    }
}
