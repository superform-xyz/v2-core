// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IStakedUSDeCooldown } from "../../../src/vendor/ethena/IStakedUSDeCooldown.sol";
// Superform
import { BaseHook } from "../../../src/core/hooks/BaseHook.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookInflowOutflow,
    ISuperHookAsync
} from "../../../src/core/interfaces/ISuperHook.sol";
import { HookDataDecoder } from "../../../src/core/libraries/HookDataDecoder.sol";

/// @title EthenaCooldownSharesHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         bytes4 yieldSourceOracleId = bytes4(BytesLib.slice(data, 0, 4), 0);
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 4, 20), 0);
/// @notice         uint256 shares = BytesLib.toUint256(BytesLib.slice(data, 24, 32), 0);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 56);
contract EthenaCooldownSharesHook is BaseHook, ISuperHook, ISuperHookInflowOutflow, ISuperHookAsync {
    using HookDataDecoder for bytes;

    uint256 private constant AMOUNT_POSITION = 24;

    constructor(address registry_) BaseHook(registry_, HookType.NONACCOUNTING) { }

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
        uint256 shares = _decodeAmount(data);
        bool usePrevHookAmount = _decodeBool(data, 56);

        if (usePrevHookAmount) {
            shares = ISuperHookResult(prevHook).outAmount();
        }

        if (shares == 0) revert AMOUNT_NOT_VALID();
        if (yieldSource == address(0) || account == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IStakedUSDeCooldown.cooldownShares, (shares))
        });
    }

    /// @inheritdoc ISuperHookAsync
    function getUsedAssetsOrShares() external view returns (uint256, bool isShares) {
        return (outAmount, true);
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, address account, bytes memory data) external {
        outAmount = _getSharesBalance(account, data);
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, address account, bytes memory data) external {
        outAmount = outAmount - _getSharesBalance(account, data);
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

    function _getSharesBalance(address account, bytes memory data) private view returns (uint256) {
        return IERC20(data.extractYieldSource()).balanceOf(account);
    }
}
