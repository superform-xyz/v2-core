// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IAaveV4Spoke } from "../../../vendor/aave-v4/IAaveV4Spoke.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseAaveV4LoanHookV2 } from "./BaseAaveV4LoanHookV2.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookInspector, ISuperHookInflowOutflow, ISuperHookOutflow } from "../../../interfaces/ISuperHook.sol";

/// @title AaveV4RepayAndWithdrawHookV2
/// @author Superform Labs
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address spoke = BytesLib.toAddress(data, 92);
/// @notice         uint256 supplyReserveId = BytesLib.toUint256(data, 112);
/// @notice         uint256 borrowReserveId = BytesLib.toUint256(data, 144);
/// @notice         uint256 repayAmount = BytesLib.toUint256(data, 176); // type(uint256).max = full repayment
/// @notice         uint256 withdrawAmount = BytesLib.toUint256(data, 208); // type(uint256).max = full collateral
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 240);
/// @dev Repayment executes strictly before collateral withdrawal. Both legs are exact; the
///      withdrawal amount is never derived from the repayment. type(uint256).max is the only
///      sentinel: on the repay leg it resolves to the full debt (drawn + premium, Spoke-native)
///      and requires usePrevHookAmount == false; on the withdraw leg it resolves to the full
///      supplied balance (Spoke-native). Each reserve id must resolve to the declared token.
///      Repaying a zero-debt position reverts before any approval. outAmount publishes the actual
///      released collateral-token wallet delta with outToken = collateralToken.
contract AaveV4RepayAndWithdrawHookV2 is BaseAaveV4LoanHookV2 {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() BaseAaveV4LoanHookV2(HookSubTypes.LOAN_REPAY) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Aave V4 Repay and Withdraw V2";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Repays debt and withdraws an exact collateral amount from an Aave V4 spoke";
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
        AaveV4V2Vars memory vars = _decodeAaveV4V2(data, false);
        _validateReserves(vars);
        (uint256 repayAssets, bool fullRepay) = _resolveRepayLeg(prevHook, account, vars);
        // Validates the withdraw leg (zero amount / zero supplied balance under the sentinel)
        // before any provider call; the sentinel itself is passed through so the Spoke resolves it
        // natively
        _resolveWithdrawLeg(account, vars);

        executions = new Execution[](5);
        executions[0] =
            Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.spoke, 0)) });
        executions[1] = Execution({
            target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.spoke, repayAssets))
        });
        executions[2] = Execution({
            target: vars.spoke,
            value: 0,
            callData: abi.encodeCall(
                IAaveV4Spoke.repay, (vars.borrowReserveId, fullRepay ? type(uint256).max : repayAssets, account)
            )
        });
        // Reset approval — critical even after repay(max)
        executions[3] =
            Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.spoke, 0)) });
        // Withdrawal executes strictly after repayment
        executions[4] = Execution({
            target: vars.spoke,
            value: 0,
            callData: abi.encodeCall(IAaveV4Spoke.withdraw, (vars.supplyReserveId, vars.amount2, account))
        });
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        return _decodeTwoAmounts(data, AMOUNT1_OFFSET, AMOUNT2_OFFSET);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory)
        external
        pure
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        return _twoTokenRoles();
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
        return _replaceTwoAmounts(data, amounts, AMOUNT1_OFFSET, AMOUNT2_OFFSET);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return _inspectAaveV4V2(_decodeAaveV4V2(data, false));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Resolves the withdraw leg: exact amount, or the full supplied balance for the sentinel
    /// @param account The executing smart account
    /// @param vars The decoded hook parameters
    /// @return The exact collateral amount the withdraw call will release
    function _resolveWithdrawLeg(address account, AaveV4V2Vars memory vars) internal view returns (uint256) {
        if (vars.amount2 == 0) revert AMOUNT_NOT_VALID();
        if (vars.amount2 != type(uint256).max) return vars.amount2;
        uint256 supplied = _suppliedAssets(vars, account);
        if (supplied == 0) revert AMOUNT_NOT_VALID();
        return supplied;
    }

    /// @inheritdoc BaseHook
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        AaveV4V2Vars memory vars = _decodeAaveV4V2(data, false);
        _validateReserves(vars);
        (uint256 repayAssets,) = _resolveRepayLeg(prevHook, account, vars);

        expectedPrimaryAmount = repayAssets;
        expectedSecondaryAmount = _resolveWithdrawLeg(account, vars);
        _snapshotBalances(account, data);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _settleClose(account, data);
    }
}
