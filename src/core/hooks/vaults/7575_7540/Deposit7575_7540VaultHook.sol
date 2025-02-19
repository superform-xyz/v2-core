// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";

import { ISuperHook, ISuperHookResult, ISuperHookInflowOutflow } from "../../../interfaces/ISuperHook.sol";
import { IERC7540 } from "../../../../vendor/vaults/7540/IERC7540.sol";

import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

/// @title Deposit7540VaultHook
/// @dev data has the following structure
/// @notice         bytes4 yieldSourceOracleId = bytes4(BytesLib.slice(data, 0, 4), 0);
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 4, 20), 0);
/// @notice         address controller = BytesLib.toAddress(BytesLib.slice(data, 24, 20), 0);
/// @notice         uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 44, 32), 0);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 76);
/// @notice         bool lockForSP = _decodeBool(data, 77);
contract Deposit7575_7540VaultHook is BaseHook, ISuperHook, ISuperHookInflowOutflow {
    using HookDataDecoder for bytes;

    uint256 private constant AMOUNT_POSITION = 44;

    constructor(address registry_, address author_) BaseHook(registry_, author_, HookType.INFLOW) { }

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
        address controller = BytesLib.toAddress(BytesLib.slice(data, 24, 20), 0);
        uint256 amount = _decodeAmount(data);
        bool usePrevHookAmount = _decodeBool(data, 76);

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).outAmount();
        }

        if (amount == 0) revert AMOUNT_NOT_VALID();
        if (yieldSource == address(0) || account == address(0) || controller == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IERC7540.deposit, (amount, account, controller))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, address account, bytes memory data) external onlyExecutor {
        // store current balance
        address yieldSource = data.extractYieldSource();
        address shareToken = IERC7540(yieldSource).share();
        outAmount = _getBalance(account, shareToken);
        lockForSP = _decodeBool(data, 77);
        spToken = yieldSource;
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, address account, bytes memory data) external onlyExecutor {
        address shareToken = IERC7540(data.extractYieldSource()).share();
        outAmount = _getBalance(account, shareToken) - outAmount;
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

    function _getBalance(address account, address shareToken) private view returns (uint256) {
        return IERC20(shareToken).balanceOf(account);
    }
}
