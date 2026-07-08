// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { ERC4626YieldSourceOracle } from "../../../src/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { ApproveAndDeposit4626VaultHook } from "../../../src/hooks/vaults/4626/ApproveAndDeposit4626VaultHook.sol";
import { Deposit4626VaultHook } from "../../../src/hooks/vaults/4626/Deposit4626VaultHook.sol";
import { Redeem4626VaultHook } from "../../../src/hooks/vaults/4626/Redeem4626VaultHook.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookResultOutflow,
    ISuperHookInflowOutflow,
    ISuperHookContextAware,
    ISuperHookOutflow
} from "../../../src/interfaces/ISuperHook.sol";

/*//////////////////////////////////////////////////////////////
                    HOOK EXECUTOR HELPER
//////////////////////////////////////////////////////////////*/

/// @title HookExecutor
/// @notice Minimal contract that acts as both executor and account for hook lifecycle testing.
///         Flow: setExecutionContext -> build -> execute each Execution -> resetExecutionState -> getOutAmount
contract HookExecutor {
    error EXECUTION_FAILED(uint256 index, bytes returnData);

    function executeHook(
        address hook,
        address prevHook,
        bytes calldata data
    )
        external
        returns (uint256 outAmount)
    {
        ISuperHook(hook).setExecutionContext(address(this));
        Execution[] memory execs = ISuperHook(hook).build(prevHook, address(this), data);

        for (uint256 i; i < execs.length; ++i) {
            (bool ok, bytes memory ret) = execs[i].target.call{ value: execs[i].value }(execs[i].callData);
            if (!ok) revert EXECUTION_FAILED(i, ret);
        }

        ISuperHook(hook).resetExecutionState(address(this));
        outAmount = ISuperHookResult(hook).getOutAmount(address(this));
    }
}

/*//////////////////////////////////////////////////////////////
                    TEST CONTRACT
//////////////////////////////////////////////////////////////*/

/// @title EulerVaultFork
/// @notice Comprehensive integration tests for ERC4626YieldSourceOracle and all ERC-4626 hooks
///         against real Euler V2 vaults on Ethereum mainnet.
contract EulerVaultFork is Test {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // Euler Prime USDC vault (6 decimals)
    address public constant EULER_USDC_VAULT = 0x797DD80692c3b2dAdabCe8e30C07fDE5307D48a9;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // MEV Capital Euler WETH vault (18 decimals)
    address public constant EULER_WETH_VAULT = 0xe2D6A2a16ff6d3bbc4C90736A7e6F7Cc3C9B8fa9;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint256 public constant ETH_BLOCK = 21_929_476;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    ERC4626YieldSourceOracle public oracle;
    ApproveAndDeposit4626VaultHook public depositHook;
    Deposit4626VaultHook public depositNoApproveHook;
    Redeem4626VaultHook public redeemHook;
    HookExecutor public executor;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"), ETH_BLOCK);

        SuperLedgerConfiguration ledgerConfig = new SuperLedgerConfiguration();
        oracle = new ERC4626YieldSourceOracle(address(ledgerConfig));
        depositHook = new ApproveAndDeposit4626VaultHook();
        depositNoApproveHook = new Deposit4626VaultHook();
        redeemHook = new Redeem4626VaultHook();
        executor = new HookExecutor();

        // Sanity: verify both vaults respond to ERC-4626 calls at fork block
        assertGt(IERC4626(EULER_USDC_VAULT).totalAssets(), 0, "USDC vault should have assets at fork block");
        assertGt(IERC4626(EULER_WETH_VAULT).totalAssets(), 0, "WETH vault should have assets at fork block");
    }

    /*//////////////////////////////////////////////////////////////
            SECTION 1: ORACLE TESTS — EULER USDC VAULT
    //////////////////////////////////////////////////////////////*/

    function test_fork_eulerUSDC_pps_nonZero() public view {
        uint256 pps = oracle.getPricePerShare(EULER_USDC_VAULT);
        assertGt(pps, 0, "PPS should be > 0");
        console2.log("[eulerUSDC] PPS:", pps);
    }

    function test_fork_eulerUSDC_pps_matchesVault() public view {
        uint256 oraclePPS = oracle.getPricePerShare(EULER_USDC_VAULT);
        uint256 vaultPPS = IERC4626(EULER_USDC_VAULT).convertToAssets(10 ** IERC4626(EULER_USDC_VAULT).decimals());
        assertEq(oraclePPS, vaultPPS, "Oracle PPS must match vault convertToAssets(10^decimals)");
    }

    function test_fork_eulerUSDC_decimals() public view {
        uint8 oracleDecimals = oracle.decimals(EULER_USDC_VAULT);
        uint8 vaultDecimals = IERC4626(EULER_USDC_VAULT).decimals();
        assertEq(oracleDecimals, vaultDecimals, "Oracle decimals must match vault decimals");
        assertEq(oracleDecimals, 6, "USDC vault should have 6 decimals");
    }

    function test_fork_eulerUSDC_tvl_nonZero() public view {
        uint256 tvl = oracle.getTVL(EULER_USDC_VAULT);
        uint256 totalAssets = IERC4626(EULER_USDC_VAULT).totalAssets();
        assertGt(tvl, 0, "TVL should be > 0");
        assertEq(tvl, totalAssets, "Oracle TVL must match vault totalAssets");
        console2.log("[eulerUSDC] TVL:", tvl);
    }

    function test_fork_eulerUSDC_conversions_consistent() public view {
        IERC4626 vault = IERC4626(EULER_USDC_VAULT);
        uint256 oneShare = 10 ** vault.decimals();

        // getAssetOutput(1 share) == getPricePerShare
        uint256 assetOut = oracle.getAssetOutput(EULER_USDC_VAULT, address(0), oneShare);
        uint256 pps = oracle.getPricePerShare(EULER_USDC_VAULT);
        assertEq(assetOut, pps, "getAssetOutput(1 share) should equal PPS");

        // getShareOutput matches previewDeposit
        uint256 depositAmount = 1_000e6; // 1000 USDC
        uint256 oracleShares = oracle.getShareOutput(EULER_USDC_VAULT, address(0), depositAmount);
        uint256 vaultShares = vault.previewDeposit(depositAmount);
        assertEq(oracleShares, vaultShares, "getShareOutput must match previewDeposit");
    }

    function test_fork_eulerUSDC_roundTrip_noValueCreation() public view {
        uint256 assets = 1_000e6;
        uint256 shares = oracle.getShareOutput(EULER_USDC_VAULT, address(0), assets);
        uint256 assetsBack = oracle.getAssetOutput(EULER_USDC_VAULT, address(0), shares);
        assertLe(assetsBack, assets, "Round-trip should not create value (floor rounding)");
    }

    /*//////////////////////////////////////////////////////////////
            SECTION 2: ORACLE TESTS — EULER WETH VAULT
    //////////////////////////////////////////////////////////////*/

    function test_fork_eulerWETH_pps_nonZero() public view {
        uint256 pps = oracle.getPricePerShare(EULER_WETH_VAULT);
        assertGt(pps, 0, "PPS should be > 0");
        console2.log("[eulerWETH] PPS:", pps);
    }

    function test_fork_eulerWETH_pps_matchesVault() public view {
        uint256 oraclePPS = oracle.getPricePerShare(EULER_WETH_VAULT);
        uint256 vaultPPS = IERC4626(EULER_WETH_VAULT).convertToAssets(10 ** IERC4626(EULER_WETH_VAULT).decimals());
        assertEq(oraclePPS, vaultPPS, "Oracle PPS must match vault convertToAssets(10^decimals)");
    }

    function test_fork_eulerWETH_decimals() public view {
        uint8 oracleDecimals = oracle.decimals(EULER_WETH_VAULT);
        uint8 vaultDecimals = IERC4626(EULER_WETH_VAULT).decimals();
        assertEq(oracleDecimals, vaultDecimals, "Oracle decimals must match vault decimals");
        assertEq(oracleDecimals, 18, "WETH vault should have 18 decimals");
    }

    function test_fork_eulerWETH_tvl_nonZero() public view {
        uint256 tvl = oracle.getTVL(EULER_WETH_VAULT);
        uint256 totalAssets = IERC4626(EULER_WETH_VAULT).totalAssets();
        assertGt(tvl, 0, "TVL should be > 0");
        assertEq(tvl, totalAssets, "Oracle TVL must match vault totalAssets");
        console2.log("[eulerWETH] TVL:", tvl);
    }

    function test_fork_eulerWETH_conversions_consistent() public view {
        IERC4626 vault = IERC4626(EULER_WETH_VAULT);
        uint256 oneShare = 10 ** vault.decimals();

        // getAssetOutput(1 share) == getPricePerShare
        uint256 assetOut = oracle.getAssetOutput(EULER_WETH_VAULT, address(0), oneShare);
        uint256 pps = oracle.getPricePerShare(EULER_WETH_VAULT);
        assertEq(assetOut, pps, "getAssetOutput(1 share) should equal PPS");

        // getShareOutput matches previewDeposit
        uint256 depositAmount = 10 ether; // 10 WETH
        uint256 oracleShares = oracle.getShareOutput(EULER_WETH_VAULT, address(0), depositAmount);
        uint256 vaultShares = vault.previewDeposit(depositAmount);
        assertEq(oracleShares, vaultShares, "getShareOutput must match previewDeposit");
    }

    function test_fork_eulerWETH_roundTrip_noValueCreation() public view {
        uint256 assets = 10 ether;
        uint256 shares = oracle.getShareOutput(EULER_WETH_VAULT, address(0), assets);
        uint256 assetsBack = oracle.getAssetOutput(EULER_WETH_VAULT, address(0), shares);
        assertLe(assetsBack, assets, "Round-trip should not create value (floor rounding)");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 3: ORACLE — MULTI-SCALE CONVERSIONS (BOTH VAULTS)
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify oracle matches vault at multiple scale points for USDC vault
    function test_fork_eulerUSDC_multiScale_conversions() public view {
        _assertMultiScaleConversions(EULER_USDC_VAULT, 6);
    }

    /// @notice Verify oracle matches vault at multiple scale points for WETH vault
    function test_fork_eulerWETH_multiScale_conversions() public view {
        _assertMultiScaleConversions(EULER_WETH_VAULT, 18);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 4: ORACLE — WITHDRAWAL SHARE OUTPUT (CEIL ROUNDING)
    //////////////////////////////////////////////////////////////*/

    /// @notice getWithdrawalShareOutput (ceil) >= getShareOutput (floor) for USDC vault
    function test_fork_eulerUSDC_withdrawalShareOutput_ceilProperty() public view {
        _assertCeilRounding(EULER_USDC_VAULT, 6);
    }

    /// @notice getWithdrawalShareOutput (ceil) >= getShareOutput (floor) for WETH vault
    function test_fork_eulerWETH_withdrawalShareOutput_ceilProperty() public view {
        _assertCeilRounding(EULER_WETH_VAULT, 18);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 5: ORACLE — BALANCE & TVL BY OWNER
    //////////////////////////////////////////////////////////////*/

    /// @notice getBalanceOfOwner matches vault.balanceOf after deposit
    function test_fork_eulerUSDC_balanceOfOwner() public {
        deal(USDC, address(executor), 1_000e6);
        executor.executeHook(address(depositHook), address(0), _buildDepositData(EULER_USDC_VAULT, USDC, 1_000e6));

        uint256 oracleBalance = oracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        uint256 vaultBalance = IERC4626(EULER_USDC_VAULT).balanceOf(address(executor));
        assertEq(oracleBalance, vaultBalance, "getBalanceOfOwner must match vault.balanceOf");
        assertGt(oracleBalance, 0, "Should have non-zero balance");
    }

    /// @notice getBalanceOfOwner returns 0 for unknown address
    function test_fork_euler_balanceOfOwner_unknownAddress() public view {
        assertEq(oracle.getBalanceOfOwner(EULER_USDC_VAULT, address(0xdead)), 0, "Unknown addr USDC balance should be 0");
        assertEq(oracle.getBalanceOfOwner(EULER_WETH_VAULT, address(0xdead)), 0, "Unknown addr WETH balance should be 0");
    }

    /// @notice getTVLByOwnerOfShares matches convertToAssets(balanceOf) after deposit
    function test_fork_eulerUSDC_tvlByOwner_afterDeposit() public {
        deal(USDC, address(executor), 5_000e6);
        executor.executeHook(address(depositHook), address(0), _buildDepositData(EULER_USDC_VAULT, USDC, 5_000e6));

        uint256 oracleTVL = oracle.getTVLByOwnerOfShares(EULER_USDC_VAULT, address(executor));
        uint256 shares = IERC4626(EULER_USDC_VAULT).balanceOf(address(executor));
        uint256 expectedTVL = IERC4626(EULER_USDC_VAULT).convertToAssets(shares);

        assertEq(oracleTVL, expectedTVL, "getTVLByOwnerOfShares must match convertToAssets(balanceOf)");
        assertGt(oracleTVL, 0, "Owner TVL should be > 0");
    }

    /// @notice getTVLByOwnerOfShares returns 0 for unknown address
    function test_fork_euler_tvlByOwner_unknownAddress() public view {
        assertEq(oracle.getTVLByOwnerOfShares(EULER_USDC_VAULT, address(0xdead)), 0, "Unknown addr USDC TVL should be 0");
        assertEq(oracle.getTVLByOwnerOfShares(EULER_WETH_VAULT, address(0xdead)), 0, "Unknown addr WETH TVL should be 0");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 6: ORACLE — ZERO & EDGE INPUTS
    //////////////////////////////////////////////////////////////*/

    function test_fork_euler_zeroInputs() public view {
        // USDC vault
        assertEq(oracle.getShareOutput(EULER_USDC_VAULT, address(0), 0), 0, "getShareOutput(0) should be 0");
        assertEq(oracle.getAssetOutput(EULER_USDC_VAULT, address(0), 0), 0, "getAssetOutput(0) should be 0");
        assertEq(
            oracle.getWithdrawalShareOutput(EULER_USDC_VAULT, address(0), 0), 0, "getWithdrawalShareOutput(0) should be 0"
        );

        // WETH vault
        assertEq(oracle.getShareOutput(EULER_WETH_VAULT, address(0), 0), 0, "getShareOutput(0) should be 0");
        assertEq(oracle.getAssetOutput(EULER_WETH_VAULT, address(0), 0), 0, "getAssetOutput(0) should be 0");
        assertEq(
            oracle.getWithdrawalShareOutput(EULER_WETH_VAULT, address(0), 0), 0, "getWithdrawalShareOutput(0) should be 0"
        );
    }

    function test_fork_euler_singleWei() public view {
        // 1 wei should produce a sensible result (not revert, and follow rounding rules)
        uint256 sharesFromOneWei = oracle.getShareOutput(EULER_USDC_VAULT, address(0), 1);
        uint256 assetsFromOneWei = oracle.getAssetOutput(EULER_USDC_VAULT, address(0), 1);
        // May be 0 due to floor rounding at small scale — that's fine
        assertLe(sharesFromOneWei, 1, "1 wei should produce <= 1 share");

        uint256 wethSharesFromOneWei = oracle.getShareOutput(EULER_WETH_VAULT, address(0), 1);
        uint256 wethAssetsFromOneWei = oracle.getAssetOutput(EULER_WETH_VAULT, address(0), 1);
        // Just verify no revert
        console2.log("[edge] USDC: 1 wei -> shares:", sharesFromOneWei, "assets:", assetsFromOneWei);
        console2.log("[edge] WETH: 1 wei -> shares:", wethSharesFromOneWei, "assets:", wethAssetsFromOneWei);
    }

    function test_fork_euler_largeConversion() public view {
        // Large amount: 1M USDC
        uint256 largeAssets = 1_000_000e6;
        uint256 shares = oracle.getShareOutput(EULER_USDC_VAULT, address(0), largeAssets);
        uint256 assetsBack = oracle.getAssetOutput(EULER_USDC_VAULT, address(0), shares);
        assertLe(assetsBack, largeAssets, "Large round-trip: no value creation");
        assertGt(shares, 0, "Large deposit should produce shares");

        // Large amount: 10000 WETH
        uint256 largeWeth = 10_000 ether;
        uint256 wethShares = oracle.getShareOutput(EULER_WETH_VAULT, address(0), largeWeth);
        uint256 wethBack = oracle.getAssetOutput(EULER_WETH_VAULT, address(0), wethShares);
        assertLe(wethBack, largeWeth, "Large WETH round-trip: no value creation");
        assertGt(wethShares, 0, "Large WETH deposit should produce shares");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 7: ORACLE — BATCH METHODS
    //////////////////////////////////////////////////////////////*/

    function test_fork_euler_batchPPS() public view {
        address[] memory vaults = new address[](2);
        vaults[0] = EULER_USDC_VAULT;
        vaults[1] = EULER_WETH_VAULT;

        uint256[] memory prices = oracle.getPricePerShareMultiple(vaults);
        assertEq(prices.length, 2, "Should return 2 prices");
        assertEq(prices[0], oracle.getPricePerShare(EULER_USDC_VAULT), "Batch PPS[0] mismatch");
        assertEq(prices[1], oracle.getPricePerShare(EULER_WETH_VAULT), "Batch PPS[1] mismatch");
    }

    function test_fork_euler_batchTVL() public view {
        address[] memory vaults = new address[](2);
        vaults[0] = EULER_USDC_VAULT;
        vaults[1] = EULER_WETH_VAULT;

        uint256[] memory tvls = oracle.getTVLMultiple(vaults);
        assertEq(tvls.length, 2, "Should return 2 TVLs");
        assertEq(tvls[0], oracle.getTVL(EULER_USDC_VAULT), "Batch TVL[0] mismatch");
        assertEq(tvls[1], oracle.getTVL(EULER_WETH_VAULT), "Batch TVL[1] mismatch");
    }

    function test_fork_euler_batchTVLByOwner() public {
        // Deposit into USDC vault so executor has shares
        deal(USDC, address(executor), 1_000e6);
        executor.executeHook(address(depositHook), address(0), _buildDepositData(EULER_USDC_VAULT, USDC, 1_000e6));

        address[] memory vaults = new address[](2);
        vaults[0] = EULER_USDC_VAULT;
        vaults[1] = EULER_WETH_VAULT;

        address[][] memory owners = new address[][](2);
        owners[0] = new address[](2);
        owners[0][0] = address(executor);
        owners[0][1] = address(0xdead);
        owners[1] = new address[](1);
        owners[1][0] = address(0xdead);

        uint256[][] memory tvls = oracle.getTVLByOwnerOfSharesMultiple(vaults, owners);
        assertEq(tvls[0][0], oracle.getTVLByOwnerOfShares(EULER_USDC_VAULT, address(executor)), "Batch owner TVL mismatch");
        assertEq(tvls[0][1], 0, "Dead addr should have 0 TVL");
        assertEq(tvls[1][0], 0, "Dead addr in WETH vault should have 0 TVL");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 8: ORACLE — PPS STABILITY AFTER OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice PPS should not change after a proportional deposit
    function test_fork_eulerUSDC_pps_stableAfterDeposit() public {
        uint256 ppsBefore = oracle.getPricePerShare(EULER_USDC_VAULT);

        deal(USDC, address(executor), 10_000e6);
        executor.executeHook(address(depositHook), address(0), _buildDepositData(EULER_USDC_VAULT, USDC, 10_000e6));

        uint256 ppsAfter = oracle.getPricePerShare(EULER_USDC_VAULT);
        uint256 vaultPPS = IERC4626(EULER_USDC_VAULT).convertToAssets(10 ** IERC4626(EULER_USDC_VAULT).decimals());

        assertEq(ppsAfter, vaultPPS, "Oracle PPS must still match vault after deposit");
        assertApproxEqAbs(ppsAfter, ppsBefore, 1, "PPS should not change after proportional deposit");
    }

    /// @notice PPS should not change after a redeem
    function test_fork_eulerUSDC_pps_stableAfterRedeem() public {
        // Deposit first
        deal(USDC, address(executor), 10_000e6);
        executor.executeHook(address(depositHook), address(0), _buildDepositData(EULER_USDC_VAULT, USDC, 10_000e6));

        uint256 ppsBefore = oracle.getPricePerShare(EULER_USDC_VAULT);

        // Redeem half
        uint256 shares = IERC4626(EULER_USDC_VAULT).balanceOf(address(executor));
        executor.executeHook(
            address(redeemHook), address(0), _buildRedeemData(EULER_USDC_VAULT, address(executor), shares / 2)
        );

        uint256 ppsAfter = oracle.getPricePerShare(EULER_USDC_VAULT);
        uint256 vaultPPS = IERC4626(EULER_USDC_VAULT).convertToAssets(10 ** IERC4626(EULER_USDC_VAULT).decimals());

        assertEq(ppsAfter, vaultPPS, "Oracle PPS must still match vault after redeem");
        assertApproxEqAbs(ppsAfter, ppsBefore, 1, "PPS should not change after redeem");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 9: ORACLE — PPS * totalSupply ≈ totalAssets
    //////////////////////////////////////////////////////////////*/

    function test_fork_eulerUSDC_pps_totalAssets_relationship() public view {
        _assertPPSTotalAssetsRelationship(EULER_USDC_VAULT);
    }

    function test_fork_eulerWETH_pps_totalAssets_relationship() public view {
        _assertPPSTotalAssetsRelationship(EULER_WETH_VAULT);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 10: ORACLE — CROSS-VALIDATION ALL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function test_fork_eulerUSDC_crossValidation_allFunctions() public view {
        IERC4626 vault = IERC4626(EULER_USDC_VAULT);
        assertEq(oracle.decimals(EULER_USDC_VAULT), vault.decimals(), "decimals");
        assertEq(oracle.getPricePerShare(EULER_USDC_VAULT), vault.convertToAssets(1e6), "PPS");
        assertEq(oracle.getShareOutput(EULER_USDC_VAULT, address(0), 1e6), vault.previewDeposit(1e6), "getShareOutput");
        assertEq(oracle.getAssetOutput(EULER_USDC_VAULT, address(0), 1e6), vault.previewRedeem(1e6), "getAssetOutput");
        assertEq(oracle.getTVL(EULER_USDC_VAULT), vault.totalAssets(), "getTVL");
        assertEq(
            oracle.getWithdrawalShareOutput(EULER_USDC_VAULT, address(0), 1e6),
            vault.previewWithdraw(1e6),
            "getWithdrawalShareOutput"
        );
    }

    function test_fork_eulerWETH_crossValidation_allFunctions() public view {
        IERC4626 vault = IERC4626(EULER_WETH_VAULT);
        assertEq(oracle.decimals(EULER_WETH_VAULT), vault.decimals(), "decimals");
        assertEq(oracle.getPricePerShare(EULER_WETH_VAULT), vault.convertToAssets(1 ether), "PPS");
        assertEq(
            oracle.getShareOutput(EULER_WETH_VAULT, address(0), 1 ether), vault.previewDeposit(1 ether), "getShareOutput"
        );
        assertEq(
            oracle.getAssetOutput(EULER_WETH_VAULT, address(0), 1 ether), vault.previewRedeem(1 ether), "getAssetOutput"
        );
        assertEq(oracle.getTVL(EULER_WETH_VAULT), vault.totalAssets(), "getTVL");
        assertEq(
            oracle.getWithdrawalShareOutput(EULER_WETH_VAULT, address(0), 1 ether),
            vault.previewWithdraw(1 ether),
            "getWithdrawalShareOutput"
        );
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 11: ORACLE — UNDERLYING ASSET VERIFICATION
    //////////////////////////////////////////////////////////////*/

    function test_fork_eulerUSDC_asset() public view {
        assertEq(IERC4626(EULER_USDC_VAULT).asset(), USDC, "USDC vault underlying asset should be USDC");
    }

    function test_fork_eulerWETH_asset() public view {
        assertEq(IERC4626(EULER_WETH_VAULT).asset(), WETH, "WETH vault underlying asset should be WETH");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 12: HOOK LIFECYCLE — EULER USDC VAULT
    //////////////////////////////////////////////////////////////*/

    function test_fork_eulerUSDC_deposit_hook_lifecycle() public {
        uint256 depositAmount = 1_000e6; // 1000 USDC
        deal(USDC, address(executor), depositAmount);

        bytes memory hookData = _buildDepositData(EULER_USDC_VAULT, USDC, depositAmount);
        uint256 outAmount = executor.executeHook(address(depositHook), address(0), hookData);

        // Verify shares received
        uint256 shares = IERC4626(EULER_USDC_VAULT).balanceOf(address(executor));
        assertGt(shares, 0, "Executor should have received vault shares");
        assertEq(outAmount, shares, "outAmount should equal shares received");

        // Verify USDC spent
        assertEq(IERC20(USDC).balanceOf(address(executor)), 0, "All USDC should be deposited");

        console2.log("[eulerUSDC deposit] Amount:", depositAmount, "Shares:", shares);
    }

    function test_fork_eulerUSDC_redeem_hook_lifecycle() public {
        // First deposit to get shares
        uint256 depositAmount = 1_000e6;
        deal(USDC, address(executor), depositAmount);
        bytes memory depositData = _buildDepositData(EULER_USDC_VAULT, USDC, depositAmount);
        executor.executeHook(address(depositHook), address(0), depositData);

        uint256 sharesBefore = IERC4626(EULER_USDC_VAULT).balanceOf(address(executor));
        assertGt(sharesBefore, 0, "Should have shares from deposit");

        // Now redeem all shares
        bytes memory redeemData = _buildRedeemData(EULER_USDC_VAULT, address(executor), sharesBefore);
        uint256 outAmount = executor.executeHook(address(redeemHook), address(0), redeemData);

        // Verify assets returned
        uint256 assetsReturned = IERC20(USDC).balanceOf(address(executor));
        assertGt(assetsReturned, 0, "Should have received USDC back");
        assertEq(outAmount, assetsReturned, "outAmount should equal assets received");

        // Verify shares burned
        assertEq(IERC4626(EULER_USDC_VAULT).balanceOf(address(executor)), 0, "All shares should be redeemed");

        // Round-trip: should get back approximately what was deposited (minus rounding)
        assertLe(assetsReturned, depositAmount, "Should not gain value on round-trip");
        assertGe(assetsReturned, depositAmount - 2, "Should lose at most rounding on round-trip");

        console2.log("[eulerUSDC redeem] Shares:", sharesBefore, "Assets returned:", assetsReturned);
    }

    function test_fork_eulerUSDC_deposit_hook_inspect() public view {
        uint256 amount = 1_000e6;
        bytes memory hookData = _buildDepositData(EULER_USDC_VAULT, USDC, amount);

        bytes memory inspected = depositHook.inspect(hookData);
        // inspect() returns abi.encodePacked(yieldSource, token)
        assertEq(inspected.length, 40, "inspect should return 40 bytes (2 addresses packed)");
        (address decodedYieldSource, address decodedToken) = _decodePackedAddresses(inspected);
        assertEq(decodedYieldSource, EULER_USDC_VAULT, "inspect yieldSource mismatch");
        assertEq(decodedToken, USDC, "inspect token mismatch");
    }

    function test_fork_eulerUSDC_redeem_hook_inspect() public view {
        uint256 shares = 1_000e6;
        bytes memory hookData = _buildRedeemData(EULER_USDC_VAULT, address(executor), shares);

        bytes memory inspected = redeemHook.inspect(hookData);
        // inspect() returns abi.encodePacked(yieldSource, owner)
        assertEq(inspected.length, 40, "inspect should return 40 bytes (2 addresses packed)");
        (address decodedYieldSource, address decodedOwner) = _decodePackedAddresses(inspected);
        assertEq(decodedYieldSource, EULER_USDC_VAULT, "inspect yieldSource mismatch");
        assertEq(decodedOwner, address(executor), "inspect owner mismatch");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 13: HOOK LIFECYCLE — EULER WETH VAULT
    //////////////////////////////////////////////////////////////*/

    function test_fork_eulerWETH_deposit_hook_lifecycle() public {
        uint256 depositAmount = 10 ether; // 10 WETH
        deal(WETH, address(executor), depositAmount);

        bytes memory hookData = _buildDepositData(EULER_WETH_VAULT, WETH, depositAmount);
        uint256 outAmount = executor.executeHook(address(depositHook), address(0), hookData);

        // Verify shares received
        uint256 shares = IERC4626(EULER_WETH_VAULT).balanceOf(address(executor));
        assertGt(shares, 0, "Executor should have received vault shares");
        assertEq(outAmount, shares, "outAmount should equal shares received");

        // Verify WETH spent
        assertEq(IERC20(WETH).balanceOf(address(executor)), 0, "All WETH should be deposited");

        console2.log("[eulerWETH deposit] Amount:", depositAmount, "Shares:", shares);
    }

    function test_fork_eulerWETH_redeem_hook_lifecycle() public {
        // First deposit to get shares
        uint256 depositAmount = 10 ether;
        deal(WETH, address(executor), depositAmount);
        bytes memory depositData = _buildDepositData(EULER_WETH_VAULT, WETH, depositAmount);
        executor.executeHook(address(depositHook), address(0), depositData);

        uint256 sharesBefore = IERC4626(EULER_WETH_VAULT).balanceOf(address(executor));
        assertGt(sharesBefore, 0, "Should have shares from deposit");

        // Now redeem all shares
        bytes memory redeemData = _buildRedeemData(EULER_WETH_VAULT, address(executor), sharesBefore);
        uint256 outAmount = executor.executeHook(address(redeemHook), address(0), redeemData);

        // Verify assets returned
        uint256 assetsReturned = IERC20(WETH).balanceOf(address(executor));
        assertGt(assetsReturned, 0, "Should have received WETH back");
        assertEq(outAmount, assetsReturned, "outAmount should equal assets received");

        // Verify shares burned
        assertEq(IERC4626(EULER_WETH_VAULT).balanceOf(address(executor)), 0, "All shares should be redeemed");

        // Round-trip: should get back approximately what was deposited (minus rounding)
        assertLe(assetsReturned, depositAmount, "Should not gain value on round-trip");
        assertGe(assetsReturned, depositAmount - 2, "Should lose at most rounding on round-trip");

        console2.log("[eulerWETH redeem] Shares:", sharesBefore, "Assets returned:", assetsReturned);
    }

    function test_fork_eulerWETH_deposit_hook_inspect() public view {
        uint256 amount = 10 ether;
        bytes memory hookData = _buildDepositData(EULER_WETH_VAULT, WETH, amount);

        bytes memory inspected = depositHook.inspect(hookData);
        assertEq(inspected.length, 40, "inspect should return 40 bytes (2 addresses packed)");
        (address decodedYieldSource, address decodedToken) = _decodePackedAddresses(inspected);
        assertEq(decodedYieldSource, EULER_WETH_VAULT, "inspect yieldSource mismatch");
        assertEq(decodedToken, WETH, "inspect token mismatch");
    }

    function test_fork_eulerWETH_redeem_hook_inspect() public view {
        uint256 shares = 10 ether;
        bytes memory hookData = _buildRedeemData(EULER_WETH_VAULT, address(executor), shares);

        bytes memory inspected = redeemHook.inspect(hookData);
        assertEq(inspected.length, 40, "inspect should return 40 bytes (2 addresses packed)");
        (address decodedYieldSource, address decodedOwner) = _decodePackedAddresses(inspected);
        assertEq(decodedYieldSource, EULER_WETH_VAULT, "inspect yieldSource mismatch");
        assertEq(decodedOwner, address(executor), "inspect owner mismatch");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 14: HOOK DATA ENCODING — decodeAmount, decodeUsePrevHookAmount
    //////////////////////////////////////////////////////////////*/

    function test_fork_euler_depositHook_decodeAmount() public view {
        uint256 amount = 42_000e6;
        bytes memory hookData = _buildDepositData(EULER_USDC_VAULT, USDC, amount);
        uint256[] memory decoded = ISuperHookInflowOutflow(address(depositHook)).decodeAmounts(hookData);
        assertEq(decoded[0], amount, "decodeAmounts should return the encoded amount");
    }

    function test_fork_euler_depositHook_decodeUsePrevHookAmount() public view {
        bytes memory hookDataFalse = _buildDepositData(EULER_USDC_VAULT, USDC, 1e6);
        assertFalse(
            ISuperHookContextAware(address(depositHook)).decodeUsePrevHookAmount(hookDataFalse),
            "usePrevHookAmount should be false"
        );

        // Build data with usePrevHookAmount = true
        bytes32 yieldSourceOracleId = keccak256("ERC4626YieldSourceOracle");
        bytes memory hookDataTrue = abi.encodePacked(yieldSourceOracleId, EULER_USDC_VAULT, USDC, uint256(1e6), uint8(1));
        assertTrue(
            ISuperHookContextAware(address(depositHook)).decodeUsePrevHookAmount(hookDataTrue),
            "usePrevHookAmount should be true"
        );
    }

    function test_fork_euler_redeemHook_decodeAmount() public view {
        uint256 shares = 99_000e6;
        bytes memory hookData = _buildRedeemData(EULER_USDC_VAULT, address(executor), shares);
        uint256[] memory decoded = ISuperHookInflowOutflow(address(redeemHook)).decodeAmounts(hookData);
        assertEq(decoded[0], shares, "decodeAmounts should return the encoded shares");
    }

    function test_fork_euler_redeemHook_replaceCalldataAmount() public view {
        uint256 originalShares = 100e6;
        uint256 newShares = 200e6;
        bytes memory hookData = _buildRedeemData(EULER_USDC_VAULT, address(executor), originalShares);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = newShares;
        bytes memory replaced = ISuperHookOutflow(address(redeemHook)).replaceCalldataAmounts(hookData, amounts);
        uint256[] memory decoded = ISuperHookInflowOutflow(address(redeemHook)).decodeAmounts(replaced);
        assertEq(decoded[0], newShares, "replaceCalldataAmounts should update the amount");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 15: HOOK TYPE & SUBTYPE
    //////////////////////////////////////////////////////////////*/

    function test_fork_euler_hookTypes() public view {
        assertEq(uint256(depositHook.hookType()), uint256(ISuperHook.HookType.INFLOW), "Deposit hook should be INFLOW");
        assertEq(
            uint256(depositNoApproveHook.hookType()),
            uint256(ISuperHook.HookType.INFLOW),
            "DepositNoApprove hook should be INFLOW"
        );
        assertEq(uint256(redeemHook.hookType()), uint256(ISuperHook.HookType.OUTFLOW), "Redeem hook should be OUTFLOW");
    }

    function test_fork_euler_hookSubtypes() public view {
        // All 4626 hooks share the same subtype
        assertEq(depositHook.SUB_TYPE(), depositNoApproveHook.SUB_TYPE(), "Subtypes should match across 4626 hooks");
        assertEq(depositHook.SUB_TYPE(), redeemHook.SUB_TYPE(), "Subtypes should match across 4626 hooks");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 16: HOOK BUILD — EXECUTION COUNT VERIFICATION
    //////////////////////////////////////////////////////////////*/

    /// @notice ApproveAndDeposit4626VaultHook.build() returns 6 executions (pre + approve(0) + approve(amt) + deposit + approve(0) + post)
    function test_fork_eulerUSDC_depositHook_buildExecutionCount() public {
        bytes memory hookData = _buildDepositData(EULER_USDC_VAULT, USDC, 1_000e6);
        // Must set execution context first for build to work with the correct account
        depositHook.setExecutionContext(address(this));
        Execution[] memory execs = depositHook.build(address(0), address(this), hookData);
        // pre(1) + approve_zero(1) + approve(1) + deposit(1) + approve_zero(1) + post(1) = 6
        assertEq(execs.length, 6, "ApproveAndDeposit should produce 6 executions");
    }

    /// @notice Redeem4626VaultHook.build() returns 3 executions (pre + redeem + post)
    function test_fork_eulerUSDC_redeemHook_buildExecutionCount() public {
        bytes memory hookData = _buildRedeemData(EULER_USDC_VAULT, address(this), 1_000e6);
        redeemHook.setExecutionContext(address(this));
        Execution[] memory execs = redeemHook.build(address(0), address(this), hookData);
        // pre(1) + redeem(1) + post(1) = 3
        assertEq(execs.length, 3, "Redeem should produce 3 executions");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 17: DEPOSIT4626VAULTHOOK (NO APPROVE VARIANT)
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit4626VaultHook works with pre-approved tokens
    function test_fork_eulerUSDC_depositNoApprove_lifecycle() public {
        uint256 depositAmount = 500e6;
        deal(USDC, address(executor), depositAmount);

        // Pre-approve the vault (simulating a prior approve hook or allowance)
        vm.prank(address(executor));
        IERC20(USDC).approve(EULER_USDC_VAULT, depositAmount);

        // Deposit4626VaultHook has different data layout: bytes32 oracleId | address yieldSource | uint256 amount | bool usePrev
        bytes32 yieldSourceOracleId = keccak256("ERC4626YieldSourceOracle");
        bytes memory hookData = abi.encodePacked(yieldSourceOracleId, EULER_USDC_VAULT, depositAmount, uint8(0));
        uint256 outAmount = executor.executeHook(address(depositNoApproveHook), address(0), hookData);

        uint256 shares = IERC4626(EULER_USDC_VAULT).balanceOf(address(executor));
        assertGt(shares, 0, "Should have received vault shares");
        assertEq(outAmount, shares, "outAmount should equal shares received");
        assertEq(IERC20(USDC).balanceOf(address(executor)), 0, "All USDC should be deposited");

        console2.log("[eulerUSDC depositNoApprove] Amount:", depositAmount, "Shares:", shares);
    }

    /// @notice Deposit4626VaultHook inspect returns only yieldSource (20 bytes)
    function test_fork_eulerUSDC_depositNoApprove_inspect() public view {
        bytes32 yieldSourceOracleId = keccak256("ERC4626YieldSourceOracle");
        bytes memory hookData = abi.encodePacked(yieldSourceOracleId, EULER_USDC_VAULT, uint256(1_000e6), uint8(0));

        bytes memory inspected = depositNoApproveHook.inspect(hookData);
        assertEq(inspected.length, 20, "Deposit4626VaultHook inspect should return 20 bytes (1 address)");
        address decodedYieldSource;
        assembly {
            decodedYieldSource := shr(96, mload(add(inspected, 32)))
        }
        assertEq(decodedYieldSource, EULER_USDC_VAULT, "inspect yieldSource mismatch");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 18: PARTIAL REDEEM — VERIFY PARTIAL WITHDRAWAL
    //////////////////////////////////////////////////////////////*/

    function test_fork_eulerUSDC_partialRedeem() public {
        // Deposit 10000 USDC
        uint256 depositAmount = 10_000e6;
        deal(USDC, address(executor), depositAmount);
        executor.executeHook(address(depositHook), address(0), _buildDepositData(EULER_USDC_VAULT, USDC, depositAmount));

        uint256 totalShares = IERC4626(EULER_USDC_VAULT).balanceOf(address(executor));

        // Redeem 25%
        uint256 redeemShares = totalShares / 4;
        uint256 outAmount =
            executor.executeHook(address(redeemHook), address(0), _buildRedeemData(EULER_USDC_VAULT, address(executor), redeemShares));

        // Should have 75% of shares remaining
        uint256 remainingShares = IERC4626(EULER_USDC_VAULT).balanceOf(address(executor));
        assertEq(remainingShares, totalShares - redeemShares, "Should have 75% shares remaining");

        // outAmount should match USDC received
        uint256 usdcBalance = IERC20(USDC).balanceOf(address(executor));
        assertEq(outAmount, usdcBalance, "outAmount should match USDC balance");
        assertGt(outAmount, 0, "Should have received some USDC");

        console2.log("[partial redeem] Total:", totalShares, "Redeemed:", redeemShares);
        console2.log("[partial redeem] Remaining:", remainingShares);
    }

    function test_fork_eulerWETH_partialRedeem() public {
        // Deposit 10 WETH
        deal(WETH, address(executor), 10 ether);
        executor.executeHook(address(depositHook), address(0), _buildDepositData(EULER_WETH_VAULT, WETH, 10 ether));

        uint256 totalShares = IERC4626(EULER_WETH_VAULT).balanceOf(address(executor));

        // Redeem 50%
        uint256 redeemShares = totalShares / 2;
        uint256 outAmount =
            executor.executeHook(address(redeemHook), address(0), _buildRedeemData(EULER_WETH_VAULT, address(executor), redeemShares));

        uint256 remainingShares = IERC4626(EULER_WETH_VAULT).balanceOf(address(executor));
        assertEq(remainingShares, totalShares - redeemShares, "Should have 50% shares remaining");
        assertEq(outAmount, IERC20(WETH).balanceOf(address(executor)), "outAmount should match WETH balance");
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 19: FULL LIFECYCLE — DEPOSIT → ORACLE CHECK → REDEEM → ORACLE CHECK
    //////////////////////////////////////////////////////////////*/

    function test_fork_eulerUSDC_fullLifecycle_oracleConsistency() public {
        uint256 ppsBefore = oracle.getPricePerShare(EULER_USDC_VAULT);
        uint256 tvlBefore = oracle.getTVL(EULER_USDC_VAULT);

        // Step 1: Deposit
        uint256 depositAmount = 50_000e6;
        deal(USDC, address(executor), depositAmount);
        uint256 depositOut =
            executor.executeHook(address(depositHook), address(0), _buildDepositData(EULER_USDC_VAULT, USDC, depositAmount));

        // Oracle checks post-deposit
        uint256 ppsAfterDeposit = oracle.getPricePerShare(EULER_USDC_VAULT);
        assertApproxEqAbs(ppsAfterDeposit, ppsBefore, 1, "PPS should be stable after deposit");
        assertGt(oracle.getTVL(EULER_USDC_VAULT), tvlBefore, "TVL should increase after deposit");
        assertEq(
            oracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor)),
            depositOut,
            "Oracle balance should match deposit shares"
        );
        uint256 ownerTVL = oracle.getTVLByOwnerOfShares(EULER_USDC_VAULT, address(executor));
        assertGt(ownerTVL, 0, "Owner TVL should be > 0 after deposit");

        // Step 2: Redeem all
        uint256 shares = IERC4626(EULER_USDC_VAULT).balanceOf(address(executor));
        uint256 redeemOut =
            executor.executeHook(address(redeemHook), address(0), _buildRedeemData(EULER_USDC_VAULT, address(executor), shares));

        // Oracle checks post-redeem
        uint256 ppsAfterRedeem = oracle.getPricePerShare(EULER_USDC_VAULT);
        assertApproxEqAbs(ppsAfterRedeem, ppsBefore, 1, "PPS should be stable after redeem");
        assertEq(oracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor)), 0, "Balance should be 0 after full redeem");
        assertEq(
            oracle.getTVLByOwnerOfShares(EULER_USDC_VAULT, address(executor)),
            0,
            "Owner TVL should be 0 after full redeem"
        );

        // Deposit out amount should match oracle's expectation
        uint256 expectedAssets = oracle.getAssetOutput(EULER_USDC_VAULT, address(0), depositOut);
        assertApproxEqAbs(redeemOut, expectedAssets, 1, "Redeem output should match oracle prediction");

        console2.log("[lifecycle] Deposited:", depositAmount, "Shares:", depositOut);
        console2.log("[lifecycle] Redeemed:", redeemOut);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 20: MULTIPLE DEPOSITS — ACCUMULATION
    //////////////////////////////////////////////////////////////*/

    function test_fork_eulerUSDC_multipleDeposits_accumulate() public {
        // Three sequential deposits
        deal(USDC, address(executor), 3_000e6);

        executor.executeHook(address(depositHook), address(0), _buildDepositData(EULER_USDC_VAULT, USDC, 1_000e6));
        uint256 sharesAfter1 = IERC4626(EULER_USDC_VAULT).balanceOf(address(executor));

        // Need to deal more USDC for 2nd deposit since executor already spent it
        deal(USDC, address(executor), 1_000e6);
        executor.executeHook(address(depositHook), address(0), _buildDepositData(EULER_USDC_VAULT, USDC, 1_000e6));
        uint256 sharesAfter2 = IERC4626(EULER_USDC_VAULT).balanceOf(address(executor));

        deal(USDC, address(executor), 1_000e6);
        executor.executeHook(address(depositHook), address(0), _buildDepositData(EULER_USDC_VAULT, USDC, 1_000e6));
        uint256 sharesAfter3 = IERC4626(EULER_USDC_VAULT).balanceOf(address(executor));

        // Shares should monotonically increase
        assertGt(sharesAfter2, sharesAfter1, "Shares should increase after 2nd deposit");
        assertGt(sharesAfter3, sharesAfter2, "Shares should increase after 3rd deposit");

        // Oracle should reflect accumulated position
        uint256 oracleBalance = oracle.getBalanceOfOwner(EULER_USDC_VAULT, address(executor));
        assertEq(oracleBalance, sharesAfter3, "Oracle balance should match total accumulated shares");

        // TVL by owner should reflect value of all deposits
        uint256 ownerTVL = oracle.getTVLByOwnerOfShares(EULER_USDC_VAULT, address(executor));
        uint256 expectedTVL = IERC4626(EULER_USDC_VAULT).convertToAssets(sharesAfter3);
        assertEq(ownerTVL, expectedTVL, "Owner TVL should match accumulated value");

        console2.log("[multi-deposit] Shares after 1/2/3:", sharesAfter1, sharesAfter2, sharesAfter3);
    }

    /*//////////////////////////////////////////////////////////////
        SECTION 21: ORACLE — getAssetOutputWithFees (NO CONFIG = NO FEES)
    //////////////////////////////////////////////////////////////*/

    /// @notice Without fee config, getAssetOutputWithFees should equal getAssetOutput
    function test_fork_eulerUSDC_assetOutputWithFees_noConfig() public view {
        bytes32 oracleId = keccak256("ERC4626YieldSourceOracle");
        uint256 shares = 1_000e6;
        uint256 withFees = oracle.getAssetOutputWithFees(oracleId, EULER_USDC_VAULT, address(0), address(0xBEEF), shares);
        uint256 withoutFees = oracle.getAssetOutput(EULER_USDC_VAULT, address(0), shares);
        assertEq(withFees, withoutFees, "Without config, getAssetOutputWithFees should equal getAssetOutput");
    }

    function test_fork_eulerWETH_assetOutputWithFees_noConfig() public view {
        bytes32 oracleId = keccak256("ERC4626YieldSourceOracle");
        uint256 shares = 1 ether;
        uint256 withFees = oracle.getAssetOutputWithFees(oracleId, EULER_WETH_VAULT, address(0), address(0xBEEF), shares);
        uint256 withoutFees = oracle.getAssetOutput(EULER_WETH_VAULT, address(0), shares);
        assertEq(withFees, withoutFees, "Without config, getAssetOutputWithFees should equal getAssetOutput");
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds hook data for ApproveAndDeposit4626VaultHook
    ///      Layout: bytes32 yieldSourceOracleId | address yieldSource | address token | uint256 amount | bool usePrevHookAmount
    function _buildDepositData(address vault, address token, uint256 amount) internal pure returns (bytes memory) {
        bytes32 yieldSourceOracleId = keccak256("ERC4626YieldSourceOracle");
        return abi.encodePacked(yieldSourceOracleId, vault, token, amount, uint8(0));
    }

    /// @dev Builds hook data for Redeem4626VaultHook
    ///      Layout: bytes32 yieldSourceOracleId | address yieldSource | address owner | uint256 shares | bool usePrevHookAmount
    function _buildRedeemData(address vault, address owner, uint256 shares) internal pure returns (bytes memory) {
        bytes32 yieldSourceOracleId = keccak256("ERC4626YieldSourceOracle");
        return abi.encodePacked(yieldSourceOracleId, vault, owner, shares, uint8(0));
    }

    /// @dev Decode two packed addresses from 40-byte inspect output
    function _decodePackedAddresses(bytes memory data) internal pure returns (address a, address b) {
        require(data.length == 40, "Expected 40 bytes");
        assembly {
            a := shr(96, mload(add(data, 32)))
            b := shr(96, mload(add(data, 52)))
        }
    }

    /// @dev Verify oracle matches vault conversions at multiple scale points
    function _assertMultiScaleConversions(address vault, uint8 dec) internal view {
        uint256[6] memory scales = [uint256(1), 10 ** (dec / 2), 10 ** dec, 1_000 * 10 ** dec, 1_000_000 * 10 ** dec, type(uint64).max];

        for (uint256 i; i < scales.length; i++) {
            assertEq(
                oracle.getShareOutput(vault, address(0), scales[i]),
                IERC4626(vault).previewDeposit(scales[i]),
                string.concat("getShareOutput mismatch @scale ", vm.toString(i))
            );
            assertEq(
                oracle.getAssetOutput(vault, address(0), scales[i]),
                IERC4626(vault).previewRedeem(scales[i]),
                string.concat("getAssetOutput mismatch @scale ", vm.toString(i))
            );
        }
    }

    /// @dev Verify ceil rounding: getWithdrawalShareOutput >= getShareOutput and covers the assets
    function _assertCeilRounding(address vault, uint8 dec) internal view {
        uint256[4] memory amounts = [uint256(1), 10 ** dec, 1_000 * 10 ** dec, 777_777 * 10 ** (dec > 6 ? dec - 6 : 0)];

        for (uint256 i; i < amounts.length; i++) {
            uint256 ceil = oracle.getWithdrawalShareOutput(vault, address(0), amounts[i]);
            uint256 floor = oracle.getShareOutput(vault, address(0), amounts[i]);
            assertGe(ceil, floor, string.concat("ceil < floor @index ", vm.toString(i)));

            // Ceil shares should cover the requested assets (with potential +1 due to rounding)
            if (ceil > 0) {
                uint256 assetsFromCeil = oracle.getAssetOutput(vault, address(0), ceil);
                assertGe(assetsFromCeil, amounts[i], string.concat("ceil doesn't cover assets @index ", vm.toString(i)));
            }
        }
    }

    /// @dev Verify PPS * totalSupply ≈ totalAssets
    function _assertPPSTotalAssetsRelationship(address vault) internal view {
        uint256 totalAssets = IERC4626(vault).totalAssets();
        uint256 totalSupply = IERC20(vault).totalSupply();
        uint256 pps = oracle.getPricePerShare(vault);
        uint8 dec = oracle.decimals(vault);

        uint256 computedTotalAssets = (totalSupply * pps) / (10 ** dec);
        assertApproxEqRel(computedTotalAssets, totalAssets, 0.0001e18, "totalSupply * PPS should approximate totalAssets");
    }
}
