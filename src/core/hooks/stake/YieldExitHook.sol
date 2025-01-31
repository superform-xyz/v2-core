// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";

import { ISuperHook } from "../../interfaces/ISuperHook.sol";
import { IYieldExit } from "../../interfaces/vendors/IYieldExit.sol";

import { HookDataDecoder } from "../../libraries/HookDataDecoder.sol";

/// @title YieldExitHook
/// @dev can be used for Gearbox, Fluid
/// @dev data has the following structure
/// @notice         bytes32 yieldSourceOracleId = BytesLib.toBytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 32, 20), 0);
/// @notice         bool lockForSP = _decodeBool(data, 52);
contract YieldExitHook is BaseHook, ISuperHook {
    using HookDataDecoder for bytes;

    constructor(address registry_, address author_) BaseHook(registry_, author_, HookType.OUTFLOW) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(address, bytes memory data) external pure override returns (Execution[] memory executions) {
        address yieldSource = data.extractYieldSource();

        executions = new Execution[](1);
        executions[0] = Execution({ target: yieldSource, value: 0, callData: abi.encodeCall(IYieldExit.exit, ()) });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, bytes memory data) external onlyExecutor {
        outAmount = _getBalance(data);
        lockForSP = _decodeBool(data, 52);
        address yieldSource = data.extractYieldSource();
        spToken = IYieldExit(yieldSource).stakingToken();
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, bytes memory data) external onlyExecutor {
        outAmount = outAmount - _getBalance(data);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(bytes memory data) private view returns (uint256) {
        address account = data.extractAccount();
        address yieldSource = data.extractYieldSource();
        return IYieldExit(yieldSource).balanceOf(account);
    }
}
