// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

interface ISuperHookMinimal {
    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice The amount of tokens processed by the hook
    function outAmount() external view returns (uint256);

    /// @notice The lock/unlock flag of the hook
    function lockFlag() external view returns (uint8);

    /// @notice The lock/unlock token of the hook
    function spToken() external view returns (address);

    /// @notice The type of hook
    function hookType() external view returns (ISuperHook.HookType);
}

interface ISuperHook {
    /*//////////////////////////////////////////////////////////////
                                 ENUMS
    //////////////////////////////////////////////////////////////*/
    enum HookType {
        NONACCOUNTING,
        INFLOW,
        OUTFLOW
    }

    /**
        lock = true, unlock = false → 00000001 (1)
        lock = false, unlock = true → 00000010 (2)
        lock = true, unlock = true → 00000011 (3)
        lock = false, unlock = false → 00000000 (0)

        uint8 flags = (lock ? 1 : 0) | (unlock ? 2 : 0);
    */

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NOT_AUTHORIZED();
    error AMOUNT_NOT_VALID();
    error ADDRESS_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Build the execution array for the hook
    /// @param prevHook The previous hook
    /// @param data The data to build the execution array from
    /// @return executions The execution array
    function build(address prevHook, bytes memory data) external view returns (Execution[] memory executions);

    /*//////////////////////////////////////////////////////////////
                                 PUBLIC METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Pre-hook operation
    /// @param prevHook The previous hook
    /// @param data The data to pre-hook
    function preExecute(address prevHook, bytes memory data) external;

    /// @notice Post-hook operation
    /// @param prevHook The previous hook
    /// @param data The data to post-hook
    function postExecute(address prevHook, bytes memory data) external;

}
