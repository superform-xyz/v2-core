// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import { Script } from "forge-std/Script.sol";
import "forge-std/console.sol";
import "src/relayer-contracts-poc/PoC/ECR20.sol";
import "src/relayer-contracts-poc/PoC/SuperBridge.sol";
import "src/relayer-contracts-poc/PoC/SuperVault.sol";
import "src/relayer-contracts-poc/PoC/OriginalVault.sol";

/*
== Logs ==
  Deploying on Destination Chain...
  SuperBridge deployed at: 0xc23e64FF756224a9f49C89A921dcE2F4da5b5146
  SuperVault deployed at: 0x8748F09Fd8E8D9C05aFce58c81E2E7dC8be29834
  SuperUSD deployed at: 0xc2c1ef95Cc34aCF24cDc5cD011f77F2bF1D5502c
  Deploying on Source Chain...
  SuperBridge deployed at: 0x5Ceb39773d11e51a8Ec24BDA70d27629E87418E0
  SuperVault deployed at: 0xD323d24469810AF385Dfa97ec58f0787f1a234D1
  SuperUSD deployed at: 0xF4417Af5416A8Dc21fD92cCf6F2a49eCc80d043D
*/

contract Deploy is Script {
    function run() external {
        // Load the private key from environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Deploy destination chain
        address superform = deployDstChain(deployerPrivateKey, deployer);

        // Deploy source chain
        deploySourceChain(deployerPrivateKey, deployer, superform);
    }

    function deploySourceChain(uint256 pk, address deployer, address superform) internal {
        console.log("Deploying on Source Chain...");

        vm.createSelectFork("base");
        vm.startBroadcast(pk);

        // Deploy SuperBridge on Chain A
        SuperBridge bridge = new SuperBridge(deployer); // Replace with relayer address

        // Mock asset for ERC4626 vault
        ERC20 asset = new ECR20("SuperUSD", "SUSD");

        // Deploy OriginalVault on Chain A, passing in the SuperBridge address
        OriginalVault vault = new OriginalVault(IERC20(asset), address(bridge), 11_155_111, superform);

        // 1000 SUSDs depositing to the deployer address
        uint256 amountToDeposit = 1000 * 10 ** asset.decimals();

        // Approve the vault to spend the specified amount of the asset on behalf of the deployer
        asset.approve(deployer, amountToDeposit);
        asset.approve(address(vault), amountToDeposit);

        // Approvals
        vault.deposit(amountToDeposit, deployer);

        vm.stopBroadcast();

        console.log("SuperBridge deployed at:", address(bridge));
        console.log("SuperVault deployed at:", address(vault));
        console.log("SuperUSD deployed at:", address(asset));
    }

    function deployDstChain(uint256 pk, address deployer) internal returns (address) {
        console.log("Deploying on Destination Chain...");

        // Working with the destination chain
        vm.createSelectFork("sepolia");
        vm.startBroadcast(pk);

        // Deploy SuperBridge on Chain B
        SuperBridge bridge = new SuperBridge(deployer); // Replace with relayer address

        // Mock asset for ERC4626 vault
        ERC20 asset = new ECR20("SuperUSD", "SUSD");

        // Deploy vault
        SuperVault vault = new SuperVault(IERC20(asset), address(bridge));

        vm.stopBroadcast();

        console.log("SuperBridge deployed at:", address(bridge));
        console.log("SuperVault deployed at:", address(vault));
        console.log("SuperUSD deployed at:", address(asset));

        return address(vault);
    }
}
