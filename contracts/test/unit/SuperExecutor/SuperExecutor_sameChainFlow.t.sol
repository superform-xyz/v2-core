// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MODULE_TYPE_HOOK } from "modulekit/accounts/kernel/types/Constants.sol";
import { AccountInstance, UserOpData, ModuleKitHelpers } from "modulekit/ModuleKit.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";    
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

// Superform
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../../../src/interfaces/accounting/ISuperLedger.sol";
import { ISuperRbac } from "../../../src/interfaces/ISuperRbac.sol";

import { LockFundsAccountHook } from "../../../src/account-hooks/LockFundsAccountHook.sol";
import { BaseTest } from "../../BaseTest.t.sol";

import { MockERC20 } from "../../mocks/MockERC20.sol";
import { Mock4626Vault } from "../../mocks/Mock4626Vault.sol";

import { console2 } from "forge-std/console2.sol";

contract SuperExecutor_sameChainFlow is BaseTest {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;


    IERC4626 public vaultInstance;
    address public yieldSourceAddress;
    address public yieldSourceOracle;
    address public underlying;
    address public account;
    AccountInstance public instance;
    ISuperExecutor public superExecutor;
    ISuperRbac public rbac;

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);
        underlying = existingUnderlyingTokens[1]["USDC"];

        yieldSourceAddress = realVaultAddresses[1]["ERC4626"]["MorphoVault"]["USDC"];
        yieldSourceOracle = _getContract(ETH, "ERC4626YieldSourceOracle");
        vaultInstance = IERC4626(yieldSourceAddress);
        account = accountInstances[ETH].account;
        instance = accountInstances[ETH];
        superExecutor = ISuperExecutor(_getContract(ETH, "SuperExecutor"));
        rbac = ISuperRbac(_getContract(ETH, "SuperRbac"));
    }

    function test_ShouldExecuteAll(uint256 amount) external {
        amount = _bound(amount);

        _getTokens(underlying, account, amount);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHook(ETH, "ApproveERC20Hook");
        hooksAddresses[1] = _getHook(ETH, "Deposit4626VaultHook");

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] =
            _createDepositHookData(account, bytes32("ERC4626YieldSourceOracle"), yieldSourceAddress, amount, false, uint8(0));
        uint256 sharesPreviewed = vaultInstance.previewDeposit(amount);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        executeOp(userOpData);

        uint256 accSharesAfter = vaultInstance.balanceOf(account);
        assertEq(accSharesAfter, sharesPreviewed);
    }

    function test_WhenHooksAreDefinedAndExecutionDataIsValid_Deposit_And_Withdraw_In_The_Same_Intent(uint256 amount)
        external
    {
        amount = _bound(amount);
        address[] memory hooksAddresses = new address[](3);
        hooksAddresses[0] = _getHook(ETH, "ApproveERC20Hook");
        hooksAddresses[1] = _getHook(ETH, "Deposit4626VaultHook");
        hooksAddresses[2] = _getHook(ETH, "Withdraw4626VaultHook");

        bytes[] memory hooksData = new bytes[](5);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] =
            _createDepositHookData(account, bytes32("ERC4626YieldSourceOracle"), yieldSourceAddress, amount, false, uint8(0));
        hooksData[2] = _createWithdrawHookData(
            account, bytes32("ERC4626YieldSourceOracle"), yieldSourceAddress, account, amount, false
        );
        // assure account has tokens
        _getTokens(underlying, account, amount);

        // it should execute all hooks
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        emit ISuperLedger.AccountingUpdated(account, yieldSourceOracle, yieldSourceAddress, false, amount, 1e18);
        executeOp(userOpData);

        uint256 accSharesAfter = vaultInstance.balanceOf(account);
        assertGt(accSharesAfter, 0);
    }

    function test_ExecuteWithMockHook(uint256 amount) external {
        amount = _bound(amount);

        address[] memory hooksAddresses = new address[](3);
        hooksAddresses[0] = _getHook(ETH, "ApproveERC20Hook");
        hooksAddresses[1] = _getHook(ETH, "Deposit4626VaultHook");
        hooksAddresses[2] = _getHook(ETH, "Withdraw4626VaultHook");

        bytes[] memory hooksData = new bytes[](5);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] =
            _createDepositHookData(account, bytes32("ERC4626YieldSourceOracle"), yieldSourceAddress, amount, false, uint8(0));
        hooksData[2] = _createWithdrawHookData(
            account, bytes32("ERC4626YieldSourceOracle"), yieldSourceAddress, account, amount, false
        );
        // assure account has tokens
        _getTokens(underlying, account, amount);

        LockFundsAccountHook hook = new LockFundsAccountHook(_getContract(ETH, "SuperRegistry"));
        vm.label(address(hook), "LockFundsAccountHook");
        instance.installModule({ moduleTypeId: MODULE_TYPE_HOOK, module: address(hook), data: "" });


         // it should execute all hooks
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        emit ISuperLedger.AccountingUpdated(account, yieldSourceOracle, yieldSourceAddress, false, amount, 1e18);
        executeOp(userOpData);

        uint256 accSharesAfter = vaultInstance.balanceOf(account);
        assertGt(accSharesAfter, 0);
    }

    function test_BenchmarkLockHook() external {
        uint256 amount = 1 ether;

        /**
            lock = true, unlock = false → 00000001 (1)
            lock = false, unlock = true → 00000010 (2)
            lock = true, unlock = true → 00000011 (3)
            lock = false, unlock = false → 00000000 (0)

            uint8 flags = (lock ? 1 : 0) | (unlock ? 2 : 0);
        */

        // create and install lock funds account hook
        LockFundsAccountHook hook = new LockFundsAccountHook(_getContract(ETH, "SuperRegistry"));
        vm.label(address(hook), "LockFundsAccountHook");
        instance.installModule({ moduleTypeId: MODULE_TYPE_HOOK, module: address(hook), data: "" });

        // set super position manager role
        rbac.setRole(address(this), rbac.SUPER_POSITION_MANAGER(), true);

        // create multiple erc20s to mark as locked
        MockERC20 _erc20;
        uint256 count = 50;
        for(uint256 i = 0; i < count;) {
            _erc20 = new MockERC20("MockERC20", "MRC20", 18);
            _erc20.mint(account, amount * 2);
            hook.lock(account, address(_erc20), amount);
            unchecked { ++i; }
        }

        hook.unlock(account, address(_erc20), amount);

        address[] memory hooksAddresses = new address[](2);
        bytes[] memory hooksData = new bytes[](2);
        hooksAddresses[0] = _getHook(ETH, "ApproveERC20Hook");
        hooksAddresses[1] = _getHook(ETH, "Deposit4626VaultHook");

        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] = _createDepositHookData(account, bytes32("ERC4626YieldSourceOracle"), yieldSourceAddress, amount, false, uint8(0));

        // assure account has tokens
        _getTokens(underlying, account, amount);

        // it should execute all hooks
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        emit ISuperLedger.AccountingUpdated(account, yieldSourceOracle, yieldSourceAddress, false, amount, 1e18);
        executeOp(userOpData);

        uint256 accSharesAfter = vaultInstance.balanceOf(account);
        assertGt(accSharesAfter, 0);

        // deposit into a mock 4626 to check the gas consumption
        Mock4626Vault mock4626 = new Mock4626Vault(IERC20(underlying), "MRC4626", "MRC4626");
        _getTokens(underlying, address(this), amount);
        IERC20(underlying).approve(address(mock4626), amount);
        mock4626.deposit(amount, address(this));

        // withdraw from the mock 4626
        mock4626.redeem(amount, address(this), address(this));

        // deposit simple
        _getTokens(underlying, address(this), amount);
        IERC20(underlying).approve(address(mock4626), amount);
        mock4626.depositSimple(amount, address(this));

        // redeem simple
        mock4626.redeemSimple(amount, address(this));

        // deposit batch simple
        /**
        uint256[] memory assets = new uint256[](10);
        for(uint256 i; i < 10;) {
            assets[i] = amount;
            unchecked { ++i; }
        }
        _getTokens(underlying, address(this), amount * 10);
        mock4626.depositBatchSimple(assets);    
         */
    }
    
}

