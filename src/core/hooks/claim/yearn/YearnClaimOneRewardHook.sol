// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IYearnStakingRewardsMulti } from "../../../../vendor/yearn/IYearnStakingRewardsMulti.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseClaimRewardHook } from "../BaseClaimRewardHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import {
    ISuperHook,
    ISuperHookResultOutflow,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware,
    ISuperHookInspector
} from "../../../interfaces/ISuperHook.sol";

/// @title YearnClaimOneRewardHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         address rewardToken = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
contract YearnClaimOneRewardHook is
    BaseHook,
    BaseClaimRewardHook,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware,
    ISuperHookInspector
{
    constructor() BaseHook(HookType.OUTFLOW, HookSubTypes.CLAIM) { }

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
        address yieldSource = BytesLib.toAddress(data, 0);
        address rewardToken = BytesLib.toAddress(data, 20);
        if (yieldSource == address(0) || rewardToken == address(0)) revert ADDRESS_NOT_VALID();

        return _build(yieldSource, abi.encodeCall(IYearnStakingRewardsMulti.getOneReward, (rewardToken)));
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
    function inspect(bytes calldata data) external pure returns(address target, address[] memory args) {
        target = BytesLib.toAddress(data, 0);
        args = new address[](1);
        args[0] = BytesLib.toAddress(data, 20);
    }

    /// @inheritdoc ISuperHookInspector
    function beneficiaryArgs(bytes calldata) external pure returns (uint8[] memory idxs) {
        idxs = new uint8[](0);
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
