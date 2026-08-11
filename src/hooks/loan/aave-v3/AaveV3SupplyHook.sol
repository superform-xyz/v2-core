// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IPool } from "../../../vendor/aave-v3/IPool.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseAaveV3LoanHook } from "./BaseAaveV3LoanHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookResult, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title AaveV3SupplyHook
/// @author Superform Labs
/// @dev data layout (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);  // supplied asset
/// @notice         address pool = BytesLib.toAddress(data, 92);
/// @notice         uint256 amount = BytesLib.toUint256(data, 112);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 144);
/// @dev Aave V3 auto-enables collateral on first supply — NO setUserUseReserveAsCollateral call
///      (forcing it would revert on 0%-LTV reserves and override isolation-mode choices).
contract AaveV3SupplyHook is BaseAaveV3LoanHook {
    constructor() BaseAaveV3LoanHook(HookSubTypes.LOAN) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Aave V3 Supply";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Supplies assets to an Aave V3 pool";
    }

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
        SupplyWithdrawVars memory vars = _decodeSupplyWithdraw(data);

        if (vars.usePrevHookAmount) {
            vars.amount = ISuperHookResult(prevHook).getOutAmount(account);
        }
        if (vars.amount == 0) revert AMOUNT_NOT_VALID();

        executions = new Execution[](4);
        executions[0] = Execution({
            target: vars.collateralToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.pool, 0))
        });
        executions[1] = Execution({
            target: vars.collateralToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.pool, vars.amount))
        });
        executions[2] = Execution({
            target: vars.pool,
            value: 0,
            callData: abi.encodeCall(IPool.supply, (vars.collateralToken, vars.amount, account, 0))
        });
        // Reset approval after supply to prevent dangling allowance to the calldata pool.
        executions[3] = Execution({
            target: vars.collateralToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.pool, 0))
        });
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        SupplyWithdrawVars memory vars = _decodeSupplyWithdraw(data);
        return abi.encodePacked(vars.pool);
    }

    /// @inheritdoc BaseHook
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getCollateralTokenBalance(account, data), account);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getOutAmount(account) - getCollateralTokenBalance(account, data), account);
        _setOutToken(getCollateralTokenAddress(data), account);
    }
}
