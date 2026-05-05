// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { DeployV2Base } from "./DeployV2Base.s.sol";
import { SuperSponsorshipPaymaster } from "../src/paymaster/SuperSponsorshipPaymaster.sol";
import { console2 } from "forge-std/console2.sol";

/// @title TransferSuperSponsorshipPaymasterRoles
/// @notice Script to transfer SuperSponsorshipPaymaster roles from DEPLOYER to governance addresses.
/// @dev Role mapping:
///      - FUNDING_ROLE     → GOVERNOR        (operational funding/withdrawals)
///      - DEFAULT_ADMIN_ROLE → SUPER_GOVERNOR (admin: pause, sweep, reconcile, overhead, emergency)
///      - MANAGER_ROLE       → SUPER_GOVERNOR (strategy management: pause/unpause, maxCost)
///      After granting, all roles are revoked from DEPLOYER.
contract TransferSuperSponsorshipPaymasterRoles is DeployV2Base {
    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address internal constant GOVERNOR = 0x9e01f41da2212C1FBc32A041CfAEF72479FA48eC;

    /*//////////////////////////////////////////////////////////////
                            MAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfer all roles from DEPLOYER to GOVERNOR / SUPER_GOVERNOR
    /// @param env Environment (0 = prod, 2 = staging)
    /// @param paymasterAddr Address of the deployed SuperSponsorshipPaymaster
    function run(uint256 env, address paymasterAddr) external broadcast(env) {
        require(env == 0 || env == 2, "INVALID_ENV: only prod (0) or staging (2) supported");
        _setBaseConfiguration(env, "");

        require(paymasterAddr.code.length > 0, "PAYMASTER_NOT_DEPLOYED");
        require(SUPER_GOVERNOR_ADDRESS != address(0), "SUPER_GOVERNOR_ADDRESS cannot be zero");
        require(GOVERNOR != address(0), "GOVERNOR cannot be zero");
        require(SUPER_GOVERNOR_ADDRESS != DEPLOYER, "SUPER_GOVERNOR_ADDRESS cannot equal DEPLOYER");
        require(GOVERNOR != DEPLOYER, "GOVERNOR cannot equal DEPLOYER");

        SuperSponsorshipPaymaster pm = SuperSponsorshipPaymaster(payable(paymasterAddr));

        console2.log("====== Transfer SuperSponsorshipPaymaster Roles ======");
        console2.log("Paymaster:", paymasterAddr);
        console2.log("Environment:", env);
        console2.log("Current Admin (DEPLOYER):", DEPLOYER);
        console2.log("GOVERNOR (gets FUNDING_ROLE):", GOVERNOR);
        console2.log("SUPER_GOVERNOR (gets ADMIN + MANAGER):", SUPER_GOVERNOR_ADDRESS);
        console2.log("");

        bytes32 DEFAULT_ADMIN_ROLE = pm.DEFAULT_ADMIN_ROLE();
        bytes32 FUNDING_ROLE = pm.FUNDING_ROLE();
        bytes32 MANAGER_ROLE = pm.MANAGER_ROLE();

        // ---- Log current state ----
        _logRoleStatus(pm, "Current");

        // ---- Check if already fully transferred ----
        if (_isFullyTransferred(pm)) {
            console2.log("=== SKIPPED: Roles Already Fully Transferred ===");
            return;
        }

        // ---- Verify deployer has admin ----
        require(pm.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER), "DEPLOYER does not have DEFAULT_ADMIN_ROLE");

        // ---- Grant roles ----
        console2.log("Granting roles...");

        // FUNDING_ROLE → GOVERNOR
        if (!pm.hasRole(FUNDING_ROLE, GOVERNOR)) {
            pm.grantRole(FUNDING_ROLE, GOVERNOR);
            console2.log("  [+] Granted FUNDING_ROLE to GOVERNOR");
        } else {
            console2.log("  [=] FUNDING_ROLE already granted to GOVERNOR");
        }

        // DEFAULT_ADMIN_ROLE → SUPER_GOVERNOR
        if (!pm.hasRole(DEFAULT_ADMIN_ROLE, SUPER_GOVERNOR_ADDRESS)) {
            pm.grantRole(DEFAULT_ADMIN_ROLE, SUPER_GOVERNOR_ADDRESS);
            console2.log("  [+] Granted DEFAULT_ADMIN_ROLE to SUPER_GOVERNOR");
        } else {
            console2.log("  [=] DEFAULT_ADMIN_ROLE already granted to SUPER_GOVERNOR");
        }

        // MANAGER_ROLE → SUPER_GOVERNOR
        if (!pm.hasRole(MANAGER_ROLE, SUPER_GOVERNOR_ADDRESS)) {
            pm.grantRole(MANAGER_ROLE, SUPER_GOVERNOR_ADDRESS);
            console2.log("  [+] Granted MANAGER_ROLE to SUPER_GOVERNOR");
        } else {
            console2.log("  [=] MANAGER_ROLE already granted to SUPER_GOVERNOR");
        }

        // ---- Revoke roles from DEPLOYER ----
        console2.log("");
        console2.log("Revoking roles from DEPLOYER...");

        // Revoke FUNDING_ROLE first (least privileged)
        if (pm.hasRole(FUNDING_ROLE, DEPLOYER)) {
            pm.revokeRole(FUNDING_ROLE, DEPLOYER);
            console2.log("  [-] Revoked FUNDING_ROLE");
        } else {
            console2.log("  [=] FUNDING_ROLE already revoked");
        }

        // Revoke MANAGER_ROLE
        if (pm.hasRole(MANAGER_ROLE, DEPLOYER)) {
            pm.revokeRole(MANAGER_ROLE, DEPLOYER);
            console2.log("  [-] Revoked MANAGER_ROLE");
        } else {
            console2.log("  [=] MANAGER_ROLE already revoked");
        }

        // Revoke DEFAULT_ADMIN_ROLE last (most privileged)
        if (pm.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER)) {
            pm.revokeRole(DEFAULT_ADMIN_ROLE, DEPLOYER);
            console2.log("  [-] Revoked DEFAULT_ADMIN_ROLE");
        } else {
            console2.log("  [=] DEFAULT_ADMIN_ROLE already revoked");
        }

        // ---- Verify final state ----
        console2.log("");
        require(pm.hasRole(FUNDING_ROLE, GOVERNOR), "TRANSFER_FAILED: GOVERNOR missing FUNDING_ROLE");
        require(
            pm.hasRole(DEFAULT_ADMIN_ROLE, SUPER_GOVERNOR_ADDRESS), "TRANSFER_FAILED: SUPER_GOVERNOR missing ADMIN"
        );
        require(pm.hasRole(MANAGER_ROLE, SUPER_GOVERNOR_ADDRESS), "TRANSFER_FAILED: SUPER_GOVERNOR missing MANAGER");
        require(!pm.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER), "TRANSFER_FAILED: DEPLOYER still has ADMIN");
        require(!pm.hasRole(FUNDING_ROLE, DEPLOYER), "TRANSFER_FAILED: DEPLOYER still has FUNDING");
        require(!pm.hasRole(MANAGER_ROLE, DEPLOYER), "TRANSFER_FAILED: DEPLOYER still has MANAGER");

        _logRoleStatus(pm, "Final");

        console2.log("====== Role Transfer Complete ======");
    }

    /// @notice Check current role status without making changes
    /// @param env Environment (0 = prod, 2 = staging)
    /// @param paymasterAddr Address of the deployed SuperSponsorshipPaymaster
    function runCheck(uint256 env, address paymasterAddr) external broadcast(env) {
        require(env == 0 || env == 2, "INVALID_ENV: only prod (0) or staging (2) supported");
        _setBaseConfiguration(env, "");

        console2.log("====== SuperSponsorshipPaymaster Role Check ======");
        console2.log("Paymaster:", paymasterAddr);
        console2.log("Environment:", env);
        console2.log("DEPLOYER:", DEPLOYER);
        console2.log("GOVERNOR:", GOVERNOR);
        console2.log("SUPER_GOVERNOR:", SUPER_GOVERNOR_ADDRESS);
        console2.log("");

        if (paymasterAddr.code.length == 0) {
            console2.log("Status: NOT DEPLOYED");
            return;
        }

        SuperSponsorshipPaymaster pm = SuperSponsorshipPaymaster(payable(paymasterAddr));

        _logRoleStatus(pm, "Current");

        if (_isFullyTransferred(pm)) {
            console2.log("Status: ROLES FULLY TRANSFERRED");
        } else if (pm.hasRole(pm.DEFAULT_ADMIN_ROLE(), DEPLOYER)) {
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

    function _logRoleStatus(SuperSponsorshipPaymaster pm, string memory label) internal view {
        bytes32 DEFAULT_ADMIN_ROLE = pm.DEFAULT_ADMIN_ROLE();
        bytes32 FUNDING_ROLE = pm.FUNDING_ROLE();
        bytes32 MANAGER_ROLE = pm.MANAGER_ROLE();

        console2.log(string.concat("=== ", label, " Role Status ==="));
        console2.log("DEPLOYER:");
        console2.log("  DEFAULT_ADMIN_ROLE:", pm.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER));
        console2.log("  FUNDING_ROLE:", pm.hasRole(FUNDING_ROLE, DEPLOYER));
        console2.log("  MANAGER_ROLE:", pm.hasRole(MANAGER_ROLE, DEPLOYER));
        console2.log("GOVERNOR:");
        console2.log("  FUNDING_ROLE:", pm.hasRole(FUNDING_ROLE, GOVERNOR));
        console2.log("SUPER_GOVERNOR:");
        console2.log("  DEFAULT_ADMIN_ROLE:", pm.hasRole(DEFAULT_ADMIN_ROLE, SUPER_GOVERNOR_ADDRESS));
        console2.log("  MANAGER_ROLE:", pm.hasRole(MANAGER_ROLE, SUPER_GOVERNOR_ADDRESS));
        console2.log("");
    }

    function _isFullyTransferred(SuperSponsorshipPaymaster pm) internal view returns (bool) {
        bytes32 DEFAULT_ADMIN_ROLE = pm.DEFAULT_ADMIN_ROLE();
        bytes32 FUNDING_ROLE = pm.FUNDING_ROLE();
        bytes32 MANAGER_ROLE = pm.MANAGER_ROLE();

        bool governorHasFunding = pm.hasRole(FUNDING_ROLE, GOVERNOR);
        bool superGovHasAdmin = pm.hasRole(DEFAULT_ADMIN_ROLE, SUPER_GOVERNOR_ADDRESS);
        bool superGovHasManager = pm.hasRole(MANAGER_ROLE, SUPER_GOVERNOR_ADDRESS);
        bool deployerHasNone = !pm.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER) && !pm.hasRole(FUNDING_ROLE, DEPLOYER)
            && !pm.hasRole(MANAGER_ROLE, DEPLOYER);

        return governorHasFunding && superGovHasAdmin && superGovHasManager && deployerHasNone;
    }
}
