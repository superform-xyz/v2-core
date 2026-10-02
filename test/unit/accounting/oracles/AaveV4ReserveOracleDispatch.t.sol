// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

import { AaveV4ReserveRegistryV2 } from "../../../../src/accounting/oracles/AaveV4ReserveRegistryV2.sol";
import { AaveV4ReserveOracle } from "../../../../src/accounting/oracles/AaveV4ReserveOracle.sol";
import { IAaveV4Spoke } from "../../../../src/vendor/aave-v4/IAaveV4Spoke.sol";
import { SuperLedgerConfiguration } from "../../../../src/accounting/SuperLedgerConfiguration.sol";
import { ISuperLedgerConfiguration } from "../../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { AaveV4ReserveKey } from "../../../../src/libraries/AaveV4ReserveKey.sol";

/*//////////////////////////////////////////////////////////////
                              MOCKS
//////////////////////////////////////////////////////////////*/

/// @dev Ledger mock whose previewFees treats the ENTIRE amount as profit (zero cost basis) — models
///      the misconfiguration hazard the oracle's `getAssetOutputWithFees` override exists to defuse:
///      neither leg ever snapshots a cost basis here, so nothing offsets the "profit".
contract MockZeroCostBasisLedger {
    function previewFees(
        address,
        address,
        uint256 amountAssets,
        uint256,
        uint256 feePercent,
        uint256,
        uint256
    )
        external
        pure
        returns (uint256)
    {
        return amountAssets * feePercent / 10_000;
    }
}

/// @dev Minimal Aave V4 spoke mock with independently settable SUPPLY and DEBT state at both the
///      per-user and reserve-aggregate level. Keeping the two legs in separate mappings is what makes
///      cross-leg leakage observable: a dispatch bug reads the wrong mapping and the figures differ.
///      `getReserve` reverts for unlisted ids, matching the real spoke.
contract MockAaveV4Spoke {
    error ReserveNotListed();

    mapping(uint256 => IAaveV4Spoke.Reserve) internal reserves;
    mapping(uint256 => bool) internal listed;
    mapping(uint256 => mapping(address => uint256)) internal drawnDebt;
    mapping(uint256 => mapping(address => uint256)) internal premiumDebt;
    mapping(uint256 => mapping(address => uint256)) internal suppliedAssets;
    mapping(uint256 => uint256) internal reserveDrawnDebt;
    mapping(uint256 => uint256) internal reservePremiumDebt;
    mapping(uint256 => uint256) internal reserveSuppliedAssets;

    function setReserve(uint256 reserveId, address underlying, uint8 decimals_) external {
        reserves[reserveId] = IAaveV4Spoke.Reserve({
            underlying: underlying,
            hub: address(this),
            assetId: uint16(reserveId),
            decimals: decimals_,
            collateralRisk: 0,
            flags: 0,
            dynamicConfigKey: 0
        });
        listed[reserveId] = true;
    }

    function setReserveFlags(uint256 reserveId, uint8 flags) external {
        reserves[reserveId].flags = flags;
    }

    function setUserDebt(uint256 reserveId, address user, uint256 drawn, uint256 premium) external {
        drawnDebt[reserveId][user] = drawn;
        premiumDebt[reserveId][user] = premium;
    }

    function setUserSuppliedAssets(uint256 reserveId, address user, uint256 amount) external {
        suppliedAssets[reserveId][user] = amount;
    }

    function setReserveDebt(uint256 reserveId, uint256 drawn, uint256 premium) external {
        reserveDrawnDebt[reserveId] = drawn;
        reservePremiumDebt[reserveId] = premium;
    }

    function setReserveSuppliedAssets(uint256 reserveId, uint256 amount) external {
        reserveSuppliedAssets[reserveId] = amount;
    }

    function getReserve(uint256 reserveId) external view returns (IAaveV4Spoke.Reserve memory) {
        if (!listed[reserveId]) revert ReserveNotListed();
        return reserves[reserveId];
    }

    function getUserDebt(uint256 reserveId, address user) external view returns (uint256, uint256) {
        return (drawnDebt[reserveId][user], premiumDebt[reserveId][user]);
    }

    function getUserSuppliedAssets(uint256 reserveId, address user) external view returns (uint256) {
        return suppliedAssets[reserveId][user];
    }

    function getReserveDebt(uint256 reserveId) external view returns (uint256, uint256) {
        return (reserveDrawnDebt[reserveId], reservePremiumDebt[reserveId]);
    }

    function getReserveSuppliedAssets(uint256 reserveId) external view returns (uint256) {
        return reserveSuppliedAssets[reserveId];
    }
}

/// @title AaveV4ReserveOracleDispatchTest
/// @notice Exhaustive coverage of the SIDE DISPATCH in `AaveV4ReserveOracle`: one oracle address
///         serves both legs of a reserve and the leg is bound into the key, so `getBalanceOfOwner`
///         and `getTVL` must branch on the registry-stored `Side` while `decimals`,
///         `getPricePerShare`, the identity converters and the fee bypass must NOT.
/// @dev Exposes the `internal` key library so the registry's public derivations can be pinned against it
contract AaveV4ReserveKeyLibHarness {
    function supplyKey(address spoke, uint256 id) external pure returns (address) {
        return AaveV4ReserveKey.computeReserveKey(spoke, id);
    }

    function debtKey(address spoke, uint256 id) external pure returns (address) {
        return AaveV4ReserveKey.computeDebtKey(spoke, id);
    }

    function domain() external pure returns (bytes32) {
        return AaveV4ReserveKey.DEBT_KEY_DOMAIN;
    }
}

/// @dev A registry stand-in that reports a Side OUTSIDE the declared enum, which the real registry cannot
///      produce. The only way to make the oracle's exhaustiveness guard falsifiable: `Side.SUPPLY` is the
///      zero value, so a fall-through would silently report supplied assets for an unset or future third
///      side. Returns the 5-tuple by hand with the side word forced to 2.
contract MockOutOfRangeSideRegistry {
    address public immutable SPOKE;

    constructor(address spoke_) {
        SPOKE = spoke_;
    }

    function getReserveInfo(address) external view returns (address, uint256, address, uint8, uint8) {
        return (SPOKE, 7, address(0xBEEF), 6, 2);
    }
}

contract AaveV4ReserveOracleDispatchTest is Test {
    AaveV4ReserveRegistryV2 public registry;
    AaveV4ReserveOracle public oracle;
    MockAaveV4Spoke public spoke;
    address public ledgerConfig;

    address public usdc = makeAddr("usdc");
    address public weth = makeAddr("weth");
    address public account1 = makeAddr("account1");
    address public account2 = makeAddr("account2");
    address public unknownKey = makeAddr("unknownKey");

    uint256 public constant USDC_RESERVE_ID = 7;
    uint256 public constant WETH_RESERVE_ID = 12;

    /// @dev SUPPLY keys — legacy two-word derivation
    address public usdcKey;
    address public wethKey;

    /// @dev DEBT keys — `DEBT_KEY_DOMAIN`-separated three-word derivation
    address public usdcDebtKey;
    address public wethDebtKey;

    /// @dev Reserve flag bits. Exact positions are irrelevant to these tests — the point is that the
    ///      oracle never reads `flags` at all, so any value must leave every read live.
    uint8 internal constant FLAG_PAUSED = 1 << 1;
    uint8 internal constant FLAG_FROZEN = 1 << 2;

    function setUp() public {
        // Avoid timestamp underflow in the registry's timelock math on the default block.timestamp
        vm.warp(365 days * 2);

        ledgerConfig = address(new SuperLedgerConfiguration());
        registry = new AaveV4ReserveRegistryV2(address(this));
        oracle = new AaveV4ReserveOracle(ledgerConfig, address(registry));

        spoke = new MockAaveV4Spoke();
        spoke.setReserve(USDC_RESERVE_ID, usdc, 6);
        spoke.setReserve(WETH_RESERVE_ID, weth, 18);

        (usdcKey, usdcDebtKey) = registry.registerReserve(address(spoke), USDC_RESERVE_ID);
        (wethKey, wethDebtKey) = registry.registerReserve(address(spoke), WETH_RESERVE_ID);

        // BOTH legs of BOTH reserves carry non-zero, mutually distinct figures so that any dispatch
        // mistake produces an observably wrong number rather than an accidental match.
        spoke.setUserSuppliedAssets(USDC_RESERVE_ID, account1, 1000e6);
        spoke.setUserDebt(USDC_RESERVE_ID, account1, 400e6, 25e6);
        spoke.setReserveSuppliedAssets(USDC_RESERVE_ID, 5_000_000e6);
        spoke.setReserveDebt(USDC_RESERVE_ID, 900_000e6, 100_000e6);

        spoke.setUserSuppliedAssets(WETH_RESERVE_ID, account1, 3 ether);
        spoke.setUserDebt(WETH_RESERVE_ID, account1, 2 ether, 1 wei);
        spoke.setReserveSuppliedAssets(WETH_RESERVE_ID, 50_000 ether);
        spoke.setReserveDebt(WETH_RESERVE_ID, 11_000 ether, 7 ether);
    }

    /*//////////////////////////////////////////////////////////////
                               HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Registers a SuperLedgerConfiguration entry the same way the existing Aave V4 oracle suite
    ///      does, and returns the derived yieldSourceOracleId.
    function _registerConfig(
        bytes32 salt,
        address oracle_,
        uint256 feePercent,
        address ledger
    )
        internal
        returns (bytes32)
    {
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle_, feePercent: feePercent, feeRecipient: makeAddr("feeRecipient"), ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = salt;
        SuperLedgerConfiguration(ledgerConfig).setYieldSourceOracles(salts, configs);
        return keccak256(abi.encodePacked(salt, address(this)));
    }

    /// @dev Lists and registers a fresh reserve with the requested underlying decimals.
    function _registerWithDecimals(
        uint256 reserveId,
        uint8 decimals_
    )
        internal
        returns (address supplyKey, address debtKey)
    {
        spoke.setReserve(reserveId, makeAddr(string(abi.encodePacked("underlying", vm.toString(reserveId)))), decimals_);
        (supplyKey, debtKey) = registry.registerReserve(address(spoke), reserveId);
    }

    /// @dev Runs the full 2-day deregistration lifecycle for a single key.
    function _deregister(address reserveKey) internal {
        registry.proposeDeregisterReserve(reserveKey);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        registry.executeDeregisterReserve(reserveKey);
    }

    function _singleOwner(address owner) internal pure returns (address[] memory owners) {
        owners = new address[](1);
        owners[0] = owner;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Both immutables are bound exactly as constructed: the inert ledger configuration kept
    ///         for `AbstractYieldSourceOracle` parity, and the registry that resolves every key.
    function test_constructor_setsImmutables() public view {
        assertEq(oracle.SUPER_LEDGER_CONFIGURATION(), ledgerConfig, "ledger configuration immutable");
        assertEq(address(oracle.REGISTRY()), address(registry), "registry immutable");
    }

    /// @notice A zero registry is rejected: without it no key could ever resolve a side.
    function test_constructor_revertIf_zeroRegistry() public {
        vm.expectRevert(AaveV4ReserveOracle.ZERO_ADDRESS.selector);
        new AaveV4ReserveOracle(ledgerConfig, address(0));
    }

    /// @notice A zero ledger configuration is rejected even though it is inert here — constructor
    ///         parity with every other oracle is enforced, not merely documented.
    function test_constructor_revertIf_zeroLedgerConfig() public {
        vm.expectRevert(AaveV4ReserveOracle.ZERO_ADDRESS.selector);
        new AaveV4ReserveOracle(address(0), address(registry));
    }

    /// @notice Both arguments zero still reverts with the same error (no ordering dependency).
    function test_constructor_revertIf_bothZero() public {
        vm.expectRevert(AaveV4ReserveOracle.ZERO_ADDRESS.selector);
        new AaveV4ReserveOracle(address(0), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                    DISPATCH: getBalanceOfOwner BOTH LEGS
    //////////////////////////////////////////////////////////////*/

    /// @notice THE CORE INVARIANT. One reserve, one oracle, two keys: the supply key returns exactly
    ///         `getUserSuppliedAssets` and the debt key returns exactly drawn + premium. With both
    ///         legs holding different non-zero figures, neither can leak into the other.
    function test_dispatch_balanceOfOwner_bothLegs_noCrossLeak() public view {
        assertEq(oracle.getBalanceOfOwner(usdcKey, account1), 1000e6, "supply key must return supplied assets");
        assertEq(oracle.getBalanceOfOwner(usdcDebtKey, account1), 425e6, "debt key must return drawn + premium");

        assertEq(oracle.getBalanceOfOwner(wethKey, account1), 3 ether, "weth supply key");
        assertEq(oracle.getBalanceOfOwner(wethDebtKey, account1), 2 ether + 1 wei, "weth debt key");
    }

    /// @notice Cross-reserve isolation on top of cross-leg isolation: four live keys, four distinct
    ///         figures, no pair of them equal — so no permutation of (reserve, side) can alias.
    function test_dispatch_balanceOfOwner_fourKeys_allDistinct() public view {
        uint256 a = oracle.getBalanceOfOwner(usdcKey, account1);
        uint256 b = oracle.getBalanceOfOwner(usdcDebtKey, account1);
        uint256 c = oracle.getBalanceOfOwner(wethKey, account1);
        uint256 d = oracle.getBalanceOfOwner(wethDebtKey, account1);

        assertTrue(a != b, "usdc supply must not alias usdc debt");
        assertTrue(a != c && a != d, "usdc supply must not alias either weth leg");
        assertTrue(b != c && b != d, "usdc debt must not alias either weth leg");
        assertTrue(c != d, "weth supply must not alias weth debt");
    }

    /// @notice Dispatch is per-owner as well as per-side: an owner with no position on either leg
    ///         reads zero on both, and does not pick up the other owner's figures.
    function test_dispatch_balanceOfOwner_unrelatedOwner_readsZeroOnBothLegs() public view {
        assertEq(oracle.getBalanceOfOwner(usdcKey, account2), 0, "unrelated owner supply leg");
        assertEq(oracle.getBalanceOfOwner(usdcDebtKey, account2), 0, "unrelated owner debt leg");
    }

    /// @notice A debt leg with a zero drawn component still reports the premium, and vice versa:
    ///         the debt read is a SUM, not either component alone.
    function test_dispatch_balanceOfOwner_debtLeg_sumsBothComponents() public {
        spoke.setUserDebt(USDC_RESERVE_ID, account2, 0, 77e6);
        assertEq(oracle.getBalanceOfOwner(usdcDebtKey, account2), 77e6, "premium-only debt must be reported");

        spoke.setUserDebt(USDC_RESERVE_ID, account2, 123e6, 0);
        assertEq(oracle.getBalanceOfOwner(usdcDebtKey, account2), 123e6, "drawn-only debt must be reported");

        spoke.setUserDebt(USDC_RESERVE_ID, account2, 123e6, 77e6);
        assertEq(oracle.getBalanceOfOwner(usdcDebtKey, account2), 200e6, "drawn + premium must be summed");
    }

    /// @notice Fuzzed dispatch: for any (supplied, drawn, premium) the supply key returns exactly
    ///         `supplied` and the debt key exactly `drawn + premium` — zeros and maxima included.
    ///         The sum is widened to uint256 so it can never truncate.
    function test_fuzz_dispatch_balanceOfOwner_bothLegs(uint128 supplied, uint128 drawn, uint128 premium) public {
        spoke.setUserSuppliedAssets(USDC_RESERVE_ID, account2, supplied);
        spoke.setUserDebt(USDC_RESERVE_ID, account2, drawn, premium);

        uint256 expectedDebt = uint256(drawn) + uint256(premium);

        assertEq(oracle.getBalanceOfOwner(usdcKey, account2), uint256(supplied), "supply key == supplied");
        assertEq(oracle.getBalanceOfOwner(usdcDebtKey, account2), expectedDebt, "debt key == drawn + premium");
        assertGe(oracle.getBalanceOfOwner(usdcDebtKey, account2), uint256(drawn), "debt sum must not truncate (drawn)");
        assertGe(
            oracle.getBalanceOfOwner(usdcDebtKey, account2), uint256(premium), "debt sum must not truncate (premium)"
        );
    }

    /// @notice uint128 maxima on both debt components: the widened sum exceeds uint128 and is still
    ///         reported exactly, proving no intermediate narrowing.
    function test_dispatch_balanceOfOwner_debtLeg_uint128MaximaDoNotTruncate() public {
        uint256 maxU128 = uint256(type(uint128).max);
        spoke.setUserDebt(USDC_RESERVE_ID, account2, type(uint128).max, type(uint128).max);

        uint256 got = oracle.getBalanceOfOwner(usdcDebtKey, account2);
        assertEq(got, maxU128 * 2, "max + max must be reported as the full uint256 sum");
        assertGt(got, maxU128, "the sum must exceed uint128 range");
    }

    /*//////////////////////////////////////////////////////////////
                        DISPATCH: getTVL BOTH LEGS
    //////////////////////////////////////////////////////////////*/

    /// @notice Reserve-level dispatch: the supply key returns total supplied assets while the debt
    ///         key returns the aggregate outstanding debt (the `totalBorrows()` analog) — never
    ///         total supplied assets for a debt key.
    function test_dispatch_getTVL_bothLegs_noCrossLeak() public view {
        assertEq(oracle.getTVL(usdcKey), 5_000_000e6, "supply key TVL == reserve supplied assets");
        assertEq(oracle.getTVL(usdcDebtKey), 1_000_000e6, "debt key TVL == reserve drawn + premium");

        assertEq(oracle.getTVL(wethKey), 50_000 ether, "weth supply key TVL");
        assertEq(oracle.getTVL(wethDebtKey), 11_007 ether, "weth debt key TVL");
    }

    /// @notice Fuzzed reserve-level dispatch, same invariant as the per-owner case.
    function test_fuzz_dispatch_getTVL_bothLegs(uint128 supplied, uint128 drawn, uint128 premium) public {
        spoke.setReserveSuppliedAssets(WETH_RESERVE_ID, supplied);
        spoke.setReserveDebt(WETH_RESERVE_ID, drawn, premium);

        uint256 expectedDebt = uint256(drawn) + uint256(premium);

        assertEq(oracle.getTVL(wethKey), uint256(supplied), "supply key TVL == reserve supplied");
        assertEq(oracle.getTVL(wethDebtKey), expectedDebt, "debt key TVL == reserve drawn + premium");
        assertGe(oracle.getTVL(wethDebtKey), uint256(drawn), "reserve debt sum must not truncate (drawn)");
        assertGe(oracle.getTVL(wethDebtKey), uint256(premium), "reserve debt sum must not truncate (premium)");
    }

    /// @notice An empty supply side with a live debt side (and the mirror case) still dispatches
    ///         correctly — a zero on one leg must not be read as "fall through to the other leg".
    function test_dispatch_getTVL_oneLegZero_doesNotFallThrough() public {
        spoke.setReserveSuppliedAssets(USDC_RESERVE_ID, 0);
        assertEq(oracle.getTVL(usdcKey), 0, "zero supply TVL must stay zero");
        assertEq(oracle.getTVL(usdcDebtKey), 1_000_000e6, "debt TVL unaffected by zero supply");

        spoke.setReserveSuppliedAssets(USDC_RESERVE_ID, 5_000_000e6);
        spoke.setReserveDebt(USDC_RESERVE_ID, 0, 0);
        assertEq(oracle.getTVL(usdcDebtKey), 0, "zero debt TVL must stay zero");
        assertEq(oracle.getTVL(usdcKey), 5_000_000e6, "supply TVL unaffected by zero debt");
    }

    /*//////////////////////////////////////////////////////////////
                           SIDE INDEPENDENCE
    //////////////////////////////////////////////////////////////*/

    /// @notice `decimals` is a property of the reserve's single underlying asset, so both legs of one
    ///         reserve must report the same value — checked across several decimals settings.
    function test_sideIndependence_decimals_acrossSeveralValues() public {
        uint8[5] memory values = [uint8(0), 2, 6, 18, 27];

        for (uint256 i; i < values.length; ++i) {
            (address supplyKey, address debtKey) = _registerWithDecimals(100 + i, values[i]);
            assertEq(oracle.decimals(supplyKey), values[i], "supply leg decimals");
            assertEq(oracle.decimals(debtKey), values[i], "debt leg decimals");
            assertEq(oracle.decimals(supplyKey), oracle.decimals(debtKey), "both legs share one decimals");
        }
    }

    /// @notice `getPricePerShare` is identity (10 ** decimals) and side-independent: both legs of one
    ///         reserve return the identical, never-zero scale.
    function test_sideIndependence_pricePerShare_equalsTenPowDecimals() public {
        uint8[5] memory values = [uint8(0), 2, 6, 18, 27];

        for (uint256 i; i < values.length; ++i) {
            (address supplyKey, address debtKey) = _registerWithDecimals(200 + i, values[i]);
            uint256 expected = 10 ** uint256(values[i]);

            assertEq(oracle.getPricePerShare(supplyKey), expected, "supply leg PPS == 10 ** decimals");
            assertEq(oracle.getPricePerShare(debtKey), expected, "debt leg PPS == 10 ** decimals");
            assertEq(oracle.getPricePerShare(supplyKey), oracle.getPricePerShare(debtKey), "PPS is side-independent");
            assertGt(oracle.getPricePerShare(debtKey), 0, "PPS is never zero");
        }
    }

    /// @notice The setUp reserves confirm the same on the default fixtures: PPS tracks decimals, not
    ///         the magnitude of either leg's balance.
    function test_sideIndependence_pricePerShare_defaultFixtures() public view {
        assertEq(oracle.getPricePerShare(usdcKey), 1e6, "usdc supply PPS");
        assertEq(oracle.getPricePerShare(usdcDebtKey), 1e6, "usdc debt PPS");
        assertEq(oracle.getPricePerShare(wethKey), 1e18, "weth supply PPS");
        assertEq(oracle.getPricePerShare(wethDebtKey), 1e18, "weth debt PPS");
    }

    /*//////////////////////////////////////////////////////////////
                  getTVLByOwnerOfShares == getBalanceOfOwner
    //////////////////////////////////////////////////////////////*/

    /// @notice Identity PPS collapses the two per-owner reads into one: `getTVLByOwnerOfShares` must
    ///         equal `getBalanceOfOwner` on BOTH legs, for any state.
    function test_fuzz_tvlByOwnerOfShares_equalsBalanceOfOwner_bothLegs(
        uint128 supplied,
        uint128 drawn,
        uint128 premium
    )
        public
    {
        spoke.setUserSuppliedAssets(USDC_RESERVE_ID, account2, supplied);
        spoke.setUserDebt(USDC_RESERVE_ID, account2, drawn, premium);

        assertEq(
            oracle.getTVLByOwnerOfShares(usdcKey, account2),
            oracle.getBalanceOfOwner(usdcKey, account2),
            "supply leg: tvlByOwner == balanceOfOwner"
        );
        assertEq(
            oracle.getTVLByOwnerOfShares(usdcDebtKey, account2),
            oracle.getBalanceOfOwner(usdcDebtKey, account2),
            "debt leg: tvlByOwner == balanceOfOwner"
        );
        assertEq(oracle.getTVLByOwnerOfShares(usdcKey, account2), uint256(supplied), "supply leg absolute figure");
        assertEq(
            oracle.getTVLByOwnerOfShares(usdcDebtKey, account2),
            uint256(drawn) + uint256(premium),
            "debt leg absolute figure"
        );
    }

    /*//////////////////////////////////////////////////////////////
                         IDENTITY CONVERTERS
    //////////////////////////////////////////////////////////////*/

    /// @notice The pure converters return the input for ANY key — registered supply, registered debt,
    ///         or completely unregistered. They do NOT consult the registry, which is exactly why they
    ///         must not revert for unknown keys: they cannot be used to probe registration status.
    function test_fuzz_identityConverters_anyKey_returnInputAndNeverRevert(uint256 amount) public view {
        address[3] memory keys = [usdcKey, usdcDebtKey, unknownKey];

        for (uint256 i; i < keys.length; ++i) {
            assertEq(oracle.getShareOutput(keys[i], usdc, amount), amount, "getShareOutput is identity");
            assertEq(
                oracle.getWithdrawalShareOutput(keys[i], usdc, amount), amount, "getWithdrawalShareOutput is identity"
            );
            assertEq(oracle.getAssetOutput(keys[i], usdc, amount), amount, "getAssetOutput is identity");
        }
    }

    /// @notice Identity holds at the numeric extremes and for the zero address as the key, further
    ///         pinning that no registry lookup happens on these paths.
    function test_identityConverters_extremes_andZeroKey() public view {
        uint256 max = type(uint256).max;

        assertEq(oracle.getShareOutput(address(0), address(0), 0), 0, "zero key, zero amount");
        assertEq(oracle.getWithdrawalShareOutput(address(0), address(0), max), max, "zero key, max amount");
        assertEq(oracle.getAssetOutput(address(0), address(0), max), max, "getAssetOutput at max");
        assertEq(oracle.getAssetOutput(usdcDebtKey, address(0), max), max, "debt key at max");
    }

    /// @notice A deregistered key still converts: identity is correct independent of registration, so
    ///         deregistration can never brick these views (only the registry-resolving ones).
    function test_identityConverters_survive_deregistration() public {
        _deregister(usdcDebtKey);

        assertEq(oracle.getShareOutput(usdcDebtKey, usdc, 42e6), 42e6, "getShareOutput after deregistration");
        assertEq(
            oracle.getWithdrawalShareOutput(usdcDebtKey, usdc, 42e6),
            42e6,
            "getWithdrawalShareOutput after deregistration"
        );
        assertEq(oracle.getAssetOutput(usdcDebtKey, usdc, 42e6), 42e6, "getAssetOutput after deregistration");
    }

    /*//////////////////////////////////////////////////////////////
                    getAssetOutputWithFees: FEE BYPASS
    //////////////////////////////////////////////////////////////*/

    /// @notice No configuration at all: the override returns identity on both legs. (The inherited
    ///         implementation would also fall through here — this pins the baseline.)
    function test_getAssetOutputWithFees_noConfig_identityOnBothLegs() public view {
        bytes32 fakeId = keccak256("UNREGISTERED_CONFIG_ID");

        assertEq(oracle.getAssetOutputWithFees(fakeId, usdcKey, usdc, account1, 500e6), 500e6, "supply leg, no config");
        assertEq(
            oracle.getAssetOutputWithFees(fakeId, usdcDebtKey, usdc, account1, 500e6), 500e6, "debt leg, no config"
        );
    }

    /// @notice A real configuration with feePercent == 0 returns identity on both legs.
    function test_getAssetOutputWithFees_zeroFeeConfig_identityOnBothLegs() public {
        address mockLedger = address(new MockZeroCostBasisLedger());
        bytes32 id = _registerConfig(keccak256("AAVE_V4_DISPATCH_ZERO_FEE"), address(oracle), 0, mockLedger);

        assertEq(oracle.getAssetOutputWithFees(id, usdcKey, usdc, account1, 500e6), 500e6, "supply leg, zero fee");
        assertEq(oracle.getAssetOutputWithFees(id, usdcDebtKey, usdc, account1, 500e6), 500e6, "debt leg, zero fee");
    }

    /// @notice THE MISCONFIGURATION CASE. feePercent = 10% plus a zero-cost-basis ledger: the
    ///         inherited implementation would have inflated 500 to 550 on both legs. The override
    ///         bypasses fee math entirely, so the quote is never fee-adjusted on either leg.
    function test_getAssetOutputWithFees_feeConfigWithZeroCostBasisLedger_identityOnBothLegs() public {
        address mockLedger = address(new MockZeroCostBasisLedger());
        bytes32 id = _registerConfig(keccak256("AAVE_V4_DISPATCH_FEE_MISCONFIG"), address(oracle), 1000, mockLedger);

        uint256 amount = 500e6;
        assertEq(
            oracle.getAssetOutputWithFees(id, usdcKey, usdc, account1, amount),
            amount,
            "supply leg must bypass fee math despite feePercent > 0"
        );
        assertEq(
            oracle.getAssetOutputWithFees(id, usdcDebtKey, usdc, account1, amount),
            amount,
            "debt leg must bypass fee math despite feePercent > 0"
        );
    }

    /// @notice Fuzzed bypass over amount and all three config shapes: the quote equals
    ///         `getAssetOutput` exactly — never fee-reduced, never fee-inflated — on both legs.
    function test_fuzz_getAssetOutputWithFees_bypass_bothLegs(uint128 amount) public {
        address mockLedger = address(new MockZeroCostBasisLedger());
        bytes32 feeId = _registerConfig(keccak256("AAVE_V4_DISPATCH_FUZZ_FEE"), address(oracle), 1000, mockLedger);
        bytes32 zeroId = _registerConfig(keccak256("AAVE_V4_DISPATCH_FUZZ_ZERO"), address(oracle), 0, mockLedger);
        bytes32 noneId = keccak256("AAVE_V4_DISPATCH_FUZZ_NONE");

        bytes32[3] memory ids = [feeId, zeroId, noneId];
        address[2] memory keys = [usdcKey, usdcDebtKey];

        for (uint256 i; i < ids.length; ++i) {
            for (uint256 j; j < keys.length; ++j) {
                assertEq(
                    oracle.getAssetOutputWithFees(ids[i], keys[j], usdc, account1, amount),
                    oracle.getAssetOutput(keys[j], usdc, amount),
                    "fee-bypassed quote must equal the identity quote"
                );
                assertEq(
                    oracle.getAssetOutputWithFees(ids[i], keys[j], usdc, account1, amount),
                    uint256(amount),
                    "fee-bypassed quote must equal the input amount"
                );
            }
        }
    }

    /// @notice The bypass does not consult the registry either: it quotes an unregistered key, and a
    ///         deregistered leg, identically.
    function test_getAssetOutputWithFees_bypass_unregisteredAndDeregisteredKeys() public {
        address mockLedger = address(new MockZeroCostBasisLedger());
        bytes32 id = _registerConfig(keccak256("AAVE_V4_DISPATCH_BYPASS_UNREG"), address(oracle), 1000, mockLedger);

        assertEq(oracle.getAssetOutputWithFees(id, unknownKey, usdc, account1, 7e6), 7e6, "unregistered key quote");

        _deregister(usdcDebtKey);
        assertEq(oracle.getAssetOutputWithFees(id, usdcDebtKey, usdc, account1, 7e6), 7e6, "deregistered leg quote");
    }

    /*//////////////////////////////////////////////////////////////
                      UNREGISTERED-KEY REVERT SURFACE
    //////////////////////////////////////////////////////////////*/

    /// @notice Every registry-resolving view reverts with RESERVE_NOT_REGISTERED for an unknown key —
    ///         never a zero return that a consumer could mistake for an empty position.
    function test_unregisteredKey_allRegistryResolvingViews_revert() public {
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.decimals(unknownKey);

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.getPricePerShare(unknownKey);

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.getBalanceOfOwner(unknownKey, account1);

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.getTVLByOwnerOfShares(unknownKey, account1);

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.getTVL(unknownKey);
    }

    /// @notice Deregistering the SUPPLY leg bricks only that leg: every registry-resolving view
    ///         reverts for the supply key while the sibling DEBT key keeps reading correctly.
    function test_deregisteredSupplyLeg_reverts_whileDebtLegSurvives() public {
        _deregister(usdcKey);

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.decimals(usdcKey);

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.getPricePerShare(usdcKey);

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.getBalanceOfOwner(usdcKey, account1);

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.getTVLByOwnerOfShares(usdcKey, account1);

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.getTVL(usdcKey);

        // The surviving sibling leg is untouched
        assertEq(oracle.decimals(usdcDebtKey), 6, "surviving debt leg decimals");
        assertEq(oracle.getPricePerShare(usdcDebtKey), 1e6, "surviving debt leg PPS");
        assertEq(oracle.getBalanceOfOwner(usdcDebtKey, account1), 425e6, "surviving debt leg balance");
        assertEq(oracle.getTVLByOwnerOfShares(usdcDebtKey, account1), 425e6, "surviving debt leg owner TVL");
        assertEq(oracle.getTVL(usdcDebtKey), 1_000_000e6, "surviving debt leg TVL");
    }

    /// @notice The mirror case: deregistering the DEBT leg bricks only the debt key while the SUPPLY
    ///         key keeps reading correctly — the documented per-key deregistration semantics.
    function test_deregisteredDebtLeg_reverts_whileSupplyLegSurvives() public {
        _deregister(usdcDebtKey);

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.decimals(usdcDebtKey);

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.getPricePerShare(usdcDebtKey);

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.getBalanceOfOwner(usdcDebtKey, account1);

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.getTVLByOwnerOfShares(usdcDebtKey, account1);

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.getTVL(usdcDebtKey);

        // The surviving sibling leg is untouched
        assertEq(oracle.decimals(usdcKey), 6, "surviving supply leg decimals");
        assertEq(oracle.getPricePerShare(usdcKey), 1e6, "surviving supply leg PPS");
        assertEq(oracle.getBalanceOfOwner(usdcKey, account1), 1000e6, "surviving supply leg balance");
        assertEq(oracle.getTVLByOwnerOfShares(usdcKey, account1), 1000e6, "surviving supply leg owner TVL");
        assertEq(oracle.getTVL(usdcKey), 5_000_000e6, "surviving supply leg TVL");
    }

    /*//////////////////////////////////////////////////////////////
                   BATCH METHODS: MIXED SUPPLY + DEBT KEYS
    //////////////////////////////////////////////////////////////*/

    /// @notice `getTVLByOwnerOfSharesMultiple` isolates per entry: an array interleaving supply keys,
    ///         debt keys and one unknown key yields the correct per-leg figure with ok=true for every
    ///         real leg, and 0 / ok=false for the unknown entry only.
    function test_batch_tvlByOwnerOfSharesMultiple_mixedKeys_isolatesUnknownEntry() public view {
        address[] memory keys = new address[](5);
        keys[0] = usdcKey;
        keys[1] = usdcDebtKey;
        keys[2] = unknownKey;
        keys[3] = wethDebtKey;
        keys[4] = wethKey;

        address[][] memory owners = new address[][](5);
        for (uint256 i; i < 5; ++i) {
            owners[i] = _singleOwner(account1);
        }

        (uint256[][] memory tvls, bool[][] memory ok) = oracle.getTVLByOwnerOfSharesMultiple(keys, owners);

        assertEq(tvls[0][0], 1000e6, "entry 0: usdc supply leg");
        assertTrue(ok[0][0], "entry 0 succeeded");

        assertEq(tvls[1][0], 425e6, "entry 1: usdc debt leg");
        assertTrue(ok[1][0], "entry 1 succeeded");

        assertEq(tvls[2][0], 0, "entry 2: unknown key returns zero");
        assertFalse(ok[2][0], "entry 2 must be flagged as failed");

        assertEq(tvls[3][0], 2 ether + 1 wei, "entry 3: weth debt leg");
        assertTrue(ok[3][0], "entry 3 succeeded");

        assertEq(tvls[4][0], 3 ether, "entry 4: weth supply leg");
        assertTrue(ok[4][0], "entry 4 succeeded");
    }

    /// @notice Isolation also holds at the inner (owner) level with mixed legs: a deregistered leg in
    ///         the middle of the array fails alone.
    function test_batch_tvlByOwnerOfSharesMultiple_deregisteredLegFailsAlone() public {
        _deregister(usdcDebtKey);

        address[] memory keys = new address[](2);
        keys[0] = usdcDebtKey;
        keys[1] = usdcKey;

        address[][] memory owners = new address[][](2);
        owners[0] = _singleOwner(account1);
        owners[1] = _singleOwner(account1);

        (uint256[][] memory tvls, bool[][] memory ok) = oracle.getTVLByOwnerOfSharesMultiple(keys, owners);

        assertEq(tvls[0][0], 0, "deregistered debt leg returns zero");
        assertFalse(ok[0][0], "deregistered debt leg flagged as failed");
        assertEq(tvls[1][0], 1000e6, "surviving supply leg still correct in the same batch");
        assertTrue(ok[1][0], "surviving supply leg succeeded");
    }

    /// @notice Multiple owners per leg, both legs present: every (leg, owner) cell carries its own
    ///         side-correct figure.
    function test_batch_tvlByOwnerOfSharesMultiple_multipleOwnersPerLeg() public {
        spoke.setUserSuppliedAssets(USDC_RESERVE_ID, account2, 55e6);
        spoke.setUserDebt(USDC_RESERVE_ID, account2, 11e6, 4e6);

        address[] memory keys = new address[](2);
        keys[0] = usdcKey;
        keys[1] = usdcDebtKey;

        address[][] memory owners = new address[][](2);
        owners[0] = new address[](2);
        owners[0][0] = account1;
        owners[0][1] = account2;
        owners[1] = new address[](2);
        owners[1][0] = account1;
        owners[1][1] = account2;

        (uint256[][] memory tvls, bool[][] memory ok) = oracle.getTVLByOwnerOfSharesMultiple(keys, owners);

        assertEq(tvls[0][0], 1000e6, "supply leg, account1");
        assertEq(tvls[0][1], 55e6, "supply leg, account2");
        assertEq(tvls[1][0], 425e6, "debt leg, account1");
        assertEq(tvls[1][1], 15e6, "debt leg, account2");
        assertTrue(ok[0][0] && ok[0][1] && ok[1][0] && ok[1][1], "all four cells succeeded");
    }

    /// @notice `getPricePerShareMultiple` has NO per-entry isolation: with both legs present, a single
    ///         unknown key aborts the whole call (inherited behavior, deliberately pinned).
    function test_batch_pricePerShareMultiple_mixedKeys_abortsOnUnknown() public {
        address[] memory keys = new address[](3);
        keys[0] = usdcKey;
        keys[1] = usdcDebtKey;
        keys[2] = unknownKey;

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.getPricePerShareMultiple(keys);
    }

    /// @notice `getTVLMultiple` has NO per-entry isolation either: one unknown key among both legs
    ///         aborts the whole call.
    function test_batch_tvlMultiple_mixedKeys_abortsOnUnknown() public {
        address[] memory keys = new address[](3);
        keys[0] = usdcKey;
        keys[1] = usdcDebtKey;
        keys[2] = unknownKey;

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.getTVLMultiple(keys);
    }

    /// @notice Without an unknown entry the same mixed array succeeds and returns the side-independent
    ///         PPS for every leg — isolating the abort above to the unknown key, not to leg mixing.
    function test_batch_pricePerShareMultiple_mixedKeys_allLegsSucceed() public view {
        address[] memory keys = new address[](4);
        keys[0] = usdcKey;
        keys[1] = usdcDebtKey;
        keys[2] = wethDebtKey;
        keys[3] = wethKey;

        uint256[] memory pps = oracle.getPricePerShareMultiple(keys);

        assertEq(pps[0], 1e6, "usdc supply PPS");
        assertEq(pps[1], 1e6, "usdc debt PPS");
        assertEq(pps[2], 1e18, "weth debt PPS");
        assertEq(pps[3], 1e18, "weth supply PPS");
    }

    /// @notice A batch of ONLY debt keys returns debt figures for every entry — the dispatch does not
    ///         default to the supply read anywhere in the loop.
    function test_batch_tvlMultiple_onlyDebtKeys_returnsDebtFigures() public view {
        address[] memory keys = new address[](2);
        keys[0] = usdcDebtKey;
        keys[1] = wethDebtKey;

        uint256[] memory tvls = oracle.getTVLMultiple(keys);

        assertEq(tvls[0], 1_000_000e6, "usdc debt TVL, not the 5,000,000e6 supply figure");
        assertEq(tvls[1], 11_007 ether, "weth debt TVL, not the 50,000 ether supply figure");
    }

    /// @notice The same for the mixed batch: supply entries carry supply TVL and debt entries carry
    ///         debt TVL, in array order.
    function test_batch_tvlMultiple_mixedKeys_perEntrySideCorrect() public view {
        address[] memory keys = new address[](4);
        keys[0] = usdcDebtKey;
        keys[1] = usdcKey;
        keys[2] = wethKey;
        keys[3] = wethDebtKey;

        uint256[] memory tvls = oracle.getTVLMultiple(keys);

        assertEq(tvls[0], 1_000_000e6, "entry 0: usdc debt TVL");
        assertEq(tvls[1], 5_000_000e6, "entry 1: usdc supply TVL");
        assertEq(tvls[2], 50_000 ether, "entry 2: weth supply TVL");
        assertEq(tvls[3], 11_007 ether, "entry 3: weth debt TVL");
    }

    /// @notice A batch of ONLY debt keys through the isolating batch method likewise returns debt
    ///         figures for every owner entry.
    function test_batch_tvlByOwnerOfSharesMultiple_onlyDebtKeys_returnsDebtFigures() public view {
        address[] memory keys = new address[](2);
        keys[0] = usdcDebtKey;
        keys[1] = wethDebtKey;

        address[][] memory owners = new address[][](2);
        owners[0] = _singleOwner(account1);
        owners[1] = _singleOwner(account1);

        (uint256[][] memory tvls, bool[][] memory ok) = oracle.getTVLByOwnerOfSharesMultiple(keys, owners);

        assertEq(tvls[0][0], 425e6, "usdc debt balance, not the 1,000e6 supply balance");
        assertEq(tvls[1][0], 2 ether + 1 wei, "weth debt balance, not the 3 ether supply balance");
        assertTrue(ok[0][0] && ok[1][0], "both debt entries succeeded");
    }

    /// @notice Empty batches are well-formed no-ops on all three batch surfaces.
    function test_batch_emptyArrays_returnEmpty() public view {
        address[] memory keys = new address[](0);
        address[][] memory owners = new address[][](0);

        assertEq(oracle.getPricePerShareMultiple(keys).length, 0, "empty PPS batch");
        assertEq(oracle.getTVLMultiple(keys).length, 0, "empty TVL batch");
        (uint256[][] memory tvls,) = oracle.getTVLByOwnerOfSharesMultiple(keys, owners);
        assertEq(tvls.length, 0, "empty owner-TVL batch");
    }

    /*//////////////////////////////////////////////////////////////
                        PPS DECIMALS BOUNDARY
    //////////////////////////////////////////////////////////////*/

    /// @notice decimals = 77 is the largest exponent that fits uint256: 10 ** 77 is returned on BOTH
    ///         legs. Unreachable with real ERC-20s (max 18 in practice) but pinned as the boundary.
    function test_ppsBoundary_decimals77_worksOnBothLegs() public {
        (address supplyKey, address debtKey) = _registerWithDecimals(777, 77);

        assertEq(oracle.decimals(supplyKey), 77, "supply leg decimals 77");
        assertEq(oracle.decimals(debtKey), 77, "debt leg decimals 77");
        assertEq(oracle.getPricePerShare(supplyKey), 10 ** 77, "supply leg PPS at decimals 77");
        assertEq(oracle.getPricePerShare(debtKey), 10 ** 77, "debt leg PPS at decimals 77");
    }

    /// @notice decimals = 78 overflows uint256, so `getPricePerShare` reverts via checked arithmetic
    ///         on BOTH legs — while `decimals` itself still reports the stored value on both.
    function test_ppsBoundary_decimals78_revertsOnBothLegs() public {
        (address supplyKey, address debtKey) = _registerWithDecimals(778, 78);

        assertEq(oracle.decimals(supplyKey), 78, "supply leg still reports decimals 78");
        assertEq(oracle.decimals(debtKey), 78, "debt leg still reports decimals 78");

        vm.expectRevert(stdError.arithmeticError);
        oracle.getPricePerShare(supplyKey);

        vm.expectRevert(stdError.arithmeticError);
        oracle.getPricePerShare(debtKey);
    }

    /// @notice The overflow propagates through the non-isolating PPS batch on both legs.
    function test_ppsBoundary_decimals78_abortsPricePerShareMultiple() public {
        (address supplyKey, address debtKey) = _registerWithDecimals(779, 78);

        address[] memory keys = new address[](2);
        keys[0] = supplyKey;
        keys[1] = debtKey;

        vm.expectRevert(stdError.arithmeticError);
        oracle.getPricePerShareMultiple(keys);
    }

    /// @notice Balance and TVL reads are unaffected by an absurd decimals value on either leg — only
    ///         the PPS scale overflows, the dispatch itself stays live.
    function test_ppsBoundary_decimals78_balanceAndTvlStillRead() public {
        (address supplyKey, address debtKey) = _registerWithDecimals(780, 78);
        spoke.setUserSuppliedAssets(780, account1, 9);
        spoke.setUserDebt(780, account1, 5, 3);
        spoke.setReserveSuppliedAssets(780, 90);
        spoke.setReserveDebt(780, 50, 30);

        assertEq(oracle.getBalanceOfOwner(supplyKey, account1), 9, "supply balance at decimals 78");
        assertEq(oracle.getBalanceOfOwner(debtKey, account1), 8, "debt balance at decimals 78");
        assertEq(oracle.getTVL(supplyKey), 90, "supply TVL at decimals 78");
        assertEq(oracle.getTVL(debtKey), 80, "debt TVL at decimals 78");
    }

    /*//////////////////////////////////////////////////////////////
                    LIVENESS UNDER RESERVE FLAGS
    //////////////////////////////////////////////////////////////*/

    /// @notice The oracle never gates on reserve flags: with paused and frozen both set, every read
    ///         keeps returning the same figures on BOTH legs. Debt accrues while paused or frozen, so
    ///         gating here would silently freeze NAV.
    function test_liveness_pausedAndFrozen_bothLegsKeepReading() public {
        spoke.setReserveFlags(USDC_RESERVE_ID, FLAG_PAUSED | FLAG_FROZEN);

        assertEq(oracle.decimals(usdcKey), 6, "supply leg decimals under flags");
        assertEq(oracle.decimals(usdcDebtKey), 6, "debt leg decimals under flags");
        assertEq(oracle.getPricePerShare(usdcKey), 1e6, "supply leg PPS under flags");
        assertEq(oracle.getPricePerShare(usdcDebtKey), 1e6, "debt leg PPS under flags");
        assertEq(oracle.getBalanceOfOwner(usdcKey, account1), 1000e6, "supply leg balance under flags");
        assertEq(oracle.getBalanceOfOwner(usdcDebtKey, account1), 425e6, "debt leg balance under flags");
        assertEq(oracle.getTVLByOwnerOfShares(usdcKey, account1), 1000e6, "supply leg owner TVL under flags");
        assertEq(oracle.getTVLByOwnerOfShares(usdcDebtKey, account1), 425e6, "debt leg owner TVL under flags");
        assertEq(oracle.getTVL(usdcKey), 5_000_000e6, "supply leg TVL under flags");
        assertEq(oracle.getTVL(usdcDebtKey), 1_000_000e6, "debt leg TVL under flags");
    }

    /// @notice Every flag bit set at once changes nothing either — the flags byte is simply never read.
    function test_liveness_allFlagsSet_bothLegsKeepReading() public {
        spoke.setReserveFlags(USDC_RESERVE_ID, type(uint8).max);
        spoke.setReserveFlags(WETH_RESERVE_ID, type(uint8).max);

        assertEq(oracle.getBalanceOfOwner(usdcDebtKey, account1), 425e6, "usdc debt balance, all flags set");
        assertEq(oracle.getTVL(wethDebtKey), 11_007 ether, "weth debt TVL, all flags set");
        assertEq(oracle.getBalanceOfOwner(wethKey, account1), 3 ether, "weth supply balance, all flags set");
        assertEq(oracle.getTVL(usdcKey), 5_000_000e6, "usdc supply TVL, all flags set");
    }

    /// @notice Debt keeps accruing while flagged: a post-flag debt increase is reported in full on the
    ///         debt leg and leaves the supply leg untouched.
    function test_liveness_debtAccrualUnderFlags_isReported() public {
        spoke.setReserveFlags(USDC_RESERVE_ID, FLAG_PAUSED | FLAG_FROZEN);

        spoke.setUserDebt(USDC_RESERVE_ID, account1, 450e6, 30e6);

        assertEq(oracle.getBalanceOfOwner(usdcDebtKey, account1), 480e6, "accrued debt reported while flagged");
        assertEq(oracle.getBalanceOfOwner(usdcKey, account1), 1000e6, "supply leg unchanged by debt accrual");
    }

    /*//////////////////////////////////////////////////////////////
            SIDE INTROSPECTION + EXHAUSTIVENESS (MIGRATION GUARDS)
    //////////////////////////////////////////////////////////////*/

    /// @notice `sideOf` is the migration guard the contract docs instruct consumers to assert with: the
    ///         sideless IYieldSourceOracle surface cannot distinguish the legs, so this is the only on-chain
    ///         way to verify a carried-over (oracle, key) config pair means the leg it claims.
    function test_sideOf_classifiesBothLegs() public view {
        assertTrue(oracle.sideOf(usdcKey) == AaveV4ReserveRegistryV2.Side.SUPPLY, "legacy key is the SUPPLY leg");
        assertTrue(oracle.sideOf(usdcDebtKey) == AaveV4ReserveRegistryV2.Side.DEBT, "debt key is the DEBT leg");
        assertTrue(oracle.sideOf(wethKey) == AaveV4ReserveRegistryV2.Side.SUPPLY, "second reserve, supply leg");
        assertTrue(oracle.sideOf(wethDebtKey) == AaveV4ReserveRegistryV2.Side.DEBT, "second reserve, debt leg");
    }

    /// @notice `sideOf` reverts rather than guessing for an unregistered key, so it doubles as a registration
    ///         probe and can never silently classify a key the registry does not know
    function test_sideOf_revertIf_unregisteredKey() public {
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.sideOf(makeAddr("ghostKey"));
    }

    /// @notice `sideOf` follows registry state: once a leg is deregistered it reverts, while its sibling
    ///         still classifies correctly
    function test_sideOf_followsDeregistration() public {
        registry.proposeDeregisterReserve(usdcDebtKey);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        registry.executeDeregisterReserve(usdcDebtKey);

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.sideOf(usdcDebtKey);
        assertTrue(oracle.sideOf(usdcKey) == AaveV4ReserveRegistryV2.Side.SUPPLY, "sibling still classifies");
    }

    /// @notice What actually protects the dispatch today is the ABI DECODER, not the `UNHANDLED_SIDE`
    ///         branch: a registry reporting a side outside the declared enum makes the oracle's own
    ///         `getReserveInfo` decode revert before either branch is evaluated. Verified by mutation —
    ///         replacing `revert UNHANDLED_SIDE()` with a supply fall-through leaves this test passing, so
    ///         it is pinned here as decoder behaviour and NOT presented as coverage of that branch.
    /// @dev `UNHANDLED_SIDE` is therefore unreachable from any external caller and is defensive only: it
    ///      exists so that ADDING a third `Side` member in source cannot silently make a supply read the
    ///      fall-through (`Side.SUPPLY` is the zero value and the `delete` default). That property is not
    ///      falsifiable by a test against the current two-member enum; whoever adds a third member must
    ///      extend the dispatch and add its own coverage.
    function test_outOfRangeSide_isRejectedByTheAbiDecoder() public {
        MockOutOfRangeSideRegistry badRegistry = new MockOutOfRangeSideRegistry(address(spoke));
        AaveV4ReserveOracle probe = new AaveV4ReserveOracle(ledgerConfig, address(badRegistry));

        // Not a typed revert: this is the decoder rejecting an enum value of 2 for a two-member enum
        vm.expectRevert();
        probe.getBalanceOfOwner(usdcKey, account1);
        vm.expectRevert();
        probe.getTVL(usdcKey);
        vm.expectRevert();
        probe.sideOf(usdcKey);
    }

    /// @notice The registry's public derivations must agree with the shared library exactly. They are two
    ///         surfaces onto one derivation; if they ever diverge, hook headers and registry keys disagree.
    function testFuzz_registryDerivations_matchTheSharedLibrary(address spoke_, uint256 id_) public {
        AaveV4ReserveKeyLibHarness lib = new AaveV4ReserveKeyLibHarness();
        assertEq(registry.computeReserveKey(spoke_, id_), lib.supplyKey(spoke_, id_), "supply derivation agrees");
        assertEq(registry.computeDebtKey(spoke_, id_), lib.debtKey(spoke_, id_), "debt derivation agrees");
        assertEq(registry.DEBT_KEY_DOMAIN(), lib.domain(), "DEBT_KEY_DOMAIN re-export agrees");
    }
}
