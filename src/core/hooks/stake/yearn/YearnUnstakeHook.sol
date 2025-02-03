// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";

import { ISuperHook, ISuperHookResult, ISuperHookInflowOutflow } from "../../../interfaces/ISuperHook.sol";
import { IYearnVault } from "../../../interfaces/vendors/yearn/IYearnVault.sol";

import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

/// @title YearnUnstakeHook
/// @dev data has the following structure
/// @notice         bytes32 yieldSourceOracleId = BytesLib.toBytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 32, 20), 0);
/// @notice         uint256 maxShares = BytesLib.toUint256(BytesLib.slice(data, 52, 32), 0);
/// @notice         uint256 maxLoss = BytesLib.toUint256(BytesLib.slice(data, 84, 32), 0);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 116);
/// @notice         bool lockForSP = _decodeBool(data, 117);
contract YearnUnstakeHook is BaseHook, ISuperHook, ISuperHookInflowOutflow {

    using HookDataDecoder for bytes;

    uint256 private constant AMOUNT_POSITION = 52;
    // forgefmt: disable-start
    address public assetOut;
    // forgefmt: disable-end

    constructor(address registry_, address author_) BaseHook(registry_, author_, HookType.OUTFLOW) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(
        address prevHook,
        address account,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        address yieldSource = data.extractYieldSource();
        uint256 maxShares = _decodeAmount(data);
        uint256 maxLoss = BytesLib.toUint256(BytesLib.slice(data, 84, 32), 0);
        bool usePrevHookAmount = _decodeBool(data, 116);

        if (yieldSource == address(0)) revert ADDRESS_NOT_VALID();

        if (usePrevHookAmount) {
            maxShares = ISuperHookResult(prevHook).outAmount();
        }

        executions = new Execution[](1);
        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IYearnVault.withdraw, (maxShares, account, maxLoss))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, address account, bytes memory data) external onlyExecutor {
        assetOut = IYearnVault(data.extractYieldSource()).stakingToken();
        outAmount = _getBalance(account, data);
        lockForSP = _decodeBool(data, 117);
        /// @dev in Yearn, the staking token doesn't exist because no shares are minted.
        /// @dev in Yearn, the share token doesn't exist because no shares are minted so we don't assign a spToken
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
        return IERC20(assetOut).balanceOf(account);
    }
}
