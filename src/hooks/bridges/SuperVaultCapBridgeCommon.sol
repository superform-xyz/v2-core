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

    function destinationVaultAsset(uint64 chainId, address vault) external view returns (address);

    function stargateDstToken(address srcPool, uint64 chainId) external view returns (address);

    function stargateMinDeliveryBps() external view returns (uint256);
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

    /// @notice R3-PF1: the guaranteed delivery must be at least this fraction of the RESERVED
    ///         source amount. Must equal the periphery registry's MIN_CONFIRMATION_BPS so that a
    ///         route whose delivery minimum passes here is always confirmable there — the
    ///         reservation, the destination action and the confirmation floor share one bound.
    ///         Assumes same-asset routes with equal source/destination decimals (the only routes
    ///         this hook family supports).
    uint256 public constant MIN_SOURCE_DELIVERY_BPS = 9000;

    /// @dev SuperGovernor address-book keys — identical to the periphery constants so the resolved
    ///      guard/registry match what the cap math reads.
    bytes32 internal constant CROSS_CHAIN_CAP_GUARD = keccak256("CROSS_CHAIN_CAP_GUARD");
    bytes32 internal constant CROSS_CHAIN_POSITION_REGISTRY = keccak256("CROSS_CHAIN_POSITION_REGISTRY");

    /// @dev Destination hook data layouts (v2-core hooks, pinned by governance via
    ///      `destinationHooks(chainId)`): ApproveERC20Hook token at 52, spender at 72, amount at
    ///      92, usePrevHookAmount at 124; Deposit4626VaultHook yieldSource at 32 (the standard
    ///      52-byte header's second field), usePrevHookAmount at 84.
    uint256 private constant DST_APPROVE_TOKEN_OFFSET = 52;
    uint256 private constant DST_APPROVE_SPENDER_OFFSET = 72;
    uint256 private constant DST_APPROVE_AMOUNT_OFFSET = 92;
    uint256 private constant DST_APPROVE_USE_PREV_OFFSET = 124;
    uint256 private constant DST_APPROVE_MIN_LENGTH = 125;
    uint256 private constant DST_DEPOSIT_VAULT_OFFSET = 32;
    uint256 private constant DST_DEPOSIT_USE_PREV_OFFSET = 84;
    uint256 private constant DST_DEPOSIT_MIN_LENGTH = 85;

    /// @notice A decoded, strictly-typed destination action (R2-B1: economics fully bound)
    struct DestinationAction {
        uint8 actionType;
        address destinationVault; // address(0) for idle-hold
        address dstAccount; // must equal the hub strategy account (checked in _enforceCrossChainCap)
        address dstToken; // the single destination token the executor attests arrival of
        uint256 actionAmount; // the intent/approve/deposit amount — bound to the bridge minimum
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice The bridge transport receiver is not an approved destination adapter for the chain
    error TRANSPORT_ADAPTER_NOT_APPROVED();
    /// @notice The destination message's account is not the hub strategy account
    error DESTINATION_ACCOUNT_NOT_VALID();
    /// @notice The destination message does not encode a permitted typed destination action
    error DESTINATION_ACTION_NOT_VALID();
    /// @notice The destination action amount is not bound to the bridge's guaranteed delivery
    error DESTINATION_AMOUNT_NOT_BOUND();
    /// @notice The bridge's guaranteed delivery is below the floor fraction of the reserved amount
    error DELIVERY_BELOW_RESERVATION_FLOOR();
    /// @notice The destination action token is not the token the bridge delivers
    error DESTINATION_TOKEN_NOT_BOUND();
    /// @notice The destination action token is not the governance-pinned asset of the vault
    error DESTINATION_VAULT_ASSET_NOT_BOUND();

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
    ///      binding -> token/amount binding (R2-B1) -> cap check -> reservation record. Reverting
    ///      here aborts the whole executeHooks batch.
    /// @param minDeliveredAmount The MINIMUM amount the bridge guarantees to deliver on the
    ///        destination (Across outputAmount / deBridge takeAmount / Stargate minAmountLD,
    ///        prev-hook-scaled where the parent scales it). The destination action must consume
    ///        exactly this: a smaller independently-encoded deposit would leave a bridged
    ///        remainder idle while the full reservation later settles (R2-B1 trace).
    /// @param expectedDstToken The bridge's destination-side output token when the hub knows it
    ///        (Across outputToken / deBridge takeToken); address(0) when the destination token
    ///        address is not hub-derivable (Stargate OFT) — the executor's balance attestation
    ///        over dstTokens[0] is then the arrival binding.
    function _enforceCrossChainCap(
        address account,
        uint64 chainId,
        address transportAdapter,
        uint256 amount,
        uint256 minDeliveredAmount,
        address expectedDstToken,
        bytes memory destinationMessage
    )
        internal
    {
        ICrossChainPositionCapGuard guard = _capGuard();
        if (!guard.isApprovedAdapter(chainId, transportAdapter)) revert TRANSPORT_ADAPTER_NOT_APPROVED();

        DestinationAction memory action = _decodeDestinationAction(destinationMessage, chainId, guard);

        // The destination account IS the hub strategy account (deterministic same-address account
        // across chains) — the only hub-verifiable "hub-controlled destination account" binding.
        // Runtime-only: `inspect` cannot know the executing account.
        if (action.dstAccount != account) revert DESTINATION_ACCOUNT_NOT_VALID();

        // R2-B1: the destination action must consume the full guaranteed delivery — the intent
        // (executor balance attestation) and, for deposits, the approve/deposit amount all equal
        // the bridge minimum. Any residual is then bounded by (actual fill − guaranteed minimum),
        // i.e. slippage dust, never an independently-chosen smaller deposit.
        if (minDeliveredAmount == 0 || action.actionAmount != minDeliveredAmount) {
            revert DESTINATION_AMOUNT_NOT_BOUND();
        }
        // R3-PF1: the guaranteed delivery must nearly cover the RESERVATION — otherwise a route
        // could reserve 100, deliver/deposit 85, and the periphery's >= 90% confirmation floor
        // would (correctly) never confirm it, stranding the position in the trusted-reconciliation
        // path by construction. Keeping this floor equal to the periphery's makes every send that
        // leaves the hub confirmable at its guaranteed minimum.
        if (minDeliveredAmount * 10_000 < amount * MIN_SOURCE_DELIVERY_BPS) {
            revert DELIVERY_BELOW_RESERVATION_FLOOR();
        }
        // R2-B1: the token whose arrival the executor attests (and which the action approves)
        // must be the token the bridge actually delivers, whenever the hub can derive it.
        if (expectedDstToken != address(0) && action.dstToken != expectedDstToken) {
            revert DESTINATION_TOKEN_NOT_BOUND();
        }

        guard.validateAllocation(account, chainId, action.destinationVault, amount);
        ICrossChainPositionRegistry(SUPER_GOVERNOR.getAddress(CROSS_CHAIN_POSITION_REGISTRY))
            .recordBridgedOut(account, chainId, action.destinationVault, amount);
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
        DestinationAction memory action = _decodeDestinationAction(destinationMessage, chainId, guard);
        return abi.encodePacked(address(guard), chainId, action.destinationVault, action.actionType, usePrevHookAmount);
    }

    /// @dev Decode and strictly type the destination action carried by `destinationMessage` (the
    ///      raw 5-tuple, WITHOUT the signature the parent appends at build time).
    ///      Permitted shapes:
    ///      - IDLE_HOLD: a well-formed `execute(ExecutorEntry)` with ZERO hooks — the bridged funds
    ///        stay on the hub-controlled destination account (destinationVault == address(0));
    ///      - VAULT_DEPOSIT: exactly [approveHook, depositHook] (the governance-pinned pair for the
    ///        chain), the approve spender equal to the deposit target — that target is the
    ///        canonical destination vault.
    ///      R2-B1 economic bindings enforced here for BOTH shapes:
    ///      - exactly ONE (dstToken, intentAmount) pair (the executor's arrival attestation);
    ///      and additionally for VAULT_DEPOSIT:
    ///      - the approve token equals dstTokens[0] (the action consumes the attested token);
    ///      - the approve amount equals intentAmounts[0] (one action amount, bound upstream to the
    ///        bridge's guaranteed delivery);
    ///      - the deposit MUST use usePrevHookAmount (it consumes the approve amount — no second,
    ///        independently encoded deposit amount can exist).
    ///      Anything else — a raw transfer (empty message), foreign executor selector, extra or
    ///      unknown hooks, spender/vault mismatch, token/amount mismatch — reverts.
    function _decodeDestinationAction(
        bytes memory destinationMessage,
        uint64 chainId,
        ICrossChainPositionCapGuard guard
    )
        internal
        view
        returns (DestinationAction memory action)
    {
        // A capped bridge must always carry a destination action; an empty message would be a raw
        // token transfer to the transport receiver — no deposit, no controlled shares.
        if (destinationMessage.length == 0) revert DESTINATION_ACTION_NOT_VALID();

        bytes memory executorCalldata;
        address[] memory dstTokens;
        uint256[] memory intentAmounts;
        (, executorCalldata, action.dstAccount, dstTokens, intentAmounts) =
            abi.decode(destinationMessage, (bytes, bytes, address, address[], uint256[]));

        // R2-B1: canonical one-token shape — the executor attests the arrival of exactly this
        // (token, amount) on the destination account before executing.
        if (dstTokens.length != 1 || intentAmounts.length != 1) revert DESTINATION_ACTION_NOT_VALID();
        action.dstToken = dstTokens[0];
        action.actionAmount = intentAmounts[0];
        if (action.dstToken == address(0) || action.actionAmount == 0) revert DESTINATION_ACTION_NOT_VALID();

        if (executorCalldata.length < 4 || bytes4(executorCalldata) != ISuperExecutor.execute.selector) {
            revert DESTINATION_ACTION_NOT_VALID();
        }
        bytes memory entryData = abi.decode(BytesLib.slice(executorCalldata, 4, executorCalldata.length - 4), (bytes));
        ISuperExecutor.ExecutorEntry memory entry = abi.decode(entryData, (ISuperExecutor.ExecutorEntry));

        uint256 hooksLen = entry.hooksAddresses.length;
        if (hooksLen != entry.hooksData.length) revert DESTINATION_ACTION_NOT_VALID();

        if (hooksLen == 0) {
            action.actionType = ACTION_IDLE_HOLD;
            return action;
        }

        if (hooksLen != 2) revert DESTINATION_ACTION_NOT_VALID();

        // The destination hook ADDRESSES are deliberately not part of the merkle leaf: they are
        // bound here against the guard's live governance config, so rotating the pair makes every
        // in-flight signed root revert at validation (fail-closed) rather than mis-route. Ops
        // note: a destinationHooks rotation therefore invalidates outstanding roots by design.
        // Ordering is load-bearing: the approve hook MUST be entry index 0 so its prevHook is
        // address(0) and it publishes outAmount = approve amount for the deposit hook's
        // usePrevHookAmount consumption (SuperExecutorBase starts prevHook at 0).
        (address approveHook, address depositHook) = guard.destinationHooks(chainId);
        if (approveHook == address(0) || depositHook == address(0)) revert DESTINATION_ACTION_NOT_VALID();
        if (entry.hooksAddresses[0] != approveHook || entry.hooksAddresses[1] != depositHook) {
            revert DESTINATION_ACTION_NOT_VALID();
        }

        if (entry.hooksData[1].length < DST_DEPOSIT_MIN_LENGTH || entry.hooksData[0].length < DST_APPROVE_MIN_LENGTH) {
            revert DESTINATION_ACTION_NOT_VALID();
        }
        action.destinationVault = BytesLib.toAddress(entry.hooksData[1], DST_DEPOSIT_VAULT_OFFSET);
        if (action.destinationVault == address(0)) revert DESTINATION_ACTION_NOT_VALID();
        // The approve spender must be the deposit target: no allowance may be granted to any other
        // address on the destination.
        if (BytesLib.toAddress(entry.hooksData[0], DST_APPROVE_SPENDER_OFFSET) != action.destinationVault) {
            revert DESTINATION_ACTION_NOT_VALID();
        }

        // R2-B1: the approve consumes the attested token, for the attested amount, and the deposit
        // consumes the approve output (usePrevHookAmount) — one amount, no divergence.
        if (BytesLib.toAddress(entry.hooksData[0], DST_APPROVE_TOKEN_OFFSET) != action.dstToken) {
            revert DESTINATION_ACTION_NOT_VALID();
        }
        if (BytesLib.toUint256(entry.hooksData[0], DST_APPROVE_AMOUNT_OFFSET) != action.actionAmount) {
            revert DESTINATION_ACTION_NOT_VALID();
        }
        if (uint8(entry.hooksData[1][DST_DEPOSIT_USE_PREV_OFFSET]) != 1) {
            revert DESTINATION_ACTION_NOT_VALID();
        }
        // R3-RF3: the approve is the FIRST destination hook — its prevHook is address(0), so
        // usePrevHookAmount == true would revert at execution and (on best-effort adapters)
        // strand the delivered funds idle under a vault-bound reservation. Reject up front.
        if (uint8(entry.hooksData[0][DST_APPROVE_USE_PREV_OFFSET]) != 0) {
            revert DESTINATION_ACTION_NOT_VALID();
        }
        // R3-RF3: the action token must be the approved vault's ASSET (governance-pinned — the
        // hub cannot call the destination vault). An output-token / vault-asset mismatch would
        // pass allowances but revert inside deposit(), stranding funds. Fail closed when unset.
        if (guard.destinationVaultAsset(chainId, action.destinationVault) != action.dstToken) {
            revert DESTINATION_VAULT_ASSET_NOT_BOUND();
        }

        action.actionType = ACTION_VAULT_DEPOSIT;
    }
}
