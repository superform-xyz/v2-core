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
        spoke.setPosition(0, owner, 100e8, 0, 0);
        spoke.setPosition(1, owner, 0, 100e6, 2e6);
        usdc.mint(owner, 30e6);
        weth.mint(owner, 9e18);
    }

    function test_OwnerSnapshotDiscoversDebtAccrualAndCash() public {
        vm.expectCall(address(usdc), abi.encodeWithSignature("balanceOf(address)", owner), uint64(1));
        (
            uint256 version,
            IAaveV4OwnerSnapshot.OwnerPosition[] memory positions,
            IAaveV4OwnerSnapshot.WalletBalance[] memory cash
        ) = oracle.getOwnerSnapshot(owner, one(supplyKey), new address[](0), one(address(usdc)), address(equity), 128);
        assertEq(version, 1);
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
        keys[0] = supplyKey;
        keys[1] = debtKey;
        keys[2] = supplyKey;
        address[] memory spokes = new address[](2);
        spokes[0] = address(spoke);
        spokes[1] = address(spoke);
        vm.expectCall(address(spoke), abi.encodeWithSignature("getReserveCount()"), uint64(1));
        vm.expectCall(address(usdc), abi.encodeWithSignature("balanceOf(address)", owner), uint64(1));
        (, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions, IAaveV4OwnerSnapshot.WalletBalance[] memory cash) =
            oracle.getOwnerSnapshot(owner, keys, spokes, one(address(usdc)), address(equity), 128);
        assertEq(positions.length, 2);
        assertEq(cash.length, 1);
    }

    function test_MultipleDebtsKeepEachTokenOnce() public {
        spoke.setPosition(2, owner, 0, 2e18, 1e16);
        (, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions, IAaveV4OwnerSnapshot.WalletBalance[] memory cash) =
            oracle.getOwnerSnapshot(owner, one(supplyKey), new address[](0), one(address(usdc)), address(equity), 128);
        assertEq(positions.length, 3);
        assertEq(cash.length, 2);
        assertEq(cash[0].token, address(usdc));
        assertEq(cash[1].token, address(weth));
        assertEq(cash[1].balance, 9e18);
        assertEq(positions[2].assets, 2e18 + 1e16);
    }

    function test_SameReserveSupplyAndDebtKeepSeparateKeys() public {
        spoke.setPosition(0, owner, 100e8, 1e8, 1);
        (, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions,) =
            oracle.getOwnerSnapshot(owner, one(supplyKey), new address[](0), new address[](0), address(equity), 128);
        assertEq(positions.length, 3);
        assertEq(positions[1].sourceKey, registry.computeDebtKey(address(spoke), 0));
        assertEq(positions[1].side, 1);
        assertEq(positions[1].assets, 1e8 + 1);
    }

    function test_TwoSpokesShareOneCashBalance() public {
        SnapshotSpoke other = new SnapshotSpoke();
        other.addReserve(address(usdc), 6);
        other.setPosition(0, owner, 0, 50e6, 1e6);
        registry.registerReserve(address(other), 0);
        vm.expectCall(address(usdc), abi.encodeWithSignature("balanceOf(address)", owner), uint64(1));
        (, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions, IAaveV4OwnerSnapshot.WalletBalance[] memory cash) =
            oracle.getOwnerSnapshot(owner, one(supplyKey), one(address(other)), new address[](0), address(equity), 128);
        assertEq(positions.length, 3);
        assertEq(cash.length, 1);
        assertEq(cash[0].balance, 30e6);
    }

    function test_VaultUnderlyingCashIsNotReadTwice() public {
        vm.mockCallRevert(address(usdc), abi.encodeWithSignature("balanceOf(address)", owner), bytes("must not read"));
        (,, IAaveV4OwnerSnapshot.WalletBalance[] memory cash) =
            oracle.getOwnerSnapshot(owner, one(supplyKey), new address[](0), one(address(usdc)), address(usdc), 128);
        assertEq(cash.length, 0);
    }

    function test_EmptySourcesStillDiscoverConfiguredSpoke() public {
        (, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions,) = oracle.getOwnerSnapshot(
            owner, new address[](0), one(address(spoke)), new address[](0), address(equity), 128
        );
        assertEq(positions.length, 1);
        assertEq(positions[0].sourceKey, debtKey);
    }

    function test_AfterRepaymentExplicitCashPersistsWithoutWalletSweep() public {
        spoke.setPosition(1, owner, 0, 0, 0);
        (, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions, IAaveV4OwnerSnapshot.WalletBalance[] memory cash) = oracle.getOwnerSnapshot(
            owner, new address[](0), one(address(spoke)), one(address(usdc)), address(equity), 128
        );
        assertEq(positions.length, 0);
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
            oracle.getOwnerSnapshot(owner, one(supplyKey), new address[](0), new address[](0), address(equity), 128);
        assertEq(positions.length, 3);
        assertEq(positions[2].sourceKey, key);
    }

    function test_DeregisteredDebtRevertsEntireSnapshot() public {
        registry.proposeDeregisterReserve(debtKey);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        registry.executeDeregisterReserve(debtKey);
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.getOwnerSnapshot(owner, one(supplyKey), new address[](0), new address[](0), address(equity), 128);
    }

    function test_UnavailableSymbolDoesNotBlockAccounting() public {
        vm.mockCallRevert(address(usdc), abi.encodeWithSignature("symbol()"), bytes("optional metadata"));
        (, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions, IAaveV4OwnerSnapshot.WalletBalance[] memory cash) =
            oracle.getOwnerSnapshot(owner, one(supplyKey), new address[](0), new address[](0), address(equity), 128);
        assertEq(positions[1].symbol, "");
        assertEq(positions[1].assets, 102e6);
        assertEq(cash[0].balance, 30e6);
    }

    function testFuzz_MalformedSymbolDoesNotBlockAccounting(bytes32 malformed) public {
        // Legacy bytes32 metadata is not ABI encoded string metadata.
        vm.mockCall(address(usdc), abi.encodeWithSignature("symbol()"), abi.encode(malformed));
        (, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions,) =
            oracle.getOwnerSnapshot(owner, one(debtKey), new address[](0), new address[](0), address(equity), 128);
        assertEq(positions[0].symbol, "");
        assertEq(positions[0].assets, 102e6);
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
                oracle.getOwnerSnapshot(owner, one(debtKey), new address[](0), new address[](0), address(equity), 128);
            assertEq(positions[0].symbol, "");
            assertEq(positions[0].assets, 102e6);
        }
    }

    function test_MaximumSymbolLengthIsAccepted() public {
        string memory symbol = string(new bytes(256));
        vm.mockCall(address(usdc), abi.encodeWithSignature("symbol()"), abi.encode(symbol));
        (, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions,) =
            oracle.getOwnerSnapshot(owner, one(debtKey), new address[](0), new address[](0), address(equity), 128);
        assertEq(positions[0].symbol, symbol);
        assertEq(positions[0].assets, 102e6);
    }

    function test_UnreadableCashFailsWithoutFallback() public {
        vm.mockCallRevert(address(usdc), abi.encodeWithSignature("balanceOf(address)", owner), bytes("unreadable"));
        vm.expectRevert(bytes("unreadable"));
        oracle.getOwnerSnapshot(owner, one(supplyKey), new address[](0), new address[](0), address(equity), 128);
    }

    function test_UnreadableStatusFailsWithoutFallback() public {
        spoke.setFailStatus(true);
        vm.expectRevert(SnapshotSpoke.UnreadableStatus.selector);
        oracle.getOwnerSnapshot(owner, one(supplyKey), new address[](0), new address[](0), address(equity), 128);
    }

    function test_ReserveLimitRevertsInsteadOfTruncatingDebt() public {
        vm.expectRevert(AaveV4ReserveOracle.SNAPSHOT_RESERVE_LIMIT.selector);
        oracle.getOwnerSnapshot(owner, one(supplyKey), new address[](0), new address[](0), address(equity), 2);
    }

    function testFuzz_AccruedDebtMatchesExistingOracle(uint128 drawn, uint128 premium) public {
        spoke.setPosition(1, owner, 0, drawn, premium);
        (, IAaveV4OwnerSnapshot.OwnerPosition[] memory positions,) =
            oracle.getOwnerSnapshot(owner, one(debtKey), new address[](0), new address[](0), address(equity), 128);
        assertEq(positions[0].assets, uint256(drawn) + premium);
        assertEq(positions[0].assets, oracle.getBalanceOfOwner(debtKey, owner));
    }

    function one(address value) private pure returns (address[] memory values) {
        values = new address[](1);
        values[0] = value;
    }
}
