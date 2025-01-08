// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { Base1InchHook } from "./Base1InchHook.sol";

import { ISuperHook, ISuperHookResult } from "../../../interfaces/ISuperHook.sol";
import {
    I1InchAggregationRouterV6,
    IAggregationExecutor
} from "../../../interfaces/vendors/1inch/I1InchAggregationRouterV6.sol";

/// @title Swap1InchGenericRouterHook
/// @dev data has the following structure
/// @notice  Swap1InchGenericRouterHookParams
contract Swap1InchGenericRouterHook is BaseHook, Base1InchHook, ISuperHook {
    constructor(
        address registry_,
        address author_,
        address aggregationRouter_
    )
        BaseHook(registry_, author_, HookType.NONACCOUNTING)
        Base1InchHook(aggregationRouter_)
    { }

    struct Swap1InchGenericRouterHookParams {
        bool usePrevHookAmount;
        uint256 msgValue;
        I1InchAggregationRouterV6.SwapDescription description;
        address aggregationExecutor;
        bytes permitData;
        bytes swapData;
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
        Swap1InchGenericRouterHookParams memory params = abi.decode(data, (Swap1InchGenericRouterHookParams));
        if (params.description.srcReceiver == address(0) || params.description.dstReceiver == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

        if (params.usePrevHookAmount) {
            // TODO: how do we handle `minReturnAmount`?
            params.description.amount = ISuperHookResult(prevHook).outAmount();
        }

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(aggregationRouter),
            value: params.msgValue,
            callData: abi.encodeCall(
                I1InchAggregationRouterV6.swap,
                (IAggregationExecutor(params.aggregationExecutor), params.description, params.permitData, params.swapData)
            )
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
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(bytes memory data) private view returns (uint256) {
        Swap1InchGenericRouterHookParams memory params = abi.decode(data, (Swap1InchGenericRouterHookParams));

        return IERC20(address(params.description.dstToken)).balanceOf(params.description.dstReceiver);
    }
}
