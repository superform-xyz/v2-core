// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// modulekit
import { ERC7579ExecutorBase } from "modulekit/Modules.sol";

// Superform
import { BaseModule } from "src/modules/BaseModule.sol";
import { CreateDebridgeOrder } from "src/hooks/CreateDebridgeOrder.sol";

import { IBridgeValidator } from "src/interfaces/IBridgeValidator.sol";
import { ISuperformExecutionModule } from "src/interfaces/ISuperformExecutionModule.sol";

contract DeBridgeOrderModule is ERC7579ExecutorBase, BaseModule, ISuperformExecutionModule {
    address public author;
    IBridgeValidator public validator;

    address public immutable dlnSource;

    event DebridgeOrderCreated(address indexed account);

    constructor(address registry_, address validator_, address dlnSource_) BaseModule(registry_) {
        author = msg.sender;
        validator = IBridgeValidator(validator_);
        dlnSource = dlnSource_;
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperformExecutionModule
    function name() external pure override returns (string memory) {
        return "DeBridgeOrder";
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
        (address account, bytes memory orderData) = abi.decode(data, (address, bytes));
        validator.validateOrder(orderData, account);
        _execute(account, CreateDebridgeOrder.hook(orderData, dlnSource, msg.value));

        emit DebridgeOrderCreated(account);
    }
}
