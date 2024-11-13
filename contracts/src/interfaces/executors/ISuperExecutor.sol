// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { ISuperRegistry } from "src/interfaces/ISuperRegistry.sol";
import { IBridgeValidator } from "src/interfaces/IBridgeValidator.sol";

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
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event BridgeValidatorSet(address indexed bridgeValidator);

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @return The super registry
    function superRegistry() external view returns (ISuperRegistry);
    /// @return The bridge validator
    function bridgeValidator() external view returns (IBridgeValidator);

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Set the bridge validator
    /// @param bridgeValidator_ The bridge validator address
    function setBridgeValidator(address bridgeValidator_) external;

    /// @notice Execute a batch of calls
    /// @param data The data to execute
    function execute(bytes memory data) external;
}
