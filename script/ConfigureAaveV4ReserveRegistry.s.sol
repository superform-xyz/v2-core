// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { DeployV2Base } from "./DeployV2Base.s.sol";
import { AaveV4ReserveRegistryV2 } from "../src/accounting/oracles/AaveV4ReserveRegistryV2.sol";
import { AaveV4ReserveRegistry } from "../src/accounting/oracles/AaveV4ReserveRegistry.sol";
import { IAaveV4Spoke } from "../src/vendor/aave-v4/IAaveV4Spoke.sol";
import { console2 } from "forge-std/console2.sol";

/// @title ConfigureAaveV4ReserveRegistry
/// @notice Seeds a deployed AaveV4ReserveRegistryV2 with every listed reserve of an Aave V4 spoke.
/// @dev Runs AFTER DeployV2Core has deployed the registry and BEFORE TransferAaveV4ReserveRegistryRoles
///      hands MARKET_MANAGER_ROLE to governance: registerReserve is role-gated and the broadcaster must
///      still hold the role (DEPLOYER does, from the constructor). Once roles are transferred, new
///      reserves are registered through governance, not this script.
///
///      Reserve ids are enumerated from the spoke itself (0, 1, 2, ... until getReserve reverts or
///      returns an empty underlying), so the script needs no per-reserve table and cannot drift from
///      what Aave has listed. The registry re-validates every id on-chain at registration.
///
///      Idempotent: reserves whose key is already registered are skipped, so re-running after Aave
///      lists a new reserve registers only the new one.
///
///      Usage (staging = 2, prod = 0):
///        forge script script/ConfigureAaveV4ReserveRegistry.s.sol:ConfigureAaveV4ReserveRegistry \
///          --sig 'run(uint256,uint64,address)' 2 8453 <registry> --rpc-url $BASE_RPC_URL --account v2 --broadcast
///        # explicit spoke (chains without a default, or a second spoke on the same chain):
///          --sig 'runSpoke(uint256,uint64,address,address)' 2 1 <registry> <spoke> ...
///        # read-only status, no broadcast:
///          --sig 'runCheck(uint64,address,address)' 8453 <registry> <spoke> --rpc-url ...
contract ConfigureAaveV4ReserveRegistry is DeployV2Base {
    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev aave-address-book AaveV4EthereumSpokes.MAIN_SPOKE
    address internal constant ETHEREUM_MAIN_SPOKE = 0x94e7A5dCbE816e498b89aB752661904E2F56c485;
    /// @dev aave-address-book AaveV4BaseSpokes.MAG7_SPOKE (equities hub: AAPLc..TSLAc + USDC)
    address internal constant BASE_MAG7_SPOKE = 0x17905Db0e4A3514467539956c084180616AE7B8D;

    /// @dev Upper bound on reserve ids probed per spoke; a spoke listing more than this needs the
    ///      bound raised, which is a deliberate code change rather than an unbounded on-chain loop.
    uint256 internal constant MAX_RESERVES_PER_SPOKE = 64;

    uint64 internal constant ETHEREUM_CHAIN_ID = 1;

    struct SeedResult {
        uint256 listed;
        uint256 registered;
        uint256 skipped;
        /// @dev Reserves that were half-registered on entry and had their missing leg restored via
        ///      `repairLeg`. Should always be 0 on a healthy registry; non-zero means someone
        ///      deregistered a single leg.
        uint256 repaired;
    }

    /*//////////////////////////////////////////////////////////////
                            MAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Register every reserve of the chain's default spoke(s).
    /// @param env Environment (0 = prod, 2 = staging)
    /// @param chainId Chain ID (selects the default spokes)
    /// @param registryAddr Deployed AaveV4ReserveRegistryV2
    function run(uint256 env, uint64 chainId, address registryAddr) external broadcast(env) {
        address[] memory spokes = _defaultSpokes(chainId);
        require(spokes.length > 0, "NO_DEFAULT_SPOKE: use runSpoke(env,chainId,registry,spoke)");
        _prepare(env, chainId, registryAddr);
        for (uint256 i; i < spokes.length; ++i) {
            _seedSpoke(AaveV4ReserveRegistryV2(registryAddr), spokes[i]);
        }
        console2.log("====== Registry Seeding Complete ======");
    }

    /// @notice Register every reserve of one explicit spoke.
    /// @param env Environment (0 = prod, 2 = staging)
    /// @param chainId Chain ID (logged and checked against the fork)
    /// @param registryAddr Deployed AaveV4ReserveRegistryV2
    /// @param spoke Aave V4 spoke to enumerate; trusted by the operator (see registry NatSpec)
    function runSpoke(uint256 env, uint64 chainId, address registryAddr, address spoke) external broadcast(env) {
        _prepare(env, chainId, registryAddr);
        _seedSpoke(AaveV4ReserveRegistryV2(registryAddr), spoke);
        console2.log("====== Registry Seeding Complete ======");
    }

    /// @notice Print each listed reserve of a spoke and whether it is registered. No broadcast.
    function runCheck(uint64 chainId, address registryAddr, address spoke) external view {
        console2.log("====== AaveV4ReserveRegistryV2 Reserve Check ======");
        console2.log("Chain ID:", uint256(chainId));
        console2.log("Registry:", registryAddr);
        console2.log("Spoke:", spoke);
        if (registryAddr.code.length == 0) {
            console2.log("Status: REGISTRY NOT DEPLOYED");
            return;
        }
        AaveV4ReserveRegistryV2 registry = AaveV4ReserveRegistryV2(registryAddr);
        uint256 missing;
        uint256 half;
        for (uint256 id; id < MAX_RESERVES_PER_SPOKE; ++id) {
            (bool listed, address underlying, uint8 decimals) = _probe(spoke, id);
            if (!listed) break;
            // BOTH legs must be checked: registration is per reserve but deregistration is per key, so a
            // supply-only check would report a half-registered reserve as healthy and the seeder would
            // skip past it (registerReserve reverts RESERVE_ALREADY_REGISTERED on the surviving leg).
            bool supplyOk = registry.isRegistered(registry.computeReserveKey(spoke, id));
            bool debtOk = registry.isRegistered(registry.computeDebtKey(spoke, id));
            if (!supplyOk || !debtOk) ++missing;
            if (supplyOk != debtOk) ++half;
            console2.log(
                string.concat(
                    "  id ",
                    vm.toString(id),
                    " ",
                    vm.toString(underlying),
                    " dec=",
                    vm.toString(uint256(decimals)),
                    supplyOk && debtOk
                        ? "  [REGISTERED both legs]"
                        : (supplyOk
                                ? "  [HALF: debt leg MISSING]"
                                : (debtOk ? "  [HALF: supply leg MISSING]" : "  [MISSING]"))
                )
            );
        }
        if (half != 0) {
            console2.log("Status: HALF-REGISTERED RESERVES PRESENT - run seed to repair the missing legs");
        } else {
            console2.log(missing == 0 ? "Status: ALL LISTED RESERVES REGISTERED" : "Status: RESERVES NEED REGISTRATION");
        }
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _defaultSpokes(uint64 chainId) internal pure returns (address[] memory spokes) {
        if (chainId == ETHEREUM_CHAIN_ID) {
            spokes = new address[](1);
            spokes[0] = ETHEREUM_MAIN_SPOKE;
        } else if (chainId == BASE_CHAIN_ID) {
            spokes = new address[](1);
            spokes[0] = BASE_MAG7_SPOKE;
        }
    }

    function _prepare(uint256 env, uint64 chainId, address registryAddr) internal {
        require(env == 0 || env == 2, "INVALID_ENV: only prod (0) or staging (2) supported");
        require(block.chainid == chainId, "CHAIN_MISMATCH: --rpc-url does not match chainId");
        _setBaseConfiguration(env, "");
        require(registryAddr.code.length > 0, "REGISTRY_NOT_DEPLOYED");
        AaveV4ReserveRegistryV2 registry = AaveV4ReserveRegistryV2(registryAddr);
        require(
            registry.hasRole(registry.MARKET_MANAGER_ROLE(), DEPLOYER),
            "DEPLOYER lacks MARKET_MANAGER_ROLE: roles already transferred, register via governance"
        );
        console2.log("====== Seed AaveV4ReserveRegistryV2 ======");
        console2.log("Registry:", registryAddr);
        console2.log("Chain ID:", uint256(chainId));
        console2.log("Environment:", env);
        console2.log("Manager (DEPLOYER):", DEPLOYER);
    }

    /// @dev Enumerates and registers every listed reserve of `spoke`, skipping ones already registered.
    function _seedSpoke(AaveV4ReserveRegistryV2 registry, address spoke) internal returns (SeedResult memory r) {
        require(spoke.code.length > 0, "SPOKE_HAS_NO_CODE");
        console2.log("");
        console2.log("Spoke:", spoke);
        for (uint256 id; id < MAX_RESERVES_PER_SPOKE; ++id) {
            (bool listed, address underlying, uint8 decimals) = _probe(spoke, id);
            if (!listed) break;
            ++r.listed;
            address key = registry.computeReserveKey(spoke, id);
            address debtKey = registry.computeDebtKey(spoke, id);
            bool supplyOk = registry.isRegistered(key);
            bool debtOk = registry.isRegistered(debtKey);
            if (supplyOk && debtOk) {
                ++r.skipped;
                console2.log(string.concat("  [=] id ", vm.toString(id), " already registered as ", vm.toString(key)));
                continue;
            }
            if (supplyOk || debtOk) {
                // Half-registered: `registerReserve` would revert on the surviving leg, so restore the
                // missing one. `repairLeg` re-derives the key and re-reads the binding from the Spoke, so
                // it can only ever restore the leg that is actually absent.
                AaveV4ReserveRegistryV2.Side missingSide =
                    supplyOk ? AaveV4ReserveRegistryV2.Side.DEBT : AaveV4ReserveRegistryV2.Side.SUPPLY;
                address restored = registry.repairLeg(spoke, id, missingSide);
                require(restored == (supplyOk ? debtKey : key), "REPAIR_KEY_MISMATCH");
                ++r.repaired;
                console2.log(
                    string.concat(
                        "  [~] id ",
                        vm.toString(id),
                        " was half-registered; restored ",
                        supplyOk ? "DEBT" : "SUPPLY",
                        " leg ",
                        vm.toString(restored)
                    )
                );
                continue;
            }
            // One call registers BOTH legs: the supply key (== `key`, the legacy derivation) and the
            // debt key. Assert both so a registry whose derivation drifted can never pass silently.
            registry.registerReserve(spoke, id);
            _assertBothLegsBound(registry, spoke, id, underlying, decimals);
            ++r.registered;
            console2.log(
                string.concat(
                    "  [+] id ",
                    vm.toString(id),
                    " ",
                    vm.toString(underlying),
                    " dec=",
                    vm.toString(uint256(decimals)),
                    " -> supply ",
                    vm.toString(key),
                    " debt ",
                    vm.toString(debtKey)
                )
            );
        }
        require(r.listed > 0, "SPOKE_LISTS_NO_RESERVES");
        require(r.listed < MAX_RESERVES_PER_SPOKE, "MAX_RESERVES_PER_SPOKE reached: raise the bound");
        console2.log("  listed:", r.listed);
        console2.log("  registered now:", r.registered);
        console2.log("  already registered:", r.skipped);
        console2.log("  half-registered legs repaired:", r.repaired);
    }

    /// @notice MIGRATION PARITY — every reserve the V1 registry holds must exist in V2, both legs
    /// @dev The whole point of the V2 seed is to carry the live V1 set across, which on Base is the MAG7
    ///      tokenized-stocks market (7 equity reserves plus USDC). `_seedSpoke` enumerates reserves from the
    ///      SPOKE rather than from V1, so in principle it could register a different set than V1 holds — if
    ///      a reserve were delisted on the spoke after V1 was seeded, the seeder would skip it and the
    ///      migration would silently lose that key. This asserts the migration is a superset: for every id
    ///      V1 has registered, V2 must have BOTH legs. Reverts loudly rather than leaving a gap.
    ///      V1's `isRegistered` / `computeReserveKey` are ABI-identical to V2's, so only the supply key is
    ///      needed to detect V1 membership (V1 has no debt leg at all).
    /// @param legacyRegistry The deployed V1 registry to compare against
    /// @param registry The V2 registry just seeded
    /// @param spoke The spoke whose reserves were seeded
    /// @return carried Number of V1 reserves confirmed present in V2
    function assertMigrationParity(
        AaveV4ReserveRegistry legacyRegistry,
        AaveV4ReserveRegistryV2 registry,
        address spoke
    )
        public
        view
        returns (uint256 carried)
    {
        for (uint256 id; id < MAX_RESERVES_PER_SPOKE; ++id) {
            address legacyKey = legacyRegistry.computeReserveKey(spoke, id);
            if (!legacyRegistry.isRegistered(legacyKey)) continue;

            // V1's supply key derivation is the unchanged legacy one, so it IS V2's supply key
            require(registry.isRegistered(registry.computeReserveKey(spoke, id)), "MIGRATION_SUPPLY_LEG_MISSING");
            require(registry.isRegistered(registry.computeDebtKey(spoke, id)), "MIGRATION_DEBT_LEG_MISSING");
            ++carried;
        }
        require(carried > 0, "MIGRATION_PARITY_FOUND_NOTHING_IN_V1");
    }

    /// @dev Post-registration assertion, extracted to keep `_seedSpoke`'s frame within stack limits
    ///      (the repo builds without via_ir). Verifies both derived keys exist, carry the correct side,
    ///      and share the binding this script independently probed from the Spoke.
    function _assertBothLegsBound(
        AaveV4ReserveRegistryV2 registry,
        address spoke,
        uint256 id,
        address underlying,
        uint8 decimals
    )
        internal
        view
    {
        address supplyKey = registry.computeReserveKey(spoke, id);
        address debtKey = registry.computeDebtKey(spoke, id);

        (,, address u1, uint8 d1, AaveV4ReserveRegistryV2.Side s1) = registry.getReserveInfo(supplyKey);
        require(u1 == underlying && d1 == decimals, "RESERVE_BINDING_MISMATCH");
        require(s1 == AaveV4ReserveRegistryV2.Side.SUPPLY, "SUPPLY_SIDE_MISMATCH");

        (,, address u2, uint8 d2, AaveV4ReserveRegistryV2.Side s2) = registry.getReserveInfo(debtKey);
        require(u2 == underlying && d2 == decimals, "DEBT_BINDING_MISMATCH");
        require(s2 == AaveV4ReserveRegistryV2.Side.DEBT, "DEBT_SIDE_MISMATCH");
    }

    /// @dev A reserve id is "listed" when getReserve succeeds with a non-zero underlying. Unlisted ids
    ///      revert on the live spokes; the empty-struct case is guarded as well.
    function _probe(address spoke, uint256 id) internal view returns (bool listed, address underlying, uint8 decimals) {
        try IAaveV4Spoke(spoke).getReserve(id) returns (IAaveV4Spoke.Reserve memory reserve) {
            if (reserve.underlying == address(0)) return (false, address(0), 0);
            return (true, reserve.underlying, reserve.decimals);
        } catch {
            return (false, address(0), 0);
        }
    }
}
