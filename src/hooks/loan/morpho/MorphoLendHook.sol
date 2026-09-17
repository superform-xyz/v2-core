// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IMorphoBase, IMorphoStaticTyping, MarketParams } from "../../../vendor/morpho/IMorpho.sol";
import { MarketParamsLib } from "../../../vendor/morpho/MarketParamsLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseMorphoMoneyMarketHook } from "./BaseMorphoMoneyMarketHook.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISuperHook, ISuperHookResult, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title MorphoLendHook
/// @author Superform Labs
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 yieldSourceOracleId = data.extractYieldSourceOracleId(); // Superform Morpho Blue YS id
/// @notice         address yieldSource = data.extractYieldSource(); // registry market key of the body MarketParams
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address oracle = BytesLib.toAddress(data, 92);
/// @notice         address irm = BytesLib.toAddress(data, 112);
/// @notice         uint256 amount = BytesLib.toUint256(data, 132);
/// @notice         uint256 lltv = BytesLib.toUint256(data, 164);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 196);
/// @dev MONEY_MARKET / INFLOW. The 52-byte header carries the Superform yield-source oracle id at
///      offset 0 and, at offset 32, the REGISTRY MARKET KEY of the body MarketParams
///      (`MorphoBlueMarketRegistry.computeMarketKey`) — the address SuperExecutor posts this hook's
///      INFLOW against and the Morpho yield-source oracle prices. It is asserted against the body
///      on build and preExecute (MARKET_KEY_MISMATCH). The Morpho Blue singleton is the `morpho`
///      immutable: the only call target and approve spender. inspect() packs the singleton plus
///      the full MarketParams (loan, collateral, oracle, irm, lltv). See BaseMorphoMoneyMarketHook.
/// @dev WARNING: outAmount is Morpho supply shares (not assets). Unlike ERC-4626 vault shares,
///      Morpho shares are non-transferable internal accounting units. Downstream hooks using
///      usePrevHookAmount will receive a share count, not a token amount. The bundler MUST NOT
///      chain this hook into asset-denominated downstream hooks without conversion.
contract MorphoLendHook is BaseMorphoMoneyMarketHook {
    using MarketParamsLib for MarketParams;
    using HookDataDecoder for bytes;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct LendHookLocalVars {
        address marketKey; // header offset 32 — registry market key (accounting / PPS key)
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 amount;
        uint256 lltv;
        bool usePrevHookAmount;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param morpho_ Address of the Morpho Blue singleton (call target)
    /// @dev INFLOW: SuperExecutor posts this hook's outAmount (Morpho supply shares) to SuperLedger
    ///      keyed by the header market key, never by the Morpho singleton.
    constructor(address morpho_) BaseMorphoMoneyMarketHook(morpho_, ISuperHook.HookType.INFLOW) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Morpho Lend";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Lends assets to a Morpho market";
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
        LendHookLocalVars memory vars = _decodeLendHookData(data);
        MarketParams memory marketParams =
            _generateMarketParams(vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv);
        _requireHeaderIsMarketKey(vars.marketKey, marketParams);

        if (vars.usePrevHookAmount) {
            vars.amount = ISuperHookResult(prevHook).getOutAmount(account);
        }

        if (vars.amount == 0) revert AMOUNT_NOT_VALID();

        executions = new Execution[](4);
        // 1. Reset approval (handles USDT)
        executions[0] =
            Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0)) });
        // 2. Set approval for supply amount
        executions[1] = Execution({
            target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, vars.amount))
        });
        // 3. Supply to Morpho Blue as lender (supply loanToken, earn interest)
        executions[2] = Execution({
            target: morpho,
            value: 0,
            callData: abi.encodeCall(IMorphoBase.supply, (marketParams, vars.amount, 0, account, ""))
        });
        // 4. P1-1: Reset approval after supply to prevent dangling allowance
        executions[3] =
            Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0)) });
    }

    /// @inheritdoc ISuperHookInspector
    /// @dev Identity = Morpho singleton + MarketParams filter; the header market key is a pure
    ///      function of those fields and is therefore not packed separately.
    function inspect(bytes calldata data) external view override returns (bytes memory) {
        LendHookLocalVars memory vars = _decodeLendHookData(data);

        MarketParams memory marketParams =
            _generateMarketParams(vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv);

        return abi.encodePacked(
            morpho,
            marketParams.loanToken,
            marketParams.collateralToken,
            marketParams.oracle,
            marketParams.irm,
            marketParams.lltv
        );
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Decodes packed calldata into LendHookLocalVars
    /// @param data The packed calldata (minimum 197 bytes)
    /// @return vars Decoded parameters for the lending operation
    function _decodeLendHookData(bytes memory data) internal pure returns (LendHookLocalVars memory vars) {
        if (data.length < SUPPLY_MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();
        _requireOracleId(data);

        address marketKey = data.extractYieldSource();
        address loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        address collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        address oracle = BytesLib.toAddress(data, ORACLE_OFFSET);
        address irm = BytesLib.toAddress(data, IRM_OFFSET);

        if (
            marketKey == address(0) || loanToken == address(0) || collateralToken == address(0) || oracle == address(0)
                || irm == address(0)
        ) {
            revert ADDRESS_NOT_VALID();
        }

        uint256 amount = _decodeAmount(data);
        uint256 lltv = BytesLib.toUint256(data, LLTV_OFFSET);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        return LendHookLocalVars({
            marketKey: marketKey,
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: oracle,
            irm: irm,
            amount: amount,
            lltv: lltv,
            usePrevHookAmount: usePrevHookAmount
        });
    }

    /// @notice Stores the current Morpho supply shares before execution
    /// @param account The smart account whose position is tracked
    /// @param data Encoded hook calldata containing market parameters
    function _preExecute(address, address account, bytes calldata data) internal override {
        // Decode once: pin the header market key and read the supply shares from the same vars.
        LendHookLocalVars memory vars = _decodeLendHookData(data);
        MarketParams memory marketParams =
            _generateMarketParams(vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv);
        _requireHeaderIsMarketKey(vars.marketKey, marketParams);
        asset = vars.loanToken;
        _setOutAmount(_supplyShares(marketParams, account), account);
    }

    /// @notice Computes supply shares received (always positive) and sets as outAmount
    /// @param account The smart account whose position is tracked
    /// @param data Encoded hook calldata containing market parameters
    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getSupplyShares(account, data) - getOutAmount(account), account);
        _setOutToken(getLoanTokenAddress(data), account);
    }

    /// @notice Queries the account's current Morpho supply shares for the market
    /// @param account The account to query
    /// @param data Encoded hook calldata containing market parameters
    /// @return supplyShares The account's supply shares in the Morpho market
    function _getSupplyShares(address account, bytes memory data) internal view returns (uint256 supplyShares) {
        LendHookLocalVars memory vars = _decodeLendHookData(data);
        return _supplyShares(
            _generateMarketParams(vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv), account
        );
    }
}
