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
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NOT_AUTHORIZED();

    modifier onlyExecutor() {
        if (_getAddress(superRegistry.SUPER_EXECUTOR_ID()) != msg.sender) revert NOT_AUTHORIZED();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(
        address,
        bytes memory
    )
        external
        pure
        override
        returns (Execution[] memory executions)
    {
        return new Execution[](0);
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, bytes memory) external pure { }

    /// @inheritdoc ISuperHook
    function postExecute(address prevHook, bytes memory data) external onlyExecutor {
        ISuperLedger ledger = ISuperLedger(superRegistry.getAddress(superRegistry.SUPER_LEDGER_ID()));

        address user = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        address yieldSourceOracle = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
        address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 40, 20), 0);
         /// @dev WARNING this must be on shares
        uint256 amount = ISuperHookResult(prevHook).outAmount();
        bool isInflow = ISuperHookResult(prevHook).isInflow();

        ledger.updateAccounting(user, yieldSourceOracle, yieldSource, isInflow, amount);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getAddress(bytes32 id_) private view returns (address) {
        return superRegistry.getAddress(id_);
    }
}
