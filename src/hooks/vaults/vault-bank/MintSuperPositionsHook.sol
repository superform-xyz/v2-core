// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IVaultBank } from "../../../vendor/superform/IVaultBank.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

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

/// @title MintSuperPositionsHook
/// @author Superform Labs
/// @notice Mints SuperPosition tokens by locking vault shares into VaultBank.
///         Supports either locking newly acquired shares (via prior hooks)
///         or locking existing vault shares held by the user.
/// @dev data has the following structure:
///         bytes32 yieldSourceOracleId = bytes32(BytesLib.slice(data, 0, 32), 0);
///         address spToken = BytesLib.toAddress(data, 32);
///         uint256 amount = BytesLib.toUint256(data, 52);
///         bool usePrevHookAmount = BytesLib.toBool(data, 84);
///         address vaultBank = BytesLib.toAddress(data, 85);
///         uint256 dstChainId = BytesLib.toUint256(data, 105);
contract MintSuperPositionsHook is
    BaseHook,
    VaultBankLockableHook,
    ISuperHookInflowOutflow,
    ISuperHookContextAware,
    ISuperHookInspector
{
    using SafeCast for uint256;
    using HookDataDecoder for bytes;

    uint256 private constant AMOUNT_POSITION = 52;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 84;

    error ID_NOT_VALID();

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.VAULT_BANK) { }

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
        bytes32 yieldSourceOracleId = data.extractYieldSourceOracleId();
        uint256 amount = _decodeAmount(data);
        // The bundler determines the correct placement of this hook based on context:
        // - It follows a previous hook that granted shares to the user, OR
        // - The user is independently locking shares.
        //
        // Note: It is not possible to distinguish whether the shares originate from an asset directly
        // or from a yield source.
        address spToken = data.extractYieldSource();
        address vaultBank = BytesLib.toAddress(data, 85);
        uint256 dstChainId = BytesLib.toUint256(data, 105);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (vaultBank == address(0) || spToken == address(0)) revert ADDRESS_NOT_VALID();
        if (dstChainId == 0 || yieldSourceOracleId == bytes32(0)) revert ID_NOT_VALID();

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).getOutAmount(account);
        }
        if (amount == 0) revert AMOUNT_NOT_VALID();

        executions = new Execution[](4);
        executions[0] =
            Execution({ target: spToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vaultBank, 0)) });
        executions[1] =
            Execution({ target: spToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vaultBank, amount)) });
        executions[2] = Execution({
            target: vaultBank,
            value: 0,
            callData: abi.encodeCall(
                IVaultBank.lockAsset, (yieldSourceOracleId, account, spToken, address(this), amount, dstChainId.toUint64())
            )
        });
        executions[3] =
            Execution({ target: spToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vaultBank, 0)) });
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
    function inspect(bytes calldata data) external pure returns (bytes memory) {
        return abi.encodePacked(
            data.extractYieldSource(),
            /**
             * spToken
             */
            BytesLib.toAddress(data, 85)
        );
        /**
         * vaultBank
         */
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address, bytes calldata data) internal override {
        vaultBank = BytesLib.toAddress(data, 85);
        dstChainId = BytesLib.toUint256(data, 105);
        spToken = data.extractYieldSource();
    }

    function _postExecute(address, address, bytes calldata) internal override { }

    /*//////////////////////////////////////////////////////////////
                          PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _decodeAmount(bytes memory data) private pure returns (uint256) {
        return BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    function _getBalance(address account, address spToken) private view returns (uint256) {
        return IERC20(spToken).balanceOf(account);
    }
}
