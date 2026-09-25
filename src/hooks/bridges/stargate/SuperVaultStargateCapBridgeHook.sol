// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// Superform
import { ApproveAndStargateSendHook } from "./ApproveAndStargateSendHook.sol";
import { SuperVaultCapBridgeCommon } from "../SuperVaultCapBridgeCommon.sol";
import { IStargate } from "../../../vendor/bridges/stargate/IStargate.sol";
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
///      MODE: only mode 0 (taxi) is allowed. Taxi is the sole Stargate V2 send path that actually
///      delivers the compose message the cap binds to. Bus mode (1) silently DROPS composeMsg —
///      Stargate's `_rideBus` never reads it (RideBusParams carries no compose field) — so the
///      tokens would land on the admin-less destination adapter with no compose execution and no
///      failedTransfers credit: the entire bridged amount would be permanently stranded. Generic
///      OFT mode (2) sends through a pool the destination TokenMessaging has no registration for,
///      hitting the adapter's unregistered-pool return AFTER the tokens are credited (and the
///      adapter cannot decode the compose format anyway) — also stranded. Mode 3 (lzMulticall)
///      forwards arbitrary pre-built calldata and ignores `to`/`amountLD` entirely. A capped send
///      must both bind the validated tuple AND guarantee destination-side compose execution, so
///      everything except taxi is rejected.
///
///      EXTRA OPTIONS: `extraOptions` flows verbatim into the LayerZero executor worker options in
///      taxi mode and is neither leaf-pinned nor consumed by the cap math, yet a native-drop (or
///      any value-carrying) option there is paid out of the send's msg.value — the account's
///      native fee float — to an arbitrary receiver. It is therefore structurally whitelisted at
///      runtime: empty, or a TYPE_3 container whose entries are executor gas-only lzReceive /
///      lzCompose options; everything else is rejected.
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
    uint256 private constant STARGATE_POOL_OFFSET = 84;
    uint256 private constant INPUT_TOKEN_OFFSET = 104;
    uint256 private constant DST_EID_OFFSET = 124;
    uint256 private constant TO_OFFSET = 128;
    uint256 private constant AMOUNT_LD_OFFSET = 160;
    uint256 private constant MIN_AMOUNT_LD_OFFSET = 192;
    uint256 private constant USE_PREV_HOOK_AMOUNT_OFFSET = 224;
    uint256 private constant MODE_OFFSET = 225;
    uint256 private constant EXTRA_OPTIONS_LENGTH_OFFSET = 226;
    uint256 private constant EXTRA_OPTIONS_OFFSET = 258;

    /// @dev Minimum hookData length before the dynamic tail (matches the parent's own build check).
    uint256 private constant MIN_CAP_DATA_LENGTH = 290;

    /// @dev The only cappable Stargate mode: taxi — the sole send path that delivers composeMsg
    ///      (bus drops it, generic OFT is unregistered in the destination TokenMessaging; both
    ///      strand the bridged amount on the admin-less adapter — see the contract NatSpec).
    uint8 private constant MODE_TAXI = 0;

    /// @dev LayerZero executor worker options layout (ExecutorOptions): a uint16 TYPE_3 header
    ///      (0x0003) followed by entries of [uint8 workerId][uint16 optionSize][uint8 optionType]
    ///      [optionSize - 1 bytes of params].
    uint16 private constant OPTIONS_TYPE_3 = 3;
    uint8 private constant EXECUTOR_WORKER_ID = 1;
    uint8 private constant OPTION_TYPE_LZRECEIVE = 1;
    uint8 private constant OPTION_TYPE_LZCOMPOSE = 3;
    /// @dev Gas-only lzReceive: optionType (1) + uint128 gas (16) — the value-carrying 33-byte
    ///      variant is rejected.
    uint256 private constant LZRECEIVE_GAS_ONLY_SIZE = 17;
    /// @dev Gas-only lzCompose: optionType (1) + uint16 index (2) + uint128 gas (16) — the
    ///      value-carrying 35-byte variant is rejected.
    uint256 private constant LZCOMPOSE_GAS_ONLY_SIZE = 19;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the LayerZero dstEid has no governance-registered canonical chain id
    error EID_NOT_MAPPED();

    /// @notice Thrown when the (source pool, chain) route has no governance-pinned destination token
    error STARGATE_ROUTE_NOT_SET();

    /// @notice Thrown when governance has not enabled cap-enabled Stargate sends
    ///         (stargateMinDeliveryBps == 0, the route enable switch)
    error STARGATE_ROUTE_DISABLED();

    /// @notice Thrown when the pool's live fee library is not the one governance pinned for it —
    ///         the quote/send exact-delivery equivalence is only known to hold for the reviewed
    ///         library (FeeLibV1 prices applyFee and applyFeeView identically and ignores the
    ///         sender); a rotation by Stargate governance fails closed until re-reviewed (R4-P1)
    error STARGATE_FEE_LIB_NOT_PINNED();

    /// @notice Thrown when the encoded minAmountLD is not EXACTLY the encoded amountLD — a
    ///         minimum is a floor, not a maximum, so full delivery is stated as equality and a
    ///         larger minimum is rejected rather than merely tolerated (R4-P1)
    error DELIVERY_MINIMUM_NOT_EXACT();

    /// @notice Thrown when the pool's runtime quote for the exact SendParam the parent will submit
    ///         does not credit precisely the amount sent — a fee state (credit below) AND a Stargate
    ///         V2 reward state (credit above, FeeLibV1 reward on a route deficit) both fail closed
    ///         here, before any approval or send, because the destination action is fixed to the
    ///         amount and any other credit would leave unregistered destination exposure (R4-P1)
    error DELIVERY_QUOTE_NOT_EXACT();

    /// @notice Thrown when the Stargate mode is not taxi — the only mode that delivers composeMsg
    ///         (any other mode strands the bridged amount on the admin-less destination adapter)
    error MODE_NOT_CAPPABLE();

    /// @notice Thrown when extraOptions carries anything beyond gas-only executor
    ///         lzReceive/lzCompose options — a value-carrying option (e.g. native drop) would pay
    ///         the account's native fee float to an arbitrary receiver
    error EXTRA_OPTIONS_NOT_VALID();

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
                          IDENTIFICATION (R3)
    //////////////////////////////////////////////////////////////*/

    /// @notice Unmistakably distinct from the uncapped parent — activation requires banning the
    ///         raw hook and authorizing only this one, so operators must never confuse the two.
    function name() external pure override returns (string memory) {
        return "SuperVault Capped Approve and Stargate Bridge";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Cap-enforced Stargate send for cross-chain SuperVaults: validates the typed destination action and records the reservation before bridging";
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
        _validateExtraOptions(data);

        // The amount validated is the amount the send will actually move; the delivery minimum is
        // minAmountLD. Under usePrevHookAmount the parent sets amountLD = prev.getOutAmount and
        // rescales minAmountLD by the same ratio — replicate exactly (R2-B1). The destination
        // token address is not hub-derivable for an OFT route (expectedDstToken = 0): the
        // executor's balance attestation over the action token is the arrival binding there.
        uint256 amount;
        uint256 minDelivered = BytesLib.toUint256(data, MIN_AMOUNT_LD_OFFSET);
        uint256 encodedAmountLD = BytesLib.toUint256(data, AMOUNT_LD_OFFSET);
        // A cap-hook send must always carry a nonzero encoded amountLD — even under
        // usePrevHookAmount, where the parent would tolerate zero. A zero encoded amount would
        // skip the parent's minAmountLD rescale AND make the encoded-equality check below vacuous
        // (0 == 0), so the runtime amounts would no longer be provably equal.
        if (encodedAmountLD == 0) revert AMOUNT_NOT_VALID();
        if (_decodeBool(data, USE_PREV_HOOK_AMOUNT_OFFSET)) {
            amount = ISuperHookResult(prevHook).getOutAmount(account);
            if (minDelivered > 0) {
                minDelivered = Math.mulDiv(minDelivered, amount, encodedAmountLD);
            }
        } else {
            amount = encodedAmountLD;
        }

        // Governance's stargateMinDeliveryBps (periphery-locked to 0 | 10_000) is the route ENABLE
        // switch only — exactness is never derived from a ratio (R3-RF1 superseded by R4-P1).
        if (_capGuard().stargateMinDeliveryBps() == 0) revert STARGATE_ROUTE_DISABLED();
        // R4-P1: a minimum is a floor, not a maximum — Stargate V2 reward routes credit MORE than
        // amountSentLD while the destination action stays fixed to the minimum, so the excess
        // would sit on the account unregistered. Full delivery is therefore stated as EQUALITY of
        // the ENCODED pair (a larger minimum is rejected, not tolerated; the usePrev rescale
        // preserves equality exactly) and proven at runtime against the pool's own quote after the
        // cap check (see _requireExactDelivery below).
        if (BytesLib.toUint256(data, MIN_AMOUNT_LD_OFFSET) != encodedAmountLD) revert DELIVERY_MINIMUM_NOT_EXACT();

        // R3-RF1: the destination token an OFT route delivers is not hub-derivable, so governance
        // pins it per (source pool, canonical chain) and the action token is bound to it.
        address expectedDstToken = _capGuard().stargateDstToken(BytesLib.toAddress(data, STARGATE_POOL_OFFSET), chainId);
        if (expectedDstToken == address(0)) revert STARGATE_ROUTE_NOT_SET();

        _enforceCrossChainCap(
            account,
            chainId,
            transportAdapter,
            BytesLib.toAddress(data, INPUT_TOKEN_OFFSET), // R4: must be the strategy's hub asset
            amount,
            minDelivered,
            expectedDstToken,
            composeMsg
        );

        // R4-P1: the pool must credit EXACTLY what is sent for the exact runtime SendParam.
        _requireExactDelivery(data, composeMsg, amount, minDelivered);
    }

    /// @dev R4-P1: quote the pool for the exact SendParam the parent will submit — the
    ///      usePrevHookAmount-adjusted amountLD/minAmountLD, the leaf's dstEid/to/extraOptions and
    ///      the pre-signature composeMsg (the fee library prices amount, route and mode, never the
    ///      payload bytes) — and require amountSentLD == amountReceivedLD == amount:
    ///      - amountSentLD < amount is shared-decimal dust the pool would silently drop (the
    ///        reservation would exceed what leaves the account);
    ///      - amountReceivedLD < amountSentLD is a fee state, amountReceivedLD > amountSentLD a
    ///        Stargate V2 REWARD state — either way the credited amount would differ from the
    ///        action-accounted amount, so the send fails closed before any approval or transfer.
    ///      The quote and the send execute inside the same executeHooks transaction, so pool state
    ///      cannot move between them except through another merkle-authorized hook of the same
    ///      batch. quoteOFT prices with msg.sender = this hook while the send prices with the
    ///      account: the equivalence therefore ASSUMES a fee library that ignores the sender and
    ///      prices applyFee and applyFeeView identically (true of FeeLibV1). That assumption is
    ///      pinned, not trusted: the pool's live fee library must equal the one governance reviewed
    ///      (stargateFeeLib), so a rotation fails closed until re-reviewed.
    ///      Liveness note: amountSentLD == amount rejects any shared-decimal dust, so cap-enabled
    ///      Stargate routes must use pools whose convertRate is 1 (e.g. 6-decimal USDC) or static
    ///      amounts that are exact multiples of the pool's convertRate.
    function _requireExactDelivery(
        bytes calldata data,
        bytes memory composeMsg,
        uint256 amount,
        uint256 minAmountLD
    )
        internal
        view
    {
        address pool = BytesLib.toAddress(data, STARGATE_POOL_OFFSET);
        address pinnedFeeLib = _capGuard().stargateFeeLib(pool);
        if (pinnedFeeLib == address(0) || IStargate(pool).getAddressConfig().feeLib != pinnedFeeLib) {
            revert STARGATE_FEE_LIB_NOT_PINNED();
        }

        uint256 extraOptionsLength = BytesLib.toUint256(data, EXTRA_OPTIONS_LENGTH_OFFSET);
        IStargate.SendParam memory sendParam = IStargate.SendParam({
            dstEid: BytesLib.toUint32(data, DST_EID_OFFSET),
            to: BytesLib.toBytes32(data, TO_OFFSET),
            amountLD: amount,
            minAmountLD: minAmountLD,
            extraOptions: data[EXTRA_OPTIONS_OFFSET:EXTRA_OPTIONS_OFFSET + extraOptionsLength],
            composeMsg: composeMsg,
            oftCmd: bytes("")
        });
        (,, IStargate.OFTReceipt memory receipt) = IStargate(pool).quoteOFT(sendParam);
        if (receipt.amountSentLD != amount || receipt.amountReceivedLD != amount) revert DELIVERY_QUOTE_NOT_EXACT();
    }

    /// @inheritdoc ApproveAndStargateSendHook
    /// @dev B4/B1 leaf: pins the parent transport fields PLUS the cap dimensions — cap guard,
    ///      CANONICAL destination chain id (translated from the LayerZero EID), economic
    ///      destination vault, destination action type and the amount-source mode — so one
    ///      approved leaf authorizes exactly one destination configuration. The R4 hub-asset
    ///      binding on the (already leaf-pinned) inputToken is runtime-only — see `_capLeafSuffix`.
    function inspect(bytes calldata data) external view override returns (bytes memory) {
        (uint64 chainId, address transportAdapter, bytes memory composeMsg) = _decodeCapFields(data);

        return abi.encodePacked(
            BytesLib.toAddress(data, STARGATE_POOL_OFFSET), // stargatePool
            BytesLib.toAddress(data, INPUT_TOKEN_OFFSET), // inputToken
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

        // Taxi only: it is the sole mode that delivers composeMsg. Bus drops the compose (the
        // bridged amount would strand on the admin-less adapter with no credit), generic OFT is
        // unregistered in the destination TokenMessaging (same outcome), and lzMulticall ignores
        // `to`/`amountLD` entirely — see the contract NatSpec.
        if (BytesLib.toUint8(data, MODE_OFFSET) != MODE_TAXI) revert MODE_NOT_CAPPABLE();

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

    /// @dev extraOptions is neither leaf-pinned nor consumed by the cap math, yet in taxi mode it
    ///      flows verbatim into the LayerZero executor worker options, and any value-carrying
    ///      option there (native drop, lzReceive/lzCompose value legs) is paid out of the send's
    ///      msg.value — the account's native fee float (lzNativeFee is unpinned too) — to a
    ///      caller-chosen receiver, repeatable per send under one authorized leaf. Structurally
    ///      whitelist it instead: empty, or a TYPE_3 container whose every entry is an executor
    ///      option that only buys gas — lzReceive (uint128 gas) or lzCompose (uint16 index +
    ///      uint128 gas). Unknown workers/types, value-carrying sizes, and malformed/truncated
    ///      encodings are all rejected. Called after `_decodeCapFields`, which already proved
    ///      `data.length >= EXTRA_OPTIONS_OFFSET + extraOptionsLength + 32`.
    function _validateExtraOptions(bytes calldata data) internal pure {
        uint256 extraOptionsLength = BytesLib.toUint256(data, EXTRA_OPTIONS_LENGTH_OFFSET);
        if (extraOptionsLength == 0) return;

        bytes calldata options = data[EXTRA_OPTIONS_OFFSET:EXTRA_OPTIONS_OFFSET + extraOptionsLength];
        if (options.length < 2 || uint16(bytes2(options[0:2])) != OPTIONS_TYPE_3) revert EXTRA_OPTIONS_NOT_VALID();

        uint256 cursor = 2;
        while (cursor < options.length) {
            // Entry: [uint8 workerId][uint16 optionSize][uint8 optionType][optionSize - 1 bytes]
            if (cursor + 4 > options.length) revert EXTRA_OPTIONS_NOT_VALID();
            uint8 workerId = uint8(options[cursor]);
            uint256 optionSize = uint16(bytes2(options[cursor + 1:cursor + 3]));
            uint8 optionType = uint8(options[cursor + 3]);
            if (cursor + 3 + optionSize > options.length) revert EXTRA_OPTIONS_NOT_VALID();

            if (workerId != EXECUTOR_WORKER_ID) revert EXTRA_OPTIONS_NOT_VALID();
            bool gasOnlyLzReceive = optionType == OPTION_TYPE_LZRECEIVE && optionSize == LZRECEIVE_GAS_ONLY_SIZE;
            bool gasOnlyLzCompose = optionType == OPTION_TYPE_LZCOMPOSE && optionSize == LZCOMPOSE_GAS_ONLY_SIZE;
            if (!gasOnlyLzReceive && !gasOnlyLzCompose) revert EXTRA_OPTIONS_NOT_VALID();

            cursor += 3 + optionSize;
        }
    }
}
