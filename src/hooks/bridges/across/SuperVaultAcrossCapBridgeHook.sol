// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";

// Superform
import { ApproveAndAcrossSendFundsAndExecuteOnDstHook } from "./ApproveAndAcrossSendFundsAndExecuteOnDstHook.sol";
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

/// @title SuperVaultAcrossCapBridgeHook
/// @author Superform Labs
/// @notice The Across ApproveAnd ERC20 bridge hook, made cross-chain-cap-aware for SuperVaults. At
///         core it IS the standard Across bridge hook; it additionally enforces the SuperVault
///         cross-chain allocation cap and records the in-flight exposure ATOMICALLY, in
///         `_preExecute`, before the approve/bridge executions run. It is intended to be the ONLY
///         cross-chain bridging leaf authorized for a cross-chain-enabled strategy: raw Across hooks
///         must NOT be registered on chains hosting such a strategy (so a raw bridge leaf cannot
///         execute), which is what makes the cap binding.
/// @dev The cap guard and position registry are resolved from SuperGovernor AT EXECUTION using the
///      same registry keys the periphery guard/registry use (`CROSS_CHAIN_CAP_GUARD`,
///      `CROSS_CHAIN_POSITION_REGISTRY`). This is deliberate: the periphery cap guard reads
///      effective exposure from the SuperGovernor-resolved registry, so recording into anything
///      other than that same registry would let a governance migration silently desync the cap's
///      in-flight term. Resolving here keeps the write-path (recordBridgedOut) and the read-path
///      (validateAllocation) pointed at one registry. The hook still imports nothing from periphery.
///
///      The cap destination is the Across `recipient`; the destination chain and amount are read
///      from the same hookData the bridge send uses, so the validated amount is exactly the bridged
///      amount. Offsets follow the parent layout (52-byte strategy header + hook fields) and are
///      pinned to the (locked-bytecode) parent — the SuperVaultAcrossCapBridgeHook test asserts the
///      decoded (recipient, chainId, amount) equals the tuple the parent hands to `depositV3Now`.
///
///      IDLE-HOLD: the periphery guard treats `destinationVault == address(0)` as an idle-hold
///      escrow branch, but the parent bridge builder reverts on `recipient == address(0)`. Since the
///      cap destination IS the Across recipient, idle-hold is unreachable through this hook; every
///      allocation is validated through the `approvedDestinationVault` branch.
///
///      REFUND: the parent passes the strategy `account` as the Across depositor, so an unfilled
///      deposit refunds principal to the strategy on the origin chain. The in-flight reservation
///      recorded here is released when the paired Pending position is confirmed, or reclaimed via
///      the registry's permissionless `invalidateExpiredPending` once it times out.
///
///      SECURITY INVARIANT (not machine-enforced here): the cap only binds if every fund-exiting
///      leaf for a cap-enabled strategy routes through a cap-aware hook. Authorizing any uncapped
///      bridge/transfer hook for such a strategy bypasses the cap. Treat "only cap-aware bridge
///      hooks registered on host chains" as a monitored governance invariant.
contract SuperVaultAcrossCapBridgeHook is ApproveAndAcrossSendFundsAndExecuteOnDstHook {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev hookData offsets — mirror the parent (locked) layout; drift is caught by the
    ///      offset-equivalence unit test, not by the compiler (the parent's constants are private).
    uint256 private constant RECIPIENT_OFFSET = 84;
    uint256 private constant INPUT_AMOUNT_OFFSET = 144;
    uint256 private constant DST_CHAIN_ID_OFFSET = 208;
    uint256 private constant USE_PREV_HOOK_AMOUNT_OFFSET = 268;

    /// @dev Minimum hookData length the cap decode requires: the usePrevHookAmount bool sits at
    ///      offset 268, so the buffer must be at least 269 bytes before any fixed-offset read.
    uint256 private constant MIN_CAP_DATA_LENGTH = 269;

    /// @dev SuperGovernor address-book keys — identical to the periphery constants so the resolved
    ///      guard/registry match what the cap math reads.
    bytes32 private constant CROSS_CHAIN_CAP_GUARD = keccak256("CROSS_CHAIN_CAP_GUARD");
    bytes32 private constant CROSS_CHAIN_POSITION_REGISTRY = keccak256("CROSS_CHAIN_POSITION_REGISTRY");

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice SuperGovernor address book — single source of truth for the cap guard and position
    ///         registry, resolved at execution time (SuperVault periphery).
    ISuperGovernorAddressBook public immutable SUPER_GOVERNOR;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param spokePoolV3_ Across SpokePool V3 (forwarded to the parent)
    /// @param validator_ Superform validator holding the destination signature (forwarded to parent)
    /// @param superGovernor_ SuperGovernor address book resolving the cap guard and position registry
    constructor(
        address spokePoolV3_,
        address validator_,
        address superGovernor_
    )
        ApproveAndAcrossSendFundsAndExecuteOnDstHook(spokePoolV3_, validator_)
    {
        if (superGovernor_ == address(0)) revert ADDRESS_NOT_VALID();
        SUPER_GOVERNOR = ISuperGovernorAddressBook(superGovernor_);
    }

    /*//////////////////////////////////////////////////////////////
                              CAP ENFORCEMENT
    //////////////////////////////////////////////////////////////*/

    /// @dev Runs BEFORE the approve/bridge executions (called by the strategy=account). Validates
    ///      the allocation against the cross-chain caps and records the in-flight exposure. A cap
    ///      breach (or stale AUM) reverts here, aborting the whole executeHooks batch; if the later
    ///      bridge send reverts, the reservation is rolled back with the transaction. Preserves the
    ///      parent pipe-mode passthrough behaviour via `super`.
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        super._preExecute(prevHook, account, data);

        // Guard the fixed-offset reads with the typed error before touching any offset. `_preExecute`
        // runs before the parent's `_buildHookExecutions` length check, so without this a short
        // buffer would revert with the vendor lib's untyped out-of-bounds error.
        if (data.length < MIN_CAP_DATA_LENGTH) revert DATA_NOT_VALID();

        // The parent forwards the FULL uint256 destinationChainId to the SpokePool. Validate the same
        // full value (rejecting anything above uint64) so the truncated cap/registry key cannot
        // disagree with the chain the bridge is actually instructed to use.
        uint256 rawChainId = BytesLib.toUint256(data, DST_CHAIN_ID_OFFSET);
        if (rawChainId > type(uint64).max) revert DATA_NOT_VALID();
        uint64 chainId = uint64(rawChainId);

        address recipient = BytesLib.toAddress(data, RECIPIENT_OFFSET);

        // The amount validated is the amount the bridge will actually send.
        uint256 amount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_OFFSET)
            ? ISuperHookResult(prevHook).getOutAmount(account)
            : BytesLib.toUint256(data, INPUT_AMOUNT_OFFSET);

        // Resolve guard + registry from SuperGovernor at call time (same keys the periphery uses), so
        // the registry recorded into is always the one the cap check reads from.
        ICrossChainPositionCapGuard(SUPER_GOVERNOR.getAddress(CROSS_CHAIN_CAP_GUARD)).validateAllocation(
            account, chainId, recipient, amount
        );
        ICrossChainPositionRegistry(SUPER_GOVERNOR.getAddress(CROSS_CHAIN_POSITION_REGISTRY)).recordBridgedOut(
            account, chainId, amount
        );
    }

    // NOTE on the merkle leaf: `inspect()` is inherited from the parent (recipient, tokens,
    // relayer) and is not re-overridable. The parent leaf omits the destination chain id, but chain
    // specificity is enforced at EXECUTION: `_preExecute` reads chainId and `validateAllocation`
    // requires the (chainId, recipient) pair to be an approved, enabled destination, so reusing an
    // approved leaf with a different chain reverts the cap check.
}
