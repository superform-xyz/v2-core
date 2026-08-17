// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// euler
import { IEVault } from "../../../vendor/euler/IEVault.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseEulerLoanHook } from "./BaseEulerLoanHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookResult, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title EulerDepositCollateralHook
/// @author Superform Labs
/// @notice Deposits collateral into an Euler V2 EVault
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
/// @dev No constructor args — vault and EVC addresses come from calldata (Aave V3 pattern).
/// @dev outAmount tracks collateral consumed (preBal - postBal), not vault shares received.
contract EulerDepositCollateralHook is BaseEulerLoanHook {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant MIN_DATA_LENGTH = 197;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct DepositVars {
        /// @dev yieldSourceAddress is the collateral vault (EVault)
        address yieldSourceAddress;
        /// @dev The underlying collateral token to deposit
        address collateralAsset;
        /// @dev Amount of collateral to deposit
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
        return "Euler Deposit Collateral";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Deposits collateral into an Euler V2 EVault";
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
        DepositVars memory vars = _decodeDepositData(data);

        if (vars.usePrevHookAmount) {
            vars.amount = ISuperHookResult(prevHook).getOutAmount(account);
        }

        if (vars.amount == 0) revert AMOUNT_NOT_VALID();

        executions = new Execution[](4);
        executions[0] = Execution({
            target: vars.collateralAsset,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (vars.yieldSourceAddress, 0))
        });
        executions[1] = Execution({
            target: vars.collateralAsset,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (vars.yieldSourceAddress, vars.amount))
        });
        executions[2] = Execution({
            target: vars.yieldSourceAddress,
            value: 0,
            callData: abi.encodeCall(IEVault.deposit, (vars.amount, account))
        });
        executions[3] = Execution({
            target: vars.collateralAsset,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (vars.yieldSourceAddress, 0))
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

    /// @notice Decodes and validates deposit collateral calldata
    /// @param data The raw hook calldata containing deposit parameters
    /// @return vars The decoded and validated deposit variables
    function _decodeDepositData(bytes memory data) internal pure returns (DepositVars memory vars) {
        if (data.length < MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        vars.yieldSourceAddress = BytesLib.toAddress(data, COLLATERAL_VAULT_OFFSET);
        vars.collateralAsset = BytesLib.toAddress(data, COLLATERAL_ASSET_OFFSET);
        vars.amount = BytesLib.toUint256(data, PRIMARY_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeBool(data, USE_PREV_OFFSET);

        if (vars.yieldSourceAddress == address(0) || vars.collateralAsset == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
    }

    /// @inheritdoc BaseHook
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getCollateralTokenBalance(account, data), account);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getOutAmount(account) - getCollateralTokenBalance(account, data), account);
        _setOutToken(getCollateralTokenAddress(data), account);
    }
}
