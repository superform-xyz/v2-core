// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { Helpers } from "../../../utils/Helpers.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { BaseLoanHookV2 } from "../../../../src/hooks/loan/BaseLoanHookV2.sol";
import { BaseEulerLoanHook } from "../../../../src/hooks/loan/euler/BaseEulerLoanHook.sol";
import { HookSubTypes } from "../../../../src/libraries/HookSubTypes.sol";
import {
    ISuperHook,
    ISuperHookLoans,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../../src/interfaces/ISuperHook.sol";
import { IEVC } from "../../../../src/vendor/euler/IEVC.sol";
import { IEVault } from "../../../../src/vendor/euler/IEVault.sol";

// Hooks
import { EulerDepositCollateralAndBorrowHook } from
    "../../../../src/hooks/loan/euler/EulerDepositCollateralAndBorrowHook.sol";
import { EulerRepayHook } from "../../../../src/hooks/loan/euler/EulerRepayHook.sol";
import { EulerRepayAndWithdrawHook } from "../../../../src/hooks/loan/euler/EulerRepayAndWithdrawHook.sol";

/*//////////////////////////////////////////////////////////////
                            LOCAL MOCKS
//////////////////////////////////////////////////////////////*/

contract MockEVC {
    mapping(address => address[]) internal _controllers;
    mapping(address => address[]) internal _collaterals;

    /// @dev EVC.disableController(address) may only be invoked by the controller vault itself.
    ///      Restricting the mock the same way proves the hooks never call it directly.
    mapping(address => bool) public registeredVault;

    function registerVault(address vault) external {
        registeredVault[vault] = true;
    }

    function getControllers(address account) external view returns (address[] memory) {
        return _controllers[account];
    }

    function getCollaterals(address account) external view returns (address[] memory) {
        return _collaterals[account];
    }

    function isControllerEnabled(address account, address vault) public view returns (bool) {
        return _contains(_controllers[account], vault);
    }

    function isCollateralEnabled(address account, address vault) public view returns (bool) {
        return _contains(_collaterals[account], vault);
    }

    // Idempotent push, mirroring the real EVC's duplicate no-op behavior
    function enableCollateral(address account, address vault) external payable {
        if (!isCollateralEnabled(account, vault)) _collaterals[account].push(vault);
    }

    function enableController(address account, address vault) external payable {
        if (!isControllerEnabled(account, vault)) _controllers[account].push(vault);
    }

    function disableCollateral(address account, address vault) external payable {
        _remove(_collaterals[account], vault);
    }

    /// @dev Vault-only path: reverts unless msg.sender is a registered vault
    function disableController(address account) external {
        require(registeredVault[msg.sender], "EVC: caller is not a registered vault");
        _remove(_controllers[account], msg.sender);
    }

    function _contains(address[] storage arr, address vault) private view returns (bool) {
        for (uint256 i; i < arr.length; ++i) {
            if (arr[i] == vault) return true;
        }
        return false;
    }

    function _remove(address[] storage arr, address vault) private {
        for (uint256 i; i < arr.length; ++i) {
            if (arr[i] == vault) {
                arr[i] = arr[arr.length - 1];
                arr.pop();
                return;
            }
        }
    }
}

contract MockGenericFactory {
    mapping(address => bool) public isProxy;

    function setProxy(address vault, bool value) external {
        isProxy[vault] = value;
    }
}

contract MockEVault {
    MockERC20 public token;

    address internal _asset;
    address internal _evc;
    uint256 internal _cash;
    uint256 internal _maxDeposit;

    /// @notice Debt per account, in underlying asset units
    mapping(address => uint256) public debtOf;

    /// @notice Share balance per account
    mapping(address => uint256) public balanceOf;

    mapping(address => uint16) internal _ltvBorrow;
    mapping(address => uint16) internal _ltvLiquidation;

    constructor(MockERC20 asset_, MockEVC evc_) {
        token = asset_;
        _asset = address(asset_);
        _evc = address(evc_);
    }

    /*////////////////////////// SETTERS //////////////////////////*/

    function setAsset(address asset_) external {
        _asset = asset_;
    }

    function setEVC(address evc_) external {
        _evc = evc_;
    }

    function setCash(uint256 cash_) external {
        _cash = cash_;
    }

    function setMaxDeposit(uint256 maxDeposit_) external {
        _maxDeposit = maxDeposit_;
    }

    function setDebt(address account, uint256 debt_) external {
        debtOf[account] = debt_;
    }

    function setShareBalance(address account, uint256 shares_) external {
        balanceOf[account] = shares_;
    }

    function setLTV(address collateral, uint16 borrowLtv_, uint16 liquidationLtv_) external {
        _ltvBorrow[collateral] = borrowLtv_;
        _ltvLiquidation[collateral] = liquidationLtv_;
    }

    /*////////////////////////// VIEWS //////////////////////////*/

    function asset() external view returns (address) {
        return _asset;
    }

    function EVC() external view returns (address) {
        return _evc;
    }

    function cash() external view returns (uint256) {
        return _cash;
    }

    function maxDeposit(address) external view returns (uint256) {
        return _maxDeposit;
    }

    // Identity conversion: shares burned == assets withdrawn
    function previewWithdraw(uint256 assets) external pure returns (uint256) {
        return assets;
    }

    function LTVBorrow(address collateral) external view returns (uint16) {
        return _ltvBorrow[collateral];
    }

    function LTVLiquidation(address collateral) external view returns (uint16) {
        return _ltvLiquidation[collateral];
    }

    /*////////////////////////// OPS //////////////////////////*/

    function deposit(uint256 amount, address receiver) external returns (uint256) {
        token.transferFrom(msg.sender, address(this), amount);
        balanceOf[receiver] += amount;
        return amount;
    }

    /// @dev Emulates EVK's end-of-call account-status check: when set, withdrawals revert the way
    ///      the real controller does for an account left unhealthy across ALL enabled collaterals
    bool public accountStatusCheckFails;

    function setAccountStatusCheckFails(bool fails) external {
        accountStatusCheckFails = fails;
    }

    function withdraw(uint256 amount, address receiver, address owner) external returns (uint256) {
        require(!accountStatusCheckFails, "E_AccountLiquidity");
        balanceOf[owner] -= amount;
        token.transfer(receiver, amount);
        return amount;
    }

    function borrow(uint256 amount, address receiver) external returns (uint256) {
        require(MockEVC(_evc).isControllerEnabled(receiver, address(this)), "E_ControllerDisabled");
        debtOf[receiver] += amount;
        token.transfer(receiver, amount);
        return amount;
    }

    // Pulls exactly `amount` from the caller; forgives when amount >= debt
    function repay(uint256 amount, address receiver) external returns (uint256) {
        token.transferFrom(msg.sender, address(this), amount);
        uint256 debt = debtOf[receiver];
        debtOf[receiver] = amount >= debt ? 0 : debt - amount;
        return amount;
    }

    /// @dev Vault self-disable path: reverts on outstanding debt, then calls the EVC internally
    function disableController() external {
        require(debtOf[msg.sender] == 0, "E_OutstandingDebt");
        MockEVC(_evc).disableController(msg.sender);
    }
}

contract MockPrevHook {
    uint256 public outAmount;
    address public outToken;

    function setOutAmount(uint256 _outAmount) external {
        outAmount = _outAmount;
    }

    function setOutToken(address _outToken) external {
        outToken = _outToken;
    }

    function getOutAmount(address) external view returns (uint256) {
        return outAmount;
    }

    function getOutToken(address) external view returns (address) {
        return outToken;
    }
}

contract MockNonLoanHook is BaseHook {
    constructor() BaseHook(ISuperHook.HookType.NONACCOUNTING, keccak256("MockNonLoan")) { }

    function name() external pure override returns (string memory) {
        return "MockNonLoanHook";
    }

    function description() external pure override returns (string memory) {
        return "Minimal non-loan hook used to prove ISuperHookLoans is not advertised by default";
    }

    function _buildHookExecutions(
        address,
        address,
        bytes calldata
    )
        internal
        pure
        override
        returns (Execution[] memory executions)
    {
        executions = new Execution[](0);
    }
}

contract EulerLoanHooksTest is Helpers {
    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    EulerDepositCollateralAndBorrowHook public openHook;
    EulerRepayHook public repayHook;
    EulerRepayAndWithdrawHook public closeHook;

    MockEVC public mockEvc;
    MockGenericFactory public mockFactory;
    MockEVault public controllerVault;
    MockEVault public collateralVault;
    MockERC20 public mockDebtToken;
    MockERC20 public mockCollateralToken;

    address public debtAsset;
    address public collateralAsset;

    uint256 public amount1;
    uint256 public amount2;

    bytes32 public constant CONFIG_ID = bytes32(uint256(0xC0FFEE));
    address public constant BURN = address(0xdead);

    function setUp() public {
        mockEvc = new MockEVC();
        mockFactory = new MockGenericFactory();

        mockDebtToken = new MockERC20("Debt Token", "DEBT", 18);
        debtAsset = address(mockDebtToken);
        mockCollateralToken = new MockERC20("Collateral Token", "COLL", 18);
        collateralAsset = address(mockCollateralToken);

        controllerVault = new MockEVault(mockDebtToken, mockEvc);
        collateralVault = new MockEVault(mockCollateralToken, mockEvc);
        mockEvc.registerVault(address(controllerVault));
        mockEvc.registerVault(address(collateralVault));
        mockFactory.setProxy(address(controllerVault), true);
        mockFactory.setProxy(address(collateralVault), true);

        openHook = new EulerDepositCollateralAndBorrowHook(address(mockEvc), address(mockFactory));
        repayHook = new EulerRepayHook(address(mockEvc), address(mockFactory));
        closeHook = new EulerRepayAndWithdrawHook(address(mockEvc), address(mockFactory));

        amount1 = 1e18;
        amount2 = 2e18;

        // Healthy open-market defaults
        controllerVault.setLTV(address(collateralVault), 8600, 8800);
        controllerVault.setCash(1_000_000e18);
        collateralVault.setMaxDeposit(1_000_000e18);
    }

    /*//////////////////////////////////////////////////////////////
                            ENCODE HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Canonical 197-byte Euler hook data layout
    function _encode(
        bytes32 configId_,
        address collateralVault_,
        address debtAsset_,
        address collateralAsset_,
        address evc_,
        address controllerVault_,
        uint256 primary_,
        uint256 secondary_,
        bool usePrev_
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            configId_, collateralVault_, debtAsset_, collateralAsset_, evc_, controllerVault_, primary_, secondary_,
            usePrev_
        );
    }

    /// @dev Composite (open/close) data with the default market wiring
    function _compositeData(uint256 primary_, uint256 secondary_, bool usePrev_) internal view returns (bytes memory) {
        return _encode(
            CONFIG_ID,
            address(collateralVault),
            debtAsset,
            collateralAsset,
            address(mockEvc),
            address(controllerVault),
            primary_,
            secondary_,
            usePrev_
        );
    }

    /// @dev Standalone-repay data: collateralVault, collateralAsset and the secondary word reserved zero
    function _repayData(uint256 cap_, bool usePrev_) internal view returns (bytes memory) {
        return _encode(
            CONFIG_ID, address(0), debtAsset, address(0), address(mockEvc), address(controllerVault), cap_, 0, usePrev_
        );
    }

    /*//////////////////////////////////////////////////////////////
                            1. CONSTRUCTORS
    //////////////////////////////////////////////////////////////*/

    function test_Constructors() public view {
        assertEq(uint256(openHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(openHook.subtype(), HookSubTypes.LOAN);

        assertEq(uint256(repayHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(repayHook.subtype(), HookSubTypes.LOAN_REPAY);

        assertEq(uint256(closeHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(closeHook.subtype(), HookSubTypes.LOAN_REPAY);
    }

    function test_Constructors_PinSingletons() public {
        // The canonical EVC and eVaultFactory are constructor-pinned immutables; the vaults remain
        // calldata but must be factory-verified proxies
        EulerDepositCollateralAndBorrowHook freshOpen =
            new EulerDepositCollateralAndBorrowHook(address(mockEvc), address(mockFactory));
        EulerRepayHook freshRepay = new EulerRepayHook(address(mockEvc), address(mockFactory));
        EulerRepayAndWithdrawHook freshClose = new EulerRepayAndWithdrawHook(address(mockEvc), address(mockFactory));

        assertEq(freshOpen.subtype(), HookSubTypes.LOAN);
        assertEq(freshRepay.subtype(), HookSubTypes.LOAN_REPAY);
        assertEq(freshClose.subtype(), HookSubTypes.LOAN_REPAY);

        assertEq(freshOpen.EVC_ADDRESS(), address(mockEvc));
        assertEq(freshOpen.EVAULT_FACTORY(), address(mockFactory));
        assertEq(freshRepay.EVC_ADDRESS(), address(mockEvc));
        assertEq(freshRepay.EVAULT_FACTORY(), address(mockFactory));
        assertEq(freshClose.EVC_ADDRESS(), address(mockEvc));
        assertEq(freshClose.EVAULT_FACTORY(), address(mockFactory));
    }

    function test_Constructors_RevertIf_ZeroSingleton() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new EulerDepositCollateralAndBorrowHook(address(0), address(mockFactory));
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new EulerDepositCollateralAndBorrowHook(address(mockEvc), address(0));

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new EulerRepayHook(address(0), address(mockFactory));
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new EulerRepayHook(address(mockEvc), address(0));

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new EulerRepayAndWithdrawHook(address(0), address(mockFactory));
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new EulerRepayAndWithdrawHook(address(mockEvc), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                              2. ERC-165
    //////////////////////////////////////////////////////////////*/

    function test_SupportsInterface_LoanHooks() public view {
        bytes4 loansId = type(ISuperHookLoans).interfaceId;
        bytes4 inflowOutflowId = type(ISuperHookInflowOutflow).interfaceId;
        bytes4 outflowId = type(ISuperHookOutflow).interfaceId;

        assertTrue(openHook.supportsInterface(loansId));
        // The standalone repay hook reserves the collateral fields as zero, which makes the
        // inherited getCollateralTokenBalance revert on its data — so it honestly does NOT
        // advertise the full ISuperHookLoans surface
        assertFalse(repayHook.supportsInterface(loansId));
        assertTrue(closeHook.supportsInterface(loansId));

        assertTrue(openHook.supportsInterface(inflowOutflowId));
        assertTrue(repayHook.supportsInterface(inflowOutflowId));
        assertTrue(closeHook.supportsInterface(inflowOutflowId));

        assertTrue(openHook.supportsInterface(outflowId));
        assertTrue(repayHook.supportsInterface(outflowId));
        assertTrue(closeHook.supportsInterface(outflowId));
    }

    function test_SupportsInterface_NonLoanHook_ReturnsFalse() public {
        MockNonLoanHook nonLoanHook = new MockNonLoanHook();
        assertFalse(nonLoanHook.supportsInterface(type(ISuperHookLoans).interfaceId));
    }

    /*//////////////////////////////////////////////////////////////
                        3. STRICT DECODE VIA BUILD
    //////////////////////////////////////////////////////////////*/

    function test_Build_RevertIf_InvalidDataLength() public {
        // 196 bytes: valid layout truncated by one byte
        bytes memory shortData = _compositeData(amount1, amount2, false);
        assembly {
            mstore(shortData, 196)
        }
        assertEq(shortData.length, 196);

        // 198 bytes: valid layout + one extra byte
        bytes memory longData = abi.encodePacked(_compositeData(amount1, amount2, false), uint8(0));
        assertEq(longData.length, 198);

        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        openHook.build(address(0), address(this), shortData);
        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        openHook.build(address(0), address(this), longData);

        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        repayHook.build(address(0), address(this), shortData);
        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        repayHook.build(address(0), address(this), longData);

        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        closeHook.build(address(0), address(this), shortData);
        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        closeHook.build(address(0), address(this), longData);
    }

    function test_Build_RevertIf_InvalidBoolValue() public {
        bytes memory data = _compositeData(amount1, amount2, false);
        data[196] = 0x02;

        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        openHook.build(address(0), address(this), data);

        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        closeHook.build(address(0), address(this), data);

        bytes memory repayData = _repayData(amount1, false);
        repayData[196] = 0x02;
        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        repayHook.build(address(0), address(this), repayData);
    }

    function test_RepayHook_Build_RevertIf_NonzeroCollateralVault() public {
        bytes memory data = _encode(
            CONFIG_ID,
            address(collateralVault),
            debtAsset,
            address(0),
            address(mockEvc),
            address(controllerVault),
            amount1,
            0,
            false
        );
        vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
        repayHook.build(address(0), address(this), data);
    }

    function test_RepayHook_Build_RevertIf_NonzeroCollateralAsset() public {
        bytes memory data = _encode(
            CONFIG_ID, address(0), debtAsset, collateralAsset, address(mockEvc), address(controllerVault), amount1, 0,
            false
        );
        vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
        repayHook.build(address(0), address(this), data);
    }

    function test_RepayHook_Build_RevertIf_NonzeroSecondaryWord() public {
        bytes memory data = _encode(
            CONFIG_ID, address(0), debtAsset, address(0), address(mockEvc), address(controllerVault), amount1, 1, false
        );
        vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
        repayHook.build(address(0), address(this), data);
    }

    function test_Build_RevertIf_ZeroDebtAsset() public {
        bytes memory compositeData = _encode(
            CONFIG_ID,
            address(collateralVault),
            address(0),
            collateralAsset,
            address(mockEvc),
            address(controllerVault),
            amount1,
            amount2,
            false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        openHook.build(address(0), address(this), compositeData);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        closeHook.build(address(0), address(this), compositeData);

        bytes memory repayData = _encode(
            CONFIG_ID, address(0), address(0), address(0), address(mockEvc), address(controllerVault), amount1, 0, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayHook.build(address(0), address(this), repayData);
    }

    function test_Build_RevertIf_ZeroEvc() public {
        bytes memory compositeData = _encode(
            CONFIG_ID,
            address(collateralVault),
            debtAsset,
            collateralAsset,
            address(0),
            address(controllerVault),
            amount1,
            amount2,
            false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        openHook.build(address(0), address(this), compositeData);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        closeHook.build(address(0), address(this), compositeData);

        bytes memory repayData = _encode(
            CONFIG_ID, address(0), debtAsset, address(0), address(0), address(controllerVault), amount1, 0, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayHook.build(address(0), address(this), repayData);
    }

    function test_Build_RevertIf_ZeroControllerVault() public {
        bytes memory compositeData = _encode(
            CONFIG_ID,
            address(collateralVault),
            debtAsset,
            collateralAsset,
            address(mockEvc),
            address(0),
            amount1,
            amount2,
            false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        openHook.build(address(0), address(this), compositeData);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        closeHook.build(address(0), address(this), compositeData);

        bytes memory repayData =
            _encode(CONFIG_ID, address(0), debtAsset, address(0), address(mockEvc), address(0), amount1, 0, false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayHook.build(address(0), address(this), repayData);
    }

    function test_CompositeBuild_RevertIf_ZeroCollateralVault() public {
        bytes memory data = _encode(
            CONFIG_ID, address(0), debtAsset, collateralAsset, address(mockEvc), address(controllerVault), amount1,
            amount2, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        openHook.build(address(0), address(this), data);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        closeHook.build(address(0), address(this), data);
    }

    function test_CompositeBuild_RevertIf_ZeroCollateralAsset() public {
        bytes memory data = _encode(
            CONFIG_ID,
            address(collateralVault),
            debtAsset,
            address(0),
            address(mockEvc),
            address(controllerVault),
            amount1,
            amount2,
            false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        openHook.build(address(0), address(this), data);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        closeHook.build(address(0), address(this), data);
    }

    function test_CompositeBuild_RevertIf_IdenticalVaults() public {
        bytes memory data = _encode(
            CONFIG_ID,
            address(controllerVault),
            debtAsset,
            collateralAsset,
            address(mockEvc),
            address(controllerVault),
            amount1,
            amount2,
            false
        );
        vm.expectRevert(BaseEulerLoanHook.IDENTICAL_VAULTS.selector);
        openHook.build(address(0), address(this), data);
        vm.expectRevert(BaseEulerLoanHook.IDENTICAL_VAULTS.selector);
        closeHook.build(address(0), address(this), data);
    }

    function test_CompositeBuild_RevertIf_IdenticalTokens() public {
        bytes memory data = _encode(
            CONFIG_ID,
            address(collateralVault),
            debtAsset,
            debtAsset,
            address(mockEvc),
            address(controllerVault),
            amount1,
            amount2,
            false
        );
        vm.expectRevert(BaseLoanHookV2.IDENTICAL_TOKENS.selector);
        openHook.build(address(0), address(this), data);
        vm.expectRevert(BaseLoanHookV2.IDENTICAL_TOKENS.selector);
        closeHook.build(address(0), address(this), data);
    }

    /*//////////////////////////////////////////////////////////////
                              4. BINDINGS
    //////////////////////////////////////////////////////////////*/

    function test_Build_RevertIf_ControllerEvcMismatch() public {
        controllerVault.setEVC(address(0xDEAD));

        vm.expectRevert(BaseEulerLoanHook.VAULT_EVC_MISMATCH.selector);
        openHook.build(address(0), address(this), _compositeData(amount1, amount2, false));

        vm.expectRevert(BaseEulerLoanHook.VAULT_EVC_MISMATCH.selector);
        closeHook.build(address(0), address(this), _compositeData(amount1, amount2, false));

        vm.expectRevert(BaseEulerLoanHook.VAULT_EVC_MISMATCH.selector);
        repayHook.build(address(0), address(this), _repayData(amount1, false));
    }

    function test_CompositeBuild_RevertIf_CollateralEvcMismatch() public {
        collateralVault.setEVC(address(0xDEAD));

        vm.expectRevert(BaseEulerLoanHook.VAULT_EVC_MISMATCH.selector);
        openHook.build(address(0), address(this), _compositeData(amount1, amount2, false));

        vm.expectRevert(BaseEulerLoanHook.VAULT_EVC_MISMATCH.selector);
        closeHook.build(address(0), address(this), _compositeData(amount1, amount2, false));
    }

    function test_Build_RevertIf_ControllerAssetMismatch() public {
        controllerVault.setAsset(address(0xBAD));

        vm.expectRevert(BaseEulerLoanHook.VAULT_ASSET_MISMATCH.selector);
        openHook.build(address(0), address(this), _compositeData(amount1, amount2, false));

        vm.expectRevert(BaseEulerLoanHook.VAULT_ASSET_MISMATCH.selector);
        closeHook.build(address(0), address(this), _compositeData(amount1, amount2, false));

        vm.expectRevert(BaseEulerLoanHook.VAULT_ASSET_MISMATCH.selector);
        repayHook.build(address(0), address(this), _repayData(amount1, false));
    }

    function test_CompositeBuild_RevertIf_CollateralAssetMismatch() public {
        collateralVault.setAsset(address(0xBAD));

        vm.expectRevert(BaseEulerLoanHook.VAULT_ASSET_MISMATCH.selector);
        openHook.build(address(0), address(this), _compositeData(amount1, amount2, false));

        vm.expectRevert(BaseEulerLoanHook.VAULT_ASSET_MISMATCH.selector);
        closeHook.build(address(0), address(this), _compositeData(amount1, amount2, false));
    }

    function test_Build_RevertIf_EvcNotCanonical() public {
        // A well-formed nonzero EVC that differs from the pinned singleton is rejected before any
        // vault call — a hostile "EVC" can never be reached
        address fakeEvc = address(0xEEE);
        bytes memory compositeData = _encode(
            CONFIG_ID,
            address(collateralVault),
            debtAsset,
            collateralAsset,
            fakeEvc,
            address(controllerVault),
            amount1,
            amount2,
            false
        );
        vm.expectRevert(BaseEulerLoanHook.EVC_NOT_CANONICAL.selector);
        openHook.build(address(0), address(this), compositeData);
        vm.expectRevert(BaseEulerLoanHook.EVC_NOT_CANONICAL.selector);
        closeHook.build(address(0), address(this), compositeData);

        bytes memory repayData =
            _encode(CONFIG_ID, address(0), debtAsset, address(0), fakeEvc, address(controllerVault), amount1, 0, false);
        vm.expectRevert(BaseEulerLoanHook.EVC_NOT_CANONICAL.selector);
        repayHook.build(address(0), address(this), repayData);
    }

    function test_Build_RevertIf_UntrustedControllerVault() public {
        // A hostile contract reporting the canonical EVC and the right asset is still rejected —
        // it is not a proxy of the pinned eVaultFactory, so enableController can never target it
        MockEVault hostileVault = new MockEVault(mockDebtToken, mockEvc);

        bytes memory compositeData = _encode(
            CONFIG_ID,
            address(collateralVault),
            debtAsset,
            collateralAsset,
            address(mockEvc),
            address(hostileVault),
            amount1,
            amount2,
            false
        );
        vm.expectRevert(BaseEulerLoanHook.UNTRUSTED_VAULT.selector);
        openHook.build(address(0), address(this), compositeData);
        vm.expectRevert(BaseEulerLoanHook.UNTRUSTED_VAULT.selector);
        closeHook.build(address(0), address(this), compositeData);

        bytes memory repayData = _encode(
            CONFIG_ID, address(0), debtAsset, address(0), address(mockEvc), address(hostileVault), amount1, 0, false
        );
        vm.expectRevert(BaseEulerLoanHook.UNTRUSTED_VAULT.selector);
        repayHook.build(address(0), address(this), repayData);
    }

    function test_CompositeBuild_RevertIf_UntrustedCollateralVault() public {
        MockEVault hostileVault = new MockEVault(mockCollateralToken, mockEvc);

        bytes memory data = _encode(
            CONFIG_ID,
            address(hostileVault),
            debtAsset,
            collateralAsset,
            address(mockEvc),
            address(controllerVault),
            amount1,
            amount2,
            false
        );
        vm.expectRevert(BaseEulerLoanHook.UNTRUSTED_VAULT.selector);
        openHook.build(address(0), address(this), data);
        vm.expectRevert(BaseEulerLoanHook.UNTRUSTED_VAULT.selector);
        closeHook.build(address(0), address(this), data);
    }

    function test_RepayHook_Build_DecoupledFromCollateralConfig() public {
        // Break every collateral-side and market-config surface: the standalone repay hook's data
        // carries no collateral fields and its validation must not touch any of this state
        controllerVault.setLTV(address(collateralVault), 0, 0);
        controllerVault.setCash(0);
        collateralVault.setMaxDeposit(0);
        collateralVault.setAsset(address(0xBAD));
        collateralVault.setEVC(address(0xDEAD));

        controllerVault.setDebt(address(this), 10e18);

        Execution[] memory executions = repayHook.build(address(0), address(this), _repayData(amount1, false));
        assertEq(executions.length, 6); // partial repay: preExecute + 4 hook execs + postExecute
    }

    /*//////////////////////////////////////////////////////////////
                        5. OPEN VALIDATION ORDER
    //////////////////////////////////////////////////////////////*/

    function test_OpenHook_Build_RevertIf_InvalidAmounts() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(0), address(this), _compositeData(0, amount2, false));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(0), address(this), _compositeData(type(uint256).max, amount2, false));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(0), address(this), _compositeData(amount1, 0, false));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(0), address(this), _compositeData(amount1, type(uint256).max, false));
    }

    function test_OpenHook_Build_RevertIf_ForeignControllerEnabled() public {
        mockEvc.enableController(address(this), address(0xBEEF));

        vm.expectRevert(BaseEulerLoanHook.CONTROLLER_MISMATCH.selector);
        openHook.build(address(0), address(this), _compositeData(amount1, amount2, false));
    }

    function test_OpenHook_Build_RevertIf_TwoControllersEnabled() public {
        mockEvc.enableController(address(this), address(controllerVault));
        mockEvc.enableController(address(this), address(0xBEEF));

        vm.expectRevert(BaseEulerLoanHook.CONTROLLER_MISMATCH.selector);
        openHook.build(address(0), address(this), _compositeData(amount1, amount2, false));
    }

    function test_OpenHook_Build_RevertIf_LtvBorrowNotSet() public {
        controllerVault.setLTV(address(collateralVault), 0, 8800);

        vm.expectRevert(BaseEulerLoanHook.LTV_NOT_SET.selector);
        openHook.build(address(0), address(this), _compositeData(amount1, amount2, false));
    }

    function test_OpenHook_Build_RevertIf_LtvLiquidationNotSet() public {
        controllerVault.setLTV(address(collateralVault), 8600, 0);

        vm.expectRevert(BaseEulerLoanHook.LTV_NOT_SET.selector);
        openHook.build(address(0), address(this), _compositeData(amount1, amount2, false));
    }

    function test_OpenHook_Build_RevertIf_DepositCapExceeded() public {
        collateralVault.setMaxDeposit(amount1 - 1);

        vm.expectRevert(BaseEulerLoanHook.DEPOSIT_CAP_EXCEEDED.selector);
        openHook.build(address(0), address(this), _compositeData(amount1, amount2, false));
    }

    function test_OpenHook_Build_RevertIf_InsufficientCash() public {
        controllerVault.setCash(amount2 - 1);

        vm.expectRevert(BaseEulerLoanHook.INSUFFICIENT_CASH.selector);
        openHook.build(address(0), address(this), _compositeData(amount1, amount2, false));
    }

    /*//////////////////////////////////////////////////////////////
                        6. PREVIOUS-HOOK PIPE
    //////////////////////////////////////////////////////////////*/

    function test_OpenHook_BuildWithPrevHook() public {
        uint256 prevAmount = 7e17;
        MockPrevHook prevHook = new MockPrevHook();
        prevHook.setOutToken(collateralAsset);
        prevHook.setOutAmount(prevAmount);

        Execution[] memory executions =
            openHook.build(address(prevHook), address(this), _compositeData(amount1, amount2, true));
        assertEq(executions.length, 9); // preExecute + 7 hook execs (both enables) + postExecute

        // The collateral approval and deposit use the previous hook's output, not calldata amount1
        assertEq(executions[2].target, collateralAsset);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (address(collateralVault), prevAmount)));
        assertEq(executions[3].target, address(collateralVault));
        assertEq(executions[3].callData, abi.encodeCall(IEVault.deposit, (prevAmount, address(this))));

        // The borrow leg (secondary) is untouched by the PREV pipe
        assertEq(executions[7].target, address(controllerVault));
        assertEq(executions[7].callData, abi.encodeCall(IEVault.borrow, (amount2, address(this))));
    }

    function test_OpenHook_Build_RevertIf_PrevTokenMismatch() public {
        MockPrevHook prevHook = new MockPrevHook();
        prevHook.setOutToken(debtAsset); // open pipes into the collateral slot
        prevHook.setOutAmount(1e18);

        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        openHook.build(address(prevHook), address(this), _compositeData(amount1, amount2, true));
    }

    function test_OpenHook_Build_RevertIf_PrevHookZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        openHook.build(address(0), address(this), _compositeData(amount1, amount2, true));
    }

    function test_OpenHook_Build_RevertIf_PrevAmountZero() public {
        MockPrevHook prevHook = new MockPrevHook();
        prevHook.setOutToken(collateralAsset);
        prevHook.setOutAmount(0);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(prevHook), address(this), _compositeData(amount1, amount2, true));
    }

    function test_OpenHook_Build_RevertIf_PrevAmountMax() public {
        MockPrevHook prevHook = new MockPrevHook();
        prevHook.setOutToken(collateralAsset);
        prevHook.setOutAmount(type(uint256).max);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(prevHook), address(this), _compositeData(amount1, amount2, true));
    }

    function test_RepayHook_BuildWithPrevHook_PrevBelowDebt() public {
        uint256 debt = 10e18;
        uint256 prevAmount = 3e18;
        controllerVault.setDebt(address(this), debt);

        MockPrevHook prevHook = new MockPrevHook();
        prevHook.setOutToken(debtAsset); // repay pipes into the debt-asset cap
        prevHook.setOutAmount(prevAmount);

        Execution[] memory executions = repayHook.build(address(prevHook), address(this), _repayData(amount1, true));
        assertEq(executions.length, 6); // partial: prev cap < debt, no disableController
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (address(controllerVault), prevAmount)));
        assertEq(executions[3].callData, abi.encodeCall(IEVault.repay, (prevAmount, address(this))));
    }

    function test_RepayHook_BuildWithPrevHook_PrevAboveDebt_MinsWithDebt() public {
        uint256 debt = 5e18;
        controllerVault.setDebt(address(this), debt);
        mockEvc.enableController(address(this), address(controllerVault));

        MockPrevHook prevHook = new MockPrevHook();
        prevHook.setOutToken(debtAsset);
        prevHook.setOutAmount(8e18); // cap > debt: actual repay is min(cap, debt) == debt

        Execution[] memory executions = repayHook.build(address(prevHook), address(this), _repayData(amount1, true));
        assertEq(executions.length, 7); // predicted clear: disableController emitted
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (address(controllerVault), debt)));
        assertEq(executions[3].callData, abi.encodeCall(IEVault.repay, (debt, address(this))));
    }

    function test_RepayHook_Build_RevertIf_PrevTokenMismatch() public {
        controllerVault.setDebt(address(this), 10e18);

        MockPrevHook prevHook = new MockPrevHook();
        prevHook.setOutToken(collateralAsset); // must be the debt asset
        prevHook.setOutAmount(1e18);

        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        repayHook.build(address(prevHook), address(this), _repayData(amount1, true));
    }

    function test_CloseHook_BuildWithPrevHook() public {
        uint256 debt = 10e18;
        uint256 prevAmount = 4e18;
        controllerVault.setDebt(address(this), debt);
        collateralVault.setShareBalance(address(this), amount2 + 1e18); // partial withdraw

        MockPrevHook prevHook = new MockPrevHook();
        prevHook.setOutToken(debtAsset); // close pipes into the debt-asset cap
        prevHook.setOutAmount(prevAmount);

        Execution[] memory executions =
            closeHook.build(address(prevHook), address(this), _compositeData(amount1, amount2, true));
        assertEq(executions.length, 7); // partial: prev cap < debt
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (address(controllerVault), prevAmount)));
        assertEq(executions[3].callData, abi.encodeCall(IEVault.repay, (prevAmount, address(this))));
    }

    /*//////////////////////////////////////////////////////////////
                        7. BUILD SHAPE (HAPPY PATHS)
    //////////////////////////////////////////////////////////////*/

    function test_OpenHook_Build_BothEnablesNeeded() public view {
        Execution[] memory executions =
            openHook.build(address(0), address(this), _compositeData(amount1, amount2, false));

        // preExecute + [approve0, approve, deposit, approve0, enableCollateral, enableController,
        // borrow] + postExecute
        assertEq(executions.length, 9);

        assertEq(executions[0].target, address(openHook));
        assertEq(executions[8].target, address(openHook));

        assertEq(executions[1].target, collateralAsset);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (address(collateralVault), 0)));

        assertEq(executions[2].target, collateralAsset);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (address(collateralVault), amount1)));

        assertEq(executions[3].target, address(collateralVault));
        assertEq(executions[3].callData, abi.encodeCall(IEVault.deposit, (amount1, address(this))));

        assertEq(executions[4].target, collateralAsset);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (address(collateralVault), 0)));

        // Enable ordering: collateral enable (5) before controller enable (6) before borrow (7)
        assertEq(executions[5].target, address(mockEvc));
        assertEq(executions[5].callData, abi.encodeCall(IEVC.enableCollateral, (address(this), address(collateralVault))));

        assertEq(executions[6].target, address(mockEvc));
        assertEq(executions[6].callData, abi.encodeCall(IEVC.enableController, (address(this), address(controllerVault))));

        assertEq(executions[7].target, address(controllerVault));
        assertEq(executions[7].callData, abi.encodeCall(IEVault.borrow, (amount2, address(this))));
    }

    function test_OpenHook_Build_BothAlreadyEnabled() public {
        mockEvc.enableCollateral(address(this), address(collateralVault));
        mockEvc.enableController(address(this), address(controllerVault));

        Execution[] memory executions =
            openHook.build(address(0), address(this), _compositeData(amount1, amount2, false));

        // No EVC enables emitted
        assertEq(executions.length, 7);
        for (uint256 i; i < executions.length; ++i) {
            assertNotEq(executions[i].target, address(mockEvc));
        }
        assertEq(executions[5].target, address(controllerVault));
        assertEq(executions[5].callData, abi.encodeCall(IEVault.borrow, (amount2, address(this))));
    }

    function test_OpenHook_Build_OnlyControllerEnableNeeded() public {
        mockEvc.enableCollateral(address(this), address(collateralVault));

        Execution[] memory executions =
            openHook.build(address(0), address(this), _compositeData(amount1, amount2, false));

        assertEq(executions.length, 8);
        assertEq(executions[5].target, address(mockEvc));
        assertEq(executions[5].callData, abi.encodeCall(IEVC.enableController, (address(this), address(controllerVault))));
        assertEq(executions[6].target, address(controllerVault));
        assertEq(executions[6].callData, abi.encodeCall(IEVault.borrow, (amount2, address(this))));
    }

    function test_OpenHook_Build_OnlyCollateralEnableNeeded() public {
        mockEvc.enableController(address(this), address(controllerVault));

        Execution[] memory executions =
            openHook.build(address(0), address(this), _compositeData(amount1, amount2, false));

        assertEq(executions.length, 8);
        assertEq(executions[5].target, address(mockEvc));
        assertEq(executions[5].callData, abi.encodeCall(IEVC.enableCollateral, (address(this), address(collateralVault))));
        assertEq(executions[6].target, address(controllerVault));
        assertEq(executions[6].callData, abi.encodeCall(IEVault.borrow, (amount2, address(this))));
    }

    function test_RepayHook_Build_Partial() public {
        uint256 debt = 10e18;
        controllerVault.setDebt(address(this), debt);

        Execution[] memory executions = repayHook.build(address(0), address(this), _repayData(amount1, false));

        // preExecute + [approve0, approve(cap), repay, approve0] + postExecute — no disable
        assertEq(executions.length, 6);

        assertEq(executions[0].target, address(repayHook));
        assertEq(executions[5].target, address(repayHook));

        assertEq(executions[1].target, debtAsset);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (address(controllerVault), 0)));

        assertEq(executions[2].target, debtAsset);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (address(controllerVault), amount1)));

        assertEq(executions[3].target, address(controllerVault));
        assertEq(executions[3].callData, abi.encodeCall(IEVault.repay, (amount1, address(this))));

        assertEq(executions[4].target, debtAsset);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (address(controllerVault), 0)));
    }

    function test_RepayHook_Build_PredictedClear_DisablesControllerLast() public {
        uint256 debt = 5e18;
        controllerVault.setDebt(address(this), debt);
        mockEvc.enableController(address(this), address(controllerVault));

        Execution[] memory executions = repayHook.build(address(0), address(this), _repayData(debt, false));

        // preExecute + [approve0, approve(debt), repay, approve0, disableController] + postExecute
        assertEq(executions.length, 7);
        assertEq(executions[3].callData, abi.encodeCall(IEVault.repay, (debt, address(this))));

        // disableController targets the VAULT (never the EVC) and is the last hook execution
        assertEq(executions[5].target, address(controllerVault));
        assertEq(executions[5].callData, abi.encodeCall(IEVault.disableController, ()));
        assertEq(executions[6].target, address(repayHook)); // postExecute follows
    }

    function test_CloseHook_Build_Partial() public {
        uint256 debt = 10e18;
        controllerVault.setDebt(address(this), debt);
        collateralVault.setShareBalance(address(this), amount2 + 1e18); // partial withdraw

        Execution[] memory executions =
            closeHook.build(address(0), address(this), _compositeData(amount1, amount2, false));

        // preExecute + [approve0, approve(cap), repay, approve0, withdraw] + postExecute — no disables
        assertEq(executions.length, 7);

        assertEq(executions[0].target, address(closeHook));
        assertEq(executions[6].target, address(closeHook));

        assertEq(executions[1].target, debtAsset);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (address(controllerVault), 0)));

        assertEq(executions[2].target, debtAsset);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (address(controllerVault), amount1)));

        assertEq(executions[3].target, address(controllerVault));
        assertEq(executions[3].callData, abi.encodeCall(IEVault.repay, (amount1, address(this))));

        assertEq(executions[4].target, debtAsset);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (address(controllerVault), 0)));

        // Withdraw executes strictly after repay
        assertEq(executions[5].target, address(collateralVault));
        assertEq(executions[5].callData, abi.encodeCall(IEVault.withdraw, (amount2, address(this), address(this))));
    }

    function test_CloseHook_Build_PredictedClear_PartialWithdraw() public {
        uint256 debt = 5e18;
        controllerVault.setDebt(address(this), debt);
        mockEvc.enableController(address(this), address(controllerVault));
        // Partial withdrawal (shares remain after withdrawing amount2); collateral flag not
        // enabled on the EVC → no collateral release emitted
        collateralVault.setShareBalance(address(this), amount2 + 1e18);

        Execution[] memory executions =
            closeHook.build(address(0), address(this), _compositeData(type(uint256).max, amount2, false));

        // preExecute + [approve0, approve(debt), repay, approve0, disableController, withdraw] + postExecute
        assertEq(executions.length, 8);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (address(controllerVault), debt)));
        assertEq(executions[3].callData, abi.encodeCall(IEVault.repay, (debt, address(this))));

        // Controller disable (5) strictly before withdraw (6); no collateral disable
        assertEq(executions[5].target, address(controllerVault));
        assertEq(executions[5].callData, abi.encodeCall(IEVault.disableController, ()));
        assertEq(executions[6].target, address(collateralVault));
        assertEq(executions[6].callData, abi.encodeCall(IEVault.withdraw, (amount2, address(this), address(this))));
        assertEq(executions[7].target, address(closeHook));
    }

    function test_CloseHook_Build_PredictedClear_FullWithdraw() public {
        uint256 debt = 5e18;
        controllerVault.setDebt(address(this), debt);
        mockEvc.enableController(address(this), address(controllerVault));
        mockEvc.enableCollateral(address(this), address(collateralVault));
        collateralVault.setShareBalance(address(this), amount2);

        Execution[] memory executions =
            closeHook.build(address(0), address(this), _compositeData(type(uint256).max, amount2, false));

        // preExecute + [approve0, approve(debt), repay, approve0, disableController, withdraw,
        // disableCollateral] + postExecute
        assertEq(executions.length, 9);

        // Ordering: disableController (5) < withdraw (6) < disableCollateral (7)
        assertEq(executions[5].target, address(controllerVault));
        assertEq(executions[5].callData, abi.encodeCall(IEVault.disableController, ()));
        assertEq(executions[6].target, address(collateralVault));
        assertEq(executions[6].callData, abi.encodeCall(IEVault.withdraw, (amount2, address(this), address(this))));
        assertEq(executions[7].target, address(mockEvc));
        assertEq(
            executions[7].callData, abi.encodeCall(IEVC.disableCollateral, (address(this), address(collateralVault)))
        );
        assertEq(executions[8].target, address(closeHook));
    }

    function test_CloseHook_Build_RevertIf_InvalidWithdrawAmount() public {
        controllerVault.setDebt(address(this), 10e18);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        closeHook.build(address(0), address(this), _compositeData(amount1, 0, false));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        closeHook.build(address(0), address(this), _compositeData(amount1, type(uint256).max, false));
    }

    function test_CloseHook_Build_PredictedClear_PartialWithdraw_StillReleasesCollateralFlag() public {
        // Debt clears but the withdrawal is partial: the collateral FLAG is still released (it
        // never locks funds — shares stay redeemable and the next open re-enables). This keeps
        // the account's EVC collateral set from accumulating stale entries toward its hard cap
        // and makes the release donation-proof (no fragile full-exit equality).
        uint256 debt = 5e18;
        controllerVault.setDebt(address(this), debt);
        mockEvc.enableController(address(this), address(controllerVault));
        mockEvc.enableCollateral(address(this), address(collateralVault));
        collateralVault.setShareBalance(address(this), amount2 + 1e18); // partial withdraw

        Execution[] memory executions =
            closeHook.build(address(0), address(this), _compositeData(type(uint256).max, amount2, false));

        // preExecute + [approve0, approve(debt), repay, approve0, disableController, withdraw,
        // disableCollateral] + postExecute
        assertEq(executions.length, 9);
        assertEq(executions[5].callData, abi.encodeCall(IEVault.disableController, ()));
        assertEq(executions[6].callData, abi.encodeCall(IEVault.withdraw, (amount2, address(this), address(this))));
        assertEq(
            executions[7].callData, abi.encodeCall(IEVC.disableCollateral, (address(this), address(collateralVault)))
        );
    }

    /// @dev B1 regression (multi-collateral): an EVC account may enable up to ten collaterals, so
    ///      fully withdrawing THIS collateral with residual debt is valid whenever the account's
    ///      other collaterals keep it healthy. The hook must not pre-block; EVK's end-of-call
    ///      account-status check over the full collateral set is the canonical arbiter.
    function test_CloseHook_FullWithdrawWithResidualDebt_Builds() public {
        controllerVault.setDebt(address(this), 10e18);
        mockEvc.enableController(address(this), address(controllerVault));
        collateralVault.setShareBalance(address(this), amount2); // previewWithdraw(amount2) == balance

        Execution[] memory executions =
            closeHook.build(address(0), address(this), _compositeData(amount1, amount2, false));

        // preExecute + [approve0, approve(repay), repay, approve0, withdraw] + postExecute —
        // residual debt: controller stays enabled, collateral flag stays enabled
        assertEq(executions.length, 7);
        assertEq(executions[5].callData, abi.encodeCall(IEVault.withdraw, (amount2, address(this), address(this))));
        for (uint256 i; i < executions.length; ++i) {
            assertTrue(
                keccak256(executions[i].callData) != keccak256(abi.encodeCall(IEVault.disableController, ())),
                "controller must stay enabled with residual debt"
            );
        }
    }

    /// @dev B1 regression: the full close executes end-to-end when the account stays healthy on
    ///      its other collaterals (emulated by the mock's passing account-status check)
    function test_CloseHook_FullWithdrawWithResidualDebt_ExecutesWhenOtherCollateralCoversDebt() public {
        controllerVault.setDebt(address(this), 10e18);
        mockEvc.enableController(address(this), address(controllerVault));
        collateralVault.setShareBalance(address(this), amount2);
        mockCollateralToken.mint(address(collateralVault), amount2); // vault liquidity for withdraw
        mockDebtToken.mint(address(this), amount1);

        Execution[] memory executions =
            closeHook.build(address(0), address(this), _compositeData(amount1, amount2, false));
        for (uint256 i; i < executions.length; ++i) {
            (bool success,) = executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            assertTrue(success);
        }

        assertEq(collateralVault.balanceOf(address(this)), 0, "collateral A fully withdrawn");
        assertGt(controllerVault.debtOf(address(this)), 0, "residual debt remains");
        assertTrue(
            mockEvc.isControllerEnabled(address(this), address(controllerVault)),
            "controller stays enabled with residual debt"
        );
        assertEq(closeHook.getOutAmount(address(this)), amount2);
    }

    /// @dev B1 regression: when the other collaterals do NOT cover the debt, the canonical EVK
    ///      account-status check reverts the withdrawal atomically — the provider, not the hook,
    ///      is the arbiter
    function test_CloseHook_FullWithdrawWithResidualDebt_CanonicalHealthCheckReverts() public {
        controllerVault.setDebt(address(this), 10e18);
        mockEvc.enableController(address(this), address(controllerVault));
        collateralVault.setShareBalance(address(this), amount2);
        mockCollateralToken.mint(address(collateralVault), amount2);
        mockDebtToken.mint(address(this), amount1);
        collateralVault.setAccountStatusCheckFails(true); // account unhealthy across ALL collaterals

        Execution[] memory executions =
            closeHook.build(address(0), address(this), _compositeData(amount1, amount2, false));

        // The withdraw leg (index 5) must revert through the provider's health check
        for (uint256 i; i < 5; ++i) {
            (bool success,) = executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            assertTrue(success);
        }
        (bool withdrawSuccess,) = executions[5].target.call(executions[5].callData);
        assertFalse(withdrawSuccess, "unhealthy full withdraw must revert via EVK, atomically");
    }

    /*//////////////////////////////////////////////////////////////
                          8. CAP SEMANTICS
    //////////////////////////////////////////////////////////////*/

    function test_RepayHook_Build_CapBelowDebt_Partial() public {
        controllerVault.setDebt(address(this), 10e18);

        Execution[] memory executions = repayHook.build(address(0), address(this), _repayData(4e18, false));
        assertEq(executions.length, 6); // no disableController
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (address(controllerVault), 4e18)));
        assertEq(executions[3].callData, abi.encodeCall(IEVault.repay, (4e18, address(this))));
    }

    function test_RepayHook_Build_CapEqualsDebt() public {
        uint256 debt = 10e18;
        controllerVault.setDebt(address(this), debt);
        mockEvc.enableController(address(this), address(controllerVault));

        Execution[] memory executions = repayHook.build(address(0), address(this), _repayData(debt, false));
        assertEq(executions.length, 7); // predicted clear: disableController emitted
        assertEq(executions[3].callData, abi.encodeCall(IEVault.repay, (debt, address(this))));
        assertEq(executions[5].callData, abi.encodeCall(IEVault.disableController, ()));
    }

    function test_RepayHook_Build_CapAboveDebt_MinsWithDebt() public {
        uint256 debt = 10e18;
        controllerVault.setDebt(address(this), debt);
        mockEvc.enableController(address(this), address(controllerVault));

        Execution[] memory executions = repayHook.build(address(0), address(this), _repayData(debt + 1e18, false));
        assertEq(executions.length, 7);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (address(controllerVault), debt)));
        assertEq(executions[3].callData, abi.encodeCall(IEVault.repay, (debt, address(this))));
    }

    function test_RepayHook_Build_CapMax_FullRepay_NoRevert() public {
        uint256 debt = 10e18;
        controllerVault.setDebt(address(this), debt);
        mockEvc.enableController(address(this), address(controllerVault));

        // type(uint256).max is a CAP, not a sentinel: it naturally means "repay everything"
        Execution[] memory executions =
            repayHook.build(address(0), address(this), _repayData(type(uint256).max, false));
        assertEq(executions.length, 7);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (address(controllerVault), debt)));
        assertEq(executions[3].callData, abi.encodeCall(IEVault.repay, (debt, address(this))));
    }

    function test_RepayHook_Build_ZeroDebt_Graceful_NoOps() public view {
        // debt defaults to zero: the repay leg is skipped instead of reverting, so a third party
        // gifting a full repayment cannot cancel a signed intent. No controller enabled → nothing
        // to emit at all.
        Execution[] memory executions = repayHook.build(address(0), address(this), _repayData(amount1, false));
        assertEq(executions.length, 2); // preExecute + postExecute only
    }

    function test_RepayHook_Build_ZeroDebt_Graceful_StillDisablesController() public {
        // Zero debt but the controller is still enabled (e.g. a third party repaid the dust):
        // the hook still emits the vault-path controller disable
        mockEvc.enableController(address(this), address(controllerVault));

        Execution[] memory executions = repayHook.build(address(0), address(this), _repayData(amount1, false));
        assertEq(executions.length, 3); // preExecute + disableController + postExecute
        assertEq(executions[1].target, address(controllerVault));
        assertEq(executions[1].callData, abi.encodeCall(IEVault.disableController, ()));
    }

    function test_CloseHook_Build_ZeroDebt_Graceful_WithdrawOnly() public {
        // Zero debt: the repay leg is skipped and the close degrades to a plain withdrawal (plus
        // releases for anything still enabled)
        collateralVault.setShareBalance(address(this), amount2 + 1e18);

        Execution[] memory executions =
            closeHook.build(address(0), address(this), _compositeData(amount1, amount2, false));
        assertEq(executions.length, 3); // preExecute + withdraw + postExecute
        assertEq(executions[1].target, address(collateralVault));
        assertEq(executions[1].callData, abi.encodeCall(IEVault.withdraw, (amount2, address(this), address(this))));
    }

    function test_CloseHook_Build_ZeroDebt_Graceful_ReleasesEnabledFlags() public {
        mockEvc.enableController(address(this), address(controllerVault));
        mockEvc.enableCollateral(address(this), address(collateralVault));
        collateralVault.setShareBalance(address(this), amount2);

        Execution[] memory executions =
            closeHook.build(address(0), address(this), _compositeData(amount1, amount2, false));
        // preExecute + disableController + withdraw + disableCollateral + postExecute
        assertEq(executions.length, 5);
        assertEq(executions[1].callData, abi.encodeCall(IEVault.disableController, ()));
        assertEq(executions[2].callData, abi.encodeCall(IEVault.withdraw, (amount2, address(this), address(this))));
        assertEq(
            executions[3].callData, abi.encodeCall(IEVC.disableCollateral, (address(this), address(collateralVault)))
        );
    }

    function test_RepayHook_Build_RevertIf_ZeroCap() public {
        controllerVault.setDebt(address(this), 10e18);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        repayHook.build(address(0), address(this), _repayData(0, false));
    }

    /*//////////////////////////////////////////////////////////////
                    9. SIZING INTERFACE (AMOUNT SLOTS)
    //////////////////////////////////////////////////////////////*/

    function test_OpenHook_DecodeAmountsAndRoles() public view {
        bytes memory data = _compositeData(amount1, amount2, false);

        uint256[] memory amounts = openHook.decodeAmounts(data);
        assertEq(amounts.length, 2);
        assertEq(amounts[0], amount1);
        assertEq(amounts[1], amount2);

        ISuperHookInflowOutflow.AmountMeta[] memory meta = openHook.amountRoles(data);
        assertEq(meta.length, 2);
        assertEq(uint256(meta[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(meta[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));
        assertEq(uint256(meta[1].dir), uint256(ISuperHookInflowOutflow.Direction.OUT));
        assertEq(uint256(meta[1].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));
    }

    function test_RepayHook_DecodeAmountsAndRoles() public view {
        bytes memory data = _repayData(amount1, false);

        // Inherited single-slot sizing interface @132
        uint256[] memory amounts = repayHook.decodeAmounts(data);
        assertEq(amounts.length, 1);
        assertEq(amounts[0], amount1);

        ISuperHookInflowOutflow.AmountMeta[] memory meta = repayHook.amountRoles(data);
        assertEq(meta.length, 1);
        assertEq(uint256(meta[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(meta[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));
    }

    function test_CloseHook_DecodeAmountsAndRoles() public view {
        bytes memory data = _compositeData(amount1, amount2, false);

        uint256[] memory amounts = closeHook.decodeAmounts(data);
        assertEq(amounts.length, 2);
        assertEq(amounts[0], amount1);
        assertEq(amounts[1], amount2);

        ISuperHookInflowOutflow.AmountMeta[] memory meta = closeHook.amountRoles(data);
        assertEq(meta.length, 2);
        assertEq(uint256(meta[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(meta[1].dir), uint256(ISuperHookInflowOutflow.Direction.OUT));
    }

    function test_OpenHook_ReplaceCalldataAmounts_PreservesIdentityFields() public view {
        bytes memory data = _compositeData(amount1, amount2, true);

        uint256[] memory newAmounts = new uint256[](2);
        newAmounts[0] = 11e18;
        newAmounts[1] = 22e18;

        bytes memory replaced = openHook.replaceCalldataAmounts(data, newAmounts);

        // Byte-exact round-trip: only the two 32-byte amount slots (@132/@164) change; configId
        // and every identity field are preserved
        assertEq(replaced, _compositeData(11e18, 22e18, true));

        uint256[] memory decoded = openHook.decodeAmounts(replaced);
        assertEq(decoded[0], 11e18);
        assertEq(decoded[1], 22e18);
    }

    function test_OpenHook_ReplaceCalldataAmounts_RevertIf_WrongLength() public {
        bytes memory data = _compositeData(amount1, amount2, false);
        uint256[] memory oneAmount = new uint256[](1);
        oneAmount[0] = 11e18;

        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        openHook.replaceCalldataAmounts(data, oneAmount);
    }

    function test_RepayHook_ReplaceCalldataAmounts_PreservesIdentityFields() public view {
        bytes memory data = _repayData(amount1, true);
        uint256[] memory newAmounts = new uint256[](1);
        newAmounts[0] = 11e18;

        bytes memory replaced = repayHook.replaceCalldataAmounts(data, newAmounts);
        assertEq(replaced, _repayData(11e18, true));

        uint256[] memory decoded = repayHook.decodeAmounts(replaced);
        assertEq(decoded.length, 1);
        assertEq(decoded[0], 11e18);
    }

    function test_RepayHook_ReplaceCalldataAmounts_RevertIf_WrongLength() public {
        bytes memory data = _repayData(amount1, false);
        uint256[] memory twoAmounts = new uint256[](2);
        twoAmounts[0] = 11e18;
        twoAmounts[1] = 22e18;

        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        repayHook.replaceCalldataAmounts(data, twoAmounts);
    }

    function test_CloseHook_ReplaceCalldataAmounts() public {
        bytes memory data = _compositeData(amount1, amount2, false);

        uint256[] memory newAmounts = new uint256[](2);
        newAmounts[0] = 11e18;
        newAmounts[1] = 22e18;

        bytes memory replaced = closeHook.replaceCalldataAmounts(data, newAmounts);
        assertEq(replaced, _compositeData(11e18, 22e18, false));

        uint256[] memory oneAmount = new uint256[](1);
        oneAmount[0] = 11e18;
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        closeHook.replaceCalldataAmounts(data, oneAmount);
    }

    function test_DecodeUsePrevHookAmount_Strict() public {
        bytes memory data = _compositeData(amount1, amount2, false);
        assertFalse(openHook.decodeUsePrevHookAmount(data));
        assertFalse(closeHook.decodeUsePrevHookAmount(data));

        bytes memory repayData = _repayData(amount1, false);
        assertFalse(repayHook.decodeUsePrevHookAmount(repayData));

        data[196] = 0x01;
        repayData[196] = 0x01;
        assertTrue(openHook.decodeUsePrevHookAmount(data));
        assertTrue(closeHook.decodeUsePrevHookAmount(data));
        assertTrue(repayHook.decodeUsePrevHookAmount(repayData));

        // Non-canonical boolean bytes revert (strict @196)
        data[196] = 0x02;
        repayData[196] = 0x02;
        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        openHook.decodeUsePrevHookAmount(data);
        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        closeHook.decodeUsePrevHookAmount(data);
        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        repayHook.decodeUsePrevHookAmount(repayData);
    }

    function test_DecodeUsePrevHookAmount_RevertIf_WrongLength() public {
        // Malformed lengths get the custom error, not an out-of-bounds panic
        bytes memory shortData = _compositeData(amount1, amount2, false);
        assembly {
            mstore(shortData, 196)
        }
        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        openHook.decodeUsePrevHookAmount(shortData);
        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        repayHook.decodeUsePrevHookAmount(shortData);
        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        closeHook.decodeUsePrevHookAmount(shortData);

        bytes memory longData = abi.encodePacked(_compositeData(amount1, amount2, false), uint8(0));
        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        openHook.decodeUsePrevHookAmount(longData);
    }

    /*//////////////////////////////////////////////////////////////
                              10. INSPECT
    //////////////////////////////////////////////////////////////*/

    function test_Inspect_Composite() public view {
        bytes memory expected = abi.encodePacked(
            address(mockEvc), address(controllerVault), address(collateralVault), debtAsset, collateralAsset
        );
        assertEq(expected.length, 100);

        assertEq(openHook.inspect(_compositeData(amount1, amount2, false)), expected);
        assertEq(closeHook.inspect(_compositeData(amount1, amount2, false)), expected);

        // configId, amount fields and usePrevHookAmount do not affect the inspector payload
        assertEq(
            openHook.inspect(
                _encode(
                    bytes32(uint256(0xFEED)),
                    address(collateralVault),
                    debtAsset,
                    collateralAsset,
                    address(mockEvc),
                    address(controllerVault),
                    9e18,
                    8e18,
                    true
                )
            ),
            expected
        );

        // Every identity field affects the inspector payload
        address other = address(0xCAFE);
        assertNotEq(
            keccak256(
                openHook.inspect(
                    _encode(
                        CONFIG_ID, other, debtAsset, collateralAsset, address(mockEvc), address(controllerVault),
                        amount1, amount2, false
                    )
                )
            ),
            keccak256(expected)
        );
        assertNotEq(
            keccak256(
                openHook.inspect(
                    _encode(
                        CONFIG_ID, address(collateralVault), other, collateralAsset, address(mockEvc),
                        address(controllerVault), amount1, amount2, false
                    )
                )
            ),
            keccak256(expected)
        );
        assertNotEq(
            keccak256(
                openHook.inspect(
                    _encode(
                        CONFIG_ID, address(collateralVault), debtAsset, other, address(mockEvc),
                        address(controllerVault), amount1, amount2, false
                    )
                )
            ),
            keccak256(expected)
        );
        assertNotEq(
            keccak256(
                openHook.inspect(
                    _encode(
                        CONFIG_ID, address(collateralVault), debtAsset, collateralAsset, other,
                        address(controllerVault), amount1, amount2, false
                    )
                )
            ),
            keccak256(expected)
        );
        assertNotEq(
            keccak256(
                openHook.inspect(
                    _encode(
                        CONFIG_ID, address(collateralVault), debtAsset, collateralAsset, address(mockEvc), other,
                        amount1, amount2, false
                    )
                )
            ),
            keccak256(expected)
        );
    }

    function test_Inspect_Repay() public view {
        bytes memory expected = abi.encodePacked(address(mockEvc), address(controllerVault), debtAsset);
        assertEq(expected.length, 60);

        assertEq(repayHook.inspect(_repayData(amount1, false)), expected);

        // configId, cap and usePrevHookAmount do not affect the inspector payload
        assertEq(
            repayHook.inspect(
                _encode(
                    bytes32(uint256(0xFEED)), address(0), debtAsset, address(0), address(mockEvc),
                    address(controllerVault), 9e18, 0, true
                )
            ),
            expected
        );

        // Every identity field affects the inspector payload
        address other = address(0xCAFE);
        assertNotEq(
            keccak256(
                repayHook.inspect(
                    _encode(CONFIG_ID, address(0), other, address(0), address(mockEvc), address(controllerVault),
                        amount1, 0, false)
                )
            ),
            keccak256(expected)
        );
        assertNotEq(
            keccak256(
                repayHook.inspect(
                    _encode(CONFIG_ID, address(0), debtAsset, address(0), other, address(controllerVault), amount1, 0,
                        false)
                )
            ),
            keccak256(expected)
        );
        assertNotEq(
            keccak256(
                repayHook.inspect(
                    _encode(CONFIG_ID, address(0), debtAsset, address(0), address(mockEvc), other, amount1, 0, false)
                )
            ),
            keccak256(expected)
        );
    }

    /*//////////////////////////////////////////////////////////////
                        11. SETTLE ROUND-TRIPS
    //////////////////////////////////////////////////////////////*/

    function test_OpenHook_SettleRoundTrip() public {
        bytes memory data = _compositeData(amount1, amount2, false);
        mockCollateralToken.mint(address(this), amount1);

        openHook.preExecute(address(0), address(this), data);

        // Simulate the provider legs: collateral leaves the wallet, borrowed debt assets arrive
        mockCollateralToken.transfer(BURN, amount1);
        mockDebtToken.mint(address(this), amount2);

        openHook.postExecute(address(0), address(this), data);

        assertEq(openHook.getOutAmount(address(this)), amount2);
        assertEq(openHook.getOutToken(address(this)), debtAsset);
    }

    function test_OpenHook_Settle_RevertIf_CollateralDeltaMismatch() public {
        bytes memory data = _compositeData(amount1, amount2, false);
        mockCollateralToken.mint(address(this), amount1);

        openHook.preExecute(address(0), address(this), data);

        // Spend one wei less collateral than the resolved expectation
        mockCollateralToken.transfer(BURN, amount1 - 1);
        mockDebtToken.mint(address(this), amount2);

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, amount1, amount1 - 1));
        openHook.postExecute(address(0), address(this), data);
    }

    function test_OpenHook_Settle_RevertIf_LoanDeltaMismatch() public {
        bytes memory data = _compositeData(amount1, amount2, false);
        mockCollateralToken.mint(address(this), amount1);

        openHook.preExecute(address(0), address(this), data);

        mockCollateralToken.transfer(BURN, amount1);
        // Receive one wei less than the resolved borrow expectation
        mockDebtToken.mint(address(this), amount2 - 1);

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, amount2, amount2 - 1));
        openHook.postExecute(address(0), address(this), data);
    }

    function test_OpenHook_Settle_RevertIf_NegativeCollateralDelta() public {
        bytes memory data = _compositeData(amount1, amount2, false);

        openHook.preExecute(address(0), address(this), data);

        // Collateral balance moves in the wrong direction (increase instead of spend)
        mockCollateralToken.mint(address(this), 1);

        vm.expectRevert(BaseLoanHookV2.NEGATIVE_BALANCE_DELTA.selector);
        openHook.postExecute(address(0), address(this), data);
    }

    function test_RepayHook_SettleRoundTrip_Partial() public {
        uint256 repayAmount = 4e18;
        controllerVault.setDebt(address(this), 10e18);
        bytes memory data = _repayData(repayAmount, false);
        mockDebtToken.mint(address(this), 10e18);

        repayHook.preExecute(address(0), address(this), data);

        // Simulate the repay: exact debt-asset spend; debt stays positive → no disable checks
        mockDebtToken.transfer(BURN, repayAmount);
        controllerVault.setDebt(address(this), 6e18);

        repayHook.postExecute(address(0), address(this), data);

        assertEq(repayHook.getOutAmount(address(this)), 0); // terminal repay publishes 0
        assertEq(repayHook.getOutToken(address(this)), debtAsset);
    }

    function test_RepayHook_SettleRoundTrip_FullClear() public {
        uint256 debt = 5e18;
        controllerVault.setDebt(address(this), debt);
        bytes memory data = _repayData(type(uint256).max, false);
        mockDebtToken.mint(address(this), debt);

        repayHook.preExecute(address(0), address(this), data);

        mockDebtToken.transfer(BURN, debt);
        controllerVault.setDebt(address(this), 0); // debt cleared; controller was never enabled

        repayHook.postExecute(address(0), address(this), data);

        assertEq(repayHook.getOutAmount(address(this)), 0); // terminal repay publishes 0
        assertEq(repayHook.getOutToken(address(this)), debtAsset);
    }

    function test_RepayHook_Settle_RevertIf_DeltaMismatch() public {
        uint256 repayAmount = 4e18;
        controllerVault.setDebt(address(this), 10e18);
        bytes memory data = _repayData(repayAmount, false);
        mockDebtToken.mint(address(this), 10e18);

        repayHook.preExecute(address(0), address(this), data);

        mockDebtToken.transfer(BURN, repayAmount - 1);

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, repayAmount, repayAmount - 1));
        repayHook.postExecute(address(0), address(this), data);
    }

    function test_RepayHook_Settle_StateDerived_ResidualDebtSkipsReleaseCheck() public {
        // The release verification is STATE-DERIVED: with residual debt at postExecute the
        // controller is legitimately still enabled, so no release check applies (the settle
        // delta check still pins the exact spend, and on a genuine EVK vault the emitted
        // disableController itself reverts E_OutstandingDebt if a predicted clear left debt)
        uint256 debt = 5e18;
        controllerVault.setDebt(address(this), debt);
        mockEvc.enableController(address(this), address(controllerVault));
        bytes memory data = _repayData(type(uint256).max, false);
        mockDebtToken.mint(address(this), debt);

        repayHook.preExecute(address(0), address(this), data); // predictedClear == true

        mockDebtToken.transfer(BURN, debt);
        controllerVault.setDebt(address(this), 1); // residual debt: controller may stay enabled

        repayHook.postExecute(address(0), address(this), data);
        assertEq(repayHook.getOutAmount(address(this)), 0); // terminal repay publishes 0
    }

    function test_RepayHook_SettleRoundTrip_ZeroDebt_Graceful() public {
        // Zero outstanding debt: the resolved repay leg is 0, nothing is spent, and the settle
        // publishes a zero spend — a gifted full repayment cannot cancel the signed intent
        bytes memory data = _repayData(amount1, false);
        mockDebtToken.mint(address(this), amount1);

        repayHook.preExecute(address(0), address(this), data);
        repayHook.postExecute(address(0), address(this), data);

        assertEq(repayHook.getOutAmount(address(this)), 0);
        assertEq(repayHook.getOutToken(address(this)), debtAsset);
    }

    function test_RepayHook_Settle_RevertIf_ControllerNotDisabled() public {
        uint256 debt = 5e18;
        controllerVault.setDebt(address(this), debt);
        mockEvc.enableController(address(this), address(controllerVault));
        bytes memory data = _repayData(type(uint256).max, false);
        mockDebtToken.mint(address(this), debt);

        repayHook.preExecute(address(0), address(this), data); // predictedClear == true

        mockDebtToken.transfer(BURN, debt);
        controllerVault.setDebt(address(this), 0);
        // rig: the controller stays enabled on the EVC

        vm.expectRevert(BaseEulerLoanHook.CONTROLLER_NOT_DISABLED.selector);
        repayHook.postExecute(address(0), address(this), data);
    }

    function test_CloseHook_SettleRoundTrip_Partial() public {
        uint256 repayAmount = 4e18;
        uint256 withdrawAmount = amount2;
        controllerVault.setDebt(address(this), 10e18);
        collateralVault.setShareBalance(address(this), withdrawAmount + 1e18); // partial withdraw
        bytes memory data = _compositeData(repayAmount, withdrawAmount, false);
        mockDebtToken.mint(address(this), 10e18);

        closeHook.preExecute(address(0), address(this), data);

        // Simulate the provider legs: debt assets spent repaying, collateral released
        mockDebtToken.transfer(BURN, repayAmount);
        mockCollateralToken.mint(address(this), withdrawAmount);

        closeHook.postExecute(address(0), address(this), data);

        assertEq(closeHook.getOutAmount(address(this)), withdrawAmount);
        assertEq(closeHook.getOutToken(address(this)), collateralAsset);
    }

    function test_CloseHook_SettleRoundTrip_FullClose() public {
        uint256 debt = 5e18;
        controllerVault.setDebt(address(this), debt);
        collateralVault.setShareBalance(address(this), amount2); // full-withdraw prediction
        mockEvc.enableController(address(this), address(controllerVault));
        mockEvc.enableCollateral(address(this), address(collateralVault));
        bytes memory data = _compositeData(type(uint256).max, amount2, false);
        mockDebtToken.mint(address(this), debt);

        closeHook.preExecute(address(0), address(this), data);

        mockDebtToken.transfer(BURN, debt);
        mockCollateralToken.mint(address(this), amount2);
        controllerVault.setDebt(address(this), 0);
        // Simulate the vault-path controller disable and the EVC collateral disable
        vm.prank(address(controllerVault));
        mockEvc.disableController(address(this));
        mockEvc.disableCollateral(address(this), address(collateralVault));

        closeHook.postExecute(address(0), address(this), data);

        assertEq(closeHook.getOutAmount(address(this)), amount2);
        assertEq(closeHook.getOutToken(address(this)), collateralAsset);
    }

    function test_CloseHook_Settle_RevertIf_LoanDeltaMismatch() public {
        uint256 repayAmount = 4e18;
        controllerVault.setDebt(address(this), 10e18);
        collateralVault.setShareBalance(address(this), amount2 + 1e18); // partial withdraw
        bytes memory data = _compositeData(repayAmount, amount2, false);
        mockDebtToken.mint(address(this), 10e18);

        closeHook.preExecute(address(0), address(this), data);

        mockDebtToken.transfer(BURN, repayAmount - 1);
        mockCollateralToken.mint(address(this), amount2);

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, repayAmount, repayAmount - 1));
        closeHook.postExecute(address(0), address(this), data);
    }

    function test_CloseHook_Settle_RevertIf_CollateralDeltaMismatch() public {
        uint256 repayAmount = 4e18;
        controllerVault.setDebt(address(this), 10e18);
        collateralVault.setShareBalance(address(this), amount2 + 1e18); // partial withdraw
        bytes memory data = _compositeData(repayAmount, amount2, false);
        mockDebtToken.mint(address(this), 10e18);

        closeHook.preExecute(address(0), address(this), data);

        mockDebtToken.transfer(BURN, repayAmount);
        // Receive one wei less collateral than the resolved expectation
        mockCollateralToken.mint(address(this), amount2 - 1);

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, amount2, amount2 - 1));
        closeHook.postExecute(address(0), address(this), data);
    }

    function test_CloseHook_Settle_RevertIf_CollateralNotDisabled() public {
        uint256 debt = 5e18;
        controllerVault.setDebt(address(this), debt);
        collateralVault.setShareBalance(address(this), amount2); // full-withdraw prediction
        mockEvc.enableCollateral(address(this), address(collateralVault));
        bytes memory data = _compositeData(type(uint256).max, amount2, false);
        mockDebtToken.mint(address(this), debt);

        closeHook.preExecute(address(0), address(this), data); // expectedCollateralDisabled == true

        mockDebtToken.transfer(BURN, debt);
        mockCollateralToken.mint(address(this), amount2);
        controllerVault.setDebt(address(this), 0);
        // rig: the collateral stays enabled on the EVC after the predicted full withdrawal

        vm.expectRevert(BaseEulerLoanHook.COLLATERAL_NOT_DISABLED.selector);
        closeHook.postExecute(address(0), address(this), data);
    }

    /*//////////////////////////////////////////////////////////////
                12. LOAN-ONLY SNAPSHOT (REPAY REGRESSION)
    //////////////////////////////////////////////////////////////*/

    /// @dev Full repay lifecycle with the collateral fields reserved zero MUST NOT revert — the
    ///      loan-only snapshot never calls balanceOf on the zero collateral address. Executing the
    ///      built array also proves the controller disable goes through the vault's own
    ///      disableController() (the mock EVC rejects any non-vault caller).
    function test_RepayHook_FullLifecycle_LoanOnlySnapshot() public {
        uint256 debt = 5e18;
        controllerVault.setDebt(address(this), debt);
        mockEvc.enableController(address(this), address(controllerVault));
        mockDebtToken.mint(address(this), 6e18);

        bytes memory data = _repayData(type(uint256).max, false);
        Execution[] memory executions = repayHook.build(address(0), address(this), data);
        assertEq(executions.length, 7);

        for (uint256 i; i < executions.length; ++i) {
            (bool success,) = executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            assertTrue(success);
        }

        assertEq(controllerVault.debtOf(address(this)), 0);
        assertFalse(mockEvc.isControllerEnabled(address(this), address(controllerVault)));
        assertEq(mockDebtToken.allowance(address(this), address(controllerVault)), 0);
        assertEq(mockDebtToken.balanceOf(address(this)), 1e18);
        assertEq(repayHook.getOutAmount(address(this)), 0); // terminal repay publishes 0
        assertEq(repayHook.getOutToken(address(this)), debtAsset);
    }

    /// @dev Documented limitation: the inherited non-virtual getCollateralTokenBalance reverts for
    ///      repay data because the collateral slot is the reserved zero address
    function test_RepayHook_GetCollateralTokenBalance_Reverts() public {
        bytes memory data = _repayData(amount1, false);
        assertEq(repayHook.getCollateralTokenAddress(data), address(0));

        vm.expectRevert();
        repayHook.getCollateralTokenBalance(address(this), data);
    }
}
