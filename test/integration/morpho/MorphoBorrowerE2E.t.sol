// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test } from "forge-std/Test.sol";

// Morpho imports
import { Id, MarketParams } from "../../../src/vendor/morpho/IMorpho.sol";
import { IMorpho, IMorphoStaticTyping } from "../../../src/vendor/morpho/IMorpho.sol";
import { MarketParamsLib } from "../../../src/vendor/morpho/MarketParamsLib.sol";

// Superform imports
import { MorphoSupplyHook } from "../../../src/hooks/loan/morpho/MorphoSupplyHook.sol";
import { MorphoBorrowHook } from "../../../src/hooks/loan/morpho/MorphoBorrowHook.sol";
import { MorphoRepayHook } from "../../../src/hooks/loan/morpho/MorphoRepayHook.sol";
import { MorphoWithdrawHook } from "../../../src/hooks/loan/morpho/MorphoWithdrawHook.sol";
import { BaseHook } from "../../../src/hooks/BaseHook.sol";
import { Constants } from "../../utils/Constants.sol";

import "forge-std/console2.sol";

/// @notice Minimal interface for the real deployed SuperVaultStrategy
interface ISuperVaultStrategy {
    struct ExecuteArgs {
        address[] hooks;
        bytes[] hookCalldata;
        uint256[] expectedAssetsOrSharesOut;
        bytes32[][] globalProofs;
        bytes32[][] strategyProofs;
    }

    function executeHooks(ExecuteArgs calldata args) external payable;
    function SUPER_GOVERNOR() external view returns (address);
}

/// @notice Minimal interface for SuperGovernor
interface ISuperGovernor {
    function isHookRegistered(address hook) external view returns (bool);
    function getAddress(bytes32 key) external view returns (address);
    function SUPER_VAULT_AGGREGATOR() external view returns (bytes32);
}

/// @notice Minimal interface for SuperVaultAggregator
interface ISuperVaultAggregator {
    struct ValidateHookArgs {
        address hookAddress;
        bytes hookArgs;
        bytes32[] globalProof;
        bytes32[] strategyProof;
    }

    function isAnyManager(address manager, address strategy) external view returns (bool);
    function validateHook(address strategy, ValidateHookArgs calldata args) external view returns (bool);
}

/// @title MorphoBorrowerE2E
/// @author Superform Labs
/// @notice E2E tests for MorphoSupplyHook, MorphoBorrowHook, MorphoRepayHook using real deployed SuperVaultStrategy
///
/// Real contracts:
///   - Strategy: 0x41A9Eb398518D2487301c61D2b33E4e966A9F1DD (SuperUSDC strategy)
///   - Manager:  0xb3dCDaA89B0A43bcC59a9BDEEb5583EC2071066c
///
/// Mocked (vm.mockCall):
///   - SUPER_GOVERNOR.isHookRegistered(hook) -> true  (freshly deployed hooks aren't registered)
///   - aggregator.isAnyManager(manager, strategy) -> true  (manager authorization)
///   - aggregator.validateHook(strategy, args) -> true  (merkle proof validation)
contract MorphoBorrowerE2E is Test, Constants {
    using MarketParamsLib for MarketParams;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Real deployed SuperVaultStrategy (SuperUSDC)
    address public constant STRATEGY = 0x41A9Eb398518D2487301c61D2b33E4e966A9F1DD;

    /// @notice Real manager for the strategy
    address public constant MANAGER = 0xb3dCDaA89B0A43bcC59a9BDEEb5583EC2071066c;

    MorphoSupplyHook public supplyHook;
    MorphoBorrowHook public borrowHook;
    MorphoRepayHook public repayHook;
    MorphoWithdrawHook public withdrawHook;

    address public superGovernor;
    address public aggregator;

    // WBTC/USDC Morpho Blue market params
    MarketParams public marketParams;
    Id public marketId;

    uint256 public constant COLLATERAL_AMOUNT = 1_000_000; // 0.01 WBTC
    uint256 public lltv;
    uint256 public lltvRatio;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        // Fork mainnet
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY));

        // Deploy hooks
        supplyHook = new MorphoSupplyHook(MORPHO);
        borrowHook = new MorphoBorrowHook(MORPHO);
        repayHook = new MorphoRepayHook(MORPHO);
        withdrawHook = new MorphoWithdrawHook(MORPHO);

        lltv = 860_000_000_000_000_000; // 86%
        lltvRatio = 660_000_000_000_000_000; // 66%

        // Read real SuperGovernor from the deployed strategy
        superGovernor = ISuperVaultStrategy(STRATEGY).SUPER_GOVERNOR();

        // Read real aggregator from SuperGovernor
        bytes32 aggregatorKey = ISuperGovernor(superGovernor).SUPER_VAULT_AGGREGATOR();
        aggregator = ISuperGovernor(superGovernor).getAddress(aggregatorKey);

        // Mock: hook registration
        vm.mockCall(
            superGovernor,
            abi.encodeCall(ISuperGovernor.isHookRegistered, (address(supplyHook))),
            abi.encode(true)
        );
        vm.mockCall(
            superGovernor,
            abi.encodeCall(ISuperGovernor.isHookRegistered, (address(borrowHook))),
            abi.encode(true)
        );
        vm.mockCall(
            superGovernor,
            abi.encodeCall(ISuperGovernor.isHookRegistered, (address(repayHook))),
            abi.encode(true)
        );
        vm.mockCall(
            superGovernor,
            abi.encodeCall(ISuperGovernor.isHookRegistered, (address(withdrawHook))),
            abi.encode(true)
        );

        // Mock: manager authorization
        vm.mockCall(
            aggregator,
            abi.encodeCall(ISuperVaultAggregator.isAnyManager, (MANAGER, STRATEGY)),
            abi.encode(true)
        );

        // Mock: hook validation (merkle proof check)
        vm.mockCall(
            aggregator,
            abi.encodeWithSelector(ISuperVaultAggregator.validateHook.selector),
            abi.encode(true)
        );

        // Build market params
        marketParams = MarketParams({
            loanToken: CHAIN_1_USDC,
            collateralToken: CHAIN_1_WBTC,
            oracle: MORPHO_ORACLE_WBTC_USDC,
            irm: MORPHO_IRM_WBTC_USDC,
            lltv: lltv
        });
        marketId = marketParams.id();
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Build hook data for MorphoSupplyHook
    function _buildSupplyHookData(uint256 amount, bool usePrevHookAmount) internal view returns (bytes memory) {
        return abi.encodePacked(
            marketParams.loanToken,
            marketParams.collateralToken,
            bytes12(0),
            marketParams.loanToken,
            marketParams.collateralToken,
            marketParams.oracle,
            marketParams.irm,
            amount,
            marketParams.lltv,
            usePrevHookAmount
        );
    }

    /// @notice Build hook data for MorphoBorrowHook
    function _buildBorrowHookData(uint256 amount, bool usePrevHookAmount) internal view returns (bytes memory) {
        return abi.encodePacked(
            marketParams.loanToken,
            marketParams.collateralToken,
            bytes12(0),
            marketParams.loanToken,
            marketParams.collateralToken,
            marketParams.oracle,
            marketParams.irm,
            amount,
            lltvRatio,
            usePrevHookAmount,
            marketParams.lltv,
            false // placeholder
        );
    }

    /// @notice Build hook data for MorphoRepayHook
    function _buildRepayHookData(
        uint256 amount,
        bool usePrevHookAmount,
        bool isFullRepayment
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            marketParams.loanToken,
            marketParams.collateralToken,
            bytes12(0),
            marketParams.loanToken,
            marketParams.collateralToken,
            marketParams.oracle,
            marketParams.irm,
            amount,
            marketParams.lltv,
            usePrevHookAmount,
            isFullRepayment
        );
    }

    /// @notice Build hook data for MorphoWithdrawHook
    /// @dev onBehalf and recipient are always set to account by the hook itself
    function _buildWithdrawHookData(
        uint256 assets,
        uint256 shares
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            marketParams.loanToken,
            marketParams.collateralToken,
            bytes12(0),
            marketParams.loanToken,
            marketParams.collateralToken,
            marketParams.oracle,
            marketParams.irm,
            marketParams.lltv,
            assets,
            shares
        );
    }

    /// @notice Build ExecuteArgs for the real strategy with empty merkle proofs
    function _buildExecuteArgs(
        address[] memory hooks,
        bytes[] memory hookCalldata,
        uint256[] memory expectedOut
    )
        internal
        pure
        returns (ISuperVaultStrategy.ExecuteArgs memory)
    {
        uint256 len = hooks.length;
        bytes32[][] memory globalProofs = new bytes32[][](len);
        bytes32[][] memory strategyProofs = new bytes32[][](len);

        for (uint256 i; i < len; ++i) {
            globalProofs[i] = new bytes32[](0);
            strategyProofs[i] = new bytes32[](0);
        }

        return ISuperVaultStrategy.ExecuteArgs({
            hooks: hooks,
            hookCalldata: hookCalldata,
            expectedAssetsOrSharesOut: expectedOut,
            globalProofs: globalProofs,
            strategyProofs: strategyProofs
        });
    }

    /// @notice Execute a single supply hook through the real strategy
    function _executeSupply(uint256 amount) internal {
        address[] memory hooks = new address[](1);
        hooks[0] = address(supplyHook);

        bytes[] memory hookCalldata = new bytes[](1);
        hookCalldata[0] = _buildSupplyHookData(amount, false);

        uint256[] memory expectedOut = new uint256[](1);
        expectedOut[0] = 0;

        ISuperVaultStrategy.ExecuteArgs memory args = _buildExecuteArgs(hooks, hookCalldata, expectedOut);

        vm.prank(MANAGER);
        ISuperVaultStrategy(STRATEGY).executeHooks(args);
    }

    /// @notice Execute a single borrow hook through the real strategy
    function _executeBorrow(uint256 amount) internal {
        address[] memory hooks = new address[](1);
        hooks[0] = address(borrowHook);

        bytes[] memory hookCalldata = new bytes[](1);
        hookCalldata[0] = _buildBorrowHookData(amount, false);

        uint256[] memory expectedOut = new uint256[](1);
        expectedOut[0] = 0;

        ISuperVaultStrategy.ExecuteArgs memory args = _buildExecuteArgs(hooks, hookCalldata, expectedOut);

        vm.prank(MANAGER);
        ISuperVaultStrategy(STRATEGY).executeHooks(args);
    }

    /// @notice Execute a repay hook through the real strategy
    function _executeRepay(uint256 amount, bool isFullRepayment) internal {
        address[] memory hooks = new address[](1);
        hooks[0] = address(repayHook);

        bytes[] memory hookCalldata = new bytes[](1);
        hookCalldata[0] = _buildRepayHookData(amount, false, isFullRepayment);

        uint256[] memory expectedOut = new uint256[](1);
        expectedOut[0] = 0;

        ISuperVaultStrategy.ExecuteArgs memory args = _buildExecuteArgs(hooks, hookCalldata, expectedOut);

        vm.prank(MANAGER);
        ISuperVaultStrategy(STRATEGY).executeHooks(args);
    }

    /*//////////////////////////////////////////////////////////////
                              TEST CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice Test: Supply WBTC collateral via real strategy
    function test_Supply_Collateral() public {
        deal(CHAIN_1_WBTC, STRATEGY, COLLATERAL_AMOUNT);

        uint256 wbtcBefore = IERC20(CHAIN_1_WBTC).balanceOf(STRATEGY);

        _executeSupply(COLLATERAL_AMOUNT);

        // Verify WBTC spent
        uint256 wbtcAfter = IERC20(CHAIN_1_WBTC).balanceOf(STRATEGY);
        assertEq(wbtcBefore - wbtcAfter, COLLATERAL_AMOUNT, "Should spend exact WBTC amount");

        // Verify Morpho position
        (uint256 supplyShares, uint128 borrowShares, uint128 collateral) =
            IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);

        assertEq(supplyShares, 0, "Should have no supply shares");
        assertEq(uint256(borrowShares), 0, "Should have no borrow shares");
        assertEq(uint256(collateral), COLLATERAL_AMOUNT, "Collateral should match");

        // Verify outAmount tracks collateral consumed
        uint256 outAmount = supplyHook.getOutAmount(STRATEGY);
        assertEq(outAmount, COLLATERAL_AMOUNT, "outAmount should equal collateral consumed");
    }

    /// @notice Test: Borrow USDC after supplying collateral
    function test_SupplyThenBorrow() public {
        deal(CHAIN_1_WBTC, STRATEGY, COLLATERAL_AMOUNT);

        // Supply collateral
        _executeSupply(COLLATERAL_AMOUNT);

        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(STRATEGY);

        // Borrow — amount field is collateral amount, borrowHook derives borrow amount from lltvRatio
        _executeBorrow(COLLATERAL_AMOUNT);

        uint256 usdcAfter = IERC20(CHAIN_1_USDC).balanceOf(STRATEGY);
        assertGt(usdcAfter, usdcBefore, "Should have received USDC");

        uint256 borrowed = usdcAfter - usdcBefore;

        // Verify position
        (uint256 supplyShares, uint128 borrowShares, uint128 collateral) =
            IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);

        assertEq(uint256(collateral), COLLATERAL_AMOUNT, "Collateral should remain");
        assertGt(uint256(borrowShares), 0, "Should have borrow shares");
        assertEq(supplyShares, 0, "Should have no supply shares");

        // Verify outAmount tracks borrowed USDC
        uint256 outAmount = borrowHook.getOutAmount(STRATEGY);
        assertEq(outAmount, borrowed, "outAmount should equal borrowed USDC");
    }

    /// @notice Test: Partial repay of USDC borrow
    function test_PartialRepay() public {
        // Setup: supply + borrow
        deal(CHAIN_1_WBTC, STRATEGY, COLLATERAL_AMOUNT);
        _executeSupply(COLLATERAL_AMOUNT);

        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(STRATEGY);
        _executeBorrow(COLLATERAL_AMOUNT);
        uint256 borrowed = IERC20(CHAIN_1_USDC).balanceOf(STRATEGY) - usdcBefore;

        // Repay half of actual borrowed amount (not half of total balance which may include pre-existing USDC)
        uint256 repayAmount = borrowed / 2;

        (, uint128 borrowSharesBefore,) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);

        // Partial repay
        _executeRepay(repayAmount, false);

        (, uint128 borrowSharesAfter,) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);
        assertLt(uint256(borrowSharesAfter), uint256(borrowSharesBefore), "Borrow shares should decrease");
        assertGt(uint256(borrowSharesAfter), 0, "Should still have remaining borrow");

        // Verify outAmount tracks consumed loanToken
        uint256 outAmount = repayHook.getOutAmount(STRATEGY);
        assertEq(outAmount, repayAmount, "outAmount should equal repaid amount");
    }

    /// @notice Test: Full repay of USDC borrow
    function test_FullRepay() public {
        // Setup: supply + borrow
        deal(CHAIN_1_WBTC, STRATEGY, COLLATERAL_AMOUNT);
        _executeSupply(COLLATERAL_AMOUNT);
        _executeBorrow(COLLATERAL_AMOUNT);

        // Warp to accrue interest
        vm.warp(block.timestamp + 7 days);

        // Accrue interest so build() sees up-to-date debt for approval calculation (P1-3)
        IMorpho(MORPHO).accrueInterest(marketParams);

        // Deal extra USDC to cover interest
        uint256 usdcBalance = IERC20(CHAIN_1_USDC).balanceOf(STRATEGY);
        deal(CHAIN_1_USDC, STRATEGY, usdcBalance + 10e6);

        // Full repay
        _executeRepay(0, true);

        (, uint128 borrowSharesAfter, uint128 collateral) =
            IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);

        assertEq(uint256(borrowSharesAfter), 0, "Should have no borrow shares after full repay");
        assertEq(uint256(collateral), COLLATERAL_AMOUNT, "Collateral should remain (repay doesn't withdraw)");
    }

    /// @notice Test: Full lifecycle — Supply → Borrow → wait → Full Repay
    function test_FullCycle_SupplyBorrowRepay() public {
        // 1. Supply collateral
        deal(CHAIN_1_WBTC, STRATEGY, COLLATERAL_AMOUNT);
        _executeSupply(COLLATERAL_AMOUNT);

        (,, uint128 collateral1) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);
        assertEq(uint256(collateral1), COLLATERAL_AMOUNT, "Step 1: Collateral supplied");

        // 2. Borrow USDC
        _executeBorrow(COLLATERAL_AMOUNT);

        (, uint128 borrowShares2,) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);
        assertGt(uint256(borrowShares2), 0, "Step 2: Borrow shares created");

        uint256 borrowed = IERC20(CHAIN_1_USDC).balanceOf(STRATEGY);
        assertGt(borrowed, 0, "Step 2: USDC received");

        // 3. Wait for interest
        vm.warp(block.timestamp + 30 days);

        // 4. Accrue interest so build() sees up-to-date debt (P1-3)
        IMorpho(MORPHO).accrueInterest(marketParams);

        // 5. Deal extra USDC and full repay
        deal(CHAIN_1_USDC, STRATEGY, borrowed + 50e6);
        _executeRepay(0, true);

        (, uint128 borrowShares5, uint128 collateral5) =
            IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);

        assertEq(uint256(borrowShares5), 0, "Step 5: No borrow shares");
        assertEq(uint256(collateral5), COLLATERAL_AMOUNT, "Step 5: Collateral intact");
    }

    /// @notice Test: Supply + Borrow chained in single executeHooks call
    function test_SupplyAndBorrow_Chained() public {
        deal(CHAIN_1_WBTC, STRATEGY, COLLATERAL_AMOUNT);

        address[] memory hooks = new address[](2);
        hooks[0] = address(supplyHook);
        hooks[1] = address(borrowHook);

        bytes[] memory hookCalldata = new bytes[](2);
        hookCalldata[0] = _buildSupplyHookData(COLLATERAL_AMOUNT, false);
        hookCalldata[1] = _buildBorrowHookData(COLLATERAL_AMOUNT, false);

        uint256[] memory expectedOut = new uint256[](2);
        expectedOut[0] = 0;
        expectedOut[1] = 0;

        ISuperVaultStrategy.ExecuteArgs memory args = _buildExecuteArgs(hooks, hookCalldata, expectedOut);

        vm.prank(MANAGER);
        ISuperVaultStrategy(STRATEGY).executeHooks(args);

        // Verify combined position
        (uint256 supplyShares, uint128 borrowShares, uint128 collateral) =
            IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);

        assertEq(uint256(collateral), COLLATERAL_AMOUNT, "Collateral supplied");
        assertGt(uint256(borrowShares), 0, "Borrow shares created");
        assertEq(supplyShares, 0, "No supply shares");
        assertGt(IERC20(CHAIN_1_USDC).balanceOf(STRATEGY), 0, "USDC received");
    }

    /// @notice Test: Supply + Borrow + Repay chained in single executeHooks call
    function test_SupplyBorrowRepay_Chained() public {
        deal(CHAIN_1_WBTC, STRATEGY, COLLATERAL_AMOUNT);

        // First do supply + borrow to create a position
        address[] memory hooks1 = new address[](2);
        hooks1[0] = address(supplyHook);
        hooks1[1] = address(borrowHook);

        bytes[] memory hookCalldata1 = new bytes[](2);
        hookCalldata1[0] = _buildSupplyHookData(COLLATERAL_AMOUNT, false);
        hookCalldata1[1] = _buildBorrowHookData(COLLATERAL_AMOUNT, false);

        uint256[] memory expectedOut1 = new uint256[](2);
        expectedOut1[0] = 0;
        expectedOut1[1] = 0;

        ISuperVaultStrategy.ExecuteArgs memory args1 = _buildExecuteArgs(hooks1, hookCalldata1, expectedOut1);

        vm.prank(MANAGER);
        ISuperVaultStrategy(STRATEGY).executeHooks(args1);

        // Now repay all in second call
        address[] memory hooks2 = new address[](1);
        hooks2[0] = address(repayHook);

        bytes[] memory hookCalldata2 = new bytes[](1);
        hookCalldata2[0] = _buildRepayHookData(0, false, true);

        uint256[] memory expectedOut2 = new uint256[](1);
        expectedOut2[0] = 0;

        ISuperVaultStrategy.ExecuteArgs memory args2 = _buildExecuteArgs(hooks2, hookCalldata2, expectedOut2);

        vm.prank(MANAGER);
        ISuperVaultStrategy(STRATEGY).executeHooks(args2);

        (, uint128 borrowSharesAfter,) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);
        assertEq(uint256(borrowSharesAfter), 0, "Should have no borrow after full repay");
    }

    /// @notice Test: Multiple supply operations accumulate collateral
    function test_Supply_MultipleAccumulates() public {
        uint256 firstSupply = 500_000;
        uint256 secondSupply = 500_000;

        deal(CHAIN_1_WBTC, STRATEGY, firstSupply + secondSupply);

        _executeSupply(firstSupply);

        (,, uint128 collateral1) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);
        assertEq(uint256(collateral1), firstSupply, "First supply");

        _executeSupply(secondSupply);

        (,, uint128 collateral2) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);
        assertEq(uint256(collateral2), firstSupply + secondSupply, "Accumulated collateral");
    }

    /// @notice Test: Interest accrual verified — more USDC needed to repay after time
    function test_InterestAccrual() public {
        deal(CHAIN_1_WBTC, STRATEGY, COLLATERAL_AMOUNT);
        _executeSupply(COLLATERAL_AMOUNT);

        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(STRATEGY);
        _executeBorrow(COLLATERAL_AMOUNT);
        uint256 borrowed = IERC20(CHAIN_1_USDC).balanceOf(STRATEGY) - usdcBefore;

        // Warp 90 days
        vm.warp(block.timestamp + 90 days);

        // Accrue interest on Morpho so build() sees up-to-date debt (P1-3)
        IMorpho(MORPHO).accrueInterest(marketParams);

        // Check that owed amount is more than actual borrowed amount
        uint256 owedAssets = repayHook.sharesToAssets(marketParams, STRATEGY);
        assertGt(owedAssets, borrowed, "Owed amount should exceed borrowed amount due to interest");

        // Deal enough to full repay with interest
        deal(CHAIN_1_USDC, STRATEGY, owedAssets + 1e6);

        _executeRepay(0, true);

        (, uint128 borrowSharesAfter,) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);
        assertEq(uint256(borrowSharesAfter), 0, "Full repay after interest accrual");
    }

    /// @notice Test: Revert when supply amount is zero
    function test_Supply_RevertsWhenAmountZero() public {
        bytes memory hookData = _buildSupplyHookData(0, false);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        supplyHook.build(address(0), STRATEGY, hookData);
    }

    /// @notice Test: Revert when borrow amount is zero
    function test_Borrow_RevertsWhenAmountZero() public {
        bytes memory hookData = _buildBorrowHookData(0, false);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        borrowHook.build(address(0), STRATEGY, hookData);
    }

    /// @notice Test: Revert when supply address is zero
    function test_Supply_RevertsWhenAddressZero() public {
        bytes memory hookData = abi.encodePacked(
            address(0), // header: loanToken = zero (offset 0)
            marketParams.collateralToken, // header: collateralToken (offset 20)
            bytes12(0), // header padding (offset 40)
            address(0), // loanToken = zero (offset 52)
            marketParams.collateralToken,
            marketParams.oracle,
            marketParams.irm,
            uint256(COLLATERAL_AMOUNT),
            marketParams.lltv,
            false
        );

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        supplyHook.build(address(0), STRATEGY, hookData);
    }
}
