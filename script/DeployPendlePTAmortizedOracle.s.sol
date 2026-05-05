// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { PendlePTAmortizedOracleScriptBase } from "./PendlePTAmortizedOracleScriptBase.s.sol";
import { PendlePTAmortizedOracle } from "../src/accounting/oracles/PendlePTAmortizedOracle.sol";
import { console2 } from "forge-std/console2.sol";

/// @title DeployPendlePTAmortizedOracle
/// @notice Deployment script for PendlePTAmortizedOracle - amortized cost pricing for Pendle PT positions
/// @dev Deploys across multiple chains with deterministic addresses
/// @dev Initially grants all roles to DEPLOYER for operational flexibility, then transfers to SUPER_GOVERNOR later
contract DeployPendlePTAmortizedOracle is PendlePTAmortizedOracleScriptBase {
    /*//////////////////////////////////////////////////////////////
                            MAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploy PendlePTAmortizedOracle on a single chain
    /// @dev Grants all roles (DEFAULT_ADMIN_ROLE, MANAGER_ROLE) to DEPLOYER
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainId Chain ID to deploy on
    /// @param branchName Branch name for vnet deployments (required when env == 1, ignored otherwise)
    function run(uint256 env, uint64 chainId, string calldata branchName) external broadcast(env) {
        _validateEnvAndBranchName(env, branchName);
        _setBaseConfiguration(env, branchName);

        // Use DEPLOYER as admin - will be transferred to SUPER_GOVERNOR_ADDRESS later
        address admin = DEPLOYER;
        // Compute SuperLedgerConfiguration address from core contracts
        address superLedgerConfiguration = __computeContractAddress(SUPER_LEDGER_CONFIGURATION_KEY, "", env);
        require(superLedgerConfiguration != address(0), "SUPER_LEDGER_CONFIG_NOT_SET");
        require(superLedgerConfiguration.code.length > 0, "SUPER_LEDGER_CONFIG_NOT_DEPLOYED");

        _deploy(env, chainId, admin, superLedgerConfiguration, branchName);
    }

    /// @notice Deploy PendlePTAmortizedOracle on multiple chains
    /// @dev Grants all roles (DEFAULT_ADMIN_ROLE, MANAGER_ROLE) to DEPLOYER
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainIds Array of chain IDs to deploy on
    /// @param branchName Branch name for vnet deployments (required when env == 1, ignored otherwise)
    function runMultiChain(uint256 env, uint64[] calldata chainIds, string calldata branchName) external broadcast(env) {
        _validateEnvAndBranchName(env, branchName);
        _setBaseConfiguration(env, branchName);

        // Use DEPLOYER as admin - will be transferred to SUPER_GOVERNOR_ADDRESS later
        address admin = DEPLOYER;
        // Compute SuperLedgerConfiguration address from core contracts
        address superLedgerConfiguration = __computeContractAddress(SUPER_LEDGER_CONFIGURATION_KEY, "", env);
        require(superLedgerConfiguration != address(0), "SUPER_LEDGER_CONFIG_NOT_SET");
        require(superLedgerConfiguration.code.length > 0, "SUPER_LEDGER_CONFIG_NOT_DEPLOYED");

        console2.log("====== Deploying PendlePTAmortizedOracle (Multi-Chain) ======");
        console2.log("Environment:", env);
        if (env == 1) {
            console2.log("Branch Name:", branchName);
        }
        console2.log("Admin (DEPLOYER):", admin);
        console2.log("SuperLedgerConfiguration:", superLedgerConfiguration);
        console2.log("Number of chains:", chainIds.length);
        console2.log("");

        for (uint256 i = 0; i < chainIds.length; i++) {
            _deploy(env, chainIds[i], admin, superLedgerConfiguration, branchName);
            console2.log("");
        }

        console2.log("====== Multi-Chain Deployment Complete ======");
    }

    /// @notice Check if PendlePTAmortizedOracle is deployed
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainId Chain ID to check
    /// @param branchName Branch name for vnet deployments (required when env == 1, ignored otherwise)
    function runCheck(uint256 env, uint64 chainId, string calldata branchName) external broadcast(env) {
        _validateEnvAndBranchName(env, branchName);
        _setBaseConfiguration(env, branchName);

        // Check with DEPLOYER as admin (initial deployment)
        address admin = DEPLOYER;
        // Compute SuperLedgerConfiguration address from core contracts
        address superLedgerConfiguration = __computeContractAddress(SUPER_LEDGER_CONFIGURATION_KEY, "", env);
        require(superLedgerConfiguration != address(0), "SUPER_LEDGER_CONFIG_NOT_SET");

        console2.log("====== PendlePTAmortizedOracle Deployment Check ======");
        console2.log("Chain ID:", chainId);
        console2.log("Environment:", env);
        if (env == 1) {
            console2.log("Branch Name:", branchName);
        }
        console2.log("Admin (DEPLOYER):", admin);
        console2.log("SuperLedgerConfiguration:", superLedgerConfiguration);
        console2.log("SUPER_GOVERNOR_ADDRESS:", SUPER_GOVERNOR_ADDRESS);
        console2.log("");

        address oracleAddr = _computeOracleAddress(env, admin, superLedgerConfiguration);
        bool isDeployed = oracleAddr.code.length > 0;

        console2.log("Computed address:", oracleAddr);
        console2.log("Is deployed:", isDeployed);

        if (isDeployed) {
            PendlePTAmortizedOracle oracle = PendlePTAmortizedOracle(oracleAddr);
            console2.log("");
            console2.log("=== Oracle Role Status ===");
            console2.log("DEPLOYER has DEFAULT_ADMIN_ROLE:", oracle.hasRole(oracle.DEFAULT_ADMIN_ROLE(), admin));
            console2.log("DEPLOYER has MANAGER_ROLE:", oracle.hasRole(oracle.MANAGER_ROLE(), admin));
            console2.log("");
            console2.log("SUPER_GOVERNOR has DEFAULT_ADMIN_ROLE:", oracle.hasRole(oracle.DEFAULT_ADMIN_ROLE(), SUPER_GOVERNOR_ADDRESS));
            console2.log("SUPER_GOVERNOR has MANAGER_ROLE:", oracle.hasRole(oracle.MANAGER_ROLE(), SUPER_GOVERNOR_ADDRESS));
            console2.log("");
            console2.log("SUPER_LEDGER_CONFIGURATION:", oracle.SUPER_LEDGER_CONFIGURATION());
        }

        console2.log("");
        console2.log("====== Check Complete ======");
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal deployment function
    /// @dev Grants all roles (DEFAULT_ADMIN_ROLE, MANAGER_ROLE) to admin
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainId Chain ID to deploy on
    /// @param admin Admin address (DEPLOYER)
    /// @param superLedgerConfiguration SuperLedgerConfiguration address
    /// @param branchName Branch name for vnet deployments
    function _deploy(
        uint256 env,
        uint64 chainId,
        address admin,
        address superLedgerConfiguration,
        string calldata branchName
    )
        internal
    {
        console2.log("====== Deploying PendlePTAmortizedOracle ======");
        console2.log("Chain ID:", chainId);
        console2.log("Environment:", env);
        if (env == 1) {
            console2.log("Branch Name:", branchName);
        }
        console2.log("Admin (DEPLOYER):", admin);
        console2.log("SuperLedgerConfiguration:", superLedgerConfiguration);
        console2.log("");

        // Validate inputs
        require(admin != address(0), "INVALID_ADMIN");
        require(superLedgerConfiguration != address(0), "INVALID_SUPER_LEDGER_CONFIG");

        // Get bytecode from generated artifacts
        bytes memory bytecode = __getBytecode(ORACLE_KEY, env);
        require(bytecode.length > 0, "BYTECODE_NOT_FOUND");

        // Deploy - constructor grants DEFAULT_ADMIN_ROLE and MANAGER_ROLE to admin
        address oracleAddr = __deployContract(
            ORACLE_KEY,
            chainId,
            __getSalt(ORACLE_KEY),
            abi.encodePacked(bytecode, abi.encode(admin, superLedgerConfiguration))
        );

        // Verify deployment
        PendlePTAmortizedOracle oracle = PendlePTAmortizedOracle(oracleAddr);
        require(oracle.hasRole(oracle.DEFAULT_ADMIN_ROLE(), admin), "ADMIN_ROLE_MISMATCH");
        require(oracle.hasRole(oracle.MANAGER_ROLE(), admin), "MANAGER_ROLE_MISMATCH");
        require(oracle.SUPER_LEDGER_CONFIGURATION() == superLedgerConfiguration, "SUPER_LEDGER_CONFIG_MISMATCH");

        console2.log("");
        console2.log("=== Deployment Verification ===");
        console2.log("PendlePTAmortizedOracle deployed at:", oracleAddr);
        console2.log("Admin verified:", admin);
        console2.log("SuperLedgerConfiguration verified:", superLedgerConfiguration);
        console2.log("Has DEFAULT_ADMIN_ROLE:", true);
        console2.log("Has MANAGER_ROLE:", true);

        // Write JSON output
        _writeOracleJson(env, chainId, oracleAddr, branchName);

        console2.log("");
        console2.log("====== Deployment Complete ======");
    }

    /// @notice Merge PendlePTAmortizedOracle address into {ChainName}-latest.json
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainId Chain ID
    /// @param oracleAddr Deployed oracle address
    /// @param branchName Branch name for vnet deployments
    function _writeOracleJson(
        uint256 env,
        uint64 chainId,
        address oracleAddr,
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
            // Create new JSON file with just this oracle
            vm.writeJson("{}", outputPath);
        }

        // Merge PendlePTAmortizedOracle address into existing JSON
        vm.writeJson(vm.toString(oracleAddr), outputPath, ".PendlePTAmortizedOracle");

        console2.log("");
        console2.log("PendlePTAmortizedOracle merged into:", outputPath);
    }
}
