// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { DeployV2Base } from "./DeployV2Base.s.sol";
import { UniV3CLPRegistry } from "../src/accounting/oracles/UniV3CLPRegistry.sol";
import { console2 } from "forge-std/console2.sol";

/// @title TransferUniV3CLPRegistryRoles
/// @notice Script to transfer UniV3CLPRegistry roles from DEPLOYER to governance addresses.
/// @dev Role mapping:
///      - POSITION_MANAGER_ROLE → GOVERNOR         (operational: register/deregister positions)
///      - DEFAULT_ADMIN_ROLE    → SUPER_GOVERNOR    (admin: manage role grants)
///      After granting, both roles are revoked from DEPLOYER.
///      On Flare chain (chainId=14), uses FLARE_SUPER_GOVERNOR instead of SUPER_GOVERNOR_ADDRESS.
contract TransferUniV3CLPRegistryRoles is DeployV2Base {
    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address internal constant GOVERNOR = 0x9e01f41da2212C1FBc32A041CfAEF72479FA48eC;

    /// @notice Flare-specific Super Governor address
    address internal constant FLARE_SUPER_GOVERNOR = 0x0f0Db7CEDD49587D78d67175Ff59Ed7069A35874;

    /*//////////////////////////////////////////////////////////////
                            MAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfer all roles from DEPLOYER to GOVERNOR / SUPER_GOVERNOR
    /// @param env Environment (0 = prod, 2 = staging)
    /// @param chainId Chain ID (used to select Flare-specific Super Governor)
    /// @param registryAddr Address of the deployed UniV3CLPRegistry
    function run(uint256 env, uint64 chainId, address registryAddr) external broadcast(env) {
        require(env == 0 || env == 2, "INVALID_ENV: only prod (0) or staging (2) supported");
        _setBaseConfiguration(env, "");

        address superGovernor = _getSuperGovernor(chainId);

        require(registryAddr.code.length > 0, "REGISTRY_NOT_DEPLOYED");
        require(superGovernor != address(0), "SUPER_GOVERNOR cannot be zero");
        require(GOVERNOR != address(0), "GOVERNOR cannot be zero");
        require(superGovernor != DEPLOYER, "SUPER_GOVERNOR cannot equal DEPLOYER");
        require(GOVERNOR != DEPLOYER, "GOVERNOR cannot equal DEPLOYER");

        UniV3CLPRegistry registry = UniV3CLPRegistry(registryAddr);

        console2.log("====== Transfer UniV3CLPRegistry Roles ======");
        console2.log("Registry:", registryAddr);
        console2.log("Chain ID:", uint256(chainId));
        console2.log("Environment:", env);
        console2.log("Current Admin (DEPLOYER):", DEPLOYER);
        console2.log("GOVERNOR (gets POSITION_MANAGER):", GOVERNOR);
        console2.log("SUPER_GOVERNOR (gets ADMIN):", superGovernor);
        console2.log("");

        bytes32 DEFAULT_ADMIN_ROLE = registry.DEFAULT_ADMIN_ROLE();
        bytes32 POSITION_MANAGER_ROLE = registry.POSITION_MANAGER_ROLE();

        // ---- Log current state ----
        _logRoleStatus(registry, superGovernor, "Current");

        // ---- Check if already fully transferred ----
        if (_isFullyTransferred(registry, superGovernor)) {
            console2.log("=== SKIPPED: Roles Already Fully Transferred ===");
            return;
        }

        // ---- Verify DEPLOYER has admin ----
        require(registry.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER), "DEPLOYER does not have DEFAULT_ADMIN_ROLE");

        // ---- Grant roles ----
        console2.log("Granting roles...");

        // POSITION_MANAGER_ROLE → GOVERNOR
        if (!registry.hasRole(POSITION_MANAGER_ROLE, GOVERNOR)) {
            registry.grantRole(POSITION_MANAGER_ROLE, GOVERNOR);
            console2.log("  [+] Granted POSITION_MANAGER_ROLE to GOVERNOR");
        } else {
            console2.log("  [=] POSITION_MANAGER_ROLE already granted to GOVERNOR");
        }

        // DEFAULT_ADMIN_ROLE → SUPER_GOVERNOR
        if (!registry.hasRole(DEFAULT_ADMIN_ROLE, superGovernor)) {
            registry.grantRole(DEFAULT_ADMIN_ROLE, superGovernor);
            console2.log("  [+] Granted DEFAULT_ADMIN_ROLE to SUPER_GOVERNOR");
        } else {
            console2.log("  [=] DEFAULT_ADMIN_ROLE already granted to SUPER_GOVERNOR");
        }

        // ---- Revoke roles from DEPLOYER ----
        console2.log("");
        console2.log("Revoking roles from DEPLOYER...");

        // Revoke POSITION_MANAGER_ROLE first (least privileged)
        if (registry.hasRole(POSITION_MANAGER_ROLE, DEPLOYER)) {
            registry.revokeRole(POSITION_MANAGER_ROLE, DEPLOYER);
            console2.log("  [-] Revoked POSITION_MANAGER_ROLE");
        } else {
            console2.log("  [=] POSITION_MANAGER_ROLE already revoked");
        }

        // Revoke DEFAULT_ADMIN_ROLE last (most privileged)
        if (registry.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER)) {
            registry.revokeRole(DEFAULT_ADMIN_ROLE, DEPLOYER);
            console2.log("  [-] Revoked DEFAULT_ADMIN_ROLE");
        } else {
            console2.log("  [=] DEFAULT_ADMIN_ROLE already revoked");
        }

        // ---- Verify final state ----
        console2.log("");
        require(
            registry.hasRole(POSITION_MANAGER_ROLE, GOVERNOR), "TRANSFER_FAILED: GOVERNOR missing POSITION_MANAGER"
        );
        require(
            registry.hasRole(DEFAULT_ADMIN_ROLE, superGovernor), "TRANSFER_FAILED: SUPER_GOVERNOR missing ADMIN"
        );
        require(!registry.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER), "TRANSFER_FAILED: DEPLOYER still has ADMIN");
        require(
            !registry.hasRole(POSITION_MANAGER_ROLE, DEPLOYER),
            "TRANSFER_FAILED: DEPLOYER still has POSITION_MANAGER"
        );

        _logRoleStatus(registry, superGovernor, "Final");

        console2.log("====== Role Transfer Complete ======");
    }

    /// @notice Check current role status without making changes
    /// @param env Environment (0 = prod, 2 = staging)
    /// @param chainId Chain ID (used to select Flare-specific Super Governor)
    /// @param registryAddr Address of the deployed UniV3CLPRegistry
    function runCheck(uint256 env, uint64 chainId, address registryAddr) external broadcast(env) {
        require(env == 0 || env == 2, "INVALID_ENV: only prod (0) or staging (2) supported");
        _setBaseConfiguration(env, "");

        address superGovernor = _getSuperGovernor(chainId);

        console2.log("====== UniV3CLPRegistry Role Check ======");
        console2.log("Registry:", registryAddr);
        console2.log("Chain ID:", uint256(chainId));
        console2.log("Environment:", env);
        console2.log("DEPLOYER:", DEPLOYER);
        console2.log("GOVERNOR:", GOVERNOR);
        console2.log("SUPER_GOVERNOR:", superGovernor);
        console2.log("");

        if (registryAddr.code.length == 0) {
            console2.log("Status: NOT DEPLOYED");
            return;
        }

        UniV3CLPRegistry registry = UniV3CLPRegistry(registryAddr);

        _logRoleStatus(registry, superGovernor, "Current");

        if (_isFullyTransferred(registry, superGovernor)) {
            console2.log("Status: ROLES FULLY TRANSFERRED");
        } else if (registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), DEPLOYER)) {
            console2.log("Status: ROLES NEED TRANSFER");
        } else {
            console2.log("Status: UNEXPECTED STATE - Check role distribution manually");
        }

        console2.log("");
        console2.log("====== Check Complete ======");
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the Super Governor address for a given chain
    /// @param chainId Chain ID
    /// @return The Super Governor address (Flare-specific or default)
    function _getSuperGovernor(uint64 chainId) internal pure returns (address) {
        if (chainId == FLARE_CHAIN_ID) {
            return FLARE_SUPER_GOVERNOR;
        }
        return SUPER_GOVERNOR_ADDRESS;
    }

    function _logRoleStatus(
        UniV3CLPRegistry registry,
        address superGovernor,
        string memory label
    )
        internal
        view
    {
        bytes32 DEFAULT_ADMIN_ROLE = registry.DEFAULT_ADMIN_ROLE();
        bytes32 POSITION_MANAGER_ROLE = registry.POSITION_MANAGER_ROLE();

        console2.log(string.concat("=== ", label, " Role Status ==="));
        console2.log("DEPLOYER:");
        console2.log("  DEFAULT_ADMIN_ROLE:", registry.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER));
        console2.log("  POSITION_MANAGER_ROLE:", registry.hasRole(POSITION_MANAGER_ROLE, DEPLOYER));
        console2.log("GOVERNOR:");
        console2.log("  POSITION_MANAGER_ROLE:", registry.hasRole(POSITION_MANAGER_ROLE, GOVERNOR));
        console2.log("SUPER_GOVERNOR:");
        console2.log("  DEFAULT_ADMIN_ROLE:", registry.hasRole(DEFAULT_ADMIN_ROLE, superGovernor));
        console2.log("");
    }

    function _isFullyTransferred(
        UniV3CLPRegistry registry,
        address superGovernor
    )
        internal
        view
        returns (bool)
    {
        bytes32 DEFAULT_ADMIN_ROLE = registry.DEFAULT_ADMIN_ROLE();
        bytes32 POSITION_MANAGER_ROLE = registry.POSITION_MANAGER_ROLE();

        bool governorHasManager = registry.hasRole(POSITION_MANAGER_ROLE, GOVERNOR);
        bool superGovHasAdmin = registry.hasRole(DEFAULT_ADMIN_ROLE, superGovernor);
        bool deployerHasNone =
            !registry.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER) && !registry.hasRole(POSITION_MANAGER_ROLE, DEPLOYER);

        return governorHasManager && superGovHasAdmin && deployerHasNone;
    }
}
