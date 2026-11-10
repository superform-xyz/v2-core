// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { ForceDeallocateMorphoVaultHook } from
    "../../../../src/hooks/vaults/metamorpho/ForceDeallocateMorphoVaultHook.sol";
import { IMorphoVaultV2 } from "../../../../src/vendor/morpho/IMorphoVaultV2.sol";
import { MarketParams } from "../../../../src/vendor/morpho/IMorpho.sol";
import { ISuperHookInflowOutflow } from "../../../../src/interfaces/ISuperHook.sol";
import { MockMorphoBlue, MockMorphoMarketAdapter, MockMorphoVaultV2 } from "../../../mocks/morpho/MorphoVaultV2Mocks.sol";

/// @notice Publishes a fixed outAmount/outToken so the `usePrevHookAmount` path can be driven
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

    function _buildHookExecutions(
        address,
        address,
        bytes calldata
    )
        internal
        pure
        override
        returns (Execution[] memory)
    {
        return new Execution[](0);
    }
}

contract ForceDeallocateMorphoVaultHookTest is Test {
    uint256 internal constant CAP = 0.0025e18;

    ForceDeallocateMorphoVaultHook internal hook;
    MockMorphoBlue internal morpho;
    MockMorphoVaultV2 internal vault;
    MockMorphoMarketAdapter internal adapter;

    address internal asset = address(0xA55E7);
    address internal irm = address(0x1247);
    address internal account = address(0xACC0);

    bytes32 internal constant ID_A = keccak256("A");
    bytes32 internal constant ID_B = keccak256("B");
    bytes32 internal constant ID_C = keccak256("C");
    bytes32 internal constant ORACLE_ID = bytes32(uint256(0xFEED));

    function setUp() public {
        morpho = new MockMorphoBlue();
        hook = new ForceDeallocateMorphoVaultHook(address(morpho), CAP);
        vault = new MockMorphoVaultV2(asset);
        adapter = new MockMorphoMarketAdapter(address(vault), address(morpho));
        vault.addAdapter(address(adapter), 1e13);
        vault.setShares(account, 1_000_000 ether);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _params(address loanToken) internal view returns (MarketParams memory p) {
        p = MarketParams(loanToken, address(0xC011), address(0x0AC1), irm, 0.945e18);
    }

    /// @dev position = what the adapter holds; supply/borrow set the market's liquidity
    function _listMarket(bytes32 id, uint256 position, uint128 supply, uint128 borrow) internal {
        morpho.setMarket(id, _params(asset), supply, borrow);
        adapter.addMarket(id, position);
    }

    function _data(uint256 assets, bool usePrev) internal view returns (bytes memory) {
        return abi.encodePacked(ORACLE_ID, address(vault), assets, usePrev);
    }

    /// @dev `build` wraps the pulls between preExecute and postExecute, so the real calls are the middle
    function _pulls(bytes memory data, address prevHook) internal view returns (Execution[] memory mid) {
        Execution[] memory all = hook.build(prevHook, account, data);
        mid = new Execution[](all.length - 2);
        for (uint256 i; i < mid.length; ++i) {
            mid[i] = all[i + 1];
        }
    }

    function _decodeCall(Execution memory e)
        internal
        pure
        returns (address adapter_, MarketParams memory p, uint256 assets, address onBehalf)
    {
        bytes memory raw = e.callData;
        bytes memory args = new bytes(raw.length - 4);
        for (uint256 i; i < args.length; ++i) {
            args[i] = raw[i + 4];
        }
        bytes memory inner;
        (adapter_, inner, assets, onBehalf) = abi.decode(args, (address, bytes, uint256, address));
        p = abi.decode(inner, (MarketParams));
    }

    /// @dev Morpho charges `assets.mulDivUp(penalty, WAD)`; mirrored here so the bound is derived, not
    ///      copied from the implementation.
    function _ceilPenalty(uint256 assets, uint256 penaltyWad) internal pure returns (uint256) {
        return (assets * penaltyWad + 1e18 - 1) / 1e18;
    }

    /*//////////////////////////////////////////////////////////////
                           LAYOUT AND SIZING
    //////////////////////////////////////////////////////////////*/

    function test_DataLengthIsExactlyEightyFive() public view {
        assertEq(_data(1 ether, false).length, 85);
    }

    function test_RejectsAnyLengthOtherThanEightyFive() public {
        _listMarket(ID_A, 100 ether, 200 ether, 0);
        bytes memory good = _data(1 ether, false);

        vm.expectRevert(abi.encodeWithSelector(ForceDeallocateMorphoVaultHook.INVALID_DATA_LENGTH.selector, 86, 85));
        hook.build(address(0), account, abi.encodePacked(good, hex"00"));

        vm.expectRevert(abi.encodeWithSelector(ForceDeallocateMorphoVaultHook.INVALID_DATA_LENGTH.selector, 84, 85));
        hook.build(address(0), account, abi.encodePacked(ORACLE_ID, address(vault), uint256(1 ether)));
    }

    function test_ResolvedZeroAmountReverts() public {
        _listMarket(ID_A, 100 ether, 200 ether, 0);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), account, _data(0, false));
    }

    function test_SizingSurfaceIsOneInTokenLegAtOffsetFiftyTwo() public view {
        uint256[] memory amounts = hook.decodeAmounts(_data(7 ether, false));
        assertEq(amounts.length, 1);
        assertEq(amounts[0], 7 ether);

        ISuperHookInflowOutflow.AmountMeta[] memory meta = hook.amountRoles("");
        assertEq(meta.length, 1);
        assertEq(uint8(meta[0].dir), uint8(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint8(meta[0].denom), uint8(ISuperHookInflowOutflow.Denomination.TOKEN));
    }

    function test_ReplaceCalldataAmountsWritesOffsetFiftyTwoAndPreservesTheFlag() public view {
        bytes memory original = _data(1 ether, true);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 99 ether;

        bytes memory rewritten = hook.replaceCalldataAmounts(original, amounts);

        assertEq(rewritten.length, original.length, "length preserved");
        assertEq(hook.decodeAmounts(rewritten)[0], 99 ether, "amount rewritten");
        assertTrue(hook.decodeUsePrevHookAmount(rewritten), "flag at 84 untouched");
        for (uint256 i; i < 52; ++i) {
            assertEq(rewritten[i], original[i], "header untouched");
        }
    }

    function test_InspectIsTheVaultAloneAndNothingElse() public view {
        bytes memory got = hook.inspect(_data(1 ether, false));
        assertEq(got.length, 20);
        assertEq(got, abi.encodePacked(address(vault)));
    }

    /*//////////////////////////////////////////////////////////////
                                 FILL
    //////////////////////////////////////////////////////////////*/

    function test_OneMarketCoversTheRequest_SecondFundedMarketIsAbsent() public {
        _listMarket(ID_A, 500 ether, 500 ether, 0);
        _listMarket(ID_B, 500 ether, 500 ether, 0);

        Execution[] memory pulls = _pulls(_data(100 ether, false), address(0));
        assertEq(pulls.length, 1, "exactly one call");

        (address a, MarketParams memory p, uint256 assets, address onBehalf) = _decodeCall(pulls[0]);
        assertEq(pulls[0].target, address(vault));
        assertEq(pulls[0].value, 0);
        assertEq(a, address(adapter));
        assertEq(assets, 100 ether, "pulls exactly the request, not the whole market");
        assertEq(onBehalf, account, "onBehalf is the executing account");
        assertEq(p.loanToken, asset);
        assertEq(p.irm, irm);
    }

    function test_SpansMarketsAndAmountsSumToExactlyAssets() public {
        // Equal penalties, so the sort is purely capacity-descending: B (300) then A (200) then C (100).
        _listMarket(ID_A, 200 ether, 200 ether, 0);
        _listMarket(ID_B, 300 ether, 300 ether, 0);
        _listMarket(ID_C, 100 ether, 100 ether, 0);

        Execution[] memory pulls = _pulls(_data(450 ether, false), address(0));
        assertEq(pulls.length, 2, "two calls");

        (,, uint256 a0,) = _decodeCall(pulls[0]);
        (,, uint256 a1,) = _decodeCall(pulls[1]);
        assertEq(a0, 300 ether, "largest capacity first");
        assertEq(a1, 150 ether, "remainder only");
        assertEq(a0 + a1, 450 ether, "sums to exactly assets");
    }

    function test_CapacityIsMinOfPositionAndMarketLiquidity() public {
        // Adapter holds 500 but the market can only pay 120 (supply 200 - borrow 80).
        _listMarket(ID_A, 500 ether, 200 ether, 80 ether);

        Execution[] memory pulls = _pulls(_data(120 ether, false), address(0));
        (,, uint256 amount,) = _decodeCall(pulls[0]);
        assertEq(amount, 120 ether, "bounded by liquidity, not position");

        vm.expectRevert(
            abi.encodeWithSelector(ForceDeallocateMorphoVaultHook.SHORTFALL.selector, 120 ether, 121 ether)
        );
        hook.build(address(0), account, _data(121 ether, false));
    }

    function test_ZeroLiquidityMarketIsSkippedAndFillCompletesFromALaterMarket() public {
        _listMarket(ID_A, 400 ether, 100 ether, 100 ether); // supply == borrow, nothing withdrawable
        _listMarket(ID_B, 400 ether, 400 ether, 0);

        Execution[] memory pulls = _pulls(_data(400 ether, false), address(0));
        assertEq(pulls.length, 1);
        (,, uint256 amount,) = _decodeCall(pulls[0]);
        assertEq(amount, 400 ether, "filled entirely from the funded market");
    }

    function test_AdapterOverThePenaltyCapIsSkippedNotFatal() public {
        _listMarket(ID_A, 400 ether, 400 ether, 0);

        MockMorphoMarketAdapter dear = new MockMorphoMarketAdapter(address(vault), address(morpho));
        vault.addAdapter(address(dear), CAP + 1);
        morpho.setMarket(ID_B, _params(asset), 1000 ether, 0);
        dear.addMarket(ID_B, 1000 ether);

        Execution[] memory pulls = _pulls(_data(400 ether, false), address(0));
        assertEq(pulls.length, 1, "the expensive adapter contributed nothing");
        (address a,,,) = _decodeCall(pulls[0]);
        assertEq(a, address(adapter), "filled from the cheap adapter");
    }

    function test_CheaperPenaltyIsFilledFirstEvenWhenSmaller() public {
        // Default adapter is at 1e13 with only 50; a pricier adapter has 1000 available.
        _listMarket(ID_A, 50 ether, 50 ether, 0);

        MockMorphoMarketAdapter pricier = new MockMorphoMarketAdapter(address(vault), address(morpho));
        vault.addAdapter(address(pricier), 2e13);
        morpho.setMarket(ID_B, _params(asset), 1000 ether, 0);
        pricier.addMarket(ID_B, 1000 ether);

        Execution[] memory pulls = _pulls(_data(60 ether, false), address(0));
        assertEq(pulls.length, 2);
        (address first,, uint256 a0,) = _decodeCall(pulls[0]);
        (address second,, uint256 a1,) = _decodeCall(pulls[1]);
        assertEq(first, address(adapter), "cheapest penalty first");
        assertEq(a0, 50 ether);
        assertEq(second, address(pricier));
        assertEq(a1, 10 ether, "only the remainder from the pricier adapter");
    }

    function test_ShortfallRevertsAndBuildsNothing() public {
        _listMarket(ID_A, 10 ether, 10 ether, 0);
        vm.expectRevert(abi.encodeWithSelector(ForceDeallocateMorphoVaultHook.SHORTFALL.selector, 10 ether, 99 ether));
        hook.build(address(0), account, _data(99 ether, false));
    }

    function test_ShortfallBlamesTheCapWhenTheCapIsTheCause() public {
        MockMorphoMarketAdapter dear = new MockMorphoMarketAdapter(address(vault), address(morpho));
        vault.addAdapter(address(dear), CAP + 5);
        morpho.setMarket(ID_B, _params(asset), 1000 ether, 0);
        dear.addMarket(ID_B, 1000 ether);

        vm.expectRevert(
            abi.encodeWithSelector(ForceDeallocateMorphoVaultHook.PENALTY_ABOVE_CAP.selector, CAP + 5, CAP)
        );
        hook.build(address(0), account, _data(100 ether, false));
    }

    /*//////////////////////////////////////////////////////////////
                      SHARED LIQUIDITY ACROSS ADAPTERS
    //////////////////////////////////////////////////////////////*/

    /// @dev The bug SUP-21799's text does not mention. `min(position, liquidity)` is per (adapter, market)
    ///      but liquidity belongs to the MARKET, so two adapters holding the same id must not each be sized
    ///      against the full amount. Without the per-id ledger this builds two pulls of 100 against a market
    ///      that can only pay 100, and the second `forceDeallocate` reverts on chain.
    function test_TwoAdaptersSharingOneMarketDoNotDoubleCountItsLiquidity() public {
        morpho.setMarket(ID_A, _params(asset), 100 ether, 0);
        adapter.addMarket(ID_A, 100 ether);

        MockMorphoMarketAdapter twin = new MockMorphoMarketAdapter(address(vault), address(morpho));
        vault.addAdapter(address(twin), 1e13);
        twin.addMarket(ID_A, 100 ether);

        // Both adapters report a 100 position in a market with 100 of liquidity: the true capacity is 100.
        vm.expectRevert(
            abi.encodeWithSelector(ForceDeallocateMorphoVaultHook.SHORTFALL.selector, 100 ether, 150 ether)
        );
        hook.build(address(0), account, _data(150 ether, false));

        Execution[] memory pulls = _pulls(_data(100 ether, false), address(0));
        uint256 total;
        for (uint256 i; i < pulls.length; ++i) {
            (,, uint256 amount,) = _decodeCall(pulls[i]);
            total += amount;
        }
        assertEq(total, 100 ether, "never plans more than the market can pay");
    }

    function test_OneAdapterListingTheSameIdTwiceDoesNotDoubleCount() public {
        morpho.setMarket(ID_A, _params(asset), 100 ether, 0);
        adapter.addMarket(ID_A, 100 ether);
        adapter.addMarket(ID_A, 100 ether);

        vm.expectRevert(
            abi.encodeWithSelector(ForceDeallocateMorphoVaultHook.SHORTFALL.selector, 100 ether, 101 ether)
        );
        hook.build(address(0), account, _data(101 ether, false));
    }

    /// @dev THE POSITION BOUND MUST BE NETTED PER (ADAPTER, MARKET), NOT JUST PER MARKET. With ample market
    ///      liquidity, a per-market-id liquidity ledger alone does nothing to stop the SAME adapter's single
    ///      position being counted once per duplicate listing. `expectedSupplyAssets` returns one number for
    ///      one adapter-market pair, so two candidates describing that pair describe the SAME capacity.
    ///      Deliberately uses position << liquidity: with position == liquidity the liquidity ledger masks
    ///      this entirely, which is how the first version of this test passed while the bug was live.
    function test_DuplicateListingDoesNotDoubleCountTheAdaptersPosition() public {
        morpho.setMarket(ID_A, _params(asset), 1000 ether, 0); // liquidity far above the position
        adapter.addMarket(ID_A, 60 ether);
        adapter.addMarket(ID_A, 60 ether);

        // The adapter holds 60, listed twice. True capacity is 60, not 120.
        vm.expectRevert(abi.encodeWithSelector(ForceDeallocateMorphoVaultHook.SHORTFALL.selector, 60 ether, 120 ether));
        hook.build(address(0), account, _data(120 ether, false));

        Execution[] memory pulls = _pulls(_data(60 ether, false), address(0));
        uint256 total;
        for (uint256 i; i < pulls.length; ++i) {
            (,, uint256 amount,) = _decodeCall(pulls[i]);
            total += amount;
        }
        assertEq(total, 60 ether, "never plans more than the adapter actually holds");
    }

    /*//////////////////////////////////////////////////////////////
                           ADAPTER FILTERING
    //////////////////////////////////////////////////////////////*/

    function test_AdapterWithoutMarketIdsLengthIsSkippedNotFatal() public {
        _listMarket(ID_A, 400 ether, 400 ether, 0);

        MockMorphoMarketAdapter vaultShaped = new MockMorphoMarketAdapter(address(vault), address(morpho));
        vaultShaped.setBreakMarketIdsLength(true);
        vault.addAdapter(address(vaultShaped), 1e13);

        Execution[] memory pulls = _pulls(_data(400 ether, false), address(0));
        assertEq(pulls.length, 1, "the shapeless adapter was skipped, build still succeeded");
    }

    function test_AdapterOfADifferentVaultIsSkipped() public {
        _listMarket(ID_A, 400 ether, 400 ether, 0);

        MockMorphoMarketAdapter foreign = new MockMorphoMarketAdapter(address(0xDEAD), address(morpho));
        vault.addAdapter(address(foreign), 1e13);
        morpho.setMarket(ID_B, _params(asset), 1000 ether, 0);
        foreign.addMarket(ID_B, 1000 ether);

        Execution[] memory pulls = _pulls(_data(400 ether, false), address(0));
        assertEq(pulls.length, 1, "parentVault mismatch excluded it");
    }

    function test_CodelessAdapterIsSkipped() public {
        _listMarket(ID_A, 400 ether, 400 ether, 0);
        vault.addAdapter(address(0xE0A), 1e13);

        Execution[] memory pulls = _pulls(_data(400 ether, false), address(0));
        assertEq(pulls.length, 1, "a staticcall to an EOA succeeds with no data; it must not pass the probe");
    }

    function test_OverlongProbeReplyIsTreatedAsAFailedProbeNotARevert() public {
        _listMarket(ID_A, 400 ether, 400 ether, 0);

        MockMorphoMarketAdapter hostile = new MockMorphoMarketAdapter(address(vault), address(morpho));
        hostile.addMarket(ID_B, 1000 ether);
        hostile.setOverlongReplies(true);
        vault.addAdapter(address(hostile), 1e13);
        morpho.setMarket(ID_B, _params(asset), 1000 ether, 0);

        Execution[] memory pulls = _pulls(_data(400 ether, false), address(0));
        assertEq(pulls.length, 1, "decode of a two-word reply must not take down build");
    }

    function test_MarketWhoseLoanTokenIsNotTheVaultAssetIsSkipped() public {
        _listMarket(ID_A, 400 ether, 400 ether, 0);
        morpho.setMarket(ID_B, _params(address(0xB44D)), 1000 ether, 0);
        adapter.addMarket(ID_B, 1000 ether);

        Execution[] memory pulls = _pulls(_data(400 ether, false), address(0));
        assertEq(pulls.length, 1, "wrong loan token excluded");
    }

    function test_UnknownMarketIdIsSkipped() public {
        _listMarket(ID_A, 400 ether, 400 ether, 0);
        adapter.addMarket(ID_C, 1000 ether); // never registered on the Morpho mock => zero params

        Execution[] memory pulls = _pulls(_data(400 ether, false), address(0));
        assertEq(pulls.length, 1, "zero loanToken excluded");
    }

    function test_MarketOutsideTheAdaptersPinnedIrmIsSkipped() public {
        _listMarket(ID_A, 400 ether, 400 ether, 0);
        adapter.setPinnedIrm(irm);

        morpho.setMarket(
            ID_B, MarketParams(asset, address(0xC011), address(0x0AC1), address(0xBAD1), 0.945e18), 1000 ether, 0
        );
        adapter.addMarket(ID_B, 1000 ether);

        Execution[] memory pulls = _pulls(_data(400 ether, false), address(0));
        assertEq(pulls.length, 1, "IRM mismatch would revert IrmMismatch on chain, so it is dropped here");
    }

    /// @dev `adapter.morpho()` is answered by a curator-registered contract, so it is pinned against the
    ///      immutable rather than merely checked for code. An adapter pointing at a different Morpho — or at
    ///      a contract impersonating one — is SKIPPED, and crucially its market state is never read, so it
    ///      cannot revert `build` from inside a typed call or claim capacity it does not have.
    function test_AdapterPointingAtADifferentMorphoIsSkipped() public {
        _listMarket(ID_A, 400 ether, 400 ether, 0);

        MockMorphoBlue impostor = new MockMorphoBlue();
        impostor.setMarket(ID_B, _params(asset), type(uint128).max, 0);
        MockMorphoMarketAdapter liar = new MockMorphoMarketAdapter(address(vault), address(impostor));
        liar.addMarket(ID_B, type(uint128).max);
        vault.addAdapter(address(liar), 0); // zero penalty would otherwise sort it first

        Execution[] memory pulls = _pulls(_data(400 ether, false), address(0));
        assertEq(pulls.length, 1, "the impostor contributed nothing");
        (address a,,,) = _decodeCall(pulls[0]);
        assertEq(a, address(adapter), "filled from the adapter on the pinned Morpho");
    }

    /// @dev The adapter list is its own gas-exhaustion surface: shape-rejected adapters contribute zero
    ///      markets, so `MAX_MARKETS` alone never bounds the walk. `build` runs on chain, so this matters.
    function test_TooManyAdaptersRevertsBeforeAnyProbing() public {
        for (uint256 i; i < 33; ++i) {
            vault.addAdapter(address(uint160(0xE0A0 + i)), 0);
        }
        vm.expectRevert(abi.encodeWithSelector(ForceDeallocateMorphoVaultHook.TOO_MANY_ADAPTERS.selector, 34, 32));
        hook.build(address(0), account, _data(1 ether, false));
    }

    /// @dev The solvency bound converts ASSETS TO SHARES, and at a 1:1 preview rate that conversion is
    ///      invisible: comparing `balanceOf` against the raw penalty assets would pass every other test in
    ///      this file. A non-unit rate is what makes `previewWithdraw` load-bearing.
    function test_SolvencyBoundConvertsAssetsToSharesAtTheVaultsRate() public {
        _listMarket(ID_A, 1000 ether, 1000 ether, 0);
        vault.setPreviewRate(2e18); // one asset costs two shares

        uint256 penalty = _ceilPenalty(1000 ether, 1e13);
        uint256 required = 2 * (1000 ether + penalty); // single leg, so no n-1 slack

        vault.setShares(account, required - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ForceDeallocateMorphoVaultHook.INSUFFICIENT_SHARES.selector, required - 1, required
            )
        );
        hook.build(address(0), account, _data(1000 ether, false));

        vault.setShares(account, required);
        assertEq(_pulls(_data(1000 ether, false), address(0)).length, 1, "exactly the share-denominated bound");
    }

    /// @dev THE SORT MUST BE STABLE, and only a full tie can show it. Every other ordering test ties on at
    ///      most one key, so `>` becoming `>=` in `_cheaperFirst` — which makes insertion sort unstable —
    ///      would change nothing observable. With equal penalty AND equal capacity the spec's final
    ///      tie-break (adapter index, then market index, ascending) is the only thing left to assert, and
    ///      it is satisfied by discovery order rather than by a third comparison.
    function test_EqualPenaltyAndCapacityFillsInAdapterThenMarketOrder() public {
        _listMarket(ID_A, 100 ether, 100 ether, 0);

        MockMorphoMarketAdapter second = new MockMorphoMarketAdapter(address(vault), address(morpho));
        vault.addAdapter(address(second), 1e13); // identical penalty
        morpho.setMarket(ID_B, _params(asset), 100 ether, 0);
        second.addMarket(ID_B, 100 ether); // identical capacity

        Execution[] memory pulls = _pulls(_data(40 ether, false), address(0));
        assertEq(pulls.length, 1, "one market covers it");
        (address a,,,) = _decodeCall(pulls[0]);
        assertEq(a, address(adapter), "the lower adapter index wins an exact tie");
    }

    /// @dev The dedup must key on (adapter, market), NOT on market alone. Two DIFFERENT adapters holding
    ///      positions in the same market are two real positions and must both be usable when the market has
    ///      the liquidity to pay both. Keying on the id alone would silently drop one and halve capacity.
    function test_TwoAdaptersInOneMarketAreBothPulledWhenLiquidityAllows() public {
        morpho.setMarket(ID_A, _params(asset), 200 ether, 0); // enough for both positions
        adapter.addMarket(ID_A, 100 ether);

        MockMorphoMarketAdapter twin = new MockMorphoMarketAdapter(address(vault), address(morpho));
        vault.addAdapter(address(twin), 1e13);
        twin.addMarket(ID_A, 100 ether);

        Execution[] memory pulls = _pulls(_data(200 ether, false), address(0));
        assertEq(pulls.length, 2, "both adapters' positions are real and both are used");

        uint256 total;
        for (uint256 i; i < pulls.length; ++i) {
            (,, uint256 amount,) = _decodeCall(pulls[i]);
            total += amount;
        }
        assertEq(total, 200 ether, "the full shared-market liquidity is reachable across two adapters");
    }

    /*//////////////////////////////////////////////////////////////
                              MAX MARKETS
    //////////////////////////////////////////////////////////////*/

    function test_ThirtyThreeListedMarketsRevertEvenWhenTheFirstFewCouldFill() public {
        for (uint256 i; i < 33; ++i) {
            bytes32 id = keccak256(abi.encode("m", i));
            morpho.setMarket(id, _params(asset), 1000 ether, 0);
            adapter.addMarket(id, 1000 ether);
        }

        vm.expectRevert(abi.encodeWithSelector(ForceDeallocateMorphoVaultHook.TOO_MANY_MARKETS.selector, 33, 32));
        hook.build(address(0), account, _data(1 ether, false));
    }

    function test_ThirtyTwoListedMarketsStillBuild() public {
        for (uint256 i; i < 32; ++i) {
            bytes32 id = keccak256(abi.encode("m", i));
            morpho.setMarket(id, _params(asset), 1000 ether, 0);
            adapter.addMarket(id, 1000 ether);
        }

        Execution[] memory pulls = _pulls(_data(1 ether, false), address(0));
        assertEq(pulls.length, 1);
    }

    /// @dev An adapter rejected at the adapter level contributes zero to the count, because its market
    ///      list is never read. Without that rule a single shapeless adapter could push a healthy vault
    ///      over the bound.
    function test_SkippedAdaptersDoNotCountTowardMaxMarkets() public {
        for (uint256 i; i < 32; ++i) {
            bytes32 id = keccak256(abi.encode("m", i));
            morpho.setMarket(id, _params(asset), 1000 ether, 0);
            adapter.addMarket(id, 1000 ether);
        }
        MockMorphoMarketAdapter shapeless = new MockMorphoMarketAdapter(address(vault), address(morpho));
        shapeless.setBreakMarketIdsLength(true);
        vault.addAdapter(address(shapeless), 1e13);

        Execution[] memory pulls = _pulls(_data(1 ether, false), address(0));
        assertEq(pulls.length, 1);
    }

    /*//////////////////////////////////////////////////////////////
                            PENALTY SOLVENCY
    //////////////////////////////////////////////////////////////*/

    function test_InsufficientSharesRevertsBeforeAnyCallIsBuilt() public {
        _listMarket(ID_A, 1000 ether, 1000 ether, 0);
        vault.setShares(account, 1);

        // One leg, so no `n - 1` slack. The bound covers the WHOLE exit: the assets being freed plus the
        // penalty those pulls burn, because the follow-on withdraw of `assets` costs shares too.
        uint256 required = 1000 ether + _ceilPenalty(1000 ether, 1e13);
        vm.expectRevert(
            abi.encodeWithSelector(ForceDeallocateMorphoVaultHook.INSUFFICIENT_SHARES.selector, 1, required)
        );
        hook.build(address(0), account, _data(1000 ether, false));
    }

    function test_SolvencyBoundAddsOneShareOfSlackPerCallAfterTheFirst() public {
        // Two legs, both penalised: required == previewWithdraw(total) + (2 - 1).
        _listMarket(ID_A, 100 ether, 100 ether, 0);
        _listMarket(ID_B, 100 ether, 100 ether, 0);

        uint256 totalPenalty = _ceilPenalty(100 ether, 1e13) + _ceilPenalty(50 ether, 1e13);
        uint256 required = IMorphoVaultV2(address(vault)).previewWithdraw(150 ether + totalPenalty) + 1;

        vault.setShares(account, required - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ForceDeallocateMorphoVaultHook.INSUFFICIENT_SHARES.selector, required - 1, required
            )
        );
        hook.build(address(0), account, _data(150 ether, false));

        vault.setShares(account, required);
        assertEq(_pulls(_data(150 ether, false), address(0)).length, 2, "exactly the bound is enough");
    }

    function test_ZeroPenaltyAdapterNeedsNoShares() public {
        MockMorphoVaultV2 free = new MockMorphoVaultV2(asset);
        MockMorphoMarketAdapter freeAdapter = new MockMorphoMarketAdapter(address(free), address(morpho));
        free.addAdapter(address(freeAdapter), 0);
        free.setShares(account, 0);
        morpho.setMarket(ID_A, _params(asset), 500 ether, 0);
        freeAdapter.addMarket(ID_A, 500 ether);

        bytes memory data = abi.encodePacked(ORACLE_ID, address(free), uint256(100 ether), false);
        Execution[] memory all = hook.build(address(0), account, data);
        assertEq(all.length, 3, "one pull, with no share requirement at all");
    }

    /*//////////////////////////////////////////////////////////////
                         USE-PREV-HOOK-AMOUNT
    //////////////////////////////////////////////////////////////*/

    /// @dev Ticket bullet: "`usePrevHookAmount` on this hook reads the previous hop's `outAmount` and pulls
    ///      that." The calldata amount is set to a decoy that must be IGNORED, so a hook that read offset 52
    ///      instead of the previous hook fails rather than coincidentally passing.
    function test_UsePrevHookAmount_PullsThePreviousHopsOutAmount() public {
        _listMarket(ID_A, 500 ether, 500 ether, 0);

        PrevHookStub prev = new PrevHookStub();
        prev.setExecutionContext(account);
        prev.publish(123 ether, asset, account);

        // Offset 52 carries a decoy the hook must not use.
        bytes memory data = abi.encodePacked(ORACLE_ID, address(vault), uint256(1 wei), true);
        Execution[] memory all = hook.build(address(prev), account, data);
        assertEq(all.length, 3, "one pull");

        (,, uint256 amount,) = _decodeCall(all[1]);
        assertEq(amount, 123 ether, "pulled the previous hop's outAmount, not the calldata decoy");
    }

    /// @dev `usePrevHookAmount` with no previous hook is a configuration error, not a silent zero.
    function test_UsePrevHookAmount_WithoutAPreviousHookReverts() public {
        _listMarket(ID_A, 500 ether, 500 ether, 0);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), account, _data(1 ether, true));
    }

    /// @dev A previous hop that published zero resolves to zero and must revert rather than build nothing.
    function test_UsePrevHookAmount_ZeroFromThePreviousHopReverts() public {
        _listMarket(ID_A, 500 ether, 500 ether, 0);

        PrevHookStub prev = new PrevHookStub();
        prev.setExecutionContext(account);
        prev.publish(0, asset, account);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(prev), account, _data(1 ether, true));
    }

    /// @dev Ticket bullet: "A successor with `usePrevHookAmount` true reverts." THIS IS THE ENFORCEMENT OF
    ///      `outAmount = 0`, not a documentation claim. The hook publishes zero precisely so that anything
    ///      trying to size a real movement from this hop's "receipt" fails closed — the account received
    ///      nothing. A second instance of this same hook stands in for any such successor.
    function test_SuccessorChainingOffThisHookFailsClosed() public {
        _listMarket(ID_A, 500 ether, 500 ether, 0);

        // Run the hook so `_preExecute` publishes its output.
        vm.startPrank(account);
        hook.setExecutionContext(account);
        Execution[] memory all = hook.build(address(0), account, _data(100 ether, false));
        (bool okPre,) = all[0].target.call(all[0].callData);
        assertTrue(okPre, "preExecute");
        vm.stopPrank();

        assertEq(hook.getOutAmount(account), 0, "nothing chainable was published");
        assertEq(hook.getOutToken(account), asset, "outToken is still the underlying");

        // Any successor resolving its amount from this hop now resolves zero and refuses to build.
        ForceDeallocateMorphoVaultHook successor = new ForceDeallocateMorphoVaultHook(address(morpho), CAP);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        successor.build(address(hook), account, _data(1 ether, true));
    }

    /// @dev THE BOUND THAT MAKES THE PENALTY CAP MEAN SOMETHING (review finding F1 on PR #1046).
    ///      `inspect` pins the vault alone and `assets` is a resizable sized leg, so whoever builds the
    ///      calldata chooses how much to force out. Bounding only the penalty meant a leaf authorised
    ///      "burn up to MAX_PENALTY_WAD of the vault's ENTIRE reachable liquidity" rather than "of this
    ///      account's exit": the cap bounded the rate while the base was unbounded.
    ///      Limit case, at the deployed 25 bps cap: a 100-unit claim against a vault with 40,000 units
    ///      reachable. 40_000 * 0.0025 == 100, so one call burned the account's ENTIRE position, with the
    ///      value accruing to the vault's other holders — and the old pre-flight passed EXACTLY at full
    ///      loss, because it only ever asked whether the penalty itself was payable.
    function test_OversizedRequestCannotBurnTheWholeClaim() public {
        // Penalty at the cap, and far more reachable liquidity than the account could ever claim.
        MockMorphoVaultV2 big = new MockMorphoVaultV2(asset);
        MockMorphoMarketAdapter rich = new MockMorphoMarketAdapter(address(big), address(morpho));
        big.addAdapter(address(rich), CAP);
        morpho.setMarket(ID_A, _params(asset), 100_000 ether, 0);
        rich.addMarket(ID_A, 100_000 ether);

        uint256 claim = 100 ether;
        big.setShares(account, claim);

        uint256 oversized = 40_000 ether;
        assertEq(_ceilPenalty(oversized, CAP), claim, "fixture: the penalty alone equals the whole claim");

        bytes memory data = abi.encodePacked(ORACLE_ID, address(big), oversized, false);
        vm.expectRevert(
            abi.encodeWithSelector(
                ForceDeallocateMorphoVaultHook.INSUFFICIENT_SHARES.selector, claim, oversized + claim
            )
        );
        hook.build(address(0), account, data);
    }

    /// @dev The same vault still serves a legitimately-sized exit, so the bound is not merely restrictive.
    ///      An account claiming `claim` can free anything whose assets-plus-penalty fit inside that claim.
    function test_ProportionateRequestStillBuilds() public {
        MockMorphoVaultV2 big = new MockMorphoVaultV2(asset);
        MockMorphoMarketAdapter rich = new MockMorphoMarketAdapter(address(big), address(morpho));
        big.addAdapter(address(rich), CAP);
        morpho.setMarket(ID_A, _params(asset), 100_000 ether, 0);
        rich.addMarket(ID_A, 100_000 ether);

        uint256 claim = 100 ether;
        big.setShares(account, claim);

        // Morpho's own full-exit size: claim / (1 + penalty), which is what SUP-21689 will size against.
        uint256 sized = (claim * 1e18) / (1e18 + CAP);
        bytes memory data = abi.encodePacked(ORACLE_ID, address(big), sized, false);

        Execution[] memory all = hook.build(address(0), account, data);
        assertEq(all.length, 3, "a correctly sized exit is unaffected by the bound");
        (,, uint256 amount,) = _decodeCall(all[1]);
        assertEq(amount, sized, "and it frees exactly what was asked");
    }

    /// @dev THE PER-PROBE STIPEND DOES NOT BOUND THE TRANSACTION; the SUM does (review finding F2 on PR
    ///      #1046). The worst case is `MAX_ADAPTERS * 4 + MAX_MARKETS * 2 == 192` probes, each able to
    ///      consume its full stipend from an adapter that answers correctly but expensively. `build` runs
    ///      ON CHAIN inside the UserOp, so that total has to fit under the 16,777,216 (2^24)
    ///      per-transaction gas cap EIP-7825 introduced on Ethereum in Fusaka. At the original 100_000
    ///      stipend it did not, which would have put the exit beyond any transaction — on the one path
    ///      that exists to escape an illiquid vault.
    function test_AllHostileAdaptersStayUnderTheTransactionGasCap() public {
        // setUp already registered one adapter, so fill to EXACTLY the ceiling — one more would revert
        // TOO_MANY_ADAPTERS before any probing and measure nothing.
        uint256 n = hook.MAX_ADAPTERS() - 1;
        for (uint256 i; i < n; ++i) {
            MockMorphoMarketAdapter greedy = new MockMorphoMarketAdapter(address(vault), address(morpho));
            bytes32 id = keccak256(abi.encode("greedy", i));
            morpho.setMarket(id, _params(asset), 1000 ether, 0);
            greedy.addMarket(id, 1000 ether);
            greedy.setBurnGas(true);
            vault.addAdapter(address(greedy), 1e13);
        }
        _listMarket(ID_A, 1000 ether, 1000 ether, 0); // give setUp's adapter a market too
        vault.setShares(account, type(uint128).max);

        uint256 before = gasleft();
        Execution[] memory all = hook.build(address(0), account, _data(1 ether, false));
        uint256 used = before - gasleft();

        assertEq(all.length, 3, "it must actually complete a build, not revert early");
        emit log_named_uint("worst-case build gas", used);
        assertLt(used, 2 ** 24, "build must fit under the EIP-7825 per-transaction gas cap");
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_ConstructorRejectsZeroAndAboveMorphosOwnCeiling() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ForceDeallocateMorphoVaultHook(address(0), CAP);

        vm.expectRevert(ForceDeallocateMorphoVaultHook.INVALID_PENALTY_CAP.selector);
        new ForceDeallocateMorphoVaultHook(address(morpho), 0);

        vm.expectRevert(ForceDeallocateMorphoVaultHook.INVALID_PENALTY_CAP.selector);
        new ForceDeallocateMorphoVaultHook(address(morpho), 0.02e18 + 1);

        assertEq(new ForceDeallocateMorphoVaultHook(address(morpho), 0.02e18).MAX_PENALTY_WAD(), 0.02e18, "the ceiling itself is ok");
        assertEq(hook.MAX_PENALTY_WAD(), CAP);
        assertEq(hook.MORPHO_MAX_PENALTY_WAD(), 0.02e18);
        assertEq(hook.MAX_MARKETS(), 32);
        assertEq(hook.MAX_ADAPTERS(), 32);
        assertEq(hook.MORPHO(), address(morpho));
    }
}
