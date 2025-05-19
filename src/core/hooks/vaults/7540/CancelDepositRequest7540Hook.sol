// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import {Execution} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import {IERC7540CancelDeposit} from "../../../../vendor/standards/ERC7540/IERC7540Vault.sol";

// Superform
import {BaseHook} from "../../BaseHook.sol";
import {HookSubTypes} from "../../../libraries/HookSubTypes.sol";
import {HookDataDecoder} from "../../../libraries/HookDataDecoder.sol";
import {ISuperHookInspector} from "../../../interfaces/ISuperHook.sol";

/// @title CancelDepositRequest7540Hook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         bytes4 placeholder = bytes4(BytesLib.slice(data, 0, 4), 0);
/// @notice         address yieldSource = BytesLib.toAddress(data, 4);
contract CancelDepositRequest7540Hook is BaseHook, ISuperHookInspector {
    using HookDataDecoder for bytes;

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.CANCEL_DEPOSIT_REQUEST) {}

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function build(address, address account, bytes memory data)
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

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure returns (bytes memory) {
        return abi.encodePacked(data.extractYieldSource());
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address, bytes calldata) internal override {}

    function _postExecute(address, address, bytes calldata) internal override {}
}
