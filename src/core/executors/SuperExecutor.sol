// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ERC7579ExecutorBase } from "modulekit/Modules.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";

import { ISuperRbac } from "../interfaces/ISuperRbac.sol";
import { ISuperExecutor } from "../interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../interfaces/accounting/ISuperLedger.sol";
import { ISuperHook, ISuperHookResult, ISuperHookResultOutflow } from "../interfaces/ISuperHook.sol";

import { HookDataDecoder } from "../libraries/HookDataDecoder.sol";

contract SuperExecutor is ERC7579ExecutorBase, SuperRegistryImplementer, ISuperExecutor {
    using HookDataDecoder for bytes;

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    mapping(address => bool) internal _initialized;

    constructor(address registry_) SuperRegistryImplementer(registry_) { }

    // TODO: check if sender is bridge gateway; otherwise enforce at the logic level
    modifier onlyBridgeGateway() {
        ISuperRbac rbac = ISuperRbac(superRegistry.getAddress(keccak256("SUPER_RBAC_ID")));
        if (!rbac.hasRole(keccak256("BRIDGE_GATEWAY"), msg.sender)) revert NOT_AUTHORIZED();
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

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _execute(address account, ExecutorEntry memory entry) private {
        // execute each strategy
        address prevHook = address(0);
        uint256 hooksLen = entry.hooksAddresses.length;
        for (uint256 i; i < hooksLen;) {
            address currentHook = entry.hooksAddresses[i];
            _processHook(account, ISuperHook(entry.hooksAddresses[i]), prevHook, entry.hooksData[i]);
            prevHook= currentHook;
            // go to next hook
            unchecked { ++i; }
        }
    }

    function _processHook(address account, ISuperHook hook, address prevHook, bytes memory hookData) private {
        // run hook preExecute
        hook.preExecute(prevHook, account, hookData);

        Execution[] memory executions = hook.build(prevHook, account, hookData);
        // run hook execute
        if (executions.length > 0) {
            _execute(account, executions);
        }

        // run hook postExecute
        hook.postExecute(prevHook, account, hookData);

        // update accounting
        _updateAccounting(account, address(hook), hookData);
    }

    function _updateAccounting(address account, address hook, bytes memory hookData) private {
        ISuperHook.HookType _type = ISuperHookResult(hook).hookType();
        if (_type == ISuperHook.HookType.INFLOW || _type == ISuperHook.HookType.OUTFLOW) {
            ISuperLedger ledger = ISuperLedger(superRegistry.getAddress(keccak256("SUPER_LEDGER_ID")));
            bytes32 yieldSourceOracleId = hookData.extractYieldSourceOracleId();
            address yieldSource = hookData.extractYieldSource();

            // Update accounting and get fee amount if any
            uint256 feeAmount = ledger.updateAccounting(
                account,
                yieldSource,
                yieldSourceOracleId,
                _type == ISuperHook.HookType.INFLOW,
                ISuperHookResult(address(hook)).outAmount(),
                ISuperHookResultOutflow(address(hook)).usedShares()
            );

            // If there's a fee to collect (only for outflows)
            if (feeAmount > 0) {
                ISuperLedger.YieldSourceOracleConfig memory config =
                    ledger.getYieldSourceOracleConfig(yieldSourceOracleId);
                // Get the asset token from the hook
                address assetToken = ISuperHookResultOutflow(hook).asset();
                if (assetToken == address(0)) revert ADDRESS_NOT_VALID();
                if (IERC20(assetToken).balanceOf(account) < feeAmount) revert INSUFFICIENT_BALANCE_FOR_FEE();

                uint256 balanceBefore = IERC20(assetToken).balanceOf(config.feeRecipient);
                Execution[] memory feeExecution = new Execution[](1);
                feeExecution[0] = Execution({
                    target: assetToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.transfer, (config.feeRecipient, feeAmount))
                });
                _execute(account, feeExecution);
                uint256 balanceAfter = IERC20(assetToken).balanceOf(config.feeRecipient);
                if (balanceAfter - balanceBefore != feeAmount) revert FEE_NOT_TRANSFERRED();
            }
        }
    }
}
