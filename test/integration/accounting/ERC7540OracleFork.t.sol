// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ERC7540YieldSourceOracle } from "../../../src/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { IERC7540 } from "../../../src/vendor/vaults/7540/IERC7540.sol";

import { ITranche } from "../../mocks/centrifuge/ITranch.sol";
import { IInvestmentManager } from "../../mocks/centrifuge/IInvestmentManager.sol";
import { IPoolManager } from "../../mocks/centrifuge/IPoolManager.sol";
import { RestrictionManagerLike } from "../../mocks/centrifuge/IRestrictionManagerLike.sol";

/// @title ERC7540OracleFork
/// @notice Fork tests for ERC7540YieldSourceOracle against the real Centrifuge USDC vault on
///         Ethereum mainnet (block 21_929_476, PPS = 1.054230 USDC/share).
///
/// @dev Covers all oracle entry points against live on-chain state:
///      - Pricing: getPricePerShare, decimals, getPricePerShareMultiple
///      - Conversions: getShareOutput, getAssetOutput, getWithdrawalShareOutput
///      - TVL: getTVL, getTVLByOwnerOfShares
///      - Breakdown: getAsyncStateBreakdown across all 5 lifecycle components:
///        (1) held shares, (2) pending redeem, (3) claimable redeem, (4) pending deposit,
///        (5) claimable deposit
///
/// @dev Run with: forge test --match-contract ERC7540OracleFork --fork-url $ETHEREUM_RPC_URL -vvv
contract ERC7540OracleFork is Test {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address constant CENTRIFUGE_USDC_VAULT = 0x1d01Ef1997d44206d839b78bA6813f60F1B3A970;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant ROOT_MANAGER = 0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC;
    address constant INVESTMENT_MANAGER = 0xE79f06573d6aF1B66166A926483ba00924285d20;
    address constant POOL_MANAGER = 0x91808B5E2F6d7483D41A681034D7c9DbB64B9E29;

    uint256 constant FORK_BLOCK = 21_929_476;
    uint256 constant EXPECTED_PPS = 1_054_230; // convertToAssets(1e6) at fork block

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    ERC7540YieldSourceOracle public oracle;
    IERC7540 public vault;
    IInvestmentManager public investmentManager;
    IPoolManager public poolManager;

    uint64 public poolId;
    bytes16 public trancheId;
    uint128 public assetId;
    address public user;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"), FORK_BLOCK);

        SuperLedgerConfiguration ledgerConfig = new SuperLedgerConfiguration();
        oracle = new ERC7540YieldSourceOracle(address(ledgerConfig), 0);

        vault = IERC7540(CENTRIFUGE_USDC_VAULT);
        investmentManager = IInvestmentManager(INVESTMENT_MANAGER);
        poolManager = IPoolManager(POOL_MANAGER);

        poolId = vault.poolId();
        trancheId = vault.trancheId();
        assetId = poolManager.assetToId(USDC);

        user = makeAddr("oracle_fork_user");
        _whitelistUser(user);
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 1: PRICING AND CONVERSIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice oracle.getPricePerShare must equal vault.convertToAssets(1e6) at fork block
    function test_fork_pps_matchesVaultDirectCall() public view {
        uint256 oraclePPS = oracle.getPricePerShare(CENTRIFUGE_USDC_VAULT);
        uint256 vaultPPS = vault.convertToAssets(1e6);

        assertEq(oraclePPS, vaultPPS, "oracle PPS must match vault.convertToAssets(1e6)");
        assertEq(oraclePPS, EXPECTED_PPS, "PPS must be 1.054230 USDC at fork block");
    }

    /// @notice PPS must be above 1.0 for an RWA tranche with accrued yield
    function test_fork_pps_greaterThanOneForYieldAccrued() public view {
        uint256 pps = oracle.getPricePerShare(CENTRIFUGE_USDC_VAULT);
        assertGt(pps, 1e6, "PPS must be > 1.0 USDC (yield has accrued on RWA tranche)");
    }

    /// @notice oracle.decimals must match the share token decimals discovered via vault.share()
    function test_fork_decimals_matchesShareToken() public view {
        uint8 oracleDecimals = oracle.decimals(CENTRIFUGE_USDC_VAULT);
        uint8 shareDecimals = ITranche(vault.share()).decimals();

        assertEq(oracleDecimals, shareDecimals, "oracle decimals must match share token");
        assertEq(oracleDecimals, 6, "Centrifuge USDC vault share token is 6-decimal");
    }

    /// @notice oracle.getShareOutput must match vault.convertToShares(assets)
    function test_fork_shareOutput_matchesVault() public view {
        uint256 assetsIn = 1_000_000; // 1 USDC
        uint256 oracleShares = oracle.getShareOutput(CENTRIFUGE_USDC_VAULT, user, assetsIn);
        uint256 vaultShares = vault.convertToShares(assetsIn);

        assertEq(oracleShares, vaultShares, "oracle share output must match vault.convertToShares");
        // 1 USDC / 1.054230 PPS = ~0.9486 shares → less than 1e6
        assertLt(oracleShares, 1e6, "shares < 1 share when PPS > 1 USDC");
        assertGt(oracleShares, 0, "shares must be nonzero for nonzero input");
    }

    /// @notice getAssetOutput(1 share) must equal the PPS
    function test_fork_assetOutput_oneShare_equalsPPS() public view {
        uint256 assets = oracle.getAssetOutput(CENTRIFUGE_USDC_VAULT, user, 1e6);
        assertEq(assets, EXPECTED_PPS, "1 full share must equal PPS in assets");
    }

    /// @notice oracle.getAssetOutput must match vault.convertToAssets for arbitrary amounts
    function test_fork_assetOutput_matchesVault() public view {
        uint256 sharesIn = 500_000; // 0.5 share
        uint256 oracleAssets = oracle.getAssetOutput(CENTRIFUGE_USDC_VAULT, user, sharesIn);
        uint256 vaultAssets = vault.convertToAssets(sharesIn);

        assertEq(oracleAssets, vaultAssets, "oracle asset output must match vault.convertToAssets");
    }

    /// @notice getWithdrawalShareOutput ceil rounding: sharesNeeded covers exactly the requested assets
    function test_fork_withdrawalShareOutput_ceilRounding() public view {
        uint256 assetsIn = 1_000_000; // 1 USDC
        uint256 sharesNeeded = oracle.getWithdrawalShareOutput(CENTRIFUGE_USDC_VAULT, user, assetsIn);
        uint256 assetsBack = oracle.getAssetOutput(CENTRIFUGE_USDC_VAULT, user, sharesNeeded);

        assertGe(assetsBack, assetsIn, "ceil rounding: sharesNeeded must cover requested assets");
        assertLe(assetsBack - assetsIn, 1, "ceil rounding must add at most 1 wei");
    }

    /// @notice getPricePerShareMultiple must be consistent with single getPricePerShare
    function test_fork_getPricePerShareMultiple_consistency() public view {
        address[] memory vaults = new address[](1);
        vaults[0] = CENTRIFUGE_USDC_VAULT;

        uint256[] memory prices = oracle.getPricePerShareMultiple(vaults);

        assertEq(prices.length, 1);
        assertEq(prices[0], oracle.getPricePerShare(CENTRIFUGE_USDC_VAULT), "batch must match single");
        assertEq(prices[0], EXPECTED_PPS);
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 2: VAULT-WIDE TVL
    //////////////////////////////////////////////////////////////*/

    /// @notice getTVL must equal vault.totalAssets() at the fork block
    function test_fork_tvl_matchesVaultTotalAssets() public view {
        uint256 oracleTVL = oracle.getTVL(CENTRIFUGE_USDC_VAULT);
        uint256 vaultTVL = vault.totalAssets();

        assertEq(oracleTVL, vaultTVL, "oracle TVL must match vault.totalAssets()");
        assertGt(oracleTVL, 0, "TVL must be nonzero at fork block");
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 3: BALANCE OF OWNER
    //////////////////////////////////////////////////////////////*/

    /// @notice getBalanceOfOwner must equal share token balanceOf after a deposit
    function test_fork_balanceOfOwner_matchesShareToken() public {
        uint256 depositAmount = 100e6; // 100 USDC
        _fullDepositFlow(depositAmount);

        uint256 oracleBalance = oracle.getBalanceOfOwner(CENTRIFUGE_USDC_VAULT, user);
        uint256 directBalance = IERC20(vault.share()).balanceOf(user);

        assertEq(oracleBalance, directBalance, "oracle balance must match share token balanceOf");
        assertGt(oracleBalance, 0, "user must hold shares after deposit");
    }

    /// @notice getBalanceOfOwner returns 0 for an address with no shares
    function test_fork_balanceOfOwner_zeroForNoHolder() public {
        address noHolder = makeAddr("no_holder");
        assertEq(oracle.getBalanceOfOwner(CENTRIFUGE_USDC_VAULT, noHolder), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 4: ASYNC STATE BREAKDOWN
    //////////////////////////////////////////////////////////////*/

    /// @notice All 5 components are 0 for a user with no position
    function test_fork_breakdown_zeroForEmptyUser() public {
        address emptyUser = makeAddr("empty_user");

        (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            uint256 claimableRedeemValue,
            uint256 pendingDepositValue,
            uint256 claimableDepositValue
        ) = oracle.getAsyncStateBreakdown(CENTRIFUGE_USDC_VAULT, emptyUser);

        assertEq(heldValue, 0);
        assertEq(pendingRedeemValue, 0);
        assertEq(claimableRedeemValue, 0);
        assertEq(pendingDepositValue, 0);
        assertEq(claimableDepositValue, 0);
    }

    /// @notice Component 1: heldValue equals convertToAssets(balanceOf(user)) after deposit
    function test_fork_breakdown_component1_heldShares() public {
        uint256 depositAmount = 100e6; // 100 USDC
        _fullDepositFlow(depositAmount);

        uint256 userShares = IERC20(vault.share()).balanceOf(user);
        assertGt(userShares, 0, "user must have shares after deposit");

        (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            uint256 claimableRedeemValue,
            uint256 pendingDepositValue,
            uint256 claimableDepositValue
        ) = oracle.getAsyncStateBreakdown(CENTRIFUGE_USDC_VAULT, user);

        assertEq(heldValue, vault.convertToAssets(userShares), "held value = convertToAssets(shares)");
        assertEq(pendingRedeemValue, 0);
        assertEq(claimableRedeemValue, 0);
        assertEq(pendingDepositValue, 0);
        assertLe(claimableDepositValue, 1, "at most 1 asset dust remaining from rounding in deposit claim");
    }

    /// @notice Component 2: pendingRedeemValue is valued at current PPS after requestRedeem
    function test_fork_breakdown_component2_pendingRedeem() public {
        uint256 depositAmount = 100e6;
        _fullDepositFlow(depositAmount);

        uint256 userShares = IERC20(vault.share()).balanceOf(user);

        // Transfer shares to the escrow (pending redeem state)
        vm.prank(user);
        vault.requestRedeem(userShares, user, user);

        assertEq(vault.pendingRedeemRequest(0, user), userShares, "all shares in pending redeem");

        (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            uint256 claimableRedeemValue,
            uint256 pendingDepositValue,
            uint256 claimableDepositValue
        ) = oracle.getAsyncStateBreakdown(CENTRIFUGE_USDC_VAULT, user);

        // Shares moved to escrow — no held balance
        assertEq(heldValue, 0, "no held balance: shares in escrow");
        assertEq(
            pendingRedeemValue, vault.convertToAssets(userShares), "pending redeem = convertToAssets(pendingShares)"
        );
        assertEq(claimableRedeemValue, 0, "not yet fulfilled");
        assertEq(pendingDepositValue, 0);
        assertLe(claimableDepositValue, 1, "at most 1 asset dust remaining from rounding in deposit claim");
    }

    /// @notice Component 3: claimableRedeemValue equals maxWithdraw after fulfillRedeemRequest
    function test_fork_breakdown_component3_claimableRedeem() public {
        uint256 depositAmount = 100e6;
        _fullDepositFlow(depositAmount);

        uint256 userShares = IERC20(vault.share()).balanceOf(user);

        vm.prank(user);
        vault.requestRedeem(userShares, user, user);

        // Simulate Centrifuge epoch execution fulfilling the redeem
        uint256 expectedAssets = vault.convertToAssets(userShares);
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillRedeemRequest(
            poolId, trancheId, user, assetId, uint128(expectedAssets), uint128(userShares)
        );

        uint256 maxWithdraw = vault.maxWithdraw(user);
        assertGt(maxWithdraw, 0, "must have claimable assets after fulfill");

        (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            uint256 claimableRedeemValue,
            uint256 pendingDepositValue,
            uint256 claimableDepositValue
        ) = oracle.getAsyncStateBreakdown(CENTRIFUGE_USDC_VAULT, user);

        assertEq(heldValue, 0);
        assertEq(pendingRedeemValue, 0, "no longer pending after fulfill");
        assertEq(claimableRedeemValue, maxWithdraw, "claimable redeem = vault.maxWithdraw(user)");
        assertEq(pendingDepositValue, 0);
        assertLe(claimableDepositValue, 1, "at most 1 asset dust remaining from rounding in deposit claim");
    }

    /// @notice Component 4: pendingDepositValue equals requested assets before epoch execution
    function test_fork_breakdown_component4_pendingDeposit() public {
        uint256 depositAmount = 50e6; // 50 USDC

        deal(USDC, user, depositAmount);
        vm.startPrank(user);
        IERC20(USDC).approve(CENTRIFUGE_USDC_VAULT, depositAmount);
        vault.requestDeposit(depositAmount, user, user);
        vm.stopPrank();

        assertEq(vault.pendingDepositRequest(0, user), depositAmount, "pending deposit = requested assets");

        (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            uint256 claimableRedeemValue,
            uint256 pendingDepositValue,
            uint256 claimableDepositValue
        ) = oracle.getAsyncStateBreakdown(CENTRIFUGE_USDC_VAULT, user);

        assertEq(heldValue, 0, "no shares yet");
        assertEq(pendingRedeemValue, 0);
        assertEq(claimableRedeemValue, 0);
        assertEq(pendingDepositValue, depositAmount, "pending deposit = requestDeposit amount");
        assertEq(claimableDepositValue, 0, "not yet fulfilled");
    }

    /// @notice Component 5: claimableDepositValue equals claimableDepositRequest after epoch execution
    function test_fork_breakdown_component5_claimableDeposit() public {
        uint256 depositAmount = 50e6; // 50 USDC

        deal(USDC, user, depositAmount);
        vm.startPrank(user);
        IERC20(USDC).approve(CENTRIFUGE_USDC_VAULT, depositAmount);
        vault.requestDeposit(depositAmount, user, user);
        vm.stopPrank();

        // Simulate Centrifuge epoch execution — moves assets from pending to claimable
        uint256 expectedShares = vault.convertToShares(depositAmount);
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillDepositRequest(
            poolId, trancheId, user, assetId, uint128(depositAmount), uint128(expectedShares)
        );

        // Do NOT call vault.deposit — leave in claimable state
        uint256 claimableAssets = vault.claimableDepositRequest(0, user);
        assertGt(claimableAssets, 0, "must have claimable deposit after epoch execution");

        (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            uint256 claimableRedeemValue,
            uint256 pendingDepositValue,
            uint256 claimableDepositValue
        ) = oracle.getAsyncStateBreakdown(CENTRIFUGE_USDC_VAULT, user);

        assertEq(heldValue, 0, "shares not yet claimed");
        assertEq(pendingRedeemValue, 0);
        assertEq(claimableRedeemValue, 0);
        assertEq(pendingDepositValue, 0, "no longer pending after epoch execution");
        assertEq(claimableDepositValue, claimableAssets, "claimable deposit = vault.claimableDepositRequest(0, user)");
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 5: TVL BY OWNER (SUM OF COMPONENTS)
    //////////////////////////////////////////////////////////////*/

    /// @notice getTVLByOwnerOfShares is the sum of all 5 breakdown components
    function test_fork_tvlByOwner_sumOfAllComponents() public {
        uint256 depositAmount = 100e6;
        _fullDepositFlow(depositAmount);

        (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            uint256 claimableRedeemValue,
            uint256 pendingDepositValue,
            uint256 claimableDepositValue
        ) = oracle.getAsyncStateBreakdown(CENTRIFUGE_USDC_VAULT, user);

        uint256 tvl = oracle.getTVLByOwnerOfShares(CENTRIFUGE_USDC_VAULT, user);

        assertEq(
            tvl,
            heldValue + pendingRedeemValue + claimableRedeemValue + pendingDepositValue + claimableDepositValue,
            "TVL must be the sum of all 5 breakdown components"
        );
    }

    /// @notice getTVLByOwnerOfShares returns 0 for a user with no position
    function test_fork_tvlByOwner_zeroForEmptyUser() public {
        assertEq(oracle.getTVLByOwnerOfShares(CENTRIFUGE_USDC_VAULT, makeAddr("nobody")), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    SECTION 6: FUZZ
    //////////////////////////////////////////////////////////////*/

    /// @notice PPS consistency holds for any share amount: oracle.getAssetOutput matches vault.convertToAssets
    function testFuzz_fork_assetOutput_matchesVault(uint256 sharesIn) public view {
        sharesIn = bound(sharesIn, 1, 1e9); // 0 to 1000 shares (6-decimal)
        assertEq(
            oracle.getAssetOutput(CENTRIFUGE_USDC_VAULT, user, sharesIn),
            vault.convertToAssets(sharesIn),
            "oracle asset output must always match vault.convertToAssets"
        );
    }

    /// @notice Ceil rounding property holds for any asset amount
    function testFuzz_fork_withdrawalShareOutput_ceilRounding(uint256 assetsIn) public view {
        assetsIn = bound(assetsIn, 1, 1e9); // 0 to 1000 USDC (6-decimal)
        uint256 sharesNeeded = oracle.getWithdrawalShareOutput(CENTRIFUGE_USDC_VAULT, user, assetsIn);
        uint256 assetsBack = oracle.getAssetOutput(CENTRIFUGE_USDC_VAULT, user, sharesNeeded);
        assertGe(assetsBack, assetsIn, "ceil rounding: sharesNeeded must always cover requested assets");
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _whitelistUser(address account) internal {
        address share = vault.share();
        address hook = ITranche(share).hook();
        RestrictionManagerLike restrictionManager = RestrictionManagerLike(hook);
        vm.prank(restrictionManager.root());
        restrictionManager.updateMember(share, account, type(uint64).max);
    }

    /// @dev Fund user → requestDeposit → fulfillDepositRequest → claim shares via deposit
    function _fullDepositFlow(uint256 depositAmount) internal {
        deal(USDC, user, depositAmount);
        vm.startPrank(user);
        IERC20(USDC).approve(CENTRIFUGE_USDC_VAULT, depositAmount);
        vault.requestDeposit(depositAmount, user, user);
        vm.stopPrank();

        uint256 expectedShares = vault.convertToShares(depositAmount);
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillDepositRequest(
            poolId, trancheId, user, assetId, uint128(depositAmount), uint128(expectedShares)
        );

        uint256 maxDeposit = vault.maxDeposit(user);
        vm.prank(user);
        vault.deposit(maxDeposit, user, user);
    }
}
