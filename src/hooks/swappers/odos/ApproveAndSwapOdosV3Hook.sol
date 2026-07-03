// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IOdosRouterV3 } from "../../../vendor/odos/IOdosRouterV3.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataUpdater } from "../../../libraries/HookDataUpdater.sol";
import { SwapCalldataLayout } from "../../../libraries/SwapCalldataLayout.sol";
import { ISuperHookSwap } from "../../../interfaces/ISuperHookSwap.sol";
import {
    ISuperHookResult,
    ISuperHookContextAware,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";

/// @title ApproveAndSwapOdosV3Hook
/// @author Superform Labs
/// @dev Payload: abi.encode(address inputReceiver, bytes pathDefinition, address executor, uint64 referralCode, uint64 referralFee, address feeRecipient)
/// @dev data has the following structure (standard 52-byte strategy header + Layer 1 + Layer 2):
/// @notice         uint256   placeholder0     = BytesLib.toUint256(data, 0);
/// @notice         address   placeholder1     = BytesLib.toAddress(data, 32);
/// @notice         address   inputToken       = BytesLib.toAddress(data, 52);
/// @notice         address   outputToken      = BytesLib.toAddress(data, 72);
/// @notice         uint256   inputAmount      = BytesLib.toUint256(data, 92);
/// @notice         uint256   outputQuote      = BytesLib.toUint256(data, 124);
/// @notice         uint256   outputMin        = BytesLib.toUint256(data, 156);
/// @notice         bool      usePrevHookAmount = _decodeBool(data, 188);
/// @notice         uint256   payload_paramLength = BytesLib.toUint256(data, 189);
/// @notice         bytes     payload          = BytesLib.slice(data, 221, payload_paramLength);
/// @dev The executor address is passed directly to the Odos Router V3, which delegate-calls into it
///      for swap execution. The executor must be trusted -- off-chain validation via inspect() is recommended.
/// @dev Unlike V2, this hook supports native ETH swaps by skipping token approvals
///      when inputToken is address(0).
contract ApproveAndSwapOdosV3Hook is
    BaseHook,
    ISuperHookSwap,
    ISuperHookContextAware,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
{
    IOdosRouterV3 public immutable ODOS_ROUTER_V3;

    /*//////////////////////////////////////////////////////////////
                        DATA LAYOUT POSITIONS
    //////////////////////////////////////////////////////////////*/
    uint256 private constant AMOUNT_POSITION = SwapCalldataLayout.AMOUNT_POSITION;

    // Layer 2 (payload) absolute positions
    uint256 private constant INPUT_RECEIVER_POSITION = SwapCalldataLayout.PAYLOAD_DATA_OFFSET; // 221
    uint256 private constant PATH_DEF_LENGTH_POSITION = SwapCalldataLayout.PAYLOAD_DATA_OFFSET + 20; // 241
    uint256 private constant PATH_DEF_DATA_POSITION = SwapCalldataLayout.PAYLOAD_DATA_OFFSET + 52; // 273

    /// @dev Tail field offsets relative to (PATH_DEF_DATA_POSITION + pathDefinitionLength)
    uint256 private constant EXECUTOR_TAIL_OFFSET = 0;
    uint256 private constant REFERRAL_CODE_TAIL_OFFSET = 20;
    uint256 private constant REFERRAL_FEE_TAIL_OFFSET = 28;
    uint256 private constant FEE_RECIPIENT_TAIL_OFFSET = 36;

    /// @notice Denominator for referral fee calculations (uint64 to match IOdosRouterV3.swapReferralInfo.fee)
    uint64 public constant FEE_DENOM = 1e18;

    /// @notice Maximum allowed referral fee (2% of the swap amount)
    uint64 public constant MAX_REFERRAL_FEE = FEE_DENOM / 50;

    /// @notice Thrown when the referral fee exceeds the maximum allowed percentage
    error REFERRAL_FEE_TOO_HIGH();

    /// @notice Thrown when inputToken and outputToken are the same address
    error SAME_INPUT_OUTPUT_TOKEN();

    /// @notice Decoded parameters for Odos V3 approve-and-swap execution
    struct HookParams {
        address inputToken;
        uint256 inputAmount;
        address approveSpender;
        bytes pathDefinition;
        address executor;
        uint64 referralCode;
        uint64 referralFee;
        address feeRecipient;
    }

    constructor(address _routerV3) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        if (_routerV3 == address(0)) revert ADDRESS_NOT_VALID();
        ODOS_ROUTER_V3 = IOdosRouterV3(_routerV3);
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Approve and Swap Odos V3";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Approves and swaps tokens via Odos V3 aggregator";
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
        HookParams memory params;

        params.inputToken = BytesLib.toAddress(data, SwapCalldataLayout.INPUT_TOKEN_OFFSET);
        address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        if (params.inputToken == outputToken) revert SAME_INPUT_OUTPUT_TOKEN();

        uint256 pathDefinitionLength = BytesLib.toUint256(data, PATH_DEF_LENGTH_POSITION);
        params.pathDefinition = BytesLib.slice(data, PATH_DEF_DATA_POSITION, pathDefinitionLength);

        uint256 tailOffset = PATH_DEF_DATA_POSITION + pathDefinitionLength;
        params.executor = BytesLib.toAddress(data, tailOffset + EXECUTOR_TAIL_OFFSET);
        params.referralCode = BytesLib.toUint64(data, tailOffset + REFERRAL_CODE_TAIL_OFFSET);
        params.referralFee = BytesLib.toUint64(data, tailOffset + REFERRAL_FEE_TAIL_OFFSET);
        params.feeRecipient = BytesLib.toAddress(data, tailOffset + FEE_RECIPIENT_TAIL_OFFSET);

        if (params.referralFee > MAX_REFERRAL_FEE) revert REFERRAL_FEE_TOO_HIGH();
        if (params.referralFee > 0 && params.feeRecipient == address(0)) revert ADDRESS_NOT_VALID();

        params.inputAmount = BytesLib.toUint256(data, SwapCalldataLayout.INPUT_AMOUNT_OFFSET);

        bool usePrevHookAmount = _decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET);
        if (usePrevHookAmount) {
            params.inputAmount = ISuperHookResult(prevHook).getOutAmount(account);
        }

        params.approveSpender = address(ODOS_ROUTER_V3);

        IOdosRouterV3.swapReferralInfo memory referralInfo =
            IOdosRouterV3.swapReferralInfo(params.referralCode, params.referralFee, params.feeRecipient);

        bytes memory swapCallData = abi.encodeCall(
            IOdosRouterV3.swap,
            (_getSwapInfo(account, prevHook, data), params.pathDefinition, params.executor, referralInfo)
        );

        if (params.inputToken == address(0)) {
            // Native ETH: skip all approvals, 1 execution only
            executions = new Execution[](1);
            executions[0] = Execution({ target: address(ODOS_ROUTER_V3), value: params.inputAmount, callData: swapCallData });
        } else {
            // ERC-20: approve(0) -> approve(amount) -> swap -> approve(0)
            executions = new Execution[](4);
            executions[0] = Execution({
                target: params.inputToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (params.approveSpender, 0))
            });

            executions[1] = Execution({
                target: params.inputToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (params.approveSpender, params.inputAmount))
            });

            executions[2] = Execution({ target: address(ODOS_ROUTER_V3), value: 0, callData: swapCallData });

            executions[3] = Execution({
                target: params.inputToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (params.approveSpender, 0))
            });
        }
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

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        address inputReceiver = BytesLib.toAddress(data, INPUT_RECEIVER_POSITION);
        uint256 pathDefinitionLength = BytesLib.toUint256(data, PATH_DEF_LENGTH_POSITION);
        uint256 tailOffset = PATH_DEF_DATA_POSITION + pathDefinitionLength;
        address executor = BytesLib.toAddress(data, tailOffset + EXECUTOR_TAIL_OFFSET);
        address feeRecipient = BytesLib.toAddress(data, tailOffset + FEE_RECIPIENT_TAIL_OFFSET);
        return abi.encodePacked(inputReceiver, executor, feeRecipient);
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

    /// @dev Returns the balance of the output token for the given account
    function _getBalance(address account, bytes memory data) private view returns (uint256) {
        address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);

        if (outputToken == address(0)) {
            return account.balance;
        }

        return IERC20(outputToken).balanceOf(account);
    }

    /// @dev Builds the swapTokenInfo struct, scaling amounts when usePrevHookAmount is true
    function _getSwapInfo(
        address account,
        address prevHook,
        bytes memory data
    )
        private
        view
        returns (IOdosRouterV3.swapTokenInfo memory)
    {
        address inputToken = BytesLib.toAddress(data, SwapCalldataLayout.INPUT_TOKEN_OFFSET);
        uint256 inputAmount = BytesLib.toUint256(data, SwapCalldataLayout.INPUT_AMOUNT_OFFSET);
        address inputReceiver = BytesLib.toAddress(data, INPUT_RECEIVER_POSITION);
        address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        uint256 outputQuote = BytesLib.toUint256(data, SwapCalldataLayout.OUTPUT_QUOTE_OFFSET);
        uint256 outputAmount = BytesLib.toUint256(data, SwapCalldataLayout.OUTPUT_MIN_OFFSET);
        bool usePrevHookAmount = _decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET);

        if (usePrevHookAmount) {
            uint256 _prevAmount = inputAmount;
            inputAmount = ISuperHookResult(prevHook).getOutAmount(account);
            outputAmount = HookDataUpdater.getUpdatedOutputAmount(inputAmount, _prevAmount, outputAmount);
            outputQuote = HookDataUpdater.getUpdatedOutputAmount(inputAmount, _prevAmount, outputQuote);
        }

        return IOdosRouterV3.swapTokenInfo(
            inputToken, inputAmount, inputReceiver, outputToken, outputQuote, outputAmount, account
        );
    }
}
