// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External Dependencies
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Superform Interfaces
import { ISuperDestinationExecutor } from "../interfaces/ISuperDestinationExecutor.sol";
import { ISuperValidator } from "../interfaces/ISuperValidator.sol";

/// @title RelayAdapter
/// @author Superform Labs
/// @notice Optional destination-side adapter for Relay Protocol fills. Relay has no receiver-callback:
/// @notice solvers execute the quote's txs[] atomically (allowFailure = false) with msg.sender being
/// @notice Relay's router — never an authenticatable bridge contract. The primary integration path is
/// @notice the solver calling SuperDestinationExecutor.processBridgedExecution directly; this adapter
/// @notice is the robustness path providing atomic forward + failed-transfer self-claim.
/// @notice Message uses the compact 2-field format: abi.encode(initData, sigData), identical to
/// @notice AcrossV3AdapterV2 — sigData is forwarded byte-identical so validator signatures stay valid.
/// @dev PERMISSIONLESS: anyone can call processRelayExecution. Safety is anchored by the executor's
///      signed-intent + balance validation, plus two adapter-local guards that Across does not need
///      (its SpokePool msg.sender check vouches for `amount`):
///      1. INSUFFICIENT_FUNDS_RECEIVED — the claimed `amount` must actually be held by the adapter
///         (excluding escrowed failed transfers), blocking phantom failedTransfers credits.
///      2. totalEscrowed — failed-transfer escrow is excluded from the spendable balance, blocking
///         redirection of other users' escrowed funds via a self-signed valid intent.
/// @dev TRUST ASSUMPTION (documented, accepted): funds parked in the adapter between two SEPARATE
///      solver transactions (a deviation from Relay's atomic-batch protocol) are forwardable by any
///      caller presenting a validly-signed message for their own account until the legitimate second
///      leg lands. The bundler MUST always request fund delivery and the adapter call as one atomic
///      txs[] batch, which Relay's router guarantees via allowFailure = false.
/// @dev token address(0) represents native ETH throughout (delivery, failed transfers, claims).
contract RelayAdapter is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The SuperDestinationExecutor for processing bridged executions
    ISuperDestinationExecutor public immutable SUPER_DESTINATION_EXECUTOR;

    /// @notice Claimable balances for failed token transfers: account => token => amount
    /// @dev token address(0) represents native ETH
    mapping(address account => mapping(address token => uint256 amount)) public failedTransfers;

    /// @notice Total amount per token currently escrowed in failedTransfers
    /// @dev Excluded from the spendable balance in processRelayExecution so permissionless callers
    ///      can never forward other users' escrowed funds
    mapping(address token => uint256 amount) public totalEscrowed;

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
    /// @dev Reverting is safe: Relay fills are independent txs, and inside an atomic solver batch
    ///      the revert also unwinds the funds-delivery leg
    error NO_DST_PROOF_FOR_CHAIN();

    /// @notice Thrown when the extracted account is the zero address
    error ACCOUNT_NOT_VALID();

    /// @notice Thrown when the adapter does not hold `amount` of the claimed token beyond escrow
    /// @dev The permissionless-caller guard — `amount` is only honored if the funds are provably here
    error INSUFFICIENT_FUNDS_RECEIVED();

    /// @notice Thrown when sending msg.value together with an ERC20 tokenSent
    error MSG_VALUE_NOT_ALLOWED();

    /// @notice Thrown when claiming more than the available failed transfer balance
    error INSUFFICIENT_FAILED_BALANCE();

    /// @notice Thrown when the amount is zero
    error ZERO_AMOUNT();

    /// @notice Thrown when a native claim transfer fails
    error ETH_TRANSFER_FAILED();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when token transfer to the account succeeds
    /// @param account The target account that received the tokens
    /// @param tokenSent The token address transferred (address(0) for native ETH)
    /// @param amount The amount of tokens transferred
    event TransferSucceeded(address indexed account, address indexed tokenSent, uint256 amount);

    /// @notice Emitted when token transfer to the account fails
    /// @param account The intended recipient
    /// @param token The token that failed to transfer (address(0) for native ETH)
    /// @param amount The amount stored for manual claim
    event TransferFailed(address indexed account, address indexed token, uint256 amount);

    /// @notice Emitted when the executor call fails but tokens were already transferred to the account
    /// @param account The account that received tokens but whose execution failed
    event ExecutionFailed(address indexed account);

    /// @notice Emitted when a user claims their failed transfer
    /// @param account The account claiming funds
    /// @param token The token claimed (address(0) for native ETH)
    /// @param amount The amount claimed
    event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address superDestinationExecutor_) {
        if (superDestinationExecutor_ == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        SUPER_DESTINATION_EXECUTOR = ISuperDestinationExecutor(superDestinationExecutor_);
    }

    /// @notice Accepts native pre-funding by the solver in a prior call of the atomic batch
    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                            RELAY EXECUTION LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Forwards Relay-filled funds to the intent account and best-effort executes the signed intent
    /// @dev Permissionless — see contract-level NatSpec for the guards that make this safe.
    ///      Native funds may arrive as msg.value on this call or be pre-funded via receive() in a
    ///      prior call of the same atomic batch.
    /// @param tokenSent The output token delivered by the Relay fill (address(0) for native ETH)
    /// @param amount The amount delivered for this intent
    /// @param message abi.encode(bytes initData, bytes sigData) — compact 2-field V2 format
    function processRelayExecution(
        address tokenSent,
        uint256 amount,
        bytes calldata message
    )
        external
        payable
        nonReentrant
    {
        // 1. Validate amount and msg.value consistency
        if (amount == 0) revert ZERO_AMOUNT();
        if (tokenSent != address(0) && msg.value != 0) revert MSG_VALUE_NOT_ALLOWED();

        // 2. Decode compact 2-field format (initData, sigData)
        (bytes memory initData, bytes memory sigDataRaw) = abi.decode(message, (bytes, bytes));

        // 3. Extract account, executorCalldata, dstTokens, intentAmounts from sigData
        ExtractedData memory extracted = _extractFromSigData(sigDataRaw);

        // 4. Revert when no DstProof matches current chain — fills are independent, and inside an
        //    atomic solver batch the revert unwinds the funds-delivery leg too
        if (!extracted.found) {
            revert NO_DST_PROOF_FOR_CHAIN();
        }

        // 5. Revert when account is zero address
        //    Prevents crediting unclaimable failedTransfers[address(0)] and burning native funds.
        if (extracted.account == address(0)) {
            revert ACCOUNT_NOT_VALID();
        }

        // 6. Permissionless-caller guard: the claimed amount must actually be held by the adapter,
        //    excluding funds escrowed for other users' failed transfers
        uint256 balance =
            tokenSent == address(0) ? address(this).balance : IERC20(tokenSent).balanceOf(address(this));
        if (balance - totalEscrowed[tokenSent] < amount) {
            revert INSUFFICIENT_FUNDS_RECEIVED();
        }

        // 7. Transfer received funds to the target account
        bool transferSuccess = _tryTransfer(tokenSent, extracted.account, amount);

        if (!transferSuccess) {
            failedTransfers[extracted.account][tokenSent] += amount;
            totalEscrowed[tokenSent] += amount;
            emit TransferFailed(extracted.account, tokenSent, amount);
        } else {
            emit TransferSucceeded(extracted.account, tokenSent, amount);
        }

        // 8. Best-effort execution — call the core executor
        //    catch binds no variable so revert returndata is never copied (returnbomb-safe)
        try SUPER_DESTINATION_EXECUTOR.processBridgedExecution(
            tokenSent,
            extracted.account,
            extracted.dstTokens,
            extracted.intentAmounts,
            initData,
            extracted.executorCalldata,
            sigDataRaw
        ) { } catch {
            emit ExecutionFailed(extracted.account);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            CLAIM LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Claim tokens from a failed transfer
    /// @dev Only the intended recipient (account) can claim their own failed transfers
    /// @param token The token to claim (address(0) for native ETH)
    /// @param amount The amount to claim
    function claimFailedTransfer(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZERO_AMOUNT();

        uint256 available = failedTransfers[msg.sender][token];
        if (available < amount) revert INSUFFICIENT_FAILED_BALANCE();

        failedTransfers[msg.sender][token] = available - amount;
        totalEscrowed[token] -= amount;

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
