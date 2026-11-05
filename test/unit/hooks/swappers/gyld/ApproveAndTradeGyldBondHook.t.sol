// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Superform
import { ApproveAndTradeGyldBondHook } from "../../../../../src/hooks/swappers/gyld/ApproveAndTradeGyldBondHook.sol";
import { GyldBondRegistry } from "../../../../../src/accounting/oracles/GyldBondRegistry.sol";
import { GyldTradeGuardHook } from "../../../../../src/hooks/swappers/gyld/GyldTradeGuardHook.sol";
import { GyldBondYieldSourceOracle } from "../../../../../src/accounting/oracles/GyldBondYieldSourceOracle.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { HookSubTypes } from "../../../../../src/libraries/HookSubTypes.sol";
import { SwapCalldataLayout } from "../../../../../src/libraries/SwapCalldataLayout.sol";
import { ISuperHookSwap } from "../../../../../src/interfaces/ISuperHookSwap.sol";
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
import { MockGyldSettlement } from "../../../../mocks/gyld/MockGyldSettlement.sol";
import { InternalHelpers } from "../../../../utils/InternalHelpers.sol";
import { IGyldTradePolicy } from "../../../../../src/interfaces/accounting/IGyldTradePolicy.sol";
import { MockGyldTradePolicy } from "../../../../../test/mocks/gyld/MockGyldTradePolicy.sol";

/// @dev A token whose `approve(spender, 0)` silently no-ops, which is the exact family of token the hook's
///      post-trade allowance assertion exists for.
contract MockStickyApprovalERC20 is ERC20 {
    constructor() ERC20("Sticky", "STK") { }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        if (amount == 0) return true; // the bug: a reset that does nothing
        return super.approve(spender, amount);
    }
}

/// @title ApproveAndTradeGyldBondHookTest
/// @notice Unit coverage for `ApproveAndTradeGyldBondHook`: the two-layer calldata contract, the approved-pair
///         gate in both directions, the per-transaction cap, and every outcome assertion that protects the
///         account from a venue that misbehaves without reverting.
contract ApproveAndTradeGyldBondHookTest is InternalHelpers {
    ApproveAndTradeGyldBondHook internal hook;
    GyldBondRegistry internal registry;
    MockGyldSettlement internal settlement;
    MockHook internal prevHook;

    MockERC20 internal bond;
    MockERC20 internal cash;
    MockERC20 internal otherBond;
    MockAggregator internal navFeed;

    address internal account;
    address internal admin = address(0xA11CE);
    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint256 internal constant MAX_INPUT = 10_000e6;
    uint256 internal constant CASH_IN = 1050e6;
    uint256 internal constant BOND_QUOTE = 1000e18;
    uint256 internal constant BOND_MIN = 995e18;

    bytes32 internal constant QUOTE_ID = keccak256("quote-1");
    MockGyldTradePolicy internal tradePolicy;


    function setUp() public {
        tradePolicy = new MockGyldTradePolicy();
        account = address(this);
        vm.warp(1_800_000_000);

        bond = new MockERC20("Gyld Bond", "GBOND", 18);
        otherBond = new MockERC20("Other Bond", "OBOND", 18);
        cash = new MockERC20("USD Coin", "USDC", 6);
        navFeed = new MockAggregator(8);
        navFeed.setLatestAnswer(1.05e8);

        registry = new GyldBondRegistry(admin);
        settlement = new MockGyldSettlement();
        hook = new ApproveAndTradeGyldBondHook(address(settlement), MAX_INPUT, address(tradePolicy), IGyldTradePolicy.TradeSide.BUY);
        prevHook = new MockHook(ISuperHook.HookType.INFLOW, address(cash));

        _registerBond(address(bond));
        cash.mint(account, 10 * CASH_IN);
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _registerBond(address bondToken) internal {
        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = bondToken;
        cfg.navFeed = address(navFeed);
        cfg.cashToken = address(cash);
        cfg.maxObservationAge = 2 days;
        cfg.maxPublicationAge = 1 days;
        vm.prank(admin);
        registry.registerInstrument(cfg);
    }

    /// @dev Layer 1: the 52-byte strategy header plus the swap layout's fixed fields.
    function _layer1(
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputQuote,
        uint256 outputMin,
        bool usePrevHookAmount,
        uint256 payloadLength
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            bytes32(0),
            bytes20(address(0)),
            bytes20(inputToken),
            bytes20(outputToken),
            inputAmount,
            outputQuote,
            outputMin,
            usePrevHookAmount,
            payloadLength
        );
    }

    /// @dev Layer 2: `abi.encode(quoteDeadline, venueCalldata)`.
    function _payload(uint256 deadline, bytes memory venueCalldata) internal pure returns (bytes memory) {
        return abi.encode(deadline, venueCalldata);
    }

    function _venueCalldata(
        bytes32 quoteId,
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 expiry
    )
        internal
        view
        returns (bytes memory)
    {
        return settlement.encodeFill(quoteId, account, inputToken, outputToken, inputAmount, outputAmount, expiry);
    }

    /// @dev The canonical BUY leaf: cash in, bond out.
    function _buyData() internal view returns (bytes memory) {
        return _buyData(CASH_IN, BOND_MIN, block.timestamp + 1 hours);
    }

    function _buyData(uint256 inputAmount, uint256 outputMin, uint256 deadline) internal view returns (bytes memory) {
        bytes memory venue = _venueCalldata(QUOTE_ID, address(cash), address(bond), inputAmount, BOND_QUOTE, deadline);
        bytes memory payload = _payload(deadline, venue);
        return bytes.concat(
            _layer1(address(cash), address(bond), inputAmount, BOND_QUOTE, outputMin, false, payload.length), payload
        );
    }

    function _dataWithTokens(address in_, address out_) internal view returns (bytes memory) {
        bytes memory payload = _payload(block.timestamp + 1 hours, hex"deadbeef");
        return bytes.concat(_layer1(in_, out_, CASH_IN, BOND_QUOTE, BOND_MIN, false, payload.length), payload);
    }

    function _runAsExecutor(bytes memory data) internal returns (uint256 failedAt, bytes memory ret) {
        hook.setExecutionContext(account);
        (failedAt, ret) = _executeBatch(hook.build(address(prevHook), account, data));
        if (failedAt == type(uint256).max) hook.resetExecutionState(account);
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public view {
        assertEq(hook.GYLD_SETTLEMENT(), address(settlement));
        // No registry binding: tradability is the guard's job, not this hook's.
        assertEq(hook.MAX_INPUT_AMOUNT(), MAX_INPUT);
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(hook.SUB_TYPE(), HookSubTypes.SWAP);
        assertEq(hook.name(), "Approve and Trade Gyld Bond");
        assertEq(
            hook.description(),
            "Approves and buys or sells a registered Gyld tokenized bond against its approved cash token"
        );
    }

    function test_Constructor_RevertIf_SettlementZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ApproveAndTradeGyldBondHook(address(0), MAX_INPUT, address(tradePolicy), IGyldTradePolicy.TradeSide.BUY);
    }

    function test_Constructor_RevertIf_CapZero() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        new ApproveAndTradeGyldBondHook(address(settlement), 0, address(tradePolicy), IGyldTradePolicy.TradeSide.BUY);
    }

    /*//////////////////////////////////////////////////////////////
                               BUILD SHAPE
    //////////////////////////////////////////////////////////////*/

    /// @dev Four executions, in this order: clear, scope, trade, clear. Nothing else is ever approved.
    function test_Build_ApproveTradeReset() public view {
        bytes memory data = _buyData();
        Execution[] memory ex = hook.build(address(prevHook), account, data);
        assertEq(ex.length, 6, "preExecute + 4 + postExecute");

        assertEq(ex[1].target, address(cash));
        assertEq(ex[1].callData, abi.encodeCall(IERC20.approve, (address(settlement), 0)));
        assertEq(ex[2].target, address(cash));
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (address(settlement), CASH_IN)));
        assertEq(ex[3].target, address(settlement), "the only call target is the pinned settlement");
        assertEq(ex[4].callData, abi.encodeCall(IERC20.approve, (address(settlement), 0)));

        for (uint256 i; i < ex.length; ++i) {
            assertEq(ex[i].value, 0, "every execution is ERC20-only");
        }
    }

    /// @dev The SELL direction is the same hook, with the pair reversed.
    function test_Build_SellDirection_Allowed() public view {
        bytes memory payload = _payload(block.timestamp + 1 hours, hex"deadbeef");
        bytes memory data =
            bytes.concat(_layer1(address(bond), address(cash), 1e9, 105e6, 100e6, false, payload.length), payload);
        Execution[] memory ex = hook.build(address(prevHook), account, data);
        assertEq(ex[1].target, address(bond), "the bond is approved on a sell");
        assertEq(ex[3].target, address(settlement));
    }

    /// @dev KNOWN LIMITATION, pinned here so it cannot change unnoticed. `MAX_INPUT_AMOUNT` is a single cap in
    ///      RAW input-token units and applies to whichever token is the input. A cap sized for the cash leg of
    ///      a 6-decimal stablecoin (10,000e6) caps the bond leg at 1e10 wei of an 18-decimal bond, which is
    ///      0.00000001 bonds. One instance cannot serve both directions of a pair whose decimals differ:
    ///      deploy one instance per direction with each cap denominated in that direction's input token.
    function test_Build_Sell_CapIsDenominatedInRawInputUnitsNotValue() public {
        bytes memory payload = _payload(block.timestamp + 1 hours, hex"deadbeef");
        // One whole bond in, worth ~1.05 cash units: far below a 10,000-cash cap BY VALUE, yet refused.
        bytes memory data =
            bytes.concat(_layer1(address(bond), address(cash), 1e18, 105e6, 100e6, false, payload.length), payload);
        vm.expectRevert(ApproveAndTradeGyldBondHook.INPUT_EXCEEDS_CAP.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_DataTooShort() public {
        vm.expectRevert(ApproveAndTradeGyldBondHook.INVALID_HOOK_DATA.selector);
        hook.build(address(prevHook), account, new bytes(SwapCalldataLayout.MIN_DATA_LENGTH - 1));
    }

    /// @dev A venue-signed quote cannot absorb an amount resized at execution time.
    function test_Build_RevertIf_UsePrevHookAmount() public {
        bytes memory payload = _payload(block.timestamp + 1 hours, hex"deadbeef");
        bytes memory data = bytes.concat(
            _layer1(address(cash), address(bond), CASH_IN, BOND_QUOTE, BOND_MIN, true, payload.length), payload
        );
        vm.expectRevert(ApproveAndTradeGyldBondHook.USE_PREV_HOOK_NOT_SUPPORTED.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_NativeInput() public {
        bytes memory data = _dataWithTokens(NATIVE, address(bond));
        vm.expectRevert(ApproveAndTradeGyldBondHook.NATIVE_ETH_NOT_SUPPORTED.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_ZeroAddressToken() public {
        bytes memory data = _dataWithTokens(address(0), address(bond));
        vm.expectRevert(ApproveAndTradeGyldBondHook.NATIVE_ETH_NOT_SUPPORTED.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_NativeOutput() public {
        bytes memory data = _dataWithTokens(address(cash), NATIVE);
        vm.expectRevert(ApproveAndTradeGyldBondHook.NATIVE_ETH_NOT_SUPPORTED.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_SameToken() public {
        bytes memory data = _dataWithTokens(address(cash), address(cash));
        vm.expectRevert(ApproveAndTradeGyldBondHook.SAME_INPUT_OUTPUT_TOKEN.selector);
        hook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
          WHAT THIS HOOK NO LONGER GATES, AND WHAT GATES IT INSTEAD
    //////////////////////////////////////////////////////////////*/

    // The hook used to ask the registry `isApprovedPair` and revert `PAIR_NOT_APPROVED`. That check was
    // removed because it was redundant three times over and actively misleading: `isApprovedPair` stays
    // TRUE while an instrument is suspended, so it looked like a tradability gate without being one.
    // The three tests below pin the new posture: these pairs BUILD, and something else stops them.

    /// @dev An unregistered instrument builds. What stops it: the leaf commits this exact pair, so it had to
    ///      be signed; and the pinned venue validates its own quote against its own registered series, so an
    ///      instrument Gyld does not know cannot be filled.
    function test_Build_UnregisteredInstrument_BuildsAndFailsAtTheVenue() public {
        MockERC20 stranger = new MockERC20("Stranger", "STR", 18);
        bytes memory data = _dataWithTokens(address(cash), address(stranger));
        hook.build(address(prevHook), account, data); // no revert at build

        // And the leaf identity is this pair and nothing else, so no other pair is authorised by it.
        assertEq(hook.inspect(data), abi.encodePacked(address(cash), address(stranger)));
    }

    /// @dev A bond-for-bond leaf builds too. The guard is what refuses it: its leaf names one instrument and
    ///      its expected cash denomination, and a bond is not that instrument's cash token.
    function test_Build_BondForBond_BuildsButTheGuardIsWhatRefuses() public {
        _registerBond(address(otherBond));
        bytes memory data = _dataWithTokens(address(bond), address(otherBond));
        hook.build(address(prevHook), account, data);

        GyldTradeGuardHook guard =
            new GyldTradeGuardHook(address(new GyldBondYieldSourceOracle(address(0xC0FFEE), address(registry))));
        bytes memory guardLeaf = abi.encodePacked(
            bytes32(0), bytes20(address(bond)), bytes20(address(otherBond)), uint256(2 days), uint256(1 days)
        );
        vm.expectRevert(GyldTradeGuardHook.CASH_DENOMINATION_MISMATCH.selector);
        guard.build(address(prevHook), account, guardLeaf);
    }

    /// @dev An unapproved cash denomination builds here and is refused by the guard for the same reason.
    function test_Build_UnapprovedCashDenomination_BuildsButTheGuardIsWhatRefuses() public {
        MockERC20 wrongCash = new MockERC20("DAI", "DAI", 18);
        bytes memory data = _dataWithTokens(address(wrongCash), address(bond));
        hook.build(address(prevHook), account, data);

        GyldTradeGuardHook guard =
            new GyldTradeGuardHook(address(new GyldBondYieldSourceOracle(address(0xC0FFEE), address(registry))));
        bytes memory guardLeaf = abi.encodePacked(
            bytes32(0), bytes20(address(bond)), bytes20(address(wrongCash)), uint256(2 days), uint256(1 days)
        );
        vm.expectRevert(GyldTradeGuardHook.CASH_DENOMINATION_MISMATCH.selector);
        guard.build(address(prevHook), account, guardLeaf);
    }

    /// @dev The shape checks that DID survive, because they are structural rather than permissions.
    function test_Build_StillRejectsStructurallyImpossiblePairs() public {
        vm.expectRevert(ApproveAndTradeGyldBondHook.SAME_INPUT_OUTPUT_TOKEN.selector);
        hook.build(address(prevHook), account, _dataWithTokens(address(cash), address(cash)));
        vm.expectRevert(ApproveAndTradeGyldBondHook.NATIVE_ETH_NOT_SUPPORTED.selector);
        hook.build(address(prevHook), account, _dataWithTokens(NATIVE, address(bond)));
    }

    function test_Build_RevertIf_InputAmountZero() public {
        bytes memory payload = _payload(block.timestamp + 1 hours, hex"deadbeef");
        bytes memory data = bytes.concat(
            _layer1(address(cash), address(bond), 0, BOND_QUOTE, BOND_MIN, false, payload.length), payload
        );
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_InputAboveCap() public {
        bytes memory data = _buyData(MAX_INPUT + 1, BOND_MIN, block.timestamp + 1 hours);
        vm.expectRevert(ApproveAndTradeGyldBondHook.INPUT_EXCEEDS_CAP.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_InputExactlyAtCap_Allowed() public view {
        bytes memory data = _buyData(MAX_INPUT, BOND_MIN, block.timestamp + 1 hours);
        Execution[] memory ex = hook.build(address(prevHook), account, data);
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (address(settlement), MAX_INPUT)));
    }

    /// @dev Slippage protection is not opt-out.
    function test_Build_RevertIf_OutputMinZero() public {
        bytes memory data = _buyData(CASH_IN, 0, block.timestamp + 1 hours);
        vm.expectRevert(ApproveAndTradeGyldBondHook.MIN_OUT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_QuoteBelowMin() public {
        bytes memory data = _buyData(CASH_IN, BOND_QUOTE + 1, block.timestamp + 1 hours);
        vm.expectRevert(ApproveAndTradeGyldBondHook.QUOTE_BELOW_MIN.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_PayloadLengthOverrunsCalldata() public {
        bytes memory payload = _payload(block.timestamp + 1 hours, hex"deadbeef");
        bytes memory data = bytes.concat(
            _layer1(address(cash), address(bond), CASH_IN, BOND_QUOTE, BOND_MIN, false, payload.length + 1), payload
        );
        vm.expectRevert(ApproveAndTradeGyldBondHook.INVALID_HOOK_DATA.selector);
        hook.build(address(prevHook), account, data);
    }

    /// @dev The deadline is checked BEFORE any approval is granted.
    function test_Build_RevertIf_QuoteExpired() public {
        bytes memory data = _buyData(CASH_IN, BOND_MIN, block.timestamp - 1);
        vm.expectRevert(ApproveAndTradeGyldBondHook.QUOTE_EXPIRED.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_QuoteDeadlineZero() public {
        bytes memory venue = _venueCalldata(QUOTE_ID, address(cash), address(bond), CASH_IN, BOND_QUOTE, 0);
        bytes memory payload = _payload(0, venue);
        bytes memory data = bytes.concat(
            _layer1(address(cash), address(bond), CASH_IN, BOND_QUOTE, BOND_MIN, false, payload.length), payload
        );
        vm.expectRevert(ApproveAndTradeGyldBondHook.QUOTE_EXPIRED.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_DeadlineExactlyNow_Allowed() public view {
        bytes memory data = _buyData(CASH_IN, BOND_MIN, block.timestamp);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_VenueCalldataShorterThanASelector() public {
        bytes memory payload = _payload(block.timestamp + 1 hours, hex"deadbe");
        bytes memory data = bytes.concat(
            _layer1(address(cash), address(bond), CASH_IN, BOND_QUOTE, BOND_MIN, false, payload.length), payload
        );
        vm.expectRevert(ApproveAndTradeGyldBondHook.INVALID_HOOK_DATA.selector);
        hook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                        DECODERS AND THE LEAF IDENTITY
    //////////////////////////////////////////////////////////////*/

    /// @dev Both tokens are in the leaf, which is what makes a buy leaf unable to execute a sell.
    function test_Inspect_CommitsBothTokens() public view {
        bytes memory data = _buyData();
        assertEq(hook.inspect(data), abi.encodePacked(address(cash), address(bond)));
        assertEq(hook.inspect(data).length, 40);
    }

    function test_Inspect_RevertIf_DataTooShort() public {
        vm.expectRevert(ApproveAndTradeGyldBondHook.INVALID_HOOK_DATA.selector);
        hook.inspect(new bytes(SwapCalldataLayout.MIN_DATA_LENGTH - 1));
    }

    function test_Decoders_ReadTheHeader() public view {
        bytes memory data = _buyData();
        assertEq(hook.decodeInputToken(data), address(cash));
        assertEq(hook.decodeOutputToken(data), address(bond));
        assertEq(hook.decodeInputAmount(data), CASH_IN);
        assertEq(hook.decodeOutputQuote(data), BOND_QUOTE);
        assertEq(hook.decodeOutputMin(data), BOND_MIN);
        assertFalse(hook.decodeUsePrevHookAmount(data));
    }

    /// @dev The flag decodes faithfully even though `build` refuses it, so the executor's own inspection of
    ///      the chain sees the same value the hook rejects.
    function test_DecodeUsePrevHookAmount_ReadsATrueFlag() public view {
        bytes memory payload = _payload(block.timestamp + 1 hours, hex"deadbeef");
        bytes memory data = bytes.concat(
            _layer1(address(cash), address(bond), CASH_IN, BOND_QUOTE, BOND_MIN, true, payload.length), payload
        );
        assertTrue(hook.decodeUsePrevHookAmount(data));
    }

    function test_DecodePayload_ReturnsLayer2() public view {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory venue = _venueCalldata(QUOTE_ID, address(cash), address(bond), CASH_IN, BOND_QUOTE, deadline);
        assertEq(hook.decodePayload(_buyData()), _payload(deadline, venue));
    }

    function test_EncodeSwapData_RoundTrips() public view {
        bytes memory payload = _payload(block.timestamp + 1 hours, hex"deadbeef");
        bytes memory encoded = hook.encodeSwapData(
            ISuperHookSwap.SwapHeader({
                inputToken: address(cash),
                outputToken: address(bond),
                inputAmount: CASH_IN,
                outputQuote: BOND_QUOTE,
                outputMin: BOND_MIN,
                usePrevHookAmount: false
            }),
            payload
        );
        assertEq(hook.decodeInputToken(encoded), address(cash));
        assertEq(hook.decodeOutputToken(encoded), address(bond));
        assertEq(hook.decodeInputAmount(encoded), CASH_IN);
        assertEq(hook.decodeOutputQuote(encoded), BOND_QUOTE);
        assertEq(hook.decodeOutputMin(encoded), BOND_MIN);
        assertEq(hook.decodePayload(encoded), payload);
        // And the encoded form is directly buildable.
        hook.build(address(prevHook), account, encoded);
    }

    /*//////////////////////////////////////////////////////////////
                             SIZELESSNESS
    //////////////////////////////////////////////////////////////*/

    /// @dev The spend lives inside a venue-signed quote, so there is no slot the OMS may rewrite.
    function test_Sizeless_NoAmountsAndNoRoles() public view {
        assertEq(hook.decodeAmounts(_buyData()).length, 0);
        assertEq(hook.amountRoles(_buyData()).length, 0);
    }

    function test_ReplaceCalldataAmounts_IsIdentity() public view {
        bytes memory data = _buyData();
        assertEq(hook.replaceCalldataAmounts(data, new uint256[](0)), data);
    }

    function test_ReplaceCalldataAmounts_RevertIf_AmountSpliced() public {
        bytes memory data = _buyData();
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        hook.replaceCalldataAmounts(data, amounts);
    }

    function test_SupportsInterface_DeclaresBothSizingInterfaces() public view {
        assertTrue(hook.supportsInterface(type(ISuperHookInflowOutflow).interfaceId));
        assertTrue(hook.supportsInterface(type(ISuperHookOutflow).interfaceId));
        assertTrue(hook.supportsInterface(type(ISuperHookInspector).interfaceId));
        assertTrue(hook.supportsInterface(type(ISuperHook).interfaceId));
        assertTrue(hook.supportsInterface(type(ISuperHookResult).interfaceId));
        assertTrue(hook.supportsInterface(type(IERC165).interfaceId));
        assertFalse(hook.supportsInterface(bytes4(0xdeadbeef)));
    }

    /*//////////////////////////////////////////////////////////////
                         FULL SEQUENCE AGAINST THE VENUE
    //////////////////////////////////////////////////////////////*/

    function test_Sequence_HappyPath_BuysTheBond() public {
        uint256 cashBefore = cash.balanceOf(account);
        (uint256 failedAt,) = _runAsExecutor(_buyData());
        assertEq(failedAt, type(uint256).max, "all six steps succeed");

        assertEq(cash.balanceOf(account), cashBefore - CASH_IN, "exactly the quoted cash left");
        assertEq(bond.balanceOf(account), BOND_QUOTE, "bonds received");
        assertEq(cash.allowance(account, address(settlement)), 0, "no standing allowance survives");
        assertEq(hook.getOutAmount(account), BOND_QUOTE);
        assertEq(hook.getOutToken(account), address(bond));
        assertTrue(settlement.quoteUsed(QUOTE_ID), "the venue marked the quote used");
    }

    /// @dev A venue that takes the cash and delivers nothing, without reverting, must still fail the leaf.
    function test_Sequence_VenueDeliversNothing_RevertsMinOut() public {
        settlement.setDeliverNothing(true);
        (uint256 failedAt, bytes memory ret) = _runAsExecutor(_buyData());
        assertEq(failedAt, 5, "fails at postExecute");
        assertEq(bytes4(ret), ApproveAndTradeGyldBondHook.MIN_OUT_NOT_MET.selector);
    }

    function test_Sequence_VenueUnderDelivers_RevertsMinOut() public {
        settlement.setUnderDeliverBps(1000); // 10% short, below the 0.5% tolerance in the leaf
        (uint256 failedAt, bytes memory ret) = _runAsExecutor(_buyData());
        assertEq(failedAt, 5);
        assertEq(bytes4(ret), ApproveAndTradeGyldBondHook.MIN_OUT_NOT_MET.selector);
    }

    /// @dev The invariant that justifies the scoped approve: the venue cannot pull a wei more than the leaf
    ///      authorised, because the allowance is exactly the header amount.
    function test_Sequence_VenueOverPulls_FailsOnAllowance() public {
        settlement.setOverPullBps(1); // one basis point above the quote
        uint256 cashBefore = cash.balanceOf(account);
        (uint256 failedAt,) = _runAsExecutor(_buyData());
        assertEq(failedAt, 3, "the venue call itself reverts on insufficient allowance");
        assertEq(cash.balanceOf(account), cashBefore, "nothing spent");
    }

    /// @dev An issuer with seize or burn powers is the one route that can move more input than was approved.
    ///      The post-trade balance comparison is what notices.
    function test_Sequence_VenueSeizesExtraInput_RevertsInputOverspent() public {
        settlement.setSeizeExtra(1e6);
        (uint256 failedAt, bytes memory ret) = _runAsExecutor(_buyData());
        assertEq(failedAt, 5, "fails at postExecute");
        assertEq(bytes4(ret), ApproveAndTradeGyldBondHook.INPUT_OVERSPENT.selector);
    }

    function test_Sequence_VenueReverts_NothingIsLeftApproved() public {
        settlement.setPaused(true);
        uint256 cashBefore = cash.balanceOf(account);
        (uint256 failedAt,) = _runAsExecutor(_buyData());
        assertEq(failedAt, 3);
        assertEq(cash.balanceOf(account), cashBefore, "failed trades leave no partial transfer");
    }

    /// @dev Replay protection is the VENUE's guarantee. The same leaf replayed in a later transaction is
    ///      rejected by the venue's single-use quote id, not by the hook.
    function test_Sequence_ReplayedQuoteIsRejectedByTheVenue() public {
        (uint256 failedAt,) = _runAsExecutor(_buyData());
        assertEq(failedAt, type(uint256).max);

        // A fresh transaction: the per-transaction cap resets, so only the venue stands in the way.
        (uint256 failedAt2, bytes memory ret) = _runAsExecutor(_buyData());
        assertEq(failedAt2, 3, "the venue call rejects the reused quote id");
        assertEq(bytes4(ret), MockGyldSettlement.QUOTE_ALREADY_USED.selector);
    }

    /// @dev And if a venue did NOT enforce single use, the per-transaction cap is the only remaining bound,
    ///      which is exactly why it exists.
    function test_Sequence_VenueAllowsReplay_CapStillBoundsTheDamage() public {
        settlement.setAllowReplay(true);
        bytes memory data = _buyData(MAX_INPUT / 2, BOND_MIN, block.timestamp + 1 hours);
        cash.mint(account, 2 * MAX_INPUT);

        hook.setExecutionContext(account);
        (uint256 first,) = _executeBatch(hook.build(address(prevHook), account, data));
        assertEq(first, type(uint256).max);
        hook.resetExecutionState(account);
        assertEq(hook.txSpent(account), MAX_INPUT / 2);

        hook.setExecutionContext(account);
        (uint256 second,) = _executeBatch(hook.build(address(prevHook), account, data));
        assertEq(second, type(uint256).max, "the second half still fits under the cap");
        hook.resetExecutionState(account);
        assertEq(hook.txSpent(account), MAX_INPUT);

        hook.setExecutionContext(account);
        (uint256 third, bytes memory ret) = _executeBatch(hook.build(address(prevHook), account, data));
        assertEq(third, 0, "the third repetition is refused at preExecute, before any approval");
        assertEq(bytes4(ret), ApproveAndTradeGyldBondHook.INPUT_EXCEEDS_CAP.selector);
    }

    /// @dev A token whose `approve(0)` no-ops leaves the venue standing on an allowance. The hook must notice
    ///      rather than trust the reset it just issued.
    function test_Sequence_StickyApproval_RevertsAllowanceNotCleared() public {
        MockStickyApprovalERC20 sticky = new MockStickyApprovalERC20();
        MockERC20 stickyBond = new MockERC20("Sticky Bond", "SBOND", 18);

        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = address(stickyBond);
        cfg.navFeed = address(navFeed);
        cfg.cashToken = address(sticky);
        cfg.maxObservationAge = 2 days;
        cfg.maxPublicationAge = 1 days;
        vm.prank(admin);
        registry.registerInstrument(cfg);

        sticky.mint(account, 10e18);
        uint256 deadline = block.timestamp + 1 hours;
        // The venue pulls only half the approved bound, so a no-op `approve(0)` leaves the rest standing.
        bytes memory venue =
            settlement.encodeFill(QUOTE_ID, account, address(sticky), address(stickyBond), 1e9, BOND_QUOTE, deadline);
        bytes memory payload = _payload(deadline, venue);
        bytes memory data = bytes.concat(
            _layer1(address(sticky), address(stickyBond), 2e9, BOND_QUOTE, BOND_MIN, false, payload.length), payload
        );

        (uint256 failedAt, bytes memory ret) = _runAsExecutor(data);
        assertEq(failedAt, 5, "fails at postExecute");
        assertEq(bytes4(ret), ApproveAndTradeGyldBondHook.ALLOWANCE_NOT_CLEARED.selector);
    }

    /*//////////////////////////////////////////////////////////////
                           PRE / POST EXECUTE
    //////////////////////////////////////////////////////////////*/

    function test_PreExecute_AccumulatesTxSpent() public {
        assertEq(hook.txSpent(account), 0);
        hook.preExecute(address(0), account, _buyData());
        assertEq(hook.txSpent(account), CASH_IN);
    }

    function test_PreExecute_RevertIf_CallerIsNotTheAccount() public {
        bytes memory data = _buyData();
        vm.expectRevert(BaseHook.UNAUTHORIZED_CALLER.selector);
        vm.prank(address(0xBAD));
        hook.preExecute(address(0), account, data);
    }

    function test_PostExecute_RevertIf_NoPreExecute() public {
        bond.mint(account, BOND_QUOTE);
        bytes memory data = _buyData();
        vm.expectRevert(ApproveAndTradeGyldBondHook.SNAPSHOT_NOT_TAKEN.selector);
        hook.postExecute(address(0), account, data);
    }

    /// @dev `setExecutionContext` is permissionless, so a venue that reenters it mid-batch would otherwise
    ///      make the pre-trade balance look like trade output. The hook fails closed on its own.
    function test_PostExecute_RevertIf_ContextRotatedBetweenPreAndPost() public {
        bond.mint(account, BOND_QUOTE + 1);
        bytes memory data = _buyData();
        hook.setExecutionContext(account);
        hook.preExecute(address(0), account, data);

        hook.setExecutionContext(account); // the mid-batch reentry
        assertEq(hook.getOutAmount(account), 0, "the snapshot is unreachable from the new context");
        vm.expectRevert(ApproveAndTradeGyldBondHook.SNAPSHOT_NOT_TAKEN.selector);
        hook.postExecute(address(0), account, data);
    }

    /// @dev A bond issuer may hold burn or seize powers, so a shrinking output balance gets a named error
    ///      rather than an arithmetic panic.
    function test_PostExecute_RevertIf_OutputBalanceDecreased() public {
        bond.mint(account, 500e18);
        bytes memory data = _buyData();
        hook.preExecute(address(0), account, data);
        bond.burn(account, 1);
        vm.expectRevert(ApproveAndTradeGyldBondHook.OUTPUT_BALANCE_DECREASED.selector);
        hook.postExecute(address(0), account, data);
    }

    function test_PostExecute_RevertIf_MinOutNotMet() public {
        bytes memory data = _buyData();
        hook.preExecute(address(0), account, data);
        bond.mint(account, BOND_MIN - 1);
        vm.expectRevert(ApproveAndTradeGyldBondHook.MIN_OUT_NOT_MET.selector);
        hook.postExecute(address(0), account, data);
    }

    function test_PostExecute_RevertIf_InputOverspent() public {
        bytes memory data = _buyData();
        hook.preExecute(address(0), account, data);
        bond.mint(account, BOND_QUOTE);
        cash.burn(account, CASH_IN + 1); // more input left than the leaf authorised
        vm.expectRevert(ApproveAndTradeGyldBondHook.INPUT_OVERSPENT.selector);
        hook.postExecute(address(0), account, data);
    }

    function test_PostExecute_InputSpentExactlyAtHeaderAmount_Allowed() public {
        bytes memory data = _buyData();
        hook.preExecute(address(0), account, data);
        bond.mint(account, BOND_QUOTE);
        cash.burn(account, CASH_IN);
        hook.postExecute(address(0), account, data);
        assertEq(hook.getOutAmount(account), BOND_QUOTE);
    }

    /// @dev F1: an input balance that GREW makes the over-spend comparison meaningless, so it is now a
    ///      NAMED failure. Previously the whole over-spend branch was skipped and the leg passed silently,
    ///      which also meant a venue could deliver output while taking nothing.
    function test_PostExecute_RevertIf_InputBalanceIncreased() public {
        bytes memory data = _buyData();
        hook.preExecute(address(0), account, data);
        bond.mint(account, BOND_QUOTE);
        cash.mint(account, 1e6);
        vm.expectRevert(ApproveAndTradeGyldBondHook.INPUT_BALANCE_INCREASED.selector);
        hook.postExecute(address(0), account, data);
    }

    /// @dev F1: and a leg that takes no input at all is not a trade.
    function test_PostExecute_RevertIf_NoInputSpent() public {
        bytes memory data = _buyData();
        hook.preExecute(address(0), account, data);
        bond.mint(account, BOND_QUOTE);
        vm.expectRevert(ApproveAndTradeGyldBondHook.NO_INPUT_SPENT.selector);
        hook.postExecute(address(0), account, data);
    }

    function test_PostExecute_RevertIf_AllowanceNotCleared() public {
        bytes memory data = _buyData();
        hook.preExecute(address(0), account, data);
        bond.mint(account, BOND_QUOTE);
        // Spend the input too: without it the leg trips `NO_INPUT_SPENT` first and this assertion would
        // pass for the wrong reason.
        cash.burn(account, CASH_IN);
        cash.approve(address(settlement), 1);
        vm.expectRevert(ApproveAndTradeGyldBondHook.ALLOWANCE_NOT_CLEARED.selector);
        hook.postExecute(address(0), account, data);
    }

    function test_PostExecute_RevertIf_CallerIsNotTheAccount() public {
        bytes memory data = _buyData();
        hook.preExecute(address(0), account, data);
        vm.expectRevert(BaseHook.UNAUTHORIZED_CALLER.selector);
        vm.prank(address(0xBAD));
        hook.postExecute(address(0), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                                 FUZZ
    //////////////////////////////////////////////////////////////*/

    /// @dev No header amount at or below the cap may be rejected by the cap, and none above it may pass.
    function testFuzz_Build_CapIsTheOnlyAmountBound(uint256 inputAmount) public {
        inputAmount = bound(inputAmount, 1, 2 * MAX_INPUT);
        bytes memory data = _buyData(inputAmount, BOND_MIN, block.timestamp + 1 hours);
        if (inputAmount > MAX_INPUT) {
            vm.expectRevert(ApproveAndTradeGyldBondHook.INPUT_EXCEEDS_CAP.selector);
            hook.build(address(prevHook), account, data);
        } else {
            Execution[] memory ex = hook.build(address(prevHook), account, data);
            assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (address(settlement), inputAmount)));
        }
    }

    /// @dev The leaf identity is exactly the token pair, for any pair the registry approves.
    function testFuzz_Inspect_IsTheTokenPair(uint256 inputAmount, uint256 outputMin) public view {
        inputAmount = bound(inputAmount, 1, MAX_INPUT);
        outputMin = bound(outputMin, 1, BOND_QUOTE);
        bytes memory data = _buyData(inputAmount, outputMin, block.timestamp + 1 hours);
        assertEq(hook.inspect(data), abi.encodePacked(address(cash), address(bond)));
    }

    /// @dev An expired quote can never build, whatever the amounts.
    function testFuzz_Build_ExpiredQuoteNeverBuilds(uint256 secondsPast) public {
        secondsPast = bound(secondsPast, 1, 365 days);
        bytes memory data = _buyData(CASH_IN, BOND_MIN, block.timestamp - secondsPast);
        vm.expectRevert(ApproveAndTradeGyldBondHook.QUOTE_EXPIRED.selector);
        hook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                   F1 — THE POLICY IS WIRED AND UNSKIPPABLE
    //////////////////////////////////////////////////////////////*/

    /// @dev A nullable policy would recreate exactly the omission hole F1 is about, moved from the root
    ///      author to the deployer. There is deliberately no no-op policy implementation either.
    function test_Constructor_RevertIf_PolicyIsZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ApproveAndTradeGyldBondHook(
            address(settlement), MAX_INPUT, address(0), IGyldTradePolicy.TradeSide.BUY
        );
    }

    function test_Constructor_StoresPolicyAndSide() public {
        assertEq(address(hook.TRADE_POLICY()), address(tradePolicy), "policy pinned");
        assertEq(uint8(hook.SIDE()), uint8(IGyldTradePolicy.TradeSide.BUY), "side pinned");

        ApproveAndTradeGyldBondHook sellSide = new ApproveAndTradeGyldBondHook(
            address(settlement), MAX_INPUT, address(tradePolicy), IGyldTradePolicy.TradeSide.SELL
        );
        assertEq(uint8(sellSide.SIDE()), uint8(IGyldTradePolicy.TradeSide.SELL), "sell side pinned");
    }

    /// @dev The side is a constructor argument, so it lands in the initcode and the two directions are
    ///      DIFFERENT addresses. That is what makes a BUY proof unusable against the SELL instance: a
    ///      different hook address is a different Merkle leaf.
    function test_SideChangesTheDeployedAddress() public {
        bytes memory initcode = abi.encodePacked(
            vm.getCode("ApproveAndTradeGyldBondHook.sol:ApproveAndTradeGyldBondHook"),
            abi.encode(address(settlement), MAX_INPUT, address(tradePolicy), uint8(0))
        );
        bytes memory initcodeSell = abi.encodePacked(
            vm.getCode("ApproveAndTradeGyldBondHook.sol:ApproveAndTradeGyldBondHook"),
            abi.encode(address(settlement), MAX_INPUT, address(tradePolicy), uint8(1))
        );
        assertTrue(keccak256(initcode) != keccak256(initcodeSell), "side is part of the initcode");
    }

    /// @dev `_preExecute` consults the policy. Proven by making the policy refuse and observing the
    ///      hook's own pre-step fail with the POLICY's error, unwrapped.
    function test_PreExecute_ConsultsThePolicy() public {
        tradePolicy.setRejectTrade(true);
        bytes memory data = _buyData();
        vm.expectRevert(MockGyldTradePolicy.TRADE_REJECTED.selector);
        hook.preExecute(address(0), account, data);
    }

    /// @dev And the refusal happens BEFORE the cap accounting touches transient state, so a refused
    ///      instrument does not consume the account's per-transaction budget.
    function test_PreExecute_PolicyRefusalDoesNotConsumeTheCap() public {
        tradePolicy.setRejectTrade(true);
        bytes memory data = _buyData();
        vm.expectRevert(MockGyldTradePolicy.TRADE_REJECTED.selector);
        hook.preExecute(address(0), account, data);

        // The same account can now trade normally: nothing was recorded against the cap.
        tradePolicy.setRejectTrade(false);
        hook.preExecute(address(0), account, data);
        bond.mint(account, BOND_QUOTE);
        cash.burn(account, CASH_IN);
        hook.postExecute(address(0), account, data);
        assertEq(hook.getOutAmount(account), BOND_QUOTE);
    }

    /// @dev `_postExecute` consults the policy with the realised amounts.
    function test_PostExecute_ConsultsThePolicy() public {
        tradePolicy.setRejectFill(true);
        bytes memory data = _buyData();
        hook.preExecute(address(0), account, data);
        bond.mint(account, BOND_QUOTE);
        cash.burn(account, CASH_IN);
        vm.expectRevert(MockGyldTradePolicy.FILL_REJECTED.selector);
        hook.postExecute(address(0), account, data);
    }

    /// @dev The policy's own error names must reach the caller unwrapped: the review criticised opaque
    ///      re-mapping, and an operator needs to know WHICH check fired.
    function test_PolicyErrorsAreNotReWrapped() public {
        tradePolicy.setRejectTrade(true);
        bytes memory data = _buyData();
        // Not ApproveAndTradeGyldBondHook's own error, the policy's.
        vm.expectRevert(MockGyldTradePolicy.TRADE_REJECTED.selector);
        hook.preExecute(address(0), account, data);
    }
}
