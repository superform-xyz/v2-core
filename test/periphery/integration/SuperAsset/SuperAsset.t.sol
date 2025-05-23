// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";
import "forge-std/console.sol";
import { SuperAsset } from "../../../../src/periphery/SuperAsset/SuperAsset.sol";
import { ISuperAsset } from "../../../../src/periphery/interfaces/SuperAsset/ISuperAsset.sol";
import { SuperGovernor } from "../../../../src/periphery/SuperGovernor.sol";
import { IncentiveFundContract } from "../../../../src/periphery/SuperAsset/IncentiveFundContract.sol";
import { IncentiveCalculationContract } from "../../../../src/periphery/SuperAsset/IncentiveCalculationContract.sol";
import { SuperOracle } from "../../../../src/periphery/oracles/SuperOracle.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { Mock4626Vault } from "../../../mocks/Mock4626Vault.sol";
import { MockAggregator } from "../../mocks/MockAggregator.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { Helpers } from "../../../utils/Helpers.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import { SuperAssetFactory, ISuperAssetFactory } from "../../../../src/periphery/SuperAsset/SuperAssetFactory.sol";

contract SuperAssetTest is Helpers {
    // --- Constants ---
    bytes32 public constant PROVIDER_1 = keccak256("PROVIDER_1");
    bytes32 public constant PROVIDER_2 = keccak256("PROVIDER_2");
    bytes32 public constant PROVIDER_3 = keccak256("PROVIDER_3");
    bytes32 public constant PROVIDER_4 = keccak256("PROVIDER_4");
    bytes32 public constant PROVIDER_5 = keccak256("PROVIDER_5");
    bytes32 public constant PROVIDER_6 = keccak256("PROVIDER_6");
    bytes32 public constant PROVIDER_SUPERASSET = keccak256("PROVIDER_SUPERASSET");
    bytes32 public constant PROVIDER_SUPERVAULT1 = keccak256("PROVIDER_SUPERVAULT1");
    bytes32 public constant PROVIDER_SUPERVAULT2 = keccak256("PROVIDER_SUPERVAULT2");

    address public constant USD = address(840);

    // --- State Variables ---
    SuperAsset public superAsset;
    SuperOracle public oracle;
    Mock4626Vault public tokenIn;
    Mock4626Vault public tokenOut;
    SuperAssetFactory public factory;
    MockERC20 public underlyingToken1;
    MockERC20 public underlyingToken2;
    MockAggregator public mockFeedSuperAssetShares1;
    MockAggregator public mockFeedSuperVault1Shares;
    MockAggregator public mockFeedSuperVault2Shares;
    MockAggregator public mockFeed1;
    MockAggregator public mockFeed2;
    MockAggregator public mockFeed3;
    MockAggregator public mockFeed4;
    MockAggregator public mockFeed5;
    MockAggregator public mockFeed6;
    IncentiveCalculationContract public icc;
    IncentiveFundContract public incentiveFund;
    SuperGovernor public superGovernor;
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
        // Deploy SuperGovernor first
        superGovernor = new SuperGovernor(
            admin, // superGovernor role
            admin, // governor role
            admin, // bankManager role
            makeAddr("treasury"), // treasury
            makeAddr("prover") // prover
        );
        console.log("SuperGovernor deployed");

        // Deploy mock tokens and vault
        underlyingToken1 = new MockERC20("Underlying Token1", "UTKN1", 18);
        tokenIn = new Mock4626Vault(address(underlyingToken1), "Vault Token", "vTKN");
        underlyingToken2 = new MockERC20("Underlying Token2", "UTKN2", 18);
        tokenOut = new Mock4626Vault(address(underlyingToken2), "Vault Token", "vTKN");
        console.log("Mock tokens deployed");

        // Deploy actual ICC
        icc = new IncentiveCalculationContract();
        console.log("ICC deployed");

        // Create mock price feeds with different price values (1 token = $1)
        mockFeedSuperAssetShares1 = new MockAggregator(1e8, 8); // Token/USD = $1
        mockFeedSuperVault1Shares = new MockAggregator(1e8, 8); // Token/USD = $1
        mockFeedSuperVault2Shares = new MockAggregator(1e8, 8); // Token/USD = $1

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
        address[] memory bases = new address[](9);
        bases[0] = address(underlyingToken1);
        bases[1] = address(underlyingToken1);
        bases[2] = address(underlyingToken1);
        bases[3] = address(underlyingToken2);
        bases[4] = address(underlyingToken2);
        bases[5] = address(underlyingToken2);
        bases[6] = address(superAsset);
        bases[7] = address(tokenIn);
        bases[8] = address(tokenOut);

        address[] memory quotes = new address[](9);
        quotes[0] = USD;
        quotes[1] = USD;
        quotes[2] = USD;
        quotes[3] = USD;
        quotes[4] = USD;
        quotes[5] = USD;
        quotes[6] = USD;
        quotes[7] = USD;
        quotes[8] = USD;

        bytes32[] memory providers = new bytes32[](9);
        providers[0] = PROVIDER_1;
        providers[1] = PROVIDER_2;
        providers[2] = PROVIDER_3;
        providers[3] = PROVIDER_4;
        providers[4] = PROVIDER_5;
        providers[5] = PROVIDER_6;
        providers[6] = PROVIDER_SUPERASSET;
        providers[7] = PROVIDER_SUPERVAULT1;
        providers[8] = PROVIDER_SUPERVAULT2;

        address[] memory feeds = new address[](9);
        feeds[0] = address(mockFeed1);
        feeds[1] = address(mockFeed2);
        feeds[2] = address(mockFeed3);
        feeds[3] = address(mockFeed4);
        feeds[4] = address(mockFeed5);
        feeds[5] = address(mockFeed6);
        feeds[6] = address(mockFeedSuperAssetShares1);
        feeds[7] = address(mockFeedSuperVault1Shares);
        feeds[8] = address(mockFeedSuperVault2Shares);

        // Deploy factory and contracts
        factory = new SuperAssetFactory(address(superGovernor));
        console.log("Factory deployed");
        superGovernor.setAddress(superGovernor.SUPER_ASSET_FACTORY(), address(factory));

        // Grant roles
        superGovernor.grantRole(superGovernor.SUPER_GOVERNOR_ROLE(), admin);
        superGovernor.grantRole(superGovernor.GOVERNOR_ROLE(), admin);
        superGovernor.grantRole(superGovernor.BANK_MANAGER_ROLE(), admin);
        console.log("SuperGovernor Roles Granted");

        // Create SuperAsset using factory
        ISuperAssetFactory.AssetCreationParams memory params = ISuperAssetFactory.AssetCreationParams({
            name: "SuperAsset",
            symbol: "SA",
            swapFeeInPercentage: 100, // 0.1% swap fee in
            swapFeeOutPercentage: 100, // 0.1% swap fee out
            superAssetManager: admin,
            superAssetStrategist: admin,
            incentiveFundManager: admin,
            incentiveCalculationContract: address(icc),
            tokenInIncentive: address(tokenIn),
            tokenOutIncentive: address(tokenOut)
        });

        // NOTE: Whitelisting ICC so that's possible to instantiate SuperAsset using it 
        superGovernor.addICCToWhitelist(address(icc));
        (address superAssetAddr, address incentiveFundAddr) = factory.createSuperAsset(params);
        vm.stopPrank();
        console.log("SuperAsset and IncentiveFund deployed via factory");
        superAsset = SuperAsset(superAssetAddr);
        incentiveFund = IncentiveFundContract(incentiveFundAddr);
        console.log("SuperAsset and IncentiveFund deployed via factory");

        // Add SuperOracle Init
        // NOTE: Initially superAsset was not defined, now it is because it gets instantiated with the factory
        bases[6] = address(superAsset);
        // Deploy and configure oracle with regular providers only
        console.log("Trying to deploy SuperOracle");
        vm.startPrank(admin);
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
        oracle.setFeedMaxStaleness(address(mockFeedSuperVault1Shares), 1 days);
        oracle.setFeedMaxStaleness(address(mockFeedSuperVault2Shares), 1 days);
        vm.stopPrank();

        console.log("Feed staleness set");

        // Set SuperAsset oracle
        vm.startPrank(admin);
        superAsset.setSuperOracle(address(oracle));
        superAsset.whitelistERC20(address(tokenIn));
        ISuperAsset.TokenData memory tokenData = superAsset.getTokenData(address(tokenIn));
        assertEq(tokenData.isSupportedERC20, true, "Token In should be whitelisted");
        superAsset.whitelistERC20(address(tokenOut));
        tokenData = superAsset.getTokenData(address(tokenOut));
        assertEq(tokenData.isSupportedERC20, true, "Token Out should be whitelisted");
        superAsset.whitelistERC20(address(superAsset));
        tokenData = superAsset.getTokenData(address(superAsset));
        assertEq(tokenData.isSupportedERC20, true, "SuperAsset should be whitelisted");
        vm.stopPrank();

        console.log("Start Minting");

        underlyingToken1.mint(user, 1000e18);
        underlyingToken2.mint(user, 1000e18);
        vm.startPrank(user);
        underlyingToken1.approve(address(tokenIn), 1000e18);
        tokenIn.deposit(1000e18, user);
        underlyingToken2.approve(address(tokenOut), 1000e18);
        tokenOut.deposit(1000e18, user);
        vm.stopPrank();
        assertGt(tokenIn.balanceOf(user), 0);
        assertGt(tokenOut.balanceOf(user), 0);

        underlyingToken1.mint(user11, 1000e18);
        underlyingToken2.mint(user11, 1000e18);
        vm.startPrank(user11);
        underlyingToken1.approve(address(tokenIn), 1000e18);
        tokenIn.deposit(1000e18, user11);
        underlyingToken2.approve(address(tokenOut), 1000e18);
        tokenOut.deposit(1000e18, user11);
        vm.stopPrank();
        assertGt(tokenIn.balanceOf(user11), 0);
        assertGt(tokenOut.balanceOf(user11), 0);

        vm.stopPrank();
    }

    // --- Test: Initialization ---
    function test_Initialize1() public view {
        assertEq(superAsset.name(), "SuperAsset");
        assertEq(superAsset.symbol(), "SA");
        assertEq(superAsset.swapFeeInPercentage(), 100);
        assertEq(superAsset.swapFeeOutPercentage(), 100);
    }

    function test_Initialize_RevertIfAlreadyInitialized() public {
        vm.expectRevert(ISuperAsset.ALREADY_INITIALIZED.selector);
        superAsset.initialize(
            "SuperAsset", // name
            "SA", // symbol
            address(superGovernor),
            100, // swapFeeInPercentage
            100 // swapFeeOutPercentage
        );
    }
    // --- Test: Token Management ---

    function test_OnlyVaultManagerCanWhitelistTokens() public {
        address newToken = makeAddr("newToken");

        // Non-manager cannot whitelist
        vm.startPrank(user);
        vm.expectRevert(ISuperAsset.UNAUTHORIZED.selector);
        superAsset.whitelistERC20(newToken);
        vm.stopPrank();

        // Manager can whitelist
        vm.startPrank(admin); // admin has VAULT_MANAGER_ROLE
        superAsset.whitelistERC20(newToken);
        vm.stopPrank();

        ISuperAsset.TokenData memory tokenData = superAsset.getTokenData(newToken);
        assertTrue(tokenData.isSupportedERC20);
    }

    // --- Test: Oracle Integration ---
    function test_OnlyAdminCanSetOracle() public {
        address newOracle = makeAddr("newOracle");

        // Non-admin cannot set oracle
        vm.startPrank(user);
        vm.expectRevert(ISuperAsset.UNAUTHORIZED.selector);
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
        vm.expectRevert(ISuperAsset.UNAUTHORIZED.selector);
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
    function test_BasicDepositSimple() public {
        console.log("test_BasicDepositSimple() Start");
        uint256 depositAmount = 100e18;
        uint256 minSharesOut = 99e18; // Allowing for 1% slippage
        ISuperAsset.TokenData memory tokenData = superAsset.getTokenData(address(tokenIn));
        assertTrue(tokenData.isSupportedERC20);
        ISuperAsset.TokenData memory tokenData2 = superAsset.getTokenData(address(tokenOut));
        assertTrue(tokenData2.isSupportedERC20);

        // Approve tokens
        vm.startPrank(user);
        tokenIn.approve(address(superAsset), depositAmount);

        (uint256 expAmountSharesMinted, uint256 expSwapFee, int256 expAmountIncentiveUSDDeposit, bool isSuccess) =
            superAsset.previewDeposit(address(tokenIn), depositAmount, false);
        assertEq(isSuccess, false, "isSuccess should be false, because of zero initial allocation");

        console.log("test_BasicDepositSimple() Preview");
        console.log("Amount Shares Minted:", expAmountSharesMinted);
        console.log("Swap Fee:", expSwapFee);
        console.log("Amount Incentive USD Deposit:", expAmountIncentiveUSDDeposit);

        // Deposit tokens
        (uint256 amountSharesMinted, uint256 swapFee, int256 amountIncentiveUSDDeposit) =
            superAsset.deposit(user, address(tokenIn), depositAmount, minSharesOut);
        vm.stopPrank();
        assertEq(expAmountSharesMinted, amountSharesMinted);
        assertEq(expSwapFee, swapFee);
        assertEq(expAmountIncentiveUSDDeposit, amountIncentiveUSDDeposit);
        console.log("test_BasicDepositSimple() Deposit");
        console.log("Amount Shares Minted:", amountSharesMinted);
        console.log("Swap Fee:", swapFee);
        console.log("Amount Incentive USD Deposit:", amountIncentiveUSDDeposit);
        console.log("test_BasicDepositSimple() End");

        // Verify results
        assertGt(amountSharesMinted, 0, "Should mint shares");
        assertEq(
            swapFee,
            (depositAmount * superAsset.swapFeeInPercentage()) / superAsset.SWAP_FEE_PERC(),
            "Incorrect swap fee"
        );
        assertTrue(superAsset.balanceOf(user) > 0, "User should have shares");
    }

    struct BasicDepositWithCircuitBreaker {
        uint256 depositAmount;
        uint256 minSharesOut;
        int256 currentPrice;
        uint256 priceUSD;
        bool isDepeg;
        bool isDispersion;
        bool isOracleOff;
    }

    function test_BasicDepositWithCircuitBreaker() public {
        console.log("test_BasicDepositWithCircuitBreaker() Start");
        BasicDepositWithCircuitBreaker memory s;
        s.depositAmount = 100e18;
        s.minSharesOut = 99e18; // Allowing for 1% slippage
        ISuperAsset.TokenData memory tokenData = superAsset.getTokenData(address(tokenIn));
        assertTrue(tokenData.isSupportedERC20);
        ISuperAsset.TokenData memory tokenData2 = superAsset.getTokenData(address(tokenOut));
        assertTrue(tokenData2.isSupportedERC20);

        // Approve tokens
        vm.startPrank(user);
        tokenIn.approve(address(superAsset), s.depositAmount);

        (, s.currentPrice,,,) = mockFeed2.latestRoundData();
        mockFeed2.setAnswer(s.currentPrice * 3);
        (, s.currentPrice,,,) = mockFeed3.latestRoundData();
        mockFeed3.setAnswer(s.currentPrice * 5);

        (s.priceUSD, s.isDepeg, s.isDispersion, s.isOracleOff) =
            superAsset.getPriceWithCircuitBreakers(IERC4626(tokenIn).asset());
        assertEq(s.isDepeg, true);
        assertEq(s.isDispersion, true);
        assertEq(s.isOracleOff, false);
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
        (uint256 expSharesMinted, uint256 expSwapFee, int256 expAmountIncentiveUSD, bool isSuccess) =
            superAsset.previewDeposit(address(tokenIn), depositAmount, false);
        vm.startPrank(user);
        tokenIn.approve(address(superAsset), depositAmount);
        (uint256 sharesMinted, uint256 swapFee, int256 amountIncentiveUSD) =
            superAsset.deposit(user, address(tokenIn), depositAmount, 0);
        assertEq(tokenIn.balanceOf(address(superAsset)), depositAmount - swapFee);
        assertEq(expSharesMinted, sharesMinted);
        assertEq(expSwapFee, swapFee);
        assertEq(expAmountIncentiveUSD, amountIncentiveUSD);

        // Now redeem the shares
        uint256 amountTokenOutAfterFees;
        int256 amountIncentiveUSDRedeem;
        uint256 expAmountTokenOutAfterFees;
        int256 expAmountIncentiveUSDRedeem;
        uint256 sharesToRedeem = sharesMinted / 2;
        uint256 minTokenOut = sharesToRedeem * 99 / 100; // Allowing for 1% slippage

        (expAmountTokenOutAfterFees, expSwapFee, expAmountIncentiveUSDRedeem, isSuccess) =
            superAsset.previewRedeem(address(tokenIn), sharesToRedeem, false);
        assertGt(expAmountTokenOutAfterFees, 0, "Should receive tokens");
        assertGt(expSwapFee, 0, "Should pay swap fees");

        (amountTokenOutAfterFees, swapFee, amountIncentiveUSDRedeem) =
            superAsset.redeem(user, sharesToRedeem, address(tokenIn), minTokenOut);
        vm.stopPrank();

        assertEq(expAmountTokenOutAfterFees, amountTokenOutAfterFees);
        assertEq(expSwapFee, swapFee);
        assertEq(expAmountIncentiveUSDRedeem, amountIncentiveUSDRedeem);

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

    struct BasiSwapStack {
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
        bool isSuccess;
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

        (
            s.expAmountTokenOutAfterFees,
            s.expSwapFeeIn,
            s.expSwapFeeOut,
            s.expAmountIncentiveUSDDeposit,
            s.expAmountIncentiveUSDRedeem,
            s.isSuccess
        ) = superAsset.previewSwap(address(tokenIn), s.swapAmount, address(tokenOut), false);
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
        (
            uint256 amountSharesIntermediateStep,
            uint256 amountTokenOutAfterFees,
            uint256 swapFeeIn,
            uint256 swapFeeOut,
            int256 amountIncentivesIn,
            int256 amountIncentivesOut
        ) = superAsset.swap(user, address(tokenIn), s.swapAmount, address(tokenOut), s.minTokenOut);

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
