// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import {
    ISuperHookResult,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware,
    ISuperHookInspector
} from "../../../interfaces/ISuperHook.sol";
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { IDETHAsyncRedeemer } from "../../../vendor/vaults/deth/IDETHAsyncRedeemer.sol";

/// @title ApproveAndRequestRedeemDETHHook
/// @author Superform Labs
/// @notice This hook does not support tokens reverting on 0 approval
/// @notice Approves DETH to Dialectic's AsyncRedeemer and requests redemption for WETH.
///         Uses zero-exact-execute-zero approval pattern. Assets are NOT transferred in this step —
///         use ClaimAssetsDETHHook after finalization.
/// @dev data has the following structure
/// @notice         bytes32 yieldSourceOracleId = bytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address asyncRedeemer = BytesLib.toAddress(data, 32);
/// @notice         address dethToken = BytesLib.toAddress(data, 52);
/// @notice         uint256 shares = BytesLib.toUint256(data, 72);
/// @notice         uint256 minAssets = BytesLib.toUint256(data, 104);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 136);
contract ApproveAndRequestRedeemDETHHook is BaseHook, ISuperHookInflowOutflow, ISuperHookOutflow, ISuperHookContextAware {
    using HookDataDecoder for bytes;

    uint256 private constant AMOUNT_POSITION = 72;
    uint256 private constant MIN_ASSETS_POSITION = 104;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 136;

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.ERC4626) { }

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
        address asyncRedeemer = data.extractYieldSource();
        address dethToken = BytesLib.toAddress(data, 52);
        uint256 shares = _decodeAmount(data);
        uint256 minAssets = BytesLib.toUint256(data, MIN_ASSETS_POSITION);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            shares = ISuperHookResult(prevHook).getOutAmount(account);
        }

        if (shares == 0) revert AMOUNT_NOT_VALID();
        if (asyncRedeemer == address(0) || account == address(0) || dethToken == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

        executions = new Execution[](4);
        executions[0] =
            Execution({ target: dethToken, value: 0, callData: abi.encodeCall(IERC20.approve, (asyncRedeemer, 0)) });
        executions[1] = Execution({
            target: dethToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (asyncRedeemer, shares))
        });
        executions[2] = Execution({
            target: asyncRedeemer,
            value: 0,
            callData: abi.encodeCall(IDETHAsyncRedeemer.requestRedeem, (shares, account, minAssets))
        });
        executions[3] =
            Execution({ target: dethToken, value: 0, callData: abi.encodeCall(IERC20.approve, (asyncRedeemer, 0)) });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        amounts[0] = _decodeAmount(data);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory) external pure override returns (ISuperHookInflowOutflow.AmountMeta[] memory meta) {
        meta = new ISuperHookInflowOutflow.AmountMeta[](1);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.SHARES);
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

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(
            data.extractYieldSource(),
            BytesLib.toAddress(data, 52) // dethToken
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getOutAmount(account) - _getBalance(account, data), account);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _decodeAmount(bytes memory data) private pure returns (uint256) {
        return BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    function _getBalance(address account, bytes memory data) private view returns (uint256) {
        address dethToken = BytesLib.toAddress(data, 52);
        return IERC20(dethToken).balanceOf(account);
    }
}
