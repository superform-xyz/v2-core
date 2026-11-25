// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// Superform
import { GyldBondRegistry } from "./GyldBondRegistry.sol";
import { GyldBondYieldSourceOracle } from "./GyldBondYieldSourceOracle.sol";
import { GyldDeliveryReceiver } from "./GyldDeliveryReceiver.sol";

/// @title GyldInTransitRegistry
/// @author Superform Labs
/// @notice What each strategy has at Gyld through the Investor API: cash sent to Gyld's deposit address and not yet
///         minted against, bonds sent to the redeem holding wallet and not yet paid out. Also the source of the
///         pinned destinations, the caps and each strategy's delivery receiver.
/// @dev WHY. The Investor API is a brokerage account: the chain sees a transfer out, and the mint or payout lands
///      later in a Gyld-signed transaction. Without a record of what is in transit the PPS drops when cash leaves
///      and jumps when tokens land. `GyldBondYieldSourceOracle` values the open lots. A lot older than
///      `maxTransitAge` is STALE: it keeps its value but blocks new deposits for the pair until it settles.
/// @dev ONE LOT PER ORDER. Every record opens a lot (one transfer, one kind, its own clock). A settle names the
///      lot and can only decrease it, so a partial fill is bounded by its order and a stalled order ages alone.
/// @dev SETTLES ARE RECEIVER-CHECKED AND NAV-BANDED. Gyld delivers to the strategy's `GyldDeliveryReceiver`
///      (its withdrawal address and mint wallet), never to the strategy. A settle sweeps what it acknowledges out
///      of the receiver and shrinks the lot in the same transaction: only what reached this strategy's receiver can
/// back a settle (which Gyld order it belongs to is the reconciler's claim; `apiRef` is the audit trail), the
/// strategy's own balance is never read, and nothing is counted twice because the oracle ignores the
///      receiver. The decrease must sit in a band around the delivered value at the live NAV: at least net of
///      the expected fee and the instrument's tolerance (no dust settles), at most the tolerance above (no full
///      delivery swept against a sliver of decrease). Fills outside the band are governance's to book through
///      the timelocked manual settle, which is netted from the valuation from the proposal on. `apiRef` is
///      anti-replay only.
/// @dev WHO MAY WRITE. Records are made by the account itself (hooks execute as the account) and only ever
///      increase its own entries, within the caps, with the transfer verified in the same batch. Decreases are
///      RECONCILER settles backed by the receiver or MANAGER manual settles behind the delay.
/// @dev ONE DEPOSIT ADDRESS PER STRATEGY, NOT ONE LEDGER. Gyld keeps one cash ledger per legal entity with several
///      whitelisted addresses, so a distinct deposit address does NOT segregate cash before delivery: anything the
///      legal entity holds at Gyld can fund any order. The address guard (`DEPOSIT_ADDRESS_IN_USE`, checked on set, at
///      proposal and at execution; a released address with open cash lots stays off limits) keeps deposits and
///      deliveries attributable per strategy. Segregation of the ledger itself is an onboarding fact: one funded
///      principal per legal-entity ledger, which `solePrincipal` enforces on chain when set. Destinations and the
///      valuation oracle change behind `DESTINATION_DELAY` after their first set; every lot keeps its destination.
/// @dev TWO CAPS, both fail-closed at zero: `maxCashInTransit` per strategy and `maxTotalCashInTransit` across
///      strategies, per instrument, checked on every deposit record.
/// @dev NOT PROTECTED HERE: Gyld actually delivering to the receiver (an onboarding fact), the order price, Gyld's
///      custody and solvency, and which Gyld order a settle belongs to (`apiRef` is an audit trail, not a proof).
contract GyldInTransitRegistry is AccessControl {
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZERO_ADDRESS();
    error ZERO_AMOUNT();
    error INVALID_AGE();
    /// @notice A fee haircut above `MAX_TRANSIT_FEE_BPS`
    error INVALID_FEE();
    error INSTRUMENT_NOT_REGISTERED();
    /// @notice The (bond, cash) pair is not the registered instrument's pair
    error PAIR_NOT_APPROVED();
    /// @notice The account has no destination of the kind this record needs
    error DESTINATION_NOT_SET();
    /// @notice `maxTransitAge` is zero; records are refused rather than valued forever
    error TRANSIT_AGE_NOT_CONFIGURED();
    /// @notice The account already has an open lot older than `maxTransitAge` for this instrument
    error TRANSIT_STALE();
    /// @notice Outstanding cash plus this record would exceed the instrument's cap
    error CAP_EXCEEDED(uint256 outstanding, uint256 cap);
    /// @notice The instrument's total cash at Gyld across every strategy would exceed `maxTotalCashInTransit`
    error GLOBAL_CAP_EXCEEDED(uint256 outstanding, uint256 cap);
    /// @notice No lot with this id has been recorded
    error LOT_NOT_FOUND(uint256 lotId);
    /// @notice A cash settle named a bond lot, or the reverse
    error LOT_KIND_MISMATCH(uint256 lotId);
    /// @notice A settlement tried to clear more than the lot still has open
    error EXCEEDS_OPEN(uint256 open, uint256 requested);
    /// @notice `settleMint` with nothing received is a loss and must go through the manual path
    error ZERO_BONDS_RECEIVED();
    /// @notice `settleRedemption` with nothing returned is a loss and must go through the manual path
    error ZERO_CASH_RETURNED();
    /// @notice The receiver does not hold what this settle claims Gyld delivered
    error DELIVERY_NOT_FOUND(uint256 lotId, uint256 inReceiver, uint256 required);
    /// @notice The delivered value does not cover the decrease at the live NAV within the instrument's bounds
    error SETTLE_BELOW_NAV(uint256 lotId, uint256 deliveredValue, uint256 requiredValue);
    /// @notice The delivery is worth more than the decrease plus the instrument's tolerance: under-reported decrease
    error SETTLE_ABOVE_NAV(uint256 lotId, uint256 deliveredValue, uint256 allowedValue);
    /// @notice The strategy received less than the registry swept (fee-on-transfer or restricted token)
    error SWEEP_SHORT(address token, uint256 expected, uint256 received);
    /// @notice The token is an instrument's bond with lots still open for this account: settle or write off first
    error RESCUE_BLOCKED(address token);
    /// @notice The oracle does not pin this registry
    error ORACLE_MISMATCH(address oracle);
    /// @notice The first oracle is set; later changes go through the timelocked proposal
    error ORACLE_ALREADY_SET();
    /// @notice Open cash lots still point at this deposit address: another strategy cannot take it yet
    error DEPOSIT_ADDRESS_HAS_OPEN_LOTS(address depositAddress, uint256 openLots);
    /// @notice A sole principal is set and this account is not it: only that strategy may send cash to Gyld
    error NOT_SOLE_PRINCIPAL(address principal);
    /// @notice The pair already has `MAX_OPEN_LOTS_PER_PAIR` lots open: settle before recording more
    error TOO_MANY_OPEN_LOTS(uint256 open, uint256 max);
    /// @notice The instrument's cash token changed since the lot was recorded: priced settles need the manual path
    error INSTRUMENT_DENOMINATION_CHANGED(uint256 lotId);
    /// @notice A manual sweep may only move the lot's bond or cash token
    error INVALID_SWEEP_TOKEN(address token);
    /// @notice The recognised loss of a manual sweep cannot exceed the decrease
    error LOSS_EXCEEDS_DECREASE(uint256 loss, uint256 amount);
    /// @notice No usable NAV for the tie (oracle unset, or `previewNav` reports a failure code)
    error NAV_UNAVAILABLE(uint8 code);
    /// @notice The manual settle's execution window has passed; propose again
    error CHANGE_EXPIRED();
    /// @notice The receiver for this account does not exist (destinations never set)
    error RECEIVER_NOT_SET();
    /// @notice This Gyld reference has already settled something
    error API_REF_REUSED(bytes32 apiRef);
    /// @notice A manual settle for this lot is already pending
    error MANUAL_SETTLE_PENDING(uint256 lotId);
    error DESTINATIONS_ALREADY_SET();
    /// @notice Another strategy already trades through the Gyld account behind this deposit address
    error DEPOSIT_ADDRESS_IN_USE(address depositAddress, address holder);
    error CHANGE_NOT_PENDING();
    error CHANGE_TIMELOCK_NOT_ELAPSED();

    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/

    /// @notice Which leg a lot belongs to
    enum LotKind {
        CASH_OUT,
        BONDS_OUT
    }

    /// @notice One recorded transfer to Gyld, settled on its own
    /// @param account The account that recorded it (`msg.sender` of the record)
    /// @param kind Cash to the deposit address, or bonds to the holding wallet
    /// @param openedAt When it was recorded
    /// @param bondToken The instrument
    /// @param destination Where the tokens went: the account's deposit address or holding wallet AT RECORD TIME.
    ///        A later destination change never re-labels an open lot.
    /// @param cashToken The instrument's cash token at record time, the token a payout or cash return is swept in
    /// @param recorded The amount recorded, in cash units (CASH_OUT) or bond units (BONDS_OUT). Also the existence
    ///        sentinel: zero means the id was never issued (zero amounts are refused on record).
    /// @param open What is still unsettled; zero means the lot is closed
    struct Lot {
        address account;
        LotKind kind;
        uint64 openedAt;
        address bondToken;
        address destination;
        address cashToken;
        uint256 recorded;
        uint256 open;
    }

    /// @notice A manager-proposed decrease that bypasses the receiver: a loss, or a delivery that reached the
    ///         strategy by another route. Executable between `executeAt` and `executeAt + MANUAL_SETTLE_WINDOW`.
    ///         Recognised in valuation (netted out of the position) from the proposal on.
    struct PendingManualSettle {
        uint256 amount; // the decrease
        uint256 netted; // the part recognised as a loss now (netted from the valuation from the proposal on)
        uint256 sweepAmount; // optional: delivered asset to sweep from the receiver at execution, atomically
        address sweepToken;
        bytes32 apiRef;
        uint64 executeAt;
    }

    /// @notice One strategy's pair at Gyld
    /// @param depositAddress Gyld's deposit address for that strategy's Gyld account (`GET /deposit/address`)
    /// @param redeemHoldingWallet Gyld's redeem holding wallet for it (`GET /portfolio.redeem_holding_wallet`)
    struct Destinations {
        address depositAddress;
        address redeemHoldingWallet;
    }

    /// @notice What one account has at Gyld for one instrument: the sums of its open lots
    /// @param cashOut Cash units sent to the deposit address and not yet minted against
    /// @param bondsOut Bond units sent to the holding wallet and not yet paid out
    /// @param oldestOpenAt `openedAt` of the oldest still-open lot; zero when nothing is open
    /// @dev No exit NAV is kept: bonds in transit are still bonds and the oracle marks them at the LIVE NAV,
    ///      exactly like wallet bonds.
    struct Transit {
        uint256 cashOut;
        uint256 bondsOut;
        uint64 oldestOpenAt;
    }

    struct PendingDestinations {
        address depositAddress;
        address redeemHoldingWallet;
        uint64 executeAt;
    }

    struct PendingOracle {
        address oracle;
        uint64 executeAt;
    }

    /// @dev Per-(account, instrument) aggregates plus the lot queue. Lots are appended in time order; `head`
    ///      is the index of the oldest lot that may still be open (everything before it is closed), so the
    ///      staleness read is O(1) and a settle advances it past closed lots.
    struct Position {
        uint256 cashOut;
        uint256 bondsOut;
        uint256 pendingCashDecrease;
        uint256 pendingBondsDecrease;
        uint256 openLots; // both kinds; bounded by MAX_OPEN_LOTS_PER_PAIR
        uint256 pendingCount; // proposals on open lots: O(1) `hasPendingManualSettle`
        uint256 head;
        uint256[] lotIds;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant RECONCILER_ROLE = keccak256("RECONCILER_ROLE");
    /// @notice Delay on every destination CHANGE after the first set
    uint256 public constant DESTINATION_DELAY = 2 days;
    /// @notice Upper bound on `maxTransitAge`; a year-old lot is not "in transit"
    uint256 public constant MAX_TRANSIT_AGE_CEILING = 365 days;

    /// @notice Ceiling on the expected-fee haircut the oracle applies to in-transit value (10%).
    uint256 public constant MAX_TRANSIT_FEE_BPS = 1000;
    /// @notice Delay on every manual (receiver-unchecked) settle: a loss or an override
    uint256 public constant MANUAL_SETTLE_DELAY = 2 days;
    /// @notice How long after its delay a manual settle stays executable before it must be re-proposed
    uint256 public constant MANUAL_SETTLE_WINDOW = 7 days;
    /// @notice Open lots per (account, instrument), both kinds. Bounds every per-pair walk (`_advanceHead`, views)
    ///         and is far above any sane book: hitting it means settles have stopped, which is the incident.
    uint256 public constant MAX_OPEN_LOTS_PER_PAIR = 256;
    uint256 private constant BPS = 10_000;

    /// @notice The approved-instrument list; pairs and caps are validated against it
    GyldBondRegistry public immutable BOND_REGISTRY;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Lots older than this make the position stale: new deposits blocked until settled (value unchanged)
    uint256 public maxTransitAge;
    /// @notice Per-instrument cap on OUTSTANDING cash at Gyld, per account; zero disables the instrument
    mapping(address bondToken => uint256 cap) public maxCashInTransit;
    /// @notice Per-instrument cap on OUTSTANDING cash at Gyld summed over every account; zero disables the instrument
    mapping(address bondToken => uint256 cap) public maxTotalCashInTransit;

    /// @notice Expected Gyld fee on an in-transit leg, in bps, netted out of in-transit value by the oracle.
    /// @dev One figure for both legs: the upfront mint fee on cash out and the redemption fee on bonds out. It
    ///      stops the price per share stepping down when the real fee is booked at settlement.
    ///      Gyld's AUM fee is already inside the NAV and needs nothing here. Zero = no haircut.
    mapping(address bondToken => uint256 bps) public transitFeeBps;
    /// @notice Sum of `cashOut` over every account, for `getTVL`
    mapping(address bondToken => uint256 total) public totalCashInTransit;
    /// @notice Sum of pending manual cash decreases over every account, netted out of `getTVL`
    mapping(address bondToken => uint256 total) public totalPendingCashDecrease;
    /// @notice The oracle the settle NAV tie reads; MANAGER-set because the oracle is deployed after this contract
    GyldBondYieldSourceOracle public valuationOracle;
    /// @notice A proposed oracle change, executable after `DESTINATION_DELAY` (the first set is immediate)
    PendingOracle public pendingValuationOracle;

    /// @notice Number of lots ever recorded; ids run from 1 to this value
    uint256 public lotCount;

    /// @notice A proposed destination change per account; `executeAt == 0` means none pending
    mapping(address account => PendingDestinations) public pendingDestinations;

    mapping(address account => Destinations) private _destinations;
    /// @notice The strategy that owns a deposit address (one deposit address per strategy); zero when free
    mapping(address depositAddress => address account) public accountOfDepositAddress;
    /// @notice Open CASH_OUT lots pinned to a deposit address; while non-zero no OTHER strategy may claim it
    mapping(address depositAddress => uint256 count) public openCashLotsAt;
    /// @notice Open lots of the account that may still be paid in `token` (cash returns and payouts land in the
    ///         lot's cash token): a rescue of that token is refused while any is open
    mapping(address account => mapping(address token => uint256 count)) public openLotsPayingIn;
    /// @notice When set, the only account allowed to record cash out: Gyld's ledger is per legal entity, so one
    ///         funded principal per ledger is how pre-delivery cash stays segregated. Zero = no restriction.
    address public solePrincipal;
    /// @notice Each strategy's delivery receiver; created with its first destinations
    mapping(address account => GyldDeliveryReceiver receiver) public receiverOf;
    /// @notice Every Gyld reference that has settled something (or is reserved by a pending manual settle)
    mapping(bytes32 apiRef => bool used) public apiRefUsed;
    /// @notice Pending manual settles, one per lot; `executeAt == 0` means none
    mapping(uint256 lotId => PendingManualSettle) public pendingManualSettles;

    mapping(uint256 lotId => Lot) private _lots;
    mapping(address account => mapping(address bondToken => Position)) private _positions;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event DestinationsSet(address indexed account, address indexed depositAddress, address indexed redeemHoldingWallet);
    event DestinationsProposed(
        address indexed account, address indexed depositAddress, address indexed redeemHoldingWallet, uint256 executeAt
    );
    event DestinationsCancelled(address indexed account);
    /// @notice The strategy's mailbox for Gyld deliveries exists; whitelist it at Gyld (P1)
    event ReceiverCreated(address indexed account, address indexed receiver);
    event ValuationOracleSet(address indexed oracle);
    event ValuationOracleProposed(address indexed oracle, uint64 executeAt);
    event ValuationOracleCancelled();
    event SolePrincipalSet(address indexed principal);
    event ManualSweepAttached(uint256 indexed lotId, address indexed token, uint256 sweepAmount, uint256 netted);
    event ManualSweepExecuted(uint256 indexed lotId, address indexed token, uint256 sweepAmount);
    /// @notice Governance moved a stray balance out of a receiver into its strategy (not a settle: no lot moved)
    event ReceiverRescued(address indexed account, address indexed token, uint256 amount);
    event MaxTransitAgeUpdated(uint256 maxTransitAge);
    event MaxCashInTransitUpdated(address indexed bondToken, uint256 cap);
    event MaxTotalCashInTransitUpdated(address indexed bondToken, uint256 cap);
    event TransitFeeUpdated(address indexed bondToken, uint256 bps);
    /// @notice A cash lot opened. The bot stores `lotId` next to the Gyld request it creates for it.
    event CashOutRecorded(
        address indexed account,
        address indexed bondToken,
        uint256 indexed lotId,
        address cashToken,
        uint256 amount,
        uint256 newCashOut
    );
    /// @notice A bond lot opened
    event BondsOutRecorded(
        address indexed account,
        address indexed bondToken,
        uint256 indexed lotId,
        address cashToken,
        uint256 shares,
        uint256 newBondsOut
    );
    event MintSettled(
        address indexed account,
        uint256 indexed lotId,
        bytes32 indexed apiRef,
        address bondToken,
        uint256 cashConsumed,
        uint256 bondsReceived,
        uint256 lotOpen,
        uint256 remainingCashOut
    );
    /// @notice A manager-proposed decrease (a loss, or an override of the receiver check) is waiting out its delay;
    ///         valuation already nets it out
    event ManualSettleProposed(
        address indexed account, uint256 indexed lotId, bytes32 indexed apiRef, uint256 amount, uint256 executeAt
    );
    event ManualSettleCancelled(uint256 indexed lotId);
    /// @notice The lot decreased without a receiver check. For a CASH_OUT lot this is the loss path.
    event ManualSettled(
        address indexed account,
        uint256 indexed lotId,
        bytes32 indexed apiRef,
        address bondToken,
        LotKind kind,
        uint256 amount,
        uint256 lotOpen,
        uint256 remainingOpen
    );
    event CashReturnSettled(
        address indexed account,
        uint256 indexed lotId,
        bytes32 indexed apiRef,
        address bondToken,
        uint256 cashReturned,
        uint256 lotOpen,
        uint256 remainingCashOut
    );
    event RedemptionSettled(
        address indexed account,
        uint256 indexed lotId,
        bytes32 indexed apiRef,
        address bondToken,
        uint256 bondsConsumed,
        uint256 cashReturned,
        uint256 lotOpen,
        uint256 remainingBondsOut
    );
    event ReturnSettled(
        address indexed account,
        uint256 indexed lotId,
        bytes32 indexed apiRef,
        address bondToken,
        uint256 bondsReturned,
        uint256 lotOpen,
        uint256 remainingBondsOut
    );

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param admin_ Holds every role at birth; handed to governance and the reconciler by script
    /// @param bondRegistry_ The approved-instrument list
    constructor(address admin_, address bondRegistry_) {
        if (admin_ == address(0) || bondRegistry_ == address(0)) revert ZERO_ADDRESS();
        BOND_REGISTRY = GyldBondRegistry(bondRegistry_);
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(MANAGER_ROLE, admin_);
        _grantRole(RECONCILER_ROLE, admin_);
    }

    /*//////////////////////////////////////////////////////////////
                           MANAGER: CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice First-time set of one strategy's pair. Immediate, because nothing of that strategy's can be in
    ///         transit yet. Until this runs the strategy can neither deposit nor redeem.
    function setDestinations(
        address account,
        address depositAddress_,
        address redeemHoldingWallet_
    )
        external
        onlyRole(MANAGER_ROLE)
    {
        if (account == address(0) || depositAddress_ == address(0) || redeemHoldingWallet_ == address(0)) {
            revert ZERO_ADDRESS();
        }
        Destinations storage d = _destinations[account];
        if (d.depositAddress != address(0) || d.redeemHoldingWallet != address(0)) revert DESTINATIONS_ALREADY_SET();
        _claimDepositAddress(account, depositAddress_);
        d.depositAddress = depositAddress_;
        d.redeemHoldingWallet = redeemHoldingWallet_;
        _ensureReceiver(account);
        emit DestinationsSet(account, depositAddress_, redeemHoldingWallet_);
    }

    /// @notice Propose a change of one strategy's pair; executable after `DESTINATION_DELAY`
    function proposeDestinations(
        address account,
        address depositAddress_,
        address redeemHoldingWallet_
    )
        external
        onlyRole(MANAGER_ROLE)
    {
        if (account == address(0) || depositAddress_ == address(0) || redeemHoldingWallet_ == address(0)) {
            revert ZERO_ADDRESS();
        }
        _checkDepositAddressFree(account, depositAddress_); // early feedback; checked again at execution
        uint64 executeAt = uint64(block.timestamp + DESTINATION_DELAY);
        pendingDestinations[account] = PendingDestinations(depositAddress_, redeemHoldingWallet_, executeAt);
        emit DestinationsProposed(account, depositAddress_, redeemHoldingWallet_, executeAt);
    }

    function executeDestinations(address account) external onlyRole(MANAGER_ROLE) {
        PendingDestinations memory p = pendingDestinations[account];
        if (p.executeAt == 0) revert CHANGE_NOT_PENDING();
        if (block.timestamp < p.executeAt) revert CHANGE_TIMELOCK_NOT_ELAPSED();
        delete pendingDestinations[account];
        _claimDepositAddress(account, p.depositAddress);
        _destinations[account] = Destinations(p.depositAddress, p.redeemHoldingWallet);
        _ensureReceiver(account);
        emit DestinationsSet(account, p.depositAddress, p.redeemHoldingWallet);
    }

    function cancelDestinations(address account) external onlyRole(MANAGER_ROLE) {
        if (pendingDestinations[account].executeAt == 0) revert CHANGE_NOT_PENDING();
        delete pendingDestinations[account];
        emit DestinationsCancelled(account);
    }

    /// @notice Risk tolerance, immediate. Zero is refused: it would make every record revert.
    function setMaxTransitAge(uint256 maxTransitAge_) external onlyRole(MANAGER_ROLE) {
        if (maxTransitAge_ == 0 || maxTransitAge_ > MAX_TRANSIT_AGE_CEILING) revert INVALID_AGE();
        maxTransitAge = maxTransitAge_;
        emit MaxTransitAgeUpdated(maxTransitAge_);
    }

    /// @notice Per-instrument cap on outstanding cash at Gyld. Zero disables new deposits for the instrument.
    function setMaxCashInTransit(address bondToken, uint256 cap) external onlyRole(MANAGER_ROLE) {
        if (!BOND_REGISTRY.isRegistered(bondToken)) revert INSTRUMENT_NOT_REGISTERED();
        maxCashInTransit[bondToken] = cap;
        emit MaxCashInTransitUpdated(bondToken, cap);
    }

    /// @notice Per-instrument cap on OUTSTANDING cash at Gyld across ALL strategies, immediate; zero disables the
    ///         instrument for new deposits. Bounds the chain's exposure to one instrument, on top of the per-strategy
    ///         cap. Lowering it below what is already out blocks new deposits until settles bring the total back.
    function setMaxTotalCashInTransit(address bondToken, uint256 cap) external onlyRole(MANAGER_ROLE) {
        if (!BOND_REGISTRY.isRegistered(bondToken)) revert INSTRUMENT_NOT_REGISTERED();
        maxTotalCashInTransit[bondToken] = cap;
        emit MaxTotalCashInTransitUpdated(bondToken, cap);
    }

    /// @notice Expected fee on in-transit legs for an instrument, in bps. At most `MAX_TRANSIT_FEE_BPS`.
    function setTransitFeeBps(address bondToken, uint256 bps) external onlyRole(MANAGER_ROLE) {
        if (!BOND_REGISTRY.isRegistered(bondToken)) revert INSTRUMENT_NOT_REGISTERED();
        if (bps > MAX_TRANSIT_FEE_BPS) revert INVALID_FEE();
        transitFeeBps[bondToken] = bps;
        emit TransitFeeUpdated(bondToken, bps);
    }

    /// @notice First set of the oracle whose NAV the settle band reads; must pin this registry. Unset, the NAV-tied
    ///         settles revert `NAV_UNAVAILABLE`. Later changes go through the timelocked proposal.
    function setValuationOracle(address oracle) external onlyRole(MANAGER_ROLE) {
        if (address(valuationOracle) != address(0)) revert ORACLE_ALREADY_SET();
        _checkOracle(oracle);
        valuationOracle = GyldBondYieldSourceOracle(oracle);
        emit ValuationOracleSet(oracle);
    }

    /// @notice Propose a new valuation oracle, executable after `DESTINATION_DELAY`: a fake NAV would let a
    ///         reconciler clear lots for dust, so the swap waits like a destination change.
    function proposeValuationOracle(address oracle) external onlyRole(MANAGER_ROLE) {
        _checkOracle(oracle);
        uint64 executeAt = uint64(block.timestamp + DESTINATION_DELAY);
        pendingValuationOracle = PendingOracle(oracle, executeAt);
        emit ValuationOracleProposed(oracle, executeAt);
    }

    function executeValuationOracle() external onlyRole(MANAGER_ROLE) {
        PendingOracle memory p = pendingValuationOracle;
        if (p.executeAt == 0) revert CHANGE_NOT_PENDING();
        if (block.timestamp < p.executeAt) revert CHANGE_TIMELOCK_NOT_ELAPSED();
        delete pendingValuationOracle;
        _checkOracle(p.oracle); // still bound to this registry
        valuationOracle = GyldBondYieldSourceOracle(p.oracle);
        emit ValuationOracleSet(p.oracle);
    }

    function cancelValuationOracle() external onlyRole(MANAGER_ROLE) {
        if (pendingValuationOracle.executeAt == 0) revert CHANGE_NOT_PENDING();
        delete pendingValuationOracle;
        emit ValuationOracleCancelled();
    }

    /// @notice Restrict cash deposits to one strategy (zero clears). Gyld pools cash per legal entity, so this is
    ///         the on-chain form of "one funded principal per ledger".
    function setSolePrincipal(address principal) external onlyRole(MANAGER_ROLE) {
        solePrincipal = principal;
        emit SolePrincipalSet(principal);
    }

    /// @notice Move a stray balance out of a strategy's receiver into the strategy without touching any lot: a
    ///         token no instrument uses, or a delivery whose lot was already written off. Refused while any open
    ///         lot of the account could still be paid in `token`.
    function rescueFromReceiver(address account, address token, uint256 amount) external onlyRole(MANAGER_ROLE) {
        GyldDeliveryReceiver r = receiverOf[account];
        if (address(r) == address(0)) revert RECEIVER_NOT_SET();
        if (amount == 0) revert ZERO_AMOUNT();
        // a bond with lots still open is a live delivery, not a stray: rescuing it would count it twice
        if (BOND_REGISTRY.isRegistered(token)) {
            Position storage p = _positions[account][token];
            if (p.cashOut != 0 || p.bondsOut != 0) revert RESCUE_BLOCKED(token);
        }
        if (openLotsPayingIn[account][token] != 0) revert RESCUE_BLOCKED(token);
        _moveFromReceiver(r, account, token, amount);
        emit ReceiverRescued(account, token, amount);
    }

    /*//////////////////////////////////////////////////////////////
                         ACCOUNT: RECORD (INCREASE ONLY)
    //////////////////////////////////////////////////////////////*/

    /// @notice Record cash sent to the deposit address as a new lot. `msg.sender` is the account.
    /// @return lotId The lot to name in the settle that closes it
    function recordCashOut(address bondToken, address cashToken, uint256 amount) external returns (uint256 lotId) {
        _checkCashOut(msg.sender, bondToken, cashToken, amount);
        Position storage p = _positions[msg.sender][bondToken];
        address dest = _destinations[msg.sender].depositAddress;
        lotId = _openLot(p, msg.sender, bondToken, cashToken, LotKind.CASH_OUT, dest, amount);
        ++openCashLotsAt[dest];
        ++p.openLots;
        ++openLotsPayingIn[msg.sender][cashToken];
        p.cashOut += amount;
        totalCashInTransit[bondToken] += amount;
        emit CashOutRecorded(msg.sender, bondToken, lotId, cashToken, amount, p.cashOut);
    }

    /// @notice Record bonds sent to the redeem holding wallet as a new lot. `msg.sender` is the account.
    /// @dev Neither the cap nor staleness applies: an exit must stay possible. No NAV is recorded: the oracle
    ///      marks bonds in transit at the live NAV, like wallet bonds.
    /// @return lotId The lot to name in the settle that closes it
    function recordBondsOut(address bondToken, address cashToken, uint256 shares) external returns (uint256 lotId) {
        _checkBondsOut(msg.sender, bondToken, cashToken);
        if (shares == 0) revert ZERO_AMOUNT();
        Position storage p = _positions[msg.sender][bondToken];
        lotId = _openLot(
            p,
            msg.sender,
            bondToken,
            cashToken,
            LotKind.BONDS_OUT,
            _destinations[msg.sender].redeemHoldingWallet,
            shares
        );
        ++p.openLots;
        ++openLotsPayingIn[msg.sender][cashToken];
        p.bondsOut += shares;
        emit BondsOutRecorded(msg.sender, bondToken, lotId, cashToken, shares, p.bondsOut);
    }

    /// @notice The strict pre-check of `recordCashOut`, as a view, so a hook's `build()` fails the same way
    function checkCashOut(address account, address bondToken, address cashToken, uint256 amount) external view {
        _checkCashOut(account, bondToken, cashToken, amount);
    }

    /// @notice The strict pre-check of `recordBondsOut`, as a view
    function checkBondsOut(address account, address bondToken, address cashToken) external view {
        _checkBondsOut(account, bondToken, cashToken);
    }

    /// @notice Non-reverting twin of `checkCashOut` for the OMS. Zero means the record would be accepted.
    /// @return code 0 ok; 201 pair not approved; 202 no deposit address; 203 age not configured; 204 stale
    ///         lot open; 205 per-strategy cap exceeded; 206 zero amount; 207 instrument-wide cap exceeded;
    ///         209 not the sole principal; 210 too many open lots
    function previewCashOut(
        address account,
        address bondToken,
        address cashToken,
        uint256 amount
    )
        external
        view
        returns (uint256 code)
    {
        if (amount == 0) return 206;
        if (!BOND_REGISTRY.isApprovedPair(bondToken, cashToken)) return 201;
        if (_destinations[account].depositAddress == address(0)) return 202;
        if (solePrincipal != address(0) && account != solePrincipal) return 209;
        if (maxTransitAge == 0) return 203;
        if (isStale(account, bondToken)) return 204;
        if (_positions[account][bondToken].openLots >= MAX_OPEN_LOTS_PER_PAIR) return 210;
        if (_positions[account][bondToken].cashOut + amount > maxCashInTransit[bondToken]) return 205;
        if (totalCashInTransit[bondToken] + amount > maxTotalCashInTransit[bondToken]) return 207;
        return 0;
    }

    /// @notice Non-reverting twin of `checkBondsOut`.
    /// @return code 0 ok; 301 pair not approved; 302 no holding wallet for the account; 303 age not configured;
    ///         305 too many open lots
    function previewBondsOut(
        address account,
        address bondToken,
        address cashToken
    )
        external
        view
        returns (uint256 code)
    {
        if (!BOND_REGISTRY.isApprovedPair(bondToken, cashToken)) return 301;
        if (_destinations[account].redeemHoldingWallet == address(0)) return 302;
        if (maxTransitAge == 0) return 303;
        if (_positions[account][bondToken].openLots >= MAX_OPEN_LOTS_PER_PAIR) return 305;
        return 0;
    }

    /*//////////////////////////////////////////////////////////////
                       RECONCILER: SETTLE (DECREASE ONLY)
    //////////////////////////////////////////////////////////////*/

    /// @notice A mint request reached `minted`: sweep the bonds Gyld delivered to the receiver into the strategy
    ///         and clear the cash they consumed from the lot.
    /// @dev Order: open amount, band on the bonds' value at the live NAV ([cash * (1 - fee) / (1 + premium),
    ///      cash * (1 + premium)]), reference, receiver balance. `cashConsumed` is Gyld's gross debit, fee
    ///      included; a fill outside the band goes through the manual path.
    /// @param lotId The cash lot the order was placed against
    /// @param apiRef Gyld's `mint_request_id` (plus a fill index for partial fills), used once
    function settleMint(
        uint256 lotId,
        uint256 cashConsumed,
        uint256 bondsReceived,
        bytes32 apiRef
    )
        external
        onlyRole(RECONCILER_ROLE)
    {
        if (bondsReceived == 0) revert ZERO_BONDS_RECEIVED();
        (Lot storage lot, Position storage p) = _openLotOfKind(lotId, LotKind.CASH_OUT);
        _decreaseCash(lotId, lot, p, cashConsumed);
        (uint256 nav, GyldBondRegistry.InstrumentConfig memory cfg) = _navFor(lotId, lot);
        uint256 delivered = bondsReceived.mulDiv(nav, cfg.bondScale);
        _checkMintBand(lotId, delivered, cashConsumed, lot.bondToken, cfg.maxEntryPremiumBps);
        _useApiRef(apiRef);
        _sweep(lot, lotId, lot.bondToken, bondsReceived);
        emit MintSettled(lot.account, lotId, apiRef, lot.bondToken, cashConsumed, bondsReceived, lot.open, p.cashOut);
    }

    /// @notice A cancelled deposit's cash came back from Gyld to the receiver: sweep it and clear the lot.
    /// @dev Cash for cash: the decrease equals the sweep, no NAV involved.
    function settleCashReturn(uint256 lotId, uint256 cashReturned, bytes32 apiRef) external onlyRole(RECONCILER_ROLE) {
        (Lot storage lot, Position storage p) = _openLotOfKind(lotId, LotKind.CASH_OUT);
        _decreaseCash(lotId, lot, p, cashReturned);
        _useApiRef(apiRef);
        _sweep(lot, lotId, lot.cashToken, cashReturned);
        emit CashReturnSettled(lot.account, lotId, apiRef, lot.bondToken, cashReturned, lot.open, p.cashOut);
    }

    /// @notice A redemption completed and Gyld paid the cash to the receiver: sweep it and clear the bonds.
    /// @dev Same order as `settleMint`; band on `cashReturned` against the bonds' value at the live NAV:
    ///      [value * (1 - fee) * (1 - discount), value * (1 + discount)].
    /// @param lotId The bond lot the redemption was placed against
    function settleRedemption(
        uint256 lotId,
        uint256 bondsConsumed,
        uint256 cashReturned,
        bytes32 apiRef
    )
        external
        onlyRole(RECONCILER_ROLE)
    {
        if (cashReturned == 0) revert ZERO_CASH_RETURNED();
        (Lot storage lot, Position storage p) = _openLotOfKind(lotId, LotKind.BONDS_OUT);
        _decreaseBonds(lotId, lot, p, bondsConsumed);
        (uint256 nav, GyldBondRegistry.InstrumentConfig memory cfg) = _navFor(lotId, lot);
        uint256 value = bondsConsumed.mulDiv(nav, cfg.bondScale);
        _checkRedemptionBand(lotId, cashReturned, value, lot.bondToken, cfg.maxExitDiscountBps);
        _useApiRef(apiRef);
        _sweep(lot, lotId, lot.cashToken, cashReturned);
        emit RedemptionSettled(
            lot.account, lotId, apiRef, lot.bondToken, bondsConsumed, cashReturned, lot.open, p.bondsOut
        );
    }

    /// @notice A cancelled redemption: Gyld returned the bonds to the receiver; sweep them and clear the lot.
    /// @dev Bonds for bonds: the decrease equals the sweep.
    function settleReturn(uint256 lotId, uint256 bondsReturned, bytes32 apiRef) external onlyRole(RECONCILER_ROLE) {
        (Lot storage lot, Position storage p) = _openLotOfKind(lotId, LotKind.BONDS_OUT);
        _decreaseBonds(lotId, lot, p, bondsReturned);
        _useApiRef(apiRef);
        _sweep(lot, lotId, lot.bondToken, bondsReturned);
        emit ReturnSettled(lot.account, lotId, apiRef, lot.bondToken, bondsReturned, lot.open, p.bondsOut);
    }

    /*//////////////////////////////////////////////////////////////
                MANAGER: MANUAL SETTLE (LOSS / OVERRIDE), TIMELOCKED
    //////////////////////////////////////////////////////////////*/

    /// @notice Propose a decrease the receiver cannot back (a loss, or a delivery that reached the strategy
    ///         directly). Executable after `MANUAL_SETTLE_DELAY` for `MANUAL_SETTLE_WINDOW`; netted from the
    ///         valuation from this block on, so the delay is a review period, not an exit window. The reference is
    ///         reserved here; an expired proposal is replaced by the next one.
    function proposeManualSettle(uint256 lotId, uint256 amount, bytes32 apiRef) external onlyRole(MANAGER_ROLE) {
        _propose(lotId, amount, amount, address(0), 0, apiRef);
    }

    /// @notice A decrease WITH a delivery to sweep: the governed path for a receipt the reconciler cannot settle (a
    ///         NAV out of the band after a price move, a suspended or stale NAV, a re-denominated instrument). At
    ///         execution the lot shrinks by `amount` and `sweepAmount` of `token` moves receiver -> strategy in the
    ///         same transaction, so the asset enters the wallet as the claim leaves the valuation: no second step.
    ///         Only `recognisedLoss` (<= amount) is netted from the valuation from the proposal on; a pure
    ///         out-of-band receipt is proposed with zero loss and moves nothing until it executes. A reconciler
    ///         settle on the lot in the meantime drops the proposal (its facts changed); the receiver must still
    ///         hold `sweepAmount` at execution or the execute reverts and nothing moves.
    function proposeManualSweep(
        uint256 lotId,
        uint256 amount,
        uint256 recognisedLoss,
        address token,
        uint256 sweepAmount,
        bytes32 apiRef
    )
        external
        onlyRole(MANAGER_ROLE)
    {
        if (sweepAmount == 0) revert ZERO_AMOUNT();
        if (recognisedLoss > amount) revert LOSS_EXCEEDS_DECREASE(recognisedLoss, amount);
        _propose(lotId, amount, recognisedLoss, token, sweepAmount, apiRef);
    }

    /// @notice Apply a proposed decrease. Clamped to what the lot still has open (the reconciler may have settled
    ///         part of it in the meantime); a lot that closed on its own has already dropped its proposal.
    function executeManualSettle(uint256 lotId) external onlyRole(MANAGER_ROLE) {
        PendingManualSettle memory m = pendingManualSettles[lotId];
        if (m.executeAt == 0) revert CHANGE_NOT_PENDING();
        if (block.timestamp < m.executeAt) revert CHANGE_TIMELOCK_NOT_ELAPSED();
        if (block.timestamp > m.executeAt + MANUAL_SETTLE_WINDOW) revert CHANGE_EXPIRED();
        delete pendingManualSettles[lotId];
        Lot storage lot = _lots[lotId];
        Position storage p = _positions[lot.account][lot.bondToken];
        --p.pendingCount;
        _removePending(lot, m.netted);
        uint256 amount = m.amount > lot.open ? lot.open : m.amount; // _decrease keeps m.amount <= open; belt and braces
        uint256 remaining;
        if (lot.kind == LotKind.CASH_OUT) {
            _decreaseCash(lotId, lot, p, amount);
            remaining = p.cashOut;
        } else {
            _decreaseBonds(lotId, lot, p, amount);
            remaining = p.bondsOut;
        }
        if (m.sweepAmount != 0) {
            _sweep(lot, lotId, m.sweepToken, m.sweepAmount);
            emit ManualSweepExecuted(lotId, m.sweepToken, m.sweepAmount);
        }
        emit ManualSettled(lot.account, lotId, m.apiRef, lot.bondToken, lot.kind, amount, lot.open, remaining);
    }

    /// @dev Shared body of the two proposal paths
    function _propose(
        uint256 lotId,
        uint256 amount,
        uint256 netted,
        address token,
        uint256 sweepAmount,
        bytes32 apiRef
    )
        private
    {
        Lot storage lot = _lots[lotId];
        if (lot.recorded == 0) revert LOT_NOT_FOUND(lotId);
        if (amount == 0) revert ZERO_AMOUNT();
        if (amount > lot.open) revert EXCEEDS_OPEN(lot.open, amount);
        if (sweepAmount != 0 && token != lot.bondToken && token != lot.cashToken) revert INVALID_SWEEP_TOKEN(token);
        uint64 pendingAt = pendingManualSettles[lotId].executeAt;
        if (pendingAt != 0) {
            // a live proposal blocks; an EXPIRED one is replaced here (its netting and reference released)
            if (block.timestamp <= pendingAt + MANUAL_SETTLE_WINDOW) revert MANUAL_SETTLE_PENDING(lotId);
            _dropPending(lotId, lot);
        }
        _useApiRef(apiRef);
        uint64 executeAt = uint64(block.timestamp + MANUAL_SETTLE_DELAY);
        pendingManualSettles[lotId] = PendingManualSettle(amount, netted, sweepAmount, token, apiRef, executeAt);
        ++_positions[lot.account][lot.bondToken].pendingCount;
        if (netted != 0) _addPending(lot, netted);
        emit ManualSettleProposed(lot.account, lotId, apiRef, amount, executeAt);
        if (sweepAmount != 0) emit ManualSweepAttached(lotId, token, sweepAmount, netted);
    }

    /// @notice Withdraw a proposal: the value comes back into the position and the reference is released.
    function cancelManualSettle(uint256 lotId) external onlyRole(MANAGER_ROLE) {
        if (pendingManualSettles[lotId].executeAt == 0) revert CHANGE_NOT_PENDING();
        _dropPending(lotId, _lots[lotId]);
    }

    /*//////////////////////////////////////////////////////////////
                                  VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice One strategy's pair; both zero until `setDestinations`
    function destinationsOf(address account)
        external
        view
        returns (address depositAddress, address redeemHoldingWallet)
    {
        Destinations storage d = _destinations[account];
        return (d.depositAddress, d.redeemHoldingWallet);
    }

    /// @notice Where the account's deposits go; zero means it cannot deposit
    function depositAddressOf(address account) external view returns (address) {
        return _destinations[account].depositAddress;
    }

    /// @notice Where the account's redemptions go; zero means it cannot redeem
    function redeemHoldingWalletOf(address account) external view returns (address) {
        return _destinations[account].redeemHoldingWallet;
    }

    /// @notice The account's aggregate position for the instrument (gross of pending manual settles), with the age
    ///         of its oldest open lot. The cap and the stale gate read this.
    function transit(address account, address bondToken) external view returns (Transit memory t) {
        Position storage p = _positions[account][bondToken];
        t.cashOut = p.cashOut;
        t.bondsOut = p.bondsOut;
        (, t.oldestOpenAt) = _oldestOpen(p);
    }

    /// @notice The same position NET of pending manual settles. The oracle values this, so a proposed write-down
    ///         is priced in from the proposal on.
    function transitNet(address account, address bondToken) external view returns (Transit memory t) {
        Position storage p = _positions[account][bondToken];
        t.cashOut = p.cashOut - p.pendingCashDecrease;
        t.bondsOut = p.bondsOut - p.pendingBondsDecrease;
        (, t.oldestOpenAt) = _oldestOpen(p);
    }

    /// @notice `totalCashInTransit` net of pending manual decreases, for `getTVL`
    function totalCashInTransitNet(address bondToken) external view returns (uint256) {
        return totalCashInTransit[bondToken] - totalPendingCashDecrease[bondToken];
    }

    /// @notice The pair has lots open and its receiver holds bond or cash no settle has swept: do not push a PPS
    function hasUnsettledDelivery(address account, address bondToken) external view returns (bool) {
        Position storage p = _positions[account][bondToken];
        if (p.cashOut == 0 && p.bondsOut == 0) return false; // nothing open: a balance here cannot be a delivery
        (uint256 bondsHeld, uint256 cashHeld) = unsweptDelivery(account, bondToken);
        return bondsHeld != 0 || cashHeld != 0;
    }

    /// @notice The amounts behind `hasUnsettledDelivery`, so the pusher can apply a dust floor
    function unsweptDelivery(address account, address bondToken) public view returns (uint256 bonds, uint256 cash) {
        GyldDeliveryReceiver r = receiverOf[account];
        if (address(r) == address(0)) return (0, 0);
        bonds = r.balance(bondToken);
        if (!BOND_REGISTRY.isRegistered(bondToken)) return (bonds, 0); // monitoring view: never reverts
        address cashToken = BOND_REGISTRY.getInstrumentConfig(bondToken).cashToken;
        if (cashToken != address(0)) cash = r.balance(cashToken);
    }

    function cashOut(address account, address bondToken) external view returns (uint256) {
        return _positions[account][bondToken].cashOut;
    }

    function bondsOut(address account, address bondToken) external view returns (uint256) {
        return _positions[account][bondToken].bondsOut;
    }

    /// @notice One lot by id; `recorded == 0` means the id was never issued
    function getLot(uint256 lotId) external view returns (Lot memory) {
        return _lots[lotId];
    }

    /// @notice Every lot id the account ever opened for the instrument, oldest first, closed ones included
    function lotsOf(address account, address bondToken) external view returns (uint256[] memory) {
        return _positions[account][bondToken].lotIds;
    }

    /// @notice The oldest still-open lot for the pair; both zero when nothing is open
    function oldestOpenLot(address account, address bondToken) external view returns (uint256 lotId, uint64 openedAt) {
        return _oldestOpen(_positions[account][bondToken]);
    }

    /// @notice Whether any open lot of the pair has a manual (loss / override) settle waiting out its delay
    /// @dev The trigger for the affected-user policy: while this or `isStale` is true the SuperVault pauses
    ///      deposits at vault level (pausing the deposit hook alone would not stop users buying shares at a PPS
    ///      that may still be revised). Walks the open part of the queue only.
    function hasPendingManualSettle(address account, address bondToken) external view returns (bool) {
        return _positions[account][bondToken].pendingCount != 0; // proposals die with their lot, so this is exact
    }

    /// @notice A proposal whose execute window has passed: still netted and still flagged until governance cancels
    ///         or replaces it (an expired clock never restores a loss by itself)
    function isManualSettleExpired(uint256 lotId) external view returns (bool) {
        uint64 at = pendingManualSettles[lotId].executeAt;
        return at != 0 && block.timestamp > at + MANUAL_SETTLE_WINDOW;
    }

    /// @notice Open lots of the pair, both kinds (bounded by `MAX_OPEN_LOTS_PER_PAIR`)
    function openLots(address account, address bondToken) external view returns (uint256) {
        return _positions[account][bondToken].openLots;
    }

    /// @notice Whether a lot is still open and older than `maxTransitAge`
    /// @dev An unconfigured age reads as stale, so the deposit gate closes on a lot nobody bounded.
    function isLotStale(uint256 lotId) external view returns (bool) {
        Lot storage l = _lots[lotId];
        if (l.open == 0) return false;
        return _aged(l.openedAt);
    }

    /// @notice Whether the account's oldest open lot for the instrument is older than `maxTransitAge`
    /// @dev The oldest open lot is the first to age, so this is "does any open lot exceed the age".
    function isStale(address account, address bondToken) public view returns (bool) {
        (uint256 lotId, uint64 openedAt) = _oldestOpen(_positions[account][bondToken]);
        if (lotId == 0) return false;
        return _aged(openedAt);
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    function _checkCashOut(address account, address bondToken, address cashToken, uint256 amount) private view {
        if (amount == 0) revert ZERO_AMOUNT();
        if (!BOND_REGISTRY.isApprovedPair(bondToken, cashToken)) revert PAIR_NOT_APPROVED();
        if (_destinations[account].depositAddress == address(0)) revert DESTINATION_NOT_SET();
        address principal = solePrincipal;
        if (principal != address(0) && account != principal) revert NOT_SOLE_PRINCIPAL(principal);
        if (maxTransitAge == 0) revert TRANSIT_AGE_NOT_CONFIGURED();
        if (isStale(account, bondToken)) revert TRANSIT_STALE();
        Position storage pos = _positions[account][bondToken];
        if (pos.openLots >= MAX_OPEN_LOTS_PER_PAIR) revert TOO_MANY_OPEN_LOTS(pos.openLots, MAX_OPEN_LOTS_PER_PAIR);
        uint256 outstanding = pos.cashOut + amount;
        uint256 cap = maxCashInTransit[bondToken];
        if (outstanding > cap) revert CAP_EXCEEDED(outstanding, cap);
        uint256 total = totalCashInTransit[bondToken] + amount;
        uint256 totalCap = maxTotalCashInTransit[bondToken];
        if (total > totalCap) revert GLOBAL_CAP_EXCEEDED(total, totalCap);
    }

    function _checkBondsOut(address account, address bondToken, address cashToken) private view {
        if (!BOND_REGISTRY.isApprovedPair(bondToken, cashToken)) revert PAIR_NOT_APPROVED();
        if (_destinations[account].redeemHoldingWallet == address(0)) revert DESTINATION_NOT_SET();
        if (maxTransitAge == 0) revert TRANSIT_AGE_NOT_CONFIGURED();
        uint256 open = _positions[account][bondToken].openLots;
        if (open >= MAX_OPEN_LOTS_PER_PAIR) revert TOO_MANY_OPEN_LOTS(open, MAX_OPEN_LOTS_PER_PAIR);
    }

    /// @dev Append a lot to the pair's queue. Ids are global and start at 1 so that zero means "none".
    function _openLot(
        Position storage p,
        address account,
        address bondToken,
        address cashToken,
        LotKind kind,
        address destination,
        uint256 amount
    )
        private
        returns (uint256 lotId)
    {
        lotId = ++lotCount;
        _lots[lotId] = Lot({
            account: account,
            kind: kind,
            openedAt: uint64(block.timestamp),
            bondToken: bondToken,
            destination: destination,
            cashToken: cashToken,
            recorded: amount,
            open: amount
        });
        p.lotIds.push(lotId);
    }

    /// @dev Claim a deposit address for the account, releasing its previous one
    function _claimDepositAddress(address account, address depositAddress_) private {
        _checkDepositAddressFree(account, depositAddress_);
        address previous = _destinations[account].depositAddress;
        if (previous != address(0) && previous != depositAddress_) delete accountOfDepositAddress[previous];
        accountOfDepositAddress[depositAddress_] = account;
    }

    /// @dev Create the strategy's mailbox once; both destination paths call this.
    function _ensureReceiver(address account) private {
        if (address(receiverOf[account]) != address(0)) return;
        GyldDeliveryReceiver r = new GyldDeliveryReceiver(account);
        receiverOf[account] = r;
        emit ReceiverCreated(account, address(r));
    }

    /// @dev The receiver's balance is an upper bound on what Gyld delivered: the sweep is the settle's proof
    function _sweep(Lot storage lot, uint256 lotId, address token, uint256 amount) private {
        GyldDeliveryReceiver r = receiverOf[lot.account];
        if (address(r) == address(0)) revert RECEIVER_NOT_SET();
        uint256 held = r.balance(token);
        if (held < amount) revert DELIVERY_NOT_FOUND(lotId, held, amount);
        _moveFromReceiver(r, lot.account, token, amount);
    }

    /// @dev Receiver -> strategy; the strategy must receive exactly `amount` (fee-on-transfer or restricted tokens)
    function _moveFromReceiver(GyldDeliveryReceiver r, address account, address token, uint256 amount) private {
        uint256 before = IERC20(token).balanceOf(account);
        r.sweep(token, amount);
        uint256 received = IERC20(token).balanceOf(account) - before;
        if (received != amount) revert SWEEP_SHORT(token, amount, received);
    }

    /// @dev Mint band: the delivered value must sit in [cash * (1 - fee) / (1 + tol), cash * (1 + tol)]
    function _checkMintBand(
        uint256 lotId,
        uint256 delivered,
        uint256 cash,
        address bondToken,
        uint256 tol
    )
        private
        view
    {
        uint256 lower = cash.mulDiv(BPS - transitFeeBps[bondToken], BPS).mulDiv(BPS, BPS + tol);
        if (delivered < lower) revert SETTLE_BELOW_NAV(lotId, delivered, lower);
        uint256 upper = cash.mulDiv(BPS + tol, BPS);
        if (delivered > upper) revert SETTLE_ABOVE_NAV(lotId, delivered, upper);
    }

    /// @dev Redemption band: the cash paid must sit in [value * (1 - fee) * (1 - tol), value * (1 + tol)]
    function _checkRedemptionBand(
        uint256 lotId,
        uint256 paid,
        uint256 value,
        address bondToken,
        uint256 tol
    )
        private
        view
    {
        uint256 lower = value.mulDiv(BPS - transitFeeBps[bondToken], BPS).mulDiv(BPS - tol, BPS);
        if (paid < lower) revert SETTLE_BELOW_NAV(lotId, paid, lower);
        uint256 upper = value.mulDiv(BPS + tol, BPS);
        if (paid > upper) revert SETTLE_ABOVE_NAV(lotId, paid, upper);
    }

    /// @dev Refused while another strategy holds the address or open cash lots still point at it
    function _checkDepositAddressFree(address account, address depositAddress_) private view {
        address holder = accountOfDepositAddress[depositAddress_];
        if (holder != address(0) && holder != account) revert DEPOSIT_ADDRESS_IN_USE(depositAddress_, holder);
        uint256 open = openCashLotsAt[depositAddress_];
        if (holder != account && open != 0) revert DEPOSIT_ADDRESS_HAS_OPEN_LOTS(depositAddress_, open);
    }

    function _checkOracle(address oracle) private view {
        if (oracle == address(0)) revert ZERO_ADDRESS();
        if (address(GyldBondYieldSourceOracle(oracle).IN_TRANSIT()) != address(this)) revert ORACLE_MISMATCH(oracle);
    }

    /// @dev Drop a lot's proposal: release the netting and the reference
    function _dropPending(uint256 lotId, Lot storage lot) private {
        PendingManualSettle memory m = pendingManualSettles[lotId];
        delete pendingManualSettles[lotId];
        _removePending(lot, m.netted);
        --_positions[lot.account][lot.bondToken].pendingCount;
        apiRefUsed[m.apiRef] = false;
        emit ManualSettleCancelled(lotId);
    }

    /// @dev The live NAV in cash units per whole bond, or revert: a settle that cannot be priced waits (or goes
    ///      through the manual path). Uses the oracle's non-reverting read so the failure code is surfaced.
    function _navFor(
        uint256 lotId,
        Lot storage lot
    )
        private
        view
        returns (uint256 nav, GyldBondRegistry.InstrumentConfig memory cfg)
    {
        GyldBondYieldSourceOracle oracle = valuationOracle;
        if (address(oracle) == address(0)) revert NAV_UNAVAILABLE(type(uint8).max);
        GyldBondYieldSourceOracle.NavStatus memory st = oracle.previewNav(lot.bondToken);
        if (st.failureCode != 0 || st.nav == 0) revert NAV_UNAVAILABLE(st.failureCode);
        nav = st.nav;
        cfg = BOND_REGISTRY.getInstrumentConfig(lot.bondToken);
        // a re-registered instrument in another cash denomination would price this lot's units wrongly
        if (cfg.cashToken != lot.cashToken) revert INSTRUMENT_DENOMINATION_CHANGED(lotId);
    }

    /// @dev One Gyld reference settles exactly once (anti-replay for the reconciler's own submissions).
    function _useApiRef(bytes32 apiRef) private {
        if (apiRefUsed[apiRef]) revert API_REF_REUSED(apiRef);
        apiRefUsed[apiRef] = true;
    }

    function _addPending(Lot storage lot, uint256 amount) private {
        Position storage p = _positions[lot.account][lot.bondToken];
        if (lot.kind == LotKind.CASH_OUT) {
            p.pendingCashDecrease += amount;
            totalPendingCashDecrease[lot.bondToken] += amount;
        } else {
            p.pendingBondsDecrease += amount;
        }
    }

    function _removePending(Lot storage lot, uint256 amount) private {
        Position storage p = _positions[lot.account][lot.bondToken];
        if (lot.kind == LotKind.CASH_OUT) {
            p.pendingCashDecrease -= amount;
            totalPendingCashDecrease[lot.bondToken] -= amount;
        } else {
            p.pendingBondsDecrease -= amount;
        }
    }

    function _decreaseCash(uint256 lotId, Lot storage lot, Position storage p, uint256 amount) private {
        _decrease(lotId, lot, p, amount);
        p.cashOut -= amount;
        totalCashInTransit[lot.bondToken] -= amount;
    }

    function _decreaseBonds(uint256 lotId, Lot storage lot, Position storage p, uint256 shares) private {
        _decrease(lotId, lot, p, shares);
        p.bondsOut -= shares;
    }

    function _openLotOfKind(uint256 lotId, LotKind kind) private view returns (Lot storage lot, Position storage p) {
        lot = _lots[lotId];
        if (lot.recorded == 0) revert LOT_NOT_FOUND(lotId);
        if (lot.kind != kind) revert LOT_KIND_MISMATCH(lotId);
        p = _positions[lot.account][lot.bondToken];
    }

    /// @dev Decrease one lot and advance the head once it closes; a pending proposal is clamped to what stays open
    ///      and dropped when the lot closes.
    function _decrease(uint256 lotId, Lot storage lot, Position storage p, uint256 amount) private {
        if (amount == 0) revert ZERO_AMOUNT();
        if (amount > lot.open) revert EXCEEDS_OPEN(lot.open, amount);
        lot.open -= amount;
        PendingManualSettle storage m = pendingManualSettles[lotId];
        if (m.executeAt != 0) {
            // a reconciler settle changed the facts a sweep proposal was made on: it falls and is re-made if still
            // needed. A plain decrease is clamped to what is left open, or dropped with the lot.
            if (lot.open == 0 || m.sweepAmount != 0) {
                _dropPending(lotId, lot);
            } else if (m.amount > lot.open) {
                m.amount = lot.open;
                if (m.netted > lot.open) {
                    _removePending(lot, m.netted - lot.open);
                    m.netted = lot.open;
                }
            }
        }
        if (lot.open == 0) {
            if (lot.kind == LotKind.CASH_OUT) --openCashLotsAt[lot.destination];
            --p.openLots;
            --openLotsPayingIn[lot.account][lot.cashToken];
            _advanceHead(p);
        }
    }

    /// @dev Skip closed lots at the front of the queue. Amortised O(1): each lot is passed once.
    function _advanceHead(Position storage p) private {
        uint256 n = p.lotIds.length;
        uint256 h = p.head;
        while (h < n && _lots[p.lotIds[h]].open == 0) {
            unchecked {
                ++h;
            }
        }
        p.head = h;
    }

    /// @dev The oldest open lot is at `head` (settles keep it there); zeros when the queue is drained.
    function _oldestOpen(Position storage p) private view returns (uint256 lotId, uint64 openedAt) {
        if (p.head >= p.lotIds.length) return (0, 0);
        lotId = p.lotIds[p.head];
        openedAt = _lots[lotId].openedAt;
    }

    function _aged(uint64 openedAt) private view returns (bool) {
        uint256 age = maxTransitAge;
        if (age == 0) return true;
        return block.timestamp - openedAt > age;
    }
}
