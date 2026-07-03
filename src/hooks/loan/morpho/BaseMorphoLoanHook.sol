// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { MarketParams } from "../../../vendor/morpho/IMorpho.sol";
import { MarketParamsLib } from "../../../vendor/morpho/MarketParamsLib.sol";

// superform
import { BaseLoanHook } from "../BaseLoanHook.sol";

/// @title BaseMorphoLoanHook
/// @author Superform Labs
/// @notice Base abstract hook for Morpho Blue lending protocol integrations
/// @dev All Morpho hooks inherit from this contract. It stores the Morpho Blue protocol address
///      and provides shared data decoding and market parameter generation utilities.
///      SECURITY INVARIANT: All Morpho calls MUST use empty callback data ("") to prevent reentrancy
///      through Morpho's callback mechanism (onMorphoSupply, onMorphoRepay, etc.).
abstract contract BaseMorphoLoanHook is BaseLoanHook {
    using MarketParamsLib for MarketParams;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Common data layout byte offsets (shared across all Morpho hooks)
    uint256 internal constant LOAN_TOKEN_OFFSET = 52;
    uint256 internal constant COLLATERAL_TOKEN_OFFSET = 72;
    uint256 internal constant ORACLE_OFFSET = 92;
    uint256 internal constant IRM_OFFSET = 112;
    // AMOUNT_POSITION = 80 inherited from BaseLoanHook
    uint256 internal constant LLTV_OFFSET = 164;
    // USE_PREV_HOOK_AMOUNT_POSITION = 144 inherited from BaseLoanHook
    uint256 internal constant IS_FULL_REPAYMENT_OFFSET = 197;

    /// @notice Byte offset for LLTV in borrow hook data (178-byte layout)
    /// @dev Same numeric offset as IS_FULL_REPAYMENT_OFFSET but different semantic meaning:
    ///      - Repay layout (146 bytes): byte 145 = isFullRepayment (bool)
    ///      - Borrow layout (178 bytes): byte 145 = lltv (uint256, 32 bytes)
    uint256 internal constant BORROW_LLTV_OFFSET = 197;

    /// @notice Minimum data length for repay hooks (146 bytes)
    uint256 internal constant REPAY_MIN_DATA_LENGTH = 198;

    /// @notice Minimum data length for borrow hooks (178 bytes)
    uint256 internal constant BORROW_MIN_DATA_LENGTH = 230;

    /// @notice Minimum data length for supply/lend hooks (145 bytes)
    uint256 internal constant SUPPLY_MIN_DATA_LENGTH = 197;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Address of the Morpho Blue protocol
    address public immutable morpho;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

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

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when hook calldata is shorter than the required minimum
    error INVALID_DATA_LENGTH();

    /// @notice Thrown when the LTV ratio exceeds or equals the liquidation LTV
    error LTV_RATIO_NOT_VALID();

    /// @notice Thrown when a division-by-zero would occur (e.g., no outstanding debt)
    error NO_OUTSTANDING_DEBT();

    /// @notice Thrown when the oracle returns a zero price
    error ORACLE_PRICE_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param morpho_ Address of the Morpho Blue protocol
    /// @param hookSubtype_ Hook subtype identifier
    constructor(address morpho_, bytes32 hookSubtype_) BaseLoanHook(hookSubtype_) {
        if (morpho_ == address(0)) revert ADDRESS_NOT_VALID();
        morpho = morpho_;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Decodes the hook data for repay operations (146-byte layout)
    /// @param data The hook data
    /// @return vars The decoded hook data
    function _decodeHookData(bytes memory data) internal pure returns (BuildHookLocalVars memory vars) {
        if (data.length < REPAY_MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        address loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        address collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        address oracle = BytesLib.toAddress(data, ORACLE_OFFSET);
        address irm = BytesLib.toAddress(data, IRM_OFFSET);

        if (loanToken == address(0) || collateralToken == address(0) || oracle == address(0) || irm == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

        uint256 amount = _decodeAmount(data);
        uint256 lltv = BytesLib.toUint256(data, LLTV_OFFSET);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
        bool isFullRepayment = _decodeBool(data, IS_FULL_REPAYMENT_OFFSET);

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

    /// @dev Decodes the hook data for borrow operations (178-byte layout)
    /// @param data The hook data
    /// @return vars The decoded borrow hook parameters
    function _decodeBorrowHookData(bytes memory data) internal pure returns (BorrowHookLocalVars memory vars) {
        if (data.length < BORROW_MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        address loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        address collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        address oracle = BytesLib.toAddress(data, ORACLE_OFFSET);
        address irm = BytesLib.toAddress(data, IRM_OFFSET);

        if (loanToken == address(0) || collateralToken == address(0) || oracle == address(0) || irm == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

        uint256 amount = _decodeAmount(data);
        uint256 ltvRatio = BytesLib.toUint256(data, LLTV_OFFSET);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
        uint256 lltv = BytesLib.toUint256(data, BORROW_LLTV_OFFSET);

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

    /// @dev Generates the market params for Morpho Blue
    /// @param loanToken The loan token
    /// @param collateralToken The collateral token
    /// @param oracle The oracle
    /// @param irm The interest rate model
    /// @param lltv The liquidation LTV
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
