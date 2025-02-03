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
        vm.selectFork(FORKS[BASE]);

        uint256 amount = 1e9;
        uint256 amountPerVault = amount / 3;

        address[] memory srcHooksAddresses = new address[](2);
        srcHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[1] = _getHookAddress(BASE, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        address[] memory ethHooksAddresses = new address[](4);
        ethHooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        ethHooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_5115_VAULT_HOOK_KEY);
        ethHooksAddresses[2] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        ethHooksAddresses[3] = _getHookAddress(ETH, DEPOSIT_7540_VAULT_HOOK_KEY);

        address[] memory opHooksAddresses = new address[](2);
        opHooksAddresses[0] = _getHookAddress(OP, APPROVE_ERC20_HOOK_KEY);
        opHooksAddresses[1] = _getHookAddress(OP, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory srcHooksData = new bytes[](2);
        srcHooksData[0] = _createApproveHookData(
            underlyingBase_USDC,
            SPOKE_POOL_V3_ADDRESSES[BASE],
            amount
        );
        srcHooksData[1] = _createAcrossSendFundsAndExecuteOnDstHookData(
          underlyingBase_USDC, 
          accountBase, 
          amount, 
          BASE, 
          CHAIN_1_SPOKE_POOL_V3_ADDRESS, 
          CHAIN_1_DEBRIDGE_GATE_ADDRESS, 
          CHAIN_1_DEBRIDGE_GATE_ADMIN_ADDRESS
        );

        bytes[] memory ethHooksData = new bytes[](4);
        ethHooksData[0] = _createApproveHookData(
            underlyingBase_USDC,
            SPOKE_POOL_V3_ADDRESSES[BASE],
            amountPerVault
        );
        ethHooksData[2] = _createDeposit5115VaultHookData(
            bytes32(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)),
            underlyingBase_USDC, 
            accountBase, 
            amountPerVault, 
            ETH, 
            CHAIN_1_PendleEthena
        );
        ethHooksData[3] = _createApproveHookData(
            underlyingBase_USDC,
            SPOKE_POOL_V3_ADDRESSES[BASE],
            amountPerVault
        );
        hooksData[4] = _createDeposit7540VaultHookData(
            bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)),
            underlyingBase_USDC, 
            accountBase, 
            amountPerVault, 
            ETH, 
            CHAIN_1_PendleEthena
        );

        bytes[] memory opHooksData = new bytes[](2);
        opHooksData[0] = _createApproveHookData(
            underlyingBase_USDC,
            SPOKE_POOL_V3_ADDRESSES[BASE],
            amountPerVault
        );
        opHooksData[1] = _createDeposit4626VaultHookData(
            bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            underlyingBase_USDC, 
            accountBase, 
            amountPerVault, 
            OP, 
            CHAIN_1_PendleEthena
        );

        // bytes memory userOpData = _createUserOp(hooksAddresses, hooksData);
    }
}
