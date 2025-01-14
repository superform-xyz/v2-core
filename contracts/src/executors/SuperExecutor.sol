// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { ERC7579ExecutorBase } from "modulekit/Modules.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { BytesLib } from "../libraries/BytesLib.sol";

// Superform
import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";

import { ISuperRbac } from "../interfaces/ISuperRbac.sol";
import { ISuperExecutor } from "../interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../interfaces/accounting/ISuperLedger.sol";
import { ISuperHook, ISuperHookMinimal } from "../interfaces/ISuperHook.sol";
import { ILockFundsAccountHook } from "../interfaces/account-hooks/ILockFundsAccountHook.sol";

contract SuperExecutor is ERC7579ExecutorBase, SuperRegistryImplementer, ISuperExecutor {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    constructor(address registry_) SuperRegistryImplementer(registry_) { }

    // TODO: check if sender is bridge gateway; otherwise enforce at the logic level
    modifier onlyBridgeGateway() {
        ISuperRbac rbac = ISuperRbac(superRegistry.getAddress(superRegistry.SUPER_RBAC_ID()));
        if (!rbac.hasRole(msg.sender, rbac.BRIDGE_GATEWAY())) revert NOT_AUTHORIZED();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get the name of the module
    function name() external pure returns (string memory) {
        return "SuperExecutor";
    }

    /// @notice Get the version of the module
    function version() external pure returns (string memory) {
        return "0.0.1";
    }

    /// @notice Check if the module is of a given type
    /// @param typeID The type to check
    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }

    /// @notice Check if the module is initialized
    function isInitialized(address) external pure returns (bool) {
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function onInstall(bytes calldata) external pure { }

    function onUninstall(bytes calldata) external pure { }

    function execute(bytes calldata data) external {
        _execute(msg.sender, abi.decode(data, (ExecutorEntry)));
    }

    /// @inheritdoc ISuperExecutor
    function executeFromGateway(address account, bytes calldata data) external onlyBridgeGateway {
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

        uint8 flags = ISuperHookMinimal(address(hook)).lockFlag();
        // (lock || unlock)
        if (flags & 3 != 0) {
            address spToken = ISuperHookMinimal(address(hook)).spToken();
            uint256 amount = ISuperHookMinimal(address(hook)).outAmount();
            if (spToken == address(0)) revert ADDRESS_NOT_VALID();

            if (flags & 1 != 0) {
                //lock
                ILockFundsAccountHook(superRegistry.getAddress(superRegistry.LOCK_FUNDS_ACCOUNT_HOOK_ID())).lock(
                    account, spToken, amount
                );
            } else if (flags & 2 != 0) {
                //TODO: unlock flag cannot be passed by orchestrator like this
                //       because otherwise the user would be able to unlock his shares and SuperPositions are still available on SupeformChain
                //       Decide in ST
                // unlock
                ILockFundsAccountHook(superRegistry.getAddress(superRegistry.LOCK_FUNDS_ACCOUNT_HOOK_ID())).unlock(
                    account, spToken, amount
                );
            } else {
                revert LOCK_UNLOCK_FLAG_NOT_VALID();
            }
        }

        Execution[] memory executions = hook.build(prevHook, hookData);

        // run hook execute
        if (executions.length > 0) {
            _execute(account, executions);
        }

        // run hook postExecute
        hook.postExecute(prevHook, hookData);

        ISuperHook.HookType _type = ISuperHookMinimal(address(hook)).hookType();
        if (_type == ISuperHook.HookType.INFLOW || _type == ISuperHook.HookType.OUTFLOW) {
            ISuperLedger ledger = ISuperLedger(superRegistry.getAddress(superRegistry.SUPER_LEDGER_ID()));

            bytes32 yieldSourceOracleId = BytesLib.toBytes32(BytesLib.slice(hookData, 20, 32), 0);
            address yieldSource = BytesLib.toAddress(BytesLib.slice(hookData, 52, 20), 0);

            ledger.updateAccounting(
                account,
                yieldSource,
                yieldSourceOracleId,
                _type == ISuperHook.HookType.INFLOW,
                ISuperHookMinimal(address(hook)).outAmount()
            );
        }
    }
}
