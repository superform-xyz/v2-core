// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { UserOpData } from "modulekit/ModuleKit.sol";

// Superform
import { ISuperExecutor } from "src/interfaces/ISuperExecutor.sol";
import { ISuperActions } from "src/interfaces/strategies/ISuperActions.sol";
import { IAcrossV3Interpreter } from "src/interfaces/vendors/bridges/across/IAcrossV3Interpreter.sol";

import { AcrossBridgeGateway } from "src/bridges/AcrossBridgeGateway.sol";
import { AcrossExecuteOnDestinationHook } from "src/hooks/bridges/across/AcrossExecuteOnDestinationHook.sol";

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

        ISuperExecutor.ExecutorEntry[] memory entries = new ISuperExecutor.ExecutorEntry[](1);
        entries[0] = ISuperExecutor.ExecutorEntry({
            actionId: actionId,
            yieldSourceAddress: RANDOM_TARGET,
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

        ISuperExecutor.ExecutorEntry[] memory entries = new ISuperExecutor.ExecutorEntry[](1);
        entries[0] = ISuperExecutor.ExecutorEntry({
            actionId: ACTION["4626_DEPOSIT"],
            yieldSourceAddress: RANDOM_TARGET,
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
        address yieldSourceAddress = address(mock4626Vault);
        bytes[] memory hooksData = _createDepositAndBridgeActionData(yieldSourceAddress, amount);

        // assure account has tokens
        _getTokens(address(mockERC20), instance.account, amount);

        // it should execute all hooks
        ISuperExecutor.ExecutorEntry[] memory entries = new ISuperExecutor.ExecutorEntry[](1);
        entries[0] = ISuperExecutor.ExecutorEntry({
            actionId: ACTION["4626_DEPOSIT_ACROSS"],
            yieldSourceAddress: yieldSourceAddress,
            hooksData: hooksData,
            nonMainActionHooks: new address[](0)
        });

        // check bridge emitted event; assume Orchestrator picks it up
        ISuperExecutor.ExecutorEntry[] memory subEntries = new ISuperExecutor.ExecutorEntry[](1);
        subEntries[0] = ISuperExecutor.ExecutorEntry({
            actionId: ACTION["4626_WITHDRAW"],
            yieldSourceAddress: yieldSourceAddress,
            hooksData: _createWithdrawActionData(yieldSourceAddress),
            nonMainActionHooks: new address[](0)
        });

        UserOpData memory userOpData = _getExecOps(abi.encode(entries));
        vm.expectEmit(true, true, true, true);
        emit AcrossBridgeGateway.InstructionProcessed(instance.account, abi.encode(subEntries));
        executeOp(userOpData);

        //  simulate Orchestrator call for the remaning data
        superExecutor.executeFromGateway(instance.account, abi.encode(subEntries));
    }

    function _createWithdrawActionData(address yieldSourceAddress)
        internal
        view
        returns (bytes[] memory hooksData)
    {
        hooksData = new bytes[](1);
        hooksData[0] = abi.encodePacked(yieldSourceAddress, user2, instance.account, DEFAULT_AMOUNT, false);
    }

    function _createDepositAndBridgeActionData(
        address yieldSourceAddress,
        uint256 amount
    )
        internal
        view
        returns (bytes[] memory hooksData)
    {
        hooksData = new bytes[](4);
        hooksData[0] = abi.encodePacked(address(mockERC20), yieldSourceAddress, amount, false);
        hooksData[1] = abi.encodePacked(yieldSourceAddress, instance.account, amount, false);
        hooksData[2] = abi.encodePacked(yieldSourceAddress, address(spokePoolV3Mock), amount, false);

        ISuperExecutor.ExecutorEntry[] memory entries = new ISuperExecutor.ExecutorEntry[](1);
        entries[0] = ISuperExecutor.ExecutorEntry({
            actionId: ACTION["4626_WITHDRAW"],
            yieldSourceAddress: yieldSourceAddress,
            hooksData: _createWithdrawActionData(yieldSourceAddress),
            nonMainActionHooks: new address[](0)

        });

        AcrossExecuteOnDestinationHook.AcrossV3DepositData memory acrossV3DepositData = AcrossExecuteOnDestinationHook
            .AcrossV3DepositData({
            value: SMALL,
            recipient: instance.account,
            inputToken: yieldSourceAddress,
            outputToken: yieldSourceAddress,
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
