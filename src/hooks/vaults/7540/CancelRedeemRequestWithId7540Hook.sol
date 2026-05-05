// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC7540CancelRedeem } from "../../../vendor/standards/ERC7540/IERC7540Vault.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title CancelRedeemRequestWithId7540Hook
/// @author Superform Labs
/// @notice Same as CancelRedeemRequest7540Hook but with requestId from calldata (non-zero support)
/// @dev data has the following structure
/// @notice         bytes32 placeholder = bytes32(BytesLib.slice(data, 0, 32));
/// @notice         address yieldSource = BytesLib.toAddress(data, 32);
/// @notice         uint256 requestId = BytesLib.toUint256(data, 52);
contract CancelRedeemRequestWithId7540Hook is BaseHook {
    using HookDataDecoder for bytes;

    uint256 private constant REQUEST_ID_POSITION = 52;

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.CANCEL_REDEEM_REQUEST) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address,
        address account,
        bytes calldata data
    )
        internal
        pure
        override
        returns (Execution[] memory executions)
    {
        address yieldSource = data.extractYieldSource();
        uint256 requestId = BytesLib.toUint256(data, REQUEST_ID_POSITION);

        if (yieldSource == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IERC7540CancelRedeem.cancelRedeemRequest, (requestId, account))
        });
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(data.extractYieldSource());
    }
}
