// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { SpectraMetaVaultOracle } from "../../../src/accounting/oracles/SpectraMetaVaultOracle.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { IYieldSourceOracle } from "../../../src/interfaces/accounting/IYieldSourceOracle.sol";

/// @title MockSpectraMetaVault
/// @notice Simulates Spectra MetaVaultWrapper behavior for oracle testing
/// @dev Key behaviors:
///      - share() reverts (vault IS the share token)
///      - totalAssets() returns 0 (OZ default, idle USDC deployed to infra vault)
///      - convertToAssets() returns epoch snapshot rate (overridden by MetaVaultWrapper)
///      - maxWithdraw() returns value based on OZ _convertToAssets (different from convertToAssets)
///      - claimableRedeemRequest() returns claimable shares
contract MockSpectraMetaVault {
    uint8 private _decimals;

    /// @dev Epoch snapshot rate: assets per 1e{_decimals} shares
    uint256 public assetsPerShare;

    /// @dev Total supply of share tokens
    uint256 public vaultTotalSupply;

    /// @dev Per-address share balances
    mapping(address => uint256) public balanceOf;

    /// @dev Per-controller claimable redeem shares
    mapping(address => uint256) public claimableRedeemShares;

    /// @dev Per-controller pending redeem shares
    mapping(address => uint256) public pendingRedeemSharesMap;

    /// @dev Per-controller pending deposit assets
    mapping(address => uint256) public pendingDepositAssetsMap;

    /// @dev Per-controller claimable deposit assets
    mapping(address => uint256) public claimableDepositAssetsMap;

    /// @dev maxWithdraw returns a value based on OZ _convertToAssets (wrong pricing)
    mapping(address => uint256) public maxWithdrawValue;

    /// @dev Revert control flags
    bool public revertOnClaimableRedeemRequest;
    bool public revertOnPendingRedeemRequest;
    bool public revertOnPendingDepositRequest;
    bool public revertOnClaimableDepositRequest;
    bool public revertOnConvertToAssets;

    constructor(uint8 decimals_) {
        _decimals = decimals_;
        assetsPerShare = 10 ** decimals_; // Default 1:1
    }

    // --- share() reverts (MetaVaultWrapper does not implement it) ---
    // No share() function defined — calls to it will revert

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function totalSupply() external view returns (uint256) {
        return vaultTotalSupply;
    }

    /// @dev Always returns 0 to simulate OZ ERC4626Upgradeable.totalAssets() = asset.balanceOf(vault)
    function totalAssets() external pure returns (uint256) {
        return 0;
    }

    /// @dev Uses epoch snapshot rate (the overridden version in MetaVaultWrapper)
    function convertToAssets(uint256 shares) public view returns (uint256) {
        if (revertOnConvertToAssets) revert("convertToAssets reverted");
        uint256 oneShare = 10 ** _decimals;
        if (oneShare == 0) return 0;
        return (shares * assetsPerShare) / oneShare;
    }

    function convertToShares(uint256 assets) external view returns (uint256) {
        if (assetsPerShare == 0) return 0;
        uint256 oneShare = 10 ** _decimals;
        return (assets * oneShare) / assetsPerShare;
    }

    /// @dev Returns value based on OZ _convertToAssets (totalAssets/totalSupply ratio)
    /// which is meaningless for MetaVaultWrapper since totalAssets = 0
    function maxWithdraw(address owner) external view returns (uint256) {
        return maxWithdrawValue[owner];
    }

    function claimableRedeemRequest(uint256, address controller) external view returns (uint256) {
        if (revertOnClaimableRedeemRequest) revert("claimableRedeemRequest reverted");
        return claimableRedeemShares[controller];
    }

    function pendingRedeemRequest(uint256, address controller) external view returns (uint256) {
        if (revertOnPendingRedeemRequest) revert("pendingRedeemRequest reverted");
        return pendingRedeemSharesMap[controller];
    }

    function pendingDepositRequest(uint256, address controller) external view returns (uint256) {
        if (revertOnPendingDepositRequest) revert("pendingDepositRequest reverted");
        return pendingDepositAssetsMap[controller];
    }

    function claimableDepositRequest(uint256, address controller) external view returns (uint256) {
        if (revertOnClaimableDepositRequest) revert("claimableDepositRequest reverted");
        return claimableDepositAssetsMap[controller];
    }

    // --- Setters (test only) ---

    function setAssetsPerShare(uint256 rate) external {
        assetsPerShare = rate;
    }

    function setTotalSupply(uint256 supply) external {
        vaultTotalSupply = supply;
    }

    function mintShares(address to, uint256 amount) external {
        balanceOf[to] += amount;
        vaultTotalSupply += amount;
    }

    function setClaimableRedeemShares(address controller, uint256 shares) external {
        claimableRedeemShares[controller] = shares;
    }

    function setPendingRedeemShares(address controller, uint256 shares) external {
        pendingRedeemSharesMap[controller] = shares;
    }

    function setPendingDepositAssets(address controller, uint256 assets) external {
        pendingDepositAssetsMap[controller] = assets;
    }

    function setClaimableDepositAssets(address controller, uint256 assets) external {
        claimableDepositAssetsMap[controller] = assets;
    }

    function setMaxWithdrawValue(address controller, uint256 value) external {
        maxWithdrawValue[controller] = value;
    }

    function setRevertOnClaimableRedeemRequest(bool revert_) external {
        revertOnClaimableRedeemRequest = revert_;
    }

    function setRevertOnPendingRedeemRequest(bool revert_) external {
        revertOnPendingRedeemRequest = revert_;
    }

    function setRevertOnPendingDepositRequest(bool revert_) external {
        revertOnPendingDepositRequest = revert_;
    }

    function setRevertOnClaimableDepositRequest(bool revert_) external {
        revertOnClaimableDepositRequest = revert_;
    }

    function setRevertOnConvertToAssets(bool revert_) external {
        revertOnConvertToAssets = revert_;
    }
}

/// @title MockSpectraMetaVaultWithShareZero
/// @notice Simulates a vault where share() returns address(0) — tests P3-3 fix
contract MockSpectraMetaVaultWithShareZero is MockSpectraMetaVault {
    constructor(uint8 decimals_) MockSpectraMetaVault(decimals_) { }

    /// @dev Returns address(0) — oracle should fallback to vault address
    function share() external pure returns (address) {
        return address(0);
    }
}

/// @title MockSpectraMetaVaultWithShare
/// @notice Simulates a vault where share() returns a valid separate share token
contract MockSpectraMetaVaultWithShare is MockSpectraMetaVault {
    address public shareToken;

    constructor(uint8 decimals_, address shareToken_) MockSpectraMetaVault(decimals_) {
        shareToken = shareToken_;
    }

    function share() external view returns (address) {
        return shareToken;
    }
}

contract SpectraMetaVaultOracleTest is Test {
    SpectraMetaVaultOracle public oracle;
    MockSpectraMetaVault public vault;
    SuperLedgerConfiguration public ledgerConfig;

    address public owner;
    address public vaultAddr;

    function setUp() public {
        ledgerConfig = new SuperLedgerConfiguration();
        oracle = new SpectraMetaVaultOracle(address(ledgerConfig), 0);

        // 6 decimals to match USDC-based MetaVaultWrapper
        vault = new MockSpectraMetaVault(6);
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
        SpectraMetaVaultOracle oracle2 = new SpectraMetaVaultOracle(address(ledgerConfig), 42);
        assertEq(oracle2.REQUEST_ID(), 42);
    }

    function test_constructor_setsSuperLedgerConfiguration() public view {
        assertEq(oracle.SUPER_LEDGER_CONFIGURATION(), address(ledgerConfig));
    }

    /*//////////////////////////////////////////////////////////////
                            DECIMALS
    //////////////////////////////////////////////////////////////*/

    function test_decimals_6() public view {
        // MockSpectraMetaVault has no share() → fallback to vault address → vault.decimals() = 6
        assertEq(oracle.decimals(vaultAddr), 6);
    }

    /*//////////////////////////////////////////////////////////////
                        SHARE TOKEN FALLBACK
    //////////////////////////////////////////////////////////////*/

    function test_shareTokenFallback_shareReverts_usesVaultAddress() public view {
        // MockSpectraMetaVault has no share() function — it reverts
        // Oracle should fallback to vault address as share token
        uint8 dec = oracle.decimals(vaultAddr);
        assertEq(dec, 6, "should read decimals from vault itself");

        uint256 balance = oracle.getBalanceOfOwner(vaultAddr, owner);
        assertEq(balance, 0, "should read balanceOf from vault itself");
    }

    function test_shareTokenFallback_balanceOfWorks() public {
        vault.mintShares(owner, 100e6);
        assertEq(oracle.getBalanceOfOwner(vaultAddr, owner), 100e6);
    }

    /*//////////////////////////////////////////////////////////////
                        GET PRICE PER SHARE
    //////////////////////////////////////////////////////////////*/

    function test_getPricePerShare_1to1() public view {
        uint256 pps = oracle.getPricePerShare(vaultAddr);
        assertEq(pps, 1e6);
    }

    function test_getPricePerShare_epochRate() public {
        // Simulate epoch snapshot rate: 0.863 USDC/share
        vault.setAssetsPerShare(863_399);
        uint256 pps = oracle.getPricePerShare(vaultAddr);
        assertEq(pps, 863_399);
    }

    function test_getPricePerShare_revertsOnConvertToAssetsRevert() public {
        vault.setRevertOnConvertToAssets(true);
        vm.expectRevert();
        oracle.getPricePerShare(vaultAddr);
    }

    /*//////////////////////////////////////////////////////////////
                    GET TVL (BUG FIX #1)
    //////////////////////////////////////////////////////////////*/

    function test_getTVL_usesConvertToAssetsNotTotalAssets() public {
        // totalAssets() returns 0 (idle USDC)
        // But convertToAssets(totalSupply) should use epoch snapshot rate
        vault.setAssetsPerShare(863_399); // ~0.863 USDC/share
        vault.setTotalSupply(513_917);

        uint256 tvl = oracle.getTVL(vaultAddr);

        // TVL = convertToAssets(513_917) = 513_917 * 863_399 / 1e6 = 443_671
        uint256 expected = vault.convertToAssets(513_917);
        assertEq(tvl, expected);
        assertGt(tvl, 0, "getTVL must be > 0 even though totalAssets() = 0");
    }

    function test_getTVL_zeroSupply() public view {
        // totalSupply = 0 → getTVL = 0 (legitimate)
        uint256 tvl = oracle.getTVL(vaultAddr);
        assertEq(tvl, 0);
    }

    function test_getTVL_1to1Rate() public {
        vault.setTotalSupply(1_000_000e6);
        uint256 tvl = oracle.getTVL(vaultAddr);
        assertEq(tvl, 1_000_000e6);
    }

    /*//////////////////////////////////////////////////////////////
                    COMPONENT 3 (BUG FIX #2)
    //////////////////////////////////////////////////////////////*/

    function test_component3_usesClaimableRedeemRequest_notMaxWithdraw() public {
        vault.mintShares(owner, 100e6);
        vault.setAssetsPerShare(1_050_000); // 1.05 USDC/share

        // maxWithdraw returns wrong value (OZ _convertToAssets based on totalAssets=0)
        vault.setMaxWithdrawValue(owner, 0);

        // claimableRedeemRequest returns 50 shares claimable
        vault.setClaimableRedeemShares(owner, 50e6);

        (,, uint256 claimableRedeemValue,,) = oracle.getAsyncStateBreakdown(vaultAddr, owner);

        // Component 3 = convertToAssets(50e6) = 50e6 * 1_050_000 / 1e6 = 52_500_000
        uint256 expected = vault.convertToAssets(50e6);
        assertEq(claimableRedeemValue, expected);
        assertGt(claimableRedeemValue, 0, "Component 3 must not use maxWithdraw (which returns 0)");
    }

    function test_component3_claimableRedeemReverts_gracefulDegradation() public {
        vault.mintShares(owner, 100e6);
        vault.setClaimableRedeemShares(owner, 50e6);
        vault.setRevertOnClaimableRedeemRequest(true);

        (uint256 held,, uint256 claimableRedeem,,) = oracle.getAsyncStateBreakdown(vaultAddr, owner);

        assertEq(held, 100e6);
        assertEq(claimableRedeem, 0, "Reverted claimableRedeemRequest should be 0");
    }

    function test_component3_zeroClaimableShares() public {
        vault.setClaimableRedeemShares(owner, 0);

        (,, uint256 claimableRedeem,,) = oracle.getAsyncStateBreakdown(vaultAddr, owner);
        assertEq(claimableRedeem, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    ALL 5 COMPONENTS
    //////////////////////////////////////////////////////////////*/

    function test_allFiveComponents() public {
        vault.setAssetsPerShare(1_050_000); // 1.05 USDC/share

        vault.mintShares(owner, 100e6); // Component 1: 100 shares
        vault.setPendingRedeemShares(owner, 50e6); // Component 2: 50 shares pending
        vault.setClaimableRedeemShares(owner, 25e6); // Component 3: 25 shares claimable
        vault.setPendingDepositAssets(owner, 10e6); // Component 4: 10 USDC pending
        vault.setClaimableDepositAssets(owner, 5e6); // Component 5: 5 USDC claimable

        (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            uint256 claimableRedeemValue,
            uint256 pendingDepositValue,
            uint256 claimableDepositValue
        ) = oracle.getAsyncStateBreakdown(vaultAddr, owner);

        assertEq(heldValue, vault.convertToAssets(100e6));
        assertEq(pendingRedeemValue, vault.convertToAssets(50e6));
        assertEq(claimableRedeemValue, vault.convertToAssets(25e6));
        assertEq(pendingDepositValue, 10e6);
        assertEq(claimableDepositValue, 5e6);

        uint256 tvl = oracle.getTVLByOwnerOfShares(vaultAddr, owner);
        assertEq(tvl, heldValue + pendingRedeemValue + claimableRedeemValue + pendingDepositValue + claimableDepositValue);
    }

    function test_allZeroBalances() public view {
        (uint256 held, uint256 pendingRedeem, uint256 claimableRedeem, uint256 pendingDeposit, uint256 claimableDeposit)
        = oracle.getAsyncStateBreakdown(vaultAddr, owner);

        assertEq(held, 0);
        assertEq(pendingRedeem, 0);
        assertEq(claimableRedeem, 0);
        assertEq(pendingDeposit, 0);
        assertEq(claimableDeposit, 0);
    }

    function test_heldOnly() public {
        vault.mintShares(owner, 100e6);

        (uint256 held,,,,) = oracle.getAsyncStateBreakdown(vaultAddr, owner);
        assertEq(held, 100e6); // 1:1 rate
    }

    function test_pendingRedeemOnly() public {
        vault.setPendingRedeemShares(owner, 30e6);

        (, uint256 pendingRedeem,,,) = oracle.getAsyncStateBreakdown(vaultAddr, owner);
        assertEq(pendingRedeem, 30e6);
    }

    function test_withExchangeRate() public {
        vault.setAssetsPerShare(2e6); // 2 assets per share
        vault.mintShares(owner, 100e6);
        vault.setPendingRedeemShares(owner, 50e6);

        (uint256 held, uint256 pendingRedeem,,,) = oracle.getAsyncStateBreakdown(vaultAddr, owner);

        assertEq(held, 200e6); // 100 shares * 2 assets/share
        assertEq(pendingRedeem, 100e6); // 50 shares * 2 assets/share
    }

    /*//////////////////////////////////////////////////////////////
                    GET SHARE OUTPUT / WITHDRAWAL SHARE OUTPUT
    //////////////////////////////////////////////////////////////*/

    function test_getShareOutput_1to1() public view {
        uint256 shares = oracle.getShareOutput(vaultAddr, address(0), 1e6);
        assertEq(shares, 1e6);
    }

    function test_getWithdrawalShareOutput_1to1() public view {
        uint256 shares = oracle.getWithdrawalShareOutput(vaultAddr, address(0), 1e6);
        assertEq(shares, 1e6);
    }

    function test_getWithdrawalShareOutput_ceilRounding() public {
        vault.setAssetsPerShare(3e6);
        uint256 shares = oracle.getWithdrawalShareOutput(vaultAddr, address(0), 1e6);
        uint256 expected = Math.mulDiv(1e6, 1e6, 3e6, Math.Rounding.Ceil);
        assertEq(shares, expected);
    }

    function test_getWithdrawalShareOutput_zeroAssetsPerShare_reverts() public {
        vault.setAssetsPerShare(0);
        vm.expectRevert("SpectraMetaVaultOracle: PPS unavailable");
        oracle.getWithdrawalShareOutput(vaultAddr, address(0), 1e6);
    }

    function test_getAssetOutput_1to1() public view {
        uint256 assets = oracle.getAssetOutput(vaultAddr, address(0), 1e6);
        assertEq(assets, 1e6);
    }

    /*//////////////////////////////////////////////////////////////
                    R2: GRACEFUL DEGRADATION
    //////////////////////////////////////////////////////////////*/

    function test_R2_pendingRedeemReverts_componentDropped() public {
        vault.mintShares(owner, 100e6);
        vault.setPendingRedeemShares(owner, 50e6);
        vault.setRevertOnPendingRedeemRequest(true);

        uint256 tvl = oracle.getTVLByOwnerOfShares(vaultAddr, owner);
        assertEq(tvl, 100e6); // Only held component
    }

    function test_R2_claimableRedeemReverts_componentDropped() public {
        vault.mintShares(owner, 100e6);
        vault.setClaimableRedeemShares(owner, 25e6);
        vault.setRevertOnClaimableRedeemRequest(true);

        uint256 tvl = oracle.getTVLByOwnerOfShares(vaultAddr, owner);
        assertEq(tvl, 100e6); // Only held
    }

    function test_R2_pendingDepositReverts_componentDropped() public {
        vault.mintShares(owner, 100e6);
        vault.setPendingDepositAssets(owner, 10e6);
        vault.setRevertOnPendingDepositRequest(true);

        uint256 tvl = oracle.getTVLByOwnerOfShares(vaultAddr, owner);
        assertEq(tvl, 100e6); // Only held
    }

    function test_R2_claimableDepositReverts_componentDropped() public {
        vault.mintShares(owner, 100e6);
        vault.setClaimableDepositAssets(owner, 5e6);
        vault.setRevertOnClaimableDepositRequest(true);

        uint256 tvl = oracle.getTVLByOwnerOfShares(vaultAddr, owner);
        assertEq(tvl, 100e6); // Only held
    }

    function test_R2_allAsyncRevert_onlyHeldReturned() public {
        vault.mintShares(owner, 100e6);
        vault.setPendingRedeemShares(owner, 50e6);
        vault.setClaimableRedeemShares(owner, 25e6);
        vault.setPendingDepositAssets(owner, 10e6);
        vault.setClaimableDepositAssets(owner, 5e6);

        vault.setRevertOnPendingRedeemRequest(true);
        vault.setRevertOnClaimableRedeemRequest(true);
        vault.setRevertOnPendingDepositRequest(true);
        vault.setRevertOnClaimableDepositRequest(true);

        uint256 tvl = oracle.getTVLByOwnerOfShares(vaultAddr, owner);
        assertEq(tvl, 100e6); // Only held component
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
                    TRY/CATCH SUBTLETY
    //////////////////////////////////////////////////////////////*/

    function test_convertToAssetsRevert_insideClaimableRedeemSuccess_gracefullyDegrades() public {
        // claimableRedeemRequest succeeds → returns shares
        // But convertToAssets reverts inside the try success block
        // With P2-1 fix: inner convertToAssets is wrapped in try/catch, so component defaults to 0
        vault.setClaimableRedeemShares(owner, 50e6);
        vault.setRevertOnConvertToAssets(true);

        // Should NOT revert — graceful degradation catches the inner convertToAssets revert
        (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            uint256 claimableRedeemValue,
            uint256 pendingDepositValue,
            uint256 claimableDepositValue
        ) = oracle.getAsyncStateBreakdown(vaultAddr, owner);

        // All share-based components should be 0 since convertToAssets reverts
        assertEq(heldValue, 0, "held should be 0 when convertToAssets reverts");
        assertEq(pendingRedeemValue, 0, "pendingRedeem should be 0");
        assertEq(claimableRedeemValue, 0, "claimableRedeem should be 0 when convertToAssets reverts");
        assertEq(pendingDepositValue, 0);
        assertEq(claimableDepositValue, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    DIFFERENT OWNERS
    //////////////////////////////////////////////////////////////*/

    function test_differentOwnersHaveIndependentState() public {
        address owner2 = makeAddr("owner2");

        vault.mintShares(owner, 100e6);
        vault.mintShares(owner2, 200e6);
        vault.setClaimableRedeemShares(owner, 10e6);
        vault.setPendingDepositAssets(owner2, 50e6);

        uint256 tvl1 = oracle.getTVLByOwnerOfShares(vaultAddr, owner);
        uint256 tvl2 = oracle.getTVLByOwnerOfShares(vaultAddr, owner2);

        assertEq(tvl1, 110e6); // 100 held + 10 claimable redeem
        assertEq(tvl2, 250e6); // 200 held + 50 pending deposit
    }

    /*//////////////////////////////////////////////////////////////
                    FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_getTVL_equalsConvertToAssetsOfTotalSupply(uint128 supply_, uint64 rate_) public {
        vm.assume(rate_ > 0);
        vault.setAssetsPerShare(rate_);
        vault.setTotalSupply(supply_);

        uint256 tvl = oracle.getTVL(vaultAddr);
        uint256 expected = vault.convertToAssets(supply_);
        assertEq(tvl, expected);
    }

    function testFuzz_getTVLByOwnerOfShares_noOverflow(
        uint128 heldShares,
        uint128 pendingShares,
        uint128 claimableShares,
        uint128 pendingDeposit_,
        uint128 claimableDeposit_
    )
        public
    {
        vault.mintShares(owner, heldShares);
        vault.setPendingRedeemShares(owner, pendingShares);
        vault.setClaimableRedeemShares(owner, claimableShares);
        vault.setPendingDepositAssets(owner, pendingDeposit_);
        vault.setClaimableDepositAssets(owner, claimableDeposit_);

        // Should not revert
        uint256 tvl = oracle.getTVLByOwnerOfShares(vaultAddr, owner);

        // TVL should be sum of all components (1:1 rate)
        uint256 expected = uint256(heldShares) + uint256(pendingShares) + uint256(claimableShares)
            + uint256(pendingDeposit_) + uint256(claimableDeposit_);
        assertEq(tvl, expected);
    }

    function testFuzz_gracefulDegradation_neverReverts(
        uint128 heldShares_,
        bool revertPendingRedeem,
        bool revertClaimableRedeem,
        bool revertPendingDeposit,
        bool revertClaimableDeposit
    )
        public
    {
        vault.mintShares(owner, heldShares_);

        vault.setRevertOnPendingRedeemRequest(revertPendingRedeem);
        vault.setRevertOnClaimableRedeemRequest(revertClaimableRedeem);
        vault.setRevertOnPendingDepositRequest(revertPendingDeposit);
        vault.setRevertOnClaimableDepositRequest(revertClaimableDeposit);

        // Must never revert (R2 graceful degradation)
        uint256 tvl = oracle.getTVLByOwnerOfShares(vaultAddr, owner);

        // Held shares always contribute
        assertGe(tvl, uint256(heldShares_), "Held value must always be present");
    }

    function testFuzz_componentSum_equals_TVL(
        uint128 heldShares_,
        uint128 pendingShares_,
        uint128 claimableShares_,
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
        vault.setClaimableRedeemShares(owner, claimableShares_);
        vault.setPendingDepositAssets(owner, pendingDeposit_);
        vault.setClaimableDepositAssets(owner, claimableDeposit_);

        (uint256 held, uint256 pendingRedeem, uint256 claimableRedeem, uint256 pendingDeposit, uint256 claimableDeposit)
        = oracle.getAsyncStateBreakdown(vaultAddr, owner);
        uint256 tvl = oracle.getTVLByOwnerOfShares(vaultAddr, owner);

        assertEq(
            tvl, held + pendingRedeem + claimableRedeem + pendingDeposit + claimableDeposit, "Components must sum to TVL"
        );
    }

    /*//////////////////////////////////////////////////////////////
                    SECURITY FIXES
    //////////////////////////////////////////////////////////////*/

    // --- P2-1: Inner convertToAssets wrapped in try/catch ---

    function test_P2_1_convertToAssetsRevert_insidePendingRedeemSuccess_gracefullyDegrades() public {
        // pendingRedeemRequest succeeds → returns shares
        // But convertToAssets reverts → Component 2 should default to 0, not propagate revert
        vault.setPendingRedeemShares(owner, 30e6);
        vault.setPendingDepositAssets(owner, 10e6); // Component 4 (assets, not affected by convertToAssets)
        vault.setRevertOnConvertToAssets(true);

        (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            ,
            uint256 pendingDepositValue,
        ) = oracle.getAsyncStateBreakdown(vaultAddr, owner);

        assertEq(heldValue, 0, "held should be 0 (no shares + convertToAssets reverts)");
        assertEq(pendingRedeemValue, 0, "pendingRedeem should gracefully degrade to 0");
        assertEq(pendingDepositValue, 10e6, "pendingDeposit (assets) should survive convertToAssets revert");
    }

    function test_P2_1_convertToAssetsRevert_mixedState_assetComponentsSurvive() public {
        // All 5 components set, but convertToAssets reverts
        // Components 4 & 5 (asset-denominated) should survive
        // Components 1, 2, 3 (share-denominated → need convertToAssets) should be 0
        vault.mintShares(owner, 100e6);
        vault.setPendingRedeemShares(owner, 50e6);
        vault.setClaimableRedeemShares(owner, 25e6);
        vault.setPendingDepositAssets(owner, 10e6);
        vault.setClaimableDepositAssets(owner, 5e6);
        vault.setRevertOnConvertToAssets(true);

        // Component 1 (held shares) calls convertToAssets WITHOUT try/catch (R1 — hard revert)
        // So getAsyncStateBreakdown should revert entirely because heldShares > 0
        vm.expectRevert("convertToAssets reverted");
        oracle.getAsyncStateBreakdown(vaultAddr, owner);
    }

    function test_P2_1_convertToAssetsRevert_noHeldShares_assetComponentsSurvive() public {
        // No held shares (Component 1 skipped), but Components 2 & 3 have shares
        // convertToAssets reverts → Components 2 & 3 gracefully degrade
        // Components 4 & 5 (assets) should survive
        vault.setPendingRedeemShares(owner, 50e6);
        vault.setClaimableRedeemShares(owner, 25e6);
        vault.setPendingDepositAssets(owner, 10e6);
        vault.setClaimableDepositAssets(owner, 5e6);
        vault.setRevertOnConvertToAssets(true);

        (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            uint256 claimableRedeemValue,
            uint256 pendingDepositValue,
            uint256 claimableDepositValue
        ) = oracle.getAsyncStateBreakdown(vaultAddr, owner);

        assertEq(heldValue, 0, "held should be 0 (no shares)");
        assertEq(pendingRedeemValue, 0, "pendingRedeem should gracefully degrade to 0");
        assertEq(claimableRedeemValue, 0, "claimableRedeem should gracefully degrade to 0");
        assertEq(pendingDepositValue, 10e6, "pendingDeposit should survive");
        assertEq(claimableDepositValue, 5e6, "claimableDeposit should survive");

        uint256 tvl = oracle.getTVLByOwnerOfShares(vaultAddr, owner);
        assertEq(tvl, 15e6, "TVL should only include asset-denominated components");
    }

    // --- P3-2: getWithdrawalShareOutput reverts when PPS unavailable ---

    function test_P3_2_getWithdrawalShareOutput_revertsOnZeroPPS_withLargeAssets() public {
        vault.setAssetsPerShare(0);
        vm.expectRevert("SpectraMetaVaultOracle: PPS unavailable");
        oracle.getWithdrawalShareOutput(vaultAddr, address(0), 1_000_000e6);
    }

    function test_P3_2_getWithdrawalShareOutput_nonZeroPPS_works() public {
        vault.setAssetsPerShare(500_000); // 0.5 USDC/share
        uint256 shares = oracle.getWithdrawalShareOutput(vaultAddr, address(0), 1e6);
        // To withdraw 1 USDC at 0.5 USDC/share, need 2 shares (Ceil)
        uint256 expected = Math.mulDiv(1e6, 1e6, 500_000, Math.Rounding.Ceil);
        assertEq(shares, expected);
        assertEq(shares, 2e6);
    }

    // --- P3-3: _getShareToken handles share() returning address(0) ---

    function test_P3_3_shareReturnsZeroAddress_fallsBackToVaultAddress() public {
        MockSpectraMetaVaultWithShareZero vaultWithShareZero = new MockSpectraMetaVaultWithShareZero(6);
        address vaultWithShareZeroAddr = address(vaultWithShareZero);

        // share() returns address(0) → oracle should fallback to vault address
        uint8 dec = oracle.decimals(vaultWithShareZeroAddr);
        assertEq(dec, 6, "should read decimals from vault itself when share() returns address(0)");
    }

    function test_P3_3_shareReturnsZeroAddress_balanceOfWorks() public {
        MockSpectraMetaVaultWithShareZero vaultWithShareZero = new MockSpectraMetaVaultWithShareZero(6);
        address vaultWithShareZeroAddr = address(vaultWithShareZero);
        vaultWithShareZero.mintShares(owner, 100e6);

        uint256 balance = oracle.getBalanceOfOwner(vaultWithShareZeroAddr, owner);
        assertEq(balance, 100e6, "balanceOf should work via vault fallback");
    }

    function test_P3_3_shareReturnsValidAddress_usesShareToken() public {
        // Deploy a separate "share token" mock
        MockSpectraMetaVault shareTokenMock = new MockSpectraMetaVault(18);
        MockSpectraMetaVaultWithShare vaultWithShare =
            new MockSpectraMetaVaultWithShare(6, address(shareTokenMock));

        // decimals should come from the share token (18), not the vault (6)
        uint8 dec = oracle.decimals(address(vaultWithShare));
        assertEq(dec, 18, "should use share token decimals when share() returns valid address");
    }

    /*//////////////////////////////////////////////////////////////
                    BATCH METHODS
    //////////////////////////////////////////////////////////////*/

    function test_getPricePerShareMultiple() public {
        vault.setAssetsPerShare(863_399);

        address[] memory vaults = new address[](1);
        vaults[0] = vaultAddr;

        uint256[] memory prices = oracle.getPricePerShareMultiple(vaults);
        assertEq(prices.length, 1);
        assertEq(prices[0], 863_399);
    }

    function test_getTVLMultiple() public {
        vault.setTotalSupply(1_000_000e6);

        address[] memory vaults = new address[](1);
        vaults[0] = vaultAddr;

        uint256[] memory tvls = oracle.getTVLMultiple(vaults);
        assertEq(tvls.length, 1);
        assertEq(tvls[0], 1_000_000e6);
    }
}
