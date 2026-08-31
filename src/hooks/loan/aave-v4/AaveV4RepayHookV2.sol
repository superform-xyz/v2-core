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
import { ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title AaveV4RepayHookV2
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
/// @notice         uint256 reserved = BytesLib.toUint256(data, 208); // must be zero
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 240);
/// @dev type(uint256).max is the only full-repayment sentinel and requires usePrevHookAmount ==
///      false; the Spoke resolves the full debt (drawn + premium) natively. Each reserve id must
///      resolve to the declared token. Repaying a zero-debt position reverts before any approval.
///      outAmount publishes the measured debt-token wallet spend with outToken = loanToken.
contract AaveV4RepayHookV2 is BaseAaveV4LoanHookV2 {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() BaseAaveV4LoanHookV2(HookSubTypes.LOAN_REPAY) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Aave V4 Repay V2";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Repays an exact amount or the full debt to an Aave V4 spoke";
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
        AaveV4V2Vars memory vars = _decodeAaveV4V2(data, true);
        _validateReserves(vars);
        (uint256 repayAssets, bool fullRepay) = _resolveRepayLeg(prevHook, account, vars);

        executions = new Execution[](4);
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
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return _inspectAaveV4V2(_decodeAaveV4V2(data, true));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        AaveV4V2Vars memory vars = _decodeAaveV4V2(data, true);
        _validateReserves(vars);
        (uint256 repayAssets,) = _resolveRepayLeg(prevHook, account, vars);

        expectedPrimaryAmount = repayAssets;
        _snapshotBalances(account, data);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _settleRepay(account, data);
    }
}
