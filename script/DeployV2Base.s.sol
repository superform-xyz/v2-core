// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.30;

// external
import { Script } from "forge-std/Script.sol";
import "forge-std/console2.sol";

// Superform
import { DeterministicDeployerLib } from "../src/vendor/nexus/DeterministicDeployerLib.sol";
import { ConfigBase } from "./utils/ConfigBase.sol";

abstract contract DeployV2Base is Script, ConfigBase {
    mapping(uint64 chainId => mapping(string contractName => address contractAddress)) public contractAddresses;

    // Deployed and total counters for checking
    uint256 internal deployed;
    uint256 internal total;

    modifier broadcast(uint256 env) {
        if (env == 1) {
            (address deployer,) = deriveRememberKey(MNEMONIC, 0);
            console2.log("Deployer: ", deployer);
            vm.startBroadcast(deployer);
            _;
            vm.stopBroadcast();
        } else {
            // Fallback for other env values
            vm.startBroadcast();
            _;
            vm.stopBroadcast();
        }
    }

    function _getContract(uint64 chainId, string memory contractName) internal view returns (address) {
        return contractAddresses[chainId][contractName];
    }

    /// @notice Deploy a contract using DeterministicDeployerLib - Nexus style
    /// @param contractName Name of the contract for logging
    /// @param chainId Chain ID for tracking
    /// @param salt Salt for deterministic deployment
    /// @param creationCode Bytecode with constructor args
    /// @return deployedAddr Address of the deployed contract
    function __deployContract(
        string memory contractName,
        uint64 chainId,
        bytes32 salt,
        bytes memory creationCode
    )
        internal
        returns (address deployedAddr)
    {
        console2.log("[!] Deploying %s...", contractName);

        // Predict address first
        address predictedAddr = DeterministicDeployerLib.computeAddress(creationCode, salt);

        // Check if already deployed using assembly like Nexus
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(predictedAddr)
        }

        if (codeSize > 0) {
            console2.log("[!] %s already deployed at:", contractName, predictedAddr);
            console2.log("      skipping...");
            contractAddresses[chainId][contractName] = predictedAddr;
            _exportContract(contractName, predictedAddr, chainId);
            return predictedAddr;
        }

        // Deploy using DeterministicDeployerLib
        deployedAddr = DeterministicDeployerLib.deploy(creationCode, salt);

        // Verify deployment
        require(deployedAddr == predictedAddr, "Address mismatch after deployment");
        require(deployedAddr.code.length > 0, "Deployment failed - no code");

        console2.log("  [+] %s deployed at:", contractName, deployedAddr);
        contractAddresses[chainId][contractName] = deployedAddr;
        _exportContract(contractName, deployedAddr, chainId);

        return deployedAddr;
    }

    /// @notice Check if a contract is deployed using bytecode from locked artifacts
    /// @param contractName Name of the contract
    /// @param salt Salt used for deployment
    /// @param args Constructor arguments (empty if none)
    /// @return isDeployed Whether the contract is deployed
    /// @return contractAddr Address of the contract
    function __checkContract(
        string memory contractName,
        bytes32 salt,
        bytes memory args
    )
        internal
        returns (bool isDeployed, address contractAddr)
    {
        // Get bytecode from locked artifacts (Nexus style)
        string memory artifactPath = string(abi.encodePacked("script/locked-bytecode/", contractName, ".json"));
        bytes memory bytecode = vm.getCode(artifactPath);

        // Compute address
        contractAddr = DeterministicDeployerLib.computeAddress(bytecode, args, salt);

        // Check if deployed using assembly (Nexus style)
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(contractAddr)
        }

        isDeployed = codeSize > 0;

        // Update counters
        if (isDeployed) {
            deployed++;
        }
        total++;

        // Log status
        console2.log(string(abi.encodePacked(contractName, " Addr: ")), contractAddr, " || >> Code Size: ", codeSize);
        console2.log("");
    }

    /// @notice Generate salt using the same pattern as current system
    /// @param name Contract name
    /// @return Salt for deployment
    function __getSalt(string memory name) internal view returns (bytes32) {
        // Use configurable salt namespace for deployment
        // This allows for different salt namespaces for production vs test/vnet deployments
        return keccak256(abi.encodePacked("SuperformV2", SALT_NAMESPACE, name, "v2.0"));
    }

    // Add a mapping to track exported contracts per chain
    mapping(uint64 => string) private exportedContracts;
    mapping(uint64 => uint256) private contractCount;

    function _exportContract(string memory contractName, address addr, uint64 chainId) internal {
        // Accumulate contracts for this chain
        contractCount[chainId]++;
        string memory objectKey = string(abi.encodePacked("EXPORTS_", vm.toString(uint256(chainId))));
        exportedContracts[chainId] = vm.serializeAddress(objectKey, contractName, addr);
    }

    function _writeExportedContracts(uint64 chainId) internal {
        if (contractCount[chainId] == 0) return;

        string memory chainName = chainNames[chainId];
        string memory root = vm.projectRoot();
        string memory chainOutputFolder = string(abi.encodePacked("/script/output/"));

        // For local runs, use local directory
        if (!vm.envOr("CI", false)) {
            chainOutputFolder =
                string(abi.encodePacked(chainOutputFolder, "local/", vm.toString(uint256(chainId)), "/"));
        } else {
            // For CI runs, use branch-specific directory
            string memory branchName = vm.envString("GITHUB_REF_NAME");

            chainOutputFolder =
                string(abi.encodePacked(chainOutputFolder, branchName, "/", vm.toString(uint256(chainId)), "/"));
        }

        // Create directory if it doesn't exist
        vm.createDir(string(abi.encodePacked(root, chainOutputFolder)), true);

        // Write to {ChainName}-latest.json
        string memory outputPath = string(abi.encodePacked(root, chainOutputFolder, chainName, "-latest.json"));
        vm.writeJson(exportedContracts[chainId], outputPath);

        console2.log("Exported", contractCount[chainId], "contracts to:", outputPath);
    }

    // Helper function to read core contract addresses for periphery deployment
    function _readCoreContracts(uint64 chainId) internal view returns (string memory) {
        string memory chainName = chainNames[chainId];
        string memory root = vm.projectRoot();
        string memory chainOutputFolder = string(abi.encodePacked("/script/output/"));

        // For local runs, use local directory
        if (!vm.envOr("CI", false)) {
            chainOutputFolder =
                string(abi.encodePacked(chainOutputFolder, "local/", vm.toString(uint256(chainId)), "/"));
        } else {
            // For CI runs, use branch-specific directory
            string memory branchName = vm.envString("GITHUB_REF_NAME");

            chainOutputFolder =
                string(abi.encodePacked(chainOutputFolder, branchName, "/", vm.toString(uint256(chainId)), "/"));
        }

        string memory outputPath = string(abi.encodePacked(root, chainOutputFolder, chainName, "-latest.json"));
        return vm.readFile(outputPath);
    }
}
