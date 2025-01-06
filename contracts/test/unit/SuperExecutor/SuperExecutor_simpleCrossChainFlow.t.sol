// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { UserOpData } from "modulekit/ModuleKit.sol";

// Superform
import { ISuperExecutor } from "src/interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "src/interfaces/accounting/ISuperLedger.sol";
import { IAcrossV3Interpreter } from "src/interfaces/vendors/bridges/across/IAcrossV3Interpreter.sol";

import { AcrossBridgeGateway } from "src/bridges/AcrossBridgeGateway.sol";
import { AcrossExecuteOnDestinationHook } from "src/hooks/bridges/across/AcrossExecuteOnDestinationHook.sol";

import { Unit_Shared } from "test/unit/Unit_Shared.t.sol";

contract SuperExecutor_simpleCrossChainFlow is Unit_Shared {
    address RANDOM_TARGET = address(uint160(uint256(keccak256(abi.encodePacked(block.timestamp, address(this))))));
    uint256 constant DEFAULT_AMOUNT = 100;
    address yieldSourceOracle = address(erc4626YieldSourceOracle);

    function test_GivenAStrategyDoesNotExist(uint256 amount) external addRole(superRbac.BRIDGE_GATEWAY()) {
        amount = _bound(amount);
        // it should retrieve an empty array of hooks
        // it should revert ?
        address[] memory hooksAddresses = new address[](0);
        bytes[] memory hooksData = new bytes[](0);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        superExecutor.executeFromGateway(instance.account, abi.encode(entry));
    }

    modifier givenAStrategyExist() {
        _;
    }

    function test_RevertWhen_HooksAreDefinedByExecutionDataIsNotValid()
        external
        givenAStrategyExist
        addRole(superRbac.BRIDGE_GATEWAY())
    {
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = address(approveErc20Hook);
        hooksAddresses[1] = address(deposit4626VaultHook);

        // it should revert
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = abi.encode(uint256(1));
        hooksData[1] = abi.encode(uint256(1));

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        vm.expectRevert();
        superExecutor.executeFromGateway(instance.account, abi.encode(entry));
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
        (
            address[] memory depositHooksAddresses,
            bytes[] memory depositHooksData,
            address[] memory withdrawHooksAddresses,
            bytes[] memory withdrawHooksData
        ) = _createDepositAndBridgeActionData(yieldSourceAddress, amount);

        // assure account has tokens
        _getTokens(address(mockERC20), instance.account, amount);

        // it should execute all hooks
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: depositHooksAddresses, hooksData: depositHooksData });

        // check bridge emitted event; assume Orchestrator picks it up
        ISuperExecutor.ExecutorEntry memory subEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: withdrawHooksAddresses, hooksData: withdrawHooksData });

        UserOpData memory userOpData = _getExecOps(abi.encode(entry));
        vm.expectEmit(true, true, true, true);
        emit AcrossBridgeGateway.InstructionProcessed(instance.account, abi.encode(subEntry));
        executeOp(userOpData);

        //  simulate Orchestrator call for the remaning data
        superExecutor.executeFromGateway(instance.account, abi.encode(subEntry));
    }

    function _createDepositAndBridgeActionData(
        address yieldSourceAddress,
        uint256 amount
    )
        internal
        view
        returns (
            address[] memory depositHooksAddresses,
            bytes[] memory depositHooksData,
            address[] memory withdrawHooksAddresses,
            bytes[] memory withdrawHooksData
        )
    {
        withdrawHooksAddresses = new address[](2);
        withdrawHooksAddresses[0] = address(withdraw4626VaultHook);
        withdrawHooksAddresses[1] = address(superLedgerHook);

        withdrawHooksData = new bytes[](2);
        withdrawHooksData[0] = _createWithdrawHookData(instance.account, yieldSourceAddress, amount);
        withdrawHooksData[1] = _createSuperAccountingHookData(instance.account, yieldSourceOracle, yieldSourceAddress);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: withdrawHooksAddresses, hooksData: withdrawHooksData });

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
                strategyData: abi.encode(entry)
            })
        });

        depositHooksAddresses = new address[](4);
        depositHooksAddresses[0] = address(approveErc20Hook);
        depositHooksAddresses[1] = address(deposit4626VaultHook);
        depositHooksAddresses[2] = address(approveErc20Hook);
        depositHooksAddresses[3] = address(acrossExecuteOnDestinationHook);

        depositHooksData = new bytes[](4);
        depositHooksData[0] = abi.encodePacked(address(mockERC20), yieldSourceAddress, amount, false);
        depositHooksData[1] = abi.encodePacked(yieldSourceAddress, instance.account, amount, false);
        depositHooksData[2] = abi.encodePacked(yieldSourceAddress, address(spokePoolV3Mock), amount, false);
        depositHooksData[3] = abi.encode(acrossV3DepositData);
    }
}
