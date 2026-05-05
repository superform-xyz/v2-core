// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";

import { MockERC7540VaultFull } from "../mocks/MockERC7540VaultFull.sol";
import { ERC7540YieldSourceOracle } from "../../src/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../src/accounting/SuperLedgerConfiguration.sol";

/*//////////////////////////////////////////////////////////////
                    HANDLER 1: VANILLA (18-DEC)
//////////////////////////////////////////////////////////////*/

/// @title VanillaLifecycleHandler
/// @notice Simulates standard ERC-7540 lifecycle on an 18-decimal vault
/// @dev setExchangeRate recomputes ghost_totalAssets to enable INV-2
contract VanillaLifecycleHandler is Test {
    MockERC7540VaultFull public vault;
    address[] public actors;

    // Ghost state per actor
    mapping(address => uint256) public ghost_pendingDeposit;
    mapping(address => uint256) public ghost_claimableDeposit;
    mapping(address => uint256) public ghost_pendingRedeem; // in shares
    mapping(address => uint256) public ghost_maxWithdraw;
    uint256 public ghost_totalAssets;

    constructor(MockERC7540VaultFull vault_, address[] memory actors_) {
        vault = vault_;
        actors = actors_;
    }

    function actorCount() external view returns (uint256) {
        return actors.length;
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    function requestDeposit(uint256 actorSeed, uint256 amount) external {
        amount = bound(amount, 0, 1e30);
        address actor = _actor(actorSeed);

        ghost_pendingDeposit[actor] += amount;
        ghost_totalAssets += amount;

        vault.setPendingDepositAssets(actor, ghost_pendingDeposit[actor]);
        vault.setTotalAssets(ghost_totalAssets);
    }

    function fulfillDeposit(uint256 actorSeed, uint256 amount) external {
        address actor = _actor(actorSeed);
        amount = bound(amount, 0, ghost_pendingDeposit[actor]);

        ghost_pendingDeposit[actor] -= amount;
        ghost_claimableDeposit[actor] += amount;

        vault.setPendingDepositAssets(actor, ghost_pendingDeposit[actor]);
        vault.setClaimableDepositAssets(actor, ghost_claimableDeposit[actor]);
    }

    function claimDeposit(uint256 actorSeed, uint256 amount) external {
        address actor = _actor(actorSeed);
        amount = bound(amount, 0, ghost_claimableDeposit[actor]);

        ghost_claimableDeposit[actor] -= amount;
        uint256 shares = vault.convertToShares(amount);

        vault.setClaimableDepositAssets(actor, ghost_claimableDeposit[actor]);
        vault.mintShares(actor, shares);
    }

    function requestRedeem(uint256 actorSeed, uint256 shares) external {
        address actor = _actor(actorSeed);
        uint256 balance = vault.shareToken().balanceOf(actor);
        shares = bound(shares, 0, balance);

        ghost_pendingRedeem[actor] += shares;

        vault.burnShares(actor, shares);
        vault.setPendingRedeemShares(actor, ghost_pendingRedeem[actor]);
    }

    function fulfillRedeem(uint256 actorSeed, uint256 shares) external {
        address actor = _actor(actorSeed);
        shares = bound(shares, 0, ghost_pendingRedeem[actor]);

        uint256 assets = vault.convertToAssets(shares);
        ghost_pendingRedeem[actor] -= shares;
        ghost_maxWithdraw[actor] += assets;

        vault.setPendingRedeemShares(actor, ghost_pendingRedeem[actor]);
        vault.setMaxWithdrawAssets(actor, ghost_maxWithdraw[actor]);
    }

    function claimRedeem(uint256 actorSeed, uint256 assets) external {
        address actor = _actor(actorSeed);
        assets = bound(assets, 0, ghost_maxWithdraw[actor]);

        ghost_maxWithdraw[actor] -= assets;
        if (assets <= ghost_totalAssets) {
            ghost_totalAssets -= assets;
        } else {
            ghost_totalAssets = 0;
        }

        vault.setMaxWithdrawAssets(actor, ghost_maxWithdraw[actor]);
        vault.setTotalAssets(ghost_totalAssets);
    }

    /// @notice Simulate yield accrual. Recomputes ghost_totalAssets from all 5 components.
    function setExchangeRate(uint256 rate) external {
        rate = bound(rate, 0.01e18, 1000e18);
        vault.setAssetsPerShare(rate);

        // Recompute totalAssets as sum of all 5 components across all actors
        uint256 total;
        for (uint256 i; i < actors.length; ++i) {
            address a = actors[i];
            // Component 1: held shares value
            uint256 heldShares = vault.shareToken().balanceOf(a);
            if (heldShares > 0) total += vault.convertToAssets(heldShares);
            // Component 2: pending redeem value (shares → assets)
            if (ghost_pendingRedeem[a] > 0) total += vault.convertToAssets(ghost_pendingRedeem[a]);
            // Component 3: claimable redeem (in assets)
            total += ghost_maxWithdraw[a];
            // Component 4: pending deposit (in assets)
            total += ghost_pendingDeposit[a];
            // Component 5: claimable deposit (in assets)
            total += ghost_claimableDeposit[a];
        }
        ghost_totalAssets = total;
        vault.setTotalAssets(ghost_totalAssets);
    }
}

/*//////////////////////////////////////////////////////////////
                    HANDLER 2: CENTRIFUGE (6-DEC)
//////////////////////////////////////////////////////////////*/

/// @title CentrifugeLifecycleHandler
/// @notice Simulates Centrifuge-style 6-decimal vault with epoch-based redeem pricing
/// @dev fulfillRedeem converts shares at an epochRate, not the current vault rate
contract CentrifugeLifecycleHandler is Test {
    MockERC7540VaultFull public vault;
    address[] public actors;

    mapping(address => uint256) public ghost_pendingDeposit;
    mapping(address => uint256) public ghost_claimableDeposit;
    mapping(address => uint256) public ghost_pendingRedeem; // in shares
    mapping(address => uint256) public ghost_maxWithdraw;
    uint256 public ghost_totalAssets;

    constructor(MockERC7540VaultFull vault_, address[] memory actors_) {
        vault = vault_;
        actors = actors_;
    }

    function actorCount() external view returns (uint256) {
        return actors.length;
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    function requestDeposit(uint256 actorSeed, uint256 amount) external {
        amount = bound(amount, 0, 1e18); // 6-dec vault, keep amounts reasonable
        address actor = _actor(actorSeed);

        ghost_pendingDeposit[actor] += amount;
        ghost_totalAssets += amount;

        vault.setPendingDepositAssets(actor, ghost_pendingDeposit[actor]);
        vault.setTotalAssets(ghost_totalAssets);
    }

    function fulfillDeposit(uint256 actorSeed, uint256 amount) external {
        address actor = _actor(actorSeed);
        amount = bound(amount, 0, ghost_pendingDeposit[actor]);

        ghost_pendingDeposit[actor] -= amount;
        ghost_claimableDeposit[actor] += amount;

        vault.setPendingDepositAssets(actor, ghost_pendingDeposit[actor]);
        vault.setClaimableDepositAssets(actor, ghost_claimableDeposit[actor]);
    }

    function claimDeposit(uint256 actorSeed, uint256 amount) external {
        address actor = _actor(actorSeed);
        amount = bound(amount, 0, ghost_claimableDeposit[actor]);

        ghost_claimableDeposit[actor] -= amount;
        uint256 shares = vault.convertToShares(amount);

        vault.setClaimableDepositAssets(actor, ghost_claimableDeposit[actor]);
        vault.mintShares(actor, shares);
    }

    function requestRedeem(uint256 actorSeed, uint256 shares) external {
        address actor = _actor(actorSeed);
        uint256 balance = vault.shareToken().balanceOf(actor);
        shares = bound(shares, 0, balance);

        ghost_pendingRedeem[actor] += shares;

        vault.burnShares(actor, shares);
        vault.setPendingRedeemShares(actor, ghost_pendingRedeem[actor]);
    }

    /// @notice Centrifuge-style: fulfillRedeem converts at a separate epochRate
    /// @dev The epochRate may differ from the current vault rate (simulates locked redeemPrice).
    ///      Adjusts totalAssets to account for the difference between vault-rate and epoch-rate value.
    function fulfillRedeem(uint256 actorSeed, uint256 shares, uint256 epochRate) external {
        address actor = _actor(actorSeed);
        shares = bound(shares, 0, ghost_pendingRedeem[actor]);
        epochRate = bound(epochRate, 0.8e6, 1.2e6);

        // Value at vault rate (what totalAssets currently accounts for)
        uint256 vaultRateValue = vault.convertToAssets(shares);
        // Value at epoch rate (what maxWithdraw will be set to)
        uint256 oneShare = 10 ** vault.shareToken().decimals(); // 1e6
        uint256 epochRateValue = (shares * epochRate) / oneShare;

        ghost_pendingRedeem[actor] -= shares;
        ghost_maxWithdraw[actor] += epochRateValue;

        // Adjust totalAssets: remove vault-rate value, add epoch-rate value
        if (vaultRateValue <= ghost_totalAssets) {
            ghost_totalAssets = ghost_totalAssets - vaultRateValue + epochRateValue;
        } else {
            ghost_totalAssets = epochRateValue;
        }

        vault.setPendingRedeemShares(actor, ghost_pendingRedeem[actor]);
        vault.setMaxWithdrawAssets(actor, ghost_maxWithdraw[actor]);
        vault.setTotalAssets(ghost_totalAssets);
    }

    function claimRedeem(uint256 actorSeed, uint256 assets) external {
        address actor = _actor(actorSeed);
        assets = bound(assets, 0, ghost_maxWithdraw[actor]);

        ghost_maxWithdraw[actor] -= assets;
        if (assets <= ghost_totalAssets) {
            ghost_totalAssets -= assets;
        } else {
            ghost_totalAssets = 0;
        }

        vault.setMaxWithdrawAssets(actor, ghost_maxWithdraw[actor]);
        vault.setTotalAssets(ghost_totalAssets);
    }

    function setExchangeRate(uint256 rate) external {
        rate = bound(rate, 0.01e6, 1000e6);
        vault.setAssetsPerShare(rate);

        // Recompute totalAssets from all components
        uint256 total;
        for (uint256 i; i < actors.length; ++i) {
            address a = actors[i];
            uint256 heldShares = vault.shareToken().balanceOf(a);
            if (heldShares > 0) total += vault.convertToAssets(heldShares);
            if (ghost_pendingRedeem[a] > 0) total += vault.convertToAssets(ghost_pendingRedeem[a]);
            total += ghost_maxWithdraw[a];
            total += ghost_pendingDeposit[a];
            total += ghost_claimableDeposit[a];
        }
        ghost_totalAssets = total;
        vault.setTotalAssets(ghost_totalAssets);
    }
}

/*//////////////////////////////////////////////////////////////
                    HANDLER 3: DEGRADED (18-DEC)
//////////////////////////////////////////////////////////////*/

/// @title DegradedLifecycleHandler
/// @notice Same lifecycle ops plus random revert flag toggling for graceful degradation testing
/// @dev NEVER toggles revertOnConvertToAssets or revertOnConvertToShares — those propagate
contract DegradedLifecycleHandler is Test {
    MockERC7540VaultFull public vault;
    address[] public actors;

    mapping(address => uint256) public ghost_pendingDeposit;
    mapping(address => uint256) public ghost_claimableDeposit;
    mapping(address => uint256) public ghost_pendingRedeem;
    mapping(address => uint256) public ghost_maxWithdraw;
    uint256 public ghost_totalAssets;

    // Track which flags are on for invariant checks
    bool public flag_revertPendingRedeem;
    bool public flag_revertMaxWithdraw;
    bool public flag_revertPendingDeposit;
    bool public flag_revertClaimableDeposit;

    constructor(MockERC7540VaultFull vault_, address[] memory actors_) {
        vault = vault_;
        actors = actors_;
    }

    function actorCount() external view returns (uint256) {
        return actors.length;
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    /// @notice Toggle one of 4 async revert flags (NEVER convertToAssets/convertToShares)
    function toggleRevertFlag(uint8 flagIndex) external {
        flagIndex = uint8(bound(flagIndex, 0, 3));
        if (flagIndex == 0) {
            flag_revertPendingRedeem = !flag_revertPendingRedeem;
            vault.setRevertOnPendingRedeemRequest(flag_revertPendingRedeem);
        } else if (flagIndex == 1) {
            flag_revertMaxWithdraw = !flag_revertMaxWithdraw;
            vault.setRevertOnMaxWithdraw(flag_revertMaxWithdraw);
        } else if (flagIndex == 2) {
            flag_revertPendingDeposit = !flag_revertPendingDeposit;
            vault.setRevertOnPendingDepositRequest(flag_revertPendingDeposit);
        } else {
            flag_revertClaimableDeposit = !flag_revertClaimableDeposit;
            vault.setRevertOnClaimableDepositRequest(flag_revertClaimableDeposit);
        }
    }

    function requestDeposit(uint256 actorSeed, uint256 amount) external {
        amount = bound(amount, 0, 1e30);
        address actor = _actor(actorSeed);

        ghost_pendingDeposit[actor] += amount;
        ghost_totalAssets += amount;

        vault.setPendingDepositAssets(actor, ghost_pendingDeposit[actor]);
        vault.setTotalAssets(ghost_totalAssets);
    }

    function fulfillDeposit(uint256 actorSeed, uint256 amount) external {
        address actor = _actor(actorSeed);
        amount = bound(amount, 0, ghost_pendingDeposit[actor]);

        ghost_pendingDeposit[actor] -= amount;
        ghost_claimableDeposit[actor] += amount;

        vault.setPendingDepositAssets(actor, ghost_pendingDeposit[actor]);
        vault.setClaimableDepositAssets(actor, ghost_claimableDeposit[actor]);
    }

    function claimDeposit(uint256 actorSeed, uint256 amount) external {
        address actor = _actor(actorSeed);
        amount = bound(amount, 0, ghost_claimableDeposit[actor]);

        ghost_claimableDeposit[actor] -= amount;
        uint256 shares = vault.convertToShares(amount);

        vault.setClaimableDepositAssets(actor, ghost_claimableDeposit[actor]);
        vault.mintShares(actor, shares);
    }

    function requestRedeem(uint256 actorSeed, uint256 shares) external {
        address actor = _actor(actorSeed);
        uint256 balance = vault.shareToken().balanceOf(actor);
        shares = bound(shares, 0, balance);

        ghost_pendingRedeem[actor] += shares;

        vault.burnShares(actor, shares);
        vault.setPendingRedeemShares(actor, ghost_pendingRedeem[actor]);
    }

    function fulfillRedeem(uint256 actorSeed, uint256 shares) external {
        address actor = _actor(actorSeed);
        shares = bound(shares, 0, ghost_pendingRedeem[actor]);

        uint256 assets = vault.convertToAssets(shares);
        ghost_pendingRedeem[actor] -= shares;
        ghost_maxWithdraw[actor] += assets;

        vault.setPendingRedeemShares(actor, ghost_pendingRedeem[actor]);
        vault.setMaxWithdrawAssets(actor, ghost_maxWithdraw[actor]);
    }

    function claimRedeem(uint256 actorSeed, uint256 assets) external {
        address actor = _actor(actorSeed);
        assets = bound(assets, 0, ghost_maxWithdraw[actor]);

        ghost_maxWithdraw[actor] -= assets;
        if (assets <= ghost_totalAssets) {
            ghost_totalAssets -= assets;
        } else {
            ghost_totalAssets = 0;
        }

        vault.setMaxWithdrawAssets(actor, ghost_maxWithdraw[actor]);
        vault.setTotalAssets(ghost_totalAssets);
    }

    function setExchangeRate(uint256 rate) external {
        rate = bound(rate, 0.01e18, 1000e18);
        vault.setAssetsPerShare(rate);

        uint256 total;
        for (uint256 i; i < actors.length; ++i) {
            address a = actors[i];
            uint256 heldShares = vault.shareToken().balanceOf(a);
            if (heldShares > 0) total += vault.convertToAssets(heldShares);
            if (ghost_pendingRedeem[a] > 0) total += vault.convertToAssets(ghost_pendingRedeem[a]);
            total += ghost_maxWithdraw[a];
            total += ghost_pendingDeposit[a];
            total += ghost_claimableDeposit[a];
        }
        ghost_totalAssets = total;
        vault.setTotalAssets(ghost_totalAssets);
    }
}

/*//////////////////////////////////////////////////////////////
                    INVARIANT TEST CONTRACT
//////////////////////////////////////////////////////////////*/

/// @title ERC7540OracleInvariantTest
/// @notice Invariant tests for ERC7540YieldSourceOracle with 3 handlers and 8 invariants
contract ERC7540OracleInvariantTest is Test {
    ERC7540YieldSourceOracle public oracle;
    SuperLedgerConfiguration public ledgerConfig;

    // Vaults
    MockERC7540VaultFull public vault18; // Vanilla 18-dec
    MockERC7540VaultFull public vault6; // Centrifuge 6-dec
    MockERC7540VaultFull public vaultDegraded; // Degraded 18-dec

    // Handlers
    VanillaLifecycleHandler public vanillaHandler;
    CentrifugeLifecycleHandler public centrifugeHandler;
    DegradedLifecycleHandler public degradedHandler;

    address[] public actors;

    function setUp() public {
        ledgerConfig = new SuperLedgerConfiguration();
        oracle = new ERC7540YieldSourceOracle(address(ledgerConfig), 0);

        // Create 3 vaults
        vault18 = new MockERC7540VaultFull(18, 18);
        vault6 = new MockERC7540VaultFull(6, 6);
        vaultDegraded = new MockERC7540VaultFull(18, 18);

        // Shared actors
        actors.push(makeAddr("actor0"));
        actors.push(makeAddr("actor1"));
        actors.push(makeAddr("actor2"));

        // Create handlers
        vanillaHandler = new VanillaLifecycleHandler(vault18, actors);
        centrifugeHandler = new CentrifugeLifecycleHandler(vault6, actors);
        degradedHandler = new DegradedLifecycleHandler(vaultDegraded, actors);

        // Target all 3 handlers
        targetContract(address(vanillaHandler));
        targetContract(address(centrifugeHandler));
        targetContract(address(degradedHandler));
    }

    /*//////////////////////////////////////////////////////////////
                    INV-1: TVL >= maxWithdraw
    //////////////////////////////////////////////////////////////*/

    /// @notice For all actors on vanilla and centrifuge vaults: TVL >= maxWithdraw
    /// @dev Skips degraded vault when maxWithdraw revert flag is set
    function invariant_INV1_TVL_lowerBound() public view {
        for (uint256 i; i < actors.length; ++i) {
            // Vanilla vault
            uint256 tvl18 = oracle.getTVLByOwnerOfShares(address(vault18), actors[i]);
            uint256 mw18 = vanillaHandler.ghost_maxWithdraw(actors[i]);
            assertGe(tvl18, mw18, "INV-1 vanilla: TVL >= maxWithdraw");

            // Centrifuge vault
            uint256 tvl6 = oracle.getTVLByOwnerOfShares(address(vault6), actors[i]);
            uint256 mw6 = centrifugeHandler.ghost_maxWithdraw(actors[i]);
            assertGe(tvl6, mw6, "INV-1 centrifuge: TVL >= maxWithdraw");

            // Degraded vault — only if maxWithdraw flag is off
            if (!degradedHandler.flag_revertMaxWithdraw()) {
                uint256 tvlD = oracle.getTVLByOwnerOfShares(address(vaultDegraded), actors[i]);
                uint256 mwD = degradedHandler.ghost_maxWithdraw(actors[i]);
                assertGe(tvlD, mwD, "INV-1 degraded: TVL >= maxWithdraw");
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                    INV-2: No Over-Attribution
    //////////////////////////////////////////////////////////////*/

    /// @notice sum(getTVLByOwnerOfShares(vault, actor_i)) <= getTVL(vault) + rounding tolerance
    /// @dev Each requestRedeem splits shares between held & pending; convertToAssets applied
    ///      individually can produce a sum up to 1 wei per actor above the combined value.
    function invariant_INV2_noOverAttribution() public view {
        uint256 tolerance = actors.length; // 1 wei per actor

        // Vanilla vault
        uint256 sumTvl18;
        for (uint256 i; i < actors.length; ++i) {
            sumTvl18 += oracle.getTVLByOwnerOfShares(address(vault18), actors[i]);
        }
        uint256 totalTvl18 = oracle.getTVL(address(vault18));
        assertLe(sumTvl18, totalTvl18 + tolerance, "INV-2 vanilla: sum(user TVL) <= getTVL + tolerance");

        // Centrifuge vault
        uint256 sumTvl6;
        for (uint256 i; i < actors.length; ++i) {
            sumTvl6 += oracle.getTVLByOwnerOfShares(address(vault6), actors[i]);
        }
        uint256 totalTvl6 = oracle.getTVL(address(vault6));
        assertLe(sumTvl6, totalTvl6 + tolerance, "INV-2 centrifuge: sum(user TVL) <= getTVL + tolerance");
    }

    /*//////////////////////////////////////////////////////////////
                    INV-3: State Transition Preservation
    //////////////////////////////////////////////////////////////*/

    /// @notice Ghost tracking: recomputed component sum matches ghost_totalAssets (within rounding)
    /// @dev Each asset-to-share-to-asset round-trip can lose up to 1 unit per conversion.
    ///      With multiple actors and operations, cumulative rounding can reach ~1000 wei.
    function invariant_INV3_stateTransitionPreservation() public view {
        uint256 ghostSum;
        for (uint256 i; i < actors.length; ++i) {
            address a = actors[i];
            uint256 heldShares = vault18.shareToken().balanceOf(a);
            if (heldShares > 0) ghostSum += vault18.convertToAssets(heldShares);
            uint256 pr = vanillaHandler.ghost_pendingRedeem(a);
            if (pr > 0) ghostSum += vault18.convertToAssets(pr);
            ghostSum += vanillaHandler.ghost_maxWithdraw(a);
            ghostSum += vanillaHandler.ghost_pendingDeposit(a);
            ghostSum += vanillaHandler.ghost_claimableDeposit(a);
        }
        uint256 ghostTotal = vanillaHandler.ghost_totalAssets();
        // Each claimDeposit does asset->share->asset round-trip losing up to 1 unit per conversion.
        // With non-trivial exchange rates and many operations, cumulative rounding can reach ~10000 wei.
        assertApproxEqAbs(ghostSum, ghostTotal, 10_000, "INV-3 vanilla: component sum ~= totalAssets");
    }

    /*//////////////////////////////////////////////////////////////
                    INV-4: Mutual Exclusivity
    //////////////////////////////////////////////////////////////*/

    /// @notice Oracle breakdown components match ghost state (no double-counting)
    function invariant_INV4_mutualExclusivity() public view {
        for (uint256 i; i < actors.length; ++i) {
            address a = actors[i];

            // Vanilla vault
            (,, uint256 cr18,, uint256 cd18) = oracle.getAsyncStateBreakdown(address(vault18), a);
            // pendingDeposit and claimableDeposit are exact matches
            (,,, uint256 pd18,) = oracle.getAsyncStateBreakdown(address(vault18), a);
            assertEq(pd18, vanillaHandler.ghost_pendingDeposit(a), "INV-4 vanilla: pendingDeposit ghost");
            assertEq(cd18, vanillaHandler.ghost_claimableDeposit(a), "INV-4 vanilla: claimableDeposit ghost");
            assertEq(cr18, vanillaHandler.ghost_maxWithdraw(a), "INV-4 vanilla: maxWithdraw ghost");

            // Centrifuge vault
            (,, uint256 cr6, uint256 pd6, uint256 cd6) = oracle.getAsyncStateBreakdown(address(vault6), a);
            assertEq(pd6, centrifugeHandler.ghost_pendingDeposit(a), "INV-4 centrifuge: pendingDeposit ghost");
            assertEq(cd6, centrifugeHandler.ghost_claimableDeposit(a), "INV-4 centrifuge: claimableDeposit ghost");
            assertEq(cr6, centrifugeHandler.ghost_maxWithdraw(a), "INV-4 centrifuge: maxWithdraw ghost");
        }
    }

    /*//////////////////////////////////////////////////////////////
                    INV-5: Claimable == maxWithdraw
    //////////////////////////////////////////////////////////////*/

    /// @notice claimableRedeemValue == maxWithdraw(actor) exactly for vanilla and centrifuge
    function invariant_INV5_claimableEqualsMaxWithdraw() public view {
        for (uint256 i; i < actors.length; ++i) {
            // Vanilla
            (,, uint256 cr18,,) = oracle.getAsyncStateBreakdown(address(vault18), actors[i]);
            assertEq(cr18, vanillaHandler.ghost_maxWithdraw(actors[i]), "INV-5 vanilla");

            // Centrifuge
            (,, uint256 cr6,,) = oracle.getAsyncStateBreakdown(address(vault6), actors[i]);
            assertEq(cr6, centrifugeHandler.ghost_maxWithdraw(actors[i]), "INV-5 centrifuge");
        }
    }

    /*//////////////////////////////////////////////////////////////
                    INV-6: Decimal Correctness
    //////////////////////////////////////////////////////////////*/

    /// @notice decimals(vault) == shareToken.decimals() AND PPS == convertToAssets(10^decimals)
    function invariant_INV6_decimalCorrectness() public view {
        // Vanilla 18-dec
        uint8 dec18 = oracle.decimals(address(vault18));
        assertEq(dec18, vault18.shareToken().decimals(), "INV-6 vanilla: decimals match");
        assertEq(
            oracle.getPricePerShare(address(vault18)),
            vault18.convertToAssets(10 ** dec18),
            "INV-6 vanilla: PPS == convertToAssets(10^dec)"
        );

        // Centrifuge 6-dec
        uint8 dec6 = oracle.decimals(address(vault6));
        assertEq(dec6, vault6.shareToken().decimals(), "INV-6 centrifuge: decimals match");
        assertEq(
            oracle.getPricePerShare(address(vault6)),
            vault6.convertToAssets(10 ** dec6),
            "INV-6 centrifuge: PPS == convertToAssets(10^dec)"
        );
    }

    /*//////////////////////////////////////////////////////////////
                    INV-7: Graceful Degradation
    //////////////////////////////////////////////////////////////*/

    /// @notice getTVLByOwnerOfShares never reverts on degraded vault regardless of revert flags
    function invariant_INV7_gracefulDegradation() public view {
        for (uint256 i; i < actors.length; ++i) {
            // Must not revert — if it does, invariant test fails
            oracle.getTVLByOwnerOfShares(address(vaultDegraded), actors[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                    INV-8: PPS Consistency
    //////////////////////////////////////////////////////////////*/

    /// @notice getPricePerShare(vault) == convertToAssets(10^decimals(vault)) for all 3 vaults
    function invariant_INV8_PPSConsistency() public view {
        // Vanilla
        uint8 d18 = oracle.decimals(address(vault18));
        assertEq(
            oracle.getPricePerShare(address(vault18)),
            vault18.convertToAssets(10 ** d18),
            "INV-8 vanilla"
        );

        // Centrifuge
        uint8 d6 = oracle.decimals(address(vault6));
        assertEq(
            oracle.getPricePerShare(address(vault6)),
            vault6.convertToAssets(10 ** d6),
            "INV-8 centrifuge"
        );

        // Degraded (convertToAssets is never set to revert)
        uint8 dD = oracle.decimals(address(vaultDegraded));
        assertEq(
            oracle.getPricePerShare(address(vaultDegraded)),
            vaultDegraded.convertToAssets(10 ** dD),
            "INV-8 degraded"
        );
    }
}
