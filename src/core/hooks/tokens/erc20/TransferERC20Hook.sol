// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { ISuperHook, ISuperHookResult } from "../../../interfaces/ISuperHook.sol";

/// @title TransferERC20Hook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address token = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         address to = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
/// @notice         uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 40, 32), 0);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 72);
contract TransferERC20Hook is BaseHook, ISuperHook {
    constructor(address registry_, address author_) BaseHook(registry_, author_, HookType.NONACCOUNTING) { }
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
        address to = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
        uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 40, 32), 0);
        bool usePrevHookAmount = _decodeBool(data, 72);

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).outAmount();
        }

        if (amount == 0) revert AMOUNT_NOT_VALID();
        if (token == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({ target: token, value: 0, callData: abi.encodeCall(IERC20.transfer, (to, amount)) });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, address, bytes memory data) external {
        outAmount = _getBalance(data);
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, address, bytes memory data) external {
        outAmount = _getBalance(data) - outAmount;
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(bytes memory data) private view returns (uint256) {
        address token = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        address to = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
        return IERC20(token).balanceOf(to);
    }
}
