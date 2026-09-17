// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IMorphoBase, IMorphoStaticTyping, MarketParams, Id } from "../../../vendor/morpho/IMorpho.sol";
import { MarketParamsLib } from "../../../vendor/morpho/MarketParamsLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseMorphoLoanHook } from "./BaseMorphoLoanHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISuperHookResult, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title MorphoLendHook
/// @author Superform Labs
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 yieldSourceOracleId = data.extractYieldSourceOracleId(); // Superform Morpho Blue YS id
/// @notice         address yieldSource = data.extractYieldSource(); // Morpho Blue singleton (call target)
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address oracle = BytesLib.toAddress(data, 92);
/// @notice         address irm = BytesLib.toAddress(data, 112);
/// @notice         uint256 amount = BytesLib.toUint256(data, 132);
/// @notice         uint256 lltv = BytesLib.toUint256(data, 164);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 196);
/// @dev The 52-byte header carries the same identity as the ERC-4626 hooks: the Superform
///      yield-source oracle id at offset 0 and the yield source (the Morpho Blue singleton — the
///      call target) at offset 32. Every Morpho call targets the header-derived yieldSource; the
///      `morpho` immutable is the primary call-target pin, asserted at build/preExecute before use.
///      inspect() packs the header yieldSource plus the full MarketParams (loan, collateral,
///      oracle, irm, lltv).
/// @dev WARNING: outAmount is Morpho supply shares (not assets). Unlike ERC-4626 vault shares,
///      Morpho shares are non-transferable internal accounting units. Downstream hooks using
///      usePrevHookAmount will receive a share count, not a token amount. The bundler MUST NOT
///      chain this hook into asset-denominated downstream hooks without conversion.
contract MorphoLendHook is BaseMorphoLoanHook {
    using MarketParamsLib for MarketParams;
    using HookDataDecoder for bytes;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct LendHookLocalVars {
        address yieldSource;
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

    /// @param morpho_ Address of the Morpho Blue protocol
    constructor(address morpho_) BaseMorphoLoanHook(morpho_, HookSubTypes.LOAN) { }

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
        _requireYieldSourceIsMorpho(vars.yieldSource);

        if (vars.usePrevHookAmount) {
            vars.amount = ISuperHookResult(prevHook).getOutAmount(account);
        }

        if (vars.amount == 0) revert AMOUNT_NOT_VALID();

        MarketParams memory marketParams =
            _generateMarketParams(vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv);

        executions = new Execution[](4);
        // 1. Reset approval (handles USDT)
        executions[0] = Execution({
            target: vars.loanToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (vars.yieldSource, 0))
        });
        // 2. Set approval for supply amount
        executions[1] = Execution({
            target: vars.loanToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (vars.yieldSource, vars.amount))
        });
        // 3. Supply to Morpho Blue as lender (supply loanToken, earn interest)
        executions[2] = Execution({
            target: vars.yieldSource,
            value: 0,
            callData: abi.encodeCall(IMorphoBase.supply, (marketParams, vars.amount, 0, account, ""))
        });
        // 4. P1-1: Reset approval after supply to prevent dangling allowance
        executions[3] = Execution({
            target: vars.loanToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (vars.yieldSource, 0))
        });
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        LendHookLocalVars memory vars = _decodeLendHookData(data);

        MarketParams memory marketParams =
            _generateMarketParams(vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv);

        return abi.encodePacked(
            vars.yieldSource,
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
    /// @param data The packed calldata (minimum 145 bytes)
    /// @return vars Decoded parameters for the lending operation
    function _decodeLendHookData(bytes memory data) internal pure returns (LendHookLocalVars memory vars) {
        if (data.length < SUPPLY_MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        address yieldSource = data.extractYieldSource();
        address loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        address collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        address oracle = BytesLib.toAddress(data, ORACLE_OFFSET);
        address irm = BytesLib.toAddress(data, IRM_OFFSET);

        if (
            yieldSource == address(0) || loanToken == address(0) || collateralToken == address(0)
                || oracle == address(0) || irm == address(0)
        ) {
            revert ADDRESS_NOT_VALID();
        }

        uint256 amount = _decodeAmount(data);
        uint256 lltv = BytesLib.toUint256(data, LLTV_OFFSET);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        return LendHookLocalVars({
            yieldSource: yieldSource,
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
        // Decode once: pin the header yield source and compute supply shares from the same vars.
        LendHookLocalVars memory vars = _decodeLendHookData(data);
        _requireYieldSourceIsMorpho(vars.yieldSource);
        _setOutAmount(_getSupplyShares(vars, account), account);
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
        return _getSupplyShares(_decodeLendHookData(data), account);
    }

    /// @notice Overload that reuses already-decoded vars to avoid a second decode
    /// @param vars Decoded lend hook parameters
    /// @param account The account to query
    /// @return supplyShares The account's supply shares in the Morpho market
    function _getSupplyShares(
        LendHookLocalVars memory vars,
        address account
    )
        internal
        view
        returns (uint256 supplyShares)
    {
        MarketParams memory marketParams =
            _generateMarketParams(vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv);
        (supplyShares,,) = IMorphoStaticTyping(morpho).position(marketParams.id(), account);
    }
}
