// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { ILedgerFees } from "../../interfaces/accounting/ILedgerFees.sol";
import { BaseFeeHelper } from "./BaseFeeHelper.sol";

/// @title DefaultFeeHelper
/// @author Superform Labs
/// @notice Default implementation of ILedgerFees
contract DefaultFeeHelper is ILedgerFees, BaseFeeHelper {
    function computeFees(uint256 costBasis, uint256 amountAssets, uint256 feePercent) external pure returns (uint256) {
        uint256 profit = amountAssets > costBasis ? amountAssets - costBasis : 0;
        if (profit == 0) return 0;  

        if (feePercent == 0) revert FEE_NOT_SET();
        // TODO: uncomment once we have a proper cost basis for 7540 vaults
        // if (costBasis == 0 && amountAssets > 0) revert COST_BASIS_NOT_VALID();

        // compute fee
        return (profit * feePercent) / 10_000;
    }
}


