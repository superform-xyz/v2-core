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
import { IPool } from "../../../../src/vendor/aave-v3/IPool.sol";
import { BytesLib } from "../../../../src/vendor/BytesLib.sol";
import { DataTypes } from "../../../../src/vendor/aave-v3/DataTypes.sol";
import { HookSubTypes } from "../../../../src/libraries/HookSubTypes.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Hooks
import { BaseLoanHookV2 } from "../../../../src/hooks/loan/BaseLoanHookV2.sol";
import { BaseAaveV3LoanHookV2 } from "../../../../src/hooks/loan/aave-v3/BaseAaveV3LoanHookV2.sol";
import { AaveV3SupplyAndBorrowHookV2 } from "../../../../src/hooks/loan/aave-v3/AaveV3SupplyAndBorrowHookV2.sol";
import { AaveV3RepayHookV2 } from "../../../../src/hooks/loan/aave-v3/AaveV3RepayHookV2.sol";
import { AaveV3RepayAndWithdrawHookV2 } from "../../../../src/hooks/loan/aave-v3/AaveV3RepayAndWithdrawHookV2.sol";

/// @notice Minimal Aave V3 Pool mock: per-asset configurable aToken / variableDebtToken addresses.
///         Provider mutators are no-ops — build-shape tests never execute them.
contract MockAaveV3Pool {
    struct ReserveTokens {
        address aToken;
        address variableDebtToken;
    }

    mapping(address asset => ReserveTokens tokens) internal reserves;

    function setReserveTokens(address asset, address aToken, address variableDebtToken) external {
        reserves[asset] = ReserveTokens(aToken, variableDebtToken);
    }

    function getReserveData(address asset) external view returns (DataTypes.ReserveDataLegacy memory data) {
        data.aTokenAddress = reserves[asset].aToken;
        data.variableDebtTokenAddress = reserves[asset].variableDebtToken;
    }

    function supply(address, uint256, address, uint16) external { }

    function withdraw(address, uint256, address) external pure returns (uint256) {
        return 0;
    }

    function borrow(address, uint256, uint256, uint16, address) external { }

    function setUserUseReserveAsCollateral(address, bool) external { }

    function repay(address, uint256, uint256, address) external pure returns (uint256) {
        return 0;
    }
}

/// @notice Previous-hook mock with settable outAmount / outToken
contract MockPrevHook {
    uint256 public storedOutAmount;
    address public storedOutToken;

    function setOutAmount(uint256 amount_) external {
        storedOutAmount = amount_;
    }

    function setOutToken(address token_) external {
        storedOutToken = token_;
    }

    function getOutAmount(address) external view returns (uint256) {
        return storedOutAmount;
    }

    function getOutToken(address) external view returns (address) {
        return storedOutToken;
    }
}

contract AaveV3LoanHooksV2Test is Helpers {
    AaveV3SupplyAndBorrowHookV2 public openHook;
    AaveV3RepayHookV2 public repayHook;
    AaveV3RepayAndWithdrawHookV2 public closeHook;

    MockAaveV3Pool public mockPool;
    MockERC20 public mockLoanToken;
    MockERC20 public mockCollateralToken;
    MockERC20 public mockAToken;
    MockERC20 public mockVariableDebtToken;

    address public pool;
    address public loanToken;
    address public collateralToken;

    uint8 internal constant VARIABLE = 2;
    uint256 public amount1 = 1e18;
    uint256 public amount2 = 5e17;
    uint256 internal constant MAX = type(uint256).max;

    function setUp() public {
        mockPool = new MockAaveV3Pool();
        pool = address(mockPool);

        mockLoanToken = new MockERC20("Loan", "LOAN", 18);
        mockCollateralToken = new MockERC20("Coll", "COLL", 18);
        mockAToken = new MockERC20("aColl", "aCOLL", 18);
        mockVariableDebtToken = new MockERC20("vDebtLoan", "vLOAN", 18);
        loanToken = address(mockLoanToken);
        collateralToken = address(mockCollateralToken);

        mockPool.setReserveTokens(loanToken, address(0), address(mockVariableDebtToken));
        mockPool.setReserveTokens(collateralToken, address(mockAToken), address(0));

        openHook = new AaveV3SupplyAndBorrowHookV2();
        repayHook = new AaveV3RepayHookV2();
        closeHook = new AaveV3RepayAndWithdrawHookV2();
    }

    /*//////////////////////////////////////////////////////////////
                             ENCODERS
    //////////////////////////////////////////////////////////////*/
    /// @dev Canonical 178-byte Aave V3 V2 layout
    function _data(
        address lt,
        address ct,
        address p,
        uint8 rateMode,
        uint256 a1,
        uint256 a2,
        uint8 usePrevByte
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(bytes32(0), address(0), lt, ct, p, rateMode, a1, a2, usePrevByte);
    }

    function _open(uint256 a1, uint256 a2, bool usePrev) internal view returns (bytes memory) {
        return _data(loanToken, collateralToken, pool, VARIABLE, a1, a2, usePrev ? 1 : 0);
    }

    function _repay(uint256 a1, bool usePrev) internal view returns (bytes memory) {
        return _data(loanToken, collateralToken, pool, VARIABLE, a1, 0, usePrev ? 1 : 0);
    }

    function _close(uint256 a1, uint256 a2, bool usePrev) internal view returns (bytes memory) {
        return _data(loanToken, collateralToken, pool, VARIABLE, a1, a2, usePrev ? 1 : 0);
    }

    function _mintDebt(address account, uint256 debt) internal {
        mockVariableDebtToken.mint(account, debt);
    }

    /*//////////////////////////////////////////////////////////////
                           CONSTRUCTORS
    //////////////////////////////////////////////////////////////*/
    function test_Constructors() public view {
        assertEq(uint256(openHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(repayHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(closeHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));

        assertEq(openHook.subtype(), HookSubTypes.LOAN);
        assertEq(repayHook.subtype(), HookSubTypes.LOAN_REPAY);
        assertEq(closeHook.subtype(), HookSubTypes.LOAN_REPAY);
    }

    function test_SupportsInterface() public view {
        bytes4 loans = type(ISuperHookLoans).interfaceId;
        bytes4 inflowOutflow = type(ISuperHookInflowOutflow).interfaceId;
        bytes4 outflow = type(ISuperHookOutflow).interfaceId;

        assertTrue(openHook.supportsInterface(loans));
        assertTrue(openHook.supportsInterface(inflowOutflow));
        assertTrue(openHook.supportsInterface(outflow));

        assertTrue(repayHook.supportsInterface(loans));
        assertTrue(repayHook.supportsInterface(inflowOutflow));
        assertTrue(repayHook.supportsInterface(outflow));

        assertTrue(closeHook.supportsInterface(loans));
        assertTrue(closeHook.supportsInterface(inflowOutflow));
        assertTrue(closeHook.supportsInterface(outflow));
    }

    /*//////////////////////////////////////////////////////////////
                          STRICT DECODE
    //////////////////////////////////////////////////////////////*/
    function test_Build_RevertIf_InvalidDataLength() public {
        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        openHook.build(address(0), address(this), new bytes(177));
        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        openHook.build(address(0), address(this), new bytes(179));

        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        repayHook.build(address(0), address(this), new bytes(177));
        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        repayHook.build(address(0), address(this), new bytes(179));

        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        closeHook.build(address(0), address(this), new bytes(177));
        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        closeHook.build(address(0), address(this), new bytes(179));
    }

    function test_Build_RevertIf_InvalidBoolValue() public {
        bytes memory data = _data(loanToken, collateralToken, pool, VARIABLE, amount1, amount2, 2);
        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        openHook.build(address(0), address(this), data);
    }

    function test_Build_RevertIf_ZeroLoanToken() public {
        bytes memory data = _data(address(0), collateralToken, pool, VARIABLE, amount1, amount2, 0);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        openHook.build(address(0), address(this), data);
    }

    function test_Build_RevertIf_ZeroCollateralToken() public {
        bytes memory data = _data(loanToken, address(0), pool, VARIABLE, amount1, amount2, 0);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        openHook.build(address(0), address(this), data);
    }

    function test_Build_RevertIf_ZeroPool() public {
        bytes memory data = _data(loanToken, collateralToken, address(0), VARIABLE, amount1, amount2, 0);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        openHook.build(address(0), address(this), data);
    }

    function test_Build_RevertIf_IdenticalTokens() public {
        bytes memory data = _data(loanToken, loanToken, pool, VARIABLE, amount1, amount2, 0);
        vm.expectRevert(BaseLoanHookV2.IDENTICAL_TOKENS.selector);
        openHook.build(address(0), address(this), data);
    }

    function test_Build_RevertIf_InvalidRateMode() public {
        vm.expectRevert(BaseAaveV3LoanHookV2.INVALID_RATE_MODE.selector);
        openHook.build(address(0), address(this), _data(loanToken, collateralToken, pool, 1, amount1, amount2, 0));
        vm.expectRevert(BaseAaveV3LoanHookV2.INVALID_RATE_MODE.selector);
        openHook.build(address(0), address(this), _data(loanToken, collateralToken, pool, 0, amount1, amount2, 0));

        vm.expectRevert(BaseAaveV3LoanHookV2.INVALID_RATE_MODE.selector);
        repayHook.build(address(0), address(this), _data(loanToken, collateralToken, pool, 1, amount1, 0, 0));

        vm.expectRevert(BaseAaveV3LoanHookV2.INVALID_RATE_MODE.selector);
        closeHook.build(address(0), address(this), _data(loanToken, collateralToken, pool, 1, amount1, amount2, 0));
    }

    function test_Repay_Build_RevertIf_ReservedFieldNotZero() public {
        _mintDebt(address(this), 2e18);
        bytes memory data = _data(loanToken, collateralToken, pool, VARIABLE, amount1, amount2, 0);
        vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
        repayHook.build(address(0), address(this), data);
    }

    /*//////////////////////////////////////////////////////////////
                          AMOUNT VALIDATION
    //////////////////////////////////////////////////////////////*/
    function test_Open_Build_RevertIf_ZeroOrMaxAmounts() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(0), address(this), _open(0, amount2, false));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(0), address(this), _open(MAX, amount2, false));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(0), address(this), _open(amount1, 0, false));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(0), address(this), _open(amount1, MAX, false));
    }

    function test_Repay_Build_RevertIf_MaxWithPrev() public {
        _mintDebt(address(this), 2e18);
        vm.expectRevert(BaseLoanHookV2.MAX_WITH_PREV_NOT_ALLOWED.selector);
        repayHook.build(address(0), address(this), _repay(MAX, true));
    }

    function test_Repay_Build_RevertIf_ZeroAmount() public {
        _mintDebt(address(this), 2e18);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        repayHook.build(address(0), address(this), _repay(0, false));
    }

    function test_Close_Build_RevertIf_MaxWithPrev() public {
        _mintDebt(address(this), 2e18);
        vm.expectRevert(BaseLoanHookV2.MAX_WITH_PREV_NOT_ALLOWED.selector);
        closeHook.build(address(0), address(this), _close(MAX, amount2, true));
    }

    function test_Close_Build_RevertIf_ZeroRepayAmount() public {
        _mintDebt(address(this), 2e18);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        closeHook.build(address(0), address(this), _close(0, amount2, false));
    }

    function test_Close_Build_RevertIf_ZeroWithdrawAmount() public {
        _mintDebt(address(this), 2e18);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        closeHook.build(address(0), address(this), _close(amount1, 0, false));
    }

    function test_Close_Build_RevertIf_MaxWithdrawWithZeroATokenBalance() public {
        _mintDebt(address(this), 2e18);
        // no aTokens minted to the account → sentinel resolves against a zero balance
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        closeHook.build(address(0), address(this), _close(amount1, MAX, false));
    }

    /*//////////////////////////////////////////////////////////////
                             ZERO DEBT
    //////////////////////////////////////////////////////////////*/
    function test_Repay_Build_RevertIf_NoOutstandingDebt() public {
        vm.expectRevert(BaseLoanHookV2.NO_OUTSTANDING_DEBT.selector);
        repayHook.build(address(0), address(this), _repay(amount1, false));
    }

    function test_Close_Build_RevertIf_NoOutstandingDebt() public {
        vm.expectRevert(BaseLoanHookV2.NO_OUTSTANDING_DEBT.selector);
        closeHook.build(address(0), address(this), _close(amount1, amount2, false));
    }

    /*//////////////////////////////////////////////////////////////
                        PREVIOUS-HOOK PIPE
    //////////////////////////////////////////////////////////////*/
    function test_Open_Prev_RevertIf_ZeroPrevHook() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        openHook.build(address(0), address(this), _open(amount1, amount2, true));
    }

    function test_Open_Prev_RevertIf_TokenMismatch() public {
        MockPrevHook prev = new MockPrevHook();
        prev.setOutAmount(3e18);
        prev.setOutToken(loanToken); // open expects collateralToken
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        openHook.build(address(prev), address(this), _open(amount1, amount2, true));
    }

    function test_Open_Prev_RevertIf_ZeroAmount() public {
        MockPrevHook prev = new MockPrevHook();
        prev.setOutAmount(0);
        prev.setOutToken(collateralToken);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(prev), address(this), _open(amount1, amount2, true));
    }

    function test_Open_Prev_HappyPath() public {
        MockPrevHook prev = new MockPrevHook();
        uint256 prevAmount = 3e18;
        prev.setOutAmount(prevAmount);
        prev.setOutToken(collateralToken); // open pipes into the collateral leg

        Execution[] memory ex = openHook.build(address(prev), address(this), _open(amount1, amount2, true));
        assertEq(ex.length, 8);
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (pool, prevAmount)));
        assertEq(ex[3].callData, abi.encodeCall(IPool.supply, (collateralToken, prevAmount, address(this), 0)));
        assertEq(ex[4].callData, abi.encodeCall(IPool.setUserUseReserveAsCollateral, (collateralToken, true)));
        // borrow leg unaffected by the pipe
        assertEq(ex[5].callData, abi.encodeCall(IPool.borrow, (loanToken, amount2, 2, 0, address(this))));
    }

    function test_Repay_Prev_RevertIf_TokenMismatch() public {
        _mintDebt(address(this), 2e18);
        MockPrevHook prev = new MockPrevHook();
        prev.setOutAmount(3e17);
        prev.setOutToken(collateralToken); // repay expects loanToken
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        repayHook.build(address(prev), address(this), _repay(amount1, true));
    }

    function test_Repay_Prev_HappyPath() public {
        _mintDebt(address(this), 2e18);
        MockPrevHook prev = new MockPrevHook();
        uint256 prevAmount = 3e17;
        prev.setOutAmount(prevAmount);
        prev.setOutToken(loanToken); // repay/close pipe into the loan-token leg

        Execution[] memory ex = repayHook.build(address(prev), address(this), _repay(amount1, true));
        assertEq(ex.length, 6);
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (pool, prevAmount)));
        assertEq(ex[3].callData, abi.encodeCall(IPool.repay, (loanToken, prevAmount, 2, address(this))));
    }

    function test_Close_Prev_HappyPath() public {
        _mintDebt(address(this), 2e18);
        MockPrevHook prev = new MockPrevHook();
        uint256 prevAmount = 4e17;
        prev.setOutAmount(prevAmount);
        prev.setOutToken(loanToken);

        Execution[] memory ex = closeHook.build(address(prev), address(this), _close(amount1, amount2, true));
        assertEq(ex.length, 7);
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (pool, prevAmount)));
        assertEq(ex[3].callData, abi.encodeCall(IPool.repay, (loanToken, prevAmount, 2, address(this))));
    }

    /*//////////////////////////////////////////////////////////////
                        BUILD SHAPE HAPPY PATHS
    //////////////////////////////////////////////////////////////*/
    function test_Open_Build() public view {
        Execution[] memory ex = openHook.build(address(0), address(this), _open(amount1, amount2, false));
        // preExecute + approve0 + approve(amount1) + supply + setUseAsCollateral + borrow + approve0
        // + postExecute = 8
        assertEq(ex.length, 8, "open exec count");
        assertEq(ex[1].target, collateralToken);
        assertEq(ex[1].callData, abi.encodeCall(IERC20.approve, (pool, 0)));
        assertEq(ex[2].target, collateralToken);
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (pool, amount1)));
        assertEq(ex[3].target, pool);
        assertEq(ex[3].callData, abi.encodeCall(IPool.supply, (collateralToken, amount1, address(this), 0)));
        assertEq(ex[4].target, pool);
        assertEq(ex[4].callData, abi.encodeCall(IPool.setUserUseReserveAsCollateral, (collateralToken, true)));
        assertEq(ex[5].target, pool);
        assertEq(ex[5].callData, abi.encodeCall(IPool.borrow, (loanToken, amount2, 2, 0, address(this))));
        assertEq(ex[6].target, collateralToken);
        assertEq(ex[6].callData, abi.encodeCall(IERC20.approve, (pool, 0)));
    }

    function test_Repay_Build_Partial() public {
        _mintDebt(address(this), 2e18);
        Execution[] memory ex = repayHook.build(address(0), address(this), _repay(amount1, false));
        // preExecute + approve0 + approve(amount1) + repay + approve0 + postExecute = 6
        assertEq(ex.length, 6, "repay exec count");
        assertEq(ex[1].target, loanToken);
        assertEq(ex[1].callData, abi.encodeCall(IERC20.approve, (pool, 0)));
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (pool, amount1)));
        assertEq(ex[3].target, pool);
        assertEq(ex[3].callData, abi.encodeCall(IPool.repay, (loanToken, amount1, 2, address(this))));
        assertEq(ex[4].callData, abi.encodeCall(IERC20.approve, (pool, 0)));
    }

    function test_Repay_Build_FullRepayment() public {
        uint256 debt = 17e17;
        _mintDebt(address(this), debt);
        Execution[] memory ex = repayHook.build(address(0), address(this), _repay(MAX, false));
        assertEq(ex.length, 6);
        // approval equals current variable-debt balance, repay passes the sentinel through
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (pool, debt)));
        assertEq(ex[3].callData, abi.encodeCall(IPool.repay, (loanToken, MAX, 2, address(this))));
        assertEq(ex[4].callData, abi.encodeCall(IERC20.approve, (pool, 0)));
    }

    function test_Close_Build() public {
        _mintDebt(address(this), 2e18);
        Execution[] memory ex = closeHook.build(address(0), address(this), _close(amount1, amount2, false));
        // preExecute + approve0 + approve(repay) + repay + approve0 + withdraw + postExecute = 7
        assertEq(ex.length, 7, "close exec count");
        assertEq(ex[1].target, loanToken);
        assertEq(ex[1].callData, abi.encodeCall(IERC20.approve, (pool, 0)));
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (pool, amount1)));
        // repay strictly before withdraw
        assertEq(ex[3].target, pool);
        assertEq(ex[3].callData, abi.encodeCall(IPool.repay, (loanToken, amount1, 2, address(this))));
        assertEq(ex[4].callData, abi.encodeCall(IERC20.approve, (pool, 0)));
        assertEq(ex[5].target, pool);
        assertEq(ex[5].callData, abi.encodeCall(IPool.withdraw, (collateralToken, amount2, address(this))));
    }

    function test_Close_Build_MaxWithdraw() public {
        _mintDebt(address(this), 2e18);
        mockAToken.mint(address(this), 9e17); // nonzero aToken balance under the sentinel
        Execution[] memory ex = closeHook.build(address(0), address(this), _close(amount1, MAX, false));
        assertEq(ex.length, 7);
        // withdraw passes the sentinel through so Aave resolves it natively
        assertEq(ex[5].callData, abi.encodeCall(IPool.withdraw, (collateralToken, MAX, address(this))));
    }

    /*//////////////////////////////////////////////////////////////
                          SIZING INTERFACE
    //////////////////////////////////////////////////////////////*/
    function test_DecodeUsePrevHookAmount_ReadsByte177() public view {
        assertTrue(openHook.decodeUsePrevHookAmount(_open(amount1, amount2, true)));
        assertFalse(openHook.decodeUsePrevHookAmount(_open(amount1, amount2, false)));
        assertTrue(repayHook.decodeUsePrevHookAmount(_repay(amount1, true)));
        assertFalse(repayHook.decodeUsePrevHookAmount(_repay(amount1, false)));
        assertTrue(closeHook.decodeUsePrevHookAmount(_close(amount1, amount2, true)));
        assertFalse(closeHook.decodeUsePrevHookAmount(_close(amount1, amount2, false)));
    }

    function test_Sizing_TwoAmounts_DecodeRolesReplace() public view {
        bytes memory data = _open(amount1, amount2, true);

        uint256[] memory amts = openHook.decodeAmounts(data);
        assertEq(amts.length, 2);
        assertEq(amts[0], amount1);
        assertEq(amts[1], amount2);

        ISuperHookInflowOutflow.AmountMeta[] memory meta = openHook.amountRoles(data);
        assertEq(meta.length, 2);
        assertEq(uint256(meta[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(meta[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));
        assertEq(uint256(meta[1].dir), uint256(ISuperHookInflowOutflow.Direction.OUT));
        assertEq(uint256(meta[1].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));

        uint256[] memory repl = new uint256[](2);
        repl[0] = 111;
        repl[1] = 222;
        bytes memory out = openHook.replaceCalldataAmounts(data, repl);
        uint256[] memory back = openHook.decodeAmounts(out);
        assertEq(back[0], 111);
        assertEq(back[1], 222);
        assertTrue(openHook.decodeUsePrevHookAmount(out), "usePrev preserved");

        // close hook shares the same two-slot layout
        uint256[] memory closeAmts = closeHook.decodeAmounts(_close(amount1, amount2, false));
        assertEq(closeAmts.length, 2);
        assertEq(closeAmts[0], amount1);
        assertEq(closeAmts[1], amount2);
        ISuperHookInflowOutflow.AmountMeta[] memory closeMeta = closeHook.amountRoles(data);
        assertEq(closeMeta.length, 2);
    }

    function test_Sizing_TwoAmounts_RevertIf_WrongLength() public {
        bytes memory data = _open(amount1, amount2, false);
        uint256[] memory one = new uint256[](1);
        one[0] = 1;
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        openHook.replaceCalldataAmounts(data, one);
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        closeHook.replaceCalldataAmounts(data, one);
    }

    function test_Sizing_Repay_SingleSlot() public {
        bytes memory data = _repay(amount1, false);

        ISuperHookInflowOutflow.AmountMeta[] memory meta = repayHook.amountRoles(data);
        assertEq(meta.length, 1);
        assertEq(uint256(meta[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(meta[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));

        // decodeAmounts reads the actual repay amount at the Aave V3 V2 offset 113
        uint256[] memory amounts = repayHook.decodeAmounts(data);
        assertEq(amounts.length, 1);
        assertEq(amounts[0], amount1);

        // exactly one amount accepted; two reverts
        uint256[] memory two = new uint256[](2);
        two[0] = 1;
        two[1] = 2;
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        repayHook.replaceCalldataAmounts(data, two);

        // replace writes at offset 113 and round-trips through decodeAmounts
        uint256[] memory one = new uint256[](1);
        one[0] = 123;
        bytes memory replaced = repayHook.replaceCalldataAmounts(data, one);
        assertEq(repayHook.decodeAmounts(replaced)[0], 123);
        assertEq(BytesLib.toUint256(replaced, 145), 0); // reserved secondary untouched
    }

    /*//////////////////////////////////////////////////////////////
                              INSPECT
    //////////////////////////////////////////////////////////////*/
    function test_Inspect() public view {
        bytes memory expected = abi.encodePacked(pool, loanToken, collateralToken, VARIABLE);
        assertEq(openHook.inspect(_open(amount1, amount2, false)), expected);
        assertEq(repayHook.inspect(_repay(amount1, false)), expected);
        assertEq(closeHook.inspect(_close(amount1, amount2, false)), expected);
    }

    function test_Inspect_UnchangedWhenOnlyAmountsChange() public view {
        assertEq(
            openHook.inspect(_open(amount1, amount2, false)),
            openHook.inspect(_open(7e18, 9e18, true))
        );
    }

    function test_Inspect_ChangesWithIdentityFields() public {
        bytes memory base = openHook.inspect(_open(amount1, amount2, false));

        address otherPool = makeAddr("otherPool");
        address otherLoan = makeAddr("otherLoan");
        address otherColl = makeAddr("otherColl");

        bytes memory poolChanged =
            openHook.inspect(_data(loanToken, collateralToken, otherPool, VARIABLE, amount1, amount2, 0));
        bytes memory loanChanged =
            openHook.inspect(_data(otherLoan, collateralToken, pool, VARIABLE, amount1, amount2, 0));
        bytes memory collChanged =
            openHook.inspect(_data(loanToken, otherColl, pool, VARIABLE, amount1, amount2, 0));

        assertTrue(keccak256(base) != keccak256(poolChanged), "pool change");
        assertTrue(keccak256(base) != keccak256(loanChanged), "loan token change");
        assertTrue(keccak256(base) != keccak256(collChanged), "collateral token change");
    }

    /*//////////////////////////////////////////////////////////////
                          SETTLE ROUND-TRIPS
    //////////////////////////////////////////////////////////////*/
    function test_Open_Settle() public {
        bytes memory data = _open(amount1, amount2, false);
        mockCollateralToken.mint(address(this), amount1);

        openHook.preExecute(address(0), address(this), data);

        // simulate: supply consumed the collateral, borrow delivered the loan tokens
        mockCollateralToken.burn(address(this), amount1);
        mockLoanToken.mint(address(this), amount2);

        openHook.postExecute(address(0), address(this), data);
        assertEq(openHook.getOutAmount(address(this)), amount2, "borrowed loan delta");
        assertEq(openHook.getOutToken(address(this)), loanToken, "outToken = loanToken");
    }

    function test_Open_Settle_RevertIf_DeltaMismatch() public {
        bytes memory data = _open(amount1, amount2, false);
        mockCollateralToken.mint(address(this), amount1);

        openHook.preExecute(address(0), address(this), data);

        // collateral spent one wei short of the expected primary amount
        mockCollateralToken.burn(address(this), amount1 - 1);
        mockLoanToken.mint(address(this), amount2);

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, amount1, amount1 - 1));
        openHook.postExecute(address(0), address(this), data);
    }

    function test_Repay_Settle() public {
        _mintDebt(address(this), 2e18); // preExecute requires nonzero outstanding debt
        bytes memory data = _repay(amount1, false);
        mockLoanToken.mint(address(this), amount1);

        repayHook.preExecute(address(0), address(this), data);

        // simulate: repay consumed exactly the loan tokens
        mockLoanToken.burn(address(this), amount1);

        repayHook.postExecute(address(0), address(this), data);
        // Terminal repay hook publishes outAmount = 0 (spend is not a product); outToken kept
        assertEq(repayHook.getOutAmount(address(this)), 0, "terminal repay: no product");
        assertEq(repayHook.getOutToken(address(this)), loanToken, "outToken = loanToken");
    }

    function test_Repay_Settle_RevertIf_DeltaMismatch() public {
        _mintDebt(address(this), 2e18);
        bytes memory data = _repay(amount1, false);
        mockLoanToken.mint(address(this), amount1);

        repayHook.preExecute(address(0), address(this), data);

        mockLoanToken.burn(address(this), amount1 - 5);

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, amount1, amount1 - 5));
        repayHook.postExecute(address(0), address(this), data);
    }

    function test_Close_Settle() public {
        _mintDebt(address(this), 2e18);
        bytes memory data = _close(amount1, amount2, false);
        mockLoanToken.mint(address(this), amount1);

        closeHook.preExecute(address(0), address(this), data);

        // simulate: repay consumed the loan tokens, withdraw released the collateral
        mockLoanToken.burn(address(this), amount1);
        mockCollateralToken.mint(address(this), amount2);

        closeHook.postExecute(address(0), address(this), data);
        assertEq(closeHook.getOutAmount(address(this)), amount2, "collateral received");
        assertEq(closeHook.getOutToken(address(this)), collateralToken, "outToken = collateralToken");
    }

    function test_Close_Settle_RevertIf_DeltaMismatch() public {
        _mintDebt(address(this), 2e18);
        bytes memory data = _close(amount1, amount2, false);
        mockLoanToken.mint(address(this), amount1);

        closeHook.preExecute(address(0), address(this), data);

        mockLoanToken.burn(address(this), amount1);
        mockCollateralToken.mint(address(this), amount2 + 3); // received more collateral than expected

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, amount2, amount2 + 3));
        closeHook.postExecute(address(0), address(this), data);
    }
}
