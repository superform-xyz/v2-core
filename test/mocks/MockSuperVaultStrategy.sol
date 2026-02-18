// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Execution } from "../../src/interfaces/ISuperHook.sol";
import { ISuperHook, ISuperHookResult, ISuperHookContextAware } from "../../src/interfaces/ISuperHook.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title MockSuperVaultStrategy
/// @author Superform Labs
/// @notice Mock contract to simulate SuperVault's executeHooks method for testing hooks in v2-core
/// @dev Mimics the execution flow of SuperVaultStrategy._processSingleHookExecution
contract MockSuperVaultStrategy {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error OPERATION_FAILED();
    error ZERO_LENGTH();
    error INVALID_ARRAY_LENGTH();
    error MINIMUM_OUTPUT_AMOUNT_NOT_MET();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event HookExecuted(address indexed hook, address indexed prevHook, bytes hookCalldata);
    event HooksExecuted(address[] hooks);

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Manager address that can call executeHooks
    address public manager;

    /// @notice List of registered hooks (empty check = all hooks allowed for simplicity in testing)
    mapping(address => bool) public registeredHooks;

    /// @notice Whether to skip hook registration check (for flexible testing)
    bool public skipHookRegistrationCheck;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address manager_) {
        manager = manager_;
        skipHookRegistrationCheck = true; // Default to skip for easier testing
    }

    /// @notice Allows the contract to receive native ETH
    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                              CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Register a hook for execution
    /// @param hook The hook address to register
    function registerHook(address hook) external {
        registeredHooks[hook] = true;
    }

    /// @notice Unregister a hook
    /// @param hook The hook address to unregister
    function unregisterHook(address hook) external {
        registeredHooks[hook] = false;
    }

    /// @notice Set whether to skip hook registration check
    /// @param skip Whether to skip the check
    function setSkipHookRegistrationCheck(bool skip) external {
        skipHookRegistrationCheck = skip;
    }

    /// @notice Set manager address
    /// @param manager_ New manager address
    function setManager(address manager_) external {
        manager = manager_;
    }

    /*//////////////////////////////////////////////////////////////
                         EXECUTE HOOKS (CORE)
    //////////////////////////////////////////////////////////////*/

    /// @notice Arguments for executeHooks
    /// @param hooks Array of hook addresses to execute
    /// @param hookCalldata Array of calldata for each hook
    /// @param expectedAssetsOrSharesOut Minimum expected output for each hook (slippage protection)
    struct ExecuteArgs {
        address[] hooks;
        bytes[] hookCalldata;
        uint256[] expectedAssetsOrSharesOut;
    }

    /// @notice Execute a sequence of hooks (mimics SuperVaultStrategy.executeHooks)
    /// @dev This is a simplified version for testing - skips Merkle proof validation
    /// @param args The execution arguments
    function executeHooks(ExecuteArgs calldata args) external payable {
        uint256 hooksLength = args.hooks.length;
        if (hooksLength == 0) revert ZERO_LENGTH();
        if (args.hookCalldata.length != hooksLength) revert INVALID_ARRAY_LENGTH();
        if (args.expectedAssetsOrSharesOut.length != hooksLength) revert INVALID_ARRAY_LENGTH();

        address prevHook;
        for (uint256 i; i < hooksLength; ++i) {
            address hook = args.hooks[i];

            // Skip hook registration check if configured (for testing flexibility)
            if (!skipHookRegistrationCheck && !registeredHooks[hook]) {
                revert OPERATION_FAILED();
            }

            prevHook = _processSingleHookExecution(
                hook,
                prevHook,
                args.hookCalldata[i],
                args.expectedAssetsOrSharesOut[i]
            );
        }

        emit HooksExecuted(args.hooks);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Process a single hook execution (mimics SuperVaultStrategy._processSingleHookExecution)
    /// @param hook The hook to execute
    /// @param prevHook The previous hook in the chain
    /// @param hookCalldata The calldata for this hook
    /// @param expectedAssetsOrSharesOut Minimum expected output
    /// @return The current hook address (for chaining)
    function _processSingleHookExecution(
        address hook,
        address prevHook,
        bytes memory hookCalldata,
        uint256 expectedAssetsOrSharesOut
    )
        internal
        returns (address)
    {
        // 1. Set execution context (tells hook who the "account" is)
        ISuperHook(hook).setExecutionContext(address(this));

        // 2. Build executions from hook
        Execution[] memory executions = ISuperHook(hook).build(prevHook, address(this), hookCalldata);

        // 3. Execute each operation
        for (uint256 j; j < executions.length; ++j) {
            (bool success,) = executions[j].target.call{ value: executions[j].value }(executions[j].callData);
            if (!success) revert OPERATION_FAILED();
        }

        // 4. Reset execution state
        ISuperHook(hook).resetExecutionState(address(this));

        // 5. Check minimum output
        uint256 actualOutput = ISuperHookResult(hook).getOutAmount(address(this));
        if (actualOutput < expectedAssetsOrSharesOut) {
            revert MINIMUM_OUTPUT_AMOUNT_NOT_MET();
        }

        emit HookExecuted(hook, prevHook, hookCalldata);

        return hook;
    }
}
