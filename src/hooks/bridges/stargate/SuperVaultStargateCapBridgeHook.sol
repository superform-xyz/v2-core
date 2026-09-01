// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";

// Superform
import { ApproveAndStargateSendHook } from "./ApproveAndStargateSendHook.sol";
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

/// @title SuperVaultStargateCapBridgeHook
/// @author Superform Labs
/// @notice The Stargate (LayerZero) ApproveAnd ERC20 bridge hook, made cross-chain-cap-aware for
///         SuperVaults. At core it IS the standard Stargate send hook; it additionally enforces the
///         SuperVault cross-chain allocation cap and records the in-flight exposure ATOMICALLY, in
///         `_preExecute`, before the approve/send executions run. It is intended to be the ONLY
///         cross-chain bridging leaf authorized for a cross-chain-enabled strategy: raw Stargate
///         hooks must NOT be registered on chains hosting such a strategy (so a raw bridge leaf
///         cannot execute), which is what makes the cap binding.
/// @dev The cap guard and position registry are resolved from SuperGovernor AT EXECUTION using the
///      same registry keys the periphery guard/registry use (`CROSS_CHAIN_CAP_GUARD`,
///      `CROSS_CHAIN_POSITION_REGISTRY`). Resolving here keeps the write-path (recordBridgedOut) and
///      the read-path (validateAllocation) pointed at one registry, so a governance migration
///      cannot silently desync the cap's in-flight term. The hook imports nothing from periphery.
///
///      DECODE: Stargate carries the destination in the on-chain send calldata at FIXED offsets
///      (before the dynamic extraOptions/composeMsg tail), so — like the Across cap hook — this
///      hook reads them directly and validates exactly what the parent sends. Offsets mirror the
///      (locked) parent; drift is caught by the offset-equivalence unit test, not the compiler
///      (the parent's constants are private).
///
///      CHAIN KEY: the cap keys on the LayerZero `dstEid` (endpoint id, uint32), NOT an EVM chainId
///      — there is no on-chain EID→chainId map, and adding a mutable one would break the
///      by-construction guarantee. `dstEid` always fits uint64, so no truncation guard is needed
///      (unlike Across/deBridge). SECURITY INVARIANT: governance MUST register
///      `approvedDestination(dstEid, vault)` under LayerZero EID values (e.g. Base 30184,
///      Ethereum 30101), a DIFFERENT namespace than the Across/deBridge caps (EVM chainId).
///
///      MODE: only modes 0 (taxi), 1 (bus) and 2 (OFT) are allowed — each carries the recipient
///      and amount at fixed offsets by construction, so validated-tuple == bridged-tuple. Mode 3 (lzMulticall)
///      forwards arbitrary pre-built calldata and ignores `to`/`amountLD` (the parent encoder even
///      zeroes `to`), so it is rejected here: the cap could not bind to what actually bridges.
///
///      `to` is a bytes32 LayerZero recipient; SuperVault caps are EVM-only, so a non-EVM recipient
///      (top 12 bytes non-zero) is rejected fail-closed, and a zero recipient is rejected to keep
///      idle-hold (destinationVault == 0) unreachable through this hook (the parent's own zero-`to`
///      check runs during build, after `_preExecute`).
///
///      SECURITY INVARIANT (not machine-enforced here): the cap only binds if every fund-exiting
///      leaf for a cap-enabled strategy routes through a cap-aware hook. Treat "only cap-aware
///      bridge hooks registered on host chains" as a monitored governance invariant.
contract SuperVaultStargateCapBridgeHook is ApproveAndStargateSendHook {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev hookData offsets — mirror the parent (locked) layout; the cap fields are fixed and sit
    ///      before the dynamic extraOptions/composeMsg tail.
    uint256 private constant DST_EID_OFFSET = 124;
    uint256 private constant TO_OFFSET = 128;
    uint256 private constant AMOUNT_LD_OFFSET = 160;
    uint256 private constant USE_PREV_HOOK_AMOUNT_OFFSET = 224;
    uint256 private constant MODE_OFFSET = 225;

    /// @dev Minimum hookData length the cap decode requires: the mode byte sits at offset 225, so
    ///      the buffer must be at least 226 bytes before any fixed-offset read. (The parent's own
    ///      build enforces a larger minimum incl. the dynamic tail; this guards direct/early reads.)
    uint256 private constant MIN_CAP_DATA_LENGTH = 226;

    /// @dev Highest Stargate mode whose `to`/`amountLD` are the actual bridged destination/amount.
    uint8 private constant MAX_CAPPABLE_MODE = 2;

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

    /// @param validator_ Superform validator holding the destination signature (forwarded to parent)
    /// @param superGovernor_ SuperGovernor address book resolving the cap guard and position registry
    constructor(address validator_, address superGovernor_) ApproveAndStargateSendHook(validator_) {
        if (superGovernor_ == address(0)) revert ADDRESS_NOT_VALID();
        SUPER_GOVERNOR = ISuperGovernorAddressBook(superGovernor_);
    }

    /*//////////////////////////////////////////////////////////////
                              CAP ENFORCEMENT
    //////////////////////////////////////////////////////////////*/

    /// @dev Runs BEFORE the approve/send executions (called by the strategy=account). Validates the
    ///      allocation against the cross-chain caps and records the in-flight exposure. A cap breach
    ///      (or stale AUM) reverts here, aborting the whole executeHooks batch; if the later send
    ///      reverts, the reservation is rolled back with the transaction. Preserves the parent
    ///      pipe-mode behaviour via `super`.
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        super._preExecute(prevHook, account, data);

        // Guard the fixed-offset reads before touching any offset (mode byte is the deepest at 225).
        if (data.length < MIN_CAP_DATA_LENGTH) revert DATA_NOT_VALID();

        // Only modes whose `to`/`amountLD` are the real bridged destination/amount can be capped.
        // Mode 3 (lzMulticall) forwards arbitrary calldata and ignores both — reject it.
        if (BytesLib.toUint8(data, MODE_OFFSET) > MAX_CAPPABLE_MODE) revert DATA_NOT_VALID();

        // dstEid is a uint32 LayerZero endpoint id; it always fits uint64 (no truncation guard).
        uint64 dstEid = uint64(BytesLib.toUint32(data, DST_EID_OFFSET));

        // `to` is a bytes32 LZ recipient. SuperVault caps are EVM-only: fail closed on a non-EVM
        // recipient (top 12 bytes non-zero) instead of truncating it to a wrong address.
        bytes32 to = BytesLib.toBytes32(data, TO_OFFSET);
        if (uint256(to) >> 160 != 0) revert DATA_NOT_VALID();
        address vault = address(uint160(uint256(to)));
        if (vault == address(0)) revert ADDRESS_NOT_VALID();

        // The amount validated is the amount the send will actually move. Under usePrevHookAmount
        // the parent sets amountLD = prev.getOutAmount(account), so read the same value here.
        uint256 amount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_OFFSET)
            ? ISuperHookResult(prevHook).getOutAmount(account)
            : BytesLib.toUint256(data, AMOUNT_LD_OFFSET);

        // Resolve guard + registry from SuperGovernor at call time (same keys the periphery uses),
        // so the registry recorded into is always the one the cap check reads from.
        ICrossChainPositionCapGuard(SUPER_GOVERNOR.getAddress(CROSS_CHAIN_CAP_GUARD)).validateAllocation(
            account, dstEid, vault, amount
        );
        ICrossChainPositionRegistry(SUPER_GOVERNOR.getAddress(CROSS_CHAIN_POSITION_REGISTRY)).recordBridgedOut(
            account, dstEid, amount
        );
    }

    // NOTE on the merkle leaf: `inspect()` is inherited from the parent (stargatePool, inputToken,
    // `to` as address) and is not re-overridden. The parent leaf omits the dstEid, but chain
    // specificity is enforced at EXECUTION: `_preExecute` reads dstEid and `validateAllocation`
    // requires the (dstEid, vault) pair to be an approved, enabled destination, so reusing an
    // approved leaf with a different endpoint reverts the cap check.
}
