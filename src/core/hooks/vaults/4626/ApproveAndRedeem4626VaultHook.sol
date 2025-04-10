// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import {
    ISuperHookResultOutflow,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware
} from "../../../interfaces/ISuperHook.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

/// @title ApproveAndRedeem4626VaultHook
/// @author Superform Labs
/// @notice This hook does not support tokens reverting on 0 approval
/// @dev data has the following structure
/// @notice         bytes4 yieldSourceOracleId = bytes4(BytesLib.slice(data, 0, 4), 0);
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 4, 20), 0);
/// @notice         address token = BytesLib.toAddress(BytesLib.slice(data, 24, 20), 0);
/// @notice         address owner = BytesLib.toAddress(BytesLib.slice(data, 44, 20), 0);
/// @notice         uint256 shares = BytesLib.toUint256(BytesLib.slice(data, 64, 32), 0);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 96);
/// @notice         bool lockForSP = _decodeBool(data, 97);
contract ApproveAndRedeem4626VaultHook is
    BaseHook,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware
{
    using HookDataDecoder for bytes;

    uint256 private constant AMOUNT_POSITION = 64;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 96;

    constructor(address registry_) BaseHook(registry_, HookType.OUTFLOW) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    function build(
        address prevHook,
        address account,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        address yieldSource = data.extractYieldSource();
        address token = BytesLib.toAddress(BytesLib.slice(data, 24, 20), 0);
        address owner = BytesLib.toAddress(BytesLib.slice(data, 44, 20), 0);
        uint256 shares = _decodeAmount(data);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            shares = ISuperHookResultOutflow(prevHook).outAmount();
        }

        if (shares == 0) revert AMOUNT_NOT_VALID();
        if (yieldSource == address(0) || owner == address(0) || token == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](4);
        executions[0] =
            Execution({ target: token, value: 0, callData: abi.encodeCall(IERC20.approve, (yieldSource, 0)) });
        executions[1] =
            Execution({ target: token, value: 0, callData: abi.encodeCall(IERC20.approve, (yieldSource, shares)) });
        executions[2] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IERC4626.redeem, (shares, account, owner))
        });
        executions[3] =
            Execution({ target: token, value: 0, callData: abi.encodeCall(IERC20.approve, (yieldSource, 0)) });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmount(bytes memory data) external pure returns (uint256) {
        return _decodeAmount(data);
    }

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookOutflow
    function replaceCalldataAmount(bytes memory data, uint256 amount) external pure returns (bytes memory) {
        return _replaceCalldataAmount(data, amount, AMOUNT_POSITION);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        address yieldSource = data.extractYieldSource();
        asset = IERC4626(yieldSource).asset();
        outAmount = _getBalance(account, data);
        usedShares = _getSharesBalance(account, data);
        lockForSP = _decodeBool(data, 97);
        spToken = yieldSource;
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        outAmount = _getBalance(account, data) - outAmount;
        usedShares = usedShares - _getSharesBalance(account, data);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _decodeAmount(bytes memory data) private pure returns (uint256) {
        return BytesLib.toUint256(BytesLib.slice(data, AMOUNT_POSITION, 32), 0);
    }

    function _getBalance(address account, bytes memory) private view returns (uint256) {
        return IERC20(asset).balanceOf(account);
    }

    function _getSharesBalance(address account, bytes memory data) private view returns (uint256) {
        address yieldSource = data.extractYieldSource();
        return IERC4626(yieldSource).balanceOf(account);
    }
}
