// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { IAcrossV3Interpreter } from "src/interfaces/vendors/bridges/across/IAcrossV3Interpreter.sol";

interface ISuperGatewayExecutorV2 {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error DATA_NOT_VALID();
    error NOT_AUTHORIZED();
    error ADDRESS_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get the actions registry address
    function superActions() external view returns (address);

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Execute a batch of calls
    /// @param data The strategy data (strategyId, hooksData)
    function execute(bytes memory data)
        //IAcrossV3Interpreter.EntryPointData memory entryPointData
        external;
}
