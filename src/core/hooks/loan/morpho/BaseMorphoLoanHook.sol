// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { MarketParams, IMorpho } from "../../../../vendor/morpho/IMorpho.sol";
import { MarketParamsLib } from "../../../../vendor/morpho/MarketParamsLib.sol";

// superform
import { BaseLoanHook } from "../BaseLoanHook.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

abstract contract BaseMorphoLoanHook is BaseLoanHook {
    using MarketParamsLib for MarketParams;
    using HookDataDecoder for bytes;

    IMorpho public morphoInterface;

    struct BuildHookLocalVars {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 amount;
        uint256 lltv;
        bool usePrevHookAmount;
        bool isFullRepayment;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address morpho_, bytes32 hookSubtype_) BaseLoanHook(hookSubtype_) {
        if (morpho_ == address(0)) revert ADDRESS_NOT_VALID();
        morphoInterface = IMorpho(morpho_);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Decodes the hook data
    /// @param data The hook data
    /// @return vars The decoded hook data
    function _decodeHookData(bytes memory data) internal pure returns (BuildHookLocalVars memory vars) {
        address loanToken = BytesLib.toAddress(data, 0);
        address collateralToken = BytesLib.toAddress(data, 20);
        address oracle = BytesLib.toAddress(data, 40);
        address irm = BytesLib.toAddress(data, 60);
        uint256 amount = _decodeAmount(data);
        uint256 lltv = BytesLib.toUint256(data, 112);
        bool usePrevHookAmount = _decodeBool(data, 144);
        bool isFullRepayment = _decodeBool(data, 145);

        vars = BuildHookLocalVars({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: oracle,
            irm: irm,
            amount: amount,
            lltv: lltv,
            usePrevHookAmount: usePrevHookAmount,
            isFullRepayment: isFullRepayment
        });
    }

    /// @dev Generates the market params
    /// @param loanToken The loan token
    /// @param collateralToken The collateral token
    /// @param oracle The oracle
    /// @param irm The irm
    /// @param lltv The lltv
    /// @return marketParams The market params
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
}
