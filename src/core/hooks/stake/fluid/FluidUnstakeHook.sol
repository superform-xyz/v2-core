// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";

import { ISuperHook, ISuperHookResultOutflow, ISuperHookInflowOutflow } from "../../../interfaces/ISuperHook.sol";
import { IFluidLendingStakingRewards } from "../../../interfaces/vendors/fluid/IFluidLendingStakingRewards.sol";

import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";


/// @title FluidUnstakeHook
/// @dev data has the following structure
/// @notice         bytes32 yieldSourceOracleId = BytesLib.toBytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 32, 20), 0);
/// @notice         uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 52, 32), 0);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 84);
/// @notice         bool lockForSP = _decodeBool(data, 85);
contract FluidUnstakeHook is BaseHook, ISuperHook, ISuperHookInflowOutflow {
    using HookDataDecoder for bytes;

    uint256 private constant AMOUNT_POSITION = 52;
    constructor(address registry_, address author_) BaseHook(registry_, author_, HookType.OUTFLOW) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
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
        bool usePrevHookAmount = _decodeBool(data, 84);

        if (yieldSource == address(0)) revert ADDRESS_NOT_VALID();

        if (usePrevHookAmount) {
            amount = ISuperHookResultOutflow(prevHook).outAmount();
        }

        executions = new Execution[](1);
        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IFluidLendingStakingRewards.withdraw, (amount))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, address account, bytes memory data) external onlyExecutor {
        asset = IFluidLendingStakingRewards(data.extractYieldSource()).stakingToken();
        outAmount = _getBalance(account, data);
        lockForSP = _decodeBool(data, 85);
        /// @dev in Fluid, the share token doesn't exist because no shares are minted so we don't assign a spToken
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, address account, bytes memory data) external onlyExecutor {
        outAmount = _getBalance(account, data) - outAmount;
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmount(bytes memory data) external pure returns (uint256) {
        return _decodeAmount(data);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _decodeAmount(bytes memory data) private pure returns (uint256) {
        return BytesLib.toUint256(BytesLib.slice(data, AMOUNT_POSITION, 32), 0);
    }
    
    function _getBalance(address account, bytes memory) private view returns (uint256) {
        return IFluidLendingStakingRewards(asset).balanceOf(account);
    }
}
