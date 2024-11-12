// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    ModuleKitUserOp,
    AccountInstance,
    UserOpData
} from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";

// Superform
import { BaseTest } from "../BaseTest.t.sol";
import { Deposit4626Module } from "src/modules/Deposit4626Module.sol";
import { IRelayerSentinel } from "src/interfaces/sentinels/IRelayerSentinel.sol";
import { ISentinel } from "src/interfaces/sentinels/ISentinel.sol";

abstract contract ModulesShared is BaseTest, RhinestoneModuleKit {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    Deposit4626Module public deposit4626Module;
    AccountInstance public instance;

    function setUp() public virtual override {
        super.setUp();

        // Initialize the RhinestoneModuleKit
        init();

        // Initialize the modules
        deposit4626Module =
            new Deposit4626Module(address(superRegistrySrc), address(deposit4626MintSuperPositionsDecoder));

        superRbacSrc.setRole(address(deposit4626Module), superRbacSrc.RELAYER_SENTINEL_NOTIFIER(), true);

        ISentinel(address(relayerSentinelSrc)).addDecoderToWhitelist(address(deposit4626MintSuperPositionsDecoder));

        vm.selectFork(arbitrumFork);
        superRbacDst.setRole(address(deposit4626Module), superRbacDst.RELAYER_SENTINEL_NOTIFIER(), true);

        vm.selectFork(mainnetFork);

        // Initialize the account instance
        instance = makeAccountInstance("SuperformAccount");
        vm.label(instance.account, "SuperformAccount");

        // Install the modules
        instance.installModule(MODULE_TYPE_EXECUTOR, address(deposit4626Module), "");

        vm.startPrank(DEPLOYER);
        // Set relayer sentinel
        deposit4626Module.setRelayerSentinel(address(relayerSentinelSrc));
    }

    modifier whenAccountHasTokens() {
        _getTokens(address(wethVault.asset()), instance.account, EXTRA_LARGE);
        _;
    }
}
