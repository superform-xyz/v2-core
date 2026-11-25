// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

import { ConfigureGyldBondRegistry } from "../../../script/ConfigureGyldBondRegistry.s.sol";
import { GyldBondRegistry } from "../../../src/accounting/oracles/GyldBondRegistry.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MockAggregator } from "../../mocks/MockAggregator.sol";

/// @title ConfigureGyldBondRegistryScriptTest
/// @notice `runRegisterInstrument`: the operator path for step 3 of the Gyld runbook. Registers through the
///         script, refuses what the registry would refuse with a NAMED reason plus the two script rules
///         (non-zero floors, readable decimals), and is a verified no-op on a re-run.
contract ConfigureGyldBondRegistryScriptTest is Test {
    ConfigureGyldBondRegistry internal script;
    GyldBondRegistry internal registry;
    MockERC20 internal bond;
    MockERC20 internal cash;
    MockAggregator internal feed;

    address internal admin = address(0xA11CE);
    // `broadcast(env)` wraps the body in vm.startBroadcast(): the registry sees forge's default sender
    address internal constant BROADCASTER = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    function setUp() public {
        vm.warp(1_800_000_000);
        bond = new MockERC20("Gyld Bond", "GBOND", 18);
        cash = new MockERC20("USD Coin", "USDC", 6);
        feed = new MockAggregator(8);
        feed.setLatestAnswer(1e8);
        registry = new GyldBondRegistry(admin);
        bytes32 role = registry.INSTRUMENT_MANAGER_ROLE();
        vm.prank(admin);
        registry.grantRole(role, BROADCASTER);
        script = new ConfigureGyldBondRegistry();
    }

    function _args() internal view returns (ConfigureGyldBondRegistry.InstrumentArgs memory a) {
        a.bondToken = address(bond);
        a.navFeed = address(feed);
        a.navFeedKind = 0;
        a.cashToken = address(cash);
        a.maxObservationAge = 7 days;
        a.maxPublicationAge = 7 days;
        a.maxEntryPremiumBps = 300;
        a.maxExitDiscountBps = 300;
    }

    function _run(ConfigureGyldBondRegistry.InstrumentArgs memory a) internal {
        script.runRegisterInstrument(2, uint64(block.chainid), address(registry), a);
    }

    /// @dev A revert inside `broadcast(env)` leaves forge's broadcast flag set; clear it so the next call can start one
    function _refused(ConfigureGyldBondRegistry.InstrumentArgs memory a, string memory reason) internal {
        vm.expectRevert(bytes(reason));
        _run(a);
        vm.stopBroadcast();
    }

    function test_RegistersAndVerifies_ThenRerunIsANoop() public {
        ConfigureGyldBondRegistry.InstrumentArgs memory a = _args();
        a.navMinAnswer = 0.5e8;
        a.navMaxAnswer = 2e8;
        _run(a);
        GyldBondRegistry.InstrumentConfig memory cfg = registry.getInstrumentConfig(address(bond));
        assertTrue(cfg.registered);
        assertEq(cfg.cashToken, address(cash));
        assertEq(cfg.navFeed, address(feed));
        assertEq(cfg.bondScale, 1e18);
        assertEq(cfg.cashScale, 1e6);
        assertEq(cfg.navFeedScale, 1e8);
        assertEq(cfg.maxEntryPremiumBps, 300);
        assertEq(cfg.maxExitDiscountBps, 300);
        assertEq(cfg.navMaxAnswer, 2e8);
        assertFalse(cfg.navSuspended);
        // the same command again changes nothing and does not revert
        _run(a);
        // but a re-run that disagrees on the cash token or the feed is refused
        a.cashToken = address(new MockERC20("Other", "OTH", 6));
        _refused(a, "ALREADY_REGISTERED_WITH_ANOTHER_CASH_TOKEN");
        a = _args();
        a.navFeed = address(new MockAggregator(8));
        _refused(a, "ALREADY_REGISTERED_WITH_ANOTHER_FEED");
    }

    function test_RefusesWhatWouldRegisterBroken() public {
        ConfigureGyldBondRegistry.InstrumentArgs memory a;
        // zero floors register fine on chain and then block every trade: the script refuses them
        a = _args();
        a.maxEntryPremiumBps = 0;
        _refused(a, "ZERO_BPS_IS_UNCONFIGURED_NOT_STRICT");
        a = _args();
        a.maxExitDiscountBps = registry.MAX_TOLERANCE_BPS() + 1;
        _refused(a, "BPS_ABOVE_CEILING");
        a = _args();
        a.cashToken = address(bond);
        _refused(a, "IDENTICAL_TOKENS");
        a = _args();
        a.navFeedKind = 2;
        _refused(a, "INVALID_FEED_KIND");
        a = _args();
        a.navIsUsdDenominated = true;
        _refused(a, "CASH_FEED_REQUIRED_FOR_USD_NAV");
        a = _args();
        a.requiresObservationTime = true; // kind 0 cannot express it
        _refused(a, "OBSERVATION_TIME_NEEDS_GYLD_NATIVE_FEED");
        a = _args();
        a.maxPublicationAge = 0;
        _refused(a, "ZERO_AGE");
        a = _args();
        a.maxObservationAge = registry.MAX_AGE_CEILING() + 1;
        _refused(a, "AGE_ABOVE_CEILING");
        a = _args();
        a.navMinAnswer = 2e8;
        a.navMaxAnswer = 1e8;
        _refused(a, "NAV_BOUNDS_MIN_NOT_BELOW_MAX");
        a = _args();
        a.cashMinAnswer = -1;
        _refused(a, "CASH_BOUNDS_NEGATIVE");
        // the registry would revert inside decimals(): the script names the address first
        a = _args();
        a.navFeed = address(0xFEED);
        _refused(a, "NO_CODE_AT_ADDRESS");
        a = _args();
        a.navFeed = address(registry); // code, but no decimals()
        _refused(a, "DECIMALS_UNREADABLE");
        // wrong fork
        a = _args();
        vm.expectRevert(bytes("CHAIN_ID_MISMATCH: wrong --rpc-url for this chainId"));
        script.runRegisterInstrument(2, uint64(block.chainid) + 1, address(registry), a);
        vm.stopBroadcast();
        assertFalse(registry.isRegistered(address(bond)), "nothing registered by a refused run");
    }

    function test_WithoutTheRole_TheRegistryRefuses() public {
        bytes32 role = registry.INSTRUMENT_MANAGER_ROLE();
        vm.prank(admin);
        registry.revokeRole(role, BROADCASTER);
        vm.expectRevert();
        _run(_args());
    }

    /// @dev The other feed shape: Gyld-native kind with observation time, a USD-denominated NAV with a cash feed and a
    ///      sequencer feed with a grace period all pass through to the stored config; the cash feed scale is derived.
    function test_Registers_GyldNativeUsdInstrument_WithSequencerFeed() public {
        MockAggregator cashFeed = new MockAggregator(8);
        cashFeed.setLatestAnswer(1e8);
        ConfigureGyldBondRegistry.InstrumentArgs memory a = _args();
        a.navFeedKind = registry.FEED_KIND_GYLD_NATIVE();
        a.requiresObservationTime = true;
        a.navIsUsdDenominated = true;
        a.cashFeed = address(cashFeed);
        a.cashMinAnswer = 0.9e8;
        a.cashMaxAnswer = 1.1e8;
        a.sequencerUptimeFeed = address(0x5E0);
        a.gracePeriod = 1 hours;
        _run(a);
        GyldBondRegistry.InstrumentConfig memory cfg = registry.getInstrumentConfig(address(bond));
        assertEq(cfg.navFeedKind, registry.FEED_KIND_GYLD_NATIVE());
        assertTrue(cfg.requiresObservationTime);
        assertTrue(cfg.navIsUsdDenominated);
        assertEq(cfg.cashFeed, address(cashFeed));
        assertEq(cfg.cashFeedScale, 1e8);
        assertEq(cfg.cashMaxAnswer, 1.1e8);
        assertEq(cfg.sequencerUptimeFeed, address(0x5E0));
        assertEq(cfg.gracePeriod, 1 hours);
        // a cash feed without decimals() is caught before signing
        a = _args();
        a.navIsUsdDenominated = true;
        a.cashFeed = address(registry);
        a.bondToken = address(new MockERC20("B2", "B2", 18));
        _refused(a, "DECIMALS_UNREADABLE");
    }

    /// @dev The whole operator sequence through the script: defaults, registration, a later recalibration of the
    ///      floors, and the read-only check on a registered and an unregistered bond.
    function test_FullSequence_DefaultsRegisterRecalibrateCheck() public {
        script.runPolicyDefaults(2, uint64(block.chainid), address(registry));
        assertEq(registry.maxPpsAge(), 1 days, "GYLD_MAX_PPS_AGE");
        script.runPolicyDefaults(2, uint64(block.chainid), address(registry)); // idempotent
        _run(_args());
        script.runTradeFloors(2, uint64(block.chainid), address(registry), address(bond), 150, 250);
        GyldBondRegistry.InstrumentConfig memory cfg = registry.getInstrumentConfig(address(bond));
        assertEq(cfg.maxEntryPremiumBps, 150);
        assertEq(cfg.maxExitDiscountBps, 250);
        vm.expectRevert(bytes("INSTRUMENT_NOT_REGISTERED: register it first"));
        script.runTradeFloors(2, uint64(block.chainid), address(registry), address(cash), 150, 250);
        vm.stopBroadcast();
        vm.expectRevert(bytes("ZERO_BPS_IS_UNCONFIGURED_NOT_STRICT"));
        script.runTradeFloors(2, uint64(block.chainid), address(registry), address(bond), 0, 250);
        vm.stopBroadcast();
        address[] memory bonds = new address[](2);
        bonds[0] = address(bond);
        bonds[1] = address(cash); // NOT REGISTERED branch
        script.runCheck(uint64(block.chainid), address(registry), address(0), bonds);
    }
}
