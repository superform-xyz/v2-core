// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

// Superform
import { GyldBondRegistry } from "./GyldBondRegistry.sol";

/// @title GyldInTransitRegistry
/// @author Superform Labs
/// @notice On-chain memory of what each account has at Gyld through the Investor API: cash sent to Gyld's
///         deposit address and not yet minted against, bond tokens sent to the redeem holding wallet and not
///         yet paid out. Also the single source of the pinned destinations and the per-instrument caps.
/// @dev WHY THIS EXISTS. The Investor API is a brokerage account, not a venue: the chain only sees a plain
///      transfer out, and the matching mint or payout arrives in a later transaction signed by Gyld. Without
///      a record of what is in transit, a SuperVault's price per share drops the moment cash leaves and jumps
///      when tokens land, which is a sandwich on every order. `GyldBondYieldSourceOracle` adds these entries
///      to its valuation and zeroes them once they are older than `maxTransitAge`.
/// @dev ONE LOT PER ORDER (review on SUP-21848). Every record opens a LOT: one transfer, one kind (cash out
///      or bonds out), one `openedAt`, one open amount. Gyld manages orders per `request_id`, so settles name
///      the lot they close and can only decrease THAT lot: a partial fill is bounded by its own order, and a
///      stalled order ages alone. The per-(account, instrument) aggregates `cashOut` / `bondsOut` are the sums
///      of the open lots and are what the oracle values. An aggregate clock was wrong in both directions: a
///      strategy with a rolling book never drained its entry and read stale `maxTransitAge` after its first
///      record, and one slow order made every healthy order behind it look expired.
/// @dev WHO MAY WRITE. `recordCashOut`/`recordBondsOut` are called by the ACCOUNT itself (hooks execute as the
///      account), so `msg.sender` cannot tell a hook from a direct call. That is accepted: a caller can only
///      increase its OWN entries, the only consumer of those entries is the valuation of that same account, a
///      SuperVault strategy can only reach this through root-authorised hooks, the cap bounds the exposure
///      and the hooks verify the matching transfer in the same atomic batch. Decreases are RECONCILER-only.
/// @dev DESTINATIONS ARE TIMELOCKED. A re-pointed deposit address is the drain vector for every open deposit
///      leaf, and the hooks cannot commit the address (it is not in calldata), so the first set is immediate
///      and every change waits `DESTINATION_DELAY` behind a visible proposal.
/// @dev WHAT THIS DOES NOT PROTECT: Gyld's withdrawal address being the strategy (an onboarding fact), the
///      order price (lives in the API), Gyld's custody and solvency, and which Gyld order a settle really
///      belongs to (the order never exists on chain; `apiRef` is the audit trail, not a proof).
contract GyldInTransitRegistry is AccessControl {
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
    /// @notice The destination this record needs is still zero
    error DESTINATION_NOT_SET();
    /// @notice `maxTransitAge` is zero; records are refused rather than valued forever
    error TRANSIT_AGE_NOT_CONFIGURED();
    /// @notice The account already has an open lot older than `maxTransitAge` for this instrument
    error TRANSIT_STALE();
    /// @notice Outstanding cash plus this record would exceed the instrument's cap
    error CAP_EXCEEDED(uint256 outstanding, uint256 cap);
    /// @notice No lot with this id has been recorded
    error LOT_NOT_FOUND(uint256 lotId);
    /// @notice A cash settle named a bond lot, or the reverse
    error LOT_KIND_MISMATCH(uint256 lotId);
    /// @notice A settlement tried to clear more than the lot still has open
    error EXCEEDS_OPEN(uint256 open, uint256 requested);
    /// @notice `settleMint` with nothing received is a loss and must go through `settleLoss`
    error ZERO_BONDS_RECEIVED();
    error DESTINATIONS_ALREADY_SET();
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
    /// @param recorded The amount recorded, in cash units (CASH_OUT) or bond units (BONDS_OUT)
    /// @param open What is still unsettled; zero means the lot is closed
    struct Lot {
        address account;
        LotKind kind;
        uint64 openedAt;
        address bondToken;
        uint256 recorded;
        uint256 open;
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

    /// @dev Per-(account, instrument) aggregates plus the lot queue. Lots are appended in time order; `head`
    ///      is the index of the oldest lot that may still be open (everything before it is closed), so the
    ///      staleness read is O(1) and a settle advances it past closed lots.
    struct Position {
        uint256 cashOut;
        uint256 bondsOut;
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

    /// @notice The approved-instrument list; pairs and caps are validated against it
    GyldBondRegistry public immutable BOND_REGISTRY;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Gyld's deposit address for our account (`GET /deposit/address`)
    address public depositAddress;
    /// @notice Gyld's redeem holding wallet (`GET /portfolio.redeem_holding_wallet`)
    address public redeemHoldingWallet;
    /// @notice Lots older than this make the position stale: valued at zero by the oracle, new deposits blocked
    uint256 public maxTransitAge;
    /// @notice Per-instrument cap on OUTSTANDING cash at Gyld, per account; zero disables the instrument
    mapping(address bondToken => uint256 cap) public maxCashInTransit;

    /// @notice Expected Gyld fee on an in-transit leg, in bps, netted out of in-transit value by the oracle.
    /// @dev One figure for both legs: the upfront mint fee on cash out and the redemption fee on bonds out. It
    ///      stops the price per share stepping down when `settleLoss` / `settleRedemption` books the real fee.
    ///      Gyld's AUM fee is already inside the NAV and needs nothing here. Zero = no haircut.
    mapping(address bondToken => uint256 bps) public transitFeeBps;
    /// @notice Sum of `cashOut` over every account, for `getTVL`
    mapping(address bondToken => uint256 total) public totalCashInTransit;

    /// @notice Number of lots ever recorded; ids run from 1 to this value
    uint256 public lotCount;

    PendingDestinations public pendingDestinations;

    mapping(uint256 lotId => Lot) private _lots;
    mapping(address account => mapping(address bondToken => Position)) private _positions;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event DestinationsSet(address indexed depositAddress, address indexed redeemHoldingWallet);
    event DestinationsProposed(address indexed depositAddress, address indexed redeemHoldingWallet, uint256 executeAt);
    event DestinationsCancelled();
    event MaxTransitAgeUpdated(uint256 maxTransitAge);
    event MaxCashInTransitUpdated(address indexed bondToken, uint256 cap);
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
    event TransitLoss(
        address indexed account,
        uint256 indexed lotId,
        bytes32 indexed apiRef,
        address bondToken,
        uint256 cashLost,
        uint256 lotOpen,
        uint256 remainingCashOut
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

    /// @notice First-time set of both destinations. Immediate, because nothing can be in transit yet.
    function setDestinations(address depositAddress_, address redeemHoldingWallet_) external onlyRole(MANAGER_ROLE) {
        if (depositAddress != address(0) || redeemHoldingWallet != address(0)) revert DESTINATIONS_ALREADY_SET();
        if (depositAddress_ == address(0) || redeemHoldingWallet_ == address(0)) revert ZERO_ADDRESS();
        depositAddress = depositAddress_;
        redeemHoldingWallet = redeemHoldingWallet_;
        emit DestinationsSet(depositAddress_, redeemHoldingWallet_);
    }

    /// @notice Propose a destination change; executable after `DESTINATION_DELAY`
    function proposeDestinations(
        address depositAddress_,
        address redeemHoldingWallet_
    )
        external
        onlyRole(MANAGER_ROLE)
    {
        if (depositAddress_ == address(0) || redeemHoldingWallet_ == address(0)) revert ZERO_ADDRESS();
        uint64 executeAt = uint64(block.timestamp + DESTINATION_DELAY);
        pendingDestinations = PendingDestinations(depositAddress_, redeemHoldingWallet_, executeAt);
        emit DestinationsProposed(depositAddress_, redeemHoldingWallet_, executeAt);
    }

    function executeDestinations() external onlyRole(MANAGER_ROLE) {
        PendingDestinations memory p = pendingDestinations;
        if (p.executeAt == 0) revert CHANGE_NOT_PENDING();
        if (block.timestamp < p.executeAt) revert CHANGE_TIMELOCK_NOT_ELAPSED();
        delete pendingDestinations;
        depositAddress = p.depositAddress;
        redeemHoldingWallet = p.redeemHoldingWallet;
        emit DestinationsSet(p.depositAddress, p.redeemHoldingWallet);
    }

    function cancelDestinations() external onlyRole(MANAGER_ROLE) {
        if (pendingDestinations.executeAt == 0) revert CHANGE_NOT_PENDING();
        delete pendingDestinations;
        emit DestinationsCancelled();
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

    /// @notice Expected fee on in-transit legs for an instrument, in bps. At most `MAX_TRANSIT_FEE_BPS`.
    function setTransitFeeBps(address bondToken, uint256 bps) external onlyRole(MANAGER_ROLE) {
        if (!BOND_REGISTRY.isRegistered(bondToken)) revert INSTRUMENT_NOT_REGISTERED();
        if (bps > MAX_TRANSIT_FEE_BPS) revert INVALID_FEE();
        transitFeeBps[bondToken] = bps;
        emit TransitFeeUpdated(bondToken, bps);
    }

    /*//////////////////////////////////////////////////////////////
                         ACCOUNT: RECORD (INCREASE ONLY)
    //////////////////////////////////////////////////////////////*/

    /// @notice Record cash sent to the deposit address as a new lot. `msg.sender` is the account.
    /// @return lotId The lot to name in the settle that closes it
    function recordCashOut(address bondToken, address cashToken, uint256 amount) external returns (uint256 lotId) {
        _checkCashOut(msg.sender, bondToken, cashToken, amount);
        Position storage p = _positions[msg.sender][bondToken];
        lotId = _openLot(p, msg.sender, bondToken, LotKind.CASH_OUT, amount);
        p.cashOut += amount;
        totalCashInTransit[bondToken] += amount;
        emit CashOutRecorded(msg.sender, bondToken, lotId, cashToken, amount, p.cashOut);
    }

    /// @notice Record bonds sent to the redeem holding wallet as a new lot. `msg.sender` is the account.
    /// @dev Neither the cap nor staleness applies: an exit must stay possible. No NAV is recorded: the oracle
    ///      marks bonds in transit at the live NAV, like wallet bonds.
    /// @return lotId The lot to name in the settle that closes it
    function recordBondsOut(address bondToken, address cashToken, uint256 shares) external returns (uint256 lotId) {
        _checkBondsOut(bondToken, cashToken);
        if (shares == 0) revert ZERO_AMOUNT();
        Position storage p = _positions[msg.sender][bondToken];
        lotId = _openLot(p, msg.sender, bondToken, LotKind.BONDS_OUT, shares);
        p.bondsOut += shares;
        emit BondsOutRecorded(msg.sender, bondToken, lotId, cashToken, shares, p.bondsOut);
    }

    /// @notice The strict pre-check of `recordCashOut`, as a view, so a hook's `build()` fails the same way
    function checkCashOut(address account, address bondToken, address cashToken, uint256 amount) external view {
        _checkCashOut(account, bondToken, cashToken, amount);
    }

    /// @notice The strict pre-check of `recordBondsOut`, as a view
    function checkBondsOut(address bondToken, address cashToken) external view {
        _checkBondsOut(bondToken, cashToken);
    }

    /// @notice Non-reverting twin of `checkCashOut` for the OMS. Zero means the record would be accepted.
    /// @return code 0 ok; 201 pair not approved; 202 no deposit address; 203 age not configured; 204 stale
    ///         lot open; 205 cap exceeded; 206 zero amount
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
        if (depositAddress == address(0)) return 202;
        if (maxTransitAge == 0) return 203;
        if (isStale(account, bondToken)) return 204;
        if (_positions[account][bondToken].cashOut + amount > maxCashInTransit[bondToken]) return 205;
        return 0;
    }

    /// @notice Non-reverting twin of `checkBondsOut`.
    /// @return code 0 ok; 301 pair not approved; 302 no holding wallet; 303 age not configured
    function previewBondsOut(address bondToken, address cashToken) external view returns (uint256 code) {
        if (!BOND_REGISTRY.isApprovedPair(bondToken, cashToken)) return 301;
        if (redeemHoldingWallet == address(0)) return 302;
        if (maxTransitAge == 0) return 303;
        return 0;
    }

    /*//////////////////////////////////////////////////////////////
                       RECONCILER: SETTLE (DECREASE ONLY)
    //////////////////////////////////////////////////////////////*/

    /// @notice A mint request reached `minted`: clear the cash it consumed from its lot.
    /// @param lotId The cash lot the order was placed against
    /// @param apiRef Gyld's `mint_request_id`, hashed or left-padded, for off-chain reconciliation
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
        (Lot storage lot, Position storage p) = _decreaseCash(lotId, cashConsumed);
        emit MintSettled(lot.account, lotId, apiRef, lot.bondToken, cashConsumed, bondsReceived, lot.open, p.cashOut);
    }

    /// @notice Cash that will never mint (fees, a failed order). Separate and loud on purpose.
    function settleLoss(uint256 lotId, uint256 cashLost, bytes32 apiRef) external onlyRole(RECONCILER_ROLE) {
        (Lot storage lot, Position storage p) = _decreaseCash(lotId, cashLost);
        emit TransitLoss(lot.account, lotId, apiRef, lot.bondToken, cashLost, lot.open, p.cashOut);
    }

    /// @notice A cancelled deposit's cash was withdrawn back to the account on chain.
    function settleCashReturn(uint256 lotId, uint256 cashReturned, bytes32 apiRef) external onlyRole(RECONCILER_ROLE) {
        (Lot storage lot, Position storage p) = _decreaseCash(lotId, cashReturned);
        emit CashReturnSettled(lot.account, lotId, apiRef, lot.bondToken, cashReturned, lot.open, p.cashOut);
    }

    /// @notice A redemption completed and the payout landed on the account.
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
        (Lot storage lot, Position storage p) = _decreaseBonds(lotId, bondsConsumed);
        emit RedemptionSettled(
            lot.account, lotId, apiRef, lot.bondToken, bondsConsumed, cashReturned, lot.open, p.bondsOut
        );
    }

    /// @notice A cancelled redemption returned the tokens to the account.
    function settleReturn(uint256 lotId, uint256 bondsReturned, bytes32 apiRef) external onlyRole(RECONCILER_ROLE) {
        (Lot storage lot, Position storage p) = _decreaseBonds(lotId, bondsReturned);
        emit ReturnSettled(lot.account, lotId, apiRef, lot.bondToken, bondsReturned, lot.open, p.bondsOut);
    }

    /*//////////////////////////////////////////////////////////////
                                  VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice The account's aggregate position for the instrument, with the age of its oldest open lot
    function transit(address account, address bondToken) external view returns (Transit memory t) {
        Position storage p = _positions[account][bondToken];
        t.cashOut = p.cashOut;
        t.bondsOut = p.bondsOut;
        (, t.oldestOpenAt) = _oldestOpen(p);
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

    /// @notice Whether a lot is still open and older than `maxTransitAge`
    /// @dev An unconfigured age reads as stale, so valuation never counts a lot nobody bounded.
    function isLotStale(uint256 lotId) public view returns (bool) {
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
        if (depositAddress == address(0)) revert DESTINATION_NOT_SET();
        if (maxTransitAge == 0) revert TRANSIT_AGE_NOT_CONFIGURED();
        if (isStale(account, bondToken)) revert TRANSIT_STALE();
        uint256 outstanding = _positions[account][bondToken].cashOut + amount;
        uint256 cap = maxCashInTransit[bondToken];
        if (outstanding > cap) revert CAP_EXCEEDED(outstanding, cap);
    }

    function _checkBondsOut(address bondToken, address cashToken) private view {
        if (!BOND_REGISTRY.isApprovedPair(bondToken, cashToken)) revert PAIR_NOT_APPROVED();
        if (redeemHoldingWallet == address(0)) revert DESTINATION_NOT_SET();
        if (maxTransitAge == 0) revert TRANSIT_AGE_NOT_CONFIGURED();
    }

    /// @dev Append a lot to the pair's queue. Ids are global and start at 1 so that zero means "none".
    function _openLot(
        Position storage p,
        address account,
        address bondToken,
        LotKind kind,
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
            recorded: amount,
            open: amount
        });
        p.lotIds.push(lotId);
    }

    function _decreaseCash(uint256 lotId, uint256 amount) private returns (Lot storage lot, Position storage p) {
        (lot, p) = _openLotOfKind(lotId, LotKind.CASH_OUT);
        _decrease(lot, p, amount);
        p.cashOut -= amount;
        totalCashInTransit[lot.bondToken] -= amount;
    }

    function _decreaseBonds(uint256 lotId, uint256 shares) private returns (Lot storage lot, Position storage p) {
        (lot, p) = _openLotOfKind(lotId, LotKind.BONDS_OUT);
        _decrease(lot, p, shares);
        p.bondsOut -= shares;
    }

    function _openLotOfKind(uint256 lotId, LotKind kind) private view returns (Lot storage lot, Position storage p) {
        lot = _lots[lotId];
        if (lot.recorded == 0) revert LOT_NOT_FOUND(lotId);
        if (lot.kind != kind) revert LOT_KIND_MISMATCH(lotId);
        p = _positions[lot.account][lot.bondToken];
    }

    /// @dev Decrease one lot, never below zero, and move the queue head past it once it closes.
    function _decrease(Lot storage lot, Position storage p, uint256 amount) private {
        if (amount == 0) revert ZERO_AMOUNT();
        if (amount > lot.open) revert EXCEEDS_OPEN(lot.open, amount);
        lot.open -= amount;
        if (lot.open == 0) _advanceHead(p);
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
