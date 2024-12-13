// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    ModuleKitUserOp,
    AccountInstance,
    UserOpData
} from "modulekit/ModuleKit.sol";
import { ERC7579ExecutorBase } from "modulekit/Modules.sol";

// Superform
import { BaseExecutorModule } from "./BaseExecutorModule.sol";
import { ISuperHook } from "src/interfaces/ISuperHook.sol";
import { ISentinel } from "src/interfaces/sentinel/ISentinel.sol";
import { ISuperExecutorV2 } from "src/interfaces/ISuperExecutorV2.sol";
import { ISuperActions } from "src/interfaces/strategies/ISuperActions.sol";
import { IAcrossV3Interpreter } from "src/interfaces/vendors/bridges/across/IAcrossV3Interpreter.sol";
import { ISuperRbac } from "src/interfaces/ISuperRbac.sol";
import { ISuperGatewayExecutorV2 } from "src/interfaces/ISuperGatewayExecutorV2.sol";

// TODO: test cross-chain execution; This contract might be merged with SuperExecutorV2 once we have an execution flow
// tested
contract SuperGatewayExecutorV2 is BaseExecutorModule, ERC7579ExecutorBase, ISuperGatewayExecutorV2 {
    constructor(address registry_) BaseExecutorModule(registry_) { }

    // TODO: check if sender is bridge gateway; otherwise enforce at the logic level
    modifier onlyBridgeGateway() {
        ISuperRbac rbac = ISuperRbac(superRegistry.getAddress(superRegistry.SUPER_RBAC_ID()));
        if (!rbac.hasRole(msg.sender, rbac.BRIDGE_GATEWAY())) revert NOT_AUTHORIZED();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperGatewayExecutorV2
    function superActions() public view returns (address) {
        return _superActions();
    }

    function isInitialized(address) external pure returns (bool) {
        return _isInitialized();
    }

    function name() external pure returns (string memory) {
        return "SuperGatewayExecutor";
    }

    function version() external pure returns (string memory) {
        return "0.0.1";
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function onInstall(bytes calldata) external { }
    function onUninstall(bytes calldata) external { }

    /// @inheritdoc ISuperGatewayExecutorV2
    function execute(
        bytes memory data // strategyId, hooksData
            //IAcrossV3Interpreter.EntryPointData memory
    )
        external
        onlyBridgeGateway
    {
        (uint256 actionId, bytes[] memory hooksData) = abi.decode(data, (uint256, bytes[]));

        // retrieve hooks for this strategy
        address[] memory hooks = ISuperActions(superActions()).getHooksForAction(actionId);

        // checks
        uint256 hooksLength = hooks.length;
        if (hooksLength == 0 || hooksLength != hooksData.length) revert DATA_NOT_VALID();

        // execute each hook
        for (uint256 i; i < hooksLength;) {
            _execute(ISuperHook(hooks[i]).build(hooksData[i]));

            unchecked {
                ++i;
            }
        }
    }
}
