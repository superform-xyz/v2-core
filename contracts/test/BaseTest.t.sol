// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Superform
import { ISuperRbac } from "src/interfaces/ISuperRbac.sol";
import { ISuperRegistry } from "src/interfaces/ISuperRegistry.sol";
import { ISuperRbac } from "src/interfaces/ISuperRbac.sol";
import { ISuperformVault } from "src/interfaces/ISuperformVault.sol";
import { ISentinelDecoder } from "src/interfaces/sentinels/ISentinelDecoder.sol";
import { IRelayerSentinel } from "src/interfaces/sentinels/IRelayerSentinel.sol";
import { ISentinel } from "src/interfaces/sentinels/ISentinel.sol";
import { ISuperPositions } from "src/interfaces/ISuperPositions.sol";

import { SuperRbac } from "src/settings/SuperRbac.sol";
import { SuperBridge } from "src/PoC/SuperBridge.sol";
import { SuperformVault } from "src/vault/SuperformVault.sol";
import { SuperRegistry } from "src/settings/SuperRegistry.sol";
import { SuperPositions } from "src/superpositions/SuperPositions.sol";
import { RelayerSentinel } from "src/sentinels/RelayerSentinel.sol";
import { Deposit4626MintSuperPositionsDecoder } from "src/sentinels/Deposit4626MintSuperPositionsDecoder.sol";

import { Types } from "./utils/Types.sol";
import { Events } from "./utils/Events.sol";
import { Helpers } from "./utils/Helpers.sol";
import { ERC20Mock } from "./mocks/ERC20Mock.sol";
import { console } from "forge-std/console.sol";

abstract contract BaseTest is Types, Events, Helpers {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public user1;
    address public user2;

    ERC20Mock public wethMock;

    ISuperformVault public wethVault;
    ISuperRegistry public superRegistrySrc;
    ISuperRegistry public superRegistryDst;
    ISuperRbac public superRbacSrc;
    ISuperRbac public superRbacDst;
    ISuperPositions public superPositions;
    ISentinelDecoder public deposit4626MintSuperPositionsDecoder;
    IRelayerSentinel public relayerSentinelSrc;
    IRelayerSentinel public relayerSentinelDst;
    uint256 public mainnetFork;
    uint256 public arbitrumFork;
    string public mainnetUrl = vm.envString("ETHEREUM_RPC_URL");
    string public arbitrumUrl = vm.envString("ARBITRUM_RPC_URL");
    address public RELAYER = address(0x777);
    address public DEPLOYER = address(this);

    function setUp() public virtual {
        arbitrumFork = vm.createSelectFork(arbitrumUrl);
        mainnetFork = vm.createSelectFork(mainnetUrl);

        // deploy accounts
        user1 = _deployAccount(USER1_KEY, "USER1");
        user2 = _deployAccount(USER2_KEY, "USER2");

        // deploy tokens
        wethMock = _deployToken("Wrapped Ether", "WETH", 18);

        // deploy contracts
        superRbacSrc = ISuperRbac(new SuperRbac(DEPLOYER));
        superRegistrySrc = ISuperRegistry(new SuperRegistry(DEPLOYER));
        wethVault = ISuperformVault(new SuperformVault(IERC20(address(wethMock)), "WETH-Vault", "WETH-Vault"));
        deposit4626MintSuperPositionsDecoder = ISentinelDecoder(new Deposit4626MintSuperPositionsDecoder());
        relayerSentinelSrc = IRelayerSentinel(new RelayerSentinel(address(superRegistrySrc)));

        vm.selectFork(arbitrumFork);
        superRbacDst = ISuperRbac(new SuperRbac(DEPLOYER));
        superRegistryDst = ISuperRegistry(new SuperRegistry(DEPLOYER));
        superPositions = ISuperPositions(new SuperPositions(address(superRegistryDst), 18));
        relayerSentinelDst = IRelayerSentinel(new RelayerSentinel(address(superRegistryDst)));

        vm.selectFork(mainnetFork);
        // labeling
        vm.label(address(wethVault), "wethVault");
        vm.label(address(superRegistrySrc), "superRegistrySrc");
        vm.label(address(superRegistryDst), "superRegistryDst");
        vm.label(address(superRbacSrc), "superRbacSrc");
        vm.label(address(superRbacDst), "superRbacDst");
        vm.label(address(deposit4626MintSuperPositionsDecoder), "deposit4626MintSuperPositionsDecoder");
        vm.label(address(relayerSentinelSrc), "relayerSentinelSrc");
        vm.label(address(relayerSentinelDst), "relayerSentinelDst");
        vm.label(address(superPositions), "superPositions");
        // post-deployment configuration
        _postDeploymentSetup();
    }

    function _postDeploymentSetup() private {
        // - set roles for this address
        superRbacSrc.setRole(DEPLOYER, superRbacSrc.ADMIN_ROLE(), true);
        superRbacSrc.setRole(DEPLOYER, superRbacSrc.HOOK_REGISTRATION_ROLE(), true);
        superRbacSrc.setRole(DEPLOYER, superRbacSrc.HOOK_EXECUTOR_ROLE(), true);

        superRbacSrc.setRole(DEPLOYER, superRbacSrc.SENTINELS_MANAGER(), true);
        superRbacSrc.setRole(DEPLOYER, superRbacSrc.RELAYER_SENTINEL_MANAGER(), true);

        // - register addresses to the registry
        superRegistrySrc.setAddress(superRegistrySrc.SUPER_RBAC_ID(), address(superRbacSrc));
        superRegistrySrc.setAddress(superRegistrySrc.RELAYER_ID(), RELAYER);
        superRegistrySrc.setAddress(superRegistrySrc.RELAYER_SENTINEL_ID(), address(relayerSentinelSrc));

        ISentinel(address(relayerSentinelSrc)).addDecoderToWhitelist(address(deposit4626MintSuperPositionsDecoder));

        vm.selectFork(arbitrumFork);

        superRbacDst.setRole(DEPLOYER, superRbacDst.ADMIN_ROLE(), true);
        superRbacDst.setRole(DEPLOYER, superRbacDst.HOOK_REGISTRATION_ROLE(), true);
        superRbacDst.setRole(DEPLOYER, superRbacDst.HOOK_EXECUTOR_ROLE(), true);

        superRbacDst.setRole(DEPLOYER, superRbacDst.SENTINELS_MANAGER(), true);
        superRbacDst.setRole(DEPLOYER, superRbacDst.RELAYER_SENTINEL_MANAGER(), true);

        superRegistryDst.setAddress(superRegistryDst.SUPER_RBAC_ID(), address(superRbacDst));
        superRegistryDst.setAddress(superRegistryDst.RELAYER_ID(), RELAYER);
        superRegistryDst.setAddress(superRegistryDst.RELAYER_SENTINEL_ID(), address(relayerSentinelDst));

        ISentinel(address(relayerSentinelDst)).addDecoderToWhitelist(address(deposit4626MintSuperPositionsDecoder));

        vm.selectFork(mainnetFork);
    }
}
