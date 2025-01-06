// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";

import { ISuperHook, ISuperHookResult } from "../../../interfaces/ISuperHook.sol";
import { IGearboxFarmingPool } from "../../../interfaces/vendors/gearbox/IGearboxFarmingPool.sol";

contract GearboxStakeHook is BaseHook, ISuperHook {
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
        address vault = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        //address account = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
        uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 40, 32), 0);
        bool usePrevHookAmount = _decodeBool(data, 72);

        if (vault == address(0)) revert ADDRESS_NOT_VALID();

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).outAmount();
        }

        executions = new Execution[](1);
        executions[0] =
            Execution({ target: vault, value: 0, callData: abi.encodeCall(IGearboxFarmingPool.deposit, (amount)) });
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
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(bytes memory data) private view returns (uint256) {
        address vault = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        address account = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
        return IGearboxFarmingPool(vault).balanceOf(account);
    }
}
