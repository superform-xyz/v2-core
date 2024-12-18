// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { ISuperExecutorV2 } from "../../../src/interfaces/ISuperExecutorV2.sol";
import { Unit_Shared } from "../Unit_Shared.t.sol";
import { ISuperActions } from "../../../src/interfaces/strategies/ISuperActions.sol";
import { SuperPositionSentinel } from "../../../src/sentinels/SuperPositionSentinel.sol";

import { console2 } from "forge-std/console2.sol";

contract SuperExecutor_sameChainFlow is Unit_Shared {
    address RANDOM_TARGET = address(uint160(uint256(keccak256(abi.encodePacked(block.timestamp, address(this))))));

    /// @dev NOTE: Cosmin, I think this test does not belong here, but rather to a SuperActions test suite
    function test_GivenAnActionDoesNotExist(uint256 amount) external {
        amount = _bound(amount);
        // it should revert with ACTION_NOT_FOUND

        uint256 actionId = uint256(uint256(keccak256(abi.encodePacked(block.timestamp, address(this)))));
        bytes[] memory hooksData = new bytes[](0);

        ISuperExecutorV2.ExecutorEntry[] memory entries = new ISuperExecutorV2.ExecutorEntry[](1);
        entries[0] = ISuperExecutorV2.ExecutorEntry({
            actionId: actionId,
            finalTarget: RANDOM_TARGET,
            hooksData: hooksData,
            nonMainActionHooks: new address[](0)
        });

        vm.expectRevert(ISuperActions.ACTION_NOT_FOUND.selector);
        superExecutor.execute(instance.account, abi.encode(entries));
    }

    modifier givenAnActionExist() {
        _;
    }

    function test_RevertWhen_HooksAreDefinedByExecutionDataIsNotValid() external givenAnActionExist {
        // it should revert
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = abi.encode(uint256(1));
        hooksData[1] = abi.encode(uint256(1));

        ISuperExecutorV2.ExecutorEntry[] memory entries = new ISuperExecutorV2.ExecutorEntry[](1);
        entries[0] = ISuperExecutorV2.ExecutorEntry({
            actionId: ACTION["4626_DEPOSIT"],
            finalTarget: RANDOM_TARGET,
            hooksData: hooksData,
            nonMainActionHooks: new address[](0)
        });

        /// @dev COSMIN: should use named error
        vm.expectRevert();
        superExecutor.execute(instance.account, abi.encode(entries));
    }

    modifier givenSentinelCallIsNotPerformed() {
        _;
    }

    function test_WhenHooksHasNonActionHooks_ShouldExecuteAll(uint256 amount) external givenAnActionExist {
        amount = _bound(amount);
        /// @dev Note: this test should fail because it contains hooks that should always be part of a main action, such
        /// as deposit4626VaultHook
        // assure account has tokens
        _getTokens(address(mockERC20), instance.account, amount);
        address finalTarget = address(mock4626Vault);
        bytes[] memory hooksData = _createDepositActionData(finalTarget, amount);
        address[] memory hooks = new address[](2);
        hooks[0] = address(approveErc20Hook);
        hooks[1] = address(deposit4626VaultHook);

        ISuperExecutorV2.ExecutorEntry[] memory entries = new ISuperExecutorV2.ExecutorEntry[](1);
        entries[0] = ISuperExecutorV2.ExecutorEntry({
            actionId: type(uint256).max,
            finalTarget: address(0),
            hooksData: hooksData,
            nonMainActionHooks: hooks
        });

        superExecutor.execute(instance.account, abi.encode(entries));

        uint256 accSharesAfter = mock4626Vault.balanceOf(instance.account);
        assertEq(accSharesAfter, amount);
    }

    function test_WhenHooksAreDefinedAndExecutionDataIsValid(uint256 amount)
        external
        givenAnActionExist
        givenSentinelCallIsNotPerformed
    {
        amount = _bound(amount);
        address finalTarget = address(mock4626Vault);

        bytes[] memory hooksData = _createDepositActionData(finalTarget, amount);

        // assure account has tokens
        _getTokens(address(mockERC20), instance.account, amount);

        // extra non-action set of hooks
        bytes[] memory nonMainActionHooksData = new bytes[](1);
        nonMainActionHooksData[0] = abi.encode(address(mockERC20), address(user2), amount);
        address[] memory nonMainActionHooks = new address[](1);
        nonMainActionHooks[0] = address(approveErc20Hook);

        // it should execute all hooks
        ISuperExecutorV2.ExecutorEntry[] memory entries = new ISuperExecutorV2.ExecutorEntry[](2);
        entries[0] = ISuperExecutorV2.ExecutorEntry({
            actionId: ACTION["4626_DEPOSIT"],
            finalTarget: finalTarget,
            hooksData: hooksData,
            nonMainActionHooks: new address[](0)
        });
        entries[1] = ISuperExecutorV2.ExecutorEntry({
            actionId: type(uint256).max,
            finalTarget: address(0),
            hooksData: nonMainActionHooksData,
            nonMainActionHooks: nonMainActionHooks
        });
        vm.expectEmit(true, true, true, true);
        emit ISuperActions.AccountingUpdated(instance.account, ACTION["4626_DEPOSIT"], finalTarget, true, amount, 1e18);
        superExecutor.execute(instance.account, abi.encode(entries));

        uint256 accSharesAfter = mock4626Vault.balanceOf(instance.account);
        assertEq(accSharesAfter, amount);

        uint256 allowanceForUser2 = mockERC20.allowance(instance.account, user2);
        assertEq(allowanceForUser2, amount);
    }

    function test_WhenHooksAreDefinedAndExecutionDataIsValid_Deposit_And_Withdraw_In_The_Same_Intent(uint256 amount)
        external
        givenAnActionExist
        givenSentinelCallIsNotPerformed
    {
        amount = _bound(amount);
        address finalTarget = address(mock4626Vault);
        bytes[] memory depositHooksData = _createDepositActionData(finalTarget, amount);
        bytes[] memory withdrawHooksData = _createWithdrawActionData(finalTarget, amount);
        // assure account has tokens
        _getTokens(address(mockERC20), instance.account, amount);

        // it should execute all hooks
        ISuperExecutorV2.ExecutorEntry[] memory entries = new ISuperExecutorV2.ExecutorEntry[](2);
        entries[0] = ISuperExecutorV2.ExecutorEntry({
            actionId: ACTION["4626_DEPOSIT"],
            finalTarget: finalTarget,
            hooksData: depositHooksData,
            nonMainActionHooks: new address[](0)
        });
        entries[1] = ISuperExecutorV2.ExecutorEntry({
            actionId: ACTION["4626_WITHDRAW"],
            finalTarget: finalTarget,
            hooksData: withdrawHooksData,
            nonMainActionHooks: new address[](0)
        });

        superExecutor.execute(instance.account, abi.encode(entries));

        uint256 accSharesAfter = mock4626Vault.balanceOf(instance.account);
        assertEq(accSharesAfter, 0);
    }

    function _createDepositActionData(
        address finalTarget,
        uint256 amount
    )
        internal
        view
        returns (bytes[] memory hooksData)
    {
        hooksData = new bytes[](2);
        hooksData[0] = abi.encode(address(mockERC20), finalTarget, amount);
        hooksData[1] = abi.encode(finalTarget, instance.account, amount);
    }

    function _createDepositWithdrawActionData(
        address finalTarget,
        uint256 amount
    )
        internal
        view
        returns (bytes[] memory hooksData)
    {
        hooksData = new bytes[](3);
        hooksData[0] = abi.encode(address(mockERC20), finalTarget, amount);
        hooksData[1] = abi.encode(finalTarget, instance.account, amount);
        hooksData[2] = abi.encode(finalTarget, instance.account, instance.account, 100);
    }

    function _createWithdrawActionData(
        address finalTarget,
        uint256 amount
    )
        internal
        view
        returns (bytes[] memory hooksData)
    {
        hooksData = new bytes[](1);
        hooksData[0] = abi.encode(finalTarget, instance.account, instance.account, amount);
    }
}
