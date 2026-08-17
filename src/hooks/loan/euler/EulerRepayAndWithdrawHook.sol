// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// euler
import { IEVC } from "../../../vendor/euler/IEVC.sol";
import { IEVault } from "../../../vendor/euler/IEVault.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseEulerLoanHook } from "./BaseEulerLoanHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import {
    ISuperHookResult,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";

/// @title EulerRepayAndWithdrawHook
/// @author Superform Labs
/// @notice Repays debt and withdraws collateral from Euler V2
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @dev         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @dev         address yieldSourceAddress = BytesLib.toAddress(data, 32);  // collateralVault
/// @dev         address debtAsset = BytesLib.toAddress(data, 52);
/// @dev         address collateralAsset = BytesLib.toAddress(data, 72);
/// @dev         address evc = BytesLib.toAddress(data, 92);
/// @dev         address controllerVault = BytesLib.toAddress(data, 112);
/// @dev         uint256 primaryAmount = BytesLib.toUint256(data, 132);     // repay amount
/// @dev         uint256 secondaryAmount = BytesLib.toUint256(data, 164);   // withdraw amount (0 = repay-only)
/// @dev         bool usePrevHookAmount = _decodeBool(data, 196);           // MUST be false for launch
/// @dev         bool isFullRepayment = _decodeBool(data, 197);
/// @dev         uint256 maxRepayAssets = BytesLib.toUint256(data, 198);
/// @dev         uint256 maxCollateralReleaseAssets = BytesLib.toUint256(data, 230);
/// @dev         uint256 maxRemainingLiqCapUtilBps = BytesLib.toUint256(data, 262);
/// @dev         address expectedReleaseOracle = BytesLib.toAddress(data, 294);
/// @dev         address expectedReleaseUnitOfAccount = BytesLib.toAddress(data, 314);
/// @dev         address expectedReleaseIRM = BytesLib.toAddress(data, 334);
/// @dev When secondaryAmount > 0: outAmount tracks collateralAsset received by account (post - pre).
///      When secondaryAmount = 0 (repay-only): outAmount tracks debtAsset consumed (pre - post).
///      When isFullRepayment = true, uses type(uint256).max for repay so Euler V2 calculates exact
///      debt atomically, and includes disableController() + disableCollateral() cleanup.
/// @dev KNOWN LIMITATION (TOCTOU): oracle/IRM/unitOfAccount are validated at build-time only.
///      Vault governance could change these between build() and execute(). This is mitigated by
///      off-chain monitoring and the _postExecute liquidation capacity checks.
/// @dev No constructor args — vault addresses come from calldata (Aave V3 pattern).
contract EulerRepayAndWithdrawHook is BaseEulerLoanHook {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // Tail offsets
    uint256 internal constant IS_FULL_REPAYMENT_OFFSET = 197;
    uint256 internal constant MAX_REPAY_ASSETS_OFFSET = 198;
    uint256 internal constant MAX_COLLATERAL_RELEASE_OFFSET = 230;
    uint256 internal constant MAX_REMAINING_LIQ_CAP_UTIL_BPS_OFFSET = 262;
    uint256 internal constant EXPECTED_RELEASE_ORACLE_OFFSET = 294;
    uint256 internal constant EXPECTED_RELEASE_UNIT_OFFSET = 314;
    uint256 internal constant EXPECTED_RELEASE_IRM_OFFSET = 334;

    uint256 internal constant MIN_DATA_LENGTH = 354;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct RepayWithdrawVars {
        /// @dev yieldSourceAddress is the collateral vault (EVault)
        address yieldSourceAddress;
        /// @dev The token being repaid
        address debtAsset;
        /// @dev The underlying collateral token to receive
        address collateralAsset;
        /// @dev The Ethereum Vault Connector address
        address evc;
        /// @dev The Euler EVault that holds the debt position
        address controllerVault;
        /// @dev Amount of debt to repay (ignored if isFullRepayment is true)
        uint256 primaryAmount;
        /// @dev Amount of collateral to withdraw (0 = repay-only)
        uint256 secondaryAmount;
        /// @dev Must be false for launch
        bool usePrevHookAmount;
        /// @dev If true, repay entire outstanding debt and disable controller + collateral
        bool isFullRepayment;
        /// @dev Maximum allowed repay amount (partial repay cap)
        uint256 maxRepayAssets;
        /// @dev Maximum allowed collateral release amount
        uint256 maxCollateralReleaseAssets;
        /// @dev Maximum remaining liquidation capacity utilization in basis points
        uint256 maxRemainingLiqCapUtilBps;
        /// @dev Expected oracle address — validated at build time
        address expectedReleaseOracle;
        /// @dev Expected unit of account address — validated at build time
        address expectedReleaseUnitOfAccount;
        /// @dev Expected interest rate model address — validated at build time
        address expectedReleaseIRM;
    }

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when usePrevHookAmount is true (not supported for launch)
    error USE_PREV_HOOK_AMOUNT_NOT_SUPPORTED();

    /// @notice Thrown when the vault's oracle doesn't match the expected oracle
    error ORACLE_MISMATCH();

    /// @notice Thrown when the vault's unit of account doesn't match expected
    error UNIT_OF_ACCOUNT_MISMATCH();

    /// @notice Thrown when the vault's IRM doesn't match expected
    error IRM_MISMATCH();

    /// @notice Thrown when repay amount exceeds the max allowed
    error MAX_REPAY_EXCEEDED();

    /// @notice Thrown when withdraw amount exceeds the max allowed
    error MAX_COLLATERAL_RELEASE_EXCEEDED();

    /// @notice Thrown when post-execution liquidation capacity utilization exceeds the cap
    error LIQUIDATION_CAPACITY_EXCEEDED();

    /// @notice Thrown when debt is not zero after full repayment
    error FULL_REPAY_FAILED();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() BaseEulerLoanHook(HookSubTypes.LOAN_REPAY) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Euler Repay and Withdraw";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Repays debt and withdraws collateral from Euler V2";
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        RepayWithdrawVars memory vars = _decodeRepayWithdrawData(data);

        // Launch constraint: usePrevHookAmount must be false
        if (vars.usePrevHookAmount) revert USE_PREV_HOOK_AMOUNT_NOT_SUPPORTED();

        uint256 repayAmount;

        if (vars.isFullRepayment) {
            // Full repay: verify debt exists, then use type(uint256).max so EVault calculates
            // exact debt atomically at execution time (eliminates interest accrual staleness)
            if (IEVault(vars.controllerVault).debtOf(account) == 0) revert AMOUNT_NOT_VALID();
            repayAmount = type(uint256).max;
        } else {
            repayAmount = vars.primaryAmount;
            if (repayAmount == 0) revert AMOUNT_NOT_VALID();
            // Cap check for partial repay
            if (repayAmount > vars.maxRepayAssets) revert MAX_REPAY_EXCEEDED();
        }

        // Validate release config only when withdrawing collateral
        if (vars.secondaryAmount > 0) {
            if (vars.secondaryAmount > vars.maxCollateralReleaseAssets) {
                revert MAX_COLLATERAL_RELEASE_EXCEEDED();
            }

            // Config validation: oracle, unit of account, IRM
            // NOTE: TOCTOU risk — vault governance could change these between build() and execute()
            if (IEVault(vars.controllerVault).oracle() != vars.expectedReleaseOracle) {
                revert ORACLE_MISMATCH();
            }
            if (IEVault(vars.controllerVault).unitOfAccount() != vars.expectedReleaseUnitOfAccount) {
                revert UNIT_OF_ACCOUNT_MISMATCH();
            }
            if (IEVault(vars.controllerVault).interestRateModel() != vars.expectedReleaseIRM) {
                revert IRM_MISMATCH();
            }
        }

        if (vars.secondaryAmount == 0) {
            // REPAY-ONLY path: 4 executions, no withdraw
            executions = new Execution[](4);
            executions[0] = Execution({
                target: vars.debtAsset,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (vars.controllerVault, 0))
            });
            executions[1] = Execution({
                target: vars.debtAsset,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (vars.controllerVault, repayAmount))
            });
            executions[2] = Execution({
                target: vars.controllerVault,
                value: 0,
                callData: abi.encodeCall(IEVault.repay, (repayAmount, account))
            });
            executions[3] = Execution({
                target: vars.debtAsset,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (vars.controllerVault, 0))
            });
        } else if (vars.isFullRepayment) {
            // FULL REPAY + WITHDRAW + CLEANUP: 8 executions
            executions = new Execution[](8);
            executions[0] = Execution({
                target: vars.debtAsset,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (vars.controllerVault, 0))
            });
            executions[1] = Execution({
                target: vars.debtAsset,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (vars.controllerVault, type(uint256).max))
            });
            executions[2] = Execution({
                target: vars.controllerVault,
                value: 0,
                callData: abi.encodeCall(IEVault.repay, (type(uint256).max, account))
            });
            executions[3] = Execution({
                target: vars.debtAsset,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (vars.controllerVault, 0))
            });
            executions[4] = Execution({
                target: vars.yieldSourceAddress,
                value: 0,
                callData: abi.encodeCall(IEVault.withdraw, (vars.secondaryAmount, account, account))
            });
            // disableController after zero debt — called on EVault with NO params
            executions[5] = Execution({
                target: vars.controllerVault,
                value: 0,
                callData: abi.encodeCall(IEVault.disableController, ())
            });
            // Clean up EVC collateral registration to free collateral slots
            executions[6] = Execution({
                target: vars.evc,
                value: 0,
                callData: abi.encodeCall(IEVC.disableCollateral, (account, vars.yieldSourceAddress))
            });
            // Reset approval after full repay (belt-and-suspenders)
            executions[7] = Execution({
                target: vars.debtAsset,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (vars.controllerVault, 0))
            });
        } else {
            // PARTIAL REPAY + WITHDRAW: 5 executions
            executions = new Execution[](5);
            executions[0] = Execution({
                target: vars.debtAsset,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (vars.controllerVault, 0))
            });
            executions[1] = Execution({
                target: vars.debtAsset,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (vars.controllerVault, repayAmount))
            });
            executions[2] = Execution({
                target: vars.controllerVault,
                value: 0,
                callData: abi.encodeCall(IEVault.repay, (repayAmount, account))
            });
            executions[3] = Execution({
                target: vars.debtAsset,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (vars.controllerVault, 0))
            });
            executions[4] = Execution({
                target: vars.yieldSourceAddress,
                value: 0,
                callData: abi.encodeCall(IEVault.withdraw, (vars.secondaryAmount, account, account))
            });
        }
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = BytesLib.toUint256(data, PRIMARY_AMOUNT_OFFSET);
        amounts[1] = BytesLib.toUint256(data, SECONDARY_AMOUNT_OFFSET);
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
        data = _replaceCalldataAmount(data, amounts[0], PRIMARY_AMOUNT_OFFSET);
        return _replaceCalldataAmount(data, amounts[1], SECONDARY_AMOUNT_OFFSET);
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
        address yieldSourceAddress = BytesLib.toAddress(data, COLLATERAL_VAULT_OFFSET);
        address evc = BytesLib.toAddress(data, EVC_OFFSET);
        address controllerVault = BytesLib.toAddress(data, CONTROLLER_VAULT_OFFSET);
        return abi.encodePacked(yieldSourceAddress, evc, controllerVault);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Decodes and validates repay-and-withdraw calldata
    /// @param data The raw hook calldata containing combined repay + withdraw parameters
    /// @return vars The decoded and validated repay-withdraw variables
    function _decodeRepayWithdrawData(bytes memory data) internal pure returns (RepayWithdrawVars memory vars) {
        if (data.length < MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        vars.yieldSourceAddress = BytesLib.toAddress(data, COLLATERAL_VAULT_OFFSET);
        vars.debtAsset = BytesLib.toAddress(data, DEBT_ASSET_OFFSET);
        vars.collateralAsset = BytesLib.toAddress(data, COLLATERAL_ASSET_OFFSET);
        vars.evc = BytesLib.toAddress(data, EVC_OFFSET);
        vars.controllerVault = BytesLib.toAddress(data, CONTROLLER_VAULT_OFFSET);
        vars.primaryAmount = BytesLib.toUint256(data, PRIMARY_AMOUNT_OFFSET);
        vars.secondaryAmount = BytesLib.toUint256(data, SECONDARY_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeBool(data, USE_PREV_OFFSET);
        vars.isFullRepayment = _decodeBool(data, IS_FULL_REPAYMENT_OFFSET);
        vars.maxRepayAssets = BytesLib.toUint256(data, MAX_REPAY_ASSETS_OFFSET);
        vars.maxCollateralReleaseAssets = BytesLib.toUint256(data, MAX_COLLATERAL_RELEASE_OFFSET);
        vars.maxRemainingLiqCapUtilBps = BytesLib.toUint256(data, MAX_REMAINING_LIQ_CAP_UTIL_BPS_OFFSET);
        vars.expectedReleaseOracle = BytesLib.toAddress(data, EXPECTED_RELEASE_ORACLE_OFFSET);
        vars.expectedReleaseUnitOfAccount = BytesLib.toAddress(data, EXPECTED_RELEASE_UNIT_OFFSET);
        vars.expectedReleaseIRM = BytesLib.toAddress(data, EXPECTED_RELEASE_IRM_OFFSET);

        if (
            vars.yieldSourceAddress == address(0) || vars.debtAsset == address(0)
                || vars.collateralAsset == address(0) || vars.evc == address(0) || vars.controllerVault == address(0)
        ) {
            revert ADDRESS_NOT_VALID();
        }
    }

    /// @inheritdoc BaseHook
    /// @dev When secondaryAmount > 0: stores collateralAsset balance for delta tracking
    ///      When secondaryAmount = 0 (repay-only): stores debtAsset balance for delta tracking
    function _preExecute(address, address account, bytes calldata data) internal override {
        uint256 secondaryAmount = BytesLib.toUint256(data, SECONDARY_AMOUNT_OFFSET);
        if (secondaryAmount == 0) {
            // Repay-only: track debt token consumed
            _setOutAmount(getLoanTokenBalance(account, data), account);
        } else {
            // Withdraw path: track collateral received
            _setOutAmount(getCollateralTokenBalance(account, data), account);
        }
    }

    /// @inheritdoc BaseHook
    /// @dev Computes token delta, validates full repay and liq capacity
    ///      When secondaryAmount > 0: outAmount = collateral received (postBal - preBal)
    ///      When secondaryAmount = 0: outAmount = debt consumed (preBal - postBal)
    function _postExecute(address, address account, bytes calldata data) internal override {
        uint256 secondaryAmount = BytesLib.toUint256(data, SECONDARY_AMOUNT_OFFSET);

        if (secondaryAmount == 0) {
            // Repay-only: outAmount = debt consumed (pre - post)
            uint256 preBal = getOutAmount(account);
            uint256 postBal = getLoanTokenBalance(account, data);
            _setOutAmount(preBal - postBal, account);
            _setOutToken(getLoanTokenAddress(data), account);
        } else {
            // Withdraw path: outAmount = collateral received (post - pre)
            uint256 preBal = getOutAmount(account);
            uint256 postBal = getCollateralTokenBalance(account, data);
            _setOutAmount(postBal - preBal, account);
            _setOutToken(getCollateralTokenAddress(data), account);
        }

        address controllerVault = BytesLib.toAddress(data, CONTROLLER_VAULT_OFFSET);
        bool isFullRepayment = _decodeBool(data, IS_FULL_REPAYMENT_OFFSET);

        // Verify full repayment succeeded
        if (isFullRepayment) {
            if (IEVault(controllerVault).debtOf(account) != 0) {
                revert FULL_REPAY_FAILED();
            }
        }

        // Validate remaining liquidation capacity (only when withdrawing collateral)
        if (secondaryAmount > 0 && !isFullRepayment) {
            uint256 maxRemainingLiqCapUtilBps = BytesLib.toUint256(data, MAX_REMAINING_LIQ_CAP_UTIL_BPS_OFFSET);
            if (maxRemainingLiqCapUtilBps > 0) {
                // collateralValue is FIRST, liabilityValue is SECOND
                (uint256 collateralValue, uint256 liabilityValue) =
                    IEVault(controllerVault).accountLiquidity(account, true);
                // Guard against zero collateral value edge case (e.g., oracle returns 0)
                if (liabilityValue > 0 && collateralValue == 0) revert LIQUIDATION_CAPACITY_EXCEEDED();
                if (liabilityValue * 10_000 > collateralValue * maxRemainingLiqCapUtilBps) {
                    revert LIQUIDATION_CAPACITY_EXCEEDED();
                }
            }
        }
    }
}
