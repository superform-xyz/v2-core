// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Tests
import { BaseTest } from "../BaseTest.t.sol";
import { console2 } from "forge-std/console2.sol";

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
    IERC7540 public vaultInstance7540ETH;
    IERC4626 public vaultInstance4626OP;

    address public underlyingETH_USDC;
    address public underlyingOP_USDC;

    address public underlyingBase_USDC;

    address public yieldSourceOracleBase;
    address public yieldSourceOracleOP;

    address public yieldSourceOracle7540;
    address public yieldSource7540AddressETH_USDC;

    address public yieldSourceOracle4626;
    address public yieldSource4626AddressOP_USDC;

    address public accountBase;
    address public accountETH;
    address public accountOP;

    AccountInstance public instanceOnBase;
    AccountInstance public instanceOnETH;
    AccountInstance public instanceOnOP;

    ISuperExecutor public superExecutorOnBase;
    ISuperExecutor public superExecutorOnETH;
    ISuperExecutor public superExecutorOnOP;

    uint256 public balance_Base_USDC_Before;

    function setUp() public override {
        super.setUp();

        underlyingBase_USDC = existingUnderlyingTokens[BASE]["USDC"];
        vm.label(underlyingBase_USDC, "underlyingBase_USDC");
        underlyingETH_USDC = existingUnderlyingTokens[ETH]["USDC"];
        vm.label(underlyingETH_USDC, "underlyingETH_USDC");
        underlyingOP_USDC = existingUnderlyingTokens[OP]["USDC"];
        vm.label(underlyingOP_USDC, "underlyingOP_USDC");

        yieldSource7540AddressETH_USDC = realVaultAddresses[ETH]["ERC7540FullyAsync"]["CentrifugeUSDC"]["USDC"];
        vm.makePersistent(yieldSource7540AddressETH_USDC);
        vm.label(yieldSource7540AddressETH_USDC, "yieldSource7540AddressETH_USDC");

        vaultInstance7540ETH = IERC7540(yieldSource7540AddressETH_USDC);

        yieldSourceOracle7540 = _getContract(ETH, ERC7540_YIELD_SOURCE_ORACLE_KEY);

        yieldSource4626AddressOP_USDC = realVaultAddresses[OP][ERC4626_VAULT_KEY][ALOE_USDC_VAULT_KEY][USDC_KEY];
        //yieldSource4626AddressOP_USDC = realVaultAddresses[OP][ERC4626_VAULT_KEY][VAULT_CRAFT_USDC_KEY][USDC_KEY];
        vm.makePersistent(yieldSource4626AddressOP_USDC);
        console2.log("--------- yieldSource4626AddressOP_USDC", yieldSource4626AddressOP_USDC);

        vaultInstance4626OP = IERC4626(yieldSource4626AddressOP_USDC);

        yieldSourceOracle4626 = _getContract(OP, ERC4626_YIELD_SOURCE_ORACLE_KEY);
        console2.log("--------- yieldSourceOracle4626", yieldSourceOracle4626);

        accountBase = accountInstances[BASE].account;
        accountETH = accountInstances[ETH].account;
        accountOP = accountInstances[OP].account;
        console2.log("--------- accountBase", accountBase);
        console2.log("--------- accountETH", accountETH);
        console2.log("--------- accountOP", accountOP);

        instanceOnBase = accountInstances[BASE];
        instanceOnETH = accountInstances[ETH];
        instanceOnOP = accountInstances[OP];

        superExecutorOnBase = ISuperExecutor(_getContract(BASE, SUPER_EXECUTOR_KEY));
        superExecutorOnETH = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
        superExecutorOnOP = ISuperExecutor(_getContract(OP, SUPER_EXECUTOR_KEY));

        vm.selectFork(FORKS[BASE]);
        balance_Base_USDC_Before = IERC20(underlyingBase_USDC).balanceOf(accountBase);
        console2.log("--------- balance_Base_USDC_Before", balance_Base_USDC_Before);
    }

    function test_Bridge_To_MultiVault_Deposit_Flow() public {
        uint256 amount = 1e8;
        uint256 amountPerVault = amount / 2;

        // ETH IS DST1
        vm.selectFork(FORKS[ETH]);

        //uint256 previewDepositAmountETH = vaultInstance7540ETH.previewDeposit(amountPerVault);

        // PREPARE ETH DATA
        address[] memory eth7540HooksAddresses = new address[](2);
        eth7540HooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        eth7540HooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_7540_VAULT_HOOK_KEY);
        
        bytes[] memory eth7540HooksData = new bytes[](2);
        eth7540HooksData[0] = _createApproveHookData(
            underlyingETH_USDC,
            yieldSource7540AddressETH_USDC,
            amountPerVault,
            false
        );
        eth7540HooksData[1] = _createDeposit7540VaultHookData(
            bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)),
            yieldSource7540AddressETH_USDC,
            0x6F94EB271cEB5a33aeab5Bb8B8edEA8ECf35Ee86,
            amountPerVault, 
            true
        );

        UserOpData memory ethUserOpData = _createUserOpData(
            eth7540HooksAddresses,
            eth7540HooksData,
            ETH
        );

        // BASE IS SRC
        vm.selectFork(FORKS[BASE]);

        address[] memory srcHooksAddresses = new address[](2);
        srcHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[1] = _getHookAddress(BASE, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory srcHooksDataETH = new bytes[](2);
        srcHooksDataETH[0] = _createApproveHookData(
            underlyingBase_USDC,
            SPOKE_POOL_V3_ADDRESSES[BASE],
            amountPerVault,
            false
        );
        srcHooksDataETH[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingBase_USDC,
            underlyingETH_USDC,
            amountPerVault / 2,
            amountPerVault / 2,
            ETH,
            true,
            ethUserOpData
        );

        UserOpData memory srcUserOpDataETH = _createUserOpData(
            srcHooksAddresses,
            srcHooksDataETH,
            BASE
        );

        // EXECUTE ETH
        _processAcrossV3Message(BASE, ETH, executeOp(srcUserOpDataETH), RELAYER_TYPE.ENOUGH_BALANCE, accountETH);

        assertEq(IERC20(underlyingBase_USDC).balanceOf(accountBase), balance_Base_USDC_Before - amountPerVault);
        //assertEq(vaultInstance7540ETH.balanceOf(accountETH), previewDepositAmountETH);

        vm.selectFork(FORKS[OP]);

        _bridge_To_OP_And_Deposit();
    }

    function _bridge_To_OP_And_Deposit() internal {
        uint256 amountPerVault = 1e8 / 2;

        // OP IS DST2
        vm.selectFork(FORKS[OP]);

        uint256 previewDepositAmountOP = vaultInstance4626OP.previewDeposit(amountPerVault);

        address[] memory opHooksAddresses = new address[](2);
        opHooksAddresses[0] = _getHookAddress(OP, APPROVE_ERC20_HOOK_KEY);
        opHooksAddresses[1] = _getHookAddress(OP, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory opHooksData = new bytes[](2);
        opHooksData[0] = _createApproveHookData(
            underlyingOP_USDC,
            yieldSource4626AddressOP_USDC,
            amountPerVault,
            false
        );
        opHooksData[1] = _createDeposit4626VaultHookData(
            bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            yieldSource4626AddressOP_USDC,
            amountPerVault / 2, 
            true,
            false
        );

        UserOpData memory opUserOpData = _createUserOpData(
            opHooksAddresses,
            opHooksData,
            OP
        );

        // BASE IS SRC
        vm.selectFork(FORKS[BASE]);

        address[] memory srcHooksAddressesOP = new address[](2);
        srcHooksAddressesOP[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddressesOP[1] = _getHookAddress(BASE, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory srcHooksDataOP = new bytes[](2);
        srcHooksDataOP[0] = _createApproveHookData(
            underlyingBase_USDC,
            SPOKE_POOL_V3_ADDRESSES[BASE],
            amountPerVault,
            false
        );
        srcHooksDataOP[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingBase_USDC,
            underlyingOP_USDC,
            amountPerVault, // amountPerVault / 2,
            amountPerVault, // amountPerVault / 2,
            OP,
            true,
            opUserOpData
        );

        UserOpData memory srcUserOpDataOP = _createUserOpData(
            srcHooksAddressesOP,
            srcHooksDataOP,
            BASE
        );

        // EXECUTE OP
        // _processAcrossV3Message(BASE, OP, executeOp(srcUserOpDataOP), RELAYER_TYPE.ENOUGH_BALANCE, accountBase);
        _processAcrossV3Message(BASE, OP, executeOp(srcUserOpDataOP), RELAYER_TYPE.ENOUGH_BALANCE, accountOP);

        assertEq(IERC20(underlyingBase_USDC).balanceOf(accountBase), balance_Base_USDC_Before - (amountPerVault * 2));

        vm.selectFork(FORKS[OP]);
        console2.log("--------- vaultInstance4626OP.balanceOf(accountOp)", vaultInstance4626OP.balanceOf(accountOP));
        //assertEq(vaultInstance4626OP.balanceOf(accountOP), previewDepositAmountOP);

        console2.log(
            "--------- IERC20(underlyingOP_USDC).balanceOf(accountOP)", 
            IERC20(underlyingOP_USDC).balanceOf(accountOP)
        );

        console2.log("--------- SpokePoolV3", SPOKE_POOL_V3_ADDRESSES[OP]);
        console2.log("--------- SuperExecutor", address(superExecutorOnOP));
    }

    function test_Bridge_To_MultiVault_Deposit_Redeem_Bridge_Back_Flow() public {
        test_Bridge_To_MultiVault_Deposit_Flow();
        _redeem_From_OP_And_Bridge_Back_To_Base();
        _redeem_From_ETH_And_Bridge_Back_To_Base();
    }

    function _redeem_From_OP_And_Bridge_Back_To_Base() internal {
        uint256 amountPerVault = 1e8 / 2;

        // BASE IS DST
        vm.selectFork(FORKS[BASE]);

        uint256 user_Base_USDC_Balance_Before = IERC20(underlyingBase_USDC).balanceOf(accountBase);

        address[] memory baseHooksAddresses = new address[](1);
        baseHooksAddresses[0] = _getHookAddress(BASE, TRANSFER_ERC20_HOOK_KEY);

        bytes[] memory baseHooksData = new bytes[](1);
        baseHooksData[0] = _createTransferERC20HookData(
            underlyingBase_USDC,
            accountBase,
            amountPerVault,
            true
        );

        UserOpData memory baseUserOpData = _createUserOpData(
            baseHooksAddresses,
            baseHooksData,
            BASE
        );

        // OP IS SRC
        vm.selectFork(FORKS[OP]);

        console2.log("--------- user balance of shares", IERC20(yieldSource4626AddressOP_USDC).balanceOf(accountOP));

        address[] memory opHooksAddresses = new address[](3);
        //opHooksAddresses[0] = _getHookAddress(OP, APPROVE_ERC20_HOOK_KEY);
        //console2.log("--------- opHooksAddresses[0]", opHooksAddresses[0]);
        opHooksAddresses[0] = _getHookAddress(OP, WITHDRAW_4626_VAULT_HOOK_KEY);
        opHooksAddresses[1] = _getHookAddress(OP, APPROVE_ERC20_HOOK_KEY);
        opHooksAddresses[2] = _getHookAddress(OP, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory opHooksData = new bytes[](3);
        //opHooksData[0] = _createApproveHookData(
        //    vaultAddress, // shares
        //    yieldSource4626AddressOP_USDC,
        //    amountPerVault,
        //    false
        //);
        opHooksData[0] = _createWithdraw4626VaultHookData(
            bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            yieldSource4626AddressOP_USDC,
            accountOP,
            300,
            false,
            false
        );
        opHooksData[1] = _createApproveHookData(
            underlyingOP_USDC,
            SPOKE_POOL_V3_ADDRESSES[OP],
            amountPerVault,
            false
        );
        opHooksData[2] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingOP_USDC,
            underlyingBase_USDC,
            amountPerVault / 2,
            amountPerVault / 2,
            BASE,
            true,
            baseUserOpData
        );

        UserOpData memory opUserOpData = _createUserOpData(
            opHooksAddresses,
            opHooksData,
            OP
        );

        _processAcrossV3Message(OP, BASE, executeOp(opUserOpData), RELAYER_TYPE.ENOUGH_BALANCE, accountBase);

        vm.selectFork(FORKS[BASE]);

        assertEq(IERC20(underlyingBase_USDC).balanceOf(accountBase), user_Base_USDC_Balance_Before + amountPerVault);
    }

    function _redeem_From_ETH_And_Bridge_Back_To_Base() internal {
        uint256 amountPerVault = 1e8 / 2;

        // BASE IS DST
        vm.selectFork(FORKS[BASE]);

        uint256 user_Base_USDC_Balance_Before = IERC20(underlyingBase_USDC).balanceOf(accountBase); 

        UserOpData memory baseUserOpData = _createUserOpData(
            new address[](0),
            new bytes[](0),
            BASE
        );

        // ETH IS SRC
        vm.selectFork(FORKS[ETH]);

        address vaultAddress = realVaultAddresses[ETH][ERC7540FullyAsync_KEY][CENTRIFUGE_USDC_VAULT_KEY][USDC_KEY];

        address[] memory ethHooksAddresses = new address[](3);
        //ethHooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        ethHooksAddresses[0] = _getHookAddress(ETH, WITHDRAW_7540_VAULT_HOOK_KEY);
        ethHooksAddresses[1] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        ethHooksAddresses[2] = _getHookAddress(ETH, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory ethHooksData = new bytes[](3);
        // ethHooksData[0] = _createApproveHookData(
        //     vaultAddress, // shares
        //     vaultAddress,
        //     amountPerVault,
        //     false
        // );
        ethHooksData[0] = _createWithdraw7540VaultHookData(
            bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)),
            vaultAddress,
            accountBase,
            amountPerVault,
            false,
            false
        );
        ethHooksData[1] = _createApproveHookData(
            underlyingBase_USDC,
            SPOKE_POOL_V3_ADDRESSES[ETH],
            amountPerVault,
            false
        );
        ethHooksData[2] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingETH_USDC,
            underlyingBase_USDC,
            amountPerVault / 2,
            amountPerVault / 2,
            BASE,
            true,
            baseUserOpData
        );

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: ethHooksAddresses, hooksData: ethHooksData });
        UserOpData memory ethUserOpData = _getExecOps(instanceOnETH, superExecutorOnETH, abi.encode(entryToExecute));

        _processAcrossV3Message(ETH, BASE, executeOp(ethUserOpData), RELAYER_TYPE.ENOUGH_BALANCE, accountETH);

        vm.selectFork(FORKS[BASE]);

        assertEq(IERC20(underlyingBase_USDC).balanceOf(accountBase), user_Base_USDC_Balance_Before + amountPerVault);
    }

    function _createUserOpData(
        address[] memory hooksAddresses, 
        bytes[] memory hooksData,
        uint64 chainId
    ) internal returns (UserOpData memory) {
        if (chainId == ETH) {
            ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
            return _getExecOps(instanceOnETH, superExecutorOnETH, abi.encode(entryToExecute));
        } else if (chainId == OP) {
            ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
            return _getExecOps(instanceOnOP, superExecutorOnOP, abi.encode(entryToExecute));
        } else {
            ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
            return _getExecOps(instanceOnBase, superExecutorOnBase, abi.encode(entryToExecute));
        }
    }
}
