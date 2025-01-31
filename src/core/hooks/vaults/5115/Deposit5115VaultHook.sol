// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

// Superform
import { IERC5115 } from "../../../interfaces/vendors/vaults/5115/IERC5115.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";

import { ISuperHook, ISuperHookResult } from "../../../interfaces/ISuperHook.sol";

import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

/// @title Deposit5115VaultHook
/// @dev data has the following structure
/// @notice         bytes32 yieldSourceOracleId = BytesLib.toBytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 32, 20), 0);
/// @notice         address tokenIn = BytesLib.toAddress(BytesLib.slice(data, 52, 20), 0);
/// @notice         uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 72, 32), 0);
/// @notice         uint256 minSharesOut = BytesLib.toUint256(BytesLib.slice(data, 104, 32), 0);
/// @notice         bool depositFromInternalBalance = _decodeBool(data, 136);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 137);
/// @notice         bool lockForSP = _decodeBool(data, 138);
contract Deposit5115VaultHook is BaseHook, ISuperHook {
    using HookDataDecoder for bytes;

    constructor(address registry_, address author_) BaseHook(registry_, author_, HookType.INFLOW) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(
        address prevHook,
        address account,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        address yieldSource = data.extractYieldSource();
        address tokenIn = BytesLib.toAddress(BytesLib.slice(data, 52, 20), 0);
        uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 72, 32), 0);
        uint256 minSharesOut = BytesLib.toUint256(BytesLib.slice(data, 104, 32), 0);
        bool depositFromInternalBalance = _decodeBool(data, 136);
        bool usePrevHookAmount = _decodeBool(data, 137);

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).outAmount();
        }

        if (amount == 0) revert AMOUNT_NOT_VALID();
        if (yieldSource == address(0) || account == address(0) || tokenIn == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IERC5115.redeem, (account, amount, tokenIn, minSharesOut, depositFromInternalBalance))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, bytes memory data) external onlyExecutor {
        outAmount = _getBalance(data);
        lockForSP = _decodeBool(data, 138);
        spToken = data.extractYieldSource();
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, bytes memory data) external onlyExecutor {
        outAmount = _getBalance(data) - outAmount;
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(address account, bytes memory data) private view returns (uint256) {
        address yieldSource = data.extractYieldSource();
        return IERC4626(yieldSource).balanceOf(account);
    }
}
