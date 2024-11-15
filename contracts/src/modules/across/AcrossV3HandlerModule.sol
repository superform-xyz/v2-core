// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// modulekit
import { ERC7579ExecutorBase } from "modulekit/Modules.sol";

// Superform
import { BaseModule } from "src/modules/BaseModule.sol";
import { HandleV3AcrossMessage } from "src/hooks/across/HandleV3AcrossMessage.sol";

import { IBridgeValidator } from "src/interfaces/executors/IBridgeValidator.sol";
import { ISuperformExecutionModule } from "src/interfaces/ISuperformExecutionModule.sol";

contract AcrossV3HandlerModule is ERC7579ExecutorBase, BaseModule, ISuperformExecutionModule {
    address public author;
    IBridgeValidator public validator;

    address public immutable acrossHandler;

    event AcrossInstructionCreated(address indexed account);

    constructor(address registry_, address validator_, address acrossHandler_) BaseModule(registry_) {
        author = msg.sender;
        validator = IBridgeValidator(validator_);

        acrossHandler = acrossHandler_;
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperformExecutionModule
    function name() external pure override returns (string memory) {
        return "AcrossV3Handler";
    }

    /// @inheritdoc ISuperformExecutionModule
    function version() external pure override returns (string memory) {
        return "0.0.1";
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }

    function isInitialized(address) external pure returns (bool) {
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function onInstall(bytes calldata) external { }
    function onUninstall(bytes calldata) external { }

    function execute(bytes calldata data) external payable {
        (address account, address token, address fallbackRecipient, bytes memory calls) =
            abi.decode(data, (address, address, address, bytes));
        validator.validateBridgeOperation(calls, account);
        _execute(account, HandleV3AcrossMessage.hook(token, acrossHandler, msg.value, calls, fallbackRecipient));

        emit AcrossInstructionCreated(account);
    }
}
