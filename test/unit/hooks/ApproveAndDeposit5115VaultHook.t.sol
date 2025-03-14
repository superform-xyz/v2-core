// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Tests
import { BaseTest } from "../../BaseTest.t.sol";

// Superform
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../../../src/core/interfaces/accounting/ISuperLedger.sol";

// Vault Interfaces
import { IStandardizedYield } from "../../../src/vendor/pendle/IStandardizedYield.sol";

// External
import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract ApproveAndDeposit5115VaultHook is BaseTest {
    IStandardizedYield public vaultInstance5115ETH;

    address public underlyingETH_sUSDe;

    address public yieldSourceOracle5115;
    address public yieldSource5115AddressSUSDe;

    address public accountETH;
    AccountInstance public instanceOnETH;

    ISuperExecutor public superExecutorOnETH;

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);

        underlyingETH_sUSDe = existingUnderlyingTokens[ETH][SUSDE_KEY];

        yieldSource5115AddressSUSDe = realVaultAddresses[ETH][ERC5115_VAULT_KEY][PENDLE_ETHENA_KEY][SUSDE_KEY];

        vaultInstance5115ETH = IStandardizedYield(yieldSource5115AddressSUSDe);

        yieldSourceOracle5115 = _getContract(ETH, "ERC5115YieldSourceOracle");

        superExecutorOnETH = ISuperExecutor(_getContract(ETH, "SuperExecutor"));

        accountETH = accountInstances[ETH].account;

        instanceOnETH = accountInstances[ETH];
    }

    function test_ApproveAndDeposit5115VaultHook() public {
        vm.selectFork(FORKS[ETH]);

        uint256 amount = 1e8;

        uint256 accountSUSDEStartBalance = IERC20(underlyingETH_sUSDe).balanceOf(accountETH);

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createApproveAndDeposit5115VaultHookData(
            bytes4(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)),
            yieldSource5115AddressSUSDe,
            underlyingETH_sUSDe,
            amount,
            0,
            false,
            false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnETH, superExecutorOnETH, abi.encode(entry));

        vm.expectEmit(true, true, true, false);
        emit IStandardizedYield.Deposit(accountETH, accountETH, underlyingETH_sUSDe, amount, amount);
        executeOp(userOpData);

        // Check asset balances
        assertEq(IERC20(underlyingETH_sUSDe).balanceOf(accountETH), accountSUSDEStartBalance - amount);

        // Check vault shares balances
        assertEq(vaultInstance5115ETH.balanceOf(accountETH), amount);
    }
}
