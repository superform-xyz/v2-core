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

    // Contract deployment status tracking
    struct ContractStatus {
        bool isDeployed;
        address contractAddress;
        string contractName;
    }

    mapping(uint64 => mapping(string => ContractStatus)) internal contractDeploymentStatus;
    mapping(uint64 => string[]) internal allContractNames;

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

        // Save deployment status
        _saveContractStatus(chainId, contractName, true, deployedAddr);

        return deployedAddr;
    }

    /// @notice Deploy a contract only if it's not already deployed
    /// @param contractName Name of the contract for logging
    /// @param chainId Chain ID for tracking
    /// @param salt Salt for deterministic deployment
    /// @param creationCode Bytecode with constructor args
    /// @return deployedAddr Address of the deployed or existing contract
    function __deployContractIfNeeded(
        string memory contractName,
        uint64 chainId,
        bytes32 salt,
        bytes memory creationCode
    )
        internal
        returns (address deployedAddr)
    {
        // Check if contract is already deployed
        if (_isContractDeployed(chainId, contractName)) {
            ContractStatus memory status = _getContractStatus(chainId, contractName);
            console2.log("[!] %s already deployed, skipping...", contractName);
            console2.log("      at:", status.contractAddress);
            contractAddresses[chainId][contractName] = status.contractAddress;
            _exportContract(contractName, status.contractAddress, chainId);
            return status.contractAddress;
        }

        // Deploy the contract if not already deployed
        return __deployContract(contractName, chainId, salt, creationCode);
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
        return __checkContractOnChain(contractName, salt, args, uint64(block.chainid));
    }

    /// @notice Check if a contract is deployed on a specific chain
    /// @param contractName Name of the contract
    /// @param salt Salt used for deployment
    /// @param args Constructor arguments (empty if none)
    /// @param chainId Chain ID to check
    /// @return isDeployed Whether the contract is deployed
    /// @return contractAddr Address of the contract
    function __checkContractOnChain(
        string memory contractName,
        bytes32 salt,
        bytes memory args,
        uint64 chainId
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

        // Store deployment status
        _saveContractStatus(chainId, contractName, isDeployed, contractAddr);

        // Update counters
        if (isDeployed) {
            deployed++;
        }
        total++;

        // Log status
        console2.log(string(abi.encodePacked(contractName, " Addr: ")), contractAddr, " || >> Code Size: ", codeSize);
        console2.log("");
    }

    /// @notice Save contract deployment status
    /// @param chainId Chain ID
    /// @param contractName Name of the contract
    /// @param isDeployed Whether the contract is deployed
    /// @param contractAddr Address of the contract
    function _saveContractStatus(
        uint64 chainId,
        string memory contractName,
        bool isDeployed,
        address contractAddr
    )
        internal
    {
        // Check if this contract name hasn't been added to the list yet
        bool nameExists = false;
        for (uint256 i = 0; i < allContractNames[chainId].length; i++) {
            if (keccak256(bytes(allContractNames[chainId][i])) == keccak256(bytes(contractName))) {
                nameExists = true;
                break;
            }
        }

        if (!nameExists) {
            allContractNames[chainId].push(contractName);
        }

        contractDeploymentStatus[chainId][contractName] =
            ContractStatus({ isDeployed: isDeployed, contractAddress: contractAddr, contractName: contractName });
    }

    /// @notice Get deployment status for a specific contract
    /// @param chainId Chain ID
    /// @param contractName Name of the contract
    /// @return status Contract deployment status
    function _getContractStatus(
        uint64 chainId,
        string memory contractName
    )
        internal
        view
        returns (ContractStatus memory status)
    {
        return contractDeploymentStatus[chainId][contractName];
    }

    /// @notice Check if a contract is deployed
    /// @param chainId Chain ID
    /// @param contractName Name of the contract
    /// @return isDeployed Whether the contract is deployed
    function _isContractDeployed(uint64 chainId, string memory contractName) internal view returns (bool) {
        return contractDeploymentStatus[chainId][contractName].isDeployed;
    }

    /// @notice Get all contract names for a chain
    /// @param chainId Chain ID
    /// @return contractNames Array of contract names
    function _getAllContractNames(uint64 chainId) internal view returns (string[] memory) {
        return allContractNames[chainId];
    }

    /// @notice Log comprehensive deployment summary showing which contracts are deployed vs missing
    /// @dev This provides a clear overview of deployment status to guide conditional deployment
    /// @param chainId Chain ID
    function _logDeploymentSummary(uint64 chainId) internal view {
        console2.log("");
        console2.log("====== DEPLOYMENT STATUS SUMMARY ======");
        console2.log("Chain ID:", chainId);
        console2.log("");

        string[] memory contractNames = allContractNames[chainId];
        uint256 deployedCount = 0;
        uint256 missingCount = 0;

        // Count deployed and missing contracts
        for (uint256 i = 0; i < contractNames.length; i++) {
            ContractStatus memory status = contractDeploymentStatus[chainId][contractNames[i]];
            if (status.isDeployed) {
                deployedCount++;
            } else {
                missingCount++;
            }
        }

        console2.log("Total Contracts Checked:", contractNames.length);
        console2.log("Already Deployed:", deployedCount);
        console2.log("Missing/Need Deployment:", missingCount);
        console2.log("");

        if (deployedCount > 0) {
            console2.log("=== ALREADY DEPLOYED CONTRACTS ===");
            for (uint256 i = 0; i < contractNames.length; i++) {
                ContractStatus memory status = contractDeploymentStatus[chainId][contractNames[i]];
                if (status.isDeployed) {
                    console2.log("[DEPLOYED]", status.contractName, "at", status.contractAddress);
                }
            }
            console2.log("");
        }

        if (missingCount > 0) {
            console2.log("=== CONTRACTS NEEDING DEPLOYMENT ===");
            for (uint256 i = 0; i < contractNames.length; i++) {
                ContractStatus memory status = contractDeploymentStatus[chainId][contractNames[i]];
                if (!status.isDeployed) {
                    console2.log("[MISSING]", status.contractName, "needs deployment at", status.contractAddress);
                }
            }
            console2.log("");
        }

        console2.log("=========================================");
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
