// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";


// Superform
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";
import { IERC5115 } from "src/interfaces/vendors/vaults/5115/IERC5115.sol";

// Superform
import { BaseHook } from "src/hooks/BaseHook.sol";
import { BaseAccountingHook } from "src/hooks/BaseAccountingHook.sol";

import { ISuperHook, ISuperHookResult } from "src/interfaces/ISuperHook.sol";

/// @title Deposit5115VaultHook
/// @dev data has the following structure
/// @notice         address user = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         address yieldSourceOracle = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 40, 20), 0);
/// @notice         address tokenIn = BytesLib.toAddress(BytesLib.slice(data, 60, 20), 0);
/// @notice         uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 80, 32), 0);
/// @notice         uint256 minSharesOut = BytesLib.toUint256(BytesLib.slice(data, 112, 32), 0);
/// @notice         bool depositFromInternalBalance = _decodeBool(data, 144);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 145);
contract Deposit5115VaultHook is BaseHook, BaseAccountingHook, ISuperHook {
    constructor(address registry_, address author_) BaseHook(registry_, author_) {
        isInflow = true;
    }

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
        address receiver = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        address vault = BytesLib.toAddress(BytesLib.slice(data, 40, 20), 0);
        address tokenIn = BytesLib.toAddress(BytesLib.slice(data, 60, 20), 0);
        uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 80, 32), 0);
        uint256 minSharesOut = BytesLib.toUint256(BytesLib.slice(data, 112, 32), 0);
        bool depositFromInternalBalance = _decodeBool(data, 144);
        bool usePrevHookAmount = _decodeBool(data, 145);

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).outAmount();
        }

        if (amount == 0) revert AMOUNT_NOT_VALID();
        if (vault == address(0) || receiver == address(0) || tokenIn == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: vault,
            value: 0,
            callData: abi.encodeCall(IERC5115.redeem, (receiver, amount, tokenIn, minSharesOut, depositFromInternalBalance))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, bytes memory data) external {
        outAmount = _getBalance(data);
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, bytes memory data) external {
        outAmount = _getBalance(data) - outAmount;
        _performAccounting(data, superRegistry, outAmount, true);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(bytes memory data) private view returns (uint256) {
        address receiver = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        address vault = BytesLib.toAddress(BytesLib.slice(data, 40, 20), 0);
        return IERC4626(vault).balanceOf(receiver);
    }
}
