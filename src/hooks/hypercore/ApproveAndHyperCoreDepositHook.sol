// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { BytesLib } from "../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";
import { HookSubTypes } from "../../libraries/HookSubTypes.sol";
import { IHyperCoreDepositGateway } from "../../vendor/hyperliquid/IHyperCoreDepositGateway.sol";
import {
    ISuperHookResult,
    ISuperHookContextAware,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../interfaces/ISuperHook.sol";

/// @title ApproveAndHyperCoreDepositHook
/// @author Superform Labs
/// @notice Approves and deposits an ERC-20 into HyperCore, crediting the executing account's spot balance
/// @dev NOT a CoreWriter hook. This is the EVM→HyperCore funding leg and it goes through a per-token
///      deposit gateway, so unlike its siblings it has a measurable balance delta and uses the
///      default TRANSFORM pipe mode.
/// @dev TOKEN and GATEWAY are immutables, not data fields. The gateway credits msg.sender and
///      exposes no recipient-taking overload, so there is no address parameter to supply — and
///      equally none to abuse. Pinning both means this contract can only ever move one token into
///      one gateway. Deploy one instance per token; CREATE2 makes that near-free.
/// @dev The address returned by the HyperCore `tokenInfo` precompile as `evmContract` is the
///      GATEWAY, not the token. Do not read TOKEN from the precompile.
/// @dev Measured on mainnet: credits a contract sender in ~1 second, 74,942 gas for approve+deposit.
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         uint256 amount = BytesLib.toUint256(data, 52);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 84);
contract ApproveAndHyperCoreDepositHook is
    BaseHook,
    ISuperHookContextAware,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
{
    uint256 private constant AMOUNT_POSITION = 52;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 84;
    uint256 private constant DATA_LENGTH = 85;

    /// @notice The ERC-20 this hook deposits
    address public immutable TOKEN;

    /// @notice The per-token HyperCore deposit gateway
    address public immutable GATEWAY;

    /// @notice The gateway's second, undocumented uint32 argument
    /// @dev Every observed mainnet call passes 0. It is NOT a token index — gateways are per-token,
    ///      so the gateway already knows its token. Held as an immutable so a later deployment can
    ///      change it without new hook logic, should its meaning ever be documented.
    uint32 public immutable GATEWAY_ARG;

    /// @notice Thrown when hook data length does not exactly match the declared layout
    error DATA_NOT_VALID();

    constructor(
        address token_,
        address gateway_,
        uint32 gatewayArg_
    )
        BaseHook(HookType.NONACCOUNTING, HookSubTypes.HYPERCORE)
    {
        if (token_ == address(0) || gateway_ == address(0)) revert ADDRESS_NOT_VALID();
        TOKEN = token_;
        GATEWAY = gateway_;
        GATEWAY_ARG = gatewayArg_;
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Approve and HyperCore Deposit";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Deposits an ERC-20 into a HyperCore spot balance";
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address prevHook,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        if (data.length != DATA_LENGTH) revert DATA_NOT_VALID();

        uint256 amount = BytesLib.toUint256(data, AMOUNT_POSITION);
        if (_decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION)) {
            amount = ISuperHookResult(prevHook).getOutAmount(account);
        }
        if (amount == 0) revert AMOUNT_NOT_VALID();

        // Zero the allowance before and after: tokens with non-standard approve semantics, and any
        // residue from a partially-consumed prior approval, must not leave a standing allowance.
        executions = new Execution[](4);
        executions[0] =
            Execution({ target: TOKEN, value: 0, callData: abi.encodeCall(IERC20.approve, (GATEWAY, 0)) });
        executions[1] =
            Execution({ target: TOKEN, value: 0, callData: abi.encodeCall(IERC20.approve, (GATEWAY, amount)) });
        executions[2] = Execution({
            target: GATEWAY,
            value: 0,
            callData: abi.encodeCall(IHyperCoreDepositGateway.deposit, (amount, GATEWAY_ARG))
        });
        executions[3] =
            Execution({ target: TOKEN, value: 0, callData: abi.encodeCall(IERC20.approve, (GATEWAY, 0)) });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        amounts[0] = BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory) external pure override returns (ISuperHookInflowOutflow.AmountMeta[] memory meta) {
        meta = new ISuperHookInflowOutflow.AmountMeta[](1);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(
            ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN
        );
    }

    /// @dev This hook implements ISuperHookInflowOutflow + ISuperHookOutflow
    function _supportsSizingInterface() internal pure override returns (bool) {
        return true;
    }

    /// @inheritdoc ISuperHookOutflow
    function replaceCalldataAmounts(
        bytes memory data,
        uint256[] memory amounts
    )
        external
        pure
        override
        returns (bytes memory)
    {
        if (amounts.length != 1) revert INVALID_AMOUNTS_LENGTH();
        return _replaceCalldataAmount(data, amounts[0], AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInspector
    /// @dev PROTOCOL REQUIREMENT: inspector functions MUST only return addresses
    function inspect(bytes calldata) external view override returns (bytes memory) {
        return abi.encodePacked(TOKEN, GATEWAY);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata) internal override {
        _setOutAmount(IERC20(TOKEN).balanceOf(account), account);
    }

    function _postExecute(address, address account, bytes calldata) internal override {
        _setOutAmount(getOutAmount(account) - IERC20(TOKEN).balanceOf(account), account);
        _setOutToken(TOKEN, account);
    }
}
