// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;
interface IHookWhitelist {

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event HookProposed(address hook, uint256 proposalTime);
    event HookWhitelisted(address hook);
    event HookRevoked(address hook);
    event ArbitraryCallProposed(address target, bytes4 selector, bytes data, uint256 proposalTime);

    event ArbitraryCallExecuted(address target, bytes4 selector);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error HOOK_ALREADY_WHITELISTED();
    error HOOK_NOT_WHITELISTED();
    error TIMELOCK_NOT_EXPIRED();
    error INVALID_HOOK();
    error INVALID_CALL();
    error CALL_ALREADY_PROPOSED();
    error CALL_NOT_PROPOSED();
    error CALL_FAILED();

    /*//////////////////////////////////////////////////////////////
                            DATA TYPES
    //////////////////////////////////////////////////////////////*/

    struct HookProposal {
        address hook;
        uint256 proposalTime;
        bool executed;
    }
    struct ArbitraryCall {
        address target;
        bytes4 selector;
        bytes data;
        uint256 proposalTime;
        bool executed;
    }

    /*//////////////////////////////////////////////////////////////
                            FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Propose a new hook to be whitelisted
    /// @param hook The hook address to whitelist
    function proposeHook(address hook) external;

    /// @notice Execute a proposed hook after timelock
    /// @param hook The hook address to whitelist
    function executeHook(address hook) external;

    /// @notice Revoke a whitelisted hook
    /// @param hook The hook address to revoke
    function revokeHook(address hook) external;

    /// @notice Check if a hook is whitelisted
    /// @param hook The hook address to check
    function isHookWhitelisted(address hook) external view returns (bool);

    /// @notice Get the proposal for a hook
    /// @param hook The hook address to get the proposal for
    function getHookProposal(address hook) external view returns (HookProposal memory);

    /// @notice Propose an arbitrary call
    /// @param target The contract to call
    /// @param data The call data
    function proposeArbitraryCall(address target, bytes calldata data) external;

    /// @notice Execute a proposed arbitrary call after timelock
    /// @param target The contract to call
    /// @param data The call data
    function executeArbitraryCall(address target, bytes calldata data) external;
    
    /// @notice Get the arbitrary call proposal
    /// @param target The target contract
    /// @param selector The function selector
    function getArbitraryCallProposal(address target, bytes4 selector) external view returns (ArbitraryCall memory);
} 