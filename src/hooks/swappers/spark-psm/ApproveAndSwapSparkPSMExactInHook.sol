// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataUpdater } from "../../../libraries/HookDataUpdater.sol";
import {
    ISuperHookResult,
    ISuperHookContextAware,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";
import { IPSM3 } from "../../../vendor/spark/IPSM3.sol";

/// @title ApproveAndSwapSparkPSMExactInHook
/// @author Superform Labs
/// @notice Hook for executing exact-input swaps via Spark PSM with approval handling
/// @dev Handles: approve(0) -> approve(amountIn) -> swapExactIn -> approve(0)
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         uint256 placeholder0 = BytesLib.toUint256(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address assetIn = BytesLib.toAddress(data, 52);
/// @notice         address assetOut = BytesLib.toAddress(data, 72);
/// @notice         uint256 amountIn = BytesLib.toUint256(data, 92);
/// @notice         uint256 minAmountOut = BytesLib.toUint256(data, 124);
/// @notice         address receiver = BytesLib.toAddress(data, 156); // IGNORED - forced to account
/// @notice         uint256 referralCode = BytesLib.toUint256(data, 176);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 208);
contract ApproveAndSwapSparkPSMExactInHook is BaseHook, ISuperHookContextAware, ISuperHookInflowOutflow, ISuperHookOutflow {
    using BytesLib for bytes;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The Spark PSM3 contract
    IPSM3 public immutable PSM;

    /// @notice Position of usePrevHookAmount flag in hook data
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 208;

    uint256 private constant AMOUNT_POSITION = 92;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when hook data is malformed or insufficient
    error INVALID_HOOK_DATA();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the Spark PSM ExactIn approve-and-swap hook
    /// @param psmAddress_ The address of the Spark PSM3 contract
    constructor(address psmAddress_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        if (psmAddress_ == address(0)) revert ADDRESS_NOT_VALID();
        PSM = IPSM3(psmAddress_);
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Approve and Swap Spark PSM Exact In";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Approves and swaps exact input tokens via Spark PSM";
    }


    /*//////////////////////////////////////////////////////////////
                            HOOK IMPLEMENTATION
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
        if (data.length < 209) revert INVALID_HOOK_DATA();

        address assetIn = data.toAddress(52);
        address assetOut = data.toAddress(72);
        if (assetIn == address(0) || assetOut == address(0)) revert ADDRESS_NOT_VALID();
        uint256 amountIn = data.toUint256(92);
        uint256 minAmountOut = data.toUint256(124);
        // receiver at offset 156 is IGNORED - forced to account
        uint256 referralCode = data.toUint256(176);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            uint256 prevAmount = ISuperHookResult(prevHook).getOutAmount(account);
            minAmountOut = HookDataUpdater.getUpdatedOutputAmount(prevAmount, amountIn, minAmountOut);
            amountIn = prevAmount;
        }

        // approve(0) -> approve(amountIn) -> swap -> approve(0)
        executions = new Execution[](4);

        // Reset approval to 0 (handles USDT-like tokens)
        executions[0] = Execution({
            target: assetIn,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PSM), 0))
        });

        // Set approval to exact amountIn
        executions[1] = Execution({
            target: assetIn,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PSM), amountIn))
        });

        // Execute swap
        executions[2] = Execution({
            target: address(PSM),
            value: 0,
            callData: abi.encodeCall(
                IPSM3.swapExactIn, (assetIn, assetOut, amountIn, minAmountOut, account, referralCode)
            )
        });

        // Clear approval after swap
        executions[3] = Execution({
            target: assetIn,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PSM), 0))
        });
    }

    /// @inheritdoc BaseHook
    function _preExecute(address, address account, bytes calldata data) internal override {
        address assetOut = data.toAddress(72);
        _setOutAmount(IERC20(assetOut).balanceOf(account), account);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        address assetOut = data.toAddress(72);
        uint256 finalBalance = IERC20(assetOut).balanceOf(account);
        uint256 initialBalance = getOutAmount(account);
        _setOutAmount(finalBalance - initialBalance, account);
        _setOutToken(assetOut, account);
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

    /// @inheritdoc BaseHook
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        address assetOut = data.toAddress(72);
        address receiver = data.toAddress(156);
        return abi.encodePacked(assetOut, receiver);
    }
}
