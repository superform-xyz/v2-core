// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.30;

import { Script } from "forge-std/Script.sol";
import { ConfigBase } from "./utils/ConfigBase.sol";
import { console2 } from "forge-std/console2.sol";

/**
 * @title SmokeTestDeployment
 * @notice Smoke test that reads a chain's deployment JSON and verifies every listed contract has code on-chain
 * @dev Usage: forge script script/SmokeTestDeployment.s.sol:SmokeTestDeployment \
 *            --sig "run(uint256,uint64)" <env> <chainId> --rpc-url <rpc>
 */
contract SmokeTestDeployment is Script, ConfigBase {
    /// @notice Environment setting for determining output path
    uint256 internal currentEnv;

    /// @notice Returns true if a contract should be skipped for a given chain
    /// @dev Tracks contracts that are known to be pending deployment (e.g. bytecode regeneration needed)
    function _isSkipped(uint64, string memory) internal pure returns (bool) {
        return false;
    }

    /// @notice Main entry point
    /// @param env Environment (0 = prod, 2 = staging)
    /// @param chainId Target chain ID to test
    function run(uint256 env, uint64 chainId) public {
        require(env == 0 || env == 2, "Invalid environment: must be 0 (prod) or 2 (staging)");

        // Initialize chain name mappings
        _setBaseConfiguration(env, "");

        string memory envName = env == 0 ? "prod" : "staging";
        string memory chainName = chainNames[chainId];
        require(bytes(chainName).length > 0, "Unknown chain ID");

        console2.log("====== DEPLOYMENT SMOKE TEST ======");
        console2.log("Environment:", envName);
        console2.log("Chain ID:", chainId);
        console2.log("Chain Name:", chainName);
        console2.log("");

        // Read deployment JSON
        string memory root = vm.envOr("SUPERFORM_PROJECT_ROOT", vm.projectRoot());
        string memory outputPath = string(
            abi.encodePacked(root, "/script/output/", envName, "/", vm.toString(uint256(chainId)), "/", chainName, "-latest.json")
        );

        require(vm.exists(outputPath), string(abi.encodePacked("DEPLOYMENT_FILE_NOT_FOUND: ", outputPath)));

        string memory json = vm.readFile(outputPath);

        // Parse all keys from the JSON
        string[] memory keys = vm.parseJsonKeys(json, "$");
        uint256 totalContracts = keys.length;
        uint256 deployedCount = 0;
        uint256 missingCount = 0;
        uint256 skippedCount = 0;

        console2.log("Total contracts in deployment file:", totalContracts);
        console2.log("");

        // Track missing contracts
        string[] memory missingContracts = new string[](totalContracts);
        address[] memory missingAddresses = new address[](totalContracts);

        for (uint256 i = 0; i < totalContracts; i++) {
            // Skip known-undeployed contracts
            if (_isSkipped(chainId, keys[i])) {
                skippedCount++;
                console2.log("SKIPPED (pending deployment):", keys[i]);
                continue;
            }

            address addr = vm.parseJsonAddress(json, string(abi.encodePacked(".", keys[i])));
            uint256 codeSize = addr.code.length;

            if (codeSize > 0) {
                deployedCount++;
            } else {
                missingContracts[missingCount] = keys[i];
                missingAddresses[missingCount] = addr;
                missingCount++;
                console2.log("MISSING:", keys[i]);
                console2.log("  Address:", addr);
            }
        }

        console2.log("");
        console2.log("====== RESULTS ======");
        console2.log("Deployed:", deployedCount, "/", totalContracts);
        if (skippedCount > 0) {
            console2.log("Skipped:", skippedCount);
        }

        if (missingCount > 0) {
            console2.log("");
            console2.log("Missing contracts:");
            for (uint256 i = 0; i < missingCount; i++) {
                console2.log(" ", missingContracts[i], "at", missingAddresses[i]);
            }
            console2.log("");
            console2.log("DEPLOYMENT SMOKE TEST FAILED");
            revert("DEPLOYMENT_SMOKE_TEST_FAILED: contracts missing on-chain");
        } else {
            console2.log("");
            console2.log("DEPLOYMENT SMOKE TEST PASSED");
        }
        console2.log("====== SMOKE TEST COMPLETED ======");
    }
}
