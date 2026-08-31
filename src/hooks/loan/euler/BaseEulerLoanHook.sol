// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IEVC } from "../../../vendor/euler/IEVC.sol";
import { IEVault } from "../../../vendor/euler/IEVault.sol";
import { IGenericFactory } from "../../../vendor/euler/IGenericFactory.sol";

// Superform
import { BaseLoanHook } from "../BaseLoanHook.sol";
import { BaseLoanHookV2 } from "../BaseLoanHookV2.sol";

/// @title BaseEulerLoanHook
/// @author Superform Labs
/// @notice Base abstract hook for the Euler EVK/EVC loan hooks (open / close / standalone repay)
/// @dev One canonical 197-byte layout is shared by all three Euler hooks
///      (52-byte strategy header carrying meaningful fields + hook-specific):
/// @notice         bytes32 configId = BytesLib.toBytes32(data, 0); // carried, not validated
/// @notice         address collateralVault = BytesLib.toAddress(data, 32); // repay: reserved ZERO
/// @notice         address debtAsset = BytesLib.toAddress(data, 52); // = loanToken slot
/// @notice         address collateralAsset = BytesLib.toAddress(data, 72); // repay: reserved ZERO
/// @notice         address evc = BytesLib.toAddress(data, 92); // must equal the pinned EVC_ADDRESS
/// @notice         address controllerVault = BytesLib.toAddress(data, 112); // debt vault
/// @notice         uint256 primaryAmount = BytesLib.toUint256(data, 132); // open: deposit; else CAP
/// @notice         uint256 secondaryAmount = BytesLib.toUint256(data, 164); // repay: reserved ZERO
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 196); // canonical 0x00/0x01
/// @dev The amount slots (132/164) and the boolean (196) deliberately match the inherited
///      BaseLoanHook offsets, so the single-slot sizing accessors apply unchanged to the
///      standalone repay hook and the BaseLoanHookV2 two-slot helpers to the composites.
///      Repay semantics use a CAP, not a max sentinel: the resolved repayment is
///      min(cap, debtOf(account)) read at build time. EVK interest accrual is timestamp-based and
///      all vault views virtually accrue, so within one transaction build-time and
///      preExecute-time resolutions are identical — no accrual call is needed (unlike Morpho).
///      A zero outstanding debt resolves the repay leg to zero (predicted clear) instead of
///      reverting, so a third party gifting a full repayment cannot cancel a signed intent.
///      TRUST PINNING: the EVC singleton and the EVK GenericFactory (eVaultFactory) are
///      constructor-pinned immutables (one canonical instance of each per chain, published in
///      euler-xyz/euler-interfaces). The calldata evc field must equal the pinned EVC and both
///      vaults must be factory-deployed proxies — arbitrary contracts masquerading as vaults are
///      rejected before any provider call, mirroring the Morpho hooks' pinned-singleton precedent.
///      SECURITY INVARIANT: the executing account is the only debt owner, collateral-share owner,
///      receiver and onBehalfOf identity; no subaccount/operator/alternate-owner calldata exists.
///      Controller disabling always goes through the vault's own disableController() — never a
///      direct EVC call.
///      Post-execution release verification is STATE-DERIVED (reads debtOf/isControllerEnabled/
///      isCollateralEnabled at postExecute time) rather than trusting transient predictions, so it
///      cannot be poisoned by an interleaved execution (ERC-777-style callbacks) and fails closed.
abstract contract BaseEulerLoanHook is BaseLoanHookV2 {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant COLLATERAL_VAULT_OFFSET = 32;
    // debtAsset (loanToken) @52 and collateralAsset @72 are read via inherited BaseLoanHook getters
    uint256 internal constant EVC_OFFSET = 92;
    uint256 internal constant CONTROLLER_VAULT_OFFSET = 112;
    // AMOUNT_POSITION = 132 (primary) inherited from BaseLoanHook
    uint256 internal constant SECONDARY_AMOUNT_OFFSET = 164;
    // USE_PREV_HOOK_AMOUNT_POSITION = 196 inherited from BaseLoanHook

    /// @notice Exact hook-data length for every Euler loan hook
    uint256 internal constant EULER_DATA_LENGTH = 197;

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The canonical EVC singleton for this chain, pinned at deploy
    address public immutable EVC_ADDRESS;

    /// @notice The canonical EVK GenericFactory (eVaultFactory) for this chain, pinned at deploy
    /// @dev Every configured vault must be one of its proxies (isProxy)
    address public immutable EVAULT_FACTORY;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct EulerVars {
        address collateralVault;
        address debtAsset;
        address collateralAsset;
        address evc;
        address controllerVault;
        uint256 primary;
        uint256 secondary;
        bool usePrevHookAmount;
    }

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when an enabled controller exists and differs from the configured one
    error CONTROLLER_MISMATCH();

    /// @notice Thrown when LTVBorrow or LTVLiquidation is zero for the configured collateral vault
    error LTV_NOT_SET();

    /// @notice Thrown when the controller vault's available cash is below the borrow amount
    error INSUFFICIENT_CASH();

    /// @notice Thrown when the collateral vault's deposit cap (or paused state) rejects the amount
    error DEPOSIT_CAP_EXCEEDED();

    /// @notice Thrown when the calldata evc field differs from the pinned canonical EVC
    error EVC_NOT_CANONICAL();

    /// @notice Thrown when a configured vault is not a proxy of the pinned EVK factory
    error UNTRUSTED_VAULT();

    /// @notice Thrown when a vault reports a different EVC than the configured one
    error VAULT_EVC_MISMATCH();

    /// @notice Thrown when a vault's underlying asset differs from the configured token
    error VAULT_ASSET_MISMATCH();

    /// @notice Thrown when the collateral vault equals the controller vault
    error IDENTICAL_VAULTS();

    /// @notice Thrown when a close would strip the full collateral while residual debt remains
    /// @dev Such a withdrawal can never pass EVK's end-of-call health check; failing fast at
    ///      resolution time replaces an opaque provider revert with a precise error
    error RESIDUAL_DEBT_FULL_WITHDRAW();

    /// @notice Thrown when the controller is still enabled after the account's debt reached zero
    error CONTROLLER_NOT_DISABLED();

    /// @notice Thrown when the collateral is still enabled after the account's debt reached zero
    error COLLATERAL_NOT_DISABLED();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Pins the canonical per-chain Euler singletons; vaults remain calldata but must be
    ///         factory-verified
    /// @param evc_ The canonical EVC singleton for this chain
    /// @param eVaultFactory_ The canonical EVK GenericFactory for this chain
    /// @param hookSubtype_ Hook subtype identifier (LOAN or LOAN_REPAY)
    constructor(address evc_, address eVaultFactory_, bytes32 hookSubtype_) BaseLoanHookV2(hookSubtype_) {
        if (evc_ == address(0) || eVaultFactory_ == address(0)) revert ADDRESS_NOT_VALID();
        EVC_ADDRESS = evc_;
        EVAULT_FACTORY = eVaultFactory_;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseLoanHook
    /// @dev Same offset (196) as the inherited implementation, but with the exact-length guard and
    ///      a strict canonical-boolean read so this view never disagrees with execution-time
    ///      decoding on malformed data (custom error instead of an out-of-bounds panic)
    function decodeUsePrevHookAmount(bytes memory data) external pure override returns (bool) {
        if (data.length != EULER_DATA_LENGTH) revert INVALID_DATA_LENGTH();
        return _decodeStrictBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Strictly decodes the canonical Euler layout.
    ///      Enforces: exact 197-byte length, canonical usePrevHookAmount boolean, nonzero
    ///      debtAsset/evc/controllerVault. For composites (`repayOnly == false`): nonzero
    ///      collateralVault/collateralAsset, distinct vaults, distinct assets. For the standalone
    ///      repay (`repayOnly == true`): collateralVault, collateralAsset and the secondary word
    ///      are reserved and must be zero. configId is carried but never validated.
    /// @param data The hook data
    /// @param repayOnly True for the standalone repay hook
    /// @return vars The decoded hook parameters
    function _decodeEuler(bytes memory data, bool repayOnly) internal pure returns (EulerVars memory vars) {
        if (data.length != EULER_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        vars.collateralVault = BytesLib.toAddress(data, COLLATERAL_VAULT_OFFSET);
        vars.debtAsset = getLoanTokenAddress(data);
        vars.collateralAsset = getCollateralTokenAddress(data);
        vars.evc = BytesLib.toAddress(data, EVC_OFFSET);
        vars.controllerVault = BytesLib.toAddress(data, CONTROLLER_VAULT_OFFSET);
        vars.primary = _decodeAmount(data);
        vars.secondary = BytesLib.toUint256(data, SECONDARY_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeStrictBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (vars.debtAsset == address(0) || vars.evc == address(0) || vars.controllerVault == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

        if (repayOnly) {
            if (vars.collateralVault != address(0) || vars.collateralAsset != address(0)) {
                revert RESERVED_FIELD_NOT_ZERO();
            }
            if (vars.secondary != 0) revert RESERVED_FIELD_NOT_ZERO();
        } else {
            if (vars.collateralVault == address(0) || vars.collateralAsset == address(0)) {
                revert ADDRESS_NOT_VALID();
            }
            if (vars.collateralVault == vars.controllerVault) revert IDENTICAL_VAULTS();
            if (vars.debtAsset == vars.collateralAsset) revert IDENTICAL_TOKENS();
        }
    }

    /// @dev External-contract truth checks, all before any provider call is emitted:
    ///      the calldata evc must equal the pinned canonical EVC, the controller vault (and for
    ///      composites the collateral vault) must be a pinned-factory proxy and must report the
    ///      configured EVC and underlying asset
    /// @param vars The decoded hook parameters
    /// @param repayOnly True for the standalone repay hook (no collateral vault to validate)
    function _validateBindings(EulerVars memory vars, bool repayOnly) internal view {
        if (vars.evc != EVC_ADDRESS) revert EVC_NOT_CANONICAL();
        _validateVault(vars.controllerVault, vars.debtAsset);
        if (!repayOnly) {
            _validateVault(vars.collateralVault, vars.collateralAsset);
        }
    }

    /// @dev A configured vault must be a genuine EVK vault (pinned-factory proxy) reporting the
    ///      pinned EVC and the configured underlying asset
    /// @param vault The vault to validate
    /// @param expectedAsset The underlying asset the vault must report
    function _validateVault(address vault, address expectedAsset) internal view {
        if (!IGenericFactory(EVAULT_FACTORY).isProxy(vault)) revert UNTRUSTED_VAULT();
        if (IEVault(vault).EVC() != EVC_ADDRESS) revert VAULT_EVC_MISMATCH();
        if (IEVault(vault).asset() != expectedAsset) revert VAULT_ASSET_MISMATCH();
    }

    /// @dev Open-only: an enabled controller different from the configured one would make the
    ///      enableController call itself revert on-chain (at most one controller may persist), so
    ///      reject it before any provider call
    /// @param vars The decoded hook parameters
    /// @param account The executing smart account
    function _validateControllerState(EulerVars memory vars, address account) internal view {
        address[] memory controllers = IEVC(vars.evc).getControllers(account);
        if (controllers.length > 1) revert CONTROLLER_MISMATCH();
        if (controllers.length == 1 && controllers[0] != vars.controllerVault) revert CONTROLLER_MISMATCH();
    }

    /// @dev Open-only market checks: borrow/liquidation LTVs configured for the collateral,
    ///      deposit cap (or paused state) admits the primary, controller cash covers the borrow
    /// @param vars The decoded hook parameters
    /// @param account The executing smart account
    function _validateOpenMarket(EulerVars memory vars, address account) internal view {
        if (
            IEVault(vars.controllerVault).LTVBorrow(vars.collateralVault) == 0
                || IEVault(vars.controllerVault).LTVLiquidation(vars.collateralVault) == 0
        ) {
            revert LTV_NOT_SET();
        }
        if (IEVault(vars.collateralVault).maxDeposit(account) < vars.primary) revert DEPOSIT_CAP_EXCEEDED();
        if (IEVault(vars.controllerVault).cash() < vars.secondary) revert INSUFFICIENT_CASH();
    }

    /// @dev Resolves the repayment as min(cap, current debt). A zero outstanding debt resolves to
    ///      (0, true) — nothing to repay, position already clear — instead of reverting, so a
    ///      third party gifting a full repayment cannot cancel a signed intent (the repay leg is
    ///      simply skipped). The cap may be type(uint256).max — the min() makes it naturally mean
    ///      "repay everything"; there is no separate full-repayment sentinel. With PREV, the
    ///      previous hook's output token must be the debt asset and its amount becomes the cap.
    /// @param prevHook The previous hook in the chain
    /// @param account The executing smart account
    /// @param vars The decoded hook parameters
    /// @return actualRepay The exact debt-asset amount the repay call will pull (0 = leg skipped)
    /// @return predictedClear True when no debt will remain after this hook's repay leg
    function _resolveRepayCap(
        address prevHook,
        address account,
        EulerVars memory vars
    )
        internal
        view
        returns (uint256 actualRepay, bool predictedClear)
    {
        uint256 debt = IEVault(vars.controllerVault).debtOf(account);
        if (debt == 0) return (0, true);

        uint256 cap = vars.usePrevHookAmount ? _resolvePrevHookOutput(prevHook, account, vars.debtAsset) : vars.primary;
        if (cap == 0) revert AMOUNT_NOT_VALID();

        actualRepay = cap < debt ? cap : debt;
        predictedClear = actualRepay == debt;
    }

    /// @dev Loan-token-only snapshot for the standalone repay hook, whose layout reserves the
    ///      collateral field as zero (BaseLoanHookV2._snapshotBalances would call balanceOf on
    ///      address(0)). _settleRepay only reads preLoanTokenBalance, so the collateral snapshot
    ///      slot is intentionally left untouched.
    /// @param account The executing smart account
    /// @param data The hook data
    function _snapshotLoanBalance(address account, bytes memory data) internal {
        preLoanTokenBalance = getLoanTokenBalance(account, data);
    }

    /// @dev State-derived post-execution release verification: whenever the account's debt on the
    ///      controller vault reads zero, the controller must no longer be enabled; when
    ///      `checkCollateral` is true (composite close), the configured collateral must not remain
    ///      enabled either. Reads live chain state instead of a transient prediction, so an
    ///      interleaved execution (ERC-777-style callback) cannot poison it into skipping — the
    ///      check fails closed.
    /// @param vars The decoded hook parameters
    /// @param account The executing smart account
    /// @param checkCollateral True to additionally require the collateral to be disabled
    function _verifyReleaseState(EulerVars memory vars, address account, bool checkCollateral) internal view {
        if (IEVault(vars.controllerVault).debtOf(account) != 0) return;
        if (IEVC(vars.evc).isControllerEnabled(account, vars.controllerVault)) revert CONTROLLER_NOT_DISABLED();
        if (checkCollateral && IEVC(vars.evc).isCollateralEnabled(account, vars.collateralVault)) {
            revert COLLATERAL_NOT_DISABLED();
        }
    }

    /// @dev Composite market-identity inspector payload: EVC, controller vault, collateral vault,
    ///      debt asset and collateral asset. configId, amount fields and usePrevHookAmount are
    ///      intentionally excluded.
    /// @param vars The decoded hook parameters
    /// @return The packed inspector payload
    function _inspectComposite(EulerVars memory vars) internal pure returns (bytes memory) {
        return
            abi.encodePacked(vars.evc, vars.controllerVault, vars.collateralVault, vars.debtAsset, vars.collateralAsset);
    }

    /// @dev Standalone-repay inspector payload: EVC, controller vault and debt asset only.
    ///      Collateral/release configuration is intentionally excluded so repayment stays
    ///      operable and identically inspectable when only that configuration changes.
    /// @param vars The decoded hook parameters
    /// @return The packed inspector payload
    function _inspectRepay(EulerVars memory vars) internal pure returns (bytes memory) {
        return abi.encodePacked(vars.evc, vars.controllerVault, vars.debtAsset);
    }
}
