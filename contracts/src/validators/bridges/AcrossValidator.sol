// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { AccountInstance } from "modulekit/ModuleKit.sol";

// Superform
import { BytesLib } from "src/libraries/BytesLib.sol";

import { ISuperRbac } from "src/interfaces/ISuperRbac.sol";
import { ISuperRegistry } from "src/interfaces/ISuperRegistry.sol";
import { ISuperExecutor } from "src/interfaces/executors/ISuperExecutor.sol";
import { IBridgeValidator } from "src/interfaces/executors/IBridgeValidator.sol";
import { HandleV3AcrossMessage } from "src/hooks/across/HandleV3AcrossMessage.sol";

contract AcrossValidator is IBridgeValidator {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    ISuperRegistry public superRegistry;
    ISuperExecutor public superExecutor;

    error INSTRUCTION_EMPTY();
    error ADDRESS_NOT_VALID();
    error NOT_BRIDGE_VALIDATOR_CONFIGURATOR();

    constructor(address registry_) {
        if (registry_ == address(0)) revert ADDRESS_NOT_VALID();

        superRegistry = ISuperRegistry(registry_);
    }

    modifier onlyBridgesValidatorConfigurator() {
        ISuperRbac rbac = ISuperRbac(superRegistry.getAddress(superRegistry.SUPER_RBAC_ID()));
        if (!rbac.hasRole(msg.sender, rbac.BRIDGE_VALIDATOR_CONFIGURATOR())) revert NOT_BRIDGE_VALIDATOR_CONFIGURATOR();
        _;
    }
    /*//////////////////////////////////////////////////////////////
                                 OWNER METHODS
    //////////////////////////////////////////////////////////////*/

    function setSuperExecutor(address executor_) external onlyBridgesValidatorConfigurator {
        if (executor_ == address(0)) revert ADDRESS_NOT_VALID();
        superExecutor = ISuperExecutor(executor_);
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IBridgeValidator
    function validateBridgeOperation(bytes memory txData_, address account_) external pure override {
        // validate calls
        HandleV3AcrossMessage.Call[] memory calls = abi.decode(txData_, (HandleV3AcrossMessage.Call[]));
        if (calls.length == 0) revert INSTRUCTION_EMPTY();

        uint256 len = calls.length;
        for (uint256 i; i < len; i++) {
            if (calls[i].target == address(0)) revert ADDRESS_NOT_VALID();
        }
    }
    /// @inheritdoc IBridgeValidator

    function validateReceiver(bytes memory, address) external view override { }
}
