// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { UserOpData } from "modulekit/ModuleKit.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Superform
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";
import { MockAccountingVault } from "../../mocks/MockAccountingVault.sol";
import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";
import { ISuperLedgerConfiguration } from "../../../src/core/interfaces/accounting/ISuperLedgerConfiguration.sol";

contract FeesTest is MinimalBaseIntegrationTest {
    IERC4626 public vaultInstance;
    address public yieldSourceAddress;
    address public underlying;

    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();

        underlying = CHAIN_1_WETH;

        MockAccountingVault vault = new MockAccountingVault(IERC20(underlying), "Vault", "VAULT");
        vm.label(address(vault), "MockAccountingVault");
        yieldSourceAddress = address(vault);
        vaultInstance = IERC4626(vault);
    }

    function test_DepositAndSuperLedgerEntries() external {
        uint256 amount = SMALL;

        _getTokens(underlying, accountEth, amount);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = deposit4626Hook;

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddress, amount, false, address(0), 0
        );
        uint256 sharesPreviewed = vaultInstance.previewDeposit(amount);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);

        uint256 accSharesAfter = vaultInstance.balanceOf(accountEth);
        assertEq(accSharesAfter, sharesPreviewed);
    }

    function test_MultipleDepositsAndPartialWithdrawal_Fees() external {
        uint256 amount = SMALL;
        _getTokens(underlying, accountEth, amount * 2);

        // make sure custom pps is 1
        MockAccountingVault(yieldSourceAddress).setCustomPps(1e18);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = deposit4626Hook;

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddress, amount, false, address(0), 0
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);
        userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);

        // set pps to 2$
        MockAccountingVault(yieldSourceAddress).setCustomPps(2e18);

        // assert pps
        uint256 sharesToWithdraw = SMALL; // should get 2 * SMALL amount
        uint256 amountOut = vaultInstance.convertToAssets(sharesToWithdraw);
        assertEq(amountOut, amount * 2);

        // prepare withdraw
        hooksAddresses = new address[](1);
        hooksAddresses[0] = redeem4626Hook;

        hooksData = new bytes[](1);
        hooksData[0] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceAddress,
            accountEth,
            sharesToWithdraw,
            false,
            address(0),
            0
        );
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config =
            ledgerConfig.getYieldSourceOracleConfig(bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)));
        uint256 feeBalanceBefore = IERC20(underlying).balanceOf(config.feeRecipient);

        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);

        uint256 feeBalanceAfter = IERC20(underlying).balanceOf(config.feeRecipient);

        // profit should be 1% of SMALL ( = amount)
        assertEq(feeBalanceAfter - feeBalanceBefore, amount * 100 / 10_000);
    }

    function test_MultipleDepositsAndFullWithdrawal_ForMultipleEntries_Fees() external {
        uint256 amount = SMALL;
        _getTokens(underlying, accountEth, amount * 2);

        // make sure custom pps is 1
        MockAccountingVault(yieldSourceAddress).setCustomPps(1e18);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = deposit4626Hook;

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddress, amount, false, address(0), 0
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);
        userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);

        // set pps to 2$ and assure vault has enough assets
        MockAccountingVault(yieldSourceAddress).setCustomPps(2e18);
        _getTokens(underlying, address(vaultInstance), LARGE);

        // assert pps
        uint256 sharesToWithdraw = SMALL * 2; // should get 4 * SMALL amount
        uint256 amountOut = vaultInstance.convertToAssets(sharesToWithdraw);
        assertEq(amountOut, amount * 4);

        // prepare withdraw
        hooksAddresses = new address[](1);
        hooksAddresses[0] = redeem4626Hook;

        hooksData = new bytes[](1);
        hooksData[0] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceAddress,
            accountEth,
            sharesToWithdraw,
            false,
            address(0),
            0
        );
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config =
            ledgerConfig.getYieldSourceOracleConfig(bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)));
        uint256 feeBalanceBefore = IERC20(underlying).balanceOf(config.feeRecipient);

        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);

        uint256 feeBalanceAfter = IERC20(underlying).balanceOf(config.feeRecipient);

        // profit should be 1% of SMALL*2 ( = amount*2)
        assertEq(feeBalanceAfter - feeBalanceBefore, amount * 200 / 10_000);
    }

    function test_MultipleDepositsAndFullWithdrawal_ForSingleEntries_Fees() external {
        uint256 amount = SMALL;
        _getTokens(underlying, accountEth, amount);

        // make sure custom pps is 1
        MockAccountingVault(yieldSourceAddress).setCustomPps(1e18);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = deposit4626Hook;

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddress, amount, false, address(0), 0
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);

        // set pps to 2$ and assure vault has enough assets
        MockAccountingVault(yieldSourceAddress).setCustomPps(2e18);
        _getTokens(underlying, address(vaultInstance), LARGE);

        // assert pps
        uint256 sharesToWithdraw = SMALL; // should get 4 * SMALL amount
        uint256 amountOut = vaultInstance.convertToAssets(sharesToWithdraw);
        assertEq(amountOut, amount * 2);

        // prepare withdraw
        hooksAddresses = new address[](1);
        hooksAddresses[0] = redeem4626Hook;

        hooksData = new bytes[](1);
        hooksData[0] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceAddress,
            accountEth,
            sharesToWithdraw,
            false,
            address(0),
            0
        );
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config =
            ledgerConfig.getYieldSourceOracleConfig(bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)));
        uint256 feeBalanceBefore = IERC20(underlying).balanceOf(config.feeRecipient);

        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);

        uint256 feeBalanceAfter = IERC20(underlying).balanceOf(config.feeRecipient);

        // profit should be 1% of SMALL*2 ( = amount*2)
        assertEq(feeBalanceAfter - feeBalanceBefore, amount * 100 / 10_000);
    }
}
