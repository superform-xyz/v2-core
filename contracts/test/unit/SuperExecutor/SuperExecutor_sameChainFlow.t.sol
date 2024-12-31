// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { UserOpData } from "modulekit/ModuleKit.sol";

// Superform
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperActions } from "../../../src/interfaces/strategies/ISuperActions.sol";

import { Unit_Shared } from "../Unit_Shared.t.sol";

contract SuperExecutor_sameChainFlow is Unit_Shared {

    address RANDOM_TARGET = address(uint160(uint256(keccak256(abi.encodePacked(block.timestamp, address(this))))));

    /**
    /// @dev NOTE: Cosmin, I think this test does not belong here, but rather to a SuperActions test suite
    function test_GivenAnActionDoesNotExist(uint256 amount) external {
        amount = _bound(amount);
        // it should revert with ACTION_NOT_FOUND

        uint256 actionId = uint256(uint256(keccak256(abi.encodePacked(block.timestamp, address(this)))));
        bytes[] memory hooksData = new bytes[](0);

        ISuperExecutor.ExecutorEntry[] memory entries = new ISuperExecutor.ExecutorEntry[](1);
        entries[0] = ISuperExecutor.ExecutorEntry({
            actionId: actionId,
            yieldSourceAddress: RANDOM_TARGET,
            hooksData: hooksData,
            nonMainActionHooks: new address[](0)
        });

        UserOpData memory userOpData = _getExecOps(abi.encode(entries));
        vm.expectRevert();
        executeOp(userOpData);
    }
   */
    modifier givenAnActionExist() {
        _;
    }

    /**
    function test_RevertWhen_HooksAreDefinedByExecutionDataIsNotValid() external givenAnActionExist {
        // it should revert
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = abi.encode(uint256(1));
        hooksData[1] = abi.encode(uint256(1));

        ISuperExecutor.ExecutorEntry[] memory entries = new ISuperExecutor.ExecutorEntry[](1);
        entries[0] = ISuperExecutor.ExecutorEntry({
            actionId: ACTION["4626_DEPOSIT"],
            yieldSourceAddress: RANDOM_TARGET,
            hooksData: hooksData,
            nonMainActionHooks: new address[](0)
        });

        UserOpData memory userOpData = _getExecOps(abi.encode(entries));
        vm.expectRevert();
        executeOp(userOpData);
    }
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
        bytes[] memory hooksData = _createDepositActionData(yieldSourceAddress, amount);
        address[] memory hooks = new address[](2);
        hooks[0] = address(approveErc20Hook);
        hooks[1] = address(deposit4626VaultHook);

        ISuperExecutor.ExecutorEntry[] memory entries = new ISuperExecutor.ExecutorEntry[](1);
        entries[0] = ISuperExecutor.ExecutorEntry({
            actionId: type(uint256).max,
            yieldSourceAddress: address(0),
            hooksData: hooksData,
            nonMainActionHooks: hooks
        });

        UserOpData memory userOpData = _getExecOps(abi.encode(entries));
        executeOp(userOpData);

        uint256 accSharesAfter = mock4626Vault.balanceOf(instance.account);
        assertEq(accSharesAfter, amount);
    }

    function test_WhenHooksAreDefinedAndExecutionDataIsValidQQQ(uint256 amount)
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
        nonMainActionHooksData[0] = abi.encode(address(mockERC20), address(user2), amount);
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
        vm.expectEmit(true, true, true, true);

        emit ISuperActions.AccountingUpdated(instance.account, ACTION["4626_DEPOSIT"], yieldSourceAddress, true, amount, 1e18);
        executeOp(userOpData);

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
        emit ISuperActions.AccountingUpdated(
            instance.account, ACTION["4626_WITHDRAW"], yieldSourceAddress, false, amount, 1e18
        );
        executeOp(userOpData);

        uint256 accSharesAfter = mock4626Vault.balanceOf(instance.account);
        assertEq(accSharesAfter, 0);
    }

    function _createDepositActionData(
        address yieldSourceAddress,
        uint256 amount
    )
        internal
        view
        returns (bytes[] memory hooksData)
    {
        hooksData = new bytes[](2);
        hooksData[0] = abi.encode(address(mockERC20), yieldSourceAddress, amount);
        hooksData[1] = abi.encode(yieldSourceAddress, instance.account, amount);
    }

    function _createDepositWithdrawActionData(
        address yieldSourceAddress,
        uint256 amount
    )
        internal
        view
        returns (bytes[] memory hooksData)
    {
        hooksData = new bytes[](3);
        hooksData[0] = abi.encode(address(mockERC20), yieldSourceAddress, amount);
        hooksData[1] = abi.encode(yieldSourceAddress, instance.account, amount);
        hooksData[2] = abi.encode(yieldSourceAddress, instance.account, instance.account, 100);
    }

    function _createWithdrawActionData(
        address yieldSourceAddress,
        uint256 amount
    )
        internal
        view
        returns (bytes[] memory hooksData)
    {
        hooksData = new bytes[](1);
        hooksData[0] = abi.encode(yieldSourceAddress, instance.account, instance.account, amount);
    }
}
