// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { SuperDeployer } from "./utils/SuperDeployer.sol";

import { Script } from "forge-std/Script.sol";
import "forge-std/console2.sol";

contract DeploySuperDeployer is Script {
    string internal constant MNEMONIC = "test test test test test test test test test test test junk";

    modifier broadcast(uint256 env) {
        if (env == 1) {
            (address deployer,) = deriveRememberKey(MNEMONIC, 0);
            console2.log("Deployer: ", deployer);
            vm.startBroadcast(deployer);
            _;
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            _;
            vm.stopBroadcast();
        }
    }

    function run(uint256 env) public broadcast(env) {
        bytes32 salt = "SuperformSuperDeployer.v1.0.3";

        address expectedAddr = vm.computeCreate2Address(salt, keccak256(type(SuperDeployer).creationCode));
        console2.log("Expected address:", expectedAddr);
        if (expectedAddr.code.length > 0) {
            console2.log("SuperDeployer already deployed at:", expectedAddr);
            return;
        }

        SuperDeployer superDeployer = new SuperDeployer{ salt: salt }();
        console2.log("SuperDeployer deployed at:", address(superDeployer));
    }
}
