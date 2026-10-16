// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IPancakeSwapRouter
/// @author Superform Labs
/// @notice Minimal interface for the PancakeSwap aggregation router (the on-chain, synchronous surface
///         behind "PancakeSwap X"). The backend fetches calldata from the aggregator API
///         (GET /v2/quote -> POST /v1/calldata); hooks forward it to this router in a single transaction.
/// @dev Only `swapExactIn` is modelled — the plain, recipient-paying entrypoint our hooks target. The
///      router also exposes `swapExactInWithRefundTo` (extra refundTo arg) and `swapWrap`, which the hooks
///      intentionally do NOT support (selector is validated). The input amount lives entirely in
///      `routesAmount` (summed across routes); `RouterPath.rawData` packs pool address + weight + reverse,
///      not amounts, so scaling `routesAmount` scales a route proportionally without touching `rawData`.
interface IPancakeSwapRouter {
    /// @notice Static request header: tokens, slippage floor and deadline
    struct BaseExactInRequest {
        address inputToken;
        address outputToken;
        uint256 minOutputAmount;
        uint256 deadline;
    }

    /// @notice One hop's routing data. `rawData[i]` packs (poolAddress, weight-in-bps, reverse);
    ///         `weight` is a ratio of the route's running amount, so it is scale-invariant.
    struct RouterPath {
        uint256[] mixAdapters;
        address[] assetTo;
        uint256[] rawData;
        bytes[] extraData;
        address fromToken;
    }

    /// @notice swapExactIn(uint256,(address,address,uint256,uint256),uint256[],
    ///         (uint256[],address[],uint256[],bytes[],address)[][],uint256,address) == 0xedad400c
    /// @param orderId Off-chain order id (opaque to the hook)
    /// @param request Token pair, min output and deadline
    /// @param routesAmount Per-route input amount; the total input is the sum
    /// @param routes Per-route hop paths
    /// @param feeConfig Packed fee/surplus config (0 = none)
    /// @param recipient Where the output is sent (must be the Superform account)
    /// @return outputAmtReceived Output token amount received
    function swapExactIn(
        uint256 orderId,
        BaseExactInRequest calldata request,
        uint256[] calldata routesAmount,
        RouterPath[][] calldata routes,
        uint256 feeConfig,
        address recipient
    )
        external
        payable
        returns (uint256 outputAmtReceived);
}
