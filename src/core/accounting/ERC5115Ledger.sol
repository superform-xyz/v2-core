// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { IYieldSourceOracle } from "../interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperLedgerConfiguration } from "../interfaces/accounting/ISuperLedgerConfiguration.sol";
import { BaseLedger } from "./BaseLedger.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title ERC5115Ledger
/// @author Superform Labs
/// @notice 5115 vaults ledger implementation
contract ERC5115Ledger is BaseLedger {
    constructor(address registry_) BaseLedger(registry_) { }

    function _getOutflowProcessVolume(uint256 amountSharesOrAssets, uint256 usedShares, uint256 pps, uint8 decimals) internal pure override returns(uint256 amountAssets)
    {
        return Math.mulDiv(usedShares, pps, 10 ** decimals);
    }
}
