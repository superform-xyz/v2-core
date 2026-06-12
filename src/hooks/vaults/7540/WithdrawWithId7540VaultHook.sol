// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC7540 } from "../../../vendor/vaults/7540/IERC7540.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import {
    ISuperHookResultOutflow,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware,
    ISuperHookInspector
} from "../../../interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

/// @title WithdrawWithId7540VaultHook
/// @author Superform Labs
/// @notice Same as Withdraw7540VaultHook but with requestId from calldata (non-zero support)
/// @dev data has the following structure
/// @notice         bytes32 yieldSourceOracleId = bytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address yieldSource = BytesLib.toAddress(data, 32);
/// @notice         uint256 amount = BytesLib.toUint256(data, 52);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 84);
/// @notice         uint256 requestId = BytesLib.toUint256(data, 85);
contract WithdrawWithId7540VaultHook is BaseHook, ISuperHookInflowOutflow, ISuperHookOutflow, ISuperHookContextAware {
    using HookDataDecoder for bytes;

    uint256 private constant AMOUNT_POSITION = 52;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 84;
    uint256 private constant REQUEST_ID_POSITION = 85;

    constructor() BaseHook(HookType.OUTFLOW, HookSubTypes.ERC7540) { }

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
        uint256 amount = _decodeAmount(data);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            amount = ISuperHookResultOutflow(prevHook).getOutAmount(account);
        }

        if (amount == 0) revert AMOUNT_NOT_VALID();
        if (yieldSource == address(0) || account == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IERC7540.withdraw, (amount, account, account))
        });
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
        meta[0] = ISuperHookInflowOutflow.AmountMeta(ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.ASSETS);
    }

    /// @dev This hook implements ISuperHookInflowOutflow + ISuperHookOutflow
    function _supportsSizingInterface() internal pure override returns (bool) {
        return true;
    }

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
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
        return abi.encodePacked(data.extractYieldSource());
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        address yieldSource = data.extractYieldSource();
        asset = IERC7540(yieldSource).asset();
        _setOutAmount(_getBalance(account, data), account);
        usedShares = _getSharesBalance(account, data);
        spToken = IERC7540(yieldSource).share();
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data) - getOutAmount(account), account);
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
        uint256 requestId = BytesLib.toUint256(data, REQUEST_ID_POSITION);
        return IERC7540(yieldSource).claimableRedeemRequest(requestId, account);
    }
}
