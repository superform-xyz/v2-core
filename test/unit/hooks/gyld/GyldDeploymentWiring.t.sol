// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { DeployV2OtherHooks } from "../../../../script/DeployV2OtherHooks.s.sol";
import { GyldBondRegistry } from "../../../../src/accounting/oracles/GyldBondRegistry.sol";
import { GyldBondYieldSourceOracle } from "../../../../src/accounting/oracles/GyldBondYieldSourceOracle.sol";
import { GyldTradeGuardHook } from "../../../../src/hooks/swappers/gyld/GyldTradeGuardHook.sol";
import { ApproveAndTradeGyldBondHook } from "../../../../src/hooks/swappers/gyld/ApproveAndTradeGyldBondHook.sol";
import { GyldTradePolicy } from "../../../../src/accounting/oracles/GyldTradePolicy.sol";
import { IGyldTradePolicy } from "../../../../src/interfaces/accounting/IGyldTradePolicy.sol";

/// @notice Exposes the deploy script's Gyld path and its configuration so the WIRING can be exercised,
///         not a copy of it.
contract GyldWiringHarness is DeployV2OtherHooks {
    function loadConfiguration(uint256 env) external {
        _setConfiguration(env, "");
    }

    function deployGyld(uint64 chainId, uint256 env) external returns (GyldHookAddresses memory) {
        return _deployGyldHooks(chainId, env, true);
    }

    function ledgerConfigAddress(uint256 env) external view returns (address) {
        return __computeContractAddress(SUPER_LEDGER_CONFIGURATION_KEY, "", env);
    }

    /*//////////////////////////////////////////////////////////////
                    CONFIGURATION READERS AND WRITERS
    //////////////////////////////////////////////////////////////*/

    function oracleEnabled(uint64 chainId) external view returns (bool) {
        return otherHooksConfiguration.gyldOracleEnabled[chainId];
    }

    function settlement(uint64 chainId) external view returns (address) {
        return otherHooksConfiguration.gyldSettlements[chainId];
    }

    function cashCap(uint64 chainId) external view returns (uint256) {
        return otherHooksConfiguration.gyldMaxCashInputAmounts[chainId];
    }

    function bondCap(uint64 chainId) external view returns (uint256) {
        return otherHooksConfiguration.gyldMaxBondInputAmounts[chainId];
    }

    /// @dev Lets a test enable the family the way a future config change would, so the deploy path's own
    ///      guards are exercised against a populated table rather than described in a comment.
    function enableFamily(uint64 chainId, address settlement_, uint256 cashCap_, uint256 bondCap_) external {
        otherHooksConfiguration.gyldOracleEnabled[chainId] = true;
        otherHooksConfiguration.gyldSettlements[chainId] = settlement_;
        otherHooksConfiguration.gyldMaxCashInputAmounts[chainId] = cashCap_;
        otherHooksConfiguration.gyldMaxBondInputAmounts[chainId] = bondCap_;
    }

    /// @dev The valuation half alone: enabled, no venue, no caps.
    function enableOracleOnly(uint64 chainId) external {
        otherHooksConfiguration.gyldOracleEnabled[chainId] = true;
    }

    function setAggregator(uint64 chainId, address aggregator_) external {
        otherHooksConfiguration.superVaultAggregators[chainId] = aggregator_;
    }

    function saltFor(string memory key) external view returns (bytes32) {
        return __getSalt(key);
    }

    function registryKey() external pure returns (string memory) {
        return GYLD_BOND_REGISTRY_KEY;
    }

    function oracleKey() external pure returns (string memory) {
        return GYLD_BOND_YIELD_SOURCE_ORACLE_KEY;
    }

    function guardKey() external pure returns (string memory) {
        return GYLD_TRADE_GUARD_HOOK_KEY;
    }

    function cashInKey() external pure returns (string memory) {
        return APPROVE_AND_TRADE_GYLD_BOND_CASH_IN_HOOK_KEY;
    }

    function bondInKey() external pure returns (string memory) {
        return APPROVE_AND_TRADE_GYLD_BOND_BOND_IN_HOOK_KEY;
    }

    function deployer() external view returns (address) {
        return DEPLOYER;
    }

    /// @dev The shipping constants are `internal`, so expose them rather than re-declaring their values
    ///      here: a test asserting its own copy of a constant proves nothing.
    function cashCapConstant() external pure returns (uint256) {
        return GYLD_MAX_CASH_INPUT_AMOUNT_KATANA;
    }

    function bondCapConstant() external pure returns (uint256) {
        return GYLD_MAX_BOND_INPUT_AMOUNT_KATANA;
    }

    function cashTokenConstant() external pure returns (address) {
        return GYLD_CASH_TOKEN_KATANA;
    }

    function katanaChainId() external pure returns (uint64) {
        return KATANA_CHAIN_ID;
    }
}

/// @title GyldDeploymentWiringTest
/// @notice Asserts what the Gyld deploy path actually wires, and that it refuses the configurations that
///         would silently produce a broken deployment.
/// @dev The reason this suite exists: three of the four contracts take another of them as a constructor
///      argument, so a mis-wired deploy produces contracts that compile, deploy, and then revert on every
///      operation. None of the behavioural suites would notice.
contract GyldDeploymentWiringTest is Test {
    GyldWiringHarness internal h;

    uint64 internal constant KATANA = 747_474;
    uint64 internal constant MAINNET = 1;
    uint64 internal constant HYPEREVM = 999;
    uint64 internal constant BNB = 56;
    uint256 internal constant ENV_PROD = 0;

    address internal constant VENUE = address(0xBEEF);
    uint256 internal constant CASH_CAP = 500_000e6;
    uint256 internal constant BOND_CAP = 500_000e18;

    function setUp() public {
        h = new GyldWiringHarness();
        h.loadConfiguration(ENV_PROD);
    }

    /*//////////////////////////////////////////////////////////////
              THE FAMILY SHIPS NOWHERE UNTIL SOMEONE SAYS SO
    //////////////////////////////////////////////////////////////*/

    /// @dev Gyld's settlement contract and NAV feed are deployed nowhere, and three high-severity review
    ///      findings are open, so a routine deploy run must ship none of this. If someone enables a chain,
    ///      this test fails and they have to update it deliberately, which is the point.
    function test_FamilyIsDisabledOnEveryChain() public view {
        // Every chain in networks-production.sh, not a sample: the point of this test is that enabling ANY
        // chain fails it, and a 5-chain sample left 13 chains able to be enabled silently.
        uint64[18] memory chains = [
            KATANA,
            MAINNET,
            uint64(8453), // Base
            uint64(10), // Optimism
            uint64(56), // BNB
            uint64(42_161), // Arbitrum
            uint64(137), // Polygon
            uint64(43_114), // Avalanche
            uint64(130), // Unichain
            uint64(59_144), // Linea
            uint64(80_094), // Berachain
            uint64(146), // Sonic
            uint64(100), // Gnosis
            uint64(480), // Worldchain
            HYPEREVM,
            uint64(14), // Flare
            uint64(988), // Stable
            uint64(4663) // Robinhood
        ];
        for (uint256 i; i < chains.length; ++i) {
            assertFalse(h.oracleEnabled(chains[i]), "valuation half must be disabled");
            assertEq(h.settlement(chains[i]), address(0), "no venue address may be configured yet");
            assertEq(h.cashCap(chains[i]), 0, "no cash cap may be configured yet");
            assertEq(h.bondCap(chains[i]), 0, "no bond cap may be configured yet");
        }
    }

    /*//////////////////////////////////////////////////////////////
                      THE DEPENDENCY CHAIN, AS DEPLOYED
    //////////////////////////////////////////////////////////////*/

    /// @dev The whole point of the family's deploy function: each contract must be pinned to the ONE the
    ///      script just deployed, read back from the live contracts rather than from the script's return
    ///      struct. A chain wired to a stale or derived address would deploy fine and revert on every op.
    function test_DeployPath_WiresTheDependencyChain() public {
        _etchLedgerConfig();
        h.enableFamily(KATANA, VENUE, CASH_CAP, BOND_CAP);

        DeployV2OtherHooks.GyldHookAddresses memory a = h.deployGyld(KATANA, ENV_PROD);

        assertTrue(a.gyldBondRegistry != address(0), "registry deployed");
        assertTrue(a.gyldBondYieldSourceOracle != address(0), "oracle deployed");
        assertTrue(a.gyldTradeGuardHook != address(0), "guard deployed");

        // The oracle points at the registry this run deployed.
        assertEq(
            address(GyldBondYieldSourceOracle(a.gyldBondYieldSourceOracle).REGISTRY()),
            a.gyldBondRegistry,
            "oracle must bind THIS registry"
        );
        // The guard points at that oracle.
        assertEq(
            address(GyldTradeGuardHook(a.gyldTradeGuardHook).GYLD_ORACLE()),
            a.gyldBondYieldSourceOracle,
            "guard must bind THIS oracle"
        );
        // Both trade instances point at the configured venue. They bind NO registry: tradability is
        // enforced by the guard, so the trade hooks read no instrument configuration at all.
        assertEq(ApproveAndTradeGyldBondHook(a.approveAndTradeGyldBondCashInHook).GYLD_SETTLEMENT(), VENUE);
        assertEq(ApproveAndTradeGyldBondHook(a.approveAndTradeGyldBondBondInHook).GYLD_SETTLEMENT(), VENUE);
    }

    /// @dev The oracle must be pinned to the SuperLedgerConfiguration that DeployV2Core deployed, derived
    ///      from the same CREATE2 inputs rather than configured, so it cannot drift from the live one.
    function test_DeployPath_OracleBindsTheDerivedLedgerConfiguration() public {
        address ledgerConfig = _etchLedgerConfig();
        h.enableFamily(KATANA, VENUE, CASH_CAP, BOND_CAP);

        DeployV2OtherHooks.GyldHookAddresses memory a = h.deployGyld(KATANA, ENV_PROD);
        assertEq(
            GyldBondYieldSourceOracle(a.gyldBondYieldSourceOracle).SUPER_LEDGER_CONFIGURATION(),
            ledgerConfig,
            "oracle must bind the derived ledger configuration"
        );
    }

    /// @dev The registry is born with DEPLOYER as admin and holds nothing, so it is inert until governance
    ///      registers an instrument. `TransferGyldBondRegistryRoles` is what hands it over.
    function test_DeployPath_RegistryIsBornAdminedByDeployerAndEmpty() public {
        _etchLedgerConfig();
        h.enableFamily(KATANA, VENUE, CASH_CAP, BOND_CAP);

        DeployV2OtherHooks.GyldHookAddresses memory a = h.deployGyld(KATANA, ENV_PROD);
        GyldBondRegistry registry = GyldBondRegistry(a.gyldBondRegistry);

        assertTrue(registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), h.deployer()), "DEPLOYER is admin");
        assertTrue(registry.hasRole(registry.INSTRUMENT_MANAGER_ROLE(), h.deployer()), "DEPLOYER is manager");
        assertFalse(registry.isRegistered(address(0xCAFE)), "no instrument is registered at birth");
    }

    /*//////////////////////////////////////////////////////////////
                  TWO INSTANCES, ONE PER DIRECTION
    //////////////////////////////////////////////////////////////*/

    /// @dev The two trade instances must be DISTINCT contracts with DIFFERENT caps. A single instance cannot
    ///      serve both directions of a pair whose decimals differ, because the cap is in raw input-token
    ///      units. A collision would silently give the sell leg the buy leg's cap.
    function test_DeployPath_TwoDistinctTradeInstancesWithTheirOwnCaps() public {
        _etchLedgerConfig();
        h.enableFamily(KATANA, VENUE, CASH_CAP, BOND_CAP);

        DeployV2OtherHooks.GyldHookAddresses memory a = h.deployGyld(KATANA, ENV_PROD);
        assertTrue(
            a.approveAndTradeGyldBondCashInHook != a.approveAndTradeGyldBondBondInHook,
            "distinct keys must yield distinct addresses"
        );
        assertEq(
            ApproveAndTradeGyldBondHook(a.approveAndTradeGyldBondCashInHook).MAX_INPUT_AMOUNT(),
            CASH_CAP,
            "the buy leg's cap is in cash units"
        );
        assertEq(
            ApproveAndTradeGyldBondHook(a.approveAndTradeGyldBondBondInHook).MAX_INPUT_AMOUNT(),
            BOND_CAP,
            "the sell leg's cap is in bond units"
        );
    }

    /// @dev Distinct keys are what make the two addresses distinct, so pin the salts apart directly too.
    function test_Keys_YieldDistinctSalts() public view {
        // Read through the harness accessors, NOT string literals: hashing two literals always yields two
        // distinct salts, so a literal-based version of this test cannot fail and says nothing about the
        // keys the deploy actually uses.
        bytes32 cashSalt = h.saltFor(h.cashInKey());
        bytes32 bondSalt = h.saltFor(h.bondInKey());
        assertTrue(cashSalt != bondSalt, "one salt for both directions would collapse them");

        // And the three singletons must not collide with each other either.
        bytes32 registrySalt = h.saltFor(h.registryKey());
        bytes32 oracleSalt = h.saltFor(h.oracleKey());
        bytes32 guardSalt = h.saltFor(h.guardKey());
        assertTrue(registrySalt != oracleSalt && oracleSalt != guardSalt && registrySalt != guardSalt);
    }

    /*//////////////////////////////////////////////////////////////
                    THE CONFIGURATIONS IT MUST REFUSE
    //////////////////////////////////////////////////////////////*/

    /// @dev An oracle pinned to a codeless ledger configuration would deploy and then be unusable, so the
    ///      deploy fails loudly instead. This is also what makes the run order explicit.
    function test_Refuses_LedgerConfigurationNotDeployed() public {
        h.enableFamily(KATANA, VENUE, CASH_CAP, BOND_CAP);
        vm.expectRevert(bytes("SUPER_LEDGER_CONFIGURATION_NOT_DEPLOYED: run DeployV2Core first"));
        h.deployGyld(KATANA, ENV_PROD);
    }

    /// @dev Two equal caps are almost certainly one value copied twice, which makes one direction unusable
    ///      or its cap vacuous by a factor of 1e12. Refused rather than deployed.
    function test_Refuses_IdenticalCaps() public {
        _etchLedgerConfig();
        h.enableFamily(KATANA, VENUE, CASH_CAP, CASH_CAP);
        vm.expectRevert(bytes("GYLD_CAPS_IDENTICAL: each direction's cap is in ITS OWN input token"));
        h.deployGyld(KATANA, ENV_PROD);
    }

    function test_Refuses_ZeroCashCap() public {
        _etchLedgerConfig();
        h.enableFamily(KATANA, VENUE, 0, BOND_CAP);
        vm.expectRevert(bytes("GYLD_CASH_CAP_NOT_CONFIGURED"));
        h.deployGyld(KATANA, ENV_PROD);
    }

    function test_Refuses_ZeroBondCap() public {
        _etchLedgerConfig();
        h.enableFamily(KATANA, VENUE, CASH_CAP, 0);
        vm.expectRevert(bytes("GYLD_BOND_CAP_NOT_CONFIGURED"));
        h.deployGyld(KATANA, ENV_PROD);
    }

    /*//////////////////////////////////////////////////////////////
                 THE VALUATION HALF SHIPS WITHOUT A VENUE
    //////////////////////////////////////////////////////////////*/

    /// @dev Gyld's settlement address does not exist yet, so the registry, oracle and guard must be
    ///      deployable without it. All three are inert until an instrument is registered.
    function test_ValuationHalfDeploysWithoutASettlementAddress() public {
        _etchLedgerConfig();
        // Enabled, but no venue and no caps: exactly the state the config comment describes.
        h.enableOracleOnly(KATANA);
        DeployV2OtherHooks.GyldHookAddresses memory a = h.deployGyld(KATANA, ENV_PROD);

        assertTrue(a.gyldBondRegistry != address(0), "registry ships");
        assertTrue(a.gyldBondYieldSourceOracle != address(0), "oracle ships");
        assertTrue(a.gyldTradeGuardHook != address(0), "guard ships");
        assertEq(a.approveAndTradeGyldBondCashInHook, address(0), "no buy hook without a venue");
        assertEq(a.approveAndTradeGyldBondBondInHook, address(0), "no sell hook without a venue");
    }

    /*//////////////////////////////////////////////////////////////
                      THE PER-CHAIN GATE IS NOT BYPASSABLE
    //////////////////////////////////////////////////////////////*/

    /// @dev THE FOOTGUN THIS CLOSES. A targeted family run executes on EVERY configured network, so an
    ///      entrypoint that ignored the per-chain enable would ship the registry, oracle and guard to every
    ///      chain in the networks file the moment anyone ran TARGET_FAMILY=Gyld. The gate lives in the
    ///      worker, so the generic path and the targeted entrypoint cannot diverge.
    function test_DeployPath_SkipsAChainThatIsNotEnabled() public {
        _etchLedgerConfig();
        // Not enabled: no venue, no caps, no flag. Nothing must be deployed, and nothing must revert.
        DeployV2OtherHooks.GyldHookAddresses memory a = h.deployGyld(MAINNET, ENV_PROD);

        assertEq(a.gyldBondRegistry, address(0), "no registry on an unenabled chain");
        assertEq(a.gyldBondYieldSourceOracle, address(0), "no oracle on an unenabled chain");
        assertEq(a.gyldTradeGuardHook, address(0), "no guard on an unenabled chain");
        assertEq(a.approveAndTradeGyldBondCashInHook, address(0));
        assertEq(a.approveAndTradeGyldBondBondInHook, address(0));
    }

    /// @dev And the gate is checked BEFORE the ledger-configuration guard, so an unenabled chain is a quiet
    ///      skip rather than a revert on a chain that was never meant to ship this.
    function test_DeployPath_UnenabledChainSkipsEvenWithoutALedgerConfiguration() public {
        DeployV2OtherHooks.GyldHookAddresses memory a = h.deployGyld(MAINNET, ENV_PROD);
        assertEq(a.gyldBondRegistry, address(0), "quiet skip, not a revert");
    }

    /*//////////////////////////////////////////////////////////////
          THE MANIFEST MUST KEY ON THE DEPLOY KEYS, NOT THE CONTRACT
    //////////////////////////////////////////////////////////////*/

    /// @dev REGRESSION. The manifest resolves a hook's deployed address by its REGISTRATION KEY. The trade
    ///      hook ships twice under two keys, so a manifest entry under the CONTRACT name would look up an
    ///      address that is never registered: both instances would read as undeployed forever, and the OMS
    ///      could not resolve either. The `instances` table in hook-enrichment.yaml is what splits them,
    ///      and this asserts the result rather than the intent. Same mechanism the HyperCore deposit hook
    ///      already relies on.
    function test_Manifest_HasAnEntryPerDeployKey() public view {
        string memory manifest = vm.readFile("manifests/hooks.json");

        // One entry per deploy key, including both trade directions.
        assertTrue(vm.keyExistsJson(manifest, ".hooks.GyldTradeGuardHook"), "guard entry");
        assertTrue(vm.keyExistsJson(manifest, ".hooks.ApproveAndTradeGyldBondCashInHook"), "buy-leg entry keyed by key");
        assertTrue(
            vm.keyExistsJson(manifest, ".hooks.ApproveAndTradeGyldBondBondInHook"), "sell-leg entry keyed by key"
        );
        // And NOT under the contract name, which would resolve no address.
        assertFalse(
            vm.keyExistsJson(manifest, ".hooks.ApproveAndTradeGyldBondHook"),
            "a contract-name entry would never resolve an address"
        );
    }

    /// @dev The manifest keys must be exactly the deploy keys. A rename on either side breaks address
    ///      resolution silently, so pin them against the script's own constants.
    function test_Manifest_KeysMatchTheDeployKeys() public view {
        string memory manifest = vm.readFile("manifests/hooks.json");
        string[3] memory keys = [h.guardKey(), h.cashInKey(), h.bondInKey()];
        for (uint256 i; i < keys.length; ++i) {
            assertTrue(
                vm.keyExistsJson(manifest, string.concat(".hooks.", keys[i])),
                string.concat("manifest is missing deploy key ", keys[i])
            );
        }
    }

    /// @dev Both trade instances must advertise a resolution tag, which is how a caller picks a direction.
    function test_Manifest_BothTradeInstancesCarryADirectionTag() public view {
        string memory manifest = vm.readFile("manifests/hooks.json");
        assertEq(vm.parseJsonString(manifest, ".hooks.ApproveAndTradeGyldBondCashInHook.tag"), "cash-in", "buy leg tag");
        assertEq(
            vm.parseJsonString(manifest, ".hooks.ApproveAndTradeGyldBondBondInHook.tag"), "bond-in", "sell leg tag"
        );
    }

    /*//////////////////////////////////////////////////////////////
                         CAP MAGNITUDE SANITY
    //////////////////////////////////////////////////////////////*/

    /// @dev The two shipping cap constants must be scaled to the decimals of the token each is denominated
    ///      in: vbUSDC has 6, the bond has 18. A constant at the wrong scale is the mistake the pair of
    ///      caps exists to prevent, and it would not revert anything.
    function test_CapConstants_MatchTheirTokenDecimals() public view {
        assertEq(h.cashCapConstant(), 500_000 * 10 ** 6, "cash cap is 6-decimal scaled");
        assertEq(h.bondCapConstant(), 500_000 * 10 ** 18, "bond cap is 18-decimal scaled");
        assertEq(
            h.bondCapConstant() / h.cashCapConstant(),
            10 ** 12,
            "the two caps are the same WHOLE-unit size, differing only by the decimal gap"
        );
    }

    /// @dev The documented cash token is the one the cash cap is scaled for. Pinned so a change to one
    ///      without the other is caught here rather than in production.
    function test_CashTokenConstant_IsKatanaVbUsdc() public view {
        assertEq(h.cashTokenConstant(), 0x203A662b0BD271A6ed5a60EdFbd04bFce608FD36);
    }

    /// @dev And the chain id the whole family is scoped to.
    function test_KatanaChainIdConstant() public view {
        assertEq(h.katanaChainId(), KATANA, "Katana is chain 747474");
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Puts code at the ledger configuration's derived CREATE2 address so the deploy path's existence
    ///      guard passes without running DeployV2Core. Any non-empty code satisfies it; the oracle only
    ///      stores the address. Also gives the placeholder venue code, because the deploy path requires the
    ///      settlement address to be a contract: a test using a codeless venue would have been asserting a
    ///      deployment the script now refuses.
    function _etchLedgerConfig() internal returns (address ledgerConfig) {
        ledgerConfig = h.ledgerConfigAddress(ENV_PROD);
        vm.etch(ledgerConfig, hex"600160005260206000f3");
        vm.etch(VENUE, hex"600160005260206000f3");
        // The deploy refuses a CONFIGURED but codeless aggregator, because a codeless `getPPS` returns
        // undecodable data and would make every trade revert namelessly. Give the configured addresses
        // code so these tests exercise the real path rather than that guard.
        vm.etch(KATANA_AGGREGATOR, hex"600160005260206000f3");
        vm.etch(address(0xA66), hex"600160005260206000f3");
        vm.etch(address(0xB77), hex"600160005260206000f3");
    }

    /// @dev The venue code check is itself worth pinning: an EOA or a typo'd address would otherwise be
    ///      burned into two permanent immutables.
    function test_Refuses_CodelessSettlementAddress() public {
        _etchLedgerConfig();
        h.enableFamily(KATANA, address(0xD15EA5E), CASH_CAP, BOND_CAP); // never given code
        vm.expectRevert(bytes("GYLD_SETTLEMENT_NOT_DEPLOYED"));
        h.deployGyld(KATANA, ENV_PROD);
    }

    /// @dev And the swapped-caps guard, which catches the mistake the non-zero and distinct checks cannot:
    ///      the two config entries are adjacent and near-identically named.
    function test_Refuses_SwappedCaps() public {
        _etchLedgerConfig();
        h.enableFamily(KATANA, VENUE, BOND_CAP, CASH_CAP); // cash slot holds the bond-scaled number
        vm.expectRevert(bytes("GYLD_CAPS_LOOK_SWAPPED: the bond cap must exceed the cash cap"));
        h.deployGyld(KATANA, ENV_PROD);
    }

    /*//////////////////////////////////////////////////////////////
                  F1 — THE POLICY IS DEPLOYED AND WIRED
    //////////////////////////////////////////////////////////////*/

    /// @dev The policy must exist and be bound to the SAME registry and oracle the deploy just made. A
    ///      policy pointing at a foreign registry would check one instrument list and price against another,
    ///      and its own constructor rejects that — so this also proves the deploy passes them in the right
    ///      order.
    /// @dev Base has no `superVaultAggregators` entry, so it stands in for "a chain without one".
    uint64 internal constant NO_AGGREGATOR_CHAIN = 8453;

    /// @dev Katana's real SuperVaultAggregator, as `ConfigOtherHooks` sets it.
    address internal constant KATANA_AGGREGATOR = 0x10AC0b33e1C4501CF3ec1cB1AE51ebfdbd2d4698;

    function test_DeployPath_PolicyIsBoundToTheDeployedRegistryAndOracle() public {
        _etchLedgerConfig();
        h.enableOracleOnly(KATANA);

        DeployV2OtherHooks.GyldHookAddresses memory a = h.deployGyld(KATANA, ENV_PROD);
        assertTrue(a.gyldTradePolicy != address(0), "policy deployed");
        assertTrue(a.gyldTradePolicy.code.length > 0, "policy has code");

        GyldTradePolicy policy = GyldTradePolicy(a.gyldTradePolicy);
        assertEq(address(policy.REGISTRY()), a.gyldBondRegistry, "same registry");
        assertEq(address(policy.ORACLE()), a.gyldBondYieldSourceOracle, "same oracle");
    }

    /// @dev Both trade instances must pin the policy the same deploy produced. If either pinned a stale or
    ///      zero address, F1 would be reopened at deploy time rather than in the contracts.
    function test_DeployPath_BothTradeInstancesPinTheDeployedPolicy() public {
        _etchLedgerConfig();
        h.enableFamily(KATANA, VENUE, CASH_CAP, BOND_CAP);

        DeployV2OtherHooks.GyldHookAddresses memory a = h.deployGyld(KATANA, ENV_PROD);
        assertEq(
            address(ApproveAndTradeGyldBondHook(a.approveAndTradeGyldBondCashInHook).TRADE_POLICY()),
            a.gyldTradePolicy,
            "cash-in pins the policy"
        );
        assertEq(
            address(ApproveAndTradeGyldBondHook(a.approveAndTradeGyldBondBondInHook).TRADE_POLICY()),
            a.gyldTradePolicy,
            "bond-in pins the policy"
        );
    }

    /// @dev The sides must be the right way round: cash-in BUYS, bond-in SELLS. Swapping them would let a
    ///      sell leaf be priced under buy rules, and the mistake would be invisible without this.
    function test_DeployPath_SidesMatchTheDeployKeys() public {
        _etchLedgerConfig();
        h.enableFamily(KATANA, VENUE, CASH_CAP, BOND_CAP);

        DeployV2OtherHooks.GyldHookAddresses memory a = h.deployGyld(KATANA, ENV_PROD);
        assertEq(
            uint8(ApproveAndTradeGyldBondHook(a.approveAndTradeGyldBondCashInHook).SIDE()),
            uint8(IGyldTradePolicy.TradeSide.BUY),
            "cash-in is BUY"
        );
        assertEq(
            uint8(ApproveAndTradeGyldBondHook(a.approveAndTradeGyldBondBondInHook).SIDE()),
            uint8(IGyldTradePolicy.TradeSide.SELL),
            "bond-in is SELL"
        );
    }

    /// @dev The configured aggregator must reach the policy. Zero means a PAUSED strategy could still
    ///      trade, so a dropped config entry has to be visible.
    function test_DeployPath_AggregatorReachesThePolicy() public {
        _etchLedgerConfig();
        h.enableOracleOnly(KATANA);
        address aggregator = address(0xA66);
        h.setAggregator(KATANA, aggregator);

        DeployV2OtherHooks.GyldHookAddresses memory a = h.deployGyld(KATANA, ENV_PROD);
        assertEq(
            address(GyldTradePolicy(a.gyldTradePolicy).AGGREGATOR()), aggregator, "aggregator wired through"
        );
    }

    /// @dev An unset aggregator still deploys — a chain with no SuperVault is legitimate — but it must land
    ///      as zero rather than as something arbitrary. Uses a chain with NO aggregator in
    ///      `ConfigOtherHooks`, since Katana now has a real one.
    function test_DeployPath_UnsetAggregatorDeploysAsZero() public {
        _etchLedgerConfig();
        h.enableOracleOnly(NO_AGGREGATOR_CHAIN);

        DeployV2OtherHooks.GyldHookAddresses memory a = h.deployGyld(NO_AGGREGATOR_CHAIN, ENV_PROD);
        assertEq(address(GyldTradePolicy(a.gyldTradePolicy).AGGREGATOR()), address(0), "zero, not garbage");
    }

    /// @dev And the REAL config entry must reach the policy, not just a test-injected one. This is the
    ///      end-to-end proof that `ConfigOtherHooks.superVaultAggregators[747474]` is actually consumed.
    function test_DeployPath_KatanaPicksUpTheConfiguredAggregator() public {
        _etchLedgerConfig();
        h.enableOracleOnly(KATANA);

        DeployV2OtherHooks.GyldHookAddresses memory a = h.deployGyld(KATANA, ENV_PROD);
        assertEq(
            address(GyldTradePolicy(a.gyldTradePolicy).AGGREGATOR()),
            KATANA_AGGREGATOR,
            "Katana's SuperVaultAggregator, from ConfigOtherHooks"
        );
    }

    /// @dev The policy is CREATE2-deployed under its own key, so changing the aggregator changes its
    ///      address — and therefore both trade-hook addresses. This is the cost of pinning it in an
    ///      immutable and it should be a conscious fact, not a surprise at redeploy time.
    function test_DeployPath_AggregatorIsPartOfThePolicyAddress() public {
        uint256 clean = vm.snapshotState();

        _etchLedgerConfig();
        h.enableOracleOnly(KATANA);
        h.setAggregator(KATANA, address(0xA66));
        address withA = h.deployGyld(KATANA, ENV_PROD).gyldTradePolicy;

        // Same deploy, same salt, different aggregator: a fresh chain state is needed because CREATE2 to an
        // occupied address would revert rather than return a second address.
        vm.revertToState(clean);
        _etchLedgerConfig();
        h.enableOracleOnly(KATANA);
        h.setAggregator(KATANA, address(0xB77));
        address withB = h.deployGyld(KATANA, ENV_PROD).gyldTradePolicy;

        assertTrue(withA != withB, "aggregator is part of the policy initcode, so part of its address");
    }

    /// @dev A CONFIGURED but codeless aggregator must be refused at deploy time. It is strictly worse than
    ///      no aggregator: the policy's registration probe calls `getPPS`, and a codeless address returns
    ///      empty data that Solidity can neither decode nor catch, so every trade would revert with no
    ///      reason at all. Zero is a legitimate choice; a typo must not be.
    function test_Refuses_ConfiguredButCodelessAggregator() public {
        _etchLedgerConfig();
        h.enableOracleOnly(KATANA);
        h.setAggregator(KATANA, address(0xC0DE1E55)); // deliberately NOT etched

        vm.expectRevert("GYLD_AGGREGATOR_NOT_DEPLOYED");
        h.deployGyld(KATANA, ENV_PROD);
    }

    /// @dev The policy is NOT a hook and must not be discovered as one: the manifest generator rglobs
    ///      `*Hook.sol` under src/hooks/ and the lint fails any discovered file missing from the
    ///      classification YAML. Pinned here so a later move into src/hooks/ breaks a test rather than CI.
    function test_PolicyIsNotUnderTheHooksTree() public view {
        string memory path = "src/accounting/oracles/GyldTradePolicy.sol";
        assertTrue(vm.isFile(path), "policy lives under src/accounting/oracles");
        assertFalse(vm.isFile("src/hooks/swappers/gyld/GyldTradePolicy.sol"), "and not under src/hooks");
    }
}
