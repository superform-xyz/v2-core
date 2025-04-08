// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC7540CancelDeposit } from "../../../../vendor/standards/ERC7540/IERC7540Vault.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { ISuperHook } from "../../../interfaces/ISuperHook.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

/// @title CancelDepositRequest7540Hook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         bytes4 placeholder = BytesLib.toAddress(BytesLib.slice(data, 0, 4), 0);
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 4, 20), 0);
contract CancelDepositRequest7540Hook is BaseHook, ISuperHook {
    using HookDataDecoder for bytes;

    constructor(address registry_) BaseHook(registry_, HookType.NONACCOUNTING) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(
        address,
        address account,
        bytes memory data
    )
        external
        pure
        override
        returns (Execution[] memory executions)
    {
        address yieldSource = data.extractYieldSource();

        if (yieldSource == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IERC7540CancelDeposit.cancelDepositRequest, (0, account))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, address, bytes memory) external { }

    /// @inheritdoc ISuperHook
    function postExecute(address, address account, bytes memory) external { }
}
