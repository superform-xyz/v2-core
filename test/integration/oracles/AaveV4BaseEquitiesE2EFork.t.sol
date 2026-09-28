// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { AaveV4ReserveRegistry } from "../../../src/accounting/oracles/AaveV4ReserveRegistry.sol";
import { AaveV4DebtOracle } from "../../../src/accounting/oracles/AaveV4DebtOracle.sol";
import { AaveV4SupplyYieldSourceOracle } from "../../../src/accounting/oracles/AaveV4SupplyYieldSourceOracle.sol";
import { IAaveV4Spoke } from "../../../src/vendor/aave-v4/IAaveV4Spoke.sol";
import { SuperLedger } from "../../../src/accounting/SuperLedger.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";

/// @title AaveV4BaseEquitiesE2EFork
/// @author Superform Labs
/// @notice End-to-end coverage of BOTH Aave V4 oracles used TOGETHER against the live Base equities
///         market (aave-address-book `AaveV4Base`: MAG7 spoke, seven tokenized stocks at 8 decimals
///         plus USDC at 6). The Ethereum E2E suite proves each oracle in isolation and in sequence;
///         this file targets the aggregation hazards that only appear when a consumer reads the two
///         oracles side by side over one portfolio.
/// @dev THE CENTRAL HAZARD — one reserve key, two oracles. `AaveV4ReserveRegistry` derives a single
///      pseudo-address per `(spoke, reserveId)` pair, and BOTH oracles accept that same key. On a
///      lending reserve a user can hold a supply position AND a debt position simultaneously, so the
///      same `(key, user)` pair legitimately yields two different non-zero numbers with opposite
///      economic sign. Any consumer that iterates registered keys across both oracles and SUMS is
///      double counting. These tests pin the correct reading: net within a reserve, never add; and
///      never add across reserves whose underlyings differ (8-decimal equities vs 6-decimal USDC).
/// @dev LEDGER-LEVEL COLLISION — `BaseLedger` accumulators are keyed `(user, yieldSource)` ONLY, with
///      no `yieldSourceOracleId` component. Both oracle ids therefore address the SAME storage slot
///      for the same reserve key. `test_E2E_SharedKey_LedgerAccumulatorsCollide` demonstrates the
///      collision and `test_E2E_SeparateLedgers_NoCollision` demonstrates the mitigation, pinning the
///      operational rule for the future accounting-wiring phase. Inert today: every loan hook is
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

    AaveV4ReserveRegistry internal registry;
    AaveV4SupplyYieldSourceOracle internal supplyOracle;
    AaveV4DebtOracle internal debtOracle;
    address internal ledgerConfig;

    address[] internal keys; // index == reserveId

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), FORK_BLOCK);

        ledgerConfig = address(new SuperLedgerConfiguration());
        registry = new AaveV4ReserveRegistry(address(this));
        supplyOracle = new AaveV4SupplyYieldSourceOracle(ledgerConfig, address(registry));
        debtOracle = new AaveV4DebtOracle(ledgerConfig, address(registry));

        for (uint256 id; id < RESERVE_COUNT; ++id) {
            keys.push(registry.registerReserve(MAG7_SPOKE, id));
        }
    }

    /*//////////////////////////////////////////////////////////////
              A. ONE KEY, TWO ORACLES — THE DOUBLE-COUNT SURFACE
    //////////////////////////////////////////////////////////////*/

    /// @notice The same reserve key returns a supply figure AND a debt figure for the SAME user, because
    ///         the borrower both supplies and borrows USDC. They are independent quantities with opposite
    ///         economic sign: a consumer must NET them, never add them.
    function test_E2E_SharedKey_SupplyAndDebtAreIndependent() public view {
        uint256 supplied = supplyOracle.getBalanceOfOwner(keys[USDC_ID], BORROWER);
        uint256 debt = debtOracle.getBalanceOfOwner(keys[USDC_ID], BORROWER);

        assertGt(supplied, 0, "live USDC supply leg");
        assertGt(debt, 0, "live USDC debt leg");
        assertTrue(supplied != debt, "two distinct quantities from one key");

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

    /// @notice Both oracles expose identity PPS for the same key, so neither rescales the other's units.
    ///         Identity makes netting within a reserve valid; it does NOT make cross-reserve addition valid.
    function test_E2E_SharedKey_IdentityPpsOnBothSides() public view {
        assertEq(supplyOracle.getPricePerShare(keys[USDC_ID]), 1e6);
        assertEq(debtOracle.getPricePerShare(keys[USDC_ID]), 1e6);
        assertEq(supplyOracle.decimals(keys[USDC_ID]), debtOracle.decimals(keys[USDC_ID]));

        // the equity leg is a different asset at a different scale
        assertEq(supplyOracle.getPricePerShare(keys[TSLA_ID]), 1e8);
        assertEq(supplyOracle.decimals(keys[TSLA_ID]), 8);
    }

    /// @notice Equity reserves carry supply only. Every equity key reads zero debt for both live users, so
    ///         a portfolio sweep over all keys × both oracles produces exactly one debt entry, not eight.
    function test_E2E_EquityKeys_SupplyOnly_NoPhantomDebt() public view {
        uint256 debtEntries;
        uint256 supplyEntries;
        for (uint256 id; id < RESERVE_COUNT; ++id) {
            uint256 s = supplyOracle.getBalanceOfOwner(keys[id], BORROWER);
            uint256 d = debtOracle.getBalanceOfOwner(keys[id], BORROWER);
            if (s != 0) ++supplyEntries;
            if (d != 0) ++debtEntries;
            if (id != USDC_ID) assertEq(d, 0, "equity reserves are collateral-only");
        }
        assertEq(debtEntries, 1, "exactly one debt leg across the whole portfolio");
        assertEq(supplyEntries, RESERVE_COUNT, "supplied in every reserve");
    }

    /// @notice Reserve-level TVL is NOT additive across the two oracles: debt is drawn out of the same
    ///         supplied pool the supply oracle reports, so adding them counts the borrowed portion twice.
    function test_E2E_ReserveTVL_NotAdditiveAcrossOracles() public view {
        uint256 suppliedTvl = supplyOracle.getTVL(keys[USDC_ID]);
        uint256 debtTvl = debtOracle.getTVL(keys[USDC_ID]);
        assertGt(suppliedTvl, 0);
        assertGt(debtTvl, 0);
        assertLt(debtTvl, suppliedTvl, "borrowed is a subset of supplied on this reserve");

        // equities: supplied only, so their debt TVL contributes nothing to a portfolio roll-up
        assertGt(supplyOracle.getTVL(keys[AAPL_ID]), 0);
        assertEq(debtOracle.getTVL(keys[AAPL_ID]), 0);
    }

    /// @notice Batch views on both oracles line up index-for-index with single calls across all eight keys,
    ///         so a batched portfolio read cannot drift or duplicate an entry.
    function test_E2E_BatchViews_BothOracles_MatchSingleCalls() public view {
        address[] memory allKeys = new address[](RESERVE_COUNT);
        address[][] memory owners = new address[][](RESERVE_COUNT);
        for (uint256 i; i < RESERVE_COUNT; ++i) {
            allKeys[i] = keys[i];
            owners[i] = new address[](1);
            owners[i][0] = BORROWER;
        }

        (uint256[][] memory supplyBatch, bool[][] memory supplyOk) =
            supplyOracle.getTVLByOwnerOfSharesMultiple(allKeys, owners);
        (uint256[][] memory debtBatch, bool[][] memory debtOk) =
            debtOracle.getTVLByOwnerOfSharesMultiple(allKeys, owners);
        uint256[] memory supplyPps = supplyOracle.getPricePerShareMultiple(allKeys);

        for (uint256 i; i < RESERVE_COUNT; ++i) {
            assertTrue(supplyOk[i][0] && debtOk[i][0], "every registered key resolves on both oracles");
            assertEq(supplyBatch[i][0], supplyOracle.getBalanceOfOwner(keys[i], BORROWER), "supply batch parity");
            assertEq(debtBatch[i][0], debtOracle.getBalanceOfOwner(keys[i], BORROWER), "debt batch parity");
            assertEq(supplyPps[i], i == USDC_ID ? 1e6 : 1e8, "per-key decimals preserved in batch");
        }
    }

    /*//////////////////////////////////////////////////////////////
              B. LEDGER COLLISION — THE REAL DOUBLE COUNT
    //////////////////////////////////////////////////////////////*/

    /// @notice DEMONSTRATION (mirrors the T1 feePercent-misconfiguration test's shape): `BaseLedger`
    ///         accumulators are keyed `(user, yieldSource)` with NO oracle-id component, so registering
    ///         BOTH oracle ids against the SAME ledger and driving both for one reserve key sums the
    ///         supply and debt legs into a single slot. This is the concrete double count to avoid when
    ///         the accounting-wiring phase lands.
    function test_E2E_SharedKey_LedgerAccumulatorsCollide() public {
        address[] memory executors = new address[](1);
        executors[0] = address(this);
        SuperLedger ledger = new SuperLedger(ledgerConfig, executors);
        (bytes32 supplyId, bytes32 debtId) = _registerBothOracles(address(ledger), address(ledger));

        address user = makeAddr("collisionUser");
        uint256 supplyLeg = 1000e6;
        uint256 debtLeg = 400e6;

        ledger.updateAccounting(user, keys[USDC_ID], supplyId, true, supplyLeg, 0);
        assertEq(ledger.usersAccumulatorShares(user, keys[USDC_ID]), supplyLeg, "supply leg recorded");

        ledger.updateAccounting(user, keys[USDC_ID], debtId, true, debtLeg, 0);
        assertEq(
            ledger.usersAccumulatorShares(user, keys[USDC_ID]),
            supplyLeg + debtLeg,
            "COLLISION: the debt leg lands in the same slot as the supply leg"
        );
        assertEq(
            ledger.usersAccumulatorCostBasis(user, keys[USDC_ID]),
            supplyLeg + debtLeg,
            "cost basis is summed too (identity PPS at 6 decimals)"
        );
    }

    /// @notice MITIGATION: one ledger per side keeps the accumulators independent for the same reserve key.
    ///         Equivalent and simpler alternative: never register both ids for the same key at all.
    function test_E2E_SeparateLedgers_NoCollision() public {
        address[] memory executors = new address[](1);
        executors[0] = address(this);
        SuperLedger supplyLedger = new SuperLedger(ledgerConfig, executors);
        SuperLedger debtLedger = new SuperLedger(ledgerConfig, executors);
        (bytes32 supplyId, bytes32 debtId) = _registerBothOracles(address(supplyLedger), address(debtLedger));

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
        (bytes32 supplyId,) = _registerBothOracles(address(ledger), address(ledger));

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
    ///         borrow USDC. Each leg moves only its own oracle — supplying never moves debt, borrowing never
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

        assertApproxEqAbs(supplyOracle.getBalanceOfOwner(keys[AAPL_ID], user), supplied, 1, "supply leg tracked");
        assertEq(debtOracle.getBalanceOfOwner(keys[AAPL_ID], user), 0, "supplying created no debt");
        assertEq(debtOracle.getBalanceOfOwner(keys[USDC_ID], user), 0, "no USDC debt yet");

        // --- borrow leg ---
        uint256 borrowAmount = 10e6; // 10 USDC
        uint256 supplyBeforeBorrow = supplyOracle.getBalanceOfOwner(keys[AAPL_ID], user);
        vm.prank(user);
        IAaveV4Spoke(MAG7_SPOKE).borrow(USDC_ID, borrowAmount, user);

        assertApproxEqAbs(debtOracle.getBalanceOfOwner(keys[USDC_ID], user), borrowAmount, 1, "debt leg tracked");
        assertEq(
            supplyOracle.getBalanceOfOwner(keys[AAPL_ID], user), supplyBeforeBorrow, "borrowing did not move supply"
        );
        assertEq(supplyOracle.getBalanceOfOwner(keys[USDC_ID], user), 0, "borrowed USDC is not a supply position");

        // --- partial repay moves debt only ---
        uint256 repay = 4e6;
        deal(USDC, user, repay);
        vm.startPrank(user);
        IERC20(USDC).approve(MAG7_SPOKE, repay);
        (, uint256 repaid) = IAaveV4Spoke(MAG7_SPOKE).repay(USDC_ID, repay, user);
        vm.stopPrank();

        assertApproxEqAbs(
            debtOracle.getBalanceOfOwner(keys[USDC_ID], user), borrowAmount - repaid, 1, "debt fell by the repayment"
        );
        assertEq(supplyOracle.getBalanceOfOwner(keys[AAPL_ID], user), supplyBeforeBorrow, "repay did not move supply");

        // --- partial withdraw moves supply only ---
        uint256 debtBeforeWithdraw = debtOracle.getBalanceOfOwner(keys[USDC_ID], user);
        vm.prank(user);
        (, uint256 withdrawn) = IAaveV4Spoke(MAG7_SPOKE).withdraw(AAPL_ID, 10e8, user);

        assertApproxEqAbs(
            supplyOracle.getBalanceOfOwner(keys[AAPL_ID], user),
            supplyBeforeBorrow - withdrawn,
            1,
            "supply fell by the withdrawal"
        );
        assertEq(debtOracle.getBalanceOfOwner(keys[USDC_ID], user), debtBeforeWithdraw, "withdraw did not move debt");
    }

    /// @notice Accrual is one-sided: warping time grows the USDC debt leg while the equity supply leg of the
    ///         same live position is untouched, so a portfolio snapshot taken later cannot mistake interest
    ///         on one side for growth on the other.
    function test_E2E_Accrual_IsOneSided() public {
        uint256 equityBefore = supplyOracle.getBalanceOfOwner(keys[TSLA_ID], BORROWER);
        uint256 debtBefore = debtOracle.getBalanceOfOwner(keys[USDC_ID], BORROWER);

        vm.warp(block.timestamp + 90 days);

        assertGt(debtOracle.getBalanceOfOwner(keys[USDC_ID], BORROWER), debtBefore, "debt accrued");
        assertEq(
            supplyOracle.getBalanceOfOwner(keys[TSLA_ID], BORROWER),
            equityBefore,
            "equity collateral did not accrue: nothing is borrowed against that reserve"
        );
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Registers both oracles in SuperLedgerConfiguration, each against the given ledger, and returns
    ///      their yieldSourceOracleIds. feePercent = 0 on both — the documented operational invariant.
    function _registerBothOracles(
        address supplyLedger,
        address debtLedger
    )
        internal
        returns (bytes32 supplyId, bytes32 debtId)
    {
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](2);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(supplyOracle),
            feePercent: 0,
            feeRecipient: makeAddr("feeRecipient"),
            ledger: supplyLedger
        });
        configs[1] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(debtOracle),
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

    /// @dev Replaces the node-native equity token with a standard ERC20 so transfer legs execute in-fork,
    ///      and funds the pool holders so withdrawals can pay out.
    function _etchEquityToken() internal {
        MockERC20 mock = new MockERC20("Apple Inc.", "AAPLc", 8);
        vm.etch(AAPLc, address(mock).code);
        deal(AAPLc, MAG7_SPOKE, 1_000_000e8);
        deal(AAPLc, EQUITIES_HUB, 1_000_000e8);
    }
}
