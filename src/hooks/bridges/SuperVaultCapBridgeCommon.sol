// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../vendor/BytesLib.sol";

// Superform
import { ISuperExecutor } from "../../interfaces/ISuperExecutor.sol";

/// @notice Minimal view of the SuperGovernor address book (SuperVault periphery). Declared locally
///         so the cap hooks have no dependency on the periphery package (v2-core is periphery's
///         dependency, not the reverse).
interface ISuperGovernorAddressBook {
    function getAddress(bytes32 key) external view returns (address);
}

/// @notice Minimal view of the cross-chain cap guard (SuperVault periphery). Besides the cap check
///         it serves the governance-set destination-execution policy: approved transport adapters,
///         the canonical destination hook pair, and the LayerZero EID -> EVM chain id map.
interface ICrossChainPositionCapGuard {
    function validateAllocation(
        address strategy,
        uint64 destinationChainId,
        address destinationVault,
        uint256 amount
    )
        external
        view;

    function isApprovedAdapter(uint64 chainId, address adapter) external view returns (bool);

    function destinationHooks(uint64 chainId) external view returns (address approveHook, address depositHook);

    function chainIdForEid(uint32 eid) external view returns (uint64);
}

/// @notice Minimal surface of the cross-chain position registry (SuperVault periphery). Note
///         `recordBridgedOut` is state-mutating and mints a reservation bound to the exact
///         (strategy, chain, vault, amount) tuple validated here.
interface ICrossChainPositionRegistry {
    function recordBridgedOut(
        address strategy,
        uint64 chainId,
        address destinationVault,
        uint256 amount
    )
        external
        returns (bytes32 reservationId);
}

/// @title SuperVaultCapBridgeCommon
/// @author Superform Labs
/// @notice Shared cross-chain-cap enforcement for the SuperVault*CapBridgeHook family. Binds the
///         cap to the ECONOMIC destination, not the bridge transport:
///         - the transport receiver must be a governance-approved destination adapter for the
///           canonical destination chain;
///         - the destination message must decode to a strictly typed destination action — either
///           an idle-hold (no destination hooks; funds stay on the hub-controlled destination
///           account) or a vault deposit (exactly [approve, deposit] using the governance-pinned
///           destination hook pair, approving and depositing into ONE vault, with the account as
///           the share receiver by construction of the destination deposit hook);
///         - the cap is validated and the in-flight reservation recorded against the canonical
///           (chainId, destinationVault) extracted from that action, never against the transport
///           receiver.
/// @dev The destination message layout is the shared Superform bridge payload
///      `abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts)` consumed by
///      every destination adapter (Across/deBridge/Stargate) and forwarded to
///      SuperDestinationExecutor, which executes `executorCalldata` ON `account`. The destination
///      deposit hook (Deposit4626VaultHook) always credits shares to that same account, so pinning
///      (account == hub strategy) + (deposit target == destinationVault) yields a hub-controlled
///      position in exactly the approved vault.
abstract contract SuperVaultCapBridgeCommon {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Typed destination actions a capped bridge may encode — nothing else is bridgeable.
    uint8 public constant ACTION_IDLE_HOLD = 0;
    uint8 public constant ACTION_VAULT_DEPOSIT = 1;

    /// @dev SuperGovernor address-book keys — identical to the periphery constants so the resolved
    ///      guard/registry match what the cap math reads.
    bytes32 internal constant CROSS_CHAIN_CAP_GUARD = keccak256("CROSS_CHAIN_CAP_GUARD");
    bytes32 internal constant CROSS_CHAIN_POSITION_REGISTRY = keccak256("CROSS_CHAIN_POSITION_REGISTRY");

    /// @dev Destination hook data layouts (v2-core hooks, pinned by governance via
    ///      `destinationHooks(chainId)`): ApproveERC20Hook spender at offset 72; the
    ///      Deposit4626VaultHook yieldSource at offset 32 (the standard 52-byte header's second
    ///      field).
    uint256 private constant DST_APPROVE_SPENDER_OFFSET = 72;
    uint256 private constant DST_APPROVE_MIN_LENGTH = 92;
    uint256 private constant DST_DEPOSIT_VAULT_OFFSET = 32;
    uint256 private constant DST_DEPOSIT_MIN_LENGTH = 52;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice The bridge transport receiver is not an approved destination adapter for the chain
    error TRANSPORT_ADAPTER_NOT_APPROVED();
    /// @notice The destination message's account is not the hub strategy account
    error DESTINATION_ACCOUNT_NOT_VALID();
    /// @notice The destination message does not encode a permitted typed destination action
    error DESTINATION_ACTION_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice SuperGovernor address book — single source of truth for the cap guard and position
    ///         registry, resolved at execution time (SuperVault periphery).
    ISuperGovernorAddressBook public immutable SUPER_GOVERNOR;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @dev Zero-check is done by the concrete hook (which owns the BaseHook error namespace).
    constructor(address superGovernor_) {
        SUPER_GOVERNOR = ISuperGovernorAddressBook(superGovernor_);
    }

    /*//////////////////////////////////////////////////////////////
                            SHARED ENFORCEMENT
    //////////////////////////////////////////////////////////////*/

    /// @dev Resolve the cap guard from SuperGovernor at call time (same key the periphery uses).
    function _capGuard() internal view returns (ICrossChainPositionCapGuard) {
        return ICrossChainPositionCapGuard(SUPER_GOVERNOR.getAddress(CROSS_CHAIN_CAP_GUARD));
    }

    /// @dev Full runtime enforcement, called from the concrete hook's `_preExecute` AFTER it has
    ///      decoded the transport tuple: adapter allowlist -> typed destination action -> account
    ///      binding -> cap check -> reservation record. Reverting here aborts the whole
    ///      executeHooks batch.
    function _enforceCrossChainCap(
        address account,
        uint64 chainId,
        address transportAdapter,
        uint256 amount,
        bytes memory destinationMessage
    )
        internal
    {
        ICrossChainPositionCapGuard guard = _capGuard();
        if (!guard.isApprovedAdapter(chainId, transportAdapter)) revert TRANSPORT_ADAPTER_NOT_APPROVED();

        (, address destinationVault, address dstAccount) = _decodeDestinationAction(destinationMessage, chainId, guard);

        // The destination account IS the hub strategy account (deterministic same-address account
        // across chains) — the only hub-verifiable "hub-controlled destination account" binding.
        // Runtime-only: `inspect` cannot know the executing account.
        if (dstAccount != account) revert DESTINATION_ACCOUNT_NOT_VALID();

        guard.validateAllocation(account, chainId, destinationVault, amount);
        ICrossChainPositionRegistry(SUPER_GOVERNOR.getAddress(CROSS_CHAIN_POSITION_REGISTRY))
            .recordBridgedOut(account, chainId, destinationVault, amount);
    }

    /// @dev Leaf suffix shared by every cap hook's `inspect`: pins the cap guard, the CANONICAL
    ///      destination chain id, the economic destination vault, the typed destination action and
    ///      the amount-source mode. Kept as one helper so hook `inspect` overrides stay shallow
    ///      (no via_ir in the default profile).
    function _capLeafSuffix(
        uint64 chainId,
        bytes memory destinationMessage,
        bool usePrevHookAmount
    )
        internal
        view
        returns (bytes memory)
    {
        ICrossChainPositionCapGuard guard = _capGuard();
        (uint8 actionType, address destinationVault,) = _decodeDestinationAction(destinationMessage, chainId, guard);
        return abi.encodePacked(address(guard), chainId, destinationVault, actionType, usePrevHookAmount);
    }

    /// @dev Decode and strictly type the destination action carried by `destinationMessage` (the
    ///      raw 5-tuple, WITHOUT the signature the parent appends at build time).
    ///      Permitted shapes:
    ///      - IDLE_HOLD: a well-formed `execute(ExecutorEntry)` with ZERO hooks — the bridged funds
    ///        stay on the hub-controlled destination account (destinationVault == address(0));
    ///      - VAULT_DEPOSIT: exactly [approveHook, depositHook] (the governance-pinned pair for the
    ///        chain), the approve spender equal to the deposit target — that target is the
    ///        canonical destination vault.
    ///      Anything else — a raw transfer (empty message), foreign executor selector, extra or
    ///      unknown hooks, spender/vault mismatch — reverts.
    function _decodeDestinationAction(
        bytes memory destinationMessage,
        uint64 chainId,
        ICrossChainPositionCapGuard guard
    )
        internal
        view
        returns (uint8 actionType, address destinationVault, address dstAccount)
    {
        // A capped bridge must always carry a destination action; an empty message would be a raw
        // token transfer to the transport receiver — no deposit, no controlled shares.
        if (destinationMessage.length == 0) revert DESTINATION_ACTION_NOT_VALID();

        bytes memory executorCalldata;
        (, executorCalldata, dstAccount,,) =
            abi.decode(destinationMessage, (bytes, bytes, address, address[], uint256[]));

        if (executorCalldata.length < 4 || bytes4(executorCalldata) != ISuperExecutor.execute.selector) {
            revert DESTINATION_ACTION_NOT_VALID();
        }
        bytes memory entryData = abi.decode(BytesLib.slice(executorCalldata, 4, executorCalldata.length - 4), (bytes));
        ISuperExecutor.ExecutorEntry memory entry = abi.decode(entryData, (ISuperExecutor.ExecutorEntry));

        uint256 hooksLen = entry.hooksAddresses.length;
        if (hooksLen != entry.hooksData.length) revert DESTINATION_ACTION_NOT_VALID();

        if (hooksLen == 0) {
            return (ACTION_IDLE_HOLD, address(0), dstAccount);
        }

        if (hooksLen != 2) revert DESTINATION_ACTION_NOT_VALID();

        (address approveHook, address depositHook) = guard.destinationHooks(chainId);
        if (approveHook == address(0) || depositHook == address(0)) revert DESTINATION_ACTION_NOT_VALID();
        if (entry.hooksAddresses[0] != approveHook || entry.hooksAddresses[1] != depositHook) {
            revert DESTINATION_ACTION_NOT_VALID();
        }

        if (entry.hooksData[1].length < DST_DEPOSIT_MIN_LENGTH || entry.hooksData[0].length < DST_APPROVE_MIN_LENGTH) {
            revert DESTINATION_ACTION_NOT_VALID();
        }
        destinationVault = BytesLib.toAddress(entry.hooksData[1], DST_DEPOSIT_VAULT_OFFSET);
        if (destinationVault == address(0)) revert DESTINATION_ACTION_NOT_VALID();
        // The approve spender must be the deposit target: no allowance may be granted to any other
        // address on the destination.
        if (BytesLib.toAddress(entry.hooksData[0], DST_APPROVE_SPENDER_OFFSET) != destinationVault) {
            revert DESTINATION_ACTION_NOT_VALID();
        }

        return (ACTION_VAULT_DEPOSIT, destinationVault, dstAccount);
    }
}
