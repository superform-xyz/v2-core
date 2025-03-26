// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Tests
import { BaseTest } from "../BaseTest.t.sol";
import { console2 } from "forge-std/console2.sol";

// Superform
import { ISuperExecutor } from "../../src/core/interfaces/ISuperExecutor.sol";

// Vault Interfaces
import { IStandardizedYield } from "../../src/vendor/pendle/IStandardizedYield.sol";
import { IERC7540 } from "../../src/vendor/vaults/7540/IERC7540.sol";

// External
import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IRoot {
    function endorsed(address user) external view returns (bool);
}

contract MultiVaultDepositFlow is BaseTest {
    IStandardizedYield public vaultInstance5115ETH;
    IERC7540 public vaultInstance7540ETH;

    address public underlyingETH_USDC;
    address public underlyingETH_sUSDe;

    address public yieldSourceOracle5115;
    address public yieldSource5115AddressSUSDe;

    address public yieldSourceOracle7540;
    address public yieldSource7540AddressUSDC;

    address public accountETH;
    AccountInstance public instanceOnETH;

    ISuperExecutor public superExecutorOnETH;

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);

        underlyingETH_USDC = existingUnderlyingTokens[ETH][USDC_KEY];
        underlyingETH_sUSDe = existingUnderlyingTokens[ETH][SUSDE_KEY];

        yieldSource5115AddressSUSDe = realVaultAddresses[ETH][ERC5115_VAULT_KEY][PENDLE_ETHENA_KEY][SUSDE_KEY];

        yieldSource7540AddressUSDC = realVaultAddresses[ETH][ERC7540FullyAsync_KEY][CENTRIFUGE_USDC_VAULT_KEY][USDC_KEY];

        vaultInstance5115ETH = IStandardizedYield(yieldSource5115AddressSUSDe);
        vaultInstance7540ETH = IERC7540(yieldSource7540AddressUSDC);

        yieldSourceOracle5115 = _getContract(ETH, "ERC5115YieldSourceOracle");

        yieldSourceOracle7540 = _getContract(ETH, "ERC7540YieldSourceOracle");

        superExecutorOnETH = ISuperExecutor(_getContract(ETH, "SuperExecutor"));

        accountETH = accountInstances[ETH].account;

        instanceOnETH = accountInstances[ETH];
    }

    function test_MultiVault_Deposit_Flow() public {
        vm.selectFork(FORKS[ETH]);

        uint256 amount = 1e8;
        uint256 amountPerVault = amount / 2;

        uint256 accountUSDCStartBalance = IERC20(underlyingETH_USDC).balanceOf(accountETH);
        uint256 accountSUSDEStartBalance = IERC20(underlyingETH_sUSDe).balanceOf(accountETH);

        address[] memory hooksAddresses = new address[](4);
        hooksAddresses[0] = _getHookAddress(ETH, "ApproveERC20Hook");
        hooksAddresses[1] = _getHookAddress(ETH, "RequestDeposit7540VaultHook");
        hooksAddresses[2] = _getHookAddress(ETH, "ApproveERC20Hook");
        hooksAddresses[3] = _getHookAddress(ETH, "Deposit5115VaultHook");
        vm.mockCall(
            0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC,
            abi.encodeWithSelector(IRoot.endorsed.selector, accountETH),
            abi.encode(true)
        );
        bytes[] memory hooksData = new bytes[](4);
        hooksData[0] = _createApproveHookData(underlyingETH_USDC, yieldSource7540AddressUSDC, amountPerVault, false);
        hooksData[1] = _createRequestDeposit7540VaultHookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), yieldSource7540AddressUSDC, amountPerVault, true
        );
        hooksData[2] = _createApproveHookData(underlyingETH_sUSDe, yieldSource5115AddressSUSDe, amountPerVault, false);
        hooksData[3] = _createDeposit5115VaultHookData(
            bytes4(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)),
            yieldSource5115AddressSUSDe,
            underlyingETH_sUSDe,
            amountPerVault,
            0,
            true,
            false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnETH, superExecutorOnETH, abi.encode(entry));

        vm.expectEmit(true, true, true, false);
        emit IERC7540.DepositRequest(accountETH, accountETH, 0, accountETH, amountPerVault);
        vm.expectEmit(true, true, true, false);
        emit IStandardizedYield.Deposit(accountETH, accountETH, underlyingETH_sUSDe, amountPerVault, amountPerVault);
        executeOp(userOpData);

        // Check asset balances
        assertEq(IERC20(underlyingETH_USDC).balanceOf(accountETH), accountUSDCStartBalance - amountPerVault);
        assertEq(IERC20(underlyingETH_sUSDe).balanceOf(accountETH), accountSUSDEStartBalance - amountPerVault);

        // Check vault shares balances
        assertEq(vaultInstance5115ETH.balanceOf(accountETH), amountPerVault);

        vm.clearMockedCalls();
    }
}
