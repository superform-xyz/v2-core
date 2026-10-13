// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance } from "modulekit/ModuleKit.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import { ExecutionReturnData } from "modulekit/test/RhinestoneModuleKit.sol";

// Superform
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { ISuperLedgerConfiguration } from "../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperLedger } from "../../src/interfaces/accounting/ISuperLedger.sol";
import { ISuperNativePaymaster } from "../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperLedgerConfiguration } from "../../src/accounting/SuperLedgerConfiguration.sol";
import { SuperLedger } from "../../src/accounting/SuperLedger.sol";
import { SuperExecutor } from "../../src/executors/SuperExecutor.sol";
import { SuperNativePaymaster } from "../../src/paymaster/SuperNativePaymaster.sol";
import { AaveV4ReserveRegistryV2 } from "../../src/accounting/oracles/AaveV4ReserveRegistryV2.sol";
import { AaveV4ReserveOracle } from "../../src/accounting/oracles/AaveV4ReserveOracle.sol";
import { AaveV4LendHook } from "../../src/hooks/loan/aave-v4/AaveV4LendHook.sol";
import { AaveV4RedeemHook } from "../../src/hooks/loan/aave-v4/AaveV4RedeemHook.sol";
import { BaseAaveV4MoneyMarketHook } from "../../src/hooks/loan/aave-v4/BaseAaveV4MoneyMarketHook.sol";
import { IAaveV4Spoke } from "../../src/vendor/aave-v4/IAaveV4Spoke.sol";
import { Helpers } from "../utils/Helpers.sol";
import { InternalHelpers } from "../utils/InternalHelpers.sol";

/// @title AaveV4IdleHooksBaseFork
/// @notice SUP-21142 E2E on Base: idle lend / redeem of USDC (reserve 7) on the MAG7 equities spoke
///         through a real SuperExecutor + SuperLedger stack. The equity reserves (ids 0-6) are
///         node-native tokens and are deliberately not touched; USDC is a normal ERC-20.
contract AaveV4IdleHooksBaseFork is Helpers, RhinestoneModuleKit, InternalHelpers {
    using ModuleKitHelpers for *;

    uint256 internal constant BASE_FORK_BLOCK = 51_778_000;
    address internal constant MAG7_SPOKE = 0x17905Db0e4A3514467539956c084180616AE7B8D;
    uint256 internal constant USDC_RESERVE_ID = 7;
    uint256 internal constant LEND = 1000e6;
    bytes32 internal constant ORACLE_SALT = bytes32("AaveV4ReserveOracle");
    bytes32 internal constant COLLATERAL_EVENT = keccak256("SetUsingAsCollateral(uint256,address,address,bool)");

    address public accountBase;
    AccountInstance public instanceOnBase;
    ISuperExecutor public superExecutorOnBase;
    ISuperLedgerConfiguration public ledgerConfig;
    SuperLedger public ledger;
    ISuperNativePaymaster public superNativePaymaster;
    AaveV4ReserveRegistryV2 public registry;
    AaveV4ReserveOracle public oracle;
    AaveV4LendHook public lendHook;
    AaveV4RedeemHook public redeemHook;
    address public usdcKey;
    /// @dev SUP-21254: the idle header and therefore the SuperLedger key — the market whose SUPPLY leg is
    ///      the USDC reserve these tests lend. An equity reserve supplies the identity-only borrow leg.
    address public usdcMarketKey;
    uint256 public constant IDLE_BORROW_LEG_ID = 0;
    bytes32 public oracleId;
    address public feeRecipient;

    function setUp() public {
        vm.createSelectFork(vm.envString(BASE_RPC_URL_KEY), BASE_FORK_BLOCK);

        ledgerConfig = ISuperLedgerConfiguration(address(new SuperLedgerConfiguration()));
        instanceOnBase = makeAccountInstance(keccak256(abi.encode("aave-idle-base-acc")));
        accountBase = instanceOnBase.account;
        superExecutorOnBase = ISuperExecutor(new SuperExecutor(address(ledgerConfig)));
        instanceOnBase.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutorOnBase), data: ""
        });
        address[] memory allowedExecutors = new address[](1);
        allowedExecutors[0] = address(superExecutorOnBase);
        ledger = new SuperLedger(address(ledgerConfig), allowedExecutors);

        registry = new AaveV4ReserveRegistryV2(address(this));
        (usdcKey,) = registry.registerReserve(MAG7_SPOKE, USDC_RESERVE_ID);
        registry.registerReserve(MAG7_SPOKE, IDLE_BORROW_LEG_ID);
        // the oracle resolves the idle header through `_resolveLeg`, which reverts for an unregistered
        // market, so the market must exist before any idle op can settle
        usdcMarketKey = registry.registerMarket(MAG7_SPOKE, USDC_RESERVE_ID, IDLE_BORROW_LEG_ID);
        oracle = new AaveV4ReserveOracle(address(ledgerConfig), address(registry));
        feeRecipient = makeAddr("feeRecipient");

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle), feePercent: 0, feeRecipient: feeRecipient, ledger: address(ledger)
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = ORACLE_SALT;
        ledgerConfig.setYieldSourceOracles(salts, configs);
        oracleId = _getYieldSourceOracleId(ORACLE_SALT, address(this));

        lendHook = new AaveV4LendHook(address(registry));
        redeemHook = new AaveV4RedeemHook(address(registry));
        superNativePaymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));

        _getTokens(CHAIN_8453_USDC, accountBase, 10_000e6);
    }

    receive() external payable { }

    /// @dev SUP-21263: 157 bytes, one `targetReserveId`. USDC is the SUPPLY leg of `usdcMarketKey`.
    function _data(uint256 amount, bool usePrev) internal view returns (bytes memory) {
        return abi.encodePacked(oracleId, usdcMarketKey, CHAIN_8453_USDC, MAG7_SPOKE, USDC_RESERVE_ID, amount, usePrev);
    }

    function _execute(address hook, bytes memory data) internal returns (ExecutionReturnData memory) {
        address[] memory hooks = new address[](1);
        hooks[0] = hook;
        bytes[] memory datas = new bytes[](1);
        datas[0] = data;
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: datas });
        UserOpData memory userOpData = _getExecOps(instanceOnBase, superExecutorOnBase, abi.encode(entry));
        return executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
    }

    function _isCollateral() internal view returns (bool flag) {
        (flag,) = IAaveV4Spoke(MAG7_SPOKE).getUserReserveStatus(USDC_RESERVE_ID, accountBase);
    }

    function _supplied() internal view returns (uint256) {
        return IAaveV4Spoke(MAG7_SPOKE).getUserSuppliedAssets(USDC_RESERVE_ID, accountBase);
    }

    function _collateralEventCount(ExecutionReturnData memory ret) internal pure returns (uint256 n) {
        for (uint256 i; i < ret.logs.length; ++i) {
            if (ret.logs[i].topics.length > 0 && ret.logs[i].topics[0] == COLLATERAL_EVENT) ++n;
        }
    }

    function test_Base_Lend_SupplyOnly_CollateralFlagNotFlipped() public {
        assertFalse(_isCollateral());
        uint256 walletBefore = IERC20(CHAIN_8453_USDC).balanceOf(accountBase);

        ExecutionReturnData memory ret = _execute(address(lendHook), _data(LEND, false));

        assertFalse(_isCollateral(), "supply-only: collateral bit untouched");
        assertEq(_collateralEventCount(ret), 0);
        assertEq(walletBefore - IERC20(CHAIN_8453_USDC).balanceOf(accountBase), LEND);
        uint256 credited = _supplied();
        assertLe(LEND - credited, 1);
        assertEq(ledger.usersAccumulatorShares(accountBase, usdcMarketKey), credited, "keyed by the header market key");
        assertEq(ledger.usersAccumulatorShares(accountBase, MAG7_SPOKE), 0, "never by the spoke");
        assertEq(oracle.getBalanceOfOwner(usdcKey, accountBase), credited);
    }

    function test_Base_Lend_Then_RedeemFull_LedgerNets() public {
        _execute(address(lendHook), _data(LEND, false));
        uint256 credited = _supplied();
        // NON-VACUITY GUARD (pre-existing gap): every assertion below holds trivially for a silently-failed
        // userOp, since `_execute` does not bubble one.
        assertGt(credited, 0, "the lend must actually have credited a position");
        uint256 walletBefore = IERC20(CHAIN_8453_USDC).balanceOf(accountBase);

        _execute(address(redeemHook), _data(type(uint256).max, false));

        assertEq(IERC20(CHAIN_8453_USDC).balanceOf(accountBase) - walletBefore, credited);
        assertEq(_supplied(), 0);
        assertEq(ledger.usersAccumulatorShares(accountBase, usdcMarketKey), 0);
        assertEq(ledger.usersAccumulatorCostBasis(accountBase, usdcMarketKey), 0);
        assertEq(IERC20(CHAIN_8453_USDC).balanceOf(feeRecipient), 0, "feePercent 0");
    }

    /*//////////////////////////////////////////////////////////////
       SUP-21263: THE BORROW LEG IS A LEGAL IDLE TARGET (AC5)
    //////////////////////////////////////////////////////////////*/

    /// @notice THE ACCEPTANCE CRITERION, on live Base. Idle USDC settles under an EQUITY market key — the
    ///         market where USDC is the LOAN leg, `(spoke, equityId, 7)` — instead of needing a yield source
    ///         of its own. Before SUP-21263 this exact payload reverted `MARKET_KEY_MISMATCH`, because
    ///         offset 92 fed `computeMarketKey`'s supply slot and reserve 7 is not that market's supply leg.
    /// @dev The absence of `vm.expectRevert` is the point: the op must simply succeed.
    function test_Base_IdleUSDC_UnderEquityCollateralMarket_DoesNotRevert() public {
        (address equityMarketKey,) = _registerEquityMarket();

        uint256 walletBefore = IERC20(CHAIN_8453_USDC).balanceOf(accountBase);
        _execute(address(lendHook), _equityMarketIdleData(LEND, false));

        uint256 credited = _supplied();
        assertEq(walletBefore - IERC20(CHAIN_8453_USDC).balanceOf(accountBase), LEND, "wallet debited exactly");
        assertLe(LEND - credited, 1, "USDC position credited (Aave rounds down <= 1 wei)");
        assertEq(
            ledger.usersAccumulatorShares(accountBase, equityMarketKey),
            credited,
            "the ledger key is the EQUITY market key, even though the moved reserve is its loan leg"
        );
        assertEq(ledger.usersAccumulatorShares(accountBase, usdcMarketKey), 0, "and NOT the USDC-collateral market");
    }

    /// @notice R2 PINNED AS OBSERVED, ACCEPTED BEHAVIOUR. The oracle resolves a market key to its COLLATERAL
    ///         leg, so the scalar `getBalanceOfOwner(equityMarketKey)` reports the EQUITY supply — which this
    ///         account does not hold — while the idle USDC is visible under its own reserve key. This is why
    ///         NAV for this family must come from `getOwnerSnapshot`, never from the scalar market-key read.
    function test_Base_IdleUSDC_UnderEquityMarket_ScalarReadResolvesToTheCollateralLeg() public {
        (address equityMarketKey, uint256 equityId) = _registerEquityMarket();
        _execute(address(lendHook), _equityMarketIdleData(LEND, false));
        uint256 credited = _supplied();
        // NON-VACUITY GUARD: `_execute` does not bubble a failed userOp, so without this the three
        // assertions below are all 0 == 0 and would pass against a hook that reverts on every input.
        assertGt(credited, 0, "the lend must actually have credited a USDC position");

        assertEq(
            oracle.getBalanceOfOwner(equityMarketKey, accountBase),
            IAaveV4Spoke(MAG7_SPOKE).getUserSuppliedAssets(equityId, accountBase),
            "the market-key read IS the equity collateral leg"
        );
        assertEq(oracle.getBalanceOfOwner(equityMarketKey, accountBase), 0, "which this account does not hold");
        // Asserted against the Spoke read directly, not against `credited` — `credited` IS `_supplied()` IS
        // `getBalanceOfOwner(usdcKey)`, so comparing them would be a tautology.
        assertEq(
            oracle.getBalanceOfOwner(usdcKey, accountBase),
            IAaveV4Spoke(MAG7_SPOKE).getUserSuppliedAssets(USDC_RESERVE_ID, accountBase),
            "the moved asset is visible under its own reserve key"
        );
        assertGt(oracle.getBalanceOfOwner(usdcKey, accountBase), 0, "and it is non-zero");
    }

    /// @notice And the exit works: a full redeem of the loan-leg position nets the equity market's
    ///         accumulator back to zero, so the asymmetry above costs nothing in the ledger.
    function test_Base_IdleUSDC_UnderEquityMarket_RedeemFullNetsToZero() public {
        (address equityMarketKey,) = _registerEquityMarket();
        _execute(address(lendHook), _equityMarketIdleData(LEND, false));
        uint256 credited = _supplied();
        assertGt(credited, 0, "NON-VACUITY GUARD: a failed lend would make every assertion below 0 == 0");
        assertEq(ledger.usersAccumulatorShares(accountBase, equityMarketKey), credited, "shares posted");
        uint256 walletBefore = IERC20(CHAIN_8453_USDC).balanceOf(accountBase);

        _execute(address(redeemHook), _equityMarketIdleData(type(uint256).max, false));

        assertEq(IERC20(CHAIN_8453_USDC).balanceOf(accountBase) - walletBefore, credited, "paid out in full");
        assertEq(_supplied(), 0, "position closed");
        assertEq(ledger.usersAccumulatorShares(accountBase, equityMarketKey), 0, "shares net");
        assertEq(ledger.usersAccumulatorCostBasis(accountBase, equityMarketKey), 0, "cost basis nets");
        assertEq(IERC20(CHAIN_8453_USDC).balanceOf(feeRecipient), 0, "feePercent 0");
    }

    /// @notice A reserve that is NEITHER leg of the header market is still refused on live state — the
    ///         feature widened the accepted set to exactly two ids, not to anything.
    function test_Base_IdleTargetOutsideTheMarket_Reverts() public {
        (address equityMarketKey,) = _registerEquityMarket();
        uint256 strayId = IDLE_BORROW_LEG_ID == 1 ? 2 : 1;
        bytes memory data = abi.encodePacked(
            oracleId,
            equityMarketKey,
            IAaveV4Spoke(MAG7_SPOKE).getReserve(strayId).underlying,
            MAG7_SPOKE,
            strayId,
            LEND,
            false
        );
        // The hook reverts in `build`, before any Spoke call. Asserted directly rather than through the
        // userOp path so the selector is exact — a paymaster-wrapped revert only surfaces as a failure.
        vm.expectRevert(BaseAaveV4MoneyMarketHook.RESERVE_NOT_IN_MARKET.selector);
        lendHook.build(address(0), accountBase, data);
        assertEq(IAaveV4Spoke(MAG7_SPOKE).getUserSuppliedAssets(strayId, accountBase), 0, "stray reserve untouched");
        assertEq(equityMarketKey, registry.computeMarketKey(MAG7_SPOKE, IDLE_BORROW_LEG_ID, USDC_RESERVE_ID));
    }

    /// @notice THE R6 HAZARD, DEMONSTRATED ON LIVE STATE — the reason the config script now requires an idle
    ///         SETTLEMENT DESIGNATION. Reserve 7 (USDC) is the LOAN leg of every equity market, so after
    ///         SUP-21263 one physical USDC position can settle under ANY of them. Lend under market A,
    ///         redeem under market B: the redeem SUCCEEDS, because `BaseLedger.calculateCostBasisView` CAPS
    ///         `usedShares` at B's empty accumulator instead of reverting — and A's shares and cost basis are
    ///         stranded forever. No funds are lost (the Spoke position is genuinely closed and `feePercent`
    ///         is 0), but the accumulators are permanently wrong.
    /// @dev Nothing in the contracts prevents this: the registry cannot forbid a 7-way shared debt leg (the
    ///      LOAN hooks need it) and the hooks cannot know which market ops blessed. The mitigation is the
    ///      designation enforced by `ConfigureAaveV4ReserveRegistry._assertIdleSettlementDesignated` plus the
    ///      OMS allowlist. This test exists so the behaviour is recorded rather than discovered.
    function test_Base_LendUnderMarketA_RedeemUnderMarketB_StrandsAccumulatorA() public {
        (address marketA,) = _registerEquityMarket(); // (reserve 0, USDC)
        uint256 otherEquityId = 1;
        registry.registerReserve(MAG7_SPOKE, otherEquityId);
        address marketB = registry.registerMarket(MAG7_SPOKE, otherEquityId, USDC_RESERVE_ID);
        assertTrue(marketA != marketB, "two distinct markets over the one USDC loan leg");

        _execute(address(lendHook), _equityMarketIdleData(LEND, false));
        uint256 credited = _supplied();
        // NON-VACUITY GUARD: without this, "funds returned" and "A holds the shares" are both 0 == 0 and the
        // whole hazard demonstration would survive a hook that never executes.
        assertGt(credited, 0, "the lend under market A must actually have credited a position");
        assertEq(ledger.usersAccumulatorShares(accountBase, marketA), credited, "A holds the shares");
        assertEq(ledger.usersAccumulatorShares(accountBase, marketB), 0, "B holds nothing");

        uint256 walletBefore = IERC20(CHAIN_8453_USDC).balanceOf(accountBase);
        _execute(address(redeemHook), _idleDataForMarket(marketB, type(uint256).max));

        // the exit happened for real...
        assertEq(IERC20(CHAIN_8453_USDC).balanceOf(accountBase) - walletBefore, credited, "funds returned");
        assertEq(_supplied(), 0, "Spoke position closed");
        // ...but under the WRONG key, so A is stranded and B stays empty
        assertEq(
            ledger.usersAccumulatorShares(accountBase, marketA),
            credited,
            "A's shares are STRANDED - this is the hazard, asserted deliberately"
        );
        assertGt(ledger.usersAccumulatorCostBasis(accountBase, marketA), 0, "and so is its cost basis");
        assertEq(ledger.usersAccumulatorShares(accountBase, marketB), 0, "B consumed nothing: usedShares was capped");
        assertEq(IERC20(CHAIN_8453_USDC).balanceOf(feeRecipient), 0, "no fee leaked while feePercent is 0");
    }

    /// @dev An idle body for an arbitrary market key, targeting the USDC reserve.
    function _idleDataForMarket(address marketKey, uint256 amount) internal view returns (bytes memory) {
        return abi.encodePacked(oracleId, marketKey, CHAIN_8453_USDC, MAG7_SPOKE, USDC_RESERVE_ID, amount, false);
    }

    /// @dev Registers an equity/USDC market — USDC as the LOAN leg — and returns it with its collateral id.
    ///      `IDLE_BORROW_LEG_ID` (reserve 0) is an equity reserve on the MAG7 spoke, already registered in
    ///      `setUp`, so only the market itself is new.
    function _registerEquityMarket() internal returns (address marketKey, uint256 equityId) {
        equityId = IDLE_BORROW_LEG_ID;
        marketKey = registry.registerMarket(MAG7_SPOKE, equityId, USDC_RESERVE_ID);
    }

    /// @dev An idle body whose header is the equity/USDC market and whose target is the USDC LOAN leg.
    function _equityMarketIdleData(uint256 amount, bool usePrev) internal view returns (bytes memory) {
        return abi.encodePacked(
            oracleId,
            registry.computeMarketKey(MAG7_SPOKE, IDLE_BORROW_LEG_ID, USDC_RESERVE_ID),
            CHAIN_8453_USDC,
            MAG7_SPOKE,
            USDC_RESERVE_ID,
            amount,
            usePrev
        );
    }

    function test_Base_Lend_Then_RedeemPartial() public {
        _execute(address(lendHook), _data(LEND, false));
        uint256 credited = _supplied();
        uint256 walletBefore = IERC20(CHAIN_8453_USDC).balanceOf(accountBase);

        _execute(address(redeemHook), _data(250e6, false));

        assertEq(IERC20(CHAIN_8453_USDC).balanceOf(accountBase) - walletBefore, 250e6, "exact receipt");
        assertApproxEqAbs(_supplied(), credited - 250e6, 1);
        assertEq(ledger.usersAccumulatorShares(accountBase, usdcMarketKey), _supplied());
    }
}
