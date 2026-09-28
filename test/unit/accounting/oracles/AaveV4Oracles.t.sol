// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

import { AaveV4ReserveRegistry } from "../../../../src/accounting/oracles/AaveV4ReserveRegistry.sol";
import { AaveV4DebtOracle } from "../../../../src/accounting/oracles/AaveV4DebtOracle.sol";
import { AaveV4SupplyYieldSourceOracle } from "../../../../src/accounting/oracles/AaveV4SupplyYieldSourceOracle.sol";
import { IAaveV4Spoke } from "../../../../src/vendor/aave-v4/IAaveV4Spoke.sol";
import { SuperLedgerConfiguration } from "../../../../src/accounting/SuperLedgerConfiguration.sol";
import { ISuperLedgerConfiguration } from "../../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { SuperLedger } from "../../../../src/accounting/SuperLedger.sol";
import { ISuperLedger } from "../../../../src/interfaces/accounting/ISuperLedger.sol";

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
    AaveV4ReserveRegistry public registry;
    AaveV4DebtOracle public debtOracle;
    AaveV4SupplyYieldSourceOracle public supplyOracle;
    MockAaveV4Spoke public spoke;
    address public ledgerConfig;

    address public usdc = makeAddr("usdc");
    address public equity = makeAddr("equityToken");
    address public account1 = makeAddr("account1");
    address public account2 = makeAddr("account2");

    uint256 public constant USDC_RESERVE_ID = 7;
    uint256 public constant EQUITY_RESERVE_ID = 12;

    address public usdcKey;
    address public equityKey;

    function setUp() public {
        // Avoid timestamp underflow in timelock math on the default block.timestamp
        vm.warp(365 days * 2);

        ledgerConfig = address(new SuperLedgerConfiguration());
        registry = new AaveV4ReserveRegistry(address(this));
        debtOracle = new AaveV4DebtOracle(ledgerConfig, address(registry));
        supplyOracle = new AaveV4SupplyYieldSourceOracle(ledgerConfig, address(registry));

        spoke = new MockAaveV4Spoke();
        spoke.setReserve(USDC_RESERVE_ID, usdc, 6);
        spoke.setReserve(EQUITY_RESERVE_ID, equity, 18);

        usdcKey = registry.registerReserve(address(spoke), USDC_RESERVE_ID);
        equityKey = registry.registerReserve(address(spoke), EQUITY_RESERVE_ID);

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
        assertEq(debtOracle.SUPER_LEDGER_CONFIGURATION(), ledgerConfig);
        assertEq(address(debtOracle.REGISTRY()), address(registry));
        assertEq(supplyOracle.SUPER_LEDGER_CONFIGURATION(), ledgerConfig);
        assertEq(address(supplyOracle.REGISTRY()), address(registry));
    }

    function test_constructors_revertIf_zeroRegistry() public {
        vm.expectRevert(AaveV4DebtOracle.ZERO_ADDRESS.selector);
        new AaveV4DebtOracle(ledgerConfig, address(0));

        vm.expectRevert(AaveV4SupplyYieldSourceOracle.ZERO_ADDRESS.selector);
        new AaveV4SupplyYieldSourceOracle(ledgerConfig, address(0));
    }

    function test_registryConstructor_revertIf_zeroAdmin() public {
        vm.expectRevert(AaveV4ReserveRegistry.ZERO_ADDRESS.selector);
        new AaveV4ReserveRegistry(address(0));
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
        (address spoke_, uint256 reserveId_, address underlying_, uint8 decimals_) = registry.getReserveInfo(usdcKey);
        assertEq(spoke_, address(spoke));
        assertEq(reserveId_, USDC_RESERVE_ID);
        assertEq(underlying_, usdc);
        assertEq(decimals_, 6);
        assertTrue(registry.isRegistered(usdcKey));
    }

    function test_registry_register_revertIf_duplicate() public {
        vm.expectRevert(AaveV4ReserveRegistry.RESERVE_ALREADY_REGISTERED.selector);
        registry.registerReserve(address(spoke), USDC_RESERVE_ID);
    }

    function test_registry_register_revertIf_zeroSpoke() public {
        vm.expectRevert(AaveV4ReserveRegistry.ZERO_ADDRESS.selector);
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
        vm.expectRevert(AaveV4ReserveRegistry.INVALID_RESERVE.selector);
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
        vm.expectRevert(AaveV4ReserveRegistry.DEREGISTRATION_TIMELOCK_NOT_ELAPSED.selector);
        registry.executeDeregisterReserve(usdcKey);

        // At the boundary: succeeds
        vm.warp(block.timestamp + 1);
        registry.executeDeregisterReserve(usdcKey);
        assertFalse(registry.isRegistered(usdcKey));

        // Post-deregistration reads revert
        vm.expectRevert(AaveV4ReserveRegistry.RESERVE_NOT_REGISTERED.selector);
        registry.getReserveInfo(usdcKey);
    }

    function test_registry_deregister_cancel() public {
        registry.proposeDeregisterReserve(usdcKey);
        registry.cancelDeregisterReserve(usdcKey);
        assertEq(registry.pendingDeregistrations(usdcKey), 0);
        assertTrue(registry.isRegistered(usdcKey));

        vm.warp(block.timestamp + 3 days);
        vm.expectRevert(AaveV4ReserveRegistry.DEREGISTRATION_NOT_PENDING.selector);
        registry.executeDeregisterReserve(usdcKey);
    }

    function test_registry_deregister_revertIf_notPending() public {
        vm.expectRevert(AaveV4ReserveRegistry.DEREGISTRATION_NOT_PENDING.selector);
        registry.executeDeregisterReserve(usdcKey);
        vm.expectRevert(AaveV4ReserveRegistry.DEREGISTRATION_NOT_PENDING.selector);
        registry.cancelDeregisterReserve(usdcKey);
    }

    function test_registry_deregister_revertIf_notRegistered() public {
        vm.expectRevert(AaveV4ReserveRegistry.RESERVE_NOT_REGISTERED.selector);
        registry.proposeDeregisterReserve(makeAddr("unknownKey"));
    }

    /// @notice Hash-derivation property: re-registering the same pair after deregistration
    ///         restores the IDENTICAL key — a key can never be rebound to a different reserve
    function test_registry_reregistration_restoresSameKey() public {
        registry.proposeDeregisterReserve(usdcKey);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        registry.executeDeregisterReserve(usdcKey);

        address keyAgain = registry.registerReserve(address(spoke), USDC_RESERVE_ID);
        assertEq(keyAgain, usdcKey, "re-registration must restore the identical derived key");
    }

    /*//////////////////////////////////////////////////////////////
                        DEBT ORACLE: IDENTITY + READS
    //////////////////////////////////////////////////////////////*/

    function test_debt_decimalsAndPps() public view {
        assertEq(debtOracle.decimals(usdcKey), 6);
        assertEq(debtOracle.getPricePerShare(usdcKey), 1e6);
        assertEq(debtOracle.decimals(equityKey), 18);
        assertEq(debtOracle.getPricePerShare(equityKey), 1e18);
    }

    function test_debt_identityConverters() public view {
        assertEq(debtOracle.getShareOutput(usdcKey, address(0), 123e6), 123e6);
        assertEq(debtOracle.getWithdrawalShareOutput(usdcKey, address(0), 123e6), 123e6);
        assertEq(debtOracle.getAssetOutput(usdcKey, address(0), 123e6), 123e6);
    }

    /// @notice Total debt = drawn + premium — the exact BaseAaveV4LoanHookV2._totalDebt read
    function test_debt_balanceOfOwner_isDrawnPlusPremium() public view {
        assertEq(debtOracle.getBalanceOfOwner(usdcKey, account1), 500e6);
        assertEq(debtOracle.getTVLByOwnerOfShares(usdcKey, account1), 500e6);
    }

    function test_debt_balanceOfOwner_zeroDebt() public view {
        assertEq(debtOracle.getBalanceOfOwner(usdcKey, account2), 0);
    }

    function test_debt_balanceOfOwner_drawnOnly() public {
        spoke.setUserDebt(USDC_RESERVE_ID, account2, 250e6, 0);
        assertEq(debtOracle.getBalanceOfOwner(usdcKey, account2), 250e6);
    }

    /// @notice Premium-only debt is still debt (drawn == 0, premium > 0)
    function test_debt_balanceOfOwner_premiumOnly() public {
        spoke.setUserDebt(USDC_RESERVE_ID, account2, 0, 33e6);
        assertEq(debtOracle.getBalanceOfOwner(usdcKey, account2), 33e6);
    }

    function test_fuzz_debt_balanceOfOwner_sumNeverTruncates(uint128 drawn, uint128 premium) public {
        spoke.setUserDebt(USDC_RESERVE_ID, account2, drawn, premium);
        assertEq(debtOracle.getBalanceOfOwner(usdcKey, account2), uint256(drawn) + uint256(premium));
    }

    function test_debt_getTVL_isReserveAggregate() public view {
        assertEq(debtOracle.getTVL(usdcKey), 1_000_000e6);
    }

    /*//////////////////////////////////////////////////////////////
                    SUPPLY ORACLE: IDENTITY + READS
    //////////////////////////////////////////////////////////////*/

    function test_supply_decimalsAndPps() public view {
        assertEq(supplyOracle.decimals(equityKey), 18);
        assertEq(supplyOracle.getPricePerShare(equityKey), 1e18);
    }

    function test_supply_balanceOfOwner_isSuppliedAssets() public view {
        assertEq(supplyOracle.getBalanceOfOwner(equityKey, account1), 2 ether);
        assertEq(supplyOracle.getTVLByOwnerOfShares(equityKey, account1), 2 ether);
    }

    function test_supply_balanceOfOwner_zeroSupply() public view {
        assertEq(supplyOracle.getBalanceOfOwner(equityKey, account2), 0);
    }

    function test_supply_getTVL_isReserveAggregate() public view {
        assertEq(supplyOracle.getTVL(equityKey), 50_000 ether);
    }

    /// @notice Per-leg decimals independence: the 6-decimal debt leg and 18-decimal supply leg
    ///         of one market resolve decimals from their OWN reserve bindings
    function test_decimalsIndependence_acrossLegs() public view {
        assertEq(debtOracle.decimals(usdcKey), 6);
        assertEq(supplyOracle.decimals(equityKey), 18);
        assertEq(debtOracle.getPricePerShare(usdcKey), 1e6);
        assertEq(supplyOracle.getPricePerShare(equityKey), 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                    UNREGISTERED KEYS + BATCH ISOLATION
    //////////////////////////////////////////////////////////////*/

    function test_unregisteredKey_revertsTyped_everywhere() public {
        address unknown = makeAddr("unknownKey");
        bytes4 sel = AaveV4ReserveRegistry.RESERVE_NOT_REGISTERED.selector;

        vm.expectRevert(sel);
        debtOracle.decimals(unknown);
        vm.expectRevert(sel);
        debtOracle.getPricePerShare(unknown);
        vm.expectRevert(sel);
        debtOracle.getBalanceOfOwner(unknown, account1);
        vm.expectRevert(sel);
        debtOracle.getTVLByOwnerOfShares(unknown, account1);
        vm.expectRevert(sel);
        debtOracle.getTVL(unknown);

        vm.expectRevert(sel);
        supplyOracle.decimals(unknown);
        vm.expectRevert(sel);
        supplyOracle.getPricePerShare(unknown);
        vm.expectRevert(sel);
        supplyOracle.getBalanceOfOwner(unknown, account1);
        vm.expectRevert(sel);
        supplyOracle.getTVLByOwnerOfShares(unknown, account1);
        vm.expectRevert(sel);
        supplyOracle.getTVL(unknown);
    }

    /// @notice getTVLByOwnerOfSharesMultiple isolates the unregistered entry; others succeed
    function test_batch_tvlByOwner_isolatesUnregisteredKey() public {
        address[] memory sources = new address[](2);
        sources[0] = usdcKey;
        sources[1] = makeAddr("unknownKey");
        address[][] memory owners = new address[][](2);
        owners[0] = new address[](1);
        owners[0][0] = account1;
        owners[1] = new address[](1);
        owners[1][0] = account1;

        (uint256[][] memory tvls, bool[][] memory ok) = debtOracle.getTVLByOwnerOfSharesMultiple(sources, owners);
        assertEq(tvls[0][0], 500e6);
        assertTrue(ok[0][0]);
        assertEq(tvls[1][0], 0);
        assertFalse(ok[1][0]);
    }

    /// @notice KNOWN ISSUE (inherited): getPricePerShareMultiple / getTVLMultiple have no per-entry
    ///         isolation — a single unregistered key aborts the whole batch call
    function test_batch_ppsAndTvlMultiple_knownIssue_abortOnUnregisteredKey() public {
        address[] memory sources = new address[](2);
        sources[0] = usdcKey;
        sources[1] = makeAddr("unknownKey");

        vm.expectRevert(AaveV4ReserveRegistry.RESERVE_NOT_REGISTERED.selector);
        debtOracle.getPricePerShareMultiple(sources);

        vm.expectRevert(AaveV4ReserveRegistry.RESERVE_NOT_REGISTERED.selector);
        debtOracle.getTVLMultiple(sources);
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
            yieldSourceOracle: oracle_,
            feePercent: feePercent,
            feeRecipient: makeAddr("feeRecipient"),
            ledger: ledger
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
    function test_getAssetOutputWithFees_supplyOracle_overrideBypassesFees_zeroCostBasis() public {
        address mockLedger = address(new MockZeroCostBasisLedger());
        bytes32 id = _registerConfig(keccak256("AAVE_V4_SUPPLY_FEE"), address(supplyOracle), 1000, mockLedger); // 10%

        uint256 amount = 500e6;
        uint256 result = supplyOracle.getAssetOutputWithFees(id, usdcKey, address(0), account1, amount);
        assertEq(result, amount, "supply oracle must bypass fee math; principal can never be fee-inflated");
    }

    /// @notice The debt oracle's override BYPASSES the fee math entirely — identity output even with
    ///         a misconfigured feePercent > 0 (protects the view path; the ledger path still relies
    ///         on the feePercent = 0 operational invariant).
    function test_getAssetOutputWithFees_debtOracle_overrideBypassesFees() public {
        address mockLedger = address(new MockZeroCostBasisLedger());
        bytes32 id = _registerConfig(keccak256("AAVE_V4_DEBT_FEE_MISCONFIG"), address(debtOracle), 1000, mockLedger);

        uint256 debtAmount = 500e6;
        uint256 result = debtOracle.getAssetOutputWithFees(id, usdcKey, address(0), account1, debtAmount);
        assertEq(result, debtAmount, "debt oracle must bypass fee math regardless of config");
    }

    /// @notice Missing config falls through to plain output on the inherited (supply) path
    function test_getAssetOutputWithFees_supplyOracle_noConfig_returnsIdentity() public view {
        bytes32 fakeId = keccak256("UNREGISTERED_CONFIG");
        assertEq(supplyOracle.getAssetOutputWithFees(fakeId, usdcKey, address(0), account1, 123e6), 123e6);
    }

    /// @notice Configured feePercent == 0 returns identity on the inherited path
    function test_getAssetOutputWithFees_supplyOracle_configuredZeroFee_returnsIdentity() public {
        address mockLedger = address(new MockZeroCostBasisLedger());
        bytes32 id = _registerConfig(keccak256("AAVE_V4_SUPPLY_ZERO_FEE"), address(supplyOracle), 0, mockLedger);
        assertEq(supplyOracle.getAssetOutputWithFees(id, usdcKey, address(0), account1, 123e6), 123e6);
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
            _registerConfig(keccak256("AAVE_V4_SUPPLY_REAL_LEDGER"), address(supplyOracle), 1000, address(realLedger));

        uint256 amount = 1000e6;
        // Inflow: snapshot cost basis at identity PPS
        realLedger.updateAccounting(account1, usdcKey, id, true, amount, 0);
        // Outflow: withdraw the same principal — profit == 0 → fee == 0
        uint256 feeAmount = realLedger.updateAccounting(account1, usdcKey, id, false, amount, amount);
        assertEq(feeAmount, 0, "identity PPS principal round trip must charge zero fee");
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
        vm.expectRevert(AaveV4ReserveRegistry.DEREGISTRATION_TIMELOCK_NOT_ELAPSED.selector);
        registry.executeDeregisterReserve(usdcKey);
    }

    /// @notice Fuzzed timelock boundary: execution succeeds iff the full delay elapsed
    function test_fuzz_registry_timelockBoundary(uint256 offset) public {
        offset = bound(offset, 0, 4 days);
        registry.proposeDeregisterReserve(usdcKey);
        uint256 deadline = registry.pendingDeregistrations(usdcKey);

        vm.warp(block.timestamp + offset);
        if (block.timestamp < deadline) {
            vm.expectRevert(AaveV4ReserveRegistry.DEREGISTRATION_TIMELOCK_NOT_ELAPSED.selector);
            registry.executeDeregisterReserve(usdcKey);
        } else {
            registry.executeDeregisterReserve(usdcKey);
            assertFalse(registry.isRegistered(usdcKey));
        }
    }

    /// @notice Invariant: a re-registered key can never inherit a live pending deregistration —
    ///         execute deletes the pending entry and is the only path to the unregistered state
    function test_registry_reregisteredKey_hasNoZombiePending() public {
        registry.proposeDeregisterReserve(usdcKey);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        registry.executeDeregisterReserve(usdcKey);

        address restored = registry.registerReserve(address(spoke), USDC_RESERVE_ID);
        assertEq(restored, usdcKey);
        assertEq(registry.pendingDeregistrations(usdcKey), 0, "no pending survives re-registration");
        vm.expectRevert(AaveV4ReserveRegistry.DEREGISTRATION_NOT_PENDING.selector);
        registry.executeDeregisterReserve(usdcKey);
    }

    /// @notice All four registry events fire with the expected payloads
    function test_registry_events() public {
        address key42 = registry.computeReserveKey(address(spoke), 42);
        spoke.setReserve(42, makeAddr("token42"), 18);

        vm.expectEmit(true, true, true, true);
        emit AaveV4ReserveRegistry.ReserveRegistered(key42, address(spoke), 42, makeAddr("token42"));
        registry.registerReserve(address(spoke), 42);

        vm.expectEmit(true, false, false, true);
        emit AaveV4ReserveRegistry.ReserveDeregistrationProposed(key42, block.timestamp + 2 days);
        registry.proposeDeregisterReserve(key42);

        vm.expectEmit(true, false, false, false);
        emit AaveV4ReserveRegistry.ReserveDeregistrationCancelled(key42);
        registry.cancelDeregisterReserve(key42);

        registry.proposeDeregisterReserve(key42);
        vm.warp(block.timestamp + 2 days);
        vm.expectEmit(true, false, false, false);
        emit AaveV4ReserveRegistry.ReserveDeregistered(key42);
        registry.executeDeregisterReserve(key42);
    }

    /*//////////////////////////////////////////////////////////////
                    FLAGS LIVENESS + PPS BOUNDARY
    //////////////////////////////////////////////////////////////*/

    /// @notice F3 (unit form): the oracles never gate on reserve flags — every view keeps
    ///         returning with paused|frozen flags set, so accounting reads survive pauses
    function test_views_liveUnderPausedFrozenFlags() public {
        spoke.setReserveFlags(USDC_RESERVE_ID, 0x03); // paused | frozen

        assertEq(debtOracle.decimals(usdcKey), 6);
        assertEq(debtOracle.getPricePerShare(usdcKey), 1e6);
        assertEq(debtOracle.getBalanceOfOwner(usdcKey, account1), 500e6);
        assertEq(debtOracle.getTVL(usdcKey), 1_000_000e6);
        assertEq(supplyOracle.getBalanceOfOwner(usdcKey, account1), 0);
        assertEq(supplyOracle.getTVL(usdcKey), 0);
    }

    /// @notice Pins the NatSpec claim: PPS works at decimals 77 and reverts (checked overflow)
    ///         at decimals 78
    function test_pps_decimalsOverflowBoundary() public {
        spoke.setReserve(77, makeAddr("token77"), 77);
        spoke.setReserve(78, makeAddr("token78"), 78);
        address key77 = registry.registerReserve(address(spoke), 77);
        address key78 = registry.registerReserve(address(spoke), 78);

        assertEq(debtOracle.getPricePerShare(key77), 10 ** 77);
        vm.expectRevert(); // Panic(0x11) checked-arithmetic overflow
        debtOracle.getPricePerShare(key78);
        vm.expectRevert();
        supplyOracle.getPricePerShare(key78);
    }
}
