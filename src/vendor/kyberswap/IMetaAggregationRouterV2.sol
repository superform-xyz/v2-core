// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IMetaAggregationRouterV2 {
    struct SwapDescriptionV2 {
        IERC20 srcToken;
        IERC20 dstToken;
        address[] srcReceivers;
        uint256[] srcAmounts;
        address[] feeReceivers;
        uint256[] feeAmounts;
        address dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
        bytes permit;
    }

    /// @dev Field ordering verified from on-chain function selector 0xe21fd0e9
    /// @dev clientData comes BEFORE desc in ABI encoding
    struct SwapExecutionParams {
        address callTarget;
        address approveTarget;
        bytes clientData;
        SwapDescriptionV2 desc;
        bytes targetData;
    }

    /// @notice Execute a token swap through KyberSwap aggregator
    /// @param execution All parameters for the swap execution
    /// @return returnAmount The actual amount of destination tokens received
    /// @return gasUsed The gas consumed by the swap execution
    function swap(SwapExecutionParams calldata execution)
        external
        payable
        returns (uint256 returnAmount, uint256 gasUsed);
}
