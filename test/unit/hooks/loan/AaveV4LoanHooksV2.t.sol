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

    function setUsingAsCollateral(uint256, bool, address) external { }
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
            assertTrue(hooks[i].supportsInterface(type(ISuperHookLoans).interfaceId));
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
        bytes memory data =
            _encode(loanToken, collateralToken, spoke, supplyReserveId, borrowReserveId, amount, bytes1(0x02), borrowAmount);

        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        openHook.build(address(0), address(this), data);

        bytes memory repayData =
            _encode(loanToken, collateralToken, spoke, supplyReserveId, borrowReserveId, amount, bytes1(0x02), 0);
        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        repayHook.build(address(0), address(this), repayData);
    }

    function test_Build_RevertIf_ZeroLoanToken() public {
        bytes memory data =
            _encode(address(0), collateralToken, spoke, supplyReserveId, borrowReserveId, amount, bytes1(0x00), borrowAmount);
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
        repayHook.build(address(0), address(this), _defaultData(amount, false, 0));
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

        Execution[] memory executions = repayHook.build(address(prevHook), address(this), _defaultData(MAX, true, 0));
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
        repayHook.build(address(0), address(this), _defaultData(0, false, 0));
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
        Execution[] memory executions = repayHook.build(address(0), address(this), _defaultData(amount, false, 0));
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

        Execution[] memory executions = repayHook.build(address(prevHook), address(this), _defaultData(amount, true, 0));
        assertEq(executions.length, 2);
    }

    function test_RepayHook_Build_PremiumOnlyDebt_DoesNotRevert() public {
        // drawn = 0 but premium > 0 → total debt = drawn + premium > 0
        mockSpoke.setUserDebt(borrowReserveId, address(this), 0, premiumDebt);
        Execution[] memory executions = repayHook.build(address(0), address(this), _defaultData(amount, false, 0));
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
        repayHook.build(address(0), address(this), _defaultData(amount, true, 0));
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
        repayHook.build(address(prevHook), address(this), _defaultData(amount, true, 0));
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
        repayHook.build(address(prevHook), address(this), _defaultData(amount, true, 0));
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

        Execution[] memory executions = repayHook.build(address(prevHook), address(this), _defaultData(amount, true, 0));

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
        Execution[] memory executions = openHook.build(address(0), address(this), _defaultData(amount, false, borrowAmount));

        // preExecute + approve(0) + approve(amount1) + supply + setUsingAsCollateral + borrow + approve(0) + postExecute
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
        Execution[] memory executions = repayHook.build(address(0), address(this), _defaultData(partialCap, false, 0));

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
        Execution[] memory executions = repayHook.build(address(0), address(this), _defaultData(MAX, false, 0));

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
        Execution[] memory executions = repayHook.build(address(0), address(this), _defaultData(debt, false, 0));
        assertEq(executions.length, 6);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (spoke, debt)));
        assertEq(executions[3].callData, abi.encodeCall(IAaveV4Spoke.repay, (borrowReserveId, MAX, address(this))));
    }

    function test_RepayHook_Build_CapAboveDebt_MinsWithDebt() public view {
        // cap > debt resolves to the debt; approval covers the debt, never the cap
        uint256 debt = drawnDebt + premiumDebt;
        Execution[] memory executions = repayHook.build(address(0), address(this), _defaultData(debt + 5e17, false, 0));
        assertEq(executions.length, 6);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (spoke, debt)));
        assertEq(executions[3].callData, abi.encodeCall(IAaveV4Spoke.repay, (borrowReserveId, MAX, address(this))));
    }

    function test_RepayHook_Build_CapBetweenDrawnAndTotal_ExactRepay() public view {
        // drawn < cap < drawn + premium: still a partial repay of the exact cap
        uint256 cap = drawnDebt + premiumDebt / 2;
        Execution[] memory executions = repayHook.build(address(0), address(this), _defaultData(cap, false, 0));
        assertEq(executions.length, 6);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (spoke, cap)));
        assertEq(executions[3].callData, abi.encodeCall(IAaveV4Spoke.repay, (borrowReserveId, cap, address(this))));
    }

    function test_RepayHook_Build_PrevCapAboveDebt_MinsWithDebt() public {
        // A PREV-fed cap larger than the debt caps instead of reverting; leftover stays in wallet
        uint256 debt = drawnDebt + premiumDebt;
        prevHook.setOutToken(loanToken);
        prevHook.setOutAmount(debt * 2);

        Execution[] memory executions = repayHook.build(address(prevHook), address(this), _defaultData(amount, true, 0));
        assertEq(executions.length, 6);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (spoke, debt)));
        assertEq(executions[3].callData, abi.encodeCall(IAaveV4Spoke.repay, (borrowReserveId, MAX, address(this))));
    }

    function test_RepayHook_SettleRoundTrip_ZeroDebt_Graceful() public {
        mockSpoke.setUserDebt(borrowReserveId, address(this), 0, 0);
        bytes memory data = _defaultData(amount, false, 0);
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
    ///      behavior: decodeAmounts reads a garbage overlap of the two reserve-id words, and
    ///      replaceCalldataAmounts leaves the real repay amount untouched while corrupting the
    ///      reserve ids. See the accompanying report — a src fix should override these at 176.
    function test_RepayHook_SizingInterface_SingleSlotAtOffset176() public {
        bytes memory data = _defaultData(amount, false, 0);

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

    function test_Inspect_Payload_AllHooks() public view {
        bytes memory expected =
            abi.encodePacked(spoke, loanToken, collateralToken, supplyReserveId, borrowReserveId);

        assertEq(openHook.inspect(_defaultData(amount, false, borrowAmount)), expected);
        assertEq(repayHook.inspect(_defaultData(amount, false, 0)), expected);
        assertEq(closeHook.inspect(_defaultData(amount, false, withdrawAmount)), expected);
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
            _encode(loanToken, collateralToken, other, supplyReserveId, borrowReserveId, amount, bytes1(0x00), borrowAmount)
        );
        assertTrue(keccak256(changed) != keccak256(base));

        // supply reserve id
        changed = openHook.inspect(
            _encode(loanToken, collateralToken, spoke, supplyReserveId + 10, borrowReserveId, amount, bytes1(0x00), borrowAmount)
        );
        assertTrue(keccak256(changed) != keccak256(base));

        // borrow reserve id
        changed = openHook.inspect(
            _encode(loanToken, collateralToken, spoke, supplyReserveId, borrowReserveId + 10, amount, bytes1(0x00), borrowAmount)
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
        bytes memory data = _defaultData(repayAmount, false, 0);
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
        bytes memory data = _defaultData(repayAmount, false, 0);
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
                         ENCODING HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Canonical 241-byte Aave V4 V2 layout:
    ///      bytes32 placeholder0 | address placeholder1 | loanToken | collateralToken | spoke |
    ///      supplyReserveId | borrowReserveId | amount1 | usePrevHookAmount (1 byte) | amount2
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
        return abi.encodePacked(
            bytes32(0),
            address(0),
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
