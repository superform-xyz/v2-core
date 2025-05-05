// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IncentiveFundContract} from "../../../src/periphery/SuperAsset/IncentiveFundContract.sol";
import {SuperAsset} from "../../../src/periphery/SuperAsset/SuperAsset.sol";
import {AssetBank} from "../../../src/periphery/SuperAsset/AssetBank.sol";
import {ISuperAsset} from "../../../src/periphery/interfaces/SuperAsset/ISuperAsset.sol";
import {IIncentiveFundContract} from "../../../src/periphery/interfaces/SuperAsset/IIncentiveFundContract.sol";
import {SuperOracle} from "../../../src/periphery/oracles/SuperOracle.sol";
import {IncentiveCalculationContract} from "../../../src/periphery/SuperAsset/IncentiveCalculationContract.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {AggregatorV3Interface} from "../../../src/vendor/chainlink/AggregatorV3Interface.sol";

contract MockAggregator is AggregatorV3Interface {
    int256 private _answer;
    uint256 private _updatedAt;
    uint8 private immutable _decimals;

    constructor(int256 answer_, uint8 decimals_) {
        _answer = answer_;
        _decimals = decimals_;
        _updatedAt = block.timestamp;
    }

    function setAnswer(int256 answer_) external {
        _answer = answer_;
    }

    function setUpdatedAt(uint256 updatedAt_) external {
        _updatedAt = updatedAt_;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function description() external pure returns (string memory) {
        return "Mock Aggregator";
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function getRoundData(uint80)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, _answer, block.timestamp, _updatedAt, 1);
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, _answer, block.timestamp, _updatedAt, 1);
    }
}

contract IncentiveFundContractTest is Test {
    // --- Events ---
    event IncentivePaid(address indexed receiver, address indexed tokenOut, uint256 amount);
    event IncentiveTaken(address indexed sender, address indexed tokenIn, uint256 amount);
    event SettlementTokenInSet(address indexed token);
    event SettlementTokenOutSet(address indexed token);

    // --- Constants ---
    bytes32 public constant AVERAGE_PROVIDER = keccak256("AVERAGE_PROVIDER");
    bytes32 public constant PROVIDER_1 = keccak256("PROVIDER_1");
    bytes32 public constant PROVIDER_2 = keccak256("PROVIDER_2");
    bytes32 public constant PROVIDER_3 = keccak256("PROVIDER_3");

    // --- State Variables ---
    IncentiveFundContract public incentiveFund;
    SuperAsset public superAsset;
    AssetBank public assetBank;
    SuperOracle public oracle;
    MockERC20 public tokenIn;
    MockERC20 public tokenOut;
    MockERC20 public usd;
    MockAggregator public mockFeed1;
    MockAggregator public mockFeed2;
    MockAggregator public mockFeed3;
    IncentiveCalculationContract public icc;
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
        usd = new MockERC20("USD", "USD", 6);

        // Deploy actual ICC
        icc = new IncentiveCalculationContract();

        // Create mock price feeds with different price values (1 token = $1)
        mockFeed1 = new MockAggregator(1e8, 8); // Token/USD = $1
        mockFeed2 = new MockAggregator(1e8, 8); // Token/USD = $1
        mockFeed3 = new MockAggregator(1e8, 8); // Token/USD = $1

        // Setup oracle parameters
        address[] memory bases = new address[](3);
        bases[0] = address(tokenIn);
        bases[1] = address(tokenOut);
        bases[2] = address(usd);

        address[] memory quotes = new address[](3);
        quotes[0] = address(usd);
        quotes[1] = address(usd);
        quotes[2] = address(usd);

        bytes32[] memory providers = new bytes32[](3);
        providers[0] = PROVIDER_1;
        providers[1] = PROVIDER_2;
        providers[2] = PROVIDER_3;

        address[] memory feeds = new address[](3);
        feeds[0] = address(mockFeed1);
        feeds[1] = address(mockFeed2);
        feeds[2] = address(mockFeed3);

        // Deploy and configure oracle
        oracle = new SuperOracle(admin, bases, quotes, providers, feeds);
        oracle.setMaxStaleness(2 weeks);
        
        // Deploy contracts (admin will automatically get DEFAULT_ADMIN_ROLE)
        assetBank = new AssetBank();
        incentiveFund = new IncentiveFundContract();
        superAsset = new SuperAsset();
        
        // Initialize SuperAsset
        superAsset.initialize(
            "SuperAsset", // name
            "SA", // symbol
            address(icc), // icc (IncentiveCalculationContract)
            address(incentiveFund), // ifc (IncentiveFundContract)
            address(assetBank), // assetBank
            100, // swapFeeInPercentage (0.1%)
            100 // swapFeeOutPercentage (0.1%)
        );

        // Grant VAULT_MANAGER_ROLE to admin for token management
        superAsset.grantRole(superAsset.VAULT_MANAGER_ROLE(), admin);

        // Configure SuperAsset
        superAsset.setSuperOracle(address(oracle));
        superAsset.whitelistERC20(address(tokenIn));
        superAsset.whitelistERC20(address(tokenOut));

        // Initialize IncentiveFundContract after SuperAsset is set up
        incentiveFund.initialize(address(superAsset), address(assetBank));

        // Setup roles for each contract
        bytes32 INCENTIVE_FUND_MANAGER = incentiveFund.INCENTIVE_FUND_MANAGER();

        // Grant roles to manager and contracts
        incentiveFund.grantRole(INCENTIVE_FUND_MANAGER, manager);
        assetBank.grantRole(assetBank.INCENTIVE_FUND_MANAGER(), address(incentiveFund));
        superAsset.grantRole(superAsset.INCENTIVE_FUND_MANAGER(), address(incentiveFund));
        superAsset.grantRole(superAsset.MINTER_ROLE(), address(incentiveFund));
        superAsset.grantRole(superAsset.BURNER_ROLE(), address(incentiveFund));

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

        // Manager pays incentive
        vm.startPrank(manager);
        vm.expectEmit(true, true, false, true);
        emit IncentivePaid(user, address(tokenOut), 100e18);
        incentiveFund.payIncentive(user, 100e18);
        vm.stopPrank();

        // Check balances
        assertEq(tokenOut.balanceOf(user), 1100e18);
        assertEq(tokenOut.balanceOf(address(incentiveFund)), 900e18);
    }

    function test_PayIncentive_RevertIfNoTokenSet() public {
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

        // Give approval to incentiveFund
        vm.startPrank(user);
        tokenIn.approve(address(incentiveFund), 100e18);
        vm.stopPrank();

        // Manager takes incentive
        vm.startPrank(manager);
        vm.expectEmit(true, true, false, true);
        emit IncentiveTaken(user, address(tokenIn), 100e18);
        incentiveFund.takeIncentive(user, 100e18);
        vm.stopPrank();

        // Check balances
        assertEq(tokenIn.balanceOf(user), 900e18);
        assertEq(tokenIn.balanceOf(address(incentiveFund)), 1100e18);
    }

    function test_TakeIncentive_RevertIfNoTokenSet() public {
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
