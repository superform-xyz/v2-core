// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External Dependencies
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Superform Interfaces
import { ISuperDestinationExecutor } from "../interfaces/ISuperDestinationExecutor.sol";
import { IMessageTransmitterV2 } from "../vendor/bridges/cctp/IMessageTransmitterV2.sol";

/// @title CCTPAdapter
/// @author Superform Labs
/// @notice Destination-side adapter that completes a Superform CCTP V2 cross-chain intent.
/// @notice The source `CCTPSendHook` burns USDC via `TokenMessengerV2.depositForBurnWithHook`, setting
/// @notice `mintRecipient = destinationCaller = this adapter` and packing the executor payload into
/// @notice `hookData = abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts, signature)`.
/// @dev Structural difference from every other Superform adapter: CCTP has NO push callback.
///      `MessageTransmitterV2.receiveMessage` only mints USDC to `mintRecipient`; it never forwards
///      `hookData`. So this adapter is PULL-driven — a relayer calls `receiveAndExecute(message,
///      attestation)`, the adapter calls `receiveMessage` itself, then acts on the payload it slices
///      from the attested message.
/// @dev PERMISSIONLESS: anyone can call `receiveAndExecute`. Safety is anchored by:
///      1. Circle's attestation authenticating the entire message (incl. `account` and `hookData`), so
///         a front-running caller cannot substitute the recipient.
///      2. `destinationCaller = adapter` (enforced by MessageTransmitterV2) making the adapter the only
///         party that can trigger the mint — mint + execution stay atomic in one tx.
///      3. The executor's own EIP-1271 signature + Merkle-root replay checks for the hook execution leg.
/// @dev Donation-proof: the adapter forwards only the measured `receiveMessage` balance delta
///      (`post - pre`, equal to `amount - feeExecuted`), never `balanceOf(this)`. A pre-existing or
///      donated USDC balance (incl. escrowed failed transfers) is therefore never forwardable.
contract CCTPAdapter is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev CCTP V2 wire offsets. Outer MessageV2 header is 148 bytes
    ///      (version[4] sourceDomain[4] destinationDomain[4] nonce[32] sender[32] recipient[32]
    ///       destinationCaller[32] minFinalityThreshold[4] finalityThresholdExecuted[4]); the
    ///      BurnMessageV2 body follows. mintRecipient is at body offset 36 → absolute 184; the
    ///      fixed BurnMessageV2 body is 228 bytes so hookData (the tail) starts at absolute 376.
    uint256 internal constant MINT_RECIPIENT_OFFSET = 184;
    uint256 internal constant HOOKDATA_OFFSET = 376;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The CCTP V2 MessageTransmitter used to receive + verify messages
    IMessageTransmitterV2 public immutable MESSAGE_TRANSMITTER;

    /// @notice The USDC token minted by CCTP on this chain
    IERC20 public immutable USDC;

    /// @notice The SuperDestinationExecutor for processing bridged executions
    ISuperDestinationExecutor public immutable SUPER_DESTINATION_EXECUTOR;

    /// @notice Claimable balances for failed USDC transfers: account => token => amount
    mapping(address account => mapping(address token => uint256 amount)) public failedTransfers;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a constructor argument is the zero address
    error ADDRESS_NOT_VALID();

    /// @notice Thrown when the message is too short to contain a BurnMessageV2 + hookData
    error MESSAGE_TOO_SHORT();

    /// @notice Thrown when the message's mintRecipient is not this adapter
    error MINT_RECIPIENT_MISMATCH();

    /// @notice Thrown when MessageTransmitterV2.receiveMessage returns false
    error RECEIVE_MESSAGE_FAILED();

    /// @notice Thrown when the decoded account is the zero address
    error ACCOUNT_NOT_VALID();

    /// @notice Thrown when the amount is zero
    error ZERO_AMOUNT();

    /// @notice Thrown when claiming more than the available failed transfer balance
    error INSUFFICIENT_FAILED_BALANCE();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the minted USDC is transferred to the account
    event TransferSucceeded(address indexed account, address indexed token, uint256 amount);

    /// @notice Emitted when the USDC transfer to the account fails and the amount is escrowed
    event TransferFailed(address indexed account, address indexed token, uint256 amount);

    /// @notice Emitted when tokens were delivered but the executor call reverted
    event ExecutionFailed(address indexed account);

    /// @notice Emitted when a recipient claims a previously failed transfer
    event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param messageTransmitter_ CCTP V2 MessageTransmitter on this chain
    /// @param usdc_ USDC token on this chain (the token CCTP mints)
    /// @param superDestinationExecutor_ SuperDestinationExecutor on this chain
    constructor(address messageTransmitter_, address usdc_, address superDestinationExecutor_) {
        if (messageTransmitter_ == address(0) || usdc_ == address(0) || superDestinationExecutor_ == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        MESSAGE_TRANSMITTER = IMessageTransmitterV2(messageTransmitter_);
        USDC = IERC20(usdc_);
        SUPER_DESTINATION_EXECUTOR = ISuperDestinationExecutor(superDestinationExecutor_);
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE + EXECUTE
    //////////////////////////////////////////////////////////////*/

    /// @notice Receives a CCTP V2 message, mints the bridged USDC, forwards it to the intent account,
    ///         and best-effort executes the signed destination intent.
    /// @dev PERMISSIONLESS — see contract-level NatSpec for why this is safe. The adapter must have been
    ///      set as the message's `mintRecipient` and `destinationCaller` on the source chain.
    /// @param message The raw CCTP V2 message bytes (contains the hookData payload as its tail)
    /// @param attestation The Circle attestation over keccak256(message)
    function receiveAndExecute(bytes calldata message, bytes calldata attestation) external nonReentrant {
        // 1. Fail-fast bounds + recipient check before any external call.
        if (message.length < HOOKDATA_OFFSET) revert MESSAGE_TOO_SHORT();
        bytes32 mintRecipient = bytes32(message[MINT_RECIPIENT_OFFSET:MINT_RECIPIENT_OFFSET + 32]);
        if (mintRecipient != bytes32(uint256(uint160(address(this))))) revert MINT_RECIPIENT_MISMATCH();

        // 2. Receive the message: mints (amount - feeExecuted) USDC to this adapter.
        //    Measure the exact delta so donated / escrowed balances are never forwardable.
        uint256 pre = USDC.balanceOf(address(this));
        if (!MESSAGE_TRANSMITTER.receiveMessage(message, attestation)) revert RECEIVE_MESSAGE_FAILED();
        uint256 minted = USDC.balanceOf(address(this)) - pre;

        // 3. Decode the executor payload from the attested hookData tail (bounds-checked abi.decode).
        (
            bytes memory initData,
            bytes memory executorCalldata,
            address account,
            address[] memory dstTokens,
            uint256[] memory intentAmounts,
            bytes memory sigData
        ) = abi.decode(message[HOOKDATA_OFFSET:], (bytes, bytes, address, address[], uint256[], bytes));

        if (account == address(0)) revert ACCOUNT_NOT_VALID();

        // 4. Fund the account first (so the executor can check its balance), escrowing on failure.
        if (_tryTransfer(account, minted)) {
            emit TransferSucceeded(account, address(USDC), minted);
        } else {
            failedTransfers[account][address(USDC)] += minted;
            emit TransferFailed(account, address(USDC), minted);
        }

        // 5. Best-effort execution. Bare catch → revert returndata is never copied (returnbomb-safe);
        //    a reverting hook set cannot unwind the already-delivered USDC.
        try SUPER_DESTINATION_EXECUTOR.processBridgedExecution(
            address(USDC), account, dstTokens, intentAmounts, initData, executorCalldata, sigData
        ) { } catch {
            emit ExecutionFailed(account);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 CLAIM
    //////////////////////////////////////////////////////////////*/

    /// @notice Claim USDC from a previously failed transfer. Only the recipient can claim its own.
    /// @param token The token to claim (USDC)
    /// @param amount The amount to claim
    function claimFailedTransfer(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZERO_AMOUNT();

        uint256 available = failedTransfers[msg.sender][token];
        if (available < amount) revert INSUFFICIENT_FAILED_BALANCE();

        failedTransfers[msg.sender][token] = available - amount;
        IERC20(token).safeTransfer(msg.sender, amount);

        emit FailedTransferClaimed(msg.sender, token, amount);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Attempt to transfer USDC to an account, returning success/failure instead of reverting.
    /// @dev Low-level call handles non-standard ERC20s that don't return a bool.
    /// @param account The recipient
    /// @param amount The amount to transfer
    /// @return success Whether the transfer succeeded
    function _tryTransfer(address account, uint256 amount) internal returns (bool success) {
        (bool callSuccess, bytes memory returnData) =
            address(USDC).call(abi.encodeCall(IERC20.transfer, (account, amount)));
        success = callSuccess && (returnData.length == 0 || abi.decode(returnData, (bool)));
    }
}
