// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";
import {
    ISuperHookLoans,
    ISuperHookContextAware,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../interfaces/ISuperHook.sol";
import { HookDataDecoder } from "../../libraries/HookDataDecoder.sol";

/// @title BaseLoanHook
/// @author Superform Labs
abstract contract BaseLoanHook is BaseHook, ISuperHookLoans, ISuperHookInflowOutflow, ISuperHookOutflow {
    using HookDataDecoder for bytes;

    uint256 internal constant AMOUNT_POSITION = 132;
    uint256 internal constant USE_PREV_HOOK_AMOUNT_POSITION = 196;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(bytes32 hookSubtype_) BaseHook(HookType.NONACCOUNTING, hookSubtype_) { }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure virtual returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure virtual override returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        amounts[0] = _decodeAmount(data);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory)
        external
        pure
        virtual
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        meta = new ISuperHookInflowOutflow.AmountMeta[](1);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
    }

    /// @inheritdoc ISuperHookOutflow
    function replaceCalldataAmounts(
        bytes memory data,
        uint256[] memory amounts
    )
        external
        pure
        virtual
        override
        returns (bytes memory)
    {
        if (amounts.length != 1) revert INVALID_AMOUNTS_LENGTH();
        return _replaceCalldataAmount(data, amounts[0], AMOUNT_POSITION);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookLoans
    function getLoanTokenAddress(bytes memory data) public pure returns (address) {
        return BytesLib.toAddress(data, 52);
    }

    /// @inheritdoc ISuperHookLoans
    function getCollateralTokenAddress(bytes memory data) public pure returns (address) {
        return BytesLib.toAddress(data, 72);
    }

    /// @inheritdoc ISuperHookLoans
    function getCollateralTokenBalance(address account, bytes memory data) public view returns (uint256) {
        address collateralToken = BytesLib.toAddress(data, 72);
        return IERC20(collateralToken).balanceOf(account);
    }

    /// @inheritdoc ISuperHookLoans
    function getLoanTokenBalance(address account, bytes memory data) public view returns (uint256) {
        address loanToken = BytesLib.toAddress(data, 52);
        return IERC20(loanToken).balanceOf(account);
    }

    /// @dev BaseLoanHook implements ISuperHookInflowOutflow + ISuperHookOutflow
    function _supportsSizingInterface() internal pure override returns (bool) {
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _decodeAmount(bytes memory data) internal pure returns (uint256) {
        return BytesLib.toUint256(data, AMOUNT_POSITION);
    }
}
