// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

// Superform
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC5115 } from "../../../interfaces/vendors/vaults/5115/IERC5115.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";

import { ISuperHook, ISuperHookResultOutflow, ISuperHookAmount } from "../../../interfaces/ISuperHook.sol";

import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

/// @title Withdraw5115VaultHook
/// @dev data has the following structure
/// @notice         address account = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         bytes32 yieldSourceOracleId = BytesLib.toBytes32(BytesLib.slice(data, 20, 32), 0);
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 52, 20), 0);
/// @notice         address tokenOut = BytesLib.toAddress(BytesLib.slice(data, 72, 20), 0);
/// @notice         uint256 shares = BytesLib.toUint256(BytesLib.slice(data, 92, 32), 0);
/// @notice         uint256 minTokenOut = BytesLib.toUint256(BytesLib.slice(data, 124, 32), 0);
/// @notice         bool burnFromInternalBalance = _decodeBool(data, 156);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 157);
/// @notice         bool lockForSP = _decodeBool(data, 158);
contract Withdraw5115VaultHook is BaseHook, ISuperHook {
    using HookDataDecoder for bytes;

    uint256 private constant AMOUNT_POSITION = 92;
    // forgefmt: disable-start
    address public transient assetOut;
    // forgefmt: disable-end

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
        address account = data.extractAccount();
        address yieldSource = data.extractYieldSource();
        address tokenOut = BytesLib.toAddress(BytesLib.slice(data, 72, 20), 0);
        uint256 shares = BytesLib.toUint256(BytesLib.slice(data, AMOUNT_POSITION, 32), 0);
        uint256 minTokenOut = BytesLib.toUint256(BytesLib.slice(data, 124, 32), 0);
        bool burnFromInternalBalance = _decodeBool(data, 156);
        bool usePrevHookAmount = _decodeBool(data, 157);

        if (usePrevHookAmount) {
            shares = ISuperHookResultOutflow(prevHook).outAmount();
        }

        if (shares == 0) revert AMOUNT_NOT_VALID();
        if (yieldSource == address(0) || tokenOut == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IERC5115.redeem, (account, shares, tokenOut, minTokenOut, burnFromInternalBalance))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, bytes memory data) external  onlyExecutor {
        assetOut = BytesLib.toAddress(BytesLib.slice(data, 72, 20), 0); // tokenOut from data
        outAmount = _getBalance(data);
        lockForSP = _decodeBool(data, 158);
        spToken = data.extractYieldSource();
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, bytes memory data) external onlyExecutor {
        outAmount = _getBalance(data) - outAmount ;
    }

    /// @inheritdoc ISuperHookAmount
    function decodeAmount(bytes memory data) external pure returns (uint256) {
        return BytesLib.toUint256(BytesLib.slice(data, AMOUNT_POSITION, 32), 0);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(bytes memory data) private view returns (uint256) {
        return IERC20(assetOut).balanceOf(data.extractAccount());
    }
}
