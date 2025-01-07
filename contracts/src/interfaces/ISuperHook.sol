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

    /// @notice Whether the hook is an inflow or outflow
    function isInflow() external view returns (bool);
}

interface ISuperHook {
    /*//////////////////////////////////////////////////////////////
                                 PUBLIC METHODS
    //////////////////////////////////////////////////////////////*/
    //TODO: we might not need return values for `preExecute`
    /// @notice Pre-hook operation
    /// @param prevHook The previous hook
    /// @param data The data to pre-hook
    function preExecute(address prevHook, bytes memory data) external;

    /// @notice Post-hook operation
    /// @param prevHook The previous hook
    /// @param data The data to post-hook
    function postExecute(address prevHook, bytes memory data) external;

    /// @notice Build the execution array for the hook
    /// @param prevHook The previous hook
    /// @param data The data to build the execution array from
    /// @return executions The execution array
    function build(address prevHook, bytes memory data) external view returns (Execution[] memory executions);
}
