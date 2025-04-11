// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";
import { ISuperHook } from "../../interfaces/ISuperHook.sol";
import { ISuperHookResult } from "../../interfaces/ISuperHook.sol";
import { HookDataDecoder } from "../../libraries/HookDataDecoder.sol";
import { ISuperHookContextAware } from "../../interfaces/ISuperHook.sol";

/// @title BaseLoanHook
/// @author Superform Labs
abstract contract BaseLoanHook is BaseHook, ISuperHookContextAware {
    using HookDataDecoder for bytes;

    error INSUFFICIENT_BALANCE();

    uint256 private constant AMOUNT_POSITION = 80;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 144;

    address public target;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    /*//////////////////////////////////////////////////////////////
    constructor(address registry_) BaseHook(registry_, HookType.NONACCOUNTING) {
        // if (target_ == address(0)) revert ADDRESS_NOT_VALID();
        // target = target_;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        // store current balance
        outAmount = _getLoanTokenBalance(account, data);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        outAmount = _getLoanTokenBalance(account, data) - outAmount;
    }
    
    function _decodeAmount(bytes memory data) internal pure returns (uint256) {
        return BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    function _getCollateralBalance(address account, bytes memory data) internal view returns (uint256) {
        address collateralToken = BytesLib.toAddress(data, 20);
        return IERC20(collateralToken).balanceOf(account);
    }

    function _getLoanTokenBalance(address account, bytes memory data) internal view returns (uint256) {
        address loanToken = BytesLib.toAddress(data, 0);
        return IERC20(loanToken).balanceOf(account);
    }
    
}
