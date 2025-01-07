// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { BytesLib } from "../libraries/BytesLib.sol";

import { ISuperRegistry } from "../interfaces/ISuperRegistry.sol";
import { ISuperLedger } from "../interfaces/accounting/ISuperLedger.sol";


abstract contract BaseAccountingHook {
    function _performAccounting(bytes memory data, ISuperRegistry superRegistry, uint256 amount, bool isInflow) internal {
        ISuperLedger ledger = ISuperLedger(superRegistry.getAddress(superRegistry.SUPER_LEDGER_ID()));

        address user = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        address yieldSourceOracle = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
        address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 40, 20), 0);

        ledger.updateAccounting(user, yieldSourceOracle, yieldSource, isInflow, amount);
    }
}
