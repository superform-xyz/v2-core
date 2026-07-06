// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External Dependencies
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Vendor Interfaces
import { ILayerZeroComposer } from "../vendor/bridges/layerzero/ILayerZeroComposer.sol";
import { IStargate } from "../vendor/bridges/stargate/IStargate.sol";
import { ITokenMessaging } from "../vendor/bridges/stargate/ITokenMessaging.sol";

// Superform Interfaces
import { ISuperDestinationExecutor } from "../interfaces/ISuperDestinationExecutor.sol";
import { ISuperValidator } from "../interfaces/ISuperValidator.sol";

/// @title StargateAdapterV2
/// @author Superform Labs
/// @notice V2 adapter that receives compact LayerZero V2 compose messages from Stargate/OFT.
/// @notice The compose message uses a 2-field format: abi.encode(initData, sigData) instead of the
/// @notice V1 6-field format. The adapter extracts account, executorCalldata, dstTokens, and intentAmounts
/// @notice from sigData's DstProof.info, eliminating 1.5-5.5 KB of duplicate data per message.
/// @dev V2 hook ↔ V2 adapter must be used together (incompatible with V1 counterparts)
/// @dev Token delivery happens in a separate transaction (lzReceive) before lzCompose is called
/// @dev Uses amountLD from OFTComposeMsgCodec header (bytes 12-44) for transfers
/// @dev lzCompose MUST NOT revert (except for invalid sender) — failed transfers are stored for user self-claim
contract StargateAdapterV2 is ILayerZeroComposer, ReentrancyGuard {
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

    /// @notice The Stargate V2 TokenMessaging contract for pool registration verification
    /// @dev Used to validate that _from in lzCompose is a legitimate Stargate pool.
    ///      TokenMessaging.assetIds(pool) returns non-zero only for pools registered by the owner.
    ///      This prevents spoofed composes from malicious contracts — sendCompose is permissionless
    ///      in LZ V2, so any contract can register a compose targeting this adapter.
    ITokenMessaging public immutable TOKEN_MESSAGING;

    /// @notice The SuperDestinationExecutor for processing bridged executions
    ISuperDestinationExecutor public immutable SUPER_DESTINATION_EXECUTOR;

    /// @notice Allowed OFT contracts that bypass the TokenMessaging.assetIds pool check
    /// @dev Set at construction time. For OFTs (e.g. USDT0) that use LZ compose but are not
    ///      registered as Stargate pools in TokenMessaging. Empty array = pool-only mode.
    mapping(address oft => bool allowed) public allowedOFTs;

    /// @notice Array of all whitelisted OFT addresses for enumeration
    address[] public allowedOFTsList;

    /// @notice Claimable balances for failed token transfers: account => token => amount
    /// @dev token address(0) represents native ETH
    mapping(address account => mapping(address token => uint256 amount)) public failedTransfers;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Holds fields extracted from sigData's DstProof.info to avoid stack-too-deep
    struct ExtractedData {
        address account;
        bytes executorCalldata;
        address[] dstTokens;
        uint256[] intentAmounts;
        bool found;
    }

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
    /// @dev Revert reason is intentionally omitted to prevent returnbomb OOG inside catch (EIP-150)
    /// @param guid The LayerZero unique message identifier
    /// @param account The account that received tokens but whose execution failed
    event ExecutionFailed(bytes32 indexed guid, address indexed account);

    /// @notice Emitted when the compose message is too short to contain the OFTComposeMsgCodec header
    /// @param guid The LayerZero unique message identifier
    /// @param messageLength The actual message length received
    event ComposeMsgTooShort(bytes32 indexed guid, uint256 messageLength);

    /// @notice Emitted when the inner compose payload cannot be decoded (malformed composeMsg)
    /// @dev Revert reason is intentionally omitted to prevent returnbomb OOG inside catch (EIP-150)
    /// @param guid The LayerZero unique message identifier
    event ComposeDecodeFailed(bytes32 indexed guid);

    /// @notice Emitted when token resolution from _from.token() fails during lzCompose
    /// @param guid The LayerZero unique message identifier
    /// @param from The Stargate pool or OFT contract that failed token resolution
    event TokenResolutionFailed(bytes32 indexed guid, address indexed from);

    /// @notice Emitted when _from is not a registered Stargate pool or allowed OFT
    /// @dev sendCompose is permissionless in LZ V2 — anyone can spoof a compose.
    ///      This event is emitted instead of reverting to avoid blocking the compose queue.
    /// @param guid The LayerZero unique message identifier
    /// @param from The unregistered contract that sent the compose
    event UnregisteredPool(bytes32 indexed guid, address indexed from);

    /// @notice Emitted when no DstProof matches the current chain's ID in sigData
    /// @dev This indicates a configuration mismatch — the compose was sent with sigData
    ///      that doesn't include a proof for this destination chain.
    /// @param guid The LayerZero unique message identifier
    /// @param chainId The current chain ID that had no matching DstProof
    event NoDstProofForChain(bytes32 indexed guid, uint64 chainId);

    /// @notice Emitted when a user claims their failed transfer
    /// @param account The account claiming funds
    /// @param token The token claimed (address(0) for native ETH)
    /// @param amount The amount claimed
    event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param lzEndpoint_ The LayerZero V2 EndpointV2 address
    /// @param tokenMessaging_ The Stargate V2 TokenMessaging address for pool verification
    /// @param superDestinationExecutor_ The SuperDestinationExecutor address
    /// @param allowedOFTs_ OFT addresses allowed to bypass pool check (empty = pool-only mode)
    constructor(
        address lzEndpoint_,
        address tokenMessaging_,
        address superDestinationExecutor_,
        address[] memory allowedOFTs_
    ) {
        if (lzEndpoint_ == address(0) || tokenMessaging_ == address(0) || superDestinationExecutor_ == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        LZ_ENDPOINT = lzEndpoint_;
        TOKEN_MESSAGING = ITokenMessaging(tokenMessaging_);
        SUPER_DESTINATION_EXECUTOR = ISuperDestinationExecutor(superDestinationExecutor_);

        for (uint256 i; i < allowedOFTs_.length; ++i) {
            allowedOFTs[allowedOFTs_[i]] = true;
            allowedOFTsList.push(allowedOFTs_[i]);
        }
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
    /// @dev Decodes the compact 2-field compose message, extracts fields from sigData,
    ///      transfers tokens to the target account, and forwards to SuperDestinationExecutor.
    /// @dev MUST NOT revert after sender validation — a revert blocks ALL subsequent composes
    ///      from the same source. Failed transfers are stored for user self-claim.
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
        if (_message.length < COMPOSE_MSG_OFFSET) {
            emit ComposeMsgTooShort(_guid, _message.length);
            return;
        }

        // 3. Validate _from is a registered Stargate pool in TokenMessaging, or an allowed OFT
        if (TOKEN_MESSAGING.assetIds(_from) == 0 && !allowedOFTs[_from]) {
            emit UnregisteredPool(_guid, _from);
            return;
        }

        // 4. Extract amountLD from OFTComposeMsgCodec header (bytes 12-44)
        uint256 amountLD = uint256(bytes32(_message[12:44]));

        // 5. Extract composeFrom from OFTComposeMsgCodec header (bytes 44-76)
        address composeFrom = address(uint160(uint256(bytes32(_message[44:76]))));

        // 6. Identify token via _from.token()
        address tokenSent = IStargate(_from).token();

        // 7. Delegate to external handler via self-call so abi.decode panics are caught
        try this.handleCompose(_guid, _message, tokenSent, amountLD, composeFrom) { }
        catch {
            // NOTE: we intentionally discard the revert reason to prevent returnbomb attacks.
            //       A hostile token's balanceOf (or any external call in the execution path) could
            //       revert with very large data; copying it via `catch (bytes memory reason)` can
            //       OOG inside the catch block (only 1/64 gas remains per EIP-150), causing
            //       lzCompose itself to revert and blocking the ordered compose queue.
            emit ComposeDecodeFailed(_guid);
        }
    }

    /// @notice Compose handler — external so lzCompose can wrap it in try/catch to absorb decode panics
    /// @dev MUST only be called by this contract (self-call from lzCompose)
    /// @dev V2 format: decodes compact 2-field payload (initData, sigData) and extracts
    ///      account, executorCalldata, dstTokens, intentAmounts from sigData's DstProof.info
    /// @param _guid The LayerZero unique message identifier
    /// @param _message The full OFTComposeMsgCodec-encoded message including header
    /// @param tokenSent The resolved token address from the Stargate pool
    /// @param amountLD The amount in local decimals extracted from the compose header
    /// @param composeFrom The source chain sender address (fallback claimant)
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

        // V2: Decode compact 2-field format (initData, sigData)
        (bytes memory initData, bytes memory sigDataRaw) =
            abi.decode(_message[COMPOSE_MSG_OFFSET:], (bytes, bytes));

        // V2: Extract account, executorCalldata, dstTokens, intentAmounts from sigData
        ExtractedData memory extracted = _extractFromSigData(sigDataRaw);

        // V2: Graceful handling when no DstProof matches current chain
        // Credit composeFrom so tokens from lzReceive are claimable (same pattern as zero-account)
        if (!extracted.found) {
            uint256 preBalance =
                tokenSent == address(0) ? address(this).balance : IERC20(tokenSent).balanceOf(address(this));
            if (preBalance >= amountLD) {
                failedTransfers[composeFrom][tokenSent] += amountLD;
                emit TransferFailed(_guid, composeFrom, tokenSent, amountLD);
            }
            emit NoDstProofForChain(_guid, uint64(block.chainid));
            return;
        }

        // Delegate transfer + execution to avoid stack too deep
        _handleTransferAndExecution(
            _guid, tokenSent, amountLD, composeFrom, extracted.account, initData, sigDataRaw, extracted
        );
    }

    /// @dev Handles the token transfer and executor call after sigData extraction
    ///      Split from handleCompose to avoid stack-too-deep
    function _handleTransferAndExecution(
        bytes32 _guid,
        address tokenSent,
        uint256 amountLD,
        address composeFrom,
        address account,
        bytes memory initData,
        bytes memory sigDataRaw,
        ExtractedData memory extracted
    )
        private
    {
        // SAME AS V1: Snapshot adapter balance BEFORE any transfer attempt.
        uint256 preBalance =
            tokenSent == address(0) ? address(this).balance : IERC20(tokenSent).balanceOf(address(this));

        // SAME AS V1: Validate account is not zero address
        if (account == address(0)) {
            if (preBalance >= amountLD) {
                failedTransfers[composeFrom][tokenSent] += amountLD;
                emit TransferFailed(_guid, composeFrom, tokenSent, amountLD);
            }
            return;
        }

        // SAME AS V1: Transfer received funds to the target account
        bool transferSuccess = _tryTransfer(tokenSent, account, amountLD);

        if (!transferSuccess) {
            if (preBalance >= amountLD) {
                failedTransfers[account][tokenSent] += amountLD;
                emit TransferFailed(_guid, account, tokenSent, amountLD);
            }
        } else {
            emit TransferSucceeded(_guid, account, tokenSent, amountLD);
        }

        // SAME AS V1: Best-effort execution
        try SUPER_DESTINATION_EXECUTOR.processBridgedExecution(
            tokenSent,
            account,
            extracted.dstTokens,
            extracted.intentAmounts,
            initData,
            extracted.executorCalldata,
            sigDataRaw
        ) { } catch {
            emit ExecutionFailed(_guid, account);
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
                            VIEW
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the full list of whitelisted OFT addresses
    /// @return The array of allowed OFT addresses
    function getAllowedOFTs() external view returns (address[] memory) {
        return allowedOFTsList;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Extract account, executorCalldata, dstTokens, intentAmounts from sigData's DstProof
    /// @dev Decodes the SignatureData struct and iterates DstProof[] to find the entry
    ///      matching the current chain ID. All operations are pure memory — no external calls.
    /// @param sigDataRaw The ABI-encoded SignatureData bytes
    /// @return extracted The extracted fields from the matching DstProof.info
    function _extractFromSigData(bytes memory sigDataRaw)
        internal
        view
        returns (ExtractedData memory extracted)
    {
        // Decode SignatureData struct — mirrors SuperValidatorBase._decodeSignatureData()
        (,,,,, ISuperValidator.DstProof[] memory proofDst,) =
            abi.decode(sigDataRaw, (uint64[], uint48, uint48, bytes32, bytes32[], ISuperValidator.DstProof[], bytes));

        // Find DstProof for current chain
        uint64 currentChain = uint64(block.chainid);
        uint256 len = proofDst.length;
        for (uint256 i; i < len; ++i) {
            if (proofDst[i].dstChainId == currentChain) {
                extracted.account = proofDst[i].info.account;
                extracted.executorCalldata = proofDst[i].info.data;
                extracted.dstTokens = proofDst[i].info.dstTokens;
                extracted.intentAmounts = proofDst[i].info.intentAmounts;
                extracted.found = true;
                return extracted;
            }
        }
    }

    /// @notice Attempt to transfer tokens to an account, returning success/failure
    /// @dev Does not revert on failure — returns false so the caller can handle it
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
