// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC5115 } from "src/interfaces/vendors/vaults/5115/IERC5115.sol";

// Superform
import { BaseHook } from "src/hooks/BaseHook.sol";
import { BaseAccountingHook } from "src/hooks/BaseAccountingHook.sol";

import { ISuperHook, ISuperHookResult } from "src/interfaces/ISuperHook.sol";

/// @title Withdraw5115VaultHook
/// @dev data has the following structure
/// @notice         address account = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         address yieldSourceOracle = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 40, 20), 0);
/// @notice         address tokenOut = BytesLib.toAddress(BytesLib.slice(data, 60, 20), 0);
/// @notice         uint256 shares = BytesLib.toUint256(BytesLib.slice(data, 80, 32), 0);
/// @notice         uint256 minTokenOut = BytesLib.toUint256(BytesLib.slice(data, 112, 32), 0);
/// @notice         bool burnFromInternalBalance = _decodeBool(data, 144);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 145);
contract Withdraw5115VaultHook is BaseHook, BaseAccountingHook, ISuperHook {
    constructor(address registry_, address author_) BaseHook(registry_, author_) { }

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
        address account = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 40, 20), 0);
        address tokenOut = BytesLib.toAddress(BytesLib.slice(data, 60, 20), 0);
        uint256 shares = BytesLib.toUint256(BytesLib.slice(data, 80, 32), 0);
        uint256 minTokenOut = BytesLib.toUint256(BytesLib.slice(data, 112, 32), 0);
        bool burnFromInternalBalance = _decodeBool(data, 144);
        bool usePrevHookAmount = _decodeBool(data, 145);

        if (usePrevHookAmount) {
            shares = ISuperHookResult(prevHook).outAmount();
        }

        if (shares == 0) revert AMOUNT_NOT_VALID();
        if (yieldSource == address(0)|| tokenOut == address(0)) revert ADDRESS_NOT_VALID();

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
    function preExecute(address, bytes memory data) external onlyExecutor {
        outAmount = _getBalance(data);
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, bytes memory data) external onlyExecutor {
        outAmount = outAmount - _getBalance(data);
        _performAccounting(data, superRegistry, outAmount, false);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(bytes memory data) private view returns (uint256) {
        address account = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 40, 20), 0);
        address asset = IERC5115(yieldSource).asset();
        return IERC20(asset).balanceOf(account);
    }
}
