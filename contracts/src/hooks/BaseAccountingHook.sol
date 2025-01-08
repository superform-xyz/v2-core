// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { BytesLib } from "../libraries/BytesLib.sol";

import { ISuperRegistry } from "../interfaces/ISuperRegistry.sol";
import { ISuperLedger } from "../interfaces/accounting/ISuperLedger.sol";

abstract contract BaseAccountingHook {
    function _performAccounting(
        bytes memory data,
        ISuperRegistry superRegistry,
        uint256 amount,
        bool isInflow
    )
        internal
    {
        ISuperLedger ledger = ISuperLedger(superRegistry.getAddress(superRegistry.SUPER_LEDGER_ID()));

        address account = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        bytes32 yieldSourceId = BytesLib.toBytes32(BytesLib.slice(data, 20, 32), 0);
        address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 52, 20), 0);

        ledger.updateAccounting(account, yieldSource, yieldSourceId, isInflow, amount);
    }
}
