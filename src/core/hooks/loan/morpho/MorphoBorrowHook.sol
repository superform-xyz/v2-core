// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { IOracle } from "../../../../vendor/morpho/IOracle.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IMorphoBase, MarketParams } from "../../../../vendor/morpho/IMorpho.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { ISuperHook } from "../../../interfaces/ISuperHook.sol";
import { ISuperHookResult } from "../../../interfaces/ISuperHook.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISuperHookContextAware } from "../../../interfaces/ISuperHook.sol";

/// @title MorphoBorrowHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address loanToken = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         address collateralToken = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
/// @notice         address oracle = BytesLib.toAddress(BytesLib.slice(data, 40, 20), 0);
/// @notice         address irm = BytesLib.toAddress(BytesLib.slice(data, 60, 20), 0);
/// @notice         uint256 collateralAmount = BytesLib.toUint256(BytesLib.slice(data, 80, 32), 0);
/// @notice         uint256 lltv = BytesLib.toUint256(BytesLib.slice(data, 112, 32), 0);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 144);
/// @notice         bool isPositiveFeed = _decodeBool(data, 145);
contract MorphoBorrowHook is BaseHook, ISuperHookContextAware {
    using HookDataDecoder for bytes;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/
    address public morpho;
    IMorphoBase public morphoInterface;

    uint256 private constant AMOUNT_POSITION = 80;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 144;

    struct BuildHookLocalVars {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 collateralAmount;
        uint256 lltv;
        bool usePrevHookAmount;
        bool isPositiveFeed;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address registry_, address morpho_) BaseHook(registry_, HookType.NONACCOUNTING) {
        if (morpho_ == address(0)) revert ADDRESS_NOT_VALID();
        morpho = morpho_;
        morphoInterface = IMorphoBase(morpho_);
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

        if (vars.usePrevHookAmount) {
            vars.collateralAmount = ISuperHookResult(prevHook).outAmount();
        }

        if (vars.collateralAmount == 0) revert AMOUNT_NOT_VALID();
        if (vars.loanToken == address(0) || vars.collateralToken == address(0)) revert ADDRESS_NOT_VALID();

        MarketParams memory marketParams =
            _generateMarketParams(vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv);

        uint256 loanAmount = _deriveLoanAmount(
            vars.collateralAmount, vars.oracle, vars.loanToken, vars.collateralToken, vars.isPositiveFeed
        );

        executions = new Execution[](4);
        executions[0] =
            Execution({ target: vars.collateralToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0)) });
        executions[1] = Execution({
            target: vars.collateralToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (morpho, vars.collateralAmount))
        });
        executions[2] = Execution({
            target: morpho,
            value: 0,
            callData: abi.encodeCall(IMorphoBase.supplyCollateral, (marketParams, vars.collateralAmount, account, ""))
        });
        executions[3] = Execution({
            target: morpho,
            value: 0,
            callData: abi.encodeCall(IMorphoBase.borrow, (marketParams, loanAmount, 0, account, account)) // derive loan
                // amount from collateral amount
         });
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    function _decodeHookData(bytes memory data) internal pure returns (BuildHookLocalVars memory vars) {
        address loanToken = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        address collateralToken = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
        address oracle = BytesLib.toAddress(BytesLib.slice(data, 40, 20), 0);
        address irm = BytesLib.toAddress(BytesLib.slice(data, 60, 20), 0);
        uint256 collateralAmount = _decodeAmount(data);
        uint256 lltv = BytesLib.toUint256(BytesLib.slice(data, 112, 32), 0);
        bool usePrevHookAmount = _decodeBool(BytesLib.slice(data, 144, 1), 0);
        bool isPositiveFeed = _decodeBool(BytesLib.slice(data, 145, 1), 0);

        vars = BuildHookLocalVars({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: oracle,
            irm: irm,
            collateralAmount: collateralAmount,
            lltv: lltv,
            usePrevHookAmount: usePrevHookAmount,
            isPositiveFeed: isPositiveFeed
        });
    }

    function _preExecute(address, address account, bytes calldata data) internal override {
        // store current balance
        outAmount = _getLoanBalance(account, data);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        outAmount = _getLoanBalance(account, data) - outAmount;
    }

    /// @dev This function returns the loan amount required for a given collateral amount.
    /// @dev It corresponds to the price of 10**(collateral token decimals) assets of collateral token quoted in
    /// 10**(loan token decimals) assets of loan token with `36 + loan token decimals - collateral token decimals`
    /// decimals of precision.
    function _deriveLoanAmount(
        uint256 collateralAmount,
        address oracleAddress,
        address loanToken,
        address collateralToken,
        bool isPositiveFeed
    )
        internal
        view
        returns (uint256 loanAmount)
    {
        IOracle oracleInstance = IOracle(oracleAddress);
        uint256 price = oracleInstance.price();
        uint256 loanDecimals = ERC20(loanToken).decimals();
        uint256 collateralDecimals = ERC20(collateralToken).decimals();

        // Correct scaling factor as per the oracle's specification:
        // 10^(36 + loanDecimals - collateralDecimals)
        uint256 scalingFactor = 10 ** (36 + loanDecimals - collateralDecimals);

        if (isPositiveFeed) {
            // Inverting the original calculation when isPositiveFeed is true:
            // loanAmount = collateralAmount * price / scalingFactor
            loanAmount = Math.mulDiv(collateralAmount, price, scalingFactor);
        } else {
            // Inverting the original calculation when isPositiveFeed is false:
            // loanAmount = collateralAmount * scalingFactor / price
            loanAmount = Math.mulDiv(collateralAmount, scalingFactor, price);
        }
    }

    function _generateMarketParams(
        address loanToken,
        address collateralToken,
        address oracle,
        address irm,
        uint256 lltv
    )
        internal
        pure
        returns (MarketParams memory)
    {
        return MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: oracle,
            irm: irm,
            lltv: lltv
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _decodeAmount(bytes memory data) private pure returns (uint256) {
        return BytesLib.toUint256(BytesLib.slice(data, AMOUNT_POSITION, 32), 0);
    }

    function _getCollateralBalance(address account, bytes memory data) private view returns (uint256) {
        address collateralToken = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
        return IERC20(collateralToken).balanceOf(account);
    }

    function _getLoanBalance(address account, bytes memory data) private view returns (uint256) {
        address loanToken = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        return IERC20(loanToken).balanceOf(account);
    }
}
