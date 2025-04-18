// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC7540 } from "../../../../vendor/vaults/7540/IERC7540.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISuperVault } from "../../../../periphery/interfaces/ISuperVault.sol";
import { ISuperHookAsyncCancelations } from "../../../interfaces/ISuperHook.sol";

/// @title CancelDepositHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         bytes4 placeholder = BytesLib.toAddress(data, 0);
/// @notice         address yieldSource = BytesLib.toAddress(data, 4);
contract CancelDepositHook is BaseHook, ISuperHookAsyncCancelations {
    using HookDataDecoder for bytes;

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.CANCEL_DEPOSIT) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function build(
        address,
        address account,
        bytes memory data
    )
        external
        pure
        override
        returns (Execution[] memory executions)
    {
        address yieldSource = data.extractYieldSource();

        if (yieldSource == address(0) || account == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] =
            Execution({ target: yieldSource, value: 0, callData: abi.encodeCall(ISuperVault.cancelDeposit, (account)) });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookAsyncCancelations
    function isAsyncCancelHook() external pure returns (CancelationType) {
        return CancelationType.INFLOW;
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        address yieldSource = data.extractYieldSource();
        asset = IERC7540(yieldSource).asset();
        // store current balance
        outAmount = _getBalance(account, data);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        outAmount = _getBalance(account, data) - outAmount;
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/

    function _getBalance(address account, bytes memory) private view returns (uint256) {
        return IERC20(asset).balanceOf(account);
    }
}
