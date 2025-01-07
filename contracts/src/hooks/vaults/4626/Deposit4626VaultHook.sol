// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseAccountingHook } from "../../BaseAccountingHook.sol";

import { ISuperHook, ISuperHookResult } from "../../../interfaces/ISuperHook.sol";

/// @title Deposit4626VaultHook
/// @dev data has the following structure
/// @notice         address account = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         address yieldSourceOracle = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 40, 20), 0);
/// @notice         uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 60, 32), 0);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 92);
contract Deposit4626VaultHook is BaseHook, BaseAccountingHook, ISuperHook {
    constructor(address registry_, address author_) BaseHook(registry_, author_) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(
        address prevHook,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        address account = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 40, 20), 0);
        uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 60, 32), 0);
        bool usePrevHookAmount = _decodeBool(data, 92);

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).outAmount();
        }

        if (amount == 0) revert AMOUNT_NOT_VALID();
        if (yieldSource == address(0) || account == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] =
            Execution({ target: yieldSource, value: 0, callData: abi.encodeCall(IERC4626.deposit, (amount, account)) });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, bytes memory data) external onlyExecutor {
        // store current balance
        outAmount = _getBalance(data);
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, bytes memory data) external onlyExecutor {
        outAmount = _getBalance(data) - outAmount;
        _performAccounting(data, superRegistry, outAmount, true);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(bytes memory data) private view returns (uint256) {
        address account = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 40, 20), 0);
        return IERC4626(yieldSource).balanceOf(account);
    }
}
