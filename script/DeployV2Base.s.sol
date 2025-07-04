// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

// external
import { Script } from "forge-std/Script.sol";
import "forge-std/console2.sol";

// Superform
import { SuperDeployer } from "./utils/SuperDeployer.sol";
import { ISuperDeployer } from "./utils/ISuperDeployer.sol";
import { ConfigBase } from "./utils/ConfigBase.sol";

abstract contract DeployV2Base is Script, ConfigBase {
    mapping(uint64 chainId => mapping(string contractName => address contractAddress)) public contractAddresses;

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

    function _deployDeployer() internal {
        bytes32 salt = __getSalt(SUPER_DEPLOYER_KEY);

        // Predict the address using CREATE2
        address predictedAddr = vm.computeCreate2Address(salt, keccak256(type(SuperDeployer).creationCode));

        // Check if already deployed
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(predictedAddr)
        }

        if (codeSize > 0) {
            console2.log("SuperDeployer already deployed at:", predictedAddr);
            console2.log("Skipping deployment...");
        } else {
            address superDeployer = address(new SuperDeployer{ salt: salt }());
            console2.log("SuperDeployer deployed at:", superDeployer);
            require(superDeployer == predictedAddr, "Address mismatch");
        }

        configuration.deployer = predictedAddr;
        console2.log("Using SuperDeployer at:", configuration.deployer);
    }

    function _getContract(uint64 chainId, string memory contractName) internal view returns (address) {
        return contractAddresses[chainId][contractName];
    }

    function __deployContract(
        ISuperDeployer deployer,
        string memory contractName,
        uint64 chainId,
        bytes32 salt,
        bytes memory creationCode
    )
        internal
        returns (address)
    {
        console2.log("[!] Deploying %s...", contractName);

        // Check if already deployed (Nexus-style pattern)
        if (deployer.isDeployed(salt)) {
            address expectedAddr = deployer.getDeployed(salt);
            console2.log("[!] %s already deployed at:", contractName, expectedAddr);
            console2.log("      skipping...");
            contractAddresses[chainId][contractName] = expectedAddr;
            _exportContract(contractName, expectedAddr, chainId);
            return expectedAddr;
        }

        address deployedAddr = deployer.deploy(salt, creationCode);
        console2.log("  [+] %s deployed at:", contractName, deployedAddr);
        contractAddresses[chainId][contractName] = deployedAddr;
        _exportContract(contractName, deployedAddr, chainId);

        return deployedAddr;
    }

    function __getSalt(string memory name) internal pure returns (bytes32) {
        // Completely deterministic salt generation - independent of all external factors
        // Only depends on contract name, guaranteeing same address across all chains/deployers
        return keccak256(abi.encodePacked("SuperformV2", name, "v2.0"));
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
