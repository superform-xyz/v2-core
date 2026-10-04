// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { Helpers } from "../../../utils/Helpers.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { BytesLib } from "../../../../src/vendor/BytesLib.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {
    ISuperHook,
    ISuperHookLoans,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookResult,
    ISuperHookInspector
} from "../../../../src/interfaces/ISuperHook.sol";
import { IAaveV4Spoke } from "../../../../src/vendor/aave-v4/IAaveV4Spoke.sol";
import { HookSubTypes } from "../../../../src/libraries/HookSubTypes.sol";

// Hooks
import { BaseLoanHookV2 } from "../../../../src/hooks/loan/BaseLoanHookV2.sol";
import { BaseAaveV4LoanHookV2 } from "../../../../src/hooks/loan/aave-v4/BaseAaveV4LoanHookV2.sol";
import { AaveV4SupplyHookV2 } from "../../../../src/hooks/loan/aave-v4/AaveV4SupplyHookV2.sol";
import { AaveV4BorrowHookV2 } from "../../../../src/hooks/loan/aave-v4/AaveV4BorrowHookV2.sol";
import { AaveV4WithdrawHookV2 } from "../../../../src/hooks/loan/aave-v4/AaveV4WithdrawHookV2.sol";
import { MockAaveV4SpokeV2, MockPrevHookV2 } from "./AaveV4LoanHooksV2.t.sol";
import { BaseAaveV4StandaloneLoanHookV2 } from "../../../../src/hooks/loan/aave-v4/BaseAaveV4StandaloneLoanHookV2.sol";
import { AaveV4ReserveKey } from "../../../../src/libraries/AaveV4ReserveKey.sol";
import { AaveV4ReserveRegistryV2 } from "../../../../src/accounting/oracles/AaveV4ReserveRegistryV2.sol";

/// @title AaveV4StandaloneLoanHooksV2Test
/// @notice SUP-21141: the standalone PLEDGE / BORROW / RELEASE hooks on the canonical 241-byte Aave V4
///         V2 layout. Mirrors MorphoStandaloneLoanHooksV2 test-for-test; Aave-specific additions cover
///         the reserve binding and the release hook's "above supplied" rejection.
contract AaveV4StandaloneLoanHooksV2Test is Helpers {
    AaveV4SupplyHookV2 public pledgeHook;
    AaveV4BorrowHookV2 public borrowHook;
    AaveV4WithdrawHookV2 public releaseHook;

    MockAaveV4SpokeV2 public mockSpoke;
    MockAaveV4SpokeV2 public otherSpoke;
    MockERC20 public mockLoanToken;
    MockERC20 public mockCollateralToken;
    MockPrevHookV2 public prevHook;

    address public spoke;
    address public loanToken;
    address public collateralToken;
    uint256 public constant SUPPLY_ID = 1;
    uint256 public constant BORROW_ID = 2;
    uint256 public constant SUPPLIED = 3e18;
    uint256 public amount1 = 1e18;
    address public constant BURN = address(0xdead);
    uint256 internal constant MAX = type(uint256).max;

    function setUp() public {
        mockSpoke = new MockAaveV4SpokeV2();
        otherSpoke = new MockAaveV4SpokeV2();
        spoke = address(mockSpoke);
        mockLoanToken = new MockERC20("Loan Token", "LOAN", 18);
        loanToken = address(mockLoanToken);
        mockCollateralToken = new MockERC20("Collateral Token", "COLL", 18);
        collateralToken = address(mockCollateralToken);
        prevHook = new MockPrevHookV2();

        pledgeHook = new AaveV4SupplyHookV2();
        borrowHook = new AaveV4BorrowHookV2();
        releaseHook = new AaveV4WithdrawHookV2();

        for (uint256 i; i < 2; ++i) {
            MockAaveV4SpokeV2 s = i == 0 ? mockSpoke : otherSpoke;
            s.setReserveUnderlying(SUPPLY_ID, collateralToken);
            s.setReserveUnderlying(BORROW_ID, loanToken);
        }
        // The test contract acts as the smart account with a supplied position on the collateral reserve
        mockSpoke.setUserSuppliedAssets(SUPPLY_ID, address(this), SUPPLIED);
        mockSpoke.setUsingAsCollateral(SUPPLY_ID, true, address(this)); // LOAN mode: flagged as collateral
    }

    /*//////////////////////////////////////////////////////////////
                            ENCODE HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev A reserve-leg key — a WRONG header for these hooks since SUP-21239, kept because rejecting it is
    ///      the property that lets the new hook addresses coexist with old reserve-keyed roots.
    function _key(address spoke_, uint256 reserveId) internal pure returns (address) {
        return AaveV4ReserveKey.computeReserveKey(spoke_, reserveId);
    }

    /// @dev The market key every V2 LOAN header must carry — the same value for every leg of the market.
    function _marketKey(address spoke_, uint256 supplyId_, uint256 borrowId_) internal pure returns (address) {
        return AaveV4ReserveKey.computeMarketKey(spoke_, supplyId_, borrowId_);
    }

    /// @dev Full layout with an explicit header (oracle id + yield-source key)
    function _encodeH(
        bytes32 oracleId,
        address headerKey,
        address loanToken_,
        address collateralToken_,
        address spoke_,
        uint256 supplyId,
        uint256 borrowId,
        uint256 amount1_,
        uint256 amount2_,
        bool usePrev_
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            oracleId, headerKey, loanToken_, collateralToken_, spoke_, supplyId, borrowId, amount1_, amount2_, usePrev_
        );
    }

    /// @dev Supply-keyed header (PLEDGE / RELEASE): yieldSource = key(spoke, supplyId)
    function _encode(
        address loanToken_,
        address collateralToken_,
        address spoke_,
        uint256 supplyId,
        uint256 borrowId,
        uint256 amount1_,
        uint256 amount2_,
        bool usePrev_
    )
        internal
        pure
        returns (bytes memory)
    {
        return _encodeH(
            AAVE_V4_YS_ORACLE_ID,
            _marketKey(spoke_, supplyId, borrowId),
            loanToken_,
            collateralToken_,
            spoke_,
            supplyId,
            borrowId,
            amount1_,
            amount2_,
            usePrev_
        );
    }

    /// @dev Borrow-keyed header (BORROW): yieldSource = key(spoke, borrowId)
    function _encodeB(
        address loanToken_,
        address collateralToken_,
        address spoke_,
        uint256 supplyId,
        uint256 borrowId,
        uint256 amount1_,
        uint256 amount2_,
        bool usePrev_
    )
        internal
        pure
        returns (bytes memory)
    {
        return _encodeH(
            AAVE_V4_YS_ORACLE_ID,
            _marketKey(spoke_, supplyId, borrowId),
            loanToken_,
            collateralToken_,
            spoke_,
            supplyId,
            borrowId,
            amount1_,
            amount2_,
            usePrev_
        );
    }

    /// @dev Header keyed for hook index i of _hooks(): 0 pledge / 2 release → supply, 1 borrow → borrow
    function _encodeFor(
        uint256 i,
        address loanToken_,
        address collateralToken_,
        address spoke_,
        uint256 supplyId,
        uint256 borrowId,
        uint256 amount1_,
        uint256 amount2_,
        bool usePrev_
    )
        internal
        pure
        returns (bytes memory)
    {
        return i == 1
            ? _encodeB(loanToken_, collateralToken_, spoke_, supplyId, borrowId, amount1_, amount2_, usePrev_)
            : _encode(loanToken_, collateralToken_, spoke_, supplyId, borrowId, amount1_, amount2_, usePrev_);
    }

    function _data(uint256 amount1_, bool usePrev_) internal view returns (bytes memory) {
        return _encode(loanToken, collateralToken, spoke, SUPPLY_ID, BORROW_ID, amount1_, 0, usePrev_);
    }

    function _dataB(uint256 amount1_, bool usePrev_) internal view returns (bytes memory) {
        return _encodeB(loanToken, collateralToken, spoke, SUPPLY_ID, BORROW_ID, amount1_, 0, usePrev_);
    }

    function _dataFor(uint256 i, uint256 amount1_, bool usePrev_) internal view returns (bytes memory) {
        return i == 1 ? _dataB(amount1_, usePrev_) : _data(amount1_, usePrev_);
    }

    function _hooks() internal view returns (BaseLoanHookV2[3] memory hooks) {
        hooks[0] = BaseLoanHookV2(address(pledgeHook));
        hooks[1] = BaseLoanHookV2(address(borrowHook));
        hooks[2] = BaseLoanHookV2(address(releaseHook));
    }

    function _build(BaseLoanHookV2 hook, bytes memory data) internal view returns (Execution[] memory) {
        return ISuperHook(address(hook)).build(address(prevHook), address(this), data);
    }

    /*//////////////////////////////////////////////////////////////
                        1-3. CONSTRUCTION / INTERFACES
    //////////////////////////////////////////////////////////////*/

    function test_Standalone_Constructors() public view {
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            assertEq(uint256(hooks[i].hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
            assertEq(hooks[i].subtype(), HookSubTypes.LOAN);
        }
        assertEq(pledgeHook.name(), "Aave V4 Supply V2");
        assertEq(borrowHook.name(), "Aave V4 Borrow V2");
        assertEq(releaseHook.name(), "Aave V4 Withdraw V2");
    }

    /// @dev No constructor args: one deployment serves any Spoke named in calldata
    function test_Standalone_NoConstructorArgs_SpokeFromCalldata() public view {
        bytes memory data =
            _encode(loanToken, collateralToken, address(otherSpoke), SUPPLY_ID, BORROW_ID, amount1, 0, false);
        Execution[] memory ex = _build(_hooks()[0], data);
        assertEq(ex[3].target, address(otherSpoke), "supply targets the calldata spoke");
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (address(otherSpoke), amount1)));
    }

    function test_Standalone_SupportsInterface() public view {
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            assertTrue(hooks[i].supportsInterface(type(IERC165).interfaceId));
            assertTrue(hooks[i].supportsInterface(type(ISuperHookInflowOutflow).interfaceId));
            assertTrue(hooks[i].supportsInterface(type(ISuperHookOutflow).interfaceId));
            assertFalse(hooks[i].supportsInterface(type(ISuperHookLoans).interfaceId));
        }
    }

    /*//////////////////////////////////////////////////////////////
                          4-10. STRICT DECODING
    //////////////////////////////////////////////////////////////*/

    function test_Standalone_Build_RevertIf_WrongLength() public {
        bytes memory data = _data(amount1, false);
        bytes memory short = BytesLib.slice(data, 0, 240);
        bytes memory long = abi.encodePacked(data, bytes1(0));
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
            _build(hooks[i], short);
            vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
            _build(hooks[i], long);
            vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
            hooks[i].decodeUsePrevHookAmount(short);
            vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
            hooks[i].decodeUsePrevHookAmount(long);
            vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
            hooks[i].decodeAmounts(long);
            vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
            hooks[i].inspect(long);
        }
    }

    function test_Standalone_Build_RevertIf_NonCanonicalBool() public {
        bytes memory data = _data(amount1, false);
        data[240] = 0x02;
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
            _build(hooks[i], data);
            vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
            hooks[i].decodeUsePrevHookAmount(data);
        }
    }

    function test_Standalone_Build_RevertIf_SecondaryWordNotZero() public {
        bytes memory data = _encode(loanToken, collateralToken, spoke, SUPPLY_ID, BORROW_ID, amount1, 1, false);
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
            _build(hooks[i], data);
        }
    }

    /// @dev SUP-21143 header bind: the oracle id (offset 0) is identity only and never validated on-chain (any
    ///      value builds identically and never leaks into a target or calldata), while the yield source (offset 32)
    ///      MUST be the reserve key of the op's primary reserve on the calldata Spoke — every other value is refused
    ///      on build, preExecute, inspect AND the strict sizing views. Primary: supply reserve for PLEDGE / RELEASE,
    ///      borrow reserve for BORROW.
    function test_Standalone_Build_HeaderBound_AnyNonzeroOracleId_KeyPinned() public {
        uint256[] memory one = new uint256[](1);
        one[0] = 1;
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            bytes memory data = _dataFor(i, amount1, false);
            // oracle id free
            bytes memory tagged = abi.encodePacked(
                keccak256("any-oracle-id"),
                _marketKey(spoke, SUPPLY_ID, BORROW_ID),
                BytesLib.slice(data, 52, data.length - 52)
            );
            Execution[] memory a = _build(hooks[i], tagged);
            Execution[] memory b = _build(hooks[i], data);
            assertEq(a.length, b.length);
            for (uint256 j = 1; j + 1 < a.length; ++j) {
                assertEq(a[j].target, b[j].target, "header never leaks into a target");
                assertEq(a[j].callData, b[j].callData, "header never leaks into calldata");
            }
            assertEq(hooks[i].inspect(tagged), hooks[i].inspect(data), "oracle id is not identity");
            // key pinned: either leg's OLD reserve key, the legs swapped, another spoke's market, the spoke
            // itself, an unrelated address
            address[6] memory wrong = [
                _key(spoke, SUPPLY_ID),
                _key(spoke, BORROW_ID),
                _marketKey(spoke, BORROW_ID, SUPPLY_ID),
                _marketKey(address(otherSpoke), SUPPLY_ID, BORROW_ID),
                spoke,
                address(0xBEEF)
            ];
            for (uint256 w; w < wrong.length; ++w) {
                bytes memory bad =
                    abi.encodePacked(AAVE_V4_YS_ORACLE_ID, wrong[w], BytesLib.slice(data, 52, data.length - 52));
                vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
                _build(hooks[i], bad);
                vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
                hooks[i].preExecute(address(prevHook), address(this), bad);
                vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
                hooks[i].inspect(bad);
                vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
                hooks[i].decodeAmounts(bad);
                vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
                hooks[i].replaceCalldataAmounts(bad, one);
            }
            // zero key is an address error, like every other zero address
            bytes memory zeroKey =
                abi.encodePacked(AAVE_V4_YS_ORACLE_ID, address(0), BytesLib.slice(data, 52, data.length - 52));
            vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
            _build(hooks[i], zeroKey);
            vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
            hooks[i].inspect(zeroKey);
        }
    }

    /// @dev The library equals the registry's derivation AND the literal formula off-chain consumers derive
    ///      (the registry delegates to the library, so the literal check is the independent pin). The RESERVE
    ///      assertion stays: the V1 six, the idle pair and the registry's NAV namespace still use that key.
    function testFuzz_ReserveKey_MatchesLiteralFormula(address spoke_, uint256 reserveId) public {
        AaveV4ReserveRegistryV2 registry = new AaveV4ReserveRegistryV2(address(this));
        address literal = address(uint160(uint256(keccak256(abi.encode(spoke_, reserveId)))));
        assertEq(AaveV4ReserveKey.computeReserveKey(spoke_, reserveId), literal, "library == literal");
        assertEq(registry.computeReserveKey(spoke_, reserveId), literal, "registry == literal");
    }

    /// @dev THE HEADER FORMULA THESE HOOKS NOW ENFORCE. Four-word, domain-separated, ids unsorted — pinned
    ///      against the literal expression because Erebor, snapshotd and the UI re-derive it from exactly this.
    function testFuzz_MarketKey_MatchesLiteralFormula(address spoke_, uint256 supplyId_, uint256 borrowId_) public {
        AaveV4ReserveRegistryV2 registry = new AaveV4ReserveRegistryV2(address(this));
        address literal = address(
            uint160(uint256(keccak256(abi.encode(spoke_, supplyId_, borrowId_, keccak256("AaveV4ReserveKey.MARKET")))))
        );
        assertEq(AaveV4ReserveKey.computeMarketKey(spoke_, supplyId_, borrowId_), literal, "library == literal");
        assertEq(registry.computeMarketKey(spoke_, supplyId_, borrowId_), literal, "registry == literal");
    }

    /// @dev The header key is identity only: every non-ERC20 execution targets the calldata Spoke and every approve
    ///      names the Spoke as spender — the key is never called or approved
    function test_Standalone_Build_SpokeIsCallTarget_NotHeaderKey() public view {
        address key = _marketKey(spoke, SUPPLY_ID, BORROW_ID);
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            Execution[] memory ex = _build(hooks[i], _dataFor(i, amount1, false));
            for (uint256 j = 1; j + 1 < ex.length; ++j) {
                assertTrue(ex[j].target != key, "key is never a target");
                if (ex[j].target == collateralToken) {
                    (address spender,) = abi.decode(BytesLib.slice(ex[j].callData, 4, 64), (address, uint256));
                    assertEq(spender, spoke, "approve spender is the Spoke");
                } else {
                    assertEq(ex[j].target, spoke, "provider target is the Spoke");
                }
            }
        }
    }

    function test_Standalone_Build_RevertIf_ZeroAddress() public {
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
            _build(hooks[i], _encodeFor(i, address(0), collateralToken, spoke, SUPPLY_ID, BORROW_ID, amount1, 0, false));
            vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
            _build(hooks[i], _encodeFor(i, loanToken, address(0), spoke, SUPPLY_ID, BORROW_ID, amount1, 0, false));
            vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
            _build(
                hooks[i], _encodeFor(i, loanToken, collateralToken, address(0), SUPPLY_ID, BORROW_ID, amount1, 0, false)
            );
        }
    }

    /// @dev Both ids are bound on every hook (incl. the borrow reserve on PLEDGE/RELEASE, which never
    ///      touch it) — on build AND preExecute, before any Spoke call.
    function test_Standalone_Build_RevertIf_ReserveMismatch() public {
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            bytes memory swapped =
                _encodeFor(i, loanToken, collateralToken, spoke, BORROW_ID, SUPPLY_ID, amount1, 0, false);
            bytes memory badBorrow = _encodeFor(i, loanToken, collateralToken, spoke, SUPPLY_ID, 9, amount1, 0, false);
            vm.expectRevert(BaseAaveV4LoanHookV2.TOKEN_RESERVE_MISMATCH.selector);
            _build(hooks[i], swapped);
            vm.expectRevert(BaseAaveV4LoanHookV2.TOKEN_RESERVE_MISMATCH.selector);
            _build(hooks[i], badBorrow);
            vm.expectRevert(BaseAaveV4LoanHookV2.TOKEN_RESERVE_MISMATCH.selector);
            hooks[i].preExecute(address(prevHook), address(this), swapped);
        }
    }

    function test_Standalone_Build_RevertIf_IdenticalTokens() public {
        bytes memory data = _encode(collateralToken, collateralToken, spoke, SUPPLY_ID, BORROW_ID, amount1, 0, false);
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            vm.expectRevert(BaseLoanHookV2.IDENTICAL_TOKENS.selector);
            _build(hooks[i], data);
        }
    }

    /*//////////////////////////////////////////////////////////////
                          11-16. AMOUNT RULES
    //////////////////////////////////////////////////////////////*/

    function test_Standalone_Build_RevertIf_ZeroAmount() public {
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
            _build(hooks[i], _dataFor(i, 0, false));
        }
    }

    function test_PledgeBorrow_Build_RevertIf_MaxAmount() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        _build(_hooks()[0], _data(MAX, false));
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        _build(_hooks()[1], _dataB(MAX, false));
    }

    /// @dev The sentinel passes through to the Spoke (native full withdrawal) while the expected
    ///      receipt is the pre-read supplied position.
    function test_Release_Build_MaxSentinel_PassesThroughAndResolvesExpected() public {
        Execution[] memory ex = _build(_hooks()[2], _data(MAX, false));
        assertEq(ex.length, 3);
        assertEq(ex[1].callData, abi.encodeCall(IAaveV4Spoke.withdraw, (SUPPLY_ID, MAX, address(this))));
        releaseHook.preExecute(address(prevHook), address(this), _data(MAX, false));
        assertEq(releaseHook.expectedPrimaryAmount(), SUPPLIED);
    }

    function test_Release_Build_MaxSentinel_RevertIf_ZeroSupplied() public {
        mockSpoke.setUserSuppliedAssets(SUPPLY_ID, address(this), 0);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        _build(_hooks()[2], _data(MAX, false));
    }

    /// @dev Aave silently converts an over-withdrawal into a full withdrawal; the hook refuses it
    ///      before the call with a specific error instead of failing later as DELTA_MISMATCH.
    function test_Release_Build_RevertIf_ExactAboveSupplied() public {
        vm.expectRevert(
            abi.encodeWithSelector(BaseAaveV4LoanHookV2.WITHDRAW_EXCEEDS_SUPPLIED.selector, SUPPLIED + 1, SUPPLIED)
        );
        _build(_hooks()[2], _data(SUPPLIED + 1, false));
        // exactly the position is fine, and it takes the EXACT path (no sentinel substitution)
        Execution[] memory ex = _build(_hooks()[2], _data(SUPPLIED, false));
        assertEq(ex.length, 3);
        assertEq(ex[1].callData, abi.encodeCall(IAaveV4Spoke.withdraw, (SUPPLY_ID, SUPPLIED, address(this))));
    }

    function test_Release_Build_RevertIf_ZeroSupplied_ExactPath() public {
        mockSpoke.setUserSuppliedAssets(SUPPLY_ID, address(this), 0);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        _build(_hooks()[2], _data(amount1, false));
    }

    /*//////////////////////////////////////////////////////////////
                    MODE PARTITION (LOAN vs idle MONEY_MARKET)
    //////////////////////////////////////////////////////////////*/

    /// @dev An un-flagged supplied position is the idle MONEY_MARKET side's (ledger-tracked): PLEDGE refuses
    ///      to flip it into LOAN mode, on build and on preExecute alike, before any Spoke call.
    function test_Pledge_Build_RevertIf_IdlePositionOnReserve() public {
        mockSpoke.setUsingAsCollateral(SUPPLY_ID, false, address(this));
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_HAS_IDLE_POSITION.selector);
        _build(_hooks()[0], _data(amount1, false));
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_HAS_IDLE_POSITION.selector);
        pledgeHook.preExecute(address(prevHook), address(this), _data(amount1, false));
    }

    /// @dev A fresh reserve (no position, flag false) and an already-flagged reserve both pledge normally
    function test_Pledge_Build_FreshOrFlaggedReserve_Passes() public {
        mockSpoke.setUsingAsCollateral(SUPPLY_ID, false, address(this));
        mockSpoke.setUserSuppliedAssets(SUPPLY_ID, address(this), 0);
        assertEq(_build(_hooks()[0], _data(amount1, false)).length, 7, "fresh reserve");
        mockSpoke.setUsingAsCollateral(SUPPLY_ID, true, address(this));
        mockSpoke.setUserSuppliedAssets(SUPPLY_ID, address(this), SUPPLIED);
        Execution[] memory ex = _build(_hooks()[0], _data(amount1, false));
        assertEq(ex.length, 7, "already flagged");
        // the enable call is emitted unconditionally (idempotent on the Spoke) — the hook never reads the flag to
        // skip it
        assertEq(ex[4].callData, abi.encodeCall(IAaveV4Spoke.setUsingAsCollateral, (SUPPLY_ID, true, address(this))));
        // fourth cell of the (flag, supplied) table: flag true with an emptied position (after a full release)
        // re-pledges
        mockSpoke.setUserSuppliedAssets(SUPPLY_ID, address(this), 0);
        assertEq(_build(_hooks()[0], _data(amount1, false)).length, 7, "flagged + empty: re-pledge allowed");
    }

    /// @dev RELEASE is the LOAN-mode exit: an un-flagged position is refused on every amount path, so the
    ///      hook can never pay an idle (ledger-tracked) position out without a ledger outflow.
    function test_Release_Build_RevertIf_NotCollateral() public {
        mockSpoke.setUsingAsCollateral(SUPPLY_ID, false, address(this));
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_NOT_COLLATERAL.selector);
        _build(_hooks()[2], _data(MAX, false));
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_NOT_COLLATERAL.selector);
        _build(_hooks()[2], _data(amount1, false));
        prevHook.setOutAmount(amount1);
        prevHook.setOutToken(collateralToken);
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_NOT_COLLATERAL.selector);
        _build(_hooks()[2], _data(0, true));
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_NOT_COLLATERAL.selector);
        releaseHook.preExecute(address(prevHook), address(this), _data(amount1, false));
    }

    /*//////////////////////////////////////////////////////////////
                          17-24. PREV-HOOK PIPE
    //////////////////////////////////////////////////////////////*/

    function test_Standalone_Build_RevertIf_UsePrevWithZeroPrevHook() public {
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
            ISuperHook(address(hooks[i])).build(address(0), address(this), _dataFor(i, amount1, true));
        }
    }

    function test_Standalone_Build_RevertIf_PrevTokenMismatch() public {
        prevHook.setOutAmount(amount1);
        // pledge / release consume the collateral token; feed the loan token
        prevHook.setOutToken(loanToken);
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        _build(_hooks()[0], _data(0, true));
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        _build(_hooks()[2], _data(0, true));
        // borrow consumes the loan token; feed the collateral token
        prevHook.setOutToken(collateralToken);
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        _build(_hooks()[1], _dataB(0, true));
    }

    function test_Standalone_Build_RevertIf_ZeroPrevAmount() public {
        prevHook.setOutAmount(0);
        prevHook.setOutToken(collateralToken);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        _build(_hooks()[0], _data(amount1, true));
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        _build(_hooks()[2], _data(amount1, true));
        prevHook.setOutToken(loanToken);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        _build(_hooks()[1], _dataB(amount1, true));
    }

    function test_Standalone_Build_RevertIf_MaxPrevAmount() public {
        prevHook.setOutAmount(MAX);
        prevHook.setOutToken(collateralToken);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        _build(_hooks()[0], _data(amount1, true));
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        _build(_hooks()[2], _data(amount1, true));
    }

    function test_Pledge_Build_UsePrev_SubstitutesPrimaryAndIgnoresWord() public {
        prevHook.setOutAmount(7e18);
        prevHook.setOutToken(collateralToken);
        Execution[] memory ex = _build(_hooks()[0], _data(123, true));
        assertEq(ex.length, 7);
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (spoke, 7e18)));
        assertEq(ex[3].callData, abi.encodeCall(IAaveV4Spoke.supply, (SUPPLY_ID, 7e18, address(this))));
    }

    function test_Borrow_Build_UsePrev_SubstitutesPrimary() public {
        prevHook.setOutAmount(4e18);
        prevHook.setOutToken(loanToken);
        Execution[] memory ex = _build(_hooks()[1], _dataB(123, true));
        assertEq(ex[1].callData, abi.encodeCall(IAaveV4Spoke.borrow, (BORROW_ID, 4e18, address(this))));
    }

    function test_Release_Build_UsePrev_IgnoresMaxWord() public {
        prevHook.setOutAmount(2e18);
        prevHook.setOutToken(collateralToken);
        Execution[] memory ex = _build(_hooks()[2], _data(MAX, true));
        assertEq(ex[1].callData, abi.encodeCall(IAaveV4Spoke.withdraw, (SUPPLY_ID, 2e18, address(this))));
    }

    function test_Release_Build_UsePrev_RevertIf_AboveSupplied() public {
        prevHook.setOutAmount(SUPPLIED + 1);
        prevHook.setOutToken(collateralToken);
        vm.expectRevert(
            abi.encodeWithSelector(BaseAaveV4LoanHookV2.WITHDRAW_EXCEEDS_SUPPLIED.selector, SUPPLIED + 1, SUPPLIED)
        );
        _build(_hooks()[2], _data(0, true));
    }

    function test_Release_Build_UsePrev_EqualsSupplied_Passes() public {
        prevHook.setOutAmount(SUPPLIED);
        prevHook.setOutToken(collateralToken);
        Execution[] memory ex = _build(_hooks()[2], _data(0, true));
        assertEq(ex[1].callData, abi.encodeCall(IAaveV4Spoke.withdraw, (SUPPLY_ID, SUPPLIED, address(this))));
        releaseHook.preExecute(address(prevHook), address(this), _data(0, true));
        assertEq(releaseHook.expectedPrimaryAmount(), SUPPLIED);
    }

    /*//////////////////////////////////////////////////////////////
                          25-27. BUILD SHAPES
    //////////////////////////////////////////////////////////////*/

    function test_Pledge_Build_Shape() public view {
        Execution[] memory ex = _build(_hooks()[0], _data(amount1, false));
        assertEq(ex.length, 7); // pre + 5 + post
        assertEq(bytes4(ex[0].callData), BaseHook.preExecute.selector);
        assertEq(ex[1].target, collateralToken);
        assertEq(ex[1].callData, abi.encodeCall(IERC20.approve, (spoke, 0)));
        assertEq(ex[2].target, collateralToken);
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (spoke, amount1)));
        assertEq(ex[3].target, spoke);
        assertEq(ex[3].callData, abi.encodeCall(IAaveV4Spoke.supply, (SUPPLY_ID, amount1, address(this))));
        assertEq(ex[4].target, spoke);
        assertEq(ex[4].callData, abi.encodeCall(IAaveV4Spoke.setUsingAsCollateral, (SUPPLY_ID, true, address(this))));
        assertEq(ex[5].target, collateralToken);
        assertEq(ex[5].callData, abi.encodeCall(IERC20.approve, (spoke, 0)));
        assertEq(bytes4(ex[6].callData), BaseHook.postExecute.selector);
    }

    function test_Borrow_Build_Shape() public view {
        Execution[] memory ex = _build(_hooks()[1], _dataB(amount1, false));
        assertEq(ex.length, 3);
        assertEq(ex[1].target, spoke);
        assertEq(ex[1].callData, abi.encodeCall(IAaveV4Spoke.borrow, (BORROW_ID, amount1, address(this))));
    }

    function test_Release_Build_Shape_ExactAmount() public view {
        Execution[] memory ex = _build(_hooks()[2], _data(amount1, false));
        assertEq(ex.length, 3);
        assertEq(ex[1].target, spoke);
        assertEq(ex[1].callData, abi.encodeCall(IAaveV4Spoke.withdraw, (SUPPLY_ID, amount1, address(this))));
    }

    /*//////////////////////////////////////////////////////////////
                        28-33. SIZING INTERFACE / INSPECT
    //////////////////////////////////////////////////////////////*/

    function test_Standalone_DecodeAmounts_SingleSlot() public view {
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            uint256[] memory a = hooks[i].decodeAmounts(_dataFor(i, 5e18, false));
            assertEq(a.length, 1);
            assertEq(a[0], 5e18);
        }
    }

    function test_Standalone_AmountRoles() public view {
        ISuperHookInflowOutflow.AmountMeta[] memory m = pledgeHook.amountRoles("");
        assertEq(m.length, 1);
        assertEq(uint256(m[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(m[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));
        m = borrowHook.amountRoles("");
        assertEq(m.length, 1);
        assertEq(uint256(m[0].dir), uint256(ISuperHookInflowOutflow.Direction.OUT));
        assertEq(uint256(m[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));
        m = releaseHook.amountRoles("");
        assertEq(m.length, 1);
        assertEq(uint256(m[0].dir), uint256(ISuperHookInflowOutflow.Direction.OUT));
        assertEq(uint256(m[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));
    }

    function test_Standalone_ReplaceCalldataAmounts_SingleSlot() public {
        uint256[] memory one = new uint256[](1);
        one[0] = 2e18;
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            bytes memory data = _dataFor(i, amount1, false);
            bytes memory replaced = hooks[i].replaceCalldataAmounts(data, one);
            assertEq(replaced.length, 241);
            assertEq(hooks[i].decodeAmounts(replaced)[0], 2e18);
            assertEq(BytesLib.toUint256(replaced, 208), 0, "reserved word untouched");
            assertEq(_build(hooks[i], replaced).length, i == 0 ? 7 : 3, "replaced payload still builds");
            vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
            hooks[i].replaceCalldataAmounts(data, new uint256[](2));
            vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
            hooks[i].replaceCalldataAmounts(data, new uint256[](0));
        }
    }

    /// @dev The sizing views run the same strict decode as build(): no payload the builder rejects
    ///      can be sized or rewritten.
    function test_Standalone_SizingApi_RejectsMalformedPayloads() public {
        bytes memory good = _data(amount1, false);
        bytes memory short = BytesLib.slice(good, 0, 240);
        bytes memory nonzeroSecondary =
            _encode(loanToken, collateralToken, spoke, SUPPLY_ID, BORROW_ID, amount1, 1, false);
        bytes memory badBool = _data(amount1, false);
        badBool[240] = 0x02;
        bytes memory zeroSpoke =
            _encode(loanToken, collateralToken, address(0), SUPPLY_ID, BORROW_ID, amount1, 0, false);
        bytes memory identical = _encode(loanToken, loanToken, spoke, SUPPLY_ID, BORROW_ID, amount1, 0, false);
        uint256[] memory one = new uint256[](1);
        one[0] = 1;
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
            hooks[i].decodeAmounts(short);
            vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
            hooks[i].replaceCalldataAmounts(short, one);
            vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
            hooks[i].decodeAmounts(nonzeroSecondary);
            vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
            hooks[i].replaceCalldataAmounts(nonzeroSecondary, one);
            vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
            hooks[i].decodeAmounts(badBool);
            vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
            hooks[i].replaceCalldataAmounts(zeroSpoke, one);
            vm.expectRevert(BaseLoanHookV2.IDENTICAL_TOKENS.selector);
            hooks[i].decodeAmounts(identical);
        }
    }

    function test_Standalone_DecodeUsePrevHookAmount() public view {
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            assertTrue(hooks[i].decodeUsePrevHookAmount(_dataFor(i, amount1, true)));
            assertFalse(hooks[i].decodeUsePrevHookAmount(_dataFor(i, amount1, false)));
        }
    }

    function test_Standalone_Inspect_MarketIdentityOnly() public view {
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            // SUP-21239: every leg of the market inspects to the SAME payload — the market key, then the
            // unchanged 124 bytes of market identity
            bytes memory expected = abi.encodePacked(
                _marketKey(spoke, SUPPLY_ID, BORROW_ID), spoke, loanToken, collateralToken, SUPPLY_ID, BORROW_ID
            );
            assertEq(expected.length, 144);
            assertEq(hooks[i].inspect(_dataFor(i, amount1, false)), expected, "key first, then market identity");
            assertEq(hooks[i].inspect(_dataFor(i, MAX, true)), expected, "amount / usePrev are not identity");
            assertTrue(
                keccak256(
                    hooks[i].inspect(
                        _encodeFor(
                            i, loanToken, collateralToken, address(otherSpoke), SUPPLY_ID, BORROW_ID, amount1, 0, false
                        )
                    )
                ) != keccak256(expected),
                "spoke (and therefore the key) is identity"
            );
            assertTrue(
                keccak256(
                    hooks[i].inspect(_encodeFor(i, loanToken, collateralToken, spoke, SUPPLY_ID, 3, amount1, 0, false))
                ) != keccak256(expected),
                "borrow id is identity"
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                        34-41. SETTLE ROUND TRIPS
    //////////////////////////////////////////////////////////////*/

    function test_Pledge_SettleRoundTrip() public {
        bytes memory data = _data(amount1, false);
        mockCollateralToken.mint(address(this), amount1);
        pledgeHook.preExecute(address(0), address(this), data);
        mockCollateralToken.transfer(BURN, amount1); // provider leg: collateral leaves the wallet
        pledgeHook.postExecute(address(0), address(this), data);
        assertEq(pledgeHook.getOutAmount(address(this)), 0, "terminal: spend is not a product");
        assertEq(pledgeHook.getOutToken(address(this)), collateralToken);
    }

    function test_Pledge_Settle_RevertIf_DeltaMismatch() public {
        bytes memory data = _data(amount1, false);
        mockCollateralToken.mint(address(this), amount1);
        pledgeHook.preExecute(address(0), address(this), data);
        mockCollateralToken.transfer(BURN, amount1 - 1);
        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, amount1, amount1 - 1));
        pledgeHook.postExecute(address(0), address(this), data);
    }

    function test_Pledge_Settle_RevertIf_NegativeDelta() public {
        bytes memory data = _data(amount1, false);
        pledgeHook.preExecute(address(0), address(this), data);
        mockCollateralToken.mint(address(this), 1);
        vm.expectRevert(BaseLoanHookV2.NEGATIVE_BALANCE_DELTA.selector);
        pledgeHook.postExecute(address(0), address(this), data);
    }

    function test_Borrow_SettleRoundTrip() public {
        bytes memory dataB = _dataB(amount1, false);
        borrowHook.preExecute(address(0), address(this), dataB);
        mockLoanToken.mint(address(this), amount1); // provider leg: borrowed assets arrive
        borrowHook.postExecute(address(0), address(this), dataB);
        assertEq(borrowHook.getOutAmount(address(this)), amount1);
        assertEq(borrowHook.getOutToken(address(this)), loanToken);
    }

    function test_Borrow_Settle_RevertIf_ShortDelivery() public {
        bytes memory dataB = _dataB(amount1, false);
        borrowHook.preExecute(address(0), address(this), dataB);
        mockLoanToken.mint(address(this), amount1 - 1);
        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, amount1, amount1 - 1));
        borrowHook.postExecute(address(0), address(this), dataB);
    }

    function test_Release_SettleRoundTrip_ExactAmount() public {
        bytes memory data = _data(amount1, false);
        releaseHook.preExecute(address(0), address(this), data);
        mockCollateralToken.mint(address(this), amount1);
        releaseHook.postExecute(address(0), address(this), data);
        assertEq(releaseHook.getOutAmount(address(this)), amount1);
        assertEq(releaseHook.getOutToken(address(this)), collateralToken);
    }

    function test_Release_SettleRoundTrip_MaxSentinel() public {
        bytes memory data = _data(MAX, false);
        releaseHook.preExecute(address(0), address(this), data);
        mockCollateralToken.mint(address(this), SUPPLIED); // the sentinel resolved to the full position
        releaseHook.postExecute(address(0), address(this), data);
        assertEq(releaseHook.getOutAmount(address(this)), SUPPLIED);
        assertEq(releaseHook.getOutToken(address(this)), collateralToken);
    }

    function test_Release_Settle_RevertIf_ShortDelivery() public {
        bytes memory data = _data(amount1, false);
        releaseHook.preExecute(address(0), address(this), data);
        mockCollateralToken.mint(address(this), amount1 - 1);
        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, amount1, amount1 - 1));
        releaseHook.postExecute(address(0), address(this), data);
    }

    /*//////////////////////////////////////////////////////////////
                42-49. VALIDATION ORDER / PRE-EXECUTE PARITY
    //////////////////////////////////////////////////////////////*/

    /// @dev Every amount rule build() enforces is re-enforced by preExecute (the executor calls both in the same
    ///      transaction, but a payload must never pass one and fail the other)
    function test_Standalone_PreExecute_MirrorsBuildAmountRules() public {
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
            hooks[i].preExecute(address(prevHook), address(this), _dataFor(i, 0, false));
            vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
            hooks[i].preExecute(address(0), address(this), _dataFor(i, amount1, true));
        }
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        pledgeHook.preExecute(address(prevHook), address(this), _data(MAX, false));
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        borrowHook.preExecute(address(prevHook), address(this), _dataB(MAX, false));
        vm.expectRevert(
            abi.encodeWithSelector(BaseAaveV4LoanHookV2.WITHDRAW_EXCEEDS_SUPPLIED.selector, SUPPLIED + 1, SUPPLIED)
        );
        releaseHook.preExecute(address(prevHook), address(this), _data(SUPPLIED + 1, false));
        prevHook.setOutAmount(amount1);
        prevHook.setOutToken(loanToken);
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        pledgeHook.preExecute(address(prevHook), address(this), _data(0, true));
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        releaseHook.preExecute(address(prevHook), address(this), _data(0, true));
    }

    /// @dev RELEASE reads the position before anything else: an empty position is AMOUNT_NOT_VALID even when the
    ///      flag is also missing and even when the prev pipe would fail — the Spoke pre-read is the first gate
    function test_Release_ValidationOrder_EmptyPositionFirst() public {
        mockSpoke.setUserSuppliedAssets(SUPPLY_ID, address(this), 0);
        mockSpoke.setUsingAsCollateral(SUPPLY_ID, false, address(this));
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        _build(_hooks()[2], _data(amount1, false));
        // prev pipe never consulted: zero prevHook would otherwise be ADDRESS_NOT_VALID
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        ISuperHook(address(releaseHook)).build(address(0), address(this), _data(0, true));
    }

    /// @dev RELEASE checks the collateral flag before resolving the prev pipe (flag false + broken pipe =>
    ///      RESERVE_NOT_COLLATERAL, not ADDRESS_NOT_VALID)
    function test_Release_ValidationOrder_FlagBeforePrevPipe() public {
        mockSpoke.setUsingAsCollateral(SUPPLY_ID, false, address(this));
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_NOT_COLLATERAL.selector);
        ISuperHook(address(releaseHook)).build(address(0), address(this), _data(0, true));
    }

    /// @dev PLEDGE's idle-mode guard runs before the prev pipe: an idle position is refused with its specific error
    ///      even when the previous hook is unset or mismatched
    function test_Pledge_ValidationOrder_IdleGuardBeforePrevPipe() public {
        mockSpoke.setUsingAsCollateral(SUPPLY_ID, false, address(this));
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_HAS_IDLE_POSITION.selector);
        ISuperHook(address(pledgeHook)).build(address(0), address(this), _data(0, true));
        prevHook.setOutAmount(amount1);
        prevHook.setOutToken(loanToken); // would be PREV_TOKEN_MISMATCH
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_HAS_IDLE_POSITION.selector);
        _build(_hooks()[0], _data(0, true));
    }

    /// @dev Reserve binding precedes every amount / mode rule on all three hooks (mismatch with a zero amount and
    ///      a broken pipe still reports TOKEN_RESERVE_MISMATCH)
    function test_Standalone_ValidationOrder_ReserveBindingFirst() public {
        mockSpoke.setUserSuppliedAssets(SUPPLY_ID, address(this), 0);
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            // header keyed consistently with the (unlisted) body id, so the Spoke binding is the first live gate
            bytes memory bad = _encodeFor(i, loanToken, collateralToken, spoke, SUPPLY_ID, 9, 0, 0, true);
            vm.expectRevert(BaseAaveV4LoanHookV2.TOKEN_RESERVE_MISMATCH.selector);
            ISuperHook(address(hooks[i])).build(address(0), address(this), bad);
        }
    }

    /// @dev The position and flag are read on the calldata supply reserve of the calldata Spoke — never on the
    ///      borrow reserve or another Spoke
    function test_Standalone_ReadsCalldataSpokeAndSupplyReserve() public {
        // position only on the borrow reserve: RELEASE sees an empty supply reserve
        mockSpoke.setUserSuppliedAssets(SUPPLY_ID, address(this), 0);
        mockSpoke.setUserSuppliedAssets(BORROW_ID, address(this), SUPPLIED);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        _build(_hooks()[2], _data(MAX, false));
        // idle position on the OTHER spoke does not block a pledge on mockSpoke (fresh there), and vice versa
        mockSpoke.setUserSuppliedAssets(SUPPLY_ID, address(this), 0);
        mockSpoke.setUsingAsCollateral(SUPPLY_ID, false, address(this));
        otherSpoke.setUserSuppliedAssets(SUPPLY_ID, address(this), SUPPLIED);
        assertEq(_build(_hooks()[0], _data(amount1, false)).length, 7, "mockSpoke is fresh");
        bytes memory onOther =
            _encode(loanToken, collateralToken, address(otherSpoke), SUPPLY_ID, BORROW_ID, amount1, 0, false);
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_HAS_IDLE_POSITION.selector);
        _build(_hooks()[0], onOther);
    }

    /// @dev The `account` argument (not msg.sender) selects the position, the flag and the wallet measured
    function test_Standalone_AccountParameterIsAuthoritative() public {
        address alice = makeAddr("alice");
        // alice has no position: RELEASE for alice reverts although this contract's position is 3e18
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        ISuperHook(address(releaseHook)).build(address(prevHook), alice, _data(amount1, false));
        // give alice a flagged position and settle a release against ALICE's wallet delta
        mockSpoke.setUserSuppliedAssets(SUPPLY_ID, alice, SUPPLIED);
        mockSpoke.setUsingAsCollateral(SUPPLY_ID, true, alice);
        Execution[] memory ex = ISuperHook(address(releaseHook)).build(address(prevHook), alice, _data(amount1, false));
        assertEq(ex[1].callData, abi.encodeCall(IAaveV4Spoke.withdraw, (SUPPLY_ID, amount1, alice)), "onBehalfOf=alice");
        // pre/postExecute are account-authenticated (msg.sender == account)
        vm.expectRevert(BaseHook.UNAUTHORIZED_CALLER.selector);
        releaseHook.preExecute(address(0), alice, _data(amount1, false));
        vm.prank(alice);
        releaseHook.preExecute(address(0), alice, _data(amount1, false));
        mockCollateralToken.mint(address(this), amount1); // wrong wallet moves: alice's delta is still zero
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, amount1, 0));
        releaseHook.postExecute(address(0), alice, _data(amount1, false));
        mockCollateralToken.mint(alice, amount1);
        vm.prank(alice);
        releaseHook.postExecute(address(0), alice, _data(amount1, false));
        assertEq(releaseHook.getOutAmount(alice), amount1);
        assertEq(releaseHook.getOutToken(alice), collateralToken);
        // (per-account output isolation is an executor-assigned execution-context property of BaseHook and is
        // exercised by the fork suite through the real SuperExecutor, not by direct calls here)
    }

    /*//////////////////////////////////////////////////////////////
                    50-55. SETTLE: PREV PATH / OVER-DELIVERY / DIRECTION
    //////////////////////////////////////////////////////////////*/

    /// @dev With usePrevHookAmount the settle expectation is the prev output, not the calldata word
    function test_PledgeBorrow_Settle_UsePrev_ExpectsPrevOutput() public {
        prevHook.setOutAmount(2e18);
        prevHook.setOutToken(collateralToken);
        bytes memory data = _data(123, true);
        bytes memory dataB = _dataB(123, true);
        mockCollateralToken.mint(address(this), 2e18);
        pledgeHook.preExecute(address(prevHook), address(this), data);
        assertEq(pledgeHook.expectedPrimaryAmount(), 2e18);
        mockCollateralToken.transfer(BURN, 123);
        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, 2e18, 123));
        pledgeHook.postExecute(address(prevHook), address(this), data);
        mockCollateralToken.transfer(BURN, 2e18 - 123);
        pledgeHook.postExecute(address(prevHook), address(this), data);
        assertEq(pledgeHook.getOutAmount(address(this)), 0);

        prevHook.setOutToken(loanToken);
        borrowHook.preExecute(address(prevHook), address(this), dataB);
        assertEq(borrowHook.expectedPrimaryAmount(), 2e18);
        mockLoanToken.mint(address(this), 2e18);
        borrowHook.postExecute(address(prevHook), address(this), dataB);
        assertEq(borrowHook.getOutAmount(address(this)), 2e18);
        assertEq(borrowHook.getOutToken(address(this)), loanToken);
    }

    /// @dev Strict equality also rejects receiving / spending MORE than resolved (a donation or a provider bonus
    ///      mid-batch is a DELTA_MISMATCH, never silently published)
    function test_Standalone_Settle_RevertIf_OverDelivery() public {
        bytes memory data = _data(amount1, false);
        bytes memory dataB = _dataB(amount1, false);
        mockCollateralToken.mint(address(this), amount1 + 1);
        pledgeHook.preExecute(address(0), address(this), data);
        mockCollateralToken.transfer(BURN, amount1 + 1);
        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, amount1, amount1 + 1));
        pledgeHook.postExecute(address(0), address(this), data);

        borrowHook.preExecute(address(0), address(this), dataB);
        mockLoanToken.mint(address(this), amount1 + 1);
        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, amount1, amount1 + 1));
        borrowHook.postExecute(address(0), address(this), dataB);

        releaseHook.preExecute(address(0), address(this), data);
        mockCollateralToken.mint(address(this), amount1 + 1);
        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, amount1, amount1 + 1));
        releaseHook.postExecute(address(0), address(this), data);
    }

    /// @dev A wallet moving the wrong way (produced-token balance dropping on BORROW / RELEASE) is a direction error,
    ///      not a size error
    function test_BorrowRelease_Settle_RevertIf_NegativeDelta() public {
        bytes memory data = _data(amount1, false);
        bytes memory dataB = _dataB(amount1, false);
        mockLoanToken.mint(address(this), 1);
        borrowHook.preExecute(address(0), address(this), dataB);
        mockLoanToken.transfer(BURN, 1);
        vm.expectRevert(BaseLoanHookV2.NEGATIVE_BALANCE_DELTA.selector);
        borrowHook.postExecute(address(0), address(this), dataB);

        mockCollateralToken.mint(address(this), 1);
        releaseHook.preExecute(address(0), address(this), data);
        mockCollateralToken.transfer(BURN, 1);
        vm.expectRevert(BaseLoanHookV2.NEGATIVE_BALANCE_DELTA.selector);
        releaseHook.postExecute(address(0), address(this), data);
    }

    /// @dev Unrelated wallet movement (the OTHER token) never affects a single-leg settle
    function test_Standalone_Settle_IgnoresOtherToken() public {
        bytes memory data = _data(amount1, false);
        bytes memory dataB = _dataB(amount1, false);
        borrowHook.preExecute(address(0), address(this), dataB);
        mockLoanToken.mint(address(this), amount1);
        mockCollateralToken.mint(address(this), 5e18); // noise on the collateral side
        borrowHook.postExecute(address(0), address(this), dataB);
        assertEq(borrowHook.getOutAmount(address(this)), amount1);

        mockCollateralToken.mint(address(this), amount1);
        pledgeHook.preExecute(address(0), address(this), data);
        mockCollateralToken.transfer(BURN, amount1);
        mockLoanToken.mint(address(this), 9e18); // noise on the loan side
        pledgeHook.postExecute(address(0), address(this), data);
        assertEq(pledgeHook.getOutAmount(address(this)), 0);
    }

    /// @dev Zero position + max sentinel + flag missing on preExecute: same first gate as build
    function test_Release_PreExecute_MaxSentinel_RevertIf_ZeroSupplied() public {
        mockSpoke.setUserSuppliedAssets(SUPPLY_ID, address(this), 0);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        releaseHook.preExecute(address(prevHook), address(this), _data(MAX, false));
    }

    /*//////////////////////////////////////////////////////////////
                    56-58. REAL-HOOK CHAINING (NO MOCK PREV)
    //////////////////////////////////////////////////////////////*/

    /// @dev PLEDGE is terminal: chaining a usePrev consumer off it fails closed on the zero output, and its outToken
    ///      alone (collateral) never makes it a valid feeder
    function test_Pledge_AsPrevHook_FailsClosed() public {
        bytes memory data = _data(amount1, false);
        mockCollateralToken.mint(address(this), amount1);
        pledgeHook.preExecute(address(0), address(this), data);
        mockCollateralToken.transfer(BURN, amount1);
        pledgeHook.postExecute(address(0), address(this), data);
        assertEq(pledgeHook.getOutToken(address(this)), collateralToken, "token published for classification");
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        ISuperHook(address(releaseHook)).build(address(pledgeHook), address(this), _data(0, true));
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        ISuperHook(address(pledgeHook)).build(address(pledgeHook), address(this), _data(0, true));
    }

    /// @dev BORROW's published loan-token output is the right denomination for a repay-style consumer and the wrong
    ///      one for PLEDGE / RELEASE (collateral-denominated) — the pipe enforces it on the real producer
    function test_Borrow_AsPrevHook_TokenDenominationEnforced() public {
        bytes memory dataB = _dataB(amount1, false);
        borrowHook.preExecute(address(0), address(this), dataB);
        mockLoanToken.mint(address(this), amount1);
        borrowHook.postExecute(address(0), address(this), dataB);
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        ISuperHook(address(pledgeHook)).build(address(borrowHook), address(this), _data(0, true));
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        ISuperHook(address(releaseHook)).build(address(borrowHook), address(this), _data(0, true));
        // the same output IS accepted by a loan-token consumer: BORROW fed by BORROW's own published amount
        // is a PREV_TOKEN match (self-chaining a hook is a bundler-policy violation, but the pipe itself is exact)
        Execution[] memory ex =
            ISuperHook(address(borrowHook)).build(address(borrowHook), address(this), _dataB(0, true));
        assertEq(ex[1].callData, abi.encodeCall(IAaveV4Spoke.borrow, (BORROW_ID, amount1, address(this))));
    }

    /// @dev RELEASE's published collateral output re-pledges exactly through the real pipe (release -> pledge)
    function test_Release_AsPrevHook_FeedsPledgeExactly() public {
        bytes memory data = _data(amount1, false);
        releaseHook.preExecute(address(0), address(this), data);
        mockCollateralToken.mint(address(this), amount1);
        releaseHook.postExecute(address(0), address(this), data);
        Execution[] memory ex =
            ISuperHook(address(pledgeHook)).build(address(releaseHook), address(this), _data(0, true));
        assertEq(ex[3].callData, abi.encodeCall(IAaveV4Spoke.supply, (SUPPLY_ID, amount1, address(this))));
        pledgeHook.preExecute(address(releaseHook), address(this), _data(0, true));
        assertEq(pledgeHook.expectedPrimaryAmount(), amount1);
    }

    /*//////////////////////////////////////////////////////////////
                    59-61. SIZING SURFACE EDGES
    //////////////////////////////////////////////////////////////*/

    /// @dev decodeAmounts surfaces the raw word (the sentinel included) — informational for the sizer; and a
    ///      rewrite to zero / max is accepted by the pure view but rejected by build() (no rewrite can smuggle an
    ///      amount the builder refuses)
    function test_Standalone_Sizing_RawSentinel_And_RewriteToInvalidRejectedByBuild() public {
        assertEq(releaseHook.decodeAmounts(_data(MAX, false))[0], MAX, "raw sentinel surfaced");
        assertEq(pledgeHook.decodeAmounts(_data(0, false))[0], 0, "views carry no amount semantics");
        assertEq(borrowHook.decodeAmounts(_dataB(MAX, false))[0], MAX);
        uint256[] memory zero = new uint256[](1);
        uint256[] memory max = new uint256[](1);
        max[0] = MAX;
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            bytes memory toZero = hooks[i].replaceCalldataAmounts(_dataFor(i, amount1, false), zero);
            vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
            _build(hooks[i], toZero);
        }
        bytes memory pledgeToMax = pledgeHook.replaceCalldataAmounts(_data(amount1, false), max);
        bytes memory borrowToMax = borrowHook.replaceCalldataAmounts(_dataB(amount1, false), max);
        bytes memory releaseToMax = releaseHook.replaceCalldataAmounts(_data(amount1, false), max);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        _build(_hooks()[0], pledgeToMax);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        _build(_hooks()[1], borrowToMax);
        // on RELEASE a rewrite to max is the legitimate full-withdraw sentinel
        assertEq(_build(_hooks()[2], releaseToMax).length, 3);
    }

    /// @dev replaceCalldataAmounts touches only bytes [176, 208): header, identity, reserved word and bool survive
    function testFuzz_Standalone_Replace_PreservesEveryOtherByte(
        bytes32 header0,
        uint256 original,
        uint256 replacement,
        bool usePrev_
    )
        public
        view
    {
        uint256[] memory one = new uint256[](1);
        one[0] = replacement;
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            bytes memory data = _encodeH(
                header0,
                _marketKey(spoke, SUPPLY_ID, BORROW_ID),
                loanToken,
                collateralToken,
                spoke,
                SUPPLY_ID,
                BORROW_ID,
                original,
                0,
                usePrev_
            );
            bytes memory out = hooks[i].replaceCalldataAmounts(data, one);
            assertEq(out.length, 241);
            assertEq(keccak256(BytesLib.slice(out, 0, 176)), keccak256(BytesLib.slice(data, 0, 176)), "prefix");
            assertEq(BytesLib.toUint256(out, 176), replacement, "amount");
            assertEq(keccak256(BytesLib.slice(out, 208, 33)), keccak256(BytesLib.slice(data, 208, 33)), "suffix");
            assertEq(hooks[i].decodeAmounts(out)[0], replacement);
            assertEq(hooks[i].decodeUsePrevHookAmount(out), usePrev_);
            assertEq(hooks[i].inspect(out), hooks[i].inspect(data), "identity unchanged");
        }
    }

    /// @dev Any boolean byte other than 0x00 / 0x01 is rejected by build and by every sizing view
    function testFuzz_Standalone_NonCanonicalBool_Rejected(uint8 raw) public {
        vm.assume(raw > 1);
        bytes memory data = _data(amount1, false);
        data[240] = bytes1(raw);
        uint256[] memory one = new uint256[](1);
        one[0] = 1;
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
            _build(hooks[i], data);
            vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
            hooks[i].decodeUsePrevHookAmount(data);
            vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
            hooks[i].decodeAmounts(data);
            vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
            hooks[i].replaceCalldataAmounts(data, one);
            vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
            hooks[i].inspect(data);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        62-64. FUZZED AMOUNT BOUNDARIES
    //////////////////////////////////////////////////////////////*/

    /// @dev RELEASE exact path: every word in (0, supplied] builds with that exact word and resolves the same
    ///      expected receipt; every word in (supplied, max) is refused before the Spoke call
    function testFuzz_Release_ExactBoundary(uint256 supplied, uint256 word) public {
        supplied = bound(supplied, 1, MAX - 1);
        word = bound(word, 1, MAX - 1);
        mockSpoke.setUserSuppliedAssets(SUPPLY_ID, address(this), supplied);
        if (word <= supplied) {
            Execution[] memory ex = _build(_hooks()[2], _data(word, false));
            assertEq(ex[1].callData, abi.encodeCall(IAaveV4Spoke.withdraw, (SUPPLY_ID, word, address(this))));
            releaseHook.preExecute(address(prevHook), address(this), _data(word, false));
            assertEq(releaseHook.expectedPrimaryAmount(), word);
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(BaseAaveV4LoanHookV2.WITHDRAW_EXCEEDS_SUPPLIED.selector, word, supplied)
            );
            _build(_hooks()[2], _data(word, false));
        }
    }

    /// @dev PLEDGE / BORROW exact path: any word in (0, max) is emitted verbatim on the provider call and becomes the
    ///      settle expectation; there is no cap, ratio or position check on these two hooks
    function testFuzz_PledgeBorrow_ExactWordPassesThrough(uint256 word) public {
        word = bound(word, 1, MAX - 1);
        Execution[] memory ex = _build(_hooks()[0], _data(word, false));
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (spoke, word)));
        assertEq(ex[3].callData, abi.encodeCall(IAaveV4Spoke.supply, (SUPPLY_ID, word, address(this))));
        pledgeHook.preExecute(address(prevHook), address(this), _data(word, false));
        assertEq(pledgeHook.expectedPrimaryAmount(), word);
        ex = _build(_hooks()[1], _dataB(word, false));
        assertEq(ex[1].callData, abi.encodeCall(IAaveV4Spoke.borrow, (BORROW_ID, word, address(this))));
        borrowHook.preExecute(address(prevHook), address(this), _dataB(word, false));
        assertEq(borrowHook.expectedPrimaryAmount(), word);
    }

    /// @dev Prev pipe: the calldata word is fully ignored on all three hooks whenever usePrevHookAmount is set
    function testFuzz_Standalone_UsePrev_IgnoresWord(uint256 word, uint256 prevOut) public {
        prevOut = bound(prevOut, 1, SUPPLIED);
        prevHook.setOutAmount(prevOut);
        prevHook.setOutToken(collateralToken);
        assertEq(
            _build(_hooks()[0], _data(word, true))[3].callData,
            abi.encodeCall(IAaveV4Spoke.supply, (SUPPLY_ID, prevOut, address(this)))
        );
        assertEq(
            _build(_hooks()[2], _data(word, true))[1].callData,
            abi.encodeCall(IAaveV4Spoke.withdraw, (SUPPLY_ID, prevOut, address(this)))
        );
        prevHook.setOutToken(loanToken);
        assertEq(
            _build(_hooks()[1], _dataB(word, true))[1].callData,
            abi.encodeCall(IAaveV4Spoke.borrow, (BORROW_ID, prevOut, address(this)))
        );
    }

    /*//////////////////////////////////////////////////////////////
                    65-71. CATALOG GAPS (post-review additions)
    //////////////////////////////////////////////////////////////*/

    function test_Borrow_Build_RevertIf_MaxPrevAmount() public {
        prevHook.setOutAmount(MAX);
        prevHook.setOutToken(loanToken);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        _build(_hooks()[1], _dataB(amount1, true));
    }

    /// @dev preExecute snapshots BOTH wallets and never touches the secondary expectation on a single-leg hook
    function test_Standalone_PreExecute_SnapshotsAndSecondaryUnused() public {
        mockLoanToken.mint(address(this), 11);
        mockCollateralToken.mint(address(this), 22);
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            hooks[i].preExecute(address(prevHook), address(this), _dataFor(i, amount1, false));
            assertEq(hooks[i].expectedPrimaryAmount(), amount1);
            assertEq(hooks[i].expectedSecondaryAmount(), 0, "no second leg");
            assertEq(hooks[i].preLoanTokenBalance(), 11);
            assertEq(hooks[i].preCollateralTokenBalance(), 22);
        }
    }

    /// @dev With usePrevHookAmount = false, live outputs on the previous hook are ignored: the word wins
    function test_Standalone_WordPath_IgnoresPrevHookOutputs() public {
        prevHook.setOutAmount(9e18);
        prevHook.setOutToken(collateralToken);
        assertEq(
            _build(_hooks()[0], _data(amount1, false))[3].callData,
            abi.encodeCall(IAaveV4Spoke.supply, (SUPPLY_ID, amount1, address(this)))
        );
        assertEq(
            _build(_hooks()[2], _data(amount1, false))[1].callData,
            abi.encodeCall(IAaveV4Spoke.withdraw, (SUPPLY_ID, amount1, address(this)))
        );
        prevHook.setOutToken(loanToken);
        assertEq(
            _build(_hooks()[1], _dataB(amount1, false))[1].callData,
            abi.encodeCall(IAaveV4Spoke.borrow, (BORROW_ID, amount1, address(this)))
        );
    }

    /// @dev inspect() is the pure strict decoder: malformed bytes revert, the header key is pinned (wrong key reverts),
    /// but reserve binding (a Spoke read) is NOT part of it — a mismatched-but-well-formed, correctly keyed payload
    /// still
    ///      yields its identity, key first
    function test_Standalone_Inspect_StrictAndBound() public {
        bytes memory good = _data(amount1, false);
        bytes memory short = BytesLib.slice(good, 0, 240);
        bytes memory nonzeroSecondary =
            _encode(loanToken, collateralToken, spoke, SUPPLY_ID, BORROW_ID, amount1, 1, false);
        bytes memory zeroLoan = _encode(address(0), collateralToken, spoke, SUPPLY_ID, BORROW_ID, amount1, 0, false);
        bytes memory identical = _encode(loanToken, loanToken, spoke, SUPPLY_ID, BORROW_ID, amount1, 0, false);
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            // ids swapped but the header keyed consistently with the swapped body: the pure decoder does not
            // bind reserves to the Spoke, so inspect still yields the (swapped) identity, key first. Note the
            // key itself differs from the unswapped market's — the derivation does not sort its ids, so the
            // reversed pair is a DIFFERENT market.
            bytes memory swapped =
                _encodeFor(i, loanToken, collateralToken, spoke, BORROW_ID, SUPPLY_ID, amount1, 0, false);
            vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
            hooks[i].inspect(short);
            vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
            hooks[i].inspect(nonzeroSecondary);
            vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
            hooks[i].inspect(zeroLoan);
            vm.expectRevert(BaseLoanHookV2.IDENTICAL_TOKENS.selector);
            hooks[i].inspect(identical);
            assertEq(
                hooks[i].inspect(swapped),
                abi.encodePacked(
                    _marketKey(spoke, BORROW_ID, SUPPLY_ID), spoke, loanToken, collateralToken, BORROW_ID, SUPPLY_ID
                ),
                "reserve binding is not part of inspect; the header key is"
            );
            // the reversed market's key against an unswapped body: ordering is significant, so this is a
            // different market and the pin must refuse it
            bytes memory wrongKey = abi.encodePacked(
                AAVE_V4_YS_ORACLE_ID, _marketKey(spoke, BORROW_ID, SUPPLY_ID), BytesLib.slice(good, 52, 189)
            );
            vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
            hooks[i].inspect(wrongKey);
        }
    }

    /// @dev Full cross-product of malformed inputs on both sizing views (the earlier test covers one error per view)
    function test_Standalone_SizingApi_MalformedCrossProduct() public {
        bytes memory good = _data(amount1, false);
        bytes memory long = abi.encodePacked(good, bytes1(0));
        bytes memory badBool = _data(amount1, false);
        badBool[240] = 0x02;
        bytes memory zeroLoan = _encode(address(0), collateralToken, spoke, SUPPLY_ID, BORROW_ID, amount1, 0, false);
        bytes memory zeroColl = _encode(loanToken, address(0), spoke, SUPPLY_ID, BORROW_ID, amount1, 0, false);
        bytes memory identical = _encode(loanToken, loanToken, spoke, SUPPLY_ID, BORROW_ID, amount1, 0, false);
        uint256[] memory one = new uint256[](1);
        one[0] = 1;
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
            hooks[i].replaceCalldataAmounts(long, one);
            vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
            hooks[i].replaceCalldataAmounts(badBool, one);
            vm.expectRevert(BaseLoanHookV2.IDENTICAL_TOKENS.selector);
            hooks[i].replaceCalldataAmounts(identical, one);
            vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
            hooks[i].decodeAmounts(zeroLoan);
            vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
            hooks[i].decodeAmounts(zeroColl);
            vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
            hooks[i].replaceCalldataAmounts(zeroColl, one);
        }
    }

    /// @dev A rewrite on a usePrevHookAmount = true payload keeps the flag, and build still takes the prev amount
    function test_Standalone_Replace_KeepsUsePrevFlag_BuildStillUsesPrev() public {
        prevHook.setOutAmount(2e18);
        prevHook.setOutToken(collateralToken);
        uint256[] memory one = new uint256[](1);
        one[0] = 5e18;
        bytes memory replaced = pledgeHook.replaceCalldataAmounts(_data(amount1, true), one);
        assertTrue(pledgeHook.decodeUsePrevHookAmount(replaced));
        assertEq(pledgeHook.decodeAmounts(replaced)[0], 5e18, "word rewritten");
        assertEq(
            _build(_hooks()[0], replaced)[3].callData,
            abi.encodeCall(IAaveV4Spoke.supply, (SUPPLY_ID, 2e18, address(this))),
            "prev output still wins over the rewritten word"
        );
    }

    function test_Standalone_Descriptions_And_InterfaceIds() public view {
        assertEq(
            pledgeHook.description(),
            "Supplies an exact collateral amount to an Aave V4 spoke and enables it as collateral without borrowing"
        );
        assertEq(
            borrowHook.description(),
            "Borrows an exact asset amount from an Aave V4 spoke against already-posted collateral"
        );
        assertEq(
            releaseHook.description(),
            "Withdraws an exact or full collateral amount from an Aave V4 spoke without repaying"
        );
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            assertTrue(hooks[i].supportsInterface(type(ISuperHook).interfaceId));
            assertTrue(hooks[i].supportsInterface(type(ISuperHookResult).interfaceId));
            assertTrue(hooks[i].supportsInterface(type(ISuperHookInspector).interfaceId));
        }
    }

    /*//////////////////////////////////////////////////////////////
                        72-77. THIRD PASS: MORE EDGES
    //////////////////////////////////////////////////////////////*/

    /// @dev Any length other than 241 is refused by build and by every view on all three hooks
    function testFuzz_Standalone_AnyOtherLength_Rejected(uint16 len) public {
        vm.assume(len != 241);
        bytes memory good = _data(amount1, false);
        bytes memory data = len < 241 ? BytesLib.slice(good, 0, len) : abi.encodePacked(good, new bytes(len - 241));
        assertEq(data.length, len);
        uint256[] memory one = new uint256[](1);
        one[0] = 1;
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
            _build(hooks[i], data);
            vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
            hooks[i].decodeAmounts(data);
            vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
            hooks[i].replaceCalldataAmounts(data, one);
            vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
            hooks[i].decodeUsePrevHookAmount(data);
            vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
            hooks[i].inspect(data);
        }
    }

    /// @dev Any nonzero reserved secondary word is refused everywhere (the layout advertises one leg only)
    function testFuzz_Standalone_AnyNonzeroReservedWord_Rejected(uint256 reserved) public {
        vm.assume(reserved != 0);
        bytes memory data = _encode(loanToken, collateralToken, spoke, SUPPLY_ID, BORROW_ID, amount1, reserved, false);
        uint256[] memory one = new uint256[](1);
        one[0] = 1;
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
            _build(hooks[i], data);
            vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
            hooks[i].decodeAmounts(data);
            vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
            hooks[i].replaceCalldataAmounts(data, one);
            vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
            hooks[i].inspect(data);
        }
    }

    /// @dev The collateral flag is read on the SUPPLY reserve: a flag set only on the borrow reserve does not qualify
    function test_Standalone_FlagReadOnSupplyReserveOnly() public {
        mockSpoke.setUsingAsCollateral(SUPPLY_ID, false, address(this));
        mockSpoke.setUsingAsCollateral(BORROW_ID, true, address(this));
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_NOT_COLLATERAL.selector);
        _build(_hooks()[2], _data(MAX, false));
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_HAS_IDLE_POSITION.selector);
        _build(_hooks()[0], _data(amount1, false));
    }

    /// @dev PLEDGE's idle guard and RELEASE's flag check are per account: alice's idle position never blocks this
    ///      account, and this account's flagged position never qualifies alice
    function test_Standalone_ModeGuards_PerAccount() public {
        address alice = makeAddr("alice");
        mockSpoke.setUserSuppliedAssets(SUPPLY_ID, alice, SUPPLIED); // alice idle: supplied, un-flagged
        assertEq(_build(_hooks()[0], _data(amount1, false)).length, 7, "this account pledges normally");
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_HAS_IDLE_POSITION.selector);
        ISuperHook(address(pledgeHook)).build(address(prevHook), alice, _data(amount1, false));
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_NOT_COLLATERAL.selector);
        ISuperHook(address(releaseHook)).build(address(prevHook), alice, _data(MAX, false));
        assertEq(_build(_hooks()[2], _data(MAX, false)).length, 3, "this account releases normally");
    }

    /// @dev Settles are exact for any pre-balance and any amount; a 1-wei deviation either way fails
    function testFuzz_Standalone_Settle_ExactForAnyBalances(uint128 preBal, uint128 amt, bool over) public {
        uint256 amount = bound(uint256(amt), 1, type(uint128).max - 1);
        uint256 pre = bound(uint256(preBal), amount + 1, type(uint128).max);
        bytes memory data = _data(amount, false);
        bytes memory dataB = _dataB(amount, false);
        // BORROW: loan token arrives
        mockLoanToken.mint(address(this), pre);
        borrowHook.preExecute(address(0), address(this), dataB);
        uint256 wrong = over ? amount + 1 : amount - 1;
        if (wrong == 0) {
            mockLoanToken.mint(address(this), 0);
        } else {
            mockLoanToken.mint(address(this), wrong);
        }
        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, amount, wrong));
        borrowHook.postExecute(address(0), address(this), dataB);
        // correct the delta to exact and settle
        if (over) mockLoanToken.transfer(BURN, 1);
        else mockLoanToken.mint(address(this), 1);
        borrowHook.postExecute(address(0), address(this), dataB);
        assertEq(borrowHook.getOutAmount(address(this)), amount);
        // PLEDGE: collateral leaves from a large pre-balance
        mockCollateralToken.mint(address(this), pre);
        pledgeHook.preExecute(address(0), address(this), data);
        mockCollateralToken.transfer(BURN, amount);
        pledgeHook.postExecute(address(0), address(this), data);
        assertEq(pledgeHook.getOutAmount(address(this)), 0);
    }

    /// @dev Malformed previous-hook: a prevHook that is not a hook at all (EOA / no code) fails the pipe before any
    ///      provider call instead of misreading garbage
    function test_Standalone_UsePrev_RevertIf_PrevHookHasNoCode() public {
        address eoa = makeAddr("eoa");
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            vm.expectRevert();
            ISuperHook(address(hooks[i])).build(eoa, address(this), _dataFor(i, amount1, true));
        }
    }

    /// @dev The header oracle id (offset 0) must be nonzero: refused on build, preExecute, inspect and both sizing
    /// views
    function test_Standalone_ZeroOracleId_Refused() public {
        uint256[] memory one = new uint256[](1);
        one[0] = 1;
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            bytes memory good = _dataFor(i, amount1, false);
            bytes memory zeroId = abi.encodePacked(bytes32(0), BytesLib.slice(good, 32, 209));
            vm.expectRevert(BaseAaveV4LoanHookV2.ORACLE_ID_NOT_VALID.selector);
            _build(hooks[i], zeroId);
            vm.expectRevert(BaseAaveV4LoanHookV2.ORACLE_ID_NOT_VALID.selector);
            hooks[i].preExecute(address(prevHook), address(this), zeroId);
            vm.expectRevert(BaseAaveV4LoanHookV2.ORACLE_ID_NOT_VALID.selector);
            hooks[i].inspect(zeroId);
            vm.expectRevert(BaseAaveV4LoanHookV2.ORACLE_ID_NOT_VALID.selector);
            hooks[i].decodeAmounts(zeroId);
            vm.expectRevert(BaseAaveV4LoanHookV2.ORACLE_ID_NOT_VALID.selector);
            hooks[i].replaceCalldataAmounts(zeroId, one);
        }
    }

    /// @dev Header key fuzz, standalone trio: a key over any other reserve id or any other spoke is refused by build,
    ///      preExecute, inspect and both sizing views
    function testFuzz_Standalone_WrongKey_Refused_AllHooks(uint256 otherReserveId, address foreignSpoke) public {
        vm.assume(otherReserveId != SUPPLY_ID && otherReserveId != BORROW_ID);
        vm.assume(foreignSpoke != spoke);
        BaseLoanHookV2[3] memory hooks = _hooks();
        uint256[] memory one = new uint256[](1);
        one[0] = 1;
        for (uint256 i; i < hooks.length; ++i) {
            bytes memory body = BytesLib.slice(_dataFor(i, 1e18, false), 52, 189);
            uint256 primary = i == 1 ? BORROW_ID : SUPPLY_ID;
            bytes[2] memory bad = [
                abi.encodePacked(AAVE_V4_YS_ORACLE_ID, _key(spoke, otherReserveId), body),
                abi.encodePacked(AAVE_V4_YS_ORACLE_ID, _key(foreignSpoke, primary), body)
            ];
            for (uint256 b; b < 2; ++b) {
                vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
                _build(hooks[i], bad[b]);
                vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
                BaseHook(address(hooks[i])).preExecute(address(prevHook), address(this), bad[b]);
                vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
                hooks[i].inspect(bad[b]);
                vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
                hooks[i].decodeAmounts(bad[b]);
                vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
                hooks[i].replaceCalldataAmounts(bad[b], one);
            }
        }
    }

    /// @dev RELEASE over an un-flagged position is RESERVE_NOT_COLLATERAL for ANY amount word (zero, max, exact, above)
    ///      on build and preExecute, while the pure sizing views still size the word
    function testFuzz_Release_UnflaggedPosition_RefusedForAnyWord(uint256 word) public {
        mockSpoke.setUserSuppliedAssets(SUPPLY_ID, address(this), 5e18);
        mockSpoke.setUsingAsCollateral(SUPPLY_ID, false, address(this));
        bytes memory data = _data(word, false);
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_NOT_COLLATERAL.selector);
        _build(BaseLoanHookV2(address(releaseHook)), data);
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_NOT_COLLATERAL.selector);
        releaseHook.preExecute(address(prevHook), address(this), data);
        assertEq(releaseHook.decodeAmounts(data)[0], word, "sizing view is pure");
        assertEq(releaseHook.inspect(data).length, 144, "inspect is pure");
    }
}
