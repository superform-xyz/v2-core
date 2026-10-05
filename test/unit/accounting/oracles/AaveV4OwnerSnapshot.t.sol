// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { AaveV4ReserveRegistryV2 } from "../../../../src/accounting/oracles/AaveV4ReserveRegistryV2.sol";
import { AaveV4ReserveOracle } from "../../../../src/accounting/oracles/AaveV4ReserveOracle.sol";
import { IAaveV4OwnerSnapshot } from "../../../../src/interfaces/accounting/IAaveV4OwnerSnapshot.sol";
import { IAaveV4Spoke } from "../../../../src/vendor/aave-v4/IAaveV4Spoke.sol";

contract SnapshotToken is ERC20 {
    uint8 private immutable tokenDecimals;

    constructor(string memory symbol_, uint8 decimals_) ERC20(symbol_, symbol_) {
        tokenDecimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return tokenDecimals;
    }

    function mint(address owner, uint256 assets) external {
        _mint(owner, assets);
    }
}

contract SnapshotSpoke {
    struct Position {
        uint256 supplied;
        uint256 drawn;
        uint256 premium;
    }
    IAaveV4Spoke.Reserve[] private reserves;
    mapping(uint256 => mapping(address => Position)) private positions;
    bool public failStatus;
    error UnreadableStatus();

    function addReserve(address token, uint8 decimals_) external returns (uint256 id) {
        id = reserves.length;
        reserves.push(IAaveV4Spoke.Reserve(token, address(this), uint16(id), decimals_, 0, 0, 0));
    }

    function setPosition(uint256 id, address owner, uint256 supplied, uint256 drawn, uint256 premium) external {
        positions[id][owner] = Position(supplied, drawn, premium);
    }

    function setFailStatus(bool fail) external {
        failStatus = fail;
    }

    function getReserve(uint256 id) external view returns (IAaveV4Spoke.Reserve memory) {
        return reserves[id];
    }

    function getReserveCount() external view returns (uint256) {
        return reserves.length;
    }

    function getUserReserveStatus(uint256 id, address owner) external view returns (bool, bool) {
        if (failStatus) revert UnreadableStatus();
        require(id < reserves.length);
        Position memory p = positions[id][owner];
        return (p.supplied != 0, p.drawn != 0 || p.premium != 0);
    }

    function getUserSuppliedAssets(uint256 id, address owner) external view returns (uint256) {
        return positions[id][owner].supplied;
    }

    function getUserDebt(uint256 id, address owner) external view returns (uint256, uint256) {
        Position memory p = positions[id][owner];
        return (p.drawn, p.premium);
    }
}

contract AaveV4OwnerSnapshotTest is Test {
    AaveV4ReserveRegistryV2 private registry;
    AaveV4ReserveOracle private oracle;
    SnapshotSpoke private spoke;
    SnapshotToken private equity;
    SnapshotToken private usdc;
    SnapshotToken private weth;
    address private owner;
    address private supplyKey;
    address private debtKey;

    address internal marketKey;
    address internal secondMarketKey;

    function setUp() public {
        owner = makeAddr("strategy");
        equity = new SnapshotToken("EQUITY", 8);
        usdc = new SnapshotToken("USDC", 6);
        weth = new SnapshotToken("WETH", 18);
        spoke = new SnapshotSpoke();
        spoke.addReserve(address(equity), 8);
        spoke.addReserve(address(usdc), 6);
        spoke.addReserve(address(weth), 18);
        registry = new AaveV4ReserveRegistryV2(address(this));
        oracle = new AaveV4ReserveOracle(makeAddr("ledger config"), address(registry));
        (supplyKey,) = registry.registerReserve(address(spoke), 0);
        (, debtKey) = registry.registerReserve(address(spoke), 1);
        registry.registerReserve(address(spoke), 2);
        // SUP-21256: the snapshot input is MARKET identity. Equity (reserve 0) collateral against the USDC
        // (reserve 1) loan is the pair these tests used to address as two separate reserve keys.
        marketKey = registry.registerMarket(address(spoke), 0, 1);
        // a second market over the SAME loan reserve, for the shared-leg dedup assertions
        secondMarketKey = registry.registerMarket(address(spoke), 2, 1);
        spoke.setPosition(0, owner, 100e8, 0, 0);
        spoke.setPosition(1, owner, 0, 100e6, 2e6);
        usdc.mint(owner, 30e6);
        weth.mint(owner, 9e18);
    }

    function test_OwnerSnapshotDiscoversDebtAccrualAndCash() public {
        vm.expectCall(address(usdc), abi.encodeWithSignature("balanceOf(address)", owner), uint64(1));
        (, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions, IAaveV4OwnerSnapshot.WalletBalance[] memory cash) =
            oracle.getOwnerSnapshot(owner, one(marketKey), new address[](0), one(address(usdc)), address(equity), 128);
        assertEq(positions.length, 2);
        assertEq(positions[0].sourceKey, supplyKey);
        assertEq(positions[0].symbol, "EQUITY");
        assertEq(positions[0].assets, oracle.getBalanceOfOwner(supplyKey, owner));
        assertEq(positions[1].sourceKey, debtKey);
        assertEq(positions[1].side, 1);
        assertEq(positions[1].underlyingDecimals, 6);
        assertEq(positions[1].assets, 102e6);
        assertEq(positions[1].assets, oracle.getBalanceOfOwner(debtKey, owner));
        assertEq(cash.length, 1);
        assertEq(cash[0].token, address(usdc));
        assertEq(cash[0].balance, 30e6);
    }

    function test_ExplicitDebtAndDuplicateSourcesSpokesCashAreCountedOnce() public {
        address[] memory keys = new address[](3);
        keys[0] = marketKey;
        keys[1] = marketKey;
        keys[2] = marketKey;
        address[] memory spokes = new address[](2);
        spokes[0] = address(spoke);
        spokes[1] = address(spoke);
        vm.expectCall(address(spoke), abi.encodeWithSignature("getReserveCount()"), uint64(1));
        vm.expectCall(address(usdc), abi.encodeWithSignature("balanceOf(address)", owner), uint64(1));
        (
            IAaveV4OwnerSnapshot.MarketBinding[] memory markets,
            IAaveV4OwnerSnapshot.OwnerPosition[] memory positions,
            IAaveV4OwnerSnapshot.WalletBalance[] memory cash
        ) = oracle.getOwnerSnapshot(owner, keys, spokes, one(address(usdc)), address(equity), 128);
        assertEq(markets.length, 1, "a repeated market key collapses to one binding");
        assertEq(positions.length, 2, "and to one supply + one debt leg");
        assertEq(cash.length, 1);
    }

    function test_MultipleDebtsKeepEachTokenOnce() public {
        spoke.setPosition(2, owner, 0, 2e18, 1e16);
        (, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions, IAaveV4OwnerSnapshot.WalletBalance[] memory cash) =
            oracle.getOwnerSnapshot(owner, one(marketKey), new address[](0), one(address(usdc)), address(equity), 128);
        assertEq(positions.length, 3);
        assertEq(cash.length, 2);
        assertEq(cash[0].token, address(usdc));
        assertEq(cash[1].token, address(weth));
        assertEq(cash[1].balance, 9e18);
        assertEq(positions[2].assets, 2e18 + 1e16);
    }

    /// @dev One reserve's two legs stay separate keys even when both are live. A MARKET cannot name the
    ///      same reserve twice (`IDENTICAL_RESERVES`), so this is asserted the way it actually arises: the
    ///      market contributes the collateral reserve's SUPPLY leg and the loan reserve's DEBT leg, and a
    ///      debt the owner also holds on the COLLATERAL reserve is discovered as a third, distinct position.
    function test_SameReserveSupplyAndDebtKeepSeparateKeys() public {
        spoke.setPosition(0, owner, 100e8, 1e8, 1);
        (IAaveV4OwnerSnapshot.MarketBinding[] memory markets, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions,) =
            oracle.getOwnerSnapshot(owner, one(marketKey), new address[](0), new address[](0), address(equity), 128);

        assertEq(positions.length, 3, "two market legs plus the discovered collateral-reserve debt");
        assertEq(positions[0].sourceKey, markets[0].supplyKey, "collateral SUPPLY leg");
        assertEq(positions[1].sourceKey, markets[0].debtKey, "loan DEBT leg");
        assertTrue(positions[0].sourceKey != positions[1].sourceKey, "the two legs are distinct keys");

        address collateralDebtKey = registry.computeDebtKey(address(spoke), 0);
        assertEq(positions[2].sourceKey, collateralDebtKey, "debt on the collateral reserve is its own key");
        assertEq(positions[2].side, 1);
        assertEq(positions[2].assets, 1e8 + 1);
    }

    function test_TwoSpokesShareOneCashBalance() public {
        SnapshotSpoke other = new SnapshotSpoke();
        other.addReserve(address(usdc), 6);
        other.setPosition(0, owner, 0, 50e6, 1e6);
        registry.registerReserve(address(other), 0);
        vm.expectCall(address(usdc), abi.encodeWithSignature("balanceOf(address)", owner), uint64(1));
        (, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions, IAaveV4OwnerSnapshot.WalletBalance[] memory cash) =
            oracle.getOwnerSnapshot(owner, one(marketKey), one(address(other)), new address[](0), address(equity), 128);
        assertEq(positions.length, 3);
        assertEq(cash.length, 1);
        assertEq(cash[0].balance, 30e6);
    }

    function test_VaultUnderlyingCashIsNotReadTwice() public {
        vm.mockCallRevert(address(usdc), abi.encodeWithSignature("balanceOf(address)", owner), bytes("must not read"));
        (,, IAaveV4OwnerSnapshot.WalletBalance[] memory cash) =
            oracle.getOwnerSnapshot(owner, one(marketKey), new address[](0), one(address(usdc)), address(usdc), 128);
        assertEq(cash.length, 0);
    }

    /// @dev SUP-21259 CHANGED THIS EXPECTATION, and the change is the fix. With no market requested, the
    ///      owner's reserve-0 equity collateral used to vanish while its reserve-1 debt kept being
    ///      discovered — exactly the one-sided snapshot the ticket closes. Both legs now come back: debt
    ///      first (discovery order), then the residual supply.
    function test_EmptySourcesStillDiscoverConfiguredSpoke() public {
        (, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions,) = oracle.getOwnerSnapshot(
            owner, new address[](0), one(address(spoke)), new address[](0), address(equity), 128
        );
        assertEq(positions.length, 2);
        assertEq(positions[0].sourceKey, debtKey);
        assertEq(positions[1].sourceKey, supplyKey, "collateral is no longer dropped when no market names it");
        assertEq(positions[1].assets, 100e8);
    }

    function test_AfterRepaymentExplicitCashPersistsWithoutWalletSweep() public {
        spoke.setPosition(1, owner, 0, 0, 0);
        (, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions, IAaveV4OwnerSnapshot.WalletBalance[] memory cash) = oracle.getOwnerSnapshot(
            owner, new address[](0), one(address(spoke)), one(address(usdc)), address(equity), 128
        );
        // SUP-21259: repaying the loan does not un-collateralise the supply. The debt row disappears, the
        // equity collateral stays — previously this read as a zero-position account still holding 100e8.
        assertEq(positions.length, 1);
        assertEq(positions[0].sourceKey, supplyKey);
        assertEq(positions[0].assets, 100e8);
        assertEq(cash.length, 1);
        assertEq(cash[0].token, address(usdc));
        assertEq(cash[0].balance, 30e6);
    }

    function test_NewReserveAndDebtAreDiscoveredOnNextRead() public {
        SnapshotToken next = new SnapshotToken("NEXT", 6);
        uint256 id = spoke.addReserve(address(next), 6);
        (, address key) = registry.registerReserve(address(spoke), id);
        spoke.setPosition(id, owner, 0, 1e6, 1);
        (, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions,) =
            oracle.getOwnerSnapshot(owner, one(marketKey), new address[](0), new address[](0), address(equity), 128);
        assertEq(positions.length, 3);
        assertEq(positions[2].sourceKey, key);
    }

    /// @dev STRICT FAILURE, both halves. A leg a live market depends on cannot be deregistered at all
    ///      (`marketRefs`), so "registered market with a missing leg" is unrepresentable rather than merely
    ///      caught — that is why the snapshot can trust `getMarketInfo`. What CAN reach the snapshot is an
    ///      unregistered market key, and that fails the whole call with no fallback.
    function test_UnregisteredMarketRevertsEntireSnapshot() public {
        // the loan DEBT leg is claimed by the market, so it cannot go dark underneath the snapshot
        vm.expectRevert(AaveV4ReserveRegistryV2.MARKET_REFERENCES_RESERVE.selector);
        registry.proposeDeregisterReserve(debtKey);

        // an unregistered market key fails the entire snapshot
        address unknownMarket = registry.computeMarketKey(address(spoke), 1, 2);
        vm.expectRevert(AaveV4ReserveRegistryV2.MARKET_NOT_REGISTERED.selector);
        oracle.getOwnerSnapshot(owner, one(unknownMarket), new address[](0), new address[](0), address(equity), 128);

        // and so does a RESERVE key passed where a market belongs: the namespaces never fall back
        vm.expectRevert(AaveV4ReserveRegistryV2.MARKET_NOT_REGISTERED.selector);
        oracle.getOwnerSnapshot(owner, one(supplyKey), new address[](0), new address[](0), address(equity), 128);
    }

    function test_UnavailableSymbolDoesNotBlockAccounting() public {
        vm.mockCallRevert(address(usdc), abi.encodeWithSignature("symbol()"), bytes("optional metadata"));
        (, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions, IAaveV4OwnerSnapshot.WalletBalance[] memory cash) =
            oracle.getOwnerSnapshot(owner, one(marketKey), new address[](0), new address[](0), address(equity), 128);
        assertEq(positions[1].symbol, "");
        assertEq(positions[1].assets, 102e6);
        assertEq(cash[0].balance, 30e6);
    }

    function testFuzz_MalformedSymbolDoesNotBlockAccounting(bytes32 malformed) public {
        // Legacy bytes32 metadata is not ABI encoded string metadata.
        vm.mockCall(address(usdc), abi.encodeWithSignature("symbol()"), abi.encode(malformed));
        (, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions,) =
            oracle.getOwnerSnapshot(owner, one(marketKey), new address[](0), new address[](0), address(equity), 128);
        assertEq(positions[1].symbol, "");
        assertEq(positions[1].assets, 102e6);
    }

    function test_MalformedSymbolHeadersDoNotBlockAccounting() public {
        bytes[] memory responses = new bytes[](5);
        responses[0] = abi.encode(uint256(0), uint256(0));
        responses[1] = abi.encode(uint256(64), uint256(0));
        responses[2] = abi.encode(uint256(32), type(uint256).max);
        responses[3] = abi.encode(uint256(32), uint256(1)); // Missing string data.
        responses[4] = abi.encode(string(new bytes(257))); // Valid encoding, excessive symbol length.
        for (uint256 i; i < responses.length; ++i) {
            vm.mockCall(address(usdc), abi.encodeWithSignature("symbol()"), responses[i]);
            (, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions,) =
                oracle.getOwnerSnapshot(owner, one(marketKey), new address[](0), new address[](0), address(equity), 128);
            // the market's DEBT leg is the USDC one whose symbol is being mangled
            assertEq(positions[1].symbol, "");
            assertEq(positions[1].assets, 102e6);
        }
    }

    function test_MaximumSymbolLengthIsAccepted() public {
        string memory symbol = string(new bytes(256));
        vm.mockCall(address(usdc), abi.encodeWithSignature("symbol()"), abi.encode(symbol));
        (, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions,) =
            oracle.getOwnerSnapshot(owner, one(marketKey), new address[](0), new address[](0), address(equity), 128);
        assertEq(positions[1].symbol, symbol, "the USDC DEBT leg carries the mocked symbol");
        assertEq(positions[1].assets, 102e6);
    }

    function test_UnreadableCashFailsWithoutFallback() public {
        vm.mockCallRevert(address(usdc), abi.encodeWithSignature("balanceOf(address)", owner), bytes("unreadable"));
        vm.expectRevert(bytes("unreadable"));
        oracle.getOwnerSnapshot(owner, one(marketKey), new address[](0), new address[](0), address(equity), 128);
    }

    function test_UnreadableStatusFailsWithoutFallback() public {
        spoke.setFailStatus(true);
        vm.expectRevert(SnapshotSpoke.UnreadableStatus.selector);
        oracle.getOwnerSnapshot(owner, one(marketKey), new address[](0), new address[](0), address(equity), 128);
    }

    function test_ReserveLimitRevertsInsteadOfTruncatingDebt() public {
        vm.expectRevert(AaveV4ReserveOracle.SNAPSHOT_RESERVE_LIMIT.selector);
        oracle.getOwnerSnapshot(owner, one(marketKey), new address[](0), new address[](0), address(equity), 2);
    }

    function testFuzz_AccruedDebtMatchesExistingOracle(uint128 drawn, uint128 premium) public {
        spoke.setPosition(1, owner, 0, drawn, premium);
        (, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions,) =
            oracle.getOwnerSnapshot(owner, one(marketKey), new address[](0), new address[](0), address(equity), 128);
        // index 1 is the market's DEBT leg; index 0 is its collateral SUPPLY leg
        assertEq(positions[1].assets, uint256(drawn) + premium);
        assertEq(positions[1].assets, oracle.getBalanceOfOwner(debtKey, owner));
    }

    function one(address value) private pure returns (address[] memory values) {
        values = new address[](1);
        values[0] = value;
    }

    /*//////////////////////////////////////////////////////////////
          SUP-21256 ACCEPTANCE: DE-DUPLICATION ACROSS MARKETS
    //////////////////////////////////////////////////////////////*/

    /// @notice THE HEADLINE CRITERION, in miniature: N markets sharing one borrow reserve return N distinct
    ///         collateral positions and exactly ONE debt position. This is the live MAG7 shape (seven
    ///         equity markets, one USDC loan reserve) and the reason the snapshot — not a per-market read —
    ///         is the portfolio path.
    function test_SharedBorrowReserveYieldsOneDebtPositionForManyMarkets() public {
        // two markets over distinct collateral reserves (0 equity, 2 weth) sharing loan reserve 1 (USDC)
        address[] memory keys = new address[](2);
        keys[0] = marketKey; // (0, 1)
        keys[1] = secondMarketKey; // (2, 1)

        (IAaveV4OwnerSnapshot.MarketBinding[] memory markets, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions,) =
            oracle.getOwnerSnapshot(owner, keys, new address[](0), new address[](0), address(equity), 128);

        assertEq(markets.length, 2, "both markets bound");
        assertEq(markets[0].debtKey, markets[1].debtKey, "they share the loan reserve's DEBT leg");
        assertTrue(markets[0].supplyKey != markets[1].supplyKey, "but not their collateral legs");

        // 2 collateral legs + 1 shared debt leg = 3, not 4
        assertEq(positions.length, 3, "the shared debt leg is returned ONCE");
        uint256 debtRows;
        for (uint256 i; i < positions.length; ++i) {
            if (positions[i].sourceKey == markets[0].debtKey) ++debtRows;
        }
        assertEq(debtRows, 1, "exactly one row for the shared debt leg");
    }

    /// @notice Markets sharing a COLLATERAL reserve return that supply position once too — the dedup is per
    ///         leg key, not per side, so it holds in both directions.
    function test_SharedCollateralReserveYieldsOneSupplyPosition() public {
        // (0, 1) and (0, 2): one collateral reserve, two different loan reserves
        address thirdMarket = registry.registerMarket(address(spoke), 0, 2);
        address[] memory keys = new address[](2);
        keys[0] = marketKey;
        keys[1] = thirdMarket;

        (IAaveV4OwnerSnapshot.MarketBinding[] memory markets, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions,) =
            oracle.getOwnerSnapshot(owner, keys, new address[](0), new address[](0), address(equity), 128);

        assertEq(markets[0].supplyKey, markets[1].supplyKey, "shared collateral leg");
        uint256 supplyRows;
        for (uint256 i; i < positions.length; ++i) {
            if (positions[i].sourceKey == markets[0].supplyKey) ++supplyRows;
        }
        assertEq(supplyRows, 1, "the shared collateral leg is returned ONCE");
    }

    /// @notice Every unique requested market gets a binding whose derived keys match the registry's own
    ///         derivations, and both legs appear in `positions` EVEN WHEN THEIR BALANCE IS ZERO — a caller
    ///         must be able to verify coverage rather than infer it from the rows that happen to be nonzero.
    function test_BindingsCoverBothLegsIncludingZeroBalances() public {
        // reserve 2 (weth) has no position for this owner at all; (2,1) is registered in setUp
        address zeroMarket = secondMarketKey;
        (IAaveV4OwnerSnapshot.MarketBinding[] memory markets, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions,) =
            oracle.getOwnerSnapshot(owner, one(zeroMarket), new address[](0), new address[](0), address(equity), 128);

        assertEq(markets.length, 1);
        assertEq(markets[0].marketKey, zeroMarket, "binding echoes the requested key");
        assertEq(markets[0].spoke, address(spoke));
        assertEq(markets[0].supplyReserveId, 2);
        assertEq(markets[0].borrowReserveId, 1);
        assertEq(markets[0].supplyKey, registry.computeReserveKey(address(spoke), 2), "derived supply key");
        assertEq(markets[0].debtKey, registry.computeDebtKey(address(spoke), 1), "derived debt key");

        bool sawZeroSupply;
        for (uint256 i; i < positions.length; ++i) {
            if (positions[i].sourceKey == markets[0].supplyKey) {
                sawZeroSupply = true;
                assertEq(positions[i].assets, 0, "the zero-balance leg is still reported");
            }
        }
        assertTrue(sawZeroSupply, "a zero-balance leg must still be covered");
    }

    /// @notice Discovered debt that is already a requested market's leg is not added twice: the discovery
    ///         pass dedups against the legs the markets contributed.
    function test_DiscoveredDebtDoesNotDuplicateARequestedLeg() public {
        (, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions,) =
            oracle.getOwnerSnapshot(owner, one(marketKey), one(address(spoke)), new address[](0), address(equity), 128);

        // reserve 1 debt is BOTH the market's debt leg and discoverable on the spoke
        address usdcDebt = registry.computeDebtKey(address(spoke), 1);
        uint256 rows;
        for (uint256 i; i < positions.length; ++i) {
            if (positions[i].sourceKey == usdcDebt) ++rows;
        }
        assertEq(rows, 1, "requested leg and discovered debt collapse to one row");
    }

    /// @notice A zero market key in the input fails the snapshot rather than being skipped.
    function test_ZeroMarketKeyReverts() public {
        vm.expectRevert(AaveV4ReserveOracle.ZERO_ADDRESS.selector);
        oracle.getOwnerSnapshot(owner, one(address(0)), new address[](0), new address[](0), address(equity), 128);
    }

    /*//////////////////////////////////////////////////////////////
       SUP-21259: COLLATERAL DROPOUT AFTER MARKET REMOVAL
    //////////////////////////////////////////////////////////////*/

    /// @notice THE BUG. Debt was discovered on covered spokes while supply arrived only through the
    ///         requested markets, so removing the last market naming a supply reserve dropped its
    ///         collateral from NAV while its debt kept counting — PPS falls on a snapshot that is merely
    ///         incomplete. Discovery is now symmetric: the residual collateral comes back as its own
    ///         position, because its SUPPLY leg is registered.
    function test_ResidualCollateralOutsideRequestedMarkets_IsIncludedWhenRegistered() public {
        // the owner supplies reserve 2 (weth) and owes on reserve 1 (usdc); only the (0,1) market is asked for
        spoke.setPosition(2, owner, 7e18, 0, 0);

        (, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions,) =
            oracle.getOwnerSnapshot(owner, one(marketKey), one(address(spoke)), new address[](0), address(equity), 128);

        address residualKey = registry.computeReserveKey(address(spoke), 2);
        bool found;
        for (uint256 i; i < positions.length; ++i) {
            if (positions[i].sourceKey == residualKey) {
                found = true;
                assertEq(positions[i].side, 0, "returned as a SUPPLY leg");
                assertEq(positions[i].assets, 7e18, "with the live supplied amount, not zero");
            }
        }
        assertTrue(found, "collateral outside the requested markets must not be omitted");
    }

    /// @notice And it is counted ONCE: a market that does cover the reserve contributes it, and discovery
    ///         must not add a second row for the same leg.
    function test_ResidualCollateralCoveredByAnotherMarket_IsCountedOnce() public {
        spoke.setPosition(2, owner, 7e18, 0, 0);
        address[] memory keys = new address[](2);
        keys[0] = marketKey; // (0,1)
        keys[1] = secondMarketKey; // (2,1) — covers reserve 2's supply leg

        (, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions,) =
            oracle.getOwnerSnapshot(owner, keys, one(address(spoke)), new address[](0), address(equity), 128);

        address supplyKey2 = registry.computeReserveKey(address(spoke), 2);
        uint256 rows;
        for (uint256 i; i < positions.length; ++i) {
            if (positions[i].sourceKey == supplyKey2) ++rows;
        }
        assertEq(rows, 1, "covered collateral is contributed once, not once per discovery path");
    }

    /// @notice STRICT, no silent omission: residual collateral whose SUPPLY leg is NOT registered fails the
    ///         whole snapshot. The alternative — dropping it — is the very bug this closes, and resolving it
    ///         through an unregistered key is not an option either.
    function test_ResidualCollateralWithUnregisteredLeg_RevertsTheSnapshot() public {
        address token = address(new SnapshotToken("FRESH", 18));
        // the id is whatever the spoke appends it as — a hardcoded one would silently fall outside
        // `getReserveCount()` and never be scanned, making this assertion vacuous
        uint256 freshId = spoke.addReserve(token, 18);
        spoke.setPosition(freshId, owner, 3e18, 0, 0);

        // the reserve is listed on the spoke and holds collateral, but was never registered
        assertFalse(registry.isRegistered(registry.computeReserveKey(address(spoke), freshId)), "unregistered");

        vm.expectRevert(
            abi.encodeWithSelector(AaveV4ReserveOracle.UNCOVERED_COLLATERAL.selector, address(spoke), freshId)
        );
        oracle.getOwnerSnapshot(owner, one(marketKey), one(address(spoke)), new address[](0), address(equity), 128);
    }

    /// @notice A fully withdrawn position is not residual collateral: zero supplied means nothing to cover,
    ///         so no extra row and no revert. Without this, every unused reserve on a covered spoke would
    ///         either bloat the response or fail the call.
    function test_FullyWithdrawnPositionIsNotTreatedAsResidualCollateral() public {
        address token = address(new SnapshotToken("EMPTY", 18));
        uint256 freshId = spoke.addReserve(token, 18);
        spoke.setPosition(freshId, owner, 0, 0, 0); // listed, unregistered, but empty
        assertFalse(registry.isRegistered(registry.computeReserveKey(address(spoke), freshId)), "unregistered");

        (, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions,) =
            oracle.getOwnerSnapshot(owner, one(marketKey), one(address(spoke)), new address[](0), address(equity), 128);

        for (uint256 i; i < positions.length; ++i) {
            assertTrue(
                positions[i].sourceKey != registry.computeReserveKey(address(spoke), freshId),
                "an empty reserve contributes no row"
            );
        }
    }

    /// @notice Debt and cash accounting are unchanged by the new supply discovery: the debt leg is still
    ///         discovered once and the cash set still excludes the vault asset.
    function test_ResidualCollateralDoesNotDisturbDebtOrCash() public {
        spoke.setPosition(2, owner, 7e18, 0, 0);

        (, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions, IAaveV4OwnerSnapshot.WalletBalance[] memory cash) = oracle.getOwnerSnapshot(
            owner, one(marketKey), one(address(spoke)), one(address(usdc)), address(equity), 128
        );

        address usdcDebt = registry.computeDebtKey(address(spoke), 1);
        uint256 debtRows;
        for (uint256 i; i < positions.length; ++i) {
            if (positions[i].sourceKey == usdcDebt) ++debtRows;
        }
        assertEq(debtRows, 1, "debt still discovered exactly once");
        for (uint256 i; i < cash.length; ++i) {
            assertTrue(cash[i].token != address(equity), "vault asset still excluded from cash");
        }
    }
}
