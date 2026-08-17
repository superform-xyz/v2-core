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
import { ISuperHookResult, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title EulerRepayHook
/// @author Superform Labs
/// @notice Repays debt to an Euler V2 controller EVault
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @dev         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @dev         address yieldSourceAddress = BytesLib.toAddress(data, 32);  // collateralVault
/// @dev         address debtAsset = BytesLib.toAddress(data, 52);
/// @dev         address collateralAsset = BytesLib.toAddress(data, 72);
/// @dev         address evc = BytesLib.toAddress(data, 92);
/// @dev         address controllerVault = BytesLib.toAddress(data, 112);
/// @dev         uint256 amount = BytesLib.toUint256(data, 132);
/// @dev         uint256 secondaryAmount = BytesLib.toUint256(data, 164);  // unused
/// @dev         bool usePrevHookAmount = _decodeBool(data, 196);
/// @dev         bool isFullRepayment = _decodeBool(data, 197);
/// @dev For full repayment, uses type(uint256).max as the repay amount so Euler V2 calculates
///      the exact debt atomically at execution time, eliminating interest accrual staleness.
/// @dev Full repayment also calls disableController + disableCollateral to clean up EVC state.
/// @dev No constructor args — vault addresses come from calldata (Aave V3 pattern).
contract EulerRepayHook is BaseEulerLoanHook {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant IS_FULL_REPAYMENT_OFFSET = 197;
    uint256 internal constant MIN_DATA_LENGTH = 198;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct RepayVars {
        /// @dev The collateral vault (EVault) — needed for disableCollateral on full repay
        address yieldSourceAddress;
        /// @dev The token being repaid
        address debtAsset;
        /// @dev The Ethereum Vault Connector address
        address evc;
        /// @dev The Euler EVault that holds the debt position
        address controllerVault;
        /// @dev The amount of debt to repay (ignored if isFullRepayment is true)
        uint256 amount;
        /// @dev If true, use the previous hook's outAmount instead of `amount`
        bool usePrevHookAmount;
        /// @dev If true, repay entire outstanding debt, disable controller, and disable collateral
        bool isFullRepayment;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() BaseEulerLoanHook(HookSubTypes.LOAN_REPAY) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Euler Repay";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Repays debt to an Euler V2 controller EVault";
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW METHODS
    //////////////////////////////////////////////////////////////*/

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
        RepayVars memory vars = _decodeRepayData(data);

        uint256 repayAmount;

        if (vars.isFullRepayment) {
            // Full repay: verify debt exists, then use type(uint256).max so EVault calculates exact
            // debt atomically at execution time (eliminates interest accrual staleness)
            if (IEVault(vars.controllerVault).debtOf(account) == 0) revert AMOUNT_NOT_VALID();

            // Full repay includes disableController + disableCollateral cleanup
            executions = new Execution[](6);
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
                target: vars.controllerVault,
                value: 0,
                callData: abi.encodeCall(IEVault.disableController, ())
            });
            // Clean up EVC collateral registration to free collateral slots
            executions[5] = Execution({
                target: vars.evc,
                value: 0,
                callData: abi.encodeCall(IEVC.disableCollateral, (account, vars.yieldSourceAddress))
            });
        } else {
            // Partial repay
            if (vars.usePrevHookAmount) {
                vars.amount = ISuperHookResult(prevHook).getOutAmount(account);
            }
            repayAmount = vars.amount;
            if (repayAmount == 0) revert AMOUNT_NOT_VALID();

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
        }
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

    /// @notice Decodes and validates repay calldata
    /// @param data The raw hook calldata containing repay parameters
    /// @return vars The decoded and validated repay variables
    function _decodeRepayData(bytes memory data) internal pure returns (RepayVars memory vars) {
        if (data.length < MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        vars.yieldSourceAddress = BytesLib.toAddress(data, COLLATERAL_VAULT_OFFSET);
        vars.debtAsset = BytesLib.toAddress(data, DEBT_ASSET_OFFSET);
        vars.evc = BytesLib.toAddress(data, EVC_OFFSET);
        vars.controllerVault = BytesLib.toAddress(data, CONTROLLER_VAULT_OFFSET);
        vars.amount = BytesLib.toUint256(data, PRIMARY_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeBool(data, USE_PREV_OFFSET);
        vars.isFullRepayment = _decodeBool(data, IS_FULL_REPAYMENT_OFFSET);

        if (
            vars.yieldSourceAddress == address(0) || vars.debtAsset == address(0) || vars.evc == address(0)
                || vars.controllerVault == address(0)
        ) {
            revert ADDRESS_NOT_VALID();
        }
    }

    /// @inheritdoc BaseHook
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getLoanTokenBalance(account, data), account);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getOutAmount(account) - getLoanTokenBalance(account, data), account);
        _setOutToken(getLoanTokenAddress(data), account);
    }
}
