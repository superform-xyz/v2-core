// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import { IStakedUSDeCooldown } from "../../../src/vendor/ethena/IStakedUSDeCooldown.sol";

// Superform
import { BaseHook } from "../../../src/core/hooks/BaseHook.sol";
import {
    ISuperHook,
    ISuperHookResultOutflow,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../src/core/interfaces/ISuperHook.sol";
import { HookDataDecoder } from "../../../src/core/libraries/HookDataDecoder.sol";

/// @title EthenaUnstakeHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         bytes4 yieldSourceOracleId = bytes4(BytesLib.slice(data, 0, 4), 0);
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 4, 20), 0);
/// @notice         uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 24, 32), 0);
/// @notice         address receiver = BytesLib.toAddress(BytesLib.slice(data, 56, 20), 0);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 76);
/// @notice         bool lockForSP = _decodeBool(data, 77);
contract EthenaUnstakeHook is BaseHook, ISuperHook, ISuperHookInflowOutflow, ISuperHookOutflow {
    using HookDataDecoder for bytes;

    uint256 private constant AMOUNT_POSITION = 24;

    // if the callee is the superRegistry, the receiver must be the account
    error INVALID_RECEIVER();

    constructor(address registry_) BaseHook(registry_, HookType.OUTFLOW) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(
        address, /* prevHook */
        address account,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        // Note: prev amount cannot be used in here, it unstakes everything available

        address yieldSource = data.extractYieldSource();
        address receiver = BytesLib.toAddress(BytesLib.slice(data, 56, 20), 0);

        if (yieldSource == address(0) || account == address(0)) revert ADDRESS_NOT_VALID();

        if (msg.sender == address(superRegistry) && receiver != account) revert INVALID_RECEIVER();
        executions = new Execution[](1);

        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IStakedUSDeCooldown.unstake, (account))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, address account, bytes memory data) external {
        address yieldSource = data.extractYieldSource();
        asset = IERC4626(yieldSource).asset();
        outAmount = _getBalance(account, data);
        usedShares = _getSharesBalance(account, data);
        lockForSP = _decodeBool(data, 57);
        spToken = yieldSource;
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, address account, bytes memory data) external {
        outAmount = _getBalance(account, data) - outAmount;
        usedShares = usedShares - _getSharesBalance(account, data);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmount(bytes memory data) external pure returns (uint256) {
        return _decodeAmount(data);
    }

    /// @inheritdoc ISuperHookOutflow
    function replaceCalldataAmount(bytes memory data, uint256 amount) external pure returns (bytes memory) {
        return _replaceCalldataAmount(data, amount, AMOUNT_POSITION);
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

    function _getSharesBalance(address account, bytes memory data) private view returns (uint256) {
        address yieldSource = data.extractYieldSource();
        return IERC4626(yieldSource).balanceOf(account);
    }
}