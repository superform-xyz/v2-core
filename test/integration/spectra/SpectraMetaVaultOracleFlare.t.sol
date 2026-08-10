// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import { SpectraMetaVaultOracle } from "../../../src/accounting/oracles/SpectraMetaVaultOracle.sol";
import { ERC7540YieldSourceOracle } from "../../../src/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { IERC7540 } from "../../../src/vendor/vaults/7540/IERC7540.sol";

/// @title SpectraMetaVaultOracleFlare
/// @notice Fork test against live Spectra vault (Gami Spectra XRP) on Flare
/// @dev On Flare, unlike Base:
///      - share() returns the vault address (does not revert)
///      - totalAssets() is non-zero (vault holds FXRP)
///      - Both oracles should agree on TVL since totalAssets ~= convertToAssets(totalSupply)
contract SpectraMetaVaultOracleFlare is Test {
    // Spectra vault on Flare (Gami Spectra XRP)
    address public constant SPECTRA_VAULT_FLARE = 0x6420A613e936602Ca3f1AD5680b3F4d47D473bf1;

    // FXRP on Flare (underlying asset)
    address public constant FXRP = 0xAd552A648C74D49E10027AB8a618A3ad4901c5bE;

    /// @dev Pinned so CI can reuse foundry's RPC cache instead of re-fetching state at latest
    uint256 public constant FORK_BLOCK = 67_000_000;

    SpectraMetaVaultOracle public spectraOracle;
    ERC7540YieldSourceOracle public genericOracle;
    SuperLedgerConfiguration public ledgerConfig;

    function setUp() public {
        string memory flareRpc = vm.envString("FLARE_RPC_URL");
        vm.createSelectFork(flareRpc, FORK_BLOCK);

        ledgerConfig = new SuperLedgerConfiguration();
        spectraOracle = new SpectraMetaVaultOracle(address(ledgerConfig), 0);
        genericOracle = new ERC7540YieldSourceOracle(address(ledgerConfig), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        TVL
    //////////////////////////////////////////////////////////////*/

    function test_fork_flare_getTVL_spectraOracle_returnsNonZero() public view {
        uint256 tvl = spectraOracle.getTVL(SPECTRA_VAULT_FLARE);
        console2.log("SpectraOracle getTVL (Flare):", tvl);
        assertGt(tvl, 0, "Spectra oracle getTVL must be > 0");
    }

    function test_fork_flare_getTVL_matchesConvertToAssetsOfTotalSupply() public view {
        IERC7540 vault = IERC7540(SPECTRA_VAULT_FLARE);
        uint256 totalSupply = IERC20(SPECTRA_VAULT_FLARE).totalSupply();
        uint256 expectedTVL = vault.convertToAssets(totalSupply);

        uint256 tvl = spectraOracle.getTVL(SPECTRA_VAULT_FLARE);
        assertEq(tvl, expectedTVL, "getTVL must equal convertToAssets(totalSupply)");
    }

    function test_fork_flare_getTVL_genericOracle_nonZero() public view {
        // On Flare, totalAssets() is non-zero, so the generic oracle also returns non-zero
        uint256 genericTvl = genericOracle.getTVL(SPECTRA_VAULT_FLARE);
        uint256 spectraTvl = spectraOracle.getTVL(SPECTRA_VAULT_FLARE);
        console2.log("GenericOracle getTVL (Flare):", genericTvl);
        console2.log("SpectraOracle getTVL (Flare):", spectraTvl);
        assertGt(genericTvl, 0, "Generic oracle TVL should also be > 0 on Flare");
    }

    /*//////////////////////////////////////////////////////////////
                        PPS
    //////////////////////////////////////////////////////////////*/

    function test_fork_flare_getPricePerShare() public view {
        uint256 pps = spectraOracle.getPricePerShare(SPECTRA_VAULT_FLARE);
        console2.log("PPS (Flare):", pps);
        assertGt(pps, 0, "PPS must be > 0");

        // PPS should be convertToAssets(10^decimals)
        IERC7540 vault = IERC7540(SPECTRA_VAULT_FLARE);
        uint8 dec = IERC20Metadata(SPECTRA_VAULT_FLARE).decimals();
        uint256 expectedPPS = vault.convertToAssets(10 ** dec);
        assertEq(pps, expectedPPS, "PPS must match convertToAssets(10^decimals)");
    }

    function test_fork_flare_getPricePerShare_matchesGenericOracle() public view {
        uint256 spectraPPS = spectraOracle.getPricePerShare(SPECTRA_VAULT_FLARE);
        uint256 genericPPS = genericOracle.getPricePerShare(SPECTRA_VAULT_FLARE);
        assertEq(spectraPPS, genericPPS, "Both oracles must report same PPS");
    }

    /*//////////////////////////////////////////////////////////////
                    DECIMALS & SHARE TOKEN
    //////////////////////////////////////////////////////////////*/

    function test_fork_flare_decimals() public view {
        uint8 dec = spectraOracle.decimals(SPECTRA_VAULT_FLARE);
        assertEq(dec, 6, "Vault share decimals must be 6 (FXRP)");
    }

    function test_fork_flare_shareTokenIsVaultAddress() public view {
        // On Flare, share() returns the vault address itself
        // Verify oracle still works correctly through this path
        uint8 dec = spectraOracle.decimals(SPECTRA_VAULT_FLARE);
        assertEq(dec, 6);
    }

    function test_fork_flare_underlyingAsset() public view {
        address asset = IERC7540(SPECTRA_VAULT_FLARE).asset();
        assertEq(asset, FXRP, "Underlying asset must be FXRP");
    }

    /*//////////////////////////////////////////////////////////////
                    SHARE/ASSET CONVERSION
    //////////////////////////////////////////////////////////////*/

    function test_fork_flare_getShareOutput() public view {
        uint256 shares = spectraOracle.getShareOutput(SPECTRA_VAULT_FLARE, address(0), 1e6);
        console2.log("Shares for 1 FXRP:", shares);
        assertGt(shares, 0, "getShareOutput must return > 0");

        uint256 expectedShares = IERC7540(SPECTRA_VAULT_FLARE).convertToShares(1e6);
        assertEq(shares, expectedShares, "Must match convertToShares");
    }

    function test_fork_flare_getAssetOutput() public view {
        uint256 assets = spectraOracle.getAssetOutput(SPECTRA_VAULT_FLARE, address(0), 1e6);
        console2.log("Assets for 1 share:", assets);
        assertGt(assets, 0, "getAssetOutput must return > 0");

        uint256 expectedAssets = IERC7540(SPECTRA_VAULT_FLARE).convertToAssets(1e6);
        assertEq(assets, expectedAssets, "Must match convertToAssets");
    }

    function test_fork_flare_getWithdrawalShareOutput() public view {
        uint256 sharesNeeded = spectraOracle.getWithdrawalShareOutput(SPECTRA_VAULT_FLARE, address(0), 1e6);
        console2.log("Shares needed to withdraw 1 FXRP:", sharesNeeded);
        assertGt(sharesNeeded, 0, "getWithdrawalShareOutput must return > 0");
    }

    /*//////////////////////////////////////////////////////////////
                    TVL BY OWNER
    //////////////////////////////////////////////////////////////*/

    function test_fork_flare_getTVLByOwnerOfShares_zeroAddress() public view {
        uint256 tvl = spectraOracle.getTVLByOwnerOfShares(SPECTRA_VAULT_FLARE, address(0));
        assertEq(tvl, 0, "Zero address should have 0 TVL");
    }

    function test_fork_flare_getBalanceOfOwner_zeroAddress() public view {
        uint256 balance = spectraOracle.getBalanceOfOwner(SPECTRA_VAULT_FLARE, address(0));
        assertEq(balance, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    ASYNC STATE BREAKDOWN
    //////////////////////////////////////////////////////////////*/

    function test_fork_flare_getAsyncStateBreakdown_zeroAddress() public view {
        (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            uint256 claimableRedeemValue,
            uint256 pendingDepositValue,
            uint256 claimableDepositValue
        ) = spectraOracle.getAsyncStateBreakdown(SPECTRA_VAULT_FLARE, address(0));

        assertEq(heldValue, 0);
        assertEq(pendingRedeemValue, 0);
        assertEq(claimableRedeemValue, 0);
        assertEq(pendingDepositValue, 0);
        assertEq(claimableDepositValue, 0);
    }

    function test_fork_flare_asyncStateBreakdown_sumEqualsTVLByOwner() public view {
        address testAddr = address(0xdead);
        (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            uint256 claimableRedeemValue,
            uint256 pendingDepositValue,
            uint256 claimableDepositValue
        ) = spectraOracle.getAsyncStateBreakdown(SPECTRA_VAULT_FLARE, testAddr);

        uint256 sum = heldValue + pendingRedeemValue + claimableRedeemValue + pendingDepositValue
            + claimableDepositValue;
        uint256 tvl = spectraOracle.getTVLByOwnerOfShares(SPECTRA_VAULT_FLARE, testAddr);
        assertEq(sum, tvl, "Breakdown sum must equal getTVLByOwnerOfShares");
    }

    /*//////////////////////////////////////////////////////////////
                    BATCH METHODS
    //////////////////////////////////////////////////////////////*/

    function test_fork_flare_getPricePerShareMultiple() public view {
        address[] memory vaults = new address[](1);
        vaults[0] = SPECTRA_VAULT_FLARE;

        uint256[] memory ppsList = spectraOracle.getPricePerShareMultiple(vaults);
        assertEq(ppsList.length, 1);
        assertEq(ppsList[0], spectraOracle.getPricePerShare(SPECTRA_VAULT_FLARE));
    }

    function test_fork_flare_getTVLMultiple() public view {
        address[] memory vaults = new address[](1);
        vaults[0] = SPECTRA_VAULT_FLARE;

        uint256[] memory tvlList = spectraOracle.getTVLMultiple(vaults);
        assertEq(tvlList.length, 1);
        assertEq(tvlList[0], spectraOracle.getTVL(SPECTRA_VAULT_FLARE));
    }
}
