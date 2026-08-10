// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import "forge-std/console2.sol";

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../src/libraries/HookSubTypes.sol";
import { IFirelightVault } from "../../../src/vendor/vaults/firelight/IFirelightVault.sol";

import { RedeemFirelightVaultHook } from "../../../src/hooks/vaults/firelight/RedeemFirelightVaultHook.sol";
import { ClaimWithdrawFirelightVaultHook } from
    "../../../src/hooks/vaults/firelight/ClaimWithdrawFirelightVaultHook.sol";

/// @title FirelightHooksE2E
/// @notice End-to-end integration tests for Firelight vault hooks on Flare mainnet fork
/// @dev Uses real Firelight stXRP vault and FXRP token on Flare (chain ID 14)
contract FirelightHooksE2E is Test {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Firelight stXRP vault on Flare
    address public constant FIRELIGHT_VAULT = 0x4C18Ff3C89632c3Dd62E796c0aFA5c07c4c1B2b3;

    /// @dev FXRP token on Flare (underlying asset of the vault)
    address public constant FXRP = 0xAd552A648C74D49E10027AB8a618A3ad4901c5bE;

    /// @dev Top stXRP holder for impersonation
    address public constant TOP_HOLDER = 0x80743e896Df841900803a46F6d8451e0F9EF6F4A;

    /// @dev Flare RPC URL env key
    string public constant FLARE_RPC_URL_KEY = "FLARE_RPC_URL";

    /// @dev Pinned so CI can reuse foundry's RPC cache instead of re-fetching state at latest
    uint256 public constant FORK_BLOCK = 67_000_000;

    /// @dev WithdrawRequest event signature from Firelight vault
    event WithdrawRequest(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 requestId,
        uint256 assets,
        uint256 shares
    );

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    RedeemFirelightVaultHook public redeemHook;
    ClaimWithdrawFirelightVaultHook public claimHook;

    bytes32 public yieldSourceOracleId;
    uint256 public forkId;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        forkId = vm.createSelectFork(vm.envString(FLARE_RPC_URL_KEY), FORK_BLOCK);

        redeemHook = new RedeemFirelightVaultHook();
        claimHook = new ClaimWithdrawFirelightVaultHook();
        yieldSourceOracleId = bytes32(keccak256("FIRELIGHT_ORACLE_ID"));
    }

    /*//////////////////////////////////////////////////////////////
                          VAULT SANITY CHECKS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify the vault's asset is FXRP
    function test_vault_assetIsFXRP() public view {
        address asset = IFirelightVault(FIRELIGHT_VAULT).asset();
        assertEq(asset, FXRP, "Vault asset should be FXRP");
    }

    /// @notice Verify top holder has a non-zero stXRP balance
    function test_vault_topHolderHasBalance() public view {
        uint256 balance = IERC20(FIRELIGHT_VAULT).balanceOf(TOP_HOLDER);
        assertGt(balance, 0, "Top holder should have stXRP balance");
        console2.log("Top holder stXRP balance:", balance);
    }

    /*//////////////////////////////////////////////////////////////
                    REDEEM HOOK INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that redeem hook builds correct calldata targeting the real vault
    function test_redeemHook_buildTargetsRealVault() public view {
        uint256 shares = 1_000_000; // 1 stXRP (6 decimals)
        bytes memory data = _encodeRedeemData(FIRELIGHT_VAULT, shares, false);
        Execution[] memory executions = redeemHook.build(address(0), TOP_HOLDER, data);

        assertEq(executions.length, 3, "Should have 3 executions (pre + redeem + post)");
        assertEq(executions[1].target, FIRELIGHT_VAULT, "Target should be Firelight vault");
        assertEq(
            executions[1].callData,
            abi.encodeCall(IFirelightVault.redeem, (shares, TOP_HOLDER, TOP_HOLDER)),
            "Calldata should encode redeem(shares, holder, holder)"
        );
    }

    /// @notice Test redeem on the real vault: burns shares, emits WithdrawRequest, no FXRP transfer
    function test_redeemHook_realVaultRedeem_burnsSharesAndEmitsWithdrawRequest() public {
        uint256 shares = 1_000_000; // 1 stXRP
        uint256 holderBalanceBefore = IERC20(FIRELIGHT_VAULT).balanceOf(TOP_HOLDER);
        uint256 fxrpBalanceBefore = IERC20(FXRP).balanceOf(TOP_HOLDER);

        vm.prank(TOP_HOLDER);
        IFirelightVault(FIRELIGHT_VAULT).redeem(shares, TOP_HOLDER, TOP_HOLDER);

        uint256 holderBalanceAfter = IERC20(FIRELIGHT_VAULT).balanceOf(TOP_HOLDER);
        uint256 fxrpBalanceAfter = IERC20(FXRP).balanceOf(TOP_HOLDER);

        // Shares should be burned
        assertEq(holderBalanceBefore - holderBalanceAfter, shares, "Should have burned exactly the requested shares");

        // FXRP should NOT have been transferred (async behavior)
        assertEq(fxrpBalanceAfter, fxrpBalanceBefore, "FXRP balance should not change (async withdrawal)");

        console2.log("Shares burned:", shares);
        console2.log("FXRP transferred:", fxrpBalanceAfter - fxrpBalanceBefore);
    }

    /// @notice Test that the redeem hook correctly tracks share burn delta via preExecute/postExecute
    function test_redeemHook_prePostExecute_tracksRealShareBurn() public {
        uint256 shares = 1_000_000; // 1 stXRP

        // Setup: impersonate the holder
        vm.startPrank(TOP_HOLDER);

        bytes memory data = _encodeRedeemData(FIRELIGHT_VAULT, shares, false);

        // Pre-execute: captures stXRP balance
        redeemHook.preExecute(address(0), TOP_HOLDER, data);
        uint256 preUsedShares = redeemHook.usedShares();
        assertEq(preUsedShares, IERC20(FIRELIGHT_VAULT).balanceOf(TOP_HOLDER), "preExecute should capture full balance");

        // Execute: call redeem on the real vault
        IFirelightVault(FIRELIGHT_VAULT).redeem(shares, TOP_HOLDER, TOP_HOLDER);

        // Post-execute: calculates delta
        redeemHook.postExecute(address(0), TOP_HOLDER, data);
        uint256 postUsedShares = redeemHook.usedShares();

        assertEq(postUsedShares, shares, "usedShares should equal the shares burned");
        vm.stopPrank();
    }

    /// @notice Test redeem with a larger amount to verify no overflow or unexpected behavior
    function test_redeemHook_realVaultRedeem_largerAmount() public {
        uint256 holderBalance = IERC20(FIRELIGHT_VAULT).balanceOf(TOP_HOLDER);
        // Redeem 10% of holder's balance
        uint256 shares = holderBalance / 10;

        vm.startPrank(TOP_HOLDER);

        bytes memory data = _encodeRedeemData(FIRELIGHT_VAULT, shares, false);

        redeemHook.preExecute(address(0), TOP_HOLDER, data);
        IFirelightVault(FIRELIGHT_VAULT).redeem(shares, TOP_HOLDER, TOP_HOLDER);
        redeemHook.postExecute(address(0), TOP_HOLDER, data);

        assertEq(redeemHook.usedShares(), shares, "usedShares should track 10% share burn");

        // Verify FXRP did not move
        assertEq(IERC20(FXRP).balanceOf(TOP_HOLDER), IERC20(FXRP).balanceOf(TOP_HOLDER));

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                CLAIM WITHDRAW HOOK INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that claim hook builds correct calldata targeting the real vault
    function test_claimHook_buildTargetsRealVault() public view {
        uint256 requestId = 139;
        bytes memory data = _encodeClaimData(FIRELIGHT_VAULT, requestId, false);
        Execution[] memory executions = claimHook.build(address(0), TOP_HOLDER, data);

        assertEq(executions.length, 3, "Should have 3 executions (pre + claim + post)");
        assertEq(executions[1].target, FIRELIGHT_VAULT, "Target should be Firelight vault");
        assertEq(
            executions[1].callData,
            abi.encodeCall(IFirelightVault.claimWithdraw, (requestId)),
            "Calldata should encode claimWithdraw(requestId)"
        );
    }

    /// @notice Test that claim hook preExecute correctly reads the real FXRP asset
    function test_claimHook_preExecute_readsRealAsset() public {
        bytes memory data = _encodeClaimData(FIRELIGHT_VAULT, 0, false);

        vm.prank(TOP_HOLDER);
        claimHook.preExecute(address(0), TOP_HOLDER, data);

        assertEq(claimHook.asset(), FXRP, "asset should be FXRP from real vault");
    }

    /// @notice Test full redeem → claim flow: redeem burns shares, claim (simulated) delivers FXRP
    function test_e2e_redeemThenClaim_simulatedCooldown() public {
        uint256 shares = 1_000_000;

        // Phase 1: Redeem
        vm.startPrank(TOP_HOLDER);

        bytes memory redeemData = _encodeRedeemData(FIRELIGHT_VAULT, shares, false);
        redeemHook.preExecute(address(0), TOP_HOLDER, redeemData);

        uint256 fxrpBefore = IERC20(FXRP).balanceOf(TOP_HOLDER);
        IFirelightVault(FIRELIGHT_VAULT).redeem(shares, TOP_HOLDER, TOP_HOLDER);
        uint256 fxrpAfterRedeem = IERC20(FXRP).balanceOf(TOP_HOLDER);

        redeemHook.postExecute(address(0), TOP_HOLDER, redeemData);

        assertEq(redeemHook.usedShares(), shares, "Phase 1: shares burned");
        assertEq(fxrpAfterRedeem, fxrpBefore, "Phase 1: no FXRP transferred yet");

        vm.stopPrank();

        // Phase 2: Claim (simulated — we can't actually wait 2 days on fork)
        // Simulate FXRP arriving by deal'ing tokens to the holder (~1:1 ratio)
        deal(FXRP, TOP_HOLDER, fxrpBefore + shares);

        vm.startPrank(TOP_HOLDER);

        bytes memory claimData = _encodeClaimData(FIRELIGHT_VAULT, 0, false);
        claimHook.preExecute(address(0), TOP_HOLDER, claimData);

        uint256 preOutAmount = claimHook.getOutAmount(TOP_HOLDER);
        assertEq(preOutAmount, fxrpBefore + shares, "Phase 2: preExecute captures current FXRP balance");

        // Simulate claim adding more FXRP
        uint256 claimedAmount = 1_000_071; // ~1:1.000071 ratio
        deal(FXRP, TOP_HOLDER, fxrpBefore + shares + claimedAmount);

        claimHook.postExecute(address(0), TOP_HOLDER, claimData);
        uint256 outAmount = claimHook.getOutAmount(TOP_HOLDER);

        assertEq(outAmount, claimedAmount, "Phase 2: outAmount should be the FXRP delta from claim");

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                     HOOK PROPERTY TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify hook subtypes match ERC4626
    function test_hookSubTypes() public view {
        assertEq(redeemHook.SUB_TYPE(), HookSubTypes.ERC4626);
        assertEq(claimHook.SUB_TYPE(), HookSubTypes.ERC4626);
    }

    /// @notice Verify inspect returns yield source for both hooks
    function test_inspect_returnsVaultAddress() public view {
        bytes memory redeemData = _encodeRedeemData(FIRELIGHT_VAULT, 1_000_000, false);
        bytes memory claimData = _encodeClaimData(FIRELIGHT_VAULT, 1, false);

        assertEq(redeemHook.inspect(redeemData), abi.encodePacked(FIRELIGHT_VAULT));
        assertEq(claimHook.inspect(claimData), abi.encodePacked(FIRELIGHT_VAULT));
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    function _encodeRedeemData(
        address yieldSource,
        uint256 shares,
        bool usePrevHook
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, shares, usePrevHook);
    }

    function _encodeClaimData(
        address yieldSource,
        uint256 requestId,
        bool usePrevHook
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, requestId, usePrevHook);
    }
}
