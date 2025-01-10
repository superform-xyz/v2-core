// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MODULE_TYPE_HOOK } from "modulekit/accounts/kernel/types/Constants.sol";
import { AccountInstance, UserOpData, ModuleKitHelpers } from "modulekit/ModuleKit.sol";

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

// Superform
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../../../src/interfaces/accounting/ISuperLedger.sol";

import { LockFundsAccountHook } from "../../../src/account-hooks/LockFundsAccountHook.sol";
import { BaseTest } from "../../BaseTest.t.sol";

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
            _createDepositHookData(account, bytes32("ERC4626YieldSourceOracle"), yieldSourceAddress, amount, false);
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
            _createDepositHookData(account, bytes32("ERC4626YieldSourceOracle"), yieldSourceAddress, amount, false);
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
            _createDepositHookData(account, bytes32("ERC4626YieldSourceOracle"), yieldSourceAddress, amount, false);
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
    
}
