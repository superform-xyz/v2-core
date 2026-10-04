// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { Helpers } from "../../../utils/Helpers.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import {
    ISuperHook,
    ISuperHookLoans,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../../src/interfaces/ISuperHook.sol";
import { IAaveV4Spoke } from "../../../../src/vendor/aave-v4/IAaveV4Spoke.sol";
import { HookSubTypes } from "../../../../src/libraries/HookSubTypes.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { BytesLib } from "../../../../src/vendor/BytesLib.sol";
import { AaveV4ReserveKey } from "../../../../src/libraries/AaveV4ReserveKey.sol";
import { AaveV4ReserveRegistryV2 } from "../../../../src/accounting/oracles/AaveV4ReserveRegistryV2.sol";
// Hooks
import { BaseLoanHookV2 } from "../../../../src/hooks/loan/BaseLoanHookV2.sol";
import { BaseAaveV4LoanHookV2 } from "../../../../src/hooks/loan/aave-v4/BaseAaveV4LoanHookV2.sol";
import { AaveV4SupplyAndBorrowHookV2 } from "../../../../src/hooks/loan/aave-v4/AaveV4SupplyAndBorrowHookV2.sol";
import { AaveV4RepayHookV2 } from "../../../../src/hooks/loan/aave-v4/AaveV4RepayHookV2.sol";
import { AaveV4RepayAndWithdrawHookV2 } from "../../../../src/hooks/loan/aave-v4/AaveV4RepayAndWithdrawHookV2.sol";

/// @dev Extends the money-function no-op behavior of the legacy MockAaveV4Spoke with the
///      view surface the V2 hooks rely on: reserve/underlying binding, per-user debt and
///      per-user supplied assets.
contract MockAaveV4SpokeV2 {
    mapping(uint256 reserveId => address underlying) public reserveUnderlying;
    mapping(uint256 reserveId => mapping(address user => uint256 drawn)) public drawnDebt;
    mapping(uint256 reserveId => mapping(address user => uint256 premium)) public premiumDebt;
    mapping(uint256 reserveId => mapping(address user => uint256 supplied)) public suppliedAssets;
    mapping(uint256 reserveId => mapping(address user => bool flag)) public usingAsCollateral;

    /*//////////////////////////////////////////////////////////////
                              SETTERS
    //////////////////////////////////////////////////////////////*/

    function setReserveUnderlying(uint256 reserveId, address underlying) external {
        reserveUnderlying[reserveId] = underlying;
    }

    function setUserDebt(uint256 reserveId, address user, uint256 drawn, uint256 premium) external {
        drawnDebt[reserveId][user] = drawn;
        premiumDebt[reserveId][user] = premium;
    }

    function setUserSuppliedAssets(uint256 reserveId, address user, uint256 amount) external {
        suppliedAssets[reserveId][user] = amount;
    }

    /*//////////////////////////////////////////////////////////////
                              VIEWS
    //////////////////////////////////////////////////////////////*/

    function getReserve(uint256 reserveId) external view returns (IAaveV4Spoke.Reserve memory reserve) {
        reserve.underlying = reserveUnderlying[reserveId];
    }

    function getUserDebt(uint256 reserveId, address user) external view returns (uint256, uint256) {
        return (drawnDebt[reserveId][user], premiumDebt[reserveId][user]);
    }

    function getUserSuppliedAssets(uint256 reserveId, address user) external view returns (uint256) {
        return suppliedAssets[reserveId][user];
    }

    /*//////////////////////////////////////////////////////////////
                        MONEY FUNCTIONS (NO-OP)
    //////////////////////////////////////////////////////////////*/

    function supply(uint256, uint256 amount, address) external pure returns (uint256, uint256) {
        return (amount, 0);
    }

    function withdraw(uint256, uint256 amount, address) external pure returns (uint256, uint256) {
        return (amount, 0);
    }

    function borrow(uint256, uint256 amount, address) external pure returns (uint256, uint256) {
        return (amount, 0);
    }

    function repay(uint256, uint256 amount, address) external pure returns (uint256, uint256) {
        return (amount, 0);
    }

    function setUsingAsCollateral(uint256 reserveId, bool flag, address user) external {
        usingAsCollateral[reserveId][user] = flag;
    }

    function getUserReserveStatus(uint256 reserveId, address user) external view returns (bool, bool) {
        return (usingAsCollateral[reserveId][user], false);
    }
}

/// @dev Previous-hook stub with settable output amount and output token
contract MockPrevHookV2 {
    uint256 internal outAmount;
    address internal outToken;

    function setOutAmount(uint256 amount) external {
        outAmount = amount;
    }

    function setOutToken(address token) external {
        outToken = token;
    }

    function getOutAmount(address) external view returns (uint256) {
        return outAmount;
    }

    function getOutToken(address) external view returns (address) {
        return outToken;
    }
}

contract AaveV4LoanHooksV2Test is Helpers {
    // Hooks
    AaveV4SupplyAndBorrowHookV2 public openHook;
    AaveV4RepayHookV2 public repayHook;
    AaveV4RepayAndWithdrawHookV2 public closeHook;

    // Mocks
    MockAaveV4SpokeV2 public mockSpoke;
    MockERC20 public mockLoanToken;
    MockERC20 public mockCollateralToken;
    MockERC20 public mockOtherToken;
    MockPrevHookV2 public prevHook;

    // Test params
    address public spoke;
    address public loanToken;
    address public collateralToken;
    uint256 public supplyReserveId = 1;
    uint256 public borrowReserveId = 2;
    uint256 public amount = 1e18;
    uint256 public borrowAmount = 5e17;
    uint256 public withdrawAmount = 6e17;
    uint256 public drawnDebt = 8e17;
    uint256 public premiumDebt = 2e17;
    uint256 public suppliedAssets = 3e18;

    address internal constant SINK = address(0xdead);
    uint256 internal constant MAX = type(uint256).max;

    function setUp() public {
        mockSpoke = new MockAaveV4SpokeV2();
        spoke = address(mockSpoke);

        mockLoanToken = new MockERC20("Loan Token", "LOAN", 18);
        loanToken = address(mockLoanToken);

        mockCollateralToken = new MockERC20("Collateral Token", "COLL", 18);
        collateralToken = address(mockCollateralToken);

        mockOtherToken = new MockERC20("Other Token", "OTHER", 18);

        prevHook = new MockPrevHookV2();

        openHook = new AaveV4SupplyAndBorrowHookV2();
        repayHook = new AaveV4RepayHookV2();
        closeHook = new AaveV4RepayAndWithdrawHookV2();

        // Bind reserves to their declared tokens
        mockSpoke.setReserveUnderlying(supplyReserveId, collateralToken);
        mockSpoke.setReserveUnderlying(borrowReserveId, loanToken);

        // The test contract acts as the smart account and has debt + supplied assets
        mockSpoke.setUserDebt(borrowReserveId, address(this), drawnDebt, premiumDebt);
        mockSpoke.setUserSuppliedAssets(supplyReserveId, address(this), suppliedAssets);
        // LOAN mode: the supplied position is flagged as collateral (OPEN refuses an un-flagged idle position)
        mockSpoke.setUsingAsCollateral(supplyReserveId, true, address(this));
    }

    /*//////////////////////////////////////////////////////////////
                           CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Constructors_HookTypes() public view {
        assertEq(uint256(openHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(repayHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(closeHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_Constructors_HookSubtypes() public view {
        assertEq(openHook.SUB_TYPE(), HookSubTypes.LOAN);
        assertEq(repayHook.SUB_TYPE(), HookSubTypes.LOAN_REPAY);
        assertEq(closeHook.SUB_TYPE(), HookSubTypes.LOAN_REPAY);
    }

    /*//////////////////////////////////////////////////////////////
                             ERC-165 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SupportsInterface_AllHooks() public view {
        BaseHook[3] memory hooks = [BaseHook(openHook), BaseHook(repayHook), BaseHook(closeHook)];
        for (uint256 i = 0; i < hooks.length; i++) {
            // ISuperHookLoans is implemented but deliberately not advertised via ERC-165
            assertFalse(hooks[i].supportsInterface(type(ISuperHookLoans).interfaceId));
            assertTrue(hooks[i].supportsInterface(type(ISuperHookInflowOutflow).interfaceId));
            assertTrue(hooks[i].supportsInterface(type(ISuperHookOutflow).interfaceId));
        }
    }

    /*//////////////////////////////////////////////////////////////
                        STRICT DECODE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Build_RevertIf_DataTooShort_240() public {
        bytes memory data = _truncate(_defaultData(amount, false, borrowAmount), 240);

        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        openHook.build(address(0), address(this), data);

        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        repayHook.build(address(0), address(this), data);

        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        closeHook.build(address(0), address(this), data);
    }

    function test_Build_RevertIf_DataTooLong_242() public {
        bytes memory data = abi.encodePacked(_defaultData(amount, false, borrowAmount), bytes1(0x00));
        assertEq(data.length, 242);

        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        openHook.build(address(0), address(this), data);

        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        repayHook.build(address(0), address(this), data);

        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        closeHook.build(address(0), address(this), data);
    }

    function test_Build_RevertIf_InvalidBoolValue() public {
        bytes memory data = _encode(
            loanToken, collateralToken, spoke, supplyReserveId, borrowReserveId, amount, bytes1(0x02), borrowAmount
        );

        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        openHook.build(address(0), address(this), data);

        bytes memory repayData =
            _encode(loanToken, collateralToken, spoke, supplyReserveId, borrowReserveId, amount, bytes1(0x02), 0);
        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        repayHook.build(address(0), address(this), repayData);
    }

    function test_Build_RevertIf_ZeroLoanToken() public {
        bytes memory data = _encode(
            address(0), collateralToken, spoke, supplyReserveId, borrowReserveId, amount, bytes1(0x00), borrowAmount
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        openHook.build(address(0), address(this), data);
    }

    function test_Build_RevertIf_ZeroCollateralToken() public {
        bytes memory data =
            _encode(loanToken, address(0), spoke, supplyReserveId, borrowReserveId, amount, bytes1(0x00), borrowAmount);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        openHook.build(address(0), address(this), data);
    }

    function test_Build_RevertIf_ZeroSpoke() public {
        bytes memory data = _encode(
            loanToken, collateralToken, address(0), supplyReserveId, borrowReserveId, amount, bytes1(0x00), borrowAmount
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        openHook.build(address(0), address(this), data);
    }

    function test_Build_RevertIf_IdenticalTokens() public {
        bytes memory data =
            _encode(loanToken, loanToken, spoke, supplyReserveId, borrowReserveId, amount, bytes1(0x00), borrowAmount);
        vm.expectRevert(BaseLoanHookV2.IDENTICAL_TOKENS.selector);
        openHook.build(address(0), address(this), data);
    }

    function test_RepayHook_Build_RevertIf_ReservedAmount2NotZero() public {
        bytes memory data = _defaultData(amount, false, 1);
        vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
        repayHook.build(address(0), address(this), data);
    }

    /*//////////////////////////////////////////////////////////////
                       RESERVE BINDING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OpenHook_Build_RevertIf_SupplyReserveMismatch() public {
        mockSpoke.setReserveUnderlying(supplyReserveId, address(mockOtherToken));
        vm.expectRevert(BaseAaveV4LoanHookV2.TOKEN_RESERVE_MISMATCH.selector);
        openHook.build(address(0), address(this), _defaultData(amount, false, borrowAmount));
    }

    function test_OpenHook_Build_RevertIf_BorrowReserveMismatch() public {
        mockSpoke.setReserveUnderlying(borrowReserveId, address(mockOtherToken));
        vm.expectRevert(BaseAaveV4LoanHookV2.TOKEN_RESERVE_MISMATCH.selector);
        openHook.build(address(0), address(this), _defaultData(amount, false, borrowAmount));
    }

    function test_RepayHook_Build_RevertIf_BorrowReserveMismatch() public {
        mockSpoke.setReserveUnderlying(borrowReserveId, address(mockOtherToken));
        vm.expectRevert(BaseAaveV4LoanHookV2.TOKEN_RESERVE_MISMATCH.selector);
        repayHook.build(address(0), address(this), _repayData(amount, false));
    }

    function test_CloseHook_Build_RevertIf_SupplyReserveMismatch() public {
        mockSpoke.setReserveUnderlying(supplyReserveId, address(mockOtherToken));
        vm.expectRevert(BaseAaveV4LoanHookV2.TOKEN_RESERVE_MISMATCH.selector);
        closeHook.build(address(0), address(this), _defaultData(amount, false, withdrawAmount));
    }

    /*//////////////////////////////////////////////////////////////
                          AMOUNT VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OpenHook_Build_RevertIf_ZeroCollateralAmount() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(0), address(this), _defaultData(0, false, borrowAmount));
    }

    function test_OpenHook_Build_RevertIf_MaxCollateralAmount() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(0), address(this), _defaultData(MAX, false, borrowAmount));
    }

    function test_OpenHook_Build_RevertIf_ZeroBorrowAmount() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(0), address(this), _defaultData(amount, false, 0));
    }

    function test_OpenHook_Build_RevertIf_MaxBorrowAmount() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(0), address(this), _defaultData(amount, false, MAX));
    }

    function test_RepayHook_Build_MaxWithPrev_PrevOutputIsCap() public {
        // Under usePrevHookAmount the calldata cap word (here max) is ignored entirely
        uint256 prevAmount = 4e17; // below the total debt → exact-amount repay
        prevHook.setOutToken(loanToken);
        prevHook.setOutAmount(prevAmount);

        Execution[] memory executions = repayHook.build(address(prevHook), address(this), _repayData(MAX, true));
        assertEq(executions.length, 6);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (spoke, prevAmount)));
        assertEq(
            executions[3].callData, abi.encodeCall(IAaveV4Spoke.repay, (borrowReserveId, prevAmount, address(this)))
        );
    }

    function test_CloseHook_Build_MaxWithPrev_PrevOutputIsCap() public {
        uint256 prevAmount = 4e17;
        prevHook.setOutToken(loanToken);
        prevHook.setOutAmount(prevAmount);

        Execution[] memory executions =
            closeHook.build(address(prevHook), address(this), _defaultData(MAX, true, withdrawAmount));
        assertEq(executions.length, 7);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (spoke, prevAmount)));
        assertEq(
            executions[3].callData, abi.encodeCall(IAaveV4Spoke.repay, (borrowReserveId, prevAmount, address(this)))
        );
    }

    function test_RepayHook_Build_RevertIf_ZeroAmount() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        repayHook.build(address(0), address(this), _repayData(0, false));
    }

    function test_CloseHook_Build_RevertIf_ZeroRepayAmount() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        closeHook.build(address(0), address(this), _defaultData(0, false, withdrawAmount));
    }

    function test_CloseHook_Build_RevertIf_ZeroWithdrawAmount() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        closeHook.build(address(0), address(this), _defaultData(amount, false, 0));
    }

    /*//////////////////////////////////////////////////////////////
                           ZERO-DEBT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RepayHook_Build_ZeroDebt_Graceful_NoOps() public {
        // Zero total debt: the repay leg is skipped instead of reverting
        mockSpoke.setUserDebt(borrowReserveId, address(this), 0, 0);
        Execution[] memory executions = repayHook.build(address(0), address(this), _repayData(amount, false));
        assertEq(executions.length, 2); // preExecute + postExecute only
    }

    function test_CloseHook_Build_ZeroDebt_Graceful_WithdrawOnly() public {
        // Zero debt: the close degrades to a plain withdrawal, arbitrated by the Spoke's health check
        mockSpoke.setUserDebt(borrowReserveId, address(this), 0, 0);
        Execution[] memory executions =
            closeHook.build(address(0), address(this), _defaultData(amount, false, withdrawAmount));
        assertEq(executions.length, 3); // preExecute + withdraw + postExecute
        assertEq(executions[1].target, spoke);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IAaveV4Spoke.withdraw, (supplyReserveId, withdrawAmount, address(this)))
        );
    }

    function test_RepayHook_Build_ZeroDebt_PrevPipeNotConsulted() public {
        // The zero-debt early-return precedes previous-hook resolution: a prev hook publishing
        // the WRONG token would revert PREV_TOKEN_MISMATCH if the pipe were consulted
        mockSpoke.setUserDebt(borrowReserveId, address(this), 0, 0);
        prevHook.setOutToken(collateralToken); // wrong token for the repay slot
        prevHook.setOutAmount(1e18);

        Execution[] memory executions = repayHook.build(address(prevHook), address(this), _repayData(amount, true));
        assertEq(executions.length, 2);
    }

    function test_RepayHook_Build_PremiumOnlyDebt_DoesNotRevert() public {
        // drawn = 0 but premium > 0 → total debt = drawn + premium > 0
        mockSpoke.setUserDebt(borrowReserveId, address(this), 0, premiumDebt);
        Execution[] memory executions = repayHook.build(address(0), address(this), _repayData(amount, false));
        assertEq(executions.length, 6);
    }

    /*//////////////////////////////////////////////////////////////
                        PREVIOUS-HOOK PIPE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OpenHook_Build_RevertIf_PrevHookZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        openHook.build(address(0), address(this), _defaultData(amount, true, borrowAmount));
    }

    function test_RepayHook_Build_RevertIf_PrevHookZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayHook.build(address(0), address(this), _repayData(amount, true));
    }

    function test_OpenHook_Build_RevertIf_PrevTokenMismatch() public {
        // Open expects the collateral token from the previous hook
        prevHook.setOutToken(loanToken);
        prevHook.setOutAmount(2e18);
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        openHook.build(address(prevHook), address(this), _defaultData(amount, true, borrowAmount));
    }

    function test_RepayHook_Build_RevertIf_PrevTokenMismatch() public {
        // Repay expects the loan token from the previous hook
        prevHook.setOutToken(collateralToken);
        prevHook.setOutAmount(2e18);
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        repayHook.build(address(prevHook), address(this), _repayData(amount, true));
    }

    function test_CloseHook_Build_RevertIf_PrevTokenMismatch() public {
        // Close expects the loan token from the previous hook
        prevHook.setOutToken(collateralToken);
        prevHook.setOutAmount(2e18);
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        closeHook.build(address(prevHook), address(this), _defaultData(amount, true, withdrawAmount));
    }

    function test_OpenHook_Build_RevertIf_PrevAmountZero() public {
        prevHook.setOutToken(collateralToken);
        prevHook.setOutAmount(0);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(prevHook), address(this), _defaultData(amount, true, borrowAmount));
    }

    function test_RepayHook_Build_RevertIf_PrevAmountZero() public {
        prevHook.setOutToken(loanToken);
        prevHook.setOutAmount(0);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        repayHook.build(address(prevHook), address(this), _repayData(amount, true));
    }

    function test_OpenHook_BuildWithPrevHook_HappyPath() public {
        uint256 prevAmount = 2e18;
        prevHook.setOutToken(collateralToken);
        prevHook.setOutAmount(prevAmount);

        Execution[] memory executions =
            openHook.build(address(prevHook), address(this), _defaultData(amount, true, borrowAmount));

        assertEq(executions.length, 8);
        // approve uses the previous hook's output amount, not the calldata amount
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (spoke, prevAmount)));
        assertEq(
            executions[3].callData, abi.encodeCall(IAaveV4Spoke.supply, (supplyReserveId, prevAmount, address(this)))
        );
        // borrow leg still comes from calldata
        assertEq(
            executions[5].callData, abi.encodeCall(IAaveV4Spoke.borrow, (borrowReserveId, borrowAmount, address(this)))
        );
    }

    function test_RepayHook_BuildWithPrevHook_HappyPath() public {
        uint256 prevAmount = 4e17;
        prevHook.setOutToken(loanToken);
        prevHook.setOutAmount(prevAmount);

        Execution[] memory executions = repayHook.build(address(prevHook), address(this), _repayData(amount, true));

        assertEq(executions.length, 6);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (spoke, prevAmount)));
        assertEq(
            executions[3].callData, abi.encodeCall(IAaveV4Spoke.repay, (borrowReserveId, prevAmount, address(this)))
        );
    }

    /*//////////////////////////////////////////////////////////////
                       BUILD SHAPE HAPPY PATHS
    //////////////////////////////////////////////////////////////*/

    function test_OpenHook_Build_Shape() public view {
        Execution[] memory executions =
            openHook.build(address(0), address(this), _defaultData(amount, false, borrowAmount));

        // preExecute + approve(0) + approve(amount1) + supply + setUsingAsCollateral + borrow + approve(0) +
        // postExecute
        assertEq(executions.length, 8);
        assertEq(executions[0].target, address(openHook));
        assertEq(executions[1].target, collateralToken);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (spoke, 0)));
        assertEq(executions[2].target, collateralToken);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (spoke, amount)));
        assertEq(executions[3].target, spoke);
        assertEq(executions[3].callData, abi.encodeCall(IAaveV4Spoke.supply, (supplyReserveId, amount, address(this))));
        assertEq(executions[4].target, spoke);
        assertEq(
            executions[4].callData,
            abi.encodeCall(IAaveV4Spoke.setUsingAsCollateral, (supplyReserveId, true, address(this)))
        );
        assertEq(executions[5].target, spoke);
        assertEq(
            executions[5].callData, abi.encodeCall(IAaveV4Spoke.borrow, (borrowReserveId, borrowAmount, address(this)))
        );
        assertEq(executions[6].target, collateralToken);
        assertEq(executions[6].callData, abi.encodeCall(IERC20.approve, (spoke, 0)));
        assertEq(executions[7].target, address(openHook));
    }

    function test_RepayHook_Build_Shape() public view {
        // Cap below the total debt (1e18) → exact assets-denominated repay of the cap
        uint256 partialCap = 7e17;
        Execution[] memory executions = repayHook.build(address(0), address(this), _repayData(partialCap, false));

        // preExecute + approve(0) + approve(cap) + repay + approve(0) + postExecute
        assertEq(executions.length, 6);
        assertEq(executions[0].target, address(repayHook));
        assertEq(executions[1].target, loanToken);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (spoke, 0)));
        assertEq(executions[2].target, loanToken);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (spoke, partialCap)));
        assertEq(executions[3].target, spoke);
        assertEq(
            executions[3].callData, abi.encodeCall(IAaveV4Spoke.repay, (borrowReserveId, partialCap, address(this)))
        );
        assertEq(executions[4].target, loanToken);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (spoke, 0)));
        assertEq(executions[5].target, address(repayHook));
    }

    function test_CloseHook_Build_Shape() public view {
        // Cap below the total debt (1e18) → exact assets-denominated repay of the cap
        uint256 partialCap = 7e17;
        Execution[] memory executions =
            closeHook.build(address(0), address(this), _defaultData(partialCap, false, withdrawAmount));

        // preExecute + approve(0) + approve(cap) + repay + approve(0) + withdraw + postExecute
        assertEq(executions.length, 7);
        assertEq(executions[0].target, address(closeHook));
        assertEq(executions[1].target, loanToken);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (spoke, 0)));
        assertEq(executions[2].target, loanToken);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (spoke, partialCap)));
        // repay executes strictly before withdraw
        assertEq(executions[3].target, spoke);
        assertEq(
            executions[3].callData, abi.encodeCall(IAaveV4Spoke.repay, (borrowReserveId, partialCap, address(this)))
        );
        assertEq(executions[4].target, loanToken);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (spoke, 0)));
        assertEq(executions[5].target, spoke);
        assertEq(
            executions[5].callData,
            abi.encodeCall(IAaveV4Spoke.withdraw, (supplyReserveId, withdrawAmount, address(this)))
        );
        assertEq(executions[6].target, address(closeHook));
    }

    function test_RepayHook_Build_FullRepay() public view {
        Execution[] memory executions = repayHook.build(address(0), address(this), _repayData(MAX, false));

        assertEq(executions.length, 6);
        // approval is exactly the resolved total debt (drawn + premium), not the sentinel
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (spoke, drawnDebt + premiumDebt)));
        // repay passes the sentinel through so the Spoke resolves the full debt natively
        assertEq(executions[3].callData, abi.encodeCall(IAaveV4Spoke.repay, (borrowReserveId, MAX, address(this))));
    }

    function test_CloseHook_Build_FullRepayAndMaxWithdraw() public view {
        Execution[] memory executions = closeHook.build(address(0), address(this), _defaultData(MAX, false, MAX));

        assertEq(executions.length, 7);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (spoke, drawnDebt + premiumDebt)));
        assertEq(executions[3].callData, abi.encodeCall(IAaveV4Spoke.repay, (borrowReserveId, MAX, address(this))));
        // supplied > 0 → the withdraw sentinel is passed through
        assertEq(executions[5].callData, abi.encodeCall(IAaveV4Spoke.withdraw, (supplyReserveId, MAX, address(this))));
    }

    function test_RepayHook_Build_CapEqualsDebt_EmitsRepayMax() public view {
        // Behavior change vs pre-cap semantics: a non-sentinel cap == total debt is a predicted
        // clear and emits repay(max) so the Spoke clears the debt without rounding dust
        uint256 debt = drawnDebt + premiumDebt;
        Execution[] memory executions = repayHook.build(address(0), address(this), _repayData(debt, false));
        assertEq(executions.length, 6);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (spoke, debt)));
        assertEq(executions[3].callData, abi.encodeCall(IAaveV4Spoke.repay, (borrowReserveId, MAX, address(this))));
    }

    function test_RepayHook_Build_CapAboveDebt_MinsWithDebt() public view {
        // cap > debt resolves to the debt; approval covers the debt, never the cap
        uint256 debt = drawnDebt + premiumDebt;
        Execution[] memory executions = repayHook.build(address(0), address(this), _repayData(debt + 5e17, false));
        assertEq(executions.length, 6);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (spoke, debt)));
        assertEq(executions[3].callData, abi.encodeCall(IAaveV4Spoke.repay, (borrowReserveId, MAX, address(this))));
    }

    function test_RepayHook_Build_CapBetweenDrawnAndTotal_ExactRepay() public view {
        // drawn < cap < drawn + premium: still a partial repay of the exact cap
        uint256 cap = drawnDebt + premiumDebt / 2;
        Execution[] memory executions = repayHook.build(address(0), address(this), _repayData(cap, false));
        assertEq(executions.length, 6);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (spoke, cap)));
        assertEq(executions[3].callData, abi.encodeCall(IAaveV4Spoke.repay, (borrowReserveId, cap, address(this))));
    }

    function test_RepayHook_Build_PrevCapAboveDebt_MinsWithDebt() public {
        // A PREV-fed cap larger than the debt caps instead of reverting; leftover stays in wallet
        uint256 debt = drawnDebt + premiumDebt;
        prevHook.setOutToken(loanToken);
        prevHook.setOutAmount(debt * 2);

        Execution[] memory executions = repayHook.build(address(prevHook), address(this), _repayData(amount, true));
        assertEq(executions.length, 6);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (spoke, debt)));
        assertEq(executions[3].callData, abi.encodeCall(IAaveV4Spoke.repay, (borrowReserveId, MAX, address(this))));
    }

    function test_RepayHook_SettleRoundTrip_ZeroDebt_Graceful() public {
        mockSpoke.setUserDebt(borrowReserveId, address(this), 0, 0);
        bytes memory data = _repayData(amount, false);
        mockLoanToken.mint(address(this), amount);

        repayHook.preExecute(address(0), address(this), data);
        repayHook.postExecute(address(0), address(this), data);

        assertEq(repayHook.getOutAmount(address(this)), 0); // terminal repay publishes 0
        assertEq(repayHook.getOutToken(address(this)), loanToken);
    }

    function test_CloseHook_Build_RevertIf_MaxWithdraw_ZeroSupplied() public {
        mockSpoke.setUserSuppliedAssets(supplyReserveId, address(this), 0);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        closeHook.build(address(0), address(this), _defaultData(amount, false, MAX));
    }

    /*//////////////////////////////////////////////////////////////
                       SIZING INTERFACE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OpenHook_DecodeAmounts_And_Roles() public view {
        bytes memory data = _defaultData(amount, false, borrowAmount);
        uint256[] memory amounts = openHook.decodeAmounts(data);
        assertEq(amounts.length, 2);
        assertEq(amounts[0], amount); // slot at offset 176
        assertEq(amounts[1], borrowAmount); // slot at offset 208

        ISuperHookInflowOutflow.AmountMeta[] memory meta = openHook.amountRoles(data);
        assertEq(meta.length, 2);
        assertEq(uint256(meta[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(meta[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));
        assertEq(uint256(meta[1].dir), uint256(ISuperHookInflowOutflow.Direction.OUT));
        assertEq(uint256(meta[1].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));
    }

    function test_OpenHook_ReplaceCalldataAmounts() public view {
        bytes memory data = _defaultData(amount, false, borrowAmount);

        uint256[] memory newAmounts = new uint256[](2);
        newAmounts[0] = 7e17;
        newAmounts[1] = 9e17;
        bytes memory replaced = openHook.replaceCalldataAmounts(data, newAmounts);

        uint256[] memory decoded = openHook.decodeAmounts(replaced);
        assertEq(decoded[0], 7e17);
        assertEq(decoded[1], 9e17);
        // identity fields untouched
        assertEq(openHook.inspect(replaced), openHook.inspect(_defaultData(amount, false, borrowAmount)));
    }

    function test_OpenHook_ReplaceCalldataAmounts_RevertIf_WrongLength() public {
        bytes memory data = _defaultData(amount, false, borrowAmount);
        uint256[] memory one = new uint256[](1);
        one[0] = 7e17;
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        openHook.replaceCalldataAmounts(data, one);
    }

    function test_CloseHook_DecodeAmounts_Roles_And_Replace() public {
        bytes memory data = _defaultData(amount, false, withdrawAmount);
        uint256[] memory amounts = closeHook.decodeAmounts(data);
        assertEq(amounts.length, 2);
        assertEq(amounts[0], amount);
        assertEq(amounts[1], withdrawAmount);

        ISuperHookInflowOutflow.AmountMeta[] memory meta = closeHook.amountRoles(data);
        assertEq(meta.length, 2);
        assertEq(uint256(meta[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(meta[1].dir), uint256(ISuperHookInflowOutflow.Direction.OUT));

        uint256[] memory newAmounts = new uint256[](2);
        newAmounts[0] = 3e17;
        newAmounts[1] = 4e17;
        uint256[] memory decoded = closeHook.decodeAmounts(closeHook.replaceCalldataAmounts(data, newAmounts));
        assertEq(decoded[0], 3e17);
        assertEq(decoded[1], 4e17);

        uint256[] memory one = new uint256[](1);
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        closeHook.replaceCalldataAmounts(data, one);
    }

    /// @dev AaveV4RepayHookV2 does NOT override the sizing interface, so it inherits
    ///      BaseLoanHook's single-slot implementation pinned to the legacy Morpho-shaped offset
    ///      132 — NOT the V2 layout's amount1 offset 176. This test documents the actual (buggy)
    /// @dev Single-slot views read / rewrite offset 176 (fixed long ago; kept as the regression pin).
    function test_RepayHook_SizingInterface_SingleSlotAtOffset176() public {
        bytes memory data = _repayData(amount, false);

        // decodeAmounts reads the actual repay amount at the Aave V4 V2 offset 176
        uint256[] memory amounts = repayHook.decodeAmounts(data);
        assertEq(amounts.length, 1);
        assertEq(amounts[0], amount);

        ISuperHookInflowOutflow.AmountMeta[] memory meta = repayHook.amountRoles(data);
        assertEq(meta.length, 1);
        assertEq(uint256(meta[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(meta[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));

        uint256[] memory two = new uint256[](2);
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        repayHook.replaceCalldataAmounts(data, two);

        // Exactly one amount is accepted and written at offset 176; reserve ids stay untouched
        uint256[] memory one = new uint256[](1);
        one[0] = 123;
        bytes memory replaced = repayHook.replaceCalldataAmounts(data, one);
        assertEq(_readUint256(replaced, 176), 123);
        assertEq(_readUint256(replaced, 112), supplyReserveId);
        assertEq(_readUint256(replaced, 144), borrowReserveId);
        assertEq(repayHook.decodeAmounts(replaced)[0], 123);
    }

    /*//////////////////////////////////////////////////////////////
                    DECODE USE PREV HOOK AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DecodeUsePrevHookAmount_ReadsByte240() public {
        bytes memory data = _defaultData(amount, false, borrowAmount);
        assertFalse(openHook.decodeUsePrevHookAmount(data));
        assertFalse(repayHook.decodeUsePrevHookAmount(data));
        assertFalse(closeHook.decodeUsePrevHookAmount(data));

        data[240] = 0x01;
        assertTrue(openHook.decodeUsePrevHookAmount(data));
        assertTrue(repayHook.decodeUsePrevHookAmount(data));
        assertTrue(closeHook.decodeUsePrevHookAmount(data));

        // strict canonical-boolean reader: any non-canonical byte reverts, matching execution
        data[240] = 0xFF;
        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        openHook.decodeUsePrevHookAmount(data);
    }

    /*//////////////////////////////////////////////////////////////
                             INSPECT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev SUP-21239: MARKET key FIRST, then spoke, tokens and both reserve ids — still exactly 144 bytes and
    ///      the same field order as SUP-21143's payload (leaves hash these raw bytes, so the layout is frozen);
    ///      only the meaning of the first 20 bytes moved. Every hook of the market now inspects to the SAME
    ///      payload, where before OPEN/CLOSE were supply-keyed and REPAY borrow-keyed.
    function test_Inspect_Payload_AllHooks() public view {
        bytes memory expected = abi.encodePacked(
            _marketKey(spoke, supplyReserveId, borrowReserveId),
            spoke,
            loanToken,
            collateralToken,
            supplyReserveId,
            borrowReserveId
        );
        assertEq(expected.length, 144);
        assertEq(openHook.inspect(_defaultData(amount, false, borrowAmount)), expected);
        assertEq(repayHook.inspect(_repayData(amount, false)), expected);
        assertEq(closeHook.inspect(_defaultData(amount, false, withdrawAmount)), expected);
    }

    /*//////////////////////////////////////////////////////////////
                    HEADER BIND (SUP-21239) — COMPOSITE OPS
    //////////////////////////////////////////////////////////////*/

    /// @dev The header yield source must be the MARKET key of the (Spoke, supply, borrow) triple the body acts
    ///      on; the oracle id is identity only. Wrong keys revert on build, preExecute, inspect AND the (now
    ///      strict) composite sizing views. The wrong-key set deliberately includes BOTH legs' reserve keys:
    ///      under SUP-21143 one of them was the correct header, so this is the fail-closed property that lets
    ///      the new hook addresses coexist with old reserve-keyed roots.
    function test_Header_KeyPinned_AnyNonzeroOracleId_AllHooks() public {
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            bool isRepay = i == 1;
            bytes memory good = isRepay ? _repayData(amount, false) : _defaultData(amount, false, borrowAmount);
            bytes memory body = BytesLib.slice(good, 52, good.length - 52);

            // oracle id free: same executions, same identity
            bytes memory tagged = abi.encodePacked(
                keccak256("any-oracle-id"), _marketKey(spoke, supplyReserveId, borrowReserveId), body
            );
            Execution[] memory a = hooks[i].build(address(0), address(this), tagged);
            Execution[] memory b = hooks[i].build(address(0), address(this), good);
            assertEq(a.length, b.length);
            for (uint256 j = 1; j + 1 < a.length; ++j) {
                assertEq(a[j].target, b[j].target);
                assertEq(a[j].callData, b[j].callData);
            }
            assertEq(hooks[i].inspect(tagged), hooks[i].inspect(good));

            address[6] memory wrong = [
                _key(spoke, supplyReserveId), // the OLD SUP-21143 header for OPEN / CLOSE
                _key(spoke, borrowReserveId), // the OLD SUP-21143 header for REPAY
                _marketKey(spoke, borrowReserveId, supplyReserveId), // legs swapped: a different market
                _marketKey(address(0xBEEF), supplyReserveId, borrowReserveId), // same pair, other spoke
                spoke,
                address(0xBEEF)
            ];
            for (uint256 w; w < wrong.length; ++w) {
                bytes memory bad = abi.encodePacked(AAVE_V4_YS_ORACLE_ID, wrong[w], body);
                vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
                hooks[i].build(address(0), address(this), bad);
                vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
                hooks[i].preExecute(address(0), address(this), bad);
                vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
                hooks[i].inspect(bad);
                vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
                hooks[i].decodeAmounts(bad);
                vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
                hooks[i].replaceCalldataAmounts(bad, new uint256[](isRepay ? 1 : 2));
            }
            bytes memory zeroKey = abi.encodePacked(AAVE_V4_YS_ORACLE_ID, address(0), body);
            vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
            hooks[i].build(address(0), address(this), zeroKey);
        }
    }

    /// @dev Format errors surface before the identity error: a wrong key on a malformed payload still reports the
    ///      format fault (length / bool / identical tokens / reserved word)
    function test_Header_FormatErrorsPrecedeKeyMismatch() public {
        bytes memory good = _defaultData(amount, false, borrowAmount);
        bytes memory body = BytesLib.slice(good, 52, good.length - 52);
        bytes memory bad = abi.encodePacked(AAVE_V4_YS_ORACLE_ID, address(0xBEEF), body);
        bad[240] = 0x02;
        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        openHook.build(address(0), address(this), bad);
        bytes memory badRepay = abi.encodePacked(
            AAVE_V4_YS_ORACLE_ID, address(0xBEEF), BytesLib.slice(_defaultData(amount, false, 1), 52, 189)
        );
        vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
        repayHook.build(address(0), address(this), badRepay);
        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        openHook.build(address(0), address(this), _truncate(bad, 240));
    }

    /// @dev The key is identity only: every non-ERC20 target and every approve spender is the calldata Spoke
    function test_Header_SpokeIsCallTarget_NotKey() public view {
        BaseLoanHookV2[3] memory hooks = _hooks();
        address key = _marketKey(spoke, supplyReserveId, borrowReserveId);
        address keyB = _key(spoke, supplyReserveId);
        for (uint256 i; i < hooks.length; ++i) {
            bytes memory data = i == 1 ? _repayData(amount, false) : _defaultData(amount, false, borrowAmount);
            Execution[] memory ex = hooks[i].build(address(0), address(this), data);
            for (uint256 j = 1; j + 1 < ex.length; ++j) {
                assertTrue(ex[j].target != key && ex[j].target != keyB, "key is never a target");
                if (ex[j].target == loanToken || ex[j].target == collateralToken) {
                    (address spender,) = abi.decode(BytesLib.slice(ex[j].callData, 4, 64), (address, uint256));
                    assertEq(spender, spoke, "approve spender is the Spoke");
                } else {
                    assertEq(ex[j].target, spoke, "provider target is the Spoke");
                }
            }
        }
    }

    /// @dev The library the hooks pin against is byte-identical to the deployed registry's derivation. The
    ///      reserve assertion stays because the V1 six, the idle pair and the registry's NAV namespace still
    ///      use it; the market assertion is what the V2 hooks now enforce.
    function testFuzz_ReserveKey_MatchesRegistry(address spoke_, uint256 reserveId) public {
        AaveV4ReserveRegistryV2 registry = new AaveV4ReserveRegistryV2(address(this));
        assertEq(AaveV4ReserveKey.computeReserveKey(spoke_, reserveId), registry.computeReserveKey(spoke_, reserveId));
    }

    /// @dev The market derivation the V2 headers pin against equals the registry's public one, so an off-chain
    ///      consumer that queries the registry derives exactly the header the hooks accept.
    function testFuzz_MarketKey_MatchesRegistry(address spoke_, uint256 supplyId_, uint256 borrowId_) public {
        AaveV4ReserveRegistryV2 registry = new AaveV4ReserveRegistryV2(address(this));
        assertEq(
            AaveV4ReserveKey.computeMarketKey(spoke_, supplyId_, borrowId_),
            registry.computeMarketKey(spoke_, supplyId_, borrowId_)
        );
    }

    function test_Inspect_UnchangedWhenOnlyAmountsChange() public view {
        bytes memory a = openHook.inspect(_defaultData(amount, false, borrowAmount));
        bytes memory b = openHook.inspect(_defaultData(9e18, true, 1));
        assertEq(a, b);
    }

    function test_Inspect_ChangesForEachIdentityField() public view {
        bytes memory base = openHook.inspect(_defaultData(amount, false, borrowAmount));
        address other = address(mockOtherToken);

        // loan token
        bytes memory changed = openHook.inspect(
            _encode(other, collateralToken, spoke, supplyReserveId, borrowReserveId, amount, bytes1(0x00), borrowAmount)
        );
        assertTrue(keccak256(changed) != keccak256(base));

        // collateral token
        changed = openHook.inspect(
            _encode(loanToken, other, spoke, supplyReserveId, borrowReserveId, amount, bytes1(0x00), borrowAmount)
        );
        assertTrue(keccak256(changed) != keccak256(base));

        // spoke
        changed = openHook.inspect(
            _encode(
                loanToken, collateralToken, other, supplyReserveId, borrowReserveId, amount, bytes1(0x00), borrowAmount
            )
        );
        assertTrue(keccak256(changed) != keccak256(base));

        // supply reserve id
        changed = openHook.inspect(
            _encode(
                loanToken,
                collateralToken,
                spoke,
                supplyReserveId + 10,
                borrowReserveId,
                amount,
                bytes1(0x00),
                borrowAmount
            )
        );
        assertTrue(keccak256(changed) != keccak256(base));

        // borrow reserve id
        changed = openHook.inspect(
            _encode(
                loanToken,
                collateralToken,
                spoke,
                supplyReserveId,
                borrowReserveId + 10,
                amount,
                bytes1(0x00),
                borrowAmount
            )
        );
        assertTrue(keccak256(changed) != keccak256(base));
    }

    /*//////////////////////////////////////////////////////////////
                       SETTLE ROUND-TRIP TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OpenHook_Settle_RoundTrip() public {
        bytes memory data = _defaultData(amount, false, borrowAmount);
        mockCollateralToken.mint(address(this), amount);

        openHook.preExecute(address(0), address(this), data);

        // simulate: supply spends the exact collateral amount, borrow delivers the exact loan amount
        mockCollateralToken.transfer(SINK, amount);
        mockLoanToken.mint(address(this), borrowAmount);

        openHook.postExecute(address(0), address(this), data);
        assertEq(openHook.getOutAmount(address(this)), borrowAmount);
        assertEq(openHook.getOutToken(address(this)), loanToken);
    }

    function test_RepayHook_Settle_RoundTrip() public {
        uint256 repayAmount = 4e17;
        bytes memory data = _repayData(repayAmount, false);
        mockLoanToken.mint(address(this), repayAmount);

        repayHook.preExecute(address(0), address(this), data);

        // simulate: repay spends the exact loan amount
        mockLoanToken.transfer(SINK, repayAmount);

        repayHook.postExecute(address(0), address(this), data);
        // Terminal repay hook publishes outAmount = 0 (spend is not a product); outToken kept
        assertEq(repayHook.getOutAmount(address(this)), 0);
        assertEq(repayHook.getOutToken(address(this)), loanToken);
    }

    function test_CloseHook_Settle_RoundTrip() public {
        uint256 repayAmount = 4e17;
        bytes memory data = _defaultData(repayAmount, false, withdrawAmount);
        mockLoanToken.mint(address(this), repayAmount);

        closeHook.preExecute(address(0), address(this), data);

        // simulate: repay spends loan tokens, withdraw releases collateral
        mockLoanToken.transfer(SINK, repayAmount);
        mockCollateralToken.mint(address(this), withdrawAmount);

        closeHook.postExecute(address(0), address(this), data);
        assertEq(closeHook.getOutAmount(address(this)), withdrawAmount);
        assertEq(closeHook.getOutToken(address(this)), collateralToken);
    }

    function test_OpenHook_Settle_RevertIf_DeltaMismatch() public {
        bytes memory data = _defaultData(amount, false, borrowAmount);
        mockCollateralToken.mint(address(this), amount);

        openHook.preExecute(address(0), address(this), data);

        // spend less collateral than the resolved expected amount
        uint256 spent = amount - 1e17;
        mockCollateralToken.transfer(SINK, spent);
        mockLoanToken.mint(address(this), borrowAmount);

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, amount, spent));
        openHook.postExecute(address(0), address(this), data);
    }

    function test_RepayHook_Settle_RevertIf_DeltaMismatch() public {
        uint256 repayAmount = 4e17;
        bytes memory data = _repayData(repayAmount, false);
        mockLoanToken.mint(address(this), repayAmount);

        repayHook.preExecute(address(0), address(this), data);

        uint256 spent = 3e17;
        mockLoanToken.transfer(SINK, spent);

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, repayAmount, spent));
        repayHook.postExecute(address(0), address(this), data);
    }

    function test_CloseHook_Settle_RevertIf_DeltaMismatch() public {
        uint256 repayAmount = 4e17;
        bytes memory data = _defaultData(repayAmount, false, withdrawAmount);
        mockLoanToken.mint(address(this), repayAmount);

        closeHook.preExecute(address(0), address(this), data);

        // loan leg settles exactly, collateral leg receives less than expected
        mockLoanToken.transfer(SINK, repayAmount);
        uint256 received = withdrawAmount - 1e17;
        mockCollateralToken.mint(address(this), received);

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, withdrawAmount, received));
        closeHook.postExecute(address(0), address(this), data);
    }

    /*//////////////////////////////////////////////////////////////
            CLOSE WITHDRAW LEG: LIVE-POSITION GATE (typed over-position)
    //////////////////////////////////////////////////////////////*/

    /// @dev CLOSE resolves its withdraw word against the live position before any provider execution: above it →
    ///      typed WITHDRAW_EXCEEDS_SUPPLIED (Aave would otherwise silently full-withdraw and the hook would fail late
    /// as DELTA_MISMATCH); exactly the position → exact path; un-flagged (idle) → RESERVE_NOT_COLLATERAL
    function test_CloseHook_WithdrawLeg_ExceedsSupplied_Typed_And_UnflaggedRefused() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                BaseAaveV4LoanHookV2.WITHDRAW_EXCEEDS_SUPPLIED.selector, suppliedAssets + 1, suppliedAssets
            )
        );
        closeHook.build(address(0), address(this), _defaultData(amount, false, suppliedAssets + 1));
        vm.expectRevert(
            abi.encodeWithSelector(
                BaseAaveV4LoanHookV2.WITHDRAW_EXCEEDS_SUPPLIED.selector, suppliedAssets + 1, suppliedAssets
            )
        );
        closeHook.preExecute(address(0), address(this), _defaultData(amount, false, suppliedAssets + 1));
        Execution[] memory ex = closeHook.build(address(0), address(this), _defaultData(amount, false, suppliedAssets));
        assertEq(
            ex[ex.length - 2].callData,
            abi.encodeCall(IAaveV4Spoke.withdraw, (supplyReserveId, suppliedAssets, address(this))),
            "exact == position takes the exact path"
        );
        mockSpoke.setUsingAsCollateral(supplyReserveId, false, address(this));
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_NOT_COLLATERAL.selector);
        closeHook.build(address(0), address(this), _defaultData(amount, false, withdrawAmount));
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_NOT_COLLATERAL.selector);
        closeHook.build(address(0), address(this), _defaultData(amount, false, MAX));
    }

    /// @dev The header oracle id (offset 0) must be nonzero on every V2 hook: build, preExecute, inspect and the strict
    ///      sizing views all refuse it (checked right after the length, before the key pin)
    function test_Header_ZeroOracleId_Refused_AllHooks() public {
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            bytes memory good = i == 1 ? _repayData(amount, false) : _defaultData(amount, false, borrowAmount);
            bytes memory zeroId = abi.encodePacked(bytes32(0), BytesLib.slice(good, 32, good.length - 32));
            vm.expectRevert(BaseAaveV4LoanHookV2.ORACLE_ID_NOT_VALID.selector);
            hooks[i].build(address(0), address(this), zeroId);
            vm.expectRevert(BaseAaveV4LoanHookV2.ORACLE_ID_NOT_VALID.selector);
            hooks[i].preExecute(address(0), address(this), zeroId);
            vm.expectRevert(BaseAaveV4LoanHookV2.ORACLE_ID_NOT_VALID.selector);
            hooks[i].inspect(zeroId);
            vm.expectRevert(BaseAaveV4LoanHookV2.ORACLE_ID_NOT_VALID.selector);
            hooks[i].decodeAmounts(zeroId);
            vm.expectRevert(BaseAaveV4LoanHookV2.ORACLE_ID_NOT_VALID.selector);
            hooks[i].replaceCalldataAmounts(zeroId, new uint256[](i == 1 ? 1 : 2));
        }
    }

    /// @dev Precedence: a zero oracle id is reported before a wrong key (both header faults present)
    function test_Header_ZeroOracleId_PrecedesWrongKey() public {
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            bytes memory good = i == 1 ? _repayData(amount, false) : _defaultData(amount, false, borrowAmount);
            bytes memory bad = abi.encodePacked(bytes32(0), address(0xBEEF), BytesLib.slice(good, 52, 189));
            vm.expectRevert(BaseAaveV4LoanHookV2.ORACLE_ID_NOT_VALID.selector);
            hooks[i].build(address(0), address(this), bad);
            vm.expectRevert(BaseAaveV4LoanHookV2.ORACLE_ID_NOT_VALID.selector);
            hooks[i].inspect(bad);
        }
    }

    /// @dev CLOSE and RELEASE agree on the withdraw-leg order: position/flag gate first, then the zero word — a zero
    ///      withdraw word over an un-flagged position is RESERVE_NOT_COLLATERAL on both, and over an empty one it is
    ///      AMOUNT_NOT_VALID (empty position) on both
    function test_CloseHook_WithdrawLeg_OrderMatchesRelease() public {
        mockSpoke.setUsingAsCollateral(supplyReserveId, false, address(this));
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_NOT_COLLATERAL.selector);
        closeHook.build(address(0), address(this), _defaultData(amount, false, 0));
        mockSpoke.setUserSuppliedAssets(supplyReserveId, address(this), 0);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        closeHook.build(address(0), address(this), _defaultData(amount, false, 0));
    }

    /// @dev CLOSE resolves its repay leg (and therefore the prev-hook pipe) BEFORE the withdraw-leg gate: with debt
    /// open, usePrev and a broken pipe over an un-flagged position, the pipe error surfaces first — deliberate (the
    /// repay
    ///      leg is the primary slot), pinned here so a reorder is a visible change
    function test_CloseHook_RepayPipe_ResolvedBeforeWithdrawGate() public {
        mockSpoke.setUsingAsCollateral(supplyReserveId, false, address(this));
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector); // prevHook == address(0)
        closeHook.build(address(0), address(this), _defaultData(amount, true, withdrawAmount));
        prevHook.setOutToken(collateralToken); // wrong token for the repay leg
        prevHook.setOutAmount(amount);
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        closeHook.build(address(prevHook), address(this), _defaultData(amount, true, withdrawAmount));
        prevHook.setOutToken(loanToken); // pipe healthy: the withdraw gate is next
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_NOT_COLLATERAL.selector);
        closeHook.build(address(prevHook), address(this), _defaultData(amount, true, withdrawAmount));
    }

    /// @dev Header key fuzz, composite trio: a market key over any other reserve pair or any other spoke is
    ///      refused by every entry point — build, inspect and both sizing views (strict decoder)
    function testFuzz_Header_WrongKey_Refused_AllHooks(uint256 otherReserveId, address otherSpoke) public {
        vm.assume(otherReserveId != supplyReserveId && otherReserveId != borrowReserveId);
        vm.assume(otherSpoke != spoke);
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            bytes memory good = i == 1 ? _repayData(amount, false) : _defaultData(amount, false, borrowAmount);
            bytes memory body = BytesLib.slice(good, 52, 189);
            bytes[3] memory bad = [
                abi.encodePacked(AAVE_V4_YS_ORACLE_ID, _marketKey(spoke, otherReserveId, borrowReserveId), body),
                abi.encodePacked(AAVE_V4_YS_ORACLE_ID, _marketKey(spoke, supplyReserveId, otherReserveId), body),
                abi.encodePacked(AAVE_V4_YS_ORACLE_ID, _marketKey(otherSpoke, supplyReserveId, borrowReserveId), body)
            ];
            uint256[] memory one = new uint256[](i == 1 ? 1 : 2);
            one[0] = 1;
            for (uint256 b; b < bad.length; ++b) {
                vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
                hooks[i].build(address(0), address(this), bad[b]);
                vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
                hooks[i].inspect(bad[b]);
                vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
                hooks[i].decodeAmounts(bad[b]);
                vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
                hooks[i].replaceCalldataAmounts(bad[b], one);
            }
        }
    }

    /// @dev The position gates (idle / collateral / over-position) live in build and preExecute only: the sizing views
    ///      and inspect() are pure and keep working on an empty or un-flagged account, so OMS can size a template
    ///      before the position exists and build() is what refuses it
    function test_SizingViews_Pure_NoPositionGate_OpenAndClose() public {
        mockSpoke.setUsingAsCollateral(supplyReserveId, false, address(this));
        mockSpoke.setUserSuppliedAssets(supplyReserveId, address(this), 0);
        bytes memory closeData = _defaultData(amount, false, withdrawAmount);
        bytes memory openData = _defaultData(amount, false, borrowAmount);
        assertEq(closeHook.decodeAmounts(closeData)[1], withdrawAmount, "close sizing view");
        assertEq(openHook.decodeAmounts(openData)[0], amount, "open sizing view");
        uint256[] memory two = new uint256[](2);
        two[0] = amount;
        two[1] = 1;
        assertEq(closeHook.decodeAmounts(closeHook.replaceCalldataAmounts(closeData, two))[1], 1, "close replace");
        assertEq(closeHook.inspect(closeData).length, 144, "inspect");
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector); // empty position
        closeHook.build(address(0), address(this), closeData);
        mockSpoke.setUserSuppliedAssets(supplyReserveId, address(this), 5e18); // idle, un-flagged
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_NOT_COLLATERAL.selector);
        closeHook.build(address(0), address(this), closeData);
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_HAS_IDLE_POSITION.selector);
        openHook.build(address(0), address(this), openData);
    }

    /*//////////////////////////////////////////////////////////////
                OPEN IDLE-MODE GUARD (one mode per account/reserve)
    //////////////////////////////////////////////////////////////*/

    /// @dev An un-flagged supplied position is the idle MONEY_MARKET side's (ledger-tracked): OPEN refuses to flip it
    ///      into LOAN mode, on build and on preExecute, before any provider execution
    function test_OpenHook_Build_RevertIf_IdlePositionOnReserve() public {
        mockSpoke.setUsingAsCollateral(supplyReserveId, false, address(this));
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_HAS_IDLE_POSITION.selector);
        openHook.build(address(0), address(this), _defaultData(amount, false, borrowAmount));
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_HAS_IDLE_POSITION.selector);
        openHook.preExecute(address(0), address(this), _defaultData(amount, false, borrowAmount));
        // CLOSE never pays an un-flagged (idle) position out either — its withdraw leg carries the collateral gate;
        // REPAY touches no collateral and builds normally (pre + 4 + post)
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_NOT_COLLATERAL.selector);
        closeHook.build(address(0), address(this), _defaultData(amount, false, withdrawAmount));
        assertEq(repayHook.build(address(0), address(this), _repayData(amount, false)).length, 6);
    }

    /// @dev A fresh reserve (no position, flag false) and an already-flagged reserve both open normally; the guard
    ///      is per account
    function test_OpenHook_Build_FreshOrFlaggedReserve_Passes() public {
        mockSpoke.setUsingAsCollateral(supplyReserveId, false, address(this));
        mockSpoke.setUserSuppliedAssets(supplyReserveId, address(this), 0);
        assertEq(
            openHook.build(address(0), address(this), _defaultData(amount, false, borrowAmount)).length, 8, "fresh"
        );
        mockSpoke.setUsingAsCollateral(supplyReserveId, true, address(this));
        mockSpoke.setUserSuppliedAssets(supplyReserveId, address(this), suppliedAssets);
        assertEq(
            openHook.build(address(0), address(this), _defaultData(amount, false, borrowAmount)).length, 8, "flagged"
        );
        address alice = makeAddr("alice");
        mockSpoke.setUserSuppliedAssets(supplyReserveId, alice, suppliedAssets); // alice idle, this account flagged
        assertEq(openHook.build(address(0), address(this), _defaultData(amount, false, borrowAmount)).length, 8);
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_HAS_IDLE_POSITION.selector);
        openHook.build(address(0), alice, _defaultData(amount, false, borrowAmount));
    }

    /*//////////////////////////////////////////////////////////////
                         ENCODING HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev A reserve-leg key. After SUP-21239 these are WRONG headers for the V2 hooks — kept because that
    ///      is exactly what the pin must now reject (an old reserve-keyed root against a new hook address).
    function _key(address spoke_, uint256 reserveId) internal pure returns (address) {
        return AaveV4ReserveKey.computeReserveKey(spoke_, reserveId);
    }

    /// @dev The market key every V2 LOAN header must carry: one key per (spoke, supply, borrow) triple, the
    ///      same value for every leg of the market.
    function _marketKey(address spoke_, uint256 supplyId_, uint256 borrowId_) internal pure returns (address) {
        return AaveV4ReserveKey.computeMarketKey(spoke_, supplyId_, borrowId_);
    }

    /// @dev Canonical 241-byte Aave V4 V2 layout with an explicit header:
    ///      bytes32 yieldSourceOracleId | address yieldSource (market key) | loanToken | collateralToken | spoke |
    ///      supplyReserveId | borrowReserveId | amount1 | amount2 | usePrevHookAmount (1 byte)
    function _encodeH(
        bytes32 oracleId,
        address headerKey,
        address loanToken_,
        address collateralToken_,
        address spoke_,
        uint256 supplyReserveId_,
        uint256 borrowReserveId_,
        uint256 amount1_,
        bytes1 usePrev_,
        uint256 amount2_
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            oracleId,
            headerKey,
            loanToken_,
            collateralToken_,
            spoke_,
            supplyReserveId_,
            borrowReserveId_,
            amount1_,
            amount2_,
            usePrev_
        );
    }

    /// @dev Supply-keyed header (OPEN / CLOSE): yieldSource = key(spoke, supplyReserveId)
    function _encode(
        address loanToken_,
        address collateralToken_,
        address spoke_,
        uint256 supplyReserveId_,
        uint256 borrowReserveId_,
        uint256 amount1_,
        bytes1 usePrev_,
        uint256 amount2_
    )
        internal
        pure
        returns (bytes memory)
    {
        return _encodeH(
            AAVE_V4_YS_ORACLE_ID,
            _marketKey(spoke_, supplyReserveId_, borrowReserveId_),
            loanToken_,
            collateralToken_,
            spoke_,
            supplyReserveId_,
            borrowReserveId_,
            amount1_,
            usePrev_,
            amount2_
        );
    }

    /// @dev REPAY header. Historically borrow-keyed; under SUP-21239 it carries the SAME market key as every
    ///      other leg, so this builder is now identical to `_encode` and is kept only so the call sites that
    ///      documented "the borrow-keyed one" still read that way.
    function _encodeB(
        address loanToken_,
        address collateralToken_,
        address spoke_,
        uint256 supplyReserveId_,
        uint256 borrowReserveId_,
        uint256 amount1_,
        bytes1 usePrev_,
        uint256 amount2_
    )
        internal
        pure
        returns (bytes memory)
    {
        return _encodeH(
            AAVE_V4_YS_ORACLE_ID,
            _marketKey(spoke_, supplyReserveId_, borrowReserveId_),
            loanToken_,
            collateralToken_,
            spoke_,
            supplyReserveId_,
            borrowReserveId_,
            amount1_,
            usePrev_,
            amount2_
        );
    }

    /// @dev Standalone REPAY payload: borrow-keyed header, reserved secondary word zero
    function _repayData(uint256 cap, bool usePrev_) internal view returns (bytes memory) {
        return _encodeB(
            loanToken,
            collateralToken,
            spoke,
            supplyReserveId,
            borrowReserveId,
            cap,
            usePrev_ ? bytes1(0x01) : bytes1(0x00),
            0
        );
    }

    function _defaultData(uint256 amount1_, bool usePrev_, uint256 amount2_) internal view returns (bytes memory) {
        return _encode(
            loanToken,
            collateralToken,
            spoke,
            supplyReserveId,
            borrowReserveId,
            amount1_,
            usePrev_ ? bytes1(0x01) : bytes1(0x00),
            amount2_
        );
    }

    function _hooks() internal view returns (BaseLoanHookV2[3] memory hooks) {
        hooks[0] = BaseLoanHookV2(address(openHook));
        hooks[1] = BaseLoanHookV2(address(repayHook));
        hooks[2] = BaseLoanHookV2(address(closeHook));
    }

    function _truncate(bytes memory data, uint256 newLength) internal pure returns (bytes memory out) {
        out = new bytes(newLength);
        for (uint256 i = 0; i < newLength; i++) {
            out[i] = data[i];
        }
    }

    function _readUint256(bytes memory data, uint256 offset) internal pure returns (uint256 value) {
        assembly ("memory-safe") {
            value := mload(add(add(data, 0x20), offset))
        }
    }
}
