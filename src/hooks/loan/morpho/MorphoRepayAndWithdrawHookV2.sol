// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IMorphoBase, MarketParams } from "../../../vendor/morpho/IMorpho.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseMorphoLoanHookV2 } from "./BaseMorphoLoanHookV2.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookInspector, ISuperHookInflowOutflow, ISuperHookOutflow } from "../../../interfaces/ISuperHook.sol";

/// @title MorphoRepayAndWithdrawHookV2
/// @author Superform Labs
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address oracle = BytesLib.toAddress(data, 92);
/// @notice         address irm = BytesLib.toAddress(data, 112);
/// @notice         uint256 repayAmount = BytesLib.toUint256(data, 132); // type(uint256).max = full repayment
/// @notice         uint256 withdrawAmount = BytesLib.toUint256(data, 164); // type(uint256).max = full collateral
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 196);
/// @notice         uint256 lltv = BytesLib.toUint256(data, 197);
/// @notice         byte reserved = data[229]; // must be 0x00
/// @dev Repayment executes strictly before collateral withdrawal. Both legs are exact; the
///      withdrawal amount is never derived proportionally from the repayment. type(uint256).max is
///      the only sentinel: on the repay leg it resolves to the accrued debt (repaid by shares) and
///      requires usePrevHookAmount == false; on the withdraw leg it resolves to the position's
///      full collateral. Repaying a zero-debt position reverts before any approval. outAmount
///      publishes the actual released collateral-token wallet delta with outToken =
///      collateralToken.
/// @dev KNOWN LIMITATION (griefing): the full-repayment sentinel resolves the debt live at
///      execution, so it is robust to a partial third-party repayment. Only a *complete*
///      third-party repayment (a donation clearing the whole debt) makes the victim's transaction
///      revert with NO_OUTSTANDING_DEBT; an exact non-sentinel repayAmount can additionally be
///      griefed by a 1-wei third-party repay shifting the debt below the signed amount. Emit the
///      sentinel for close intents and mitigate with private mempools.
contract MorphoRepayAndWithdrawHookV2 is BaseMorphoLoanHookV2 {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param morpho_ Address of the Morpho Blue singleton
    constructor(address morpho_) BaseMorphoLoanHookV2(morpho_, HookSubTypes.LOAN_REPAY) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Morpho Repay and Withdraw V2";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Repays debt and withdraws an exact collateral amount from a Morpho market";
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
        MorphoV2Vars memory vars = _decodeMorphoV2(data, false);
        MarketParams memory marketParams = _marketParams(vars);
        (uint256 repayAssets, uint256 borrowShares, bool fullRepay) =
            _resolveRepayLeg(prevHook, account, vars, marketParams);
        uint256 withdrawAmount = _resolveWithdrawLeg(account, vars, marketParams);

        executions = new Execution[](5);
        executions[0] =
            Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0)) });
        executions[1] = Execution({
            target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, repayAssets))
        });
        executions[2] = Execution({
            target: morpho,
            value: 0,
            callData: fullRepay
                ? abi.encodeCall(IMorphoBase.repay, (marketParams, 0, borrowShares, account, ""))
                : abi.encodeCall(IMorphoBase.repay, (marketParams, repayAssets, 0, account, ""))
        });
        executions[3] =
            Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0)) });
        // Withdrawal executes strictly after repayment
        executions[4] = Execution({
            target: morpho,
            value: 0,
            callData: abi.encodeCall(IMorphoBase.withdrawCollateral, (marketParams, withdrawAmount, account, account))
        });
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        return _decodeTwoAmounts(data, AMOUNT_POSITION, AMOUNT2_OFFSET);
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
        return _replaceTwoAmounts(data, amounts, AMOUNT_POSITION, AMOUNT2_OFFSET);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external view override returns (bytes memory) {
        return _inspectMorphoV2(_decodeMorphoV2(data, false));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Resolves the withdraw leg: exact amount, or the position's full collateral for the
    ///      type(uint256).max sentinel. Never derived proportionally from the repayment.
    /// @param account The executing smart account
    /// @param vars The decoded hook parameters
    /// @param marketParams The Morpho market params derived from `vars`
    /// @return withdrawAmount The exact collateral amount the withdraw call will release
    function _resolveWithdrawLeg(
        address account,
        MorphoV2Vars memory vars,
        MarketParams memory marketParams
    )
        internal
        view
        returns (uint256 withdrawAmount)
    {
        if (vars.amount2 == 0) revert AMOUNT_NOT_VALID();
        if (vars.amount2 != type(uint256).max) return vars.amount2;
        withdrawAmount = _positionCollateral(marketParams, account);
        if (withdrawAmount == 0) revert AMOUNT_NOT_VALID();
    }

    /// @inheritdoc BaseHook
    /// @dev Accrues interest, then stores the exact expected legs and snapshots wallet balances
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        MorphoV2Vars memory vars = _decodeMorphoV2(data, false);
        _accrueInterest(vars);

        MarketParams memory marketParams = _marketParams(vars);
        (uint256 repayAssets,,) = _resolveRepayLeg(prevHook, account, vars, marketParams);
        expectedPrimaryAmount = repayAssets;
        expectedSecondaryAmount = _resolveWithdrawLeg(account, vars, marketParams);
        _snapshotBalances(account, data);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _settleClose(account, data);
    }
}
