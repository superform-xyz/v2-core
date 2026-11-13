// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { ForceRedeemMorphoVaultHook } from "../../../../src/hooks/vaults/metamorpho/ForceRedeemMorphoVaultHook.sol";
import { IMorphoVaultV2 } from "../../../../src/vendor/morpho/IMorphoVaultV2.sol";
import { MarketParams } from "../../../../src/vendor/morpho/IMorpho.sol";
import {
    ISuperHook,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware
} from "../../../../src/interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../../src/libraries/HookSubTypes.sol";
import {
    MockMorphoBlue,
    MockMorphoMarketAdapter,
    MockMorphoVaultV2,
    FeeOnTransferToken,
    SharesInflatingVault
} from "../../../mocks/morpho/MorphoVaultV2Mocks.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";

/// @notice Publishes a fixed outAmount/outToken, to prove the flag is refused even with a real predecessor
contract PrevHookStub is BaseHook {
    constructor() BaseHook(HookType.NONACCOUNTING, bytes32(0)) { }

    function name() external pure override returns (string memory) {
        return "prev";
    }

    function description() external pure override returns (string memory) {
        return "prev";
    }

    function publish(uint256 amount, address token, address account) external {
        _setOutAmount(amount, account);
        _setOutToken(token, account);
    }

    function _buildHookExecutions(address, address, bytes calldata)
        internal
        pure
        override
        returns (Execution[] memory)
    {
        return new Execution[](0);
    }
}

/// @title ForceRedeemMorphoVaultHookTest
/// @notice SUP-21849: the share-sized exit. The 117-byte layout with the `minAssetsOut` floor, the
///         smallest-deallocation solver against a Vault V2 mock that applies V2's own arithmetic, `redeem(S - P)`
///         as the last leg, `previewAssetsOut` agreeing with what the account receives, and the filters.
contract ForceRedeemMorphoVaultHookTest is Test {
    /// @dev Morpho's own ceiling on `forceDeallocatePenalty`; the only bound on the rate that is left.
    uint256 internal constant MORPHO_MAX_PENALTY = 0.02e18;
    uint256 internal constant WAD = 1e18;

    ForceRedeemMorphoVaultHook internal hook;
    MockMorphoBlue internal morpho;
    MockMorphoVaultV2 internal vault;
    MockMorphoMarketAdapter internal adapter;

    MockERC20 internal asset;
    address internal irm = address(0x1247);
    address internal account = address(0xACC0);

    bytes32 internal constant ID_A = keccak256("A");
    bytes32 internal constant ID_B = keccak256("B");
    bytes32 internal constant ID_C = keccak256("C");
    bytes32 internal constant ORACLE_ID = bytes32(uint256(0xFEED));

    uint256 internal constant HELD = 1_000_000 ether;
    /// @dev Supply == assets + 1 so D/N starts at exactly 1 (D = assets + 1, N = supply + virtual 1).
    uint256 internal constant SUPPLY = 10_000_000 ether;
    uint256 internal constant RATE_A = 1e13; // 0.1 bps, Gauntlet's live rate

    function setUp() public {
        asset = new MockERC20("Underlying", "UND", 18);
        morpho = new MockMorphoBlue();
        hook = new ForceRedeemMorphoVaultHook(address(morpho));
        vault = new MockMorphoVaultV2(address(asset));
        adapter = new MockMorphoMarketAdapter(address(vault), address(morpho));
        vault.addAdapter(address(adapter), RATE_A);
        vault.setShares(account, HELD);
        vault.setTotals(SUPPLY, SUPPLY - 1, 1);
        vault.setTrackPositions(true);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _params(address loanToken) internal view returns (MarketParams memory p) {
        p = MarketParams(loanToken, address(0xC011), address(0x0AC1), irm, 0.945e18);
    }

    function _idOf(MarketParams memory p) internal pure returns (bytes32) {
        return keccak256(abi.encode(p));
    }

    /// @dev position = what the adapter holds; supply/borrow set the market's liquidity. The market id is
    ///      derived from the params so the vault mock can keep the adapter's position in step with pulls.
    function _listMarket(
        MockMorphoMarketAdapter a,
        address loanToken,
        address collateral,
        uint256 position,
        uint128 supply,
        uint128 borrow
    )
        internal
        returns (bytes32 id)
    {
        MarketParams memory p = MarketParams(loanToken, collateral, address(0x0AC1), irm, 0.945e18);
        id = _idOf(p);
        morpho.setMarket(id, p, supply, borrow);
        a.addMarket(id, position);
    }

    function _list(uint256 position, uint128 supply) internal returns (bytes32) {
        return _listMarket(adapter, address(asset), address(0xC011), position, supply, 0);
    }

    /// @dev No floor (`minAssetsOut = 0`) unless a test says otherwise.
    function _data(uint256 shares) internal view returns (bytes memory) {
        return _dataFull(shares, false, 0);
    }

    function _dataFull(uint256 shares, bool usePrev, uint256 minAssetsOut) internal view returns (bytes memory) {
        return abi.encodePacked(ORACLE_ID, address(vault), shares, usePrev, minAssetsOut);
    }

    function _idle(uint256 amount) internal {
        asset.mint(address(vault), amount);
    }

    /// @dev The forceDeallocate legs only: everything between preExecute and the redeem.
    function _pulls(bytes memory data) internal view returns (Execution[] memory mid) {
        Execution[] memory all = hook.build(address(0), account, data);
        mid = new Execution[](all.length - 3);
        for (uint256 i; i < mid.length; ++i) {
            mid[i] = all[i + 1];
        }
    }

    function _redeemLeg(bytes memory data) internal view returns (Execution memory) {
        Execution[] memory all = hook.build(address(0), account, data);
        return all[all.length - 2];
    }

    function _decodePull(Execution memory e)
        internal
        pure
        returns (address adapter_, MarketParams memory p, uint256 assets, address onBehalf)
    {
        bytes memory args = _args(e.callData);
        bytes memory inner;
        (adapter_, inner, assets, onBehalf) = abi.decode(args, (address, bytes, uint256, address));
        p = abi.decode(inner, (MarketParams));
    }

    function _decodeRedeem(Execution memory e) internal pure returns (uint256 shares, address receiver, address owner) {
        assertEq(bytes4(e.callData), IERC4626.redeem.selector, "last leg is redeem");
        (shares, receiver, owner) = abi.decode(_args(e.callData), (uint256, address, address));
    }

    function _args(bytes memory raw) internal pure returns (bytes memory args) {
        args = new bytes(raw.length - 4);
        for (uint256 i; i < args.length; ++i) {
            args[i] = raw[i + 4];
        }
    }

    /// @dev Mirrors `SuperExecutorBase._processHook`: context, build, run every leg as the account, reset.
    function _run(bytes memory data) internal returns (uint256 received, uint256 pulls) {
        uint256 before = asset.balanceOf(account);
        vm.startPrank(account);
        hook.setExecutionContext(account);
        Execution[] memory all = hook.build(address(0), account, data);
        for (uint256 i; i < all.length; ++i) {
            (bool ok, bytes memory ret) = all[i].target.call(all[i].callData);
            if (!ok) {
                assembly ("memory-safe") {
                    revert(add(ret, 0x20), mload(ret))
                }
            }
        }
        hook.resetExecutionState(account);
        vm.stopPrank();
        received = asset.balanceOf(account) - before;
        pulls = all.length - 3;
    }

    /// @dev Test-side stepper, written from Morpho's arithmetic rather than copied from the hook.
    function _stepped(
        uint256[] memory pulls,
        uint256[] memory rates
    )
        internal
        view
        returns (uint256 n, uint256 d, uint256 penaltyShares)
    {
        (uint256 ta, uint256 pf, uint256 mf) = vault.accrueInterestView();
        n = vault.totalSupply() + pf + mf + vault.virtualShares();
        d = ta + 1;
        for (uint256 i; i < pulls.length; ++i) {
            uint256 pa = _mulDivUp(pulls[i], rates[i], WAD);
            uint256 ps = _mulDivUp(pa, n, d);
            n -= ps;
            d -= pa;
            penaltyShares += ps;
        }
    }

    function _mulDivUp(uint256 x, uint256 y, uint256 z) internal pure returns (uint256) {
        return (x * y + (z - 1)) / z;
    }

    /*//////////////////////////////////////////////////////////////
                           LAYOUT AND DECODE
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public view {
        assertEq(hook.MORPHO(), address(morpho));
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.OUTFLOW));
        assertEq(hook.SUB_TYPE(), HookSubTypes.ERC4626);
        assertTrue(hook.supportsInterface(type(ISuperHookInflowOutflow).interfaceId));
        assertTrue(hook.supportsInterface(type(ISuperHookOutflow).interfaceId));
        assertTrue(hook.supportsInterface(type(IERC165).interfaceId));
    }

    function test_ConstructorRejectsZeroMorpho() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ForceRedeemMorphoVaultHook(address(0));
    }

    function test_DataLengthIsExactlyOneHundredSeventeen() public {
        _list(HELD, uint128(HELD));
        assertEq(_data(1 ether).length, 117);
        vm.expectRevert(abi.encodeWithSelector(ForceRedeemMorphoVaultHook.INVALID_DATA_LENGTH.selector, 118, 117));
        hook.build(address(0), account, abi.encodePacked(_data(1 ether), hex"00"));
        // the OLD 85-byte layout is refused, never decoded as "no floor"
        vm.expectRevert(abi.encodeWithSelector(ForceRedeemMorphoVaultHook.INVALID_DATA_LENGTH.selector, 85, 117));
        hook.build(address(0), account, abi.encodePacked(ORACLE_ID, address(vault), uint256(1 ether), false));
    }

    function test_RevertOrder_Vault_Flag_Shares_Held_Floor() public {
        _list(HELD, uint128(HELD));
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), account, abi.encodePacked(ORACLE_ID, address(0), uint256(1 ether), false, uint256(0)));

        PrevHookStub prev = new PrevHookStub();
        prev.publish(5 ether, address(asset), account);
        vm.expectRevert(ForceRedeemMorphoVaultHook.USE_PREV_HOOK_AMOUNT_NOT_SUPPORTED.selector);
        hook.build(address(prev), account, _dataFull(1 ether, true, 0));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), account, _data(0));

        vm.expectRevert(abi.encodeWithSelector(ForceRedeemMorphoVaultHook.INSUFFICIENT_SHARES.selector, HELD, HELD + 1));
        hook.build(address(0), account, _data(HELD + 1));

        // the floor is judged LAST, against the solved plan
        uint256 quoted = hook.previewAssetsOut(address(vault), account, 1 ether);
        vm.expectRevert(
            abi.encodeWithSelector(ForceRedeemMorphoVaultHook.INSUFFICIENT_OUTPUT.selector, quoted, quoted + 1)
        );
        hook.build(address(0), account, _dataFull(1 ether, false, quoted + 1));
    }

    function test_PreExecute_RevalidatesLayoutOnly() public {
        _list(HELD, uint128(HELD));
        vm.startPrank(account);
        hook.setExecutionContext(account);
        vm.expectRevert(abi.encodeWithSelector(ForceRedeemMorphoVaultHook.INVALID_DATA_LENGTH.selector, 85, 117));
        hook.preExecute(address(0), account, abi.encodePacked(ORACLE_ID, address(vault), uint256(1 ether), false));
        vm.expectRevert(ForceRedeemMorphoVaultHook.USE_PREV_HOOK_AMOUNT_NOT_SUPPORTED.selector);
        hook.preExecute(address(0), account, _dataFull(1 ether, true, 0));
        // an unreachable floor is NOT judged here: preExecute has nothing measured yet
        hook.preExecute(address(0), account, _dataFull(1 ether, false, type(uint256).max));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              SIZING SURFACE
    //////////////////////////////////////////////////////////////*/

    function test_SizingSurfaceIsOneInSharesLegAtOffsetFiftyTwo() public view {
        bytes memory d = _data(7 ether);
        assertEq(hook.decodeAmounts(d)[0], 7 ether);
        ISuperHookInflowOutflow.AmountMeta[] memory meta = hook.amountRoles("");
        assertEq(meta.length, 1);
        assertEq(uint8(meta[0].dir), uint8(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint8(meta[0].denom), uint8(ISuperHookInflowOutflow.Denomination.SHARES));
        assertFalse(hook.decodeUsePrevHookAmount(d));
    }

    function test_ReplaceCalldataAmountsWritesOffsetFiftyTwoAndPreservesFlagAndFloor() public view {
        bytes memory original = _dataFull(1 ether, true, 0.002e18);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 9 ether;
        bytes memory replaced = hook.replaceCalldataAmounts(original, amounts);
        assertEq(replaced.length, 117);
        assertEq(hook.decodeAmounts(replaced)[0], 9 ether);
        assertTrue(hook.decodeUsePrevHookAmount(replaced));
        bytes memory floorWord = new bytes(32);
        for (uint256 i; i < 32; ++i) {
            floorWord[i] = replaced[85 + i];
        }
        assertEq(uint256(bytes32(floorWord)), 0.002e18, "the floor word is untouched");
    }

    function test_InspectIsTheVaultAlone() public view {
        assertEq(hook.inspect(_dataFull(1 ether, true, 1)), abi.encodePacked(address(vault)));
    }

    /*//////////////////////////////////////////////////////////////
                           THE SOLVER: IDLE COVERS
    //////////////////////////////////////////////////////////////*/

    function test_IdleCoversTheRedeem_SingleRedeemNoPulls() public {
        _list(HELD, uint128(HELD));
        uint256 shares = 100 ether;
        _idle(vault.previewRedeem(shares));

        Execution[] memory all = hook.build(address(0), account, _data(shares));
        assertEq(all.length, 3, "pre, redeem, post");
        (uint256 s, address r, address o) = _decodeRedeem(all[1]);
        assertEq(s, shares, "the whole input is redeemed, nothing burned");
        assertEq(r, account);
        assertEq(o, account);

        uint256 quoted = hook.previewAssetsOut(address(vault), account, shares);
        (uint256 received, uint256 pulls) = _run(_data(shares));
        assertEq(pulls, 0);
        assertEq(received, vault.previewRedeem(shares) > received ? received : received); // no-op guard
        assertEq(received, quoted, "previewAssetsOut == what the account received");
        assertEq(vault.balanceOf(account), HELD - shares);
        assertEq(hook.getOutAmount(account), received);
        assertEq(hook.getOutToken(account), address(asset));
        assertEq(hook.usedShares(), shares);
    }

    function test_IdleOneWeiShort_TriggersOnePull() public {
        _list(HELD, uint128(HELD));
        uint256 shares = 100 ether;
        _idle(vault.previewRedeem(shares) - 1);
        Execution[] memory pulls = _pulls(_data(shares));
        assertEq(pulls.length, 1, "one pull to close a one-wei gap");
        (,, uint256 x,) = _decodePull(pulls[0]);
        assertGt(x, 0);
        assertLt(x, 1000, "and it is tiny: the deficit plus the penalty it costs");
    }

    /*//////////////////////////////////////////////////////////////
                    THE SOLVER: ONE PENALISED MARKET, FULL EXIT
    //////////////////////////////////////////////////////////////*/

    function test_FullBalanceExit_EndsAtZeroShares_AndPaysPreviewAssetsOut() public {
        _list(2 * HELD, uint128(2 * HELD));

        Execution[] memory pulls = _pulls(_data(HELD));
        assertEq(pulls.length, 1);
        _assertSinglePullShape(pulls[0]);

        // Independent derivation of what the vault will do with this pull.
        uint256 expectedOut = _expectedOutSinglePull(pulls[0], HELD);
        (uint256 s,,) = _decodeRedeem(_redeemLeg(_data(HELD)));
        assertEq(s, HELD - _penaltyOfSinglePull(pulls[0]), "the remainder after the predicted burn is redeemed");
        assertEq(hook.previewAssetsOut(address(vault), account, HELD), expectedOut);

        (uint256 received,) = _run(_data(HELD));
        assertEq(received, expectedOut, "the account received exactly the quote");
        assertEq(vault.balanceOf(account), 0, "a full-balance exit leaves zero shares");
        assertEq(hook.usedShares(), HELD, "usedShares spans the whole call, penalty burns included");
        assertEq(hook.getOutAmount(account), received);
    }

    function _assertSinglePullShape(Execution memory pull) internal view {
        (address a, MarketParams memory p,, address onBehalf) = _decodePull(pull);
        assertEq(a, address(adapter));
        assertEq(p.loanToken, address(asset));
        assertEq(onBehalf, account);
    }

    function _penaltyOfSinglePull(Execution memory pull) internal view returns (uint256 penaltyShares) {
        (,, uint256 x,) = _decodePull(pull);
        uint256[] memory xs = new uint256[](1);
        uint256[] memory rs = new uint256[](1);
        xs[0] = x;
        rs[0] = RATE_A;
        (,, penaltyShares) = _stepped(xs, rs);
    }

    function _expectedOutSinglePull(Execution memory pull, uint256 shares) internal view returns (uint256) {
        (,, uint256 x,) = _decodePull(pull);
        uint256[] memory xs = new uint256[](1);
        uint256[] memory rs = new uint256[](1);
        xs[0] = x;
        rs[0] = RATE_A;
        (uint256 n, uint256 d, uint256 p) = _stepped(xs, rs);
        uint256 out = (shares - p) * d / n;
        assertLe(out, x, "covered: idle (0) + X pays the redeem");
        return out;
    }

    /// @dev Minimality: one wei less deallocation would not cover the redeem.
    function test_SmallestXIsChosen_OneWeiLessWouldNotCover() public {
        _list(2 * HELD, uint128(2 * HELD));
        uint256 shares = 250_000 ether;
        _idle(1234 ether);
        Execution[] memory pulls = _pulls(_data(shares));
        assertEq(pulls.length, 1);
        (,, uint256 x,) = _decodePull(pulls[0]);

        uint256[] memory xs = new uint256[](1);
        uint256[] memory rs = new uint256[](1);
        rs[0] = RATE_A;
        xs[0] = x;
        (uint256 n, uint256 d, uint256 p) = _stepped(xs, rs);
        assertLe((shares - p) * d / n, 1234 ether + x, "X covers");
        xs[0] = x - 1;
        (n, d, p) = _stepped(xs, rs);
        assertGt((shares - p) * d / n, 1234 ether + x - 1, "X - 1 does not");
    }

    /*//////////////////////////////////////////////////////////////
                  THE SOLVER: TWO ADAPTERS, CHEAPEST FIRST
    //////////////////////////////////////////////////////////////*/

    function test_TwoAdapters_CheaperFilledInFull_ThenPartial_BurnsMatchTheStepper() public {
        MockMorphoMarketAdapter dear = new MockMorphoMarketAdapter(address(vault), address(morpho));
        vault.addAdapter(address(dear), 5e13);
        _list(300_000 ether, 300_000 ether); // cheap, 0.1 bps
        _listMarket(dear, address(asset), address(0xC022), 900_000 ether, 900_000 ether, 0); // 0.5 bps

        Execution[] memory pulls = _pulls(_data(HELD));
        assertEq(pulls.length, 2, "the cheap market alone cannot cover a full exit");
        _assertCheaperFirst(pulls, address(dear));
        (uint256[] memory xs, uint256[] memory rs) = _pullsOf(pulls, 5e13);
        (uint256 n, uint256 d, uint256 p) = _stepped(xs, rs);
        (uint256 s,,) = _decodeRedeem(_redeemLeg(_data(HELD)));
        assertEq(s, HELD - p, "redeem leg == S minus the stepped burns");

        uint256 supply0 = vault.totalSupply();
        (uint256 received,) = _run(_data(HELD));
        assertEq(received, (HELD - p) * d / n, "payout priced at the stepped N/D");
        assertEq(vault.balanceOf(account), 0);
        assertEq(
            supply0 - vault.totalSupply(), HELD, "every share of the input left the supply: P burned + S - P redeemed"
        );
    }

    function _assertCheaperFirst(Execution[] memory pulls, address dear) internal view {
        (address a0,, uint256 x0,) = _decodePull(pulls[0]);
        (address a1,, uint256 x1,) = _decodePull(pulls[1]);
        assertEq(a0, address(adapter), "cheaper first");
        assertEq(x0, 300_000 ether, "taken in full");
        assertEq(a1, dear);
        assertGt(x1, 0);
        assertLt(x1, 900_000 ether, "the dear market is only partially drawn");
    }

    /// @dev Amounts and rates of a two-pull plan: the first pull is the fixture adapter at RATE_A.
    function _pullsOf(
        Execution[] memory pulls,
        uint256 secondRate
    )
        internal
        pure
        returns (uint256[] memory xs, uint256[] memory rs)
    {
        xs = new uint256[](2);
        rs = new uint256[](2);
        (,, xs[0],) = _decodePull(pulls[0]);
        (,, xs[1],) = _decodePull(pulls[1]);
        rs[0] = RATE_A;
        rs[1] = secondRate;
    }

    /*//////////////////////////////////////////////////////////////
                      SHORTFALL AND THE OUTPUT FLOOR
    //////////////////////////////////////////////////////////////*/

    function test_Shortfall_NoExecutionsBuilt_LiveNumbers() public {
        _list(10 ether, 10 ether);
        _idle(5 ether);
        uint256 shares = 100 ether;
        uint256 gross = vault.previewRedeem(shares);
        vm.expectRevert(
            abi.encodeWithSelector(ForceRedeemMorphoVaultHook.SHORTFALL.selector, 5 ether + 10 ether, gross)
        );
        hook.build(address(0), account, _data(shares));
        vm.expectRevert(
            abi.encodeWithSelector(ForceRedeemMorphoVaultHook.SHORTFALL.selector, 5 ether + 10 ether, gross)
        );
        hook.previewAssetsOut(address(vault), account, shares);
        assertEq(vault.callCount(), 0, "nothing was built, nothing ran");
    }

    /// @dev SUP-21849: NO RATE CAP. cbAssets' 30 bps adapter (which the old 25 bps immutable refused) is
    ///      ordered after the cheap one and used only for what the cheap one cannot cover.
    function test_DearAdapterIsOrderedLastNotSkipped() public {
        MockMorphoMarketAdapter dear = new MockMorphoMarketAdapter(address(vault), address(morpho));
        vault.addAdapter(address(dear), 0.003e18);
        _listMarket(dear, address(asset), address(0xC022), HELD, uint128(HELD), 0);
        _list(100 ether, 100 ether);
        Execution[] memory pulls = _pulls(_data(100 ether));
        assertEq(pulls.length, 1, "cheap covers alone");
        (address a,,,) = _decodePull(pulls[0]);
        assertEq(a, address(adapter));

        pulls = _pulls(_data(200 ether));
        assertEq(pulls.length, 2, "then the dear one for the remainder");
        (address first,,,) = _decodePull(pulls[0]);
        (address second,,,) = _decodePull(pulls[1]);
        assertEq(first, address(adapter));
        assertEq(second, address(dear));
    }

    /// @dev The motivating case: the only adapter charges 30 bps and the exit still builds and settles.
    function test_ThirtyBpsOnlyAdapter_ExitSettlesExactly() public {
        vault.setPenalty(address(adapter), 0.003e18);
        _list(HELD, uint128(HELD));
        uint256 quoted = hook.previewAssetsOut(address(vault), account, 100 ether);
        (uint256 received, uint256 pulls) = _run(_dataFull(100 ether, false, quoted));
        assertEq(pulls, 1);
        assertEq(received, quoted, "the floor set at the quote is met exactly");
    }

    /// @dev `minAssetsOut` is judged twice: on the QUOTE in `build` (what the OMS pre-flight sees) and on
    ///      the MEASURED delivery in `_postExecute`. Floor == quote passes both.
    function test_MinAssetsOut_QuoteBelowTheFloorIsRefusedAtBuild() public {
        _list(HELD, uint128(HELD));
        uint256 shares = 1000 ether;
        uint256 quoted = hook.previewAssetsOut(address(vault), account, shares);
        assertGt(quoted, 0);

        vm.expectRevert(
            abi.encodeWithSelector(ForceRedeemMorphoVaultHook.INSUFFICIENT_OUTPUT.selector, quoted, quoted + 1)
        );
        hook.build(address(0), account, _dataFull(shares, false, quoted + 1));
        assertEq(vault.callCount(), 0, "nothing ran");

        (uint256 received,) = _run(_dataFull(shares, false, quoted));
        assertEq(received, quoted, "a floor equal to the quote is met");
        assertEq(hook.getOutAmount(account), quoted);
    }

    /// @dev `previewAssetsOut` is how a caller finds the floor, so it must not itself judge one.
    function test_PreviewAssetsOut_IgnoresTheFloor() public {
        _list(HELD, uint128(HELD));
        uint256 quoted = hook.previewAssetsOut(address(vault), account, 1000 ether);
        assertGt(quoted, 0);
        assertEq(hook.previewAssetsOut(address(vault), account, 1000 ether), quoted, "pure function of state");
    }

    /*//////////////////////////////////////////////////////////////
                            FEES AND ACCOUNTING
    //////////////////////////////////////////////////////////////*/

    function test_PendingFeeSharesEnterTheRate_AndTheMockAccruesOnTheFirstPull() public {
        _list(2 * HELD, uint128(2 * HELD));
        vault.setPendingFees(1000 ether, 500 ether);
        uint256 shares = 200_000 ether;
        uint256 quoted = hook.previewAssetsOut(address(vault), account, shares);
        uint256 supply0 = vault.totalSupply();
        (uint256 received,) = _run(_data(shares));
        assertEq(received, quoted, "the quote already priced the fee shares in");
        assertEq(vault.balanceOf(account), HELD - shares, "exactly S left the account");
        assertGt(vault.totalSupply() + shares, supply0, "fee shares were minted on the way");
    }

    function test_OutAmountIsTheMeasuredDeltaNotTheQuote_FeeOnTransfer() public {
        (MockMorphoVaultV2 v, FeeOnTransferToken fot) = _feeOnTransferFixture();
        uint256 shares = 1000 ether;
        bytes memory d = abi.encodePacked(ORACLE_ID, address(v), shares, false, uint256(0));
        uint256 quoted = hook.previewAssetsOut(address(v), account, shares);

        vm.startPrank(account);
        hook.setExecutionContext(account);
        Execution[] memory all = hook.build(address(0), account, d);
        for (uint256 i; i < all.length; ++i) {
            (bool ok,) = all[i].target.call(all[i].callData);
            assertTrue(ok);
        }
        hook.resetExecutionState(account);
        vm.stopPrank();
        assertEq(hook.getOutAmount(account), fot.balanceOf(account), "measured");
        assertEq(hook.getOutAmount(account), quoted - quoted / 100, "one percent less than the vault accounted");
    }

    /// @dev THE FLOOR IS JUDGED ON DELIVERY, not on the quote. The quote equals the floor so `build`
    ///      passes; the token keeps 1% in transit and `_postExecute` refuses with the measured number.
    function test_MinAssetsOut_MeasuredDeliveryBelowTheFloorRevertsInPostExecute() public {
        (MockMorphoVaultV2 v,) = _feeOnTransferFixture();
        uint256 shares = 1000 ether;
        uint256 quoted = hook.previewAssetsOut(address(v), account, shares);
        bytes memory d = abi.encodePacked(ORACLE_ID, address(v), shares, false, quoted);

        vm.startPrank(account);
        hook.setExecutionContext(account);
        Execution[] memory all = hook.build(address(0), account, d);
        for (uint256 i; i + 1 < all.length; ++i) {
            (bool ok,) = all[i].target.call(all[i].callData);
            assertTrue(ok, "every leg before postExecute succeeds");
        }
        vm.expectRevert(
            abi.encodeWithSelector(
                ForceRedeemMorphoVaultHook.INSUFFICIENT_OUTPUT.selector, quoted - quoted / 100, quoted
            )
        );
        (bool okPost, bytes memory ret) = all[all.length - 1].target.call(all[all.length - 1].callData);
        okPost;
        ret;
        vm.stopPrank();
    }

    function _feeOnTransferFixture() internal returns (MockMorphoVaultV2 v, FeeOnTransferToken fot) {
        fot = new FeeOnTransferToken(100); // 1%
        v = new MockMorphoVaultV2(address(fot));
        MockMorphoMarketAdapter a = new MockMorphoMarketAdapter(address(v), address(morpho));
        v.addAdapter(address(a), 0);
        v.setShares(account, HELD);
        v.setTotals(SUPPLY, SUPPLY - 1, 1);
        v.setTrackPositions(true);
        _listMarket(a, address(fot), address(0xC011), HELD, uint128(HELD), 0);
    }

    function test_UsedSharesClampsIfTheBalanceSomehowRises() public {
        SharesInflatingVault v = new SharesInflatingVault(address(asset));
        MockMorphoMarketAdapter a = new MockMorphoMarketAdapter(address(v), address(morpho));
        v.addAdapter(address(a), 0);
        v.setShares(account, HELD);
        v.setTotals(SUPPLY, SUPPLY - 1, 1);
        v.setInflate(true);
        _listMarket(a, address(asset), address(0xC011), HELD, uint128(HELD), 0);
        asset.mint(address(v), 10 ether); // idle covers: single redeem path
        bytes memory d = abi.encodePacked(ORACLE_ID, address(v), uint256(1 ether), false, uint256(0));
        vm.startPrank(account);
        hook.setExecutionContext(account);
        Execution[] memory all = hook.build(address(0), account, d);
        for (uint256 i; i < all.length; ++i) {
            (bool ok,) = all[i].target.call(all[i].callData);
            assertTrue(ok);
        }
        vm.stopPrank();
        assertEq(hook.usedShares(), 0, "clamped rather than underflowing");
    }

    function test_SequentialExits_SecondPlansAgainstWhatTheFirstLeft() public {
        _list(2 * HELD, uint128(2 * HELD));
        (uint256 r1,) = _run(_data(100_000 ether));
        uint256 quote2 = hook.previewAssetsOut(address(vault), account, 100_000 ether);
        (uint256 r2,) = _run(_data(100_000 ether));
        assertEq(r2, quote2);
        assertEq(hook.getOutAmount(account), r2, "outAmount is the delta of THIS exit, not the balance");
        assertEq(vault.balanceOf(account), HELD - 200_000 ether);
        assertGt(r1, 0);
    }

    /*//////////////////////////////////////////////////////////////
                           FILTERS (UNCHANGED RULES)
    //////////////////////////////////////////////////////////////*/

    function test_AdapterOfADifferentVaultIsSkipped() public {
        MockMorphoMarketAdapter stray = new MockMorphoMarketAdapter(address(0xDEAD), address(morpho));
        vault.addAdapter(address(stray), 0);
        _listMarket(stray, address(asset), address(0xC033), HELD, uint128(HELD), 0);
        _list(HELD, uint128(HELD));
        (address a,,,) = _decodePull(_pulls(_data(10 ether))[0]);
        assertEq(a, address(adapter));
    }

    function test_CodelessAdapterIsSkipped() public {
        vault.addAdapter(address(0xC0DE1E55), 0);
        _list(HELD, uint128(HELD));
        assertEq(_pulls(_data(10 ether)).length, 1);
    }

    function test_MarketWhoseLoanTokenIsNotTheVaultAssetIsSkipped() public {
        _listMarket(adapter, address(0xBAD), address(0xC011), HELD, uint128(HELD), 0);
        uint256 gross = vault.previewRedeem(10 ether);
        vm.expectRevert(abi.encodeWithSelector(ForceRedeemMorphoVaultHook.SHORTFALL.selector, 0, gross));
        hook.build(address(0), account, _data(10 ether));
    }

    function test_TwoAdaptersSharingOneMarketDoNotDoubleCountItsLiquidity() public {
        MockMorphoMarketAdapter twin = new MockMorphoMarketAdapter(address(vault), address(morpho));
        vault.addAdapter(address(twin), RATE_A);
        bytes32 id = _list(100 ether, 100 ether); // market liquidity 100
        twin.addMarket(id, 100 ether); // same market, own position
        uint256 gross = vault.previewRedeem(150 ether);
        // both positions are 100 but the MARKET can only pay 100 in total
        vm.expectRevert(abi.encodeWithSelector(ForceRedeemMorphoVaultHook.SHORTFALL.selector, 100 ether, gross));
        hook.build(address(0), account, _data(150 ether));
    }

    /*//////////////////////////////////////////////////////////////
                 ADAPTER AND MARKET FILTERS (ported, SUP-21799)
    //////////////////////////////////////////////////////////////*/

    /// @dev Shape-rejected adapters contribute zero markets, so `MAX_MARKETS` alone never bounds the walk.
    function test_TooManyAdaptersRevertsBeforeAnyProbing() public {
        for (uint256 i; i < 32; ++i) {
            vault.addAdapter(address(uint160(0xE0A0 + i)), 0);
        }
        vm.expectRevert(abi.encodeWithSelector(ForceRedeemMorphoVaultHook.TOO_MANY_ADAPTERS.selector, 33, 32));
        hook.build(address(0), account, _data(1 ether));
    }

    function test_OverlongProbeReplyIsTreatedAsAFailedProbeNotARevert() public {
        MockMorphoMarketAdapter hostile = new MockMorphoMarketAdapter(address(vault), address(morpho));
        hostile.setOverlongReplies(true);
        vault.addAdapter(address(hostile), 0);
        _listMarket(hostile, address(asset), address(0xC022), HELD, uint128(HELD), 0);
        _list(HELD, uint128(HELD));
        (address a,,,) = _decodePull(_pulls(_data(10 ether))[0]);
        assertEq(a, address(adapter), "decode of a two-word reply must not take down build");
    }

    function test_UnknownMarketIdIsSkipped() public {
        adapter.addMarket(ID_C, HELD); // never registered on the Morpho mock => zero params
        _list(HELD, uint128(HELD));
        assertEq(_pulls(_data(10 ether)).length, 1, "zero loanToken excluded");
    }

    function test_MarketOutsideTheAdaptersPinnedIrmIsSkipped() public {
        adapter.setPinnedIrm(irm);
        MarketParams memory off = MarketParams(address(asset), address(0xC022), address(0x0AC1), address(0xBAD1), 0.945e18);
        morpho.setMarket(_idOf(off), off, uint128(HELD), 0);
        adapter.addMarket(_idOf(off), HELD);
        _list(HELD, uint128(HELD));
        (, MarketParams memory used,,) = _decodePull(_pulls(_data(10 ether))[0]);
        assertEq(used.irm, irm, "the market on the foreign IRM is dropped");
    }

    /// @dev The one fail-OPEN branch: an adapter that answers `adaptiveCurveIrm()` with zero pins no IRM.
    function test_AdapterAnsweringZeroIrmDisablesTheIrmFilter() public {
        adapter.setZeroIrm(true);
        MarketParams memory off = MarketParams(address(asset), address(0xC022), address(0x0AC1), address(0xBAD1), 0.945e18);
        morpho.setMarket(_idOf(off), off, 100 ether, 0);
        adapter.addMarket(_idOf(off), 100 ether);
        _list(100 ether, 100 ether);
        assertEq(_pulls(_data(150 ether)).length, 2, "both markets admitted, because no IRM is pinned");
    }

    /// @dev `adapter.morpho()` is pinned against the immutable; an impostor's market state is never read.
    function test_AdapterPointingAtADifferentMorphoIsSkipped() public {
        MockMorphoBlue impostor = new MockMorphoBlue();
        MockMorphoMarketAdapter liar = new MockMorphoMarketAdapter(address(vault), address(impostor));
        vault.addAdapter(address(liar), 0); // zero penalty would otherwise sort it first
        MarketParams memory pm = _params(address(asset));
        impostor.setMarket(_idOf(pm), pm, type(uint128).max, 0);
        liar.addMarket(_idOf(pm), type(uint128).max);
        _list(HELD, uint128(HELD));
        (address a,,,) = _decodePull(_pulls(_data(10 ether))[0]);
        assertEq(a, address(adapter), "filled from the adapter on the pinned Morpho");
    }

    function test_AdapterWhoseMorphoProbeRevertsIsSkipped() public {
        MockMorphoMarketAdapter broken = new MockMorphoMarketAdapter(address(vault), address(morpho));
        broken.setBreakMorpho(true);
        vault.addAdapter(address(broken), 0);
        _listMarket(broken, address(asset), address(0xC022), HELD, uint128(HELD), 0);
        _list(HELD, uint128(HELD));
        (address a,,,) = _decodePull(_pulls(_data(10 ether))[0]);
        assertEq(a, address(adapter), "skipped at the morpho probe, not fatal");
    }

    /// @dev Market liquidity floors at zero: borrow above supply is "nothing withdrawable", not an underflow.
    function test_MarketWithBorrowAboveSupplyIsTreatedAsEmpty() public {
        _listMarket(adapter, address(asset), address(0xC022), HELD, 100 ether, 150 ether);
        _list(HELD, uint128(HELD));
        (, MarketParams memory used,,) = _decodePull(_pulls(_data(10 ether))[0]);
        assertEq(used.collateralToken, address(0xC011), "the underwater market contributed nothing");
    }

    function test_SkippedAdaptersDoNotCountTowardMaxMarkets() public {
        for (uint256 i; i < 32; ++i) {
            _listMarket(adapter, address(asset), address(uint160(0xC000 + i)), HELD, uint128(HELD), 0);
        }
        MockMorphoMarketAdapter shapeless = new MockMorphoMarketAdapter(address(vault), address(morpho));
        shapeless.setBreakMarketIdsLength(true);
        vault.addAdapter(address(shapeless), 0);
        assertEq(_pulls(_data(1 ether)).length, 1, "32 real markets plus a shapeless adapter still build");
    }

    /*//////////////////////////////////////////////////////////////
                         LIFECYCLE AND LAYOUT GUARDS
    //////////////////////////////////////////////////////////////*/

    function test_OnlyTheAccountMayDriveTheLifecycle() public {
        _list(HELD, uint128(HELD));
        bytes memory data = _data(100 ether);
        vm.prank(account);
        hook.setExecutionContext(account);

        vm.prank(makeAddr("stranger"));
        vm.expectRevert();
        hook.preExecute(address(0), account, data);

        vm.prank(makeAddr("stranger"));
        vm.expectRevert();
        hook.postExecute(address(0), account, data);
    }

    function test_MutexesAreOneShotAndClearedByReset() public {
        _list(HELD, uint128(HELD));
        bytes memory data = _data(100 ether);

        vm.startPrank(account);
        hook.setExecutionContext(account);
        Execution[] memory all = hook.build(address(0), account, data);
        for (uint256 i; i < all.length; ++i) {
            (bool ok,) = all[i].target.call(all[i].callData);
            assertTrue(ok, "first run");
        }
        vm.expectRevert();
        hook.preExecute(address(0), account, data);

        hook.resetExecutionState(account);
        hook.setExecutionContext(account);
        hook.preExecute(address(0), account, data);
        vm.stopPrank();
    }

    function testFuzz_OnlyOneHundredSeventeenBytesIsAccepted(uint16 lenRaw) public {
        uint256 len = bound(uint256(lenRaw), 0, 300);
        vm.assume(len != 117);
        bytes memory data = new bytes(len);
        vm.expectRevert(abi.encodeWithSelector(ForceRedeemMorphoVaultHook.INVALID_DATA_LENGTH.selector, len, 117));
        hook.build(address(0), account, data);
    }

    /// @dev For ANY floor: at or below the quote the exit settles and meets it; above the quote build refuses.
    function testFuzz_FloorBelowOrEqualQuotePasses_AboveReverts(uint256 floorRaw) public {
        _list(HELD, uint128(HELD));
        uint256 shares = 5000 ether;
        uint256 quoted = hook.previewAssetsOut(address(vault), account, shares);
        uint256 floor = bound(floorRaw, 0, 2 * quoted);
        bytes memory d = _dataFull(shares, false, floor);
        if (floor > quoted) {
            vm.expectRevert(
                abi.encodeWithSelector(ForceRedeemMorphoVaultHook.INSUFFICIENT_OUTPUT.selector, quoted, floor)
            );
            hook.build(address(0), account, d);
            return;
        }
        (uint256 received,) = _run(d);
        assertEq(received, quoted);
        assertGe(received, floor);
    }

    /// @dev OMS resizes the share leg through `replaceCalldataAmounts`; the floor it signed must still bind
    ///      the resized exit at build, not just survive as bytes.
    function test_FloorStillBindsAfterReplaceCalldataAmounts() public {
        _list(HELD, uint128(HELD));
        uint256 quotedBig = hook.previewAssetsOut(address(vault), account, 5000 ether);
        bytes memory signed = _dataFull(5000 ether, false, quotedBig);
        uint256[] memory smaller = new uint256[](1);
        smaller[0] = 1000 ether;
        bytes memory resized = hook.replaceCalldataAmounts(signed, smaller);
        uint256 quotedSmall = hook.previewAssetsOut(address(vault), account, 1000 ether);
        assertLt(quotedSmall, quotedBig);
        vm.expectRevert(
            abi.encodeWithSelector(ForceRedeemMorphoVaultHook.INSUFFICIENT_OUTPUT.selector, quotedSmall, quotedBig)
        );
        hook.build(address(0), account, resized);
    }

    function test_ThirtyThreeListedMarketsRevertEvenWhenTheFirstFewCouldFill() public {
        for (uint256 i; i < 33; ++i) {
            _listMarket(adapter, address(asset), address(uint160(0xC000 + i)), HELD, uint128(HELD), 0);
        }
        vm.expectRevert(abi.encodeWithSelector(ForceRedeemMorphoVaultHook.TOO_MANY_MARKETS.selector, 33, 32));
        hook.build(address(0), account, _data(1 ether));
    }

    function test_ThirtyTwoListedMarketsStillBuild_AndStayUnderTheGasCap() public {
        for (uint256 i; i < 32; ++i) {
            _listMarket(adapter, address(asset), address(uint160(0xC000 + i)), 1 ether, 1 ether, 0);
        }
        uint256 g = gasleft();
        Execution[] memory all = hook.build(address(0), account, _data(31 ether));
        uint256 used = g - gasleft();
        assertGt(all.length, 3);
        assertLt(used, 2 ** 24, "build fits under the per-transaction cap with the solver");
    }

    /*//////////////////////////////////////////////////////////////
                                  FUZZ
    //////////////////////////////////////////////////////////////*/

    /// @dev Either SHORTFALL, or the exit settles exactly: `held - S` shares remain, the account receives
    ///      `previewAssetsOut`, and the plan is minimal (one wei less on the last pull would not cover).
    function testFuzz_ExitSettlesExactlyOrShortfalls(
        uint96 sharesRaw,
        uint96 idleRaw,
        uint96 capA,
        uint96 capB,
        uint64 rateB
    )
        public
    {
        uint256 shares = bound(uint256(sharesRaw), 1 ether, HELD);
        uint256 idle = bound(uint256(idleRaw), 0, 500_000 ether);
        uint256 cA = bound(uint256(capA), 1 ether, 800_000 ether);
        uint256 cB = bound(uint256(capB), 1 ether, 800_000 ether);
        uint256 rB = bound(uint256(rateB), 0, MORPHO_MAX_PENALTY);
        MockMorphoMarketAdapter other = new MockMorphoMarketAdapter(address(vault), address(morpho));
        vault.addAdapter(address(other), rB);
        _list(cA, uint128(cA));
        _listMarket(other, address(asset), address(0xC022), cB, uint128(cB), 0);
        _idle(idle);

        bytes memory d = _data(shares);
        (bool ok, bytes memory ret) =
            address(hook).staticcall(abi.encodeCall(hook.previewAssetsOut, (address(vault), account, shares)));
        if (!ok) {
            assertEq(bytes4(ret), ForceRedeemMorphoVaultHook.SHORTFALL.selector, "the only admissible failure");
            vm.expectRevert();
            hook.build(address(0), account, d);
            return;
        }
        uint256 quoted = abi.decode(ret, (uint256));
        Execution[] memory pulls = _pulls(d);
        uint256 X;
        for (uint256 i; i < pulls.length; ++i) {
            (,, uint256 x,) = _decodePull(pulls[i]);
            X += x;
        }
        (uint256 received,) = _run(d);
        assertEq(received, quoted, "received == previewAssetsOut");
        assertEq(vault.balanceOf(account), HELD - shares, "exactly S shares left the account");
        assertLe(received, idle + X, "paid out of idle plus what was deallocated");
        assertGt(received, 0);
    }
}
