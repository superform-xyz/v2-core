// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IPool } from "../../../vendor/aave-v3/IPool.sol";

// Superform
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { BaseHook } from "../../BaseHook.sol";
import { BaseAaveV3LoanHook } from "./BaseAaveV3LoanHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import {
    ISuperHookResult,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";

/// @title AaveV3RepayAndWithdrawHook
/// @author Superform Labs
/// @dev data layout (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address loanToken = BytesLib.toAddress(data, 52);   // repaid (debt) asset
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);  // withdrawn asset
/// @notice         address pool = BytesLib.toAddress(data, 92);
/// @notice         uint8   interestRateMode = BytesLib.toUint8(data, 112);  // validated == 2
/// @notice         uint256 repayAmount = BytesLib.toUint256(data, 113);  // usePrevHookAmount applies here; max = full
/// @notice         uint256 withdrawAmount = BytesLib.toUint256(data, 145);  // fixed calldata; max = full
/// @notice         bool usePrevHookAmount = _decodeBool(data, 177);
/// @dev outAmount tracks collateral withdrawn (post − pre). usePrevHookAmount applies to the repay leg
///      only; withdrawAmount is fixed calldata. A partial repay + fixed withdraw can revert on Aave's
///      HF check — the bundler owns consistent leg sizing.
contract AaveV3RepayAndWithdrawHook is BaseAaveV3LoanHook {
    constructor() BaseAaveV3LoanHook(HookSubTypes.LOAN_REPAY) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Aave V3 Repay and Withdraw";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Repays debt and withdraws collateral from an Aave V3 pool";
    }

    function _usePrevOffset() internal pure override returns (uint256) {
        return CB_USE_PREV_OFFSET;
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
        RepayAndWithdrawVars memory vars = _decodeRepayAndWithdraw(data);

        if (vars.usePrevHookAmount) {
            vars.repayAmount = ISuperHookResult(prevHook).getOutAmount(account);
        }
        if (vars.repayAmount == 0 || vars.withdrawAmount == 0) revert AMOUNT_NOT_VALID();

        executions = new Execution[](5);
        executions[0] =
            Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.pool, 0)) });
        executions[1] = Execution({
            target: vars.loanToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (vars.pool, vars.repayAmount))
        });
        executions[2] = Execution({
            target: vars.pool,
            value: 0,
            callData: abi.encodeCall(IPool.repay, (vars.loanToken, vars.repayAmount, VARIABLE_RATE_MODE, account))
        });
        // Reset approval — critical even after repay(max).
        executions[3] =
            Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.pool, 0)) });
        executions[4] = Execution({
            target: vars.pool,
            value: 0,
            callData: abi.encodeCall(IPool.withdraw, (vars.collateralToken, vars.withdrawAmount, account))
        });
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = BytesLib.toUint256(data, CB_AMOUNT1_OFFSET);
        amounts[1] = BytesLib.toUint256(data, CB_AMOUNT2_OFFSET);
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
        if (amounts.length != 2) revert INVALID_AMOUNTS_LENGTH();
        data = _replaceCalldataAmount(data, amounts[0], CB_AMOUNT1_OFFSET);
        return _replaceCalldataAmount(data, amounts[1], CB_AMOUNT2_OFFSET);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory)
        external
        pure
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        meta = new ISuperHookInflowOutflow.AmountMeta[](2);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(
            ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN
        );
        meta[1] = ISuperHookInflowOutflow.AmountMeta(
            ISuperHookInflowOutflow.Direction.OUT, ISuperHookInflowOutflow.Denomination.TOKEN
        );
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        RepayAndWithdrawVars memory vars = _decodeRepayAndWithdraw(data);
        return abi.encodePacked(vars.pool);
    }

    /// @inheritdoc BaseHook
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getCollateralTokenBalance(account, data), account);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getCollateralTokenBalance(account, data) - getOutAmount(account), account);
        _setOutToken(getCollateralTokenAddress(data), account);
    }
}
