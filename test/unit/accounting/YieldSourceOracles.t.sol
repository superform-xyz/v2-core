// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Helpers } from "../../utils/Helpers.sol";

import { MockERC20 } from "../../mocks/MockERC20.sol";
import { Mock4626Vault } from "../../mocks/Mock4626Vault.sol";
import { Mock7540Vault } from "../../mocks/Mock7540Vault.sol";
import { Mock5115Vault } from "../../mocks/Mock5115Vault.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IStakingVault } from "../../../src/vendor/staking/IStakingVault.sol";

import { ERC4626YieldSourceOracle } from "../../../src/core/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { ERC5115YieldSourceOracle } from "../../../src/core/accounting/oracles/ERC5115YieldSourceOracle.sol";
import { ERC7540YieldSourceOracle } from "../../../src/core/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { StakingYieldSourceOracle } from "../../../src/core/accounting/oracles/StakingYieldSourceOracle.sol";

import { SuperLedgerConfiguration } from "../../../src/core/accounting/SuperLedgerConfiguration.sol";
import { ISuperLedgerConfiguration } from "../../../src/core/interfaces/accounting/ISuperLedgerConfiguration.sol";

import { ISuperLedger } from "../../../src/core/interfaces/accounting/ISuperLedger.sol";
import { SuperLedger } from "../../../src/core/accounting/SuperLedger.sol";

contract YieldSourceOraclesTest is Helpers {
    ISuperLedgerConfiguration public ledgerConfig;
    ISuperLedger public ledger;

    MockERC20 public asset;
    address public underlying;

    Mock4626Vault public erc4626;
    Mock7540Vault public erc7540;
    Mock5115Vault public erc5115;
    IStakingVault public stakingVault;

    ERC4626YieldSourceOracle public erc4626YieldSourceOracle;
    ERC5115YieldSourceOracle public erc5115YieldSourceOracle;
    ERC7540YieldSourceOracle public erc7540YieldSourceOracle;
    StakingYieldSourceOracle public stakingYieldSourceOracle;

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY));

        ledgerConfig = ISuperLedgerConfiguration(address(new SuperLedgerConfiguration()));
        /// @dev with random allowed executor
        address[] memory allowedExecutors = new address[](1);
        allowedExecutors[0] = address(0x777);
        ledger = ISuperLedger(address(new SuperLedger(address(ledgerConfig), allowedExecutors)));

        erc4626YieldSourceOracle = new ERC4626YieldSourceOracle(address(ledgerConfig));
        erc5115YieldSourceOracle = new ERC5115YieldSourceOracle(address(ledgerConfig));
        erc7540YieldSourceOracle = new ERC7540YieldSourceOracle(address(ledgerConfig));
        stakingYieldSourceOracle = new StakingYieldSourceOracle(address(ledgerConfig));

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);

        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(erc4626YieldSourceOracle),
            feePercent: 100,
            feeRecipient: makeAddr("feeRecipient"),
            ledger: address(ledger)
        });

        bytes32[] memory salts = new bytes32[](1);
        salts[0] = bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY));
        ledgerConfig.setYieldSourceOracles(salts, configs);

        asset = new MockERC20("MockAsset", "MA", 18);

        erc4626 = new Mock4626Vault(address(asset), "Mock4626", "M4626");
        erc7540 = new Mock7540Vault(IERC20(address(asset)), "Mock7540", "M7540");
        erc5115 = new Mock5115Vault(IERC20(address(asset)), "Mock5115", "M5115");
        stakingVault = IStakingVault(CHAIN_1_FluidVault);
        underlying = stakingVault.stakingToken();

        _getTokens(address(asset), address(this), 1e18);
        _getTokens(address(underlying), address(this), 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                            DECIMALS TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ERC4626_decimals() public view {
        assertEq(erc4626.decimals(), asset.decimals());
    }

    function test_ERC7540_decimals() public view {
        assertEq(ERC20(erc7540.share()).decimals(), asset.decimals());
    }

    function test_ERC5115_decimals() public view {
        (,, uint8 decimals) = erc5115.assetInfo();
        assertEq(decimals, asset.decimals());
    }

    function test_StakingVault_decimals() public view {
        address stakingToken = stakingVault.stakingToken();
        assertEq(ERC20(stakingToken).decimals(), ERC20(underlying).decimals());
    }

    /*//////////////////////////////////////////////////////////////
                          SHARE OUTPUT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ERC4626_getShareOutput() public view {
        uint256 assetsIn = 1e18;
        uint256 expectedShares = erc4626.previewDeposit(assetsIn);
        uint256 actualShares = erc4626YieldSourceOracle.getShareOutput(address(erc4626), address(0), assetsIn);
        assertEq(actualShares, expectedShares);
    }

    function test_ERC7540_getShareOutput() public view {
        uint256 assetsIn = 1e18;
        uint256 expectedShares = erc7540.convertToShares(assetsIn);
        uint256 actualShares = erc7540YieldSourceOracle.getShareOutput(address(erc7540), address(0), assetsIn);
        assertEq(actualShares, expectedShares);
    }

    function test_ERC5115_getShareOutput() public view {
        uint256 assetsIn = 1e18;
        uint256 expectedShares = erc5115.previewDeposit(address(asset), assetsIn);
        uint256 actualShares = erc5115YieldSourceOracle.getShareOutput(address(erc5115), address(0), assetsIn);
        assertEq(actualShares, expectedShares);
    }

    function test_Staking_getShareOutput() public view {
        uint256 assetsIn = 1e18;
        uint256 actualShares = stakingYieldSourceOracle.getShareOutput(address(stakingVault), address(0), assetsIn);
        assertEq(actualShares, assetsIn); // For staking vaults, shares = assets
    }

    /*//////////////////////////////////////////////////////////////
                          ASSET OUTPUT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ERC4626_getAssetOutput() public view {
        uint256 sharesIn = 1e18;
        uint256 expectedAssets = erc4626.previewRedeem(sharesIn);
        uint256 actualAssets = erc4626YieldSourceOracle.getAssetOutput(address(erc4626), address(0), sharesIn);
        assertEq(actualAssets, expectedAssets);
    }

    function test_ERC7540_getAssetOutput() public view {
        uint256 sharesIn = 1e18;
        uint256 expectedAssets = erc7540.convertToAssets(sharesIn);
        uint256 actualAssets = erc7540YieldSourceOracle.getAssetOutput(address(erc7540), address(0), sharesIn);
        assertEq(actualAssets, expectedAssets);
    }

    function test_ERC5115_getAssetOutput() public view {
        uint256 sharesIn = 1e18;
        uint256 expectedAssets = erc5115.previewRedeem(address(asset), sharesIn);
        uint256 actualAssets = erc5115YieldSourceOracle.getAssetOutput(address(erc5115), address(0), sharesIn);
        assertEq(actualAssets, expectedAssets);
    }

    function test_Staking_getAssetOutput() public view {
        uint256 sharesIn = 1e18;
        uint256 actualAssets = stakingYieldSourceOracle.getAssetOutput(address(stakingVault), address(0), sharesIn);
        assertEq(actualAssets, sharesIn); // For staking vaults, assets = shares
    }

    function test_Staking_decimals() public view {
        assertEq(stakingYieldSourceOracle.decimals(address(stakingVault)), 18);
        assertEq(stakingYieldSourceOracle.decimals(address(this)), 18);
    }

    /*//////////////////////////////////////////////////////////////
                        PRICE PER SHARE TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ERC4626_getPricePerShare() public view {
        uint256 price = erc4626YieldSourceOracle.getPricePerShare(address(erc4626));
        assertEq(price, 1e18); // Initial price should be 1:1
    }

    function test_ERC7540_getPricePerShare() public view {
        uint256 price = erc7540YieldSourceOracle.getPricePerShare(address(erc7540));
        assertEq(price, 1e18); // Initial price should be 1:1
    }

    function test_ERC5115_getPricePerShare() public view {
        uint256 price = erc5115YieldSourceOracle.getPricePerShare(address(erc5115));
        assertEq(price, 1e18); // Initial price should be 1:1
    }

    function test_Staking_getPricePerShare() public view {
        uint256 price = stakingYieldSourceOracle.getPricePerShare(address(stakingVault));
        assertEq(price, 1e18); // Staking vaults always return 1:1
    }

    /*//////////////////////////////////////////////////////////////
                              TVL TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ERC4626_getTVL() public view {
        uint256 tvl = erc4626YieldSourceOracle.getTVL(address(erc4626));
        assertEq(tvl, 0); // Initial TVL should be 0
    }

    function test_ERC7540_getTVL() public view {
        uint256 tvl = erc7540YieldSourceOracle.getTVL(address(erc7540));
        assertEq(tvl, 0); // Initial TVL should be 0
    }

    function test_ERC5115_getTVL() public view {
        uint256 tvl = erc5115YieldSourceOracle.getTVL(address(erc5115));
        assertEq(tvl, 0); // Initial TVL should be 0
    }

    function test_Staking_getTVL() public view {
        uint256 tvl = stakingYieldSourceOracle.getTVL(address(stakingVault));
        assertGt(tvl, 0); // Staking vault should have some TVL
    }

    /*//////////////////////////////////////////////////////////////
                        TVL MULTIPLE TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ERC4626_getTVLMultiple() public view {
        address[] memory vaults = new address[](2);
        vaults[0] = address(erc4626);
        vaults[1] = address(erc4626);

        uint256[] memory tvls = erc4626YieldSourceOracle.getTVLMultiple(vaults);
        assertEq(tvls.length, 2);
        assertEq(tvls[0], 0); // Initial TVL should be 0
        assertEq(tvls[1], 0); // Initial TVL should be 0
    }

    function test_ERC7540_getTVLMultiple() public view {
        address[] memory vaults = new address[](2);
        vaults[0] = address(erc7540);
        vaults[1] = address(erc7540);

        uint256[] memory tvls = erc7540YieldSourceOracle.getTVLMultiple(vaults);
        assertEq(tvls.length, 2);
        assertEq(tvls[0], 0); // Initial TVL should be 0
        assertEq(tvls[1], 0); // Initial TVL should be 0
    }

    function test_ERC5115_getTVLMultiple() public view {
        address[] memory vaults = new address[](2);
        vaults[0] = address(erc5115);
        vaults[1] = address(erc5115);

        uint256[] memory tvls = erc5115YieldSourceOracle.getTVLMultiple(vaults);
        assertEq(tvls.length, 2);
        assertEq(tvls[0], 0); // Initial TVL should be 0
        assertEq(tvls[1], 0); // Initial TVL should be 0
    }

    function test_Staking_getTVLMultiple() public view {
        address[] memory vaults = new address[](2);
        vaults[0] = address(stakingVault);
        vaults[1] = address(stakingVault);

        uint256[] memory tvls = stakingYieldSourceOracle.getTVLMultiple(vaults);
        assertEq(tvls.length, 2);
        assertGt(tvls[0], 0); // Staking vault should have some TVL
        assertGt(tvls[1], 0); // Staking vault should have some TVL
    }

    /*//////////////////////////////////////////////////////////////
                       UNDERLYING ASSET TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ERC4626_isValidUnderlyingAsset() public view {
        bool isValid = erc4626YieldSourceOracle.isValidUnderlyingAsset(address(erc4626), address(asset));
        assertTrue(isValid);
    }

    function test_ERC7540_isValidUnderlyingAsset() public view {
        bool isValid = erc7540YieldSourceOracle.isValidUnderlyingAsset(address(erc7540), address(asset));
        assertTrue(isValid);
    }

    function test_ERC5115_isValidUnderlyingAsset() public view {
        bool isValid = erc5115YieldSourceOracle.isValidUnderlyingAsset(address(erc5115), address(asset));
        assertTrue(isValid);
    }

    function test_Staking_isValidUnderlyingAsset() public view {
        bool isValid = stakingYieldSourceOracle.isValidUnderlyingAsset(address(stakingVault), underlying);
        assertTrue(isValid);
    }

    /*//////////////////////////////////////////////////////////////
                       UNDERLYING ASSETS TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ERC4626_isValidUnderlyingAssets() public view {
        address[] memory vaults = new address[](2);
        address[] memory expectedUnderlying = new address[](2);
        vaults[0] = address(erc4626);
        vaults[1] = address(erc4626);
        expectedUnderlying[0] = address(asset);
        expectedUnderlying[1] = address(asset);

        bool[] memory isValid = erc4626YieldSourceOracle.isValidUnderlyingAssets(vaults, expectedUnderlying);
        assertEq(isValid.length, 2);
        assertTrue(isValid[0]);
        assertTrue(isValid[1]);
    }

    function test_ERC7540_isValidUnderlyingAssets() public view {
        address[] memory vaults = new address[](2);
        address[] memory expectedUnderlying = new address[](2);
        vaults[0] = address(erc7540);
        vaults[1] = address(erc7540);
        expectedUnderlying[0] = address(asset);
        expectedUnderlying[1] = address(asset);

        bool[] memory isValid = erc7540YieldSourceOracle.isValidUnderlyingAssets(vaults, expectedUnderlying);
        assertEq(isValid.length, 2);
        assertTrue(isValid[0]);
        assertTrue(isValid[1]);
    }

    function test_ERC5115_isValidUnderlyingAssets() public view {
        address[] memory vaults = new address[](2);
        address[] memory expectedUnderlying = new address[](2);
        vaults[0] = address(erc5115);
        vaults[1] = address(erc5115);
        expectedUnderlying[0] = address(asset);
        expectedUnderlying[1] = address(asset);

        bool[] memory isValid = erc5115YieldSourceOracle.isValidUnderlyingAssets(vaults, expectedUnderlying);
        assertEq(isValid.length, 2);
        assertTrue(isValid[0]);
        assertTrue(isValid[1]);
    }

    function test_Staking_isValidUnderlyingAssets() public view {
        address[] memory vaults = new address[](2);
        address[] memory expectedUnderlying = new address[](2);
        vaults[0] = address(stakingVault);
        vaults[1] = address(stakingVault);
        expectedUnderlying[0] = stakingVault.stakingToken();
        expectedUnderlying[1] = stakingVault.stakingToken();

        bool[] memory isValid = stakingYieldSourceOracle.isValidUnderlyingAssets(vaults, expectedUnderlying);
        assertEq(isValid.length, 2);
        assertTrue(isValid[0]);
        assertTrue(isValid[1]);
    }

    /*//////////////////////////////////////////////////////////////
                         BALANCE CHECK TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ERC4626_balanceCheck() public {
        IERC20(address(asset)).approve(address(erc4626), 1e18);
        erc4626.deposit(1e18, msg.sender);
        assertEq(
            erc4626.balanceOf(msg.sender), erc4626YieldSourceOracle.getBalanceOfOwner(address(erc4626), msg.sender)
        );
    }

    function test_ERC7540_balanceCheck() public {
        IERC20(address(asset)).approve(address(erc7540), 1e18);
        erc7540.deposit(1e18, msg.sender);
        assertEq(
            IERC20(erc7540.share()).balanceOf(msg.sender),
            erc7540YieldSourceOracle.getBalanceOfOwner(address(erc7540), msg.sender)
        );
    }

    function test_ERC5115_balanceCheck() public {
        IERC20(address(asset)).approve(address(erc5115), 1e18);
        erc5115.deposit(address(this), address(asset), 1e18, 0);
        assertEq(1e18, erc5115YieldSourceOracle.getBalanceOfOwner(address(erc5115), msg.sender));
    }

    function test_Staking_balanceCheck() public view {
        assertEq(
            IERC20(stakingVault.rewardsToken()).balanceOf(msg.sender),
            stakingYieldSourceOracle.getBalanceOfOwner(address(stakingVault), msg.sender)
        );
    }

    /*//////////////////////////////////////////////////////////////
                      TVL BY OWNER OF SHARES TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ERC4626_getTVLByOwnerOfShares() public {
        IERC20(address(asset)).approve(address(erc4626), 1e18);
        erc4626.deposit(1e18, msg.sender);
        uint256 shares = erc4626.balanceOf(msg.sender);
        uint256 expectedTVL = erc4626.convertToAssets(shares);
        uint256 actualTVL = erc4626YieldSourceOracle.getTVLByOwnerOfShares(address(erc4626), msg.sender);
        assertEq(actualTVL, expectedTVL);
    }

    function test_ERC7540_getTVLByOwnerOfShares() public {
        IERC20(address(asset)).approve(address(erc7540), 1e18);
        erc7540.deposit(1e18, msg.sender);
        uint256 shares = IERC20(erc7540.share()).balanceOf(msg.sender);
        uint256 expectedTVL = erc7540.convertToAssets(shares);
        uint256 actualTVL = erc7540YieldSourceOracle.getTVLByOwnerOfShares(address(erc7540), msg.sender);
        assertEq(actualTVL, expectedTVL);
    }

    function test_ERC5115_getTVLByOwnerOfShares() public {
        IERC20(address(asset)).approve(address(erc5115), 1e18);
        erc5115.deposit(address(this), address(asset), 1e18, 0);
        uint256 shares = erc5115.balanceOf(msg.sender);
        uint256 expectedTVL = erc5115.previewRedeem(address(asset), shares);
        uint256 actualTVL = erc5115YieldSourceOracle.getTVLByOwnerOfShares(address(erc5115), msg.sender);
        assertEq(actualTVL, expectedTVL);
    }

    function test_Staking_getTVLByOwnerOfShares() public view {
        uint256 shares = IERC20(stakingVault.rewardsToken()).balanceOf(msg.sender);
        uint256 actualTVL = stakingYieldSourceOracle.getTVLByOwnerOfShares(address(stakingVault), msg.sender);
        assertEq(actualTVL, shares); // For staking vaults, TVL = shares
    }

    /*//////////////////////////////////////////////////////////////
                      GET ASSET OUTPUT WITH FEES TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ERC4626_getAssetOutputWithFees_WithValidConfig() public {
        bytes32 oracleId = bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY));
        address user = makeAddr("testUser");
        uint256 initialShares = 1000e18;
        uint256 usedShares = 500e18; // Half of the shares
        uint256 assetOutput = 1100e18; // 10% profit over cost basis
        oracleId = _getYieldSourceOracleId(oracleId, address(this));

        // First do an inflow to set up shares (cost basis = 1000e18)
        vm.prank(address(0x777)); // allowed executor
        ledger.updateAccounting(
            user,
            address(erc4626),
            oracleId,
            true, // isInflow
            initialShares,
            0
        );

        // Mock the vault's previewRedeem to return our desired asset output
        vm.mockCall(
            address(erc4626), abi.encodeWithSignature("previewRedeem(uint256)", usedShares), abi.encode(assetOutput)
        );

        // Get asset output with fees
        uint256 assetOutputWithFees = erc4626YieldSourceOracle.getAssetOutputWithFees(
            oracleId, address(erc4626), address(asset), user, usedShares
        );

        // Cost basis for half the shares = 500e18
        // Profit = 1100e18 - 500e18 = 600e18
        // Fee = 600e18 * 1% = 6e18
        // Total with fees = 1100e18 + 6e18 = 1106e18
        uint256 expectedFee = (600e18 * 100) / 10_000; // 1% of profit
        uint256 expectedTotal = assetOutput + expectedFee;

        assertEq(assetOutputWithFees, expectedTotal, "Asset output with fees should include profit-based fees");
        assertGt(assetOutputWithFees, assetOutput, "Asset output with fees should be > base output");
    }

    function test_ERC4626_getAssetOutputWithFees_NoProfit() public {
        bytes32 oracleId = bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY));
        address user = makeAddr("testUser");
        uint256 initialShares = 1000e18;
        uint256 usedShares = 500e18; // Half of the shares
        uint256 assetOutput = 500e18; // No profit, equals cost basis for half shares
        oracleId = _getYieldSourceOracleId(oracleId, address(this));

        // First do an inflow to set up shares (cost basis = 1000e18)
        vm.prank(address(0x777)); // allowed executor
        ledger.updateAccounting(
            user,
            address(erc4626),
            oracleId,
            true, // isInflow
            initialShares,
            0
        );

        // Mock the vault's previewRedeem to return exactly cost basis (no profit)
        vm.mockCall(
            address(erc4626), abi.encodeWithSignature("previewRedeem(uint256)", usedShares), abi.encode(assetOutput)
        );

        // Get asset output with fees
        uint256 assetOutputWithFees = erc4626YieldSourceOracle.getAssetOutputWithFees(
             oracleId, address(erc4626), address(asset), user, usedShares
        );

        // No profit means no fees, so output should equal base output
        assertEq(assetOutputWithFees, assetOutput, "Asset output should equal base output when no profit");
    }

    function test_ERC4626_getAssetOutputWithFees_WithZeroFees() public {
        // Set up a configuration with zero fees using a unique oracle ID
        bytes32 zeroFeeOracleId = bytes32(keccak256("uniqueZeroFeeOracle_test_2024_v1"));

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(erc4626YieldSourceOracle),
            feePercent: 0, // 0% fees
            feeRecipient: makeAddr("feeRecipient"),
            ledger: address(ledger)
        });

        bytes32[] memory salts = new bytes32[](1);
        salts[0] = zeroFeeOracleId;
        ledgerConfig.setYieldSourceOracles(salts, configs);

        address user = makeAddr("testUser");
        uint256 initialShares = 1000e18;
        uint256 usedShares = 500e18;
        uint256 assetOutput = 1100e18; // 10% profit
        zeroFeeOracleId = _getYieldSourceOracleId(zeroFeeOracleId, address(this));

        // First do an inflow to set up shares
        vm.prank(address(0x777)); // allowed executor
        ledger.updateAccounting(
            user,
            address(erc4626),
            zeroFeeOracleId,
            true, // isInflow
            initialShares,
            0
        );

        // Mock the vault's previewRedeem to return profit
        vm.mockCall(
            address(erc4626), abi.encodeWithSignature("previewRedeem(uint256)", usedShares), abi.encode(assetOutput)
        );

        // Get asset output with fees (should be same as base with 0% fees)
        uint256 assetOutputWithFees = erc4626YieldSourceOracle.getAssetOutputWithFees(
            zeroFeeOracleId, address(erc4626), address(asset), user, usedShares
        );

        assertEq(assetOutputWithFees, assetOutput, "Asset output should equal base output with zero fees");
    }

    function test_ERC4626_getAssetOutputWithFees_WithMaxFees() public {
        // Set up a configuration with max fees (50%) using a unique oracle ID
        bytes32 maxFeeOracleId = bytes32(keccak256("uniqueMaxFeeOracle_test_2024_v1"));

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(erc4626YieldSourceOracle),
            feePercent: 5000, // 50% fees (max allowed)
            feeRecipient: makeAddr("feeRecipient"),
            ledger: address(ledger)
        });

        bytes32[] memory salts = new bytes32[](1);
        salts[0] = maxFeeOracleId;
        ledgerConfig.setYieldSourceOracles(salts, configs);

        address user = makeAddr("testUser");
        uint256 initialShares = 1000e18;
        uint256 usedShares = 1000e18; // Use all shares
        uint256 assetOutput = 2000e18; // 100% profit
        maxFeeOracleId = _getYieldSourceOracleId(maxFeeOracleId, address(this));

        // First do an inflow to set up shares
        vm.prank(address(0x777)); // allowed executor
        ledger.updateAccounting(
            user,
            address(erc4626),
            maxFeeOracleId,
            true, // isInflow
            initialShares,
            0
        );

        // Mock the vault's previewRedeem to return significant profit
        vm.mockCall(
            address(erc4626), abi.encodeWithSignature("previewRedeem(uint256)", usedShares), abi.encode(assetOutput)
        );

        // Get asset output with fees
        uint256 assetOutputWithFees = erc4626YieldSourceOracle.getAssetOutputWithFees(
            maxFeeOracleId, address(erc4626), address(asset), user, usedShares
        );

        // Cost basis = 1000e18, Asset output = 2000e18, Profit = 1000e18
        // Fee = 1000e18 * 50% = 500e18
        // Total with fees = 2000e18 + 500e18 = 2500e18
        uint256 expectedFee = (1000e18 * 5000) / 10_000; // 50% of profit
        uint256 expectedTotal = assetOutput + expectedFee;

        assertEq(assetOutputWithFees, expectedTotal, "Asset output with max fees calculation incorrect");
        assertGt(assetOutputWithFees, assetOutput, "Asset output with max fees should be > base output");
    }

    function test_ERC4626_getAssetOutputWithFees_WithInvalidOracleId() public {
        bytes32 invalidOracleId = bytes32(keccak256("invalidOracle"));
        address user = makeAddr("testUser");
        uint256 usedShares = 1000e18;
        uint256 assetOutput = 1100e18;

        // Mock the vault's previewRedeem for this test
        vm.mockCall(
            address(erc4626), abi.encodeWithSignature("previewRedeem(uint256)", usedShares), abi.encode(assetOutput)
        );
        invalidOracleId = _getYieldSourceOracleId(invalidOracleId, address(this));

        // Get asset output with fees using invalid oracle ID
        // Should fall back to base output (zero fees) due to try/catch
        uint256 assetOutputWithFees = erc4626YieldSourceOracle.getAssetOutputWithFees(
            invalidOracleId, address(erc4626), address(asset), user, usedShares
        );

        // With invalid oracle ID, it should just return the base asset output
        assertEq(assetOutputWithFees, assetOutput, "Should fall back to base output with invalid oracle ID");
    }

    function test_ERC4626_getAssetOutputWithFees_WithDifferentProfitLevels() public {
        bytes32 oracleId = bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY));
        address user = makeAddr("testUser");
        uint256 initialShares = 1000e18;
        uint256 usedShares = 500e18; // Half shares, so cost basis = 500e18
        oracleId = _getYieldSourceOracleId(oracleId, address(this));

        // First do an inflow to set up shares
        vm.prank(address(0x777)); // allowed executor
        ledger.updateAccounting(
            user,
            address(erc4626),
            oracleId,
            true, // isInflow
            initialShares,
            0
        );

        // Test different profit levels
        uint256[] memory assetOutputs = new uint256[](3);
        assetOutputs[0] = 500e18; // No profit
        assetOutputs[1] = 750e18; // 50% profit
        assetOutputs[2] = 1000e18; // 100% profit

        for (uint256 i = 0; i < assetOutputs.length; i++) {
            uint256 assetOutput = assetOutputs[i];

            // Clear any previous mocks
            vm.clearMockedCalls();

            // Mock the vault's previewRedeem for this specific test iteration
            vm.mockCall(
                address(erc4626), abi.encodeWithSignature("previewRedeem(uint256)", usedShares), abi.encode(assetOutput)
            );

            uint256 assetOutputWithFees = erc4626YieldSourceOracle.getAssetOutputWithFees(
                oracleId, address(erc4626), address(asset), user, usedShares
            );

            if (assetOutput <= 500e18) {
                // No profit, no fees
                assertEq(assetOutputWithFees, assetOutput, "No fees should be added when no profit");
            } else {
                // Profit exists, fees should be added
                // Cost basis = 500e18, so profit = assetOutput - 500e18
                uint256 profit = assetOutput - 500e18;
                uint256 expectedFee = (profit * 100) / 10_000; // 1% of profit
                uint256 expectedTotal = assetOutput + expectedFee;

                assertEq(assetOutputWithFees, expectedTotal, "Fees should be calculated correctly when profit exists");
                assertGt(assetOutputWithFees, assetOutput, "Fees should be added when profit exists");
            }
        }
    }

    function test_ERC4626_getAssetOutputWithFees_WithMultipleUsers() public {
        bytes32 oracleId = bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY));
        uint256 initialShares = 1000e18;
        uint256 usedShares = 500e18;
        uint256 assetOutput = 1100e18; // 10% profit

        address[] memory users = new address[](3);
        users[0] = makeAddr("user1");
        users[1] = makeAddr("user2");
        users[2] = makeAddr("user3");
        oracleId = _getYieldSourceOracleId(oracleId, address(this));

        // Set up inflows for each user
        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(address(0x777)); // allowed executor
            ledger.updateAccounting(
                users[i],
                address(erc4626),
                oracleId,
                true, // isInflow
                initialShares,
                0
            );
        }

        // Mock the vault's previewRedeem
        vm.mockCall(
            address(erc4626), abi.encodeWithSignature("previewRedeem(uint256)", usedShares), abi.encode(assetOutput)
        );

        uint256 expectedFee = (600e18 * 100) / 10_000; // 1% of 600e18 profit
        uint256 expectedTotal = assetOutput + expectedFee;

        for (uint256 i = 0; i < users.length; i++) {
            // Get asset output with fees for each user
            uint256 assetOutputWithFees = erc4626YieldSourceOracle.getAssetOutputWithFees(
                oracleId, address(erc4626), address(asset), users[i], usedShares
            );

            // Should be consistent across all users
            assertEq(assetOutputWithFees, expectedTotal, "Asset output with fees should be consistent across users");
        }
    }

    
    function _getYieldSourceOracleId(bytes32 id, address sender) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(id, sender));
    }

}
