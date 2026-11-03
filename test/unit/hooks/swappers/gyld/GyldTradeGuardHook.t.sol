// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// Superform
import { GyldTradeGuardHook } from "../../../../../src/hooks/swappers/gyld/GyldTradeGuardHook.sol";
import { GyldBondRegistry } from "../../../../../src/accounting/oracles/GyldBondRegistry.sol";
import { GyldBondYieldSourceOracle } from "../../../../../src/accounting/oracles/GyldBondYieldSourceOracle.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { HookSubTypes } from "../../../../../src/libraries/HookSubTypes.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookInspector
} from "../../../../../src/interfaces/ISuperHook.sol";

import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { MockAggregator } from "../../../../mocks/MockAggregator.sol";
import { MockGyldNavFeed } from "../../../../mocks/gyld/MockGyldNavFeed.sol";

/// @title GyldTradeGuardHookTest
/// @notice Unit coverage for `GyldTradeGuardHook`: the fixed 136-byte calldata contract, each reason a trade
///         must not proceed as its own named error, and the rule that the LEAF's freshness bounds win when
///         they are stricter than the registry's.
contract GyldTradeGuardHookTest is Test {
    GyldTradeGuardHook internal hook;
    GyldBondRegistry internal registry;
    GyldBondYieldSourceOracle internal oracle;
    MockHook internal prevHook;

    MockERC20 internal bond;
    MockERC20 internal cash;
    MockAggregator internal navFeed;
    MockGyldNavFeed internal nativeFeed;

    address internal account;
    address internal admin = address(0xA11CE);

    uint256 internal constant REG_OBS_AGE = 7 days;
    uint256 internal constant REG_PUB_AGE = 7 days;
    uint256 internal constant LEAF_OBS_AGE = 2 days;
    uint256 internal constant LEAF_PUB_AGE = 1 days;

    function setUp() public {
        account = address(this);
        vm.warp(1_800_000_000);

        bond = new MockERC20("Gyld Bond", "GBOND", 18);
        cash = new MockERC20("USD Coin", "USDC", 6);
        navFeed = new MockAggregator(8);
        navFeed.setLatestAnswer(1.05e8);
        nativeFeed = new MockGyldNavFeed(8);
        nativeFeed.setFreshNav(address(bond), 1.05e8);

        registry = new GyldBondRegistry(admin);
        oracle = new GyldBondYieldSourceOracle(address(0xC0FFEE), address(registry));
        hook = new GyldTradeGuardHook(address(oracle));
        prevHook = new MockHook(ISuperHook.HookType.INFLOW, address(cash));

        _registerChainlink();
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _baseCfg() internal view returns (GyldBondRegistry.InstrumentConfig memory cfg) {
        cfg.bondToken = address(bond);
        cfg.navFeed = address(navFeed);
        cfg.cashToken = address(cash);
        cfg.maxObservationAge = REG_OBS_AGE;
        cfg.maxPublicationAge = REG_PUB_AGE;
    }

    function _registerChainlink() internal {
        GyldBondRegistry.InstrumentConfig memory cfg = _baseCfg();
        vm.prank(admin);
        registry.registerInstrument(cfg);
    }

    function _reRegisterNative(bool requiresObservationTime) internal {
        vm.startPrank(admin);
        registry.proposeDeregisterInstrument(address(bond));
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        registry.executeDeregisterInstrument(address(bond));
        vm.stopPrank();

        GyldBondRegistry.InstrumentConfig memory cfg = _baseCfg();
        cfg.navFeed = address(nativeFeed);
        cfg.navFeedKind = 1;
        cfg.requiresObservationTime = requiresObservationTime;
        vm.prank(admin);
        registry.registerInstrument(cfg);
        nativeFeed.setFreshNav(address(bond), 1.05e8);
    }

    /// @dev The 136-byte layout: a 52-byte strategy header, then bond, cash, and the two age bounds.
    function _data(
        address bondToken,
        address cashToken,
        uint256 maxObservationAge,
        uint256 maxPublicationAge
    )
        internal
        pure
        returns (bytes memory)
    {
        return
            abi.encodePacked(bytes32(0), bytes20(bondToken), bytes20(cashToken), maxObservationAge, maxPublicationAge);
    }

    function _data() internal view returns (bytes memory) {
        return _data(address(bond), address(cash), LEAF_OBS_AGE, LEAF_PUB_AGE);
    }

    function _suspend(bool v) internal {
        vm.prank(admin);
        registry.setNavSuspended(address(bond), v);
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public view {
        assertEq(address(hook.GYLD_ORACLE()), address(oracle));
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(hook.SUB_TYPE(), HookSubTypes.MISC);
        assertEq(hook.MAX_AGE_CEILING(), 30 days);
        assertEq(hook.name(), "Gyld Trade Guard");
        assertEq(hook.description(), "Reverts unless the named Gyld bond is registered, unsuspended and freshly priced");
    }

    function test_Constructor_RevertIf_OracleZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new GyldTradeGuardHook(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                           CALLDATA CONTRACT
    //////////////////////////////////////////////////////////////*/

    function test_Data_IsExactly136Bytes() public view {
        assertEq(_data().length, 136);
    }

    function test_Build_RevertIf_DataTooShort() public {
        vm.expectRevert(GyldTradeGuardHook.INVALID_DATA_LENGTH.selector);
        hook.build(address(prevHook), account, new bytes(135));
    }

    /// @dev An exact length, not a minimum: trailing bytes would mean a leaf whose identity is ambiguous.
    function test_Build_RevertIf_DataTooLong() public {
        bytes memory data = bytes.concat(_data(), hex"00");
        vm.expectRevert(GyldTradeGuardHook.INVALID_DATA_LENGTH.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_BondTokenZero() public {
        bytes memory data = _data(address(0), address(cash), LEAF_OBS_AGE, LEAF_PUB_AGE);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_CashTokenZero() public {
        bytes memory data = _data(address(bond), address(0), LEAF_OBS_AGE, LEAF_PUB_AGE);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_IdenticalTokens() public {
        bytes memory data = _data(address(bond), address(bond), LEAF_OBS_AGE, LEAF_PUB_AGE);
        vm.expectRevert(GyldTradeGuardHook.IDENTICAL_TOKENS.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_ObservationAgeZero() public {
        bytes memory data = _data(address(bond), address(cash), 0, LEAF_PUB_AGE);
        vm.expectRevert(GyldTradeGuardHook.INVALID_STALENESS.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_PublicationAgeZero() public {
        bytes memory data = _data(address(bond), address(cash), LEAF_OBS_AGE, 0);
        vm.expectRevert(GyldTradeGuardHook.INVALID_STALENESS.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_ObservationAgeAboveCeiling() public {
        bytes memory data = _data(address(bond), address(cash), 30 days + 1, LEAF_PUB_AGE);
        vm.expectRevert(GyldTradeGuardHook.INVALID_STALENESS.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_PublicationAgeAboveCeiling() public {
        bytes memory data = _data(address(bond), address(cash), LEAF_OBS_AGE, 30 days + 1);
        vm.expectRevert(GyldTradeGuardHook.INVALID_STALENESS.selector);
        hook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                              BUILD SHAPE
    //////////////////////////////////////////////////////////////*/

    /// @dev A guard moves nothing: `build()` is exactly the pre/post pair.
    function test_Build_HealthyInstrument_YieldsOnlyPreAndPost() public view {
        Execution[] memory ex = hook.build(address(prevHook), account, _data());
        assertEq(ex.length, 2);
        assertEq(ex[0].target, address(hook));
        assertEq(ex[1].target, address(hook));
        assertEq(ex[0].value, 0);
        assertEq(ex[1].value, 0);
    }

    /// @dev PASSTHROUGH: the previous hook's output travels through untouched, so inserting a guard mid-chain
    ///      cannot break the piping of the hook after it.
    function test_PipeMode_ForwardsPreviousOutput() public {
        prevHook.setOutAmount(1234, account);
        hook.setExecutionContext(account);
        hook.preExecute(address(prevHook), account, _data());
        assertEq(hook.getOutAmount(account), 1234, "forwarded");
    }

    /*//////////////////////////////////////////////////////////////
                        EVERY REASON TO REFUSE
    //////////////////////////////////////////////////////////////*/

    function test_Refuses_UnregisteredInstrument() public {
        MockERC20 stranger = new MockERC20("Stranger", "STR", 18);
        bytes memory data = _data(address(stranger), address(cash), LEAF_OBS_AGE, LEAF_PUB_AGE);
        vm.expectRevert(GyldTradeGuardHook.INSTRUMENT_NOT_REGISTERED.selector);
        hook.build(address(prevHook), account, data);
        assertEq(
            hook.previewTradable(data, account),
            uint256(uint8(GyldBondYieldSourceOracle.NavFailure.NOT_REGISTERED)),
            "previewTradable agrees without reverting"
        );
    }

    /// @dev A denomination change between signing and execution must not go unnoticed.
    function test_Refuses_CashDenominationMismatch() public {
        MockERC20 wrongCash = new MockERC20("DAI", "DAI", 18);
        bytes memory data = _data(address(bond), address(wrongCash), LEAF_OBS_AGE, LEAF_PUB_AGE);
        vm.expectRevert(GyldTradeGuardHook.CASH_DENOMINATION_MISMATCH.selector);
        hook.build(address(prevHook), account, data);
        assertEq(hook.previewTradable(data, account), 101, "a dedicated code above the oracle's range");
    }

    function test_Refuses_SuspendedInstrument() public {
        _suspend(true);
        bytes memory data = _data();
        vm.expectRevert(GyldTradeGuardHook.NAV_SUSPENDED.selector);
        hook.build(address(prevHook), account, data);
        assertEq(hook.previewTradable(data, account), uint256(uint8(GyldBondYieldSourceOracle.NavFailure.SUSPENDED)));
    }

    function test_Refuses_StalePublicationFromTheRegistryBound() public {
        navFeed.setUpdatedAt(block.timestamp - REG_PUB_AGE - 1);
        bytes memory data = _data();
        vm.expectRevert(GyldTradeGuardHook.NAV_PUBLICATION_STALE.selector);
        hook.build(address(prevHook), account, data);
    }

    /// @dev THE REASON THE BOUNDS ARE IN THE LEAF. The registry tolerates a week-old publication; this leaf
    ///      tolerates a day. The leaf's stricter bound must win, otherwise a signer could present a loose
    ///      bound against a proof issued for a tight one.
    function test_Refuses_StalePublicationUnderTheStricterLeafBound() public {
        navFeed.setUpdatedAt(block.timestamp - LEAF_PUB_AGE - 1);
        // The oracle itself is content, because the registry's bound is a week.
        assertEq(oracle.previewNav(address(bond)).failureCode, 0, "the registry bound passes");

        bytes memory data = _data();
        vm.expectRevert(GyldTradeGuardHook.NAV_PUBLICATION_STALE.selector);
        hook.build(address(prevHook), account, data);
        assertEq(
            hook.previewTradable(data, account), uint256(uint8(GyldBondYieldSourceOracle.NavFailure.PUBLICATION_STALE))
        );
    }

    function test_Refuses_StaleObservationUnderTheStricterLeafBound() public {
        _reRegisterNative(false);
        nativeFeed.setNav(address(bond), 1.05e8, block.timestamp - LEAF_OBS_AGE - 1, block.timestamp);
        assertEq(oracle.previewNav(address(bond)).failureCode, 0, "the registry bound passes");

        bytes memory data = _data();
        vm.expectRevert(GyldTradeGuardHook.NAV_OBSERVATION_STALE.selector);
        hook.build(address(prevHook), account, data);
        assertEq(
            hook.previewTradable(data, account), uint256(uint8(GyldBondYieldSourceOracle.NavFailure.OBSERVATION_STALE))
        );
    }

    function test_Refuses_StaleObservationFromTheRegistryBound() public {
        _reRegisterNative(false);
        nativeFeed.setNav(address(bond), 1.05e8, block.timestamp - REG_OBS_AGE - 1, block.timestamp);
        bytes memory data = _data();
        vm.expectRevert(GyldTradeGuardHook.NAV_OBSERVATION_STALE.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Refuses_MissingObservationTimeWhenRequired() public {
        _reRegisterNative(true);
        nativeFeed.setNav(address(bond), 1.05e8, 0, block.timestamp);
        bytes memory data = _data();
        vm.expectRevert(GyldTradeGuardHook.OBSERVATION_TIME_UNAVAILABLE.selector);
        hook.build(address(prevHook), account, data);
        assertEq(
            hook.previewTradable(data, account),
            uint256(uint8(GyldBondYieldSourceOracle.NavFailure.OBSERVATION_UNAVAILABLE))
        );
    }

    function test_Refuses_NonPositiveNav() public {
        navFeed.setLatestAnswer(0);
        bytes memory data = _data();
        vm.expectRevert(GyldTradeGuardHook.INVALID_PRICE.selector);
        hook.build(address(prevHook), account, data);
        assertEq(
            hook.previewTradable(data, account), uint256(uint8(GyldBondYieldSourceOracle.NavFailure.ZERO_OR_NEGATIVE))
        );
    }

    function test_Refuses_CircuitBreakerTripped() public {
        vm.startPrank(admin);
        registry.proposeDeregisterInstrument(address(bond));
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        registry.executeDeregisterInstrument(address(bond));
        GyldBondRegistry.InstrumentConfig memory cfg = _baseCfg();
        cfg.navMaxAnswer = 1e8; // the 1.05e8 answer is above the breaker
        registry.registerInstrument(cfg);
        vm.stopPrank();

        bytes memory data = _data();
        vm.expectRevert(GyldTradeGuardHook.INVALID_PRICE.selector);
        hook.build(address(prevHook), account, data);
        assertEq(
            hook.previewTradable(data, account), uint256(uint8(GyldBondYieldSourceOracle.NavFailure.CIRCUIT_BREAKER))
        );
    }

    function test_Refuses_CashFeedFailure() public {
        MockAggregator cashFeed = new MockAggregator(8);
        cashFeed.setLatestAnswer(0); // dead

        vm.startPrank(admin);
        registry.proposeDeregisterInstrument(address(bond));
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        registry.executeDeregisterInstrument(address(bond));
        GyldBondRegistry.InstrumentConfig memory cfg = _baseCfg();
        cfg.navIsUsdDenominated = true;
        cfg.cashFeed = address(cashFeed);
        registry.registerInstrument(cfg);
        vm.stopPrank();

        bytes memory data = _data();
        vm.expectRevert(GyldTradeGuardHook.CASH_FEED_FAILED.selector);
        hook.build(address(prevHook), account, data);
        assertEq(
            hook.previewTradable(data, account), uint256(uint8(GyldBondYieldSourceOracle.NavFailure.CASH_FEED_FAILED))
        );
    }

    function test_Refuses_SequencerDown() public {
        vm.startPrank(admin);
        registry.proposeDeregisterInstrument(address(bond));
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        registry.executeDeregisterInstrument(address(bond));
        GyldBondRegistry.InstrumentConfig memory cfg = _baseCfg();
        cfg.sequencerUptimeFeed = address(new MockDownSequencer());
        registry.registerInstrument(cfg);
        vm.stopPrank();

        bytes memory data = _data();
        vm.expectRevert(GyldTradeGuardHook.SEQUENCER_DOWN.selector);
        hook.build(address(prevHook), account, data);
        assertEq(
            hook.previewTradable(data, account),
            uint256(uint8(GyldBondYieldSourceOracle.NavFailure.SEQUENCER_DOWN_CODE))
        );
    }

    /*//////////////////////////////////////////////////////////////
                        THE AUTHORITATIVE RE-CHECK
    //////////////////////////////////////////////////////////////*/

    /// @dev Checked twice on purpose. `build()` observes state before the batch runs; `_postExecute` observes
    ///      it from inside the batch, after every preceding hook executed. A suspension landing between the
    ///      two must still stop the leaf.
    function test_PostExecute_RefusesASuspensionThatLandedAfterBuild() public {
        bytes memory data = _data();
        hook.build(address(prevHook), account, data); // passes
        hook.setExecutionContext(account);
        hook.preExecute(address(prevHook), account, data);

        _suspend(true); // the incident switch flips mid-batch

        vm.expectRevert(GyldTradeGuardHook.NAV_SUSPENDED.selector);
        hook.postExecute(address(prevHook), account, data);
    }

    function test_PostExecute_HealthyInstrumentPasses() public {
        bytes memory data = _data();
        hook.setExecutionContext(account);
        hook.preExecute(address(prevHook), account, data);
        hook.postExecute(address(prevHook), account, data);
    }

    function test_PostExecute_RevertIf_CallerIsNotTheAccount() public {
        bytes memory data = _data();
        vm.expectRevert(BaseHook.UNAUTHORIZED_CALLER.selector);
        vm.prank(address(0xBAD));
        hook.postExecute(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                           PREVIEW AND IDENTITY
    //////////////////////////////////////////////////////////////*/

    function test_PreviewTradable_HealthyReturnsZero() public view {
        assertEq(hook.previewTradable(_data(), account), 0);
    }

    function test_PreviewTradable_RevertIf_MalformedData() public {
        // Decoding is shared with `build`, so a malformed leaf is rejected the same way in the preview.
        vm.expectRevert(GyldTradeGuardHook.INVALID_DATA_LENGTH.selector);
        hook.previewTradable(new bytes(10), account);
    }

    /// @dev REGRESSION for the panic only. A feed can report a timestamp in the FUTURE. An unguarded
    ///      `block.timestamp - publishedAt` would panic, and `previewTradable` is specified never to revert,
    ///      so the OMS would lose its pre-flight on exactly the malformed feed it most needs to detect.
    ///      THE STRICT PATH DOES NOT REFUSE IT. A future-dated publication suspends the staleness check
    ///      entirely, which is open finding A2; that is reproduced under
    ///      `GyldBondReviewFindingsTest.test_Finding_P1_3_*`. This test asserts ONLY that the preview stays
    ///      total, and deliberately makes no claim about whether the trade should proceed.
    function test_PreviewTradable_FutureDatedPublication_DoesNotPanic() public {
        navFeed.setUpdatedAt(block.timestamp + 1 days);
        // Now REJECTED by name rather than treated as fresh, and still without panicking.
        assertEq(
            hook.previewTradable(_data(), account),
            uint256(uint8(GyldBondYieldSourceOracle.NavFailure.INVALID_TIMESTAMP)),
            "a future stamp is invalid, not fresh"
        );
        vm.expectRevert(GyldTradeGuardHook.INVALID_TIMESTAMP.selector);
        hook.build(address(prevHook), account, _data());
    }

    /// @dev Same for the observation clock, on a feed that can express one.
    function test_PreviewTradable_FutureDatedObservation_DoesNotPanic() public {
        _reRegisterNative(false);
        nativeFeed.setNav(address(bond), 1.05e8, block.timestamp + 1 days, block.timestamp);
        // The oracle already calls a future valuation unusable, so the preview reports that, not a panic.
        assertEq(
            hook.previewTradable(_data(), account),
            uint256(uint8(GyldBondYieldSourceOracle.NavFailure.INVALID_TIMESTAMP))
        );
        vm.expectRevert(GyldTradeGuardHook.INVALID_TIMESTAMP.selector);
        hook.build(address(prevHook), account, _data());
    }

    /// @dev The bounds are committed too: a proof issued for a tight bound cannot be presented with a loose one.
    function test_Inspect_CommitsTokensAndBothBounds() public view {
        assertEq(hook.inspect(_data()), abi.encodePacked(address(bond), address(cash), LEAF_OBS_AGE, LEAF_PUB_AGE));
        assertEq(hook.inspect(_data()).length, 104);
    }

    function test_Inspect_RevertIf_MalformedData() public {
        vm.expectRevert(GyldTradeGuardHook.INVALID_DATA_LENGTH.selector);
        hook.inspect(new bytes(10));
    }

    function test_Sizeless_NoAmountsAndNoRoles() public view {
        assertEq(hook.decodeAmounts(_data()).length, 0);
        assertEq(hook.amountRoles(_data()).length, 0);
    }

    /// @dev Declares the S2 sizing interface and explicitly NOT the outflow one: nothing here is resizable.
    function test_SupportsInterface() public view {
        assertTrue(hook.supportsInterface(type(ISuperHookInflowOutflow).interfaceId));
        assertFalse(hook.supportsInterface(type(ISuperHookOutflow).interfaceId));
        assertTrue(hook.supportsInterface(type(ISuperHookInspector).interfaceId));
        assertTrue(hook.supportsInterface(type(ISuperHook).interfaceId));
        assertTrue(hook.supportsInterface(type(ISuperHookResult).interfaceId));
        assertTrue(hook.supportsInterface(type(IERC165).interfaceId));
        assertFalse(hook.supportsInterface(bytes4(0xdeadbeef)));
    }

    /*//////////////////////////////////////////////////////////////
                                 FUZZ
    //////////////////////////////////////////////////////////////*/

    /// @dev Any leaf bound tighter than the feed's actual age must refuse, and any looser one must pass.
    function testFuzz_LeafBoundIsAuthoritative(uint256 feedAge, uint256 leafBound) public {
        feedAge = bound(feedAge, 0, REG_PUB_AGE);
        leafBound = bound(leafBound, 1, 30 days);
        navFeed.setUpdatedAt(block.timestamp - feedAge);

        bytes memory data = _data(address(bond), address(cash), 30 days, leafBound);
        if (feedAge > leafBound) {
            vm.expectRevert(GyldTradeGuardHook.NAV_PUBLICATION_STALE.selector);
            hook.build(address(prevHook), account, data);
        } else {
            assertEq(hook.previewTradable(data, account), 0);
            hook.build(address(prevHook), account, data);
        }
    }

    /// @dev `previewTradable` never reverts for a well-formed leaf, whatever the instrument's state.
    function testFuzz_PreviewNeverRevertsForAWellFormedLeaf(bool suspended, int256 answer, int256 skew) public {
        skew = bound(skew, -60 days, 60 days); // both clocks, including timestamps in the FUTURE
        navFeed.setLatestAnswer(answer);
        navFeed.setUpdatedAt(uint256(int256(block.timestamp) + skew));
        if (suspended) _suspend(true);
        hook.previewTradable(_data(), account);
    }
}

/// @dev A sequencer uptime feed reporting "down"
contract MockDownSequencer {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (1, 1, block.timestamp, block.timestamp, 1);
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }
}
