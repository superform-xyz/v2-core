// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External Dependencies
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Protocol Interfaces
import { IAcrossV3Receiver } from "../vendor/bridges/across/IAcrossV3Receiver.sol";

// Superform Interfaces
import { ISuperDestinationExecutor } from "../interfaces/ISuperDestinationExecutor.sol";
import { ISuperValidator } from "../interfaces/ISuperValidator.sol";

/// @title AcrossV3AdapterV2
/// @author Superform Labs
/// @notice Receives compact Across V3 messages encoded as abi.encode(initData, sigData)
/// @notice Extracts account, executorCalldata, dstTokens, and intentAmounts from sigData's DstProof.info
/// @dev The Across hook and adapter must use the same message format
/// @dev Across delivers tokens to this adapter via handleV3AcrossMessage, which then transfers to the account
/// @dev Transfer failures revert the Across fill atomically
contract AcrossV3AdapterV2 is IAcrossV3Receiver, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The Across SpokePool address
    address public immutable ACROSS_SPOKE_POOL;

    /// @notice The SuperDestinationExecutor for processing bridged executions
    ISuperDestinationExecutor public immutable SUPER_DESTINATION_EXECUTOR;

    /// @notice Claimable balances for failed token transfers: account => token => amount
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

    /// @notice Thrown when no DstProof matches the current chain ID in sigData
    /// @dev Unlike Stargate (where lzCompose MUST NOT revert to avoid blocking the compose queue),
    ///      Across fills are independent — reverting is safe and prevents permanent token loss
    error NO_DST_PROOF_FOR_CHAIN();

    /// @notice Thrown when the extracted account is the zero address
    error ACCOUNT_NOT_VALID();

    /// @notice Thrown when bridged tokens cannot be transferred to the destination account
    /// @dev Reverting rolls back the complete Across fill, including the SpokePool token transfer
    error TRANSFER_FAILED();

    /// @notice Thrown when destination execution fails without returning revert data
    /// @dev Empty revert data includes the observed out-of-gas failure mode and other exceptional halts
    error DESTINATION_EXECUTION_FAILED();

    /// @notice Thrown when claiming more than the available failed transfer balance
    error INSUFFICIENT_FAILED_BALANCE();

    /// @notice Thrown when claiming with zero amount
    error ZERO_AMOUNT();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when token transfer to the account succeeds
    /// @param account The target account that received the tokens
    /// @param tokenSent The token address transferred
    /// @param amount The amount of tokens transferred
    event TransferSucceeded(address indexed account, address indexed tokenSent, uint256 amount);

    /// @notice Emitted when token transfer to the account fails
    /// @param account The intended recipient
    /// @param token The token that failed to transfer
    /// @param amount The amount stored for manual claim
    event TransferFailed(address indexed account, address indexed token, uint256 amount);

    /// @notice Emitted when the executor call fails but tokens were already transferred to the account
    /// @param account The account that received tokens but whose execution failed
    event ExecutionFailed(address indexed account);

    /// @notice Emitted when a user claims their failed transfer
    /// @param account The account claiming funds
    /// @param token The token claimed
    /// @param amount The amount claimed
    event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address acrossSpokePool_, address superDestinationExecutor_) {
        if (acrossSpokePool_ == address(0) || superDestinationExecutor_ == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        ACROSS_SPOKE_POOL = acrossSpokePool_;
        SUPER_DESTINATION_EXECUTOR = ISuperDestinationExecutor(superDestinationExecutor_);
    }

    /*//////////////////////////////////////////////////////////////
                            ACROSS V3 RECEIVER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAcrossV3Receiver
    function handleV3AcrossMessage(
        address tokenSent,
        uint256 amount,
        address, // relayer; not used
        bytes memory message
    )
        external
        override
    {
        // 1. Validate Sender
        if (msg.sender != ACROSS_SPOKE_POOL) {
            revert INVALID_SENDER();
        }

        // 2. Decode compact 2-field format (initData, sigData)
        (bytes memory initData, bytes memory sigDataRaw) = abi.decode(message, (bytes, bytes));

        // 3. Extract account, executorCalldata, dstTokens, intentAmounts from sigData
        ExtractedData memory extracted = _extractFromSigData(sigDataRaw);

        // 4. Revert when no DstProof matches current chain
        //    Unlike Stargate (lzCompose MUST NOT revert to avoid blocking the ordered compose queue),
        //    Across fills are independent — reverting is safe and prevents permanent token loss at the adapter.
        if (!extracted.found) {
            revert NO_DST_PROOF_FOR_CHAIN();
        }

        // 5. Revert when account is zero address
        //    Prevents the Across fill from delivering funds to an unusable account.
        if (extracted.account == address(0)) {
            revert ACCOUNT_NOT_VALID();
        }

        // 6. Transfer received funds to the target account. Across callbacks are atomic with the fill,
        //    so reverting here prevents tokens from being stranded in this adapter.
        if (!IERC20(tokenSent).trySafeTransfer(extracted.account, amount)) {
            revert TRANSFER_FAILED();
        }
        emit TransferSucceeded(extracted.account, tokenSent, amount);

        // 7. Best-effort execution for failures with revert data. Empty failures include the observed
        //    OOG mode and revert the fill so Across can retry without finalizing token delivery alone.
        if (address(SUPER_DESTINATION_EXECUTOR).code.length == 0) revert DESTINATION_EXECUTION_FAILED();
        try SUPER_DESTINATION_EXECUTOR.processBridgedExecution(
            tokenSent,
            extracted.account,
            extracted.dstTokens,
            extracted.intentAmounts,
            initData,
            extracted.executorCalldata,
            sigDataRaw
        ) { }
        catch {
            uint256 returnDataSize;
            assembly ("memory-safe") {
                returnDataSize := returndatasize()
            }
            if (returnDataSize == 0) revert DESTINATION_EXECUTION_FAILED();
            emit ExecutionFailed(extracted.account);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            CLAIM LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Claim tokens from a failed transfer balance
    /// @dev Only the intended recipient can claim their recorded balance
    /// @param token The token to claim
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

    /// @notice Extract account, executorCalldata, dstTokens, intentAmounts from sigData's DstProof
    /// @dev Decodes the SignatureData struct and iterates DstProof[] to find the entry
    ///      matching the current chain ID. All operations are pure memory — no external calls.
    /// @param sigDataRaw The ABI-encoded SignatureData bytes
    /// @return extracted The extracted fields from the matching DstProof.info
    function _extractFromSigData(bytes memory sigDataRaw) internal view returns (ExtractedData memory extracted) {
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
}
