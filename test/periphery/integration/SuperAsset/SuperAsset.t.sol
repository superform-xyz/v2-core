// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {SuperAsset} from "../../../../src/periphery/SuperAsset/SuperAsset.sol";
import {ISuperAsset} from "../../../../src/periphery/interfaces/SuperAsset/ISuperAsset.sol";
import {AssetBank} from "../../../../src/periphery/SuperAsset/AssetBank.sol";
import {IncentiveFundContract} from "../../../../src/periphery/SuperAsset/IncentiveFundContract.sol";
import {IncentiveCalculationContract} from "../../../../src/periphery/SuperAsset/IncentiveCalculationContract.sol";
import {SuperOracle} from "../../../../src/periphery/oracles/SuperOracle.sol";
import {MockERC20} from "../../../mocks/MockERC20.sol";
import {MockAggregator} from "../../mocks/MockAggregator.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Helpers} from "../../../utils/Helpers.sol";

contract SuperAssetTest is Helpers {
    // --- Constants ---
    bytes32 public constant PROVIDER_1 = keccak256("PROVIDER_1");
    bytes32 public constant PROVIDER_2 = keccak256("PROVIDER_2");
    bytes32 public constant PROVIDER_3 = keccak256("PROVIDER_3");
    bytes32 public constant PROVIDER_4 = keccak256("PROVIDER_4");
    bytes32 public constant PROVIDER_5 = keccak256("PROVIDER_5");
    bytes32 public constant PROVIDER_6 = keccak256("PROVIDER_6");
    bytes32 public constant PROVIDER_SUPERASSET = keccak256("PROVIDER_SUPERASSET");
    address public constant USD = address(840);

    // --- State Variables ---
    SuperAsset public superAsset;
    AssetBank public assetBank;
    SuperOracle public oracle;
    MockERC20 public tokenIn;
    MockERC20 public tokenOut;
    MockAggregator public mockFeedSuperAssetShares1;
    MockAggregator public mockFeed1;
    MockAggregator public mockFeed2;
    MockAggregator public mockFeed3;
    MockAggregator public mockFeed4;
    MockAggregator public mockFeed5;
    MockAggregator public mockFeed6;
    IncentiveCalculationContract public icc;
    IncentiveFundContract public incentiveFund;
    address public admin;
    address public manager;
    address public user;
    address public user11;

    // --- Setup ---
    function setUp() public {
        // Setup accounts
        admin = makeAddr("admin");
        manager = makeAddr("manager");
        user = makeAddr("user");
        user11 = makeAddr("user11");

        vm.startPrank(admin);
        // Deploy and initialize SuperAsset
        superAsset = new SuperAsset();
        console.log("SuperAsset deployed");

        // Deploy mock tokens
        tokenIn = new MockERC20("Token In", "TIN", 18);
        tokenOut = new MockERC20("Token Out", "TOUT", 18);
        console.log("Mock tokens deployed");

        // Deploy actual ICC
        icc = new IncentiveCalculationContract();
        console.log("ICC deployed");

        // Create mock price feeds with different price values (1 token = $1)
        mockFeedSuperAssetShares1 = new MockAggregator(1e8, 8); // Token/USD = $1
        mockFeed1 = new MockAggregator(1e8, 8); // Token/USD = $1
        mockFeed2 = new MockAggregator(1e8, 8); // Token/USD = $1
        mockFeed3 = new MockAggregator(1e8, 8); // Token/USD = $1
        mockFeed4 = new MockAggregator(1e8, 8); // Token/USD = $1
        mockFeed5 = new MockAggregator(1e8, 8); // Token/USD = $1
        mockFeed6 = new MockAggregator(1e8, 8); // Token/USD = $1
        console.log("Mock feeds deployed");

        // Update timestamps to ensure prices are fresh
        mockFeedSuperAssetShares1.setUpdatedAt(block.timestamp);
        mockFeed1.setUpdatedAt(block.timestamp);
        mockFeed2.setUpdatedAt(block.timestamp);
        mockFeed3.setUpdatedAt(block.timestamp);
        mockFeed4.setUpdatedAt(block.timestamp);
        mockFeed5.setUpdatedAt(block.timestamp);
        mockFeed6.setUpdatedAt(block.timestamp);
        console.log("Feed timestamps updated");

        // Setup oracle parameters with regular providers
        address[] memory bases = new address[](7);
        bases[0] = address(tokenIn);
        bases[1] = address(tokenIn);
        bases[2] = address(tokenIn);
        bases[3] = address(tokenOut);
        bases[4] = address(tokenOut);
        bases[5] = address(tokenOut);
        bases[6] = address(superAsset);

        address[] memory quotes = new address[](7);
        quotes[0] = USD;
        quotes[1] = USD;
        quotes[2] = USD;
        quotes[3] = USD;
        quotes[4] = USD;
        quotes[5] = USD;
        quotes[6] = USD;

        bytes32[] memory providers = new bytes32[](7);
        providers[0] = PROVIDER_1;
        providers[1] = PROVIDER_2;
        providers[2] = PROVIDER_3;
        providers[3] = PROVIDER_4;
        providers[4] = PROVIDER_5;
        providers[5] = PROVIDER_6;
        providers[6] = PROVIDER_SUPERASSET;

        address[] memory feeds = new address[](7);
        feeds[0] = address(mockFeed1);
        feeds[1] = address(mockFeed2);
        feeds[2] = address(mockFeed3);
        feeds[3] = address(mockFeed4);
        feeds[4] = address(mockFeed5);
        feeds[5] = address(mockFeed6);
        feeds[6] = address(mockFeedSuperAssetShares1);

        // Deploy and configure oracle with regular providers only
        oracle = new SuperOracle(admin, bases, quotes, providers, feeds);
        oracle.setMaxStaleness(2 weeks);
        console.log("Oracle deployed");

        // Set staleness for each feed
        oracle.setFeedMaxStaleness(address(mockFeed1), 1 days);
        oracle.setFeedMaxStaleness(address(mockFeed2), 1 days);
        oracle.setFeedMaxStaleness(address(mockFeed3), 1 days);
        oracle.setFeedMaxStaleness(address(mockFeed4), 1 days);
        oracle.setFeedMaxStaleness(address(mockFeed5), 1 days);
        oracle.setFeedMaxStaleness(address(mockFeed6), 1 days);
        oracle.setFeedMaxStaleness(address(mockFeedSuperAssetShares1), 1 days);
        console.log("Feed staleness set");

        // Deploy contracts
        vm.startPrank(admin);
        
        // Deploy and initialize AssetBank
        assetBank = new AssetBank();
        console.log("AssetBank deployed");

        // Deploy and initialize IncentiveFund
        incentiveFund = new IncentiveFundContract();
        console.log("IncentiveFund deployed");

        // Initialize SuperAsset
        console.log("About to initialize SuperAsset");
        superAsset.initialize(
            "SuperAsset", // name
            "SA", // symbol
            address(icc), // icc
            address(incentiveFund), // ifc
            address(assetBank), // assetBank
            100, // swapFeeInPercentage (0.1%)
            100 // swapFeeOutPercentage (0.1%)
        );
        console.log("SuperAsset initialized");

        // Initialize IncentiveFund after SuperAsset is initialized
        incentiveFund.initialize(address(superAsset), address(assetBank));

        // Setup roles and configuration
        superAsset.grantRole(superAsset.VAULT_MANAGER_ROLE(), admin);
        superAsset.setSuperOracle(address(oracle));
        superAsset.whitelistERC20(address(tokenIn));
        assertEq(superAsset.isSupportedERC20(address(tokenIn)), true, "Token In should be whitelisted");
        superAsset.whitelistERC20(address(tokenOut));
        assertEq(superAsset.isSupportedERC20(address(tokenOut)), true, "Token Out should be whitelisted");
        superAsset.whitelistERC20(address(superAsset));
        assertEq(superAsset.isSupportedERC20(address(superAsset)), true, "SuperAsset should be whitelisted");

        // Grant necessary roles
        bytes32 INCENTIVE_FUND_MANAGER = incentiveFund.INCENTIVE_FUND_MANAGER();
        incentiveFund.grantRole(INCENTIVE_FUND_MANAGER, manager);
        assetBank.grantRole(assetBank.INCENTIVE_FUND_MANAGER(), address(incentiveFund));
        superAsset.grantRole(superAsset.INCENTIVE_FUND_MANAGER(), address(incentiveFund));
        superAsset.grantRole(superAsset.MINTER_ROLE(), address(incentiveFund));
        superAsset.grantRole(superAsset.BURNER_ROLE(), address(incentiveFund));

        // Set up initial token balances
        tokenIn.mint(user, 1000e18);
        tokenIn.mint(address(incentiveFund), 1000e18);
        tokenOut.mint(user, 1000e18);
        tokenOut.mint(address(incentiveFund), 1000e18);

        tokenIn.mint(user11, 1000e18);
        tokenOut.mint(user11, 1000e18);
        vm.stopPrank();
    }

    // --- Test: Initialization ---
    function test_Initialize() public {
        assertEq(superAsset.name(), "SuperAsset");
        assertEq(superAsset.symbol(), "SA");
        assertEq(superAsset.incentiveCalculationContract(), address(icc));
        assertEq(superAsset.incentiveFundContract(), address(incentiveFund));
        assertEq(superAsset.assetBank(), address(assetBank));
        assertEq(superAsset.swapFeeInPercentage(), 100);
        assertEq(superAsset.swapFeeOutPercentage(), 100);
    }

    function test_Initialize_RevertIfAlreadyInitialized() public {
        vm.expectRevert(ISuperAsset.ALREADY_INITIALIZED.selector);
        superAsset.initialize(
            "SuperAsset", // name
            "SA", // symbol
            address(icc), // icc
            address(incentiveFund), // ifc
            address(assetBank), // assetBank
            100, // swapFeeInPercentage
            100 // swapFeeOutPercentage
        );
    }

    // --- Test: Role Management ---
    function test_OnlyAdminCanGrantRoles() public {
        address newManager = makeAddr("newManager");
        console.log("test_OnlyAdminCanGrantRoles Start()");
        
        // Non-admin cannot grant roles
        vm.startPrank(user);
        console.log("User = ", user);
        // NOTE: This test is not passing, but not sure why since according to the logs it should pass
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                superAsset.DEFAULT_ADMIN_ROLE()
            )
        );
        superAsset.grantRole(superAsset.VAULT_MANAGER_ROLE(), newManager);
        vm.stopPrank();
        console.log("T1");

        // Admin can grant roles
        vm.startPrank(admin);
        superAsset.grantRole(superAsset.VAULT_MANAGER_ROLE(), newManager);
        vm.stopPrank();
        console.log("T3");

        assertTrue(superAsset.hasRole(superAsset.VAULT_MANAGER_ROLE(), newManager));
    }

    // --- Test: Token Management ---
    function test_OnlyVaultManagerCanWhitelistTokens() public {
        address newToken = makeAddr("newToken");

        // Non-manager cannot whitelist
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                superAsset.VAULT_MANAGER_ROLE()
            )
        );
        superAsset.whitelistERC20(newToken);
        vm.stopPrank();

        // Manager can whitelist
        vm.startPrank(admin); // admin has VAULT_MANAGER_ROLE
        superAsset.whitelistERC20(newToken);
        vm.stopPrank();

        assertTrue(superAsset.isSupportedERC20(newToken));
    }

    // --- Test: Oracle Integration ---
    function test_OnlyAdminCanSetOracle() public {
        address newOracle = makeAddr("newOracle");

        // Non-admin cannot set oracle
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                superAsset.DEFAULT_ADMIN_ROLE()
            )
        );
        superAsset.setSuperOracle(newOracle);
        vm.stopPrank();

        // Admin can set oracle
        vm.startPrank(admin);
        superAsset.setSuperOracle(newOracle);
        vm.stopPrank();

        assertEq(address(superAsset.superOracle()), newOracle);
    }

    // --- Test: Fee Management ---
    function test_OnlyAdminCanSetSwapFees() public {
        uint256 newFee = 500; // 5%

        // Non-admin cannot set fees
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                superAsset.DEFAULT_ADMIN_ROLE()
            )
        );
        superAsset.setSwapFeeInPercentage(newFee);
        vm.stopPrank();

        // Admin can set fees
        vm.startPrank(admin);
        superAsset.setSwapFeeInPercentage(newFee);
        vm.stopPrank();

        assertEq(superAsset.swapFeeInPercentage(), newFee);
    }

    function test_CannotSetFeesAboveMaximum() public {
        uint256 tooHighFee = superAsset.MAX_SWAP_FEE_PERCENTAGE() + 1;

        vm.startPrank(admin);
        vm.expectRevert(ISuperAsset.INVALID_SWAP_FEE_PERCENTAGE.selector);
        superAsset.setSwapFeeInPercentage(tooHighFee);
        vm.stopPrank();
    }

    // --- Test: Deposit ---
    function test_BasicDeposit() public {
        uint256 depositAmount = 100e18;
        uint256 minSharesOut = 99e18; // Allowing for 1% slippage
        assertEq(superAsset.isSupportedERC20(address(tokenIn)), true, "Token In should be whitelisted");
        assertEq(superAsset.isSupportedERC20(address(tokenOut)), true, "Token Out should be whitelisted");

        // Approve tokens
        vm.startPrank(user);
        tokenIn.approve(address(superAsset), depositAmount);

        (uint256 expAmountSharesMinted, uint256 expSwapFee, int256 expAmountIncentiveUSDDeposit) = 
            superAsset.previewDeposit(address(tokenIn), depositAmount);

        // Deposit tokens
        (uint256 amountSharesMinted, uint256 swapFee, int256 amountIncentiveUSDDeposit) = 
            superAsset.deposit(user, address(tokenIn), depositAmount, minSharesOut);
        vm.stopPrank();
        assertEq(expAmountSharesMinted, amountSharesMinted);
        assertEq(expSwapFee, swapFee);
        assertEq(expAmountIncentiveUSDDeposit, amountIncentiveUSDDeposit);


        // Verify results
        assertGt(amountSharesMinted, 0, "Should mint shares");
        assertEq(swapFee, (depositAmount * superAsset.swapFeeInPercentage()) / superAsset.SWAP_FEE_PERC(), "Incorrect swap fee");
        assertTrue(superAsset.balanceOf(user) > 0, "User should have shares");
    }

    function test_DepositWithZeroAmount() public {
        vm.startPrank(user);
        vm.expectRevert(ISuperAsset.ZERO_AMOUNT.selector);
        superAsset.deposit(user, address(tokenIn), 0, 0);
        vm.stopPrank();
    }

    function test_DepositWithUnsupportedToken() public {
        address unsupportedToken = makeAddr("unsupportedToken");
        vm.startPrank(user);
        vm.expectRevert(ISuperAsset.NOT_SUPPORTED_TOKEN.selector);
        superAsset.deposit(user, unsupportedToken, 100e18, 0);
        vm.stopPrank();
    }

    function test_DepositWithZeroAddress() public {
        vm.startPrank(user);
        vm.expectRevert(ISuperAsset.ZERO_ADDRESS.selector);
        superAsset.deposit(address(0), address(tokenIn), 100e18, 0);
        vm.stopPrank();
    }

    function test_DepositSlippageProtection() public {
        uint256 depositAmount = 100e18;
        uint256 tooHighMinSharesOut = 101e18; // Requiring more shares than possible

        vm.startPrank(user);
        tokenIn.approve(address(superAsset), depositAmount);

        vm.expectRevert(ISuperAsset.SLIPPAGE_PROTECTION.selector);
        superAsset.deposit(user, address(tokenIn), depositAmount, tooHighMinSharesOut);
        vm.stopPrank();
    }

    // --- Test: Redeem ---
    function test_BasicRedeem() public {
        // First deposit to get some shares
        uint256 depositAmount = 100e18;
        (uint256 expSharesMinted, uint256 expSwapFee, int256 expAmountIncentiveUSD) = superAsset.previewDeposit(address(tokenIn), depositAmount);
        vm.startPrank(user);
        tokenIn.approve(address(superAsset), depositAmount);
        (uint256 sharesMinted, uint256 swapFee, int256 amountIncentiveUSD) = superAsset.deposit(user, address(tokenIn), depositAmount, 0);
        assertEq(tokenIn.balanceOf(address(superAsset)), depositAmount - swapFee);
        assertEq(expSharesMinted, sharesMinted);
        assertEq(expSwapFee, swapFee);
        assertEq(expAmountIncentiveUSD, amountIncentiveUSD);
        // console.log("Deposit swapFee = ", swapFee);
        // console.log("Deposit amountIncentiveUSD = ", amountIncentiveUSD);
        // console.log("Deposit sharesMinted = ", sharesMinted);

        // Now redeem the shares
        uint256 amountTokenOutAfterFees;
        int256 amountIncentiveUSDRedeem;
        uint256 expAmountTokenOutAfterFees;
        int256 expAmountIncentiveUSDRedeem;
        uint256 sharesToRedeem = sharesMinted / 2;
        uint256 minTokenOut = sharesToRedeem * 99 / 100; // Allowing for 1% slippage

        (expAmountTokenOutAfterFees, expSwapFee, expAmountIncentiveUSDRedeem) = superAsset.previewRedeem(address(tokenIn), sharesToRedeem);
        assertGt(expAmountTokenOutAfterFees, 0, "Should receive tokens");
        assertGt(expSwapFee, 0, "Should pay swap fees");
        // assertGt(amountIncentiveUSDRedeem, 0, "Should receive incentives");
        console.log("test_BasicRedeem() Preview");

        (amountTokenOutAfterFees, swapFee, amountIncentiveUSDRedeem) = 
            superAsset.redeem(user, sharesToRedeem, address(tokenIn), minTokenOut);
        vm.stopPrank();
        
        assertEq(expAmountTokenOutAfterFees, amountTokenOutAfterFees);
        assertEq(expSwapFee, swapFee);
        assertEq(expAmountIncentiveUSDRedeem, amountIncentiveUSDRedeem);

        // console.log("test_BasicRedeem() Redeem");
        // console.log("Amount Token Out After Fees:", amountTokenOutAfterFees);
        // console.log("Swap Fee:", swapFee);
        // console.log("Amount Incentive USD Redeem:", amountIncentiveUSDRedeem);


        // Verify results
        assertGt(amountTokenOutAfterFees, 0, "Should receive tokens");
        assertEq(superAsset.balanceOf(user), sharesMinted - sharesToRedeem, "User should have no shares left");
    }

    function test_RedeemWithZeroAmount() public {
        vm.startPrank(user);
        vm.expectRevert(ISuperAsset.ZERO_AMOUNT.selector);
        superAsset.redeem(user, 0, address(tokenIn), 0);
        vm.stopPrank();
    }

    function test_RedeemWithUnsupportedToken() public {
        address unsupportedToken = makeAddr("unsupportedToken");
        vm.startPrank(user);
        vm.expectRevert(ISuperAsset.NOT_SUPPORTED_TOKEN.selector);
        superAsset.redeem(user, 100e18, unsupportedToken, 0);
        vm.stopPrank();
    }

    function test_RedeemWithZeroAddress() public {
        vm.startPrank(user);
        vm.expectRevert(ISuperAsset.ZERO_ADDRESS.selector);
        superAsset.redeem(address(0), 100e18, address(tokenIn), 0);
        vm.stopPrank();
    }

    function test_RedeemSlippageProtection() public {
        // First deposit to get some shares
        uint256 depositAmount = 100e18;
        vm.startPrank(user);
        tokenIn.approve(address(superAsset), depositAmount);
        (uint256 sharesMinted,,) = superAsset.deposit(user, address(tokenIn), depositAmount, 0);

        // Try to redeem with too high minimum output requirement
        uint256 tooHighMinTokenOut = 101e18; // Requiring more tokens than possible
        vm.expectRevert(ISuperAsset.SLIPPAGE_PROTECTION.selector);
        superAsset.redeem(user, sharesMinted, address(tokenIn), tooHighMinTokenOut);
        vm.stopPrank();
    }

    // --- Test: Incentive Handling ---
    // function test_DepositWithIncentives() public {
    //     uint256 depositAmount = 100e18;

    //     // Approve tokens
    //     vm.startPrank(user);
    //     tokenIn.approve(address(superAsset), depositAmount);

    //     // Deposit tokens and check incentive calculation
    //     (uint256 amountSharesMinted, uint256 swapFee, int256 amountIncentiveUSDDeposit) = 
    //         superAsset.deposit(user, address(tokenIn), depositAmount, 0);
    //     vm.stopPrank();

    //     // Verify incentive calculation
    //     assertTrue(amountIncentiveUSDDeposit != 0, "Should calculate incentives");

    //     // Check if incentives were settled with IncentiveFund
    //     // This would require mocking/checking the IncentiveFund contract's state
    //     // For now we just verify the event was emitted
    //     vm.expectEmit(true, true, true, true);
    //     emit Deposit(user, address(tokenIn), depositAmount, amountSharesMinted, swapFee, amountIncentiveUSDDeposit);
    // }

    // function test_RedeemWithIncentives() public {
    //     // First deposit to get shares
    //     uint256 depositAmount = 100e18;
    //     vm.startPrank(user);
    //     tokenIn.approve(address(superAsset), depositAmount);
    //     (uint256 sharesMinted,,) = superAsset.deposit(user, address(tokenIn), depositAmount, 0);

    //     // Redeem shares and check incentive calculation
    //     (uint256 amountTokenOutAfterFees, uint256 swapFee, int256 amountIncentiveUSDRedeem) = 
    //         superAsset.redeem(user, address(tokenIn), sharesMinted, 0);
    //     vm.stopPrank();

    //     // Verify incentive calculation
    //     assertTrue(amountIncentiveUSDRedeem != 0, "Should calculate incentives");

    //     // Check if incentives were settled with IncentiveFund
    //     vm.expectEmit(true, true, true, true);
    //     emit Redeem(user, address(tokenIn), sharesMinted, amountTokenOutAfterFees, swapFee, amountIncentiveUSDRedeem);
    // }

    struct BasiSwapStack{
        uint256 swapAmount;
        uint256 minTokenOut;
        uint256 expAmountTokenOutAfterFees;
        uint256 expSwapFeeIn;
        uint256 expSwapFeeOut;
        int256 expAmountIncentiveUSDDeposit;
        int256 expAmountIncentiveUSDRedeem;
        uint256 sharesMinted;
        uint256 swapFee;
        int256 amountIncentiveUSD;
    }

    // --- Test: Swap ---
    function test_BasicSwap() public {
        BasiSwapStack memory s;
        s.swapAmount = 100e18;
        s.minTokenOut = 99e18; // 1% slippage allowance

        vm.startPrank(user11);
        // We need enough tokenOut deposited
        tokenOut.approve(address(superAsset), s.swapAmount);
        (s.sharesMinted, s.swapFee, s.amountIncentiveUSD) = 
            superAsset.deposit(user11, address(tokenOut), s.swapAmount, 0);
        vm.stopPrank();
        assertEq(tokenOut.balanceOf(address(superAsset)), s.swapAmount - s.swapFee, "Should deposit tokenOut");
        assertEq(superAsset.balanceOf(user11), s.sharesMinted, "Should mint shares");

        (s.expAmountTokenOutAfterFees, s.expSwapFeeIn, s.expSwapFeeOut, 
        s.expAmountIncentiveUSDDeposit, s.expAmountIncentiveUSDRedeem) = 
            superAsset.previewSwap(address(tokenIn), s.swapAmount, address(tokenOut));
        assertGt(s.expAmountTokenOutAfterFees, 0, "Should receive output tokens");
        assertGt(s.expSwapFeeIn, 0, "Should charge deposit fee");
        assertGt(s.expSwapFeeOut, 0, "Should charge redeem fee");

        // NOTE: No incentives here
        // TODO: Check if correct
        assertTrue(s.expAmountIncentiveUSDDeposit == 0, "Should calculate deposit incentives");
        assertTrue(s.expAmountIncentiveUSDRedeem == 0, "Should calculate redeem incentives");

        console.log("test_BasicSwap() Preview");
        console.log("Amount Token Out After Fees:", s.expAmountTokenOutAfterFees);
        console.log("Swap Fee In:", s.expSwapFeeIn);
        console.log("Swap Fee Out:", s.expSwapFeeOut);
        console.log("Amount Incentive USD Deposit:", s.expAmountIncentiveUSDDeposit);
        console.log("Amount Incentive USD Redeem:", s.expAmountIncentiveUSDRedeem);

        // Approve tokens
        vm.startPrank(user);
        tokenIn.approve(address(superAsset), s.swapAmount);

        // Perform swap
        (uint256 amountSharesIntermediateStep, 
         uint256 amountTokenOutAfterFees, 
         uint256 swapFeeIn, 
         uint256 swapFeeOut, 
         int256 amountIncentivesIn, 
         int256 amountIncentivesOut) = 
            superAsset.swap(user, address(tokenIn), s.swapAmount, address(tokenOut), s.minTokenOut);

        vm.stopPrank();

        // Verify results
        assertGt(amountSharesIntermediateStep, 0, "Should create intermediate shares");
        assertGt(amountTokenOutAfterFees, 0, "Should receive output tokens");
        assertGt(swapFeeIn, 0, "Should charge deposit fee");
        assertGt(swapFeeOut, 0, "Should charge redeem fee");

        // NOTE: No incentives here
        // TODO: Check if correct
        assertTrue(amountIncentivesIn == 0, "Should calculate deposit incentives");
        assertTrue(amountIncentivesOut == 0, "Should calculate redeem incentives");
    }

    function test_SwapWithZeroAmount() public {
        vm.startPrank(user);
        vm.expectRevert(ISuperAsset.ZERO_AMOUNT.selector);
        superAsset.swap(user, address(tokenIn), 0, address(tokenOut), 0);
        vm.stopPrank();
    }

    function test_SwapWithUnsupportedToken() public {
        address unsupportedToken = makeAddr("unsupportedToken");
        vm.startPrank(user);
        vm.expectRevert(ISuperAsset.NOT_SUPPORTED_TOKEN.selector);
        superAsset.swap(user, unsupportedToken, 100e18, address(tokenOut), 0);
        vm.stopPrank();
    }

    function test_SwapWithZeroAddress() public {
        vm.startPrank(user);
        vm.expectRevert(ISuperAsset.ZERO_ADDRESS.selector);
        superAsset.swap(address(0), address(tokenIn), 100e18, address(tokenOut), 0);
        vm.stopPrank();
    }

    function test_SwapSlippageProtection() public {
        uint256 swapAmount = 100e18;
        uint256 tooHighMinTokenOut = 101e18; // Requiring more output than possible

        vm.startPrank(user);
        tokenIn.approve(address(superAsset), swapAmount);

        vm.expectRevert(ISuperAsset.SLIPPAGE_PROTECTION.selector);
        superAsset.swap(user, address(tokenIn), swapAmount, address(tokenOut), tooHighMinTokenOut);
        vm.stopPrank();
    }
}
