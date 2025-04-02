// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC7579ExecutorBase } from "modulekit/Modules.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Superform
import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";
import { ISuperExecutor } from "../interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../interfaces/accounting/ISuperLedger.sol";
import { ISuperLedgerConfiguration } from "../interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperHook, ISuperHookResult, ISuperHookResultOutflow } from "../interfaces/ISuperHook.sol";
import { HookDataDecoder } from "../libraries/HookDataDecoder.sol";


/// @title SuperExecutorBase
/// @author Superform Labs
/// @notice Base contract for Superform executors
abstract contract SuperExecutorBase is ERC7579ExecutorBase, SuperRegistryImplementer, ISuperExecutor, ReentrancyGuard {
    using HookDataDecoder for bytes;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(address => bool) internal _initialized;
    bytes32 internal constant SUPER_LEDGER_CONFIGURATION_ID = keccak256("SUPER_LEDGER_CONFIGURATION_ID");

    constructor(address registry_) SuperRegistryImplementer(registry_) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function isInitialized(address account) external view returns (bool) {
        return _initialized[account];
    }

    function name() external view virtual returns (string memory);

    function version() external view virtual returns (string memory);

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

     function execute(bytes calldata data) external virtual {
        if (!_initialized[msg.sender]) revert NOT_INITIALIZED();
        _execute(msg.sender, abi.decode(data, (ExecutorEntry)));
    }


    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _execute(address account, ExecutorEntry memory entry) internal virtual {
        uint256 hooksLen = entry.hooksAddresses.length;

        if (hooksLen == 0) revert NO_HOOKS();
        if (hooksLen != entry.hooksData.length) revert LENGTH_MISMATCH();

        // execute each strategy
        address prevHook;
        address currentHook;
        for (uint256 i; i < hooksLen; ++i) {
            currentHook = entry.hooksAddresses[i];
            if (currentHook == address(0)) revert ADDRESS_NOT_VALID();

            _processHook(account, ISuperHook(currentHook), prevHook, entry.hooksData[i]);
            prevHook = currentHook;
        }
    }
   
    function _updateAccounting(address account, address hook, bytes memory hookData) internal virtual {
        ISuperHook.HookType _type = ISuperHookResult(hook).hookType();
        if (_type == ISuperHook.HookType.INFLOW || _type == ISuperHook.HookType.OUTFLOW) {
            ISuperLedgerConfiguration ledgerConfiguration =
                ISuperLedgerConfiguration(superRegistry.getAddress(SUPER_LEDGER_CONFIGURATION_ID));

            bytes4 yieldSourceOracleId = hookData.extractYieldSourceOracleId();
            address yieldSource = hookData.extractYieldSource();

            ISuperLedgerConfiguration.YieldSourceOracleConfig memory config =
                ledgerConfiguration.getYieldSourceOracleConfig(yieldSourceOracleId);
            if (config.manager == address(0)) revert MANAGER_NOT_SET();

            // Update accounting and get fee amount if any
            uint256 feeAmount = ISuperLedger(config.ledger).updateAccounting(
                account,
                yieldSource,
                yieldSourceOracleId,
                _type == ISuperHook.HookType.INFLOW,
                ISuperHookResult(address(hook)).outAmount(),
                ISuperHookResultOutflow(address(hook)).usedShares()
            );

            // If there's a fee to collect (only for outflows)
            if (feeAmount > 0 && _type == ISuperHook.HookType.OUTFLOW) {
                if (feeAmount > ISuperHookResult(address(hook)).outAmount()) revert INVALID_FEE();

                // Get the asset token from the hook
                address assetToken = ISuperHookResultOutflow(hook).asset();
                if (assetToken == address(0)) {
                    if (account.balance < feeAmount) revert INSUFFICIENT_BALANCE_FOR_FEE();
                    _performNativeFeeTransfer(account, config.feeRecipient, feeAmount);
                } else {
                    if (IERC20(assetToken).balanceOf(account) < feeAmount) revert INSUFFICIENT_BALANCE_FOR_FEE();
                    _performErc20FeeTransfer(account, assetToken, config.feeRecipient, feeAmount);
                }
            }
        }
    }

    function _performErc20FeeTransfer(
        address account,
        address assetToken,
        address feeRecipient,
        uint256 feeAmount
    )
        internal virtual 
    {
        uint256 balanceBefore = IERC20(assetToken).balanceOf(feeRecipient);
        Execution[] memory feeExecution = new Execution[](1);
        feeExecution[0] = Execution({
            target: assetToken,
            value: 0,
            callData: abi.encodeCall(IERC20.transfer, (feeRecipient, feeAmount))
        });
        _execute(account, feeExecution);
        uint256 balanceAfter = IERC20(assetToken).balanceOf(feeRecipient);
        if (balanceAfter - balanceBefore != feeAmount) revert FEE_NOT_TRANSFERRED();
    }

    function _performNativeFeeTransfer(address account, address feeRecipient, uint256 feeAmount) internal virtual {
        uint256 balanceBefore = feeRecipient.balance;
        Execution[] memory feeExecution = new Execution[](1);
        feeExecution[0] = Execution({ target: feeRecipient, value: feeAmount, callData: "" });
        _execute(account, feeExecution);
        uint256 balanceAfter = feeRecipient.balance;
        if (balanceAfter - balanceBefore != feeAmount) revert FEE_NOT_TRANSFERRED();
    }

    function _processHook(address account, ISuperHook hook, address prevHook, bytes memory hookData) internal nonReentrant {
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


}
