// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { FirelightYieldSourceOracle } from "../../../src/accounting/oracles/FirelightYieldSourceOracle.sol";
import { IFirelightVault } from "../../../src/vendor/vaults/firelight/IFirelightVault.sol";
import { IYieldSourceOracle } from "../../../src/interfaces/accounting/IYieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperLedger } from "../../../src/interfaces/accounting/ISuperLedger.sol";
import { SuperLedger } from "../../../src/accounting/SuperLedger.sol";

/*//////////////////////////////////////////////////////////////
                        MOCK VAULT
//////////////////////////////////////////////////////////////*/

/// @notice Mock Firelight vault simulating period-based async withdrawal system
contract MockFirelightVault {
    uint8 public decimals;
    uint256 public totalAssets;
    uint256 public currentPeriod;

    // Exchange rate: assetsPerShare = _assetsPerShareNumerator / 10^decimals
    uint256 private _assetsPerShareNumerator;

    mapping(address => uint256) public balanceOf;
    mapping(uint256 => mapping(address => uint256)) public withdrawalsOf;
    mapping(uint256 => mapping(address => bool)) public isWithdrawClaimed;

    address public asset;

    constructor(uint8 decimals_, uint256 assetsPerShareNumerator_) {
        decimals = decimals_;
        _assetsPerShareNumerator = assetsPerShareNumerator_;
        asset = address(0xA55E7);
    }

    function convertToAssets(uint256 shares) external view returns (uint256) {
        uint256 oneShare = 10 ** decimals;
        return Math.mulDiv(shares, _assetsPerShareNumerator, oneShare);
    }

    function convertToShares(uint256 assets) external view returns (uint256) {
        uint256 oneShare = 10 ** decimals;
        return Math.mulDiv(assets, oneShare, _assetsPerShareNumerator);
    }

    function redeem(uint256 shares, address, address owner) external returns (uint256 assets) {
        uint256 oneShare = 10 ** decimals;
        assets = Math.mulDiv(shares, _assetsPerShareNumerator, oneShare);
        balanceOf[owner] -= shares;
        withdrawalsOf[currentPeriod + 1][owner] += assets;
        totalAssets -= assets;
    }

    function claimWithdraw(uint256 /*requestId*/ ) external { }

    // Test helpers
    function setBalance(address account, uint256 amount) external {
        balanceOf[account] = amount;
    }

    function setCurrentPeriod(uint256 period) external {
        currentPeriod = period;
    }

    function setWithdrawalsOf(uint256 period, address account, uint256 amount) external {
        withdrawalsOf[period][account] = amount;
    }

    function setIsWithdrawClaimed(uint256 period, address account, bool claimed) external {
        isWithdrawClaimed[period][account] = claimed;
    }

    function setTotalAssets(uint256 amount) external {
        totalAssets = amount;
    }

    function setAssetsPerShareNumerator(uint256 numerator) external {
        _assetsPerShareNumerator = numerator;
    }
}

/*//////////////////////////////////////////////////////////////
                        TEST CONTRACT
//////////////////////////////////////////////////////////////*/

/// @title FirelightYieldSourceOracleTest
/// @notice Comprehensive unit tests for FirelightYieldSourceOracle — all branches, lines, fuzz
contract FirelightYieldSourceOracleTest is Test {
    FirelightYieldSourceOracle public oracle;
    MockFirelightVault public vault;
    ISuperLedgerConfiguration public ledgerConfig;

    address public user = makeAddr("user");
    address public user2 = makeAddr("user2");

    // 6 decimals, PPS ~1.000071 (matching real Firelight vault)
    uint8 constant DECIMALS = 6;
    uint256 constant ONE_SHARE = 1e6;
    uint256 constant ASSETS_PER_SHARE = 1_000_071; // ~1.000071 FXRP per stXRP

    function setUp() public {
        ledgerConfig = ISuperLedgerConfiguration(address(new SuperLedgerConfiguration()));
        oracle = new FirelightYieldSourceOracle(address(ledgerConfig));
        vault = new MockFirelightVault(DECIMALS, ASSETS_PER_SHARE);
        vault.setCurrentPeriod(100);
        vault.setTotalAssets(60_000e6);
    }

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR & CONSTANTS
    //////////////////////////////////////////////////////////////*/

    function test_constructor_setsMaxLookback() public view {
        assertEq(oracle.MAX_LOOKBACK(), 1000);
    }

    function test_constructor_setsSuperLedgerConfiguration() public view {
        assertEq(oracle.SUPER_LEDGER_CONFIGURATION(), address(ledgerConfig));
    }

    /*//////////////////////////////////////////////////////////////
                        decimals()
    //////////////////////////////////////////////////////////////*/

    function test_decimals_6() public view {
        assertEq(oracle.decimals(address(vault)), 6);
    }

    function test_decimals_8() public {
        MockFirelightVault v8 = new MockFirelightVault(8, 1.001e8);
        assertEq(oracle.decimals(address(v8)), 8);
    }

    function test_decimals_18() public {
        MockFirelightVault v18 = new MockFirelightVault(18, 1.05e18);
        assertEq(oracle.decimals(address(v18)), 18);
    }

    /*//////////////////////////////////////////////////////////////
                        getShareOutput()
    //////////////////////////////////////////////////////////////*/

    function test_getShareOutput() public view {
        uint256 assetsIn = 1_000_000;
        uint256 shares = oracle.getShareOutput(address(vault), address(0), assetsIn);
        assertEq(shares, Math.mulDiv(assetsIn, ONE_SHARE, ASSETS_PER_SHARE));
    }

    function test_getShareOutput_zeroInput() public view {
        assertEq(oracle.getShareOutput(address(vault), address(0), 0), 0);
    }

    function test_getShareOutput_largeAmount() public view {
        uint256 assetsIn = 1_000_000e6; // 1M FXRP
        uint256 shares = oracle.getShareOutput(address(vault), address(0), assetsIn);
        assertEq(shares, Math.mulDiv(assetsIn, ONE_SHARE, ASSETS_PER_SHARE));
    }

    /*//////////////////////////////////////////////////////////////
                        getAssetOutput()
    //////////////////////////////////////////////////////////////*/

    function test_getAssetOutput() public view {
        uint256 sharesIn = 1_000_000;
        uint256 assets = oracle.getAssetOutput(address(vault), address(0), sharesIn);
        assertEq(assets, ASSETS_PER_SHARE);
    }

    function test_getAssetOutput_zeroInput() public view {
        assertEq(oracle.getAssetOutput(address(vault), address(0), 0), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        getWithdrawalShareOutput()
    //////////////////////////////////////////////////////////////*/

    function test_getWithdrawalShareOutput_ceilRounding() public view {
        uint256 assetsIn = 1_000_000;
        uint256 shares = oracle.getWithdrawalShareOutput(address(vault), address(0), assetsIn);
        uint256 expected = Math.mulDiv(assetsIn, ONE_SHARE, ASSETS_PER_SHARE, Math.Rounding.Ceil);
        assertEq(shares, expected);
        // Ceil >= floor
        assertGe(shares, Math.mulDiv(assetsIn, ONE_SHARE, ASSETS_PER_SHARE));
    }

    function test_getWithdrawalShareOutput_zeroAssetsPerShare_returnsZero() public {
        vault.setAssetsPerShareNumerator(0);
        assertEq(oracle.getWithdrawalShareOutput(address(vault), address(0), 1_000_000), 0);
    }

    function test_getWithdrawalShareOutput_zeroInput() public view {
        assertEq(oracle.getWithdrawalShareOutput(address(vault), address(0), 0), 0);
    }

    function test_getWithdrawalShareOutput_exactDivision() public {
        // 1:1 rate → no ceil rounding needed
        MockFirelightVault v1to1 = new MockFirelightVault(6, 1e6);
        uint256 shares = oracle.getWithdrawalShareOutput(address(v1to1), address(0), 5_000_000);
        assertEq(shares, 5_000_000); // exact, no rounding
    }

    /*//////////////////////////////////////////////////////////////
                        getPricePerShare()
    //////////////////////////////////////////////////////////////*/

    function test_getPricePerShare_6dec() public view {
        assertEq(oracle.getPricePerShare(address(vault)), ASSETS_PER_SHARE);
    }

    function test_getPricePerShare_18dec() public {
        MockFirelightVault v18 = new MockFirelightVault(18, 1.05e18);
        assertEq(oracle.getPricePerShare(address(v18)), 1.05e18);
    }

    function test_getPricePerShare_8dec() public {
        MockFirelightVault v8 = new MockFirelightVault(8, 1.001e8);
        assertEq(oracle.getPricePerShare(address(v8)), 1.001e8);
    }

    function test_getPricePerShare_1to1() public {
        MockFirelightVault v = new MockFirelightVault(6, 1e6);
        assertEq(oracle.getPricePerShare(address(v)), 1e6);
    }

    /*//////////////////////////////////////////////////////////////
                        getBalanceOfOwner()
    //////////////////////////////////////////////////////////////*/

    function test_getBalanceOfOwner_nonZero() public {
        vault.setBalance(user, 5_000e6);
        assertEq(oracle.getBalanceOfOwner(address(vault), user), 5_000e6);
    }

    function test_getBalanceOfOwner_zero() public view {
        assertEq(oracle.getBalanceOfOwner(address(vault), user), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        getTVL()
    //////////////////////////////////////////////////////////////*/

    function test_getTVL() public view {
        assertEq(oracle.getTVL(address(vault)), 60_000e6);
    }

    function test_getTVL_zero() public {
        vault.setTotalAssets(0);
        assertEq(oracle.getTVL(address(vault)), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    getTVLByOwnerOfShares — HELD SHARES ONLY
    //////////////////////////////////////////////////////////////*/

    function test_TVL_noShares_noPending() public view {
        assertEq(oracle.getTVLByOwnerOfShares(address(vault), user), 0);
    }

    function test_TVL_sharesOnly() public {
        vault.setBalance(user, 1_000e6);
        assertEq(
            oracle.getTVLByOwnerOfShares(address(vault), user),
            Math.mulDiv(1_000e6, ASSETS_PER_SHARE, ONE_SHARE)
        );
    }

    function test_TVL_heldShares_skipsConvertWhenZero() public view {
        // Branch: heldShares == 0 → skip convertToAssets call
        // No pending either → TVL = 0
        assertEq(oracle.getTVLByOwnerOfShares(address(vault), user), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    getTVLByOwnerOfShares — PENDING ONLY
    //////////////////////////////////////////////////////////////*/

    function test_TVL_pendingOnly_nextPeriod() public {
        vault.setWithdrawalsOf(101, user, 50_000e6);
        assertEq(oracle.getTVLByOwnerOfShares(address(vault), user), 50_000e6);
    }

    function test_TVL_pendingOnly_currentPeriod() public {
        vault.setWithdrawalsOf(100, user, 30_000e6);
        assertEq(oracle.getTVLByOwnerOfShares(address(vault), user), 30_000e6);
    }

    function test_TVL_pendingOnly_olderPeriod() public {
        vault.setWithdrawalsOf(99, user, 25_000e6);
        assertEq(oracle.getTVLByOwnerOfShares(address(vault), user), 25_000e6);
    }

    /*//////////////////////////////////////////////////////////////
                    getTVLByOwnerOfShares — HELD + PENDING
    //////////////////////////////////////////////////////////////*/

    function test_TVL_heldAndPending() public {
        vault.setBalance(user, 1_000e6);
        vault.setWithdrawalsOf(101, user, 50_000e6);
        uint256 heldValue = Math.mulDiv(1_000e6, ASSETS_PER_SHARE, ONE_SHARE);
        assertEq(oracle.getTVLByOwnerOfShares(address(vault), user), heldValue + 50_000e6);
    }

    /*//////////////////////////////////////////////////////////////
                    getTVLByOwnerOfShares — CLAIMED EXCLUSION
    //////////////////////////////////////////////////////////////*/

    function test_TVL_claimedCurrentPeriod_excluded() public {
        vault.setWithdrawalsOf(100, user, 30_000e6);
        vault.setIsWithdrawClaimed(100, user, true);
        assertEq(oracle.getTVLByOwnerOfShares(address(vault), user), 0);
    }

    function test_TVL_claimedNextPeriod_excluded() public {
        vault.setWithdrawalsOf(101, user, 50_000e6);
        vault.setIsWithdrawClaimed(101, user, true);
        assertEq(oracle.getTVLByOwnerOfShares(address(vault), user), 0);
    }

    function test_TVL_claimedOlderPeriod_excluded() public {
        vault.setWithdrawalsOf(98, user, 10_000e6);
        vault.setIsWithdrawClaimed(98, user, true);
        vault.setWithdrawalsOf(99, user, 15_000e6); // unclaimed
        assertEq(oracle.getTVLByOwnerOfShares(address(vault), user), 15_000e6);
    }

    function test_TVL_allPeriodsClaimed_zero() public {
        vault.setWithdrawalsOf(98, user, 10_000e6);
        vault.setIsWithdrawClaimed(98, user, true);
        vault.setWithdrawalsOf(99, user, 15_000e6);
        vault.setIsWithdrawClaimed(99, user, true);
        vault.setWithdrawalsOf(100, user, 20_000e6);
        vault.setIsWithdrawClaimed(100, user, true);
        vault.setWithdrawalsOf(101, user, 25_000e6);
        vault.setIsWithdrawClaimed(101, user, true);
        assertEq(oracle.getTVLByOwnerOfShares(address(vault), user), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    getTVLByOwnerOfShares — MULTI-PERIOD ACCUMULATION
    //////////////////////////////////////////////////////////////*/

    function test_TVL_unclaimedAcrossMultiplePeriods() public {
        vault.setBalance(user, 500e6);
        vault.setWithdrawalsOf(98, user, 10_000e6);
        vault.setWithdrawalsOf(99, user, 15_000e6);
        vault.setWithdrawalsOf(100, user, 20_000e6);
        vault.setWithdrawalsOf(101, user, 25_000e6);

        uint256 heldValue = Math.mulDiv(500e6, ASSETS_PER_SHARE, ONE_SHARE);
        assertEq(
            oracle.getTVLByOwnerOfShares(address(vault), user),
            heldValue + 10_000e6 + 15_000e6 + 20_000e6 + 25_000e6
        );
    }

    function test_TVL_mixedClaimedUnclaimed() public {
        vault.setWithdrawalsOf(97, user, 5_000e6);
        vault.setIsWithdrawClaimed(97, user, true); // claimed
        vault.setWithdrawalsOf(98, user, 10_000e6); // unclaimed
        vault.setWithdrawalsOf(99, user, 15_000e6);
        vault.setIsWithdrawClaimed(99, user, true); // claimed
        vault.setWithdrawalsOf(100, user, 20_000e6); // unclaimed
        vault.setWithdrawalsOf(101, user, 25_000e6); // unclaimed

        assertEq(oracle.getTVLByOwnerOfShares(address(vault), user), 10_000e6 + 20_000e6 + 25_000e6);
    }

    /*//////////////////////////////////////////////////////////////
                    getTVLByOwnerOfShares — LOOKBACK BOUNDARY
    //////////////////////////////////////////////////////////////*/

    function test_TVL_lookbackBoundary_included() public {
        uint256 cp = oracle.MAX_LOOKBACK() + 100;
        vault.setCurrentPeriod(cp);
        uint256 boundaryPeriod = cp - oracle.MAX_LOOKBACK();
        vault.setWithdrawalsOf(boundaryPeriod, user, 5_000e6);
        assertEq(oracle.getTVLByOwnerOfShares(address(vault), user), 5_000e6);
    }

    function test_TVL_beyondLookback_excluded() public {
        uint256 cp = oracle.MAX_LOOKBACK() + 100;
        vault.setCurrentPeriod(cp);
        uint256 beyondPeriod = cp - oracle.MAX_LOOKBACK() - 1;
        vault.setWithdrawalsOf(beyondPeriod, user, 5_000e6);
        assertEq(oracle.getTVLByOwnerOfShares(address(vault), user), 0);
    }

    function test_TVL_currentPeriodExactlyMaxLookback() public {
        // currentPeriod == MAX_LOOKBACK → startPeriod = 0
        vault.setCurrentPeriod(oracle.MAX_LOOKBACK());
        vault.setWithdrawalsOf(0, user, 1_000e6);
        vault.setWithdrawalsOf(oracle.MAX_LOOKBACK() + 1, user, 2_000e6);
        assertEq(oracle.getTVLByOwnerOfShares(address(vault), user), 1_000e6 + 2_000e6);
    }

    /*//////////////////////////////////////////////////////////////
                    getTVLByOwnerOfShares — UNDERFLOW SAFETY
    //////////////////////////////////////////////////////////////*/

    function test_TVL_currentPeriodLessThanMaxLookback() public {
        vault.setCurrentPeriod(3);
        vault.setWithdrawalsOf(0, user, 1_000e6);
        vault.setWithdrawalsOf(1, user, 2_000e6);
        vault.setWithdrawalsOf(3, user, 3_000e6);
        vault.setWithdrawalsOf(4, user, 4_000e6);
        assertEq(oracle.getTVLByOwnerOfShares(address(vault), user), 1_000e6 + 2_000e6 + 3_000e6 + 4_000e6);
    }

    function test_TVL_currentPeriodZero() public {
        vault.setCurrentPeriod(0);
        vault.setWithdrawalsOf(0, user, 1_000e6);
        vault.setWithdrawalsOf(1, user, 2_000e6);
        assertEq(oracle.getTVLByOwnerOfShares(address(vault), user), 1_000e6 + 2_000e6);
    }

    function test_TVL_currentPeriodOne() public {
        vault.setCurrentPeriod(1);
        vault.setWithdrawalsOf(0, user, 500e6);
        vault.setWithdrawalsOf(1, user, 600e6);
        vault.setWithdrawalsOf(2, user, 700e6);
        assertEq(oracle.getTVLByOwnerOfShares(address(vault), user), 500e6 + 600e6 + 700e6);
    }

    /*//////////////////////////////////////////////////////////////
                    getTVLByOwnerOfShares — MULTIPLE USERS
    //////////////////////////////////////////////////////////////*/

    function test_TVL_differentUsers_independent() public {
        vault.setBalance(user, 1_000e6);
        vault.setWithdrawalsOf(101, user, 50_000e6);

        vault.setBalance(user2, 2_000e6);
        vault.setWithdrawalsOf(100, user2, 30_000e6);

        uint256 tvl1 = oracle.getTVLByOwnerOfShares(address(vault), user);
        uint256 tvl2 = oracle.getTVLByOwnerOfShares(address(vault), user2);

        assertEq(tvl1, Math.mulDiv(1_000e6, ASSETS_PER_SHARE, ONE_SHARE) + 50_000e6);
        assertEq(tvl2, Math.mulDiv(2_000e6, ASSETS_PER_SHARE, ONE_SHARE) + 30_000e6);
    }

    function test_TVL_userWithClaimed_otherWithUnclaimed() public {
        vault.setWithdrawalsOf(100, user, 10_000e6);
        vault.setIsWithdrawClaimed(100, user, true);

        vault.setWithdrawalsOf(100, user2, 10_000e6);
        // user2 NOT claimed

        assertEq(oracle.getTVLByOwnerOfShares(address(vault), user), 0);
        assertEq(oracle.getTVLByOwnerOfShares(address(vault), user2), 10_000e6);
    }

    /*//////////////////////////////////////////////////////////////
                    REDEEM SIMULATION — TVL PRESERVATION
    //////////////////////////////////////////////////////////////*/

    function test_TVL_partialRedeem_preserved() public {
        vault.setBalance(user, 5_000e6);
        vault.setTotalAssets(5_000e6 * ASSETS_PER_SHARE / ONE_SHARE);

        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(address(vault), user);
        vault.redeem(3_000e6, user, user);
        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(address(vault), user);

        assertApproxEqAbs(tvlAfter, tvlBefore, 1);
    }

    function test_TVL_fullRedeem_preserved() public {
        vault.setBalance(user, 1_000e6);
        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(address(vault), user);

        vault.redeem(1_000e6, user, user);
        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(address(vault), user);

        assertApproxEqAbs(tvlAfter, tvlBefore, 1);
    }

    function test_TVL_multipleRedeems_samePeriod_accumulate() public {
        vault.setBalance(user, 5_000e6);
        vault.redeem(1_000e6, user, user);
        vault.redeem(2_000e6, user, user);

        // 2000 shares held + 3000 shares worth of assets pending in period 101
        uint256 heldValue = Math.mulDiv(2_000e6, ASSETS_PER_SHARE, ONE_SHARE);
        uint256 pendingAssets = Math.mulDiv(1_000e6, ASSETS_PER_SHARE, ONE_SHARE)
            + Math.mulDiv(2_000e6, ASSETS_PER_SHARE, ONE_SHARE);

        assertEq(oracle.getTVLByOwnerOfShares(address(vault), user), heldValue + pendingAssets);
    }

    /*//////////////////////////////////////////////////////////////
                    BATCH METHODS (INHERITED)
    //////////////////////////////////////////////////////////////*/

    function test_getPricePerShareMultiple() public {
        MockFirelightVault vault2 = new MockFirelightVault(18, 1.1e18);
        address[] memory vaults = new address[](2);
        vaults[0] = address(vault);
        vaults[1] = address(vault2);

        uint256[] memory prices = oracle.getPricePerShareMultiple(vaults);
        assertEq(prices[0], ASSETS_PER_SHARE);
        assertEq(prices[1], 1.1e18);
    }

    function test_getTVLMultiple() public {
        MockFirelightVault vault2 = new MockFirelightVault(18, 1.1e18);
        vault2.setTotalAssets(100e18);

        address[] memory vaults = new address[](2);
        vaults[0] = address(vault);
        vaults[1] = address(vault2);

        uint256[] memory tvls = oracle.getTVLMultiple(vaults);
        assertEq(tvls[0], 60_000e6);
        assertEq(tvls[1], 100e18);
    }

    function test_getTVLByOwnerOfSharesMultiple() public {
        vault.setBalance(user, 1_000e6);
        vault.setWithdrawalsOf(101, user, 50_000e6);

        address[] memory vaults = new address[](1);
        vaults[0] = address(vault);

        address[][] memory owners = new address[][](1);
        owners[0] = new address[](2);
        owners[0][0] = user;
        owners[0][1] = user2;

        uint256[][] memory tvls = oracle.getTVLByOwnerOfSharesMultiple(vaults, owners);
        assertEq(tvls[0][0], Math.mulDiv(1_000e6, ASSETS_PER_SHARE, ONE_SHARE) + 50_000e6);
        assertEq(tvls[0][1], 0);
    }

    function test_getTVLByOwnerOfSharesMultiple_arrayLengthMismatch_reverts() public {
        address[] memory vaults = new address[](2);
        address[][] memory owners = new address[][](1);

        vm.expectRevert(IYieldSourceOracle.ARRAY_LENGTH_MISMATCH.selector);
        oracle.getTVLByOwnerOfSharesMultiple(vaults, owners);
    }

    /*//////////////////////////////////////////////////////////////
                    getAssetOutputWithFees (INHERITED)
    //////////////////////////////////////////////////////////////*/

    function test_getAssetOutputWithFees_noConfig() public view {
        // No oracle config registered → falls back to base asset output
        bytes32 oracleId = keccak256("unregistered");
        uint256 result = oracle.getAssetOutputWithFees(oracleId, address(vault), address(0), user, 1_000e6);
        assertEq(result, oracle.getAssetOutput(address(vault), address(0), 1_000e6));
    }

    /*//////////////////////////////////////////////////////////////
                    MULTI-DECIMAL VAULT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_18dec_fullLifecycle() public {
        MockFirelightVault v18 = new MockFirelightVault(18, 1.05e18);
        v18.setCurrentPeriod(10);
        v18.setBalance(user, 100e18);
        v18.setWithdrawalsOf(11, user, 50e18);
        v18.setTotalAssets(1000e18);

        assertEq(oracle.decimals(address(v18)), 18);
        assertEq(oracle.getPricePerShare(address(v18)), 1.05e18);
        assertEq(oracle.getTVL(address(v18)), 1000e18);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(v18), user);
        assertEq(tvl, Math.mulDiv(100e18, 1.05e18, 1e18) + 50e18);
    }

    function test_8dec_conversions() public {
        MockFirelightVault v8 = new MockFirelightVault(8, 1.00125e8);
        // getShareOutput
        uint256 shares = oracle.getShareOutput(address(v8), address(0), 1e8);
        assertEq(shares, Math.mulDiv(1e8, 1e8, 1.00125e8));
        // getAssetOutput
        uint256 assets = oracle.getAssetOutput(address(v8), address(0), 1e8);
        assertEq(assets, 1.00125e8);
    }

    /*//////////////////////////////////////////////////////////////
                    EARLY VAULT — FULL COVERAGE FROM PERIOD 0
    //////////////////////////////////////////////////////////////*/

    function test_earlyVault_fullCoverageFromZero() public {
        vault.setCurrentPeriod(5);
        vault.setWithdrawalsOf(0, user, 1_000e6);
        vault.setWithdrawalsOf(2, user, 2_000e6);
        vault.setWithdrawalsOf(5, user, 3_000e6);
        vault.setWithdrawalsOf(6, user, 4_000e6);

        assertEq(oracle.getTVLByOwnerOfShares(address(vault), user), 1_000e6 + 2_000e6 + 3_000e6 + 4_000e6);
    }

    /*//////////////////////////////////////////////////////////////
                    FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_roundTrip_assetToShareToAsset(uint256 assetsIn) public view {
        assetsIn = bound(assetsIn, 1, 1e30);
        uint256 shares = oracle.getShareOutput(address(vault), address(0), assetsIn);
        if (shares == 0) return;
        uint256 assetsBack = oracle.getAssetOutput(address(vault), address(0), shares);
        assertLe(assetsBack, assetsIn, "Floor rounding: assetsBack <= assetsIn");
    }

    function testFuzz_withdrawalShareOutput_ceilGteFloor(uint256 assetsIn) public view {
        assetsIn = bound(assetsIn, 1, 1e30);
        uint256 ceilShares = oracle.getWithdrawalShareOutput(address(vault), address(0), assetsIn);
        uint256 floorShares = oracle.getShareOutput(address(vault), address(0), assetsIn);
        assertGe(ceilShares, floorShares, "Ceil >= floor always");
    }

    function testFuzz_withdrawalShareOutput_coversAssets(uint256 assetsIn) public view {
        assetsIn = bound(assetsIn, 1, 1e24);
        uint256 ceilShares = oracle.getWithdrawalShareOutput(address(vault), address(0), assetsIn);
        if (ceilShares == 0) return;
        uint256 assetsFromCeil = oracle.getAssetOutput(address(vault), address(0), ceilShares);
        assertGe(assetsFromCeil, assetsIn, "Ceil shares should cover requested assets");
    }

    function testFuzz_redeemPreservesTVL(uint256 shares) public {
        shares = bound(shares, 1, 1e18);
        vault.setBalance(user, shares);
        vault.setTotalAssets(shares * ASSETS_PER_SHARE / ONE_SHARE);

        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(address(vault), user);
        vault.redeem(shares, user, user);
        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(address(vault), user);

        assertApproxEqAbs(tvlAfter, tvlBefore, 1, "TVL preserved within 1 wei");
    }

    function testFuzz_TVL_neverReverts(uint256 balance, uint256 pending, uint256 period) public {
        balance = bound(balance, 0, 1e24);
        pending = bound(pending, 0, 1e24);
        period = bound(period, 0, 5000);

        vault.setBalance(user, balance);
        vault.setCurrentPeriod(period);
        if (period + 1 < type(uint256).max) {
            vault.setWithdrawalsOf(period + 1, user, pending);
        }

        // Should never revert
        oracle.getTVLByOwnerOfShares(address(vault), user);
    }

    function testFuzz_PPS_matchesConvertToAssets(uint256 rate) public {
        rate = bound(rate, 1, 1e30);
        MockFirelightVault v = new MockFirelightVault(6, rate);
        uint256 pps = oracle.getPricePerShare(address(v));
        assertEq(pps, rate, "PPS should equal convertToAssets(oneShare)");
    }

    function testFuzz_pendingValue_claimedExcluded(uint256 amount, bool claimed) public {
        amount = bound(amount, 1, 1e24);
        vault.setWithdrawalsOf(100, user, amount);
        vault.setIsWithdrawClaimed(100, user, claimed);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(vault), user);
        if (claimed) {
            assertEq(tvl, 0, "Claimed should be excluded");
        } else {
            assertEq(tvl, amount, "Unclaimed should be included");
        }
    }

    function testFuzz_lookbackBoundary(uint256 currentPeriod) public {
        currentPeriod = bound(currentPeriod, 0, 10_000);
        vault.setCurrentPeriod(currentPeriod);

        uint256 startPeriod;
        if (currentPeriod > oracle.MAX_LOOKBACK()) {
            startPeriod = currentPeriod - oracle.MAX_LOOKBACK();
        }

        // Withdrawal at startPeriod should be included
        vault.setWithdrawalsOf(startPeriod, user, 1_000e6);
        uint256 tvl = oracle.getTVLByOwnerOfShares(address(vault), user);
        assertEq(tvl, 1_000e6, "Boundary period should be included");

        // Withdrawal 1 before startPeriod should be excluded (if startPeriod > 0)
        if (startPeriod > 0) {
            vault.setWithdrawalsOf(startPeriod, user, 0); // clear
            vault.setWithdrawalsOf(startPeriod - 1, user, 1_000e6);
            tvl = oracle.getTVLByOwnerOfShares(address(vault), user);
            assertEq(tvl, 0, "Before boundary should be excluded");
        }
    }
}
