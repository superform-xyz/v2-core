// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// External imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test } from "forge-std/Test.sol";
import "forge-std/console2.sol";

// Morpho imports
import { MarketParamsLib } from "../../../src/vendor/morpho/MarketParamsLib.sol";
import { Id, IMorphoStaticTyping, MarketParams } from "../../../src/vendor/morpho/IMorpho.sol";

// Superform imports
import { MorphoSupplyHook } from "../../../src/hooks/loan/morpho/MorphoSupplyHook.sol";
import { MorphoBorrowHook } from "../../../src/hooks/loan/morpho/MorphoBorrowHook.sol";
import { MorphoRepayHook } from "../../../src/hooks/loan/morpho/MorphoRepayHook.sol";
import { MorphoSupplyAndBorrowHook } from "../../../src/hooks/loan/morpho/MorphoSupplyAndBorrowHook.sol";
import { MorphoRepayAndWithdrawHook } from "../../../src/hooks/loan/morpho/MorphoRepayAndWithdrawHook.sol";
import { Constants } from "../../utils/Constants.sol";

/// @notice Minimal interface for the real deployed SuperVaultStrategy.executeHooks
interface ISuperVaultStrategyExecute {
    struct ExecuteArgs {
        address[] hooks;
        bytes[] hookCalldata;
        uint256[] expectedAssetsOrSharesOut;
        bytes32[][] globalProofs;
        bytes32[][] strategyProofs;
    }

    function executeHooks(ExecuteArgs calldata args) external payable;
}

/// @notice Minimal interface for the SuperGovernor (used for isHookRegistered)
interface ISuperGovernor {
    function isHookRegistered(address hook) external view returns (bool);
    function getAddress(bytes32 key) external view returns (address);
    function SUPER_VAULT_AGGREGATOR() external view returns (bytes32);
}

/// @notice Minimal interface for the SuperVaultAggregator (used for isAnyManager + validateHook)
interface ISuperVaultAggregator {
    struct ValidateHookArgs {
        address hookAddress;
        bytes hookArgs;
        bytes32[] globalProof;
        bytes32[] strategyProof;
    }

    function isAnyManager(address manager, address strategy) external view returns (bool);
    function validateHook(address strategy, ValidateHookArgs calldata args) external view returns (bool isValid);
}

/// @title MorphoSuperVaultE2E
/// @notice E2E integration tests for Morpho hooks executed through real deployed SuperVaultStrategy (superUSDC)
/// @dev Uses WBTC/USDC Morpho market on Ethereum mainnet fork
/// @dev Strategy: 0x41A9Eb398518D2487301c61D2b33E4e966A9F1DD (Flagship USDC SuperVault)
/// @dev Manager: 0xb3dCDaA89B0A43bcC59a9BDEEb5583EC2071066c
/// @dev Aggregator: 0x10AC0b33e1C4501CF3ec1cB1AE51ebfdbd2d4698
/// @dev SuperGovernor: 0xB5396ef2bF8CA360cEB4166b77AFb2bed20e74d4
contract MorphoSuperVaultE2E is Test, Constants {
    using MarketParamsLib for MarketParams;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Real deployed SuperVault strategy (Flagship USDC, Ethereum mainnet)
    address public constant STRATEGY = 0x41A9Eb398518D2487301c61D2b33E4e966A9F1DD;
    address public constant MANAGER = 0xb3dCDaA89B0A43bcC59a9BDEEb5583EC2071066c;
    address public constant AGGREGATOR = 0x10AC0b33e1C4501CF3ec1cB1AE51ebfdbd2d4698;
    address public constant SUPER_GOVERNOR = 0xB5396ef2bF8CA360cEB4166b77AFb2bed20e74d4;

    /// @dev Fork at a block after strategy deployment (deployed at block 23922236)
    uint256 public constant FORK_BLOCK = 23_930_000;

    // Market parameters
    address public constant LOAN_TOKEN = CHAIN_1_USDC;
    address public constant COLLATERAL_TOKEN = CHAIN_1_WBTC;
    address public constant ORACLE = MORPHO_ORACLE_WBTC_USDC;
    address public constant IRM = MORPHO_IRM_WBTC_USDC;
    uint256 public constant LLTV = 860_000_000_000_000_000; // 86%
    uint256 public constant LTV_RATIO = 660_000_000_000_000_000; // 66%

    uint256 public constant COLLATERAL_AMOUNT = 1_000_000; // 0.01 WBTC (8 decimals)

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    ISuperVaultStrategyExecute public strategy;

    MorphoSupplyHook public supplyHook;
    MorphoBorrowHook public borrowHook;
    MorphoRepayHook public repayHook;
    MorphoSupplyAndBorrowHook public supplyAndBorrowHook;
    MorphoRepayAndWithdrawHook public repayAndWithdrawHook;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), FORK_BLOCK);

        strategy = ISuperVaultStrategyExecute(STRATEGY);

        // Deploy fresh Morpho hooks
        supplyHook = new MorphoSupplyHook(MORPHO);
        borrowHook = new MorphoBorrowHook(MORPHO);
        repayHook = new MorphoRepayHook(MORPHO);
        supplyAndBorrowHook = new MorphoSupplyAndBorrowHook(MORPHO);
        repayAndWithdrawHook = new MorphoRepayAndWithdrawHook(MORPHO);

        // Mock: SuperGovernor.isHookRegistered → always true for our hooks
        _mockHookRegistered(address(supplyHook));
        _mockHookRegistered(address(borrowHook));
        _mockHookRegistered(address(repayHook));
        _mockHookRegistered(address(supplyAndBorrowHook));
        _mockHookRegistered(address(repayAndWithdrawHook));

        // Mock: Aggregator.validateHook → always true (skip Merkle proof validation)
        vm.mockCall(
            AGGREGATOR,
            abi.encodeWithSelector(ISuperVaultAggregator.validateHook.selector),
            abi.encode(true)
        );

        // Mock: Aggregator.isAnyManager → true for MANAGER
        vm.mockCall(
            AGGREGATOR,
            abi.encodeWithSelector(ISuperVaultAggregator.isAnyManager.selector, MANAGER, STRATEGY),
            abi.encode(true)
        );
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                            MOCK HELPERS
    //////////////////////////////////////////////////////////////*/

    function _mockHookRegistered(address hook) internal {
        vm.mockCall(
            SUPER_GOVERNOR,
            abi.encodeWithSelector(ISuperGovernor.isHookRegistered.selector, hook),
            abi.encode(true)
        );
    }

    /*//////////////////////////////////////////////////////////////
                         DATA ENCODING HELPERS
    //////////////////////////////////////////////////////////////*/

    function _getMarketParams() internal pure returns (MarketParams memory) {
        return MarketParams({
            loanToken: LOAN_TOKEN,
            collateralToken: COLLATERAL_TOKEN,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });
    }

    function _getMarketId() internal pure returns (Id) {
        return _getMarketParams().id();
    }

    function _getPosition(address account)
        internal
        view
        returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral)
    {
        (supplyShares, borrowShares, collateral) = IMorphoStaticTyping(MORPHO).position(_getMarketId(), account);
    }

    /// @dev Encode data for MorphoSupplyHook
    function _createSupplyHookData(uint256 amount, bool usePrevHookAmount) internal pure returns (bytes memory) {
        return abi.encodePacked(LOAN_TOKEN, COLLATERAL_TOKEN, bytes12(0), LOAN_TOKEN, COLLATERAL_TOKEN, ORACLE, IRM, amount, LLTV, usePrevHookAmount);
    }

    /// @dev Encode data for MorphoSupplyAndBorrowHook
    function _createSupplyAndBorrowData(
        uint256 amount,
        uint256 ltvRatio,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            LOAN_TOKEN, COLLATERAL_TOKEN, bytes12(0), LOAN_TOKEN, COLLATERAL_TOKEN, ORACLE, IRM, amount, ltvRatio, usePrevHookAmount, LLTV, false
        );
    }

    /// @dev Encode data for MorphoRepayAndWithdrawHook
    function _createRepayAndWithdrawData(
        uint256 amount,
        bool usePrevHookAmount,
        bool isFullRepayment
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            LOAN_TOKEN, COLLATERAL_TOKEN, bytes12(0), LOAN_TOKEN, COLLATERAL_TOKEN, ORACLE, IRM, amount, LLTV, usePrevHookAmount, isFullRepayment
        );
    }

    /// @dev Encode data for MorphoRepayHook
    function _createRepayData(
        uint256 amount,
        bool usePrevHookAmount,
        bool isFullRepayment
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            LOAN_TOKEN, COLLATERAL_TOKEN, bytes12(0), LOAN_TOKEN, COLLATERAL_TOKEN, ORACLE, IRM, amount, LLTV, usePrevHookAmount, isFullRepayment
        );
    }

    /// @dev Build ExecuteArgs for a single hook (empty Merkle proofs since validation is mocked)
    function _buildArgs(
        address hook,
        bytes memory hookCalldata
    )
        internal
        pure
        returns (ISuperVaultStrategyExecute.ExecuteArgs memory)
    {
        address[] memory hooks = new address[](1);
        hooks[0] = hook;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = hookCalldata;

        uint256[] memory expectedOut = new uint256[](1);
        expectedOut[0] = 0;

        bytes32[][] memory emptyProofs = new bytes32[][](1);
        emptyProofs[0] = new bytes32[](0);

        return ISuperVaultStrategyExecute.ExecuteArgs({
            hooks: hooks,
            hookCalldata: calldatas,
            expectedAssetsOrSharesOut: expectedOut,
            globalProofs: emptyProofs,
            strategyProofs: emptyProofs
        });
    }

    /// @dev Execute supply+borrow as a common setup step. Returns borrow amount.
    function _doSupplyAndBorrow(uint256 collateralAmount) internal returns (uint256 borrowedAmount) {
        deal(COLLATERAL_TOKEN, STRATEGY, collateralAmount);

        uint256 usdcBefore = IERC20(LOAN_TOKEN).balanceOf(STRATEGY);

        vm.prank(MANAGER);
        strategy.executeHooks(
            _buildArgs(address(supplyAndBorrowHook), _createSupplyAndBorrowData(collateralAmount, LTV_RATIO, false))
        );

        borrowedAmount = IERC20(LOAN_TOKEN).balanceOf(STRATEGY) - usdcBefore;
    }

    /*//////////////////////////////////////////////////////////////
                    TEST A: SUPPLY + BORROW (COMBINED)
    //////////////////////////////////////////////////////////////*/

    /// @notice Test combined supply collateral and borrow using MorphoSupplyAndBorrowHook
    function test_SupplyAndBorrow_Combined() public {
        console2.log("=== Test A: Supply + Borrow (Combined Hook) via Real Strategy ===");

        uint256 wbtcBefore = IERC20(COLLATERAL_TOKEN).balanceOf(STRATEGY);
        uint256 usdcBefore = IERC20(LOAN_TOKEN).balanceOf(STRATEGY);

        uint256 borrowedAmount = _doSupplyAndBorrow(COLLATERAL_AMOUNT);

        uint256 wbtcAfter = IERC20(COLLATERAL_TOKEN).balanceOf(STRATEGY);
        uint256 usdcAfter = IERC20(LOAN_TOKEN).balanceOf(STRATEGY);

        console2.log("WBTC spent:", wbtcBefore + COLLATERAL_AMOUNT - wbtcAfter);
        console2.log("USDC borrowed:", borrowedAmount);

        assertEq(wbtcAfter, wbtcBefore, "All WBTC should be supplied as collateral");
        assertGt(usdcAfter, usdcBefore, "USDC balance should increase from borrowing");
        assertGt(borrowedAmount, 0, "Should borrow non-zero USDC");

        (, uint128 borrowShares, uint128 collateral) = _getPosition(STRATEGY);
        assertGt(collateral, 0, "Morpho should show collateral position");
        assertGt(borrowShares, 0, "Morpho should show borrow shares");

        console2.log("Morpho collateral:", collateral);
        console2.log("Morpho borrow shares:", borrowShares);
    }

    /*//////////////////////////////////////////////////////////////
                TEST B: SUPPLY + BORROW (INDIVIDUAL HOOKS)
    //////////////////////////////////////////////////////////////*/

    /// @notice Test supply then borrow using individual hooks chained
    function test_SupplyThenBorrow_Individual() public {
        console2.log("=== Test B: Supply + Borrow (Individual Hooks) via Real Strategy ===");

        deal(COLLATERAL_TOKEN, STRATEGY, COLLATERAL_AMOUNT);

        uint256 wbtcBefore = IERC20(COLLATERAL_TOKEN).balanceOf(STRATEGY);
        uint256 usdcBefore = IERC20(LOAN_TOKEN).balanceOf(STRATEGY);

        // Step 1: Supply collateral
        vm.prank(MANAGER);
        strategy.executeHooks(_buildArgs(address(supplyHook), _createSupplyHookData(COLLATERAL_AMOUNT, false)));

        (, , uint128 collateralAfterSupply) = _getPosition(STRATEGY);
        assertEq(uint256(collateralAfterSupply), COLLATERAL_AMOUNT, "Collateral should match supplied amount");

        // Step 2: Borrow USDC
        uint256 borrowAmount = supplyAndBorrowHook.deriveLoanAmount(COLLATERAL_AMOUNT, LTV_RATIO, LLTV, ORACLE);

        bytes memory borrowData = abi.encodePacked(
            LOAN_TOKEN, COLLATERAL_TOKEN, bytes12(0), LOAN_TOKEN, COLLATERAL_TOKEN, ORACLE, IRM, borrowAmount, LTV_RATIO, false, LLTV, false
        );

        vm.prank(MANAGER);
        strategy.executeHooks(_buildArgs(address(borrowHook), borrowData));

        uint256 usdcAfter = IERC20(LOAN_TOKEN).balanceOf(STRATEGY);

        console2.log("WBTC supplied:", wbtcBefore);
        console2.log("USDC borrowed:", usdcAfter - usdcBefore);

        (, uint128 borrowShares, uint128 collateral) = _getPosition(STRATEGY);
        assertGt(collateral, 0, "Should have collateral in Morpho");
        assertGt(borrowShares, 0, "Should have borrow shares in Morpho");
        assertGt(usdcAfter, usdcBefore, "Should have borrowed USDC");
    }

    /*//////////////////////////////////////////////////////////////
            TEST C: FULL REPAY + WITHDRAW (COMBINED HOOK)
    //////////////////////////////////////////////////////////////*/

    /// @notice Test full repay and withdraw all collateral using MorphoRepayAndWithdrawHook
    function test_FullRepayAndWithdraw_Combined() public {
        console2.log("=== Test C: Full Repay + Withdraw (Combined Hook) via Real Strategy ===");

        uint256 borrowedAmount = _doSupplyAndBorrow(COLLATERAL_AMOUNT);

        // Deal enough USDC to repay (buffer for interest)
        deal(LOAN_TOKEN, STRATEGY, borrowedAmount * 110 / 100);

        uint256 wbtcBefore = IERC20(COLLATERAL_TOKEN).balanceOf(STRATEGY);

        vm.prank(MANAGER);
        strategy.executeHooks(
            _buildArgs(
                address(repayAndWithdrawHook),
                _createRepayAndWithdrawData(0, false, true) // full repayment
            )
        );

        (, uint128 borrowShares, uint128 collateral) = _getPosition(STRATEGY);
        assertEq(collateral, 0, "Collateral should be fully withdrawn");
        assertEq(borrowShares, 0, "Borrow should be fully repaid");

        uint256 wbtcAfter = IERC20(COLLATERAL_TOKEN).balanceOf(STRATEGY);
        assertEq(wbtcAfter - wbtcBefore, COLLATERAL_AMOUNT, "All collateral should be returned");

        console2.log("Collateral returned:", wbtcAfter - wbtcBefore);
    }

    /*//////////////////////////////////////////////////////////////
        TEST D: PARTIAL REPAY + WITHDRAW (MAINTAINS LTV)
    //////////////////////////////////////////////////////////////*/

    /// @notice Test partial repay maintains LTV ratio
    function test_PartialRepayAndWithdraw_MaintainsLTV() public {
        console2.log("=== Test D: Partial Repay + Withdraw (Maintains LTV) via Real Strategy ===");

        _doSupplyAndBorrow(COLLATERAL_AMOUNT);

        // Warp forward to accrue interest
        vm.warp(block.timestamp + 10 weeks);
        IMorphoStaticTyping(MORPHO).accrueInterest(_getMarketParams());

        (, uint128 borrowSharesBefore, uint128 collateralBefore) = _getPosition(STRATEGY);
        uint256 borrowAssetsBefore = repayAndWithdrawHook.sharesToAssets(_getMarketParams(), STRATEGY);
        uint256 initialLtv = (borrowAssetsBefore * 1e18) / uint256(collateralBefore);

        console2.log("Initial borrow assets:", borrowAssetsBefore);
        console2.log("Initial collateral:", collateralBefore);
        console2.log("Initial LTV:", initialLtv);

        // Repay 50%
        uint256 repayAmount = borrowAssetsBefore / 2;
        deal(LOAN_TOKEN, STRATEGY, repayAmount);

        vm.prank(MANAGER);
        strategy.executeHooks(
            _buildArgs(
                address(repayAndWithdrawHook),
                _createRepayAndWithdrawData(repayAmount, false, false) // partial
            )
        );

        (, uint128 borrowSharesAfter, uint128 collateralAfter) = _getPosition(STRATEGY);
        assertGt(borrowSharesAfter, 0, "Should still have borrow");
        assertGt(collateralAfter, 0, "Should still have collateral");
        assertLt(borrowSharesAfter, borrowSharesBefore, "Borrow should decrease");
        assertLt(collateralAfter, collateralBefore, "Collateral should decrease");

        uint256 borrowAssetsAfter = repayAndWithdrawHook.sharesToAssets(_getMarketParams(), STRATEGY);
        uint256 finalLtv = (borrowAssetsAfter * 1e18) / uint256(collateralAfter);

        console2.log("Final borrow assets:", borrowAssetsAfter);
        console2.log("Final collateral:", collateralAfter);
        console2.log("Final LTV:", finalLtv);

        assertApproxEqRel(finalLtv, initialLtv, 1e16, "LTV should be maintained within 1%");
    }

    /*//////////////////////////////////////////////////////////////
        TEST E: FULL CYCLE (SUPPLY → BORROW → REPAY+WITHDRAW)
    //////////////////////////////////////////////////////////////*/

    /// @notice Test full lifecycle: individual supply + borrow, then combined repay+withdraw
    /// @dev MorphoWithdrawHook uses IMorphoBase.withdraw (supply-side), not withdrawCollateral.
    ///      To withdraw collateral after borrowing, MorphoRepayAndWithdrawHook must be used.
    function test_FullCycle_IndividualSupplyBorrow_CombinedRepayWithdraw() public {
        console2.log("=== Test E: Full Cycle via Real Strategy ===");

        deal(COLLATERAL_TOKEN, STRATEGY, COLLATERAL_AMOUNT);
        uint256 wbtcInitial = IERC20(COLLATERAL_TOKEN).balanceOf(STRATEGY);

        // Step 1: Supply collateral
        console2.log("--- Step 1: Supply Collateral ---");
        vm.prank(MANAGER);
        strategy.executeHooks(_buildArgs(address(supplyHook), _createSupplyHookData(COLLATERAL_AMOUNT, false)));

        (, , uint128 collateralStep1) = _getPosition(STRATEGY);
        assertEq(uint256(collateralStep1), COLLATERAL_AMOUNT, "Step 1: collateral supplied");
        console2.log("Collateral after supply:", collateralStep1);

        // Step 2: Borrow
        console2.log("--- Step 2: Borrow ---");
        uint256 borrowAmount = supplyAndBorrowHook.deriveLoanAmount(COLLATERAL_AMOUNT, LTV_RATIO, LLTV, ORACLE);

        bytes memory borrowData = abi.encodePacked(
            LOAN_TOKEN, COLLATERAL_TOKEN, bytes12(0), LOAN_TOKEN, COLLATERAL_TOKEN, ORACLE, IRM, borrowAmount, LTV_RATIO, false, LLTV, false
        );

        vm.prank(MANAGER);
        strategy.executeHooks(_buildArgs(address(borrowHook), borrowData));

        uint256 usdcAfterBorrow = IERC20(LOAN_TOKEN).balanceOf(STRATEGY);
        (, uint128 borrowSharesStep2, ) = _getPosition(STRATEGY);
        assertGt(borrowSharesStep2, 0, "Step 2: should have borrow shares");
        assertGt(usdcAfterBorrow, 0, "Step 2: should have USDC from borrow");
        console2.log("USDC borrowed:", usdcAfterBorrow);

        // Step 3: Full Repay + Withdraw All Collateral
        console2.log("--- Step 3: Repay + Withdraw (combined) ---");
        deal(LOAN_TOKEN, STRATEGY, usdcAfterBorrow * 110 / 100);

        vm.prank(MANAGER);
        strategy.executeHooks(
            _buildArgs(
                address(repayAndWithdrawHook),
                _createRepayAndWithdrawData(0, false, true)
            )
        );

        (, uint128 borrowSharesFinal, uint128 collateralFinal) = _getPosition(STRATEGY);
        assertEq(collateralFinal, 0, "All collateral withdrawn");
        assertEq(borrowSharesFinal, 0, "All borrow repaid");

        uint256 wbtcFinal = IERC20(COLLATERAL_TOKEN).balanceOf(STRATEGY);
        assertEq(wbtcFinal, wbtcInitial, "All WBTC should be returned to vault");

        console2.log("WBTC returned:", wbtcFinal);
        console2.log("Collateral returned:", wbtcFinal - (wbtcInitial - COLLATERAL_AMOUNT));
        console2.log("Full cycle completed successfully");
    }
}
