// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MarketParamsLib } from "../../../../vendor/morpho/MarketParamsLib.sol";
import { IMorphoBase, MarketParams } from "../../../../vendor/morpho/IMorpho.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseMorphoLoanHook } from "./BaseMorphoLoanHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title MorphoWithdrawHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address loanToken = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         address collateralToken = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
/// @notice         address oracle = BytesLib.toAddress(BytesLib.slice(data, 40, 20), 0);
/// @notice         address irm = BytesLib.toAddress(BytesLib.slice(data, 60, 20), 0);
/// @notice         address onBehalf = BytesLib.toAddress(BytesLib.slice(data, 80, 20), 0);
/// @notice         address recipient = BytesLib.toAddress(BytesLib.slice(data, 100, 20), 0);
/// @notice         uint256 lltv = BytesLib.toUint256(BytesLib.slice(data, 120, 32), 0);
/// @notice         uint256 assets = BytesLib.toUint256(BytesLib.slice(data, 152, 32), 0);
/// @notice         uint256 shares = BytesLib.toUint256(BytesLib.slice(data, 184, 32), 0);
contract MorphoWithdrawHook is BaseMorphoLoanHook, ISuperHookInspector {
    using MarketParamsLib for MarketParams;
    using HookDataDecoder for bytes;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/
    address public morpho;
    IMorphoBase public morphoBase;

    struct WithdrawHookVars {
        MarketParams marketParams;
        address onBehalf;
        address receiver;
        uint256 assets;
        uint256 shares;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address morpho_) BaseMorphoLoanHook(morpho_, HookSubTypes.LOAN_REPAY) {
        if (morpho_ == address(0)) revert ADDRESS_NOT_VALID();
        morpho = morpho_;
        morphoBase = IMorphoBase(morpho_);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address,
        address,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        WithdrawHookVars memory vars = _decodeWithdrawData(data);
        if (vars.assets == 0 && vars.shares == 0) revert AMOUNT_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: morpho,
            value: 0,
            callData: abi.encodeCall(
                IMorphoBase.withdraw, (vars.marketParams, vars.assets, vars.shares, vars.onBehalf, vars.receiver)
            )
        });
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure returns (bytes memory) {
        WithdrawHookVars memory vars = _decodeWithdrawData(data);

        return abi.encodePacked(
            vars.marketParams.loanToken,
            vars.marketParams.collateralToken,
            vars.marketParams.oracle,
            vars.marketParams.irm
        );
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address, bytes calldata data) internal override {
        address recipient = BytesLib.toAddress(data, 100);
        // store current balance
        setOutAmount(getCollateralTokenBalance(recipient, data), recipient);
    }

    function _postExecute(address, address, bytes calldata data) internal override {
        address recipient = BytesLib.toAddress(data, 100);
        setOutAmount(getCollateralTokenBalance(recipient, data) - getOutAmount(recipient), recipient);
    }

    function _decodeWithdrawData(bytes calldata data) internal pure returns (WithdrawHookVars memory vars) {
        address loanToken = BytesLib.toAddress(data, 0);
        address collateralToken = BytesLib.toAddress(data, 20);
        address oracle = BytesLib.toAddress(data, 40);
        address irm = BytesLib.toAddress(data, 60);
        address onBehalf = BytesLib.toAddress(data, 80);
        address recipient = BytesLib.toAddress(data, 100);
        uint256 lltv = BytesLib.toUint256(data, 120);
        uint256 assets = BytesLib.toUint256(data, 152);
        uint256 shares = BytesLib.toUint256(data, 184);

        if (loanToken == address(0) || collateralToken == address(0) || oracle == address(0) || irm == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

        MarketParams memory marketParams = _generateMarketParams(loanToken, collateralToken, oracle, irm, lltv);

        vars = WithdrawHookVars({
            marketParams: marketParams,
            onBehalf: onBehalf,
            receiver: recipient,
            assets: assets,
            shares: shares
        });
    }
}
