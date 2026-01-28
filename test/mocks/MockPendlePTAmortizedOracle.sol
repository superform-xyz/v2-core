// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IPendlePTAmortizedOracle } from "../../src/vendor/pendle/IPendlePTAmortizedOracle.sol";

/// @notice Mock oracle that records calls for verification
/// @dev Used for testing RecordPurchase and RecordRedemption hooks
contract MockPendlePTAmortizedOracle is IPendlePTAmortizedOracle {
    struct PurchaseRecord {
        address caller;
        address market;
        uint256 sySpent;
        uint256 ptAmount;
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

    function recordPurchase(address market, uint256 sySpent, uint256 ptAmount) external override {
        purchases.push(
            PurchaseRecord({
                caller: msg.sender,
                market: market,
                sySpent: sySpent,
                ptAmount: ptAmount,
                timestamp: block.timestamp
            })
        );
        positionExists[msg.sender][market] = true;
        bookValueStorage[msg.sender][market] += sySpent;
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
