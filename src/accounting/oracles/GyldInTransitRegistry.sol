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
/// @dev WHO MAY WRITE. `recordCashOut`/`recordBondsOut` are called by the ACCOUNT itself (hooks execute as the
///      account), so `msg.sender` cannot tell a hook from a direct call. That is accepted: a caller can only
///      increase its OWN entries, the only consumer of those entries is the valuation of that same account, a
///      SuperVault strategy can only reach this through root-authorised hooks, the cap bounds the exposure
///      and the hooks verify the matching transfer in the same atomic batch. Decreases are RECONCILER-only.
/// @dev DESTINATIONS ARE TIMELOCKED. A re-pointed deposit address is the drain vector for every open deposit
///      leaf, and the hooks cannot commit the address (it is not in calldata), so the first set is immediate
///      and every change waits `DESTINATION_DELAY` behind a visible proposal.
/// @dev WHAT THIS DOES NOT PROTECT: Gyld's withdrawal address being the strategy (an onboarding fact), the
///      order price (lives in the API), Gyld's custody and solvency.
contract GyldInTransitRegistry is AccessControl {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZERO_ADDRESS();
    error ZERO_AMOUNT();
    error INVALID_AGE();
    error INSTRUMENT_NOT_REGISTERED();
    /// @notice The (bond, cash) pair is not the registered instrument's pair
    error PAIR_NOT_APPROVED();
    /// @notice The destination this record needs is still zero
    error DESTINATION_NOT_SET();
    /// @notice `maxTransitAge` is zero; records are refused rather than valued forever
    error TRANSIT_AGE_NOT_CONFIGURED();
    /// @notice The account already has an entry older than `maxTransitAge` for this instrument
    error TRANSIT_STALE();
    /// @notice Outstanding cash plus this record would exceed the instrument's cap
    error CAP_EXCEEDED(uint256 outstanding, uint256 cap);
    /// @notice A settlement tried to clear more than is open
    error EXCEEDS_OPEN(uint256 open, uint256 requested);
    /// @notice `settleMint` with nothing received is a loss and must go through `settleLoss`
    error ZERO_BONDS_RECEIVED();
    error DESTINATIONS_ALREADY_SET();
    error CHANGE_NOT_PENDING();
    error CHANGE_TIMELOCK_NOT_ELAPSED();

    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/

    /// @notice What one account has at Gyld for one instrument
    /// @param cashOut Cash units sent to the deposit address and not yet minted against
    /// @param bondsOut Bond units sent to the holding wallet and not yet paid out
    /// @param bondsOutNav Weighted NAV at exit, cash units per whole bond; the oracle clamps it at the live NAV
    /// @param oldestOpenAt When the oldest still-open entry was recorded; zero when nothing is open
    struct Transit {
        uint256 cashOut;
        uint256 bondsOut;
        uint256 bondsOutNav;
        uint64 oldestOpenAt;
    }

    struct PendingDestinations {
        address depositAddress;
        address redeemHoldingWallet;
        uint64 executeAt;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant RECONCILER_ROLE = keccak256("RECONCILER_ROLE");
    /// @notice Delay on every destination CHANGE after the first set
    uint256 public constant DESTINATION_DELAY = 2 days;
    /// @notice Upper bound on `maxTransitAge`; a year-old entry is not "in transit"
    uint256 public constant MAX_TRANSIT_AGE_CEILING = 365 days;

    /// @notice The approved-instrument list; pairs and caps are validated against it
    GyldBondRegistry public immutable BOND_REGISTRY;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Gyld's deposit address for our account (`GET /deposit/address`)
    address public depositAddress;
    /// @notice Gyld's redeem holding wallet (`GET /portfolio.redeem_holding_wallet`)
    address public redeemHoldingWallet;
    /// @notice Entries older than this are valued at zero by the oracle and block new deposits
    uint256 public maxTransitAge;
    /// @notice Per-instrument cap on OUTSTANDING cash at Gyld, per account; zero disables the instrument
    mapping(address bondToken => uint256 cap) public maxCashInTransit;
    /// @notice Sum of `cashOut` over every account, for `getTVL`
    mapping(address bondToken => uint256 total) public totalCashInTransit;

    PendingDestinations public pendingDestinations;

    mapping(address account => mapping(address bondToken => Transit)) private _transit;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event DestinationsSet(address indexed depositAddress, address indexed redeemHoldingWallet);
    event DestinationsProposed(address indexed depositAddress, address indexed redeemHoldingWallet, uint256 executeAt);
    event DestinationsCancelled();
    event MaxTransitAgeUpdated(uint256 maxTransitAge);
    event MaxCashInTransitUpdated(address indexed bondToken, uint256 cap);
    event CashOutRecorded(
        address indexed account, address indexed bondToken, address cashToken, uint256 amount, uint256 newCashOut
    );
    event BondsOutRecorded(
        address indexed account,
        address indexed bondToken,
        address cashToken,
        uint256 shares,
        uint256 navNow,
        uint256 newBondsOut
    );
    event MintSettled(
        address indexed account,
        address indexed bondToken,
        bytes32 indexed apiRef,
        uint256 cashConsumed,
        uint256 bondsReceived,
        uint256 remainingCashOut
    );
    event TransitLoss(
        address indexed account,
        address indexed bondToken,
        bytes32 indexed apiRef,
        uint256 cashLost,
        uint256 remainingCashOut
    );
    event RedemptionSettled(
        address indexed account,
        address indexed bondToken,
        bytes32 indexed apiRef,
        uint256 bondsConsumed,
        uint256 cashReturned,
        uint256 remainingBondsOut
    );
    event ReturnSettled(
        address indexed account,
        address indexed bondToken,
        bytes32 indexed apiRef,
        uint256 bondsReturned,
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

    /*//////////////////////////////////////////////////////////////
                         ACCOUNT: RECORD (INCREASE ONLY)
    //////////////////////////////////////////////////////////////*/

    /// @notice Record cash sent to the deposit address. `msg.sender` is the account.
    function recordCashOut(address bondToken, address cashToken, uint256 amount) external {
        _checkCashOut(msg.sender, bondToken, cashToken, amount);
        Transit storage t = _transit[msg.sender][bondToken];
        if (t.oldestOpenAt == 0) t.oldestOpenAt = uint64(block.timestamp);
        t.cashOut += amount;
        totalCashInTransit[bondToken] += amount;
        emit CashOutRecorded(msg.sender, bondToken, cashToken, amount, t.cashOut);
    }

    /// @notice Record bonds sent to the redeem holding wallet. `msg.sender` is the account.
    /// @dev Neither the cap nor staleness applies: an exit must stay possible. `navNow` may be zero (NAV
    ///      unusable at exit); the entry is then valued at zero while in transit.
    function recordBondsOut(address bondToken, address cashToken, uint256 shares, uint256 navNow) external {
        _checkBondsOut(bondToken, cashToken);
        if (shares == 0) revert ZERO_AMOUNT();
        Transit storage t = _transit[msg.sender][bondToken];
        if (t.oldestOpenAt == 0) t.oldestOpenAt = uint64(block.timestamp);
        // Weighted average: two exits at different NAVs cannot share one snapshot. The oracle clamps the
        // result at the live NAV regardless.
        uint256 newBondsOut = t.bondsOut + shares;
        t.bondsOutNav = (t.bondsOut * t.bondsOutNav + shares * navNow) / newBondsOut;
        t.bondsOut = newBondsOut;
        emit BondsOutRecorded(msg.sender, bondToken, cashToken, shares, navNow, newBondsOut);
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
    ///         entry; 205 cap exceeded; 206 zero amount
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
        if (_transit[account][bondToken].cashOut + amount > maxCashInTransit[bondToken]) return 205;
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

    /// @notice A mint request reached `minted`: clear the cash it consumed.
    /// @param apiRef Gyld's `mint_request_id`, hashed or left-padded, for off-chain reconciliation
    function settleMint(
        address account,
        address bondToken,
        uint256 cashConsumed,
        uint256 bondsReceived,
        bytes32 apiRef
    )
        external
        onlyRole(RECONCILER_ROLE)
    {
        if (bondsReceived == 0) revert ZERO_BONDS_RECEIVED();
        Transit storage t = _transit[account][bondToken];
        _decreaseCash(t, bondToken, cashConsumed);
        emit MintSettled(account, bondToken, apiRef, cashConsumed, bondsReceived, t.cashOut);
        _closeIfEmpty(t);
    }

    /// @notice Cash that will never mint (fees, a failed order). Separate and loud on purpose.
    function settleLoss(
        address account,
        address bondToken,
        uint256 cashLost,
        bytes32 apiRef
    )
        external
        onlyRole(RECONCILER_ROLE)
    {
        Transit storage t = _transit[account][bondToken];
        _decreaseCash(t, bondToken, cashLost);
        emit TransitLoss(account, bondToken, apiRef, cashLost, t.cashOut);
        _closeIfEmpty(t);
    }

    /// @notice A redemption completed and the payout landed on the account.
    function settleRedemption(
        address account,
        address bondToken,
        uint256 bondsConsumed,
        uint256 cashReturned,
        bytes32 apiRef
    )
        external
        onlyRole(RECONCILER_ROLE)
    {
        Transit storage t = _transit[account][bondToken];
        _decreaseBonds(t, bondsConsumed);
        emit RedemptionSettled(account, bondToken, apiRef, bondsConsumed, cashReturned, t.bondsOut);
        _closeIfEmpty(t);
    }

    /// @notice A cancelled redemption returned the tokens to the account.
    function settleReturn(
        address account,
        address bondToken,
        uint256 bondsReturned,
        bytes32 apiRef
    )
        external
        onlyRole(RECONCILER_ROLE)
    {
        Transit storage t = _transit[account][bondToken];
        _decreaseBonds(t, bondsReturned);
        emit ReturnSettled(account, bondToken, apiRef, bondsReturned, t.bondsOut);
        _closeIfEmpty(t);
    }

    /*//////////////////////////////////////////////////////////////
                                  VIEWS
    //////////////////////////////////////////////////////////////*/

    function transit(address account, address bondToken) external view returns (Transit memory) {
        return _transit[account][bondToken];
    }

    function cashOut(address account, address bondToken) external view returns (uint256) {
        return _transit[account][bondToken].cashOut;
    }

    function bondsOut(address account, address bondToken) external view returns (uint256) {
        return _transit[account][bondToken].bondsOut;
    }

    /// @notice Whether the account's oldest open entry for the instrument is older than `maxTransitAge`
    /// @dev An unconfigured age reads as stale, so valuation never counts an entry nobody bounded.
    function isStale(address account, address bondToken) public view returns (bool) {
        uint64 openedAt = _transit[account][bondToken].oldestOpenAt;
        if (openedAt == 0) return false;
        uint256 age = maxTransitAge;
        if (age == 0) return true;
        return block.timestamp - openedAt > age;
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
        uint256 outstanding = _transit[account][bondToken].cashOut + amount;
        uint256 cap = maxCashInTransit[bondToken];
        if (outstanding > cap) revert CAP_EXCEEDED(outstanding, cap);
    }

    function _checkBondsOut(address bondToken, address cashToken) private view {
        if (!BOND_REGISTRY.isApprovedPair(bondToken, cashToken)) revert PAIR_NOT_APPROVED();
        if (redeemHoldingWallet == address(0)) revert DESTINATION_NOT_SET();
        if (maxTransitAge == 0) revert TRANSIT_AGE_NOT_CONFIGURED();
    }

    function _decreaseCash(Transit storage t, address bondToken, uint256 amount) private {
        if (amount == 0) revert ZERO_AMOUNT();
        if (amount > t.cashOut) revert EXCEEDS_OPEN(t.cashOut, amount);
        t.cashOut -= amount;
        totalCashInTransit[bondToken] -= amount;
    }

    function _decreaseBonds(Transit storage t, uint256 shares) private {
        if (shares == 0) revert ZERO_AMOUNT();
        if (shares > t.bondsOut) revert EXCEEDS_OPEN(t.bondsOut, shares);
        t.bondsOut -= shares;
    }

    /// @dev Nothing open: forget the age and the exit NAV so the next record starts a fresh clock.
    function _closeIfEmpty(Transit storage t) private {
        if (t.cashOut == 0 && t.bondsOut == 0) {
            t.oldestOpenAt = 0;
            t.bondsOutNav = 0;
        }
    }
}
