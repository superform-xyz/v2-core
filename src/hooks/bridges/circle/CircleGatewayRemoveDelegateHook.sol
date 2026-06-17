// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../../hooks/BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";

import { IGatewayWallet } from "../../../vendor/circle/IGatewayWallet.sol";

// Superform
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
/// @title CircleGatewayRemoveDelegateHook
/// @author Superform Labs
/// @notice Hook for removing a delegate from Circle Gateway Wallet
/// @dev data has the following structure:
/// @notice         address token = BytesLib.toAddress(data, 0);
/// @notice         address delegate = BytesLib.toAddress(data, 20);
contract CircleGatewayRemoveDelegateHook is BaseHook, ISuperHookInflowOutflow {
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

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Circle Gateway Remove Delegate";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Removes a delegate from a Circle Gateway wallet";
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

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](0);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory) external pure override returns (ISuperHookInflowOutflow.AmountMeta[] memory meta) {
        meta = new ISuperHookInflowOutflow.AmountMeta[](0);
    }

    /// @inheritdoc IERC165
    /// @dev S2: implements ISuperHookInflowOutflow (decode-only) but NOT ISuperHookOutflow
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        if (interfaceId == type(ISuperHookInflowOutflow).interfaceId) return true;
        if (interfaceId == type(ISuperHookOutflow).interfaceId) return false;
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(ISuperHook).interfaceId
            || interfaceId == type(ISuperHookResult).interfaceId
            || interfaceId == type(ISuperHookInspector).interfaceId;
    }

}
