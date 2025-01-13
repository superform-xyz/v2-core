// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Script } from "forge-std/Script.sol";
import "forge-std/console2.sol";

// Superform
import { ISuperDeployer } from "./utils/ISuperDeployer.sol";
import { Configuration } from "./utils/Configuration.sol";

import { MockValidatorModule } from "../test/mocks/MockValidatorModule.sol";

contract DeployMocks is Script, Configuration {
    function run(uint64[] memory chainIds) public {
        vm.startBroadcast();
        _setAllChainsConfiguration();
        uint256 len = chainIds.length;
        for (uint256 i; i < len;) {
            uint64 chainId = chainIds[i];
            console2.log("Deploying on chainId: ", chainId);

            // set chain configuration
            _setConfiguration(chainId);

            _deploy();

            unchecked {
                ++i;
            }
        }
        vm.stopBroadcast();
    }

    function _getDeployer() internal view returns (ISuperDeployer deployer) {
        return ISuperDeployer(configuration.deployer);
    }

    function _deploy() internal {
        // retrieve deployer
        ISuperDeployer deployer = _getDeployer();

        // deploy mock validator module
        __deployContract(
            deployer,
            "MockValidatorModule",
            __getSalt(configuration.owner, configuration.deployer, "MockValidatorModule"),
            type(MockValidatorModule).creationCode
        );
    }

    function __deployContract(
        ISuperDeployer deployer,
        string memory contractName,
        bytes32 salt,
        bytes memory creationCode
    )
        private
        returns (address)
    {
        address expectedAddr = deployer.getDeployed(salt);
        if (expectedAddr.code.length > 0) {
            console2.log("[!] %s already deployed at:", contractName, expectedAddr);
            console2.log("      skipping...");
            return expectedAddr;
        }

        address deployedAddr = deployer.deploy(salt, creationCode);
        console2.log("  [+] %s deployed at:", contractName, deployedAddr);
        return deployedAddr;
    }

    function __getSalt(address eoa, address deployer, string memory name) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(eoa, deployer, bytes(SALT_NAMESPACE), bytes(string.concat(name, ".v0.1"))));
    }
}
