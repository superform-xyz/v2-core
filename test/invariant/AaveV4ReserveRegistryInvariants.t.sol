// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";

import { AaveV4ReserveRegistryV2 } from "../../src/accounting/oracles/AaveV4ReserveRegistryV2.sol";
import { AaveV4ReserveOracle } from "../../src/accounting/oracles/AaveV4ReserveOracle.sol";
import { IAaveV4Spoke } from "../../src/vendor/aave-v4/IAaveV4Spoke.sol";
import { SuperLedgerConfiguration } from "../../src/accounting/SuperLedgerConfiguration.sol";

/*//////////////////////////////////////////////////////////////
                            MOCK SPOKE
//////////////////////////////////////////////////////////////*/

/// @title MockAaveV4SpokeInvariant
/// @notice Minimal Aave V4 spoke stub for the registry invariant campaign
/// @dev Mirrors `MockAaveV4Spoke` in test/unit/accounting/oracles/AaveV4Oracles.t.sol: `getReserve`
///      reverts for unlisted ids (as the real spoke does) and the balance/TVL views return fixed,
///      nonzero amounts. The registry invariants never depend on the magnitudes — only on the fact
///      that oracle reads succeed for registered keys and revert for unregistered ones — so the
///      position views are constants rather than settable state.
contract MockAaveV4SpokeInvariant {
    /// @notice Thrown when querying a reserve id that was never listed on this spoke
    error ReserveNotListed();

    mapping(uint256 reserveId => IAaveV4Spoke.Reserve) internal _reserves;
    mapping(uint256 reserveId => bool) internal _listed;

    /// @notice List a reserve so `registerReserve` can bind it
    /// @param reserveId The reserve identifier within this spoke
    /// @param underlying The reserve's underlying asset
    /// @param decimals_ The underlying asset's decimals
    function setReserve(uint256 reserveId, address underlying, uint8 decimals_) external {
        _reserves[reserveId] = IAaveV4Spoke.Reserve({
            underlying: underlying,
            hub: address(this),
            assetId: uint16(reserveId),
            decimals: decimals_,
            collateralRisk: 0,
            flags: 0,
            dynamicConfigKey: 0
        });
        _listed[reserveId] = true;
    }

    /// @notice Reserve data, reverting for unlisted ids exactly as the real spoke does
    function getReserve(uint256 reserveId) external view returns (IAaveV4Spoke.Reserve memory) {
        if (!_listed[reserveId]) revert ReserveNotListed();
        return _reserves[reserveId];
    }

    /// @notice Fixed (drawn, premium) debt for any (reserve, user)
    function getUserDebt(uint256, address) external pure returns (uint256, uint256) {
        return (1e6, 7);
    }

    /// @notice Fixed supplied assets for any (reserve, user)
    function getUserSuppliedAssets(uint256, address) external pure returns (uint256) {
        return 3e6;
    }

    /// @notice Fixed reserve-level (drawn, premium) debt
    function getReserveDebt(uint256) external pure returns (uint256, uint256) {
        return (5e6, 11);
    }

    /// @notice Fixed reserve-level supplied assets
    function getReserveSuppliedAssets(uint256) external pure returns (uint256) {
        return 9e6;
    }
}

/*//////////////////////////////////////////////////////////////
                              HANDLER
//////////////////////////////////////////////////////////////*/

/// @title AaveV4ReserveRegistryHandler
/// @notice Bounded random-action driver over a fixed 4-spoke x 6-reserve universe (24 reserves, 48 keys)
/// @dev The handler holds DEFAULT_ADMIN_ROLE and MARKET_MANAGER_ROLE, so it can both mutate registry
///      data and churn the manager role on three separate actor addresses. Every action picks a caller
///      from {actor0, actor1, actor2, handler}; only the handler is permanently authorised, so a large
///      fraction of attempted calls are unauthorised and must revert. Because `fail_on_revert = false`
///      swallows reverts inside handler calls, the handler NEVER asserts — it records every outcome
///      mismatch into ghost counters that `invariant_RoleChurnSafety` then asserts on.
contract AaveV4ReserveRegistryHandler is Test {
    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @param spoke The spoke this key was derived from
    /// @param reserveId The reserve id this key was derived from
    /// @param side The leg this key denotes
    /// @param sibling The other leg's key for the same reserve
    struct KeyMeta {
        address spoke;
        uint256 reserveId;
        AaveV4ReserveRegistryV2.Side side;
        address sibling;
    }

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    AaveV4ReserveRegistryV2 public immutable REGISTRY;
    bytes32 public immutable MANAGER_ROLE;

    /// @notice The four spokes in the universe
    address[] public spokes;

    /// @notice The six reserve ids listed on every spoke
    uint256[] public reserveIds;

    /// @notice Callers used for actions: indices 0-2 are role-churned, index 3 is this handler
    address[] public actors;

    /// @notice Every key in the universe (supply and debt leg of all 24 reserves)
    address[] public allKeys;

    /// @notice Static derivation metadata per key — what the key must always re-derive to
    mapping(address reserveKey => KeyMeta) public keyMeta;

    /// @notice What a market key must always re-derive from, and which legs it claims
    struct MarketMeta {
        address spoke;
        uint256 supplyReserveId;
        uint256 borrowReserveId;
        bool seen;
    }

    /*//////////////////////////////////////////////////////////////
                             GHOST STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Expected current registration state per key
    mapping(address reserveKey => bool) public ghostRegistered;

    /// @notice True once a key has been created by a successful `registerReserve`
    mapping(address reserveKey => bool) public ghostEverRegistered;

    /// @notice True once a key has been removed by a successful `executeDeregisterReserve`
    mapping(address reserveKey => bool) public ghostEverDeregistered;

    /// @notice Every market key the campaign has ever registered, for the market invariants to sweep
    address[] public allMarketKeys;

    /// @notice Expected current registration state per market key
    mapping(address marketKey => bool) public ghostMarketRegistered;

    /// @notice The (spoke, supplyId, borrowId) triple a market key was registered with
    mapping(address marketKey => MarketMeta) public marketMeta;

    /// @notice True once a key has been restored by a successful `repairLeg`
    /// @dev Deliberately SEPARATE from `ghostEverRegistered`: a repair must never be what makes INV-4's
    ///      "this key was created by a paired write" assertion true. See `repairLeg` below.
    mapping(address reserveKey => bool) public ghostEverRepaired;

    /// @notice Highest `executeAfter` ever observed for the key's CURRENT pending entry (0 when none)
    mapping(address reserveKey => uint256) public ghostPendingHighWater;

    /// @notice `block.timestamp` of the most recent successful proposal for the key's CURRENT pending
    ///         entry (0 when none)
    /// @dev Recorded by the HANDLER rather than read back from the contract, so INV-6 can compare the
    ///      armed deadline against the block that armed it instead of against the contract's own output.
    mapping(address reserveKey => uint256) public ghostProposedAt;

    /// @notice Expected number of currently registered keys
    uint256 public ghostRegisteredCount;

    /// @notice Count of calls that succeeded although the handler predicted a revert
    uint256 public ghostUnexpectedSuccesses;

    /// @notice Count of calls that reverted although the handler predicted success
    uint256 public ghostUnexpectedReverts;

    /// @notice Count of data-mutating calls that succeeded from a caller lacking MARKET_MANAGER_ROLE
    uint256 public ghostUnauthorisedSuccesses;

    /// @notice Count of re-proposals whose `executeAfter` came back lower than the previous one
    uint256 public ghostTimelockRegressions;

    /// @notice Count of proposals that armed an `executeAfter` LESS than a full `DEREGISTER_DELAY`
    ///         after the block that armed them
    uint256 public ghostShortDelays;

    /// @notice Count of proposals that armed an `executeAfter` less than `MIN_DEREGISTER_DELAY` after
    ///         the block that armed them, measured against this handler's OWN constant
    /// @dev Separate from `ghostShortDelays` on purpose. That counter uses `registry.DEREGISTER_DELAY()`
    ///      on both sides of the comparison, so it catches an arming bug but stays silent if the constant
    ///      itself is shortened. This one hardcodes the floor and is the only check that fails when
    ///      `DEREGISTER_DELAY` is reduced.
    uint256 public ghostFloorBreaches;

    /// @notice Count of successful `repairLeg` calls whose sibling leg was NOT registered beforehand
    /// @dev A non-zero value means `repairLeg` minted a LONE leg — the half-registered state
    ///      `registerReserve`'s paired write exists to make unrepresentable.
    uint256 public ghostLoneLegMints;

    /// @notice Count of successful `repairLeg` calls that returned a key other than the one its
    ///         `(spoke, reserveId, side)` triple derives to
    uint256 public ghostRepairKeyMismatches;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The 2-day deregistration warning window, hardcoded here INDEPENDENTLY of the registry
    /// @dev `AaveV4ReserveRegistryV2.DEREGISTER_DELAY` is the operator's warning window and the value this
    ///      campaign treats as a floor. Reading the floor from the contract under test would make every
    ///      delay self-consistent — the exact weakness INV-6 used to have — so the number is restated here.
    uint256 public constant MIN_DEREGISTER_DELAY = 2 days;

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Builds the fixed universe, lists every reserve on every spoke and precomputes all keys
    /// @param registry_ The registry under test
    constructor(AaveV4ReserveRegistryV2 registry_) {
        REGISTRY = registry_;
        MANAGER_ROLE = registry_.MARKET_MANAGER_ROLE();

        uint256[6] memory ids = [uint256(0), 1, 7, 12, 99, 4242];
        uint8[6] memory decs = [uint8(6), 8, 18, 18, 6, 12];
        for (uint256 k; k < ids.length; ++k) {
            reserveIds.push(ids[k]);
        }

        for (uint256 s; s < 4; ++s) {
            MockAaveV4SpokeInvariant spoke = new MockAaveV4SpokeInvariant();
            spokes.push(address(spoke));
            for (uint256 r; r < reserveIds.length; ++r) {
                spoke.setReserve(reserveIds[r], address(uint160(0xA4E00 + s * 100 + r)), decs[r]);

                address supplyKey = registry_.computeReserveKey(address(spoke), reserveIds[r]);
                address debtKey = registry_.computeDebtKey(address(spoke), reserveIds[r]);

                keyMeta[supplyKey] = KeyMeta({
                    spoke: address(spoke),
                    reserveId: reserveIds[r],
                    side: AaveV4ReserveRegistryV2.Side.SUPPLY,
                    sibling: debtKey
                });
                keyMeta[debtKey] = KeyMeta({
                    spoke: address(spoke),
                    reserveId: reserveIds[r],
                    side: AaveV4ReserveRegistryV2.Side.DEBT,
                    sibling: supplyKey
                });
                allKeys.push(supplyKey);
                allKeys.push(debtKey);
            }
        }

        actors.push(makeAddr("aaveV4RegistryActor0"));
        actors.push(makeAddr("aaveV4RegistryActor1"));
        actors.push(makeAddr("aaveV4RegistryActor2"));
        actors.push(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice Number of keys in the tracked universe
    function allKeysLength() external view returns (uint256) {
        return allKeys.length;
    }

    /// @notice Number of market keys the campaign has ever registered
    function allMarketKeysLength() external view returns (uint256) {
        return allMarketKeys.length;
    }

    /*//////////////////////////////////////////////////////////////
                               ACTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Register a (spoke, reserveId) pair picked from the universe
    /// @dev Registration is per reserve and writes BOTH legs, so ghost state is updated in pairs.
    ///      It must revert when EITHER leg is already registered, which is how a reserve whose supply
    ///      leg was deregistered while its debt leg survived becomes permanently unregisterable.
    /// @param seed Fuzzed selector for the reserve and the caller
    function registerReserve(uint256 seed) external {
        address spoke = spokes[seed % spokes.length];
        uint256 reserveId = reserveIds[(seed >> 8) % reserveIds.length];
        address caller = _actor(seed >> 16);

        address supplyKey = REGISTRY.computeReserveKey(spoke, reserveId);
        address debtKey = REGISTRY.computeDebtKey(spoke, reserveId);

        bool authorised = REGISTRY.hasRole(MANAGER_ROLE, caller);
        bool shouldSucceed = authorised && !ghostRegistered[supplyKey] && !ghostRegistered[debtKey];

        if (caller != address(this)) vm.prank(caller);
        try REGISTRY.registerReserve(spoke, reserveId) {
            if (!shouldSucceed) ++ghostUnexpectedSuccesses;
            if (!authorised) ++ghostUnauthorisedSuccesses;
            ghostRegistered[supplyKey] = true;
            ghostRegistered[debtKey] = true;
            ghostEverRegistered[supplyKey] = true;
            ghostEverRegistered[debtKey] = true;
            ghostRegisteredCount += 2;
        } catch {
            if (shouldSucceed) ++ghostUnexpectedReverts;
        }
    }

    /// @notice Restore the missing leg of a half-registered reserve
    /// @dev THE MUTATION INV-4 EXISTS TO CATCH. `repairLeg` is the only role-gated write that can create a
    ///      SINGLE key, so without it in the action space INV-4 ("legs are only ever created in pairs") is
    ///      true merely because nothing can falsify it. It is reachable here, and INV-4 plus INV-10 are the
    ///      proof that the sibling-registered precondition confines it to COMPLETING a reserve
    ///      `registerReserve` already created.
    ///      Ghost bookkeeping note: this deliberately does NOT set `ghostEverRegistered`. INV-4 asserts
    ///      `ghostEverRegistered` for every live key, so leaving it alone turns INV-4 into the detector —
    ///      a leg that only `repairLeg` ever created would fail it. The claim being proven is that every leg
    ///      `repairLeg` can reach was already written once by a paired `registerReserve`.
    /// @param seed Fuzzed selector for the key and the caller
    function repairLeg(uint256 seed) external {
        address key = _pickRepairableKey(seed);
        KeyMeta memory meta = keyMeta[key];
        address caller = _actor(seed >> 16);

        bool authorised = REGISTRY.hasRole(MANAGER_ROLE, caller);
        bool siblingLive = ghostRegistered[meta.sibling];
        bool shouldSucceed = authorised && !ghostRegistered[key] && siblingLive;

        if (caller != address(this)) vm.prank(caller);
        try REGISTRY.repairLeg(meta.spoke, meta.reserveId, meta.side) returns (address restored) {
            if (!shouldSucceed) ++ghostUnexpectedSuccesses;
            if (!authorised) ++ghostUnauthorisedSuccesses;
            if (restored != key) ++ghostRepairKeyMismatches;
            if (!siblingLive) ++ghostLoneLegMints;
            if (!ghostRegistered[key]) ++ghostRegisteredCount;
            ghostRegistered[key] = true;
            ghostEverRepaired[key] = true;
        } catch {
            if (shouldSucceed) ++ghostUnexpectedReverts;
        }
    }

    /// @notice Propose deregistration of a currently registered key, preferring a real one
    /// @dev Records the proposing block's `block.timestamp` so INV-6 can measure the armed deadline
    ///      against the block that armed it. Comparing the contract's output only against itself — which
    ///      is what a high-water mark seeded from `pendingDeregistrations` does — accepts ANY delay,
    ///      including zero.
    /// @param seed Fuzzed selector for the key and the caller
    function proposeDeregister(uint256 seed) external {
        address key = _pickRegisteredKey(seed);
        address caller = _actor(seed >> 16);

        bool authorised = REGISTRY.hasRole(MANAGER_ROLE, caller);
        bool shouldSucceed = authorised && ghostRegistered[key];
        uint256 previous = ghostPendingHighWater[key];
        uint256 proposedAt = block.timestamp;

        if (caller != address(this)) vm.prank(caller);
        try REGISTRY.proposeDeregisterReserve(key) {
            if (!shouldSucceed) ++ghostUnexpectedSuccesses;
            if (!authorised) ++ghostUnauthorisedSuccesses;
            uint256 fresh = REGISTRY.pendingDeregistrations(key);
            if (fresh < proposedAt + REGISTRY.DEREGISTER_DELAY()) ++ghostShortDelays;
            if (fresh < proposedAt + MIN_DEREGISTER_DELAY) ++ghostFloorBreaches;
            if (fresh < previous) ++ghostTimelockRegressions;
            ghostPendingHighWater[key] = fresh > previous ? fresh : previous;
            ghostProposedAt[key] = proposedAt;
        } catch {
            if (shouldSucceed) ++ghostUnexpectedReverts;
        }
    }

    /// @notice Execute a pending deregistration, preferring a key whose timelock has ripened
    /// @param seed Fuzzed selector for the key and the caller
    function executeDeregister(uint256 seed) external {
        address key = _pickRipePendingKey(seed);
        address caller = _actor(seed >> 16);

        uint256 executeAfter = REGISTRY.pendingDeregistrations(key);
        bool authorised = REGISTRY.hasRole(MANAGER_ROLE, caller);
        bool shouldSucceed = authorised && executeAfter != 0 && block.timestamp >= executeAfter;

        if (caller != address(this)) vm.prank(caller);
        try REGISTRY.executeDeregisterReserve(key) {
            if (!shouldSucceed) ++ghostUnexpectedSuccesses;
            if (!authorised) ++ghostUnauthorisedSuccesses;
            if (ghostRegistered[key]) --ghostRegisteredCount;
            ghostRegistered[key] = false;
            ghostEverDeregistered[key] = true;
            ghostPendingHighWater[key] = 0;
            ghostProposedAt[key] = 0;
        } catch {
            if (shouldSucceed) ++ghostUnexpectedReverts;
        }
    }

    /// @notice Cancel a pending deregistration, preferring a key that actually has one
    /// @param seed Fuzzed selector for the key and the caller
    function cancelDeregister(uint256 seed) external {
        address key = _pickPendingKey(seed);
        address caller = _actor(seed >> 16);

        bool authorised = REGISTRY.hasRole(MANAGER_ROLE, caller);
        bool shouldSucceed = authorised && REGISTRY.pendingDeregistrations(key) != 0;

        if (caller != address(this)) vm.prank(caller);
        try REGISTRY.cancelDeregisterReserve(key) {
            if (!shouldSucceed) ++ghostUnexpectedSuccesses;
            if (!authorised) ++ghostUnauthorisedSuccesses;
            ghostPendingHighWater[key] = 0;
            ghostProposedAt[key] = 0;
        } catch {
            if (shouldSucceed) ++ghostUnexpectedReverts;
        }
    }

    /// @notice Advance time so deregistration timelocks can ripen
    /// @param seed Fuzzed time delta, bounded to 1 hour .. 3 days
    /// @notice Register a market pair, exercising the INTENT namespace alongside the NAV one
    /// @dev THE ACTION THE MARKET INVARIANTS NEED. Without it INV-12/13/14 are vacuously true, which is the
    ///      trap the merged-oracle review flagged on `UNHANDLED_SIDE`. Both legs and both guards
    ///      (`MARKET_LEG_NOT_REGISTERED`, `RESERVE_DEREGISTRATION_PENDING`) are reachable from here because
    ///      the reserve actions churn leg registration and proposals underneath it.
    /// @param seed Fuzzed selector for the spoke, both reserve ids and the caller
    function registerMarket(uint256 seed) external {
        address spoke = spokes[seed % spokes.length];
        uint256 supplyId = reserveIds[(seed >> 8) % reserveIds.length];
        uint256 borrowId = reserveIds[(seed >> 16) % reserveIds.length];
        address caller = _actor(seed >> 24);
        if (supplyId == borrowId) return;

        address marketKey = REGISTRY.computeMarketKey(spoke, supplyId, borrowId);

        if (caller != address(this)) vm.prank(caller);
        try REGISTRY.registerMarket(spoke, supplyId, borrowId) returns (address returned) {
            if (!REGISTRY.hasRole(MANAGER_ROLE, caller)) ++ghostUnauthorisedSuccesses;
            if (returned != marketKey) ++ghostUnexpectedSuccesses;
            if (!marketMeta[marketKey].seen) {
                allMarketKeys.push(marketKey);
                marketMeta[marketKey] =
                    MarketMeta({ spoke: spoke, supplyReserveId: supplyId, borrowReserveId: borrowId, seen: true });
            }
            ghostMarketRegistered[marketKey] = true;
        } catch { }
    }

    /// @notice Propose a market deregistration
    /// @param seed Fuzzed selector for the market key and the caller
    function proposeDeregisterMarket(uint256 seed) external {
        if (allMarketKeys.length == 0) return;
        address marketKey = allMarketKeys[seed % allMarketKeys.length];
        address caller = _actor(seed >> 16);

        if (caller != address(this)) vm.prank(caller);
        try REGISTRY.proposeDeregisterMarket(marketKey) {
            if (!REGISTRY.hasRole(MANAGER_ROLE, caller)) ++ghostUnauthorisedSuccesses;
        } catch { }
    }

    /// @notice Execute a ripe market deregistration
    /// @param seed Fuzzed selector for the market key and the caller
    function executeDeregisterMarket(uint256 seed) external {
        if (allMarketKeys.length == 0) return;
        address marketKey = allMarketKeys[seed % allMarketKeys.length];
        address caller = _actor(seed >> 16);

        if (caller != address(this)) vm.prank(caller);
        try REGISTRY.executeDeregisterMarket(marketKey) {
            if (!REGISTRY.hasRole(MANAGER_ROLE, caller)) ++ghostUnauthorisedSuccesses;
            ghostMarketRegistered[marketKey] = false;
        } catch { }
    }

    function warp(uint256 seed) external {
        vm.warp(block.timestamp + bound(seed, 1 hours, 3 days));
    }

    /// @notice Grant MARKET_MANAGER_ROLE to one of the three churnable actors
    /// @dev Never targets the handler itself, so at least one authorised caller always exists and the
    ///      campaign cannot deadlock into a state where no action can ever succeed again.
    /// @param seed Fuzzed actor selector
    function grantManager(uint256 seed) external {
        REGISTRY.grantRole(MANAGER_ROLE, actors[seed % 3]);
    }

    /// @notice Revoke MARKET_MANAGER_ROLE from one of the three churnable actors
    /// @param seed Fuzzed actor selector
    function revokeManager(uint256 seed) external {
        REGISTRY.revokeRole(MANAGER_ROLE, actors[seed % 3]);
    }

    /*//////////////////////////////////////////////////////////////
                              INTERNALS
    //////////////////////////////////////////////////////////////*/

    /// @dev Picks a caller; index 3 is the handler itself, which is permanently authorised
    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    /// @dev First registered key at or after `seed`, falling back to an arbitrary key so unauthorised
    ///      and not-registered revert paths are still exercised
    function _pickRegisteredKey(uint256 seed) internal view returns (address) {
        uint256 len = allKeys.length;
        uint256 start = seed % len;
        for (uint256 i; i < len; ++i) {
            address key = allKeys[(start + i) % len];
            if (ghostRegistered[key]) return key;
        }
        return allKeys[start];
    }

    /// @dev First HALF-REGISTERED key at or after `seed` — unregistered itself while its sibling is
    ///      registered, the one state `repairLeg` is meant for. Falls back to an arbitrary key so the
    ///      already-registered, no-sibling and unauthorised revert paths are exercised too.
    function _pickRepairableKey(uint256 seed) internal view returns (address) {
        uint256 len = allKeys.length;
        uint256 start = seed % len;
        for (uint256 i; i < len; ++i) {
            address key = allKeys[(start + i) % len];
            if (!ghostRegistered[key] && ghostRegistered[keyMeta[key].sibling]) return key;
        }
        return allKeys[start];
    }

    /// @dev First key with a nonzero pending entry at or after `seed`, else an arbitrary key
    function _pickPendingKey(uint256 seed) internal view returns (address) {
        uint256 len = allKeys.length;
        uint256 start = seed % len;
        for (uint256 i; i < len; ++i) {
            address key = allKeys[(start + i) % len];
            if (REGISTRY.pendingDeregistrations(key) != 0) return key;
        }
        return allKeys[start];
    }

    /// @dev First key with a RIPE pending entry at or after `seed`, else any pending key, else arbitrary
    function _pickRipePendingKey(uint256 seed) internal view returns (address) {
        uint256 len = allKeys.length;
        uint256 start = seed % len;
        for (uint256 i; i < len; ++i) {
            address key = allKeys[(start + i) % len];
            uint256 executeAfter = REGISTRY.pendingDeregistrations(key);
            if (executeAfter != 0 && block.timestamp >= executeAfter) return key;
        }
        return _pickPendingKey(seed);
    }
}

/*//////////////////////////////////////////////////////////////
                        INVARIANT TEST
//////////////////////////////////////////////////////////////*/

/// @title AaveV4ReserveRegistryInvariantsTest
/// @notice Stateful invariant campaign over `AaveV4ReserveRegistryV2` and its consumer
///         `AaveV4ReserveOracle`
/// @dev The registry is a DERIVED-key registry: a key is `keccak256(spoke, reserveId)` (supply) or
///      `keccak256(spoke, reserveId, DEBT_KEY_DOMAIN)` (debt), truncated to 20 bytes. Its entire
///      safety argument is that a key can only ever bind to the reserve that hashes to it, that the
///      side baked into the key is the only discriminator the sideless `IYieldSourceOracle` surface
///      has, and that the 2-day deregistration timelock can never be shortened. These invariants pin
///      exactly those properties across registration, single-leg repair, the full propose/execute/cancel
///      timelock lifecycle, time travel and manager-role churn.
/// @dev ACTION SPACE COMPLETENESS. Every role-gated mutation on the registry is in the handler's selector
///      list — `registerReserve`, `repairLeg`, `proposeDeregisterReserve`, `executeDeregisterReserve`,
///      `cancelDeregisterReserve` — plus role churn and time travel. `repairLeg` matters most: it is the
///      only write that can create a SINGLE key, so it is the only action capable of falsifying INV-4 and
///      INV-10. Leaving it out would make both pass for the wrong reason.
contract AaveV4ReserveRegistryInvariantsTest is Test {
    AaveV4ReserveRegistryV2 public registry;
    AaveV4ReserveOracle public oracle;
    AaveV4ReserveRegistryHandler public handler;

    /// @dev Arbitrary position owner used for the oracle balance reads
    address internal constant OWNER = address(0xBEEF);

    function setUp() public {
        // Deregistration timelock math adds 2 days to block.timestamp; start well clear of zero so
        // comparisons against historic timestamps stay meaningful.
        vm.warp(365 days * 2);

        registry = new AaveV4ReserveRegistryV2(address(this));
        oracle = new AaveV4ReserveOracle(address(new SuperLedgerConfiguration()), address(registry));

        handler = new AaveV4ReserveRegistryHandler(registry);

        // The handler drives every mutation: it needs the manager role to act and the admin role to
        // churn the manager role on its actors.
        registry.grantRole(registry.MARKET_MANAGER_ROLE(), address(handler));
        registry.grantRole(registry.DEFAULT_ADMIN_ROLE(), address(handler));
        // Remove the deployer's powers so the handler's ghost state is the only authority on registry
        // data; otherwise the test contract could mutate state outside the campaign's bookkeeping.
        registry.renounceRole(registry.MARKET_MANAGER_ROLE(), address(this));
        registry.renounceRole(registry.DEFAULT_ADMIN_ROLE(), address(this));

        // `repairLeg` MUST stay in this list: it is the only role-gated write that can create a single
        // key, so it is the only action able to falsify INV-4 / INV-10. Dropping it would make both
        // invariants vacuously true.
        bytes4[] memory selectors = new bytes4[](11);
        selectors[0] = AaveV4ReserveRegistryHandler.registerReserve.selector;
        selectors[1] = AaveV4ReserveRegistryHandler.proposeDeregister.selector;
        selectors[2] = AaveV4ReserveRegistryHandler.executeDeregister.selector;
        selectors[3] = AaveV4ReserveRegistryHandler.cancelDeregister.selector;
        selectors[4] = AaveV4ReserveRegistryHandler.warp.selector;
        selectors[5] = AaveV4ReserveRegistryHandler.grantManager.selector;
        selectors[6] = AaveV4ReserveRegistryHandler.revokeManager.selector;
        selectors[7] = AaveV4ReserveRegistryHandler.repairLeg.selector;
        // The three market actions MUST stay here for the same reason `repairLeg` must: they are the only
        // writes to the INTENT namespace, so INV-12 / INV-13 / INV-14 are vacuous without them.
        selectors[8] = AaveV4ReserveRegistryHandler.registerMarket.selector;
        selectors[9] = AaveV4ReserveRegistryHandler.proposeDeregisterMarket.selector;
        selectors[10] = AaveV4ReserveRegistryHandler.executeDeregisterMarket.selector;

        targetContract(address(handler));
        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
    }

    /*//////////////////////////////////////////////////////////////
                    INV-1: DERIVATION INTEGRITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Every key the registry reports as registered re-derives EXACTLY itself from the
    ///         `(spoke, reserveId, side)` triple `getReserveInfo` returns — supply keys through
    ///         `computeReserveKey`, debt keys through `computeDebtKey`.
    /// @dev This is the core safety property of a derived-key registry. If a key could ever be bound
    ///      to a reserve it does not hash to, the pseudo-address stops naming a reserve: a hook header
    ///      pinned to `computeReserveKey(spoke, id)` — which since SUP-21239 means the V1 LOAN six and the
    ///      idle MONEY_MARKET pair, the V2 six having moved to the market key — would resolve through the
    ///      oracle to a DIFFERENT
    ///      spoke/reserve, so NAV, TVL and ledger accounting would be read from the wrong market. The
    ///      contract achieves this by computing the key from the inputs rather than accepting one, and
    ///      this invariant holds that true across re-registration after deregistration.
    /// forge-config: default.invariant.runs = 32
    /// forge-config: default.invariant.depth = 80
    function invariant_DerivationIntegrity() public view {
        uint256 len = handler.allKeysLength();
        for (uint256 i; i < len; ++i) {
            address key = handler.allKeys(i);
            if (!registry.isRegistered(key)) continue;

            (address spoke, uint256 reserveId,,, AaveV4ReserveRegistryV2.Side side) = registry.getReserveInfo(key);

            address rederived = side == AaveV4ReserveRegistryV2.Side.SUPPLY
                ? registry.computeReserveKey(spoke, reserveId)
                : registry.computeDebtKey(spoke, reserveId);

            assertEq(rederived, key, "INV-1: registered key does not re-derive from its own binding");
        }
    }

    /*//////////////////////////////////////////////////////////////
                      INV-2: SIDE CORRECTNESS
    //////////////////////////////////////////////////////////////*/

    /// @notice A registered key's stored side always matches the derivation that produced it: SUPPLY
    ///         keys equal `computeReserveKey` and NOT `computeDebtKey`, and vice versa for DEBT keys.
    /// @dev The side is the ONLY discriminator the sideless `IYieldSourceOracle` surface has. A supply
    ///      key stored as DEBT would make `getBalanceOfOwner` return the owner's debt where the
    ///      aggregator expects collateral — a sign error in NAV, not a rounding error. Asserting the
    ///      cross-derivation does NOT match additionally pins that the two preimages (two words vs
    ///      three with `DEBT_KEY_DOMAIN`) stay genuinely separate domains.
    /// forge-config: default.invariant.runs = 32
    /// forge-config: default.invariant.depth = 80
    function invariant_SideCorrectness() public view {
        uint256 len = handler.allKeysLength();
        for (uint256 i; i < len; ++i) {
            address key = handler.allKeys(i);
            if (!registry.isRegistered(key)) continue;

            (address spoke, uint256 reserveId,,, AaveV4ReserveRegistryV2.Side side) = registry.getReserveInfo(key);
            (,, AaveV4ReserveRegistryV2.Side expectedSide,) = handler.keyMeta(key);

            assertEq(uint8(side), uint8(expectedSide), "INV-2: stored side differs from derivation side");

            if (side == AaveV4ReserveRegistryV2.Side.SUPPLY) {
                assertEq(registry.computeReserveKey(spoke, reserveId), key, "INV-2: SUPPLY key not supply-derived");
                assertTrue(registry.computeDebtKey(spoke, reserveId) != key, "INV-2: SUPPLY key is also a debt key");
            } else {
                assertEq(registry.computeDebtKey(spoke, reserveId), key, "INV-2: DEBT key not debt-derived");
                assertTrue(registry.computeReserveKey(spoke, reserveId) != key, "INV-2: DEBT key is also a supply key");
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                       INV-3: SHARED BINDING
    //////////////////////////////////////////////////////////////*/

    /// @notice When both legs of a reserve are registered they agree on spoke, reserveId, underlying
    ///         and decimals, and differ ONLY in side.
    /// @dev Both legs are written from the same `getReserve` result in one call, so any divergence
    ///      would mean the two legs describe different markets while claiming to be one reserve. The
    ///      oracle derives `getPricePerShare` from the per-key stored decimals, so mismatched decimals
    ///      between legs would price the same asset at two different scales.
    /// forge-config: default.invariant.runs = 32
    /// forge-config: default.invariant.depth = 80
    function invariant_SharedBinding() public view {
        uint256 len = handler.allKeysLength();
        for (uint256 i; i < len; ++i) {
            address key = handler.allKeys(i);
            (,,, address sibling) = handler.keyMeta(key);
            if (!registry.isRegistered(key) || !registry.isRegistered(sibling)) continue;

            (address spokeA, uint256 idA, address underA, uint8 decA, AaveV4ReserveRegistryV2.Side sideA) =
                registry.getReserveInfo(key);
            (address spokeB, uint256 idB, address underB, uint8 decB, AaveV4ReserveRegistryV2.Side sideB) =
                registry.getReserveInfo(sibling);

            assertEq(spokeA, spokeB, "INV-3: sibling legs disagree on spoke");
            assertEq(idA, idB, "INV-3: sibling legs disagree on reserveId");
            assertEq(underA, underB, "INV-3: sibling legs disagree on underlying");
            assertEq(decA, decB, "INV-3: sibling legs disagree on decimals");
            assertTrue(sideA != sideB, "INV-3: sibling legs share the same side");
        }
    }

    /*//////////////////////////////////////////////////////////////
                    INV-4: REGISTRATION ATOMICITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Legs are only ever CREATED in pairs: every registered key was created by a
    ///         `registerReserve` that also created its sibling, so its sibling is either still
    ///         registered or was explicitly deregistered at some point.
    /// @dev `registerReserve` writes both keys or reverts, making a half-registered reserve
    ///      unrepresentable; deregistration is deliberately per key, so a lone surviving leg is legal
    ///      ONLY as the residue of a deregistration. A lone leg with no deregistered sibling would mean
    ///      the registry can mint a key outside the paired write — exactly the state the one-call
    ///      double write exists to prevent.
    /// @dev THE ONE ACTION THAT COULD FALSIFY THIS is `repairLeg`, the only role-gated write creating a
    ///      SINGLE key, and it IS in the handler's selector list. It survives this invariant only because
    ///      it requires the sibling leg to be registered already (reverting `RESERVE_NOT_REGISTERED`
    ///      otherwise), which confines it to COMPLETING a reserve `registerReserve` created — never to
    ///      minting a lone leg. The handler does not mark repaired keys as `ghostEverRegistered`, so if
    ///      `repairLeg` ever created a leg no paired write had created, the first assertion below fails.
    /// forge-config: default.invariant.runs = 32
    /// forge-config: default.invariant.depth = 80
    function invariant_RegistrationAtomicity() public view {
        uint256 len = handler.allKeysLength();
        for (uint256 i; i < len; ++i) {
            address key = handler.allKeys(i);
            if (!registry.isRegistered(key)) continue;
            (,,, address sibling) = handler.keyMeta(key);

            assertTrue(handler.ghostEverRegistered(key), "INV-4: key exists but was never registered");
            assertTrue(handler.ghostEverRegistered(sibling), "INV-4: sibling was never created alongside key");
            assertTrue(
                registry.isRegistered(sibling) || handler.ghostEverDeregistered(sibling),
                "INV-4: lone leg whose sibling was never deregistered"
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                      INV-5: NO ORPHAN PENDING
    //////////////////////////////////////////////////////////////*/

    /// @notice `pendingDeregistrations[key] != 0` implies the key is currently registered, and a
    ///         deregistered key never retains a pending entry.
    /// @dev `executeDeregisterReserve` deletes the pending entry and the reserve in the same call. A
    ///      surviving pending entry on a deregistered key would become live again the moment the
    ///      reserve is re-registered, letting a stale proposal delete a freshly registered reserve with
    ///      no fresh 2-day warning window — the timelock would be silently bypassed.
    /// forge-config: default.invariant.runs = 32
    /// forge-config: default.invariant.depth = 80
    function invariant_NoOrphanPending() public view {
        uint256 len = handler.allKeysLength();
        for (uint256 i; i < len; ++i) {
            address key = handler.allKeys(i);
            if (registry.pendingDeregistrations(key) == 0) continue;
            assertTrue(registry.isRegistered(key), "INV-5: pending deregistration on an unregistered key");
        }
    }

    /*//////////////////////////////////////////////////////////////
                      INV-6: MONOTONIC TIMELOCK
    //////////////////////////////////////////////////////////////*/

    /// @notice Every armed deregistration is at least a full `DEREGISTER_DELAY` — and never less than the
    ///         2-day floor — after the block that armed it, and while it stays pending its `executeAfter`
    ///         never decreases: re-proposing may only extend it.
    /// @dev The 2-day delay is the operator's warning window: anyone watching
    ///      `ReserveDeregistrationProposed` must be able to treat the announced timestamp as a floor. A
    ///      re-proposal that lowered `executeAfter` would let a manager shorten (or retroactively ripen)
    ///      a live proposal, collapsing the window. The handler records the per-key high-water mark and
    ///      resets it on cancel/execute, so the live value must always equal that mark.
    /// @dev WHY THE DELAY IS CHECKED HERE AND NOT ONLY THE MONOTONICITY. The high-water mark is seeded
    ///      from `pendingDeregistrations` — the contract's own output — so on its own it compares the
    ///      contract against itself and accepts ANY delay, zero included. Two mutations survived that
    ///      formulation: arming with no delay at all (`executeAfter = block.timestamp`), and shortening
    ///      `DEREGISTER_DELAY` from 2 days to 1 hour. Both are now caught: the handler records the
    ///      PROPOSING BLOCK's timestamp and the delay is measured from it, against the live constant AND
    ///      against `MIN_DEREGISTER_DELAY`, a 2-day floor restated in the handler independently of the
    ///      contract. The live-constant comparison catches a bad arming; the independent floor is the only
    ///      check that catches the constant itself being reduced.
    /// forge-config: default.invariant.runs = 32
    /// forge-config: default.invariant.depth = 80
    function invariant_MonotonicTimelock() public view {
        assertEq(handler.ghostTimelockRegressions(), 0, "INV-6: a re-proposal shortened a live timelock");
        assertEq(
            handler.ghostShortDelays(),
            0,
            "INV-6: a proposal armed less than a full DEREGISTER_DELAY after its own block"
        );
        assertEq(
            handler.ghostFloorBreaches(), 0, "INV-6: a proposal armed less than the 2-day floor after its own block"
        );
        assertGe(
            registry.DEREGISTER_DELAY(),
            handler.MIN_DEREGISTER_DELAY(),
            "INV-6: DEREGISTER_DELAY fell below the 2-day warning window"
        );

        uint256 len = handler.allKeysLength();
        for (uint256 i; i < len; ++i) {
            address key = handler.allKeys(i);
            uint256 live = registry.pendingDeregistrations(key);
            if (live == 0) continue;
            assertEq(live, handler.ghostPendingHighWater(key), "INV-6: pending executeAfter below its high-water mark");

            uint256 proposedAt = handler.ghostProposedAt(key);
            assertTrue(proposedAt != 0, "INV-6: a pending entry exists that no recorded proposal armed");
            assertGe(
                live,
                proposedAt + registry.DEREGISTER_DELAY(),
                "INV-6: armed executeAfter is less than DEREGISTER_DELAY after the proposing block"
            );
            assertGe(
                live,
                proposedAt + handler.MIN_DEREGISTER_DELAY(),
                "INV-6: armed executeAfter is less than 2 days after the proposing block"
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                   INV-7: ORACLE READ CONSISTENCY
    //////////////////////////////////////////////////////////////*/

    /// @notice The oracle's behaviour is fully determined by registry state: for every registered key
    ///         `getPricePerShare` returns `10 ** decimals` and never reverts, and for every
    ///         unregistered key every registry-resolving view reverts.
    /// @dev The oracle holds no state of its own, so the registry is its single source of truth. A
    ///      registered key that made a read revert would brick NAV/TVL and SuperLedger outflow
    ///      accounting; an unregistered key that returned a value instead of reverting would silently
    ///      price a market nobody vetted — the documented contract is "never a zero return".
    /// forge-config: default.invariant.runs = 32
    /// forge-config: default.invariant.depth = 80
    function invariant_OracleReadConsistency() public view {
        uint256 len = handler.allKeysLength();
        for (uint256 i; i < len; ++i) {
            address key = handler.allKeys(i);

            if (registry.isRegistered(key)) {
                (,,, uint8 dec,) = registry.getReserveInfo(key);
                assertEq(oracle.decimals(key), dec, "INV-7: oracle decimals differ from registry binding");

                try oracle.getPricePerShare(key) returns (uint256 pps) {
                    assertEq(pps, 10 ** uint256(dec), "INV-7: PPS is not 10 ** decimals for a registered key");
                } catch {
                    assertTrue(false, "INV-7: getPricePerShare reverted for a registered key");
                }

                try oracle.getBalanceOfOwner(key, OWNER) returns (uint256) { }
                catch {
                    assertTrue(false, "INV-7: getBalanceOfOwner reverted for a registered key");
                }

                try oracle.getTVL(key) returns (uint256) { }
                catch {
                    assertTrue(false, "INV-7: getTVL reverted for a registered key");
                }
            } else {
                try oracle.getPricePerShare(key) returns (uint256) {
                    assertTrue(false, "INV-7: getPricePerShare resolved an unregistered key");
                } catch { }

                try oracle.decimals(key) returns (uint8) {
                    assertTrue(false, "INV-7: decimals resolved an unregistered key");
                } catch { }

                try oracle.getBalanceOfOwner(key, OWNER) returns (uint256) {
                    assertTrue(false, "INV-7: getBalanceOfOwner resolved an unregistered key");
                } catch { }

                try oracle.getTVL(key) returns (uint256) {
                    assertTrue(false, "INV-7: getTVL resolved an unregistered key");
                } catch { }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                      INV-8: KEYS NEVER COLLIDE
    //////////////////////////////////////////////////////////////*/

    /// @notice No two distinct `(spoke, reserveId, side)` triples in the tracked universe map to the
    ///         same key, across all 48 keys (24 reserves x 2 legs, 4 spokes x 6 reserve ids).
    /// @dev Key uniqueness is what makes the pseudo-address a name. A collision between two triples
    ///      would make the second reserve unregisterable (the benign case the contract documents) or,
    ///      worse, let one reserve's reads resolve through another's binding. In particular this pins
    ///      that the two-word SUPPLY preimage and the three-word `DEBT_KEY_DOMAIN` DEBT preimage never
    ///      coincide for any pair in the universe — including `reserveId = 0`, where a naive
    ///      concatenation-style derivation would be most at risk.
    /// forge-config: default.invariant.runs = 32
    /// forge-config: default.invariant.depth = 80
    function invariant_KeysNeverCollide() public view {
        uint256 len = handler.allKeysLength();
        for (uint256 i; i < len; ++i) {
            address keyI = handler.allKeys(i);
            (address spokeI, uint256 idI, AaveV4ReserveRegistryV2.Side sideI,) = handler.keyMeta(keyI);

            address rederivedI = sideI == AaveV4ReserveRegistryV2.Side.SUPPLY
                ? registry.computeReserveKey(spokeI, idI)
                : registry.computeDebtKey(spokeI, idI);
            assertEq(rederivedI, keyI, "INV-8: universe key no longer derives from its triple");

            for (uint256 j = i + 1; j < len; ++j) {
                assertTrue(keyI != handler.allKeys(j), "INV-8: two distinct triples derive the same key");
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                      INV-9: ROLE CHURN SAFETY
    //////////////////////////////////////////////////////////////*/

    /// @notice Registry DATA only ever changes through authorised actions: the live registered-key set
    ///         and count match the handler's ghost expectation exactly, and no call from a caller
    ///         lacking MARKET_MANAGER_ROLE ever mutated state.
    /// @dev Manager-role grants and revokes churn continuously during the campaign, so this pins that
    ///      authorisation is checked at CALL time and that losing the role cannot leave a half-applied
    ///      mutation behind. The ghost count is maintained only on observed successes, so any state
    ///      change the campaign did not authorise — or any authorised call that silently failed to
    ///      apply — desynchronises it.
    /// forge-config: default.invariant.runs = 32
    /// forge-config: default.invariant.depth = 80
    function invariant_RoleChurnSafety() public view {
        assertEq(handler.ghostUnauthorisedSuccesses(), 0, "INV-9: unauthorised caller mutated registry data");
        assertEq(handler.ghostUnexpectedSuccesses(), 0, "INV-9: a call succeeded that should have reverted");
        assertEq(handler.ghostUnexpectedReverts(), 0, "INV-9: a call reverted that should have succeeded");

        uint256 len = handler.allKeysLength();
        uint256 liveCount;
        for (uint256 i; i < len; ++i) {
            address key = handler.allKeys(i);
            bool live = registry.isRegistered(key);
            assertEq(live, handler.ghostRegistered(key), "INV-9: live registration differs from ghost expectation");
            if (live) ++liveCount;
        }
        assertEq(liveCount, handler.ghostRegisteredCount(), "INV-9: registered-key count drifted from ghost count");
    }

    /*//////////////////////////////////////////////////////////////
                  INV-10: repairLeg ONLY COMPLETES A PAIR
    //////////////////////////////////////////////////////////////*/

    /// @notice `repairLeg` can only ever restore the MISSING leg of a reserve whose sibling leg is already
    ///         registered: every key it ever created had been written before by a paired `registerReserve`
    ///         and then explicitly deregistered, its sibling was live at repair time, and the key it
    ///         returns is exactly the one its own `(spoke, reserveId, side)` triple derives to.
    /// @dev This pins the ALLOWED CREATION SET of the registry's only single-key write. `registerReserve`
    ///      guards per RESERVE (it rejects if either leg is present) while deregistration deletes per KEY,
    ///      so the two are not inverses and a repair path has to exist. The danger is that the repair path
    ///      becomes a second way to CREATE a reserve: a lone leg minted on a never-registered reserve is
    ///      the half-registered state the contract documents as unrepresentable, and it would also wedge
    ///      the reserve permanently, because `registerReserve`'s two-key guard then rejects the normal path
    ///      forever. The sibling-registered precondition is what prevents it, and these are the terms:
    ///      `ghostLoneLegMints` counts any success whose sibling was absent, and the per-key assertions
    ///      restate it from live ghost history rather than from the counter alone.
    /// forge-config: default.invariant.runs = 32
    /// forge-config: default.invariant.depth = 80
    function invariant_RepairOnlyCompletesAPair() public view {
        assertEq(handler.ghostLoneLegMints(), 0, "INV-10: repairLeg minted a leg whose sibling was not registered");
        assertEq(
            handler.ghostRepairKeyMismatches(),
            0,
            "INV-10: repairLeg returned a key its own (spoke, reserveId, side) triple does not derive to"
        );

        uint256 len = handler.allKeysLength();
        for (uint256 i; i < len; ++i) {
            address key = handler.allKeys(i);
            if (!handler.ghostEverRepaired(key)) continue;
            (,,, address sibling) = handler.keyMeta(key);

            assertTrue(
                handler.ghostEverRegistered(key), "INV-10: repairLeg created a leg no registerReserve ever created"
            );
            assertTrue(
                handler.ghostEverRegistered(sibling), "INV-10: repaired leg's sibling was never created by a pair"
            );
            assertTrue(
                handler.ghostEverDeregistered(key), "INV-10: repairLeg created a leg that was never deregistered"
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
       INV-12: EVERY LIVE MARKET'S TWO CLAIMED LEGS ARE REGISTERED
    //////////////////////////////////////////////////////////////*/

    /// @notice For every registered market, the collateral reserve's SUPPLY leg and the loan reserve's DEBT
    ///         leg are BOTH still registered. This is what guarantees a whitelisted market is always
    ///         valuable: those two keys are exactly what a consumer reads to price it.
    /// @dev `registerMarket` enforces it at registration; `marketRefs` is what keeps it true afterwards, by
    ///      refusing to deregister a claimed leg. The campaign churns leg deregistration freely, so if
    ///      `marketRefs` ever failed to protect the right two legs, this is where it shows up — a market
    ///      whose NAV silently went dark.
    function invariant_12_everyMarketKeepsBothClaimedLegsRegistered() public view {
        uint256 count = handler.allMarketKeysLength();
        for (uint256 i; i < count; ++i) {
            address marketKey = handler.allMarketKeys(i);
            if (!registry.isMarketRegistered(marketKey)) continue;

            (address spoke, uint256 supplyId, uint256 borrowId,,) = registry.getMarketInfo(marketKey);
            assertTrue(
                registry.isRegistered(registry.computeReserveKey(spoke, supplyId)),
                "INV-12: a live market's collateral SUPPLY leg must stay registered"
            );
            assertTrue(
                registry.isRegistered(registry.computeDebtKey(spoke, borrowId)),
                "INV-12: a live market's loan DEBT leg must stay registered"
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
       INV-13: NO KEY IS EVER LIVE IN BOTH NAMESPACES
    //////////////////////////////////////////////////////////////*/

    /// @notice No 20-byte value is simultaneously a registered reserve leg and a registered market. The two
    ///         namespaces must stay disjoint or one key would mean a position to the oracle and a market to an
    ///         off-chain whitelist at the same time.
    /// @dev Swept in both directions over the whole universe: every reserve leg the campaign can create and
    ///      every market key it has registered. Under the real derivations a collision is ~2^-160, so this
    ///      invariant is really a guard against a future edit that makes the two mappings share a key by
    ///      construction (e.g. a market key derived without its domain separator).
    function invariant_13_noKeyIsLiveInBothNamespaces() public view {
        uint256 keyCount = handler.allKeysLength();
        for (uint256 i; i < keyCount; ++i) {
            address reserveKey = handler.allKeys(i);
            if (!registry.isRegistered(reserveKey)) continue;
            assertFalse(registry.isMarketRegistered(reserveKey), "INV-13: a live reserve leg must not also be a market");
        }

        uint256 marketCount = handler.allMarketKeysLength();
        for (uint256 i; i < marketCount; ++i) {
            address marketKey = handler.allMarketKeys(i);
            if (!registry.isMarketRegistered(marketKey)) continue;
            assertFalse(registry.isRegistered(marketKey), "INV-13: a live market must not also be a reserve leg");
        }
    }

    /*//////////////////////////////////////////////////////////////
       INV-14: marketRefs EQUALS THE NUMBER OF MARKETS CLAIMING A LEG
    //////////////////////////////////////////////////////////////*/

    /// @notice `marketRefs[leg]` equals, exactly, the number of currently registered markets that claim that
    ///         leg — recounted from scratch here rather than tracked incrementally, so a drifted counter
    ///         cannot hide behind the same bookkeeping that produced it.
    /// @dev The counter is the whole basis of the deregistration guard: too low and a claimed leg can be
    ///      removed under a live market (INV-12 goes red), too high and a leg is permanently unremovable.
    ///      On the live MAG7 spoke seven markets share one USDC debt leg, so the shared-leg case this checks
    ///      is the production shape, not a corner case.
    function invariant_14_marketRefsEqualsTheClaimCount() public view {
        uint256 keyCount = handler.allKeysLength();
        uint256 marketCount = handler.allMarketKeysLength();

        for (uint256 i; i < keyCount; ++i) {
            address leg = handler.allKeys(i);
            uint256 expected;

            for (uint256 j; j < marketCount; ++j) {
                address marketKey = handler.allMarketKeys(j);
                if (!registry.isMarketRegistered(marketKey)) continue;
                (address spoke, uint256 supplyId, uint256 borrowId,,) = registry.getMarketInfo(marketKey);
                if (
                    leg == registry.computeReserveKey(spoke, supplyId)
                        || leg == registry.computeDebtKey(spoke, borrowId)
                ) {
                    ++expected;
                }
            }

            assertEq(registry.marketRefs(leg), expected, "INV-14: marketRefs must equal the live claim count");
        }
    }

    /*//////////////////////////////////////////////////////////////
       INV-15: A CLAIMED LEG NEVER HAS A PENDING DEREGISTRATION
    //////////////////////////////////////////////////////////////*/

    /// @notice No leg is ever both claimed by a market and pending deregistration. The two guards
    ///         (`MARKET_REFERENCES_RESERVE` on propose, `RESERVE_DEREGISTRATION_PENDING` on registerMarket)
    ///         close that state from both sides, which is what stops a proposal from sitting un-executable
    ///         behind `marketRefs` and then firing with no warning window once the market is removed.
    function invariant_15_noClaimedLegHasAPendingProposal() public view {
        uint256 keyCount = handler.allKeysLength();
        for (uint256 i; i < keyCount; ++i) {
            address leg = handler.allKeys(i);
            if (registry.marketRefs(leg) == 0) continue;
            assertEq(registry.pendingDeregistrations(leg), 0, "INV-15: a claimed leg must have no pending proposal");
        }
    }
}
