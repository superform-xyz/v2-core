// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import "forge-std/console2.sol";

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../src/libraries/HookSubTypes.sol";
import { IDETHAsyncRedeemer } from "../../../src/vendor/vaults/deth/IDETHAsyncRedeemer.sol";
import { IMachine } from "../../../src/vendor/vaults/deth/IMachine.sol";

import { RequestRedeemDETHHook } from "../../../src/hooks/vaults/deth/RequestRedeemDETHHook.sol";
import { ApproveAndRequestRedeemDETHHook } from
    "../../../src/hooks/vaults/deth/ApproveAndRequestRedeemDETHHook.sol";
import { ClaimAssetsDETHHook } from "../../../src/hooks/vaults/deth/ClaimAssetsDETHHook.sol";

/// @dev Minimal interface for the AsyncRedeemer admin operations
interface IAsyncRedeemerAdmin {
    function setWhitelistedUsers(address[] calldata users, bool whitelisted) external;
    function isWhitelistedUser(address user) external view returns (bool);
    function isWhitelistEnabled() external view returns (bool);
    function nextRequestId() external view returns (uint256);
    function lastFinalizedRequestId() external view returns (uint256);
    function finalizationDelay() external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
}

/// @dev Minimal interface for reading ERC-20 metadata
interface IERC20Metadata {
    function decimals() external view returns (uint8);
}

/// @title DETHAsyncRedeemerHooksE2E
/// @notice End-to-end integration tests for DETH AsyncRedeemer hooks on Ethereum mainnet fork
/// @dev Uses real DETH, Machine, and AsyncRedeemer contracts on Ethereum mainnet
contract DETHAsyncRedeemerHooksE2E is Test {
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

    /// @dev Risk manager on Machine — can call setWhitelistedUsers on AsyncRedeemer
    address public constant RISK_MANAGER = 0x36BA7c92Cd68051fB304Bd4580C4A51c1d376532;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    RequestRedeemDETHHook public requestRedeemHook;
    ApproveAndRequestRedeemDETHHook public approveAndRequestHook;
    ClaimAssetsDETHHook public claimHook;

    bytes32 public yieldSourceOracleId;
    uint256 public forkId;

    /// @dev Test smart account that simulates a SuperVault strategy
    address public account;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        forkId = vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));

        requestRedeemHook = new RequestRedeemDETHHook();
        approveAndRequestHook = new ApproveAndRequestRedeemDETHHook();
        claimHook = new ClaimAssetsDETHHook();
        yieldSourceOracleId = bytes32(keccak256("DETH_ORACLE_ID"));

        // Use a deterministic address as the smart account
        account = makeAddr("superVaultStrategy");

        // Whitelist the account on AsyncRedeemer via riskManager
        _whitelistAccount(account);

        // Give the account DETH tokens
        deal(DETH, account, 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                          VAULT SANITY CHECKS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify Machine's shareToken is DETH
    function test_machine_shareTokenIsDETH() public view {
        assertEq(IMachine(MACHINE).shareToken(), DETH, "Machine shareToken should be DETH");
    }

    /// @notice Verify Machine's accountingToken is WETH
    function test_machine_accountingTokenIsWETH() public view {
        assertEq(IMachine(MACHINE).accountingToken(), WETH, "Machine accountingToken should be WETH");
    }

    /// @notice Verify AsyncRedeemer points to Machine
    function test_asyncRedeemer_machineAddress() public view {
        assertEq(IDETHAsyncRedeemer(ASYNC_REDEEMER).machine(), MACHINE, "AsyncRedeemer machine should be Machine");
    }

    /// @notice Verify DETH has 18 decimals
    function test_deth_decimals() public view {
        assertEq(IERC20Metadata(DETH).decimals(), 18, "DETH should have 18 decimals");
    }

    /// @notice Verify whitelist is enabled and account is whitelisted
    function test_whitelist_accountIsWhitelisted() public view {
        assertTrue(IAsyncRedeemerAdmin(ASYNC_REDEEMER).isWhitelistEnabled(), "Whitelist should be enabled");
        assertTrue(IAsyncRedeemerAdmin(ASYNC_REDEEMER).isWhitelistedUser(account), "Account should be whitelisted");
    }

    /// @notice Verify account has DETH balance from deal
    function test_account_hasDETHBalance() public view {
        assertEq(IERC20(DETH).balanceOf(account), 100 ether, "Account should have 100 DETH");
    }

    /*//////////////////////////////////////////////////////////////
                  REQUEST REDEEM HOOK INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that RequestRedeemDETHHook builds correct calldata targeting the real AsyncRedeemer
    function test_requestRedeemHook_buildTargetsRealAsyncRedeemer() public view {
        uint256 shares = 1 ether;
        uint256 minAssets = 0.9 ether;
        bytes memory data = _encodeRequestRedeemData(ASYNC_REDEEMER, shares, minAssets, false);
        Execution[] memory executions = requestRedeemHook.build(address(0), account, data);

        assertEq(executions.length, 3, "Should have 3 executions (pre + requestRedeem + post)");
        assertEq(executions[1].target, ASYNC_REDEEMER, "Target should be AsyncRedeemer");
        assertEq(
            executions[1].callData,
            abi.encodeCall(IDETHAsyncRedeemer.requestRedeem, (shares, account, minAssets)),
            "Calldata should encode requestRedeem(shares, account, minAssets)"
        );
    }

    /// @notice Test requestRedeem on the real AsyncRedeemer: transfers DETH, mints NFT
    function test_requestRedeemHook_realRequestRedeem() public {
        uint256 shares = 1 ether;

        uint256 nextId = IAsyncRedeemerAdmin(ASYNC_REDEEMER).nextRequestId();
        uint256 dethBefore = IERC20(DETH).balanceOf(account);

        vm.startPrank(account);
        IERC20(DETH).approve(ASYNC_REDEEMER, shares);
        uint256 requestId = IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(shares, account, 0);
        vm.stopPrank();

        uint256 dethAfter = IERC20(DETH).balanceOf(account);

        assertEq(requestId, nextId, "Request ID should match nextRequestId");
        assertEq(dethBefore - dethAfter, shares, "Should have transferred exactly the shares");

        // Verify NFT minted to account
        assertEq(IAsyncRedeemerAdmin(ASYNC_REDEEMER).ownerOf(requestId), account, "NFT should be owned by account");

        console2.log("requestRedeem success: requestId =", requestId);
    }

    /// @notice Test that requestRedeemHook pre/postExecute tracks DETH balance delta via usedShares
    function test_requestRedeemHook_prePostExecute_tracksRealShareBurn() public {
        uint256 shares = 1 ether;

        bytes memory data = _encodeRequestRedeemData(ASYNC_REDEEMER, shares, 0, false);

        // Pre-execute: captures DETH balance (must prank as account - BaseHook requires msg.sender == account)
        vm.prank(account);
        requestRedeemHook.preExecute(address(0), account, data);
        assertEq(
            requestRedeemHook.usedShares(),
            IERC20(DETH).balanceOf(account),
            "preExecute should capture full DETH balance"
        );

        // Execute: approve + requestRedeem on the real contract
        vm.startPrank(account);
        IERC20(DETH).approve(ASYNC_REDEEMER, shares);
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(shares, account, 0);

        // Post-execute: calculates delta
        requestRedeemHook.postExecute(address(0), account, data);
        vm.stopPrank();

        assertEq(requestRedeemHook.usedShares(), shares, "usedShares should equal DETH transferred");
    }

    /*//////////////////////////////////////////////////////////////
            APPROVE AND REQUEST REDEEM HOOK INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that ApproveAndRequestRedeemDETHHook builds 4 correct executions
    function test_approveAndRequestHook_buildTargetsRealContracts() public view {
        uint256 shares = 1 ether;
        uint256 minAssets = 0.9 ether;
        bytes memory data = _encodeApproveAndRequestData(ASYNC_REDEEMER, DETH, shares, minAssets, false);
        Execution[] memory executions = approveAndRequestHook.build(address(0), account, data);

        assertEq(executions.length, 6, "Should have 6 executions (pre + 4 hook + post)");

        // approve(0)
        assertEq(executions[1].target, DETH);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (ASYNC_REDEEMER, 0)));

        // approve(shares)
        assertEq(executions[2].target, DETH);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (ASYNC_REDEEMER, shares)));

        // requestRedeem
        assertEq(executions[3].target, ASYNC_REDEEMER);
        assertEq(
            executions[3].callData,
            abi.encodeCall(IDETHAsyncRedeemer.requestRedeem, (shares, account, minAssets))
        );

        // approve(0) cleanup
        assertEq(executions[4].target, DETH);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (ASYNC_REDEEMER, 0)));
    }

    /// @notice Test approve + requestRedeem end-to-end on real contracts
    function test_approveAndRequestHook_realApproveAndRequest() public {
        uint256 shares = 1 ether;

        uint256 nextId = IAsyncRedeemerAdmin(ASYNC_REDEEMER).nextRequestId();
        uint256 dethBefore = IERC20(DETH).balanceOf(account);

        // Execute the full approve+request flow (simulating what the executions would do)
        vm.startPrank(account);
        IERC20(DETH).approve(ASYNC_REDEEMER, 0);
        IERC20(DETH).approve(ASYNC_REDEEMER, shares);
        uint256 requestId = IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(shares, account, 0);
        IERC20(DETH).approve(ASYNC_REDEEMER, 0);
        vm.stopPrank();

        uint256 dethAfter = IERC20(DETH).balanceOf(account);

        assertEq(requestId, nextId, "Request ID should match nextRequestId");
        assertEq(dethBefore - dethAfter, shares, "Should have transferred exactly the shares");
        assertEq(IERC20(DETH).allowance(account, ASYNC_REDEEMER), 0, "Allowance should be 0 after cleanup");
    }

    /// @notice Test pre/postExecute tracking for approve+request hook
    function test_approveAndRequestHook_prePostExecute_tracksBalance() public {
        uint256 shares = 1 ether;

        bytes memory data = _encodeApproveAndRequestData(ASYNC_REDEEMER, DETH, shares, 0, false);

        // Pre-execute
        vm.prank(account);
        approveAndRequestHook.preExecute(address(0), account, data);
        assertEq(
            approveAndRequestHook.getOutAmount(account),
            IERC20(DETH).balanceOf(account),
            "preExecute should capture full DETH balance"
        );

        // Execute
        vm.startPrank(account);
        IERC20(DETH).approve(ASYNC_REDEEMER, shares);
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(shares, account, 0);

        // Post-execute
        approveAndRequestHook.postExecute(address(0), account, data);
        vm.stopPrank();

        assertEq(approveAndRequestHook.getOutAmount(account), shares, "outAmount should equal DETH transferred");
    }

    /*//////////////////////////////////////////////////////////////
                    CLAIM ASSETS HOOK INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that ClaimAssetsDETHHook builds correct calldata
    function test_claimHook_buildTargetsRealAsyncRedeemer() public view {
        uint256 requestId = 1;
        bytes memory data = _encodeClaimData(ASYNC_REDEEMER, requestId, false);
        Execution[] memory executions = claimHook.build(address(0), account, data);

        assertEq(executions.length, 3, "Should have 3 executions (pre + claimAssets + post)");
        assertEq(executions[1].target, ASYNC_REDEEMER, "Target should be AsyncRedeemer");
        assertEq(
            executions[1].callData,
            abi.encodeCall(IDETHAsyncRedeemer.claimAssets, (requestId)),
            "Calldata should encode claimAssets(requestId)"
        );
    }

    /// @notice Test that requestRedeem hook preExecute caches DETH shareToken in spToken (P3-5 gas fix)
    function test_requestRedeemHook_preExecute_cachesSpToken() public {
        uint256 amount = 10 ether;
        deal(DETH, account, amount);

        bytes memory data = _encodeRequestRedeemData(ASYNC_REDEEMER, amount, 0, false);

        vm.prank(account);
        requestRedeemHook.preExecute(address(0), account, data);

        // spToken should be cached to DETH via machine().shareToken() discovery chain
        assertEq(requestRedeemHook.spToken(), DETH, "spToken should be cached to DETH share token");
        assertEq(requestRedeemHook.usedShares(), amount, "usedShares should snapshot DETH balance");
    }

    /// @notice Test that requestRedeem hook postExecute uses cached spToken, not re-derived
    function test_requestRedeemHook_postExecute_usesCachedSpToken() public {
        uint256 amount = 10 ether;
        deal(DETH, account, amount);

        bytes memory data = _encodeRequestRedeemData(ASYNC_REDEEMER, amount, 0, false);

        vm.prank(account);
        requestRedeemHook.preExecute(address(0), account, data);
        assertEq(requestRedeemHook.spToken(), DETH);

        // Simulate DETH burned by requestRedeem
        uint256 burnAmount = amount / 2;
        deal(DETH, account, amount - burnAmount);

        vm.prank(account);
        requestRedeemHook.postExecute(address(0), account, data);

        assertEq(requestRedeemHook.usedShares(), burnAmount, "usedShares tracks burn via cached spToken");
        assertEq(requestRedeemHook.spToken(), DETH, "spToken still cached after postExecute");
    }

    /// @notice Test that approveAndRequest hook does NOT set spToken (NONACCOUNTING, no caching)
    function test_approveAndRequestHook_doesNotSetSpToken() public {
        uint256 amount = 10 ether;
        deal(DETH, account, amount);

        bytes memory data = _encodeApproveAndRequestData(ASYNC_REDEEMER, DETH, amount, 0, false);

        vm.prank(account);
        approveAndRequestHook.preExecute(address(0), account, data);

        // ApproveAndRequestRedeemDETHHook does NOT set spToken (only tracks outAmount)
        assertEq(approveAndRequestHook.spToken(), address(0), "spToken should not be set for NONACCOUNTING hook");
    }

    /// @notice Test that claim hook preExecute correctly discovers WETH from real Machine
    function test_claimHook_preExecute_discoversRealWETH() public {
        bytes memory data = _encodeClaimData(ASYNC_REDEEMER, 0, false);

        vm.prank(account);
        claimHook.preExecute(address(0), account, data);

        assertEq(claimHook.asset(), WETH, "asset should be WETH discovered via machine().accountingToken()");
        assertEq(claimHook.spToken(), DETH, "spToken should be DETH share token");
    }

    /// @notice Test real claimAssets on an already-finalized request (request #30 on mainnet)
    /// @dev Request #30 is finalized on mainnet, owned by 0x7bb196C9eBf38DA33804A5941E6a501BeA9AF406
    function test_claimHook_realClaimOnFinalizedRequest() public {
        uint256 requestId = 30;
        address nftOwner = IAsyncRedeemerAdmin(ASYNC_REDEEMER).ownerOf(requestId);

        // Whitelist the NFT owner (may already be whitelisted)
        _whitelistAccount(nftOwner);

        uint256 wethBefore = IERC20(WETH).balanceOf(nftOwner);

        bytes memory data = _encodeClaimData(ASYNC_REDEEMER, requestId, false);

        // Pre-execute
        vm.prank(nftOwner);
        claimHook.preExecute(address(0), nftOwner, data);
        assertEq(claimHook.asset(), WETH, "asset should be WETH");

        // Execute real claimAssets
        vm.prank(nftOwner);
        uint256 assetsReceived = IDETHAsyncRedeemer(ASYNC_REDEEMER).claimAssets(requestId);

        // Post-execute
        vm.prank(nftOwner);
        claimHook.postExecute(address(0), nftOwner, data);

        uint256 wethAfter = IERC20(WETH).balanceOf(nftOwner);
        uint256 outAmount = claimHook.getOutAmount(nftOwner);

        assertGt(assetsReceived, 0, "Should have received WETH");
        assertEq(wethAfter - wethBefore, assetsReceived, "WETH delta should match assets received");
        assertEq(outAmount, assetsReceived, "outAmount should match assets received");

        // Verify NFT burned
        vm.expectRevert();
        IAsyncRedeemerAdmin(ASYNC_REDEEMER).ownerOf(requestId);

        console2.log("claimAssets success: WETH received =", assetsReceived);
    }

    /// @notice Verify claim hook does NOT set usedShares
    function test_claimHook_usedSharesNotSet() public {
        uint256 requestId = 30;
        address nftOwner = IAsyncRedeemerAdmin(ASYNC_REDEEMER).ownerOf(requestId);
        _whitelistAccount(nftOwner);

        bytes memory data = _encodeClaimData(ASYNC_REDEEMER, requestId, false);

        vm.prank(nftOwner);
        claimHook.preExecute(address(0), nftOwner, data);

        vm.prank(nftOwner);
        IDETHAsyncRedeemer(ASYNC_REDEEMER).claimAssets(requestId);

        vm.prank(nftOwner);
        claimHook.postExecute(address(0), nftOwner, data);

        // usedShares should be 0 (intentionally not set in claim hook)
        assertEq(claimHook.usedShares(), 0, "usedShares should NOT be set in claim hook");
    }

    /*//////////////////////////////////////////////////////////////
                          FULL E2E FLOW
    //////////////////////////////////////////////////////////////*/

    /// @notice Full E2E: request → simulate finalization via deal → claim
    /// @dev We can't call finalizeRequests on fork (requires Aave interaction in Machine),
    ///      so we simulate the claim phase by dealing WETH to the account
    function test_e2e_requestAndSimulatedClaim() public {
        uint256 shares = 10 ether;

        // --- Phase 1: Request Redeem ---
        uint256 dethBefore = IERC20(DETH).balanceOf(account);

        bytes memory requestData = _encodeRequestRedeemData(ASYNC_REDEEMER, shares, 0, false);

        vm.prank(account);
        requestRedeemHook.preExecute(address(0), account, requestData);

        vm.startPrank(account);
        IERC20(DETH).approve(ASYNC_REDEEMER, shares);
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(shares, account, 0);
        requestRedeemHook.postExecute(address(0), account, requestData);
        vm.stopPrank();

        assertEq(requestRedeemHook.usedShares(), shares, "usedShares should track DETH transferred");
        assertEq(IERC20(DETH).balanceOf(account), dethBefore - shares, "DETH balance should decrease");

        // --- Phase 2: Simulated claim (deal WETH, like Firelight E2E) ---
        // In production, Dialectic keeper finalizes → then claimAssets transfers WETH.
        // On fork, we simulate the WETH arrival to test hook tracking.
        uint256 expectedWeth = 10.09 ether; // ~1.009 WETH per DETH

        bytes memory claimData = _encodeClaimData(ASYNC_REDEEMER, 0, false);

        vm.prank(account);
        claimHook.preExecute(address(0), account, claimData);
        assertEq(claimHook.asset(), WETH, "asset should be WETH");

        uint256 wethBeforeClaim = IERC20(WETH).balanceOf(account);

        // Simulate WETH arriving from claim
        deal(WETH, account, wethBeforeClaim + expectedWeth);

        vm.prank(account);
        claimHook.postExecute(address(0), account, claimData);

        assertEq(claimHook.getOutAmount(account), expectedWeth, "outAmount should match WETH delta");
        console2.log("E2E complete: DETH transferred =", shares, "WETH received (simulated) =", expectedWeth);
    }

    /// @notice Full E2E using ApproveAndRequestRedeemDETHHook variant
    function test_e2e_approveAndRequestThenSimulatedClaim() public {
        uint256 shares = 5 ether;

        // --- Phase 1: Approve + Request ---
        bytes memory requestData = _encodeApproveAndRequestData(ASYNC_REDEEMER, DETH, shares, 0, false);

        vm.prank(account);
        approveAndRequestHook.preExecute(address(0), account, requestData);

        vm.startPrank(account);
        IERC20(DETH).approve(ASYNC_REDEEMER, 0);
        IERC20(DETH).approve(ASYNC_REDEEMER, shares);
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(shares, account, 0);
        IERC20(DETH).approve(ASYNC_REDEEMER, 0);
        approveAndRequestHook.postExecute(address(0), account, requestData);
        vm.stopPrank();

        assertEq(approveAndRequestHook.getOutAmount(account), shares, "outAmount should track DETH transferred");
        assertEq(IERC20(DETH).allowance(account, ASYNC_REDEEMER), 0, "Allowance should be 0 after");

        // --- Phase 2: Simulated claim ---
        uint256 expectedWeth = 5.045 ether;

        bytes memory claimData = _encodeClaimData(ASYNC_REDEEMER, 0, false);

        vm.prank(account);
        claimHook.preExecute(address(0), account, claimData);

        deal(WETH, account, expectedWeth);

        vm.prank(account);
        claimHook.postExecute(address(0), account, claimData);

        assertEq(claimHook.getOutAmount(account), expectedWeth, "outAmount should match");
    }

    /*//////////////////////////////////////////////////////////////
                     HOOK PROPERTY TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify hook types
    function test_hookTypes() public view {
        assertEq(uint256(requestRedeemHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(approveAndRequestHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(claimHook.hookType()), uint256(ISuperHook.HookType.OUTFLOW));
    }

    /// @notice Verify hook subtypes
    function test_hookSubTypes() public view {
        assertEq(requestRedeemHook.SUB_TYPE(), HookSubTypes.ERC4626);
        assertEq(approveAndRequestHook.SUB_TYPE(), HookSubTypes.ERC4626);
        assertEq(claimHook.SUB_TYPE(), HookSubTypes.ERC4626);
    }

    /// @notice Verify inspect returns correct addresses
    function test_inspect() public view {
        bytes memory requestData = _encodeRequestRedeemData(ASYNC_REDEEMER, 1 ether, 0, false);
        assertEq(requestRedeemHook.inspect(requestData), abi.encodePacked(ASYNC_REDEEMER));

        bytes memory approveData = _encodeApproveAndRequestData(ASYNC_REDEEMER, DETH, 1 ether, 0, false);
        assertEq(approveAndRequestHook.inspect(approveData), abi.encodePacked(ASYNC_REDEEMER, DETH));

        bytes memory claimData = _encodeClaimData(ASYNC_REDEEMER, 1, false);
        assertEq(claimHook.inspect(claimData), abi.encodePacked(ASYNC_REDEEMER));
    }

    /*//////////////////////////////////////////////////////////////
                    NON-WHITELISTED REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify that non-whitelisted accounts cannot call requestRedeem
    function test_requestRedeem_revertsIfNotWhitelisted() public {
        address nonWhitelisted = makeAddr("nonWhitelisted");
        deal(DETH, nonWhitelisted, 1 ether);

        vm.startPrank(nonWhitelisted);
        IERC20(DETH).approve(ASYNC_REDEEMER, 1 ether);
        vm.expectRevert();
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(1 ether, nonWhitelisted, 0);
        vm.stopPrank();
    }

    /// @notice Verify that non-owner cannot claim someone else's NFT
    function test_claimAssets_revertsIfNotNFTOwner() public {
        // Request #30 is finalized and owned by a different address
        uint256 requestId = 30;
        address nftOwner = IAsyncRedeemerAdmin(ASYNC_REDEEMER).ownerOf(requestId);
        assertTrue(nftOwner != account, "NFT owner should be different from test account");

        // Account is whitelisted but doesn't own the NFT
        vm.prank(account);
        vm.expectRevert();
        IDETHAsyncRedeemer(ASYNC_REDEEMER).claimAssets(requestId);
    }

    /*//////////////////////////////////////////////////////////////
                  REQUEST REDEEM — EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice Multiple sequential requests from the same account increment request IDs correctly
    function test_requestRedeem_multipleSequentialRequests() public {
        uint256 shares1 = 1 ether;
        uint256 shares2 = 2 ether;
        uint256 shares3 = 0.5 ether;

        uint256 nextId = IAsyncRedeemerAdmin(ASYNC_REDEEMER).nextRequestId();

        vm.startPrank(account);
        IERC20(DETH).approve(ASYNC_REDEEMER, shares1 + shares2 + shares3);

        uint256 id1 = IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(shares1, account, 0);
        uint256 id2 = IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(shares2, account, 0);
        uint256 id3 = IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(shares3, account, 0);
        vm.stopPrank();

        assertEq(id1, nextId, "First request ID should match nextRequestId");
        assertEq(id2, nextId + 1, "Second request should be +1");
        assertEq(id3, nextId + 2, "Third request should be +2");

        // All NFTs owned by account
        assertEq(IAsyncRedeemerAdmin(ASYNC_REDEEMER).ownerOf(id1), account);
        assertEq(IAsyncRedeemerAdmin(ASYNC_REDEEMER).ownerOf(id2), account);
        assertEq(IAsyncRedeemerAdmin(ASYNC_REDEEMER).ownerOf(id3), account);
    }

    /// @notice Request with account's entire DETH balance
    function test_requestRedeem_fullBalance() public {
        uint256 fullBalance = IERC20(DETH).balanceOf(account);
        assertEq(fullBalance, 100 ether, "Precondition: full balance is 100 DETH");

        vm.startPrank(account);
        IERC20(DETH).approve(ASYNC_REDEEMER, fullBalance);
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(fullBalance, account, 0);
        vm.stopPrank();

        assertEq(IERC20(DETH).balanceOf(account), 0, "Account should have zero DETH after full redeem");
    }

    /// @notice Request with tiny amount (1 wei of DETH)
    function test_requestRedeem_tinyAmount() public {
        uint256 tinyAmount = 1;

        vm.startPrank(account);
        IERC20(DETH).approve(ASYNC_REDEEMER, tinyAmount);
        uint256 requestId = IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(tinyAmount, account, 0);
        vm.stopPrank();

        assertEq(IAsyncRedeemerAdmin(ASYNC_REDEEMER).ownerOf(requestId), account);
        assertEq(IERC20(DETH).balanceOf(account), 100 ether - tinyAmount);
    }

    /// @notice Verify DETH actually arrives at AsyncRedeemer after requestRedeem
    function test_requestRedeem_dethTransferredToAsyncRedeemer() public {
        uint256 shares = 5 ether;
        uint256 asyncRedeemerDethBefore = IERC20(DETH).balanceOf(ASYNC_REDEEMER);

        vm.startPrank(account);
        IERC20(DETH).approve(ASYNC_REDEEMER, shares);
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(shares, account, 0);
        vm.stopPrank();

        uint256 asyncRedeemerDethAfter = IERC20(DETH).balanceOf(ASYNC_REDEEMER);
        assertEq(asyncRedeemerDethAfter - asyncRedeemerDethBefore, shares, "AsyncRedeemer DETH should increase by shares");
    }

    /// @notice usedShares tracks exact partial redeem delta, not full balance
    function test_requestRedeemHook_usedShares_partialRedeem() public {
        uint256 shares = 30 ether; // Redeem 30 out of 100 DETH

        bytes memory data = _encodeRequestRedeemData(ASYNC_REDEEMER, shares, 0, false);

        vm.prank(account);
        requestRedeemHook.preExecute(address(0), account, data);
        // preExecute captures the full 100 DETH balance
        assertEq(requestRedeemHook.usedShares(), 100 ether);

        vm.startPrank(account);
        IERC20(DETH).approve(ASYNC_REDEEMER, shares);
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(shares, account, 0);
        requestRedeemHook.postExecute(address(0), account, data);
        vm.stopPrank();

        // usedShares = pre(100) - post(70) = 30
        assertEq(requestRedeemHook.usedShares(), shares, "usedShares should be exactly the shares transferred");
        assertEq(IERC20(DETH).balanceOf(account), 70 ether, "Remaining DETH should be 70");
    }

    /// @notice Request with insufficient approval should revert
    function test_requestRedeem_insufficientApproval() public {
        vm.startPrank(account);
        IERC20(DETH).approve(ASYNC_REDEEMER, 0.5 ether);
        vm.expectRevert();
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(1 ether, account, 0);
        vm.stopPrank();
    }

    /// @notice Request without any approval should revert
    function test_requestRedeem_noApproval() public {
        vm.prank(account);
        vm.expectRevert();
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(1 ether, account, 0);
    }

    /// @notice Request with insufficient DETH balance should revert
    function test_requestRedeem_insufficientBalance() public {
        uint256 tooMuch = 200 ether; // Account only has 100

        vm.startPrank(account);
        IERC20(DETH).approve(ASYNC_REDEEMER, tooMuch);
        vm.expectRevert();
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(tooMuch, account, 0);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
            APPROVE AND REQUEST — EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice Zero-set-execute-zero clears dirty allowance from a previous failed attempt
    function test_approveAndRequest_clearsDirtyAllowance() public {
        // Simulate a dirty allowance left from a prior interaction
        vm.prank(account);
        IERC20(DETH).approve(ASYNC_REDEEMER, 999 ether);

        uint256 shares = 1 ether;

        // Execute the full approve pattern
        vm.startPrank(account);
        IERC20(DETH).approve(ASYNC_REDEEMER, 0); // reset dirty
        IERC20(DETH).approve(ASYNC_REDEEMER, shares); // set exact
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(shares, account, 0);
        IERC20(DETH).approve(ASYNC_REDEEMER, 0); // cleanup
        vm.stopPrank();

        assertEq(IERC20(DETH).allowance(account, ASYNC_REDEEMER), 0, "Allowance must be 0 after cleanup");
    }

    /// @notice ApproveAndRequest with full balance
    function test_approveAndRequest_fullBalance() public {
        uint256 fullBalance = IERC20(DETH).balanceOf(account);

        bytes memory data = _encodeApproveAndRequestData(ASYNC_REDEEMER, DETH, fullBalance, 0, false);

        vm.prank(account);
        approveAndRequestHook.preExecute(address(0), account, data);

        vm.startPrank(account);
        IERC20(DETH).approve(ASYNC_REDEEMER, 0);
        IERC20(DETH).approve(ASYNC_REDEEMER, fullBalance);
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(fullBalance, account, 0);
        IERC20(DETH).approve(ASYNC_REDEEMER, 0);
        approveAndRequestHook.postExecute(address(0), account, data);
        vm.stopPrank();

        assertEq(IERC20(DETH).balanceOf(account), 0, "Should have zero DETH after full redeem");
        assertEq(approveAndRequestHook.getOutAmount(account), fullBalance, "outAmount should equal full balance");
    }

    /// @notice Two back-to-back approve+request with fresh hook instances (no state collision)
    function test_approveAndRequest_twoSequentialWithTracking() public {
        uint256 shares1 = 3 ether;
        uint256 shares2 = 7 ether;

        // --- First request ---
        bytes memory data1 = _encodeApproveAndRequestData(ASYNC_REDEEMER, DETH, shares1, 0, false);

        vm.prank(account);
        approveAndRequestHook.preExecute(address(0), account, data1);

        vm.startPrank(account);
        IERC20(DETH).approve(ASYNC_REDEEMER, 0);
        IERC20(DETH).approve(ASYNC_REDEEMER, shares1);
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(shares1, account, 0);
        IERC20(DETH).approve(ASYNC_REDEEMER, 0);
        approveAndRequestHook.postExecute(address(0), account, data1);
        vm.stopPrank();

        assertEq(approveAndRequestHook.getOutAmount(account), shares1, "First outAmount should be shares1");

        // --- Second request (new hook instance to avoid transient state) ---
        ApproveAndRequestRedeemDETHHook hook2 = new ApproveAndRequestRedeemDETHHook();
        bytes memory data2 = _encodeApproveAndRequestData(ASYNC_REDEEMER, DETH, shares2, 0, false);

        vm.prank(account);
        hook2.preExecute(address(0), account, data2);

        vm.startPrank(account);
        IERC20(DETH).approve(ASYNC_REDEEMER, 0);
        IERC20(DETH).approve(ASYNC_REDEEMER, shares2);
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(shares2, account, 0);
        IERC20(DETH).approve(ASYNC_REDEEMER, 0);
        hook2.postExecute(address(0), account, data2);
        vm.stopPrank();

        assertEq(hook2.getOutAmount(account), shares2, "Second outAmount should be shares2");
        assertEq(IERC20(DETH).balanceOf(account), 100 ether - shares1 - shares2, "Remaining balance should be correct");
    }

    /*//////////////////////////////////////////////////////////////
                    CLAIM ASSETS — EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice Claiming a non-finalized request reverts with NotFinalized()
    function test_claimAssets_revertsIfNotFinalized() public {
        // Create a new request (it won't be finalized)
        vm.startPrank(account);
        IERC20(DETH).approve(ASYNC_REDEEMER, 1 ether);
        uint256 requestId = IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(1 ether, account, 0);
        vm.stopPrank();

        // Verify it's not finalized
        uint256 lastFinalized = IAsyncRedeemerAdmin(ASYNC_REDEEMER).lastFinalizedRequestId();
        assertGt(requestId, lastFinalized, "Request should be above lastFinalizedRequestId");

        // Attempt to claim should revert with NotFinalized()
        vm.prank(account);
        vm.expectRevert(); // NotFinalized()
        IDETHAsyncRedeemer(ASYNC_REDEEMER).claimAssets(requestId);
    }

    /// @notice Claiming a non-existent request ID reverts with ERC721NonexistentToken
    function test_claimAssets_revertsIfNonExistentRequest() public {
        vm.prank(account);
        vm.expectRevert(); // ERC721NonexistentToken(999999)
        IDETHAsyncRedeemer(ASYNC_REDEEMER).claimAssets(999_999);
    }

    /// @notice Claiming an already-claimed request reverts (NFT burned)
    function test_claimAssets_revertsIfAlreadyClaimed() public {
        uint256 requestId = 30;
        address nftOwner = IAsyncRedeemerAdmin(ASYNC_REDEEMER).ownerOf(requestId);
        _whitelistAccount(nftOwner);

        // Claim once — should succeed
        vm.prank(nftOwner);
        IDETHAsyncRedeemer(ASYNC_REDEEMER).claimAssets(requestId);

        // Claim again — should revert (NFT burned)
        vm.prank(nftOwner);
        vm.expectRevert(); // ERC721NonexistentToken
        IDETHAsyncRedeemer(ASYNC_REDEEMER).claimAssets(requestId);
    }

    /// @notice Claim hook correctly tracks WETH delta when account has pre-existing WETH balance
    function test_claimHook_tracksWethDelta_withExistingBalance() public {
        uint256 requestId = 30;
        address nftOwner = IAsyncRedeemerAdmin(ASYNC_REDEEMER).ownerOf(requestId);
        _whitelistAccount(nftOwner);

        // Give the owner some pre-existing WETH
        uint256 existingWeth = 50 ether;
        deal(WETH, nftOwner, existingWeth);
        assertEq(IERC20(WETH).balanceOf(nftOwner), existingWeth);

        bytes memory data = _encodeClaimData(ASYNC_REDEEMER, requestId, false);

        vm.prank(nftOwner);
        claimHook.preExecute(address(0), nftOwner, data);
        // preExecute snapshots existingWeth
        assertEq(claimHook.getOutAmount(nftOwner), existingWeth, "preExecute should snapshot existing WETH");

        vm.prank(nftOwner);
        uint256 assetsReceived = IDETHAsyncRedeemer(ASYNC_REDEEMER).claimAssets(requestId);

        vm.prank(nftOwner);
        claimHook.postExecute(address(0), nftOwner, data);

        // outAmount should be ONLY the delta, not the full balance
        assertEq(claimHook.getOutAmount(nftOwner), assetsReceived, "outAmount should be delta, not full balance");
        assertEq(IERC20(WETH).balanceOf(nftOwner), existingWeth + assetsReceived, "Total WETH = existing + claimed");
    }

    /// @notice Non-whitelisted NFT owner cannot claim even if they own the NFT
    function test_claimAssets_revertsIfOwnerNotWhitelisted() public {
        // Create a request
        vm.startPrank(account);
        IERC20(DETH).approve(ASYNC_REDEEMER, 1 ether);
        uint256 requestId = IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(1 ether, account, 0);
        vm.stopPrank();

        // Remove account from whitelist
        address[] memory users = new address[](1);
        users[0] = account;
        vm.prank(RISK_MANAGER);
        IAsyncRedeemerAdmin(ASYNC_REDEEMER).setWhitelistedUsers(users, false);

        assertFalse(IAsyncRedeemerAdmin(ASYNC_REDEEMER).isWhitelistedUser(account), "Account should be de-whitelisted");

        // Even though account owns the NFT, claimAssets should revert
        vm.prank(account);
        vm.expectRevert(); // UnauthorizedCaller
        IDETHAsyncRedeemer(ASYNC_REDEEMER).claimAssets(requestId);
    }

    /*//////////////////////////////////////////////////////////////
                  MACHINE DISCOVERY CHAIN TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify the full discovery chain: asyncRedeemer → machine() → shareToken() == DETH
    function test_discoveryChain_shareToken() public view {
        address machine = IDETHAsyncRedeemer(ASYNC_REDEEMER).machine();
        assertEq(machine, MACHINE, "machine() should return Machine address");

        address shareToken = IMachine(machine).shareToken();
        assertEq(shareToken, DETH, "shareToken() should return DETH address");
    }

    /// @notice Verify the full discovery chain: asyncRedeemer → machine() → accountingToken() == WETH
    function test_discoveryChain_accountingToken() public view {
        address machine = IDETHAsyncRedeemer(ASYNC_REDEEMER).machine();
        address accountingToken = IMachine(machine).accountingToken();
        assertEq(accountingToken, WETH, "accountingToken() should return WETH address");
    }

    /*//////////////////////////////////////////////////////////////
              TWO DIFFERENT ACCOUNTS — ISOLATION TEST
    //////////////////////////////////////////////////////////////*/

    /// @notice Two different accounts making requests — verify they don't interfere
    function test_twoAccounts_independentRequests() public {
        address account2 = makeAddr("superVaultStrategy2");
        _whitelistAccount(account2);
        deal(DETH, account2, 50 ether);

        uint256 shares1 = 10 ether;
        uint256 shares2 = 20 ether;

        uint256 nextId = IAsyncRedeemerAdmin(ASYNC_REDEEMER).nextRequestId();

        // Account 1 requests
        vm.startPrank(account);
        IERC20(DETH).approve(ASYNC_REDEEMER, shares1);
        uint256 id1 = IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(shares1, account, 0);
        vm.stopPrank();

        // Account 2 requests
        vm.startPrank(account2);
        IERC20(DETH).approve(ASYNC_REDEEMER, shares2);
        uint256 id2 = IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(shares2, account2, 0);
        vm.stopPrank();

        assertEq(id1, nextId);
        assertEq(id2, nextId + 1);
        assertEq(IAsyncRedeemerAdmin(ASYNC_REDEEMER).ownerOf(id1), account, "NFT 1 should belong to account1");
        assertEq(IAsyncRedeemerAdmin(ASYNC_REDEEMER).ownerOf(id2), account2, "NFT 2 should belong to account2");

        // Account 2 cannot claim account 1's NFT
        vm.prank(account2);
        vm.expectRevert();
        IDETHAsyncRedeemer(ASYNC_REDEEMER).claimAssets(id1);
    }

    /// @notice Two accounts with independent hook tracking don't share state
    function test_twoAccounts_hookTrackingIsolation() public {
        address account2 = makeAddr("superVaultStrategy2");
        _whitelistAccount(account2);
        deal(DETH, account2, 50 ether);

        uint256 shares1 = 5 ether;
        uint256 shares2 = 15 ether;

        RequestRedeemDETHHook hook1 = new RequestRedeemDETHHook();
        RequestRedeemDETHHook hook2 = new RequestRedeemDETHHook();

        // Account 1
        bytes memory data1 = _encodeRequestRedeemData(ASYNC_REDEEMER, shares1, 0, false);
        vm.prank(account);
        hook1.preExecute(address(0), account, data1);

        vm.startPrank(account);
        IERC20(DETH).approve(ASYNC_REDEEMER, shares1);
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(shares1, account, 0);
        hook1.postExecute(address(0), account, data1);
        vm.stopPrank();

        // Account 2
        bytes memory data2 = _encodeRequestRedeemData(ASYNC_REDEEMER, shares2, 0, false);
        vm.prank(account2);
        hook2.preExecute(address(0), account2, data2);

        vm.startPrank(account2);
        IERC20(DETH).approve(ASYNC_REDEEMER, shares2);
        IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(shares2, account2, 0);
        hook2.postExecute(address(0), account2, data2);
        vm.stopPrank();

        assertEq(hook1.usedShares(), shares1, "Hook1 usedShares should be shares1");
        assertEq(hook2.usedShares(), shares2, "Hook2 usedShares should be shares2");
    }

    /*//////////////////////////////////////////////////////////////
                  REAL CLAIM — WETH AMOUNT SANITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify real claimed WETH is reasonable (sanity check against PPS)
    function test_realClaim_wethAmountSanity() public {
        uint256 requestId = 30;
        address nftOwner = IAsyncRedeemerAdmin(ASYNC_REDEEMER).ownerOf(requestId);
        _whitelistAccount(nftOwner);

        uint256 wethBefore = IERC20(WETH).balanceOf(nftOwner);

        vm.prank(nftOwner);
        uint256 assetsReceived = IDETHAsyncRedeemer(ASYNC_REDEEMER).claimAssets(requestId);

        uint256 wethAfter = IERC20(WETH).balanceOf(nftOwner);

        // Verify basic sanity
        assertGt(assetsReceived, 0, "Must receive some WETH");
        assertEq(wethAfter - wethBefore, assetsReceived, "Balance delta must match return value");

        // The AsyncRedeemer had ~101 WETH — claim should not exceed that
        assertLe(assetsReceived, 200 ether, "Claimed amount should be reasonable (< 200 WETH)");

        console2.log("Real claim WETH received:", assetsReceived);
    }

    /*//////////////////////////////////////////////////////////////
                  FULL E2E — REQUEST + REAL CLAIM
    //////////////////////////////////////////////////////////////*/

    /// @notice Full lifecycle: account requests → claim from already-finalized request #30
    ///         Exercises both request hooks AND real claimAssets in a single test
    function test_e2e_requestNewAndClaimExistingFinalized() public {
        // --- Phase 1: Create a new request (proves request flow) ---
        uint256 shares = 2 ether;

        bytes memory requestData = _encodeRequestRedeemData(ASYNC_REDEEMER, shares, 0, false);

        vm.prank(account);
        requestRedeemHook.preExecute(address(0), account, requestData);

        vm.startPrank(account);
        IERC20(DETH).approve(ASYNC_REDEEMER, shares);
        uint256 newRequestId = IDETHAsyncRedeemer(ASYNC_REDEEMER).requestRedeem(shares, account, 0);
        requestRedeemHook.postExecute(address(0), account, requestData);
        vm.stopPrank();

        assertEq(requestRedeemHook.usedShares(), shares, "Phase 1: usedShares correct");
        assertEq(IAsyncRedeemerAdmin(ASYNC_REDEEMER).ownerOf(newRequestId), account, "Phase 1: NFT minted");

        // --- Phase 2: Claim an existing finalized request (#30) ---
        uint256 requestId = 30;
        address nftOwner = IAsyncRedeemerAdmin(ASYNC_REDEEMER).ownerOf(requestId);
        _whitelistAccount(nftOwner);

        ClaimAssetsDETHHook claimHook2 = new ClaimAssetsDETHHook();
        bytes memory claimData = _encodeClaimData(ASYNC_REDEEMER, requestId, false);

        vm.prank(nftOwner);
        claimHook2.preExecute(address(0), nftOwner, claimData);

        vm.prank(nftOwner);
        uint256 wethReceived = IDETHAsyncRedeemer(ASYNC_REDEEMER).claimAssets(requestId);

        vm.prank(nftOwner);
        claimHook2.postExecute(address(0), nftOwner, claimData);

        assertGt(wethReceived, 0, "Phase 2: Must receive WETH");
        assertEq(claimHook2.getOutAmount(nftOwner), wethReceived, "Phase 2: outAmount matches");
        assertEq(claimHook2.asset(), WETH, "Phase 2: asset is WETH");
        assertEq(claimHook2.spToken(), DETH, "Phase 2: spToken is DETH share token");
        assertEq(claimHook2.usedShares(), 0, "Phase 2: usedShares intentionally 0");

        // Verify NFT burned
        vm.expectRevert();
        IAsyncRedeemerAdmin(ASYNC_REDEEMER).ownerOf(requestId);

        console2.log("E2E: new requestId =", newRequestId, " | claimed WETH =", wethReceived);
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
}
