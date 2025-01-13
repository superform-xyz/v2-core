// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";

import { ISuperHook, ISuperHookMinimal } from "../../../interfaces/ISuperHook.sol";
import { IYearnVault } from "../../../interfaces/vendors/yearn/IYearnVault.sol";

/// @title YearnWithdrawHook
/// @dev data has the following structure
/// @notice         address account = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         bytes32 yieldSourceOracleId = BytesLib.toBytes32(BytesLib.slice(data, 20, 32), 0);
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 52, 20), 0);
/// @notice         uint256 maxShares = BytesLib.toUint256(BytesLib.slice(data, 72, 32), 0);
/// @notice         uint256 maxLoss = BytesLib.toUint256(BytesLib.slice(data, 104, 32), 0);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 136);
/// @notice         uint8 lockFlags = BytesLib.toUint8(BytesLib.slice(data, 137, 1), 0);
contract YearnWithdrawHook is BaseHook, ISuperHook {
    constructor(address registry_, address author_) BaseHook(registry_, author_, HookType.OUTFLOW) { }

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
        address recipient = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 52, 20), 0);
        uint256 maxShares = BytesLib.toUint256(BytesLib.slice(data, 72, 32), 0);
        uint256 maxLoss = BytesLib.toUint256(BytesLib.slice(data, 104, 32), 0);
        bool usePrevHookAmount = _decodeBool(data, 136);

        if (yieldSource == address(0)) revert ADDRESS_NOT_VALID();

        if (usePrevHookAmount) {
            maxShares = ISuperHookMinimal(prevHook).outAmount();
        }

        executions = new Execution[](1);
        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IYearnVault.withdraw, (maxShares, recipient, maxLoss))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, bytes memory data) external onlyExecutor {
        outAmount = _getBalance(data);
        lockFlag = BytesLib.toUint8(BytesLib.slice(data, 137, 1), 0);
        address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 52, 20), 0);
        spToken = IYearnVault(yieldSource).stakingToken();
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, bytes memory data) external onlyExecutor {
        outAmount = outAmount - _getBalance(data);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(bytes memory data) private view returns (uint256) {
        address recipient = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 52, 20), 0);
        return IYearnVault(yieldSource).balanceOf(recipient);
    }
}
