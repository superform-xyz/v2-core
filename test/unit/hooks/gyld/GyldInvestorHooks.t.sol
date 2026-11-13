// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

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
        transit.setDestinations(deposit, holding);
        transit.setMaxTransitAge(AGE);
        transit.setMaxCashInTransit(address(bond), CAP);
        vm.stopPrank();

        depositHook = new GyldInvestorDepositHook(address(transit), address(policy));
        redeemHook = new GyldInvestorRedeemHook(address(transit), address(oracle));
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
        assertEq(address(redeemHook.GYLD_ORACLE()), address(oracle));
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
        new GyldInvestorRedeemHook(address(transit), address(0));
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
            ex[2].callData,
            abi.encodeCall(GyldInTransitRegistry.recordBondsOut, (address(bond), address(cash), SHARES, 1.05e6))
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
        assertEq(redeemHook.previewRedeem(_red(SHARES)), 0);
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
        GyldInvestorRedeemHook r = new GyldInvestorRedeemHook(address(bare), address(oracle));
        vm.expectRevert(GyldInvestorTransferBase.DESTINATION_NOT_SET.selector);
        d.build(address(0), account, _dep(AMOUNT));
        vm.expectRevert(GyldInvestorTransferBase.DESTINATION_NOT_SET.selector);
        r.build(address(0), account, _red(SHARES));
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

    function test_Redeem_FullLeg_MovesBonds_RecordsExitNav_ZeroOut() public {
        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(address(bond), account);
        _run(redeemHook, _red(SHARES));
        assertEq(bond.balanceOf(holding), SHARES);
        GyldInTransitRegistry.Transit memory t = transit.transit(account, address(bond));
        assertEq(t.bondsOut, SHARES);
        assertEq(t.bondsOutNav, 1.05e6);
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
        assertEq(transit.transit(account, address(bond)).bondsOutNav, 0, "no usable NAV at exit: recorded as zero");
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
}
