// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { UserOpData } from "modulekit/ModuleKit.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Superform
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { MockAccountingVault } from "../../mocks/MockAccountingVault.sol";
import { MinimalBaseIntegrationTest } from "../../integration/MinimalBaseIntegrationTest.t.sol";
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";

import "forge-std/console2.sol";

// Moved from integration test folder because it's more of a unit test rather than an integration one
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
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            yieldSourceAddress,
            amount,
            false,
            address(0),
            0
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
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            yieldSourceAddress,
            amount,
            false,
            address(0),
            0
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
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            yieldSourceAddress,
            accountEth,
            sharesToWithdraw,
            false
        );
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config = ledgerConfig.getYieldSourceOracleConfig(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this))
        );
        uint256 feeBalanceBefore = IERC20(underlying).balanceOf(config.feeRecipient);

        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);

        uint256 feeBalanceAfter = IERC20(underlying).balanceOf(config.feeRecipient);

        // profit should be 1% of SMALL ( = amount)
        assertEq(feeBalanceAfter - feeBalanceBefore, amount * 100 / 10_000);
    }

    function test_MultipleDepositsAndFullWithdrawal_ForMultipleEntries_Fees() external {
        uint256 amount = SMALL; // 1eth
        _getTokens(underlying, accountEth, amount * 2);

        // make sure custom pps is 1
        MockAccountingVault(yieldSourceAddress).setCustomPps(1e18);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = deposit4626Hook;

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            yieldSourceAddress,
            amount,
            false,
            address(0),
            0
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);
        // 1000000000000000000 Shares and 1000000000000000000 cost basis (assets)

        // deposit 1 eth here

        vm.startPrank(accountEth);
        _getTokens(underlying, accountEth, SMALL);
        IERC20(underlying).approve(yieldSourceAddress, SMALL);
        MockAccountingVault(yieldSourceAddress).deposit(SMALL, accountEth);
        vm.stopPrank();

        uint256 sharesBalance = MockAccountingVault(yieldSourceAddress).balanceOf(accountEth);
        console2.log("Shares balance of the user", sharesBalance);

        // set pps to 2$ and assure vault has enough assets
        MockAccountingVault(yieldSourceAddress).setCustomPps(2e18);
        _getTokens(underlying, address(vaultInstance), LARGE);

        // assert pps
        uint256 amountOut = vaultInstance.convertToAssets(sharesBalance);
        console2.log("equivalent asset amount", amountOut);

        // prepare withdraw
        hooksAddresses = new address[](1);
        hooksAddresses[0] = redeem4626Hook;

        hooksData = new bytes[](1);
        hooksData[0] = _createRedeem4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            yieldSourceAddress,
            accountEth,
            sharesBalance,
            false
        );
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config = ledgerConfig.getYieldSourceOracleConfig(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this))
        );
        console2.log("config.feePercent", config.feePercent);
        uint256 feeBalanceBefore = IERC20(underlying).balanceOf(config.feeRecipient);

        console2.log("feeBalanceBefore", feeBalanceBefore);

        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);

        uint256 feeBalanceAfter = IERC20(underlying).balanceOf(config.feeRecipient);
        console2.log("feeBalanceAfter", feeBalanceAfter);

        assertEq(feeBalanceAfter - feeBalanceBefore, SMALL * 100 / 10_000);
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
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            yieldSourceAddress,
            amount,
            false,
            address(0),
            0
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
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            yieldSourceAddress,
            accountEth,
            sharesToWithdraw,
            false
        );
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config = ledgerConfig.getYieldSourceOracleConfig(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this))
        );
        uint256 feeBalanceBefore = IERC20(underlying).balanceOf(config.feeRecipient);

        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);

        uint256 feeBalanceAfter = IERC20(underlying).balanceOf(config.feeRecipient);

        // profit should be 1% of SMALL*2 ( = amount*2)
        assertEq(feeBalanceAfter - feeBalanceBefore, amount * 100 / 10_000);
    }
}
