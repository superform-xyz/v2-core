// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External Dependencies
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Protocol Interfaces
import { IAcrossV3Receiver } from "../../../src/vendor/bridges/across/IAcrossV3Receiver.sol";

// Superform Interfaces
import { ISuperDestinationExecutor } from "../../../src/interfaces/ISuperDestinationExecutor.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";

/// @title AcrossV3AdapterV2Simulations
/// @author Superform Labs
/// @notice Strict simulation equivalent of AcrossV3AdapterV2
/// @dev This contract is never deployed. Its runtime is installed at a live Across adapter
///      with a state override after its constructor-configured immutables are patched.
///      The success path mirrors the production V2 adapter, while transfer and destination
///      execution failures revert so eth_estimateGas cannot accept a best-effort failure path.
contract AcrossV3AdapterV2Simulations is IAcrossV3Receiver, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The Across SpokePool address
    address public immutable ACROSS_SPOKE_POOL;

    /// @notice The SuperDestinationExecutor for processing bridged executions
    ISuperDestinationExecutor public immutable SUPER_DESTINATION_EXECUTOR;

    /// @notice Claimable balances for failed token transfers
    /// @dev Must remain in the same storage position as AcrossV3AdapterV2
    mapping(address account => mapping(address token => uint256 amount)) public failedTransfers;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Holds fields extracted from sigData's destination proof
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

    error ADDRESS_NOT_VALID();
    error NO_DST_PROOF_FOR_CHAIN();
    error ACCOUNT_NOT_VALID();
    error TRANSFER_FAILED();
    error DESTINATION_EXECUTION_FAILED();
    error INSUFFICIENT_FAILED_BALANCE();
    error ZERO_AMOUNT();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TransferSucceeded(address indexed account, address indexed tokenSent, uint256 amount);
    event TransferFailed(address indexed account, address indexed token, uint256 amount);
    event ExecutionFailed(address indexed account);
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
        address,
        bytes memory message
    )
        external
        override
    {
        if (msg.sender != ACROSS_SPOKE_POOL) revert INVALID_SENDER();

        (bytes memory initData, bytes memory sigDataRaw) = abi.decode(message, (bytes, bytes));
        ExtractedData memory extracted = _extractFromSigData(sigDataRaw);

        if (!extracted.found) revert NO_DST_PROOF_FOR_CHAIN();
        if (extracted.account == address(0)) revert ACCOUNT_NOT_VALID();
        if (!_tryTransfer(tokenSent, extracted.account, amount)) revert TRANSFER_FAILED();

        emit TransferSucceeded(extracted.account, tokenSent, amount);

        try SUPER_DESTINATION_EXECUTOR.processBridgedExecution(
            tokenSent,
            extracted.account,
            extracted.dstTokens,
            extracted.intentAmounts,
            initData,
            extracted.executorCalldata,
            sigDataRaw
        ) { }
        catch (bytes memory reason) {
            _revert(reason);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                CLAIM LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Claims tokens recorded by the live adapter before the code override
    /// @dev Included to preserve the production adapter's storage and callable surface
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

    /// @notice Extracts destination execution fields for the current chain
    function _extractFromSigData(bytes memory sigDataRaw) internal view returns (ExtractedData memory extracted) {
        (,,,,, ISuperValidator.DstProof[] memory proofDst,) =
            abi.decode(sigDataRaw, (uint64[], uint48, uint48, bytes32, bytes32[], ISuperValidator.DstProof[], bytes));

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

    /// @notice Attempts the same low-level ERC20 transfer as AcrossV3AdapterV2
    function _tryTransfer(address token, address account, uint256 amount) internal returns (bool success) {
        (bool callSuccess, bytes memory returnData) = token.call(abi.encodeCall(IERC20.transfer, (account, amount)));
        success = callSuccess && (returnData.length == 0 || abi.decode(returnData, (bool)));
    }

    /// @notice Bubbles a destination executor failure without changing its revert selector
    function _revert(bytes memory reason) private pure {
        if (reason.length == 0) revert DESTINATION_EXECUTION_FAILED();
        assembly ("memory-safe") {
            revert(add(reason, 0x20), mload(reason))
        }
    }
}
