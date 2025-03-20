// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

/// @title ISuperHookResult
/// @author Superform Labs
/// @notice Interface for the SuperHookResult contract that manages hook results
interface ISuperHookResult {
    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice The amount of tokens processed by the hook
    function outAmount() external view returns (uint256);
    /// @notice The type of hook
    function hookType() external view returns (ISuperHook.HookType);
    /// @notice The lock flag of the hook
    function lockForSP() external view returns (bool);
    /// @notice The lock token of the hook
    function spToken() external view returns (address);
    /// @notice The asset token being withdrawn or deposited
    function asset() external view returns (address);
}

/// @title ISuperHookInflowOutflow
/// @author Superform Labs
/// @notice Interface for the SuperHookInflowOutflow contract that manages inflow and outflow hooks
interface ISuperHookInflowOutflow {
    function decodeAmount(bytes memory data) external pure returns (uint256);
}

/// @title ISuperHookOutflow
/// @author Superform Labs
/// @notice Interface for the SuperHookOutflow contract that manages outflow hooks
interface ISuperHookOutflow {
    /// @notice Replace the amount in the calldata
    /// @param data The data to replace the amount in
    /// @param amount The amount to replace
    /// @return data The data with the replaced amount
    function replaceCalldataAmount(bytes memory data, uint256 amount) external pure returns (bytes memory);
}

/// @title ISuperHookResultOutflow
/// @author Superform Labs
/// @notice Interface for the SuperHookResultOutflow contract that manages outflow hook results
interface ISuperHookResultOutflow is ISuperHookResult {
    /// @notice The amount of shares processed by the hook
    function usedShares() external view returns (uint256);
}

/// @title ISuperHookNonAccounting
/// @author Superform Labs
/// @notice Interface for the SuperHookResultNonAccounting contract that manages non-accounting hook results
interface ISuperHookNonAccounting {
    /// @notice The amount of assets or shares processed by the hook
    function getUsedAssetsOrShares() external pure returns (uint256, bool);
}

/// @title ISuperHook
/// @author Superform Labs
/// @notice Interface for the SuperHook contract that manages hooks
interface ISuperHook {
    /*//////////////////////////////////////////////////////////////

                                 ENUMS
    //////////////////////////////////////////////////////////////*/
    enum HookType {
        NONACCOUNTING,
        INFLOW,
        OUTFLOW
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Build the execution array for the hook
    /// @param prevHook The previous hook
    /// @param account The account to build the execution array from
    /// @param data The data to build the execution array from
    /// @return executions The execution array
    function build(
        address prevHook,
        address account,
        bytes memory data
    )
        external
        view
        returns (Execution[] memory executions);

    /*//////////////////////////////////////////////////////////////
                                 PUBLIC METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Pre-hook operation
    /// @param prevHook The previous hook
    /// @param account The account to pre-hook
    /// @param data The data to pre-hook
    function preExecute(address prevHook, address account, bytes memory data) external;

    /// @notice Post-hook operation
    /// @param prevHook The previous hook
    /// @param account The account to post-hook
    /// @param data The data to post-hook
    function postExecute(address prevHook, address account, bytes memory data) external;
}
