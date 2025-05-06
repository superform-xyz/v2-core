// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IStandardizedYield } from "../../../../vendor/pendle/IStandardizedYield.sol";

// Superform
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BaseHook } from "../../BaseHook.sol";
import {
    ISuperHookResultOutflow,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware
} from "../../../interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

/// @title Redeem5115VaultHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         bytes4 yieldSourceOracleId = bytes4(BytesLib.slice(data, 0, 4), 0);
/// @notice         address yieldSource = BytesLib.toAddress(data, 4);
/// @notice         address tokenOut = BytesLib.toAddress(data, 24);
/// @notice         uint256 shares = BytesLib.toUint256(data, 44);
/// @notice         uint256 minTokenOut = BytesLib.toUint256(data, 76);
/// @notice         bool burnFromInternalBalance = _decodeBool(data, 108);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 109);
/// @notice         address vaultBank = BytesLib.toAddress(data, 110);
/// @notice         uint256 dstChainId = BytesLib.toUint256(data, 130);
contract Redeem5115VaultHook is BaseHook, ISuperHookInflowOutflow, ISuperHookOutflow, ISuperHookContextAware {
    using HookDataDecoder for bytes;

    uint256 private constant AMOUNT_POSITION = 44;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 109;

    constructor() BaseHook(HookType.OUTFLOW, HookSubTypes.ERC5115) { }

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
        address tokenOut = BytesLib.toAddress(data, 24);
        uint256 shares = _decodeAmount(data);
        uint256 minTokenOut = BytesLib.toUint256(data, 76);
        bool burnFromInternalBalance = _decodeBool(data, 108);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            shares = ISuperHookResultOutflow(prevHook).outAmount();
        }

        if (shares == 0) revert AMOUNT_NOT_VALID();
        if (yieldSource == address(0) || tokenOut == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(
                IStandardizedYield.redeem, (account, shares, tokenOut, minTokenOut, burnFromInternalBalance)
            )
        });
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
        asset = BytesLib.toAddress(data, 24); // tokenOut from data
        outAmount = _getBalance(account, data);
        usedShares = _getSharesBalance(account, data);
        vaultBank = BytesLib.toAddress(data, 110);
        dstChainId = BytesLib.toUint256(data, 130);
        spToken = data.extractYieldSource();
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        outAmount = _getBalance(account, data) - outAmount;
        usedShares = usedShares - _getSharesBalance(account, data);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _decodeAmount(bytes memory data) private pure returns (uint256) {
        return BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    function _getBalance(address account, bytes memory) private view returns (uint256) {
        return IERC20(asset).balanceOf(account);
    }

    function _getSharesBalance(address account, bytes memory data) private view returns (uint256) {
        address yieldSource = data.extractYieldSource();
        return IStandardizedYield(yieldSource).balanceOf(account);
    }
}
