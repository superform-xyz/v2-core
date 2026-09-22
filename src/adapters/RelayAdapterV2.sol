// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External Dependencies
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Vendor / Protocol Interfaces
import { BytesLib } from "../vendor/BytesLib.sol";

// Superform Interfaces
import { ISuperDestinationExecutor } from "../interfaces/ISuperDestinationExecutor.sol";
import { ISuperDestinationValidator } from "../interfaces/ISuperDestinationValidator.sol";
import { ISuperSenderCreator } from "../interfaces/ISuperSenderCreator.sol";
import { ISuperValidator } from "../interfaces/ISuperValidator.sol";

/// @notice Minimal getter for the executor's wired validator
/// @dev Kept local so the shared ISuperDestinationExecutor interface (compiled into locked-bytecode
///      deployed contracts) stays untouched; SuperDestinationExecutor exposes this as a public immutable
interface IDestinationValidatorSource {
    function SUPER_DESTINATION_VALIDATOR() external view returns (address);
}

/// @title RelayAdapterV2
/// @author Superform Labs
/// @notice Destination-side adapter for Relay Protocol fills, hardened so that the FUND TRANSFER
///         itself is gated on intent authenticity rather than on a pool-level balance check.
///
/// @dev ## What changed versus RelayAdapter (V1) and why
///
/// V1 moved funds before any signature was verified. `_extractFromSigData` is a bare `abi.decode`, and
/// the only gates before the transfer were "a DstProof exists for this chain", "account != 0", and
/// `balance - totalEscrowed >= amount` — a POOL-level check with no notion of which delivery the funds
/// belong to. The real signature check lived inside `processBridgedExecution`, which ran AFTER the
/// transfer and inside a swallowing `catch {}`.
///
/// Consequently no signature was required at all for funds to move: any syntactically well-formed byte
/// string naming the caller's own address, with an EMPTY signature, would drain whatever balance was
/// resting in the adapter. V1's NatSpec described this as requiring "a validly-signed message for their
/// own account", which understated the attacker's cost.
///
/// Relay is the only adapter with this exposure. Across (`msg.sender == ACROSS_SPOKE_POOL`), Stargate
/// (`msg.sender == LZ_ENDPOINT` + registered-pool allowlist) and deBridge (`onlyExternalCallAdapter`)
/// gate their entrypoints to a trusted bridge contract that vouches for the amount; CCTP is
/// permissionless but its message is Circle-attested and its amount is a measured mint delta. Relay has
/// no destination callback at all, so it has neither a trusted caller nor an attested message — which
/// is precisely why the signature must be checked here, before the funds move.
///
/// V2 therefore validates the signed destination intent BEFORE `_tryTransfer`, mirroring the exact
/// ordering `SuperDestinationExecutor` uses: create the account if needed, then verify. Reverting on an
/// unauthentic message is safe for Relay — fills are independent, and inside the solver's atomic batch
/// (allowFailure = false) the revert unwinds the funds-delivery leg too, so the solver is never left
/// funding a stranger. This is the same rationale V1 already relied on for `NO_DST_PROOF_FOR_CHAIN`.
///
/// @dev ## What V2 does NOT fix: fund attribution
///
/// V2 authenticates the MESSAGE. It does not attribute the FUNDS. The spendable check is still
/// pool-level — `balance - totalEscrowed >= amount` — which answers "does this contract hold this
/// much?", never "were these funds delivered for this intent?". So any balance resting in the adapter
/// backs any valid intent: if a fill is delivered for account A and A's second leg reverts or is
/// delayed, a later call carrying a genuinely signed intent for account B will consume those funds.
/// This is pinned by `test_Residual_RestingFundsAreConsumedByADifferentValidIntent`.
///
/// V2 therefore narrows the V1 exposure from "any fabricated byte string with an EMPTY signature can
/// sweep resting funds" to "only the holder of a genuinely signed intent can, only ever to the account
/// that intent names, and only once per signed intent". That is a reduction in FORGEABILITY. It is
/// not a protection of resting funds, and the checks must not be read as one:
///
///   - Nothing here establishes a transfer BUDGET. The token-binding check asks whether the intent
///     names the delivered token; the one-shot flag limits each signed root to a single delivery;
///     neither bounds `amount`, which within that delivery is limited only by the spendable balance.
///     `intentAmounts` is the MINIMUM acceptable fill (ISuperValidator.DstInfo,
///     SuperDestinationExecutor._validateBalances, technical-spec.md:123) and is deliberately NOT used
///     as a maximum — an earlier revision did, and it rejected every normal fill above the slippage
///     floor (review F1).
///   - An attacker needs no victim key, no origin deposit and no solver role. They sign a fresh
///     intent for their OWN account — every new root is a new shot — and are paid from whatever is
///     resting. Restricting payment to the signer's own account does not protect pooled victim funds,
///     because the attacker's own account is exactly where they want them. Rejecting empty or
///     mismatched token lists removes a shortcut, not the exposure.
///   - Resting funds are therefore NOT safe in V2. Their safety rests entirely on the accepted
///     operating requirements: one atomic delivery per call, `amount` matched to the delivered funds,
///     supported (non-rebasing, non-fee) tokens, and no unassigned residual. `SpendableBalanceRetained`
///     is DETECTION of a violated requirement, not prevention; under correct operation it is never
///     emitted.
///
/// Why the one-shot flag (`intentDelivered`, keyed by the intent's merkle root) lives in this adapter
/// even though the executor has its own root guard: the executor marks `usedMerkleRoots` only
/// immediately before `_execute`, so an execution revert rolls that mark back while this adapter's
/// transfer stays committed — leaving one signature able to draw resting funds indefinitely. A Relay
/// fill is a single atomic delivery per intent, and the recovery path for a failed second leg is a
/// direct, permissionless `processBridgedExecution` call (the funds are already at the account), so a
/// SECOND adapter delivery against the same root is never part of a legitimate flow. A below-minimum
/// partial fill is delivered by this adapter and left unexecuted by the executor's balance gate; any
/// top-up must reach the account directly, not through this adapter (pinned in
/// RelayAdapterV2RealExecutorE2E). If Relay ever introduces multi-delivery fills for one intent, this
/// flag — not the executor — is what would need a delivery-level redesign.
///
/// ## Custody model: pushed delivery retained; pull-based delivery is feasible but out of scope
///
/// The way to attribute funds on-chain is to stop accepting pushed balances and pull them instead —
/// `transferFrom(msg.sender, ...)` (or `msg.value` for native) inside the same call that executes the
/// intent, forwarding only the measured delta, so nothing ever rests and the payer is known.
///
/// Relay's own documentation describes exactly that shape for destination calls: output funds are
/// delivered to the Router within the same multicall BEFORE `txs[]` execute, an in-`txs[]` `approve`
/// is executed BY the Router over the Router's balance, and Relay's Call Execution Integration Guide
/// (EXACT_INPUT with proxy contracts) recommends a proxy that pulls the approved balance from the
/// caller that initiated execution — the Router. The repository's own Relay research records the same
/// (specs/relay-bridge-integration/research/framework-docs.md, "Fund delivery relative to the calls").
/// Pull-based delivery is therefore NOT architecturally impossible for Relay; an earlier revision of
/// this note claimed it was, and that claim is withdrawn.
///
/// This PR nevertheless retains pushed custody, deliberately and with a narrow claim: it fixes the
/// authentication ordering (the V1 vulnerability) and keeps the atomic-batch assumption for
/// attribution that the integration already documents and accepts (spec.md:73). Moving to pull is a
/// separate delivery-level design that has not been done here and must not be assumed safe from this
/// note alone. It requires, at minimum: (a) verifying per route which Router/Multicaller version fills
/// go through and that it holds the output tokens while executing `txs[]` (simple bridges bypass the
/// Router entirely); (b) binding the forwarded amount to the actually-pulled delta — and native value
/// to `msg.value` of the same call — never to a caller-supplied `amount`; (c) a live Relay
/// quote/integration test. None of that is exercised in this repository today: the pigeon E2E
/// simulates the solver leg, not Relay's Router.
///
/// Every other adapter avoids the question because something outside the message binds funds to it: a
/// trusted caller that vouches for `amount` (Across/Stargate/deBridge) or an attested message carrying
/// the payer's identity (CCTP's `messageSender`). Relay's fill carries no source-chain message at all,
/// so until a pull-based design lands, the solver's atomicity is the only binding.
///
/// ## The residual, stated plainly
///
/// Binding funds to an intent rests entirely on the solver's batch being atomic (`allowFailure =
/// false`), which is the trust assumption the Relay integration already documents and accepts
/// (specs/relay-bridge-integration/spec.md:73). Note also that this adapter is the OPTIONAL path: the
/// primary integration is the solver delivering funds directly to the account and calling
/// `SuperDestinationExecutor.processBridgedExecution` (spec.md:33), where no adapter ever takes
/// custody and this residual does not arise.
///
/// @dev PERMISSIONLESS by design: anyone may call `processRelayExecution`. Safe against forged
///      messages without any atomicity assumption, because an attacker cannot produce a signature over
///      a leaf naming their own account for someone else's intent. Still dependent on batch atomicity
///      for fund ATTRIBUTION — see above.
/// @dev token address(0) represents native ETH throughout (delivery, failed transfers, claims).
contract RelayAdapterV2 is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev bytes4(keccak256("isValidDestinationSignature(address,bytes)"))
    bytes4 internal constant DESTINATION_SIGNATURE_MAGIC_VALUE = bytes4(0x5c2ec0f3);

    /// @dev Minimum gas that must remain before the best-effort executor call.
    /// @dev Unlike CCTP this is a convenience rather than a fund-safety control: a Relay message is not
    ///      one-shot. `SuperDestinationExecutor.processBridgedExecution` is permissionless and the
    ///      merkle root is only marked used immediately before `_execute`, so a gas-starved execution
    ///      unwinds and stays retriable by anyone. The floor simply stops a caller from silently
    ///      pushing a relay into the `catch` branch.
    uint256 internal constant MIN_EXECUTION_GAS = 500_000;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The SuperDestinationExecutor for processing bridged executions
    ISuperDestinationExecutor public immutable SUPER_DESTINATION_EXECUTOR;

    /// @notice The destination validator wired into the executor, cached at construction
    /// @dev V1 was the only adapter that did not cache this; V2 needs it to pre-validate.
    address public immutable SUPER_DESTINATION_VALIDATOR;

    /// @notice Claimable balances for failed token transfers: account => token => amount
    mapping(address account => mapping(address token => uint256 amount)) public failedTransfers;

    /// @notice Total amount per token currently escrowed in failedTransfers
    mapping(address token => uint256 amount) public totalEscrowed;

    /// @notice Whether a signed intent has already been delivered against: account => merkleRoot => delivered
    /// @dev A destination signature is REUSABLE — the executor only marks `usedMerkleRoots` right before
    ///      `_execute`, and a revert there rolls that write back while this adapter's transfer stays
    ///      committed. Without this flag one signed intent could be replayed to absorb the resting
    ///      balance indefinitely. The merkle root is unique per signed intent, so one delivery per
    ///      (account, root) bounds replay to exactly one shot per signature.
    /// @dev This is a one-shot flag, NOT an amount cap: `intentAmounts` is the MINIMUM acceptable fill
    ///      (spec technical-spec.md:123; SuperDestinationExecutor._validateBalances), so it cannot bound
    ///      how much a legitimate fill delivers. An earlier revision capped at it and would have reverted
    ///      every normal fill delivered above the slippage floor (found by review).
    mapping(address account => mapping(bytes32 merkleRoot => bool delivered)) public intentDelivered;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Fields extracted from sigData's DstProof.info (avoids stack-too-deep)
    struct ExtractedData {
        address account;
        address executor;
        address validator;
        bytes32 merkleRoot;
        bytes executorCalldata;
        address[] dstTokens;
        uint256[] intentAmounts;
        bool found;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ADDRESS_NOT_VALID();
    error ZERO_AMOUNT();
    error MSG_VALUE_NOT_ALLOWED();
    error NO_DST_PROOF_FOR_CHAIN();
    error ACCOUNT_NOT_VALID();
    error INSUFFICIENT_FUNDS_RECEIVED();
    error INSUFFICIENT_FAILED_BALANCE();
    error ETH_TRANSFER_FAILED();
    error INSUFFICIENT_GAS();

    /// @notice Thrown when the signed DstProof for this chain names a different executor
    error EXECUTOR_NOT_VALID();

    /// @notice Thrown when the signed DstProof for this chain names a different validator
    error VALIDATOR_NOT_VALID();

    /// @notice Thrown when the destination signature does not authenticate this intent
    /// @dev This is the V2 guard: it fires BEFORE any funds move.
    error INVALID_SIGNATURE();

    /// @notice Thrown when a signed intent is presented again after it has already been delivered against
    error INTENT_ALREADY_DELIVERED();

    /// @notice Thrown when the signed intent does not name `tokenSent` with a non-zero minimum
    /// @dev Binds the delivery token to the intent. Without it a self-signed intent with an empty
    ///      dstTokens list could be paid in ANY token resting here (found by review).
    error TOKEN_NOT_IN_SIGNED_INTENT();

    /// @notice Thrown when the signed intent's dstTokens and intentAmounts differ in length
    /// @dev Fires BEFORE any transfer. A mismatched pair is never legitimate — the executor rejects it
    ///      with ARRAY_LENGTH_MISMATCH — but the executor runs AFTER the transfer, inside a swallowed
    ///      try/catch. Without this check a signer could sign a deliberately mismatched pair to make
    ///      the token-binding and one-shot checks below be skipped (found by CI review).
    error ARRAY_LENGTH_MISMATCH();

    /// @notice Thrown when the target account does not exist and could not be created
    error ACCOUNT_NOT_CREATED();

    /// @notice Thrown when initData does not produce the named account
    error INVALID_ACCOUNT();

    /// @notice Thrown when the SuperSenderCreator in initData is not a contract
    error SENDER_CREATOR_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TransferSucceeded(address indexed account, address indexed token, uint256 amount);
    event TransferFailed(address indexed account, address indexed token, uint256 amount);
    event ExecutionFailed(address indexed account);

    /// @notice Emitted when spendable balance remains in the adapter after a relay.
    /// @dev Under correct operation this is always zero: the solver's batch is atomic and delivers
    ///      exactly what the call consumes. A non-zero value means either an over-delivery (a bundler
    ///      amount mismatch), a donation, or a previously-split batch — all of which leave funds that
    ///      the next valid intent can absorb. Emitted so monitoring catches it rather than discovering
    ///      it after the fact.
    event SpendableBalanceRetained(address indexed token, uint256 amount);
    event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param superDestinationExecutor_ The SuperDestinationExecutor on this chain
    constructor(address superDestinationExecutor_) {
        if (superDestinationExecutor_ == address(0)) revert ADDRESS_NOT_VALID();
        SUPER_DESTINATION_EXECUTOR = ISuperDestinationExecutor(superDestinationExecutor_);
        SUPER_DESTINATION_VALIDATOR =
            IDestinationValidatorSource(superDestinationExecutor_).SUPER_DESTINATION_VALIDATOR();
    }

    /// @notice Accepts native ETH pre-funded by a solver in a prior leg of the same atomic batch
    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                          RECEIVE + EXECUTE
    //////////////////////////////////////////////////////////////*/

    /// @notice Forwards Relay-filled funds to the intent account and best-effort executes the intent.
    /// @param tokenSent The output token delivered by the Relay fill (address(0) for native ETH)
    /// @param amount The amount delivered for this intent
    /// @param message abi.encode(bytes initData, bytes sigData) — compact 2-field format
    function processRelayExecution(
        address tokenSent,
        uint256 amount,
        bytes calldata message
    )
        external
        payable
        nonReentrant
    {
        if (amount == 0) revert ZERO_AMOUNT();
        if (tokenSent != address(0) && msg.value != 0) revert MSG_VALUE_NOT_ALLOWED();

        (bytes memory initData, bytes memory sigDataRaw) = abi.decode(message, (bytes, bytes));
        ExtractedData memory extracted = _extractFromSigData(sigDataRaw);

        if (!extracted.found) revert NO_DST_PROOF_FOR_CHAIN();
        if (extracted.account == address(0)) revert ACCOUNT_NOT_VALID();

        // Cheap early exits: a proof naming another deployment can never produce a valid signature
        // against this chain's executor/validator, so fail here rather than burning the verify gas.
        if (extracted.executor != address(SUPER_DESTINATION_EXECUTOR)) revert EXECUTOR_NOT_VALID();
        if (extracted.validator != SUPER_DESTINATION_VALIDATOR) revert VALIDATOR_NOT_VALID();

        // ---------------------------------------------------------------------------------------
        // THE V2 GUARD: authenticate the intent BEFORE any funds move.
        //
        // WHY THIS LIVES IN THE ADAPTER AT ALL.
        // `SuperDestinationExecutor.processBridgedExecution` already performs both of these steps, so
        // at first glance repeating them here is redundant. It is not: the executor runs them AFTER
        // this adapter has transferred the funds, and its failure is swallowed by the `catch {}` at
        // the bottom of this function. In V1 that ordering was the whole vulnerability — the only
        // gates ahead of the transfer were "a DstProof names this chain", "account != 0" and a
        // POOL-level balance check, none of which say anything about whether the caller is entitled
        // to the funds resting in this contract. Any well-formed byte string with an EMPTY signature
        // could therefore redirect another user's fill. Verifying here makes the transfer itself
        // conditional on intent authenticity rather than on the adapter's balance.
        //
        // WHY THIS ADAPTER IS DIFFERENT FROM EVERY OTHER ONE.
        //
        // The general principle: an adapter may only hand funds to an address named in a message if
        // SOMETHING independent of the caller binds those funds to that message. Deferring the
        // signature check to the executor (as every other adapter does) is safe precisely because each
        // of them already holds such a binding by the time the transfer happens:
        //
        //   ADAPTER              WHO MAY CALL IT              WHAT VOUCHES FOR THE DELIVERY
        //   AcrossV3AdapterV2    only ACROSS_SPOKE_POOL       `amount` is a param the SpokePool passes
        //   StargateAdapterV2    only LZ_ENDPOINT (+ pool     `amountLD` is read from the compose
        //                        allowlist, since LZ V2's     header LayerZero itself delivered
        //                        sendCompose is permissionless)
        //   DebridgeAdapter      only externalCallAdapter     `_transferredAmount` is a trusted param
        //   CCTPAdapter          anyone                       the message is Circle-ATTESTED, and the
        //                                                     amount is a mint delta measured around
        //                                                     `receiveMessage` (unforgeable either way)
        //
        // For the first three an attacker simply cannot reach the entrypoint. For CCTP an attacker can
        // call it, but cannot forge Circle's attestation nor inflate a measured delta.
        //
        // Relay has NO destination callback at all. The solver delivers funds in one leg and calls this
        // contract in another, so:
        //   - `msg.sender` is Relay's router — not an authenticatable bridge contract, and in the
        //     general case just whoever chose to submit the second leg;
        //   - `amount` is supplied by that caller;
        //   - the message is supplied by that caller too, and carries no attestation.
        // The caller controls all three inputs, so NOTHING outside the message binds the resting funds
        // to it. V1's substitute was `balance - totalEscrowed >= amount`, but that only answers "does
        // this contract hold this much?" — never "do these funds belong to this message?", which is the
        // question that actually matters. That gap is what made the sweep possible.
        //
        // The signature is therefore the only binding available to Relay, which is why the check that
        // every other adapter can safely defer must happen here, ahead of the transfer.
        //
        // WHY ACCOUNT CREATION MUST COME FIRST.
        // `isValidDestinationSignature` opens with `if (!_initialized[sender]) revert NOT_INITIALIZED`
        // (SuperValidatorBase), and `_initialized` is set by the account itself when it installs the
        // validator module. A first-time cross-chain user's account does not exist yet — creating it
        // is precisely what `initData` is for — so validating before creating would revert for exactly
        // the users the initData path exists to serve. This mirrors the executor's own ordering:
        // `_validateOrCreateAccount` (SuperDestinationExecutor:108) then the signature check (:118).
        //
        // COST, AND WHY IT IS ACCEPTABLE.
        // The signature is now verified twice (here and again inside the executor below) — one extra
        // merkle-proof verification plus one ECDSA recovery. `isValidDestinationSignature` is `view`
        // and side-effect free, so the repetition is purely gas, never a correctness hazard. Account
        // creation is NOT repeated: the executor's own `_validateOrCreateAccount` no-ops on its second
        // pass because `account.code.length != 0` by then.
        //
        // WHY REVERTING HERE IS SAFE.
        // Relay fills are independent and the solver's router executes the quote's txs[] with
        // allowFailure = false, so a revert unwinds the funds-delivery leg in the same batch and the
        // solver keeps its capital. V1 already relied on this reasoning for NO_DST_PROOF_FOR_CHAIN.
        // (Contrast CCTPAdapter, where the burn is irreversible and the message bytes are immutable,
        // so a content-dependent revert would destroy the funds permanently rather than defer them.)
        // ---------------------------------------------------------------------------------------
        _validateOrCreateAccount(extracted.account, initData);
        _validateDestinationSignature(extracted, sigDataRaw);

        // A mismatched (dstTokens, intentAmounts) pair is never legitimate, and it must be rejected HERE
        // rather than left to the executor: the executor's own check runs after the transfer inside a
        // swallowed try/catch, so a signer could otherwise sign a mismatched pair to defeat the checks
        // below.
        if (extracted.dstTokens.length != extracted.intentAmounts.length) revert ARRAY_LENGTH_MISMATCH();

        // The intent must actually name the token being delivered, with a non-zero minimum. A signed
        // intent whose dstTokens is empty (or names other tokens) is not an intent to receive THIS token
        // and must not be able to pull it. `intentAmounts` is a MINIMUM, so it is deliberately NOT used
        // as a maximum here — see the note on `intentDelivered`.
        if (!_intentNamesToken(extracted, tokenSent)) revert TOKEN_NOT_IN_SIGNED_INTENT();

        // One delivery per signed intent. Set BEFORE the transfer (checks-effects-interactions).
        if (intentDelivered[extracted.account][extracted.merkleRoot]) revert INTENT_ALREADY_DELIVERED();
        intentDelivered[extracted.account][extracted.merkleRoot] = true;

        // Balance guard retained from V1: the claimed amount must actually be held, excluding escrow.
        uint256 balance =
            tokenSent == address(0) ? address(this).balance : IERC20(tokenSent).balanceOf(address(this));
        // Saturating: a negative-rebasing token (or a transfer that moved funds but reported failure)
        // can leave the live balance below the escrow ledger. A checked subtraction would then panic
        // on every call for that token; failing cleanly with INSUFFICIENT_FUNDS_RECEIVED does not.
        uint256 escrowed = totalEscrowed[tokenSent];
        uint256 spendable = balance > escrowed ? balance - escrowed : 0;
        if (spendable < amount) revert INSUFFICIENT_FUNDS_RECEIVED();

        // Surface any balance left over after this relay. Zero under correct operation; non-zero means
        // funds are resting and a later valid intent could absorb them.
        if (spendable > amount) emit SpendableBalanceRetained(tokenSent, spendable - amount);

        // Transfer to the authenticated account
        if (_tryTransfer(tokenSent, extracted.account, amount)) {
            emit TransferSucceeded(extracted.account, tokenSent, amount);
        } else {
            failedTransfers[extracted.account][tokenSent] += amount;
            totalEscrowed[tokenSent] += amount;
            emit TransferFailed(extracted.account, tokenSent, amount);
        }

        if (gasleft() < MIN_EXECUTION_GAS) revert INSUFFICIENT_GAS();

        // Best-effort execution; bare catch never copies revert returndata (returnbomb-safe)
        try SUPER_DESTINATION_EXECUTOR.processBridgedExecution(
            tokenSent,
            extracted.account,
            extracted.dstTokens,
            extracted.intentAmounts,
            initData,
            extracted.executorCalldata,
            sigDataRaw
        ) { } catch {
            emit ExecutionFailed(extracted.account);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 CLAIM
    //////////////////////////////////////////////////////////////*/

    /// @notice Claim tokens from a failed transfer. Only the intended recipient may claim.
    function claimFailedTransfer(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZERO_AMOUNT();

        uint256 available = failedTransfers[msg.sender][token];
        if (available < amount) revert INSUFFICIENT_FAILED_BALANCE();

        failedTransfers[msg.sender][token] = available - amount;
        totalEscrowed[token] -= amount;

        if (token == address(0)) {
            (bool success,) = msg.sender.call{ value: amount }("");
            if (!success) revert ETH_TRANSFER_FAILED();
        } else {
            IERC20(token).safeTransfer(msg.sender, amount);
        }

        emit FailedTransferClaimed(msg.sender, token, amount);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify the destination signature over the reconstructed leaf.
    /// @dev Rebuilds `destinationData` exactly as SuperDestinationExecutor does (:114-115), using the
    ///      EXECUTOR's address — the leaf commits to the executor, never to this adapter, which is why
    ///      V2 can be deployed at a new address without invalidating any signature already issued.
    function _validateDestinationSignature(ExtractedData memory extracted, bytes memory sigDataRaw) internal view {
        bytes memory destinationData = abi.encode(
            extracted.executorCalldata,
            uint64(block.chainid),
            extracted.account,
            address(SUPER_DESTINATION_EXECUTOR),
            extracted.dstTokens,
            extracted.intentAmounts
        );

        bytes4 result = ISuperDestinationValidator(SUPER_DESTINATION_VALIDATOR).isValidDestinationSignature(
            extracted.account, abi.encode(sigDataRaw, destinationData)
        );
        if (result != DESTINATION_SIGNATURE_MAGIC_VALUE) revert INVALID_SIGNATURE();
    }

    /// @notice Create the target account when it does not yet exist.
    /// @dev Mirrors SuperDestinationExecutor._validateOrCreateAccount/_createAccount. Required here
    ///      because the signature check below it cannot run against an uninitialized account, and
    ///      first-time cross-chain users are created during the bridge itself. The executor repeats
    ///      this check later as a no-op.
    function _validateOrCreateAccount(address account, bytes memory initData) internal {
        if (initData.length > 0 && account.code.length == 0) {
            address senderCreator = BytesLib.toAddress(initData, 0);
            if (senderCreator == address(0)) revert ADDRESS_NOT_VALID();
            if (senderCreator.code.length == 0) revert SENDER_CREATOR_NOT_VALID();

            bytes memory senderData = BytesLib.slice(initData, 20, initData.length - 20);
            address computed = ISuperSenderCreator(senderCreator).createSender(senderData);
            if (account != computed) revert INVALID_ACCOUNT();
        }

        if (account.code.length == 0) revert ACCOUNT_NOT_CREATED();
    }

    /// @notice Transfer without reverting, so a failure can be escrowed instead.
    /// @dev The `returnData.length >= 32` guard matters: a token returning a short non-empty payload
    ///      would make `abi.decode` PANIC, propagating out and converting a recoverable escrow into a
    ///      hard revert. V1 (and both Stargate adapters) lack this guard.
    function _tryTransfer(address token, address account, uint256 amount) internal returns (bool success) {
        if (token == address(0)) {
            (success,) = account.call{ value: amount }("");
        } else {
            (bool callSuccess, bytes memory returnData) =
                token.call(abi.encodeCall(IERC20.transfer, (account, amount)));
            // NOT abi.decode(returnData,(bool)): the ABI decoder PANICS on a 32-byte word that is not 0 or
            // 1, so a length guard alone cannot keep this helper from reverting. Read the raw word instead;
            // any non-`1` payload simply reads as failure and escrows, which is this helper's contract.
            success = callSuccess && (returnData.length == 0 || (returnData.length >= 32 && _isTrueWord(returnData)));
        }
    }

    /// @dev Reads the first return word without abi.decode, so a non-boolean word yields false, never a panic.
    function _isTrueWord(bytes memory data) private pure returns (bool isTrue) {
        bytes32 word;
        assembly {
            word := mload(add(data, 32))
        }
        return word == bytes32(uint256(1));
    }

    /// @notice Whether the signed intent names `tokenSent` with a non-zero minimum amount.
    /// @dev `dstTokens`/`intentAmounts` are inside the signed leaf, so this binding is authenticated.
    ///      Caller has already rejected a length mismatch, so indexing intentAmounts by i is safe.
    function _intentNamesToken(ExtractedData memory extracted, address tokenSent) internal pure returns (bool) {
        uint256 len = extracted.dstTokens.length;
        for (uint256 i; i < len; ++i) {
            if (extracted.dstTokens[i] == tokenSent && extracted.intentAmounts[i] != 0) return true;
        }
        return false;
    }

    /// @notice Extract the DstProof entry matching this chain.
    function _extractFromSigData(bytes memory sigDataRaw) internal view returns (ExtractedData memory extracted) {
        (,,, bytes32 merkleRoot,, ISuperValidator.DstProof[] memory proofDst,) =
            abi.decode(sigDataRaw, (uint64[], uint48, uint48, bytes32, bytes32[], ISuperValidator.DstProof[], bytes));
        extracted.merkleRoot = merkleRoot;

        uint64 currentChain = uint64(block.chainid);
        uint256 len = proofDst.length;
        for (uint256 i; i < len; ++i) {
            if (proofDst[i].dstChainId == currentChain) {
                extracted.account = proofDst[i].info.account;
                extracted.executor = proofDst[i].info.executor;
                extracted.validator = proofDst[i].info.validator;
                extracted.executorCalldata = proofDst[i].info.data;
                extracted.dstTokens = proofDst[i].info.dstTokens;
                extracted.intentAmounts = proofDst[i].info.intentAmounts;
                extracted.found = true;
                return extracted;
            }
        }
    }
}
