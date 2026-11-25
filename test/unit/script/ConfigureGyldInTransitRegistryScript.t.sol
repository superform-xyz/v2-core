// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

import { ConfigureGyldInTransitRegistry } from "../../../script/ConfigureGyldInTransitRegistry.s.sol";
import { GyldBondRegistry } from "../../../src/accounting/oracles/GyldBondRegistry.sol";
import { GyldInTransitRegistry } from "../../../src/accounting/oracles/GyldInTransitRegistry.sol";
import { GyldBondYieldSourceOracle } from "../../../src/accounting/oracles/GyldBondYieldSourceOracle.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MockAggregator } from "../../mocks/MockAggregator.sol";

/// @title ConfigureGyldInTransitRegistryScriptTest
/// @notice The MANAGER-side entrypoints of the in-transit configure script, in the runbook's order: destinations
///         (receiver created), transit defaults, the first oracle and a timelocked change, caps, fee, sole principal.
contract ConfigureGyldInTransitRegistryScriptTest is Test {
    ConfigureGyldInTransitRegistry internal script;
    GyldBondRegistry internal bonds;
    GyldInTransitRegistry internal reg;
    GyldBondYieldSourceOracle internal oracle;
    MockERC20 internal bond;
    MockERC20 internal cash;

    address internal admin = address(0xA11CE);
    address internal strategy = address(0xACC0);
    address internal deposit = address(0xDE90);
    address internal holding = address(0x401D);
    address internal constant BROADCASTER = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    uint64 internal chainId;

    function setUp() public {
        vm.warp(1_800_000_000);
        chainId = uint64(block.chainid);
        bond = new MockERC20("Gyld Bond", "GBOND", 18);
        cash = new MockERC20("USD Coin", "USDC", 6);
        MockAggregator feed = new MockAggregator(8);
        feed.setLatestAnswer(1e8);
        bonds = new GyldBondRegistry(admin);
        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = address(bond);
        cfg.navFeed = address(feed);
        cfg.cashToken = address(cash);
        cfg.maxObservationAge = 7 days;
        cfg.maxPublicationAge = 7 days;
        vm.prank(admin);
        bonds.registerInstrument(cfg);
        reg = new GyldInTransitRegistry(admin, address(bonds));
        oracle = new GyldBondYieldSourceOracle(address(0xC0FFEE), address(bonds), address(reg));
        bytes32 role = reg.MANAGER_ROLE();
        vm.prank(admin);
        reg.grantRole(role, BROADCASTER);
        script = new ConfigureGyldInTransitRegistry();
    }

    function test_RunbookOrder_DestinationsDefaultsOracleCapsFeePrincipal() public {
        // 8. destinations: creates the receiver, prints it; a second set for the same strategy is refused on chain
        script.runDestinations(2, chainId, address(reg), strategy, deposit, holding);
        (address dep, address hold) = reg.destinationsOf(strategy);
        assertEq(dep, deposit);
        assertEq(hold, holding);
        address receiver = address(reg.receiverOf(strategy));
        assertTrue(receiver != address(0) && receiver.code.length > 0, "receiver deployed");
        vm.expectRevert(GyldInTransitRegistry.DESTINATIONS_ALREADY_SET.selector);
        script.runDestinations(2, chainId, address(reg), strategy, deposit, holding);
        vm.stopBroadcast();
        // another strategy cannot take the same deposit address
        vm.expectRevert(
            abi.encodeWithSelector(GyldInTransitRegistry.DEPOSIT_ADDRESS_IN_USE.selector, deposit, strategy)
        );
        script.runDestinations(2, chainId, address(reg), address(0xB), deposit, holding);
        vm.stopBroadcast();
        // transit defaults, idempotent
        script.runTransitDefaults(2, chainId, address(reg));
        assertEq(reg.maxTransitAge(), 14 days);
        script.runTransitDefaults(2, chainId, address(reg));
        // the first oracle is immediate, a second one is proposed and applied after the delay
        script.runOracle(2, chainId, address(reg), address(oracle));
        assertEq(address(reg.valuationOracle()), address(oracle));
        script.runOracle(2, chainId, address(reg), address(oracle)); // already set, skipping
        GyldBondYieldSourceOracle oracle2 =
            new GyldBondYieldSourceOracle(address(0xC0FFEE), address(bonds), address(reg));
        script.runOracle(2, chainId, address(reg), address(oracle2));
        (address pending, uint64 at) = reg.pendingValuationOracle();
        assertEq(pending, address(oracle2));
        assertEq(address(reg.valuationOracle()), address(oracle), "not applied yet");
        vm.expectRevert(bytes("ORACLE_TIMELOCK_NOT_ELAPSED"));
        script.runOracleExecute(2, chainId, address(reg));
        vm.stopBroadcast();
        vm.warp(at);
        script.runOracleExecute(2, chainId, address(reg));
        assertEq(address(reg.valuationOracle()), address(oracle2));
        vm.expectRevert(bytes("NO_PENDING_ORACLE"));
        script.runOracleExecute(2, chainId, address(reg));
        vm.stopBroadcast();
        // 10. caps and fee, as GOVERNOR in production (the same MANAGER role here)
        script.runCap(2, chainId, address(reg), address(bond), 1000e6, 3000e6);
        assertEq(reg.maxCashInTransit(address(bond)), 1000e6);
        assertEq(reg.maxTotalCashInTransit(address(bond)), 3000e6);
        vm.expectRevert(bytes("TOTAL_CAP_BELOW_PER_STRATEGY"));
        script.runCap(2, chainId, address(reg), address(bond), 1000e6, 999e6);
        vm.stopBroadcast();
        script.runFee(2, chainId, address(reg), address(bond), 50);
        assertEq(reg.transitFeeBps(address(bond)), 50);
        // hub model: one funder, then cleared
        script.runSolePrincipal(2, chainId, address(reg), strategy);
        assertEq(reg.solePrincipal(), strategy);
        script.runSolePrincipal(2, chainId, address(reg), address(0));
        assertEq(reg.solePrincipal(), address(0));
        // and the strategy can now deposit: everything the hooks need is in place
        assertEq(reg.previewCashOut(strategy, address(bond), address(cash), 1e6), 0);
        address[] memory strategies = new address[](1);
        strategies[0] = strategy;
        address[] memory bondTokens = new address[](1);
        bondTokens[0] = address(bond);
        script.runCheck(chainId, address(reg), strategies, bondTokens);
    }

    function test_Refusals_BeforeAnythingIsSigned() public {
        vm.expectRevert(bytes("ZERO_STRATEGY"));
        script.runDestinations(2, chainId, address(reg), address(0), deposit, holding);
        vm.stopBroadcast();
        vm.expectRevert(bytes("ZERO_DESTINATION"));
        script.runDestinations(2, chainId, address(reg), strategy, deposit, address(0));
        vm.stopBroadcast();
        vm.expectRevert(bytes("CHAIN_ID_MISMATCH"));
        script.runTransitDefaults(2, chainId + 1, address(reg));
        vm.stopBroadcast();
        vm.expectRevert(bytes("REGISTRY_NOT_DEPLOYED"));
        script.runTransitDefaults(2, chainId, address(0xDEAD));
        vm.stopBroadcast();
        vm.expectRevert(bytes("ORACLE_NOT_DEPLOYED"));
        script.runOracle(2, chainId, address(reg), address(0xDEAD));
        vm.stopBroadcast();
        // an oracle pinned to ANOTHER registry is refused by the registry itself
        GyldInTransitRegistry otherReg = new GyldInTransitRegistry(admin, address(bonds));
        GyldBondYieldSourceOracle foreign =
            new GyldBondYieldSourceOracle(address(0xC0FFEE), address(bonds), address(otherReg));
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.ORACLE_MISMATCH.selector, address(foreign)));
        script.runOracle(2, chainId, address(reg), address(foreign));
        vm.stopBroadcast();
        // without the role the registry refuses every write
        bytes32 role = reg.MANAGER_ROLE();
        vm.prank(admin);
        reg.revokeRole(role, BROADCASTER);
        vm.expectRevert();
        script.runTransitDefaults(2, chainId, address(reg));
        vm.stopBroadcast();
        assertEq(reg.maxTransitAge(), 0, "nothing applied");
    }
}
