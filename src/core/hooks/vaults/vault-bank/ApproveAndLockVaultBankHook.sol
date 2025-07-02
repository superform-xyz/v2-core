// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IVaultBank } from "../../../../periphery/interfaces/VaultBank/IVaultBank.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISuperHookResult, ISuperLockableHook } from "../../../interfaces/ISuperHook.sol";

/// @title ApproveAndLockVaultBankHook
/// @author Superform Labs
/// @notice This hook approves and locks assets in the VaultBank for cross-chain operations
/// @dev data has the following structure:
///         bytes32 yieldSourceOracleId = bytes32(BytesLib.slice(data, 0, 32), 0);
///         address spToken = BytesLib.toAddress(data, 32);
contract ApproveAndLockVaultBankHook is BaseHook
{
    using SafeCast for uint256;
    using HookDataDecoder for bytes;
    
    error ID_NOT_VALID();
    error PREV_HOOK_NOT_VALID();

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.VAULT_BANK) {}

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
        // hook must extract details from the previous hook
        if(prevHook == address(0)) revert PREV_HOOK_NOT_VALID();

        address spToken = BytesLib.toAddress(data, 32);
        uint256 amount = ISuperHookResult(prevHook).getOutAmount(account);
        (address vaultBank, uint256 dstChainId, bytes32 yieldSourceOracleId) = ISuperLockableHook(prevHook).extractLockDetails(data);

        if (amount == 0) revert AMOUNT_NOT_VALID();
        if (spToken == address(0) || vaultBank == address(0)) revert ADDRESS_NOT_VALID();
        if (yieldSourceOracleId == bytes32(0) || dstChainId == 0) revert ID_NOT_VALID();

        executions = new Execution[](4);
        executions[0] =
            Execution({ target: spToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vaultBank, 0)) });
        executions[1] =
            Execution({ target: spToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vaultBank, amount)) });
        executions[2] =
            Execution({ target: vaultBank, value: 0, callData: abi.encodeCall(IVaultBank.lockAsset, (yieldSourceOracleId, account, spToken, prevHook, amount, dstChainId.toUint64())) });
        executions[3] =
            Execution({ target: spToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vaultBank, 0)) });
    }
    
    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address prevHook, address account, bytes calldata) internal override {
        // store current balance
        uint256 amount = ISuperHookResult(prevHook).getOutAmount(account);
        _setOutAmount(amount, account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override { }
} 