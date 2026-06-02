// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External Dependencies
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Vendor Interfaces
import { ILayerZeroComposer } from "../vendor/bridges/layerzero/ILayerZeroComposer.sol";
import { IStargate } from "../vendor/bridges/stargate/IStargate.sol";

// Superform Interfaces
import { ISuperDestinationExecutor } from "../interfaces/ISuperDestinationExecutor.sol";

/// @title StargateAdapter
/// @author Superform Labs
/// @notice Receives LayerZero V2 compose messages from Stargate/OFT and forwards them to the SuperDestinationExecutor.
/// @notice This contract acts as a translator between LayerZero V2 compose callbacks and the core Superform execution
/// logic.
/// @dev Supports both Stargate pool tokens (taxi/bus modes) and generic OFT tokens
/// @dev Token delivery happens in a separate transaction (lzReceive) before lzCompose is called
/// @dev Uses amountLD from OFTComposeMsgCodec header (bytes 12-44) for transfers, ensuring each
/// @dev compose only transfers the exact amount credited during its corresponding lzReceive
/// @dev lzCompose MUST NOT revert (except for invalid sender) — LZ compose messages are ordered,
/// @dev so a revert blocks all subsequent composes from the same source. Failed transfers are stored
/// @dev for user self-claim via claimFailedTransfer.
contract StargateAdapter is ILayerZeroComposer, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Offset where the inner composeMsg starts in the OFTComposeMsgCodec-encoded message
    /// @dev Layout: nonce(8) + srcEid(4) + amountLD(32) + composeFrom(32) = 76 bytes header
    uint256 private constant COMPOSE_MSG_OFFSET = 76;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The LayerZero V2 EndpointV2 address
    /// @dev Same on all EVM chains: 0x1a44076050125825900e736c501f859c50fE728c
    address public immutable LZ_ENDPOINT;

    /// @notice The SuperDestinationExecutor for processing bridged executions
    ISuperDestinationExecutor public immutable SUPER_DESTINATION_EXECUTOR;

    /// @notice Claimable balances for failed token transfers: account => token => amount
    /// @dev token address(0) represents native ETH
    mapping(address account => mapping(address token => uint256 amount)) public failedTransfers;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a constructor argument is the zero address
    error ADDRESS_NOT_VALID();

    /// @notice Thrown when lzCompose is called by an address other than the LZ endpoint
    error INVALID_SENDER();

    /// @notice Thrown when native ETH transfer fails during claim
    error ETH_TRANSFER_FAILED();

    /// @notice Thrown when claiming more than the available failed transfer balance
    error INSUFFICIENT_FAILED_BALANCE();

    /// @notice Thrown when claiming with zero amount
    error ZERO_AMOUNT();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when token transfer to the account succeeds during lzCompose
    /// @param guid The LayerZero unique message identifier
    /// @param account The target account that received the tokens
    /// @param tokenSent The token address transferred (address(0) for native ETH)
    /// @param amount The amount of tokens transferred
    event TransferSucceeded(bytes32 indexed guid, address indexed account, address indexed tokenSent, uint256 amount);

    /// @notice Emitted when token transfer to the account fails during lzCompose
    /// @param guid The LayerZero unique message identifier
    /// @param account The intended recipient
    /// @param token The token that failed to transfer (address(0) for native ETH)
    /// @param amount The amount stored for manual claim
    event TransferFailed(bytes32 indexed guid, address indexed account, address indexed token, uint256 amount);

    /// @notice Emitted when the executor call fails but tokens were already transferred to the account
    /// @param guid The LayerZero unique message identifier
    /// @param account The account that received tokens but whose execution failed
    /// @param reason The revert reason from the executor
    event ExecutionFailed(bytes32 indexed guid, address indexed account, bytes reason);

    /// @notice Emitted when the compose message is too short to contain the OFTComposeMsgCodec header
    /// @param guid The LayerZero unique message identifier
    /// @param messageLength The actual message length received
    event ComposeMsgTooShort(bytes32 indexed guid, uint256 messageLength);

    /// @notice Emitted when the inner compose payload cannot be decoded (malformed composeMsg)
    /// @param guid The LayerZero unique message identifier
    /// @param reason The revert reason from the failed decode
    event ComposeDecodeFailed(bytes32 indexed guid, bytes reason);

    /// @notice Emitted when token resolution from _from.token() fails during lzCompose
    /// @param guid The LayerZero unique message identifier
    /// @param from The Stargate pool or OFT contract that failed token resolution
    event TokenResolutionFailed(bytes32 indexed guid, address indexed from);

    /// @notice Emitted when a user claims their failed transfer
    /// @param account The account claiming funds
    /// @param token The token claimed (address(0) for native ETH)
    /// @param amount The amount claimed
    event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param lzEndpoint_ The LayerZero V2 EndpointV2 address
    /// @param superDestinationExecutor_ The SuperDestinationExecutor address
    constructor(address lzEndpoint_, address superDestinationExecutor_) {
        if (lzEndpoint_ == address(0) || superDestinationExecutor_ == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        LZ_ENDPOINT = lzEndpoint_;
        SUPER_DESTINATION_EXECUTOR = ISuperDestinationExecutor(superDestinationExecutor_);
    }

    /*//////////////////////////////////////////////////////////////
                                 RECEIVE
    //////////////////////////////////////////////////////////////*/

    /// @dev Accepts native ETH from StargatePoolNative during lzReceive token credit
    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                            LAYERZERO COMPOSE LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ILayerZeroComposer
    /// @dev Decodes the OFTComposeMsgCodec message, transfers tokens to the target account,
    ///      and forwards the execution payload to SuperDestinationExecutor.
    /// @dev MUST NOT revert after sender validation — a revert blocks ALL subsequent composes
    ///      from the same source. Failed transfers are stored for user self-claim.
    /// @dev The _from parameter is the destination Stargate pool or OFT contract (NOT the source chain sender)
    /// @dev Uses amountLD from OFTComposeMsgCodec header for precise per-compose transfers
    function lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address, // _executor
        bytes calldata // _extraData
    )
        external
        payable
        override
    {
        // 1. Validate sender: only the LZ endpoint can call lzCompose
        if (msg.sender != LZ_ENDPOINT) revert INVALID_SENDER();

        // 2. Validate message length: must contain OFTComposeMsgCodec header
        //    Emit + return instead of reverting to avoid blocking the compose pipeline
        if (_message.length < COMPOSE_MSG_OFFSET) {
            emit ComposeMsgTooShort(_guid, _message.length);
            return;
        }

        // 3. Extract amountLD from OFTComposeMsgCodec header (bytes 12-44)
        //    This is the post-dust-removal amount set by Stargate after lzReceive
        uint256 amountLD = uint256(bytes32(_message[12:44]));

        // 4. Extract composeFrom from OFTComposeMsgCodec header (bytes 44-76)
        //    This is the source chain sender address (padded to bytes32)
        //    Used as fallback claimant when account is address(0)
        address composeFrom = address(uint160(uint256(bytes32(_message[44:76]))));

        // 5. Identify token via _from.token() — wrapped in try/catch (P2-1)
        //    If _from is not a valid Stargate/OFT contract, token() will revert.
        //    We MUST NOT let that block the compose pipeline.
        address tokenSent;
        try IStargate(_from).token() returns (address resolvedToken) {
            tokenSent = resolvedToken;
        } catch {
            emit TokenResolutionFailed(_guid, _from);
            return;
        }

        // 6. Delegate to external handler via self-call so abi.decode panics are caught
        //    by try/catch. A malformed inner payload must not block the compose pipeline.
        try this.handleCompose(_guid, _message, tokenSent, amountLD, composeFrom) { }
        catch (bytes memory reason) {
            emit ComposeDecodeFailed(_guid, reason);
        }
    }

    /// @notice Compose handler — external so lzCompose can wrap it in try/catch to absorb decode panics
    /// @dev MUST only be called by this contract (self-call from lzCompose)
    function handleCompose(
        bytes32 _guid,
        bytes calldata _message,
        address tokenSent,
        uint256 amountLD,
        address composeFrom
    )
        external
    {
        if (msg.sender != address(this)) revert INVALID_SENDER();
        // Decode the inner application payload (skip 76-byte OFTComposeMsgCodec header)
        (
            bytes memory initData,
            bytes memory executorCalldata,
            address account,
            address[] memory dstTokens,
            uint256[] memory intentAmounts,
            bytes memory sigData
        ) = abi.decode(_message[COMPOSE_MSG_OFFSET:], (bytes, bytes, address, address[], uint256[], bytes));

        // Validate account is not zero address
        //    If account is zero, store in failedTransfers keyed by composeFrom (source chain sender)
        //    so the originator can claim on the destination chain.
        //    Don't revert — avoids blocking the LZ pipeline.
        //    NOTE: if composeFrom is also address(0) (requires a bug in the source OFT/Stargate
        //    encoder), tokens become permanently unclaimable. Accepted risk — the contract is
        //    intentionally admin-less and adding a rescue function would widen the attack surface
        //    more than this near-impossible edge case warrants.
        if (account == address(0)) {
            failedTransfers[composeFrom][tokenSent] += amountLD;
            emit TransferFailed(_guid, composeFrom, tokenSent, amountLD);
            return;
        }

        // Transfer received funds to the target account
        //    Uses amountLD from the compose header — the exact amount credited during lzReceive
        //    If transfer fails, store for manual claim — MUST NOT revert to avoid blocking LZ pipeline
        bool transferSuccess = _tryTransfer(tokenSent, account, amountLD);

        if (!transferSuccess) {
            failedTransfers[account][tokenSent] += amountLD;
            emit TransferFailed(_guid, account, tokenSent, amountLD);
        } else {
            emit TransferSucceeded(_guid, account, tokenSent, amountLD);
        }

        // Best-effort execution — attempt regardless of transfer outcome.
        //    The account may already hold tokens from a prior operation, so execution can
        //    succeed even when this transfer failed.  If execution also fails, the try/catch
        //    absorbs the revert and emits ExecutionFailed; the merkle root stays unconsumed
        //    in that case (unlike the zero-account path above, which skips execution entirely
        //    because there is no valid account to target).
        try SUPER_DESTINATION_EXECUTOR.processBridgedExecution(
            tokenSent, account, dstTokens, intentAmounts, initData, executorCalldata, sigData
        ) { } catch (bytes memory reason) {
            emit ExecutionFailed(_guid, account, reason);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            CLAIM LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Claim tokens from a failed lzCompose transfer
    /// @dev Only the intended recipient (account) can claim their own failed transfers
    /// @param token The token to claim (address(0) for native ETH)
    /// @param amount The amount to claim
    function claimFailedTransfer(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZERO_AMOUNT();

        uint256 available = failedTransfers[msg.sender][token];
        if (available < amount) revert INSUFFICIENT_FAILED_BALANCE();

        failedTransfers[msg.sender][token] = available - amount;

        if (token == address(0)) {
            (bool success,) = msg.sender.call{ value: amount }("");
            if (!success) revert ETH_TRANSFER_FAILED();
        } else {
            IERC20(token).safeTransfer(msg.sender, amount);
        }

        emit FailedTransferClaimed(msg.sender, token, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Attempt to transfer tokens to an account, returning success/failure
    /// @dev Does not revert on failure — returns false so the caller can handle it
    /// @dev Uses low-level call for ERC20 transfers to support non-standard tokens (e.g. USDT)
    ///      that don't return a bool from transfer()
    /// @param token The token to transfer (address(0) for native ETH)
    /// @param account The recipient
    /// @param amount The amount to transfer
    /// @return success Whether the transfer succeeded
    function _tryTransfer(address token, address account, uint256 amount) internal returns (bool success) {
        if (token == address(0)) {
            (success,) = account.call{ value: amount }("");
        } else {
            // Low-level call handles non-standard ERC20s (USDT) that don't return bool
            (bool callSuccess, bytes memory returnData) =
                token.call(abi.encodeCall(IERC20.transfer, (account, amount)));
            success = callSuccess && (returnData.length == 0 || abi.decode(returnData, (bool)));
        }
    }
}
