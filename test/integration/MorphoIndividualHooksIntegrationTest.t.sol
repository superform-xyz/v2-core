// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { MarketParamsLib } from "../../src/vendor/morpho/MarketParamsLib.sol";
import { Id, IMorpho, IMorphoStaticTyping, MarketParams } from "../../src/vendor/morpho/IMorpho.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import "forge-std/console2.sol";

// Superform
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { MinimalBaseIntegrationTest } from "./MinimalBaseIntegrationTest.t.sol";
import { MorphoSupplyHook } from "../../src/hooks/loan/morpho/MorphoSupplyHook.sol";
import { MorphoBorrowHook } from "../../src/hooks/loan/morpho/MorphoBorrowHook.sol";
import { MorphoRepayHook } from "../../src/hooks/loan/morpho/MorphoRepayHook.sol";
import { MorphoWithdrawHook } from "../../src/hooks/loan/morpho/MorphoWithdrawHook.sol";
import { ISuperNativePaymaster } from "../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperNativePaymaster } from "../../src/paymaster/SuperNativePaymaster.sol";

/// @title MorphoIndividualHooksIntegrationTest
/// @notice Integration tests for individual Morpho hooks (Supply, Borrow, Repay) through real ERC-4337 UserOp flow
/// @dev No mocks — uses SuperExecutor, SuperNativePaymaster, real Morpho Blue, real tokens
contract MorphoIndividualHooksIntegrationTest is MinimalBaseIntegrationTest {
    using MarketParamsLib for MarketParams;

    MorphoSupplyHook public supplyHook;
    MorphoBorrowHook public borrowHook;
    MorphoRepayHook public repayHook;
    MorphoWithdrawHook public withdrawHook;
    ISuperNativePaymaster public superNativePaymaster;

    MarketParams public marketParams;
    Id public marketId;

    uint256 public constant COLLATERAL_AMOUNT = 1_000_000; // 0.01 WBTC (8 decimals)
    uint256 public lltv;
    uint256 public lltvRatio;

    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();

        supplyHook = new MorphoSupplyHook(MORPHO);
        borrowHook = new MorphoBorrowHook(MORPHO);
        repayHook = new MorphoRepayHook(MORPHO);
        withdrawHook = new MorphoWithdrawHook(MORPHO);
        superNativePaymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));

        lltv = 860_000_000_000_000_000; // 86%
        lltvRatio = 660_000_000_000_000_000; // 66%

        marketParams = MarketParams({
            loanToken: CHAIN_1_USDC,
            collateralToken: CHAIN_1_WBTC,
            oracle: MORPHO_ORACLE_WBTC_USDC,
            irm: MORPHO_IRM_WBTC_USDC,
            lltv: lltv
        });
        marketId = marketParams.id();

        // Fund account with WBTC for collateral
        _getTokens(CHAIN_1_WBTC, accountEth, 1e8); // 1 WBTC
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                         HELPER: ENCODE HOOK DATA
    //////////////////////////////////////////////////////////////*/

    function _createSupplyHookData(uint256 amount, bool usePrevHookAmount) internal view returns (bytes memory) {
        return abi.encodePacked(
            CHAIN_1_USDC, CHAIN_1_WBTC, bytes12(0),
            CHAIN_1_USDC, CHAIN_1_WBTC, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, amount, lltv, usePrevHookAmount
        );
    }

    function _createBorrowHookData(uint256 amount, bool usePrevHookAmount) internal view returns (bytes memory) {
        return _createMorphoBorrowHookData(
            CHAIN_1_USDC, CHAIN_1_WBTC, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, amount, lltvRatio, usePrevHookAmount, lltv
        );
    }

    function _createRepayHookData(
        uint256 amount,
        bool usePrevHookAmount,
        bool isFullRepayment
    )
        internal
        view
        returns (bytes memory)
    {
        return _createMorphoRepayHookData(
            CHAIN_1_USDC, CHAIN_1_WBTC, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, amount, lltv, usePrevHookAmount, isFullRepayment
        );
    }

    function _createWithdrawCollateralHookData(
        address onBehalf,
        address recipient,
        uint256 assets,
        uint256 shares
    )
        internal
        view
        returns (bytes memory)
    {
        // MorphoWithdrawHook calls Morpho.withdraw (for lending positions), not withdrawCollateral.
        // For borrower-side collateral withdrawal, we use MorphoRepayAndWithdrawHook.
        // But for completeness, this encodes the withdraw hook data format.
        return abi.encodePacked(
            CHAIN_1_USDC, CHAIN_1_WBTC, bytes12(0),
            CHAIN_1_USDC, CHAIN_1_WBTC, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, onBehalf, recipient, lltv, assets, shares
        );
    }

    /*//////////////////////////////////////////////////////////////
                         HELPER: EXECUTE VIA USEROP
    //////////////////////////////////////////////////////////////*/

    function _executeSupply(uint256 amount) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(supplyHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createSupplyHookData(amount, false);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
    }

    function _executeBorrow(uint256 amount) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(borrowHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createBorrowHookData(amount, false);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
    }

    function _executeRepay(uint256 amount, bool isFullRepayment) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(repayHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createRepayHookData(amount, false, isFullRepayment);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                              TEST CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice Test: Supply WBTC as collateral via MorphoSupplyHook
    function test_SupplyHook_SupplyCollateral() external {
        uint256 wbtcBefore = IERC20(CHAIN_1_WBTC).balanceOf(accountEth);

        _executeSupply(COLLATERAL_AMOUNT);

        // Verify WBTC spent
        uint256 wbtcAfter = IERC20(CHAIN_1_WBTC).balanceOf(accountEth);
        assertEq(wbtcBefore - wbtcAfter, COLLATERAL_AMOUNT, "Should spend exact WBTC amount");

        // Verify collateral position on Morpho
        (uint256 supplyShares, uint128 borrowShares, uint128 collateral) =
            IMorphoStaticTyping(MORPHO).position(marketId, accountEth);

        assertEq(supplyShares, 0, "Should have no supply shares (this is collateral)");
        assertEq(borrowShares, 0, "Should have no borrow shares yet");
        assertEq(uint256(collateral), COLLATERAL_AMOUNT, "Collateral should match supplied amount");
    }

    /// @notice Test: Borrow USDC after supplying collateral
    function test_BorrowHook_BorrowAfterSupply() external {
        // First supply collateral
        _executeSupply(COLLATERAL_AMOUNT);

        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);

        // Then borrow
        _executeBorrow(COLLATERAL_AMOUNT);

        uint256 usdcAfter = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        assertGt(usdcAfter, usdcBefore, "Should have received USDC from borrow");

        // Verify position has both collateral and borrow
        (uint256 supplyShares, uint128 borrowShares, uint128 collateral) =
            IMorphoStaticTyping(MORPHO).position(marketId, accountEth);

        assertEq(uint256(collateral), COLLATERAL_AMOUNT, "Collateral should remain");
        assertGt(uint256(borrowShares), 0, "Should have borrow shares");
        assertEq(supplyShares, 0, "Should have no supply shares");
    }

    /// @notice Test: Partial repay after supply + borrow
    function test_RepayHook_PartialRepay() external {
        // Supply collateral + borrow
        _executeSupply(COLLATERAL_AMOUNT);

        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        _executeBorrow(COLLATERAL_AMOUNT);
        uint256 borrowed = IERC20(CHAIN_1_USDC).balanceOf(accountEth) - usdcBefore;

        // Repay half of the actual borrowed amount (not half of total balance which includes base setup funds)
        uint256 repayAmount = borrowed / 2;

        (, uint128 borrowSharesBefore,) = IMorphoStaticTyping(MORPHO).position(marketId, accountEth);

        // Partial repay
        _executeRepay(repayAmount, false);

        (, uint128 borrowSharesAfter,) = IMorphoStaticTyping(MORPHO).position(marketId, accountEth);
        assertLt(uint256(borrowSharesAfter), uint256(borrowSharesBefore), "Borrow shares should decrease");
        assertGt(uint256(borrowSharesAfter), 0, "Should still have remaining borrow");
    }

    /// @notice Test: Full repay after supply + borrow
    /// @dev Calls accrueInterest before the repay UserOp so build() sees up-to-date debt (P1-3 mitigation)
    function test_RepayHook_FullRepay() external {
        // Supply collateral + borrow
        _executeSupply(COLLATERAL_AMOUNT);
        _executeBorrow(COLLATERAL_AMOUNT);

        // Warp to accrue some interest
        vm.warp(block.timestamp + 7 days);

        // Accrue interest so build() sees up-to-date debt for approval calculation (P1-3)
        IMorpho(MORPHO).accrueInterest(marketParams);

        // Deal extra USDC to cover interest
        uint256 usdcBalance = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        _getTokens(CHAIN_1_USDC, accountEth, usdcBalance + 1e6); // extra 1 USDC for interest

        // Full repay
        _executeRepay(0, true);

        (, uint128 borrowSharesAfter,) = IMorphoStaticTyping(MORPHO).position(marketId, accountEth);
        assertEq(uint256(borrowSharesAfter), 0, "Should have no borrow shares after full repay");
    }

    /// @notice Test: Full lifecycle — Supply → Borrow → time passes → Repay (full)
    /// @dev Calls accrueInterest before the repay UserOp so build() sees up-to-date debt (P1-3 mitigation)
    function test_FullCycle_SupplyBorrowRepay() external {
        // 1. Supply collateral
        uint256 wbtcBefore = IERC20(CHAIN_1_WBTC).balanceOf(accountEth);
        _executeSupply(COLLATERAL_AMOUNT);

        assertEq(wbtcBefore - IERC20(CHAIN_1_WBTC).balanceOf(accountEth), COLLATERAL_AMOUNT);

        // 2. Borrow
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        _executeBorrow(COLLATERAL_AMOUNT);

        uint256 borrowed = IERC20(CHAIN_1_USDC).balanceOf(accountEth) - usdcBefore;
        assertGt(borrowed, 0, "Should have borrowed USDC");

        // 3. Wait for interest
        vm.warp(block.timestamp + 30 days);

        // 4. Accrue interest so build() sees up-to-date debt (P1-3)
        IMorpho(MORPHO).accrueInterest(marketParams);

        // 5. Deal USDC to cover interest
        _getTokens(CHAIN_1_USDC, accountEth, IERC20(CHAIN_1_USDC).balanceOf(accountEth) + 10e6);

        // 6. Full repay
        _executeRepay(0, true);

        (, uint128 borrowShares, uint128 collateral) = IMorphoStaticTyping(MORPHO).position(marketId, accountEth);
        assertEq(uint256(borrowShares), 0, "Should have no borrow after full repay");
        assertEq(uint256(collateral), COLLATERAL_AMOUNT, "Collateral should remain (repay doesn't withdraw collateral)");
    }

    /// @notice Test: Supply + Borrow chained in single UserOp
    function test_SupplyAndBorrowChained() external {
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = address(supplyHook);
        hooksAddresses[1] = address(borrowHook);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createSupplyHookData(COLLATERAL_AMOUNT, false);
        hooksData[1] = _createBorrowHookData(COLLATERAL_AMOUNT, false);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);

        // Verify both collateral and borrow set
        (uint256 supplyShares, uint128 borrowShares, uint128 collateral) =
            IMorphoStaticTyping(MORPHO).position(marketId, accountEth);

        assertEq(uint256(collateral), COLLATERAL_AMOUNT, "Collateral should be supplied");
        assertGt(uint256(borrowShares), 0, "Should have borrow shares");
        assertEq(supplyShares, 0, "Should have no supply shares");

        // Verify USDC received
        assertGt(IERC20(CHAIN_1_USDC).balanceOf(accountEth), 0, "Should have borrowed USDC");
    }

    /// @notice Test: Multiple supply operations accumulate collateral
    function test_SupplyHook_MultipleSupplies() external {
        uint256 firstSupply = 500_000;
        uint256 secondSupply = 500_000;

        _executeSupply(firstSupply);

        (,, uint128 collateralAfterFirst) = IMorphoStaticTyping(MORPHO).position(marketId, accountEth);
        assertEq(uint256(collateralAfterFirst), firstSupply, "First supply collateral");

        _executeSupply(secondSupply);

        (,, uint128 collateralAfterSecond) = IMorphoStaticTyping(MORPHO).position(marketId, accountEth);
        assertEq(uint256(collateralAfterSecond), firstSupply + secondSupply, "Collateral should accumulate");
    }
}
