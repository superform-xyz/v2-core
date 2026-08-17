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

/// @title EulerDepositCollateralAndBorrowHook
/// @author Superform Labs
/// @notice Deposits collateral into an Euler V2 EVault and borrows from a controller EVault
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @dev         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @dev         address yieldSourceAddress = BytesLib.toAddress(data, 32);  // collateralVault
/// @dev         address debtAsset = BytesLib.toAddress(data, 52);
/// @dev         address collateralAsset = BytesLib.toAddress(data, 72);
/// @dev         address evc = BytesLib.toAddress(data, 92);
/// @dev         address controllerVault = BytesLib.toAddress(data, 112);
/// @dev         uint256 primaryAmount = BytesLib.toUint256(data, 132);     // collateral deposit amount
/// @dev         uint256 secondaryAmount = BytesLib.toUint256(data, 164);   // borrow amount
/// @dev         bool usePrevHookAmount = _decodeBool(data, 196);           // MUST be false for launch
/// @dev         uint256 maxPostDebt = BytesLib.toUint256(data, 197);
/// @dev         uint256 maxLiqCapUtilBps = BytesLib.toUint256(data, 229);
/// @dev         address expectedOracle = BytesLib.toAddress(data, 261);
/// @dev         address expectedUnitOfAccount = BytesLib.toAddress(data, 281);
/// @dev         address expectedIRM = BytesLib.toAddress(data, 301);
/// @dev outAmount tracks debtAsset received by account (post - pre), i.e., the borrowed amount.
///      usePrevHookAmount MUST be false (launch constraint — both amounts are independently sized).
///      No constructor args — vault and EVC addresses come from calldata (Aave V3 pattern).
/// @dev KNOWN LIMITATION (TOCTOU): oracle/IRM/unitOfAccount are validated at build-time only.
///      Vault governance could change these between build() and execute(). This is mitigated by
///      off-chain monitoring and the _postExecute maxPostDebt/liquidation capacity checks.
contract EulerDepositCollateralAndBorrowHook is BaseEulerLoanHook {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // Tail offsets
    uint256 internal constant MAX_POST_DEBT_OFFSET = 197;
    uint256 internal constant MAX_LIQ_CAP_UTIL_BPS_OFFSET = 229;
    uint256 internal constant EXPECTED_ORACLE_OFFSET = 261;
    uint256 internal constant EXPECTED_UNIT_OF_ACCOUNT_OFFSET = 281;
    uint256 internal constant EXPECTED_IRM_OFFSET = 301;

    uint256 internal constant MIN_DATA_LENGTH = 321;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct OpenVars {
        /// @dev yieldSourceAddress is the collateral vault (EVault)
        address yieldSourceAddress;
        /// @dev The token being borrowed
        address debtAsset;
        /// @dev The underlying collateral token to deposit
        address collateralAsset;
        /// @dev The Ethereum Vault Connector address
        address evc;
        /// @dev The Euler EVault that manages the debt position
        address controllerVault;
        /// @dev Amount of collateral to deposit
        uint256 primaryAmount;
        /// @dev Amount of debt to borrow
        uint256 secondaryAmount;
        /// @dev Must be false for launch
        bool usePrevHookAmount;
        /// @dev Maximum allowed debt after execution
        uint256 maxPostDebt;
        /// @dev Maximum liquidation capacity utilization in basis points
        uint256 maxLiqCapUtilBps;
        /// @dev Expected oracle address — validated at build time
        address expectedOracle;
        /// @dev Expected unit of account address — validated at build time
        address expectedUnitOfAccount;
        /// @dev Expected interest rate model address — validated at build time
        address expectedIRM;
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

    /// @notice Thrown when post-execution debt exceeds the max allowed
    error MAX_POST_DEBT_EXCEEDED();

    /// @notice Thrown when post-execution liquidation capacity utilization exceeds the cap
    error LIQUIDATION_CAPACITY_EXCEEDED();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() BaseEulerLoanHook(HookSubTypes.LOAN) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Euler Deposit Collateral and Borrow";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Deposits collateral and borrows from Euler V2";
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
        OpenVars memory vars = _decodeOpenData(data);

        // Launch constraint: usePrevHookAmount must be false
        if (vars.usePrevHookAmount) revert USE_PREV_HOOK_AMOUNT_NOT_SUPPORTED();

        if (vars.primaryAmount == 0 || vars.secondaryAmount == 0) revert AMOUNT_NOT_VALID();

        // Enforce zero-or-one controller invariant
        address[] memory controllers = IEVC(vars.evc).getControllers(account);
        if (controllers.length > 0 && controllers[0] != vars.controllerVault) {
            revert CONTROLLER_ALREADY_SET();
        }

        // Config validation: oracle, unit of account, IRM must match expected
        // NOTE: TOCTOU risk — vault governance could change these between build() and execute()
        if (IEVault(vars.controllerVault).oracle() != vars.expectedOracle) {
            revert ORACLE_MISMATCH();
        }
        if (IEVault(vars.controllerVault).unitOfAccount() != vars.expectedUnitOfAccount) {
            revert UNIT_OF_ACCOUNT_MISMATCH();
        }
        if (IEVault(vars.controllerVault).interestRateModel() != vars.expectedIRM) {
            revert IRM_MISMATCH();
        }

        executions = new Execution[](7);
        // Triple-approval for collateral deposit
        executions[0] = Execution({
            target: vars.collateralAsset,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (vars.yieldSourceAddress, 0))
        });
        executions[1] = Execution({
            target: vars.collateralAsset,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (vars.yieldSourceAddress, vars.primaryAmount))
        });
        executions[2] = Execution({
            target: vars.yieldSourceAddress,
            value: 0,
            callData: abi.encodeCall(IEVault.deposit, (vars.primaryAmount, account))
        });
        // EVC enable calls (idempotent)
        executions[3] = Execution({
            target: vars.evc,
            value: 0,
            callData: abi.encodeCall(IEVC.enableCollateral, (account, vars.yieldSourceAddress))
        });
        executions[4] = Execution({
            target: vars.evc,
            value: 0,
            callData: abi.encodeCall(IEVC.enableController, (account, vars.controllerVault))
        });
        // Borrow
        executions[5] = Execution({
            target: vars.controllerVault,
            value: 0,
            callData: abi.encodeCall(IEVault.borrow, (vars.secondaryAmount, account))
        });
        // Reset collateral approval
        executions[6] = Execution({
            target: vars.collateralAsset,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (vars.yieldSourceAddress, 0))
        });
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

    /// @notice Decodes and validates deposit-collateral-and-borrow calldata
    /// @param data The raw hook calldata containing combined deposit + borrow parameters
    /// @return vars The decoded and validated open position variables
    function _decodeOpenData(bytes memory data) internal pure returns (OpenVars memory vars) {
        if (data.length < MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        vars.yieldSourceAddress = BytesLib.toAddress(data, COLLATERAL_VAULT_OFFSET);
        vars.debtAsset = BytesLib.toAddress(data, DEBT_ASSET_OFFSET);
        vars.collateralAsset = BytesLib.toAddress(data, COLLATERAL_ASSET_OFFSET);
        vars.evc = BytesLib.toAddress(data, EVC_OFFSET);
        vars.controllerVault = BytesLib.toAddress(data, CONTROLLER_VAULT_OFFSET);
        vars.primaryAmount = BytesLib.toUint256(data, PRIMARY_AMOUNT_OFFSET);
        vars.secondaryAmount = BytesLib.toUint256(data, SECONDARY_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeBool(data, USE_PREV_OFFSET);
        vars.maxPostDebt = BytesLib.toUint256(data, MAX_POST_DEBT_OFFSET);
        vars.maxLiqCapUtilBps = BytesLib.toUint256(data, MAX_LIQ_CAP_UTIL_BPS_OFFSET);
        vars.expectedOracle = BytesLib.toAddress(data, EXPECTED_ORACLE_OFFSET);
        vars.expectedUnitOfAccount = BytesLib.toAddress(data, EXPECTED_UNIT_OF_ACCOUNT_OFFSET);
        vars.expectedIRM = BytesLib.toAddress(data, EXPECTED_IRM_OFFSET);

        if (
            vars.yieldSourceAddress == address(0) || vars.debtAsset == address(0)
                || vars.collateralAsset == address(0) || vars.evc == address(0) || vars.controllerVault == address(0)
        ) {
            revert ADDRESS_NOT_VALID();
        }
    }

    /// @inheritdoc BaseHook
    /// @dev Stores debtAsset balance before execution for outAmount delta tracking
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getLoanTokenBalance(account, data), account);
    }

    /// @inheritdoc BaseHook
    /// @dev Computes debtAsset received (post - pre), validates maxPostDebt and liquidation capacity
    function _postExecute(address, address account, bytes calldata data) internal override {
        uint256 preBal = getOutAmount(account);
        uint256 postBal = getLoanTokenBalance(account, data);
        _setOutAmount(postBal - preBal, account);
        _setOutToken(getLoanTokenAddress(data), account);

        // Validate maxPostDebt
        address controllerVault = BytesLib.toAddress(data, CONTROLLER_VAULT_OFFSET);
        uint256 currentDebt = IEVault(controllerVault).debtOf(account);
        uint256 maxPostDebt = BytesLib.toUint256(data, MAX_POST_DEBT_OFFSET);
        if (currentDebt > maxPostDebt) revert MAX_POST_DEBT_EXCEEDED();

        // Validate liquidation capacity utilization
        uint256 maxLiqCapUtilBps = BytesLib.toUint256(data, MAX_LIQ_CAP_UTIL_BPS_OFFSET);
        if (maxLiqCapUtilBps > 0) {
            // collateralValue is FIRST, liabilityValue is SECOND
            (uint256 collateralValue, uint256 liabilityValue) =
                IEVault(controllerVault).accountLiquidity(account, true);
            // Guard against zero collateral value edge case (e.g., oracle returns 0)
            if (liabilityValue > 0 && collateralValue == 0) revert LIQUIDATION_CAPACITY_EXCEEDED();
            if (liabilityValue * 10_000 > collateralValue * maxLiqCapUtilBps) {
                revert LIQUIDATION_CAPACITY_EXCEEDED();
            }
        }
    }
}
