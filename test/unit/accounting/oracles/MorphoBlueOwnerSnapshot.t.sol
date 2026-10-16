// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

import { MorphoBlueYieldSourceOracle } from "../../../../src/accounting/oracles/MorphoBlueYieldSourceOracle.sol";
import { MorphoBlueDebtOracle } from "../../../../src/accounting/oracles/MorphoBlueDebtOracle.sol";
import { MorphoBlueMarketRegistry } from "../../../../src/accounting/oracles/MorphoBlueMarketRegistry.sol";
import { IMorphoMarketPosition } from "../../../../src/interfaces/accounting/IMorphoMarketPosition.sol";
import { IMorphoOwnerSnapshot } from "../../../../src/interfaces/accounting/IMorphoOwnerSnapshot.sol";
import { SuperLedgerConfiguration } from "../../../../src/accounting/SuperLedgerConfiguration.sol";
import { IMorphoStaticTyping, MarketParams, Id } from "../../../../src/vendor/morpho/IMorpho.sol";
import { MarketParamsLib } from "../../../../src/vendor/morpho/MarketParamsLib.sol";
import { SharesMathLib } from "../../../../src/vendor/morpho/SharesMathLib.sol";
import { IIrm } from "../../../../src/vendor/morpho/IIrm.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @notice Unit tests for the Morpho market/owner snapshot API (SUP-21477) added to the lending oracle.
contract MorphoBlueOwnerSnapshotTest is Test {
    using MarketParamsLib for MarketParams;
    using SharesMathLib for uint256;

    MorphoBlueYieldSourceOracle public oracle;
    address public ledgerConfig;
    address public registry;

    address public morpho = makeAddr("morpho");
    address public loan6 = makeAddr("usdc"); // 6-decimal loan token
    address public loan18 = makeAddr("weth"); // 18-decimal loan token
    address public collateral = makeAddr("collateral"); // 18-decimal collateral token
    address public mockOracle = makeAddr("oracle");
    address public mockOracle2 = makeAddr("oracle2");
    address public irm = makeAddr("irm");

    address public lender = makeAddr("lender");
    address public borrower = makeAddr("borrower"); // zero-lending borrower
    address public both = makeAddr("both"); // simultaneous lend + borrow
    address public empty = makeAddr("empty"); // no position at all

    // Markets: A and B share loan6 (distinct via oracle addr); C is lending-only (collateralToken == 0).
    MarketParams public mpA;
    MarketParams public mpB;
    MarketParams public mpC;
    address public keyA;
    address public keyB;
    address public keyC;

    uint128 constant SUP_ASSETS_6 = 10_000_000e6;
    uint128 constant SUP_SHARES_6 = 10_000_000e12; // +6 virtual-offset decimals
    uint128 constant BOR_ASSETS_6 = 5_000_000e6;
    uint128 constant BOR_SHARES_6 = 5_000_000e12;

    uint128 constant SUP_ASSETS_18 = 50_000 ether;
    uint128 constant SUP_SHARES_18 = 50_000e24;
    uint128 constant BOR_ASSETS_18 = 25_000 ether;
    uint128 constant BOR_SHARES_18 = 25_000e24;

    uint256 constant LLTV = 0.86e18;

    function setUp() public {
        vm.warp(365 days * 2);

        ledgerConfig = address(new SuperLedgerConfiguration());
        registry = address(new MorphoBlueMarketRegistry(address(this)));
        MorphoBlueMarketRegistry(registry).setIrmApproval(irm, true);

        mpA = MarketParams(loan6, collateral, mockOracle, irm, LLTV);
        mpB = MarketParams(loan6, collateral, mockOracle2, irm, LLTV); // same loan token, distinct market
        mpC = MarketParams(loan18, address(0), mockOracle, irm, LLTV); // lending-only market

        vm.mockCall(loan6, abi.encodeCall(IERC20Metadata.decimals, ()), abi.encode(uint8(6)));
        vm.mockCall(loan18, abi.encodeCall(IERC20Metadata.decimals, ()), abi.encode(uint8(18)));
        vm.mockCall(collateral, abi.encodeCall(IERC20Metadata.decimals, ()), abi.encode(uint8(18)));

        _mockIdToParams(mpA);
        _mockIdToParams(mpB);
        _mockIdToParams(mpC);

        keyA = MorphoBlueMarketRegistry(registry).registerMarket(morpho, loan6, collateral, mockOracle, irm, LLTV);
        keyB = MorphoBlueMarketRegistry(registry).registerMarket(morpho, loan6, collateral, mockOracle2, irm, LLTV);
        keyC = MorphoBlueMarketRegistry(registry).registerMarket(morpho, loan18, address(0), mockOracle, irm, LLTV);

        oracle = new MorphoBlueYieldSourceOracle(ledgerConfig, registry);

        // No accrual by default: lastUpdate == now.
        _mockMarket(mpA.id(), SUP_ASSETS_6, SUP_SHARES_6, BOR_ASSETS_6, BOR_SHARES_6, block.timestamp);
        _mockMarket(mpB.id(), SUP_ASSETS_6, SUP_SHARES_6, BOR_ASSETS_6, BOR_SHARES_6, block.timestamp);
        _mockMarket(mpC.id(), SUP_ASSETS_18, SUP_SHARES_18, BOR_ASSETS_18, BOR_SHARES_18, block.timestamp);

        // Positions (supplyShares, borrowShares, collateral):
        _mockPos(mpA.id(), lender, 1000e12, 0, 0); // pure lender
        _mockPos(mpA.id(), borrower, 0, 500e12, 7e18); // zero lending shares, has debt + collateral
        _mockPos(mpA.id(), both, 1000e12, 500e12, 7e18); // simultaneous
        _mockPos(mpA.id(), empty, 0, 0, 0); // nothing

        _mockPos(mpB.id(), borrower, 0, 300e12, 2e18); // same loan token, distinct market
        _mockPos(mpC.id(), lender, 2e24, 0, 0); // lending-only market lender
        _mockPos(mpC.id(), borrower, 0, 0, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    function _mockIdToParams(MarketParams memory mp) internal {
        vm.mockCall(
            morpho,
            abi.encodeCall(IMorphoStaticTyping.idToMarketParams, (mp.id())),
            abi.encode(mp.loanToken, mp.collateralToken, mp.oracle, mp.irm, mp.lltv)
        );
    }

    function _mockMarket(
        Id id,
        uint256 sa,
        uint256 ss,
        uint256 ba,
        uint256 bs,
        uint256 lastUpdate
    )
        internal
    {
        vm.mockCall(
            morpho,
            abi.encodeCall(IMorphoStaticTyping.market, (id)),
            abi.encode(uint128(sa), uint128(ss), uint128(ba), uint128(bs), uint128(lastUpdate), uint128(0))
        );
    }

    function _mockPos(Id id, address account, uint256 supplyShares, uint128 borrowShares, uint256 coll) internal {
        vm.mockCall(
            morpho,
            abi.encodeCall(IMorphoStaticTyping.position, (id, account)),
            abi.encode(supplyShares, borrowShares, coll)
        );
    }

    /*//////////////////////////////////////////////////////////////
                        getMarketPosition
    //////////////////////////////////////////////////////////////*/

    function test_MarketPosition_SimultaneousLendAndBorrow() public view {
        IMorphoMarketPosition.MarketPosition memory p = oracle.getMarketPosition(keyA, both);

        assertEq(p.morpho, morpho);
        assertEq(p.marketId, Id.unwrap(mpA.id()));
        assertEq(p.loanToken, loan6);
        assertEq(p.collateralToken, collateral);
        assertEq(p.loanDecimals, 6);
        assertEq(p.collateralDecimals, 18);
        assertEq(p.supplyShares, 1000e12);
        assertEq(p.borrowShares, 500e12);
        assertEq(p.collateral, 7e18);
        assertEq(p.suppliedAssets, uint256(1000e12).toAssetsDown(SUP_ASSETS_6, SUP_SHARES_6), "supply down");
        assertEq(p.debtAssets, uint256(500e12).toAssetsUp(BOR_ASSETS_6, BOR_SHARES_6), "debt up");
    }

    /// @notice The property the whole ticket exists for: zero supply shares must not suppress collateral/debt.
    function test_MarketPosition_ZeroLendingBorrower_StillHasCollateralAndDebt() public view {
        IMorphoMarketPosition.MarketPosition memory p = oracle.getMarketPosition(keyA, borrower);
        assertEq(p.suppliedAssets, 0, "no lending");
        assertEq(p.supplyShares, 0, "no lending shares");
        assertGt(p.debtAssets, 0, "debt surfaced despite zero lending");
        assertEq(p.collateral, 7e18, "collateral surfaced despite zero lending");
        assertEq(p.debtAssets, uint256(500e12).toAssetsUp(BOR_ASSETS_6, BOR_SHARES_6));
    }

    function test_MarketPosition_LendingOnlyMarket_NoCollateralToken() public view {
        IMorphoMarketPosition.MarketPosition memory p = oracle.getMarketPosition(keyC, lender);
        assertEq(p.collateralToken, address(0), "lending-only market");
        assertEq(p.collateralDecimals, 0, "no collateral decimals read");
        assertEq(p.collateral, 0);
        assertEq(p.loanDecimals, 18);
        assertEq(p.suppliedAssets, uint256(2e24).toAssetsDown(SUP_ASSETS_18, SUP_SHARES_18));
    }

    function test_MarketPosition_Revert_UnregisteredMarket() public {
        vm.expectRevert(MorphoBlueMarketRegistry.MARKET_NOT_REGISTERED.selector);
        oracle.getMarketPosition(makeAddr("ghost"), lender);
    }

    function test_MarketPosition_Revert_ZeroOwner() public {
        vm.expectRevert(MorphoBlueYieldSourceOracle.ZERO_ADDRESS.selector);
        oracle.getMarketPosition(keyA, address(0));
    }

    /// @notice Under live interest, the snapshot's supply leg must equal the scalar lender read and its debt
    ///         leg must equal the INDEPENDENT MorphoBlueDebtOracle (not the same lib it uses) — a non-circular
    ///         cross-check that the two oracles agree on accrued debt.
    function test_MarketPosition_AccrualParity_SupplyScalar_DebtAgainstDebtOracle() public {
        _mockMarket(mpA.id(), SUP_ASSETS_6, SUP_SHARES_6, BOR_ASSETS_6, BOR_SHARES_6, block.timestamp - 30 days);
        vm.mockCall(irm, abi.encodeWithSelector(IIrm.borrowRateView.selector), abi.encode(uint256(1e18 / uint256(365 days)) / 20));

        MorphoBlueDebtOracle debtOracle = new MorphoBlueDebtOracle(ledgerConfig, registry);

        IMorphoMarketPosition.MarketPosition memory p = oracle.getMarketPosition(keyA, both);

        assertEq(p.suppliedAssets, oracle.getTVLByOwnerOfShares(keyA, both), "supply parity with scalar read");
        assertEq(p.debtAssets, debtOracle.getAssetOutput(keyA, loan6, p.borrowShares), "debt parity with debt oracle");
        assertGt(p.suppliedAssets, uint256(1000e12).toAssetsDown(SUP_ASSETS_6, SUP_SHARES_6), "supply grew with interest");
        assertGt(p.debtAssets, uint256(500e12).toAssetsUp(BOR_ASSETS_6, BOR_SHARES_6), "debt grew with interest");
    }

    /// @notice A market untouched > 365 days must not over-accrue or overflow-revert: BOTH legs cap `elapsed`
    ///         at 365 days (the bug was the debt leg using an uncapped helper). Still equals the debt oracle,
    ///         which caps identically.
    function test_MarketPosition_StaleOver365Days_BothLegsCapped_NoRevert() public {
        _mockMarket(mpA.id(), SUP_ASSETS_6, SUP_SHARES_6, BOR_ASSETS_6, BOR_SHARES_6, block.timestamp - 400 days);
        vm.mockCall(irm, abi.encodeWithSelector(IIrm.borrowRateView.selector), abi.encode(uint256(1e18 / uint256(365 days)) / 20));

        MorphoBlueDebtOracle debtOracle = new MorphoBlueDebtOracle(ledgerConfig, registry);

        // Does not revert despite 400-day staleness.
        IMorphoMarketPosition.MarketPosition memory p = oracle.getMarketPosition(keyA, both);

        assertEq(p.suppliedAssets, oracle.getTVLByOwnerOfShares(keyA, both), "supply capped, matches scalar");
        assertEq(p.debtAssets, debtOracle.getAssetOutput(keyA, loan6, p.borrowShares), "debt capped, matches debt oracle");
    }

    /// @notice Registered zero-IRM market (registry allows irm == address(0)) with outstanding borrows: the
    ///         old uncapped debt path called borrowRateView on address(0) and reverted. The capped `_accrue`
    ///         takes Morpho's irm==0 early-return, so debt is the raw (un-accrued) share conversion and the
    ///         read does not revert.
    function test_MarketPosition_ZeroIrmMarket_NoAccrualNoRevert() public {
        MarketParams memory mpZ = MarketParams(loan6, collateral, mockOracle, address(0), LLTV);
        vm.mockCall(
            morpho,
            abi.encodeCall(IMorphoStaticTyping.idToMarketParams, (mpZ.id())),
            abi.encode(loan6, collateral, mockOracle, address(0), LLTV)
        );
        address keyZ = MorphoBlueMarketRegistry(registry).registerMarket(morpho, loan6, collateral, mockOracle, address(0), LLTV);

        // Stale AND zero-IRM: proves the revert came from the IRM call, not staleness.
        _mockMarket(mpZ.id(), SUP_ASSETS_6, SUP_SHARES_6, BOR_ASSETS_6, BOR_SHARES_6, block.timestamp - 400 days);
        _mockPos(mpZ.id(), borrower, 0, 500e12, 3e18);

        IMorphoMarketPosition.MarketPosition memory p = oracle.getMarketPosition(keyZ, borrower);
        // No accrual: raw totals used, so debt == toAssetsUp against the un-accrued totals.
        assertEq(p.debtAssets, uint256(500e12).toAssetsUp(BOR_ASSETS_6, BOR_SHARES_6), "zero-IRM debt not accrued");
        assertEq(p.collateral, 3e18);
    }

    /// @notice Fee-bearing market (fee > 0): exercises the fee-share accrual branch of `_accrue` on the
    ///         snapshot path and confirms the supply leg still matches the scalar read.
    function test_MarketPosition_FeeAccrual_SupplyMatchesScalar() public {
        vm.mockCall(
            morpho,
            abi.encodeCall(IMorphoStaticTyping.market, (mpA.id())),
            abi.encode(
                SUP_ASSETS_6, SUP_SHARES_6, BOR_ASSETS_6, BOR_SHARES_6, uint128(block.timestamp - 30 days), uint128(0.1e18)
            )
        );
        vm.mockCall(irm, abi.encodeWithSelector(IIrm.borrowRateView.selector), abi.encode(uint256(1e18 / uint256(365 days)) / 20));

        IMorphoMarketPosition.MarketPosition memory p = oracle.getMarketPosition(keyA, both);
        assertEq(p.suppliedAssets, oracle.getTVLByOwnerOfShares(keyA, both), "fee-adjusted supply matches scalar read");
    }

    /*//////////////////////////////////////////////////////////////
                        getOwnerSnapshot
    //////////////////////////////////////////////////////////////*/

    function test_OwnerSnapshot_ThreeLegsForCollateralMarket() public view {
        address[] memory keys = new address[](1);
        keys[0] = keyA;
        (IMorphoOwnerSnapshot.MarketBinding[] memory m, IMorphoOwnerSnapshot.OwnerPosition[] memory pos) =
            oracle.getOwnerSnapshot(both, keys);

        assertEq(m.length, 1, "one binding");
        assertEq(m[0].marketKey, keyA);
        assertEq(m[0].loanToken, loan6);
        assertEq(m[0].collateralToken, collateral);

        assertEq(pos.length, 3, "lending + debt + collateral");
        assertTrue(pos[0].side == IMorphoOwnerSnapshot.Side.Lending);
        assertEq(pos[0].token, loan6);
        assertTrue(pos[1].side == IMorphoOwnerSnapshot.Side.Debt);
        assertEq(pos[1].token, loan6);
        assertTrue(pos[2].side == IMorphoOwnerSnapshot.Side.Collateral);
        assertEq(pos[2].token, collateral);
        assertEq(pos[2].assets, 7e18);
        assertEq(pos[2].shares, 0, "collateral carries no shares");
    }

    function test_OwnerSnapshot_LendingOnlyMarket_EmitsTwoLegs() public view {
        address[] memory keys = new address[](1);
        keys[0] = keyC;
        (, IMorphoOwnerSnapshot.OwnerPosition[] memory pos) = oracle.getOwnerSnapshot(lender, keys);
        assertEq(pos.length, 2, "no collateral leg for lending-only market");
        assertTrue(pos[0].side == IMorphoOwnerSnapshot.Side.Lending);
        assertTrue(pos[1].side == IMorphoOwnerSnapshot.Side.Debt);
    }

    /// @notice Zero balances are still emitted (stable per-market shape) for the loan-token legs.
    function test_OwnerSnapshot_EmptyOwner_ZeroLegsStillReturned() public view {
        address[] memory keys = new address[](1);
        keys[0] = keyA;
        (, IMorphoOwnerSnapshot.OwnerPosition[] memory pos) = oracle.getOwnerSnapshot(empty, keys);
        assertEq(pos.length, 3);
        assertEq(pos[0].assets, 0, "lending zero");
        assertEq(pos[1].assets, 0, "debt zero");
        assertEq(pos[2].assets, 0, "collateral zero");
    }

    /// @notice Same loan token in two DISTINCT markets must stay two distinct debt legs — never merged.
    function test_OwnerSnapshot_SameLoanToken_DistinctMarkets_NotMerged() public view {
        address[] memory keys = new address[](2);
        keys[0] = keyA;
        keys[1] = keyB;
        (IMorphoOwnerSnapshot.MarketBinding[] memory m, IMorphoOwnerSnapshot.OwnerPosition[] memory pos) =
            oracle.getOwnerSnapshot(borrower, keys);

        assertEq(m.length, 2, "two distinct markets");
        // 3 legs each (both have a collateral token) = 6
        assertEq(pos.length, 6);

        uint256 debtA = uint256(500e12).toAssetsUp(BOR_ASSETS_6, BOR_SHARES_6);
        uint256 debtB = uint256(300e12).toAssetsUp(BOR_ASSETS_6, BOR_SHARES_6);
        uint256 seenDebtMarkets;
        for (uint256 i; i < pos.length; ++i) {
            if (pos[i].side == IMorphoOwnerSnapshot.Side.Debt) {
                seenDebtMarkets++;
                assertEq(pos[i].token, loan6, "both debts in same loan token");
                assertTrue(pos[i].assets == debtA || pos[i].assets == debtB, "distinct debt amounts preserved");
            }
        }
        assertEq(seenDebtMarkets, 2, "two separate debt legs, not one merged");
    }

    /// @notice Duplicate market keys collapse to one binding and one set of legs (idempotent).
    function test_OwnerSnapshot_DuplicateKeys_Collapse() public view {
        address[] memory keys = new address[](3);
        keys[0] = keyA;
        keys[1] = keyA;
        keys[2] = keyA;
        (IMorphoOwnerSnapshot.MarketBinding[] memory m, IMorphoOwnerSnapshot.OwnerPosition[] memory pos) =
            oracle.getOwnerSnapshot(both, keys);
        assertEq(m.length, 1, "collapsed to one binding");
        assertEq(pos.length, 3, "collapsed to one set of legs");
    }

    function test_OwnerSnapshot_Revert_UnregisteredMarket() public {
        address[] memory keys = new address[](1);
        keys[0] = makeAddr("ghost");
        vm.expectRevert(MorphoBlueMarketRegistry.MARKET_NOT_REGISTERED.selector);
        oracle.getOwnerSnapshot(lender, keys);
    }

    function test_OwnerSnapshot_Revert_ZeroOwner() public {
        address[] memory keys = new address[](1);
        keys[0] = keyA;
        vm.expectRevert(MorphoBlueYieldSourceOracle.ZERO_ADDRESS.selector);
        oracle.getOwnerSnapshot(address(0), keys);
    }

    function test_OwnerSnapshot_EmptyKeys_ReturnsEmpty() public view {
        address[] memory keys = new address[](0);
        (IMorphoOwnerSnapshot.MarketBinding[] memory m, IMorphoOwnerSnapshot.OwnerPosition[] memory pos) =
            oracle.getOwnerSnapshot(lender, keys);
        assertEq(m.length, 0);
        assertEq(pos.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        ADDITIONAL COVERAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Collateral-only owner: no lending, no debt, collateral present — all three legs still read.
    function test_MarketPosition_CollateralOnly() public {
        address collOnly = makeAddr("collOnly");
        _mockPos(mpA.id(), collOnly, 0, 0, 9e18);

        IMorphoMarketPosition.MarketPosition memory p = oracle.getMarketPosition(keyA, collOnly);
        assertEq(p.suppliedAssets, 0);
        assertEq(p.supplyShares, 0);
        assertEq(p.debtAssets, 0);
        assertEq(p.borrowShares, 0);
        assertEq(p.collateral, 9e18);

        address[] memory keys = new address[](1);
        keys[0] = keyA;
        (, IMorphoOwnerSnapshot.OwnerPosition[] memory pos) = oracle.getOwnerSnapshot(collOnly, keys);
        assertEq(pos.length, 3, "all three legs for a collateral market");
        assertEq(pos[2].assets, 9e18, "collateral leg carries the amount");
    }

    /// @notice Debt rounds UP and supply rounds DOWN: a single dust share makes the directions diverge.
    ///         supply(1 share) floors to 0; debt(1 share) ceils to 1 — never the other way around.
    function test_MarketPosition_DebtRoundsUp_SupplyRoundsDown() public {
        address dust = makeAddr("dust");
        _mockPos(mpA.id(), dust, 1, 1, 0);

        IMorphoMarketPosition.MarketPosition memory p = oracle.getMarketPosition(keyA, dust);

        assertEq(p.suppliedAssets, 0, "supply floors the dust share to 0");
        assertEq(p.suppliedAssets, uint256(1).toAssetsDown(SUP_ASSETS_6, SUP_SHARES_6));
        assertEq(p.debtAssets, 1, "debt ceils the dust share to 1 (conservative liability)");
        assertEq(p.debtAssets, uint256(1).toAssetsUp(BOR_ASSETS_6, BOR_SHARES_6));
        assertGt(p.debtAssets, uint256(1).toAssetsDown(BOR_ASSETS_6, BOR_SHARES_6), "up > down for the same share");
    }

    /// @notice Mixed markets in one request: binding order is first-seen, legs are grouped per market, and
    ///         each leg carries its own token's decimals (6-dec collateral market + 18-dec lending-only).
    function test_OwnerSnapshot_MixedMarkets_OrderAndDecimals() public view {
        address[] memory keys = new address[](2);
        keys[0] = keyA; // 6-dec loan, has collateral
        keys[1] = keyC; // 18-dec loan, lending-only
        (IMorphoOwnerSnapshot.MarketBinding[] memory m, IMorphoOwnerSnapshot.OwnerPosition[] memory pos) =
            oracle.getOwnerSnapshot(lender, keys);

        assertEq(m.length, 2);
        assertEq(m[0].marketKey, keyA, "first-seen order preserved");
        assertEq(m[1].marketKey, keyC);

        // keyA -> 3 legs, keyC -> 2 legs
        assertEq(pos.length, 5);
        // keyA legs
        assertEq(pos[0].tokenDecimals, 6, "keyA lending decimals");
        assertEq(pos[1].tokenDecimals, 6, "keyA debt decimals");
        assertTrue(pos[2].side == IMorphoOwnerSnapshot.Side.Collateral);
        assertEq(pos[2].tokenDecimals, 18, "collateral token decimals");
        // keyC legs (lending-only, loan token is 18-dec)
        assertEq(pos[3].marketKey, keyC);
        assertEq(pos[3].tokenDecimals, 18, "keyC lending decimals");
        assertTrue(pos[4].side == IMorphoOwnerSnapshot.Side.Debt);
    }

    /// @notice The binding's marketId is the real Morpho id (keccak of the market params), not the key.
    function test_OwnerSnapshot_BindingMarketIdMatches() public view {
        address[] memory keys = new address[](1);
        keys[0] = keyA;
        (IMorphoOwnerSnapshot.MarketBinding[] memory m,) = oracle.getOwnerSnapshot(lender, keys);
        assertEq(m[0].marketId, Id.unwrap(mpA.id()), "binding carries the full market id");
        assertEq(m[0].morpho, morpho);
    }

    /// @notice Conversions hold for arbitrary positions (no accrual): supply down, debt up, collateral and
    ///         shares echoed verbatim, independently of each other.
    function testFuzz_MarketPosition_Conversions(uint256 supplyShares, uint128 borrowShares, uint128 coll) public {
        supplyShares = bound(supplyShares, 0, 1e30);
        borrowShares = uint128(bound(uint256(borrowShares), 0, uint256(SUP_SHARES_6))); // within total borrow-share space
        address who = makeAddr("fuzzOwner");
        _mockPos(mpA.id(), who, supplyShares, borrowShares, uint256(coll));

        IMorphoMarketPosition.MarketPosition memory p = oracle.getMarketPosition(keyA, who);

        assertEq(p.supplyShares, supplyShares, "supply shares echoed");
        assertEq(p.borrowShares, uint256(borrowShares), "borrow shares echoed");
        assertEq(p.collateral, uint256(coll), "collateral passthrough");
        assertEq(p.suppliedAssets, supplyShares.toAssetsDown(SUP_ASSETS_6, SUP_SHARES_6), "supply down");
        assertEq(p.debtAssets, uint256(borrowShares).toAssetsUp(BOR_ASSETS_6, BOR_SHARES_6), "debt up");
        // zero lending never suppresses the other legs
        if (supplyShares == 0) {
            assertEq(p.suppliedAssets, 0);
            assertEq(p.collateral, uint256(coll));
            assertEq(p.debtAssets, uint256(borrowShares).toAssetsUp(BOR_ASSETS_6, BOR_SHARES_6));
        }
    }
}
