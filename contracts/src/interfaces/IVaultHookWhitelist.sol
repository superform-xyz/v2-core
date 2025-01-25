// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

/**
 * @title IVaultHookWhitelist
 * @notice Interface for managing hook whitelisting and arbitrary calls for a vault
 */
interface IVaultHookWhitelist {
    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Hook proposal struct
    struct HookProposal {
        address hook;
        uint256 proposalTime;
        bool executed;
    }

    /// @notice Arbitrary call struct
    struct ArbitraryCall {
        address target;
        bytes4 selector;
        bytes data;
        uint256 proposalTime;
        bool executed;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a hook is proposed
    event HookProposed(address indexed hook, uint256 proposalTime);

    /// @notice Emitted when a hook is whitelisted
    event HookWhitelisted(address indexed hook);

    /// @notice Emitted when a hook is revoked
    event HookRevoked(address indexed hook);

    /// @notice Emitted when an arbitrary call is proposed
    event ArbitraryCallProposed(address indexed target, bytes4 indexed selector, bytes data, uint256 proposalTime);

    /// @notice Emitted when an arbitrary call is executed
    event ArbitraryCallExecuted(address indexed target, bytes4 indexed selector);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Hook not whitelisted
    error HOOK_NOT_WHITELISTED();

    /// @notice Hook already whitelisted
    error HOOK_ALREADY_WHITELISTED();

    /// @notice Invalid hook
    error INVALID_HOOK();

    /// @notice Timelock not expired
    error TIMELOCK_NOT_EXPIRED();

    /// @notice Invalid call
    error INVALID_CALL();

    /// @notice Call already proposed
    error CALL_ALREADY_PROPOSED();

    /// @notice Call already executed
    error CALL_ALREADY_EXECUTED();

    /// @notice Call not proposed
    error CALL_NOT_PROPOSED();

    /// @notice Call failed
    error CALL_FAILED();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Propose a new hook to be whitelisted
    /// @param hook The hook to propose
    function proposeHook(address hook) external;

    /// @notice Execute a hook proposal after timelock expires
    /// @param hook The hook to execute
    function executeHook(address hook) external;

    /// @notice Revoke a whitelisted hook
    /// @param hook The hook to revoke
    function revokeHook(address hook) external;

    /// @notice Propose an arbitrary call
    /// @param target The target address
    /// @param data The call data
    function proposeArbitraryCall(address target, bytes calldata data) external;

    /// @notice Execute an arbitrary call after timelock expires
    /// @param target The target address
    /// @param data The call data
    function executeArbitraryCall(address target, bytes calldata data) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if a hook is whitelisted
    /// @param hook The hook to check
    /// @return Whether the hook is whitelisted
    function isHookWhitelisted(address hook) external view returns (bool);

    /// @notice Get a hook proposal
    /// @param hook The hook to get the proposal for
    /// @return The hook proposal
    function getHookProposal(address hook) external view returns (HookProposal memory);
} 