// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.30;

import { DeployV2Core } from "./DeployV2Core.s.sol";
import { ISuperLedgerConfiguration } from "../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { console2 } from "forge-std/console2.sol";

/**
 * @title AddToSuperLedgerConfiguration
 * @notice Script to add new yield source oracles to existing SuperLedger configuration
 * @dev This script allows adding custom oracle configurations with specified salts and addresses
 *      without needing to redeploy the entire system
 */
contract AddToSuperLedgerConfiguration is DeployV2Core {
    /// @notice Add new yield source oracles to SuperLedger configuration with string salts
    /// @dev Reads SuperLedger configuration and other contracts from deployment files
    /// @dev Converts string salts to bytes32 using bytes32(bytes(saltString))
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainId Target chain ID
    /// @param saltStrings Array of salt strings to generate unique identifiers for new oracles
    /// @param oracleAddresses Array of oracle addresses to add
    function run(
        uint256 env,
        uint64 chainId,
        string[] memory saltStrings,
        address[] memory oracleAddresses
    )
        public
        broadcast(env)
    {
        bytes32[] memory salts = _convertStringsToBytes32(saltStrings);
        _addToSuperLedgerConfiguration(env, chainId, "", salts, oracleAddresses);
    }

    /// @notice Add new yield source oracles to SuperLedger configuration (legacy bytes32 version)
    /// @dev Reads SuperLedger configuration and other contracts from deployment files
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainId Target chain ID
    /// @param salts Array of salt values to generate unique identifiers for new oracles
    /// @param oracleAddresses Array of oracle addresses to add
    function run(
        uint256 env,
        uint64 chainId,
        bytes32[] memory salts,
        address[] memory oracleAddresses
    )
        public
        broadcast(env)
    {
        _addToSuperLedgerConfiguration(env, chainId, "", salts, oracleAddresses);
    }

    /// @notice Add new yield source oracles with salt namespace support (string salts)
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainId Target chain ID
    /// @param saltNamespace Salt namespace for configuration
    /// @param saltStrings Array of salt strings to generate unique identifiers for new oracles
    /// @param oracleAddresses Array of oracle addresses to add
    function run(
        uint256 env,
        uint64 chainId,
        string memory saltNamespace,
        string[] memory saltStrings,
        address[] memory oracleAddresses
    )
        public
        broadcast(env)
    {
        bytes32[] memory salts = _convertStringsToBytes32(saltStrings);
        _addToSuperLedgerConfiguration(env, chainId, saltNamespace, salts, oracleAddresses);
    }

    /// @notice Add new yield source oracles with salt namespace support (legacy bytes32 version)
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainId Target chain ID
    /// @param saltNamespace Salt namespace for configuration
    /// @param salts Array of salt values to generate unique identifiers for new oracles
    /// @param oracleAddresses Array of oracle addresses to add
    function run(
        uint256 env,
        uint64 chainId,
        string memory saltNamespace,
        bytes32[] memory salts,
        address[] memory oracleAddresses
    )
        public
        broadcast(env)
    {
        _addToSuperLedgerConfiguration(env, chainId, saltNamespace, salts, oracleAddresses);
    }

    /// @notice Add new yield source oracles with branch name support for VNETs (string salts)
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainId Target chain ID
    /// @param saltNamespace Salt namespace for configuration
    /// @param branchName Branch name for env=1 (VNET) to read contracts from specific branch folder
    /// @param saltStrings Array of salt strings to generate unique identifiers for new oracles
    /// @param oracleAddresses Array of oracle addresses to add
    function run(
        uint256 env,
        uint64 chainId,
        string memory saltNamespace,
        string memory branchName,
        string[] memory saltStrings,
        address[] memory oracleAddresses
    )
        public
        broadcast(env)
    {
        bytes32[] memory salts = _convertStringsToBytes32(saltStrings);
        _addToSuperLedgerConfiguration(env, chainId, saltNamespace, branchName, salts, oracleAddresses);
    }

    /// @notice Add new yield source oracles with branch name support for VNETs (legacy bytes32 version)
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainId Target chain ID
    /// @param saltNamespace Salt namespace for configuration
    /// @param branchName Branch name for env=1 (VNET) to read contracts from specific branch folder
    /// @param salts Array of salt values to generate unique identifiers for new oracles
    /// @param oracleAddresses Array of oracle addresses to add
    function run(
        uint256 env,
        uint64 chainId,
        string memory saltNamespace,
        string memory branchName,
        bytes32[] memory salts,
        address[] memory oracleAddresses
    )
        public
        broadcast(env)
    {
        _addToSuperLedgerConfiguration(env, chainId, saltNamespace, branchName, salts, oracleAddresses);
    }

    /// @notice Internal function to add new yield source oracles to SuperLedger configuration
    /// @dev Reads contract addresses from deployment output files and adds new oracle configurations
    /// @param env Environment for determining output path
    /// @param chainId Target chain ID
    /// @param saltNamespace Salt namespace (can be empty string)
    /// @param salts Array of salt values for new oracle IDs
    /// @param oracleAddresses Array of oracle addresses to configure
    function _addToSuperLedgerConfiguration(
        uint256 env,
        uint64 chainId,
        string memory saltNamespace,
        bytes32[] memory salts,
        address[] memory oracleAddresses
    )
        private
    {
        _addToSuperLedgerConfiguration(env, chainId, saltNamespace, "", salts, oracleAddresses);
    }

    /// @notice Internal function to add new yield source oracles with branch name support
    /// @param env Environment for determining output path
    /// @param chainId Target chain ID
    /// @param saltNamespace Salt namespace (can be empty string)
    /// @param branchName Branch name for VNET environment (can be empty string)
    /// @param salts Array of salt values for new oracle IDs
    /// @param oracleAddresses Array of oracle addresses to configure
    function _addToSuperLedgerConfiguration(
        uint256 env,
        uint64 chainId,
        string memory saltNamespace,
        string memory branchName,
        bytes32[] memory salts,
        address[] memory oracleAddresses
    )
        private
    {
        console2.log("====== ADDING TO SUPERLEDGER CONFIGURATION ======");
        console2.log("Environment:", env == 0 ? "Production" : (env == 1 ? "VNET" : "Staging"));
        console2.log("Chain ID:", chainId);
        if (bytes(saltNamespace).length > 0) {
            console2.log("Salt Namespace:", saltNamespace);
        }
        if (env == 1 && bytes(branchName).length > 0) {
            console2.log("Branch Name:", branchName);
        }
        console2.log("");

        // Set configuration to get correct environment settings
        _setConfiguration(env, saltNamespace);

        // ===== VALIDATE INPUT ARRAYS =====
        require(salts.length > 0, "ADD_TO_LEDGER_CONFIG_EMPTY_SALTS");
        require(oracleAddresses.length > 0, "ADD_TO_LEDGER_CONFIG_EMPTY_ADDRESSES");
        require(salts.length == oracleAddresses.length, "ADD_TO_LEDGER_CONFIG_LENGTH_MISMATCH");

        console2.log("Adding", salts.length, "new oracle configuration(s)");
        console2.log("");

        // ===== READ CONTRACT ADDRESSES FROM DEPLOYMENT FILES =====
        string memory deploymentJson;
        if (bytes(branchName).length > 0) {
            deploymentJson = _readCoreContractsFromOutput(chainId, env, branchName);
        } else {
            deploymentJson = _readCoreContractsFromOutput(chainId, env, "");
        }

        address superLedgerConfig = vm.parseJsonAddress(deploymentJson, ".SuperLedgerConfiguration");
        address superLedger = vm.parseJsonAddress(deploymentJson, ".SuperLedger");
        address flatFeeLedger = vm.parseJsonAddress(deploymentJson, ".FlatFeeLedger");

        // ===== VALIDATE REQUIRED CONTRACTS =====
        require(superLedgerConfig != address(0), "ADD_TO_LEDGER_CONFIG_ZERO");
        require(superLedgerConfig.code.length > 0, "ADD_TO_LEDGER_CONFIG_NO_CODE");

        require(superLedger != address(0), "ADD_TO_LEDGER_SUPER_LEDGER_ZERO");
        require(superLedger.code.length > 0, "ADD_TO_LEDGER_SUPER_LEDGER_NO_CODE");

        require(flatFeeLedger != address(0), "ADD_TO_LEDGER_FLAT_FEE_LEDGER_ZERO");
        require(flatFeeLedger.code.length > 0, "ADD_TO_LEDGER_FLAT_FEE_LEDGER_NO_CODE");

        // Validate treasury address is set
        require(configuration.treasury != address(0), "ADD_TO_LEDGER_TREASURY_ZERO");

        console2.log("SuperLedgerConfiguration:", superLedgerConfig);
        console2.log("SuperLedger:", superLedger);
        console2.log("FlatFeeLedger:", flatFeeLedger);
        console2.log("Treasury:", configuration.treasury);
        console2.log("");

        // ===== VALIDATE ALL ORACLE ADDRESSES =====
        for (uint256 i = 0; i < oracleAddresses.length; ++i) {
            require(oracleAddresses[i] != address(0), "ADD_TO_LEDGER_ORACLE_ZERO");
            require(oracleAddresses[i].code.length > 0, "ADD_TO_LEDGER_ORACLE_NO_CODE");
            require(salts[i] != bytes32(0), "ADD_TO_LEDGER_SALT_ZERO");
            console2.log("Oracle", i, ":", oracleAddresses[i]);
            console2.log("Salt", i, ":", vm.toString(salts[i]));
        }
        console2.log("");

        // ===== SETUP NEW CONFIGURATIONS =====
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](oracleAddresses.length);

        // Create configuration for each oracle
        // Note: Using SuperLedger as default ledger and 0% fee
        // Adjust feePercent and ledger as needed for your specific use case
        for (uint256 i = 0; i < oracleAddresses.length; ++i) {
            configs[i] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
                yieldSourceOracle: oracleAddresses[i],
                feePercent: 0,
                feeRecipient: configuration.treasury,
                ledger: superLedger // Default to SuperLedger, can be changed to flatFeeLedger if needed
            });

            console2.log("Configuration", i, "created:");
            console2.log("  Oracle:", configs[i].yieldSourceOracle);
            console2.log("  Fee Percent:", configs[i].feePercent);
            console2.log("  Fee Recipient:", configs[i].feeRecipient);
            console2.log("  Ledger:", configs[i].ledger);
            console2.log("");
        }

        // ===== EXECUTE CONFIGURATION SETUP =====
        console2.log("Setting yield source oracles in SuperLedgerConfiguration...");
        ISuperLedgerConfiguration(superLedgerConfig).setYieldSourceOracles(salts, configs);

        console2.log("");
        console2.log("====== CONFIGURATION ADDED SUCCESSFULLY ======");
        console2.log("Added", salts.length, "new oracle configuration(s) to SuperLedger");
    }

    /// @notice Helper function to convert string array to bytes32 array
    /// @dev Converts each string to bytes32 using bytes32(bytes(str))
    /// @param strings Array of strings to convert
    /// @return bytes32Array Array of bytes32 values
    function _convertStringsToBytes32(string[] memory strings) private pure returns (bytes32[] memory bytes32Array) {
        bytes32Array = new bytes32[](strings.length);
        for (uint256 i = 0; i < strings.length; ++i) {
            bytes32Array[i] = bytes32(bytes(strings[i]));
        }
        return bytes32Array;
    }
}
