// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IAaveV4Spoke } from "../../../vendor/aave-v4/IAaveV4Spoke.sol";

// Superform
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { BaseHook } from "../../BaseHook.sol";
import { BaseAaveV4LoanHook } from "./BaseAaveV4LoanHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import {
    ISuperHookResult,
    ISuperHookInspector,
    ISuperHookInflowOutflow
} from "../../../interfaces/ISuperHook.sol";

/// @title AaveV4RepayAndWithdrawHook
/// @author Superform Labs
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address spoke = BytesLib.toAddress(data, 92);
/// @notice         uint256 supplyReserveId = BytesLib.toUint256(data, 112);
/// @notice         uint256 borrowReserveId = BytesLib.toUint256(data, 144);
/// @notice         uint256 amount = BytesLib.toUint256(data, 176);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 208);
/// @notice         bool isFullRepayment = _decodeBool(data, 209);
/// @notice         uint256 withdrawAmount = BytesLib.toUint256(data, 210);
/// @dev KNOWN LIMITATION (P1-2): An attacker can front-run full repayment by repaying a small amount
///      on behalf of the borrower, causing the victim's transaction to revert. Mitigate by using
///      private mempools or adding slippage tolerance.
/// @dev KNOWN LIMITATION (P1-3): Interest accrues between build() and execute(). For full repayment,
///      the approval set during build() may be slightly stale. The off-chain bundler should
///      execute UserOps promptly after building.
contract AaveV4RepayAndWithdrawHook is BaseAaveV4LoanHook {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() BaseAaveV4LoanHook(HookSubTypes.LOAN_REPAY) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Aave V4 Repay and Withdraw";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Repays and withdraws assets from an Aave V4 lending pool";
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
        RepayAndWithdrawHookLocalVars memory vars = _decodeRepayAndWithdrawHookData(data);

        executions = new Execution[](5);
        executions[0] = Execution({
            target: vars.loanToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (vars.spoke, 0))
        });

        if (vars.isFullRepayment) {
            executions[1] = Execution({
                target: vars.loanToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (vars.spoke, type(uint256).max))
            });
            executions[2] = Execution({
                target: vars.spoke,
                value: 0,
                callData: abi.encodeCall(IAaveV4Spoke.repay, (vars.borrowReserveId, type(uint256).max, account))
            });
            executions[3] = Execution({
                target: vars.loanToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (vars.spoke, 0))
            });
            executions[4] = Execution({
                target: vars.spoke,
                value: 0,
                callData: abi.encodeCall(
                    IAaveV4Spoke.withdraw, (vars.supplyReserveId, type(uint256).max, account)
                )
            });
        } else {
            if (vars.usePrevHookAmount) {
                vars.amount = ISuperHookResult(prevHook).getOutAmount(account);
            }
            if (vars.amount == 0) revert AMOUNT_NOT_VALID();
            if (vars.withdrawAmount == 0) revert AMOUNT_NOT_VALID();

            executions[1] = Execution({
                target: vars.loanToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (vars.spoke, vars.amount))
            });
            executions[2] = Execution({
                target: vars.spoke,
                value: 0,
                callData: abi.encodeCall(IAaveV4Spoke.repay, (vars.borrowReserveId, vars.amount, account))
            });
            executions[3] = Execution({
                target: vars.loanToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (vars.spoke, 0))
            });
            executions[4] = Execution({
                target: vars.spoke,
                value: 0,
                callData: abi.encodeCall(IAaveV4Spoke.withdraw, (vars.supplyReserveId, vars.withdrawAmount, account))
            });
        }
    }

    /// @inheritdoc BaseAaveV4LoanHook
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = BytesLib.toUint256(data, AAVE_V4_AMOUNT_OFFSET);
        amounts[1] = BytesLib.toUint256(data, WITHDRAW_AMOUNT_OFFSET);
    }

    /// @inheritdoc BaseAaveV4LoanHook
    /// @dev IMPORTANT: When isFullRepayment is true in the data, build() uses type(uint256).max
    ///      for both repay and withdraw amounts — the amount fields are ignored at execution time.
    ///      The OMS should check isFullRepayment before relying on replaced amounts.
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
        data = _replaceCalldataAmount(data, amounts[0], AAVE_V4_AMOUNT_OFFSET);
        return _replaceCalldataAmount(data, amounts[1], WITHDRAW_AMOUNT_OFFSET);
    }

    /// @inheritdoc BaseAaveV4LoanHook
    function amountRoles(bytes memory)
        external
        pure
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        meta = new ISuperHookInflowOutflow.AmountMeta[](2);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        meta[1] = ISuperHookInflowOutflow.AmountMeta(ISuperHookInflowOutflow.Direction.OUT, ISuperHookInflowOutflow.Denomination.TOKEN);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        RepayAndWithdrawHookLocalVars memory vars = _decodeRepayAndWithdrawHookData(data);
        return abi.encodePacked(vars.spoke);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

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
