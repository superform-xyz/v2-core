// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// Test
import { BaseSuperVaultTest } from "../integration/SuperVault/BaseSuperVaultTest.t.sol";

// Superform
import { SuperAssetRegistry } from "../../../src/periphery/SuperVault/SuperAssetRegistry.sol";
import { ISuperAssetRegistry } from "../../../src/periphery/interfaces/SuperVault/ISuperAssetRegistry.sol";
import { SuperGovernor } from "../../../src/periphery/SuperGovernor.sol";
import { SuperVault } from "../../../src/periphery/SuperVault/SuperVault.sol";
import { SuperVaultStrategy } from "../../../src/periphery/SuperVault/SuperVaultStrategy.sol";

// External
import { ERC20Mock } from "forge-std/mocks/MockERC20.sol";

contract SuperAssetRegistryTest is BaseSuperVaultTest {
    SuperAssetRegistry public superAssetRegistry;
    SuperGovernor public superGovernor;
    
    address public constant STRATEGY = address(0x1234);
    address public constant STRATEGIST = address(0x5678);
    address public constant SECONDARY_STRATEGIST = address(0x9ABC);
    address public constant UNAUTHORIZED = address(0xDEF0);
    address public constant NEW_STRATEGIST = address(0x1111);
    
    ERC20Mock public upkeepToken;
    
    event PPSUpdated(
        address indexed strategy,
        uint256 newPPS,
        uint256 newPPSStdev,
        uint256 lastUpdateTimestamp,
        uint256 minUpdateInterval
    );
    
    event StrategistAdded(address indexed strategy, address indexed strategist, bool isPrimary);
    event StrategistRemoved(address indexed strategy, address indexed strategist);
    event UpkeepDeposited(address indexed strategist, uint256 amount);
    event UpkeepWithdrawn(address indexed strategist, uint256 amount);
    event AuthorizedCallerAdded(address indexed strategy, address indexed caller);
    event AuthorizedCallerRemoved(address indexed strategy, address indexed caller);
    event PPSVerificationThresholdsUpdated(
        address indexed strategy,
        uint256 dispersionThreshold,
        uint256 deviationThreshold,
        uint256 mnThreshold
    );
    event PrimaryStrategistChangeProposed(address indexed strategy, address indexed newStrategist, uint256 effectiveTime);
    event PrimaryStrategistChanged(address indexed strategy, address indexed oldStrategist, address indexed newStrategist);

    function setUp() public override {
        super.setUp();
        
        // Deploy SuperGovernor
        superGovernor = SuperGovernor(A[0].superGovernor);
        
        // Deploy SuperAssetRegistry
        superAssetRegistry = new SuperAssetRegistry(address(superGovernor));
        
        // Setup upkeep token
        upkeepToken = new ERC20Mock();
        upkeepToken.mint(STRATEGIST, 1000 ether);
        upkeepToken.mint(SECONDARY_STRATEGIST, 1000 ether);
        
        // Setup strategy with primary strategist
        vm.startPrank(address(superGovernor));
        superAssetRegistry.addPrimaryStrategist(STRATEGY, STRATEGIST);
        vm.stopPrank();
        
        // Set upkeep token in governor
        vm.startPrank(address(superGovernor));
        superGovernor.setUpkeepToken(address(upkeepToken));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_constructor_ValidGovernor() public {
        SuperAssetRegistry registry = new SuperAssetRegistry(address(superGovernor));
        assertEq(address(registry.SUPER_GOVERNOR()), address(superGovernor));
    }

    function test_constructor_RevertIf_ZeroAddress() public {
        vm.expectRevert(ISuperAssetRegistry.ZERO_ADDRESS.selector);
        new SuperAssetRegistry(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                            PPS UPDATE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_forwardPPS_Success() public {
        ISuperAssetRegistry.ForwardPPSArgs memory args = ISuperAssetRegistry.ForwardPPSArgs({
            strategy: STRATEGY,
            newPPS: 1.1e18,
            newPPSStdev: 0.01e18,
            lastUpdateTimestamp: block.timestamp,
            minUpdateInterval: 1 hours
        });

        vm.expectEmit(true, false, false, true);
        emit PPSUpdated(STRATEGY, 1.1e18, 0.01e18, block.timestamp, 1 hours);

        vm.prank(STRATEGIST);
        superAssetRegistry.forwardPPS(STRATEGIST, args);

        assertEq(superAssetRegistry.getPPS(STRATEGY), 1.1e18);
        (uint256 pps, uint256 stdev) = superAssetRegistry.getPPSWithStdDev(STRATEGY);
        assertEq(pps, 1.1e18);
        assertEq(stdev, 0.01e18);
        assertEq(superAssetRegistry.getLastUpdateTimestamp(STRATEGY), block.timestamp);
        assertEq(superAssetRegistry.getMinUpdateInterval(STRATEGY), 1 hours);
    }

    function test_forwardPPS_RevertIf_UnauthorizedCaller() public {
        ISuperAssetRegistry.ForwardPPSArgs memory args = ISuperAssetRegistry.ForwardPPSArgs({
            strategy: STRATEGY,
            newPPS: 1.1e18,
            newPPSStdev: 0.01e18,
            lastUpdateTimestamp: block.timestamp,
            minUpdateInterval: 1 hours
        });

        vm.expectRevert(ISuperAssetRegistry.UNAUTHORIZED_UPDATE_AUTHORITY.selector);
        vm.prank(UNAUTHORIZED);
        superAssetRegistry.forwardPPS(UNAUTHORIZED, args);
    }

    function test_batchForwardPPS_Success() public {
        ISuperAssetRegistry.ForwardPPSArgs[] memory argsArray = new ISuperAssetRegistry.ForwardPPSArgs[](2);
        argsArray[0] = ISuperAssetRegistry.ForwardPPSArgs({
            strategy: STRATEGY,
            newPPS: 1.1e18,
            newPPSStdev: 0.01e18,
            lastUpdateTimestamp: block.timestamp,
            minUpdateInterval: 1 hours
        });
        
        address strategy2 = address(0x2345);
        vm.prank(address(superGovernor));
        superAssetRegistry.addPrimaryStrategist(strategy2, STRATEGIST);
        
        argsArray[1] = ISuperAssetRegistry.ForwardPPSArgs({
            strategy: strategy2,
            newPPS: 1.2e18,
            newPPSStdev: 0.02e18,
            lastUpdateTimestamp: block.timestamp,
            minUpdateInterval: 2 hours
        });

        address[] memory updateAuthorities = new address[](2);
        updateAuthorities[0] = STRATEGIST;
        updateAuthorities[1] = STRATEGIST;

        ISuperAssetRegistry.BatchForwardPPSArgs memory batchArgs = ISuperAssetRegistry.BatchForwardPPSArgs({
            updateAuthorities: updateAuthorities,
            argsArray: argsArray
        });

        vm.prank(STRATEGIST);
        superAssetRegistry.batchForwardPPS(batchArgs);

        assertEq(superAssetRegistry.getPPS(STRATEGY), 1.1e18);
        assertEq(superAssetRegistry.getPPS(strategy2), 1.2e18);
    }

    /*//////////////////////////////////////////////////////////////
                        STRATEGIST MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_addSecondaryStrategist_Success() public {
        vm.expectEmit(true, true, false, true);
        emit StrategistAdded(STRATEGY, SECONDARY_STRATEGIST, false);

        vm.prank(STRATEGIST);
        superAssetRegistry.addSecondaryStrategist(STRATEGY, SECONDARY_STRATEGIST);

        assertTrue(superAssetRegistry.isSecondaryStrategist(SECONDARY_STRATEGIST, STRATEGY));
        assertTrue(superAssetRegistry.isAnyStrategist(SECONDARY_STRATEGIST, STRATEGY));
    }

    function test_addSecondaryStrategist_RevertIf_NotMainStrategist() public {
        vm.expectRevert(ISuperAssetRegistry.UNAUTHORIZED_STRATEGIST_UPDATE.selector);
        vm.prank(UNAUTHORIZED);
        superAssetRegistry.addSecondaryStrategist(STRATEGY, SECONDARY_STRATEGIST);
    }

    function test_removeSecondaryStrategist_Success() public {
        // First add secondary strategist
        vm.prank(STRATEGIST);
        superAssetRegistry.addSecondaryStrategist(STRATEGY, SECONDARY_STRATEGIST);

        vm.expectEmit(true, true, false, true);
        emit StrategistRemoved(STRATEGY, SECONDARY_STRATEGIST);

        vm.prank(STRATEGIST);
        superAssetRegistry.removeSecondaryStrategist(STRATEGY, SECONDARY_STRATEGIST);

        assertFalse(superAssetRegistry.isSecondaryStrategist(SECONDARY_STRATEGIST, STRATEGY));
        assertFalse(superAssetRegistry.isAnyStrategist(SECONDARY_STRATEGIST, STRATEGY));
    }

    function test_proposeChangePrimaryStrategist_Success() public {
        uint256 timelock = 7 days;
        vm.prank(address(superGovernor));
        superAssetRegistry.setPrimaryStrategistChangeTimelock(timelock);

        vm.expectEmit(true, true, false, true);
        emit PrimaryStrategistChangeProposed(STRATEGY, NEW_STRATEGIST, block.timestamp + timelock);

        vm.prank(STRATEGIST);
        superAssetRegistry.proposeChangePrimaryStrategist(STRATEGY, NEW_STRATEGIST);

        assertEq(superAssetRegistry.getProposedPrimaryStrategist(STRATEGY), NEW_STRATEGIST);
        assertEq(superAssetRegistry.getPrimaryStrategistChangeEffectiveTime(STRATEGY), block.timestamp + timelock);
    }

    function test_executeChangePrimaryStrategist_Success() public {
        uint256 timelock = 7 days;
        vm.prank(address(superGovernor));
        superAssetRegistry.setPrimaryStrategistChangeTimelock(timelock);

        // Propose change
        vm.prank(STRATEGIST);
        superAssetRegistry.proposeChangePrimaryStrategist(STRATEGY, NEW_STRATEGIST);

        // Fast forward time
        vm.warp(block.timestamp + timelock + 1);

        vm.expectEmit(true, true, true, true);
        emit PrimaryStrategistChanged(STRATEGY, STRATEGIST, NEW_STRATEGIST);

        superAssetRegistry.executeChangePrimaryStrategist(STRATEGY);

        assertEq(superAssetRegistry.getMainStrategist(STRATEGY), NEW_STRATEGIST);
        assertEq(superAssetRegistry.getProposedPrimaryStrategist(STRATEGY), address(0));
    }

    function test_executeChangePrimaryStrategist_RevertIf_TimelockNotMet() public {
        uint256 timelock = 7 days;
        vm.prank(address(superGovernor));
        superAssetRegistry.setPrimaryStrategistChangeTimelock(timelock);

        // Propose change
        vm.prank(STRATEGIST);
        superAssetRegistry.proposeChangePrimaryStrategist(STRATEGY, NEW_STRATEGIST);

        // Try to execute before timelock
        vm.expectRevert(ISuperAssetRegistry.TIMELOCK_NOT_MET.selector);
        superAssetRegistry.executeChangePrimaryStrategist(STRATEGY);
    }

    /*//////////////////////////////////////////////////////////////
                            UPKEEP TESTS
    //////////////////////////////////////////////////////////////*/

    function test_depositUpkeep_Success() public {
        uint256 amount = 100e18;
        
        vm.startPrank(STRATEGIST);
        upkeepToken.approve(address(superAssetRegistry), amount);
        
        vm.expectEmit(true, false, false, true);
        emit UpkeepDeposited(STRATEGIST, amount);
        
        superAssetRegistry.depositUpkeep(STRATEGIST, amount);
        vm.stopPrank();

        assertEq(superAssetRegistry.getUpkeepBalance(STRATEGIST), amount);
        assertEq(upkeepToken.balanceOf(address(superAssetRegistry)), amount);
    }

    function test_withdrawUpkeep_Success() public {
        uint256 depositAmount = 100e18;
        uint256 withdrawAmount = 50e18;
        
        // First deposit
        vm.startPrank(STRATEGIST);
        upkeepToken.approve(address(superAssetRegistry), depositAmount);
        superAssetRegistry.depositUpkeep(STRATEGIST, depositAmount);
        
        vm.expectEmit(true, false, false, true);
        emit UpkeepWithdrawn(STRATEGIST, withdrawAmount);
        
        superAssetRegistry.withdrawUpkeep(withdrawAmount);
        vm.stopPrank();

        assertEq(superAssetRegistry.getUpkeepBalance(STRATEGIST), depositAmount - withdrawAmount);
        assertEq(upkeepToken.balanceOf(STRATEGIST), 1000e18 - depositAmount + withdrawAmount);
    }

    function test_withdrawUpkeep_RevertIf_InsufficientBalance() public {
        vm.expectRevert(ISuperAssetRegistry.INSUFFICIENT_UPKEEP_BALANCE.selector);
        vm.prank(STRATEGIST);
        superAssetRegistry.withdrawUpkeep(100e18);
    }

    /*//////////////////////////////////////////////////////////////
                        AUTHORIZED CALLER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_addAuthorizedCaller_Success() public {
        address caller = address(0x9999);
        
        vm.expectEmit(true, true, false, true);
        emit AuthorizedCallerAdded(STRATEGY, caller);
        
        vm.prank(STRATEGIST);
        superAssetRegistry.addAuthorizedCaller(STRATEGY, caller);

        assertTrue(superAssetRegistry.isAuthorizedCaller(caller, STRATEGY));
    }

    function test_removeAuthorizedCaller_Success() public {
        address caller = address(0x9999);
        
        // First add
        vm.prank(STRATEGIST);
        superAssetRegistry.addAuthorizedCaller(STRATEGY, caller);
        
        vm.expectEmit(true, true, false, true);
        emit AuthorizedCallerRemoved(STRATEGY, caller);
        
        vm.prank(STRATEGIST);
        superAssetRegistry.removeAuthorizedCaller(STRATEGY, caller);

        assertFalse(superAssetRegistry.isAuthorizedCaller(caller, STRATEGY));
    }

    /*//////////////////////////////////////////////////////////////
                    PPS VERIFICATION THRESHOLD TESTS
    //////////////////////////////////////////////////////////////*/

    function test_updatePPSVerificationThresholds_Success() public {
        uint256 dispersionThreshold = 500; // 5%
        uint256 deviationThreshold = 300; // 3%
        uint256 mnThreshold = 200; // 2%
        
        vm.expectEmit(true, false, false, true);
        emit PPSVerificationThresholdsUpdated(STRATEGY, dispersionThreshold, deviationThreshold, mnThreshold);
        
        vm.prank(STRATEGIST);
        superAssetRegistry.updatePPSVerificationThresholds(
            STRATEGY, 
            dispersionThreshold, 
            deviationThreshold, 
            mnThreshold
        );

        (uint256 disp, uint256 dev, uint256 mn) = superAssetRegistry.getPPSVerificationThresholds(STRATEGY);
        assertEq(disp, dispersionThreshold);
        assertEq(dev, deviationThreshold);
        assertEq(mn, mnThreshold);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setPrimaryStrategistChangeTimelock_OnlyGovernor() public {
        uint256 newTimelock = 14 days;
        
        vm.prank(address(superGovernor));
        superAssetRegistry.setPrimaryStrategistChangeTimelock(newTimelock);
        
        assertEq(superAssetRegistry.getPrimaryStrategistChangeTimelock(), newTimelock);
    }

    function test_setPrimaryStrategistChangeTimelock_RevertIf_NotGovernor() public {
        vm.expectRevert(); // Will revert due to access control
        vm.prank(UNAUTHORIZED);
        superAssetRegistry.setPrimaryStrategistChangeTimelock(14 days);
    }

    function test_addPrimaryStrategist_OnlyGovernor() public {
        address newStrategy = address(0x8888);
        
        vm.prank(address(superGovernor));
        superAssetRegistry.addPrimaryStrategist(newStrategy, NEW_STRATEGIST);
        
        assertEq(superAssetRegistry.getMainStrategist(newStrategy), NEW_STRATEGIST);
        assertTrue(superAssetRegistry.isAnyStrategist(NEW_STRATEGIST, newStrategy));
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_isMainStrategist_True() public {
        assertTrue(superAssetRegistry.isMainStrategist(STRATEGIST, STRATEGY));
    }

    function test_isMainStrategist_False() public {
        assertFalse(superAssetRegistry.isMainStrategist(UNAUTHORIZED, STRATEGY));
    }

    function test_getUpkeepBalance_Zero() public {
        assertEq(superAssetRegistry.getUpkeepBalance(STRATEGIST), 0);
    }

    function test_getPPS_DefaultValue() public {
        assertEq(superAssetRegistry.getPPS(STRATEGY), 1e18); // Default PPS is 1.0
    }

    function test_getPPSWithStdDev_DefaultValues() public {
        (uint256 pps, uint256 stdev) = superAssetRegistry.getPPSWithStdDev(STRATEGY);
        assertEq(pps, 1e18);
        assertEq(stdev, 0);
    }

    function test_getLastUpdateTimestamp_DefaultValue() public {
        assertEq(superAssetRegistry.getLastUpdateTimestamp(STRATEGY), 0);
    }

    function test_getMinUpdateInterval_DefaultValue() public {
        assertEq(superAssetRegistry.getMinUpdateInterval(STRATEGY), 0);
    }

    function test_getPPSVerificationThresholds_DefaultValues() public {
        (uint256 disp, uint256 dev, uint256 mn) = superAssetRegistry.getPPSVerificationThresholds(STRATEGY);
        assertEq(disp, 1000); // 10% default
        assertEq(dev, 500); // 5% default  
        assertEq(mn, 300); // 3% default
    }
} 