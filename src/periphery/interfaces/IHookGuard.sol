// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/// @title IHookGuard
interface IHookGuard {
    /*//////////////////////////////////////////////////////////////
                                  STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct Record {
        address addr; // target or argument
        uint40 eta; // >0 when staged, can activate after block.timestamp>=eta
        bool live; // becomes true on activation
        bool vetoed; // guardian veto
    }


    /*//////////////////////////////////////////////////////////////
                                  ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when the caller is not the main strategist

    error NOT_MAIN_STRATEGIST();
    /// @notice Thrown when an entry has been vetoed
    error VETOED_ENTRY();
    /// @notice Thrown when an entry is in an invalid state
    error BAD_STATE();
    /// @notice Thrown when a target is not found
    error TARGET_NOT_FOUND();
    /// @notice Thrown when an argument is not found
    error ARG_NOT_FOUND();
    /// @notice Thrown when caller is not the guardian
    error NOT_GUARDIAN();
    /// @notice Thrown when no data is provided
    error NO_DATA();
    /// @notice Thrown when an address is not on the allow-list
    error NOT_ALLOWED();

    /*//////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a target is staged for allowlisting
    /// @param strat Strategy address that requested the staging
    /// @param hook Hook contract address
    /// @param idx Index for the target in the hook
    /// @param target Target address being staged
    /// @param eta Timestamp when the target can be activated
    event TargetStaged(address indexed strat, address indexed hook, uint8 indexed idx, address target, uint40 eta);

    /// @notice Emitted when a target is activated
    /// @param strat Strategy address that requested the activation
    /// @param hook Hook contract address
    /// @param idx Index for the target in the hook
    /// @param target Target address being activated
    event TargetActivated(address indexed strat, address indexed hook, uint8 indexed idx, address target);

    /// @notice Emitted when a target is revoked
    /// @param strat Strategy address that requested the revocation
    /// @param hook Hook contract address
    /// @param idx Index for the target in the hook
    /// @param target Target address being revoked
    event TargetRevoked(address indexed strat, address indexed hook, uint8 indexed idx, address target);

    /// @notice Emitted when a target's veto status is changed
    /// @param strat Strategy address
    /// @param hook Hook contract address
    /// @param idx Index for the target in the hook
    /// @param target Target address
    /// @param vetoed Whether the target is vetoed (true) or unvetoed (false)
    event TargetVetoStatusChanged(
        address indexed strat, address indexed hook, uint8 indexed idx, address target, bool vetoed
    );

    /// @notice Emitted when an argument is staged for allowlisting
    /// @param strat Strategy address that requested the staging
    /// @param hook Hook contract address
    /// @param idx Index for the argument in the hook
    /// @param arg Argument address being staged
    /// @param eta Timestamp when the argument can be activated
    event ArgStaged(address indexed strat, address indexed hook, uint8 indexed idx, address arg, uint40 eta);

    /// @notice Emitted when an argument is activated
    /// @param strat Strategy address that requested the activation
    /// @param hook Hook contract address
    /// @param idx Index for the argument in the hook
    /// @param arg Argument address being activated
    event ArgActivated(address indexed strat, address indexed hook, uint8 indexed idx, address arg);

    /// @notice Emitted when an argument is revoked
    /// @param strat Strategy address that requested the revocation
    /// @param hook Hook contract address
    /// @param idx Index for the argument in the hook
    /// @param arg Argument address being revoked
    event ArgRevoked(address indexed strat, address indexed hook, uint8 indexed idx, address arg);

    /// @notice Emitted when an argument's veto status is changed
    /// @param strat Strategy address
    /// @param hook Hook contract address
    /// @param idx Index for the argument in the hook
    /// @param arg Argument address
    /// @param vetoed Whether the argument is vetoed (true) or unvetoed (false)
    event ArgVetoStatusChanged(
        address indexed strat, address indexed hook, uint8 indexed idx, address arg, bool vetoed
    );

    /*//////////////////////////////////////////////////////////////
                    VETOING AND HOOK GUARD
    //////////////////////////////////////////////////////////////*/
    /// @notice Veto a target by the guardian
    /// @param strategy Strategy address
    /// @param hook Hook contract address
    /// @param idx Index for the target in the hook
    /// @param target Target address to veto
    /// @param vetoed Whether to veto (true) or unveto (false)
    function vetoTarget(address strategy, address hook, uint8 idx, address target, bool vetoed) external;

    /// @notice Veto an argument by the guardian
    /// @param strategy Strategy address
    /// @param hook Hook contract address
    /// @param idx Index for the argument in the hook
    /// @param arg Argument address to veto
    /// @param vetoed Whether to veto (true) or unveto (false)
    function vetoArg(address strategy, address hook, uint8 idx, address arg, bool vetoed) external;

    /// @notice Enforces that a hook and its arguments are on the allow-list
    /// @param hook Hook contract address
    /// @param all Array of addresses: [target, arg1, arg2, ...]
    function enforceGlobalGuardedHookExecution(address hook, address[] calldata all) external view;
}
