// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IStandardizedYield } from "../../../vendor/pendle/IStandardizedYield.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { VaultBankLockableHook } from "../../VaultBankLockableHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import {
    ISuperHookResult,
    ISuperHookInflowOutflow,
    ISuperHookContextAware,
    ISuperHookInspector
} from "../../../interfaces/ISuperHook.sol";

/// @title ApproveAndDeposit5115VaultHook
/// @author Superform Labs
/// @notice This hook does not support tokens reverting on 0 approval
/// @dev data has the following structure
/// @notice         bytes32 yieldSourceOracleId = bytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address yieldSource = BytesLib.toAddress(data, 32);
/// @notice         address tokenIn = BytesLib.toAddress(data, 52);
/// @notice         uint256 amount = BytesLib.toUint256(data, 72);
/// @notice         uint256 minSharesOut = BytesLib.toUint256(data, 104);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 136);
contract ApproveAndDeposit5115VaultHook is
    BaseHook,
    VaultBankLockableHook,
    ISuperHookInflowOutflow,
    ISuperHookContextAware
{
    using HookDataDecoder for bytes;

    uint256 private constant AMOUNT_POSITION = 72;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 136;

    constructor() BaseHook(HookType.INFLOW, HookSubTypes.ERC5115) { }

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
        address yieldSource = data.extractYieldSource();
        address tokenIn = BytesLib.toAddress(data, 52);
        uint256 amount = BytesLib.toUint256(data, AMOUNT_POSITION);
        uint256 minSharesOut = BytesLib.toUint256(data, 104);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).getOutAmount(account);
        }

        if (amount == 0) revert AMOUNT_NOT_VALID();
        if (yieldSource == address(0) || account == address(0) || tokenIn == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](4);
        executions[0] =
            Execution({ target: tokenIn, value: 0, callData: abi.encodeCall(IERC20.approve, (yieldSource, 0)) });
        executions[1] =
            Execution({ target: tokenIn, value: 0, callData: abi.encodeCall(IERC20.approve, (yieldSource, amount)) });
        executions[2] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IStandardizedYield.deposit, (account, tokenIn, amount, minSharesOut))
        });
        executions[3] =
            Execution({ target: tokenIn, value: 0, callData: abi.encodeCall(IERC20.approve, (yieldSource, 0)) });
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

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(
            data.extractYieldSource(),
            BytesLib.toAddress(data, 52) // tokenIn
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data), account);
        spToken = data.extractYieldSource();
        asset = BytesLib.toAddress(data, 52);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data) - getOutAmount(account), account);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _decodeAmount(bytes memory data) private pure returns (uint256) {
        return BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    function _getBalance(address account, bytes memory data) private view returns (uint256) {
        return IStandardizedYield(data.extractYieldSource()).balanceOf(account);
    }
}
