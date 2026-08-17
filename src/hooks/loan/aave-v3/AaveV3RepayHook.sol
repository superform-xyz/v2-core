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

/// @title AaveV3RepayHook
/// @author Superform Labs
/// @dev data layout (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address loanToken = BytesLib.toAddress(data, 52);  // repaid (debt) asset
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address pool = BytesLib.toAddress(data, 92);
/// @notice         uint8   interestRateMode = BytesLib.toUint8(data, 112);  // validated == 2
/// @notice         uint256 amount = BytesLib.toUint256(data, 113);  // type(uint256).max = full repay
/// @notice         bool usePrevHookAmount = _decodeBool(data, 145);
contract AaveV3RepayHook is BaseAaveV3LoanHook {
    constructor() BaseAaveV3LoanHook(HookSubTypes.LOAN_REPAY) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Aave V3 Repay";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Repays debt on an Aave V3 pool";
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
        // type(uint256).max (full repay) is allowed and is != 0.
        if (vars.amount == 0) revert AMOUNT_NOT_VALID();

        executions = new Execution[](4);
        executions[0] =
            Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.pool, 0)) });
        executions[1] = Execution({
            target: vars.loanToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (vars.pool, vars.amount))
        });
        executions[2] = Execution({
            target: vars.pool,
            value: 0,
            callData: abi.encodeCall(IPool.repay, (vars.loanToken, vars.amount, VARIABLE_RATE_MODE, account))
        });
        // Reset approval — critical even after repay(max), which leaves an infinite allowance otherwise.
        executions[3] =
            Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.pool, 0)) });
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        BorrowRepayVars memory vars = _decodeBorrowRepay(data);
        return abi.encodePacked(vars.pool);
    }

    /// @inheritdoc BaseHook
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getLoanTokenBalance(account, data), account);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getOutAmount(account) - getLoanTokenBalance(account, data), account);
        _setOutToken(getLoanTokenAddress(data), account);
    }
}
