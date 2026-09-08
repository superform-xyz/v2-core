// SPDX-License-Identifier: Apache-2.0
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
interface ISuperLockableHook {
    /// @notice The vault bank address used to lock SuperPositions
    /// @dev Only relevant for cross-chain operations where positions are locked
    /// @return The vault bank address, or address(0) if not applicable
    function vaultBank() external view returns (address);

    /// @notice The destination chain ID for cross-chain operations
    /// @dev Used to identify the target chain for cross-chain position transfers
    /// @return The destination chain ID, or 0 if not a cross-chain operation
    function dstChainId() external view returns (uint256);
}

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

    /// @notice The amount of tokens processed by the hook in a given caller context, subject to fees after update
    /// @dev This is the primary output value used by subsequent hooks
    /// @param caller The caller address for context identification
    /// @return The amount of tokens (assets or shares) processed
    function getOutAmount(address caller) external view returns (uint256);

    /// @notice The output token address produced by the hook in a given caller context
    /// @dev Used by subsequent hooks to determine what token the previous hook produced
    ///      PASSTHROUGH hooks auto-forward the previous hook's outToken
    ///      TRANSFORM hooks set this to their specific output token
    /// @param caller The caller address for context identification
    /// @return The address of the output token, or address(0) if not set
    function getOutToken(address caller) external view returns (address);
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
    /// @notice Direction of an amount slot
    /// @dev IN  = primary amount the OMS sizes (intent amount)
    ///      OUT = secondary derived amount (e.g. borrow amount in supply-and-borrow)
    enum Direction {
        IN,
        OUT
    }

    /// @notice Denomination of an amount slot
    /// @dev TOKEN  = raw ERC-20 amount (swaps, bridges, transfers, loan operations)
    ///      ASSETS = underlying asset amount (vault deposits, ERC-4626/7540 withdraw)
    ///      SHARES = vault share amount (vault redeems, ERC-4626/7540 requestRedeem)
    enum Denomination {
        TOKEN,
        ASSETS,
        SHARES
    }

    /// @notice Per-slot metadata: direction + denomination
    /// @dev Aligned 1:1 with the array from decodeAmounts.
    ///      A slot belongs in decodeAmounts/amountRoles iff the OMS can rewrite it
    ///      at execution time without invalidating any commitment (signature or proof)
    ///      embedded in the same data.
    struct AmountMeta {
        Direction dir;
        Denomination denom;
    }

    /// @notice Extracts all amounts from the hook's calldata
    /// @dev Used to determine the quantity of assets or shares being processed
    /// @param data The hook-specific calldata
    /// @return amounts Array of amounts (length 1 for single-amount hooks, 2+ for compound hooks)
    function decodeAmounts(bytes memory data) external pure returns (uint256[] memory amounts);

    /// @notice Returns per-slot metadata (direction + denomination) for each amount
    /// @dev Must return an array of the same length as decodeAmounts(data).
    ///      Enables the OMS to know which slots to size (IN vs OUT) and in what
    ///      denomination (TOKEN vs ASSETS vs SHARES).
    ///      Takes data so variable-count hooks can return the correct number of slots.
    /// @param data The hook-specific calldata (same as passed to decodeAmounts)
    /// @return meta Array of AmountMeta structs aligned index-by-index with decodeAmounts
    function amountRoles(bytes memory data) external pure returns (AmountMeta[] memory meta);
}

/// @title ISuperHookOutflow
/// @author Superform Labs
/// @notice Interface for hooks that specifically handle outflows (withdrawals)
/// @dev Provides additional functionality needed only for outflow operations
interface ISuperHookOutflow {
    /// @notice Replace amounts in the calldata
    /// @param data The data to replace amounts in
    /// @param amounts The amounts to replace (must match length from decodeAmounts)
    /// @return The data with replaced amounts
    function replaceCalldataAmounts(
        bytes memory data,
        uint256[] memory amounts
    )
        external
        pure
        returns (bytes memory);
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

/// @title ISuperHookLoans
/// @author Superform Labs
/// @notice Interface for hooks that interact with lending protocols
/// @dev Extends context awareness to enable loan operations within hook chains
interface ISuperHookLoans is ISuperHookContextAware {
    /// @notice Gets the address of the token being borrowed
    /// @dev Used to identify which asset is being borrowed from the lending protocol
    /// @param data The hook-specific data containing loan information
    /// @return The address of the borrowed token
    function getLoanTokenAddress(bytes memory data) external pure returns (address);

    /// @notice Gets the address of the token used as collateral
    /// @dev Used to identify which asset is being used to secure the loan
    /// @param data The hook-specific data containing collateral information
    /// @return The address of the collateral token
    function getCollateralTokenAddress(bytes memory data) external view returns (address);

    /// @notice Gets the account's current ERC-20 wallet balance of the loan token
    /// @dev Returns the plain wallet balance (not the outstanding debt on the lending protocol).
    ///      Hooks snapshot this before execution and measure the post-execution delta to report
    ///      actual loan tokens received (borrow) or spent (repay).
    /// @param account The account to check the wallet balance for
    /// @param data The hook-specific data containing the loan token address
    /// @return The account's wallet balance of the loan token
    function getLoanTokenBalance(address account, bytes memory data) external view returns (uint256);

    /// @notice Gets the account's current ERC-20 wallet balance of the collateral token
    /// @dev Returns the plain wallet balance (not the collateral posted on the lending protocol).
    ///      Hooks snapshot this before execution and measure the post-execution delta to report
    ///      actual collateral tokens spent (supply) or received (withdraw).
    /// @param account The account to check the wallet balance for
    /// @param data The hook-specific data containing the collateral token address
    /// @return The account's wallet balance of the collateral token
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

    /// @notice Human-readable name for UI display
    /// @return The hook's friendly name
    function name() external pure returns (string memory);

    /// @notice One-sentence description of what this hook does
    /// @return A human-readable description for UI display
    function description() external pure returns (string memory);

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
    function setExecutionContext(address caller) external;

    /// @notice Returns the execution nonce for the current execution context
    /// @dev Used to ensure unique execution contexts and prevent replay attacks
    /// @return The execution nonce
    function executionNonce() external view returns (uint256);

    /// @notice Returns the last caller registered by `setExecutionContext`
    /// @return The last caller address
    function lastCaller() external view returns (address);
}
