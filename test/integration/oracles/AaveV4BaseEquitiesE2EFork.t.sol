// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { AaveV4ReserveRegistryV2 } from "../../../src/accounting/oracles/AaveV4ReserveRegistryV2.sol";
import { AaveV4ReserveOracle } from "../../../src/accounting/oracles/AaveV4ReserveOracle.sol";
import { SuperYieldSourceOracle } from "../../../src/accounting/oracles/SuperYieldSourceOracle.sol";
import { IAaveV4Spoke } from "../../../src/vendor/aave-v4/IAaveV4Spoke.sol";
import { SuperLedger } from "../../../src/accounting/SuperLedger.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";

/// @title AaveV4BaseEquitiesE2EFork
/// @author Superform Labs
/// @notice End-to-end coverage of BOTH legs of the Aave V4 reserve oracle used TOGETHER against the
///         live Base equities market (aave-address-book `AaveV4Base`: MAG7 spoke, seven tokenized
///         stocks at 8 decimals plus USDC at 6). The Ethereum E2E suite proves each leg in isolation
///         and in sequence; this file targets the aggregation hazards that only appear when a consumer
///         reads the two legs side by side over one portfolio.
/// @dev THE CENTRAL HAZARD — two reserve keys, one oracle. `AaveV4ReserveRegistryV2` derives a SUPPLY key
///      and a DEBT key per `(spoke, reserveId)` pair, and the single `AaveV4ReserveOracle` serves both,
///      branching on the side bound into the key. On a lending reserve a user can hold a supply position
///      AND a debt position simultaneously, so the two sibling keys of one reserve legitimately yield two
///      different non-zero numbers with opposite economic sign. Any consumer that iterates registered
///      keys and SUMS is double counting. These tests pin the correct reading: net the two legs within a
///      reserve, never add; and never add across reserves whose underlyings differ (8-decimal equities vs
///      6-decimal USDC).
/// @dev LEDGER-LEVEL COLLISION — `BaseLedger` accumulators are keyed `(user, yieldSource)` ONLY, with
///      no `yieldSourceOracleId` component. Binding the side into the key is what keeps the two legs of
///      one reserve in separate slots: `test_E2E_SeparateKeys_LedgerAccumulatorsDoNotCollide` pins that,
///      and also pins what still breaks if an operator drives the debt leg at the SUPPLY key (the
///      pre-merge shape of the bug). `test_E2E_SeparateLedgers_NoCollision` keeps the second line of
///      defence on record for the future accounting-wiring phase. Inert today: every loan hook is
///      NONACCOUNTING, so nothing drives `updateAccounting` for these positions.
contract AaveV4BaseEquitiesE2EFork is Test {
    // aave-address-book AaveV4Base.sol
    address internal constant MAG7_SPOKE = 0x17905Db0e4A3514467539956c084180616AE7B8D;
    address internal constant EQUITIES_HUB = 0xa4d5947Eb727A052bae69C593FfC84247EC9864E;
    address internal constant AAPLc = 0xb200000000000000000000C2e324d24d7eEcd1fb;
    address internal constant TSLAc = 0xb2000000000000000000001e800a7f5189430cD0;
    address internal constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    uint256 internal constant AAPL_ID = 0;
    uint256 internal constant TSLA_ID = 6;
    uint256 internal constant USDC_ID = 7;
    uint256 internal constant RESERVE_COUNT = 8;

    /// @dev live positions at the pinned block
    address internal constant BORROWER = 0x26D595DdDbAd81Bf976eF6f24686a12A800b141F; // equities + USDC supply + USDC
    // debt
    address internal constant WHALE = 0x9e3787f9f7f0fF7Eea9e36628BecA431B61AE647; // equities + USDC supply, no debt

    uint256 internal constant FORK_BLOCK = 51_778_000;

    AaveV4ReserveRegistryV2 internal registry;
    AaveV4ReserveOracle internal oracle;
    address internal ledgerConfig;

    address[] internal keys; // SUPPLY keys, index == reserveId
    address[] internal debtKeys; // DEBT keys, index == reserveId

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), FORK_BLOCK);

        ledgerConfig = address(new SuperLedgerConfiguration());
        registry = new AaveV4ReserveRegistryV2(address(this));
        oracle = new AaveV4ReserveOracle(ledgerConfig, address(registry));

        for (uint256 id; id < RESERVE_COUNT; ++id) {
            (address supplyKey, address debtKey) = registry.registerReserve(MAG7_SPOKE, id);
            keys.push(supplyKey);
            debtKeys.push(debtKey);
        }
    }

    /*//////////////////////////////////////////////////////////////
              A. TWO KEYS, ONE ORACLE — THE DOUBLE-COUNT SURFACE
    //////////////////////////////////////////////////////////////*/

    /// @notice The two sibling keys of one reserve return a supply figure AND a debt figure for the SAME
    ///         user, because the borrower both supplies and borrows USDC. They are independent quantities
    ///         with opposite economic sign: a consumer must NET them, never add them.
    function test_E2E_SiblingKeys_SupplyAndDebtAreIndependent() public view {
        uint256 supplied = oracle.getBalanceOfOwner(keys[USDC_ID], BORROWER);
        uint256 debt = oracle.getBalanceOfOwner(debtKeys[USDC_ID], BORROWER);

        assertGt(supplied, 0, "live USDC supply leg");
        assertGt(debt, 0, "live USDC debt leg");
        assertTrue(supplied != debt, "two distinct quantities from the two keys of one reserve");

        // each matches its own spoke view, so neither leaks into the other
        assertEq(supplied, IAaveV4Spoke(MAG7_SPOKE).getUserSuppliedAssets(USDC_ID, BORROWER));
        (uint256 drawn, uint256 premium) = IAaveV4Spoke(MAG7_SPOKE).getUserDebt(USDC_ID, BORROWER);
        assertEq(debt, drawn + premium);

        // the naive aggregate a portfolio reader might compute, and the correct one
        uint256 naiveSum = supplied + debt;
        assertTrue(debt > supplied, "this borrower is net short USDC at the pinned block");
        uint256 netShort = debt - supplied;
        assertTrue(naiveSum != netShort, "summing the two legs is NOT the position");
        assertEq(naiveSum - netShort, 2 * supplied, "the sum double counts the supply leg exactly twice");
    }

    /// @notice Both legs expose identity PPS for one reserve, so neither rescales the other's units.
    ///         Identity makes netting within a reserve valid; it does NOT make cross-reserve addition valid.
    function test_E2E_SiblingKeys_IdentityPpsOnBothSides() public view {
        assertEq(oracle.getPricePerShare(keys[USDC_ID]), 1e6);
        assertEq(oracle.getPricePerShare(debtKeys[USDC_ID]), 1e6);
        assertEq(oracle.decimals(keys[USDC_ID]), oracle.decimals(debtKeys[USDC_ID]));

        // the equity leg is a different asset at a different scale
        assertEq(oracle.getPricePerShare(keys[TSLA_ID]), 1e8);
        assertEq(oracle.decimals(keys[TSLA_ID]), 8);
    }

    /// @notice Equity reserves carry supply only. Every equity debt key reads zero for both live users, so
    ///         a portfolio sweep over all registered keys produces exactly one debt entry, not eight.
    function test_E2E_EquityKeys_SupplyOnly_NoPhantomDebt() public view {
        uint256 debtEntries;
        uint256 supplyEntries;
        for (uint256 id; id < RESERVE_COUNT; ++id) {
            uint256 s = oracle.getBalanceOfOwner(keys[id], BORROWER);
            uint256 d = oracle.getBalanceOfOwner(debtKeys[id], BORROWER);
            if (s != 0) ++supplyEntries;
            if (d != 0) ++debtEntries;
            if (id != USDC_ID) assertEq(d, 0, "equity reserves are collateral-only");
        }
        assertEq(debtEntries, 1, "exactly one debt leg across the whole portfolio");
        assertEq(supplyEntries, RESERVE_COUNT, "supplied in every reserve");
    }

    /// @notice Reserve-level TVL is NOT additive across the two legs: debt is drawn out of the same
    ///         supplied pool the supply key reports, so adding them counts the borrowed portion twice.
    function test_E2E_ReserveTVL_NotAdditiveAcrossLegs() public view {
        uint256 suppliedTvl = oracle.getTVL(keys[USDC_ID]);
        uint256 debtTvl = oracle.getTVL(debtKeys[USDC_ID]);
        assertGt(suppliedTvl, 0);
        assertGt(debtTvl, 0);
        assertLt(debtTvl, suppliedTvl, "borrowed is a subset of supplied on this reserve");

        // equities: supplied only, so their debt TVL contributes nothing to a portfolio roll-up
        assertGt(oracle.getTVL(keys[AAPL_ID]), 0);
        assertEq(oracle.getTVL(debtKeys[AAPL_ID]), 0);
    }

    /// @notice Batch views line up index-for-index with single calls across all eight supply keys and all
    ///         eight debt keys, so a batched portfolio read cannot drift or duplicate an entry.
    function test_E2E_BatchViews_BothLegs_MatchSingleCalls() public view {
        address[] memory allKeys = new address[](RESERVE_COUNT);
        address[] memory allDebtKeys = new address[](RESERVE_COUNT);
        address[][] memory owners = new address[][](RESERVE_COUNT);
        for (uint256 i; i < RESERVE_COUNT; ++i) {
            allKeys[i] = keys[i];
            allDebtKeys[i] = debtKeys[i];
            owners[i] = new address[](1);
            owners[i][0] = BORROWER;
        }

        (uint256[][] memory supplyBatch, bool[][] memory supplyOk) =
            oracle.getTVLByOwnerOfSharesMultiple(allKeys, owners);
        (uint256[][] memory debtBatch, bool[][] memory debtOk) =
            oracle.getTVLByOwnerOfSharesMultiple(allDebtKeys, owners);
        uint256[] memory supplyPps = oracle.getPricePerShareMultiple(allKeys);

        for (uint256 i; i < RESERVE_COUNT; ++i) {
            assertTrue(supplyOk[i][0] && debtOk[i][0], "every registered key resolves on both legs");
            assertEq(supplyBatch[i][0], oracle.getBalanceOfOwner(keys[i], BORROWER), "supply batch parity");
            assertEq(debtBatch[i][0], oracle.getBalanceOfOwner(debtKeys[i], BORROWER), "debt batch parity");
            assertEq(supplyPps[i], i == USDC_ID ? 1e6 : 1e8, "per-key decimals preserved in batch");
        }
    }

    /*//////////////////////////////////////////////////////////////
            B. LEDGER SLOTS — THE REAL DOUBLE COUNT, AND ITS FIX
    //////////////////////////////////////////////////////////////*/

    /// @notice `BaseLedger` accumulators are keyed `(user, yieldSource)` with NO oracle-id component, so
    ///         the ONLY thing separating the two legs of one reserve in ledger storage is the key itself.
    ///         Binding the side into the key supplies exactly that: driving both legs on the SAME ledger
    ///         lands them in two slots. The second half pins the pre-merge shape of the bug — route the
    ///         debt leg at the SUPPLY key and the legs still sum into one slot, because the ledger cannot
    ///         tell the two oracle ids apart. This is the concrete double count to avoid when the
    ///         accounting-wiring phase lands.
    function test_E2E_SeparateKeys_LedgerAccumulatorsDoNotCollide() public {
        address[] memory executors = new address[](1);
        executors[0] = address(this);
        SuperLedger ledger = new SuperLedger(ledgerConfig, executors);
        (bytes32 supplyId, bytes32 debtId) = _registerBothLegs(address(ledger), address(ledger));

        address user = makeAddr("collisionUser");
        uint256 supplyLeg = 1000e6;
        uint256 debtLeg = 400e6;

        ledger.updateAccounting(user, keys[USDC_ID], supplyId, true, supplyLeg, 0);
        assertEq(ledger.usersAccumulatorShares(user, keys[USDC_ID]), supplyLeg, "supply leg recorded");

        ledger.updateAccounting(user, debtKeys[USDC_ID], debtId, true, debtLeg, 0);
        assertEq(ledger.usersAccumulatorShares(user, keys[USDC_ID]), supplyLeg, "supply slot untouched");
        assertEq(ledger.usersAccumulatorShares(user, debtKeys[USDC_ID]), debtLeg, "debt leg in its own slot");
        assertEq(
            ledger.usersAccumulatorCostBasis(user, debtKeys[USDC_ID]),
            debtLeg,
            "debt cost basis isolated too (identity PPS at 6 decimals)"
        );

        // the pre-merge failure mode: the ledger ignores the oracle id, so a debt leg mis-routed onto the
        // SUPPLY key still sums into the supply slot
        ledger.updateAccounting(user, keys[USDC_ID], debtId, true, debtLeg, 0);
        assertEq(
            ledger.usersAccumulatorShares(user, keys[USDC_ID]),
            supplyLeg + debtLeg,
            "COLLISION: only the per-leg key keeps the slots apart"
        );
    }

    /// @notice SECOND LINE OF DEFENCE: one ledger per side keeps the accumulators independent even when
    ///         both ids are driven at the same reserve key. The per-leg key is the primary mitigation.
    function test_E2E_SeparateLedgers_NoCollision() public {
        address[] memory executors = new address[](1);
        executors[0] = address(this);
        SuperLedger supplyLedger = new SuperLedger(ledgerConfig, executors);
        SuperLedger debtLedger = new SuperLedger(ledgerConfig, executors);
        (bytes32 supplyId, bytes32 debtId) = _registerBothLegs(address(supplyLedger), address(debtLedger));

        address user = makeAddr("separatedUser");
        supplyLedger.updateAccounting(user, keys[USDC_ID], supplyId, true, 1000e6, 0);
        debtLedger.updateAccounting(user, keys[USDC_ID], debtId, true, 400e6, 0);

        assertEq(supplyLedger.usersAccumulatorShares(user, keys[USDC_ID]), 1000e6, "supply leg isolated");
        assertEq(debtLedger.usersAccumulatorShares(user, keys[USDC_ID]), 400e6, "debt leg isolated");
    }

    /// @notice Distinct reserve keys never collide even on one ledger: the 8-decimal equity leg and the
    ///         6-decimal USDC leg of one leveraged position occupy separate slots and keep their own scale.
    function test_E2E_DistinctKeys_NoCollisionAcrossDecimals() public {
        address[] memory executors = new address[](1);
        executors[0] = address(this);
        SuperLedger ledger = new SuperLedger(ledgerConfig, executors);
        (bytes32 supplyId,) = _registerBothLegs(address(ledger), address(ledger));

        address user = makeAddr("mixedDecimalsUser");
        ledger.updateAccounting(user, keys[TSLA_ID], supplyId, true, 5e8, 0); // 5 TSLAc
        ledger.updateAccounting(user, keys[USDC_ID], supplyId, true, 5e6, 0); // 5 USDC

        assertEq(ledger.usersAccumulatorShares(user, keys[TSLA_ID]), 5e8, "equity slot at 8 decimals");
        assertEq(ledger.usersAccumulatorShares(user, keys[USDC_ID]), 5e6, "USDC slot at 6 decimals");
        assertEq(ledger.usersAccumulatorCostBasis(user, keys[TSLA_ID]), 5e8, "identity cost basis, 8dp");
        assertEq(ledger.usersAccumulatorCostBasis(user, keys[USDC_ID]), 5e6, "identity cost basis, 6dp");
    }

    /*//////////////////////////////////////////////////////////////
              C. LIVE LEVERAGED LIFECYCLE — NO CROSS-TALK
    //////////////////////////////////////////////////////////////*/

    /// @notice A real position built on the live spoke: supply an 8-decimal equity, enable it as collateral,
    ///         borrow USDC. Each leg moves only its own key — supplying never moves debt, borrowing never
    ///         moves supply — then a partial repay and a partial withdraw each move exactly one side.
    /// @dev The equity token is node-native on Base (1 byte of code, 0xEF), so a standard ERC20 is etched at
    ///      its address to make the transfer legs fork-executable. Spoke-internal accounting is untouched.
    function test_E2E_LeveragedLifecycle_LegsMoveIndependently() public {
        address user = makeAddr("leveragedUser");
        uint256 collateral = 100e8; // 100 AAPLc
        _etchEquityToken();
        deal(AAPLc, user, collateral);

        // --- supply leg ---
        vm.startPrank(user);
        IERC20(AAPLc).approve(MAG7_SPOKE, collateral);
        (, uint256 supplied) = IAaveV4Spoke(MAG7_SPOKE).supply(AAPL_ID, collateral, user);
        IAaveV4Spoke(MAG7_SPOKE).setUsingAsCollateral(AAPL_ID, true, user);
        vm.stopPrank();

        assertApproxEqAbs(oracle.getBalanceOfOwner(keys[AAPL_ID], user), supplied, 1, "supply leg tracked");
        assertEq(oracle.getBalanceOfOwner(debtKeys[AAPL_ID], user), 0, "supplying created no debt");
        assertEq(oracle.getBalanceOfOwner(debtKeys[USDC_ID], user), 0, "no USDC debt yet");

        // --- borrow leg ---
        uint256 borrowAmount = 10e6; // 10 USDC
        uint256 supplyBeforeBorrow = oracle.getBalanceOfOwner(keys[AAPL_ID], user);
        vm.prank(user);
        IAaveV4Spoke(MAG7_SPOKE).borrow(USDC_ID, borrowAmount, user);

        assertApproxEqAbs(oracle.getBalanceOfOwner(debtKeys[USDC_ID], user), borrowAmount, 1, "debt leg tracked");
        assertEq(oracle.getBalanceOfOwner(keys[AAPL_ID], user), supplyBeforeBorrow, "borrowing did not move supply");
        assertEq(oracle.getBalanceOfOwner(keys[USDC_ID], user), 0, "borrowed USDC is not a supply position");

        // --- partial repay moves debt only ---
        uint256 repay = 4e6;
        deal(USDC, user, repay);
        vm.startPrank(user);
        IERC20(USDC).approve(MAG7_SPOKE, repay);
        (, uint256 repaid) = IAaveV4Spoke(MAG7_SPOKE).repay(USDC_ID, repay, user);
        vm.stopPrank();

        assertApproxEqAbs(
            oracle.getBalanceOfOwner(debtKeys[USDC_ID], user), borrowAmount - repaid, 1, "debt fell by the repayment"
        );
        assertEq(oracle.getBalanceOfOwner(keys[AAPL_ID], user), supplyBeforeBorrow, "repay did not move supply");

        // --- partial withdraw moves supply only ---
        uint256 debtBeforeWithdraw = oracle.getBalanceOfOwner(debtKeys[USDC_ID], user);
        vm.prank(user);
        (, uint256 withdrawn) = IAaveV4Spoke(MAG7_SPOKE).withdraw(AAPL_ID, 10e8, user);

        assertApproxEqAbs(
            oracle.getBalanceOfOwner(keys[AAPL_ID], user),
            supplyBeforeBorrow - withdrawn,
            1,
            "supply fell by the withdrawal"
        );
        assertEq(oracle.getBalanceOfOwner(debtKeys[USDC_ID], user), debtBeforeWithdraw, "withdraw did not move debt");
    }

    /// @notice Accrual is one-sided: warping time grows the USDC debt leg while the equity supply leg of the
    ///         same live position is untouched, so a portfolio snapshot taken later cannot mistake interest
    ///         on one side for growth on the other.
    function test_E2E_Accrual_IsOneSided() public {
        uint256 equityBefore = oracle.getBalanceOfOwner(keys[TSLA_ID], BORROWER);
        uint256 debtBefore = oracle.getBalanceOfOwner(debtKeys[USDC_ID], BORROWER);

        vm.warp(block.timestamp + 90 days);

        assertGt(oracle.getBalanceOfOwner(debtKeys[USDC_ID], BORROWER), debtBefore, "debt accrued");
        assertEq(
            oracle.getBalanceOfOwner(keys[TSLA_ID], BORROWER),
            equityBefore,
            "equity collateral did not accrue: nothing is borrowed against that reserve"
        );
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Registers one config id per leg in SuperLedgerConfiguration — both pointing at the single
    ///      merged oracle — each against the given ledger, and returns their yieldSourceOracleIds.
    ///      feePercent = 0 on both — the documented operational invariant.
    function _registerBothLegs(
        address supplyLedger,
        address debtLedger
    )
        internal
        returns (bytes32 supplyId, bytes32 debtId)
    {
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](2);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle),
            feePercent: 0,
            feeRecipient: makeAddr("feeRecipient"),
            ledger: supplyLedger
        });
        configs[1] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle),
            feePercent: 0,
            feeRecipient: makeAddr("feeRecipient"),
            ledger: debtLedger
        });

        bytes32[] memory salts = new bytes32[](2);
        salts[0] = keccak256(abi.encodePacked("AAVE_V4_BASE_SUPPLY", supplyLedger, debtLedger));
        salts[1] = keccak256(abi.encodePacked("AAVE_V4_BASE_DEBT", supplyLedger, debtLedger));
        SuperLedgerConfiguration(ledgerConfig).setYieldSourceOracles(salts, configs);

        supplyId = keccak256(abi.encodePacked(salts[0], address(this)));
        debtId = keccak256(abi.encodePacked(salts[1], address(this)));
    }

    /*//////////////////////////////////////////////////////////////
       E. THE REAL CONSUMER PATH — SuperYieldSourceOracle AGGREGATOR
    //////////////////////////////////////////////////////////////*/

    /// @notice THE DESIGN PREMISE, pinned end to end. SuperVault PPS computation does not call this oracle
    ///         directly — it calls `SuperYieldSourceOracle.getTVLByOwnerOfSharesMultiple(sources, oracles,
    ///         owners)`, whose loop is
    ///         `IYieldSourceOracle(oracles[i]).getTVLByOwnerOfShares(sources[i], owners[i])`. That call is
    ///         SIDELESS: there is no parameter in which to say "this entry is the debt leg". Before the
    ///         merge the leg was disambiguated by the per-entry ORACLE ADDRESS (two oracle contracts, one
    ///         key). This test pins the replacement: ONE oracle address appears in both entries and the
    ///         legs are told apart purely by the key, against the live Base equities market.
    function test_E2E_Aggregator_OneOracleAddress_TwoKeys_ResolvesBothLegs() public {
        SuperYieldSourceOracle aggregator = new SuperYieldSourceOracle();

        address[] memory sources = new address[](2);
        sources[0] = keys[USDC_ID]; // SUPPLY leg
        sources[1] = debtKeys[USDC_ID]; // DEBT leg, same reserve

        address[] memory oracles = new address[](2);
        oracles[0] = address(oracle);
        oracles[1] = address(oracle); // the SAME address — this is what the merge changed
        assertEq(oracles[0], oracles[1], "one oracle serves both legs");

        address[] memory owners = new address[](2);
        owners[0] = BORROWER;
        owners[1] = BORROWER;

        uint256[] memory tvls = aggregator.getTVLByOwnerOfSharesMultiple(sources, oracles, owners);

        // Each entry resolved to its own leg, not to whichever the oracle "defaults" to
        assertEq(tvls[0], oracle.getBalanceOfOwner(keys[USDC_ID], BORROWER), "supply leg via aggregator");
        assertEq(tvls[1], oracle.getBalanceOfOwner(debtKeys[USDC_ID], BORROWER), "debt leg via aggregator");
        assertGt(tvls[0], 0, "live supply");
        assertGt(tvls[1], 0, "live debt");
        assertTrue(tvls[0] != tvls[1], "the two legs are distinct through one oracle address");

        // And each still agrees with the raw spoke, so the aggregator hop introduced no drift
        assertEq(tvls[0], IAaveV4Spoke(MAG7_SPOKE).getUserSuppliedAssets(USDC_ID, BORROWER));
        (uint256 drawn, uint256 premium) = IAaveV4Spoke(MAG7_SPOKE).getUserDebt(USDC_ID, BORROWER);
        assertEq(tvls[1], drawn + premium);
    }

    /// @notice A full 16-entry portfolio sweep (8 reserves x 2 legs) through ONE aggregator call against
    ///         one oracle address — the realistic SuperVault pricing shape. Exactly one debt entry is
    ///         non-zero (USDC); the seven tokenized stocks are collateral-only.
    function test_E2E_Aggregator_FullPortfolioSweep_StocksAreCollateralOnly() public {
        SuperYieldSourceOracle aggregator = new SuperYieldSourceOracle();

        uint256 n = RESERVE_COUNT * 2;
        address[] memory sources = new address[](n);
        address[] memory oracles = new address[](n);
        address[] memory owners = new address[](n);
        for (uint256 id; id < RESERVE_COUNT; ++id) {
            sources[id] = keys[id];
            sources[RESERVE_COUNT + id] = debtKeys[id];
            oracles[id] = address(oracle);
            oracles[RESERVE_COUNT + id] = address(oracle);
            owners[id] = BORROWER;
            owners[RESERVE_COUNT + id] = BORROWER;
        }

        uint256[] memory tvls = aggregator.getTVLByOwnerOfSharesMultiple(sources, oracles, owners);

        uint256 nonZeroDebtEntries;
        for (uint256 id; id < RESERVE_COUNT; ++id) {
            assertGt(tvls[id], 0, "supplied in every reserve, including every stock");
            uint256 debtEntry = tvls[RESERVE_COUNT + id];
            if (debtEntry != 0) ++nonZeroDebtEntries;
            if (id != USDC_ID) assertEq(debtEntry, 0, "tokenized stock reserves carry no debt");
        }
        assertEq(nonZeroDebtEntries, 1, "one debt leg across a 16-entry sweep");

        // The naive thing a pricing consumer must NOT do: sum all 16 entries. Kept explicit so the
        // double-count stays visible at the aggregator level, not just the per-key level.
        uint256 naiveTotal;
        for (uint256 i; i < n; ++i) {
            naiveTotal += tvls[i];
        }
        uint256 suppliedUsdc = tvls[USDC_ID];
        uint256 debtUsdc = tvls[RESERVE_COUNT + USDC_ID];
        assertTrue(naiveTotal > suppliedUsdc + debtUsdc, "mixes 8-decimal equities with 6-decimal USDC");
        assertTrue(debtUsdc > suppliedUsdc, "borrower is net short USDC at the pinned block");
    }

    /// @notice A WHALE with no debt reads zero on every debt key through the aggregator — the side
    ///         discriminator does not invent a position where none exists.
    function test_E2E_Aggregator_NoDebtUser_AllDebtKeysZero() public {
        SuperYieldSourceOracle aggregator = new SuperYieldSourceOracle();

        address[] memory sources = new address[](RESERVE_COUNT);
        address[] memory oracles = new address[](RESERVE_COUNT);
        address[] memory owners = new address[](RESERVE_COUNT);
        for (uint256 id; id < RESERVE_COUNT; ++id) {
            sources[id] = debtKeys[id];
            oracles[id] = address(oracle);
            owners[id] = WHALE;
        }

        uint256[] memory tvls = aggregator.getTVLByOwnerOfSharesMultiple(sources, oracles, owners);
        for (uint256 id; id < RESERVE_COUNT; ++id) {
            assertEq(tvls[id], 0, "whale holds no debt on any leg");
        }
        // ...while its supply legs are non-zero through the same oracle address
        assertGt(oracle.getBalanceOfOwner(keys[USDC_ID], WHALE), 0, "whale does supply");
    }

    /// @notice Reserve-level TVL through the aggregator resolves per leg too: `getTVLMultiple` over one
    ///         oracle address returns total supplied for the supply key and total borrows for the debt key.
    function test_E2E_Aggregator_GetTVLMultiple_PerLegReserveTotals() public {
        SuperYieldSourceOracle aggregator = new SuperYieldSourceOracle();

        address[] memory sources = new address[](2);
        sources[0] = keys[USDC_ID];
        sources[1] = debtKeys[USDC_ID];
        address[] memory oracles = new address[](2);
        oracles[0] = address(oracle);
        oracles[1] = address(oracle);

        uint256[] memory tvls = aggregator.getTVLMultiple(sources, oracles);

        assertEq(tvls[0], IAaveV4Spoke(MAG7_SPOKE).getReserveSuppliedAssets(USDC_ID), "total supplied");
        (uint256 drawn, uint256 premium) = IAaveV4Spoke(MAG7_SPOKE).getReserveDebt(USDC_ID);
        assertEq(tvls[1], drawn + premium, "total borrows");
        assertGt(tvls[0], tvls[1], "a healthy reserve supplies more than it lends out");
    }

    /// @dev Replaces the node-native equity token with a standard ERC20 so transfer legs execute in-fork,
    ///      and funds the pool holders so withdrawals can pay out.
    function _etchEquityToken() internal {
        MockERC20 mock = new MockERC20("Apple Inc.", "AAPLc", 8);
        vm.etch(AAPLc, address(mock).code);
        deal(AAPLc, MAG7_SPOKE, 1_000_000e8);
        deal(AAPLc, EQUITIES_HUB, 1_000_000e8);
    }
}
