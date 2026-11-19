// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { DeployV2Base } from "./DeployV2Base.s.sol";
import { ConstantsOtherHooks } from "./utils/ConstantsOtherHooks.sol";
import { GyldInTransitRegistry } from "../src/accounting/oracles/GyldInTransitRegistry.sol";
import { console2 } from "forge-std/console2.sol";

/// @title TransferGyldInTransitRegistryRoles
/// @notice Transfers `GyldInTransitRegistry` roles from DEPLOYER to governance and the reconciler.
/// @dev Role mapping, mirroring `TransferGyldBondRegistryRoles`:
///      - MANAGER_ROLE       → GOVERNOR        (destinations, transit age, valuation oracle, per-instrument caps and
///                               fee haircuts, the timelocked manual settle, receiver rescue)
///      - RECONCILER_ROLE    → reconciler bot  (sweeps deliveries out of the strategy's receiver and shrinks the lot
///                               by what the delivery is worth at the live NAV, within the instrument's fee + entry /
///                               exit tolerance band; DECREASE only, never a loss: losses go through the MANAGER's
///                               timelocked manual settle)
///      - DEFAULT_ADMIN_ROLE → SUPER_GOVERNOR  (role administration)
///      All three are then revoked from DEPLOYER.
/// @dev RUN AFTER `ConfigureGyldInTransitRegistry.runDestinations/runTransitDefaults/runOracle` (they need the
///      DEPLOYER's MANAGER_ROLE) and BEFORE any deposit leaf executes: while DEPLOYER holds MANAGER_ROLE one
///      key can re-point the deposit address, which is the drain vector for every open deposit leaf, and holds
///      MANAGER and RECONCILER together, which is the one pairing the design does not defend against.
/// @dev The reconciler is a dedicated signer, not a governance address: it runs continuously and can only
///      decrease entries by what the receiver actually holds, at the live NAV within the band, so its compromise
///      bounds to delaying settles (temporary under-valuation) and to mis-stating a lot by at most the fee +
///      tolerance band per settle, never to moved funds.
contract TransferGyldInTransitRegistryRoles is DeployV2Base, ConstantsOtherHooks {
    /// @dev Same operational governor as the other registries in this repo
    address internal constant GOVERNOR = 0x9e01f41da2212C1FBc32A041CfAEF72479FA48eC;
    /// @notice Flare-specific Super Governor address
    address internal constant FLARE_SUPER_GOVERNOR = 0x0f0Db7CEDD49587D78d67175Ff59Ed7069A35874;

    function run(uint256 env, uint64 chainId, address registryAddr, address reconciler) external broadcast(env) {
        require(env == 0 || env == 2, "INVALID_ENV: only prod (0) or staging (2) supported");
        _setBaseConfiguration(env, "");
        address superGovernor = _getSuperGovernor(chainId);
        require(registryAddr.code.length > 0, "REGISTRY_NOT_DEPLOYED");
        require(superGovernor != address(0), "SUPER_GOVERNOR cannot be zero");
        require(reconciler != address(0), "RECONCILER cannot be zero");
        // Same merge-blocker as the bond registry: a codeless admin freezes role administration forever.
        require(superGovernor.code.length > 0, "SUPER_GOVERNOR_NOT_DEPLOYED_ON_THIS_CHAIN");
        address bondRegistry = __computeContractAddress(GYLD_BOND_REGISTRY_KEY, abi.encode(DEPLOYER), env);
        require(
            registryAddr
                == __computeContractAddress(GYLD_IN_TRANSIT_REGISTRY_KEY, abi.encode(DEPLOYER, bondRegistry), env),
            "REGISTRY_ADDRESS_MISMATCH: not the CREATE2 address this env deploys"
        );
        require(
            superGovernor != DEPLOYER && GOVERNOR != DEPLOYER && reconciler != DEPLOYER, "DEPLOYER cannot keep a role"
        );

        GyldInTransitRegistry registry = GyldInTransitRegistry(registryAddr);
        console2.log("====== Transfer GyldInTransitRegistry Roles ======");
        console2.log("Registry:", registryAddr);
        console2.log("GOVERNOR (gets MANAGER):", GOVERNOR);
        console2.log("RECONCILER:", reconciler);
        console2.log("SUPER_GOVERNOR (gets ADMIN):", superGovernor);

        bytes32 manager = registry.MANAGER_ROLE();
        bytes32 rec = registry.RECONCILER_ROLE();
        bytes32 admin = registry.DEFAULT_ADMIN_ROLE();

        registry.grantRole(manager, GOVERNOR);
        registry.grantRole(rec, reconciler);
        registry.grantRole(admin, superGovernor);
        registry.revokeRole(manager, DEPLOYER);
        registry.revokeRole(rec, DEPLOYER);
        registry.revokeRole(admin, DEPLOYER);

        require(registry.hasRole(manager, GOVERNOR), "MANAGER not granted");
        require(registry.hasRole(rec, reconciler), "RECONCILER not granted");
        require(registry.hasRole(admin, superGovernor), "ADMIN not granted");
        require(!registry.hasRole(manager, DEPLOYER), "MANAGER not revoked");
        require(!registry.hasRole(rec, DEPLOYER), "RECONCILER not revoked");
        require(!registry.hasRole(admin, DEPLOYER), "ADMIN not revoked");
        console2.log("====== Roles transferred ======");
    }

    /// @notice Read-only verification of the handover
    function runCheck(uint64 chainId, address registryAddr, address reconciler) external view {
        require(block.chainid == chainId, "CHAIN_ID_MISMATCH");
        GyldInTransitRegistry registry = GyldInTransitRegistry(registryAddr);
        address superGovernor = _getSuperGovernor(chainId);
        console2.log("GOVERNOR has MANAGER:", registry.hasRole(registry.MANAGER_ROLE(), GOVERNOR));
        console2.log("reconciler has RECONCILER:", registry.hasRole(registry.RECONCILER_ROLE(), reconciler));
        console2.log("SUPER_GOVERNOR has ADMIN:", registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), superGovernor));
        console2.log("DEPLOYER has MANAGER:", registry.hasRole(registry.MANAGER_ROLE(), DEPLOYER));
        console2.log("DEPLOYER has RECONCILER:", registry.hasRole(registry.RECONCILER_ROLE(), DEPLOYER));
        console2.log("DEPLOYER has ADMIN:", registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), DEPLOYER));
    }

    function _getSuperGovernor(uint64 chainId) internal pure returns (address) {
        if (chainId == FLARE_CHAIN_ID) return FLARE_SUPER_GOVERNOR;
        return SUPER_GOVERNOR_ADDRESS;
    }
}
