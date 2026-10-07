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
    ISuperHookInspector
} from "../../../../src/interfaces/ISuperHook.sol";
import { IAaveV4Spoke } from "../../../../src/vendor/aave-v4/IAaveV4Spoke.sol";
import { HookSubTypes } from "../../../../src/libraries/HookSubTypes.sol";

// Hooks under test + LOAN siblings (type-flip isolation)
import { BaseLoanHookV2 } from "../../../../src/hooks/loan/BaseLoanHookV2.sol";
import { BaseAaveV4MoneyMarketHook } from "../../../../src/hooks/loan/aave-v4/BaseAaveV4MoneyMarketHook.sol";
import { AaveV4ReserveKey } from "../../../../src/libraries/AaveV4ReserveKey.sol";
import { HookDataDecoder } from "../../../../src/libraries/HookDataDecoder.sol";
import { ISuperHookInspector } from "../../../../src/interfaces/ISuperHook.sol";
import { AaveV4LendHook } from "../../../../src/hooks/loan/aave-v4/AaveV4LendHook.sol";
import { AaveV4RedeemHook } from "../../../../src/hooks/loan/aave-v4/AaveV4RedeemHook.sol";
import { AaveV4SupplyHook } from "../../../../src/hooks/loan/aave-v4/AaveV4SupplyHook.sol";
import { AaveV4WithdrawHook } from "../../../../src/hooks/loan/aave-v4/AaveV4WithdrawHook.sol";
import { AaveV4SupplyAndBorrowHookV2 } from "../../../../src/hooks/loan/aave-v4/AaveV4SupplyAndBorrowHookV2.sol";
import { AaveV4RepayHookV2 } from "../../../../src/hooks/loan/aave-v4/AaveV4RepayHookV2.sol";
import { AaveV4ReserveRegistryV2 } from "../../../../src/accounting/oracles/AaveV4ReserveRegistryV2.sol";
import { AaveV4ReserveOracle } from "../../../../src/accounting/oracles/AaveV4ReserveOracle.sol";
import { SuperLedger } from "../../../../src/accounting/SuperLedger.sol";
import { SuperLedgerConfiguration } from "../../../../src/accounting/SuperLedgerConfiguration.sol";
import { ISuperLedgerConfiguration } from "../../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { IAaveV4MarketRegistry } from "../../../../src/interfaces/accounting/IAaveV4MarketRegistry.sol";

/// @dev Stateful idle-spoke mock: pulls the underlying on supply, credits the position rounded DOWN by
///      `roundDownWei` (Aave's toAddedAssetsDown), pays min(amount, supplied) on withdraw (any amount
///      above the position is a full withdrawal), records every setUsingAsCollateral call.
contract MockAaveV4IdleSpoke {
    uint256 public roundDownWei = 1;
    uint256 public collateralCalls;
    mapping(uint256 reserveId => address underlying) public reserveUnderlying;
    mapping(uint256 reserveId => mapping(address user => uint256 supplied)) public suppliedAssets;
    mapping(uint256 reserveId => mapping(address user => bool)) public isCollateral;
    mapping(uint256 reserveId => mapping(address user => bool)) public isBorrowing;

    function setReserveUnderlying(uint256 reserveId, address underlying) external {
        reserveUnderlying[reserveId] = underlying;
    }

    function setRoundDownWei(uint256 wei_) external {
        roundDownWei = wei_;
    }

    function setSupplied(uint256 reserveId, address user, uint256 amount) external {
        suppliedAssets[reserveId][user] = amount;
    }

    function setCollateral(uint256 reserveId, address user, bool flag) external {
        isCollateral[reserveId][user] = flag;
    }

    function setBorrowing(uint256 reserveId, address user, bool flag) external {
        isBorrowing[reserveId][user] = flag;
    }

    function getReserve(uint256 reserveId) external view returns (IAaveV4Spoke.Reserve memory reserve) {
        reserve.underlying = reserveUnderlying[reserveId];
        reserve.decimals = 6;
    }

    function getUserSuppliedAssets(uint256 reserveId, address user) external view returns (uint256) {
        return suppliedAssets[reserveId][user];
    }

    function getUserDebt(uint256, address) external pure returns (uint256, uint256) {
        return (0, 0);
    }

    function getUserReserveStatus(uint256 reserveId, address user) external view returns (bool, bool) {
        return (isCollateral[reserveId][user], isBorrowing[reserveId][user]);
    }

    function supply(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256) {
        IERC20(reserveUnderlying[reserveId]).transferFrom(msg.sender, address(this), amount);
        uint256 credited = amount > roundDownWei ? amount - roundDownWei : 0;
        suppliedAssets[reserveId][onBehalfOf] += credited;
        return (credited, amount);
    }

    function withdraw(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256) {
        uint256 supplied = suppliedAssets[reserveId][onBehalfOf];
        uint256 paid = amount > supplied ? supplied : amount;
        suppliedAssets[reserveId][onBehalfOf] = supplied - paid;
        IERC20(reserveUnderlying[reserveId]).transfer(msg.sender, paid);
        return (paid, paid);
    }

    function setUsingAsCollateral(uint256 reserveId, bool useAsCollateral, address onBehalfOf) external {
        ++collateralCalls;
        isCollateral[reserveId][onBehalfOf] = useAsCollateral;
    }
}

/// @dev Previous-hook stub with settable output amount and output token
contract MockPrevHookIdle {
    uint256 internal outAmount;
    address internal outToken;

    function set(uint256 amount, address token) external {
        outAmount = amount;
        outToken = token;
    }

    function getOutAmount(address) external view returns (uint256) {
        return outAmount;
    }

    function getOutToken(address) external view returns (address) {
        return outToken;
    }
}

contract AaveV4MoneyMarketHooksTest is Helpers {
    AaveV4LendHook public lendHook;
    AaveV4RedeemHook public redeemHook;
    MockAaveV4IdleSpoke public mockSpoke;
    MockAaveV4IdleSpoke public otherSpoke;
    MockERC20 public usdc;
    MockERC20 public otherToken;
    MockERC20 public thirdToken;
    MockPrevHookIdle public prevHook;
    AaveV4ReserveRegistryV2 public registry;

    address public spoke;
    address public underlying;
    address public account;
    bytes32 public constant ORACLE_ID = keccak256("AaveV4ReserveOracle");
    uint256 public constant RESERVE_ID = 7;
    /// @dev The market's OTHER leg. Since SUP-21263 it is no longer carried in the body — the body has one
    ///      `targetReserveId` — but it still completes the market key, and the registry registration below
    ///      is what the hooks read to decide whether a target is one of the market's legs.
    uint256 public constant BORROW_LEG_ID = 3;
    uint256 public constant AMOUNT = 1000e6;

    function setUp() public {
        mockSpoke = new MockAaveV4IdleSpoke();
        otherSpoke = new MockAaveV4IdleSpoke();
        usdc = new MockERC20("USD Coin", "USDC", 6);
        otherToken = new MockERC20("Other", "OTH", 18);
        thirdToken = new MockERC20("Third", "THD", 18);
        prevHook = new MockPrevHookIdle();

        spoke = address(mockSpoke);
        underlying = address(usdc);
        account = address(this);
        mockSpoke.setReserveUnderlying(RESERVE_ID, underlying);
        mockSpoke.setReserveUnderlying(0, address(otherToken));
        // SUP-21263: the market's other leg needs a DISTINCT underlying or `registerMarket` refuses it
        // (IDENTICAL_UNDERLYINGS), and it must be a real listed reserve or the hooks cannot move it.
        mockSpoke.setReserveUnderlying(BORROW_LEG_ID, address(thirdToken));
        otherSpoke.setReserveUnderlying(RESERVE_ID, underlying);
        otherSpoke.setReserveUnderlying(BORROW_LEG_ID, address(thirdToken));

        // A REAL registry, not a mock: the hooks' identity check is `getMarketInfo`, so the test must
        // exercise the same storage the deployed registry uses. `address(this)` holds MARKET_MANAGER_ROLE.
        registry = new AaveV4ReserveRegistryV2(address(this));
        registry.registerReserve(spoke, RESERVE_ID);
        registry.registerReserve(spoke, BORROW_LEG_ID);
        registry.registerMarket(spoke, RESERVE_ID, BORROW_LEG_ID);

        lendHook = new AaveV4LendHook(address(registry));
        redeemHook = new AaveV4RedeemHook(address(registry));

        usdc.mint(account, 1_000_000e6);
        usdc.mint(address(mockSpoke), 1_000_000e6);
        thirdToken.mint(account, 1_000_000e18);
        thirdToken.mint(address(mockSpoke), 1_000_000e18);
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev A reserve-leg key. After SUP-21254 these are WRONG idle headers — kept because rejecting them
    ///      is the fail-closed property that lets the redeployed idle pair coexist with old roots.
    function _key(address spoke_, uint256 reserveId) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encode(spoke_, reserveId)))));
    }

    /// @dev THE IDLE HEADER since SUP-21254: the market key whose SUPPLY leg is the reserve the op moves.
    ///      Written out as the literal four-word formula, not via the library, so a library edit fails here.
    function _marketKey(address spoke_, uint256 supplyId, uint256 borrowId) internal pure returns (address) {
        return address(
            uint160(uint256(keccak256(abi.encode(spoke_, supplyId, borrowId, keccak256("AaveV4ReserveKey.MARKET")))))
        );
    }

    /// @dev SUP-21263: exactly 157 bytes, ONE reserve word at offset 92 (`targetReserveId`). The appended
    ///      borrow-leg word is gone, so the 8-argument overload that controlled it is gone too.
    function _dataRaw(
        bytes32 oracleId,
        address key,
        address underlying_,
        address spoke_,
        uint256 targetReserveId,
        uint256 amount,
        bytes1 flag
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(oracleId, key, underlying_, spoke_, targetReserveId, amount, flag);
    }

    function _data(uint256 amount, bool usePrev) internal view returns (bytes memory) {
        return _dataRaw(
            ORACLE_ID,
            _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID),
            underlying,
            spoke,
            RESERVE_ID,
            amount,
            usePrev ? bytes1(0x01) : bytes1(0x00)
        );
    }

    function _hasSelector(Execution[] memory executions, bytes4 selector) internal pure returns (bool) {
        for (uint256 i; i < executions.length; ++i) {
            if (executions[i].callData.length >= 4 && bytes4(executions[i].callData) == selector) return true;
        }
        return false;
    }

    /// @dev Runs a hook the way SuperExecutor does: build() returns [preExecute, ...provider calls...,
    ///      postExecute]; every call is issued from the account (this test contract). Reverts bubble up.
    function _run(BaseHook hook, bytes memory data) internal {
        hook.setExecutionContext(account); // fresh context per run, exactly like SuperExecutorBase
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        for (uint256 i; i < executions.length; ++i) {
            (bool ok, bytes memory ret) =
                executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            if (!ok) {
                assembly {
                    revert(add(ret, 32), mload(ret))
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        TYPE / SUBTYPE / INTERFACE
    //////////////////////////////////////////////////////////////*/

    function test_HookTypes_IdleFlipsLoanStays() public {
        assertEq(uint256(lendHook.hookType()), uint256(ISuperHook.HookType.INFLOW), "lend INFLOW");
        assertEq(uint256(redeemHook.hookType()), uint256(ISuperHook.HookType.OUTFLOW), "redeem OUTFLOW");
        assertEq(lendHook.subtype(), HookSubTypes.LOAN);
        assertEq(redeemHook.subtype(), HookSubTypes.LOAN);
        // LOAN siblings are untouched
        assertEq(uint256(new AaveV4SupplyHook().hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(new AaveV4WithdrawHook().hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(new AaveV4SupplyAndBorrowHookV2().hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(new AaveV4RepayHookV2().hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_SupportsInterface_SizingAdvertisedLoansNot() public view {
        assertTrue(lendHook.supportsInterface(type(IERC165).interfaceId));
        assertTrue(lendHook.supportsInterface(type(ISuperHookInflowOutflow).interfaceId));
        assertTrue(lendHook.supportsInterface(type(ISuperHookOutflow).interfaceId));
        assertTrue(redeemHook.supportsInterface(type(ISuperHookInflowOutflow).interfaceId));
        assertTrue(redeemHook.supportsInterface(type(ISuperHookOutflow).interfaceId));
        assertFalse(lendHook.supportsInterface(type(ISuperHookLoans).interfaceId), "loans iface never advertised");
    }

    /// @dev Documented LIMITATION: the inherited ISuperHookLoans getters read LOAN offsets. The loan-token
    ///      getter is truthful (underlying); the collateral getter returns the Spoke and its balance read
    ///      reverts. Never called by the leaves; pinned like EulerRepayHook.
    function test_LoansGetters_LimitationPinned() public {
        bytes memory data = _data(AMOUNT, false);
        assertEq(lendHook.getLoanTokenAddress(data), underlying, "offset 52 = underlying");
        assertEq(lendHook.getCollateralTokenAddress(data), spoke, "offset 72 = spoke, not a token");
        assertEq(lendHook.getLoanTokenBalance(account, data), usdc.balanceOf(account));
        vm.expectRevert();
        lendHook.getCollateralTokenBalance(account, data);
        vm.expectRevert();
        redeemHook.getCollateralTokenBalance(account, data);
    }

    function test_NameAndDescription() public view {
        assertEq(lendHook.name(), "Aave V4 Lend");
        assertEq(redeemHook.name(), "Aave V4 Redeem");
        assertGt(bytes(lendHook.description()).length, 0);
        assertGt(bytes(redeemHook.description()).length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                       KEY DERIVATION (REGISTRY PARITY)
    //////////////////////////////////////////////////////////////*/

    function test_ReserveKey_MatchesRegistryFormula() public view {
        assertEq(_key(spoke, RESERVE_ID), registry.computeReserveKey(spoke, RESERVE_ID));
        assertEq(_key(spoke, 0), registry.computeReserveKey(spoke, 0));
        assertTrue(_key(spoke, 0) != _key(spoke, RESERVE_ID), "reserve ids diverge");
        assertTrue(_key(spoke, RESERVE_ID) != _key(address(otherSpoke), RESERVE_ID), "spokes diverge");
    }

    /// @dev The hook's local key must equal the deployed registry's formula for every (spoke, reserveId)
    function testFuzz_ReserveKey_MatchesRegistryFormula(address spoke_, uint256 reserveId) public view {
        assertEq(_key(spoke_, reserveId), registry.computeReserveKey(spoke_, reserveId));
    }

    /*//////////////////////////////////////////////////////////////
                           STRICT DECODING
    //////////////////////////////////////////////////////////////*/

    function test_Decode_RevertIf_WrongLength() public {
        bytes memory short = _data(AMOUNT, false);
        bytes memory tooShort = BytesLib.slice(short, 0, 156);
        bytes memory tooLong = abi.encodePacked(short, bytes1(0x00));

        bytes4 err = BaseLoanHookV2.INVALID_DATA_LENGTH.selector;
        vm.expectRevert(err);
        lendHook.build(address(0), account, tooShort);
        vm.expectRevert(err);
        lendHook.build(address(0), account, tooLong);
        vm.expectRevert(err);
        redeemHook.build(address(0), account, tooShort);
        vm.expectRevert(err);
        lendHook.inspect(tooLong);
        vm.expectRevert(err);
        lendHook.decodeAmounts(tooShort);
        vm.expectRevert(err);
        lendHook.decodeUsePrevHookAmount(tooShort);
        vm.expectRevert(err);
        redeemHook.replaceCalldataAmounts(tooLong, new uint256[](1));
        vm.expectRevert(err);
        lendHook.build(address(0), account, "");
    }

    function test_Decode_RevertIf_NonCanonicalBool() public {
        bytes memory data = _dataRaw(
            ORACLE_ID, _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID), underlying, spoke, RESERVE_ID, AMOUNT, 0x02
        );
        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        lendHook.build(address(0), account, data);
        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        redeemHook.decodeUsePrevHookAmount(data);
        data = _dataRaw(
            ORACLE_ID, _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID), underlying, spoke, RESERVE_ID, AMOUNT, 0xff
        );
        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        redeemHook.inspect(data);
    }

    function test_Decode_RevertIf_ZeroOracleId() public {
        bytes memory data = _dataRaw(
            bytes32(0), _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID), underlying, spoke, RESERVE_ID, AMOUNT, 0x00
        );
        vm.expectRevert(BaseAaveV4MoneyMarketHook.ORACLE_ID_NOT_VALID.selector);
        lendHook.build(address(0), account, data);
        vm.expectRevert(BaseAaveV4MoneyMarketHook.ORACLE_ID_NOT_VALID.selector);
        redeemHook.inspect(data);
    }

    function test_Decode_RevertIf_ZeroAddresses() public {
        bytes4 err = BaseHook.ADDRESS_NOT_VALID.selector;
        vm.expectRevert(err);
        lendHook.build(
            address(0), account, _dataRaw(ORACLE_ID, address(0), underlying, spoke, RESERVE_ID, AMOUNT, 0x00)
        );
        vm.expectRevert(err);
        lendHook.build(
            address(0),
            account,
            _dataRaw(
                ORACLE_ID, _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID), address(0), spoke, RESERVE_ID, AMOUNT, 0x00
            )
        );
        vm.expectRevert(err);
        redeemHook.build(
            address(0),
            account,
            _dataRaw(ORACLE_ID, _key(address(0), RESERVE_ID), underlying, address(0), RESERVE_ID, AMOUNT, 0x00)
        );
    }

    /// @dev The header must be `computeMarketKey(spoke, supplyReserveId, borrowReserveId)` (SUP-21254):
    ///      another reserve's market, another spoke's market, or the LOAN-style "spoke in the header" all
    ///      fail — on build AND on inspect.
    /// @dev SUP-21263: these headers are no longer merely mis-derived, they are UNREGISTERED markets, so the
    ///      error is `MARKET_NOT_REGISTERED` and it is raised by the registry read in build/preExecute.
    ///      `inspect` is pure now and authenticates nothing, so it is asserted to SUCCEED instead.
    function test_Decode_RevertIf_HeaderKeyMismatch() public {
        bytes4 err = AaveV4ReserveRegistryV2.MARKET_NOT_REGISTERED.selector;
        bytes memory otherReserve =
            _dataRaw(ORACLE_ID, _marketKey(spoke, 0, BORROW_LEG_ID), underlying, spoke, RESERVE_ID, AMOUNT, 0x00);
        bytes memory otherSpokeKey = _dataRaw(
            ORACLE_ID,
            _marketKey(address(otherSpoke), RESERVE_ID, BORROW_LEG_ID),
            underlying,
            spoke,
            RESERVE_ID,
            AMOUNT,
            0x00
        );
        bytes memory spokeAsKey = _dataRaw(ORACLE_ID, spoke, underlying, spoke, RESERVE_ID, AMOUNT, 0x00);

        vm.expectRevert(err);
        lendHook.build(address(0), account, otherReserve);
        vm.expectRevert(err);
        redeemHook.build(address(0), account, otherSpokeKey);
        vm.expectRevert(err);
        lendHook.build(address(0), account, spokeAsKey);
        vm.expectRevert(err);
        redeemHook.preExecute(address(0), account, spokeAsKey);
        // pure: it describes the body, it does not vouch for it
        assertEq(lendHook.inspect(otherReserve).length, 92);
        assertEq(redeemHook.inspect(otherSpokeKey).length, 92);
        assertEq(redeemHook.inspect(spokeAsKey).length, 92);
    }

    /// @dev Underlying is bound to the reserve on build / preExecute (view); inspect stays pure.
    function test_Decode_RevertIf_UnderlyingMismatch_ButInspectIsPure() public {
        bytes memory data = _dataRaw(
            ORACLE_ID,
            _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID),
            address(otherToken),
            spoke,
            RESERVE_ID,
            AMOUNT,
            0x00
        );
        vm.expectRevert(BaseAaveV4MoneyMarketHook.TOKEN_RESERVE_MISMATCH.selector);
        lendHook.build(address(0), account, data);
        vm.expectRevert(BaseAaveV4MoneyMarketHook.TOKEN_RESERVE_MISMATCH.selector);
        redeemHook.preExecute(address(0), account, data);
        assertEq(lendHook.inspect(data).length, 92, "inspect does not consult the spoke");
    }

    /// @dev One mode per (account, reserve): a collateral-flagged reserve is refused by both hooks on
    ///      build and preExecute; inspect stays pure and unaffected.
    function test_RevertIf_ReserveIsCollateral() public {
        mockSpoke.setCollateral(RESERVE_ID, account, true);
        mockSpoke.setSupplied(RESERVE_ID, account, AMOUNT);
        bytes memory data = _data(AMOUNT, false);
        bytes4 err = BaseAaveV4MoneyMarketHook.RESERVE_IS_COLLATERAL.selector;

        vm.expectRevert(err);
        lendHook.build(address(0), account, data);
        vm.expectRevert(err);
        lendHook.preExecute(address(0), account, data);
        vm.expectRevert(err);
        redeemHook.build(address(0), account, data);
        vm.expectRevert(err);
        redeemHook.preExecute(address(0), account, data);
        assertEq(lendHook.inspect(data).length, 92, "inspect is pure");

        // Another account on the same reserve is unaffected (flag is per user)
        address other = makeAddr("other");
        assertEq(lendHook.build(address(0), other, data).length, 6);
    }

    /// @dev Lend refuses a reserve the account already borrows (supply + debt on one key); redeem keeps
    ///      only the collateral rule so an exit is never trapped behind a debt taken later (P3-2).
    function test_Lend_RevertIf_ReserveIsBorrowed_RedeemStillAllowed() public {
        mockSpoke.setBorrowing(RESERVE_ID, account, true);
        mockSpoke.setSupplied(RESERVE_ID, account, AMOUNT);
        bytes memory data = _data(AMOUNT, false);
        bytes4 err = BaseAaveV4MoneyMarketHook.RESERVE_IS_BORROWED.selector;

        vm.expectRevert(err);
        lendHook.build(address(0), account, data);
        vm.expectRevert(err);
        lendHook.preExecute(address(0), account, data);
        assertEq(redeemHook.build(address(0), account, data).length, 3, "redeem unaffected by debt");
        redeemHook.preExecute(address(0), account, data);
        assertEq(lendHook.inspect(data).length, 92, "inspect is pure");

        // Collateral still wins the error ordering when both are set
        mockSpoke.setCollateral(RESERVE_ID, account, true);
        vm.expectRevert(BaseAaveV4MoneyMarketHook.RESERVE_IS_COLLATERAL.selector);
        lendHook.build(address(0), account, data);
    }

    function test_Build_RevertIf_AmountZero() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        lendHook.build(address(0), account, _data(0, false));
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        redeemHook.build(address(0), account, _data(0, false));
    }

    function test_Build_Lend_RevertIf_AmountMax() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        lendHook.build(address(0), account, _data(type(uint256).max, false));
    }

    /*//////////////////////////////////////////////////////////////
                              BUILD SHAPES
    //////////////////////////////////////////////////////////////*/

    function test_Build_Lend_FourExecutions_NeverEnablesCollateral() public view {
        Execution[] memory ex = lendHook.build(address(0), account, _data(AMOUNT, false));
        // BaseHook wraps the provider calls: [0] = hook.preExecute, [5] = hook.postExecute
        assertEq(ex.length, 6);
        assertEq(ex[0].target, address(lendHook));
        assertEq(bytes4(ex[0].callData), BaseHook.preExecute.selector);
        assertEq(ex[1].target, underlying);
        assertEq(ex[1].callData, abi.encodeCall(IERC20.approve, (spoke, 0)));
        assertEq(ex[2].target, underlying);
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (spoke, AMOUNT)));
        assertEq(ex[3].target, spoke);
        assertEq(ex[3].callData, abi.encodeCall(IAaveV4Spoke.supply, (RESERVE_ID, AMOUNT, account)));
        assertEq(ex[4].target, underlying);
        assertEq(ex[4].callData, abi.encodeCall(IERC20.approve, (spoke, 0)));
        assertEq(ex[5].target, address(lendHook));
        assertEq(bytes4(ex[5].callData), BaseHook.postExecute.selector);
        assertFalse(_hasSelector(ex, IAaveV4Spoke.setUsingAsCollateral.selector), "must never enable collateral");
        for (uint256 i = 1; i < 5; ++i) {
            assertTrue(
                ex[i].target == underlying || ex[i].target == spoke, "provider targets are underlying/spoke only"
            );
            assertEq(ex[i].value, 0);
        }
    }

    function test_Build_Redeem_SingleWithdraw_MaxPassesThrough() public view {
        Execution[] memory ex = redeemHook.build(address(0), account, _data(AMOUNT, false));
        // [0] = hook.preExecute, [1] = withdraw, [2] = hook.postExecute
        assertEq(ex.length, 3);
        assertEq(bytes4(ex[0].callData), BaseHook.preExecute.selector);
        assertEq(ex[1].target, spoke);
        assertEq(ex[1].callData, abi.encodeCall(IAaveV4Spoke.withdraw, (RESERVE_ID, AMOUNT, account)));
        assertEq(bytes4(ex[2].callData), BaseHook.postExecute.selector);

        ex = redeemHook.build(address(0), account, _data(type(uint256).max, false));
        assertEq(ex[1].callData, abi.encodeCall(IAaveV4Spoke.withdraw, (RESERVE_ID, type(uint256).max, account)));
        assertFalse(_hasSelector(ex, IAaveV4Spoke.setUsingAsCollateral.selector));
        assertFalse(_hasSelector(ex, IAaveV4Spoke.repay.selector));
    }

    /*//////////////////////////////////////////////////////////////
                        PREVIOUS-HOOK AMOUNT PIPE
    //////////////////////////////////////////////////////////////*/

    function test_UsePrev_Lend_RequiresUnderlyingOutput() public {
        prevHook.set(500e6, underlying);
        Execution[] memory ex = lendHook.build(address(prevHook), account, _data(0, true));
        assertEq(ex[3].callData, abi.encodeCall(IAaveV4Spoke.supply, (RESERVE_ID, 500e6, account)));

        prevHook.set(500e6, address(otherToken));
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        lendHook.build(address(prevHook), account, _data(0, true));

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        lendHook.build(address(0), account, _data(0, true));

        prevHook.set(0, underlying);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        lendHook.build(address(prevHook), account, _data(0, true));

        prevHook.set(type(uint256).max, underlying);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        lendHook.build(address(prevHook), account, _data(0, true));
    }

    /// @dev SUP-21263 renamed the requirement: the share slot must be fed by the moved LEG's reserve key.
    function test_UsePrev_Redeem_RequiresTargetLegReserveKeyOutput() public {
        prevHook.set(400e6, _chainToken(_marketKey(spoke, RESERVE_ID, BORROW_LEG_ID), RESERVE_ID));
        Execution[] memory ex = redeemHook.build(address(prevHook), account, _data(0, true));
        assertEq(
            _spokeCallArgs(ex, IAaveV4Spoke.withdraw.selector),
            abi.encode(RESERVE_ID, uint256(400e6), account),
            "the prev output drives the withdraw"
        );

        // A raw asset output (e.g. a swap) cannot feed the share slot
        prevHook.set(400e6, underlying);
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        redeemHook.build(address(prevHook), account, _data(0, true));
    }

    /*//////////////////////////////////////////////////////////////
                               INSPECT
    //////////////////////////////////////////////////////////////*/

    function test_Inspect_ShapeAndStability() public view {
        bytes memory expected =
            abi.encodePacked(_marketKey(spoke, RESERVE_ID, BORROW_LEG_ID), spoke, underlying, RESERVE_ID);
        assertEq(expected.length, 92);
        assertEq(lendHook.inspect(_data(AMOUNT, false)), expected);
        assertEq(redeemHook.inspect(_data(AMOUNT, false)), expected, "lend and redeem share identity");
        // Unchanged when only amount / usePrev change
        assertEq(lendHook.inspect(_data(1, true)), expected);
        assertEq(lendHook.inspect(_data(type(uint256).max, false)), expected);
        // Different oracle id does not change identity either (not part of inspect)
        assertEq(
            lendHook.inspect(
                _dataRaw(
                    keccak256("other"),
                    _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID),
                    underlying,
                    spoke,
                    RESERVE_ID,
                    AMOUNT,
                    0x00
                )
            ),
            expected
        );
    }

    function test_Inspect_ChangesWithReserveSpokeOrUnderlying() public view {
        bytes memory base = lendHook.inspect(_data(AMOUNT, false));
        // other reserve on the same spoke (key follows)
        bytes memory otherReserve = lendHook.inspect(
            _dataRaw(ORACLE_ID, _marketKey(spoke, 0, BORROW_LEG_ID), address(otherToken), spoke, 0, AMOUNT, 0x00)
        );
        assertTrue(keccak256(otherReserve) != keccak256(base));
        // same reserve id on another spoke (key follows)
        bytes memory otherSpokeData = lendHook.inspect(
            _dataRaw(
                ORACLE_ID,
                _marketKey(address(otherSpoke), RESERVE_ID, BORROW_LEG_ID),
                underlying,
                address(otherSpoke),
                RESERVE_ID,
                AMOUNT,
                0x00
            )
        );
        assertTrue(keccak256(otherSpokeData) != keccak256(base));
        // same reserve, different declared underlying (inspect is pure; the spoke check lives in build)
        bytes memory otherUnderlying = lendHook.inspect(
            _dataRaw(
                ORACLE_ID,
                _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID),
                address(otherToken),
                spoke,
                RESERVE_ID,
                AMOUNT,
                0x00
            )
        );
        assertTrue(keccak256(otherUnderlying) != keccak256(base));
    }

    /*//////////////////////////////////////////////////////////////
                          SIZING INTERFACE
    //////////////////////////////////////////////////////////////*/

    function test_AmountRoles() public view {
        ISuperHookInflowOutflow.AmountMeta[] memory lend = lendHook.amountRoles("");
        assertEq(lend.length, 1);
        assertEq(uint256(lend[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(lend[0].denom), uint256(ISuperHookInflowOutflow.Denomination.ASSETS));

        ISuperHookInflowOutflow.AmountMeta[] memory redeem = redeemHook.amountRoles("");
        assertEq(redeem.length, 1);
        assertEq(uint256(redeem[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(redeem[0].denom), uint256(ISuperHookInflowOutflow.Denomination.SHARES));
    }

    function test_DecodeReplace_RoundtripPreservesEveryOtherByte() public {
        bytes memory data = _data(AMOUNT, true);
        assertEq(lendHook.decodeAmounts(data)[0], AMOUNT);
        assertTrue(lendHook.decodeUsePrevHookAmount(data));
        assertFalse(redeemHook.decodeUsePrevHookAmount(_data(AMOUNT, false)));

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 42e6;
        bytes memory replaced = redeemHook.replaceCalldataAmounts(data, amounts);
        assertEq(replaced.length, 157);
        assertEq(redeemHook.decodeAmounts(replaced)[0], 42e6);
        assertEq(BytesLib.slice(replaced, 0, 124), BytesLib.slice(data, 0, 124), "prefix untouched");
        assertEq(BytesLib.slice(replaced, 156, 1), BytesLib.slice(data, 156, 1), "flag untouched");
        assertEq(lendHook.inspect(replaced), lendHook.inspect(data));

        uint256[] memory two = new uint256[](2);
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        lendHook.replaceCalldataAmounts(data, two);
    }

    /*//////////////////////////////////////////////////////////////
                       PRE / POST EXECUTE — LEND
    //////////////////////////////////////////////////////////////*/

    function test_Lend_Cycle_CreditedPositionIsOutAmount_KeyIsOutToken() public {
        uint256 walletBefore = usdc.balanceOf(account);
        _run(lendHook, _data(AMOUNT, false));

        assertEq(walletBefore - usdc.balanceOf(account), AMOUNT, "wallet spend exact");
        assertEq(lendHook.getOutAmount(account), AMOUNT - 1, "credited position (1-wei round-down), not the spend");
        // SUP-21263: leg-exact, not market-exact — a market key covers both legs, so it cannot be the
        // chaining token any more. The LEDGER key is still the market key (header offset 32).
        assertEq(
            lendHook.getOutToken(account),
            _chainToken(_marketKey(spoke, RESERVE_ID, BORROW_LEG_ID), RESERVE_ID),
            "outToken = the (market, leg) chain token"
        );
        assertEq(lendHook.asset(), underlying, "fee asset = underlying");
        assertEq(mockSpoke.collateralCalls(), 0, "never enabled collateral");
        assertFalse(mockSpoke.isCollateral(RESERVE_ID, account));
    }

    function test_Lend_Cycle_NoRounding() public {
        mockSpoke.setRoundDownWei(0);
        _run(lendHook, _data(AMOUNT, false));
        assertEq(lendHook.getOutAmount(account), AMOUNT);
    }

    function test_Lend_Cycle_AddsToExistingPosition() public {
        mockSpoke.setSupplied(RESERVE_ID, account, 5000e6);
        _run(lendHook, _data(AMOUNT, false));
        assertEq(lendHook.getOutAmount(account), AMOUNT - 1, "delta, not the whole position");
    }

    function test_Lend_Post_RevertIf_WalletNotDebited() public {
        bytes memory data = _data(AMOUNT, false);
        lendHook.preExecute(address(0), account, data);
        // nothing moved
        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, AMOUNT, 0));
        lendHook.postExecute(address(0), account, data);
    }

    function test_Lend_Post_RevertIf_WalletDebitedDifferently() public {
        bytes memory data = _data(AMOUNT, false);
        lendHook.preExecute(address(0), account, data);
        usdc.transfer(address(0xdead), AMOUNT - 5);
        mockSpoke.setSupplied(RESERVE_ID, account, AMOUNT);
        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, AMOUNT, AMOUNT - 5));
        lendHook.postExecute(address(0), account, data);
    }

    function test_Lend_Post_RevertIf_PositionDecreased() public {
        mockSpoke.setSupplied(RESERVE_ID, account, 10e6);
        bytes memory data = _data(AMOUNT, false);
        lendHook.preExecute(address(0), account, data);
        usdc.transfer(address(0xdead), AMOUNT);
        mockSpoke.setSupplied(RESERVE_ID, account, 9e6);
        vm.expectRevert(BaseLoanHookV2.NEGATIVE_BALANCE_DELTA.selector);
        lendHook.postExecute(address(0), account, data);
    }

    function test_Lend_Post_RevertIf_NothingCredited() public {
        // 1-wei supply rounds down to a zero credit: never post a zero inflow
        bytes memory data = _data(1, false);
        lendHook.preExecute(address(0), account, data);
        usdc.approve(spoke, 1);
        mockSpoke.supply(RESERVE_ID, 1, account); // pulls 1 wei, credits 0
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        lendHook.postExecute(address(0), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                       PRE / POST EXECUTE — REDEEM
    //////////////////////////////////////////////////////////////*/

    function test_Redeem_Cycle_Partial() public {
        _run(lendHook, _data(AMOUNT, false));
        uint256 credited = lendHook.getOutAmount(account);
        uint256 walletBefore = usdc.balanceOf(account);

        _run(redeemHook, _data(400e6, false));

        assertEq(usdc.balanceOf(account) - walletBefore, 400e6, "receipt exact");
        assertEq(redeemHook.getOutAmount(account), 400e6);
        assertEq(redeemHook.usedShares(), 400e6, "position consumed");
        assertEq(redeemHook.getOutToken(account), underlying, "outToken = underlying");
        assertEq(redeemHook.asset(), underlying);
        assertEq(mockSpoke.getUserSuppliedAssets(RESERVE_ID, account), credited - 400e6);
        assertEq(mockSpoke.collateralCalls(), 0);
    }

    function test_Redeem_Cycle_FullViaMax() public {
        _run(lendHook, _data(AMOUNT, false));
        uint256 credited = lendHook.getOutAmount(account);
        uint256 walletBefore = usdc.balanceOf(account);

        _run(redeemHook, _data(type(uint256).max, false));

        assertEq(usdc.balanceOf(account) - walletBefore, credited, "full withdrawal pays the pre-read position");
        assertEq(redeemHook.getOutAmount(account), credited);
        assertEq(redeemHook.usedShares(), credited);
        assertEq(mockSpoke.getUserSuppliedAssets(RESERVE_ID, account), 0);
    }

    function test_Redeem_Cycle_AmountAbovePositionIsFull() public {
        _run(lendHook, _data(AMOUNT, false));
        uint256 credited = lendHook.getOutAmount(account);
        _run(redeemHook, _data(credited + 12_345, false));
        assertEq(redeemHook.getOutAmount(account), credited);
        assertEq(redeemHook.usedShares(), credited);
    }

    function test_Redeem_Cycle_UsePrevFromLend() public {
        _run(lendHook, _data(AMOUNT, false));
        uint256 credited = lendHook.getOutAmount(account);
        prevHook.set(credited, _chainToken(_marketKey(spoke, RESERVE_ID, BORROW_LEG_ID), RESERVE_ID));
        _run(redeemHook, _data(0, true));
        assertEq(redeemHook.getOutAmount(account), credited);
        assertEq(mockSpoke.getUserSuppliedAssets(RESERVE_ID, account), 0);
    }

    function test_Redeem_Pre_RevertIf_NothingSupplied() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        redeemHook.preExecute(address(0), account, _data(AMOUNT, false));
    }

    function test_Redeem_Post_RevertIf_ReceiptMismatch() public {
        mockSpoke.setSupplied(RESERVE_ID, account, AMOUNT);
        bytes memory data = _data(400e6, false);
        redeemHook.preExecute(address(0), account, data);
        // spoke paid less than requested
        vm.prank(address(mockSpoke));
        usdc.transfer(account, 399e6);
        mockSpoke.setSupplied(RESERVE_ID, account, AMOUNT - 400e6);
        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, 400e6, 399e6));
        redeemHook.postExecute(address(0), account, data);
    }

    function test_Redeem_Post_RevertIf_PositionGrew() public {
        mockSpoke.setSupplied(RESERVE_ID, account, AMOUNT);
        bytes memory data = _data(400e6, false);
        redeemHook.preExecute(address(0), account, data);
        vm.prank(address(mockSpoke));
        usdc.transfer(account, 400e6);
        mockSpoke.setSupplied(RESERVE_ID, account, AMOUNT + 1);
        vm.expectRevert(BaseLoanHookV2.NEGATIVE_BALANCE_DELTA.selector);
        redeemHook.postExecute(address(0), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                  HEADER IDENTITY ACROSS RESERVES / SPOKES
    //////////////////////////////////////////////////////////////*/

    /// @dev SUP-21263: the market the second reserve settles under must be REGISTERED, and `getOutToken` is
    ///      now the moved leg's RESERVE key rather than the market key — still distinct per reserve, which is
    ///      what this test is about.
    function test_HeaderIdentity_TwoReservesOneSpoke_DistinctKeys() public {
        otherToken.mint(account, 1e18);
        registry.registerReserve(spoke, 0);
        registry.registerMarket(spoke, 0, BORROW_LEG_ID);

        bytes memory usdcData = _data(AMOUNT, false);
        bytes memory othData =
            _dataRaw(ORACLE_ID, _marketKey(spoke, 0, BORROW_LEG_ID), address(otherToken), spoke, 0, 1e18, 0x00);

        _run(lendHook, usdcData);
        address keyUsdc = lendHook.getOutToken(account);
        _run(lendHook, othData);
        address keyOth = lendHook.getOutToken(account);

        assertEq(keyUsdc, _chainToken(_marketKey(spoke, RESERVE_ID, BORROW_LEG_ID), RESERVE_ID));
        assertEq(keyOth, _chainToken(_marketKey(spoke, 0, BORROW_LEG_ID), 0));
        assertTrue(keyUsdc != keyOth, "distinct accounting keys per reserve");
        assertTrue(keccak256(lendHook.inspect(usdcData)) != keccak256(lendHook.inspect(othData)));
        // a RESERVE key in the header is not a market: fails closed
        vm.expectRevert(AaveV4ReserveRegistryV2.MARKET_NOT_REGISTERED.selector);
        lendHook.build(address(0), account, _dataRaw(ORACLE_ID, keyOth, underlying, spoke, RESERVE_ID, AMOUNT, 0x00));
    }

    /// @dev PR #1020 review P3-1: the idle sizing APIs check exact length + canonical bool only. A mis-keyed template
    ///      sizes and rewrites successfully (wrong key preserved) and is refused at inspect / build / preExecute
    function test_Idle_SizingApis_TransformationOnly_ExecutionAuthenticatesHeader() public {
        address wrongKey = _marketKey(spoke, 0, BORROW_LEG_ID);
        bytes memory bad = _dataRaw(ORACLE_ID, wrongKey, underlying, spoke, RESERVE_ID, AMOUNT, 0x00);
        address[2] memory hooks = [address(lendHook), address(redeemHook)];
        uint256[] memory repl = new uint256[](1);
        repl[0] = 7;
        for (uint256 i; i < 2; ++i) {
            assertEq(ISuperHookInflowOutflow(hooks[i]).decodeAmounts(bad)[0], AMOUNT, "sizes a mis-keyed template");
            assertFalse(BaseAaveV4MoneyMarketHook(hooks[i]).decodeUsePrevHookAmount(bad), "bool view is header-blind");
            bytes memory rewritten = ISuperHookOutflow(hooks[i]).replaceCalldataAmounts(bad, repl);
            assertEq(HookDataDecoder.extractYieldSource(rewritten), wrongKey, "wrong key preserved by the rewrite");
            assertEq(ISuperHookInflowOutflow(hooks[i]).decodeAmounts(rewritten)[0], 7, "amount rewritten");
            vm.expectRevert(AaveV4ReserveRegistryV2.MARKET_NOT_REGISTERED.selector);
            ISuperHook(hooks[i]).build(address(0), account, rewritten);
            vm.expectRevert(AaveV4ReserveRegistryV2.MARKET_NOT_REGISTERED.selector);
            BaseHook(hooks[i]).preExecute(address(0), account, rewritten);
            // SUP-21263: inspect is pure and NOT an authentication surface — it describes the mis-keyed body
            assertEq(ISuperHookInspector(hooks[i]).inspect(rewritten).length, 92, "inspect still describes it");
        }
    }

    /*//////////////////////////////////////////////////////////////
       SUP-21263: TARGET-LEG MEMBERSHIP, CHECKED AGAINST THE REGISTRY
    //////////////////////////////////////////////////////////////*/

    /// @notice THE FEATURE. The market's BORROW leg is a legal idle target under the SAME market key, so
    ///         idle USDC on a MAG7-shaped pair settles under the equity market instead of needing its own
    ///         yield source. Before SUP-21263 this reverted `MARKET_KEY_MISMATCH`, because offset 92 fed
    ///         `computeMarketKey`'s supply slot. This is the unit-level proof of AC5.
    function test_Build_Lend_BorrowLegTarget_SuppliesTheBorrowLeg() public {
        bytes memory data = _dataRaw(
            ORACLE_ID,
            _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID),
            address(thirdToken),
            spoke,
            BORROW_LEG_ID,
            AMOUNT,
            0x00
        );

        Execution[] memory executions = lendHook.build(address(0), account, data);
        (uint256 movedId, uint256 movedAmount, address onBehalfOf) =
            abi.decode(_spokeCallArgs(executions, IAaveV4Spoke.supply.selector), (uint256, uint256, address));
        assertEq(movedId, BORROW_LEG_ID, "the Spoke call moves the BORROW leg");
        assertEq(movedAmount, AMOUNT);
        assertEq(onBehalfOf, account, "onBehalfOf is always the account");
    }

    /// @notice And the redeem side withdraws the same leg.
    function test_Build_Redeem_BorrowLegTarget_WithdrawsTheBorrowLeg() public {
        mockSpoke.setSupplied(BORROW_LEG_ID, account, AMOUNT);
        bytes memory data = _dataRaw(
            ORACLE_ID,
            _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID),
            address(thirdToken),
            spoke,
            BORROW_LEG_ID,
            AMOUNT,
            0x00
        );

        Execution[] memory executions = redeemHook.build(address(0), account, data);
        (uint256 movedId,,) =
            abi.decode(_spokeCallArgs(executions, IAaveV4Spoke.withdraw.selector), (uint256, uint256, address));
        assertEq(movedId, BORROW_LEG_ID);
    }

    /// @notice The supply leg still works, unchanged — this is the pre-existing shape.
    function test_Build_Lend_SupplyLegTarget_StillSuppliesTheSupplyLeg() public {
        Execution[] memory executions = lendHook.build(address(0), account, _data(AMOUNT, false));
        (uint256 movedId,,) =
            abi.decode(_spokeCallArgs(executions, IAaveV4Spoke.supply.selector), (uint256, uint256, address));
        assertEq(movedId, RESERVE_ID);
    }

    /// @notice A target that is NEITHER leg of the header market is refused, on both hooks and at BOTH
    ///         authenticating entry points. This is the check that replaced the pure key pin.
    function test_Build_RevertIf_TargetNotAMarketLeg() public {
        uint256 strayId = 9;
        mockSpoke.setReserveUnderlying(strayId, address(otherToken));
        bytes memory data = _dataRaw(
            ORACLE_ID, _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID), address(otherToken), spoke, strayId, AMOUNT, 0x00
        );

        bytes4 err = BaseAaveV4MoneyMarketHook.RESERVE_NOT_IN_MARKET.selector;
        vm.expectRevert(err);
        lendHook.build(address(0), account, data);
        vm.expectRevert(err);
        lendHook.preExecute(address(0), account, data);
        vm.expectRevert(err);
        redeemHook.build(address(0), account, data);
        vm.expectRevert(err);
        redeemHook.preExecute(address(0), account, data);
    }

    /// @notice Only the two legs are acceptable — everything else reverts, for any id.
    function testFuzz_TargetMustBeOneOfTwoLegs(uint256 target) public {
        vm.assume(target != RESERVE_ID && target != BORROW_LEG_ID);
        bytes memory data = _dataRaw(
            ORACLE_ID, _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID), underlying, spoke, target, AMOUNT, 0x00
        );
        vm.expectRevert(BaseAaveV4MoneyMarketHook.RESERVE_NOT_IN_MARKET.selector);
        lendHook.build(address(0), account, data);
    }

    /// @notice AN UNREGISTERED HEADER NOW FAILS IN THE HOOK, not deep inside SuperLedger — and that is how
    ///         the legacy reserve-keyed headers fail closed. Note `inspect` does NOT revert: since SUP-21263
    ///         it is pure and authenticates nothing (see `_inspectIdle`), so this test pins BOTH halves.
    function test_Build_RevertIf_MarketNotRegistered() public {
        address[4] memory badHeaders = [
            _key(spoke, RESERVE_ID), // the SUP-21142 idle header
            _debtKey(spoke, RESERVE_ID), // its debt sibling
            _marketKey(spoke, RESERVE_ID, 11), // a well-formed market that was never registered
            address(0xBEEF) // not a key at all
        ];
        for (uint256 i; i < badHeaders.length; ++i) {
            bytes memory data = _dataRaw(ORACLE_ID, badHeaders[i], underlying, spoke, RESERVE_ID, AMOUNT, 0x00);
            vm.expectRevert(AaveV4ReserveRegistryV2.MARKET_NOT_REGISTERED.selector);
            lendHook.build(address(0), account, data);
            vm.expectRevert(AaveV4ReserveRegistryV2.MARKET_NOT_REGISTERED.selector);
            redeemHook.preExecute(address(0), account, data);
            // pure, state-independent, and deliberately NOT an authentication surface
            assertEq(lendHook.inspect(data).length, 92, "inspect still returns its 92-byte payload");
        }
    }

    /// @notice A REGISTERED header whose body names a different spoke reverts `MARKET_KEY_MISMATCH`: the
    ///         re-derivation in `_requireTargetIsMarketLeg` pins the spoke, because the registry filed the
    ///         key under its own.
    function test_Build_RevertIf_SpokeIsNotTheMarketSpoke() public {
        bytes memory data = _dataRaw(
            ORACLE_ID,
            _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID),
            underlying,
            address(otherSpoke),
            RESERVE_ID,
            AMOUNT,
            0x00
        );
        vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
        lendHook.build(address(0), account, data);
        vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
        redeemHook.build(address(0), account, data);
    }

    /// @notice GUARD ORDERING: membership is checked before the underlying binding, so a stray target
    ///         reports the real defect (`RESERVE_NOT_IN_MARKET`) rather than a confusing
    ///         `TOKEN_RESERVE_MISMATCH`; and a valid leg with the wrong underlying still reports the latter.
    function test_GuardOrdering_MarketMembershipPrecedesUnderlying() public {
        uint256 strayId = 9;
        mockSpoke.setReserveUnderlying(strayId, address(otherToken));
        // stray target AND a mismatched underlying -> membership fires first
        vm.expectRevert(BaseAaveV4MoneyMarketHook.RESERVE_NOT_IN_MARKET.selector);
        lendHook.build(
            address(0),
            account,
            _dataRaw(ORACLE_ID, _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID), underlying, spoke, strayId, AMOUNT, 0x00)
        );
        // a real leg, wrong underlying -> the underlying check fires
        vm.expectRevert(BaseAaveV4MoneyMarketHook.TOKEN_RESERVE_MISMATCH.selector);
        lendHook.build(
            address(0),
            account,
            _dataRaw(
                ORACLE_ID, _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID), underlying, spoke, BORROW_LEG_ID, AMOUNT, 0x00
            )
        );
    }

    /// @notice And the pure decode still precedes any registry read: a zero address never costs a staticcall.
    function test_GuardOrdering_ZeroAddressPrecedesRegistry() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        lendHook.build(
            address(0),
            account,
            _dataRaw(
                ORACLE_ID,
                _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID),
                underlying,
                address(0),
                RESERVE_ID,
                AMOUNT,
                0x00
            )
        );
    }

    /// @notice THE R3 PROOF. `targetReserveId` is in the inspector payload, so the two legs of ONE market
    ///         produce DIFFERENT 92-byte payloads and therefore different Merkle leaves. Without it, one
    ///         signed leaf would authorise moving either asset.
    function test_Inspect_IsPure_AndCommitsTheTargetLeg() public view {
        address header = _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID);
        bytes memory supplyLeg =
            lendHook.inspect(_dataRaw(ORACLE_ID, header, underlying, spoke, RESERVE_ID, AMOUNT, 0x00));
        bytes memory borrowLeg =
            lendHook.inspect(_dataRaw(ORACLE_ID, header, address(thirdToken), spoke, BORROW_LEG_ID, AMOUNT, 0x00));

        assertEq(supplyLeg.length, 92, "payload size is unchanged by SUP-21263");
        assertEq(borrowLeg.length, 92);
        assertTrue(keccak256(supplyLeg) != keccak256(borrowLeg), "the two legs of one market are distinguishable");
        assertEq(BytesLib.toUint256(supplyLeg, 60), RESERVE_ID, "the tail word is the target leg");
        assertEq(BytesLib.toUint256(borrowLeg, 60), BORROW_LEG_ID);
    }

    /// @notice A resize still cannot touch any identity field. The borrow-leg word is gone, so the property
    ///         to pin now is that the 157-byte body's header and target survive a replacement.
    function test_Replace_PreservesHeaderAndTargetLeg() public view {
        bytes memory data = _data(AMOUNT, false);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = AMOUNT * 3;
        bytes memory replaced = lendHook.replaceCalldataAmounts(data, amounts);

        assertEq(replaced.length, 157, "length preserved");
        assertEq(BytesLib.toAddress(replaced, 32), BytesLib.toAddress(data, 32), "header untouched");
        assertEq(BytesLib.toUint256(replaced, 92), RESERVE_ID, "the target leg is outside the resize window");
        assertEq(BytesLib.toUint256(replaced, 124), AMOUNT * 3, "only the amount moved");
    }

    /// @notice BOTH legs idle under ONE market key: accepted on purpose (the ticket requires it), and the
    ///         accumulators net to zero when both are fully redeemed. The ledger-level consequences live in
    ///         the fork suite; this pins that the hooks themselves do not refuse the shape.
    function test_BothLegsIdleUnderOneKey_BuildAndRedeemBoth() public {
        address header = _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID);
        _run(lendHook, _dataRaw(ORACLE_ID, header, underlying, spoke, RESERVE_ID, AMOUNT, 0x00));
        _run(lendHook, _dataRaw(ORACLE_ID, header, address(thirdToken), spoke, BORROW_LEG_ID, AMOUNT, 0x00));

        assertGt(mockSpoke.getUserSuppliedAssets(RESERVE_ID, account), 0, "supply leg credited");
        assertGt(mockSpoke.getUserSuppliedAssets(BORROW_LEG_ID, account), 0, "borrow leg credited too");

        _run(redeemHook, _dataRaw(ORACLE_ID, header, underlying, spoke, RESERVE_ID, type(uint256).max, 0x00));
        _run(
            redeemHook, _dataRaw(ORACLE_ID, header, address(thirdToken), spoke, BORROW_LEG_ID, type(uint256).max, 0x00)
        );

        assertEq(mockSpoke.getUserSuppliedAssets(RESERVE_ID, account), 0, "supply leg fully exited");
        assertEq(mockSpoke.getUserSuppliedAssets(BORROW_LEG_ID, account), 0, "borrow leg fully exited");
    }

    /// @notice THE R5 FIX. The lend hook's outToken is the moved LEG's reserve key, not the market key, so
    ///         chaining a collateral-leg lend into a loan-leg redeem fails closed instead of feeding an
    ///         8-decimal figure into a 6-decimal withdraw.
    function test_UsePrev_CrossLegChain_FailsClosed() public {
        address header = _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID);
        mockSpoke.setSupplied(BORROW_LEG_ID, account, AMOUNT);

        // a lend of the SUPPLY leg advertises THIS market's supply-leg chain token
        prevHook.set(AMOUNT, _chainToken(header, RESERVE_ID));
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        redeemHook.build(
            address(prevHook), account, _dataRaw(ORACLE_ID, header, address(thirdToken), spoke, BORROW_LEG_ID, 0, 0x01)
        );

        // ...and the SAME leg chains cleanly
        prevHook.set(AMOUNT, _chainToken(header, BORROW_LEG_ID));
        Execution[] memory executions = redeemHook.build(
            address(prevHook), account, _dataRaw(ORACLE_ID, header, address(thirdToken), spoke, BORROW_LEG_ID, 0, 0x01)
        );
        assertTrue(_hasSelector(executions, IAaveV4Spoke.withdraw.selector), "same-leg chaining is unaffected");
    }

    /// @notice The market key is no longer accepted as the chaining token — it is leg-ambiguous, which is
    ///         exactly why it was replaced.
    function test_UsePrev_MarketKeyOutput_IsRefused() public {
        address header = _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID);
        mockSpoke.setSupplied(RESERVE_ID, account, AMOUNT);
        prevHook.set(AMOUNT, header);
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        redeemHook.build(
            address(prevHook), account, _dataRaw(ORACLE_ID, header, underlying, spoke, RESERVE_ID, 0, 0x01)
        );
    }

    /// @notice THE CROSS-MARKET CHAIN, closed in code rather than by the ops allowlist. Reserve
    ///         BORROW_LEG_ID is the loan leg of BOTH markets here, exactly as USDC is the loan leg of all
    ///         seven Base equity markets. With a market-blind chaining token (a bare reserve key, which is
    ///         what the first cut of this fix used) `lend(market A, leg R)` and `redeem(market B, leg R)`
    ///         published and expected the SAME token, so ONE signed bundle credited A's accumulator and
    ///         consumed B's — and `BaseLedger` CAPS `usedShares` at B's empty accumulator instead of
    ///         reverting, stranding A's basis and zeroing the performance fee whatever `feePercent` is.
    ///         Committing the (market, leg) PAIR makes that chain fail `PREV_TOKEN_MISMATCH`.
    function test_UsePrev_CrossMarketChain_FailsClosed() public {
        address marketA = _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID);
        // market B over the SAME loan leg: reserve 0 collateral, BORROW_LEG_ID borrow
        registry.registerReserve(spoke, 0);
        address marketB = registry.registerMarket(spoke, 0, BORROW_LEG_ID);
        assertTrue(marketA != marketB, "two markets sharing one loan leg");

        mockSpoke.setSupplied(BORROW_LEG_ID, account, AMOUNT);

        // a lend under market A, targeting the shared loan leg, advertises A's pair token
        prevHook.set(AMOUNT, _chainToken(marketA, BORROW_LEG_ID));

        // redeeming the SAME reserve under market B must NOT accept it
        bytes memory underB = _dataRaw(ORACLE_ID, marketB, address(thirdToken), spoke, BORROW_LEG_ID, 0, 0x01);
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        redeemHook.build(address(prevHook), account, underB);

        // ...and the bare reserve key — market-blind, the defective form — is refused too
        prevHook.set(AMOUNT, _key(spoke, BORROW_LEG_ID));
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        redeemHook.build(address(prevHook), account, underB);

        // same market, same leg still chains
        prevHook.set(AMOUNT, _chainToken(marketB, BORROW_LEG_ID));
        Execution[] memory ok = redeemHook.build(address(prevHook), account, underB);
        assertTrue(_hasSelector(ok, IAaveV4Spoke.withdraw.selector), "same market + same leg is unaffected");
    }

    /// @notice The chain token is distinct for every (market, leg) combination, and collides with none of
    ///         the three key namespaces it sits beside.
    function test_ChainToken_IsUniquePerMarketAndLeg() public view {
        address marketA = _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID);
        address marketB = _marketKey(spoke, 0, BORROW_LEG_ID);

        assertTrue(_chainToken(marketA, RESERVE_ID) != _chainToken(marketA, BORROW_LEG_ID), "legs differ");
        assertTrue(_chainToken(marketA, BORROW_LEG_ID) != _chainToken(marketB, BORROW_LEG_ID), "markets differ");
        assertTrue(_chainToken(marketA, RESERVE_ID) != marketA, "not the market key");
        assertTrue(_chainToken(marketA, RESERVE_ID) != _key(spoke, RESERVE_ID), "not the reserve key");
        assertTrue(_chainToken(marketA, RESERVE_ID) != _debtKey(spoke, RESERVE_ID), "not the debt key");
        assertTrue(_chainToken(marketA, RESERVE_ID) != underlying, "not a real token");
    }

    /// @notice Neither hook can be deployed without a registry — every op would otherwise revert.
    function test_Constructor_RevertIf_ZeroRegistry() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new AaveV4LendHook(address(0));
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new AaveV4RedeemHook(address(0));
    }

    /// @notice The hooks read the registry through `IAaveV4MarketRegistry`, which the deployed registry does
    ///         NOT inherit (editing it would move its CREATE2 address). This pins the structural parity the
    ///         compiler therefore cannot: same 5-tuple, and the same `MARKET_NOT_REGISTERED` selector.
    function test_RegistryInterfaceParity() public view {
        address header = _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID);
        (address iSpoke, uint256 iSupply, uint256 iBorrow, address iCollateral, address iLoan) =
            IAaveV4MarketRegistry(address(registry)).getMarketInfo(header);
        (address rSpoke, uint256 rSupply, uint256 rBorrow, address rCollateral, address rLoan) =
            registry.getMarketInfo(header);
        assertEq(iSpoke, rSpoke);
        assertEq(iSupply, rSupply);
        assertEq(iBorrow, rBorrow);
        assertEq(iCollateral, rCollateral);
        assertEq(iLoan, rLoan);
        assertEq(
            IAaveV4MarketRegistry.MARKET_NOT_REGISTERED.selector,
            AaveV4ReserveRegistryV2.MARKET_NOT_REGISTERED.selector,
            "selectors must match or a hook revert would be unrecognisable to callers"
        );
        assertTrue(IAaveV4MarketRegistry(address(registry)).isMarketRegistered(header));
        assertEq(address(lendHook.REGISTRY()), address(registry), "the hook holds the registry it was given");
    }

    /// @notice AC6, AND THE MUTATION NO OTHER TEST CATCHES. Both mode guards must apply to the MOVED reserve
    ///         (`targetReserveId`), not to the market's supply leg. Every other guard test uses a supply-leg
    ///         target, where the two readings coincide — so an incomplete migration that left
    ///         `_requireNotCollateral` / `_requireIdleLendable` reading the market's `supplyReserveId` would
    ///         pass the entire rest of the suite while letting an account idle-lend a BORROW-leg reserve it
    ///         has pledged as collateral. That would break the one-mode-per-(account, reserve) invariant this
    ///         whole family rests on.
    function test_ModeGuards_ApplyToTheBorrowLegTarget_NotTheSupplyLeg() public {
        address header = _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID);
        bytes memory borrowLegData =
            _dataRaw(ORACLE_ID, header, address(thirdToken), spoke, BORROW_LEG_ID, AMOUNT, 0x00);

        // Flag ONLY the borrow leg as collateral; the supply leg stays clean, so a guard reading the supply
        // leg would see nothing wrong.
        mockSpoke.setCollateral(BORROW_LEG_ID, account, true);
        assertFalse(mockSpoke.isCollateral(RESERVE_ID, account), "the supply leg is deliberately clean");

        vm.expectRevert(BaseAaveV4MoneyMarketHook.RESERVE_IS_COLLATERAL.selector);
        lendHook.build(address(0), account, borrowLegData);
        vm.expectRevert(BaseAaveV4MoneyMarketHook.RESERVE_IS_COLLATERAL.selector);
        lendHook.preExecute(address(0), account, borrowLegData);
        vm.expectRevert(BaseAaveV4MoneyMarketHook.RESERVE_IS_COLLATERAL.selector);
        redeemHook.build(address(0), account, borrowLegData);
        vm.expectRevert(BaseAaveV4MoneyMarketHook.RESERVE_IS_COLLATERAL.selector);
        redeemHook.preExecute(address(0), account, borrowLegData);

        // and the lend-only debt guard, same asymmetry
        mockSpoke.setCollateral(BORROW_LEG_ID, account, false);
        mockSpoke.setBorrowing(BORROW_LEG_ID, account, true);
        assertFalse(mockSpoke.isBorrowing(RESERVE_ID, account), "the supply leg is deliberately clean");
        vm.expectRevert(BaseAaveV4MoneyMarketHook.RESERVE_IS_BORROWED.selector);
        lendHook.build(address(0), account, borrowLegData);
        // redeem keeps only the collateral rule, so an exit is never trapped behind a later debt
        mockSpoke.setSupplied(BORROW_LEG_ID, account, AMOUNT);
        redeemHook.build(address(0), account, borrowLegData);
    }

    /// @notice And the mirror: a supply-leg target is NOT blocked by a flag on the borrow leg. Without this,
    ///         a guard that checked BOTH legs would pass the test above and still be wrong.
    function test_ModeGuards_SupplyLegTargetUnaffectedByBorrowLegFlags() public {
        mockSpoke.setCollateral(BORROW_LEG_ID, account, true);
        mockSpoke.setBorrowing(BORROW_LEG_ID, account, true);
        lendHook.build(address(0), account, _data(AMOUNT, false)); // must not revert
    }

    /// @notice The spoke pin, at `preExecute` as well as `build`, on both hooks. Mutation testing showed the
    ///         re-derivation in `_requireTargetIsMarketLeg` was covered by exactly ONE assertion — this
    ///         widens it, because it is the only thing stopping a REGISTERED market key from being paired
    ///         with a different spoke in the body.
    function test_PreExecute_RevertIf_SpokeIsNotTheMarketSpoke() public {
        bytes memory data = _dataRaw(
            ORACLE_ID,
            _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID),
            underlying,
            address(otherSpoke),
            RESERVE_ID,
            AMOUNT,
            0x00
        );
        vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
        lendHook.preExecute(address(0), account, data);
        vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
        redeemHook.preExecute(address(0), account, data);

        // the same market registered on the OTHER spoke is a different key, so it cannot be substituted
        registry.registerReserve(address(otherSpoke), RESERVE_ID);
        registry.registerReserve(address(otherSpoke), BORROW_LEG_ID);
        address otherSpokeMarket = registry.registerMarket(address(otherSpoke), RESERVE_ID, BORROW_LEG_ID);
        assertTrue(otherSpokeMarket != _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID), "distinct keys per spoke");
        vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
        lendHook.build(
            address(0), account, _dataRaw(ORACLE_ID, otherSpokeMarket, underlying, spoke, RESERVE_ID, AMOUNT, 0x00)
        );
    }

    /// @notice THE STALE 189-BYTE BODY — fail-closed direction 4 from the contract docblock, which
    ///         `test_Decode_RevertIf_WrongLength` (156 / 158 / 0) did not cover. A SUP-21254 root replayed
    ///         against this revision must die on the length, before any registry read.
    function test_Decode_RevertIf_StaleSupTwentyOneTwoFiveFourBody() public {
        bytes memory stale = abi.encodePacked(
            _dataRaw(
                ORACLE_ID, _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID), underlying, spoke, RESERVE_ID, AMOUNT, 0x00
            ),
            BORROW_LEG_ID // the word SUP-21254 appended at offset 157
        );
        assertEq(stale.length, 189, "exactly the superseded layout");

        address[2] memory hooks = [address(lendHook), address(redeemHook)];
        for (uint256 i; i < hooks.length; ++i) {
            vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
            ISuperHook(hooks[i]).build(address(0), account, stale);
            vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
            ISuperHookInspector(hooks[i]).inspect(stale);
            vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
            ISuperHookInflowOutflow(hooks[i]).decodeAmounts(stale);
        }
    }

    /// @notice Every length but 157 is refused by the decoder, so no adjacent layout can be mistaken for
    ///         this one. Complements the fixed 156 / 158 / 189 cases above.
    function testFuzz_OnlyOneFiveSevenByteBodiesDecode(uint16 length) public {
        vm.assume(length != 157 && length <= 512);
        bytes memory wrong = new bytes(length);
        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        lendHook.inspect(wrong);
    }

    /// @dev The arguments of the one Spoke call with `selector`, selector stripped so `abi.decode` works.
    ///      Scans rather than indexing: `build()` wraps the hook's own executions with pre/postExecute, so a
    ///      fixed index silently decodes the wrong call if that envelope ever changes.
    function _spokeCallArgs(Execution[] memory executions, bytes4 selector) internal pure returns (bytes memory out) {
        for (uint256 i; i < executions.length; ++i) {
            bytes memory callData = executions[i].callData;
            if (callData.length < 4 || bytes4(callData) != selector) continue;
            out = new bytes(callData.length - 4);
            for (uint256 j; j < out.length; ++j) {
                out[j] = callData[j + 4];
            }
            return out;
        }
        revert("SPOKE_CALL_NOT_FOUND");
    }

    /// @dev The (market, leg) chaining token, as the literal domain-separated formula rather than via the
    ///      hook — so a change to `_idleChainToken` breaks this test instead of silently agreeing with it.
    function _chainToken(address marketKey, uint256 targetReserveId) internal pure returns (address) {
        return address(
            uint160(uint256(keccak256(abi.encode(marketKey, targetReserveId, keccak256("AaveV4Idle.CHAIN_TOKEN")))))
        );
    }

    /// @dev The DEBT-leg derivation, for the legacy-header test above
    function _debtKey(address spoke_, uint256 reserveId) internal pure returns (address) {
        return address(
            uint160(uint256(keccak256(abi.encode(spoke_, reserveId, keccak256("AaveV4ReserveRegistryV2.DEBT")))))
        );
    }

    /*//////////////////////////////////////////////////////////////
            RETIREMENT: THE DOCUMENTED DRAIN CHECK IS NOT ENOUGH
    //////////////////////////////////////////////////////////////*/

    /// @notice REGRESSION for the PR #1027 review's P2. SECURITY.md section 16 item 3 used to tell operators
    ///         that `getBalanceOfOwner(marketKey, account)` and `usersAccumulatorShares(account, marketKey)`
    ///         both reading zero means a market's idle positions are drained and it is safe to retire. Since
    ///         SUP-21263 enabled idle positions on a market's BORROW reserve, that is false for two
    ///         independent reasons, and this test makes both of them fail the old gate while real user funds
    ///         are still supplied:
    ///           1. the market scalar resolves a market key to its COLLATERAL leg only (SUP-21255,
    ///              one-directional by design), so a borrow-leg position is invisible to it;
    ///           2. ledger shares count deposited ACCOUNTING UNITS, so redeeming every credited unit zeroes
    ///              the accumulator and leaves accrued interest supplied.
    ///         The consequence is the thing worth preventing: retirement passes the old checklist and the
    ///         holder can then no longer exit through Superform at all.
    /// @dev Real registry, real oracle, real `SuperLedger`, real hooks; only the Spoke is a mock, which is
    ///      what lets interest be modelled exactly rather than waited for. The ledger is driven directly
    ///      because this suite runs hooks the way `SuperExecutor` does but is not `SuperExecutor`.
    function test_RetirementDocumentedZeroChecksPassWithBorrowLegYieldRemaining() public {
        address marketKey = _marketKey(spoke, RESERVE_ID, BORROW_LEG_ID);

        address ledgerConfig = address(new SuperLedgerConfiguration());
        AaveV4ReserveOracle oracle = new AaveV4ReserveOracle(ledgerConfig, address(registry));
        address[] memory allowed = new address[](1);
        allowed[0] = account;
        SuperLedger ledger = new SuperLedger(ledgerConfig, allowed);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle),
            feePercent: 0,
            feeRecipient: makeAddr("feeRecipient"),
            ledger: address(ledger)
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = ORACLE_ID;
        SuperLedgerConfiguration(ledgerConfig).setYieldSourceOracles(salts, configs);
        bytes32 oracleId = keccak256(abi.encodePacked(ORACLE_ID, account));

        // 1. Lend on the market's BORROW leg — the mode SUP-21263 newly allows.
        _run(lendHook, _dataRaw(ORACLE_ID, marketKey, address(thirdToken), spoke, BORROW_LEG_ID, AMOUNT, bytes1(0x00)));
        uint256 credited = lendHook.getOutAmount(account);
        assertGt(credited, 0, "nothing was lent");
        ledger.updateAccounting(account, marketKey, oracleId, true, credited, 0);

        // 2. Model Aave interest: supplied assets now exceed the credited accounting units.
        uint256 residue = 1e6;
        mockSpoke.setSupplied(BORROW_LEG_ID, account, credited + residue);
        thirdToken.mint(address(mockSpoke), residue);

        // 3. Redeem every credited unit under the same market.
        _run(
            redeemHook,
            _dataRaw(ORACLE_ID, marketKey, address(thirdToken), spoke, BORROW_LEG_ID, credited, bytes1(0x00))
        );
        ledger.updateAccounting(account, marketKey, oracleId, false, credited, credited);

        // 4. THE BUG. Both checks the old runbook relied on read zero...
        assertEq(oracle.getBalanceOfOwner(marketKey, account), 0, "market scalar reads the collateral leg only");
        assertEq(ledger.usersAccumulatorShares(account, marketKey), 0, "every credited unit was consumed");

        // ...while real user funds are still supplied on the market's borrow leg.
        assertEq(
            IAaveV4Spoke(spoke).getUserSuppliedAssets(BORROW_LEG_ID, account), residue, "borrow-leg supply must remain"
        );

        // 5. The check SECURITY.md now mandates -- the Spoke's own accounting for BOTH of the market's
        //    reserves -- is what catches it.
        assertGt(
            IAaveV4Spoke(spoke).getUserSuppliedAssets(RESERVE_ID, account)
                + IAaveV4Spoke(spoke).getUserSuppliedAssets(BORROW_LEG_ID, account),
            0,
            "the two-reserve Spoke read must see the residue"
        );

        // 6. Retirement sails through the old gate.
        registry.proposeDeregisterMarket(marketKey);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        registry.executeDeregisterMarket(marketKey);

        // 7. And the holder's ordinary exit is gone. The failure is in the HOOK's registry validation,
        //    before any accounting runs -- not the oracle's `RESERVE_NOT_REGISTERED` that item 3 used to
        //    describe. Asserted on `build` AND `preExecute` -- both gates a bundler hits before anything
        //    moves -- each from a fresh execution context, as `SuperExecutorBase` would issue them.
        //    `postExecute` is deliberately not asserted here: its own ordering guard
        //    (`PRE_EXECUTE_ALREADY_CALLED` / not-called) fires first, which would make this test about
        //    hook sequencing rather than about the retired market.
        bytes memory exitData =
            _dataRaw(ORACLE_ID, marketKey, address(thirdToken), spoke, BORROW_LEG_ID, residue, bytes1(0x00));
        bytes4 retired = AaveV4ReserveRegistryV2.MARKET_NOT_REGISTERED.selector;

        redeemHook.setExecutionContext(account);
        vm.expectRevert(retired);
        redeemHook.build(address(prevHook), account, exitData);

        redeemHook.setExecutionContext(account);
        vm.expectRevert(retired);
        redeemHook.preExecute(address(prevHook), account, exitData);

        // The funds are still on the Spoke: stranded, not lost. Recovery needs the binding restored or a
        // direct Spoke exit with ledger reconciliation.
        assertEq(
            IAaveV4Spoke(spoke).getUserSuppliedAssets(BORROW_LEG_ID, account),
            residue,
            "the residue is stranded, not lost"
        );
    }
}
