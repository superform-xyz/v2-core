// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

interface ISuperHook {
    /*//////////////////////////////////////////////////////////////
                                 PUBLIC METHODS
    //////////////////////////////////////////////////////////////*/
    //TODO: we might not need return values for `preExecute`
    /// @notice Pre-hook operation
    /// @param data The data to pre-hook
    function preExecute(bytes memory data)
        external
        returns (address _addr, uint256 _value, bytes32 _data, bool _flag);

    /// @notice Post-hook operation
    /// @param data The data to post-hook
    function postExecute(bytes memory data)
        external
        returns (address _addr, uint256 _value, bytes32 _data, bool _flag);

    /// @notice Build the execution array for the hook
    /// @param data The data to build the execution array from
    /// @return executions The execution array
    function build(bytes memory data) external view returns (Execution[] memory executions);
}
