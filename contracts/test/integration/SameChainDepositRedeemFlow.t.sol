// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { console } from "forge-std/console.sol";
import { ForkedTestBase } from "./ForkedTestBase.t.sol";
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { ISuperActions } from "../../src/interfaces/strategies/ISuperActions.sol";

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/// @dev Forked mainnet test with deposit and redeem flow for a real ERC4626 vault
contract SameChainDepositRedeemFlowTest is ForkedTestBase {
    IERC4626 public vaultInstance;
    address public yieldSourceAddress;

    address public underlying;

    function setUp() public override {
        super.setUp();

        vm.selectFork(chainIds[0]);

        underlying = existingUnderlyingTokens[1]["USDC"];
        console.log("underlying", underlying);

        yieldSourceAddress = realVaultAddresses[1]["ERC4626"]["MorphoVault"]["USDC"];
        console.log("yieldSourceAddress", yieldSourceAddress);

        vaultInstance = IERC4626(yieldSourceAddress);
    }

    function test_Deposit_4626_Mainnet_Flow() public {
        vm.selectFork(FORKS[ETH]);

        address account = accountInstances[ETH].account;
        console.log("account", account);

        uint256 amount = 1e8;

        bytes[] memory depositHooksData = _createDepositActionData(account, yieldSourceAddress, underlying, amount);

        ISuperExecutor.ExecutorEntry[] memory entries = new ISuperExecutor.ExecutorEntry[](1);
        entries[0] = ISuperExecutor.ExecutorEntry({
            actionId: ACTION["4626_DEPOSIT"][ETH],
            yieldSourceAddress: yieldSourceAddress,
            hooksData: depositHooksData,
            nonMainActionHooks: new address[](0)
        });

        ISuperExecutor superExecutor = ISuperExecutor(_getContract(chainIds[0], "SuperExecutor"));
        vm.prank(account);
        superExecutor.execute(abi.encode(entries));
    }

    function test_Deposit_Redeem_4626_Mainnet_Flow() public {
        vm.selectFork(FORKS[ETH]);

        address account = accountInstances[ETH].account;

        uint256 amount = 1e8;

        bytes[] memory depositHooksData = _createDepositActionData(
            account, 
            yieldSourceAddress, 
            underlying, 
            amount
        );

        ISuperExecutor.ExecutorEntry[] memory entries = new ISuperExecutor.ExecutorEntry[](1);
        entries[0] = ISuperExecutor.ExecutorEntry({
            actionId: ACTION["4626_DEPOSIT"][ETH],
            yieldSourceAddress: yieldSourceAddress,
            hooksData: depositHooksData,
            nonMainActionHooks: new address[](0)
        });

        ISuperExecutor superExecutor = ISuperExecutor(_getContract(chainIds[0], "SuperExecutor"));

        vm.expectEmit(true, true, true, false);
        emit ISuperActions.AccountingUpdated(
            account, 
            ACTION["4626_DEPOSIT"][ETH], 
            yieldSourceAddress, 
            true, 
            amount, 
            1e18
        );
        vm.prank(account);
        superExecutor.execute(abi.encode(entries));

        uint256 accSharesAfter = vaultInstance.balanceOf(account);
        console.log("accSharesAfter", accSharesAfter);
        assertEq(accSharesAfter, vaultInstance.previewDeposit(amount));

        bytes[] memory redeemHooksData = _createWithdrawActionData(
            account,
            yieldSourceAddress,
            accSharesAfter
        );

        ISuperExecutor.ExecutorEntry[] memory entriesWithdraw = new ISuperExecutor.ExecutorEntry[](1);

        entriesWithdraw[0] = ISuperExecutor.ExecutorEntry({
            actionId: ACTION["4626_WITHDRAW"][ETH],
            yieldSourceAddress: yieldSourceAddress,
            hooksData: redeemHooksData,
            nonMainActionHooks: new address[](0)
        });

        ISuperExecutor superExecutorWithdraw = ISuperExecutor(_getContract(chainIds[0], "SuperExecutor"));

        vm.expectEmit(true, true, true, false);
        emit ISuperActions.AccountingUpdated(
            account, 
            ACTION["4626_WITHDRAW"][ETH], 
            yieldSourceAddress, 
            false, 
            accSharesAfter, 
            1e18
        );
        vm.prank(account);
        superExecutorWithdraw.execute(abi.encode(entriesWithdraw));

        uint256 accSharesAfterWithdraw = vaultInstance.balanceOf(account);
        assertEq(accSharesAfterWithdraw, 0);
    }
}
