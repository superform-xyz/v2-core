// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

// external
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../../src/core/hooks/BaseHook.sol";

import { ISuperHookResult, ISuperHookInflowOutflow } from "../../../src/core/interfaces/ISuperHook.sol";
import { IFluidLendingStakingRewards } from "../../../src/vendor/fluid/IFluidLendingStakingRewards.sol";

import { HookDataDecoder } from "../../../src/core/libraries/HookDataDecoder.sol";

/// @title FluidStakeWithPermitHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         bytes4 yieldSourceOracleId = bytes4(BytesLib.slice(data, 0, 4), 0);
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 4, 20), 0);
/// @notice         uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 24, 32), 0);
/// @notice         uint256 deadline = BytesLib.toUint256(BytesLib.slice(data, 56, 32), 0);
/// @notice         uint8 v = BytesLib.toUint8(BytesLib.slice(data, 88, 1), 0);
/// @notice         bytes32 r = BytesLib.toBytes32(BytesLib.slice(data, 89, 32), 0);
/// @notice         bytes32 s = BytesLib.toBytes32(BytesLib.slice(data, 121, 32), 0);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 153);
contract FluidStakeWithPermitHook is BaseHook, ISuperHookInflowOutflow {
    using HookDataDecoder for bytes;

    uint256 private constant AMOUNT_POSITION = 24;

    constructor() BaseHook(HookType.INFLOW, "Stake") { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function build(
        address prevHook,
        address,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        address yieldSource = data.extractYieldSource();
        uint256 amount = _decodeAmount(data);
        uint256 deadline = BytesLib.toUint256(BytesLib.slice(data, 56, 32), 0);
        uint8 v = BytesLib.toUint8(BytesLib.slice(data, 88, 1), 0);
        bytes32 r = BytesLib.toBytes32(BytesLib.slice(data, 89, 32), 0);
        bytes32 s = BytesLib.toBytes32(BytesLib.slice(data, 121, 32), 0);
        bool usePrevHookAmount = _decodeBool(data, 153);

        if (yieldSource == address(0)) revert ADDRESS_NOT_VALID();

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).outAmount();
        }

        executions = new Execution[](1);
        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IFluidLendingStakingRewards.stakeWithPermit, (amount, deadline, v, r, s))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmount(bytes memory data) external pure returns (uint256) {
        return _decodeAmount(data);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        outAmount = _getBalance(account, data);
        /// @dev in Fluid, the share token doesn't exist because no shares are minted so we don't assign a spToken
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        outAmount = _getBalance(account, data) - outAmount;
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _decodeAmount(bytes memory data) private pure returns (uint256) {
        return BytesLib.toUint256(BytesLib.slice(data, AMOUNT_POSITION, 32), 0);
    }

    function _getBalance(address account, bytes memory data) private view returns (uint256) {
        return IFluidLendingStakingRewards(data.extractYieldSource()).balanceOf(account);
    }
}
