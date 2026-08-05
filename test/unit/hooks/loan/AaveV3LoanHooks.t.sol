// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { Helpers } from "../../../utils/Helpers.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ISuperHook } from "../../../../src/interfaces/ISuperHook.sol";
import { IPool } from "../../../../src/vendor/aave-v3/IPool.sol";
import { HookSubTypes } from "../../../../src/libraries/HookSubTypes.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Hooks
import { BaseAaveV3LoanHook } from "../../../../src/hooks/loan/aave-v3/BaseAaveV3LoanHook.sol";
import { AaveV3SupplyHook } from "../../../../src/hooks/loan/aave-v3/AaveV3SupplyHook.sol";
import { AaveV3WithdrawHook } from "../../../../src/hooks/loan/aave-v3/AaveV3WithdrawHook.sol";
import { AaveV3BorrowHook } from "../../../../src/hooks/loan/aave-v3/AaveV3BorrowHook.sol";
import { AaveV3RepayHook } from "../../../../src/hooks/loan/aave-v3/AaveV3RepayHook.sol";
import { AaveV3SupplyAndBorrowHook } from "../../../../src/hooks/loan/aave-v3/AaveV3SupplyAndBorrowHook.sol";
import { AaveV3RepayAndWithdrawHook } from "../../../../src/hooks/loan/aave-v3/AaveV3RepayAndWithdrawHook.sol";
import { AaveV3RepayWithATokensHook } from "../../../../src/hooks/loan/aave-v3/AaveV3RepayWithATokensHook.sol";

contract MockHookForPrevAmount {
    ISuperHook.HookType public hookType;
    uint256 public storedOutAmount;

    constructor(ISuperHook.HookType _hookType) {
        hookType = _hookType;
    }

    function setOutAmount(uint256 _outAmount, address) external {
        storedOutAmount = _outAmount;
    }

    function getOutAmount(address) external view returns (uint256) {
        return storedOutAmount;
    }
}

contract AaveV3LoanHooksTest is Helpers {
    AaveV3SupplyHook public supplyHook;
    AaveV3WithdrawHook public withdrawHook;
    AaveV3BorrowHook public borrowHook;
    AaveV3RepayHook public repayHook;
    AaveV3SupplyAndBorrowHook public supplyAndBorrowHook;
    AaveV3RepayAndWithdrawHook public repayAndWithdrawHook;
    AaveV3RepayWithATokensHook public repayWithATokensHook;

    address public pool = makeAddr("aaveV3Pool");
    MockERC20 public mockLoanToken;
    MockERC20 public mockCollateralToken;
    address public loanToken;
    address public collateralToken;

    uint8 internal constant VARIABLE = 2;
    uint256 public amount = 1e18;
    uint256 public borrowAmount = 5e17;
    uint256 public withdrawAmount = 8e17;

    // bytes4(keccak256("setUserUseReserveAsCollateral(address,bool)"))
    bytes4 internal constant SET_COLLATERAL_SELECTOR = 0x5a3b74b9;

    function setUp() public {
        mockLoanToken = new MockERC20("Loan", "LOAN", 18);
        mockCollateralToken = new MockERC20("Coll", "COLL", 18);
        loanToken = address(mockLoanToken);
        collateralToken = address(mockCollateralToken);

        supplyHook = new AaveV3SupplyHook();
        withdrawHook = new AaveV3WithdrawHook();
        borrowHook = new AaveV3BorrowHook();
        repayHook = new AaveV3RepayHook();
        supplyAndBorrowHook = new AaveV3SupplyAndBorrowHook();
        repayAndWithdrawHook = new AaveV3RepayAndWithdrawHook();
        repayWithATokensHook = new AaveV3RepayWithATokensHook();
    }

    /*//////////////////////////////////////////////////////////////
                             ENCODERS
    //////////////////////////////////////////////////////////////*/
    function _hdr() internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(0), bytes20(0)); // 52-byte header
    }

    function _sw(uint256 amt, bool usePrev) internal view returns (bytes memory) {
        return abi.encodePacked(_hdr(), loanToken, collateralToken, pool, amt, usePrev);
    }

    function _br(uint8 mode, uint256 amt, bool usePrev) internal view returns (bytes memory) {
        return abi.encodePacked(_hdr(), loanToken, collateralToken, pool, mode, amt, usePrev);
    }

    function _cb(uint8 mode, uint256 a1, uint256 a2, bool usePrev) internal view returns (bytes memory) {
        return abi.encodePacked(_hdr(), loanToken, collateralToken, pool, mode, a1, a2, usePrev);
    }

    /*//////////////////////////////////////////////////////////////
                           CONSTRUCTORS
    //////////////////////////////////////////////////////////////*/
    function test_Constructors() public view {
        assertEq(uint256(supplyHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(withdrawHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(borrowHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(repayHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(supplyAndBorrowHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(repayAndWithdrawHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(repayWithATokensHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));

        assertEq(supplyHook.subtype(), HookSubTypes.LOAN);
        assertEq(borrowHook.subtype(), HookSubTypes.LOAN);
        assertEq(supplyAndBorrowHook.subtype(), HookSubTypes.LOAN);
        assertEq(withdrawHook.subtype(), HookSubTypes.LOAN_REPAY);
        assertEq(repayHook.subtype(), HookSubTypes.LOAN_REPAY);
        assertEq(repayAndWithdrawHook.subtype(), HookSubTypes.LOAN_REPAY);
        assertEq(repayWithATokensHook.subtype(), HookSubTypes.LOAN_REPAY);
    }

    /*//////////////////////////////////////////////////////////////
                              SUPPLY
    //////////////////////////////////////////////////////////////*/
    function test_Supply_Build_NoCollateralToggle() public view {
        Execution[] memory ex = supplyHook.build(address(0), address(this), _sw(amount, false));
        // preExecute + approve0 + approve(amount) + supply + approve0 + postExecute = 6
        assertEq(ex.length, 6, "supply exec count");
        assertEq(ex[1].callData, abi.encodeCall(IERC20.approve, (pool, 0)));
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (pool, amount)));
        assertEq(ex[3].target, pool);
        assertEq(ex[3].callData, abi.encodeCall(IPool.supply, (collateralToken, amount, address(this), 0)));
        assertEq(ex[4].callData, abi.encodeCall(IERC20.approve, (pool, 0)));
        // gap #1 regression: no setUserUseReserveAsCollateral anywhere
        for (uint256 i; i < ex.length; ++i) {
            assertTrue(bytes4(ex[i].callData) != SET_COLLATERAL_SELECTOR, "no collateral toggle");
        }
        assertEq(supplyHook.inspect(_sw(amount, false)), abi.encodePacked(pool));
    }

    function test_Supply_UsePrevHookAmount() public {
        MockHookForPrevAmount prev = new MockHookForPrevAmount(ISuperHook.HookType.NONACCOUNTING);
        prev.setOutAmount(3e18, address(this));
        Execution[] memory ex = supplyHook.build(address(prev), address(this), _sw(amount, true));
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (pool, 3e18)));
        assertEq(ex[3].callData, abi.encodeCall(IPool.supply, (collateralToken, 3e18, address(this), 0)));
    }

    function test_Supply_RevertZeroAmount() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        supplyHook.build(address(0), address(this), _sw(0, false));
    }

    function test_Supply_RevertShortData() public {
        vm.expectRevert(BaseAaveV3LoanHook.INVALID_DATA_LENGTH.selector);
        supplyHook.build(address(0), address(this), new bytes(144));
    }

    function test_Supply_RevertZeroPool() public {
        bytes memory data = abi.encodePacked(_hdr(), loanToken, collateralToken, address(0), amount, false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        supplyHook.build(address(0), address(this), data);
    }

    /*//////////////////////////////////////////////////////////////
                          WITHDRAW / BORROW
    //////////////////////////////////////////////////////////////*/
    function test_Withdraw_Build_MaxAllowed() public view {
        Execution[] memory ex = withdrawHook.build(address(0), address(this), _sw(type(uint256).max, false));
        assertEq(ex.length, 3); // pre + withdraw + post
        assertEq(ex[1].target, pool);
        assertEq(ex[1].callData, abi.encodeCall(IPool.withdraw, (collateralToken, type(uint256).max, address(this))));
    }

    function test_Borrow_Build() public view {
        Execution[] memory ex = borrowHook.build(address(0), address(this), _br(VARIABLE, amount, false));
        assertEq(ex.length, 3);
        assertEq(ex[1].target, pool);
        assertEq(ex[1].callData, abi.encodeCall(IPool.borrow, (loanToken, amount, 2, 0, address(this))));
    }

    function test_Borrow_RevertInvalidRateMode() public {
        vm.expectRevert(BaseAaveV3LoanHook.INVALID_RATE_MODE.selector);
        borrowHook.build(address(0), address(this), _br(1, amount, false));
        vm.expectRevert(BaseAaveV3LoanHook.INVALID_RATE_MODE.selector);
        borrowHook.build(address(0), address(this), _br(0, amount, false));
    }

    /*//////////////////////////////////////////////////////////////
                               REPAY
    //////////////////////////////////////////////////////////////*/
    function test_Repay_Build_Full() public view {
        Execution[] memory ex = repayHook.build(address(0), address(this), _br(VARIABLE, type(uint256).max, false));
        // pre + approve0 + approve(max) + repay + approve0 + post = 6
        assertEq(ex.length, 6);
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (pool, type(uint256).max)));
        assertEq(ex[3].callData, abi.encodeCall(IPool.repay, (loanToken, type(uint256).max, 2, address(this))));
        assertEq(ex[4].callData, abi.encodeCall(IERC20.approve, (pool, 0))); // reset even after repay(max)
    }

    function test_Repay_RevertInvalidRateMode() public {
        vm.expectRevert(BaseAaveV3LoanHook.INVALID_RATE_MODE.selector);
        repayHook.build(address(0), address(this), _br(1, amount, false));
    }

    /*//////////////////////////////////////////////////////////////
                          REPAY WITH ATOKENS
    //////////////////////////////////////////////////////////////*/
    function test_RepayWithATokens_Build_NoApproval() public view {
        Execution[] memory ex = repayWithATokensHook.build(address(0), address(this), _br(VARIABLE, amount, false));
        // pre + repayWithATokens + post = 3 (NO approvals)
        assertEq(ex.length, 3);
        assertEq(ex[1].target, pool);
        assertEq(ex[1].callData, abi.encodeCall(IPool.repayWithATokens, (loanToken, amount, 2)));
    }

    function test_RepayWithATokens_RevertInvalidRateMode() public {
        vm.expectRevert(BaseAaveV3LoanHook.INVALID_RATE_MODE.selector);
        repayWithATokensHook.build(address(0), address(this), _br(3, amount, false));
    }

    /*//////////////////////////////////////////////////////////////
                            COMBINED
    //////////////////////////////////////////////////////////////*/
    function test_SupplyAndBorrow_Build() public view {
        Execution[] memory ex =
            supplyAndBorrowHook.build(address(0), address(this), _cb(VARIABLE, amount, borrowAmount, false));
        // pre + approve0 + approve(supply) + supply + borrow + approve0 + post = 7
        assertEq(ex.length, 7);
        assertEq(ex[3].callData, abi.encodeCall(IPool.supply, (collateralToken, amount, address(this), 0)));
        assertEq(ex[4].callData, abi.encodeCall(IPool.borrow, (loanToken, borrowAmount, 2, 0, address(this))));
    }

    function test_SupplyAndBorrow_RevertZeroBorrow() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        supplyAndBorrowHook.build(address(0), address(this), _cb(VARIABLE, amount, 0, false));
    }

    function test_RepayAndWithdraw_Build() public view {
        Execution[] memory ex =
            repayAndWithdrawHook.build(address(0), address(this), _cb(VARIABLE, amount, withdrawAmount, false));
        // pre + approve0 + approve(repay) + repay + approve0 + withdraw + post = 7
        assertEq(ex.length, 7);
        assertEq(ex[3].callData, abi.encodeCall(IPool.repay, (loanToken, amount, 2, address(this))));
        assertEq(ex[5].callData, abi.encodeCall(IPool.withdraw, (collateralToken, withdrawAmount, address(this))));
    }

    /*//////////////////////////////////////////////////////////////
                         SIZING INTERFACE
    //////////////////////////////////////////////////////////////*/
    function test_Sizing_SingleAmount_Offsets() public view {
        // Supply/Withdraw amount@112, usePrev@144
        assertEq(supplyHook.decodeAmounts(_sw(amount, true))[0], amount);
        assertTrue(supplyHook.decodeUsePrevHookAmount(_sw(amount, true)));
        // Borrow/Repay amount@113, usePrev@145
        assertEq(borrowHook.decodeAmounts(_br(VARIABLE, amount, true))[0], amount);
        assertTrue(borrowHook.decodeUsePrevHookAmount(_br(VARIABLE, amount, true)));
        assertEq(repayWithATokensHook.decodeAmounts(_br(VARIABLE, amount, false))[0], amount);
    }

    function test_Sizing_Combined_TwoAmounts() public view {
        bytes memory data = _cb(VARIABLE, amount, borrowAmount, true);
        uint256[] memory amts = supplyAndBorrowHook.decodeAmounts(data);
        assertEq(amts.length, 2);
        assertEq(amts[0], amount);
        assertEq(amts[1], borrowAmount);
        assertTrue(supplyAndBorrowHook.decodeUsePrevHookAmount(data)); // usePrev@177

        uint256[] memory repl = new uint256[](2);
        repl[0] = 111;
        repl[1] = 222;
        bytes memory out = supplyAndBorrowHook.replaceCalldataAmounts(data, repl);
        uint256[] memory back = supplyAndBorrowHook.decodeAmounts(out);
        assertEq(back[0], 111);
        assertEq(back[1], 222);
    }

    function test_Sizing_ReplaceSingle_RoundTrip() public view {
        bytes memory data = _br(VARIABLE, amount, false);
        uint256[] memory repl = new uint256[](1);
        repl[0] = 999;
        bytes memory out = borrowHook.replaceCalldataAmounts(data, repl);
        assertEq(borrowHook.decodeAmounts(out)[0], 999);
    }
}
