// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IPool } from "../../../vendor/aave-v3/IPool.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseAaveV3LoanHook } from "./BaseAaveV3LoanHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookResult, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title AaveV3RepayWithATokensHook
/// @author Superform Labs
/// @notice Repays Aave V3 debt directly using the account's own aTokens (no underlying transfer / approval).
/// @dev data layout (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address loanToken = BytesLib.toAddress(data, 52);   // underlying debt asset (passed to Aave)
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);  // the aToken address (for balance-delta)
/// @notice         address pool = BytesLib.toAddress(data, 92);
/// @notice         uint8   interestRateMode = BytesLib.toUint8(data, 112);  // validated == 2
/// @notice         uint256 amount = BytesLib.toUint256(data, 113);  // type(uint256).max = repay min(debt, aTokenBal)
/// @notice         bool usePrevHookAmount = _decodeBool(data, 145);
/// @dev IMPORTANT: `repayWithATokens(max)` repays min(currentDebt, aTokenBalance). Unlike repay(max),
///      if the account's aToken balance < debt it SILENTLY leaves residual debt without reverting. A
///      chained withdraw(max) may then hit an HF revert or withdraw only part of the collateral.
///      There is no on-chain guard: the hook is a stateless builder and cannot read the account's
///      aToken balance vs. debt at build time.
///      MITIGATION (off-chain, bundler): do NOT chain `repayWithATokens(max) -> withdraw(max)` when the
///      account's aToken balance may be below its debt. For a guaranteed full-debt close, route
///      `AaveV3RepayHook(max)` (repays with the underlying) instead; otherwise size any follow-on
///      withdraw to the actual post-repay collateral rather than using the max sentinel.
///      collateralToken (offset 72) carries the aToken address so the base balance-delta helper
///      measures the burn; outToken is set to the underlying loanToken for consistency with AaveV3RepayHook.
contract AaveV3RepayWithATokensHook is BaseAaveV3LoanHook {
    constructor() BaseAaveV3LoanHook(HookSubTypes.LOAN_REPAY) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Aave V3 Repay With ATokens";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Repays Aave V3 debt using the account's aTokens";
    }

    function _amountOffset() internal pure override returns (uint256) {
        return BR_AMOUNT_OFFSET;
    }

    function _usePrevOffset() internal pure override returns (uint256) {
        return BR_USE_PREV_OFFSET;
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
        BorrowRepayVars memory vars = _decodeBorrowRepay(data);

        if (vars.usePrevHookAmount) {
            vars.amount = ISuperHookResult(prevHook).getOutAmount(account);
        }
        // type(uint256).max (repay min(debt, aTokenBal)) is allowed and is != 0.
        if (vars.amount == 0) revert AMOUNT_NOT_VALID();

        // No ERC20 approval: aTokens are burned directly from the account.
        executions = new Execution[](1);
        executions[0] = Execution({
            target: vars.pool,
            value: 0,
            callData: abi.encodeCall(IPool.repayWithATokens, (vars.loanToken, vars.amount, VARIABLE_RATE_MODE))
        });
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        BorrowRepayVars memory vars = _decodeBorrowRepay(data);
        return abi.encodePacked(vars.pool);
    }

    /// @inheritdoc BaseHook
    /// @dev collateralToken (offset 72) = aToken; measures aTokens burned.
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getCollateralTokenBalance(account, data), account);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getOutAmount(account) - getCollateralTokenBalance(account, data), account);
        // outToken = underlying (debt) asset, for consistency with AaveV3RepayHook.
        _setOutToken(getLoanTokenAddress(data), account);
    }
}
