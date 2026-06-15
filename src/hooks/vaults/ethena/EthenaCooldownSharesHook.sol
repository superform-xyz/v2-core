// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IStakedUSDeCooldown } from "../../../vendor/ethena/IStakedUSDeCooldown.sol";
// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISuperHookResult, ISuperHookInflowOutflow, ISuperHookOutflow, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title EthenaCooldownSharesHook
/// @author Superform Labs
/// @dev data has the following structure

/// @notice         bytes32 yieldSourceOracleId = bytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address yieldSource = BytesLib.toAddress(data, 32);
/// @notice         uint256 shares = BytesLib.toUint256(data, 52);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 84);
contract EthenaCooldownSharesHook is BaseHook, ISuperHookInflowOutflow, ISuperHookOutflow {
    using HookDataDecoder for bytes;

    uint256 private constant AMOUNT_POSITION = 52;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 84;

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.COOLDOWN) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Ethena Cooldown Shares";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Initiates cooldown for Ethena staked shares";
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
        address yieldSource = data.extractYieldSource();
        uint256 shares = _decodeAmount(data);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            shares = ISuperHookResult(prevHook).getOutAmount(account);
        }

        if (shares == 0) revert AMOUNT_NOT_VALID();
        if (yieldSource == address(0) || account == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IStakedUSDeCooldown.cooldownShares, (shares))
        });
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(data.extractYieldSource());
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

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        usedShares = _getSharesBalance(account, data);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        usedShares = usedShares - _getSharesBalance(account, data);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _decodeAmount(bytes memory data) private pure returns (uint256) {
        return BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    function _getSharesBalance(address account, bytes memory data) private view returns (uint256) {
        return IERC20(data.extractYieldSource()).balanceOf(account);
    }
}
