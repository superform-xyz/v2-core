// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// Superform
import { ApproveAndAcrossSendFundsAndExecuteOnDstHook } from "./ApproveAndAcrossSendFundsAndExecuteOnDstHook.sol";
import { SuperVaultCapBridgeCommon } from "../SuperVaultCapBridgeCommon.sol";
import { ISuperHookResult } from "../../../interfaces/ISuperHook.sol";

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
///      `CROSS_CHAIN_POSITION_REGISTRY`), keeping the write-path (recordBridgedOut) and the
///      read-path (validateAllocation) pointed at one registry across governance migrations.
///
///      ECONOMIC DESTINATION vs TRANSPORT (B1): the Across `recipient` is the bridge TRANSPORT
///      receiver — in the real destination flow it is the AcrossV3Adapter, which forwards funds
///      and the message to SuperDestinationExecutor; it is NOT the economic destination. This hook
///      therefore:
///      - requires `recipient` to be a governance-approved destination adapter for the canonical
///        destination chain;
///      - decodes the `destinationMessage` into a strictly typed destination action (idle-hold on
///        the hub-controlled destination account, or a deposit into exactly one vault via the
///        governance-pinned destination hook pair);
///      - validates the cap and records the in-flight reservation against the canonical
///        (destinationChainId, destinationVault) extracted from that action.
///      An empty destinationMessage (a raw token transfer) is rejected: it mints no controlled
///      shares and establishes no registrable position.
///
///      The destination chain and amount are read from the same hookData the bridge send uses, so
///      the validated amount is exactly the amount the parent hands to `depositV3Now` (offsets are
///      pinned by the offset-equivalence unit test).
///
///      REFUND: the parent passes the strategy `account` as the Across depositor, so an unfilled
///      deposit refunds principal to the strategy on the origin chain. The in-flight reservation
///      recorded here is reconciled 1:1 by the registry: consumed by exactly one position
///      registration, released on confirmation, or reclaimed after the reservation timeout.
///
///      SECURITY INVARIANT (not machine-enforced here): the cap only binds if every fund-exiting
///      leaf for a cap-enabled strategy routes through a cap-aware hook. Authorizing any uncapped
///      bridge/transfer hook for such a strategy bypasses the cap. Treat "only cap-aware bridge
///      hooks registered on host chains" as a monitored governance invariant.
contract SuperVaultAcrossCapBridgeHook is ApproveAndAcrossSendFundsAndExecuteOnDstHook, SuperVaultCapBridgeCommon {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev hookData offsets — mirror the parent (locked) layout; drift is caught by the
    ///      offset-equivalence unit test, not by the compiler (the parent's constants are private).
    uint256 private constant RECIPIENT_OFFSET = 84;
    uint256 private constant OUTPUT_TOKEN_OFFSET = 124;
    uint256 private constant INPUT_AMOUNT_OFFSET = 144;
    uint256 private constant OUTPUT_AMOUNT_OFFSET = 176;
    uint256 private constant DST_CHAIN_ID_OFFSET = 208;
    uint256 private constant USE_PREV_HOOK_AMOUNT_OFFSET = 268;
    uint256 private constant DESTINATION_MESSAGE_OFFSET = 269;

    /// @dev Minimum hookData length the cap decode requires: the usePrevHookAmount bool sits at
    ///      offset 268, so the buffer must be at least 269 bytes before any fixed-offset read.
    uint256 private constant MIN_CAP_DATA_LENGTH = 269;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice The Across outputToken is address(0) — the SpokePool's "destination equivalent of
    ///         the input token" sentinel, which the cap's destination-token binding cannot verify
    error OUTPUT_TOKEN_NOT_VALID();

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
        return "SuperVault Capped Approve and Across Bridge";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Cap-enforced Across bridge for cross-chain SuperVaults: validates the typed destination action and records the reservation before bridging";
    }

    /*//////////////////////////////////////////////////////////////
                              CAP ENFORCEMENT
    //////////////////////////////////////////////////////////////*/

    /// @dev Runs BEFORE the approve/bridge executions (called by the strategy=account). Validates
    ///      the allocation against the cross-chain caps and records the in-flight reservation. A
    ///      cap breach (or stale AUM, unapproved adapter, untyped destination action) reverts here,
    ///      aborting the whole executeHooks batch; if the later bridge send reverts, the
    ///      reservation is rolled back with the transaction. Preserves the parent pipe-mode
    ///      passthrough behaviour via `super`.
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        super._preExecute(prevHook, account, data);

        (uint64 chainId, address transportAdapter, bytes memory destinationMessage) = _decodeCapFields(data);

        // The amount validated is the amount the bridge will actually send; the delivery minimum
        // is the outputAmount the fill must pay. Under usePrevHookAmount, replicate the parent's
        // exact rescale so validated == bridged for both (R2-B1).
        uint256 amount;
        uint256 minDelivered = BytesLib.toUint256(data, OUTPUT_AMOUNT_OFFSET);
        if (_decodeBool(data, USE_PREV_HOOK_AMOUNT_OFFSET)) {
            uint256 inputAmount = BytesLib.toUint256(data, INPUT_AMOUNT_OFFSET);
            amount = ISuperHookResult(prevHook).getOutAmount(account);
            if (inputAmount > 0 && minDelivered > 0) {
                minDelivered = Math.mulDiv(minDelivered, amount, inputAmount);
            }
        } else {
            amount = BytesLib.toUint256(data, INPUT_AMOUNT_OFFSET);
        }

        _enforceCrossChainCap(
            account,
            chainId,
            transportAdapter,
            amount,
            minDelivered,
            BytesLib.toAddress(data, OUTPUT_TOKEN_OFFSET),
            destinationMessage
        );
    }

    /// @inheritdoc ApproveAndAcrossSendFundsAndExecuteOnDstHook
    /// @dev B1 leaf: pins the parent transport fields PLUS the cap dimensions — cap guard,
    ///      canonical destination chain, economic destination vault, destination action type and
    ///      the amount-source mode — so one approved leaf authorizes exactly one destination
    ///      configuration. Mutating only the executor calldata (a different vault) changes the
    ///      leaf and falls outside the approved root.
    function inspect(bytes calldata data) external view override returns (bytes memory) {
        (uint64 chainId, address transportAdapter, bytes memory destinationMessage) = _decodeCapFields(data);

        return abi.encodePacked(
            transportAdapter, // recipient = destination adapter (transport)
            BytesLib.toAddress(data, 104), // inputToken
            BytesLib.toAddress(data, 124), // outputToken
            BytesLib.toAddress(data, 240), // exclusiveRelayer
            // cap guard, canonical chain id, destination vault, action type, amount-source mode
            _capLeafSuffix(chainId, destinationMessage, _decodeBool(data, USE_PREV_HOOK_AMOUNT_OFFSET))
        );
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @dev Shared decode for `_preExecute` and `inspect`: canonical chain id (the full uint256 the
    ///      parent forwards to the SpokePool, rejected above uint64 so the cap/registry key cannot
    ///      disagree with the chain the bridge is instructed to use), the transport receiver, and
    ///      the raw destination message.
    function _decodeCapFields(bytes calldata data)
        internal
        pure
        returns (uint64 chainId, address transportAdapter, bytes memory destinationMessage)
    {
        // Guard the fixed-offset reads with the typed error before touching any offset.
        if (data.length < MIN_CAP_DATA_LENGTH) revert DATA_NOT_VALID();

        // P3: modern SpokePools treat outputToken == address(0) as "destination equivalent of the
        // inputToken" — a sentinel this hook's destination-token binding cannot verify (the shared
        // base skips the binding for address(0), a carve-out meant only for Stargate OFT routes).
        // Across can always express the token explicitly, so a zero outputToken is rejected.
        if (BytesLib.toAddress(data, OUTPUT_TOKEN_OFFSET) == address(0)) revert OUTPUT_TOKEN_NOT_VALID();

        uint256 rawChainId = BytesLib.toUint256(data, DST_CHAIN_ID_OFFSET);
        if (rawChainId > type(uint64).max) revert DATA_NOT_VALID();
        chainId = uint64(rawChainId);

        transportAdapter = BytesLib.toAddress(data, RECIPIENT_OFFSET);
        destinationMessage = data[DESTINATION_MESSAGE_OFFSET:];
    }
}
