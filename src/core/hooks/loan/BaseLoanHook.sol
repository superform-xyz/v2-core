// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";
import { HookSubTypes } from "../../libraries/HookSubTypes.sol";
import { ISuperHookLoans } from "../../interfaces/ISuperHook.sol";
import { HookDataDecoder } from "../../libraries/HookDataDecoder.sol";
import { ISuperHookContextAware } from "../../interfaces/ISuperHook.sol";

/// @title BaseLoanHook
/// @author Superform Labs
abstract contract BaseLoanHook is BaseHook, ISuperHookLoans {
    using HookDataDecoder for bytes;

    error INSUFFICIENT_BALANCE();

    uint256 private constant AMOUNT_POSITION = 80;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 144;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(bytes32 hookSubtype_) BaseHook(HookType.NONACCOUNTING, hookSubtype_) { }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookLoans
    function getLoanTokenAddress(bytes memory data) public pure returns (address) {
        return BytesLib.toAddress(data, 0);
    }

    /// @inheritdoc ISuperHookLoans
    function getCollateralTokenAddress(bytes memory data) public pure returns (address) {
        return BytesLib.toAddress(data, 20);
    }

    /// @inheritdoc ISuperHookLoans
    function getCollateralTokenBalance(address account, bytes memory data) public view returns (uint256) {
        address collateralToken = BytesLib.toAddress(data, 20);
        return IERC20(collateralToken).balanceOf(account);
    }

    /// @inheritdoc ISuperHookLoans
    function getLoanTokenBalance(address account, bytes memory data) public view returns (uint256) {
        address loanToken = BytesLib.toAddress(data, 0);
        return IERC20(loanToken).balanceOf(account);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _decodeAmount(bytes memory data) internal pure returns (uint256) {
        return BytesLib.toUint256(data, AMOUNT_POSITION);
    }
}
