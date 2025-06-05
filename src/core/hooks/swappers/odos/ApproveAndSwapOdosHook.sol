// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import {BytesLib} from "../../../../vendor/BytesLib.sol";
import {Execution} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import {IOdosRouterV2} from "../../../../vendor/odos/IOdosRouterV2.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import {BaseHook} from "../../BaseHook.sol";
import {HookSubTypes} from "../../../libraries/HookSubTypes.sol";
import {ISuperHookResult, ISuperHookContextAware, ISuperHookInspector} from "../../../interfaces/ISuperHook.sol";

/// @title ApproveAndSwapOdosHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address inputToken = BytesLib.toAddress(data, 0);
/// @notice         uint256 inputAmount = BytesLib.toUint256(data, 20);
/// @notice         address inputReceiver = BytesLib.toAddress(data, 52);
/// @notice         address outputToken = BytesLib.toAddress(data, 72);
/// @notice         uint256 outputQuote = BytesLib.toUint256(data, 92);
/// @notice         uint256 outputMin = BytesLib.toUint256(data, 124);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 156);
/// @notice         address spender = BytesLib.toAddress(data, 157);
/// @notice         uint256 pathDefinition_paramLength = BytesLib.toUint256(data, 177);
/// @notice         bytes pathDefinition = BytesLib.slice(data, 209, pathDefinition_paramLength);
/// @notice         address executor = BytesLib.toAddress(data, 209 + pathDefinition_paramLength);
/// @notice         uint32 referralCode = BytesLib.toUint32(data, 209 + pathDefinition_paramLength + 20);
contract ApproveAndSwapOdosHook is BaseHook, ISuperHookContextAware, ISuperHookInspector {
    IOdosRouterV2 public immutable odosRouterV2;

    struct LocalVars {
        uint256 pathDefinition_paramLength;
        bytes pathDefinition;
        address executor;
        uint32 referralCode;
        address inputToken;
        uint256 inputAmount;
        bool usePrevHookAmount;
        address approveSpender;
        uint256 allowance;
        uint256 offset;
    }

    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 156;

    constructor(address _routerV2) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        if (_routerV2 == address(0)) revert ADDRESS_NOT_VALID();
        odosRouterV2 = IOdosRouterV2(_routerV2);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function build(address prevHook, address account, bytes memory data)
        external
        view
        override
        returns (Execution[] memory executions)
    {
        LocalVars memory vars;

        vars.pathDefinition_paramLength = BytesLib.toUint256(data, 177);
        vars.pathDefinition = BytesLib.slice(data, 209, vars.pathDefinition_paramLength);
        vars.executor = BytesLib.toAddress(data, 209 + vars.pathDefinition_paramLength);
        vars.referralCode = BytesLib.toUint32(data, 209 + vars.pathDefinition_paramLength + 20);

        vars.inputToken = BytesLib.toAddress(data, 0);
        vars.inputAmount = BytesLib.toUint256(data, 20);

        vars.usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
        if (vars.usePrevHookAmount) {
            vars.inputAmount = ISuperHookResult(prevHook).outAmount();
        }

        vars.approveSpender = BytesLib.toAddress(data, 157);
        if (vars.approveSpender == address(0)) {
            vars.approveSpender = address(odosRouterV2);
        }

        vars.allowance = IERC20(vars.inputToken).allowance(account, vars.approveSpender);

        executions = new Execution[](vars.allowance > 0 ? 3 : 2);

        vars.offset = 0;
        if (vars.allowance > 0) {
            executions[0] = Execution({
                target: vars.inputToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (vars.approveSpender, 0))
            });
            vars.offset = 1;
        }
        executions[vars.offset + 0] = Execution({
            target: vars.inputToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (vars.approveSpender, vars.inputAmount))
        });
        executions[vars.offset + 1] = Execution({
            target: address(odosRouterV2),
            value: 0,
            callData: abi.encodeCall(
                IOdosRouterV2.swap, (_getSwapInfo(account, prevHook, data), vars.pathDefinition, vars.executor, vars.referralCode)
            )
        });
    }


    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure returns (bytes memory) {
        uint256 pathDefinition_paramLength = BytesLib.toUint256(data, 177);
        address executor = BytesLib.toAddress(data, 209 + pathDefinition_paramLength);

        return abi.encodePacked(
            BytesLib.toAddress(data, 0), //inputToken
            BytesLib.toAddress(data, 52), //inputReceiver
            BytesLib.toAddress(data, 72), //outputToken
            BytesLib.toAddress(data, 157), //spender
            executor
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        outAmount = _getBalance(account, data);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        outAmount = _getBalance(account, data) - outAmount;
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(address account, bytes memory data) private view returns (uint256) {
        address outputToken = BytesLib.toAddress(data, 72);

        if (outputToken == address(0)) {
            return account.balance;
        }

        return IERC20(outputToken).balanceOf(account);
    }

    function _getSwapInfo(address account, address prevHook, bytes memory data)
        private
        view
        returns (IOdosRouterV2.swapTokenInfo memory)
    {
        address inputToken = BytesLib.toAddress(data, 0);
        uint256 inputAmount = BytesLib.toUint256(data, 20);
        address inputReceiver = BytesLib.toAddress(data, 52);
        address outputToken = BytesLib.toAddress(data, 72);
        uint256 outputQuote = BytesLib.toUint256(data, 92);
        uint256 outputMin = BytesLib.toUint256(data, 124);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            inputAmount = ISuperHookResult(prevHook).outAmount();
        }
        return IOdosRouterV2.swapTokenInfo(
            inputToken, inputAmount, inputReceiver, outputToken, outputQuote, outputMin, account
        );
    }

    function _createExecutions(
        address account,
        address inputToken,
        address approveSpender,
        uint256 inputAmount,
        bytes memory pathDefinition,
        address executor,
        uint32 referralCode,
        address prevHook,
        bytes memory data
    ) internal view returns (Execution[] memory executions) {
        uint256 allowance = IERC20(inputToken).allowance(account, approveSpender);
        executions = new Execution[](allowance > 0 ? 3 : 2);
        uint256 offset = 0;
        if (allowance > 0) {
            executions[0] = Execution({
                target: inputToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (approveSpender, 0))
            });
            offset = 1;
        }
        executions[offset + 0] = Execution({
            target: inputToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (approveSpender, inputAmount))
        });
        executions[offset + 1] = Execution({
            target: address(odosRouterV2),
            value: 0,
            callData: abi.encodeCall(
                IOdosRouterV2.swap, (_getSwapInfo(account, prevHook, data), pathDefinition, executor, referralCode)
            )
        });
    }
}
