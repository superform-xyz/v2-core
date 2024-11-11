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
import { Deposit4626Module } from "src/modules/Deposit4626Module.sol";
import { SuperformVault } from "src/vault/SuperformVault.sol";
import { ERC20Mock } from "test/mocks/ERC20Mock.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployV2Core is Script {
    // Add storage variables
    Create3Deployer public deployer;
    address public constant CREATE3 = 0xd468A8f2f0CF8c905FC95dE67a94C1f8feaa3c8B;
    address public constant DEPLOYER = 0x48aB8AdF869Ba9902Ad483FB1Ca2eFDAb6eabe92;
    address public constant RELAYER = 0x8C91d7EADfFc9F9921092cA14C3e498cD8cDe0d3;
    address public constant WETH = 0x4200000000000000000000000000000000000006;

    function deploy(uint64 chainId) public {
        vm.startBroadcast();

        // Initialize Create3Deployer
        deployer = Create3Deployer(CREATE3);

        address superRbac = deployer.deploy(
            keccak256("SUPER_RBAC_V3"), abi.encodePacked(type(SuperRbac).creationCode, abi.encode(DEPLOYER))
        );

        address superRegistry = deployer.deploy(
            keccak256("SUPER_REGISTRY_V3"), abi.encodePacked(type(SuperRegistry).creationCode, abi.encode(DEPLOYER))
        );

        address relayerSentinel = deployer.deploy(
            keccak256("RELAYER_SENTINEL_V3"),
            abi.encodePacked(type(RelayerSentinel).creationCode, abi.encode(superRegistry))
        );

        SuperRbac superRbacContract = SuperRbac(superRbac);
        superRbacContract.setRole(DEPLOYER, superRbacContract.ADMIN_ROLE(), true);
        superRbacContract.setRole(DEPLOYER, superRbacContract.HOOK_REGISTRATION_ROLE(), true);
        superRbacContract.setRole(DEPLOYER, superRbacContract.HOOK_EXECUTOR_ROLE(), true);

        superRbacContract.setRole(DEPLOYER, superRbacContract.SENTINELS_MANAGER(), true);
        superRbacContract.setRole(DEPLOYER, superRbacContract.RELAYER_SENTINEL_MANAGER(), true);

        SuperRegistry superRegistryContract = SuperRegistry(superRegistry);
        superRegistryContract.setAddress(superRegistryContract.SUPER_RBAC_ID(), address(superRbacContract));
        superRegistryContract.setAddress(superRegistryContract.RELAYER_ID(), RELAYER);
        superRegistryContract.setAddress(superRegistryContract.RELAYER_SENTINEL_ID(), address(relayerSentinel));

        address deposit4626MintSuperPositionsDecoder;
        address deposit4626Module;
        address superformVault;
        address superPositions;
        // just for Base Sepolia
        if (chainId == 0) {
            superformVault = deployer.deploy(
                keccak256("SUPERFORM_VAULT_V3"),
                abi.encodePacked(type(SuperformVault).creationCode, abi.encode(IERC20(WETH), "SuperWETHVault", "sWETH"))
            );

            deposit4626MintSuperPositionsDecoder = deployer.deploy(
                keccak256("DEPOSIT_4626_MINT_SUPER_POSITIONS_DECODER_V3"),
                abi.encodePacked(type(Deposit4626MintSuperPositionsDecoder).creationCode)
            );
            deposit4626Module = deployer.deploy(
                keccak256("DEPOSIT_4626_MODULE_V3"),
                abi.encodePacked(
                    type(Deposit4626Module).creationCode,
                    abi.encode(superRegistry, deposit4626MintSuperPositionsDecoder)
                )
            );

            Deposit4626Module(deposit4626Module).setRelayerSentinel(relayerSentinel);
            ISentinel(relayerSentinel).addModuleToWhitelist(deposit4626Module);
            ISentinel(relayerSentinel).addDecoderToWhitelist(deposit4626MintSuperPositionsDecoder);
            superRegistryContract.setAddress(superRegistryContract.SUPER_POSITIONS_ID(), superPositions);
        } else if (chainId == 1) {
            // just for SuperChain
            superPositions = deployer.deploy(
                keccak256("SUPER_POSITIONS_V3"),
                abi.encodePacked(type(SuperPositions).creationCode, abi.encode(superRegistry, 18))
            );
            superRegistryContract.setAddress(superRegistryContract.SUPER_POSITIONS_ID(), superPositions);
        }

        // Log deployed addresses
        console2.log("SuperRBAC deployed to:", superRbac);
        console2.log("SuperRegistry deployed to:", superRegistry);
        console2.log("RelayerSentinel deployed to:", relayerSentinel);
        if (chainId == 0) {
            console2.log("SuperformVault deployed to:", superformVault);
            console2.log("Deposit4626MintSuperPositionsDecoder deployed to:", deposit4626MintSuperPositionsDecoder);
            console2.log("Deposit4626Module deployed to:", deposit4626Module);
        } else if (chainId == 1) {
            console2.log("SuperPositions deployed to:", superPositions);
        }

        vm.stopBroadcast();
    }
}
