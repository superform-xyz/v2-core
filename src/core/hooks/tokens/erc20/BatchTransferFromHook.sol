// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IPermit2 } from "../../../../vendor/uniswap/permit2/IPermit2.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IAllowanceTransfer } from "../../../../vendor/uniswap/permit2/IAllowanceTransfer.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookResult, ISuperHookContextAware } from "../../../interfaces/ISuperHook.sol";

/// @title BatchTransferFromHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address token = BytesLib.toAddress(data, 0);
/// @notice         address to = BytesLib.toAddress(data, 20);
/// @notice         uint256 amount = BytesLib.toUint256(data, 40);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 72);
contract BatchTransferFromHook is BaseHook, ISuperHookContextAware {
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 72;

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.TOKEN) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
}