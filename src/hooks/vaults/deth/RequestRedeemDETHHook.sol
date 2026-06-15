// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import {
    ISuperHookResult,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware,
    ISuperHookInspector
} from "../../../interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { IDETHAsyncRedeemer } from "../../../vendor/vaults/deth/IDETHAsyncRedeemer.sol";
import { IMachine } from "../../../vendor/vaults/deth/IMachine.sol";

/// @title RequestRedeemDETHHook
/// @author Superform Labs
/// @notice Transfers DETH shares to Dialectic's AsyncRedeemer and receives an ERC-721 NFT receipt.
///         Assets are NOT transferred in this step — use ClaimAssetsDETHHook after finalization.
/// @dev Assumes the smart account has already approved DETH to the AsyncRedeemer.
///      The AsyncRedeemer requires the caller to be whitelisted.
/// @dev DETH balance delta tracking assumes DETH does not rebase within a single transaction.
///      If requestRedeem() triggers a Machine sync that changes DETH balances, usedShares may be inaccurate.
/// @dev data has the following structure
/// @notice         bytes32 yieldSourceOracleId = bytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address asyncRedeemer = BytesLib.toAddress(data, 32);
/// @notice         uint256 shares = BytesLib.toUint256(data, 52);
/// @notice         uint256 minAssets = BytesLib.toUint256(data, 84);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 116);
contract RequestRedeemDETHHook is BaseHook, ISuperHookInflowOutflow, ISuperHookOutflow, ISuperHookContextAware {
    using HookDataDecoder for bytes;

    uint256 private constant AMOUNT_POSITION = 52;
    uint256 private constant MIN_ASSETS_POSITION = 84;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 116;

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.ERC4626) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Request Redeem DETH";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Requests a redemption from a DETH vault";
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
        address asyncRedeemer = data.extractYieldSource();
        uint256 shares = _decodeAmount(data);
        uint256 minAssets = BytesLib.toUint256(data, MIN_ASSETS_POSITION);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            shares = ISuperHookResult(prevHook).getOutAmount(account);
        }

        if (shares == 0) revert AMOUNT_NOT_VALID();
        if (asyncRedeemer == address(0) || account == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: asyncRedeemer,
            value: 0,
            callData: abi.encodeCall(IDETHAsyncRedeemer.requestRedeem, (shares, account, minAssets))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(data.extractYieldSource());
    }

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

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        address asyncRedeemer = data.extractYieldSource();
        address machine = IDETHAsyncRedeemer(asyncRedeemer).machine();
        spToken = IMachine(machine).shareToken();
        usedShares = IERC20(spToken).balanceOf(account);
    }

    function _postExecute(address, address account, bytes calldata) internal override {
        usedShares = usedShares - IERC20(spToken).balanceOf(account);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _decodeAmount(bytes memory data) private pure returns (uint256) {
        return BytesLib.toUint256(data, AMOUNT_POSITION);
    }
}
