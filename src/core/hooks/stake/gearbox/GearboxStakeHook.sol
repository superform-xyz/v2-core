// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";

import { ISuperHook, ISuperHookResult, ISuperHookAmount } from "../../../interfaces/ISuperHook.sol";
import { IGearboxFarmingPool } from "../../../interfaces/vendors/gearbox/IGearboxFarmingPool.sol";

import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

/// @title GearboxStakeHook
/// @dev data has the following structure
/// @notice         address account = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         bytes32 yieldSourceOracleId = BytesLib.toBytes32(BytesLib.slice(data, 20, 32), 0);
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 52, 20), 0);
/// @notice         uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 72, 32), 0);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 104);
/// @notice         bool lockForSP = _decodeBool(data, 105);
contract GearboxStakeHook is BaseHook, ISuperHook {
    using HookDataDecoder for bytes;

    uint256 private constant AMOUNT_POSITION = 72;

    constructor(address registry_, address author_) BaseHook(registry_, author_, HookType.INFLOW) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(
        address prevHook,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        address yieldSource = data.extractYieldSource();
        uint256 amount = BytesLib.toUint256(BytesLib.slice(data, AMOUNT_POSITION, 32), 0);
        bool usePrevHookAmount = _decodeBool(data, 104);

        if (yieldSource == address(0)) revert ADDRESS_NOT_VALID();

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).outAmount();
        }

        executions = new Execution[](1);
        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IGearboxFarmingPool.deposit, (amount))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, bytes memory data) external onlyExecutor {
        outAmount = _getBalance(data);
        lockForSP = _decodeBool(data, 105);
        /// @dev In Gearbox, the shares is the yield source itself
        spToken = data.extractYieldSource();
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, bytes memory data) external onlyExecutor {
        outAmount = _getBalance(data) - outAmount;
    }

    /// @inheritdoc ISuperHookAmount
    function decodeAmount(bytes memory data) external pure returns (uint256) {
        return BytesLib.toUint256(BytesLib.slice(data, AMOUNT_POSITION, 32), 0);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(bytes memory data) private view returns (uint256) {
        return IGearboxFarmingPool(data.extractYieldSource()).balanceOf(data.extractAccount());
    }
}
