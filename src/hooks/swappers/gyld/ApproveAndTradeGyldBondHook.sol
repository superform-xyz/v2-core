// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { SwapCalldataLayout } from "../../../libraries/SwapCalldataLayout.sol";
import { GyldBondRegistry } from "../../../accounting/oracles/GyldBondRegistry.sol";
import { ISuperHookSwap } from "../../../interfaces/ISuperHookSwap.sol";
import {
    ISuperHookContextAware,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";

/// @title ApproveAndTradeGyldBondHook
/// @author Superform Labs
/// @notice Buys or sells a registered Gyld tokenized bond against its approved cash token, in one atomic leg.
/// @dev ONE HOOK, BOTH DIRECTIONS. Direction is implied by `(inputToken, outputToken)`, which `inspect()`
///      commits into the Merkle leaf: a buy leaf (cash in, bond out) is a different leaf from a sell leaf, and
///      neither authorises any other token. That is the repo convention for every venue — there is not a single
///      direction-flag swap hook in `src/hooks/swappers/` — and it is also what enforces "the approved pair".
/// @dev THE STRATEGY IS THE TRADING ACCOUNT, PAYER AND RECIPIENT. Every execution below runs as the executing
///      smart account. This hook never holds a token, never takes an approval for itself, and names no operator.
///      That property only survives end to end if the venue pulls from and delivers to `msg.sender`, or
///      validates its quote's taker against it — requirement R2 in `IGyldSettlement`.
/// @dev OPAQUE VENUE CALLDATA, OUTCOME VALIDATION. Gyld's settlement ABI is unconfirmed and may sit behind a
///      proxy, so the venue calldata is forwarded verbatim and the hook validates the RESULT: a scoped
///      allowance, a minimum output actually received, no more input spent than authorised, and no standing
///      allowance left behind. This is the `ApproveAndSwapBinanceHook` posture. Pinning `GYLD_SETTLEMENT` pins
///      the address, not the code.
/// @dev NO PLAIN VARIANT SHIPS. The live allowance is the only input-side bound on opaque calldata, so the
///      approval must be scoped to this execution rather than left standing by a separate approve leaf.
/// @dev REPLAY PROTECTION IS A VENUE GUARANTEE, NOT A HOOK FEATURE. SuperVault leaves carry no amount and no
///      nonce and are reusable within and across transactions by design. The per-transaction cap below bounds
///      the DAMAGE of repetition, never the repetition itself. The venue must enforce single-use quote ids
///      (R1). This is the same posture the Pendle hooks take toward the Pendle Router's nonce manager.
/// @dev SIZELESS. The spend is committed inside a venue-signed quote, so the OMS cannot rewrite it at execution
///      time without invalidating the signature. The header `inputAmount` is the allowance bound only.
/// @dev Payload (Layer 2): abi.encode(uint256 quoteDeadline, bytes venueCalldata)
/// @dev data has the following structure (standard 52-byte strategy header + Layer 1 + Layer 2):
/// @notice         bytes32   placeholder0        = BytesLib.toBytes32(data, 0);
/// @notice         address   placeholder1        = BytesLib.toAddress(data, 32);
/// @notice         address   inputToken          = BytesLib.toAddress(data, 52);
/// @notice         address   outputToken         = BytesLib.toAddress(data, 72);
/// @notice         uint256   inputAmount         = BytesLib.toUint256(data, 92);
/// @notice         uint256   outputQuote         = BytesLib.toUint256(data, 124);
/// @notice         uint256   outputMin           = BytesLib.toUint256(data, 156);
/// @notice         bool      usePrevHookAmount   = _decodeBool(data, 188);
/// @notice         uint256   payload_paramLength = BytesLib.toUint256(data, 189);
/// @notice         bytes     payload             = BytesLib.slice(data, 221, payload_paramLength);
/// @dev `usePrevHookAmount` is read and REJECTED when true; a venue-signed quote cannot absorb a resized
///      amount. `inputAmount` bounds the allowance only and is NOT the spend. `outputQuote` and `outputMin`
///      are caller-supplied and are NOT committed into the Merkle leaf, so `MIN_OUT_NOT_MET` guards an
///      honest manager's mistake; `MAX_INPUT_AMOUNT` is what bounds a compromised key.
/// @dev TWO DELIBERATE DEVIATIONS FROM THE MAJORITY OF THE SWAP FAMILY, both relevant to whoever builds the
///      calldata off-chain. Pinned by `GyldSwapEncodingConformance.t.sol`.
///      1. `outputQuote` IS CONSTRAINED. Most swappers treat it as informational and never read it beyond
///         `decodeOutputQuote` (the Binance E2E suite passes zero for it, and the shared 1inch-style test
///         builder passes zero for both quote and min). This hook requires `outputMin != 0` and
///         `outputQuote >= outputMin`, following `BaseAerodromeUniversalRouterHook`'s
///         `if (originalAmountOutMin == 0 || outputQuote < originalAmountOutMin) revert` precedent.
///         CONSEQUENCE: an encoder that leaves either field at zero produces leaves this hook REJECTS, so
///         the OMS must populate both. A generic swap-hook builder will not drive this hook unchanged.
///      2. `usePrevHookAmount` is faithfully ENCODED and DECODED, per the standard, but rejected at build.
///         The flag must still round-trip so the executor's own inspection of the chain agrees with the
///         hook, which is why it is not simply ignored.
/// @dev Everything else is the standard: `encodeSwapData` is byte-identical to its peers, every decoder
///      reads the offset `SwapCalldataLayout` declares, `inspect()` commits the token pair as the swap
///      family does, and `ISuperHookSwap` is deliberately NOT advertised through ERC-165, matching the fleet.
contract ApproveAndTradeGyldBondHook is
    BaseHook,
    ISuperHookSwap,
    ISuperHookContextAware,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
{
    /*//////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Gyld's settlement contract, pinned at deploy time. The only call target.
    address public immutable GYLD_SETTLEMENT;

    /// @notice The approved-instrument list. Decides which pairs and cash denominations are tradable.
    GyldBondRegistry public immutable GYLD_REGISTRY;

    /// @notice Ceiling on the SUM of header `inputAmount`s this hook approves for one account within one
    ///         transaction, in raw token units.
    /// @dev Per-TRANSACTION, not per-execution: a Merkle leaf carries no amount, so one leaf can be repeated.
    ///      This is the only on-chain bound on a compromised manager key in the SuperVault path.
    uint256 public immutable MAX_INPUT_AMOUNT;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 private constant TX_SPENT_KEY = keccak256("ApproveAndTradeGyldBondHook.txSpent");
    bytes32 private constant SNAPSHOT_KEY = keccak256("ApproveAndTradeGyldBondHook.snapshot");
    bytes32 private constant IN_BALANCE_KEY = keccak256("ApproveAndTradeGyldBondHook.inBalance");

    address private constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @dev A selector is the minimum meaningful venue calldata.
    uint256 private constant MIN_VENUE_CALLDATA_LENGTH = 4;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error INVALID_HOOK_DATA();
    error USE_PREV_HOOK_NOT_SUPPORTED();
    error NATIVE_ETH_NOT_SUPPORTED();
    error SAME_INPUT_OUTPUT_TOKEN();
    /// @notice Neither side of the pair is a registered bond with the other as its configured cash token
    error PAIR_NOT_APPROVED();
    error MIN_OUT_NOT_VALID();
    error MIN_OUT_NOT_MET();
    error QUOTE_BELOW_MIN();
    error QUOTE_EXPIRED();
    error INPUT_EXCEEDS_CAP();
    error INPUT_OVERSPENT();
    error OUTPUT_BALANCE_DECREASED();
    error ALLOWANCE_NOT_CLEARED();
    error SNAPSHOT_NOT_TAKEN();

    constructor(
        address gyldSettlement_,
        address gyldRegistry_,
        uint256 maxInputAmount_
    )
        BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP)
    {
        if (gyldSettlement_ == address(0) || gyldRegistry_ == address(0)) revert ADDRESS_NOT_VALID();
        if (maxInputAmount_ == 0) revert AMOUNT_NOT_VALID();
        GYLD_SETTLEMENT = gyldSettlement_;
        GYLD_REGISTRY = GyldBondRegistry(gyldRegistry_);
        MAX_INPUT_AMOUNT = maxInputAmount_;
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Approve and Trade Gyld Bond";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Approves and buys or sells a registered Gyld tokenized bond against its approved cash token";
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sum of header `inputAmount`s this hook has approved for `account` in the current transaction
    /// @dev Transient; reads as zero in any later transaction.
    function txSpent(address account) external view returns (uint256) {
        return _getTxSpent(account);
    }

    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address, /* prevHook */
        address, /* account */
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        (address inputToken, uint256 inputAmount) = _validateHeader(data);
        bytes memory venueCalldata = _validatePayload(data);

        // Scope the allowance to exactly this execution. ERC20 only: every execution carries value 0.
        bytes memory clearApproval = abi.encodeCall(IERC20.approve, (GYLD_SETTLEMENT, 0));
        executions = new Execution[](4);
        executions[0] = Execution({ target: inputToken, value: 0, callData: clearApproval });
        executions[1] = Execution({
            target: inputToken, value: 0, callData: abi.encodeCall(IERC20.approve, (GYLD_SETTLEMENT, inputAmount))
        });
        executions[2] = Execution({ target: GYLD_SETTLEMENT, value: 0, callData: venueCalldata });
        executions[3] = Execution({ target: inputToken, value: 0, callData: clearApproval });
    }

    /// @notice Validates the Layer 1 header and the approved pair
    /// @dev Length is checked first so every later fixed-offset read is in bounds.
    function _validateHeader(bytes calldata data) private view returns (address inputToken, uint256 inputAmount) {
        if (data.length < SwapCalldataLayout.MIN_DATA_LENGTH) revert INVALID_HOOK_DATA();
        // A venue-signed quote cannot absorb a resized amount.
        if (_decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET)) revert USE_PREV_HOOK_NOT_SUPPORTED();

        inputToken = BytesLib.toAddress(data, SwapCalldataLayout.INPUT_TOKEN_OFFSET);
        _validatePair(inputToken, BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET));

        inputAmount = BytesLib.toUint256(data, SwapCalldataLayout.INPUT_AMOUNT_OFFSET);
        if (inputAmount == 0) revert AMOUNT_NOT_VALID();
        // Bound loss-per-transaction. Equal to the cap is allowed.
        if (inputAmount > MAX_INPUT_AMOUNT) revert INPUT_EXCEEDS_CAP();

        uint256 outputMin = BytesLib.toUint256(data, SwapCalldataLayout.OUTPUT_MIN_OFFSET);
        // Slippage protection is not opt-out.
        if (outputMin == 0) revert MIN_OUT_NOT_VALID();
        if (BytesLib.toUint256(data, SwapCalldataLayout.OUTPUT_QUOTE_OFFSET) < outputMin) revert QUOTE_BELOW_MIN();
    }

    /// @notice Rejects anything that is not an approved bond-against-its-cash-token pair
    /// @dev Exactly one side must be a registered bond and the other must be THAT instrument's configured cash
    ///      token, which rejects a bond-for-bond trade, an unapproved cash denomination and an unregistered
    ///      instrument in one check.
    function _validatePair(address inputToken, address outputToken) private view {
        if (!_isERC20(inputToken) || !_isERC20(outputToken)) revert NATIVE_ETH_NOT_SUPPORTED();
        if (inputToken == outputToken) revert SAME_INPUT_OUTPUT_TOKEN();
        if (
            !GYLD_REGISTRY.isApprovedPair(outputToken, inputToken)
                && !GYLD_REGISTRY.isApprovedPair(inputToken, outputToken)
        ) {
            revert PAIR_NOT_APPROVED();
        }
    }

    /// @notice Validates the Layer 2 payload and returns the opaque venue calldata
    /// @dev The deadline is checked before any approval is granted. The venue enforces the expiry inside its
    ///      own signed payload (R3); this is the cheap, named, pre-approval check on the caller's copy of it.
    function _validatePayload(bytes calldata data) private view returns (bytes memory venueCalldata) {
        uint256 payloadLength = BytesLib.toUint256(data, SwapCalldataLayout.PAYLOAD_LENGTH_OFFSET);
        if (SwapCalldataLayout.PAYLOAD_DATA_OFFSET + payloadLength > data.length) revert INVALID_HOOK_DATA();
        bytes memory payload = BytesLib.slice(data, SwapCalldataLayout.PAYLOAD_DATA_OFFSET, payloadLength);

        uint256 quoteDeadline;
        (quoteDeadline, venueCalldata) = abi.decode(payload, (uint256, bytes));
        if (quoteDeadline == 0 || block.timestamp > quoteDeadline) revert QUOTE_EXPIRED();
        if (venueCalldata.length < MIN_VENUE_CALLDATA_LENGTH) revert INVALID_HOOK_DATA();
    }

    /*//////////////////////////////////////////////////////////////
                             EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    /// @dev Sizeless: the spend is inside a venue-signed quote, so no slot here is OMS-rewritable.
    function decodeAmounts(bytes memory) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](0);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory)
        external
        pure
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        meta = new ISuperHookInflowOutflow.AmountMeta[](0);
    }

    /// @dev Implements ISuperHookInflowOutflow + ISuperHookOutflow as authoritatively sizeless
    function _supportsSizingInterface() internal pure override returns (bool) {
        return true;
    }

    /// @inheritdoc ISuperHookOutflow
    /// @dev Identity. Reverts only if a caller tries to splice an amount into a sizeless hook.
    function replaceCalldataAmounts(
        bytes memory data,
        uint256[] memory amounts
    )
        external
        pure
        override
        returns (bytes memory)
    {
        if (amounts.length != 0) revert INVALID_AMOUNTS_LENGTH();
        return data;
    }

    /// @inheritdoc ISuperHookInspector
    /// @dev Commits BOTH tokens, packed (40 bytes). This is what makes the direction and the pair part of the
    ///      signed permission: a sell leaf cannot execute a buy, and neither authorises an unapproved token.
    ///      The settlement contract is committed transitively, because it is an immutable of this hook.
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        if (data.length < SwapCalldataLayout.MIN_DATA_LENGTH) revert INVALID_HOOK_DATA();
        return abi.encodePacked(
            BytesLib.toAddress(data, SwapCalldataLayout.INPUT_TOKEN_OFFSET),
            BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET)
        );
    }

    /*//////////////////////////////////////////////////////////////
                             ISuperHookSwap
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookSwap
    function encodeSwapData(
        ISuperHookSwap.SwapHeader calldata header,
        bytes calldata payload
    )
        external
        pure
        override
        returns (bytes memory)
    {
        return bytes.concat(
            bytes(new bytes(SwapCalldataLayout.HEADER_SIZE)),
            bytes20(header.inputToken),
            bytes20(header.outputToken),
            bytes32(header.inputAmount),
            bytes32(header.outputQuote),
            bytes32(header.outputMin),
            bytes1(header.usePrevHookAmount ? uint8(1) : uint8(0)),
            bytes32(payload.length),
            payload
        );
    }

    /// @inheritdoc ISuperHookSwap
    function decodeInputToken(bytes calldata data) external pure override returns (address) {
        return BytesLib.toAddress(data, SwapCalldataLayout.INPUT_TOKEN_OFFSET);
    }

    /// @inheritdoc ISuperHookSwap
    function decodeOutputToken(bytes calldata data) external pure override returns (address) {
        return BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
    }

    /// @inheritdoc ISuperHookSwap
    function decodeInputAmount(bytes calldata data) external pure override returns (uint256) {
        return BytesLib.toUint256(data, SwapCalldataLayout.INPUT_AMOUNT_OFFSET);
    }

    /// @inheritdoc ISuperHookSwap
    function decodeOutputQuote(bytes calldata data) external pure override returns (uint256) {
        return BytesLib.toUint256(data, SwapCalldataLayout.OUTPUT_QUOTE_OFFSET);
    }

    /// @inheritdoc ISuperHookSwap
    function decodeOutputMin(bytes calldata data) external pure override returns (uint256) {
        return BytesLib.toUint256(data, SwapCalldataLayout.OUTPUT_MIN_OFFSET);
    }

    /// @inheritdoc ISuperHookSwap
    function decodePayload(bytes calldata data) external pure override returns (bytes memory) {
        uint256 payloadLen = BytesLib.toUint256(data, SwapCalldataLayout.PAYLOAD_LENGTH_OFFSET);
        return BytesLib.slice(data, SwapCalldataLayout.PAYLOAD_DATA_OFFSET, payloadLen);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    function _preExecute(address, address account, bytes calldata data) internal override {
        // Per-transaction cap on the running sum, checked before any approval is granted.
        uint256 spent = _getTxSpent(account) + BytesLib.toUint256(data, SwapCalldataLayout.INPUT_AMOUNT_OFFSET);
        if (spent > MAX_INPUT_AMOUNT) revert INPUT_EXCEEDS_CAP();
        _setTxSpent(account, spent);

        address inputToken = BytesLib.toAddress(data, SwapCalldataLayout.INPUT_TOKEN_OFFSET);
        address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);

        _setOutAmount(IERC20(outputToken).balanceOf(account), account);
        // Input-side snapshot: the only way to notice a venue that takes cash and delivers nothing
        // without reverting.
        _setInBalance(account, IERC20(inputToken).balanceOf(account));
        _setSnapshotTaken(account, true);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        // Refuse to compare against a context that never took a snapshot.
        if (!_getSnapshotTaken(account)) revert SNAPSHOT_NOT_TAKEN();
        _setSnapshotTaken(account, false);

        address inputToken = BytesLib.toAddress(data, SwapCalldataLayout.INPUT_TOKEN_OFFSET);
        address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);

        uint256 balanceAfter = IERC20(outputToken).balanceOf(account);
        uint256 balanceBefore = getOutAmount(account);
        // Named rather than an arithmetic panic: a bond issuer may hold burn or seize powers.
        if (balanceAfter < balanceBefore) revert OUTPUT_BALANCE_DECREASED();
        uint256 received = balanceAfter - balanceBefore;
        if (received < BytesLib.toUint256(data, SwapCalldataLayout.OUTPUT_MIN_OFFSET)) revert MIN_OUT_NOT_MET();

        // "Failed trades must not leave partial transfers" — this is the teeth. More input left the account
        // than was authorised means the venue over-pulled, whatever it reported.
        uint256 inputBefore = _getInBalance(account);
        uint256 inputAfter = IERC20(inputToken).balanceOf(account);
        if (inputBefore > inputAfter) {
            uint256 inputSpent = inputBefore - inputAfter;
            if (inputSpent > BytesLib.toUint256(data, SwapCalldataLayout.INPUT_AMOUNT_OFFSET)) {
                revert INPUT_OVERSPENT();
            }
        }
        _setInBalance(account, 0);

        // No standing allowance may survive: catches tokens whose approve(0) silently no-ops.
        if (IERC20(inputToken).allowance(account, GYLD_SETTLEMENT) != 0) revert ALLOWANCE_NOT_CLEARED();

        _setOutAmount(received, account);
        _setOutToken(outputToken, account);
    }

    /*//////////////////////////////////////////////////////////////
                             PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/

    function _isERC20(address token) private pure returns (bool) {
        return token != address(0) && token != NATIVE_TOKEN;
    }

    function _txSpentKey(address account) private pure returns (bytes32) {
        return keccak256(abi.encode(TX_SPENT_KEY, account));
    }

    /// @dev Keyed by account only, NOT by execution nonce, so the cap accumulates across every repetition of a
    ///      leaf inside one transaction.
    function _getTxSpent(address account) private view returns (uint256 value) {
        bytes32 key = _txSpentKey(account);
        assembly ("memory-safe") {
            value := tload(key)
        }
    }

    function _setTxSpent(address account, uint256 value) private {
        bytes32 key = _txSpentKey(account);
        assembly ("memory-safe") {
            tstore(key, value)
        }
    }

    function _inBalanceKey(address account) private view returns (bytes32) {
        return keccak256(abi.encode(IN_BALANCE_KEY, account, executionNonce));
    }

    function _getInBalance(address account) private view returns (uint256 value) {
        bytes32 key = _inBalanceKey(account);
        assembly ("memory-safe") {
            value := tload(key)
        }
    }

    function _setInBalance(address account, uint256 value) private {
        bytes32 key = _inBalanceKey(account);
        assembly ("memory-safe") {
            tstore(key, value)
        }
    }

    /// @dev Keyed by execution nonce too: any mid-batch `setExecutionContext` makes this read unset, so
    ///      `_postExecute` fails closed rather than comparing against a foreign snapshot.
    function _snapshotKey(address account) private view returns (bytes32) {
        return keccak256(abi.encode(SNAPSHOT_KEY, account, executionNonce));
    }

    function _getSnapshotTaken(address account) private view returns (bool value) {
        bytes32 key = _snapshotKey(account);
        assembly ("memory-safe") {
            value := tload(key)
        }
    }

    function _setSnapshotTaken(address account, bool value) private {
        bytes32 key = _snapshotKey(account);
        assembly ("memory-safe") {
            tstore(key, value)
        }
    }
}
