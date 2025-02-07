// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

// Superform
import { ISuperExecutor } from "../../src/core/interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../../src/core/interfaces/accounting/ISuperLedger.sol";
import { IDeBridgeGate } from "../../src/core/interfaces/vendors/bridges/debridge/IDeBridgeGate.sol";

import { BaseTest } from "../BaseTest.t.sol";

import { console2 } from "forge-std/console2.sol";

/// @dev Forked mainnet test with deposit and redeem flow for a real ERC4626 vault
contract ERC4626DepositRedeemFlowTest is BaseTest {
    IERC4626 public vaultInstanceEth;
    IERC4626 public vaultInstanceBase;
    address public yieldSourceAddressEth;
    address public yieldSourceAddressBase;
    address public yieldSourceAddressBaseWeth;
    address public yieldSourceOracle;
    address public underlyingEth_USDC;
    address public underlyingOp_USDC;
    address public underlyingBase_USDC;
    address public underlyingBase_WETH;
    address public accountEth;
    address public accountBase;
    AccountInstance public instanceOnEth;
    AccountInstance public instanceOnBase;
    AccountInstance public instanceOnOP;
    ISuperExecutor public superExecutorOnEth;
    ISuperExecutor public superExecutorOnBase;
    ISuperExecutor public superExecutorOnOP;

    function setUp() public override {
        super.setUp();

        vm.selectFork(FORKS[ETH]);

        underlyingEth_USDC = existingUnderlyingTokens[ETH][USDC_KEY];
        underlyingBase_USDC = existingUnderlyingTokens[BASE][USDC_KEY];
        underlyingOp_USDC = existingUnderlyingTokens[OP][USDC_KEY];
        underlyingBase_WETH = existingUnderlyingTokens[BASE][WETH_KEY];
        yieldSourceAddressEth = realVaultAddresses[ETH][ERC4626_VAULT_KEY][MORPHO_VAULT_KEY][USDC_KEY];
        yieldSourceAddressBase = realVaultAddresses[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_USDC_PRIME_KEY][USDC_KEY];
        yieldSourceAddressBaseWeth =
            realVaultAddresses[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_WETH_CORE_KEY][WETH_KEY];
        yieldSourceOracle = _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY);
        vaultInstanceEth = IERC4626(yieldSourceAddressEth);
        vaultInstanceBase = IERC4626(yieldSourceAddressBase);
        accountEth = accountInstances[ETH].account;
        accountBase = accountInstances[BASE].account;
        instanceOnEth = accountInstances[ETH];
        instanceOnBase = accountInstances[BASE];
        instanceOnOP = accountInstances[OP];
        superExecutorOnEth = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
        superExecutorOnBase = ISuperExecutor(_getContract(BASE, SUPER_EXECUTOR_KEY));
        superExecutorOnOP = ISuperExecutor(_getContract(OP, SUPER_EXECUTOR_KEY));
    }

    function test_Deposit_4626_Mainnet_Flow() public {
        vm.selectFork(FORKS[ETH]);

        uint256 amount = 1e8;
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingEth_USDC, yieldSourceAddressEth, amount, false);
        hooksData[1] = _createDepositHookData(
            bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddressEth, amount, false, false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);
    }

    function test_Deposit_Redeem_4626_Mainnet_Flow() public {
        vm.selectFork(FORKS[ETH]);

        uint256 amount = 1e8;
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingEth_USDC, yieldSourceAddressEth, amount, false);
        hooksData[1] = _createDepositHookData(
            bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddressEth, amount, false, false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        vm.expectEmit(true, true, true, false);
        emit ISuperLedger.AccountingInflow(accountEth, yieldSourceOracle, yieldSourceAddressEth, amount, 1e18);
        executeOp(userOpData);

        uint256 accSharesAfter = vaultInstanceEth.balanceOf(accountEth);
        assertEq(accSharesAfter, vaultInstanceEth.previewDeposit(amount));

        hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, WITHDRAW_4626_VAULT_HOOK_KEY);
        hooksData = new bytes[](2);
        hooksData[0] = _createWithdrawHookData(
            bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceAddressEth,
            accountEth,
            accSharesAfter/2, // temporary
            false,
            false
        );

        ISuperExecutor.ExecutorEntry memory entryWithdraw =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryWithdraw));

        vm.expectEmit(true, true, true, false);
        emit ISuperLedger.AccountingOutflow(accountEth, yieldSourceOracle, yieldSourceAddressEth, accSharesAfter, 0);

        executeOp(userOpData);

        // uint256 accSharesAfterWithdraw = vaultInstanceEth.balanceOf(accountEth);
        // assertEq(accSharesAfterWithdraw, 0);

    }

    function test_RebalanceCrossChain_4626_Mainnet_Flow() public {
        vm.selectFork(FORKS[ETH]);

        uint256 amount = 1e8;
        uint256 previewRedeemAmount = vaultInstanceEth.previewRedeem(vaultInstanceEth.previewDeposit(amount));

        // BASE IS DST
        vm.selectFork(FORKS[BASE]);

        // PREPARE DST DATA
        address[] memory dstHooksAddresses = new address[](2);
        dstHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        dstHooksAddresses[1] = _getHookAddress(BASE, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory dstHooksData = new bytes[](2);
        dstHooksData[0] =
            _createApproveHookData(underlyingBase_USDC, yieldSourceAddressBase, previewRedeemAmount, false);
        dstHooksData[1] = _createDepositHookData(
            bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceAddressBase,
            previewRedeemAmount,
            false,
            false
        );

        ISuperExecutor.ExecutorEntry memory entryToExecuteOnDst =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: dstHooksAddresses, hooksData: dstHooksData });

        UserOpData memory dstUserOpData =
            _getExecOps(instanceOnBase, superExecutorOnBase, abi.encode(entryToExecuteOnDst));

        // ETH is SRC
        vm.selectFork(FORKS[ETH]);
        address[] memory srcHooksAddresses = new address[](4);
        srcHooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);
        srcHooksAddresses[2] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[3] = _getHookAddress(ETH, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory srcHooksData = new bytes[](4);
        srcHooksData[0] = _createApproveHookData(underlyingEth_USDC, yieldSourceAddressEth, amount, false);
        srcHooksData[1] = _createDepositHookData(
            bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddressEth, amount, false, false
        );
        srcHooksData[2] = _createApproveHookData(underlyingEth_USDC, SPOKE_POOL_V3_ADDRESSES[ETH], 0, true);

        srcHooksData[3] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            existingUnderlyingTokens[ETH][USDC_KEY],
            existingUnderlyingTokens[BASE][USDC_KEY],
            previewRedeemAmount,
            previewRedeemAmount,
            BASE,
            true,
            accountBase,
            0,
            dstUserOpData
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: srcHooksAddresses, hooksData: srcHooksData });

        UserOpData memory srcUserOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        _processAcrossV3Message(ETH, BASE, executeOp(srcUserOpData), RELAYER_TYPE.ENOUGH_BALANCE, accountBase);
    }

    struct LocalVars {
        uint256 intentAmount;
        address[] dstHooksAddresses;
        bytes[] dstHooksData;
        address[] srcHooksAddresses;
        bytes[] srcHooksData;
    }

    function test_sendFundsFromTwoChainsAndDeposit() public {
        LocalVars memory vars;
        vm.selectFork(FORKS[ETH]);

        vars.intentAmount = 100e8;

        // BASE IS DST
        vm.selectFork(FORKS[BASE]);

        // PREPARE DST DATA
        vars.dstHooksAddresses = new address[](2);
        vars.dstHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        vars.dstHooksAddresses[1] = _getHookAddress(BASE, DEPOSIT_4626_VAULT_HOOK_KEY);

        vars.dstHooksData = new bytes[](2);
        vars.dstHooksData[0] =
            _createApproveHookData(underlyingBase_WETH, yieldSourceAddressBaseWeth, vars.intentAmount, false);
        vars.dstHooksData[1] = _createDepositHookData(
            bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceAddressBaseWeth,
            vars.intentAmount,
            false,
            false
        );

        ISuperExecutor.ExecutorEntry memory entryToExecuteOnDst =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: vars.dstHooksAddresses, hooksData: vars.dstHooksData });

        UserOpData memory dstUserOpData =
            _getExecOps(instanceOnBase, superExecutorOnBase, abi.encode(entryToExecuteOnDst));

        // ETH is SRC1
        vm.selectFork(FORKS[ETH]);
        vars.srcHooksAddresses = new address[](2);
        vars.srcHooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        vars.srcHooksAddresses[1] = _getHookAddress(ETH, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        vars.srcHooksData = new bytes[](2);
        vars.srcHooksData[0] =
            _createApproveHookData(underlyingEth_USDC, SPOKE_POOL_V3_ADDRESSES[ETH], vars.intentAmount / 2, false);

        vars.srcHooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            existingUnderlyingTokens[ETH][USDC_KEY],
            existingUnderlyingTokens[BASE][WETH_KEY],
            vars.intentAmount / 2,
            vars.intentAmount / 2,
            BASE,
            true,
            accountBase,
            vars.intentAmount,
            dstUserOpData
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: vars.srcHooksAddresses, hooksData: vars.srcHooksData });

        UserOpData memory srcUserOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        // not enough balance is received
        _processAcrossV3Message(ETH, BASE, executeOp(srcUserOpData), RELAYER_TYPE.NOT_ENOUGH_BALANCE, accountBase);

        // OP is SRC2
        vm.selectFork(FORKS[OP]);

        vars.srcHooksAddresses = new address[](2);
        vars.srcHooksAddresses[0] = _getHookAddress(OP, APPROVE_ERC20_HOOK_KEY);
        vars.srcHooksAddresses[1] = _getHookAddress(OP, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        vars.srcHooksData = new bytes[](2);
        vars.srcHooksData[0] =
            _createApproveHookData(underlyingOp_USDC, SPOKE_POOL_V3_ADDRESSES[OP], vars.intentAmount / 2, false);
        vars.srcHooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            existingUnderlyingTokens[OP][USDC_KEY],
            existingUnderlyingTokens[BASE][WETH_KEY],
            vars.intentAmount / 2,
            vars.intentAmount / 2,
            BASE,
            true,
            accountBase,
            vars.intentAmount,
            dstUserOpData
        );

        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: vars.srcHooksAddresses, hooksData: vars.srcHooksData });

        srcUserOpData = _getExecOps(instanceOnOP, superExecutorOnOP, abi.encode(entry));
        // balance is received and everything is executed
        _processAcrossV3Message(OP, BASE, executeOp(srcUserOpData), RELAYER_TYPE.ENOUGH_BALANCE, accountBase);
    }

    function test_RebalanceCrossChain_WithDebridge_4626_Mainnet_Flow() public {
        vm.selectFork(FORKS[ETH]);

        uint256 amount = 1e10;

        // BASE IS DST
        vm.selectFork(FORKS[BASE]);

        // PREPARE DST DATA
        address[] memory dstHooksAddresses = new address[](2);
        dstHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        dstHooksAddresses[1] = _getHookAddress(BASE, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory dstHooksData = new bytes[](2);
        dstHooksData[0] = _createApproveHookData(underlyingBase_USDC, yieldSourceAddressBase, amount, false);
        dstHooksData[1] = _createDepositHookData(
            bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddressBase, amount, false, false
        );

        // ETH is SRC
        vm.selectFork(FORKS[ETH]);
        address[] memory srcHooksAddresses = new address[](2);
        srcHooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[1] = _getHookAddress(ETH, DEBRIDGE_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        IDeBridgeGate.SubmissionAutoParamsTo memory autoParams = IDeBridgeGate.SubmissionAutoParamsTo({
            executionFee: 0,
            flags: 0,
            fallbackAddress: abi.encodePacked(instanceOnBase.account),
            data: ""
        });
        bytes memory autoParamsBytes = abi.encode(autoParams);

        bytes[] memory srcHooksData = new bytes[](2);
        srcHooksData[0] = _createApproveHookData(underlyingEth_USDC, DEBRIDGE_GATE_ADDRESSES[ETH], amount, false);
        srcHooksData[1] = _createDebridgeSendFundsAndExecuteHookData(
            1 ether,
            accountBase,
            existingUnderlyingTokens[ETH][USDC_KEY],
            amount,
            chainIds[2], //Base
            0,
            false, // use asset fee
            false, // use prev hook amount
            autoParamsBytes.length,
            autoParamsBytes,
            ""
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: srcHooksAddresses, hooksData: srcHooksData });

        UserOpData memory srcUserOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        _processDebridgeMessage(ETH, BASE, executeOp(srcUserOpData));
    }
}
