// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// External
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { ISuperHook, ISuperHookSetter } from "../interfaces/ISuperHook.sol";

/// @title BaseHook
/// @author Superform Labs
/// @notice Base implementation for all hooks in the Superform system
/// @dev Provides core security validation and execution flow management for hooks
///      All specialized hooks should inherit from this base contract
///      Implements the ISuperHook interface defined lifecycle methods
///      Uses a transient storage pattern for stateful execution context
abstract contract BaseHook is ISuperHook, ISuperHookSetter {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    // forgefmt: disable-start
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
    
    /// @notice The address that initiated the first execution in the hook chain
    /// @dev Used for security validation between preExecute and postExecute calls
    address public transient lastExecutionCaller;

    /// @notice The vault bank address (if applicable) for cross-chain operations
    /// @dev Used primarily in bridge hooks to track source/destination vault banks
    address public transient vaultBank;
    
    /// @notice The destination chain ID for cross-chain operations
    /// @dev Used primarily in bridge hooks to track target chain
    uint256 public transient dstChainId;

    // forgefmt: disable-end

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

    /// @notice Retrieves the address that initiated the current execution context
    /// @dev Implemented as an external view function to allow for test mocking
    ///      Used by the security validation system to enforce caller consistency
    /// @return The address stored as the lastExecutionCaller
    function getExecutionCaller() public view returns (address) {
        return lastExecutionCaller;
    }

    /// @inheritdoc ISuperHook
    function build(address prevHook, address account, bytes calldata data) external view virtual returns (Execution[] memory executions) {}
    
    /// @inheritdoc ISuperHook
    function preExecute(address prevHook, address account, bytes calldata data) external  {
        _validateCaller();
        _preExecute(prevHook, account, data);
    }
    
    /// @inheritdoc ISuperHook
    function postExecute(address prevHook, address account, bytes calldata data) external  {
        _validateCaller();
        _postExecute(prevHook, account, data);
    }

    /// @inheritdoc ISuperHookSetter
    function setOutAmount(uint256 _outAmount) external {
        _validateCaller();
        outAmount = _outAmount;
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
    /// @notice Validates that the caller has permission to execute hook methods
    /// @dev Implements a security pattern to ensure consistent caller identity throughout execution
    ///      On first call (when lastExecutionCaller is unset), records the caller identity
    ///      On subsequent calls, enforces that the same address is calling
    ///      This prevents unauthorized addresses from interfering with ongoing hook execution
    function _validateCaller() internal {
        // Get the current execution context caller (via the external function for test mockability)
        address caller = this.getExecutionCaller();

        // First call in this transaction - allow it and set the caller
        if (caller == address(0)) {
            lastExecutionCaller = msg.sender;
            return;
        }
        
        // Subsequent calls must be from the same caller that initiated execution
        if (msg.sender == caller) {
            return;
        }
        
        // If we already had a different caller and now we're trying to call from another address, reject
        revert NOT_AUTHORIZED();
    }

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
    function _replaceCalldataAmount(bytes memory data, uint256 amount, uint256 offset) internal pure returns (bytes memory) {
        bytes memory newAmountEncoded = abi.encodePacked(amount);
        for (uint256 i; i < 32; ++i) {
            data[offset + i] = newAmountEncoded[i];
        }
        return data;
    }   
}
