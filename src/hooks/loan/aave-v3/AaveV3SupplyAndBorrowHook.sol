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

/// @title AaveV3SupplyAndBorrowHook
/// @author Superform Labs
/// @dev data layout (standard 52-byte strategy header + hook-specific):
/// @notice         address loanToken = BytesLib.toAddress(data, 52);   // borrowed asset
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);  // supplied asset
/// @notice         address pool = BytesLib.toAddress(data, 92);
/// @notice         uint8   interestRateMode = BytesLib.toUint8(data, 112);  // validated == 2
/// @notice         uint256 supplyAmount = BytesLib.toUint256(data, 113);  // usePrevHookAmount applies here
/// @notice         uint256 borrowAmount = BytesLib.toUint256(data, 145);  // fixed calldata (second leg)
/// @notice         bool usePrevHookAmount = _decodeBool(data, 177);
/// @dev outAmount tracks collateral consumed by the supply leg (pre − post), NOT the borrowed amount.
///      usePrevHookAmount applies to the supply leg only; borrowAmount is fixed calldata (the bundler
///      is responsible for consistent leg sizing — Aave enforces the HF≥1 floor).
contract AaveV3SupplyAndBorrowHook is BaseAaveV3LoanHook {
    constructor() BaseAaveV3LoanHook(HookSubTypes.LOAN) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Aave V3 Supply and Borrow";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Supplies collateral and borrows assets from an Aave V3 pool";
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
        SupplyAndBorrowVars memory vars = _decodeSupplyAndBorrow(data);

        if (vars.usePrevHookAmount) {
            vars.supplyAmount = ISuperHookResult(prevHook).getOutAmount(account);
        }
        if (vars.supplyAmount == 0 || vars.borrowAmount == 0) revert AMOUNT_NOT_VALID();

        executions = new Execution[](5);
        executions[0] = Execution({
            target: vars.collateralToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.pool, 0))
        });
        executions[1] = Execution({
            target: vars.collateralToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (vars.pool, vars.supplyAmount))
        });
        executions[2] = Execution({
            target: vars.pool,
            value: 0,
            callData: abi.encodeCall(IPool.supply, (vars.collateralToken, vars.supplyAmount, account, 0))
        });
        executions[3] = Execution({
            target: vars.pool,
            value: 0,
            callData: abi.encodeCall(IPool.borrow, (vars.loanToken, vars.borrowAmount, VARIABLE_RATE_MODE, 0, account))
        });
        executions[4] = Execution({
            target: vars.collateralToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.pool, 0))
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
        SupplyAndBorrowVars memory vars = _decodeSupplyAndBorrow(data);
        return abi.encodePacked(vars.pool);
    }

    /// @inheritdoc BaseHook
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getCollateralTokenBalance(account, data), account);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getOutAmount(account) - getCollateralTokenBalance(account, data), account);
        _setOutToken(getCollateralTokenAddress(data), account);
    }
}
