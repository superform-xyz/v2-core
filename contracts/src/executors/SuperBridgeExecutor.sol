// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// Superform
import { BaseExecutor } from "./BaseExecutor.sol";
import { IBridgeValidator } from "src/interfaces/executors/IBridgeValidator.sol";
import { ISuperExecutor } from "src/interfaces/executors/ISuperExecutor.sol";

contract SuperBridgeExecutor is ISuperExecutor, BaseExecutor {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    IBridgeValidator public bridgeValidator;

    event BridgeValidatorSet(address indexed bridgeValidator);

    constructor(address registry_) BaseExecutor(registry_) { }

    /*//////////////////////////////////////////////////////////////
                                 OWNER METHODS
    //////////////////////////////////////////////////////////////*/
    function setBridgeValidator(address bridgeValidator_) external onlyExecutorConfigurator {
        if (bridgeValidator_ == address(0)) revert ADDRESS_NOT_VALID();
        bridgeValidator = IBridgeValidator(bridgeValidator_);
        emit BridgeValidatorSet(bridgeValidator_);
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    function execute(bytes memory data) external override {
        bridgeValidator.validateReceiver("", address(0));

        _executeAccountOp(data);
    }
}
