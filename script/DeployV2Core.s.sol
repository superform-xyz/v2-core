// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { DeployV2Base } from "./DeployV2Base.s.sol";
import { ISuperDeployer } from "./utils/ISuperDeployer.sol";
import { ConfigCore } from "./utils/ConfigCore.sol";
import { ConfigOtherHooks } from "./utils/ConfigOtherHooks.sol";

import { SuperExecutor } from "../src/core/executors/SuperExecutor.sol";
import { SuperDestinationExecutor } from "../src/core/executors/SuperDestinationExecutor.sol";
import { AcrossV3Adapter } from "../src/core/adapters/AcrossV3Adapter.sol";
import { DebridgeAdapter } from "../src/core/adapters/DebridgeAdapter.sol";

import { SuperLedger } from "../src/core/accounting/SuperLedger.sol";
import { FlatFeeLedger } from "../src/core/accounting/FlatFeeLedger.sol";
import { SuperLedgerConfiguration } from "../src/core/accounting/SuperLedgerConfiguration.sol";
import { ISuperLedgerConfiguration } from "../src/core/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { SuperMerkleValidator } from "../src/core/validators/SuperMerkleValidator.sol";
import { SuperDestinationValidator } from "../src/core/validators/SuperDestinationValidator.sol";
import { SuperNativePaymaster } from "../src/core/paymaster/SuperNativePaymaster.sol";

// -- hooks
// ---- | swappers
import { Swap1InchHook } from "../src/core/hooks/swappers/1inch/Swap1InchHook.sol";
import { SwapOdosV2Hook } from "../src/core/hooks/swappers/odos/SwapOdosV2Hook.sol";
import { ApproveAndSwapOdosV2Hook } from "../src/core/hooks/swappers/odos/ApproveAndSwapOdosV2Hook.sol";

// ---- | tokens
import { ApproveERC20Hook } from "../src/core/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { TransferERC20Hook } from "../src/core/hooks/tokens/erc20/TransferERC20Hook.sol";
import { BatchTransferHook } from "../src/core/hooks/tokens/BatchTransferHook.sol";
import { BatchTransferFromHook } from "../src/core/hooks/tokens/permit2/BatchTransferFromHook.sol";
import { OfframpTokensHook } from "../src/core/hooks/tokens/OfframpTokensHook.sol";
import { MintSuperPositionsHook } from "../src/core/hooks/vaults/vault-bank/MintSuperPositionsHook.sol";

// ---- | vault
import { Deposit4626VaultHook } from "../src/core/hooks/vaults/4626/Deposit4626VaultHook.sol";
import { ApproveAndDeposit4626VaultHook } from "../src/core/hooks/vaults/4626/ApproveAndDeposit4626VaultHook.sol";
import { Redeem4626VaultHook } from "../src/core/hooks/vaults/4626/Redeem4626VaultHook.sol";
import { Deposit5115VaultHook } from "../src/core/hooks/vaults/5115/Deposit5115VaultHook.sol";
import { ApproveAndDeposit5115VaultHook } from "../src/core/hooks/vaults/5115/ApproveAndDeposit5115VaultHook.sol";
import { Redeem5115VaultHook } from "../src/core/hooks/vaults/5115/Redeem5115VaultHook.sol";
import { RequestDeposit7540VaultHook } from "../src/core/hooks/vaults/7540/RequestDeposit7540VaultHook.sol";
import { ApproveAndRequestDeposit7540VaultHook } from
    "../src/core/hooks/vaults/7540/ApproveAndRequestDeposit7540VaultHook.sol";
import { ApproveAndRequestRedeem7540VaultHook } from
    "../src/core/hooks/vaults/7540/ApproveAndRequestRedeem7540VaultHook.sol";
import { Deposit7540VaultHook } from "../src/core/hooks/vaults/7540/Deposit7540VaultHook.sol";
import { Redeem7540VaultHook } from "../src/core/hooks/vaults/7540/Redeem7540VaultHook.sol";
import { RequestRedeem7540VaultHook } from "../src/core/hooks/vaults/7540/RequestRedeem7540VaultHook.sol";
import { Withdraw7540VaultHook } from "../src/core/hooks/vaults/7540/Withdraw7540VaultHook.sol";
import { CancelDepositRequest7540Hook } from "../src/core/hooks/vaults/7540/CancelDepositRequest7540Hook.sol";
import { CancelRedeemRequest7540Hook } from "../src/core/hooks/vaults/7540/CancelRedeemRequest7540Hook.sol";
import { ClaimCancelDepositRequest7540Hook } from "../src/core/hooks/vaults/7540/ClaimCancelDepositRequest7540Hook.sol";
import { ClaimCancelRedeemRequest7540Hook } from "../src/core/hooks/vaults/7540/ClaimCancelRedeemRequest7540Hook.sol";
import { CancelRedeemHook } from "../src/core/hooks/vaults/super-vault/CancelRedeemHook.sol";

// ---- | bridges
import { AcrossSendFundsAndExecuteOnDstHook } from
    "../src/core/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHook.sol";
import { DeBridgeSendOrderAndExecuteOnDstHook } from
    "../src/core/hooks/bridges/debridge/DeBridgeSendOrderAndExecuteOnDstHook.sol";
import { DeBridgeCancelOrderHook } from "../src/core/hooks/bridges/debridge/DeBridgeCancelOrderHook.sol";
import { EthenaCooldownSharesHook } from "../src/core/hooks/vaults/ethena/EthenaCooldownSharesHook.sol";
import { EthenaUnstakeHook } from "../src/core/hooks/vaults/ethena/EthenaUnstakeHook.sol";

// -- oracles
import { ERC4626YieldSourceOracle } from "../src/core/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { ERC5115YieldSourceOracle } from "../src/core/accounting/oracles/ERC5115YieldSourceOracle.sol";
import { ERC7540YieldSourceOracle } from "../src/core/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { PendlePTYieldSourceOracle } from "../src/core/accounting/oracles/PendlePTYieldSourceOracle.sol";
import { SpectraPTYieldSourceOracle } from "../src/core/accounting/oracles/SpectraPTYieldSourceOracle.sol";
import { StakingYieldSourceOracle } from "../src/core/accounting/oracles/StakingYieldSourceOracle.sol";
import { SuperYieldSourceOracle } from "../src/core/accounting/oracles/SuperYieldSourceOracle.sol";

import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";
import { console2 } from "forge-std/console2.sol";

contract DeployV2Core is DeployV2Base, ConfigCore, ConfigOtherHooks {
    struct CoreContracts {
        address superExecutor;
        address acrossV3Adapter;
        address debridgeAdapter;
        address superDestinationExecutor;
        address superLedger;
        address flatFeeLedger;
        address superLedgerConfiguration;
        address superMerkleValidator;
        address superDestinationValidator;
        address superNativePaymaster;
    }

    struct HookAddresses {
        address approveErc20Hook;
        address transferErc20Hook;
        address batchTransferHook;
        address batchTransferFromHook;
        address offrampTokensHook;
        address deposit4626VaultHook;
        address approveAndDeposit4626VaultHook;
        address redeem4626VaultHook;
        address deposit5115VaultHook;
        address redeem5115VaultHook;
        address approveAndDeposit5115VaultHook;
        address deposit7540VaultHook;
        address requestDeposit7540VaultHook;
        address approveAndRequestDeposit7540VaultHook;
        address approveAndRequestRedeem7540VaultHook;
        address redeem7540VaultHook;
        address requestRedeem7540VaultHook;
        address withdraw7540VaultHook;
        address acrossSendFundsAndExecuteOnDstHook;
        address swap1InchHook;
        address swapOdosHook;
        address approveAndSwapOdosHook;
        address cancelDepositRequest7540Hook;
        address cancelRedeemRequest7540Hook;
        address claimCancelDepositRequest7540Hook;
        address claimCancelRedeemRequest7540Hook;
        address cancelRedeemHook;
        address deBridgeSendOrderAndExecuteOnDstHook;
        address deBridgeCancelOrderHook;
        address ethenaCooldownSharesHook;
        address ethenaUnstakeHook;
        address mintSuperPositionHook;
    }

    struct HookDeployment {
        string name;
        bytes creationCode;
    }

    struct OracleDeployment {
        string name;
        bytes creationCode;
    }

    /// @notice Sets up complete configuration for core contracts with hook support
    /// @param env Environment (0/2 = production, 1 = test)
    function _setConfiguration(uint256 env) internal {
        // Set base configuration (chain names, common addresses)
        _setBaseConfiguration(env);

        // Set core contract dependencies
        _setCoreConfiguration();

        // Set protocol router addresses for hooks
        _setOtherHooksConfiguration();
    }

    function run(uint256 env, uint64 chainId) public broadcast(env) {
        _setConfiguration(env);
        console2.log("Deploying V2 Core (Early Access) on chainId: ", chainId);

        _deployDeployer();

        // deploy core contracts
        _deployCoreContracts(chainId);

        // Write all exported contracts for this chain
        _writeExportedContracts(chainId);
    }

    function _deployCoreContracts(uint64 chainId) internal {
        CoreContracts memory coreContracts;

        // retrieve deployer
        ISuperDeployer deployer = ISuperDeployer(configuration.deployer);

        // ===== VALIDATION PHASE =====
        // Validate critical dependencies before deployment
        console2.log("Validating deployment dependencies for chain:", chainId);

        // Check Nexus Factory (required for SuperDestinationExecutor)
        if (configuration.nexusFactories[chainId] == address(0)) {
            revert("NEXUS_FACTORY_NOT_CONFIGURED");
        }
        console2.log(" Nexus Factory:", configuration.nexusFactories[chainId]);

        // Check Permit2 (required for BatchTransferFromHook)
        if (configuration.permit2s[chainId] == address(0)) {
            revert("PERMIT2_NOT_CONFIGURED");
        }
        console2.log(" Permit2:", configuration.permit2s[chainId]);

        // Check critical router addresses
        if (configuration.aggregationRouters[chainId] == address(0)) {
            revert("1INCH_ROUTER_NOT_CONFIGURED");
        }
        if (configuration.odosRouters[chainId] == address(0)) {
            revert("ODOS_ROUTER_NOT_CONFIGURED");
        }

        console2.log(" All critical dependencies validated");

        // ===== DEPLOYMENT PHASE =====

        // Deploy SuperLedgerConfiguration
        coreContracts.superLedgerConfiguration = __deployContract(
            deployer,
            SUPER_LEDGER_CONFIGURATION_KEY,
            chainId,
            __getSalt(SUPER_LEDGER_CONFIGURATION_KEY),
            abi.encodePacked(type(SuperLedgerConfiguration).creationCode, abi.encode(configuration.owner))
        );

        // Validate SuperLedgerConfiguration was deployed
        if (coreContracts.superLedgerConfiguration == address(0)) {
            revert("SUPER_LEDGER_CONFIGURATION_DEPLOYMENT_FAILED");
        }

        // Deploy SuperMerkleValidator
        coreContracts.superMerkleValidator = __deployContract(
            deployer,
            SUPER_MERKLE_VALIDATOR_KEY,
            chainId,
            __getSalt(SUPER_MERKLE_VALIDATOR_KEY),
            type(SuperMerkleValidator).creationCode
        );

        // Deploy SuperDestinationValidator
        coreContracts.superDestinationValidator = __deployContract(
            deployer,
            SUPER_DESTINATION_VALIDATOR_KEY,
            chainId,
            __getSalt(SUPER_DESTINATION_VALIDATOR_KEY),
            type(SuperDestinationValidator).creationCode
        );

        // Deploy SuperExecutor
        coreContracts.superExecutor = __deployContract(
            deployer,
            SUPER_EXECUTOR_KEY,
            chainId,
            __getSalt(SUPER_EXECUTOR_KEY),
            abi.encodePacked(type(SuperExecutor).creationCode, abi.encode(coreContracts.superLedgerConfiguration))
        );

        // Deploy SuperDestinationExecutor - VALIDATED DEPENDENCY
        coreContracts.superDestinationExecutor = __deployContract(
            deployer,
            SUPER_DESTINATION_EXECUTOR_KEY,
            chainId,
            __getSalt(SUPER_DESTINATION_EXECUTOR_KEY),
            abi.encodePacked(
                type(SuperDestinationExecutor).creationCode,
                abi.encode(
                    coreContracts.superLedgerConfiguration,
                    coreContracts.superDestinationValidator,
                    configuration.nexusFactories[chainId] // ✓ VALIDATED: Non-zero
                )
            )
        );

        // Deploy AcrossV3Adapter
        coreContracts.acrossV3Adapter = __deployContract(
            deployer,
            ACROSS_V3_ADAPTER_KEY,
            chainId,
            __getSalt(ACROSS_V3_ADAPTER_KEY),
            abi.encodePacked(
                type(AcrossV3Adapter).creationCode,
                abi.encode(configuration.acrossSpokePoolV3s[chainId], coreContracts.superDestinationExecutor)
            )
        );

        // Deploy DebridgeAdapter - IMPROVED ERROR HANDLING
        if (configuration.debridgeDstDln[chainId] == address(0)) {
            revert("DEBRIDGE_DLN_DST_NOT_CONFIGURED");
        }
        coreContracts.debridgeAdapter = __deployContract(
            deployer,
            DEBRIDGE_ADAPTER_KEY,
            chainId,
            __getSalt(DEBRIDGE_ADAPTER_KEY),
            abi.encodePacked(
                type(DebridgeAdapter).creationCode,
                abi.encode(configuration.debridgeDstDln[chainId], coreContracts.superDestinationExecutor)
            )
        );

        // ===== LEDGER DEPLOYMENT WITH VALIDATED EXECUTORS =====
        address[] memory allowedExecutors = new address[](2);
        allowedExecutors[0] = address(coreContracts.superExecutor);
        allowedExecutors[1] = address(coreContracts.superDestinationExecutor);

        // Validate executor addresses before using them
        if (allowedExecutors[0] == address(0) || allowedExecutors[1] == address(0)) {
            revert("EXECUTOR_DEPLOYMENT_FAILED");
        }
        console2.log(" Validated executor addresses:", allowedExecutors[0], allowedExecutors[1]);

        // Deploy SuperLedger
        coreContracts.superLedger = __deployContract(
            deployer,
            SUPER_LEDGER_KEY,
            chainId,
            __getSalt(SUPER_LEDGER_KEY),
            abi.encodePacked(
                type(SuperLedger).creationCode, abi.encode(coreContracts.superLedgerConfiguration, allowedExecutors)
            )
        );

        // Deploy FlatFeeLedger
        coreContracts.flatFeeLedger = __deployContract(
            deployer,
            FLAT_FEE_LEDGER_KEY,
            chainId,
            __getSalt(FLAT_FEE_LEDGER_KEY),
            abi.encodePacked(
                type(FlatFeeLedger).creationCode, abi.encode(coreContracts.superLedgerConfiguration, allowedExecutors)
            )
        );

        // Deploy SuperNativePaymaster
        coreContracts.superNativePaymaster = __deployContract(
            deployer,
            SUPER_NATIVE_PAYMASTER_KEY,
            chainId,
            __getSalt(SUPER_NATIVE_PAYMASTER_KEY),
            abi.encodePacked(type(SuperNativePaymaster).creationCode, abi.encode(ENTRY_POINT))
        );

        console2.log("Core contracts deployment completed successfully");

        // Deploy Hooks
        _deployHooks(deployer, chainId);

        // Deploy Oracles
        _deployOracles(deployer, chainId);

        // Setup SuperLedger configuration with oracle mappings
        _setupSuperLedgerConfiguration(chainId);
    }

    function _deployHooks(
        ISuperDeployer deployer,
        uint64 chainId
    )
        private
        returns (HookAddresses memory hookAddresses)
    {
        console2.log("Starting hook deployment with dependency validation...");

        uint256 len = 32;
        HookDeployment[] memory hooks = new HookDeployment[](len);
        address[] memory addresses = new address[](len);

        // ===== HOOKS WITHOUT DEPENDENCIES =====
        hooks[0] = HookDeployment(APPROVE_ERC20_HOOK_KEY, type(ApproveERC20Hook).creationCode);
        hooks[1] = HookDeployment(TRANSFER_ERC20_HOOK_KEY, type(TransferERC20Hook).creationCode);
        hooks[2] = HookDeployment(BATCH_TRANSFER_HOOK_KEY, type(BatchTransferHook).creationCode);

        // ===== HOOKS WITH VALIDATED DEPENDENCIES =====

        // BatchTransferFromHook - Requires Permit2 (already validated)
        if (configuration.permit2s[chainId] == address(0)) {
            revert("PERMIT2_NOT_CONFIGURED");
        }
        hooks[3] = HookDeployment(
            BATCH_TRANSFER_FROM_HOOK_KEY,
            abi.encodePacked(type(BatchTransferFromHook).creationCode, abi.encode(configuration.permit2s[chainId]))
        );
        // Vault hooks (no external dependencies)
        hooks[4] = HookDeployment(DEPOSIT_4626_VAULT_HOOK_KEY, type(Deposit4626VaultHook).creationCode);
        hooks[5] =
            HookDeployment(APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY, type(ApproveAndDeposit4626VaultHook).creationCode);
        hooks[6] = HookDeployment(REDEEM_4626_VAULT_HOOK_KEY, type(Redeem4626VaultHook).creationCode);
        hooks[7] = HookDeployment(DEPOSIT_5115_VAULT_HOOK_KEY, type(Deposit5115VaultHook).creationCode);
        hooks[8] =
            HookDeployment(APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY, type(ApproveAndDeposit5115VaultHook).creationCode);
        hooks[9] = HookDeployment(REDEEM_5115_VAULT_HOOK_KEY, type(Redeem5115VaultHook).creationCode);
        hooks[10] = HookDeployment(REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY, type(RequestDeposit7540VaultHook).creationCode);
        hooks[11] = HookDeployment(
            APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY, type(ApproveAndRequestDeposit7540VaultHook).creationCode
        );
        hooks[12] = HookDeployment(
            APPROVE_AND_REQUEST_REDEEM_7540_VAULT_HOOK_KEY, type(ApproveAndRequestRedeem7540VaultHook).creationCode
        );
        hooks[13] = HookDeployment(REDEEM_7540_VAULT_HOOK_KEY, type(Redeem7540VaultHook).creationCode);
        hooks[14] = HookDeployment(REQUEST_REDEEM_7540_VAULT_HOOK_KEY, type(RequestRedeem7540VaultHook).creationCode);
        hooks[15] = HookDeployment(DEPOSIT_7540_VAULT_HOOK_KEY, type(Deposit7540VaultHook).creationCode);
        hooks[16] = HookDeployment(WITHDRAW_7540_VAULT_HOOK_KEY, type(Withdraw7540VaultHook).creationCode);

        // ===== HOOKS WITH EXTERNAL ROUTER DEPENDENCIES =====

        // 1inch Swap Hook - Validate aggregation router
        if (configuration.aggregationRouters[chainId] == address(0)) {
            revert("1INCH_ROUTER_NOT_CONFIGURED");
        }
        hooks[17] = HookDeployment(
            SWAP_1INCH_HOOK_KEY,
            abi.encodePacked(type(Swap1InchHook).creationCode, abi.encode(configuration.aggregationRouters[chainId]))
        );

        // ODOS Swap Hooks - Validate ODOS router
        if (configuration.odosRouters[chainId] == address(0)) {
            revert("ODOS_ROUTER_NOT_CONFIGURED");
        }
        hooks[18] = HookDeployment(
            SWAP_ODOSV2_HOOK_KEY,
            abi.encodePacked(type(SwapOdosV2Hook).creationCode, abi.encode(configuration.odosRouters[chainId]))
        );
        hooks[19] = HookDeployment(
            APPROVE_AND_SWAP_ODOSV2_HOOK_KEY,
            abi.encodePacked(
                type(ApproveAndSwapOdosV2Hook).creationCode, abi.encode(configuration.odosRouters[chainId])
            )
        );

        // Across Bridge Hook - Validate Across Spoke Pool
        if (configuration.acrossSpokePoolV3s[chainId] == address(0)) {
            revert("ACROSS_SPOKE_POOL_V3_NOT_CONFIGURED");
        }
        hooks[20] = HookDeployment(
            ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY,
            abi.encodePacked(
                type(AcrossSendFundsAndExecuteOnDstHook).creationCode,
                abi.encode(configuration.acrossSpokePoolV3s[chainId], _getContract(chainId, SUPER_MERKLE_VALIDATOR_KEY))
            )
        );

        // DeBridge hooks (use constants - always available)
        hooks[21] = HookDeployment(
            DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY,
            abi.encodePacked(
                type(DeBridgeSendOrderAndExecuteOnDstHook).creationCode,
                abi.encode(DEBRIDGE_DLN_SRC, _getContract(chainId, SUPER_MERKLE_VALIDATOR_KEY))
            )
        );
        hooks[22] = HookDeployment(
            DEBRIDGE_CANCEL_ORDER_HOOK_KEY,
            abi.encodePacked(type(DeBridgeCancelOrderHook).creationCode, abi.encode(DEBRIDGE_DLN_DST))
        );

        // Protocol-specific hooks (no external dependencies)
        hooks[23] = HookDeployment(ETHENA_COOLDOWN_SHARES_HOOK_KEY, type(EthenaCooldownSharesHook).creationCode);
        hooks[24] = HookDeployment(ETHENA_UNSTAKE_HOOK_KEY, type(EthenaUnstakeHook).creationCode);
        hooks[25] =
            HookDeployment(CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY, type(CancelDepositRequest7540Hook).creationCode);
        hooks[26] = HookDeployment(CANCEL_REDEEM_REQUEST_7540_HOOK_KEY, type(CancelRedeemRequest7540Hook).creationCode);
        hooks[27] = HookDeployment(
            CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY, type(ClaimCancelDepositRequest7540Hook).creationCode
        );
        hooks[28] = HookDeployment(
            CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY, type(ClaimCancelRedeemRequest7540Hook).creationCode
        );
        hooks[29] = HookDeployment(CANCEL_REDEEM_HOOK_KEY, type(CancelRedeemHook).creationCode);
        hooks[30] = HookDeployment(OFFRAMP_TOKENS_HOOK_KEY, type(OfframpTokensHook).creationCode);
        hooks[31] = HookDeployment(MINT_SUPERPOSITIONS_HOOK_KEY, type(MintSuperPositionsHook).creationCode);

        // ===== DEPLOY ALL HOOKS =====
        console2.log("Deploying", len, "hooks...");
        for (uint256 i = 0; i < len; ++i) {
            HookDeployment memory hook = hooks[i];
            addresses[i] = __deployContract(deployer, hook.name, chainId, __getSalt(hook.name), hook.creationCode);
        }

        // Assign hook addresses
        hookAddresses.approveErc20Hook =
            Strings.equal(hooks[0].name, APPROVE_ERC20_HOOK_KEY) ? addresses[0] : address(0);
        hookAddresses.transferErc20Hook =
            Strings.equal(hooks[1].name, TRANSFER_ERC20_HOOK_KEY) ? addresses[1] : address(0);
        hookAddresses.batchTransferHook =
            Strings.equal(hooks[2].name, BATCH_TRANSFER_HOOK_KEY) ? addresses[2] : address(0);
        hookAddresses.batchTransferFromHook =
            Strings.equal(hooks[3].name, BATCH_TRANSFER_FROM_HOOK_KEY) ? addresses[3] : address(0);
        hookAddresses.deposit4626VaultHook =
            Strings.equal(hooks[4].name, DEPOSIT_4626_VAULT_HOOK_KEY) ? addresses[4] : address(0);
        hookAddresses.approveAndDeposit4626VaultHook =
            Strings.equal(hooks[5].name, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY) ? addresses[5] : address(0);
        hookAddresses.redeem4626VaultHook =
            Strings.equal(hooks[6].name, REDEEM_4626_VAULT_HOOK_KEY) ? addresses[6] : address(0);
        hookAddresses.deposit5115VaultHook =
            Strings.equal(hooks[7].name, DEPOSIT_5115_VAULT_HOOK_KEY) ? addresses[7] : address(0);
        hookAddresses.approveAndDeposit5115VaultHook =
            Strings.equal(hooks[8].name, APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY) ? addresses[8] : address(0);
        hookAddresses.redeem5115VaultHook =
            Strings.equal(hooks[9].name, REDEEM_5115_VAULT_HOOK_KEY) ? addresses[9] : address(0);
        hookAddresses.requestDeposit7540VaultHook =
            Strings.equal(hooks[10].name, REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY) ? addresses[10] : address(0);
        hookAddresses.approveAndRequestDeposit7540VaultHook =
            Strings.equal(hooks[11].name, APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY) ? addresses[11] : address(0);
        hookAddresses.approveAndRequestRedeem7540VaultHook =
            Strings.equal(hooks[12].name, APPROVE_AND_REQUEST_REDEEM_7540_VAULT_HOOK_KEY) ? addresses[12] : address(0);
        hookAddresses.redeem7540VaultHook =
            Strings.equal(hooks[13].name, REDEEM_7540_VAULT_HOOK_KEY) ? addresses[13] : address(0);
        hookAddresses.requestRedeem7540VaultHook =
            Strings.equal(hooks[14].name, REQUEST_REDEEM_7540_VAULT_HOOK_KEY) ? addresses[14] : address(0);
        hookAddresses.deposit7540VaultHook =
            Strings.equal(hooks[15].name, DEPOSIT_7540_VAULT_HOOK_KEY) ? addresses[15] : address(0);
        hookAddresses.withdraw7540VaultHook =
            Strings.equal(hooks[16].name, WITHDRAW_7540_VAULT_HOOK_KEY) ? addresses[16] : address(0);
        hookAddresses.swap1InchHook = Strings.equal(hooks[17].name, SWAP_1INCH_HOOK_KEY) ? addresses[17] : address(0);
        hookAddresses.swapOdosHook = Strings.equal(hooks[18].name, SWAP_ODOSV2_HOOK_KEY) ? addresses[18] : address(0);
        hookAddresses.approveAndSwapOdosHook =
            Strings.equal(hooks[19].name, APPROVE_AND_SWAP_ODOSV2_HOOK_KEY) ? addresses[19] : address(0);
        hookAddresses.acrossSendFundsAndExecuteOnDstHook =
            Strings.equal(hooks[20].name, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY) ? addresses[20] : address(0);
        hookAddresses.deBridgeSendOrderAndExecuteOnDstHook =
            Strings.equal(hooks[21].name, DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY) ? addresses[21] : address(0);
        hookAddresses.deBridgeCancelOrderHook =
            Strings.equal(hooks[22].name, DEBRIDGE_CANCEL_ORDER_HOOK_KEY) ? addresses[22] : address(0);
        hookAddresses.ethenaCooldownSharesHook =
            Strings.equal(hooks[23].name, ETHENA_COOLDOWN_SHARES_HOOK_KEY) ? addresses[23] : address(0);
        hookAddresses.ethenaUnstakeHook =
            Strings.equal(hooks[24].name, ETHENA_UNSTAKE_HOOK_KEY) ? addresses[24] : address(0);
        hookAddresses.cancelDepositRequest7540Hook =
            Strings.equal(hooks[25].name, CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY) ? addresses[25] : address(0);
        hookAddresses.cancelRedeemRequest7540Hook =
            Strings.equal(hooks[26].name, CANCEL_REDEEM_REQUEST_7540_HOOK_KEY) ? addresses[26] : address(0);
        hookAddresses.claimCancelDepositRequest7540Hook =
            Strings.equal(hooks[27].name, CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY) ? addresses[27] : address(0);
        hookAddresses.claimCancelRedeemRequest7540Hook =
            Strings.equal(hooks[28].name, CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY) ? addresses[28] : address(0);
        hookAddresses.cancelRedeemHook =
            Strings.equal(hooks[29].name, CANCEL_REDEEM_HOOK_KEY) ? addresses[29] : address(0);
        hookAddresses.offrampTokensHook =
            Strings.equal(hooks[30].name, OFFRAMP_TOKENS_HOOK_KEY) ? addresses[30] : address(0);
        hookAddresses.mintSuperPositionHook =
            Strings.equal(hooks[31].name, MINT_SUPERPOSITIONS_HOOK_KEY) ? addresses[31] : address(0);

        // Verify critical hooks were deployed successfully
        require(hookAddresses.approveErc20Hook != address(0), "approveErc20Hook not assigned");
        require(hookAddresses.transferErc20Hook != address(0), "transferErc20Hook not assigned");
        require(hookAddresses.batchTransferHook != address(0), "batchTransferHook not assigned");
        require(hookAddresses.batchTransferFromHook != address(0), "batchTransferFromHook not assigned");
        require(hookAddresses.deposit4626VaultHook != address(0), "deposit4626VaultHook not assigned");
        require(
            hookAddresses.approveAndDeposit4626VaultHook != address(0), "approveAndDeposit4626VaultHook not assigned"
        );
        require(hookAddresses.redeem4626VaultHook != address(0), "redeem4626VaultHook not assigned");
        require(hookAddresses.deposit5115VaultHook != address(0), "deposit5115VaultHook not assigned");
        require(
            hookAddresses.approveAndDeposit5115VaultHook != address(0), "approveAndDeposit5115VaultHook not assigned"
        );
        require(hookAddresses.redeem5115VaultHook != address(0), "redeem5115VaultHook not assigned");
        require(hookAddresses.redeem7540VaultHook != address(0), "redeem7540VaultHook not assigned");
        require(hookAddresses.requestDeposit7540VaultHook != address(0), "requestDeposit7540VaultHook not assigned");
        require(
            hookAddresses.approveAndRequestDeposit7540VaultHook != address(0),
            "approveAndRequestDeposit7540VaultHook not assigned"
        );
        require(hookAddresses.requestRedeem7540VaultHook != address(0), "requestRedeem7540VaultHook not assigned");
        require(hookAddresses.deposit7540VaultHook != address(0), "deposit7540VaultHook not assigned");
        require(hookAddresses.withdraw7540VaultHook != address(0), "withdraw7540VaultHook not assigned");
        require(
            hookAddresses.approveAndRequestRedeem7540VaultHook != address(0),
            "approveAndRequestRedeem7540VaultHook not assigned"
        );
        require(hookAddresses.swap1InchHook != address(0), "swap1InchHook not assigned");
        require(hookAddresses.swapOdosHook != address(0), "swapOdosHook not assigned");
        require(hookAddresses.approveAndSwapOdosHook != address(0), "approveAndSwapOdosHook not assigned");
        require(
            hookAddresses.acrossSendFundsAndExecuteOnDstHook != address(0),
            "acrossSendFundsAndExecuteOnDstHook not assigned"
        );
        require(
            hookAddresses.deBridgeSendOrderAndExecuteOnDstHook != address(0),
            "deBridgeSendOrderAndExecuteOnDstHook not assigned"
        );

        require(hookAddresses.cancelDepositRequest7540Hook != address(0), "cancelDepositRequest7540Hook not assigned");
        require(hookAddresses.cancelRedeemRequest7540Hook != address(0), "cancelRedeemRequest7540Hook not assigned");
        require(
            hookAddresses.claimCancelDepositRequest7540Hook != address(0),
            "claimCancelDepositRequest7540Hook not assigned"
        );
        require(
            hookAddresses.claimCancelRedeemRequest7540Hook != address(0),
            "claimCancelRedeemRequest7540Hook not assigned"
        );
        require(hookAddresses.cancelRedeemHook != address(0), "cancelRedeemHook not assigned");
        require(hookAddresses.ethenaCooldownSharesHook != address(0), "ethenaCooldownSharesHook not assigned");
        require(hookAddresses.ethenaUnstakeHook != address(0), "ethenaUnstakeHook not assigned");
        require(hookAddresses.offrampTokensHook != address(0), "offrampTokensHook not assigned");
        require(hookAddresses.mintSuperPositionHook != address(0), "mintSuperPositionHook not assigned");

        console2.log("All hooks deployed and validated successfully with dependency checking!");

        return hookAddresses;
    }

    function _deployOracles(
        ISuperDeployer deployer,
        uint64 chainId
    )
        private
        returns (address[] memory oracleAddresses)
    {
        uint256 len = 7;
        OracleDeployment[] memory oracles = new OracleDeployment[](len);
        oracleAddresses = new address[](len);

        address superLedgerConfig = _getContract(chainId, SUPER_LEDGER_CONFIGURATION_KEY);

        oracles[0] = OracleDeployment(
            ERC4626_YIELD_SOURCE_ORACLE_KEY,
            abi.encodePacked(type(ERC4626YieldSourceOracle).creationCode, abi.encode(superLedgerConfig))
        );
        oracles[1] = OracleDeployment(
            ERC5115_YIELD_SOURCE_ORACLE_KEY,
            abi.encodePacked(type(ERC5115YieldSourceOracle).creationCode, abi.encode(superLedgerConfig))
        );
        oracles[2] = OracleDeployment(
            ERC7540_YIELD_SOURCE_ORACLE_KEY,
            abi.encodePacked(type(ERC7540YieldSourceOracle).creationCode, abi.encode(superLedgerConfig))
        );
        oracles[3] = OracleDeployment(
            PENDLE_PT_YIELD_SOURCE_ORACLE_KEY,
            abi.encodePacked(type(PendlePTYieldSourceOracle).creationCode, abi.encode(superLedgerConfig))
        );
        oracles[4] = OracleDeployment(
            SPECTRA_PT_YIELD_SOURCE_ORACLE_KEY,
            abi.encodePacked(type(SpectraPTYieldSourceOracle).creationCode, abi.encode(superLedgerConfig))
        );
        oracles[5] = OracleDeployment(
            STAKING_YIELD_SOURCE_ORACLE_KEY,
            abi.encodePacked(type(StakingYieldSourceOracle).creationCode, abi.encode(superLedgerConfig))
        );
        oracles[6] = OracleDeployment(SUPER_YIELD_SOURCE_ORACLE_KEY, type(SuperYieldSourceOracle).creationCode);

        for (uint256 i = 0; i < len; ++i) {
            OracleDeployment memory oracle = oracles[i];
            oracleAddresses[i] =
                __deployContract(deployer, oracle.name, chainId, __getSalt(oracle.name), oracle.creationCode);
        }
    }

    function _setupSuperLedgerConfiguration(uint64 chainId) private {
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](4);

        // Note: Since this is core deployment without SuperGovernor, we use owner directly
        // The periphery deployment will later update fee recipients to use SuperGovernor treasury
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: _getContract(chainId, ERC4626_YIELD_SOURCE_ORACLE_KEY),
            feePercent: 0,
            feeRecipient: configuration.owner,
            ledger: _getContract(chainId, SUPER_LEDGER_KEY)
        });
        configs[1] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: _getContract(chainId, ERC7540_YIELD_SOURCE_ORACLE_KEY),
            feePercent: 0,
            feeRecipient: configuration.owner,
            ledger: _getContract(chainId, SUPER_LEDGER_KEY)
        });
        configs[2] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: _getContract(chainId, ERC5115_YIELD_SOURCE_ORACLE_KEY),
            feePercent: 0,
            feeRecipient: configuration.owner,
            ledger: _getContract(chainId, FLAT_FEE_LEDGER_KEY)
        });
        configs[3] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: _getContract(chainId, STAKING_YIELD_SOURCE_ORACLE_KEY),
            feePercent: 0,
            feeRecipient: configuration.owner,
            ledger: _getContract(chainId, SUPER_LEDGER_KEY)
        });

        bytes32[] memory salts = new bytes32[](4);
        salts[0] = bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY));
        salts[1] = bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY));
        salts[2] = bytes32(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY));
        salts[3] = bytes32(bytes(STAKING_YIELD_SOURCE_ORACLE_KEY));

        ISuperLedgerConfiguration(_getContract(chainId, SUPER_LEDGER_CONFIGURATION_KEY)).setYieldSourceOracles(
            salts, configs
        );

        console2.log("SuperLedgerConfiguration setup completed with yield source oracles");
    }
}
