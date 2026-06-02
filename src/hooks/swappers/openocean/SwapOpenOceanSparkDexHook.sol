// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IOpenOceanCaller } from "../../../vendor/openocean/IOpenOceanCaller.sol";
import { IOpenOceanExchange } from "../../../vendor/openocean/IOpenOceanExchange.sol";
import { OpenOceanSparkDexScaler } from "../../../libraries/OpenOceanSparkDexScaler.sol";
import { ISuperHookContextAware, ISuperHookInspector, ISuperHookResult } from "../../../interfaces/ISuperHook.sol";

/// @title SwapOpenOceanSparkDexHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address outputToken = BytesLib.toAddress(data, 0);
/// @notice         uint256 value = BytesLib.toUint256(data, 20);
/// @notice         uint256 inputAmount = BytesLib.toUint256(data, 52);
/// @notice         uint256 outputMin = BytesLib.toUint256(data, 84);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 116);
/// @notice         uint256 txDataLength = BytesLib.toUint256(data, 117);
/// @notice         bytes txData_ = BytesLib.slice(data, 149, txDataLength);
contract SwapOpenOceanSparkDexHook is BaseHook, ISuperHookContextAware {
    IOpenOceanExchange public immutable OPENOCEAN_ROUTER;
    IOpenOceanCaller public immutable OPENOCEAN_CALLER;

    address public immutable NATIVE;

    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 116;

    /// @notice Thrown when inputToken and outputToken are the same address
    error SAME_INPUT_OUTPUT_TOKEN();

    constructor(
        address router_,
        address caller_,
        address nativeToken_
    )
        BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP)
    {
        if (router_ == address(0) || caller_ == address(0)) revert ADDRESS_NOT_VALID();
        OPENOCEAN_ROUTER = IOpenOceanExchange(router_);
        OPENOCEAN_CALLER = IOpenOceanCaller(caller_);
        NATIVE = nativeToken_;
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

        _validateTokenPair(_getInputToken(txData_), outputToken);

        uint256 executionAmount = inputAmount;
        if (usePrevHookAmount) {
            executionAmount = ISuperHookResult(prevHook).getOutAmount(account);
        }

        txData_ = OpenOceanSparkDexScaler.updateTxDataAmounts(
            txData_, address(OPENOCEAN_CALLER), executionAmount, inputAmount
        );
        uint256 value = _isNativeInput(txData_) ? executionAmount : 0;

        executions = new Execution[](1);
        executions[0] = Execution({ target: address(OPENOCEAN_ROUTER), value: value, callData: txData_ });
    }

    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        uint256 txDataLength = BytesLib.toUint256(data, 117);
        bytes memory txData_ = BytesLib.slice(data, 149, txDataLength);

        (
            IOpenOceanCaller caller,
            IOpenOceanExchange.SwapDescription memory desc,
            IOpenOceanCaller.CallDescription[] memory calls
        ) = abi.decode(
            BytesLib.slice(txData_, 4, txData_.length - 4),
            (IOpenOceanCaller, IOpenOceanExchange.SwapDescription, IOpenOceanCaller.CallDescription[])
        );
        calls;

        return abi.encodePacked(
            address(caller), address(desc.srcToken), address(desc.dstToken), desc.srcReceiver, desc.dstReceiver
        );
    }

    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data) - getOutAmount(account), account);
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

    function _isNativeInput(bytes memory txData_) private view returns (bool) {
        return _isNative(_getInputToken(txData_));
    }

    function _getInputToken(bytes memory txData_) private pure returns (address) {
        (, IOpenOceanExchange.SwapDescription memory desc,) = abi.decode(
            BytesLib.slice(txData_, 4, txData_.length - 4),
            (IOpenOceanCaller, IOpenOceanExchange.SwapDescription, IOpenOceanCaller.CallDescription[])
        );
        return address(desc.srcToken);
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
