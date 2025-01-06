// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";

import { IYieldExit } from "../../interfaces/vendors/IYieldExit.sol";
import { ISuperHook, ISuperHookResult } from "../../interfaces/ISuperHook.sol";

// can be used for Gearbox, Fluid
contract YieldExitHook is BaseHook, ISuperHook {
    constructor(address registry_, address author_) BaseHook(registry_, author_) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(address, bytes memory data) external pure override returns (Execution[] memory executions) {
        address vault = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        //address account = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);

        executions = new Execution[](1);
        executions[0] = Execution({ target: vault, value: 0, callData: abi.encodeCall(IYieldExit.exit, ()) });
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
        outAmount = outAmount - _getBalance(data);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(bytes memory data) private view returns (uint256) {
        address vault = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        address account = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
        return IYieldExit(vault).balanceOf(account);
    }
}
