// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../../../src/hooks/BaseHook.sol";

import { ISuperHookResult } from "../../../src/interfaces/ISuperHook.sol";
import { IPermit2Single } from "../../../src/vendor/uniswap/permit2/IPermit2Single.sol";

/// @title TransferWithPermit2Hook
/// @dev data has the following structure
/// @notice         address from = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         address to = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
/// @notice         uint160 amount = uint160(BytesLib.toUint256(BytesLib.slice(data, 40, 20), 0));
/// @notice         address token = BytesLib.toAddress(BytesLib.slice(data, 60, 20), 0);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 80);
contract TransferWithPermit2Hook is BaseHook {
    using SafeCast for uint256;
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public permit2;

    constructor(address permit2_) BaseHook(HookType.NONACCOUNTING, "Token") {
        if (permit2_ == address(0)) revert ADDRESS_NOT_VALID();
        permit2 = permit2_;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function _buildHookExecutions(
        address prevHook,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        address from = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        address to = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
        uint160 amount = uint160(BytesLib.toUint256(BytesLib.slice(data, 40, 20), 0));
        address token = BytesLib.toAddress(BytesLib.slice(data, 60, 20), 0);
        bool usePrevHookAmount = _decodeBool(data, 80);

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).getOutAmount(account).toUint160();
        }

        if (token == address(0) || from == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(permit2),
            value: 0,
            callData: abi.encodeCall(IPermit2Single.transferFrom, (from, to, amount, token))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(data), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(data) - getOutAmount(account), account);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(bytes memory data) private view returns (uint256) {
        address to = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
        address token = BytesLib.toAddress(BytesLib.slice(data, 60, 20), 0);
        return IERC20(token).balanceOf(to);
    }
}
