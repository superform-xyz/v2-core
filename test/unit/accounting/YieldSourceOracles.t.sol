// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

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

contract YieldSourceOraclesTest is Helpers {
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

        erc4626YieldSourceOracle = new ERC4626YieldSourceOracle();
        erc5115YieldSourceOracle = new ERC5115YieldSourceOracle();
        erc7540YieldSourceOracle = new ERC7540YieldSourceOracle();
        stakingYieldSourceOracle = new StakingYieldSourceOracle();

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
}
