// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

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

/// @title WrappedNativeHook
/// @author Superform Labs
/// @notice Hook for wrapping native tokens into their ERC-20 equivalent (e.g. ETH -> WETH, FLR -> WFLR)
///         or unwrapping them back (e.g. WETH -> ETH, WFLR -> FLR)
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         uint256 placeholder0 = BytesLib.toUint256(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         uint256 amount = BytesLib.toUint256(data, 52);
/// @notice         bool wrap = _decodeBool(data, 84);              // true = wrap (native -> wrapped), false = unwrap (wrapped -> native)
/// @notice         bool usePrevHookAmount = _decodeBool(data, 85);
contract WrappedNativeHook is BaseHook, ISuperHookContextAware, ISuperHookInflowOutflow, ISuperHookOutflow {
    /*//////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The wrapped native token contract address (e.g. WETH, WFLR, WAVAX)
    address public immutable WRAPPED_NATIVE;

    /// @notice Position of the amount in the hook data (after 52-byte strategy header)
    uint256 private constant AMOUNT_POSITION = 52;

    /// @notice Position of the wrap direction flag in the hook data
    uint256 private constant WRAP_POSITION = 84;

    /// @notice Position of the usePrevHookAmount flag in the hook data
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 85;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the amount to wrap or unwrap is zero
    error ZERO_AMOUNT();

    /// @notice Thrown when account has insufficient wrapped native balance for unwrapping
    error INSUFFICIENT_BALANCE();

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address wrappedNative) BaseHook(HookType.NONACCOUNTING, HookSubTypes.TOKEN) {
        WRAPPED_NATIVE = wrappedNative;
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Wrapped Native";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Wraps native tokens into their ERC-20 equivalent or unwraps them back";
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
        uint256 amount = BytesLib.toUint256(data, AMOUNT_POSITION);
        bool wrap = _decodeBool(data, WRAP_POSITION);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).getOutAmount(account);
        }

        if (amount == 0) revert ZERO_AMOUNT();

        executions = new Execution[](1);

        if (wrap) {
            // Wrap: deposit native token to receive wrapped native (e.g. ETH -> WETH)
            executions[0] = Execution({
                target: WRAPPED_NATIVE,
                value: amount,
                callData: abi.encodeWithSignature("deposit()")
            });
        } else {
            // Unwrap: withdraw wrapped native to receive native token (e.g. WETH -> ETH)
            uint256 wrappedBalance = IERC20(WRAPPED_NATIVE).balanceOf(account);
            if (wrappedBalance < amount) revert INSUFFICIENT_BALANCE();

            executions[0] = Execution({
                target: WRAPPED_NATIVE,
                value: 0,
                callData: abi.encodeWithSignature("withdraw(uint256)", amount)
            });
        }
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
    function inspect(bytes calldata) external view override returns (bytes memory) {
        return abi.encodePacked(WRAPPED_NATIVE);
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the initial balance as outAmount before execution
    /// @dev For wrap: records native balance. For unwrap: records wrapped native balance.
    function _preExecute(address, address account, bytes calldata data) internal override {
        bool wrap = _decodeBool(data, WRAP_POSITION);
        if (wrap) {
            _setOutAmount(account.balance, account);
        } else {
            _setOutAmount(IERC20(WRAPPED_NATIVE).balanceOf(account), account);
        }
    }

    /// @notice Updates outAmount with the balance difference after execution
    /// @dev For wrap: ETH spent equals amount deposited. For unwrap: wrapped native spent equals amount withdrawn.
    /// @dev outToken is WRAPPED_NATIVE for wrap, address(0) for unwrap (native ETH/FLR/etc.)
    function _postExecute(address, address account, bytes calldata data) internal override {
        bool wrap = _decodeBool(data, WRAP_POSITION);
        uint256 previousBalance = getOutAmount(account);
        uint256 currentBalance = wrap ? account.balance : IERC20(WRAPPED_NATIVE).balanceOf(account);
        _setOutAmount(previousBalance - currentBalance, account);
        _setOutToken(wrap ? WRAPPED_NATIVE : address(0), account);
    }
}
