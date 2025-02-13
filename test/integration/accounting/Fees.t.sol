// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Superform
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../../../src/core/interfaces/accounting/ISuperLedger.sol";
import { IYieldSourceOracle } from "../../../src/core/interfaces/accounting/IYieldSourceOracle.sol";

import { SuperRegistry } from "../../../src/core/settings/SuperRegistry.sol";

import { MockAccountingVault } from "../../mocks/MockAccountingVault.sol";

import { BaseTest } from "../../BaseTest.t.sol";

contract FeesTest is BaseTest {
    IERC4626 public vaultInstance;
    address public yieldSourceAddress;
    address public yieldSourceOracle;
    address public underlying;
    address public account;
    AccountInstance public instance;

    ISuperExecutor public superExecutor;
    ISuperLedger public superLedger;
    string public constant MOCKACCOUNTINGVAULT_YIELD_SOURCE_ORACLE_KEY = "MockAccountingVaultYieldSourceOracle";

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);

        underlying = CHAIN_1_WETH;

        MockAccountingVault vault = new MockAccountingVault(IERC20(underlying), "Vault", "VAULT");
        vm.label(address(vault), "MockAccountingVault");
        yieldSourceAddress = address(vault);

        //SuperRegistry superRegistry = SuperRegistry(_getContract(chainIds[0], SUPER_REGISTRY_KEY));
        ISuperLedger.YieldSourceOracleConfigArgs[] memory configs = new ISuperLedger.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedger.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: bytes32(bytes(MOCKACCOUNTINGVAULT_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceOracle: _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY),
            feePercent: 100,
            feeRecipient: address(this),
            feeHelper: _getContract(ETH, DEFAULT_FEE_HELPER_KEY)
        });
        superLedger = ISuperLedger(_getContract(ETH, SUPER_LEDGER_KEY));
        superLedger.setYieldSourceOracles(configs);

        yieldSourceOracle = _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY);
        vaultInstance = IERC4626(vault);
        account = accountInstances[ETH].account;
        instance = accountInstances[ETH];
        superExecutor = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
    }

    function test_DepositAndSuperLedgerEntries() external {
        uint256 amount = SMALL;

        _getTokens(underlying, account, amount);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            bytes32(bytes(MOCKACCOUNTINGVAULT_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddress, amount, false, false
        );
        uint256 sharesPreviewed = vaultInstance.previewDeposit(amount);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        executeOp(userOpData);

        uint256 accSharesAfter = vaultInstance.balanceOf(account);
        assertEq(accSharesAfter, sharesPreviewed);

        uint256 pricePerShare = IYieldSourceOracle(yieldSourceOracle).getPricePerShare(address(vaultInstance));
        uint256 shares = vaultInstance.previewDeposit(amount);

        (ISuperLedger.LedgerEntry[] memory entries, uint256 unconsumedEntries) =
            superLedger.getLedger(account, address(vaultInstance));

        assertEq(entries.length, 1);
        assertEq(entries[entries.length - 1].price, pricePerShare);
        assertEq(entries[entries.length - 1].amountSharesAvailableToConsume, shares);
        assertEq(unconsumedEntries, 0);
    }

    function test_MultipleDepositsAndPartialWithdrawal_Fees() external {
        uint256 amount = SMALL;
        _getTokens(underlying, account, amount * 2);

        // make sure custom pps is 1
        MockAccountingVault(yieldSourceAddress).setCustomPps(1e18);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            bytes32(bytes(MOCKACCOUNTINGVAULT_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddress, amount, false, false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        executeOp(userOpData);
        userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        executeOp(userOpData);

        (ISuperLedger.LedgerEntry[] memory entries, uint256 unconsumedEntries) =
            superLedger.getLedger(account, address(vaultInstance));
        assertEq(entries.length, 2);
        assertEq(unconsumedEntries, 0);

        // set pps to 2$
        MockAccountingVault(yieldSourceAddress).setCustomPps(2e18);

        // assert pps
        uint256 sharesToWithdraw = SMALL; // should get 2 * SMALL amount
        uint256 amountOut = vaultInstance.convertToAssets(sharesToWithdraw);
        assertEq(amountOut, amount * 2);

        // prepare withdraw
        hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, WITHDRAW_4626_VAULT_HOOK_KEY);

        hooksData = new bytes[](1);
        hooksData[0] = _createWithdraw4626HookData(
            bytes32(bytes(MOCKACCOUNTINGVAULT_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceAddress,
            account,
            sharesToWithdraw,
            false,
            false
        );

        uint256 feeBalanceBefore = IERC20(underlying).balanceOf(address(this));

        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        executeOp(userOpData);

        uint256 feeBalanceAfter = IERC20(underlying).balanceOf(address(this));

        // profit should be 1% of SMALL ( = amount)
        assertEq(feeBalanceAfter - feeBalanceBefore, amount * 100 / 10_000);

        (entries, unconsumedEntries) = superLedger.getLedger(account, address(vaultInstance));
        assertEq(entries.length, 2);
        assertEq(unconsumedEntries, 1);
    }

    function test_MultipleDepositsAndFullWithdrawal_ForMultipleEntries_Fees() external {
        uint256 amount = SMALL;
        _getTokens(underlying, account, amount * 2);

        // make sure custom pps is 1
        MockAccountingVault(yieldSourceAddress).setCustomPps(1e18);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            bytes32(bytes(MOCKACCOUNTINGVAULT_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddress, amount, false, false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        executeOp(userOpData);
        userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        executeOp(userOpData);

        (ISuperLedger.LedgerEntry[] memory entries, uint256 unconsumedEntries) =
            superLedger.getLedger(account, address(vaultInstance));
        assertEq(entries.length, 2);
        assertEq(unconsumedEntries, 0);

        // set pps to 2$ and assure vault has enough assets
        MockAccountingVault(yieldSourceAddress).setCustomPps(2e18);
        _getTokens(underlying, address(vaultInstance), LARGE);

        // assert pps
        uint256 sharesToWithdraw = SMALL * 2; // should get 4 * SMALL amount
        uint256 amountOut = vaultInstance.convertToAssets(sharesToWithdraw);
        assertEq(amountOut, amount * 4);

        // prepare withdraw
        hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, WITHDRAW_4626_VAULT_HOOK_KEY);

        hooksData = new bytes[](1);
        hooksData[0] = _createWithdraw4626HookData(
            bytes32(bytes(MOCKACCOUNTINGVAULT_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceAddress,
            account,
            sharesToWithdraw,
            false,
            false
        );

        uint256 feeBalanceBefore = IERC20(underlying).balanceOf(address(this));

        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        executeOp(userOpData);

        uint256 feeBalanceAfter = IERC20(underlying).balanceOf(address(this));

        // profit should be 1% of SMALL*2 ( = amount*2)
        assertEq(feeBalanceAfter - feeBalanceBefore, amount * 200 / 10_000);

        (entries, unconsumedEntries) = superLedger.getLedger(account, address(vaultInstance));
        assertEq(entries.length, 2);
        assertEq(unconsumedEntries, 2);
    }

    function test_MultipleDepositsAndFullWithdrawal_ForSingleEntries_Fees() external {
        uint256 amount = SMALL;
        _getTokens(underlying, account, amount);

        // make sure custom pps is 1
        MockAccountingVault(yieldSourceAddress).setCustomPps(1e18);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            bytes32(bytes(MOCKACCOUNTINGVAULT_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddress, amount, false, false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        executeOp(userOpData);

        (ISuperLedger.LedgerEntry[] memory entries, uint256 unconsumedEntries) =
            superLedger.getLedger(account, address(vaultInstance));
        assertEq(entries.length, 1);
        assertEq(unconsumedEntries, 0);

        // set pps to 2$ and assure vault has enough assets
        MockAccountingVault(yieldSourceAddress).setCustomPps(2e18);
        _getTokens(underlying, address(vaultInstance), LARGE);

        // assert pps
        uint256 sharesToWithdraw = SMALL; // should get 4 * SMALL amount
        uint256 amountOut = vaultInstance.convertToAssets(sharesToWithdraw);
        assertEq(amountOut, amount * 2);

        // prepare withdraw
        hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, WITHDRAW_4626_VAULT_HOOK_KEY);

        hooksData = new bytes[](1);
        hooksData[0] = _createWithdraw4626HookData(
            bytes32(bytes(MOCKACCOUNTINGVAULT_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceAddress,
            account,
            sharesToWithdraw,
            false,
            false
        );

        uint256 feeBalanceBefore = IERC20(underlying).balanceOf(address(this));

        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        executeOp(userOpData);

        uint256 feeBalanceAfter = IERC20(underlying).balanceOf(address(this));

        // profit should be 1% of SMALL*2 ( = amount*2)
        assertEq(feeBalanceAfter - feeBalanceBefore, amount * 100 / 10_000);

        (entries, unconsumedEntries) = superLedger.getLedger(account, address(vaultInstance));
        assertEq(entries.length, 1);
        assertEq(unconsumedEntries, 1);
    }
}
