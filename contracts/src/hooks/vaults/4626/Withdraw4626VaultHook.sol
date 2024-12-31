// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

// Superform
import { BaseHook } from "src/hooks/BaseHook.sol";

import { ISuperHook, ISuperHookResult } from "src/interfaces/ISuperHook.sol";

contract Withdraw4626VaultHook is BaseHook, ISuperHook {
    constructor(address registry_, address author_) BaseHook(registry_, author_) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(address prevHook, bytes memory data) external view override returns (Execution[] memory executions) {
        address vault = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        address receiver = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
        address owner = BytesLib.toAddress(BytesLib.slice(data, 40, 20), 0);
        uint256 shares = BytesLib.toUint256(BytesLib.slice(data, 60, 32), 0);
        bool usePrevHookAmount = _decodeBool(data, 92);

        if (usePrevHookAmount) {
            shares = ISuperHookResult(prevHook).outAmount();
        } 

        if (shares == 0) revert AMOUNT_NOT_VALID();
        if (vault == address(0) || owner == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] =
            Execution({ target: vault, value: 0, callData: abi.encodeCall(IERC4626.redeem, (shares, receiver, owner)) });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, bytes memory data) external
    {
        outAmount = _getShareBalance(data);
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, bytes memory data) external
    {
        outAmount = outAmount - _getShareBalance(data);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getShareBalance(bytes memory data) private view returns (uint256) {
        address vault = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        address receiver = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
        return IERC4626(vault).balanceOf(receiver);
    }
}
