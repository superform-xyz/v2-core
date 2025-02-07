// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

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

interface ISuperHookInflowOutflow {
    function decodeAmount(bytes memory data) external pure returns (uint256);
}

interface ISuperHookResultOutflow is ISuperHookResult {

    /// @notice The amount of shares processed by the hook
    function usedShares() external view returns (uint256);
}

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
    function build(address prevHook, address account, bytes memory data) external view returns (Execution[] memory executions);

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
