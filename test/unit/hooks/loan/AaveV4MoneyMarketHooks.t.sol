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
import { AaveV4LendHook } from "../../../../src/hooks/loan/aave-v4/AaveV4LendHook.sol";
import { AaveV4RedeemHook } from "../../../../src/hooks/loan/aave-v4/AaveV4RedeemHook.sol";
import { AaveV4SupplyHook } from "../../../../src/hooks/loan/aave-v4/AaveV4SupplyHook.sol";
import { AaveV4WithdrawHook } from "../../../../src/hooks/loan/aave-v4/AaveV4WithdrawHook.sol";
import { AaveV4SupplyAndBorrowHookV2 } from "../../../../src/hooks/loan/aave-v4/AaveV4SupplyAndBorrowHookV2.sol";
import { AaveV4RepayHookV2 } from "../../../../src/hooks/loan/aave-v4/AaveV4RepayHookV2.sol";
import { AaveV4ReserveRegistry } from "../../../../src/accounting/oracles/AaveV4ReserveRegistry.sol";

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
    MockPrevHookIdle public prevHook;

    address public spoke;
    address public underlying;
    address public account;
    bytes32 public constant ORACLE_ID = keccak256("AaveV4SupplyYieldSourceOracle");
    uint256 public constant RESERVE_ID = 7;
    uint256 public constant AMOUNT = 1000e6;

    function setUp() public {
        lendHook = new AaveV4LendHook();
        redeemHook = new AaveV4RedeemHook();
        mockSpoke = new MockAaveV4IdleSpoke();
        otherSpoke = new MockAaveV4IdleSpoke();
        usdc = new MockERC20("USD Coin", "USDC", 6);
        otherToken = new MockERC20("Other", "OTH", 18);
        prevHook = new MockPrevHookIdle();

        spoke = address(mockSpoke);
        underlying = address(usdc);
        account = address(this);
        mockSpoke.setReserveUnderlying(RESERVE_ID, underlying);
        mockSpoke.setReserveUnderlying(0, address(otherToken));
        otherSpoke.setReserveUnderlying(RESERVE_ID, underlying);
        usdc.mint(account, 1_000_000e6);
        usdc.mint(address(mockSpoke), 1_000_000e6);
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    function _key(address spoke_, uint256 reserveId) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encode(spoke_, reserveId)))));
    }

    function _dataRaw(
        bytes32 oracleId,
        address key,
        address underlying_,
        address spoke_,
        uint256 reserveId,
        uint256 amount,
        bytes1 flag
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(oracleId, key, underlying_, spoke_, reserveId, amount, flag);
    }

    function _data(uint256 amount, bool usePrev) internal view returns (bytes memory) {
        return _dataRaw(
            ORACLE_ID,
            _key(spoke, RESERVE_ID),
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

    function test_ReserveKey_MatchesRegistryFormula() public {
        AaveV4ReserveRegistry registry = new AaveV4ReserveRegistry(address(this));
        assertEq(_key(spoke, RESERVE_ID), registry.computeReserveKey(spoke, RESERVE_ID));
        assertEq(_key(spoke, 0), registry.computeReserveKey(spoke, 0));
        assertTrue(_key(spoke, 0) != _key(spoke, RESERVE_ID), "reserve ids diverge");
        assertTrue(_key(spoke, RESERVE_ID) != _key(address(otherSpoke), RESERVE_ID), "spokes diverge");
    }

    /// @dev The hook's local key must equal the deployed registry's formula for every (spoke, reserveId)
    function testFuzz_ReserveKey_MatchesRegistryFormula(address spoke_, uint256 reserveId) public {
        AaveV4ReserveRegistry registry = new AaveV4ReserveRegistry(address(this));
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
        bytes memory data = _dataRaw(ORACLE_ID, _key(spoke, RESERVE_ID), underlying, spoke, RESERVE_ID, AMOUNT, 0x02);
        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        lendHook.build(address(0), account, data);
        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        redeemHook.decodeUsePrevHookAmount(data);
        data = _dataRaw(ORACLE_ID, _key(spoke, RESERVE_ID), underlying, spoke, RESERVE_ID, AMOUNT, 0xff);
        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        redeemHook.inspect(data);
    }

    function test_Decode_RevertIf_ZeroOracleId() public {
        bytes memory data = _dataRaw(bytes32(0), _key(spoke, RESERVE_ID), underlying, spoke, RESERVE_ID, AMOUNT, 0x00);
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
            _dataRaw(ORACLE_ID, _key(spoke, RESERVE_ID), address(0), spoke, RESERVE_ID, AMOUNT, 0x00)
        );
        vm.expectRevert(err);
        redeemHook.build(
            address(0),
            account,
            _dataRaw(ORACLE_ID, _key(address(0), RESERVE_ID), underlying, address(0), RESERVE_ID, AMOUNT, 0x00)
        );
    }

    /// @dev The header must be computeReserveKey(spoke, reserveId): another reserve's key, another
    ///      spoke's key, or the LOAN-style "spoke in the header" all fail — on build AND on inspect.
    function test_Decode_RevertIf_HeaderKeyMismatch() public {
        bytes4 err = BaseAaveV4MoneyMarketHook.RESERVE_KEY_MISMATCH.selector;
        bytes memory otherReserve = _dataRaw(ORACLE_ID, _key(spoke, 0), underlying, spoke, RESERVE_ID, AMOUNT, 0x00);
        bytes memory otherSpokeKey =
            _dataRaw(ORACLE_ID, _key(address(otherSpoke), RESERVE_ID), underlying, spoke, RESERVE_ID, AMOUNT, 0x00);
        bytes memory spokeAsKey = _dataRaw(ORACLE_ID, spoke, underlying, spoke, RESERVE_ID, AMOUNT, 0x00);

        vm.expectRevert(err);
        lendHook.build(address(0), account, otherReserve);
        vm.expectRevert(err);
        lendHook.inspect(otherReserve);
        vm.expectRevert(err);
        redeemHook.build(address(0), account, otherSpokeKey);
        vm.expectRevert(err);
        redeemHook.inspect(otherSpokeKey);
        vm.expectRevert(err);
        lendHook.build(address(0), account, spokeAsKey);
        vm.expectRevert(err);
        redeemHook.inspect(spokeAsKey);
    }

    /// @dev Underlying is bound to the reserve on build / preExecute (view); inspect stays pure.
    function test_Decode_RevertIf_UnderlyingMismatch_ButInspectIsPure() public {
        bytes memory data =
            _dataRaw(ORACLE_ID, _key(spoke, RESERVE_ID), address(otherToken), spoke, RESERVE_ID, AMOUNT, 0x00);
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

    function test_UsePrev_Redeem_RequiresReserveKeyOutput() public {
        prevHook.set(400e6, _key(spoke, RESERVE_ID));
        Execution[] memory ex = redeemHook.build(address(prevHook), account, _data(0, true));
        assertEq(ex[1].callData, abi.encodeCall(IAaveV4Spoke.withdraw, (RESERVE_ID, 400e6, account)));

        // A raw asset output (e.g. a swap) cannot feed the share slot
        prevHook.set(400e6, underlying);
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        redeemHook.build(address(prevHook), account, _data(0, true));
    }

    /*//////////////////////////////////////////////////////////////
                               INSPECT
    //////////////////////////////////////////////////////////////*/

    function test_Inspect_ShapeAndStability() public view {
        bytes memory expected = abi.encodePacked(_key(spoke, RESERVE_ID), spoke, underlying, RESERVE_ID);
        assertEq(expected.length, 92);
        assertEq(lendHook.inspect(_data(AMOUNT, false)), expected);
        assertEq(redeemHook.inspect(_data(AMOUNT, false)), expected, "lend and redeem share identity");
        // Unchanged when only amount / usePrev change
        assertEq(lendHook.inspect(_data(1, true)), expected);
        assertEq(lendHook.inspect(_data(type(uint256).max, false)), expected);
        // Different oracle id does not change identity either (not part of inspect)
        assertEq(
            lendHook.inspect(
                _dataRaw(keccak256("other"), _key(spoke, RESERVE_ID), underlying, spoke, RESERVE_ID, AMOUNT, 0x00)
            ),
            expected
        );
    }

    function test_Inspect_ChangesWithReserveSpokeOrUnderlying() public view {
        bytes memory base = lendHook.inspect(_data(AMOUNT, false));
        // other reserve on the same spoke (key follows)
        bytes memory otherReserve =
            lendHook.inspect(_dataRaw(ORACLE_ID, _key(spoke, 0), address(otherToken), spoke, 0, AMOUNT, 0x00));
        assertTrue(keccak256(otherReserve) != keccak256(base));
        // same reserve id on another spoke (key follows)
        bytes memory otherSpokeData = lendHook.inspect(
            _dataRaw(
                ORACLE_ID,
                _key(address(otherSpoke), RESERVE_ID),
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
            _dataRaw(ORACLE_ID, _key(spoke, RESERVE_ID), address(otherToken), spoke, RESERVE_ID, AMOUNT, 0x00)
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
        assertEq(lendHook.getOutToken(account), _key(spoke, RESERVE_ID), "outToken = reserve key");
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
        prevHook.set(credited, _key(spoke, RESERVE_ID));
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

    function test_HeaderIdentity_TwoReservesOneSpoke_DistinctKeys() public {
        otherToken.mint(account, 1e18);
        bytes memory usdcData = _data(AMOUNT, false);
        bytes memory othData = _dataRaw(ORACLE_ID, _key(spoke, 0), address(otherToken), spoke, 0, 1e18, 0x00);

        _run(lendHook, usdcData);
        address keyUsdc = lendHook.getOutToken(account);
        _run(lendHook, othData);
        address keyOth = lendHook.getOutToken(account);

        assertTrue(keyUsdc != keyOth, "distinct accounting keys per reserve");
        assertTrue(keccak256(lendHook.inspect(usdcData)) != keccak256(lendHook.inspect(othData)));
        // each header pinned to its own reserve: swapping keys fails closed
        vm.expectRevert(BaseAaveV4MoneyMarketHook.RESERVE_KEY_MISMATCH.selector);
        lendHook.build(address(0), account, _dataRaw(ORACLE_ID, keyOth, underlying, spoke, RESERVE_ID, AMOUNT, 0x00));
    }
}
