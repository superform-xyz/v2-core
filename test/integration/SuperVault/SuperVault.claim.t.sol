// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// testing
import { BaseTest } from "../../BaseTest.t.sol";
import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";

// external
import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

import {
    RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, AccountType, UserOpData
} from "modulekit/ModuleKit.sol";

// superform
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { MerkleReader } from "../../utils/merkle/helper/MerkleReader.sol";
import { PeripheryRegistry } from "../../../src/periphery/PeripheryRegistry.sol";
import { SuperVaultEscrow } from "../../../src/periphery/SuperVaultEscrow.sol";
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { PeripheryRegistry } from "../../../src/periphery/PeripheryRegistry.sol";
import { ISuperLedgerData } from "../../../src/core/interfaces/accounting/ISuperLedger.sol";
import { ISuperLedgerConfiguration } from "../../../src/core/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { SuperRegistry } from "../../../src/core/settings/SuperRegistry.sol";
import { SuperVaultFactory } from "../../../src/periphery/SuperVaultFactory.sol";
import { SuperVaultStrategy } from "../../../src/periphery/SuperVaultStrategy.sol";
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";

import { ISuperVaultFactory } from "../../../src/periphery/interfaces/ISuperVaultFactory.sol";

contract SuperVaultClaimTest is BaseSuperVaultTest, MerkleReader {
    using ModuleKitHelpers for *;
    using Math for uint256;

    address public accountEth;
    AccountInstance public instanceOnEth;
    AccountInstance[] accInstances;

    ISuperExecutor public superExecutorOnEth;

    // Core contracts
    SuperVault public vault;
    SuperVaultEscrow public escrow;
    SuperVaultFactory public factory;
    SuperVaultStrategy public strategy;
    PeripheryRegistry public peripheryRegistry;

    // Roles
    address public SV_MANAGER;
    address public STRATEGIST;
    address public EMERGENCY_ADMIN;

    // Tokens and yield sources
    IERC20Metadata public asset;
    IERC4626 public fluidVault;
    IERC4626 public aaveVault;

    // Constants
    uint256 constant VAULT_CAP = 1_000_000e6; // 1M USDC
    uint256 private constant PRECISION = 1e18;
    uint256 constant SUPER_VAULT_CAP = 5_000_000e6; // 5M USDC
    uint256 constant MAX_ALLOCATION_RATE = 6000; // 50%
    uint256 constant VAULT_THRESHOLD = 100_000e6; // 100k USDC

    uint256 constant ONE_HUNDRED_PERCENT = 10_000;

    uint256 public constant BOOTSTRAP_AMOUNT = 1e6;

    struct SharePricePoint {
        /// @notice Number of shares at this price point
        uint256 shares;
        /// @notice Price per share in asset decimals when these shares were minted
        uint256 pricePerShare;
    }

    mapping(address user => uint256 sharePricePointCursor) public userSharePricePointCursors;

    mapping(address user => SharePricePoint[] sharePricePoints) public userSharePricePoints;

    function setUp() public override {
        super.setUp();

        vm.selectFork(FORKS[ETH]);
        accInstances = randomAccountInstances[ETH];
        assertEq(accInstances.length, ACCOUNT_COUNT);
        peripheryRegistry = PeripheryRegistry(_getContract(ETH, PERIPHERY_REGISTRY_KEY));

        // Set up accounts
        accountEth = accountInstances[ETH].account;
        instanceOnEth = accountInstances[ETH];

        accInstances = randomAccountInstances[ETH];

        // Set up super executor
        superExecutorOnEth = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));

        // Deploy factory
        factory = new SuperVaultFactory(_getContract(ETH, PERIPHERY_REGISTRY_KEY));

        // Set up roles
        SV_MANAGER = _deployAccount(MANAGER_KEY, "SV_MANAGER");
        STRATEGIST = _deployAccount(STRATEGIST_KEY, "STRATEGIST");
        EMERGENCY_ADMIN = _deployAccount(EMERGENCY_ADMIN_KEY, "EMERGENCY_ADMIN");

        // Get USDC from fork
        asset = IERC20Metadata(existingUnderlyingTokens[ETH][USDC_KEY]);

        address fluidVaultAddr = 0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33;
        address aaveVaultAddr = 0x73edDFa87C71ADdC275c2b9890f5c3a8480bC9E6;
        vm.label(fluidVaultAddr, "FluidVault");
        vm.label(aaveVaultAddr, "AaveVault");

        // Get real yield sources from fork
        fluidVault = IERC4626(fluidVaultAddr);
        aaveVault = IERC4626(aaveVaultAddr);

        // Deploy vault trio with initial config
        ISuperVaultStrategy.GlobalConfig memory config = ISuperVaultStrategy.GlobalConfig({
            vaultCap: VAULT_CAP,
            superVaultCap: SUPER_VAULT_CAP,
            maxAllocationRate: ONE_HUNDRED_PERCENT,
            vaultThreshold: VAULT_THRESHOLD
        });
        bytes32 hookRoot = _getMerkleRoot();
        address depositHookAddress = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory bootstrapHooks = new address[](1);
        bootstrapHooks[0] = depositHookAddress;

        bytes32[][] memory bootstrapHookProofs = new bytes32[][](1);
        bootstrapHookProofs[0] = _getMerkleProof(depositHookAddress);

        bytes[] memory bootstrapHooksData = new bytes[](1);
        bootstrapHooksData[0] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(fluidVault), BOOTSTRAP_AMOUNT, false, false
        );
        vm.startPrank(SV_MANAGER);
        deal(address(asset), SV_MANAGER, BOOTSTRAP_AMOUNT * 2);
        asset.approve(address(factory), BOOTSTRAP_AMOUNT * 2);

        // Deploy vault trio
        (address vaultAddr, address strategyAddr, address escrowAddr) = factory.createVault(
            ISuperVaultFactory.VaultCreationParams({
                asset: address(asset),
                name: "SuperVault USDC",
                symbol: "svUSDC",
                manager: SV_MANAGER,
                strategist: STRATEGIST,
                emergencyAdmin: EMERGENCY_ADMIN,
                feeRecipient: TREASURY,
                config: config,
                finalMaxAllocationRate: MAX_ALLOCATION_RATE,
                bootstrapAmount: BOOTSTRAP_AMOUNT,
                initYieldSource: address(fluidVault),
                initHooksRoot: hookRoot,
                initYieldSourceOracle: _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY),
                bootstrappingHooks: bootstrapHooks,
                bootstrappingHookProofs: bootstrapHookProofs,
                bootstrappingHookCalldata: bootstrapHooksData
            })
        );
        vm.label(vaultAddr, "SuperVault");
        vm.label(strategyAddr, "SuperVaultStrategy");
        vm.label(escrowAddr, "SuperVaultEscrow");

        // Cast addresses to contract types
        vault = SuperVault(vaultAddr);
        strategy = SuperVaultStrategy(strategyAddr);
        escrow = SuperVaultEscrow(escrowAddr);

        // Add a new yield source as manager
        strategy.manageYieldSource(
            address(aaveVault),
            _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY),
            0,
            false // addYieldSource
        );
        vm.stopPrank();

        _setFeeConfig(100, TREASURY);

        // Set up hook root (same one as bootstrap, just to test)
        vm.startPrank(SV_MANAGER);
        strategy.proposeOrExecuteHookRoot(hookRoot);
        vm.warp(block.timestamp + 7 days);
        strategy.proposeOrExecuteHookRoot(bytes32(0));
        vm.stopPrank();
    }
}
