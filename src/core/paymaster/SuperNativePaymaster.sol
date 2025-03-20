// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BasePaymaster } from "@account-abstraction/core/BasePaymaster.sol";
import { IEntryPoint } from "@account-abstraction/interfaces/IEntryPoint.sol";
import { UserOperationLib } from "@account-abstraction/core/UserOperationLib.sol";
import { PackedUserOperation } from "@account-abstraction/interfaces/PackedUserOperation.sol";
import { IEntryPointSimulations } from "@account-abstraction/interfaces/IEntryPointSimulations.sol";

/// @title SuperNativePaymaster
/// @author Superform Labs
/// @notice A paymaster contract that allows users to pay for their operations with native tokens.
/// @dev Inspired by https://github.com/0xPolycode/klaster-smart-contracts/blob/master/contracts/KlasterPaymasterV7.sol
contract SuperNativePaymaster is BasePaymaster {
    using UserOperationLib for PackedUserOperation;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error EMPTY_MESSAGE_VALUE();
    error INSUFFICIENT_BALANCE();

    constructor(IEntryPoint _entryPoint) payable BasePaymaster(_entryPoint) { }
    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Calculate the refund amount based on the max gas limit, max fee per gas, actual gas cost, and node
    /// operator premium.
    /// @param maxGasLimit The maximum gas limit for the operation.
    /// @param maxFeePerGas The maximum fee per gas for the operation.
    /// @param actualGasCost The actual gas cost for the operation.
    /// @param nodeOperatorPremium The node operator premium for the operation.

    function calculateRefund(
        uint256 maxGasLimit,
        uint256 maxFeePerGas,
        uint256 actualGasCost,
        uint256 nodeOperatorPremium
    )
        public
        pure
        returns (uint256 refund)
    {
        uint256 costWithPremium = (actualGasCost * (100 + nodeOperatorPremium)) / 100;

        uint256 maxCost = maxGasLimit * maxFeePerGas;
        if (costWithPremium < maxCost) {
            refund = maxCost - costWithPremium;
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Handle a batch of user operations.
    /// @param ops The user operations to handle.
    function handleOps(PackedUserOperation[] calldata ops) public payable {
        if (msg.value == 0) {
            revert EMPTY_MESSAGE_VALUE();
        }
        entryPoint.depositTo{ value: address(this).balance }(address(this));
        entryPoint.handleOps(ops, payable(msg.sender));
        entryPoint.withdrawTo(payable(msg.sender), entryPoint.getDepositInfo(address(this)).deposit);
    }

    /// @notice Simulate the handling of a user operation.
    /// @param op The user operation to simulate.
    /// @param target The target address of the user operation.
    /// @param callData The call data for the user operation.
    function simulateHandleOp(
        PackedUserOperation calldata op,
        address target,
        bytes calldata callData
    )
        external
        payable
        returns (IEntryPointSimulations.ExecutionResult memory)
    {
        if (msg.value == 0) {
            revert EMPTY_MESSAGE_VALUE();
        }
        IEntryPointSimulations entryPointWithSimulations = _getEntryPointWithSimulations();
        entryPointWithSimulations.depositTo{ value: address(this).balance }(address(this));
        return entryPointWithSimulations.simulateHandleOp(op, target, callData);
    }

    /// @notice Simulate the validation of a user operation.
    /// @param op The user operation to simulate.
    function simulateValidation(PackedUserOperation calldata op)
        external
        payable
        returns (IEntryPointSimulations.ValidationResult memory)
    {
        if (msg.value == 0) {
            revert EMPTY_MESSAGE_VALUE();
        }
        IEntryPointSimulations entryPointWithSimulations = _getEntryPointWithSimulations();
        entryPointWithSimulations.depositTo{ value: address(this).balance }(address(this));
        return entryPointWithSimulations.simulateValidation(op);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32,
        /**
         * userOpHash
         */
        uint256 maxCost
    )
        internal
        virtual
        override
        returns (bytes memory context, uint256 validationData)
    {
        if (entryPoint.getDepositInfo(address(this)).deposit < maxCost) {
            revert INSUFFICIENT_BALANCE();
        }
        (uint256 maxGasLimit, uint256 nodeOperatorPremium) =
            abi.decode(userOp.paymasterAndData[PAYMASTER_DATA_OFFSET:], (uint256, uint256));

        return (abi.encode(userOp.sender, userOp.unpackMaxFeePerGas(), maxGasLimit, nodeOperatorPremium), 0);
    }

    /// @notice Handle the post-operation logic.
    ///         Executes userOp and gives back refund to the userOp.sender if userOp.sender has overpaid for execution.
    /// @dev Verified to be called only through the entryPoint.
    ///      If subclass returns a non-empty context from validatePaymasterUserOp, it must also implement this method.
    /// @param mode The mode of the post-operation
    ///                  opSucceeded - user operation succeeded.
    ///                  opReverted  - user op reverted. still has to pay for gas.
    ///                  postOpReverted - user op succeeded, but caused postOp (in mode=opSucceeded) to revert.
    ///                                    Now this is the 2nd call, after user's op was deliberately reverted.
    /// @param context The context value returned by validatePaymasterUserOp.
    /// @param actualGasCost The actual gas used so far (without this postOp call).
    function _postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256
    )
        /**
         * actualUserOpFeePerGas
         */
        internal
        virtual
        override
    {
        if (mode == PostOpMode.postOpReverted) {
            return;
        }
        (address sender, uint256 maxFeePerGas, uint256 maxGasLimit, uint256 nodeOperatorPremium) =
            abi.decode(context, (address, uint256, uint256, uint256));

        uint256 refund = calculateRefund(maxGasLimit, maxFeePerGas, actualGasCost, nodeOperatorPremium);
        if (refund > 0) {
            entryPoint.withdrawTo(payable(sender), refund);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getEntryPointWithSimulations() private view returns (IEntryPointSimulations) {
        return IEntryPointSimulations(address(entryPoint));
    }
}
