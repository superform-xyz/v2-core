// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IMetaAggregationRouterV2 } from "../../../vendor/kyberswap/IMetaAggregationRouterV2.sol";
import { IScaleHelper } from "../../../vendor/kyberswap/IScaleHelper.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { KyberSwapScaler } from "../../../libraries/KyberSwapScaler.sol";
import { ISuperHookResult, ISuperHookContextAware, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title ApproveAndSwapKyberSwapHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address inputToken = BytesLib.toAddress(data, 0);
/// @notice         address outputToken = BytesLib.toAddress(data, 20);
/// @notice         uint256 inputAmount = BytesLib.toUint256(data, 40);
/// @notice         uint256 outputMin = BytesLib.toUint256(data, 72);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 104);
/// @notice         uint256 txDataLength = BytesLib.toUint256(data, 105);
/// @notice         bytes txData_ = BytesLib.slice(data, 137, txDataLength);
contract ApproveAndSwapKyberSwapHook is BaseHook, ISuperHookContextAware {
    IMetaAggregationRouterV2 public immutable KYBER_ROUTER;
    IScaleHelper public immutable SCALE_HELPER;

    address public immutable NATIVE;

    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 104;

    constructor(
        address router_,
        address scaleHelper_,
        address nativeToken_
    )
        BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP)
    {
        if (router_ == address(0)) revert ADDRESS_NOT_VALID();
        KYBER_ROUTER = IMetaAggregationRouterV2(router_);
        SCALE_HELPER = IScaleHelper(scaleHelper_);
        NATIVE = nativeToken_;
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
        address inputToken = BytesLib.toAddress(data, 0);
        uint256 inputAmount = BytesLib.toUint256(data, 40);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
        uint256 txDataLength = BytesLib.toUint256(data, 105);
        bytes memory txData_ = BytesLib.slice(data, 137, txDataLength);

        // Extract approveTarget before scaling to avoid double-decoding SwapExecutionParams
        address approveTarget = _getApproveTarget(txData_);

        if (usePrevHookAmount) {
            uint256 prevAmount = ISuperHookResult(prevHook).getOutAmount(account);
            txData_ = KyberSwapScaler.updateTxDataAmounts(SCALE_HELPER, txData_, prevAmount, inputAmount);
            inputAmount = prevAmount;
        }

        executions = new Execution[](4);
        executions[0] = Execution({
            target: inputToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (approveTarget, 0))
        });

        executions[1] = Execution({
            target: inputToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (approveTarget, inputAmount))
        });

        executions[2] = Execution({ target: address(KYBER_ROUTER), value: 0, callData: txData_ });

        executions[3] = Execution({
            target: inputToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (approveTarget, 0))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        uint256 txDataLength = BytesLib.toUint256(data, 105);
        bytes memory txData_ = BytesLib.slice(data, 137, txDataLength);

        IMetaAggregationRouterV2.SwapExecutionParams memory params =
            abi.decode(BytesLib.slice(txData_, 4, txData_.length - 4), (IMetaAggregationRouterV2.SwapExecutionParams));

        return abi.encodePacked(address(params.desc.dstToken));
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data) - getOutAmount(account), account);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/

    function _getBalance(address account, bytes memory data) private view returns (uint256) {
        address outputToken = BytesLib.toAddress(data, 20);
        if (outputToken == NATIVE) {
            return account.balance;
        }
        return IERC20(outputToken).balanceOf(account);
    }

    /// @dev Extracts approveTarget from decoded txData. Falls back to KYBER_ROUTER if zero address.
    function _getApproveTarget(bytes memory txData_) private view returns (address) {
        IMetaAggregationRouterV2.SwapExecutionParams memory params = abi.decode(
            BytesLib.slice(txData_, 4, txData_.length - 4), (IMetaAggregationRouterV2.SwapExecutionParams)
        );

        if (params.approveTarget == address(0)) {
            return address(KYBER_ROUTER);
        }
        return params.approveTarget;
    }
}
