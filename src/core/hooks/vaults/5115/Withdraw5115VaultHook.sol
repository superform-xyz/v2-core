// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IStandardizedYield } from "../../../interfaces/vendors/pendle/IStandardizedYield.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";

import { ISuperHook, ISuperHookResultOutflow, ISuperHookInflowOutflow } from "../../../interfaces/ISuperHook.sol";

import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

/// @title Withdraw5115VaultHook
/// @dev data has the following structure
/// @notice         bytes32 yieldSourceOracleId = BytesLib.toBytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 32, 20), 0);
/// @notice         address tokenOut = BytesLib.toAddress(BytesLib.slice(data, 52, 20), 0);
/// @notice         uint256 shares = BytesLib.toUint256(BytesLib.slice(data, 72, 32), 0);
/// @notice         uint256 minTokenOut = BytesLib.toUint256(BytesLib.slice(data, 104, 32), 0);
/// @notice         bool burnFromInternalBalance = _decodeBool(data, 136);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 137);
/// @notice         bool lockForSP = _decodeBool(data, 138);
contract Withdraw5115VaultHook is BaseHook, ISuperHook, ISuperHookInflowOutflow {
    using HookDataDecoder for bytes;

    uint256 private constant AMOUNT_POSITION = 72;
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
        address account,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        address yieldSource = data.extractYieldSource();
        address tokenOut = BytesLib.toAddress(BytesLib.slice(data, 52, 20), 0);
        uint256 shares = _decodeAmount(data);
        uint256 minTokenOut = BytesLib.toUint256(BytesLib.slice(data, 104, 32), 0);
        bool burnFromInternalBalance = _decodeBool(data, 136);
        bool usePrevHookAmount = _decodeBool(data, 137);

        if (usePrevHookAmount) {
            shares = ISuperHookResultOutflow(prevHook).outAmount();
        }

        if (shares == 0) revert AMOUNT_NOT_VALID();
        if (yieldSource == address(0) || tokenOut == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IStandardizedYield.redeem, (account, shares, tokenOut, minTokenOut, burnFromInternalBalance))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, address account,bytes memory data) external  onlyExecutor {
        assetOut = BytesLib.toAddress(BytesLib.slice(data, 52, 20), 0); // tokenOut from data
        outAmount = _getBalance(account, data);
        usedShares = _getSharesBalance(account, data);
        lockForSP = _decodeBool(data, 138);
        spToken = data.extractYieldSource();
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, address account, bytes memory data) external onlyExecutor {
        outAmount = _getBalance(account, data) - outAmount;
        usedShares = usedShares - _getSharesBalance(account, data);
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

    function _getSharesBalance(address account, bytes memory data) private view returns (uint256) {
        address yieldSource = data.extractYieldSource();
        return IStandardizedYield(yieldSource).balanceOf(account);
    }

}
