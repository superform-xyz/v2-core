// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookContextAware,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {
    IPendleRouterV4,
    ApproxParams,
    TokenInput,
    LimitOrderData,
    TokenOutput,
    FillOrderParams,
    Order,
    SwapData,
    SwapType
} from "../../../vendor/pendle/IPendleRouterV4.sol";
import { IPendleMarket } from "../../../vendor/pendle/IPendleMarket.sol";
import { IStandardizedYield } from "../../../vendor/pendle/IStandardizedYield.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { HookDataUpdater } from "../../../libraries/HookDataUpdater.sol";
import { SwapCalldataLayout } from "../../../libraries/SwapCalldataLayout.sol";
import { ISuperHookSwap } from "../../../interfaces/ISuperHookSwap.sol";

/// @title PendleUnifiedHook
/// @author Superform Labs
/// @notice Unified hook supporting all Pendle router operations: swaps (pre-maturity) and redemptions (post-maturity)
/// @dev Merges PendleRouterSwapHook and PendleRouterRedeemHook with fix for tokenRedeemSy validation
/// @dev Payload: abi.encode(bytes4 selector, bytes routingParams)
/// @dev data has the following structure (standard 52-byte strategy header + Layer 1 + Layer 2):
/// @notice         bytes32   placeholder0     = BytesLib.toBytes32(data, 0);
/// @notice         address   placeholder1     = BytesLib.toAddress(data, 32);
/// @notice         address   inputToken       = BytesLib.toAddress(data, 52);
/// @notice         address   outputToken      = BytesLib.toAddress(data, 72);
/// @notice         uint256   inputAmount      = BytesLib.toUint256(data, 92);
/// @notice         uint256   outputQuote      = BytesLib.toUint256(data, 124);
/// @notice         uint256   outputMin        = BytesLib.toUint256(data, 156);
/// @notice         bool      usePrevHookAmount = _decodeBool(data, 188);
/// @notice         uint256   payload_paramLength = BytesLib.toUint256(data, 189);
/// @notice         bytes     payload          = BytesLib.slice(data, 221, payload_paramLength);
/// @dev Trust assumptions:
/// @dev   - The yieldSource (Pendle market) address is provided by the signed intent and trusted by the signer.
/// @dev     The hook validates structural correctness (market matches txData, receiver matches account) but does NOT
/// @dev     whitelist markets. A malicious market could return attacker-controlled token addresses from readTokens().
/// @dev     The trust model relies on the intent signer only submitting known-good Pendle market addresses.
/// @dev   - SwapData.extRouter and SwapData.extCalldata in TokenInput/TokenOutput are user-supplied via the signed
/// @dev     intent payload. The Pendle Router V4 forwards calls to extRouter with extCalldata. The hook validates
/// @dev     structural correctness (non-zero extRouter, non-zero pendleSwap when swap is needed) but does NOT
/// @dev     whitelist routers or inspect calldata contents. The trust model relies on: (1) the intent signer
/// @dev     validating these fields before signing, and (2) the Pendle Router V4's own protections during execution.
/// @dev   - TokenInput.pendleSwap and TokenOutput.pendleSwap are intermediary swap aggregator addresses used by
/// @dev     the Pendle Router internally. They are validated for non-zero when swapType != NONE but not whitelisted.
contract PendleUnifiedHook is BaseHook, ISuperHookSwap, ISuperHookContextAware, ISuperHookInflowOutflow, ISuperHookOutflow {

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/
    /// @dev Maximum number of fill orders allowed per array to prevent gas griefing
    uint256 private constant MAX_FILLS = 64;

    /// @dev Maximum epsilon for Pendle's binary search approximation (100% in 1e18 scale)
    uint256 private constant MAX_EPS = 1e18;

    /// @dev Maximum iterations for Pendle's binary search approximation
    uint256 private constant MAX_ITERATIONS = 256;

    /// @dev Native token sentinel address
    address private constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @dev Maximum length of LimitOrderData.optData to prevent gas griefing via memory expansion
    uint256 private constant MAX_OPT_DATA_LENGTH = 1024;

    /*//////////////////////////////////////////////////////////////
                        DATA LAYOUT POSITIONS
    //////////////////////////////////////////////////////////////*/
    uint256 private constant AMOUNT_POSITION = SwapCalldataLayout.AMOUNT_POSITION;

    /*//////////////////////////////////////////////////////////////
                                 IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    IPendleRouterV4 public immutable PENDLE_ROUTER_V4;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when a limit order has expired (expiry < block.timestamp)
    error ORDER_EXPIRED();
    /// @notice Thrown when ApproxParams epsilon exceeds MAX_EPS (1e18)
    error EPS_NOT_VALID();
    /// @notice Thrown when the SY address from the market is the zero address
    error SY_NOT_VALID();
    /// @notice Thrown when the function selector is not a supported Pendle router operation
    error SELECTOR_NOT_VALID();
    /// @notice Thrown when the minimum output amount is zero
    error MIN_OUT_NOT_VALID();
    /// @notice Thrown when the input amount is zero
    error AMOUNT_IN_NOT_VALID();
    /// @notice Thrown when guessMin exceeds guessMax in ApproxParams
    error GUESS_PT_OUT_NOT_VALID();
    /// @notice Thrown when the external router address is zero or the native token sentinel
    error EXT_ROUTER_NOT_VALID();
    /// @notice Thrown when the making amount of a fill order is zero
    error MAKING_AMOUNT_NOT_VALID();
    /// @notice Thrown when tokenOut is not a valid output token in the SY contract
    error TOKEN_OUT_NOT_LISTED();
    /// @notice Thrown when tokenRedeemSy is not a valid output token in the SY contract
    error TOKEN_REDEEM_SY_NOT_VALID();
    /// @notice Thrown when the number of fill orders exceeds MAX_FILLS (64)
    error TOO_MANY_FILLS();
    /// @notice Thrown when ApproxParams maxIteration exceeds MAX_ITERATIONS (256)
    error MAX_ITERATION_NOT_VALID();
    /// @notice Thrown when the header outputToken does not match the txData-derived output token
    error OUTPUT_TOKEN_MISMATCH();
    /// @notice Thrown when the pendleSwap address is zero while swapType requires it
    error PENDLE_SWAP_NOT_VALID();
    /// @notice Thrown when LimitOrderData.optData exceeds MAX_OPT_DATA_LENGTH
    error OPT_DATA_TOO_LONG();

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @notice Initializes the PendleUnifiedHook with the Pendle Router V4 address
    /// @param pendleRouterV4_ The address of the Pendle Router V4 contract
    constructor(address pendleRouterV4_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.PTYT) {
        if (pendleRouterV4_ == address(0)) revert ADDRESS_NOT_VALID();
        PENDLE_ROUTER_V4 = IPendleRouterV4(pendleRouterV4_);
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Pendle Unified";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Executes unified Pendle operations (swap or redeem)";
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address prevHook,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        bool usePrevHookAmount = _decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET);
        uint256 inputAmount = BytesLib.toUint256(data, SwapCalldataLayout.INPUT_AMOUNT_OFFSET);
        uint256 outputMin = BytesLib.toUint256(data, SwapCalldataLayout.OUTPUT_MIN_OFFSET);

        address yieldSource = HookDataDecoder.extractYieldSource(data);
        (bytes4 selector, bytes memory routingParams) =
            abi.decode(data[SwapCalldataLayout.PAYLOAD_DATA_OFFSET:], (bytes4, bytes));

        if (
            selector != IPendleRouterV4.redeemPyToToken.selector
                && selector != IPendleRouterV4.swapExactTokenForPt.selector
                && selector != IPendleRouterV4.swapExactPtForToken.selector
        ) {
            revert SELECTOR_NOT_VALID();
        }

        if (outputMin == 0) revert MIN_OUT_NOT_VALID();

        // Pre-compute amounts to reduce stack depth in builders.
        // NOTE: HookDataUpdater uses 1e5 precision for percentage scaling. For extreme ratios between
        // netTokenIn and inputAmount, or for tokens with very low decimal precision, the scaledOutputMin
        // may suffer precision loss. The zero check below catches the degenerate case.
        uint256 netTokenIn;
        uint256 scaledOutputMin;
        if (usePrevHookAmount) {
            netTokenIn = ISuperHookResult(prevHook).getOutAmount(account);
            scaledOutputMin = HookDataUpdater.getUpdatedOutputAmount(netTokenIn, inputAmount, outputMin);
            if (scaledOutputMin == 0) revert MIN_OUT_NOT_VALID();
        } else {
            netTokenIn = inputAmount;
            scaledOutputMin = outputMin;
        }
        if (netTokenIn == 0) revert AMOUNT_IN_NOT_VALID();

        address headerInputToken = BytesLib.toAddress(data, SwapCalldataLayout.INPUT_TOKEN_OFFSET);
        address headerOutputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);

        address derivedTokenOut;
        if (selector == IPendleRouterV4.redeemPyToToken.selector) {
            (executions, derivedTokenOut) =
                _buildRedeemExecutions(account, yieldSource, headerOutputToken, netTokenIn, scaledOutputMin, routingParams);
        } else if (selector == IPendleRouterV4.swapExactTokenForPt.selector) {
            (executions, derivedTokenOut) = _buildSwapTokenForPtExecutions(
                account, yieldSource, headerInputToken, netTokenIn, scaledOutputMin, routingParams
            );
        } else {
            (executions, derivedTokenOut) =
                _buildSwapPtForTokenExecutions(account, yieldSource, headerOutputToken, netTokenIn, scaledOutputMin, routingParams);
        }

        // Validate header outputToken matches derived output (meaningful for swapExactTokenForPt where
        // tokenOut = PT from market; tautological but harmless for the other two paths)
        if (headerOutputToken != derivedTokenOut) revert OUTPUT_TOKEN_MISMATCH();
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        amounts[0] = BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory) external pure override returns (ISuperHookInflowOutflow.AmountMeta[] memory meta) {
        meta = new ISuperHookInflowOutflow.AmountMeta[](1);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
    }

    /// @inheritdoc BaseHook
    function _supportsSizingInterface() internal pure override returns (bool) {
        return true;
    }

    /// @inheritdoc ISuperHookOutflow
    function replaceCalldataAmounts(
        bytes memory data,
        uint256[] memory amounts
    )
        external
        pure
        override
        returns (bytes memory)
    {
        if (amounts.length != 1) revert INVALID_AMOUNTS_LENGTH();
        return _replaceCalldataAmount(data, amounts[0], AMOUNT_POSITION);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        if (interfaceId == type(ISuperHookInflowOutflow).interfaceId) return true;
        if (interfaceId == type(ISuperHookOutflow).interfaceId) return true;
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(ISuperHook).interfaceId
            || interfaceId == type(ISuperHookResult).interfaceId
            || interfaceId == type(ISuperHookInspector).interfaceId;
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        return abi.encodePacked(outputToken);
    }

    // ─── ISuperHookSwap ──────────────────────────────────────────────────────

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
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data), account);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data) - getOutAmount(account), account);
        _setOutToken(BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET), account);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds executions for redeemPyToToken (PT+YT redemption)
    /// @dev routingParams: abi.encode(address tokenRedeemSy, address pendleSwap, SwapData swapData)
    /// @param account The account executing the redemption
    /// @param yieldSource The Pendle market address
    /// @param headerOutputToken The output token from the header (used as TokenOutput.tokenOut)
    /// @param netTokenIn The amount of PT+YT to redeem
    /// @param scaledOutputMin The minimum acceptable output token amount
    /// @param routingParams ABI-encoded Pendle-specific routing parameters
    /// @return executions Array of executions (approve + redeem + cleanup)
    /// @return tokenOut The output token address (= headerOutputToken)
    function _buildRedeemExecutions(
        address account,
        address yieldSource,
        address headerOutputToken,
        uint256 netTokenIn,
        uint256 scaledOutputMin,
        bytes memory routingParams
    )
        private
        view
        returns (Execution[] memory executions, address tokenOut)
    {
        address pt;
        address yt;
        TokenOutput memory output;

        // Scoping block to free tokenRedeemSy, pendleSwap, swapData, sy from the stack
        {
            (address tokenRedeemSy, address pendleSwap, SwapData memory swapData) =
                abi.decode(routingParams, (address, address, SwapData));

            address sy;
            (sy, pt, yt) = IPendleMarket(yieldSource).readTokens();
            if (sy == address(0)) revert SY_NOT_VALID();

            output = TokenOutput({
                tokenOut: headerOutputToken,
                minTokenOut: scaledOutputMin,
                tokenRedeemSy: tokenRedeemSy,
                pendleSwap: pendleSwap,
                swapData: swapData
            });

            tokenOut = headerOutputToken;

            if (output.swapData.swapType != SwapType.NONE) {
                if (!IStandardizedYield(sy).isValidTokenOut(output.tokenRedeemSy)) {
                    revert TOKEN_REDEEM_SY_NOT_VALID();
                }
                if (output.pendleSwap == address(0)) revert PENDLE_SWAP_NOT_VALID();
                if (output.swapData.swapType != SwapType.ETH_WETH) {
                    if (output.swapData.extRouter == address(0) || output.swapData.extRouter == NATIVE_TOKEN) {
                        revert EXT_ROUTER_NOT_VALID();
                    }
                }
            } else {
                if (!IStandardizedYield(sy).isValidTokenOut(output.tokenOut)) {
                    revert TOKEN_OUT_NOT_LISTED();
                }
            }
        }

        executions = new Execution[](7);
        executions[0] = Execution({
            target: pt,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), 0))
        });
        executions[1] = Execution({
            target: pt,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), netTokenIn))
        });
        executions[2] = Execution({
            target: yt,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), 0))
        });
        executions[3] = Execution({
            target: yt,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), netTokenIn))
        });
        executions[4] = Execution({
            target: address(PENDLE_ROUTER_V4),
            value: 0,
            callData: abi.encodeCall(IPendleRouterV4.redeemPyToToken, (account, yt, netTokenIn, output))
        });
        executions[5] = Execution({
            target: pt,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), 0))
        });
        executions[6] = Execution({
            target: yt,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), 0))
        });
    }

    /// @dev Builds executions for swapExactTokenForPt (token -> PT)
    /// @dev routingParams: abi.encode(address tokenMintSy, address pendleSwap, SwapData swapData, ApproxParams guessPtOut, LimitOrderData limit)
    /// @param account The account executing the swap
    /// @param yieldSource The Pendle market address (used as the market parameter in the router call)
    /// @param headerInputToken The input token from the header (used as TokenInput.tokenIn)
    /// @param netTokenIn The net token input amount (may be sourced from previous hook)
    /// @param scaledOutputMin The minimum acceptable PT output, scaled if using previous hook amount
    /// @param routingParams ABI-encoded Pendle-specific routing parameters
    /// @return executions Array of executions to send to the Pendle Router
    /// @return tokenOut The output token address (PT) derived from the market
    function _buildSwapTokenForPtExecutions(
        address account,
        address yieldSource,
        address headerInputToken,
        uint256 netTokenIn,
        uint256 scaledOutputMin,
        bytes memory routingParams
    )
        private
        view
        returns (Execution[] memory executions, address tokenOut)
    {
        TokenInput memory input;
        ApproxParams memory guessPtOut;
        LimitOrderData memory limit;

        // Scoping block to free tokenMintSy, pendleSwap, swapData from the stack
        {
            (
                address tokenMintSy,
                address pendleSwap,
                SwapData memory swapData,
                ApproxParams memory guessPtOut_,
                LimitOrderData memory limit_
            ) = abi.decode(routingParams, (address, address, SwapData, ApproxParams, LimitOrderData));

            guessPtOut = guessPtOut_;
            limit = limit_;

            if (guessPtOut.guessMin > guessPtOut.guessMax) revert GUESS_PT_OUT_NOT_VALID();
            if (guessPtOut.eps > MAX_EPS) revert EPS_NOT_VALID();
            if (guessPtOut.maxIteration > MAX_ITERATIONS) revert MAX_ITERATION_NOT_VALID();

            input = TokenInput({
                tokenIn: headerInputToken,
                netTokenIn: netTokenIn,
                tokenMintSy: tokenMintSy,
                pendleSwap: pendleSwap,
                swapData: swapData
            });

            // Validate TokenInput swap data
            if (input.swapData.swapType != SwapType.NONE) {
                if (input.pendleSwap == address(0)) revert PENDLE_SWAP_NOT_VALID();
                if (input.swapData.swapType != SwapType.ETH_WETH) {
                    if (input.swapData.extRouter == address(0) || input.swapData.extRouter == NATIVE_TOKEN) {
                        revert EXT_ROUTER_NOT_VALID();
                    }
                }
            }

            _validateLimitOrders(limit);
        }

        // Get PT address for output token
        {
            (, address pt_,) = IPendleMarket(yieldSource).readTokens();
            tokenOut = pt_;
        }

        if (headerInputToken != address(0)) {
            // ERC20 input: approve-reset-approve + call + cleanup
            executions = new Execution[](4);
            executions[0] = Execution({
                target: headerInputToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), 0))
            });
            executions[1] = Execution({
                target: headerInputToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), netTokenIn))
            });
            executions[2] = Execution({
                target: address(PENDLE_ROUTER_V4),
                value: 0,
                callData: abi.encodeCall(
                    IPendleRouterV4.swapExactTokenForPt,
                    (account, yieldSource, scaledOutputMin, guessPtOut, input, limit)
                )
            });
            executions[3] = Execution({
                target: headerInputToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), 0))
            });
        } else {
            // Native ETH input: single call with value = netTokenIn
            executions = new Execution[](1);
            executions[0] = Execution({
                target: address(PENDLE_ROUTER_V4),
                value: netTokenIn,
                callData: abi.encodeCall(
                    IPendleRouterV4.swapExactTokenForPt,
                    (account, yieldSource, scaledOutputMin, guessPtOut, input, limit)
                )
            });
        }
    }

    /// @dev Builds executions for swapExactPtForToken (PT -> token)
    /// @dev routingParams: abi.encode(address tokenRedeemSy, address pendleSwap, SwapData swapData, LimitOrderData limit)
    /// @param account The account executing the swap
    /// @param yieldSource The Pendle market address (used as the market parameter in the router call)
    /// @param headerOutputToken The output token from the header (used as TokenOutput.tokenOut)
    /// @param netTokenIn The exact PT input amount
    /// @param scaledOutputMin The minimum acceptable token output, scaled if using previous hook amount
    /// @param routingParams ABI-encoded Pendle-specific routing parameters
    /// @return executions Array of executions (approve + swap + cleanup)
    /// @return tokenOut The output token address (= headerOutputToken)
    function _buildSwapPtForTokenExecutions(
        address account,
        address yieldSource,
        address headerOutputToken,
        uint256 netTokenIn,
        uint256 scaledOutputMin,
        bytes memory routingParams
    )
        private
        view
        returns (Execution[] memory executions, address tokenOut)
    {
        address pt;
        TokenOutput memory output;
        LimitOrderData memory limit;

        // Scoping block to free tokenRedeemSy, pendleSwap, swapData, sy from the stack
        {
            (
                address tokenRedeemSy,
                address pendleSwap,
                SwapData memory swapData,
                LimitOrderData memory limit_
            ) = abi.decode(routingParams, (address, address, SwapData, LimitOrderData));

            limit = limit_;

            output = TokenOutput({
                tokenOut: headerOutputToken,
                minTokenOut: scaledOutputMin,
                tokenRedeemSy: tokenRedeemSy,
                pendleSwap: pendleSwap,
                swapData: swapData
            });

            tokenOut = headerOutputToken;

            // Validate token output against SY (consistent with redeem path)
            address sy;
            (sy, pt,) = IPendleMarket(yieldSource).readTokens();
            if (sy == address(0)) revert SY_NOT_VALID();

            if (output.swapData.swapType != SwapType.NONE) {
                if (!IStandardizedYield(sy).isValidTokenOut(output.tokenRedeemSy)) {
                    revert TOKEN_REDEEM_SY_NOT_VALID();
                }
                if (output.pendleSwap == address(0)) revert PENDLE_SWAP_NOT_VALID();
                if (output.swapData.swapType != SwapType.ETH_WETH) {
                    if (output.swapData.extRouter == address(0) || output.swapData.extRouter == NATIVE_TOKEN) {
                        revert EXT_ROUTER_NOT_VALID();
                    }
                }
            } else {
                if (!IStandardizedYield(sy).isValidTokenOut(output.tokenOut)) {
                    revert TOKEN_OUT_NOT_LISTED();
                }
            }

            _validateLimitOrders(limit);
        }

        // Approve-reset-approve + swap + cleanup for PT
        executions = new Execution[](4);
        executions[0] = Execution({
            target: pt,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), 0))
        });
        executions[1] = Execution({
            target: pt,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), netTokenIn))
        });
        executions[2] = Execution({
            target: address(PENDLE_ROUTER_V4),
            value: 0,
            callData: abi.encodeCall(
                IPendleRouterV4.swapExactPtForToken,
                (account, yieldSource, netTokenIn, output, limit)
            )
        });
        executions[3] = Execution({
            target: pt,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), 0))
        });
    }

    /// @dev Validates limit order parameters
    function _validateLimitOrders(LimitOrderData memory limit) private view {
        if (limit.optData.length > MAX_OPT_DATA_LENGTH) revert OPT_DATA_TOO_LONG();
        if (limit.normalFills.length > 0) {
            if (limit.limitRouter == address(0)) revert ADDRESS_NOT_VALID();
            _validateFillOrders(limit.normalFills);
        }
        if (limit.flashFills.length > 0) {
            if (limit.limitRouter == address(0)) revert ADDRESS_NOT_VALID();
            _validateFillOrders(limit.flashFills);
        }
    }

    /// @dev Validates fill order parameters
    function _validateFillOrders(FillOrderParams[] memory fills) private view {
        if (fills.length > MAX_FILLS) revert TOO_MANY_FILLS();
        for (uint256 i; i < fills.length; ++i) {
            if (fills[i].makingAmount == 0) revert MAKING_AMOUNT_NOT_VALID();
            _validateOrder(fills[i].order);
        }
    }

    /// @dev Validates individual order parameters
    /// @dev Note: order.nonce replay protection is enforced by the Pendle Router's on-chain nonce manager,
    ///      not at the hook layer. This validation covers structural correctness only.
    function _validateOrder(Order memory order) private view {
        if (order.expiry < block.timestamp) revert ORDER_EXPIRED();
        if (order.maker == address(0) || order.receiver == address(0)) revert ADDRESS_NOT_VALID();
    }

    /// @dev Gets balance of output token for the account
    function _getBalance(address account, bytes calldata data) private view returns (uint256) {
        address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);

        if (outputToken == address(0) || outputToken == NATIVE_TOKEN) {
            return account.balance;
        }

        return IERC20(outputToken).balanceOf(account);
    }
}
