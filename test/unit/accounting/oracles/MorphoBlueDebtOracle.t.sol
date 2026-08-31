// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

import { MorphoBlueDebtOracle } from "../../../../src/accounting/oracles/MorphoBlueDebtOracle.sol";
import { MorphoBlueMarketRegistry } from "../../../../src/accounting/oracles/MorphoBlueMarketRegistry.sol";
import { IYieldSourceOracle } from "../../../../src/interfaces/accounting/IYieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../../../src/accounting/SuperLedgerConfiguration.sol";
import { IMorphoStaticTyping, MarketParams, Id } from "../../../../src/vendor/morpho/IMorpho.sol";
import { MarketParamsLib } from "../../../../src/vendor/morpho/MarketParamsLib.sol";
import { SharesMathLib } from "../../../../src/vendor/morpho/SharesMathLib.sol";
import { MathLib } from "../../../../src/vendor/morpho/MathLib.sol";
import { IIrm } from "../../../../src/vendor/morpho/IIrm.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract MorphoBlueDebtOracleTest is Test {
    using MarketParamsLib for MarketParams;
    using SharesMathLib for uint256;
    using MathLib for uint256;

    MorphoBlueDebtOracle public oracle;
    address public ledgerConfig;
    address public registry;

    // Mock addresses
    address public morpho = makeAddr("morpho");
    address public loanToken6 = makeAddr("usdc");
    address public loanToken18 = makeAddr("weth");
    address public collateralToken = makeAddr("collateral");
    address public mockOracle = makeAddr("oracle");
    address public irm = makeAddr("irm");

    address public account1 = makeAddr("account1");
    address public account2 = makeAddr("account2");

    // Market keys (derived from registry)
    address public marketKey6;
    address public marketKey18;

    // Market params
    MarketParams public mp6;
    MarketParams public mp18;

    // Default market state values
    uint128 constant TOTAL_SUPPLY_ASSETS = 10_000_000e6;
    uint128 constant TOTAL_SUPPLY_SHARES = 10_000_000e12; // +6 decimals
    uint128 constant TOTAL_BORROW_ASSETS = 5_000_000e6;
    uint128 constant TOTAL_BORROW_SHARES = 5_000_000e12;
    uint128 constant FEE = 0;
    uint256 constant LLTV = 0.86e18;

    function setUp() public {
        // Warp to a reasonable timestamp to avoid underflow in (block.timestamp - N days)
        vm.warp(365 days * 2);

        ledgerConfig = address(new SuperLedgerConfiguration());

        // Deploy registry
        registry = address(new MorphoBlueMarketRegistry(address(this)));

        // Approve IRM
        MorphoBlueMarketRegistry(registry).setIrmApproval(irm, true);

        // Set up market params
        mp6 = MarketParams({
            loanToken: loanToken6,
            collateralToken: collateralToken,
            oracle: mockOracle,
            irm: irm,
            lltv: LLTV
        });

        mp18 = MarketParams({
            loanToken: loanToken18,
            collateralToken: collateralToken,
            oracle: mockOracle,
            irm: irm,
            lltv: LLTV
        });

        // Mock loanToken decimals
        vm.mockCall(loanToken6, abi.encodeCall(IERC20Metadata.decimals, ()), abi.encode(uint8(6)));
        vm.mockCall(loanToken18, abi.encodeCall(IERC20Metadata.decimals, ()), abi.encode(uint8(18)));

        // Mock idToMarketParams so registry registerMarket works
        vm.mockCall(
            morpho,
            abi.encodeCall(IMorphoStaticTyping.idToMarketParams, (mp6.id())),
            abi.encode(loanToken6, collateralToken, mockOracle, irm, LLTV)
        );
        vm.mockCall(
            morpho,
            abi.encodeCall(IMorphoStaticTyping.idToMarketParams, (mp18.id())),
            abi.encode(loanToken18, collateralToken, mockOracle, irm, LLTV)
        );

        // Register markets
        marketKey6 = MorphoBlueMarketRegistry(registry).registerMarket(
            morpho, loanToken6, collateralToken, mockOracle, irm, LLTV
        );
        marketKey18 = MorphoBlueMarketRegistry(registry).registerMarket(
            morpho, loanToken18, collateralToken, mockOracle, irm, LLTV
        );

        // Deploy oracle
        oracle = new MorphoBlueDebtOracle(ledgerConfig, registry);

        // Mock market state for 6-decimal market (lastUpdate = block.timestamp, no accrual needed)
        _mockMarketState(mp6.id(), TOTAL_SUPPLY_ASSETS, TOTAL_SUPPLY_SHARES, TOTAL_BORROW_ASSETS, TOTAL_BORROW_SHARES);

        // Mock market state for 18-decimal market
        _mockMarketState(
            mp18.id(),
            50_000 ether, // totalSupplyAssets
            50_000e24, // totalSupplyShares (18+6 decimals)
            25_000 ether, // totalBorrowAssets
            25_000e24 // totalBorrowShares
        );

        // Mock positions: account1 has debt, account2 has no debt
        _mockPosition(mp6.id(), account1, 0, 500e12, 0); // 500e12 borrow shares
        _mockPosition(mp6.id(), account2, 0, 0, 0); // no debt
        _mockPosition(mp18.id(), account1, 0, 2e24, 0); // 2e24 borrow shares (2 WETH worth at 1:1)
        _mockPosition(mp18.id(), account2, 0, 0, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    function _mockMarketState(
        Id id,
        uint256 totalSupplyAssets_,
        uint256 totalSupplyShares_,
        uint256 totalBorrowAssets_,
        uint256 totalBorrowShares_
    )
        internal
    {
        vm.mockCall(
            morpho,
            abi.encodeCall(IMorphoStaticTyping.market, (id)),
            abi.encode(
                uint128(totalSupplyAssets_),
                uint128(totalSupplyShares_),
                uint128(totalBorrowAssets_),
                uint128(totalBorrowShares_),
                uint128(block.timestamp), // lastUpdate = now (no accrual)
                uint128(0) // fee
            )
        );
    }

    function _mockMarketStateWithTimestamp(
        Id id,
        uint256 totalBorrowAssets_,
        uint256 totalBorrowShares_,
        uint256 lastUpdate_
    )
        internal
    {
        vm.mockCall(
            morpho,
            abi.encodeCall(IMorphoStaticTyping.market, (id)),
            abi.encode(
                uint128(TOTAL_SUPPLY_ASSETS),
                uint128(TOTAL_SUPPLY_SHARES),
                uint128(totalBorrowAssets_),
                uint128(totalBorrowShares_),
                uint128(lastUpdate_),
                uint128(0)
            )
        );
    }

    function _mockPosition(
        Id id,
        address account,
        uint256 supplyShares,
        uint128 borrowShares,
        uint256 collateral
    )
        internal
    {
        vm.mockCall(
            morpho,
            abi.encodeCall(IMorphoStaticTyping.position, (id, account)),
            abi.encode(supplyShares, borrowShares, collateral)
        );
    }

    function _mockBorrowRate(uint256 rate) internal {
        vm.mockCall(irm, abi.encodeWithSelector(IIrm.borrowRateView.selector), abi.encode(rate));
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_constructor_setsSuperLedgerConfiguration() public view {
        assertEq(oracle.SUPER_LEDGER_CONFIGURATION(), ledgerConfig);
    }

    function test_constructor_setsRegistry() public view {
        assertEq(address(oracle.REGISTRY()), registry);
    }

    function test_constructor_revertsOnZeroRegistry() public {
        vm.expectRevert(MorphoBlueDebtOracle.ZERO_ADDRESS.selector);
        new MorphoBlueDebtOracle(ledgerConfig, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                            DECIMALS
    //////////////////////////////////////////////////////////////*/

    function test_decimals_6decimals() public view {
        assertEq(oracle.decimals(marketKey6), 12); // 6 + 6
    }

    function test_decimals_18decimals() public view {
        assertEq(oracle.decimals(marketKey18), 24); // 18 + 6
    }

    function test_decimals_0decimals() public {
        // Create a market with 0-decimal token
        address loanToken0 = makeAddr("token0dec");
        vm.mockCall(loanToken0, abi.encodeCall(IERC20Metadata.decimals, ()), abi.encode(uint8(0)));

        MarketParams memory mp0 = MarketParams({
            loanToken: loanToken0,
            collateralToken: collateralToken,
            oracle: mockOracle,
            irm: irm,
            lltv: LLTV
        });

        vm.mockCall(
            morpho,
            abi.encodeCall(IMorphoStaticTyping.idToMarketParams, (mp0.id())),
            abi.encode(loanToken0, collateralToken, mockOracle, irm, LLTV)
        );
        address key0 = MorphoBlueMarketRegistry(registry).registerMarket(
            morpho, loanToken0, collateralToken, mockOracle, irm, LLTV
        );
        _mockMarketState(mp0.id(), 0, 0, 0, 0);

        assertEq(oracle.decimals(key0), 6); // 0 + 6
    }

    /*//////////////////////////////////////////////////////////////
                        PRICE PER SHARE
    //////////////////////////////////////////////////////////////*/

    function test_getPricePerShare_freshMarket() public view {
        // lastUpdate == block.timestamp, no accrual needed
        // PPS = (10^12).toAssetsUp(5_000_000e6, 5_000_000e12)
        // With virtual: (10^12 * (5_000_000e6 + 1) + (5_000_000e12 + 1e6)) / (5_000_000e12 + 1e6)
        // Approximately 1e6 (1:1 ratio since assets and shares were created at 1:1)
        uint256 pps = oracle.getPricePerShare(marketKey6);
        // Should be very close to 1e6 (the identity PPS for a fresh 1:1 market)
        assertApproxEqRel(pps, 1e6, 1e12); // within 0.0001%
    }

    function test_getPricePerShare_withAccruedInterest() public {
        // Set lastUpdate to 1 day ago
        _mockMarketStateWithTimestamp(mp6.id(), TOTAL_BORROW_ASSETS, TOTAL_BORROW_SHARES, block.timestamp - 1 days);

        // Mock IRM to return 5% APY (approx)
        uint256 borrowRatePerSecond = 1_585_489_599; // ~5% APY in WAD per second
        _mockBorrowRate(borrowRatePerSecond);

        uint256 ppsBefore = oracle.getPricePerShare(marketKey6);

        // Warp forward another day to increase accrual
        vm.warp(block.timestamp + 1 days);
        uint256 ppsAfter = oracle.getPricePerShare(marketKey6);

        assertGt(ppsAfter, ppsBefore, "PPS should increase with interest accrual");
    }

    function test_getPricePerShare_zeroIrm() public {
        // Create a market with zero IRM
        MarketParams memory mp0irm = MarketParams({
            loanToken: loanToken6,
            collateralToken: collateralToken,
            oracle: mockOracle,
            irm: address(0),
            lltv: 0.5e18
        });

        vm.mockCall(
            morpho,
            abi.encodeCall(IMorphoStaticTyping.idToMarketParams, (mp0irm.id())),
            abi.encode(loanToken6, collateralToken, mockOracle, address(0), 0.5e18)
        );
        address key0irm = MorphoBlueMarketRegistry(registry).registerMarket(
            morpho, loanToken6, collateralToken, mockOracle, address(0), 0.5e18
        );

        // Set lastUpdate to 1 day ago (but irm=0 so no accrual)
        vm.mockCall(
            morpho,
            abi.encodeCall(IMorphoStaticTyping.market, (mp0irm.id())),
            abi.encode(
                uint128(TOTAL_SUPPLY_ASSETS),
                uint128(TOTAL_SUPPLY_SHARES),
                uint128(TOTAL_BORROW_ASSETS),
                uint128(TOTAL_BORROW_SHARES),
                uint128(block.timestamp - 1 days),
                uint128(0)
            )
        );

        uint256 pps = oracle.getPricePerShare(key0irm);
        // Should be same as fresh (no interest with zero IRM)
        assertApproxEqRel(pps, 1e6, 1e12);
    }

    function test_getPricePerShare_zeroBorrows() public {
        // Market with no borrows
        _mockMarketState(mp6.id(), TOTAL_SUPPLY_ASSETS, TOTAL_SUPPLY_SHARES, 0, 0);

        // PPS with zero borrows: (10^12).toAssetsUp(0, 0)
        // = (10^12 * (0 + 1) + (0 + 1e6)) / (0 + 1e6) = (10^12 + 1e6) / 1e6 ≈ 1e6
        uint256 pps = oracle.getPricePerShare(marketKey6);
        assertApproxEqRel(pps, 1e6, 1e12);
    }

    /*//////////////////////////////////////////////////////////////
                    SHARE/ASSET CONVERSIONS
    //////////////////////////////////////////////////////////////*/

    function test_getShareOutput_convertsAssetsToShares() public view {
        uint256 shares = oracle.getShareOutput(marketKey6, address(0), 100e6);
        // Fresh 1:1 market: 100e6 assets ≈ 100e12 shares (with virtual offset)
        assertApproxEqRel(shares, 100e12, 1e12);
    }

    function test_getWithdrawalShareOutput_convertsAssetsToSharesUp() public view {
        uint256 sharesDown = oracle.getShareOutput(marketKey6, address(0), 100e6);
        uint256 sharesUp = oracle.getWithdrawalShareOutput(marketKey6, address(0), 100e6);
        // Rounding up should give >= rounding down
        assertGe(sharesUp, sharesDown, "Withdrawal shares (up) should be >= share output (down)");
    }

    function test_getAssetOutput_convertsSharestoAssetsUp() public view {
        uint256 assets = oracle.getAssetOutput(marketKey6, address(0), 100e12);
        // Fresh 1:1 market: 100e12 shares ≈ 100e6 assets
        assertApproxEqRel(assets, 100e6, 1e12);
    }

    function test_conversions_roundTrip() public view {
        uint256 amount = 12_345e6;
        uint256 shares = oracle.getShareOutput(marketKey6, address(0), amount);
        uint256 back = oracle.getAssetOutput(marketKey6, address(0), shares);
        // toAssetsUp on the way back gives >= original (conservative)
        assertGe(back, amount, "Round-trip with toAssetsUp should give >= original");
    }

    /*//////////////////////////////////////////////////////////////
                    BALANCE / DEBT TRACKING
    //////////////////////////////////////////////////////////////*/

    function test_getBalanceOfOwner_returnsBorrowShares() public view {
        assertEq(oracle.getBalanceOfOwner(marketKey6, account1), 500e12);
    }

    function test_getBalanceOfOwner_zeroDebt() public view {
        assertEq(oracle.getBalanceOfOwner(marketKey6, account2), 0);
    }

    function test_getBalanceOfOwner_maxUint128BorrowShares() public {
        _mockPosition(mp6.id(), account1, 0, type(uint128).max, 0);
        assertEq(oracle.getBalanceOfOwner(marketKey6, account1), type(uint128).max);
    }

    function test_getTVLByOwnerOfShares_returnsAccruedDebt() public view {
        uint256 tvl = oracle.getTVLByOwnerOfShares(marketKey6, account1);
        // 500e12 shares at ~1:1 PPS ≈ 500e6 assets
        assertApproxEqRel(tvl, 500e6, 1e12);
    }

    function test_getTVLByOwnerOfShares_zeroShares_returnsZero() public view {
        assertEq(oracle.getTVLByOwnerOfShares(marketKey6, account2), 0);
    }

    function test_getBalanceOfOwner_equalityCheck() public view {
        // getBalanceOfOwner returns raw shares, getTVLByOwnerOfShares converts to assets
        uint256 shares = oracle.getBalanceOfOwner(marketKey6, account1);
        uint256 tvl = oracle.getTVLByOwnerOfShares(marketKey6, account1);
        // In a 1:1 market, shares (in 12 dec) should be numerically different from tvl (in 6 dec)
        assertTrue(shares != tvl, "Shares and TVL should differ in a non-identity oracle");
    }

    /*//////////////////////////////////////////////////////////////
                            TVL
    //////////////////////////////////////////////////////////////*/

    function test_getTVL_returnsAccruedTotalBorrowAssets() public view {
        assertEq(oracle.getTVL(marketKey6), TOTAL_BORROW_ASSETS);
    }

    function test_getTVL_18decimals() public view {
        assertEq(oracle.getTVL(marketKey18), 25_000 ether);
    }

    function test_getTVL_zeroBorrows() public {
        _mockMarketState(mp6.id(), TOTAL_SUPPLY_ASSETS, TOTAL_SUPPLY_SHARES, 0, 0);
        assertEq(oracle.getTVL(marketKey6), 0);
    }

    function test_getTVL_withInterestAccrual() public {
        _mockMarketStateWithTimestamp(mp6.id(), TOTAL_BORROW_ASSETS, TOTAL_BORROW_SHARES, block.timestamp - 1 days);
        uint256 borrowRatePerSecond = 1_585_489_599; // ~5% APY
        _mockBorrowRate(borrowRatePerSecond);

        uint256 tvl = oracle.getTVL(marketKey6);
        assertGt(tvl, TOTAL_BORROW_ASSETS, "TVL should increase with interest accrual");
    }

    /*//////////////////////////////////////////////////////////////
                    INTEREST ACCRUAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function test_accrual_noElapsed_noChange() public view {
        // lastUpdate == block.timestamp, no accrual
        assertEq(oracle.getTVL(marketKey6), TOTAL_BORROW_ASSETS);
    }

    function test_accrual_withElapsed_interestApplied() public {
        _mockMarketStateWithTimestamp(mp6.id(), TOTAL_BORROW_ASSETS, TOTAL_BORROW_SHARES, block.timestamp - 7 days);
        uint256 borrowRatePerSecond = 1_585_489_599;
        _mockBorrowRate(borrowRatePerSecond);

        uint256 tvl = oracle.getTVL(marketKey6);
        // Interest = totalBorrowAssets * wMulDown(borrowRate.wTaylorCompounded(7 days))
        // Should be > 0 but less than 1% of principal for 7 days at 5% APY
        uint256 expectedMinInterest = TOTAL_BORROW_ASSETS * 7 / 365 / 100; // rough lower bound: 5%/365 * 7
        assertGt(tvl - TOTAL_BORROW_ASSETS, expectedMinInterest / 10, "Interest should be meaningful");
        assertLt(tvl - TOTAL_BORROW_ASSETS, TOTAL_BORROW_ASSETS / 10, "Interest should be < 10% for 7 days");
    }

    function test_accrual_elapsedCappedAt365Days() public {
        // lastUpdate very far in the past
        _mockMarketStateWithTimestamp(mp6.id(), TOTAL_BORROW_ASSETS, TOTAL_BORROW_SHARES, block.timestamp - 730 days);
        uint256 borrowRatePerSecond = 1_585_489_599;
        _mockBorrowRate(borrowRatePerSecond);

        uint256 tvl730 = oracle.getTVL(marketKey6);

        // Now set exactly 365 days
        _mockMarketStateWithTimestamp(mp6.id(), TOTAL_BORROW_ASSETS, TOTAL_BORROW_SHARES, block.timestamp - 365 days);

        uint256 tvl365 = oracle.getTVL(marketKey6);

        // Both should produce the same result (730 is capped to 365)
        assertEq(tvl730, tvl365, "Elapsed should be capped at 365 days");
    }

    function test_accrual_zeroIrm_skipsAccrual() public {
        // Create zero-IRM market
        MarketParams memory mp0irm = MarketParams({
            loanToken: loanToken6,
            collateralToken: collateralToken,
            oracle: mockOracle,
            irm: address(0),
            lltv: 0.5e18
        });

        vm.mockCall(
            morpho,
            abi.encodeCall(IMorphoStaticTyping.idToMarketParams, (mp0irm.id())),
            abi.encode(loanToken6, collateralToken, mockOracle, address(0), 0.5e18)
        );
        address key = MorphoBlueMarketRegistry(registry).registerMarket(
            morpho, loanToken6, collateralToken, mockOracle, address(0), 0.5e18
        );

        // Set stale market state (1 day old)
        vm.mockCall(
            morpho,
            abi.encodeCall(IMorphoStaticTyping.market, (mp0irm.id())),
            abi.encode(
                uint128(TOTAL_SUPPLY_ASSETS),
                uint128(TOTAL_SUPPLY_SHARES),
                uint128(TOTAL_BORROW_ASSETS),
                uint128(TOTAL_BORROW_SHARES),
                uint128(block.timestamp - 1 days),
                uint128(0)
            )
        );

        // No IRM → no accrual even with elapsed > 0
        assertEq(oracle.getTVL(key), TOTAL_BORROW_ASSETS, "Zero IRM should skip accrual");
    }

    /*//////////////////////////////////////////////////////////////
                    REVERT ON INVALID INPUT
    //////////////////////////////////////////////////////////////*/

    function test_decimals_revertsOnUnregisteredMarket() public {
        vm.expectRevert(MorphoBlueMarketRegistry.MARKET_NOT_REGISTERED.selector);
        oracle.decimals(address(0xdead));
    }

    function test_getPricePerShare_revertsOnUnregisteredMarket() public {
        vm.expectRevert(MorphoBlueMarketRegistry.MARKET_NOT_REGISTERED.selector);
        oracle.getPricePerShare(address(0xdead));
    }

    function test_getTVL_revertsOnUnregisteredMarket() public {
        vm.expectRevert(MorphoBlueMarketRegistry.MARKET_NOT_REGISTERED.selector);
        oracle.getTVL(address(0xdead));
    }

    function test_getBalanceOfOwner_revertsOnUnregisteredMarket() public {
        vm.expectRevert(MorphoBlueMarketRegistry.MARKET_NOT_REGISTERED.selector);
        oracle.getBalanceOfOwner(address(0xdead), account1);
    }

    function test_getTVLByOwnerOfShares_revertsOnUnregisteredMarket() public {
        vm.expectRevert(MorphoBlueMarketRegistry.MARKET_NOT_REGISTERED.selector);
        oracle.getTVLByOwnerOfShares(address(0xdead), account1);
    }

    /*//////////////////////////////////////////////////////////////
                    getAssetOutputWithFees (OVERRIDDEN - P2-1 FIX)
    //////////////////////////////////////////////////////////////*/

    /// @notice Override always returns getAssetOutput (no fee logic)
    function test_getAssetOutputWithFees_noConfig_returnsBase() public view {
        bytes32 fakeOracleId = keccak256("nonexistent");
        uint256 shares = 500e12;
        uint256 baseOutput = oracle.getAssetOutput(marketKey6, address(0), shares);
        uint256 result = oracle.getAssetOutputWithFees(fakeOracleId, marketKey6, address(0), account1, shares);
        assertEq(result, baseOutput, "Should return base output (fees always bypassed)");
    }

    /// @notice Zero shares returns zero
    function test_getAssetOutputWithFees_zeroShares() public view {
        bytes32 fakeOracleId = keccak256("nonexistent");
        uint256 result = oracle.getAssetOutputWithFees(fakeOracleId, marketKey6, address(0), account1, 0);
        assertEq(result, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    BATCH OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function test_getPricePerShareMultiple() public view {
        address[] memory keys = new address[](2);
        keys[0] = marketKey6;
        keys[1] = marketKey18;

        uint256[] memory prices = oracle.getPricePerShareMultiple(keys);
        assertEq(prices.length, 2);
        assertApproxEqRel(prices[0], 1e6, 1e12);
        assertApproxEqRel(prices[1], 1e18, 1e12);
    }

    function test_getTVLMultiple() public view {
        address[] memory keys = new address[](2);
        keys[0] = marketKey6;
        keys[1] = marketKey18;

        uint256[] memory tvls = oracle.getTVLMultiple(keys);
        assertEq(tvls[0], TOTAL_BORROW_ASSETS);
        assertEq(tvls[1], 25_000 ether);
    }

    function test_getTVLByOwnerOfSharesMultiple() public view {
        address[] memory keys = new address[](2);
        keys[0] = marketKey6;
        keys[1] = marketKey18;

        address[][] memory owners = new address[][](2);
        owners[0] = new address[](2);
        owners[0][0] = account1;
        owners[0][1] = account2;
        owners[1] = new address[](1);
        owners[1][0] = account1;

        (uint256[][] memory tvls, bool[][] memory succeeded) = oracle.getTVLByOwnerOfSharesMultiple(keys, owners);

        assertApproxEqRel(tvls[0][0], 500e6, 1e12);
        assertTrue(succeeded[0][0]);
        assertEq(tvls[0][1], 0); // account2 has no debt
        assertTrue(succeeded[0][1]);
        assertApproxEqRel(tvls[1][0], 2 ether, 1e12);
        assertTrue(succeeded[1][0]);
    }

    function test_getTVLByOwnerOfSharesMultiple_arrayLengthMismatch() public {
        address[] memory keys = new address[](2);
        keys[0] = marketKey6;
        keys[1] = marketKey18;

        address[][] memory owners = new address[][](1);
        owners[0] = new address[](1);
        owners[0][0] = account1;

        vm.expectRevert(IYieldSourceOracle.ARRAY_LENGTH_MISMATCH.selector);
        oracle.getTVLByOwnerOfSharesMultiple(keys, owners);
    }

    function test_getTVLByOwnerOfSharesMultiple_failureIsolation() public {
        address invalidKey = address(0xdead);

        address[] memory keys = new address[](2);
        keys[0] = marketKey6;
        keys[1] = invalidKey;

        address[][] memory owners = new address[][](2);
        owners[0] = new address[](1);
        owners[0][0] = account1;
        owners[1] = new address[](1);
        owners[1][0] = account1;

        (uint256[][] memory tvls, bool[][] memory succeeded) = oracle.getTVLByOwnerOfSharesMultiple(keys, owners);

        assertApproxEqRel(tvls[0][0], 500e6, 1e12);
        assertTrue(succeeded[0][0]);
        assertEq(tvls[1][0], 0);
        assertFalse(succeeded[1][0]);
    }

    /*//////////////////////////////////////////////////////////////
                    CROSS-MARKET CONSISTENCY
    //////////////////////////////////////////////////////////////*/

    function test_crossMarket_differentDebts() public view {
        uint256 tvl6 = oracle.getTVLByOwnerOfShares(marketKey6, account1);
        uint256 tvl18 = oracle.getTVLByOwnerOfShares(marketKey18, account1);
        assertTrue(tvl6 != tvl18, "Different markets should return different debt values");
    }

    function test_crossMarket_differentPPS() public view {
        uint256 pps6 = oracle.getPricePerShare(marketKey6);
        uint256 pps18 = oracle.getPricePerShare(marketKey18);
        assertTrue(pps6 != pps18, "Different decimal markets should have different PPS");
    }

    /*//////////////////////////////////////////////////////////////
                    MOCK STATE CHANGES
    //////////////////////////////////////////////////////////////*/

    function test_mockStateChange_debtIncrease() public {
        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(marketKey6, account1);

        // Increase borrow shares for account1
        _mockPosition(mp6.id(), account1, 0, 1000e12, 0);

        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(marketKey6, account1);
        assertGt(tvlAfter, tvlBefore, "Debt should increase with more borrow shares");
    }

    function test_mockStateChange_debtCleared() public {
        _mockPosition(mp6.id(), account1, 0, 0, 0);
        assertEq(oracle.getBalanceOfOwner(marketKey6, account1), 0);
        assertEq(oracle.getTVLByOwnerOfShares(marketKey6, account1), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function test_fuzz_getShareOutput(uint256 amount) public view {
        vm.assume(amount > 0 && amount < type(uint128).max);
        uint256 shares = oracle.getShareOutput(marketKey6, address(0), amount);
        assertGt(shares, 0, "Non-zero assets should produce non-zero shares");
    }

    function test_fuzz_getAssetOutput(uint256 shares) public view {
        vm.assume(shares > 0 && shares < type(uint128).max);
        uint256 assets = oracle.getAssetOutput(marketKey6, address(0), shares);
        assertGt(assets, 0, "Non-zero shares should produce non-zero assets");
    }

    function test_fuzz_getBalanceOfOwner(uint128 borrowShares) public {
        _mockPosition(mp6.id(), account1, 0, borrowShares, 0);
        assertEq(oracle.getBalanceOfOwner(marketKey6, account1), uint256(borrowShares));
    }

    function test_fuzz_getTVL(uint128 totalBorrows) public {
        _mockMarketState(mp6.id(), TOTAL_SUPPLY_ASSETS, TOTAL_SUPPLY_SHARES, totalBorrows, TOTAL_BORROW_SHARES);
        assertEq(oracle.getTVL(marketKey6), totalBorrows);
    }

    function test_fuzz_ppsNonDecreasing(uint256 elapsed) public {
        vm.assume(elapsed > 0 && elapsed <= 365 days);

        // PPS at time 0
        uint256 ppsBefore = oracle.getPricePerShare(marketKey6);

        // Set lastUpdate to `elapsed` seconds ago
        _mockMarketStateWithTimestamp(mp6.id(), TOTAL_BORROW_ASSETS, TOTAL_BORROW_SHARES, block.timestamp - elapsed);
        uint256 borrowRatePerSecond = 1_585_489_599;
        _mockBorrowRate(borrowRatePerSecond);

        uint256 ppsAfter = oracle.getPricePerShare(marketKey6);
        assertGe(ppsAfter, ppsBefore, "PPS should be non-decreasing with interest");
    }

    /*//////////////////////////////////////////////////////////////
            SECURITY FIX: getAssetOutputWithFees OVERRIDE (P2-1)
    //////////////////////////////////////////////////////////////*/

    /// @notice getAssetOutputWithFees always bypasses fee computation for debt oracle
    function test_getAssetOutputWithFees_bypassesFees() public view {
        uint256 shares = 100e12;
        bytes32 fakeOracleId = keccak256("someOracleId");

        uint256 result = oracle.getAssetOutputWithFees(fakeOracleId, marketKey6, loanToken6, account1, shares);
        uint256 expected = oracle.getAssetOutput(marketKey6, loanToken6, shares);

        assertEq(result, expected, "getAssetOutputWithFees must equal getAssetOutput for debt oracle");
    }

    /// @notice getAssetOutputWithFees ignores yieldSourceOracleId and user params
    function test_getAssetOutputWithFees_ignoresConfigParams() public view {
        uint256 shares = 100e12;

        // Different oracle IDs and users should all produce the same result
        uint256 result1 = oracle.getAssetOutputWithFees(bytes32(0), marketKey6, loanToken6, account1, shares);
        uint256 result2 = oracle.getAssetOutputWithFees(keccak256("id2"), marketKey6, loanToken6, account2, shares);
        uint256 result3 = oracle.getAssetOutputWithFees(keccak256("id3"), marketKey6, loanToken6, address(0), shares);

        assertEq(result1, result2, "Different oracle IDs should produce same result");
        assertEq(result2, result3, "Different users should produce same result");
    }

    /// @notice getAssetOutputWithFees for 18-decimal market
    function test_getAssetOutputWithFees_18dec() public view {
        uint256 shares = 1e24;
        bytes32 fakeOracleId = keccak256("oracleId");

        uint256 result = oracle.getAssetOutputWithFees(fakeOracleId, marketKey18, loanToken18, account1, shares);
        uint256 expected = oracle.getAssetOutput(marketKey18, loanToken18, shares);

        assertEq(result, expected, "18-dec market: getAssetOutputWithFees must equal getAssetOutput");
    }

    /// @notice getAssetOutputWithFees override with zero shares returns zero
    function test_getAssetOutputWithFees_override_zeroShares() public view {
        uint256 result = oracle.getAssetOutputWithFees(bytes32(0), marketKey6, loanToken6, account1, 0);
        assertEq(result, 0, "Zero shares should return zero assets");
    }

    /*//////////////////////////////////////////////////////////////
            SECURITY FIX: getLastUpdate (P3-2)
    //////////////////////////////////////////////////////////////*/

    /// @notice getLastUpdate returns the mocked lastUpdate timestamp
    function test_getLastUpdate_returnsCurrentTimestamp() public view {
        // setUp mocked lastUpdate = block.timestamp
        uint256 lastUpdate = oracle.getLastUpdate(marketKey6);
        assertEq(lastUpdate, block.timestamp, "lastUpdate should match mocked value");
    }

    /// @notice getLastUpdate reflects stale timestamp when market hasn't been touched
    function test_getLastUpdate_staleTimestamp() public {
        uint256 staleTime = block.timestamp - 7 days;
        _mockMarketStateWithTimestamp(mp6.id(), TOTAL_BORROW_ASSETS, TOTAL_BORROW_SHARES, staleTime);

        uint256 lastUpdate = oracle.getLastUpdate(marketKey6);
        assertEq(lastUpdate, staleTime, "lastUpdate should reflect stale timestamp");
        assertEq(block.timestamp - lastUpdate, 7 days, "Staleness should be 7 days");
    }

    /// @notice getLastUpdate for 18-decimal market
    function test_getLastUpdate_18dec() public view {
        uint256 lastUpdate = oracle.getLastUpdate(marketKey18);
        assertEq(lastUpdate, block.timestamp, "18-dec market lastUpdate should match");
    }

    /// @notice getLastUpdate reverts for unregistered market
    function test_getLastUpdate_revertsUnregistered() public {
        vm.expectRevert(MorphoBlueMarketRegistry.MARKET_NOT_REGISTERED.selector);
        oracle.getLastUpdate(address(0xdead));
    }

    /// @notice getLastUpdate with very old timestamp
    function test_getLastUpdate_veryOld() public {
        uint256 oldTime = 1; // timestamp 1
        _mockMarketStateWithTimestamp(mp6.id(), TOTAL_BORROW_ASSETS, TOTAL_BORROW_SHARES, oldTime);

        uint256 lastUpdate = oracle.getLastUpdate(marketKey6);
        assertEq(lastUpdate, 1, "lastUpdate should be 1");
    }
}
