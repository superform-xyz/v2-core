// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { ISuperExecutorV2 } from "src/interfaces/ISuperExecutorV2.sol";
import { Unit_Shared } from "test/unit/Unit_Shared.t.sol";

contract SuperExecutor_sameChainFlow is Unit_Shared {
    function test_GivenAStrategyDoesNotExist(uint256 amount) external {
        amount = _bound(amount);
        // it should retrieve an empty array of hooks
        // it should revert wityh DATA_NOT_VALID

        address strategyId = address(uint160(uint256(keccak256(abi.encodePacked(block.timestamp, address(this))))));
        bytes[] memory hooksData = new bytes[](0);

        ISuperExecutorV2.ExecutorEntry[] memory entries = new ISuperExecutorV2.ExecutorEntry[](1);
        entries[0] = ISuperExecutorV2.ExecutorEntry({
            strategyId: strategyId,
            hooksData: hooksData
        });

        vm.expectRevert(ISuperExecutorV2.DATA_NOT_VALID.selector);
        superExecutor.execute(instance.account, abi.encode(entries));
    }

    modifier givenAStrategyExist() {
        _;
    }

    function test_RevertWhen_NoHooksAreDefined() external givenAStrategyExist {
        // it should revert
        // register an empty invalid strategy
        address[] memory hooks = new address[](0);
        address stratId = strategiesRegistry.registerStrategy(hooks);

        bytes[] memory hooksData = new bytes[](0);
        ISuperExecutorV2.ExecutorEntry[] memory entries = new ISuperExecutorV2.ExecutorEntry[](1);
        entries[0] = ISuperExecutorV2.ExecutorEntry({
            strategyId: stratId,
            hooksData: hooksData
        });

        vm.expectRevert(ISuperExecutorV2.DATA_NOT_VALID.selector);
        superExecutor.execute(instance.account, abi.encode(entries));
    }

    function test_RevertWhen_HooksAreDefinedByExecutionDataIsNotValid() external givenAStrategyExist {
        // it should revert
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = abi.encode(uint256(1));
        hooksData[1] = abi.encode(uint256(1));

        ISuperExecutorV2.ExecutorEntry[] memory entries = new ISuperExecutorV2.ExecutorEntry[](1);
        entries[0] = ISuperExecutorV2.ExecutorEntry({
            strategyId: stratIds[0],
            hooksData: hooksData
        });

        vm.expectRevert();
        superExecutor.execute(instance.account, abi.encode(entries));
    }

    modifier givenSentinelCallIsNotPerformed() {
        _;
    }

    function test_WhenHooksAreDefinedAndExecutionDataIsValidAndSentinelIsConfigured(uint256 amount)
        external
        givenAStrategyExist
        givenSentinelCallIsNotPerformed
    {
        amount = _bound(amount);
        bytes[] memory hooksData = _createStrategy0(amount);
        
        // assure account has tokens
        _getTokens(address(mockERC20), instance.account, amount);

        // it should execute all hooks
        ISuperExecutorV2.ExecutorEntry[] memory entries = new ISuperExecutorV2.ExecutorEntry[](1);
        entries[0] = ISuperExecutorV2.ExecutorEntry({
            strategyId: stratIds[0],
            hooksData: hooksData
        });

        vm.expectEmit(true, true, true, true);
        emit SuperPositionMint(stratIds[0], amount);
        superExecutor.execute(instance.account, abi.encode(entries));

        uint256 accSharesAfter = mock4626Vault.balanceOf(instance.account);
        assertEq(accSharesAfter, amount);
    }

    function test_WhenHooksAreDefinedAndExecutionDataIsValidAndSentinelIsConfigured_Deposit_And_Withdraw_In_The_Same_Strategy(uint256 amount)
        external
        givenAStrategyExist
        givenSentinelCallIsNotPerformed
    {
        amount = _bound(amount);
        bytes[] memory hooksData = _createStrategy2(amount);
        
        // assure account has tokens
        _getTokens(address(mockERC20), instance.account, amount);

        // it should execute all hooks
        ISuperExecutorV2.ExecutorEntry[] memory entries = new ISuperExecutorV2.ExecutorEntry[](1);
        entries[0] = ISuperExecutorV2.ExecutorEntry({
            strategyId: stratIds[2],
            hooksData: hooksData
        });

        vm.expectEmit(true, true, true, true);
        emit SuperPositionMint(stratIds[2], amount-100);
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
