// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

// Superform
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../../../src/core/interfaces/accounting/ISuperLedger.sol";

import { SwapOdosHook } from "../../../src/core/hooks/swappers/odos/SwapOdosHook.sol";

import { MockOdosRouterV2 } from "../../mocks/MockOdosRouterV2.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { BaseTest } from "../../BaseTest.t.sol";

import "forge-std/console.sol";

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
        underlying = existingUnderlyingTokens[1][USDC_KEY];

        yieldSourceAddress = realVaultAddresses[1][ERC4626_VAULT_KEY][MORPHO_VAULT_KEY][USDC_KEY];
        yieldSourceOracle = _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY);
        vaultInstance = IERC4626(yieldSourceAddress);
        account = accountInstances[ETH].account;
        instance = accountInstances[ETH];
        superExecutor = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
    }

    function test_ShouldExecuteAll(uint256 amount) external {
        amount = _bound(amount);

        _getTokens(underlying, account, amount);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddress, amount, false, false
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
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);
        hooksAddresses[2] = _getHookAddress(ETH, WITHDRAW_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](5);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddress, amount, false, false
        );
        hooksData[2] = _createWithdraw4626HookData(
            bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddress, account, amount, false, false
        );
        // assure account has tokens
        _getTokens(underlying, account, amount);

        // it should execute all hooks
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        emit ISuperLedger.AccountingInflow(account, yieldSourceOracle, yieldSourceAddress, amount, 1e18);
        executeOp(userOpData);

        uint256 accSharesAfter = vaultInstance.balanceOf(account);
        assertGt(accSharesAfter, 0);
    }

    function test_SwapThroughMockOdosRouter(uint256 amount) external {
        amount = _bound(amount);

        MockERC20 inputToken = new MockERC20("A","A",18);
        MockERC20 outputToken = new MockERC20("B","B",18);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, SWAP_ODOS_HOOK_KEY);

        _getTokens(address(inputToken), odosRouters[ETH], amount);
        _getTokens(address(outputToken), odosRouters[ETH], amount);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(address(inputToken), odosRouters[ETH], amount, false);
        hooksData[1] = _createOdosSwapHookData(
            address(inputToken),
            amount,
            account,
            address(outputToken),
            0,
            amount,
            "",
            address(this),
            uint32(0),
            false
        );

        // it should execute all hooks
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        executeOp(userOpData);
    }
}
