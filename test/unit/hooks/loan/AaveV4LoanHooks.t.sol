// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { Helpers } from "../../../utils/Helpers.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ISuperHook } from "../../../../src/interfaces/ISuperHook.sol";
import { IAaveV4Spoke } from "../../../../src/vendor/aave-v4/IAaveV4Spoke.sol";
import { HookSubTypes } from "../../../../src/libraries/HookSubTypes.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Hooks
import { BaseAaveV4LoanHook } from "../../../../src/hooks/loan/aave-v4/BaseAaveV4LoanHook.sol";
import { AaveV4SupplyHook } from "../../../../src/hooks/loan/aave-v4/AaveV4SupplyHook.sol";
import { AaveV4WithdrawHook } from "../../../../src/hooks/loan/aave-v4/AaveV4WithdrawHook.sol";
import { AaveV4BorrowHook } from "../../../../src/hooks/loan/aave-v4/AaveV4BorrowHook.sol";
import { AaveV4RepayHook } from "../../../../src/hooks/loan/aave-v4/AaveV4RepayHook.sol";
import { AaveV4SupplyAndBorrowHook } from "../../../../src/hooks/loan/aave-v4/AaveV4SupplyAndBorrowHook.sol";
import { AaveV4RepayAndWithdrawHook } from "../../../../src/hooks/loan/aave-v4/AaveV4RepayAndWithdrawHook.sol";

contract MockAaveV4Spoke {
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

contract AaveV4LoanHooksTest is Helpers {
    // Hooks
    AaveV4SupplyHook public supplyHook;
    AaveV4WithdrawHook public withdrawHook;
    AaveV4BorrowHook public borrowHook;
    AaveV4RepayHook public repayHook;
    AaveV4SupplyAndBorrowHook public supplyAndBorrowHook;
    AaveV4RepayAndWithdrawHook public repayAndWithdrawHook;

    // Mocks
    MockAaveV4Spoke public mockSpoke;
    MockERC20 public mockLoanToken;
    MockERC20 public mockCollateralToken;

    // Test params
    address public spoke;
    address public loanToken;
    address public collateralToken;
    uint256 public supplyReserveId = 1;
    uint256 public borrowReserveId = 2;
    uint256 public amount = 1e18;
    uint256 public borrowAmount = 5e17;
    uint256 public withdrawAmount = 8e17;

    function setUp() public {
        mockSpoke = new MockAaveV4Spoke();
        spoke = address(mockSpoke);

        mockLoanToken = new MockERC20("Loan Token", "LOAN", 18);
        loanToken = address(mockLoanToken);

        mockCollateralToken = new MockERC20("Collateral Token", "COLL", 18);
        collateralToken = address(mockCollateralToken);

        supplyHook = new AaveV4SupplyHook();
        withdrawHook = new AaveV4WithdrawHook();
        borrowHook = new AaveV4BorrowHook();
        repayHook = new AaveV4RepayHook();
        supplyAndBorrowHook = new AaveV4SupplyAndBorrowHook();
        repayAndWithdrawHook = new AaveV4RepayAndWithdrawHook();
    }

    /*//////////////////////////////////////////////////////////////
                           CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Constructors() public view {
        assertEq(uint256(supplyHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(withdrawHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(borrowHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(repayHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(supplyAndBorrowHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(repayAndWithdrawHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    /*//////////////////////////////////////////////////////////////
                         SUPPLY HOOK TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SupplyHook_Build() public view {
        bytes memory data = _encodeSupplyData(false);
        Execution[] memory executions = supplyHook.build(address(0), address(this), data);

        // preExecute + approve(0) + approve(amount) + supply + setUsingAsCollateral + approve(0) + postExecute
        assertEq(executions.length, 7);
        // approve(0)
        assertEq(executions[1].target, collateralToken);
        // approve(amount)
        assertEq(executions[2].target, collateralToken);
        // supply call targets spoke
        assertEq(executions[3].target, spoke);
        // setUsingAsCollateral targets spoke
        assertEq(executions[4].target, spoke);
        // approve(0) cleanup
        assertEq(executions[5].target, collateralToken);
    }

    function test_SupplyHook_BuildWithPrevHook() public {
        MockHookForPrevAmount mockPrevHook = new MockHookForPrevAmount(ISuperHook.HookType.NONACCOUNTING);
        uint256 prevAmount = 2e18;
        mockPrevHook.setOutAmount(prevAmount, address(this));

        bytes memory data = _encodeSupplyData(true);
        Execution[] memory executions = supplyHook.build(address(mockPrevHook), address(this), data);

        assertEq(executions.length, 7);
        // Verify supply calldata uses prevAmount
        bytes memory expectedCalldata = abi.encodeCall(IAaveV4Spoke.supply, (supplyReserveId, prevAmount, address(this)));
        assertEq(executions[3].callData, expectedCalldata);
    }

    function test_SupplyHook_Build_RevertIf_ZeroAmount() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, collateralToken, spoke, supplyReserveId, borrowReserveId, uint256(0), false
        );
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        supplyHook.build(address(0), address(this), data);
    }

    function test_SupplyHook_Build_RevertIf_ZeroSpoke() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, collateralToken, address(0), supplyReserveId, borrowReserveId, amount, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        supplyHook.build(address(0), address(this), data);
    }

    function test_SupplyHook_Build_RevertIf_ZeroLoanToken() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), address(0), collateralToken, spoke, supplyReserveId, borrowReserveId, amount, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        supplyHook.build(address(0), address(this), data);
    }

    function test_SupplyHook_Build_RevertIf_ZeroCollateralToken() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, address(0), spoke, supplyReserveId, borrowReserveId, amount, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        supplyHook.build(address(0), address(this), data);
    }

    function test_SupplyHook_Build_RevertIf_InvalidDataLength() public {
        bytes memory shortData = abi.encodePacked(loanToken, collateralToken);
        vm.expectRevert(BaseAaveV4LoanHook.INVALID_DATA_LENGTH.selector);
        supplyHook.build(address(0), address(this), shortData);
    }

    function test_SupplyHook_Inspect() public view {
        bytes memory data = _encodeSupplyData(false);
        bytes memory result = supplyHook.inspect(data);
        assertEq(result, abi.encodePacked(spoke));
    }

    function test_SupplyHook_Inspect_RevertIf_ZeroAddress() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), address(0), collateralToken, spoke, supplyReserveId, borrowReserveId, amount, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        supplyHook.inspect(data);
    }

    function test_SupplyHook_PrePostExecute() public {
        bytes memory data = _encodeSupplyData(false);
        deal(collateralToken, address(this), amount);

        supplyHook.preExecute(address(0), address(this), data);
        assertEq(supplyHook.getOutAmount(address(this)), amount);

        // post with same balance => outAmount = amount - amount = 0
        supplyHook.postExecute(address(0), address(this), data);
        assertEq(supplyHook.getOutAmount(address(this)), 0);
    }

    function test_SupplyHook_DecodeUsePrevHookAmount() public view {
        bytes memory dataFalse = _encodeSupplyData(false);
        assertEq(supplyHook.decodeUsePrevHookAmount(dataFalse), false);

        bytes memory dataTrue = _encodeSupplyData(true);
        assertEq(supplyHook.decodeUsePrevHookAmount(dataTrue), true);
    }

    function test_SupplyHook_GetLoanTokenAddress() public view {
        bytes memory data = _encodeSupplyData(false);
        assertEq(supplyHook.getLoanTokenAddress(data), loanToken);
    }

    function test_SupplyHook_GetCollateralTokenAddress() public view {
        bytes memory data = _encodeSupplyData(false);
        assertEq(supplyHook.getCollateralTokenAddress(data), collateralToken);
    }

    function test_SupplyHook_GetCollateralTokenBalance() public {
        bytes memory data = _encodeSupplyData(false);
        deal(collateralToken, address(this), 5e18);
        assertEq(supplyHook.getCollateralTokenBalance(address(this), data), 5e18);
    }

    function test_SupplyHook_GetLoanTokenBalance() public {
        bytes memory data = _encodeSupplyData(false);
        deal(loanToken, address(this), 3e18);
        assertEq(supplyHook.getLoanTokenBalance(address(this), data), 3e18);
    }

    /*//////////////////////////////////////////////////////////////
                         WITHDRAW HOOK TESTS
    //////////////////////////////////////////////////////////////*/

    function test_WithdrawHook_Build() public view {
        bytes memory data = _encodeWithdrawData(false);
        Execution[] memory executions = withdrawHook.build(address(0), address(this), data);

        assertEq(executions.length, 3); // preExecute + withdraw + postExecute
        assertEq(executions[1].target, spoke);
    }

    function test_WithdrawHook_BuildWithPrevHook() public {
        MockHookForPrevAmount mockPrevHook = new MockHookForPrevAmount(ISuperHook.HookType.NONACCOUNTING);
        uint256 prevAmount = 3e18;
        mockPrevHook.setOutAmount(prevAmount, address(this));

        bytes memory data = _encodeWithdrawData(true);
        Execution[] memory executions = withdrawHook.build(address(mockPrevHook), address(this), data);

        assertEq(executions.length, 3);
        bytes memory expectedCalldata =
            abi.encodeCall(IAaveV4Spoke.withdraw, (supplyReserveId, prevAmount, address(this)));
        assertEq(executions[1].callData, expectedCalldata);
    }

    function test_WithdrawHook_Build_RevertIf_ZeroAmount() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, collateralToken, spoke, supplyReserveId, borrowReserveId, uint256(0), false
        );
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        withdrawHook.build(address(0), address(this), data);
    }

    function test_WithdrawHook_Build_RevertIf_ZeroSpoke() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, collateralToken, address(0), supplyReserveId, borrowReserveId, amount, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        withdrawHook.build(address(0), address(this), data);
    }

    function test_WithdrawHook_Build_RevertIf_InvalidDataLength() public {
        bytes memory shortData = abi.encodePacked(loanToken, collateralToken);
        vm.expectRevert(BaseAaveV4LoanHook.INVALID_DATA_LENGTH.selector);
        withdrawHook.build(address(0), address(this), shortData);
    }

    function test_WithdrawHook_Inspect() public view {
        bytes memory data = _encodeWithdrawData(false);
        bytes memory result = withdrawHook.inspect(data);
        assertEq(result, abi.encodePacked(spoke));
    }

    function test_WithdrawHook_Inspect_RevertIf_ZeroAddress() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), address(0), collateralToken, spoke, supplyReserveId, borrowReserveId, amount, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        withdrawHook.inspect(data);
    }

    function test_WithdrawHook_PrePostExecute() public {
        bytes memory data = _encodeWithdrawData(false);

        withdrawHook.preExecute(address(0), address(this), data);
        assertEq(withdrawHook.getOutAmount(address(this)), 0);

        // Simulate receiving collateral
        deal(collateralToken, address(this), amount);
        withdrawHook.postExecute(address(0), address(this), data);
        assertEq(withdrawHook.getOutAmount(address(this)), amount);
    }

    function test_WithdrawHook_DecodeUsePrevHookAmount() public view {
        bytes memory dataFalse = _encodeWithdrawData(false);
        assertEq(withdrawHook.decodeUsePrevHookAmount(dataFalse), false);

        bytes memory dataTrue = _encodeWithdrawData(true);
        assertEq(withdrawHook.decodeUsePrevHookAmount(dataTrue), true);
    }

    /*//////////////////////////////////////////////////////////////
                         BORROW HOOK TESTS
    //////////////////////////////////////////////////////////////*/

    function test_BorrowHook_Build() public view {
        bytes memory data = _encodeBorrowData(false);
        Execution[] memory executions = borrowHook.build(address(0), address(this), data);

        assertEq(executions.length, 3); // preExecute + borrow + postExecute
        assertEq(executions[1].target, spoke);
    }

    function test_BorrowHook_BuildWithPrevHook() public {
        MockHookForPrevAmount mockPrevHook = new MockHookForPrevAmount(ISuperHook.HookType.NONACCOUNTING);
        uint256 prevAmount = 4e18;
        mockPrevHook.setOutAmount(prevAmount, address(this));

        bytes memory data = _encodeBorrowData(true);
        Execution[] memory executions = borrowHook.build(address(mockPrevHook), address(this), data);

        assertEq(executions.length, 3);
        bytes memory expectedCalldata =
            abi.encodeCall(IAaveV4Spoke.borrow, (borrowReserveId, prevAmount, address(this)));
        assertEq(executions[1].callData, expectedCalldata);
    }

    function test_BorrowHook_Build_RevertIf_ZeroAmount() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, collateralToken, spoke, supplyReserveId, borrowReserveId, uint256(0), false
        );
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        borrowHook.build(address(0), address(this), data);
    }

    function test_BorrowHook_Build_RevertIf_ZeroSpoke() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, collateralToken, address(0), supplyReserveId, borrowReserveId, amount, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        borrowHook.build(address(0), address(this), data);
    }

    function test_BorrowHook_Build_RevertIf_InvalidDataLength() public {
        bytes memory shortData = abi.encodePacked(loanToken, collateralToken);
        vm.expectRevert(BaseAaveV4LoanHook.INVALID_DATA_LENGTH.selector);
        borrowHook.build(address(0), address(this), shortData);
    }

    function test_BorrowHook_Inspect() public view {
        bytes memory data = _encodeBorrowData(false);
        bytes memory result = borrowHook.inspect(data);
        assertEq(result, abi.encodePacked(spoke));
    }

    function test_BorrowHook_Inspect_RevertIf_ZeroAddress() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), address(0), collateralToken, spoke, supplyReserveId, borrowReserveId, amount, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        borrowHook.inspect(data);
    }

    function test_BorrowHook_PrePostExecute() public {
        bytes memory data = _encodeBorrowData(false);
        deal(loanToken, address(this), amount);

        borrowHook.preExecute(address(0), address(this), data);
        assertEq(borrowHook.getOutAmount(address(this)), amount);

        // post with same balance => outAmount = amount - amount = 0
        borrowHook.postExecute(address(0), address(this), data);
        assertEq(borrowHook.getOutAmount(address(this)), 0);
    }

    function test_BorrowHook_DecodeUsePrevHookAmount() public view {
        bytes memory dataFalse = _encodeBorrowData(false);
        assertEq(borrowHook.decodeUsePrevHookAmount(dataFalse), false);

        bytes memory dataTrue = _encodeBorrowData(true);
        assertEq(borrowHook.decodeUsePrevHookAmount(dataTrue), true);
    }

    /*//////////////////////////////////////////////////////////////
                         REPAY HOOK TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RepayHook_Build_Partial() public view {
        bytes memory data = _encodeRepayData(false, false);
        Execution[] memory executions = repayHook.build(address(0), address(this), data);

        assertEq(executions.length, 6); // preExecute + approve(0) + approve(amount) + repay + approve(0) + postExecute
        assertEq(executions[1].target, loanToken);
        assertEq(executions[2].target, loanToken);
        assertEq(executions[3].target, spoke);
        assertEq(executions[4].target, loanToken);
    }

    function test_RepayHook_Build_FullRepayment() public view {
        bytes memory data = _encodeRepayData(false, true);
        Execution[] memory executions = repayHook.build(address(0), address(this), data);

        assertEq(executions.length, 6);

        // Verify max approval for full repayment
        bytes memory expectedApproval = abi.encodeCall(IERC20Approve.approve, (spoke, type(uint256).max));
        assertEq(executions[2].callData, expectedApproval);

        // Verify max amount in repay call
        bytes memory expectedRepay =
            abi.encodeCall(IAaveV4Spoke.repay, (borrowReserveId, type(uint256).max, address(this)));
        assertEq(executions[3].callData, expectedRepay);
    }

    function test_RepayHook_BuildWithPrevHook() public {
        MockHookForPrevAmount mockPrevHook = new MockHookForPrevAmount(ISuperHook.HookType.NONACCOUNTING);
        uint256 prevAmount = 5e17;
        mockPrevHook.setOutAmount(prevAmount, address(this));

        bytes memory data = _encodeRepayData(true, false);
        Execution[] memory executions = repayHook.build(address(mockPrevHook), address(this), data);

        assertEq(executions.length, 6);
        bytes memory expectedRepay =
            abi.encodeCall(IAaveV4Spoke.repay, (borrowReserveId, prevAmount, address(this)));
        assertEq(executions[3].callData, expectedRepay);
    }

    function test_RepayHook_Build_RevertIf_ZeroAmount() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, collateralToken, spoke, supplyReserveId, borrowReserveId, uint256(0), false, false
        );
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        repayHook.build(address(0), address(this), data);
    }

    function test_RepayHook_Build_RevertIf_ZeroSpoke() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, collateralToken, address(0), supplyReserveId, borrowReserveId, amount, false, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayHook.build(address(0), address(this), data);
    }

    function test_RepayHook_Build_RevertIf_InvalidDataLength() public {
        bytes memory shortData = abi.encodePacked(loanToken, collateralToken);
        vm.expectRevert(BaseAaveV4LoanHook.INVALID_DATA_LENGTH.selector);
        repayHook.build(address(0), address(this), shortData);
    }

    function test_RepayHook_Inspect() public view {
        bytes memory data = _encodeRepayData(false, false);
        bytes memory result = repayHook.inspect(data);
        assertEq(result, abi.encodePacked(spoke));
    }

    function test_RepayHook_Inspect_RevertIf_ZeroAddress() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), address(0), collateralToken, spoke, supplyReserveId, borrowReserveId, amount, false, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayHook.inspect(data);
    }

    function test_RepayHook_PrePostExecute() public {
        bytes memory data = _encodeRepayData(false, false);

        repayHook.preExecute(address(0), address(this), data);
        assertEq(repayHook.getOutAmount(address(this)), 0);

        repayHook.postExecute(address(0), address(this), data);
        assertEq(repayHook.getOutAmount(address(this)), 0);
    }

    function test_RepayHook_PrePostExecute_WithBalance() public {
        bytes memory data = _encodeRepayData(false, false);
        deal(loanToken, address(this), amount);

        repayHook.preExecute(address(0), address(this), data);
        assertEq(repayHook.getOutAmount(address(this)), amount);

        // Simulate repay consuming loan tokens
        deal(loanToken, address(this), 0);
        repayHook.postExecute(address(0), address(this), data);
        assertEq(repayHook.getOutAmount(address(this)), amount);
    }

    function test_RepayHook_DecodeUsePrevHookAmount() public view {
        bytes memory dataFalse = _encodeRepayData(false, false);
        assertEq(repayHook.decodeUsePrevHookAmount(dataFalse), false);

        bytes memory dataTrue = _encodeRepayData(true, false);
        assertEq(repayHook.decodeUsePrevHookAmount(dataTrue), true);
    }

    /*//////////////////////////////////////////////////////////////
                    SUPPLY AND BORROW HOOK TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SupplyAndBorrowHook_Build() public view {
        bytes memory data = _encodeSupplyAndBorrowData(false, borrowAmount);
        Execution[] memory executions = supplyAndBorrowHook.build(address(0), address(this), data);

        // preExecute + approve(0) + approve(supplyAmount) + supply + setUsingAsCollateral + borrow + approve(0) +
        // postExecute
        assertEq(executions.length, 8);
        assertEq(executions[1].target, collateralToken); // approve(0)
        assertEq(executions[2].target, collateralToken); // approve(amount)
        assertEq(executions[3].target, spoke); // supply
        assertEq(executions[4].target, spoke); // setUsingAsCollateral
        assertEq(executions[5].target, spoke); // borrow
        assertEq(executions[6].target, collateralToken); // approve(0) cleanup

        // Verify borrow uses borrowReserveId and borrowAmount
        bytes memory expectedBorrow =
            abi.encodeCall(IAaveV4Spoke.borrow, (borrowReserveId, borrowAmount, address(this)));
        assertEq(executions[5].callData, expectedBorrow);
    }

    function test_SupplyAndBorrowHook_BuildWithPrevHook() public {
        MockHookForPrevAmount mockPrevHook = new MockHookForPrevAmount(ISuperHook.HookType.NONACCOUNTING);
        uint256 prevAmount = 3e18;
        mockPrevHook.setOutAmount(prevAmount, address(this));

        bytes memory data = _encodeSupplyAndBorrowData(true, borrowAmount);
        Execution[] memory executions = supplyAndBorrowHook.build(address(mockPrevHook), address(this), data);

        assertEq(executions.length, 8);
        // Verify supply uses prevAmount
        bytes memory expectedSupply =
            abi.encodeCall(IAaveV4Spoke.supply, (supplyReserveId, prevAmount, address(this)));
        assertEq(executions[3].callData, expectedSupply);
        // borrowAmount still from calldata
        bytes memory expectedBorrow =
            abi.encodeCall(IAaveV4Spoke.borrow, (borrowReserveId, borrowAmount, address(this)));
        assertEq(executions[5].callData, expectedBorrow);
    }

    function test_SupplyAndBorrowHook_Build_RevertIf_ZeroSupplyAmount() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, collateralToken, spoke, supplyReserveId, borrowReserveId, uint256(0), false, borrowAmount
        );
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        supplyAndBorrowHook.build(address(0), address(this), data);
    }

    function test_SupplyAndBorrowHook_Build_RevertIf_ZeroBorrowAmount() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, collateralToken, spoke, supplyReserveId, borrowReserveId, amount, false, uint256(0)
        );
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        supplyAndBorrowHook.build(address(0), address(this), data);
    }

    function test_SupplyAndBorrowHook_Build_RevertIf_ZeroSpoke() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, collateralToken, address(0), supplyReserveId, borrowReserveId, amount, false, borrowAmount
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        supplyAndBorrowHook.build(address(0), address(this), data);
    }

    function test_SupplyAndBorrowHook_Build_RevertIf_InvalidDataLength() public {
        bytes memory shortData = abi.encodePacked(loanToken, collateralToken);
        vm.expectRevert(BaseAaveV4LoanHook.INVALID_DATA_LENGTH.selector);
        supplyAndBorrowHook.build(address(0), address(this), shortData);
    }

    function test_SupplyAndBorrowHook_Inspect() public view {
        bytes memory data = _encodeSupplyAndBorrowData(false, borrowAmount);
        bytes memory result = supplyAndBorrowHook.inspect(data);
        assertEq(result, abi.encodePacked(spoke));
    }

    function test_SupplyAndBorrowHook_Inspect_RevertIf_ZeroAddress() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), address(0), collateralToken, spoke, supplyReserveId, borrowReserveId, amount, false, borrowAmount
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        supplyAndBorrowHook.inspect(data);
    }

    function test_SupplyAndBorrowHook_PrePostExecute() public {
        bytes memory data = _encodeSupplyAndBorrowData(false, borrowAmount);
        deal(collateralToken, address(this), amount);

        supplyAndBorrowHook.preExecute(address(0), address(this), data);
        assertEq(supplyAndBorrowHook.getOutAmount(address(this)), amount);

        supplyAndBorrowHook.postExecute(address(0), address(this), data);
        assertEq(supplyAndBorrowHook.getOutAmount(address(this)), 0);
    }

    function test_SupplyAndBorrowHook_DecodeUsePrevHookAmount() public view {
        bytes memory dataFalse = _encodeSupplyAndBorrowData(false, borrowAmount);
        assertEq(supplyAndBorrowHook.decodeUsePrevHookAmount(dataFalse), false);

        bytes memory dataTrue = _encodeSupplyAndBorrowData(true, borrowAmount);
        assertEq(supplyAndBorrowHook.decodeUsePrevHookAmount(dataTrue), true);
    }

    /*//////////////////////////////////////////////////////////////
                    REPAY AND WITHDRAW HOOK TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RepayAndWithdrawHook_Build_Partial() public view {
        bytes memory data = _encodeRepayAndWithdrawData(false, false, withdrawAmount);
        Execution[] memory executions = repayAndWithdrawHook.build(address(0), address(this), data);

        // preExecute + approve(0) + approve(amount) + repay + approve(0) + withdraw + postExecute
        assertEq(executions.length, 7);
        assertEq(executions[1].target, loanToken); // approve(0)
        assertEq(executions[2].target, loanToken); // approve(repayAmount)
        assertEq(executions[3].target, spoke); // repay
        assertEq(executions[4].target, loanToken); // approve(0) cleanup
        assertEq(executions[5].target, spoke); // withdraw

        // Verify withdraw uses supplyReserveId and withdrawAmount
        bytes memory expectedWithdraw =
            abi.encodeCall(IAaveV4Spoke.withdraw, (supplyReserveId, withdrawAmount, address(this)));
        assertEq(executions[5].callData, expectedWithdraw);
    }

    function test_RepayAndWithdrawHook_Build_FullRepayment() public view {
        bytes memory data = _encodeRepayAndWithdrawData(false, true, withdrawAmount);
        Execution[] memory executions = repayAndWithdrawHook.build(address(0), address(this), data);

        assertEq(executions.length, 7);

        // Verify max approval
        bytes memory expectedApproval = abi.encodeCall(IERC20Approve.approve, (spoke, type(uint256).max));
        assertEq(executions[2].callData, expectedApproval);

        // Verify max repay
        bytes memory expectedRepay =
            abi.encodeCall(IAaveV4Spoke.repay, (borrowReserveId, type(uint256).max, address(this)));
        assertEq(executions[3].callData, expectedRepay);

        // Verify max withdraw
        bytes memory expectedWithdraw =
            abi.encodeCall(IAaveV4Spoke.withdraw, (supplyReserveId, type(uint256).max, address(this)));
        assertEq(executions[5].callData, expectedWithdraw);
    }

    function test_RepayAndWithdrawHook_BuildWithPrevHook() public {
        MockHookForPrevAmount mockPrevHook = new MockHookForPrevAmount(ISuperHook.HookType.NONACCOUNTING);
        uint256 prevAmount = 7e17;
        mockPrevHook.setOutAmount(prevAmount, address(this));

        bytes memory data = _encodeRepayAndWithdrawData(true, false, withdrawAmount);
        Execution[] memory executions = repayAndWithdrawHook.build(address(mockPrevHook), address(this), data);

        assertEq(executions.length, 7);
        bytes memory expectedRepay =
            abi.encodeCall(IAaveV4Spoke.repay, (borrowReserveId, prevAmount, address(this)));
        assertEq(executions[3].callData, expectedRepay);
    }

    function test_RepayAndWithdrawHook_Build_RevertIf_ZeroRepayAmount() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, collateralToken, spoke, supplyReserveId, borrowReserveId, uint256(0), false, false, withdrawAmount
        );
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        repayAndWithdrawHook.build(address(0), address(this), data);
    }

    function test_RepayAndWithdrawHook_Build_RevertIf_ZeroWithdrawAmount() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, collateralToken, spoke, supplyReserveId, borrowReserveId, amount, false, false, uint256(0)
        );
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        repayAndWithdrawHook.build(address(0), address(this), data);
    }

    function test_RepayAndWithdrawHook_Build_RevertIf_ZeroSpoke() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken,
            collateralToken,
            address(0),
            supplyReserveId,
            borrowReserveId,
            amount,
            false,
            false,
            withdrawAmount
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayAndWithdrawHook.build(address(0), address(this), data);
    }

    function test_RepayAndWithdrawHook_Build_RevertIf_InvalidDataLength() public {
        bytes memory shortData = abi.encodePacked(loanToken, collateralToken);
        vm.expectRevert(BaseAaveV4LoanHook.INVALID_DATA_LENGTH.selector);
        repayAndWithdrawHook.build(address(0), address(this), shortData);
    }

    function test_RepayAndWithdrawHook_Inspect() public view {
        bytes memory data = _encodeRepayAndWithdrawData(false, false, withdrawAmount);
        bytes memory result = repayAndWithdrawHook.inspect(data);
        assertEq(result, abi.encodePacked(spoke));
    }

    function test_RepayAndWithdrawHook_Inspect_RevertIf_ZeroAddress() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            address(0),
            collateralToken,
            spoke,
            supplyReserveId,
            borrowReserveId,
            amount,
            false,
            false,
            withdrawAmount
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayAndWithdrawHook.inspect(data);
    }

    function test_RepayAndWithdrawHook_PrePostExecute() public {
        bytes memory data = _encodeRepayAndWithdrawData(false, false, withdrawAmount);

        repayAndWithdrawHook.preExecute(address(0), address(this), data);
        assertEq(repayAndWithdrawHook.getOutAmount(address(this)), 0);

        // Simulate receiving collateral
        deal(collateralToken, address(this), amount);
        repayAndWithdrawHook.postExecute(address(0), address(this), data);
        assertEq(repayAndWithdrawHook.getOutAmount(address(this)), amount);
    }

    function test_RepayAndWithdrawHook_DecodeUsePrevHookAmount() public view {
        bytes memory dataFalse = _encodeRepayAndWithdrawData(false, false, withdrawAmount);
        assertEq(repayAndWithdrawHook.decodeUsePrevHookAmount(dataFalse), false);

        bytes memory dataTrue = _encodeRepayAndWithdrawData(true, false, withdrawAmount);
        assertEq(repayAndWithdrawHook.decodeUsePrevHookAmount(dataTrue), true);
    }

    /*//////////////////////////////////////////////////////////////
                    CONSTRUCTOR / HOOK SUBTYPE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SupplyHook_HookSubType() public view {
        assertEq(supplyHook.SUB_TYPE(), HookSubTypes.LOAN);
    }

    function test_WithdrawHook_HookSubType() public view {
        assertEq(withdrawHook.SUB_TYPE(), HookSubTypes.LOAN_REPAY);
    }

    function test_BorrowHook_HookSubType() public view {
        assertEq(borrowHook.SUB_TYPE(), HookSubTypes.LOAN);
    }

    function test_RepayHook_HookSubType() public view {
        assertEq(repayHook.SUB_TYPE(), HookSubTypes.LOAN_REPAY);
    }

    function test_SupplyAndBorrowHook_HookSubType() public view {
        assertEq(supplyAndBorrowHook.SUB_TYPE(), HookSubTypes.LOAN);
    }

    function test_RepayAndWithdrawHook_HookSubType() public view {
        assertEq(repayAndWithdrawHook.SUB_TYPE(), HookSubTypes.LOAN_REPAY);
    }

    /*//////////////////////////////////////////////////////////////
          SUPPLY HOOK - ADDITIONAL CALLDATA VERIFICATION
    //////////////////////////////////////////////////////////////*/

    function test_SupplyHook_Build_VerifyAllCalldata() public view {
        bytes memory data = _encodeSupplyData(false);
        Execution[] memory executions = supplyHook.build(address(0), address(this), data);

        // exec[1] = approve(spoke, 0)
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (spoke, 0)));
        // exec[2] = approve(spoke, amount)
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (spoke, amount)));
        // exec[3] = supply(reserveId, amount, account)
        assertEq(executions[3].callData, abi.encodeCall(IAaveV4Spoke.supply, (supplyReserveId, amount, address(this))));
        // exec[4] = setUsingAsCollateral(reserveId, true, account)
        assertEq(
            executions[4].callData,
            abi.encodeCall(IAaveV4Spoke.setUsingAsCollateral, (supplyReserveId, true, address(this)))
        );
        // exec[5] = approve(spoke, 0) cleanup
        assertEq(executions[5].callData, abi.encodeCall(IERC20.approve, (spoke, 0)));
    }

    function test_SupplyHook_Build_AllExecutionValues_AreZero() public view {
        bytes memory data = _encodeSupplyData(false);
        Execution[] memory executions = supplyHook.build(address(0), address(this), data);
        // All executions should have value = 0
        for (uint256 i = 0; i < executions.length; i++) {
            assertEq(executions[i].value, 0);
        }
    }

    function test_SupplyHook_PrePostExecute_WithBalanceDecrease() public {
        bytes memory data = _encodeSupplyData(false);
        deal(collateralToken, address(this), 5e18);

        supplyHook.preExecute(address(0), address(this), data);
        assertEq(supplyHook.getOutAmount(address(this)), 5e18);

        // Simulate supply consuming 3e18
        deal(collateralToken, address(this), 2e18);
        supplyHook.postExecute(address(0), address(this), data);
        assertEq(supplyHook.getOutAmount(address(this)), 3e18);
    }

    /*//////////////////////////////////////////////////////////////
          WITHDRAW HOOK - ZERO ADDRESS REVERTS + CALLDATA
    //////////////////////////////////////////////////////////////*/

    function test_WithdrawHook_Build_RevertIf_ZeroLoanToken() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), address(0), collateralToken, spoke, supplyReserveId, borrowReserveId, amount, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        withdrawHook.build(address(0), address(this), data);
    }

    function test_WithdrawHook_Build_RevertIf_ZeroCollateralToken() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, address(0), spoke, supplyReserveId, borrowReserveId, amount, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        withdrawHook.build(address(0), address(this), data);
    }

    function test_WithdrawHook_Build_VerifyCalldata() public view {
        bytes memory data = _encodeWithdrawData(false);
        Execution[] memory executions = withdrawHook.build(address(0), address(this), data);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IAaveV4Spoke.withdraw, (supplyReserveId, amount, address(this)))
        );
    }

    function test_WithdrawHook_GetLoanTokenAddress() public view {
        bytes memory data = _encodeWithdrawData(false);
        assertEq(withdrawHook.getLoanTokenAddress(data), loanToken);
    }

    function test_WithdrawHook_GetCollateralTokenAddress() public view {
        bytes memory data = _encodeWithdrawData(false);
        assertEq(withdrawHook.getCollateralTokenAddress(data), collateralToken);
    }

    function test_WithdrawHook_GetCollateralTokenBalance() public {
        bytes memory data = _encodeWithdrawData(false);
        deal(collateralToken, address(this), 7e18);
        assertEq(withdrawHook.getCollateralTokenBalance(address(this), data), 7e18);
    }

    function test_WithdrawHook_GetLoanTokenBalance() public {
        bytes memory data = _encodeWithdrawData(false);
        deal(loanToken, address(this), 4e18);
        assertEq(withdrawHook.getLoanTokenBalance(address(this), data), 4e18);
    }

    function test_WithdrawHook_Inspect_RevertIf_ZeroCollateralToken() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, address(0), spoke, supplyReserveId, borrowReserveId, amount, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        withdrawHook.inspect(data);
    }

    function test_WithdrawHook_Inspect_RevertIf_ZeroSpoke() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, collateralToken, address(0), supplyReserveId, borrowReserveId, amount, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        withdrawHook.inspect(data);
    }

    /*//////////////////////////////////////////////////////////////
          BORROW HOOK - ZERO ADDRESS REVERTS + CALLDATA
    //////////////////////////////////////////////////////////////*/

    function test_BorrowHook_Build_RevertIf_ZeroLoanToken() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), address(0), collateralToken, spoke, supplyReserveId, borrowReserveId, amount, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        borrowHook.build(address(0), address(this), data);
    }

    function test_BorrowHook_Build_RevertIf_ZeroCollateralToken() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, address(0), spoke, supplyReserveId, borrowReserveId, amount, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        borrowHook.build(address(0), address(this), data);
    }

    function test_BorrowHook_Build_VerifyCalldata() public view {
        bytes memory data = _encodeBorrowData(false);
        Execution[] memory executions = borrowHook.build(address(0), address(this), data);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IAaveV4Spoke.borrow, (borrowReserveId, amount, address(this)))
        );
    }

    function test_BorrowHook_GetLoanTokenAddress() public view {
        bytes memory data = _encodeBorrowData(false);
        assertEq(borrowHook.getLoanTokenAddress(data), loanToken);
    }

    function test_BorrowHook_GetCollateralTokenAddress() public view {
        bytes memory data = _encodeBorrowData(false);
        assertEq(borrowHook.getCollateralTokenAddress(data), collateralToken);
    }

    function test_BorrowHook_GetCollateralTokenBalance() public {
        bytes memory data = _encodeBorrowData(false);
        deal(collateralToken, address(this), 2e18);
        assertEq(borrowHook.getCollateralTokenBalance(address(this), data), 2e18);
    }

    function test_BorrowHook_GetLoanTokenBalance() public {
        bytes memory data = _encodeBorrowData(false);
        deal(loanToken, address(this), 6e18);
        assertEq(borrowHook.getLoanTokenBalance(address(this), data), 6e18);
    }

    function test_BorrowHook_Inspect_RevertIf_ZeroCollateralToken() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, address(0), spoke, supplyReserveId, borrowReserveId, amount, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        borrowHook.inspect(data);
    }

    function test_BorrowHook_Inspect_RevertIf_ZeroSpoke() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, collateralToken, address(0), supplyReserveId, borrowReserveId, amount, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        borrowHook.inspect(data);
    }

    function test_BorrowHook_PrePostExecute_WithBalanceIncrease() public {
        bytes memory data = _encodeBorrowData(false);
        deal(loanToken, address(this), 1e18);

        borrowHook.preExecute(address(0), address(this), data);
        assertEq(borrowHook.getOutAmount(address(this)), 1e18);

        // Simulate borrow adding 2e18 loan tokens
        deal(loanToken, address(this), 3e18);
        borrowHook.postExecute(address(0), address(this), data);
        assertEq(borrowHook.getOutAmount(address(this)), 2e18);
    }

    /*//////////////////////////////////////////////////////////////
          REPAY HOOK - ZERO ADDRESS REVERTS + CALLDATA + EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_RepayHook_Build_RevertIf_ZeroLoanToken() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), address(0), collateralToken, spoke, supplyReserveId, borrowReserveId, amount, false, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayHook.build(address(0), address(this), data);
    }

    function test_RepayHook_Build_RevertIf_ZeroCollateralToken() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, address(0), spoke, supplyReserveId, borrowReserveId, amount, false, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayHook.build(address(0), address(this), data);
    }

    function test_RepayHook_Build_Partial_VerifyAllCalldata() public view {
        bytes memory data = _encodeRepayData(false, false);
        Execution[] memory executions = repayHook.build(address(0), address(this), data);

        // exec[1] = approve(spoke, 0)
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (spoke, 0)));
        // exec[2] = approve(spoke, amount)
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (spoke, amount)));
        // exec[3] = repay(borrowReserveId, amount, account)
        assertEq(
            executions[3].callData,
            abi.encodeCall(IAaveV4Spoke.repay, (borrowReserveId, amount, address(this)))
        );
        // exec[4] = approve(spoke, 0) cleanup
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (spoke, 0)));
    }

    function test_RepayHook_Build_FullRepayment_VerifyAllCalldata() public view {
        bytes memory data = _encodeRepayData(false, true);
        Execution[] memory executions = repayHook.build(address(0), address(this), data);

        // exec[1] = approve(spoke, 0)
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (spoke, 0)));
        // exec[2] = approve(spoke, type(uint256).max)
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (spoke, type(uint256).max)));
        // exec[3] = repay(borrowReserveId, type(uint256).max, account)
        assertEq(
            executions[3].callData,
            abi.encodeCall(IAaveV4Spoke.repay, (borrowReserveId, type(uint256).max, address(this)))
        );
        // exec[4] = approve(spoke, 0) cleanup
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (spoke, 0)));
    }

    /// @notice Full repayment path should NOT check usePrevHookAmount or amount==0
    function test_RepayHook_Build_FullRepayment_IgnoresZeroAmount() public view {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, collateralToken, spoke, supplyReserveId, borrowReserveId, uint256(0), false, true
        );
        // Should NOT revert — full repayment path skips amount/prevHookAmount checks
        Execution[] memory executions = repayHook.build(address(0), address(this), data);
        assertEq(executions.length, 6);
    }

    function test_RepayHook_GetLoanTokenAddress() public view {
        bytes memory data = _encodeRepayData(false, false);
        assertEq(repayHook.getLoanTokenAddress(data), loanToken);
    }

    function test_RepayHook_GetCollateralTokenAddress() public view {
        bytes memory data = _encodeRepayData(false, false);
        assertEq(repayHook.getCollateralTokenAddress(data), collateralToken);
    }

    function test_RepayHook_GetCollateralTokenBalance() public {
        bytes memory data = _encodeRepayData(false, false);
        deal(collateralToken, address(this), 9e18);
        assertEq(repayHook.getCollateralTokenBalance(address(this), data), 9e18);
    }

    function test_RepayHook_GetLoanTokenBalance() public {
        bytes memory data = _encodeRepayData(false, false);
        deal(loanToken, address(this), 8e18);
        assertEq(repayHook.getLoanTokenBalance(address(this), data), 8e18);
    }

    function test_RepayHook_Inspect_RevertIf_ZeroCollateralToken() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, address(0), spoke, supplyReserveId, borrowReserveId, amount, false, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayHook.inspect(data);
    }

    function test_RepayHook_Inspect_RevertIf_ZeroSpoke() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, collateralToken, address(0), supplyReserveId, borrowReserveId, amount, false, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayHook.inspect(data);
    }

    /*//////////////////////////////////////////////////////////////
      SUPPLY AND BORROW HOOK - ZERO ADDRESS + CALLDATA + EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_SupplyAndBorrowHook_Build_RevertIf_ZeroLoanToken() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), address(0), collateralToken, spoke, supplyReserveId, borrowReserveId, amount, false, borrowAmount
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        supplyAndBorrowHook.build(address(0), address(this), data);
    }

    function test_SupplyAndBorrowHook_Build_RevertIf_ZeroCollateralToken() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, address(0), spoke, supplyReserveId, borrowReserveId, amount, false, borrowAmount
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        supplyAndBorrowHook.build(address(0), address(this), data);
    }

    function test_SupplyAndBorrowHook_Build_VerifyAllCalldata() public view {
        bytes memory data = _encodeSupplyAndBorrowData(false, borrowAmount);
        Execution[] memory executions = supplyAndBorrowHook.build(address(0), address(this), data);

        // exec[1] = approve(spoke, 0)
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (spoke, 0)));
        // exec[2] = approve(spoke, amount)
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (spoke, amount)));
        // exec[3] = supply
        assertEq(
            executions[3].callData,
            abi.encodeCall(IAaveV4Spoke.supply, (supplyReserveId, amount, address(this)))
        );
        // exec[4] = setUsingAsCollateral
        assertEq(
            executions[4].callData,
            abi.encodeCall(IAaveV4Spoke.setUsingAsCollateral, (supplyReserveId, true, address(this)))
        );
        // exec[5] = borrow
        assertEq(
            executions[5].callData,
            abi.encodeCall(IAaveV4Spoke.borrow, (borrowReserveId, borrowAmount, address(this)))
        );
        // exec[6] = approve(spoke, 0) cleanup
        assertEq(executions[6].callData, abi.encodeCall(IERC20.approve, (spoke, 0)));
    }

    function test_SupplyAndBorrowHook_GetLoanTokenAddress() public view {
        bytes memory data = _encodeSupplyAndBorrowData(false, borrowAmount);
        assertEq(supplyAndBorrowHook.getLoanTokenAddress(data), loanToken);
    }

    function test_SupplyAndBorrowHook_GetCollateralTokenAddress() public view {
        bytes memory data = _encodeSupplyAndBorrowData(false, borrowAmount);
        assertEq(supplyAndBorrowHook.getCollateralTokenAddress(data), collateralToken);
    }

    function test_SupplyAndBorrowHook_GetCollateralTokenBalance() public {
        bytes memory data = _encodeSupplyAndBorrowData(false, borrowAmount);
        deal(collateralToken, address(this), 10e18);
        assertEq(supplyAndBorrowHook.getCollateralTokenBalance(address(this), data), 10e18);
    }

    function test_SupplyAndBorrowHook_GetLoanTokenBalance() public {
        bytes memory data = _encodeSupplyAndBorrowData(false, borrowAmount);
        deal(loanToken, address(this), 2e18);
        assertEq(supplyAndBorrowHook.getLoanTokenBalance(address(this), data), 2e18);
    }

    function test_SupplyAndBorrowHook_PrePostExecute_WithBalanceDecrease() public {
        bytes memory data = _encodeSupplyAndBorrowData(false, borrowAmount);
        deal(collateralToken, address(this), 5e18);

        supplyAndBorrowHook.preExecute(address(0), address(this), data);
        assertEq(supplyAndBorrowHook.getOutAmount(address(this)), 5e18);

        // Simulate supply consuming 2e18 collateral
        deal(collateralToken, address(this), 3e18);
        supplyAndBorrowHook.postExecute(address(0), address(this), data);
        assertEq(supplyAndBorrowHook.getOutAmount(address(this)), 2e18);
    }

    function test_SupplyAndBorrowHook_Inspect_RevertIf_ZeroCollateralToken() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, address(0), spoke, supplyReserveId, borrowReserveId, amount, false, borrowAmount
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        supplyAndBorrowHook.inspect(data);
    }

    function test_SupplyAndBorrowHook_Inspect_RevertIf_ZeroSpoke() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, collateralToken, address(0), supplyReserveId, borrowReserveId, amount, false, borrowAmount
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        supplyAndBorrowHook.inspect(data);
    }

    /*//////////////////////////////////////////////////////////////
      REPAY AND WITHDRAW HOOK - ZERO ADDRESS + CALLDATA + EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_RepayAndWithdrawHook_Build_RevertIf_ZeroLoanToken() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), address(0), collateralToken, spoke, supplyReserveId, borrowReserveId, amount, false, false, withdrawAmount
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayAndWithdrawHook.build(address(0), address(this), data);
    }

    function test_RepayAndWithdrawHook_Build_RevertIf_ZeroCollateralToken() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, address(0), spoke, supplyReserveId, borrowReserveId, amount, false, false, withdrawAmount
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayAndWithdrawHook.build(address(0), address(this), data);
    }

    function test_RepayAndWithdrawHook_Build_Partial_VerifyAllCalldata() public view {
        bytes memory data = _encodeRepayAndWithdrawData(false, false, withdrawAmount);
        Execution[] memory executions = repayAndWithdrawHook.build(address(0), address(this), data);

        // exec[1] = approve(spoke, 0)
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (spoke, 0)));
        // exec[2] = approve(spoke, amount)
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (spoke, amount)));
        // exec[3] = repay(borrowReserveId, amount, account)
        assertEq(
            executions[3].callData,
            abi.encodeCall(IAaveV4Spoke.repay, (borrowReserveId, amount, address(this)))
        );
        // exec[4] = approve(spoke, 0) cleanup
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (spoke, 0)));
        // exec[5] = withdraw(supplyReserveId, withdrawAmount, account)
        assertEq(
            executions[5].callData,
            abi.encodeCall(IAaveV4Spoke.withdraw, (supplyReserveId, withdrawAmount, address(this)))
        );
    }

    function test_RepayAndWithdrawHook_Build_FullRepayment_VerifyAllCalldata() public view {
        bytes memory data = _encodeRepayAndWithdrawData(false, true, withdrawAmount);
        Execution[] memory executions = repayAndWithdrawHook.build(address(0), address(this), data);

        // exec[1] = approve(spoke, 0)
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (spoke, 0)));
        // exec[2] = approve(spoke, type(uint256).max)
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (spoke, type(uint256).max)));
        // exec[3] = repay(borrowReserveId, type(uint256).max, account)
        assertEq(
            executions[3].callData,
            abi.encodeCall(IAaveV4Spoke.repay, (borrowReserveId, type(uint256).max, address(this)))
        );
        // exec[4] = approve(spoke, 0)
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (spoke, 0)));
        // exec[5] = withdraw(supplyReserveId, type(uint256).max, account)
        assertEq(
            executions[5].callData,
            abi.encodeCall(IAaveV4Spoke.withdraw, (supplyReserveId, type(uint256).max, address(this)))
        );
    }

    /// @notice Full repayment path should NOT check usePrevHookAmount or amount/withdrawAmount==0
    function test_RepayAndWithdrawHook_Build_FullRepayment_IgnoresZeroAmounts() public view {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken,
            collateralToken,
            spoke,
            supplyReserveId,
            borrowReserveId,
            uint256(0), // amount = 0, but full repay ignores it
            false,
            true, // isFullRepayment
            uint256(0) // withdrawAmount, also ignored in full path (uses max)
        );
        Execution[] memory executions = repayAndWithdrawHook.build(address(0), address(this), data);
        assertEq(executions.length, 7);
    }

    function test_RepayAndWithdrawHook_BuildWithPrevHook_PartialVerifyRepayAmount() public {
        MockHookForPrevAmount mockPrevHook = new MockHookForPrevAmount(ISuperHook.HookType.NONACCOUNTING);
        uint256 prevAmount = 3e17;
        mockPrevHook.setOutAmount(prevAmount, address(this));

        bytes memory data = _encodeRepayAndWithdrawData(true, false, withdrawAmount);
        Execution[] memory executions = repayAndWithdrawHook.build(address(mockPrevHook), address(this), data);

        // repay should use prevAmount
        assertEq(
            executions[3].callData,
            abi.encodeCall(IAaveV4Spoke.repay, (borrowReserveId, prevAmount, address(this)))
        );
        // approve should also use prevAmount
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (spoke, prevAmount)));
        // withdraw should still use withdrawAmount from calldata
        assertEq(
            executions[5].callData,
            abi.encodeCall(IAaveV4Spoke.withdraw, (supplyReserveId, withdrawAmount, address(this)))
        );
    }

    function test_RepayAndWithdrawHook_Build_Partial_RevertIf_PrevHookZeroAmount() public {
        MockHookForPrevAmount mockPrevHook = new MockHookForPrevAmount(ISuperHook.HookType.NONACCOUNTING);
        mockPrevHook.setOutAmount(0, address(this));

        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, collateralToken, spoke, supplyReserveId, borrowReserveId, uint256(0), true, false, withdrawAmount
        );
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        repayAndWithdrawHook.build(address(mockPrevHook), address(this), data);
    }

    function test_RepayAndWithdrawHook_GetLoanTokenAddress() public view {
        bytes memory data = _encodeRepayAndWithdrawData(false, false, withdrawAmount);
        assertEq(repayAndWithdrawHook.getLoanTokenAddress(data), loanToken);
    }

    function test_RepayAndWithdrawHook_GetCollateralTokenAddress() public view {
        bytes memory data = _encodeRepayAndWithdrawData(false, false, withdrawAmount);
        assertEq(repayAndWithdrawHook.getCollateralTokenAddress(data), collateralToken);
    }

    function test_RepayAndWithdrawHook_GetCollateralTokenBalance() public {
        bytes memory data = _encodeRepayAndWithdrawData(false, false, withdrawAmount);
        deal(collateralToken, address(this), 11e18);
        assertEq(repayAndWithdrawHook.getCollateralTokenBalance(address(this), data), 11e18);
    }

    function test_RepayAndWithdrawHook_GetLoanTokenBalance() public {
        bytes memory data = _encodeRepayAndWithdrawData(false, false, withdrawAmount);
        deal(loanToken, address(this), 6e18);
        assertEq(repayAndWithdrawHook.getLoanTokenBalance(address(this), data), 6e18);
    }

    function test_RepayAndWithdrawHook_PrePostExecute_WithBalanceIncrease() public {
        bytes memory data = _encodeRepayAndWithdrawData(false, false, withdrawAmount);
        deal(collateralToken, address(this), 1e18);

        repayAndWithdrawHook.preExecute(address(0), address(this), data);
        assertEq(repayAndWithdrawHook.getOutAmount(address(this)), 1e18);

        // Simulate withdraw adding 4e18 collateral
        deal(collateralToken, address(this), 5e18);
        repayAndWithdrawHook.postExecute(address(0), address(this), data);
        assertEq(repayAndWithdrawHook.getOutAmount(address(this)), 4e18);
    }

    function test_RepayAndWithdrawHook_Inspect_RevertIf_ZeroCollateralToken() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken,
            address(0),
            spoke,
            supplyReserveId,
            borrowReserveId,
            amount,
            false,
            false,
            withdrawAmount
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayAndWithdrawHook.inspect(data);
    }

    function test_RepayAndWithdrawHook_Inspect_RevertIf_ZeroSpoke() public {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken,
            collateralToken,
            address(0),
            supplyReserveId,
            borrowReserveId,
            amount,
            false,
            false,
            withdrawAmount
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayAndWithdrawHook.inspect(data);
    }

    /*//////////////////////////////////////////////////////////////
                 ADDITIONAL EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice RepayHook: prevHookAmount returning 0 should revert in partial path
    function test_RepayHook_Build_Partial_RevertIf_PrevHookZeroAmount() public {
        MockHookForPrevAmount mockPrevHook = new MockHookForPrevAmount(ISuperHook.HookType.NONACCOUNTING);
        mockPrevHook.setOutAmount(0, address(this));

        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            loanToken, collateralToken, spoke, supplyReserveId, borrowReserveId, uint256(0), true, false
        );
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        repayHook.build(address(mockPrevHook), address(this), data);
    }

    /// @notice SupplyHook: prevHookAmount returning 0 should revert
    function test_SupplyHook_Build_RevertIf_PrevHookZeroAmount() public {
        MockHookForPrevAmount mockPrevHook = new MockHookForPrevAmount(ISuperHook.HookType.NONACCOUNTING);
        mockPrevHook.setOutAmount(0, address(this));

        bytes memory data = _encodeSupplyData(true);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        supplyHook.build(address(mockPrevHook), address(this), data);
    }

    /// @notice WithdrawHook: prevHookAmount returning 0 should revert
    function test_WithdrawHook_Build_RevertIf_PrevHookZeroAmount() public {
        MockHookForPrevAmount mockPrevHook = new MockHookForPrevAmount(ISuperHook.HookType.NONACCOUNTING);
        mockPrevHook.setOutAmount(0, address(this));

        bytes memory data = _encodeWithdrawData(true);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        withdrawHook.build(address(mockPrevHook), address(this), data);
    }

    /// @notice BorrowHook: prevHookAmount returning 0 should revert
    function test_BorrowHook_Build_RevertIf_PrevHookZeroAmount() public {
        MockHookForPrevAmount mockPrevHook = new MockHookForPrevAmount(ISuperHook.HookType.NONACCOUNTING);
        mockPrevHook.setOutAmount(0, address(this));

        bytes memory data = _encodeBorrowData(true);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        borrowHook.build(address(mockPrevHook), address(this), data);
    }

    /// @notice SupplyAndBorrowHook: prevHookAmount returning 0 should revert
    function test_SupplyAndBorrowHook_Build_RevertIf_PrevHookZeroAmount() public {
        MockHookForPrevAmount mockPrevHook = new MockHookForPrevAmount(ISuperHook.HookType.NONACCOUNTING);
        mockPrevHook.setOutAmount(0, address(this));

        bytes memory data = _encodeSupplyAndBorrowData(true, borrowAmount);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        supplyAndBorrowHook.build(address(mockPrevHook), address(this), data);
    }

    /// @notice Withdraw hook with invalid data length
    function test_WithdrawHook_Inspect_RevertIf_InvalidDataLength() public {
        bytes memory shortData = abi.encodePacked(loanToken, collateralToken);
        vm.expectRevert(BaseAaveV4LoanHook.INVALID_DATA_LENGTH.selector);
        withdrawHook.inspect(shortData);
    }

    /// @notice Borrow hook inspect with invalid data length
    function test_BorrowHook_Inspect_RevertIf_InvalidDataLength() public {
        bytes memory shortData = abi.encodePacked(loanToken, collateralToken);
        vm.expectRevert(BaseAaveV4LoanHook.INVALID_DATA_LENGTH.selector);
        borrowHook.inspect(shortData);
    }

    /// @notice Repay hook inspect with invalid data length
    function test_RepayHook_Inspect_RevertIf_InvalidDataLength() public {
        bytes memory shortData = abi.encodePacked(loanToken, collateralToken);
        vm.expectRevert(BaseAaveV4LoanHook.INVALID_DATA_LENGTH.selector);
        repayHook.inspect(shortData);
    }

    /// @notice SupplyAndBorrow hook inspect with invalid data length
    function test_SupplyAndBorrowHook_Inspect_RevertIf_InvalidDataLength() public {
        bytes memory shortData = abi.encodePacked(loanToken, collateralToken);
        vm.expectRevert(BaseAaveV4LoanHook.INVALID_DATA_LENGTH.selector);
        supplyAndBorrowHook.inspect(shortData);
    }

    /// @notice RepayAndWithdraw hook inspect with invalid data length
    function test_RepayAndWithdrawHook_Inspect_RevertIf_InvalidDataLength() public {
        bytes memory shortData = abi.encodePacked(loanToken, collateralToken);
        vm.expectRevert(BaseAaveV4LoanHook.INVALID_DATA_LENGTH.selector);
        repayAndWithdrawHook.inspect(shortData);
    }

    /// @notice Supply hook inspect with invalid data length
    function test_SupplyHook_Inspect_RevertIf_InvalidDataLength() public {
        bytes memory shortData = abi.encodePacked(loanToken, collateralToken);
        vm.expectRevert(BaseAaveV4LoanHook.INVALID_DATA_LENGTH.selector);
        supplyHook.inspect(shortData);
    }

    /// @notice WithdrawHook: preExecute then postExecute with increased balance
    function test_WithdrawHook_PrePostExecute_WithBalance() public {
        bytes memory data = _encodeWithdrawData(false);
        deal(collateralToken, address(this), 2e18);

        withdrawHook.preExecute(address(0), address(this), data);
        assertEq(withdrawHook.getOutAmount(address(this)), 2e18);

        // Simulate balance increase from withdraw (e.g. 2e18 → 5e18)
        deal(collateralToken, address(this), 5e18);
        withdrawHook.postExecute(address(0), address(this), data);
        // outAmount = currentBalance - preBalance = 5e18 - 2e18 = 3e18
        assertEq(withdrawHook.getOutAmount(address(this)), 3e18);
    }

    /*//////////////////////////////////////////////////////////////
              DECODE AMOUNT / REPLACE CALLDATA AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_SupplyHook_DecodeAmounts() public view {
        bytes memory data = _encodeSupplyData(false);
        assertEq(supplyHook.decodeAmounts(data)[0], amount);
    }

    function test_SupplyHook_ReplaceCalldataAmounts() public view {
        bytes memory data = _encodeSupplyData(false);
        uint256 newAmount = 2e18;
        bytes memory result = supplyHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(supplyHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_SupplyHook_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeSupplyData(false);
        bytes memory result = supplyHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(supplyHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_WithdrawHook_DecodeAmounts() public view {
        bytes memory data = _encodeWithdrawData(false);
        assertEq(withdrawHook.decodeAmounts(data)[0], amount);
    }

    function test_WithdrawHook_ReplaceCalldataAmounts() public view {
        bytes memory data = _encodeWithdrawData(false);
        uint256 newAmount = 2e18;
        bytes memory result = withdrawHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(withdrawHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_WithdrawHook_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeWithdrawData(false);
        bytes memory result = withdrawHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(withdrawHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_BorrowHook_DecodeAmounts() public view {
        bytes memory data = _encodeBorrowData(false);
        assertEq(borrowHook.decodeAmounts(data)[0], amount);
    }

    function test_BorrowHook_ReplaceCalldataAmounts() public view {
        bytes memory data = _encodeBorrowData(false);
        uint256 newAmount = 2e18;
        bytes memory result = borrowHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(borrowHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_BorrowHook_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeBorrowData(false);
        bytes memory result = borrowHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(borrowHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_RepayHook_DecodeAmounts() public view {
        bytes memory data = _encodeRepayData(false, false);
        assertEq(repayHook.decodeAmounts(data)[0], amount);
    }

    function test_RepayHook_ReplaceCalldataAmounts() public view {
        bytes memory data = _encodeRepayData(false, false);
        uint256 newAmount = 2e18;
        bytes memory result = repayHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(repayHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_RepayHook_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeRepayData(false, false);
        bytes memory result = repayHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(repayHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_SupplyAndBorrowHook_DecodeAmounts() public view {
        bytes memory data = _encodeSupplyAndBorrowData(false, 500);
        assertEq(supplyAndBorrowHook.decodeAmounts(data)[0], amount);
    }

    function test_SupplyAndBorrowHook_ReplaceCalldataAmounts() public view {
        bytes memory data = _encodeSupplyAndBorrowData(false, 500);
        uint256 newSupply = 2e18;
        uint256 newBorrow = 1e18;
        // SupplyAndBorrowHook has dual-amount: [supplyAmount, borrowAmount]
        bytes memory result = supplyAndBorrowHook.replaceCalldataAmounts(data, _dualAmounts(newSupply, newBorrow));
        assertEq(result.length, data.length);
        assertEq(supplyAndBorrowHook.decodeAmounts(result)[0], newSupply);
        assertEq(supplyAndBorrowHook.decodeAmounts(result)[1], newBorrow);
    }

    function testFuzz_SupplyAndBorrowHook_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeSupplyAndBorrowData(false, 500);
        // SupplyAndBorrowHook has dual-amount: [supplyAmount, borrowAmount]
        bytes memory result = supplyAndBorrowHook.replaceCalldataAmounts(data, _dualAmounts(fuzzAmount, 500));
        assertEq(supplyAndBorrowHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_RepayAndWithdrawHook_DecodeAmounts() public view {
        bytes memory data = _encodeRepayAndWithdrawData(false, false, 500);
        assertEq(repayAndWithdrawHook.decodeAmounts(data)[0], amount);
    }

    function test_RepayAndWithdrawHook_ReplaceCalldataAmounts() public view {
        bytes memory data = _encodeRepayAndWithdrawData(false, false, 500);
        uint256 newRepay = 2e18;
        uint256 newWithdraw = 1e18;
        // RepayAndWithdrawHook has dual-amount: [repayAmount, withdrawAmount]
        bytes memory result = repayAndWithdrawHook.replaceCalldataAmounts(data, _dualAmounts(newRepay, newWithdraw));
        assertEq(result.length, data.length);
        assertEq(repayAndWithdrawHook.decodeAmounts(result)[0], newRepay);
        assertEq(repayAndWithdrawHook.decodeAmounts(result)[1], newWithdraw);
    }

    function testFuzz_RepayAndWithdrawHook_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeRepayAndWithdrawData(false, false, 500);
        // RepayAndWithdrawHook has dual-amount: [repayAmount, withdrawAmount]
        bytes memory result = repayAndWithdrawHook.replaceCalldataAmounts(data, _dualAmounts(fuzzAmount, 500));
        assertEq(repayAndWithdrawHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_AaveV4Supply_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _encodeSupplyData(false);
        uint256 newAmount = 500;
        bytes memory replaced = supplyHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = supplyHook.build(address(0), address(this), replaced);
        assertEq(executions.length, 7);
        assertEq(supplyHook.decodeAmounts(replaced)[0], newAmount);
    }

    function test_AaveV4Withdraw_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _encodeWithdrawData(false);
        uint256 newAmount = 500;
        bytes memory replaced = withdrawHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = withdrawHook.build(address(0), address(this), replaced);
        assertEq(executions.length, 3);
        assertEq(withdrawHook.decodeAmounts(replaced)[0], newAmount);
    }

    /*//////////////////////////////////////////////////////////////
                         ENCODING HELPERS
    //////////////////////////////////////////////////////////////*/

    function _encodeSupplyData(bool usePrevHook) internal view returns (bytes memory) {
        return abi.encodePacked(
            address(loanToken), address(collateralToken), bytes12(0),
            loanToken, collateralToken, spoke, supplyReserveId, borrowReserveId, amount, usePrevHook
        );
    }

    function _encodeWithdrawData(bool usePrevHook) internal view returns (bytes memory) {
        return abi.encodePacked(
            address(loanToken), address(collateralToken), bytes12(0),
            loanToken, collateralToken, spoke, supplyReserveId, borrowReserveId, amount, usePrevHook
        );
    }

    function _encodeBorrowData(bool usePrevHook) internal view returns (bytes memory) {
        return abi.encodePacked(
            address(loanToken), address(collateralToken), bytes12(0),
            loanToken, collateralToken, spoke, supplyReserveId, borrowReserveId, amount, usePrevHook
        );
    }

    function _encodeRepayData(bool usePrevHook, bool isFullRepayment) internal view returns (bytes memory) {
        return abi.encodePacked(
            address(loanToken), address(collateralToken), bytes12(0),
            loanToken, collateralToken, spoke, supplyReserveId, borrowReserveId, amount, usePrevHook, isFullRepayment
        );
    }

    function _encodeSupplyAndBorrowData(
        bool usePrevHook,
        uint256 borrowAmt
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            address(loanToken), address(collateralToken), bytes12(0),
            loanToken, collateralToken, spoke, supplyReserveId, borrowReserveId, amount, usePrevHook, borrowAmt
        );
    }

    function _encodeRepayAndWithdrawData(
        bool usePrevHook,
        bool isFullRepayment,
        uint256 withdrawAmt
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            address(loanToken), address(collateralToken), bytes12(0),
            loanToken,
            collateralToken,
            spoke,
            supplyReserveId,
            borrowReserveId,
            amount,
            usePrevHook,
            isFullRepayment,
            withdrawAmt
        );
    }

    /*//////////////////////////////////////////////////////////////
                         GET OUT TOKEN TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SupplyHook_GetOutToken() public {
        bytes memory data = _encodeSupplyData(false);
        // deal collateral to account before supply
        deal(collateralToken, address(this), amount);
        supplyHook.preExecute(address(0), address(this), data);
        // simulate supply consuming collateral tokens
        deal(collateralToken, address(this), 0);
        supplyHook.postExecute(address(0), address(this), data);
        assertEq(supplyHook.getOutToken(address(this)), collateralToken);
    }

    function test_WithdrawHook_GetOutToken() public {
        bytes memory data = _encodeWithdrawData(false);
        // preExecute: collateralToken balance = 0
        withdrawHook.preExecute(address(0), address(this), data);
        // simulate withdraw receiving collateral tokens
        deal(collateralToken, address(this), amount);
        withdrawHook.postExecute(address(0), address(this), data);
        assertEq(withdrawHook.getOutToken(address(this)), collateralToken);
    }

    function test_BorrowHook_GetOutToken() public {
        bytes memory data = _encodeBorrowData(false);
        // preExecute: loanToken balance = 0
        borrowHook.preExecute(address(0), address(this), data);
        // simulate borrow receiving loan tokens
        deal(loanToken, address(this), amount);
        borrowHook.postExecute(address(0), address(this), data);
        assertEq(borrowHook.getOutToken(address(this)), loanToken);
    }

    function test_RepayHook_GetOutToken() public {
        bytes memory data = _encodeRepayData(false, false);
        // deal loan tokens to account before repay
        deal(loanToken, address(this), amount);
        repayHook.preExecute(address(0), address(this), data);
        // simulate repay consuming loan tokens
        deal(loanToken, address(this), 0);
        repayHook.postExecute(address(0), address(this), data);
        assertEq(repayHook.getOutToken(address(this)), loanToken);
    }

    function test_SupplyAndBorrowHook_GetOutToken() public {
        bytes memory data = _encodeSupplyAndBorrowData(false, borrowAmount);
        // deal collateral to account before supply
        deal(collateralToken, address(this), amount);
        supplyAndBorrowHook.preExecute(address(0), address(this), data);
        // simulate supply consuming collateral tokens
        deal(collateralToken, address(this), 0);
        supplyAndBorrowHook.postExecute(address(0), address(this), data);
        assertEq(supplyAndBorrowHook.getOutToken(address(this)), collateralToken);
    }

    function test_RepayAndWithdrawHook_GetOutToken() public {
        bytes memory data = _encodeRepayAndWithdrawData(false, false, withdrawAmount);
        // preExecute: collateralToken balance = 0
        repayAndWithdrawHook.preExecute(address(0), address(this), data);
        // simulate withdraw receiving collateral tokens back
        deal(collateralToken, address(this), amount);
        repayAndWithdrawHook.postExecute(address(0), address(this), data);
        assertEq(repayAndWithdrawHook.getOutToken(address(this)), collateralToken);
    }
}

/// @dev Helper interface for asserting approve calldata
interface IERC20Approve {
    function approve(address spender, uint256 amount) external returns (bool);
}
