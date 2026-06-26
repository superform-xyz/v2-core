// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { IMorphoBase, IMorphoStaticTyping, MarketParams, Id } from "../../../src/vendor/morpho/IMorpho.sol";
import { MarketParamsLib } from "../../../src/vendor/morpho/MarketParamsLib.sol";

import { MorphoBlueMarketRegistry } from "../../../src/accounting/oracles/MorphoBlueMarketRegistry.sol";
import { MorphoBlueYieldSourceOracle } from "../../../src/accounting/oracles/MorphoBlueYieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { MorphoLendHook } from "../../../src/hooks/loan/morpho/MorphoLendHook.sol";
import { MorphoWithdrawHook } from "../../../src/hooks/loan/morpho/MorphoWithdrawHook.sol";
import { Constants } from "../../utils/Constants.sol";

/// @title MorphoBlueMarketFork
/// @notice Fork tests for MorphoBlueMarketRegistry and MorphoBlueYieldSourceOracle
/// @dev Runs on Ethereum mainnet fork at ETH_BLOCK (21_929_476)
contract MorphoBlueMarketFork is Test, Constants {
    using MarketParamsLib for MarketParams;

    /*//////////////////////////////////////////////////////////////
                            WBTC/USDC MARKET
    //////////////////////////////////////////////////////////////*/

    // loanToken = USDC (6 decimals)
    address constant WBTC_USDC_LOAN_TOKEN = CHAIN_1_USDC;
    address constant WBTC_USDC_COLLATERAL_TOKEN = CHAIN_1_WBTC;
    address constant WBTC_USDC_ORACLE = MORPHO_ORACLE_WBTC_USDC;
    address constant WBTC_USDC_IRM = MORPHO_IRM_WBTC_USDC;
    uint256 constant WBTC_USDC_LLTV = 860_000_000_000_000_000; // 86%

    /*//////////////////////////////////////////////////////////////
                        wstETH/WETH MARKET
    //////////////////////////////////////////////////////////////*/

    // loanToken = WETH (18 decimals)
    address constant WSTETH_WETH_LOAN_TOKEN = CHAIN_1_WETH;
    address constant WSTETH_WETH_COLLATERAL_TOKEN = CHAIN_1_WST_ETH;
    address constant WSTETH_WETH_ORACLE = 0x2a01EB9496094dA03c4E364Def50f5aD1280AD72;
    address constant WSTETH_WETH_IRM = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;
    uint256 constant WSTETH_WETH_LLTV = 945_000_000_000_000_000; // 94.5%

    /*//////////////////////////////////////////////////////////////
                            TEST STATE
    //////////////////////////////////////////////////////////////*/

    MorphoBlueMarketRegistry public registry;
    MorphoBlueYieldSourceOracle public oracle;
    SuperLedgerConfiguration public ledgerConfig;
    MorphoLendHook public lendHook;
    MorphoWithdrawHook public withdrawHook;

    /// @dev Market keys (pseudo-addresses derived from market IDs)
    address public wbtcUsdcKey;
    address public wstethWethKey;

    address public testUser;

    function setUp() public {
        string memory rpcUrl = vm.envString("ETHEREUM_RPC_URL");
        vm.createSelectFork(rpcUrl, ETH_BLOCK);

        ledgerConfig = new SuperLedgerConfiguration();

        // Deploy registry (this test contract is the admin)
        registry = new MorphoBlueMarketRegistry(address(this));

        // Approve IRMs before registering markets that use them
        registry.setIrmApproval(WBTC_USDC_IRM, true);
        registry.setIrmApproval(WSTETH_WETH_IRM, true);

        // Register both markets — returns the market key (pseudo-address)
        wbtcUsdcKey = registry.registerMarket(
            MORPHO, WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM, WBTC_USDC_LLTV
        );

        wstethWethKey = registry.registerMarket(
            MORPHO,
            WSTETH_WETH_LOAN_TOKEN,
            WSTETH_WETH_COLLATERAL_TOKEN,
            WSTETH_WETH_ORACLE,
            WSTETH_WETH_IRM,
            WSTETH_WETH_LLTV
        );

        // Deploy oracle with registry
        oracle = new MorphoBlueYieldSourceOracle(address(ledgerConfig), address(registry));

        // Deploy hooks
        lendHook = new MorphoLendHook(MORPHO);
        withdrawHook = new MorphoWithdrawHook(MORPHO);

        testUser = makeAddr("testUser");
    }

    /*//////////////////////////////////////////////////////////////
                    REGISTRY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_registry_storesMarketParams_wbtcUsdc() public view {
        (MarketParams memory mp, address morpho) = registry.getMarketInfo(wbtcUsdcKey);
        assertEq(morpho, MORPHO);
        assertEq(mp.loanToken, WBTC_USDC_LOAN_TOKEN);
        assertEq(mp.collateralToken, WBTC_USDC_COLLATERAL_TOKEN);
        assertEq(mp.oracle, WBTC_USDC_ORACLE);
        assertEq(mp.irm, WBTC_USDC_IRM);
        assertEq(mp.lltv, WBTC_USDC_LLTV);
    }

    function test_registry_computesCorrectKey() public view {
        // computeMarketKey must return the same key as registerMarket
        address computedKey = registry.computeMarketKey(
            WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM, WBTC_USDC_LLTV
        );
        assertEq(computedKey, wbtcUsdcKey, "computeMarketKey must match registerMarket key");
    }

    function test_registry_rejectsInvalidMarket() public {
        vm.expectRevert(MorphoBlueMarketRegistry.MARKET_DOES_NOT_EXIST_ON_MORPHO.selector);
        registry.registerMarket(
            MORPHO,
            WBTC_USDC_LOAN_TOKEN,
            WBTC_USDC_COLLATERAL_TOKEN,
            WBTC_USDC_ORACLE,
            WBTC_USDC_IRM,
            999_999 // invalid LLTV => different market ID that doesn't exist
        );
    }

    function test_registry_isRegistered() public view {
        assertTrue(registry.isRegistered(wbtcUsdcKey), "wbtcUsdc market must be registered");
        assertTrue(registry.isRegistered(wstethWethKey), "wstethWeth market must be registered");
        assertFalse(registry.isRegistered(address(0xdead)), "unknown key must not be registered");
    }

    function test_registry_deregister_clearsMarket() public {
        assertTrue(registry.isRegistered(wbtcUsdcKey));

        // Step 1: propose — starts the 2-day timelock
        registry.proposeDeregisterMarket(wbtcUsdcKey);
        assertTrue(registry.isRegistered(wbtcUsdcKey), "market still registered during timelock");
        assertGt(registry.pendingDeregistrations(wbtcUsdcKey), 0, "pending deregistration must be set");

        // Step 2: warp past the timelock
        vm.warp(block.timestamp + 2 days + 1);

        // Step 3: execute — removes the market
        registry.executeDeregisterMarket(wbtcUsdcKey);
        assertFalse(registry.isRegistered(wbtcUsdcKey));

        // oracle should now revert for this key
        vm.expectRevert(MorphoBlueMarketRegistry.MARKET_NOT_REGISTERED.selector);
        oracle.getPricePerShare(wbtcUsdcKey);
    }

    function test_registry_onlyMarketManager_canRegister() public {
        address stranger = makeAddr("stranger");
        vm.prank(stranger);
        vm.expectRevert(); // AccessControl revert
        registry.registerMarket(
            MORPHO, WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM, WBTC_USDC_LLTV
        );
    }

    function test_registry_rejectsDoubleRegister() public {
        vm.expectRevert(MorphoBlueMarketRegistry.MARKET_ALREADY_REGISTERED.selector);
        registry.registerMarket(
            MORPHO, WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM, WBTC_USDC_LLTV
        );
    }

    /*//////////////////////////////////////////////////////////////
                    ORACLE TESTS — WBTC/USDC MARKET (6 decimals)
    //////////////////////////////////////////////////////////////*/

    function test_fork_morphoWbtcUsdc_decimals() public view {
        uint8 dec = oracle.decimals(wbtcUsdcKey);
        assertEq(dec, 6, "USDC has 6 decimals");
    }

    function test_fork_morphoWbtcUsdc_pps_nonZero() public view {
        uint256 pps = oracle.getPricePerShare(wbtcUsdcKey);
        console2.log("WBTC/USDC PPS:", pps);
        assertGt(pps, 0, "PPS must be > 0");
        // Morpho supply shares use VIRTUAL_SHARES=1e6, so PPS for a 6-decimal token is ~1 atomic unit (not 1e6)
    }

    function test_fork_morphoWbtcUsdc_pps_withInterestAccrual() public {
        // Read PPS at current block
        uint256 ppsBefore = oracle.getPricePerShare(wbtcUsdcKey);

        // Warp forward 1 day
        vm.warp(block.timestamp + 1 days);

        uint256 ppsAfter = oracle.getPricePerShare(wbtcUsdcKey);
        console2.log("PPS before:", ppsBefore, "PPS after 1d:", ppsAfter);
        // After more time, PPS should be >= (interest accrues)
        assertGe(ppsAfter, ppsBefore, "PPS must not decrease after time passes");
    }

    function test_fork_morphoWbtcUsdc_tvl_nonZero() public view {
        uint256 tvl = oracle.getTVL(wbtcUsdcKey);
        console2.log("WBTC/USDC TVL:", tvl);
        assertGt(tvl, 0, "TVL must be > 0 for active market");
    }

    function test_fork_morphoWbtcUsdc_conversions_consistent() public view {
        uint8 dec = oracle.decimals(wbtcUsdcKey);
        uint256 oneShareUnit = 10 ** dec;

        uint256 pps = oracle.getPricePerShare(wbtcUsdcKey);
        uint256 assetFromOneShare = oracle.getAssetOutput(wbtcUsdcKey, address(0), oneShareUnit);

        // Morpho shares have virtual offset, so PPS == toAssetsDown(10^dec, ...) and
        // getAssetOutput(10^dec) == toAssetsDown(10^dec, ...) — they should match exactly
        assertEq(assetFromOneShare, pps, "getAssetOutput(1 share unit) must equal PPS");
    }

    function test_fork_morphoWbtcUsdc_roundTrip_noValueCreation() public view {
        uint256 assets = 1_000_000; // 1 USDC
        uint256 shares = oracle.getShareOutput(wbtcUsdcKey, address(0), assets);
        uint256 assetsBack = oracle.getAssetOutput(wbtcUsdcKey, address(0), shares);

        // Round-trip should not create value (rounding goes against the user)
        assertLe(assetsBack, assets, "Round trip must not create value");
        console2.log("Assets in:", assets, "Assets back:", assetsBack);
    }

    function test_fork_morphoWbtcUsdc_balanceOfOwner_zeroForFreshAddress() public view {
        uint256 balance = oracle.getBalanceOfOwner(wbtcUsdcKey, testUser);
        assertEq(balance, 0, "Fresh address should have 0 shares");
    }

    /*//////////////////////////////////////////////////////////////
                    ORACLE TESTS — wstETH/WETH MARKET (18 decimals)
    //////////////////////////////////////////////////////////////*/

    function test_fork_morphoWstethWeth_decimals() public view {
        uint8 dec = oracle.decimals(wstethWethKey);
        assertEq(dec, 18, "WETH has 18 decimals");
    }

    function test_fork_morphoWstethWeth_pps_nonZero() public view {
        uint256 pps = oracle.getPricePerShare(wstethWethKey);
        console2.log("wstETH/WETH PPS:", pps);
        assertGt(pps, 0, "PPS must be > 0");
        // Morpho supply shares use VIRTUAL_SHARES=1e6, so PPS for an 18-decimal token is ~1e12 (not 1e18)
    }

    function test_fork_morphoWstethWeth_pps_withInterestAccrual() public {
        uint256 ppsBefore = oracle.getPricePerShare(wstethWethKey);
        vm.warp(block.timestamp + 1 days);
        uint256 ppsAfter = oracle.getPricePerShare(wstethWethKey);
        console2.log("PPS before:", ppsBefore, "PPS after 1d:", ppsAfter);
        assertGe(ppsAfter, ppsBefore, "PPS must not decrease after time passes");
    }

    function test_fork_morphoWstethWeth_tvl_nonZero() public view {
        uint256 tvl = oracle.getTVL(wstethWethKey);
        console2.log("wstETH/WETH TVL:", tvl);
        assertGt(tvl, 0, "TVL must be > 0 for active market");
    }

    function test_fork_morphoWstethWeth_conversions_consistent() public view {
        uint8 dec = oracle.decimals(wstethWethKey);
        uint256 oneShareUnit = 10 ** dec;

        uint256 pps = oracle.getPricePerShare(wstethWethKey);
        uint256 assetFromOneShare = oracle.getAssetOutput(wstethWethKey, address(0), oneShareUnit);

        assertEq(assetFromOneShare, pps, "getAssetOutput(1 share unit) must equal PPS");
    }

    function test_fork_morphoWstethWeth_roundTrip_noValueCreation() public view {
        uint256 assets = 1 ether;
        uint256 shares = oracle.getShareOutput(wstethWethKey, address(0), assets);
        uint256 assetsBack = oracle.getAssetOutput(wstethWethKey, address(0), shares);

        assertLe(assetsBack, assets, "Round trip must not create value");
        console2.log("Assets in:", assets, "Assets back:", assetsBack);
    }

    function test_fork_morphoWstethWeth_balanceOfOwner_zeroForFreshAddress() public view {
        uint256 balance = oracle.getBalanceOfOwner(wstethWethKey, testUser);
        assertEq(balance, 0, "Fresh address should have 0 shares");
    }

    /*//////////////////////////////////////////////////////////////
                SUPPLY + ORACLE INTEGRATION TESTS — WBTC/USDC
    //////////////////////////////////////////////////////////////*/

    function test_fork_morphoWbtcUsdc_supply_oracleReflectsPosition() public {
        uint256 supplyAmount = 10_000e6; // 10,000 USDC
        _supplyToMorpho(
            WBTC_USDC_LOAN_TOKEN,
            WBTC_USDC_COLLATERAL_TOKEN,
            WBTC_USDC_ORACLE,
            WBTC_USDC_IRM,
            WBTC_USDC_LLTV,
            supplyAmount,
            testUser
        );

        // Oracle should reflect the position
        uint256 balance = oracle.getBalanceOfOwner(wbtcUsdcKey, testUser);
        assertGt(balance, 0, "Balance should be > 0 after supply");
        console2.log("Supply shares:", balance);

        uint256 userTvl = oracle.getTVLByOwnerOfShares(wbtcUsdcKey, testUser);
        console2.log("User TVL:", userTvl);
        // TVL should be approximately the supply amount (within rounding)
        assertGe(userTvl, supplyAmount - 1, "User TVL should approximate supply amount");
        assertLe(userTvl, supplyAmount + 1, "User TVL should approximate supply amount");
    }

    function test_fork_morphoWbtcUsdc_supply_ppsStable() public {
        uint256 ppsBefore = oracle.getPricePerShare(wbtcUsdcKey);

        uint256 supplyAmount = 10_000e6;
        _supplyToMorpho(
            WBTC_USDC_LOAN_TOKEN,
            WBTC_USDC_COLLATERAL_TOKEN,
            WBTC_USDC_ORACLE,
            WBTC_USDC_IRM,
            WBTC_USDC_LLTV,
            supplyAmount,
            testUser
        );

        uint256 ppsAfter = oracle.getPricePerShare(wbtcUsdcKey);
        console2.log("PPS before supply:", ppsBefore, "PPS after supply:", ppsAfter);
        // PPS should be identical — supply is proportional, doesn't change the rate
        assertEq(ppsAfter, ppsBefore, "PPS must not change from user deposit");
    }

    function test_fork_morphoWbtcUsdc_supplyAndWithdraw_lifecycle() public {
        uint256 supplyAmount = 10_000e6;
        _supplyToMorpho(
            WBTC_USDC_LOAN_TOKEN,
            WBTC_USDC_COLLATERAL_TOKEN,
            WBTC_USDC_ORACLE,
            WBTC_USDC_IRM,
            WBTC_USDC_LLTV,
            supplyAmount,
            testUser
        );

        // Verify position exists
        uint256 supplyShares = oracle.getBalanceOfOwner(wbtcUsdcKey, testUser);
        assertGt(supplyShares, 0, "Should have supply shares");

        // Withdraw all by shares
        MarketParams memory mp = MarketParams({
            loanToken: WBTC_USDC_LOAN_TOKEN,
            collateralToken: WBTC_USDC_COLLATERAL_TOKEN,
            oracle: WBTC_USDC_ORACLE,
            irm: WBTC_USDC_IRM,
            lltv: WBTC_USDC_LLTV
        });

        vm.prank(testUser);
        IMorphoBase(MORPHO).withdraw(mp, 0, supplyShares, testUser, testUser);

        // Verify position is cleared
        uint256 sharesAfter = oracle.getBalanceOfOwner(wbtcUsdcKey, testUser);
        assertEq(sharesAfter, 0, "Should have 0 shares after full withdrawal");

        // Verify user received assets back
        uint256 usdcBalance = IERC20(WBTC_USDC_LOAN_TOKEN).balanceOf(testUser);
        console2.log("USDC returned:", usdcBalance);
        // Morpho rounds down 1 wei on toSharesDown at deposit; allow 1 wei tolerance
        assertApproxEqAbs(usdcBalance, supplyAmount, 1, "Should receive ~supply amount on withdrawal");
    }

    /*//////////////////////////////////////////////////////////////
                SUPPLY + ORACLE INTEGRATION TESTS — wstETH/WETH
    //////////////////////////////////////////////////////////////*/

    function test_fork_morphoWstethWeth_supply_oracleReflectsPosition() public {
        uint256 supplyAmount = 5 ether;
        _supplyToMorpho(
            WSTETH_WETH_LOAN_TOKEN,
            WSTETH_WETH_COLLATERAL_TOKEN,
            WSTETH_WETH_ORACLE,
            WSTETH_WETH_IRM,
            WSTETH_WETH_LLTV,
            supplyAmount,
            testUser
        );

        uint256 balance = oracle.getBalanceOfOwner(wstethWethKey, testUser);
        assertGt(balance, 0, "Balance should be > 0 after supply");

        uint256 userTvl = oracle.getTVLByOwnerOfShares(wstethWethKey, testUser);
        console2.log("User TVL (WETH):", userTvl);
        assertGe(userTvl, supplyAmount - 1, "User TVL should approximate supply amount");
        assertLe(userTvl, supplyAmount + 1, "User TVL should approximate supply amount");
    }

    function test_fork_morphoWstethWeth_supply_ppsStable() public {
        uint256 ppsBefore = oracle.getPricePerShare(wstethWethKey);

        uint256 supplyAmount = 5 ether;
        _supplyToMorpho(
            WSTETH_WETH_LOAN_TOKEN,
            WSTETH_WETH_COLLATERAL_TOKEN,
            WSTETH_WETH_ORACLE,
            WSTETH_WETH_IRM,
            WSTETH_WETH_LLTV,
            supplyAmount,
            testUser
        );

        uint256 ppsAfter = oracle.getPricePerShare(wstethWethKey);
        assertEq(ppsAfter, ppsBefore, "PPS must not change from user deposit");
    }

    function test_fork_morphoWstethWeth_supplyAndWithdraw_lifecycle() public {
        uint256 supplyAmount = 5 ether;
        _supplyToMorpho(
            WSTETH_WETH_LOAN_TOKEN,
            WSTETH_WETH_COLLATERAL_TOKEN,
            WSTETH_WETH_ORACLE,
            WSTETH_WETH_IRM,
            WSTETH_WETH_LLTV,
            supplyAmount,
            testUser
        );

        uint256 supplyShares = oracle.getBalanceOfOwner(wstethWethKey, testUser);
        assertGt(supplyShares, 0);

        MarketParams memory mp = MarketParams({
            loanToken: WSTETH_WETH_LOAN_TOKEN,
            collateralToken: WSTETH_WETH_COLLATERAL_TOKEN,
            oracle: WSTETH_WETH_ORACLE,
            irm: WSTETH_WETH_IRM,
            lltv: WSTETH_WETH_LLTV
        });

        vm.prank(testUser);
        IMorphoBase(MORPHO).withdraw(mp, 0, supplyShares, testUser, testUser);

        uint256 sharesAfter = oracle.getBalanceOfOwner(wstethWethKey, testUser);
        assertEq(sharesAfter, 0);

        uint256 wethBalance = IERC20(WSTETH_WETH_LOAN_TOKEN).balanceOf(testUser);
        assertApproxEqAbs(wethBalance, supplyAmount, 1, "Should receive ~supply amount on withdrawal");
    }

    /*//////////////////////////////////////////////////////////////
                    HOOK INSPECT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_fork_morphoWbtcUsdc_lendHook_inspect() public view {
        bytes memory hookData = _encodeLendHookData(
            WBTC_USDC_LOAN_TOKEN,
            WBTC_USDC_COLLATERAL_TOKEN,
            WBTC_USDC_ORACLE,
            WBTC_USDC_IRM,
            10_000e6,
            WBTC_USDC_LLTV,
            false
        );

        bytes memory inspected = lendHook.inspect(hookData);
        // inspect returns abi.encodePacked(loanToken, collateralToken, oracle, irm)
        assertEq(inspected.length, 80, "inspect should return 4 addresses packed (80 bytes)");
    }

    function test_fork_morphoWbtcUsdc_withdrawHook_inspect() public view {
        bytes memory hookData = _encodeWithdrawHookData(
            WBTC_USDC_LOAN_TOKEN,
            WBTC_USDC_COLLATERAL_TOKEN,
            WBTC_USDC_ORACLE,
            WBTC_USDC_IRM,
            WBTC_USDC_LLTV,
            10_000e6, // withdraw 10k USDC in assets
            0 // 0 shares
        );

        bytes memory inspected = withdrawHook.inspect(hookData);
        assertEq(inspected.length, 80, "inspect should return 4 addresses packed (80 bytes)");
    }

    /*//////////////////////////////////////////////////////////////
                    WITHDRAWAL SHARE OUTPUT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_fork_morphoWbtcUsdc_withdrawalShareOutput_roundsUp() public view {
        uint256 assets = 1_000_000; // 1 USDC
        uint256 sharesDown = oracle.getShareOutput(wbtcUsdcKey, address(0), assets);
        uint256 sharesUp = oracle.getWithdrawalShareOutput(wbtcUsdcKey, address(0), assets);

        // Withdrawal shares (rounded up) should be >= deposit shares (rounded down)
        assertGe(sharesUp, sharesDown, "Withdrawal shares must be >= deposit shares");
    }

    /*//////////////////////////////////////////////////////////////
                    BATCH METHODS
    //////////////////////////////////////////////////////////////*/

    function test_fork_getPricePerShareMultiple() public view {
        address[] memory keys = new address[](2);
        keys[0] = wbtcUsdcKey;
        keys[1] = wstethWethKey;

        uint256[] memory prices = oracle.getPricePerShareMultiple(keys);
        assertEq(prices.length, 2);
        assertGt(prices[0], 0);
        assertGt(prices[1], 0);
    }

    function test_fork_getTVLMultiple() public view {
        address[] memory keys = new address[](2);
        keys[0] = wbtcUsdcKey;
        keys[1] = wstethWethKey;

        uint256[] memory tvls = oracle.getTVLMultiple(keys);
        assertEq(tvls.length, 2);
        assertGt(tvls[0], 0);
        assertGt(tvls[1], 0);
    }

    /*//////////////////////////////////////////////////////////////
               E2E HOOK + ORACLE LIFECYCLE TESTS — WBTC/USDC
    //////////////////////////////////////////////////////////////*/

    function test_fork_e2e_lendHook_supply_oracleReadsPosition() public {
        uint256 supplyAmount = 10_000e6;

        // Simulate MorphoLendHook executions: approve + supply + approve(reset)
        deal(WBTC_USDC_LOAN_TOKEN, testUser, supplyAmount);
        vm.startPrank(testUser);
        IERC20(WBTC_USDC_LOAN_TOKEN).approve(MORPHO, 0);
        IERC20(WBTC_USDC_LOAN_TOKEN).approve(MORPHO, supplyAmount);
        IMorphoBase(MORPHO).supply(
            MarketParams({
                loanToken: WBTC_USDC_LOAN_TOKEN,
                collateralToken: WBTC_USDC_COLLATERAL_TOKEN,
                oracle: WBTC_USDC_ORACLE,
                irm: WBTC_USDC_IRM,
                lltv: WBTC_USDC_LLTV
            }),
            supplyAmount,
            0,
            testUser,
            ""
        );
        IERC20(WBTC_USDC_LOAN_TOKEN).approve(MORPHO, 0);
        vm.stopPrank();

        // Oracle must reflect the position
        uint256 shares = oracle.getBalanceOfOwner(wbtcUsdcKey, testUser);
        assertGt(shares, 0, "oracle: supply shares must be > 0 after lend hook");

        uint256 tvl = oracle.getTVLByOwnerOfShares(wbtcUsdcKey, testUser);
        assertGe(tvl, supplyAmount - 1, "oracle: TVL must approximate supply amount");
        assertLe(tvl, supplyAmount + 1, "oracle: TVL must not exceed supply amount");

        console2.log("LendHook E2E: shares =", shares, "TVL =", tvl);
    }

    function test_fork_e2e_withdrawHook_withdraw_oracleReadsZero() public {
        // Setup: supply first
        uint256 supplyAmount = 10_000e6;
        _supplyToMorpho(
            WBTC_USDC_LOAN_TOKEN,
            WBTC_USDC_COLLATERAL_TOKEN,
            WBTC_USDC_ORACLE,
            WBTC_USDC_IRM,
            WBTC_USDC_LLTV,
            supplyAmount,
            testUser
        );

        uint256 sharesBefore = oracle.getBalanceOfOwner(wbtcUsdcKey, testUser);
        assertGt(sharesBefore, 0, "must have shares before withdraw");

        // Simulate MorphoWithdrawHook execution: withdraw all by shares
        vm.prank(testUser);
        IMorphoBase(MORPHO).withdraw(
            MarketParams({
                loanToken: WBTC_USDC_LOAN_TOKEN,
                collateralToken: WBTC_USDC_COLLATERAL_TOKEN,
                oracle: WBTC_USDC_ORACLE,
                irm: WBTC_USDC_IRM,
                lltv: WBTC_USDC_LLTV
            }),
            0,
            sharesBefore,
            testUser,
            testUser
        );

        // Oracle must show zero balance after full withdrawal
        uint256 sharesAfter = oracle.getBalanceOfOwner(wbtcUsdcKey, testUser);
        assertEq(sharesAfter, 0, "oracle: shares must be 0 after withdraw hook");

        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(wbtcUsdcKey, testUser);
        assertEq(tvlAfter, 0, "oracle: TVL must be 0 after full withdrawal");

        // User received funds back
        uint256 usdcBalance = IERC20(WBTC_USDC_LOAN_TOKEN).balanceOf(testUser);
        assertApproxEqAbs(usdcBalance, supplyAmount, 1, "user must receive ~supply amount on withdrawal");
        console2.log("WithdrawHook E2E: USDC returned =", usdcBalance);
    }

    function test_fork_e2e_fullLifecycle_lendAndWithdraw_wstethWeth() public {
        uint256 supplyAmount = 5 ether;

        // Simulate MorphoLendHook for wstETH/WETH market
        deal(WSTETH_WETH_LOAN_TOKEN, testUser, supplyAmount);
        vm.startPrank(testUser);
        IERC20(WSTETH_WETH_LOAN_TOKEN).approve(MORPHO, 0);
        IERC20(WSTETH_WETH_LOAN_TOKEN).approve(MORPHO, supplyAmount);
        IMorphoBase(MORPHO).supply(
            MarketParams({
                loanToken: WSTETH_WETH_LOAN_TOKEN,
                collateralToken: WSTETH_WETH_COLLATERAL_TOKEN,
                oracle: WSTETH_WETH_ORACLE,
                irm: WSTETH_WETH_IRM,
                lltv: WSTETH_WETH_LLTV
            }),
            supplyAmount,
            0,
            testUser,
            ""
        );
        IERC20(WSTETH_WETH_LOAN_TOKEN).approve(MORPHO, 0);
        vm.stopPrank();

        // Oracle reflects position
        uint256 shares = oracle.getBalanceOfOwner(wstethWethKey, testUser);
        assertGt(shares, 0, "oracle: must have shares after lend");
        uint256 tvlBeforeWarp = oracle.getTVLByOwnerOfShares(wstethWethKey, testUser);

        // Warp 1 day — interest accrues, TVL should increase
        vm.warp(block.timestamp + 1 days);
        uint256 tvlAfterWarp = oracle.getTVLByOwnerOfShares(wstethWethKey, testUser);
        assertGe(tvlAfterWarp, tvlBeforeWarp, "oracle: TVL must not decrease over time");
        console2.log("wstETH/WETH TVL before warp:", tvlBeforeWarp, "after 1d:", tvlAfterWarp);

        // Simulate MorphoWithdrawHook — withdraw all shares
        vm.prank(testUser);
        IMorphoBase(MORPHO).withdraw(
            MarketParams({
                loanToken: WSTETH_WETH_LOAN_TOKEN,
                collateralToken: WSTETH_WETH_COLLATERAL_TOKEN,
                oracle: WSTETH_WETH_ORACLE,
                irm: WSTETH_WETH_IRM,
                lltv: WSTETH_WETH_LLTV
            }),
            0,
            shares,
            testUser,
            testUser
        );

        // Oracle shows zero
        assertEq(oracle.getBalanceOfOwner(wstethWethKey, testUser), 0, "oracle: zero after withdraw");
        assertEq(oracle.getTVLByOwnerOfShares(wstethWethKey, testUser), 0, "oracle: zero TVL after withdraw");
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_roundTrip_neverCreatesValue_wbtcUsdc(uint256 assets) public view {
        assets = bound(assets, 1, 1e13); // up to 10M USDC
        uint256 shares = oracle.getShareOutput(wbtcUsdcKey, address(0), assets);
        uint256 assetsBack = oracle.getAssetOutput(wbtcUsdcKey, address(0), shares);
        assertLe(assetsBack, assets, "round-trip must not create value");
    }

    function testFuzz_roundTrip_neverCreatesValue_wstethWeth(uint256 assets) public view {
        assets = bound(assets, 1, 1e24); // up to 1M WETH
        uint256 shares = oracle.getShareOutput(wstethWethKey, address(0), assets);
        uint256 assetsBack = oracle.getAssetOutput(wstethWethKey, address(0), shares);
        assertLe(assetsBack, assets, "round-trip must not create value");
    }

    function testFuzz_pps_monotonicallyIncreases_withElapsed(uint32 elapsed) public {
        elapsed = uint32(bound(elapsed, 1, 30 days));
        uint256 ppsBefore = oracle.getPricePerShare(wbtcUsdcKey);
        vm.warp(block.timestamp + elapsed);
        uint256 ppsAfter = oracle.getPricePerShare(wbtcUsdcKey);
        assertGe(ppsAfter, ppsBefore, "PPS must not decrease as time passes");
    }

    function testFuzz_supply_doesNotChangePPS(uint256 supplyAmount) public {
        supplyAmount = bound(supplyAmount, 1e6, 10_000_000e6); // 1 USDC to 10M USDC
        uint256 ppsBefore = oracle.getPricePerShare(wbtcUsdcKey);

        _supplyToMorpho(
            WBTC_USDC_LOAN_TOKEN,
            WBTC_USDC_COLLATERAL_TOKEN,
            WBTC_USDC_ORACLE,
            WBTC_USDC_IRM,
            WBTC_USDC_LLTV,
            supplyAmount,
            testUser
        );

        uint256 ppsAfter = oracle.getPricePerShare(wbtcUsdcKey);
        assertEq(ppsAfter, ppsBefore, "proportional supply must not change PPS");
    }

    function testFuzz_withdrawalShareOutput_geDepositShareOutput(uint256 assets) public view {
        assets = bound(assets, 1, 1e13);
        uint256 depositShares = oracle.getShareOutput(wbtcUsdcKey, address(0), assets);
        uint256 withdrawalShares = oracle.getWithdrawalShareOutput(wbtcUsdcKey, address(0), assets);
        assertGe(withdrawalShares, depositShares, "withdrawal must burn >= deposit shares");
    }

    function testFuzz_tvlByOwner_consistentWithGetAssetOutput(uint256 supplyAmount) public {
        supplyAmount = bound(supplyAmount, 1e6, 1_000_000e6);
        _supplyToMorpho(
            WBTC_USDC_LOAN_TOKEN,
            WBTC_USDC_COLLATERAL_TOKEN,
            WBTC_USDC_ORACLE,
            WBTC_USDC_IRM,
            WBTC_USDC_LLTV,
            supplyAmount,
            testUser
        );

        uint256 shares = oracle.getBalanceOfOwner(wbtcUsdcKey, testUser);
        uint256 assetFromShares = oracle.getAssetOutput(wbtcUsdcKey, address(0), shares);
        uint256 tvl = oracle.getTVLByOwnerOfShares(wbtcUsdcKey, testUser);
        assertEq(tvl, assetFromShares, "TVLByOwner must equal getAssetOutput(getBalanceOfOwner)");
    }

    /*//////////////////////////////////////////////////////////////
              TRUE HOOK LIFECYCLE — WBTC/USDC
              (setExecutionContext → preExecute → ops → postExecute)
    //////////////////////////////////////////////////////////////*/

    /// @notice lendHook.outAmount (supply shares) must equal oracle.getBalanceOfOwner after supply
    function test_hookLifecycle_lend_outAmountMatchesOracleBalance_wbtcUsdc() public {
        uint256 supplyAmount = 10_000e6;
        deal(WBTC_USDC_LOAN_TOKEN, testUser, supplyAmount);

        uint256 hookShares = _supplyViaLendHook(
            WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM,
            WBTC_USDC_LLTV, supplyAmount, testUser
        );

        uint256 oracleShares = oracle.getBalanceOfOwner(wbtcUsdcKey, testUser);
        assertGt(hookShares, 0, "hook: outAmount must be > 0");
        assertEq(hookShares, oracleShares, "hook outAmount must match oracle balance");
        console2.log("WBTC/USDC hook outAmount (shares):", hookShares);
    }

    /// @notice withdrawHook.outAmount (USDC received) must equal actual loanToken balance delta
    function test_hookLifecycle_withdraw_byShares_outAmountIsLoanToken_wbtcUsdc() public {
        uint256 supplyAmount = 10_000e6;
        _supplyToMorpho(
            WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM,
            WBTC_USDC_LLTV, supplyAmount, testUser
        );
        uint256 supplyShares = oracle.getBalanceOfOwner(wbtcUsdcKey, testUser);

        uint256 hookOut = _withdrawViaWithdrawHook(
            WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM,
            WBTC_USDC_LLTV, 0, supplyShares, testUser
        );

        uint256 usdcBalance = IERC20(WBTC_USDC_LOAN_TOKEN).balanceOf(testUser);
        assertGt(hookOut, 0, "hook: outAmount must be > 0");
        assertEq(hookOut, usdcBalance, "hook outAmount must equal USDC received");
        assertApproxEqAbs(hookOut, supplyAmount, 1, "received ~supply amount");
        assertEq(oracle.getBalanceOfOwner(wbtcUsdcKey, testUser), 0, "oracle: zero after full withdrawal");
    }

    /// @notice Partial withdrawal by asset amount: oracle position reduces proportionally
    function test_hookLifecycle_withdraw_byAssets_partial_wbtcUsdc() public {
        uint256 supplyAmount = 20_000e6;
        _supplyToMorpho(
            WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM,
            WBTC_USDC_LLTV, supplyAmount, testUser
        );
        uint256 sharesBefore = oracle.getBalanceOfOwner(wbtcUsdcKey, testUser);

        uint256 partialAssets = 5_000e6;
        uint256 hookOut = _withdrawViaWithdrawHook(
            WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM,
            WBTC_USDC_LLTV, partialAssets, 0, testUser
        );

        uint256 sharesAfter = oracle.getBalanceOfOwner(wbtcUsdcKey, testUser);
        assertEq(hookOut, partialAssets, "hook outAmount must equal withdrawn assets");
        assertGt(sharesAfter, 0, "oracle: must still have shares after partial withdrawal");
        assertLt(sharesAfter, sharesBefore, "oracle: shares must decrease after partial withdrawal");
        console2.log("Partial withdraw: before", sharesBefore, "after", sharesAfter);
    }

    /// @notice Full lend → 30d warp → withdraw: withdrawHook.outAmount > supplyAmount (earned interest)
    function test_hookLifecycle_lendAndWithdraw_earnedInterest_wbtcUsdc() public {
        uint256 supplyAmount = 50_000e6;
        deal(WBTC_USDC_LOAN_TOKEN, testUser, supplyAmount);

        uint256 hookShares = _supplyViaLendHook(
            WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM,
            WBTC_USDC_LLTV, supplyAmount, testUser
        );
        assertEq(hookShares, oracle.getBalanceOfOwner(wbtcUsdcKey, testUser));

        // Interest accrues over 30 days
        vm.warp(block.timestamp + 30 days);

        uint256 tvlAfterWarp = oracle.getTVLByOwnerOfShares(wbtcUsdcKey, testUser);
        assertGt(tvlAfterWarp, supplyAmount, "oracle: TVL must exceed supply after 30d interest");

        uint256 hookUsdcOut = _withdrawViaWithdrawHook(
            WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM,
            WBTC_USDC_LLTV, 0, hookShares, testUser
        );
        assertGt(hookUsdcOut, supplyAmount, "received more USDC than supplied (interest earned)");
        assertEq(oracle.getBalanceOfOwner(wbtcUsdcKey, testUser), 0, "oracle: zero after full withdrawal");
        console2.log("Supply:", supplyAmount, "Received after 30d:", hookUsdcOut);
    }

    /// @notice withdrawHook.outAmount matches oracle.getTVLByOwnerOfShares pre-withdrawal (within 1 wei)
    function test_hookLifecycle_oracleTvl_matchesWithdrawHookOut_wbtcUsdc() public {
        uint256 supplyAmount = 10_000e6;
        _supplyToMorpho(
            WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM,
            WBTC_USDC_LLTV, supplyAmount, testUser
        );

        // oracle TVL before withdrawal = expected withdrawal proceeds
        uint256 oracleTvlBefore = oracle.getTVLByOwnerOfShares(wbtcUsdcKey, testUser);
        uint256 supplyShares = oracle.getBalanceOfOwner(wbtcUsdcKey, testUser);

        uint256 hookOut = _withdrawViaWithdrawHook(
            WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM,
            WBTC_USDC_LLTV, 0, supplyShares, testUser
        );

        // hook outAmount (assets received) must be within 1 wei of oracle-predicted TVL
        // (oracle rounds down, Morpho rounds down — both conservative; max 1 wei drift)
        assertApproxEqAbs(hookOut, oracleTvlBefore, 1, "hookOut must equal oracle TVL (+/-1 wei)");
    }

    /// @notice Multiple sequential lends accumulate correctly in oracle
    function test_hookLifecycle_multipleLends_oracleAccumulates_wbtcUsdc() public {
        uint256 firstLend = 5_000e6;
        uint256 secondLend = 3_000e6;

        deal(WBTC_USDC_LOAN_TOKEN, testUser, firstLend + secondLend);

        uint256 shares1 = _supplyViaLendHook(
            WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM,
            WBTC_USDC_LLTV, firstLend, testUser
        );
        uint256 oracleShares1 = oracle.getBalanceOfOwner(wbtcUsdcKey, testUser);
        assertEq(shares1, oracleShares1, "first lend: hook shares == oracle shares");

        uint256 shares2 = _supplyViaLendHook(
            WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM,
            WBTC_USDC_LLTV, secondLend, testUser
        );
        uint256 oracleSharesTotal = oracle.getBalanceOfOwner(wbtcUsdcKey, testUser);
        assertEq(oracleSharesTotal, oracleShares1 + shares2, "total oracle shares = sum of hook outAmounts");

        uint256 totalTvl = oracle.getTVLByOwnerOfShares(wbtcUsdcKey, testUser);
        assertGe(totalTvl, firstLend + secondLend - 2, "TVL must be ~= both supplies combined");
    }

    /*//////////////////////////////////////////////////////////////
              TRUE HOOK LIFECYCLE — wstETH/WETH
    //////////////////////////////////////////////////////////////*/

    /// @notice lendHook.outAmount == oracle.getBalanceOfOwner for 18-decimal token
    function test_hookLifecycle_lend_outAmountMatchesOracleBalance_wstethWeth() public {
        uint256 supplyAmount = 5 ether;
        deal(WSTETH_WETH_LOAN_TOKEN, testUser, supplyAmount);

        uint256 hookShares = _supplyViaLendHook(
            WSTETH_WETH_LOAN_TOKEN, WSTETH_WETH_COLLATERAL_TOKEN, WSTETH_WETH_ORACLE, WSTETH_WETH_IRM,
            WSTETH_WETH_LLTV, supplyAmount, testUser
        );

        uint256 oracleShares = oracle.getBalanceOfOwner(wstethWethKey, testUser);
        assertGt(hookShares, 0, "hook: outAmount must be > 0");
        assertEq(hookShares, oracleShares, "hook outAmount must match oracle balance");
        console2.log("wstETH/WETH hook outAmount (shares):", hookShares);
    }

    /// @notice Full lend → 30d → withdraw: earned interest in wstETH/WETH market
    function test_hookLifecycle_lendAndWithdraw_earnedInterest_wstethWeth() public {
        uint256 supplyAmount = 10 ether;
        deal(WSTETH_WETH_LOAN_TOKEN, testUser, supplyAmount);

        uint256 hookShares = _supplyViaLendHook(
            WSTETH_WETH_LOAN_TOKEN, WSTETH_WETH_COLLATERAL_TOKEN, WSTETH_WETH_ORACLE, WSTETH_WETH_IRM,
            WSTETH_WETH_LLTV, supplyAmount, testUser
        );

        vm.warp(block.timestamp + 30 days);

        uint256 tvlAfterWarp = oracle.getTVLByOwnerOfShares(wstethWethKey, testUser);
        assertGt(tvlAfterWarp, supplyAmount, "oracle: TVL must exceed supply after 30d interest");

        uint256 hookWethOut = _withdrawViaWithdrawHook(
            WSTETH_WETH_LOAN_TOKEN, WSTETH_WETH_COLLATERAL_TOKEN, WSTETH_WETH_ORACLE, WSTETH_WETH_IRM,
            WSTETH_WETH_LLTV, 0, hookShares, testUser
        );
        assertGt(hookWethOut, supplyAmount, "received more WETH than supplied (interest earned)");
        console2.log("wstETH/WETH supply:", supplyAmount, "received after 30d:", hookWethOut);
    }

    /*//////////////////////////////////////////////////////////////
              MULTI-USER AND MULTI-MARKET ISOLATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Two users supply to same market — oracle reads each position independently
    function test_multiUser_independentPositions_wbtcUsdc() public {
        address user2 = makeAddr("user2");
        uint256 amount1 = 10_000e6;
        uint256 amount2 = 25_000e6;

        deal(WBTC_USDC_LOAN_TOKEN, testUser, amount1);
        deal(WBTC_USDC_LOAN_TOKEN, user2, amount2);

        _supplyViaLendHook(
            WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM,
            WBTC_USDC_LLTV, amount1, testUser
        );
        _supplyViaLendHook(
            WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM,
            WBTC_USDC_LLTV, amount2, user2
        );

        uint256 shares1 = oracle.getBalanceOfOwner(wbtcUsdcKey, testUser);
        uint256 shares2 = oracle.getBalanceOfOwner(wbtcUsdcKey, user2);

        assertGt(shares1, 0, "user1 must have shares");
        assertGt(shares2, 0, "user2 must have shares");
        assertGt(shares2, shares1, "user2 supplied more, must have more shares");

        uint256 tvl1 = oracle.getTVLByOwnerOfShares(wbtcUsdcKey, testUser);
        uint256 tvl2 = oracle.getTVLByOwnerOfShares(wbtcUsdcKey, user2);
        assertGe(tvl1, amount1 - 1, "user1 TVL ~= amount1");
        assertGe(tvl2, amount2 - 1, "user2 TVL ~= amount2");

        console2.log("User1 shares:", shares1, "TVL:", tvl1);
        console2.log("User2 shares:", shares2, "TVL:", tvl2);
    }

    /// @notice Same user supplies to both markets — oracle reads both positions independently
    function test_multiMarket_sameUser_bothPositions() public {
        uint256 usdcAmount = 10_000e6;
        uint256 wethAmount = 5 ether;

        deal(WBTC_USDC_LOAN_TOKEN, testUser, usdcAmount);
        deal(WSTETH_WETH_LOAN_TOKEN, testUser, wethAmount);

        uint256 usdcShares = _supplyViaLendHook(
            WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM,
            WBTC_USDC_LLTV, usdcAmount, testUser
        );
        uint256 wethShares = _supplyViaLendHook(
            WSTETH_WETH_LOAN_TOKEN, WSTETH_WETH_COLLATERAL_TOKEN, WSTETH_WETH_ORACLE, WSTETH_WETH_IRM,
            WSTETH_WETH_LLTV, wethAmount, testUser
        );

        // Oracle reads both positions in same call
        assertEq(oracle.getBalanceOfOwner(wbtcUsdcKey, testUser), usdcShares, "USDC market: oracle == hook");
        assertEq(oracle.getBalanceOfOwner(wstethWethKey, testUser), wethShares, "WETH market: oracle == hook");

        // TVL denominated in respective loan tokens
        uint256 usdcTvl = oracle.getTVLByOwnerOfShares(wbtcUsdcKey, testUser);
        uint256 wethTvl = oracle.getTVLByOwnerOfShares(wstethWethKey, testUser);
        assertGe(usdcTvl, usdcAmount - 1, "USDC TVL ~= supplied");
        assertGe(wethTvl, wethAmount - 1, "WETH TVL ~= supplied");

        // Batch query returns both
        address[] memory keys = new address[](2);
        keys[0] = wbtcUsdcKey;
        keys[1] = wstethWethKey;
        uint256[] memory tvls = oracle.getTVLMultiple(keys);
        assertGt(tvls[0], 0, "batch USDC TVL > 0");
        assertGt(tvls[1], 0, "batch WETH TVL > 0");
    }

    /// @notice User withdraws from one market, the other market position is unaffected
    function test_multiMarket_withdrawOne_otherUnchanged() public {
        uint256 usdcAmount = 10_000e6;
        uint256 wethAmount = 5 ether;
        deal(WBTC_USDC_LOAN_TOKEN, testUser, usdcAmount);
        deal(WSTETH_WETH_LOAN_TOKEN, testUser, wethAmount);

        uint256 usdcShares = _supplyViaLendHook(
            WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM,
            WBTC_USDC_LLTV, usdcAmount, testUser
        );
        _supplyViaLendHook(
            WSTETH_WETH_LOAN_TOKEN, WSTETH_WETH_COLLATERAL_TOKEN, WSTETH_WETH_ORACLE, WSTETH_WETH_IRM,
            WSTETH_WETH_LLTV, wethAmount, testUser
        );

        // Withdraw from USDC market only
        _withdrawViaWithdrawHook(
            WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM,
            WBTC_USDC_LLTV, 0, usdcShares, testUser
        );

        // USDC position is gone, WETH position is unchanged
        assertEq(oracle.getBalanceOfOwner(wbtcUsdcKey, testUser), 0, "USDC market: cleared after withdrawal");
        assertGt(oracle.getBalanceOfOwner(wstethWethKey, testUser), 0, "WETH market: unaffected");
    }

    /*//////////////////////////////////////////////////////////////
              ORACLE ACCRUAL CROSS-CHECKS
    //////////////////////////////////////////////////////////////*/

    /// @notice Oracle TVL for a user exceeds stale Morpho stored state after time warp
    function test_fork_oracleAccrual_exceedsStoredMorphoState_wbtcUsdc() public {
        uint256 supplyAmount = 100_000e6;
        _supplyToMorpho(
            WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM,
            WBTC_USDC_LLTV, supplyAmount, testUser
        );

        // Record oracle TVL at current block (no time elapsed)
        uint256 tvlAtBlock = oracle.getTVL(wbtcUsdcKey);

        // Warp 30 days — Morpho's stored state is stale, oracle accrues in-view
        vm.warp(block.timestamp + 30 days);

        uint256 tvlAfterWarp = oracle.getTVL(wbtcUsdcKey);

        // Query raw Morpho state (NOT accrued) by reading totalSupplyAssets directly
        (uint128 storedTotalSupply,,,,, ) = IMorphoStaticTyping(MORPHO).market(
            MarketParamsLib.id(MarketParams({
                loanToken: WBTC_USDC_LOAN_TOKEN,
                collateralToken: WBTC_USDC_COLLATERAL_TOKEN,
                oracle: WBTC_USDC_ORACLE,
                irm: WBTC_USDC_IRM,
                lltv: WBTC_USDC_LLTV
            }))
        );

        // Oracle must reflect accrued interest; raw Morpho state is stale
        assertGt(tvlAfterWarp, tvlAtBlock, "oracle TVL must increase after time warp");
        assertGt(tvlAfterWarp, uint256(storedTotalSupply), "oracle TVL must exceed stale Morpho stored state");

        uint256 interestAccrued = tvlAfterWarp - tvlAtBlock;
        console2.log("TVL at block:", tvlAtBlock, "after 30d:", tvlAfterWarp);
        console2.log("Interest accrued:", interestAccrued);
    }

    /// @notice 30-day accrual: wstETH/WETH position TVL increases
    function test_fork_oracleAccrual_wstethWeth_30days() public {
        uint256 supplyAmount = 10 ether;
        _supplyToMorpho(
            WSTETH_WETH_LOAN_TOKEN, WSTETH_WETH_COLLATERAL_TOKEN, WSTETH_WETH_ORACLE, WSTETH_WETH_IRM,
            WSTETH_WETH_LLTV, supplyAmount, testUser
        );

        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(wstethWethKey, testUser);
        uint256 ppsBefore = oracle.getPricePerShare(wstethWethKey);

        vm.warp(block.timestamp + 30 days);

        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(wstethWethKey, testUser);
        uint256 ppsAfter = oracle.getPricePerShare(wstethWethKey);

        assertGt(tvlAfter, tvlBefore, "user TVL must increase over 30 days");
        assertGe(ppsAfter, ppsBefore, "PPS must not decrease over 30 days");
        console2.log("wstETH/WETH TVL before:", tvlBefore, "after 30d:", tvlAfter);
    }

    /// @notice PPS is continuous: each day step increases PPS or keeps it the same
    function test_fork_pps_continuouslyIncreases_dayByDay_wbtcUsdc() public {
        uint256 ppsPrev = oracle.getPricePerShare(wbtcUsdcKey);
        for (uint256 d = 1; d <= 7; d++) {
            vm.warp(block.timestamp + 1 days);
            uint256 ppsCur = oracle.getPricePerShare(wbtcUsdcKey);
            assertGe(ppsCur, ppsPrev, "PPS must not decrease day-over-day");
            ppsPrev = ppsCur;
        }
    }

    /// @notice Large withdrawal does not push oracle TVL negative or cause overflow
    function test_fork_largeWithdraw_oracleRemainsConsistent_wbtcUsdc() public {
        uint256 supplyAmount = 1_000_000e6; // 1M USDC
        _supplyToMorpho(
            WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM,
            WBTC_USDC_LLTV, supplyAmount, testUser
        );

        uint256 supplyShares = oracle.getBalanceOfOwner(wbtcUsdcKey, testUser);
        uint256 tvlBefore = oracle.getTVL(wbtcUsdcKey);

        vm.prank(testUser);
        IMorphoBase(MORPHO).withdraw(
            MarketParams({
                loanToken: WBTC_USDC_LOAN_TOKEN, collateralToken: WBTC_USDC_COLLATERAL_TOKEN,
                oracle: WBTC_USDC_ORACLE, irm: WBTC_USDC_IRM, lltv: WBTC_USDC_LLTV
            }),
            0, supplyShares, testUser, testUser
        );

        uint256 tvlAfter = oracle.getTVL(wbtcUsdcKey);
        assertLt(tvlAfter, tvlBefore, "oracle TVL must decrease after large withdrawal");
        assertEq(oracle.getBalanceOfOwner(wbtcUsdcKey, testUser), 0, "oracle: zero balance after full withdrawal");
        console2.log("TVL before 1M withdraw:", tvlBefore, "after:", tvlAfter);
    }

    /// @notice Zero-amount operations don't corrupt oracle state
    function test_fork_zeroBalance_oracleReturnsZero_bothMarkets() public {
        address freshUser = makeAddr("freshUser");
        // Both markets should return 0 for unrelated address
        assertEq(oracle.getBalanceOfOwner(wbtcUsdcKey, freshUser), 0);
        assertEq(oracle.getBalanceOfOwner(wstethWethKey, freshUser), 0);
        assertEq(oracle.getTVLByOwnerOfShares(wbtcUsdcKey, freshUser), 0);
        assertEq(oracle.getTVLByOwnerOfShares(wstethWethKey, freshUser), 0);
    }

    /*//////////////////////////////////////////////////////////////
              ADDITIONAL FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice hook.outAmount always equals oracle.getBalanceOfOwner after any lend amount
    function testFuzz_hookLifecycle_lend_outAmountMatchesOracleBalance(uint256 supplyAmount) public {
        supplyAmount = bound(supplyAmount, 1e6, 10_000_000e6); // 1 USDC to 10M USDC
        deal(WBTC_USDC_LOAN_TOKEN, testUser, supplyAmount);

        uint256 hookShares = _supplyViaLendHook(
            WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM,
            WBTC_USDC_LLTV, supplyAmount, testUser
        );

        uint256 oracleShares = oracle.getBalanceOfOwner(wbtcUsdcKey, testUser);
        assertEq(hookShares, oracleShares, "hook outAmount must always equal oracle balance");
    }

    /// @notice Withdraw hook outAmount <= lend amount for immediate withdraw (no interest)
    function testFuzz_hookLifecycle_immediateWithdraw_outAmountLeSupply(uint256 supplyAmount) public {
        supplyAmount = bound(supplyAmount, 1e6, 1_000_000e6);
        deal(WBTC_USDC_LOAN_TOKEN, testUser, supplyAmount);

        uint256 hookShares = _supplyViaLendHook(
            WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM,
            WBTC_USDC_LLTV, supplyAmount, testUser
        );

        uint256 hookUsdcOut = _withdrawViaWithdrawHook(
            WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM,
            WBTC_USDC_LLTV, 0, hookShares, testUser
        );

        // Immediate withdrawal: can only be <= supply (Morpho rounds down on deposit)
        assertLe(hookUsdcOut, supplyAmount, "immediate withdraw cannot exceed supply amount");
        assertApproxEqAbs(hookUsdcOut, supplyAmount, 1, "immediate withdraw should be ~supply (within 1 wei)");
    }

    /// @notice Oracle TVL after warp is always >= oracle TVL before warp (interest never negative)
    function testFuzz_oracle_tvl_neverDecreases_withTimeWarp(uint32 elapsed) public {
        elapsed = uint32(bound(elapsed, 1, 365 days));

        _supplyToMorpho(
            WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM,
            WBTC_USDC_LLTV, 10_000e6, testUser
        );

        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(wbtcUsdcKey, testUser);
        vm.warp(block.timestamp + elapsed);
        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(wbtcUsdcKey, testUser);
        assertGe(tvlAfter, tvlBefore, "user TVL must never decrease with time");
    }

    /*//////////////////////////////////////////////////////////////
              SECURITY FIX TESTS — REGISTRY
    //////////////////////////////////////////////////////////////*/

    // --- IRM whitelist (P0-01 / P1-01) ---

    function test_registry_setIrmApproval_approvesAndRevokes() public {
        address irm = makeAddr("someIrm");
        assertFalse(registry.approvedIrms(irm), "IRM must start unapproved");

        vm.expectEmit(true, false, false, true);
        emit MorphoBlueMarketRegistry.IrmApprovalSet(irm, true);
        registry.setIrmApproval(irm, true);
        assertTrue(registry.approvedIrms(irm), "IRM must be approved after setIrmApproval");

        vm.expectEmit(true, false, false, true);
        emit MorphoBlueMarketRegistry.IrmApprovalSet(irm, false);
        registry.setIrmApproval(irm, false);
        assertFalse(registry.approvedIrms(irm), "IRM must be revoked after setIrmApproval(false)");
    }

    function test_registry_rejectsUnapprovedIRM() public {
        // Fresh registry with no IRM approvals
        MorphoBlueMarketRegistry freshRegistry = new MorphoBlueMarketRegistry(address(this));
        vm.expectRevert(MorphoBlueMarketRegistry.IRM_NOT_APPROVED.selector);
        freshRegistry.registerMarket(
            MORPHO, WBTC_USDC_LOAN_TOKEN, WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM, WBTC_USDC_LLTV
        );
    }

    function test_registry_onlyMarketManager_canSetIrmApproval() public {
        address stranger = makeAddr("stranger");
        vm.prank(stranger);
        vm.expectRevert(); // AccessControl revert
        registry.setIrmApproval(makeAddr("irm"), true);
    }

    // --- Input validation (P2-03 / P2-05) ---

    function test_registry_rejectsZeroLoanToken() public {
        vm.expectRevert(MorphoBlueMarketRegistry.INVALID_LOAN_TOKEN.selector);
        registry.registerMarket(
            MORPHO, address(0), WBTC_USDC_COLLATERAL_TOKEN, WBTC_USDC_ORACLE, WBTC_USDC_IRM, WBTC_USDC_LLTV
        );
    }

    function test_registry_constructorRejectsZeroAdmin() public {
        vm.expectRevert(MorphoBlueMarketRegistry.ZERO_ADDRESS.selector);
        new MorphoBlueMarketRegistry(address(0));
    }

    // --- Deregistration timelock (P1-04) ---

    function test_registry_deregister_rejectsExecuteWithoutProposal() public {
        vm.expectRevert(MorphoBlueMarketRegistry.DEREGISTRATION_NOT_PENDING.selector);
        registry.executeDeregisterMarket(wbtcUsdcKey);
    }

    function test_registry_deregister_rejectsCancelWithoutProposal() public {
        vm.expectRevert(MorphoBlueMarketRegistry.DEREGISTRATION_NOT_PENDING.selector);
        registry.cancelDeregisterMarket(wbtcUsdcKey);
    }

    function test_registry_deregister_rejectsEarlyExecution() public {
        registry.proposeDeregisterMarket(wbtcUsdcKey);
        // Warp just under the delay — should still revert
        vm.warp(block.timestamp + 2 days - 1);
        vm.expectRevert(MorphoBlueMarketRegistry.DEREGISTRATION_TIMELOCK_NOT_ELAPSED.selector);
        registry.executeDeregisterMarket(wbtcUsdcKey);
        // Market must still be registered
        assertTrue(registry.isRegistered(wbtcUsdcKey));
    }

    function test_registry_deregister_proposeThenCancel_marketStillRegistered() public {
        registry.proposeDeregisterMarket(wbtcUsdcKey);
        assertGt(registry.pendingDeregistrations(wbtcUsdcKey), 0, "pending must be set after propose");

        vm.expectEmit(true, false, false, false);
        emit MorphoBlueMarketRegistry.MarketDeregistrationCancelled(wbtcUsdcKey);
        registry.cancelDeregisterMarket(wbtcUsdcKey);

        assertEq(registry.pendingDeregistrations(wbtcUsdcKey), 0, "pending must be cleared after cancel");
        assertTrue(registry.isRegistered(wbtcUsdcKey), "market must still be registered after cancel");
    }

    function test_registry_deregister_proposeResetsTimelock() public {
        registry.proposeDeregisterMarket(wbtcUsdcKey);
        uint256 first = registry.pendingDeregistrations(wbtcUsdcKey);

        vm.warp(block.timestamp + 1 days);
        registry.proposeDeregisterMarket(wbtcUsdcKey); // re-propose resets
        uint256 second = registry.pendingDeregistrations(wbtcUsdcKey);

        assertGt(second, first, "re-propose must push executeAfter forward");
    }

    /*//////////////////////////////////////////////////////////////
          SECURITY FIX TESTS — ORACLE
    //////////////////////////////////////////////////////////////*/

    function test_oracle_constructorRejectsZeroRegistry() public {
        vm.expectRevert(MorphoBlueYieldSourceOracle.ZERO_ADDRESS.selector);
        new MorphoBlueYieldSourceOracle(address(ledgerConfig), address(0));
    }

    /// @notice Verifies the 365-day elapsed cap prevents overflow / revert after extended chain downtime
    function test_oracle_elapsedCap_noOverflowAfterLongTime() public {
        // Warp 400 days past the fork block — elapsed far exceeds the 365-day cap
        vm.warp(block.timestamp + 400 days);
        // Without the cap, wTaylorCompounded could overflow for high borrow rates over extreme elapsed
        uint256 pps = oracle.getPricePerShare(wbtcUsdcKey);
        assertGt(pps, 0, "PPS must be > 0 after 400-day warp");
        uint256 tvl = oracle.getTVL(wbtcUsdcKey);
        assertGt(tvl, 0, "TVL must be > 0 after 400-day warp");
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Supplies loanToken to a Morpho Blue market on behalf of `user`
    function _supplyToMorpho(
        address loanToken,
        address collateralToken,
        address mOracle,
        address mIrm,
        uint256 lltv,
        uint256 amount,
        address user
    )
        internal
    {
        deal(loanToken, user, amount);

        vm.startPrank(user);
        IERC20(loanToken).approve(MORPHO, amount);

        MarketParams memory mp = MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: mOracle,
            irm: mIrm,
            lltv: lltv
        });

        IMorphoBase(MORPHO).supply(mp, amount, 0, user, "");
        vm.stopPrank();
    }

    /// @dev Encodes data for MorphoLendHook (145-byte layout)
    function _encodeLendHookData(
        address loanToken,
        address collateralToken,
        address mOracle,
        address mIrm,
        uint256 amount,
        uint256 lltv,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            loanToken, // 20 bytes, offset 0
            collateralToken, // 20 bytes, offset 20
            mOracle, // 20 bytes, offset 40
            mIrm, // 20 bytes, offset 60
            amount, // 32 bytes, offset 80
            lltv, // 32 bytes, offset 112
            usePrevHookAmount // 1 byte, offset 144
        );
    }

    /// @dev Encodes data for MorphoWithdrawHook (176-byte layout)
    function _encodeWithdrawHookData(
        address loanToken,
        address collateralToken,
        address mOracle,
        address mIrm,
        uint256 lltv,
        uint256 assets,
        uint256 shares
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            loanToken, // 20 bytes, offset 0
            collateralToken, // 20 bytes, offset 20
            mOracle, // 20 bytes, offset 40
            mIrm, // 20 bytes, offset 60
            lltv, // 32 bytes, offset 80
            assets, // 32 bytes, offset 112
            shares // 32 bytes, offset 144
        );
    }

    /// @dev Full MorphoLendHook lifecycle: setExecutionContext → preExecute → approve+supply → postExecute
    /// @dev Gives `user` exactly `amount` of loanToken via deal, then runs the full hook lifecycle.
    ///      Mirrors the execution sequence the SuperExecutor builds via lendHook.build().
    /// @return outAmount Supply shares received, as reported by lendHook.getOutAmount(user)
    function _supplyViaLendHook(
        address loanToken,
        address collateralToken,
        address mOracle,
        address mIrm,
        uint256 lltv,
        uint256 amount,
        address user
    )
        internal
        returns (uint256 outAmount)
    {
        bytes memory hookData = _encodeLendHookData(loanToken, collateralToken, mOracle, mIrm, amount, lltv, false);

        deal(loanToken, user, amount);

        // Create execution context for user (test contract becomes lastCaller)
        lendHook.setExecutionContext(user);

        // preExecute: snapshots pre-supply shares into transient outAmount slot
        vm.prank(user);
        lendHook.preExecute(address(0), user, hookData);

        // Replicate the executions built by lendHook.build(): reset approval, approve, supply, reset approval
        vm.startPrank(user);
        IERC20(loanToken).approve(MORPHO, 0);
        IERC20(loanToken).approve(MORPHO, amount);
        IMorphoBase(MORPHO).supply(
            MarketParams({
                loanToken: loanToken,
                collateralToken: collateralToken,
                oracle: mOracle,
                irm: mIrm,
                lltv: lltv
            }),
            amount,
            0,
            user,
            ""
        );
        IERC20(loanToken).approve(MORPHO, 0);
        vm.stopPrank();

        // postExecute: computes delta (post_shares - pre_shares) → shares received
        vm.prank(user);
        lendHook.postExecute(address(0), user, hookData);

        outAmount = lendHook.getOutAmount(user);
    }

    /// @dev Full MorphoWithdrawHook lifecycle: setExecutionContext → preExecute → withdraw → postExecute
    /// @dev Pass either assets>0,shares=0 (withdraw by asset amount) or assets=0,shares>0 (withdraw by share count).
    ///      Mirrors the execution sequence the SuperExecutor builds via withdrawHook.build().
    /// @return outAmount Loan tokens received, as reported by withdrawHook.getOutAmount(user)
    function _withdrawViaWithdrawHook(
        address loanToken,
        address collateralToken,
        address mOracle,
        address mIrm,
        uint256 lltv,
        uint256 assets,
        uint256 shares,
        address user
    )
        internal
        returns (uint256 outAmount)
    {
        bytes memory hookData =
            _encodeWithdrawHookData(loanToken, collateralToken, mOracle, mIrm, lltv, assets, shares);

        // Create execution context for user (test contract becomes lastCaller)
        withdrawHook.setExecutionContext(user);

        // preExecute: snapshots pre-withdraw loanToken balance into transient outAmount slot
        vm.prank(user);
        withdrawHook.preExecute(address(0), user, hookData);

        // Replicate the single execution built by withdrawHook.build(): Morpho.withdraw
        vm.prank(user);
        IMorphoBase(MORPHO).withdraw(
            MarketParams({
                loanToken: loanToken,
                collateralToken: collateralToken,
                oracle: mOracle,
                irm: mIrm,
                lltv: lltv
            }),
            assets,
            shares,
            user,
            user
        );

        // postExecute: computes delta (post_balance - pre_balance) → loanToken received
        vm.prank(user);
        withdrawHook.postExecute(address(0), user, hookData);

        outAmount = withdrawHook.getOutAmount(user);
    }
}
