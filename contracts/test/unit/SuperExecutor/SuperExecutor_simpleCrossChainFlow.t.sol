// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { ISuperExecutorV2 } from "src/interfaces/ISuperExecutorV2.sol";
import { IAcrossV3Interpreter } from "src/interfaces/vendors/bridges/across/IAcrossV3Interpreter.sol";

import { AcrossExecuteOnDestinationHook } from "src/hooks/bridges/across/AcrossExecuteOnDestinationHook.sol";
import { Unit_Shared } from "test/unit/Unit_Shared.t.sol";

contract SuperExecutor_simpleCrossChainFlow is Unit_Shared {
    function test_GivenAStrategyDoesNotExist(uint256 amount) external addRole(superRbac.BRIDGE_GATEWAY()) {
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
        superExecutor.executeFromGateway(instance.account, abi.encode(entries));
    }

    modifier givenAStrategyExist() {
        _;
    }

    function test_RevertWhen_NoHooksAreDefined() external givenAStrategyExist addRole(superRbac.BRIDGE_GATEWAY()) {
        address[] memory hooks = new address[](0);
        address stratId = strategiesRegistry.registerStrategy(hooks);

        bytes[] memory hooksData = new bytes[](0);
        ISuperExecutorV2.ExecutorEntry[] memory entries = new ISuperExecutorV2.ExecutorEntry[](1);
        entries[0] = ISuperExecutorV2.ExecutorEntry({
            strategyId: stratId,
            hooksData: hooksData
        });

        vm.expectRevert(ISuperExecutorV2.DATA_NOT_VALID.selector);
        superExecutor.executeFromGateway(instance.account, abi.encode(entries));
    }

    function test_RevertWhen_HooksAreDefinedByExecutionDataIsNotValid() external givenAStrategyExist addRole(superRbac.BRIDGE_GATEWAY()) {
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
        superExecutor.executeFromGateway(instance.account, abi.encode(entries));
    }

    
}
