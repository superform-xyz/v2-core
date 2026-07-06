// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataUpdater } from "../../../libraries/HookDataUpdater.sol";
import { SwapCalldataLayout } from "../../../libraries/SwapCalldataLayout.sol";
import { ISuperHookSwap } from "../../../interfaces/ISuperHookSwap.sol";
import {
    ISuperHookResult,
    ISuperHookContextAware,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";
import { IAlgebraSwapRouter } from "../../../vendor/algebra-integral/IAlgebraSwapRouter.sol";

/// @title ApproveAndSwapAlgebraIntegralHook
/// @author Superform Labs
/// @notice Hook for executing swaps via Algebra Integral with approval handling
/// @dev Handles: approve(0) -> approve(amount) -> swap -> approve(0)
/// @dev Payload: abi.encode(address deployer, uint256 deadline, uint160 limitSqrtPrice)
/// @dev data has the following structure (3-layer calldata standard):
/// @notice         bytes32 placeholder0      = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1      = BytesLib.toAddress(data, 32);
/// @notice         address inputToken        = BytesLib.toAddress(data, 52);
/// @notice         address outputToken       = BytesLib.toAddress(data, 72);
/// @notice         uint256 inputAmount       = BytesLib.toUint256(data, 92);
/// @notice         uint256 outputQuote       = BytesLib.toUint256(data, 124);
/// @notice         uint256 outputMin         = BytesLib.toUint256(data, 156);
/// @notice         bool    usePrevHookAmount = _decodeBool(data, 188);
/// @notice         uint256 payload_paramLength = BytesLib.toUint256(data, 189);
/// @notice         bytes   payload           = BytesLib.slice(data, 221, payload_paramLength);
contract ApproveAndSwapAlgebraIntegralHook is
    BaseHook,
    ISuperHookSwap,
    ISuperHookContextAware,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
{
    using BytesLib for bytes;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The Algebra Integral SwapRouter contract
    IAlgebraSwapRouter public immutable SWAP_ROUTER;

    uint256 private constant AMOUNT_POSITION = SwapCalldataLayout.AMOUNT_POSITION;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when hook data is malformed or insufficient
    error INVALID_HOOK_DATA();

    /// @notice Thrown when native ETH is used (use WETH instead)
    error NATIVE_ETH_NOT_SUPPORTED();

    /// @notice Thrown when the deadline has passed
    /// @param deadline The provided deadline timestamp
    /// @param currentTimestamp The current block timestamp
    error EXPIRED_DEADLINE(uint256 deadline, uint256 currentTimestamp);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the Algebra Integral swap hook with approval handling
    /// @param swapRouter_ The address of the Algebra Integral SwapRouter
    constructor(address swapRouter_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        if (swapRouter_ == address(0)) revert ADDRESS_NOT_VALID();
        SWAP_ROUTER = IAlgebraSwapRouter(swapRouter_);
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Approve and Swap Algebra Integral";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Approves and swaps tokens via Algebra Integral DEX";
    }

    /*//////////////////////////////////////////////////////////////
                            HOOK IMPLEMENTATION
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
        address tokenIn = data.toAddress(SwapCalldataLayout.INPUT_TOKEN_OFFSET);
        address tokenOut = data.toAddress(SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);

        if (tokenIn == address(0) || tokenOut == address(0)) revert NATIVE_ETH_NOT_SUPPORTED();
        if (tokenIn == tokenOut) revert INVALID_HOOK_DATA();

        address deployer;
        uint256 deadline;
        uint160 limitSqrtPrice;
        {
            uint256 payloadLen = BytesLib.toUint256(data, SwapCalldataLayout.PAYLOAD_LENGTH_OFFSET);
            bytes memory payload = BytesLib.slice(data, SwapCalldataLayout.PAYLOAD_DATA_OFFSET, payloadLen);
            (deployer, deadline, limitSqrtPrice) = abi.decode(payload, (address, uint256, uint160));
        }

        if (deadline < block.timestamp) revert EXPIRED_DEADLINE(deadline, block.timestamp);

        uint256 amountIn = data.toUint256(SwapCalldataLayout.INPUT_AMOUNT_OFFSET);
        uint256 amountOutMinimum = data.toUint256(SwapCalldataLayout.OUTPUT_MIN_OFFSET);

        if (_decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET)) {
            uint256 prevAmountIn = ISuperHookResult(prevHook).getOutAmount(account);
            amountOutMinimum = HookDataUpdater.getUpdatedOutputAmount(prevAmountIn, amountIn, amountOutMinimum);
            amountIn = prevAmountIn;
        }

        if (amountIn == 0) revert AMOUNT_NOT_VALID();

        // Build: approve(0) -> approve(amount) -> swap -> approve(0)
        executions = new Execution[](4);

        executions[0] = Execution({
            target: tokenIn,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(SWAP_ROUTER), 0))
        });

        executions[1] = Execution({
            target: tokenIn,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(SWAP_ROUTER), amountIn))
        });

        executions[2] = Execution({
            target: address(SWAP_ROUTER),
            value: 0,
            callData: abi.encodeCall(
                IAlgebraSwapRouter.exactInputSingle,
                (
                    IAlgebraSwapRouter.ExactInputSingleParams({
                        tokenIn: tokenIn,
                        tokenOut: tokenOut,
                        deployer: deployer,
                        recipient: account,
                        deadline: deadline,
                        amountIn: amountIn,
                        amountOutMinimum: amountOutMinimum,
                        limitSqrtPrice: limitSqrtPrice
                    })
                )
            )
        });

        executions[3] = Execution({
            target: tokenIn,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(SWAP_ROUTER), 0))
        });
    }

    /// @inheritdoc BaseHook
    function _preExecute(address, address account, bytes calldata data) internal override {
        address tokenOut = data.toAddress(SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        _setOutAmount(IERC20(tokenOut).balanceOf(account), account);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        address tokenOut = data.toAddress(SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        uint256 finalBalance = IERC20(tokenOut).balanceOf(account);
        uint256 initialBalance = getOutAmount(account);
        if (finalBalance < initialBalance) revert AMOUNT_NOT_VALID();
        _setOutAmount(finalBalance - initialBalance, account);
        _setOutToken(tokenOut, account);
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
    function amountRoles(bytes memory)
        external
        pure
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        meta = new ISuperHookInflowOutflow.AmountMeta[](1);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(
            ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN
        );
    }

    /// @dev This hook implements ISuperHookInflowOutflow + ISuperHookOutflow
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

    /// @inheritdoc BaseHook
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        address tokenOut = data.toAddress(SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        return abi.encodePacked(tokenOut);
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
}
