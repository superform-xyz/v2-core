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
import { ISuperHookSwap } from "../../../interfaces/ISuperHookSwap.sol";
import {
    ISuperHookContextAware,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";

/// @title ApproveAndSwapBinanceHook
/// @author Superform Labs
/// @notice Swaps ERC20 -> ERC20 via the Binance Web3 Trading API DEX router on BNB Chain.
/// @dev Named for the router it pins; "LiquidMesh" is a routing venue in Binance's API, not a contract.
/// @dev SIZELESS and NO CHAINING: the spend amount is committed inside the opaque router calldata, so
///      neither a resized header `inputAmount` nor a previous hook's output can be reflected in what
///      the router executes. The OMS re-quotes instead.
/// @dev NO plain `Swap` variant: the live allowance is the only input-side bound on the opaque blob, so
///      approval must be scoped to this execution rather than left standing by a separate approve leaf.
/// @dev No in-hook compliance check: the bStocks sanctions list can be invalidated wholesale in one
///      transaction, so it is not a trustworthy on-chain gate. A sanctioned account reverts on transfer
///      and the batch fails closed; the OMS screens pre-trade.
/// @dev See specs/liquidmesh-swap-hook/technical-spec.md ("Design decisions", "Attack surface analysis").
/// @dev Payload: abi.encode(address to, bytes txData)
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
contract ApproveAndSwapBinanceHook is
    BaseHook,
    ISuperHookSwap,
    ISuperHookContextAware,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
{
    /// @notice The Binance DEX router, pinned at deploy time; the API-supplied `to` must match it.
    /// @dev EIP-2535 diamond: pinning the address does not pin the code. Facet and inner-router changes
    ///      are monitored off-chain. See technical-spec.md "What pinning the router actually buys".
    address public immutable BINANCE_ROUTER;

    /// @notice Ceiling on the SUM of header `inputAmount`s this hook approves for one account within one
    ///         transaction, in raw token units.
    /// @dev Per-TRANSACTION, not per-execution: a Merkle leaf carries no amount, so one leaf can be repeated
    ///      N times in a batch. Token-agnostic on-chain; it only means something because `inspect()` commits
    ///      `inputToken` into the leaf. `outputMin` is caller-chosen and bounds nothing under a compromised key.
    uint256 public immutable MAX_INPUT_AMOUNT;

    /// @dev Transient-storage key prefix for the per-account, per-transaction spend accumulator.
    bytes32 private constant TX_SPENT_KEY = keccak256("ApproveAndSwapBinanceHook.txSpent");

    /// @dev Transient-storage key prefix for the per-account "snapshot taken" flag `_preExecute` sets and
    ///      `_postExecute` requires. Keyed by executionNonce too: BaseHook's context is private, but any
    ///      mid-batch `setExecutionContext` advances the nonce, so the flag reads unset and post fails closed.
    bytes32 private constant SNAPSHOT_KEY = keccak256("ApproveAndSwapBinanceHook.snapshot");

    /// @dev Conventional native-asset sentinel. Rejected on both sides; never a valid path here.
    address private constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @dev Minimum router calldata: a 4-byte selector. The diamond's fallback dispatches by selector and
    ///      reverts on unknown ones anyway; this rejects empty or garbage calldata cheaply at build time.
    uint256 private constant MIN_TX_DATA_LENGTH = 4;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when data is shorter than the standard swap layout or txData has no selector
    error INVALID_HOOK_DATA();
    /// @notice Thrown when the API-supplied `to` is not the pinned router
    error ROUTER_MISMATCH();
    /// @notice Thrown when outputMin is zero — slippage protection must not be opt-out
    error MIN_OUT_NOT_VALID();
    /// @notice Thrown when realised output is below outputMin
    error MIN_OUT_NOT_MET();
    /// @notice Thrown when usePrevHookAmount is set; unsupported (no Binance scaling helper)
    error USE_PREV_HOOK_NOT_SUPPORTED();
    /// @notice Thrown when inputToken == outputToken
    error SAME_INPUT_OUTPUT_TOKEN();
    /// @notice Thrown when either token is address(0) or the native sentinel; the hook is ERC20-only
    error NATIVE_ETH_NOT_SUPPORTED();
    /// @notice Thrown when inputAmount exceeds the per-deployment cap
    error INPUT_EXCEEDS_CAP();
    /// @notice Thrown when the output balance fell across the swap
    /// @dev Named error, not panic(0x11): the issuer's raw burn/seize powers can lower a balance mid-swap.
    error OUTPUT_BALANCE_DECREASED();
    /// @notice Thrown when residual allowance to the router is non-zero after execution
    error ALLOWANCE_NOT_CLEARED();
    /// @notice Thrown when postExecute runs without a balance snapshot taken by preExecute in the same context
    error SNAPSHOT_NOT_TAKEN();

    constructor(address router_, uint256 maxInputAmount_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        if (router_ == address(0)) revert ADDRESS_NOT_VALID();
        if (maxInputAmount_ == 0) revert AMOUNT_NOT_VALID();
        BINANCE_ROUTER = router_;
        MAX_INPUT_AMOUNT = maxInputAmount_;
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Approve and Swap Binance";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Approves and swaps tokens via the Binance Web3 Trading API DEX router";
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sum of header `inputAmount`s this hook has approved for `account` in the current transaction.
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
        // Length first, so every later fixed-offset read is in bounds.
        if (data.length < SwapCalldataLayout.MIN_DATA_LENGTH) revert INVALID_HOOK_DATA();

        // No scaler exists for the opaque blob, so a previous hook's output can never reach the router.
        if (_decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET)) {
            revert USE_PREV_HOOK_NOT_SUPPORTED();
        }

        address inputToken = BytesLib.toAddress(data, SwapCalldataLayout.INPUT_TOKEN_OFFSET);
        address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        if (!_isERC20(inputToken) || !_isERC20(outputToken)) revert NATIVE_ETH_NOT_SUPPORTED();
        if (inputToken == outputToken) revert SAME_INPUT_OUTPUT_TOKEN();

        uint256 inputAmount = BytesLib.toUint256(data, SwapCalldataLayout.INPUT_AMOUNT_OFFSET);
        if (inputAmount == 0) revert AMOUNT_NOT_VALID();
        // Bound loss-per-transaction. Equal to the cap is allowed.
        if (inputAmount > MAX_INPUT_AMOUNT) revert INPUT_EXCEEDS_CAP();

        // Reject opt-out of slippage protection at build time.
        if (BytesLib.toUint256(data, SwapCalldataLayout.OUTPUT_MIN_OFFSET) == 0) {
            revert MIN_OUT_NOT_VALID();
        }

        uint256 payloadLength = BytesLib.toUint256(data, SwapCalldataLayout.PAYLOAD_LENGTH_OFFSET);
        bytes memory payload = BytesLib.slice(data, SwapCalldataLayout.PAYLOAD_DATA_OFFSET, payloadLength);
        (address to, bytes memory txData) = abi.decode(payload, (address, bytes));

        // The API chooses `to`; accept only the pinned router.
        if (to != BINANCE_ROUTER) revert ROUTER_MISMATCH();
        if (txData.length < MIN_TX_DATA_LENGTH) revert INVALID_HOOK_DATA();

        // Scope the allowance to exactly this execution: `approve(inputAmount)` is the only input-side bound.
        // ERC20 only — every execution carries value: 0; the API's `value` is ignored.
        bytes memory clearApproval = abi.encodeCall(IERC20.approve, (BINANCE_ROUTER, 0));
        executions = new Execution[](4);
        executions[0] = Execution({ target: inputToken, value: 0, callData: clearApproval });
        executions[1] = Execution({
            target: inputToken, value: 0, callData: abi.encodeCall(IERC20.approve, (BINANCE_ROUTER, inputAmount))
        });
        executions[2] = Execution({ target: BINANCE_ROUTER, value: 0, callData: txData });
        executions[3] = Execution({ target: inputToken, value: 0, callData: clearApproval });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    /// @dev Sizeless: the header `inputAmount` is only the allowance bound; the spend lives in the opaque calldata.
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

    /// @dev This hook implements ISuperHookInflowOutflow + ISuperHookOutflow (as authoritatively sizeless)
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
    /// @dev Commits BOTH tokens, packed (40 bytes). Without `inputToken` a leaf would authorise calldata that
    ///      spends ANY token approved to this router; the router itself is an immutable, so the hook address
    ///      already pins it. Packed addresses are what the SuperBank root generator emits — see
    ///      technical-spec.md "Leaf encoding and SuperBank root tooling".
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        if (data.length < SwapCalldataLayout.MIN_DATA_LENGTH) revert INVALID_HOOK_DATA();
        return abi.encodePacked(
            BytesLib.toAddress(data, SwapCalldataLayout.INPUT_TOKEN_OFFSET),
            BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET)
        );
    }

    // ─── ISuperHookSwap ─────────────────────────────

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

    /// @inheritdoc BaseHook
    /// @dev No totalSupply/rebase guard: the bStock BEP-677 multiplier is display-only and `balanceOf` is raw,
    ///      so the balance delta is sound whatever happens to the multiplier mid-execution. See
    ///      technical-spec.md "Token risks".
    function _preExecute(address, address account, bytes calldata data) internal override {
        // Per-transaction cap on the running sum, checked before any approval is granted.
        uint256 spent = _getTxSpent(account) + BytesLib.toUint256(data, SwapCalldataLayout.INPUT_AMOUNT_OFFSET);
        if (spent > MAX_INPUT_AMOUNT) revert INPUT_EXCEEDS_CAP();
        _setTxSpent(account, spent);

        address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        _setOutAmount(IERC20(outputToken).balanceOf(account), account);
        _setSnapshotTaken(account, true);
    }

    /// @inheritdoc BaseHook
    /// @dev Validates the OUTCOME, not the opaque calldata (mutable diamond, no stable ABI).
    function _postExecute(address, address account, bytes calldata data) internal override {
        // Refuse to compare against a context that never took a snapshot (see SNAPSHOT_KEY).
        if (!_getSnapshotTaken(account)) revert SNAPSHOT_NOT_TAKEN();
        _setSnapshotTaken(account, false);

        address inputToken = BytesLib.toAddress(data, SwapCalldataLayout.INPUT_TOKEN_OFFSET);
        address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);

        uint256 balanceAfter = IERC20(outputToken).balanceOf(account);
        uint256 balanceBefore = getOutAmount(account);
        if (balanceAfter < balanceBefore) revert OUTPUT_BALANCE_DECREASED();
        uint256 received = balanceAfter - balanceBefore;

        // Slippage is enforced in-hook, unlike the sibling aggregator hooks. outputMin is caller-supplied and
        // not in the leaf, so this guards an honest manager's mistake; MAX_INPUT_AMOUNT bounds a compromised key.
        if (received < BytesLib.toUint256(data, SwapCalldataLayout.OUTPUT_MIN_OFFSET)) {
            revert MIN_OUT_NOT_MET();
        }

        // No standing allowance may survive: catches tokens whose approve(0) silently no-ops.
        if (IERC20(inputToken).allowance(account, BINANCE_ROUTER) != 0) revert ALLOWANCE_NOT_CLEARED();

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
