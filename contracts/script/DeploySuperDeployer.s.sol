// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { SuperDeployer } from "./utils/SuperDeployer.sol";

import { Script } from "forge-std/Script.sol";
import "forge-std/console2.sol";

contract DeploySuperDeployer is Script {
    function run() public {
        vm.startBroadcast();
        bytes32 salt = "SuperformSuperDeployer.v1.0.2";

        address expectedAddr = vm.computeCreate2Address(salt, keccak256(type(SuperDeployer).creationCode));
        console2.log("Expected address:", expectedAddr);
        if (expectedAddr.code.length > 0) {
            console2.log("SuperDeployer already deployed at:", expectedAddr);
            vm.stopBroadcast();
            return;
        }

        SuperDeployer superDeployer = new SuperDeployer{ salt: salt }();
        console2.log("SuperDeployer deployed at:", address(superDeployer));
    }
}
