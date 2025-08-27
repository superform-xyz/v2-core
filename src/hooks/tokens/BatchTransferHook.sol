// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";
import { HookSubTypes } from "../../libraries/HookSubTypes.sol";
import { ISuperHookInspector } from "../../interfaces/ISuperHook.sol";

address constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

/// @title BatchTransferHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address to = BytesLib.toAddress(data, 0);
/// @notice         bytes tokensArr = BytesLib.slice(data, 20, data.length - 20);
contract BatchTransferHook is BaseHook {
    error LENGTH_MISMATCH();

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.TOKEN) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    function _buildHookExecutions(
        address,
        address,
        bytes calldata data
    )
        internal
        pure
        override
        returns (Execution[] memory executions)
    {
        address to = BytesLib.toAddress(data, 0);
        bytes memory tokensData = BytesLib.slice(data, 20, data.length - 20);

        (address[] memory tokens, uint256[] memory amounts) = abi.decode(tokensData, (address[], uint256[]));

        uint256 tokensLen = tokens.length;
        if (tokensLen != amounts.length) revert LENGTH_MISMATCH();

        executions = new Execution[](tokensLen);
        for (uint256 i; i < tokensLen; i++) {
            if (tokens[i] == NATIVE_TOKEN) {
                // For native token, send ETH directly to the recipient
                executions[i] = Execution({ target: to, value: amounts[i], callData: "" });
            } else {
                // For ERC20 tokens, use the standard transfer
                executions[i] = Execution({
                    target: tokens[i],
                    value: 0,
                    callData: abi.encodeCall(IERC20.transfer, (to, amounts[i]))
                });
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory result) {
        // First 20 bytes is the 'to' address
        address to = BytesLib.toAddress(data, 0);

        // The rest is abi encoded (address[] tokens, uint256[] amounts)
        bytes memory tokensData = BytesLib.slice(data, 20, data.length - 20);
        (address[] memory tokens,) = abi.decode(tokensData, (address[], uint256[]));

        // Return the 'to' address and all token addresses
        result = abi.encodePacked(to);

        uint256 tokensLen = tokens.length;
        for (uint256 i; i < tokensLen; i++) {
            result = abi.encodePacked(result, tokens[i]);
        }
    }
}
