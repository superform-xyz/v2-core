// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External Dependencies
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Vendor Interfaces
import { IMessageTransmitterV2 } from "../vendor/bridges/cctp/IMessageTransmitterV2.sol";
import { ITokenMinterV2 } from "../vendor/bridges/cctp/ITokenMinterV2.sol";

// Superform Interfaces
import { ISuperDestinationExecutor } from "../interfaces/ISuperDestinationExecutor.sol";
import { ISuperValidator } from "../interfaces/ISuperValidator.sol";

/// @notice Minimal getter for the executor's wired validator
/// @dev Kept local so the shared ISuperDestinationExecutor interface (compiled into locked-bytecode
///      deployed contracts) stays untouched; SuperDestinationExecutor exposes this as a public immutable
interface IDestinationValidatorSource {
    function SUPER_DESTINATION_VALIDATOR() external view returns (address);
}

/// @notice Minimal getter for TokenMessengerV2's wired TokenMinterV2
/// @dev Kept local so the vendored ITokenMessengerV2 (whose source hash is baked into the metadata of the
///      already-deployed CCTPSendHook / ApproveAndCCTPSendHook locked bytecode) stays byte-identical
interface ITokenMessengerV2MinterSource {
    function localMinter() external view returns (address);
    function localMessageTransmitter() external view returns (address);
}

/// @title CCTPAdapter
/// @author Superform Labs
/// @notice Destination-side adapter that completes a Superform CCTP V2 cross-chain intent.
/// @notice The source `CCTPSendHook` burns USDC via `TokenMessengerV2.depositForBurnWithHook`, setting
/// @notice `mintRecipient = destinationCaller = this adapter` and packing the executor payload into
/// @notice `hookData = abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts, signature)`.
/// @dev Structural difference from every other Superform adapter: CCTP has NO push callback.
///      `MessageTransmitterV2.receiveMessage` only mints USDC to `mintRecipient`; it never forwards
///      `hookData`. So this adapter is PULL-driven — a relayer calls `receiveAndExecute(message,
///      attestation)`, the adapter calls `receiveMessage` itself, then acts on the payload it slices
///      from the attested message.
/// @dev PERMISSIONLESS: anyone can call `receiveAndExecute`. Safety is anchored by:
///      1. Circle's attestation authenticating the entire message (incl. `account` and `hookData`), so
///         a front-running caller cannot substitute the recipient.
///      2. `destinationCaller = adapter` (enforced by MessageTransmitterV2) making the adapter the only
///         party that can trigger the mint — mint + execution stay atomic in one tx.
///      3. The executor's own EIP-1271 signature + Merkle-root replay checks for the hook execution leg.
/// @dev Donation-proof: the adapter forwards only the measured `receiveMessage` balance delta
///      (`post - pre`, equal to `amount - feeExecuted`), never `balanceOf(this)`. A pre-existing or
///      donated USDC balance (incl. escrowed failed transfers) is therefore never forwardable.
/// @dev Token model: the intent leg is USDC-only, but CCTP V2 itself is multi-token (Circle registers
///      each supported token per remote domain in TokenMinterV2). A message that burned some OTHER
///      registered token with this adapter as `mintRecipient`/`destinationCaller` can only ever be
///      consumed here, so it must not revert: the minted token is measured and escrowed to the attested
///      burner instead (see `_receiveNonUsdc`). Which local token a message mints is resolved BEFORE
///      `receiveMessage` via `TokenMinterV2.getLocalToken(sourceDomain, burnToken)` — the same lookup
///      the transmitter's mint path performs.
contract CCTPAdapter is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // CCTP V2 wire offsets: absolute = 148 (MessageV2 header) + BurnMessageV2 body offset.
    //   MessageV2 header, 148 bytes — field[size] at offset:
    //     version[4] 0 | sourceDomain[4] 4 | destinationDomain[4] 8 | nonce[32] 12 | sender[32] 44
    //     recipient[32] 76 | destinationCaller[32] 108 | minFinalityThreshold[4] 140
    //     finalityThresholdExecuted[4] 144 | body starts at 148
    //   BurnMessageV2 body, 228 fixed bytes then hookData — field[size] at body offset:
    //     version[4] 0 | burnToken[32] 4 | mintRecipient[32] 36 | amount[32] 68 | messageSender[32] 100
    //     maxFee[32] 132 | feeExecuted[32] 164 | expirationBlock[32] 196 | hookData 228
    //   Hence burnToken 148+4=152, mintRecipient 148+36=184, amount 148+68=216, feeExecuted 148+164=312,
    //   hookData 148+228=376.
    //   Verified against circlefin/evm-cctp-contracts src/messages/v2/{MessageV2,BurnMessageV2}.sol and
    //   by the pigeon E2E suite against real deployed bytecode.
    uint256 private constant BURN_TOKEN_OFFSET = 152;
    uint256 private constant MINT_RECIPIENT_OFFSET = 184;
    uint256 private constant AMOUNT_OFFSET = 216;
    uint256 private constant FEE_EXECUTED_OFFSET = 312;
    uint256 private constant HOOKDATA_OFFSET = 376;

    /// @dev CCTP V2 message header version. V1 messages (version 0) carry no hookData at all, so they
    ///      can never represent a Superform intent and are rejected before any external call.
    uint32 private constant SUPPORTED_MESSAGE_VERSION = 1;

    /// @dev Offset of the BurnMessageV2 body's own `version` field (body offset 0 → absolute 148).
    uint256 private constant BODY_VERSION_OFFSET = 148;

    /// @dev MessageV2 header `destinationCaller` field (header offset 108).
    uint256 private constant DESTINATION_CALLER_OFFSET = 108;

    /// @dev MessageV2 header `sourceDomain` field (header offset 4). Together with `burnToken` it keys
    ///      TokenMinterV2's remote→local token registry.
    uint256 private constant SOURCE_DOMAIN_OFFSET = 4;

    /// @dev MessageV2 header `recipient` field (header offset 76): the contract the transmitter hands the
    ///      body to. MessageTransmitterV2 dispatches to ANY non-zero recipient and `sendMessage` is
    ///      permissionless on the source chain, so without this pin a Circle-attested NON-burn message
    ///      could name an attacker handler as recipient with a BurnMessageV2-shaped body it fully controls
    ///      (including `messageSender`). Pinning to TOKEN_MESSENGER guarantees the body is a genuine burn
    ///      (TokenMessengerV2 enforces `onlyRemoteTokenMessenger`), keeps the `getLocalToken` lookup on the
    ///      same messenger that will mint, and removes the attacker-callback surface entirely.
    uint256 private constant RECIPIENT_OFFSET = 76;

    /// @dev BurnMessageV2 `messageSender` (body offset 100 → absolute 248). Set by Circle's
    ///      TokenMessengerV2 to `msg.sender` at burn time, so it is attested and unspoofable — given the
    ///      RECIPIENT_OFFSET pin, which is what guarantees the body was produced by a real burn — and it
    ///      lives inside the FIXED 228-byte body — readable even when the hookData tail is garbage.
    ///      For a Superform-originated burn this is the depositing smart account itself, i.e. the same
    ///      value the hookData tail is supposed to decode to as `account`.
    uint256 private constant MESSAGE_SENDER_OFFSET = 248;

    /// @dev CCTP V2 BurnMessageV2 body version.
    /// @dev Checked SEPARATELY from the outer header version. Circle's own audit found an underflow in
    ///      their reference `CCTPHookWrapper.relay()` precisely because a non-BurnMessageV2 body could
    ///      be sliced with BurnMessageV2 offsets (ChainSecurity, CS-EVM-CCTP2-013); their fix validates
    ///      "lengths and versions of BOTH MessageV2 and BurnMessageV2". Every offset below
    ///      (mintRecipient/amount/feeExecuted/hookData) assumes this body layout, so validating the
    ///      body version is what makes trusting them sound — and is cheap insurance against a future
    ///      Circle body-format bump silently shifting them.
    uint32 private constant SUPPORTED_BODY_VERSION = 1;

    /// @dev Minimum gas that must remain before the executor call.
    /// @dev `receiveAndExecute()` is permissionless, so the caller chooses the gas limit. Without a floor a griefer
    ///      can supply just enough gas for `receiveMessage` + the transfer to succeed while starving the
    ///      executor call under EIP-150's 63/64 rule, forcing the `catch` branch. Reverting here instead
    ///      unwinds the mint entirely, leaving the message retriable by a caller who supplies enough gas.
    ///      NOTE (review I1): starvation past the floor is NOT a loss. The USDC is already at the account, the
    ///      merkle root stays unused on revert and the payload is public in the attested message, so anyone
    ///      can re-drive `SuperDestinationExecutor.processBridgedExecution` directly (it is permissionless)
    ///      until the signature's validUntil. The floor is defense-in-depth against a DELAYED execution.
    /// @dev Deliberately a floor and NOT a `{gas: N}` stipend — a stipend would cap legitimate long hook
    ///      chains. All remaining gas is forwarded; the floor only guarantees there is enough to forward.
    /// @dev Measured basis: a real cap-validated SuperVault destination deposit costs ~660k gas
    ///      (test/unit/simulationHelpers/CrossChainSuperVaultDestinationE2E.t.sol), and first-time
    ///      accounts add a CREATE2 deploy via SuperDestinationExecutor._createAccount. Per EIP-150 the
    ///      inner call receives 63/64 of what remains, so a 500k floor guaranteed only ~492k — below
    ///      the realistic requirement, leaving the griefing vector open on complex intents.
    /// @dev Calibrated against the realistic MAXIMUM, not the adversarial minimum. The dangerous case
    ///      is not "floor rejects" (that reverts and unwinds, leaving the nonce unspent and the message
    ///      retriable) but "floor passes yet gas is still short": the executor then reverts into the
    ///      catch, the OUTER transaction SUCCEEDS, and the CCTP nonce is consumed with hooks
    ///      unexecuted — recoverable only by the direct re-drive above, i.e. a delay this floor exists to avoid. A
    /// conservatively high floor costs relayers only a higher gas LIMIT (unused gas is refunded), so there is no
    ///      reason to keep it tight.
    uint256 private constant MIN_EXECUTION_GAS = 2_000_000;

    /// @dev `MisconfiguredMessageRelayed.kind`: the message had `destinationCaller = 0` (any caller could have
    ///      minted it straight into this adapter); it was relayed and delivered normally.
    uint8 private constant MISCONFIG_UNPINNED = 1;
    /// @dev `MisconfiguredMessageRelayed.kind`: the message was pinned to this adapter but minted elsewhere;
    ///      it was passed through to the transmitter and Circle minted to its own `mintRecipient`.
    uint8 private constant MISCONFIG_MINT_ELSEWHERE = 2;

    /// @dev Returned by `checkDestinationTargets` when the DstProof for this chain targets this
    ///      deployment, or when no DstProof names this chain at all.
    uint8 private constant MATCH_OK = 0;
    /// @dev Returned when the DstProof names an executor other than SUPER_DESTINATION_EXECUTOR.
    uint8 private constant MISMATCH_EXECUTOR = 1;
    /// @dev Returned when the DstProof names a validator other than SUPER_DESTINATION_VALIDATOR.
    uint8 private constant MISMATCH_VALIDATOR = 2;

    /// @notice Decoded hookData payload — the 6-tuple CCTPSendHook emits (same shape DebridgeAdapter decodes)
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

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The CCTP V2 MessageTransmitter used to receive + verify messages
    IMessageTransmitterV2 public immutable MESSAGE_TRANSMITTER;

    /// @notice The USDC token minted by CCTP on this chain
    IERC20 public immutable USDC;

    /// @notice The CCTP V2 TokenMessenger on this chain; its `localMinter()` owns the remote→local token registry
    /// @dev Read at call time rather than cached: Circle can rotate the minter (`addLocalMinter`/`removeLocalMinter`)
    ///      and this adapter is immutable.
    ITokenMessengerV2MinterSource public immutable TOKEN_MESSENGER;

    /// @notice The SuperDestinationExecutor for processing bridged executions
    ISuperDestinationExecutor public immutable SUPER_DESTINATION_EXECUTOR;

    /// @notice The destination validator wired into the executor, cached at construction
    address public immutable SUPER_DESTINATION_VALIDATOR;

    /// @notice Claimable escrow balances (failed, undeliverable or surplus credits): account => token => amount
    /// @dev Token is USDC on every path except the non-USDC CCTP mint escrow, which keys by the token minted.
    mapping(address account => mapping(address token => uint256 amount)) public failedTransfers;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a constructor argument is the zero address
    error ADDRESS_NOT_VALID();

    /// @notice Thrown when `tokenMessenger_` is not a live TokenMessengerV2 wired to `messageTransmitter_`
    /// @dev Checked at construction (no minter, or a different transmitter) so a wrong-but-populated address —
    ///      e.g. a chain where Circle's CREATE2 address differs — cannot deploy an adapter that reverts on every
    ///      relay with no admin to repoint it. Also thrown at runtime if Circle has removed the local minter.
    error TOKEN_MESSENGER_NOT_VALID();

    /// @notice Thrown when the message is too short to contain a BurnMessageV2 + hookData
    error MESSAGE_TOO_SHORT();

    /// @notice Thrown when the message mints elsewhere AND is not pinned to this adapter (not ours to relay)
    /// @dev A message minting elsewhere that IS pinned to this adapter is passed through instead (review F2).
    error MINT_RECIPIENT_MISMATCH();

    /// @notice Thrown when MessageTransmitterV2.receiveMessage returns false
    error RECEIVE_MESSAGE_FAILED();

    /// @notice Thrown when the amount is zero
    error ZERO_AMOUNT();

    /// @notice Thrown when claiming more than the available failed transfer balance
    error INSUFFICIENT_FAILED_BALANCE();

    /// @notice Thrown when the message header version is not CCTP V2
    error UNSUPPORTED_MESSAGE_VERSION();

    /// @notice Thrown when the BurnMessageV2 body version is not CCTP V2
    error UNSUPPORTED_BODY_VERSION();

    /// @notice Thrown when the message's destinationCaller is neither this adapter nor zero
    /// @dev Zero is accepted (review F1): rejecting it cannot prevent a direct transmitter call and would only
    ///      remove the honest relayer's chance to deliver first.
    error DESTINATION_CALLER_MISMATCH();

    /// @notice Thrown when the message's header recipient is not the wired TokenMessengerV2
    /// @dev Such a message is not a CCTP burn at all (see RECIPIENT_OFFSET); rejecting it before any external
    ///      call costs nothing — no burned funds exist behind it.
    error RECIPIENT_MISMATCH();

    /// @notice Thrown when `receiveMessage` succeeded but the creditable amount is zero: no balance delta of the
    ///         resolved local token, or (USDC path) an attested `amount - feeExecuted` of zero
    error NOTHING_MINTED();

    /// @notice Thrown when TokenMinterV2 has no local token registered for the message's (sourceDomain, burnToken)
    /// @dev The transmitter's own mint would revert on the same lookup, so nothing is lost by failing fast here
    ///      with a legible reason; the message stays unconsumed.
    error UNSUPPORTED_BURN_TOKEN();

    /// @notice Thrown when `checkDestinationTargets` is called by anyone other than this contract
    error INVALID_SENDER();

    /// @notice Thrown when insufficient gas remains to attempt the destination execution
    error INSUFFICIENT_GAS();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the minted USDC is transferred to the account
    event TransferSucceeded(address indexed account, address indexed token, uint256 amount);

    /// @notice Emitted whenever a balance is credited to `failedTransfers[account][token]`.
    /// @dev Fires on EVERY escrow credit so generic failed-transfer tooling sees all of them: a failed USDC
    ///      delivery, an over-mint surplus, an undecodable-hookData rescue (paired with
    ///      HookPayloadUndecodable) and a non-USDC mint (paired with NonUsdcMintEscrowed). `token` is USDC
    ///      except on the non-USDC path.
    event TransferFailed(address indexed account, address indexed token, uint256 amount);

    /// @notice Emitted when tokens were delivered but the executor call reverted
    /// @param account The intent account (funds are already delivered or escrowed to it)
    /// @param selector First 4 bytes of the revert data, or zero when the executor reverted with no data (OOG)
    /// @dev Only the bounded 4-byte selector is ever copied out of returndata (returnbomb-safe), mirroring
    ///      AcrossV3AdapterV2. Unlike Across, an empty reason does NOT revert the relay: the funds are already at
    ///      the account and the execution can be re-driven directly on the permissionless executor.
    /// @dev A normal (non-reverting) return from `processBridgedExecution` is NOT proof of execution:
    ///      it returns normally on three silent no-op paths — insufficient balance, an already-used
    ///      merkle root, and empty hook calldata — none of which emit this event. Each of those emits
    ///      its own SuperDestinationExecutor event (SuperDestinationExecutorReceivedButNotEnoughBalance /
    ///      ...ReceivedButRootUsedAlready / ...ReceivedButNoHooks vs SuperDestinationExecutorExecuted). An
    ///      indexer distinguishing
    ///      "executed" from "silently no-opped" must watch those, not just this adapter's events.
    event ExecutionFailed(address indexed account, bytes4 selector);

    /// @notice Emitted when the hookData tail could not be turned into a usable payload.
    /// @dev Covers three cases: the 6-tuple does not decode, `account == address(0)`, and
    ///      `account == address(this)` (a self-transfer would "succeed" and strand the funds). In all
    ///      three the minted USDC is escrowed to the attested `messageSender` rather than the relay
    ///      reverting, which would destroy the bridged funds permanently.
    /// @param messageSender The attested burner, credited with the rescued amount
    /// @param amount The escrowed amount
    event HookPayloadUndecodable(address indexed messageSender, uint256 amount);

    /// @notice Emitted when the signed DstProof for this chain names a different executor/validator.
    /// @dev Funds are still delivered; only the destination execution is skipped.
    /// @param account The intent account the funds were delivered to
    /// @param code MISMATCH_EXECUTOR (1) or MISMATCH_VALIDATOR (2)
    event DestinationTargetMismatch(address indexed account, uint8 code);

    /// @notice Emitted when the message minted a registered CCTP token other than USDC.
    /// @dev The signed intent is USDC-denominated, so no execution is attempted; the full minted delta is
    ///      escrowed to the attested burner under the minted token, claimable via `claimFailedTransfer`.
    /// @param messageSender The attested burner, credited with the minted amount
    /// @param token The local token that was minted
    /// @param amount The escrowed amount
    event NonUsdcMintEscrowed(address indexed messageSender, address indexed token, uint256 amount);

    /// @notice Emitted when a message the SDK should never have produced was still relayed safely.
    /// @dev Monitoring hook for SDK/backend regressions: kind MISCONFIG_UNPINNED (1) or MISCONFIG_MINT_ELSEWHERE (2).
    /// @param kind Which misconfiguration was observed
    /// @param mintRecipient The message's mintRecipient (this adapter for kind 1, the real recipient for kind 2)
    event MisconfiguredMessageRelayed(uint8 indexed kind, bytes32 mintRecipient);

    /// @notice Emitted when a recipient claims a previously failed transfer
    event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param messageTransmitter_ CCTP V2 MessageTransmitter on this chain
    /// @param tokenMessenger_ CCTP V2 TokenMessenger on this chain (must already have a local minter wired)
    /// @param usdc_ USDC token on this chain (the token CCTP mints for a Superform intent)
    /// @param superDestinationExecutor_ SuperDestinationExecutor on this chain
    constructor(
        address messageTransmitter_,
        address tokenMessenger_,
        address usdc_,
        address superDestinationExecutor_
    ) {
        if (
            messageTransmitter_ == address(0) || tokenMessenger_ == address(0) || usdc_ == address(0)
                || superDestinationExecutor_ == address(0)
        ) {
            revert ADDRESS_NOT_VALID();
        }
        // The two Circle immutables must belong to the same CCTP deployment: a live messenger (minter wired)
        // whose transmitter is the one this adapter will call. `code.length` alone would accept any contract
        // with a permissive fallback at the expected address.
        ITokenMessengerV2MinterSource messenger = ITokenMessengerV2MinterSource(tokenMessenger_);
        if (messenger.localMinter() == address(0) || messenger.localMessageTransmitter() != messageTransmitter_) {
            revert TOKEN_MESSENGER_NOT_VALID();
        }
        MESSAGE_TRANSMITTER = IMessageTransmitterV2(messageTransmitter_);
        TOKEN_MESSENGER = ITokenMessengerV2MinterSource(tokenMessenger_);
        USDC = IERC20(usdc_);
        SUPER_DESTINATION_EXECUTOR = ISuperDestinationExecutor(superDestinationExecutor_);
        SUPER_DESTINATION_VALIDATOR =
            IDestinationValidatorSource(superDestinationExecutor_).SUPER_DESTINATION_VALIDATOR();
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE + EXECUTE
    //////////////////////////////////////////////////////////////*/

    /// @notice Receives a CCTP V2 message, mints the bridged USDC, forwards it to the intent account,
    ///         and best-effort executes the signed destination intent.
    /// @dev PERMISSIONLESS — see contract-level NatSpec for why this is safe. The adapter must have been
    ///      set as the message's `mintRecipient` and `destinationCaller` on the source chain.
    /// @dev A message that mints a registered non-USDC CCTP token is consumed and escrowed to the attested
    ///      burner instead (see `_receiveNonUsdc`); no delivery and no execution happen on that path.
    /// @param message The raw CCTP V2 message bytes (contains the hookData payload as its tail)
    /// @param attestation The Circle attestation over keccak256(message)
    function receiveAndExecute(bytes calldata message, bytes calldata attestation) external nonReentrant {
        // 1. Fail-fast bounds, version and recipient checks before any external call.
        if (message.length < HOOKDATA_OFFSET) revert MESSAGE_TOO_SHORT();
        if (uint32(bytes4(message[0:4])) != SUPPORTED_MESSAGE_VERSION) revert UNSUPPORTED_MESSAGE_VERSION();
        if (uint32(bytes4(message[BODY_VERSION_OFFSET:BODY_VERSION_OFFSET + 4])) != SUPPORTED_BODY_VERSION) {
            revert UNSUPPORTED_BODY_VERSION();
        }
        {
            bytes32 selfWord = bytes32(uint256(uint160(address(this))));
            bytes32 destinationCaller = bytes32(message[DESTINATION_CALLER_OFFSET:DESTINATION_CALLER_OFFSET + 32]);
            // `destinationCaller` SHOULD pin to this adapter and the SDK must set it so (CCTPSendHook.sol:123
            // validates only mintRecipient). MessageTransmitterV2 enforces it only when non-zero, so a
            // zero-caller message can be received by ANY caller straight through the transmitter — minting
            // into this adapter with nothing forwarded (delta-only accounting, no sweep). Rejecting such a
            // message here cannot stop that bypass; it only removes the one outcome that saves the funds:
            // the honest relayer arriving first. So zero is ACCEPTED (review F1) and flagged by event; any
            // other third-party caller value is not ours to relay and is rejected.
            if (destinationCaller != selfWord && destinationCaller != bytes32(0)) revert DESTINATION_CALLER_MISMATCH();
            // The body is only a trustworthy BurnMessageV2 if Circle's TokenMessengerV2 is the one receiving it.
            if (
                bytes32(message[RECIPIENT_OFFSET:RECIPIENT_OFFSET + 32])
                    != bytes32(uint256(uint160(address(TOKEN_MESSENGER))))
            ) revert RECIPIENT_MISMATCH();
            bytes32 mintRecipient = bytes32(message[MINT_RECIPIENT_OFFSET:MINT_RECIPIENT_OFFSET + 32]);
            if (mintRecipient != selfWord) {
                // A burn minting elsewhere is not ours to relay — unless it is PINNED to us, in which case
                // nobody else can ever relay it (every direct `receiveMessage` reverts "Invalid caller") and
                // re-attestation cannot change `destinationCaller`. Pass it through: Circle mints straight to
                // `mintRecipient`, this adapter's balances are untouched, and the burn is not stranded
                // (review F2; the realistic trigger is a half-migrated SDK path keeping the old
                // mintRecipient = account with the new destinationCaller = adapter).
                if (destinationCaller != selfWord) revert MINT_RECIPIENT_MISMATCH();
                if (!MESSAGE_TRANSMITTER.receiveMessage(message, attestation)) revert RECEIVE_MESSAGE_FAILED();
                emit MisconfiguredMessageRelayed(MISCONFIG_MINT_ELSEWHERE, mintRecipient);
                return;
            }
            if (destinationCaller == bytes32(0)) emit MisconfiguredMessageRelayed(MISCONFIG_UNPINNED, mintRecipient);
        }

        // Read from the FIXED body before touching the tail — available even if hookData is garbage.
        address messageSender =
            address(uint160(uint256(bytes32(message[MESSAGE_SENDER_OFFSET:MESSAGE_SENDER_OFFSET + 32]))));

        // 1b. Resolve which LOCAL token this message mints, the same way the transmitter's mint path will.
        //     A registered non-USDC token (CCTP V2 is multi-token) is measured and escrowed instead of
        //     reverting: `destinationCaller` pins this message to this adapter, so a content-dependent
        //     revert here would strand the burned funds forever.
        address localToken = _resolveLocalToken(message);
        if (localToken != address(USDC)) {
            _receiveNonUsdc(message, attestation, IERC20(localToken), messageSender);
            return;
        }

        // 2. Receive the message: mints (amount - feeExecuted) USDC to this adapter.
        //    Measure the exact delta so donated / escrowed balances are never forwardable.
        uint256 pre = USDC.balanceOf(address(this));
        if (!MESSAGE_TRANSMITTER.receiveMessage(message, attestation)) revert RECEIVE_MESSAGE_FAILED();
        uint256 minted = USDC.balanceOf(address(this)) - pre;

        // 2b. Cross-check the measured delta against the attested body's own arithmetic. The two should
        //     agree exactly; forwarding the smaller keeps a hypothetical transmitter over-mint from ever
        //     draining escrowed balances, and keeps an under-mint from over-promising the account.
        uint256 claimed = uint256(bytes32(message[AMOUNT_OFFSET:AMOUNT_OFFSET + 32]))
            - uint256(bytes32(message[FEE_EXECUTED_OFFSET:FEE_EXECUTED_OFFSET + 32]));

        // A surplus over what the attested body claims is anomalous, but must not be silently retained
        // — it is credited to the intent account below (once decoded) so it stays claimable rather than
        // becoming dead weight in this contract.
        uint256 surplus;
        if (claimed < minted) {
            unchecked {
                // Safe: guarded by `claimed < minted` immediately above, so this cannot underflow.
                surplus = minted - claimed;
            }
            minted = claimed;
        }

        // Backstop only: step 1b already routed every registered non-USDC token to its own escrow path,
        // so with a real transmitter a zero USDC delta here is unreachable (`fee < amount` is enforced at
        // burn). Reverting unwinds the mint and leaves the nonce unspent rather than consuming it for
        // nothing.
        if (minted == 0) revert NOTHING_MINTED();

        // 3. Decode the executor payload from the attested hookData tail.
        //    Isolated behind a self-call so a malformed 6-tuple cannot revert the relay. A revert here
        //    would be PERMANENT LOSS, not a retry: the CCTP burn is irreversible and these message
        //    bytes are immutable, so the same panic would recur on every future attempt. Instead the
        //    minted USDC is escrowed to `messageSender` — attested, unspoofable, and for a
        //    Superform-originated burn the depositing account itself.
        HookPayload memory p;
        bool decoded;
        try this.decodeHookPayload(message) returns (HookPayload memory d) {
            p = d;
            decoded = true;
        } catch {
            // malformed hookData — fall through to the escrow below
        }

        // `account == address(this)` is also unusable: a self-transfer SUCCEEDS trivially, so the funds
        // would never be credited anywhere and would become indistinguishable from a donation —
        // permanently stuck (found by review). Escrow to the attested burner instead of reverting.
        if (!decoded || p.account == address(0) || p.account == address(this)) {
            uint256 rescued = minted + surplus;
            failedTransfers[messageSender][address(USDC)] += rescued;
            // Both events fire on purpose: TransferFailed keeps generic failedTransfers-balance tooling
            // working for this credit, while HookPayloadUndecodable lets consumers tell "never
            // attempted — hookData was garbage" apart from a genuine failed transfer to a known account.
            emit TransferFailed(messageSender, address(USDC), rescued);
            emit HookPayloadUndecodable(messageSender, rescued);
            return;
        }

        address account = p.account;

        // Credit any over-mint surplus (see the clamp above) so it remains claimable by the account.
        if (surplus != 0) {
            failedTransfers[account][address(USDC)] += surplus;
            emit TransferFailed(account, address(USDC), surplus);
        }

        // 3b. If the signed intent carries a DstProof for this chain, it must name THIS executor and
        //     validator. A mismatch means the intent was signed for a different deployment, so the
        //     execution could never succeed. We do NOT revert on it — the funds are still delivered
        //     below and only the execution step is skipped (see the `if (!targetsMatch) return;` guard
        //     in step 5). Reverting on message content would be a permanent burn: the CCTP burn is
        //     irreversible and these bytes are immutable, so the same revert would recur forever.
        //     AcrossV3AdapterV2:176-187 can revert safely only because an unfilled Across deposit
        //     refunds at origin; CCTP has no refund path.
        //     A message with no proof for this chain is left alone: funds still get delivered and the
        //     executor no-ops, matching StargateAdapterV2's graceful NoDstProofForChain handling.
        //     Decode is isolated behind a self-call so a malformed sigData blob cannot revert the relay
        //     (abi.decode panics on garbage); a decode failure is treated the same as MATCH_OK.
        bool targetsMatch = true;
        try this.checkDestinationTargets(p.sigData) returns (uint8 code) {
            if (code != MATCH_OK) {
                targetsMatch = false;
                emit DestinationTargetMismatch(account, code);
            }
        } catch {
            // Undecodable sigData: the executor's own signature check fails harmlessly below and the
            // funds are still delivered. Nothing to assert.
        }

        // 4. Fund the account first (so the executor can check its balance), escrowing on failure.
        if (_tryTransfer(account, minted)) {
            emit TransferSucceeded(account, address(USDC), minted);
        } else {
            failedTransfers[account][address(USDC)] += minted;
            emit TransferFailed(account, address(USDC), minted);
        }

        // 5. Best-effort execution behind an explicit gas floor, so a permissionless caller cannot
        //    starve the executor into the catch branch (see MIN_EXECUTION_GAS). All remaining gas is
        //    forwarded — no stipend, so long hook chains are not capped.
        // A target mismatch means the intent was signed against a different deployment, so the
        // execution cannot succeed. Skip it — but the funds have ALREADY been delivered above and stay
        // delivered. Reverting here would be catastrophic: the CCTP burn is irreversible and the
        // mismatching sigData is immutable inside the attested message, so every future relay attempt
        // would revert identically and the USDC would be permanently destroyed. (AcrossV3AdapterV2 can
        // revert safely because an unfilled Across deposit refunds; CCTP has no refund path.)
        if (!targetsMatch) return;

        if (gasleft() < MIN_EXECUTION_GAS) revert INSUFFICIENT_GAS();

        // Bare catch → the full revert returndata is never copied (returnbomb-safe); only the 4-byte selector
        // is read for observability. A reverting hook set cannot unwind the already-delivered USDC, and the
        // execution stays re-drivable directly on the executor (root unused, payload public).
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

    /// @notice Decode the 6-tuple hookData tail.
    /// @dev External ONLY so `receiveAndExecute` can self-call it and contain `abi.decode` panics on a
    ///      malformed tail. MUST only be called by this contract.
    /// @param message The full attested CCTP message
    /// @return p The decoded payload
    function decodeHookPayload(bytes calldata message) external view returns (HookPayload memory p) {
        if (msg.sender != address(this)) revert INVALID_SENDER();
        (p.initData, p.executorCalldata, p.account, p.dstTokens, p.intentAmounts, p.sigData) =
            abi.decode(message[HOOKDATA_OFFSET:], (bytes, bytes, address, address[], uint256[], bytes));
    }

    /// @notice Report whether the DstProof for this chain targets this deployment's executor/validator.
    /// @dev External ONLY so `receiveAndExecute` can self-call it and contain `abi.decode` panics on a
    ///      malformed `sigData` — mirrors StargateAdapterV2's `handleCompose` self-call (:239-247).
    ///      Returns a code rather than reverting so the caller can distinguish "malformed blob"
    ///      (caught, treated as MATCH_OK) from "explicit mismatch" (funds delivered, execution skipped).
    /// @param sigData The raw SignatureData blob appended by the source hook
    /// @dev MUST only be called by this contract; it is NOT a general-purpose public API despite
    ///      being view-only. Guard mirrors StargateAdapterV2.handleCompose (:268).
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
    /// @param token The token to claim (USDC, or the token minted on the non-USDC escrow path)
    /// @param amount The amount to claim
    function claimFailedTransfer(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZERO_AMOUNT();

        uint256 available = failedTransfers[msg.sender][token];
        if (available < amount) revert INSUFFICIENT_FAILED_BALANCE();

        failedTransfers[msg.sender][token] = available - amount;
        IERC20(token).safeTransfer(msg.sender, amount);

        emit FailedTransferClaimed(msg.sender, token, amount);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Resolve the local token this message mints, exactly as TokenMinterV2.mint will.
    /// @dev `burnToken` is the SOURCE-chain address, so it cannot be compared to USDC directly; the
    ///      TokenMinterV2 registry keyed by (sourceDomain, burnToken) is the only sound translation — and it
    ///      is the same `_getLocalToken` call Circle's mint path performs, so a zero here implies the mint
    ///      would revert too. Every revert in this function precedes `receiveMessage`, so the message stays
    ///      unconsumed. The minter is read live (not cached) because Circle can rotate it.
    /// @param message The full attested CCTP message
    /// @return localToken The registered local token; never address(0)
    function _resolveLocalToken(bytes calldata message) internal view returns (address localToken) {
        address minter = TOKEN_MESSENGER.localMinter();
        // Circle removed the minter: their own mint would revert "Local minter is not set"; give the
        // relayer a legible reason rather than an empty revert from a call to address(0).
        if (minter == address(0)) revert TOKEN_MESSENGER_NOT_VALID();
        localToken = ITokenMinterV2(minter)
            .getLocalToken(
                uint32(bytes4(message[SOURCE_DOMAIN_OFFSET:SOURCE_DOMAIN_OFFSET + 4])),
                bytes32(message[BURN_TOKEN_OFFSET:BURN_TOKEN_OFFSET + 32])
            );
        if (localToken == address(0)) revert UNSUPPORTED_BURN_TOKEN();
    }

    /// @notice Non-USDC branch of `receiveAndExecute`: consume the message and escrow the minted delta.
    /// @dev Measures the minted delta of the resolved token and escrows it to the attested burner. No
    ///      hookData decode and no execution —
    ///      the signed intent's `dstTokens`/`intentAmounts` are USDC-denominated and the executor
    ///      balance-gates on them, so an execution could only no-op or misbehave. Escrowing to
    ///      `messageSender` (the depositing account itself for a Superform-originated burn) mirrors the
    ///      undecodable-hookData path and needs nothing from the untrusted tail.
    /// @param message The full attested CCTP message
    /// @param attestation The Circle attestation over keccak256(message)
    /// @param token The local token TokenMinterV2 resolved for this message (never USDC here)
    /// @param messageSender The attested burner, credited with the minted delta
    function _receiveNonUsdc(
        bytes calldata message,
        bytes calldata attestation,
        IERC20 token,
        address messageSender
    )
        internal
    {
        uint256 pre = token.balanceOf(address(this));
        if (!MESSAGE_TRANSMITTER.receiveMessage(message, attestation)) revert RECEIVE_MESSAGE_FAILED();
        // Delta only — a pre-existing or donated balance of this token is never creditable.
        uint256 minted = token.balanceOf(address(this)) - pre;
        if (minted == 0) revert NOTHING_MINTED();

        failedTransfers[messageSender][address(token)] += minted;
        // Both events on purpose: TransferFailed keeps generic escrow tooling working; the specific
        // event tells consumers this was a token-routing outcome, not a failed delivery to a known account.
        emit TransferFailed(messageSender, address(token), minted);
        emit NonUsdcMintEscrowed(messageSender, address(token), minted);
    }

    /// @notice Attempt to transfer USDC to an account, returning success/failure instead of reverting.
    /// @dev Low-level call handles non-standard ERC20s that don't return a bool.
    /// @param account The recipient
    /// @param amount The amount to transfer
    /// @return success Whether the transfer succeeded
    function _tryTransfer(address account, uint256 amount) internal returns (bool success) {
        (bool callSuccess, bytes memory returnData) =
            address(USDC).call(abi.encodeCall(IERC20.transfer, (account, amount)));
        // NOT abi.decode(returnData,(bool)): the ABI decoder PANICS on a 32-byte word that is not 0 or
        // 1 (reproduced on the sibling RelayAdapterV2), so a length guard alone cannot keep this helper
        // from reverting. Read the raw word instead; any non-`1` payload reads as failure and escrows,
        // which is this helper's contract.
        success = callSuccess && (returnData.length == 0 || (returnData.length >= 32 && _isTrueWord(returnData)));
    }

    /// @dev Reads the first return word without abi.decode, so a non-boolean word yields false, never a panic.
    function _isTrueWord(bytes memory data) internal pure returns (bool isTrue) {
        bytes32 word;
        assembly {
            word := mload(add(data, 32))
        }
        return word == bytes32(uint256(1));
    }
}
