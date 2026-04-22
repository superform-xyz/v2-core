// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { ISuperHookResult, ISuperHookInflowOutflow, ISuperHookContextAware } from "../../../interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { IFirelightVault } from "../../../vendor/vaults/firelight/IFirelightVault.sol";

/// @title ClaimWithdrawFirelightVaultHook
/// @author Superform Labs
/// @notice Claims FXRP from a completed Firelight withdrawal request after the cooldown period.
///         Must be used after RedeemFirelightVaultHook has created the withdrawal request.
/// @dev data has the following structure
/// @notice         bytes32 yieldSourceOracleId = bytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address yieldSource = BytesLib.toAddress(data, 32);
/// @notice         uint256 requestId = BytesLib.toUint256(data, 52);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 84);
contract ClaimWithdrawFirelightVaultHook is BaseHook, ISuperHookInflowOutflow, ISuperHookContextAware {
    using HookDataDecoder for bytes;

    uint256 private constant REQUEST_ID_POSITION = 52;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 84;

    constructor() BaseHook(HookType.OUTFLOW, HookSubTypes.ERC4626) { }

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
        uint256 requestId = _decodeRequestId(data);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            requestId = ISuperHookResult(prevHook).getOutAmount(account);
        }

        if (yieldSource == address(0) || account == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IFirelightVault.claimWithdraw, (requestId))
        });
    }

    /// @inheritdoc BaseHook
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(data.extractYieldSource());
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmount(bytes memory data) external pure returns (uint256) {
        return _decodeRequestId(data);
    }

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        address yieldSource = data.extractYieldSource();
        asset = IFirelightVault(yieldSource).asset();
        spToken = yieldSource;
        _setOutAmount(_getBalance(account), account);
        // NOTE: usedShares intentionally not set — shares were burned in the prior RedeemFirelightVaultHook step
    }

    /// @dev outAmount may be 0 if the request is not yet claimable or vault is paused
    function _postExecute(address, address account, bytes calldata) internal override {
        _setOutAmount(_getBalance(account) - getOutAmount(account), account);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _decodeRequestId(bytes memory data) private pure returns (uint256) {
        return BytesLib.toUint256(data, REQUEST_ID_POSITION);
    }

    function _getBalance(address account) private view returns (uint256) {
        return IERC20(asset).balanceOf(account);
    }
}
