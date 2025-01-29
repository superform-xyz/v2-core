// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

// Superform
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../../../src/core/interfaces/accounting/ISuperLedger.sol";

import { BaseTest } from "../../BaseTest.t.sol";

import { console2 } from "forge-std/console2.sol";

contract SuperExecutor_sameChainFlow is BaseTest {
    IERC4626 public vaultInstance;
    address public yieldSourceAddress;
    address public yieldSourceOracle;
    address public underlying;
    address public account;
    AccountInstance public instance;
    ISuperExecutor public superExecutor;

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);
        underlying = existingUnderlyingTokens[1]["USDC"];

        yieldSourceAddress = realVaultAddresses[1]["ERC4626"]["MorphoVault"]["USDC"];
        yieldSourceOracle = _getContract(ETH, "ERC4626YieldSourceOracle");
        vaultInstance = IERC4626(yieldSourceAddress);
        account = accountInstances[ETH].account;
        instance = accountInstances[ETH];
        superExecutor = ISuperExecutor(_getContract(ETH, "SuperExecutor"));
    }

    function test_ShouldExecuteAll(uint256 amount) external {
        amount = _bound(amount);

        _getTokens(underlying, account, amount);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, "ApproveERC20Hook");
        hooksAddresses[1] = _getHookAddress(ETH, "Deposit4626VaultHook");

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] = _createDepositHookData(
            account, bytes32("ERC4626YieldSourceOracle"), yieldSourceAddress, amount, false, false
        );
        uint256 sharesPreviewed = vaultInstance.previewDeposit(amount);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        executeOp(userOpData);

        uint256 accSharesAfter = vaultInstance.balanceOf(account);
        assertEq(accSharesAfter, sharesPreviewed);
    }

    function test_WhenHooksAreDefinedAndExecutionDataIsValid_Deposit_And_Withdraw_In_The_Same_Intent(uint256 amount)
        external
    {
        amount = _bound(amount);
        address[] memory hooksAddresses = new address[](3);
        hooksAddresses[0] = _getHookAddress(ETH, "ApproveERC20Hook");
        hooksAddresses[1] = _getHookAddress(ETH, "Deposit4626VaultHook");
        hooksAddresses[2] = _getHookAddress(ETH, "Withdraw4626VaultHook");

        bytes[] memory hooksData = new bytes[](5);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] = _createDepositHookData(
            account, bytes32("ERC4626YieldSourceOracle"), yieldSourceAddress, amount, false, false
        );
        hooksData[2] = _createWithdrawHookData(
            account, bytes32("ERC4626YieldSourceOracle"), yieldSourceAddress, account, amount, false, false
        );
        // assure account has tokens
        _getTokens(underlying, account, amount);

        // it should execute all hooks
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        emit ISuperLedger.AccountingUpdated(account, yieldSourceOracle, yieldSourceAddress, false, amount, 1e18);
        executeOp(userOpData);

        uint256 accSharesAfter = vaultInstance.balanceOf(account);
        assertGt(accSharesAfter, 0);
    }
}
