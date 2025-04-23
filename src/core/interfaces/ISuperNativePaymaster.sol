// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { PackedUserOperation } from "@ERC4337/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
/// @title ISuperNativePaymaster
/// @author Superform Labs
/// @notice Interface for SuperNativePaymaster contract

interface ISuperNativePaymaster {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZERO_ADDRESS();
    error EMPTY_MESSAGE_VALUE();
    error INSUFFICIENT_BALANCE();
    error INVALID_MAX_GAS_LIMIT();
    error INVALID_NODE_OPERATOR_PREMIUM();

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Handle a batch of user operations.
    /// @param ops The user operations to handle.
    function handleOps(PackedUserOperation[] calldata ops) external payable;

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
        external
        pure
        returns (uint256 refund);
}
