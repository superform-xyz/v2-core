// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookResult, ISuperHookContextAware, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title DepositWETHHook
/// @author Superform Labs
/// @notice Hook for converting ETH to WETH by calling the WETH deposit function
/// @dev data has the following structure:
///      uint256 amount = BytesLib.toUint256(data, 0);
///      bool usePrevHookAmount = _decodeBool(data, 32);
contract DepositWETHHook is BaseHook, ISuperHookContextAware {
    /*//////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    
    /// @notice The WETH contract address
    address public immutable WETH;
    
    /// @notice Position of the usePrevHookAmount flag in the hook data
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 32;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Thrown when the ETH amount to deposit is zero
    error ZERO_ETH_AMOUNT();

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address weth) BaseHook(HookType.NONACCOUNTING, HookSubTypes.TOKEN) {
        WETH = weth;
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
        uint256 amount = BytesLib.toUint256(data, 0);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).getOutAmount(account);
        }

        if (amount == 0) revert ZERO_ETH_AMOUNT();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: WETH,
            value: amount,
            callData: abi.encodeWithSignature("deposit()")
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
    function inspect(bytes calldata) external view override returns (bytes memory) {
        return abi.encodePacked(
            WETH // WETH contract address
        );
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Sets the initial ETH balance as outAmount before execution
    function _preExecute(address, address account, bytes calldata) internal override {
        _setOutAmount(account.balance, account);
    }

    /// @notice Updates outAmount with the ETH balance difference after WETH deposit
    function _postExecute(address, address account, bytes calldata) internal override {
        uint256 previousBalance = getOutAmount(account);
        uint256 currentBalance = account.balance;
        
        // The difference should equal the amount deposited to WETH
        _setOutAmount(previousBalance - currentBalance, account);
    }
}