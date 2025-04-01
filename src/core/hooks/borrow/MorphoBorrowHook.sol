// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { ISuperHook } from "../../../interfaces/ISuperHook.sol";

/// @title MorphoBorrowHook
/// @author Superform Labs
/// @dev data has the following structure


contract MorphoBorrowHook is BaseHook, ISuperHook {
    constructor(address registry_) BaseHook(registry_, HookType.NONACCOUNTING) { }

    /*//////////////////////////////////////////////////////////////
                              VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
}
