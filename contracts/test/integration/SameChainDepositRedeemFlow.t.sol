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

/// @dev Forked mainnet test with deposit and redeem flow for a real ERC4626 vault
contract SameChainDepositRedeemFlowTest is BaseTest {
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

    function test_Deposit_4626_Mainnet_Flow() public {
        vm.selectFork(FORKS[ETH]);

        uint256 amount = 1e8;
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHook(ETH, "ApproveERC20Hook");
        hooksAddresses[1] = _getHook(ETH, "Deposit4626VaultHook");

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] = _createDepositHookData(account, yieldSourceOracle, yieldSourceAddress, amount, false);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        executeOp(userOpData);
    }

    function test_Deposit_Redeem_4626_Mainnet_Flow() public {
        vm.selectFork(FORKS[ETH]);

        uint256 amount = 1e8;
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHook(ETH, "ApproveERC20Hook");
        hooksAddresses[1] = _getHook(ETH, "Deposit4626VaultHook");
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] = _createDepositHookData(account, yieldSourceOracle, yieldSourceAddress, amount, false);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        vm.expectEmit(true, true, true, false);
        emit ISuperLedger.AccountingUpdated(account, yieldSourceOracle, yieldSourceAddress, true, amount, 1e18);
        executeOp(userOpData);

        uint256 accSharesAfter = vaultInstance.balanceOf(account);

        assertEq(accSharesAfter, vaultInstance.previewDeposit(amount));

        hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHook(ETH, "Withdraw4626VaultHook");
        hooksData = new bytes[](2);
        hooksData[0] = _createWithdrawHookData(account, yieldSourceOracle, yieldSourceAddress, account, accSharesAfter, false);

        ISuperExecutor.ExecutorEntry memory entryWithdraw =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        userOpData = _getExecOps(instance, superExecutor, abi.encode(entryWithdraw));

        vm.expectEmit(true, true, true, false);
        emit ISuperLedger.AccountingUpdated(account, yieldSourceOracle, yieldSourceAddress, false, accSharesAfter, 1e18);

        executeOp(userOpData);

        uint256 accSharesAfterWithdraw = vaultInstance.balanceOf(account);
        assertEq(accSharesAfterWithdraw, 0);
    }
}
