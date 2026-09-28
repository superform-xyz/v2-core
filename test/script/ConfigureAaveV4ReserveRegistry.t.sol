// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { ConfigureAaveV4ReserveRegistry } from "../../script/ConfigureAaveV4ReserveRegistry.s.sol";
import { AaveV4ReserveRegistry } from "../../src/accounting/oracles/AaveV4ReserveRegistry.sol";

/// @dev Exposes the seeding primitive so it can run against a fresh registry on a live fork
///      without a broadcast or the env/role preamble.
contract SeedHarness is ConfigureAaveV4ReserveRegistry {
    function seed(AaveV4ReserveRegistry registry, address spoke) external returns (SeedResult memory) {
        return _seedSpoke(registry, spoke);
    }

    function defaultSpokes(uint64 chainId) external pure returns (address[] memory) {
        return _defaultSpokes(chainId);
    }

    function mag7Spoke() external pure returns (address) {
        return BASE_MAG7_SPOKE;
    }
}

/// @title ConfigureAaveV4ReserveRegistryTest
/// @notice The seeding script must register exactly the reserves Aave lists on the spoke, bind the same
///         underlying/decimals the registry reads itself, and be a no-op on a second run.
contract ConfigureAaveV4ReserveRegistryTest is Test {
    uint256 internal constant BASE_FORK_BLOCK = 51_778_000;
    address internal constant AAPLc = 0xb200000000000000000000C2e324d24d7eEcd1fb;
    address internal constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    uint256 internal constant MAG7_LISTED_RESERVES = 8; // 7 equities + USDC at the pinned block

    SeedHarness internal harness;
    AaveV4ReserveRegistry internal registry;
    address internal spoke;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), BASE_FORK_BLOCK);
        harness = new SeedHarness();
        spoke = harness.mag7Spoke();
        // Admin = harness so it holds MARKET_MANAGER_ROLE, exactly like DEPLOYER after a real deploy.
        registry = new AaveV4ReserveRegistry(address(harness));
    }

    function test_Seed_RegistersEveryListedReserveOnce() public {
        ConfigureAaveV4ReserveRegistry.SeedResult memory first = harness.seed(registry, spoke);
        assertEq(first.listed, MAG7_LISTED_RESERVES, "listed");
        assertEq(first.registered, MAG7_LISTED_RESERVES, "registered on first run");
        assertEq(first.skipped, 0);

        for (uint256 id; id < MAG7_LISTED_RESERVES; ++id) {
            address key = registry.computeReserveKey(spoke, id);
            assertTrue(registry.isRegistered(key), "every id registered");
            (address spoke_, uint256 id_,,) = registry.getReserveInfo(key);
            assertEq(spoke_, spoke);
            assertEq(id_, id);
        }
        (,, address u0, uint8 d0) = registry.getReserveInfo(registry.computeReserveKey(spoke, 0));
        assertEq(u0, AAPLc, "reserve 0 is AAPLc");
        assertEq(d0, 8);
        (,, address u7, uint8 d7) = registry.getReserveInfo(registry.computeReserveKey(spoke, 7));
        assertEq(u7, USDC_BASE, "reserve 7 is USDC");
        assertEq(d7, 6);
        assertFalse(registry.isRegistered(registry.computeReserveKey(spoke, MAG7_LISTED_RESERVES)), "no phantom id");
    }

    function test_Seed_SecondRunIsANoOp() public {
        harness.seed(registry, spoke);
        ConfigureAaveV4ReserveRegistry.SeedResult memory second = harness.seed(registry, spoke);
        assertEq(second.listed, MAG7_LISTED_RESERVES);
        assertEq(second.registered, 0, "nothing new");
        assertEq(second.skipped, MAG7_LISTED_RESERVES);
    }

    function test_Seed_FillsOnlyTheGapAfterAPartialRegistration() public {
        // Operator registered two reserves by hand earlier: the script must add the other six only.
        vm.startPrank(address(harness));
        registry.registerReserve(spoke, 3);
        registry.registerReserve(spoke, 7);
        vm.stopPrank();

        ConfigureAaveV4ReserveRegistry.SeedResult memory r = harness.seed(registry, spoke);
        assertEq(r.registered, MAG7_LISTED_RESERVES - 2);
        assertEq(r.skipped, 2);
    }

    function test_Seed_RevertsForASpokeWithoutCode() public {
        vm.expectRevert(bytes("SPOKE_HAS_NO_CODE"));
        harness.seed(registry, address(0xdead));
    }

    function test_DefaultSpokes_BaseAndEthereumOnly() public view {
        assertEq(harness.defaultSpokes(8453)[0], spoke);
        assertEq(harness.defaultSpokes(1).length, 1);
        assertEq(harness.defaultSpokes(42_161).length, 0, "no default elsewhere: runSpoke is explicit");
    }

    function test_RunCheck_DoesNotRevertBeforeOrAfterSeeding() public {
        harness.runCheck(8453, address(registry), spoke);
        harness.seed(registry, spoke);
        harness.runCheck(8453, address(registry), spoke);
    }
}
