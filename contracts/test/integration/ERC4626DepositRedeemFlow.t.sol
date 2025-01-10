// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

// Superform
import { ISuperExecutor } from "src/interfaces/ISuperExecutor.sol";
import { console } from "forge-std/console.sol";
import { BaseTest } from "../BaseTest.t.sol";
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../../src/interfaces/accounting/ISuperLedger.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { AcrossV3Helper } from "pigeon/across/AcrossV3Helper.sol";
/// @dev Forked mainnet test with deposit and redeem flow for a real ERC4626 vault

contract ERC4626DepositRedeemFlowTest is BaseTest {
    IERC4626 public vaultInstanceSrc;
    IERC4626 public vaultInstanceDst;
    address public yieldSourceAddressSrc;
    address public yieldSourceAddressDst;
    address public yieldSourceOracle;
    address public underlyingSrc;
    address public underlyingDst;
    address public accountSrc;
    address public accountDst;
    AccountInstance public instanceOnSrc;
    AccountInstance public instanceOnDst;
    ISuperExecutor public superExecutorOnSrc;
    ISuperExecutor public superExecutorOnDst;

    function setUp() public override {
        super.setUp();

        vm.selectFork(FORKS[ETH]);

        underlyingSrc = existingUnderlyingTokens[ETH]["USDC"];
        underlyingDst = existingUnderlyingTokens[BASE]["USDC"];

        yieldSourceAddressSrc = realVaultAddresses[ETH]["ERC4626"]["MorphoVault"]["USDC"];
        yieldSourceAddressDst = realVaultAddresses[BASE]["ERC4626"]["MorphoGauntletUSDCPrime"]["USDC"];
        yieldSourceOracle = _getContract(ETH, "ERC4626YieldSourceOracle");
        vaultInstanceSrc = IERC4626(yieldSourceAddressSrc);
        vaultInstanceDst = IERC4626(yieldSourceAddressDst);
        accountSrc = accountInstances[ETH].account;
        accountDst = accountInstances[BASE].account;
        instanceOnSrc = accountInstances[ETH];
        instanceOnDst = accountInstances[BASE];
        superExecutorOnSrc = ISuperExecutor(_getContract(ETH, "SuperExecutor"));
        superExecutorOnDst = ISuperExecutor(_getContract(BASE, "SuperExecutor"));
    }

    function test_Deposit_4626_Mainnet_Flow() public {
        vm.selectFork(FORKS[ETH]);

        uint256 amount = 1e8;
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHook(ETH, "ApproveERC20Hook");
        hooksAddresses[1] = _getHook(ETH, "Deposit4626VaultHook");

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingSrc, yieldSourceAddressSrc, amount, false);
        hooksData[1] = _createDepositHookData(
            accountSrc, bytes32("ERC4626YieldSourceOracle"), yieldSourceAddressSrc, amount, false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnSrc, superExecutorOnSrc, abi.encode(entry));
        executeOp(userOpData);
    }

    function test_Deposit_Redeem_4626_Mainnet_Flow() public {
        vm.selectFork(FORKS[ETH]);

        uint256 amount = 1e8;
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHook(ETH, "ApproveERC20Hook");
        hooksAddresses[1] = _getHook(ETH, "Deposit4626VaultHook");
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingSrc, yieldSourceAddressSrc, amount, false);
        hooksData[1] = _createDepositHookData(
            accountSrc, bytes32("ERC4626YieldSourceOracle"), yieldSourceAddressSrc, amount, false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        UserOpData memory userOpData = _getExecOps(instanceOnSrc, superExecutorOnSrc, abi.encode(entry));
        vm.expectEmit(true, true, true, false);
        emit ISuperLedger.AccountingUpdated(accountSrc, yieldSourceOracle, yieldSourceAddressSrc, true, amount, 1e18);
        executeOp(userOpData);

        uint256 accSharesAfter = vaultInstanceSrc.balanceOf(accountSrc);

        assertEq(accSharesAfter, vaultInstanceSrc.previewDeposit(amount));

        hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHook(ETH, "Withdraw4626VaultHook");
        hooksData = new bytes[](2);
        hooksData[0] = _createWithdrawHookData(
            accountSrc, bytes32("ERC4626YieldSourceOracle"), yieldSourceAddressSrc, accountSrc, accSharesAfter, false
        );

        ISuperExecutor.ExecutorEntry memory entryWithdraw =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        userOpData = _getExecOps(instanceOnSrc, superExecutorOnSrc, abi.encode(entryWithdraw));

        vm.expectEmit(true, true, true, false);
        emit ISuperLedger.AccountingUpdated(
            accountSrc, yieldSourceOracle, yieldSourceAddressSrc, false, accSharesAfter, 1e18
        );

        executeOp(userOpData);

        uint256 accSharesAfterWithdraw = vaultInstanceSrc.balanceOf(accountSrc);
        assertEq(accSharesAfterWithdraw, 0);
    }

    function test_RebalanceCrossChain_4626_Mainnet_Flow() public {
        vm.selectFork(FORKS[ETH]);

        uint256 amount = 1e8;
        uint256 previewRedeemAmount = vaultInstanceSrc.previewRedeem(vaultInstanceSrc.previewDeposit(amount));
        console.log("previewRedeemAmount", previewRedeemAmount);

        // BASE IS DST
        vm.selectFork(FORKS[BASE]);

        // PREPARE DST DATA
        address[] memory dstHooksAddresses = new address[](2);
        dstHooksAddresses[0] = _getHook(BASE, "ApproveERC20Hook");
        dstHooksAddresses[1] = _getHook(BASE, "Deposit4626VaultHook");

        bytes[] memory dstHooksData = new bytes[](2);
        dstHooksData[0] = _createApproveHookData(underlyingDst, yieldSourceAddressDst, previewRedeemAmount, false);
        dstHooksData[1] = _createDepositHookData(
            accountDst, bytes32("ERC4626YieldSourceOracle"), yieldSourceAddressDst, previewRedeemAmount, false
        );

        ISuperExecutor.ExecutorEntry memory entryToExecuteOnDst =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: dstHooksAddresses, hooksData: dstHooksData });

        UserOpData memory dstUserOpData =
            _getExecOps(instanceOnDst, superExecutorOnDst, abi.encode(entryToExecuteOnDst));

        // ETH is SRC
        vm.selectFork(FORKS[ETH]);
        address[] memory srcHooksAddresses = new address[](5);
        srcHooksAddresses[0] = _getHook(ETH, "ApproveERC20Hook");
        srcHooksAddresses[1] = _getHook(ETH, "Deposit4626VaultHook");
        srcHooksAddresses[2] = _getHook(ETH, "Withdraw4626VaultHook");
        srcHooksAddresses[3] = _getHook(ETH, "ApproveERC20Hook");
        srcHooksAddresses[4] = _getHook(ETH, "AcrossSendFundsAndExecuteOnDstHook");

        bytes[] memory srcHooksData = new bytes[](5);
        srcHooksData[0] = _createApproveHookData(underlyingSrc, yieldSourceAddressSrc, amount, false);
        srcHooksData[1] = _createDepositHookData(
            accountSrc, bytes32("ERC4626YieldSourceOracle"), yieldSourceAddressSrc, amount, false
        );
        srcHooksData[2] = _createWithdrawHookData(
            accountSrc, bytes32("ERC4626YieldSourceOracle"), yieldSourceAddressSrc, accountSrc, 0, true
        );
        srcHooksData[3] = _createApproveHookData(underlyingSrc, SPOKE_POOL_V3_ADDRESSES[ETH], 0, true);

        srcHooksData[4] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            existingUnderlyingTokens[ETH]["USDC"],
            existingUnderlyingTokens[BASE]["USDC"],
            previewRedeemAmount,
            previewRedeemAmount,
            BASE,
            true,
            abi.encode(instanceOnDst.account, 0, dstUserOpData)
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: srcHooksAddresses, hooksData: srcHooksData });

        UserOpData memory srcUserOpData = _getExecOps(instanceOnSrc, superExecutorOnSrc, abi.encode(entry));

        _processAcrossV3Message(ETH, BASE, executeOp(srcUserOpData));
    }
}
