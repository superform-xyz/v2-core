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
import { SuperRbac } from "src/settings/SuperRbac.sol";
import { SuperBridge } from "src/PoC/SuperBridge.sol";
import { SuperformVault } from "src/vault/SuperformVault.sol";
import { SuperRegistry } from "src/settings/SuperRegistry.sol";
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
    ISuperRegistry public superRegistry;
    ISuperRbac public superRbac;

    ISentinelDecoder public deposit4626MintSuperPositionsDecoder;
    IRelayerSentinel public relayerSentinel;
    uint256 public mainnetFork;
    string public mainnetUrl = vm.envString("ETHEREUM_RPC_URL");
    address public RELAYER = address(0x777);
    address public DEPLOYER = address(this);

    function setUp() public virtual {
        mainnetFork = vm.createSelectFork(mainnetUrl, 19_274_877);

        // deploy accounts
        user1 = _deployAccount(USER1_KEY, "USER1");
        user2 = _deployAccount(USER2_KEY, "USER2");

        // deploy tokens
        wethMock = _deployToken("Wrapped Ether", "WETH", 18);

        // deploy contracts
        superRbac = ISuperRbac(new SuperRbac(DEPLOYER));
        superRegistry = ISuperRegistry(new SuperRegistry(DEPLOYER));
        wethVault = ISuperformVault(new SuperformVault(IERC20(address(wethMock)), "WETH-Vault", "WETH-Vault"));
        deposit4626MintSuperPositionsDecoder = ISentinelDecoder(new Deposit4626MintSuperPositionsDecoder());
        relayerSentinel = IRelayerSentinel(new RelayerSentinel(address(superRegistry)));

        // labeling
        vm.label(address(wethVault), "wethVault");
        vm.label(address(superRegistry), "superRegistry");
        vm.label(address(superRbac), "superRbac");
        vm.label(address(deposit4626MintSuperPositionsDecoder), "deposit4626MintSuperPositionsDecoder");
        vm.label(address(relayerSentinel), "relayerSentinel");

        // post-deployment configuration
        _postDeploymentSetup();
    }

    function _postDeploymentSetup() private {
        // - set roles for this address
        superRbac.setRole(DEPLOYER, superRbac.ADMIN_ROLE(), true);
        superRbac.setRole(DEPLOYER, superRbac.HOOK_REGISTRATION_ROLE(), true);
        superRbac.setRole(DEPLOYER, superRbac.HOOK_EXECUTOR_ROLE(), true);

        superRbac.setRole(DEPLOYER, superRbac.SENTINELS_MANAGER(), true);
        superRbac.setRole(DEPLOYER, superRbac.RELAYER_SENTINEL_MANAGER(), true);

        // - register addresses to the registry
        superRegistry.setAddress(superRegistry.SUPER_RBAC_ID(), address(superRbac));
        superRegistry.setAddress(superRegistry.RELAYER_ID(), RELAYER);
        superRegistry.setAddress(superRegistry.RELAYER_SENTINEL_ID(), address(relayerSentinel));

        ISentinel(address(relayerSentinel)).addDecoderToWhitelist(address(deposit4626MintSuperPositionsDecoder));
    }

    modifier calledBy(address from_) {
        _resetCaller(from_);
        _;
    }

    modifier userWithRole(address user, bytes32 role_) {
        superRbac.setRole(user, role_, true);
        _;
    }

    modifier userWithoutRole(address user, bytes32 role_) {
        superRbac.setRole(user, role_, false);
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
