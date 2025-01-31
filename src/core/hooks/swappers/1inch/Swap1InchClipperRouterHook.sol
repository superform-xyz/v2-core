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
    IClipperExchange,
    IERC20,
    Address
} from "../../../interfaces/vendors/1inch/I1InchAggregationRouterV6.sol";

/// @title Swap1InchClipperRouterHook
/// @dev data has the following structure
/// @notice  Swap1InchClipperRouterHookParams
contract Swap1InchClipperRouterHook is BaseHook, Base1InchHook, ISuperHook {
    constructor(
        address registry_,
        address author_,
        address aggregationRouter_
    )
        BaseHook(registry_, author_, HookType.NONACCOUNTING)
        Base1InchHook(aggregationRouter_)
    { }

    struct Swap1InchClipperRouterHookParams {
        bool usePrevHookAmount;
        uint256 msgValue;
        address clipperExchange;
        address srcToken;
        address dstToken;
        uint256 inputAmount;
        uint256 outputAmount;
        uint256 expiryWithFlags;
        bytes32 r;
        bytes32 vs;
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
        Swap1InchClipperRouterHookParams memory params;
        params.usePrevHookAmount = _decodeBool(data, 0);
        params.msgValue = BytesLib.toUint256(BytesLib.slice(data, 1, 32), 0);
        params.clipperExchange = BytesLib.toAddress(BytesLib.slice(data, 33, 20), 0);
        params.srcToken = BytesLib.toAddress(BytesLib.slice(data, 53, 20), 0);
        params.dstToken = BytesLib.toAddress(BytesLib.slice(data, 73, 20), 0);
        params.inputAmount = BytesLib.toUint256(BytesLib.slice(data, 93, 32), 0);
        params.outputAmount = BytesLib.toUint256(BytesLib.slice(data, 113, 32), 0);
        params.expiryWithFlags = BytesLib.toUint256(BytesLib.slice(data, 133, 32), 0);
        params.r = BytesLib.toBytes32(BytesLib.slice(data, 153, 32), 0);
        params.vs = BytesLib.toBytes32(BytesLib.slice(data, 173, 32), 0);

        if (params.usePrevHookAmount) {
            params.inputAmount = ISuperHookResult(prevHook).outAmount();
        }

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(aggregationRouter),
            value: params.msgValue,
            callData: abi.encodeCall(
                I1InchAggregationRouterV6.clipperSwapTo,
                (
                    IClipperExchange(params.clipperExchange),
                    payable(account),
                    Address.wrap(uint256(uint160(params.srcToken))),
                    IERC20(params.dstToken),
                    params.inputAmount,
                    params.outputAmount,
                    params.expiryWithFlags,
                    params.r,
                    params.vs
                )
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
        address dstToken = BytesLib.toAddress(BytesLib.slice(data, 73, 20), 0);
        return IERC20(dstToken).balanceOf(account);
    }
}
