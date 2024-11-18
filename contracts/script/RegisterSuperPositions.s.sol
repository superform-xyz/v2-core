// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { Script } from "forge-std/Script.sol";
import "forge-std/console2.sol";
import { Create3Deployer } from "./utils/Create3Deployer.sol";
import { ISentinel } from "src/interfaces/sentinels/ISentinel.sol";
import { SuperRbac } from "src/settings/SuperRbac.sol";
import { SuperRegistry } from "src/settings/SuperRegistry.sol";
import { SuperPositions } from "src/superpositions/SuperPositions.sol";
import { RelayerSentinel } from "src/sentinels/RelayerSentinel.sol";
import { Deposit4626MintSuperPositionsDecoder } from "src/sentinels/Deposit4626MintSuperPositionsDecoder.sol";
import { Deposit4626Module } from "src/modules/erc4626/Deposit4626Module.sol";
import { SuperformVault } from "src/vault/SuperformVault.sol";
import { ERC20Mock } from "test/mocks/ERC20Mock.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RegisterSuperPositions is Script {
    // Add storage variables
    Create3Deployer public deployer;

    function registerSuperPositions(uint64 chainId) public {
        vm.startBroadcast();
        address superPositions = 0xAA1e1fBa73CE05245f84108253bD315b3Cf0Cf67;

        SuperRegistry superRegistryContract = SuperRegistry(0x06008e3dbf33a6A1864bDaafce8d8603BBFD3e3d);
        superRegistryContract.setAddress(superRegistryContract.SUPER_POSITIONS_ID(), superPositions);

        vm.stopBroadcast();
    }
}
