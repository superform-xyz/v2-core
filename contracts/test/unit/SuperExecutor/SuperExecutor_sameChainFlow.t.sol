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

    address yieldSourceOracle = address(erc4626YieldSourceOracle);

    modifier givenAnActionExist() {
        _;
    }

    modifier givenSentinelCallIsNotPerformed() {
        _;
    }

    function test_ShouldExecuteAll(uint256 amount) external givenAnActionExist {
        amount = _bound(amount);

        _getTokens(address(mockERC20), instance.account, amount);
        address yieldSourceAddress = address(mock4626Vault);

        address[] memory hooksAddresses = new address[](3);
        hooksAddresses[0] = address(approveErc20Hook);
        hooksAddresses[1] = address(deposit4626VaultHook);
        hooksAddresses[2] = address(superLedgerHook);

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

        // assure account has tokens
        _getTokens(address(mockERC20), instance.account, amount);

        address[] memory hooksAddresses = new address[](3);
        hooksAddresses[0] = address(approveErc20Hook);
        hooksAddresses[1] = address(deposit4626VaultHook);
        hooksAddresses[2] = address(superLedgerHook);

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

    function test_WhenHooksAreDefinedAndExecutionDataIsValid_Deposit_And_Withdraw_In_The_Same_Intent(uint256 amount)
        external
        givenAnActionExist
        givenSentinelCallIsNotPerformed
    {
        amount = _bound(amount);
        address yieldSourceAddress = address(mock4626Vault);
        address[] memory hooksAddresses = new address[](4);
        hooksAddresses[0] = address(approveErc20Hook);
        hooksAddresses[1] = address(deposit4626VaultHook);
        hooksAddresses[2] = address(superLedgerHook);
        hooksAddresses[3] = address(withdraw4626VaultHook);
        hooksAddresses[4] = address(superLedgerHook);

        bytes[] memory hooksData = new bytes[](5);
        hooksData[0] = _createApproveHookData(address(mockERC20), yieldSourceAddress, amount);
        hooksData[1] = _createDepositHookData(instance.account, yieldSourceAddress, amount);
        hooksData[2] = _createSuperAccountingHookData(instance.account, yieldSourceOracle, yieldSourceAddress);
        hooksData[3] = _createWithdrawHookData(instance.account, yieldSourceAddress, amount);
        hooksData[4] = _createSuperAccountingHookData(instance.account, yieldSourceOracle, yieldSourceAddress);
        // assure account has tokens
        _getTokens(address(mockERC20), instance.account, amount);

        // it should execute all hooks
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(abi.encode(entry));
        emit ISuperLedger.AccountingUpdated(
            instance.account, yieldSourceOracle, yieldSourceAddress, false, amount, 1e18
        );
        executeOp(userOpData);

        uint256 accSharesAfter = mock4626Vault.balanceOf(instance.account);
        assertEq(accSharesAfter, 0);
    }
}
