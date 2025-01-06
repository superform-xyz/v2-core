// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { ERC7579ExecutorBase } from "modulekit/Modules.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";

import { ISuperHook } from "../interfaces/ISuperHook.sol";
import { ISuperRbac } from "../interfaces/ISuperRbac.sol";
import { ISuperExecutor } from "../interfaces/ISuperExecutor.sol";

import { console2 } from "forge-std/console2.sol";

contract SuperExecutor is ERC7579ExecutorBase, SuperRegistryImplementer, ISuperExecutor {
    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    mapping(address => bool) internal _initialized;

    constructor(address registry_) SuperRegistryImplementer(registry_) { }

    // TODO: check if sender is bridge gateway; otherwise enforce at the logic level
    modifier onlyBridgeGateway() {
        ISuperRbac rbac = ISuperRbac(superRegistry.getAddress(superRegistry.SUPER_RBAC_ID()));
        if (!rbac.hasRole(msg.sender, rbac.BRIDGE_GATEWAY())) revert NOT_AUTHORIZED();
        _;
    }

    function isInitialized(address account) external view returns (bool) {
        return _initialized[account];
    }

    function name() external pure returns (string memory) {
        return "SuperExecutor";
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
    function onInstall(bytes calldata) external {
        if (_initialized[msg.sender]) revert ALREADY_INITIALIZED();
        _initialized[msg.sender] = true;
    }

    function onUninstall(bytes calldata) external {
        if (!_initialized[msg.sender]) revert NOT_INITIALIZED();
        _initialized[msg.sender] = false;
    }

    function execute(bytes calldata data) external {
        if (!_initialized[msg.sender]) revert NOT_INITIALIZED();
        _execute(msg.sender, abi.decode(data, (ExecutorEntry)));
    }

    /// @inheritdoc ISuperExecutor
    function executeFromGateway(address account, bytes calldata data) external onlyBridgeGateway {
        if (!_initialized[account]) revert NOT_INITIALIZED();
        // check if we need anything else here
        _execute(account, abi.decode(data, (ExecutorEntry)));
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _execute(address account, ExecutorEntry memory entry) private {
        // execute each strategy
        uint256 hooksLen = entry.hooksAddresses.length;
        for (uint256 i; i < hooksLen;) {
            // fill prevHook
            address prevHook = (i != 0) ? entry.hooksAddresses[i - 1] : address(0);
            console2.log("prevHook", prevHook);
            // execute current hook
            _processHook(account, ISuperHook(entry.hooksAddresses[i]), prevHook, entry.hooksData[i]);

            // go to next hook
            unchecked {
                ++i;
            }
        }
    }

    function _processHook(address account, ISuperHook hook, address prevHook, bytes memory hookData) private {
        // run hook preExecute
        hook.preExecute(prevHook, hookData);

        Execution[] memory executions = hook.build(prevHook, hookData);

        // run hook execute
        if (executions.length > 0) {
            _execute(account, executions);
        }

        // run hook postExecute
        hook.postExecute(prevHook, hookData);
    }
}
