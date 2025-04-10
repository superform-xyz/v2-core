// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IGearboxFarmingPool } from "../../../../vendor/gearbox/IGearboxFarmingPool.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseClaimRewardHook } from "../BaseClaimRewardHook.sol";

/// @title GearboxClaimRewardHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address farmingPool = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
contract GearboxClaimRewardHook is BaseHook, BaseClaimRewardHook {
    constructor(address registry_) BaseHook(registry_, HookType.NONACCOUNTING) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function build(
        address,
        address,
        bytes memory data
    )
        external
        pure
        override
        returns (Execution[] memory executions)
    {
        address farmingPool = BytesLib.toAddress(data, 0);
        if (farmingPool == address(0)) revert ADDRESS_NOT_VALID();

        return _build(farmingPool, abi.encodeCall(IGearboxFarmingPool.claim, ()));
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address, bytes calldata data) internal override {
        outAmount = _getBalance(data);
    }

    function _postExecute(address, address, bytes calldata data) internal override {
        outAmount = _getBalance(data) - outAmount;
    }
}
