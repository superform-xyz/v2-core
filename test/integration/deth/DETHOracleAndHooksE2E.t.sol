// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test, console2 } from "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { DETHYieldSourceOracle } from "../../../src/accounting/oracles/DETHYieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { IMachine } from "../../../src/vendor/vaults/deth/IMachine.sol";
import { IDETHAsyncRedeemer } from "../../../src/vendor/vaults/deth/IDETHAsyncRedeemer.sol";

import { RequestRedeemDETHHook } from "../../../src/hooks/vaults/deth/RequestRedeemDETHHook.sol";
import { ApproveAndRequestRedeemDETHHook } from
    "../../../src/hooks/vaults/deth/ApproveAndRequestRedeemDETHHook.sol";
import { ClaimAssetsDETHHook } from "../../../src/hooks/vaults/deth/ClaimAssetsDETHHook.sol";

/// @dev Minimal interface for AsyncRedeemer admin operations
interface IAsyncRedeemerAdmin {
    function setWhitelistedUsers(address[] calldata users, bool whitelisted) external;
    function isWhitelistedUser(address user) external view returns (bool);
    function nextRequestId() external view returns (uint256);
    function lastFinalizedRequestId() external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function getShares(uint256 requestId) external view returns (uint256);
}

/// @dev Minimal interface for SuperVaultAggregator PPS operations
interface ISuperVaultAggregatorMinimal {
    struct ForwardPPSArgs {
        address[] strategies;
        uint256[] ppss;
        uint256[] timestamps;
        address updateAuthority;
    }

    function forwardPPS(ForwardPPSArgs calldata args) external;
    function getPPS(address strategy) external view returns (uint256);
}

/// @title DETHOracleAndHooksE2E
/// @notice End-to-end integration test combining the DETHYieldSourceOracle with DETH async redeemer hooks.
///         Forks Ethereum mainnet, simulates a SuperVault strategy holding DETH, and verifies oracle TVL
///         tracking throughout the full lifecycle: hold → requestRedeem → pending TVL → claim → final TVL.
/// @dev Run with: forge test --match-contract DETHOracleAndHooksE2E --fork-url $ETHEREUM_RPC_URL -vvv
contract DETHOracleAndHooksE2E is Test {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev DETH share token (18 decimals)
    address public constant DETH = 0x871aB8E36CaE9AF35c6A3488B049965233DeB7ed;

    /// @dev Machine vault (modified ERC-4626)
    address public constant MACHINE = 0x0447D0aD7FD6a3409B48Ecbb9DDB075C1e11D735;

    /// @dev AsyncRedeemer (BeaconProxy)
    address public constant ASYNC_REDEEMER = 0xE44b62dD3F6379D6d14c38081fe1499D1a56250F;

    /// @dev WETH (accounting token)
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// @dev Risk manager — can call setWhitelistedUsers on AsyncRedeemer
    address public constant RISK_MANAGER = 0x36BA7c92Cd68051fB304Bd4580C4A51c1d376532;

    /// @dev Flagship WETH SuperVault on Ethereum mainnet
    address public constant SUPER_WETH_VAULT = 0xa036823b9A24F63c32553367bf181Ee04229c3AC;

    /// @dev SuperWETH strategy (investor account for DETH exposure)
    address public constant SUPER_WETH_STRATEGY = 0x1199a6B2587Ed96446E76Dee3FB660bb8fCfd0b2;

    /// @dev FOUNDATION address for routing DETH redemptions (receives ERC-721 NFTs on behalf of strategy)
    address public constant ROUTER = 0x97b5e4a707A4D5AB4A58b2c93bc8d249a63Ff153;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    DETHYieldSourceOracle public oracle;
    RequestRedeemDETHHook public requestRedeemHook;
    ApproveAndRequestRedeemDETHHook public approveAndRequestHook;
    ClaimAssetsDETHHook public claimHook;

    bytes32 public yieldSourceOracleId;

    /// @dev The real SuperWETH strategy, funded with DETH for testing
    address public strategy;

    /// @dev ERC-7201 storage slot for lastFinalizedRequestId in AsyncRedeemer
    bytes32 internal constant LAST_FINALIZED_SLOT =
        0x187c268ec5d498b5b6e4945b27f62abf37217cdbd80e6429181b3e4c2c378901;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));

        // Deploy oracle (dynamic — no asyncRedeemer constructor param)
        SuperLedgerConfiguration ledgerConfig = new SuperLedgerConfiguration();
        oracle = new DETHYieldSourceOracle(address(ledgerConfig), ROUTER);

        // Deploy hooks
        requestRedeemHook = new RequestRedeemDETHHook();
        approveAndRequestHook = new ApproveAndRequestRedeemDETHHook();
        claimHook = new ClaimAssetsDETHHook();

        yieldSourceOracleId = bytes32(keccak256("DETH_ORACLE_ID"));

        // Use the real SuperWETH strategy as the DETH investor
        // Strategy doesn't currently hold DETH on mainnet (it holds WETH),
        // so we deal DETH to simulate post-deposit state (after executing hooks to deposit WETH into Machine)
        strategy = SUPER_WETH_STRATEGY;
        _whitelistAccount(strategy);
        deal(DETH, strategy, 100 ether);

        // The strategy is a minimal proxy that doesn't implement IERC721Receiver.
        // Mock onERC721Received so AsyncRedeemer can _safeMint NFTs to it during requestRedeem.
        vm.mockCall(
            strategy,
            abi.encodeWithSelector(bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))),
            abi.encode(bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")))
        );
    }

    /*//////////////////////////////////////////////////////////////
                          ORACLE SANITY CHECKS
    //////////////////////////////////////////////////////////////*/

    /// @notice Oracle decimals matches DETH token decimals (18)
    function test_oracle_decimals() public view {
        assertEq(oracle.decimals(ASYNC_REDEEMER), 18, "Oracle decimals should be 18");
    }

    /// @notice Oracle PPS exactly matches Machine.convertToAssets(1e18)
    function test_oracle_ppsMatchesMachine() public view {
        uint256 oraclePPS = oracle.getPricePerShare(ASYNC_REDEEMER);
        uint256 machinePPS = IMachine(MACHINE).convertToAssets(1e18);

        assertEq(oraclePPS, machinePPS, "Oracle PPS must exactly match Machine PPS");
        assertGt(oraclePPS, 0.9e18, "PPS sanity: should be > 0.9 WETH/DETH");
        assertLt(oraclePPS, 2e18, "PPS sanity: should be < 2.0 WETH/DETH");

        console2.log("Oracle PPS:", oraclePPS);
    }

    /// @notice Oracle TVL matches Machine.lastTotalAum()
    function test_oracle_tvlMatchesMachine() public view {
        uint256 oracleTVL = oracle.getTVL(ASYNC_REDEEMER);
        uint256 machineAum = IMachine(MACHINE).lastTotalAum();

        assertEq(oracleTVL, machineAum, "Oracle TVL must match Machine lastTotalAum");
        assertGt(oracleTVL, 0, "TVL should be non-zero");

        console2.log("Machine TVL (WETH):", oracleTVL);
    }

    /// @notice Oracle balance matches DETH.balanceOf(strategy)
    function test_oracle_strategyBalanceMatchesDETH() public view {
        uint256 oracleBalance = oracle.getBalanceOfOwner(ASYNC_REDEEMER, strategy);
        uint256 dethBalance = IERC20(DETH).balanceOf(strategy);

        assertEq(oracleBalance, dethBalance, "Oracle balance must match DETH.balanceOf");
        assertEq(oracleBalance, 100 ether, "Strategy should have 100 DETH");
    }

    /// @notice Strategy TVL with only held shares (no pending redemptions)
    function test_oracle_strategyTVLByOwner_heldSharesOnly() public view {
        uint256 tvl = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);
        // Use Machine.convertToAssets directly (not mulDiv with PPS) to match oracle internals
        uint256 expectedTVL = IMachine(MACHINE).convertToAssets(100 ether);

        assertEq(tvl, expectedTVL, "TVL should equal Machine.convertToAssets(100 DETH)");
        assertGt(tvl, 90 ether, "TVL sanity: 100 DETH should be worth > 90 WETH");
        assertLt(tvl, 200 ether, "TVL sanity: 100 DETH should be worth < 200 WETH");

        console2.log("Strategy TVL (held only, WETH):", tvl);
    }

    /// @notice Zero-address strategy should have zero TVL
    function test_oracle_tvlByOwner_zeroAddress() public view {
        assertEq(oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, address(0)), 0);
    }

    /// @notice Oracle share/asset round-trip matches Machine
    function test_oracle_roundTrip_matchesMachine() public view {
        uint256 oneETH = 1 ether;

        uint256 shares = oracle.getShareOutput(ASYNC_REDEEMER, address(0), oneETH);
        uint256 machineShares = IMachine(MACHINE).convertToShares(oneETH);
        assertEq(shares, machineShares, "getShareOutput must match Machine.convertToShares");

        uint256 assetsBack = oracle.getAssetOutput(ASYNC_REDEEMER, address(0), shares);
        uint256 machineAssetsBack = IMachine(MACHINE).convertToAssets(shares);
        assertEq(assetsBack, machineAssetsBack, "getAssetOutput must match Machine.convertToAssets");

        assertApproxEqAbs(assetsBack, oneETH, 1, "Round-trip should preserve value within 1 wei");
    }

    /*//////////////////////////////////////////////////////////////
              ORACLE + REQUEST REDEEM: PENDING TVL TRACKING
    //////////////////////////////////////////////////////////////*/

    /// @notice After requestRedeem, oracle includes pending value in TVLByOwner
    function test_oracle_tvlByOwner_includesPendingAfterRequestRedeem() public {
        uint256 redeemShares = 30 ether;

        // --- TVL before request ---
        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);
        uint256 expectedTVLBefore = IMachine(MACHINE).convertToAssets(100 ether);
        assertEq(tvlBefore, expectedTVLBefore, "Pre-request TVL should match convertToAssets(100 DETH)");

        // --- Request redeem ---
        vm.startPrank(strategy);
        IERC20(DETH).approve(ASYNC_REDEEMER, redeemShares);
        uint256 requestId = IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(redeemShares, strategy, 0);
        vm.stopPrank();

        // Verify state
        assertEq(IERC20(DETH).balanceOf(strategy), 70 ether, "Strategy should have 70 DETH held");
        assertEq(IAsyncRedeemerAdmin(ASYNC_REDEEMER).ownerOf(requestId), strategy, "NFT should be owned by strategy");

        // --- TVL after request ---
        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);

        // TVL should be approximately the same: 70 held + 30 pending ≈ 100 DETH value
        // Small difference possible due to rounding in batch convertToAssets
        assertApproxEqRel(tvlAfter, tvlBefore, 1e14, "TVL should be ~same after request (held + pending)");

        // Decompose: held value + pending value
        uint256 heldValue = IMachine(MACHINE).convertToAssets(70 ether);
        uint256 pendingShares = IAsyncRedeemerAdmin(ASYNC_REDEEMER).getShares(requestId);
        assertEq(pendingShares, redeemShares, "Pending shares should equal requested amount");

        console2.log("TVL before request:", tvlBefore);
        console2.log("TVL after request: ", tvlAfter);
        console2.log("  held value:      ", heldValue);
        console2.log("  pending shares:  ", pendingShares);
    }

    /// @notice Multiple requests accumulate pending TVL correctly
    function test_oracle_multipleRequests_pendingTVLAccumulates() public {
        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);

        // Make 3 requests
        vm.startPrank(strategy);
        IERC20(DETH).approve(ASYNC_REDEEMER, 60 ether);
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(10 ether, strategy, 0);
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(20 ether, strategy, 0);
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(30 ether, strategy, 0);
        vm.stopPrank();

        // Strategy now has 40 held + 60 pending
        assertEq(IERC20(DETH).balanceOf(strategy), 40 ether, "Should have 40 DETH held");

        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);

        // TVL should stay approximately the same (40 held + 60 pending ≈ 100)
        assertApproxEqRel(tvlAfter, tvlBefore, 1e14, "TVL should be ~same (held + 3 pending requests)");

        console2.log("TVL with 3 pending requests:", tvlAfter);
    }

    /// @notice A different account's pending requests don't affect strategy TVL
    function test_oracle_pendingRequests_filteredByOwner() public {
        address otherAccount = makeAddr("otherAccount");
        _whitelistAccount(otherAccount);
        deal(DETH, otherAccount, 50 ether);

        // Other account creates pending requests
        vm.startPrank(otherAccount);
        IERC20(DETH).approve(ASYNC_REDEEMER, 50 ether);
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(50 ether, otherAccount, 0);
        vm.stopPrank();

        // Strategy TVL should be unaffected (only counts strategy-owned NFTs)
        uint256 strategyTVL = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);
        uint256 expectedTVL = IMachine(MACHINE).convertToAssets(100 ether);

        assertEq(strategyTVL, expectedTVL, "Strategy TVL should not include otherAccount's pending requests");
    }

    /*//////////////////////////////////////////////////////////////
              FULL E2E: HOOKS + ORACLE LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    /// @notice Full lifecycle: hold → request (hook) → verify pending TVL → simulated claim (hook) → final TVL
    function test_e2e_fullLifecycle_oracleTracksTVLThroughout() public {
        uint256 redeemShares = 40 ether;

        // ========== Phase 0: Initial state ==========
        uint256 tvl0 = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);
        uint256 balance0 = oracle.getBalanceOfOwner(ASYNC_REDEEMER, strategy);
        assertEq(balance0, 100 ether, "Phase 0: strategy holds 100 DETH");
        assertGt(tvl0, 0, "Phase 0: TVL is non-zero");

        console2.log("=== Phase 0: Initial ===");
        console2.log("  DETH balance:", balance0);
        console2.log("  TVL (WETH):  ", tvl0);

        // ========== Phase 1: Request redeem via ApproveAndRequestRedeemDETHHook ==========
        bytes memory requestData =
            _encodeApproveAndRequestData(ASYNC_REDEEMER, DETH, redeemShares, 0, false);

        vm.prank(strategy);
        approveAndRequestHook.preExecute(address(0), strategy, requestData);

        vm.startPrank(strategy);
        IERC20(DETH).approve(ASYNC_REDEEMER, 0);
        IERC20(DETH).approve(ASYNC_REDEEMER, redeemShares);
        uint256 requestId = IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(redeemShares, strategy, 0);
        IERC20(DETH).approve(ASYNC_REDEEMER, 0);
        approveAndRequestHook.postExecute(address(0), strategy, requestData);
        vm.stopPrank();

        // Verify hook tracking
        assertEq(
            approveAndRequestHook.getOutAmount(strategy), redeemShares, "Phase 1: hook tracked 40 DETH transferred"
        );
        assertEq(IERC20(DETH).allowance(strategy, ASYNC_REDEEMER), 0, "Phase 1: allowance cleaned up");

        // ========== Phase 2: Verify oracle sees held + pending ==========
        uint256 tvl1 = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);
        uint256 balance1 = oracle.getBalanceOfOwner(ASYNC_REDEEMER, strategy);

        assertEq(balance1, 60 ether, "Phase 2: strategy holds 60 DETH");
        // TVL should be approximately the same (60 held + 40 pending)
        assertApproxEqRel(tvl1, tvl0, 1e14, "Phase 2: TVL preserved (held + pending)");

        console2.log("=== Phase 2: After request ===");
        console2.log("  DETH balance:", balance1);
        console2.log("  TVL (WETH):  ", tvl1);
        console2.log("  requestId:   ", requestId);

        // ========== Phase 3: Simulate finalization + claim via ClaimAssetsDETHHook ==========
        // On-chain finalization requires Dialectic keeper + Aave interaction.
        // We simulate by dealing WETH to the strategy (same pattern as existing E2E).
        uint256 expectedWeth = IMachine(MACHINE).convertToAssets(redeemShares);

        bytes memory claimData = _encodeClaimData(ASYNC_REDEEMER, requestId, false);

        vm.prank(strategy);
        claimHook.preExecute(address(0), strategy, claimData);
        assertEq(claimHook.asset(), WETH, "Phase 3: claim hook discovered WETH");
        assertEq(claimHook.spToken(), DETH, "Phase 3: claim hook discovered DETH");

        // Simulate WETH arriving from finalized claim
        uint256 wethBefore = IERC20(WETH).balanceOf(strategy);
        deal(WETH, strategy, wethBefore + expectedWeth);

        // Simulate NFT burn (the real claimAssets burns the NFT)
        // We can't call claimAssets without real finalization, so we mock the NFT removal
        // by dealing the strategy's DETH to zero out the pending request effect.
        // Instead, we just verify the hook's WETH tracking works with the deal.

        vm.prank(strategy);
        claimHook.postExecute(address(0), strategy, claimData);

        assertEq(claimHook.getOutAmount(strategy), expectedWeth, "Phase 3: outAmount = WETH delta");

        console2.log("=== Phase 3: After simulated claim ===");
        console2.log("  WETH received:", expectedWeth);
        console2.log("  DETH balance: ", IERC20(DETH).balanceOf(strategy));
        console2.log("  WETH balance: ", IERC20(WETH).balanceOf(strategy));

        // ========== Phase 4: Final oracle state ==========
        // Strategy still holds 60 DETH (the pending 40 was "claimed" as WETH)
        uint256 tvl2 = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);
        uint256 balance2 = oracle.getBalanceOfOwner(ASYNC_REDEEMER, strategy);

        assertEq(balance2, 60 ether, "Phase 4: strategy still holds 60 DETH");
        // TVL should now be ~60 DETH worth of WETH (pending request still exists as NFT
        // since we simulated the claim, the NFT is still there in this simulation)
        uint256 heldValue = IMachine(MACHINE).convertToAssets(60 ether);
        assertGe(tvl2, heldValue, "Phase 4: TVL >= held DETH value");

        console2.log("=== Phase 4: Final state ===");
        console2.log("  DETH balance:", balance2);
        console2.log("  TVL (WETH):  ", tvl2);
    }

    /// @notice Full E2E with real claimAssets on a finalized request + oracle verification
    /// @dev Creates a fresh request and force-finalizes it. The oracle does NOT count finalized
    ///      requests in pending range. This test verifies the hook tracks WETH correctly
    ///      and the oracle state is consistent before and after claim.
    function test_e2e_realClaim_oracleTracksWETHDelta() public {
        // Create a finalized request for a separate account
        address claimAccount = makeAddr("oracleClaimAccount");
        uint256 claimShares = 1 ether;
        (uint256 requestId, address nftOwner) = _createFinalizedRequest(claimAccount, claimShares);

        // Get the nftOwner's DETH balance
        uint256 dethBalance = IERC20(DETH).balanceOf(nftOwner);
        uint256 lastFinalized = IAsyncRedeemerAdmin(ASYNC_REDEEMER).lastFinalizedRequestId();

        // Request is finalized (requestId <= lastFinalizedRequestId), so oracle won't scan it
        // Oracle TVL = held DETH value only (pending scan range starts at lastFinalized+1)
        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, nftOwner);
        uint256 expectedTVL = dethBalance > 0 ? IMachine(MACHINE).convertToAssets(dethBalance) : 0;
        assertEq(tvlBefore, expectedTVL, "TVL should reflect held DETH only (request is finalized)");

        console2.log("=== Before real claim ===");
        console2.log("  nftOwner:", nftOwner);
        console2.log("  DETH held:", dethBalance);
        console2.log("  lastFinalizedRequestId:", lastFinalized);
        console2.log("  TVL:", tvlBefore);

        // Execute real claim via hook
        bytes memory claimData = _encodeClaimData(ASYNC_REDEEMER, requestId, false);

        vm.prank(nftOwner);
        claimHook.preExecute(address(0), nftOwner, claimData);

        vm.prank(nftOwner);
        uint256 assetsReceived = IDETHAsyncRedeemer(ASYNC_REDEEMER).claimAssets(requestId);

        vm.prank(nftOwner);
        claimHook.postExecute(address(0), nftOwner, claimData);

        // Verify hook tracking
        assertGt(assetsReceived, 0, "Must receive WETH from real claim");
        assertEq(claimHook.getOutAmount(nftOwner), assetsReceived, "Hook outAmount matches real claim");
        assertEq(claimHook.usedShares(), 0, "Claim hook should NOT set usedShares");

        // Oracle TVL after claim: unchanged (finalized request wasn't in pending scan anyway)
        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, nftOwner);
        assertEq(tvlAfter, tvlBefore, "TVL unchanged (finalized request not in pending scan)");

        // Verify NFT burned
        vm.expectRevert();
        IAsyncRedeemerAdmin(ASYNC_REDEEMER).ownerOf(requestId);

        console2.log("=== After real claim ===");
        console2.log("  WETH received:", assetsReceived);
        console2.log("  TVL after:", tvlAfter);
    }

    /// @notice E2E with RequestRedeemDETHHook variant + oracle tracking
    function test_e2e_requestRedeemHook_oracleTracking() public {
        uint256 redeemShares = 25 ether;

        // Pre-request oracle state
        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);

        // Execute via RequestRedeemDETHHook (requires prior approval)
        vm.prank(strategy);
        IERC20(DETH).approve(ASYNC_REDEEMER, redeemShares);

        bytes memory data = _encodeRequestRedeemData(ASYNC_REDEEMER, redeemShares, 0, false);

        vm.prank(strategy);
        requestRedeemHook.preExecute(address(0), strategy, data);

        vm.startPrank(strategy);
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(redeemShares, strategy, 0);
        requestRedeemHook.postExecute(address(0), strategy, data);
        vm.stopPrank();

        // Hook tracking
        assertEq(requestRedeemHook.usedShares(), redeemShares, "Hook usedShares = redeemed amount");
        assertEq(requestRedeemHook.spToken(), DETH, "Hook cached spToken = DETH");

        // Oracle: TVL preserved (75 held + 25 pending)
        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);
        assertApproxEqRel(tvlAfter, tvlBefore, 1e14, "TVL preserved after request (held + pending)");

        // Oracle: balance decreased
        assertEq(oracle.getBalanceOfOwner(ASYNC_REDEEMER, strategy), 75 ether, "Balance should be 75 DETH");
    }

    /// @notice Verify getWithdrawalShareOutput rounds up correctly (ceil rounding favors protocol)
    function test_oracle_withdrawalShareOutput_ceilRounding() public view {
        uint256 oneETH = 1 ether;

        uint256 sharesNeeded = oracle.getWithdrawalShareOutput(ASYNC_REDEEMER, address(0), oneETH);
        uint256 assetsRecovered = oracle.getAssetOutput(ASYNC_REDEEMER, address(0), sharesNeeded);

        // Ceil rounding means sharesNeeded * PPS >= assetsIn (favors protocol)
        assertGe(assetsRecovered, oneETH, "Ceil rounding: recovered assets >= requested assets");

        console2.log("Withdrawal shares for 1 WETH:", sharesNeeded);
        console2.log("Assets recovered:", assetsRecovered);
    }

    /// @notice Oracle conversion methods are consistent: getShareOutput → getAssetOutput ≈ identity
    function test_oracle_conversionConsistency() public view {
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 0.001 ether;
        amounts[1] = 1 ether;
        amounts[2] = 100 ether;
        amounts[3] = 10_000 ether;

        for (uint256 i = 0; i < amounts.length; i++) {
            uint256 shares = oracle.getShareOutput(ASYNC_REDEEMER, address(0), amounts[i]);
            uint256 assetsBack = oracle.getAssetOutput(ASYNC_REDEEMER, address(0), shares);
            assertApproxEqAbs(assetsBack, amounts[i], 1, "Round-trip off by > 1 wei");
        }
    }

    /*//////////////////////////////////////////////////////////////
          E2E: STRATEGY REBALANCE SCENARIO
    //////////////////////////////////////////////////////////////*/

    /// @notice Simulates a strategy rebalancing: partial redeem + oracle TVL check at every step
    function test_e2e_strategyRebalance_partialRedeem() public {
        // Step 1: Strategy holds 100 DETH
        uint256 tvl = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);
        assertEq(oracle.getBalanceOfOwner(ASYNC_REDEEMER, strategy), 100 ether);

        // Step 2: Redeem 20% (20 DETH) via approve+request hook
        uint256 redeemAmount = 20 ether;
        bytes memory requestData =
            _encodeApproveAndRequestData(ASYNC_REDEEMER, DETH, redeemAmount, 0, false);

        vm.prank(strategy);
        approveAndRequestHook.preExecute(address(0), strategy, requestData);

        vm.startPrank(strategy);
        IERC20(DETH).approve(ASYNC_REDEEMER, 0);
        IERC20(DETH).approve(ASYNC_REDEEMER, redeemAmount);
        uint256 requestId = IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(redeemAmount, strategy, 0);
        IERC20(DETH).approve(ASYNC_REDEEMER, 0);
        approveAndRequestHook.postExecute(address(0), strategy, requestData);
        vm.stopPrank();

        // Step 3: Verify 80% held + 20% pending
        assertEq(oracle.getBalanceOfOwner(ASYNC_REDEEMER, strategy), 80 ether, "Should hold 80 DETH");
        uint256 tvlAfterRedeem = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);
        assertApproxEqRel(tvlAfterRedeem, tvl, 1e14, "TVL preserved after partial redeem");

        // Step 4: Simulate second rebalance — redeem another 30%
        uint256 redeemAmount2 = 30 ether;
        vm.startPrank(strategy);
        IERC20(DETH).approve(ASYNC_REDEEMER, redeemAmount2);
        uint256 requestId2 = IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(redeemAmount2, strategy, 0);
        vm.stopPrank();

        // Step 5: 50% held + 50% pending (2 requests)
        assertEq(oracle.getBalanceOfOwner(ASYNC_REDEEMER, strategy), 50 ether, "Should hold 50 DETH");
        uint256 tvlAfterSecondRedeem = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);
        assertApproxEqRel(tvlAfterSecondRedeem, tvl, 1e14, "TVL preserved after second redeem");

        console2.log("=== Strategy Rebalance ===");
        console2.log("Initial TVL:       ", tvl);
        console2.log("After 20% redeem:  ", tvlAfterRedeem);
        console2.log("After 50% redeem:  ", tvlAfterSecondRedeem);
        console2.log("Held DETH:          50 ether");
        console2.log("Pending request 1: ", requestId);
        console2.log("Pending request 2: ", requestId2);
    }

    /*//////////////////////////////////////////////////////////////
          E2E: ROUTED REDEEM VIA INTERMEDIATE ADDRESS
    //////////////////////////////////////////////////////////////*/

    /// @notice Full lifecycle routing DETH through FOUNDATION address that supports ERC-721.
    ///         Strategy → transfer DETH to ROUTER → ROUTER requestRedeem → claim → transfer WETH back to strategy.
    ///         This bypasses the missing onERC721Received on SuperVaultStrategy.
    function test_e2e_routedRedeem_viaSafeAddress() public {
        uint256 redeemShares = 50 ether;

        // ========== Phase 0: Initial state ==========
        uint256 tvl0 = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);
        uint256 balance0 = IERC20(DETH).balanceOf(strategy);
        uint256 wethBefore = IERC20(WETH).balanceOf(strategy);
        assertEq(balance0, 100 ether, "Phase 0: strategy holds 100 DETH");

        console2.log("=== Phase 0: Initial ===");
        console2.log("  Strategy DETH:", balance0);
        console2.log("  Strategy TVL: ", tvl0);

        // ========== Phase 1: Transfer DETH from strategy to ROUTER ==========
        vm.prank(strategy);
        IERC20(DETH).transfer(ROUTER, redeemShares);

        assertEq(IERC20(DETH).balanceOf(strategy), 50 ether, "Phase 1: strategy has 50 DETH");
        assertEq(IERC20(DETH).balanceOf(ROUTER), redeemShares, "Phase 1: router has 50 DETH");

        console2.log("=== Phase 1: After transfer to ROUTER ===");
        console2.log("  Strategy DETH:", IERC20(DETH).balanceOf(strategy));
        console2.log("  Router DETH:  ", IERC20(DETH).balanceOf(ROUTER));

        // ========== Phase 2: ROUTER requests redeem (no onERC721Received issue) ==========
        _whitelistAccount(ROUTER);

        vm.startPrank(ROUTER);
        IERC20(DETH).approve(ASYNC_REDEEMER, redeemShares);
        uint256 requestId = IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(redeemShares, ROUTER, 0);
        vm.stopPrank();

        // Verify NFT is owned by ROUTER
        assertEq(IAsyncRedeemerAdmin(ASYNC_REDEEMER).ownerOf(requestId), ROUTER, "Phase 2: NFT owned by ROUTER");
        assertEq(IERC20(DETH).balanceOf(ROUTER), 0, "Phase 2: router DETH consumed by requestRedeem");

        // KEY ASSERTION: Oracle TVL preserved — FOUNDATION's pending NFTs count toward strategy TVL
        uint256 tvlAfterRequest = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);
        assertApproxEqRel(tvlAfterRequest, tvl0, 1e14, "Phase 2: TVL preserved (held + FOUNDATION pending)");

        console2.log("=== Phase 2: After requestRedeem from ROUTER ===");
        console2.log("  Request ID:   ", requestId);
        console2.log("  Router DETH:  ", IERC20(DETH).balanceOf(ROUTER));
        console2.log("  Strategy TVL: ", tvlAfterRequest);

        // ========== Phase 3: Simulate finalization + ROUTER claims WETH ==========
        uint256 expectedWeth = IMachine(MACHINE).convertToAssets(redeemShares);

        // Simulate finalization: advance lastFinalizedRequestId past our request
        // so the oracle's pending scan no longer includes it
        vm.mockCall(
            ASYNC_REDEEMER,
            abi.encodeWithSelector(IDETHAsyncRedeemer.lastFinalizedRequestId.selector),
            abi.encode(requestId)
        );

        // Simulate WETH arriving from finalized claim (real finalization requires Dialectic keeper)
        deal(WETH, ROUTER, expectedWeth);

        console2.log("=== Phase 3: After simulated claim ===");
        console2.log("  Router WETH:  ", IERC20(WETH).balanceOf(ROUTER));

        // ========== Phase 4: Transfer WETH back from ROUTER to strategy ==========
        vm.prank(ROUTER);
        IERC20(WETH).transfer(strategy, expectedWeth);

        assertEq(IERC20(WETH).balanceOf(ROUTER), 0, "Phase 4: router WETH fully returned");
        assertEq(
            IERC20(WETH).balanceOf(strategy), wethBefore + expectedWeth, "Phase 4: strategy received WETH"
        );

        // ========== Phase 5: Verify final state ==========
        // Strategy now has: 50 DETH held + expectedWeth WETH
        uint256 finalDETH = IERC20(DETH).balanceOf(strategy);
        uint256 finalWETH = IERC20(WETH).balanceOf(strategy);

        assertEq(finalDETH, 50 ether, "Phase 5: strategy still holds 50 DETH");
        assertEq(finalWETH, wethBefore + expectedWeth, "Phase 5: strategy received WETH from routed redeem");

        // Oracle TVL for remaining DETH position
        uint256 tvlFinal = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);
        uint256 expectedHeldTVL = IMachine(MACHINE).convertToAssets(50 ether);
        assertEq(tvlFinal, expectedHeldTVL, "Phase 5: oracle TVL reflects only remaining 50 DETH");

        console2.log("=== Phase 5: Final state ===");
        console2.log("  Strategy DETH:", finalDETH);
        console2.log("  Strategy WETH:", finalWETH);
        console2.log("  Strategy TVL: ", tvlFinal);
        console2.log("  Value preserved (WETH from redeem + DETH TVL):", finalWETH + tvlFinal);
        console2.log("  Original TVL:  ", tvl0);
    }

    /*//////////////////////////////////////////////////////////////
          E2E: SUPERWETH PPS STABILITY THROUGH DETH REDEEM FLOW
    //////////////////////////////////////////////////////////////*/

    /// @dev SuperVault aggregator (stores strategy PPS)
    ISuperVaultAggregatorMinimal public constant AGGREGATOR =
        ISuperVaultAggregatorMinimal(0x10AC0b33e1C4501CF3ec1cB1AE51ebfdbd2d4698);

    /// @dev Active PPS oracle (authorized to call forwardPPS)
    address public constant PPS_ORACLE = 0x366d88F03B8EF34eb49F32a927ff6e1609F694F2;

    /// @notice Simulates the full DETH routed redeem flow while monitoring SuperWETH PPS stability.
    ///         Calls updatePPS (forwardPPS) between each operation to reflect the oracle's view.
    ///         With FOUNDATION-aware oracle, PPS should remain stable through the async redeem window.
    function test_e2e_superWETH_pps_stableThrough_routedDETHRedeem() public {
        uint256 redeemShares = 50 ether;

        // ========== Snapshot: SuperWETH PPS before anything ==========
        uint256 ppsBefore = _getSuperWETHPPS();
        uint256 oracleTVLBefore = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);

        console2.log("=== Initial State ===");
        console2.log("  SuperWETH PPS:    ", ppsBefore);
        console2.log("  Oracle TVL:       ", oracleTVLBefore);
        console2.log("  Strategy DETH:    ", IERC20(DETH).balanceOf(strategy));

        // ========== Step 1: Transfer DETH from strategy to ROUTER ==========
        vm.prank(strategy);
        IERC20(DETH).transfer(ROUTER, redeemShares);

        // Oracle TVL: 50 DETH held by strategy + 0 pending (DETH is on ROUTER but not yet in AsyncRedeemer)
        // NOTE: DETH sitting on ROUTER (not yet redeemed) is NOT tracked by the oracle.
        // This is a transient state within a single tx batch — in production, transfer + requestRedeem
        // happen atomically in the same execution batch, so this intermediate state is never observed.
        uint256 tvlAfterTransfer = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);

        console2.log("=== After DETH Transfer to ROUTER ===");
        console2.log("  Oracle TVL:       ", tvlAfterTransfer);
        console2.log("  Strategy DETH:    ", IERC20(DETH).balanceOf(strategy));
        console2.log("  Router DETH:      ", IERC20(DETH).balanceOf(ROUTER));

        // ========== Step 2: ROUTER requests redeem ==========
        _whitelistAccount(ROUTER);

        vm.startPrank(ROUTER);
        IERC20(DETH).approve(ASYNC_REDEEMER, redeemShares);
        uint256 requestId = IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(redeemShares, ROUTER, 0);
        vm.stopPrank();

        // Oracle TVL: 50 DETH held + 50 DETH pending (NFT on ROUTER, counted via FOUNDATION)
        uint256 tvlAfterRequest = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);
        assertApproxEqRel(tvlAfterRequest, oracleTVLBefore, 1e14, "TVL preserved after requestRedeem");

        // Compute PPS the oracle would report, then feed it to the aggregator
        uint256 computedPPS = _computeStrategyPPS(tvlAfterRequest);
        _updatePPS(computedPPS);

        uint256 ppsAfterRequest = _getSuperWETHPPS();
        console2.log("=== After requestRedeem + updatePPS ===");
        console2.log("  Oracle TVL:       ", tvlAfterRequest);
        console2.log("  Computed PPS:     ", computedPPS);
        console2.log("  SuperWETH PPS:    ", ppsAfterRequest);
        console2.log("  PPS delta:        ", _absDiff(ppsAfterRequest, ppsBefore));
        console2.log("  Request ID:       ", requestId);

        // PPS should be stable (within 0.01%)
        assertApproxEqRel(ppsAfterRequest, ppsBefore, 1e14, "SuperWETH PPS stable after requestRedeem");

        // ========== Step 3: Simulate finalization + claim ==========
        uint256 expectedWeth = IMachine(MACHINE).convertToAssets(redeemShares);
        deal(WETH, ROUTER, expectedWeth);

        // After claim, ROUTER has WETH. Oracle TVL for strategy: only 50 DETH held
        // (pending NFT still exists in this simulation, but in production it would be burned)
        uint256 tvlAfterClaim = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);

        uint256 computedPPSAfterClaim = _computeStrategyPPS(tvlAfterClaim);
        _updatePPS(computedPPSAfterClaim);

        uint256 ppsAfterClaim = _getSuperWETHPPS();
        console2.log("=== After simulated claim + updatePPS ===");
        console2.log("  Oracle TVL:       ", tvlAfterClaim);
        console2.log("  Computed PPS:     ", computedPPSAfterClaim);
        console2.log("  SuperWETH PPS:    ", ppsAfterClaim);
        console2.log("  PPS delta:        ", _absDiff(ppsAfterClaim, ppsBefore));

        // ========== Step 4: Transfer WETH back from ROUTER to strategy ==========
        vm.prank(ROUTER);
        IERC20(WETH).transfer(strategy, expectedWeth);

        // Strategy now has 50 DETH + expectedWeth WETH
        // For PPS purposes, the WETH is back in the strategy's balance (totalAssets increases)
        // But SuperVault PPS is driven by storedPPS in aggregator, not direct balance checks.
        // The off-chain oracle would see the WETH balance + DETH TVL and compute accordingly.

        console2.log("=== After WETH returned to strategy ===");
        console2.log("  Strategy DETH:    ", IERC20(DETH).balanceOf(strategy));
        console2.log("  Strategy WETH:    ", IERC20(WETH).balanceOf(strategy));
        console2.log("  Oracle TVL (DETH):", oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy));

        // ========== Summary ==========
        console2.log("=== PPS Summary ===");
        console2.log("  PPS before:         ", ppsBefore);
        console2.log("  PPS after request:  ", ppsAfterRequest);
        console2.log("  PPS after claim:    ", ppsAfterClaim);
        console2.log("  Max PPS deviation:  ", _maxDev(ppsBefore, ppsAfterRequest, ppsAfterClaim));
    }

    /*//////////////////////////////////////////////////////////////
          FOUNDATION ORACLE: TVL ATTRIBUTION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Without FOUNDATION, oracle misses ROUTER's pending NFTs → TVL drops
    function test_foundation_withoutFoundation_tvlDropsAfterRoutedRedeem() public {
        // Deploy oracle with unrelated foundation (not ROUTER) — same as having no effective foundation
        SuperLedgerConfiguration ledgerConfig2 = new SuperLedgerConfiguration();
        DETHYieldSourceOracle oracleNoFoundation = new DETHYieldSourceOracle(address(ledgerConfig2), address(1));

        uint256 tvlBefore = oracleNoFoundation.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);

        // Route 50 DETH through ROUTER
        vm.prank(strategy);
        IERC20(DETH).transfer(ROUTER, 50 ether);

        _whitelistAccount(ROUTER);
        vm.startPrank(ROUTER);
        IERC20(DETH).approve(ASYNC_REDEEMER, 50 ether);
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(50 ether, ROUTER, 0);
        vm.stopPrank();

        // Oracle WITHOUT foundation: only sees 50 DETH held, misses 50 pending on ROUTER
        uint256 tvlAfter = oracleNoFoundation.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);
        uint256 heldOnly = IMachine(MACHINE).convertToAssets(50 ether);
        assertEq(tvlAfter, heldOnly, "No-foundation oracle sees only held DETH");

        // TVL dropped ~50%
        assertApproxEqRel(tvlAfter, tvlBefore / 2, 1e14, "TVL dropped ~50% without foundation");

        // Oracle WITH foundation: sees held + ROUTER's pending
        uint256 tvlWithFoundation = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);
        assertApproxEqRel(tvlWithFoundation, tvlBefore, 1e14, "Foundation oracle preserves TVL");

        console2.log("TVL before:              ", tvlBefore);
        console2.log("TVL without foundation:  ", tvlAfter);
        console2.log("TVL with foundation:     ", tvlWithFoundation);
    }

    /// @notice FOUNDATION oracle counts ROUTER's pending NFTs but not other addresses'
    function test_foundation_onlyCountsRouterPending_notOtherAddresses() public {
        address otherAccount = makeAddr("otherAccount");
        _whitelistAccount(otherAccount);
        deal(DETH, otherAccount, 50 ether);

        // otherAccount creates a pending request
        vm.startPrank(otherAccount);
        IERC20(DETH).approve(ASYNC_REDEEMER, 50 ether);
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(50 ether, otherAccount, 0);
        vm.stopPrank();

        // Strategy TVL should not include otherAccount's pending
        uint256 strategyTVL = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);
        uint256 expectedTVL = IMachine(MACHINE).convertToAssets(100 ether);
        assertEq(strategyTVL, expectedTVL, "Other account's pending should not affect strategy TVL");
    }

    /// @notice FOUNDATION pending + strategy pending both count
    function test_foundation_mixedPending_strategyAndRouterBothCounted() public {
        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);

        // Strategy directly creates a pending request (30 DETH)
        vm.startPrank(strategy);
        IERC20(DETH).approve(ASYNC_REDEEMER, 30 ether);
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(30 ether, strategy, 0);
        vm.stopPrank();

        // Route 20 DETH through ROUTER
        vm.prank(strategy);
        IERC20(DETH).transfer(ROUTER, 20 ether);

        _whitelistAccount(ROUTER);
        vm.startPrank(ROUTER);
        IERC20(DETH).approve(ASYNC_REDEEMER, 20 ether);
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(20 ether, ROUTER, 0);
        vm.stopPrank();

        // Strategy now: 50 DETH held + 30 pending (own NFT) + 20 pending (ROUTER NFT)
        assertEq(IERC20(DETH).balanceOf(strategy), 50 ether, "Strategy holds 50 DETH");

        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);

        // TVL should be preserved: 50 held + 30 strategy-pending + 20 router-pending ≈ 100
        assertApproxEqRel(tvlAfter, tvlBefore, 1e14, "TVL preserved with mixed pending (strategy + router)");

        console2.log("TVL before:  ", tvlBefore);
        console2.log("TVL after:   ", tvlAfter);
        console2.log("  50 held + 30 strategy-pending + 20 router-pending");
    }

    /// @notice Multiple routed requests accumulate correctly
    function test_foundation_multipleRoutedRequests_accumulate() public {
        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);
        _whitelistAccount(ROUTER);

        // Route 3 separate requests through ROUTER
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(strategy);
            IERC20(DETH).transfer(ROUTER, 10 ether);

            vm.startPrank(ROUTER);
            IERC20(DETH).approve(ASYNC_REDEEMER, 10 ether);
            IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(10 ether, ROUTER, 0);
            vm.stopPrank();
        }

        // Strategy: 70 held + 30 pending via ROUTER (3 NFTs)
        assertEq(IERC20(DETH).balanceOf(strategy), 70 ether, "Strategy has 70 DETH");

        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);
        assertApproxEqRel(tvlAfter, tvlBefore, 1e14, "TVL preserved across 3 routed requests");
    }

    /// @notice Querying ROUTER's own TVL doesn't double-count (FOUNDATION is skipped when owner == FOUNDATION)
    function test_foundation_routerOwnTVL_noDoubleCount() public {
        _whitelistAccount(ROUTER);
        deal(DETH, ROUTER, 10 ether);

        // ROUTER creates its own pending request
        vm.startPrank(ROUTER);
        IERC20(DETH).approve(ASYNC_REDEEMER, 10 ether);
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(10 ether, ROUTER, 0);
        vm.stopPrank();

        // Query ROUTER's own TVL — should NOT double-count (oracle skips FOUNDATION scan when owner == FOUNDATION)
        uint256 routerTVL = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, ROUTER);
        uint256 expectedPending = IMachine(MACHINE).convertToAssets(10 ether);

        // ROUTER: 0 DETH held + 10 DETH pending = ~10 DETH value
        assertEq(routerTVL, expectedPending, "ROUTER TVL = pending only, no double-count");
    }

    /// @notice Redeem 100% of DETH through ROUTER — strategy has 0 held, all pending via FOUNDATION
    function test_foundation_fullRedeem_allPendingViaRouter() public {
        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);
        _whitelistAccount(ROUTER);

        // Transfer ALL 100 DETH to ROUTER and redeem
        vm.prank(strategy);
        IERC20(DETH).transfer(ROUTER, 100 ether);

        vm.startPrank(ROUTER);
        IERC20(DETH).approve(ASYNC_REDEEMER, 100 ether);
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(100 ether, ROUTER, 0);
        vm.stopPrank();

        assertEq(IERC20(DETH).balanceOf(strategy), 0, "Strategy has 0 DETH held");
        assertEq(IERC20(DETH).balanceOf(ROUTER), 0, "ROUTER DETH fully consumed");

        // Oracle: 0 held + 100 pending via FOUNDATION
        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);
        assertApproxEqRel(tvlAfter, tvlBefore, 1e14, "TVL preserved when 100% routed through FOUNDATION");

        console2.log("TVL before full redeem:", tvlBefore);
        console2.log("TVL after full redeem: ", tvlAfter);
        console2.log("Strategy DETH held:     0");
    }

    /// @notice FOUNDATION immutable is correctly set
    function test_foundation_immutableIsSet() public view {
        assertEq(oracle.FOUNDATION(), ROUTER, "FOUNDATION should be ROUTER address");
    }

    /// @notice Oracle constructor reverts with FOUNDATION=address(0)
    function test_foundation_zeroAddress_reverts() public {
        SuperLedgerConfiguration ledgerConfig2 = new SuperLedgerConfiguration();
        vm.expectRevert(DETHYieldSourceOracle.ZERO_ADDRESS.selector);
        new DETHYieldSourceOracle(address(ledgerConfig2), address(0));
    }

    /*//////////////////////////////////////////////////////////////
          PPS STABILITY: COMPARISON WITH vs WITHOUT FOUNDATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Side-by-side PPS comparison: with FOUNDATION vs without, after routed redeem
    function test_pps_comparison_withVsWithoutFoundation() public {
        // Deploy oracle with unrelated foundation for comparison (not ROUTER)
        SuperLedgerConfiguration ledgerConfig2 = new SuperLedgerConfiguration();
        DETHYieldSourceOracle oracleNoFoundation = new DETHYieldSourceOracle(address(ledgerConfig2), address(1));

        // Route 50 DETH through ROUTER
        vm.prank(strategy);
        IERC20(DETH).transfer(ROUTER, 50 ether);

        _whitelistAccount(ROUTER);
        vm.startPrank(ROUTER);
        IERC20(DETH).approve(ASYNC_REDEEMER, 50 ether);
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(50 ether, ROUTER, 0);
        vm.stopPrank();

        // With FOUNDATION: TVL preserved
        uint256 tvlWith = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);
        uint256 ppsWithFoundation = _computeStrategyPPS(tvlWith);

        // Without FOUNDATION: TVL drops
        uint256 tvlWithout = oracleNoFoundation.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);
        uint256 storedPPS = AGGREGATOR.getPPS(strategy);
        uint256 initialTVL = IMachine(MACHINE).convertToAssets(100 ether);
        uint256 ppsWithoutFoundation = Math.mulDiv(storedPPS, tvlWithout, initialTVL);

        // With foundation: PPS stable
        assertApproxEqRel(ppsWithFoundation, storedPPS, 1e14, "With foundation: PPS stable");

        // Without foundation: PPS drops ~50%
        assertApproxEqRel(ppsWithoutFoundation, storedPPS / 2, 1e14, "Without foundation: PPS drops ~50%");

        uint256 ppsDropBps = Math.mulDiv(storedPPS - ppsWithoutFoundation, 10_000, storedPPS);

        console2.log("=== PPS Comparison ===");
        console2.log("  Stored PPS:             ", storedPPS);
        console2.log("  PPS with foundation:    ", ppsWithFoundation);
        console2.log("  PPS without foundation: ", ppsWithoutFoundation);
        console2.log("  PPS drop (bps):         ", ppsDropBps);
        console2.log("  TVL with foundation:    ", tvlWith);
        console2.log("  TVL without foundation: ", tvlWithout);
    }

    /// @notice Incremental redeems: PPS stays stable through 10%, 30%, 50%, 80%, 100% routed redemptions
    function test_pps_stableThroughIncrementalRoutedRedeems() public {
        _whitelistAccount(ROUTER);

        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);
        uint256[] memory redeemPcts = new uint256[](5);
        redeemPcts[0] = 10 ether;
        redeemPcts[1] = 20 ether;
        redeemPcts[2] = 20 ether;
        redeemPcts[3] = 30 ether;
        redeemPcts[4] = 20 ether;

        uint256 totalRedeemed;
        for (uint256 i = 0; i < redeemPcts.length; i++) {
            uint256 amount = redeemPcts[i];
            totalRedeemed += amount;

            vm.prank(strategy);
            IERC20(DETH).transfer(ROUTER, amount);

            vm.startPrank(ROUTER);
            IERC20(DETH).approve(ASYNC_REDEEMER, amount);
            IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(amount, ROUTER, 0);
            vm.stopPrank();

            uint256 tvlAfter = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);
            assertApproxEqRel(tvlAfter, tvlBefore, 1e14, "TVL stable at cumulative redeem step");

            console2.log("  Step %d: redeemed %d DETH, TVL: %d", i + 1, totalRedeemed / 1e18, tvlAfter);
        }

        // All 100 DETH redeemed, strategy has 0 held
        assertEq(IERC20(DETH).balanceOf(strategy), 0, "All DETH redeemed");
        uint256 tvlFinal = oracle.getTVLByOwnerOfShares(ASYNC_REDEEMER, strategy);
        assertApproxEqRel(tvlFinal, tvlBefore, 1e14, "TVL stable after 100% incremental redemption");
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    function _whitelistAccount(address _account) internal {
        address[] memory users = new address[](1);
        users[0] = _account;
        vm.prank(RISK_MANAGER);
        IAsyncRedeemerAdmin(ASYNC_REDEEMER).setWhitelistedUsers(users, true);
    }

    /// @dev Gets SuperWETH vault PPS via convertToAssets(1e18)
    function _getSuperWETHPPS() internal view returns (uint256) {
        (bool success, bytes memory data) =
            SUPER_WETH_VAULT.staticcall(abi.encodeWithSignature("convertToAssets(uint256)", 1e18));
        require(success, "convertToAssets failed");
        return abi.decode(data, (uint256));
    }

    /// @dev Computes what strategy PPS the off-chain oracle would report.
    ///      In production, PPS = totalAssetsManaged / totalSharesMinted.
    ///      For simplicity, we use the current stored PPS scaled by the TVL ratio.
    function _computeStrategyPPS(uint256 currentOracleTVL) internal view returns (uint256) {
        uint256 storedPPS = AGGREGATOR.getPPS(strategy);

        // If oracle TVL hasn't changed, PPS stays the same
        uint256 initialTVL = IMachine(MACHINE).convertToAssets(100 ether);
        if (initialTVL == 0) return storedPPS;

        // Scale PPS proportionally to TVL change
        return Math.mulDiv(storedPPS, currentOracleTVL, initialTVL);
    }

    /// @dev Calls forwardPPS on the aggregator, pranking as the active PPS oracle.
    ///      Advances block.timestamp by 31 minutes to satisfy rate limiting.
    function _updatePPS(uint256 newPPS) internal {
        // Advance time to satisfy minUpdateInterval (30 min)
        vm.warp(block.timestamp + 31 minutes);

        address[] memory strategies = new address[](1);
        strategies[0] = strategy;

        uint256[] memory ppss = new uint256[](1);
        ppss[0] = newPPS;

        uint256[] memory timestamps = new uint256[](1);
        timestamps[0] = block.timestamp;

        vm.prank(PPS_ORACLE);
        AGGREGATOR.forwardPPS(
            ISuperVaultAggregatorMinimal.ForwardPPSArgs({
                strategies: strategies,
                ppss: ppss,
                timestamps: timestamps,
                updateAuthority: PPS_ORACLE
            })
        );
    }

    function _absDiff(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    function _maxDev(uint256 base, uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 devA = _absDiff(base, a);
        uint256 devB = _absDiff(base, b);
        return devA > devB ? devA : devB;
    }

    /// @dev Encodes RequestRedeemDETHHook data
    /// Layout: bytes32 oracleId | address asyncRedeemer | uint256 shares | uint256 minAssets | bool usePrevHook
    function _encodeRequestRedeemData(
        address asyncRedeemer,
        uint256 shares,
        uint256 minAssets,
        bool usePrevHook
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, asyncRedeemer, shares, minAssets, usePrevHook);
    }

    /// @dev Encodes ApproveAndRequestRedeemDETHHook data
    /// Layout: bytes32 oracleId | address asyncRedeemer | address dethToken | uint256 shares | uint256 minAssets |
    /// bool usePrevHook
    function _encodeApproveAndRequestData(
        address asyncRedeemer,
        address dethToken,
        uint256 shares,
        uint256 minAssets,
        bool usePrevHook
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, asyncRedeemer, dethToken, shares, minAssets, usePrevHook);
    }

    /// @dev Encodes ClaimAssetsDETHHook data
    /// Layout: bytes32 oracleId | address asyncRedeemer | uint256 requestId | bool usePrevHook
    function _encodeClaimData(
        address asyncRedeemer,
        uint256 requestId,
        bool usePrevHook
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, asyncRedeemer, requestId, usePrevHook);
    }

    /// @dev Creates a real redeem request and force-finalizes it via storage manipulation.
    ///      Returns the request ID and NFT owner (the caller account).
    ///      Deals WETH to AsyncRedeemer so claimAssets can transfer it out.
    function _createFinalizedRequest(
        address caller,
        uint256 shares
    )
        internal
        returns (uint256 requestId, address nftOwner)
    {
        deal(DETH, caller, IERC20(DETH).balanceOf(caller) + shares);
        _whitelistAccount(caller);

        // Mock onERC721Received so AsyncRedeemer can _safeMint NFTs
        vm.mockCall(
            caller,
            abi.encodeWithSelector(bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))),
            abi.encode(bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")))
        );

        vm.startPrank(caller);
        IERC20(DETH).approve(ASYNC_REDEEMER, shares);
        requestId = IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(shares, caller, 0);
        vm.stopPrank();

        // Force-finalize by advancing lastFinalizedRequestId past this request
        vm.store(ASYNC_REDEEMER, LAST_FINALIZED_SLOT, bytes32(requestId));

        // Deal WETH to AsyncRedeemer so claimAssets can pay out
        uint256 expectedAssets = IMachine(MACHINE).convertToAssets(shares);
        deal(WETH, ASYNC_REDEEMER, IERC20(WETH).balanceOf(ASYNC_REDEEMER) + expectedAssets);

        nftOwner = caller;
    }
}
