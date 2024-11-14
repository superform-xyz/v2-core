// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// Superform
import { BaseExecutor } from "./BaseExecutor.sol";
import { ISuperExecutor } from "src/interfaces/executors/ISuperExecutor.sol";

contract SuperAccountExecutor is ISuperExecutor, BaseExecutor {
    constructor(address registry_) BaseExecutor(registry_) { }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    function execute(bytes memory data) external override {
        _executeAccountOp(data);
    }
}
