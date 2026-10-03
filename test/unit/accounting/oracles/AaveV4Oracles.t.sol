// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

import { AaveV4ReserveRegistryV2 } from "../../../../src/accounting/oracles/AaveV4ReserveRegistryV2.sol";
import { AaveV4ReserveOracle } from "../../../../src/accounting/oracles/AaveV4ReserveOracle.sol";
import { IAaveV4Spoke } from "../../../../src/vendor/aave-v4/IAaveV4Spoke.sol";
import { SuperLedgerConfiguration } from "../../../../src/accounting/SuperLedgerConfiguration.sol";
import { ISuperLedgerConfiguration } from "../../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { SuperLedger } from "../../../../src/accounting/SuperLedger.sol";
import { ISuperLedger, ISuperLedgerData } from "../../../../src/interfaces/accounting/ISuperLedger.sol";

/// @dev Ledger mock whose previewFees treats the ENTIRE amount as profit (zero cost basis) —
///      models the debt-oracle hazard: debt positions never snapshot, so nothing offsets the "profit".
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

/// @dev Minimal spoke mock with settable reserves, user debt (drawn/premium), user supply and
///      reserve-level aggregates. getReserve reverts for unlisted ids, matching the real spoke.
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

contract AaveV4OraclesTest is Test {
    AaveV4ReserveRegistryV2 public registry;
    AaveV4ReserveOracle public oracle;
    MockAaveV4Spoke public spoke;
    address public ledgerConfig;

    address public usdc = makeAddr("usdc");
    address public equity = makeAddr("equityToken");
    address public account1 = makeAddr("account1");
    address public account2 = makeAddr("account2");

    uint256 public constant USDC_RESERVE_ID = 7;
    uint256 public constant EQUITY_RESERVE_ID = 12;

    /// @dev SUPPLY keys — the unchanged legacy derivation, `registry.computeReserveKey`
    address public usdcKey;
    address public equityKey;

    /// @dev DEBT keys — `registry.computeDebtKey`, the second leg registered by the same call
    address public usdcDebtKey;
    address public equityDebtKey;

    function setUp() public {
        // Avoid timestamp underflow in timelock math on the default block.timestamp
        vm.warp(365 days * 2);

        ledgerConfig = address(new SuperLedgerConfiguration());
        registry = new AaveV4ReserveRegistryV2(address(this));
        oracle = new AaveV4ReserveOracle(ledgerConfig, address(registry));

        spoke = new MockAaveV4Spoke();
        spoke.setReserve(USDC_RESERVE_ID, usdc, 6);
        spoke.setReserve(EQUITY_RESERVE_ID, equity, 18);

        (usdcKey, usdcDebtKey) = registry.registerReserve(address(spoke), USDC_RESERVE_ID);
        (equityKey, equityDebtKey) = registry.registerReserve(address(spoke), EQUITY_RESERVE_ID);

        // Default state: account1 borrows USDC (drawn + premium), supplies equity
        spoke.setUserDebt(USDC_RESERVE_ID, account1, 400e6, 100e6);
        spoke.setUserSuppliedAssets(EQUITY_RESERVE_ID, account1, 2 ether);
        spoke.setReserveDebt(USDC_RESERVE_ID, 900_000e6, 100_000e6);
        spoke.setReserveSuppliedAssets(EQUITY_RESERVE_ID, 50_000 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTORS
    //////////////////////////////////////////////////////////////*/

    function test_constructors_setImmutables() public view {
        assertEq(oracle.SUPER_LEDGER_CONFIGURATION(), ledgerConfig);
        assertEq(address(oracle.REGISTRY()), address(registry));
    }

    function test_constructors_revertIf_zeroRegistry() public {
        vm.expectRevert(AaveV4ReserveOracle.ZERO_ADDRESS.selector);
        new AaveV4ReserveOracle(ledgerConfig, address(0));

        vm.expectRevert(AaveV4ReserveOracle.ZERO_ADDRESS.selector);
        new AaveV4ReserveOracle(address(0), address(registry));
    }

    function test_registryConstructor_revertIf_zeroAdmin() public {
        vm.expectRevert(AaveV4ReserveRegistryV2.ZERO_ADDRESS.selector);
        new AaveV4ReserveRegistryV2(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                        REGISTRY: KEY DERIVATION
    //////////////////////////////////////////////////////////////*/

    /// @notice registerReserve's stored key must equal the pure preview (hash-derivation property)
    function test_registry_computeReserveKey_matchesRegistration() public view {
        assertEq(usdcKey, registry.computeReserveKey(address(spoke), USDC_RESERVE_ID));
        assertEq(equityKey, registry.computeReserveKey(address(spoke), EQUITY_RESERVE_ID));
        assertEq(usdcKey, address(uint160(uint256(keccak256(abi.encode(address(spoke), USDC_RESERVE_ID))))));
    }

    /// @notice Fuzzed derivation property against an INDEPENDENT inline recomputation
    function test_fuzz_registry_computeReserveKey_matchesIndependentDerivation(
        address spoke_,
        uint256 reserveId_
    )
        public
        view
    {
        assertEq(
            registry.computeReserveKey(spoke_, reserveId_),
            address(uint160(uint256(keccak256(abi.encode(spoke_, reserveId_)))))
        );
    }

    /*//////////////////////////////////////////////////////////////
                        REGISTRY: REGISTRATION
    //////////////////////////////////////////////////////////////*/

    function test_registry_register_storesBinding() public view {
        (address spoke_, uint256 reserveId_, address underlying_, uint8 decimals_, AaveV4ReserveRegistryV2.Side side_) =
            registry.getReserveInfo(usdcKey);
        assertEq(spoke_, address(spoke));
        assertEq(reserveId_, USDC_RESERVE_ID);
        assertEq(underlying_, usdc);
        assertEq(decimals_, 6);
        assertTrue(side_ == AaveV4ReserveRegistryV2.Side.SUPPLY, "legacy key is the SUPPLY leg");
        assertTrue(registry.isRegistered(usdcKey));
    }

    /// @notice One registerReserve call binds BOTH legs: same spoke/reserve/underlying/decimals,
    ///         differing only in side, under two distinct keys
    function test_registry_register_storesBothLegs() public view {
        (address sSpoke, uint256 sId, address sUnderlying, uint8 sDecimals, AaveV4ReserveRegistryV2.Side sSide) =
            registry.getReserveInfo(usdcKey);
        (address dSpoke, uint256 dId, address dUnderlying, uint8 dDecimals, AaveV4ReserveRegistryV2.Side dSide) =
            registry.getReserveInfo(usdcDebtKey);

        assertEq(dSpoke, sSpoke, "same spoke");
        assertEq(dId, sId, "same reserveId");
        assertEq(dUnderlying, sUnderlying, "same underlying");
        assertEq(dDecimals, sDecimals, "same decimals");
        assertTrue(sSide == AaveV4ReserveRegistryV2.Side.SUPPLY);
        assertTrue(dSide == AaveV4ReserveRegistryV2.Side.DEBT);
        assertTrue(usdcKey != usdcDebtKey, "the legs must be keyed apart");
        assertEq(usdcDebtKey, registry.computeDebtKey(address(spoke), USDC_RESERVE_ID), "debt key derivation");
    }

    function test_registry_register_revertIf_duplicate() public {
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_ALREADY_REGISTERED.selector);
        registry.registerReserve(address(spoke), USDC_RESERVE_ID);
    }

    function test_registry_register_revertIf_zeroSpoke() public {
        vm.expectRevert(AaveV4ReserveRegistryV2.ZERO_ADDRESS.selector);
        registry.registerReserve(address(0), 0);
    }

    /// @notice A codeless (EOA) spoke must revert at registration, not garbage-decode-succeed
    function test_registry_register_revertIf_codelessSpoke() public {
        vm.expectRevert();
        registry.registerReserve(makeAddr("eoaSpoke"), 0);
    }

    function test_registry_register_revertIf_unlistedReserve() public {
        vm.expectRevert(MockAaveV4Spoke.ReserveNotListed.selector);
        registry.registerReserve(address(spoke), 999);
    }

    function test_registry_register_revertIf_zeroUnderlying() public {
        spoke.setReserve(42, address(0), 18);
        vm.expectRevert(AaveV4ReserveRegistryV2.INVALID_RESERVE.selector);
        registry.registerReserve(address(spoke), 42);
    }

    function test_registry_register_revertIf_notManager() public {
        vm.prank(account1);
        vm.expectRevert();
        registry.registerReserve(address(spoke), USDC_RESERVE_ID);
    }

    /*//////////////////////////////////////////////////////////////
                        REGISTRY: DEREGISTRATION
    //////////////////////////////////////////////////////////////*/

    function test_registry_deregister_lifecycle() public {
        registry.proposeDeregisterReserve(usdcKey);
        assertEq(registry.pendingDeregistrations(usdcKey), block.timestamp + registry.DEREGISTER_DELAY());

        // Before the timelock elapses: revert
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY() - 1);
        vm.expectRevert(AaveV4ReserveRegistryV2.DEREGISTRATION_TIMELOCK_NOT_ELAPSED.selector);
        registry.executeDeregisterReserve(usdcKey);

        // At the boundary: succeeds
        vm.warp(block.timestamp + 1);
        registry.executeDeregisterReserve(usdcKey);
        assertFalse(registry.isRegistered(usdcKey));

        // Post-deregistration reads revert
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        registry.getReserveInfo(usdcKey);
    }

    function test_registry_deregister_cancel() public {
        registry.proposeDeregisterReserve(usdcKey);
        registry.cancelDeregisterReserve(usdcKey);
        assertEq(registry.pendingDeregistrations(usdcKey), 0);
        assertTrue(registry.isRegistered(usdcKey));

        vm.warp(block.timestamp + 3 days);
        vm.expectRevert(AaveV4ReserveRegistryV2.DEREGISTRATION_NOT_PENDING.selector);
        registry.executeDeregisterReserve(usdcKey);
    }

    function test_registry_deregister_revertIf_notPending() public {
        vm.expectRevert(AaveV4ReserveRegistryV2.DEREGISTRATION_NOT_PENDING.selector);
        registry.executeDeregisterReserve(usdcKey);
        vm.expectRevert(AaveV4ReserveRegistryV2.DEREGISTRATION_NOT_PENDING.selector);
        registry.cancelDeregisterReserve(usdcKey);
    }

    function test_registry_deregister_revertIf_notRegistered() public {
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        registry.proposeDeregisterReserve(makeAddr("unknownKey"));
    }

    /// @notice Hash-derivation property: re-registering the same pair after deregistration
    ///         restores the IDENTICAL key — a key can never be rebound to a different reserve
    function test_registry_reregistration_restoresSameKey() public {
        // Both legs must go: registration is per reserve, so a surviving leg blocks re-registration
        registry.proposeDeregisterReserve(usdcKey);
        registry.proposeDeregisterReserve(usdcDebtKey);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        registry.executeDeregisterReserve(usdcKey);
        registry.executeDeregisterReserve(usdcDebtKey);

        (address keyAgain, address debtKeyAgain) = registry.registerReserve(address(spoke), USDC_RESERVE_ID);
        assertEq(keyAgain, usdcKey, "re-registration must restore the identical derived supply key");
        assertEq(debtKeyAgain, usdcDebtKey, "re-registration must restore the identical derived debt key");
    }

    /// @notice Deregistration is PER KEY while registration is PER RESERVE, so dropping one leg leaves
    ///         the other resolvable — and that survivor blocks re-registration of the whole reserve
    function test_registry_deregisterOneLeg_otherLegSurvives_andBlocksReregistration() public {
        registry.proposeDeregisterReserve(usdcKey);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        registry.executeDeregisterReserve(usdcKey);

        assertFalse(registry.isRegistered(usdcKey), "supply leg dropped");
        assertTrue(registry.isRegistered(usdcDebtKey), "debt leg survives independently");
        // The surviving debt leg still resolves for reads
        assertEq(oracle.getPricePerShare(usdcDebtKey), 1e6);
        // ...and blocks re-registering the reserve until it too is dropped
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_ALREADY_REGISTERED.selector);
        registry.registerReserve(address(spoke), USDC_RESERVE_ID);
    }

    /*//////////////////////////////////////////////////////////////
                         DEBT LEG: IDENTITY + READS
    //////////////////////////////////////////////////////////////*/

    function test_debt_decimalsAndPps() public view {
        assertEq(oracle.decimals(usdcDebtKey), 6);
        assertEq(oracle.getPricePerShare(usdcDebtKey), 1e6);
        assertEq(oracle.decimals(equityDebtKey), 18);
        assertEq(oracle.getPricePerShare(equityDebtKey), 1e18);
    }

    function test_debt_identityConverters() public view {
        assertEq(oracle.getShareOutput(usdcDebtKey, address(0), 123e6), 123e6);
        assertEq(oracle.getWithdrawalShareOutput(usdcDebtKey, address(0), 123e6), 123e6);
        assertEq(oracle.getAssetOutput(usdcDebtKey, address(0), 123e6), 123e6);
    }

    /// @notice Total debt = drawn + premium — the exact BaseAaveV4LoanHookV2._totalDebt read
    function test_debt_balanceOfOwner_isDrawnPlusPremium() public view {
        assertEq(oracle.getBalanceOfOwner(usdcDebtKey, account1), 500e6);
        assertEq(oracle.getTVLByOwnerOfShares(usdcDebtKey, account1), 500e6);
    }

    function test_debt_balanceOfOwner_zeroDebt() public view {
        assertEq(oracle.getBalanceOfOwner(usdcDebtKey, account2), 0);
    }

    function test_debt_balanceOfOwner_drawnOnly() public {
        spoke.setUserDebt(USDC_RESERVE_ID, account2, 250e6, 0);
        assertEq(oracle.getBalanceOfOwner(usdcDebtKey, account2), 250e6);
    }

    /// @notice Premium-only debt is still debt (drawn == 0, premium > 0)
    function test_debt_balanceOfOwner_premiumOnly() public {
        spoke.setUserDebt(USDC_RESERVE_ID, account2, 0, 33e6);
        assertEq(oracle.getBalanceOfOwner(usdcDebtKey, account2), 33e6);
    }

    function test_fuzz_debt_balanceOfOwner_sumNeverTruncates(uint128 drawn, uint128 premium) public {
        spoke.setUserDebt(USDC_RESERVE_ID, account2, drawn, premium);
        assertEq(oracle.getBalanceOfOwner(usdcDebtKey, account2), uint256(drawn) + uint256(premium));
    }

    function test_debt_getTVL_isReserveAggregate() public view {
        assertEq(oracle.getTVL(usdcDebtKey), 1_000_000e6);
    }

    /*//////////////////////////////////////////////////////////////
                        SUPPLY LEG: IDENTITY + READS
    //////////////////////////////////////////////////////////////*/

    function test_supply_decimalsAndPps() public view {
        assertEq(oracle.decimals(equityKey), 18);
        assertEq(oracle.getPricePerShare(equityKey), 1e18);
    }

    function test_supply_balanceOfOwner_isSuppliedAssets() public view {
        assertEq(oracle.getBalanceOfOwner(equityKey, account1), 2 ether);
        assertEq(oracle.getTVLByOwnerOfShares(equityKey, account1), 2 ether);
    }

    function test_supply_balanceOfOwner_zeroSupply() public view {
        assertEq(oracle.getBalanceOfOwner(equityKey, account2), 0);
    }

    function test_supply_getTVL_isReserveAggregate() public view {
        assertEq(oracle.getTVL(equityKey), 50_000 ether);
    }

    /// @notice Per-leg decimals independence: the 6-decimal debt leg and 18-decimal supply leg
    ///         of one market resolve decimals from their OWN reserve bindings
    function test_decimalsIndependence_acrossLegs() public view {
        assertEq(oracle.decimals(usdcDebtKey), 6);
        assertEq(oracle.decimals(equityKey), 18);
        assertEq(oracle.getPricePerShare(usdcDebtKey), 1e6);
        assertEq(oracle.getPricePerShare(equityKey), 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                    UNREGISTERED KEYS + BATCH ISOLATION
    //////////////////////////////////////////////////////////////*/

    function test_unregisteredKey_revertsTyped_everywhere() public {
        address unknown = makeAddr("unknownKey");
        bytes4 sel = AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector;

        vm.expectRevert(sel);
        oracle.decimals(unknown);
        vm.expectRevert(sel);
        oracle.getPricePerShare(unknown);
        vm.expectRevert(sel);
        oracle.getBalanceOfOwner(unknown, account1);
        vm.expectRevert(sel);
        oracle.getTVLByOwnerOfShares(unknown, account1);
        vm.expectRevert(sel);
        oracle.getTVL(unknown);
    }

    /// @notice getTVLByOwnerOfSharesMultiple isolates the unregistered entry; others succeed
    function test_batch_tvlByOwner_isolatesUnregisteredKey() public {
        address[] memory sources = new address[](2);
        sources[0] = usdcDebtKey;
        sources[1] = makeAddr("unknownKey");
        address[][] memory owners = new address[][](2);
        owners[0] = new address[](1);
        owners[0][0] = account1;
        owners[1] = new address[](1);
        owners[1][0] = account1;

        (uint256[][] memory tvls, bool[][] memory ok) = oracle.getTVLByOwnerOfSharesMultiple(sources, owners);
        assertEq(tvls[0][0], 500e6);
        assertTrue(ok[0][0]);
        assertEq(tvls[1][0], 0);
        assertFalse(ok[1][0]);
    }

    /// @notice KNOWN ISSUE (inherited): getPricePerShareMultiple / getTVLMultiple have no per-entry
    ///         isolation — a single unregistered key aborts the whole batch call
    function test_batch_ppsAndTvlMultiple_knownIssue_abortOnUnregisteredKey() public {
        address[] memory sources = new address[](2);
        sources[0] = usdcDebtKey;
        sources[1] = makeAddr("unknownKey");

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.getPricePerShareMultiple(sources);

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.getTVLMultiple(sources);
    }

    /*//////////////////////////////////////////////////////////////
                        FEE PATHS (T1 HAZARD DEMO)
    //////////////////////////////////////////////////////////////*/

    /// @dev Register a config in SuperLedgerConfiguration and return the derived oracle id
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

    /// @notice PR-997 F1 fix pinned: the supply oracle's override BYPASSES the fee view entirely
    ///         during the standalone phase — with feePercent > 0 and zero cost basis (no hook
    ///         wiring exists to snapshot), the base implementation would have inflated 500 USDC
    ///         principal to 550; the override returns identity instead. The ledger path still
    ///         relies on the feePercent = 0 operational invariant.
    function test_getAssetOutputWithFees_supplyLeg_overrideBypassesFees_zeroCostBasis() public {
        address mockLedger = address(new MockZeroCostBasisLedger());
        bytes32 id = _registerConfig(keccak256("AAVE_V4_SUPPLY_FEE"), address(oracle), 1000, mockLedger); // 10%

        uint256 amount = 500e6;
        uint256 result = oracle.getAssetOutputWithFees(id, usdcKey, address(0), account1, amount);
        assertEq(result, amount, "supply leg must bypass fee math; principal can never be fee-inflated");
    }

    /// @notice The debt leg's override BYPASSES the fee math entirely — identity output even with
    ///         a misconfigured feePercent > 0 (protects the view path; the ledger path still relies
    ///         on the feePercent = 0 operational invariant).
    function test_getAssetOutputWithFees_debtLeg_overrideBypassesFees() public {
        address mockLedger = address(new MockZeroCostBasisLedger());
        bytes32 id = _registerConfig(keccak256("AAVE_V4_DEBT_FEE_MISCONFIG"), address(oracle), 1000, mockLedger);

        uint256 debtAmount = 500e6;
        uint256 result = oracle.getAssetOutputWithFees(id, usdcDebtKey, address(0), account1, debtAmount);
        assertEq(result, debtAmount, "debt leg must bypass fee math regardless of config");
    }

    /// @notice Missing config falls through to plain output on the inherited (supply) path
    function test_getAssetOutputWithFees_supplyLeg_noConfig_returnsIdentity() public view {
        bytes32 fakeId = keccak256("UNREGISTERED_CONFIG");
        assertEq(oracle.getAssetOutputWithFees(fakeId, usdcKey, address(0), account1, 123e6), 123e6);
    }

    /// @notice Configured feePercent == 0 returns identity on the inherited path
    function test_getAssetOutputWithFees_supplyLeg_configuredZeroFee_returnsIdentity() public {
        address mockLedger = address(new MockZeroCostBasisLedger());
        bytes32 id = _registerConfig(keccak256("AAVE_V4_SUPPLY_ZERO_FEE"), address(oracle), 0, mockLedger);
        assertEq(oracle.getAssetOutputWithFees(id, usdcKey, address(0), account1, 123e6), 123e6);
    }

    /// @notice REAL-LEDGER round trip (documents the FUTURE-wiring ledger path; production keeps
    ///         feePercent = 0 until accounting hooks exist): with identity PPS and a configured
    ///         fee, a plain supply-then-withdraw of principal takes a cost-basis snapshot and
    ///         charges ZERO fee (never-over-charge property on the ledger path)
    function test_realLedger_supplyRoundTrip_principalChargesZeroFee() public {
        address[] memory executors = new address[](1);
        executors[0] = address(this);
        SuperLedger realLedger = new SuperLedger(ledgerConfig, executors);
        bytes32 id =
            _registerConfig(keccak256("AAVE_V4_SUPPLY_REAL_LEDGER"), address(oracle), 1000, address(realLedger));

        uint256 amount = 1000e6;
        // Inflow: snapshot cost basis at identity PPS
        realLedger.updateAccounting(account1, usdcKey, id, true, amount, 0);
        // Outflow: withdraw the same principal — profit == 0 → fee == 0
        uint256 feeAmount = realLedger.updateAccounting(account1, usdcKey, id, false, amount, amount);
        assertEq(feeAmount, 0, "identity PPS principal round trip must charge zero fee");
    }

    /// @notice DOCBLOCK CASE (a), WITH REAL ACCRUAL: the oracle's "WHY THE FEE VIEW IS BYPASSED ON BOTH
    ///         LEGS" note claims that on the SUPPLY leg a non-zero `feePercent` charges nothing because
    ///         identity PPS makes cost basis == shares at every snapshot, so "a partial redeem re-prices
    ///         to its own cost basis". This pins exactly that: principal in, yield accrues ON THE SPOKE
    ///         (so the position is genuinely in profit and `getBalanceOfOwner` reports it), then a PARTIAL
    ///         outflow through the real `SuperLedger` at `feePercent = 10%` still yields `feeAmount == 0`.
    /// @dev This is the load-bearing reason there is no on-chain `feePercent == 0` guard on the supply
    ///      leg, so it must be tested with accrual present. The pre-existing
    ///      `test_realLedger_supplyRoundTrip_principalChargesZeroFee` is principal-in / principal-out with
    ///      NO accrual — the degenerate case where profit is trivially zero and the claim is untested.
    ///      The amounts mirror the idle MONEY_MARKET hooks: `AaveV4LendHook` (INFLOW) reports the
    ///      supplied-assets delta as "shares", and `AaveV4RedeemHook` (OUTFLOW) reports the redeemed
    ///      asset amount as both `amountSharesOrAssets` and `usedShares` — identical under identity PPS.
    function test_realLedger_supplyLeg_partialRedeemAfterAccrual_chargesZeroFeeDespiteNonZeroFeePercent() public {
        (SuperLedger realLedger, bytes32 id) =
            _realLedgerWithFee(keccak256("AAVE_V4_SUPPLY_PARTIAL_AFTER_ACCRUAL"), 1000);

        // --- INFLOW: 1000 USDC of principal lands on the spoke and is snapshotted ---
        uint256 principal = 1000e6;
        spoke.setUserSuppliedAssets(USDC_RESERVE_ID, account1, principal);
        realLedger.updateAccounting(account1, usdcKey, id, true, principal, 0);
        assertEq(realLedger.usersAccumulatorShares(account1, usdcKey), principal, "accumulator holds the principal");
        assertEq(
            realLedger.usersAccumulatorCostBasis(account1, usdcKey),
            principal,
            "identity PPS: cost basis equals shares at the snapshot"
        );

        // --- ACCRUAL: the spoke's virtual accrual grows the position by 10% ---
        uint256 accrued = 1100e6;
        spoke.setUserSuppliedAssets(USDC_RESERVE_ID, account1, accrued);
        assertGt(accrued, principal, "the accrual is real, so profit is not trivially zero");
        assertEq(oracle.getBalanceOfOwner(usdcKey, account1), accrued, "the oracle reports the accrued position");

        // --- PARTIAL OUTFLOW: half of the principal, priced at identity PPS ---
        uint256 redeemed = 500e6;
        uint256 feeAmount = realLedger.updateAccounting(account1, usdcKey, id, false, redeemed, redeemed);
        assertEq(feeAmount, 0, "partial redeem re-prices to its own cost basis: zero profit, zero fee");

        // the accumulators drained proportionally — cost basis stays equal to shares, which is why the
        // NEXT partial redeem is zero-fee too
        assertEq(realLedger.usersAccumulatorShares(account1, usdcKey), principal - redeemed, "shares drained pro rata");
        assertEq(
            realLedger.usersAccumulatorCostBasis(account1, usdcKey),
            principal - redeemed,
            "cost basis drained pro rata: still equal to shares"
        );

        // CONSUMER WARNING pinned: the ledger accumulator is NOT NAV — the spoke still holds the accrued
        // remainder, which exceeds the remaining ledger shares
        assertGt(
            oracle.getBalanceOfOwner(usdcKey, account1) - redeemed,
            realLedger.usersAccumulatorShares(account1, usdcKey),
            "ledger shares understate the live position once yield has accrued"
        );
    }

    /// @notice DOCBLOCK CASE (b), WITH REAL ACCRUAL: the second half of the same claim — "a full redeem
    ///         after accrual reports usedShares above the accumulator, which `BaseLedger` caps and
    ///         re-prices to the accumulator". Principal in, yield accrues on the spoke, then the WHOLE
    ///         accrued balance is redeemed so `usedShares` strictly exceeds the accumulator. `BaseLedger`
    ///         caps `usedShares` (emitting `UsedSharesCapped`), re-prices `amountAssets` to the capped
    ///         shares at identity PPS, and the fee is again ZERO at `feePercent = 10%`.
    /// @dev Together with the partial case above, this is the full two-case justification for having no
    ///      on-chain fee guard on the supply leg. The cap is what makes the accrued surplus invisible to
    ///      the fee math: without it, `amountAssets` (the accrued balance) would exceed the cost basis
    ///      (the principal) and the difference would be charged as profit.
    function test_realLedger_supplyLeg_fullRedeemAfterAccrual_usedSharesAboveAccumulator_chargesZeroFee() public {
        (SuperLedger realLedger, bytes32 id) = _realLedgerWithFee(keccak256("AAVE_V4_SUPPLY_FULL_AFTER_ACCRUAL"), 1000);

        // --- INFLOW: 1000 USDC of principal ---
        uint256 principal = 1000e6;
        spoke.setUserSuppliedAssets(USDC_RESERVE_ID, account1, principal);
        realLedger.updateAccounting(account1, usdcKey, id, true, principal, 0);

        // --- ACCRUAL: 23.4% of yield, chosen so no amount is a round multiple of the principal ---
        spoke.setUserSuppliedAssets(USDC_RESERVE_ID, account1, 1234e6);
        uint256 accrued = oracle.getBalanceOfOwner(usdcKey, account1);
        assertGt(
            accrued,
            realLedger.usersAccumulatorShares(account1, usdcKey),
            "precondition: a full redeem reports usedShares ABOVE the accumulator"
        );

        // --- FULL OUTFLOW: the redeem hook reports the entire accrued balance ---
        vm.expectEmit(true, true, true, true);
        emit ISuperLedgerData.UsedSharesCapped(accrued, principal);
        uint256 feeAmount = realLedger.updateAccounting(account1, usdcKey, id, false, accrued, accrued);
        assertEq(feeAmount, 0, "capped usedShares re-price to the accumulator: zero profit, zero fee");

        assertEq(realLedger.usersAccumulatorShares(account1, usdcKey), 0, "the accumulator is cleared");
        assertEq(realLedger.usersAccumulatorCostBasis(account1, usdcKey), 0, "and so is the cost basis");
    }

    /// @dev Real `SuperLedger` + a `SuperLedgerConfiguration` entry at a NON-ZERO `feePercent`, with the
    ///      fee asserted non-zero so the zero-fee results above can never be vacuous.
    /// @param salt Config salt, distinct per test
    /// @param feePercent Performance fee in basis points; must be > 0
    /// @return realLedger The ledger this test contract is an allowed executor on
    /// @return id The derived yieldSourceOracleId
    function _realLedgerWithFee(bytes32 salt, uint256 feePercent)
        internal
        returns (SuperLedger realLedger, bytes32 id)
    {
        address[] memory executors = new address[](1);
        executors[0] = address(this);
        realLedger = new SuperLedger(ledgerConfig, executors);
        id = _registerConfig(salt, address(oracle), feePercent, address(realLedger));

        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config =
            SuperLedgerConfiguration(ledgerConfig).getYieldSourceOracleConfig(id);
        assertGt(config.feePercent, 0, "the configured fee must be non-zero or the zero-fee result is vacuous");
        assertEq(config.ledger, address(realLedger), "the config points at the real ledger under test");
    }

    /*//////////////////////////////////////////////////////////////
                    REGISTRY: ROLE GATING + TIMELOCK HARDENING
    //////////////////////////////////////////////////////////////*/

    /// @notice Deregistration lifecycle functions are all role-gated (regression guard for the
    ///         highest-consequence registry action)
    function test_registry_deregistration_revertIf_notManager() public {
        registry.proposeDeregisterReserve(usdcKey);

        vm.startPrank(account1);
        vm.expectRevert();
        registry.proposeDeregisterReserve(usdcKey);
        vm.expectRevert();
        registry.cancelDeregisterReserve(usdcKey);
        vm.warp(block.timestamp + 2 days);
        vm.expectRevert();
        registry.executeDeregisterReserve(usdcKey);
        vm.stopPrank();
    }

    /// @notice Re-proposing resets (extends) the timelock — it can never shorten it
    function test_registry_repropose_extendsTimelock() public {
        registry.proposeDeregisterReserve(usdcKey);
        uint256 firstDeadline = registry.pendingDeregistrations(usdcKey);

        vm.warp(block.timestamp + 1 days);
        registry.proposeDeregisterReserve(usdcKey);
        uint256 secondDeadline = registry.pendingDeregistrations(usdcKey);
        assertEq(secondDeadline, firstDeadline + 1 days, "re-propose restarts the full delay");

        // The original deadline is no longer sufficient
        vm.warp(firstDeadline);
        vm.expectRevert(AaveV4ReserveRegistryV2.DEREGISTRATION_TIMELOCK_NOT_ELAPSED.selector);
        registry.executeDeregisterReserve(usdcKey);
    }

    /// @notice Fuzzed timelock boundary: execution succeeds iff the full delay elapsed
    function test_fuzz_registry_timelockBoundary(uint256 offset) public {
        offset = bound(offset, 0, 4 days);
        registry.proposeDeregisterReserve(usdcKey);
        uint256 deadline = registry.pendingDeregistrations(usdcKey);

        vm.warp(block.timestamp + offset);
        if (block.timestamp < deadline) {
            vm.expectRevert(AaveV4ReserveRegistryV2.DEREGISTRATION_TIMELOCK_NOT_ELAPSED.selector);
            registry.executeDeregisterReserve(usdcKey);
        } else {
            registry.executeDeregisterReserve(usdcKey);
            assertFalse(registry.isRegistered(usdcKey));
        }
    }

    /// @notice Invariant: a re-registered key can never inherit a live pending deregistration —
    ///         execute deletes the pending entry and is the only path to the unregistered state
    function test_registry_reregisteredKey_hasNoZombiePending() public {
        // Deregistration is per key, registration is per reserve: BOTH legs must be dropped or the
        // surviving one blocks re-registration with RESERVE_ALREADY_REGISTERED
        registry.proposeDeregisterReserve(usdcKey);
        registry.proposeDeregisterReserve(usdcDebtKey);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        registry.executeDeregisterReserve(usdcKey);
        registry.executeDeregisterReserve(usdcDebtKey);

        (address restored, address restoredDebt) = registry.registerReserve(address(spoke), USDC_RESERVE_ID);
        assertEq(restored, usdcKey);
        assertEq(restoredDebt, usdcDebtKey);
        assertEq(registry.pendingDeregistrations(usdcKey), 0, "no pending survives re-registration");
        vm.expectRevert(AaveV4ReserveRegistryV2.DEREGISTRATION_NOT_PENDING.selector);
        registry.executeDeregisterReserve(usdcKey);
    }

    /// @notice All four registry events fire with the expected payloads
    function test_registry_events() public {
        address key42 = registry.computeReserveKey(address(spoke), 42);
        spoke.setReserve(42, makeAddr("token42"), 18);

        address debtKey42 = registry.computeDebtKey(address(spoke), 42);
        vm.expectEmit(true, true, true, true);
        emit AaveV4ReserveRegistryV2.ReserveRegistered(
            key42, address(spoke), 42, makeAddr("token42"), AaveV4ReserveRegistryV2.Side.SUPPLY
        );
        vm.expectEmit(true, true, true, true);
        emit AaveV4ReserveRegistryV2.ReserveRegistered(
            debtKey42, address(spoke), 42, makeAddr("token42"), AaveV4ReserveRegistryV2.Side.DEBT
        );
        registry.registerReserve(address(spoke), 42);

        vm.expectEmit(true, false, false, true);
        emit AaveV4ReserveRegistryV2.ReserveDeregistrationProposed(key42, block.timestamp + 2 days);
        registry.proposeDeregisterReserve(key42);

        vm.expectEmit(true, false, false, false);
        emit AaveV4ReserveRegistryV2.ReserveDeregistrationCancelled(key42);
        registry.cancelDeregisterReserve(key42);

        registry.proposeDeregisterReserve(key42);
        vm.warp(block.timestamp + 2 days);
        vm.expectEmit(true, false, false, false);
        emit AaveV4ReserveRegistryV2.ReserveDeregistered(key42);
        registry.executeDeregisterReserve(key42);
    }

    /*//////////////////////////////////////////////////////////////
                    FLAGS LIVENESS + PPS BOUNDARY
    //////////////////////////////////////////////////////////////*/

    /// @notice F3 (unit form): the oracles never gate on reserve flags — every view keeps
    ///         returning with paused|frozen flags set, so accounting reads survive pauses
    function test_views_liveUnderPausedFrozenFlags() public {
        spoke.setReserveFlags(USDC_RESERVE_ID, 0x03); // paused | frozen

        assertEq(oracle.decimals(usdcDebtKey), 6);
        assertEq(oracle.getPricePerShare(usdcDebtKey), 1e6);
        assertEq(oracle.getBalanceOfOwner(usdcDebtKey, account1), 500e6);
        assertEq(oracle.getTVL(usdcDebtKey), 1_000_000e6);
        // Same reserve, SUPPLY leg: nobody supplied USDC, so the supply key reads zero while the
        // debt key above reads the borrow position — the per-key side discriminator in action
        assertEq(oracle.getBalanceOfOwner(usdcKey, account1), 0);
        assertEq(oracle.getTVL(usdcKey), 0);
    }

    /// @notice Pins the NatSpec claim: PPS works at decimals 77 and reverts (checked overflow)
    ///         at decimals 78
    function test_pps_decimalsOverflowBoundary() public {
        spoke.setReserve(77, makeAddr("token77"), 77);
        spoke.setReserve(78, makeAddr("token78"), 78);
        (address key77, address debtKey77) = registry.registerReserve(address(spoke), 77);
        (address key78, address debtKey78) = registry.registerReserve(address(spoke), 78);

        // Side-independent: decimals and PPS come from the shared reserve binding, so both legs
        // behave identically at the boundary
        assertEq(oracle.getPricePerShare(key77), 10 ** 77);
        assertEq(oracle.getPricePerShare(debtKey77), 10 ** 77);
        vm.expectRevert(); // Panic(0x11) checked-arithmetic overflow
        oracle.getPricePerShare(key78);
        vm.expectRevert();
        oracle.getPricePerShare(debtKey78);
    }
}
