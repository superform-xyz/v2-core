// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { IOracle } from "../../../../vendor/morpho/IOracle.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IMorphoBase, MarketParams } from "../../../../vendor/morpho/IMorpho.sol";

// Superform
import { BaseMorphoLoanHook } from "./BaseMorphoLoanHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookLoans } from "../../../interfaces/ISuperHook.sol";
import { ISuperHookResult } from "../../../interfaces/ISuperHook.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISuperHook, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title MorphoSupplyAndBorrowHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address loanToken = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         address collateralToken = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
/// @notice         address oracle = BytesLib.toAddress(BytesLib.slice(data, 40, 20), 0);
/// @notice         address irm = BytesLib.toAddress(BytesLib.slice(data, 60, 20), 0);
/// @notice         uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 80, 32), 0);
/// @notice         uint256 ltvRatio = BytesLib.toUint256(BytesLib.slice(data, 112, 32), 0);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 144);
/// @notice         uint256 lltv = BytesLib.toUint256(BytesLib.slice(data, 145, 32), 0);
/// @notice         bool placeholder = _decodeBool(data, 177);
contract MorphoBorrowHook is BaseMorphoLoanHook, ISuperHookInspector {
    using HookDataDecoder for bytes;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/
    address public morpho;
    IMorphoBase public morphoBase;

    uint256 private constant AMOUNT_POSITION = 80;
    uint256 private constant PRICE_SCALING_FACTOR = 1e36;
    uint256 private constant PERCENTAGE_SCALING_FACTOR = 1e18;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 144;

    struct BorrowHookLocalVars {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 amount;
        uint256 ltvRatio;
        bool usePrevHookAmount;
        uint256 lltv;
    }

    error LTV_RATIO_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address morpho_) BaseMorphoLoanHook(morpho_, HookSubTypes.LOAN) {
        if (morpho_ == address(0)) revert ADDRESS_NOT_VALID();
        morpho = morpho_;
        morphoBase = IMorphoBase(morpho_);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW METHODS
    //////////////////////////////////////////////////////////////*/
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
        BorrowHookLocalVars memory vars = _decodeBorrowHookData(data);

        if (vars.usePrevHookAmount) {
            vars.amount = ISuperHookResult(prevHook).outAmount();
        }

        if (vars.amount == 0) revert AMOUNT_NOT_VALID();
        if (vars.loanToken == address(0) || vars.collateralToken == address(0)) revert ADDRESS_NOT_VALID();

        MarketParams memory marketParams =
            _generateMarketParams(vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv);

        executions = new Execution[](1);
        executions[0] = Execution({
            target: morpho,
            value: 0,
            callData: abi.encodeCall(IMorphoBase.borrow, (marketParams, vars.amount, 0, account, account))
        });
    }

    /// @inheritdoc ISuperHookLoans
    function getUsedAssets(address, bytes memory) external view returns (uint256) {
        return outAmount;
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure returns (bytes memory) {
        BorrowHookLocalVars memory vars = _decodeBorrowHookData(data);

        MarketParams memory marketParams =
            _generateMarketParams(vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv);

        return abi.encodePacked(
            marketParams.loanToken, marketParams.collateralToken, marketParams.oracle, marketParams.irm
        );
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _decodeBorrowHookData(bytes memory data) internal pure returns (BorrowHookLocalVars memory vars) {
        address loanToken = BytesLib.toAddress(data, 0);
        address collateralToken = BytesLib.toAddress(data, 20);
        address oracle = BytesLib.toAddress(data, 40);
        address irm = BytesLib.toAddress(data, 60);
        uint256 amount = _decodeAmount(data);
        uint256 ltvRatio = BytesLib.toUint256(data, 112);
        bool usePrevHookAmount = _decodeBool(data, 144);
        uint256 lltv = BytesLib.toUint256(data, 145);

        return BorrowHookLocalVars({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: oracle,
            irm: irm,
            amount: amount,
            ltvRatio: ltvRatio,
            usePrevHookAmount: usePrevHookAmount,
            lltv: lltv
        });
    }

    function _preExecute(address, address account, bytes calldata data) internal override {
        // store current balance
        outAmount = getLoanTokenBalance(account, data);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        outAmount = getLoanTokenBalance(account, data) - outAmount;
    }
}
