// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";

// Superform
import { IAcrossV3Interpreter } from "src/interfaces/vendors/bridges/across/IAcrossV3Interpreter.sol";

interface ISuperGatewayExecutor {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NO_EXECUTIONS();
    error NOT_AUTHORIZED();
    error ADDRESS_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Execute a batch of calls
    /// @param executions The executions to execute
    /// @param entryPointData The entry point data
    function execute(
        Execution[] memory executions,
        IAcrossV3Interpreter.EntryPointData memory entryPointData
    )
        external;
}
