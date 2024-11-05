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
import { BaseTest } from "test/BaseTest.t.sol";
import { BorrowFromMockProtocolIntent } from "src/intents/BorrowFromMockProtocolIntent.sol";
import { DepositToSuperformVaultIntent } from "src/intents/DepositToSuperformVaultIntent.sol";
import { AddCollateralToMockProtocolIntent } from "src/intents/AddCollateralToMockProtocolIntent.sol";

import { ILendingAndBorrowMock } from "src/interfaces/mocks/ILendingAndBorrowMock.sol";
import { LendingAndBorrowingProtocolMock } from "src/mocks/LendingAndBorrowingProtocolMock.sol";

abstract contract IntentsShared is BaseTest, RhinestoneModuleKit {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    BorrowFromMockProtocolIntent public borrowFromMockProtocolIntent;
    DepositToSuperformVaultIntent public depositToSuperformVaultIntent;
    AddCollateralToMockProtocolIntent public addCollateralToMockProtocolIntent;
    ILendingAndBorrowMock public lendingAndBorrowingProtocolMock;
    AccountInstance public instance;

    uint256 mainnetFork;

    function setUp() public virtual override {
        // Create the fork
        string memory mainnetUrl = vm.envString("MAINNET_RPC_URL");
        mainnetFork = vm.createFork(mainnetUrl);
        vm.selectFork(mainnetFork);
        vm.rollFork(19_274_877);

        super.setUp();

        // Initialize the RhinestoneModuleKit
        init();

        // Setup lending and borrowing protocol mock
        lendingAndBorrowingProtocolMock =
            ILendingAndBorrowMock(address(new LendingAndBorrowingProtocolMock(address(wethVault), address(wethMock))));
        wethMock.mint(address(lendingAndBorrowingProtocolMock), EXTRA_LARGE);
        vm.label(address(lendingAndBorrowingProtocolMock), "lendingAndBorrowingProtocolMock");

        // Initialize the modules
        depositToSuperformVaultIntent = new DepositToSuperformVaultIntent(address(wethVault));
        borrowFromMockProtocolIntent = new BorrowFromMockProtocolIntent(address(lendingAndBorrowingProtocolMock));
        addCollateralToMockProtocolIntent =
            new AddCollateralToMockProtocolIntent(address(lendingAndBorrowingProtocolMock));

        // Initialize the account instance
        instance = makeAccountInstance("SuperformAccount");
        vm.label(instance.account, "SuperformAccount");

        // Install the modules
        instance.installModule(MODULE_TYPE_EXECUTOR, address(borrowFromMockProtocolIntent), "");
        instance.installModule(MODULE_TYPE_EXECUTOR, address(depositToSuperformVaultIntent), "");
        instance.installModule(MODULE_TYPE_EXECUTOR, address(addCollateralToMockProtocolIntent), "");
    }

    modifier whenAccountHasTokens() {
        _getTokens(address(wethVault.asset()), instance.account, EXTRA_LARGE);
        _;
    }
}
