// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { DeployV2Base } from "./DeployV2Base.s.sol";
import { AaveV4ReserveRegistry } from "../src/accounting/oracles/AaveV4ReserveRegistry.sol";
import { IAaveV4Spoke } from "../src/vendor/aave-v4/IAaveV4Spoke.sol";
import { console2 } from "forge-std/console2.sol";

/// @title ConfigureAaveV4ReserveRegistry
/// @notice Seeds a deployed AaveV4ReserveRegistry with every listed reserve of an Aave V4 spoke.
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
    }

    /*//////////////////////////////////////////////////////////////
                            MAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Register every reserve of the chain's default spoke(s).
    /// @param env Environment (0 = prod, 2 = staging)
    /// @param chainId Chain ID (selects the default spokes)
    /// @param registryAddr Deployed AaveV4ReserveRegistry
    function run(uint256 env, uint64 chainId, address registryAddr) external broadcast(env) {
        address[] memory spokes = _defaultSpokes(chainId);
        require(spokes.length > 0, "NO_DEFAULT_SPOKE: use runSpoke(env,chainId,registry,spoke)");
        _prepare(env, chainId, registryAddr);
        for (uint256 i; i < spokes.length; ++i) {
            _seedSpoke(AaveV4ReserveRegistry(registryAddr), spokes[i]);
        }
        console2.log("====== Registry Seeding Complete ======");
    }

    /// @notice Register every reserve of one explicit spoke.
    /// @param env Environment (0 = prod, 2 = staging)
    /// @param chainId Chain ID (logged and checked against the fork)
    /// @param registryAddr Deployed AaveV4ReserveRegistry
    /// @param spoke Aave V4 spoke to enumerate; trusted by the operator (see registry NatSpec)
    function runSpoke(uint256 env, uint64 chainId, address registryAddr, address spoke) external broadcast(env) {
        _prepare(env, chainId, registryAddr);
        _seedSpoke(AaveV4ReserveRegistry(registryAddr), spoke);
        console2.log("====== Registry Seeding Complete ======");
    }

    /// @notice Print each listed reserve of a spoke and whether it is registered. No broadcast.
    function runCheck(uint64 chainId, address registryAddr, address spoke) external view {
        console2.log("====== AaveV4ReserveRegistry Reserve Check ======");
        console2.log("Chain ID:", uint256(chainId));
        console2.log("Registry:", registryAddr);
        console2.log("Spoke:", spoke);
        if (registryAddr.code.length == 0) {
            console2.log("Status: REGISTRY NOT DEPLOYED");
            return;
        }
        AaveV4ReserveRegistry registry = AaveV4ReserveRegistry(registryAddr);
        uint256 missing;
        for (uint256 id; id < MAX_RESERVES_PER_SPOKE; ++id) {
            (bool listed, address underlying, uint8 decimals) = _probe(spoke, id);
            if (!listed) break;
            bool registered = registry.isRegistered(registry.computeReserveKey(spoke, id));
            if (!registered) ++missing;
            console2.log(
                string.concat(
                    "  id ",
                    vm.toString(id),
                    " ",
                    vm.toString(underlying),
                    " dec=",
                    vm.toString(uint256(decimals)),
                    registered ? "  [REGISTERED]" : "  [MISSING]"
                )
            );
        }
        console2.log(missing == 0 ? "Status: ALL LISTED RESERVES REGISTERED" : "Status: RESERVES NEED REGISTRATION");
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
        AaveV4ReserveRegistry registry = AaveV4ReserveRegistry(registryAddr);
        require(
            registry.hasRole(registry.MARKET_MANAGER_ROLE(), DEPLOYER),
            "DEPLOYER lacks MARKET_MANAGER_ROLE: roles already transferred, register via governance"
        );
        console2.log("====== Seed AaveV4ReserveRegistry ======");
        console2.log("Registry:", registryAddr);
        console2.log("Chain ID:", uint256(chainId));
        console2.log("Environment:", env);
        console2.log("Manager (DEPLOYER):", DEPLOYER);
    }

    /// @dev Enumerates and registers every listed reserve of `spoke`, skipping ones already registered.
    function _seedSpoke(AaveV4ReserveRegistry registry, address spoke) internal returns (SeedResult memory r) {
        require(spoke.code.length > 0, "SPOKE_HAS_NO_CODE");
        console2.log("");
        console2.log("Spoke:", spoke);
        for (uint256 id; id < MAX_RESERVES_PER_SPOKE; ++id) {
            (bool listed, address underlying, uint8 decimals) = _probe(spoke, id);
            if (!listed) break;
            ++r.listed;
            address key = registry.computeReserveKey(spoke, id);
            if (registry.isRegistered(key)) {
                ++r.skipped;
                console2.log(string.concat("  [=] id ", vm.toString(id), " already registered as ", vm.toString(key)));
                continue;
            }
            address registeredKey = registry.registerReserve(spoke, id);
            require(registeredKey == key, "KEY_MISMATCH");
            // The registry bound decimals from the spoke's Reserve struct; assert it saw what we saw.
            (,, address boundUnderlying, uint8 boundDecimals) = registry.getReserveInfo(key);
            require(boundUnderlying == underlying && boundDecimals == decimals, "RESERVE_BINDING_MISMATCH");
            ++r.registered;
            console2.log(
                string.concat(
                    "  [+] id ",
                    vm.toString(id),
                    " ",
                    vm.toString(underlying),
                    " dec=",
                    vm.toString(uint256(decimals)),
                    " -> key ",
                    vm.toString(key)
                )
            );
        }
        require(r.listed > 0, "SPOKE_LISTS_NO_RESERVES");
        require(r.listed < MAX_RESERVES_PER_SPOKE, "MAX_RESERVES_PER_SPOKE reached: raise the bound");
        console2.log("  listed:", r.listed);
        console2.log("  registered now:", r.registered);
        console2.log("  already registered:", r.skipped);
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
