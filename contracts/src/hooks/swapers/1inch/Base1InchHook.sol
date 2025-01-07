// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import {
    I1InchAggregationRouterV6,
    IAggregationExecutor
} from "../../../interfaces/vendors/1inch/I1InchAggregationRouterV6.sol";

abstract contract Base1InchHook {
    I1InchAggregationRouterV6 public immutable aggregationRouter;

    constructor(address aggregationRouter_) {
        aggregationRouter = I1InchAggregationRouterV6(aggregationRouter_);
    }
}
