// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC7579ExecutorBase } from "modulekit/Modules.sol";
import { IModule } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// Superform
import { ISuperExecutor } from "../interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../interfaces/accounting/ISuperLedger.sol";
import { ISuperLedgerConfiguration } from "../interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperHook, ISuperHookResult, ISuperHookResultOutflow } from "../interfaces/ISuperHook.sol";
import { HookDataDecoder } from "../libraries/HookDataDecoder.sol";
import { IVaultBank } from "../../periphery/interfaces/VaultBank/IVaultBank.sol";

/// @title SuperExecutorBase
/// @author Superform Labs
/// @notice Base contract for Superform executors that processes hook sequences
/// @dev Implements the executor logic for processing hooks in sequence with these key features:
///      1. Chain of hooks execution - Processes hooks in order, passing results between them
///      2. Accounting integration - Updates the ledger based on hook operations
///      3. Fee handling - Calculates and transfers fees for yield-generating operations
///      4. Cross-chain operations - Handles locking assets for cross-chain positions
///      5. ERC-7579 compliance - Integrates with smart account architecture
abstract contract SuperExecutorBase is ERC7579ExecutorBase, ISuperExecutor, ReentrancyGuard {
    using HookDataDecoder for bytes;
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    /// @notice Tracks which accounts have initialized this executor
    /// @dev Used to ensure only initialized accounts can execute operations
    mapping(address => bool) internal _initialized;

    /// @notice Configuration for yield sources and accounting
    /// @dev Provides access to ledger information and fee settings
    ISuperLedgerConfiguration public immutable ledgerConfiguration;

    /// @notice Tolerance for fee transfer verification (numerator)
    /// @dev Used to account for tokens with transfer fees or rounding errors
    uint256 internal constant FEE_TOLERANCE = 10_000;

    /// @notice Denominator for fee tolerance calculation
    /// @dev FEE_TOLERANCE/FEE_TOLERANCE_DENOMINATOR represents the maximum allowed deviation
    uint256 internal constant FEE_TOLERANCE_DENOMINATOR = 100_000;

    /// @notice Initializes the executor with ledger configuration
    /// @dev Sets up the immutable references needed for accounting and fee calculations
    /// @param superLedgerConfiguration_ Address of the ledger configuration contract
    constructor(address superLedgerConfiguration_) {
        if (superLedgerConfiguration_ == address(0)) revert ADDRESS_NOT_VALID();
        ledgerConfiguration = ISuperLedgerConfiguration(superLedgerConfiguration_);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperExecutor
    function isInitialized(address account) external view override(IModule, ISuperExecutor) returns (bool) {
        return _initialized[account];
    }

    /// @inheritdoc ISuperExecutor
    function name() external view virtual returns (string memory);

    /// @inheritdoc ISuperExecutor
    function version() external view virtual returns (string memory);

    /// @notice Verifies if this module is of the specified type
    /// @dev Part of the ERC-7579 module interface
    /// @param typeID The module type identifier to check against
    /// @return True if this module matches the specified type, false otherwise
    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperExecutor
    function onInstall(bytes calldata) external override(IModule, ISuperExecutor) {
        if (_initialized[msg.sender]) revert ALREADY_INITIALIZED();
        _initialized[msg.sender] = true;
    }

    /// @inheritdoc ISuperExecutor
    function onUninstall(bytes calldata) external override(IModule, ISuperExecutor) {
        if (!_initialized[msg.sender]) revert NOT_INITIALIZED();
        _initialized[msg.sender] = false;
    }

    /// @inheritdoc ISuperExecutor
    function execute(bytes calldata data) external virtual {
        if (!_initialized[msg.sender]) revert NOT_INITIALIZED();
        _execute(msg.sender, abi.decode(data, (ExecutorEntry)));
    }

    /// @notice Validates that hook follows secure execution pattern
    function validateHookCompliance(
        address hook,
        address prevHook,
        address account, 
        bytes memory hookData
    ) public view returns (Execution[] memory) {
        Execution[] memory empty = new Execution[](0);
        try ISuperHook(hook).build(prevHook, account, hookData) returns (Execution[] memory executions) {
            if (executions.length < 2) return empty;
            
            // Check FIRST execution is preExecute
            if (executions[0].target != hook) return empty;
            bytes4 firstSelector = bytes4(executions[0].callData);
            if (firstSelector != ISuperHook.preExecute.selector) return empty;
            
            // Check LAST execution is postExecute
            uint256 lastIdx = executions.length - 1;
            if (executions[lastIdx].target != hook) return empty;
            bytes4 lastSelector = bytes4(executions[lastIdx].callData);
            if (lastSelector != ISuperHook.postExecute.selector) return empty;

            // Do not allow any in-between executions to be performed on the same hook
            for (uint256 i = 1; i < lastIdx; i++) {
                if (executions[i].target == hook) return empty;
            }
            
            return executions;
        } catch {
            return empty;
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Processes a set of hooks in sequence
    /// @dev Core execution flow handler that iterates through hooks and processes them
    ///      Hooks are executed in sequence with results from previous hooks available to later ones
    ///      Each hook is processed through the _processHook method
    /// @param account The smart account executing the operation
    /// @param entry The executor entry containing hook addresses and their data
    function _execute(address account, ExecutorEntry memory entry) internal virtual {
        uint256 hooksLen = entry.hooksAddresses.length;

        // Validate we have hooks to execute
        if (hooksLen == 0) revert NO_HOOKS();
        if (hooksLen != entry.hooksData.length) revert LENGTH_MISMATCH();

        // Execute each hook in sequence, passing the previous hook address to each one
        address prevHook;
        address currentHook;
        for (uint256 i; i < hooksLen; ++i) {
            currentHook = entry.hooksAddresses[i];
            if (currentHook == address(0)) revert ADDRESS_NOT_VALID();

            _processHook(account, ISuperHook(currentHook), prevHook, entry.hooksData[i]);
            prevHook = currentHook;
        }
    }

    /// @notice Updates accounting records after hook execution
    /// @dev Integrates with the ledger system to record inflows and outflows
    ///      For INFLOW hooks: Records new share acquisition
    ///      For OUTFLOW hooks: Records share consumption and calculates yield fees
    ///      For NONACCOUNTING hooks: No ledger update is performed
    /// @param account The smart account executing the operation
    /// @param hook The hook that was just executed
    /// @param hookData The data provided to the hook for execution
    function _updateAccounting(address account, address hook, bytes memory hookData) internal virtual {
        ISuperHook.HookType _type = ISuperHookResult(hook).hookType();
        if (_type == ISuperHook.HookType.INFLOW || _type == ISuperHook.HookType.OUTFLOW) {
            // Extract yield source information from the hook data
            bytes4 yieldSourceOracleId = hookData.extractYieldSourceOracleId();
            address yieldSource = hookData.extractYieldSource();

            // Get configuration for the yield source oracle
            ISuperLedgerConfiguration.YieldSourceOracleConfig memory config =
                ledgerConfiguration.getYieldSourceOracleConfig(yieldSourceOracleId);
            if (config.manager == address(0)) revert MANAGER_NOT_SET();

            // Update accounting records and calculate any fees
            uint256 feeAmount = ISuperLedger(config.ledger).updateAccounting(
                account,
                yieldSource,
                yieldSourceOracleId,
                _type == ISuperHook.HookType.INFLOW, // True for inflow, false for outflow
                ISuperHookResult(address(hook)).outAmount(), // Amount of shares or assets processed
                ISuperHookResultOutflow(address(hook)).usedShares() // Shares consumed (for outflows)
            );

            // Handle fee collection for outflows if a fee was generated
            if (feeAmount > 0 && _type == ISuperHook.HookType.OUTFLOW) {
                // Sanity check to ensure fee isn't greater than the output amount
                if (feeAmount > ISuperHookResult(address(hook)).outAmount()) revert INVALID_FEE();

                // Determine token type (native or ERC20) and process fee transfer
                address assetToken = ISuperHookResultOutflow(hook).asset();
                if (assetToken == address(0)) {
                    // Native token handling
                    if (account.balance < feeAmount) revert INSUFFICIENT_BALANCE_FOR_FEE();
                    _performNativeFeeTransfer(account, config.feeRecipient, feeAmount);
                } else {
                    // ERC20 token handling
                    if (IERC20(assetToken).balanceOf(account) < feeAmount) revert INSUFFICIENT_BALANCE_FOR_FEE();
                    _performErc20FeeTransfer(account, assetToken, config.feeRecipient, feeAmount);
                }
            }
        }
    }

    /// @notice Executes an ERC20 token fee transfer from the account
    /// @dev Creates and executes a transfer operation on behalf of the account
    ///      Verifies the transfer was successful by checking recipient balance changes
    ///      Includes tolerance for tokens with transfer fees or rounding issues
    /// @param account The smart account executing the operation
    /// @param assetToken The ERC20 token to transfer
    /// @param feeRecipient The address to receive the fee
    /// @param feeAmount The amount of tokens to transfer as a fee
    function _performErc20FeeTransfer(
        address account,
        address assetToken,
        address feeRecipient,
        uint256 feeAmount
    )
        internal
        virtual
    {
        // Record balance before transfer to verify successful execution
        uint256 balanceBefore = IERC20(assetToken).balanceOf(feeRecipient);

        // Execute the transfer from the account to the fee recipient
        _execute(account, assetToken, 0, abi.encodeCall(IERC20.transfer, (feeRecipient, feeAmount)));

        // Verify the transfer was successful within acceptable tolerance
        uint256 balanceAfter = IERC20(assetToken).balanceOf(feeRecipient);
        uint256 actualFee = balanceAfter - balanceBefore;
        uint256 maxAllowedDeviation = feeAmount.mulDiv(FEE_TOLERANCE, FEE_TOLERANCE_DENOMINATOR);

        // Ensure the actual fee received is within the allowed deviation range
        if (actualFee < feeAmount - maxAllowedDeviation || actualFee > feeAmount + maxAllowedDeviation) {
            revert FEE_NOT_TRANSFERRED();
        }
    }

    /// @notice Executes a native token (ETH/MATIC) fee transfer from the account
    /// @dev Creates and executes a native transfer operation on behalf of the account
    ///      Verifies the transfer was successful by checking recipient balance changes
    /// @param account The smart account executing the operation
    /// @param feeRecipient The address to receive the fee
    /// @param feeAmount The amount of native tokens to transfer as a fee
    function _performNativeFeeTransfer(address account, address feeRecipient, uint256 feeAmount) internal virtual {
        // Record balance before transfer to verify successful execution
        uint256 balanceBefore = feeRecipient.balance;

        // Execute the native token transfer from the account to the fee recipient
        _execute(account, feeRecipient, feeAmount, "");

        // Verify the transfer was successful (exact amount requirement for native tokens)
        uint256 balanceAfter = feeRecipient.balance;
        if (balanceAfter - balanceBefore != feeAmount) revert FEE_NOT_TRANSFERRED();
    }

    /// @notice Processes a single hook through its complete lifecycle
    /// @dev Manages the hook execution flow with these stages:
    ///      1. preExecute - Prepares the hook and validates inputs
    ///      2. build - Generates the execution instructions
    ///      3. execute - Performs the generated executions
    ///      4. postExecute - Finalizes the execution and sets output values
    ///      5. updateAccounting - Updates ledger records based on hook results
    ///      6. checkAndLockForSuperPosition - Handles cross-chain asset locking if needed
    /// @param account The smart account executing the operation
    /// @param hook The hook to process
    /// @param prevHook The previous hook in the sequence (or address(0) if first)
    /// @param hookData The data provided to the hook for execution
    function _processHook(
        address account,
        ISuperHook hook,
        address prevHook,
        bytes memory hookData
    )
        internal
        nonReentrant
    {
        Execution[] memory executions = validateHookCompliance(address(hook), prevHook, account, hookData);
        // STEP 1: Validate hook compliance
        if (executions.length == 0) {
            revert MALICIOUS_HOOK_DETECTED();
        }

        // STEP 2: Build and execute (dual mutexes protect pre/post)
        hook.setCaller();
        _execute(account, executions);

        // STEP 3: Update accounting (both mutexes active, preventing reentrancy)
        _updateAccounting(account, address(hook), hookData);
        
        // STEP 4: Handle cross-chain operations
        _checkAndLockForSuperPosition(account, address(hook));
        
        // STEP 5: Reset both mutexes after all processing complete
        hook.resetExecutionState();
    }

    /// @notice Handles cross-chain asset locking for SuperPosition minting
    /// @dev Checks if the hook specifies a vault bank and destination chain
    ///      If cross-chain operation is needed:
    ///      1. Creates approval for the vault bank to access tokens
    ///      2. Locks the assets in the vault bank for the destination chain
    ///      3. Emits an event to signal the cross-chain operation
    /// @param account The smart account executing the operation
    /// @param hook The hook that contains cross-chain operation details
    function _checkAndLockForSuperPosition(address account, address hook) internal virtual {
        // Get cross-chain operation details from the hook
        address vaultBank = ISuperHookResult(address(hook)).vaultBank();
        uint256 dstChainId = ISuperHookResult(address(hook)).dstChainId();

        // Process cross-chain operation if a vault bank is specified
        if (vaultBank != address(0)) {
            address spToken = ISuperHookResult(hook).spToken();
            uint256 amount = ISuperHookResult(hook).outAmount();

            // Create and execute approval for the vault bank to access tokens
            Execution[] memory execs = new Execution[](1);
            execs[0] = Execution({
                target: spToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (address(vaultBank), amount))
            });
            _execute(account, execs);

            // Ensure destination chain is different from current chain
            if (dstChainId == block.chainid) revert INVALID_CHAIN_ID();

            // Lock assets in the vault bank for cross-chain transfer
            IVaultBank(vaultBank).lockAsset(account, spToken, hook, amount, uint64(dstChainId));
        }
    }
}
