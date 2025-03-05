// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

// testing
import { BaseTest } from "../../BaseTest.t.sol";
import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";

// external
import { console2 } from "forge-std/console2.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC5115 } from "../../../src/vendor/vaults/5115/IERC5115.sol";

// superform
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { SuperVaultEscrow } from "../../../src/periphery/SuperVaultEscrow.sol";
import { ISuperVault } from "../../../src/periphery/interfaces/ISuperVault.sol";
import { ERC7540YieldSourceOracle } from "../../../src/core/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { ERC5115YieldSourceOracle } from "../../../src/core/accounting/oracles/ERC5115YieldSourceOracle.sol";
import { ISuperLedger, ISuperLedgerData } from "../../../src/core/interfaces/accounting/ISuperLedger.sol";
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { ISuperVaultFactory } from "../../../src/periphery/interfaces/ISuperVaultFactory.sol";
import { SuperVaultStrategy } from "../../../src/periphery/SuperVaultStrategy.sol";

contract SuperVault5115Underlying is BaseSuperVaultTest {
    IERC5115 public pendleEthena;

    SuperVault public superVaultsUSDE;
    SuperVaultEscrow public superVaultEscrowsUSDE;
    SuperVaultStrategy public superVaultStrategysUSDE;

    function setUp() public override {
        super.setUp();

        vm.selectFork(FORKS[ETH]);

        // Get USDC from fork
        asset = IERC20Metadata(existingUnderlyingTokens[ETH][SUSDE_KEY]);

        address pendleEthenaAddress = realVaultAddresses[ETH][ERC5115_VAULT_KEY][PENDLE_ETHEANA_KEY][SUSDE_KEY];
        vm.label(pendleEthenaAddress, "PendleEthena");

        // Get real yield sources from fork
        pendleEthena = IERC5115(pendleEthena);

        // Deploy vault trio with initial config
        ISuperVaultStrategy.GlobalConfig memory config = ISuperVaultStrategy.GlobalConfig({
            vaultCap: VAULT_CAP,
            superVaultCap: SUPER_VAULT_CAP,
            maxAllocationRate: ONE_HUNDRED_PERCENT,
            vaultThreshold: VAULT_THRESHOLD
        });
        bytes32 hookRoot = _getMerkleRoot();
        address depositHookAddress = _getHookAddress(ETH, DEPOSIT_5115_VAULT_HOOK_KEY);

        address[] memory bootstrapHooks = new address[](1);
        bootstrapHooks[0] = depositHookAddress;

        bytes32[][] memory bootstrapHookProofs = new bytes32[][](1);
        bootstrapHookProofs[0] = _getMerkleProof(depositHookAddress);

        bytes[] memory bootstrapHooksData = new bytes[](1);
        bootstrapHooksData[0] = _createDeposit5115VaultHookData(
            bytes4(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)), 
            address(pendleEthena), 
            address(asset), 
            BOOTSTRAP_AMOUNT,
            BOOTSTRAP_AMOUNT,
            false, 
            false
        );
        vm.startPrank(SV_MANAGER);
        deal(address(asset), SV_MANAGER, BOOTSTRAP_AMOUNT * 2);
        asset.approve(address(factory), BOOTSTRAP_AMOUNT * 2);

        // Deploy vault trio
        (address vaultAddr, address strategyAddr, address escrowAddr) = factory.createVault(
            ISuperVaultFactory.VaultCreationParams({
                asset: address(asset),
                name: "SuperVault sUSDE",
                symbol: "svsUSDE",
                manager: SV_MANAGER,
                strategist: STRATEGIST,
                emergencyAdmin: EMERGENCY_ADMIN,
                feeRecipient: TREASURY,
                config: config,
                finalMaxAllocationRate: MAX_ALLOCATION_RATE,
                bootstrapAmount: BOOTSTRAP_AMOUNT,
                initYieldSource: address(pendleEthena),
                initHooksRoot: hookRoot,
                initYieldSourceOracle: _getContract(ETH, ERC5115_YIELD_SOURCE_ORACLE_KEY),
                bootstrappingHooks: bootstrapHooks,
                bootstrappingHookProofs: bootstrapHookProofs,
                bootstrappingHookCalldata: bootstrapHooksData
            })
        );
        vm.label(vaultAddr, "SuperVault");
        vm.label(strategyAddr, "SuperVaultStrategy");
        vm.label(escrowAddr, "SuperVaultEscrow");

        // Cast addresses to contract types
        superVaultsUSDE = SuperVault(vaultAddr);
        superVaultStrategysUSDE = SuperVaultStrategy(strategyAddr);
        superVaultEscrowsUSDE = SuperVaultEscrow(escrowAddr);

        // Add a new yield source as manager
        superVaultStrategysUSDE.manageYieldSource(
            address(pendleEthena),
            _getContract(ETH, ERC5115_YIELD_SOURCE_ORACLE_KEY),
            0,
            false // addYieldSource
        );
        vm.stopPrank();

        _setFeeConfig(100, TREASURY);

        // Set up hook root (same one as bootstrap, just to test)
        vm.startPrank(SV_MANAGER);
        superVaultStrategysUSDE.proposeOrExecuteHookRoot(hookRoot);
        vm.warp(block.timestamp + 7 days);
        superVaultStrategysUSDE.proposeOrExecuteHookRoot(bytes32(0));
        vm.stopPrank();
    }
    
}
