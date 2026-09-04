// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IDlnSource } from "../../../vendor/bridges/debridge/IDlnSource.sol";

// Superform
import { DeBridgeSendOrderAndExecuteOnDstHook } from "./DeBridgeSendOrderAndExecuteOnDstHook.sol";
import { SuperVaultCapBridgeCommon } from "../SuperVaultCapBridgeCommon.sol";
import { ISuperHookResult } from "../../../interfaces/ISuperHook.sol";

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
///      `CROSS_CHAIN_POSITION_REGISTRY`), keeping the write-path (recordBridgedOut) and the
///      read-path (validateAllocation) pointed at one registry across governance migrations.
///
///      ECONOMIC DESTINATION vs TRANSPORT (B1): the order `receiverDst` is the bridge TRANSPORT
///      receiver — in the real destination flow it is the DebridgeAdapter, which forwards funds
///      and the external-call payload to SuperDestinationExecutor; it is NOT the economic
///      destination. This hook therefore:
///      - requires `receiverDst` to be a governance-approved destination adapter for the canonical
///        destination chain, and requires the external-call `executorAddress` to be that SAME
///        adapter (the contract deBridge hands the payload to);
///      - requires the external-call `fallbackAddress` to be the hub strategy account, so a failed
///        destination execution strands funds only on the hub-controlled account;
///      - decodes the destination payload into a strictly typed destination action (idle-hold on
///        the hub-controlled destination account, or a deposit into exactly one vault via the
///        governance-pinned destination hook pair);
///      - validates the cap and records the in-flight reservation against the canonical
///        (takeChainId, destinationVault) extracted from that action.
///      An order with NO external call (a raw token transfer to receiverDst) is rejected: it mints
///      no controlled shares and establishes no registrable position.
///
///      DECODE: the deBridge hookData layout is dynamic, so this hook reuses the parent's internal
///      `_createOrder(data, "")` decode (the same call the parent's own `inspect()` makes) to read
///      the exact order the bridge will create — validated-tuple == bridged-tuple by construction.
///      Passing an empty signature is safe: the signature only feeds the `externalCall` envelope
///      payload tail and never affects the validated fields.
///
///      SECURITY INVARIANT (not machine-enforced here): the cap only binds if every fund-exiting
///      leaf for a cap-enabled strategy routes through a cap-aware hook. Treat "only cap-aware
///      bridge hooks registered on host chains" as a monitored governance invariant.
contract SuperVaultDeBridgeCapBridgeHook is DeBridgeSendOrderAndExecuteOnDstHook, SuperVaultCapBridgeCommon {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev usePrevHookAmount bool offset — mirrors the parent (whose constant is private); drift is
    ///      caught by the offset-equivalence unit test, not by the compiler.
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 52;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the decoded destination is not an EVM address (receiverDst length != 20),
    ///         the destination chain id does not fit in a uint64, or the external-call envelope's
    ///         executor/fallback do not match the approved adapter / hub account
    error DATA_NOT_VALID();

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
        SuperVaultCapBridgeCommon(superGovernor_)
    {
        if (superGovernor_ == address(0)) revert ADDRESS_NOT_VALID();
    }

    /*//////////////////////////////////////////////////////////////
                              CAP ENFORCEMENT
    //////////////////////////////////////////////////////////////*/

    /// @dev Runs BEFORE the createOrder execution (called by the strategy=account). Validates the
    ///      allocation against the cross-chain caps and records the in-flight reservation. A cap
    ///      breach (or stale AUM, unapproved adapter, untyped destination action) reverts here,
    ///      aborting the whole executeHooks batch; if the later order send reverts, the reservation
    ///      is rolled back with the transaction. Preserves the parent pipe-mode behaviour via
    ///      `super`.
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        super._preExecute(prevHook, account, data);

        CapFields memory f = _decodeCapFields(data);

        // A failed destination execution must strand funds only on the hub-controlled account.
        // Runtime-only: `inspect` cannot know the executing account.
        if (f.fallbackAddress != account) revert DATA_NOT_VALID();

        // The amount validated is the amount the order actually gives; the delivery minimum is the
        // order's takeAmount. Under usePrevHookAmount the parent rewrites giveAmount to the
        // prev-hook output and rescales takeAmount by the same ratio — replicate exactly (R2-B1).
        uint256 amount;
        uint256 minDelivered = f.takeAmount;
        if (_decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION)) {
            amount = ISuperHookResult(prevHook).getOutAmount(account);
            if (f.orderGiveAmount > 0 && minDelivered > 0) {
                minDelivered = Math.mulDiv(minDelivered, amount, f.orderGiveAmount);
            }
        } else {
            amount = f.orderGiveAmount;
        }

        _enforceCrossChainCap(
            account, f.chainId, f.transportAdapter, amount, minDelivered, f.takeToken, f.destinationMessage
        );
    }

    /// @inheritdoc DeBridgeSendOrderAndExecuteOnDstHook
    /// @dev B1 leaf: pins the parent order-authority fields PLUS the cap dimensions — cap guard,
    ///      canonical destination chain, economic destination vault, destination action type and
    ///      the amount-source mode — so one approved leaf authorizes exactly one destination
    ///      configuration. Mutating only the external-call payload (a different vault) changes the
    ///      leaf and falls outside the approved root.
    function inspect(bytes calldata data) external view override returns (bytes memory) {
        (IDlnSource.OrderCreation memory order,,,) = _createOrder(data, "");
        CapFields memory f = _decodeCapFields(data);

        return abi.encodePacked(
            order.giveTokenAddress,
            address(bytes20(order.takeTokenAddress)),
            f.transportAdapter, // receiverDst = destination adapter (transport)
            order.givePatchAuthoritySrc,
            address(bytes20(order.orderAuthorityAddressDst)),
            address(bytes20(order.allowedCancelBeneficiarySrc)),
            // cap guard, canonical chain id, destination vault, action type, amount-source mode
            _capLeafSuffix(f.chainId, f.destinationMessage, _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION))
        );
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @dev Bundle to keep stacks shallow across the shared decode.
    struct CapFields {
        uint64 chainId;
        address transportAdapter;
        address fallbackAddress;
        uint256 orderGiveAmount;
        uint256 takeAmount; // delivery minimum on the destination (R2-B1 amount binding)
        address takeToken; // delivery token on the destination (R2-B1 token binding)
        bytes destinationMessage;
    }

    /// @dev Shared decode for `_preExecute` and `inspect`. Recreates the exact order the parent
    ///      will send (empty signature — it only affects the payload tail), enforces the EVM-only
    ///      and uint64 bounds, unwraps the external-call envelope and validates its executor
    ///      binding, and re-encodes the raw 5-tuple destination message for the common
    ///      typed-action validation. The fallback binding is account-dependent and checked by
    ///      `_preExecute` only.
    function _decodeCapFields(bytes calldata data) internal pure returns (CapFields memory f) {
        (IDlnSource.OrderCreation memory order,,,) = _createOrder(data, "");
        f.orderGiveAmount = order.giveAmount;

        // receiverDst is EVM-only for SuperVault caps: fail closed on a non-20-byte (e.g. 32-byte
        // Solana) destination instead of truncating it to a wrong address.
        if (order.receiverDst.length != 20) revert DATA_NOT_VALID();
        f.transportAdapter = address(bytes20(order.receiverDst));
        if (f.transportAdapter == address(0)) revert ADDRESS_NOT_VALID();

        // R2-B1: the destination delivery tuple the cap binds the action to. EVM-only take token.
        if (order.takeTokenAddress.length != 20) revert DATA_NOT_VALID();
        f.takeToken = address(bytes20(order.takeTokenAddress));
        f.takeAmount = order.takeAmount;

        // takeChainId is forwarded as a full uint256 to DlnSource; reject anything above uint64 so
        // the truncated cap/registry key cannot disagree with the chain the order actually targets.
        if (order.takeChainId > type(uint64).max) revert DATA_NOT_VALID();
        f.chainId = uint64(order.takeChainId);

        // An order without an external call is a raw transfer to receiverDst — not a typed
        // destination action.
        if (order.externalCall.length <= 1) revert DESTINATION_ACTION_NOT_VALID();

        // externalCall = abi.encodePacked(uint8 version, abi.encode(ExternalCallEnvelopV1)).
        IDlnSource.ExternalCallEnvelopV1 memory envelope = abi.decode(
            BytesLib.slice(order.externalCall, 1, order.externalCall.length - 1), (IDlnSource.ExternalCallEnvelopV1)
        );

        // The payload is executed by `executorAddress`; it must be the SAME approved adapter that
        // receives the funds.
        if (envelope.executorAddress != f.transportAdapter) revert DATA_NOT_VALID();
        f.fallbackAddress = envelope.fallbackAddress;

        // payload = abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts, sig).
        (
            bytes memory initData,
            bytes memory executorCalldata,
            address dstAccount,
            address[] memory dstTokens,
            uint256[] memory intentAmounts,
        ) = abi.decode(envelope.payload, (bytes, bytes, address, address[], uint256[], bytes));

        f.destinationMessage = abi.encode(initData, executorCalldata, dstAccount, dstTokens, intentAmounts);
    }
}
