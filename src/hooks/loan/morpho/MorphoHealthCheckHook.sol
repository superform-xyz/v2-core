// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { MathLib } from "../../../vendor/morpho/MathLib.sol";
import { SharesMathLib } from "../../../vendor/morpho/SharesMathLib.sol";
import { MarketParamsLib } from "../../../vendor/morpho/MarketParamsLib.sol";
import { MorphoBalancesLib } from "../../../vendor/morpho/MorphoBalancesLib.sol";
import { IOracle } from "../../../vendor/morpho/IOracle.sol";
import { Id, IMorpho, IMorphoStaticTyping, MarketParams } from "../../../vendor/morpho/IMorpho.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";

/// @title MorphoHealthCheckHook
/// @author Superform Labs
/// @notice NONACCOUNTING guard: reverts unless the executing account's Morpho Blue health factor on the named
///         market is at or above `minHealthFactor`. Moves no funds, grants no approvals, forwards the previous
///         hook's output untouched (PASSTHROUGH). Place it after a BORROW / RELEASE / swap leg so the whole
///         userOp unwinds when the position would end up too close to liquidation.
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific), exactly 196 bytes:
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0); // reserved, not validated
/// @notice         address yieldSource = BytesLib.toAddress(data, 32); // registry market key of the body MarketParams
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address oracle = BytesLib.toAddress(data, 92); // Morpho IOracle — read ONLY to compare, never to
/// size @notice         address irm = BytesLib.toAddress(data, 112);
/// @notice         uint256 lltv = BytesLib.toUint256(data, 132);
/// @notice         uint256 minHealthFactor = BytesLib.toUint256(data, 164); // WAD; 1e18 = Morpho liquidation line
/// @dev HEALTH FACTOR. Morpho Blue has no health getter, so the hook evaluates Morpho's own `_isHealthy` at
///      `block.timestamp`: `borrowed = borrowShares.toAssetsUp(totalBorrowAssets, totalBorrowShares)` after view
///      accrual (`MorphoBalancesLib.expectedBorrowBalances`), `maxBorrow = collateral.mulDivDown(price,
///      ORACLE_PRICE_SCALE).wMulDown(lltv)`, `healthFactor = maxBorrow.wDivDown(borrowed)`. Debt rounds UP,
///      max borrow and the ratio round DOWN, so the guard is never more lenient than the venue: at
///      `minHealthFactor == 1e18` it passes iff Morpho's `_isHealthy` is true. No debt returns
///      `type(uint256).max` without touching the oracle (Morpho's own short-circuit).
///      ORACLE. The V2 loan hooks treat the oracle as identity only ("never priced") so a manipulated price can
///      never size an amount they move. This hook is the one documented exception: `price()` feeds a `>=`
///      comparison and nothing else. A reverting oracle fails the userOp closed and a low price reverts a healthy
///      position (fail-closed). A HIGH price overstates collateral for Morpho and this guard alike: the guard is
///      conservative relative to the venue's contemporaneous oracle and math, not an independent price-integrity
///      or executable-exit check.
///      WHERE THE CHECK RUNS. `_buildHookExecutions` returns no executions, so `build()` yields exactly
///      `[preExecute, postExecute]`. The executor builds hook N only after hook N-1 executed, so the build-time
///      read already observes post-action state; `_postExecute` repeats the read as the authoritative one from
///      inside the account's batch, so the guard holds under any executor scheduling.
///      HEADER IDENTITY. Offset 32 must equal the registry market key of the body MarketParams (the Morpho
///      market id truncated to an address, identical to `MorphoBlueMarketRegistry.computeMarketKey`), else
///      `MARKET_KEY_MISMATCH`. The Morpho singleton is the `morpho` immutable; the only external reads are
///      `position`, `market`, `borrowRateView` (via the body IRM) and `price` (via the body oracle), all staticcalls.
///      `minHealthFactor` below 1e18 is a signing bug (the venue already enforces 1e18 on its own legs) and is
///      rejected; `type(uint256).max` is allowed and means "must have no debt".
contract MorphoHealthCheckHook is BaseHook, ISuperHookInflowOutflow {
    using HookDataDecoder for bytes;
    using MarketParamsLib for MarketParams;
    using MathLib for uint256;
    using SharesMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Exact calldata length
    uint256 private constant DATA_LENGTH = 196;
    uint256 private constant LOAN_TOKEN_OFFSET = 52;
    uint256 private constant COLLATERAL_TOKEN_OFFSET = 72;
    uint256 private constant ORACLE_OFFSET = 92;
    uint256 private constant IRM_OFFSET = 112;
    uint256 private constant LLTV_OFFSET = 132;
    uint256 private constant MIN_HEALTH_FACTOR_OFFSET = 164;

    /// @dev Morpho Blue `ConstantsLib.ORACLE_PRICE_SCALE` (not vendored): `IOracle.price()` is scaled by 1e36
    uint256 public constant ORACLE_PRICE_SCALE = 1e36;
    /// @dev WAD health factor at which Morpho liquidates; same name and value as the Aave V4 Spoke constant
    uint256 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18;

    /// @notice The Morpho Blue singleton
    address public immutable morpho;
    /// @notice Static-typing view of the singleton (position / market reads)
    IMorphoStaticTyping public immutable morphoStaticTyping;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice The guard tripped: the account's health factor is below the committed minimum
    error HEALTH_FACTOR_BELOW_MINIMUM(uint256 healthFactor, uint256 minHealthFactor);
    /// @notice `minHealthFactor` is below the liquidation line (1e18)
    error INVALID_MIN_HEALTH_FACTOR();
    /// @notice Calldata is not exactly 196 bytes
    error INVALID_DATA_LENGTH();
    /// @notice Header market key (offset 32) does not match the body MarketParams
    error MARKET_KEY_MISMATCH();
    /// @notice Loan and collateral token are the same address
    error IDENTICAL_TOKENS();

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Vars {
        address marketKey;
        MarketParams marketParams;
        uint256 minHealthFactor;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param morpho_ The Morpho Blue singleton on this chain
    constructor(address morpho_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.MISC) {
        if (morpho_ == address(0)) revert ADDRESS_NOT_VALID();
        morpho = morpho_;
        morphoStaticTyping = IMorphoStaticTyping(morpho_);
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Morpho Health Check";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Reverts unless the account's Morpho Blue health factor on the market is at or above the minimum";
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice The WAD health factor this guard would enforce for `account` with `data`, evaluated now
    /// @dev Lets the OMS size a leg against the exact number the guard reads on-chain. `type(uint256).max` = no debt.
    /// @param data The 196-byte hook data
    /// @param account The account to evaluate
    /// @return The WAD health factor
    function previewHealthFactor(bytes calldata data, address account) external view returns (uint256) {
        Vars memory vars = _decode(data);
        return _healthFactor(vars.marketParams, account);
    }

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
        _requireHealthy(account, data);
        executions = new Execution[](0);
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookInspector
    /// @dev The 132-byte Morpho V2 identity payload (market key + MarketParams) followed by `minHealthFactor`
    ///      (164 bytes total). The threshold IS part of the leaf: a SuperVault strategy's permission commits to an
    ///      exact minimum, so an execution signer holding a proof for one margin cannot present it with a lower one.
    ///      Each distinct threshold is therefore a distinct leaf. The ERC-4337 path commits the full calldata anyway.
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        Vars memory vars = _decode(data);
        return abi.encodePacked(
            vars.marketKey,
            vars.marketParams.loanToken,
            vars.marketParams.collateralToken,
            vars.marketParams.oracle,
            vars.marketParams.irm,
            vars.marketParams.lltv,
            vars.minHealthFactor
        );
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](0);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory)
        external
        pure
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        meta = new ISuperHookInflowOutflow.AmountMeta[](0);
    }

    /// @inheritdoc IERC165
    /// @dev S2: implements ISuperHookInflowOutflow (decode-only) but NOT ISuperHookOutflow
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        if (interfaceId == type(ISuperHookInflowOutflow).interfaceId) return true;
        if (interfaceId == type(ISuperHookOutflow).interfaceId) return false;
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(ISuperHook).interfaceId
            || interfaceId == type(ISuperHookResult).interfaceId || interfaceId == type(ISuperHookInspector).interfaceId;
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Authoritative read, from inside the account's batch after every preceding hook executed
    function _postExecute(address, address account, bytes calldata data) internal view override {
        _requireHealthy(account, data);
    }

    /// @dev Guard only — forwards the previous hook's outAmount + outToken
    function _pipeMode() internal pure override returns (PipeMode) {
        return PipeMode.PASSTHROUGH;
    }

    function _requireHealthy(address account, bytes memory data) internal view {
        Vars memory vars = _decode(data);
        uint256 healthFactor = _healthFactor(vars.marketParams, account);
        if (healthFactor < vars.minHealthFactor) {
            revert HEALTH_FACTOR_BELOW_MINIMUM(healthFactor, vars.minHealthFactor);
        }
    }

    /// @dev Pure: length, zero checks, header pin, threshold floor. Reads no state so `inspect()` stays pure.
    function _decode(bytes memory data) internal pure returns (Vars memory vars) {
        if (data.length != DATA_LENGTH) revert INVALID_DATA_LENGTH();

        vars.marketKey = data.extractYieldSource();
        vars.marketParams = MarketParams({
            loanToken: BytesLib.toAddress(data, LOAN_TOKEN_OFFSET),
            collateralToken: BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET),
            oracle: BytesLib.toAddress(data, ORACLE_OFFSET),
            irm: BytesLib.toAddress(data, IRM_OFFSET),
            lltv: BytesLib.toUint256(data, LLTV_OFFSET)
        });
        vars.minHealthFactor = BytesLib.toUint256(data, MIN_HEALTH_FACTOR_OFFSET);

        if (
            vars.marketKey == address(0) || vars.marketParams.loanToken == address(0)
                || vars.marketParams.collateralToken == address(0) || vars.marketParams.oracle == address(0)
                || vars.marketParams.irm == address(0)
        ) {
            revert ADDRESS_NOT_VALID();
        }
        if (vars.marketParams.loanToken == vars.marketParams.collateralToken) revert IDENTICAL_TOKENS();
        // Same derivation as BaseMorphoLoanHookV2._marketKey / MorphoBlueMarketRegistry.computeMarketKey
        if (vars.marketKey != address(uint160(uint256(Id.unwrap(vars.marketParams.id()))))) {
            revert MARKET_KEY_MISMATCH();
        }
        if (vars.minHealthFactor < HEALTH_FACTOR_LIQUIDATION_THRESHOLD) revert INVALID_MIN_HEALTH_FACTOR();
    }

    /// @dev WAD health factor exactly as Morpho's `_isHealthy` would evaluate it at `block.timestamp`
    function _healthFactor(MarketParams memory marketParams, address account) internal view returns (uint256) {
        (, uint128 borrowShares, uint128 collateral) = morphoStaticTyping.position(marketParams.id(), account);
        // No debt: healthy by definition, and the oracle is never consulted (Morpho's own short-circuit)
        if (borrowShares == 0) return type(uint256).max;

        (uint256 totalBorrowAssets, uint256 totalBorrowShares) =
            MorphoBalancesLib.expectedBorrowBalances(IMorpho(morpho), marketParams);
        // >= 1 whenever borrowShares > 0 (virtual shares, rounds up), so the division below is safe
        uint256 borrowed = uint256(borrowShares).toAssetsUp(totalBorrowAssets, totalBorrowShares);

        uint256 maxBorrow = uint256(collateral).mulDivDown(IOracle(marketParams.oracle).price(), ORACLE_PRICE_SCALE)
            .wMulDown(marketParams.lltv);
        return maxBorrow.wDivDown(borrowed);
    }
}
