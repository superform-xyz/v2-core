// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Helpers } from "../../utils/Helpers.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { DETHYieldSourceOracle } from "../../../src/accounting/oracles/DETHYieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperLedger } from "../../../src/interfaces/accounting/ISuperLedger.sol";
import { SuperLedger } from "../../../src/accounting/SuperLedger.sol";

/*//////////////////////////////////////////////////////////////
                        INLINE MOCKS
//////////////////////////////////////////////////////////////*/

/// @dev Mock DETH token (ERC-20 with 18 decimals)
contract MockDETH {
    string public name = "Dialectic ETH";
    string public symbol = "DETH";
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function burn(address from, uint256 amount) external {
        balanceOf[from] -= amount;
        totalSupply -= amount;
    }

    function setDecimals(uint8 d) external {
        decimals = d;
    }
}

/// @dev Mock Machine vault with configurable conversion rates
contract MockMachine {
    address public shareToken;
    address public accountingToken;
    uint256 public lastTotalAum;

    // Configurable PPS: assetsPerShare = convertToAssets(1e18)
    uint256 private _assetsPerShare = 1e18; // 1:1 default

    // If > 0, convertToAssets reverts for inputs above this threshold
    uint256 private _revertAbove;

    constructor(address deth_, address weth_) {
        shareToken = deth_;
        accountingToken = weth_;
        lastTotalAum = 1000e18;
    }

    function convertToAssets(uint256 shares) external view returns (uint256) {
        require(_revertAbove == 0 || shares <= _revertAbove, "convertToAssets: input too large");
        return Math.mulDiv(shares, _assetsPerShare, 1e18);
    }

    function setRevertAbove(uint256 threshold) external {
        _revertAbove = threshold;
    }

    function convertToShares(uint256 assets) external view returns (uint256) {
        if (_assetsPerShare == 0) return 0;
        return Math.mulDiv(assets, 1e18, _assetsPerShare);
    }

    function setAssetsPerShare(uint256 newRate) external {
        _assetsPerShare = newRate;
    }

    function setLastTotalAum(uint256 newAum) external {
        lastTotalAum = newAum;
    }
}

/// @dev Mock AsyncRedeemer with configurable pending requests
contract MockAsyncRedeemer {
    address public machine;

    uint256 private _nextRequestId = 1;
    uint256 private _lastFinalizedRequestId;

    bool public revertOnLastFinalizedRequestId;
    bool public revertOnNextRequestId;

    // requestId => shares locked
    mapping(uint256 => uint256) private _requestShares;
    // requestId => owner
    mapping(uint256 => address) private _requestOwner;
    // requestId => exists
    mapping(uint256 => bool) private _requestExists;
    // requestId => revert on getShares
    mapping(uint256 => bool) private _revertGetShares;

    constructor(address machine_) {
        machine = machine_;
    }

    function nextRequestId() external view returns (uint256) {
        require(!revertOnNextRequestId, "nextRequestId reverted");
        return _nextRequestId;
    }

    function lastFinalizedRequestId() external view returns (uint256) {
        require(!revertOnLastFinalizedRequestId, "lastFinalizedRequestId reverted");
        return _lastFinalizedRequestId;
    }

    function getShares(uint256 requestId) external view returns (uint256) {
        require(!_revertGetShares[requestId], "getShares reverted");
        require(_requestExists[requestId], "Request does not exist");
        return _requestShares[requestId];
    }

    function ownerOf(uint256 requestId) external view returns (address) {
        require(_requestExists[requestId], "ERC721: invalid token ID");
        return _requestOwner[requestId];
    }

    // --- Test helpers ---

    function mockRequestRedeem(address owner, uint256 shares) external returns (uint256 requestId) {
        requestId = _nextRequestId++;
        _requestShares[requestId] = shares;
        _requestOwner[requestId] = owner;
        _requestExists[requestId] = true;
    }

    /// @dev Create a request where ownerOf succeeds but getShares reverts
    function mockRequestRedeemWithBrokenShares(address owner) external returns (uint256 requestId) {
        requestId = _nextRequestId++;
        _requestOwner[requestId] = owner;
        _requestExists[requestId] = true;
        _revertGetShares[requestId] = true;
    }

    function mockFinalizeUpTo(uint256 upTo) external {
        _lastFinalizedRequestId = upTo;
    }

    function mockClaimRequest(uint256 requestId) external {
        delete _requestExists[requestId];
        delete _requestOwner[requestId];
        delete _requestShares[requestId];
    }

    function setRevertOnLastFinalizedRequestId(bool val) external {
        revertOnLastFinalizedRequestId = val;
    }

    function setRevertOnNextRequestId(bool val) external {
        revertOnNextRequestId = val;
    }

    /// @dev Bulk-create N pending requests for a single owner
    function mockBulkRequestRedeem(address owner, uint256 shares, uint256 count) external {
        for (uint256 i; i < count; ++i) {
            uint256 requestId = _nextRequestId++;
            _requestShares[requestId] = shares;
            _requestOwner[requestId] = owner;
            _requestExists[requestId] = true;
        }
    }

    function requestRedeem(uint256, address, uint256) external pure returns (uint256) {
        revert("use mockRequestRedeem");
    }

    function claimAssets(uint256) external pure returns (uint256) {
        revert("use mockClaimRequest");
    }
}

/*//////////////////////////////////////////////////////////////
                        TEST CONTRACT
//////////////////////////////////////////////////////////////*/

/// @title DETHYieldSourceOracleTest
/// @notice Comprehensive test suite for DETHYieldSourceOracle
/// @dev Tests all 8 oracle functions + pending redemption TVL tracking
contract DETHYieldSourceOracleTest is Helpers {
    DETHYieldSourceOracle public oracle;
    ISuperLedgerConfiguration public ledgerConfig;
    ISuperLedger public ledger;

    MockDETH public deth;
    MockMachine public machine;
    MockAsyncRedeemer public asyncRedeemer;

    address public superVault;

    function setUp() public {
        // Deploy mocks
        deth = new MockDETH();
        machine = new MockMachine(address(deth), makeAddr("WETH"));
        asyncRedeemer = new MockAsyncRedeemer(address(machine));

        // Deploy configuration and oracle
        ledgerConfig = ISuperLedgerConfiguration(address(new SuperLedgerConfiguration()));
        address[] memory allowedExecutors = new address[](1);
        allowedExecutors[0] = address(0x777);
        ledger = ISuperLedger(address(new SuperLedger(address(ledgerConfig), allowedExecutors)));

        oracle = new DETHYieldSourceOracle(address(ledgerConfig), address(1));

        superVault = makeAddr("superVault");
    }

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify dynamic resolution works correctly through AsyncRedeemer → Machine → tokens
    function test_constructor_dynamicResolution() public view {
        // Oracle resolves addresses dynamically via yieldSourceAddress
        assertEq(oracle.decimals(address(asyncRedeemer)), 18);
        assertEq(oracle.getPricePerShare(address(asyncRedeemer)), 1e18);
    }

    /// @notice Constructor reverts when foundation_ is address(0)
    function test_constructor_revertsOnZeroFoundation() public {
        vm.expectRevert(DETHYieldSourceOracle.ZERO_ADDRESS.selector);
        new DETHYieldSourceOracle(address(ledgerConfig), address(0));
    }

    /// @notice Constructor accepts any non-zero foundation address
    function test_constructor_acceptsNonZeroFoundation() public {
        address foundation = makeAddr("foundation");
        DETHYieldSourceOracle o = new DETHYieldSourceOracle(address(ledgerConfig), foundation);
        assertEq(o.FOUNDATION(), foundation);
    }

    /// @notice FOUNDATION immutable is set correctly on default oracle
    function test_constructor_foundationImmutableIsSet() public view {
        assertEq(oracle.FOUNDATION(), address(1));
    }

    /// @notice Fuzz: constructor accepts any non-zero foundation
    function testFuzz_constructor_acceptsNonZero(address foundation) public {
        vm.assume(foundation != address(0));
        DETHYieldSourceOracle o = new DETHYieldSourceOracle(address(ledgerConfig), foundation);
        assertEq(o.FOUNDATION(), foundation);
    }

    /*//////////////////////////////////////////////////////////////
                            DECIMALS TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test decimals() returns DETH token decimals (18)
    function test_decimals() public view {
        assertEq(oracle.decimals(address(asyncRedeemer)), 18);
    }

    /// @notice Test decimals() uses yieldSourceAddress to resolve share token
    function test_decimals_usesYieldSourceAddress() public view {
        // Must pass a valid AsyncRedeemer address (dynamic resolution)
        assertEq(oracle.decimals(address(asyncRedeemer)), 18);
    }

    /*//////////////////////////////////////////////////////////////
                        GET SHARE OUTPUT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test getShareOutput() at 1:1 rate
    function test_getShareOutput_oneToOne() public view {
        uint256 assetsIn = 100e18;
        uint256 shares = oracle.getShareOutput(address(asyncRedeemer), address(0), assetsIn);
        assertEq(shares, assetsIn);
    }

    /// @notice Test getShareOutput() at non-1:1 rate (1 DETH = 1.5 WETH)
    function test_getShareOutput_nonOneToOne() public {
        machine.setAssetsPerShare(1.5e18);
        uint256 assetsIn = 150e18;
        uint256 shares = oracle.getShareOutput(address(asyncRedeemer), address(0), assetsIn);
        assertEq(shares, 100e18); // 150 WETH / 1.5 = 100 DETH
    }

    /// @notice Test getShareOutput() with zero input returns zero
    function test_getShareOutput_zeroInput() public view {
        assertEq(oracle.getShareOutput(address(asyncRedeemer), address(0), 0), 0);
    }

    /// @notice Fuzz test getShareOutput()
    function testFuzz_getShareOutput(uint256 assetsIn) public view {
        assetsIn = bound(assetsIn, 0, type(uint128).max);
        uint256 shares = oracle.getShareOutput(address(asyncRedeemer), address(0), assetsIn);
        if (assetsIn == 0) {
            assertEq(shares, 0);
        } else {
            assertEq(shares, machine.convertToShares(assetsIn));
        }
    }

    /*//////////////////////////////////////////////////////////////
                    WITHDRAWAL SHARE OUTPUT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test getWithdrawalShareOutput() at 1:1 rate
    function test_getWithdrawalShareOutput_oneToOne() public view {
        uint256 assetsIn = 100e18;
        uint256 shares = oracle.getWithdrawalShareOutput(address(asyncRedeemer), address(0), assetsIn);
        assertEq(shares, assetsIn);
    }

    /// @notice Test getWithdrawalShareOutput() uses Ceil rounding (favors vault)
    function test_getWithdrawalShareOutput_ceilRounding() public {
        // Set PPS so that exact division doesn't work
        machine.setAssetsPerShare(3e18); // 1 DETH = 3 WETH

        // 10 WETH / 3 = 3.333... DETH → should round UP to 4 DETH (ceil)
        uint256 shares = oracle.getWithdrawalShareOutput(address(asyncRedeemer), address(0), 10e18);
        uint256 expectedCeil = Math.mulDiv(10e18, 1e18, 3e18, Math.Rounding.Ceil);
        assertEq(shares, expectedCeil);
        // Verify it's actually ceil (greater than floor)
        uint256 expectedFloor = Math.mulDiv(10e18, 1e18, 3e18, Math.Rounding.Floor);
        assertGt(shares, expectedFloor);
    }

    /// @notice Test getWithdrawalShareOutput() with zero PPS returns zero
    function test_getWithdrawalShareOutput_zeroPPS() public {
        machine.setAssetsPerShare(0);
        assertEq(oracle.getWithdrawalShareOutput(address(asyncRedeemer), address(0), 100e18), 0);
    }

    /// @notice Test getWithdrawalShareOutput() with zero input returns zero
    function test_getWithdrawalShareOutput_zeroInput() public view {
        assertEq(oracle.getWithdrawalShareOutput(address(asyncRedeemer), address(0), 0), 0);
    }

    /// @notice Fuzz test: withdrawal shares >= regular shares (ceil vs floor)
    function testFuzz_getWithdrawalShareOutput_ceilVsFloor(uint256 assetsIn, uint256 pps) public {
        assetsIn = bound(assetsIn, 1, type(uint128).max);
        pps = bound(pps, 1, type(uint128).max);
        machine.setAssetsPerShare(pps);

        uint256 withdrawalShares = oracle.getWithdrawalShareOutput(address(asyncRedeemer), address(0), assetsIn);
        uint256 regularShares = oracle.getShareOutput(address(asyncRedeemer), address(0), assetsIn);

        // Ceil rounding should produce >= floor rounding
        assertGe(withdrawalShares, regularShares);
    }

    /*//////////////////////////////////////////////////////////////
                        GET ASSET OUTPUT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test getAssetOutput() at 1:1 rate
    function test_getAssetOutput_oneToOne() public view {
        uint256 sharesIn = 100e18;
        uint256 assets = oracle.getAssetOutput(address(asyncRedeemer), address(0), sharesIn);
        assertEq(assets, sharesIn);
    }

    /// @notice Test getAssetOutput() at non-1:1 rate
    function test_getAssetOutput_nonOneToOne() public {
        machine.setAssetsPerShare(2e18); // 1 DETH = 2 WETH
        uint256 assets = oracle.getAssetOutput(address(asyncRedeemer), address(0), 100e18);
        assertEq(assets, 200e18);
    }

    /// @notice Test getAssetOutput() with zero input returns zero
    function test_getAssetOutput_zeroInput() public view {
        assertEq(oracle.getAssetOutput(address(asyncRedeemer), address(0), 0), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        PRICE PER SHARE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test getPricePerShare() at 1:1 rate
    function test_getPricePerShare_oneToOne() public view {
        assertEq(oracle.getPricePerShare(address(asyncRedeemer)), 1e18);
    }

    /// @notice Test getPricePerShare() at non-1:1 rate
    function test_getPricePerShare_nonOneToOne() public {
        machine.setAssetsPerShare(1.5e18);
        assertEq(oracle.getPricePerShare(address(asyncRedeemer)), 1.5e18);
    }

    /// @notice Test getPricePerShare() reflects changes
    function test_getPricePerShare_reflectsChanges() public {
        machine.setAssetsPerShare(1e18);
        assertEq(oracle.getPricePerShare(address(asyncRedeemer)), 1e18);

        machine.setAssetsPerShare(2e18);
        assertEq(oracle.getPricePerShare(address(asyncRedeemer)), 2e18);
    }

    /*//////////////////////////////////////////////////////////////
                        BALANCE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test getBalanceOfOwner() returns DETH balance
    function test_getBalanceOfOwner() public {
        deth.mint(superVault, 100e18);
        assertEq(oracle.getBalanceOfOwner(address(asyncRedeemer), superVault), 100e18);
    }

    /// @notice Test getBalanceOfOwner() returns zero for empty account
    function test_getBalanceOfOwner_zero() public view {
        assertEq(oracle.getBalanceOfOwner(address(asyncRedeemer), superVault), 0);
    }

    /// @notice Test getBalanceOfOwner() uses yieldSourceAddress to resolve share token
    function test_getBalanceOfOwner_usesYieldSourceAddress() public {
        deth.mint(superVault, 50e18);
        assertEq(oracle.getBalanceOfOwner(address(asyncRedeemer), superVault), 50e18);
    }

    /*//////////////////////////////////////////////////////////////
                        TVL TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test getTVL() returns Machine's lastTotalAum
    function test_getTVL() public view {
        assertEq(oracle.getTVL(address(asyncRedeemer)), 1000e18);
    }

    /// @notice Test getTVL() reflects changes
    function test_getTVL_reflectsChanges() public {
        machine.setLastTotalAum(5000e18);
        assertEq(oracle.getTVL(address(asyncRedeemer)), 5000e18);
    }

    /*//////////////////////////////////////////////////////////////
                TVL BY OWNER TESTS (KEY FUNCTIONALITY)
    //////////////////////////////////////////////////////////////*/

    /// @notice Test getTVLByOwnerOfShares() with only held shares (no pending)
    function test_getTVLByOwner_heldOnly() public {
        deth.mint(superVault, 100e18);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        assertEq(tvl, 100e18); // 1:1 rate
    }

    /// @notice Test getTVLByOwnerOfShares() with non-1:1 rate, held only
    function test_getTVLByOwner_heldOnly_nonOneToOne() public {
        machine.setAssetsPerShare(2e18);
        deth.mint(superVault, 100e18);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        assertEq(tvl, 200e18); // 100 DETH * 2 = 200 WETH
    }

    /// @notice Test getTVLByOwnerOfShares() includes pending redemption value
    function test_getTVLByOwner_includesPending() public {
        // Held: 100 DETH
        deth.mint(superVault, 100e18);

        // Pending: 1 request with 50 DETH
        asyncRedeemer.mockRequestRedeem(superVault, 50e18);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        // held(100) + pending(50) = 150 WETH at 1:1
        assertEq(tvl, 150e18);
    }

    /// @notice Test getTVLByOwnerOfShares() with multiple pending requests
    function test_getTVLByOwner_multiplePending() public {
        deth.mint(superVault, 100e18);

        // 3 pending requests
        asyncRedeemer.mockRequestRedeem(superVault, 10e18);
        asyncRedeemer.mockRequestRedeem(superVault, 20e18);
        asyncRedeemer.mockRequestRedeem(superVault, 30e18);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        // held(100) + pending(10+20+30) = 160 at 1:1
        assertEq(tvl, 160e18);
    }

    /// @notice Test getTVLByOwnerOfShares() only counts requests owned by the specified address
    function test_getTVLByOwner_filtersOwner() public {
        address otherUser = makeAddr("otherUser");

        deth.mint(superVault, 100e18);
        deth.mint(otherUser, 50e18);

        // superVault has 1 request
        asyncRedeemer.mockRequestRedeem(superVault, 10e18);
        // otherUser has 2 requests
        asyncRedeemer.mockRequestRedeem(otherUser, 20e18);
        asyncRedeemer.mockRequestRedeem(otherUser, 30e18);

        uint256 tvlSV = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        uint256 tvlOther = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), otherUser);

        assertEq(tvlSV, 110e18); // held(100) + pending(10)
        assertEq(tvlOther, 100e18); // held(50) + pending(20+30)
    }

    /// @notice Test getTVLByOwnerOfShares() excludes finalized requests
    function test_getTVLByOwner_excludesFinalized() public {
        deth.mint(superVault, 100e18);

        // Create 3 requests (IDs 1, 2, 3)
        asyncRedeemer.mockRequestRedeem(superVault, 10e18);
        asyncRedeemer.mockRequestRedeem(superVault, 20e18);
        asyncRedeemer.mockRequestRedeem(superVault, 30e18);

        // Finalize requests 1 and 2
        asyncRedeemer.mockFinalizeUpTo(2);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        // Only request 3 is pending now: held(100) + pending(30)
        assertEq(tvl, 130e18);
    }

    /// @notice Test getTVLByOwnerOfShares() with only pending (zero held)
    function test_getTVLByOwner_onlyPending() public {
        asyncRedeemer.mockRequestRedeem(superVault, 50e18);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        assertEq(tvl, 50e18);
    }

    /// @notice Test getTVLByOwnerOfShares() with zero position
    function test_getTVLByOwner_zeroPosition() public view {
        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        assertEq(tvl, 0);
    }

    /// @notice KEY TEST: PPS stability during requestRedeem
    /// @dev After requestRedeem(), held DETH decreases but pending increases by the same amount
    function test_getTVLByOwner_ppsStabilityOnRequest() public {
        uint256 initialShares = 100e18;
        deth.mint(superVault, initialShares);

        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);

        // Simulate requestRedeem: burn 30 DETH from user, create pending NFT
        uint256 redeemShares = 30e18;
        deth.burn(superVault, redeemShares);
        asyncRedeemer.mockRequestRedeem(superVault, redeemShares);

        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);

        assertEq(tvlBefore, tvlAfter, "TVL should remain stable during requestRedeem");
    }

    /// @notice Test pending value with non-1:1 exchange rate
    function test_getTVLByOwner_pendingWithNonOneToOneRate() public {
        machine.setAssetsPerShare(1.5e18); // 1 DETH = 1.5 WETH

        deth.mint(superVault, 100e18);
        asyncRedeemer.mockRequestRedeem(superVault, 50e18);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        // held: 100 * 1.5 = 150, pending: 50 * 1.5 = 75 → total: 225
        assertEq(tvl, 225e18);
    }

    /// @notice Test graceful degradation when no pending requests exist
    function test_getTVLByOwner_noPendingRange() public {
        deth.mint(superVault, 100e18);

        // nextRequestId == lastFinalizedRequestId + 1 (no pending)
        // Default: nextRequestId=1, lastFinalizedRequestId=0 → no pending
        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        assertEq(tvl, 100e18);
    }

    /// @notice Test that claimed (burned) NFTs are skipped
    function test_getTVLByOwner_skipsBurnedNFTs() public {
        deth.mint(superVault, 100e18);

        // Create 3 requests
        asyncRedeemer.mockRequestRedeem(superVault, 10e18); // ID 1
        asyncRedeemer.mockRequestRedeem(superVault, 20e18); // ID 2
        asyncRedeemer.mockRequestRedeem(superVault, 30e18); // ID 3

        // Claim request 2 (burns NFT)
        asyncRedeemer.mockClaimRequest(2);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        // held(100) + pending(10+30) = 140 (request 2 excluded)
        assertEq(tvl, 140e18);
    }

    /*//////////////////////////////////////////////////////////////
                    MAX_PENDING_REQUESTS BOUND TEST
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that iteration is bounded by MAX_PENDING_REQUESTS
    function test_getTVLByOwner_boundedIteration() public view {
        assertEq(oracle.MAX_PENDING_REQUESTS(), 200);
    }

    /// @notice Test that scan is actually capped at MAX_PENDING_REQUESTS when more exist
    function test_getTVLByOwner_cappedAtMaxPendingRequests() public {
        uint256 totalRequests = 210;
        uint256 sharesPerRequest = 1e18;

        // Create 210 pending requests for superVault
        asyncRedeemer.mockBulkRequestRedeem(superVault, sharesPerRequest, totalRequests);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);

        // Only the first 200 are scanned → 200 * 1e18 at 1:1 rate
        uint256 expectedValue = 200 * sharesPerRequest;
        assertEq(tvl, expectedValue, "Should only count MAX_PENDING_REQUESTS");
    }

    /// @notice Test graceful degradation when lastFinalizedRequestId() reverts
    function test_getTVLByOwner_gracefulWhenLastFinalizedReverts() public {
        deth.mint(superVault, 100e18);
        asyncRedeemer.mockRequestRedeem(superVault, 50e18);

        // Make lastFinalizedRequestId() revert
        asyncRedeemer.setRevertOnLastFinalizedRequestId(true);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        // Pending scanning fails gracefully → returns held value only
        assertEq(tvl, 100e18, "Should return held value only when lastFinalizedRequestId reverts");
    }

    /// @notice Test graceful degradation when nextRequestId() reverts
    function test_getTVLByOwner_gracefulWhenNextRequestIdReverts() public {
        deth.mint(superVault, 100e18);
        asyncRedeemer.mockRequestRedeem(superVault, 50e18);

        // Make nextRequestId() revert
        asyncRedeemer.setRevertOnNextRequestId(true);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        // Pending scanning fails gracefully → returns held value only
        assertEq(tvl, 100e18, "Should return held value only when nextRequestId reverts");
    }

    /// @notice Test graceful degradation when Machine.convertToAssets reverts on accumulated pending shares (F-08)
    function test_getTVLByOwner_gracefulWhenConvertToAssetsRevertsOnPending() public {
        deth.mint(superVault, 100e18);

        // Create pending request with 50 DETH
        asyncRedeemer.mockRequestRedeem(superVault, 50e18);

        // Make convertToAssets revert for inputs > 10e18
        // This allows held shares (100e18) conversion to work via the ternary (converts individually),
        // but the accumulated pending shares (50e18) conversion will revert
        // Actually, held shares = 100e18 which is also > 10e18, so we need a smarter threshold.
        // Set threshold so held value conversion works but pending fails.
        // The held value path: convertToAssets(100e18) — this needs to succeed.
        // The pending path: convertToAssets(50e18) — this should fail.
        // We can't easily differentiate since both go through the same function.
        // Instead, set threshold between held shares (100e18) and use a very large pending amount.
        // Let's create a scenario with many pending shares that sum above the threshold.
        asyncRedeemer.mockRequestRedeem(superVault, 200e18); // total pending = 250e18

        // Set threshold: convertToAssets works for <= 100e18 (held), reverts for 250e18 (pending sum)
        machine.setRevertAbove(100e18);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);

        // Held value: 100e18 at 1:1 = 100e18 (convertToAssets(100e18) succeeds, exactly at threshold)
        // Pending value: convertToAssets(250e18) reverts, gracefully returns 0
        assertEq(tvl, 100e18, "Should return held value only when pending convertToAssets reverts");
    }

    /// @notice Test that a request where getShares() reverts is silently skipped
    function test_getTVLByOwner_skipsRequestWithBrokenGetShares() public {
        deth.mint(superVault, 100e18);

        // Normal request: 50 DETH
        asyncRedeemer.mockRequestRedeem(superVault, 50e18);
        // Broken request: ownerOf works but getShares reverts
        asyncRedeemer.mockRequestRedeemWithBrokenShares(superVault);
        // Another normal request: 30 DETH
        asyncRedeemer.mockRequestRedeem(superVault, 30e18);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        // held(100) + pending(50 + 0[skipped] + 30) = 180
        assertEq(tvl, 180e18, "Should skip broken getShares and count the rest");
    }

    /*//////////////////////////////////////////////////////////////
              SINGLE-PASS LOOP (F-04) + FOUNDATION TVL TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice FOUNDATION pending NFTs are included in owner's TVL via single-pass loop
    function test_singlePass_foundationPendingIncludedInOwnerTVL() public {
        // oracle.FOUNDATION() == address(1)
        address foundation = oracle.FOUNDATION();

        // superVault holds 100 DETH, foundation holds 0
        deth.mint(superVault, 100e18);

        // Create pending request owned by FOUNDATION (simulates routed redemption)
        asyncRedeemer.mockRequestRedeem(foundation, 50e18);

        // TVL for superVault should include held(100) + foundation's pending(50) = 150
        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        assertEq(tvl, 150e18, "FOUNDATION pending should be included in owner TVL");
    }

    /// @notice Mixed ownership: owner NFTs + FOUNDATION NFTs + unrelated NFTs in single pass
    function test_singlePass_mixedOwnership_correctAttribution() public {
        address foundation = oracle.FOUNDATION();
        address unrelated = makeAddr("unrelated");

        deth.mint(superVault, 50e18);

        // Create requests: 2 for owner, 2 for foundation, 1 for unrelated
        asyncRedeemer.mockRequestRedeem(superVault, 10e18);   // owner
        asyncRedeemer.mockRequestRedeem(foundation, 20e18);    // foundation
        asyncRedeemer.mockRequestRedeem(unrelated, 30e18);     // unrelated — should NOT be counted
        asyncRedeemer.mockRequestRedeem(superVault, 15e18);    // owner
        asyncRedeemer.mockRequestRedeem(foundation, 25e18);    // foundation

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        // held(50) + owner pending(10+15) + foundation pending(20+25) = 50+25+45 = 120
        assertEq(tvl, 120e18, "Mixed ownership: owner + foundation counted, unrelated excluded");

        // Verify unrelated's own TVL doesn't include foundation
        // unrelated queries: held(0) + pending(30) + foundation pending(20+25) = 75
        // Because FOUNDATION is added for ALL owners (except foundation itself) — this is the F-01 behavior
        uint256 unrelatedTvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), unrelated);
        assertEq(unrelatedTvl, 75e18, "Unrelated also gets foundation attribution (F-01 documented behavior)");
    }

    /// @notice When querying FOUNDATION itself, secondaryOwner is address(0) — no double-count
    function test_singlePass_queryFoundation_noDoubleCount() public {
        address foundation = oracle.FOUNDATION();

        deth.mint(foundation, 40e18);
        asyncRedeemer.mockRequestRedeem(foundation, 60e18);

        // Querying FOUNDATION: held(40) + pending for foundation(60) + secondary=address(0)
        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), foundation);
        assertEq(tvl, 100e18, "FOUNDATION's own TVL: no double-count");
    }

    /// @notice All pending on FOUNDATION, none for owner — owner still gets FOUNDATION value
    function test_singlePass_allPendingOnFoundation_ownerGetsValue() public {
        address foundation = oracle.FOUNDATION();

        // Owner has held DETH but all pending is on FOUNDATION
        deth.mint(superVault, 100e18);
        asyncRedeemer.mockRequestRedeem(foundation, 80e18);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        assertEq(tvl, 180e18, "Owner gets held + FOUNDATION pending");
    }

    /// @notice No pending requests: single-pass returns held value only
    function test_singlePass_noPending_heldOnly() public {
        deth.mint(superVault, 100e18);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        assertEq(tvl, 100e18, "No pending: TVL = held only");
    }

    /// @notice Graceful degradation: lastFinalizedRequestId reverts, single-pass returns held only
    function test_singlePass_graceful_lastFinalizedReverts() public {
        address foundation = oracle.FOUNDATION();

        deth.mint(superVault, 100e18);
        asyncRedeemer.mockRequestRedeem(superVault, 30e18);
        asyncRedeemer.mockRequestRedeem(foundation, 20e18);

        asyncRedeemer.setRevertOnLastFinalizedRequestId(true);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        assertEq(tvl, 100e18, "Graceful: held only when lastFinalizedRequestId reverts");
    }

    /// @notice Graceful degradation: nextRequestId reverts, single-pass returns held only
    function test_singlePass_graceful_nextRequestIdReverts() public {
        address foundation = oracle.FOUNDATION();

        deth.mint(superVault, 100e18);
        asyncRedeemer.mockRequestRedeem(superVault, 30e18);
        asyncRedeemer.mockRequestRedeem(foundation, 20e18);

        asyncRedeemer.setRevertOnNextRequestId(true);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        assertEq(tvl, 100e18, "Graceful: held only when nextRequestId reverts");
    }

    /// @notice MAX_PENDING_REQUESTS cap applies with FOUNDATION in single pass
    function test_singlePass_cappedAtMax_withFoundation() public {
        address foundation = oracle.FOUNDATION();

        // Create 210 requests: 105 for owner, 105 for foundation (interleaved)
        for (uint256 i; i < 105; ++i) {
            asyncRedeemer.mockRequestRedeem(superVault, 1e18);
            asyncRedeemer.mockRequestRedeem(foundation, 1e18);
        }
        // Total 210 pending, cap at 200 — first 200 are 100 owner + 100 foundation

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        // Only first 200 scanned: 100 owner + 100 foundation = 200e18
        assertEq(tvl, 200e18, "Single-pass capped at MAX_PENDING_REQUESTS");
    }

    /// @notice Finalized requests excluded in single pass with FOUNDATION
    function test_singlePass_finalizedExcluded_withFoundation() public {
        address foundation = oracle.FOUNDATION();

        // Create 5 requests: owner, foundation, owner, foundation, owner
        asyncRedeemer.mockRequestRedeem(superVault, 10e18);   // ID 1
        asyncRedeemer.mockRequestRedeem(foundation, 20e18);    // ID 2
        asyncRedeemer.mockRequestRedeem(superVault, 30e18);    // ID 3
        asyncRedeemer.mockRequestRedeem(foundation, 40e18);    // ID 4
        asyncRedeemer.mockRequestRedeem(superVault, 50e18);    // ID 5

        // Finalize first 2 (owner:10, foundation:20)
        asyncRedeemer.mockFinalizeUpTo(2);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        // Pending: ID 3(owner:30) + ID 4(foundation:40) + ID 5(owner:50) = 120
        assertEq(tvl, 120e18, "Finalized requests excluded in single pass");
    }

    /// @notice Burned NFTs skipped in single pass
    function test_singlePass_burnedNFTsSkipped_withFoundation() public {
        address foundation = oracle.FOUNDATION();

        asyncRedeemer.mockRequestRedeem(superVault, 10e18);   // ID 1
        asyncRedeemer.mockRequestRedeem(foundation, 20e18);    // ID 2
        asyncRedeemer.mockRequestRedeem(superVault, 30e18);    // ID 3

        // Burn ID 2 (foundation's request)
        asyncRedeemer.mockClaimRequest(2);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        // ID 1(owner:10) + ID 2(burned:skip) + ID 3(owner:30) = 40
        assertEq(tvl, 40e18, "Burned foundation NFT skipped in single pass");
    }

    /// @notice Oracle with different FOUNDATION sees different pending
    function test_singlePass_differentFoundation_differentResults() public {
        address foundationA = makeAddr("foundationA");
        address foundationB = makeAddr("foundationB");

        DETHYieldSourceOracle oracleA = new DETHYieldSourceOracle(address(ledgerConfig), foundationA);
        DETHYieldSourceOracle oracleB = new DETHYieldSourceOracle(address(ledgerConfig), foundationB);

        // Create pending owned by foundationA
        asyncRedeemer.mockRequestRedeem(foundationA, 50e18);
        asyncRedeemer.mockRequestRedeem(foundationB, 30e18);

        // oracleA sees foundationA's 50 for superVault
        uint256 tvlA = oracleA.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        assertEq(tvlA, 50e18, "OracleA includes foundationA's pending");

        // oracleB sees foundationB's 30 for superVault
        uint256 tvlB = oracleB.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        assertEq(tvlB, 30e18, "OracleB includes foundationB's pending");
    }

    /// @notice Fuzz: TVL stable when shares move from owner to FOUNDATION pending
    function testFuzz_singlePass_tvlStable_sharesToFoundation(
        uint256 totalShares,
        uint256 redeemFraction,
        uint256 pps
    )
        public
    {
        totalShares = bound(totalShares, 1, type(uint64).max);
        redeemFraction = bound(redeemFraction, 0, totalShares);
        pps = bound(pps, 1, type(uint64).max);
        machine.setAssetsPerShare(pps);

        address foundation = oracle.FOUNDATION();

        deth.mint(superVault, totalShares);
        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);

        if (redeemFraction > 0) {
            // Simulate routed redeem: burn from owner, pending minted to FOUNDATION
            deth.burn(superVault, redeemFraction);
            asyncRedeemer.mockRequestRedeem(foundation, redeemFraction);
        }

        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        // TVL should be stable: held decreased but FOUNDATION pending increased by same amount
        assertApproxEqAbs(tvlAfter, tvlBefore, 1, "TVL stable when shares route through FOUNDATION");
    }

    /// @notice Fuzz: single-pass matches two separate calls for correctness
    function testFuzz_singlePass_matchesSeparateCalls(
        uint256 ownerPending,
        uint256 foundationPending,
        uint256 heldShares,
        uint256 pps
    )
        public
    {
        ownerPending = bound(ownerPending, 0, type(uint64).max);
        foundationPending = bound(foundationPending, 0, type(uint64).max);
        heldShares = bound(heldShares, 0, type(uint64).max);
        pps = bound(pps, 1, type(uint64).max);
        machine.setAssetsPerShare(pps);

        address foundation = oracle.FOUNDATION();

        if (heldShares > 0) deth.mint(superVault, heldShares);
        if (ownerPending > 0) asyncRedeemer.mockRequestRedeem(superVault, ownerPending);
        if (foundationPending > 0) asyncRedeemer.mockRequestRedeem(foundation, foundationPending);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);

        // Manually compute expected: held + owner_pending + foundation_pending
        uint256 expectedHeld = heldShares > 0 ? machine.convertToAssets(heldShares) : 0;
        uint256 totalPending = ownerPending + foundationPending;
        uint256 expectedPending = totalPending > 0 ? machine.convertToAssets(totalPending) : 0;

        assertEq(tvl, expectedHeld + expectedPending, "Single-pass result matches manual computation");
    }

    /// @notice Fuzz: converting accumulated shares in one call equals sum of individual conversions
    /// @dev Validates the single-pass batching of shares into one convertToAssets call
    function testFuzz_singlePass_batchConversion(
        uint256 shares1,
        uint256 shares2,
        uint256 shares3,
        uint256 pps
    )
        public
    {
        shares1 = bound(shares1, 0, type(uint64).max);
        shares2 = bound(shares2, 0, type(uint64).max);
        shares3 = bound(shares3, 0, type(uint64).max);
        pps = bound(pps, 1, type(uint64).max);
        machine.setAssetsPerShare(pps);

        address foundation = oracle.FOUNDATION();

        // Mix: shares1 for owner, shares2 for foundation, shares3 for owner
        if (shares1 > 0) asyncRedeemer.mockRequestRedeem(superVault, shares1);
        if (shares2 > 0) asyncRedeemer.mockRequestRedeem(foundation, shares2);
        if (shares3 > 0) asyncRedeemer.mockRequestRedeem(superVault, shares3);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);

        // All shares batched into one convertToAssets call
        uint256 totalShares = shares1 + shares2 + shares3;
        uint256 expected = totalShares > 0 ? machine.convertToAssets(totalShares) : 0;
        assertEq(tvl, expected, "Batched conversion matches expected");
    }

    /*//////////////////////////////////////////////////////////////
                        ROUND-TRIP FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fuzz: round-trip shares -> assets -> shares preserves or loses at most 1 wei
    function testFuzz_roundTrip_sharesToAssetsToShares(uint256 sharesIn) public view {
        sharesIn = bound(sharesIn, 1, type(uint128).max);

        uint256 assets = oracle.getAssetOutput(address(asyncRedeemer), address(0), sharesIn);
        if (assets == 0) return;

        uint256 sharesBack = oracle.getShareOutput(address(asyncRedeemer), address(0), assets);
        // Floor rounding may lose at most 1 wei
        assertApproxEqAbs(sharesBack, sharesIn, 1);
    }

    /// @notice Fuzz: assets -> shares -> assets preserves or loses at most 1 wei
    function testFuzz_roundTrip_assetsToSharesToAssets(uint256 assetsIn) public view {
        assetsIn = bound(assetsIn, 1, type(uint128).max);

        uint256 shares = oracle.getShareOutput(address(asyncRedeemer), address(0), assetsIn);
        if (shares == 0) return;

        uint256 assetsBack = oracle.getAssetOutput(address(asyncRedeemer), address(0), shares);
        assertApproxEqAbs(assetsBack, assetsIn, 1);
    }

    /// @notice Fuzz: withdrawal shares cover at least the requested asset amount
    function testFuzz_withdrawalSharesCoverAssets(uint256 assetsIn, uint256 pps) public {
        assetsIn = bound(assetsIn, 1, type(uint64).max);
        pps = bound(pps, 1, type(uint64).max);
        machine.setAssetsPerShare(pps);

        uint256 withdrawalShares = oracle.getWithdrawalShareOutput(address(asyncRedeemer), address(0), assetsIn);
        uint256 assetsFromShares = oracle.getAssetOutput(address(asyncRedeemer), address(0), withdrawalShares);

        // Ceil rounding ensures we always get at least the requested assets
        assertGe(assetsFromShares, assetsIn);
    }

    /*//////////////////////////////////////////////////////////////
            DYNAMIC RESOLUTION — MULTI-REDEEMER TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice One oracle serves two different AsyncRedeemers with different PPS
    function test_dynamicResolution_multipleAsyncRedeemers() public {
        // Deploy second vault ecosystem
        MockDETH deth2 = new MockDETH();
        MockMachine machine2 = new MockMachine(address(deth2), makeAddr("WETH2"));
        MockAsyncRedeemer asyncRedeemer2 = new MockAsyncRedeemer(address(machine2));

        machine.setAssetsPerShare(1.5e18);
        machine2.setAssetsPerShare(2e18);

        // Same oracle, different yield sources → different results
        assertEq(oracle.getPricePerShare(address(asyncRedeemer)), 1.5e18);
        assertEq(oracle.getPricePerShare(address(asyncRedeemer2)), 2e18);

        // Conversion outputs differ
        assertEq(oracle.getAssetOutput(address(asyncRedeemer), address(0), 100e18), 150e18);
        assertEq(oracle.getAssetOutput(address(asyncRedeemer2), address(0), 100e18), 200e18);
    }

    /// @notice Multi-redeemer TVL is independent per yield source
    function test_dynamicResolution_independentTVL() public {
        MockDETH deth2 = new MockDETH();
        MockMachine machine2 = new MockMachine(address(deth2), makeAddr("WETH2"));
        MockAsyncRedeemer asyncRedeemer2 = new MockAsyncRedeemer(address(machine2));

        // User has 100 DETH in redeemer1, 50 DETH2 in redeemer2
        deth.mint(superVault, 100e18);
        deth2.mint(superVault, 50e18);

        // Pending in redeemer1 only
        asyncRedeemer.mockRequestRedeem(superVault, 30e18);

        uint256 tvl1 = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        uint256 tvl2 = oracle.getTVLByOwnerOfShares(address(asyncRedeemer2), superVault);

        assertEq(tvl1, 130e18); // held(100) + pending(30)
        assertEq(tvl2, 50e18); // held(50) + pending(0)
    }

    /// @notice Multi-redeemer decimals can differ
    function test_dynamicResolution_differentDecimals() public {
        // deth has 18 decimals (default)
        // Create a 6-decimal token for second redeemer
        MockDETH deth6 = new MockDETH();
        deth6.setDecimals(6);
        MockMachine machine6 = new MockMachine(address(deth6), makeAddr("USDC"));
        MockAsyncRedeemer asyncRedeemer6 = new MockAsyncRedeemer(address(machine6));

        assertEq(oracle.decimals(address(asyncRedeemer)), 18);
        assertEq(oracle.decimals(address(asyncRedeemer6)), 6);
    }

    /*//////////////////////////////////////////////////////////////
                    ADDITIONAL FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fuzz: getAssetOutput at varying PPS always matches Machine
    function testFuzz_getAssetOutput_varyingPPS(uint256 sharesIn, uint256 pps) public {
        sharesIn = bound(sharesIn, 1, type(uint128).max);
        pps = bound(pps, 1, type(uint128).max);
        machine.setAssetsPerShare(pps);

        uint256 oracleResult = oracle.getAssetOutput(address(asyncRedeemer), address(0), sharesIn);
        uint256 machineResult = machine.convertToAssets(sharesIn);
        assertEq(oracleResult, machineResult);
    }

    /// @notice Fuzz: getShareOutput at varying PPS always matches Machine
    function testFuzz_getShareOutput_varyingPPS(uint256 assetsIn, uint256 pps) public {
        assetsIn = bound(assetsIn, 1, type(uint128).max);
        pps = bound(pps, 1, type(uint128).max);
        machine.setAssetsPerShare(pps);

        uint256 oracleResult = oracle.getShareOutput(address(asyncRedeemer), address(0), assetsIn);
        uint256 machineResult = machine.convertToShares(assetsIn);
        assertEq(oracleResult, machineResult);
    }

    /// @notice Fuzz: PPS always equals convertToAssets(oneShare)
    function testFuzz_getPricePerShare_matchesConvertToAssets(uint256 pps) public {
        pps = bound(pps, 1, type(uint128).max);
        machine.setAssetsPerShare(pps);

        uint256 oraclePPS = oracle.getPricePerShare(address(asyncRedeemer));
        uint256 machinePPS = machine.convertToAssets(1e18);
        assertEq(oraclePPS, machinePPS);
    }

    /// @notice Fuzz: TVL always equals Machine.lastTotalAum()
    function testFuzz_getTVL(uint256 aum) public {
        machine.setLastTotalAum(aum);
        assertEq(oracle.getTVL(address(asyncRedeemer)), aum);
    }

    /// @notice Fuzz: balance always matches DETH token balance
    function testFuzz_getBalanceOfOwner(uint256 amount) public {
        amount = bound(amount, 0, type(uint128).max);
        if (amount > 0) deth.mint(superVault, amount);
        assertEq(oracle.getBalanceOfOwner(address(asyncRedeemer), superVault), amount);
    }

    /// @notice Fuzz: TVL = convertToAssets(held) + convertToAssets(pending)
    function testFuzz_getTVLByOwner_heldPlusPending(uint256 heldShares, uint256 pendingShares, uint256 pps) public {
        heldShares = bound(heldShares, 0, type(uint64).max);
        pendingShares = bound(pendingShares, 0, type(uint64).max);
        pps = bound(pps, 1, type(uint64).max);
        machine.setAssetsPerShare(pps);

        if (heldShares > 0) deth.mint(superVault, heldShares);
        if (pendingShares > 0) asyncRedeemer.mockRequestRedeem(superVault, pendingShares);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);

        uint256 expectedHeld = heldShares > 0 ? machine.convertToAssets(heldShares) : 0;
        uint256 expectedPending = pendingShares > 0 ? machine.convertToAssets(pendingShares) : 0;
        assertEq(tvl, expectedHeld + expectedPending);
    }

    /// @notice Fuzz: TVL stable when shares move from held to pending (requestRedeem simulation)
    function testFuzz_getTVLByOwner_ppsStability(uint256 totalShares, uint256 redeemFraction, uint256 pps) public {
        totalShares = bound(totalShares, 1, type(uint64).max);
        redeemFraction = bound(redeemFraction, 0, totalShares);
        pps = bound(pps, 1, type(uint64).max);
        machine.setAssetsPerShare(pps);

        deth.mint(superVault, totalShares);
        uint256 tvlBefore = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);

        if (redeemFraction > 0) {
            deth.burn(superVault, redeemFraction);
            asyncRedeemer.mockRequestRedeem(superVault, redeemFraction);
        }

        uint256 tvlAfter = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);

        // TVL should be stable: held shares moved to pending, value unchanged
        // May differ by at most 1 wei due to rounding in convertToAssets(a+b) vs convertToAssets(a)+convertToAssets(b)
        assertApproxEqAbs(tvlAfter, tvlBefore, 1, "TVL should be stable during requestRedeem");
    }

    /// @notice Fuzz: withdrawal overshoot is at most 1 share worth of assets
    function testFuzz_withdrawalSharesCoverAssets_minimalOvershoot(uint256 assetsIn, uint256 pps) public {
        assetsIn = bound(assetsIn, 1, type(uint64).max);
        pps = bound(pps, 1, type(uint64).max);
        machine.setAssetsPerShare(pps);

        uint256 withdrawalShares = oracle.getWithdrawalShareOutput(address(asyncRedeemer), address(0), assetsIn);
        uint256 assetsBack = oracle.getAssetOutput(address(asyncRedeemer), address(0), withdrawalShares);

        // Must cover requested amount
        assertGe(assetsBack, assetsIn, "Withdrawal shares must cover requested assets");

        // Overshoot should be less than 1 share worth of assets
        uint256 overshoot = assetsBack - assetsIn;
        assertLt(overshoot, pps, "Overshoot exceeds 1 share worth of assets");
    }

    /// @notice Fuzz: multiple pending requests → TVL equals sum of individual values
    function testFuzz_getTVLByOwner_multiplePending(
        uint256 shares1,
        uint256 shares2,
        uint256 shares3,
        uint256 pps
    )
        public
    {
        shares1 = bound(shares1, 0, type(uint64).max);
        shares2 = bound(shares2, 0, type(uint64).max);
        shares3 = bound(shares3, 0, type(uint64).max);
        pps = bound(pps, 1, type(uint64).max);
        machine.setAssetsPerShare(pps);

        if (shares1 > 0) asyncRedeemer.mockRequestRedeem(superVault, shares1);
        if (shares2 > 0) asyncRedeemer.mockRequestRedeem(superVault, shares2);
        if (shares3 > 0) asyncRedeemer.mockRequestRedeem(superVault, shares3);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);

        // The oracle batches all pending shares into one convertToAssets call
        uint256 totalPending = shares1 + shares2 + shares3;
        uint256 expected = totalPending > 0 ? machine.convertToAssets(totalPending) : 0;
        assertEq(tvl, expected);
    }

    /// @notice Fuzz: owner filtering — two owners' TVLs sum correctly
    function testFuzz_getTVLByOwner_ownerIsolation(
        uint256 heldA,
        uint256 pendingA,
        uint256 heldB,
        uint256 pendingB,
        uint256 pps
    )
        public
    {
        heldA = bound(heldA, 0, type(uint64).max);
        pendingA = bound(pendingA, 0, type(uint64).max);
        heldB = bound(heldB, 0, type(uint64).max);
        pendingB = bound(pendingB, 0, type(uint64).max);
        pps = bound(pps, 1, type(uint64).max);
        machine.setAssetsPerShare(pps);

        address userA = superVault;
        address userB = makeAddr("userB");

        if (heldA > 0) deth.mint(userA, heldA);
        if (heldB > 0) deth.mint(userB, heldB);
        if (pendingA > 0) asyncRedeemer.mockRequestRedeem(userA, pendingA);
        if (pendingB > 0) asyncRedeemer.mockRequestRedeem(userB, pendingB);

        uint256 tvlA = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), userA);
        uint256 tvlB = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), userB);

        // Each user's TVL matches their individual held + pending
        uint256 expectedA = (heldA > 0 ? machine.convertToAssets(heldA) : 0)
            + (pendingA > 0 ? machine.convertToAssets(pendingA) : 0);
        uint256 expectedB = (heldB > 0 ? machine.convertToAssets(heldB) : 0)
            + (pendingB > 0 ? machine.convertToAssets(pendingB) : 0);

        assertEq(tvlA, expectedA, "User A TVL mismatch");
        assertEq(tvlB, expectedB, "User B TVL mismatch");
    }

    /// @notice Fuzz: getShareOutput(0) always returns 0 regardless of PPS
    function testFuzz_getShareOutput_zeroAlwaysZero(uint256 pps) public {
        pps = bound(pps, 1, type(uint128).max);
        machine.setAssetsPerShare(pps);
        assertEq(oracle.getShareOutput(address(asyncRedeemer), address(0), 0), 0);
    }

    /// @notice Fuzz: getAssetOutput(0) always returns 0 regardless of PPS
    function testFuzz_getAssetOutput_zeroAlwaysZero(uint256 pps) public {
        pps = bound(pps, 1, type(uint128).max);
        machine.setAssetsPerShare(pps);
        assertEq(oracle.getAssetOutput(address(asyncRedeemer), address(0), 0), 0);
    }

    /// @notice Fuzz: getWithdrawalShareOutput(0) always returns 0 regardless of PPS
    function testFuzz_getWithdrawalShareOutput_zeroAlwaysZero(uint256 pps) public {
        pps = bound(pps, 1, type(uint128).max);
        machine.setAssetsPerShare(pps);
        assertEq(oracle.getWithdrawalShareOutput(address(asyncRedeemer), address(0), 0), 0);
    }

    /// @notice Fuzz: finalized requests are correctly excluded from TVL
    function testFuzz_getTVLByOwner_finalizationExclusion(
        uint256 totalRequests,
        uint256 finalizeCount,
        uint256 pps
    )
        public
    {
        totalRequests = bound(totalRequests, 1, 20);
        finalizeCount = bound(finalizeCount, 0, totalRequests);
        pps = bound(pps, 1, type(uint64).max);
        machine.setAssetsPerShare(pps);

        uint256 sharesPerRequest = 1e18;
        asyncRedeemer.mockBulkRequestRedeem(superVault, sharesPerRequest, totalRequests);

        if (finalizeCount > 0) {
            asyncRedeemer.mockFinalizeUpTo(finalizeCount);
        }

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), superVault);
        uint256 pendingCount = totalRequests - finalizeCount;
        uint256 expected = pendingCount > 0 ? machine.convertToAssets(pendingCount * sharesPerRequest) : 0;

        assertEq(tvl, expected, "TVL should only count non-finalized requests");
    }
}

/*//////////////////////////////////////////////////////////////
                    INVARIANT TESTS
//////////////////////////////////////////////////////////////*/

/// @dev Handler contract for invariant testing — performs random state mutations
contract DETHOracleHandler is Helpers {
    DETHYieldSourceOracle public oracle;
    MockDETH public deth;
    MockMachine public machine;
    MockAsyncRedeemer public asyncRedeemer;
    address public user;

    // Ghost variables to track expected state
    uint256 public ghost_totalHeldShares;
    uint256 public ghost_totalPendingShares;
    uint256 public ghost_numPendingRequests;
    uint256 public ghost_numFinalized;

    constructor(
        DETHYieldSourceOracle oracle_,
        MockDETH deth_,
        MockMachine machine_,
        MockAsyncRedeemer asyncRedeemer_,
        address user_
    ) {
        oracle = oracle_;
        deth = deth_;
        machine = machine_;
        asyncRedeemer = asyncRedeemer_;
        user = user_;
    }

    /// @dev Mint held DETH shares to the user
    function mintShares(uint256 amount) external {
        amount = bound(amount, 0, type(uint64).max);
        if (amount == 0) return;
        deth.mint(user, amount);
        ghost_totalHeldShares += amount;
    }

    /// @dev Move shares from held to pending (simulates requestRedeem)
    function requestRedeem(uint256 amount) external {
        amount = bound(amount, 0, ghost_totalHeldShares);
        if (amount == 0) return;
        deth.burn(user, amount);
        asyncRedeemer.mockRequestRedeem(user, amount);
        ghost_totalHeldShares -= amount;
        ghost_totalPendingShares += amount;
        ghost_numPendingRequests++;
    }

    /// @dev Change PPS (simulates yield accrual or loss)
    function changePPS(uint256 newPPS) external {
        newPPS = bound(newPPS, 1, type(uint64).max);
        machine.setAssetsPerShare(newPPS);
    }

    /// @dev Finalize oldest pending requests
    function finalizeRequests(uint256 count) external {
        if (ghost_numPendingRequests == 0) return;
        count = bound(count, 1, ghost_numPendingRequests);

        uint256 newFinalized = ghost_numFinalized + count;
        asyncRedeemer.mockFinalizeUpTo(newFinalized);

        // We can't easily track per-request shares for finalized requests,
        // so we mark them as finalized but can't subtract from ghost_totalPendingShares
        // without per-request tracking. For invariants, we track separately.
        ghost_numFinalized = newFinalized;
        ghost_numPendingRequests -= count;
    }
}

/// @title DETHYieldSourceOracleInvariantTest
/// @notice Invariant tests for DETHYieldSourceOracle
contract DETHYieldSourceOracleInvariantTest is Helpers {
    DETHYieldSourceOracle public oracle;
    MockDETH public deth;
    MockMachine public machine;
    MockAsyncRedeemer public asyncRedeemer;
    DETHOracleHandler public handler;

    address public user;

    function setUp() public {
        deth = new MockDETH();
        machine = new MockMachine(address(deth), makeAddr("WETH"));
        asyncRedeemer = new MockAsyncRedeemer(address(machine));

        ISuperLedgerConfiguration ledgerConfig = ISuperLedgerConfiguration(address(new SuperLedgerConfiguration()));
        oracle = new DETHYieldSourceOracle(address(ledgerConfig), address(1));

        user = makeAddr("invariantUser");
        handler = new DETHOracleHandler(oracle, deth, machine, asyncRedeemer, user);

        targetContract(address(handler));
    }

    /// @notice TVL is always >= held share value (pending can only add)
    function invariant_tvlGeHeldValue() public view {
        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), user);
        uint256 heldShares = deth.balanceOf(user);
        uint256 heldValue = heldShares > 0 ? machine.convertToAssets(heldShares) : 0;

        assertGe(tvl, heldValue, "TVL must be >= held share value");
    }

    /// @notice Balance returned by oracle matches actual DETH balance
    function invariant_balanceMatchesDETH() public view {
        uint256 oracleBalance = oracle.getBalanceOfOwner(address(asyncRedeemer), user);
        uint256 actualBalance = deth.balanceOf(user);
        assertEq(oracleBalance, actualBalance, "Oracle balance must match DETH balance");
    }

    /// @notice PPS is always positive (Machine PPS is bounded > 0 by handler)
    function invariant_ppsPositive() public view {
        uint256 pps = oracle.getPricePerShare(address(asyncRedeemer));
        assertGt(pps, 0, "PPS must always be positive");
    }

    /// @notice Withdrawal shares always cover 1 ETH worth of assets
    function invariant_withdrawalSharesCover1ETH() public view {
        uint256 pps = oracle.getPricePerShare(address(asyncRedeemer));
        if (pps == 0) return;

        uint256 testAmount = 1e18;
        uint256 withdrawalShares = oracle.getWithdrawalShareOutput(address(asyncRedeemer), address(0), testAmount);
        uint256 assetsBack = oracle.getAssetOutput(address(asyncRedeemer), address(0), withdrawalShares);

        assertGe(assetsBack, testAmount, "Withdrawal shares must cover 1 ETH");
    }

    /// @notice Oracle held shares ghost matches actual DETH balance
    function invariant_ghostHeldMatchesBalance() public view {
        assertEq(
            handler.ghost_totalHeldShares(),
            deth.balanceOf(user),
            "Ghost held shares must match actual DETH balance"
        );
    }

    /// @notice Round-trip shares→assets→shares preserves value (within 1 wei)
    function invariant_roundTripPreservation() public view {
        uint256 testShares = 1e18;
        uint256 assets = oracle.getAssetOutput(address(asyncRedeemer), address(0), testShares);
        if (assets == 0) return;

        uint256 sharesBack = oracle.getShareOutput(address(asyncRedeemer), address(0), assets);
        assertApproxEqAbs(sharesBack, testShares, 1, "Round-trip must preserve within 1 wei");
    }

    /// @notice TVL for zero-address user is always 0
    function invariant_zeroAddressTVL() public view {
        uint256 tvl = oracle.getTVLByOwnerOfShares(address(asyncRedeemer), address(0));
        assertEq(tvl, 0, "Zero address TVL must be 0");
    }

    /// @notice getTVL always returns Machine.lastTotalAum
    function invariant_tvlMatchesMachineAum() public view {
        uint256 oracleTVL = oracle.getTVL(address(asyncRedeemer));
        uint256 machineAum = machine.lastTotalAum();
        assertEq(oracleTVL, machineAum, "Oracle TVL must match Machine AUM");
    }
}
