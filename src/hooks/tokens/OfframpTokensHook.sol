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
import { LibSort } from "solady/utils/LibSort.sol";

address constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

/// @title OfframpTokensHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address to = BytesLib.toAddress(data, 0);
/// @notice         bytes tokensArr = BytesLib.slice(data, 20, data.length - 20);
contract OfframpTokensHook is BaseHook {
    using LibSort for address[];

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

        // make sure tokens are sorted and unique
        tokens.insertionSort();
        tokens.uniquifySorted();

        uint256 tokensLen = tokens.length;

        // Cache balances and count non-zero ones in a single pass
        uint256[] memory balances = new uint256[](tokensLen);
        uint256 executionCount;
        for (uint256 i; i < tokensLen; ++i) {
            address _token = tokens[i];
            uint256 balance = _token == NATIVE_TOKEN ? account.balance : IERC20(_token).balanceOf(account);
            balances[i] = balance;

            // consider this for transfer
            if (balance > 0) {
                executionCount++;
            }
        }

        // Build executions array using cached balances
        executions = new Execution[](executionCount);
        uint256 executionIndex;
        for (uint256 i; i < tokensLen; ++i) {
            uint256 balance = balances[i];

            // skip 0 balance transfers
            if (balance == 0) continue;

            address _token = tokens[i];
            if (_token == NATIVE_TOKEN) {
                // For native token, send ETH directly to the recipient
                executions[executionIndex++] = Execution({ target: to, value: balance, callData: "" });
            } else {
                // For ERC20 tokens, use the standard transfer
                executions[executionIndex++] = Execution({
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
    function inspect(bytes calldata data) external pure override returns (bytes memory result) {
        // First 20 bytes is the 'to' address
        address to = BytesLib.toAddress(data, 0);

        // The rest is abi encoded (address[] tokens, uint256[] amounts)
        bytes memory tokensData = BytesLib.slice(data, 20, data.length - 20);
        (address[] memory tokens) = abi.decode(tokensData, (address[]));

        // Return the 'to' address and all token addresses
        result = abi.encodePacked(to);

        uint256 tokensLen = tokens.length;
        for (uint256 i; i < tokensLen; i++) {
            result = abi.encodePacked(result, tokens[i]);
        }
    }
}
