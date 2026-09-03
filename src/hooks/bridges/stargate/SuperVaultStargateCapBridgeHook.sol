// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";

// Superform
import { ApproveAndStargateSendHook } from "./ApproveAndStargateSendHook.sol";
import { SuperVaultCapBridgeCommon } from "../SuperVaultCapBridgeCommon.sol";
import { ISuperHookResult } from "../../../interfaces/ISuperHook.sol";

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
///      `CROSS_CHAIN_POSITION_REGISTRY`), keeping the write-path (recordBridgedOut) and the
///      read-path (validateAllocation) pointed at one registry across governance migrations.
///
///      ECONOMIC DESTINATION vs TRANSPORT (B1): the LayerZero `to` is the bridge TRANSPORT
///      receiver — in the real destination flow it is the StargateAdapter, which receives the
///      tokens plus the compose message and forwards both to SuperDestinationExecutor; it is NOT
///      the economic destination. This hook therefore:
///      - requires `to` to be a governance-approved destination adapter for the canonical
///        destination chain;
///      - requires a non-empty compose message decoding to a strictly typed destination action
///        (idle-hold on the hub-controlled destination account, or a deposit into exactly one
///        vault via the governance-pinned destination hook pair);
///      - validates the cap and records the in-flight reservation against the canonical
///        (chainId, destinationVault) extracted from that action.
///      A send with an empty compose message (a raw token transfer to `to`) is rejected: it mints
///      no controlled shares and establishes no registrable position.
///
///      CANONICAL CHAIN KEY (B4): Stargate routes by LayerZero `dstEid` (endpoint id, uint32),
///      which is a DIFFERENT namespace than the EVM chain id the registry/cap system keys on
///      (e.g. Base is EID 30184 but chain id 8453). The hook translates the routing id through the
///      governance-controlled EID -> chain id map served by the cap guard and validates/records
///      ONLY under the canonical EVM chain id — so a Base allocation through Stargate consumes
///      the SAME per-chain cap as one through Across/deBridge, and its reservation releases under
///      the same registry key. An unmapped EID fails closed.
///
///      MODE: only modes 0 (taxi), 1 (bus) and 2 (OFT) are allowed — each carries the recipient
///      and amount at fixed offsets by construction, so validated-tuple == bridged-tuple. Mode 3
///      (lzMulticall) forwards arbitrary pre-built calldata and ignores `to`/`amountLD` (the
///      parent encoder even zeroes `to`), so it is rejected here: the cap could not bind to what
///      actually bridges.
///
///      SECURITY INVARIANT (not machine-enforced here): the cap only binds if every fund-exiting
///      leaf for a cap-enabled strategy routes through a cap-aware hook. Treat "only cap-aware
///      bridge hooks registered on host chains" as a monitored governance invariant.
contract SuperVaultStargateCapBridgeHook is ApproveAndStargateSendHook, SuperVaultCapBridgeCommon {
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
    uint256 private constant EXTRA_OPTIONS_LENGTH_OFFSET = 226;
    uint256 private constant EXTRA_OPTIONS_OFFSET = 258;

    /// @dev Minimum hookData length before the dynamic tail (matches the parent's own build check).
    uint256 private constant MIN_CAP_DATA_LENGTH = 290;

    /// @dev Highest Stargate mode whose `to`/`amountLD` are the actual bridged destination/amount.
    uint8 private constant MAX_CAPPABLE_MODE = 2;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the LayerZero dstEid has no governance-registered canonical chain id
    error EID_NOT_MAPPED();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param validator_ Superform validator holding the destination signature (forwarded to parent)
    /// @param superGovernor_ SuperGovernor address book resolving the cap guard and position registry
    constructor(
        address validator_,
        address superGovernor_
    )
        ApproveAndStargateSendHook(validator_)
        SuperVaultCapBridgeCommon(superGovernor_)
    {
        if (superGovernor_ == address(0)) revert ADDRESS_NOT_VALID();
    }

    /*//////////////////////////////////////////////////////////////
                              CAP ENFORCEMENT
    //////////////////////////////////////////////////////////////*/

    /// @dev Runs BEFORE the approve/send executions (called by the strategy=account). Validates the
    ///      allocation against the cross-chain caps and records the in-flight reservation. A cap
    ///      breach (or stale AUM, unapproved adapter, unmapped EID, untyped destination action)
    ///      reverts here, aborting the whole executeHooks batch; if the later send reverts, the
    ///      reservation is rolled back with the transaction. Preserves the parent pipe-mode
    ///      behaviour via `super`.
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        super._preExecute(prevHook, account, data);

        (uint64 chainId, address transportAdapter, bytes memory composeMsg) = _decodeCapFields(data);

        // The amount validated is the amount the send will actually move. Under usePrevHookAmount
        // the parent sets amountLD = prev.getOutAmount(account), so read the same value here.
        uint256 amount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_OFFSET)
            ? ISuperHookResult(prevHook).getOutAmount(account)
            : BytesLib.toUint256(data, AMOUNT_LD_OFFSET);

        _enforceCrossChainCap(account, chainId, transportAdapter, amount, composeMsg);
    }

    /// @inheritdoc ApproveAndStargateSendHook
    /// @dev B4/B1 leaf: pins the parent transport fields PLUS the cap dimensions — cap guard,
    ///      CANONICAL destination chain id (translated from the LayerZero EID), economic
    ///      destination vault, destination action type and the amount-source mode — so one
    ///      approved leaf authorizes exactly one destination configuration.
    function inspect(bytes calldata data) external view override returns (bytes memory) {
        (uint64 chainId, address transportAdapter, bytes memory composeMsg) = _decodeCapFields(data);

        return abi.encodePacked(
            BytesLib.toAddress(data, 84), // stargatePool
            BytesLib.toAddress(data, 104), // inputToken
            transportAdapter, // to = destination adapter (transport)
            // cap guard, CANONICAL chain id (not the EID), destination vault, action type,
            // amount-source mode
            _capLeafSuffix(chainId, composeMsg, _decodeBool(data, USE_PREV_HOOK_AMOUNT_OFFSET))
        );
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @dev Shared decode for `_preExecute` and `inspect`: canonical chain id (via the
    ///      governance-controlled EID map — fail closed on unmapped), EVM-only transport receiver,
    ///      and the raw compose message (which is the shared 5-tuple destination payload, WITHOUT
    ///      the signature the parent appends at build time).
    function _decodeCapFields(bytes calldata data)
        internal
        view
        returns (uint64 chainId, address transportAdapter, bytes memory composeMsg)
    {
        // Guard the fixed-offset reads before touching any offset.
        if (data.length < MIN_CAP_DATA_LENGTH) revert DATA_NOT_VALID();

        // Only modes whose `to`/`amountLD` are the real bridged destination/amount can be capped.
        // Mode 3 (lzMulticall) forwards arbitrary calldata and ignores both — reject it.
        if (BytesLib.toUint8(data, MODE_OFFSET) > MAX_CAPPABLE_MODE) revert DATA_NOT_VALID();

        // B4: translate the LayerZero routing id to the canonical EVM chain id; fail closed on an
        // unmapped EID so a new route cannot be capped under a fresh, empty namespace.
        uint32 dstEid = BytesLib.toUint32(data, DST_EID_OFFSET);
        chainId = _capGuard().chainIdForEid(dstEid);
        if (chainId == 0) revert EID_NOT_MAPPED();

        // `to` is a bytes32 LZ recipient. SuperVault caps are EVM-only: fail closed on a non-EVM
        // recipient (top 12 bytes non-zero) instead of truncating it to a wrong address.
        bytes32 to = BytesLib.toBytes32(data, TO_OFFSET);
        if (uint256(to) >> 160 != 0) revert DATA_NOT_VALID();
        transportAdapter = address(uint160(uint256(to)));
        if (transportAdapter == address(0)) revert ADDRESS_NOT_VALID();

        // composeMsg sits after the dynamic extraOptions block (same walk as the parent's build).
        uint256 extraOptionsLength = BytesLib.toUint256(data, EXTRA_OPTIONS_LENGTH_OFFSET);
        uint256 composeMsgOffset = EXTRA_OPTIONS_OFFSET + extraOptionsLength;
        if (data.length < composeMsgOffset + 32) revert DATA_NOT_VALID();
        uint256 composeMsgLength = BytesLib.toUint256(data, composeMsgOffset);
        if (data.length < composeMsgOffset + 32 + composeMsgLength) revert DATA_NOT_VALID();
        composeMsg = BytesLib.slice(data, composeMsgOffset + 32, composeMsgLength);
    }
}
