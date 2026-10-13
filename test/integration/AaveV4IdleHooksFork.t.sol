// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import { ExecutionReturnData } from "modulekit/test/RhinestoneModuleKit.sol";
import { VmSafe } from "forge-std/Vm.sol";

// Superform
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { ISuperLedgerConfiguration } from "../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperNativePaymaster } from "../../src/interfaces/ISuperNativePaymaster.sol";
import { MinimalBaseIntegrationTest } from "./MinimalBaseIntegrationTest.t.sol";
import { SuperLedger } from "../../src/accounting/SuperLedger.sol";
import { SuperNativePaymaster } from "../../src/paymaster/SuperNativePaymaster.sol";
import { AaveV4ReserveRegistryV2 } from "../../src/accounting/oracles/AaveV4ReserveRegistryV2.sol";
import { AaveV4ReserveOracle } from "../../src/accounting/oracles/AaveV4ReserveOracle.sol";
import { AaveV4LendHook } from "../../src/hooks/loan/aave-v4/AaveV4LendHook.sol";
import { AaveV4RedeemHook } from "../../src/hooks/loan/aave-v4/AaveV4RedeemHook.sol";
import { BaseAaveV4MoneyMarketHook } from "../../src/hooks/loan/aave-v4/BaseAaveV4MoneyMarketHook.sol";
import { AaveV4ReserveKey } from "../../src/libraries/AaveV4ReserveKey.sol";
import { BaseHook } from "../../src/hooks/BaseHook.sol";
import { IAaveV4Spoke } from "../../src/vendor/aave-v4/IAaveV4Spoke.sol";

/// @title AaveV4IdleHooksFork
/// @notice SUP-21142 E2E on Ethereum mainnet: AaveV4LendHook / AaveV4RedeemHook through the REAL
///         SuperExecutor, SuperLedger and AaveV4ReserveOracle, with the ledger keyed by the MARKET key,
///         against the live Main Spoke USDC reserve (id 7). Proves: supply-only (collateral flag never
///         flips), exact wallet deltas, identity-PPS ledger netting, fail-closed on unregistered keys.
contract AaveV4IdleHooksFork is MinimalBaseIntegrationTest {
    address public constant SPOKE = 0x94e7A5dCbE816e498b89aB752661904E2F56c485;
    uint256 public constant USDC_RESERVE_ID = 7;
    uint256 public constant GHO_RESERVE_ID = 13;
    address public constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
    uint256 public constant LEND = 1000e6;
    bytes32 public constant ORACLE_SALT = bytes32("AaveV4ReserveOracle");
    bytes32 internal constant COLLATERAL_EVENT = keccak256("SetUsingAsCollateral(uint256,address,address,bool)");

    AaveV4LendHook public lendHook;
    AaveV4RedeemHook public redeemHook;
    AaveV4ReserveRegistryV2 public registry;
    AaveV4ReserveOracle public oracle;
    ISuperNativePaymaster public superNativePaymaster;
    SuperLedger public superLedger;
    address public feeRecipient;
    address public usdcKey;
    /// @dev SUP-21254: the idle header AND therefore the SuperLedger key. The oracle resolves it to the
    ///      USDC reserve's SUPPLY leg, so `getBalanceOfOwner(usdcMarketKey) == getBalanceOfOwner(usdcKey)`.
    address public usdcMarketKey;
    bytes32 public oracleId;

    function setUp() public override {
        blockNumber = AAVE_V4_BLOCK;
        super.setUp();

        registry = new AaveV4ReserveRegistryV2(address(this));
        (usdcKey,) = registry.registerReserve(SPOKE, USDC_RESERVE_ID);
        // SUP-21254: the idle header is a MARKET key, and the ledger read goes through
        // `AaveV4ReserveOracle._resolveLeg`, which reverts for an unregistered market — so an idle op can
        // only settle under a market the registry has blessed. Register the pair whose SUPPLY leg is the
        // reserve these tests lend: reserve 0 supplies the identity-only borrow leg.
        registry.registerReserve(SPOKE, 0);
        usdcMarketKey = registry.registerMarket(SPOKE, USDC_RESERVE_ID, 0);
        oracle = new AaveV4ReserveOracle(address(ledgerConfig), address(registry));
        feeRecipient = makeAddr("aaveIdleFeeRecipient");

        // Register the identity-PPS reserve oracle with feePercent = 0 (operational invariant) on the
        // real SuperLedger the executor posts to.
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle), feePercent: 0, feeRecipient: feeRecipient, ledger: address(ledger)
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = ORACLE_SALT;
        ledgerConfig.setYieldSourceOracles(salts, configs);
        oracleId = _getYieldSourceOracleId(ORACLE_SALT, address(this));

        superLedger = SuperLedger(address(ledger));
        lendHook = new AaveV4LendHook(address(registry));
        redeemHook = new AaveV4RedeemHook(address(registry));
        superNativePaymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));

        _getTokens(CHAIN_1_USDC, accountEth, 10_000e6);
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    function _idleData(
        address underlying,
        uint256 reserveId,
        uint256 amount,
        bool usePrev
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            oracleId,
            registry.computeMarketKey(SPOKE, reserveId, _idleBorrowLeg(reserveId)),
            underlying,
            SPOKE,
            reserveId,
            amount,
            usePrev
        );
    }

    function _lendData(uint256 amount) internal view returns (bytes memory) {
        return _idleData(CHAIN_1_USDC, USDC_RESERVE_ID, amount, false);
    }

    /// @dev The market key needs a second leg that is not the reserve being moved. Since SUP-21263 it is no
    ///      longer carried in the body — only the header commits it — but the MARKET must be REGISTERED, so
    ///      whichever leg this returns has to match what `setUp` registered.
    function _idleBorrowLeg(uint256 supplyReserveId) internal pure returns (uint256) {
        return supplyReserveId == USDC_RESERVE_ID ? 0 : USDC_RESERVE_ID;
    }

    function _redeemData(uint256 amount, bool usePrev) internal view returns (bytes memory) {
        return _idleData(CHAIN_1_USDC, USDC_RESERVE_ID, amount, usePrev);
    }

    function _execute(address hook, bytes memory data) internal returns (ExecutionReturnData memory) {
        address[] memory hooks = new address[](1);
        hooks[0] = hook;
        bytes[] memory datas = new bytes[](1);
        datas[0] = data;
        return _executeHooks(hooks, datas);
    }

    function _executeHooks(address[] memory hooks, bytes[] memory datas) internal returns (ExecutionReturnData memory) {
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: datas });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        return executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
    }

    /// @dev The userOp execution phase must revert with `expectedSelector` (surfaced by the EntryPoint via
    ///      UserOperationRevertReason)
    function _executeExpectFailure(address hook, bytes memory data, bytes4 expectedSelector) internal {
        ExecutionReturnData memory ret = _execute(hook, data);
        bytes32 revertTopic = keccak256("UserOperationRevertReason(bytes32,address,uint256,bytes)");
        bool found;
        for (uint256 i; i < ret.logs.length; ++i) {
            VmSafe.Log memory log = ret.logs[i];
            if (log.topics.length > 0 && log.topics[0] == revertTopic && _containsSelector(log.data, expectedSelector))
            {
                found = true;
                break;
            }
        }
        assertTrue(found, "expected UserOperationRevertReason with the given selector");
    }

    function _containsSelector(bytes memory blob, bytes4 selector) internal pure returns (bool) {
        if (blob.length < 4) return false;
        for (uint256 i; i <= blob.length - 4; ++i) {
            if (
                blob[i] == selector[0] && blob[i + 1] == selector[1] && blob[i + 2] == selector[2]
                    && blob[i + 3] == selector[3]
            ) return true;
        }
        return false;
    }

    function _collateralEventCount(ExecutionReturnData memory ret) internal pure returns (uint256 n) {
        for (uint256 i; i < ret.logs.length; ++i) {
            if (ret.logs[i].topics.length > 0 && ret.logs[i].topics[0] == COLLATERAL_EVENT) ++n;
        }
    }

    function _isCollateral() internal view returns (bool flag) {
        (flag,) = IAaveV4Spoke(SPOKE).getUserReserveStatus(USDC_RESERVE_ID, accountEth);
    }

    function _supplied() internal view returns (uint256) {
        return IAaveV4Spoke(SPOKE).getUserSuppliedAssets(USDC_RESERVE_ID, accountEth);
    }

    /// @dev Lends LEND and returns the credited position (within 1 wei of LEND, Aave rounds down)
    /// @dev `_execute` goes through the EntryPoint and does NOT bubble a failed userOp, so a silently
    ///      reverting hook would leave every delta at zero and any test written purely as
    ///      `delta == credited` would pass as `0 == 0`. Assert the lend actually credited something — this
    ///      one line is what makes the ledger-netting and chaining tests non-vacuous.
    function _lend() internal returns (uint256 credited) {
        _execute(address(lendHook), _lendData(LEND));
        credited = _supplied();
        assertGt(credited, 0, "precondition: the idle lend must have executed");
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Lend_SupplyOnly_CollateralFlagNotFlipped() public {
        assertFalse(_isCollateral(), "fresh account: not collateral");
        uint256 walletBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);

        vm.expectCall(SPOKE, abi.encodeWithSelector(IAaveV4Spoke.setUsingAsCollateral.selector), 0);
        ExecutionReturnData memory ret = _execute(address(lendHook), _lendData(LEND));

        assertFalse(_isCollateral(), "lend must not flip the collateral bit");
        assertEq(_collateralEventCount(ret), 0, "no SetUsingAsCollateral event");
        assertEq(walletBefore - IERC20(CHAIN_1_USDC).balanceOf(accountEth), LEND, "wallet spend exact");

        uint256 credited = _supplied();
        assertLe(LEND - credited, 1, "Aave rounds the credited position down by at most 1 wei");
        // Ledger keyed by the MARKET key, in the oracle's units (identity pps), never by the spoke
        assertEq(superLedger.usersAccumulatorShares(accountEth, usdcMarketKey), credited, "accumulator shares");
        assertEq(superLedger.usersAccumulatorCostBasis(accountEth, usdcMarketKey), credited, "cost basis 1:1");
        assertEq(superLedger.usersAccumulatorShares(accountEth, SPOKE), 0, "spoke never keyed");
        assertEq(oracle.getBalanceOfOwner(usdcKey, accountEth), credited, "oracle balance == ledger shares");
        assertEq(oracle.getPricePerShare(usdcKey), 1e6, "identity pps");
        // the ledger key is the MARKET key, and the oracle resolves it to exactly the same leg
        assertEq(
            oracle.getBalanceOfOwner(usdcMarketKey, accountEth),
            oracle.getBalanceOfOwner(usdcKey, accountEth),
            "market key resolves to the reserve this idle op moved"
        );
        assertEq(oracle.getPricePerShare(usdcMarketKey), 1e6, "identity pps through the market key too");
    }

    function test_Lend_Then_RedeemFull_LedgerNets() public {
        uint256 credited = _lend();
        uint256 walletBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        uint256 feeBefore = IERC20(CHAIN_1_USDC).balanceOf(feeRecipient);

        ExecutionReturnData memory ret = _execute(address(redeemHook), _redeemData(type(uint256).max, false));

        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth) - walletBefore, credited, "full redeem pays the position");
        assertEq(_supplied(), 0);
        assertEq(superLedger.usersAccumulatorShares(accountEth, usdcMarketKey), 0, "shares net to zero");
        assertEq(superLedger.usersAccumulatorCostBasis(accountEth, usdcMarketKey), 0, "cost basis nets to zero");
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(feeRecipient), feeBefore, "feePercent 0: nothing charged");
        assertFalse(_isCollateral());
        assertEq(_collateralEventCount(ret), 0, "redeem needs no collateral toggle");
    }

    function test_Lend_Then_RedeemPartial_ExactAmount() public {
        uint256 credited = _lend();
        uint256 walletBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);

        _execute(address(redeemHook), _redeemData(400e6, false));

        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth) - walletBefore, 400e6, "partial receipt exact");
        uint256 remaining = _supplied();
        assertApproxEqAbs(remaining, credited - 400e6, 1, "position consumed within share rounding");
        assertEq(superLedger.usersAccumulatorShares(accountEth, usdcMarketKey), remaining, "ledger tracks the position");
        assertEq(oracle.getBalanceOfOwner(usdcKey, accountEth), remaining);
    }

    function test_Lend_Then_Warp_RedeemFull_YieldNotTaxed() public {
        uint256 credited = _lend();
        vm.warp(block.timestamp + 30 days);
        uint256 accrued = _supplied();
        assertGt(accrued, credited, "position accrued interest");
        uint256 walletBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        uint256 feeBefore = IERC20(CHAIN_1_USDC).balanceOf(feeRecipient);

        _execute(address(redeemHook), _redeemData(type(uint256).max, false));

        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth) - walletBefore, accrued, "yield paid out");
        assertEq(superLedger.usersAccumulatorShares(accountEth, usdcMarketKey), 0, "capped usedShares clears the slot");
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(feeRecipient), feeBefore, "feePercent 0: yield untaxed");
    }

    /// @dev THE ONLY FORK-LEVEL TEST OF THE SUP-21263 CHAINING TOKEN, so it must not be vacuous. A
    ///      lend+redeem round trip leaves the position at 0 whether both hooks ran or NEITHER did, and
    ///      `_executeHooks` does not bubble a failed userOp — so a `PREV_TOKEN_MISMATCH` from a wrong
    ///      `outToken` would have passed silently. The Spoke event count is the positive proof that both
    ///      legs actually executed.
    function test_Chain_Lend_Then_Redeem_UsePrev() public {
        uint256 walletBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        address[] memory hooks = new address[](2);
        hooks[0] = address(lendHook);
        hooks[1] = address(redeemHook);
        bytes[] memory datas = new bytes[](2);
        // consumes the lend's outAmount, which since SUP-21263 is advertised against the moved LEG's
        // reserve key — `computeReserveKey(SPOKE, USDC_RESERVE_ID)`, not the market key
        datas[0] = _lendData(LEND);
        datas[1] = _redeemData(0, true);

        ExecutionReturnData memory ret = _executeHooks(hooks, datas);

        // NON-VACUITY GUARD: both Spoke calls must appear in the logs.
        (uint256 sentByAccount, uint256 receivedByAccount) = _countAccountTransfers(ret);
        assertGt(sentByAccount, 0, "the lend leg executed (USDC left the account)");
        assertGt(receivedByAccount, 0, "and the chained redeem leg executed, so the prev-token check passed");

        assertEq(_supplied(), 0, "everything the lend credited was redeemed");
        assertLe(walletBefore - IERC20(CHAIN_1_USDC).balanceOf(accountEth), 1, "round trip loses at most 1 wei");
        assertEq(superLedger.usersAccumulatorShares(accountEth, usdcMarketKey), 0);
    }

    /// @dev Counts USDC Transfers out of and into the ACCOUNT — a protocol-agnostic witness that the supply
    ///      and withdraw legs really ran, independent of hook or ledger state.
    ///      NOT keyed on the Spoke deliberately: Aave V4's Hub/Spoke split means the tokens move between the
    ///      account and the HUB, so a spoke-keyed witness finds nothing and would itself be vacuous.
    function _countAccountTransfers(ExecutionReturnData memory ret)
        internal
        view
        returns (uint256 sentByAccount, uint256 receivedByAccount)
    {
        bytes32 transferTopic = keccak256("Transfer(address,address,uint256)");
        for (uint256 i; i < ret.logs.length; ++i) {
            if (ret.logs[i].emitter != CHAIN_1_USDC) continue;
            if (ret.logs[i].topics.length < 3 || ret.logs[i].topics[0] != transferTopic) continue;
            if (address(uint160(uint256(ret.logs[i].topics[1]))) == accountEth) ++sentByAccount;
            if (address(uint160(uint256(ret.logs[i].topics[2]))) == accountEth) ++receivedByAccount;
        }
    }

    function test_Redeem_RevertIf_NothingSupplied() public {
        _executeExpectFailure(address(redeemHook), _redeemData(LEND, false), BaseHook.AMOUNT_NOT_VALID.selector);
    }

    function test_UnregisteredKey_FailsClosed() public {
        // GHO reserve 13 is listed on the spoke but NEITHER its legs NOR any market over it are registered.
        // SUP-21263 MOVED THIS REVERT EARLIER: the hook now resolves the header through the registry in
        // `build`, so the op dies on `MARKET_NOT_REGISTERED` before any Spoke call, instead of surviving to
        // accounting and dying on the oracle's `RESERVE_NOT_REGISTERED`. Same fail-closed outcome, sooner
        // and more legibly.
        _getTokens(GHO, accountEth, 1000e18);
        _executeExpectFailure(
            address(lendHook),
            _idleData(GHO, GHO_RESERVE_ID, 100e18, false),
            AaveV4ReserveRegistryV2.MARKET_NOT_REGISTERED.selector
        );
        assertEq(IAaveV4Spoke(SPOKE).getUserSuppliedAssets(GHO_RESERVE_ID, accountEth), 0, "nothing supplied");
    }

    /// @notice THE GATE SUP-21254 BOUGHT, isolated — and since SUP-21263 it is enforced by the HOOK. The
    ///         reserve's legs ARE registered, so the old per-reserve allowlist would have allowed this op;
    ///         only the MARKET is missing. The hook's `getMarketInfo` read finds no market and reverts at
    ///         build, so the idle allowlist is market-granular and is checked before any external call.
    /// @dev Distinct from `test_UnregisteredKey_FailsClosed`, which fails for two reasons at once (neither
    ///      the legs nor a market exist) and therefore cannot isolate this behaviour.
    function test_RegisteredReserveButUnregisteredMarket_FailsClosed() public {
        // The USDC reserve the suite funds and lends: BOTH its legs are registered, and market (7, 0) is
        // registered in setUp. Market (7, 1) is NOT — same moved reserve, different borrow leg, so the only
        // thing missing is the market itself.
        uint256 unregisteredBorrowLeg = 1;
        address unregisteredMarket = registry.computeMarketKey(SPOKE, USDC_RESERVE_ID, unregisteredBorrowLeg);
        assertTrue(registry.isRegistered(usdcKey), "the moved reserve's SUPPLY leg IS registered");
        assertTrue(registry.isMarketRegistered(usdcMarketKey), "and market (7,0) is registered");
        assertFalse(registry.isMarketRegistered(unregisteredMarket), "but market (7,1) is not");

        bytes memory data =
            abi.encodePacked(oracleId, unregisteredMarket, CHAIN_1_USDC, SPOKE, USDC_RESERVE_ID, LEND, false);
        _executeExpectFailure(address(lendHook), data, AaveV4ReserveRegistryV2.MARKET_NOT_REGISTERED.selector);
        assertEq(_supplied(), 0, "nothing supplied");
    }

    /// @dev One mode per (account, reserve): once the account flags the reserve as collateral (LOAN
    ///      semantics), both idle hooks refuse it; clearing the flag restores idle operation.
    function test_CollateralFlaggedReserve_IsRefusedByBothHooks() public {
        uint256 credited = _lend();
        vm.prank(accountEth);
        IAaveV4Spoke(SPOKE).setUsingAsCollateral(USDC_RESERVE_ID, true, accountEth);
        assertTrue(_isCollateral());

        _executeExpectFailure(
            address(redeemHook),
            _redeemData(type(uint256).max, false),
            BaseAaveV4MoneyMarketHook.RESERVE_IS_COLLATERAL.selector
        );
        _executeExpectFailure(
            address(lendHook), _lendData(LEND), BaseAaveV4MoneyMarketHook.RESERVE_IS_COLLATERAL.selector
        );
        assertEq(_supplied(), credited, "nothing moved");
        assertEq(superLedger.usersAccumulatorShares(accountEth, usdcMarketKey), credited, "ledger untouched");

        vm.prank(accountEth);
        IAaveV4Spoke(SPOKE).setUsingAsCollateral(USDC_RESERVE_ID, false, accountEth);
        _execute(address(redeemHook), _redeemData(type(uint256).max, false));
        assertEq(_supplied(), 0);
        assertEq(superLedger.usersAccumulatorShares(accountEth, usdcMarketKey), 0);
    }

    /*//////////////////////////////////////////////////////////////
       SUP-21263: EITHER LEG MAY BE THE IDLE TARGET
    //////////////////////////////////////////////////////////////*/

    /// @notice THE FEATURE on live Ethereum state: `usdcMarketKey` is the market `(supply = USDC 7,
    ///         borrow = WETH 0)`, and WETH — its LOAN leg — is now a legal idle target under that SAME
    ///         header. Before SUP-21263 this reverted `MARKET_KEY_MISMATCH`.
    function test_IdleWETH_UnderUsdcCollateralMarket_DoesNotRevert() public {
        _getTokens(CHAIN_1_WETH, accountEth, 2 ether);
        uint256 walletBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);

        _execute(address(lendHook), _wethLegData(1 ether, false));

        uint256 credited = IAaveV4Spoke(SPOKE).getUserSuppliedAssets(0, accountEth);
        assertEq(walletBefore - IERC20(CHAIN_1_WETH).balanceOf(accountEth), 1 ether, "WETH debited exactly");
        assertLe(1 ether - credited, 1, "WETH position credited");
        assertEq(
            superLedger.usersAccumulatorShares(accountEth, usdcMarketKey),
            credited,
            "settled under the market key whose BORROW leg this is"
        );
    }

    /// @notice R1, ON LIVE STATE AND THROUGH THE REAL LEDGER. Both legs of ONE market idled at once share a
    ///         single `(user, yieldSource)` accumulator — which the ticket's motivation requires — so the
    ///         accumulator sums an 18-decimal WETH position with a 6-decimal USDC one. It is therefore NOT a
    ///         meaningful NAV number; `AaveV4ReserveOracle.getOwnerSnapshot` is. What IS guaranteed, and
    ///         pinned here, is that fully redeeming both legs returns the accumulator to exactly zero, so no
    ///         exit is ever trapped and no fee can leak while `feePercent == 0`.
    function test_BothLegsIdleUnderOneMarketKey_LedgerSumsAndNetsToZero() public {
        _getTokens(CHAIN_1_WETH, accountEth, 2 ether);

        uint256 usdcCredited = _lend(); // leg 7, the market's SUPPLY leg
        _execute(address(lendHook), _wethLegData(1 ether, false)); // leg 0, its BORROW leg
        uint256 wethCredited = IAaveV4Spoke(SPOKE).getUserSuppliedAssets(0, accountEth);
        assertGt(usdcCredited, 0, "fixture sanity: the USDC lend credited");
        assertGt(wethCredited, 0, "fixture sanity: the WETH lend credited");

        assertEq(
            superLedger.usersAccumulatorShares(accountEth, usdcMarketKey),
            usdcCredited + wethCredited,
            "ONE accumulator, two reserves, incommensurable units - documented, not defended against"
        );

        _execute(address(redeemHook), _redeemData(type(uint256).max, false));
        _execute(address(redeemHook), _wethLegData(type(uint256).max, false));

        assertEq(_supplied(), 0, "USDC leg closed");
        assertEq(IAaveV4Spoke(SPOKE).getUserSuppliedAssets(0, accountEth), 0, "WETH leg closed");
        assertEq(superLedger.usersAccumulatorShares(accountEth, usdcMarketKey), 0, "shares net to zero");
        assertEq(superLedger.usersAccumulatorCostBasis(accountEth, usdcMarketKey), 0, "cost basis nets to zero");
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(feeRecipient), 0, "no USDC fee leaked");
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(feeRecipient), 0, "no WETH fee leaked");
    }

    /// @dev An idle body targeting reserve 0 (WETH) under `usdcMarketKey` — the market's BORROW leg.
    function _wethLegData(uint256 amount, bool usePrev) internal view returns (bytes memory) {
        return abi.encodePacked(oracleId, usdcMarketKey, CHAIN_1_WETH, SPOKE, uint256(0), amount, usePrev);
    }

    /// @notice A reserve the account already borrows is refused by lend (RESERVE_IS_BORROWED) while
    ///         redeem still exits the idle position: the same-asset supply + debt state is never trapped.
    function test_BorrowedReserve_LendRefused_RedeemAllowed() public {
        uint256 credited = _lend();

        // Take USDC debt on reserve 7 against 1 WETH pledged on reserve 0 (direct self-calls)
        _getTokens(CHAIN_1_WETH, accountEth, 1 ether);
        vm.startPrank(accountEth);
        IERC20(CHAIN_1_WETH).approve(SPOKE, 1 ether);
        IAaveV4Spoke(SPOKE).supply(0, 1 ether, accountEth);
        IAaveV4Spoke(SPOKE).setUsingAsCollateral(0, true, accountEth);
        IAaveV4Spoke(SPOKE).borrow(USDC_RESERVE_ID, 100e6, accountEth);
        vm.stopPrank();
        (bool isColl, bool isBorrowing) = IAaveV4Spoke(SPOKE).getUserReserveStatus(USDC_RESERVE_ID, accountEth);
        assertTrue(!isColl && isBorrowing, "USDC: un-flagged supply with debt");

        _executeExpectFailure(
            address(lendHook), _lendData(LEND), BaseAaveV4MoneyMarketHook.RESERVE_IS_BORROWED.selector
        );
        assertEq(_supplied(), credited, "nothing moved");

        _execute(address(redeemHook), _redeemData(type(uint256).max, false));
        assertEq(_supplied(), 0, "idle position exited despite the debt");
        assertEq(superLedger.usersAccumulatorShares(accountEth, usdcMarketKey), 0, "ledger nets");
    }

    /// @dev FAIL-CLOSED through the real userOp path: the spoke-as-header case AND both of the reserve's
    ///      legacy leg keys are refused. The reserve-key cases are the migration property — an old
    ///      reserve-keyed idle root against the redeployed hook cannot execute.
    ///      SUP-21263 CHANGED THE ERROR, not the outcome: membership is now a registry lookup, so a header
    ///      that is not a registered market fails `MARKET_NOT_REGISTERED` in the hook rather than
    ///      `MARKET_KEY_MISMATCH` from the pure pin — and it fails at BUILD, before any Spoke call.
    function test_Lend_RevertIf_HeaderKeyMismatch() public {
        address[3] memory wrong = [
            SPOKE, // LOAN-style: spoke in the header
            registry.computeReserveKey(SPOKE, USDC_RESERVE_ID), // the old SUP-21142 idle header
            registry.computeDebtKey(SPOKE, USDC_RESERVE_ID) // the reserve's other leg
        ];
        for (uint256 i; i < wrong.length; ++i) {
            bytes memory data = abi.encodePacked(oracleId, wrong[i], CHAIN_1_USDC, SPOKE, USDC_RESERVE_ID, LEND, false);
            _executeExpectFailure(address(lendHook), data, AaveV4ReserveRegistryV2.MARKET_NOT_REGISTERED.selector);
        }
    }

    function test_Lend_RevertIf_UnderlyingMismatch() public {
        _executeExpectFailure(
            address(lendHook),
            _idleData(CHAIN_1_WETH, USDC_RESERVE_ID, LEND, false),
            BaseAaveV4MoneyMarketHook.TOKEN_RESERVE_MISMATCH.selector
        );
    }
}
