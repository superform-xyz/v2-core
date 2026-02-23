// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { PendlePTAmortizedOracleV2ScriptBase } from "./PendlePTAmortizedOracleV2ScriptBase.s.sol";
import { PendlePTAmortizedOracleV2 } from "../src/accounting/oracles/PendlePTAmortizedOracleV2.sol";
import { console2 } from "forge-std/console2.sol";

/// @title DeployPendlePTAmortizedOracleV2
/// @notice Deployment script for PendlePTAmortizedOracleV2 - amortized cost pricing with on-chain PT rate
/// @dev V2 key differences from V1:
///      - recordPurchase calculates sySpent from on-chain PT rate (no off-chain price dependency)
///      - twapDuration passed per-call via hook (no market config storage)
/// @dev Deploys across multiple chains with deterministic addresses
/// @dev Initially grants all roles to DEPLOYER for operational flexibility, then transfers to SUPER_GOVERNOR later
contract DeployPendlePTAmortizedOracleV2 is PendlePTAmortizedOracleV2ScriptBase {
    /*//////////////////////////////////////////////////////////////
                            MAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploy PendlePTAmortizedOracleV2 on a single chain
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
        address superLedgerConfiguration = __computeContractAddress(SUPER_LEDGER_CONFIGURATION_KEY, "");
        require(superLedgerConfiguration != address(0), "SUPER_LEDGER_CONFIG_NOT_SET");
        require(superLedgerConfiguration.code.length > 0, "SUPER_LEDGER_CONFIG_NOT_DEPLOYED");

        _deploy(env, chainId, admin, superLedgerConfiguration, branchName);
    }

    /// @notice Deploy PendlePTAmortizedOracleV2 on multiple chains
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
        address superLedgerConfiguration = __computeContractAddress(SUPER_LEDGER_CONFIGURATION_KEY, "");
        require(superLedgerConfiguration != address(0), "SUPER_LEDGER_CONFIG_NOT_SET");
        require(superLedgerConfiguration.code.length > 0, "SUPER_LEDGER_CONFIG_NOT_DEPLOYED");

        console2.log("====== Deploying PendlePTAmortizedOracleV2 (Multi-Chain) ======");
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

    /// @notice Check if PendlePTAmortizedOracleV2 is deployed
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainId Chain ID to check
    /// @param branchName Branch name for vnet deployments (required when env == 1, ignored otherwise)
    function runCheck(uint256 env, uint64 chainId, string calldata branchName) external broadcast(env) {
        _validateEnvAndBranchName(env, branchName);
        _setBaseConfiguration(env, branchName);

        // Check with DEPLOYER as admin (initial deployment)
        address admin = DEPLOYER;
        // Compute SuperLedgerConfiguration address from core contracts
        address superLedgerConfiguration = __computeContractAddress(SUPER_LEDGER_CONFIGURATION_KEY, "");
        require(superLedgerConfiguration != address(0), "SUPER_LEDGER_CONFIG_NOT_SET");

        console2.log("====== PendlePTAmortizedOracleV2 Deployment Check ======");
        console2.log("Chain ID:", chainId);
        console2.log("Environment:", env);
        if (env == 1) {
            console2.log("Branch Name:", branchName);
        }
        console2.log("Admin (DEPLOYER):", admin);
        console2.log("SuperLedgerConfiguration:", superLedgerConfiguration);
        console2.log("SUPER_GOVERNOR_ADDRESS:", SUPER_GOVERNOR_ADDRESS);
        console2.log("");

        address oracleAddr = _computeOracleV2Address(env, admin, superLedgerConfiguration);
        bool isDeployed = oracleAddr.code.length > 0;

        console2.log("Computed address:", oracleAddr);
        console2.log("Is deployed:", isDeployed);

        if (isDeployed) {
            PendlePTAmortizedOracleV2 oracle = PendlePTAmortizedOracleV2(oracleAddr);
            console2.log("");
            console2.log("=== Oracle V2 Role Status ===");
            console2.log("DEPLOYER has DEFAULT_ADMIN_ROLE:", oracle.hasRole(oracle.DEFAULT_ADMIN_ROLE(), admin));
            console2.log("DEPLOYER has MANAGER_ROLE:", oracle.hasRole(oracle.MANAGER_ROLE(), admin));
            console2.log("");
            console2.log("SUPER_GOVERNOR has DEFAULT_ADMIN_ROLE:", oracle.hasRole(oracle.DEFAULT_ADMIN_ROLE(), SUPER_GOVERNOR_ADDRESS));
            console2.log("SUPER_GOVERNOR has MANAGER_ROLE:", oracle.hasRole(oracle.MANAGER_ROLE(), SUPER_GOVERNOR_ADDRESS));
            console2.log("");
            console2.log("SUPER_LEDGER_CONFIGURATION:", oracle.SUPER_LEDGER_CONFIGURATION());
            console2.log("DEFAULT_TWAP_DURATION:", oracle.DEFAULT_TWAP_DURATION());
            console2.log("DEFAULT_MIN_TWAP_DURATION:", oracle.DEFAULT_MIN_TWAP_DURATION());
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
        console2.log("====== Deploying PendlePTAmortizedOracleV2 ======");
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
        bytes memory bytecode = __getBytecode(ORACLE_V2_KEY, env);
        require(bytecode.length > 0, "BYTECODE_NOT_FOUND");

        // Deploy - constructor grants DEFAULT_ADMIN_ROLE and MANAGER_ROLE to admin
        address oracleAddr = __deployContract(
            ORACLE_V2_KEY,
            chainId,
            __getSalt(ORACLE_V2_KEY),
            abi.encodePacked(bytecode, abi.encode(admin, superLedgerConfiguration))
        );

        // Verify deployment
        PendlePTAmortizedOracleV2 oracle = PendlePTAmortizedOracleV2(oracleAddr);
        require(oracle.hasRole(oracle.DEFAULT_ADMIN_ROLE(), admin), "ADMIN_ROLE_MISMATCH");
        require(oracle.hasRole(oracle.MANAGER_ROLE(), admin), "MANAGER_ROLE_MISMATCH");
        require(oracle.SUPER_LEDGER_CONFIGURATION() == superLedgerConfiguration, "SUPER_LEDGER_CONFIG_MISMATCH");

        console2.log("");
        console2.log("=== Deployment Verification ===");
        console2.log("PendlePTAmortizedOracleV2 deployed at:", oracleAddr);
        console2.log("Admin verified:", admin);
        console2.log("SuperLedgerConfiguration verified:", superLedgerConfiguration);
        console2.log("Has DEFAULT_ADMIN_ROLE:", true);
        console2.log("Has MANAGER_ROLE:", true);
        console2.log("DEFAULT_TWAP_DURATION:", oracle.DEFAULT_TWAP_DURATION());
        console2.log("DEFAULT_MIN_TWAP_DURATION:", oracle.DEFAULT_MIN_TWAP_DURATION());

        // Write JSON output
        _writeOracleV2Json(env, chainId, oracleAddr, branchName);

        console2.log("");
        console2.log("====== Deployment Complete ======");
    }

    /// @notice Merge PendlePTAmortizedOracleV2 address into {ChainName}-latest.json
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainId Chain ID
    /// @param oracleAddr Deployed oracle address
    /// @param branchName Branch name for vnet deployments
    function _writeOracleV2Json(
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

        // Merge PendlePTAmortizedOracleV2 address into existing JSON
        // vm.writeJson with path selector will create file if it doesn't exist or update existing
        vm.writeJson(vm.toString(oracleAddr), outputPath, ".PendlePTAmortizedOracleV2");

        console2.log("");
        console2.log("PendlePTAmortizedOracleV2 merged into:", outputPath);
    }
}
