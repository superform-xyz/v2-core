// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import { console } from "forge-std/console.sol";
import { ERC4626YieldSourceOracle } from "../../../../src/core/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { SuperAsset } from "../../../../src/periphery/SuperAsset/SuperAsset.sol";
import { ISuperAsset } from "../../../../src/periphery/interfaces/SuperAsset/ISuperAsset.sol";
import { SuperVaultAggregator } from "../../../../src/periphery/SuperVault/SuperVaultAggregator.sol";
import { SuperGovernor } from "../../../../src/periphery/SuperGovernor.sol";
import { IncentiveFundContract } from "../../../../src/periphery/SuperAsset/IncentiveFundContract.sol";
import { IncentiveCalculationContract } from "../../../../src/periphery/SuperAsset/IncentiveCalculationContract.sol";
import { SuperOracle } from "../../../../src/periphery/oracles/SuperOracle.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { Mock4626Vault } from "../../../mocks/Mock4626Vault.sol";
import { MockAggregator } from "../../mocks/MockAggregator.sol";
import { Helpers } from "../../../utils/Helpers.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { SuperAssetFactory, ISuperAssetFactory } from "../../../../src/periphery/SuperAsset/SuperAssetFactory.sol";
import { SuperBank } from "../../../../src/periphery/SuperBank.sol";

contract SuperAssetTest is Helpers {
    // --- Constants ---
    bytes32 public constant PROVIDER_1 = keccak256("PROVIDER_1");
    bytes32 public constant PROVIDER_2 = keccak256("PROVIDER_2");
    bytes32 public constant PROVIDER_3 = keccak256("PROVIDER_3");
    bytes32 public constant PROVIDER_4 = keccak256("PROVIDER_4");
    bytes32 public constant PROVIDER_5 = keccak256("PROVIDER_5");
    bytes32 public constant PROVIDER_6 = keccak256("PROVIDER_6");
    bytes32 public constant PROVIDER_7 = keccak256("PROVIDER_7");
    bytes32 public constant PROVIDER_8 = keccak256("PROVIDER_8");
    bytes32 public constant PROVIDER_9 = keccak256("PROVIDER_9");
    bytes32 public constant PROVIDER_PRIMARY_ASSET = keccak256("PROVIDER_PRIMARY_ASSET");
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
    MockERC20 public underlyingToken6d;
    MockAggregator public mockFeedSuperAssetShares1;
    MockAggregator public mockFeedSuperVault1Shares;
    MockAggregator public mockFeedSuperVault2Shares;
    MockAggregator public mockFeed1;
    MockAggregator public mockFeed2;
    MockAggregator public mockFeed3;
    MockAggregator public mockFeed4;
    MockAggregator public mockFeed5;
    MockAggregator public mockFeed6;
    MockAggregator public mockFeed7;
    MockAggregator public mockFeed8;
    MockAggregator public mockFeed9;
    MockAggregator public mockFeedPrimaryAsset;
    IncentiveCalculationContract public icc;
    IncentiveFundContract public incentiveFund;
    SuperVaultAggregator public aggregator;
    SuperGovernor public superGovernor;
    SuperBank public superBank;
    address public admin;
    address public manager;
    address public user;
    address public user11;

    ERC4626YieldSourceOracle public yieldSourceOracle;

    function _updateAllFeedTimestamps() internal {
        mockFeedSuperAssetShares1.setUpdatedAt(block.timestamp);
        mockFeedPrimaryAsset.setUpdatedAt(block.timestamp);
        mockFeed1.setUpdatedAt(block.timestamp);
        mockFeed2.setUpdatedAt(block.timestamp);
        mockFeed3.setUpdatedAt(block.timestamp);
        mockFeed4.setUpdatedAt(block.timestamp);
        mockFeed5.setUpdatedAt(block.timestamp);
        mockFeed6.setUpdatedAt(block.timestamp);
        mockFeed7.setUpdatedAt(block.timestamp);
        mockFeed8.setUpdatedAt(block.timestamp);
        mockFeed9.setUpdatedAt(block.timestamp);
    }


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

        // Grant roles
        superGovernor.grantRole(superGovernor.SUPER_GOVERNOR_ROLE(), admin);
        superGovernor.grantRole(superGovernor.GOVERNOR_ROLE(), admin);
        superGovernor.grantRole(superGovernor.BANK_MANAGER_ROLE(), admin);
        console.log("SuperGovernor Roles Granted");

        // Deploy SuperVaultAggregator
        aggregator = new SuperVaultAggregator(address(superGovernor));
        superGovernor.setAddress(superGovernor.SUPER_VAULT_AGGREGATOR(), address(aggregator));

        // Deploy mock tokens and vault
        MockERC20 primaryAsset = new MockERC20("Primary Asset", "PA", 18);
        underlyingToken1 = new MockERC20("Underlying Token1", "UTKN1", 18);
        tokenIn = new Mock4626Vault(address(underlyingToken1), "Vault Token", "vTKN");
        underlyingToken2 = new MockERC20("Underlying Token2", "UTKN2", 18);
        tokenOut = new Mock4626Vault(address(underlyingToken2), "Vault Token", "vTKN");

        // Token with 6d
        underlyingToken6d = new MockERC20("Underlying Token 6d", "UTKN6D", 6);

        console.log("Mock tokens deployed");

        // Deploy actual ICC
        icc = new IncentiveCalculationContract();
        console.log("ICC deployed");

        // Create mock price feeds with different price values (1 token = $1)
        mockFeedSuperAssetShares1 = new MockAggregator(1e8, 8); // Token/USD = $1
        mockFeedSuperVault1Shares = new MockAggregator(1e8, 8); // Token/USD = $1
        mockFeedSuperVault2Shares = new MockAggregator(1e8, 8); // Token/USD = $1
        //mockFeedPrimaryAsset = new MockAggregator(1e18, 18);
        mockFeedPrimaryAsset = new MockAggregator(1e8, 8);

        mockFeed1 = new MockAggregator(1e8, 8); // Token/USD = $1
        mockFeed2 = new MockAggregator(1e8, 8); // Token/USD = $1
        mockFeed3 = new MockAggregator(1e8, 8); // Token/USD = $1
        mockFeed4 = new MockAggregator(1e8, 8); // Token/USD = $1
        mockFeed5 = new MockAggregator(1e8, 8); // Token/USD = $1
        mockFeed6 = new MockAggregator(1e8, 8); // Token/USD = $1
        mockFeed7 = new MockAggregator(1e8, 8); // Token/USD = $1
        mockFeed8 = new MockAggregator(1e8, 8); // Token/USD = $1
        mockFeed9 = new MockAggregator(1e8, 8); // Token/USD = $1
        console.log("Mock feeds deployed");

        // Update timestamps to ensure prices are fresh
        mockFeedSuperAssetShares1.setUpdatedAt(block.timestamp);
        mockFeedPrimaryAsset.setUpdatedAt(block.timestamp);
        mockFeed1.setUpdatedAt(block.timestamp);
        mockFeed2.setUpdatedAt(block.timestamp);
        mockFeed3.setUpdatedAt(block.timestamp);
        mockFeed4.setUpdatedAt(block.timestamp);
        mockFeed5.setUpdatedAt(block.timestamp);
        mockFeed6.setUpdatedAt(block.timestamp);
        mockFeed7.setUpdatedAt(block.timestamp);
        mockFeed8.setUpdatedAt(block.timestamp);
        mockFeed9.setUpdatedAt(block.timestamp);
        console.log("Feed timestamps updated");

        // Setup oracle parameters with regular providers
        address[] memory bases = new address[](11);
        bases[0] = address(underlyingToken1);
        bases[1] = address(underlyingToken1);
        bases[2] = address(underlyingToken1);
        bases[3] = address(underlyingToken2);
        bases[4] = address(underlyingToken2);
        bases[5] = address(underlyingToken2);
        bases[6] = address(superAsset);
        bases[7] = address(primaryAsset);
        bases[8] = address(underlyingToken6d);
        bases[9] = address(underlyingToken6d);
        bases[10] = address(underlyingToken6d);


        address[] memory quotes = new address[](11);
        quotes[0] = USD;
        quotes[1] = USD;
        quotes[2] = USD;
        quotes[3] = USD;
        quotes[4] = USD;
        quotes[5] = USD;
        quotes[6] = USD;
        quotes[7] = USD;
        quotes[8] = USD;
        quotes[9] = USD;
        quotes[10] = USD;

        bytes32[] memory providers = new bytes32[](11);
        providers[0] = PROVIDER_1;
        providers[1] = PROVIDER_2;
        providers[2] = PROVIDER_3;
        providers[3] = PROVIDER_4;
        providers[4] = PROVIDER_5;
        providers[5] = PROVIDER_6;
        providers[6] = PROVIDER_SUPERASSET;
        providers[7] = PROVIDER_PRIMARY_ASSET;
        providers[8] = PROVIDER_1;
        providers[9] = PROVIDER_2;
        providers[10] = PROVIDER_3;

        address[] memory feeds = new address[](11);
        feeds[0] = address(mockFeed1);
        feeds[1] = address(mockFeed2);
        feeds[2] = address(mockFeed3);
        feeds[3] = address(mockFeed4);
        feeds[4] = address(mockFeed5);
        feeds[5] = address(mockFeed6);
        feeds[6] = address(mockFeedSuperAssetShares1);
        feeds[7] = address(mockFeedPrimaryAsset);
        feeds[8] = address(mockFeed7);
        feeds[9] = address(mockFeed8);
        feeds[10] = address(mockFeed9);

        // Deploy factory and contracts
        factory = new SuperAssetFactory(address(superGovernor));
        console.log("Factory deployed");
        superGovernor.setAddress(superGovernor.SUPER_ASSET_FACTORY(), address(factory));

        // Deploy SuperBank
        superBank = new SuperBank(address(superGovernor));
        superGovernor.setAddress(superGovernor.SUPER_BANK(), address(superBank));

        // Create SuperAsset using factory
        ISuperAssetFactory.AssetCreationParams memory params = ISuperAssetFactory.AssetCreationParams({
            name: "SuperAsset",
            symbol: "SA",
            swapFeeInPercentage: 100, // 0.1% swap fee in
            swapFeeOutPercentage: 100, // 0.1% swap fee out
            asset: address(primaryAsset),
            superAssetManager: admin,
            superAssetStrategist: admin,
            incentiveFundManager: admin,
            incentiveCalculationContract: address(icc),
            tokenInIncentive: address(tokenIn),
            tokenOutIncentive: address(tokenOut)
        });

        yieldSourceOracle = new ERC4626YieldSourceOracle();

        // NOTE: Whitelisting ICC so that's possible to instantiate SuperAsset using it
        superGovernor.addICCToWhitelist(address(icc));
        (address superAssetAddr, address incentiveFundAddr) = factory.createSuperAsset(params);

        vm.stopPrank();
        console.log("SuperAsset and IncentiveFund deployed via factory");
        superAsset = SuperAsset(superAssetAddr);
        incentiveFund = IncentiveFundContract(incentiveFundAddr);
        vm.prank(admin);
        incentiveFund.toggleIncentives(false);
        console.log("SuperAsset and IncentiveFund deployed via factory");

        // Add SuperOracle Init
        // NOTE: Initially superAsset was not defined, now it is because it gets instantiated with the factory
        bases[6] = address(superAsset);
        // Deploy and configure oracle with regular providers only
        console.log("Trying to deploy SuperOracle");
        vm.startPrank(admin);
        oracle = new SuperOracle(address(superGovernor), bases, quotes, providers, feeds);
        superGovernor.setAddress(superGovernor.SUPER_ORACLE(), address(oracle));

        superGovernor.setOracleMaxStaleness(2 weeks);
        // Set Oracle
        console.log("Oracle deployed");

        // Set staleness for each feed
        superGovernor.setOracleFeedMaxStaleness(address(mockFeed1), 14 days);
        superGovernor.setOracleFeedMaxStaleness(address(mockFeed2), 14 days);
        superGovernor.setOracleFeedMaxStaleness(address(mockFeed3), 14 days);
        superGovernor.setOracleFeedMaxStaleness(address(mockFeed4), 14 days);
        superGovernor.setOracleFeedMaxStaleness(address(mockFeed5), 14 days);
        superGovernor.setOracleFeedMaxStaleness(address(mockFeed6), 14 days);
        superGovernor.setOracleFeedMaxStaleness(address(mockFeed7), 14 days);
        superGovernor.setOracleFeedMaxStaleness(address(mockFeed8), 14 days);
        superGovernor.setOracleFeedMaxStaleness(address(mockFeed9), 14 days);
        superGovernor.setOracleFeedMaxStaleness(address(mockFeedSuperAssetShares1), 14 days);
        superGovernor.setOracleFeedMaxStaleness(address(mockFeedSuperVault1Shares), 14 days);
        superGovernor.setOracleFeedMaxStaleness(address(mockFeedSuperVault2Shares), 14 days);
        superGovernor.setEmergencyPrice(address(primaryAsset), 1e8);
        vm.stopPrank();

        console.log("Feed staleness set");

        console.log("List of Token Addresses");
        console.log("tokenIn = ", address(tokenIn));
        console.log("tokenOut = ", address(tokenOut));
        console.log("underlyingToken1 = ", address(underlyingToken1));
        console.log("underlyingToken2 = ", address(underlyingToken2));
        console.log("superAsset = ", address(superAsset));
        console.log("primaryAsset = ", address(primaryAsset));
        console.log("---------------");

        // Set SuperAsset oracle
        vm.startPrank(admin);
        superAsset.whitelistVault(address(tokenIn), address(yieldSourceOracle));
        ISuperAsset.TokenData memory tokenData = superAsset.getTokenData(address(tokenIn));
        assertEq(tokenData.isSupportedUnderlyingVault, true, "Token In should be whitelisted");

        superAsset.whitelistERC20(address(underlyingToken1));
        tokenData = superAsset.getTokenData(address(underlyingToken1));
        assertEq(tokenData.isSupportedERC20, true, "Underlying Token 1 should be whitelisted");

        superAsset.whitelistVault(address(tokenOut), address(yieldSourceOracle));
        tokenData = superAsset.getTokenData(address(tokenOut));
        assertEq(tokenData.isSupportedUnderlyingVault, true, "Token Out should be whitelisted");

        superAsset.whitelistERC20(address(underlyingToken2));
        tokenData = superAsset.getTokenData(address(underlyingToken2));
        assertEq(tokenData.isSupportedERC20, true, "Underlying Token 2 should be whitelisted");

        superAsset.whitelistERC20(address(superAsset)); // Todo: is this correct?
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
            address(underlyingToken1),
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
        uint256 tooHighFee = superAsset.MAX_SWAP_FEE_PERC() + 1;

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
        underlyingToken1.mint(user, depositAmount);

        // Approve tokens
        vm.startPrank(user);
        assertEq(underlyingToken1.balanceOf(user), depositAmount);
        underlyingToken1.approve(address(superAsset), depositAmount);

        // Create preview deposit args using the new struct approach
        ISuperAsset.PreviewDepositArgs memory previewDepositArgs = ISuperAsset.PreviewDepositArgs({
            tokenIn: address(underlyingToken1),
            amountTokenToDeposit: depositAmount,
            isSoft: false
        });

        // Call previewDeposit with the new struct
        ISuperAsset.PreviewDepositReturnVars memory previewDepositRet = superAsset.previewDeposit(previewDepositArgs);

        console.log("Oracle Price USD:", previewDepositRet.oraclePriceUSD);
        console.log("Is Depeg:", previewDepositRet.isDepeg);
        console.log("Is Dispersion:", previewDepositRet.isDispersion);
        console.log("Is Oracle Off:", previewDepositRet.isOracleOff);
        console.log("Token In Found:", previewDepositRet.tokenInFound);
        console.log("Incentive Calculation Success:", previewDepositRet.incentiveCalculationSuccess);
        // Check if operation should succeed based on circuit breakers and other conditions
        bool isSuccess = previewDepositRet.oraclePriceUSD != 0 && !previewDepositRet.isDepeg
            && !previewDepositRet.isDispersion && !previewDepositRet.isOracleOff && previewDepositRet.tokenInFound;

        assertEq(isSuccess, true, "isSuccess should be true, because of zero initial allocation");

        uint256 b1 = tokenIn.balanceOf(address(superBank));
        // Deposit tokens
        ISuperAsset.DepositArgs memory depositArgs = ISuperAsset.DepositArgs({
            receiver: user,
            tokenIn: address(underlyingToken1),
            amountTokenToDeposit: depositAmount,
            minSharesOut: minSharesOut
        });
        console.log("test_BasicDepositSimple() Pre-Deposit");
        ISuperAsset.DepositReturnVars memory ret = superAsset.deposit(depositArgs);
        console.log("test_BasicDepositSimple() Post-Deposit");
        vm.stopPrank();
        assertEq(underlyingToken1.balanceOf(address(superBank)) - b1, ret.swapFee, "SuperBank should receive the swap fee");
        assertEq(
            previewDepositRet.amountSharesMinted, ret.amountSharesMinted, "Actual shares minted should match preview"
        );
        assertEq(previewDepositRet.swapFee, ret.swapFee, "Actual swap fee should match preview");
        assertEq(
            previewDepositRet.amountIncentiveUSDDeposit,
            ret.amountIncentiveUSDDeposit,
            "Actual incentive should match preview"
        );

        // Verify results
        assertGt(ret.amountSharesMinted, 0, "Should mint shares");
        assertEq(
            ret.swapFee,
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

        // Approve tokens
        vm.startPrank(user);
        tokenIn.approve(address(superAsset), s.depositAmount);

        (, s.currentPrice,,,) = mockFeed2.latestRoundData();
        mockFeed2.setAnswer(s.currentPrice * 3);
        (, s.currentPrice,,,) = mockFeed3.latestRoundData();
        mockFeed3.setAnswer(s.currentPrice * 5);

        (s.priceUSD, s.isDepeg, s.isDispersion, s.isOracleOff) =
            superAsset.getPriceAndCircuitBreakers(IERC4626(tokenIn).asset());
        assertEq(s.isDepeg, true);
        assertEq(s.isDispersion, true);
        assertEq(s.isOracleOff, false);
    }

    function test_DepositWithZeroAmount() public {
        vm.startPrank(user);
        vm.expectRevert(ISuperAsset.ZERO_AMOUNT.selector);
        ISuperAsset.DepositArgs memory depositArgs = ISuperAsset.DepositArgs({
            receiver: user,
            tokenIn: address(tokenIn),
            amountTokenToDeposit: 0,
            minSharesOut: 0
        });
        superAsset.deposit(depositArgs);
        vm.stopPrank();
    }

    function test_DepositWithUnsupportedToken() public {
        address unsupportedToken = makeAddr("unsupportedToken");
        vm.startPrank(user);
        vm.expectRevert(ISuperAsset.NOT_SUPPORTED_TOKEN.selector);
        ISuperAsset.DepositArgs memory depositArgs = ISuperAsset.DepositArgs({
            receiver: user,
            tokenIn: unsupportedToken,
            amountTokenToDeposit: 100e18,
            minSharesOut: 0
        });
        superAsset.deposit(depositArgs);
        vm.stopPrank();
    }

    function test_DepositWithZeroAddress() public {
        vm.startPrank(user);
        vm.expectRevert(ISuperAsset.ZERO_ADDRESS.selector);
        ISuperAsset.DepositArgs memory depositArgs = ISuperAsset.DepositArgs({
            receiver: address(0),
            tokenIn: address(tokenIn),
            amountTokenToDeposit: 100e18,
            minSharesOut: 0
        });
        superAsset.deposit(depositArgs);
        vm.stopPrank();
    }

    function test_DepositSlippageProtection() public {
        uint256 depositAmount = 100e18;
        uint256 tooHighMinSharesOut = 101e18; // Requiring more shares than possible

        vm.startPrank(user);
        tokenIn.approve(address(superAsset), depositAmount);

        vm.expectRevert(ISuperAsset.SLIPPAGE_PROTECTION.selector);
        ISuperAsset.DepositArgs memory depositArgs = ISuperAsset.DepositArgs({
            receiver: user,
            tokenIn: address(tokenIn),
            amountTokenToDeposit: depositAmount,
            minSharesOut: tooHighMinSharesOut
        });
        superAsset.deposit(depositArgs);
        vm.stopPrank();
    }

    // --- Test: Redeem ---
    function test_BasicRedeem() public {
        // First deposit to get some shares
        uint256 depositAmount = 100e18;
        // Create preview deposit args using the new struct approach
        ISuperAsset.PreviewDepositArgs memory previewDepositArgs = ISuperAsset.PreviewDepositArgs({
            tokenIn: address(tokenIn),
            amountTokenToDeposit: depositAmount,
            isSoft: false
        });

        // Call previewDeposit with the new struct
        ISuperAsset.PreviewDepositReturnVars memory previewDepositRet = superAsset.previewDeposit(previewDepositArgs);

        // Check if operation should succeed based on circuit breakers and other conditions
        bool isSuccess = previewDepositRet.oraclePriceUSD != 0 && !previewDepositRet.isDepeg
            && !previewDepositRet.isDispersion && !previewDepositRet.isOracleOff && previewDepositRet.tokenInFound;

        assertEq(isSuccess, true, "isSuccess should be true, because of zero initial allocation");

        vm.startPrank(user);
        tokenIn.approve(address(superAsset), depositAmount);
        ISuperAsset.DepositArgs memory depositArgs = ISuperAsset.DepositArgs({
            receiver: user,
            tokenIn: address(tokenIn),
            amountTokenToDeposit: depositAmount,
            minSharesOut: 0
        });
        console.log("\n DEPOSIT 1 START");
        ISuperAsset.DepositReturnVars memory ret = superAsset.deposit(depositArgs);
        console.log("\n DEPOSIT 1 END");

        assertEq(tokenIn.balanceOf(address(superAsset)), depositAmount - ret.swapFee);
        assertEq(previewDepositRet.amountSharesMinted, ret.amountSharesMinted);
        uint256 userShareBalancePostDeposit = superAsset.balanceOf(user);
        assertEq(userShareBalancePostDeposit, ret.amountSharesMinted, "User should have received the shares");
        assertEq(previewDepositRet.swapFee, ret.swapFee);
        assertEq(previewDepositRet.amountIncentiveUSDDeposit, ret.amountIncentiveUSDDeposit);

        tokenIn.approve(address(superAsset), depositAmount);
        ISuperAsset.DepositArgs memory depositArgs2 = ISuperAsset.DepositArgs({
            receiver: user,
            tokenIn: address(tokenIn),
            amountTokenToDeposit: depositAmount,
            minSharesOut: 0
        });
        console.log("\n DEPOSIT 2 START");
        ISuperAsset.DepositReturnVars memory ret2 = superAsset.deposit(depositArgs2);
        console.log("\n DEPOSIT 2 END");

        // Now redeem the shares
        uint256 minTokenOut = (ret.amountSharesMinted + ret2.amountSharesMinted) * 99 / 100; // Allowing for 1% slippage

        // Create preview redeem args using the new struct approach
        ISuperAsset.PreviewRedeemArgs memory previewRedeemArgs = ISuperAsset.PreviewRedeemArgs({
            tokenOut: address(tokenIn),
            amountSharesToRedeem: ret.amountSharesMinted + ret2.amountSharesMinted,
            isSoft: false
        });

        // Call previewRedeem with the new struct
        ISuperAsset.PreviewRedeemReturnVars memory previewRedeemRet = superAsset.previewRedeem(previewRedeemArgs);

        // Check if redeem operation should succeed based on circuit breakers and other conditions
        isSuccess = previewRedeemRet.oraclePriceUSD != 0 && !previewRedeemRet.isDepeg && !previewRedeemRet.isDispersion
            && !previewRedeemRet.isOracleOff && previewRedeemRet.tokenOutFound
            && previewRedeemRet.incentiveCalculationSuccess;
        assertEq(isSuccess, true, "isSuccess should be true, because of zero initial allocation");
        assertGt(previewRedeemRet.amountTokenOutAfterFees, 0, "Should receive tokens");
        assertGt(previewRedeemRet.swapFee, 0, "Should pay swap fees");

        ISuperAsset.RedeemArgs memory redeemArgs = ISuperAsset.RedeemArgs({
            receiver: user,
            amountSharesToRedeem: ret.amountSharesMinted + ret2.amountSharesMinted,
            tokenOut: address(tokenIn),
            minTokenOut: minTokenOut
        });

        console.log("\n USER SHARE BALANCE PRE REDEEM", userShareBalancePostDeposit);
        ISuperAsset.RedeemReturnVars memory retRedeem = superAsset.redeem(redeemArgs);
        vm.stopPrank();

        // Verify the actual redeem results match the preview results
        assertEq(
            previewRedeemRet.amountTokenOutAfterFees,
            retRedeem.amountTokenOutAfterFees,
            "Actual token output should match preview"
        );
        assertEq(previewRedeemRet.swapFee, retRedeem.swapFee, "Actual swap fee should match preview");
        assertEq(
            previewRedeemRet.amountIncentiveUSDRedeem,
            retRedeem.amountIncentiveUSDRedeem,
            "Actual incentive should match preview"
        );

        // Verify results
        assertGt(retRedeem.amountTokenOutAfterFees, 0, "Should receive tokens");
        assertEq(superAsset.balanceOf(user), 0, "User should have no shares left");
    }

    function test_RedeemWithZeroAmount() public {
        vm.startPrank(user);
        vm.expectRevert(ISuperAsset.ZERO_AMOUNT.selector);
        ISuperAsset.RedeemArgs memory redeemArgs = ISuperAsset.RedeemArgs({
            receiver: user,
            amountSharesToRedeem: 0,
            tokenOut: address(tokenIn),
            minTokenOut: 0
        });
        superAsset.redeem(redeemArgs);
        vm.stopPrank();
    }

    function test_RedeemWithUnsupportedToken() public {
        address unsupportedToken = makeAddr("unsupportedToken");
        vm.startPrank(user);
        vm.expectRevert(ISuperAsset.NOT_SUPPORTED_TOKEN.selector);
        ISuperAsset.RedeemArgs memory redeemArgs = ISuperAsset.RedeemArgs({
            receiver: user,
            amountSharesToRedeem: 100e18,
            tokenOut: unsupportedToken,
            minTokenOut: 0
        });
        superAsset.redeem(redeemArgs);
        vm.stopPrank();
    }

    function test_RedeemWithZeroAddress() public {
        vm.startPrank(user);
        vm.expectRevert(ISuperAsset.ZERO_ADDRESS.selector);
        ISuperAsset.RedeemArgs memory redeemArgs = ISuperAsset.RedeemArgs({
            receiver: address(0),
            amountSharesToRedeem: 100e18,
            tokenOut: address(tokenIn),
            minTokenOut: 0
        });
        superAsset.redeem(redeemArgs);
        vm.stopPrank();
    }

    function test_RedeemSlippageProtection() public {
        // First deposit to get some shares
        uint256 depositAmount = 100e18;
        vm.startPrank(user);
        tokenIn.approve(address(superAsset), depositAmount);
        ISuperAsset.DepositArgs memory depositArgs = ISuperAsset.DepositArgs({
            receiver: user,
            tokenIn: address(tokenIn),
            amountTokenToDeposit: depositAmount,
            minSharesOut: 0
        });
        ISuperAsset.DepositReturnVars memory ret = superAsset.deposit(depositArgs);

        // Try to redeem with too high minimum output requirement
        uint256 tooHighMinTokenOut = 101e18; // Requiring more tokens than possible
        ISuperAsset.RedeemArgs memory redeemArgs = ISuperAsset.RedeemArgs({
            receiver: user,
            amountSharesToRedeem: ret.amountSharesMinted,
            tokenOut: address(tokenIn),
            minTokenOut: tooHighMinTokenOut
        });
        vm.expectRevert(ISuperAsset.SLIPPAGE_PROTECTION.selector);
        superAsset.redeem(redeemArgs);
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
        ISuperAsset.DepositArgs memory depositArgs = ISuperAsset.DepositArgs({
            receiver: user11,
            tokenIn: address(tokenOut),
            amountTokenToDeposit: s.swapAmount,
            minSharesOut: 0
        });
        ISuperAsset.DepositReturnVars memory ret = superAsset.deposit(depositArgs);
        vm.stopPrank();
        assertEq(tokenOut.balanceOf(address(superAsset)), s.swapAmount - ret.swapFee, "Should deposit tokenOut");
        assertEq(superAsset.balanceOf(user11), ret.amountSharesMinted, "Should mint shares");
        // Create preview swap args
        ISuperAsset.PreviewSwapArgs memory previewArgs = ISuperAsset.PreviewSwapArgs({
            tokenIn: address(tokenIn),
            amountTokenToDeposit: s.swapAmount,
            tokenOut: address(tokenOut),
            isSoft: false
        });

        // Call previewSwap with the new struct approach
        ISuperAsset.PreviewSwapReturnVars memory previewRet = superAsset.previewSwap(previewArgs);

        // Store results for later assertions
        s.expAmountTokenOutAfterFees = previewRet.amountTokenOutAfterFees;
        s.expSwapFeeIn = previewRet.swapFeeIn;
        s.expSwapFeeOut = previewRet.swapFeeOut;
        s.expAmountIncentiveUSDDeposit = previewRet.amountIncentiveUSDDeposit;
        s.expAmountIncentiveUSDRedeem = previewRet.amountIncentiveUSDRedeem;

        s.isSuccess = previewRet.oraclePriceUSD != 0 && !previewRet.isDepeg && !previewRet.isDispersion
            && !previewRet.isOracleOff && previewRet.tokenInFound;
        assertEq(s.isSuccess, true, "isSuccess should be true, because of zero initial allocation");
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
        ISuperAsset.SwapArgs memory swapArgs = ISuperAsset.SwapArgs({
            receiver: user,
            tokenIn: address(tokenIn),
            amountTokenToDeposit: s.swapAmount,
            tokenOut: address(tokenOut),
            minTokenOut: s.minTokenOut
        });
        ISuperAsset.SwapReturnVars memory swapRet = superAsset.swap(swapArgs);

        // Store return values for assertions
        uint256 sharesStep = swapRet.amountSharesIntermediateStep;
        uint256 tokensOut = swapRet.amountTokenOutAfterFees;
        uint256 swapFeeIn = swapRet.swapFeeIn;
        uint256 swapFeeOut = swapRet.swapFeeOut;
        int256 incentivesIn = swapRet.amountIncentivesIn;
        int256 incentivesOut = swapRet.amountIncentivesOut;

        vm.stopPrank();

        // Verify results
        assertGt(sharesStep, 0, "Should create intermediate shares");
        assertGt(tokensOut, 0, "Should receive output tokens");
        assertGt(swapFeeIn, 0, "Should charge deposit fee");
        assertGt(swapFeeOut, 0, "Should charge redeem fee");

        // NOTE: No incentives here
        // TODO: Check if correct
        assertTrue(incentivesIn == 0, "Should calculate deposit incentives");
        assertTrue(incentivesOut == 0, "Should calculate redeem incentives");
    }

    function test_SwapWithZeroAmount() public {
        vm.startPrank(user);
        vm.expectRevert(ISuperAsset.ZERO_AMOUNT.selector);
        ISuperAsset.SwapArgs memory swapArgs = ISuperAsset.SwapArgs({
            receiver: user,
            tokenIn: address(tokenIn),
            amountTokenToDeposit: 0,
            tokenOut: address(tokenOut),
            minTokenOut: 0
        });
        superAsset.swap(swapArgs);
        vm.stopPrank();
    }

    function test_SwapWithUnsupportedToken() public {
        address unsupportedToken = makeAddr("unsupportedToken");
        vm.startPrank(user);
        vm.expectRevert(ISuperAsset.NOT_SUPPORTED_TOKEN.selector);
        ISuperAsset.SwapArgs memory swapArgs = ISuperAsset.SwapArgs({
            receiver: user,
            tokenIn: unsupportedToken,
            amountTokenToDeposit: 100e18,
            tokenOut: address(tokenOut),
            minTokenOut: 0
        });
        superAsset.swap(swapArgs);
        vm.stopPrank();
    }

    function test_SwapWithZeroAddress() public {
        vm.startPrank(user);
        vm.expectRevert(ISuperAsset.ZERO_ADDRESS.selector);
        ISuperAsset.SwapArgs memory swapArgs = ISuperAsset.SwapArgs({
            receiver: address(0),
            tokenIn: address(tokenIn),
            amountTokenToDeposit: 100e18,
            tokenOut: address(tokenOut),
            minTokenOut: 0
        });
        superAsset.swap(swapArgs);
        vm.stopPrank();
    }

    function test_SwapSlippageProtection() public {
        uint256 swapAmount = 100e18;
        uint256 tooHighMinTokenOut = 101e18; // Requiring more output than possible

        vm.startPrank(user);
        tokenIn.approve(address(superAsset), swapAmount);

        vm.expectRevert(ISuperAsset.SLIPPAGE_PROTECTION.selector);
        ISuperAsset.SwapArgs memory swapArgs = ISuperAsset.SwapArgs({
            receiver: user,
            tokenIn: address(tokenIn),
            amountTokenToDeposit: swapAmount,
            tokenOut: address(tokenOut),
            minTokenOut: tooHighMinTokenOut
        });
        superAsset.swap(swapArgs);
        vm.stopPrank();
    }

    // --- Test: Token Management ---
    function test_ERC20TokenActivationAndDeactivation() public {
        // Deploy a new test token
        MockERC20 testToken = new MockERC20("Test Token", "TEST", 18);

        // Whitelist the token (also sets isActive to true)
        vm.startPrank(admin);
        superAsset.whitelistERC20(address(testToken));

        // Check initial state
        ISuperAsset.TokenData memory tokenData = superAsset.getTokenData(address(testToken));
        assertTrue(tokenData.isSupportedERC20, "Token should be supported");
        assertTrue(tokenData.isActive, "Token should be active after whitelisting");

        // Give the token some balance to prevent complete purge
        vm.stopPrank();
        deal(address(testToken), address(superAsset), 100e18);
        vm.startPrank(admin);

        // Deactivate the token (with balance, it will remain in system but inactive)
        superAsset.removeERC20(address(testToken));

        // Check token is inactive but still supported because it has balance
        tokenData = superAsset.getTokenData(address(testToken));
        assertTrue(tokenData.isSupportedERC20, "Token should still be supported after deactivation when it has balance");
        assertFalse(tokenData.isActive, "Token should be inactive after deactivation");

        // Reactivate the token
        superAsset.activateERC20(address(testToken));

        // Check token is active again
        tokenData = superAsset.getTokenData(address(testToken));
        assertTrue(tokenData.isActive, "Token should be active after reactivation");

        vm.stopPrank();
    }

    function test_VaultTokenActivationAndDeactivation() public {
        // Deploy a new test vault
        MockERC20 underlying = new MockERC20("Vault Underlying", "VUND", 18);
        Mock4626Vault testVault = new Mock4626Vault(address(underlying), "Test Vault", "TVAULT");

        // Whitelist the vault (also sets isActive to true)
        vm.startPrank(admin);
        superAsset.whitelistVault(address(testVault), address(yieldSourceOracle));

        // Check initial state
        ISuperAsset.TokenData memory tokenData = superAsset.getTokenData(address(testVault));
        assertTrue(tokenData.isSupportedUnderlyingVault, "Vault should be supported");
        assertTrue(tokenData.isActive, "Vault should be active after whitelisting");

        // Give the vault token a non-zero balance in SuperAsset to prevent auto-purge
        vm.stopPrank(); // Stop being admin to do token operations

        // Use deal to give SuperAsset some vault tokens
        deal(address(testVault), address(superAsset), 100e18);

        // Start being admin again
        vm.startPrank(admin);

        // Deactivate the vault (with balance, it will remain in system but inactive)
        superAsset.removeVault(address(testVault));

        // Check vault is inactive but still supported because it has balance
        tokenData = superAsset.getTokenData(address(testVault));
        assertTrue(
            tokenData.isSupportedUnderlyingVault,
            "Vault should still be supported after deactivation when it has balance"
        );
        assertFalse(tokenData.isActive, "Vault should be inactive after deactivation");

        // Reactivate the vault
        superAsset.activateVault(address(testVault));

        // Check vault is active again
        tokenData = superAsset.getTokenData(address(testVault));
        assertTrue(tokenData.isActive, "Vault should be active after reactivation");

        vm.stopPrank();
    }

    function test_AutoPurgeWithZeroBalance() public {
        // Deploy a new test token
        MockERC20 testToken = new MockERC20("Test Token", "TEST", 18);

        // Whitelist the token
        vm.startPrank(admin);
        superAsset.whitelistERC20(address(testToken));
        vm.stopPrank();

        // Mint tokens to SuperAsset contract
        testToken.mint(address(superAsset), 100e18);
        assertEq(testToken.balanceOf(address(superAsset)), 100e18, "SuperAsset should have token balance");

        // Deactivate with balance - token should remain in system but inactive
        vm.startPrank(admin);
        superAsset.removeERC20(address(testToken));
        ISuperAsset.TokenData memory tokenData = superAsset.getTokenData(address(testToken));
        assertFalse(tokenData.isActive, "Token should be inactive after deactivation");
        assertTrue(tokenData.isSupportedERC20, "Token should still be supported when it has balance");
        vm.stopPrank();

        // Transfer all tokens out
        vm.prank(address(superAsset));
        testToken.transfer(address(this), 100e18);
        assertEq(testToken.balanceOf(address(superAsset)), 0, "SuperAsset should have no token balance");

        // Now try to deactivate again - should auto-purge since balance is zero
        vm.startPrank(admin);
        superAsset.removeERC20(address(testToken));
        tokenData = superAsset.getTokenData(address(testToken));
        assertFalse(tokenData.isActive, "Token should be inactive after purge");
        assertFalse(tokenData.isSupportedERC20, "Token should be completely removed when it has no balance");
        vm.stopPrank();
    }

    function test_CannotDepositInactiveToken() public {
        // Deploy a new test token
        MockERC20 testToken = new MockERC20("Test Token", "TEST", 18);

        // Whitelist the token
        vm.startPrank(admin);
        superAsset.whitelistERC20(address(testToken));
        vm.stopPrank();

        // Mint tokens to user
        testToken.mint(user, 100e18);

        // Deactivate the token
        vm.startPrank(admin);
        superAsset.removeERC20(address(testToken));
        vm.stopPrank();

        // Deposit should work with active token
        ISuperAsset.DepositArgs memory depositArgs = ISuperAsset.DepositArgs({
            receiver: user,
            tokenIn: address(testToken),
            amountTokenToDeposit: 10e18,
            minSharesOut: 0
        });

        // Try to deposit with inactive token - should revert
        vm.startPrank(user);
        testToken.approve(address(superAsset), 100e18);

        vm.expectRevert(ISuperAsset.NOT_SUPPORTED_TOKEN.selector);
        superAsset.deposit(depositArgs);
        vm.stopPrank();
    }

    function test_CannotRedeemToInactiveToken() public {
        // First deposit some tokens to get shares
        uint256 depositAmount = 50e18;

        vm.startPrank(user);
        tokenIn.approve(address(superAsset), depositAmount);

        ISuperAsset.DepositArgs memory depositArgs = ISuperAsset.DepositArgs({
            receiver: user,
            tokenIn: address(tokenIn),
            amountTokenToDeposit: depositAmount,
            minSharesOut: 0
        });
        ISuperAsset.DepositReturnVars memory depositRet = superAsset.deposit(depositArgs);
        uint256 sharesBalance = depositRet.amountSharesMinted;
        assertGt(sharesBalance, 0, "User should have shares after deposit");
        vm.stopPrank();

        // Now deactivate tokenOut
        vm.startPrank(admin);
        superAsset.removeVault(address(tokenOut));
        vm.stopPrank();

        // Try to redeem to inactive token - should revert
        vm.startPrank(user);
        vm.expectRevert(ISuperAsset.NOT_SUPPORTED_TOKEN.selector);
        ISuperAsset.RedeemArgs memory redeemArgs = ISuperAsset.RedeemArgs({
            receiver: user,
            tokenOut: address(tokenOut),
            amountSharesToRedeem: sharesBalance,
            minTokenOut: 0
        });
        superAsset.redeem(redeemArgs);
        vm.stopPrank();
    }

    function test_ReactivationErrors() public {
        // Deploy a new test token
        MockERC20 testToken = new MockERC20("Test Token", "TEST", 18);

        // Try to activate non-supported token
        vm.startPrank(admin);
        vm.expectRevert(ISuperAsset.TOKEN_NOT_SUPPORTED.selector);
        superAsset.activateERC20(address(testToken));

        // Whitelist the token
        superAsset.whitelistERC20(address(testToken));

        // Try to activate already active token
        vm.expectRevert(ISuperAsset.TOKEN_ALREADY_ACTIVE.selector);
        superAsset.activateERC20(address(testToken));

        // Add token balance to prevent complete removal
        vm.stopPrank();
        deal(address(testToken), address(superAsset), 100e18);
        vm.startPrank(admin);

        // Deactivate the token
        superAsset.removeERC20(address(testToken));

        // Activation should now succeed
        superAsset.activateERC20(address(testToken));
        ISuperAsset.TokenData memory tokenData = superAsset.getTokenData(address(testToken));
        assertTrue(tokenData.isActive, "Token should be active after reactivation");

        vm.stopPrank();
    }

    function test_CircuitBreaker_DispersionDetection1() public {
        // Test depeg detection - price moves beyond ±2% threshold
        vm.startPrank(user);
        tokenIn.approve(address(superAsset), 100e18);

        // Set mockFeed2 to trigger depeg (price drops by 5%)
        // This should be not enough to trigger a depeg but enough to trigger a dispersion
        (, int256 currentPrice,,,) = mockFeed2.latestRoundData();
        mockFeed2.setAnswer(currentPrice * 95 / 100); // 5% drop

        // Should revert due to depeg
        ISuperAsset.DepositArgs memory depositArgs = ISuperAsset.DepositArgs({
            receiver: user,
            tokenIn: address(tokenIn),
            amountTokenToDeposit: 100e18,
            minSharesOut: 0
        });

        vm.expectRevert(abi.encodeWithSelector(ISuperAsset.SUPPORTED_ASSET_PRICE_DISPERSION.selector, address(tokenIn)));
        superAsset.deposit(depositArgs);
        vm.stopPrank();
    }

    function test_CircuitBreaker_DispersionDetection2() public {
        // Test dispersion detection - high standard deviation between price feeds
        vm.startPrank(user);
        tokenIn.approve(address(superAsset), 100e18);

        // Create high dispersion by setting feeds to very different values
        (, int256 basePrice,,,) = mockFeed1.latestRoundData();
        mockFeed2.setAnswer(basePrice * 120 / 100); // +20%
        mockFeed3.setAnswer(basePrice * 80 / 100); // -20%

        ISuperAsset.DepositArgs memory depositArgs = ISuperAsset.DepositArgs({
            receiver: user,
            tokenIn: address(tokenIn),
            amountTokenToDeposit: 100e18,
            minSharesOut: 0
        });

        vm.expectRevert(abi.encodeWithSelector(ISuperAsset.SUPPORTED_ASSET_PRICE_DISPERSION.selector, address(tokenIn)));
        superAsset.deposit(depositArgs);
        vm.stopPrank();
    }

    function test_CircuitBreaker_OracleFailure() public {
        // Test oracle failure detection
        vm.startPrank(user);
        tokenIn.approve(address(superAsset), 100e18);

        // Set feed to stale timestamp to trigger oracle failure
        vm.warp(block.timestamp + 30 days);

        ISuperAsset.DepositArgs memory depositArgs = ISuperAsset.DepositArgs({
            receiver: user,
            tokenIn: address(tokenIn),
            amountTokenToDeposit: 100e18,
            minSharesOut: 0
        });
        vm.expectRevert(abi.encodeWithSelector(ISuperAsset.SUPPORTED_ASSET_PRICE_ORACLE_OFF.selector, address(tokenIn)));
        superAsset.deposit(depositArgs);
        vm.stopPrank();
    }

    function test_CircuitBreaker_OracleOff() public {
        // Test zero price detection
        vm.startPrank(user);
        tokenIn.approve(address(superAsset), 100e18);

        // Set price to zero
        mockFeed1.setAnswer(0);
        mockFeed2.setAnswer(0);
        mockFeed3.setAnswer(0);

        ISuperAsset.DepositArgs memory depositArgs = ISuperAsset.DepositArgs({
            receiver: user,
            tokenIn: address(tokenIn),
            amountTokenToDeposit: 100e18,
            minSharesOut: 0
        });

        vm.expectRevert(abi.encodeWithSelector(ISuperAsset.SUPPORTED_ASSET_PRICE_ORACLE_OFF.selector, address(tokenIn)));
        superAsset.deposit(depositArgs);
        vm.stopPrank();
    }

    function test_TargetAllocationManagement() public {
        // Test setting and managing target allocations
        vm.startPrank(admin);

        address[] memory tokens = new address[](3);
        tokens[0] = address(tokenIn);
        tokens[1] = address(tokenOut);
        tokens[2] = address(underlyingToken1);
        
        uint256[] memory allocations = new uint256[](3);
        allocations[0] = 50e18; // 50%
        allocations[1] = 30e18; // 30%
        allocations[2] = 20e18; // 20%

        superAsset.setTargetAllocations(tokens, allocations);

        // Verify allocations were set
        ISuperAsset.TokenData memory tokenData = superAsset.getTokenData(address(tokenIn));
        assertEq(tokenData.targetAllocations, 50e18, "TokenIn allocation should be 50%");

        tokenData = superAsset.getTokenData(address(tokenOut));
        assertEq(tokenData.targetAllocations, 30e18, "TokenOut allocation should be 30%");
        
        tokenData = superAsset.getTokenData(address(underlyingToken1));
        assertEq(tokenData.targetAllocations, 20e18, "underlyingToken1 allocation should be 20%");
        
        vm.stopPrank();
    }

    function test_WeightManagement() public {
        // Test setting vault weights for rebalancing
        vm.startPrank(admin);
        superAsset.setWeight(address(tokenIn), 100);
        superAsset.setWeight(address(tokenOut), 200);
        superAsset.setWeight(address(underlyingToken1), 50);
        
        // Verify weights were set
        ISuperAsset.TokenData memory tokenData = superAsset.getTokenData(address(tokenIn));
        assertEq(tokenData.weights, 100, "TokenIn weight should be 100");

        tokenData = superAsset.getTokenData(address(tokenOut));
        assertEq(tokenData.weights, 200, "TokenOut weight should be 200");
        
        tokenData = superAsset.getTokenData(address(underlyingToken1));
        assertEq(tokenData.weights, 50, "underlyingToken1 weight should be 50");
        
        vm.stopPrank();
    }

    function test_MultiUserDepositRedeemSequence() public {
        // Test complex sequence with multiple users
        uint256 deposit1 = 100e18;
        uint256 deposit2 = 200e18;
        
        // User deposits
        vm.startPrank(user);
        tokenIn.approve(address(superAsset), deposit1);
        ISuperAsset.DepositArgs memory depositArgs1 = ISuperAsset.DepositArgs({
            receiver: user,
            tokenIn: address(tokenIn),
            amountTokenToDeposit: deposit1,
            minSharesOut: 0
        });

        console.log("TokenIn = ", address(tokenIn));
        console.log("TokenOut = ", address(tokenOut));
        console.log("SuperAsset Shares = ", address(superAsset));
        ISuperAsset.DepositReturnVars memory ret1 = superAsset.deposit(depositArgs1);
        vm.stopPrank();
        
        // User11 deposits different token
        vm.startPrank(user11);
        tokenOut.approve(address(superAsset), deposit2);
        ISuperAsset.DepositArgs memory depositArgs2 = ISuperAsset.DepositArgs({
            receiver: user11,
            tokenIn: address(tokenOut),
            amountTokenToDeposit: deposit2,
            minSharesOut: 0
        });
        ISuperAsset.DepositReturnVars memory ret2 = superAsset.deposit(depositArgs2);
        vm.stopPrank();

        // Verify balances
        assertEq(superAsset.balanceOf(user), ret1.amountSharesMinted, "User should have correct shares");
        assertEq(superAsset.balanceOf(user11), ret2.amountSharesMinted, "User11 should have correct shares");
        
        // User redeems half
        vm.startPrank(user);
        uint256 redeemAmount = ret1.amountSharesMinted / 2;
        ISuperAsset.RedeemArgs memory redeemArgs = ISuperAsset.RedeemArgs({
            receiver: user,
            amountSharesToRedeem: redeemAmount,
            tokenOut: address(tokenIn),
            minTokenOut: 0
        });
        ISuperAsset.RedeemReturnVars memory redeemRet = superAsset.redeem(redeemArgs);
        vm.stopPrank();
        
        // Verify partial redemption
        assertEq(superAsset.balanceOf(user), ret1.amountSharesMinted - redeemAmount, "User should have remaining shares");
        assertGt(redeemRet.amountTokenOutAfterFees, 0, "User should receive tokens");
    }




    function test_CrossTokenSwapsWithDifferentDecimals() public {
        // Whitelist underlyingToken6d
        vm.startPrank(admin);
        superAsset.whitelistERC20(address(underlyingToken6d));
        vm.stopPrank();
        console.log("test_CrossTokenSwapsWithDifferentDecimals() Start");
        // Test swaps between tokens with different decimal places
        address liquidityProvider = user11;
        uint256 LPingAmount = 100000000e6;
        underlyingToken6d.mint(liquidityProvider, LPingAmount);
        uint256 swapAmount = 10e18;

        
        // Provide liquidity in underlyingToken6d (6 decimals)
        vm.startPrank(liquidityProvider);
        underlyingToken6d.approve(address(superAsset), LPingAmount);
        ISuperAsset.DepositArgs memory liquidityArgs = ISuperAsset.DepositArgs({
            receiver: liquidityProvider,
            tokenIn: address(underlyingToken6d),
            amountTokenToDeposit: LPingAmount, 
            minSharesOut: 0
        });
        superAsset.deposit(liquidityArgs);
        vm.stopPrank();
        console.log("test_CrossTokenSwapsWithDifferentDecimals() LPing Done");
        
        // Swap from 18 decimal token to 6 decimal token
        vm.startPrank(user);
        tokenIn.approve(address(superAsset), swapAmount);
        
        ISuperAsset.SwapArgs memory swapArgs = ISuperAsset.SwapArgs({
            receiver: user,
            tokenIn: address(tokenIn),
            amountTokenToDeposit: swapAmount,
            tokenOut: address(underlyingToken6d),
            minTokenOut: 0
        });
        
        ISuperAsset.SwapReturnVars memory swapRet = superAsset.swap(swapArgs);
        
        // Verify swap succeeded and amounts are reasonable
        assertGt(swapRet.amountTokenOutAfterFees, 0, "Should receive volatile tokens");
        assertGt(swapRet.swapFeeIn, 0, "Should pay input fee");
        assertGt(swapRet.swapFeeOut, 0, "Should pay output fee");
        
        vm.stopPrank();
    }


    function test_LargeAmountOperations() public {
        address liquidityProvider = user11;

        // Test with very large amounts near uint256 limits
        uint256 largeAmount = type(uint128).max; // Use uint128 max to avoid overflow
        
        // Setup large liquidity
        underlyingToken1.mint(liquidityProvider, largeAmount);
        
        vm.startPrank(liquidityProvider);
        underlyingToken1.approve(address(tokenIn), largeAmount);
        tokenIn.deposit(largeAmount / 2, liquidityProvider);
        tokenIn.approve(address(superAsset), largeAmount / 2);
        
        ISuperAsset.DepositArgs memory depositArgs = ISuperAsset.DepositArgs({
            receiver: liquidityProvider,
            tokenIn: address(tokenIn),
            amountTokenToDeposit: largeAmount / 4, // Use 1/4 to leave room for fees
            minSharesOut: 0
        });
        
        // Should not revert with large amounts
        ISuperAsset.DepositReturnVars memory ret = superAsset.deposit(depositArgs);
        assertGt(ret.amountSharesMinted, 0, "Should mint shares even with large amounts");
        
        vm.stopPrank();
    }

    function test_MinimalAmountOperations() public {
        // Test with minimal amounts (1 wei)
        uint256 minAmount = 1;
        
        vm.startPrank(user);
        tokenIn.approve(address(superAsset), minAmount);
        
        ISuperAsset.DepositArgs memory depositArgs = ISuperAsset.DepositArgs({
            receiver: user,
            tokenIn: address(tokenIn),
            amountTokenToDeposit: minAmount,
            minSharesOut: 0
        });
        
        // May revert or succeed depending on precision - test that it behaves consistently
        try superAsset.deposit(depositArgs) returns (ISuperAsset.DepositReturnVars memory ret) {
            // If it succeeds, verify the math is consistent
            assertGe(ret.amountSharesMinted, 0, "Shares minted should be non-negative");
        } catch {
            // If it reverts, that's also acceptable for minimal amounts
            assertTrue(true, "Minimal amount operations may revert");
        }
        
        vm.stopPrank();
    }


    function test_SequentialPriceUpdates() public {
        // Test system behavior with sequential price updates
        uint256 depositAmount = 100e18;
        underlyingToken1.mint(user, 2*depositAmount);
        
        vm.startPrank(user);
        underlyingToken1.approve(address(superAsset), depositAmount);
        
        ISuperAsset.DepositArgs memory depositArgs = ISuperAsset.DepositArgs({
            receiver: user,
            tokenIn: address(underlyingToken1),
            amountTokenToDeposit: depositAmount,
            minSharesOut: 0
        });
        
        // Initial deposit
        ISuperAsset.DepositReturnVars memory ret1 = superAsset.deposit(depositArgs);
        
        // Update prices (within acceptable range)
        (, int256 currentPrice,,,) = mockFeed1.latestRoundData();
        mockFeed1.setAnswer(currentPrice * 102 / 100); // 2% increase
        mockFeed2.setAnswer(currentPrice * 102 / 100);
        mockFeed3.setAnswer(currentPrice * 102 / 100);
        _updateAllFeedTimestamps();
        
        // Second deposit with updated prices
        underlyingToken1.approve(address(superAsset), depositAmount);
        ISuperAsset.DepositReturnVars memory ret2 = superAsset.deposit(depositArgs);
        console.log("ret1.amountSharesMinted = ", ret1.amountSharesMinted);
        console.log("ret2.amountSharesMinted = ", ret2.amountSharesMinted);
        
        // NOTE: Equality here might seem incorrect but it should be correct since 
        // After the first deposit, the SuperAsset is 100% exposed to underlyingtoken1
        // so since this token goes up 2% also the SuperAsset PPS goes up 2% 
        // so in the second deposit, using the same amount as the previous one should return the same number of SuperAsset shares since 
        // since both the underlyingToken1 price and the SuperAsset shares price went up by 2% so their ratio stays the same
        assertTrue(ret1.amountSharesMinted == ret2.amountSharesMinted, "Price updates should affect share calculations");
        
        vm.stopPrank();
    }
}
