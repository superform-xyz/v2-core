// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ERC7579ExecutorBase } from "modulekit/Modules.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { SuperRegistryImplementer } from "../../src/core/utils/SuperRegistryImplementer.sol";

import { ISuperExecutor } from "../../src/core/interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../../src/core/interfaces/accounting/ISuperLedger.sol";
import { ISuperLedgerConfiguration } from "../../src/core/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperHook, ISuperHookResult } from "../../src/core/interfaces/ISuperHook.sol";
import { ISuperCollectiveVault } from "./ISuperCollectiveVault.sol";

import { INexusFactory } from "../../src/vendor/nexus/INexusFactory.sol";


import { HookDataDecoder } from "../../src/core/libraries/HookDataDecoder.sol";

contract MockTargetExecutor is ERC7579ExecutorBase, SuperRegistryImplementer, ISuperExecutor {
    using HookDataDecoder for bytes;

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    INexusFactory public nexusFactory;
    mapping(address => bool) internal _initialized;

    // @dev used for testing only
    address public nexusCreatedAccount;

    error INVALID_SENDER();

    event HappyAccountCreated(address indexed account);

    constructor(address registry_) SuperRegistryImplementer(registry_) { }

    // @dev this would be in the constructor for the real TargetExecutor
    function setNexusFactory(address nexusFactory_) external {
        nexusFactory = INexusFactory(nexusFactory_);
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


    // @dev `message`  has data only for the account creation 
    function handleV3AcrossMessage(
        address tokenSent,
        uint256 amount,
        address, //relayer; not used
        bytes memory message
    )
        external
    {
        // @dev this should exist on the real TargetExecutor
        //if (msg.sender != acrossSpokePool) revert INVALID_SENDER();

        // @dev for the real TargetExecutor this would be abi.encodePacked and have more fields
        (bytes memory initData, bytes32 initSalt) = abi.decode(message, (bytes, bytes32));

        address computedAddress = nexusFactory.computeAccountAddress(initData, initSalt);
        address deployedAddress = nexusFactory.createAccount(initData, initSalt);
        
        // @dev use custom errors for the real executor
        if (deployedAddress != computedAddress) revert("Nexus SCA addresses mismatch");

        // @dev use safeTransfer for the real executor
        IERC20(tokenSent).transfer(deployedAddress, amount);
        
        nexusCreatedAccount = deployedAddress;
        emit HappyAccountCreated(deployedAddress);
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
            ISuperLedgerConfiguration ledgerConfiguration =
                ISuperLedgerConfiguration(superRegistry.getAddress(keccak256("SUPER_LEDGER_CONFIGURATION_ID")));
            bytes4 yieldSourceOracleId = hookData.extractYieldSourceOracleId();
            address yieldSource = hookData.extractYieldSource();

            ISuperLedgerConfiguration.YieldSourceOracleConfig memory config =
                ledgerConfiguration.getYieldSourceOracleConfig(yieldSourceOracleId);
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
        bool lockForSP = ISuperHookResult(address(hook)).lockForSP();
        if (lockForSP) {
            address spToken = ISuperHookResult(hook).spToken();
            uint256 amount = ISuperHookResult(hook).outAmount();

            ISuperCollectiveVault vault;
            try superRegistry.getAddress(keccak256("SUPER_COLLECTIVE_VAULT_ID")) returns (address vaultAddress) {
                vault = ISuperCollectiveVault(vaultAddress);
            } catch {
                return;
            }

            if (address(vault) != address(0)) {
                // forge approval for vault
                Execution[] memory execs = new Execution[](1);
                execs[0] = Execution({
                    target: spToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (address(vault), amount))
                });
                _execute(account, execs);

                vault.lock(account, spToken, amount);

                emit SuperPositionLocked(account, spToken, amount);
            }
        }
    }
}
