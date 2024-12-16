// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { ISuperExecutorV2 } from "../../../src/interfaces/ISuperExecutorV2.sol";
import { Unit_Shared } from "../Unit_Shared.t.sol";
import { ISuperActions } from "../../../src/interfaces/strategies/ISuperActions.sol";
import { SuperPositionSentinel } from "../../../src/sentinels/SuperPositionSentinel.sol";

contract SuperExecutor_sameChainFlow is Unit_Shared {
    address RANDOM_TARGET = address(uint160(uint256(keccak256(abi.encodePacked(block.timestamp, address(this))))));

    /// @dev NOTE: Cosmin, I think this test does not belong here, but rather to a SuperActions test suite
    function test_GivenAnActionDoesNotExist(uint256 amount) external {
        amount = _bound(amount);
        // it should revert with ACTION_NOT_FOUND

        uint256 actionId = uint256(uint256(keccak256(abi.encodePacked(block.timestamp, address(this)))));
        bytes[] memory hooksData = new bytes[](0);

        ISuperExecutorV2.ExecutorEntry[] memory entries = new ISuperExecutorV2.ExecutorEntry[](1);
        entries[0] =
            ISuperExecutorV2.ExecutorEntry({ actionId: actionId, finalTarget: RANDOM_TARGET, hooksData: hooksData });

        vm.expectRevert(ISuperActions.ACTION_NOT_FOUND.selector);
        superExecutor.execute(instance.account, abi.encode(entries));
    }

    modifier givenAnActionExist() {
        _;
    }

    /// @dev NOTE: Cosmin, I think this test does not belong here, but rather to a SuperActions test suite
    function test_RevertWhen_NoHooksAreDefined() external givenAnActionExist {
        // it should revert
        // register an empty invalid action
        address[] memory hooks = new address[](0);
        vm.prank(SUPER_ACTIONS_CONFIGURATOR);
        vm.expectRevert(ISuperActions.INVALID_HOOKS_LENGTH.selector);
        uint256 actionId = superActions.registerAction(hooks, ACTION_ORACLE_TEMP);
    }

    function test_RevertWhen_HooksAreDefinedByExecutionDataIsNotValid() external givenAnActionExist {
        // it should revert
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = abi.encode(uint256(1));
        hooksData[1] = abi.encode(uint256(1));

        ISuperExecutorV2.ExecutorEntry[] memory entries = new ISuperExecutorV2.ExecutorEntry[](1);
        entries[0] =
            ISuperExecutorV2.ExecutorEntry({ actionId: actionIds[0], finalTarget: RANDOM_TARGET, hooksData: hooksData });

        vm.expectRevert();
        superExecutor.execute(instance.account, abi.encode(entries));
    }

    modifier givenSentinelCallIsNotPerformed() {
        _;
    }

    function test_WhenHooksAreDefinedAndExecutionDataIsValidAndSentinelIsConfigured(uint256 amount)
        external
        givenAnActionExist
        givenSentinelCallIsNotPerformed
    {
        amount = _bound(amount);
        bytes[] memory hooksData = _createStrategy0(amount);

        // assure account has tokens
        _getTokens(address(mockERC20), instance.account, amount);

        // it should execute all hooks
        ISuperExecutorV2.ExecutorEntry[] memory entries = new ISuperExecutorV2.ExecutorEntry[](1);
        entries[0] =
            ISuperExecutorV2.ExecutorEntry({ actionId: actionIds[0], finalTarget: RANDOM_TARGET, hooksData: hooksData });

        vm.expectEmit(true, true, true, true);
        emit SuperPositionSentinel.SuperPositionMint(actionIds[0], RANDOM_TARGET, amount);
        superExecutor.execute(instance.account, abi.encode(entries));

        uint256 accSharesAfter = mock4626Vault.balanceOf(instance.account);
        assertEq(accSharesAfter, amount);
    }

    function test_WhenHooksAreDefinedAndExecutionDataIsValidAndSentinelIsConfigured_Deposit_And_Withdraw_In_The_Same_Strategy(
        uint256 amount
    )
        external
        givenAnActionExist
        givenSentinelCallIsNotPerformed
    {
        amount = _bound(amount);
        bytes[] memory hooksData = _createStrategy2(amount);

        // assure account has tokens
        _getTokens(address(mockERC20), instance.account, amount);

        // it should execute all hooks
        ISuperExecutorV2.ExecutorEntry[] memory entries = new ISuperExecutorV2.ExecutorEntry[](1);
        entries[0] =
            ISuperExecutorV2.ExecutorEntry({ actionId: actionIds[2], finalTarget: RANDOM_TARGET, hooksData: hooksData });

        vm.expectEmit(true, true, true, true);

        emit SuperPositionSentinel.SuperPositionMint(actionIds[2], RANDOM_TARGET, amount - 100);
        superExecutor.execute(instance.account, abi.encode(entries));

        uint256 accSharesAfter = mock4626Vault.balanceOf(instance.account);
        assertEq(accSharesAfter, amount - 100);
    }

    function _createStrategy0(uint256 amount) internal view returns (bytes[] memory hooksData) {
        hooksData = new bytes[](2);
        hooksData[0] = abi.encode(address(mockERC20), address(mock4626Vault), amount);
        hooksData[1] = abi.encode(address(mock4626Vault), instance.account, amount);
    }

    function _createStrategy2(uint256 amount) internal view returns (bytes[] memory hooksData) {
        hooksData = new bytes[](3);
        hooksData[0] = abi.encode(address(mockERC20), address(mock4626Vault), amount);
        hooksData[1] = abi.encode(address(mock4626Vault), instance.account, amount);
        hooksData[2] = abi.encode(address(mock4626Vault), instance.account, instance.account, 100);
    }
}
