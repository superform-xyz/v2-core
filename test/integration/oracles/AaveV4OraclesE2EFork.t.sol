// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { AaveV4ReserveRegistry } from "../../../src/accounting/oracles/AaveV4ReserveRegistry.sol";
import { AaveV4DebtOracle } from "../../../src/accounting/oracles/AaveV4DebtOracle.sol";
import { AaveV4SupplyYieldSourceOracle } from "../../../src/accounting/oracles/AaveV4SupplyYieldSourceOracle.sol";
import { IAaveV4Spoke } from "../../../src/vendor/aave-v4/IAaveV4Spoke.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { SuperLedger } from "../../../src/accounting/SuperLedger.sol";
import { AaveV4SupplyAndBorrowHookV2 } from "../../../src/hooks/loan/aave-v4/AaveV4SupplyAndBorrowHookV2.sol";
import { AaveV4RepayHookV2 } from "../../../src/hooks/loan/aave-v4/AaveV4RepayHookV2.sol";
import { AaveV4RepayAndWithdrawHookV2 } from "../../../src/hooks/loan/aave-v4/AaveV4RepayAndWithdrawHookV2.sol";
import { TransferAaveV4ReserveRegistryRoles } from "../../../script/TransferAaveV4ReserveRegistryRoles.s.sol";

/// @dev Exposes the role-handoff script's internal address constants so the E2E tests stay in
///      lockstep with the actual script — a script address change breaks these tests
contract TransferRolesHarness is TransferAaveV4ReserveRegistryRoles {
    function governor() external pure returns (address) {
        return GOVERNOR;
    }

    function superGovernor(uint64 chainId) external pure returns (address) {
        return _getSuperGovernor(chainId);
    }

    function deployerAddr() external pure returns (address) {
        return DEPLOYER;
    }
}

/// @dev Ledger mock treating the ENTIRE amount as profit — the adversarial config that would
///      inflate quotes through the inherited fee view if the bypass override were missing
contract MockZeroCostBasisLedgerE2E {
    function previewFees(
        address,
        address,
        uint256 amountAssets,
        uint256,
        uint256 feePercent,
        uint256,
        uint256
    )
        external
        pure
        returns (uint256)
    {
        return amountAssets * feePercent / 10_000;
    }
}

/// @notice End-to-end fork tests for the Aave V4 accounting oracles against the live Ethereum
///         Main Spoke, exercising ALL 14 live reserves at the pinned block plus full position
///         lifecycles — both via direct spoke self-calls and via the real V2 loan hooks.
/// @dev Reserve map at block 24_884_274 (probed on-chain):
///         0 WETH  1 wstETH  2 weETH  3 WBTC(8dec)  4 cbBTC(8dec)  5 AAVE  6 LINK
///         7 USDC(6dec)  8 USDT(6dec)  9 EURC(6dec)  10 RLUSD  11 USDG(6dec)  12 frxUSD  13 GHO
///      Real aggregates at the block: USDC reserve carries ~864k drawn debt / ~1.72M supplied.
///      WARP NOTE: tests that warp 30-180 days and then mutate (repay/withdraw/borrow) pass
///      because the V4 price layer at this block performs no Chainlink staleness enforcement
///      (empirically verified; consistent with the historical AaveOracle design). If Aave ever
///      ships staleness-guarded adapters via a spoke/oracle upgrade, the warped mutation calls
///      here will start reverting — re-pin the block and mock prices if that happens.
contract AaveV4OraclesE2EForkTest is Test {
    // Live Ethereum mainnet Aave V4 Main Spoke
    address internal constant SPOKE = 0x94e7A5dCbE816e498b89aB752661904E2F56c485;
    uint256 internal constant AAVE_V4_BLOCK = 24_884_274;

    // Real underlyings (probed from the spoke at the pinned block)
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address internal constant WEETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address internal constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address internal constant AAVE = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
    address internal constant LINK = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant EURC = 0x1aBaEA1f7C830bD89Acc67eC4af516284b1bC33c;
    address internal constant RLUSD = 0x8292Bb45bf1Ee4d140127049757C2E0fF06317eD;
    address internal constant USDG = 0xe343167631d89B6Ffc58B88d6b7fB0228795491D;
    address internal constant FRXUSD = 0xCAcd6fd266aF91b8AeD52aCCc382b4e165586E29;
    address internal constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;

    uint256 internal constant LIVE_RESERVE_COUNT = 14;

    AaveV4ReserveRegistry internal registry;
    AaveV4DebtOracle internal debtOracle;
    AaveV4SupplyYieldSourceOracle internal supplyOracle;
    address internal ledgerConfig;

    AaveV4SupplyAndBorrowHookV2 internal openHook;
    AaveV4RepayHookV2 internal repayHook;
    AaveV4RepayAndWithdrawHookV2 internal closeHook;

    address[] internal underlyings;
    address[] internal keys; // reserveKey per id, index == reserveId

    address internal user1 = makeAddr("e2eUser1");
    address internal user2 = makeAddr("e2eUser2");

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"), AAVE_V4_BLOCK);

        ledgerConfig = address(new SuperLedgerConfiguration());
        registry = new AaveV4ReserveRegistry(address(this));
        debtOracle = new AaveV4DebtOracle(ledgerConfig, address(registry));
        supplyOracle = new AaveV4SupplyYieldSourceOracle(ledgerConfig, address(registry));

        openHook = new AaveV4SupplyAndBorrowHookV2();
        repayHook = new AaveV4RepayHookV2();
        closeHook = new AaveV4RepayAndWithdrawHookV2();

        underlyings = new address[](LIVE_RESERVE_COUNT);
        underlyings[0] = WETH;
        underlyings[1] = WSTETH;
        underlyings[2] = WEETH;
        underlyings[3] = WBTC;
        underlyings[4] = CBBTC;
        underlyings[5] = AAVE;
        underlyings[6] = LINK;
        underlyings[7] = USDC;
        underlyings[8] = USDT;
        underlyings[9] = EURC;
        underlyings[10] = RLUSD;
        underlyings[11] = USDG;
        underlyings[12] = FRXUSD;
        underlyings[13] = GHO;

        keys = new address[](LIVE_RESERVE_COUNT);
        for (uint256 id; id < LIVE_RESERVE_COUNT; ++id) {
            keys[id] = registry.registerReserve(SPOKE, id);
        }
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Approve via raw call so non-standard tokens (USDT returns no bool) work uniformly
    function _approve(address token, address owner, address spender, uint256 amount) internal {
        vm.prank(owner);
        (bool ok,) = token.call(abi.encodeWithSelector(IERC20.approve.selector, spender, amount));
        require(ok, "approve failed");
    }

    /// @dev Opens a real position via direct spoke self-calls (onlyPositionManager allows self)
    function _openPosition(
        address account,
        address collateral,
        uint256 collateralReserveId,
        uint256 supplyAmount,
        uint256 borrowReserveId,
        uint256 borrowAmount
    )
        internal
    {
        deal(collateral, account, supplyAmount);
        _approve(collateral, account, SPOKE, supplyAmount);
        vm.startPrank(account);
        IAaveV4Spoke(SPOKE).supply(collateralReserveId, supplyAmount, account);
        IAaveV4Spoke(SPOKE).setUsingAsCollateral(collateralReserveId, true, account);
        IAaveV4Spoke(SPOKE).borrow(borrowReserveId, borrowAmount, account);
        vm.stopPrank();
    }

    /// @dev Canonical 241-byte Aave V4 V2 hook data layout
    function _hookData(
        address loanToken,
        address collateralToken,
        uint256 supplyReserveId,
        uint256 borrowReserveId,
        uint256 amount1,
        uint256 amount2
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            bytes32(0),
            address(0),
            loanToken,
            collateralToken,
            SPOKE,
            supplyReserveId,
            borrowReserveId,
            amount1,
            amount2,
            uint8(0)
        );
    }

    /// @dev Executes a hook's built sequence exactly as the smart account would: every call,
    ///      including preExecute and postExecute, originates from `account`
    function _executeAs(address account, Execution[] memory executions) internal {
        for (uint256 i; i < executions.length; ++i) {
            vm.prank(account);
            (bool ok, bytes memory ret) =
                executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            require(ok, string(ret));
        }
    }

    /*//////////////////////////////////////////////////////////////
              A. FULL-MARKET REGISTRATION (ALL 14 LIVE RESERVES)
    //////////////////////////////////////////////////////////////*/

    /// @notice Every live reserve registers, and the stored bindings match both the spoke's
    ///         Reserve struct AND the underlying token's own ERC20 metadata
    function test_E2E_RegisterAllLiveReserves_BindingsMatchOnChain() public {
        for (uint256 id; id < LIVE_RESERVE_COUNT; ++id) {
            (address spoke_, uint256 reserveId_, address underlying_, uint8 dec_) = registry.getReserveInfo(keys[id]);
            assertEq(spoke_, SPOKE);
            assertEq(reserveId_, id);
            assertEq(underlying_, underlyings[id], "underlying mismatch vs probed map");
            assertEq(dec_, IERC20Metadata(underlyings[id]).decimals(), "decimals mismatch vs token metadata");
            assertEq(keys[id], registry.computeReserveKey(SPOKE, id), "key derivation parity");
            assertTrue(registry.isRegistered(keys[id]));
        }
        // id 14 is genuinely unlisted at this block
        vm.expectRevert();
        registry.registerReserve(SPOKE, LIVE_RESERVE_COUNT);
    }

    /// @notice Batch views work across ALL live reserves at once (every key registered → no aborts)
    function test_E2E_BatchViews_AllLiveReserves() public view {
        uint256[] memory pps = debtOracle.getPricePerShareMultiple(keys);
        uint256[] memory debtTvls = debtOracle.getTVLMultiple(keys);
        uint256[] memory supplyTvls = supplyOracle.getTVLMultiple(keys);

        for (uint256 id; id < LIVE_RESERVE_COUNT; ++id) {
            assertEq(pps[id], 10 ** IERC20Metadata(underlyings[id]).decimals(), "identity PPS per reserve");
            // Aggregates are internally consistent: a reserve with outstanding debt has suppliers
            if (debtTvls[id] > 0) {
                assertGt(supplyTvls[id], 0, "debt without supply is impossible");
            }
        }

        // Majors carry live liquidity at the pinned block
        assertGt(supplyTvls[0], 0, "WETH supplied");
        assertGt(supplyTvls[1], 0, "wstETH supplied");
        assertGt(supplyTvls[7], 0, "USDC supplied");
    }

    /// @notice Pins the real USDC reserve aggregates at the block (probed: ~864k debt, ~1.72M supplied)
    function test_E2E_RealAggregates_USDCReserve() public view {
        assertGt(debtOracle.getTVL(keys[7]), 500_000e6, "USDC reserve has substantial live debt");
        assertGt(supplyOracle.getTVL(keys[7]), 1_000_000e6, "USDC reserve has substantial live supply");
        assertGt(supplyOracle.getTVL(keys[7]), debtOracle.getTVL(keys[7]), "supplied exceeds borrowed");
    }

    /// @notice Batch TVL-by-owner across mixed reserves and users: values match single calls,
    ///         succeeded flags all true (every key registered)
    function test_E2E_BatchTVLByOwner_MixedUsersAndReserves() public {
        _openPosition(user1, WETH, 0, 10 ether, 7, 5000e6);
        _openPosition(user2, WSTETH, 1, 10 ether, 8, 3000e6);

        address[] memory sources = new address[](3);
        sources[0] = keys[7]; // USDC debt
        sources[1] = keys[8]; // USDT debt
        sources[2] = keys[0]; // WETH supply — read through the DEBT oracle: zero debt for both
        address[][] memory owners = new address[][](3);
        for (uint256 i; i < 3; ++i) {
            owners[i] = new address[](2);
            owners[i][0] = user1;
            owners[i][1] = user2;
        }

        (uint256[][] memory tvls, bool[][] memory ok) = debtOracle.getTVLByOwnerOfSharesMultiple(sources, owners);
        assertEq(tvls[0][0], debtOracle.getBalanceOfOwner(keys[7], user1), "batch == single");
        assertGe(tvls[0][0], 5000e6);
        assertEq(tvls[0][1], 0, "user2 has no USDC debt");
        assertEq(tvls[1][0], 0, "user1 has no USDT debt");
        assertGe(tvls[1][1], 3000e6, "user2 USDT debt");
        assertEq(tvls[2][0], 0, "no WETH debt for user1");
        for (uint256 i; i < 3; ++i) {
            assertTrue(ok[i][0]);
            assertTrue(ok[i][1]);
        }
    }

    /*//////////////////////////////////////////////////////////////
            B. MULTI-USER / MULTI-RESERVE POSITION LIFECYCLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Two users on different collateral/debt reserves: the oracles isolate balances
    ///         per (key, owner) with zero cross-contamination
    function test_E2E_TwoUsers_IsolatedBalances() public {
        _openPosition(user1, WETH, 0, 10 ether, 7, 5000e6);
        _openPosition(user2, WSTETH, 1, 10 ether, 8, 3000e6);

        // user1: WETH supply + USDC debt only
        assertGt(supplyOracle.getBalanceOfOwner(keys[0], user1), 0);
        assertGe(debtOracle.getBalanceOfOwner(keys[7], user1), 5000e6);
        assertEq(supplyOracle.getBalanceOfOwner(keys[1], user1), 0);
        assertEq(debtOracle.getBalanceOfOwner(keys[8], user1), 0);

        // user2: wstETH supply + USDT debt only
        assertGt(supplyOracle.getBalanceOfOwner(keys[1], user2), 0);
        assertGe(debtOracle.getBalanceOfOwner(keys[8], user2), 3000e6);
        assertEq(supplyOracle.getBalanceOfOwner(keys[0], user2), 0);
        assertEq(debtOracle.getBalanceOfOwner(keys[7], user2), 0);

        // Invariant: reserve-level TVL always covers any single user's position (both oracles)
        assertGe(debtOracle.getTVL(keys[7]), debtOracle.getBalanceOfOwner(keys[7], user1));
        assertGe(debtOracle.getTVL(keys[8]), debtOracle.getBalanceOfOwner(keys[8], user2));
        assertGe(supplyOracle.getTVL(keys[0]), supplyOracle.getBalanceOfOwner(keys[0], user1));
        assertGe(supplyOracle.getTVL(keys[1]), supplyOracle.getBalanceOfOwner(keys[1], user2));
    }

    /// @notice 8-decimal collateral (WBTC): PPS = 1e8 and the supplied read round-trips
    function test_E2E_WBTC_8Decimals_Lifecycle() public {
        assertEq(supplyOracle.getPricePerShare(keys[3]), 1e8);
        assertEq(debtOracle.getPricePerShare(keys[3]), 1e8);

        _openPosition(user1, WBTC, 3, 1e8, 7, 10_000e6);

        uint256 supplied = supplyOracle.getBalanceOfOwner(keys[3], user1);
        assertGt(supplied, 0);
        assertLe(supplied, 1e8, "supply rounds down at source");
        assertGe(debtOracle.getBalanceOfOwner(keys[7], user1), 10_000e6);
    }

    /// @notice Partial repay: the oracle's debt delta equals the repaid amount (±1 wei rounding)
    function test_E2E_PartialRepay_ExactOracleDelta() public {
        _openPosition(user1, WETH, 0, 10 ether, 7, 5000e6);
        vm.warp(block.timestamp + 30 days);

        uint256 debtBefore = debtOracle.getBalanceOfOwner(keys[7], user1);
        uint256 repayAmount = 2000e6;

        deal(USDC, user1, repayAmount);
        _approve(USDC, user1, SPOKE, repayAmount);
        vm.prank(user1);
        IAaveV4Spoke(SPOKE).repay(7, repayAmount, user1);

        uint256 debtAfter = debtOracle.getBalanceOfOwner(keys[7], user1);
        assertApproxEqAbs(debtBefore - debtAfter, repayAmount, 1, "debt delta equals repaid amount");
        assertGt(debtAfter, 0, "residual debt remains");
        // supply leg untouched by repay
        assertGt(supplyOracle.getBalanceOfOwner(keys[0], user1), 0);
    }

    /// @notice Partial withdraw: the oracle's supplied delta equals the withdrawn assets (±1 wei)
    function test_E2E_PartialWithdraw_ExactOracleDelta() public {
        _openPosition(user1, WETH, 0, 10 ether, 7, 1000e6); // low LTV so a partial withdraw stays healthy

        uint256 suppliedBefore = supplyOracle.getBalanceOfOwner(keys[0], user1);
        uint256 walletBefore = IERC20(WETH).balanceOf(user1);

        vm.prank(user1);
        (, uint256 assetsOut) = IAaveV4Spoke(SPOKE).withdraw(0, 2 ether, user1);

        assertEq(IERC20(WETH).balanceOf(user1) - walletBefore, assetsOut, "wallet received what spoke reports");
        uint256 suppliedAfter = supplyOracle.getBalanceOfOwner(keys[0], user1);
        assertApproxEqAbs(suppliedBefore - suppliedAfter, assetsOut, 1, "supplied delta equals withdrawn assets");
    }

    /// @notice Borrowing more strictly increases the oracle-read debt by the borrowed amount (±1 wei)
    function test_E2E_BorrowMore_DebtIncreases() public {
        _openPosition(user1, WETH, 0, 10 ether, 7, 2000e6);
        uint256 debtBefore = debtOracle.getBalanceOfOwner(keys[7], user1);

        vm.prank(user1);
        IAaveV4Spoke(SPOKE).borrow(7, 1500e6, user1);

        assertApproxEqAbs(
            debtOracle.getBalanceOfOwner(keys[7], user1) - debtBefore, 1500e6, 1, "debt grew by the borrow"
        );
    }

    /// @notice Full close (repay max + withdraw max): BOTH oracles read exactly zero afterwards
    function test_E2E_FullClose_BothOraclesReadZero() public {
        _openPosition(user1, WETH, 0, 10 ether, 7, 5000e6);
        vm.warp(block.timestamp + 60 days);

        uint256 debt = debtOracle.getBalanceOfOwner(keys[7], user1);
        deal(USDC, user1, debt * 2);
        _approve(USDC, user1, SPOKE, type(uint256).max);

        vm.startPrank(user1);
        IAaveV4Spoke(SPOKE).repay(7, type(uint256).max, user1);
        IAaveV4Spoke(SPOKE).withdraw(0, type(uint256).max, user1);
        vm.stopPrank();

        assertEq(debtOracle.getBalanceOfOwner(keys[7], user1), 0, "debt cleared exactly");
        assertEq(supplyOracle.getBalanceOfOwner(keys[0], user1), 0, "supply cleared exactly");
        assertGt(IERC20(WETH).balanceOf(user1), 0, "collateral (plus yield) back in wallet");
    }

    /// @notice Accrual is monotonic across multiple checkpoints with zero state-touching calls —
    ///         debt never under-reports between reads
    function test_E2E_Accrual_MonotonicCheckpoints() public {
        _openPosition(user1, WETH, 0, 10 ether, 7, 5000e6);

        uint256 prevDebt = debtOracle.getBalanceOfOwner(keys[7], user1);
        uint256 prevSupplied = supplyOracle.getBalanceOfOwner(keys[0], user1);

        uint256[4] memory warps = [uint256(1 hours), 1 days, 30 days, 180 days];
        for (uint256 i; i < warps.length; ++i) {
            vm.warp(block.timestamp + warps[i]);
            uint256 debt = debtOracle.getBalanceOfOwner(keys[7], user1);
            uint256 supplied = supplyOracle.getBalanceOfOwner(keys[0], user1);
            assertGe(debt, prevDebt, "debt monotonic non-decreasing under pure accrual");
            assertGe(supplied, prevSupplied, "supplied monotonic non-decreasing under pure accrual");
            prevDebt = debt;
            prevSupplied = supplied;
        }
        assertGt(prevDebt, 5000e6, "interest actually accrued over 211 days");
    }

    /// @notice Documents real drawn/premium behavior: oracle total is always the exact component
    ///         sum, before and after accrual
    function test_E2E_PremiumComponents_SumParity() public {
        _openPosition(user1, WETH, 0, 10 ether, 7, 5000e6);

        (uint256 drawn0, uint256 premium0) = IAaveV4Spoke(SPOKE).getUserDebt(7, user1);
        assertEq(debtOracle.getBalanceOfOwner(keys[7], user1), drawn0 + premium0);

        vm.warp(block.timestamp + 90 days);
        (uint256 drawn1, uint256 premium1) = IAaveV4Spoke(SPOKE).getUserDebt(7, user1);
        assertEq(debtOracle.getBalanceOfOwner(keys[7], user1), drawn1 + premium1);
        assertGt(drawn1, drawn0, "drawn debt accrued");
    }

    /// @notice Non-standard ERC20 (USDT, no bool return) as the debt asset: full lifecycle
    function test_E2E_USDT_NonStandardToken_Lifecycle() public {
        _openPosition(user1, WETH, 0, 10 ether, 8, 3000e6);
        assertGe(debtOracle.getBalanceOfOwner(keys[8], user1), 3000e6);

        vm.warp(block.timestamp + 30 days);
        uint256 debt = debtOracle.getBalanceOfOwner(keys[8], user1);
        deal(USDT, user1, debt * 2);
        _approve(USDT, user1, SPOKE, debt * 2);
        vm.prank(user1);
        IAaveV4Spoke(SPOKE).repay(8, type(uint256).max, user1);

        assertEq(debtOracle.getBalanceOfOwner(keys[8], user1), 0, "USDT debt cleared exactly");
    }

    /*//////////////////////////////////////////////////////////////
                C. HOOK-DRIVEN E2E (REAL V2 LOAN HOOKS)
    //////////////////////////////////////////////////////////////*/

    /// @notice Open via AaveV4SupplyAndBorrowHookV2's built executions: the oracles agree with
    ///         the hook-observed state and the wallet deltas
    function test_E2E_HookOpen_OracleConsistency() public {
        uint256 supplyAmount = 10 ether;
        uint256 borrowAmount = 5000e6;
        deal(WETH, user1, supplyAmount);

        bytes memory data = _hookData(USDC, WETH, 0, 7, supplyAmount, borrowAmount);
        Execution[] memory executions = openHook.build(address(0), user1, data);
        uint256 usdcBefore = IERC20(USDC).balanceOf(user1);

        _executeAs(user1, executions);

        // Wallet deltas match the intent
        assertEq(IERC20(USDC).balanceOf(user1) - usdcBefore, borrowAmount, "borrowed USDC in wallet");
        assertEq(IERC20(WETH).balanceOf(user1), 0, "collateral fully supplied");

        // Oracles agree with the raw spoke reads the hooks use
        (uint256 drawn, uint256 premium) = IAaveV4Spoke(SPOKE).getUserDebt(7, user1);
        assertEq(debtOracle.getBalanceOfOwner(keys[7], user1), drawn + premium, "oracle == hook _totalDebt read");
        assertEq(
            supplyOracle.getBalanceOfOwner(keys[0], user1),
            IAaveV4Spoke(SPOKE).getUserSuppliedAssets(0, user1),
            "oracle == hook _suppliedAssets read"
        );
        assertGe(debtOracle.getBalanceOfOwner(keys[7], user1), borrowAmount);
    }

    /// @notice Hook-driven partial repay: the oracle's debt delta equals the hook's exact repay
    ///         amount and the allowance is reset
    function test_E2E_HookPartialRepay_OracleDelta() public {
        _openPosition(user1, WETH, 0, 10 ether, 7, 5000e6);
        vm.warp(block.timestamp + 30 days);

        uint256 repayAmount = 1500e6;
        deal(USDC, user1, repayAmount);
        uint256 debtBefore = debtOracle.getBalanceOfOwner(keys[7], user1);

        bytes memory data = _hookData(USDC, WETH, 0, 7, repayAmount, 0);
        _executeAs(user1, repayHook.build(address(0), user1, data));

        assertApproxEqAbs(
            debtBefore - debtOracle.getBalanceOfOwner(keys[7], user1), repayAmount, 1, "oracle delta == hook repay"
        );
        assertEq(IERC20(USDC).allowance(user1, SPOKE), 0, "allowance reset by hook");
        assertEq(IERC20(USDC).balanceOf(user1), 0, "exact spend");
    }

    /// @notice Full hook lifecycle: open via hook, accrue, close via hook (max repay + max
    ///         withdraw) — both oracles read exactly zero and the wallet holds collateral + yield
    function test_E2E_HookOpen_Warp_HookCloseMax_OraclesReadZero() public {
        uint256 supplyAmount = 10 ether;
        deal(WETH, user1, supplyAmount);
        _executeAs(user1, openHook.build(address(0), user1, _hookData(USDC, WETH, 0, 7, supplyAmount, 5000e6)));

        vm.warp(block.timestamp + 30 days);

        uint256 debt = debtOracle.getBalanceOfOwner(keys[7], user1);
        assertGt(debt, 5000e6, "interest accrued");
        deal(USDC, user1, debt + 100e6); // cover accrued interest

        bytes memory closeData = _hookData(USDC, WETH, 0, 7, type(uint256).max, type(uint256).max);
        _executeAs(user1, closeHook.build(address(0), user1, closeData));

        assertEq(debtOracle.getBalanceOfOwner(keys[7], user1), 0, "debt oracle reads zero after close");
        assertEq(supplyOracle.getBalanceOfOwner(keys[0], user1), 0, "supply oracle reads zero after close");
        assertGe(IERC20(WETH).balanceOf(user1), supplyAmount, "collateral plus supply yield returned");
        assertEq(IERC20(USDC).allowance(user1, SPOKE), 0, "allowance reset");
    }

    /// @notice Debt parity holds at EVERY lifecycle stage between the oracle and the raw
    ///         drawn+premium read the hooks resolve against
    function test_E2E_HookOracleParity_AllStages() public {
        // Stage 0: no position
        assertEq(debtOracle.getBalanceOfOwner(keys[7], user1), 0);

        // Stage 1: open
        deal(WETH, user1, 10 ether);
        _executeAs(user1, openHook.build(address(0), user1, _hookData(USDC, WETH, 0, 7, 10 ether, 4000e6)));
        (uint256 d, uint256 p) = IAaveV4Spoke(SPOKE).getUserDebt(7, user1);
        assertEq(debtOracle.getBalanceOfOwner(keys[7], user1), d + p);

        // Stage 2: accrual
        vm.warp(block.timestamp + 45 days);
        (d, p) = IAaveV4Spoke(SPOKE).getUserDebt(7, user1);
        assertEq(debtOracle.getBalanceOfOwner(keys[7], user1), d + p);

        // Stage 3: partial hook repay
        deal(USDC, user1, 1000e6);
        _executeAs(user1, repayHook.build(address(0), user1, _hookData(USDC, WETH, 0, 7, 1000e6, 0)));
        (d, p) = IAaveV4Spoke(SPOKE).getUserDebt(7, user1);
        assertEq(debtOracle.getBalanceOfOwner(keys[7], user1), d + p);
        assertGt(d + p, 0, "residual debt");
    }

    /*//////////////////////////////////////////////////////////////
                D. REGISTRY LIFECYCLE ON REAL RESERVES
    //////////////////////////////////////////////////////////////*/

    /// @notice Re-registering a live reserve reverts (no overwrite, real spoke)
    function test_E2E_Registry_DuplicateLiveReserve_Reverts() public {
        vm.expectRevert(AaveV4ReserveRegistry.RESERVE_ALREADY_REGISTERED.selector);
        registry.registerReserve(SPOKE, 7);
    }

    /// @notice Deregistering a live reserve bricks all oracle reads for its key (the SAFETY
    ///         INVARIANT hazard, demonstrated on real state), and re-registration restores the
    ///         IDENTICAL key with identical live values
    function test_E2E_Registry_DeregisterRealReserve_BricksThenRestores() public {
        uint256 tvlBefore = supplyOracle.getTVL(keys[2]); // weETH
        assertGt(tvlBefore, 0);

        registry.proposeDeregisterReserve(keys[2]);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        registry.executeDeregisterReserve(keys[2]);

        vm.expectRevert(AaveV4ReserveRegistry.RESERVE_NOT_REGISTERED.selector);
        supplyOracle.getTVL(keys[2]);
        vm.expectRevert(AaveV4ReserveRegistry.RESERVE_NOT_REGISTERED.selector);
        debtOracle.getPricePerShare(keys[2]);

        address restored = registry.registerReserve(SPOKE, 2);
        assertEq(restored, keys[2], "hash-derived key restored identically");
        // TVL read works again; value moved only by warp-driven accrual (>= pre-deregistration)
        assertGe(supplyOracle.getTVL(keys[2]), tvlBefore, "reads restored with live values");
    }

    /*//////////////////////////////////////////////////////////////
            E. ADVERSARIAL / THIRD-PARTY STATE CHANGES (REAL SPOKE)
    //////////////////////////////////////////////////////////////*/

    /// @notice Pins the DEPLOYED spoke's premium-update authorization (fork-discovered: the
    ///         pre-launch Sherlock-contest code was permissionless, but the live deployment gates
    ///         it behind AccessManager): third-party pokes REVERT, self-pokes succeed, and oracle
    ///         parity holds after a self-poke with the total never decreased
    function test_E2E_UpdateUserRiskPremium_GatedOnDeployment_ParityAfterSelfPoke() public {
        _openPosition(user1, WETH, 0, 10 ether, 7, 5000e6);
        vm.warp(block.timestamp + 30 days);

        uint256 debtBefore = debtOracle.getBalanceOfOwner(keys[7], user1);

        // Unrelated third party: reverts AccessManagedUnauthorized(caller) on the live spoke
        vm.prank(makeAddr("premiumPoker"));
        (bool ok, bytes memory ret) = SPOKE.call(abi.encodeWithSignature("updateUserRiskPremium(address)", user1));
        assertFalse(ok, "third-party premium poke is gated on the deployed spoke");
        assertEq(bytes4(ret), bytes4(0x068ca9d8), "AccessManagedUnauthorized selector");

        // Self-call succeeds (msg.sender == onBehalfOf)
        vm.prank(user1);
        (ok,) = SPOKE.call(abi.encodeWithSignature("updateUserRiskPremium(address)", user1));
        assertTrue(ok, "self premium poke allowed");

        (uint256 drawn, uint256 premium) = IAaveV4Spoke(SPOKE).getUserDebt(7, user1);
        uint256 debtAfter = debtOracle.getBalanceOfOwner(keys[7], user1);
        assertEq(debtAfter, drawn + premium, "oracle == component sum after poke");
        assertGe(debtAfter, debtBefore, "poke never decreases total owed (ray-precision fix)");
    }

    /// @notice Premium self-poke immediately followed by repay(max): position still clears to
    ///         exactly zero (the SUP-20842 repay-cap interaction, end to end)
    function test_E2E_PremiumPoke_ThenRepayMax_ClearsToZero() public {
        _openPosition(user1, WETH, 0, 10 ether, 7, 5000e6);
        vm.warp(block.timestamp + 30 days);

        vm.prank(user1);
        (bool ok,) = SPOKE.call(abi.encodeWithSignature("updateUserRiskPremium(address)", user1));
        assertTrue(ok);

        uint256 debt = debtOracle.getBalanceOfOwner(keys[7], user1);
        deal(USDC, user1, debt * 2);
        _approve(USDC, user1, SPOKE, type(uint256).max);
        vm.prank(user1);
        IAaveV4Spoke(SPOKE).repay(7, type(uint256).max, user1);

        assertEq(debtOracle.getBalanceOfOwner(keys[7], user1), 0, "clears exactly even after a fresh poke");
    }

    /// @notice Pins the real EURC market state at the block: the reserve is ~100% utilized
    ///         (2,517e6 supplied vs 2,517e6 drawn), so any borrow reverts InsufficientLiquidity —
    ///         while the oracles keep reading the fully-utilized reserve without issue
    function test_E2E_EURC_FullyUtilizedReserve_OracleReadsLive() public {
        assertGe(debtOracle.getTVL(keys[9]), supplyOracle.getTVL(keys[9]), "EURC ~100% utilized at this block");

        _openPosition(user1, WETH, 0, 10 ether, 7, 100e6); // unrelated healthy position
        vm.prank(user1);
        vm.expectRevert(); // InsufficientLiquidity(uint256) — selector 0xc730333f
        IAaveV4Spoke(SPOKE).borrow(9, 500e6, user1);

        // Oracle reads on the exhausted reserve stay live
        assertGt(debtOracle.getTVL(keys[9]), 0);
        assertEq(debtOracle.getBalanceOfOwner(keys[9], user1), 0);
    }

    /// @notice Donation immunity on the REAL spoke: transferring tokens directly to the spoke
    ///         moves neither user balances nor reserve TVLs (internal share/index bookkeeping)
    function test_E2E_Donation_DoesNotMoveOracleReads() public {
        _openPosition(user1, WETH, 0, 10 ether, 7, 5000e6);

        uint256 userSupplied = supplyOracle.getBalanceOfOwner(keys[0], user1);
        uint256 supplyTvl = supplyOracle.getTVL(keys[0]);
        uint256 userDebt = debtOracle.getBalanceOfOwner(keys[7], user1);
        uint256 debtTvl = debtOracle.getTVL(keys[7]);

        // Donate both assets straight to the spoke
        deal(WETH, address(this), 100 ether);
        IERC20(WETH).transfer(SPOKE, 100 ether);
        deal(USDC, address(this), 1_000_000e6);
        IERC20(USDC).transfer(SPOKE, 1_000_000e6);

        assertEq(supplyOracle.getBalanceOfOwner(keys[0], user1), userSupplied, "user supply unmoved by donation");
        assertEq(supplyOracle.getTVL(keys[0]), supplyTvl, "supply TVL unmoved by donation");
        assertEq(debtOracle.getBalanceOfOwner(keys[7], user1), userDebt, "user debt unmoved by donation");
        assertEq(debtOracle.getTVL(keys[7]), debtTvl, "debt TVL unmoved by donation");
    }

    /*//////////////////////////////////////////////////////////////
                F. REAL-LEDGER ACCOUNTING E2E (FORK)
    //////////////////////////////////////////////////////////////*/

    /// @notice Full accounting round trip with a REAL SuperLedger over REAL accrual (documents
    ///         the FUTURE-wiring ledger path; production keeps feePercent = 0 and the fee VIEW is
    ///         bypass-overridden until accounting hooks exist): cost basis snapshots at deposit,
    ///         and the configured fee is charged on the accrued yield only — proving the
    ///         identity-PPS oracle's ledger path fees yield, never principal, once wired
    function test_E2E_RealLedger_YieldFee_ChargedOnAccrualOnly() public {
        // Configure: supply oracle, 10% fee, real ledger, this test as the allowed executor
        address[] memory executors = new address[](1);
        executors[0] = address(this);
        SuperLedger ledger = new SuperLedger(ledgerConfig, executors);
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(supplyOracle),
            feePercent: 1000,
            feeRecipient: makeAddr("feeRecipient"),
            ledger: address(ledger)
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = keccak256("AAVE_V4_E2E_LEDGER");
        SuperLedgerConfiguration(ledgerConfig).setYieldSourceOracles(salts, configs);
        bytes32 id = keccak256(abi.encodePacked(salts[0], address(this)));

        // Real supply on the real spoke
        _openPosition(user1, WETH, 0, 10 ether, 7, 1000e6);
        uint256 inAssets = supplyOracle.getBalanceOfOwner(keys[0], user1);
        ledger.updateAccounting(user1, keys[0], id, true, inAssets, 0);

        // Real accrual, then full withdrawal after clearing the small debt
        vm.warp(block.timestamp + 365 days);
        uint256 debt = debtOracle.getBalanceOfOwner(keys[7], user1);
        deal(USDC, user1, debt * 2);
        _approve(USDC, user1, SPOKE, type(uint256).max);
        uint256 wethBefore = IERC20(WETH).balanceOf(user1);
        vm.startPrank(user1);
        IAaveV4Spoke(SPOKE).repay(7, type(uint256).max, user1);
        IAaveV4Spoke(SPOKE).withdraw(0, type(uint256).max, user1);
        vm.stopPrank();
        uint256 outAssets = IERC20(WETH).balanceOf(user1) - wethBefore;
        assertGt(outAssets, inAssets, "365 days of supply yield accrued");

        uint256 feeAmount = ledger.updateAccounting(user1, keys[0], id, false, outAssets, inAssets);
        assertEq(feeAmount, (outAssets - inAssets) * 1000 / 10_000, "fee == 10% of yield, never principal");
    }

    /*//////////////////////////////////////////////////////////////
                G. PORTFOLIO / EXOTIC-RESERVE LIFECYCLES
    //////////////////////////////////////////////////////////////*/

    /// @notice GHO (mint-based debt asset, reserve 13): borrow + partial repay from borrowed
    ///         funds, with exact oracle deltas throughout
    function test_E2E_GHO_MintBasedDebt_Lifecycle() public {
        _openPosition(user1, WETH, 0, 10 ether, 13, 1000e18);
        uint256 debtAfterBorrow = debtOracle.getBalanceOfOwner(keys[13], user1);
        assertGe(debtAfterBorrow, 1000e18, "GHO debt registered");
        assertEq(IERC20(GHO).balanceOf(user1), 1000e18, "borrowed GHO in wallet");

        // Repay half straight from the borrowed funds — no deal() needed
        _approve(GHO, user1, SPOKE, 500e18);
        vm.prank(user1);
        IAaveV4Spoke(SPOKE).repay(13, 500e18, user1);

        assertApproxEqAbs(
            debtAfterBorrow - debtOracle.getBalanceOfOwner(keys[13], user1), 500e18, 1, "GHO repay delta exact"
        );
    }

    /// @notice Multi-collateral portfolio: one user, WETH + WBTC both supplied, single USDC debt —
    ///         the supply oracle isolates per reserve while the debt aggregates on one key
    function test_E2E_MultiCollateral_PortfolioIsolation() public {
        // WETH leg
        _openPosition(user1, WETH, 0, 5 ether, 7, 2000e6);
        // Add WBTC collateral + borrow more against the combined portfolio
        deal(WBTC, user1, 1e8);
        _approve(WBTC, user1, SPOKE, 1e8);
        vm.startPrank(user1);
        IAaveV4Spoke(SPOKE).supply(3, 1e8, user1);
        IAaveV4Spoke(SPOKE).setUsingAsCollateral(3, true, user1);
        IAaveV4Spoke(SPOKE).borrow(7, 8000e6, user1);
        vm.stopPrank();

        // Supply oracle: per-reserve isolation, correct decimals domains
        uint256 wethSupplied = supplyOracle.getBalanceOfOwner(keys[0], user1);
        uint256 wbtcSupplied = supplyOracle.getBalanceOfOwner(keys[3], user1);
        assertGt(wethSupplied, 0);
        assertLe(wethSupplied, 5 ether);
        assertGt(wbtcSupplied, 0);
        assertLe(wbtcSupplied, 1e8);

        // Debt oracle: single aggregated USDC position across both borrows
        assertGe(debtOracle.getBalanceOfOwner(keys[7], user1), 10_000e6, "both borrows aggregate on one key");
        assertEq(debtOracle.getBalanceOfOwner(keys[3], user1), 0, "no WBTC debt");
        assertEq(debtOracle.getBalanceOfOwner(keys[0], user1), 0, "no WETH debt");
    }

    /// @notice Multi-debt portfolio read in ONE batch call: USDC + USDT + GHO debts for one user,
    ///         plus a second user and empty entries, all isolated with succeeded flags
    function test_E2E_MultiDebt_PortfolioBatchMatrix() public {
        _openPosition(user1, WETH, 0, 10 ether, 7, 3000e6);
        vm.startPrank(user1);
        IAaveV4Spoke(SPOKE).borrow(8, 2000e6, user1);
        IAaveV4Spoke(SPOKE).borrow(13, 1000e18, user1);
        vm.stopPrank();
        _openPosition(user2, WSTETH, 1, 5 ether, 0, 0.5 ether); // WETH debt (EURC is 100% utilized)

        address[] memory sources = new address[](4);
        sources[0] = keys[7];
        sources[1] = keys[8];
        sources[2] = keys[13];
        sources[3] = keys[0];
        address[][] memory owners = new address[][](4);
        for (uint256 i; i < 4; ++i) {
            owners[i] = new address[](2);
            owners[i][0] = user1;
            owners[i][1] = user2;
        }

        (uint256[][] memory tvls, bool[][] memory ok) = debtOracle.getTVLByOwnerOfSharesMultiple(sources, owners);
        assertGe(tvls[0][0], 3000e6, "USDC debt");
        assertGe(tvls[1][0], 2000e6, "USDT debt");
        assertGe(tvls[2][0], 1000e18, "GHO debt");
        assertEq(tvls[3][0], 0, "no WETH debt for user1");
        assertGe(tvls[3][1], 0.5 ether, "WETH debt for user2");
        assertEq(tvls[0][1], 0, "no USDC debt for user2");
        for (uint256 i; i < 4; ++i) {
            assertTrue(ok[i][0]);
            assertTrue(ok[i][1]);
        }
    }

    /// @notice Hook-driven close with an EXACT partial withdraw (not the max sentinel): the
    ///         supply-oracle delta equals the withdrawn amount and residual position survives
    function test_E2E_HookClose_ExactPartialWithdraw_OracleDelta() public {
        deal(WETH, user1, 10 ether);
        _executeAs(user1, openHook.build(address(0), user1, _hookData(USDC, WETH, 0, 7, 10 ether, 1000e6)));

        uint256 suppliedBefore = supplyOracle.getBalanceOfOwner(keys[0], user1);
        uint256 debt = debtOracle.getBalanceOfOwner(keys[7], user1);
        deal(USDC, user1, debt);

        // Close: exact-amount repay of the full debt via cap-free exact word, exact 2 ETH withdraw
        bytes memory closeData = _hookData(USDC, WETH, 0, 7, type(uint256).max, 2 ether);
        _executeAs(user1, closeHook.build(address(0), user1, closeData));

        assertEq(debtOracle.getBalanceOfOwner(keys[7], user1), 0, "debt cleared");
        assertApproxEqAbs(
            suppliedBefore - supplyOracle.getBalanceOfOwner(keys[0], user1),
            2 ether,
            1,
            "supply delta == exact withdraw"
        );
        assertGt(supplyOracle.getBalanceOfOwner(keys[0], user1), 0, "residual collateral position survives");
    }

    /// @notice SAFETY INVARIANT demonstrated with a LIVE position: deregistering the key bricks
    ///         both oracles for an open position; re-registration restores the identical key and
    ///         the exact live values
    function test_E2E_DeregisterWithLivePosition_BricksThenRestoresExactValues() public {
        _openPosition(user1, WETH, 0, 10 ether, 7, 5000e6);

        registry.proposeDeregisterReserve(keys[7]);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        // Record AFTER the warp so accrual doesn't move the comparison values
        (uint256 drawn, uint256 premium) = IAaveV4Spoke(SPOKE).getUserDebt(7, user1);
        registry.executeDeregisterReserve(keys[7]);

        // The live position's accounting reads are bricked — the documented hazard
        vm.expectRevert(AaveV4ReserveRegistry.RESERVE_NOT_REGISTERED.selector);
        debtOracle.getBalanceOfOwner(keys[7], user1);
        vm.expectRevert(AaveV4ReserveRegistry.RESERVE_NOT_REGISTERED.selector);
        debtOracle.getTVL(keys[7]);

        // Same-block re-registration restores the identical key and exact live values
        assertEq(registry.registerReserve(SPOKE, 7), keys[7]);
        assertEq(debtOracle.getBalanceOfOwner(keys[7], user1), drawn + premium, "exact live values restored");
    }

    /*//////////////////////////////////////////////////////////////
            H. PR-997 F1: FEE-VIEW BYPASS ON REAL POSITIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Registers an adversarial fee config (10%, zero-cost-basis ledger) for `oracle_`
    function _registerAdversarialFeeConfig(bytes32 salt, address oracle_) internal returns (bytes32) {
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle_,
            feePercent: 1000, // 10% — the misconfiguration the bypass must neutralize
            feeRecipient: makeAddr("feeRecipient"),
            ledger: address(new MockZeroCostBasisLedgerE2E())
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = salt;
        SuperLedgerConfiguration(ledgerConfig).setYieldSourceOracles(salts, configs);
        return keccak256(abi.encodePacked(salt, address(this)));
    }

    /// @notice F1 fix pinned on a REAL position: with a misconfigured 10% fee and no cost-basis
    ///         snapshot (nothing is wired), the supply oracle's fee view returns exactly the
    ///         requested amount — the pre-fix inherited view would have quoted supplied × 1.1
    function test_E2E_F1_SupplyFeeView_BypassesOnRealPosition() public {
        _openPosition(user1, WETH, 0, 10 ether, 7, 1000e6);
        bytes32 id = _registerAdversarialFeeConfig(keccak256("E2E_F1_SUPPLY"), address(supplyOracle));

        uint256 supplied = supplyOracle.getBalanceOfOwner(keys[0], user1);
        uint256 quote = supplyOracle.getAssetOutputWithFees(id, keys[0], WETH, user1, supplied);

        assertEq(quote, supplied, "bypass: quote == requested amount, never fee-inflated");
        assertLt(quote, supplied + supplied * 1000 / 10_000, "pre-fix inflated quote is impossible");
    }

    /// @notice F1 impact scenario disproved end-to-end: a withdrawal quote through the fee view
    ///         can never request more assets than the position actually releases
    function test_E2E_F1_WithdrawQuote_NeverExceedsReleasable() public {
        _openPosition(user1, WETH, 0, 10 ether, 7, 100e6);
        bytes32 id = _registerAdversarialFeeConfig(keccak256("E2E_F1_QUOTE"), address(supplyOracle));

        // Clear the small debt so a full withdrawal is possible
        deal(USDC, user1, 200e6);
        _approve(USDC, user1, SPOKE, type(uint256).max);
        vm.prank(user1);
        IAaveV4Spoke(SPOKE).repay(7, type(uint256).max, user1);

        uint256 supplied = supplyOracle.getBalanceOfOwner(keys[0], user1);
        uint256 quote = supplyOracle.getAssetOutputWithFees(id, keys[0], WETH, user1, supplied);

        uint256 wethBefore = IERC20(WETH).balanceOf(user1);
        vm.prank(user1);
        IAaveV4Spoke(SPOKE).withdraw(0, type(uint256).max, user1);
        uint256 released = IERC20(WETH).balanceOf(user1) - wethBefore;

        assertLe(quote, released + 1, "quote never exceeds what the position releases");
        assertApproxEqAbs(quote, released, 1, "identity quote matches the actual release");
    }

    /// @notice Both oracles bypass identically under the same adversarial config on real keys
    function test_E2E_F1_BothOracles_BypassParity() public {
        _openPosition(user1, WETH, 0, 10 ether, 7, 5000e6);
        bytes32 supplyId = _registerAdversarialFeeConfig(keccak256("E2E_F1_PARITY_S"), address(supplyOracle));
        bytes32 debtId = _registerAdversarialFeeConfig(keccak256("E2E_F1_PARITY_D"), address(debtOracle));

        uint256 debt = debtOracle.getBalanceOfOwner(keys[7], user1);
        assertEq(debtOracle.getAssetOutputWithFees(debtId, keys[7], USDC, user1, debt), debt, "debt view bypasses");
        uint256 supplied = supplyOracle.getBalanceOfOwner(keys[0], user1);
        assertEq(
            supplyOracle.getAssetOutputWithFees(supplyId, keys[0], WETH, user1, supplied),
            supplied,
            "supply view bypasses"
        );
    }

    /*//////////////////////////////////////////////////////////////
            I. PR-997 F3: ROLE HANDOFF SEQUENCE ON FORK
    //////////////////////////////////////////////////////////////*/

    /// @notice The exact handoff sequence TransferAaveV4ReserveRegistryRoles performs, executed
    ///         against a fork-deployed registry with the script's REAL addresses (harness-coupled):
    ///         final role matrix, loss of deployer power, and operational continuity under the
    ///         governor — all verified against the live spoke
    function test_E2E_F3_RoleHandoff_SequenceAndOperationalContinuity() public {
        TransferRolesHarness script_ = new TransferRolesHarness();
        address deployer = script_.deployerAddr();
        address gov = script_.governor();
        address superGov = script_.superGovernor(1); // Ethereum fork → default Super Governor

        // Fresh registry with the real DEPLOYER as bootstrap admin (mirrors DeployV2Core)
        AaveV4ReserveRegistry reg = new AaveV4ReserveRegistry(deployer);
        bytes32 MANAGER = reg.MARKET_MANAGER_ROLE();
        bytes32 ADMIN = reg.DEFAULT_ADMIN_ROLE();

        // ---- The script's sequence: grant both, then revoke both from deployer ----
        vm.startPrank(deployer);
        reg.grantRole(MANAGER, gov);
        reg.grantRole(ADMIN, superGov);
        reg.revokeRole(MANAGER, deployer);
        reg.revokeRole(ADMIN, deployer);
        vm.stopPrank();

        // ---- Final state matrix (the script's _isFullyTransferred conditions) ----
        assertTrue(reg.hasRole(MANAGER, gov), "governor holds MARKET_MANAGER");
        assertTrue(reg.hasRole(ADMIN, superGov), "super governor holds ADMIN");
        assertFalse(reg.hasRole(MANAGER, deployer), "deployer fully revoked (manager)");
        assertFalse(reg.hasRole(ADMIN, deployer), "deployer fully revoked (admin)");

        // ---- Deployer has lost all power ----
        vm.startPrank(deployer);
        vm.expectRevert();
        reg.registerReserve(SPOKE, 0);
        vm.expectRevert();
        reg.grantRole(MANAGER, deployer); // cannot self-restore
        vm.stopPrank();

        // ---- Operational continuity: governor registers a REAL reserve ----
        vm.prank(gov);
        address key = reg.registerReserve(SPOKE, 0);
        assertEq(key, reg.computeReserveKey(SPOKE, 0));
        assertTrue(reg.isRegistered(key));

        // Governor can run the deregistration lifecycle too
        vm.startPrank(gov);
        reg.proposeDeregisterReserve(key);
        reg.cancelDeregisterReserve(key);
        vm.stopPrank();

        // ---- Separation of duties: governor is not admin ----
        vm.prank(gov);
        vm.expectRevert();
        reg.grantRole(MANAGER, makeAddr("newOps"));

        // ---- Admin continuity: super governor grants a new ops manager, who can operate ----
        address newOps = makeAddr("newOpsManager");
        vm.prank(superGov);
        reg.grantRole(MANAGER, newOps);
        vm.prank(newOps);
        address key7 = reg.registerReserve(SPOKE, 7);
        assertTrue(reg.isRegistered(key7), "new ops manager operational after admin grant");
    }

    /// @notice The handoff sequence is idempotent — re-running every step after full transfer
    ///         neither reverts nor changes state (mirrors the script's skip/no-op guarantees)
    function test_E2E_F3_RoleHandoff_Idempotent() public {
        TransferRolesHarness script_ = new TransferRolesHarness();
        address deployer = script_.deployerAddr();
        address gov = script_.governor();
        address superGov = script_.superGovernor(1);

        AaveV4ReserveRegistry reg = new AaveV4ReserveRegistry(deployer);
        bytes32 MANAGER = reg.MARKET_MANAGER_ROLE();
        bytes32 ADMIN = reg.DEFAULT_ADMIN_ROLE();

        vm.startPrank(deployer);
        reg.grantRole(MANAGER, gov);
        reg.grantRole(ADMIN, superGov);
        reg.revokeRole(MANAGER, deployer);
        reg.revokeRole(ADMIN, deployer);
        vm.stopPrank();

        // Second run — now only the super governor holds admin; every step is a no-op
        vm.startPrank(superGov);
        reg.grantRole(MANAGER, gov);
        reg.grantRole(ADMIN, superGov);
        reg.revokeRole(MANAGER, deployer);
        reg.revokeRole(ADMIN, deployer);
        vm.stopPrank();

        assertTrue(reg.hasRole(MANAGER, gov));
        assertTrue(reg.hasRole(ADMIN, superGov));
        assertFalse(reg.hasRole(MANAGER, deployer));
        assertFalse(reg.hasRole(ADMIN, deployer));
    }
}
