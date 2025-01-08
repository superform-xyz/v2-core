// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "src/hooks/BaseHook.sol";
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
        address payable recipient;
        address srcToken;
        address dstToken;
        uint256 inputAmount;
        uint256 outputAmount;
        uint256 expiryWithFlags;
        bytes32 r;
        bytes32 vs;
        bytes permitData;
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
        Swap1InchClipperRouterHookParams memory params = abi.decode(data, (Swap1InchClipperRouterHookParams));

        if (params.usePrevHookAmount) {
            // TODO: how do we handle `outputAmount`?
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
                    params.recipient,
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
        Swap1InchClipperRouterHookParams memory params = abi.decode(data, (Swap1InchClipperRouterHookParams));

        return IERC20(address(params.dstToken)).balanceOf(params.recipient);
    }
}
