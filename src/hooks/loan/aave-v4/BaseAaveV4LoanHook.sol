// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";

// Superform
import { BaseLoanHook } from "../BaseLoanHook.sol";
import { ISuperHookInflowOutflow, ISuperHookOutflow } from "../../../interfaces/ISuperHook.sol";

/// @title BaseAaveV4LoanHook
/// @author Superform Labs
/// @notice Base abstract hook for Aave V4 Hub-and-Spoke lending protocol integrations
/// @dev All Aave V4 hooks inherit from this contract. Unlike Morpho hooks, the Spoke address
///      comes from calldata rather than the constructor, enabling a single hook deployment to
///      work with any Aave V4 Spoke (Core, e-Mode, Isolation, RWA, Vault Spokes).
///      SECURITY INVARIANT: onBehalfOf is always hardcoded to `account` — never arbitrary.
abstract contract BaseAaveV4LoanHook is BaseLoanHook {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Aave V4 data layout byte offsets
    uint256 internal constant LOAN_TOKEN_OFFSET = 52;
    uint256 internal constant COLLATERAL_TOKEN_OFFSET = 72;
    uint256 internal constant SPOKE_OFFSET = 92;
    uint256 internal constant SUPPLY_RESERVE_ID_OFFSET = 112;
    uint256 internal constant BORROW_RESERVE_ID_OFFSET = 144;
    uint256 internal constant AAVE_V4_AMOUNT_OFFSET = 176;
    uint256 internal constant AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION = 208;
    /// @dev Byte 209 is used by TWO DIFFERENT data layouts (never both at once):
    ///      - SupplyAndBorrow: uint256 borrowAmount starts at 209 (no isFullRepayment field)
    ///      - RepayAndWithdraw: bool isFullRepayment at 209, then uint256 withdrawAmount at 210
    uint256 internal constant IS_FULL_REPAYMENT_OFFSET = 209;
    uint256 internal constant BORROW_AMOUNT_OFFSET = 209;
    uint256 internal constant WITHDRAW_AMOUNT_OFFSET = 210;

    /// @notice Minimum data lengths for validation
    uint256 internal constant SUPPLY_MIN_DATA_LENGTH = 209;
    uint256 internal constant WITHDRAW_MIN_DATA_LENGTH = 209;
    uint256 internal constant BORROW_MIN_DATA_LENGTH = 209;
    uint256 internal constant REPAY_MIN_DATA_LENGTH = 210;
    uint256 internal constant SUPPLY_AND_BORROW_MIN_DATA_LENGTH = 241;
    uint256 internal constant REPAY_AND_WITHDRAW_MIN_DATA_LENGTH = 242;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct SupplyHookLocalVars {
        address loanToken;
        address collateralToken;
        address spoke;
        uint256 supplyReserveId;
        uint256 amount;
        bool usePrevHookAmount;
    }

    struct WithdrawHookLocalVars {
        address loanToken;
        address collateralToken;
        address spoke;
        uint256 supplyReserveId;
        uint256 amount;
        bool usePrevHookAmount;
    }

    struct BorrowHookLocalVars {
        address loanToken;
        address collateralToken;
        address spoke;
        uint256 borrowReserveId;
        uint256 amount;
        bool usePrevHookAmount;
    }

    struct RepayHookLocalVars {
        address loanToken;
        address collateralToken;
        address spoke;
        uint256 borrowReserveId;
        uint256 amount;
        bool usePrevHookAmount;
        bool isFullRepayment;
    }

    struct SupplyAndBorrowHookLocalVars {
        address loanToken;
        address collateralToken;
        address spoke;
        uint256 supplyReserveId;
        uint256 borrowReserveId;
        uint256 amount;
        bool usePrevHookAmount;
        uint256 borrowAmount;
    }

    struct RepayAndWithdrawHookLocalVars {
        address loanToken;
        address collateralToken;
        address spoke;
        uint256 supplyReserveId;
        uint256 borrowReserveId;
        uint256 amount;
        bool usePrevHookAmount;
        bool isFullRepayment;
        uint256 withdrawAmount;
    }

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when hook calldata is shorter than the required minimum
    error INVALID_DATA_LENGTH();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice No constructor args — Spoke address comes from calldata
    /// @param hookSubtype_ Hook subtype identifier (LOAN or LOAN_REPAY)
    constructor(bytes32 hookSubtype_) BaseLoanHook(hookSubtype_) { }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseLoanHook
    /// @dev Overrides parent to use Aave V4 offset (156) instead of Morpho offset (144)
    function decodeUsePrevHookAmount(bytes memory data) external pure override returns (bool) {
        return _decodeBool(data, AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure virtual override returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        amounts[0] = BytesLib.toUint256(data, AAVE_V4_AMOUNT_OFFSET);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory)
        external
        pure
        virtual
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        meta = new ISuperHookInflowOutflow.AmountMeta[](1);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
    }

    /// @inheritdoc ISuperHookOutflow
    function replaceCalldataAmounts(
        bytes memory data,
        uint256[] memory amounts
    )
        external
        pure
        virtual
        override
        returns (bytes memory)
    {
        if (amounts.length != 1) revert INVALID_AMOUNTS_LENGTH();
        return _replaceCalldataAmount(data, amounts[0], AAVE_V4_AMOUNT_OFFSET);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Decodes supply hook data
    function _decodeSupplyHookData(bytes memory data) internal pure returns (SupplyHookLocalVars memory vars) {
        if (data.length < SUPPLY_MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        vars.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        vars.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        vars.spoke = BytesLib.toAddress(data, SPOKE_OFFSET);

        if (vars.loanToken == address(0) || vars.collateralToken == address(0) || vars.spoke == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

        vars.supplyReserveId = BytesLib.toUint256(data, SUPPLY_RESERVE_ID_OFFSET);
        vars.amount = BytesLib.toUint256(data, AAVE_V4_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeBool(data, AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @dev Decodes withdraw hook data (same layout as supply)
    function _decodeWithdrawHookData(bytes memory data) internal pure returns (WithdrawHookLocalVars memory vars) {
        if (data.length < WITHDRAW_MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        vars.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        vars.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        vars.spoke = BytesLib.toAddress(data, SPOKE_OFFSET);

        if (vars.loanToken == address(0) || vars.collateralToken == address(0) || vars.spoke == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

        vars.supplyReserveId = BytesLib.toUint256(data, SUPPLY_RESERVE_ID_OFFSET);
        vars.amount = BytesLib.toUint256(data, AAVE_V4_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeBool(data, AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @dev Decodes borrow hook data — uses borrowReserveId (not supplyReserveId)
    function _decodeBorrowHookData(bytes memory data) internal pure returns (BorrowHookLocalVars memory vars) {
        if (data.length < BORROW_MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        vars.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        vars.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        vars.spoke = BytesLib.toAddress(data, SPOKE_OFFSET);

        if (vars.loanToken == address(0) || vars.collateralToken == address(0) || vars.spoke == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

        vars.borrowReserveId = BytesLib.toUint256(data, BORROW_RESERVE_ID_OFFSET);
        vars.amount = BytesLib.toUint256(data, AAVE_V4_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeBool(data, AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @dev Decodes repay hook data — uses borrowReserveId + isFullRepayment
    function _decodeRepayHookData(bytes memory data) internal pure returns (RepayHookLocalVars memory vars) {
        if (data.length < REPAY_MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        vars.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        vars.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        vars.spoke = BytesLib.toAddress(data, SPOKE_OFFSET);

        if (vars.loanToken == address(0) || vars.collateralToken == address(0) || vars.spoke == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

        vars.borrowReserveId = BytesLib.toUint256(data, BORROW_RESERVE_ID_OFFSET);
        vars.amount = BytesLib.toUint256(data, AAVE_V4_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeBool(data, AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION);
        vars.isFullRepayment = _decodeBool(data, IS_FULL_REPAYMENT_OFFSET);
    }

    /// @dev Decodes supply-and-borrow hook data — uses BOTH reserveIds + borrowAmount at position 157
    function _decodeSupplyAndBorrowHookData(bytes memory data)
        internal
        pure
        returns (SupplyAndBorrowHookLocalVars memory vars)
    {
        if (data.length < SUPPLY_AND_BORROW_MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        vars.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        vars.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        vars.spoke = BytesLib.toAddress(data, SPOKE_OFFSET);

        if (vars.loanToken == address(0) || vars.collateralToken == address(0) || vars.spoke == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

        vars.supplyReserveId = BytesLib.toUint256(data, SUPPLY_RESERVE_ID_OFFSET);
        vars.borrowReserveId = BytesLib.toUint256(data, BORROW_RESERVE_ID_OFFSET);
        vars.amount = BytesLib.toUint256(data, AAVE_V4_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeBool(data, AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION);
        vars.borrowAmount = BytesLib.toUint256(data, BORROW_AMOUNT_OFFSET);
    }

    /// @dev Decodes repay-and-withdraw hook data — uses BOTH reserveIds + isFullRepayment + withdrawAmount
    function _decodeRepayAndWithdrawHookData(bytes memory data)
        internal
        pure
        returns (RepayAndWithdrawHookLocalVars memory vars)
    {
        if (data.length < REPAY_AND_WITHDRAW_MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        vars.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        vars.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        vars.spoke = BytesLib.toAddress(data, SPOKE_OFFSET);

        if (vars.loanToken == address(0) || vars.collateralToken == address(0) || vars.spoke == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

        vars.supplyReserveId = BytesLib.toUint256(data, SUPPLY_RESERVE_ID_OFFSET);
        vars.borrowReserveId = BytesLib.toUint256(data, BORROW_RESERVE_ID_OFFSET);
        vars.amount = BytesLib.toUint256(data, AAVE_V4_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeBool(data, AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION);
        vars.isFullRepayment = _decodeBool(data, IS_FULL_REPAYMENT_OFFSET);
        vars.withdrawAmount = BytesLib.toUint256(data, WITHDRAW_AMOUNT_OFFSET);
    }
}
