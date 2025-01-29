// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";

import { ISuperHook } from "../../../interfaces/ISuperHook.sol";
import { ISomelierCellarStaking } from "../../../interfaces/vendors/somelier/ISomelierCellarStaking.sol";

import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

/// @title SomelierUnstakeAllHook
/// @dev data has the following structure
/// @notice         address account = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         bytes32 yieldSourceOracleId = BytesLib.toBytes32(BytesLib.slice(data, 20, 32), 0);
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 52, 20), 0);
/// @notice         bool lockForSP = _decodeBool(data, 72);
contract SomelierUnstakeAllHook is BaseHook, ISuperHook {
    using HookDataDecoder for bytes;

    constructor(address registry_, address author_) BaseHook(registry_, author_, HookType.OUTFLOW) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(address, bytes memory data) external pure override returns (Execution[] memory executions) {
        address yieldSource = data.extractYieldSource();

        if (yieldSource == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] =
            Execution({ target: yieldSource, value: 0, callData: abi.encodeCall(ISomelierCellarStaking.unstakeAll, ()) });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, bytes memory data) external onlyExecutor {
        outAmount = _getBalance(data);
        lockForSP = _decodeBool(data, 72);
        address yieldSource = data.extractYieldSource();
        spToken = ISomelierCellarStaking(yieldSource).stakingToken();
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, bytes memory data) external onlyExecutor {
        outAmount = _getBalance(data) - outAmount;
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(bytes memory data) private view returns (uint256) {
        address account = data.extractAccount();
        address yieldSource = data.extractYieldSource();

        ISomelierCellarStaking.UserStake[] memory stakes = ISomelierCellarStaking(yieldSource).getUserStakes(account);
        uint256 total;
        for (uint256 i = 0; i < stakes.length;) {
            total += stakes[i].amount;
            unchecked {
                ++i;
            }
        }
        return total;
    }
}
