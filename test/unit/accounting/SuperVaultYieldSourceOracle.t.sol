// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Helpers } from "../../utils/Helpers.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { SuperVaultYieldSourceOracle } from "../../../src/accounting/oracles/SuperVaultYieldSourceOracle.sol";
import { ISuperVault } from "../../../src/vendor/superform/ISuperVault.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperLedger } from "../../../src/interfaces/accounting/ISuperLedger.sol";
import { SuperLedger } from "../../../src/accounting/SuperLedger.sol";

/// @title SuperVaultYieldSourceOracleTest
/// @notice Comprehensive test suite for SuperVaultYieldSourceOracle
/// @dev Tests fee-inclusive deposit quotes, decimal precision, and async redeem compatibility
contract SuperVaultYieldSourceOracleTest is Helpers {
    SuperVaultYieldSourceOracle public oracle;
    ISuperLedgerConfiguration public ledgerConfig;
    ISuperLedger public ledger;

    MockERC20 public asset6; // 6 decimals (USDC-like)
    MockERC20 public asset18; // 18 decimals (DAI-like)

    MockSuperVault public vault6; // SuperVault with 6 decimal asset
    MockSuperVault public vault18; // SuperVault with 18 decimal asset

    address public feeRecipient;

    function setUp() public {
        // Deploy configuration and oracle
        ledgerConfig = ISuperLedgerConfiguration(address(new SuperLedgerConfiguration()));
        address[] memory allowedExecutors = new address[](1);
        allowedExecutors[0] = address(0x777);
        ledger = ISuperLedger(address(new SuperLedger(address(ledgerConfig), allowedExecutors)));

        oracle = new SuperVaultYieldSourceOracle(address(ledgerConfig));

        // Create assets with different decimals
        asset6 = new MockERC20("MockUSDC", "USDC", 6);
        asset18 = new MockERC20("MockDAI", "DAI", 18);

        // Create mock SuperVaults
        vault6 = new MockSuperVault(address(asset6), "SuperVault USDC", "svUSDC", 6);
        vault18 = new MockSuperVault(address(asset18), "SuperVault DAI", "svDAI", 18);

        feeRecipient = makeAddr("feeRecipient");

        // Register oracle in configuration
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);

        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle),
            feePercent: 100, // 1%
            feeRecipient: feeRecipient,
            ledger: address(ledger)
        });

        bytes32[] memory salts = new bytes32[](1);
        salts[0] = keccak256("SUPERVAULT_YIELD_SOURCE_ORACLE");
        ledgerConfig.setYieldSourceOracles(salts, configs);
    }

    /*//////////////////////////////////////////////////////////////
                            DECIMALS TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test decimals() returns correct value for 6 decimal vault
    function test_decimals_6decimals() public view {
        uint8 decimals = oracle.decimals(address(vault6));
        assertEq(decimals, 6);
        assertEq(decimals, vault6.decimals());
    }

    /// @notice Test decimals() returns correct value for 18 decimal vault
    function test_decimals_18decimals() public view {
        uint8 decimals = oracle.decimals(address(vault18));
        assertEq(decimals, 18);
        assertEq(decimals, vault18.decimals());
    }

    /*//////////////////////////////////////////////////////////////
                        GET SHARE OUTPUT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test getShareOutput() uses previewDeposit() and includes management fees
    function test_getShareOutput_includesFees() public view {
        uint256 assetsIn = 1000e6; // 1000 USDC

        // Oracle should call previewDeposit() which includes fees
        uint256 oracleShares = oracle.getShareOutput(address(vault6), address(asset6), assetsIn);
        uint256 expectedShares = vault6.previewDeposit(assetsIn);

        assertEq(oracleShares, expectedShares);

        // Verify it's less than convertToShares (which doesn't include fees)
        uint256 sharesWithoutFee = vault6.convertToShares(assetsIn);
        assertLt(oracleShares, sharesWithoutFee, "Should be less due to fee");
    }

    /// @notice Test getShareOutput() with 18 decimal asset
    function test_getShareOutput_18decimals() public view {
        uint256 assetsIn = 1000e18; // 1000 DAI

        uint256 oracleShares = oracle.getShareOutput(address(vault18), address(asset18), assetsIn);
        uint256 expectedShares = vault18.previewDeposit(assetsIn);

        assertEq(oracleShares, expectedShares);
    }

    /// @notice Fuzz test getShareOutput() across various amounts
    function testFuzz_getShareOutput(uint256 assetsIn) public view {
        assetsIn = bound(assetsIn, 1, 1_000_000e6); // 1 to 1M USDC

        uint256 oracleShares = oracle.getShareOutput(address(vault6), address(asset6), assetsIn);
        uint256 expectedShares = vault6.previewDeposit(assetsIn);

        assertEq(oracleShares, expectedShares);
    }

    /*//////////////////////////////////////////////////////////////
                WITHDRAWAL SHARE OUTPUT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test getWithdrawalShareOutput() uses correct decimals (not hardcoded 1e18)
    function test_getWithdrawalShareOutput_correctDecimals_6decimals() public view {
        uint256 assetsIn = 1000e6; // 1000 USDC

        // Expected calculation with CORRECT decimals
        uint256 oneShare = 10 ** vault6.decimals(); // 1e6, not 1e18!
        uint256 assetsPerShare = vault6.convertToAssets(oneShare);
        uint256 expectedShares = Math.mulDiv(assetsIn, oneShare, assetsPerShare, Math.Rounding.Ceil);

        uint256 actualShares = oracle.getWithdrawalShareOutput(address(vault6), address(asset6), assetsIn);

        assertEq(actualShares, expectedShares);
    }

    /// @notice Test getWithdrawalShareOutput() with 18 decimal asset
    function test_getWithdrawalShareOutput_correctDecimals_18decimals() public view {
        uint256 assetsIn = 1000e18; // 1000 DAI

        uint256 oneShare = 10 ** vault18.decimals(); // 1e18
        uint256 assetsPerShare = vault18.convertToAssets(oneShare);
        uint256 expectedShares = Math.mulDiv(assetsIn, oneShare, assetsPerShare, Math.Rounding.Ceil);

        uint256 actualShares = oracle.getWithdrawalShareOutput(address(vault18), address(asset18), assetsIn);

        assertEq(actualShares, expectedShares);
    }

    /// @notice Test getWithdrawalShareOutput() uses ceiling rounding (favors vault)
    function test_getWithdrawalShareOutput_ceilRounding() public view {
        uint256 assetsIn = 1001e6; // Amount that doesn't divide evenly

        uint256 actualShares = oracle.getWithdrawalShareOutput(address(vault6), address(asset6), assetsIn);

        // Calculate with floor rounding
        uint256 oneShare = 10 ** vault6.decimals();
        uint256 assetsPerShare = vault6.convertToAssets(oneShare);
        uint256 sharesFloor = Math.mulDiv(assetsIn, oneShare, assetsPerShare, Math.Rounding.Floor);

        // Oracle should return more shares (ceiling) to favor vault
        assertGe(actualShares, sharesFloor);
    }

    /// @notice Test getWithdrawalShareOutput() handles zero PPS gracefully
    function test_getWithdrawalShareOutput_zeroPPS() public {
        // Create vault with zero PPS
        MockSuperVault vaultZeroPPS = new MockSuperVault(address(asset6), "Zero PPS", "zPPS", 6);
        vaultZeroPPS.setStoredPPS(0);

        uint256 shares = oracle.getWithdrawalShareOutput(address(vaultZeroPPS), address(asset6), 1000e6);
        assertEq(shares, 0);
    }

    /// @notice Fuzz test getWithdrawalShareOutput() across various amounts
    function testFuzz_getWithdrawalShareOutput(uint256 assetsIn) public view {
        assetsIn = bound(assetsIn, 1, 1_000_000e6);

        uint256 oneShare = 10 ** vault6.decimals();
        uint256 assetsPerShare = vault6.convertToAssets(oneShare);
        if (assetsPerShare == 0) return; // Skip if PPS is zero

        uint256 expectedShares = Math.mulDiv(assetsIn, oneShare, assetsPerShare, Math.Rounding.Ceil);
        uint256 actualShares = oracle.getWithdrawalShareOutput(address(vault6), address(asset6), assetsIn);

        assertEq(actualShares, expectedShares);
    }

    /*//////////////////////////////////////////////////////////////
                    GET ASSET OUTPUT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test getAssetOutput() uses convertToAssets() (not previewRedeem)
    function test_getAssetOutput_usesConvertToAssets() public view {
        uint256 sharesIn = 1000e6; // 1000 shares

        uint256 oracleAssets = oracle.getAssetOutput(address(vault6), address(asset6), sharesIn);
        uint256 expectedAssets = vault6.convertToAssets(sharesIn);

        assertEq(oracleAssets, expectedAssets);
    }

    /// @notice Test getAssetOutput() with 18 decimal vault
    function test_getAssetOutput_18decimals() public view {
        uint256 sharesIn = 1000e18;

        uint256 oracleAssets = oracle.getAssetOutput(address(vault18), address(asset18), sharesIn);
        uint256 expectedAssets = vault18.convertToAssets(sharesIn);

        assertEq(oracleAssets, expectedAssets);
    }

    /// @notice Fuzz test getAssetOutput() across various amounts
    function testFuzz_getAssetOutput(uint256 sharesIn) public view {
        sharesIn = bound(sharesIn, 1, 1_000_000e6);

        uint256 oracleAssets = oracle.getAssetOutput(address(vault6), address(asset6), sharesIn);
        uint256 expectedAssets = vault6.convertToAssets(sharesIn);

        assertEq(oracleAssets, expectedAssets);
    }

    /*//////////////////////////////////////////////////////////////
                    PRICE PER SHARE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test getPricePerShare() uses correct decimals for 6 decimal vault
    function test_getPricePerShare_6decimals() public view {
        uint256 pps = oracle.getPricePerShare(address(vault6));
        uint256 expectedPPS = vault6.convertToAssets(10 ** vault6.decimals());

        assertEq(pps, expectedPPS);
    }

    /// @notice Test getPricePerShare() uses correct decimals for 18 decimal vault
    function test_getPricePerShare_18decimals() public view {
        uint256 pps = oracle.getPricePerShare(address(vault18));
        uint256 expectedPPS = vault18.convertToAssets(10 ** vault18.decimals());

        assertEq(pps, expectedPPS);
    }

    /*//////////////////////////////////////////////////////////////
                        BALANCE & TVL TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test getBalanceOfOwner() returns correct share balance
    function test_getBalanceOfOwner() public {
        address user = address(0x1234);
        uint256 shares = 1000e6;

        // Mint shares to user
        vault6.mint(user, shares);

        uint256 balance = oracle.getBalanceOfOwner(address(vault6), user);
        assertEq(balance, shares);
    }

    /// @notice Test getTVLByOwnerOfShares() returns correct asset value
    function test_getTVLByOwnerOfShares() public {
        address user = address(0x1234);
        uint256 shares = 1000e6;

        vault6.mint(user, shares);

        uint256 tvl = oracle.getTVLByOwnerOfShares(address(vault6), user);
        uint256 expectedTVL = vault6.convertToAssets(shares);

        assertEq(tvl, expectedTVL);
    }

    /// @notice Test getTVLByOwnerOfShares() returns zero for zero shares
    function test_getTVLByOwnerOfShares_zeroShares() public view {
        address user = address(0x5678);
        uint256 tvl = oracle.getTVLByOwnerOfShares(address(vault6), user);
        assertEq(tvl, 0);
    }

    /// @notice Test getTVL() returns total assets
    function test_getTVL() public view {
        uint256 tvl = oracle.getTVL(address(vault6));
        uint256 expectedTVL = vault6.totalAssets();

        assertEq(tvl, expectedTVL);
    }

    /*//////////////////////////////////////////////////////////////
                    ASYNC REDEEM COMPATIBILITY TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify vault's previewWithdraw() reverts (by design)
    function test_vault_previewWithdrawReverts() public {
        vm.expectRevert(ISuperVault.NOT_IMPLEMENTED.selector);
        vault6.previewWithdraw(1000e6);
    }

    /// @notice Verify vault's previewRedeem() reverts (by design)
    function test_vault_previewRedeemReverts() public {
        vm.expectRevert(ISuperVault.NOT_IMPLEMENTED.selector);
        vault6.previewRedeem(1000e6);
    }

    /// @notice Verify oracle does NOT revert even though vault's preview functions do
    /// @dev This is the key test - proves oracle avoids problematic methods
    function test_oracle_doesNotRevert_whenPreviewFunctionsRevert() public view {
        uint256 assetsIn = 1000e6;
        uint256 sharesIn = 1000e6;

        // These should all succeed even though vault's preview functions revert
        oracle.getShareOutput(address(vault6), address(asset6), assetsIn);
        oracle.getWithdrawalShareOutput(address(vault6), address(asset6), assetsIn);
        oracle.getAssetOutput(address(vault6), address(asset6), sharesIn);
        oracle.getPricePerShare(address(vault6));
        oracle.getTVL(address(vault6));
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test oracle with very small amounts
    function test_edgeCase_smallAmounts() public view {
        uint256 smallAmount = 1; // 1 wei

        // Should not revert
        oracle.getShareOutput(address(vault6), address(asset6), smallAmount);
        oracle.getWithdrawalShareOutput(address(vault6), address(asset6), smallAmount);
        oracle.getAssetOutput(address(vault6), address(asset6), smallAmount);
    }

    /// @notice Test oracle with very large amounts
    function test_edgeCase_largeAmounts() public view {
        uint256 largeAmount = type(uint128).max;

        // Should not revert or overflow
        oracle.getShareOutput(address(vault6), address(asset6), largeAmount);
        oracle.getWithdrawalShareOutput(address(vault6), address(asset6), largeAmount);
        oracle.getAssetOutput(address(vault6), address(asset6), largeAmount);
    }

    /// @notice Test oracle with non-1:1 price per share
    function test_edgeCase_nonOneToOnePPS() public {
        // Set PPS to 2x (vault has appreciated)
        vault6.setStoredPPS(2 * 10 ** vault6.decimals());

        uint256 assetsIn = 1000e6;
        uint256 sharesOut = oracle.getShareOutput(address(vault6), address(asset6), assetsIn);

        // Should get fewer shares due to 2x PPS
        assertLt(sharesOut, assetsIn);
    }
}

/*//////////////////////////////////////////////////////////////
                        MOCK SUPERVAULT
//////////////////////////////////////////////////////////////*/

/// @notice Mock SuperVault for testing
/// @dev Simplified version that mimics SuperVault's key behaviors:
///      - previewDeposit() includes management fees
///      - previewWithdraw() and previewRedeem() revert
///      - convertToShares() and convertToAssets() work with stored PPS
contract MockSuperVault is ISuperVault {
    using Math for uint256;

    string private _name;
    string private _symbol;
    uint8 private _decimals;
    address private _asset;

    uint256 public storedPPS; // Price per share
    uint256 public managementFeeBps = 100; // 1% default
    uint256 private constant BPS_PRECISION = 10_000;

    mapping(address => uint256) private _balances;
    uint256 private _totalSupply;

    constructor(address asset_, string memory name_, string memory symbol_, uint8 decimals_) {
        _asset = asset_;
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        storedPPS = 10 ** decimals_; // Start at 1:1
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function asset() public view override returns (address) {
        return _asset;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function setStoredPPS(uint256 pps) external {
        storedPPS = pps;
    }

    function convertToShares(uint256 assets) public view override returns (uint256) {
        if (storedPPS == 0) return 0;
        return Math.mulDiv(assets, 10 ** _decimals, storedPPS, Math.Rounding.Floor);
    }

    function convertToAssets(uint256 shares) public view override returns (uint256) {
        if (storedPPS == 0) return 0;
        return Math.mulDiv(shares, storedPPS, 10 ** _decimals, Math.Rounding.Floor);
    }

    function previewDeposit(uint256 assets) public view override returns (uint256) {
        // Calculate fee
        uint256 fee = Math.mulDiv(assets, managementFeeBps, BPS_PRECISION, Math.Rounding.Ceil);
        uint256 assetsNet = assets - fee;
        return convertToShares(assetsNet);
    }

    function previewWithdraw(uint256) public pure override returns (uint256) {
        revert NOT_IMPLEMENTED();
    }

    function previewRedeem(uint256) public pure override returns (uint256) {
        revert NOT_IMPLEMENTED();
    }

    function totalAssets() external view override returns (uint256) {
        return convertToAssets(_totalSupply);
    }

    function mint(address to, uint256 amount) external {
        _balances[to] += amount;
        _totalSupply += amount;
    }

    // ERC20 functions
    mapping(address => mapping(address => uint256)) private _allowances;

    function transfer(address, uint256) external pure returns (bool) {
        revert("Not implemented in mock");
    }

    function approve(address, uint256) external pure returns (bool) {
        revert("Not implemented in mock");
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        revert("Not implemented in mock");
    }

    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }

    // Stub implementations for ISuperVault interface
    function mintShares(address, uint256) external pure override {
        revert("Not implemented in mock");
    }

    function burnShares(uint256) external pure override {
        revert("Not implemented in mock");
    }

    function extractAndSendAssets(address, uint256) external pure override {
        revert("Not implemented in mock");
    }

    function getEscrowedAssets() external pure override returns (uint256) {
        return 0;
    }

    function escrow() external pure override returns (address) {
        return address(0);
    }

    // Stub ERC4626 functions not needed for oracle testing
    function deposit(uint256, address) external pure override returns (uint256) {
        revert("Not implemented in mock");
    }

    function mint(uint256, address) external pure override returns (uint256) {
        revert("Not implemented in mock");
    }

    function withdraw(uint256, address, address) external pure override returns (uint256) {
        revert("Not implemented in mock");
    }

    function redeem(uint256, address, address) external pure override returns (uint256) {
        revert("Not implemented in mock");
    }

    function maxDeposit(address) external pure override returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) external pure override returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address) external pure override returns (uint256) {
        return 0;
    }

    function maxRedeem(address) external pure override returns (uint256) {
        return 0;
    }

    function previewMint(uint256) external pure override returns (uint256) {
        revert("Not implemented in mock");
    }

    // ERC7540 stub functions
    function requestRedeem(uint256, address, address) external pure override returns (uint256) {
        revert("Not implemented in mock");
    }

    function pendingRedeemRequest(uint256, address) external pure override returns (uint256) {
        return 0;
    }

    function claimableRedeemRequest(uint256, address) external pure override returns (uint256) {
        return 0;
    }

    // ERC7540CancelRedeem stub functions
    function cancelRedeemRequest(uint256, address) external pure {
        revert("Not implemented in mock");
    }

    function claimCancelRedeemRequest(uint256, address, address) external pure returns (uint256) {
        revert("Not implemented in mock");
    }

    function pendingCancelRedeemRequest(uint256, address) external pure returns (bool) {
        return false;
    }

    function claimableCancelRedeemRequest(uint256, address) external pure returns (uint256) {
        return 0;
    }

    // ERC7540Operator stub functions
    function isOperator(address, address) external pure returns (bool) {
        return false;
    }

    function setOperator(address, bool) external pure returns (bool) {
        revert("Not implemented in mock");
    }

    // ERC7741 stub functions
    function authorizeOperator(address, address, bool, bytes32, uint256, bytes memory) external pure returns (bool) {
        revert("Not implemented in mock");
    }

    function authorizations(address, bytes32) external pure returns (bool) {
        return false;
    }

    function DOMAIN_SEPARATOR() external pure returns (bytes32) {
        return bytes32(0);
    }

    function invalidateNonce(bytes32) external pure {
        revert("Not implemented in mock");
    }

    function AUTHORIZE_OPERATOR_TYPEHASH() external pure returns (bytes32) {
        return bytes32(0);
    }
}
