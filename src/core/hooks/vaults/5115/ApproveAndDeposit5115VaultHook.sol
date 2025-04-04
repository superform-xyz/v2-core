// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import { IStandardizedYield } from "../../../../vendor/pendle/IStandardizedYield.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookInflowOutflow,
    ISuperHookContextAware
} from "../../../interfaces/ISuperHook.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

/// @title ApproveAndDeposit5115VaultHook
/// @author Superform Labs
/// @notice This hook does not support tokens reverting on 0 approval
/// @dev data has the following structure
/// @notice         bytes4 yieldSourceOracleId = bytes4(BytesLib.slice(data, 0, 4), 0);
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 4, 20), 0);
/// @notice         address tokenIn = BytesLib.toAddress(BytesLib.slice(data, 24, 20), 0);
/// @notice         uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 44, 32), 0);
/// @notice         uint256 minSharesOut = BytesLib.toUint256(BytesLib.slice(data, 76, 32), 0);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 108);
/// @notice         bool lockForSP = _decodeBool(data, 109);
contract ApproveAndDeposit5115VaultHook is BaseHook, ISuperHook, ISuperHookInflowOutflow, ISuperHookContextAware {
    using HookDataDecoder for bytes;

    uint256 private constant AMOUNT_POSITION = 44;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 108;

    constructor(address registry_) BaseHook(registry_, HookType.INFLOW) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
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
        address tokenIn = BytesLib.toAddress(BytesLib.slice(data, 24, 20), 0);
        uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 44, 32), 0);
        uint256 minSharesOut = BytesLib.toUint256(BytesLib.slice(data, 76, 32), 0);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).outAmount();
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
    /// @inheritdoc ISuperHook
    function preExecute(address, address account, bytes memory data) external {
        outAmount = _getBalance(account, data);
        lockForSP = _decodeBool(data, 109);
        spToken = data.extractYieldSource();
        asset = BytesLib.toAddress(BytesLib.slice(data, 24, 20), 0);
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, address account, bytes memory data) external {
        outAmount = _getBalance(account, data) - outAmount;
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmount(bytes memory data) external pure returns (uint256) {
        return _decodeAmount(data);
    }

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _decodeAmount(bytes memory data) private pure returns (uint256) {
        return BytesLib.toUint256(BytesLib.slice(data, AMOUNT_POSITION, 32), 0);
    }

    function _getBalance(address account, bytes memory data) private view returns (uint256) {
        return IERC4626(data.extractYieldSource()).balanceOf(account);
    }
}
