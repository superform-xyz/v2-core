// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    ModuleKitUserOp,
    AccountInstance,
    UserOpData
} from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";

// Superform
import { BaseTest } from "./BaseTest.t.sol";
import { Deposit4626 } from "src/intents/Deposit4626.sol";
import { IRelayerSentinel } from "src/interfaces/sentinels/IRelayerSentinel.sol";

abstract contract IntentsShared is BaseTest, RhinestoneModuleKit {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    Deposit4626 public deposit4626Module;
    AccountInstance public instance;

    function setUp() public virtual override {
        super.setUp();

        // Initialize the RhinestoneModuleKit
        init();

        // Initialize the modules
        deposit4626Module = new Deposit4626(address(wethVault), address(superRegistry));

        // Initialize the account instance
        instance = makeAccountInstance("SuperformAccount");
        vm.label(instance.account, "SuperformAccount");

        // Install the modules
        instance.installModule(MODULE_TYPE_EXECUTOR, address(deposit4626Module), "");

        // Set relayer sentinel & intents notification type
        deposit4626Module.setRelayerSentinel(address(relayerSentinel));
        relayerSentinel.setIntentNotificationType(
            address(deposit4626Module), IRelayerSentinel.IntentNotificationType.Deposit4626
        );
    }

    modifier whenAccountHasTokens() {
        _getTokens(address(wethVault.asset()), instance.account, EXTRA_LARGE);
        _;
    }
}
