// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "src/hooks/BaseHook.sol";

import { ISuperHook, ISuperHookResult } from "src/interfaces/ISuperHook.sol";
import { IERC7540 } from "src/interfaces/vendors/vaults/7540/IERC7540.sol";

/// @title RequestDeposit7540VaultHook
/// @dev data has the following structure
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         address account = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
/// @notice         uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 40, 32), 0);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 72);
contract RequestDeposit7540VaultHook is BaseHook, ISuperHook {
    constructor(address registry_, address author_) BaseHook(registry_, author_, HookType.NONACCOUNTING) { }

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
        address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        address account = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
        uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 40, 32), 0);
        bool usePrevHookAmount = _decodeBool(data, 72);

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).outAmount();
        }

        if (amount == 0) revert AMOUNT_NOT_VALID();
        if (yieldSource == address(0) || account == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IERC7540.requestDeposit, (amount, account))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, bytes memory) external view onlyExecutor { }

    /// @inheritdoc ISuperHook
    function postExecute(address, bytes memory) external view onlyExecutor{ }
}
