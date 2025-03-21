// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { PackedUserOperation } from "@account-abstraction/interfaces/PackedUserOperation.sol";
import { UserOperationLib } from "@account-abstraction/core/UserOperationLib.sol";

/// @title PaymasterGasCalculator
/// @author Superform Labs
/// @notice Library for calculating paymaster gas costs for user operations
library PaymasterGasCalculator {
    /// @dev Offset in paymasterAndData where custom data begins
    uint256 internal constant PAYMASTER_DATA_OFFSET = UserOperationLib.PAYMASTER_DATA_OFFSET;
    uint256 internal constant PAYMASTER_VALIDATION_GAS_OFFSET = UserOperationLib.PAYMASTER_VALIDATION_GAS_OFFSET;
    uint256 internal constant PAYMASTER_POSTOP_GAS_OFFSET = UserOperationLib.PAYMASTER_POSTOP_GAS_OFFSET;

    /// @notice Calculates the total gas cost of a user operation in wei
    /// @param userOp The user operation to calculate gas for
    /// @return totalCostInWei The total gas cost in wei
    function calculateGasCostInWei(PackedUserOperation calldata userOp)
        internal
        pure
        returns (uint256 totalCostInWei)
    {
        uint256 totalGasConsumption = calculateTotalGasConsumption(userOp);
        uint256 maxFeePerGas = UserOperationLib.unpackMaxFeePerGas(userOp);
        uint256 maxPriorityFeePerGas = UserOperationLib.unpackMaxPriorityFeePerGas(userOp);

        return totalGasConsumption * (maxFeePerGas + maxPriorityFeePerGas);
    }

    /// @notice Calculates the total gas consumption of a user operation
    /// @param userOp The user operation to calculate gas for
    /// @return totalGas The total gas consumption
    function calculateTotalGasConsumption(PackedUserOperation calldata userOp)
        internal
        pure
        returns (uint256 totalGas)
    {
        // 1. Get preverificationGas directly from userOp
        uint256 preverificationGas = userOp.preVerificationGas;

        // 2. Extract accountCreationGas and callDataGas from accountGasLimits
        uint256 accountCreationGas = UserOperationLib.unpackVerificationGasLimit(userOp);
        uint256 callDataGas = UserOperationLib.unpackCallGasLimit(userOp);

        // 3. Extract validationGas and postOpGas from paymasterAndData if it exists
        uint256 validationGas = 0;
        uint256 postOpGas = 0;

        if (userOp.paymasterAndData.length >= PAYMASTER_DATA_OFFSET) {
            validationGas = UserOperationLib.unpackPaymasterVerificationGasLimit(userOp);
            postOpGas = UserOperationLib.unpackPostOpGasLimit(userOp);
        }

        // 4. Sum all gas components
        return preverificationGas + accountCreationGas + callDataGas + validationGas + postOpGas;
    }

    /// @notice Gets the max fee per gas from a user operation
    /// @param userOp The user operation
    /// @return The max fee per gas
    function getMaxFeePerGas(PackedUserOperation calldata userOp) internal pure returns (uint256) {
        return UserOperationLib.unpackMaxFeePerGas(userOp);
    }

    /// @notice Gets the max priority fee per gas from a user operation
    /// @param userOp The user operation
    /// @return The max priority fee per gas
    function getMaxPriorityFeePerGas(PackedUserOperation calldata userOp) internal pure returns (uint256) {
        return UserOperationLib.unpackMaxPriorityFeePerGas(userOp);
    }
}
