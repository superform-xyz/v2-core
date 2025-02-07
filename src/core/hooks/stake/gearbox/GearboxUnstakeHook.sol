// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";

import { ISuperHook, ISuperHookResultOutflow, ISuperHookInflowOutflow } from "../../../interfaces/ISuperHook.sol";
import { IGearboxFarmingPool } from "../../../interfaces/vendors/gearbox/IGearboxFarmingPool.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

/// @title GearboxUnstakeHook
/// @dev data has the following structure
/// @notice         bytes32 yieldSourceOracleId = BytesLib.toBytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 32, 20), 0);
/// @notice         uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 52, 32), 0);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 84);
/// @notice         bool lockForSP = _decodeBool(data, 85);
contract GearboxUnstakeHook is BaseHook, ISuperHook, ISuperHookInflowOutflow {
    using HookDataDecoder for bytes;

    uint256 private constant AMOUNT_POSITION = 52;

    constructor(address registry_, address author_) BaseHook(registry_, author_, HookType.OUTFLOW) { }

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
            callData: abi.encodeCall(IGearboxFarmingPool.withdraw, (amount))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, address account, bytes memory data) external onlyExecutor {
        address yieldSource = data.extractYieldSource();
        /// @dev in Gearbox, the staking token is the asset
        asset = IGearboxFarmingPool(yieldSource).stakingToken();
        outAmount = _getBalance(account, data);
        lockForSP = _decodeBool(data, 85);
        spToken = yieldSource;
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, address account, bytes memory data) external onlyExecutor {
        outAmount =  _getBalance(account, data) - outAmount;
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
        return IERC20(asset).balanceOf(account);
    }
}
