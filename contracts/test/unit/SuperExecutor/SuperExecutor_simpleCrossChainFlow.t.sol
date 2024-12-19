// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { ISuperExecutorV2 } from "src/interfaces/ISuperExecutorV2.sol";
import { ISuperActions } from "src/interfaces/strategies/ISuperActions.sol";
import { IAcrossV3Interpreter } from "src/interfaces/vendors/bridges/across/IAcrossV3Interpreter.sol";

import { AcrossBridgeGateway } from "src/bridges/AcrossBridgeGateway.sol";
import { AcrossExecuteOnDestinationHook } from "src/hooks/bridges/across/AcrossExecuteOnDestinationHook.sol";
import { SuperPositionSentinel } from "src/sentinels/SuperPositionSentinel.sol";

import { Unit_Shared } from "test/unit/Unit_Shared.t.sol";

contract SuperExecutor_simpleCrossChainFlow is Unit_Shared {
    address RANDOM_TARGET = address(uint160(uint256(keccak256(abi.encodePacked(block.timestamp, address(this))))));
    uint256 constant DEFAULT_AMOUNT = 100;

    function test_GivenAStrategyDoesNotExist(uint256 amount) external addRole(superRbac.BRIDGE_GATEWAY()) {
        amount = _bound(amount);
        // it should retrieve an empty array of hooks
        // it should revert with DATA_NOT_VALID
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
        superExecutor.executeFromGateway(instance.account, abi.encode(entries));
    }

    modifier givenAStrategyExist() {
        _;
    }

    function test_RevertWhen_HooksAreDefinedByExecutionDataIsNotValid()
        external
        givenAStrategyExist
        addRole(superRbac.BRIDGE_GATEWAY())
    {
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

        vm.expectRevert();
        superExecutor.executeFromGateway(instance.account, abi.encode(entries));
    }

    modifier givenStrategyHasACrossHookAndNoSameChainHooks() {
        _;
    }

    function test_WhenHooksAreDefinedAndExecutionDataIsValidAndSentinelIsConfigured(uint256 amount)
        external
        givenAStrategyExist
        givenStrategyHasACrossHookAndNoSameChainHooks
        addRole(superRbac.BRIDGE_GATEWAY())
    {
        amount = _bound(amount);
        address finalTarget = address(mock4626Vault);
        bytes[] memory hooksData = _createDepositAndBridgeActionData(finalTarget, amount);

        // assure account has tokens
        _getTokens(address(mockERC20), instance.account, amount);

        // it should execute all hooks
        ISuperExecutorV2.ExecutorEntry[] memory entries = new ISuperExecutorV2.ExecutorEntry[](1);
        entries[0] = ISuperExecutorV2.ExecutorEntry({
            actionId: ACTION["4626_DEPOSIT_ACROSS"],
            finalTarget: finalTarget,
            hooksData: hooksData,
            nonMainActionHooks: new address[](0)
        });

        // check bridge emitted event; assume Orchestrator picks it up
        ISuperExecutorV2.ExecutorEntry[] memory subEntries = new ISuperExecutorV2.ExecutorEntry[](1);
        subEntries[0] = ISuperExecutorV2.ExecutorEntry({
            actionId: ACTION["4626_WITHDRAW"],
            finalTarget: finalTarget,
            hooksData: _createWithdrawActionData(finalTarget, amount),
            nonMainActionHooks: new address[](0)
        });
        vm.expectEmit(true, true, true, true);
        emit AcrossBridgeGateway.InstructionProcessed(instance.account, abi.encode(subEntries));
        superExecutor.execute(instance.account, abi.encode(entries));

        //  simulate Orchestrator call for the remaning data
        superExecutor.executeFromGateway(instance.account, abi.encode(subEntries));
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
        hooksData[0] = abi.encode(finalTarget, user2, instance.account, DEFAULT_AMOUNT);
    }

    function _createDepositAndBridgeActionData(
        address finalTarget,
        uint256 amount
    )
        internal
        view
        returns (bytes[] memory hooksData)
    {
        hooksData = new bytes[](4);
        hooksData[0] = abi.encode(address(mockERC20), finalTarget, amount);
        hooksData[1] = abi.encode(finalTarget, instance.account, amount);
        hooksData[2] = abi.encode(finalTarget, address(spokePoolV3Mock), amount);

        ISuperExecutorV2.ExecutorEntry[] memory entries = new ISuperExecutorV2.ExecutorEntry[](1);
        entries[0] = ISuperExecutorV2.ExecutorEntry({
            actionId: ACTION["4626_WITHDRAW"],
            finalTarget: finalTarget,
            hooksData: _createWithdrawActionData(finalTarget, amount),
            nonMainActionHooks: new address[](0)
        });

        AcrossExecuteOnDestinationHook.AcrossV3DepositData memory acrossV3DepositData = AcrossExecuteOnDestinationHook
            .AcrossV3DepositData({
            value: SMALL,
            recipient: instance.account,
            inputToken: finalTarget,
            outputToken: finalTarget,
            inputAmount: amount,
            outputAmount: amount,
            destinationChainId: 1,
            exclusiveRelayer: address(0),
            fillDeadline: 0,
            exclusivityDeadline: 0,
            instruction: IAcrossV3Interpreter.Instruction({
                account: instance.account,
                amount: amount,
                strategyData: abi.encode(entries)
            })
        });
        hooksData[3] = abi.encode(acrossV3DepositData);
    }
}
