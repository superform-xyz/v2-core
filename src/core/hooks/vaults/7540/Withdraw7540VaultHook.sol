// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";

import { ISuperHook, ISuperHookResultOutflow } from "../../../interfaces/ISuperHook.sol";
import { IERC7540 } from "../../../interfaces/vendors/vaults/7540/IERC7540.sol";

import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

/// @title Withdraw7540VaultHook
/// @dev data has the following structure
/// @notice         bytes32 yieldSourceOracleId = BytesLib.toBytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 32, 20), 0);
/// @notice         address owner = BytesLib.toAddress(BytesLib.slice(data, 52, 20), 0);
/// @notice         uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 72, 32), 0);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 104);
/// @notice         bool lockForSP = _decodeBool(data, 105);
contract Withdraw7540VaultHook is BaseHook, ISuperHook {
    using HookDataDecoder for bytes;

    // forgefmt: disable-start
    address public transient assetOut;
    // forgefmt: disable-end

    constructor(address registry_, address author_) BaseHook(registry_, author_, ISuperHook.HookType.OUTFLOW) { }

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
        address owner = BytesLib.toAddress(BytesLib.slice(data, 52, 20), 0);
        uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 72, 32), 0);
        bool usePrevHookAmount = _decodeBool(data, 104);

        if (usePrevHookAmount) {
            amount = ISuperHookResultOutflow(prevHook).outAmount();
        }

        if (amount == 0) revert AMOUNT_NOT_VALID();
        if (yieldSource == address(0) || account == address(0) || owner == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IERC7540.withdraw, (amount, account, owner))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, address account, bytes memory data) external onlyExecutor {
        address yieldSource = data.extractYieldSource();
        assetOut = IERC7540(yieldSource).asset();
        outAmount = _getBalance(account, data);
        lockForSP = _decodeBool(data, 105);
        spToken = yieldSource;
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, address account, bytes memory data) external onlyExecutor {
        outAmount = _getBalance(account, data) - outAmount;
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(address account, bytes memory data) private view returns (uint256) {
        return IERC20(assetOut).balanceOf(account);
    }
}
