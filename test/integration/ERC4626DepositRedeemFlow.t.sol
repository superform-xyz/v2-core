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

        underlyingEth_USDC = existingUnderlyingTokens[ETH]["USDC"];
        underlyingBase_USDC = existingUnderlyingTokens[BASE]["USDC"];
        underlyingOp_USDC = existingUnderlyingTokens[OP]["USDC"];
        underlyingBase_WETH = existingUnderlyingTokens[BASE]["WETH"];
        yieldSourceAddressEth = realVaultAddresses[ETH]["ERC4626"]["MorphoVault"]["USDC"];
        yieldSourceAddressBase = realVaultAddresses[BASE]["ERC4626"]["MorphoGauntletUSDCPrime"]["USDC"];
        yieldSourceAddressBaseWeth = realVaultAddresses[BASE]["ERC4626"]["MorphoGauntletWETHCore"]["WETH"];
        yieldSourceOracle = _getContract(ETH, "ERC4626YieldSourceOracle");
        vaultInstanceEth = IERC4626(yieldSourceAddressEth);
        vaultInstanceBase = IERC4626(yieldSourceAddressBase);
        accountEth = accountInstances[ETH].account;
        accountBase = accountInstances[BASE].account;
        instanceOnEth = accountInstances[ETH];
        instanceOnBase = accountInstances[BASE];
        instanceOnOP = accountInstances[OP];
        superExecutorOnEth = ISuperExecutor(_getContract(ETH, "SuperExecutor"));
        superExecutorOnBase = ISuperExecutor(_getContract(BASE, "SuperExecutor"));
        superExecutorOnOP = ISuperExecutor(_getContract(OP, "SuperExecutor"));
    }

    function test_Deposit_4626_Mainnet_Flow() public {
        vm.selectFork(FORKS[ETH]);

        uint256 amount = 1e8;
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, "ApproveERC20Hook");
        hooksAddresses[1] = _getHookAddress(ETH, "Deposit4626VaultHook");

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingEth_USDC, yieldSourceAddressEth, amount, false);
        hooksData[1] = _createDepositHookData(
            accountEth, bytes32("ERC4626YieldSourceOracle"), yieldSourceAddressEth, amount, false, false
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
        hooksAddresses[0] = _getHookAddress(ETH, "ApproveERC20Hook");
        hooksAddresses[1] = _getHookAddress(ETH, "Deposit4626VaultHook");
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingEth_USDC, yieldSourceAddressEth, amount, false);
        hooksData[1] = _createDepositHookData(
            accountEth, bytes32("ERC4626YieldSourceOracle"), yieldSourceAddressEth, amount, false, false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        vm.expectEmit(true, true, true, false);
        emit ISuperLedger.AccountingUpdated(accountEth, yieldSourceOracle, yieldSourceAddressEth, true, amount, 1e18);
        executeOp(userOpData);

        uint256 accSharesAfter = vaultInstanceEth.balanceOf(accountEth);

        assertEq(accSharesAfter, vaultInstanceEth.previewDeposit(amount));

        hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, "Withdraw4626VaultHook");
        hooksData = new bytes[](2);
        hooksData[0] = _createWithdrawHookData(
            accountEth,
            bytes32("ERC4626YieldSourceOracle"),
            yieldSourceAddressEth,
            accountEth,
            accSharesAfter,
            false,
            false
        );

        ISuperExecutor.ExecutorEntry memory entryWithdraw =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryWithdraw));

        vm.expectEmit(true, true, true, false);
        emit ISuperLedger.AccountingUpdated(
            accountEth, yieldSourceOracle, yieldSourceAddressEth, false, accSharesAfter, 1e18
        );

        executeOp(userOpData);

        uint256 accSharesAfterWithdraw = vaultInstanceEth.balanceOf(accountEth);
        assertEq(accSharesAfterWithdraw, 0);
    }

    function test_RebalanceCrossChain_4626_Mainnet_Flow() public {
        vm.selectFork(FORKS[ETH]);

        uint256 amount = 1e8;
        uint256 previewRedeemAmount = vaultInstanceEth.previewRedeem(vaultInstanceEth.previewDeposit(amount));

        // BASE IS DST
        vm.selectFork(FORKS[BASE]);

        // PREPARE DST DATA
        address[] memory dstHooksAddresses = new address[](2);
        dstHooksAddresses[0] = _getHookAddress(BASE, "ApproveERC20Hook");
        dstHooksAddresses[1] = _getHookAddress(BASE, "Deposit4626VaultHook");

        bytes[] memory dstHooksData = new bytes[](2);
        dstHooksData[0] =
            _createApproveHookData(underlyingBase_USDC, yieldSourceAddressBase, previewRedeemAmount, false);
        dstHooksData[1] = _createDepositHookData(
            accountBase, bytes32("ERC4626YieldSourceOracle"), yieldSourceAddressBase, previewRedeemAmount, false, false
        );

        ISuperExecutor.ExecutorEntry memory entryToExecuteOnDst =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: dstHooksAddresses, hooksData: dstHooksData });

        UserOpData memory dstUserOpData =
            _getExecOps(instanceOnBase, superExecutorOnBase, abi.encode(entryToExecuteOnDst));

        // ETH is SRC
        vm.selectFork(FORKS[ETH]);
        address[] memory srcHooksAddresses = new address[](5);
        srcHooksAddresses[0] = _getHookAddress(ETH, "ApproveERC20Hook");
        srcHooksAddresses[1] = _getHookAddress(ETH, "Deposit4626VaultHook");
        srcHooksAddresses[2] = _getHookAddress(ETH, "Withdraw4626VaultHook");
        srcHooksAddresses[3] = _getHookAddress(ETH, "ApproveERC20Hook");
        srcHooksAddresses[4] = _getHookAddress(ETH, "AcrossSendFundsAndExecuteOnDstHook");

        bytes[] memory srcHooksData = new bytes[](5);
        srcHooksData[0] = _createApproveHookData(underlyingEth_USDC, yieldSourceAddressEth, amount, false);
        srcHooksData[1] = _createDepositHookData(
            accountEth, bytes32("ERC4626YieldSourceOracle"), yieldSourceAddressEth, amount, false, false
        );
        srcHooksData[2] = _createWithdrawHookData(
            accountEth, bytes32("ERC4626YieldSourceOracle"), yieldSourceAddressEth, accountEth, 0, true, false
        );
        srcHooksData[3] = _createApproveHookData(underlyingEth_USDC, SPOKE_POOL_V3_ADDRESSES[ETH], 0, true);

        srcHooksData[4] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            existingUnderlyingTokens[ETH]["USDC"],
            existingUnderlyingTokens[BASE]["USDC"],
            previewRedeemAmount,
            previewRedeemAmount,
            BASE,
            true,
            instanceOnBase.account,
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
        vars.dstHooksAddresses[0] = _getHookAddress(BASE, "ApproveERC20Hook");
        vars.dstHooksAddresses[1] = _getHookAddress(BASE, "Deposit4626VaultHook");

        vars.dstHooksData = new bytes[](2);
        vars.dstHooksData[0] =
            _createApproveHookData(underlyingBase_WETH, yieldSourceAddressBaseWeth, vars.intentAmount, false);
        vars.dstHooksData[1] = _createDepositHookData(
            accountBase,
            bytes32("ERC4626YieldSourceOracle"),
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
        vars.srcHooksAddresses[0] = _getHookAddress(ETH, "ApproveERC20Hook");
        vars.srcHooksAddresses[1] = _getHookAddress(ETH, "AcrossSendFundsAndExecuteOnDstHook");

        vars.srcHooksData = new bytes[](2);
        vars.srcHooksData[0] =
            _createApproveHookData(underlyingEth_USDC, SPOKE_POOL_V3_ADDRESSES[ETH], vars.intentAmount / 2, false);
        vars.srcHooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            existingUnderlyingTokens[ETH]["USDC"],
            existingUnderlyingTokens[BASE]["WETH"],
            vars.intentAmount / 2,
            vars.intentAmount / 2,
            BASE,
            true,
            instanceOnBase.account,
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
        vars.srcHooksAddresses[0] = _getHookAddress(OP, "ApproveERC20Hook");
        vars.srcHooksAddresses[1] = _getHookAddress(OP, "AcrossSendFundsAndExecuteOnDstHook");

        vars.srcHooksData = new bytes[](2);
        vars.srcHooksData[0] =
            _createApproveHookData(underlyingOp_USDC, SPOKE_POOL_V3_ADDRESSES[OP], vars.intentAmount / 2, false);
        vars.srcHooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            existingUnderlyingTokens[OP]["USDC"],
            existingUnderlyingTokens[BASE]["WETH"],
            vars.intentAmount / 2,
            vars.intentAmount / 2,
            BASE,
            true,
            instanceOnBase.account,
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
        dstHooksAddresses[0] = _getHookAddress(BASE, "ApproveERC20Hook");
        dstHooksAddresses[1] = _getHookAddress(BASE, "Deposit4626VaultHook");

        bytes[] memory dstHooksData = new bytes[](2);
        dstHooksData[0] = _createApproveHookData(underlyingBase_USDC, yieldSourceAddressBase, amount, false);
        dstHooksData[1] = _createDepositHookData(
            accountBase, bytes32("ERC4626YieldSourceOracle"), yieldSourceAddressBase, amount, false, false
        );

        //ISuperExecutor.ExecutorEntry memory entryToExecuteOnDst =
        //    ISuperExecutor.ExecutorEntry({ hooksAddresses: dstHooksAddresses, hooksData: dstHooksData });

        // ETH is SRC
        vm.selectFork(FORKS[ETH]);
        address[] memory srcHooksAddresses = new address[](2);
        srcHooksAddresses[0] = _getHookAddress(ETH, "ApproveERC20Hook");
        srcHooksAddresses[1] = _getHookAddress(ETH, "DeBridgeSendFundsAndExecuteOnDstHook");

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
            instanceOnBase.account,
            existingUnderlyingTokens[ETH]["USDC"],
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
