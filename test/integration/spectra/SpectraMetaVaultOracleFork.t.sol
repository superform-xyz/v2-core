// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { SpectraMetaVaultOracle } from "../../../src/accounting/oracles/SpectraMetaVaultOracle.sol";
import { ERC7540YieldSourceOracle } from "../../../src/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { IERC7540 } from "../../../src/vendor/vaults/7540/IERC7540.sol";

/// @title SpectraMetaVaultOracleFork
/// @notice Fork test against live Spectra MetaVault on Base
/// @dev Verifies that the custom oracle fixes both bugs in the generic ERC7540YieldSourceOracle
contract SpectraMetaVaultOracleFork is Test {
    // Spectra MetaVaultWrapper on Base
    address public constant SPECTRA_META_VAULT = 0x6420A613e936602Ca3f1AD5680b3F4d47D473bf1;

    // USDC on Base
    address public constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    SpectraMetaVaultOracle public spectraOracle;
    ERC7540YieldSourceOracle public genericOracle;
    SuperLedgerConfiguration public ledgerConfig;

    function setUp() public {
        string memory baseRpc = vm.envString("BASE_RPC_URL");
        vm.createSelectFork(baseRpc);

        ledgerConfig = new SuperLedgerConfiguration();
        spectraOracle = new SpectraMetaVaultOracle(address(ledgerConfig), 0);
        genericOracle = new ERC7540YieldSourceOracle(address(ledgerConfig), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    BUG FIX #1: getTVL
    //////////////////////////////////////////////////////////////*/

    function test_fork_getTVL_spectraOracle_returnsNonZero() public view {
        uint256 tvl = spectraOracle.getTVL(SPECTRA_META_VAULT);
        console2.log("SpectraOracle getTVL:", tvl);
        assertGt(tvl, 0, "Spectra oracle getTVL must be > 0");
    }

    function test_fork_getTVL_genericOracle_returnsZero() public view {
        uint256 tvl = genericOracle.getTVL(SPECTRA_META_VAULT);
        console2.log("GenericOracle getTVL:", tvl);
        assertEq(tvl, 0, "Generic oracle getTVL returns 0 (the bug)");
    }

    function test_fork_getTVL_matchesConvertToAssetsOfTotalSupply() public view {
        IERC7540 vault = IERC7540(SPECTRA_META_VAULT);
        uint256 totalSupply = IERC20(SPECTRA_META_VAULT).totalSupply();
        uint256 expectedTVL = vault.convertToAssets(totalSupply);

        uint256 tvl = spectraOracle.getTVL(SPECTRA_META_VAULT);
        assertEq(tvl, expectedTVL, "getTVL must equal convertToAssets(totalSupply)");
    }

    /*//////////////////////////////////////////////////////////////
                    PPS
    //////////////////////////////////////////////////////////////*/

    function test_fork_getPricePerShare() public view {
        uint256 pps = spectraOracle.getPricePerShare(SPECTRA_META_VAULT);
        console2.log("PPS:", pps);
        assertGt(pps, 0, "PPS must be > 0");

        // PPS should be convertToAssets(10^6) since USDC is 6 decimals
        IERC7540 vault = IERC7540(SPECTRA_META_VAULT);
        uint256 expectedPPS = vault.convertToAssets(1e6);
        assertEq(pps, expectedPPS, "PPS must match convertToAssets(1e6)");
    }

    function test_fork_getPricePerShare_matchesGenericOracle() public view {
        uint256 spectraPPS = spectraOracle.getPricePerShare(SPECTRA_META_VAULT);
        uint256 genericPPS = genericOracle.getPricePerShare(SPECTRA_META_VAULT);
        assertEq(spectraPPS, genericPPS, "Both oracles must report same PPS");
    }

    /*//////////////////////////////////////////////////////////////
                    DECIMALS & SHARE TOKEN
    //////////////////////////////////////////////////////////////*/

    function test_fork_decimals() public view {
        uint8 dec = spectraOracle.decimals(SPECTRA_META_VAULT);
        assertEq(dec, 6, "MetaVault share decimals must be 6 (USDC)");
    }

    function test_fork_shareTokenFallback() public view {
        // share() reverts → fallback to vault address
        // Verify decimals still works (proves fallback path)
        uint8 dec = spectraOracle.decimals(SPECTRA_META_VAULT);
        assertEq(dec, 6);
    }

    /*//////////////////////////////////////////////////////////////
                    TVL BY OWNER (zero address - no position)
    //////////////////////////////////////////////////////////////*/

    function test_fork_getTVLByOwnerOfShares_zeroAddress() public view {
        uint256 tvl = spectraOracle.getTVLByOwnerOfShares(SPECTRA_META_VAULT, address(0));
        assertEq(tvl, 0, "Zero address should have 0 TVL");
    }

    /*//////////////////////////////////////////////////////////////
                    BALANCE
    //////////////////////////////////////////////////////////////*/

    function test_fork_getBalanceOfOwner() public view {
        uint256 balance = spectraOracle.getBalanceOfOwner(SPECTRA_META_VAULT, address(0));
        assertEq(balance, 0);
    }
}
