// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { PackedUserOperation } from "@ERC4337/account-abstraction/contracts/interfaces/PackedUserOperation.sol";

/// @title ISuperNativePaymaster
/// @author Superform Labs
/// @notice Interface for a paymaster that enables users to pay for ERC-4337 operations with native tokens
/// @dev Implements handling of operations and provides refund calculations for unused gas

interface ISuperNativePaymaster {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when a critical address parameter is set to the zero address
    /// @dev Used in constructor when validating EntryPoint address
    error ZERO_ADDRESS();
    
    /// @notice Thrown when an operation requires value but none was provided
    /// @dev Used when checking for sufficient balance for operations
    error EMPTY_MESSAGE_VALUE();
    
    /// @notice Thrown when there isn't enough balance to cover an operation
    /// @dev Used during handleOps to ensure sufficient funds to execute operations
    error INSUFFICIENT_BALANCE();
    
    /// @notice Thrown when an invalid gas limit is specified
    /// @dev Used to prevent gas limit abuse or errors
    error INVALID_MAX_GAS_LIMIT();
    
    /// @notice Thrown when a node operator premium exceeds the maximum allowed
    /// @dev Node operator premium is capped at 10,000 basis points (100%)
    error INVALID_NODE_OPERATOR_PREMIUM();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted after a post-operation is completed by the paymaster
    /// @dev Includes the context data from the operation for tracking
    /// @param context The encoded context data from the operation
    event SuperNativePaymasterPostOp(bytes context);
    
    /// @notice Emitted when a refund is sent to an account
    /// @dev Refunds are provided when users overpay for gas costs
    /// @param sender The address receiving the refund
    /// @param refund The amount of native tokens refunded
    event SuperNativePaymsterRefund(address indexed sender, uint256 refund);

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Handle a batch of user operations
    /// @dev Forwards the operations to the EntryPoint contract with funding
    ///      Sends the paymaster's balance to the EntryPoint to cover operation costs
    ///      Called by a bundler or gateway contract to process operations
    /// @param ops Array of packed user operations to execute
    function handleOps(PackedUserOperation[] calldata ops) external payable;
    
    /// @notice Calculate the refund amount based on gas parameters
    /// @dev Takes into account node operator premium when calculating refunds
    ///      Returns zero if the actual cost (with premium) exceeds the maximum cost
    /// @param maxGasLimit The maximum gas limit specified for the operation
    /// @param maxFeePerGas The maximum fee per gas specified for the operation
    /// @param actualGasCost The actual gas cost of the operation
    /// @param nodeOperatorPremium The premium percentage for the node operator (in basis points)
    /// @return refund The amount of native tokens to refund

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Calculate the refund amount based on gas parameters
    /// @dev Takes into account node operator premium when calculating refunds
    ///      Returns zero if the actual cost (with premium) exceeds the maximum cost
    /// @param maxGasLimit The maximum gas limit specified for the operation
    /// @param maxFeePerGas The maximum fee per gas specified for the operation
    /// @param actualGasCost The actual gas cost of the operation
    /// @param nodeOperatorPremium The premium percentage for the node operator (in basis points)
    /// @return refund The amount of native tokens to refund
    function calculateRefund(
        uint256 maxGasLimit,
        uint256 maxFeePerGas,
        uint256 actualGasCost,
        uint256 nodeOperatorPremium
    )
        external
        pure
        returns (uint256 refund);
}
