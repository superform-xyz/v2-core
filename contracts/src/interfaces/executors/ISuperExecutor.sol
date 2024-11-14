// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { ISuperRegistry } from "src/interfaces/ISuperRegistry.sol";

interface ISuperExecutor {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_DATA();
    error INVALID_MODULE();
    error ADDRESS_NOT_VALID();
    error NOT_RELAYER_SENTINEL();
    error NOT_EXECUTOR_CONFIGURATOR();

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @return The super registry
    function superRegistry() external view returns (ISuperRegistry);

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Execute a batch of calls
    /// @param data The data to execute
    function execute(bytes memory data) external;
}
