// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { Base1InchHook } from "./Base1InchHook.sol";

import { ISuperHook, ISuperHookMinimal } from "../../../interfaces/ISuperHook.sol";
import {
    I1InchAggregationRouterV6,
    IAggregationExecutor,
    Address,
    AddressLib
} from "../../../interfaces/vendors/1inch/I1InchAggregationRouterV6.sol";

/// @title Swap1InchUnoswapHook
/// @dev data has the following structure
/// @notice  Swap1InchUnoswapHookParams
contract Swap1InchUnoswapHook is BaseHook, Base1InchHook, ISuperHook {
    using AddressLib for Address;

    constructor(
        address registry_,
        address author_,
        address aggregationRouter_
    )
        BaseHook(registry_, author_, HookType.NONACCOUNTING)
        Base1InchHook(aggregationRouter_)
    { }

    struct Swap1InchUnoswapHookParams {
        bool usePrevHookAmount;
        uint256 msgValue;
        address recipient;
        address token;
        uint256 amount;
        uint256 minReturnAmount;
        address dex;
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
        Swap1InchUnoswapHookParams memory params = abi.decode(data, (Swap1InchUnoswapHookParams));

        if (params.usePrevHookAmount) {
            // TODO: how do we handle `minReturnAmount`?
            params.amount = ISuperHookMinimal(prevHook).outAmount();
        }

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(aggregationRouter),
            value: params.msgValue,
            callData: abi.encodeCall(
                I1InchAggregationRouterV6.unoswapTo,
                (
                    Address.wrap(uint256(uint160(params.recipient))),
                    Address.wrap(uint256(uint160(params.token))),
                    params.amount,
                    params.minReturnAmount,
                    Address.wrap(uint256(uint160(params.dex)))
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
        Swap1InchUnoswapHookParams memory params = abi.decode(data, (Swap1InchUnoswapHookParams));

        return IERC20(params.token).balanceOf(params.recipient);
    }
}
