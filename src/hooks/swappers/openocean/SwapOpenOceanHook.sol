// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IOpenOceanCaller } from "../../../vendor/openocean/IOpenOceanCaller.sol";
import { IOpenOceanExchange } from "../../../vendor/openocean/IOpenOceanExchange.sol";
import { OpenOceanDynamicAmountUpdater } from "../../../libraries/OpenOceanDynamicAmountUpdater.sol";
import {
    ISuperHookContextAware,
    ISuperHookInspector,
    ISuperHookResult,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";

/// @title SwapOpenOceanHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address outputToken = BytesLib.toAddress(data, 0);
/// @notice         uint256 value = BytesLib.toUint256(data, 20);
/// @notice         uint256 inputAmount = BytesLib.toUint256(data, 52);
/// @notice         uint256 outputMin = BytesLib.toUint256(data, 84);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 116);
/// @notice         uint256 txDataLength = BytesLib.toUint256(data, 117);
/// @notice         bytes txData_ = BytesLib.slice(data, 149, txDataLength);
contract SwapOpenOceanHook is BaseHook, ISuperHookContextAware, ISuperHookInflowOutflow, ISuperHookOutflow {
    IOpenOceanExchange public immutable OPENOCEAN_ROUTER;
    address public immutable OPENOCEAN_REFERRER;

    address public immutable NATIVE;

    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 116;
    uint256 private constant AMOUNT_POSITION = 52;

    /// @notice Thrown when inputToken and outputToken are the same address
    error SAME_INPUT_OUTPUT_TOKEN();

    /// @notice Thrown when dstToken in txData does not match the expected outputToken
    error OUTPUT_TOKEN_MISMATCH();

    /// @notice Thrown when resolved execution amount is zero
    error ZERO_EXECUTION_AMOUNT();

    constructor(
        address router_,
        address referrer_,
        address nativeToken_
    )
        BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP)
    {
        if (router_ == address(0) || referrer_ == address(0)) revert ADDRESS_NOT_VALID();
        OPENOCEAN_ROUTER = IOpenOceanExchange(router_);
        OPENOCEAN_REFERRER = referrer_;
        NATIVE = nativeToken_;
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Swap OpenOcean";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Swaps tokens via OpenOcean aggregator";
    }

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
        address outputToken = BytesLib.toAddress(data, 0);
        uint256 inputAmount = BytesLib.toUint256(data, 52);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
        uint256 txDataLength = BytesLib.toUint256(data, 117);
        bytes memory txData_ = BytesLib.slice(data, 149, txDataLength);

        uint256 executionAmount = inputAmount;
        if (usePrevHookAmount) {
            executionAmount = ISuperHookResult(prevHook).getOutAmount(account);
            if (executionAmount == 0) revert ZERO_EXECUTION_AMOUNT();
        }

        (bytes memory updatedTxData, address srcToken, address dstToken) = OpenOceanDynamicAmountUpdater.updateTxDataAmounts(
            txData_, OPENOCEAN_REFERRER, account, executionAmount, inputAmount
        );

        _validateTokenPair(srcToken, outputToken);
        if (!_isSameToken(dstToken, outputToken)) revert OUTPUT_TOKEN_MISMATCH();

        uint256 value = _isNative(srcToken) ? executionAmount : 0;

        executions = new Execution[](1);
        executions[0] = Execution({ target: address(OPENOCEAN_ROUTER), value: value, callData: updatedTxData });
    }

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
        uint256 txDataLength = BytesLib.toUint256(data, 117);
        bytes memory txData_ = BytesLib.slice(data, 149, txDataLength);

        (, IOpenOceanExchange.SwapDescription memory desc,) = abi.decode(
            BytesLib.slice(txData_, 4, txData_.length - 4),
            (IOpenOceanCaller, IOpenOceanExchange.SwapDescription, IOpenOceanCaller.CallDescription[])
        );

        return abi.encodePacked(desc.dstReceiver);
    }

    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data) - getOutAmount(account), account);
        _setOutToken(BytesLib.toAddress(data, 0), account);
    }

    function _getBalance(address account, bytes memory data) private view returns (uint256) {
        address outputToken = BytesLib.toAddress(data, 0);
        if (_isNative(outputToken)) {
            return account.balance;
        }
        return IERC20(outputToken).balanceOf(account);
    }

    function _isNative(address token_) private view returns (bool) {
        return token_ == address(0) || token_ == NATIVE;
    }

    function _validateTokenPair(address inputToken_, address outputToken_) private view {
        if (_isSameToken(inputToken_, outputToken_)) revert SAME_INPUT_OUTPUT_TOKEN();
    }

    function _isSameToken(address tokenA_, address tokenB_) private view returns (bool) {
        if (_isNative(tokenA_) && _isNative(tokenB_)) {
            return true;
        }
        return tokenA_ == tokenB_;
    }
}
