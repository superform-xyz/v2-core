// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
// superform
import { BaseLedger } from "./BaseLedger.sol";

/// @title ERC5115Ledger
/// @author Superform Labs
/// @notice 5115 vaults ledger implementation
contract ERC5115Ledger is BaseLedger {
    constructor(
        address ledgerConfiguration_,
        address[] memory allowedExecutors_
    )
        BaseLedger(ledgerConfiguration_, allowedExecutors_)
    { }

    function _getOutflowProcessVolume(
        uint256,
        uint256 usedShares,
        uint256 pps,
        uint8 decimals
    )
        internal
        pure
        override
        returns (uint256)
    {
        return Math.mulDiv(usedShares, pps, 10 ** decimals);
    }
}
