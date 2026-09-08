// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External Dependencies
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Protocol Interfaces
import { IAcrossV3Receiver } from "../vendor/bridges/across/IAcrossV3Receiver.sol";

// Superform Interfaces
import { ISuperDestinationExecutor } from "../interfaces/ISuperDestinationExecutor.sol";
import { ISuperValidator } from "../interfaces/ISuperValidator.sol";

/// @notice Minimal getter for the executor's wired validator
/// @dev Kept local so the shared ISuperDestinationExecutor interface (compiled into locked-bytecode
///      deployed contracts) stays untouched; SuperDestinationExecutor exposes this as a public immutable
interface IDestinationValidatorSource {
    function SUPER_DESTINATION_VALIDATOR() external view returns (address);
}

/// @title AcrossV3AdapterV2
/// @author Superform Labs
/// @notice Receives compact Across V3 messages encoded as abi.encode(initData, sigData)
/// @notice Extracts account, executor, validator, executorCalldata, dstTokens, and intentAmounts from sigData's
/// DstProof.info
/// @dev The Across hook and adapter must use the same message format
/// @dev Across delivers tokens to this adapter via handleV3AcrossMessage, which then transfers to the account
/// @dev Transfer failures revert the Across fill atomically
contract AcrossV3AdapterV2 is IAcrossV3Receiver {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The Across SpokePool address
    address public immutable ACROSS_SPOKE_POOL;

    /// @notice The SuperDestinationExecutor for processing bridged executions
    ISuperDestinationExecutor public immutable SUPER_DESTINATION_EXECUTOR;

    /// @notice The SuperDestinationValidator the executor is wired to
    /// @dev Cached at construction; intents signed for a different validator can never execute here
    address public immutable SUPER_DESTINATION_VALIDATOR;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Holds fields extracted from sigData's DstProof.info to avoid stack-too-deep
    struct ExtractedData {
        /// @dev The target smart account receiving tokens and execution
        address account;
        /// @dev The executor the intent was signed for; must match SUPER_DESTINATION_EXECUTOR
        address executor;
        /// @dev The validator the intent was signed for; must match SUPER_DESTINATION_VALIDATOR
        address validator;
        /// @dev The encoded execution data forwarded to the destination executor
        bytes executorCalldata;
        /// @dev The tokens the intent expects on the destination chain
        address[] dstTokens;
        /// @dev The per-token amounts the intent expects on the destination chain
        uint256[] intentAmounts;
        /// @dev Whether a DstProof matching the current chain ID was found
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

    /// @notice Thrown when the signed DstProof names an executor other than SUPER_DESTINATION_EXECUTOR
    /// @dev Such an intent can never execute through this adapter; reverting rolls back the fill
    ///      so the deposit refunds at origin instead of stranding tokens on the account
    error EXECUTOR_NOT_VALID();

    /// @notice Thrown when the signed DstProof names a validator other than SUPER_DESTINATION_VALIDATOR
    /// @dev The source leaf binds the validator, so a mismatch fails destination signature validation
    ///      forever; reverting rolls back the fill so the deposit refunds at origin
    error VALIDATOR_NOT_VALID();

    /// @notice Thrown when bridged tokens cannot be transferred to the destination account
    /// @dev Reverting rolls back the complete Across fill, including the SpokePool token transfer
    error TRANSFER_FAILED();

    /// @notice Thrown when destination execution fails without returning revert data
    /// @dev Empty revert data includes the observed out-of-gas failure mode and other exceptional halts;
    ///      also thrown when the executor has no deployed code
    error DESTINATION_EXECUTION_FAILED();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when token transfer to the account succeeds
    /// @param account The target account that received the tokens
    /// @param token The token address transferred
    /// @param amount The amount of tokens transferred
    event TransferSucceeded(address indexed account, address indexed token, uint256 amount);

    /// @notice Emitted when the executor call fails but tokens were already transferred to the account
    /// @dev Anyone can trigger this event via a permissionless Across deposit naming the adapter,
    ///      so it MUST NOT gate privileged actions; the selector lets monitoring filter such noise
    ///      (e.g. forged signatures) from genuine execution failures
    /// @param account The account that received tokens but whose execution failed
    /// @param selector The first four bytes of the executor's revert data (zero if shorter)
    event ExecutionFailed(address indexed account, bytes4 selector);

    /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param acrossSpokePool_ The Across SpokePool authorized to call handleV3AcrossMessage
    /// @param superDestinationExecutor_ The SuperDestinationExecutor that processes bridged executions
    constructor(address acrossSpokePool_, address superDestinationExecutor_) {
        if (acrossSpokePool_ == address(0) || superDestinationExecutor_ == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        ACROSS_SPOKE_POOL = acrossSpokePool_;
        SUPER_DESTINATION_EXECUTOR = ISuperDestinationExecutor(superDestinationExecutor_);
        SUPER_DESTINATION_VALIDATOR =
            IDestinationValidatorSource(superDestinationExecutor_).SUPER_DESTINATION_VALIDATOR();
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

        // 3. Extract account, executor, executorCalldata, dstTokens, intentAmounts from sigData
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

        // 6. Revert when the signed executor is not this adapter's executor. Such an intent can never
        //    execute here, so rolling back the fill lets the deposit refund at origin instead of
        //    delivering tokens alongside a permanently unexecutable intent.
        if (extracted.executor != address(SUPER_DESTINATION_EXECUTOR)) {
            revert EXECUTOR_NOT_VALID();
        }

        // 7. Revert when the signed validator is not the executor's validator. The source leaf binds
        //    the validator, so a mismatch fails destination signature validation forever — same
        //    permanently-dead-intent class as the executor check above.
        if (extracted.validator != SUPER_DESTINATION_VALIDATOR) {
            revert VALIDATOR_NOT_VALID();
        }

        // 8. Transfer received funds to the target account. Across callbacks are atomic with the fill,
        //    so reverting here prevents tokens from being stranded in this adapter.
        if (!IERC20(tokenSent).trySafeTransfer(extracted.account, amount)) {
            revert TRANSFER_FAILED();
        }
        emit TransferSucceeded(extracted.account, tokenSent, amount);

        // 9. Best-effort execution for failures with revert data. Empty failures include the observed
        //    OOG mode and revert the fill so Across can retry without finalizing token delivery alone.
        //    The code check runs per call: try/catch on a code-less target reverts in this frame with
        //    an unhelpful empty reason, so the explicit check surfaces a clear error instead.
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
            // Only the bounded 4-byte selector is copied — never the full (attacker-sized) returndata.
            uint256 returnDataSize;
            bytes4 selector;
            assembly ("memory-safe") {
                returnDataSize := returndatasize()
                if gt(returnDataSize, 3) {
                    mstore(0, 0)
                    returndatacopy(0, 0, 4)
                    selector := mload(0)
                }
            }
            if (returnDataSize == 0) revert DESTINATION_EXECUTION_FAILED();
            emit ExecutionFailed(extracted.account, selector);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Extract account, executor, executorCalldata, dstTokens, intentAmounts from sigData's DstProof
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
                extracted.executor = proofDst[i].info.executor;
                extracted.validator = proofDst[i].info.validator;
                extracted.executorCalldata = proofDst[i].info.data;
                extracted.dstTokens = proofDst[i].info.dstTokens;
                extracted.intentAmounts = proofDst[i].info.intentAmounts;
                extracted.found = true;
                return extracted;
            }
        }
    }
}
