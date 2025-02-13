// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

interface ILedgerFees {
    function computeFees(uint256 costBasis, uint256 amountAssets, uint256 feePercent) external view returns (uint256);
}
