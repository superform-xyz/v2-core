// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { IIrm } from "../../../../vendor/morpho/IIrm.sol";
import { MathLib } from "../../../../vendor/morpho/MathLib.sol";
import { IOracle } from "../../../../vendor/morpho/IOracle.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SharesMathLib } from "../../../../vendor/morpho/SharesMathLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { MarketParamsLib } from "../../../../vendor/morpho/MarketParamsLib.sol";
import {
    IMorpho, IMorphoBase, IMorphoStaticTyping, MarketParams, Id, Market
} from "../../../../vendor/morpho/IMorpho.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseMorphoLoanHook } from "./BaseMorphoLoanHook.sol";
import { ISuperHook, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookLoans } from "../../../interfaces/ISuperHook.sol";
import { ISuperHookResult } from "../../../interfaces/ISuperHook.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

/// @title MorphoRepayHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address loanToken = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         address collateralToken = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
/// @notice         address oracle = BytesLib.toAddress(BytesLib.slice(data, 40, 20), 0);
/// @notice         address irm = BytesLib.toAddress(BytesLib.slice(data, 60, 20), 0);
/// @notice         uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 80, 32), 0);
/// @notice         uint256 lltv = BytesLib.toUint256(BytesLib.slice(data, 112, 32), 0);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 144);
/// @notice         bool isFullRepayment = _decodeBool(data, 145);
contract MorphoRepayHook is BaseMorphoLoanHook, ISuperHookInspector {
    using MarketParamsLib for MarketParams;
    using HookDataDecoder for bytes;
    using SharesMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/
    address public morpho;
    IMorphoBase public morphoBase;
    IMorphoStaticTyping public morphoStaticTyping;

    uint256 private constant AMOUNT_POSITION = 80;
    uint256 private constant PRICE_SCALING_FACTOR = 1e36;
    uint256 private constant PERCENTAGE_SCALING_FACTOR = 1e18;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 144;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address morpho_) BaseMorphoLoanHook(morpho_, HookSubTypes.LOAN_REPAY) {
        if (morpho_ == address(0)) revert ADDRESS_NOT_VALID();
        morpho = morpho_;
        morphoBase = IMorphoBase(morpho_);
        morphoInterface = IMorpho(morpho_);
        morphoStaticTyping = IMorphoStaticTyping(morpho_);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(
        address prevHook,
        address account,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        BuildHookLocalVars memory vars = _decodeHookData(data);

        if (vars.loanToken == address(0) || vars.collateralToken == address(0)) revert ADDRESS_NOT_VALID();

        MarketParams memory marketParams =
            _generateMarketParams(vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv);

        Id id = marketParams.id();

        uint256 fee = deriveFeeAmount(marketParams);
        executions = new Execution[](4);
        executions[0] =
            Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0)) });
        if (vars.isFullRepayment) {
            uint128 borrowBalance = deriveShareBalance(id, account);
            uint256 shareBalance = uint256(borrowBalance);
            uint256 assetsToPay = fee + deriveInterest(marketParams) + sharesToAssets(marketParams, account);

            executions[1] = Execution({
                target: vars.loanToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (morpho, assetsToPay))
            });
            executions[2] = Execution({
                target: morpho,
                value: 0,
                callData: abi.encodeCall(IMorphoBase.repay, (marketParams, 0, shareBalance, account, "")) // 0 assets
                    // shareBalance indicates full repayment
             });
        } else {
            if (vars.usePrevHookAmount) {
                vars.amount = ISuperHookResult(prevHook).outAmount();
            }
            _verifyAmount(vars.amount, marketParams);

            executions[1] = Execution({
                target: vars.loanToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (morpho, vars.amount))
            });
            executions[2] = Execution({
                target: morpho,
                value: 0,
                callData: abi.encodeCall(IMorphoBase.repay, (marketParams, vars.amount, 0, account, "")) // 0 shares and
                    // amount > 0 indicates partial repayment to Morpho
             });
        }
        executions[3] =
            Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0)) });
    }

    /// @inheritdoc ISuperHookLoans
    function getUsedAssets(address, bytes memory data) external view returns (uint256) {
        BuildHookLocalVars memory vars = _decodeHookData(data);
        uint256 amountInCollateral = deriveCollateralAmountFromLoanAmount(vars.oracle, outAmount);
        MarketParams memory marketParams =
            _generateMarketParams(vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv);
        return amountInCollateral + deriveFeeAmount(marketParams);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external view returns(address target, address[] memory args) {
        BuildHookLocalVars memory vars = _decodeHookData(data);

        MarketParams memory marketParams =
            _generateMarketParams(vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv);

        target = address(morpho);
        args = new address[](5);
        args[0] = marketParams.loanToken;
        args[1] = marketParams.collateralToken;
        args[2] = marketParams.oracle;
        args[3] = marketParams.irm;
        args[4] = tempAcc;
    }

    /// @inheritdoc ISuperHookInspector
    function beneficiaryArgs(bytes calldata) external pure returns (uint8[] memory idxs) {
        idxs = new uint8[](1);
        idxs[0] = 4;
    }
    /*//////////////////////////////////////////////////////////////
                            PUBLIC METHODS
    //////////////////////////////////////////////////////////////*/
    function deriveInterest(MarketParams memory marketParams) public view returns (uint256 interest) {
        Id id = marketParams.id();
        Market memory market = morphoInterface.market(id);
        uint256 borrowRate = IIrm(marketParams.irm).borrowRateView(marketParams, market);
        if (block.timestamp < market.lastUpdate) revert INVALID_TIMESTAMP();
        uint256 elapsed = block.timestamp - market.lastUpdate;
        interest = MathLib.wMulDown(market.totalBorrowAssets, MathLib.wTaylorCompounded(borrowRate, elapsed));
    }

    function deriveShareBalance(Id id, address account) public view returns (uint128 borrowShares) {
        (, borrowShares,) = morphoStaticTyping.position(id, account);
    }

    function deriveCollateralAmountFromLoanAmount(
        address oracle,
        uint256 loanAmount
    )
        public
        view
        returns (uint256 collateralAmount)
    {
        IOracle oracleInstance = IOracle(oracle);
        uint256 price = oracleInstance.price();

        collateralAmount = Math.mulDiv(loanAmount, price, PRICE_SCALING_FACTOR);
    }

    function sharesToAssets(MarketParams memory marketParams, address account) public view returns (uint256 assets) {
        Id id = marketParams.id();
        uint256 shareBalance = deriveShareBalance(id, account);
        Market memory market = morphoInterface.market(id);
        assets = shareBalance.toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        // store current balance
        outAmount = getCollateralTokenBalance(account, data);
        tempAcc = account;
    }

    function _postExecute(address, address, bytes calldata) internal override {
        outAmount = 0;
    }

    function _verifyAmount(uint256 amount, MarketParams memory marketParams) internal view {
        if (amount == 0) revert AMOUNT_NOT_VALID();
        uint256 fee = deriveFeeAmount(marketParams);
        uint256 interest = deriveInterest(marketParams);
        uint256 totalAmount = amount + fee + interest;
        if (amount < totalAmount) revert AMOUNT_NOT_VALID();
    }
}
