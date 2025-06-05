// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// testing
import { console } from "forge-std/console.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { BaseSuperVaultTest } from "./SuperVault/BaseSuperVaultTest.t.sol";
import { AccountInstance, UserOpData, ModuleKitHelpers } from "modulekit/ModuleKit.sol";

// external
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// superform
import { SuperGovernor } from "../../../src/periphery/SuperGovernor.sol";
import { VaultBank } from "../../../src/periphery/VaultBank/VaultBank.sol";
import { SuperOracle } from "../../../src/periphery/oracles/SuperOracle.sol";
import { SuperVault } from "../../../src/periphery/SuperVault/SuperVault.sol";
import { SuperAsset } from "../../../src/periphery/SuperAsset/SuperAsset.sol";
import { VaultBankSource } from "../../../src/periphery/VaultBank/VaultBankSource.sol";
import { VaultBankDestination } from "../../../src/periphery/VaultBank/VaultBankDestination.sol";
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";
import { ISuperVault } from "../../../src/periphery/interfaces/SuperVault/ISuperVault.sol";
import { ISuperAsset } from "../../../src/periphery/interfaces/SuperAsset/ISuperAsset.sol";
import { SuperVaultEscrow } from "../../../src/periphery/SuperVault/SuperVaultEscrow.sol";
import { SuperVaultStrategy } from "../../../src/periphery/SuperVault/SuperVaultStrategy.sol";
import { ISuperVaultEscrow } from "../../../src/periphery/interfaces/SuperVault/ISuperVaultEscrow.sol";
import { ISuperVaultAggregator } from "../../../src/periphery/interfaces/SuperVault/ISuperVaultAggregator.sol";
import { SuperVaultAggregator } from "../../../src/periphery/SuperVault/SuperVaultAggregator.sol";
import { IERC7540Redeem, IERC7741 } from "../../../src/vendor/standards/ERC7540/IERC7540Vault.sol";
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/SuperVault/ISuperVaultStrategy.sol";
import { ERC7540YieldSourceOracle } from "../../../src/core/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { ERC4626YieldSourceOracle } from "../../../src/core/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { SuperAssetFactory, ISuperAssetFactory } from "../../../src/periphery/SuperAsset/SuperAssetFactory.sol";
import { SuperAssetPriceLib } from "../../../src/periphery/libraries/SuperAssetPriceLib.sol";
import { IncentiveFundContract } from "../../../src/periphery/SuperAsset/IncentiveFundContract.sol";
import { IncentiveCalculationContract } from "../../../src/periphery/SuperAsset/IncentiveCalculationContract.sol";

contract E2ESuperAssetSuperVaultTest is BaseSuperVaultTest {
    using ModuleKitHelpers for *;
    using Math for uint256;

    // --- Constants ---
    bytes32 public constant PROVIDER_1 = keccak256("PROVIDER_1");
    bytes32 public constant PROVIDER_2 = keccak256("PROVIDER_2");
    bytes32 public constant PROVIDER_3 = keccak256("PROVIDER_3");
    bytes32 public constant PROVIDER_4 = keccak256("PROVIDER_4");
    bytes32 public constant PROVIDER_5 = keccak256("PROVIDER_5");
    bytes32 public constant PROVIDER_6 = keccak256("PROVIDER_6");
    bytes32 public constant PROVIDER_7 = keccak256("PROVIDER_7");
    bytes32 public constant PROVIDER_8 = keccak256("PROVIDER_8");
    bytes32 public constant PROVIDER_9 = keccak256("PROVIDER_9");
    bytes32 public constant PROVIDER_PRIMARY_ASSET = keccak256("PROVIDER_PRIMARY_ASSET");
    bytes32 public constant PROVIDER_SUPERASSET = keccak256("PROVIDER_SUPERASSET");
    bytes32 public constant PROVIDER_SUPERVAULT1 = keccak256("PROVIDER_SUPERVAULT1");
    bytes32 public constant PROVIDER_SUPERVAULT2 = keccak256("PROVIDER_SUPERVAULT2");

    uint256 constant userPrivateKey = 0xA11CE;

    address public constant operator = address(0x123);
    address public constant USD = address(840);

    // --- State Variables ---
    SuperOracle public oracle;
    VaultBank public vaultBank;
    SuperAsset public superAsset;
    SuperVault public superVault;
    SuperGovernor public governor;
    VaultBankSource public vaultBankSource;
    IncentiveCalculationContract public icc;
    ISuperExecutor public superExecutorOnBase;
    IncentiveFundContract public incentiveFund;
    ISuperAssetFactory public superAssetFactory;
    SuperVaultStrategy public superVaultStrategy;
    VaultBankDestination public vaultBankDestination;
    ISuperVaultAggregator public superVaultAggregator;
    ERC4626YieldSourceOracle public oracleYieldSource4626;
    ERC7540YieldSourceOracle public oracleYieldSource7540;

    address public user;
    address public adminSuperAsset;
    address public managerSuperAsset;
    address public managerSuperVault;
    address public strategistSuperVault;

    // ---- Derived from BaseSuperVaultTest ----
    // SuperExectuorOnEth
    // AccountOnEth -> the address of the smart account
    // InstanceOnEth -> the smart account instance
    // AccInstances -> array of smart account instances

    // IERC4626 public aaveVault
    // IERC4626 public fluidVault
    // IERC20Metadata public usdc -> called asset

    // TotalAssetHelper

    // TODO: Add token feeds here

    function setUp() public override {
        super.setUp();

        vm.selectFork(FORKS[ETH]);

        user = vm.addr(userPrivateKey);
        adminSuperAsset = makeAddr("adminSuperAsset");
        managerSuperAsset = makeAddr("managerSuperAsset");
        managerSuperVault = SV_MANAGER;
        strategistSuperVault = STRATEGIST;

        oracleYieldSource7540 = ERC7540YieldSourceOracle(_getContract(ETH, ERC7540_YIELD_SOURCE_ORACLE_KEY));
        oracleYieldSource4626 = ERC4626YieldSourceOracle(_getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY));

        // vm.startPrank(adminSuperAsset);

        // Deploy SuperGovernor first
        governor = new SuperGovernor(
            adminSuperAsset, // superGovernor role
            adminSuperAsset, // governor role
            adminSuperAsset, // bankManager role
            adminSuperAsset, // treasury
            makeAddr("prover") // mock polymer prover, get from VaultBank.t.sol
        );
        console.log("SuperGovernor deployed");

        // Grant roles
        governor.grantRole(governor.SUPER_GOVERNOR_ROLE(), adminSuperAsset);
        governor.grantRole(governor.GOVERNOR_ROLE(), adminSuperAsset);
        governor.grantRole(governor.BANK_MANAGER_ROLE(), adminSuperAsset);
        console.log("SuperGovernor Roles Granted");

        // Deploy SuperVaultAggregator
        aggregator = new SuperVaultAggregator(address(governor));
        governor.setAddress(governor.SUPER_VAULT_AGGREGATOR(), address(aggregator));

        // TODO: Deploy super vault using the _deployVault function from BaseSuperVaultTest
        // TODO: Explicitly regenerate the Merkle tree with the confirmed strategy address

        // TODO: Now propose and execute the global hooks root update

        // TODO: Set fees for SV like how it is done in _setFeeConfig() of BaseSuperVaultTest but for the new SV

        // TODO: Deploy VaultBankSource

        vm.selectFork(FORKS[BASE]);



        // TODO: Deploy Dest chain SuperGovernor, set permissions and roles

        // TODO: Depoly oracle with real forked feed for usdc or mock feed

        // TODO: Set up feeds here

        // TODO: Deploy VaultBankDestination

        // TODO: Deploy SuperAssetFactory

        icc = new IncentiveCalculationContract();
        superGovernor.addICCToWhitelist(address(icc));

        // TODO: Create SuperAsset using factory with SV and USDC as supported underlying tokens

        // TODO: Set staleness for each feed

        // TODO: Set SuperAsset oracle
    }

    function test_E2ESuperAssetSuperVault() public {
        // 1. Deposit on a 7540 super vault via executor
        // 2. Lock the share in vault bank, moving the share to a second chain
        // 3. Switch fork to the second chain and provide the SuperVault PPS to SuperOracle
        // 4. Supply the share in SuperAsset, alongside other real assets which get whitelisted and test with SuperAsset
        // rebalances

        // For 1.
        // Look at the __deposit() function in BaseSuperVaultTest and its variants

        // For 2.
        // Use CHAIN_1_POLYMER_PROVER
        // Follow logic in VaultBank.t.sol using the Polymer mock

        // For 3.
        // vm.selectFork(FORKS[BASE]);
        // Supply the SuperVault PPS to SuperOracle

        // For 4.
        // Deposit SV share in SuperAsset as one or a few account instances
        // Deposit USDC in SuperAsset as one or a few account instances
        // Redeem some users from SuperAsset


    }
}
