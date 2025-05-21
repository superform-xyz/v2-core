// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
// superform
import {BaseLedger} from "./BaseLedger.sol";

/// @title ERC5115Ledger
/// @author Superform Labs
/// @notice Specialized ledger implementation for ERC-5115 vaults
/// @dev Extends BaseLedger to properly handle accounting for ERC-5115 (Standardized Yield) tokens
///      These tokens follow the Pendle StandardizedYield interface where the exchange rate
///      is normalized to 18 decimals
contract ERC5115Ledger is BaseLedger {
    /// @notice Initializes the ERC5115Ledger with configuration and executor permissions
    /// @param ledgerConfiguration_ Address of the SuperLedgerConfiguration contract
    /// @param allowedExecutors_ Array of addresses authorized to execute accounting operations
    constructor(address ledgerConfiguration_, address[] memory allowedExecutors_)
        BaseLedger(ledgerConfiguration_, allowedExecutors_)
    {}

    /// @notice Calculates the asset volume for outflow processing in ERC-5115 vaults
    /// @dev Overrides the base implementation to handle ERC-5115 specific price conversion
    ///      Converts share amount to asset amount using price per share from the oracle
    /// @param usedShares Amount of shares being withdrawn
    /// @param pps Current price per share from the oracle
    /// @param decimals Decimal precision of the yield source
    /// @return The asset amount equivalent to the withdrawn shares
    function _getOutflowProcessVolume(uint256, /* notUsed */ uint256 usedShares, uint256 pps, uint8 decimals)
        internal
        pure
        override
        returns (uint256)
    {
        return Math.mulDiv(usedShares, pps, 10 ** decimals);
    }
}
