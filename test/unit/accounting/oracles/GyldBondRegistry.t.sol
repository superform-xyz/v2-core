// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

// external
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

// Superform
import { GyldBondRegistry } from "../../../../src/accounting/oracles/GyldBondRegistry.sol";

import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockAggregator } from "../../../mocks/MockAggregator.sol";

/// @dev A token whose `decimals()` can change after deployment. Exists only to prove `refreshScales` actually
///      re-reads the chain rather than returning the value frozen at registration.
contract MockMutableDecimals {
    uint8 public decimals;

    constructor(uint8 decimals_) {
        decimals = decimals_;
    }

    function setDecimals(uint8 decimals_) external {
        decimals = decimals_;
    }
}

/// @title GyldBondRegistryTest
/// @notice Exhaustive lifecycle coverage for `GyldBondRegistry`: role gating, every rejected registration,
///         the two timelocked change paths, the un-timelocked incident switch, deregistration, and the
///         never-reverting views the guard hook depends on.
contract GyldBondRegistryTest is Test {
    GyldBondRegistry internal registry;

    MockERC20 internal bond;
    MockERC20 internal cash;
    MockAggregator internal navFeed;
    MockAggregator internal cashFeed;

    address internal admin = address(0xA11CE);
    address internal manager = address(0xB0B);
    address internal outsider = address(0xBAD);

    uint256 internal constant MAX_OBS_AGE = 2 days;
    uint256 internal constant MAX_PUB_AGE = 1 days;

    /// @dev Cached locally because every read of these is an external call, and an external call inside an
    ///      argument list consumes a pending `vm.prank` or `vm.expectRevert`.
    bytes32 internal MANAGER_ROLE;
    uint8 internal KIND_CHAINLINK;
    uint8 internal KIND_NATIVE;

    function setUp() public {
        registry = new GyldBondRegistry(admin);
        MANAGER_ROLE = registry.INSTRUMENT_MANAGER_ROLE();
        KIND_CHAINLINK = registry.FEED_KIND_CHAINLINK();
        KIND_NATIVE = registry.FEED_KIND_GYLD_NATIVE();
        vm.prank(admin);
        registry.grantRole(MANAGER_ROLE, manager);

        bond = new MockERC20("Gyld Bond", "GBOND", 18);
        cash = new MockERC20("USD Coin", "USDC", 6);
        navFeed = new MockAggregator(8);
        cashFeed = new MockAggregator(8);
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _cfg() internal view returns (GyldBondRegistry.InstrumentConfig memory cfg) {
        cfg.bondToken = address(bond);
        cfg.navFeed = address(navFeed);
        cfg.navFeedKind = KIND_CHAINLINK;
        cfg.cashToken = address(cash);
        cfg.maxObservationAge = MAX_OBS_AGE;
        cfg.maxPublicationAge = MAX_PUB_AGE;
    }

    function _register(GyldBondRegistry.InstrumentConfig memory cfg) internal {
        vm.prank(manager);
        registry.registerInstrument(cfg);
    }

    function _expectUnauthorized(address caller) internal {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, caller, MANAGER_ROLE)
        );
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_GrantsBothRolesToAdmin() public view {
        assertTrue(registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(registry.hasRole(registry.INSTRUMENT_MANAGER_ROLE(), admin));
    }

    function test_Constructor_RevertIf_AdminZero() public {
        vm.expectRevert(GyldBondRegistry.ZERO_ADDRESS.selector);
        new GyldBondRegistry(address(0));
    }

    function test_Constants() public view {
        assertEq(registry.DEREGISTER_DELAY(), 2 days);
        assertEq(registry.MAX_AGE_CEILING(), 30 days);
        assertEq(registry.FEED_KIND_CHAINLINK(), 0);
        assertEq(registry.FEED_KIND_GYLD_NATIVE(), 1);
        assertEq(registry.INSTRUMENT_MANAGER_ROLE(), keccak256("INSTRUMENT_MANAGER_ROLE"));
    }

    /*//////////////////////////////////////////////////////////////
                              REGISTRATION
    //////////////////////////////////////////////////////////////*/

    function test_Register_StoresConfigAndPrecomputesScales() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.cashFeed = address(cashFeed);
        cfg.navMinAnswer = 1;
        cfg.navMaxAnswer = 1e12;
        cfg.sequencerUptimeFeed = address(0xFEED);
        cfg.gracePeriod = 1 hours;

        vm.expectEmit(true, true, true, true);
        emit GyldBondRegistry.InstrumentRegistered(address(bond), address(navFeed), address(cash));
        _register(cfg);

        GyldBondRegistry.InstrumentConfig memory stored = registry.getInstrumentConfig(address(bond));
        assertEq(stored.bondToken, address(bond));
        assertEq(stored.bondScale, 1e18, "bond scale from decimals()");
        assertEq(stored.cashScale, 1e6, "cash scale from decimals()");
        assertEq(stored.navFeedScale, 1e8, "nav feed scale from decimals()");
        assertEq(stored.cashFeedScale, 1e8, "cash feed scale from decimals()");
        assertEq(stored.navFeed, address(navFeed));
        assertEq(stored.cashFeed, address(cashFeed));
        assertEq(stored.navMinAnswer, 1);
        assertEq(stored.navMaxAnswer, 1e12);
        assertEq(stored.maxObservationAge, MAX_OBS_AGE);
        assertEq(stored.maxPublicationAge, MAX_PUB_AGE);
        assertEq(stored.sequencerUptimeFeed, address(0xFEED));
        assertEq(stored.gracePeriod, 1 hours);
        assertTrue(stored.registered);
    }

    /// @dev No cash feed means no cash feed scale: zero, not a reverting `decimals()` call on address(0).
    function test_Register_NoCashFeed_LeavesCashFeedScaleZero() public {
        _register(_cfg());
        assertEq(registry.getInstrumentConfig(address(bond)).cashFeedScale, 0);
    }

    /// @dev An instrument is never born suspended or pre-loaded with a recovery NAV, whatever the caller asks.
    function test_Register_IgnoresCallerSuppliedSuspensionAndRecoveryNav() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navSuspended = true;
        cfg.recoveryNav = 999e6;
        _register(cfg);

        GyldBondRegistry.InstrumentConfig memory stored = registry.getInstrumentConfig(address(bond));
        assertFalse(stored.navSuspended, "not born suspended");
        assertEq(stored.recoveryNav, 0, "not born with a recovery NAV");
    }

    function test_Register_RevertIf_NotManager() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        _expectUnauthorized(outsider);
        vm.prank(outsider);
        registry.registerInstrument(cfg);
    }

    function test_Register_RevertIf_AlreadyRegistered() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        _register(cfg);
        vm.expectRevert(GyldBondRegistry.INSTRUMENT_ALREADY_REGISTERED.selector);
        _register(cfg);
    }

    function test_Register_RevertIf_BondTokenZero() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.bondToken = address(0);
        vm.expectRevert(GyldBondRegistry.ZERO_ADDRESS.selector);
        _register(cfg);
    }

    function test_Register_RevertIf_NavFeedZero() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navFeed = address(0);
        vm.expectRevert(GyldBondRegistry.ZERO_ADDRESS.selector);
        _register(cfg);
    }

    function test_Register_RevertIf_CashTokenZero() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.cashToken = address(0);
        vm.expectRevert(GyldBondRegistry.ZERO_ADDRESS.selector);
        _register(cfg);
    }

    function test_Register_RevertIf_IdenticalTokens() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.cashToken = address(bond);
        vm.expectRevert(GyldBondRegistry.IDENTICAL_TOKENS.selector);
        _register(cfg);
    }

    function test_Register_RevertIf_FeedKindUnknown() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navFeedKind = 2;
        vm.expectRevert(GyldBondRegistry.INVALID_FEED_KIND.selector);
        _register(cfg);
    }

    /// @dev THE "assume cash equals one dollar" BUG. A USD-denominated NAV with no cash feed must be
    ///      unconfigurable, not merely discouraged.
    function test_Register_RevertIf_UsdDenominatedWithoutCashFeed() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navIsUsdDenominated = true;
        vm.expectRevert(GyldBondRegistry.CASH_FEED_REQUIRED.selector);
        _register(cfg);
    }

    function test_Register_UsdDenominatedWithCashFeed_Allowed() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navIsUsdDenominated = true;
        cfg.cashFeed = address(cashFeed);
        _register(cfg);
        assertTrue(registry.getInstrumentConfig(address(bond)).navIsUsdDenominated);
    }

    /// @dev A Chainlink-style feed cannot express an observation clock, so it cannot serve an instrument that
    ///      requires one.
    function test_Register_RevertIf_RequiresObservationTimeOnChainlinkFeed() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.requiresObservationTime = true;
        vm.expectRevert(GyldBondRegistry.INVALID_FEED_KIND.selector);
        _register(cfg);
    }

    function test_Register_RequiresObservationTimeOnNativeFeed_Allowed() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.requiresObservationTime = true;
        cfg.navFeedKind = KIND_NATIVE;
        _register(cfg);
        assertTrue(registry.getInstrumentConfig(address(bond)).requiresObservationTime);
    }

    function test_Register_RevertIf_ObservationAgeZero() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.maxObservationAge = 0;
        vm.expectRevert(GyldBondRegistry.INVALID_STALENESS.selector);
        _register(cfg);
    }

    function test_Register_RevertIf_PublicationAgeZero() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.maxPublicationAge = 0;
        vm.expectRevert(GyldBondRegistry.INVALID_STALENESS.selector);
        _register(cfg);
    }

    function test_Register_RevertIf_ObservationAgeAboveCeiling() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.maxObservationAge = 30 days + 1;
        vm.expectRevert(GyldBondRegistry.INVALID_STALENESS.selector);
        _register(cfg);
    }

    function test_Register_RevertIf_PublicationAgeAboveCeiling() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.maxPublicationAge = 30 days + 1;
        vm.expectRevert(GyldBondRegistry.INVALID_STALENESS.selector);
        _register(cfg);
    }

    function test_Register_AgesExactlyAtCeiling_Allowed() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.maxObservationAge = 30 days;
        cfg.maxPublicationAge = 30 days;
        _register(cfg);
        assertEq(registry.getInstrumentConfig(address(bond)).maxPublicationAge, 30 days);
    }

    function test_Register_RevertIf_NavMinAnswerNegative() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navMinAnswer = -1;
        vm.expectRevert(GyldBondRegistry.INVALID_BOUNDS.selector);
        _register(cfg);
    }

    function test_Register_RevertIf_NavMaxAnswerNegative() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navMaxAnswer = -1;
        vm.expectRevert(GyldBondRegistry.INVALID_BOUNDS.selector);
        _register(cfg);
    }

    function test_Register_RevertIf_NavMinAboveMax() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navMinAnswer = 100;
        cfg.navMaxAnswer = 100;
        vm.expectRevert(GyldBondRegistry.INVALID_BOUNDS.selector);
        _register(cfg);
    }

    function test_Register_RevertIf_CashBoundsInverted() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.cashFeed = address(cashFeed);
        cfg.cashMinAnswer = 200;
        cfg.cashMaxAnswer = 100;
        vm.expectRevert(GyldBondRegistry.INVALID_BOUNDS.selector);
        _register(cfg);
    }

    function test_Register_RevertIf_CashMinAnswerNegative() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.cashMinAnswer = -5;
        vm.expectRevert(GyldBondRegistry.INVALID_BOUNDS.selector);
        _register(cfg);
    }

    /// @dev A zero max disables the upper side, so a non-zero min alone is legal.
    function test_Register_MinWithZeroMax_Allowed() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navMinAnswer = 100;
        cfg.navMaxAnswer = 0;
        _register(cfg);
        assertEq(registry.getInstrumentConfig(address(bond)).navMinAnswer, 100);
    }

    /*//////////////////////////////////////////////////////////////
                               REFRESH SCALES
    //////////////////////////////////////////////////////////////*/

    function test_RefreshScales_RereadsDecimals() public {
        MockMutableDecimals mutableBond = new MockMutableDecimals(18);
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.bondToken = address(mutableBond);
        _register(cfg);
        assertEq(registry.getInstrumentConfig(address(mutableBond)).bondScale, 1e18);

        mutableBond.setDecimals(6);
        vm.expectEmit(true, true, true, true);
        emit GyldBondRegistry.CircuitBreakerBoundsRefreshed(address(mutableBond));
        vm.prank(manager);
        registry.refreshScales(address(mutableBond));

        assertEq(registry.getInstrumentConfig(address(mutableBond)).bondScale, 1e6, "rescaled");
    }

    function test_RefreshScales_RevertIf_NotManager() public {
        _register(_cfg());
        _expectUnauthorized(outsider);
        vm.prank(outsider);
        registry.refreshScales(address(bond));
    }

    function test_RefreshScales_RevertIf_NotRegistered() public {
        vm.expectRevert(GyldBondRegistry.INSTRUMENT_NOT_REGISTERED.selector);
        vm.prank(manager);
        registry.refreshScales(address(bond));
    }

    /*//////////////////////////////////////////////////////////////
                             STALENESS BOUNDS
    //////////////////////////////////////////////////////////////*/

    function test_SetStalenessBounds_Updates() public {
        _register(_cfg());
        vm.expectEmit(true, true, true, true);
        emit GyldBondRegistry.StalenessBoundsUpdated(address(bond), 3 days, 4 days);
        vm.prank(manager);
        registry.setStalenessBounds(address(bond), 3 days, 4 days);

        GyldBondRegistry.InstrumentConfig memory stored = registry.getInstrumentConfig(address(bond));
        assertEq(stored.maxObservationAge, 3 days);
        assertEq(stored.maxPublicationAge, 4 days);
    }

    function test_SetStalenessBounds_RevertIf_NotManager() public {
        _register(_cfg());
        _expectUnauthorized(outsider);
        vm.prank(outsider);
        registry.setStalenessBounds(address(bond), 1 days, 1 days);
    }

    function test_SetStalenessBounds_RevertIf_NotRegistered() public {
        vm.expectRevert(GyldBondRegistry.INSTRUMENT_NOT_REGISTERED.selector);
        vm.prank(manager);
        registry.setStalenessBounds(address(bond), 1 days, 1 days);
    }

    function test_SetStalenessBounds_RevertIf_Zero() public {
        _register(_cfg());
        vm.expectRevert(GyldBondRegistry.INVALID_STALENESS.selector);
        vm.prank(manager);
        registry.setStalenessBounds(address(bond), 0, 1 days);
    }

    function test_SetStalenessBounds_RevertIf_AboveCeiling() public {
        _register(_cfg());
        vm.expectRevert(GyldBondRegistry.INVALID_STALENESS.selector);
        vm.prank(manager);
        registry.setStalenessBounds(address(bond), 1 days, 31 days);
    }

    /*//////////////////////////////////////////////////////////////
                           THE INCIDENT SWITCH
    //////////////////////////////////////////////////////////////*/

    /// @dev Deliberately NOT timelocked: an impairing instrument cannot wait two days.
    function test_SetNavSuspended_TakesEffectImmediately() public {
        _register(_cfg());
        vm.expectEmit(true, true, true, true);
        emit GyldBondRegistry.NavSuspended(address(bond), true);
        vm.prank(manager);
        registry.setNavSuspended(address(bond), true);
        assertTrue(registry.getInstrumentConfig(address(bond)).navSuspended);

        vm.prank(manager);
        registry.setNavSuspended(address(bond), false);
        assertFalse(registry.getInstrumentConfig(address(bond)).navSuspended);
    }

    function test_SetNavSuspended_RevertIf_NotManager() public {
        _register(_cfg());
        _expectUnauthorized(outsider);
        vm.prank(outsider);
        registry.setNavSuspended(address(bond), true);
    }

    function test_SetNavSuspended_RevertIf_NotRegistered() public {
        vm.expectRevert(GyldBondRegistry.INSTRUMENT_NOT_REGISTERED.selector);
        vm.prank(manager);
        registry.setNavSuspended(address(bond), true);
    }

    /*//////////////////////////////////////////////////////////////
                              RECOVERY NAV
    //////////////////////////////////////////////////////////////*/

    function test_RecoveryNav_ProposeThenExecuteAfterDelay() public {
        _register(_cfg());

        uint256 executeAt = block.timestamp + registry.DEREGISTER_DELAY();
        vm.expectEmit(true, true, true, true);
        emit GyldBondRegistry.RecoveryNavProposed(address(bond), 42e6, executeAt);
        vm.prank(manager);
        registry.proposeRecoveryNav(address(bond), 42e6);
        assertEq(registry.pendingRecoveryNav(address(bond)), 42e6);
        assertEq(registry.pendingRecoveryNavAt(address(bond)), executeAt);

        vm.warp(executeAt);
        vm.expectEmit(true, true, true, true);
        emit GyldBondRegistry.RecoveryNavSet(address(bond), 42e6);
        vm.prank(manager);
        registry.executeRecoveryNav(address(bond));

        assertEq(registry.getInstrumentConfig(address(bond)).recoveryNav, 42e6);
        assertEq(registry.pendingRecoveryNav(address(bond)), 0, "pending cleared");
        assertEq(registry.pendingRecoveryNavAt(address(bond)), 0, "pending cleared");
    }

    function test_RecoveryNav_RevertIf_ProposeNotManager() public {
        _register(_cfg());
        _expectUnauthorized(outsider);
        vm.prank(outsider);
        registry.proposeRecoveryNav(address(bond), 1);
    }

    function test_RecoveryNav_RevertIf_ProposeNotRegistered() public {
        vm.expectRevert(GyldBondRegistry.INSTRUMENT_NOT_REGISTERED.selector);
        vm.prank(manager);
        registry.proposeRecoveryNav(address(bond), 1);
    }

    function test_RecoveryNav_RevertIf_ExecuteNotPending() public {
        _register(_cfg());
        vm.expectRevert(GyldBondRegistry.CHANGE_NOT_PENDING.selector);
        vm.prank(manager);
        registry.executeRecoveryNav(address(bond));
    }

    function test_RecoveryNav_RevertIf_TimelockNotElapsed() public {
        _register(_cfg());
        vm.prank(manager);
        registry.proposeRecoveryNav(address(bond), 1);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY() - 1);
        vm.expectRevert(GyldBondRegistry.CHANGE_TIMELOCK_NOT_ELAPSED.selector);
        vm.prank(manager);
        registry.executeRecoveryNav(address(bond));
    }

    function test_RecoveryNav_RevertIf_ExecuteNotManager() public {
        _register(_cfg());
        vm.prank(manager);
        registry.proposeRecoveryNav(address(bond), 1);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        _expectUnauthorized(outsider);
        vm.prank(outsider);
        registry.executeRecoveryNav(address(bond));
    }

    /*//////////////////////////////////////////////////////////////
                              FEED CHANGE
    //////////////////////////////////////////////////////////////*/

    /// @dev The force-suspension IS the point: a feed swap must never silently re-point what a vault is
    ///      marked at, so resuming is a separate deliberate call.
    function test_FeedChange_ProposeExecute_ForceSuspendsAndRescales() public {
        _register(_cfg());
        MockAggregator newFeed = new MockAggregator(18);

        uint256 executeAt = block.timestamp + registry.DEREGISTER_DELAY();
        vm.expectEmit(true, true, true, true);
        emit GyldBondRegistry.FeedChangeProposed(address(bond), address(newFeed), 0, executeAt);
        vm.prank(manager);
        registry.proposeFeedChange(address(bond), address(newFeed), 0, 0, 0);
        assertEq(registry.pendingFeed(address(bond)), address(newFeed));
        assertEq(registry.pendingFeedKind(address(bond)), 0);
        assertEq(registry.pendingFeedAt(address(bond)), executeAt);

        vm.warp(executeAt);
        vm.prank(manager);
        registry.executeFeedChange(address(bond));

        GyldBondRegistry.InstrumentConfig memory stored = registry.getInstrumentConfig(address(bond));
        assertEq(stored.navFeed, address(newFeed));
        assertEq(stored.navFeedScale, 1e18, "scales refreshed for the new feed");
        assertTrue(stored.navSuspended, "feed change force-suspends valuation");
        assertEq(registry.pendingFeed(address(bond)), address(0), "pending cleared");
        assertEq(registry.pendingFeedAt(address(bond)), 0, "pending cleared");
    }

    function test_FeedChange_RevertIf_ProposeNotManager() public {
        _register(_cfg());
        _expectUnauthorized(outsider);
        vm.prank(outsider);
        registry.proposeFeedChange(address(bond), address(cashFeed), 0, 0, 0);
    }

    function test_FeedChange_RevertIf_ProposeNotRegistered() public {
        vm.expectRevert(GyldBondRegistry.INSTRUMENT_NOT_REGISTERED.selector);
        vm.prank(manager);
        registry.proposeFeedChange(address(bond), address(cashFeed), 0, 0, 0);
    }

    function test_FeedChange_RevertIf_NewFeedZero() public {
        _register(_cfg());
        vm.expectRevert(GyldBondRegistry.ZERO_ADDRESS.selector);
        vm.prank(manager);
        registry.proposeFeedChange(address(bond), address(0), 0, 0, 0);
    }

    function test_FeedChange_RevertIf_KindUnknown() public {
        _register(_cfg());
        vm.expectRevert(GyldBondRegistry.INVALID_FEED_KIND.selector);
        vm.prank(manager);
        registry.proposeFeedChange(address(bond), address(cashFeed), 2, 0, 0);
    }

    function test_FeedChange_RevertIf_ExecuteNotPending() public {
        _register(_cfg());
        vm.expectRevert(GyldBondRegistry.CHANGE_NOT_PENDING.selector);
        vm.prank(manager);
        registry.executeFeedChange(address(bond));
    }

    function test_FeedChange_RevertIf_TimelockNotElapsed() public {
        _register(_cfg());
        vm.prank(manager);
        registry.proposeFeedChange(address(bond), address(cashFeed), 0, 0, 0);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY() - 1);
        vm.expectRevert(GyldBondRegistry.CHANGE_TIMELOCK_NOT_ELAPSED.selector);
        vm.prank(manager);
        registry.executeFeedChange(address(bond));
    }

    function test_FeedChange_RevertIf_ExecuteNotManager() public {
        _register(_cfg());
        vm.prank(manager);
        registry.proposeFeedChange(address(bond), address(cashFeed), 0, 0, 0);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        _expectUnauthorized(outsider);
        vm.prank(outsider);
        registry.executeFeedChange(address(bond));
    }

    /// @dev An instrument that requires an observation clock cannot be downgraded to a feed that has none,
    ///      even through the timelocked path.
    function test_FeedChange_RevertIf_DowngradesAFeedThatMustExposeObservationTime() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.requiresObservationTime = true;
        cfg.navFeedKind = KIND_NATIVE;
        _register(cfg);

        vm.prank(manager);
        registry.proposeFeedChange(address(bond), address(cashFeed), KIND_CHAINLINK, 0, 0);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        vm.expectRevert(GyldBondRegistry.INVALID_FEED_KIND.selector);
        vm.prank(manager);
        registry.executeFeedChange(address(bond));
    }

    /*//////////////////////////////////////////////////////////////
                             DEREGISTRATION
    //////////////////////////////////////////////////////////////*/

    function test_Deregister_ProposeExecute_DeletesConfig() public {
        _register(_cfg());

        uint256 executeAt = block.timestamp + registry.DEREGISTER_DELAY();
        vm.expectEmit(true, true, true, true);
        emit GyldBondRegistry.InstrumentDeregistrationProposed(address(bond), executeAt);
        vm.prank(manager);
        registry.proposeDeregisterInstrument(address(bond));
        assertEq(registry.pendingDeregistration(address(bond)), executeAt);

        vm.warp(executeAt);
        vm.expectEmit(true, true, true, true);
        emit GyldBondRegistry.InstrumentDeregistered(address(bond));
        vm.prank(manager);
        registry.executeDeregisterInstrument(address(bond));

        assertFalse(registry.isRegistered(address(bond)));
        assertEq(registry.pendingDeregistration(address(bond)), 0);
        vm.expectRevert(GyldBondRegistry.INSTRUMENT_NOT_REGISTERED.selector);
        registry.getInstrumentConfig(address(bond));
    }

    function test_Deregister_Cancel() public {
        _register(_cfg());
        vm.prank(manager);
        registry.proposeDeregisterInstrument(address(bond));

        vm.expectEmit(true, true, true, true);
        emit GyldBondRegistry.InstrumentDeregistrationCancelled(address(bond));
        vm.prank(manager);
        registry.cancelDeregisterInstrument(address(bond));

        assertEq(registry.pendingDeregistration(address(bond)), 0);
        assertTrue(registry.isRegistered(address(bond)), "still registered after a cancelled proposal");
    }

    function test_Deregister_RevertIf_ProposeNotManager() public {
        _register(_cfg());
        _expectUnauthorized(outsider);
        vm.prank(outsider);
        registry.proposeDeregisterInstrument(address(bond));
    }

    function test_Deregister_RevertIf_ProposeNotRegistered() public {
        vm.expectRevert(GyldBondRegistry.INSTRUMENT_NOT_REGISTERED.selector);
        vm.prank(manager);
        registry.proposeDeregisterInstrument(address(bond));
    }

    function test_Deregister_RevertIf_ExecuteNotPending() public {
        _register(_cfg());
        vm.expectRevert(GyldBondRegistry.DEREGISTRATION_NOT_PENDING.selector);
        vm.prank(manager);
        registry.executeDeregisterInstrument(address(bond));
    }

    function test_Deregister_RevertIf_TimelockNotElapsed() public {
        _register(_cfg());
        vm.prank(manager);
        registry.proposeDeregisterInstrument(address(bond));
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY() - 1);
        vm.expectRevert(GyldBondRegistry.DEREGISTRATION_TIMELOCK_NOT_ELAPSED.selector);
        vm.prank(manager);
        registry.executeDeregisterInstrument(address(bond));
    }

    function test_Deregister_RevertIf_ExecuteNotManager() public {
        _register(_cfg());
        vm.prank(manager);
        registry.proposeDeregisterInstrument(address(bond));
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        _expectUnauthorized(outsider);
        vm.prank(outsider);
        registry.executeDeregisterInstrument(address(bond));
    }

    function test_Deregister_RevertIf_CancelNotPending() public {
        _register(_cfg());
        vm.expectRevert(GyldBondRegistry.DEREGISTRATION_NOT_PENDING.selector);
        vm.prank(manager);
        registry.cancelDeregisterInstrument(address(bond));
    }

    function test_Deregister_RevertIf_CancelNotManager() public {
        _register(_cfg());
        vm.prank(manager);
        registry.proposeDeregisterInstrument(address(bond));
        _expectUnauthorized(outsider);
        vm.prank(outsider);
        registry.cancelDeregisterInstrument(address(bond));
    }

    /// @dev Re-registration after a completed deregistration must start from a clean slate.
    function test_Deregister_ThenReRegister_StartsClean() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        _register(cfg);
        vm.prank(manager);
        registry.setNavSuspended(address(bond), true);

        vm.prank(manager);
        registry.proposeDeregisterInstrument(address(bond));
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        vm.prank(manager);
        registry.executeDeregisterInstrument(address(bond));

        _register(cfg);
        assertFalse(registry.getInstrumentConfig(address(bond)).navSuspended, "suspension did not survive");
    }

    /*//////////////////////////////////////////////////////////////
                             TOTAL VIEWS
    //////////////////////////////////////////////////////////////*/

    function test_IsRegistered_NeverReverts() public {
        assertFalse(registry.isRegistered(address(bond)));
        assertFalse(registry.isRegistered(address(0)));
        _register(_cfg());
        assertTrue(registry.isRegistered(address(bond)));
    }

    function test_IsApprovedPair_NeverReverts() public {
        assertFalse(registry.isApprovedPair(address(bond), address(cash)), "unregistered");
        _register(_cfg());
        assertTrue(registry.isApprovedPair(address(bond), address(cash)));
        assertFalse(registry.isApprovedPair(address(bond), address(0xDEAD)), "wrong cash denomination");
        assertFalse(registry.isApprovedPair(address(cash), address(bond)), "not symmetric");
    }

    function test_GetInstrumentConfig_RevertIf_NotRegistered() public {
        vm.expectRevert(GyldBondRegistry.INSTRUMENT_NOT_REGISTERED.selector);
        registry.getInstrumentConfig(address(bond));
    }

    /*//////////////////////////////////////////////////////////////
                                 FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Register_AgeBoundsRespectCeiling(uint256 obsAge, uint256 pubAge) public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.maxObservationAge = obsAge;
        cfg.maxPublicationAge = pubAge;

        bool valid = obsAge != 0 && pubAge != 0 && obsAge <= 30 days && pubAge <= 30 days;
        if (!valid) vm.expectRevert(GyldBondRegistry.INVALID_STALENESS.selector);
        _register(cfg);
        assertEq(registry.isRegistered(address(bond)), valid);
    }

    function testFuzz_Register_BoundsNeverNegativeAndOrdered(int192 minAnswer, int192 maxAnswer) public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navMinAnswer = minAnswer;
        cfg.navMaxAnswer = maxAnswer;

        bool valid = minAnswer >= 0 && maxAnswer >= 0 && (maxAnswer == 0 || minAnswer < maxAnswer);
        if (!valid) vm.expectRevert(GyldBondRegistry.INVALID_BOUNDS.selector);
        _register(cfg);
        assertEq(registry.isRegistered(address(bond)), valid);
    }
}
