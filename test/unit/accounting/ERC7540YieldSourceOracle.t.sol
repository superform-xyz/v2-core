// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { MockERC7540VaultFull } from "../../mocks/MockERC7540VaultFull.sol";
import { ERC7540YieldSourceOracle } from "../../../src/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { IYieldSourceOracle } from "../../../src/interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperLedger } from "../../../src/interfaces/accounting/ISuperLedger.sol";

contract ERC7540YieldSourceOracleTest is Test {
    ERC7540YieldSourceOracle public oracle;
    MockERC7540VaultFull public vault;
    SuperLedgerConfiguration public ledgerConfig;

    address public owner;
    address public vaultAddr;

    function setUp() public {
        ledgerConfig = new SuperLedgerConfiguration();
        oracle = new ERC7540YieldSourceOracle(address(ledgerConfig), 0);
        vault = new MockERC7540VaultFull(18, 18);
        vaultAddr = address(vault);
        owner = makeAddr("owner");
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_constructor_setsRequestId() public view {
        assertEq(oracle.REQUEST_ID(), 0);
    }

    function test_constructor_nonZeroRequestId() public {
        ERC7540YieldSourceOracle oracle2 = new ERC7540YieldSourceOracle(address(ledgerConfig), 42);
        assertEq(oracle2.REQUEST_ID(), 42);
    }

    function test_constructor_setsSuperLedgerConfiguration() public view {
        assertEq(oracle.SUPER_LEDGER_CONFIGURATION(), address(ledgerConfig));
    }

    /*//////////////////////////////////////////////////////////////
                            DECIMALS
    //////////////////////////////////////////////////////////////*/

    function test_decimals_18() public view {
        assertEq(oracle.decimals(vaultAddr), 18);
    }

    function test_decimals_6() public {
        MockERC7540VaultFull vault6 = new MockERC7540VaultFull(6, 6);
        assertEq(oracle.decimals(address(vault6)), 6);
    }

    function test_decimals_8() public {
        MockERC7540VaultFull vault8 = new MockERC7540VaultFull(6, 8);
        assertEq(oracle.decimals(address(vault8)), 8);
    }

    /*//////////////////////////////////////////////////////////////
                            GET SHARE OUTPUT
    //////////////////////////////////////////////////////////////*/

    function test_getShareOutput_1to1() public view {
        // Default 1:1 rate with 18 decimals
        uint256 shares = oracle.getShareOutput(vaultAddr, address(0), 1e18);
        assertEq(shares, 1e18);
    }

    function test_getShareOutput_2to1() public {
        // 2 assets per share => 1 asset gets 0.5 shares
        vault.setAssetsPerShare(2e18);
        uint256 shares = oracle.getShareOutput(vaultAddr, address(0), 1e18);
        assertEq(shares, 0.5e18);
    }

    function test_getShareOutput_zeroAssets() public view {
        uint256 shares = oracle.getShareOutput(vaultAddr, address(0), 0);
        assertEq(shares, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        GET WITHDRAWAL SHARE OUTPUT
    //////////////////////////////////////////////////////////////*/

    function test_getWithdrawalShareOutput_1to1() public view {
        uint256 shares = oracle.getWithdrawalShareOutput(vaultAddr, address(0), 1e18);
        assertEq(shares, 1e18);
    }

    function test_getWithdrawalShareOutput_2to1() public {
        // 2 assets per share => need 0.5 shares for 1 asset (ceil rounding may apply)
        vault.setAssetsPerShare(2e18);
        uint256 shares = oracle.getWithdrawalShareOutput(vaultAddr, address(0), 1e18);
        assertEq(shares, 0.5e18);
    }

    function test_getWithdrawalShareOutput_ceilRounding() public {
        // 3 assets per share => for 1 asset, need ceil(1e18 * 1e18 / 3e18) shares
        vault.setAssetsPerShare(3e18);
        uint256 shares = oracle.getWithdrawalShareOutput(vaultAddr, address(0), 1e18);
        uint256 expected = Math.mulDiv(1e18, 1e18, 3e18, Math.Rounding.Ceil);
        assertEq(shares, expected);
    }

    function test_getWithdrawalShareOutput_zeroAssetsPerShare() public {
        vault.setAssetsPerShare(0);
        uint256 shares = oracle.getWithdrawalShareOutput(vaultAddr, address(0), 1e18);
        assertEq(shares, 0);
    }

    function test_getWithdrawalShareOutput_6decimals() public {
        MockERC7540VaultFull vault6 = new MockERC7540VaultFull(6, 6);
        vault6.setAssetsPerShare(1e6); // 1:1 at 6 decimals
        uint256 shares = oracle.getWithdrawalShareOutput(address(vault6), address(0), 1e6);
        assertEq(shares, 1e6);
    }

    /*//////////////////////////////////////////////////////////////
                            GET ASSET OUTPUT
    //////////////////////////////////////////////////////////////*/

    function test_getAssetOutput_1to1() public view {
        uint256 assets = oracle.getAssetOutput(vaultAddr, address(0), 1e18);
        assertEq(assets, 1e18);
    }

    function test_getAssetOutput_2to1() public {
        vault.setAssetsPerShare(2e18);
        uint256 assets = oracle.getAssetOutput(vaultAddr, address(0), 1e18);
        assertEq(assets, 2e18);
    }

    function test_getAssetOutput_zeroShares() public view {
        uint256 assets = oracle.getAssetOutput(vaultAddr, address(0), 0);
        assertEq(assets, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            GET PRICE PER SHARE
    //////////////////////////////////////////////////////////////*/

    function test_getPricePerShare_1to1() public view {
        uint256 pps = oracle.getPricePerShare(vaultAddr);
        assertEq(pps, 1e18);
    }

    function test_getPricePerShare_2to1() public {
        vault.setAssetsPerShare(2e18);
        uint256 pps = oracle.getPricePerShare(vaultAddr);
        assertEq(pps, 2e18);
    }

    function test_getPricePerShare_6decimals() public {
        MockERC7540VaultFull vault6 = new MockERC7540VaultFull(6, 6);
        vault6.setAssetsPerShare(1e6);
        uint256 pps = oracle.getPricePerShare(address(vault6));
        assertEq(pps, 1e6);
    }

    function test_getPricePerShare_revertsOnConvertToAssetsRevert() public {
        vault.setRevertOnConvertToAssets(true);
        vm.expectRevert();
        oracle.getPricePerShare(vaultAddr);
    }

    /*//////////////////////////////////////////////////////////////
                            GET BALANCE OF OWNER
    //////////////////////////////////////////////////////////////*/

    function test_getBalanceOfOwner_zero() public view {
        assertEq(oracle.getBalanceOfOwner(vaultAddr, owner), 0);
    }

    function test_getBalanceOfOwner_withShares() public {
        vault.mintShares(owner, 100e18);
        assertEq(oracle.getBalanceOfOwner(vaultAddr, owner), 100e18);
    }

    /*//////////////////////////////////////////////////////////////
                            GET TVL
    //////////////////////////////////////////////////////////////*/

    function test_getTVL() public {
        vault.setTotalAssets(1_000_000e18);
        assertEq(oracle.getTVL(vaultAddr), 1_000_000e18);
    }

    function test_getTVL_zero() public view {
        assertEq(oracle.getTVL(vaultAddr), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        GET ASYNC STATE BREAKDOWN
    //////////////////////////////////////////////////////////////*/

    function test_getAsyncStateBreakdown_allZero() public view {
        (uint256 held, uint256 pendingRedeem, uint256 claimableRedeem, uint256 pendingDeposit, uint256 claimableDeposit)
        = oracle.getAsyncStateBreakdown(vaultAddr, owner);

        assertEq(held, 0);
        assertEq(pendingRedeem, 0);
        assertEq(claimableRedeem, 0);
        assertEq(pendingDeposit, 0);
        assertEq(claimableDeposit, 0);
    }

    function test_getAsyncStateBreakdown_heldOnly() public {
        vault.mintShares(owner, 50e18);

        (uint256 held,,,,) = oracle.getAsyncStateBreakdown(vaultAddr, owner);
        assertEq(held, 50e18); // 1:1 rate
    }

    function test_getAsyncStateBreakdown_pendingRedeemOnly() public {
        vault.setPendingRedeemShares(owner, 30e18);

        (, uint256 pendingRedeem,,,) = oracle.getAsyncStateBreakdown(vaultAddr, owner);
        assertEq(pendingRedeem, 30e18); // 1:1 rate
    }

    function test_getAsyncStateBreakdown_claimableRedeemOnly() public {
        vault.setMaxWithdrawAssets(owner, 25e18);

        (,, uint256 claimableRedeem,,) = oracle.getAsyncStateBreakdown(vaultAddr, owner);
        assertEq(claimableRedeem, 25e18);
    }

    function test_getAsyncStateBreakdown_pendingDepositOnly() public {
        vault.setPendingDepositAssets(owner, 10e18);

        (,,, uint256 pendingDeposit,) = oracle.getAsyncStateBreakdown(vaultAddr, owner);
        assertEq(pendingDeposit, 10e18);
    }

    function test_getAsyncStateBreakdown_claimableDepositOnly() public {
        vault.setClaimableDepositAssets(owner, 5e18);

        (,,,, uint256 claimableDeposit) = oracle.getAsyncStateBreakdown(vaultAddr, owner);
        assertEq(claimableDeposit, 5e18);
    }

    function test_getAsyncStateBreakdown_allComponentsActive() public {
        vault.mintShares(owner, 100e18);
        vault.setPendingRedeemShares(owner, 50e18);
        vault.setMaxWithdrawAssets(owner, 25e18);
        vault.setPendingDepositAssets(owner, 10e18);
        vault.setClaimableDepositAssets(owner, 5e18);

        (uint256 held, uint256 pendingRedeem, uint256 claimableRedeem, uint256 pendingDeposit, uint256 claimableDeposit)
        = oracle.getAsyncStateBreakdown(vaultAddr, owner);

        assertEq(held, 100e18);
        assertEq(pendingRedeem, 50e18);
        assertEq(claimableRedeem, 25e18);
        assertEq(pendingDeposit, 10e18);
        assertEq(claimableDeposit, 5e18);
    }

    function test_getAsyncStateBreakdown_withExchangeRate() public {
        vault.setAssetsPerShare(2e18); // 2 assets per share
        vault.mintShares(owner, 100e18);
        vault.setPendingRedeemShares(owner, 50e18);

        (uint256 held, uint256 pendingRedeem,,,) = oracle.getAsyncStateBreakdown(vaultAddr, owner);

        assertEq(held, 200e18); // 100 shares * 2 assets/share
        assertEq(pendingRedeem, 100e18); // 50 shares * 2 assets/share
    }

    /*//////////////////////////////////////////////////////////////
                        GET TVL BY OWNER OF SHARES
    //////////////////////////////////////////////////////////////*/

    function test_getTVLByOwnerOfShares_sumsAllComponents() public {
        vault.mintShares(owner, 100e18);
        vault.setPendingRedeemShares(owner, 50e18);
        vault.setMaxWithdrawAssets(owner, 25e18);
        vault.setPendingDepositAssets(owner, 10e18);
        vault.setClaimableDepositAssets(owner, 5e18);

        uint256 tvl = oracle.getTVLByOwnerOfShares(vaultAddr, owner);
        assertEq(tvl, 100e18 + 50e18 + 25e18 + 10e18 + 5e18);
    }

    function test_getTVLByOwnerOfShares_allZero() public view {
        uint256 tvl = oracle.getTVLByOwnerOfShares(vaultAddr, owner);
        assertEq(tvl, 0);
    }

    function test_getTVLByOwnerOfShares_heldOnlyWithExchangeRate() public {
        vault.setAssetsPerShare(1.5e18);
        vault.mintShares(owner, 100e18);

        uint256 tvl = oracle.getTVLByOwnerOfShares(vaultAddr, owner);
        assertEq(tvl, 150e18);
    }

    /*//////////////////////////////////////////////////////////////
                        R2: GRACEFUL DEGRADATION
    //////////////////////////////////////////////////////////////*/

    function test_R2_pendingRedeemReverts_componentDroppedNotEntireCall() public {
        vault.mintShares(owner, 100e18);
        vault.setPendingRedeemShares(owner, 50e18);
        vault.setRevertOnPendingRedeemRequest(true);

        uint256 tvl = oracle.getTVLByOwnerOfShares(vaultAddr, owner);
        // Only held component should be present (pending redeem dropped)
        assertEq(tvl, 100e18);
    }

    function test_R2_maxWithdrawReverts_componentDropped() public {
        vault.mintShares(owner, 100e18);
        vault.setMaxWithdrawAssets(owner, 25e18);
        vault.setRevertOnMaxWithdraw(true);

        uint256 tvl = oracle.getTVLByOwnerOfShares(vaultAddr, owner);
        assertEq(tvl, 100e18); // Only held
    }

    function test_R2_pendingDepositReverts_componentDropped() public {
        vault.mintShares(owner, 100e18);
        vault.setPendingDepositAssets(owner, 10e18);
        vault.setRevertOnPendingDepositRequest(true);

        uint256 tvl = oracle.getTVLByOwnerOfShares(vaultAddr, owner);
        assertEq(tvl, 100e18); // Only held
    }

    function test_R2_claimableDepositReverts_componentDropped() public {
        vault.mintShares(owner, 100e18);
        vault.setClaimableDepositAssets(owner, 5e18);
        vault.setRevertOnClaimableDepositRequest(true);

        uint256 tvl = oracle.getTVLByOwnerOfShares(vaultAddr, owner);
        assertEq(tvl, 100e18); // Only held
    }

    function test_R2_allAsyncRevert_onlyHeldReturned() public {
        vault.mintShares(owner, 100e18);
        vault.setPendingRedeemShares(owner, 50e18);
        vault.setMaxWithdrawAssets(owner, 25e18);
        vault.setPendingDepositAssets(owner, 10e18);
        vault.setClaimableDepositAssets(owner, 5e18);

        vault.setRevertOnPendingRedeemRequest(true);
        vault.setRevertOnMaxWithdraw(true);
        vault.setRevertOnPendingDepositRequest(true);
        vault.setRevertOnClaimableDepositRequest(true);

        uint256 tvl = oracle.getTVLByOwnerOfShares(vaultAddr, owner);
        assertEq(tvl, 100e18); // Only held component
    }

    function test_R2_breakdown_revertingComponentsReturnZero() public {
        vault.setPendingRedeemShares(owner, 50e18);
        vault.setMaxWithdrawAssets(owner, 25e18);
        vault.setRevertOnPendingRedeemRequest(true);

        (uint256 held, uint256 pendingRedeem, uint256 claimableRedeem, uint256 pendingDeposit, uint256 claimableDeposit)
        = oracle.getAsyncStateBreakdown(vaultAddr, owner);

        assertEq(held, 0);
        assertEq(pendingRedeem, 0); // Reverted → 0
        assertEq(claimableRedeem, 25e18); // Still works
        assertEq(pendingDeposit, 0);
        assertEq(claimableDeposit, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        R1: HARD REVERT
    //////////////////////////////////////////////////////////////*/

    function test_R1_getPricePerShare_revertsOnConvertToAssetsFailure() public {
        vault.setRevertOnConvertToAssets(true);
        vm.expectRevert();
        oracle.getPricePerShare(vaultAddr);
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_zeroShareBalance_skipsConvertToAssets() public view {
        // No shares minted, heldValue should be 0 without calling convertToAssets
        (uint256 held,,,,) = oracle.getAsyncStateBreakdown(vaultAddr, owner);
        assertEq(held, 0);
    }

    function test_zeroPendingShares_skipsConvertToAssets() public {
        vault.setPendingRedeemShares(owner, 0);
        (, uint256 pendingRedeem,,,) = oracle.getAsyncStateBreakdown(vaultAddr, owner);
        assertEq(pendingRedeem, 0);
    }

    function test_differentOwnersHaveIndependentState() public {
        address owner2 = makeAddr("owner2");

        vault.mintShares(owner, 100e18);
        vault.mintShares(owner2, 200e18);
        vault.setPendingRedeemShares(owner, 10e18);
        vault.setMaxWithdrawAssets(owner2, 50e18);

        uint256 tvl1 = oracle.getTVLByOwnerOfShares(vaultAddr, owner);
        uint256 tvl2 = oracle.getTVLByOwnerOfShares(vaultAddr, owner2);

        assertEq(tvl1, 110e18); // 100 held + 10 pending
        assertEq(tvl2, 250e18); // 200 held + 50 claimable
    }

    function test_6decimal_vault() public {
        MockERC7540VaultFull vault6 = new MockERC7540VaultFull(6, 6);
        vault6.setAssetsPerShare(1e6); // 1:1 at 6 decimals
        vault6.mintShares(owner, 100e6);
        vault6.setPendingRedeemShares(owner, 50e6);
        vault6.setMaxWithdrawAssets(owner, 25e6);
        vault6.setPendingDepositAssets(owner, 10e6);
        vault6.setClaimableDepositAssets(owner, 5e6);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(vault6), owner);
        assertEq(tvl, 100e6 + 50e6 + 25e6 + 10e6 + 5e6);
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_getTVLByOwnerOfShares_noOverflow(
        uint128 heldShares,
        uint128 pendingShares,
        uint128 maxWithdraw_,
        uint128 pendingDeposit_,
        uint128 claimableDeposit_
    )
        public
    {
        vault.mintShares(owner, heldShares);
        vault.setPendingRedeemShares(owner, pendingShares);
        vault.setMaxWithdrawAssets(owner, maxWithdraw_);
        vault.setPendingDepositAssets(owner, pendingDeposit_);
        vault.setClaimableDepositAssets(owner, claimableDeposit_);

        // Should not revert
        uint256 tvl = oracle.getTVLByOwnerOfShares(vaultAddr, owner);

        // TVL should be sum of all components (1:1 rate)
        uint256 expected =
            uint256(heldShares) + uint256(pendingShares) + uint256(maxWithdraw_) + uint256(pendingDeposit_)
            + uint256(claimableDeposit_);
        assertEq(tvl, expected);
    }

    function testFuzz_getPricePerShare_variousRates(uint128 assetsPerShare_) public {
        vm.assume(assetsPerShare_ > 0);
        vault.setAssetsPerShare(assetsPerShare_);

        uint256 pps = oracle.getPricePerShare(vaultAddr);
        // PPS = convertToAssets(1e18) = (1e18 * assetsPerShare_) / 1e18 = assetsPerShare_
        assertEq(pps, assetsPerShare_);
    }

    function testFuzz_getWithdrawalShareOutput_inverseOfGetAssetOutput(uint128 shares_) public view {
        vm.assume(shares_ > 0);
        // Get asset output for shares
        uint256 assets = oracle.getAssetOutput(vaultAddr, address(0), shares_);
        if (assets == 0) return;

        // Get withdrawal share output for those assets
        uint256 sharesBack = oracle.getWithdrawalShareOutput(vaultAddr, address(0), assets);

        // Due to ceil rounding, sharesBack >= shares_
        assertGe(sharesBack, shares_);
    }

    function testFuzz_getShareOutput_variousRates(uint128 rate_, uint128 assetsIn_) public {
        vm.assume(rate_ > 0);
        vault.setAssetsPerShare(rate_);

        uint256 shares = oracle.getShareOutput(vaultAddr, address(0), assetsIn_);

        // convertToShares = (assets * 1e18) / assetsPerShare
        uint256 expected = uint256(assetsIn_) * 1e18 / uint256(rate_);
        assertEq(shares, expected);
    }

    function testFuzz_getAssetOutput_variousRates(uint64 rate_, uint128 sharesIn_) public {
        vm.assume(rate_ > 0);
        vault.setAssetsPerShare(rate_);

        uint256 assets = oracle.getAssetOutput(vaultAddr, address(0), sharesIn_);

        // convertToAssets = (shares * assetsPerShare) / 1e18
        uint256 expected = uint256(sharesIn_) * uint256(rate_) / 1e18;
        assertEq(assets, expected);
    }

    function testFuzz_roundTrip_assetToShareToAsset(uint128 assetsIn_) public view {
        vm.assume(assetsIn_ > 0);

        uint256 shares = oracle.getShareOutput(vaultAddr, address(0), assetsIn_);
        if (shares == 0) return;

        uint256 assetsBack = oracle.getAssetOutput(vaultAddr, address(0), shares);

        // Floor rounding on both conversions means assetsBack <= assetsIn_
        assertLe(assetsBack, assetsIn_);
    }

    function testFuzz_getWithdrawalShareOutput_ceilFavorsVault(uint128 assetsIn_, uint64 rate_) public {
        vm.assume(rate_ > 0);
        vm.assume(assetsIn_ > 0);
        vault.setAssetsPerShare(rate_);

        uint256 shares = oracle.getWithdrawalShareOutput(vaultAddr, address(0), assetsIn_);
        if (shares == 0) return;

        // Ceil rounding guarantees: getAssetOutput(shares) >= assetsIn_
        uint256 assetsOut = oracle.getAssetOutput(vaultAddr, address(0), shares);
        assertGe(assetsOut, assetsIn_, "Ceil rounding must favor the vault");
    }

    /// @notice INV-5 fuzz: claimableRedeemValue always equals maxWithdraw exactly
    function testFuzz_INV5_claimableRedeemValue_equalsMaxWithdraw(uint128 maxWithdraw_) public {
        vault.setMaxWithdrawAssets(owner, maxWithdraw_);

        (,, uint256 claimableRedeemValue,,) = oracle.getAsyncStateBreakdown(vaultAddr, owner);
        assertEq(claimableRedeemValue, maxWithdraw_, "INV-5: claimableRedeemValue must equal maxWithdraw");
    }

    /// @notice INV-7 fuzz: getTVLByOwnerOfShares never reverts regardless of revert flags
    function testFuzz_INV7_gracefulDegradation_neverReverts(
        uint128 heldShares_,
        uint128 pendingShares_,
        uint128 maxWithdraw_,
        uint128 pendingDeposit_,
        uint128 claimableDeposit_,
        bool revertPendingRedeem,
        bool revertMaxWithdraw,
        bool revertPendingDeposit,
        bool revertClaimableDeposit
    )
        public
    {
        vault.mintShares(owner, heldShares_);
        vault.setPendingRedeemShares(owner, pendingShares_);
        vault.setMaxWithdrawAssets(owner, maxWithdraw_);
        vault.setPendingDepositAssets(owner, pendingDeposit_);
        vault.setClaimableDepositAssets(owner, claimableDeposit_);

        vault.setRevertOnPendingRedeemRequest(revertPendingRedeem);
        vault.setRevertOnMaxWithdraw(revertMaxWithdraw);
        vault.setRevertOnPendingDepositRequest(revertPendingDeposit);
        vault.setRevertOnClaimableDepositRequest(revertClaimableDeposit);

        // Must never revert (R2 graceful degradation)
        uint256 tvl = oracle.getTVLByOwnerOfShares(vaultAddr, owner);

        // Held shares always contribute (not wrapped in try/catch)
        assertGe(tvl, uint256(heldShares_), "Held value must always be present");
    }

    /// @notice INV-1 fuzz: TVL >= maxWithdraw(owner) when no reverts
    function testFuzz_INV1_TVL_gte_maxWithdraw(
        uint128 heldShares_,
        uint128 pendingShares_,
        uint128 maxWithdraw_,
        uint128 pendingDeposit_,
        uint128 claimableDeposit_
    )
        public
    {
        vault.mintShares(owner, heldShares_);
        vault.setPendingRedeemShares(owner, pendingShares_);
        vault.setMaxWithdrawAssets(owner, maxWithdraw_);
        vault.setPendingDepositAssets(owner, pendingDeposit_);
        vault.setClaimableDepositAssets(owner, claimableDeposit_);

        uint256 tvl = oracle.getTVLByOwnerOfShares(vaultAddr, owner);
        assertGe(tvl, uint256(maxWithdraw_), "INV-1: TVL must be >= maxWithdraw(owner)");
    }

    /// @notice Fuzz: breakdown components sum to TVL with exchange rate
    function testFuzz_componentSum_equals_TVL(
        uint128 heldShares_,
        uint128 pendingShares_,
        uint128 maxWithdraw_,
        uint128 pendingDeposit_,
        uint128 claimableDeposit_,
        uint64 rate_
    )
        public
    {
        vm.assume(rate_ > 0);
        vault.setAssetsPerShare(rate_);
        vault.mintShares(owner, heldShares_);
        vault.setPendingRedeemShares(owner, pendingShares_);
        vault.setMaxWithdrawAssets(owner, maxWithdraw_);
        vault.setPendingDepositAssets(owner, pendingDeposit_);
        vault.setClaimableDepositAssets(owner, claimableDeposit_);

        (uint256 held, uint256 pendingRedeem, uint256 claimableRedeem, uint256 pendingDeposit, uint256 claimableDeposit)
        = oracle.getAsyncStateBreakdown(vaultAddr, owner);
        uint256 tvl = oracle.getTVLByOwnerOfShares(vaultAddr, owner);

        assertEq(tvl, held + pendingRedeem + claimableRedeem + pendingDeposit + claimableDeposit, "Components must sum to TVL");
    }

    /*//////////////////////////////////////////////////////////////
                        BATCH METHODS (AbstractYieldSourceOracle)
    //////////////////////////////////////////////////////////////*/

    function test_getPricePerShareMultiple_singleVault() public view {
        address[] memory vaults = new address[](1);
        vaults[0] = vaultAddr;

        uint256[] memory prices = oracle.getPricePerShareMultiple(vaults);
        assertEq(prices.length, 1);
        assertEq(prices[0], 1e18);
    }

    function test_getPricePerShareMultiple_multipleVaults() public {
        MockERC7540VaultFull vault2 = new MockERC7540VaultFull(18, 18);
        vault2.setAssetsPerShare(2e18);
        MockERC7540VaultFull vault3 = new MockERC7540VaultFull(6, 6);
        vault3.setAssetsPerShare(1.5e6);

        address[] memory vaults = new address[](3);
        vaults[0] = vaultAddr;
        vaults[1] = address(vault2);
        vaults[2] = address(vault3);

        uint256[] memory prices = oracle.getPricePerShareMultiple(vaults);
        assertEq(prices.length, 3);
        assertEq(prices[0], 1e18);
        assertEq(prices[1], 2e18);
        assertEq(prices[2], 1.5e6);
    }

    function test_getTVLByOwnerOfSharesMultiple_singleOwner() public {
        vault.mintShares(owner, 100e18);
        vault.setMaxWithdrawAssets(owner, 50e18);

        address[] memory vaults = new address[](1);
        vaults[0] = vaultAddr;
        address[][] memory owners = new address[][](1);
        owners[0] = new address[](1);
        owners[0][0] = owner;

        (uint256[][] memory tvls,) = oracle.getTVLByOwnerOfSharesMultiple(vaults, owners);
        assertEq(tvls.length, 1);
        assertEq(tvls[0].length, 1);
        assertEq(tvls[0][0], 150e18); // 100 held + 50 claimable
    }

    function test_getTVLByOwnerOfSharesMultiple_arrayLengthMismatch_reverts() public {
        address[] memory vaults = new address[](2);
        vaults[0] = vaultAddr;
        vaults[1] = vaultAddr;
        address[][] memory owners = new address[][](1);
        owners[0] = new address[](1);
        owners[0][0] = owner;

        vm.expectRevert(IYieldSourceOracle.ARRAY_LENGTH_MISMATCH.selector);
        oracle.getTVLByOwnerOfSharesMultiple(vaults, owners);
    }

    function test_getTVLMultiple_multipleVaults() public {
        vault.setTotalAssets(1_000e18);
        MockERC7540VaultFull vault2 = new MockERC7540VaultFull(18, 18);
        vault2.setTotalAssets(2_000e18);
        MockERC7540VaultFull vault3 = new MockERC7540VaultFull(6, 6);
        vault3.setTotalAssets(500e6);

        address[] memory vaults = new address[](3);
        vaults[0] = vaultAddr;
        vaults[1] = address(vault2);
        vaults[2] = address(vault3);

        uint256[] memory tvls = oracle.getTVLMultiple(vaults);
        assertEq(tvls.length, 3);
        assertEq(tvls[0], 1_000e18);
        assertEq(tvls[1], 2_000e18);
        assertEq(tvls[2], 500e6);
    }

    /*//////////////////////////////////////////////////////////////
                        GET ASSET OUTPUT WITH FEES
    //////////////////////////////////////////////////////////////*/

    function test_getAssetOutputWithFees_noConfigured() public view {
        bytes32 fakeOracleId = keccak256("nonexistent");
        // No config set, try/catch returns base assetOutput without fees
        uint256 result = oracle.getAssetOutputWithFees(fakeOracleId, vaultAddr, address(0), owner, 10e18);
        uint256 expected = oracle.getAssetOutput(vaultAddr, address(0), 10e18);
        assertEq(result, expected);
    }

    function test_getAssetOutputWithFees_withFees() public {
        // Deploy mock ledger that returns a fixed fee
        MockSuperLedger mockLedger = new MockSuperLedger(1e18); // 1e18 fee

        // Set up ledger config
        bytes32 salt = keccak256("test-oracle");
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = salt;
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle),
            feePercent: 1000, // 10%
            feeRecipient: makeAddr("feeRecipient"),
            ledger: address(mockLedger)
        });
        ledgerConfig.setYieldSourceOracles(salts, configs);

        // Compute the oracleId the same way SuperLedgerConfiguration._deriveWithSender does
        bytes32 oracleId = keccak256(abi.encodePacked(salt, address(this)));

        uint256 result = oracle.getAssetOutputWithFees(oracleId, vaultAddr, address(0), owner, 10e18);
        uint256 baseOutput = oracle.getAssetOutput(vaultAddr, address(0), 10e18);
        // result = baseOutput + feeAmount (1e18)
        assertEq(result, baseOutput + 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                    ZERO-DECIMAL EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_decimals_zeroDecimalVault() public {
        MockERC7540VaultFull vault0 = new MockERC7540VaultFull(0, 0);
        assertEq(oracle.decimals(address(vault0)), 0);
    }

    function test_getPricePerShare_zeroDecimalVault() public {
        MockERC7540VaultFull vault0 = new MockERC7540VaultFull(0, 0);
        // 10^0 = 1 share, assetsPerShare = 10^0 = 1
        // convertToAssets(1) = (1 * 1) / 1 = 1
        uint256 pps = oracle.getPricePerShare(address(vault0));
        assertEq(pps, 1); // convertToAssets(10^0) = convertToAssets(1) = 1
    }

    /*//////////////////////////////////////////////////////////////
                    REQUEST_ID ROUTING
    //////////////////////////////////////////////////////////////*/

    function test_getAsyncStateBreakdown_usesRequestId() public {
        // Deploy oracle with REQUEST_ID = 42
        ERC7540YieldSourceOracle oracle42 = new ERC7540YieldSourceOracle(address(ledgerConfig), 42);

        // Configure mock to enforce requestId = 42
        vault.setEnforceRequestId(true, 42);
        vault.setPendingRedeemShares(owner, 30e18);
        vault.setPendingDepositAssets(owner, 10e18);
        vault.setClaimableDepositAssets(owner, 5e18);

        // oracle42 passes REQUEST_ID=42, mock accepts it
        (, uint256 pendingRedeem,, uint256 pendingDeposit, uint256 claimableDeposit) =
            oracle42.getAsyncStateBreakdown(vaultAddr, owner);

        assertEq(pendingRedeem, 30e18);
        assertEq(pendingDeposit, 10e18);
        assertEq(claimableDeposit, 5e18);
    }

    function test_getAsyncStateBreakdown_wrongRequestId_gracefulDegradation() public {
        // Deploy oracle with REQUEST_ID = 0
        // But vault expects requestId = 42 → all async calls revert → caught by try/catch
        vault.setEnforceRequestId(true, 42);
        vault.mintShares(owner, 100e18);
        vault.setPendingRedeemShares(owner, 30e18);

        // oracle has REQUEST_ID=0, vault expects 42 → pendingRedeemRequest reverts → caught
        (uint256 held, uint256 pendingRedeem,,,) = oracle.getAsyncStateBreakdown(vaultAddr, owner);
        assertEq(held, 100e18); // held is not affected by requestId
        assertEq(pendingRedeem, 0); // wrong requestId → try/catch → 0
    }

    /*//////////////////////////////////////////////////////////////
                    _getShareToken FALLBACK
    //////////////////////////////////////////////////////////////*/

    /// @notice When vault implements share(), oracle uses it to discover the share token
    function test_getShareToken_usesShareWhenAvailable() public view {
        // MockERC7540VaultFull implements share() → returns separate shareToken
        uint8 dec = oracle.decimals(vaultAddr);
        assertEq(dec, 18);
        // Verify it's reading from the share token (not the vault address)
        assertEq(dec, vault.shareToken().decimals());
    }

    /// @notice When vault does NOT implement share(), oracle falls back to vault address as share token
    function test_getShareToken_fallbackToVaultAddress() public {
        // Deploy a vault without share() function
        MockERC4626NoShare noShareVault = new MockERC4626NoShare(18);
        noShareVault.setAssetsPerShare(1.5e18);
        noShareVault.mint(owner, 100e18);

        // Oracle should fallback to using vault address as share token
        uint8 dec = oracle.decimals(address(noShareVault));
        assertEq(dec, 18, "decimals should read from vault itself");

        uint256 pps = oracle.getPricePerShare(address(noShareVault));
        assertEq(pps, 1.5e18, "PPS uses vault's convertToAssets");

        uint256 balance = oracle.getBalanceOfOwner(address(noShareVault), owner);
        assertEq(balance, 100e18, "balanceOf reads from vault (as share token)");
    }

    /// @notice Full TVL with all 5 components on vault without share()
    function test_getShareToken_fallback_fullLifecycle() public {
        MockERC4626NoShare noShareVault = new MockERC4626NoShare(6);
        noShareVault.setAssetsPerShare(1_050_000); // 1.05 at 6 dec
        noShareVault.mint(owner, 100e6);
        noShareVault.setPendingRedeemShares(owner, 20e6);
        noShareVault.setMaxWithdrawAssets(owner, 15e6);
        noShareVault.setPendingDepositAssets(owner, 10e6);
        noShareVault.setClaimableDepositAssets(owner, 5e6);
        noShareVault.setTotalAssets(1_000_000e6);

        assertEq(oracle.decimals(address(noShareVault)), 6);
        assertEq(oracle.getPricePerShare(address(noShareVault)), 1_050_000);
        assertEq(oracle.getTVL(address(noShareVault)), 1_000_000e6);

        (uint256 held, uint256 pendingRedeem, uint256 claimableRedeem, uint256 pendingDeposit, uint256 claimableDeposit)
        = oracle.getAsyncStateBreakdown(address(noShareVault), owner);

        // held: 100e6 shares * 1.05 = 105e6
        assertEq(held, noShareVault.convertToAssets(100e6));
        assertEq(pendingRedeem, noShareVault.convertToAssets(20e6));
        assertEq(claimableRedeem, 15e6);
        assertEq(pendingDeposit, 10e6);
        assertEq(claimableDeposit, 5e6);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(noShareVault), owner);
        assertEq(tvl, held + pendingRedeem + claimableRedeem + pendingDeposit + claimableDeposit);
    }

    /*//////////////////////////////////////////////////////////////
                    TRY/CATCH SUBTLETY
    //////////////////////////////////////////////////////////////*/

    /// @notice When pendingRedeemRequest succeeds but convertToAssets reverts,
    ///         the entire call reverts because convertToAssets is inside the try-success block
    function test_getTVLByOwnerOfShares_convertToAssetsRevert_insideTrySuccess_propagates() public {
        // Set up: owner has NO held shares (skip line 211) but HAS pending redeem shares
        vault.setPendingRedeemShares(owner, 30e18);

        // Enable revert on convertToAssets
        vault.setRevertOnConvertToAssets(true);

        // pendingRedeemRequest(0, owner) succeeds → returns 30e18
        // Inside try success block: vault.convertToAssets(30e18) REVERTS
        // The catch only catches reverts from pendingRedeemRequest(), not from inner code
        // So the entire getAsyncStateBreakdown reverts
        vm.expectRevert("convertToAssets reverted");
        oracle.getAsyncStateBreakdown(vaultAddr, owner);
    }
}

/// @notice Minimal mock ISuperLedger that returns a fixed fee amount from previewFees
contract MockSuperLedger {
    uint256 public fixedFee;

    constructor(uint256 fixedFee_) {
        fixedFee = fixedFee_;
    }

    function previewFees(address, address, uint256, uint256, uint256, uint256, uint256) external view returns (uint256) {
        return fixedFee;
    }
}

/// @notice Minimal ERC-4626-style vault that does NOT implement share()
/// @dev Used to test _getShareToken fallback behavior. The vault IS the share token (ERC-20).
contract MockERC4626NoShare {
    uint8 private _decimals;
    uint256 public assetsPerShare;
    uint256 public vaultTotalAssets;

    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public pendingRedeemShares;
    mapping(address => uint256) public maxWithdrawAssets;
    mapping(address => uint256) public pendingDepositAssets;
    mapping(address => uint256) public claimableDepositAssets;

    constructor(uint8 decimals_) {
        _decimals = decimals_;
        assetsPerShare = 10 ** decimals_; // Default 1:1
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function convertToAssets(uint256 shares) external view returns (uint256) {
        uint256 oneShare = 10 ** _decimals;
        if (oneShare == 0) return 0;
        return (shares * assetsPerShare) / oneShare;
    }

    function convertToShares(uint256 assets) external view returns (uint256) {
        if (assetsPerShare == 0) return 0;
        uint256 oneShare = 10 ** _decimals;
        return (assets * oneShare) / assetsPerShare;
    }

    function totalAssets() external view returns (uint256) {
        return vaultTotalAssets;
    }

    function maxWithdraw(address owner) external view returns (uint256) {
        return maxWithdrawAssets[owner];
    }

    function pendingRedeemRequest(uint256, address controller) external view returns (uint256) {
        return pendingRedeemShares[controller];
    }

    function pendingDepositRequest(uint256, address controller) external view returns (uint256) {
        return pendingDepositAssets[controller];
    }

    function claimableDepositRequest(uint256, address controller) external view returns (uint256) {
        return claimableDepositAssets[controller];
    }

    // NOTE: No share() function — this tests the fallback path

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function setAssetsPerShare(uint256 rate) external {
        assetsPerShare = rate;
    }

    function setTotalAssets(uint256 total) external {
        vaultTotalAssets = total;
    }

    function setPendingRedeemShares(address controller, uint256 shares) external {
        pendingRedeemShares[controller] = shares;
    }

    function setMaxWithdrawAssets(address controller, uint256 assets) external {
        maxWithdrawAssets[controller] = assets;
    }

    function setPendingDepositAssets(address controller, uint256 assets) external {
        pendingDepositAssets[controller] = assets;
    }

    function setClaimableDepositAssets(address controller, uint256 assets) external {
        claimableDepositAssets[controller] = assets;
    }
}
