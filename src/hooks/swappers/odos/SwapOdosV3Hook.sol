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
import {
    ISuperHookResult,
    ISuperHookContextAware,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";

/// @title SwapOdosV3Hook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address inputToken = BytesLib.toAddress(data, 0);
/// @notice         uint256 inputAmount = BytesLib.toUint256(data, 20);
/// @notice         address inputReceiver = BytesLib.toAddress(data, 52);
/// @notice         address outputToken = BytesLib.toAddress(data, 72);
/// @notice         uint256 outputQuote = BytesLib.toUint256(data, 92);
/// @notice         uint256 outputMin = BytesLib.toUint256(data, 124);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 156);
/// @notice         uint256 pathDefinition_paramLength = BytesLib.toUint256(data, 157);
/// @notice         bytes pathDefinition = BytesLib.slice(data, 189, pathDefinition_paramLength);
/// @notice         address executor = BytesLib.toAddress(data, 189 + pathDefinition_paramLength);
/// @notice         uint64 referralCode = BytesLib.toUint64(data, 189 + pathDefinition_paramLength + 20);
/// @notice         uint64 referralFee = BytesLib.toUint64(data, 189 + pathDefinition_paramLength + 28);
/// @notice         address feeRecipient = BytesLib.toAddress(data, 189 + pathDefinition_paramLength + 36);
/// @dev The executor address is passed directly to the Odos Router V3, which delegate-calls into it
///      for swap execution. The executor must be trusted -- off-chain validation via inspect() is recommended.
contract SwapOdosV3Hook is BaseHook, ISuperHookContextAware, ISuperHookInflowOutflow, ISuperHookOutflow {
    IOdosRouterV3 public immutable ODOS_ROUTER_V3;

    /*//////////////////////////////////////////////////////////////
                        DATA LAYOUT POSITIONS
    //////////////////////////////////////////////////////////////*/
    uint256 private constant INPUT_TOKEN_POSITION = 0;
    uint256 private constant INPUT_AMOUNT_POSITION = 20;
    uint256 private constant AMOUNT_POSITION = 20;
    uint256 private constant INPUT_RECEIVER_POSITION = 52;
    uint256 private constant OUTPUT_TOKEN_POSITION = 72;
    uint256 private constant OUTPUT_QUOTE_POSITION = 92;
    uint256 private constant OUTPUT_MIN_POSITION = 124;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 156;
    uint256 private constant PATH_DEF_LENGTH_POSITION = 157;
    uint256 private constant PATH_DEF_DATA_POSITION = 189;

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

    /// @notice Decoded parameters for Odos V3 swap execution
    struct HookParams {
        address inputToken;
        uint256 inputAmount;
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
        return "Swap Odos V3";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Swaps tokens via Odos V3 aggregator";
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

        params.inputToken = BytesLib.toAddress(data, INPUT_TOKEN_POSITION);
        address outputToken = BytesLib.toAddress(data, OUTPUT_TOKEN_POSITION);
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

        params.inputAmount = BytesLib.toUint256(data, INPUT_AMOUNT_POSITION);

        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
        if (usePrevHookAmount) {
            params.inputAmount = ISuperHookResult(prevHook).getOutAmount(account);
        }

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(ODOS_ROUTER_V3),
            value: params.inputToken == address(0) ? params.inputAmount : 0,
            callData: abi.encodeCall(
                IOdosRouterV3.swap,
                (
                    _getSwapInfo(account, prevHook, data),
                    params.pathDefinition,
                    params.executor,
                    IOdosRouterV3.swapReferralInfo(params.referralCode, params.referralFee, params.feeRecipient)
                )
            )
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
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
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the balance of the output token for the given account
    function _getBalance(address account, bytes memory data) private view returns (uint256) {
        address outputToken = BytesLib.toAddress(data, OUTPUT_TOKEN_POSITION);

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
        address inputToken = BytesLib.toAddress(data, INPUT_TOKEN_POSITION);
        uint256 inputAmount = BytesLib.toUint256(data, INPUT_AMOUNT_POSITION);
        address inputReceiver = BytesLib.toAddress(data, INPUT_RECEIVER_POSITION);
        address outputToken = BytesLib.toAddress(data, OUTPUT_TOKEN_POSITION);
        uint256 outputQuote = BytesLib.toUint256(data, OUTPUT_QUOTE_POSITION);
        uint256 outputAmount = BytesLib.toUint256(data, OUTPUT_MIN_POSITION);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

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
