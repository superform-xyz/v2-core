// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IMorphoBase, MarketParams } from "../../../vendor/morpho/IMorpho.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseMorphoLoanHook } from "./BaseMorphoLoanHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookInspector, ISuperHookInflowOutflow, ISuperHookOutflow } from "../../../interfaces/ISuperHook.sol";

/// @title MorphoWithdrawHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address loanToken = BytesLib.toAddress(data, 0);
/// @notice         address collateralToken = BytesLib.toAddress(data, 20);
/// @notice         address oracle = BytesLib.toAddress(data, 40);
/// @notice         address irm = BytesLib.toAddress(data, 60);
/// @notice         uint256 lltv = BytesLib.toUint256(data, 80);
/// @notice         uint256 assets = BytesLib.toUint256(data, 112);
/// @notice         uint256 shares = BytesLib.toUint256(data, 144);
/// @dev Both onBehalf and receiver are always set to account (consistent with all other Morpho hooks)
contract MorphoWithdrawHook is BaseMorphoLoanHook {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Minimum data length: 4 addresses (80) + 3 uint256s (96) = 176 bytes
    uint256 private constant MIN_DATA_LENGTH = 176;

    /// @notice Byte offset for lltv uint256
    uint256 private constant WITHDRAW_LLTV_OFFSET = 80;

    /// @notice Byte offset for assets uint256
    uint256 private constant ASSETS_OFFSET = 112;

    /// @notice Byte offset for shares uint256
    uint256 private constant SHARES_OFFSET = 144;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct WithdrawHookVars {
        MarketParams marketParams;
        uint256 assets;
        uint256 shares;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param morpho_ Address of the Morpho Blue protocol
    constructor(address morpho_) BaseMorphoLoanHook(morpho_, HookSubTypes.LOAN_REPAY) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Morpho Withdraw";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Withdraws collateral from a Morpho market";
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
        WithdrawHookVars memory vars = _decodeWithdrawData(data);
        if (vars.assets == 0 && vars.shares == 0) revert AMOUNT_NOT_VALID();
        if (vars.assets != 0 && vars.shares != 0) revert AMOUNT_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: morpho,
            value: 0,
            callData: abi.encodeCall(IMorphoBase.withdraw, (vars.marketParams, vars.assets, vars.shares, account, account))
        });
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        WithdrawHookVars memory vars = _decodeWithdrawData(data);

        return abi.encodePacked(
            vars.marketParams.loanToken,
            vars.marketParams.collateralToken,
            vars.marketParams.oracle,
            vars.marketParams.irm
        );
    }

    /// @inheritdoc ISuperHookInflowOutflow
    /// @dev Returns both assets and shares slots; exactly one must be nonzero (XOR invariant)
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = BytesLib.toUint256(data, ASSETS_OFFSET);
        amounts[1] = BytesLib.toUint256(data, SHARES_OFFSET);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    /// @dev Slot 0 = assets (IN, ASSETS), Slot 1 = shares (IN, SHARES)
    ///      OMS picks the slot matching the intent's denomination
    function amountRoles(bytes memory) external pure override returns (ISuperHookInflowOutflow.AmountMeta[] memory meta) {
        meta = new ISuperHookInflowOutflow.AmountMeta[](2);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.ASSETS);
        meta[1] = ISuperHookInflowOutflow.AmountMeta(ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.SHARES);
    }

    /// @inheritdoc ISuperHookOutflow
    /// @dev Enforces assets-XOR-shares invariant: after replacement, exactly one of
    ///      assets/shares must be nonzero (Morpho requires exactly one to be set)
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

        // Enforce assets-XOR-shares BEFORE mutating data: exactly one must be nonzero
        if (amounts[0] != 0 && amounts[1] != 0) revert AMOUNT_NOT_VALID();
        if (amounts[0] == 0 && amounts[1] == 0) revert AMOUNT_NOT_VALID();

        data = _replaceCalldataAmount(data, amounts[0], ASSETS_OFFSET);
        return _replaceCalldataAmount(data, amounts[1], SHARES_OFFSET);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    /// @dev Stores account's loanToken balance before Morpho withdraw executes
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getLoanTokenBalance(account, data), account);
    }

    /// @inheritdoc BaseHook
    /// @dev Computes loanToken received by account (post - pre) and sets as outAmount
    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getLoanTokenBalance(account, data) - getOutAmount(account), account);
        _setOutToken(asset, account);
    }

    /// @dev Decodes the hook data for withdraw operations
    /// @param data The calldata containing withdraw parameters
    /// @return vars The decoded withdraw hook parameters
    function _decodeWithdrawData(bytes calldata data) internal pure returns (WithdrawHookVars memory vars) {
        if (data.length < MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        address loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        address collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        address oracle = BytesLib.toAddress(data, ORACLE_OFFSET);
        address irm = BytesLib.toAddress(data, IRM_OFFSET);
        uint256 lltv = BytesLib.toUint256(data, WITHDRAW_LLTV_OFFSET);
        uint256 assets = BytesLib.toUint256(data, ASSETS_OFFSET);
        uint256 shares = BytesLib.toUint256(data, SHARES_OFFSET);

        if (loanToken == address(0) || collateralToken == address(0) || oracle == address(0) || irm == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

        MarketParams memory marketParams = _generateMarketParams(loanToken, collateralToken, oracle, irm, lltv);

        vars = WithdrawHookVars({
            marketParams: marketParams,
            assets: assets,
            shares: shares
        });
    }
}
