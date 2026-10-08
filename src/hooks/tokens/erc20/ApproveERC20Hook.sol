// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import {
    ISuperHookResult,
    ISuperHookContextAware,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";

/// @title ApproveERC20Hook
/// @author Superform Labs
/// @notice This hook does not support tokens reverting on 0 approval
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address token = BytesLib.toAddress(data, 52);
/// @notice         address spender = BytesLib.toAddress(data, 72);
/// @notice         uint256 amount = BytesLib.toUint256(data, 92);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 124);
contract ApproveERC20Hook is BaseHook, ISuperHookContextAware, ISuperHookInflowOutflow, ISuperHookOutflow {
    uint256 private constant AMOUNT_POSITION = 92;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 124;

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.TOKEN) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Approve ERC-20";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Approves an ERC-20 token spending allowance";
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
        address token = BytesLib.toAddress(data, 52);
        address spender = BytesLib.toAddress(data, 72);
        uint256 amount = BytesLib.toUint256(data, 92);

        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).getOutAmount(account);
        }

        if (token == address(0) || spender == address(0)) revert ADDRESS_NOT_VALID();

        // @dev no-revert-on-failure tokens are not supported
        executions = new Execution[](2);
        executions[0] = Execution({ target: token, value: 0, callData: abi.encodeCall(IERC20.approve, (spender, 0)) });
        executions[1] =
            Execution({ target: token, value: 0, callData: abi.encodeCall(IERC20.approve, (spender, amount)) });
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
    function amountRoles(bytes memory)
        external
        pure
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        meta = new ISuperHookInflowOutflow.AmountMeta[](1);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(
            ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN
        );
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
        return abi.encodePacked(
            BytesLib.toAddress(data, 52), //token
            BytesLib.toAddress(data, 72) //spender
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev The mode used only when `usePrevHookAmount` is true — see `_preExecute`.
    function _pipeMode() internal pure override returns (PipeMode) {
        return PipeMode.PASSTHROUGH;
    }

    /// @notice THE RULE: this hook reports whatever allowance it set.
    /// @dev `usePrevHookAmount` now governs BOTH halves of this hook consistently:
    ///      - true  -> the allowance is the previous hook's `outAmount`, and that same value is
    ///                 reported onward (BaseHook's PASSTHROUGH);
    ///      - false -> the allowance is this hook's own `amount`, and THAT is reported onward.
    ///
    ///      BEHAVIOUR CHANGE. Previously the flag governed only the allowance: mid-chain, the hook
    ///      forwarded the previous hook's `outAmount` regardless of the flag, so a downstream hook with
    ///      `usePrevHookAmount = true` saw the UPSTREAM amount even when this hook was configured with
    ///      its own. That made the flag look ignored from the consumer's side, and it zeroed chains whose
    ///      source produces no output (a multi-token `BatchTransferHook` reports 0, which is
    ///      indistinguishable from a real zero). Position 0 already behaved the new way; this makes the
    ///      two positions consistent.
    ///
    ///      THE TRADE-OFF, stated because it is a real one. An allowance is an upper bound, not a
    ///      quantity held, so with `usePrevHookAmount = false` a downstream consumer now inherits a
    ///      number this account may not actually hold: `swap(receives 777) -> approve(1000) ->
    ///      deposit(usePrevHookAmount = true)` now deposits 1000 rather than 777 and reverts on the
    ///      shortfall. Set the allowance to the amount actually intended to move, or leave
    ///      `usePrevHookAmount = true` to inherit the real upstream figure. Pinned by
    ///      `test_PreExecute_UsePrevFalse_ReportsOwnAmount_AllowanceAboveBalanceIsCallersProblem`.
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        if (prevHook != address(0) && _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION)) {
            super._preExecute(prevHook, account, data);
        } else {
            _setOutAmount(BytesLib.toUint256(data, AMOUNT_POSITION), account);
            _setOutToken(BytesLib.toAddress(data, 52), account);
        }
    }
}
