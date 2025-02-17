// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Superform
import { IYieldSourceOracle } from "../interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperRegistry } from "../interfaces/ISuperRegistry.sol";
import { ISuperLedgerConfiguration } from "../interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperLedger, ISuperLedgerData } from "../interfaces/accounting/ISuperLedger.sol";

import { SuperLedgerConfiguration } from "./SuperLedgerConfiguration.sol";

abstract contract BaseLedger is ISuperLedgerData {
    using SafeERC20 for IERC20;

    SuperLedgerConfiguration public immutable superLedgerConfiguration;

    /// @notice Tracks user's ledger entries for each yield source address
    mapping(address user => mapping(address yieldSource => Ledger ledger)) internal userLedger;

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(address superLedgerConfiguration_) {
        if (superLedgerConfiguration_ == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();
        superLedgerConfiguration = SuperLedgerConfiguration(superLedgerConfiguration_);
    }

    modifier onlyExecutor() {
        if (_getAddress(keccak256("SUPER_EXECUTOR_ID")) != msg.sender) revert NOT_AUTHORIZED();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _getLedger(
        address user,
        address yieldSource
    )
        internal
        virtual
        view
        returns (LedgerEntry[] memory entries, uint256 unconsumedEntries)
    {
        Ledger storage ledger = userLedger[user][yieldSource];
        return (ledger.entries, ledger.unconsumedEntries);
    }

    function _getAddress(bytes32 id_) internal view returns (address) {
        ISuperRegistry registry = ISuperRegistry(superLedgerConfiguration.superRegistry());
        return registry.getAddress(id_);
    }
}
