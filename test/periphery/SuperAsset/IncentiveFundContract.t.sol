// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IncentiveFundContract} from "../../../src/periphery/SuperAsset/IncentiveFundContract.sol";
import {ISuperAsset} from "../../../src/periphery/interfaces/SuperAsset/ISuperAsset.sol";
import {IIncentiveFundContract} from "../../../src/periphery/interfaces/SuperAsset/IIncentiveFundContract.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";
import {MockSuperAsset} from "../../mocks/MockSuperAsset.sol";
import {MockAssetBank} from "../../mocks/MockAssetBank.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract IncentiveFundContractTest is Test {
    // --- Events ---
    event IncentivePaid(address indexed receiver, address indexed tokenOut, uint256 amount);
    event IncentiveTaken(address indexed sender, address indexed tokenIn, uint256 amount);
    event SettlementTokenInSet(address indexed token);
    event SettlementTokenOutSet(address indexed token);

    // --- State Variables ---
    IncentiveFundContract public incentiveFund;
    MockSuperAsset public superAsset;
    MockAssetBank public assetBank;
    MockERC20 public tokenIn;
    MockERC20 public tokenOut;
    address public admin;
    address public manager;
    address public user;

    // --- Setup ---
    function setUp() public {
        // Setup accounts
        admin = makeAddr("admin");
        manager = makeAddr("manager");
        user = makeAddr("user");

        // Deploy mock contracts
        vm.startPrank(admin);
        tokenIn = new MockERC20("Token In", "TIN", 18);
        tokenOut = new MockERC20("Token Out", "TOUT", 18);
        superAsset = new MockSuperAsset();
        assetBank = new MockAssetBank();

        // Deploy and initialize IncentiveFundContract
        incentiveFund = new IncentiveFundContract();
        incentiveFund.initialize(address(superAsset), address(assetBank));

        // Setup roles
        incentiveFund.grantRole(incentiveFund.INCENTIVE_FUND_MANAGER(), manager);
        vm.stopPrank();

        // Setup initial balances
        tokenIn.mint(address(incentiveFund), 1000e18);
        tokenOut.mint(address(incentiveFund), 1000e18);
        tokenIn.mint(user, 1000e18);
        tokenOut.mint(user, 1000e18);
    }

    // --- Test: Initialization ---
    function test_Initialize() public {
        assertEq(address(incentiveFund.superAsset()), address(superAsset));
        assertEq(incentiveFund.assetBank(), address(assetBank));
    }

    function test_Initialize_RevertIfAlreadyInitialized() public {
        vm.startPrank(admin);
        vm.expectRevert(IIncentiveFundContract.ALREADY_INITIALIZED.selector);
        incentiveFund.initialize(address(superAsset), address(assetBank));
        vm.stopPrank();
    }

    function test_Initialize_RevertIfZeroAddress() public {
        vm.startPrank(admin);
        IncentiveFundContract newContract = new IncentiveFundContract();
        vm.expectRevert(IIncentiveFundContract.ZERO_ADDRESS.selector);
        newContract.initialize(address(0), address(assetBank));

        vm.expectRevert(IIncentiveFundContract.ZERO_ADDRESS.selector);
        newContract.initialize(address(superAsset), address(0));
        vm.stopPrank();
    }

    // --- Test: Access Control ---
    function test_OnlyAdminCanSetTokens() public {
        // Non-admin cannot set tokens
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, incentiveFund.DEFAULT_ADMIN_ROLE()));
        incentiveFund.setTokenInIncentive(address(tokenIn));

        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, incentiveFund.DEFAULT_ADMIN_ROLE()));
        incentiveFund.setTokenOutIncentive(address(tokenOut));
        vm.stopPrank();

        // Admin can set tokens
        vm.startPrank(admin);
        vm.expectEmit(true, false, false, true);
        emit SettlementTokenInSet(address(tokenIn));
        incentiveFund.setTokenInIncentive(address(tokenIn));

        vm.expectEmit(true, false, false, true);
        emit SettlementTokenOutSet(address(tokenOut));
        incentiveFund.setTokenOutIncentive(address(tokenOut));
        vm.stopPrank();

        assertEq(incentiveFund.tokenInIncentive(), address(tokenIn));
        assertEq(incentiveFund.tokenOutIncentive(), address(tokenOut));
    }

    function test_OnlyManagerCanPayIncentive() public {
        // Setup tokens
        vm.startPrank(admin);
        incentiveFund.setTokenOutIncentive(address(tokenOut));
        vm.stopPrank();

        // Mock price data
        vm.mockCall(
            address(superAsset),
            abi.encodeWithSelector(ISuperAsset.getPriceWithCircuitBreakers.selector, address(tokenOut)),
            abi.encode(1e18, false, false, false)
        );
        vm.mockCall(
            address(superAsset),
            abi.encodeWithSelector(ISuperAsset.getPrecision.selector),
            abi.encode(1e18)
        );

        // Non-manager cannot pay incentive
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, incentiveFund.INCENTIVE_FUND_MANAGER()));
        incentiveFund.payIncentive(user, 100e18);
        vm.stopPrank();

        // Manager can pay incentive
        uint256 balanceBefore = tokenOut.balanceOf(user);
        
        vm.startPrank(manager);
        incentiveFund.payIncentive(user, 100e18);
        vm.stopPrank();

        uint256 balanceAfter = tokenOut.balanceOf(user);
        assertEq(balanceAfter - balanceBefore, 100e18);
    }

    function test_OnlyManagerCanTakeIncentive() public {
        // Setup tokens
        vm.startPrank(admin);
        incentiveFund.setTokenInIncentive(address(tokenIn));
        vm.stopPrank();

        // Mock price data
        vm.mockCall(
            address(superAsset),
            abi.encodeWithSelector(ISuperAsset.getPriceWithCircuitBreakers.selector, address(tokenIn)),
            abi.encode(1e18, false, false, false)
        );
        vm.mockCall(
            address(superAsset),
            abi.encodeWithSelector(ISuperAsset.getPrecision.selector),
            abi.encode(1e18)
        );

        // Give approval to incentiveFund
        vm.startPrank(user);
        tokenIn.approve(address(incentiveFund), 100e18);
        vm.stopPrank();

        // Non-manager cannot take incentive
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, incentiveFund.INCENTIVE_FUND_MANAGER()));
        incentiveFund.takeIncentive(user, 100e18);
        vm.stopPrank();

        // Manager can take incentive
        uint256 balanceBefore = tokenIn.balanceOf(user);
        
        vm.startPrank(manager);
        incentiveFund.takeIncentive(user, 100e18);
        vm.stopPrank();

        uint256 balanceAfter = tokenIn.balanceOf(user);
        assertEq(balanceBefore - balanceAfter, 100e18);
    }

    // --- Test: Core Functionality ---
    function test_PayIncentive() public {
        // Setup token
        vm.startPrank(admin);
        incentiveFund.setTokenOutIncentive(address(tokenOut));
        vm.stopPrank();

        // Mock price data
        vm.mockCall(
            address(superAsset),
            abi.encodeWithSelector(ISuperAsset.getPriceWithCircuitBreakers.selector, address(tokenOut)),
            abi.encode(1e18, false, false, false)
        );
        vm.mockCall(
            address(superAsset),
            abi.encodeWithSelector(ISuperAsset.getPrecision.selector),
            abi.encode(1e18)
        );

        // Pay incentive
        uint256 amount = 100e18;
        uint256 balanceBefore = tokenOut.balanceOf(user);

        vm.expectEmit(true, true, false, true);
        emit IncentivePaid(user, address(tokenOut), amount);

        vm.startPrank(manager);
        incentiveFund.payIncentive(user, amount);
        vm.stopPrank();

        uint256 balanceAfter = tokenOut.balanceOf(user);
        assertEq(balanceAfter - balanceBefore, amount);
    }

    function test_PayIncentive_RevertIfNoTokenSet() public {
        // Mock price data
        vm.mockCall(
            address(superAsset),
            abi.encodeWithSelector(ISuperAsset.getPriceWithCircuitBreakers.selector, address(0)),
            abi.encode(1e18, false, false, false)
        );
        vm.mockCall(
            address(superAsset),
            abi.encodeWithSelector(ISuperAsset.getPrecision.selector),
            abi.encode(1e18)
        );

        vm.startPrank(manager);
        vm.expectRevert(IIncentiveFundContract.TOKEN_OUT_NOT_SET.selector);
        incentiveFund.payIncentive(user, 100e18);
        vm.stopPrank();
    }

    function test_PayIncentive_RevertIfInsufficientBalance() public {
        // Setup token
        vm.startPrank(admin);
        incentiveFund.setTokenOutIncentive(address(tokenOut));
        vm.stopPrank();

        // Mock price data
        vm.mockCall(
            address(superAsset),
            abi.encodeWithSelector(ISuperAsset.getPriceWithCircuitBreakers.selector, address(tokenOut)),
            abi.encode(1e18, false, false, false)
        );
        vm.mockCall(
            address(superAsset),
            abi.encodeWithSelector(ISuperAsset.getPrecision.selector),
            abi.encode(1e18)
        );

        // Try to pay more than contract's balance
        vm.startPrank(manager);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(incentiveFund), 1000e18, 2000e18));
        incentiveFund.payIncentive(user, 2000e18);
        vm.stopPrank();
    }

    function test_TakeIncentive() public {
        // Setup token
        vm.startPrank(admin);
        incentiveFund.setTokenInIncentive(address(tokenIn));
        vm.stopPrank();

        // Mock price data
        vm.mockCall(
            address(superAsset),
            abi.encodeWithSelector(ISuperAsset.getPriceWithCircuitBreakers.selector, address(tokenIn)),
            abi.encode(1e18, false, false, false)
        );
        vm.mockCall(
            address(superAsset),
            abi.encodeWithSelector(ISuperAsset.getPrecision.selector),
            abi.encode(1e18)
        );

        // Approve transfer
        vm.startPrank(user);
        tokenIn.approve(address(incentiveFund), 100e18);
        vm.stopPrank();

        // Take incentive
        uint256 amount = 100e18;
        uint256 balanceBefore = tokenIn.balanceOf(user);

        vm.expectEmit(true, true, false, true);
        emit IncentiveTaken(user, address(tokenIn), amount);

        vm.startPrank(manager);
        incentiveFund.takeIncentive(user, amount);
        vm.stopPrank();

        uint256 balanceAfter = tokenIn.balanceOf(user);
        assertEq(balanceBefore - balanceAfter, amount);
    }

    function test_TakeIncentive_RevertIfNoTokenSet() public {
        // Mock price data
        vm.mockCall(
            address(superAsset),
            abi.encodeWithSelector(ISuperAsset.getPriceWithCircuitBreakers.selector, address(0)),
            abi.encode(1e18, false, false, false)
        );
        vm.mockCall(
            address(superAsset),
            abi.encodeWithSelector(ISuperAsset.getPrecision.selector),
            abi.encode(1e18)
        );

        vm.startPrank(manager);
        vm.expectRevert(IIncentiveFundContract.TOKEN_IN_NOT_SET.selector);
        incentiveFund.takeIncentive(user, 100e18);
        vm.stopPrank();
    }

    function test_TakeIncentive_RevertIfInsufficientAllowance() public {
        // Setup token
        vm.startPrank(admin);
        incentiveFund.setTokenInIncentive(address(tokenIn));
        vm.stopPrank();

        // Mock price data
        vm.mockCall(
            address(superAsset),
            abi.encodeWithSelector(ISuperAsset.getPriceWithCircuitBreakers.selector, address(tokenIn)),
            abi.encode(1e18, false, false, false)
        );
        vm.mockCall(
            address(superAsset),
            abi.encodeWithSelector(ISuperAsset.getPrecision.selector),
            abi.encode(1e18)
        );

        // Try to take without approval
        vm.startPrank(manager);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(incentiveFund), 0, 100e18));
        incentiveFund.takeIncentive(user, 100e18);
        vm.stopPrank();
    }

    function test_TakeIncentive_RevertIfInsufficientBalance() public {
        // Setup token
        vm.startPrank(admin);
        incentiveFund.setTokenInIncentive(address(tokenIn));
        vm.stopPrank();

        // Mock price data
        vm.mockCall(
            address(superAsset),
            abi.encodeWithSelector(ISuperAsset.getPriceWithCircuitBreakers.selector, address(tokenIn)),
            abi.encode(1e18, false, false, false)
        );
        vm.mockCall(
            address(superAsset),
            abi.encodeWithSelector(ISuperAsset.getPrecision.selector),
            abi.encode(1e18)
        );

        // Approve transfer
        vm.startPrank(user);
        tokenIn.approve(address(incentiveFund), 2000e18);
        vm.stopPrank();

        // Try to take more than user's balance
        vm.startPrank(manager);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, 1000e18, 2000e18));
        incentiveFund.takeIncentive(user, 2000e18);
        vm.stopPrank();
    }
}
