// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MorphoBalancesLib } from "../../../vendor/morpho/MorphoBalancesLib.sol";
import { IMorpho, IMorphoBase, MarketParams } from "../../../vendor/morpho/IMorpho.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseMorphoLoanHookV2 } from "./BaseMorphoLoanHookV2.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title MorphoRepayHookV2
/// @author Superform Labs
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address oracle = BytesLib.toAddress(data, 92);
/// @notice         address irm = BytesLib.toAddress(data, 112);
/// @notice         uint256 repayAmount = BytesLib.toUint256(data, 132); // type(uint256).max = full repayment
/// @notice         uint256 reserved = BytesLib.toUint256(data, 164); // must be zero
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 196);
/// @notice         uint256 lltv = BytesLib.toUint256(data, 197);
/// @notice         byte reserved2 = data[229]; // must be 0x00
/// @dev type(uint256).max is the only full-repayment sentinel and requires usePrevHookAmount ==
///      false. Full repayment approves the accrued debt (view-simulated to block.timestamp, exact
///      because build and the repay execute in the same transaction), repays the current borrow
///      shares, and resets the approval to zero in the same transaction. Repaying a zero-debt
///      position reverts before any approval. outAmount publishes the measured debt-token wallet
///      spend with outToken = loanToken.
/// @dev KNOWN LIMITATION (P1-2, unchanged vs V1): full repayment can be front-run by repaying
///      1 wei of shares on behalf of the borrower, making the victim's transaction revert.
///      Mitigate with private mempools.
contract MorphoRepayHookV2 is BaseMorphoLoanHookV2 {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param morpho_ Address of the Morpho Blue singleton
    constructor(address morpho_) BaseMorphoLoanHookV2(morpho_, HookSubTypes.LOAN_REPAY) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Morpho Repay V2";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Repays an exact amount or the full debt to a Morpho market";
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
        MorphoV2Vars memory vars = _decodeMorphoV2(data, true);
        MarketParams memory marketParams = _marketParams(vars);
        (uint256 repayAssets, uint256 borrowShares, bool fullRepay) =
            _resolveRepayLeg(prevHook, account, vars, marketParams);

        executions = new Execution[](4);
        executions[0] =
            Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0)) });
        executions[1] = Execution({
            target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, repayAssets))
        });
        executions[2] = Execution({
            target: morpho,
            value: 0,
            callData: fullRepay
                // repay by shares clears the entire debt regardless of interim accrual
                ? abi.encodeCall(IMorphoBase.repay, (marketParams, 0, borrowShares, account, ""))
                : abi.encodeCall(IMorphoBase.repay, (marketParams, repayAssets, 0, account, ""))
        });
        executions[3] =
            Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0)) });
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external view override returns (bytes memory) {
        return _inspectMorphoV2(_decodeMorphoV2(data, true));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Resolves the repay leg. Reverts before any approval/provider call when the account has
    ///      no outstanding debt, when a full-repayment sentinel is combined with
    ///      usePrevHookAmount, or when the previous-hook output is invalid.
    function _resolveRepayLeg(
        address prevHook,
        address account,
        MorphoV2Vars memory vars,
        MarketParams memory marketParams
    )
        internal
        view
        returns (uint256 repayAssets, uint256 borrowShares, bool fullRepay)
    {
        borrowShares = _borrowShares(marketParams, account);
        if (borrowShares == 0) revert NO_OUTSTANDING_DEBT();

        fullRepay = vars.amount1 == type(uint256).max;
        if (fullRepay) {
            if (vars.usePrevHookAmount) revert MAX_WITH_PREV_NOT_ALLOWED();
            repayAssets = MorphoBalancesLib.expectedBorrowAssets(IMorpho(morpho), marketParams, account);
        } else {
            repayAssets =
                vars.usePrevHookAmount ? _resolvePrevHookOutput(prevHook, account, vars.loanToken) : vars.amount1;
            if (repayAssets == 0) revert AMOUNT_NOT_VALID();
        }
    }

    /// @inheritdoc BaseHook
    /// @dev Accrues interest so the sentinel resolution below and the shares-denominated repay
    ///      price debt against identical market state, then stores the exact expected debt-token
    ///      spend and snapshots wallet balances
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        MorphoV2Vars memory vars = _decodeMorphoV2(data, true);
        _accrueInterest(vars);

        (uint256 repayAssets,,) = _resolveRepayLeg(prevHook, account, vars, _marketParams(vars));
        expectedPrimaryAmount = repayAssets;
        _snapshotBalances(account, data);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _settleRepay(account, data);
    }
}
