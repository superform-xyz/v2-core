// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookResult, ISuperHookContextAware, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title WithdrawWETHHook
/// @author Superform Labs
/// @notice Hook for converting WETH to ETH by calling the WETH withdraw function
/// @dev data has the following structure:
///      uint256 amount = BytesLib.toUint256(data, 0);
///      bool usePrevHookAmount = _decodeBool(data, 32);
contract WithdrawWETHHook is BaseHook, ISuperHookContextAware {
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
    
    /// @notice Thrown when the WETH amount to withdraw is zero
    error ZERO_WETH_AMOUNT();

    /// @notice Thrown when account has insufficient WETH balance
    error INSUFFICIENT_WETH_BALANCE();

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

        if (amount == 0) revert ZERO_WETH_AMOUNT();

        // Verify account has sufficient WETH balance
        uint256 wethBalance = IERC20(WETH).balanceOf(account);
        if (wethBalance < amount) revert INSUFFICIENT_WETH_BALANCE();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: WETH,
            value: 0,
            callData: abi.encodeWithSignature("withdraw(uint256)", amount)
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
    
    /// @notice Sets the initial WETH balance as outAmount before execution
    function _preExecute(address, address account, bytes calldata) internal override {
        uint256 wethBalance = IERC20(WETH).balanceOf(account);
        _setOutAmount(wethBalance, account);
    }

    /// @notice Updates outAmount with the WETH balance difference after withdrawal
    function _postExecute(address, address account, bytes calldata) internal override {
        uint256 previousWethBalance = getOutAmount(account);
        uint256 currentWethBalance = IERC20(WETH).balanceOf(account);
        
        // The difference should equal the amount withdrawn from WETH (converted to ETH)
        _setOutAmount(previousWethBalance - currentWethBalance, account);
    }
}