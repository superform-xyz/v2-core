// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test } from "forge-std/Test.sol";

// Morpho imports
import { Id, MarketParams, Position } from "../../../src/vendor/morpho/IMorpho.sol";
import { IMorphoStaticTyping } from "../../../src/vendor/morpho/IMorpho.sol";
import { MarketParamsLib } from "../../../src/vendor/morpho/MarketParamsLib.sol";

// Superform imports
import { MorphoLendHook } from "../../../src/hooks/loan/morpho/MorphoLendHook.sol";
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

/// @notice Minimal interface for SuperGovernor (to read aggregator address)
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

/// @title MorphoLendE2E
/// @author Superform Labs
/// @notice E2E tests for MorphoLendHook using real deployed SuperVaultStrategy
/// @dev Uses existing MorphoWithdrawHook for withdrawal (calls withdraw() which works for lending positions)
///
/// Real contracts:
///   - Strategy: 0x41A9Eb398518D2487301c61D2b33E4e966A9F1DD (SuperUSDC strategy)
///   - Manager:  0xb3dCDaA89B0A43bcC59a9BDEEb5583EC2071066c
///
/// Mocked (vm.mockCall):
///   - SUPER_GOVERNOR.isHookRegistered(hook) -> true  (freshly deployed hooks aren't registered)
///   - aggregator.isAnyManager(manager, strategy) -> true  (manager authorization)
///   - aggregator.validateHook(strategy, args) -> true  (merkle proof validation)
contract MorphoLendE2E is Test, Constants {
    using MarketParamsLib for MarketParams;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Real deployed SuperVaultStrategy (SuperUSDC)
    address public constant STRATEGY = 0x41A9Eb398518D2487301c61D2b33E4e966A9F1DD;

    /// @notice Real manager for the strategy
    address public constant MANAGER = 0xb3dCDaA89B0A43bcC59a9BDEEb5583EC2071066c;

    MorphoLendHook public lendHook;
    MorphoWithdrawHook public withdrawHook;

    address public superGovernor;
    address public aggregator;

    // WBTC/USDC Morpho Blue market params
    MarketParams public marketParams;
    Id public marketId;

    // Lend amount: 10,000 USDC
    uint256 public constant LEND_AMOUNT = 10_000e6;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        // Fork mainnet
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY));

        // Deploy hooks
        lendHook = new MorphoLendHook(MORPHO);
        withdrawHook = new MorphoWithdrawHook(MORPHO);

        // Read real SuperGovernor from the deployed strategy
        superGovernor = ISuperVaultStrategy(STRATEGY).SUPER_GOVERNOR();

        // Read real aggregator from SuperGovernor
        bytes32 aggregatorKey = ISuperGovernor(superGovernor).SUPER_VAULT_AGGREGATOR();
        aggregator = ISuperGovernor(superGovernor).getAddress(aggregatorKey);

        // Mock: hook registration (freshly deployed hooks aren't registered in SuperGovernor)
        vm.mockCall(
            superGovernor,
            abi.encodeCall(ISuperGovernor.isHookRegistered, (address(lendHook))),
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
        // Use a broad mock - any call to validateHook on the aggregator returns true
        vm.mockCall(
            aggregator,
            abi.encodeWithSelector(ISuperVaultAggregator.validateHook.selector),
            abi.encode(true)
        );

        // Build market params for WBTC/USDC market
        marketParams = MarketParams({
            loanToken: CHAIN_1_USDC,
            collateralToken: CHAIN_1_WBTC,
            oracle: MORPHO_ORACLE_WBTC_USDC,
            irm: MORPHO_IRM_WBTC_USDC,
            lltv: 860000000000000000 // 86% LLTV
        });
        marketId = marketParams.id();
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Build hook data for MorphoLendHook
    function _buildLendHookData(
        uint256 amount,
        bool usePrevHookAmount
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            marketParams.loanToken, // 20 bytes - offset 0
            marketParams.collateralToken, // 20 bytes - offset 20
            marketParams.oracle, // 20 bytes - offset 40
            marketParams.irm, // 20 bytes - offset 60
            amount, // 32 bytes - offset 80
            marketParams.lltv, // 32 bytes - offset 112
            usePrevHookAmount // 1 byte  - offset 144
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
            marketParams.loanToken, // 20 bytes - offset 0
            marketParams.collateralToken, // 20 bytes - offset 20
            marketParams.oracle, // 20 bytes - offset 40
            marketParams.irm, // 20 bytes - offset 60
            marketParams.lltv, // 32 bytes - offset 80
            assets, // 32 bytes - offset 112
            shares // 32 bytes - offset 144
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

        // Empty proof arrays - validateHook is mocked to return true
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

    /// @notice Execute a single lend hook through the real strategy
    function _executeLend(uint256 amount) internal {
        bytes memory hookData = _buildLendHookData(amount, false);

        address[] memory hooks = new address[](1);
        hooks[0] = address(lendHook);

        bytes[] memory hookCalldata = new bytes[](1);
        hookCalldata[0] = hookData;

        uint256[] memory expectedOut = new uint256[](1);
        expectedOut[0] = 0; // NONACCOUNTING hook

        ISuperVaultStrategy.ExecuteArgs memory args = _buildExecuteArgs(hooks, hookCalldata, expectedOut);

        vm.prank(MANAGER);
        ISuperVaultStrategy(STRATEGY).executeHooks(args);
    }

    /// @notice Execute a withdraw hook through the real strategy
    function _executeWithdraw(uint256 assets, uint256 shares) internal {
        bytes memory hookData = _buildWithdrawHookData(assets, shares);

        address[] memory hooks = new address[](1);
        hooks[0] = address(withdrawHook);

        bytes[] memory hookCalldata = new bytes[](1);
        hookCalldata[0] = hookData;

        uint256[] memory expectedOut = new uint256[](1);
        expectedOut[0] = 0;

        ISuperVaultStrategy.ExecuteArgs memory args = _buildExecuteArgs(hooks, hookCalldata, expectedOut);

        vm.prank(MANAGER);
        ISuperVaultStrategy(STRATEGY).executeHooks(args);
    }

    /*//////////////////////////////////////////////////////////////
                              TEST CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice Test: Lend USDC to WBTC/USDC Morpho Blue market
    function test_Lend_SupplyUSDC() public {
        // Fund strategy with USDC
        deal(CHAIN_1_USDC, STRATEGY, LEND_AMOUNT);

        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(STRATEGY);

        // Execute lend
        _executeLend(LEND_AMOUNT);

        // Verify USDC spent
        uint256 usdcAfter = IERC20(CHAIN_1_USDC).balanceOf(STRATEGY);
        assertEq(usdcBefore - usdcAfter, LEND_AMOUNT, "Should spend exact USDC amount");

        // Verify supply shares created on Morpho
        (uint256 supplyShares, uint128 borrowShares, uint128 collateral) =
            IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);

        assertGt(supplyShares, 0, "Should have supply shares");
        assertEq(borrowShares, 0, "Should have no borrow shares");
        assertEq(collateral, 0, "Should have no collateral");

        // Verify outAmount tracks supply shares received (not USDC spent)
        uint256 outAmount = lendHook.getOutAmount(STRATEGY);
        assertEq(outAmount, supplyShares, "outAmount should equal supply shares received");
    }

    /// @notice Test: Full cycle - Lend -> time passes -> withdraw all via shares
    function test_LendAndWithdraw_FullCycle() public {
        // Fund and lend
        deal(CHAIN_1_USDC, STRATEGY, LEND_AMOUNT);
        _executeLend(LEND_AMOUNT);

        // Record supply shares
        (uint256 supplyShares,,) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);
        assertGt(supplyShares, 0, "Should have supply shares after lend");

        // Warp time to accrue interest
        vm.warp(block.timestamp + 30 days);

        // Withdraw all via shares (set assets=0, shares=supplyShares)
        _executeWithdraw(0, supplyShares);

        // Verify position is closed
        (uint256 supplySharesAfter,,) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);
        assertEq(supplySharesAfter, 0, "Should have no supply shares after full withdrawal");

        // Verify USDC received (should be >= LEND_AMOUNT due to interest)
        uint256 usdcBalance = IERC20(CHAIN_1_USDC).balanceOf(STRATEGY);
        assertGe(usdcBalance, LEND_AMOUNT, "Should receive at least the lent amount");

        uint256 interestEarned = usdcBalance - LEND_AMOUNT;
        assertGt(interestEarned, 0, "Should have earned interest over 30 days");
    }

    /// @notice Test: Partial withdrawal via assets
    function test_LendAndWithdraw_Partial() public {
        // Fund and lend
        deal(CHAIN_1_USDC, STRATEGY, LEND_AMOUNT);
        _executeLend(LEND_AMOUNT);

        (uint256 supplySharesBefore,,) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);

        // Withdraw half via assets (set assets=5000e6, shares=0)
        uint256 partialAmount = LEND_AMOUNT / 2;
        _executeWithdraw(partialAmount, 0);

        // Verify partial position remains
        (uint256 supplySharesAfter,,) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);
        assertGt(supplySharesAfter, 0, "Should still have supply shares");
        assertLt(supplySharesAfter, supplySharesBefore, "Should have fewer supply shares");

        // Verify USDC received
        uint256 usdcBalance = IERC20(CHAIN_1_USDC).balanceOf(STRATEGY);
        assertEq(usdcBalance, partialAmount, "Should receive partial amount");
    }

    /// @notice Test: Lend with usePrevHookAmount (chained from previous hook)
    function test_Lend_WithPrevHookAmount() public {
        uint256 mockPrevAmount = 5000e6; // 5000 USDC from previous hook

        // Fund strategy
        deal(CHAIN_1_USDC, STRATEGY, mockPrevAmount);

        // Create mock previous hook that returns mockPrevAmount
        MockPrevHookForLend mockPrevHook = new MockPrevHookForLend(mockPrevAmount);

        // Mock hook registration for the mock prev hook too
        vm.mockCall(
            superGovernor,
            abi.encodeCall(ISuperGovernor.isHookRegistered, (address(mockPrevHook))),
            abi.encode(true)
        );

        // Build lend data with usePrevHookAmount = true
        // amount field is set to a different value to prove usePrevHookAmount overrides it
        bytes memory lendData = _buildLendHookData(999e6, true);

        // Build executeHooks args with two hooks chained
        address[] memory hooks = new address[](2);
        hooks[0] = address(mockPrevHook);
        hooks[1] = address(lendHook);

        bytes[] memory hookCalldata = new bytes[](2);
        // Strategy's _processSingleHookExecution calls extractYieldSource(hookCalldata) which reads
        // BytesLib.toAddress(data, 32), so we need at least 52 bytes of data even for the mock hook
        hookCalldata[0] = abi.encodePacked(bytes32(0), address(0));
        hookCalldata[1] = lendData;

        uint256[] memory expectedOut = new uint256[](2);
        expectedOut[0] = 0;
        expectedOut[1] = 0;

        ISuperVaultStrategy.ExecuteArgs memory args = _buildExecuteArgs(hooks, hookCalldata, expectedOut);

        vm.prank(MANAGER);
        ISuperVaultStrategy(STRATEGY).executeHooks(args);

        // Verify supply shares created
        (uint256 supplyShares,,) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);
        assertGt(supplyShares, 0, "Should have supply shares");

        // Verify outAmount matches supply shares received (not token amount)
        uint256 outAmount = lendHook.getOutAmount(STRATEGY);
        assertEq(outAmount, supplyShares, "outAmount should equal supply shares received");

        // Verify USDC spent is prev hook amount
        uint256 usdcRemaining = IERC20(CHAIN_1_USDC).balanceOf(STRATEGY);
        assertEq(usdcRemaining, 0, "Should have spent all USDC from prev hook amount");
    }

    /// @notice Test: Multiple sequential lends accumulate supply shares
    function test_Lend_MultipleLends() public {
        uint256 firstLend = 5000e6;
        uint256 secondLend = 3000e6;

        // Fund and first lend
        deal(CHAIN_1_USDC, STRATEGY, firstLend + secondLend);
        _executeLend(firstLend);

        (uint256 sharesAfterFirst,,) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);
        assertGt(sharesAfterFirst, 0, "Should have shares after first lend");

        // Second lend
        _executeLend(secondLend);

        (uint256 sharesAfterSecond,,) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);
        assertGt(sharesAfterSecond, sharesAfterFirst, "Shares should increase after second lend");

        // All USDC should be spent
        uint256 usdcRemaining = IERC20(CHAIN_1_USDC).balanceOf(STRATEGY);
        assertEq(usdcRemaining, 0, "All USDC should be lent");
    }

    /// @notice Test: Multiple partial withdrawals drain position in chunks
    function test_LendAndWithdraw_MultiplePartials() public {
        deal(CHAIN_1_USDC, STRATEGY, LEND_AMOUNT);
        _executeLend(LEND_AMOUNT);

        (uint256 totalShares,,) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);

        // First partial withdraw: 30%
        uint256 firstWithdraw = 3000e6;
        _executeWithdraw(firstWithdraw, 0);

        (uint256 sharesAfterFirst,,) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);
        assertLt(sharesAfterFirst, totalShares, "Shares should decrease after first withdrawal");

        // Second partial withdraw: 30%
        uint256 secondWithdraw = 3000e6;
        _executeWithdraw(secondWithdraw, 0);

        (uint256 sharesAfterSecond,,) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);
        assertLt(sharesAfterSecond, sharesAfterFirst, "Shares should decrease after second withdrawal");
        assertGt(sharesAfterSecond, 0, "Should still have remaining shares");

        // Final withdraw: remaining via shares
        _executeWithdraw(0, sharesAfterSecond);

        (uint256 sharesAfterFinal,,) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);
        assertEq(sharesAfterFinal, 0, "All shares should be withdrawn");

        // Verify total USDC recovered ~= original (Morpho share math can round down by 1 wei per operation)
        uint256 usdcBalance = IERC20(CHAIN_1_USDC).balanceOf(STRATEGY);
        assertApproxEqAbs(usdcBalance, LEND_AMOUNT, 3, "Should recover approximately the original amount");
    }

    /// @notice Test: Minimum amount lend (1 USDC)
    function test_Lend_MinAmount() public {
        uint256 minAmount = 1e6; // 1 USDC
        deal(CHAIN_1_USDC, STRATEGY, minAmount);
        _executeLend(minAmount);

        (uint256 supplyShares,,) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);
        assertGt(supplyShares, 0, "Should have supply shares for min amount");

        uint256 usdcRemaining = IERC20(CHAIN_1_USDC).balanceOf(STRATEGY);
        assertEq(usdcRemaining, 0, "All USDC should be lent");
    }

    /// @notice Test: Lend + Withdraw chained in single executeHooks call
    function test_LendAndWithdraw_Chained() public {
        // First lend to create position
        deal(CHAIN_1_USDC, STRATEGY, LEND_AMOUNT);
        _executeLend(LEND_AMOUNT);

        (uint256 supplyShares,,) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);
        assertGt(supplyShares, 0, "Should have shares before chained withdraw");

        // Now lend more + withdraw the original in a single executeHooks call
        uint256 secondLend = 2000e6;
        deal(CHAIN_1_USDC, STRATEGY, secondLend);

        bytes memory lendData = _buildLendHookData(secondLend, false);
        bytes memory withdrawData = _buildWithdrawHookData(0, supplyShares);

        address[] memory hooks = new address[](2);
        hooks[0] = address(lendHook);
        hooks[1] = address(withdrawHook);

        bytes[] memory hookCalldata = new bytes[](2);
        hookCalldata[0] = lendData;
        hookCalldata[1] = withdrawData;

        uint256[] memory expectedOut = new uint256[](2);
        expectedOut[0] = 0;
        expectedOut[1] = 0;

        ISuperVaultStrategy.ExecuteArgs memory args = _buildExecuteArgs(hooks, hookCalldata, expectedOut);

        vm.prank(MANAGER);
        ISuperVaultStrategy(STRATEGY).executeHooks(args);

        // After: should have only secondLend worth of shares (original withdrawn, new added)
        (uint256 sharesAfter,,) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);
        assertGt(sharesAfter, 0, "Should have shares from second lend");

        // USDC balance should be ~= LEND_AMOUNT (original withdrawal proceeds, rounding tolerance)
        uint256 usdcBalance = IERC20(CHAIN_1_USDC).balanceOf(STRATEGY);
        assertApproxEqAbs(usdcBalance, LEND_AMOUNT, 2, "Should have withdrawn original lend amount");
    }

    /// @notice Test: Interest accrual over time periods
    function test_Lend_InterestAccrual() public {
        deal(CHAIN_1_USDC, STRATEGY, LEND_AMOUNT);
        _executeLend(LEND_AMOUNT);

        (uint256 supplyShares,,) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);

        // Warp 7 days
        vm.warp(block.timestamp + 7 days);
        _executeWithdraw(0, supplyShares / 2);

        uint256 usdcAfter7Days = IERC20(CHAIN_1_USDC).balanceOf(STRATEGY);

        // Half shares should return at least half the original (due to interest)
        assertGe(usdcAfter7Days, LEND_AMOUNT / 2, "Half withdrawal should return at least half amount");

        // Warp another 23 days (total 30 days)
        vm.warp(block.timestamp + 23 days);

        (uint256 remainingShares,,) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);
        _executeWithdraw(0, remainingShares);

        uint256 totalRecovered = IERC20(CHAIN_1_USDC).balanceOf(STRATEGY);
        assertGt(totalRecovered, LEND_AMOUNT, "Total recovered should exceed original due to interest");
    }

    /// @notice Test: Revert when amount is zero
    function test_Lend_RevertsWhenAmountZero() public {
        bytes memory hookData = _buildLendHookData(0, false);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        lendHook.build(address(0), STRATEGY, hookData);
    }

    /// @notice Test: Revert when loanToken address is zero
    function test_Lend_RevertsWhenAddressZero() public {
        bytes memory hookData = abi.encodePacked(
            address(0), // loanToken = zero
            marketParams.collateralToken,
            marketParams.oracle,
            marketParams.irm,
            uint256(1000e6),
            marketParams.lltv,
            false
        );

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        lendHook.build(address(0), STRATEGY, hookData);
    }
}

/// @notice Mock contract to simulate previous hook returning specific amounts
/// @dev This is the only mock - used to test usePrevHookAmount chaining.
///      It simulates a hook that has already executed and has an outAmount ready.
contract MockPrevHookForLend {
    uint256 private _outAmount;

    constructor(uint256 outAmount_) {
        _outAmount = outAmount_;
    }

    function setExecutionContext(address) external { }

    function build(address, address account, bytes calldata) external view returns (Execution[] memory executions) {
        executions = new Execution[](2);
        executions[0] = Execution({
            target: address(this),
            value: 0,
            callData: abi.encodeCall(this.preExecute, (address(0), account, ""))
        });
        executions[1] = Execution({
            target: address(this),
            value: 0,
            callData: abi.encodeCall(this.postExecute, (address(0), account, ""))
        });
    }

    function preExecute(address, address, bytes calldata) external { }

    function postExecute(address, address, bytes calldata) external { }

    function resetExecutionState(address) external { }

    function getOutAmount(address) external view returns (uint256) {
        return _outAmount;
    }

    function inspect(bytes calldata) external pure returns (bytes memory) {
        return "";
    }
}

import { Execution } from "../../../src/interfaces/ISuperHook.sol";
