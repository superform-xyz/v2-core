// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { PackedUserOperation } from "@account-abstraction/interfaces/PackedUserOperation.sol";
import { UserOperationLib } from "@account-abstraction/core/UserOperationLib.sol";

/// @title PaymasterGasCalculator
/// @author Superform Labs
/// @notice Library for calculating paymaster gas costs for user operations
library PaymasterGasCalculator {
    uint256 internal constant UINT128_BYTES = 16;


    /// @dev Offset in paymasterAndData where custom data begins
    uint256 internal constant PAYMASTER_MAX_GAS_LIMIT_OFFSET = 20;
    uint256 internal constant PAYMASTER_DATA_OFFSET = UserOperationLib.PAYMASTER_DATA_OFFSET;
    uint256 internal constant PAYMASTER_VALIDATION_GAS_OFFSET = UserOperationLib.PAYMASTER_VALIDATION_GAS_OFFSET;
    uint256 internal constant PAYMASTER_POSTOP_GAS_OFFSET = UserOperationLib.PAYMASTER_POSTOP_GAS_OFFSET;

    /// @notice Calculates the total gas cost of a user operation in wei
    /// @param userOp The user operation to calculate gas for
    /// @return totalCostInWei The total gas cost in wei
    function calculateGasCostInWei(PackedUserOperation memory userOp) internal pure returns (uint256 totalCostInWei) {
        uint256 totalGasConsumption = calculateTotalGasConsumption(userOp);
        uint256 maxFeePerGas = getMaxFeePerGas(userOp);
        uint256 maxPriorityFeePerGas = getMaxPriorityFeePerGas(userOp);

        return totalGasConsumption * (maxFeePerGas + maxPriorityFeePerGas);
    }

    /// @notice Calculates the total gas consumption of a user operation
    /// @param userOp The user operation to calculate gas for
    /// @return totalGas The total gas consumption
    function calculateTotalGasConsumption(PackedUserOperation memory userOp) internal pure returns (uint256 totalGas) {
        // 1. Get preverificationGas directly from userOp
        uint256 preverificationGas = userOp.preVerificationGas;

        // 2. Extract accountCreationGas and callDataGas from accountGasLimits
        uint256 accountCreationGas = getVerificationGasLimit(userOp);
        uint256 callDataGas = getCallGasLimit(userOp);

        // 3. Extract validationGas and postOpGas from paymasterAndData if it exists
        uint256 validationGas = 0;
        uint256 postOpGas = 0;

        if (userOp.paymasterAndData.length >= PAYMASTER_DATA_OFFSET) {
            // Extract paymaster data using memory versions of the functions
            validationGas = getPaymasterVerificationGasLimit(userOp);
            postOpGas = getPostOpGasLimit(userOp);
        }

        // 4. Sum all gas components
        return preverificationGas + accountCreationGas + callDataGas + validationGas + postOpGas;
    }

    /// @notice Gets the max fee per gas from a user operation
    /// @param userOp The user operation
    /// @return The max fee per gas
    function getMaxFeePerGas(PackedUserOperation memory userOp) internal pure returns (uint256) {
        return unpackLow128(userOp.gasFees);
    }

    /// @notice Gets the max priority fee per gas from a user operation
    /// @param userOp The user operation
    /// @return The max priority fee per gas
    function getMaxPriorityFeePerGas(PackedUserOperation memory userOp) internal pure returns (uint256) {
        return unpackHigh128(userOp.gasFees);
    }

    /// @notice Gets the verification gas limit
    /// @param userOp The user operation
    /// @return The verification gas limit
    function getVerificationGasLimit(PackedUserOperation memory userOp) internal pure returns (uint256) {
        return unpackHigh128(userOp.accountGasLimits);
    }

    /// @notice Gets the call gas limit
    /// @param userOp The user operation
    /// @return The call gas limit
    function getCallGasLimit(PackedUserOperation memory userOp) internal pure returns (uint256) {
        return unpackLow128(userOp.accountGasLimits);
    }

    /// @notice Gets the paymaster verification gas limit
    /// @param userOp The user operation
    /// @return The paymaster verification gas limit
    function getPaymasterVerificationGasLimit(PackedUserOperation memory userOp) internal pure returns (uint256) {
        if (userOp.paymasterAndData.length < PAYMASTER_POSTOP_GAS_OFFSET) return 0;

        // Since we can't slice memory arrays directly, we need to copy the relevant bytes
        bytes memory validationGasBytes = new bytes(16);
        for (uint256 i; i < 16; i++) {
            if (PAYMASTER_VALIDATION_GAS_OFFSET + i < userOp.paymasterAndData.length) {
                validationGasBytes[i] = userOp.paymasterAndData[PAYMASTER_VALIDATION_GAS_OFFSET + i];
            }
        }

        // Convert the copied bytes to uint256
        return uint128(bytes16(validationGasBytes));
    }

    /// @notice Gets the post op gas limit
    /// @param userOp The user operation
    /// @return The post op gas limit
    function getPostOpGasLimit(PackedUserOperation memory userOp) internal pure returns (uint256) {
        if (userOp.paymasterAndData.length < PAYMASTER_DATA_OFFSET) return 0;

        // Since we can't slice memory arrays directly, we need to copy the relevant bytes
        bytes memory postOpGasBytes = new bytes(16);
        for (uint256 i; i < 16; i++) {
            if (PAYMASTER_POSTOP_GAS_OFFSET + i < userOp.paymasterAndData.length) {
                postOpGasBytes[i] = userOp.paymasterAndData[PAYMASTER_POSTOP_GAS_OFFSET + i];
            }
        }

        // Convert the copied bytes to uint256
        return uint128(bytes16(postOpGasBytes));
    }

    /// @notice Unpacks the high 128-bits from a packed value
    /// @param packed The packed value
    /// @return The high 128 bits as a uint256
    function unpackHigh128(bytes32 packed) internal pure returns (uint256) {
        return uint256(packed) >> 128;
    }

    /// @notice Unpacks the low 128-bits from a packed value
    /// @param packed The packed value
    /// @return The low 128 bits as a uint256
    function unpackLow128(bytes32 packed) internal pure returns (uint256) {
        return uint128(uint256(packed));
    }
}
