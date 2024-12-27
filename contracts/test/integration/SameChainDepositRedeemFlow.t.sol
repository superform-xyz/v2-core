// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { ForkedTestBase } from "./ForkedTestBase.t.sol";
import { ISuperExecutorV2 } from "src/interfaces/ISuperExecutorV2.sol";
import { ISuperActions } from "src/interfaces/strategies/ISuperActions.sol";
import { ERC4626 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

/// @dev Forked mainnet test with deposit and redeem flow for a real ERC4626 vault in the same intent
contract SameChainDepositRedeemFlowTest is ForkedTestBase {
    ERC4626 public vaultInstance;

    address public underlying;

    function setUp() public override {
        super.setUp();

        vm.selectFork(chainIds[0]);

        underlying = existingUnderlyingTokens[1]["DAI"];
        vaultInstance = ERC4626(realVaultAddresses[1]["ERC4626"]["YearnDaiYVault"]["DAI"]);
    }

    function test_Deposit_Redeem_Mainnet_4626_Flow() public {
        vm.selectFork(chainIds[0]);
        address finalTarget = address(vaultInstance);
        uint256 amount = 1e18;
        bytes[] memory depositHooksData = _createDepositActionData(finalTarget, underlying, amount);
        bytes[] memory redeemHooksData = _createWithdrawActionData(finalTarget, amount);

        // extra non-action set of hooks
        bytes[] memory nonMainActionHooksData = new bytes[](1);
        nonMainActionHooksData[0] = abi.encode(underlying, instance.account, amount); //Should account be user2?
        //nonMainActionHooksData[1] = abi.encode(finalTarget, instance.account, amount);
        address[] memory nonMainActionHooks = new address[](1);
        nonMainActionHooks[0] = address(approveErc20Hook);
        //nonMainActionHooks[1] = address(deposit4626VaultHook);

        // it should execute all hooks
        ISuperExecutorV2.ExecutorEntry[] memory entries = new ISuperExecutorV2.ExecutorEntry[](1);
        entries[0] = ISuperExecutorV2.ExecutorEntry({
            actionId: ACTION["4626_DEPOSIT"],
            finalTarget: finalTarget,
            hooksData: depositHooksData,
            nonMainActionHooks: new address[](0)
        });
        entries[1] = ISuperExecutorV2.ExecutorEntry({
            actionId: ACTION["4626_WITHDRAW"],
            finalTarget: finalTarget,
            //hooksData: redeemHooksData,
            hooksData: nonMainActionHooksData,
            nonMainActionHooks: nonMainActionHooks
        });

        // vm.expectEmit(true, true, true, true);
        // emit ISuperActions.AccountingUpdated(
        //     instance.account, ACTION["4626_WITHDRAW"], finalTarget, false, amount, 1e18
        // );
        superExecutor.execute(instance.account, abi.encode(entries));

        uint256 accSharesAfter = vaultInstance.balanceOf(instance.account);
        assertEq(accSharesAfter, 0);
    }
}
