// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

// Superform
import { IERC5115 } from "src/interfaces/vendors/vaults/5115/IERC5115.sol";

// Superform
import { BaseHook } from "src/hooks/BaseHook.sol";

import { ISuperHook, ISuperHookResult } from "src/interfaces/ISuperHook.sol";

contract Deposit5115VaultHook is BaseHook, ISuperHook {
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
        address vault = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        address receiver = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
        address tokenIn = BytesLib.toAddress(BytesLib.slice(data, 40, 20), 0);
        uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 60, 32), 0);
        uint256 minSharesOut = BytesLib.toUint256(BytesLib.slice(data, 92, 32), 0);
        bool depositFromInternalBalance = _decodeBool(data, 124);
        bool usePrevHookAmount = _decodeBool(data, 125);

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
        isInflow = true;
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(bytes memory data) private view returns (uint256) {
        address vault = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        address receiver = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
        return IERC4626(vault).balanceOf(receiver);
    }
}
