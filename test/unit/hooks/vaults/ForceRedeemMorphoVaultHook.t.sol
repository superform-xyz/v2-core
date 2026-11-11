// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { ForceRedeemMorphoVaultHook } from
    "../../../../src/hooks/vaults/metamorpho/ForceRedeemMorphoVaultHook.sol";
import { IMorphoVaultV2 } from "../../../../src/vendor/morpho/IMorphoVaultV2.sol";
import { MarketParams } from "../../../../src/vendor/morpho/IMorpho.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware
} from "../../../../src/interfaces/ISuperHook.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { HookSubTypes } from "../../../../src/libraries/HookSubTypes.sol";
import { MockMorphoBlue, MockMorphoMarketAdapter, MockMorphoVaultV2 } from "../../../mocks/morpho/MorphoVaultV2Mocks.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { FeeOnTransferToken, SharesInflatingVault } from "../../../mocks/morpho/MorphoVaultV2Mocks.sol";

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

contract ForceRedeemMorphoVaultHookTest is Test {
    uint256 internal constant CAP = 0.0025e18;

    ForceRedeemMorphoVaultHook internal hook;
    MockMorphoBlue internal morpho;
    MockMorphoVaultV2 internal vault;
    MockMorphoMarketAdapter internal adapter;

    /// @dev A REAL ERC20, not a bare address: `_preExecute` reads `balanceOf` on the underlying, so
    ///      the accounting cannot be exercised against a codeless placeholder.
    address internal asset;
    address internal irm = address(0x1247);
    address internal account = address(0xACC0);

    bytes32 internal constant ID_A = keccak256("A");
    bytes32 internal constant ID_B = keccak256("B");
    bytes32 internal constant ID_C = keccak256("C");
    bytes32 internal constant ORACLE_ID = bytes32(uint256(0xFEED));

    function setUp() public {
        asset = address(new MockERC20("Underlying", "UND", 18));
        morpho = new MockMorphoBlue();
        hook = new ForceRedeemMorphoVaultHook(address(morpho), CAP);
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

    /// @dev `build` wraps everything between preExecute and postExecute, and this hook's LAST inner
    ///      execution is the withdraw. `_pulls` returns only the `forceDeallocate` legs, so the existing
    ///      expectations about pull counts and amounts keep their meaning; `_withdrawLeg` exposes the
    ///      final one separately.
    function _pulls(bytes memory data, address prevHook) internal view returns (Execution[] memory mid) {
        Execution[] memory all = hook.build(prevHook, account, data);
        mid = new Execution[](all.length - 3);
        for (uint256 i; i < mid.length; ++i) {
            mid[i] = all[i + 1];
        }
    }

    /// @dev The withdraw execution: second from the end, before postExecute
    function _withdrawLeg(bytes memory data) internal view returns (Execution memory) {
        Execution[] memory all = hook.build(address(0), account, data);
        return all[all.length - 2];
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

        vm.expectRevert(abi.encodeWithSelector(ForceRedeemMorphoVaultHook.INVALID_DATA_LENGTH.selector, 86, 85));
        hook.build(address(0), account, abi.encodePacked(good, hex"00"));

        vm.expectRevert(abi.encodeWithSelector(ForceRedeemMorphoVaultHook.INVALID_DATA_LENGTH.selector, 84, 85));
        hook.build(address(0), account, abi.encodePacked(ORACLE_ID, address(vault), uint256(1 ether)));
    }

    function test_ResolvedZeroAmountReverts() public {
        _listMarket(ID_A, 100 ether, 200 ether, 0);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), account, _data(0, false));
    }

    function test_SizingSurfaceIsOneInAssetsLegAtOffsetFiftyTwo() public view {
        uint256[] memory amounts = hook.decodeAmounts(_data(7 ether, false));
        assertEq(amounts.length, 1);
        assertEq(amounts[0], 7 ether);

        ISuperHookInflowOutflow.AmountMeta[] memory meta = hook.amountRoles("");
        assertEq(meta.length, 1);
        assertEq(uint8(meta[0].dir), uint8(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint8(meta[0].denom), uint8(ISuperHookInflowOutflow.Denomination.ASSETS));
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
            abi.encodeWithSelector(ForceRedeemMorphoVaultHook.SHORTFALL.selector, 120 ether, 121 ether)
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
        vm.expectRevert(abi.encodeWithSelector(ForceRedeemMorphoVaultHook.SHORTFALL.selector, 10 ether, 99 ether));
        hook.build(address(0), account, _data(99 ether, false));
    }

    function test_ShortfallBlamesTheCapWhenTheCapIsTheCause() public {
        MockMorphoMarketAdapter dear = new MockMorphoMarketAdapter(address(vault), address(morpho));
        vault.addAdapter(address(dear), CAP + 5);
        morpho.setMarket(ID_B, _params(asset), 1000 ether, 0);
        dear.addMarket(ID_B, 1000 ether);

        vm.expectRevert(
            abi.encodeWithSelector(ForceRedeemMorphoVaultHook.PENALTY_ABOVE_CAP.selector, CAP + 5, CAP)
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
            abi.encodeWithSelector(ForceRedeemMorphoVaultHook.SHORTFALL.selector, 100 ether, 150 ether)
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
            abi.encodeWithSelector(ForceRedeemMorphoVaultHook.SHORTFALL.selector, 100 ether, 101 ether)
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
        vm.expectRevert(abi.encodeWithSelector(ForceRedeemMorphoVaultHook.SHORTFALL.selector, 60 ether, 120 ether));
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
        vm.expectRevert(abi.encodeWithSelector(ForceRedeemMorphoVaultHook.TOO_MANY_ADAPTERS.selector, 34, 32));
        hook.build(address(0), account, _data(1 ether, false));
    }

    /// @dev The solvency bound converts ASSETS TO SHARES, and at a 1:1 preview rate that conversion is
    ///      invisible: comparing `balanceOf` against the raw penalty assets would pass every other test in
    ///      this file. A non-unit rate is what makes `previewWithdraw` load-bearing.
    function test_SolvencyBoundConvertsAssetsToSharesAtTheVaultsRate() public {
        _listMarket(ID_A, 1000 ether, 1000 ether, 0);
        vault.setPreviewRate(2e18); // one asset costs two shares

        uint256 penalty = _ceilPenalty(1000 ether, 1e13);
        uint256 required = 2 * (1000 ether + penalty) + 1; // one penalised pull, plus the withdraw

        vault.setShares(account, required - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ForceRedeemMorphoVaultHook.INSUFFICIENT_SHARES.selector, required - 1, required
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

        vm.expectRevert(abi.encodeWithSelector(ForceRedeemMorphoVaultHook.TOO_MANY_MARKETS.selector, 33, 32));
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
        // +1: one ceiling-rounded burn per penalised pull, plus one for the withdraw itself.
        uint256 required = 1000 ether + _ceilPenalty(1000 ether, 1e13) + 1;
        vm.expectRevert(
            abi.encodeWithSelector(ForceRedeemMorphoVaultHook.INSUFFICIENT_SHARES.selector, 1, required)
        );
        hook.build(address(0), account, _data(1000 ether, false));
    }

    function test_SolvencyBoundAddsOneShareOfSlackPerPenalisedPull() public {
        // Two legs, both penalised: required == previewWithdraw(total) + (2 - 1).
        _listMarket(ID_A, 100 ether, 100 ether, 0);
        _listMarket(ID_B, 100 ether, 100 ether, 0);

        uint256 totalPenalty = _ceilPenalty(100 ether, 1e13) + _ceilPenalty(50 ether, 1e13);
        uint256 required = IMorphoVaultV2(address(vault)).previewWithdraw(150 ether + totalPenalty) + 2;

        vault.setShares(account, required - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ForceRedeemMorphoVaultHook.INSUFFICIENT_SHARES.selector, required - 1, required
            )
        );
        hook.build(address(0), account, _data(150 ether, false));

        vault.setShares(account, required);
        assertEq(_pulls(_data(150 ether, false), address(0)).length, 2, "exactly the bound is enough");
    }

    function test_ZeroPenaltyAdapterStillNeedsSharesForTheWithdraw() public {
        MockMorphoVaultV2 free = new MockMorphoVaultV2(asset);
        MockMorphoMarketAdapter freeAdapter = new MockMorphoMarketAdapter(address(free), address(morpho));
        free.addAdapter(address(freeAdapter), 0);
        free.setShares(account, 0);
        morpho.setMarket(ID_A, _params(asset), 500 ether, 0);
        freeAdapter.addMarket(ID_A, 500 ether);

        bytes memory data = abi.encodePacked(ORACLE_ID, address(free), uint256(100 ether), false);

        // THE PREMISE IS THE REVERSE OF THE DEALLOCATE-ONLY SIBLING'S. There, a zero-penalty adapter put
        // nothing at risk and the solvency check was skipped entirely. Here the hook withdraws, so the
        // account must cover the withdraw whatever the penalty rate is — and with no early return the
        // refusal is a free INSUFFICIENT_SHARES rather than a panic after every pull has run.
        vm.expectRevert(
            abi.encodeWithSelector(ForceRedeemMorphoVaultHook.INSUFFICIENT_SHARES.selector, 0, 100 ether)
        );
        hook.build(address(0), account, data);

        free.setShares(account, 100 ether);
        Execution[] memory all = hook.build(address(0), account, data);
        assertEq(all.length, 4, "one pull plus the withdraw, and no penalty slack to add");
    }

    /// @dev The output forwards, reversing the deallocate sibling's `outAmount = 0`: this hook pays the
    ///      account, so it publishes the underlying actually received.
    /// @dev THE ACCOUNT IS PRE-FUNDED, which is the whole point. With a zero starting balance, a hook that
    ///      wrote the absolute balance instead of the delta would publish the same number and pass.
    function test_PublishesTheUnderlyingItActuallyPaidOut() public {
        _listMarket(ID_A, 500 ether, 500 ether, 0);
        uint256 assets = 100 ether;
        MockERC20(asset).mint(account, 777 ether); // pre-existing holdings the hook must NOT report

        vm.startPrank(account);
        hook.setExecutionContext(account);
        Execution[] memory all = hook.build(address(0), account, _data(assets, false));

        uint256 sharesBefore = vault.balanceOf(account);
        for (uint256 i; i < all.length; ++i) {
            (bool ok,) = all[i].target.call(all[i].callData);
            assertTrue(ok, string.concat("execution ", vm.toString(i)));
        }
        vm.stopPrank();

        assertEq(hook.getOutAmount(account), assets, "outAmount is the DELTA, not the 877 ether now held");
        assertEq(MockERC20(asset).balanceOf(account), 777 ether + assets, "sanity: the absolute differs");
        assertEq(hook.getOutToken(account), asset, "outToken is the vault underlying");
        assertGt(sharesBefore - vault.balanceOf(account), 0, "and shares were really given up");
        assertEq(hook.usedShares(), sharesBefore - vault.balanceOf(account), "usedShares spans the whole call");
    }

    /// @dev The withdraw is the LAST inner execution, targets the vault, and asks for exactly `assets`
    ///      with the account as both receiver and owner — which is what makes a share allowance
    ///      unnecessary.
    function test_WithdrawLegIsLastAndSelfAddressed() public {
        _listMarket(ID_A, 500 ether, 500 ether, 0);
        uint256 assets = 100 ether;

        Execution memory w = _withdrawLeg(_data(assets, false));
        assertEq(w.target, address(vault), "the vault is the withdraw target");
        assertEq(w.value, 0);
        assertEq(bytes4(w.callData), bytes4(keccak256("withdraw(uint256,address,address)")), "withdraw, not redeem");

        bytes memory args = new bytes(w.callData.length - 4);
        for (uint256 i; i < args.length; ++i) {
            args[i] = w.callData[i + 4];
        }
        (uint256 a, address receiver, address owner) = abi.decode(args, (uint256, address, address));
        assertEq(a, assets, "withdraws exactly the requested underlying");
        assertEq(receiver, account, "paid to the account");
        assertEq(owner, account, "and drawn from the account, so msg.sender == owner");
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
        assertEq(all.length, 4, "one pull plus the withdraw");

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
                ForceRedeemMorphoVaultHook.INSUFFICIENT_SHARES.selector, claim, oversized + claim + 1
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
        // The withdraw's own ceiling needs one share beyond the pure claim/(1+p) figure.
        big.setShares(account, claim + 1);
        bytes memory data = abi.encodePacked(ORACLE_ID, address(big), sized, false);

        Execution[] memory all = hook.build(address(0), account, data);
        assertEq(all.length, 4, "a correctly sized exit is unaffected by the bound");
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

        assertEq(all.length, 4, "it must actually complete a build, not revert early");
        emit log_named_uint("worst-case build gas", used);
        assertLt(used, 2 ** 24, "build must fit under the EIP-7825 per-transaction gas cap");
    }

    /*//////////////////////////////////////////////////////////////
                      OUTFLOW IDENTITY AND ACCOUNTING
    //////////////////////////////////////////////////////////////*/

    /// @dev The type is not cosmetic: `lint_hook_manifest.py` maps (config, instant) to NONACCOUNTING only,
    ///      and an OUTFLOW hook routes through SuperLedger where the deallocate-only siblings do not.
    function test_IsAnOutflowErc4626Hook() public view {
        assertEq(uint8(hook.hookType()), uint8(ISuperHook.HookType.OUTFLOW), "OUTFLOW, not NONACCOUNTING");
        assertEq(hook.subtype(), HookSubTypes.ERC4626, "ERC4626, not MISC");
    }

    /// @dev `spToken` is what the ledger attributes the position to, and `asset` is what `_postExecute`
    ///      measures the delta in. Both are set in `_preExecute`, before any leg runs.
    function test_PreExecuteSetsTheLedgerFields() public {
        _listMarket(ID_A, 500 ether, 500 ether, 0);
        vm.startPrank(account);
        hook.setExecutionContext(account);
        Execution[] memory all = hook.build(address(0), account, _data(100 ether, false));
        (bool ok,) = all[0].target.call(all[0].callData);
        assertTrue(ok, "preExecute");
        vm.stopPrank();

        assertEq(hook.spToken(), address(vault), "spToken is the vault");
        assertEq(hook.asset(), asset, "asset is the vault underlying");
    }

    /// @dev `outAmount` IS MEASURED, NOT DECLARED. On a plain ERC-20 the delta equals `assets`, so only an
    ///      underlying that delivers less can distinguish the two. A hook that published the request would
    ///      over-report here and a `usePrevHookAmount` successor would size from tokens that never arrived.
    function test_OutAmountIsTheMeasuredDeltaNotTheRequest() public {
        FeeOnTransferToken fot = new FeeOnTransferToken(500); // 5% kept on transfer
        MockMorphoVaultV2 fotVault = new MockMorphoVaultV2(address(fot));
        MockMorphoMarketAdapter fotAdapter = new MockMorphoMarketAdapter(address(fotVault), address(morpho));
        fotVault.addAdapter(address(fotAdapter), 1e13);
        fotVault.setShares(account, 1_000_000 ether);
        morpho.setMarket(ID_A, _params(address(fot)), 500 ether, 0);
        fotAdapter.addMarket(ID_A, 500 ether);

        uint256 assets = 100 ether;
        bytes memory data = abi.encodePacked(ORACLE_ID, address(fotVault), assets, false);

        vm.startPrank(account);
        hook.setExecutionContext(account);
        Execution[] memory all = hook.build(address(0), account, data);
        for (uint256 i; i < all.length; ++i) {
            (bool ok,) = all[i].target.call(all[i].callData);
            assertTrue(ok, string.concat("execution ", vm.toString(i)));
        }
        vm.stopPrank();

        assertEq(hook.getOutAmount(account), 95 ether, "published what arrived, not what was asked for");
        assertLt(hook.getOutAmount(account), assets, "and that is strictly less than the request");
    }

    /// @dev The `usedShares` subtraction is clamped. No honest path can reach it — every leg only burns the
    ///      account's shares — so this uses a vault that violates that assumption, to prove the branch
    ///      reports zero rather than panicking at the very end of an otherwise successful exit.
    function test_UsedSharesClampsIfTheBalanceSomehowRises() public {
        SharesInflatingVault odd = new SharesInflatingVault(asset);
        MockMorphoMarketAdapter a = new MockMorphoMarketAdapter(address(odd), address(morpho));
        odd.addAdapter(address(a), 0); // zero penalty: no burn, so only the withdraw moves shares
        odd.setShares(account, 1_000_000 ether);
        odd.setInflate(true);
        morpho.setMarket(ID_A, _params(asset), 500 ether, 0);
        a.addMarket(ID_A, 500 ether);

        bytes memory data = abi.encodePacked(ORACLE_ID, address(odd), uint256(100 ether), false);
        vm.startPrank(account);
        hook.setExecutionContext(account);
        Execution[] memory all = hook.build(address(0), account, data);
        for (uint256 i; i < all.length; ++i) {
            (bool ok,) = all[i].target.call(all[i].callData);
            assertTrue(ok, string.concat("execution ", vm.toString(i)));
        }
        vm.stopPrank();

        assertEq(hook.usedShares(), 0, "clamped to zero instead of underflowing");
    }

    /*//////////////////////////////////////////////////////////////
                        THE WITHDRAW LEG IN DETAIL
    //////////////////////////////////////////////////////////////*/

    /// @dev ORDER MATTERS AND IS NOT INCIDENTAL: the withdraw must come after every pull, because it spends
    ///      the idle those pulls create. A build that emitted it first would revert at execution on an
    ///      illiquid vault — the exact situation this hook exists for.
    function test_WithdrawIsEmittedAfterEveryPull() public {
        _listMarket(ID_A, 200 ether, 200 ether, 0);
        _listMarket(ID_B, 300 ether, 300 ether, 0);

        Execution[] memory all = hook.build(address(0), account, _data(450 ether, false));
        assertEq(all.length, 5, "pre + two pulls + withdraw + post");

        for (uint256 i = 1; i < all.length - 2; ++i) {
            assertEq(bytes4(all[i].callData), IMorphoVaultV2.forceDeallocate.selector, "pulls come first");
        }
        assertEq(
            bytes4(all[all.length - 2].callData),
            bytes4(keccak256("withdraw(uint256,address,address)")),
            "and the withdraw is last"
        );
    }

    /// @dev The withdraw asks for the SUM of the pulls, which is the whole point of the fill summing to
    ///      exactly `assets`: a withdraw for more would revert, for less would strand idle in the vault.
    function test_WithdrawAmountEqualsTheSumOfThePulls() public {
        _listMarket(ID_A, 200 ether, 200 ether, 0);
        _listMarket(ID_B, 300 ether, 300 ether, 0);
        uint256 assets = 450 ether;

        Execution[] memory pulls = _pulls(_data(assets, false), address(0));
        uint256 summed;
        for (uint256 i; i < pulls.length; ++i) {
            (,, uint256 amount,) = _decodeCall(pulls[i]);
            summed += amount;
        }

        Execution memory w = _withdrawLeg(_data(assets, false));
        bytes memory args = new bytes(w.callData.length - 4);
        for (uint256 i; i < args.length; ++i) {
            args[i] = w.callData[i + 4];
        }
        (uint256 wAmount,,) = abi.decode(args, (uint256, address, address));
        assertEq(summed, assets, "pulls sum to the request");
        assertEq(wAmount, summed, "and the withdraw claims exactly that");
    }

    /// @dev With `usePrevHookAmount`, the RESOLVED amount must drive the withdraw and the solvency bound,
    ///      not the calldata word. A hook that resolved the pulls but withdrew the decoy would strand the
    ///      difference in the vault as unattributed idle.
    function test_UsePrevHookAmountDrivesTheWithdrawToo() public {
        _listMarket(ID_A, 500 ether, 500 ether, 0);

        PrevHookStub prev = new PrevHookStub();
        prev.setExecutionContext(account);
        prev.publish(123 ether, asset, account);

        bytes memory data = abi.encodePacked(ORACLE_ID, address(vault), uint256(1 wei), true);
        Execution[] memory all = hook.build(address(prev), account, data);
        assertEq(all.length, 4, "one pull plus the withdraw");

        (,, uint256 pulled,) = _decodeCall(all[1]);
        bytes memory args = new bytes(all[2].callData.length - 4);
        for (uint256 i; i < args.length; ++i) {
            args[i] = all[2].callData[i + 4];
        }
        (uint256 withdrawn,,) = abi.decode(args, (uint256, address, address));

        assertEq(pulled, 123 ether, "pulled the resolved amount");
        assertEq(withdrawn, 123 ether, "and withdrew the resolved amount, not the 1 wei decoy");
    }

    /*//////////////////////////////////////////////////////////////
                   INTERFACES, ACCESS CONTROL, LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    /// @dev An OUTFLOW hook is ASSERTED on by the repo-wide sizing invariants, where a NONACCOUNTING one is
    ///      only warned about — so advertising the sizing pair correctly is load-bearing here in a way it
    ///      is not for the deallocate-only siblings.
    function test_AdvertisesTheFullSizingAndResultInterfaces() public view {
        assertTrue(hook.supportsInterface(type(ISuperHookInflowOutflow).interfaceId), "InflowOutflow");
        assertTrue(hook.supportsInterface(type(ISuperHookOutflow).interfaceId), "Outflow: it rewrites amounts");
        assertTrue(hook.supportsInterface(type(ISuperHook).interfaceId), "ISuperHook");
        assertTrue(hook.supportsInterface(type(ISuperHookResult).interfaceId), "Result");
        assertTrue(hook.supportsInterface(type(ISuperHookInspector).interfaceId), "Inspector");
        assertTrue(hook.supportsInterface(type(IERC165).interfaceId), "ERC165");
        assertFalse(hook.supportsInterface(0xdeadbeef), "and nothing it does not implement");
    }

    /// @dev `preExecute`/`postExecute` move real value and set the ledger fields, so only the account may
    ///      drive them. A stranger calling either directly must be refused.
    function test_OnlyTheAccountMayDriveTheLifecycle() public {
        _listMarket(ID_A, 500 ether, 500 ether, 0);
        bytes memory data = _data(100 ether, false);

        vm.prank(account);
        hook.setExecutionContext(account);

        vm.prank(makeAddr("stranger"));
        vm.expectRevert();
        hook.preExecute(address(0), account, data);

        vm.prank(makeAddr("stranger"));
        vm.expectRevert();
        hook.postExecute(address(0), account, data);
    }

    /// @dev The pre/post mutexes are one-shot, and `resetExecutionState` is what clears them. Without the
    ///      reset a second exit in the same context would be refused, which is how the executor enforces
    ///      that a hook runs exactly once per leg.
    function test_MutexesAreOneShotAndClearedByReset() public {
        _listMarket(ID_A, 500 ether, 500 ether, 0);
        bytes memory data = _data(100 ether, false);

        vm.startPrank(account);
        hook.setExecutionContext(account);
        Execution[] memory all = hook.build(address(0), account, data);
        for (uint256 i; i < all.length; ++i) {
            (bool ok,) = all[i].target.call(all[i].callData);
            assertTrue(ok, "first run");
        }
        // preExecute is spent until the state is reset
        vm.expectRevert();
        hook.preExecute(address(0), account, data);

        hook.resetExecutionState(account);
        hook.setExecutionContext(account);
        hook.preExecute(address(0), account, data);
        vm.stopPrank();
    }

    /// @dev `replaceCalldataAmounts` takes exactly one amount, because the hook has exactly one sized leg.
    function test_ReplaceCalldataAmountsRejectsTheWrongArity() public {
        bytes memory data = _data(1 ether, false);
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        hook.replaceCalldataAmounts(data, new uint256[](0));
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        hook.replaceCalldataAmounts(data, new uint256[](2));
    }

    function test_DecodeUsePrevHookAmountReadsTheFlagAtEightyFour() public view {
        assertFalse(hook.decodeUsePrevHookAmount(_data(1 ether, false)));
        assertTrue(hook.decodeUsePrevHookAmount(_data(1 ether, true)));
    }

    /// @dev A zero yield source is a caller error, caught before any vault read.
    function test_ZeroYieldSourceReverts() public {
        bytes memory data = abi.encodePacked(ORACLE_ID, address(0), uint256(1 ether), false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), account, data);
    }

    /// @dev `_marketLiquidity` floors at zero. `supply == borrow` is the common degenerate case and is
    ///      covered elsewhere; this is the strictly-underwater one, where a bare subtraction would
    ///      underflow rather than report "nothing withdrawable".
    function test_MarketWithBorrowAboveSupplyIsTreatedAsEmpty() public {
        _listMarket(ID_A, 400 ether, 400 ether, 0);
        morpho.setMarket(ID_B, _params(asset), 100 ether, 150 ether); // borrow > supply
        adapter.addMarket(ID_B, 400 ether);

        Execution[] memory pulls = _pulls(_data(400 ether, false), address(0));
        assertEq(pulls.length, 1, "the underwater market contributed nothing and did not underflow");
    }

    /*//////////////////////////////////////////////////////////////
                      BOUNDARIES AND REMAINING PROBES
    //////////////////////////////////////////////////////////////*/

    /// @dev THE CAP COMPARISON IS `>`, NOT `>=`, so an adapter sitting EXACTLY at the ceiling is eligible.
    ///      Only a boundary case can tell the two operators apart, and getting it wrong would quietly
    ///      exclude an adapter priced exactly at the policy limit.
    function test_AdapterExactlyAtTheCapIsEligible() public {
        MockMorphoVaultV2 atCap = new MockMorphoVaultV2(asset);
        MockMorphoMarketAdapter a = new MockMorphoMarketAdapter(address(atCap), address(morpho));
        atCap.addAdapter(address(a), CAP); // exactly the immutable ceiling
        atCap.setShares(account, 1_000_000 ether);
        morpho.setMarket(ID_A, _params(asset), 500 ether, 0);
        a.addMarket(ID_A, 500 ether);

        bytes memory data = abi.encodePacked(ORACLE_ID, address(atCap), uint256(100 ether), false);
        Execution[] memory all = hook.build(address(0), account, data);
        assertEq(all.length, 4, "an adapter at exactly the cap is usable");
    }

    /// @dev One wei above the cap is the other side of that boundary, and must be excluded.
    function test_AdapterOneWeiAboveTheCapIsExcluded() public {
        MockMorphoVaultV2 overCap = new MockMorphoVaultV2(asset);
        MockMorphoMarketAdapter a = new MockMorphoMarketAdapter(address(overCap), address(morpho));
        overCap.addAdapter(address(a), CAP + 1);
        overCap.setShares(account, 1_000_000 ether);
        morpho.setMarket(ID_A, _params(asset), 500 ether, 0);
        a.addMarket(ID_A, 500 ether);

        bytes memory data = abi.encodePacked(ORACLE_ID, address(overCap), uint256(100 ether), false);
        vm.expectRevert(
            abi.encodeWithSelector(ForceRedeemMorphoVaultHook.PENALTY_ABOVE_CAP.selector, CAP + 1, CAP)
        );
        hook.build(address(0), account, data);
    }

    /// @dev An adapter that ANSWERS `adaptiveCurveIrm()` with the zero address is distinct from one whose
    ///      probe fails, and both are read as "pins no IRM" — so the IRM filter is disabled and a market
    ///      on any IRM is admitted. This is the one fail-OPEN branch in an otherwise fail-closed filter
    ///      set; pinning it here means a future change to that reading shows up as a failing test.
    function test_AdapterAnsweringZeroIrmDisablesTheIrmFilter() public {
        adapter.setZeroIrm(true);
        _listMarket(ID_A, 400 ether, 400 ether, 0);

        // A market on a completely different IRM, which a pinned adapter would have excluded.
        morpho.setMarket(
            ID_B, MarketParams(asset, address(0xC011), address(0x0AC1), address(0xBAD1), 0.945e18), 400 ether, 0
        );
        adapter.addMarket(ID_B, 400 ether);

        Execution[] memory pulls = _pulls(_data(800 ether, false), address(0));
        assertEq(pulls.length, 2, "both markets admitted, because no IRM is pinned");
    }

    /// @dev An adapter whose `morpho()` reverts after answering `parentVault()` correctly. Distinct from a
    ///      codeless adapter: the contract exists and passes the identity check, then fails the next probe.
    function test_AdapterWhoseMorphoProbeRevertsIsSkipped() public {
        _listMarket(ID_A, 400 ether, 400 ether, 0);

        MockMorphoMarketAdapter broken = new MockMorphoMarketAdapter(address(vault), address(morpho));
        broken.setBreakMorpho(true);
        broken.addMarket(ID_B, 1000 ether);
        vault.addAdapter(address(broken), 1e13);
        morpho.setMarket(ID_B, _params(asset), 1000 ether, 0);

        Execution[] memory pulls = _pulls(_data(400 ether, false), address(0));
        assertEq(pulls.length, 1, "skipped at the morpho probe, not fatal");
    }

    /// @dev The sort's final tie-break is market index WITHIN one adapter, which the adapter-index test
    ///      cannot reach. Two markets on the SAME adapter with identical penalty and capacity must fill in
    ///      listing order — which the stable sort provides only because discovery is market-minor.
    function test_EqualCapacityOnOneAdapterFillsInMarketListingOrder() public {
        // Distinguishable by `lltv`: the mock gives every market identical params otherwise, so the
        // emitted adapterData could not say which of the two was chosen.
        morpho.setMarket(ID_A, MarketParams(asset, address(0xC011), address(0x0AC1), irm, 0.945e18), 100 ether, 0);
        adapter.addMarket(ID_A, 100 ether);
        morpho.setMarket(ID_B, MarketParams(asset, address(0xC011), address(0x0AC1), irm, 0.965e18), 100 ether, 0);
        adapter.addMarket(ID_B, 100 ether);

        Execution[] memory pulls = _pulls(_data(40 ether, false), address(0));
        assertEq(pulls.length, 1, "one market covers it");
        (, MarketParams memory p,,) = _decodeCall(pulls[0]);
        assertEq(p.lltv, 0.945e18, "the first-listed market wins an exact tie");
    }

    /// @dev Three adapters, one over the cap, one shapeless, one good: the filters compose, and the fill
    ///      completes from the only eligible adapter rather than reverting on the other two.
    function test_FiltersComposeAcrossSeveralBadAdapters() public {
        _listMarket(ID_A, 400 ether, 400 ether, 0);

        MockMorphoMarketAdapter dear = new MockMorphoMarketAdapter(address(vault), address(morpho));
        dear.addMarket(ID_B, 1000 ether);
        vault.addAdapter(address(dear), CAP + 1);

        MockMorphoMarketAdapter shapeless = new MockMorphoMarketAdapter(address(vault), address(morpho));
        shapeless.setBreakMarketIdsLength(true);
        vault.addAdapter(address(shapeless), 1e13);

        morpho.setMarket(ID_B, _params(asset), 1000 ether, 0);

        Execution[] memory pulls = _pulls(_data(400 ether, false), address(0));
        assertEq(pulls.length, 1, "filled from the single eligible adapter");
        (address a,,,) = _decodeCall(pulls[0]);
        assertEq(a, address(adapter));
    }

    /// @dev When a single market covers the request exactly, the pull equals the request equals the
    ///      withdraw — the degenerate case where all three numbers coincide and an off-by-one anywhere in
    ///      the chain would be invisible to the multi-pull tests.
    function test_SinglePullExactlyEqualsTheRequestAndTheWithdraw() public {
        _listMarket(ID_A, 250 ether, 250 ether, 0);
        uint256 assets = 250 ether;

        Execution[] memory all = hook.build(address(0), account, _data(assets, false));
        assertEq(all.length, 4, "exactly one pull");
        (,, uint256 pulled,) = _decodeCall(all[1]);
        assertEq(pulled, assets, "the pull drains the market exactly");

        bytes memory args = new bytes(all[2].callData.length - 4);
        for (uint256 i; i < args.length; ++i) {
            args[i] = all[2].callData[i + 4];
        }
        (uint256 withdrawn,,) = abi.decode(args, (uint256, address, address));
        assertEq(withdrawn, assets, "and the withdraw claims it all");
    }

    /// @dev `inspect` reads only the yield source, so two payloads differing anywhere after offset 52
    ///      produce the SAME leaf — which is what lets a curator add a market without re-signing, and is
    ///      also precisely the scope of what one leaf authorises.
    function test_InspectIgnoresEverythingAfterTheYieldSource() public view {
        bytes memory a = abi.encodePacked(ORACLE_ID, address(vault), uint256(1 ether), false);
        bytes memory b = abi.encodePacked(bytes32(uint256(0xBEEF)), address(vault), uint256(999 ether), true);
        assertEq(hook.inspect(a), hook.inspect(b), "same vault, same leaf");
        assertEq(hook.inspect(a).length, 20);
    }

    /*//////////////////////////////////////////////////////////////
                                 FUZZ
    //////////////////////////////////////////////////////////////*/

    /// @dev Whatever the request, the pulls sum to EXACTLY it and the withdraw claims exactly that sum.
    ///      This is the hook's central invariant and the one a future refactor is most likely to break.
    function testFuzz_PullsAlwaysSumToTheRequestAndTheWithdrawMatches(uint96 raw) public {
        _listMarket(ID_A, 200 ether, 200 ether, 0);
        _listMarket(ID_B, 300 ether, 300 ether, 0);
        _listMarket(ID_C, 100 ether, 100 ether, 0);

        uint256 assets = uint256(raw) % 600 ether;
        vm.assume(assets > 0);

        Execution[] memory all = hook.build(address(0), account, _data(assets, false));
        uint256 summed;
        for (uint256 i = 1; i < all.length - 2; ++i) {
            (,, uint256 amount,) = _decodeCall(all[i]);
            summed += amount;
        }
        assertEq(summed, assets, "pulls sum to the request for every request");

        bytes memory args = new bytes(all[all.length - 2].callData.length - 4);
        for (uint256 i; i < args.length; ++i) {
            args[i] = all[all.length - 2].callData[i + 4];
        }
        (uint256 withdrawn,,) = abi.decode(args, (uint256, address, address));
        assertEq(withdrawn, assets, "and the withdraw claims exactly that");
    }

    /// @dev Any length other than 85 is refused, whatever the payload.
    function testFuzz_OnlyEightyFiveBytesIsAccepted(uint8 len) public {
        vm.assume(len != 85);
        _listMarket(ID_A, 500 ether, 500 ether, 0);
        vm.expectPartialRevert(ForceRedeemMorphoVaultHook.INVALID_DATA_LENGTH.selector);
        hook.build(address(0), account, new bytes(len));
    }

    /// @dev The sized leg round-trips at offset 52 for any value, with the adjacent flag intact.
    function testFuzz_AmountRoundTripsThroughReplace(uint256 amount, bool flag) public view {
        bytes memory original = _data(1 ether, flag);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        bytes memory rewritten = hook.replaceCalldataAmounts(original, amounts);
        assertEq(hook.decodeAmounts(rewritten)[0], amount);
        assertEq(hook.decodeUsePrevHookAmount(rewritten), flag, "the flag at 84 survives any amount");
        assertEq(rewritten.length, 85);
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_ConstructorRejectsZeroAndAboveMorphosOwnCeiling() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ForceRedeemMorphoVaultHook(address(0), CAP);

        vm.expectRevert(ForceRedeemMorphoVaultHook.INVALID_PENALTY_CAP.selector);
        new ForceRedeemMorphoVaultHook(address(morpho), 0);

        vm.expectRevert(ForceRedeemMorphoVaultHook.INVALID_PENALTY_CAP.selector);
        new ForceRedeemMorphoVaultHook(address(morpho), 0.02e18 + 1);

        assertEq(new ForceRedeemMorphoVaultHook(address(morpho), 0.02e18).MAX_PENALTY_WAD(), 0.02e18, "the ceiling itself is ok");
        assertEq(hook.MAX_PENALTY_WAD(), CAP);
        assertEq(hook.MORPHO_MAX_PENALTY_WAD(), 0.02e18);
        assertEq(hook.MAX_MARKETS(), 32);
        assertEq(hook.MAX_ADAPTERS(), 32);
        assertEq(hook.MORPHO(), address(morpho));
    }
}
