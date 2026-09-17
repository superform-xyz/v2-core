// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IMorphoBase, MarketParams } from "../../../vendor/morpho/IMorpho.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseMorphoMoneyMarketHook } from "./BaseMorphoMoneyMarketHook.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import {
    ISuperHook,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";

/// @title MorphoWithdrawHook
/// @author Superform Labs
/// @dev Withdraws supplied loan assets (lend-side) via IMorphoBase.withdraw.
///      To withdraw posted collateral use MorphoRepayAndWithdrawHook (IMorphoBase.withdrawCollateral).
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 yieldSourceOracleId = data.extractYieldSourceOracleId(); // Superform Morpho Blue YS id
/// @notice         address yieldSource = data.extractYieldSource(); // registry market key of the body MarketParams
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address oracle = BytesLib.toAddress(data, 92);
/// @notice         address irm = BytesLib.toAddress(data, 112);
/// @notice         uint256 lltv = BytesLib.toUint256(data, 132);
/// @notice         uint256 assets = BytesLib.toUint256(data, 164);
/// @notice         uint256 shares = BytesLib.toUint256(data, 196);
/// @dev MONEY_MARKET / OUTFLOW. The 52-byte header carries the Superform yield-source oracle id at
///      offset 0 and, at offset 32, the REGISTRY MARKET KEY of the body MarketParams
///      (`MorphoBlueMarketRegistry.computeMarketKey`) — the address SuperExecutor posts this hook's
///      OUTFLOW against and the Morpho yield-source oracle prices. It is asserted against the body
///      on build and preExecute (MARKET_KEY_MISMATCH). The Morpho Blue singleton is the `morpho`
///      immutable: the only call target. inspect() packs the singleton plus the full MarketParams
///      (loan, collateral, oracle, irm, lltv). See BaseMorphoMoneyMarketHook.
/// @dev NOTE: This hook has no usePrevHookAmount field. The inherited decodeUsePrevHookAmount
///      is overridden to return false — offset 196 is the shares uint256, not a bool.
/// @dev Both onBehalf and receiver are always set to account (consistent with all other Morpho hooks)
contract MorphoWithdrawHook is BaseMorphoMoneyMarketHook {
    using HookDataDecoder for bytes;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Minimum data length: 52-byte header + 4 addresses (80) + 3 uint256s (96) = 228 bytes
    ///         (shares at offset 196 occupies bytes 196..227)
    uint256 private constant MIN_DATA_LENGTH = 228;

    /// @notice Byte offset for lltv uint256
    uint256 private constant WITHDRAW_LLTV_OFFSET = 132;

    /// @notice Byte offset for assets uint256
    uint256 private constant ASSETS_OFFSET = 164;

    /// @notice Byte offset for shares uint256
    uint256 private constant SHARES_OFFSET = 196;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct WithdrawHookVars {
        address marketKey; // header offset 32 — registry market key (accounting / PPS key)
        MarketParams marketParams;
        uint256 assets;
        uint256 shares;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param morpho_ Address of the Morpho Blue singleton (call target)
    /// @dev OUTFLOW: SuperExecutor posts outAmount (loan token received) and `usedShares` (Morpho
    ///      supply shares burned) to SuperLedger keyed by the header market key, and charges any
    ///      realized-profit fee in `asset` (the loan token).
    constructor(address morpho_) BaseMorphoMoneyMarketHook(morpho_, ISuperHook.HookType.OUTFLOW) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Morpho Withdraw";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Withdraws supplied assets from a Morpho market";
    }

    /// @notice This hook has no usePrevHookAmount field — offset 196 is the shares uint256.
    /// @dev Override to prevent the inherited function from misreading shares[0] as a boolean.
    function decodeUsePrevHookAmount(bytes memory) external pure override returns (bool) {
        return false;
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
        _requireHeaderIsMarketKey(vars.marketKey, vars.marketParams);
        if (vars.assets == 0 && vars.shares == 0) revert AMOUNT_NOT_VALID();
        if (vars.assets != 0 && vars.shares != 0) revert AMOUNT_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: morpho,
            value: 0,
            callData: abi.encodeCall(
                IMorphoBase.withdraw, (vars.marketParams, vars.assets, vars.shares, account, account)
            )
        });
    }

    /// @inheritdoc ISuperHookInspector
    /// @dev Identity = Morpho singleton + MarketParams filter; the header market key is a pure
    ///      function of those fields and is therefore not packed separately.
    function inspect(bytes calldata data) external view override returns (bytes memory) {
        WithdrawHookVars memory vars = _decodeWithdrawData(data);

        return abi.encodePacked(
            morpho,
            vars.marketParams.loanToken,
            vars.marketParams.collateralToken,
            vars.marketParams.oracle,
            vars.marketParams.irm,
            vars.marketParams.lltv
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
    function amountRoles(bytes memory)
        external
        pure
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        meta = new ISuperHookInflowOutflow.AmountMeta[](2);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(
            ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.ASSETS
        );
        meta[1] = ISuperHookInflowOutflow.AmountMeta(
            ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.SHARES
        );
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
    /// @dev Pins the header market key, records the fee asset (loan token), snapshots the loan
    ///      token balance (outAmount baseline) and the supply-share position (usedShares baseline).
    function _preExecute(address, address account, bytes calldata data) internal override {
        WithdrawHookVars memory vars = _decodeWithdrawData(data);
        _requireHeaderIsMarketKey(vars.marketKey, vars.marketParams);
        asset = vars.marketParams.loanToken;
        _setOutAmount(getLoanTokenBalance(account, data), account);
        usedShares = _supplyShares(vars.marketParams, account);
    }

    /// @inheritdoc BaseHook
    /// @dev outAmount = loan token received (post - pre); usedShares = supply shares actually
    ///      burned (position diff), which covers withdraw-by-assets and withdraw-by-shares alike.
    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getLoanTokenBalance(account, data) - getOutAmount(account), account);
        _setOutToken(getLoanTokenAddress(data), account);
        usedShares -= _supplyShares(_decodeWithdrawData(data).marketParams, account);
    }

    /// @dev Decodes the hook data for withdraw operations
    /// @param data The calldata containing withdraw parameters
    /// @return vars The decoded withdraw hook parameters
    function _decodeWithdrawData(bytes calldata data) internal pure returns (WithdrawHookVars memory vars) {
        if (data.length < MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();
        _requireOracleId(data);

        address marketKey = data.extractYieldSource();
        address loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        address collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        address oracle = BytesLib.toAddress(data, ORACLE_OFFSET);
        address irm = BytesLib.toAddress(data, IRM_OFFSET);
        uint256 lltv = BytesLib.toUint256(data, WITHDRAW_LLTV_OFFSET);
        uint256 assets = BytesLib.toUint256(data, ASSETS_OFFSET);
        uint256 shares = BytesLib.toUint256(data, SHARES_OFFSET);

        if (
            marketKey == address(0) || loanToken == address(0) || collateralToken == address(0) || oracle == address(0)
                || irm == address(0)
        ) {
            revert ADDRESS_NOT_VALID();
        }

        MarketParams memory marketParams = _generateMarketParams(loanToken, collateralToken, oracle, irm, lltv);

        vars = WithdrawHookVars({ marketKey: marketKey, marketParams: marketParams, assets: assets, shares: shares });
    }
}
