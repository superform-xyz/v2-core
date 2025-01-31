// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { Base1InchHook } from "./Base1InchHook.sol";

import { ISuperHook, ISuperHookResult } from "../../../interfaces/ISuperHook.sol";
import {
    I1InchAggregationRouterV6,
    IAggregationExecutor,
    IERC20
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
        address account,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        Swap1InchGenericRouterHookParams memory params;
        params.usePrevHookAmount = _decodeBool(data, 0);
        params.msgValue = BytesLib.toUint256(BytesLib.slice(data, 1, 32), 0);

        params.description.srcToken = IERC20(BytesLib.toAddress(BytesLib.slice(data, 33, 20), 0));
        params.description.dstToken = IERC20(BytesLib.toAddress(BytesLib.slice(data, 53, 20), 0));
        params.description.srcReceiver = payable(account);
        params.description.srcReceiver = payable(account);
        params.description.amount = BytesLib.toUint256(BytesLib.slice(data, 73, 32), 0);
        params.description.minReturnAmount = BytesLib.toUint256(BytesLib.slice(data, 105, 32), 0);
        params.description.flags = BytesLib.toUint256(BytesLib.slice(data, 137, 32), 0);
        params.aggregationExecutor = BytesLib.toAddress(BytesLib.slice(data, 157, 20), 0);

        uint256 permitDataLength = BytesLib.toUint256(BytesLib.slice(data, 177, 32), 0);
        params.permitData = BytesLib.slice(data, 209, permitDataLength);

        uint256 swapDataOffset = 209 + permitDataLength;
        params.swapData = BytesLib.slice(data, swapDataOffset, data.length - swapDataOffset);


        if (params.description.srcReceiver == address(0) || params.description.dstReceiver == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

        if (params.usePrevHookAmount) {
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
    function preExecute(address, address account, bytes memory data) external {
        outAmount = _getBalance(account, data);
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, address account, bytes memory data) external {
        outAmount = _getBalance(account, data) - outAmount;
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(address account, bytes memory data) private view returns (uint256) {
        address dstToken = BytesLib.toAddress(BytesLib.slice(data, 53, 20), 0);
        return IERC20(dstToken).balanceOf(account);
    }
}
