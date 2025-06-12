// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ERC7579ExecutorBase} from "modulekit/Modules.sol";
import {IModule} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import {Execution} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import {ISuperExecutor} from "../../src/core/interfaces/ISuperExecutor.sol";
import {ISuperLedger} from "../../src/core/interfaces/accounting/ISuperLedger.sol";
import {ISuperLedgerConfiguration} from "../../src/core/interfaces/accounting/ISuperLedgerConfiguration.sol";
import {ISuperHook, ISuperHookResult} from "../../src/core/interfaces/ISuperHook.sol";
import {ISuperCollectiveVault} from "./ISuperCollectiveVault.sol";

import {HookDataDecoder} from "../../src/core/libraries/HookDataDecoder.sol";

contract MockSuperExecutor is ERC7579ExecutorBase, ISuperExecutor {
    using HookDataDecoder for bytes;

    ISuperLedgerConfiguration public immutable LEDGER_CONFIGURATION;
    address public immutable SUPER_COLLECTIVE_VAULT;

    constructor(address ledgerConfiguration_, address superCollectiveVault_) {
        LEDGER_CONFIGURATION = ISuperLedgerConfiguration(ledgerConfiguration_);
        SUPER_COLLECTIVE_VAULT = superCollectiveVault_;
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    mapping(address account => bool initialized) internal _initialized;

    function isInitialized(address account) external view override(IModule, ISuperExecutor) returns (bool) {
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
    function onInstall(bytes calldata) external override(IModule, ISuperExecutor) {
        if (_initialized[msg.sender]) revert ALREADY_INITIALIZED();
        _initialized[msg.sender] = true;
    }

    function onUninstall(bytes calldata) external override(IModule, ISuperExecutor) {
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
        uint256 hooksLen = entry.hooksAddresses.length;
        for (uint256 i; i < hooksLen; ++i) {
            // fill prevHook
            address prevHook = (i != 0) ? entry.hooksAddresses[i - 1] : address(0);
            // execute current hook
            _processHook(account, ISuperHook(entry.hooksAddresses[i]), prevHook, entry.hooksData[i]);
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

        // check SP minting and lock assets
        _lockForSuperPositions(account, address(hook));
    }

    function _updateAccounting(address account, address hook, bytes memory hookData) private {
        ISuperHook.HookType _type = ISuperHookResult(hook).hookType();
        if (_type == ISuperHook.HookType.INFLOW || _type == ISuperHook.HookType.OUTFLOW) {
            bytes4 yieldSourceOracleId = hookData.extractYieldSourceOracleId();
            address yieldSource = hookData.extractYieldSource();

            ISuperLedgerConfiguration.YieldSourceOracleConfig memory config =
                LEDGER_CONFIGURATION.getYieldSourceOracleConfig(yieldSourceOracleId);
            ISuperLedger(config.ledger).updateAccounting(
                account,
                yieldSource,
                yieldSourceOracleId,
                _type == ISuperHook.HookType.INFLOW,
                ISuperHookResult(address(hook)).outAmount(),
                0
            );
        }
    }

    function _lockForSuperPositions(address account, address hook) private {
        bool lockForSP = ISuperHookResult(address(hook)).vaultBank() != address(0);
        if (lockForSP) {
            address spToken = ISuperHookResult(hook).spToken();
            uint256 amount = ISuperHookResult(hook).outAmount();

            ISuperCollectiveVault vault = ISuperCollectiveVault(SUPER_COLLECTIVE_VAULT);
            if (address(vault) != address(0)) {
                // forge approval for vault
                Execution[] memory execs = new Execution[](1);
                execs[0] = Execution({
                    target: spToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (address(vault), amount))
                });
                _execute(account, execs);

                vault.lock(account, spToken, address(hook), amount);
            }
        }
    }
}
