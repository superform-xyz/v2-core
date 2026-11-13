// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import { stdStorage, StdStorage } from "forge-std/StdStorage.sol";

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

import { GyldInTransitRegistry } from "../../../../src/accounting/oracles/GyldInTransitRegistry.sol";
import { GyldBondRegistry } from "../../../../src/accounting/oracles/GyldBondRegistry.sol";

import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockAggregator } from "../../../mocks/MockAggregator.sol";

/// @title GyldInTransitRegistryTest
/// @notice Roles, timelocked destinations, the account-side record rules (cap, staleness, approved pair) and
///         the reconciler-side settle rules (decrease only, loud loss) of the in-transit registry.
contract GyldInTransitRegistryTest is Test {
    using stdStorage for StdStorage;

    GyldInTransitRegistry internal reg;
    GyldBondRegistry internal bonds;

    MockERC20 internal bond;
    MockERC20 internal cash;
    MockERC20 internal otherCash;
    MockAggregator internal navFeed;

    address internal admin = address(0xA11CE);
    address internal account = address(0xACC0);
    address internal other = address(0x07E7);
    address internal deposit = address(0xDE90);
    address internal holding = address(0x401D);

    uint256 internal constant AGE = 14 days;
    uint256 internal constant CAP = 1000e6;

    function setUp() public {
        vm.warp(1_800_000_000);
        bond = new MockERC20("Gyld Bond", "GBOND", 18);
        cash = new MockERC20("USD Coin", "USDC", 6);
        otherCash = new MockERC20("Other", "OTH", 6);
        navFeed = new MockAggregator(8);
        navFeed.setLatestAnswer(1e8);

        bonds = new GyldBondRegistry(admin);
        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = address(bond);
        cfg.navFeed = address(navFeed);
        cfg.cashToken = address(cash);
        cfg.maxObservationAge = 7 days;
        cfg.maxPublicationAge = 7 days;
        vm.prank(admin);
        bonds.registerInstrument(cfg);

        reg = new GyldInTransitRegistry(admin, address(bonds));
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _configure() internal {
        vm.startPrank(admin);
        reg.setDestinations(deposit, holding);
        reg.setMaxTransitAge(AGE);
        reg.setMaxCashInTransit(address(bond), CAP);
        vm.stopPrank();
    }

    function _record(uint256 amount) internal {
        vm.prank(account);
        reg.recordCashOut(address(bond), address(cash), amount);
    }

    function _expectRole(address who, bytes32 role) internal {
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, who, role));
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR / ROLES
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public view {
        assertEq(address(reg.BOND_REGISTRY()), address(bonds));
        assertTrue(reg.hasRole(reg.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(reg.hasRole(reg.MANAGER_ROLE(), admin));
        assertTrue(reg.hasRole(reg.RECONCILER_ROLE(), admin));
        assertEq(reg.DESTINATION_DELAY(), 2 days);
        assertEq(reg.MAX_TRANSIT_AGE_CEILING(), 365 days);
        assertEq(reg.depositAddress(), address(0));
        assertEq(reg.maxTransitAge(), 0);
    }

    function test_Constructor_RevertZero() public {
        vm.expectRevert(GyldInTransitRegistry.ZERO_ADDRESS.selector);
        new GyldInTransitRegistry(address(0), address(bonds));
        vm.expectRevert(GyldInTransitRegistry.ZERO_ADDRESS.selector);
        new GyldInTransitRegistry(admin, address(0));
    }

    function test_Roles_NonHoldersRevert() public {
        bytes32 manager = reg.MANAGER_ROLE();
        bytes32 reconciler = reg.RECONCILER_ROLE();
        _expectRole(other, manager);
        vm.prank(other);
        reg.setDestinations(deposit, holding);
        _expectRole(other, manager);
        vm.prank(other);
        reg.setMaxTransitAge(AGE);
        _expectRole(other, manager);
        vm.prank(other);
        reg.setMaxCashInTransit(address(bond), CAP);
        _expectRole(other, reconciler);
        vm.prank(other);
        reg.settleMint(account, address(bond), 1, 1, bytes32("x"));
        _expectRole(other, reconciler);
        vm.prank(other);
        reg.settleLoss(account, address(bond), 1, bytes32("x"));
    }

    /*//////////////////////////////////////////////////////////////
                               DESTINATIONS
    //////////////////////////////////////////////////////////////*/

    function test_Destinations_FirstSetImmediate_ChangeTimelocked() public {
        vm.startPrank(admin);
        reg.setDestinations(deposit, holding);
        assertEq(reg.depositAddress(), deposit);
        assertEq(reg.redeemHoldingWallet(), holding);

        vm.expectRevert(GyldInTransitRegistry.DESTINATIONS_ALREADY_SET.selector);
        reg.setDestinations(address(1), address(2));

        vm.expectRevert(GyldInTransitRegistry.CHANGE_NOT_PENDING.selector);
        reg.executeDestinations();

        reg.proposeDestinations(address(1), address(2));
        vm.expectRevert(GyldInTransitRegistry.CHANGE_TIMELOCK_NOT_ELAPSED.selector);
        reg.executeDestinations();
        assertEq(reg.depositAddress(), deposit, "unchanged while pending");

        vm.warp(block.timestamp + reg.DESTINATION_DELAY());
        reg.executeDestinations();
        assertEq(reg.depositAddress(), address(1));
        assertEq(reg.redeemHoldingWallet(), address(2));
        (,, uint64 executeAt) = reg.pendingDestinations();
        assertEq(executeAt, 0, "pending cleared");

        reg.proposeDestinations(address(3), address(4));
        reg.cancelDestinations();
        vm.expectRevert(GyldInTransitRegistry.CHANGE_NOT_PENDING.selector);
        reg.cancelDestinations();
        assertEq(reg.depositAddress(), address(1), "cancel keeps the live value");
        vm.stopPrank();
    }

    function test_Destinations_RevertZero() public {
        vm.startPrank(admin);
        vm.expectRevert(GyldInTransitRegistry.ZERO_ADDRESS.selector);
        reg.setDestinations(address(0), holding);
        vm.expectRevert(GyldInTransitRegistry.ZERO_ADDRESS.selector);
        reg.proposeDestinations(deposit, address(0));
        vm.stopPrank();
    }

    function test_MaxTransitAge_Bounds() public {
        vm.startPrank(admin);
        vm.expectRevert(GyldInTransitRegistry.INVALID_AGE.selector);
        reg.setMaxTransitAge(0);
        vm.expectRevert(GyldInTransitRegistry.INVALID_AGE.selector);
        reg.setMaxTransitAge(366 days);
        reg.setMaxTransitAge(365 days);
        assertEq(reg.maxTransitAge(), 365 days);
        vm.stopPrank();
    }

    function test_MaxCashInTransit_RequiresRegisteredInstrument() public {
        vm.prank(admin);
        vm.expectRevert(GyldInTransitRegistry.INSTRUMENT_NOT_REGISTERED.selector);
        reg.setMaxCashInTransit(address(otherCash), CAP);
    }

    /*//////////////////////////////////////////////////////////////
                              recordCashOut
    //////////////////////////////////////////////////////////////*/

    function test_RecordCashOut_HappyPath_SetsClockOnce() public {
        _configure();
        uint256 t0 = block.timestamp;
        _record(400e6);
        vm.warp(t0 + 1 days);
        _record(100e6);
        GyldInTransitRegistry.Transit memory t = reg.transit(account, address(bond));
        assertEq(t.cashOut, 500e6);
        assertEq(t.oldestOpenAt, t0, "clock set by the FIRST open entry only");
        assertEq(reg.totalCashInTransit(address(bond)), 500e6);
        assertEq(reg.cashOut(account, address(bond)), 500e6);
        assertFalse(reg.isStale(account, address(bond)));
    }

    function test_RecordCashOut_CapBoundary() public {
        _configure();
        _record(CAP);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.CAP_EXCEEDED.selector, CAP + 1, CAP));
        _record(1);
        // cap is on OUTSTANDING, not per tx: settlement frees room
        vm.prank(admin);
        reg.settleMint(account, address(bond), 1, 1, bytes32("m"));
        _record(1);
    }

    function test_RecordCashOut_ZeroCapDisables() public {
        vm.startPrank(admin);
        reg.setDestinations(deposit, holding);
        reg.setMaxTransitAge(AGE);
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.CAP_EXCEEDED.selector, 1, 0));
        _record(1);
    }

    function test_RecordCashOut_Preconditions() public {
        // nothing configured: destination first
        vm.prank(account);
        vm.expectRevert(GyldInTransitRegistry.DESTINATION_NOT_SET.selector);
        reg.recordCashOut(address(bond), address(cash), 1);
        vm.prank(admin);
        reg.setDestinations(deposit, holding);
        vm.prank(account);
        vm.expectRevert(GyldInTransitRegistry.TRANSIT_AGE_NOT_CONFIGURED.selector);
        reg.recordCashOut(address(bond), address(cash), 1);
        vm.prank(admin);
        reg.setMaxTransitAge(AGE);
        // wrong pair
        vm.prank(account);
        vm.expectRevert(GyldInTransitRegistry.PAIR_NOT_APPROVED.selector);
        reg.recordCashOut(address(bond), address(otherCash), 1);
        // zero amount
        vm.prank(account);
        vm.expectRevert(GyldInTransitRegistry.ZERO_AMOUNT.selector);
        reg.recordCashOut(address(bond), address(cash), 0);
    }

    function test_RecordCashOut_StaleRefuses_UntilSettled() public {
        _configure();
        _record(100e6);
        vm.warp(block.timestamp + AGE + 1);
        assertTrue(reg.isStale(account, address(bond)));
        vm.expectRevert(GyldInTransitRegistry.TRANSIT_STALE.selector);
        _record(1);
        assertEq(reg.previewCashOut(account, address(bond), address(cash), 1), 204);
        // other accounts are unaffected
        vm.prank(other);
        reg.recordCashOut(address(bond), address(cash), 1);
        // full settlement resets the clock and re-opens the account
        vm.prank(admin);
        reg.settleMint(account, address(bond), 100e6, 95e18, bytes32("m"));
        assertFalse(reg.isStale(account, address(bond)));
        assertEq(reg.transit(account, address(bond)).oldestOpenAt, 0);
        _record(1);
    }

    function test_PreviewCashOut_MirrorsStrictPath() public {
        assertEq(reg.previewCashOut(account, address(bond), address(cash), 0), 206);
        assertEq(reg.previewCashOut(account, address(bond), address(otherCash), 1), 201);
        assertEq(reg.previewCashOut(account, address(bond), address(cash), 1), 202);
        vm.prank(admin);
        reg.setDestinations(deposit, holding);
        assertEq(reg.previewCashOut(account, address(bond), address(cash), 1), 203);
        vm.prank(admin);
        reg.setMaxTransitAge(AGE);
        assertEq(reg.previewCashOut(account, address(bond), address(cash), 1), 205, "zero cap");
        vm.prank(admin);
        reg.setMaxCashInTransit(address(bond), CAP);
        assertEq(reg.previewCashOut(account, address(bond), address(cash), CAP), 0);
        assertEq(reg.previewCashOut(account, address(bond), address(cash), CAP + 1), 205);
        // checkCashOut is the reverting twin
        reg.checkCashOut(account, address(bond), address(cash), CAP);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.CAP_EXCEEDED.selector, CAP + 1, CAP));
        reg.checkCashOut(account, address(bond), address(cash), CAP + 1);
    }

    /*//////////////////////////////////////////////////////////////
                              recordBondsOut
    //////////////////////////////////////////////////////////////*/

    function test_RecordBondsOut_IgnoresCapAndStaleness_WeightedNav() public {
        vm.startPrank(admin);
        reg.setDestinations(deposit, holding);
        reg.setMaxTransitAge(AGE);
        vm.stopPrank(); // no cap set: bonds out must still work
        vm.prank(account);
        reg.recordBondsOut(address(bond), address(cash), 100e18, 1.0e6);
        vm.warp(block.timestamp + AGE + 1); // stale on the cash side would refuse; bonds must not
        vm.prank(account);
        reg.recordBondsOut(address(bond), address(cash), 300e18, 1.04e6);
        GyldInTransitRegistry.Transit memory t = reg.transit(account, address(bond));
        assertEq(t.bondsOut, 400e18);
        assertEq(t.bondsOutNav, (100e18 * 1.0e6 + 300e18 * 1.04e6) / 400e18, "weighted average");
        // zero NAV at exit is accepted (valued at zero while in transit)
        vm.prank(account);
        reg.recordBondsOut(address(bond), address(cash), 1e18, 0);
    }

    function test_RecordBondsOut_Preconditions() public {
        vm.prank(account);
        vm.expectRevert(GyldInTransitRegistry.DESTINATION_NOT_SET.selector);
        reg.recordBondsOut(address(bond), address(cash), 1, 1);
        assertEq(reg.previewBondsOut(address(bond), address(cash)), 302);
        assertEq(reg.previewBondsOut(address(bond), address(otherCash)), 301);
        vm.prank(admin);
        reg.setDestinations(deposit, holding);
        assertEq(reg.previewBondsOut(address(bond), address(cash)), 303);
        vm.prank(admin);
        reg.setMaxTransitAge(AGE);
        assertEq(reg.previewBondsOut(address(bond), address(cash)), 0);
        vm.prank(account);
        vm.expectRevert(GyldInTransitRegistry.PAIR_NOT_APPROVED.selector);
        reg.recordBondsOut(address(bond), address(otherCash), 1, 1);
        vm.prank(account);
        vm.expectRevert(GyldInTransitRegistry.ZERO_AMOUNT.selector);
        reg.recordBondsOut(address(bond), address(cash), 0, 1);
    }

    /*//////////////////////////////////////////////////////////////
                                 SETTLE
    //////////////////////////////////////////////////////////////*/

    function test_Settle_DecreaseOnly_And_Close() public {
        _configure();
        _record(600e6);
        vm.prank(account);
        reg.recordBondsOut(address(bond), address(cash), 50e18, 1e6);

        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.EXCEEDS_OPEN.selector, 600e6, 600e6 + 1));
        reg.settleMint(account, address(bond), 600e6 + 1, 1, bytes32("m"));
        vm.expectRevert(GyldInTransitRegistry.ZERO_BONDS_RECEIVED.selector);
        reg.settleMint(account, address(bond), 1, 0, bytes32("m"));
        vm.expectRevert(GyldInTransitRegistry.ZERO_AMOUNT.selector);
        reg.settleLoss(account, address(bond), 0, bytes32("l"));

        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.MintSettled(account, address(bond), bytes32("m"), 500e6, 480e18, 100e6);
        reg.settleMint(account, address(bond), 500e6, 480e18, bytes32("m"));
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.TransitLoss(account, address(bond), bytes32("l"), 100e6, 0);
        reg.settleLoss(account, address(bond), 100e6, bytes32("l"));
        assertEq(reg.totalCashInTransit(address(bond)), 0);
        // bonds still open: not closed yet
        assertGt(reg.transit(account, address(bond)).oldestOpenAt, 0);

        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.EXCEEDS_OPEN.selector, 50e18, 51e18));
        reg.settleRedemption(account, address(bond), 51e18, 1, bytes32("r"));
        reg.settleReturn(account, address(bond), 20e18, bytes32("c"));
        reg.settleRedemption(account, address(bond), 30e18, 29e6, bytes32("r"));
        GyldInTransitRegistry.Transit memory t = reg.transit(account, address(bond));
        assertEq(t.bondsOut, 0);
        assertEq(t.oldestOpenAt, 0, "closed");
        assertEq(t.bondsOutNav, 0, "exit NAV forgotten");
        vm.stopPrank();
    }

    /// @dev Settlements can never clear more than was recorded, in any interleaving.
    function testFuzz_SettleNeverExceedsRecord(uint64 a, uint64 b, uint64 s1, uint64 s2) public {
        vm.startPrank(admin);
        reg.setDestinations(deposit, holding);
        reg.setMaxTransitAge(AGE);
        reg.setMaxCashInTransit(address(bond), type(uint256).max);
        vm.stopPrank();
        uint256 ra = bound(uint256(a), 1, 1e18);
        uint256 rb = bound(uint256(b), 1, 1e18);
        _record(ra);
        _record(rb);
        uint256 total = ra + rb;
        uint256 c1 = bound(uint256(s1), 1, total);
        vm.prank(admin);
        reg.settleMint(account, address(bond), c1, 1, bytes32(0));
        uint256 open = total - c1;
        uint256 c2 = bound(uint256(s2), 1, 1e18 * 2);
        vm.prank(admin);
        if (c2 > open) {
            vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.EXCEEDS_OPEN.selector, open, c2));
            reg.settleLoss(account, address(bond), c2, bytes32(0));
        } else {
            reg.settleLoss(account, address(bond), c2, bytes32(0));
            assertEq(reg.cashOut(account, address(bond)), open - c2);
            assertEq(reg.totalCashInTransit(address(bond)), open - c2);
        }
    }

    function test_IsStale_UnconfiguredAgeReadsStale() public {
        vm.startPrank(admin);
        reg.setDestinations(deposit, holding);
        reg.setMaxTransitAge(AGE);
        reg.setMaxCashInTransit(address(bond), CAP);
        vm.stopPrank();
        _record(1);
        // an age cannot be set back to zero through the setter, so emulate the unconfigured state by storage
        stdstore.target(address(reg)).sig("maxTransitAge()").checked_write(uint256(0));
        assertEq(reg.maxTransitAge(), 0);
        assertTrue(reg.isStale(account, address(bond)), "an unbounded entry is never counted");
    }
}
