// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { IMorpho } from "../../../../vendor/morpho/IMorpho.sol";~~~~~~~~~~~~~~~
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { ISuperHook } from "../../../interfaces/ISuperHook.sol";

/// @title MorphoBorrowHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         bytes4 yieldSourceOracleId = bytes4(BytesLib.slice(data, 0, 4), 0);
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 4, 20), 0);
/// @notice         address loanToken = BytesLib.toAddress(BytesLib.slice(data, 24, 20), 0);
/// @notice         address collateralToken = BytesLib.toAddress(BytesLib.slice(data, 44, 20), 0);
/// TODO: Does user specify oracle or we always use the same one?
/// @notice         address oracle = BytesLib.toAddress(BytesLib.slice(data, 64, 20), 0);
/// @notice         address irm = BytesLib.toAddress(BytesLib.slice(data, 84, 20), 0);
/// @notice         uint256 assets = BytesLib.toUint256(BytesLib.slice(data, 104, 32), 0);
/// @notice         uint256 lltv = BytesLib.toUint256(BytesLib.slice(data, 136, 32), 0);
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
