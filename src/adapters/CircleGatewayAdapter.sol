// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External Dependencies
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Circle Gateway libraries (vendored submodule; all `internal`, inlined — no linking)
import { TypedMemView } from "@memview-sol/TypedMemView.sol";
import { AttestationLib } from "evm-gateway/lib/AttestationLib.sol";
import { TransferSpecLib } from "evm-gateway/lib/TransferSpecLib.sol";
import { AddressLib } from "evm-gateway/lib/AddressLib.sol";
import { Cursor } from "evm-gateway/lib/Cursor.sol";

// Vendor Interfaces
import { IGatewayMinter } from "../vendor/bridges/circle/IGatewayMinter.sol";

// Superform Interfaces
import { ISuperDestinationExecutor } from "../interfaces/ISuperDestinationExecutor.sol";
import { ISuperValidator } from "../interfaces/ISuperValidator.sol";

/// @notice Minimal getter for the executor's wired validator
/// @dev Kept local so the shared ISuperDestinationExecutor interface (compiled into locked-bytecode
///      deployed contracts) stays untouched; SuperDestinationExecutor exposes this as a public immutable
interface IDestinationValidatorSource {
    function SUPER_DESTINATION_VALIDATOR() external view returns (address);
}

/// @title CircleGatewayAdapter
/// @author Superform Labs
/// @notice Destination-side adapter that completes a Superform intent funded through Circle Gateway (the unified
///         USDC balance product — NOT CCTP).
/// @notice The user (or a Gateway delegate) signs a `TransferSpec` off-chain with `destinationRecipient =
///         destinationCaller = this adapter` and the Superform payload in `hookData =
///         abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts, sigData)`; Circle attests it.
/// @dev Structural difference from every other Superform adapter except CCTPAdapter: Gateway has NO push callback.
///      `GatewayMinter.gatewayMint` only mints to `destinationRecipient`; it never forwards `hookData`. So this
///      adapter is PULL-driven — a relayer calls `receiveAndExecute(payload, signature)`, the adapter calls
///      `gatewayMint` itself, then acts on the payload it parsed from the same attested bytes.
/// @dev PERMISSIONLESS: anyone can call `receiveAndExecute`. Safety is anchored by:
///      1. Circle's attestation signature covering the entire payload (incl. `account` and `hookData`); every
///         attestation is value-backed by a Circle-verified deposit, so there is no forged-message primitive.
///      2. `destinationCaller = adapter` (enforced by the minter when non-zero) keeping mint + execution atomic.
///      3. The executor's own EIP-1271 signature + merkle-root replay checks for the hook execution leg.
///      4. The minter's one-shot TransferSpec hash: this adapter keeps NO delivery slot a third party could
///         pre-consume (`processed[hash]` flips only after a Circle-signed mint of that exact spec).
/// @dev Failure model (differs from CCTP): the source-side burn happens only AFTER a successful `gatewayMint`, and
///      an attestation that expires unused (~10 minutes, `maxBlockHeight`) restores the depositor's balance. A
///      revert BEFORE the mint therefore costs the user a retry, not funds — so every content problem (routing,
///      token, undecodable hookData, bad account, mixed set) is rejected pre-mint. After the mint nothing reverts
///      on content: delivery failure escrows to the account, execution failure is caught.
/// @dev Accepted residual (review R2): the pre-mint guarantee does not extend to specs a third party mints
///      DIRECTLY into this adapter (possible only when the spec is not pinned to this adapter). If such a spec's
///      hookData is unusable (undecodable, account 0 / this) or its token is not USDC, `recoverDirectMint` can
///      never attribute it and its value stays in this ownerless, immutable contract. Self-inflicted by
///      construction: the SDK always pins `destinationCaller = adapter`, which makes the direct-mint path
///      unreachable, and only the depositor authors hookData.
/// @dev Donation-proof: forwards only the measured `gatewayMint` balance delta (`post - pre`, equal to the sum of
///      the specs' `value`), never `balanceOf(this)`. Stray mints (zero or third-party `destinationCaller`) that
/// bypassed this adapter are forwarded only through `recoverDirectMint`, which requires the minter's own used-hash
/// record for that
///      exact spec (a used hash proves Circle signed and minted byte-identical routing, `hookData` included).
contract CircleGatewayAdapter is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using TypedMemView for bytes29;
    using TransferSpecLib for bytes29;
    using AttestationLib for bytes29;
    using AttestationLib for Cursor;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Minimum gas that must remain before the executor call.
    /// @dev `receiveAndExecute()` is permissionless, so the caller chooses the gas limit. Without a floor a griefer
    ///      can supply just enough gas for `gatewayMint` + the transfer to succeed while starving the executor call
    ///      under EIP-150's 63/64 rule, forcing the `catch` branch. Reverting here instead unwinds the mint
    ///      entirely (hash unused, attestation still valid), leaving the payload retriable with enough gas.
    /// @dev Deliberately a floor and NOT a `{gas: N}` stipend — a stipend would cap legitimate long hook chains.
    /// @dev Starvation PAST the floor is a delay, not a loss: the USDC is at the account, the merkle root stays
    ///      unused on revert and the payload is public, so anyone can re-drive
    ///      `SuperDestinationExecutor.processBridgedExecution` directly until the signature's validUntil.
    /// @dev Same calibration as CCTPAdapter (realistic maximum ~660k for a cap-validated SuperVault deposit plus a
    ///      first-time CREATE2 account; conservatively high because unused gas is refunded).
    uint256 private constant MIN_EXECUTION_GAS = 2_000_000;

    /// @dev `MisconfiguredMessageRelayed.kind`: the spec(s) had `destinationCaller = 0` (any caller could have
    ///      minted them straight into this adapter); relayed and delivered normally.
    uint8 private constant MISCONFIG_UNPINNED = 1;
    /// @dev `MisconfiguredMessageRelayed.kind`: pinned to this adapter but minting elsewhere; passed through to the
    ///      minter and Circle minted to the spec's own `destinationRecipient`.
    uint8 private constant MISCONFIG_MINT_ELSEWHERE = 2;

    /// @dev Returned by `checkDestinationTargets` when the DstProof for this chain targets this deployment, or when
    ///      no DstProof names this chain at all.
    uint8 private constant MATCH_OK = 0;
    /// @dev Returned when the DstProof names an executor other than SUPER_DESTINATION_EXECUTOR.
    uint8 private constant MISMATCH_EXECUTOR = 1;
    /// @dev Returned when the DstProof names a validator other than SUPER_DESTINATION_VALIDATOR.
    uint8 private constant MISMATCH_VALIDATOR = 2;

    /// @notice Decoded hookData payload — the 6-tuple the SDK packs (same shape CCTPAdapter/DebridgeAdapter decode)
    struct HookPayload {
        /// @dev Account init calldata (SuperSenderCreator-prefixed); empty when the account already exists
        bytes initData;
        /// @dev Encoded SuperExecutor entry forwarded to SuperDestinationExecutor
        bytes executorCalldata;
        /// @dev The smart account that receives the USDC and the execution
        address account;
        /// @dev Tokens the intent expects on this chain (executor balance-gate keys)
        address[] dstTokens;
        /// @dev MINIMUM balances the executor requires per dstToken before executing
        uint256[] intentAmounts;
        /// @dev Raw SignatureData blob, forwarded byte-identical so validator signatures stay valid
        bytes sigData;
    }

    /// @notice The routing-relevant content of an attestation payload, homogeneous across all member specs
    /// @dev Produced by `_parse` from the same bytes the minter will validate; every field is attested.
    struct Parsed {
        /// @dev Sum of `value` over all member specs (Gateway mints exactly `value` per spec; no destination fee)
        uint256 totalValue;
        /// @dev `destinationCaller` shared by all members (validated against this adapter / zero only in
        ///      `receiveAndExecute`; `recoverDirectMint` accepts any non-adapter caller)
        address destinationCaller;
        /// @dev `destinationRecipient` shared by all members
        address destinationRecipient;
        /// @dev `destinationToken` shared by all members
        address destinationToken;
        /// @dev `hookData` shared (byte-identical) by all members
        bytes hookData;
        /// @dev keccak256 of each member's encoded TransferSpec — the minter's replay key (`AttestationUsed`).
        ///      Unique within the payload (`ATTESTATION_SET_DUPLICATE` otherwise).
        bytes32[] specHashes;
        /// @dev Each member's attested `value`, index-aligned with `specHashes`
        uint256[] values;
    }

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The Circle Gateway minter on this chain (UUPS proxy, same address on every chain)
    IGatewayMinter public immutable GATEWAY_MINTER;

    /// @notice The USDC token Gateway mints on this chain (the only token this adapter delivers)
    IERC20 public immutable USDC;

    /// @notice The SuperDestinationExecutor for processing bridged executions
    ISuperDestinationExecutor public immutable SUPER_DESTINATION_EXECUTOR;

    /// @notice The destination validator wired into the executor, cached at construction
    address public immutable SUPER_DESTINATION_VALIDATOR;

    /// @notice Claimable escrow balances (failed delivery or over-mint surplus): account => token => amount
    mapping(address account => mapping(address token => uint256 amount)) public failedTransfers;

    /// @notice Total escrowed per token, so `recoverDirectMint` never forwards escrowed funds
    mapping(address token => uint256 amount) public totalEscrowed;

    /// @notice TransferSpec hashes this adapter has already attributed (relayed or recovered)
    /// @dev Set only after a Circle-signed mint of that exact spec succeeded — in-tx by `receiveAndExecute`, or
    ///      verified post-hoc by `recoverDirectMint` against the minter's own used-hash record. No third party can
    ///      flip it ahead of the real relay, so it is not a griefable delivery slot.
    mapping(bytes32 specHash => bool processed) public processed;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a constructor argument is the zero address
    error ADDRESS_NOT_VALID();

    /// @notice Thrown when `gatewayMinter_` has no code or does not support `usdc_`
    /// @dev Binds the deployment: a wrong-but-populated address cannot deploy an adapter that reverts on every relay.
    ///      Deliberately does NOT require `domain() != 0` — Ethereum's Gateway domain is 0.
    error GATEWAY_MINTER_NOT_VALID();

    /// @notice Thrown when the members of an AttestationSet differ in caller, recipient, token or hookData
    /// @dev A set is minted atomically by the minter; the adapter delivers and executes it once, so its routing
    ///      must be one routing. The SDK must submit homogeneous sets or one intent per source chain.
    error ATTESTATION_SET_MIXED();

    /// @notice Thrown when an AttestationSet has no members
    /// @dev The minter rejects it too (`MustHaveAtLeastOneAttestation`); named here so the reason is legible
    ///      instead of an incidental `DESTINATION_RECIPIENT_MISMATCH` on a zeroed parse.
    error ATTESTATION_SET_EMPTY();

    /// @notice Thrown when the same TransferSpec appears twice in one payload
    /// @dev The minter rejects such a set itself (it marks hashes as it iterates); `recoverDirectMint` does not go
    ///      through the minter, so the adapter must not be weaker on the same bytes (review R1-F1).
    error ATTESTATION_SET_DUPLICATE();

    /// @notice Thrown when a spec names a `destinationContract` other than GATEWAY_MINTER
    error DESTINATION_CONTRACT_MISMATCH();

    /// @notice Thrown when a spec names a `destinationDomain` other than this chain's Gateway domain
    error DESTINATION_DOMAIN_MISMATCH();

    /// @notice Thrown when `destinationCaller` is neither this adapter nor zero
    /// @dev Zero is accepted: rejecting it cannot prevent a direct `gatewayMint` and would only remove the honest
    ///      relayer's chance to deliver first (CCTPAdapter review F1).
    error DESTINATION_CALLER_MISMATCH();

    /// @notice Thrown when the specs mint elsewhere: in `receiveAndExecute` only when also not pinned to this
    ///         adapter (pinned ones are passed through, CCTPAdapter review F2); in `recoverDirectMint` always
    error DESTINATION_RECIPIENT_MISMATCH();

    /// @notice Thrown when `destinationToken` is not USDC
    /// @dev In `receiveAndExecute` this is pre-mint (the attestation expires and the depositor's balance is
    ///      restored). In `recoverDirectMint` it means a directly-minted non-USDC spec cannot be attributed — see
    ///      the contract-level accepted residual.
    error UNSUPPORTED_DESTINATION_TOKEN();

    /// @notice Thrown when a spec's `value` is zero (the minter would reject it too; fail early)
    error ZERO_VALUE();

    /// @notice Thrown when hookData does not decode to the 6-tuple, or names account 0 or this adapter
    /// @dev In `receiveAndExecute` this is pre-mint: the user only loses the attestation, not funds (contrast
    ///      CCTPAdapter, which must escrow). In `recoverDirectMint` the USDC was already minted into this adapter
    ///      by a direct `gatewayMint`; a spec with unusable hookData can never be attributed and its value stays
    ///      here permanently — see the contract-level accepted residual.
    error HOOK_PAYLOAD_INVALID();

    /// @notice Thrown when `gatewayMint` succeeded but no USDC reached this adapter
    /// @dev Backstop: unreachable with the real minter (it mints exactly `value`); unwinds the mint if a mint
    ///      authority ever returns without minting (`Mints._mint` ignores the bool return).
    error NOTHING_MINTED();

    /// @notice Thrown when insufficient gas remains to attempt the destination execution
    error INSUFFICIENT_GAS();

    /// @notice Thrown when a self-call helper is called by anyone other than this contract
    error INVALID_SENDER();

    /// @notice Thrown when the claim amount is zero
    error ZERO_AMOUNT();

    /// @notice Thrown when claiming more than the available escrow balance
    error INSUFFICIENT_FAILED_BALANCE();

    /// @notice Thrown by `recoverDirectMint` when a member spec has not been minted by the minter
    error SPEC_NOT_MINTED();

    /// @notice Thrown by `recoverDirectMint` when a member spec was already attributed (relayed or recovered)
    error SPEC_ALREADY_PROCESSED();

    /// @notice Thrown by `recoverDirectMint` when the non-escrowed USDC balance cannot cover the specs' value
    /// @dev Never partially forwards; every stray mint's USDC is accounted for, so this only fires on a bug or a
    ///      claim race, and the call can simply be retried.
    error INSUFFICIENT_RECOVERABLE();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the minted USDC is transferred to the account
    event TransferSucceeded(address indexed account, address indexed token, uint256 amount);

    /// @notice Emitted whenever a balance is credited to `failedTransfers[account][token]`
    /// @dev Fires on EVERY escrow credit (failed delivery and over-mint surplus) so generic escrow tooling sees all.
    event TransferFailed(address indexed account, address indexed token, uint256 amount);

    /// @notice Emitted when tokens were delivered but the executor call reverted
    /// @param account The intent account (funds are already delivered or escrowed to it)
    /// @param selector First 4 bytes of the revert data, or zero when the executor reverted with no data (OOG)
    /// @dev Only the bounded 4-byte selector is copied out of returndata (returnbomb-safe). A normal return from
    ///      `processBridgedExecution` is NOT proof of execution: it returns normally on three silent no-op paths
    ///      (insufficient balance, already-used root, empty hook calldata), each emitting its own executor event.
    event ExecutionFailed(address indexed account, bytes4 selector);

    /// @notice Emitted when the signed DstProof for this chain names a different executor/validator
    /// @dev Funds are still delivered; only the destination execution is skipped.
    /// @param account The intent account the funds were delivered (or escrowed) to
    /// @param code MISMATCH_EXECUTOR (1) or MISMATCH_VALIDATOR (2)
    event DestinationTargetMismatch(address indexed account, uint8 code);

    /// @notice Emitted when a payload the SDK should never have produced was still relayed safely
    /// @param kind MISCONFIG_UNPINNED (1) or MISCONFIG_MINT_ELSEWHERE (2)
    /// @param destinationRecipient The specs' recipient (this adapter for kind 1, the real recipient for kind 2)
    event MisconfiguredMessageRelayed(uint8 indexed kind, address destinationRecipient);

    /// @notice Emitted once per member spec when its value has been attributed by this adapter
    /// @param specHash keccak256 of the encoded TransferSpec (== the minter's `AttestationUsed.transferSpecHash`)
    /// @param account The intent account credited
    /// @param value The member's attested `value` (the delivered total, carried by `TransferSucceeded` /
    ///              `TransferFailed`, can be lower on an anomalous under-mint)
    /// @param recovered false for `receiveAndExecute`, true for `recoverDirectMint`
    event SpecProcessed(bytes32 indexed specHash, address indexed account, uint256 value, bool recovered);

    /// @notice Emitted when a recipient claims a previously escrowed balance
    event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param gatewayMinter_ Circle Gateway minter on this chain
    /// @param usdc_ USDC token on this chain (must be minter-supported)
    /// @param superDestinationExecutor_ SuperDestinationExecutor on this chain
    constructor(address gatewayMinter_, address usdc_, address superDestinationExecutor_) {
        if (gatewayMinter_ == address(0) || usdc_ == address(0) || superDestinationExecutor_ == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        // Liveness + wiring: a real, initialized minter that mints this USDC. `domain()` is NOT required to be
        // non-zero (Ethereum is domain 0).
        if (gatewayMinter_.code.length == 0 || !IGatewayMinter(gatewayMinter_).isTokenSupported(usdc_)) {
            revert GATEWAY_MINTER_NOT_VALID();
        }
        GATEWAY_MINTER = IGatewayMinter(gatewayMinter_);
        USDC = IERC20(usdc_);
        SUPER_DESTINATION_EXECUTOR = ISuperDestinationExecutor(superDestinationExecutor_);
        SUPER_DESTINATION_VALIDATOR =
            IDestinationValidatorSource(superDestinationExecutor_).SUPER_DESTINATION_VALIDATOR();
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE + EXECUTE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mints the attested USDC through Circle Gateway, forwards it to the intent account and best-effort
    ///         executes the signed destination intent.
    /// @dev PERMISSIONLESS — see contract-level NatSpec. Every content check runs BEFORE `gatewayMint`; a revert
    ///      there leaves the TransferSpec hash unused, the attestation expires and the balance is restored.
    /// @dev A homogeneous AttestationSet (identical caller/recipient/token/hookData across members) is minted in
    ///      one `gatewayMint`, delivered once and executed once. Mixed sets are rejected.
    /// @param attestationPayload The raw Attestation or AttestationSet bytes exactly as Circle attested them
    /// @param signature Circle's EIP-191 signature over keccak256(attestationPayload)
    function receiveAndExecute(bytes calldata attestationPayload, bytes calldata signature) external nonReentrant {
        // 1. Parse + fail fast. `_parse` validates the structure with the minter's own libraries and enforces
        //    contract / domain / value / homogeneity; caller and recipient rules follow here.
        Parsed memory parsed = _parse(attestationPayload);
        if (parsed.destinationCaller != address(this) && parsed.destinationCaller != address(0)) {
            revert DESTINATION_CALLER_MISMATCH();
        }
        if (parsed.destinationRecipient != address(this)) {
            // Minting elsewhere is not ours to relay — unless the specs are PINNED to us, in which case nobody
            // else can ever mint them. Pass through: Circle mints to their own recipient, our balances are
            // untouched (CCTPAdapter review F2).
            if (parsed.destinationCaller != address(this)) revert DESTINATION_RECIPIENT_MISMATCH();
            GATEWAY_MINTER.gatewayMint(attestationPayload, signature);
            emit MisconfiguredMessageRelayed(MISCONFIG_MINT_ELSEWHERE, parsed.destinationRecipient);
            return;
        }
        if (parsed.destinationToken != address(USDC)) revert UNSUPPORTED_DESTINATION_TOKEN();

        // 2. Decode the executor payload BEFORE minting. Isolated behind a self-call so a malformed 6-tuple is a
        //    clean revert rather than a panic; the revert is safe here (nothing minted yet).
        HookPayload memory p = _decodeOrRevert(parsed.hookData);

        // 3. Mint and measure. Gateway mints exactly `value` per spec; measure anyway so a donated or escrowed
        //    balance is never forwardable and an under-mint never over-promises the account.
        uint256 pre = USDC.balanceOf(address(this));
        GATEWAY_MINTER.gatewayMint(attestationPayload, signature);
        uint256 minted = USDC.balanceOf(address(this)) - pre;
        uint256 surplus;
        if (parsed.totalValue < minted) {
            unchecked {
                // Safe: guarded by `parsed.totalValue < minted` immediately above.
                surplus = minted - parsed.totalValue;
            }
            minted = parsed.totalValue;
        }
        if (minted == 0) revert NOTHING_MINTED();

        // From here on nothing reverts on content: the specs are consumed on the minter.
        if (parsed.destinationCaller == address(0)) {
            emit MisconfiguredMessageRelayed(MISCONFIG_UNPINNED, address(this));
        }
        _deliverAndExecute(p, parsed, minted, surplus, false);
    }

    /// @notice Attributes USDC that a spec NOT pinned to this adapter (zero or third-party `destinationCaller`)
    ///         minted straight into this adapter without going through `receiveAndExecute` (someone called
    ///         `gatewayMint` directly), forwarding it and executing the intent exactly as the relay would have.
    /// @dev PERMISSIONLESS and signature-free. The minter's own `isTransferSpecHashUsed(keccak256(spec))` is a
    ///      strictly stronger witness than a signature check: the hash is written only inside `gatewayMint`,
    ///      after Circle's signature was verified, and it binds recipient, token, value, `hookData` (so the
    ///      `account`) and salt byte-for-byte. Re-verifying the signer here would add nothing and would strand
    ///      the funds forever once Circle rotates its attestation signer (review R1-F2). Every member must be used
    ///      by the minter and not yet attributed here; only the non-escrowed balance is ever forwarded, never
    ///      partially. A payload reconstructed from the public direct-mint calldata is sufficient.
    /// @param attestationPayload An Attestation or AttestationSet whose member specs were minted (the outer
    ///        `maxBlockHeight` is irrelevant here; only the specs are read)
    function recoverDirectMint(bytes calldata attestationPayload) external nonReentrant {
        Parsed memory parsed = _parse(attestationPayload);
        // Only specs that mint INTO this adapter can have stranded funds here. `destinationCaller` is deliberately
        // not checked: a spec pinned to this adapter can only have been minted via `receiveAndExecute` (already
        // `processed`), so anything reaching here was minted by a zero or third-party caller.
        if (parsed.destinationRecipient != address(this)) revert DESTINATION_RECIPIENT_MISMATCH();
        if (parsed.destinationToken != address(USDC)) revert UNSUPPORTED_DESTINATION_TOKEN();
        HookPayload memory p = _decodeOrRevert(parsed.hookData);

        uint256 len = parsed.specHashes.length;
        for (uint256 i; i < len; ++i) {
            bytes32 h = parsed.specHashes[i];
            if (!GATEWAY_MINTER.isTransferSpecHashUsed(h)) revert SPEC_NOT_MINTED();
            if (processed[h]) revert SPEC_ALREADY_PROCESSED();
        }
        uint256 spendable = USDC.balanceOf(address(this)) - totalEscrowed[address(USDC)];
        if (parsed.totalValue > spendable) revert INSUFFICIENT_RECOVERABLE();

        _deliverAndExecute(p, parsed, parsed.totalValue, 0, true);
    }

    /// @notice Decode the 6-tuple hookData.
    /// @dev External ONLY so the entrypoints can self-call it and contain `abi.decode` panics on a malformed tail.
    ///      MUST only be called by this contract.
    /// @param hookData The TransferSpec hookData bytes
    /// @return p The decoded payload
    function decodeHookPayload(bytes calldata hookData) external view returns (HookPayload memory p) {
        if (msg.sender != address(this)) revert INVALID_SENDER();
        (p.initData, p.executorCalldata, p.account, p.dstTokens, p.intentAmounts, p.sigData) =
            abi.decode(hookData, (bytes, bytes, address, address[], uint256[], bytes));
    }

    /// @notice Report whether the DstProof for this chain targets this deployment's executor/validator.
    /// @dev External ONLY so the entrypoints can self-call it and contain `abi.decode` panics on a malformed
    ///      `sigData`. Returns a code rather than reverting so the caller can distinguish "malformed blob"
    ///      (caught, treated as MATCH_OK) from "explicit mismatch" (funds delivered, execution skipped).
    ///      MUST only be called by this contract.
    /// @param sigData The raw SignatureData blob from the hookData
    /// @return code MATCH_OK when the proof matches or no proof exists for this chain
    function checkDestinationTargets(bytes calldata sigData) external view returns (uint8 code) {
        if (msg.sender != address(this)) revert INVALID_SENDER();
        if (sigData.length == 0) return MATCH_OK;
        (,,,,, ISuperValidator.DstProof[] memory proofDst,) =
            abi.decode(sigData, (uint64[], uint48, uint48, bytes32, bytes32[], ISuperValidator.DstProof[], bytes));
        uint64 currentChain = uint64(block.chainid);
        uint256 len = proofDst.length;
        for (uint256 i; i < len; ++i) {
            if (proofDst[i].dstChainId == currentChain) {
                if (proofDst[i].info.executor != address(SUPER_DESTINATION_EXECUTOR)) return MISMATCH_EXECUTOR;
                if (proofDst[i].info.validator != SUPER_DESTINATION_VALIDATOR) return MISMATCH_VALIDATOR;
                return MATCH_OK;
            }
        }
        return MATCH_OK;
    }

    /*//////////////////////////////////////////////////////////////
                                 CLAIM
    //////////////////////////////////////////////////////////////*/

    /// @notice Claim a previously escrowed balance. Only the recipient can claim its own.
    /// @param token The token to claim (USDC)
    /// @param amount The amount to claim
    function claimFailedTransfer(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZERO_AMOUNT();
        uint256 available = failedTransfers[msg.sender][token];
        if (available < amount) revert INSUFFICIENT_FAILED_BALANCE();
        failedTransfers[msg.sender][token] = available - amount;
        totalEscrowed[token] -= amount;
        IERC20(token).safeTransfer(msg.sender, amount);
        emit FailedTransferClaimed(msg.sender, token, amount);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Parse an Attestation or AttestationSet with the minter's own libraries and enforce the checks that
    ///         do not depend on who is calling.
    /// @dev `AttestationLib.cursor` is exactly the structural validation `gatewayMint` runs (magics, lengths,
    ///      version), so anything that passes here passes there — no parser differential. Per member:
    ///      `destinationContract == GATEWAY_MINTER`, `destinationDomain == domain()`, `value != 0`; across
    ///      members: identical caller, recipient, token and hookData (`ATTESTATION_SET_MIXED` otherwise).
    ///      Addresses are compared truncated (low 20 bytes), exactly as the minter compares them.
    ///      Duplicate members are rejected (`ATTESTATION_SET_DUPLICATE`), matching the minter's mark-as-you-go.
    /// @param attestationPayload The raw payload (copied to memory once; every view points into that copy)
    /// @return parsed The homogeneous routing content plus every member's spec hash and value
    function _parse(bytes calldata attestationPayload) internal view returns (Parsed memory parsed) {
        bytes memory payload = attestationPayload;
        Cursor memory cursor = AttestationLib.cursor(payload);
        if (cursor.numElements == 0) revert ATTESTATION_SET_EMPTY();
        uint32 localDomain = GATEWAY_MINTER.domain();
        parsed.specHashes = new bytes32[](cursor.numElements);
        parsed.values = new uint256[](cursor.numElements);
        bytes32 hookDataHash;
        while (!cursor.done) {
            uint256 i = cursor.index;
            bytes29 spec = cursor.next().getTransferSpec();

            if (AddressLib._bytes32ToAddress(spec.getDestinationContract()) != address(GATEWAY_MINTER)) {
                revert DESTINATION_CONTRACT_MISMATCH();
            }
            if (spec.getDestinationDomain() != localDomain) revert DESTINATION_DOMAIN_MISMATCH();
            uint256 value = spec.getValue();
            if (value == 0) revert ZERO_VALUE();

            address caller = AddressLib._bytes32ToAddress(spec.getDestinationCaller());
            address recipient = AddressLib._bytes32ToAddress(spec.getDestinationRecipient());
            address token = AddressLib._bytes32ToAddress(spec.getDestinationToken());
            bytes29 hookDataView = spec.getHookData();

            if (i == 0) {
                parsed.destinationCaller = caller;
                parsed.destinationRecipient = recipient;
                parsed.destinationToken = token;
                parsed.hookData = _viewToBytes(hookDataView);
                hookDataHash = keccak256(parsed.hookData);
            } else if (
                caller != parsed.destinationCaller || recipient != parsed.destinationRecipient
                    || token != parsed.destinationToken || hookDataView.keccak() != hookDataHash
            ) {
                revert ATTESTATION_SET_MIXED();
            }
            bytes32 specHash = spec.getHash();
            for (uint256 j; j < i; ++j) {
                if (parsed.specHashes[j] == specHash) revert ATTESTATION_SET_DUPLICATE();
            }
            parsed.totalValue += value;
            parsed.specHashes[i] = specHash;
            parsed.values[i] = value;
        }
    }

    /// @notice Decode the 6-tuple pre-mint, reverting cleanly on anything unusable.
    /// @dev Self-call isolates the `abi.decode` panic; `account == 0` cannot be delivered to and
    ///      `account == address(this)` would "succeed" as a self-transfer and strand the funds.
    /// @param hookData The TransferSpec hookData shared by all members
    /// @return p The decoded payload with a usable `account`
    function _decodeOrRevert(bytes memory hookData) internal view returns (HookPayload memory p) {
        try this.decodeHookPayload(hookData) returns (HookPayload memory d) {
            p = d;
        } catch {
            revert HOOK_PAYLOAD_INVALID();
        }
        if (p.account == address(0) || p.account == address(this)) revert HOOK_PAYLOAD_INVALID();
    }

    /// @notice Shared post-mint tail: attribute the specs, credit surplus, deliver, and best-effort execute.
    /// @dev Nothing here reverts on content — the specs are already consumed on the minter. Only the gas floor
    ///      reverts, and it unwinds the whole relay (hash unused) rather than consuming it half-done.
    /// @param p The decoded hookData payload
    /// @param parsed The parsed, homogeneous routing content of the attested payload
    /// @param minted USDC to deliver (the measured mint delta, clamped to `parsed.totalValue`)
    /// @param surplus Over-mint above `parsed.totalValue`, escrowed to the account
    /// @param recovered false from `receiveAndExecute`, true from `recoverDirectMint`
    function _deliverAndExecute(
        HookPayload memory p,
        Parsed memory parsed,
        uint256 minted,
        uint256 surplus,
        bool recovered
    )
        internal
    {
        address account = p.account;
        uint256 len = parsed.specHashes.length;
        for (uint256 i; i < len; ++i) {
            bytes32 h = parsed.specHashes[i];
            processed[h] = true;
            emit SpecProcessed(h, account, parsed.values[i], recovered);
        }

        // Over-mint surplus (anomalous) is credited to the account rather than retained.
        if (surplus != 0) {
            failedTransfers[account][address(USDC)] += surplus;
            totalEscrowed[address(USDC)] += surplus;
            emit TransferFailed(account, address(USDC), surplus);
        }

        // If the signed intent carries a DstProof for this chain, it must name THIS executor and validator; a
        // mismatch means it was signed for another deployment, so only the execution is skipped — funds are still
        // delivered. Decode isolated behind a self-call; a malformed blob is treated as MATCH_OK (the executor's
        // own signature check then fails harmlessly).
        bool targetsMatch = true;
        try this.checkDestinationTargets(p.sigData) returns (uint8 code) {
            if (code != MATCH_OK) {
                targetsMatch = false;
                emit DestinationTargetMismatch(account, code);
            }
        } catch {
            // undecodable sigData: nothing to assert
        }

        // Fund the account first (so the executor can check its balance), escrowing on failure.
        if (_tryTransfer(account, minted)) {
            emit TransferSucceeded(account, address(USDC), minted);
        } else {
            failedTransfers[account][address(USDC)] += minted;
            totalEscrowed[address(USDC)] += minted;
            emit TransferFailed(account, address(USDC), minted);
        }
        if (!targetsMatch) return;
        if (gasleft() < MIN_EXECUTION_GAS) revert INSUFFICIENT_GAS();

        // Bare catch → the full revert returndata is never copied (returnbomb-safe); only the 4-byte selector is
        // read for observability. The execution stays re-drivable directly on the executor.
        try SUPER_DESTINATION_EXECUTOR.processBridgedExecution(
            address(USDC), account, p.dstTokens, p.intentAmounts, p.initData, p.executorCalldata, p.sigData
        ) { }
        catch {
            bytes4 selector;
            assembly ("memory-safe") {
                if gt(returndatasize(), 3) {
                    mstore(0, 0)
                    returndatacopy(0, 0, 4)
                    selector := mload(0)
                }
            }
            emit ExecutionFailed(account, selector);
        }
    }

    /// @notice Attempt to transfer USDC to an account, returning success/failure instead of reverting.
    /// @dev Low-level call handles non-standard ERC20s that don't return a bool.
    /// @param account The recipient
    /// @param amount The amount of USDC
    /// @return success True iff the token reported (or implied) a successful transfer
    function _tryTransfer(address account, uint256 amount) internal returns (bool success) {
        (bool callSuccess, bytes memory returnData) =
            address(USDC).call(abi.encodeCall(IERC20.transfer, (account, amount)));
        // NOT abi.decode(returnData,(bool)): the ABI decoder PANICS on a 32-byte word that is not 0 or 1, so a
        // length guard alone cannot keep this helper from reverting. Read the raw word instead.
        success = callSuccess && (returnData.length == 0 || (returnData.length >= 32 && _isTrueWord(returnData)));
    }

    /// @dev True iff the first 32-byte word of `data` equals exactly 1.
    /// @param data Return data of at least 32 bytes
    /// @return isTrue Whether the word is exactly 1
    function _isTrueWord(bytes memory data) internal pure returns (bool isTrue) {
        bytes32 word;
        assembly ("memory-safe") {
            word := mload(add(data, 32))
        }
        return word == bytes32(uint256(1));
    }

    /// @dev Word-aligned copy of a memview slice into `bytes memory`. Preferred over `TypedMemView.clone`: `mcopy`
    ///      (Cancun+) is cheaper than clone's identity-precompile staticcall and, unlike clone, this rounds the
    ///      free-memory pointer up to a 32-byte boundary. Reads only inside `v`, writes only fresh memory. The
    ///      library paths used here (`cursor`, `getHash`/`keccak`) only allocate through solc (the `Cursor`
    ///      struct) and otherwise only read, so the free-memory pointer is never left stale (verified against
    ///      memview-sol at the vendored commit; re-check on any TypedMemView bump).
    /// @param v The view to copy (never NULL: `getHookData` reverts on NULL)
    /// @return out The copied bytes
    function _viewToBytes(bytes29 v) internal pure returns (bytes memory out) {
        uint256 len = v.len();
        uint256 loc = v.loc();
        assembly ("memory-safe") {
            out := mload(0x40)
            mstore(out, len)
            mcopy(add(out, 0x20), loc, len)
            mstore(0x40, add(out, and(add(add(len, 0x20), 0x1f), not(0x1f))))
        }
    }
}
