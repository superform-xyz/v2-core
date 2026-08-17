// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
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

/// @title EulerBorrowHook
/// @author Superform Labs
/// @notice Borrows assets from an Euler V2 controller EVault
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
/// @dev Includes EVC enableCollateral + enableController calls (idempotent) before borrow.
///      No constructor args — vault and EVC addresses come from calldata (Aave V3 pattern).
contract EulerBorrowHook is BaseEulerLoanHook {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant MIN_DATA_LENGTH = 197;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct BorrowVars {
        /// @dev yieldSourceAddress is the collateral vault (EVault)
        address yieldSourceAddress;
        /// @dev The token being borrowed
        address debtAsset;
        /// @dev The Ethereum Vault Connector address
        address evc;
        /// @dev The Euler EVault that manages the debt position
        address controllerVault;
        /// @dev Amount of debt to borrow
        uint256 amount;
        /// @dev If true, use the previous hook's outAmount instead of `amount`
        bool usePrevHookAmount;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() BaseEulerLoanHook(HookSubTypes.LOAN) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Euler Borrow";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Borrows assets from an Euler V2 controller EVault";
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
        BorrowVars memory vars = _decodeBorrowData(data);

        if (vars.usePrevHookAmount) {
            vars.amount = ISuperHookResult(prevHook).getOutAmount(account);
        }

        if (vars.amount == 0) revert AMOUNT_NOT_VALID();

        // Enforce zero-or-one controller invariant
        address[] memory controllers = IEVC(vars.evc).getControllers(account);
        if (controllers.length > 0 && controllers[0] != vars.controllerVault) {
            revert CONTROLLER_ALREADY_SET();
        }

        executions = new Execution[](3);
        // enableCollateral and enableController are idempotent
        executions[0] = Execution({
            target: vars.evc,
            value: 0,
            callData: abi.encodeCall(IEVC.enableCollateral, (account, vars.yieldSourceAddress))
        });
        executions[1] = Execution({
            target: vars.evc,
            value: 0,
            callData: abi.encodeCall(IEVC.enableController, (account, vars.controllerVault))
        });
        executions[2] = Execution({
            target: vars.controllerVault,
            value: 0,
            callData: abi.encodeCall(IEVault.borrow, (vars.amount, account))
        });
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

    /// @notice Decodes and validates borrow calldata
    /// @param data The raw hook calldata containing borrow parameters
    /// @return vars The decoded and validated borrow variables
    function _decodeBorrowData(bytes memory data) internal pure returns (BorrowVars memory vars) {
        if (data.length < MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        vars.yieldSourceAddress = BytesLib.toAddress(data, COLLATERAL_VAULT_OFFSET);
        vars.debtAsset = BytesLib.toAddress(data, DEBT_ASSET_OFFSET);
        vars.evc = BytesLib.toAddress(data, EVC_OFFSET);
        vars.controllerVault = BytesLib.toAddress(data, CONTROLLER_VAULT_OFFSET);
        vars.amount = BytesLib.toUint256(data, PRIMARY_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeBool(data, USE_PREV_OFFSET);

        if (vars.yieldSourceAddress == address(0) || vars.debtAsset == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        if (vars.evc == address(0) || vars.controllerVault == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
    }

    /// @inheritdoc BaseHook
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getLoanTokenBalance(account, data), account);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getLoanTokenBalance(account, data) - getOutAmount(account), account);
        _setOutToken(getLoanTokenAddress(data), account);
    }
}
