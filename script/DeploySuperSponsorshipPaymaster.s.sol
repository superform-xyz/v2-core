// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { DeployV2Base } from "./DeployV2Base.s.sol";
import { DeterministicDeployerLib } from "../src/vendor/nexus/DeterministicDeployerLib.sol";
import { SuperSponsorshipPaymaster } from "../src/paymaster/SuperSponsorshipPaymaster.sol";
import { console2 } from "forge-std/console2.sol";

/// @title DeploySuperSponsorshipPaymaster
/// @notice Deployment script for SuperSponsorshipPaymaster - per-strategy gas sponsorship budgets
/// @dev Deploys across multiple chains with deterministic addresses
/// @dev Initially grants all roles to PAYMASTER_ADMIN for operational flexibility, then transfers to SUPER_GOVERNOR
/// later
contract DeploySuperSponsorshipPaymaster is DeployV2Base {
    /// @notice Admin address for the SuperSponsorshipPaymaster
    address internal constant PAYMASTER_ADMIN = 0x22BC97cFac64D6d9BCaDF5dC36e4D01Db9e929c5;

    /// @notice Flare-specific Super Governor address
    address internal constant FLARE_SUPER_GOVERNOR = 0x0f0Db7CEDD49587D78d67175Ff59Ed7069A35874;

    /*//////////////////////////////////////////////////////////////
                            MAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploy SuperSponsorshipPaymaster on a single chain
    /// @dev Grants all roles (DEFAULT_ADMIN_ROLE, FUNDING_ROLE, MANAGER_ROLE) to PAYMASTER_ADMIN
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainId Chain ID to deploy on
    /// @param branchName Branch name for vnet deployments (required when env == 1, ignored otherwise)
    function run(uint256 env, uint64 chainId, string calldata branchName) external broadcast(env) {
        _validateEnvAndBranchName(env, branchName);
        _setBaseConfiguration(env, branchName);

        // Use PAYMASTER_ADMIN - will be transferred to SUPER_GOVERNOR_ADDRESS later
        address admin = PAYMASTER_ADMIN;

        _deploy(env, chainId, admin, branchName);
    }

    /// @notice Deploy SuperSponsorshipPaymaster on multiple chains
    /// @dev Grants all roles (DEFAULT_ADMIN_ROLE, FUNDING_ROLE, MANAGER_ROLE) to PAYMASTER_ADMIN
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainIds Array of chain IDs to deploy on
    /// @param branchName Branch name for vnet deployments (required when env == 1, ignored otherwise)
    function runMultiChain(
        uint256 env,
        uint64[] calldata chainIds,
        string calldata branchName
    )
        external
        broadcast(env)
    {
        _validateEnvAndBranchName(env, branchName);
        _setBaseConfiguration(env, branchName);

        // Use PAYMASTER_ADMIN - will be transferred to SUPER_GOVERNOR_ADDRESS later
        address admin = PAYMASTER_ADMIN;

        console2.log("====== Deploying SuperSponsorshipPaymaster (Multi-Chain) ======");
        console2.log("Environment:", env);
        if (env == 1) {
            console2.log("Branch Name:", branchName);
        }
        console2.log("Admin (PAYMASTER_ADMIN):", admin);
        console2.log("EntryPoint:", ENTRY_POINT);
        console2.log("Number of chains:", chainIds.length);
        console2.log("");

        for (uint256 i = 0; i < chainIds.length; i++) {
            _deploy(env, chainIds[i], admin, branchName);
            console2.log("");
        }

        console2.log("====== Multi-Chain Deployment Complete ======");
    }

    /// @notice Check if SuperSponsorshipPaymaster is deployed
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainId Chain ID to check
    /// @param branchName Branch name for vnet deployments (required when env == 1, ignored otherwise)
    function runCheck(uint256 env, uint64 chainId, string calldata branchName) external broadcast(env) {
        _validateEnvAndBranchName(env, branchName);
        _setBaseConfiguration(env, branchName);

        address admin = PAYMASTER_ADMIN;

        console2.log("====== SuperSponsorshipPaymaster Deployment Check ======");
        console2.log("Chain ID:", chainId);
        console2.log("Environment:", env);
        if (env == 1) {
            console2.log("Branch Name:", branchName);
        }
        console2.log("Admin (PAYMASTER_ADMIN):", admin);
        console2.log("EntryPoint:", ENTRY_POINT);

        address superGovernor = _getSuperGovernor(chainId);
        console2.log("SUPER_GOVERNOR:", superGovernor);
        console2.log("");

        address paymasterAddr = _computePaymasterAddress(env, admin);
        bool isDeployed = paymasterAddr.code.length > 0;

        console2.log("Computed address:", paymasterAddr);
        console2.log("Is deployed:", isDeployed);

        if (isDeployed) {
            SuperSponsorshipPaymaster pm = SuperSponsorshipPaymaster(payable(paymasterAddr));
            console2.log("");
            console2.log("=== Paymaster Role Status ===");
            console2.log("PAYMASTER_ADMIN has DEFAULT_ADMIN_ROLE:", pm.hasRole(pm.DEFAULT_ADMIN_ROLE(), admin));
            console2.log("PAYMASTER_ADMIN has FUNDING_ROLE:", pm.hasRole(pm.FUNDING_ROLE(), admin));
            console2.log("PAYMASTER_ADMIN has MANAGER_ROLE:", pm.hasRole(pm.MANAGER_ROLE(), admin));
            console2.log("");
            console2.log(
                "SUPER_GOVERNOR has DEFAULT_ADMIN_ROLE:", pm.hasRole(pm.DEFAULT_ADMIN_ROLE(), superGovernor)
            );
            console2.log("SUPER_GOVERNOR has FUNDING_ROLE:", pm.hasRole(pm.FUNDING_ROLE(), superGovernor));
            console2.log("SUPER_GOVERNOR has MANAGER_ROLE:", pm.hasRole(pm.MANAGER_ROLE(), superGovernor));
            console2.log("");
            console2.log("EntryPoint:", address(pm.entryPoint()));
            console2.log("Global Paused:", pm.globalPaused());
            console2.log("PostOp Gas Overhead:", pm.postOpGasOverhead());
            console2.log("Total Allocated:", pm.totalAllocated());
            console2.log("EP Deposit:", pm.getDeposit());
        }

        console2.log("");
        console2.log("====== Check Complete ======");
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal deployment function
    /// @dev Grants all roles (DEFAULT_ADMIN_ROLE, FUNDING_ROLE, MANAGER_ROLE) to admin
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainId Chain ID to deploy on
    /// @param admin Admin address (PAYMASTER_ADMIN)
    /// @param branchName Branch name for vnet deployments
    function _deploy(uint256 env, uint64 chainId, address admin, string calldata branchName) internal {
        console2.log("====== Deploying SuperSponsorshipPaymaster ======");
        console2.log("Chain ID:", chainId);
        console2.log("Environment:", env);
        if (env == 1) {
            console2.log("Branch Name:", branchName);
        }
        console2.log("Admin (PAYMASTER_ADMIN):", admin);
        console2.log("EntryPoint:", ENTRY_POINT);
        console2.log("");

        // Validate inputs
        require(admin != address(0), "INVALID_ADMIN");

        // Get bytecode from generated artifacts
        bytes memory bytecode = __getBytecode(SUPER_SPONSORSHIP_PAYMASTER_KEY, env);
        require(bytecode.length > 0, "BYTECODE_NOT_FOUND");

        // Deploy - constructor grants DEFAULT_ADMIN_ROLE, FUNDING_ROLE, MANAGER_ROLE to admin
        // Constructor args: (IEntryPoint entryPoint_, address admin_)
        address paymasterAddr = __deployContract(
            SUPER_SPONSORSHIP_PAYMASTER_KEY,
            chainId,
            __getSalt(SUPER_SPONSORSHIP_PAYMASTER_KEY),
            abi.encodePacked(bytecode, abi.encode(ENTRY_POINT, admin))
        );

        // Verify deployment
        SuperSponsorshipPaymaster pm = SuperSponsorshipPaymaster(payable(paymasterAddr));
        require(pm.hasRole(pm.DEFAULT_ADMIN_ROLE(), admin), "ADMIN_ROLE_MISMATCH");
        require(pm.hasRole(pm.FUNDING_ROLE(), admin), "FUNDING_ROLE_MISMATCH");
        require(pm.hasRole(pm.MANAGER_ROLE(), admin), "MANAGER_ROLE_MISMATCH");
        require(address(pm.entryPoint()) == ENTRY_POINT, "ENTRYPOINT_MISMATCH");

        console2.log("");
        console2.log("=== Deployment Verification ===");
        console2.log("SuperSponsorshipPaymaster deployed at:", paymasterAddr);
        console2.log("Admin verified:", admin);
        console2.log("EntryPoint verified:", ENTRY_POINT);
        console2.log("Has DEFAULT_ADMIN_ROLE:", true);
        console2.log("Has FUNDING_ROLE:", true);
        console2.log("Has MANAGER_ROLE:", true);

        // Write JSON output
        _writePaymasterJson(env, chainId, paymasterAddr, branchName);

        console2.log("");
        console2.log("====== Deployment Complete ======");
    }

    /// @notice Compute the deterministic address for SuperSponsorshipPaymaster
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param admin Admin address used during deployment
    /// @return The computed deterministic address
    function _computePaymasterAddress(uint256 env, address admin) internal view returns (address) {
        bytes memory bytecode = __getBytecode(SUPER_SPONSORSHIP_PAYMASTER_KEY, env);
        require(bytecode.length > 0, "BYTECODE_NOT_FOUND");
        return DeterministicDeployerLib.computeAddress(
            abi.encodePacked(bytecode, abi.encode(ENTRY_POINT, admin)),
            __getSalt(SUPER_SPONSORSHIP_PAYMASTER_KEY)
        );
    }

    /// @notice Merge SuperSponsorshipPaymaster address into {ChainName}-latest.json
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainId Chain ID
    /// @param paymasterAddr Deployed paymaster address
    /// @param branchName Branch name for vnet deployments
    function _writePaymasterJson(
        uint256 env,
        uint64 chainId,
        address paymasterAddr,
        string calldata branchName
    )
        internal
    {
        string memory root = vm.projectRoot();
        string memory envFolder;
        if (env == 0) {
            envFolder = "prod";
        } else if (env == 1) {
            envFolder = branchName;
        } else {
            envFolder = "staging";
        }

        string memory chainName = chainNames[chainId];
        string memory outputFolder =
            string(abi.encodePacked(root, "/script/output/", envFolder, "/", vm.toString(uint256(chainId)), "/"));

        // Create directory if it doesn't exist
        vm.createDir(outputFolder, true);

        string memory outputPath = string(abi.encodePacked(outputFolder, chainName, "-latest.json"));

        // Check if file exists - vm.writeJson with path selector requires existing file
        if (!vm.exists(outputPath)) {
            vm.writeJson("{}", outputPath);
        }

        // Merge SuperSponsorshipPaymaster address into existing JSON
        vm.writeJson(vm.toString(paymasterAddr), outputPath, ".SuperSponsorshipPaymaster");

        console2.log("");
        console2.log("SuperSponsorshipPaymaster merged into:", outputPath);
    }

    /// @notice Returns the Super Governor address for a given chain
    /// @param chainId Chain ID
    /// @return The Super Governor address (Flare-specific or default)
    function _getSuperGovernor(uint64 chainId) internal pure returns (address) {
        if (chainId == FLARE_CHAIN_ID) {
            return FLARE_SUPER_GOVERNOR;
        }
        return SUPER_GOVERNOR_ADDRESS;
    }
}
