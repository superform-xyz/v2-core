// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";

import { IOdosRouterV2 } from "../../../interfaces/vendors/odos/IOdosRouterV2.sol";

import { ISuperHook, ISuperHookResult } from "../../../interfaces/ISuperHook.sol";

/// @title SwapOdosHook
/// @dev data has the following structure
/// @notice         address inputToken = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         uint256 inputAmount = BytesLib.toUint256(BytesLib.slice(data, 20, 32), 0);
/// @notice         address inputReceiver = BytesLib.toAddress(BytesLib.slice(data, 52, 20), 0);
/// @notice         address outputToken = BytesLib.toAddress(BytesLib.slice(data, 72, 20), 0);
/// @notice         uint256 outputQuote = BytesLib.toUint256(BytesLib.slice(data, 92, 32), 0);
/// @notice         uint256 outputMin = BytesLib.toUint256(BytesLib.slice(data, 124, 32), 0);
/// @notice         uint256 pathDefinitionLength = BytesLib.toUint256(BytesLib.slice(data, 156, 32), 0);
/// @notice         bytes pathDefinition = BytesLib.slice(data, 188, pathDefinitionLength);
/// @notice         address executor = BytesLib.toAddress(BytesLib.slice(data, 188 + pathDefinitionLength, 20), 0);
/// @notice         uint32 referralCode = BytesLib.toUint32(BytesLib.slice(data, 188 + pathDefinitionLength + 20, 4),
/// 0);
/// @notice         bool usePreviousHookAmount = _decodeBool(data, 168 + pathDefinitionLength + 20 + 4);
contract SwapOdosHook is BaseHook, ISuperHook {
    IOdosRouterV2 public immutable odosRouterV2;

    constructor(address registry_, address author_, address _routerV2) BaseHook(registry_, author_, HookType.NONACCOUNTING) {
        if (_routerV2 == address(0)) revert ADDRESS_NOT_VALID();
        odosRouterV2 = IOdosRouterV2(odosRouterV2);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(
        address prevHook,
        address account,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        uint256 pathDefinitionLength = BytesLib.toUint256(BytesLib.slice(data, 156, 32), 0);
        bytes memory pathDefinition = BytesLib.slice(data, 188, pathDefinitionLength);
        address executor = BytesLib.toAddress(BytesLib.slice(data, 188 + pathDefinitionLength, 20), 0);
        uint32 referralCode = BytesLib.toUint32(BytesLib.slice(data, 188 + pathDefinitionLength + 20, 4), 0);

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(odosRouterV2),
            value: 0,
            callData: abi.encodeCall(IOdosRouterV2.swap, 
                (
                    _getSwapInfo(account, prevHook, data), 
                    pathDefinition, 
                    executor, 
                    referralCode
                )
            )
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, address account, bytes memory data) external {
        outAmount = _getBalance(account, data);
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, address account, bytes memory data) external {
        outAmount = _getBalance(account, data) - outAmount;
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(address account, bytes memory data) private view returns (uint256) {
        address outputToken = BytesLib.toAddress(BytesLib.slice(data, 72, 20), 0);
        return IERC20(outputToken).balanceOf(account);
    }
    function _getSwapInfo(address account, address prevHook, bytes memory data) private view returns (IOdosRouterV2.swapTokenInfo memory) {
        address inputToken = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        uint256 inputAmount = BytesLib.toUint256(BytesLib.slice(data, 20, 32), 0);
        address inputReceiver = BytesLib.toAddress(BytesLib.slice(data, 52, 20), 0);
        address outputToken = BytesLib.toAddress(BytesLib.slice(data, 72, 20), 0);
        uint256 outputQuote = BytesLib.toUint256(BytesLib.slice(data, 92, 32), 0);
        uint256 outputMin = BytesLib.toUint256(BytesLib.slice(data, 124, 32), 0);
        uint256 pathDefinitionLength = BytesLib.toUint256(BytesLib.slice(data, 156, 32), 0);
        bool usePrevHookAmount = _decodeBool(data, 188 + pathDefinitionLength + 20 + 4);

        if (usePrevHookAmount) {
            inputAmount = ISuperHookResult(prevHook).outAmount();
        }
        return IOdosRouterV2.swapTokenInfo(
                        inputToken, 
                        inputAmount, 
                        inputReceiver, 
                        outputToken, 
                        outputQuote, 
                        outputMin, 
                        account
                    );
    }
}
