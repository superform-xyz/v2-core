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

contract IncentiveFundContractTest is Test {
    // --- Events ---
    event IncentivePaid(address indexed token, address indexed recipient, uint256 amount);
    event IncentiveTaken(address indexed token, address indexed from, uint256 amount);

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
        admin = address(this);
        manager = makeAddr("manager");
        user = makeAddr("user");

        // Deploy mock contracts
        tokenIn = new MockERC20("Token In", "TIN", 18);
        tokenOut = new MockERC20("Token Out", "TOUT", 18);
        superAsset = new MockSuperAsset();
        assetBank = new MockAssetBank();

        // Deploy and initialize IncentiveFundContract
        incentiveFund = new IncentiveFundContract();
        incentiveFund.initialize(address(superAsset), address(assetBank));

        // Setup roles
        incentiveFund.grantRole(incentiveFund.INCENTIVE_FUND_MANAGER(), manager);

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
        vm.expectRevert(IIncentiveFundContract.ALREADY_INITIALIZED.selector);
        incentiveFund.initialize(address(superAsset), address(assetBank));
    }

    function test_Initialize_RevertIfZeroAddress() public {
        IncentiveFundContract newContract = new IncentiveFundContract();
        
        vm.expectRevert(IIncentiveFundContract.ZERO_ADDRESS.selector);
        newContract.initialize(address(0), address(assetBank));

        vm.expectRevert(IIncentiveFundContract.ZERO_ADDRESS.selector);
        newContract.initialize(address(superAsset), address(0));
    }

    // --- Test: Access Control ---
    function test_OnlyManagerCanSetTokens() public {
        // Non-manager cannot set tokens
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, incentiveFund.INCENTIVE_FUND_MANAGER()));
        incentiveFund.setTokenInIncentive(address(tokenIn));

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, incentiveFund.INCENTIVE_FUND_MANAGER()));
        incentiveFund.setTokenOutIncentive(address(tokenOut));

        // Manager can set tokens
        vm.startPrank(manager);
        incentiveFund.setTokenInIncentive(address(tokenIn));
        incentiveFund.setTokenOutIncentive(address(tokenOut));
        vm.stopPrank();

        assertEq(incentiveFund.tokenInIncentive(), address(tokenIn));
        assertEq(incentiveFund.tokenOutIncentive(), address(tokenOut));
    }

    // TODO: Fix this
    // function test_OnlyAssetBankCanPayIncentive() public {
    //     // Setup tokens
    //     vm.prank(manager);
    //     incentiveFund.setTokenInIncentive(address(tokenIn));

    //     // Non-AssetBank cannot pay incentive
    //     vm.prank(user);
    //     vm.expectRevert(IIncentiveFundContract.NOT_ASSET_BANK.selector);
    //     incentiveFund.payIncentive(user, 100e18);

    //     // AssetBank can pay incentive
    //     uint256 balanceBefore = tokenIn.balanceOf(user);
        
    //     vm.prank(address(assetBank));
    //     incentiveFund.payIncentive(user, 100e18);

    //     uint256 balanceAfter = tokenIn.balanceOf(user);
    //     assertEq(balanceAfter - balanceBefore, 100e18);
    // }

    // function test_OnlyAssetBankCanTakeIncentive() public {
    //     // Setup tokens
    //     vm.prank(manager);
    //     incentiveFund.setTokenOutIncentive(address(tokenOut));

    //     // Give approval to incentiveFund
    //     vm.prank(user);
    //     tokenOut.approve(address(incentiveFund), 100e18);

    //     // Non-AssetBank cannot take incentive
    //     vm.prank(user);
    //     vm.expectRevert(IIncentiveFundContract.NOT_ASSET_BANK.selector);
    //     incentiveFund.takeIncentive(user, 100e18);

    //     // AssetBank can take incentive
    //     uint256 balanceBefore = tokenOut.balanceOf(user);
        
    //     vm.prank(address(assetBank));
    //     incentiveFund.takeIncentive(user, 100e18);

    //     uint256 balanceAfter = tokenOut.balanceOf(user);
    //     assertEq(balanceBefore - balanceAfter, 100e18);
    // }

    // --- Test: Core Functionality ---
    function test_PayIncentive() public {
        // Setup token
        vm.prank(manager);
        incentiveFund.setTokenInIncentive(address(tokenIn));

        // Pay incentive
        uint256 amount = 100e18;
        uint256 balanceBefore = tokenIn.balanceOf(user);

        vm.expectEmit(true, true, false, true);
        emit IncentivePaid(address(tokenIn), user, amount);

        vm.prank(address(assetBank));
        incentiveFund.payIncentive(user, amount);

        uint256 balanceAfter = tokenIn.balanceOf(user);
        assertEq(balanceAfter - balanceBefore, amount);
    }

    function test_PayIncentive_RevertIfNoTokenSet() public {
        vm.prank(address(assetBank));
        vm.expectRevert(IIncentiveFundContract.TOKEN_IN_NOT_SET.selector);
        incentiveFund.payIncentive(user, 100e18);
    }

    function test_PayIncentive_RevertIfInsufficientBalance() public {
        // Setup token
        vm.prank(manager);
        incentiveFund.setTokenInIncentive(address(tokenIn));

        // Try to pay more than contract's balance
        vm.prank(address(assetBank));
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        incentiveFund.payIncentive(user, 2000e18);
    }

    function test_TakeIncentive() public {
        // Setup token
        vm.prank(manager);
        incentiveFund.setTokenOutIncentive(address(tokenOut));

        // Approve transfer
        vm.prank(user);
        tokenOut.approve(address(incentiveFund), 100e18);

        // Take incentive
        uint256 amount = 100e18;
        uint256 balanceBefore = tokenOut.balanceOf(user);

        vm.expectEmit(true, true, false, true);
        emit IncentiveTaken(address(tokenOut), user, amount);

        vm.prank(address(assetBank));
        incentiveFund.takeIncentive(user, amount);

        uint256 balanceAfter = tokenOut.balanceOf(user);
        assertEq(balanceBefore - balanceAfter, amount);
    }

    function test_TakeIncentive_RevertIfNoTokenSet() public {
        vm.prank(address(assetBank));
        vm.expectRevert(IIncentiveFundContract.TOKEN_OUT_NOT_SET.selector);
        incentiveFund.takeIncentive(user, 100e18);
    }

    function test_TakeIncentive_RevertIfInsufficientAllowance() public {
        // Setup token
        vm.prank(manager);
        incentiveFund.setTokenOutIncentive(address(tokenOut));

        // Try to take without approval
        vm.prank(address(assetBank));
        vm.expectRevert("ERC20: insufficient allowance");
        incentiveFund.takeIncentive(user, 100e18);
    }

    function test_TakeIncentive_RevertIfInsufficientBalance() public {
        // Setup token
        vm.prank(manager);
        incentiveFund.setTokenOutIncentive(address(tokenOut));

        // Approve transfer
        vm.prank(user);
        tokenOut.approve(address(incentiveFund), 2000e18);

        // Try to take more than user's balance
        vm.prank(address(assetBank));
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        incentiveFund.takeIncentive(user, 2000e18);
    }
}
