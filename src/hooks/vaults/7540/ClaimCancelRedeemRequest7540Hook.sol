// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC7540CancelRedeem } from "../../../vendor/standards/ERC7540/IERC7540Vault.sol";
import { IERC7540 } from "../../../vendor/vaults/7540/IERC7540.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// Superform
import { BaseHook } from "../../BaseHook.sol";
import { VaultBankLockableHook } from "../../VaultBankLockableHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISuperHookAsyncCancelations, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title ClaimCancelRedeemRequest7540Hook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         bytes32 placeholder = bytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address yieldSource = BytesLib.toAddress(data, 32);
/// @notice         address receiver = BytesLib.toAddress(data, 52);
contract ClaimCancelRedeemRequest7540Hook is
    BaseHook,
    VaultBankLockableHook,
    ISuperHookAsyncCancelations,
    ISuperHookInspector
{
    using HookDataDecoder for bytes;

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.CLAIM_CANCEL_REDEEM_REQUEST) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address,
        address account,
        bytes calldata data
    )
        internal
        pure
        override
        returns (Execution[] memory executions)
    {
        address yieldSource = data.extractYieldSource();
        address receiver = BytesLib.toAddress(data, 52);

        if (yieldSource == address(0) || receiver == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IERC7540CancelRedeem.claimCancelRedeemRequest, (0, receiver, account))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookAsyncCancelations
    function isAsyncCancelHook() external pure returns (CancelationType) {
        return CancelationType.OUTFLOW;
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure returns (bytes memory) {
        return abi.encodePacked(
            data.extractYieldSource(),
            BytesLib.toAddress(data, 52) //receiver
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data), account);
        spToken = IERC7540(data.extractYieldSource()).share();
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        address receiver = BytesLib.toAddress(data, 52);
        _setOutAmount(_getBalance(receiver, data) - getOutAmount(account), account);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/

    function _getBalance(address account, bytes memory data) private view returns (uint256) {
        return IERC20(IERC7540(data.extractYieldSource()).share()).balanceOf(account);
    }
}
