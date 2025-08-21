// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../../hooks/BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";

import { IGatewayWallet } from "../../../vendor/circle/IGatewayWallet.sol";

/// @title CircleGatewayRemoveDelegateHook
/// @author Superform Labs
/// @notice Hook for removing a delegate from Circle Gateway Wallet
/// @dev data has the following structure:
/// @notice         address token = BytesLib.toAddress(data, 0);
/// @notice         address delegate = BytesLib.toAddress(data, 20);
contract CircleGatewayRemoveDelegateHook is BaseHook {
    using BytesLib for bytes;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Circle Gateway Wallet contract address
    address public immutable GATEWAY_WALLET;

    constructor(address gatewayWalletAddress) BaseHook(HookType.NONACCOUNTING, HookSubTypes.BRIDGE) {
        if (gatewayWalletAddress == address(0)) revert ADDRESS_NOT_VALID();
        GATEWAY_WALLET = gatewayWalletAddress;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address,
        address,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        address token = BytesLib.toAddress(data, 0);
        address delegate = BytesLib.toAddress(data, 20);

        if (delegate == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: GATEWAY_WALLET,
            value: 0,
            callData: abi.encodeCall(IGatewayWallet.removeDelegate, (token, delegate))
        });
    }
}
