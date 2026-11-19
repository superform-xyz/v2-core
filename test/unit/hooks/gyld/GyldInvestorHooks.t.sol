// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { GyldInvestorDepositHook } from "../../../../src/hooks/gyld/GyldInvestorDepositHook.sol";
import { GyldInvestorRedeemHook } from "../../../../src/hooks/gyld/GyldInvestorRedeemHook.sol";
import { GyldInvestorTransferBase } from "../../../../src/hooks/gyld/GyldInvestorTransferBase.sol";
import { GyldInTransitRegistry } from "../../../../src/accounting/oracles/GyldInTransitRegistry.sol";
import { GyldBondRegistry } from "../../../../src/accounting/oracles/GyldBondRegistry.sol";
import { GyldBondYieldSourceOracle } from "../../../../src/accounting/oracles/GyldBondYieldSourceOracle.sol";
import { GyldTradePolicy } from "../../../../src/accounting/oracles/GyldTradePolicy.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { HookSubTypes } from "../../../../src/libraries/HookSubTypes.sol";
import { ISuperHook, ISuperHookInflowOutflow, ISuperHookOutflow } from "../../../../src/interfaces/ISuperHook.sol";

import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockAggregator } from "../../../mocks/MockAggregator.sol";
import { MockSuperVaultStrategyState } from "../../../mocks/gyld/MockSuperVaultStrategyState.sol";

/// @dev Minimal predecessor: settable outAmount AND outToken (the repo's MockHook returns address(0) for the token).
contract PrevHookStub {
    uint256 internal amount;
    address internal token;

    function set(uint256 amount_, address token_) external {
        amount = amount_;
        token = token_;
    }

    function getOutAmount(address) external view returns (uint256) {
        return amount;
    }

    function getOutToken(address) external view returns (address) {
        return token;
    }
}

/// @dev Takes a 1% cut on every transfer, to prove both delta checks fail closed.
contract FeeOnTransferERC20 is MockERC20 {
    constructor() MockERC20("Fee", "FEE", 6) { }

    function transfer(address to, uint256 amount) public override returns (bool) {
        uint256 fee = amount / 100;
        _burn(msg.sender, fee);
        return super.transfer(to, amount - fee);
    }
}

/// @title GyldInvestorHooksTest
/// @notice Unit coverage for the two Investor API hooks over a real registry, oracle, policy and in-transit
///         registry: the 125-byte layout, pinned destinations, the same named errors in `build()` as on chain,
///         the exact-delta post checks, the zero `outAmount`, and the sizing surface.
contract GyldInvestorHooksTest is Test {
    GyldInvestorDepositHook internal depositHook;
    GyldInvestorRedeemHook internal redeemHook;
    GyldInTransitRegistry internal transit;
    GyldBondRegistry internal registry;
    GyldBondYieldSourceOracle internal oracle;
    GyldTradePolicy internal policy;
    MockSuperVaultStrategyState internal aggregator;
    PrevHookStub internal prevHook;

    MockERC20 internal bond;
    MockERC20 internal cash;
    MockAggregator internal navFeed;

    address internal account;
    address internal admin = address(0xA11CE);
    address internal deposit = address(0xDE90);
    address internal holding = address(0x401D);

    uint256 internal constant AMOUNT = 1000e6;
    uint256 internal constant SHARES = 100e18;
    uint256 internal constant CAP = 5000e6;
    uint256 internal constant AGE = 14 days;

    function setUp() public {
        account = address(this);
        vm.warp(1_800_000_000);

        bond = new MockERC20("Gyld Bond", "GBOND", 18);
        cash = new MockERC20("USD Coin", "USDC", 6);
        navFeed = new MockAggregator(8);
        navFeed.setLatestAnswer(1.05e8);

        registry = new GyldBondRegistry(admin);
        transit = new GyldInTransitRegistry(admin, address(registry));
        oracle = new GyldBondYieldSourceOracle(address(0xC0FFEE), address(registry), address(transit));
        aggregator = new MockSuperVaultStrategyState();
        policy = new GyldTradePolicy(address(registry), address(oracle), address(aggregator));
        aggregator.register(account);
        vm.prank(admin);
        registry.setMaxPpsAge(1 days);

        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = address(bond);
        cfg.navFeed = address(navFeed);
        cfg.cashToken = address(cash);
        cfg.maxObservationAge = 7 days;
        cfg.maxPublicationAge = 7 days;
        cfg.maxEntryPremiumBps = 200;
        cfg.maxExitDiscountBps = 200;
        vm.prank(admin);
        registry.registerInstrument(cfg);

        vm.startPrank(admin);
        transit.setDestinations(account, deposit, holding);
        transit.setMaxTransitAge(AGE);
        transit.setMaxCashInTransit(address(bond), CAP);
        transit.setMaxTotalCashInTransit(address(bond), 4 * CAP);
        transit.setValuationOracle(address(oracle));
        vm.stopPrank();

        depositHook = new GyldInvestorDepositHook(address(transit), address(policy));
        redeemHook = new GyldInvestorRedeemHook(address(transit));
        prevHook = new PrevHookStub();
        prevHook.set(0, address(cash));

        cash.mint(account, 10_000e6);
        bond.mint(account, 1000e18);
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _data(address ys, address ct, uint256 amount, bool usePrev) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(0), bytes20(address(0)), bytes20(ys), bytes20(ct), amount, usePrev);
    }

    function _dep(uint256 amount) internal view returns (bytes memory) {
        return _data(address(bond), address(cash), amount, false);
    }

    function _red(uint256 shares) internal view returns (bytes memory) {
        return _data(address(bond), address(cash), shares, false);
    }

    /// @dev Runs pre, the hook executions, post, exactly as the account would.
    function _run(BaseHook hook, bytes memory data) internal {
        Execution[] memory ex = hook.build(address(prevHook), account, data);
        for (uint256 i; i < ex.length; ++i) {
            (bool ok, bytes memory ret) = ex[i].target.call{ value: ex[i].value }(ex[i].callData);
            if (!ok) {
                assembly ("memory-safe") {
                    revert(add(ret, 0x20), mload(ret))
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTION
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public view {
        assertEq(address(depositHook.IN_TRANSIT()), address(transit));
        assertEq(address(depositHook.POLICY()), address(policy));
        assertEq(address(redeemHook.IN_TRANSIT()), address(transit));
        assertEq(uint256(depositHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(redeemHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(depositHook.SUB_TYPE(), HookSubTypes.MISC);
        assertEq(redeemHook.SUB_TYPE(), HookSubTypes.MISC);
        assertEq(depositHook.name(), "Gyld Investor Deposit");
        assertEq(redeemHook.name(), "Gyld Investor Redeem");
    }

    function test_Constructor_RevertZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new GyldInvestorDepositHook(address(0), address(policy));
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new GyldInvestorDepositHook(address(transit), address(0));
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new GyldInvestorRedeemHook(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                             LAYOUT / DECODE
    //////////////////////////////////////////////////////////////*/

    function test_Build_ExactLength() public {
        bytes memory d = _dep(AMOUNT);
        vm.expectRevert(abi.encodeWithSelector(GyldInvestorTransferBase.INVALID_DATA_LENGTH.selector, 124, 125));
        depositHook.build(address(0), account, _slice(d, 124));
        vm.expectRevert(abi.encodeWithSelector(GyldInvestorTransferBase.INVALID_DATA_LENGTH.selector, 126, 125));
        redeemHook.build(address(0), account, bytes.concat(d, hex"00"));
    }

    function test_Build_RejectsZeroOrIdenticalTokens_AndZeroAmount() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        depositHook.build(address(0), account, _data(address(0), address(cash), AMOUNT, false));
        vm.expectRevert(GyldInvestorTransferBase.IDENTICAL_TOKENS.selector);
        redeemHook.build(address(0), account, _data(address(bond), address(bond), SHARES, false));
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        depositHook.build(address(0), account, _dep(0));
    }

    function test_Build_Executions_UsePinnedDestinations() public view {
        Execution[] memory ex = depositHook.build(address(0), account, _dep(AMOUNT));
        assertEq(ex.length, 4, "pre, transfer, record, post");
        assertEq(ex[1].target, address(cash));
        assertEq(ex[1].callData, abi.encodeCall(IERC20.transfer, (deposit, AMOUNT)));
        assertEq(ex[2].target, address(transit));
        assertEq(
            ex[2].callData, abi.encodeCall(GyldInTransitRegistry.recordCashOut, (address(bond), address(cash), AMOUNT))
        );

        ex = redeemHook.build(address(0), account, _red(SHARES));
        assertEq(ex.length, 4);
        assertEq(ex[1].target, address(bond));
        assertEq(ex[1].callData, abi.encodeCall(IERC20.transfer, (holding, SHARES)));
        assertEq(
            ex[2].callData, abi.encodeCall(GyldInTransitRegistry.recordBondsOut, (address(bond), address(cash), SHARES))
        );
    }

    function test_Build_UsePrevHookAmount_And_PrevTokenMismatch() public {
        prevHook.set(AMOUNT / 2, address(cash));
        Execution[] memory ex =
            depositHook.build(address(prevHook), account, _data(address(bond), address(cash), 1, true));
        assertEq(ex[1].callData, abi.encodeCall(IERC20.transfer, (deposit, AMOUNT / 2)));
        // the redeem hook moves the BOND; a cash-denominated predecessor is a mismatch
        vm.expectRevert(GyldInvestorTransferBase.PREV_TOKEN_MISMATCH.selector);
        redeemHook.build(address(prevHook), account, _data(address(bond), address(cash), 1, true));
        prevHook.set(SHARES / 4, address(bond));
        ex = redeemHook.build(address(prevHook), account, _data(address(bond), address(cash), 1, true));
        assertEq(ex[1].callData, abi.encodeCall(IERC20.transfer, (holding, SHARES / 4)));
        // a zero predecessor output is refused (the terminal-hook rule relies on it)
        prevHook.set(0, address(cash));
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        depositHook.build(address(prevHook), account, _data(address(bond), address(cash), 1, true));
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        depositHook.build(address(0), account, _data(address(bond), address(cash), 1, true));
    }

    function test_Build_RefusesWhatTheRegistryWouldRefuse() public {
        // unapproved pair
        MockERC20 other = new MockERC20("O", "O", 6);
        vm.expectRevert(GyldInTransitRegistry.PAIR_NOT_APPROVED.selector);
        depositHook.build(address(0), account, _data(address(bond), address(other), AMOUNT, false));
        vm.expectRevert(GyldInTransitRegistry.PAIR_NOT_APPROVED.selector);
        redeemHook.build(address(0), account, _data(address(bond), address(other), SHARES, false));
        // cap
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.CAP_EXCEEDED.selector, CAP + 1, CAP));
        depositHook.build(address(0), account, _dep(CAP + 1));
        assertEq(depositHook.previewDeposit(_dep(CAP + 1), account), 205);
        assertEq(depositHook.previewDeposit(_dep(CAP), account), 0);
        assertEq(redeemHook.previewRedeem(_red(SHARES), account), 0);
        // stale transit blocks a new deposit, never a redeem
        _run(depositHook, _dep(AMOUNT));
        vm.warp(block.timestamp + AGE + 1);
        navFeed.setLatestAnswer(1.05e8);
        aggregator.setLastUpdate(account, block.timestamp);
        vm.expectRevert(GyldInTransitRegistry.TRANSIT_STALE.selector);
        depositHook.build(address(0), account, _dep(1));
        assertEq(depositHook.previewDeposit(_dep(1), account), 204);
        redeemHook.build(address(0), account, _red(SHARES));
    }

    function test_Build_RefusesMissingDestination() public {
        GyldInTransitRegistry bare = new GyldInTransitRegistry(admin, address(registry));
        GyldInvestorDepositHook d = new GyldInvestorDepositHook(address(bare), address(policy));
        GyldInvestorRedeemHook r = new GyldInvestorRedeemHook(address(bare));
        vm.expectRevert(GyldInvestorTransferBase.DESTINATION_NOT_SET.selector);
        d.build(address(0), account, _dep(AMOUNT));
        vm.expectRevert(GyldInvestorTransferBase.DESTINATION_NOT_SET.selector);
        r.build(address(0), account, _red(SHARES));
    }

    /// @dev Destinations are per strategy: on the SAME registry, a strategy without its own pair is refused by
    ///      both hooks while a configured one is served, and the configured pair is the one the hook moves to.
    function test_Build_DestinationIsTheAccountsOwn() public {
        address otherStrategy = address(0x5EC0);
        aggregator.register(otherStrategy);
        vm.expectRevert(GyldInvestorTransferBase.DESTINATION_NOT_SET.selector);
        depositHook.build(address(0), otherStrategy, _dep(AMOUNT));
        vm.expectRevert(GyldInvestorTransferBase.DESTINATION_NOT_SET.selector);
        redeemHook.build(address(0), otherStrategy, _red(SHARES));
        assertEq(depositHook.previewDeposit(_dep(AMOUNT), otherStrategy), 202);
        assertEq(redeemHook.previewRedeem(_red(SHARES), otherStrategy), 302);

        vm.prank(admin);
        transit.setDestinations(otherStrategy, address(0xD2), address(0x42));
        Execution[] memory ex = depositHook.build(address(0), otherStrategy, _dep(AMOUNT));
        assertEq(ex[1].callData, abi.encodeCall(IERC20.transfer, (address(0xD2), AMOUNT)), "other's own address");
        ex = redeemHook.build(address(0), otherStrategy, _red(SHARES));
        assertEq(ex[1].callData, abi.encodeCall(IERC20.transfer, (address(0x42), SHARES)));
        ex = depositHook.build(address(0), account, _dep(AMOUNT));
        assertEq(ex[1].callData, abi.encodeCall(IERC20.transfer, (deposit, AMOUNT)), "ours is unchanged");
    }

    /*//////////////////////////////////////////////////////////////
                              FULL LEG
    //////////////////////////////////////////////////////////////*/

    function test_Deposit_FullLeg_MovesCash_RecordsTransit_ZeroOut() public {
        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(address(bond), account);
        _run(depositHook, _dep(AMOUNT));
        assertEq(cash.balanceOf(deposit), AMOUNT);
        assertEq(cash.balanceOf(account), 10_000e6 - AMOUNT);
        assertEq(transit.cashOut(account, address(bond)), AMOUNT);
        assertEq(depositHook.getOutAmount(account), 0, "terminal: fails closed downstream");
        assertEq(depositHook.getOutToken(account), address(cash));
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), account), tvlBefore + AMOUNT, "valued at face");
    }

    function test_Redeem_FullLeg_MovesBonds_RecordsBondsOut_ZeroOut() public {
        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(address(bond), account);
        _run(redeemHook, _red(SHARES));
        assertEq(bond.balanceOf(holding), SHARES);
        GyldInTransitRegistry.Transit memory t = transit.transit(account, address(bond));
        assertEq(t.bondsOut, SHARES);
        assertEq(redeemHook.getOutAmount(account), 0);
        assertEq(redeemHook.getOutToken(account), address(bond));
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), account), tvlBefore, "TVL unchanged by the exit");
    }

    function test_Redeem_SuspensionDoesNotBlock_DepositDoes() public {
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);
        vm.expectRevert(GyldTradePolicy.NAV_SUSPENDED.selector);
        depositHook.preExecute(address(0), account, _dep(AMOUNT));
        _run(redeemHook, _red(SHARES));
        assertEq(transit.transit(account, address(bond)).bondsOut, SHARES, "recorded without a usable NAV");
    }

    function test_Deposit_PolicyGates_RecoveryMark_PausedStrategy() public {
        vm.startPrank(admin);
        registry.proposeRecoveryNav(address(bond), 1e6);
        vm.warp(block.timestamp + 2 days);
        registry.executeRecoveryNav(address(bond));
        vm.stopPrank();
        aggregator.setLastUpdate(account, block.timestamp);
        navFeed.setLatestAnswer(1.05e8);
        vm.expectRevert(GyldTradePolicy.RECOVERY_MARK_SET.selector);
        depositHook.preExecute(address(0), account, _dep(AMOUNT));
        vm.startPrank(admin);
        registry.proposeClearRecoveryNav(address(bond));
        vm.warp(block.timestamp + 2 days);
        registry.executeClearRecoveryNav(address(bond));
        vm.stopPrank();
        navFeed.setLatestAnswer(1.05e8);
        aggregator.setLastUpdate(account, block.timestamp);
        aggregator.setPaused(account, true);
        vm.expectRevert(GyldTradePolicy.STRATEGY_PAUSED.selector);
        depositHook.preExecute(address(0), account, _dep(AMOUNT));
        aggregator.setPaused(account, false);
        _run(depositHook, _dep(AMOUNT));
    }

    /*//////////////////////////////////////////////////////////////
                           POST-EXECUTE CHECKS
    //////////////////////////////////////////////////////////////*/

    function test_Post_InputNotSpent() public {
        bytes memory d = _dep(AMOUNT);
        depositHook.preExecute(address(0), account, d);
        // nothing moved
        vm.expectRevert(abi.encodeWithSelector(GyldInvestorTransferBase.INPUT_NOT_SPENT.selector, AMOUNT, 0));
        depositHook.postExecute(address(0), account, d);
    }

    function test_Post_DestinationNotCredited_FeeOnTransfer() public {
        FeeOnTransferERC20 fee = new FeeOnTransferERC20();
        MockERC20 bond2 = new MockERC20("B2", "B2", 18);
        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = address(bond2);
        cfg.navFeed = address(navFeed);
        cfg.cashToken = address(fee);
        cfg.maxObservationAge = 7 days;
        cfg.maxPublicationAge = 7 days;
        cfg.maxEntryPremiumBps = 200;
        cfg.maxExitDiscountBps = 200;
        vm.startPrank(admin);
        registry.registerInstrument(cfg);
        transit.setMaxCashInTransit(address(bond2), CAP);
        transit.setMaxTotalCashInTransit(address(bond2), CAP);
        vm.stopPrank();
        fee.mint(account, AMOUNT);
        bytes memory d = _data(address(bond2), address(fee), AMOUNT, false);
        Execution[] memory ex = depositHook.build(address(0), account, d);
        for (uint256 i; i < 3; ++i) {
            (bool ok,) = ex[i].target.call(ex[i].callData);
            assertTrue(ok, "pre, transfer, record succeed");
        }
        // the spend side is exact (amount burned + sent), the credit side is short by the fee
        vm.expectRevert(
            abi.encodeWithSelector(
                GyldInvestorTransferBase.DESTINATION_NOT_CREDITED.selector, AMOUNT, AMOUNT - AMOUNT / 100
            )
        );
        depositHook.postExecute(address(0), account, d);
    }

    function test_Post_OnlyAccountMayCall() public {
        bytes memory d = _dep(AMOUNT);
        vm.prank(address(0xBAD));
        vm.expectRevert(BaseHook.UNAUTHORIZED_CALLER.selector);
        depositHook.postExecute(address(0), account, d);
    }

    /*//////////////////////////////////////////////////////////////
                                 SIZING
    //////////////////////////////////////////////////////////////*/

    function test_Sizing_Surface() public view {
        bytes memory d = _dep(AMOUNT);
        assertEq(depositHook.decodeAmounts(d)[0], AMOUNT);
        assertEq(redeemHook.decodeAmounts(_red(SHARES))[0], SHARES);
        assertTrue(depositHook.decodeUsePrevHookAmount(_data(address(bond), address(cash), 1, true)));
        assertFalse(depositHook.decodeUsePrevHookAmount(d));
        ISuperHookInflowOutflow.AmountMeta[] memory m = redeemHook.amountRoles("");
        assertEq(m.length, 1);
        assertEq(uint256(m[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(m[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));
        uint256[] memory a = new uint256[](1);
        a[0] = 7;
        bytes memory out = depositHook.replaceCalldataAmounts(d, a);
        assertEq(depositHook.decodeAmounts(out)[0], 7);
        assertEq(out.length, 125);
        assertEq(depositHook.inspect(d), abi.encodePacked(address(bond), address(cash)));
        assertTrue(depositHook.supportsInterface(type(ISuperHookInflowOutflow).interfaceId));
        assertTrue(depositHook.supportsInterface(type(ISuperHookOutflow).interfaceId));
        assertTrue(redeemHook.supportsInterface(type(ISuperHookOutflow).interfaceId));
    }

    function test_Sizing_ReplaceRejectsWrongLength() public {
        uint256[] memory a = new uint256[](2);
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        depositHook.replaceCalldataAmounts(_dep(AMOUNT), a);
    }

    function _slice(bytes memory d, uint256 n) internal pure returns (bytes memory out) {
        out = new bytes(n);
        for (uint256 i; i < n; ++i) {
            out[i] = d[i];
        }
    }

    /*//////////////////////////////////////////////////////////////
                       MORE: PREV AMOUNT, LOTS, ROTATION
    //////////////////////////////////////////////////////////////*/

    /// @dev Full legs sized from a predecessor: the lot opens for the predecessor's amount, not the calldata word.
    function test_FullLeg_UsePrevHookAmount_BothHooks() public {
        prevHook.set(AMOUNT / 4, address(cash));
        _run(depositHook, _data(address(bond), address(cash), 999, true));
        assertEq(transit.getLot(1).open, AMOUNT / 4, "deposit lot = predecessor amount");
        assertEq(cash.balanceOf(deposit), AMOUNT / 4);
        prevHook.set(SHARES / 5, address(bond));
        _run(redeemHook, _data(address(bond), address(cash), 999, true));
        assertEq(transit.getLot(2).open, SHARES / 5, "redeem lot = predecessor amount");
        assertEq(bond.balanceOf(holding), SHARES / 5);
        prevHook.set(0, address(cash));
    }

    /// @dev A run emits the lot id and the lot remembers the pinned destination it was sent to.
    function test_FullLeg_EmitsLotId_And_LotKeepsDestination() public {
        vm.recordLogs();
        _run(depositHook, _dep(AMOUNT));
        _run(redeemHook, _red(SHARES));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 cashSig = keccak256("CashOutRecorded(address,address,uint256,address,uint256,uint256)");
        bytes32 bondSig = keccak256("BondsOutRecorded(address,address,uint256,address,uint256,uint256)");
        uint256 seen;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(transit)) continue;
            if (logs[i].topics[0] == cashSig) {
                assertEq(address(uint160(uint256(logs[i].topics[1]))), account);
                assertEq(uint256(logs[i].topics[3]), 1, "first lot id");
                (address ct, uint256 amt, uint256 newOut) = abi.decode(logs[i].data, (address, uint256, uint256));
                assertEq(ct, address(cash));
                assertEq(amt, AMOUNT);
                assertEq(newOut, AMOUNT);
                ++seen;
            } else if (logs[i].topics[0] == bondSig) {
                assertEq(uint256(logs[i].topics[3]), 2, "second lot id");
                (, uint256 sh,) = abi.decode(logs[i].data, (address, uint256, uint256));
                assertEq(sh, SHARES);
                ++seen;
            }
        }
        assertEq(seen, 2, "both records emitted with their lot ids");
        assertEq(transit.getLot(1).destination, deposit);
        assertEq(transit.getLot(2).destination, holding);
        assertEq(transit.getLot(1).account, account);
        assertEq(uint256(transit.getLot(2).kind), uint256(GyldInTransitRegistry.LotKind.BONDS_OUT));
    }

    /// @dev The cap binds across runs and only a settle frees it; a redeem is never gated by it.
    function test_FullLeg_CapAcrossRuns_FreedBySettleOnly() public {
        _run(depositHook, _dep(CAP));
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.CAP_EXCEEDED.selector, CAP + 1, CAP));
        depositHook.build(address(0), account, _dep(1));
        assertEq(depositHook.previewDeposit(_dep(1), account), 205);
        _run(redeemHook, _red(SHARES)); // exits are never capped
        cash.mint(address(transit.receiverOf(account)), CAP / 2); // the cancelled half came back, to the receiver
        vm.prank(admin);
        transit.settleCashReturn(1, CAP / 2, bytes32("half back"));
        depositHook.build(address(0), account, _dep(CAP / 2));
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.CAP_EXCEEDED.selector, CAP + 1, CAP));
        depositHook.build(address(0), account, _dep(CAP / 2 + 1));
    }

    /// @dev Two strategies through the same hooks: separate pairs, separate lots, separate aggregates.
    function test_FullLeg_TwoStrategies_SeparateBooks() public {
        address otherStrategy = address(0x5EC0);
        aggregator.register(otherStrategy);
        vm.prank(admin);
        transit.setDestinations(otherStrategy, address(0xD2), address(0x42));
        cash.mint(otherStrategy, 10_000e6);
        bond.mint(otherStrategy, 1000e18);
        _run(depositHook, _dep(AMOUNT));
        // run the other strategy's leg as that strategy (build already includes pre and post); the executor opens
        // a fresh execution context per hook run, so do the same here
        Execution[] memory ex = depositHook.build(address(0), otherStrategy, _dep(AMOUNT * 2));
        depositHook.setExecutionContext(otherStrategy);
        vm.startPrank(otherStrategy);
        for (uint256 i; i < ex.length; ++i) {
            (bool ok,) = ex[i].target.call(ex[i].callData);
            assertTrue(ok, "every leg of the other strategy's plan runs");
        }
        vm.stopPrank();
        assertEq(cash.balanceOf(deposit), AMOUNT, "ours went to our pair");
        assertEq(cash.balanceOf(address(0xD2)), AMOUNT * 2, "theirs went to their pair");
        assertEq(transit.cashOut(account, address(bond)), AMOUNT);
        assertEq(transit.cashOut(otherStrategy, address(bond)), AMOUNT * 2);
        assertEq(transit.getLot(1).account, account);
        assertEq(transit.getLot(2).account, otherStrategy);
        assertEq(transit.getLot(2).destination, address(0xD2));
        assertEq(transit.totalCashInTransit(address(bond)), AMOUNT * 3);
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), account), 1000e18 * 1.05e6 / 1e18 + AMOUNT);
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), otherStrategy), 1000e18 * 1.05e6 / 1e18 + AMOUNT * 2);
    }

    /// @dev inspect() pins exactly the pair: same pair -> same bytes regardless of amount; other cash -> different.
    function test_Inspect_PinsThePair_Only() public view {
        bytes memory a = depositHook.inspect(_dep(1));
        bytes memory b = depositHook.inspect(_dep(type(uint128).max));
        bytes memory c = redeemHook.inspect(_red(1));
        assertEq(keccak256(a), keccak256(b), "amount is not part of the leaf identity");
        assertEq(keccak256(a), keccak256(c), "both hooks pin the same (bond, cash) identity");
        assertEq(a, abi.encodePacked(address(bond), address(cash)));
        bytes memory d = depositHook.inspect(_data(address(bond), address(0xCA54), 1, false));
        assertTrue(keccak256(a) != keccak256(d), "a different cash token is a different leaf");
    }

    /// @dev A destination rotation that lands between build and execution fails closed: the transfer built
    ///      against the old pair does not credit the new destination, so _postExecute reverts.
    function test_Rotation_BetweenBuildAndExecute_FailsClosed() public {
        Execution[] memory ex = depositHook.build(address(prevHook), account, _dep(AMOUNT));
        vm.startPrank(admin);
        transit.proposeDestinations(account, address(0xD2), address(0x42));
        vm.warp(block.timestamp + transit.DESTINATION_DELAY());
        transit.executeDestinations(account);
        vm.stopPrank();
        navFeed.setLatestAnswer(1.05e8);
        aggregator.setLastUpdate(account, block.timestamp);
        // the stale plan is [pre, transfer to the OLD address, record, post]: pre snapshots the NEW destination,
        // the transfer pays the old one, so post sees the new destination uncredited and reverts
        assertEq(ex.length, 4);
        for (uint256 i; i < 3; ++i) {
            (bool ok,) = ex[i].target.call{ value: ex[i].value }(ex[i].callData);
            assertTrue(ok);
        }
        (bool postOk, bytes memory ret) = ex[3].target.call(ex[3].callData);
        assertFalse(postOk, "post fails closed");
        assertEq(ret, abi.encodeWithSelector(GyldInvestorTransferBase.DESTINATION_NOT_CREDITED.selector, AMOUNT, 0));
        // a fresh build targets the new pair
        ex = depositHook.build(address(prevHook), account, _dep(AMOUNT));
        assertEq(ex[1].callData, abi.encodeCall(IERC20.transfer, (address(0xD2), AMOUNT)));
    }

    /// @dev The instrument-wide cap through the hook: a second strategy with per-strategy headroom is refused at
    ///      build once the instrument is full, with its own preview code; exits stay open.
    function test_FullLeg_GlobalCap_AcrossStrategies() public {
        address otherStrategy = address(0x5EC0);
        aggregator.register(otherStrategy);
        vm.startPrank(admin);
        transit.setDestinations(otherStrategy, address(0xD2), address(0x42));
        transit.setMaxTotalCashInTransit(address(bond), CAP + CAP / 2);
        vm.stopPrank();
        cash.mint(otherStrategy, 10_000e6);
        bond.mint(otherStrategy, 1000e18);
        _run(depositHook, _dep(CAP)); // ours fills its own cap
        assertEq(depositHook.previewDeposit(_dep(CAP / 2), otherStrategy), 0, "its own headroom, instrument not full");
        assertEq(depositHook.previewDeposit(_dep(CAP / 2 + 1), otherStrategy), 207, "instrument full");
        vm.expectRevert(
            abi.encodeWithSelector(GyldInTransitRegistry.GLOBAL_CAP_EXCEEDED.selector, CAP + CAP / 2 + 1, CAP + CAP / 2)
        );
        depositHook.build(address(0), otherStrategy, _dep(CAP / 2 + 1));
        depositHook.build(address(0), otherStrategy, _dep(CAP / 2));
        redeemHook.build(address(0), otherStrategy, _red(SHARES)); // never capped
        // a settle on OUR lot frees the instrument for THEM (NAV 1.05: 960 bonds = 1008 of value for 1000 of cash)
        bond.mint(address(transit.receiverOf(account)), 960e18);
        vm.prank(admin);
        transit.settleMint(1, 1000e6, 960e18, bytes32("m"));
        assertEq(depositHook.previewDeposit(_dep(CAP / 2 + 1), otherStrategy), 0);
    }

    /// @dev Preview codes for what cannot be previewed: an amount that comes from the previous hook (208 / 308) and
    ///      zero shares (304), each only after the other gates passed.
    function test_Preview_UnresolvableAmounts_HaveTheirOwnCodes() public {
        bytes memory dep = _data(address(bond), address(cash), 0, true);
        assertEq(depositHook.previewDeposit(dep, account), 208, "usePrevHookAmount: amount known at execution");
        bytes memory red = _data(address(bond), address(cash), 0, true);
        assertEq(redeemHook.previewRedeem(red, account), 308);
        assertEq(redeemHook.previewRedeem(_red(0), account), 304, "zero shares: build reverts");
        // gates still come first (policy, then the registry's)
        address stranger = address(0x5717);
        assertTrue(depositHook.previewDeposit(dep, stranger) != 0, "policy refuses an unknown strategy");
        aggregator.register(stranger);
        assertEq(depositHook.previewDeposit(dep, stranger), 202);
        assertEq(redeemHook.previewRedeem(red, stranger), 302);
    }
}
