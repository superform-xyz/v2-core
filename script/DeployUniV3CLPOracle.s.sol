// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { DeployV2Base } from "./DeployV2Base.s.sol";
import { UniV3CLPRegistry } from "../src/accounting/oracles/UniV3CLPRegistry.sol";
import { UniV3CLPYieldSourceOracle } from "../src/accounting/oracles/UniV3CLPYieldSourceOracle.sol";
import { DeterministicDeployerLib } from "../src/vendor/nexus/DeterministicDeployerLib.sol";
import { console2 } from "forge-std/console2.sol";

/// @title DeployUniV3CLPOracle
/// @notice Deployment script for UniV3CLPRegistry + UniV3CLPYieldSourceOracle
/// @dev Deploys across multiple chains with deterministic addresses.
///      Registry deploys first with (admin), oracle deploys second with (superLedgerConfig, registryAddress).
contract DeployUniV3CLPOracle is DeployV2Base {
    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    string internal constant REGISTRY_KEY = "UniV3CLPRegistry";
    string internal constant ORACLE_KEY = "UniV3CLPYieldSourceOracle";

    /*//////////////////////////////////////////////////////////////
                            MAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploy UniV3CLPRegistry + UniV3CLPYieldSourceOracle on a single chain
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

    /// @notice Deploy UniV3CLPRegistry + UniV3CLPYieldSourceOracle on multiple chains
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

        console2.log("====== Deploying UniV3CLP Oracle (Multi-Chain) ======");
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

    /// @notice Check if UniV3CLPRegistry + UniV3CLPYieldSourceOracle are deployed
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainId Chain ID to check
    /// @param branchName Branch name for vnet deployments (required when env == 1, ignored otherwise)
    function runCheck(uint256 env, uint64 chainId, string calldata branchName) external broadcast(env) {
        _validateEnvAndBranchName(env, branchName);
        _setBaseConfiguration(env, branchName);

        // Compute SuperLedgerConfiguration address from core contracts
        address superLedgerConfiguration = __computeContractAddress(SUPER_LEDGER_CONFIGURATION_KEY, "", env);
        require(superLedgerConfiguration != address(0), "SUPER_LEDGER_CONFIG_NOT_SET");

        console2.log("====== UniV3CLP Oracle Deployment Check ======");
        console2.log("Chain ID:", chainId);
        console2.log("Environment:", env);
        if (env == 1) {
            console2.log("Branch Name:", branchName);
        }
        console2.log("SuperLedgerConfiguration:", superLedgerConfiguration);
        console2.log("");

        // Check registry
        address registryAddr = _computeRegistryAddress(env);
        bool registryDeployed = registryAddr.code.length > 0;
        console2.log("=== UniV3CLPRegistry ===");
        console2.log("Computed address:", registryAddr);
        console2.log("Is deployed:", registryDeployed);

        // Check oracle
        address oracleAddr = _computeOracleAddress(env, superLedgerConfiguration, registryAddr);
        bool oracleDeployed = oracleAddr.code.length > 0;
        console2.log("");
        console2.log("=== UniV3CLPYieldSourceOracle ===");
        console2.log("Computed address:", oracleAddr);
        console2.log("Is deployed:", oracleDeployed);

        if (oracleDeployed) {
            UniV3CLPYieldSourceOracle oracle = UniV3CLPYieldSourceOracle(oracleAddr);
            console2.log("");
            console2.log("=== Oracle Configuration ===");
            console2.log("SUPER_LEDGER_CONFIGURATION:", oracle.SUPER_LEDGER_CONFIGURATION());
            console2.log("REGISTRY:", address(oracle.REGISTRY()));
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
        console2.log("====== Deploying UniV3CLP Oracle ======");
        console2.log("Chain ID:", chainId);
        console2.log("Environment:", env);
        if (env == 1) {
            console2.log("Branch Name:", branchName);
        }
        console2.log("SuperLedgerConfiguration:", superLedgerConfiguration);
        console2.log("");

        // Validate inputs
        require(superLedgerConfiguration != address(0), "INVALID_SUPER_LEDGER_CONFIG");

        // --- Deploy Registry ---
        bytes memory registryBytecode = __getBytecode(REGISTRY_KEY, env);
        require(registryBytecode.length > 0, "REGISTRY_BYTECODE_NOT_FOUND");

        address registryAddr = __deployContract(
            REGISTRY_KEY,
            chainId,
            __getSalt(REGISTRY_KEY),
            abi.encodePacked(registryBytecode, abi.encode(DEPLOYER))
        );

        // Verify registry deployment
        UniV3CLPRegistry registry = UniV3CLPRegistry(registryAddr);
        require(
            registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), DEPLOYER), "REGISTRY_ADMIN_ROLE_MISMATCH"
        );
        require(
            registry.hasRole(registry.POSITION_MANAGER_ROLE(), DEPLOYER), "REGISTRY_POSITION_MANAGER_ROLE_MISMATCH"
        );

        console2.log("UniV3CLPRegistry deployed at:", registryAddr);

        // --- Deploy Oracle ---
        bytes memory oracleBytecode = __getBytecode(ORACLE_KEY, env);
        require(oracleBytecode.length > 0, "ORACLE_BYTECODE_NOT_FOUND");

        address oracleAddr = __deployContract(
            ORACLE_KEY,
            chainId,
            __getSalt(ORACLE_KEY),
            abi.encodePacked(oracleBytecode, abi.encode(superLedgerConfiguration, registryAddr))
        );

        // Verify oracle deployment
        UniV3CLPYieldSourceOracle oracle = UniV3CLPYieldSourceOracle(oracleAddr);
        require(oracle.SUPER_LEDGER_CONFIGURATION() == superLedgerConfiguration, "SUPER_LEDGER_CONFIG_MISMATCH");
        require(address(oracle.REGISTRY()) == registryAddr, "REGISTRY_MISMATCH");

        console2.log("UniV3CLPYieldSourceOracle deployed at:", oracleAddr);

        // Write JSON output
        _writeJson(env, chainId, registryAddr, oracleAddr, branchName);

        console2.log("");
        console2.log("====== Deployment Complete ======");
    }

    /// @notice Compute the deterministic address of the registry
    /// @param env Environment
    /// @return registryAddr Computed registry address
    function _computeRegistryAddress(uint256 env) internal view returns (address registryAddr) {
        bytes memory bytecode = __getBytecode(REGISTRY_KEY, env);
        bytes memory args = abi.encode(DEPLOYER);
        bytes32 salt = __getSalt(REGISTRY_KEY);

        bytes memory creationCode = abi.encodePacked(bytecode, args);
        registryAddr = DeterministicDeployerLib.computeAddress(creationCode, salt);
    }

    /// @notice Compute the deterministic address of the oracle
    /// @param env Environment
    /// @param superLedgerConfiguration SuperLedgerConfiguration address
    /// @param registryAddr Registry address
    /// @return oracleAddr Computed oracle address
    function _computeOracleAddress(
        uint256 env,
        address superLedgerConfiguration,
        address registryAddr
    )
        internal
        view
        returns (address oracleAddr)
    {
        bytes memory bytecode = __getBytecode(ORACLE_KEY, env);
        bytes memory args = abi.encode(superLedgerConfiguration, registryAddr);
        bytes32 salt = __getSalt(ORACLE_KEY);

        bytes memory creationCode = abi.encodePacked(bytecode, args);
        oracleAddr = DeterministicDeployerLib.computeAddress(creationCode, salt);
    }

    /// @notice Merge UniV3CLPRegistry and UniV3CLPYieldSourceOracle addresses into {ChainName}-latest.json
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainId Chain ID
    /// @param registryAddr Deployed registry address
    /// @param oracleAddr Deployed oracle address
    /// @param branchName Branch name for vnet deployments
    function _writeJson(
        uint256 env,
        uint64 chainId,
        address registryAddr,
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
            vm.writeJson("{}", outputPath);
        }

        // Merge addresses into existing JSON
        vm.writeJson(vm.toString(registryAddr), outputPath, ".UniV3CLPRegistry");
        vm.writeJson(vm.toString(oracleAddr), outputPath, ".UniV3CLPYieldSourceOracle");

        console2.log("");
        console2.log("UniV3CLPRegistry merged into:", outputPath);
        console2.log("UniV3CLPYieldSourceOracle merged into:", outputPath);
    }
}
