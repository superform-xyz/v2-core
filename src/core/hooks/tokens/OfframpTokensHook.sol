// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";
import { HookSubTypes } from "../../libraries/HookSubTypes.sol";
import { ISuperHookInspector } from "../../interfaces/ISuperHook.sol";

address constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

/// @title OfframpTokensHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address to = BytesLib.toAddress(data, 0);
/// @notice         bytes tokensArr = BytesLib.slice(data, 20, data.length - 20);
contract OfframpTokensHook is BaseHook, ISuperHookInspector {
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 52;

    error LENGTH_MISMATCH();

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.TOKEN) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    function _buildHookExecutions(
        address,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        address to = BytesLib.toAddress(data, 0);
        bytes memory tokensData = BytesLib.slice(data, 20, data.length - 20);

        (address[] memory tokens) = abi.decode(tokensData, (address[]));

        uint256 tokensLen = tokens.length;

        executions = new Execution[](tokensLen);
        for (uint256 i; i < tokensLen; i++) {
            address _token = tokens[i];
            if (_token == NATIVE_TOKEN) {
                uint256 balance = account.balance;
                // For native token, send ETH directly to the recipient
                executions[i] = Execution({ target: to, value: balance, callData: "" });
            } else {
                uint256 balance = IERC20(_token).balanceOf(account);
                // For ERC20 tokens, use the standard transfer
                executions[i] = Execution({
                    target: _token,
                    value: 0,
                    callData: abi.encodeCall(IERC20.transfer, (to, balance))
                });
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure returns (bytes memory) {
        // First 20 bytes is the 'to' address
        address to = BytesLib.toAddress(data, 0);

        // The rest is abi encoded (address[] tokens, uint256[] amounts)
        bytes memory tokensData = BytesLib.slice(data, 20, data.length - 20);
        (address[] memory tokens) = abi.decode(tokensData, (address[]));

        // Return the 'to' address and all token addresses
        bytes memory result = abi.encodePacked(to);

        uint256 tokensLen = tokens.length;
        for (uint256 i; i < tokensLen; i++) {
            result = abi.encodePacked(result, tokens[i]);
        }

        return result;
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address, bytes calldata data) internal override { }

    function _postExecute(address, address, bytes calldata data) internal override { }
}
