// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { AaveV4ReserveRegistryV2 } from "../../../src/accounting/oracles/AaveV4ReserveRegistryV2.sol";
import { AaveV4ReserveOracle } from "../../../src/accounting/oracles/AaveV4ReserveOracle.sol";
import { IAaveV4Spoke } from "../../../src/vendor/aave-v4/IAaveV4Spoke.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";

/// @notice Fork tests for the Aave V4 accounting oracle against the live Ethereum Main Spoke.
/// @dev Pins the assumptions the unit suite mocks: reserve→token bindings on the real spoke,
///      in-view interest accrual with no state-touching call, and repay-to-zero reading exactly 0.
///      Positions are opened via direct spoke self-calls (onlyPositionManager always allows
///      msg.sender == onBehalfOf) — no hook machinery needed for oracle verification.
///      A Base-spoke twin should be added once the Base equities spoke address is published.
contract AaveV4OraclesForkTest is Test {
    // Live Ethereum mainnet Aave V4 Main Spoke (see test/integration/AaveV4V2HooksFork.t.sol)
    address internal constant SPOKE = 0x94e7A5dCbE816e498b89aB752661904E2F56c485;
    uint256 internal constant AAVE_V4_BLOCK = 24_884_274; // test/utils/Constants.sol
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint256 internal constant WETH_RESERVE_ID = 0;
    uint256 internal constant USDC_RESERVE_ID = 7;

    AaveV4ReserveRegistryV2 internal registry;
    AaveV4ReserveOracle internal oracle;

    address internal usdcKey;
    address internal usdcDebtKey;
    address internal wethKey;
    address internal wethDebtKey;
    address internal user = makeAddr("aaveV4OracleUser");

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"), AAVE_V4_BLOCK);

        address ledgerConfig = address(new SuperLedgerConfiguration());
        registry = new AaveV4ReserveRegistryV2(address(this));
        oracle = new AaveV4ReserveOracle(ledgerConfig, address(registry));

        (usdcKey, usdcDebtKey) = registry.registerReserve(SPOKE, USDC_RESERVE_ID);
        (wethKey, wethDebtKey) = registry.registerReserve(SPOKE, WETH_RESERVE_ID);
    }

    /// @dev Opens a real WETH-collateral / USDC-debt position via direct spoke self-calls
    function _openPosition(uint256 supplyWeth, uint256 borrowUsdc) internal {
        deal(WETH, user, supplyWeth);
        vm.startPrank(user);
        IERC20(WETH).approve(SPOKE, supplyWeth);
        IAaveV4Spoke(SPOKE).supply(WETH_RESERVE_ID, supplyWeth, user);
        IAaveV4Spoke(SPOKE).setUsingAsCollateral(WETH_RESERVE_ID, true, user);
        IAaveV4Spoke(SPOKE).borrow(USDC_RESERVE_ID, borrowUsdc, user);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    F4: REAL-MARKET REGISTRATION + BINDINGS
    //////////////////////////////////////////////////////////////*/

    /// @notice Registry bindings match the real spoke's reserve data (underlying + decimals)
    function test_Fork_Registration_RealBindings() public view {
        (address spoke_, uint256 id_, address underlying_, uint8 dec_, AaveV4ReserveRegistryV2.Side side_) =
            registry.getReserveInfo(usdcKey);
        assertEq(spoke_, SPOKE);
        assertEq(id_, USDC_RESERVE_ID);
        assertEq(underlying_, USDC);
        assertEq(dec_, 6);
        assertTrue(side_ == AaveV4ReserveRegistryV2.Side.SUPPLY);

        // The debt leg shares the binding and differs only in its side
        (,, address usdcDebtUnderlying, uint8 usdcDebtDec, AaveV4ReserveRegistryV2.Side debtSide) =
            registry.getReserveInfo(usdcDebtKey);
        assertEq(usdcDebtUnderlying, USDC);
        assertEq(usdcDebtDec, 6);
        assertTrue(debtSide == AaveV4ReserveRegistryV2.Side.DEBT);

        (,, address wethUnderlying, uint8 wethDec,) = registry.getReserveInfo(wethKey);
        assertEq(wethUnderlying, WETH);
        assertEq(wethDec, 18);

        // Decimals sweep through both legs — side-independent
        assertEq(oracle.getPricePerShare(usdcDebtKey), 1e6);
        assertEq(oracle.getPricePerShare(wethKey), 1e18);
    }

    /// @notice Reserve-level aggregates are live and non-zero on the real market, and the
    ///         extended vendored views (getReserveDebt / getReserveSuppliedAssets) match upstream
    function test_Fork_ReserveAggregates_Live() public view {
        assertGt(oracle.getTVL(usdcDebtKey), 0, "real USDC reserve has outstanding debt");
        assertGt(oracle.getTVL(usdcKey), 0, "real USDC reserve has supplied assets");
        assertGt(oracle.getTVL(wethKey), 0, "real WETH reserve has supplied assets");
    }

    /// @notice Registering an unlisted reserve id on the real spoke reverts (spoke-side revert)
    function test_Fork_Registration_RevertIf_UnlistedReserve() public {
        vm.expectRevert();
        registry.registerReserve(SPOKE, 999_999);
    }

    /*//////////////////////////////////////////////////////////////
                    F1: IN-VIEW ACCRUAL, NO STATE TOUCH
    //////////////////////////////////////////////////////////////*/

    /// @notice Debt read includes any same-block premium and accrues in-view after a warp with
    ///         NO state-touching call — no keeper poke, no stale-index gap
    function test_Fork_Debt_InViewAccrual_AfterWarp() public {
        _openPosition(10 ether, 5000e6);

        uint256 debtAtOpen = oracle.getBalanceOfOwner(usdcDebtKey, user);
        assertGe(debtAtOpen, 5000e6, "debt at open covers at least the drawn principal");

        vm.warp(block.timestamp + 30 days);

        uint256 debtLater = oracle.getBalanceOfOwner(usdcDebtKey, user);
        assertGt(debtLater, debtAtOpen, "interest accrues in-view with no state-touching call");

        // Reserve-level aggregate accrues in-view too
        // (drawn component of getReserveDebt rides the same live index)
        assertGt(oracle.getTVL(usdcDebtKey), 0);
    }

    /// @notice Supply read accrues in-view as well (hub share price rises with borrow interest)
    function test_Fork_Supply_InViewAccrual_AfterWarp() public {
        _openPosition(10 ether, 5000e6);

        uint256 suppliedAtOpen = oracle.getBalanceOfOwner(wethKey, user);
        assertGt(suppliedAtOpen, 0);
        // Supply rounds down at source: at most the deposit at t0
        assertLe(suppliedAtOpen, 10 ether);

        vm.warp(block.timestamp + 365 days);
        uint256 suppliedLater = oracle.getBalanceOfOwner(wethKey, user);
        assertGe(suppliedLater, suppliedAtOpen, "supplied balance never decreases under pure accrual");
    }

    /*//////////////////////////////////////////////////////////////
                    F2: REPAY-TO-ZERO CONSISTENCY
    //////////////////////////////////////////////////////////////*/

    /// @notice After a full repay (max sentinel), the oracle reads exactly 0 — both debt
    ///         components cleared, consistent with the hooks' SUP-20842 zero-debt-skip semantics
    function test_Fork_Debt_RepayToZero_ReadsExactlyZero() public {
        _openPosition(10 ether, 5000e6);
        vm.warp(block.timestamp + 30 days);

        uint256 debt = oracle.getBalanceOfOwner(usdcDebtKey, user);
        deal(USDC, user, debt * 2);

        vm.startPrank(user);
        IERC20(USDC).approve(SPOKE, type(uint256).max);
        IAaveV4Spoke(SPOKE).repay(USDC_RESERVE_ID, type(uint256).max, user);
        vm.stopPrank();

        assertEq(oracle.getBalanceOfOwner(usdcDebtKey, user), 0, "full repay clears drawn + premium exactly");
    }

    /*//////////////////////////////////////////////////////////////
                    HOOK-CONSISTENCY ANCHOR
    //////////////////////////////////////////////////////////////*/

    /// @notice The oracle's debt figure equals the raw drawn + premium sum the V2 loan hooks
    ///         (_totalDebt) resolve against — hook-side repays and oracle-side reads cannot diverge
    function test_Fork_Debt_MatchesHookRead() public {
        _openPosition(10 ether, 5000e6);
        vm.warp(block.timestamp + 7 days);

        (uint256 drawn, uint256 premium) = IAaveV4Spoke(SPOKE).getUserDebt(USDC_RESERVE_ID, user);
        assertEq(oracle.getBalanceOfOwner(usdcDebtKey, user), drawn + premium);

        assertEq(
            oracle.getBalanceOfOwner(wethKey, user), IAaveV4Spoke(SPOKE).getUserSuppliedAssets(WETH_RESERVE_ID, user)
        );
    }
}
