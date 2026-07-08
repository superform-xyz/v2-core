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

/// @title AaveV4RepayHook
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
/// @dev KNOWN LIMITATION (P1-2): An attacker can front-run full repayment by repaying a small amount
///      on behalf of the borrower, causing the victim's transaction to revert. Mitigate by using
///      private mempools or adding slippage tolerance.
/// @dev KNOWN LIMITATION (P1-3): Interest accrues between build() and execute(). For full repayment,
///      the approval set during build() may be slightly stale. The off-chain bundler should
///      execute UserOps promptly after building.
contract AaveV4RepayHook is BaseAaveV4LoanHook {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() BaseAaveV4LoanHook(HookSubTypes.LOAN_REPAY) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Aave V4 Repay";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Repays borrowed assets to an Aave V4 lending pool";
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
        RepayHookLocalVars memory vars = _decodeRepayHookData(data);

        executions = new Execution[](4);
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
        } else {
            if (vars.usePrevHookAmount) {
                vars.amount = ISuperHookResult(prevHook).getOutAmount(account);
            }
            if (vars.amount == 0) revert AMOUNT_NOT_VALID();

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
        }

        executions[3] = Execution({
            target: vars.loanToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (vars.spoke, 0))
        });
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        RepayHookLocalVars memory vars = _decodeRepayHookData(data);
        return abi.encodePacked(vars.spoke);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

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
