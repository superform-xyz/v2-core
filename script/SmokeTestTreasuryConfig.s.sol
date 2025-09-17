// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.30;

import { DeployV2Base } from "./DeployV2Base.s.sol";
import { ConfigCore } from "./utils/ConfigCore.sol";
import { ISuperLedgerConfiguration } from "../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { console2 } from "forge-std/console2.sol";

/**
 * @title SmokeTestTreasuryConfig
 * @notice Smoke test script to verify treasury configuration setup by _setupSuperLedgerConfiguration
 * @dev This script validates that the treasury address is correctly configured across all oracle configurations
 */
contract SmokeTestTreasuryConfig is DeployV2Base, ConfigCore {
    /// @notice Custom error for smoke test failure
    error TreasuryConfigSmokeTestFailed();

    /// @notice Fireblocks sender address used for oracle ID derivation
    address internal constant FIREBLOCKS_SENDER = 0x28b7599f461D104f07D78215Fa6F9B959851f93d;

    struct TreasuryValidationResults {
        bool treasuryConfigured;
        bool superLedgerConfigDeployed;
        bool oraclesConfigured;
        uint256 validOracleConfigs;
        uint256 totalOracleConfigs;
        address expectedTreasury;
        address[] oracleAddresses;
        address[] configuredFeeRecipients;
        string[] validationErrors;
    }

    /// @notice Main entry point for treasury configuration smoke test
    /// @param chainId Target chain ID to test
    function run(uint64 chainId) public {
        runTreasuryConfigSmokeTest(chainId);
    }

    /// @notice Execute treasury configuration smoke test
    /// @param chainId Target chain ID to test
    function runTreasuryConfigSmokeTest(uint64 chainId) public {
        console2.log("====== TREASURY CONFIGURATION SMOKE TEST ======");
        console2.log("Environment: Production");
        console2.log("Chain ID:", chainId);
        console2.log("");

        // Set configuration for production environment
        _setConfiguration();

        // Perform treasury validation
        TreasuryValidationResults memory results = _validateTreasuryConfiguration(chainId);

        // Log detailed results
        _logValidationResults(results, chainId);

        // Determine overall test result
        bool testPassed = _evaluateTestResults(results);

        console2.log("");
        if (testPassed) {
            console2.log("TREASURY CONFIGURATION SMOKE TEST PASSED");
        } else {
            console2.log("TREASURY CONFIGURATION SMOKE TEST FAILED");
            revert TreasuryConfigSmokeTestFailed();
        }
        console2.log("====== SMOKE TEST COMPLETED ======");
    }

    /// @notice Validate treasury configuration across all components
    /// @param chainId Target chain ID
    /// @return results Comprehensive validation results
    function _validateTreasuryConfiguration(uint64 chainId)
        internal
        view
        returns (TreasuryValidationResults memory results)
    {
        // Initialize results struct
        results.expectedTreasury = configuration.treasury;
        results.oracleAddresses = new address[](4);
        results.configuredFeeRecipients = new address[](4);
        results.validationErrors = new string[](10); // Pre-allocate for potential errors

        uint256 errorCount = 0;

        // 1. Validate treasury is configured in base configuration
        if (configuration.treasury == address(0)) {
            results.validationErrors[errorCount++] = "Treasury address not configured in base configuration";
            results.treasuryConfigured = false;
        } else {
            results.treasuryConfigured = true;
            console2.log("Treasury configured:", configuration.treasury);
        }

        // 2. Get SuperLedgerConfiguration address directly
        address superLedgerConfig = _getDeployedContractAddress(chainId, SUPER_LEDGER_CONFIGURATION_KEY);

        if (superLedgerConfig == address(0) || superLedgerConfig.code.length == 0) {
            revert("SuperLedgerConfiguration not properly deployed");
        }

        results.superLedgerConfigDeployed = true;
        console2.log("SuperLedgerConfiguration deployed at:", superLedgerConfig);

        // 3. Validate oracle configurations
        (results, errorCount) = _validateOracleConfigurations(superLedgerConfig, results, errorCount);

        // Resize validation errors array to actual size
        string[] memory actualErrors = new string[](errorCount);
        for (uint256 i = 0; i < errorCount; i++) {
            actualErrors[i] = results.validationErrors[i];
        }
        results.validationErrors = actualErrors;

        return results;
    }

    /// @notice Validate oracle configurations for treasury setup
    /// @param superLedgerConfig Address of SuperLedgerConfiguration contract
    /// @param results Current validation results to update
    /// @param errorCount Current error count
    /// @return Updated validation results and updated error count
    function _validateOracleConfigurations(
        address superLedgerConfig,
        TreasuryValidationResults memory results,
        uint256 errorCount
    )
        internal
        view
        returns (TreasuryValidationResults memory, uint256)
    {
        // Define oracle salts for hashing with Fireblocks sender
        bytes32[4] memory saltHashes = [
            bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_SALT)),
            bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_SALT)),
            bytes32(bytes(ERC5115_YIELD_SOURCE_ORACLE_SALT)),
            bytes32(bytes(STAKING_YIELD_SOURCE_ORACLE_SALT))
        ];

        // Derive oracle IDs using _deriveWithSender logic (keccak256(salt, sender))
        bytes32[] memory oracleIds = new bytes32[](4);
        for (uint256 i = 0; i < 4; i++) {
            oracleIds[i] = _deriveWithSender(saltHashes[i], FIREBLOCKS_SENDER);
            console2.logBytes32(oracleIds[i]);
        }

        string[4] memory oracleNames = [
            "ERC4626YieldSourceOracle",
            "ERC7540YieldSourceOracle",
            "ERC5115YieldSourceOracle",
            "StakingYieldSourceOracle"
        ];

        results.totalOracleConfigs = 4;

        // Get all oracle configurations at once using batch function
        try ISuperLedgerConfiguration(superLedgerConfig).getYieldSourceOracleConfigs(oracleIds) returns (
            ISuperLedgerConfiguration.YieldSourceOracleConfig[] memory configs
        ) {
            uint256 validConfigs = 0;

            for (uint256 i = 0; i < 4; i++) {
                // Store oracle address for logging
                results.oracleAddresses[i] = configs[i].yieldSourceOracle;
                results.configuredFeeRecipients[i] = configs[i].feeRecipient;

                if (configs[i].feeRecipient == results.expectedTreasury) {
                    validConfigs++;
                    console2.log("Oracle", oracleNames[i], "treasury configured correctly");
                } else {
                    string memory err = string(
                        abi.encodePacked(
                            oracleNames[i],
                            " has incorrect treasury: expected ",
                            _addressToString(results.expectedTreasury),
                            " got ",
                            _addressToString(configs[i].feeRecipient)
                        )
                    );
                    console2.log(err);
                    results.validationErrors[errorCount++] = err;
                }
            }

            results.validOracleConfigs = validConfigs;
            results.oraclesConfigured = (validConfigs == 4);
        } catch {
            results.validationErrors[errorCount++] = "Failed to get oracle configurations from SuperLedgerConfiguration";
            results.oraclesConfigured = false;
        }

        return (results, errorCount);
    }

    /// @notice Derive oracle ID with sender address (replica of _deriveWithSender)
    /// @param salt The salt bytes32 value
    /// @param sender The sender address (Fireblocks)
    /// @return Derived oracle ID
    function _deriveWithSender(bytes32 salt, address sender) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(salt, sender));
    }

    /// @notice Get deployed contract address for validation
    /// @param chainId Target chain ID
    /// @param contractKey Contract key
    /// @return contractAddress Deployed contract address
    function _getDeployedContractAddress(
        uint64 chainId,
        string memory contractKey
    )
        public
        view
        returns (address contractAddress)
    {
        // Read from deployment output files
        string memory deploymentJson = _readCoreContractsFromOutput(chainId);
        contractAddress = vm.parseJsonAddress(deploymentJson, string(abi.encodePacked(".", contractKey)));
        return contractAddress;
    }

    /// @notice Read core contracts from output files
    /// @param chainId Target chain ID
    /// @return JSON string containing contract addresses
    function _readCoreContractsFromOutput(uint64 chainId) internal view returns (string memory) {
        string memory chainName = chainNames[chainId];
        // Use environment variable for reliable project root, fallback to vm.projectRoot()
        string memory root = vm.envOr("SUPERFORM_PROJECT_ROOT", vm.projectRoot());

        string memory envName = "prod";

        // Construct path: script/output/{env}/{chainId}/{ChainName}-latest.json
        string memory outputPath = string(
            abi.encodePacked(
                root, "/script/output/", envName, "/", vm.toString(uint256(chainId)), "/", chainName, "-latest.json"
            )
        );

        console2.log("Reading contracts from:", outputPath);

        // Check if file exists and read it
        if (!vm.exists(outputPath)) {
            revert(string(abi.encodePacked("CONTRACT_FILE_NOT_FOUND: ", outputPath)));
        }

        return vm.readFile(outputPath);
    }

    /// @notice Log comprehensive validation results
    /// @param results Validation results to log
    /// @param chainId Target chain ID
    function _logValidationResults(TreasuryValidationResults memory results, uint64 chainId) internal pure {
        console2.log("====== VALIDATION RESULTS ======");
        console2.log("Chain ID:", chainId);
        console2.log("Expected Treasury:", results.expectedTreasury);
        console2.log("");

        console2.log("=== Configuration Status ===");
        console2.log("Treasury Configured:", results.treasuryConfigured ? "YES" : "NO");
        console2.log("SuperLedgerConfiguration Deployed:", results.superLedgerConfigDeployed ? "YES" : "NO");
        console2.log("Oracles Configured:", results.oraclesConfigured ? "YES" : "NO");
        console2.log("Valid Oracle Configs:", results.validOracleConfigs, "/", results.totalOracleConfigs);
        console2.log("");

        if (results.oracleAddresses.length > 0) {
            console2.log("=== Oracle Treasury Configuration ===");
            string[4] memory oracleNames = [
                "ERC4626YieldSourceOracle",
                "ERC7540YieldSourceOracle",
                "ERC5115YieldSourceOracle",
                "StakingYieldSourceOracle"
            ];

            for (uint256 i = 0; i < 4; i++) {
                if (results.oracleAddresses[i] != address(0)) {
                    console2.log(oracleNames[i], ":");
                    console2.log("  Address:", results.oracleAddresses[i]);
                    console2.log("  Fee Recipient:", results.configuredFeeRecipients[i]);
                    console2.log(
                        "  Treasury Match:",
                        results.configuredFeeRecipients[i] == results.expectedTreasury ? "YES" : "NO"
                    );
                }
            }
            console2.log("");
        }

        if (results.validationErrors.length > 0) {
            console2.log("=== Validation Errors ===");
            for (uint256 i = 0; i < results.validationErrors.length; i++) {
                if (bytes(results.validationErrors[i]).length > 0) {
                    console2.log("ERROR:", results.validationErrors[i]);
                }
            }
            console2.log("");
        }
    }

    /// @notice Evaluate test results and determine pass/fail
    /// @param results Validation results
    /// @return testPassed Whether the test passed
    function _evaluateTestResults(TreasuryValidationResults memory results) internal pure returns (bool testPassed) {
        return results.treasuryConfigured && results.superLedgerConfigDeployed && results.oraclesConfigured
            && results.validationErrors.length == 0;
    }

    /// @notice Convert address to string for error messages
    /// @param addr Address to convert
    /// @return String representation of address
    function _addressToString(address addr) internal pure returns (string memory) {
        bytes memory data = abi.encodePacked(addr);
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < data.length; i++) {
            str[2 + i * 2] = alphabet[uint256(uint8(data[i] >> 4))];
            str[3 + i * 2] = alphabet[uint256(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }

    /// @notice Sets up configuration for the smoke test (production only)
    function _setConfiguration() internal {
        // Set base configuration for production
        _setBaseConfiguration(0, "");

        // Set core contract dependencies
        _setCoreConfiguration();
    }
}
