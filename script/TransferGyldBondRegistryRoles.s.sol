// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { DeployV2Base } from "./DeployV2Base.s.sol";
import { ConstantsOtherHooks } from "./utils/ConstantsOtherHooks.sol";
import { GyldBondRegistry } from "../src/accounting/oracles/GyldBondRegistry.sol";
import { console2 } from "forge-std/console2.sol";

/// @title TransferGyldBondRegistryRoles
/// @notice Transfers `GyldBondRegistry` roles from DEPLOYER to governance.
/// @dev Role mapping, mirroring `TransferUniV3CLPRegistryRoles`:
///      - INSTRUMENT_MANAGER_ROLE → GOVERNOR       (operational: register, suspend, propose changes)
///      - DEFAULT_ADMIN_ROLE      → SUPER_GOVERNOR (admin: manage role grants)
///      Both are then revoked from DEPLOYER.
/// @dev RUN THIS BEFORE REGISTERING ANY INSTRUMENT. A registry whose admin is still DEPLOYER is an
///      instrument list one key can re-point, and `INSTRUMENT_MANAGER_ROLE` reaches every valuation control:
///      the un-timelocked suspension switch, the staleness bounds, and the two timelocked change paths.
/// @dev NOTE ON WHAT THIS DOES NOT FIX. `INSTRUMENT_MANAGER_ROLE` can move an instrument's mark through
///      several instant, single-key routes (`setStalenessBounds` loosening, `refreshScales`,
///      `setNavSuspended(false)`), and role ADMINISTRATION is not timelocked, so a compromised default admin
///      can mint itself a manager key. Transferring to governance is therefore necessary and not sufficient.
/// @dev AND `GOVERNOR` IS AN EOA, not a multisig. Verified 2026-11-02: the address below has no code on
///      Base, Arbitrum, BSC or Katana. So this handover moves a mark-moving role from one single key
///      (DEPLOYER) to another single key. That is the shipped posture of all five Transfer*Roles scripts in
///      this repo and is an open decision, not a Gyld-local defect. Do not read it as "secured by
///      governance". See the open findings in .claude/sessions/context_session_gyld_bonds.md.
/// @dev A `DEPLOYER` COMPROMISE BEFORE THIS RUNS IS NOT DETECTABLE HERE. The registry is plain
///      `AccessControl`, not `AccessControlEnumerable`, so neither `run` nor `runCheck` can see a third
///      party that `DEPLOYER` granted a role to. Verify the holder set off-chain from `RoleGranted` /
///      `RoleRevoked` events from the deployment block before trusting a "fully transferred" result.
contract TransferGyldBondRegistryRoles is DeployV2Base, ConstantsOtherHooks {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Same operational governor as the other registries in this repo
    address internal constant GOVERNOR = 0x9e01f41da2212C1FBc32A041CfAEF72479FA48eC;

    /// @notice Flare-specific Super Governor address
    address internal constant FLARE_SUPER_GOVERNOR = 0x0f0Db7CEDD49587D78d67175Ff59Ed7069A35874;

    /*//////////////////////////////////////////////////////////////
                              MAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfer all roles from DEPLOYER to GOVERNOR / SUPER_GOVERNOR
    /// @param env Environment (0 = prod, 2 = staging)
    /// @param chainId Chain ID, used to select a chain-specific Super Governor
    /// @param registryAddr Address of the deployed GyldBondRegistry
    function run(uint256 env, uint64 chainId, address registryAddr) external broadcast(env) {
        require(env == 0 || env == 2, "INVALID_ENV: only prod (0) or staging (2) supported");
        _setBaseConfiguration(env, "");

        address superGovernor = _getSuperGovernor(chainId);

        require(registryAddr.code.length > 0, "REGISTRY_NOT_DEPLOYED");
        require(superGovernor != address(0), "SUPER_GOVERNOR cannot be zero");
        require(GOVERNOR != address(0), "GOVERNOR cannot be zero");
        // THE MERGE-BLOCKER CHECK. `GyldBondRegistry` is plain `AccessControl`: no owner, no recovery, and
        // no second admin. Granting DEFAULT_ADMIN_ROLE to an address with no code and then revoking it from
        // DEPLOYER freezes role administration FOREVER, and every closing `require` below would still pass
        // because `hasRole` is true for a codeless address. Verified on-chain 2026-11-02:
        // SUPER_GOVERNOR_ADDRESS returns empty code on Katana (747474), the only chain this family targets.
        require(superGovernor.code.length > 0, "SUPER_GOVERNOR_NOT_DEPLOYED_ON_THIS_CHAIN");
        // The registry address is a free parameter, so pin it to what the deploy would have produced. A
        // typo'd address otherwise makes the operator believe the handover landed on the real registry.
        require(
            registryAddr == __computeContractAddress(GYLD_BOND_REGISTRY_KEY, abi.encode(DEPLOYER), env),
            "REGISTRY_ADDRESS_MISMATCH: not the CREATE2 address this env deploys"
        );
        require(superGovernor != DEPLOYER, "SUPER_GOVERNOR cannot equal DEPLOYER");
        require(GOVERNOR != DEPLOYER, "GOVERNOR cannot equal DEPLOYER");

        GyldBondRegistry registry = GyldBondRegistry(registryAddr);

        console2.log("====== Transfer GyldBondRegistry Roles ======");
        console2.log("Registry:", registryAddr);
        console2.log("Chain ID:", uint256(chainId));
        console2.log("Environment:", env);
        console2.log("Current Admin (DEPLOYER):", DEPLOYER);
        console2.log("GOVERNOR (gets INSTRUMENT_MANAGER):", GOVERNOR);
        console2.log("SUPER_GOVERNOR (gets ADMIN):", superGovernor);
        console2.log("");

        bytes32 DEFAULT_ADMIN_ROLE = registry.DEFAULT_ADMIN_ROLE();
        bytes32 INSTRUMENT_MANAGER_ROLE = registry.INSTRUMENT_MANAGER_ROLE();

        _logRoleStatus(registry, superGovernor, "Current");

        if (_isFullyTransferred(registry, superGovernor)) {
            console2.log("=== SKIPPED: Roles Already Fully Transferred ===");
            return;
        }

        require(registry.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER), "DEPLOYER does not have DEFAULT_ADMIN_ROLE");

        // ---- Grant ----
        console2.log("Granting roles...");
        if (!registry.hasRole(INSTRUMENT_MANAGER_ROLE, GOVERNOR)) {
            registry.grantRole(INSTRUMENT_MANAGER_ROLE, GOVERNOR);
            console2.log("  [+] Granted INSTRUMENT_MANAGER_ROLE to GOVERNOR");
        } else {
            console2.log("  [=] INSTRUMENT_MANAGER_ROLE already granted to GOVERNOR");
        }

        if (!registry.hasRole(DEFAULT_ADMIN_ROLE, superGovernor)) {
            registry.grantRole(DEFAULT_ADMIN_ROLE, superGovernor);
            console2.log("  [+] Granted DEFAULT_ADMIN_ROLE to SUPER_GOVERNOR");
        } else {
            console2.log("  [=] DEFAULT_ADMIN_ROLE already granted to SUPER_GOVERNOR");
        }

        // ---- Revoke, least privileged first ----
        console2.log("");
        console2.log("Revoking roles from DEPLOYER...");
        if (registry.hasRole(INSTRUMENT_MANAGER_ROLE, DEPLOYER)) {
            registry.revokeRole(INSTRUMENT_MANAGER_ROLE, DEPLOYER);
            console2.log("  [-] Revoked INSTRUMENT_MANAGER_ROLE");
        } else {
            console2.log("  [=] INSTRUMENT_MANAGER_ROLE already revoked");
        }

        if (registry.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER)) {
            registry.revokeRole(DEFAULT_ADMIN_ROLE, DEPLOYER);
            console2.log("  [-] Revoked DEFAULT_ADMIN_ROLE");
        } else {
            console2.log("  [=] DEFAULT_ADMIN_ROLE already revoked");
        }

        // ---- Verify ----
        console2.log("");
        require(
            registry.hasRole(INSTRUMENT_MANAGER_ROLE, GOVERNOR), "TRANSFER_FAILED: GOVERNOR missing INSTRUMENT_MANAGER"
        );
        require(registry.hasRole(DEFAULT_ADMIN_ROLE, superGovernor), "TRANSFER_FAILED: SUPER_GOVERNOR missing ADMIN");
        require(!registry.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER), "TRANSFER_FAILED: DEPLOYER still has ADMIN");
        require(
            !registry.hasRole(INSTRUMENT_MANAGER_ROLE, DEPLOYER),
            "TRANSFER_FAILED: DEPLOYER still has INSTRUMENT_MANAGER"
        );

        _logRoleStatus(registry, superGovernor, "Final");
        console2.log("====== Role Transfer Complete ======");
    }

    /// @notice Check current role status without making changes
    /// @param env Environment (0 = prod, 2 = staging)
    /// @param chainId Chain ID, used to select a chain-specific Super Governor
    /// @param registryAddr Address of the deployed GyldBondRegistry
    function runCheck(uint256 env, uint64 chainId, address registryAddr) external broadcast(env) {
        require(env == 0 || env == 2, "INVALID_ENV: only prod (0) or staging (2) supported");
        _setBaseConfiguration(env, "");

        address superGovernor = _getSuperGovernor(chainId);

        console2.log("====== GyldBondRegistry Role Check ======");
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
        if (superGovernor.code.length == 0) {
            console2.log("Status: BLOCKED - SUPER_GOVERNOR has NO CODE on this chain.");
            console2.log("  Granting admin to it would permanently freeze role administration.");
            console2.log("  Deploy the governance Safe on this chain before running the transfer.");
            return;
        }

        GyldBondRegistry registry = GyldBondRegistry(registryAddr);
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

    function _getSuperGovernor(uint64 chainId) internal pure returns (address) {
        if (chainId == FLARE_CHAIN_ID) {
            return FLARE_SUPER_GOVERNOR;
        }
        return SUPER_GOVERNOR_ADDRESS;
    }

    function _logRoleStatus(GyldBondRegistry registry, address superGovernor, string memory label) internal view {
        bytes32 DEFAULT_ADMIN_ROLE = registry.DEFAULT_ADMIN_ROLE();
        bytes32 INSTRUMENT_MANAGER_ROLE = registry.INSTRUMENT_MANAGER_ROLE();

        console2.log(string.concat("=== ", label, " Role Status ==="));
        console2.log("DEPLOYER:");
        console2.log("  DEFAULT_ADMIN_ROLE:", registry.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER));
        console2.log("  INSTRUMENT_MANAGER_ROLE:", registry.hasRole(INSTRUMENT_MANAGER_ROLE, DEPLOYER));
        console2.log("GOVERNOR:");
        console2.log("  INSTRUMENT_MANAGER_ROLE:", registry.hasRole(INSTRUMENT_MANAGER_ROLE, GOVERNOR));
        console2.log("SUPER_GOVERNOR:");
        console2.log("  DEFAULT_ADMIN_ROLE:", registry.hasRole(DEFAULT_ADMIN_ROLE, superGovernor));
        console2.log("");
    }

    function _isFullyTransferred(GyldBondRegistry registry, address superGovernor) internal view returns (bool) {
        bytes32 DEFAULT_ADMIN_ROLE = registry.DEFAULT_ADMIN_ROLE();
        bytes32 INSTRUMENT_MANAGER_ROLE = registry.INSTRUMENT_MANAGER_ROLE();

        bool governorHasManager = registry.hasRole(INSTRUMENT_MANAGER_ROLE, GOVERNOR);
        bool superGovHasAdmin = registry.hasRole(DEFAULT_ADMIN_ROLE, superGovernor);
        bool deployerHasNone =
            !registry.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER) && !registry.hasRole(INSTRUMENT_MANAGER_ROLE, DEPLOYER);

        return governorHasManager && superGovHasAdmin && deployerHasNone;
    }
}
