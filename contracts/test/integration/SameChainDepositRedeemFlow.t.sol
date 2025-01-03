// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { console } from "forge-std/console.sol";
import { ForkedTestBase } from "./ForkedTestBase.t.sol";
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../../src/interfaces/accounting/ISuperLedger.sol";

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/// @dev Forked mainnet test with deposit and redeem flow for a real ERC4626 vault
contract SameChainDepositRedeemFlowTest is ForkedTestBase {
    IERC4626 public vaultInstance;
    address public yieldSourceAddress;
    address public yieldSourceOracle;
    address public underlying;

    function setUp() public override {
        super.setUp();

        vm.selectFork(chainIds[0]);

        underlying = existingUnderlyingTokens[1]["USDC"];
        console.log("underlying", underlying);

        yieldSourceAddress = realVaultAddresses[1]["ERC4626"]["MorphoVault"]["USDC"];
        console.log("yieldSourceAddress", yieldSourceAddress);
        yieldSourceOracle = _getContract(ETH, "ERC4626YieldSourceOracle");
        vaultInstance = IERC4626(yieldSourceAddress);
    }

    function test_Deposit_4626_Mainnet_Flow() public {
        vm.selectFork(FORKS[ETH]);

        address account = accountInstances[ETH].account;
        console.log("account", account);

        uint256 amount = 1e8;
        address[] memory hooksAddresses = new address[](3);
        hooksAddresses[0] = _getHook(ETH, "ApproveERC20Hook");
        hooksAddresses[1] = _getHook(ETH, "Deposit4626VaultHook");
        hooksAddresses[2] = _getHook(ETH, "SuperAccountingHook");

        bytes[] memory hooksData = new bytes[](3);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount);
        hooksData[1] = _createDepositHookData(account, yieldSourceAddress, amount);
        hooksData[2] = _createSuperAccountingHookData(account, yieldSourceOracle, yieldSourceAddress);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        ISuperExecutor superExecutor = ISuperExecutor(_getContract(chainIds[0], "SuperExecutor"));
        vm.prank(account);
        superExecutor.execute(abi.encode(entry));
    }

    function test_Deposit_Redeem_4626_Mainnet_Flow() public {
        vm.selectFork(FORKS[ETH]);

        address account = accountInstances[ETH].account;

        uint256 amount = 1e8;
        address[] memory hooksAddresses = new address[](3);
        hooksAddresses[0] = _getHook(ETH, "ApproveERC20Hook");
        hooksAddresses[1] = _getHook(ETH, "Deposit4626VaultHook");
        hooksAddresses[2] = _getHook(ETH, "SuperAccountingHook");
        bytes[] memory hooksData = new bytes[](3);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount);
        hooksData[1] = _createDepositHookData(account, yieldSourceAddress, amount);
        hooksData[2] = _createSuperAccountingHookData(account, yieldSourceOracle, yieldSourceAddress);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        ISuperExecutor superExecutor = ISuperExecutor(_getContract(chainIds[0], "SuperExecutor"));

        vm.expectEmit(true, true, true, false);
        emit ISuperLedger.AccountingUpdated(account, yieldSourceOracle, yieldSourceAddress, true, amount, 1e18);
        vm.prank(account);
        superExecutor.execute(abi.encode(entry));

        uint256 accSharesAfter = vaultInstance.balanceOf(account);
        console.log("accSharesAfter", accSharesAfter);
        assertEq(accSharesAfter, vaultInstance.previewDeposit(amount));
        hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHook(ETH, "Withdraw4626VaultHook");
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createWithdrawHookData(account, yieldSourceOracle, yieldSourceAddress, accSharesAfter);
        hooksData[1] = _createSuperAccountingHookData(account, yieldSourceOracle, yieldSourceAddress);

        ISuperExecutor.ExecutorEntry memory entryWithdraw =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        vm.expectEmit(true, true, true, false);
        emit ISuperLedger.AccountingUpdated(account, yieldSourceOracle, yieldSourceAddress, false, accSharesAfter, 1e18);
        vm.prank(account);
        superExecutor.execute(abi.encode(entry));

        uint256 accSharesAfterWithdraw = vaultInstance.balanceOf(account);
        assertEq(accSharesAfterWithdraw, 0);
    }
}
