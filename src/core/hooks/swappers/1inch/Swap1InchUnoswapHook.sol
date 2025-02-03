// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { Base1InchHook } from "./Base1InchHook.sol";

import { ISuperHook, ISuperHookResult } from "../../../interfaces/ISuperHook.sol";
import {
    I1InchAggregationRouterV6,
    IAggregationExecutor,
    Address,
    AddressLib
} from "../../../interfaces/vendors/1inch/I1InchAggregationRouterV6.sol";

/// @title Swap1InchUnoswapHook
/// @dev data has the following structure
/// @notice  Swap1InchUnoswapHookParams
/// @notice         bool usePrevHookAmount = _decodeBool(data, 0);
/// @notice         uint256 msgValue = BytesLib.toUint256(BytesLib.slice(data, 1, 32), 0);
/// @notice         address token = BytesLib.toAddress(BytesLib.slice(data, 33, 20), 0);
/// @notice         uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 53, 32), 0);
/// @notice         uint256 minReturnAmount = BytesLib.toUint256(BytesLib.slice(data, 85, 32), 0);
/// @notice         address dex = BytesLib.toAddress(BytesLib.slice(data, 117, 20), 0);
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
        address account,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        Swap1InchUnoswapHookParams memory params;
        params.usePrevHookAmount = _decodeBool(data, 0);
        params.msgValue = BytesLib.toUint256(BytesLib.slice(data, 1, 32), 0);
        params.token = BytesLib.toAddress(BytesLib.slice(data, 33, 20), 0);
        params.amount = BytesLib.toUint256(BytesLib.slice(data, 53, 32), 0);
        params.minReturnAmount = BytesLib.toUint256(BytesLib.slice(data, 85, 32), 0);
        params.dex = BytesLib.toAddress(BytesLib.slice(data, 117, 20), 0);

        if (params.usePrevHookAmount) {
            params.amount = ISuperHookResult(prevHook).outAmount();
        }

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(aggregationRouter),
            value: params.msgValue,
            callData: abi.encodeCall(
                I1InchAggregationRouterV6.unoswapTo,
                (
                    Address.wrap(uint256(uint160(account))),
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
        address token = BytesLib.toAddress(BytesLib.slice(data, 33, 20), 0);
        return IERC20(token).balanceOf(account);
    }
}
