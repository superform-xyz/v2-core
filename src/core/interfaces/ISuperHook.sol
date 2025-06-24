// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

/**
 * @title SuperHook System
 * @author Superform Labs
 * @notice The hook system provides a modular and composable way to execute operations on assets
 * @dev The hook system architecture consists of several interfaces that work together:
 *      - ISuperHook: The base interface all hooks implement, with lifecycle methods
 *      - ISuperHookResult: Provides execution results and output information
 *      - Specialized interfaces (ISuperHookOutflow, ISuperHookLoans, etc.) for specific behaviors
 *
 * Hooks are executed in sequence, where each hook can access the results from previous hooks.
 * The three main types of hooks are:
 *      - NONACCOUNTING: Utility hooks that don't update the accounting system
 *      - INFLOW: Hooks that process deposits or additions to positions
 *      - OUTFLOW: Hooks that process withdrawals or reductions to positions
 */
interface ISuperHookSetter {
    /// @notice Sets the output amount for the hook
    /// @dev Used for updating `outAmount` when fees were deducted
    /// @param outAmount The amount of tokens processed by the hook
    /// @param caller The caller address for context identification
    function setOutAmount(uint256 outAmount, address caller) external;
}
/// @title ISuperHookInspector
/// @author Superform Labs
/// @notice Interface for the SuperHookInspector contract that manages hook inspection

interface ISuperHookInspector {
    /// @notice Inspect the hook
    /// @param data The hook data to inspect
    /// @return argsEncoded The arguments of the hook encoded
    function inspect(bytes calldata data) external view returns (bytes memory argsEncoded);
}

/// @title ISuperHookResult
/// @author Superform Labs
/// @notice Interface that exposes the result of a hook execution
/// @dev All hooks must implement this interface to provide standardized access to execution results.
///      These results are used by subsequent hooks in the execution chain and by the executor.
interface ISuperHookResult {
    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice The amount of tokens processed by the hook
    /// @dev This is the primary output value used by subsequent hooks and for accounting
    /// @return The amount of tokens (assets or shares) processed
    function outAmount() external view returns (uint256);

    /// @notice The type of hook
    /// @dev Used to determine how accounting should process this hook's results
    /// @return The hook type (NONACCOUNTING, INFLOW, or OUTFLOW)
    function hookType() external view returns (ISuperHook.HookType);

    /// @notice The SuperPosition (SP) token associated with this hook
    /// @dev For vault hooks, this would be the tokenized position representing shares
    /// @return The address of the SP token, or address(0) if not applicable
    function spToken() external view returns (address);

    /// @notice The underlying asset token being processed
    /// @dev For most hooks, this is the actual token being deposited or withdrawn
    /// @return The address of the asset token, or address(0) for native assets
    function asset() external view returns (address);

    /// @notice The vault bank address used to lock SuperPositions
    /// @dev Only relevant for cross-chain operations where positions are locked
    /// @return The vault bank address, or address(0) if not applicable
    function vaultBank() external view returns (address);

    /// @notice The destination chain ID for cross-chain operations
    /// @dev Used to identify the target chain for cross-chain position transfers
    /// @return The destination chain ID, or 0 if not a cross-chain operation
    function dstChainId() external view returns (uint256);
}

/// @title ISuperHookContextAware
/// @author Superform Labs
/// @notice Interface for hooks that can use previous hook results in their execution
/// @dev Enables contextual awareness and data flow between hooks in a chain
interface ISuperHookContextAware {
    /// @notice Determines if this hook should use the amount from the previous hook
    /// @dev Used to create hook chains where output from one hook becomes input to the next
    /// @param data The hook-specific data containing configuration
    /// @return True if the hook should use the previous hook's output amount
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool);
}

/// @title ISuperHookInflowOutflow
/// @author Superform Labs
/// @notice Interface for hooks that handle both inflows and outflows
/// @dev Provides standardized amount extraction for both deposit and withdrawal operations
interface ISuperHookInflowOutflow {
    /// @notice Extracts the amount from the hook's calldata
    /// @dev Used to determine the quantity of assets or shares being processed
    /// @param data The hook-specific calldata containing the amount
    /// @return The amount of tokens to process
    function decodeAmount(bytes memory data) external pure returns (uint256);
}

/// @title ISuperHookOutflow
/// @author Superform Labs
/// @notice Interface for hooks that specifically handle outflows (withdrawals)
/// @dev Provides additional functionality needed only for outflow operations
interface ISuperHookOutflow {
    /// @notice Replace the amount in the calldata
    /// @param data The data to replace the amount in
    /// @param amount The amount to replace
    /// @return data The data with the replaced amount
    function replaceCalldataAmount(bytes memory data, uint256 amount) external pure returns (bytes memory);
}

/// @title ISuperHookResultOutflow
/// @author Superform Labs
/// @notice Extended result interface for outflow hook operations
/// @dev Extends the base result interface with outflow-specific information
interface ISuperHookResultOutflow is ISuperHookResult {
    /// @notice The amount of shares consumed during outflow processing
    /// @dev Used for cost basis calculation in the accounting system
    /// @return The amount of shares consumed from the user's position
    function usedShares() external view returns (uint256);
}

/// @title ISuperHookAsync
/// @author Superform Labs
/// @notice Interface for hooks that perform asynchronous operations
/// @dev Used for operations that may complete in a separate transaction
interface ISuperHookAsync {
    /// @notice Retrieves the amount of assets or shares processed asynchronously
    /// @dev Used to track the quantities involved in pending async operations
    /// @return amount The amount of tokens processed
    /// @return isShares True if the amount represents shares, false if it represents assets
    function getUsedAssetsOrShares() external view returns (uint256 amount, bool isShares);
}

/// @title ISuperHookLoans
/// @author Superform Labs
/// @notice Interface for hooks that interact with lending protocols
/// @dev Extends context awareness to enable loan operations within hook chains
interface ISuperHookLoans is ISuperHookContextAware {
    /// @notice Gets the address of the token being borrowed
    /// @dev Used to identify which asset is being borrowed from the lending protocol
    /// @param data The hook-specific data containing loan information
    /// @return The address of the borrowed token
    function getLoanTokenAddress(bytes memory data) external view returns (address);

    /// @notice Gets the address of the token used as collateral
    /// @dev Used to identify which asset is being used to secure the loan
    /// @param data The hook-specific data containing collateral information
    /// @return The address of the collateral token
    function getCollateralTokenAddress(bytes memory data) external view returns (address);

    /// @notice Gets the current loan token balance for an account
    /// @dev Used to track outstanding loan amounts
    /// @param account The account to check the loan balance for
    /// @param data The hook-specific data containing loan parameters
    /// @return The amount of tokens currently borrowed
    function getLoanTokenBalance(address account, bytes memory data) external view returns (uint256);

    /// @notice Gets the current collateral token balance for an account
    /// @dev Used to track collateral positions
    /// @param account The account to check the collateral balance for
    /// @param data The hook-specific data containing collateral parameters
    /// @return The amount of tokens currently used as collateral
    function getCollateralTokenBalance(address account, bytes memory data) external view returns (uint256);
}

/// @title ISuperHookAsyncCancelations
/// @author Superform Labs
/// @notice Interface for hooks that can cancel asynchronous operations
/// @dev Used to handle cancellation of pending operations that haven't completed
interface ISuperHookAsyncCancelations {
    /// @notice Types of cancellations that can be performed
    /// @dev Distinguishes between different operation types that can be canceled
    enum CancelationType {
        NONE, // Not a cancelation hook
        INFLOW, // Cancels a pending deposit operation
        OUTFLOW // Cancels a pending withdrawal operation

    }

    /// @notice Identifies the type of async operation this hook can cancel
    /// @dev Used to verify the hook is appropriate for the operation being canceled
    /// @return asyncType The type of cancellation this hook performs
    function isAsyncCancelHook() external pure returns (CancelationType asyncType);
}

/// @title ISuperHook
/// @author Superform Labs
/// @notice The core hook interface that all hooks must implement
/// @dev Defines the lifecycle methods and execution flow for the hook system
///      Hooks are executed in sequence with results passed between them
interface ISuperHook {
    /*//////////////////////////////////////////////////////////////

                                 ENUMS
    //////////////////////////////////////////////////////////////*/
    /// @notice Defines the possible types of hooks in the system
    /// @dev Used to determine how the hook affects accounting and what operations it performs
    enum HookType {
        NONACCOUNTING, // Hook doesn't affect accounting (e.g., a swap or bridge)
        INFLOW, // Hook processes deposits or positions being added
        OUTFLOW // Hook processes withdrawals or positions being removed

    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Builds the execution array for the hook operation
    /// @dev This is the core method where hooks define their on-chain interactions
    ///      The returned executions are a sequence of contract calls to perform
    ///      No state changes should occur in this method
    /// @param prevHook The address of the previous hook in the chain, or address(0) if first
    /// @param account The account to perform executions for (usually an ERC7579 account)
    /// @param data The hook-specific parameters and configuration data
    /// @return executions Array of Execution structs defining calls to make
    function build(
        address prevHook,
        address account,
        bytes calldata data
    )
        external
        view
        returns (Execution[] memory executions);

    /*//////////////////////////////////////////////////////////////
                                 PUBLIC METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Prepares the hook for execution
    /// @dev Called before the main execution, used to validate inputs and set execution context
    ///      This method may perform state changes to set up the hook's execution state
    /// @param prevHook The address of the previous hook in the chain, or address(0) if first
    /// @param account The account to perform operations for
    /// @param data The hook-specific parameters and configuration data
    function preExecute(address prevHook, address account, bytes memory data) external;

    /// @notice Finalizes the hook after execution
    /// @dev Called after the main execution, used to update hook state and calculate results
    ///      Sets output values (outAmount, usedShares, etc.) for subsequent hooks
    /// @param prevHook The address of the previous hook in the chain, or address(0) if first
    /// @param account The account operations were performed for
    /// @param data The hook-specific parameters and configuration data
    function postExecute(address prevHook, address account, bytes memory data) external;

    /// @notice Returns the specific subtype identification for this hook
    /// @dev Used to categorize hooks beyond the basic HookType
    ///      For example, a hook might be of type INFLOW but subtype VAULT_DEPOSIT
    /// @return A bytes32 identifier for the specific hook functionality
    function subtype() external view returns (bytes32);

    /// @notice Resets hook mutexes
    /// @param caller The caller address for context identification
    function resetExecutionState(address caller) external;

    /// @notice Sets the caller address that initiated the execution
    /// @dev Used for security validation between preExecute and postExecute calls
    /// @param caller The caller address for context identification
    function setExecutionContext(address caller, bytes calldata hookData) external;
}
