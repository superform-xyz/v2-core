// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { SuperExecutor } from "../../../src/core/executors/SuperExecutor.sol";
import { MaliciousToken } from "../../mocks/MaliciousToken.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MockHook } from "../../mocks/MockHook.sol";
import { MockLedger, MockLedgerConfiguration } from "../../mocks/MockLedger.sol";

import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";
import { ISuperHook } from "../../../src/core/interfaces/ISuperHook.sol";

import { Helpers } from "../../utils/Helpers.sol";

import { InternalHelpers } from "../../InternalHelpers.sol";

import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance } from "modulekit/ModuleKit.sol";

contract SuperExecutorTest is Helpers, RhinestoneModuleKit, InternalHelpers {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    SuperExecutor public superExecutor;
    address public account;
    MockERC20 public token;
    MockHook public inflowHook;
    MockHook public outflowHook;
    MockLedger public ledger;
    MockLedgerConfiguration public ledgerConfig;
    address public feeRecipient;
    AccountInstance public instance;

    function setUp() public {
        instance = makeAccountInstance(keccak256(abi.encode("TEST")));
        account = instance.account;

        token = new MockERC20("Mock Token", "MTK", 18);
        feeRecipient = makeAddr("feeRecipient");

        inflowHook = new MockHook(ISuperHook.HookType.INFLOW, address(token));
        outflowHook = new MockHook(ISuperHook.HookType.OUTFLOW, address(token));

        ledger = new MockLedger();
        ledgerConfig = new MockLedgerConfiguration(address(ledger), feeRecipient, address(token), 100, account);

        superExecutor = new SuperExecutor(address(ledgerConfig));

        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
    }

    function test_Name() public view {
        assertEq(superExecutor.name(), "SuperExecutor");
    }

    function test_Version() public view {
        assertEq(superExecutor.version(), "0.0.1");
    }

    function test_IsModuleType() public view {
        assertTrue(superExecutor.isModuleType(MODULE_TYPE_EXECUTOR));
        assertFalse(superExecutor.isModuleType(1234));
    }

    function test_OnInstall() public view {
        assertTrue(superExecutor.isInitialized(account));
    }

    function test_OnInstall_RevertIf_AlreadyInitialized() public {
        AccountInstance memory newInstance = makeAccountInstance(keccak256(abi.encode("TEST")));
        address newAccount = newInstance.account;

        vm.startPrank(newAccount);

        vm.expectRevert(ISuperExecutor.ALREADY_INITIALIZED.selector);
        superExecutor.onInstall("");
        vm.stopPrank();
    }

    function test_OnUninstall() public {
        vm.startPrank(account);
        superExecutor.onUninstall("");
        vm.stopPrank();

        assertFalse(superExecutor.isInitialized(account));
    }

    function test_OnUninstall_RevertIf_NotInitialized() public {
        vm.startPrank(makeAddr("account"));
        vm.expectRevert(ISuperExecutor.NOT_INITIALIZED.selector);
        superExecutor.onUninstall("");
        vm.stopPrank();
    }

    function test_Execute_RevertIf_NotInitialized() public {
        vm.startPrank(makeAddr("account"));
        vm.expectRevert(ISuperExecutor.NOT_INITIALIZED.selector);
        superExecutor.execute("");
        vm.stopPrank();
    }

    function test_Execute_WithHooks() public {
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = address(inflowHook);
        hooksAddresses[1] = address(outflowHook);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] =
            _createDeposit4626HookData(bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(token), 1, false, false);
        hooksData[1] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(token), account, 1, false, false
        );

        vm.startPrank(account);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        superExecutor.execute(abi.encode(entry));
        vm.stopPrank();

        assertTrue(inflowHook.preExecuteCalled());
        assertTrue(inflowHook.postExecuteCalled());
        assertTrue(outflowHook.preExecuteCalled());
        assertTrue(outflowHook.postExecuteCalled());
    }

    function test_UpdateAccounting_Inflow() public {
        inflowHook.setOutAmount(1000);

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(inflowHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] =
            _createDeposit4626HookData(bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(token), 1, false, false);

        vm.startPrank(account);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        superExecutor.execute(abi.encode(entry));
        vm.stopPrank();
    }

    function test_UpdateAccounting_Outflow_WithFee() public {
        vm.startPrank(account);

        outflowHook.setOutAmount(1000);
        outflowHook.setUsedShares(500);
        ledger.setFeeAmount(100);

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(outflowHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(token), account, 1, false, false
        );

        _getTokens(address(token), account, 1000);

        assertGt(token.balanceOf(account), 0, "Account should have tokens");

        vm.startPrank(account);
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        superExecutor.execute(abi.encode(entry));
        vm.stopPrank();

        assertEq(token.balanceOf(feeRecipient), 100);
    }

    function test_UpdateAccounting_Outflow_RevertIf_InvalidAsset() public {
        MockHook invalidHook = new MockHook(ISuperHook.HookType.OUTFLOW, address(0));
        invalidHook.setOutAmount(1000);
        ledger.setFeeAmount(100);

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(invalidHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(token), account, 1, false, false
        );

        vm.startPrank(makeAddr("account"));
        superExecutor.onInstall("");

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        vm.expectRevert(ISuperExecutor.INSUFFICIENT_BALANCE_FOR_FEE.selector);
        superExecutor.execute(abi.encode(entry));
        vm.stopPrank();
    }

    function test_UpdateAccounting_Outflow_RevertIf_InsufficientBalance() public {
        outflowHook.setOutAmount(1000);
        ledger.setFeeAmount(100);

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(outflowHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(token), account, 1, false, false
        );

        vm.startPrank(account);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        vm.expectRevert(ISuperExecutor.INSUFFICIENT_BALANCE_FOR_FEE.selector);
        superExecutor.execute(abi.encode(entry));
        vm.stopPrank();
    }

    function test_UpdateAccounting_Outflow_RevertIf_FeeNotTransferred() public {
        MaliciousToken maliciousToken = new MaliciousToken();

        maliciousToken.blacklist(feeRecipient);

        MockHook maliciousHook = new MockHook(ISuperHook.HookType.OUTFLOW, address(maliciousToken));
        maliciousHook.setOutAmount(910);
        maliciousHook.setUsedShares(500);

        ledger.setFeeAmount(100);

        MockLedgerConfiguration maliciousConfig =
            new MockLedgerConfiguration(address(ledger), feeRecipient, address(maliciousToken), 100, account);
        superExecutor = new SuperExecutor(address(maliciousConfig));
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(maliciousHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(token), account, 1, false, false
        );

        vm.startPrank(address(this));
        maliciousToken.transfer(account, 1000);
        vm.stopPrank();

        assertGt(maliciousToken.balanceOf(account), 0, "Account should have tokens");

        vm.startPrank(account);
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        vm.expectRevert(ISuperExecutor.FEE_NOT_TRANSFERRED.selector);
        superExecutor.execute(abi.encode(entry));
        vm.stopPrank();
    }
}
