// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";

interface ISuperHook {
    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get the total number of operations in the hook
    /// @return The total number of operations
    function totalOps() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                                 PUBLIC METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Build the execution array for the hook
    /// @param data The data to build the execution array from
    /// @return executions The execution array
    function build(bytes memory data) external view returns (Execution[] memory executions);
}
