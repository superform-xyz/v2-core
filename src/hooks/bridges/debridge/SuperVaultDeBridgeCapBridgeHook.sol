// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IDlnSource } from "../../../vendor/bridges/debridge/IDlnSource.sol";

// Superform
import { DeBridgeSendOrderAndExecuteOnDstHook } from "./DeBridgeSendOrderAndExecuteOnDstHook.sol";
import { ISuperHookResult } from "../../../interfaces/ISuperHook.sol";

/// @notice Minimal view of the SuperGovernor address book (SuperVault periphery). Declared locally
///         so this hook has no dependency on the periphery package (v2-core is periphery's
///         dependency, not the reverse).
interface ISuperGovernorAddressBook {
    function getAddress(bytes32 key) external view returns (address);
}

/// @notice Minimal view of the cross-chain cap guard (SuperVault periphery).
interface ICrossChainPositionCapGuard {
    function validateAllocation(
        address strategy,
        uint64 destinationChainId,
        address destinationVault,
        uint256 amount
    )
        external
        view;
}

/// @notice Minimal surface of the cross-chain position registry (SuperVault periphery). Note
///         `recordBridgedOut` is state-mutating.
interface ICrossChainPositionRegistry {
    function recordBridgedOut(address strategy, uint64 chainId, uint256 amount) external;
}

/// @title SuperVaultDeBridgeCapBridgeHook
/// @author Superform Labs
/// @notice The deBridge (DLN) send-order hook, made cross-chain-cap-aware for SuperVaults. At core
///         it IS the standard deBridge send hook; it additionally enforces the SuperVault
///         cross-chain allocation cap and records the in-flight exposure ATOMICALLY, in
///         `_preExecute`, before the `createOrder` execution runs. It is intended to be the ONLY
///         cross-chain bridging leaf authorized for a cross-chain-enabled strategy: raw deBridge
///         hooks must NOT be registered on chains hosting such a strategy (so a raw bridge leaf
///         cannot execute), which is what makes the cap binding.
/// @dev The cap guard and position registry are resolved from SuperGovernor AT EXECUTION using the
///      same registry keys the periphery guard/registry use (`CROSS_CHAIN_CAP_GUARD`,
///      `CROSS_CHAIN_POSITION_REGISTRY`). Resolving here keeps the write-path (recordBridgedOut)
///      and the read-path (validateAllocation) pointed at one registry, so a governance migration
///      cannot silently desync the cap's in-flight term. The hook imports nothing from periphery.
///
///      DECODE: unlike the Across cap hook (fixed offsets), the deBridge hookData layout is dynamic
///      — variable-length fields (destinationMessage, takeTokenAddress, receiverDst, …) place the
///      cap fields at data-dependent offsets. This hook therefore reuses the parent's internal
///      `_createOrder(data, "")` decode (the same call the parent's own `inspect()` makes) to read
///      the exact `(receiverDst, takeChainId, giveAmount)` the bridge will use, so validated-tuple
///      == bridged-tuple by construction. Passing an empty signature is safe: the signature only
///      feeds the `externalCall` envelope and never affects those three fields.
///
///      The cap destination is the order `receiverDst` (EVM-only for SuperVaults — a non-20-byte
///      destination, e.g. a 32-byte Solana pubkey, is rejected fail-closed); the destination chain
///      is `takeChainId` (deBridge's namespace, which equals the EVM chainId for EVM destinations);
///      the amount is the `giveAmount` the order actually gives (the previous hook's output under
///      usePrevHookAmount, matching the parent's own resolution).
///
///      IDLE-HOLD: the periphery guard treats `destinationVault == address(0)` as an idle-hold
///      escrow branch. The deBridge parent (unlike Across) does NOT revert on a zero receiver, so
///      this hook rejects `recipient == address(0)` explicitly, keeping every allocation on the
///      `approvedDestinationVault` branch and idle-hold unreachable through this hook.
///
///      SECURITY INVARIANT (not machine-enforced here): the cap only binds if every fund-exiting
///      leaf for a cap-enabled strategy routes through a cap-aware hook. Authorizing any uncapped
///      bridge/transfer hook for such a strategy bypasses the cap. Treat "only cap-aware bridge
///      hooks registered on host chains" as a monitored governance invariant. Governance must
///      register `approvedDestination(chainId, vault)` under the deBridge `takeChainId` value.
contract SuperVaultDeBridgeCapBridgeHook is DeBridgeSendOrderAndExecuteOnDstHook {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev usePrevHookAmount bool offset — mirrors the parent (whose constant is private); drift is
    ///      caught by the offset-equivalence unit test, not by the compiler. No amount offset is
    ///      mirrored: the validated amount comes from `_createOrder(...).giveAmount`, not a fixed
    ///      offset, so there is one less constant that can drift than on the Across hook.
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 52;

    /// @dev SuperGovernor address-book keys — identical to the periphery constants so the resolved
    ///      guard/registry match what the cap math reads.
    bytes32 private constant CROSS_CHAIN_CAP_GUARD = keccak256("CROSS_CHAIN_CAP_GUARD");
    bytes32 private constant CROSS_CHAIN_POSITION_REGISTRY = keccak256("CROSS_CHAIN_POSITION_REGISTRY");

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the decoded destination is not an EVM address (receiverDst length != 20)
    ///         or the destination chain id does not fit in a uint64
    error DATA_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice SuperGovernor address book — single source of truth for the cap guard and position
    ///         registry, resolved at execution time (SuperVault periphery).
    ISuperGovernorAddressBook public immutable SUPER_GOVERNOR;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param dlnSource_ deBridge DLN source (forwarded to the parent, which zero-checks it)
    /// @param validator_ Superform validator holding the destination signature (forwarded to parent)
    /// @param superGovernor_ SuperGovernor address book resolving the cap guard and position registry
    constructor(
        address dlnSource_,
        address validator_,
        address superGovernor_
    )
        DeBridgeSendOrderAndExecuteOnDstHook(dlnSource_, validator_)
    {
        if (superGovernor_ == address(0)) revert ADDRESS_NOT_VALID();
        SUPER_GOVERNOR = ISuperGovernorAddressBook(superGovernor_);
    }

    /*//////////////////////////////////////////////////////////////
                              CAP ENFORCEMENT
    //////////////////////////////////////////////////////////////*/

    /// @dev Runs BEFORE the createOrder execution (called by the strategy=account). Validates the
    ///      allocation against the cross-chain caps and records the in-flight exposure. A cap breach
    ///      (or stale AUM) reverts here, aborting the whole executeHooks batch; if the later order
    ///      send reverts, the reservation is rolled back with the transaction. Preserves the parent
    ///      pipe-mode behaviour via `super`.
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        super._preExecute(prevHook, account, data);

        // Reuse the parent's decode (same call its inspect() makes) so the validated tuple is
        // exactly what the bridge will send. Malformed/short data reverts here via the vendor lib's
        // bounds check — identical to the parent's own build()/inspect() on the same buffer.
        (IDlnSource.OrderCreation memory order,,,) = _createOrder(data, "");

        // receiverDst is EVM-only for SuperVault caps: fail closed on a non-20-byte (e.g. 32-byte
        // Solana) destination instead of truncating it to a wrong address.
        if (order.receiverDst.length != 20) revert DATA_NOT_VALID();
        address recipient = address(bytes20(order.receiverDst));
        // The deBridge parent does not revert on a zero receiver; reject it so idle-hold
        // (destinationVault == 0) stays unreachable through this hook.
        if (recipient == address(0)) revert ADDRESS_NOT_VALID();

        // takeChainId is forwarded as a full uint256 to DlnSource; reject anything above uint64 so
        // the truncated cap/registry key cannot disagree with the chain the order actually targets.
        uint256 rawChainId = order.takeChainId;
        if (rawChainId > type(uint64).max) revert DATA_NOT_VALID();
        uint64 chainId = uint64(rawChainId);

        // The amount validated is the amount the order actually gives. Under usePrevHookAmount the
        // parent sets giveAmount = prev.getOutAmount(account), so read the same value here.
        uint256 amount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION)
            ? ISuperHookResult(prevHook).getOutAmount(account)
            : order.giveAmount;

        // Resolve guard + registry from SuperGovernor at call time (same keys the periphery uses),
        // so the registry recorded into is always the one the cap check reads from.
        ICrossChainPositionCapGuard(SUPER_GOVERNOR.getAddress(CROSS_CHAIN_CAP_GUARD)).validateAllocation(
            account, chainId, recipient, amount
        );
        ICrossChainPositionRegistry(SUPER_GOVERNOR.getAddress(CROSS_CHAIN_POSITION_REGISTRY)).recordBridgedOut(
            account, chainId, amount
        );
    }

    // NOTE on the merkle leaf: `inspect()` is inherited from the parent (giveToken, takeToken,
    // receiverDst, givePatchAuthoritySrc, orderAuthorityAddressDst, allowedCancelBeneficiarySrc) and
    // is not re-overridden. The parent leaf omits takeChainId, but chain specificity is enforced at
    // EXECUTION: `_preExecute` reads takeChainId and `validateAllocation` requires the
    // (chainId, recipient) pair to be an approved, enabled destination, so reusing an approved leaf
    // with a different chain reverts the cap check.
}
