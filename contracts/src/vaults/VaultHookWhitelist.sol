// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IVaultHookWhitelist } from "../interfaces/IVaultHookWhitelist.sol";

/**
 * @title VaultHookWhitelist
 * @notice Manages hook whitelisting and arbitrary calls for a specific vault
 * @dev Controlled by the vault's strategist with timelock protection
 */
abstract contract VaultHookWhitelist is IVaultHookWhitelist {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Timelock duration for whitelisting hooks and arbitrary calls
    uint256 public immutable TIMELOCK_DURATION;

    /// @notice Mapping of hook address to whitelisted status
    mapping(address => bool) public whitelistedHooks;

    /// @notice Mapping of hook address to proposal
    mapping(address => HookProposal) public hookProposals;

    /// @notice Mapping of target and selector to arbitrary call proposal
    mapping(address => mapping(bytes4 => ArbitraryCall)) public arbitraryCallProposals;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(uint256 timelockDuration_) {
        TIMELOCK_DURATION = timelockDuration_;
    }

    /*//////////////////////////////////////////////////////////////
                        HOOK WHITELISTING
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVaultHookWhitelist
    function proposeHook(address hook) external onlyStrategist {
        if (whitelistedHooks[hook]) revert HOOK_ALREADY_WHITELISTED();
        if (hook == address(0)) revert INVALID_HOOK();

        hookProposals[hook] = HookProposal({
            hook: hook,
            proposalTime: block.timestamp,
            executed: false
        });

        emit HookProposed(hook, block.timestamp);
    }

    /// @inheritdoc IVaultHookWhitelist
    function executeHook(address hook) external onlyStrategist {
        HookProposal storage proposal = hookProposals[hook];
        if (proposal.hook == address(0)) revert INVALID_HOOK();
        if (proposal.executed) revert HOOK_ALREADY_WHITELISTED();
        if (block.timestamp < proposal.proposalTime + TIMELOCK_DURATION) revert TIMELOCK_NOT_EXPIRED();

        whitelistedHooks[hook] = true;
        proposal.executed = true;

        emit HookWhitelisted(hook);
    }

    /// @inheritdoc IVaultHookWhitelist
    function revokeHook(address hook) external onlyStrategist {
        if (!whitelistedHooks[hook]) revert HOOK_NOT_WHITELISTED();

        whitelistedHooks[hook] = false;
        delete hookProposals[hook];

        emit HookRevoked(hook);
    }

    /*//////////////////////////////////////////////////////////////
                        ARBITRARY CALLS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVaultHookWhitelist
    function proposeArbitraryCall(address target, bytes calldata data) external onlyStrategist {
        if (target == address(0)) revert INVALID_CALL();
        if (data.length < 4) revert INVALID_CALL();

        bytes4 selector = bytes4(data[:4]);
        if (arbitraryCallProposals[target][selector].proposalTime != 0 && 
            !arbitraryCallProposals[target][selector].executed) revert CALL_ALREADY_PROPOSED();

        arbitraryCallProposals[target][selector] = ArbitraryCall({
            target: target,
            selector: selector,
            data: data,
            proposalTime: block.timestamp,
            executed: false
        });

        emit ArbitraryCallProposed(target, selector, data, block.timestamp);
    }

    /// @inheritdoc IVaultHookWhitelist
    function executeArbitraryCall(address target, bytes calldata data) external onlyStrategist {
        if (data.length < 4) revert INVALID_CALL();
        bytes4 selector = bytes4(data[:4]);

        ArbitraryCall storage proposal = arbitraryCallProposals[target][selector];
        if (proposal.proposalTime == 0) revert CALL_NOT_PROPOSED();
        if (proposal.executed) revert CALL_ALREADY_EXECUTED();
        if (block.timestamp < proposal.proposalTime + TIMELOCK_DURATION) revert TIMELOCK_NOT_EXPIRED();
        if (keccak256(proposal.data) != keccak256(data)) revert INVALID_CALL();

        proposal.executed = true;

        (bool success,) = target.call(data);
        if (!success) revert CALL_FAILED();

        emit ArbitraryCallExecuted(target, selector);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVaultHookWhitelist
    function isHookWhitelisted(address hook) external view returns (bool) {
        return whitelistedHooks[hook];
    }

    /// @inheritdoc IVaultHookWhitelist
    function getHookProposal(address hook) external view returns (HookProposal memory) {
        return hookProposals[hook];
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Only allow the strategist to call this function
    modifier onlyStrategist() virtual;
} 