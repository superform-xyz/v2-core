// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

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

    // forgefmt: disable-start
    address public assetOut;
    // forgefmt: disable-end

    constructor(address registry_, address author_) BaseHook(registry_, author_, ISuperHook.HookType.OUTFLOW) { }
    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHook
    function build(address, bytes memory data) external pure override returns (Execution[] memory executions) {
        address yieldSource = data.extractYieldSource();

        if (yieldSource == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(ISomelierCellarStaking.unstakeAll, ())
        });
    }

    /// @inheritdoc ISuperHook
    function preExecute(address, bytes memory data) external onlyExecutor {
        address yieldSource = data.extractYieldSource();
        assetOut = ISomelierCellarStaking(yieldSource).stakingToken();
        outAmount = _getBalance(data);
        lockForSP = _decodeBool(data, 72);
        /// @dev in Somelier, the staking token doesn't exist because no shares are minted.
        spToken = address(0);
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, bytes memory data) external onlyExecutor {
        outAmount = _getBalance(data) - outAmount;
    }

    function _getBalance(bytes memory data) private view returns (uint256) {
        address account = data.extractAccount();
        return IERC20(assetOut).balanceOf(account);
    }
}
