// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC7579Account } from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/kernel/types/Constants.sol";

// Tests
import { BaseTest } from "../BaseTest.t.sol";
import { console2 } from "forge-std/console2.sol";

// Superform
import { ISuperExecutor } from "../../src/core/interfaces/ISuperExecutor.sol";
import { BootstrapConfig, INexusBootstrap } from "../../src/vendor/nexus/INexusBootstrap.sol";
import { IERC7484 } from "../../src/vendor/nexus/IERC7484.sol";
import { MockRegistry } from "../mocks/MockRegistry.sol";
import { MockAcrossHook } from "../mocks/MockAcrossHook.sol";
import { MockTargetExecutor } from "../mocks/MockTargetExecutor.sol";

import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";

contract CrossChainNexusAccountCreation is BaseTest {
    ISuperExecutor public superExecutorOnBase;
    ISuperExecutor public superExecutorOnETH;
    ISuperExecutor public superExecutorOnOP;

    MockTargetExecutor public mockTargetExecutorOnETH;

    address public underlyingBase_USDC;
    address public underlyingETH_USDC;

    address public validatorOnETH;

    INexusBootstrap nexusBootstrap;

    AccountInstance public instanceOnBase;
    address public accountBase;

    MockAcrossHook public mockAcrossHook;

    uint256 public constant WARP_START_TIME = 1_740_137_231;

    function setUp() public override {
        super.setUp();

        vm.selectFork(FORKS[ETH]);

        underlyingBase_USDC = existingUnderlyingTokens[BASE][USDC_KEY];
        underlyingETH_USDC = existingUnderlyingTokens[ETH][USDC_KEY];

        // Set up the super executors
        superExecutorOnBase = ISuperExecutor(_getContract(BASE, SUPER_EXECUTOR_KEY));
        superExecutorOnETH = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
        superExecutorOnOP = ISuperExecutor(_getContract(OP, SUPER_EXECUTOR_KEY));

        mockTargetExecutorOnETH = MockTargetExecutor(_getContract(ETH, MOCK_TARGET_EXECUTOR_KEY));
        validatorOnETH = _getContract(ETH, SUPER_MERKLE_VALIDATOR_KEY);

        nexusBootstrap = INexusBootstrap(CHAIN_1_NEXUS_BOOTSTRAP);
        vm.label(address(nexusBootstrap), "NexusBootstrap");

        instanceOnBase = accountInstances[BASE];
        accountBase = accountInstances[BASE].account;
    }

    function test_Bridge_To_ETH_And_Create_Nexus_Account() public {
        // ETH IS DST
        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME);

        mockTargetExecutorOnETH.setNexusFactory(CHAIN_1_NEXUS_FACTORY);

        // PREPARE ETH DATA
        // create validators
        BootstrapConfig[] memory validators = new BootstrapConfig[](1);
        validators[0] = BootstrapConfig({ module: validatorOnETH, data: abi.encode(this) });
        // create executors
        BootstrapConfig[] memory executors = new BootstrapConfig[](1);
        executors[0] = BootstrapConfig({ module: address(superExecutorOnETH), data: "" });
        // create hooks
        BootstrapConfig memory hook = BootstrapConfig({ module: address(0), data: "" });
        // create fallbacks
        BootstrapConfig[] memory fallbacks = new BootstrapConfig[](0);
        address[] memory attesters = new address[](1);
        attesters[0] = address(MANAGER);
        uint8 threshold = 1;
        MockRegistry nexusRegistry = new MockRegistry();
        bytes memory initData = nexusBootstrap.getInitNexusCalldata(
            validators, executors, hook, fallbacks, IERC7484(nexusRegistry), attesters, threshold
        );
        bytes memory destinationMessage = abi.encode(initData, bytes32(keccak256("SomeSaltForAccountCreation")));

        // BASE IS SRC
        SELECT_FORK_AND_WARP(BASE, WARP_START_TIME + 30 days);

        mockAcrossHook = new MockAcrossHook(SPOKE_POOL_V3_ADDRESSES[BASE], _getContract(BASE, SUPER_MERKLE_VALIDATOR_KEY));
        vm.label(address(mockAcrossHook), "MockAcrossHook");

        deal(underlyingBase_USDC, accountBase, 1e18);

        // PREPARE BASE DATA
        address[] memory srcHooksAddresses = new address[](2);
        srcHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[1] = address(mockAcrossHook);

        bytes[] memory srcHooksData = new bytes[](2);
        srcHooksData[0] = _createApproveHookData(underlyingBase_USDC, SPOKE_POOL_V3_ADDRESSES[BASE], 1e18, false);
        srcHooksData[1] = _createAcrossV3ReceiveFundsAndCreateAccount(
            underlyingBase_USDC, underlyingETH_USDC, 1e18, 1e18, ETH, false, destinationMessage
        );

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: srcHooksAddresses, hooksData: srcHooksData });
        UserOpData memory srcUserOpData = _getExecOps(instanceOnBase, superExecutorOnBase, abi.encode(entryToExecute));

        // EXECUTE ETH
        _processAcrossV3MessageWithoutDestinationAccount(BASE, ETH, WARP_START_TIME + 30 days, executeOp(srcUserOpData));

        // check account
        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME);

        address createdAccount = mockTargetExecutorOnETH.nexusCreatedAccount();
        uint256 tokenBalanceOfCreatedAccount = IERC20(underlyingETH_USDC).balanceOf(createdAccount);
        assertEq(tokenBalanceOfCreatedAccount, 1e18);

        assertEq(
            IERC7579Account(createdAccount).isModuleInstalled(MODULE_TYPE_EXECUTOR, address(superExecutorOnETH), ""),
            true
        );
        assertEq(
            IERC7579Account(createdAccount).isModuleInstalled(MODULE_TYPE_VALIDATOR, address(validatorOnETH), ""), true
        );
        assertEq(
            IERC7579Account(createdAccount).isModuleInstalled(
                MODULE_TYPE_EXECUTOR, address(mockTargetExecutorOnETH), ""
            ),
            false
        );
    }
}
