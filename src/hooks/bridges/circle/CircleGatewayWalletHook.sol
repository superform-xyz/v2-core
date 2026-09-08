// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../../hooks/BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookResult, ISuperHookInflowOutflow, ISuperHookOutflow, ISuperHookContextAware } from "../../../interfaces/ISuperHook.sol";

import { IGatewayWallet } from "../../../vendor/circle/IGatewayWallet.sol";

/// @title CircleGatewayWalletHook
/// @author Superform Labs
/// @notice Hook for approving and depositing tokens to Circle Gateway Wallet
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address usdc = BytesLib.toAddress(data, 52);
/// @notice         uint256 amount = BytesLib.toUint256(data, 72);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 104);
contract CircleGatewayWalletHook is BaseHook, ISuperHookInflowOutflow, ISuperHookOutflow, ISuperHookContextAware {
    using BytesLib for bytes;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Circle Gateway Wallet contract address
    address public immutable GATEWAY_WALLET;

    uint256 private constant AMOUNT_POSITION = 72;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 104;

    constructor(address gatewayWalletAddress) BaseHook(HookType.NONACCOUNTING, HookSubTypes.BRIDGE) {
        if (gatewayWalletAddress == address(0)) revert ADDRESS_NOT_VALID();
        GATEWAY_WALLET = gatewayWalletAddress;
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Circle Gateway Wallet";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Interacts with Circle Gateway wallet for cross-chain transfers";
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
        address usdc = BytesLib.toAddress(data, 52);
        uint256 amount = BytesLib.toUint256(data, AMOUNT_POSITION);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).getOutAmount(account);
        }

        if (usdc == address(0)) revert ADDRESS_NOT_VALID();
        if (amount == 0) revert AMOUNT_NOT_VALID();

        executions = new Execution[](4);

        // First reset approval to 0
        executions[0] =
            Execution({ target: usdc, value: 0, callData: abi.encodeCall(IERC20.approve, (GATEWAY_WALLET, 0)) });

        // Then approve the actual amount
        executions[1] =
            Execution({ target: usdc, value: 0, callData: abi.encodeCall(IERC20.approve, (GATEWAY_WALLET, amount)) });

        // Finally deposit to Gateway Wallet
        executions[2] = Execution({
            target: GATEWAY_WALLET,
            value: 0,
            callData: abi.encodeCall(IGatewayWallet.deposit, (usdc, amount))
        });

        // Reset approval to 0
        executions[3] =
            Execution({ target: usdc, value: 0, callData: abi.encodeCall(IERC20.approve, (GATEWAY_WALLET, 0)) });
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
        meta[0] = ISuperHookInflowOutflow.AmountMeta(ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
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

    /// @notice Decode the usdc from hook data
    /// @param data The hook data to decode
    /// @return The usdc address
    function decodeToken(bytes memory data) external pure returns (address) {
        return BytesLib.toAddress(data, 52);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Publishes the effective deposited amount and token as this hook's output
    /// @param prevHook The previous hook in the chain, source of the amount when usePrevHookAmount is set
    /// @param account The account the deposit was performed for
    /// @param data Hook calldata containing the token, static amount and usePrevHookAmount flag
    function _postExecute(address prevHook, address account, bytes calldata data) internal override {
        uint256 amount = BytesLib.toUint256(data, AMOUNT_POSITION);
        // Must mirror the amount resolution in _buildHookExecutions: when usePrevHookAmount is set,
        // the deposit used the previous hook's output, so the static encoded amount is stale here.
        if (_decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION)) {
            amount = ISuperHookResult(prevHook).getOutAmount(account);
        }
        _setOutAmount(amount, account);
        _setOutToken(BytesLib.toAddress(data, 52), account);
    }
}
