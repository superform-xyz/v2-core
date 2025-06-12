// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import {BytesLib} from "../../../../vendor/BytesLib.sol";
import {Execution} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import {IFluidLendingStakingRewards} from "../../../../vendor/fluid/IFluidLendingStakingRewards.sol";

// Superform
import {
    ISuperHookResultOutflow,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware,
    ISuperHookInspector
} from "../../../interfaces/ISuperHook.sol";
import {BaseHook} from "../../BaseHook.sol";
import {HookSubTypes} from "../../../libraries/HookSubTypes.sol";
import {BaseClaimRewardHook} from "../BaseClaimRewardHook.sol";

/// @title FluidClaimRewardHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address stakingRewards = BytesLib.toAddress(data, 0);
contract FluidClaimRewardHook is
    BaseHook,
    BaseClaimRewardHook,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware,
    ISuperHookInspector
{
    constructor() BaseHook(HookType.OUTFLOW, HookSubTypes.CLAIM) {}

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc BaseHook
    function _buildHookExecutions(address, address, bytes calldata data)
        internal
        pure
        override
        returns (Execution[] memory executions)
    {
        address stakingRewards = BytesLib.toAddress(data, 0);
        if (stakingRewards == address(0)) revert ADDRESS_NOT_VALID();

        return _build(stakingRewards, abi.encodeCall(IFluidLendingStakingRewards.getReward, ()));
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmount(bytes memory) external pure returns (uint256) {
        return 0;
    }

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory) external pure returns (bool) {
        return false;
    }

    /// @inheritdoc ISuperHookOutflow
    function replaceCalldataAmount(bytes memory data, uint256) external pure returns (bytes memory) {
        return data;
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure returns (bytes memory) {
        return abi.encodePacked(BytesLib.toAddress(data, 0));
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address, bytes calldata data) internal override {
        asset = BytesLib.toAddress(data, 20);
        if (asset == address(0)) revert ASSET_ZERO_ADDRESS();

        outAmount = _getBalance(data);
    }

    function _postExecute(address, address, bytes calldata data) internal override {
        outAmount = _getBalance(data) - outAmount;
    }
}
