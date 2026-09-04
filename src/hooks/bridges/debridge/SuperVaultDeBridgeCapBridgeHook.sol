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

    /// @notice Thrown when the external-call envelope's version or execution policy is not the
    ///         pinned one (version 1, required successful execution, no delayed execution, zero
    ///         execution fee) — see R3-RF2
    error EXECUTION_POLICY_NOT_VALID();

    /// @notice Thrown when `orderAuthorityAddressDst` is not exactly the 20-byte hub strategy
    ///         account — the authority can cancel an unfilled order (refunding the FULL giveAmount)
    ///         and patch takeAmount below the validated minimum, so it must be the account itself
    error ORDER_AUTHORITY_NOT_ACCOUNT();

    /// @notice Thrown when `allowedCancelBeneficiarySrc` is not exactly the 20-byte hub strategy
    ///         account — an empty value lets the authority refund a cancelled order's giveAmount
    ///         to an ARBITRARY address, so the refund destination must be the account itself
    error CANCEL_BENEFICIARY_NOT_ACCOUNT();

    /// @notice Thrown when a non-empty `affiliateFee` is encoded — a give-side skim to an
    ///         arbitrary beneficiary, deducted from giveAmount on fulfilment (see R3-RF2 mirror:
    ///         executionFee pins the take side, this pins the give side)
    error AFFILIATE_FEE_NOT_ALLOWED();

    /// @notice Thrown when the decoded takeToken is address(0) — native take delivery, which the
    ///         shared cap base cannot bind (its address(0) sentinel disables the destination-token
    ///         check) and which the ERC20-attesting destination action cannot consume
    error TAKE_TOKEN_NOT_VALID();

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
                          IDENTIFICATION (R3)
    //////////////////////////////////////////////////////////////*/

    /// @notice Unmistakably distinct from the uncapped parent — activation requires banning the
    ///         raw hook and authorizing only this one, so operators must never confuse the two.
    function name() external pure override returns (string memory) {
        return "SuperVault Capped deBridge Send Order";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Cap-enforced deBridge order for cross-chain SuperVaults: validates the typed destination action and records the reservation before bridging";
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

        // P1: the order authority can cancel an unfilled order on the take chain (refunding the
        // FULL giveAmount to allowedCancelBeneficiarySrc — or to ANY address when that field is
        // empty) and can patch takeAmount below the validated delivery minimum. Both are therefore
        // runtime-pinned to the hub strategy account (deterministic same-address account across
        // chains — the same assumption the fallbackAddress binding above relies on), matching the
        // designed cancel path where the account itself sends the cancel with itself as
        // beneficiary. Runtime-only: `inspect` cannot know the executing account.
        if (f.orderAuthority != account) revert ORDER_AUTHORITY_NOT_ACCOUNT();
        if (f.cancelBeneficiary != account) revert CANCEL_BENEFICIARY_NOT_ACCOUNT();

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
    ///      leaf and falls outside the approved root. The orderAuthorityAddressDst and
    ///      allowedCancelBeneficiarySrc fields stay in the leaf for parent-compatibility but are
    ///      RUNTIME-pinned to the hub strategy account by `_preExecute` (the leaf's 20-byte view
    ///      cannot distinguish empty bytes from address(0)), closing cancel-theft, fund-lock and
    ///      takeAmount patch-down regardless of what a leaf reviewer approves.
    function inspect(bytes calldata data) external view override returns (bytes memory) {
        (IDlnSource.OrderCreation memory order,,,) = _createOrder(data, "");
        CapFields memory f = _decodeCapFields(data);

        return abi.encodePacked(
            order.giveTokenAddress,
            f.takeToken,
            f.transportAdapter, // receiverDst = destination adapter (transport)
            order.givePatchAuthoritySrc,
            f.orderAuthority, // runtime-pinned to the account by _preExecute (P1)
            f.cancelBeneficiary, // runtime-pinned to the account by _preExecute (P1)
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
        address orderAuthority; // cancel/patch authority on the take chain (P1: pinned to account)
        address cancelBeneficiary; // cancel refund destination on the give chain (P1: pinned to account)
        uint256 orderGiveAmount;
        uint256 takeAmount; // delivery minimum on the destination (R2-B1 amount binding)
        address takeToken; // delivery token on the destination (R2-B1 token binding)
        bytes destinationMessage;
    }

    /// @dev Shared decode for `_preExecute` and `inspect`. Recreates the exact order the parent
    ///      will send (empty signature — it only affects the payload tail), enforces the EVM-only
    ///      and uint64 bounds, unwraps the external-call envelope and validates its executor
    ///      binding, and re-encodes the raw 5-tuple destination message for the common
    ///      typed-action validation. The fallback/authority/cancel-beneficiary bindings are
    ///      account-dependent and checked by `_preExecute` only (this decode enforces their
    ///      20-byte shape).
    function _decodeCapFields(bytes calldata data) internal pure returns (CapFields memory f) {
        (IDlnSource.OrderCreation memory order,, bytes memory affiliateFee,) = _createOrder(data, "");
        f.orderGiveAmount = order.giveAmount;

        // P2: affiliateFee is a give-side skim (beneficiary, amount) deducted from giveAmount on
        // fulfilment — the give-chain twin of the pinned executionFee below. Forbid it entirely:
        // nothing may be skimmed from the reserved amount on either side.
        if (affiliateFee.length != 0) revert AFFILIATE_FEE_NOT_ALLOWED();

        // receiverDst is EVM-only for SuperVault caps: fail closed on a non-20-byte (e.g. 32-byte
        // Solana) destination instead of truncating it to a wrong address.
        if (order.receiverDst.length != 20) revert DATA_NOT_VALID();
        f.transportAdapter = address(bytes20(order.receiverDst));
        if (f.transportAdapter == address(0)) revert ADDRESS_NOT_VALID();

        // R2-B1: the destination delivery tuple the cap binds the action to. EVM-only take token.
        if (order.takeTokenAddress.length != 20) revert DATA_NOT_VALID();
        f.takeToken = address(bytes20(order.takeTokenAddress));
        // P3: a zero takeToken means NATIVE take delivery (onEtherReceived) while the destination
        // action attests an ERC20 — and it would disable the shared base's destination-token
        // binding (its address(0) sentinel exists only for non-derivable Stargate OFT outputs;
        // deBridge always knows its take token). Fail closed.
        if (f.takeToken == address(0)) revert TAKE_TOKEN_NOT_VALID();
        f.takeAmount = order.takeAmount;

        // takeChainId is forwarded as a full uint256 to DlnSource; reject anything above uint64 so
        // the truncated cap/registry key cannot disagree with the chain the order actually targets.
        if (order.takeChainId > type(uint64).max) revert DATA_NOT_VALID();
        f.chainId = uint64(order.takeChainId);

        // P1: the cancel/patch authority and the cancel refund beneficiary must be exact 20-byte
        // EVM addresses (an empty or non-EVM value can never be the hub account — and the leaf's
        // address(bytes20(...)) view cannot distinguish empty bytes from address(0), so this MUST
        // be enforced here, not by leaf review). `_preExecute` pins both to the account.
        if (order.orderAuthorityAddressDst.length != 20) revert ORDER_AUTHORITY_NOT_ACCOUNT();
        f.orderAuthority = address(bytes20(order.orderAuthorityAddressDst));
        if (order.allowedCancelBeneficiarySrc.length != 20) revert CANCEL_BENEFICIARY_NOT_ACCOUNT();
        f.cancelBeneficiary = address(bytes20(order.allowedCancelBeneficiarySrc));

        // An order without an external call is a raw transfer to receiverDst — not a typed
        // destination action.
        if (order.externalCall.length <= 1) revert DESTINATION_ACTION_NOT_VALID();

        // R3-RF2: the envelope VERSION decides how the destination interprets everything that
        // follows — only the supported V1 layout is capped.
        if (uint8(order.externalCall[0]) != 1) revert EXECUTION_POLICY_NOT_VALID();

        // externalCall = abi.encodePacked(uint8 version, abi.encode(ExternalCallEnvelopV1)).
        IDlnSource.ExternalCallEnvelopV1 memory envelope = abi.decode(
            BytesLib.slice(order.externalCall, 1, order.externalCall.length - 1), (IDlnSource.ExternalCallEnvelopV1)
        );

        // The payload is executed by `executorAddress`; it must be the SAME approved adapter that
        // receives the funds.
        if (envelope.executorAddress != f.transportAdapter) revert DATA_NOT_VALID();

        // R3-RF2: pin the execution policy by construction — these envelope controls decide
        // whether the signed destination action MUST run (vs. silently falling back to an idle
        // transfer the reservation cannot represent), and they sit OUTSIDE the signed payload
        // and the parent leaf. Hardcoding them here means no leaf can ever authorize a variant:
        // - requireSuccessfullExecution: a failed vault action must fail the fill, not strand
        //   funds idle under a vault-bound reservation;
        // - !allowDelayedExecution: fulfilment and execution stay atomic, compatible with the
        //   reservation/confirmation timeouts;
        // - executionFee == 0: nothing may be skimmed from the delivered amount for a taker
        //   (the give-side twin, affiliateFee, is forbidden above — both skim sides are closed).
        if (!envelope.requireSuccessfullExecution || envelope.allowDelayedExecution || envelope.executionFee != 0) {
            revert EXECUTION_POLICY_NOT_VALID();
        }
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
