// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC7579ExecutorBase } from "modulekit/Modules.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";

// Superform
import { ISuperExecutor } from "../interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../interfaces/accounting/ISuperLedger.sol";
import { ISuperLedgerConfiguration } from "../interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperHook, ISuperHookResult, ISuperHookResultOutflow } from "../interfaces/ISuperHook.sol";
import { ISuperStateProver } from "../interfaces/ISuperStateProver.sol";
import { ISuperResultVerifier } from "../interfaces/ISuperResultVerifier.sol";
import { HookDataDecoder } from "../libraries/HookDataDecoder.sol";

/// @title SuperExecutorBase
/// @author Superform Labs
/// @notice Base contract for Superform executors
abstract contract SuperExecutorBase is
    ERC7579ExecutorBase,
    ISuperExecutor,
    ReentrancyGuard
{
    using HookDataDecoder for bytes;
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(address => bool) internal _initialized;
    ISuperLedgerConfiguration public immutable ledgerConfiguration;
    
    // Verifiers for proofs - can be zero for standard execution
    address public immutable stateProver;
    address public immutable resultVerifier;
    
    // If true, requires proofs for specific execution types
    bool public immutable requireProofsForSkippedExecution;

    uint256 internal constant FEE_TOLERANCE = 10_000;
    uint256 internal constant FEE_TOLERANCE_DENOMINATOR = 100_000;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event ProofVerified(address indexed account, address indexed hook, bool verified);
    event HookExecutionSkipped(address indexed account, address indexed hook, bool verified);
    event ResultsVerified(address indexed account, address indexed hook, bool verified);

    constructor(
        address superLedgerConfiguration_,
        address stateProver_,
        address resultVerifier_,
        bool requireProofsForSkippedExecution_
    ) {
        if (superLedgerConfiguration_ == address(0)) revert ADDRESS_NOT_VALID(); 
        ledgerConfiguration = ISuperLedgerConfiguration(superLedgerConfiguration_);
        stateProver = stateProver_;
        resultVerifier = resultVerifier_;
        requireProofsForSkippedExecution = requireProofsForSkippedExecution_;
    }

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

        // Basic validation
        if (hooksLen == 0) revert NO_HOOKS();
        if (hooksLen != entry.hooksData.length) revert LENGTH_MISMATCH();
        
        // Validate optional arrays if present
        if (entry.stateProofs.length > 0 && entry.stateProofs.length != hooksLen) revert LENGTH_MISMATCH();
        if (entry.expectedResults.length > 0 && entry.expectedResults.length != hooksLen) revert LENGTH_MISMATCH();
        if (entry.skipOnChainExecution.length > 0 && entry.skipOnChainExecution.length != hooksLen) revert LENGTH_MISMATCH();

        // execute each hook
        address prevHook;
        address currentHook;
        for (uint256 i; i < hooksLen; ++i) {
            currentHook = entry.hooksAddresses[i];
            if (currentHook == address(0)) revert ADDRESS_NOT_VALID();
            
            bool skipExecution = entry.skipOnChainExecution.length > 0 && entry.skipOnChainExecution[i];
            
            if (skipExecution) {
                // Skip execution path - verify proof and apply results directly
                _processHookWithProof(
                    account,
                    ISuperHook(currentHook),
                    prevHook,
                    entry.hooksData[i],
                    entry.stateProofs.length > 0 ? entry.stateProofs[i] : bytes(""),
                    entry.expectedResults.length > 0 ? entry.expectedResults[i] : bytes("")
                );
            } else {
                // Standard execution path
                _processHook(account, ISuperHook(currentHook), prevHook, entry.hooksData[i]);
            }
            
            prevHook = currentHook;
        }
    }
    
    // Process hook with state transition proof, bypassing actual execution
    function _processHookWithProof(
        address account,
        ISuperHook hook,
        address prevHook,
        bytes memory hookData,
        bytes memory stateProof,
        bytes memory expectedResults
    ) internal nonReentrant {
        // When skipping execution, we must have proofs if the flag is set
        if (requireProofsForSkippedExecution) {
            if (stateProver == address(0)) revert PROVER_NOT_CONFIGURED();
            if (stateProof.length == 0) revert PROOF_REQUIRED();
            if (expectedResults.length == 0) revert EXPECTED_RESULTS_REQUIRED();
            
            // Capture initial state
            bytes memory initialState = _captureState(account, hook, prevHook, hookData);
            
            // Decode expected final state from expected results
            bytes memory finalState = _decodeExpectedState(
                account, 
                hook, 
                prevHook, 
                hookData, 
                expectedResults
            );
            
            // Verify state transition with prover
            bool verified = ISuperStateProver(stateProver).verifyStateTransition(
                initialState,
                finalState,
                hookData,
                stateProof
            );
            
            if (!verified) revert PROOF_VERIFICATION_FAILED();
            
            // Apply the state change based on the verified proof
            _applyProvenStateChanges(account, address(hook), hookData, expectedResults);
            
            emit ProofVerified(account, address(hook), true);
            emit HookExecutionSkipped(account, address(hook), true);
        } else {
            // Permissive mode - applying expected results without proof verification
            if (expectedResults.length == 0) revert EXPECTED_RESULTS_REQUIRED();
            
            // Apply the state changes directly from expected results
            _applyProvenStateChanges(account, address(hook), hookData, expectedResults);
            
            emit HookExecutionSkipped(account, address(hook), false);
        }
    }

    // Standard hook execution
    function _processHook(
        address account,
        ISuperHook hook,
        address prevHook,
        bytes memory hookData
    )
        internal
        nonReentrant
    {
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
        _updateAccounting(account, address(hook), hookData, bytes(""));
    }

    // Capture relevant state before execution
    function _captureState(
        address account,
        ISuperHook hook,
        address prevHook,
        bytes memory hookData
    ) internal view returns (bytes memory) {
        ISuperHook.HookType hookType = ISuperHookResult(address(hook)).hookType();
        
        if (hookType == ISuperHook.HookType.INFLOW || hookType == ISuperHook.HookType.OUTFLOW) {
            bytes4 yieldSourceOracleId = hookData.extractYieldSourceOracleId();
            address yieldSource = hookData.extractYieldSource();
            
            // For INFLOW/OUTFLOW hooks, we capture the relevant account balances and state
            return abi.encode(
                account,
                yieldSource,
                yieldSourceOracleId,
                hookType,
                IERC20(yieldSource).balanceOf(account),
                prevHook
            );
        } else {
            // For other hook types, we capture minimal state
            return abi.encode(account, address(hook), hookType, prevHook);
        }
    }
    
    // Decode the expected final state from expected results
    function _decodeExpectedState(
        address account,
        ISuperHook hook,
        address prevHook,
        bytes memory hookData,
        bytes memory expectedResults
    ) internal view returns (bytes memory) {
        ISuperHook.HookType hookType = ISuperHookResult(address(hook)).hookType();
        
        if (hookType == ISuperHook.HookType.INFLOW || hookType == ISuperHook.HookType.OUTFLOW) {
            bytes4 yieldSourceOracleId = hookData.extractYieldSourceOracleId();
            address yieldSource = hookData.extractYieldSource();
            
            // Decode expected values
            (uint256 expectedOutAmount, uint256 expectedUsedShares) = 
                abi.decode(expectedResults, (uint256, uint256));
            
            // For INFLOW/OUTFLOW hooks, we capture the relevant account balances and state
            return abi.encode(
                account,
                yieldSource,
                yieldSourceOracleId,
                hookType,
                IERC20(yieldSource).balanceOf(account) + (
                    hookType == ISuperHook.HookType.INFLOW ? expectedOutAmount : 0
                ) - (
                    hookType == ISuperHook.HookType.OUTFLOW ? expectedOutAmount : 0
                ),
                prevHook,
                expectedOutAmount,
                expectedUsedShares
            );
        } else {
            // For other hook types, we capture minimal state
            return abi.encode(account, address(hook), hookType, prevHook);
        }
    }
    
    // Apply proven state changes without execution
    function _applyProvenStateChanges(
        address account,
        address hook,
        bytes memory hookData,
        bytes memory expectedResults
    ) internal {
        ISuperHook.HookType hookType = ISuperHookResult(hook).hookType();
        
        if (hookType == ISuperHook.HookType.INFLOW || hookType == ISuperHook.HookType.OUTFLOW) {
            bytes4 yieldSourceOracleId = hookData.extractYieldSourceOracleId();
            address yieldSource = hookData.extractYieldSource();
            
            // Decode expected values
            (uint256 expectedOutAmount, uint256 expectedUsedShares) = 
                abi.decode(expectedResults, (uint256, uint256));
            
            // Get config
            ISuperLedgerConfiguration.YieldSourceOracleConfig memory config =
                ledgerConfiguration.getYieldSourceOracleConfig(yieldSourceOracleId);
            if (config.manager == address(0)) revert MANAGER_NOT_SET();
            
            // Update accounting directly with proven values
            uint256 feeAmount = ISuperLedger(config.ledger).updateAccounting(
                account,
                yieldSource,
                yieldSourceOracleId,
                hookType == ISuperHook.HookType.INFLOW,
                expectedOutAmount,
                expectedUsedShares
            );
            
            // Handle fee collection for OUTFLOW
            if (feeAmount > 0 && hookType == ISuperHook.HookType.OUTFLOW) {
                if (feeAmount > expectedOutAmount) revert INVALID_FEE();
                
                // Get the asset token from expected data
                address assetToken = yieldSource; // This is typically the asset token
                
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

    function _updateAccounting(
        address account, 
        address hook, 
        bytes memory hookData, 
        bytes memory expectedResults
    ) internal virtual {
        ISuperHook.HookType _type = ISuperHookResult(hook).hookType();
        if (_type == ISuperHook.HookType.INFLOW || _type == ISuperHook.HookType.OUTFLOW) {
            bytes4 yieldSourceOracleId = hookData.extractYieldSourceOracleId();
            address yieldSource = hookData.extractYieldSource();

            ISuperLedgerConfiguration.YieldSourceOracleConfig memory config =
                ledgerConfiguration.getYieldSourceOracleConfig(yieldSourceOracleId);
            if (config.manager == address(0)) revert MANAGER_NOT_SET();

            // Capture the actual outAmount and usedShares
            uint256 actualOutAmount = ISuperHookResult(address(hook)).outAmount();
            uint256 actualUsedShares = ISuperHookResultOutflow(address(hook)).usedShares();
            
            // If result verification is enabled and expected results are provided
            if (resultVerifier != address(0) && expectedResults.length > 0) {
                // Decode expected results
                (uint256 expectedOutAmount, uint256 expectedUsedShares) = 
                    abi.decode(expectedResults, (uint256, uint256));
                    
                // Verify results match expectations
                bytes memory actualResult = abi.encode(actualOutAmount, actualUsedShares);
                bytes memory expectedResult = abi.encode(expectedOutAmount, expectedUsedShares);
                
                bool verified = ISuperResultVerifier(resultVerifier).verifyResults(
                    account, 
                    hook, 
                    expectedResult, 
                    actualResult
                );
                
                emit ResultsVerified(account, hook, verified);
                
                if (!verified) revert ISuperResultVerifier.RESULTS_MISMATCH();
            }

            // Update accounting and get fee amount if any
            uint256 feeAmount = ISuperLedger(config.ledger).updateAccounting(
                account,
                yieldSource,
                yieldSourceOracleId,
                _type == ISuperHook.HookType.INFLOW,
                actualOutAmount,
                actualUsedShares
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
        internal
        virtual
    {
        uint256 balanceBefore = IERC20(assetToken).balanceOf(feeRecipient);
        _execute(account, assetToken, 0, abi.encodeCall(IERC20.transfer, (feeRecipient, feeAmount)));
        uint256 balanceAfter = IERC20(assetToken).balanceOf(feeRecipient);

        uint256 actualFee = balanceAfter - balanceBefore;
        uint256 maxAllowedDeviation = feeAmount.mulDiv(FEE_TOLERANCE, FEE_TOLERANCE_DENOMINATOR);
        if (actualFee < feeAmount - maxAllowedDeviation || actualFee > feeAmount + maxAllowedDeviation) {
            revert FEE_NOT_TRANSFERRED();
        }
    }

    function _performNativeFeeTransfer(address account, address feeRecipient, uint256 feeAmount) internal virtual {
        uint256 balanceBefore = feeRecipient.balance;

        _execute(account, feeRecipient, feeAmount, "");
        uint256 balanceAfter = feeRecipient.balance;
        if (balanceAfter - balanceBefore != feeAmount) revert FEE_NOT_TRANSFERRED();
    }
}
