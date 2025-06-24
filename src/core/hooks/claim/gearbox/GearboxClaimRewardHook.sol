// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import {BytesLib} from "../../../../vendor/BytesLib.sol";
import {Execution} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import {IGearboxFarmingPool} from "../../../../vendor/gearbox/IGearboxFarmingPool.sol";

// Superform
import {
    ISuperHook,
    ISuperHookResultOutflow,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware,
    ISuperHookInspector
} from "../../../interfaces/ISuperHook.sol";
import {BaseHook} from "../../BaseHook.sol";
import {BaseClaimRewardHook} from "../BaseClaimRewardHook.sol";
import {HookSubTypes} from "../../../libraries/HookSubTypes.sol";
import {HookDataDecoder} from "../../../libraries/HookDataDecoder.sol";

/// @title GearboxClaimRewardHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         bytes4 placeholder = bytes4(BytesLib.slice(data, 0, 4), 0);
/// @notice         address farmingPool = BytesLib.toAddress(data, 4);
/// @notice         address rewardToken = BytesLib.toAddress(data, 24);
/// @notice         address account = BytesLib.toAddress(data, 44);
contract GearboxClaimRewardHook is
    BaseHook,
    BaseClaimRewardHook,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware,
    ISuperHookInspector
{
    using HookDataDecoder for bytes;

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
        address farmingPool = data.extractYieldSource();
        if (farmingPool == address(0)) revert ADDRESS_NOT_VALID();

        return _build(farmingPool, abi.encodeCall(IGearboxFarmingPool.claim, ()));
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
        return abi.encodePacked(data.extractYieldSource());
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        address farmingPool = BytesLib.toAddress(data, 4);
        asset = BytesLib.toAddress(data, 24);
        if (asset == address(0)) revert ASSET_ZERO_ADDRESS();
        address expectedToken = IGearboxFarmingPool(farmingPool).rewardsToken();
        if (asset != expectedToken) revert INVALID_REWARD_TOKEN();

        setOutAmount(_getBalance(data, account), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        setOutAmount(_getBalance(data, account) - getOutAmount(account), account);
    }
}
