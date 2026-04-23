// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IAaveV4Spoke } from "../../../vendor/aave-v4/IAaveV4Spoke.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseAaveV4LoanHook } from "./BaseAaveV4LoanHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookResult, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title AaveV4RepayAndWithdrawHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address loanToken = BytesLib.toAddress(data, 0);
/// @notice         address collateralToken = BytesLib.toAddress(data, 20);
/// @notice         address spoke = BytesLib.toAddress(data, 40);
/// @notice         uint256 supplyReserveId = BytesLib.toUint256(data, 60);
/// @notice         uint256 borrowReserveId = BytesLib.toUint256(data, 92);
/// @notice         uint256 amount = BytesLib.toUint256(data, 124);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 156);
/// @notice         bool isFullRepayment = _decodeBool(data, 157);
/// @notice         uint256 withdrawAmount = BytesLib.toUint256(data, 158);
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
    }
}
