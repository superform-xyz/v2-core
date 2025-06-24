// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// External
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { ISuperHook, ISuperHookSetter, ISuperHookContextAware, ISuperHookResult } from "../interfaces/ISuperHook.sol";

import { console2 } from "forge-std/console2.sol";

/// @title BaseHook
/// @author Superform Labs
/// @notice Base implementation for all hooks in the Superform system
/// @dev Provides core security validation and execution flow management for hooks
///      All specialized hooks should inherit from this base contract
///      Implements the ISuperHook interface defined lifecycle methods
///      Uses a transient storage pattern for stateful execution context
abstract contract BaseHook is ISuperHook, ISuperHookSetter, ISuperHookResult {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    /// @notice The output amount produced by this hook's execution
    /// @dev Set during postExecute, used by subsequent hooks in the chain
    uint256 public transient outAmount;

    /// @notice The number of shares used by this hook's operation
    /// @dev Used for accounting and tracking consumption of position shares
    uint256 public transient usedShares;

    /// @notice The special token address (if any) associated with this hook's operation
    /// @dev May be used to track token addresses for various operations
    address public transient spToken;

    /// @notice The primary asset address this hook operates on
    /// @dev Typically the base token or asset being processed
    address public transient asset;

    /// @notice The vault bank address (if applicable) for cross-chain operations
    /// @dev Used primarily in bridge hooks to track source/destination vault banks
    address public transient vaultBank;

    /// @notice The destination chain ID for cross-chain operations
    /// @dev Used primarily in bridge hooks to track target chain
    uint256 public transient dstChainId;

    /// @notice PreExecute protection: false=callable, true=already_called
    bool public transient preExecuteMutex;

    /// @notice PostExecute protection: false=callable, true=already_called
    bool public transient postExecuteMutex;

    /// @notice Execution nonce for creating unique contexts
    uint256 private transient executionNonce;

    // Storage offsets for different state variables
    uint256 private constant OUT_AMOUNT_OFFSET = 1;
    uint256 private constant PRE_EXECUTE_MUTEX_OFFSET = 2;
    uint256 private constant POST_EXECUTE_MUTEX_OFFSET = 3;

    /// @notice Base storage key for hook execution state
    bytes32 private constant HOOK_EXECUTION_STORAGE = keccak256("hook.execution.state");

    /// @notice Storage key for account context mapping
    bytes32 private constant ACCOUNT_CONTEXT_STORAGE = keccak256("hook.account.context");

    /// @notice The specific subtype identifier for this hook
    /// @dev Used to identify specialized hook types beyond the basic HookType enum
    bytes32 public immutable subType;

    /// @notice The type of hook (NONACCOUNTING, INFLOW, OUTFLOW)
    /// @dev Determines how the hook impacts accounting in the system
    ISuperHook.HookType public hookType;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when a caller attempts to execute hook methods without proper authorization
    /// @dev Used by security validation to prevent unauthorized hook execution
    error NOT_AUTHORIZED();

    /// @notice Thrown when an amount parameter is invalid (e.g., zero or overflow)
    /// @dev Used in validation checks for asset amounts and share values
    error AMOUNT_NOT_VALID();

    /// @notice Thrown when an address parameter is invalid (e.g., zero address)
    /// @dev Used in validation checks for tokens, accounts, and other addresses
    error ADDRESS_NOT_VALID();

    /// @notice Thrown when the provided data payload is too short for decoding
    /// @dev Used when validating and parsing hook-specific data parameters
    error DATA_LENGTH_INSUFFICIENT();

    /// @notice Thrown when a caller is not authorized to execute hook methods
    /// @dev Used by security validation to prevent unauthorized hook execution
    error UNAUTHORIZED_CALLER();

    /// @notice Thrown when preExecute is called more than once
    /// @dev Used to prevent reentrancy attacks and ensure proper execution flow
    error PRE_EXECUTE_ALREADY_CALLED();

    /// @notice Thrown when postExecute is called more than once
    /// @dev Used to prevent reentrancy attacks and ensure proper execution flow
    error POST_EXECUTE_ALREADY_CALLED();

    /// @notice Thrown when a hook execution is incomplete
    /// @dev Used to prevent incomplete hook execution
    error INCOMPLETE_HOOK_EXECUTION();

    /// @notice Initializes the hook with its type and subtype
    /// @dev Sets immutable parameters that define the hook's behavior
    /// @param hookType_ The type classification for this hook (NONACCOUNTING, INFLOW, OUTFLOW)
    /// @param subType_ The specific subtype identifier for specialized hook functionality
    constructor(ISuperHook.HookType hookType_, bytes32 subType_) {
        hookType = hookType_;
        subType = subType_;
    }

    /*//////////////////////////////////////////////////////////////
                          EXECUTION SECURITY
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function setExecutionContext(address caller, bytes calldata hookData) external {
        uint256 context = _createExecutionContext(caller, hookData);

        console2.log("caller", caller);
        console2.log("CONTEXT SET CALLER", context);
    }

    /// @dev Standard build pattern - MUST include preExecute first, postExecute last
    /// @inheritdoc ISuperHook
    function build(
        address prevHook,
        address account,
        bytes calldata hookData
    )
        external
        view
        virtual
        returns (Execution[] memory executions)
    {
        // Get hook-specific executions
        Execution[] memory hookExecutions = _buildHookExecutions(prevHook, account, hookData);

        // Always include pre + hook + post
        executions = new Execution[](hookExecutions.length + 2);

        // FIRST: preExecute
        executions[0] = Execution({
            target: address(this),
            value: 0,
            callData: abi.encodeCall(this.preExecute, (prevHook, account, hookData))
        });

        // MIDDLE: hook-specific operations
        for (uint256 i = 0; i < hookExecutions.length; i++) {
            executions[i + 1] = hookExecutions[i];
        }

        // LAST: postExecute
        executions[executions.length - 1] = Execution({
            target: address(this),
            value: 0,
            callData: abi.encodeCall(this.postExecute, (prevHook, account, hookData))
        });
    }

    /// @inheritdoc ISuperHook
    function preExecute(address prevHook, address account, bytes calldata data) external {
        if (msg.sender != account) revert UNAUTHORIZED_CALLER();
        uint256 context = _getCurrentExecutionContext(account);
        if (_getPreExecuteMutex(context)) revert PRE_EXECUTE_ALREADY_CALLED();
        _setPreExecuteMutex(context, true);
        _preExecute(prevHook, account, data);
        console2.log("caller", account);

        console2.log("CONTEXT PRE EXECUTE", context);
    }

    /// @inheritdoc ISuperHook
    function postExecute(address prevHook, address account, bytes calldata data) external {
        if (msg.sender != account) revert UNAUTHORIZED_CALLER();
        uint256 context = _getCurrentExecutionContext(account);
        if (_getPostExecuteMutex(context)) revert POST_EXECUTE_ALREADY_CALLED();
        _setPostExecuteMutex(context, true);
        _postExecute(prevHook, account, data);
        console2.log("caller", account);

        console2.log("CONTEXT POST EXECUTE", context);
    }

    /// @inheritdoc ISuperHookSetter
    function setOutAmount(uint256 _outAmount, address caller) external {
        uint256 context = _getCurrentExecutionContext(caller);
        _setOutAmount(context, _outAmount);
        console2.log("caller", caller);

        console2.log("CONTEXT SET OUT AMOUNT", context);
    }

    /// @inheritdoc ISuperHook
    function resetExecutionState(address caller) external {
        uint256 context = _getCurrentExecutionContext(caller);
        console2.log("caller", caller);

        console2.log("CONTEXT RESET EXECUTION STATE", context);
        if (!_getPreExecuteMutex(context) || !_getPostExecuteMutex(context)) {
            revert INCOMPLETE_HOOK_EXECUTION();
        }
        _clearExecutionState(context);

        /*
        // Clear the account's context
        bytes32 key = _makeAccountContextKey(caller);
        assembly {
            tstore(key, 0)
        }
        */
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function subtype() external view returns (bytes32) {
        return subType;
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Internal implementation of build
    /// @dev Abstract function to be implemented by derived hooks
    ///      Called during build to generate hook-specific execution sequences
    /// @param prevHook The previous hook in the chain, or address(0) if first hook
    /// @param account The account that operations will be performed for
    /// @param data Hook-specific parameters and configuration data
    /// @return executions Array of execution objects containing target, value, and callData
    function _buildHookExecutions(
        address prevHook,
        address account,
        bytes calldata data
    )
        internal
        view
        virtual
        returns (Execution[] memory executions);

    /// @notice Internal implementation of preExecute
    /// @dev Abstract function to be implemented by derived hooks
    ///      Called before execution to validate inputs and prepare the hook's state
    ///      Typically sets up the hook context by parsing parameters from data
    ///      May check balances, permissions, or other preconditions
    /// @param prevHook The previous hook in the chain, or address(0) if first hook
    /// @param account The account that operations will be performed for
    /// @param data Hook-specific parameters and configuration data
    function _preExecute(address prevHook, address account, bytes calldata data) internal virtual;

    /// @notice Internal implementation of postExecute
    /// @dev Abstract function to be implemented by derived hooks
    ///      Called after execution to finalize the hook's state and set output values
    ///      Typically calculates final results and sets outAmount, usedShares, etc.
    ///      May perform additional validations on execution results
    /// @param prevHook The previous hook in the chain, or address(0) if first hook
    /// @param account The account operations were performed for
    /// @param data Hook-specific parameters and configuration data
    function _postExecute(address prevHook, address account, bytes calldata data) internal virtual;

    /// @notice Decodes a boolean value from a byte array at the specified offset
    /// @dev Helper function for extracting boolean values from packed data
    ///      Used when parsing hook-specific data parameters
    /// @param data The byte array containing the encoded data
    /// @param offset The position in the array to read from
    /// @return The decoded boolean value (true if byte is non-zero)
    function _decodeBool(bytes memory data, uint256 offset) internal pure returns (bool) {
        return data[offset] != 0;
    }

    /// @notice Replaces an amount value within a byte array at the specified offset
    /// @dev Used to modify hook calldata for amount adjustments without full re-encoding
    ///      Particularly useful for modifying amounts in multi-hook execution chains
    ///      Directly modifies the bytes in-place for gas efficiency
    /// @param data The original byte array containing encoded calldata
    /// @param amount The new amount value to insert
    /// @param offset The position in the array where the amount starts
    /// @return The modified byte array with the replaced amount
    function _replaceCalldataAmount(
        bytes memory data,
        uint256 amount,
        uint256 offset
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory newAmountEncoded = abi.encodePacked(amount);
        for (uint256 i; i < 32; ++i) {
            data[offset + i] = newAmountEncoded[i];
        }
        return data;
    }

    function _makeAccountContextKey(address account) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(ACCOUNT_CONTEXT_STORAGE, account));
    }

    function _createExecutionContext(address caller, bytes calldata hookData) private returns (uint256) {
        bytes32 key = _makeAccountContextKey(caller);

        // Check if this hook should use previous execution context for chaining
        bool shouldUsePreviousOutput;

        // only grab usePrevHookAmount if hookData is not empty (used for when hooks are used standalone outside of
        // 7579 execution and we always want new execution contexts)
        if (hookData.length > 0) {
            shouldUsePreviousOutput = _shouldUsePreviousOutput(hookData);
        }

        console2.log("shouldUsePreviousOutput", shouldUsePreviousOutput);

        if (shouldUsePreviousOutput) {
            // Get existing context for caller
            uint256 existingContext;
            assembly {
                existingContext := tload(key)
            }

            console2.log("existingContext", existingContext);

            // If we have an existing context, reuse it for chaining
            if (existingContext != 0) {
                return existingContext;
            }
            // If no existing context, fall through to create new one
        }

        // Always increment nonce for new execution context
        executionNonce++;

        // Store this context for the current caller
        uint256 currentNonce = executionNonce; // Load into local variable for assembly
        assembly {
            tstore(key, currentNonce)
        }

        return executionNonce;
    }

    function _getCurrentExecutionContext(address caller) private view returns (uint256 context) {
        bytes32 key = _makeAccountContextKey(caller);
        assembly {
            context := tload(key)
        }
    }

    function _makeKey(uint256 context, uint256 offset) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(HOOK_EXECUTION_STORAGE, context, offset));
    }

    function _getOutAmount(uint256 context) private view returns (uint256 value) {
        bytes32 key = _makeKey(context, OUT_AMOUNT_OFFSET);
        assembly {
            value := tload(key)
        }
    }

    function _setOutAmount(uint256 context, uint256 value) private {
        bytes32 key = _makeKey(context, OUT_AMOUNT_OFFSET);
        assembly {
            tstore(key, value)
        }
    }

    function _getPreExecuteMutex(uint256 context) private view returns (bool value) {
        bytes32 key = _makeKey(context, PRE_EXECUTE_MUTEX_OFFSET);
        assembly {
            value := tload(key)
        }
    }

    function _setPreExecuteMutex(uint256 context, bool value) private {
        bytes32 key = _makeKey(context, PRE_EXECUTE_MUTEX_OFFSET);
        assembly {
            tstore(key, value)
        }
    }

    function _getPostExecuteMutex(uint256 context) private view returns (bool value) {
        bytes32 key = _makeKey(context, POST_EXECUTE_MUTEX_OFFSET);
        assembly {
            value := tload(key)
        }
    }

    function _setPostExecuteMutex(uint256 context, bool value) private {
        bytes32 key = _makeKey(context, POST_EXECUTE_MUTEX_OFFSET);
        assembly {
            tstore(key, value)
        }
    }

    function _clearExecutionState(uint256 context) private {
        _setPreExecuteMutex(context, false);
        _setPostExecuteMutex(context, false);
    }

    function _shouldUsePreviousOutput(bytes calldata hookData) private view returns (bool) {
        try ISuperHookContextAware(address(this)).decodeUsePrevHookAmount(hookData) returns (bool usePrevHookAmount) {
            return usePrevHookAmount;
        } catch {
            return false;
        }
    }
}
