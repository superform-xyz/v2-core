// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { ILedgerFees } from "../../interfaces/accounting/ILedgerFees.sol";
import { BaseFeeHelper } from "./BaseFeeHelper.sol";

/// @title PendleFeeHelper
/// @author Superform Labs
/// @notice Fee helper for Pendle valts
contract PendleFeeHelper is ILedgerFees, BaseFeeHelper {
    function computeFees(uint256, uint256 amountAssets, uint256 feePercent) external pure returns (uint256) {
        return (amountAssets * feePercent) / 10_000; // TODO: decide how we handle the fees
    }
}


