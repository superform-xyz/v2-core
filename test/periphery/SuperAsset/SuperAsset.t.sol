// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {SuperAsset} from "../../../src/periphery/SuperAsset/SuperAsset.sol";
import {ISuperAsset} from "../../../src/periphery/interfaces/SuperAsset/ISuperAsset.sol";
import {AssetBank} from "../../../src/periphery/SuperAsset/AssetBank.sol";
import {IncentiveFundContract} from "../../../src/periphery/SuperAsset/IncentiveFundContract.sol";
import {IncentiveCalculationContract} from "../../../src/periphery/SuperAsset/IncentiveCalculationContract.sol";
import {SuperOracle} from "../../../src/periphery/oracles/SuperOracle.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";
import {MockAggregator} from "./MockAggregator.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";


contract SuperAssetTest is Test {
    // --- Constants ---
    bytes32 public constant PROVIDER_1 = keccak256("PROVIDER_1");
    bytes32 public constant PROVIDER_2 = keccak256("PROVIDER_2");
    bytes32 public constant PROVIDER_3 = keccak256("PROVIDER_3");
    bytes32 public constant PROVIDER_4 = keccak256("PROVIDER_4");
    bytes32 public constant PROVIDER_5 = keccak256("PROVIDER_5");
    bytes32 public constant PROVIDER_6 = keccak256("PROVIDER_6");
    address public constant USD = address(840);

    // --- State Variables ---
    SuperAsset public superAsset;
    AssetBank public assetBank;
    SuperOracle public oracle;
    MockERC20 public tokenIn;
    MockERC20 public tokenOut;
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

    // --- Setup ---
    function setUp() public {
        // Setup accounts
        admin = makeAddr("admin");
        manager = makeAddr("manager");
        user = makeAddr("user");

        vm.startPrank(admin);
        
        // Deploy mock tokens
        tokenIn = new MockERC20("Token In", "TIN", 18);
        tokenOut = new MockERC20("Token Out", "TOUT", 18);
        console.log("Mock tokens deployed");

        // Deploy actual ICC
        icc = new IncentiveCalculationContract();
        console.log("ICC deployed");

        // Create mock price feeds with different price values (1 token = $1)
        mockFeed1 = new MockAggregator(1e8, 8); // Token/USD = $1
        mockFeed2 = new MockAggregator(1e8, 8); // Token/USD = $1
        mockFeed3 = new MockAggregator(1e8, 8); // Token/USD = $1
        mockFeed4 = new MockAggregator(1e8, 8); // Token/USD = $1
        mockFeed5 = new MockAggregator(1e8, 8); // Token/USD = $1
        mockFeed6 = new MockAggregator(1e8, 8); // Token/USD = $1
        console.log("Mock feeds deployed");

        // Update timestamps to ensure prices are fresh
        mockFeed1.setUpdatedAt(block.timestamp);
        mockFeed2.setUpdatedAt(block.timestamp);
        mockFeed3.setUpdatedAt(block.timestamp);
        mockFeed4.setUpdatedAt(block.timestamp);
        mockFeed5.setUpdatedAt(block.timestamp);
        mockFeed6.setUpdatedAt(block.timestamp);
        console.log("Feed timestamps updated");

        // Setup oracle parameters with regular providers
        address[] memory bases = new address[](6);
        bases[0] = address(tokenIn);
        bases[1] = address(tokenIn);
        bases[2] = address(tokenIn);
        bases[3] = address(tokenOut);
        bases[4] = address(tokenOut);
        bases[5] = address(tokenOut);

        address[] memory quotes = new address[](6);
        quotes[0] = USD;
        quotes[1] = USD;
        quotes[2] = USD;
        quotes[3] = USD;
        quotes[4] = USD;
        quotes[5] = USD;

        bytes32[] memory providers = new bytes32[](6);
        providers[0] = PROVIDER_1;
        providers[1] = PROVIDER_2;
        providers[2] = PROVIDER_3;
        providers[3] = PROVIDER_4;
        providers[4] = PROVIDER_5;
        providers[5] = PROVIDER_6;

        address[] memory feeds = new address[](6);
        feeds[0] = address(mockFeed1);
        feeds[1] = address(mockFeed2);
        feeds[2] = address(mockFeed3);
        feeds[3] = address(mockFeed4);
        feeds[4] = address(mockFeed5);
        feeds[5] = address(mockFeed6);

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
        console.log("Feed staleness set");

        // Deploy contracts
        assetBank = new AssetBank();
        console.log("AssetBank deployed");

        incentiveFund = new IncentiveFundContract();
        console.log("IncentiveFund deployed");

        superAsset = new SuperAsset();
        console.log("SuperAsset deployed");

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

        // Setup roles and configuration
        superAsset.grantRole(superAsset.VAULT_MANAGER_ROLE(), admin);
        superAsset.setSuperOracle(address(oracle));
        superAsset.whitelistERC20(address(tokenIn));
        superAsset.whitelistERC20(address(tokenOut));

        // Initialize IncentiveFund
        incentiveFund.initialize(address(superAsset), address(assetBank));

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
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                keccak256("DEFAULT_ADMIN_ROLE")  // DEFAULT_ADMIN_ROLE is a special role in AccessControl
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

    // function test_OnlyVaultManagerCanBlacklistTokens() public {
    //     // First whitelist a token
    //     address newToken = makeAddr("newToken");
    //     vm.startPrank(admin);
    //     superAsset.whitelistERC20(newToken);
    //     vm.stopPrank();

    //     // Non-manager cannot blacklist
    //     vm.startPrank(user);
    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             IAccessControl.AccessControlUnauthorizedAccount.selector,
    //             user,
    //             superAsset.VAULT_MANAGER_ROLE()
    //         )
    //     );
    //     superAsset.blacklistERC20(newToken);
    //     vm.stopPrank();

    //     // Manager can blacklist
    //     vm.startPrank(admin);
    //     superAsset.blacklistERC20(newToken);
    //     vm.stopPrank();

    //     assertFalse(superAsset.isSupportedERC20(newToken));
    // }

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
}
