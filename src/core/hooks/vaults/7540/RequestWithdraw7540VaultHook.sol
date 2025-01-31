// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";

import { ISuperHook, ISuperHookResult, ISuperHookInflowOutflow } from "../../../interfaces/ISuperHook.sol";
import { IERC7540 } from "../../../interfaces/vendors/vaults/7540/IERC7540.sol";

import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

/// @title RequestWithdraw7540VaultHook
/// @dev data has the following structure
/// @notice         address account = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         bytes32 yieldSourceOracleId = BytesLib.toBytes32(BytesLib.slice(data, 20, 32), 0);
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 52, 20), 0);
/// @notice         address controller = BytesLib.toAddress(BytesLib.slice(data, 72, 20), 0);
/// @notice         uint256 shares = BytesLib.toUint256(BytesLib.slice(data, 92, 32), 0);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 124);
contract RequestWithdraw7540VaultHook is BaseHook, ISuperHook, ISuperHookInflowOutflow {
    using HookDataDecoder for bytes;

    uint256 private constant AMOUNT_POSITION = 92;

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
        address account = data.extractAccount();
        address yieldSource = data.extractYieldSource();
        address controller = BytesLib.toAddress(BytesLib.slice(data, 72, 20), 0);
        uint256 shares = BytesLib.toUint256(BytesLib.slice(data, AMOUNT_POSITION, 32), 0);
        bool usePrevHookAmount = _decodeBool(data, 124);

        if (usePrevHookAmount) {
            shares = ISuperHookResult(prevHook).outAmount();
        }

        if (shares == 0) revert AMOUNT_NOT_VALID();
        if (yieldSource == address(0) || controller == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IERC7540.requestRedeem, (shares, controller, account))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, bytes memory) external view onlyExecutor { }

    /// @inheritdoc ISuperHook
    function postExecute(address, bytes memory) external view onlyExecutor { }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmount(bytes memory data) external pure returns (uint256) {
        return BytesLib.toUint256(BytesLib.slice(data, AMOUNT_POSITION, 32), 0);
    }
}
