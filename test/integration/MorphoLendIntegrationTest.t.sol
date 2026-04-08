// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { MarketParamsLib } from "../../src/vendor/morpho/MarketParamsLib.sol";
import { Id, IMorphoStaticTyping, MarketParams } from "../../src/vendor/morpho/IMorpho.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import "forge-std/console2.sol";

// Superform
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { MinimalBaseIntegrationTest } from "./MinimalBaseIntegrationTest.t.sol";
import { MorphoLendHook } from "../../src/hooks/loan/morpho/MorphoLendHook.sol";
import { MorphoWithdrawHook } from "../../src/hooks/loan/morpho/MorphoWithdrawHook.sol";
import { ISuperNativePaymaster } from "../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperNativePaymaster } from "../../src/paymaster/SuperNativePaymaster.sol";

/// @title MorphoLendIntegrationTest
/// @notice Full E2E test for MorphoLendHook + MorphoWithdrawHook through real ERC-4337 UserOp flow
/// @dev No mocks — uses SuperExecutor, SuperNativePaymaster, real Morpho Blue, real tokens
contract MorphoLendIntegrationTest is MinimalBaseIntegrationTest {
    using MarketParamsLib for MarketParams;

    MorphoLendHook public lendHook;
    MorphoWithdrawHook public withdrawHook;
    ISuperNativePaymaster public superNativePaymaster;

    MarketParams public marketParams;
    Id public marketId;

    uint256 public constant LEND_AMOUNT = 10_000e6; // 10,000 USDC
    uint256 public lltv;

    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();

        lendHook = new MorphoLendHook(MORPHO);
        withdrawHook = new MorphoWithdrawHook(MORPHO);
        superNativePaymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));

        lltv = 860_000_000_000_000_000; // 86% LLTV

        marketParams = MarketParams({
            loanToken: CHAIN_1_USDC,
            collateralToken: CHAIN_1_WBTC,
            oracle: MORPHO_ORACLE_WBTC_USDC,
            irm: MORPHO_IRM_WBTC_USDC,
            lltv: lltv
        });
        marketId = marketParams.id();

        // Fund account with USDC for lending
        _getTokens(CHAIN_1_USDC, accountEth, LEND_AMOUNT);
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                         HELPER: ENCODE LEND DATA
    //////////////////////////////////////////////////////////////*/

    function _createMorphoLendHookData(
        address loanToken,
        address collateralToken,
        address oracle,
        address irm,
        uint256 amount,
        uint256 _lltv,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(loanToken, collateralToken, oracle, irm, amount, _lltv, usePrevHookAmount);
    }

    function _createMorphoWithdrawHookData(
        address loanToken,
        address collateralToken,
        address oracle,
        address irm,
        uint256 _lltv,
        uint256 assets,
        uint256 shares
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(loanToken, collateralToken, oracle, irm, _lltv, assets, shares);
    }

    /*//////////////////////////////////////////////////////////////
                         HELPER: EXECUTE VIA USEROP
    //////////////////////////////////////////////////////////////*/

    function _executeLendViaUserOp(uint256 amount) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(lendHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createMorphoLendHookData(
            CHAIN_1_USDC, CHAIN_1_WBTC, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, amount, lltv, false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
    }

    function _executeWithdrawViaUserOp(uint256 assets, uint256 shares) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(withdrawHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createMorphoWithdrawHookData(
            CHAIN_1_USDC, CHAIN_1_WBTC, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, lltv, assets, shares
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                              TEST CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice Test: Lend USDC via full ERC-4337 UserOp flow — no mocks
    function test_MorphoLendHook_SupplyUSDC() external {
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        assertGe(usdcBefore, LEND_AMOUNT, "Account should have USDC");

        _executeLendViaUserOp(LEND_AMOUNT);

        // Verify USDC spent
        uint256 usdcAfter = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        assertEq(usdcBefore - usdcAfter, LEND_AMOUNT, "Should spend exact USDC amount");

        // Verify supply shares created on Morpho
        (uint256 supplyShares, uint128 borrowShares, uint128 collateral) =
            IMorphoStaticTyping(MORPHO).position(marketId, accountEth);

        assertGt(supplyShares, 0, "Should have supply shares");
        assertEq(borrowShares, 0, "Should have no borrow shares");
        assertEq(collateral, 0, "Should have no collateral");
    }

    /// @notice Test: Full lend + withdraw cycle via UserOp flow
    function test_MorphoLendHook_FullCycle() external {
        // Lend
        _executeLendViaUserOp(LEND_AMOUNT);

        (uint256 supplyShares,,) = IMorphoStaticTyping(MORPHO).position(marketId, accountEth);
        assertGt(supplyShares, 0, "Should have supply shares after lend");

        // Warp to accrue interest
        vm.warp(block.timestamp + 30 days);

        // Withdraw all via shares
        _executeWithdrawViaUserOp(0, supplyShares);

        // Verify position closed
        (uint256 supplySharesAfter,,) = IMorphoStaticTyping(MORPHO).position(marketId, accountEth);
        assertEq(supplySharesAfter, 0, "Should have no supply shares after full withdrawal");

        // Verify interest earned
        uint256 usdcBalance = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        assertGe(usdcBalance, LEND_AMOUNT, "Should receive at least the lent amount");

        uint256 interestEarned = usdcBalance - LEND_AMOUNT;
        assertGt(interestEarned, 0, "Should have earned interest over 30 days");
    }

    /// @notice Test: Partial withdrawal via assets
    function test_MorphoLendHook_PartialWithdraw() external {
        _executeLendViaUserOp(LEND_AMOUNT);

        (uint256 supplySharesBefore,,) = IMorphoStaticTyping(MORPHO).position(marketId, accountEth);

        // Withdraw 50% via assets
        uint256 partialAmount = LEND_AMOUNT / 2;
        _executeWithdrawViaUserOp(partialAmount, 0);

        // Verify partial position remains
        (uint256 supplySharesAfter,,) = IMorphoStaticTyping(MORPHO).position(marketId, accountEth);
        assertGt(supplySharesAfter, 0, "Should still have supply shares");
        assertLt(supplySharesAfter, supplySharesBefore, "Should have fewer supply shares");

        // Verify USDC received
        uint256 usdcBalance = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        assertEq(usdcBalance, partialAmount, "Should receive partial amount");
    }

    /// @notice Test: Multiple lends accumulate supply shares
    function test_MorphoLendHook_MultipleLends() external {
        uint256 firstLend = 5000e6;
        uint256 secondLend = 5000e6;

        // First lend
        _executeLendViaUserOp(firstLend);

        (uint256 sharesAfterFirst,,) = IMorphoStaticTyping(MORPHO).position(marketId, accountEth);
        assertGt(sharesAfterFirst, 0, "Should have shares after first lend");

        // Second lend
        _executeLendViaUserOp(secondLend);

        (uint256 sharesAfterSecond,,) = IMorphoStaticTyping(MORPHO).position(marketId, accountEth);
        assertGt(sharesAfterSecond, sharesAfterFirst, "Shares should increase after second lend");

        // All USDC should be spent
        uint256 usdcRemaining = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        assertEq(usdcRemaining, 0, "All USDC should be lent");
    }

    /// @notice Test: Lend + withdraw chained in single UserOp
    function test_MorphoLendHook_LendAndWithdrawChained() external {
        // First lend to create a position
        _executeLendViaUserOp(LEND_AMOUNT);

        (uint256 supplyShares,,) = IMorphoStaticTyping(MORPHO).position(marketId, accountEth);

        // Fund more USDC for second lend
        uint256 secondLend = 2000e6;
        _getTokens(CHAIN_1_USDC, accountEth, secondLend);

        // Chain: lend more + withdraw original in single UserOp
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = address(lendHook);
        hooksAddresses[1] = address(withdrawHook);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createMorphoLendHookData(
            CHAIN_1_USDC, CHAIN_1_WBTC, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, secondLend, lltv, false
        );
        hooksData[1] = _createMorphoWithdrawHookData(
            CHAIN_1_USDC, CHAIN_1_WBTC, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, lltv, 0, supplyShares
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);

        // Should have new shares from second lend, original position withdrawn
        (uint256 sharesAfter,,) = IMorphoStaticTyping(MORPHO).position(marketId, accountEth);
        assertGt(sharesAfter, 0, "Should have shares from second lend");

        // USDC balance should be ~= LEND_AMOUNT (original withdrawal, rounding tolerance)
        uint256 usdcBalance = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        assertApproxEqAbs(usdcBalance, LEND_AMOUNT, 2, "Should have withdrawn original lend amount");
    }

    /// @notice Test: Interest accrual verified with time warps
    function test_MorphoLendHook_InterestAccrual() external {
        _executeLendViaUserOp(LEND_AMOUNT);

        (uint256 supplyShares,,) = IMorphoStaticTyping(MORPHO).position(marketId, accountEth);

        // Warp 7 days, withdraw half
        vm.warp(block.timestamp + 7 days);
        _executeWithdrawViaUserOp(0, supplyShares / 2);

        uint256 usdcAfter7Days = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        assertGe(usdcAfter7Days, LEND_AMOUNT / 2, "Half withdrawal should return at least half amount");

        // Warp another 23 days (total 30), withdraw remaining
        vm.warp(block.timestamp + 23 days);
        (uint256 remainingShares,,) = IMorphoStaticTyping(MORPHO).position(marketId, accountEth);
        _executeWithdrawViaUserOp(0, remainingShares);

        uint256 totalRecovered = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        assertGt(totalRecovered, LEND_AMOUNT, "Total recovered should exceed original due to interest");
    }
}
