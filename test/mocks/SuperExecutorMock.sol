// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ERC7579ExecutorBase } from "modulekit/Modules.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { BytesLib } from "../../src/core/libraries/BytesLib.sol";

// Superform
import { SuperRegistryImplementer } from "../../src/core/utils/SuperRegistryImplementer.sol";

import { ISuperRbac } from "../../src/core/interfaces/ISuperRbac.sol";
import { ISuperExecutor } from "../../src/core/interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../../src/core/interfaces/accounting/ISuperLedger.sol";
import { ISuperHook, ISuperHookResult } from "../../src/core/interfaces/ISuperHook.sol";
import { ISuperCollectiveVault } from "./ISuperCollectiveVault.sol";

contract SuperExecutorMock is ERC7579ExecutorBase, SuperRegistryImplementer, ISuperExecutor {
    event SuperPositionLocked(address indexed account, address indexed spToken, uint256 amount);
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
            ISuperLedger ledger = ISuperLedger(superRegistry.getAddress(superRegistry.SUPER_LEDGER_ID()));
            bytes32 yieldSourceOracleId = BytesLib.toBytes32(BytesLib.slice(hookData, 20, 32), 0);
            address yieldSource = BytesLib.toAddress(BytesLib.slice(hookData, 52, 20), 0);

            ledger.updateAccounting(
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

            if (spToken == address(0)) revert ADDRESS_NOT_VALID();

            ISuperCollectiveVault vault =
                ISuperCollectiveVault(superRegistry.getAddress(keccak256("SUPER_COLLECTIVE_VAULT_ID")));

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
