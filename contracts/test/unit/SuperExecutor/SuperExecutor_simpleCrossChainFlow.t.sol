// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { ISuperExecutorV2 } from "src/interfaces/ISuperExecutorV2.sol";
import { ISuperActions } from "src/interfaces/strategies/ISuperActions.sol";
import { IAcrossV3Interpreter } from "src/interfaces/vendors/bridges/across/IAcrossV3Interpreter.sol";

import { AcrossExecuteOnDestinationHook } from "src/hooks/bridges/across/AcrossExecuteOnDestinationHook.sol";
import { Unit_Shared } from "test/unit/Unit_Shared.t.sol";

contract SuperExecutor_simpleCrossChainFlow is Unit_Shared {
    address RANDOM_TARGET = address(uint160(uint256(keccak256(abi.encodePacked(block.timestamp, address(this))))));

    function test_GivenAStrategyDoesNotExist(uint256 amount) external addRole(superRbac.BRIDGE_GATEWAY()) {
        amount = _bound(amount);
        // it should retrieve an empty array of hooks
        // it should revert wityh DATA_NOT_VALID
        uint256 actionId = uint256(uint256(keccak256(abi.encodePacked(block.timestamp, address(this)))));
        bytes[] memory hooksData = new bytes[](0);

        ISuperExecutorV2.ExecutorEntry[] memory entries = new ISuperExecutorV2.ExecutorEntry[](1);
        entries[0] = ISuperExecutorV2.ExecutorEntry({
            actionId: actionId,
            finalTarget: RANDOM_TARGET, 
            hooksData: hooksData
        });

        vm.expectRevert(ISuperActions.ACTION_NOT_FOUND.selector);
        superExecutor.executeFromGateway(instance.account, abi.encode(entries));
    }

    modifier givenAStrategyExist() {
        _;
    }


    function test_RevertWhen_HooksAreDefinedByExecutionDataIsNotValid() external givenAStrategyExist addRole(superRbac.BRIDGE_GATEWAY()) {
        // it should revert
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = abi.encode(uint256(1));
        hooksData[1] = abi.encode(uint256(1));

        ISuperExecutorV2.ExecutorEntry[] memory entries = new ISuperExecutorV2.ExecutorEntry[](1);
        entries[0] =
            ISuperExecutorV2.ExecutorEntry({ actionId: actionIds[0], finalTarget: RANDOM_TARGET, hooksData: hooksData });

        vm.expectRevert();
        superExecutor.executeFromGateway(instance.account, abi.encode(entries));
    }
}
