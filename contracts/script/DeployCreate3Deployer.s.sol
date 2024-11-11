// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { Script } from "forge-std/Script.sol";
import "forge-std/console2.sol";
import { Create3Deployer } from "./utils/Create3Deployer.sol";

contract DeployScript is Script {
    function run() public {
        vm.startBroadcast();
        bytes32 salt = "SuperformCreate3";
        address expectedAddr = vm.computeCreate2Address(salt, keccak256(type(Create3Deployer).creationCode));
        if (expectedAddr.code.length > 0) {
            console2.log("Create3Deployer already at: ", expectedAddr);
            vm.stopBroadcast();
            return;
        }
        Create3Deployer deployer = new Create3Deployer{ salt: salt }();
        console2.log("Create3Deployer: ", address(deployer));
        vm.stopBroadcast();
    }
}
