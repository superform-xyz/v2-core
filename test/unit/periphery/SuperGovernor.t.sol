// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { SuperGovernor } from "src/periphery/SuperGovernor.sol";
import { ISuperGovernor, FeeType } from "src/periphery/interfaces/ISuperGovernor.sol";
import { BaseTest } from "test/BaseTest.t.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { ISuperVaultAggregator } from "src/periphery/interfaces/ISuperVaultAggregator.sol";
import { SuperVaultAggregator } from "src/periphery/SuperVault/SuperVaultAggregator.sol";
import { Helpers } from "../../utils/Helpers.sol";

contract SuperGovernorTest is Helpers {
    SuperGovernor internal superGovernor;

    // Roles & Addresses
    address internal sGovernor;
    address internal governor;
    address internal treasury;
    address internal user;
    address internal hook1;
    address internal hook2;
    address internal fulfillHook1;
    address internal fulfillHook2;
    address internal validator1;
    address internal validator2;
    address internal ppsOracle1;
    address internal ppsOracle2;
    address internal superVaultAggregator;
    address internal strategy1;
    address internal newStrategist;

    // Role Hashes
    bytes32 internal constant SUPER_GOVERNOR_ROLE = keccak256("SUPER_GOVERNOR_ROLE");
    bytes32 internal constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 internal constant SUPER_VAULT_AGGREGATOR = keccak256("SUPER_VAULT_AGGREGATOR");

    // Keys
    bytes32 internal constant TEST_KEY = keccak256("TEST_KEY");

    // Constants
    uint256 internal constant TIMELOCK = 7 days;
    uint256 internal constant BPS_MAX = 10_000;

    /// @notice Sets up the test environment before each test case.
    function setUp() public {
        sGovernor = _deployAccount(0x1, "SuperGovernor");
        governor = _deployAccount(0x2, "Governor");
        treasury = _deployAccount(0x3, "Treasury");
        user = _deployAccount(0x4, "User");
        hook1 = _deployAccount(0x5, "Hook1");
        hook2 = _deployAccount(0x6, "Hook2");
        fulfillHook1 = _deployAccount(0x7, "FulfillHook1");
        fulfillHook2 = _deployAccount(0x8, "FulfillHook2");
        validator1 = _deployAccount(0x9, "Validator1");
        validator2 = _deployAccount(0xA, "Validator2");
        ppsOracle1 = _deployAccount(0xB, "PPSOracle1");
        ppsOracle2 = _deployAccount(0xC, "PPSOracle2");
        newStrategist = _deployAccount(0xF, "NewStrategist");

        superGovernor = new SuperGovernor(sGovernor, governor, treasury);
        superVaultAggregator = address(new SuperVaultAggregator(address(superGovernor)));
        (, address strategy,) = ISuperVaultAggregator(superVaultAggregator).createVault(
            ISuperVaultAggregator.VaultCreationParams({
                asset: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
                manager: address(this),
                mainStrategist: address(this),
                feeRecipient: address(this),
                name: "SUP",
                symbol: "SUP",
                minUpdateInterval: 5,
                maxStaleness: 300,
                superVaultCap: 1e9
            })
        );
        strategy1 = strategy;
    }

    // =============================================================
    // Constructor Tests
    // =============================================================

    /// @notice Tests if the constructor correctly sets initial roles and treasury.
    function test_constructor_InitialState() public view {
        assertTrue(superGovernor.hasRole(SUPER_GOVERNOR_ROLE, sGovernor), "Admin should have SUPER_GOVERNOR_ROLE");
        assertTrue(superGovernor.hasRole(GOVERNOR_ROLE, governor), "Governor should have GOVERNOR_ROLE");
        assertEq(superGovernor.getAddress(superGovernor.TREASURY()), treasury, "Treasury address mismatch");
    }

    /// @notice Tests constructor revert on zero address superGovernor.
    function test_constructor_Revert_ZeroAdmin() public {
        vm.expectRevert(ISuperGovernor.INVALID_ADDRESS.selector);
        new SuperGovernor(address(0), governor, treasury);
    }

    /// @notice Tests constructor revert on zero address governor.
    function test_constructor_Revert_ZeroGovernor() public {
        vm.expectRevert(ISuperGovernor.INVALID_ADDRESS.selector);
        new SuperGovernor(sGovernor, address(0), treasury);
    }

    /// @notice Tests constructor revert on zero address treasury.
    function test_constructor_Revert_ZeroTreasury() public {
        vm.expectRevert(ISuperGovernor.INVALID_ADDRESS.selector);
        new SuperGovernor(sGovernor, governor, address(0));
    }

    // =============================================================
    // Role Tests
    // =============================================================

    /// @notice Tests that only SUPER_GOVERNOR_ROLE can call SUPER_GOVERNOR_ROLE functions.
    function test_Role_SuperGovernorOnlyFunctions() public {
        vm.prank(governor);
        // Expected role hash for SUPER_GOVERNOR_ROLE
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, governor, SUPER_GOVERNOR_ROLE
            )
        );
        superGovernor.setAddress(TEST_KEY, user);

        vm.prank(sGovernor);
        superGovernor.setAddress(TEST_KEY, user); // Should succeed
    }

    /// @notice Tests that only GOVERNOR_ROLE can call GOVERNOR_ROLE functions.
    function test_Role_GovernorOnlyFunctions() public {
        vm.prank(sGovernor); // Admin has SUPER_GOVERNOR_ROLE but not GOVERNOR_ROLE by default
        // Expected role hash for GOVERNOR_ROLE
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, sGovernor, GOVERNOR_ROLE)
        );
        superGovernor.addValidator(validator1);

        vm.prank(governor);
        superGovernor.addValidator(validator1); // Should succeed
    }

    // =============================================================
    // Address Registry Tests
    // =============================================================

    /// @notice Tests setting and getting an address.
    function test_AddressRegistry_SetAndGetAddress() public {
        vm.prank(sGovernor);
        vm.expectEmit(true, true, true, true);
        emit ISuperGovernor.AddressSet(TEST_KEY, user);
        superGovernor.setAddress(TEST_KEY, user);

        assertEq(superGovernor.getAddress(TEST_KEY), user, "Address mismatch");
    }

    /// @notice Tests setting an address with SUPER_GOVERNOR_ROLE.
    function test_AddressRegistry_SetAddress_AccessControl() public {
        // Test with governor role (should fail)
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, governor, SUPER_GOVERNOR_ROLE
            )
        );
        superGovernor.setAddress(TEST_KEY, user);

        // Test with superGovernor role (should succeed)
        vm.prank(sGovernor);
        superGovernor.setAddress(TEST_KEY, user);
        assertEq(superGovernor.getAddress(TEST_KEY), user);
    }

    /// @notice Tests reverting when setting address to address(0).
    function test_AddressRegistry_SetAddress_Revert_ZeroAddress() public {
        vm.prank(sGovernor);
        vm.expectRevert(ISuperGovernor.INVALID_ADDRESS.selector);
        superGovernor.setAddress(TEST_KEY, address(0));
    }

    /// @notice Tests reverting when getting a non-existent address.
    function test_AddressRegistry_GetAddress_Revert_NotFound() public {
        vm.expectRevert(ISuperGovernor.CONTRACT_NOT_FOUND.selector);
        superGovernor.getAddress(keccak256("NON_EXISTENT"));
    }

    // =============================================================
    // Strategist Takeover Tests
    // =============================================================

    /// @notice Tests changing a strategist for a strategy
    function test_StrategistTakeover_ChangeStrategist() public {
        // Set up SuperVaultAggregator address in registry
        vm.prank(sGovernor);
        superGovernor.setAddress(SUPER_VAULT_AGGREGATOR, superVaultAggregator);

        // Test with governor role
        vm.prank(sGovernor);
        superGovernor.changePrimaryStrategist(strategy1, newStrategist);

        assertEq(ISuperVaultAggregator(superVaultAggregator).getMainStrategist(strategy1), newStrategist);
    }

    /// @notice Tests reverting when changing strategist to address(0)
    function test_StrategistTakeover_Revert_ZeroStrategist() public {
        // Set up SuperVaultAggregator address in registry
        vm.prank(sGovernor);
        superGovernor.setAddress(SUPER_VAULT_AGGREGATOR, superVaultAggregator);

        vm.prank(sGovernor);
        vm.expectRevert(ISuperGovernor.INVALID_ADDRESS.selector);
        superGovernor.changePrimaryStrategist(strategy1, address(0));
    }

    /// @notice Tests reverting when changing strategy to address(0)
    function test_StrategistTakeover_Revert_ZeroStrategy() public {
        // Set up SuperVaultAggregator address in registry
        vm.prank(sGovernor);
        superGovernor.setAddress(SUPER_VAULT_AGGREGATOR, superVaultAggregator);

        vm.prank(sGovernor);
        vm.expectRevert(ISuperGovernor.INVALID_ADDRESS.selector);
        superGovernor.changePrimaryStrategist(address(0), newStrategist);
    }

    /// @notice Tests freezing strategist takeovers
    function test_StrategistTakeover_Freeze() public {
        vm.prank(sGovernor);
        vm.expectEmit(true, false, false, false);
        emit ISuperGovernor.StrategistTakeoversFrozen();
        superGovernor.freezeStrategistTakeover();

        assertTrue(superGovernor.isStrategistTakeoverFrozen(), "Strategist takeovers should be frozen");
    }

    /// @notice Tests reverting when trying to freeze already frozen strategist takeovers
    function test_StrategistTakeover_Revert_AlreadyFrozen() public {
        // First freeze
        vm.prank(sGovernor);
        superGovernor.freezeStrategistTakeover();

        // Try to freeze again
        vm.prank(sGovernor);
        vm.expectRevert(ISuperGovernor.STRATEGIST_TAKEOVERS_FROZEN.selector);
        superGovernor.freezeStrategistTakeover();
    }

    /// @notice Tests reverting when trying to change strategist after freeze
    function test_StrategistTakeover_Revert_FrozenChangeAttempt() public {
        // Set up SuperVaultAggregator address in registry
        vm.prank(sGovernor);
        superGovernor.setAddress(SUPER_VAULT_AGGREGATOR, superVaultAggregator);

        // Freeze strategist takeovers
        vm.prank(sGovernor);
        superGovernor.freezeStrategistTakeover();

        // Try to change strategist after freeze
        vm.prank(sGovernor);
        vm.expectRevert(ISuperGovernor.STRATEGIST_TAKEOVERS_FROZEN.selector);
        superGovernor.changePrimaryStrategist(strategy1, newStrategist);
    }

    // =============================================================
    // Hook Management Tests
    // =============================================================

    /// @notice Tests registering a hook
    function test_HookManagement_RegisterHook() public {
        vm.prank(governor);
        vm.expectEmit(true, false, false, false);
        emit ISuperGovernor.HookApproved(hook1);
        superGovernor.registerHook(hook1, false);

        assertTrue(superGovernor.isHookRegistered(hook1), "Hook should be registered");
        assertFalse(
            superGovernor.isFulfillRequestsHookRegistered(hook1),
            "Hook should not be registered as fulfill requests hook"
        );
    }

    /// @notice Tests registering a fulfill requests hook
    function test_HookManagement_RegisterFulfillRequestsHook() public {
        vm.prank(governor);
        vm.expectEmit(true, false, false, false);
        emit ISuperGovernor.FulfillRequestsHookRegistered(fulfillHook1);
        superGovernor.registerHook(fulfillHook1, true);

        assertTrue(
            superGovernor.isFulfillRequestsHookRegistered(fulfillHook1),
            "Hook should be registered as fulfill requests hook"
        );
        assertFalse(superGovernor.isHookRegistered(fulfillHook1), "Hook should not be registered as regular hook");
    }

    /// @notice Tests reverting when registering a hook with zero address
    function test_HookManagement_Revert_ZeroAddress() public {
        vm.prank(governor);
        vm.expectRevert(ISuperGovernor.INVALID_ADDRESS.selector);
        superGovernor.registerHook(address(0), false);
    }

    /// @notice Tests reverting when registering an already registered hook
    function test_HookManagement_Revert_AlreadyRegistered() public {
        // Register hook first
        vm.prank(governor);
        superGovernor.registerHook(hook1, false);

        // Try to register again
        vm.prank(governor);
        vm.expectRevert(ISuperGovernor.HOOK_ALREADY_APPROVED.selector);
        superGovernor.registerHook(hook1, false);
    }

    /// @notice Tests reverting when registering an already registered fulfill requests hook
    function test_HookManagement_Revert_FulfillHookAlreadyRegistered() public {
        // Register fulfill hook first
        vm.prank(governor);
        superGovernor.registerHook(fulfillHook1, true);

        // Try to register again
        vm.prank(governor);
        vm.expectRevert(ISuperGovernor.FULFILL_REQUESTS_HOOK_ALREADY_REGISTERED.selector);
        superGovernor.registerHook(fulfillHook1, true);
    }

    /// @notice Tests unregistering a hook
    function test_HookManagement_UnregisterHook() public {
        // Register hook first
        vm.prank(governor);
        superGovernor.registerHook(hook1, false);

        // Unregister hook
        vm.prank(governor);
        vm.expectEmit(true, false, false, false);
        emit ISuperGovernor.HookRemoved(hook1);
        superGovernor.unregisterHook(hook1, false);

        assertFalse(superGovernor.isHookRegistered(hook1), "Hook should be unregistered");
    }

    /// @notice Tests unregistering a fulfill requests hook
    function test_HookManagement_UnregisterFulfillRequestsHook() public {
        // Register fulfill hook first
        vm.prank(governor);
        superGovernor.registerHook(fulfillHook1, true);

        // Unregister fulfill hook
        vm.prank(governor);
        vm.expectEmit(true, false, false, false);
        emit ISuperGovernor.FulfillRequestsHookUnregistered(fulfillHook1);
        superGovernor.unregisterHook(fulfillHook1, true);

        assertFalse(superGovernor.isFulfillRequestsHookRegistered(fulfillHook1), "Fulfill hook should be unregistered");
    }

    /// @notice Tests getting the list of registered hooks
    function test_HookManagement_GetRegisteredHooks() public {
        // Register two hooks
        vm.startPrank(governor);
        superGovernor.registerHook(hook1, false);
        superGovernor.registerHook(hook2, false);
        vm.stopPrank();

        address[] memory hooks = superGovernor.getRegisteredHooks();
        assertEq(hooks.length, 2, "Should have 2 registered hooks");
        assertTrue(hooks[0] == hook1 || hooks[1] == hook1, "hook1 should be in the list");
        assertTrue(hooks[0] == hook2 || hooks[1] == hook2, "hook2 should be in the list");
    }

    /// @notice Tests getting the list of registered fulfill requests hooks
    function test_HookManagement_GetRegisteredFulfillRequestsHooks() public {
        // Register two fulfill hooks
        vm.startPrank(governor);
        superGovernor.registerHook(fulfillHook1, true);
        superGovernor.registerHook(fulfillHook2, true);
        vm.stopPrank();

        address[] memory hooks = superGovernor.getRegisteredFulfillRequestsHooks();
        assertEq(hooks.length, 2, "Should have 2 registered fulfill hooks");
        assertTrue(hooks[0] == fulfillHook1 || hooks[1] == fulfillHook1, "fulfillHook1 should be in the list");
        assertTrue(hooks[0] == fulfillHook2 || hooks[1] == fulfillHook2, "fulfillHook2 should be in the list");
    }

    // =============================================================
    // Validator Management Tests
    // =============================================================

    /// @notice Tests adding a validator
    function test_ValidatorManagement_AddValidator() public {
        vm.prank(governor);
        vm.expectEmit(true, false, false, false);
        emit ISuperGovernor.ValidatorAdded(validator1);
        superGovernor.addValidator(validator1);

        assertTrue(superGovernor.isValidator(validator1), "Validator should be added");
        address[] memory validators = superGovernor.getValidators();
        assertEq(validators.length, 1, "Should have 1 validator");
        assertEq(validators[0], validator1, "Validator in list should match");
    }

    /// @notice Tests reverting when adding a validator with zero address
    function test_ValidatorManagement_Revert_ZeroAddress() public {
        vm.prank(governor);
        vm.expectRevert(ISuperGovernor.INVALID_ADDRESS.selector);
        superGovernor.addValidator(address(0));
    }

    /// @notice Tests reverting when adding an already registered validator
    function test_ValidatorManagement_Revert_AlreadyRegistered() public {
        // Add validator first
        vm.prank(governor);
        superGovernor.addValidator(validator1);

        // Try to add again
        vm.prank(governor);
        vm.expectRevert(ISuperGovernor.VALIDATOR_ALREADY_REGISTERED.selector);
        superGovernor.addValidator(validator1);
    }

    /// @notice Tests removing a validator
    function test_ValidatorManagement_RemoveValidator() public {
        // Add validator first
        vm.prank(governor);
        superGovernor.addValidator(validator1);

        // Remove validator
        vm.prank(governor);
        vm.expectEmit(true, false, false, false);
        emit ISuperGovernor.ValidatorRemoved(validator1);
        superGovernor.removeValidator(validator1);

        assertFalse(superGovernor.isValidator(validator1), "Validator should be removed");
        address[] memory validators = superGovernor.getValidators();
        assertEq(validators.length, 0, "Should have 0 validators");
    }

    /// @notice Tests reverting when removing a non-existent validator
    function test_ValidatorManagement_Revert_NotRegistered() public {
        vm.prank(governor);
        vm.expectRevert(ISuperGovernor.VALIDATOR_NOT_REGISTERED.selector);
        superGovernor.removeValidator(validator1);
    }

    /// @notice Tests removing a validator when multiple validators exist
    function test_ValidatorManagement_RemoveValidatorWithMultiple() public {
        // Add two validators
        vm.startPrank(governor);
        superGovernor.addValidator(validator1);
        superGovernor.addValidator(validator2);
        vm.stopPrank();

        // Remove the first validator
        vm.prank(governor);
        superGovernor.removeValidator(validator1);

        assertFalse(superGovernor.isValidator(validator1), "validator1 should be removed");
        assertTrue(superGovernor.isValidator(validator2), "validator2 should still be registered");

        address[] memory validators = superGovernor.getValidators();
        assertEq(validators.length, 1, "Should have 1 validator remaining");
        assertEq(validators[0], validator2, "Remaining validator should be validator2");
    }

    // =============================================================
    // PPS Oracle Management Tests
    // =============================================================

    /// @notice Tests proposing a new active PPS Oracle
    function test_PPSOracleManagement_ProposeActivePPSOracle() public {
        uint256 expectedTime = block.timestamp + TIMELOCK;

        vm.prank(sGovernor);
        vm.expectEmit(true, true, false, false);
        emit ISuperGovernor.ActivePPSOracleProposed(ppsOracle1, expectedTime);
        superGovernor.proposeActivePPSOracle(ppsOracle1);

        (address proposedOracle, uint256 effectiveTime) = superGovernor.getProposedActivePPSOracle();
        assertEq(proposedOracle, ppsOracle1, "Proposed PPS Oracle address mismatch");
        assertEq(effectiveTime, expectedTime, "Effective time mismatch");
    }

    /// @notice Tests reverting when proposing a PPS Oracle with zero address
    function test_PPSOracleManagement_Revert_ProposeZeroAddress() public {
        vm.prank(sGovernor);
        vm.expectRevert(ISuperGovernor.INVALID_ADDRESS.selector);
        superGovernor.proposeActivePPSOracle(address(0));
    }

    /// @notice Tests executing a PPS Oracle change
    function test_PPSOracleManagement_ExecuteActivePPSOracleChange() public {
        // Propose a new PPS Oracle
        vm.prank(sGovernor);
        superGovernor.proposeActivePPSOracle(ppsOracle1);

        // Warp to after timelock
        vm.warp(block.timestamp + TIMELOCK + 1);

        // Execute the change
        vm.expectEmit(true, false, false, false);
        emit ISuperGovernor.ActivePPSOracleChanged(address(0), ppsOracle1);
        superGovernor.executeActivePPSOracleChange();

        assertEq(superGovernor.getActivePPSOracle(), ppsOracle1, "Active PPS Oracle should be updated");
        assertTrue(superGovernor.isActivePPSOracle(ppsOracle1), "isActivePPSOracle should return true");

        // Check that proposal data is reset
        (address proposedOracle,) = superGovernor.getProposedActivePPSOracle();
        assertEq(proposedOracle, address(0), "Proposed PPS Oracle should be reset");
    }

    /// @notice Tests reverting when executing without a proposal
    function test_PPSOracleManagement_Revert_ExecuteNoProposal() public {
        vm.expectRevert(ISuperGovernor.NO_PROPOSED_PPS_ORACLE.selector);
        superGovernor.executeActivePPSOracleChange();
    }

    /// @notice Tests reverting when executing before timelock expiry
    function test_PPSOracleManagement_Revert_ExecuteBeforeTimelock() public {
        // Propose a new PPS Oracle
        vm.prank(sGovernor);
        superGovernor.proposeActivePPSOracle(ppsOracle1);

        // Try to execute before timelock expires
        vm.expectRevert(ISuperGovernor.TIMELOCK_NOT_EXPIRED.selector);
        superGovernor.executeActivePPSOracleChange();
    }

    /// @notice Tests setting the PPS Oracle quorum
    function test_PPSOracleManagement_SetPPSOracleQuorum() public {
        uint256 newQuorum = 3;

        vm.prank(governor);
        vm.expectEmit(true, false, false, false);
        emit ISuperGovernor.PPSOracleQuorumUpdated(newQuorum);
        superGovernor.setPPSOracleQuorum(newQuorum);

        assertEq(superGovernor.getPPSOracleQuorum(), newQuorum, "PPS Oracle quorum mismatch");
    }

    // =============================================================
    // Fee Management Tests
    // =============================================================

    /// @notice Tests proposing a new fee
    function test_FeeManagement_ProposeFee() public {
        FeeType feeType = FeeType.REVENUE_SHARE;
        uint256 feeValue = 50; // 0.5% in basis points
        uint256 expectedTime = block.timestamp + TIMELOCK;

        vm.prank(sGovernor);
        vm.expectEmit(true, true, true, false);
        emit ISuperGovernor.FeeProposed(feeType, feeValue, expectedTime);
        superGovernor.proposeFee(feeType, feeValue);

        // Since we can't directly check the proposed fee value, we'll test it through execution
    }

    /// @notice Tests reverting when proposing an invalid fee value
    function test_FeeManagement_Revert_InvalidFeeValue() public {
        FeeType feeType = FeeType.REVENUE_SHARE;
        uint256 invalidFeeValue = BPS_MAX + 1; // Greater than max

        vm.prank(sGovernor);
        vm.expectRevert(ISuperGovernor.INVALID_FEE_VALUE.selector);
        superGovernor.proposeFee(feeType, invalidFeeValue);
    }

    /// @notice Tests executing a fee update
    function test_FeeManagement_ExecuteFeeUpdate() public {
        FeeType feeType = FeeType.REVENUE_SHARE;
        uint256 feeValue = 50; // 0.5% in basis points

        // Propose new fee
        vm.prank(sGovernor);
        superGovernor.proposeFee(feeType, feeValue);

        // Warp to after timelock
        vm.warp(block.timestamp + TIMELOCK + 1);

        // Execute the fee update
        vm.expectEmit(true, true, false, false);
        emit ISuperGovernor.FeeUpdated(feeType, feeValue);
        superGovernor.executeFeeUpdate(feeType);

        assertEq(superGovernor.getFee(feeType), feeValue, "Fee value mismatch");
    }

    /// @notice Tests reverting when executing a fee update without a proposal
    function test_FeeManagement_Revert_ExecuteNoProposal() public {
        FeeType feeType = FeeType.REVENUE_SHARE;

        vm.expectRevert(abi.encodeWithSelector(ISuperGovernor.NO_PROPOSED_FEE.selector, feeType));
        superGovernor.executeFeeUpdate(feeType);
    }

    /// @notice Tests reverting when executing a fee update before timelock expiry
    function test_FeeManagement_Revert_ExecuteBeforeTimelock() public {
        FeeType feeType = FeeType.REVENUE_SHARE;
        uint256 feeValue = 50;

        // Propose new fee
        vm.prank(sGovernor);
        superGovernor.proposeFee(feeType, feeValue);

        // Try to execute before timelock expires
        vm.expectRevert(abi.encodeWithSelector(ISuperGovernor.TIMELOCK_NOT_EXPIRED.selector));
        superGovernor.executeFeeUpdate(feeType);
    }

    // =============================================================
    // SuperBank Hook Merkle Root Tests
    // =============================================================

    /// @notice Tests proposing a new SuperBank hook merkle root
    function test_MerkleRoot_ProposeMerkleRoot() public {
        // First register the hook
        vm.prank(governor);
        superGovernor.registerHook(hook1, false);

        // Propose a new merkle root
        bytes32 proposedRoot = keccak256("test_root");
        uint256 expectedTime = block.timestamp + TIMELOCK;

        vm.prank(governor);
        vm.expectEmit(true, true, true, false);
        emit ISuperGovernor.SuperBankHookMerkleRootProposed(hook1, proposedRoot, expectedTime);
        superGovernor.proposeSuperBankHookMerkleRoot(hook1, proposedRoot);

        (bytes32 actualProposedRoot, uint256 effectiveTime) = superGovernor.getProposedSuperBankHookMerkleRoot(hook1);
        assertEq(actualProposedRoot, proposedRoot, "Proposed merkle root mismatch");
        assertEq(effectiveTime, expectedTime, "Effective time mismatch");
    }

    /// @notice Tests reverting when proposing a merkle root for an unregistered hook
    function test_MerkleRoot_Revert_HookNotApproved() public {
        bytes32 proposedRoot = keccak256("test_root");

        vm.prank(governor);
        vm.expectRevert(ISuperGovernor.HOOK_NOT_APPROVED.selector);
        superGovernor.proposeSuperBankHookMerkleRoot(hook1, proposedRoot);
    }

    /// @notice Tests executing a merkle root update
    function test_MerkleRoot_ExecuteMerkleRootUpdate() public {
        // Register the hook
        vm.prank(governor);
        superGovernor.registerHook(hook1, false);

        // Propose a new merkle root
        bytes32 proposedRoot = keccak256("test_root");
        vm.prank(governor);
        superGovernor.proposeSuperBankHookMerkleRoot(hook1, proposedRoot);

        // Warp to after timelock
        vm.warp(block.timestamp + TIMELOCK + 1);

        // Execute the merkle root update
        vm.expectEmit(true, true, false, false);
        emit ISuperGovernor.SuperBankHookMerkleRootUpdated(hook1, proposedRoot);
        superGovernor.executeSuperBankHookMerkleRootUpdate(hook1);

        assertEq(superGovernor.getSuperBankHookMerkleRoot(hook1), proposedRoot, "Merkle root mismatch");
    }

    /// @notice Tests reverting when executing a merkle root update for an unregistered hook
    function test_MerkleRoot_Revert_ExecuteHookNotApproved() public {
        vm.expectRevert(ISuperGovernor.HOOK_NOT_APPROVED.selector);
        superGovernor.executeSuperBankHookMerkleRootUpdate(hook1);
    }

    /// @notice Tests reverting when executing without a merkle root proposal
    function test_MerkleRoot_Revert_ExecuteNoProposal() public {
        // Register the hook
        vm.prank(governor);
        superGovernor.registerHook(hook1, false);

        // Try to execute without a proposal
        vm.expectRevert(ISuperGovernor.NO_PROPOSED_MERKLE_ROOT.selector);
        superGovernor.executeSuperBankHookMerkleRootUpdate(hook1);
    }

    /// @notice Tests reverting when executing a merkle root update before timelock expiry
    function test_MerkleRoot_Revert_ExecuteBeforeTimelock() public {
        // Register the hook
        vm.prank(governor);
        superGovernor.registerHook(hook1, false);

        // Propose a new merkle root
        bytes32 proposedRoot = keccak256("test_root");
        vm.prank(governor);
        superGovernor.proposeSuperBankHookMerkleRoot(hook1, proposedRoot);

        // Try to execute before timelock expires
        vm.expectRevert(ISuperGovernor.TIMELOCK_NOT_EXPIRED.selector);
        superGovernor.executeSuperBankHookMerkleRootUpdate(hook1);
    }
}
