// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { DeployV2Base } from "./DeployV2Base.s.sol";
import { YoYieldSourceOracle } from "../src/accounting/oracles/YoYieldSourceOracle.sol";
import { DeterministicDeployerLib } from "../src/vendor/nexus/DeterministicDeployerLib.sol";
import { console2 } from "forge-std/console2.sol";

/// @title DeployYoYieldSourceOracle
/// @notice Deployment script for YoYieldSourceOracle - Oracle for Yo Vaults with async redemption support
/// @dev Deploys across multiple chains with deterministic addresses
contract DeployYoYieldSourceOracle is DeployV2Base {
    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    string internal constant ORACLE_KEY = "YoYieldSourceOracle";

    /*//////////////////////////////////////////////////////////////
                            MAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploy YoYieldSourceOracle on a single chain
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainId Chain ID to deploy on
    /// @param branchName Branch name for vnet deployments (required when env == 1, ignored otherwise)
    function run(uint256 env, uint64 chainId, string calldata branchName) external broadcast(env) {
        _validateEnvAndBranchName(env, branchName);
        _setBaseConfiguration(env, branchName);

        // Compute SuperLedgerConfiguration address from core contracts
        address superLedgerConfiguration = __computeContractAddress(SUPER_LEDGER_CONFIGURATION_KEY, "", env);
        require(superLedgerConfiguration != address(0), "SUPER_LEDGER_CONFIG_NOT_SET");
        require(superLedgerConfiguration.code.length > 0, "SUPER_LEDGER_CONFIG_NOT_DEPLOYED");

        _deploy(env, chainId, superLedgerConfiguration, branchName);
    }

    /// @notice Deploy YoYieldSourceOracle on multiple chains
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainIds Array of chain IDs to deploy on
    /// @param branchName Branch name for vnet deployments (required when env == 1, ignored otherwise)
    function runMultiChain(uint256 env, uint64[] calldata chainIds, string calldata branchName) external broadcast(env) {
        _validateEnvAndBranchName(env, branchName);
        _setBaseConfiguration(env, branchName);

        // Compute SuperLedgerConfiguration address from core contracts
        address superLedgerConfiguration = __computeContractAddress(SUPER_LEDGER_CONFIGURATION_KEY, "", env);
        require(superLedgerConfiguration != address(0), "SUPER_LEDGER_CONFIG_NOT_SET");
        require(superLedgerConfiguration.code.length > 0, "SUPER_LEDGER_CONFIG_NOT_DEPLOYED");

        console2.log("====== Deploying YoYieldSourceOracle (Multi-Chain) ======");
        console2.log("Environment:", env);
        if (env == 1) {
            console2.log("Branch Name:", branchName);
        }
        console2.log("SuperLedgerConfiguration:", superLedgerConfiguration);
        console2.log("Number of chains:", chainIds.length);
        console2.log("");

        for (uint256 i = 0; i < chainIds.length; i++) {
            _deploy(env, chainIds[i], superLedgerConfiguration, branchName);
            console2.log("");
        }

        console2.log("====== Multi-Chain Deployment Complete ======");
    }

    /// @notice Check if YoYieldSourceOracle is deployed
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainId Chain ID to check
    /// @param branchName Branch name for vnet deployments (required when env == 1, ignored otherwise)
    function runCheck(uint256 env, uint64 chainId, string calldata branchName) external broadcast(env) {
        _validateEnvAndBranchName(env, branchName);
        _setBaseConfiguration(env, branchName);

        // Compute SuperLedgerConfiguration address from core contracts
        address superLedgerConfiguration = __computeContractAddress(SUPER_LEDGER_CONFIGURATION_KEY, "", env);
        require(superLedgerConfiguration != address(0), "SUPER_LEDGER_CONFIG_NOT_SET");

        console2.log("====== YoYieldSourceOracle Deployment Check ======");
        console2.log("Chain ID:", chainId);
        console2.log("Environment:", env);
        if (env == 1) {
            console2.log("Branch Name:", branchName);
        }
        console2.log("SuperLedgerConfiguration:", superLedgerConfiguration);
        console2.log("");

        address oracleAddr = _computeOracleAddress(env, superLedgerConfiguration);
        bool isDeployed = oracleAddr.code.length > 0;

        console2.log("Computed address:", oracleAddr);
        console2.log("Is deployed:", isDeployed);

        if (isDeployed) {
            YoYieldSourceOracle oracle = YoYieldSourceOracle(oracleAddr);
            console2.log("");
            console2.log("=== Oracle Configuration ===");
            console2.log("SUPER_LEDGER_CONFIGURATION:", oracle.SUPER_LEDGER_CONFIGURATION());
        }

        console2.log("");
        console2.log("====== Check Complete ======");
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal deployment function
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainId Chain ID to deploy on
    /// @param superLedgerConfiguration SuperLedgerConfiguration address
    /// @param branchName Branch name for vnet deployments
    function _deploy(
        uint256 env,
        uint64 chainId,
        address superLedgerConfiguration,
        string calldata branchName
    )
        internal
    {
        console2.log("====== Deploying YoYieldSourceOracle ======");
        console2.log("Chain ID:", chainId);
        console2.log("Environment:", env);
        if (env == 1) {
            console2.log("Branch Name:", branchName);
        }
        console2.log("SuperLedgerConfiguration:", superLedgerConfiguration);
        console2.log("");

        // Validate inputs
        require(superLedgerConfiguration != address(0), "INVALID_SUPER_LEDGER_CONFIG");

        // Get bytecode from generated artifacts
        bytes memory bytecode = __getBytecode(ORACLE_KEY, env);
        require(bytecode.length > 0, "BYTECODE_NOT_FOUND");

        // Deploy - constructor takes only superLedgerConfiguration
        address oracleAddr = __deployContract(
            ORACLE_KEY,
            chainId,
            __getSalt(ORACLE_KEY),
            abi.encodePacked(bytecode, abi.encode(superLedgerConfiguration))
        );

        // Verify deployment
        YoYieldSourceOracle oracle = YoYieldSourceOracle(oracleAddr);
        require(oracle.SUPER_LEDGER_CONFIGURATION() == superLedgerConfiguration, "SUPER_LEDGER_CONFIG_MISMATCH");

        console2.log("");
        console2.log("=== Deployment Verification ===");
        console2.log("YoYieldSourceOracle deployed at:", oracleAddr);
        console2.log("SuperLedgerConfiguration verified:", superLedgerConfiguration);

        // Write JSON output
        _writeOracleJson(env, chainId, oracleAddr, branchName);

        console2.log("");
        console2.log("====== Deployment Complete ======");
    }

    /// @notice Compute the deterministic address of the oracle
    /// @param env Environment
    /// @param superLedgerConfiguration SuperLedgerConfiguration address
    /// @return oracleAddr Computed oracle address
    function _computeOracleAddress(
        uint256 env,
        address superLedgerConfiguration
    )
        internal
        view
        returns (address oracleAddr)
    {
        bytes memory bytecode = __getBytecode(ORACLE_KEY, env);
        bytes memory args = abi.encode(superLedgerConfiguration);
        bytes32 salt = __getSalt(ORACLE_KEY);

        bytes memory creationCode = abi.encodePacked(bytecode, args);
        oracleAddr = DeterministicDeployerLib.computeAddress(creationCode, salt);
    }

    /// @notice Merge YoYieldSourceOracle address into {ChainName}-latest.json
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

        // Merge YoYieldSourceOracle address into existing JSON
        // vm.writeJson with path selector will create file if it doesn't exist or update existing
        vm.writeJson(vm.toString(oracleAddr), outputPath, ".YoYieldSourceOracle");

        console2.log("");
        console2.log("YoYieldSourceOracle merged into:", outputPath);
    }
}
