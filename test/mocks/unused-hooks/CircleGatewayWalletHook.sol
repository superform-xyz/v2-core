// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../../src/hooks/BaseHook.sol";
import { HookSubTypes } from "../../../src/libraries/HookSubTypes.sol";
import { ISuperHookResult, ISuperHookContextAware } from "../../../src/interfaces/ISuperHook.sol";

// Circle Gateway
interface IGatewayWallet {
    function deposit(address token, uint256 value) external;
}

/// @title CircleGatewayWalletHook
/// @author Superform Labs
/// @notice Hook for approving and depositing tokens to Circle Gateway Wallet
/// @dev data has the following structure:
/// @notice         address token = BytesLib.toAddress(data, 0);
/// @notice         uint256 amount = BytesLib.toUint256(data, 20);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 52);
contract CircleGatewayWalletHook is BaseHook, ISuperHookContextAware {
    using BytesLib for bytes;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Circle Gateway Wallet contract address
    address public constant GATEWAY_WALLET = 0x0077777d7EBA4688BDeF3E311b846F25870A19B9;

    uint256 private constant AMOUNT_POSITION = 20;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 52;

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.BRIDGE) { }

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
        address token = BytesLib.toAddress(data, 0);
        uint256 amount = BytesLib.toUint256(data, AMOUNT_POSITION);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).getOutAmount(account);
        }

        if (token == address(0)) revert ADDRESS_NOT_VALID();
        if (amount == 0) revert AMOUNT_NOT_VALID();

        // Build executions: approve(0), approve(amount), deposit
        executions = new Execution[](3);
        
        // First reset approval to 0
        executions[0] = Execution({
            target: token,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (GATEWAY_WALLET, 0))
        });
        
        // Then approve the actual amount
        executions[1] = Execution({
            target: token,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (GATEWAY_WALLET, amount))
        });
        
        // Finally deposit to Gateway Wallet
        executions[2] = Execution({
            target: GATEWAY_WALLET,
            value: 0,
            callData: abi.encodeCall(IGatewayWallet.deposit, (token, amount))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @notice Decode the amount from hook data
    /// @param data The hook data to decode
    /// @return The amount value
    function decodeAmount(bytes memory data) external pure returns (uint256) {
        return BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    /// @notice Decode the token from hook data
    /// @param data The hook data to decode
    /// @return The token address
    function decodeToken(bytes memory data) external pure returns (address) {
        return BytesLib.toAddress(data, 0);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    
    function _preExecute(address, address, bytes calldata) internal override {
        // No pre-execution logic needed
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        uint256 amount = BytesLib.toUint256(data, AMOUNT_POSITION);
        // Set the deposited amount as output
        _setOutAmount(amount, account);
    }
}