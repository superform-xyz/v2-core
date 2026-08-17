// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { Helpers } from "../../../utils/Helpers.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { BytesLib } from "../../../../src/vendor/BytesLib.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ISuperHook, ISuperHookInflowOutflow } from "../../../../src/interfaces/ISuperHook.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Euler vendor
import { IEVC } from "../../../../src/vendor/euler/IEVC.sol";
import { IEVault } from "../../../../src/vendor/euler/IEVault.sol";

// Hooks
import { EulerDepositCollateralHook } from "../../../../src/hooks/loan/euler/EulerDepositCollateralHook.sol";
import { EulerBorrowHook } from "../../../../src/hooks/loan/euler/EulerBorrowHook.sol";
import { EulerRepayHook } from "../../../../src/hooks/loan/euler/EulerRepayHook.sol";
import { EulerWithdrawCollateralHook } from "../../../../src/hooks/loan/euler/EulerWithdrawCollateralHook.sol";
import {
    EulerDepositCollateralAndBorrowHook
} from "../../../../src/hooks/loan/euler/EulerDepositCollateralAndBorrowHook.sol";
import { EulerRepayAndWithdrawHook } from "../../../../src/hooks/loan/euler/EulerRepayAndWithdrawHook.sol";
import { BaseEulerLoanHook } from "../../../../src/hooks/loan/euler/BaseEulerLoanHook.sol";
import { HookSubTypes } from "../../../../src/libraries/HookSubTypes.sol";

/*//////////////////////////////////////////////////////////////
                            MOCKS
//////////////////////////////////////////////////////////////*/

contract MockEVC {
    mapping(address => address[]) internal _controllers;

    function setControllers(address account, address[] memory controllers_) external {
        _controllers[account] = controllers_;
    }

    function getControllers(address account) external view returns (address[] memory) {
        return _controllers[account];
    }

    function enableCollateral(address, address) external { }

    function enableController(address, address) external { }

    function disableCollateral(address, address) external { }

    function getCollaterals(address) external pure returns (address[] memory) {
        return new address[](0);
    }

    function isCollateralEnabled(address, address) external pure returns (bool) {
        return true;
    }

    function isControllerEnabled(address, address) external pure returns (bool) {
        return true;
    }
}

contract MockEVault {
    uint256 public _debtOf;
    address public _oracle;
    address public _unitOfAccount;
    address public _interestRateModel;
    uint256 public _collateralValue;
    uint256 public _liabilityValue;

    function setDebtOf(uint256 debt_) external {
        _debtOf = debt_;
    }

    function setOracle(address oracle_) external {
        _oracle = oracle_;
    }

    function setUnitOfAccount(address unit_) external {
        _unitOfAccount = unit_;
    }

    function setInterestRateModel(address irm_) external {
        _interestRateModel = irm_;
    }

    function setAccountLiquidity(uint256 collateral_, uint256 liability_) external {
        _collateralValue = collateral_;
        _liabilityValue = liability_;
    }

    function debtOf(address) external view returns (uint256) {
        return _debtOf;
    }

    function oracle() external view returns (address) {
        return _oracle;
    }

    function unitOfAccount() external view returns (address) {
        return _unitOfAccount;
    }

    function interestRateModel() external view returns (address) {
        return _interestRateModel;
    }

    function accountLiquidity(address, bool) external view returns (uint256, uint256) {
        return (_collateralValue, _liabilityValue);
    }

    function deposit(uint256, address) external pure returns (uint256) {
        return 0;
    }

    function withdraw(uint256, address, address) external pure returns (uint256) {
        return 0;
    }

    function borrow(uint256, address) external pure returns (uint256) {
        return 0;
    }

    function repay(uint256, address) external pure returns (uint256) {
        return 0;
    }

    function disableController() external { }
}

contract MockPrevHook {
    uint256 public storedOutAmount;

    function setOutAmount(uint256 _outAmount, address) external {
        storedOutAmount = _outAmount;
    }

    function getOutAmount(address) external view returns (uint256) {
        return storedOutAmount;
    }
}

/*//////////////////////////////////////////////////////////////
                          TEST CONTRACT
//////////////////////////////////////////////////////////////*/

contract EulerLoanHooksTest is Helpers {
    // Individual hooks
    EulerDepositCollateralHook public depositHook;
    EulerBorrowHook public borrowHook;
    EulerRepayHook public repayHook;
    EulerWithdrawCollateralHook public withdrawHook;

    // Composite hooks
    EulerDepositCollateralAndBorrowHook public depositAndBorrowHook;
    EulerRepayAndWithdrawHook public repayAndWithdrawHook;

    // Mocks
    MockEVC public mockEVC;
    MockEVault public mockCollateralVault;
    MockEVault public mockControllerVault;
    MockERC20 public mockDebtAsset;
    MockERC20 public mockCollateralAsset;
    MockPrevHook public mockPrevHook;

    // Test addresses
    address public collateralVault;
    address public controllerVault;
    address public evc;
    address public debtAsset;
    address public collateralAsset;
    address public expectedOracle;
    address public expectedUnitOfAccount;
    address public expectedIRM;

    uint256 public amount = 1e18;
    uint256 public borrowAmount = 5e17;

    function setUp() public {
        // Deploy mocks
        mockEVC = new MockEVC();
        mockCollateralVault = new MockEVault();
        mockControllerVault = new MockEVault();
        mockDebtAsset = new MockERC20("Debt Token", "DEBT", 18);
        mockCollateralAsset = new MockERC20("Collateral Token", "COLL", 18);
        mockPrevHook = new MockPrevHook();

        // Set addresses
        evc = address(mockEVC);
        collateralVault = address(mockCollateralVault);
        controllerVault = address(mockControllerVault);
        debtAsset = address(mockDebtAsset);
        collateralAsset = address(mockCollateralAsset);

        // Config validation addresses
        expectedOracle = makeAddr("oracle");
        expectedUnitOfAccount = makeAddr("unitOfAccount");
        expectedIRM = makeAddr("irm");

        // Configure mock controller vault
        mockControllerVault.setOracle(expectedOracle);
        mockControllerVault.setUnitOfAccount(expectedUnitOfAccount);
        mockControllerVault.setInterestRateModel(expectedIRM);
        mockControllerVault.setDebtOf(10e18);
        mockControllerVault.setAccountLiquidity(100e18, 50e18);

        // Deploy hooks
        depositHook = new EulerDepositCollateralHook();
        borrowHook = new EulerBorrowHook();
        repayHook = new EulerRepayHook();
        withdrawHook = new EulerWithdrawCollateralHook();
        depositAndBorrowHook = new EulerDepositCollateralAndBorrowHook();
        repayAndWithdrawHook = new EulerRepayAndWithdrawHook();
    }

    /*//////////////////////////////////////////////////////////////
                            ENCODERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Encode shared prefix (197 bytes minimum)
    function _encodeSharedPrefix(
        uint256 primaryAmt,
        uint256 secondaryAmt,
        bool usePrev
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            bytes32(0), // configId
            bytes20(uint160(collateralVault)), // collateralVault at offset 32
            bytes20(uint160(debtAsset)), // debtAsset at offset 52
            bytes20(uint160(collateralAsset)), // collateralAsset at offset 72
            bytes20(uint160(evc)), // evc at offset 92
            bytes20(uint160(controllerVault)), // controllerVault at offset 112
            primaryAmt, // primaryAmount at offset 132
            secondaryAmt, // secondaryAmount at offset 164
            usePrev // usePrevHookAmount at offset 196
        );
    }

    /// @dev Encode deposit data (minimal shared prefix)
    function _encodeDepositData(uint256 amt, bool usePrev) internal view returns (bytes memory) {
        return _encodeSharedPrefix(amt, 0, usePrev);
    }

    /// @dev Encode borrow data
    function _encodeBorrowData(uint256 amt, bool usePrev) internal view returns (bytes memory) {
        return _encodeSharedPrefix(amt, 0, usePrev);
    }

    /// @dev Encode repay data
    function _encodeRepayData(uint256 amt, bool usePrev, bool isFullRepayment) internal view returns (bytes memory) {
        return abi.encodePacked(_encodeSharedPrefix(amt, 0, usePrev), isFullRepayment);
    }

    /// @dev Encode withdraw data
    function _encodeWithdrawData(uint256 amt, bool usePrev) internal view returns (bytes memory) {
        return _encodeSharedPrefix(amt, 0, usePrev);
    }

    /// @dev Encode deposit+borrow composite data (321 bytes minimum)
    function _encodeDepositAndBorrowData(
        uint256 primaryAmt,
        uint256 secondaryAmt,
        bool usePrev,
        uint256 maxPostDebt,
        uint256 maxLiqCapUtilBps
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            _encodeSharedPrefix(primaryAmt, secondaryAmt, usePrev),
            maxPostDebt, // offset 197
            maxLiqCapUtilBps, // offset 229
            bytes20(uint160(expectedOracle)), // offset 261
            bytes20(uint160(expectedUnitOfAccount)), // offset 281
            bytes20(uint160(expectedIRM)) // offset 301
        );
    }

    /// @dev Encode repay+withdraw composite data (354 bytes minimum)
    function _encodeRepayAndWithdrawData(
        uint256 primaryAmt,
        uint256 secondaryAmt,
        bool usePrev,
        bool isFullRepayment,
        uint256 maxRepayAssets,
        uint256 maxCollateralRelease,
        uint256 maxRemainingLiqCapUtilBps
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            _encodeSharedPrefix(primaryAmt, secondaryAmt, usePrev),
            isFullRepayment, // offset 197
            maxRepayAssets, // offset 198
            maxCollateralRelease, // offset 230
            maxRemainingLiqCapUtilBps, // offset 262
            bytes20(uint160(expectedOracle)), // offset 294
            bytes20(uint160(expectedUnitOfAccount)), // offset 314
            bytes20(uint160(expectedIRM)) // offset 334
        );
    }

    /*//////////////////////////////////////////////////////////////
                          CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Constructors() public view {
        // All hooks should be NONACCOUNTING type
        assertEq(uint256(depositHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(borrowHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(repayHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(withdrawHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(depositAndBorrowHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(repayAndWithdrawHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));

        // Subtypes
        assertEq(depositHook.subtype(), HookSubTypes.LOAN);
        assertEq(borrowHook.subtype(), HookSubTypes.LOAN);
        assertEq(depositAndBorrowHook.subtype(), HookSubTypes.LOAN);
        assertEq(repayHook.subtype(), HookSubTypes.LOAN_REPAY);
        assertEq(withdrawHook.subtype(), HookSubTypes.LOAN_REPAY);
        assertEq(repayAndWithdrawHook.subtype(), HookSubTypes.LOAN_REPAY);
    }

    function test_Names() public view {
        assertEq(depositHook.name(), "Euler Deposit Collateral");
        assertEq(borrowHook.name(), "Euler Borrow");
        assertEq(repayHook.name(), "Euler Repay");
        assertEq(withdrawHook.name(), "Euler Withdraw Collateral");
        assertEq(depositAndBorrowHook.name(), "Euler Deposit Collateral and Borrow");
        assertEq(repayAndWithdrawHook.name(), "Euler Repay and Withdraw");
    }

    function test_Descriptions() public view {
        assertGt(bytes(depositHook.description()).length, 0);
        assertGt(bytes(borrowHook.description()).length, 0);
        assertGt(bytes(repayHook.description()).length, 0);
        assertGt(bytes(withdrawHook.description()).length, 0);
        assertGt(bytes(depositAndBorrowHook.description()).length, 0);
        assertGt(bytes(repayAndWithdrawHook.description()).length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    EULER DEPOSIT COLLATERAL HOOK
    //////////////////////////////////////////////////////////////*/

    function test_DepositHook_Build() public view {
        bytes memory data = _encodeDepositData(amount, false);
        Execution[] memory executions = depositHook.build(address(0), address(this), data);

        // 4 inner executions: approve(0), approve(N), deposit, approve(0)
        // + preExecute + postExecute = 6
        assertEq(executions.length, 6);

        // approve(0)
        assertEq(executions[1].target, collateralAsset);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (collateralVault, 0)));

        // approve(amount)
        assertEq(executions[2].target, collateralAsset);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (collateralVault, amount)));

        // deposit
        assertEq(executions[3].target, collateralVault);
        assertEq(executions[3].callData, abi.encodeCall(IEVault.deposit, (amount, address(this))));

        // approve(0) reset
        assertEq(executions[4].target, collateralAsset);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (collateralVault, 0)));
    }

    function test_DepositHook_Build_UsePrevHookAmount() public {
        uint256 prevAmount = 2e18;
        mockPrevHook.setOutAmount(prevAmount, address(this));

        bytes memory data = _encodeDepositData(amount, true);
        Execution[] memory executions = depositHook.build(address(mockPrevHook), address(this), data);

        assertEq(executions.length, 6);
        // approve(prevAmount)
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (collateralVault, prevAmount)));
        // deposit(prevAmount)
        assertEq(executions[3].callData, abi.encodeCall(IEVault.deposit, (prevAmount, address(this))));
    }

    function test_DepositHook_Build_RevertIf_ZeroAmount() public {
        bytes memory data = _encodeDepositData(0, false);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        depositHook.build(address(0), address(this), data);
    }

    function test_DepositHook_Build_RevertIf_ZeroCollateralVault() public {
        bytes memory data = abi.encodePacked(
            bytes32(0),
            bytes20(0), // zero collateralVault
            bytes20(uint160(debtAsset)),
            bytes20(uint160(collateralAsset)),
            bytes20(uint160(evc)),
            bytes20(uint160(controllerVault)),
            amount,
            uint256(0),
            false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        depositHook.build(address(0), address(this), data);
    }

    function test_DepositHook_Build_RevertIf_InvalidDataLength() public {
        bytes memory shortData = abi.encodePacked(debtAsset, collateralAsset); // 40 bytes
        vm.expectRevert(BaseEulerLoanHook.INVALID_DATA_LENGTH.selector);
        depositHook.build(address(0), address(this), shortData);
    }

    function test_DepositHook_Inspector() public view {
        bytes memory data = _encodeDepositData(amount, false);
        bytes memory result = depositHook.inspect(data);
        assertEq(result, abi.encodePacked(collateralVault, evc, controllerVault));
    }

    function test_DepositHook_PrePostExecute() public {
        bytes memory data = _encodeDepositData(amount, false);

        // Deal collateral to account
        deal(collateralAsset, address(this), 100e18);

        depositHook.preExecute(address(0), address(this), data);
        assertEq(depositHook.getOutAmount(address(this)), 100e18);

        // Simulate deposit consuming 50e18 collateral
        deal(collateralAsset, address(this), 50e18);

        depositHook.postExecute(address(0), address(this), data);
        assertEq(depositHook.getOutAmount(address(this)), 50e18);
    }

    function test_DepositHook_GetOutToken() public {
        bytes memory data = _encodeDepositData(amount, false);
        deal(collateralAsset, address(this), amount);
        depositHook.preExecute(address(0), address(this), data);
        deal(collateralAsset, address(this), 0);
        depositHook.postExecute(address(0), address(this), data);
        assertEq(depositHook.getOutToken(address(this)), collateralAsset);
    }

    /*//////////////////////////////////////////////////////////////
                        EULER BORROW HOOK
    //////////////////////////////////////////////////////////////*/

    function test_BorrowHook_Build() public view {
        bytes memory data = _encodeBorrowData(amount, false);
        Execution[] memory executions = borrowHook.build(address(0), address(this), data);

        // 3 inner executions + pre + post = 5
        assertEq(executions.length, 5);

        // enableCollateral
        assertEq(executions[1].target, evc);
        assertEq(executions[1].callData, abi.encodeCall(IEVC.enableCollateral, (address(this), collateralVault)));

        // enableController
        assertEq(executions[2].target, evc);
        assertEq(executions[2].callData, abi.encodeCall(IEVC.enableController, (address(this), controllerVault)));

        // borrow
        assertEq(executions[3].target, controllerVault);
        assertEq(executions[3].callData, abi.encodeCall(IEVault.borrow, (amount, address(this))));
    }

    function test_BorrowHook_Build_UsePrevHookAmount() public {
        uint256 prevAmount = 3e18;
        mockPrevHook.setOutAmount(prevAmount, address(this));

        bytes memory data = _encodeBorrowData(amount, true);
        Execution[] memory executions = borrowHook.build(address(mockPrevHook), address(this), data);

        assertEq(executions.length, 5);
        assertEq(executions[3].callData, abi.encodeCall(IEVault.borrow, (prevAmount, address(this))));
    }

    function test_BorrowHook_Build_RevertIf_ZeroAmount() public {
        bytes memory data = _encodeBorrowData(0, false);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        borrowHook.build(address(0), address(this), data);
    }

    function test_BorrowHook_Build_RevertIf_ControllerAlreadySet() public {
        // Set a different controller for the account
        address[] memory controllers = new address[](1);
        controllers[0] = makeAddr("otherController");
        mockEVC.setControllers(address(this), controllers);

        bytes memory data = _encodeBorrowData(amount, false);
        vm.expectRevert(BaseEulerLoanHook.CONTROLLER_ALREADY_SET.selector);
        borrowHook.build(address(0), address(this), data);
    }

    function test_BorrowHook_Build_NoRevert_SameControllerAlreadySet() public {
        // Set the SAME controller — should not revert
        address[] memory controllers = new address[](1);
        controllers[0] = controllerVault;
        mockEVC.setControllers(address(this), controllers);

        bytes memory data = _encodeBorrowData(amount, false);
        Execution[] memory executions = borrowHook.build(address(0), address(this), data);
        assertEq(executions.length, 5);
    }

    function test_BorrowHook_Build_RevertIf_ZeroEVC() public {
        bytes memory data = abi.encodePacked(
            bytes32(0),
            bytes20(uint160(collateralVault)),
            bytes20(uint160(debtAsset)),
            bytes20(uint160(collateralAsset)),
            bytes20(0), // zero evc
            bytes20(uint160(controllerVault)),
            amount,
            uint256(0),
            false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        borrowHook.build(address(0), address(this), data);
    }

    function test_BorrowHook_Build_RevertIf_InvalidDataLength() public {
        bytes memory shortData = abi.encodePacked(bytes32(0), bytes20(0));
        vm.expectRevert(BaseEulerLoanHook.INVALID_DATA_LENGTH.selector);
        borrowHook.build(address(0), address(this), shortData);
    }

    function test_BorrowHook_Inspector() public view {
        bytes memory data = _encodeBorrowData(amount, false);
        bytes memory result = borrowHook.inspect(data);
        assertEq(result, abi.encodePacked(collateralVault, evc, controllerVault));
    }

    function test_BorrowHook_PrePostExecute() public {
        bytes memory data = _encodeBorrowData(amount, false);

        // Pre-execute: no debtAsset balance
        borrowHook.preExecute(address(0), address(this), data);
        assertEq(borrowHook.getOutAmount(address(this)), 0);

        // Simulate receiving borrowed tokens
        deal(debtAsset, address(this), amount);

        borrowHook.postExecute(address(0), address(this), data);
        assertEq(borrowHook.getOutAmount(address(this)), amount);
    }

    function test_BorrowHook_GetOutToken() public {
        bytes memory data = _encodeBorrowData(amount, false);
        borrowHook.preExecute(address(0), address(this), data);
        deal(debtAsset, address(this), amount);
        borrowHook.postExecute(address(0), address(this), data);
        assertEq(borrowHook.getOutToken(address(this)), debtAsset);
    }

    /*//////////////////////////////////////////////////////////////
                        EULER REPAY HOOK
    //////////////////////////////////////////////////////////////*/

    function test_RepayHook_Build_Partial() public view {
        bytes memory data = _encodeRepayData(amount, false, false);
        Execution[] memory executions = repayHook.build(address(0), address(this), data);

        // 4 inner + pre + post = 6
        assertEq(executions.length, 6);

        // approve(0)
        assertEq(executions[1].target, debtAsset);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (controllerVault, 0)));

        // approve(amount)
        assertEq(executions[2].target, debtAsset);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (controllerVault, amount)));

        // repay
        assertEq(executions[3].target, controllerVault);
        assertEq(executions[3].callData, abi.encodeCall(IEVault.repay, (amount, address(this))));

        // approve(0) reset
        assertEq(executions[4].target, debtAsset);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (controllerVault, 0)));
    }

    function test_RepayHook_Build_Full() public view {
        bytes memory data = _encodeRepayData(0, false, true);
        Execution[] memory executions = repayHook.build(address(0), address(this), data);

        // Full: 6 inner + pre + post = 8
        assertEq(executions.length, 8);

        // approve(0)
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (controllerVault, 0)));

        // approve(type(uint256).max) for full repay
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (controllerVault, type(uint256).max)));

        // repay(type(uint256).max) — EVault calculates exact debt atomically
        assertEq(executions[3].callData, abi.encodeCall(IEVault.repay, (type(uint256).max, address(this))));

        // approve(0) reset
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (controllerVault, 0)));

        // disableController()
        assertEq(executions[5].target, controllerVault);
        assertEq(executions[5].callData, abi.encodeCall(IEVault.disableController, ()));

        // disableCollateral() cleanup
        assertEq(executions[6].target, evc);
        assertEq(executions[6].callData, abi.encodeCall(IEVC.disableCollateral, (address(this), collateralVault)));
    }

    function test_RepayHook_Build_Full_RevertIf_ZeroDebt() public {
        mockControllerVault.setDebtOf(0);
        bytes memory data = _encodeRepayData(0, false, true);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        repayHook.build(address(0), address(this), data);
    }

    function test_RepayHook_Build_RevertIf_ZeroAmount() public {
        bytes memory data = _encodeRepayData(0, false, false);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        repayHook.build(address(0), address(this), data);
    }

    function test_RepayHook_Build_UsePrevHookAmount() public {
        uint256 prevAmount = 5e18;
        mockPrevHook.setOutAmount(prevAmount, address(this));

        bytes memory data = _encodeRepayData(0, true, false);
        Execution[] memory executions = repayHook.build(address(mockPrevHook), address(this), data);

        assertEq(executions.length, 6);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (controllerVault, prevAmount)));
    }

    function test_RepayHook_Build_RevertIf_InvalidDataLength() public {
        bytes memory shortData = new bytes(100);
        vm.expectRevert(BaseEulerLoanHook.INVALID_DATA_LENGTH.selector);
        repayHook.build(address(0), address(this), shortData);
    }

    function test_RepayHook_Inspector() public view {
        bytes memory data = _encodeRepayData(amount, false, false);
        bytes memory result = repayHook.inspect(data);
        assertEq(result, abi.encodePacked(collateralVault, evc, controllerVault));
    }

    function test_RepayHook_PrePostExecute() public {
        bytes memory data = _encodeRepayData(amount, false, false);

        // Deal debtAsset to account
        deal(debtAsset, address(this), 100e18);

        repayHook.preExecute(address(0), address(this), data);
        assertEq(repayHook.getOutAmount(address(this)), 100e18);

        // Simulate repay consuming 50e18
        deal(debtAsset, address(this), 50e18);

        repayHook.postExecute(address(0), address(this), data);
        assertEq(repayHook.getOutAmount(address(this)), 50e18);
    }

    function test_RepayHook_GetOutToken() public {
        bytes memory data = _encodeRepayData(amount, false, false);
        deal(debtAsset, address(this), amount);
        repayHook.preExecute(address(0), address(this), data);
        deal(debtAsset, address(this), 0);
        repayHook.postExecute(address(0), address(this), data);
        assertEq(repayHook.getOutToken(address(this)), debtAsset);
    }

    /*//////////////////////////////////////////////////////////////
                    EULER WITHDRAW COLLATERAL HOOK
    //////////////////////////////////////////////////////////////*/

    function test_WithdrawHook_Build() public view {
        bytes memory data = _encodeWithdrawData(amount, false);
        Execution[] memory executions = withdrawHook.build(address(0), address(this), data);

        // 1 inner + pre + post = 3
        assertEq(executions.length, 3);

        // withdraw
        assertEq(executions[1].target, collateralVault);
        assertEq(
            executions[1].callData, abi.encodeCall(IEVault.withdraw, (amount, address(this), address(this)))
        );
    }

    function test_WithdrawHook_Build_UsePrevHookAmount() public {
        uint256 prevAmount = 7e18;
        mockPrevHook.setOutAmount(prevAmount, address(this));

        bytes memory data = _encodeWithdrawData(amount, true);
        Execution[] memory executions = withdrawHook.build(address(mockPrevHook), address(this), data);

        assertEq(executions.length, 3);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IEVault.withdraw, (prevAmount, address(this), address(this)))
        );
    }

    function test_WithdrawHook_Build_RevertIf_ZeroAmount() public {
        bytes memory data = _encodeWithdrawData(0, false);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        withdrawHook.build(address(0), address(this), data);
    }

    function test_WithdrawHook_Build_RevertIf_InvalidDataLength() public {
        bytes memory shortData = new bytes(50);
        vm.expectRevert(BaseEulerLoanHook.INVALID_DATA_LENGTH.selector);
        withdrawHook.build(address(0), address(this), shortData);
    }

    function test_WithdrawHook_Inspector() public view {
        bytes memory data = _encodeWithdrawData(amount, false);
        bytes memory result = withdrawHook.inspect(data);
        assertEq(result, abi.encodePacked(collateralVault, evc, controllerVault));
    }

    function test_WithdrawHook_PrePostExecute() public {
        bytes memory data = _encodeWithdrawData(amount, false);

        // Pre-execute: no collateral
        withdrawHook.preExecute(address(0), address(this), data);
        assertEq(withdrawHook.getOutAmount(address(this)), 0);

        // Simulate receiving collateral
        deal(collateralAsset, address(this), amount);

        withdrawHook.postExecute(address(0), address(this), data);
        assertEq(withdrawHook.getOutAmount(address(this)), amount);
    }

    function test_WithdrawHook_GetOutToken() public {
        bytes memory data = _encodeWithdrawData(amount, false);
        withdrawHook.preExecute(address(0), address(this), data);
        deal(collateralAsset, address(this), amount);
        withdrawHook.postExecute(address(0), address(this), data);
        assertEq(withdrawHook.getOutToken(address(this)), collateralAsset);
    }

    /*//////////////////////////////////////////////////////////////
              EULER DEPOSIT COLLATERAL AND BORROW HOOK
    //////////////////////////////////////////////////////////////*/

    function test_DepositAndBorrowHook_Build() public view {
        bytes memory data = _encodeDepositAndBorrowData(amount, borrowAmount, false, 100e18, 5000);
        Execution[] memory executions = depositAndBorrowHook.build(address(0), address(this), data);

        // 7 inner + pre + post = 9
        assertEq(executions.length, 9);

        // approve(0)
        assertEq(executions[1].target, collateralAsset);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (collateralVault, 0)));

        // approve(primaryAmount)
        assertEq(executions[2].target, collateralAsset);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (collateralVault, amount)));

        // deposit
        assertEq(executions[3].target, collateralVault);
        assertEq(executions[3].callData, abi.encodeCall(IEVault.deposit, (amount, address(this))));

        // enableCollateral
        assertEq(executions[4].target, evc);
        assertEq(
            executions[4].callData, abi.encodeCall(IEVC.enableCollateral, (address(this), collateralVault))
        );

        // enableController
        assertEq(executions[5].target, evc);
        assertEq(
            executions[5].callData, abi.encodeCall(IEVC.enableController, (address(this), controllerVault))
        );

        // borrow
        assertEq(executions[6].target, controllerVault);
        assertEq(executions[6].callData, abi.encodeCall(IEVault.borrow, (borrowAmount, address(this))));

        // approve(0) reset
        assertEq(executions[7].target, collateralAsset);
        assertEq(executions[7].callData, abi.encodeCall(IERC20.approve, (collateralVault, 0)));
    }

    function test_DepositAndBorrowHook_Build_RevertIf_UsePrevHookAmount() public {
        bytes memory data = _encodeDepositAndBorrowData(amount, borrowAmount, true, 100e18, 0);
        vm.expectRevert(EulerDepositCollateralAndBorrowHook.USE_PREV_HOOK_AMOUNT_NOT_SUPPORTED.selector);
        depositAndBorrowHook.build(address(0), address(this), data);
    }

    function test_DepositAndBorrowHook_Build_RevertIf_ZeroPrimaryAmount() public {
        bytes memory data = _encodeDepositAndBorrowData(0, borrowAmount, false, 100e18, 0);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        depositAndBorrowHook.build(address(0), address(this), data);
    }

    function test_DepositAndBorrowHook_Build_RevertIf_ZeroSecondaryAmount() public {
        bytes memory data = _encodeDepositAndBorrowData(amount, 0, false, 100e18, 0);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        depositAndBorrowHook.build(address(0), address(this), data);
    }

    function test_DepositAndBorrowHook_Build_RevertIf_ControllerAlreadySet() public {
        address[] memory controllers = new address[](1);
        controllers[0] = makeAddr("otherController");
        mockEVC.setControllers(address(this), controllers);

        bytes memory data = _encodeDepositAndBorrowData(amount, borrowAmount, false, 100e18, 0);
        vm.expectRevert(BaseEulerLoanHook.CONTROLLER_ALREADY_SET.selector);
        depositAndBorrowHook.build(address(0), address(this), data);
    }

    function test_DepositAndBorrowHook_Build_RevertIf_OracleMismatch() public {
        mockControllerVault.setOracle(makeAddr("wrongOracle"));
        bytes memory data = _encodeDepositAndBorrowData(amount, borrowAmount, false, 100e18, 0);
        vm.expectRevert(EulerDepositCollateralAndBorrowHook.ORACLE_MISMATCH.selector);
        depositAndBorrowHook.build(address(0), address(this), data);
    }

    function test_DepositAndBorrowHook_Build_RevertIf_UnitOfAccountMismatch() public {
        mockControllerVault.setUnitOfAccount(makeAddr("wrongUnit"));
        bytes memory data = _encodeDepositAndBorrowData(amount, borrowAmount, false, 100e18, 0);
        vm.expectRevert(EulerDepositCollateralAndBorrowHook.UNIT_OF_ACCOUNT_MISMATCH.selector);
        depositAndBorrowHook.build(address(0), address(this), data);
    }

    function test_DepositAndBorrowHook_Build_RevertIf_IRMMismatch() public {
        mockControllerVault.setInterestRateModel(makeAddr("wrongIRM"));
        bytes memory data = _encodeDepositAndBorrowData(amount, borrowAmount, false, 100e18, 0);
        vm.expectRevert(EulerDepositCollateralAndBorrowHook.IRM_MISMATCH.selector);
        depositAndBorrowHook.build(address(0), address(this), data);
    }

    function test_DepositAndBorrowHook_Build_RevertIf_InvalidDataLength() public {
        bytes memory shortData = new bytes(200);
        vm.expectRevert(BaseEulerLoanHook.INVALID_DATA_LENGTH.selector);
        depositAndBorrowHook.build(address(0), address(this), shortData);
    }

    function test_DepositAndBorrowHook_Build_RevertIf_ZeroAddress() public {
        // Zero collateralVault
        bytes memory data = abi.encodePacked(
            bytes32(0),
            bytes20(0), // zero collateralVault
            bytes20(uint160(debtAsset)),
            bytes20(uint160(collateralAsset)),
            bytes20(uint160(evc)),
            bytes20(uint160(controllerVault)),
            amount,
            borrowAmount,
            false,
            uint256(100e18),
            uint256(0),
            bytes20(uint160(expectedOracle)),
            bytes20(uint160(expectedUnitOfAccount)),
            bytes20(uint160(expectedIRM))
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        depositAndBorrowHook.build(address(0), address(this), data);
    }

    function test_DepositAndBorrowHook_Inspector() public view {
        bytes memory data = _encodeDepositAndBorrowData(amount, borrowAmount, false, 100e18, 0);
        bytes memory result = depositAndBorrowHook.inspect(data);
        assertEq(result, abi.encodePacked(collateralVault, evc, controllerVault));
    }

    function test_DepositAndBorrowHook_DecodeAmounts() public view {
        bytes memory data = _encodeDepositAndBorrowData(amount, borrowAmount, false, 100e18, 0);
        uint256[] memory amounts = depositAndBorrowHook.decodeAmounts(data);
        assertEq(amounts.length, 2);
        assertEq(amounts[0], amount);
        assertEq(amounts[1], borrowAmount);
    }

    function test_DepositAndBorrowHook_ReplaceCalldataAmounts() public view {
        bytes memory data = _encodeDepositAndBorrowData(amount, borrowAmount, false, 100e18, 0);
        uint256 newPrimary = 2e18;
        uint256 newSecondary = 1e18;
        bytes memory result = depositAndBorrowHook.replaceCalldataAmounts(data, _dualAmounts(newPrimary, newSecondary));
        uint256[] memory decoded = depositAndBorrowHook.decodeAmounts(result);
        assertEq(decoded[0], newPrimary);
        assertEq(decoded[1], newSecondary);
    }

    function testFuzz_DepositAndBorrowHook_ReplaceCalldataAmounts(uint256 a, uint256 b) public view {
        vm.assume(a > 0 && b > 0);
        bytes memory data = _encodeDepositAndBorrowData(amount, borrowAmount, false, 100e18, 0);
        bytes memory result = depositAndBorrowHook.replaceCalldataAmounts(data, _dualAmounts(a, b));
        uint256[] memory decoded = depositAndBorrowHook.decodeAmounts(result);
        assertEq(decoded[0], a);
        assertEq(decoded[1], b);
    }

    function test_DepositAndBorrowHook_AmountRoles() public view {
        bytes memory data = _encodeDepositAndBorrowData(amount, borrowAmount, false, 100e18, 0);
        ISuperHookInflowOutflow.AmountMeta[] memory meta = depositAndBorrowHook.amountRoles(data);
        assertEq(meta.length, 2);
    }

    function test_DepositAndBorrowHook_PostExecute_MaxPostDebtExceeded() public {
        bytes memory data = _encodeDepositAndBorrowData(amount, borrowAmount, false, 5e18, 0);
        // debtOf returns 10e18 which exceeds maxPostDebt of 5e18

        depositAndBorrowHook.preExecute(address(0), address(this), data);
        deal(debtAsset, address(this), borrowAmount);

        vm.expectRevert(EulerDepositCollateralAndBorrowHook.MAX_POST_DEBT_EXCEEDED.selector);
        depositAndBorrowHook.postExecute(address(0), address(this), data);
    }

    function test_DepositAndBorrowHook_PostExecute_LiqCapExceeded() public {
        // Set high liability relative to collateral (liability=90, collateral=100)
        mockControllerVault.setAccountLiquidity(100e18, 90e18);

        // maxLiqCapUtilBps = 5000 (50%), but liability/collateral = 90% > 50%
        bytes memory data = _encodeDepositAndBorrowData(amount, borrowAmount, false, 100e18, 5000);

        depositAndBorrowHook.preExecute(address(0), address(this), data);
        deal(debtAsset, address(this), borrowAmount);

        vm.expectRevert(EulerDepositCollateralAndBorrowHook.LIQUIDATION_CAPACITY_EXCEEDED.selector);
        depositAndBorrowHook.postExecute(address(0), address(this), data);
    }

    function test_DepositAndBorrowHook_PrePostExecute() public {
        bytes memory data = _encodeDepositAndBorrowData(amount, borrowAmount, false, 100e18, 0);

        // Pre: no debtAsset
        depositAndBorrowHook.preExecute(address(0), address(this), data);
        assertEq(depositAndBorrowHook.getOutAmount(address(this)), 0);

        // Simulate receiving borrowed tokens
        deal(debtAsset, address(this), borrowAmount);

        depositAndBorrowHook.postExecute(address(0), address(this), data);
        assertEq(depositAndBorrowHook.getOutAmount(address(this)), borrowAmount);
    }

    function test_DepositAndBorrowHook_GetOutToken() public {
        bytes memory data = _encodeDepositAndBorrowData(amount, borrowAmount, false, 100e18, 0);
        depositAndBorrowHook.preExecute(address(0), address(this), data);
        deal(debtAsset, address(this), borrowAmount);
        depositAndBorrowHook.postExecute(address(0), address(this), data);
        assertEq(depositAndBorrowHook.getOutToken(address(this)), debtAsset);
    }

    /*//////////////////////////////////////////////////////////////
                  EULER REPAY AND WITHDRAW HOOK
    //////////////////////////////////////////////////////////////*/

    function test_RepayAndWithdrawHook_Build_PartialRepayAndWithdraw() public view {
        bytes memory data = _encodeRepayAndWithdrawData(amount, borrowAmount, false, false, amount, borrowAmount, 0);
        Execution[] memory executions = repayAndWithdrawHook.build(address(0), address(this), data);

        // 5 inner + pre + post = 7
        assertEq(executions.length, 7);

        // approve(0)
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (controllerVault, 0)));
        // approve(primaryAmount)
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (controllerVault, amount)));
        // repay
        assertEq(executions[3].callData, abi.encodeCall(IEVault.repay, (amount, address(this))));
        // approve(0) reset
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (controllerVault, 0)));
        // withdraw
        assertEq(executions[5].target, collateralVault);
        assertEq(
            executions[5].callData,
            abi.encodeCall(IEVault.withdraw, (borrowAmount, address(this), address(this)))
        );
    }

    function test_RepayAndWithdrawHook_Build_RepayOnly() public view {
        // secondaryAmount = 0 → repay-only path
        bytes memory data = _encodeRepayAndWithdrawData(amount, 0, false, false, amount, 0, 0);
        Execution[] memory executions = repayAndWithdrawHook.build(address(0), address(this), data);

        // 4 inner + pre + post = 6
        assertEq(executions.length, 6);

        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (controllerVault, 0)));
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (controllerVault, amount)));
        assertEq(executions[3].callData, abi.encodeCall(IEVault.repay, (amount, address(this))));
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (controllerVault, 0)));
    }

    function test_RepayAndWithdrawHook_Build_FullRepayAndWithdraw() public view {
        // isFullRepayment = true, secondaryAmount > 0
        bytes memory data = _encodeRepayAndWithdrawData(0, borrowAmount, false, true, type(uint256).max, borrowAmount, 0);
        Execution[] memory executions = repayAndWithdrawHook.build(address(0), address(this), data);

        // 8 inner + pre + post = 10 (full repay + withdraw + disableController + disableCollateral + approve reset)
        assertEq(executions.length, 10);

        // approve(0)
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (controllerVault, 0)));
        // approve(type(uint256).max) for full repay
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (controllerVault, type(uint256).max)));
        // repay(type(uint256).max) — EVault calculates exact debt atomically
        assertEq(executions[3].callData, abi.encodeCall(IEVault.repay, (type(uint256).max, address(this))));
        // approve(0) reset
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (controllerVault, 0)));
        // withdraw
        assertEq(
            executions[5].callData,
            abi.encodeCall(IEVault.withdraw, (borrowAmount, address(this), address(this)))
        );
        // disableController
        assertEq(executions[6].target, controllerVault);
        assertEq(executions[6].callData, abi.encodeCall(IEVault.disableController, ()));
        // disableCollateral cleanup
        assertEq(executions[7].target, evc);
        assertEq(executions[7].callData, abi.encodeCall(IEVC.disableCollateral, (address(this), collateralVault)));
        // approve(0) belt-and-suspenders reset
        assertEq(executions[8].callData, abi.encodeCall(IERC20.approve, (controllerVault, 0)));
    }

    function test_RepayAndWithdrawHook_Build_RevertIf_UsePrevHookAmount() public {
        bytes memory data = _encodeRepayAndWithdrawData(amount, borrowAmount, true, false, amount, borrowAmount, 0);
        vm.expectRevert(EulerRepayAndWithdrawHook.USE_PREV_HOOK_AMOUNT_NOT_SUPPORTED.selector);
        repayAndWithdrawHook.build(address(0), address(this), data);
    }

    function test_RepayAndWithdrawHook_Build_RevertIf_ZeroRepayAmount() public {
        bytes memory data = _encodeRepayAndWithdrawData(0, borrowAmount, false, false, 0, borrowAmount, 0);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        repayAndWithdrawHook.build(address(0), address(this), data);
    }

    function test_RepayAndWithdrawHook_Build_RevertIf_MaxRepayExceeded() public {
        // primaryAmount (amount=1e18) > maxRepayAssets (0.5e18)
        bytes memory data = _encodeRepayAndWithdrawData(amount, 0, false, false, 5e17, 0, 0);
        vm.expectRevert(EulerRepayAndWithdrawHook.MAX_REPAY_EXCEEDED.selector);
        repayAndWithdrawHook.build(address(0), address(this), data);
    }

    function test_RepayAndWithdrawHook_Build_RevertIf_MaxCollateralReleaseExceeded() public {
        // secondaryAmount > maxCollateralReleaseAssets
        bytes memory data = _encodeRepayAndWithdrawData(amount, 10e18, false, false, amount, 5e18, 0);
        vm.expectRevert(EulerRepayAndWithdrawHook.MAX_COLLATERAL_RELEASE_EXCEEDED.selector);
        repayAndWithdrawHook.build(address(0), address(this), data);
    }

    function test_RepayAndWithdrawHook_Build_RevertIf_OracleMismatch() public {
        mockControllerVault.setOracle(makeAddr("wrongOracle"));
        bytes memory data = _encodeRepayAndWithdrawData(amount, borrowAmount, false, false, amount, borrowAmount, 0);
        vm.expectRevert(EulerRepayAndWithdrawHook.ORACLE_MISMATCH.selector);
        repayAndWithdrawHook.build(address(0), address(this), data);
    }

    function test_RepayAndWithdrawHook_Build_RevertIf_InvalidDataLength() public {
        bytes memory shortData = new bytes(200);
        vm.expectRevert(BaseEulerLoanHook.INVALID_DATA_LENGTH.selector);
        repayAndWithdrawHook.build(address(0), address(this), shortData);
    }

    function test_RepayAndWithdrawHook_Inspector() public view {
        bytes memory data = _encodeRepayAndWithdrawData(amount, borrowAmount, false, false, amount, borrowAmount, 0);
        bytes memory result = repayAndWithdrawHook.inspect(data);
        assertEq(result, abi.encodePacked(collateralVault, evc, controllerVault));
    }

    function test_RepayAndWithdrawHook_DecodeAmounts() public view {
        bytes memory data = _encodeRepayAndWithdrawData(amount, borrowAmount, false, false, amount, borrowAmount, 0);
        uint256[] memory amounts = repayAndWithdrawHook.decodeAmounts(data);
        assertEq(amounts.length, 2);
        assertEq(amounts[0], amount);
        assertEq(amounts[1], borrowAmount);
    }

    function test_RepayAndWithdrawHook_ReplaceCalldataAmounts() public view {
        bytes memory data = _encodeRepayAndWithdrawData(amount, borrowAmount, false, false, amount, borrowAmount, 0);
        uint256 newPrimary = 2e18;
        uint256 newSecondary = 1e18;
        bytes memory result = repayAndWithdrawHook.replaceCalldataAmounts(data, _dualAmounts(newPrimary, newSecondary));
        uint256[] memory decoded = repayAndWithdrawHook.decodeAmounts(result);
        assertEq(decoded[0], newPrimary);
        assertEq(decoded[1], newSecondary);
    }

    function testFuzz_RepayAndWithdrawHook_ReplaceCalldataAmounts(uint256 a, uint256 b) public view {
        vm.assume(a > 0 && b > 0);
        bytes memory data = _encodeRepayAndWithdrawData(amount, borrowAmount, false, false, amount, borrowAmount, 0);
        bytes memory result = repayAndWithdrawHook.replaceCalldataAmounts(data, _dualAmounts(a, b));
        uint256[] memory decoded = repayAndWithdrawHook.decodeAmounts(result);
        assertEq(decoded[0], a);
        assertEq(decoded[1], b);
    }

    function test_RepayAndWithdrawHook_AmountRoles() public view {
        bytes memory data = _encodeRepayAndWithdrawData(amount, borrowAmount, false, false, amount, borrowAmount, 0);
        ISuperHookInflowOutflow.AmountMeta[] memory meta = repayAndWithdrawHook.amountRoles(data);
        assertEq(meta.length, 2);
    }

    function test_RepayAndWithdrawHook_PostExecute_FullRepayFailed() public {
        // isFullRepayment but debt remains after execution
        bytes memory data = _encodeRepayAndWithdrawData(0, borrowAmount, false, true, type(uint256).max, borrowAmount, 0);

        repayAndWithdrawHook.preExecute(address(0), address(this), data);
        deal(collateralAsset, address(this), borrowAmount);

        // debtOf still returns 10e18 (not repaid)
        vm.expectRevert(EulerRepayAndWithdrawHook.FULL_REPAY_FAILED.selector);
        repayAndWithdrawHook.postExecute(address(0), address(this), data);
    }

    function test_RepayAndWithdrawHook_PostExecute_LiqCapExceeded() public {
        // Set high liability (90% of collateral)
        mockControllerVault.setAccountLiquidity(100e18, 90e18);
        mockControllerVault.setDebtOf(5e18); // not full repay

        bytes memory data = _encodeRepayAndWithdrawData(amount, borrowAmount, false, false, amount, borrowAmount, 5000);

        repayAndWithdrawHook.preExecute(address(0), address(this), data);
        deal(collateralAsset, address(this), borrowAmount);

        vm.expectRevert(EulerRepayAndWithdrawHook.LIQUIDATION_CAPACITY_EXCEEDED.selector);
        repayAndWithdrawHook.postExecute(address(0), address(this), data);
    }

    function test_RepayAndWithdrawHook_PrePostExecute() public {
        bytes memory data = _encodeRepayAndWithdrawData(amount, borrowAmount, false, false, amount, borrowAmount, 0);

        // Pre: no collateral
        repayAndWithdrawHook.preExecute(address(0), address(this), data);
        assertEq(repayAndWithdrawHook.getOutAmount(address(this)), 0);

        // Simulate receiving collateral from withdraw
        deal(collateralAsset, address(this), borrowAmount);

        repayAndWithdrawHook.postExecute(address(0), address(this), data);
        assertEq(repayAndWithdrawHook.getOutAmount(address(this)), borrowAmount);
    }

    function test_RepayAndWithdrawHook_GetOutToken() public {
        bytes memory data = _encodeRepayAndWithdrawData(amount, borrowAmount, false, false, amount, borrowAmount, 0);
        repayAndWithdrawHook.preExecute(address(0), address(this), data);
        deal(collateralAsset, address(this), borrowAmount);
        repayAndWithdrawHook.postExecute(address(0), address(this), data);
        assertEq(repayAndWithdrawHook.getOutToken(address(this)), collateralAsset);
    }

    /*//////////////////////////////////////////////////////////////
                    TOKEN ADDRESS / BALANCE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetLoanTokenAddress() public view {
        bytes memory data = _encodeDepositData(amount, false);
        assertEq(depositHook.getLoanTokenAddress(data), debtAsset);
        assertEq(borrowHook.getLoanTokenAddress(data), debtAsset);
    }

    function test_GetCollateralTokenAddress() public view {
        bytes memory data = _encodeDepositData(amount, false);
        assertEq(depositHook.getCollateralTokenAddress(data), collateralAsset);
        assertEq(borrowHook.getCollateralTokenAddress(data), collateralAsset);
    }

    function test_GetLoanTokenBalance() public {
        bytes memory data = _encodeDepositData(amount, false);
        assertEq(depositHook.getLoanTokenBalance(address(this), data), 0);

        deal(debtAsset, address(this), 500);
        assertEq(depositHook.getLoanTokenBalance(address(this), data), 500);
    }

    function test_GetCollateralTokenBalance() public {
        bytes memory data = _encodeDepositData(amount, false);
        assertEq(depositHook.getCollateralTokenBalance(address(this), data), 0);

        deal(collateralAsset, address(this), 500);
        assertEq(depositHook.getCollateralTokenBalance(address(this), data), 500);
    }

    function test_DecodeUsePrevHookAmount() public view {
        bytes memory dataFalse = _encodeDepositData(amount, false);
        assertEq(depositHook.decodeUsePrevHookAmount(dataFalse), false);

        bytes memory dataTrue = _encodeDepositData(amount, true);
        assertEq(depositHook.decodeUsePrevHookAmount(dataTrue), true);
    }

    /*//////////////////////////////////////////////////////////////
              REPAY AND WITHDRAW - REPAY-ONLY NO CONFIG VALIDATION
    //////////////////////////////////////////////////////////////*/

    function test_RepayAndWithdrawHook_RepayOnly_SkipsConfigValidation() public {
        // When secondaryAmount = 0, config validation (oracle/unit/IRM) should NOT be checked
        // Even with wrong oracle, this should NOT revert
        mockControllerVault.setOracle(makeAddr("wrongOracle"));

        bytes memory data = _encodeRepayAndWithdrawData(amount, 0, false, false, amount, 0, 0);
        Execution[] memory executions = repayAndWithdrawHook.build(address(0), address(this), data);
        assertEq(executions.length, 6); // 4 inner + pre + post
    }

    /*//////////////////////////////////////////////////////////////
              ADDITIONAL TESTS: ADDRESS VALIDATION (ALL HOOKS)
    //////////////////////////////////////////////////////////////*/

    function test_DepositHook_Build_RevertIf_ZeroCollateralAsset() public {
        bytes memory data = abi.encodePacked(
            bytes32(0),
            bytes20(uint160(collateralVault)),
            bytes20(uint160(debtAsset)),
            bytes20(0), // zero collateralAsset
            bytes20(uint160(evc)),
            bytes20(uint160(controllerVault)),
            amount,
            uint256(0),
            false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        depositHook.build(address(0), address(this), data);
    }

    function test_BorrowHook_Build_RevertIf_ZeroDebtAsset() public {
        bytes memory data = abi.encodePacked(
            bytes32(0),
            bytes20(uint160(collateralVault)),
            bytes20(0), // zero debtAsset
            bytes20(uint160(collateralAsset)),
            bytes20(uint160(evc)),
            bytes20(uint160(controllerVault)),
            amount,
            uint256(0),
            false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        borrowHook.build(address(0), address(this), data);
    }

    function test_BorrowHook_Build_RevertIf_ZeroControllerVault() public {
        bytes memory data = abi.encodePacked(
            bytes32(0),
            bytes20(uint160(collateralVault)),
            bytes20(uint160(debtAsset)),
            bytes20(uint160(collateralAsset)),
            bytes20(uint160(evc)),
            bytes20(0), // zero controllerVault
            amount,
            uint256(0),
            false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        borrowHook.build(address(0), address(this), data);
    }

    function test_BorrowHook_Build_RevertIf_MultipleControllers() public {
        // Set 2 controllers — length > 0 and first != controllerVault
        address[] memory controllers = new address[](2);
        controllers[0] = makeAddr("ctrl1");
        controllers[1] = makeAddr("ctrl2");
        mockEVC.setControllers(address(this), controllers);

        bytes memory data = _encodeBorrowData(amount, false);
        vm.expectRevert(BaseEulerLoanHook.CONTROLLER_ALREADY_SET.selector);
        borrowHook.build(address(0), address(this), data);
    }

    function test_BorrowHook_Build_ZeroControllers() public view {
        // Zero controllers means first borrow — should succeed
        bytes memory data = _encodeBorrowData(amount, false);
        Execution[] memory executions = borrowHook.build(address(0), address(this), data);
        assertEq(executions.length, 5);
    }

    function test_RepayHook_Build_RevertIf_ZeroDebtAsset() public {
        bytes memory data = abi.encodePacked(
            bytes32(0),
            bytes20(uint160(collateralVault)),
            bytes20(0), // zero debtAsset
            bytes20(uint160(collateralAsset)),
            bytes20(uint160(evc)),
            bytes20(uint160(controllerVault)),
            amount,
            uint256(0),
            false,
            false // isFullRepayment
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayHook.build(address(0), address(this), data);
    }

    function test_RepayHook_Build_RevertIf_ZeroControllerVault() public {
        bytes memory data = abi.encodePacked(
            bytes32(0),
            bytes20(uint160(collateralVault)),
            bytes20(uint160(debtAsset)),
            bytes20(uint160(collateralAsset)),
            bytes20(uint160(evc)),
            bytes20(0), // zero controllerVault
            amount,
            uint256(0),
            false,
            false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayHook.build(address(0), address(this), data);
    }

    function test_RepayHook_Build_RevertIf_ZeroEVC() public {
        bytes memory data = abi.encodePacked(
            bytes32(0),
            bytes20(uint160(collateralVault)),
            bytes20(uint160(debtAsset)),
            bytes20(uint160(collateralAsset)),
            bytes20(0), // zero evc
            bytes20(uint160(controllerVault)),
            amount,
            uint256(0),
            false,
            false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayHook.build(address(0), address(this), data);
    }

    function test_WithdrawHook_Build_RevertIf_ZeroCollateralAsset() public {
        bytes memory data = abi.encodePacked(
            bytes32(0),
            bytes20(uint160(collateralVault)),
            bytes20(uint160(debtAsset)),
            bytes20(0), // zero collateralAsset
            bytes20(uint160(evc)),
            bytes20(uint160(controllerVault)),
            amount,
            uint256(0),
            false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        withdrawHook.build(address(0), address(this), data);
    }

    /*//////////////////////////////////////////////////////////////
              ADDITIONAL TESTS: FULL REPAY DETAILED CALLDATA
    //////////////////////////////////////////////////////////////*/

    function test_RepayHook_Build_Full_DetailedCalldata() public view {
        bytes memory data = _encodeRepayData(0, false, true);
        Execution[] memory executions = repayHook.build(address(0), address(this), data);

        assertEq(executions.length, 8); // 6 inner + pre + post

        // Verify each target
        assertEq(executions[1].target, debtAsset); // approve(0)
        assertEq(executions[2].target, debtAsset); // approve(max)
        assertEq(executions[3].target, controllerVault); // repay(max)
        assertEq(executions[4].target, debtAsset); // approve(0)
        assertEq(executions[5].target, controllerVault); // disableController
        assertEq(executions[6].target, evc); // disableCollateral
    }

    function test_RepayHook_Build_Partial_DetailedTargets() public view {
        bytes memory data = _encodeRepayData(amount, false, false);
        Execution[] memory executions = repayHook.build(address(0), address(this), data);

        assertEq(executions.length, 6); // 4 inner + pre + post

        assertEq(executions[1].target, debtAsset);
        assertEq(executions[2].target, debtAsset);
        assertEq(executions[3].target, controllerVault);
        assertEq(executions[4].target, debtAsset);
    }

    /*//////////////////////////////////////////////////////////////
              ADDITIONAL TESTS: DECODE/REPLACE AMOUNTS (INDIVIDUAL)
    //////////////////////////////////////////////////////////////*/

    function test_DepositHook_DecodeAmounts() public view {
        bytes memory data = _encodeDepositData(amount, false);
        uint256[] memory amounts = depositHook.decodeAmounts(data);
        assertEq(amounts.length, 1);
        assertEq(amounts[0], amount);
    }

    function test_DepositHook_ReplaceCalldataAmounts() public view {
        bytes memory data = _encodeDepositData(amount, false);
        uint256 newAmt = 5e18;
        bytes memory result = depositHook.replaceCalldataAmounts(data, _singleAmount(newAmt));
        uint256[] memory decoded = depositHook.decodeAmounts(result);
        assertEq(decoded[0], newAmt);
    }

    function test_DepositHook_AmountRoles() public view {
        bytes memory data = _encodeDepositData(amount, false);
        ISuperHookInflowOutflow.AmountMeta[] memory meta = depositHook.amountRoles(data);
        assertEq(meta.length, 1);
        assertEq(uint256(meta[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(meta[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));
    }

    function test_BorrowHook_DecodeAmounts() public view {
        bytes memory data = _encodeBorrowData(amount, false);
        uint256[] memory amounts = borrowHook.decodeAmounts(data);
        assertEq(amounts.length, 1);
        assertEq(amounts[0], amount);
    }

    function test_BorrowHook_ReplaceCalldataAmounts() public view {
        bytes memory data = _encodeBorrowData(amount, false);
        uint256 newAmt = 3e18;
        bytes memory result = borrowHook.replaceCalldataAmounts(data, _singleAmount(newAmt));
        uint256[] memory decoded = borrowHook.decodeAmounts(result);
        assertEq(decoded[0], newAmt);
    }

    function test_RepayHook_DecodeAmounts() public view {
        bytes memory data = _encodeRepayData(amount, false, false);
        uint256[] memory amounts = repayHook.decodeAmounts(data);
        assertEq(amounts.length, 1);
        assertEq(amounts[0], amount);
    }

    function test_RepayHook_ReplaceCalldataAmounts() public view {
        bytes memory data = _encodeRepayData(amount, false, false);
        uint256 newAmt = 7e18;
        bytes memory result = repayHook.replaceCalldataAmounts(data, _singleAmount(newAmt));
        uint256[] memory decoded = repayHook.decodeAmounts(result);
        assertEq(decoded[0], newAmt);
    }

    function test_WithdrawHook_DecodeAmounts() public view {
        bytes memory data = _encodeWithdrawData(amount, false);
        uint256[] memory amounts = withdrawHook.decodeAmounts(data);
        assertEq(amounts.length, 1);
        assertEq(amounts[0], amount);
    }

    function test_WithdrawHook_ReplaceCalldataAmounts() public view {
        bytes memory data = _encodeWithdrawData(amount, false);
        uint256 newAmt = 4e18;
        bytes memory result = withdrawHook.replaceCalldataAmounts(data, _singleAmount(newAmt));
        uint256[] memory decoded = withdrawHook.decodeAmounts(result);
        assertEq(decoded[0], newAmt);
    }

    /*//////////////////////////////////////////////////////////////
              ADDITIONAL TESTS: REPLACE CALLDATA WRONG LENGTH
    //////////////////////////////////////////////////////////////*/

    function test_DepositHook_ReplaceCalldataAmounts_RevertIf_WrongLength() public {
        bytes memory data = _encodeDepositData(amount, false);
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        depositHook.replaceCalldataAmounts(data, _dualAmounts(1, 2));
    }

    function test_DepositAndBorrowHook_ReplaceCalldataAmounts_RevertIf_WrongLength() public {
        bytes memory data = _encodeDepositAndBorrowData(amount, borrowAmount, false, 100e18, 0);
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        depositAndBorrowHook.replaceCalldataAmounts(data, _singleAmount(1));
    }

    function test_RepayAndWithdrawHook_ReplaceCalldataAmounts_RevertIf_WrongLength() public {
        bytes memory data = _encodeRepayAndWithdrawData(amount, borrowAmount, false, false, amount, borrowAmount, 0);
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        repayAndWithdrawHook.replaceCalldataAmounts(data, _singleAmount(1));
    }

    /*//////////////////////////////////////////////////////////////
              ADDITIONAL TESTS: DEPOSIT AND BORROW BOUNDARY
    //////////////////////////////////////////////////////////////*/

    function test_DepositAndBorrowHook_Build_SameControllerNoRevert() public {
        address[] memory controllers = new address[](1);
        controllers[0] = controllerVault;
        mockEVC.setControllers(address(this), controllers);

        bytes memory data = _encodeDepositAndBorrowData(amount, borrowAmount, false, 100e18, 0);
        Execution[] memory executions = depositAndBorrowHook.build(address(0), address(this), data);
        assertEq(executions.length, 9);
    }

    function test_DepositAndBorrowHook_PostExecute_MaxPostDebtExactlyAtLimit() public {
        // Set debt = maxPostDebt exactly: should pass
        mockControllerVault.setDebtOf(10e18);
        bytes memory data = _encodeDepositAndBorrowData(amount, borrowAmount, false, 10e18, 0);

        depositAndBorrowHook.preExecute(address(0), address(this), data);
        deal(debtAsset, address(this), borrowAmount);

        // Should NOT revert: currentDebt == maxPostDebt
        depositAndBorrowHook.postExecute(address(0), address(this), data);
    }

    function test_DepositAndBorrowHook_PostExecute_LiqCapExactlyAtLimit() public {
        // liability / collateral = 50% exactly = maxLiqCapUtilBps 5000
        mockControllerVault.setAccountLiquidity(100e18, 50e18);

        bytes memory data = _encodeDepositAndBorrowData(amount, borrowAmount, false, 100e18, 5000);
        depositAndBorrowHook.preExecute(address(0), address(this), data);
        deal(debtAsset, address(this), borrowAmount);

        // Should NOT revert: 50 * 10000 == 100 * 5000
        depositAndBorrowHook.postExecute(address(0), address(this), data);
    }

    function test_DepositAndBorrowHook_PostExecute_LiqCapZeroSkipsCheck() public {
        // With maxLiqCapUtilBps=0, the liq cap check should be skipped entirely
        // even with extremely high liability
        mockControllerVault.setAccountLiquidity(100e18, 99e18);

        bytes memory data = _encodeDepositAndBorrowData(amount, borrowAmount, false, 100e18, 0);
        depositAndBorrowHook.preExecute(address(0), address(this), data);
        deal(debtAsset, address(this), borrowAmount);

        // Should NOT revert because maxLiqCapUtilBps == 0 skips the check
        depositAndBorrowHook.postExecute(address(0), address(this), data);
    }

    function test_DepositAndBorrowHook_PostExecute_ZeroCollateralNonZeroLiability() public {
        mockControllerVault.setAccountLiquidity(0, 10e18);

        bytes memory data = _encodeDepositAndBorrowData(amount, borrowAmount, false, 100e18, 5000);
        depositAndBorrowHook.preExecute(address(0), address(this), data);
        deal(debtAsset, address(this), borrowAmount);

        vm.expectRevert(EulerDepositCollateralAndBorrowHook.LIQUIDATION_CAPACITY_EXCEEDED.selector);
        depositAndBorrowHook.postExecute(address(0), address(this), data);
    }

    function test_DepositAndBorrowHook_AmountRoles_DirectionsAndDenominations() public view {
        bytes memory data = _encodeDepositAndBorrowData(amount, borrowAmount, false, 100e18, 0);
        ISuperHookInflowOutflow.AmountMeta[] memory meta = depositAndBorrowHook.amountRoles(data);

        assertEq(uint256(meta[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(meta[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));
        assertEq(uint256(meta[1].dir), uint256(ISuperHookInflowOutflow.Direction.OUT));
        assertEq(uint256(meta[1].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));
    }

    /*//////////////////////////////////////////////////////////////
              ADDITIONAL TESTS: REPAY AND WITHDRAW PATHS
    //////////////////////////////////////////////////////////////*/

    function test_RepayAndWithdrawHook_Build_RevertIf_UnitOfAccountMismatch() public {
        mockControllerVault.setUnitOfAccount(makeAddr("wrongUnit"));
        bytes memory data = _encodeRepayAndWithdrawData(amount, borrowAmount, false, false, amount, borrowAmount, 0);
        vm.expectRevert(EulerRepayAndWithdrawHook.UNIT_OF_ACCOUNT_MISMATCH.selector);
        repayAndWithdrawHook.build(address(0), address(this), data);
    }

    function test_RepayAndWithdrawHook_Build_RevertIf_IRMMismatch() public {
        mockControllerVault.setInterestRateModel(makeAddr("wrongIRM"));
        bytes memory data = _encodeRepayAndWithdrawData(amount, borrowAmount, false, false, amount, borrowAmount, 0);
        vm.expectRevert(EulerRepayAndWithdrawHook.IRM_MISMATCH.selector);
        repayAndWithdrawHook.build(address(0), address(this), data);
    }

    function test_RepayAndWithdrawHook_Build_FullRepayOnly() public view {
        // isFullRepayment=true, secondaryAmount=0: full repay-only (no withdraw)
        bytes memory data =
            _encodeRepayAndWithdrawData(0, 0, false, true, type(uint256).max, 0, 0);
        Execution[] memory executions = repayAndWithdrawHook.build(address(0), address(this), data);

        // Repay-only full path: 4 inner + pre + post = 6
        assertEq(executions.length, 6);

        // Verify it's a full repay with type(uint256).max
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (controllerVault, type(uint256).max)));
        assertEq(executions[3].callData, abi.encodeCall(IEVault.repay, (type(uint256).max, address(this))));
    }

    function test_RepayAndWithdrawHook_Build_FullRepay_RevertIf_ZeroDebt() public {
        mockControllerVault.setDebtOf(0);
        bytes memory data = _encodeRepayAndWithdrawData(0, borrowAmount, false, true, type(uint256).max, borrowAmount, 0);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        repayAndWithdrawHook.build(address(0), address(this), data);
    }

    function test_RepayAndWithdrawHook_RepayOnly_SkipsAllConfigValidation() public {
        // All three config params wrong — should still not revert for repay-only
        mockControllerVault.setOracle(makeAddr("wrongOracle"));
        mockControllerVault.setUnitOfAccount(makeAddr("wrongUnit"));
        mockControllerVault.setInterestRateModel(makeAddr("wrongIRM"));

        bytes memory data = _encodeRepayAndWithdrawData(amount, 0, false, false, amount, 0, 0);
        Execution[] memory executions = repayAndWithdrawHook.build(address(0), address(this), data);
        assertEq(executions.length, 6);
    }

    function test_RepayAndWithdrawHook_PostExecute_FullRepaySucceeds() public {
        // After full repay, debt should be 0: postExecute should pass
        mockControllerVault.setDebtOf(0); // Simulate debt paid off
        bytes memory data =
            _encodeRepayAndWithdrawData(0, borrowAmount, false, true, type(uint256).max, borrowAmount, 0);

        // Pre: start with collateral balance 0
        repayAndWithdrawHook.preExecute(address(0), address(this), data);

        // Simulate receiving collateral from withdraw
        deal(collateralAsset, address(this), borrowAmount);

        // Should NOT revert since debtOf is 0
        repayAndWithdrawHook.postExecute(address(0), address(this), data);
        assertEq(repayAndWithdrawHook.getOutAmount(address(this)), borrowAmount);
    }

    function test_RepayAndWithdrawHook_PostExecute_RepayOnlyTracksDebtConsumed() public {
        // For repay-only (secondaryAmount=0), outAmount = debtAsset consumed (pre - post)
        bytes memory data = _encodeRepayAndWithdrawData(amount, 0, false, false, amount, 0, 0);

        // Pre: account has 10e18 debtAsset
        deal(debtAsset, address(this), 10e18);
        repayAndWithdrawHook.preExecute(address(0), address(this), data);

        // After repay: account has 9e18 debtAsset (consumed 1e18)
        deal(debtAsset, address(this), 9e18);
        repayAndWithdrawHook.postExecute(address(0), address(this), data);

        assertEq(repayAndWithdrawHook.getOutAmount(address(this)), 1e18);
        assertEq(repayAndWithdrawHook.getOutToken(address(this)), debtAsset);
    }

    function test_RepayAndWithdrawHook_PostExecute_WithdrawTracksCollateralReceived() public {
        // For withdraw path (secondaryAmount>0), outAmount = collateral received (post - pre)
        bytes memory data = _encodeRepayAndWithdrawData(amount, borrowAmount, false, false, amount, borrowAmount, 0);

        // Pre: account has 0 collateral
        repayAndWithdrawHook.preExecute(address(0), address(this), data);

        // After withdraw: account received 5e17 collateral
        deal(collateralAsset, address(this), borrowAmount);
        repayAndWithdrawHook.postExecute(address(0), address(this), data);

        assertEq(repayAndWithdrawHook.getOutAmount(address(this)), borrowAmount);
        assertEq(repayAndWithdrawHook.getOutToken(address(this)), collateralAsset);
    }

    function test_RepayAndWithdrawHook_PostExecute_LiqCapZeroSkipsCheck() public {
        // maxRemainingLiqCapUtilBps=0 should skip liq cap check
        mockControllerVault.setAccountLiquidity(100e18, 95e18);
        mockControllerVault.setDebtOf(5e18);

        bytes memory data = _encodeRepayAndWithdrawData(amount, borrowAmount, false, false, amount, borrowAmount, 0);
        repayAndWithdrawHook.preExecute(address(0), address(this), data);
        deal(collateralAsset, address(this), borrowAmount);

        // Should NOT revert despite 95% utilization because cap is 0
        repayAndWithdrawHook.postExecute(address(0), address(this), data);
    }

    function test_RepayAndWithdrawHook_PostExecute_FullRepaySkipsLiqCapCheck() public {
        // Full repay + withdraw should NOT check liq cap (it's a full close)
        mockControllerVault.setDebtOf(0);
        mockControllerVault.setAccountLiquidity(0, 0);

        bytes memory data =
            _encodeRepayAndWithdrawData(0, borrowAmount, false, true, type(uint256).max, borrowAmount, 5000);
        repayAndWithdrawHook.preExecute(address(0), address(this), data);
        deal(collateralAsset, address(this), borrowAmount);

        // Should NOT revert: full repay skips liq cap check
        repayAndWithdrawHook.postExecute(address(0), address(this), data);
    }

    function test_RepayAndWithdrawHook_PostExecute_ZeroCollateralNonZeroLiability() public {
        mockControllerVault.setAccountLiquidity(0, 10e18);
        mockControllerVault.setDebtOf(5e18);

        bytes memory data = _encodeRepayAndWithdrawData(amount, borrowAmount, false, false, amount, borrowAmount, 5000);
        repayAndWithdrawHook.preExecute(address(0), address(this), data);
        deal(collateralAsset, address(this), borrowAmount);

        vm.expectRevert(EulerRepayAndWithdrawHook.LIQUIDATION_CAPACITY_EXCEEDED.selector);
        repayAndWithdrawHook.postExecute(address(0), address(this), data);
    }

    function test_RepayAndWithdrawHook_AmountRoles_DirectionsAndDenominations() public view {
        bytes memory data = _encodeRepayAndWithdrawData(amount, borrowAmount, false, false, amount, borrowAmount, 0);
        ISuperHookInflowOutflow.AmountMeta[] memory meta = repayAndWithdrawHook.amountRoles(data);

        assertEq(uint256(meta[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(meta[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));
        assertEq(uint256(meta[1].dir), uint256(ISuperHookInflowOutflow.Direction.OUT));
        assertEq(uint256(meta[1].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));
    }

    /*//////////////////////////////////////////////////////////////
              ADDITIONAL TESTS: FUZZ BUILD AMOUNTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_DepositHook_Build(uint256 amt) public view {
        vm.assume(amt > 0);
        bytes memory data = _encodeDepositData(amt, false);
        Execution[] memory executions = depositHook.build(address(0), address(this), data);
        assertEq(executions.length, 6);
        // Verify the deposit amount is encoded correctly
        assertEq(executions[3].callData, abi.encodeCall(IEVault.deposit, (amt, address(this))));
    }

    function testFuzz_BorrowHook_Build(uint256 amt) public view {
        vm.assume(amt > 0);
        bytes memory data = _encodeBorrowData(amt, false);
        Execution[] memory executions = borrowHook.build(address(0), address(this), data);
        assertEq(executions.length, 5);
        assertEq(executions[3].callData, abi.encodeCall(IEVault.borrow, (amt, address(this))));
    }

    function testFuzz_RepayHook_Build_Partial(uint256 amt) public view {
        vm.assume(amt > 0);
        bytes memory data = _encodeRepayData(amt, false, false);
        Execution[] memory executions = repayHook.build(address(0), address(this), data);
        assertEq(executions.length, 6);
        assertEq(executions[3].callData, abi.encodeCall(IEVault.repay, (amt, address(this))));
    }

    function testFuzz_WithdrawHook_Build(uint256 amt) public view {
        vm.assume(amt > 0);
        bytes memory data = _encodeWithdrawData(amt, false);
        Execution[] memory executions = withdrawHook.build(address(0), address(this), data);
        assertEq(executions.length, 3);
        assertEq(executions[1].callData, abi.encodeCall(IEVault.withdraw, (amt, address(this), address(this))));
    }

    function testFuzz_DepositHook_DecodeReplaceRoundtrip(uint256 amt) public view {
        bytes memory data = _encodeDepositData(amount, false);
        bytes memory replaced = depositHook.replaceCalldataAmounts(data, _singleAmount(amt));
        uint256[] memory decoded = depositHook.decodeAmounts(replaced);
        assertEq(decoded[0], amt);
    }

    /*//////////////////////////////////////////////////////////////
              ADDITIONAL TESTS: TYPE(UINT256).MAX AMOUNTS
    //////////////////////////////////////////////////////////////*/

    function test_DepositHook_Build_MaxUintAmount() public view {
        bytes memory data = _encodeDepositData(type(uint256).max, false);
        Execution[] memory executions = depositHook.build(address(0), address(this), data);
        assertEq(executions.length, 6);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (collateralVault, type(uint256).max)));
    }

    function test_BorrowHook_Build_MaxUintAmount() public view {
        bytes memory data = _encodeBorrowData(type(uint256).max, false);
        Execution[] memory executions = borrowHook.build(address(0), address(this), data);
        assertEq(executions.length, 5);
        assertEq(executions[3].callData, abi.encodeCall(IEVault.borrow, (type(uint256).max, address(this))));
    }

    function test_WithdrawHook_Build_MaxUintAmount() public view {
        bytes memory data = _encodeWithdrawData(type(uint256).max, false);
        Execution[] memory executions = withdrawHook.build(address(0), address(this), data);
        assertEq(executions.length, 3);
    }

    /*//////////////////////////////////////////////////////////////
              ADDITIONAL TESTS: 1 WEI AMOUNTS
    //////////////////////////////////////////////////////////////*/

    function test_DepositHook_Build_OneWei() public view {
        bytes memory data = _encodeDepositData(1, false);
        Execution[] memory executions = depositHook.build(address(0), address(this), data);
        assertEq(executions.length, 6);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (collateralVault, 1)));
    }

    function test_BorrowHook_Build_OneWei() public view {
        bytes memory data = _encodeBorrowData(1, false);
        Execution[] memory executions = borrowHook.build(address(0), address(this), data);
        assertEq(executions.length, 5);
    }

    function test_RepayHook_Build_OneWei() public view {
        bytes memory data = _encodeRepayData(1, false, false);
        Execution[] memory executions = repayHook.build(address(0), address(this), data);
        assertEq(executions.length, 6);
    }

    function test_WithdrawHook_Build_OneWei() public view {
        bytes memory data = _encodeWithdrawData(1, false);
        Execution[] memory executions = withdrawHook.build(address(0), address(this), data);
        assertEq(executions.length, 3);
    }

    /*//////////////////////////////////////////////////////////////
              ADDITIONAL TESTS: PRE-EXECUTE EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_DepositHook_PreExecute_ZeroBalance() public {
        bytes memory data = _encodeDepositData(amount, false);
        depositHook.preExecute(address(0), address(this), data);
        assertEq(depositHook.getOutAmount(address(this)), 0);
    }

    function test_BorrowHook_PreExecute_NonZeroBalance() public {
        bytes memory data = _encodeBorrowData(amount, false);
        deal(debtAsset, address(this), 5e18);
        borrowHook.preExecute(address(0), address(this), data);
        assertEq(borrowHook.getOutAmount(address(this)), 5e18);
    }

    function test_DepositHook_PreExecute_RevertIf_CalledTwice() public {
        bytes memory data = _encodeDepositData(amount, false);

        deal(collateralAsset, address(this), 100e18);
        depositHook.preExecute(address(0), address(this), data);

        // Second preExecute should revert with PRE_EXECUTE_ALREADY_CALLED
        vm.expectRevert(BaseHook.PRE_EXECUTE_ALREADY_CALLED.selector);
        depositHook.preExecute(address(0), address(this), data);
    }

    /*//////////////////////////////////////////////////////////////
              ADDITIONAL TESTS: MULTIPLE ACCOUNTS
    //////////////////////////////////////////////////////////////*/

    function test_DepositHook_MultipleAccounts_IndependentOutAmounts() public {
        bytes memory data = _encodeDepositData(amount, false);
        address account1 = makeAddr("account1");
        address account2 = makeAddr("account2");

        // Each account needs its own execution context
        depositHook.setExecutionContext(account1);
        depositHook.setExecutionContext(account2);

        deal(collateralAsset, account1, 100e18);
        deal(collateralAsset, account2, 50e18);

        vm.prank(account1);
        depositHook.preExecute(address(0), account1, data);
        vm.prank(account2);
        depositHook.preExecute(address(0), account2, data);

        deal(collateralAsset, account1, 90e18); // consumed 10
        deal(collateralAsset, account2, 20e18); // consumed 30

        vm.prank(account1);
        depositHook.postExecute(address(0), account1, data);
        vm.prank(account2);
        depositHook.postExecute(address(0), account2, data);

        assertEq(depositHook.getOutAmount(account1), 10e18);
        assertEq(depositHook.getOutAmount(account2), 30e18);
    }

    function test_BorrowHook_MultipleAccounts_IndependentOutAmounts() public {
        bytes memory data = _encodeBorrowData(amount, false);
        address account1 = makeAddr("account1");
        address account2 = makeAddr("account2");

        // Each account needs its own execution context
        borrowHook.setExecutionContext(account1);
        borrowHook.setExecutionContext(account2);

        vm.prank(account1);
        borrowHook.preExecute(address(0), account1, data);
        vm.prank(account2);
        borrowHook.preExecute(address(0), account2, data);

        deal(debtAsset, account1, 5e18);
        deal(debtAsset, account2, 3e18);

        vm.prank(account1);
        borrowHook.postExecute(address(0), account1, data);
        vm.prank(account2);
        borrowHook.postExecute(address(0), account2, data);

        assertEq(borrowHook.getOutAmount(account1), 5e18);
        assertEq(borrowHook.getOutAmount(account2), 3e18);
    }

    /*//////////////////////////////////////////////////////////////
              ADDITIONAL TESTS: REPAY AND WITHDRAW LIQ CAP BOUNDARY
    //////////////////////////////////////////////////////////////*/

    function test_RepayAndWithdrawHook_PostExecute_LiqCapExactlyAtLimit() public {
        // liability / collateral = 50% exactly = maxRemainingLiqCapUtilBps 5000
        mockControllerVault.setAccountLiquidity(100e18, 50e18);
        mockControllerVault.setDebtOf(5e18);

        bytes memory data = _encodeRepayAndWithdrawData(amount, borrowAmount, false, false, amount, borrowAmount, 5000);
        repayAndWithdrawHook.preExecute(address(0), address(this), data);
        deal(collateralAsset, address(this), borrowAmount);

        // 50 * 10000 == 100 * 5000 → should NOT revert
        repayAndWithdrawHook.postExecute(address(0), address(this), data);
    }

    function test_RepayAndWithdrawHook_PostExecute_LiqCapJustOver() public {
        // liability / collateral = 50.01% > maxRemainingLiqCapUtilBps 5000
        mockControllerVault.setAccountLiquidity(10000, 5001);
        mockControllerVault.setDebtOf(5e18);

        bytes memory data = _encodeRepayAndWithdrawData(amount, borrowAmount, false, false, amount, borrowAmount, 5000);
        repayAndWithdrawHook.preExecute(address(0), address(this), data);
        deal(collateralAsset, address(this), borrowAmount);

        // 5001 * 10000 > 10000 * 5000 → revert
        vm.expectRevert(EulerRepayAndWithdrawHook.LIQUIDATION_CAPACITY_EXCEEDED.selector);
        repayAndWithdrawHook.postExecute(address(0), address(this), data);
    }

    /*//////////////////////////////////////////////////////////////
              ADDITIONAL TESTS: DEPOSIT AND BORROW CONTROLLER
    //////////////////////////////////////////////////////////////*/

    function test_DepositAndBorrowHook_Build_RevertIf_MultipleControllers() public {
        address[] memory controllers = new address[](2);
        controllers[0] = makeAddr("ctrl1");
        controllers[1] = makeAddr("ctrl2");
        mockEVC.setControllers(address(this), controllers);

        bytes memory data = _encodeDepositAndBorrowData(amount, borrowAmount, false, 100e18, 0);
        vm.expectRevert(BaseEulerLoanHook.CONTROLLER_ALREADY_SET.selector);
        depositAndBorrowHook.build(address(0), address(this), data);
    }

    function test_DepositAndBorrowHook_Build_ZeroControllersSucceeds() public view {
        // No controllers set — first borrow scenario
        bytes memory data = _encodeDepositAndBorrowData(amount, borrowAmount, false, 100e18, 0);
        Execution[] memory executions = depositAndBorrowHook.build(address(0), address(this), data);
        assertEq(executions.length, 9);
    }
}
