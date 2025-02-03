// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Tests
import { BaseTest } from "../BaseTest.t.sol";

// Superform
import { ISuperExecutor } from "../../src/core/interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../../src/core/interfaces/accounting/ISuperLedger.sol";

// Vault Interfaces
import { IStandardizedYield } from "../../src/core/interfaces/vendors/pendle/IStandardizedYield.sol";
import { IERC7540 } from "../../src/core/interfaces/vendors/vaults/7540/IERC7540.sol";

// External
import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract BridgeToMultiVaultDepositAndRedeemFlow is BaseTest {
    IStandardizedYield public vaultInstance5115ETH;
    IERC7540 public vaultInstance7540ETH;
    IERC4626 public vaultInstance4626OP;

    address public underlyingETH_USDC;
    address public underlyingETH_sUSDe;

    address public underlyingOP_USDC;

    address public underlyingBase_USDC;
    address public underlyingBase_WETH;

    address public yieldSourceOracleBase;
    address public yieldSourceOracleOP;

    address public yieldSourceOracle5115;
    address public yieldSource5115AddressSUSDe;

    address public yieldSourceOracle7540;
    address public yieldSource7540AddressUSDC;

    address public yieldSourceOracle4626;
    address public yieldSource4626AddressUSDC;

    address public accountBase;
    address public accountETH;
    address public accountOP;

    AccountInstance public instanceOnBase;
    AccountInstance public instanceOnETH;
    AccountInstance public instanceOnOP;

    ISuperExecutor public superExecutorOnBase;
    ISuperExecutor public superExecutorOnETH;
    ISuperExecutor public superExecutorOnOP;

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);

        underlyingETH_USDC = existingUnderlyingTokens[ETH]["USDC"];
        underlyingETH_sUSDe = existingUnderlyingTokens[ETH]["sUSDe"];

        underlyingOP_USDC = existingUnderlyingTokens[OP]["USDC"];

        underlyingBase_USDC = existingUnderlyingTokens[BASE]["USDC"];
        underlyingBase_WETH = existingUnderlyingTokens[BASE]["WETH"];

        yieldSourceOracle5115 = _getContract(ETH, ERC7540_YIELD_SOURCE_ORACLE_KEY);
        yieldSourceOracle7540 = _getContract(ETH, ERC7540_YIELD_SOURCE_ORACLE_KEY);

        yieldSourceOracle5115 = _getContract(OP, ERC7540_YIELD_SOURCE_ORACLE_KEY);
        yieldSourceOracle7540 = _getContract(OP, ERC7540_YIELD_SOURCE_ORACLE_KEY);

        yieldSourceOracle4626 = _getContract(BASE, ERC7540_YIELD_SOURCE_ORACLE_KEY);
        yieldSourceOracle4626 = _getContract(BASE, ERC7540_YIELD_SOURCE_ORACLE_KEY);

        vaultInstance5115ETH = IStandardizedYield(yieldSource5115AddressSUSDe);
        vaultInstance7540ETH = IERC7540(yieldSource7540AddressUSDC);
        vaultInstance4626OP = IERC4626(yieldSource4626AddressUSDC);

        accountBase = accountInstances[BASE].account;
        accountETH = accountInstances[ETH].account;
        accountOP = accountInstances[OP].account;

        instanceOnBase = accountInstances[BASE];
        instanceOnETH = accountInstances[ETH];
        instanceOnOP = accountInstances[OP];

        superExecutorOnBase = ISuperExecutor(_getContract(BASE, SUPER_EXECUTOR_KEY));
        superExecutorOnETH = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
        superExecutorOnOP = ISuperExecutor(_getContract(OP, SUPER_EXECUTOR_KEY));
    }

    function test_Bridge_ToMultiVault_Deposit_Flow() public {
        vm.selectFork(FORKS[ETH]);

        uint256 amount = 1e8;

        address[] memory hooksAddresses = new address[](5);
        hooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(BASE, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);
        hooksAddresses[2] = _getHookAddress(ETH, DEPOSIT_5115_VAULT_HOOK_KEY);
        hooksAddresses[3] = _getHookAddress(OP, DEPOSIT_4626_VAULT_HOOK_KEY);
        hooksAddresses[4] = _getHookAddress(ETH, DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](5);
        hooksData[0] = _createApproveHookData(underlyingBase_USDC, accountBase, amount);
        hooksData[1] 
        = _createAcrossSendFundsAndExecuteOnDstHookData(
          underlyingBase_USDC, 
          accountBase, 
          amount, 
          ETH, 
          CHAIN_1_SPOKE_POOL_V3_ADDRESS, 
          CHAIN_1_DEBRIDGE_GATE_ADDRESS, 
          CHAIN_1_DEBRIDGE_GATE_ADMIN_ADDRESS
        );
        hooksData[2] = _createDeposit5115VaultHookData(underlyingBase_USDC, accountBase, amount, ETH, CHAIN_1_PendleEthena);
        hooksData[3] = _createDepositVaultHookData(underlyingBase_USDC, accountBase, amount, OP, CHAIN_1_PendleEthena);
        hooksData[4] = _createDeposit7540VaultHookData(underlyingBase_USDC, accountBase, amount, ETH, CHAIN_1_PendleEthena);

        // bytes memory userOpData = _createUserOp(hooksAddresses, hooksData);
    }
}
