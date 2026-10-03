// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

// external
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

// superform
import { AaveV4ReserveRegistryV2 } from "../../../../src/accounting/oracles/AaveV4ReserveRegistryV2.sol";
import { AaveV4ReserveKey } from "../../../../src/libraries/AaveV4ReserveKey.sol";
import { IAaveV4Spoke } from "../../../../src/vendor/aave-v4/IAaveV4Spoke.sol";

/// @dev Minimal Aave V4 spoke stand-in for registry tests: only `getReserve` matters here (the
///      registry never touches balances). `getReserve` reverts for unlisted ids, matching the real
///      spoke, which is the revert the registry deliberately lets surface to its caller.
contract MockLifecycleSpoke {
    error ReserveNotListed();

    mapping(uint256 => IAaveV4Spoke.Reserve) internal reserves;
    mapping(uint256 => bool) internal listed;

    function setReserve(uint256 reserveId, address underlying, uint8 decimals_) external {
        reserves[reserveId] = IAaveV4Spoke.Reserve({
            underlying: underlying,
            hub: address(this),
            assetId: uint16(reserveId),
            decimals: decimals_,
            collateralRisk: 0,
            flags: 0,
            dynamicConfigKey: 0
        });
        listed[reserveId] = true;
    }

    function getReserve(uint256 reserveId) external view returns (IAaveV4Spoke.Reserve memory) {
        if (!listed[reserveId]) revert ReserveNotListed();
        return reserves[reserveId];
    }
}

/// @title AaveV4ReserveRegistryLifecycle
/// @notice Exhaustive lifecycle coverage for `AaveV4ReserveRegistryV2`: role gating, the two-leg
///         (SUPPLY/DEBT) atomic registration introduced with `Side`, the per-key deregistration
///         timelock matrix, and the SUPPLY/DEBT asymmetry that per-key deregistration creates on
///         top of per-reserve registration.
contract AaveV4ReserveRegistryLifecycleTest is Test {
    AaveV4ReserveRegistryV2 internal registry;
    MockLifecycleSpoke internal spoke;

    address internal admin;
    address internal manager;
    address internal newManager;
    address internal newAdmin;
    address internal outsider;
    address internal usdc;
    address internal weth;

    uint256 internal constant USDC_RESERVE_ID = 7;
    uint256 internal constant WETH_RESERVE_ID = 12;
    uint256 internal constant UNLISTED_RESERVE_ID = 999;
    uint256 internal constant ZERO_UNDERLYING_RESERVE_ID = 31;

    /// @dev SUPPLY leg key — the unchanged legacy two-word derivation
    address internal usdcKey;
    /// @dev DEBT leg key — the `DEBT_KEY_DOMAIN`-separated three-word derivation
    address internal usdcDebtKey;

    bytes32 internal MANAGER_ROLE;
    bytes32 internal ADMIN_ROLE;

    function setUp() public {
        // Keep block.timestamp far from zero so timelock arithmetic in warps never underflows
        vm.warp(365 days * 2);

        admin = address(this);
        manager = makeAddr("manager");
        newManager = makeAddr("newManager");
        newAdmin = makeAddr("newAdmin");
        outsider = makeAddr("outsider");
        usdc = makeAddr("usdc");
        weth = makeAddr("weth");

        registry = new AaveV4ReserveRegistryV2(admin);
        MANAGER_ROLE = registry.MARKET_MANAGER_ROLE();
        ADMIN_ROLE = registry.DEFAULT_ADMIN_ROLE();

        spoke = new MockLifecycleSpoke();
        spoke.setReserve(USDC_RESERVE_ID, usdc, 6);
        spoke.setReserve(WETH_RESERVE_ID, weth, 18);
        spoke.setReserve(ZERO_UNDERLYING_RESERVE_ID, address(0), 18);

        (usdcKey, usdcDebtKey) = registry.registerReserve(address(spoke), USDC_RESERVE_ID);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Expected OZ AccessControl rejection payload for `account` lacking `role`
    function _unauthorised(address account, bytes32 role) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, account, role);
    }

    /// @dev Drive one key through the full propose/execute timelock matrix. Shared by both legs so
    ///      the matrix is pinned identically for SUPPLY and DEBT (the contract is side-agnostic
    ///      here, and this proves it).
    function _assertTimelockMatrix(address key) internal {
        uint256 delay = registry.DEREGISTER_DELAY();

        assertEq(registry.pendingDeregistrations(key), 0, "no pending deregistration before proposing");

        registry.proposeDeregisterReserve(key);
        uint256 executeAfter = block.timestamp + delay;
        assertEq(registry.pendingDeregistrations(key), executeAfter, "propose must arm the full delay");
        assertTrue(registry.isRegistered(key), "a pending proposal must not deregister anything yet");

        // One second short of the deadline: rejected
        vm.warp(executeAfter - 1);
        vm.expectRevert(AaveV4ReserveRegistryV2.DEREGISTRATION_TIMELOCK_NOT_ELAPSED.selector);
        registry.executeDeregisterReserve(key);

        // Exactly at the deadline: accepted (the comparison is `<`, so == is ripe)
        vm.warp(executeAfter);
        registry.executeDeregisterReserve(key);

        assertFalse(registry.isRegistered(key), "execute must drop the reserve");
        assertEq(registry.pendingDeregistrations(key), 0, "execute must clear the pending entry");

        // Nothing pending any more: both lifecycle verbs reject
        vm.expectRevert(AaveV4ReserveRegistryV2.DEREGISTRATION_NOT_PENDING.selector);
        registry.executeDeregisterReserve(key);
        vm.expectRevert(AaveV4ReserveRegistryV2.DEREGISTRATION_NOT_PENDING.selector);
        registry.cancelDeregisterReserve(key);

        // ...and the key is no longer proposable
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        registry.proposeDeregisterReserve(key);
    }

    /// @dev Deregister a single leg through the full timelock, leaving the other untouched
    function _dropLeg(address key) internal {
        registry.proposeDeregisterReserve(key);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        registry.executeDeregisterReserve(key);
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Deployment grants BOTH DEFAULT_ADMIN_ROLE and MARKET_MANAGER_ROLE to the admin, and
    ///         nothing to anybody else
    function test_constructor_grantsBothRolesToAdmin() public view {
        assertTrue(registry.hasRole(ADMIN_ROLE, admin), "admin must hold DEFAULT_ADMIN_ROLE");
        assertTrue(registry.hasRole(MANAGER_ROLE, admin), "admin must hold MARKET_MANAGER_ROLE");
        assertFalse(registry.hasRole(ADMIN_ROLE, outsider), "outsider must not hold DEFAULT_ADMIN_ROLE");
        assertFalse(registry.hasRole(MANAGER_ROLE, outsider), "outsider must not hold MARKET_MANAGER_ROLE");
    }

    /// @notice A zero admin would deploy an unusable, permanently role-less registry — rejected
    function test_constructor_revertIf_zeroAdmin() public {
        vm.expectRevert(AaveV4ReserveRegistryV2.ZERO_ADDRESS.selector);
        new AaveV4ReserveRegistryV2(address(0));
    }

    /// @notice Constants are pinned by value, so a rename or re-seed of a domain/role string is a
    ///         visible, off-chain-breaking change rather than a silent one
    function test_constructor_pinsPublicConstants() public view {
        assertEq(MANAGER_ROLE, keccak256("MARKET_MANAGER_ROLE"), "MARKET_MANAGER_ROLE string pinned");
        assertEq(ADMIN_ROLE, bytes32(0), "DEFAULT_ADMIN_ROLE is OZ's zero role");
        assertEq(registry.DEREGISTER_DELAY(), 2 days, "deregistration delay pinned at 2 days");
        assertEq(registry.DEBT_KEY_DOMAIN(), keccak256("AaveV4ReserveRegistryV2.DEBT"), "debt domain string pinned");
    }

    /*//////////////////////////////////////////////////////////////
                             ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /// @notice registerReserve is MARKET_MANAGER_ROLE-gated with OZ's typed rejection
    function test_registerReserve_revertIf_unauthorised() public {
        vm.prank(outsider);
        vm.expectRevert(_unauthorised(outsider, MANAGER_ROLE));
        registry.registerReserve(address(spoke), WETH_RESERVE_ID);
    }

    /// @notice proposeDeregisterReserve is MARKET_MANAGER_ROLE-gated with OZ's typed rejection
    function test_proposeDeregisterReserve_revertIf_unauthorised() public {
        vm.prank(outsider);
        vm.expectRevert(_unauthorised(outsider, MANAGER_ROLE));
        registry.proposeDeregisterReserve(usdcKey);
    }

    /// @notice executeDeregisterReserve is MARKET_MANAGER_ROLE-gated — the role check runs BEFORE
    ///         the pending/timelock checks, so even a ripe proposal cannot be executed by anyone else
    function test_executeDeregisterReserve_revertIf_unauthorised() public {
        registry.proposeDeregisterReserve(usdcKey);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());

        vm.prank(outsider);
        vm.expectRevert(_unauthorised(outsider, MANAGER_ROLE));
        registry.executeDeregisterReserve(usdcKey);

        assertTrue(registry.isRegistered(usdcKey), "an unauthorised execute must change nothing");
    }

    /// @notice cancelDeregisterReserve is MARKET_MANAGER_ROLE-gated — an outsider can neither
    ///         complete nor abort a pending proposal
    function test_cancelDeregisterReserve_revertIf_unauthorised() public {
        registry.proposeDeregisterReserve(usdcKey);
        uint256 pending = registry.pendingDeregistrations(usdcKey);

        vm.prank(outsider);
        vm.expectRevert(_unauthorised(outsider, MANAGER_ROLE));
        registry.cancelDeregisterReserve(usdcKey);

        assertEq(registry.pendingDeregistrations(usdcKey), pending, "an unauthorised cancel must change nothing");
    }

    /// @notice The admin can grant MARKET_MANAGER_ROLE; a revoked manager immediately loses the
    ///         ability to register (no grace period, no cached authorisation)
    function test_accessControl_grantThenRevokeManager() public {
        registry.grantRole(MANAGER_ROLE, manager);
        assertTrue(registry.hasRole(MANAGER_ROLE, manager), "grant must take effect");

        vm.prank(manager);
        (address supplyKey, address debtKey) = registry.registerReserve(address(spoke), WETH_RESERVE_ID);
        assertTrue(registry.isRegistered(supplyKey), "granted manager can register the supply leg");
        assertTrue(registry.isRegistered(debtKey), "granted manager can register the debt leg");

        registry.revokeRole(MANAGER_ROLE, manager);
        assertFalse(registry.hasRole(MANAGER_ROLE, manager), "revoke must take effect");

        spoke.setReserve(42, makeAddr("token42"), 8);
        vm.prank(manager);
        vm.expectRevert(_unauthorised(manager, MANAGER_ROLE));
        registry.registerReserve(address(spoke), 42);
    }

    /// @notice The production handoff shape: grant MARKET_MANAGER_ROLE to the governor and
    ///         DEFAULT_ADMIN_ROLE to the SuperGovernor, then revoke both from the deployer — after
    ///         which the deployer can neither register nor re-grant
    function test_accessControl_productionRoleHandoff() public {
        registry.grantRole(MANAGER_ROLE, newManager);
        registry.grantRole(ADMIN_ROLE, newAdmin);
        registry.revokeRole(MANAGER_ROLE, admin);
        registry.revokeRole(ADMIN_ROLE, admin);

        assertTrue(registry.hasRole(MANAGER_ROLE, newManager), "new manager holds MARKET_MANAGER_ROLE");
        assertTrue(registry.hasRole(ADMIN_ROLE, newAdmin), "new admin holds DEFAULT_ADMIN_ROLE");
        assertFalse(registry.hasRole(MANAGER_ROLE, admin), "deployer manager role revoked");
        assertFalse(registry.hasRole(ADMIN_ROLE, admin), "deployer admin role revoked");

        // The deployer is fully de-privileged
        vm.expectRevert(_unauthorised(admin, MANAGER_ROLE));
        registry.registerReserve(address(spoke), WETH_RESERVE_ID);
        vm.expectRevert(_unauthorised(admin, ADMIN_ROLE));
        registry.grantRole(MANAGER_ROLE, admin);

        // ...and the new manager is fully operational
        vm.prank(newManager);
        (address supplyKey,) = registry.registerReserve(address(spoke), WETH_RESERVE_ID);
        assertTrue(registry.isRegistered(supplyKey), "handed-off manager must be able to register");
    }

    /// @notice MARKET_MANAGER_ROLE does not confer admin: a manager cannot widen the manager set
    function test_accessControl_managerCannotGrantRoles() public {
        registry.grantRole(MANAGER_ROLE, manager);

        vm.prank(manager);
        vm.expectRevert(_unauthorised(manager, ADMIN_ROLE));
        registry.grantRole(MANAGER_ROLE, outsider);
    }

    /*//////////////////////////////////////////////////////////////
                      REGISTRATION: KEY DERIVATION
    //////////////////////////////////////////////////////////////*/

    /// @notice The returned keys equal the pure derivations — the registry never invents a key
    function test_registerReserve_returnsPureDerivations() public view {
        assertEq(usdcKey, registry.computeReserveKey(address(spoke), USDC_RESERVE_ID), "supply key is the pure value");
        assertEq(usdcDebtKey, registry.computeDebtKey(address(spoke), USDC_RESERVE_ID), "debt key is the pure value");
    }

    /// @notice The SUPPLY key keeps the legacy two-word preimage and the DEBT key uses the
    ///         three-word domain-separated preimage — the exact formulas off-chain consumers derive
    function test_computeKeys_matchLiteralFormulas() public view {
        assertEq(
            registry.computeReserveKey(address(spoke), USDC_RESERVE_ID),
            address(uint160(uint256(keccak256(abi.encode(address(spoke), USDC_RESERVE_ID))))),
            "supply key: keccak(spoke, reserveId)"
        );
        assertEq(
            registry.computeDebtKey(address(spoke), USDC_RESERVE_ID),
            address(
                uint160(
                    uint256(
                        keccak256(abi.encode(address(spoke), USDC_RESERVE_ID, keccak256("AaveV4ReserveRegistryV2.DEBT")))
                    )
                )
            ),
            "debt key: keccak(spoke, reserveId, DEBT_KEY_DOMAIN)"
        );
    }

    /// @notice The SUPPLY derivation is the shared library's, so hooks and registry can never drift
    function test_computeReserveKey_matchesSharedLibrary() public view {
        assertEq(
            registry.computeReserveKey(address(spoke), USDC_RESERVE_ID),
            AaveV4ReserveKey.computeReserveKey(address(spoke), USDC_RESERVE_ID),
            "registry must delegate the supply derivation to AaveV4ReserveKey"
        );
    }

    /// @notice The two legs of one reserve are keyed apart, and distinct reserves are keyed apart
    function test_computeKeys_legsAndReservesAreDistinct() public view {
        address wethKey = registry.computeReserveKey(address(spoke), WETH_RESERVE_ID);
        address wethDebtKey = registry.computeDebtKey(address(spoke), WETH_RESERVE_ID);

        assertTrue(usdcKey != usdcDebtKey, "a reserve's supply and debt keys must differ");
        assertTrue(wethKey != wethDebtKey, "a reserve's supply and debt keys must differ");
        assertTrue(usdcKey != wethKey, "distinct reserves must have distinct supply keys");
        assertTrue(usdcDebtKey != wethDebtKey, "distinct reserves must have distinct debt keys");
        assertTrue(usdcKey != wethDebtKey, "cross-leg, cross-reserve keys must differ");
    }

    /// @notice Both key derivations are PURE: they answer for never-registered inputs and so can
    ///         never be used to probe registration state (that is `isRegistered`'s job alone)
    function test_computeKeys_workForUnregisteredInputs_andDoNotProbeRegistration() public {
        address ghostSpoke = makeAddr("ghostSpoke");
        address ghostSupply = registry.computeReserveKey(ghostSpoke, 123);
        address ghostDebt = registry.computeDebtKey(ghostSpoke, 123);

        assertTrue(ghostSupply != address(0), "pure derivation answers for unregistered pairs");
        assertTrue(ghostDebt != address(0), "pure derivation answers for unregistered pairs");
        assertFalse(registry.isRegistered(ghostSupply), "computing a key must not register it");
        assertFalse(registry.isRegistered(ghostDebt), "computing a key must not register it");

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        registry.getReserveInfo(ghostSupply);
    }

    /*//////////////////////////////////////////////////////////////
                      REGISTRATION: HAPPY PATH
    //////////////////////////////////////////////////////////////*/

    /// @notice One call writes BOTH legs with the same (spoke, reserveId, underlying, decimals)
    ///         binding, differing only in `side` — a half-registered reserve is unrepresentable
    function test_registerReserve_writesBothLegs_sharedBinding() public view {
        (address sSpoke, uint256 sId, address sUnderlying, uint8 sDecimals, AaveV4ReserveRegistryV2.Side sSide) =
            registry.getReserveInfo(usdcKey);
        (address dSpoke, uint256 dId, address dUnderlying, uint8 dDecimals, AaveV4ReserveRegistryV2.Side dSide) =
            registry.getReserveInfo(usdcDebtKey);

        assertEq(sSpoke, address(spoke), "supply leg binds the spoke");
        assertEq(sId, USDC_RESERVE_ID, "supply leg binds the reserveId");
        assertEq(sUnderlying, usdc, "supply leg binds the underlying");
        assertEq(sDecimals, 6, "supply leg binds the decimals");
        assertEq(uint8(sSide), uint8(AaveV4ReserveRegistryV2.Side.SUPPLY), "legacy key is the SUPPLY leg");

        assertEq(dSpoke, sSpoke, "both legs share the spoke");
        assertEq(dId, sId, "both legs share the reserveId");
        assertEq(dUnderlying, sUnderlying, "both legs share the underlying");
        assertEq(dDecimals, sDecimals, "both legs share the decimals");
        assertEq(uint8(dSide), uint8(AaveV4ReserveRegistryV2.Side.DEBT), "domain-separated key is the DEBT leg");

        assertTrue(registry.isRegistered(usdcKey), "supply leg registered");
        assertTrue(registry.isRegistered(usdcDebtKey), "debt leg registered");
        assertEq(registry.pendingDeregistrations(usdcKey), 0, "registration arms no deregistration");
        assertEq(registry.pendingDeregistrations(usdcDebtKey), 0, "registration arms no deregistration");
    }

    /// @notice Registering a second reserve leaves the first untouched; four live keys coexist
    function test_registerReserve_secondReserve_isIndependent() public {
        (address wethKey, address wethDebtKey) = registry.registerReserve(address(spoke), WETH_RESERVE_ID);

        (,, address wUnderlying, uint8 wDecimals,) = registry.getReserveInfo(wethKey);
        assertEq(wUnderlying, weth, "second reserve binds its own underlying");
        assertEq(wDecimals, 18, "second reserve binds its own decimals");

        (,, address uUnderlying, uint8 uDecimals,) = registry.getReserveInfo(usdcKey);
        assertEq(uUnderlying, usdc, "first reserve's underlying is untouched");
        assertEq(uDecimals, 6, "first reserve's decimals are untouched");

        assertTrue(registry.isRegistered(wethDebtKey), "second reserve's debt leg registered");
        assertTrue(registry.isRegistered(usdcDebtKey), "first reserve's debt leg untouched");
    }

    /// @notice Registration emits ReserveRegistered TWICE — SUPPLY first, then DEBT — with the
    ///         shared payload and the per-leg `Side` discriminator
    function test_registerReserve_emitsBothLegsInOrder() public {
        address key = registry.computeReserveKey(address(spoke), WETH_RESERVE_ID);
        address debtKey = registry.computeDebtKey(address(spoke), WETH_RESERVE_ID);

        vm.expectEmit(true, true, true, true);
        emit AaveV4ReserveRegistryV2.ReserveRegistered(
            key, address(spoke), WETH_RESERVE_ID, weth, AaveV4ReserveRegistryV2.Side.SUPPLY
        );
        vm.expectEmit(true, true, true, true);
        emit AaveV4ReserveRegistryV2.ReserveRegistered(
            debtKey, address(spoke), WETH_RESERVE_ID, weth, AaveV4ReserveRegistryV2.Side.DEBT
        );
        registry.registerReserve(address(spoke), WETH_RESERVE_ID);
    }

    /// @notice Exactly two ReserveRegistered logs are emitted per registration — no silent third
    ///         leg, no duplicate — and their non-indexed `Side` words are 0 then 1
    function test_registerReserve_emitsExactlyTwoLogs() public {
        vm.recordLogs();
        registry.registerReserve(address(spoke), WETH_RESERVE_ID);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 2, "registration emits exactly two logs");

        bytes32 topic0 = keccak256("ReserveRegistered(address,address,uint256,address,uint8)");
        assertEq(logs[0].topics[0], topic0, "first log is ReserveRegistered");
        assertEq(logs[1].topics[0], topic0, "second log is ReserveRegistered");

        (address underlying0, uint8 side0) = abi.decode(logs[0].data, (address, uint8));
        (address underlying1, uint8 side1) = abi.decode(logs[1].data, (address, uint8));
        assertEq(underlying0, weth, "both logs carry the shared underlying");
        assertEq(underlying1, weth, "both logs carry the shared underlying");
        assertEq(side0, uint8(AaveV4ReserveRegistryV2.Side.SUPPLY), "SUPPLY is emitted first");
        assertEq(side1, uint8(AaveV4ReserveRegistryV2.Side.DEBT), "DEBT is emitted second");
    }

    /*//////////////////////////////////////////////////////////////
                      REGISTRATION: REJECTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice A zero spoke is rejected before any external call is attempted
    function test_registerReserve_revertIf_zeroSpoke() public {
        vm.expectRevert(AaveV4ReserveRegistryV2.ZERO_ADDRESS.selector);
        registry.registerReserve(address(0), USDC_RESERVE_ID);
    }

    /// @notice A codeless (EOA) spoke must revert at registration rather than decode garbage into
    ///         a binding — validation is genuinely on-chain
    function test_registerReserve_revertIf_codelessSpoke() public {
        address eoaSpoke = makeAddr("eoaSpoke");
        assertEq(eoaSpoke.code.length, 0, "the test premise is a codeless spoke");

        vm.expectRevert();
        registry.registerReserve(eoaSpoke, USDC_RESERVE_ID);
    }

    /// @notice An unlisted reserve id surfaces the spoke's own revert to the caller
    function test_registerReserve_revertIf_unlistedReserve() public {
        vm.expectRevert(MockLifecycleSpoke.ReserveNotListed.selector);
        registry.registerReserve(address(spoke), UNLISTED_RESERVE_ID);
    }

    /// @notice A reserve whose spoke reports a zero underlying is rejected as INVALID_RESERVE —
    ///         a zero-underlying binding would make every oracle read meaningless
    function test_registerReserve_revertIf_zeroUnderlying() public {
        vm.expectRevert(AaveV4ReserveRegistryV2.INVALID_RESERVE.selector);
        registry.registerReserve(address(spoke), ZERO_UNDERLYING_RESERVE_ID);
    }

    /// @notice A fully registered reserve cannot be registered again (both legs present)
    function test_registerReserve_revertIf_duplicate_bothLegsPresent() public {
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_ALREADY_REGISTERED.selector);
        registry.registerReserve(address(spoke), USDC_RESERVE_ID);
    }

    /// @notice The duplicate guard fires when ONLY THE SUPPLY leg survives — the debt leg was
    ///         deregistered, yet re-registration is still refused rather than silently rebinding
    function test_registerReserve_revertIf_onlySupplyLegPresent() public {
        _dropLeg(usdcDebtKey);
        assertTrue(registry.isRegistered(usdcKey), "supply leg still present");
        assertFalse(registry.isRegistered(usdcDebtKey), "debt leg dropped");

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_ALREADY_REGISTERED.selector);
        registry.registerReserve(address(spoke), USDC_RESERVE_ID);
    }

    /// @notice The duplicate guard fires when ONLY THE DEBT leg survives — the second half of the
    ///         `||` guard, which a both-legs-present test alone never reaches
    function test_registerReserve_revertIf_onlyDebtLegPresent() public {
        _dropLeg(usdcKey);
        assertFalse(registry.isRegistered(usdcKey), "supply leg dropped");
        assertTrue(registry.isRegistered(usdcDebtKey), "debt leg still present");

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_ALREADY_REGISTERED.selector);
        registry.registerReserve(address(spoke), USDC_RESERVE_ID);
    }

    /*//////////////////////////////////////////////////////////////
                             ATOMICITY
    //////////////////////////////////////////////////////////////*/

    /// @notice A registration that reverts on INVALID_RESERVE writes NOTHING — neither leg of the
    ///         rejected reserve exists afterwards
    function test_registerReserve_atomicity_zeroUnderlying_writesNothing() public {
        address key = registry.computeReserveKey(address(spoke), ZERO_UNDERLYING_RESERVE_ID);
        address debtKey = registry.computeDebtKey(address(spoke), ZERO_UNDERLYING_RESERVE_ID);

        vm.expectRevert(AaveV4ReserveRegistryV2.INVALID_RESERVE.selector);
        registry.registerReserve(address(spoke), ZERO_UNDERLYING_RESERVE_ID);

        assertFalse(registry.isRegistered(key), "no supply leg after a failed registration");
        assertFalse(registry.isRegistered(debtKey), "no debt leg after a failed registration");
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        registry.getReserveInfo(key);
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        registry.getReserveInfo(debtKey);
    }

    /// @notice A registration that reverts inside the spoke call writes NOTHING either
    function test_registerReserve_atomicity_unlistedReserve_writesNothing() public {
        address key = registry.computeReserveKey(address(spoke), UNLISTED_RESERVE_ID);
        address debtKey = registry.computeDebtKey(address(spoke), UNLISTED_RESERVE_ID);

        vm.expectRevert(MockLifecycleSpoke.ReserveNotListed.selector);
        registry.registerReserve(address(spoke), UNLISTED_RESERVE_ID);

        assertFalse(registry.isRegistered(key), "no supply leg after a failed registration");
        assertFalse(registry.isRegistered(debtKey), "no debt leg after a failed registration");
    }

    /// @notice A duplicate-rejected registration cannot corrupt the live binding it collided with
    function test_registerReserve_atomicity_duplicate_leavesBindingIntact() public {
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_ALREADY_REGISTERED.selector);
        registry.registerReserve(address(spoke), USDC_RESERVE_ID);

        (address sSpoke, uint256 sId, address sUnderlying, uint8 sDecimals, AaveV4ReserveRegistryV2.Side sSide) =
            registry.getReserveInfo(usdcKey);
        assertEq(sSpoke, address(spoke), "spoke unchanged");
        assertEq(sId, USDC_RESERVE_ID, "reserveId unchanged");
        assertEq(sUnderlying, usdc, "underlying unchanged");
        assertEq(sDecimals, 6, "decimals unchanged");
        assertEq(uint8(sSide), uint8(AaveV4ReserveRegistryV2.Side.SUPPLY), "side unchanged");
    }

    /*//////////////////////////////////////////////////////////////
                      TIMELOCK MATRIX (PER LEG)
    //////////////////////////////////////////////////////////////*/

    /// @notice The full propose/boundary/execute matrix holds for the SUPPLY leg
    function test_timelockMatrix_supplyLeg() public {
        _assertTimelockMatrix(usdcKey);
    }

    /// @notice The full propose/boundary/execute matrix holds identically for the DEBT leg — the
    ///         lifecycle is key-addressed and side-agnostic
    function test_timelockMatrix_debtLeg() public {
        _assertTimelockMatrix(usdcDebtKey);
    }

    /// @notice Executing well after the deadline still works (proposals never expire) and removes
    ///         both the pending entry and the reserve binding
    function test_executeDeregisterReserve_afterDeadline_deletesPendingAndReserve() public {
        registry.proposeDeregisterReserve(usdcKey);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY() + 30 days);

        registry.executeDeregisterReserve(usdcKey);

        assertEq(registry.pendingDeregistrations(usdcKey), 0, "pending entry deleted");
        assertFalse(registry.isRegistered(usdcKey), "reserve binding deleted");
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        registry.getReserveInfo(usdcKey);
    }

    /// @notice Cancelling clears the pending entry and leaves the reserve fully registered and
    ///         readable — a cancel is a no-op on the binding
    function test_cancelDeregisterReserve_clearsPending_keepsReserve() public {
        registry.proposeDeregisterReserve(usdcKey);
        registry.cancelDeregisterReserve(usdcKey);

        assertEq(registry.pendingDeregistrations(usdcKey), 0, "cancel clears the pending entry");
        assertTrue(registry.isRegistered(usdcKey), "cancel leaves the reserve registered");
        (,, address underlying,, AaveV4ReserveRegistryV2.Side side) = registry.getReserveInfo(usdcKey);
        assertEq(underlying, usdc, "binding survives a cancel");
        assertEq(uint8(side), uint8(AaveV4ReserveRegistryV2.Side.SUPPLY), "side survives a cancel");

        // The previously armed deadline is dead, not merely postponed
        vm.warp(block.timestamp + 10 days);
        vm.expectRevert(AaveV4ReserveRegistryV2.DEREGISTRATION_NOT_PENDING.selector);
        registry.executeDeregisterReserve(usdcKey);
    }

    /// @notice A cancelled proposal can be re-proposed and then executed — cancel does not brick
    ///         the key's lifecycle
    function test_cancelDeregisterReserve_thenReproposeAndExecute() public {
        registry.proposeDeregisterReserve(usdcKey);
        registry.cancelDeregisterReserve(usdcKey);

        registry.proposeDeregisterReserve(usdcKey);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        registry.executeDeregisterReserve(usdcKey);
        assertFalse(registry.isRegistered(usdcKey), "re-proposed deregistration completes");
    }

    /// @notice Execute and cancel both reject when nothing is pending, on a registered key
    function test_executeAndCancel_revertIf_nothingPending() public {
        vm.expectRevert(AaveV4ReserveRegistryV2.DEREGISTRATION_NOT_PENDING.selector);
        registry.executeDeregisterReserve(usdcKey);
        vm.expectRevert(AaveV4ReserveRegistryV2.DEREGISTRATION_NOT_PENDING.selector);
        registry.cancelDeregisterReserve(usdcKey);
    }

    /// @notice Execute and cancel reject on a never-registered key with the pending error — the
    ///         pending check precedes any registration lookup
    function test_executeAndCancel_revertIf_unknownKey() public {
        address unknown = makeAddr("unknownKey");
        vm.expectRevert(AaveV4ReserveRegistryV2.DEREGISTRATION_NOT_PENDING.selector);
        registry.executeDeregisterReserve(unknown);
        vm.expectRevert(AaveV4ReserveRegistryV2.DEREGISTRATION_NOT_PENDING.selector);
        registry.cancelDeregisterReserve(unknown);
    }

    /// @notice Proposing on an unregistered key is refused — the timelock can never be armed for
    ///         something that does not exist
    function test_proposeDeregisterReserve_revertIf_unregisteredKey() public {
        address unknown = makeAddr("unknownKey");
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        registry.proposeDeregisterReserve(unknown);
        assertEq(registry.pendingDeregistrations(unknown), 0, "a refused propose arms nothing");
    }

    /// @notice Re-proposing EXTENDS the timelock and can never shorten it: the new deadline is
    ///         strictly later, and the old deadline stops being sufficient
    function test_proposeDeregisterReserve_reproposeExtendsNeverShortens() public {
        registry.proposeDeregisterReserve(usdcKey);
        uint256 firstDeadline = registry.pendingDeregistrations(usdcKey);

        vm.warp(block.timestamp + 1 days);
        registry.proposeDeregisterReserve(usdcKey);
        uint256 secondDeadline = registry.pendingDeregistrations(usdcKey);

        assertEq(secondDeadline, firstDeadline + 1 days, "re-propose restarts the full delay");
        assertGt(secondDeadline, firstDeadline, "re-propose can only move the deadline later");

        vm.warp(firstDeadline);
        vm.expectRevert(AaveV4ReserveRegistryV2.DEREGISTRATION_TIMELOCK_NOT_ELAPSED.selector);
        registry.executeDeregisterReserve(usdcKey);

        vm.warp(secondDeadline);
        registry.executeDeregisterReserve(usdcKey);
        assertFalse(registry.isRegistered(usdcKey), "the extended deadline is the operative one");
    }

    /// @notice A pending proposal does not degrade reads: the binding stays fully resolvable for
    ///         the whole warning window
    function test_pendingDeregistration_doesNotAffectReads() public {
        registry.proposeDeregisterReserve(usdcKey);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY() + 1);

        assertTrue(registry.isRegistered(usdcKey), "still registered until execute");
        (address sSpoke,, address underlying, uint8 decimals_,) = registry.getReserveInfo(usdcKey);
        assertEq(sSpoke, address(spoke), "spoke readable while pending");
        assertEq(underlying, usdc, "underlying readable while pending");
        assertEq(decimals_, 6, "decimals readable while pending");
    }

    /*//////////////////////////////////////////////////////////////
                      SUPPLY / DEBT ASYMMETRY
    //////////////////////////////////////////////////////////////*/

    /// @notice Deregistration is PER KEY while registration is PER RESERVE: dropping the SUPPLY
    ///         leg leaves the DEBT leg registered, readable and unchanged
    function test_asymmetry_dropSupplyLeg_debtLegSurvivesReadable() public {
        _dropLeg(usdcKey);

        assertFalse(registry.isRegistered(usdcKey), "supply leg dropped");
        assertTrue(registry.isRegistered(usdcDebtKey), "debt leg survives independently");

        (address dSpoke, uint256 dId, address dUnderlying, uint8 dDecimals, AaveV4ReserveRegistryV2.Side dSide) =
            registry.getReserveInfo(usdcDebtKey);
        assertEq(dSpoke, address(spoke), "surviving debt leg keeps its spoke");
        assertEq(dId, USDC_RESERVE_ID, "surviving debt leg keeps its reserveId");
        assertEq(dUnderlying, usdc, "surviving debt leg keeps its underlying");
        assertEq(dDecimals, 6, "surviving debt leg keeps its decimals");
        assertEq(uint8(dSide), uint8(AaveV4ReserveRegistryV2.Side.DEBT), "surviving debt leg keeps its side");

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        registry.getReserveInfo(usdcKey);
    }

    /// @notice The mirror case: dropping the DEBT leg leaves the SUPPLY leg registered, readable
    ///         and unchanged — this is how a borrow leg is retired without disturbing NAV reads
    function test_asymmetry_dropDebtLeg_supplyLegSurvivesReadable() public {
        _dropLeg(usdcDebtKey);

        assertFalse(registry.isRegistered(usdcDebtKey), "debt leg dropped");
        assertTrue(registry.isRegistered(usdcKey), "supply leg survives independently");

        (address sSpoke, uint256 sId, address sUnderlying, uint8 sDecimals, AaveV4ReserveRegistryV2.Side sSide) =
            registry.getReserveInfo(usdcKey);
        assertEq(sSpoke, address(spoke), "surviving supply leg keeps its spoke");
        assertEq(sId, USDC_RESERVE_ID, "surviving supply leg keeps its reserveId");
        assertEq(sUnderlying, usdc, "surviving supply leg keeps its underlying");
        assertEq(sDecimals, 6, "surviving supply leg keeps its decimals");
        assertEq(uint8(sSide), uint8(AaveV4ReserveRegistryV2.Side.SUPPLY), "surviving supply leg keeps its side");

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        registry.getReserveInfo(usdcDebtKey);
    }

    /// @notice Dropping BOTH legs is the only state that re-opens registration, and the restored
    ///         keys are IDENTICAL — a derived key can never be rebound to a different reserve
    function test_asymmetry_dropBothLegs_reregistrationRestoresIdenticalKeys() public {
        _dropLeg(usdcKey);
        _dropLeg(usdcDebtKey);
        assertFalse(registry.isRegistered(usdcKey), "supply leg dropped");
        assertFalse(registry.isRegistered(usdcDebtKey), "debt leg dropped");

        (address restoredSupply, address restoredDebt) = registry.registerReserve(address(spoke), USDC_RESERVE_ID);
        assertEq(restoredSupply, usdcKey, "re-registration restores the identical supply key");
        assertEq(restoredDebt, usdcDebtKey, "re-registration restores the identical debt key");

        (,, address underlying, uint8 decimals_, AaveV4ReserveRegistryV2.Side side) = registry.getReserveInfo(usdcKey);
        assertEq(underlying, usdc, "re-registration rebinds the same underlying");
        assertEq(decimals_, 6, "re-registration rebinds the same decimals");
        assertEq(uint8(side), uint8(AaveV4ReserveRegistryV2.Side.SUPPLY), "re-registration restores the SUPPLY side");
        (,,,, AaveV4ReserveRegistryV2.Side debtSide) = registry.getReserveInfo(usdcDebtKey);
        assertEq(uint8(debtSide), uint8(AaveV4ReserveRegistryV2.Side.DEBT), "re-registration restores the DEBT side");
    }

    /// @notice No zombie pending survives re-registration: execute is the only route to the
    ///         unregistered state and it deletes the pending entry on the way
    function test_asymmetry_reregisteredKeys_haveNoZombiePending() public {
        _dropLeg(usdcKey);
        _dropLeg(usdcDebtKey);
        registry.registerReserve(address(spoke), USDC_RESERVE_ID);

        assertEq(registry.pendingDeregistrations(usdcKey), 0, "no pending survives supply re-registration");
        assertEq(registry.pendingDeregistrations(usdcDebtKey), 0, "no pending survives debt re-registration");
        vm.expectRevert(AaveV4ReserveRegistryV2.DEREGISTRATION_NOT_PENDING.selector);
        registry.executeDeregisterReserve(usdcKey);
        vm.expectRevert(AaveV4ReserveRegistryV2.DEREGISTRATION_NOT_PENDING.selector);
        registry.executeDeregisterReserve(usdcDebtKey);
    }

    /*//////////////////////////////////////////////////////////////
                PER-LEG INDEPENDENCE OF PENDING STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice A pending deregistration on the SUPPLY key arms nothing on the DEBT key
    function test_pendingIndependence_supplyDoesNotArmDebt() public {
        registry.proposeDeregisterReserve(usdcKey);

        assertEq(
            registry.pendingDeregistrations(usdcKey), block.timestamp + registry.DEREGISTER_DELAY(), "supply leg armed"
        );
        assertEq(registry.pendingDeregistrations(usdcDebtKey), 0, "debt leg must stay un-armed");

        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        vm.expectRevert(AaveV4ReserveRegistryV2.DEREGISTRATION_NOT_PENDING.selector);
        registry.executeDeregisterReserve(usdcDebtKey);
    }

    /// @notice The mirror: a pending deregistration on the DEBT key arms nothing on the SUPPLY key
    function test_pendingIndependence_debtDoesNotArmSupply() public {
        registry.proposeDeregisterReserve(usdcDebtKey);

        assertEq(
            registry.pendingDeregistrations(usdcDebtKey),
            block.timestamp + registry.DEREGISTER_DELAY(),
            "debt leg armed"
        );
        assertEq(registry.pendingDeregistrations(usdcKey), 0, "supply leg must stay un-armed");

        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        vm.expectRevert(AaveV4ReserveRegistryV2.DEREGISTRATION_NOT_PENDING.selector);
        registry.executeDeregisterReserve(usdcKey);
    }

    /// @notice With both legs armed, executing one leaves the other's pending entry intact, and
    ///         cancelling one leaves the other's intact — the mapping is strictly per key
    function test_pendingIndependence_executeAndCancelArePerKey() public {
        registry.proposeDeregisterReserve(usdcKey);
        registry.proposeDeregisterReserve(usdcDebtKey);
        uint256 deadline = block.timestamp + registry.DEREGISTER_DELAY();

        vm.warp(deadline);
        registry.executeDeregisterReserve(usdcKey);
        assertEq(registry.pendingDeregistrations(usdcKey), 0, "executed leg's pending cleared");
        assertEq(registry.pendingDeregistrations(usdcDebtKey), deadline, "other leg's pending intact");
        assertTrue(registry.isRegistered(usdcDebtKey), "other leg still registered");

        registry.cancelDeregisterReserve(usdcDebtKey);
        assertEq(registry.pendingDeregistrations(usdcDebtKey), 0, "cancel clears only the named leg");
        assertTrue(registry.isRegistered(usdcDebtKey), "cancel keeps the other leg registered");
    }

    /// @notice Pending state is also independent ACROSS reserves, not just across legs
    function test_pendingIndependence_acrossReserves() public {
        (address wethKey, address wethDebtKey) = registry.registerReserve(address(spoke), WETH_RESERVE_ID);
        registry.proposeDeregisterReserve(wethKey);

        assertEq(registry.pendingDeregistrations(usdcKey), 0, "unrelated reserve's supply leg un-armed");
        assertEq(registry.pendingDeregistrations(usdcDebtKey), 0, "unrelated reserve's debt leg un-armed");
        assertEq(registry.pendingDeregistrations(wethDebtKey), 0, "same reserve's other leg un-armed");

        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        registry.executeDeregisterReserve(wethKey);
        assertTrue(registry.isRegistered(usdcKey), "unrelated reserve untouched");
        assertTrue(registry.isRegistered(wethDebtKey), "same reserve's other leg untouched");
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice getReserveInfo reverts with the typed error for a never-registered key
    function test_getReserveInfo_revertIf_unknownKey() public {
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        registry.getReserveInfo(makeAddr("unknownKey"));
    }

    /// @notice getReserveInfo reverts for a DEREGISTERED key — `registered` is the sole gate, so a
    ///         stale key can never read back a half-deleted binding
    function test_getReserveInfo_revertIf_deregisteredKey() public {
        _dropLeg(usdcKey);
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        registry.getReserveInfo(usdcKey);
    }

    /// @notice getReserveInfo reverts for the zero key, which no derivation realistically produces
    function test_getReserveInfo_revertIf_zeroKey() public {
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        registry.getReserveInfo(address(0));
    }

    /// @notice isRegistered is false for unknown keys and never reverts
    function test_isRegistered_falseForUnknownKeys() public {
        assertFalse(registry.isRegistered(makeAddr("unknownKey")), "unknown key is not registered");
        assertFalse(registry.isRegistered(address(0)), "zero key is not registered");
        assertFalse(registry.isRegistered(address(registry)), "the registry itself is not a reserve key");
    }

    /// @notice pendingDeregistrations defaults to zero for unknown keys
    function test_pendingDeregistrations_zeroForUnknownKeys() public {
        assertEq(registry.pendingDeregistrations(makeAddr("unknownKey")), 0, "unknown key has no pending entry");
        assertEq(registry.pendingDeregistrations(address(0)), 0, "zero key has no pending entry");
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice ReserveDeregistrationProposed carries the indexed key and the armed deadline
    function test_events_proposeDeregistration() public {
        vm.expectEmit(true, false, false, true);
        emit AaveV4ReserveRegistryV2.ReserveDeregistrationProposed(usdcKey, block.timestamp + registry.DEREGISTER_DELAY());
        registry.proposeDeregisterReserve(usdcKey);
    }

    /// @notice A re-propose emits the NEW deadline, so monitoring sees the extension
    function test_events_reproposeEmitsExtendedDeadline() public {
        registry.proposeDeregisterReserve(usdcKey);
        vm.warp(block.timestamp + 1 days);

        vm.expectEmit(true, false, false, true);
        emit AaveV4ReserveRegistryV2.ReserveDeregistrationProposed(usdcKey, block.timestamp + registry.DEREGISTER_DELAY());
        registry.proposeDeregisterReserve(usdcKey);
    }

    /// @notice ReserveDeregistrationCancelled carries the indexed key
    function test_events_cancelDeregistration() public {
        registry.proposeDeregisterReserve(usdcKey);

        vm.expectEmit(true, false, false, true);
        emit AaveV4ReserveRegistryV2.ReserveDeregistrationCancelled(usdcKey);
        registry.cancelDeregisterReserve(usdcKey);
    }

    /// @notice ReserveDeregistered carries the indexed key, and fires per leg
    function test_events_deregisteredPerLeg() public {
        registry.proposeDeregisterReserve(usdcKey);
        registry.proposeDeregisterReserve(usdcDebtKey);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());

        vm.expectEmit(true, false, false, true);
        emit AaveV4ReserveRegistryV2.ReserveDeregistered(usdcKey);
        registry.executeDeregisterReserve(usdcKey);

        vm.expectEmit(true, false, false, true);
        emit AaveV4ReserveRegistryV2.ReserveDeregistered(usdcDebtKey);
        registry.executeDeregisterReserve(usdcDebtKey);
    }

    /*//////////////////////////////////////////////////////////////
                                 FUZZ
    //////////////////////////////////////////////////////////////*/

    /// @notice Fuzzed SUPPLY derivation against an independent inline recomputation of the
    ///         documented two-word formula
    function testFuzz_computeReserveKey_matchesLiteralFormula(address spoke_, uint256 reserveId_) public view {
        assertEq(
            registry.computeReserveKey(spoke_, reserveId_),
            address(uint160(uint256(keccak256(abi.encode(spoke_, reserveId_))))),
            "supply key must equal the documented two-word derivation"
        );
    }

    /// @notice Fuzzed DEBT derivation against an independent inline recomputation of the
    ///         documented three-word domain-separated formula
    function testFuzz_computeDebtKey_matchesLiteralFormula(address spoke_, uint256 reserveId_) public view {
        assertEq(
            registry.computeDebtKey(spoke_, reserveId_),
            address(
                uint160(uint256(keccak256(abi.encode(spoke_, reserveId_, keccak256("AaveV4ReserveRegistryV2.DEBT")))))
            ),
            "debt key must equal the documented three-word derivation"
        );
    }

    /// @notice The two preimages differ in length, so no (spoke, reserveId) pair ever maps its
    ///         SUPPLY and DEBT legs onto the same key
    function testFuzz_computeKeys_legsNeverCollide(address spoke_, uint256 reserveId_) public view {
        assertTrue(
            registry.computeReserveKey(spoke_, reserveId_) != registry.computeDebtKey(spoke_, reserveId_),
            "a pair's supply and debt keys must never collide"
        );
    }

    /// @notice Both derivations are pure functions of their inputs — repeated calls agree, and
    ///         registering a pair never changes what the derivations return for it
    function testFuzz_computeKeys_arePureAndRegistrationIndependent(uint256 reserveId_) public {
        vm.assume(reserveId_ != USDC_RESERVE_ID);
        vm.assume(reserveId_ != ZERO_UNDERLYING_RESERVE_ID);

        address supplyBefore = registry.computeReserveKey(address(spoke), reserveId_);
        address debtBefore = registry.computeDebtKey(address(spoke), reserveId_);

        spoke.setReserve(reserveId_, usdc, 6);
        registry.registerReserve(address(spoke), reserveId_);

        assertEq(registry.computeReserveKey(address(spoke), reserveId_), supplyBefore, "supply derivation is pure");
        assertEq(registry.computeDebtKey(address(spoke), reserveId_), debtBefore, "debt derivation is pure");
    }

    /// @notice Fuzzed registration round trip: for an arbitrary (spoke, reserveId) the call returns
    ///         the pure keys and binds both legs with the spoke-reported underlying
    /// @dev The spoke dimension is fuzzed indirectly — a fresh mock spoke is deployed per run, so
    ///      each run exercises a different spoke address; the pure-derivation fuzz tests above cover
    ///      the spoke input exhaustively over the whole address space.
    function testFuzz_registerReserve_roundTrip(uint256 reserveId_, address underlying_) public {
        vm.assume(underlying_ != address(0));

        MockLifecycleSpoke freshSpoke = new MockLifecycleSpoke();
        freshSpoke.setReserve(reserveId_, underlying_, 18);

        (address supplyKey, address debtKey) = registry.registerReserve(address(freshSpoke), reserveId_);

        assertEq(supplyKey, registry.computeReserveKey(address(freshSpoke), reserveId_), "returned supply key");
        assertEq(debtKey, registry.computeDebtKey(address(freshSpoke), reserveId_), "returned debt key");

        (address sSpoke, uint256 sId, address sUnderlying,, AaveV4ReserveRegistryV2.Side sSide) =
            registry.getReserveInfo(supplyKey);
        assertEq(sSpoke, address(freshSpoke), "supply leg binds the spoke");
        assertEq(sId, reserveId_, "supply leg binds the reserveId");
        assertEq(sUnderlying, underlying_, "supply leg binds the underlying");
        assertEq(uint8(sSide), uint8(AaveV4ReserveRegistryV2.Side.SUPPLY), "supply leg side");

        (address dSpoke, uint256 dId, address dUnderlying,, AaveV4ReserveRegistryV2.Side dSide) =
            registry.getReserveInfo(debtKey);
        assertEq(dSpoke, address(freshSpoke), "debt leg binds the spoke");
        assertEq(dId, reserveId_, "debt leg binds the reserveId");
        assertEq(dUnderlying, underlying_, "debt leg binds the underlying");
        assertEq(uint8(dSide), uint8(AaveV4ReserveRegistryV2.Side.DEBT), "debt leg side");
    }

    /// @notice Fuzzed decimals binding over 0..77: whatever the spoke reports is stored verbatim on
    ///         BOTH legs
    /// @dev 78+ is deliberately out of range here: `10 ** decimals` overflow is a PPS concern in
    ///      `AaveV4ReserveOracle`, not a registry one — the registry stores any uint8 faithfully.
    function testFuzz_registerReserve_bindsDecimals(uint8 decimals_) public {
        decimals_ = uint8(bound(uint256(decimals_), 0, 77));

        MockLifecycleSpoke freshSpoke = new MockLifecycleSpoke();
        freshSpoke.setReserve(1, usdc, decimals_);

        (address supplyKey, address debtKey) = registry.registerReserve(address(freshSpoke), 1);

        (,,, uint8 sDecimals,) = registry.getReserveInfo(supplyKey);
        (,,, uint8 dDecimals,) = registry.getReserveInfo(debtKey);
        assertEq(sDecimals, decimals_, "supply leg stores the reported decimals verbatim");
        assertEq(dDecimals, decimals_, "debt leg stores the reported decimals verbatim");
    }

    /// @notice Fuzzed timelock boundary per leg: execution succeeds iff the full delay has elapsed
    function testFuzz_timelockBoundary(uint256 offset, bool useDebtLeg) public {
        offset = bound(offset, 0, 2 * registry.DEREGISTER_DELAY());
        address key = useDebtLeg ? usdcDebtKey : usdcKey;

        registry.proposeDeregisterReserve(key);
        uint256 deadline = registry.pendingDeregistrations(key);

        vm.warp(block.timestamp + offset);
        if (block.timestamp < deadline) {
            vm.expectRevert(AaveV4ReserveRegistryV2.DEREGISTRATION_TIMELOCK_NOT_ELAPSED.selector);
            registry.executeDeregisterReserve(key);
            assertTrue(registry.isRegistered(key), "premature execute changes nothing");
        } else {
            registry.executeDeregisterReserve(key);
            assertFalse(registry.isRegistered(key), "ripe execute deregisters the key");
        }
    }

    /// @notice Role gating holds for ANY non-manager caller, not just the one fixed outsider
    function testFuzz_accessControl_anyNonManagerIsRejected(address caller) public {
        assumeNotForgeAddress(caller);
        vm.assume(caller != admin);
        vm.assume(!registry.hasRole(MANAGER_ROLE, caller));

        vm.startPrank(caller);
        vm.expectRevert(_unauthorised(caller, MANAGER_ROLE));
        registry.registerReserve(address(spoke), WETH_RESERVE_ID);
        vm.expectRevert(_unauthorised(caller, MANAGER_ROLE));
        registry.proposeDeregisterReserve(usdcKey);
        vm.expectRevert(_unauthorised(caller, MANAGER_ROLE));
        registry.executeDeregisterReserve(usdcKey);
        vm.expectRevert(_unauthorised(caller, MANAGER_ROLE));
        registry.cancelDeregisterReserve(usdcKey);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    repairLeg — THE INVERTIBILITY FIX
    //////////////////////////////////////////////////////////////*/

    /// @dev Drops one leg through the full timelock and returns the dropped key
    function _dropLeg(bool dropDebt) internal returns (address droppedKey) {
        droppedKey = dropDebt ? usdcDebtKey : usdcKey;
        registry.proposeDeregisterReserve(droppedKey);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        registry.executeDeregisterReserve(droppedKey);
        assertFalse(registry.isRegistered(droppedKey), "leg dropped");
    }

    /// @notice repairLeg restores a dropped SUPPLY leg immediately, with the binding re-read from the
    ///         Spoke, and leaves the surviving sibling untouched
    function test_repairLeg_restoresDroppedSupplyLeg() public {
        _dropLeg(false);
        assertTrue(registry.isRegistered(usdcDebtKey), "debt sibling survives");

        address restored = registry.repairLeg(address(spoke), USDC_RESERVE_ID, AaveV4ReserveRegistryV2.Side.SUPPLY);
        assertEq(restored, usdcKey, "repair writes exactly the derived supply key");
        assertTrue(registry.isRegistered(usdcKey), "supply leg restored");

        (address s_, uint256 id_, address u_, uint8 d_, AaveV4ReserveRegistryV2.Side side_) =
            registry.getReserveInfo(usdcKey);
        assertEq(s_, address(spoke), "spoke re-bound");
        assertEq(id_, USDC_RESERVE_ID, "reserveId re-bound");
        assertEq(u_, usdc, "underlying re-read from the Spoke");
        assertEq(d_, 6, "decimals re-read from the Spoke");
        assertTrue(side_ == AaveV4ReserveRegistryV2.Side.SUPPLY, "restored under the SUPPLY side");
    }

    /// @notice The mirror case: a dropped DEBT leg is restorable without disturbing supply NAV reads
    function test_repairLeg_restoresDroppedDebtLeg() public {
        _dropLeg(true);
        assertTrue(registry.isRegistered(usdcKey), "supply sibling survives");

        address restored = registry.repairLeg(address(spoke), USDC_RESERVE_ID, AaveV4ReserveRegistryV2.Side.DEBT);
        assertEq(restored, usdcDebtKey, "repair writes exactly the derived debt key");
        (,,,, AaveV4ReserveRegistryV2.Side side_) = registry.getReserveInfo(usdcDebtKey);
        assertTrue(side_ == AaveV4ReserveRegistryV2.Side.DEBT, "restored under the DEBT side");
    }

    /// @notice repairLeg needs NO timelock — it can only restore a leg, never remove one, so there is
    ///         nothing to warn about. Repair in the same block as the execute that dropped it.
    function test_repairLeg_hasNoTimelock() public {
        uint256 t = block.timestamp;
        _dropLeg(false);
        vm.warp(t); // rewind: prove the repair itself imposes no delay
        registry.repairLeg(address(spoke), USDC_RESERVE_ID, AaveV4ReserveRegistryV2.Side.SUPPLY);
        assertTrue(registry.isRegistered(usdcKey), "restored with no waiting period");
    }

    /// @notice repairLeg is never an overwrite: a leg that is already present is refused
    function test_repairLeg_revertIf_legAlreadyPresent() public {
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_ALREADY_REGISTERED.selector);
        registry.repairLeg(address(spoke), USDC_RESERVE_ID, AaveV4ReserveRegistryV2.Side.SUPPLY);

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_ALREADY_REGISTERED.selector);
        registry.repairLeg(address(spoke), USDC_RESERVE_ID, AaveV4ReserveRegistryV2.Side.DEBT);
    }

    /// @notice repairLeg cannot restore a leg of a reserve the Spoke has since delisted — the binding is
    ///         re-read rather than copied from the surviving sibling
    function test_repairLeg_revertIf_reserveNoLongerListed() public {
        _dropLeg(false);
        spoke.setReserve(USDC_RESERVE_ID, address(0), 0);

        vm.expectRevert(AaveV4ReserveRegistryV2.INVALID_RESERVE.selector);
        registry.repairLeg(address(spoke), USDC_RESERVE_ID, AaveV4ReserveRegistryV2.Side.SUPPLY);
        assertFalse(registry.isRegistered(usdcKey), "nothing written on the failed repair");
    }

    /// @notice repairLeg rejects a zero spoke
    function test_repairLeg_revertIf_zeroSpoke() public {
        _dropLeg(false);
        vm.expectRevert(AaveV4ReserveRegistryV2.ZERO_ADDRESS.selector);
        registry.repairLeg(address(0), USDC_RESERVE_ID, AaveV4ReserveRegistryV2.Side.SUPPLY);
    }

    /// @notice repairLeg is role-gated like every other mutation
    function test_repairLeg_revertIf_unauthorised() public {
        _dropLeg(false);
        vm.prank(outsider);
        vm.expectRevert(_unauthorised(outsider, MANAGER_ROLE));
        registry.repairLeg(address(spoke), USDC_RESERVE_ID, AaveV4ReserveRegistryV2.Side.SUPPLY);
        assertFalse(registry.isRegistered(usdcKey), "unauthorised repair wrote nothing");
    }

    /// @notice repairLeg emits ReserveRegistered for the restored leg only, carrying its side
    function test_repairLeg_emitsReserveRegisteredForThatLegOnly() public {
        _dropLeg(true);

        vm.recordLogs();
        registry.repairLeg(address(spoke), USDC_RESERVE_ID, AaveV4ReserveRegistryV2.Side.DEBT);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1, "exactly one event for a single-leg repair");
        assertEq(
            logs[0].topics[0],
            keccak256("ReserveRegistered(address,address,uint256,address,uint8)"),
            "ReserveRegistered topic0"
        );
        assertEq(address(uint160(uint256(logs[0].topics[1]))), usdcDebtKey, "indexed key is the repaired leg");
        (, uint256 emittedSide) = abi.decode(logs[0].data, (address, uint256));
        assertEq(emittedSide, uint256(AaveV4ReserveRegistryV2.Side.DEBT), "emitted side is DEBT");
    }

    /// @notice After a repair the reserve is whole again, so registerReserve is refused once more and the
    ///         pair behaves exactly as it did before the drop
    function test_repairLeg_restoresWholeReserve_registerStillRefused() public {
        _dropLeg(false);
        registry.repairLeg(address(spoke), USDC_RESERVE_ID, AaveV4ReserveRegistryV2.Side.SUPPLY);

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_ALREADY_REGISTERED.selector);
        registry.registerReserve(address(spoke), USDC_RESERVE_ID);

        (address sSpoke, uint256 sId,,, AaveV4ReserveRegistryV2.Side sSide) = registry.getReserveInfo(usdcKey);
        (address dSpoke, uint256 dId,,, AaveV4ReserveRegistryV2.Side dSide) = registry.getReserveInfo(usdcDebtKey);
        assertEq(sSpoke, dSpoke, "both legs share the spoke again");
        assertEq(sId, dId, "both legs share the reserveId again");
        assertTrue(sSide == AaveV4ReserveRegistryV2.Side.SUPPLY && dSide == AaveV4ReserveRegistryV2.Side.DEBT, "sides");
    }

    /// @notice repairLeg can only ever COMPLETE a half-registered reserve. On a reserve that was never
    ///         registered it reverts, so it cannot be used as an alternative creation path and cannot mint
    ///         the lone-leg state that would wedge the reserve against `registerReserve` forever.
    function test_repairLeg_revertIf_siblingNotRegistered() public {
        // A completely unregistered reserve: neither leg present
        spoke.setReserve(321, weth, 18);
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        registry.repairLeg(address(spoke), 321, AaveV4ReserveRegistryV2.Side.SUPPLY);
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        registry.repairLeg(address(spoke), 321, AaveV4ReserveRegistryV2.Side.DEBT);

        assertFalse(registry.isRegistered(registry.computeReserveKey(address(spoke), 321)), "no supply leg minted");
        assertFalse(registry.isRegistered(registry.computeDebtKey(address(spoke), 321)), "no debt leg minted");
        // ...and the normal path still works, i.e. nothing was wedged
        registry.registerReserve(address(spoke), 321);
        assertTrue(registry.isRegistered(registry.computeReserveKey(address(spoke), 321)), "register still works");
    }

    /// @notice Both legs fully deregistered is NOT a repairable state either — `registerReserve` owns it.
    ///         This is the boundary between the two entry points.
    function test_repairLeg_revertIf_bothLegsDeregistered() public {
        registry.proposeDeregisterReserve(usdcKey);
        registry.proposeDeregisterReserve(usdcDebtKey);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        registry.executeDeregisterReserve(usdcKey);
        registry.executeDeregisterReserve(usdcDebtKey);

        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        registry.repairLeg(address(spoke), USDC_RESERVE_ID, AaveV4ReserveRegistryV2.Side.SUPPLY);

        // registerReserve is the correct recovery for a fully-dropped reserve
        (address k, address dk) = registry.registerReserve(address(spoke), USDC_RESERVE_ID);
        assertEq(k, usdcKey, "supply key restored");
        assertEq(dk, usdcDebtKey, "debt key restored");
    }

    /// @notice repairLeg writes the derivation of its OWN arguments, so it can never restore a leg onto a
    ///         different reserve than the one named
    function test_repairLeg_writesOnlyItsOwnDerivedKey() public {
        _dropLeg(true); // USDC debt leg missing, supply leg survives
        address written = registry.repairLeg(address(spoke), USDC_RESERVE_ID, AaveV4ReserveRegistryV2.Side.DEBT);
        assertEq(written, registry.computeDebtKey(address(spoke), USDC_RESERVE_ID), "its own derived debt key");
        assertTrue(written != usdcKey, "never the supply key");
    }
}
