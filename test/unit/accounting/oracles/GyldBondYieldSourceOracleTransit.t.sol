// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

import { GyldInTransitRegistry } from "../../../../src/accounting/oracles/GyldInTransitRegistry.sol";
import { GyldBondRegistry } from "../../../../src/accounting/oracles/GyldBondRegistry.sol";
import { GyldBondYieldSourceOracle } from "../../../../src/accounting/oracles/GyldBondYieldSourceOracle.sol";

import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockAggregator } from "../../../mocks/MockAggregator.sol";

/// @title GyldBondYieldSourceOracleTransitTest
/// @notice The in-transit half of the oracle (SUP-21848): what the registry entries add to each read, the
///         `min(exit NAV, live NAV)` clamp, the stale-to-zero rule, and the invariants the existing reads keep.
///         The pre-existing suite runs with `IN_TRANSIT == address(0)` and is unchanged.
contract GyldBondYieldSourceOracleTransitTest is Test {
    GyldBondRegistry internal registry;
    GyldInTransitRegistry internal transit;
    GyldBondYieldSourceOracle internal oracle;

    MockERC20 internal bond; // 18 decimals
    MockERC20 internal cash; // 6 decimals
    MockAggregator internal navFeed; // 8 decimals, Chainlink-shaped

    address internal admin = address(0xA11CE);
    address internal holder = address(0xB0DB);
    address internal deposit = address(0xDE90);
    address internal holding = address(0x401D);

    int256 internal constant NAV_ANSWER = 1.05e8;
    uint256 internal constant NAV_IN_CASH = 1.05e6;
    uint256 internal constant AGE = 14 days;

    function setUp() public {
        vm.warp(1_800_000_000);
        bond = new MockERC20("Gyld Bond", "GBOND", 18);
        cash = new MockERC20("USD Coin", "USDC", 6);
        navFeed = new MockAggregator(8);
        navFeed.setLatestAnswer(NAV_ANSWER);

        registry = new GyldBondRegistry(admin);
        transit = new GyldInTransitRegistry(admin, address(registry));
        oracle = new GyldBondYieldSourceOracle(address(0xC0FFEE), address(registry), address(transit));

        _register(address(bond), 18);
        vm.startPrank(admin);
        transit.setDestinations(deposit, holding);
        transit.setMaxTransitAge(AGE);
        transit.setMaxCashInTransit(address(bond), type(uint256).max);
        vm.stopPrank();
    }

    function _register(address bondToken, uint8) internal {
        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = bondToken;
        cfg.navFeed = address(navFeed);
        cfg.cashToken = address(cash);
        cfg.maxObservationAge = 7 days;
        cfg.maxPublicationAge = 7 days;
        vm.prank(admin);
        registry.registerInstrument(cfg);
    }

    function _cashOut(uint256 amount) internal {
        vm.prank(holder);
        transit.recordCashOut(address(bond), address(cash), amount);
    }

    function _bondsOut(uint256 shares, uint256 nav) internal {
        vm.prank(holder);
        transit.recordBondsOut(address(bond), address(cash), shares, nav);
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_PinsRegistry_And_RejectsMismatch() public {
        assertEq(address(oracle.IN_TRANSIT()), address(transit));
        GyldBondRegistry otherBonds = new GyldBondRegistry(admin);
        GyldInTransitRegistry foreign = new GyldInTransitRegistry(admin, address(otherBonds));
        vm.expectRevert(GyldBondYieldSourceOracle.REGISTRY_MISMATCH.selector);
        new GyldBondYieldSourceOracle(address(0xC0FFEE), address(registry), address(foreign));
        // zero = feature off
        GyldBondYieldSourceOracle off = new GyldBondYieldSourceOracle(address(0xC0FFEE), address(registry), address(0));
        assertEq(address(off.IN_TRANSIT()), address(0));
        assertFalse(off.hasStaleTransit(address(bond), holder));
    }

    /*//////////////////////////////////////////////////////////////
                          getTVLByOwnerOfShares
    //////////////////////////////////////////////////////////////*/

    function test_TVL_HeldPlusCashAtFace_PlusBondsClamped() public {
        bond.mint(holder, 100e18);
        _cashOut(250e6);
        _bondsOut(10e18, 1.0e6); // exited below the live 1.05
        // 100 bonds * 1.05 + 250 cash + 10 bonds * min(1.00, 1.05)
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), 105e6 + 250e6 + 10e6);

        // exit NAV above live: clamp to live
        _bondsOut(10e18, 1.3e6); // weighted exit NAV becomes 1.15 > live 1.05
        assertEq(transit.transit(holder, address(bond)).bondsOutNav, 1.15e6);
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), 105e6 + 250e6 + 20 * NAV_IN_CASH);
    }

    function test_TVL_ZeroShortCircuit_StillHolds_WithNoTransit() public {
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);
        // no balance, no transit: zero WITHOUT touching the suspended feed
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), 0);
    }

    function test_TVL_TransitWithSuspendedNav_RevertsLikeAnyValueRead() public {
        _cashOut(1e6);
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);
        vm.expectRevert(GyldBondYieldSourceOracle.NAV_SUSPENDED.selector);
        oracle.getTVLByOwnerOfShares(address(bond), holder);
        // identity read still answers: bonds-in-transit counted, cash contributes zero shares
        _unsuspendAndRecord();
    }

    function _unsuspendAndRecord() internal {
        vm.prank(admin);
        registry.setNavSuspended(address(bond), false);
        _bondsOut(3e18, 1e6);
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);
        assertEq(oracle.getBalanceOfOwner(address(bond), holder), 3e18, "cash shares are zero while NAV is unusable");
    }

    function test_TVL_StaleTransit_ValuedAtZero_AndFlagged() public {
        bond.mint(holder, 1e18);
        _cashOut(100e6);
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), NAV_IN_CASH + 100e6);
        assertFalse(oracle.hasStaleTransit(address(bond), holder));
        vm.warp(block.timestamp + AGE + 1);
        navFeed.setLatestAnswer(NAV_ANSWER); // keep the feed itself fresh
        assertTrue(oracle.hasStaleTransit(address(bond), holder));
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), NAV_IN_CASH, "stale transit drops out");
        assertEq(oracle.getBalanceOfOwner(address(bond), holder), 1e18);
    }

    function test_TVL_6DecimalBond() public {
        MockERC20 bond6 = new MockERC20("Gyld Bond 6", "GB6", 6);
        _register(address(bond6), 6);
        vm.prank(admin);
        transit.setMaxCashInTransit(address(bond6), type(uint256).max);
        bond6.mint(holder, 100e6);
        vm.prank(holder);
        transit.recordBondsOut(address(bond6), address(cash), 10e6, 1.0e6);
        vm.prank(holder);
        transit.recordCashOut(address(bond6), address(cash), 5e6);
        // 100 * 1.05 + 10 * 1.00 + 5
        assertEq(oracle.getTVLByOwnerOfShares(address(bond6), holder), 105e6 + 10e6 + 5e6);
        // balance: 100 + 10 + 5 / 1.05 = 4.761904 bonds (floor, 6 dec)
        assertEq(oracle.getBalanceOfOwner(address(bond6), holder), 100e6 + 10e6 + uint256(5e6) * 1e6 / NAV_IN_CASH);
    }

    /*//////////////////////////////////////////////////////////////
                            getBalanceOfOwner
    //////////////////////////////////////////////////////////////*/

    function test_BalanceOfOwner_AddsTransit_NeverReverts() public {
        bond.mint(holder, 2e18);
        _cashOut(2.1e6); // 2 bonds at 1.05
        _bondsOut(1e18, 1e6);
        assertEq(oracle.getBalanceOfOwner(address(bond), holder), 2e18 + 1e18 + 2e18);
        // unregistered token: plain balance, no registry lookup
        MockERC20 stray = new MockERC20("S", "S", 18);
        stray.mint(holder, 7);
        assertEq(oracle.getBalanceOfOwner(address(stray), holder), 7);
    }

    /*//////////////////////////////////////////////////////////////
                                 getTVL
    //////////////////////////////////////////////////////////////*/

    function test_GetTVL_AddsCashNotBonds() public {
        bond.mint(holder, 100e18);
        bond.mint(holding, 10e18); // bonds "in the holding wallet" are still in totalSupply
        _cashOut(50e6);
        _bondsOut(10e18, 1e6);
        assertEq(oracle.getTVL(address(bond)), 110 * NAV_IN_CASH + 50e6, "supply at NAV plus cash in transit only");
    }

    /*//////////////////////////////////////////////////////////////
                              PRICING UNCHANGED
    //////////////////////////////////////////////////////////////*/

    function test_PerSharePricing_IgnoresTransit() public {
        _cashOut(1000e6);
        _bondsOut(1e18, 9e6);
        assertEq(oracle.getPricePerShare(address(bond)), NAV_IN_CASH);
        assertEq(oracle.getAssetOutput(address(bond), address(cash), 1e18), NAV_IN_CASH);
        assertEq(oracle.getShareOutput(address(bond), address(cash), NAV_IN_CASH), 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                                  FUZZ
    //////////////////////////////////////////////////////////////*/

    /// @dev TVL is monotone in both transit components and bounded by valuing in-transit bonds at the live NAV.
    function testFuzz_TVL_MonotoneAndBounded(uint96 held, uint64 cashIn, uint96 bondsIn, uint64 exitNavRaw) public {
        uint256 h = bound(uint256(held), 0, 1e24);
        uint256 c = bound(uint256(cashIn), 0, 1e12);
        uint256 b = bound(uint256(bondsIn), 0, 1e24);
        uint256 exitNav = bound(uint256(exitNavRaw), 0, 3e6);
        if (h != 0) bond.mint(holder, h);
        uint256 base = oracle.getTVLByOwnerOfShares(address(bond), holder);
        if (c != 0) _cashOut(c);
        uint256 withCash = oracle.getTVLByOwnerOfShares(address(bond), holder);
        assertEq(withCash, base + c, "cash at face");
        if (b != 0) _bondsOut(b, exitNav);
        uint256 full = oracle.getTVLByOwnerOfShares(address(bond), holder);
        assertGe(full, withCash, "bonds never subtract");
        assertLe(full, withCash + b * NAV_IN_CASH / 1e18 + 1, "never above the live mark");
        if (exitNav >= NAV_IN_CASH && b != 0) {
            assertEq(full, withCash + b * NAV_IN_CASH / 1e18, "clamped to live NAV");
        }
    }
}
