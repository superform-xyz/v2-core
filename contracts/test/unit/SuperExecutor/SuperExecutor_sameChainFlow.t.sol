// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { UserOpData } from "modulekit/ModuleKit.sol";

// Superform
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../../../src/interfaces/accounting/ISuperLedger.sol";

import { Unit_Shared } from "../Unit_Shared.t.sol";

contract SuperExecutor_sameChainFlow is Unit_Shared {
    address RANDOM_TARGET = address(uint160(uint256(keccak256(abi.encodePacked(block.timestamp, address(this))))));

    /**
     * /// @dev NOTE: Cosmin, I think this test does not belong here, but rather to a SuperActions test suite
     * function test_GivenAnActionDoesNotExist(uint256 amount) external {
     *     amount = _bound(amount);
     *     // it should revert with ACTION_NOT_FOUND
     *
     *     uint256 actionId = uint256(uint256(keccak256(abi.encodePacked(block.timestamp, address(this)))));
     *     bytes[] memory hooksData = new bytes[](0);
     *
     *     ISuperExecutor.ExecutorEntry[] memory entries = new ISuperExecutor.ExecutorEntry[](1);
     *     entries[0] = ISuperExecutor.ExecutorEntry({
     *         actionId: actionId,
     *         yieldSourceAddress: RANDOM_TARGET,
     *         hooksData: hooksData,
     *         nonMainActionHooks: new address[](0)
     *     });
     *
     *     UserOpData memory userOpData = _getExecOps(abi.encode(entries));
     *     vm.expectRevert();
     *     executeOp(userOpData);
     * }
     */
    modifier givenAnActionExist() {
        _;
    }

    /**
     * function test_RevertWhen_HooksAreDefinedByExecutionDataIsNotValid() external givenAnActionExist {
     *     // it should revert
     *     bytes[] memory hooksData = new bytes[](2);
     *     hooksData[0] = abi.encode(uint256(1));
     *     hooksData[1] = abi.encode(uint256(1));
     *
     *     ISuperExecutor.ExecutorEntry[] memory entries = new ISuperExecutor.ExecutorEntry[](1);
     *     entries[0] = ISuperExecutor.ExecutorEntry({
     *         actionId: ACTION["4626_DEPOSIT"],
     *         yieldSourceAddress: RANDOM_TARGET,
     *         hooksData: hooksData,
     *         nonMainActionHooks: new address[](0)
     *     });
     *
     *     UserOpData memory userOpData = _getExecOps(abi.encode(entries));
     *     vm.expectRevert();
     *     executeOp(userOpData);
     * }
     */
    modifier givenSentinelCallIsNotPerformed() {
        _;
    }

    function test_WhenHooksHasNonActionHooks_ShouldExecuteAll(uint256 amount) external givenAnActionExist {
        amount = _bound(amount);
        /// @dev Note: this test should fail because it contains hooks that should always be part of a main action, such
        /// as deposit4626VaultHook
        // assure account has tokens
        _getTokens(address(mockERC20), instance.account, amount);
        address yieldSourceAddress = address(mock4626Vault);

        address[] memory hooksAddresses = new address[](3);
        hooksAddresses[0] = address(approveErc20Hook);
        hooksAddresses[1] = address(deposit4626VaultHook);
        hooksAddresses[2] = address(superAccountingHook);

        bytes[] memory hooksData = new bytes[](3);
        hooksData[0] = _createApproveHookData(address(mockERC20), yieldSourceAddress, amount);
        hooksData[1] = _createDepositHookData(instance.account, yieldSourceAddress, amount);
        hooksData[2] = _createSuperAccountingHookData(instance.account, yieldSourceOracle, yieldSourceAddress);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        UserOpData memory userOpData = _getExecOps(abi.encode(entry));
        executeOp(userOpData);

        uint256 accSharesAfter = mock4626Vault.balanceOf(instance.account);
        assertEq(accSharesAfter, amount);
    }

    function test_WhenHooksAreDefinedAndExecutionDataIsValid(uint256 amount)
        external
        givenAnActionExist
        givenSentinelCallIsNotPerformed
    {
        amount = _bound(amount);
        address yieldSourceAddress = address(mock4626Vault);

        bytes[] memory hooksData = _createDepositActionData(yieldSourceAddress, amount);

        // assure account has tokens
        _getTokens(address(mockERC20), instance.account, amount);

        // extra non-action set of hooks
        bytes[] memory nonMainActionHooksData = new bytes[](1);
        nonMainActionHooksData[0] = abi.encodePacked(address(mockERC20), address(user2), amount, false);
        address[] memory nonMainActionHooks = new address[](1);
        nonMainActionHooks[0] = address(approveErc20Hook);

        address[] memory hooksAddresses = new address[](3);
        hooksAddresses[0] = address(approveErc20Hook);
        hooksAddresses[1] = address(deposit4626VaultHook);
        hooksAddresses[2] = address(superAccountingHook);

        bytes[] memory hooksData = new bytes[](4);
        hooksData[0] = _createApproveHookData(address(mockERC20), yieldSourceAddress, amount);
        hooksData[1] = _createDepositHookData(instance.account, yieldSourceAddress, amount);
        hooksData[2] = _createSuperAccountingHookData(instance.account, yieldSourceOracle, yieldSourceAddress);
        hooksData[3] = abi.encodePacked(address(mockERC20), address(user2), amount, false);

        // it should execute all hooks
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        UserOpData memory userOpData = _getExecOps(abi.encode(entry));
        vm.expectEmit(true, true, true, true);

        emit ISuperLedger.AccountingUpdated(instance.account, yieldSourceOracle, yieldSourceAddress, true, amount, 1e18);
        executeOp(userOpData);

        uint256 accSharesAfter = mock4626Vault.balanceOf(instance.account);
        assertEq(accSharesAfter, amount);

        uint256 allowanceForUser2 = mockERC20.allowance(instance.account, user2);
        assertEq(allowanceForUser2, amount);
    }

    function test_WhenHooksAreDefinedAndExecutionDataIsValid_AndContextIsPassedBetweenActionsAndHooks(uint256 amount)
        external
        givenAnActionExist
        givenSentinelCallIsNotPerformed
    {
        amount = _bound(amount);
        address yieldSourceAddress = address(mock4626Vault);

        // should get less shares than amount
        mock4626Vault.setLessAmount(true);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = abi.encodePacked(address(mockERC20), yieldSourceAddress, amount, false);
        hooksData[1] = abi.encodePacked(yieldSourceAddress, instance.account, uint256(0), true);

        // assure account has tokens
        _getTokens(address(mockERC20), instance.account, amount);

        // extra non-action set of hooks
        bytes[] memory nonMainActionHooksData = new bytes[](1);
        // `true` means use the amount from the previous hook = obtained shares
        nonMainActionHooksData[0] = abi.encodePacked(address(mockERC20), address(user2), uint256(0), true);
        address[] memory nonMainActionHooks = new address[](1);
        nonMainActionHooks[0] = address(approveErc20Hook);

        // it should execute all hooks
        ISuperExecutor.ExecutorEntry[] memory entries = new ISuperExecutor.ExecutorEntry[](2);
        entries[0] = ISuperExecutor.ExecutorEntry({
            actionId: ACTION["4626_DEPOSIT"],
            yieldSourceAddress: yieldSourceAddress,
            hooksData: hooksData,
            nonMainActionHooks: new address[](0)
        });
        entries[1] = ISuperExecutor.ExecutorEntry({
            actionId: type(uint256).max,
            yieldSourceAddress: address(0),
            hooksData: nonMainActionHooksData,
            nonMainActionHooks: nonMainActionHooks
        });
        UserOpData memory userOpData = _getExecOps(abi.encode(entries));
        executeOp(userOpData);

        uint256 accSharesAfter = mock4626Vault.balanceOf(instance.account);
        assertEq(accSharesAfter, amount / 2, "A");

        uint256 allowanceForUser2 = mockERC20.allowance(instance.account, user2);
        assertEq(allowanceForUser2, amount / 2, "B");
    }

    function test_WhenHooksAreDefinedAndExecutionDataIsValid_Deposit_And_Withdraw_In_The_Same_Intent(uint256 amount)
        external
        givenAnActionExist
        givenSentinelCallIsNotPerformed
    {
        amount = _bound(amount);
        address yieldSourceAddress = address(mock4626Vault);
        bytes[] memory depositHooksData = _createDepositActionData(yieldSourceAddress, amount);
        bytes[] memory withdrawHooksData = _createWithdrawActionData(yieldSourceAddress, amount);
        // assure account has tokens
        _getTokens(address(mockERC20), instance.account, amount);

        // it should execute all hooks
        ISuperExecutor.ExecutorEntry[] memory entries = new ISuperExecutor.ExecutorEntry[](2);
        entries[0] = ISuperExecutor.ExecutorEntry({
            actionId: ACTION["4626_DEPOSIT"],
            yieldSourceAddress: yieldSourceAddress,
            hooksData: depositHooksData,
            nonMainActionHooks: new address[](0)
        });
        entries[1] = ISuperExecutor.ExecutorEntry({
            actionId: ACTION["4626_WITHDRAW"],
            yieldSourceAddress: yieldSourceAddress,
            hooksData: withdrawHooksData,
            nonMainActionHooks: new address[](0)
        });

        UserOpData memory userOpData = _getExecOps(abi.encode(entries));
        vm.expectEmit(true, true, true, true);
        emit ISuperLedger.AccountingUpdated(
            instance.account, ACTION["4626_WITHDRAW"], yieldSourceAddress, false, amount, 1e18
        );
        executeOp(userOpData);

        uint256 accSharesAfter = mock4626Vault.balanceOf(instance.account);
        assertEq(accSharesAfter, 0);
    }
}
