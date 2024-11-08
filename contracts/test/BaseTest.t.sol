// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Superform
import { ISuperRbac } from "src/interfaces/ISuperRbac.sol";
import { IRelayer } from "src/interfaces/relayer/IRelayer.sol";
import { ISentinel } from "src/interfaces/sentinels/ISentinel.sol";
import { ISuperRegistry } from "src/interfaces/ISuperRegistry.sol";
import { ISuperformVault } from "src/interfaces/ISuperformVault.sol";
import { IRelayerDecoder } from "src/interfaces/sentinels/IRelayerDecoder.sol";
import { IRelayerSentinel } from "src/interfaces/sentinels/IRelayerSentinel.sol";

import { SuperRbac } from "src/utils/SuperRbac.sol";
import { SuperBridge } from "src/PoC/SuperBridge.sol";
import { SuperformVault } from "src/vault/SuperformVault.sol";
import { SuperRegistryMock } from "src/mocks/SuperRegistryMock.sol";
import { RelayerSentinel } from "src/sentinels/RelayerSentinel.sol";
import { SuperformSentinel } from "src/sentinels/SuperformSentinel.sol";
import { RelayerSentinelDecoder } from "src/sentinels/RelayerSentinelDecoder.sol";

import { Types } from "./utils/Types.sol";
import { Events } from "./utils/Events.sol";
import { Helpers } from "./utils/Helpers.sol";
import { ERC20Mock } from "./mocks/ERC20Mock.sol";

abstract contract BaseTest is Types, Events, Helpers {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public user1;
    address public user2;

    ERC20Mock public wethMock;

    ISuperRbac public roles;
    IRelayer public relayer;
    ISentinel public sentinel;
    ISuperformVault public wethVault;
    ISuperRegistry public superRegistry;
    IRelayerDecoder public relayerDecoder;
    IRelayerSentinel public relayerSentinel;

    function setUp() public virtual {
        // deploy accounts
        user1 = _deployAccount(USER1_KEY, "USER1");
        user2 = _deployAccount(USER2_KEY, "USER2");

        // deploy tokens
        wethMock = _deployToken("Wrapped Ether", "WETH", 18);

        // deploy contracts
        roles = ISuperRbac(new SuperRbac(address(this)));
        relayer = IRelayer(address(new SuperBridge(address(0))));
        sentinel = ISentinel(new SuperformSentinel(address(this)));
        superRegistry = ISuperRegistry(new SuperRegistryMock(address(this)));
        wethVault = ISuperformVault(new SuperformVault(IERC20(address(wethMock)), "WETH-Vault", "WETH-Vault"));
        relayerDecoder = IRelayerDecoder(new RelayerSentinelDecoder());
        relayerSentinel = IRelayerSentinel(new RelayerSentinel(address(superRegistry), address(relayerDecoder)));

        // labeling
        vm.label(address(roles), "roles");
        vm.label(address(sentinel), "sentinel");
        vm.label(address(wethVault), "wethVault");
        vm.label(address(superRegistry), "superRegistry");
        vm.label(address(relayerDecoder), "relayerDecoder");
        vm.label(address(relayerSentinel), "relayerSentinel");

        // post-deployment configuration
        _postDeploymentSetup();
    }

    function _postDeploymentSetup() private {
        // - set roles for this address
        SuperRbac(address(roles)).setRole(address(this), superRegistry.ADMIN_ROLE(), true);
        SuperRbac(address(roles)).setRole(address(this), superRegistry.HOOK_REGISTRATION_ROLE(), true);
        SuperRbac(address(roles)).setRole(address(this), superRegistry.HOOK_EXECUTOR_ROLE(), true);

        SuperRbac(address(roles)).setRole(address(this), superRegistry.SENTINELS_MANAGER(), true);
        SuperRbac(address(roles)).setRole(address(this), superRegistry.RELAYER_SENTINEL_MANAGER(), true);

        // - register addresses to the registry
        SuperRegistryMock(address(superRegistry)).setAddress(ROLES_ID, address(roles));
        SuperRegistryMock(address(superRegistry)).setAddress(RELAYER_ID, address(relayer));
        SuperRegistryMock(address(superRegistry)).setAddress(RELAYER_SENTINEL_ID, address(relayerSentinel));
    }

    modifier calledBy(address from_) {
        _resetCaller(from_);
        _;
    }

    modifier userWithRole(address user, bytes32 role_) {
        SuperRbac(address(roles)).setRole(user, role_, true);
        _;
    }

    modifier userWithoutRole(address user, bytes32 role_) {
        SuperRbac(address(roles)).setRole(user, role_, false);
        _;
    }

    modifier inRange(uint256 _value, uint256 _min, uint256 _max) {
        vm.assume(_value >= _min && _value <= _max);
        _;
    }

    modifier targetApproved(address token_, address target_, address user_, uint256 amount_) {
        approveErc20(token_, user_, target_, amount_);
        _;
    }
}
