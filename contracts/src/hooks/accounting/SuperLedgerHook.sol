// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { ISuperLedger } from "../../interfaces/accounting/ISuperLedger.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";

import { ISuperHook, ISuperHookResult } from "../../interfaces/ISuperHook.sol";

contract SuperLedgerHook is BaseHook, ISuperHook {
    constructor(address registry_, address author_) BaseHook(registry_, author_) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(
        address prevHook,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        address user = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        address yieldSourceOracle = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
        address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 40, 20), 0);

        /// @dev WARNING this must be on shares
        uint256 amount = ISuperHookResult(prevHook).outAmount();
        bool isInflow = ISuperHookResult(prevHook).isInflow();

        if (amount == 0) {
            revert AMOUNT_NOT_VALID();
        }
        if (user == address(0) || yieldSourceOracle == address(0) || yieldSource == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

        executions = new Execution[](1);
        executions[0] = Execution({
            target: superRegistry.getAddress(superRegistry.SUPER_LEDGER_ID()),
            value: 0,
            callData: abi.encodeCall(
                ISuperLedger.updateAccounting, (user, yieldSourceOracle, yieldSource, isInflow, amount)
            )
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, bytes memory) external { }

    /// @inheritdoc ISuperHook
    function postExecute(address, bytes memory) external { }
}
