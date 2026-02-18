// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IPendlePTAmortizedOracleV2 } from "../../src/vendor/pendle/IPendlePTAmortizedOracleV2.sol";

/// @notice Mock V2 oracle that records calls for verification
/// @dev Used for testing RecordPurchase V2 hooks
/// @dev V2 difference: recordPurchase takes twapDuration instead of sySpent
contract MockPendlePTAmortizedOracleV2 is IPendlePTAmortizedOracleV2 {
    struct PurchaseRecord {
        address caller;
        address market;
        uint256 ptBought;
        uint32 twapDuration;
        uint256 timestamp;
    }

    struct RedemptionRecord {
        address caller;
        address market;
        uint256 ptSold;
        uint256 timestamp;
    }

    PurchaseRecord[] public purchases;
    RedemptionRecord[] public redemptions;

    mapping(address => mapping(address => uint256)) public bookValueStorage;
    mapping(address => mapping(address => bool)) public positionExists;

    /// @notice V2: recordPurchase includes twapDuration parameter
    function recordPurchase(address market, uint256 ptBought, uint32 twapDuration) external override {
        purchases.push(
            PurchaseRecord({
                caller: msg.sender,
                market: market,
                ptBought: ptBought,
                twapDuration: twapDuration,
                timestamp: block.timestamp
            })
        );
        positionExists[msg.sender][market] = true;
        // Simulate ~90% book value (like PT rate would calculate)
        bookValueStorage[msg.sender][market] += (ptBought * 9) / 10;
    }

    function recordRedemption(address market, uint256 ptSold) external override {
        redemptions.push(
            RedemptionRecord({ caller: msg.sender, market: market, ptSold: ptSold, timestamp: block.timestamp })
        );
    }

    function getBookValue(address strategy, address market) external view override returns (uint256) {
        return bookValueStorage[strategy][market];
    }

    function hasPosition(address strategy, address market) external view override returns (bool) {
        return positionExists[strategy][market];
    }

    function getPurchaseCount() external view returns (uint256) {
        return purchases.length;
    }

    function getRedemptionCount() external view returns (uint256) {
        return redemptions.length;
    }

    function getLastPurchase() external view returns (PurchaseRecord memory) {
        require(purchases.length > 0, "No purchases");
        return purchases[purchases.length - 1];
    }

    function getLastRedemption() external view returns (RedemptionRecord memory) {
        require(redemptions.length > 0, "No redemptions");
        return redemptions[redemptions.length - 1];
    }
}
