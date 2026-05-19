// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { PackedUserOperation } from "@ERC4337/account-abstraction/contracts/interfaces/PackedUserOperation.sol";

/// @title ISuperNativePaymaster
/// @author Superform Labs
/// @notice Interface for a paymaster that enables users to pay for ERC-4337 operations with native tokens
/// @dev Implements handling of operations and provides refund calculations for unused gas

interface ISuperNativePaymaster {
    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit info for native fee sponsorship per account
    /// @param account The smart account to deposit for
    /// @param amount The amount of native ETH to deposit
    struct NativeFeeDeposit {
        address account;
        uint256 amount;
    }

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

    /// @notice Thrown when the total native amount exceeds msg.value
    error NATIVE_AMOUNT_EXCEEDS_VALUE();

    /// @notice Thrown when the sponsorship contract address is zero
    error INVALID_SPONSORSHIP();

    /// @notice Thrown when the deposits array exceeds the maximum allowed length
    error TOO_MANY_DEPOSITS();

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
    /// @param refundAmount The amount of native tokens refunded
    /// @param initialRefund The initial refund amount before deposit check
    event SuperNativePaymasterRefund(address indexed sender, uint256 refundAmount, uint256 initialRefund);

    /// @notice Emitted when a batch of user operations is handled
    /// @param sender The address that handled the operations
    /// @param numOps The number of operations handled
    /// @param initialAmount The initial amount of native tokens
    /// @param withdrawnAmount The amount of native tokens withdrawn
    event UserOperationsHandled(address indexed sender, uint256 numOps, uint256 initialAmount, uint256 withdrawnAmount);

    /// @notice Emitted when native fee sponsorship and UserOp handling completes
    /// @param sponsor The bundler/sponsor address
    /// @param totalNativeAmount The total native ETH deposited for messaging fees
    /// @param opsCount The number of operations handled
    event SponsorNativeAndHandleOps(address indexed sponsor, uint256 totalNativeAmount, uint256 opsCount);

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Handle a batch of user operations
    /// @dev Forwards the operations to the EntryPoint contract with funding
    ///      Sends the paymaster's balance to the EntryPoint to cover operation costs
    ///      Called by a bundler or gateway contract to process operations
    /// @param ops Array of packed user operations to execute
    function handleOps(PackedUserOperation[] calldata ops) external payable;

    /// @notice Deposit native ETH for messaging fees and execute UserOps atomically
    /// @dev Splits msg.value into native deposits (for sponsorship) and remainder (for gas).
    ///      The deposits array is independent of ops — one entry per unique account needing sponsorship.
    ///      The paymaster deposits as itself (paymaster = sponsor in NativeFeeSponsorship).
    ///      WARNING: If deposits and UserOp execution happen in separate transactions (non-atomic path),
    ///      a race condition exists where the sponsor can reclaim before the account withdraws.
    ///      Always prefer this atomic function over direct depositForAccount calls.
    /// @param ops Array of packed user operations to execute
    /// @param deposits Array of native fee deposits, one per unique account needing sponsorship (max 50)
    /// @param sponsorship The NativeFeeSponsorship contract address to deposit into
    function sponsorNativeAndHandleOps(
        PackedUserOperation[] calldata ops,
        NativeFeeDeposit[] calldata deposits,
        address sponsorship
    )
        external
        payable;

    /// @notice Reclaim unused sponsored native ETH from a NativeFeeSponsorship contract
    /// @dev Only callable by the contract owner. The paymaster is the sponsor of record in
    ///      NativeFeeSponsorship, so only it can reclaim via withdrawSponsorDeposit.
    /// @param sponsorship The NativeFeeSponsorship contract to reclaim from
    /// @param account The account whose sponsorship allocation to reclaim
    /// @param to The address to send reclaimed ETH to
    /// @param amount The amount to reclaim
    function reclaimSponsorship(
        address sponsorship,
        address account,
        address payable to,
        uint256 amount
    )
        external;

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
