// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";

import { ISuperHook, ISuperHookResult } from "../../../interfaces/ISuperHook.sol";
import { IAllowanceTransfer } from "../../../../vendor/uniswap/permit2/IAllowanceTransfer.sol";

/// @title ApproveWithPermit2Hook
/// @dev data has the following structure
/// @notice         address token = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         address spender = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
/// @notice         uint160 amount = uint160(BytesLib.toUint256(BytesLib.slice(data, 40, 20), 0));
/// @notice         uint48 expiration = uint48(BytesLib.toUint256(BytesLib.slice(data, 60, 6), 0));
/// @notice         bool usePrevHookAmount = _decodeBool(data, 66);
contract ApproveWithPermit2Hook is BaseHook, ISuperHook {
    using SafeCast for uint256;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public permit2;

    constructor(
        address registry_,
        address author_,
        address permit2_
    )
        BaseHook(registry_, author_, HookType.NONACCOUNTING)
    {
        if (permit2_ == address(0)) revert ADDRESS_NOT_VALID();
        permit2 = permit2_;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(
        address prevHook,
        address,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        address token = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        address spender = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
        uint160 amount = uint160(BytesLib.toUint256(BytesLib.slice(data, 40, 20), 0));
        uint48 expiration = uint48(BytesLib.toUint256(BytesLib.slice(data, 60, 6), 0));
        bool usePrevHookAmount = _decodeBool(data, 66);

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).outAmount().toUint160();
        }

        if (token == address(0) || spender == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(permit2),
            value: 0,
            callData: abi.encodeCall(IAllowanceTransfer.approve, (token, spender, amount, expiration))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, address, bytes memory data) external {
        outAmount = uint160(BytesLib.toUint256(BytesLib.slice(data, 40, 20), 0));
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, address, bytes memory data) external {
        outAmount = uint160(BytesLib.toUint256(BytesLib.slice(data, 40, 20), 0));
    }
}
