// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

// external
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

// Superform
import { GyldBondRegistry } from "../../../../src/accounting/oracles/GyldBondRegistry.sol";

import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockAggregator } from "../../../mocks/MockAggregator.sol";
import {
    MockRevertingFeed,
    MockAbsurdDecimalsERC20,
    MockEmptyReturnFeed
} from "../../../mocks/gyld/GyldAdversarialMocks.sol";

/// @title GyldBondRegistryAdversarialTest
/// @notice Adversarial and lifecycle-interaction coverage for `GyldBondRegistry`, beyond the happy and
///         rejected paths in `GyldBondRegistry.t.sol`: pending proposals crossing a deregistration, role
///         changes landing mid-timelock, multi-instrument isolation, and hostile token or feed metadata.
contract GyldBondRegistryAdversarialTest is Test {
    GyldBondRegistry internal registry;

    MockERC20 internal bond;
    MockERC20 internal otherBond;
    MockERC20 internal cash;
    MockAggregator internal navFeed;
    MockAggregator internal otherFeed;

    address internal admin = address(0xA11CE);
    address internal manager = address(0xB0B);
    address internal outsider = address(0xBAD);

    bytes32 internal MANAGER_ROLE;
    bytes32 internal ADMIN_ROLE;
    uint8 internal KIND_CHAINLINK;
    uint8 internal KIND_NATIVE;

    function setUp() public {
        vm.warp(1_800_000_000);
        registry = new GyldBondRegistry(admin);
        MANAGER_ROLE = registry.INSTRUMENT_MANAGER_ROLE();
        ADMIN_ROLE = registry.DEFAULT_ADMIN_ROLE();
        KIND_CHAINLINK = registry.FEED_KIND_CHAINLINK();
        KIND_NATIVE = registry.FEED_KIND_GYLD_NATIVE();

        vm.prank(admin);
        registry.grantRole(MANAGER_ROLE, manager);

        bond = new MockERC20("Gyld Bond", "GBOND", 18);
        otherBond = new MockERC20("Other Bond", "OBOND", 8);
        cash = new MockERC20("USD Coin", "USDC", 6);
        navFeed = new MockAggregator(8);
        otherFeed = new MockAggregator(18);
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _cfg(address bondToken) internal view returns (GyldBondRegistry.InstrumentConfig memory cfg) {
        cfg.bondToken = bondToken;
        cfg.navFeed = address(navFeed);
        cfg.navFeedKind = KIND_CHAINLINK;
        cfg.cashToken = address(cash);
        cfg.maxObservationAge = 2 days;
        cfg.maxPublicationAge = 1 days;
    }

    function _register(address bondToken) internal {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg(bondToken);
        vm.prank(manager);
        registry.registerInstrument(cfg);
    }

    function _deregister(address bondToken) internal {
        vm.startPrank(manager);
        registry.proposeDeregisterInstrument(bondToken);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        registry.executeDeregisterInstrument(bondToken);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
          PENDING PROPOSALS CROSSING A DEREGISTRATION — FINDINGS
    //////////////////////////////////////////////////////////////*/

    /// @dev FINDING (awaiting an owner decision, pinned here so the behaviour is explicit).
    ///      `executeDeregisterInstrument` deletes `_instruments[bondToken]` and `pendingDeregistration`, but
    ///      NOT `pendingRecoveryNav` / `pendingRecoveryNavAt`. A proposal made against the OLD instrument
    ///      therefore survives deregistration and can be executed against a NEWLY registered instrument with
    ///      the same bond token, applying a terminal valuation override that was never proposed for it and
    ///      without a fresh two-day delay from the new registration.
    ///      Fix: clear every pending change in `executeDeregisterInstrument`.
    function test_Finding_PendingRecoveryNavSurvivesDeregistrationAndReRegistration() public {
        _register(address(bond));

        vm.prank(manager);
        registry.proposeRecoveryNav(address(bond), 0.4e6);
        uint256 executeAt = registry.pendingRecoveryNavAt(address(bond));

        _deregister(address(bond));
        assertEq(registry.pendingRecoveryNav(address(bond)), 0.4e6, "the proposal is NOT cleared");
        assertEq(registry.pendingRecoveryNavAt(address(bond)), executeAt, "and neither is its clock");

        // A fresh registration of the same bond token starts with no override, as the registry intends.
        _register(address(bond));
        assertEq(registry.getInstrumentConfig(address(bond)).recoveryNav, 0, "born clean");

        // But the stale proposal is still executable against it.
        vm.prank(manager);
        registry.executeRecoveryNav(address(bond));
        assertEq(
            registry.getInstrumentConfig(address(bond)).recoveryNav,
            0.4e6,
            "a stale proposal re-pointed the new instrument's valuation"
        );
    }

    /// @dev FINDING, same root cause on the feed-change path. Milder, because applying a feed change
    ///      force-suspends valuation, so the stale change cannot silently re-mark a position.
    function test_Finding_PendingFeedChangeSurvivesDeregistrationAndReRegistration() public {
        _register(address(bond));

        vm.prank(manager);
        registry.proposeFeedChange(address(bond), address(otherFeed), KIND_CHAINLINK);

        _deregister(address(bond));
        assertEq(registry.pendingFeed(address(bond)), address(otherFeed), "the proposal is NOT cleared");

        _register(address(bond));
        vm.prank(manager);
        registry.executeFeedChange(address(bond));

        GyldBondRegistry.InstrumentConfig memory stored = registry.getInstrumentConfig(address(bond));
        assertEq(stored.navFeed, address(otherFeed), "a stale proposal swapped the new instrument's feed");
        assertTrue(stored.navSuspended, "but it force-suspends, so nothing is silently re-marked");
    }

    /// @dev FINDING. Neither `executeRecoveryNav` nor `executeFeedChange` calls `_requireRegistered`, so both
    ///      can be executed against a bond token that is not registered at all, writing into a deleted struct.
    ///      Harmless today only because `registerInstrument` explicitly re-zeroes `recoveryNav`, and because
    ///      every oracle read gates on `registered`.
    function test_Finding_TimelockedChangesExecuteOnAnUnregisteredInstrument() public {
        _register(address(bond));
        vm.prank(manager);
        registry.proposeRecoveryNav(address(bond), 0.4e6);
        _deregister(address(bond));

        assertFalse(registry.isRegistered(address(bond)));
        vm.prank(manager);
        registry.executeRecoveryNav(address(bond)); // does not revert

        // The write landed on an unregistered instrument, which no read will honour.
        assertFalse(registry.isRegistered(address(bond)), "still unregistered");
        vm.expectRevert(GyldBondRegistry.INSTRUMENT_NOT_REGISTERED.selector);
        registry.getInstrumentConfig(address(bond));
    }

    /// @dev A re-proposal overwrites the pending value AND restarts the clock, so a manager cannot stack a
    ///      second change onto an almost-matured one.
    function test_ReProposingRecoveryNav_RestartsTheClock() public {
        _register(address(bond));
        vm.prank(manager);
        registry.proposeRecoveryNav(address(bond), 0.4e6);

        vm.warp(block.timestamp + registry.DEREGISTER_DELAY() - 1);
        vm.prank(manager);
        registry.proposeRecoveryNav(address(bond), 0.9e6);

        assertEq(registry.pendingRecoveryNav(address(bond)), 0.9e6, "value overwritten");
        assertEq(
            registry.pendingRecoveryNavAt(address(bond)),
            block.timestamp + registry.DEREGISTER_DELAY(),
            "clock restarted from the new proposal"
        );

        vm.expectRevert(GyldBondRegistry.CHANGE_TIMELOCK_NOT_ELAPSED.selector);
        vm.prank(manager);
        registry.executeRecoveryNav(address(bond));
    }

    function test_ReProposingFeedChange_RestartsTheClock() public {
        _register(address(bond));
        vm.prank(manager);
        registry.proposeFeedChange(address(bond), address(otherFeed), KIND_CHAINLINK);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY() - 1);
        vm.prank(manager);
        registry.proposeFeedChange(address(bond), address(navFeed), KIND_CHAINLINK);

        assertEq(registry.pendingFeed(address(bond)), address(navFeed));
        vm.expectRevert(GyldBondRegistry.CHANGE_TIMELOCK_NOT_ELAPSED.selector);
        vm.prank(manager);
        registry.executeFeedChange(address(bond));
    }

    /// @dev A cancelled deregistration cannot be executed later by replaying the original maturity.
    function test_CancelledDeregistration_CannotBeExecutedLater() public {
        _register(address(bond));
        vm.startPrank(manager);
        registry.proposeDeregisterInstrument(address(bond));
        registry.cancelDeregisterInstrument(address(bond));
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY() + 1);
        vm.expectRevert(GyldBondRegistry.DEREGISTRATION_NOT_PENDING.selector);
        registry.executeDeregisterInstrument(address(bond));
        vm.stopPrank();
        assertTrue(registry.isRegistered(address(bond)));
    }

    /// @dev A deregistration proposal can be executed at ANY time after it matures; there is no expiry window.
    ///      Worth knowing: a year-old proposal is still live.
    function test_MaturedDeregistration_NeverExpires() public {
        _register(address(bond));
        vm.prank(manager);
        registry.proposeDeregisterInstrument(address(bond));
        vm.warp(block.timestamp + 365 days);
        vm.prank(manager);
        registry.executeDeregisterInstrument(address(bond));
        assertFalse(registry.isRegistered(address(bond)));
    }

    /*//////////////////////////////////////////////////////////////
                           ROLE LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    /// @dev A manager key revoked mid-timelock cannot complete the change it proposed.
    function test_RevokedManager_CannotExecuteItsOwnPendingChange() public {
        _register(address(bond));
        vm.prank(manager);
        registry.proposeRecoveryNav(address(bond), 0.4e6);

        vm.prank(admin);
        registry.revokeRole(MANAGER_ROLE, manager);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, manager, MANAGER_ROLE)
        );
        vm.prank(manager);
        registry.executeRecoveryNav(address(bond));

        // The proposal itself survives, so another manager can still complete it. That is deliberate: the
        // proposal is the registry's, not the proposer's.
        vm.prank(admin);
        registry.executeRecoveryNav(address(bond));
        assertEq(registry.getInstrumentConfig(address(bond)).recoveryNav, 0.4e6);
    }

    function test_RenouncedManager_LosesAccess() public {
        _register(address(bond));
        vm.prank(manager);
        registry.renounceRole(MANAGER_ROLE, manager);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, manager, MANAGER_ROLE)
        );
        vm.prank(manager);
        registry.setNavSuspended(address(bond), true);
    }

    /// @dev Role ADMINISTRATION is not timelocked, so a compromised default admin can mint itself a manager
    ///      key instantly. The two-day delay protects the VALUE-changing calls, not the role graph.
    function test_DefaultAdmin_CanGrantItselfManagerInstantly() public {
        address newAdmin = address(0xC0DE);
        vm.prank(admin);
        registry.grantRole(ADMIN_ROLE, newAdmin);

        vm.prank(newAdmin);
        registry.grantRole(MANAGER_ROLE, newAdmin);
        _register(address(bond));

        vm.prank(newAdmin);
        registry.setNavSuspended(address(bond), true);
        assertTrue(registry.getInstrumentConfig(address(bond)).navSuspended, "no delay on the role graph");
    }

    function test_Outsider_CannotGrantRoles() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, outsider, ADMIN_ROLE)
        );
        vm.prank(outsider);
        registry.grantRole(MANAGER_ROLE, outsider);
    }

    /*//////////////////////////////////////////////////////////////
                        MULTI-INSTRUMENT ISOLATION
    //////////////////////////////////////////////////////////////*/

    /// @dev Two instruments sharing one cash token and one feed must not share state. Keying directly by
    ///      bond token is what makes this hold, and it is the property that fails in registries keyed by a
    ///      derived pseudo-address.
    function test_TwoInstruments_AreFullyIsolated() public {
        _register(address(bond));
        _register(address(otherBond));

        vm.prank(manager);
        registry.setNavSuspended(address(bond), true);
        assertTrue(registry.getInstrumentConfig(address(bond)).navSuspended);
        assertFalse(registry.getInstrumentConfig(address(otherBond)).navSuspended, "the sibling is untouched");

        vm.prank(manager);
        registry.setStalenessBounds(address(otherBond), 3 days, 3 days);
        assertEq(registry.getInstrumentConfig(address(bond)).maxPublicationAge, 1 days, "the sibling is untouched");

        // Scales are per-instrument, from each bond's own decimals.
        assertEq(registry.getInstrumentConfig(address(bond)).bondScale, 1e18);
        assertEq(registry.getInstrumentConfig(address(otherBond)).bondScale, 1e8);

        _deregister(address(bond));
        assertTrue(registry.isRegistered(address(otherBond)), "deregistering one does not touch the other");
        assertTrue(registry.isApprovedPair(address(otherBond), address(cash)));
    }

    /// @dev A pending change on one instrument does not mature on another.
    function test_PendingChanges_AreKeyedPerInstrument() public {
        _register(address(bond));
        _register(address(otherBond));
        vm.prank(manager);
        registry.proposeRecoveryNav(address(bond), 0.4e6);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());

        vm.expectRevert(GyldBondRegistry.CHANGE_NOT_PENDING.selector);
        vm.prank(manager);
        registry.executeRecoveryNav(address(otherBond));
    }

    /*//////////////////////////////////////////////////////////////
                    SUSPENSION IS NOT UNAPPROVAL — FINDING
    //////////////////////////////////////////////////////////////*/

    /// @dev IMPORTANT OPERATIONAL CONSEQUENCE. `isApprovedPair` stays TRUE while an instrument is suspended,
    ///      because suspension governs VALUATION, not tradability. `ApproveAndTradeGyldBondHook` gates only
    ///      on `isApprovedPair`, so a leaf that omits `GyldTradeGuardHook` can still trade a suspended
    ///      instrument. The guard is therefore MANDATORY in every Gyld leaf, not optional hardening.
    function test_Finding_SuspensionDoesNotUnapproveThePair() public {
        _register(address(bond));
        vm.prank(manager);
        registry.setNavSuspended(address(bond), true);

        assertTrue(
            registry.isApprovedPair(address(bond), address(cash)),
            "suspension governs valuation, NOT the trade hook's pair gate"
        );
    }

    /// @dev Deregistration, by contrast, does unapprove the pair, which is why it bricks a live position.
    function test_DeregistrationUnapprovesThePair() public {
        _register(address(bond));
        _deregister(address(bond));
        assertFalse(registry.isApprovedPair(address(bond), address(cash)));
    }

    /*//////////////////////////////////////////////////////////////
                     HOSTILE TOKEN AND FEED METADATA
    //////////////////////////////////////////////////////////////*/

    /// @dev A token claiming 78 decimals overflows `10 ** decimals()`. Registration must fail loudly rather
    ///      than storing a wrapped scale that would mis-value every read afterwards.
    function test_AbsurdDecimals_RevertsRegistration() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg(address(new MockAbsurdDecimalsERC20()));
        vm.expectRevert(); // arithmetic overflow in 10 ** 78
        vm.prank(manager);
        registry.registerInstrument(cfg);
    }

    /// @dev A feed whose `decimals()` reverts cannot be registered: no silent zero scale.
    function test_RevertingFeedDecimals_RevertsRegistration() public {
        MockRevertingFeed feed = new MockRevertingFeed();
        feed.setRevertOnDecimals(true);
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg(address(bond));
        cfg.navFeed = address(feed);

        vm.expectRevert(MockRevertingFeed.FEED_DEAD.selector);
        vm.prank(manager);
        registry.registerInstrument(cfg);
    }

    /// @dev A feed address with no `decimals()` at all returns empty data, which must fail the decode rather
    ///      than scale to one.
    function test_FeedWithoutDecimals_RevertsRegistration() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg(address(bond));
        cfg.navFeed = address(new MockEmptyReturnFeed());
        vm.expectRevert();
        vm.prank(manager);
        registry.registerInstrument(cfg);
    }

    /// @dev An EOA as the feed also fails, which rules out a typo'd address silently registering.
    function test_EoaAsFeed_RevertsRegistration() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg(address(bond));
        cfg.navFeed = address(0xDEAD);
        vm.expectRevert();
        vm.prank(manager);
        registry.registerInstrument(cfg);
    }

    /// @dev A cash feed that goes bad after registration cannot be fixed by `refreshScales`; it needs the
    ///      timelocked feed-change path. Pinned so nobody mistakes refresh for a feed swap.
    function test_RefreshScales_CannotReplaceAFeed() public {
        _register(address(bond));
        address before = registry.getInstrumentConfig(address(bond)).navFeed;
        vm.prank(manager);
        registry.refreshScales(address(bond));
        assertEq(registry.getInstrumentConfig(address(bond)).navFeed, before, "refresh never re-points a feed");
    }

    /*//////////////////////////////////////////////////////////////
                                 FUZZ
    //////////////////////////////////////////////////////////////*/

    /// @dev No sequence of suspend/unsuspend can leave an instrument unregistered or change its pair.
    function testFuzz_SuspensionTogglingNeverChangesRegistrationOrPair(bool[8] calldata flips) public {
        _register(address(bond));
        for (uint256 i; i < flips.length; ++i) {
            vm.prank(manager);
            registry.setNavSuspended(address(bond), flips[i]);
            assertTrue(registry.isRegistered(address(bond)));
            assertTrue(registry.isApprovedPair(address(bond), address(cash)));
        }
        assertEq(registry.getInstrumentConfig(address(bond)).navSuspended, flips[flips.length - 1]);
    }

    /// @dev A timelocked change is executable at its maturity and at no earlier second.
    function testFuzz_TimelockBoundaryIsExact(uint256 offset) public {
        offset = bound(offset, 0, 2 * registry.DEREGISTER_DELAY());
        _register(address(bond));
        vm.prank(manager);
        registry.proposeRecoveryNav(address(bond), 1e6);
        uint256 executeAt = registry.pendingRecoveryNavAt(address(bond));

        vm.warp(block.timestamp + offset);
        if (block.timestamp < executeAt) {
            vm.expectRevert(GyldBondRegistry.CHANGE_TIMELOCK_NOT_ELAPSED.selector);
            vm.prank(manager);
            registry.executeRecoveryNav(address(bond));
        } else {
            vm.prank(manager);
            registry.executeRecoveryNav(address(bond));
            assertEq(registry.getInstrumentConfig(address(bond)).recoveryNav, 1e6);
        }
    }
}
