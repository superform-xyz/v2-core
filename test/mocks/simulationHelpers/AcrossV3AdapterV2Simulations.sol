// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External Dependencies
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Protocol Interfaces
import { IAcrossV3Receiver } from "../../../src/vendor/bridges/across/IAcrossV3Receiver.sol";

// Superform Interfaces
import { IDestinationValidatorSource } from "../../../src/adapters/AcrossV3AdapterV2.sol";
import { ISuperDestinationExecutor } from "../../../src/interfaces/ISuperDestinationExecutor.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";

/// @title AcrossV3AdapterV2Simulations
/// @author Superform Labs
/// @notice Strict simulation equivalent of AcrossV3AdapterV2
/// @dev This contract is never deployed. Its runtime is installed at a live Across adapter
///      with a state override after its constructor-configured immutables are patched.
///      The success path mirrors the production V2 adapter, while transfer and destination
///      execution failures revert so eth_estimateGas cannot accept a best-effort failure path.
contract AcrossV3AdapterV2Simulations is IAcrossV3Receiver {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The Across SpokePool address
    address public immutable ACROSS_SPOKE_POOL;

    /// @notice The SuperDestinationExecutor for processing bridged executions
    ISuperDestinationExecutor public immutable SUPER_DESTINATION_EXECUTOR;

    /// @notice The SuperDestinationValidator the executor is wired to
    address public immutable SUPER_DESTINATION_VALIDATOR;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Holds fields extracted from sigData's destination proof
    struct ExtractedData {
        address account;
        address executor;
        address validator;
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
    error EXECUTOR_NOT_VALID();
    error VALIDATOR_NOT_VALID();
    error TRANSFER_FAILED();
    error DESTINATION_EXECUTION_FAILED();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TransferSucceeded(address indexed account, address indexed token, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

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
    function handleV3AcrossMessage(address tokenSent, uint256 amount, address, bytes memory message) external override {
        if (msg.sender != ACROSS_SPOKE_POOL) revert INVALID_SENDER();

        (bytes memory initData, bytes memory sigDataRaw) = abi.decode(message, (bytes, bytes));
        ExtractedData memory extracted = _extractFromSigData(sigDataRaw);

        if (!extracted.found) revert NO_DST_PROOF_FOR_CHAIN();
        if (extracted.account == address(0)) revert ACCOUNT_NOT_VALID();
        if (extracted.executor != address(SUPER_DESTINATION_EXECUTOR)) revert EXECUTOR_NOT_VALID();
        if (extracted.validator != SUPER_DESTINATION_VALIDATOR) revert VALIDATOR_NOT_VALID();
        if (!IERC20(tokenSent).trySafeTransfer(extracted.account, amount)) revert TRANSFER_FAILED();

        emit TransferSucceeded(extracted.account, tokenSent, amount);

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
        catch (bytes memory reason) {
            _revert(reason);
        }
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

    /// @notice Bubbles a destination executor failure without changing its revert selector
    function _revert(bytes memory reason) private pure {
        if (reason.length == 0) revert DESTINATION_EXECUTION_FAILED();
        assembly ("memory-safe") {
            revert(add(reason, 0x20), mload(reason))
        }
    }
}
