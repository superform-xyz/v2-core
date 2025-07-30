// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.30;

import { DeployV2Base } from "./DeployV2Base.s.sol";
import { ConfigCore } from "./utils/ConfigCore.sol";

import { ISuperLedgerConfiguration } from "../src/interfaces/accounting/ISuperLedgerConfiguration.sol";

// -- mocks (dev environment only)
import { MockDex } from "../test/mocks/MockDex.sol";
import { MockDexHook } from "../test/mocks/MockDexHook.sol";

import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";
import { console2 } from "forge-std/console2.sol";

contract DeployV2Core is DeployV2Base, ConfigCore {
    struct CoreContracts {
        address superExecutor;
        address acrossV3Adapter;
        address debridgeAdapter;
        address superDestinationExecutor;
        address superSenderCreator;
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
        address markRootAsUsedHook;
    }

    struct HookDeployment {
        string name;
        bytes creationCode;
    }

    struct OracleDeployment {
        string name;
        bytes creationCode;
    }

    uint256 private _deployed;
    uint256 private _total;

    /// @notice Sets up complete configuration for core contracts with hook support
    /// @param env Environment (0 is prod, 1 is dev, 2 is staging)
    /// @param saltNamespace Salt namespace for deployment (if empty, uses production default)
    function _setConfiguration(uint256 env, string memory saltNamespace) internal {
        // Set base configuration (chain names, common addresses)
        _setBaseConfiguration(env, saltNamespace);

        // Set core contract dependencies
        _setCoreConfiguration();
    }

    // this is used by deploy_v2_staging_prod for env 0 and 2
    function run(bool check, uint256 env, uint64 chainId) public broadcast(env) {
        _setConfiguration(env, "");
        console2.log("V2 Core (Early Access) on chainId: ", chainId);

        if (check) {
            _checkV2CoreAddresses(chainId);
        } else {
            console2.log("Deploying V2 Core (Early Access) on chainId: ", chainId);
            // deploy core contracts
            _deployCoreContracts(chainId, env);
            // Write all exported contracts for this chain
            _writeExportedContracts(chainId);
        }
    }

    // used by tenderly vnets (constantly changing salt)
    function run(uint256 env, uint64 chainId, string memory saltNamespace) public broadcast(env) {
        _setConfiguration(env, saltNamespace);
        console2.log("V2 Core (Early Access) on chainId: ", chainId);

        console2.log("Deploying V2 Core (Early Access) on chainId: ", chainId);
        // deploy core contracts
        _deployCoreContracts(chainId, env);
        // Write all exported contracts for this chain
        _writeExportedContracts(chainId);
    }

    /// @notice Public function to configure SuperLedger after deployment (for production/staging)
    /// @dev This function reads contract addresses from output files and configures the ledger
    /// @dev Meant to be called by Fireblocks MPC wallet via separate script
    /// @param env Environment (0 = prod, 2 = staging)
    /// @param chainId Target chain ID
    function runLedgerConfigurations(uint256 env, uint64 chainId) public broadcast(env) {
        console2.log(" Configuring SuperLedger for production/staging environment...");
        console2.log("   Environment:", env == 0 ? "Production" : "Staging");
        console2.log("   Chain ID:", chainId);

        // Set configuration to get correct environment settings
        _setConfiguration(env, "");

        // Configure SuperLedger by reading contracts from output files
        _setupSuperLedgerConfiguration(chainId, true, env);

        console2.log(" SuperLedger configuration completed successfully!");
    }

    /// @notice Check V2 Core contract addresses before deployment
    /// @param chainId The target chain ID
    function _checkV2CoreAddresses(uint64 chainId) internal {
        console2.log("====== V2 Core Address Verification ======");
        console2.log("Chain ID:", chainId);
        console2.log("");

        // Reset counters
        deployed = 0;
        total = 0;

        _checkCoreContracts(chainId);

        // Log comprehensive deployment summary
        _logDeploymentSummary(chainId);

        // ===== SUMMARY =====
        console2.log("");
        console2.log("=====> On this chain we have", deployed, "contracts already deployed out of", total);
        console2.log("======================================");
    }

    /// @notice Check core contract addresses
    function _checkCoreContracts(uint64 chainId) internal {
        console2.log("=== Core Contracts ===");

        // SuperLedgerConfiguration (no constructor args)
        (, address superLedgerConfig) =
            __checkContract(SUPER_LEDGER_CONFIGURATION_KEY, __getSalt(SUPER_LEDGER_CONFIGURATION_KEY), "");

        // SuperMerkleValidator (no constructor args)
        (, address superMerkleValidator) =
            __checkContract(SUPER_MERKLE_VALIDATOR_KEY, __getSalt(SUPER_MERKLE_VALIDATOR_KEY), "");

        // SuperDestinationValidator (no constructor args)
        (, address superDestValidator) =
            __checkContract(SUPER_DESTINATION_VALIDATOR_KEY, __getSalt(SUPER_DESTINATION_VALIDATOR_KEY), "");

        // SuperExecutor (requires superLedgerConfiguration)
        address superExecutor;
        if (superLedgerConfig != address(0)) {
            (, superExecutor) =
                __checkContract(SUPER_EXECUTOR_KEY, __getSalt(SUPER_EXECUTOR_KEY), abi.encode(superLedgerConfig));
        } else {
            revert("SUPER_EXECUTOR_CHECK_FAILED_MISSING_SUPER_LEDGER_CONFIG");
        }

        // SuperDestinationExecutor (requires superLedgerConfiguration, superDestinationValidator, nexusFactory)
        address superDestExecutor;
        if (
            superLedgerConfig != address(0) && superDestValidator != address(0)
                && configuration.nexusFactories[chainId] != address(0)
        ) {
            (, superDestExecutor) = __checkContract(
                SUPER_DESTINATION_EXECUTOR_KEY,
                __getSalt(SUPER_DESTINATION_EXECUTOR_KEY),
                abi.encode(superLedgerConfig, superDestValidator, configuration.nexusFactories[chainId])
            );
        } else {
            revert("SUPER_DEST_EXECUTOR_CHECK_FAILED_MISSING_DEPENDENCIES");
        }

        // SuperSenderCreator (no constructor args)
        __checkContract(SUPER_SENDER_CREATOR_KEY, __getSalt(SUPER_SENDER_CREATOR_KEY), "");

        _checkAdapterContracts(chainId, superDestExecutor);
        _checkLedgerContracts(superLedgerConfig, superExecutor, superDestExecutor);
        _checkPaymasterContracts();
        _checkHookContracts(chainId, superMerkleValidator);
        _checkOracleContracts(superLedgerConfig);
    }

    /// @notice Check adapter contracts
    function _checkAdapterContracts(uint64 chainId, address superDestExecutor) internal {
        // AcrossV3Adapter (requires acrossSpokePoolV3 and superDestinationExecutor)
        if (configuration.acrossSpokePoolV3s[chainId] != address(0) && superDestExecutor != address(0)) {
            __checkContract(
                ACROSS_V3_ADAPTER_KEY,
                __getSalt(ACROSS_V3_ADAPTER_KEY),
                abi.encode(configuration.acrossSpokePoolV3s[chainId], superDestExecutor)
            );
        } else {
            revert("ACROSS_V3_ADAPTER_CHECK_FAILED_MISSING_DEPENDENCIES");
        }

        // DebridgeAdapter (requires debridgeDstDln and superDestinationExecutor)
        if (configuration.debridgeDstDln[chainId] != address(0) && superDestExecutor != address(0)) {
            __checkContract(
                DEBRIDGE_ADAPTER_KEY,
                __getSalt(DEBRIDGE_ADAPTER_KEY),
                abi.encode(configuration.debridgeDstDln[chainId], superDestExecutor)
            );
        } else {
            revert("DEBRIDGE_ADAPTER_CHECK_FAILED_MISSING_DEPENDENCIES");
        }
    }

    /// @notice Check ledger contracts
    function _checkLedgerContracts(
        address superLedgerConfig,
        address superExecutor,
        address superDestExecutor
    )
        internal
    {
        // Build allowedExecutors array like in deployment
        address[] memory allowedExecutors = new address[](2);
        allowedExecutors[0] = superExecutor;
        allowedExecutors[1] = superDestExecutor;

        // SuperLedger (requires superLedgerConfiguration and allowedExecutors)
        if (superLedgerConfig != address(0) && superExecutor != address(0) && superDestExecutor != address(0)) {
            __checkContract(
                SUPER_LEDGER_KEY, __getSalt(SUPER_LEDGER_KEY), abi.encode(superLedgerConfig, allowedExecutors)
            );
        } else {
            revert("SUPER_LEDGER_CHECK_FAILED_MISSING_DEPENDENCIES");
        }

        // FlatFeeLedger (requires superLedgerConfiguration and allowedExecutors)
        if (superLedgerConfig != address(0) && superExecutor != address(0) && superDestExecutor != address(0)) {
            __checkContract(
                FLAT_FEE_LEDGER_KEY, __getSalt(FLAT_FEE_LEDGER_KEY), abi.encode(superLedgerConfig, allowedExecutors)
            );
        } else {
            revert("FLAT_FEE_LEDGER_CHECK_FAILED_MISSING_DEPENDENCIES");
        }
    }

    /// @notice Check paymaster contracts
    function _checkPaymasterContracts() internal {
        // SuperNativePaymaster (requires ENTRY_POINT)
        if (ENTRY_POINT != address(0)) {
            __checkContract(SUPER_NATIVE_PAYMASTER_KEY, __getSalt(SUPER_NATIVE_PAYMASTER_KEY), abi.encode(ENTRY_POINT));
        } else {
            revert("SUPER_NATIVE_PAYMASTER_CHECK_FAILED_MISSING_ENTRY_POINT");
        }
    }

    /// @notice Check hook contracts
    function _checkHookContracts(uint64 chainId, address superMerkleValidator) internal {
        console2.log("");
        console2.log("=== Hooks ===");

        // Basic hooks without dependencies
        __checkContract(APPROVE_ERC20_HOOK_KEY, __getSalt(APPROVE_ERC20_HOOK_KEY), "");
        __checkContract(TRANSFER_ERC20_HOOK_KEY, __getSalt(TRANSFER_ERC20_HOOK_KEY), "");
        __checkContract(BATCH_TRANSFER_HOOK_KEY, __getSalt(BATCH_TRANSFER_HOOK_KEY), "");

        // BatchTransferFromHook with Permit2
        if (configuration.permit2s[chainId] != address(0)) {
            __checkContract(
                BATCH_TRANSFER_FROM_HOOK_KEY,
                __getSalt(BATCH_TRANSFER_FROM_HOOK_KEY),
                abi.encode(configuration.permit2s[chainId])
            );
        } else {
            revert("BATCH_TRANSFER_FROM_HOOK_CHECK_FAILED_MISSING_PERMIT2");
        }

        // 4626 Vault hooks
        __checkContract(DEPOSIT_4626_VAULT_HOOK_KEY, __getSalt(DEPOSIT_4626_VAULT_HOOK_KEY), "");
        __checkContract(APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY, __getSalt(APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY), "");
        __checkContract(REDEEM_4626_VAULT_HOOK_KEY, __getSalt(REDEEM_4626_VAULT_HOOK_KEY), "");

        // 5115 Vault hooks
        __checkContract(DEPOSIT_5115_VAULT_HOOK_KEY, __getSalt(DEPOSIT_5115_VAULT_HOOK_KEY), "");
        __checkContract(APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY, __getSalt(APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY), "");
        __checkContract(REDEEM_5115_VAULT_HOOK_KEY, __getSalt(REDEEM_5115_VAULT_HOOK_KEY), "");

        // 7540 Vault hooks
        __checkContract(REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY, __getSalt(REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY), "");
        __checkContract(
            APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY,
            __getSalt(APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY),
            ""
        );
        __checkContract(
            APPROVE_AND_REQUEST_REDEEM_7540_VAULT_HOOK_KEY,
            __getSalt(APPROVE_AND_REQUEST_REDEEM_7540_VAULT_HOOK_KEY),
            ""
        );
        __checkContract(REDEEM_7540_VAULT_HOOK_KEY, __getSalt(REDEEM_7540_VAULT_HOOK_KEY), "");
        __checkContract(REQUEST_REDEEM_7540_VAULT_HOOK_KEY, __getSalt(REQUEST_REDEEM_7540_VAULT_HOOK_KEY), "");
        __checkContract(DEPOSIT_7540_VAULT_HOOK_KEY, __getSalt(DEPOSIT_7540_VAULT_HOOK_KEY), "");
        __checkContract(WITHDRAW_7540_VAULT_HOOK_KEY, __getSalt(WITHDRAW_7540_VAULT_HOOK_KEY), "");
        __checkContract(CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY, __getSalt(CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY), "");
        __checkContract(CANCEL_REDEEM_REQUEST_7540_HOOK_KEY, __getSalt(CANCEL_REDEEM_REQUEST_7540_HOOK_KEY), "");
        __checkContract(
            CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY, __getSalt(CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY), ""
        );
        __checkContract(
            CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY, __getSalt(CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY), ""
        );

        // Swap hooks with router dependencies
        if (configuration.aggregationRouters[chainId] != address(0)) {
            __checkContract(
                SWAP_1INCH_HOOK_KEY,
                __getSalt(SWAP_1INCH_HOOK_KEY),
                abi.encode(configuration.aggregationRouters[chainId])
            );
        } else {
            revert("SWAP_1INCH_HOOK_CHECK_FAILED_MISSING_AGGREGATION_ROUTER");
        }

        if (configuration.odosRouters[chainId] != address(0)) {
            __checkContract(
                SWAP_ODOSV2_HOOK_KEY, __getSalt(SWAP_ODOSV2_HOOK_KEY), abi.encode(configuration.odosRouters[chainId])
            );
            __checkContract(
                APPROVE_AND_SWAP_ODOSV2_HOOK_KEY,
                __getSalt(APPROVE_AND_SWAP_ODOSV2_HOOK_KEY),
                abi.encode(configuration.odosRouters[chainId])
            );
        } else {
            revert("SWAP_ODOS_HOOKS_CHECK_FAILED_MISSING_ODOS_ROUTER");
        }

        // Bridge hooks
        if (configuration.acrossSpokePoolV3s[chainId] != address(0) && superMerkleValidator != address(0)) {
            __checkContract(
                ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY,
                __getSalt(ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY),
                abi.encode(configuration.acrossSpokePoolV3s[chainId], superMerkleValidator)
            );
        } else {
            revert("ACROSS_HOOK_CHECK_FAILED_MISSING_DEPENDENCIES");
        }

        if (DEBRIDGE_DLN_SRC != address(0) && superMerkleValidator != address(0)) {
            __checkContract(
                DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY,
                __getSalt(DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY),
                abi.encode(DEBRIDGE_DLN_SRC, superMerkleValidator)
            );
        } else {
            __checkContract(
                DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY,
                __getSalt(DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY),
                ""
            );
        }

        if (DEBRIDGE_DLN_DST != address(0)) {
            __checkContract(
                DEBRIDGE_CANCEL_ORDER_HOOK_KEY, __getSalt(DEBRIDGE_CANCEL_ORDER_HOOK_KEY), abi.encode(DEBRIDGE_DLN_DST)
            );
        } else {
            revert("DEBRIDGE_CANCEL_HOOK_CHECK_FAILED_MISSING_DLN_DST");
        }

        // Protocol-specific hooks
        __checkContract(ETHENA_COOLDOWN_SHARES_HOOK_KEY, __getSalt(ETHENA_COOLDOWN_SHARES_HOOK_KEY), "");
        __checkContract(ETHENA_UNSTAKE_HOOK_KEY, __getSalt(ETHENA_UNSTAKE_HOOK_KEY), "");
        __checkContract(CANCEL_REDEEM_HOOK_KEY, __getSalt(CANCEL_REDEEM_HOOK_KEY), "");
        __checkContract(OFFRAMP_TOKENS_HOOK_KEY, __getSalt(OFFRAMP_TOKENS_HOOK_KEY), "");
        __checkContract(MINT_SUPERPOSITIONS_HOOK_KEY, __getSalt(MINT_SUPERPOSITIONS_HOOK_KEY), "");
        __checkContract(MARK_ROOT_AS_USED_HOOK_KEY, __getSalt(MARK_ROOT_AS_USED_HOOK_KEY), "");
    }

    /// @notice Check oracle contracts
    function _checkOracleContracts(address superLedgerConfig) internal {
        console2.log("");
        console2.log("=== Oracles ===");

        // Oracles that require superLedgerConfiguration
        if (superLedgerConfig != address(0)) {
            __checkContract(
                ERC4626_YIELD_SOURCE_ORACLE_KEY,
                __getSalt(ERC4626_YIELD_SOURCE_ORACLE_KEY),
                abi.encode(superLedgerConfig)
            );
            __checkContract(
                ERC5115_YIELD_SOURCE_ORACLE_KEY,
                __getSalt(ERC5115_YIELD_SOURCE_ORACLE_KEY),
                abi.encode(superLedgerConfig)
            );
            __checkContract(
                ERC7540_YIELD_SOURCE_ORACLE_KEY,
                __getSalt(ERC7540_YIELD_SOURCE_ORACLE_KEY),
                abi.encode(superLedgerConfig)
            );
            __checkContract(
                PENDLE_PT_YIELD_SOURCE_ORACLE_KEY,
                __getSalt(PENDLE_PT_YIELD_SOURCE_ORACLE_KEY),
                abi.encode(superLedgerConfig)
            );
            __checkContract(
                SPECTRA_PT_YIELD_SOURCE_ORACLE_KEY,
                __getSalt(SPECTRA_PT_YIELD_SOURCE_ORACLE_KEY),
                abi.encode(superLedgerConfig)
            );
            __checkContract(
                STAKING_YIELD_SOURCE_ORACLE_KEY,
                __getSalt(STAKING_YIELD_SOURCE_ORACLE_KEY),
                abi.encode(superLedgerConfig)
            );
        } else {
            revert("ORACLES_CHECK_FAILED_MISSING_SUPER_LEDGER_CONFIG");
        }

        // SuperYieldSourceOracle (no constructor args)
        __checkContract(SUPER_YIELD_SOURCE_ORACLE_KEY, __getSalt(SUPER_YIELD_SOURCE_ORACLE_KEY), "");
    }

    /// @notice Populate CoreContracts struct with addresses from deployment status
    /// @param chainId Chain ID
    /// @param coreContracts CoreContracts struct to populate
    function _populateCoreContractsFromStatus(uint64 chainId, CoreContracts memory coreContracts) internal view {
        ContractStatus memory status;

        status = _getContractStatus(chainId, SUPER_EXECUTOR_KEY);
        if (status.isDeployed) coreContracts.superExecutor = status.contractAddress;

        status = _getContractStatus(chainId, ACROSS_V3_ADAPTER_KEY);
        if (status.isDeployed) coreContracts.acrossV3Adapter = status.contractAddress;

        status = _getContractStatus(chainId, DEBRIDGE_ADAPTER_KEY);
        if (status.isDeployed) coreContracts.debridgeAdapter = status.contractAddress;

        status = _getContractStatus(chainId, SUPER_DESTINATION_EXECUTOR_KEY);
        if (status.isDeployed) coreContracts.superDestinationExecutor = status.contractAddress;

        status = _getContractStatus(chainId, SUPER_SENDER_CREATOR_KEY);
        if (status.isDeployed) coreContracts.superSenderCreator = status.contractAddress;

        status = _getContractStatus(chainId, SUPER_LEDGER_KEY);
        if (status.isDeployed) coreContracts.superLedger = status.contractAddress;

        status = _getContractStatus(chainId, FLAT_FEE_LEDGER_KEY);
        if (status.isDeployed) coreContracts.flatFeeLedger = status.contractAddress;

        status = _getContractStatus(chainId, SUPER_LEDGER_CONFIGURATION_KEY);
        if (status.isDeployed) coreContracts.superLedgerConfiguration = status.contractAddress;

        status = _getContractStatus(chainId, SUPER_MERKLE_VALIDATOR_KEY);
        if (status.isDeployed) coreContracts.superMerkleValidator = status.contractAddress;

        status = _getContractStatus(chainId, SUPER_DESTINATION_VALIDATOR_KEY);
        if (status.isDeployed) coreContracts.superDestinationValidator = status.contractAddress;

        status = _getContractStatus(chainId, SUPER_NATIVE_PAYMASTER_KEY);
        if (status.isDeployed) coreContracts.superNativePaymaster = status.contractAddress;
    }

    function _deployCoreContracts(uint64 chainId, uint256 env) internal {
        CoreContracts memory coreContracts;

        // Pre-populate core contracts with existing deployed addresses
        _populateCoreContractsFromStatus(chainId, coreContracts);

        // ===== VALIDATION PHASE =====
        // Validate critical dependencies before deployment
        console2.log("Validating deployment dependencies for chain:", chainId);

        // Validate treasury and owner addresses
        require(configuration.treasury != address(0), "TREASURY_ADDRESS_ZERO");
        require(configuration.owner != address(0), "OWNER_ADDRESS_ZERO");
        console2.log(" Treasury:", configuration.treasury);
        console2.log(" Owner:", configuration.owner);

        // Check Nexus Factory (required for SuperDestinationExecutor)
        require(configuration.nexusFactories[chainId] != address(0), "NEXUS_FACTORY_ADDRESS_ZERO");
        require(configuration.nexusFactories[chainId].code.length > 0, "NEXUS_FACTORY_NOT_DEPLOYED");
        console2.log(" Nexus Factory:", configuration.nexusFactories[chainId]);

        // Check Permit2 (required for BatchTransferFromHook)
        require(configuration.permit2s[chainId] != address(0), "PERMIT2_ADDRESS_ZERO");
        require(configuration.permit2s[chainId].code.length > 0, "PERMIT2_NOT_DEPLOYED");
        console2.log(" Permit2:", configuration.permit2s[chainId]);

        // Check Across Spoke Pool (required for AcrossV3Adapter)
        require(configuration.acrossSpokePoolV3s[chainId] != address(0), "ACROSS_SPOKE_POOL_ADDRESS_ZERO");
        require(configuration.acrossSpokePoolV3s[chainId].code.length > 0, "ACROSS_SPOKE_POOL_NOT_DEPLOYED");
        console2.log(" Across Spoke Pool V3:", configuration.acrossSpokePoolV3s[chainId]);

        // Check DeBridge DLN (required for DebridgeAdapter)
        require(configuration.debridgeDstDln[chainId] != address(0), "DEBRIDGE_DLN_ADDRESS_ZERO");
        require(configuration.debridgeDstDln[chainId].code.length > 0, "DEBRIDGE_DLN_NOT_DEPLOYED");
        console2.log(" DeBridge DLN DST:", configuration.debridgeDstDln[chainId]);

        // Check critical router addresses for hooks
        require(configuration.aggregationRouters[chainId] != address(0), "AGGREGATION_ROUTER_ADDRESS_ZERO");
        require(configuration.aggregationRouters[chainId].code.length > 0, "AGGREGATION_ROUTER_NOT_DEPLOYED");
        console2.log(" 1inch Aggregation Router:", configuration.aggregationRouters[chainId]);

        require(configuration.odosRouters[chainId] != address(0), "ODOS_ROUTER_ADDRESS_ZERO");
        require(configuration.odosRouters[chainId].code.length > 0, "ODOS_ROUTER_NOT_DEPLOYED");
        console2.log(" ODOS Router:", configuration.odosRouters[chainId]);

        // Validate EntryPoint address
        require(ENTRY_POINT != address(0), "ENTRY_POINT_ADDRESS_ZERO");
        require(ENTRY_POINT.code.length > 0, "ENTRY_POINT_NOT_DEPLOYED");
        console2.log(" EntryPoint:", ENTRY_POINT);

        console2.log("All critical dependencies validated successfully");

        // ===== DEPLOYMENT PHASE =====

        // Deploy SuperLedgerConfiguration
        coreContracts.superLedgerConfiguration = __deployContractIfNeeded(
            SUPER_LEDGER_CONFIGURATION_KEY,
            chainId,
            __getSalt(SUPER_LEDGER_CONFIGURATION_KEY),
            vm.getCode("script/locked-bytecode/SuperLedgerConfiguration.json")
        );

        // Validate SuperLedgerConfiguration was deployed
        require(coreContracts.superLedgerConfiguration != address(0), "SUPER_LEDGER_CONFIGURATION_DEPLOYMENT_FAILED");
        require(coreContracts.superLedgerConfiguration.code.length > 0, "SUPER_LEDGER_CONFIGURATION_NO_CODE");
        console2.log(" SuperLedgerConfiguration deployed and validated");

        // Deploy SuperMerkleValidator
        coreContracts.superMerkleValidator = __deployContractIfNeeded(
            SUPER_MERKLE_VALIDATOR_KEY,
            chainId,
            __getSalt(SUPER_MERKLE_VALIDATOR_KEY),
            vm.getCode("script/locked-bytecode/SuperMerkleValidator.json")
        );

        // Validate SuperMerkleValidator was deployed
        require(coreContracts.superMerkleValidator != address(0), "SUPER_MERKLE_VALIDATOR_DEPLOYMENT_FAILED");
        require(coreContracts.superMerkleValidator.code.length > 0, "SUPER_MERKLE_VALIDATOR_NO_CODE");
        console2.log(" SuperMerkleValidator deployed and validated");

        // Deploy SuperDestinationValidator
        coreContracts.superDestinationValidator = __deployContractIfNeeded(
            SUPER_DESTINATION_VALIDATOR_KEY,
            chainId,
            __getSalt(SUPER_DESTINATION_VALIDATOR_KEY),
            vm.getCode("script/locked-bytecode/SuperDestinationValidator.json")
        );

        // Validate SuperDestinationValidator was deployed
        require(coreContracts.superDestinationValidator != address(0), "SUPER_DESTINATION_VALIDATOR_DEPLOYMENT_FAILED");
        require(coreContracts.superDestinationValidator.code.length > 0, "SUPER_DESTINATION_VALIDATOR_NO_CODE");
        console2.log(" SuperDestinationValidator deployed and validated");

        // Deploy SuperExecutor - VALIDATED CONSTRUCTOR PARAMETERS
        require(coreContracts.superLedgerConfiguration != address(0), "SUPER_EXECUTOR_LEDGER_CONFIG_PARAM_ZERO");
        coreContracts.superExecutor = __deployContractIfNeeded(
            SUPER_EXECUTOR_KEY,
            chainId,
            __getSalt(SUPER_EXECUTOR_KEY),
            abi.encodePacked(
                vm.getCode("script/locked-bytecode/SuperExecutor.json"),
                abi.encode(coreContracts.superLedgerConfiguration)
            )
        );

        // Validate SuperExecutor was deployed
        require(coreContracts.superExecutor != address(0), "SUPER_EXECUTOR_DEPLOYMENT_FAILED");
        require(coreContracts.superExecutor.code.length > 0, "SUPER_EXECUTOR_NO_CODE");
        console2.log(" SuperExecutor deployed and validated");

        // Deploy SuperDestinationExecutor - VALIDATED CONSTRUCTOR PARAMETERS
        require(coreContracts.superLedgerConfiguration != address(0), "SUPER_DEST_EXECUTOR_LEDGER_CONFIG_PARAM_ZERO");
        require(coreContracts.superDestinationValidator != address(0), "SUPER_DEST_EXECUTOR_VALIDATOR_PARAM_ZERO");
        require(configuration.nexusFactories[chainId] != address(0), "SUPER_DEST_EXECUTOR_NEXUS_FACTORY_PARAM_ZERO");

        coreContracts.superDestinationExecutor = __deployContractIfNeeded(
            SUPER_DESTINATION_EXECUTOR_KEY,
            chainId,
            __getSalt(SUPER_DESTINATION_EXECUTOR_KEY),
            abi.encodePacked(
                vm.getCode("script/locked-bytecode/SuperDestinationExecutor.json"),
                abi.encode(
                    coreContracts.superLedgerConfiguration,
                    coreContracts.superDestinationValidator,
                    configuration.nexusFactories[chainId]
                )
            )
        );

        // Validate SuperDestinationExecutor was deployed
        require(coreContracts.superDestinationExecutor != address(0), "SUPER_DESTINATION_EXECUTOR_DEPLOYMENT_FAILED");
        require(coreContracts.superDestinationExecutor.code.length > 0, "SUPER_DESTINATION_EXECUTOR_NO_CODE");
        console2.log(" SuperDestinationExecutor deployed and validated");

        // Deploy SuperSenderCreator
        coreContracts.superSenderCreator = __deployContractIfNeeded(
            SUPER_SENDER_CREATOR_KEY,
            chainId,
            __getSalt(SUPER_SENDER_CREATOR_KEY),
            vm.getCode("script/locked-bytecode/SuperSenderCreator.json")
        );

        // Validate SuperSenderCreator was deployed
        require(coreContracts.superSenderCreator != address(0), "SUPER_SENDER_CREATOR_DEPLOYMENT_FAILED");
        require(coreContracts.superSenderCreator.code.length > 0, "SUPER_SENDER_CREATOR_NO_CODE");
        console2.log(" SuperSenderCreator deployed and validated");

        // Deploy AcrossV3Adapter - VALIDATED CONSTRUCTOR PARAMETERS
        require(configuration.acrossSpokePoolV3s[chainId] != address(0), "ACROSS_ADAPTER_SPOKE_POOL_PARAM_ZERO");
        require(coreContracts.superDestinationExecutor != address(0), "ACROSS_ADAPTER_DEST_EXECUTOR_PARAM_ZERO");

        coreContracts.acrossV3Adapter = __deployContractIfNeeded(
            ACROSS_V3_ADAPTER_KEY,
            chainId,
            __getSalt(ACROSS_V3_ADAPTER_KEY),
            abi.encodePacked(
                vm.getCode("script/locked-bytecode/AcrossV3Adapter.json"),
                abi.encode(configuration.acrossSpokePoolV3s[chainId], coreContracts.superDestinationExecutor)
            )
        );

        // Validate AcrossV3Adapter was deployed
        require(coreContracts.acrossV3Adapter != address(0), "ACROSS_V3_ADAPTER_DEPLOYMENT_FAILED");
        require(coreContracts.acrossV3Adapter.code.length > 0, "ACROSS_V3_ADAPTER_NO_CODE");
        console2.log(" AcrossV3Adapter deployed and validated");

        // Deploy DebridgeAdapter - VALIDATED CONSTRUCTOR PARAMETERS
        require(configuration.debridgeDstDln[chainId] != address(0), "DEBRIDGE_ADAPTER_DST_DLN_PARAM_ZERO");
        require(coreContracts.superDestinationExecutor != address(0), "DEBRIDGE_ADAPTER_DEST_EXECUTOR_PARAM_ZERO");

        coreContracts.debridgeAdapter = __deployContractIfNeeded(
            DEBRIDGE_ADAPTER_KEY,
            chainId,
            __getSalt(DEBRIDGE_ADAPTER_KEY),
            abi.encodePacked(
                vm.getCode("script/locked-bytecode/DebridgeAdapter.json"),
                abi.encode(configuration.debridgeDstDln[chainId], coreContracts.superDestinationExecutor)
            )
        );

        // Validate DebridgeAdapter was deployed
        require(coreContracts.debridgeAdapter != address(0), "DEBRIDGE_ADAPTER_DEPLOYMENT_FAILED");
        require(coreContracts.debridgeAdapter.code.length > 0, "DEBRIDGE_ADAPTER_NO_CODE");
        console2.log(" DebridgeAdapter deployed and validated");

        // ===== LEDGER DEPLOYMENT WITH VALIDATED EXECUTORS =====
        address[] memory allowedExecutors = new address[](2);
        allowedExecutors[0] = address(coreContracts.superExecutor);
        allowedExecutors[1] = address(coreContracts.superDestinationExecutor);

        // Validate executor addresses before using them
        require(allowedExecutors[0] != address(0), "LEDGER_SUPER_EXECUTOR_PARAM_ZERO");
        require(allowedExecutors[1] != address(0), "LEDGER_DEST_EXECUTOR_PARAM_ZERO");
        require(allowedExecutors[0].code.length > 0, "LEDGER_SUPER_EXECUTOR_NO_CODE");
        require(allowedExecutors[1].code.length > 0, "LEDGER_DEST_EXECUTOR_NO_CODE");
        console2.log(" Validated executor addresses for ledgers:", allowedExecutors[0], allowedExecutors[1]);

        // Deploy SuperLedger - VALIDATED CONSTRUCTOR PARAMETERS
        require(coreContracts.superLedgerConfiguration != address(0), "SUPER_LEDGER_CONFIG_PARAM_ZERO");

        coreContracts.superLedger = __deployContractIfNeeded(
            SUPER_LEDGER_KEY,
            chainId,
            __getSalt(SUPER_LEDGER_KEY),
            abi.encodePacked(
                vm.getCode("script/locked-bytecode/SuperLedger.json"),
                abi.encode(coreContracts.superLedgerConfiguration, allowedExecutors)
            )
        );

        // Validate SuperLedger was deployed
        require(coreContracts.superLedger != address(0), "SUPER_LEDGER_DEPLOYMENT_FAILED");
        require(coreContracts.superLedger.code.length > 0, "SUPER_LEDGER_NO_CODE");
        console2.log(" SuperLedger deployed and validated");

        // Deploy FlatFeeLedger - VALIDATED CONSTRUCTOR PARAMETERS
        require(coreContracts.superLedgerConfiguration != address(0), "FLAT_FEE_LEDGER_CONFIG_PARAM_ZERO");

        coreContracts.flatFeeLedger = __deployContractIfNeeded(
            FLAT_FEE_LEDGER_KEY,
            chainId,
            __getSalt(FLAT_FEE_LEDGER_KEY),
            abi.encodePacked(
                vm.getCode("script/locked-bytecode/FlatFeeLedger.json"),
                abi.encode(coreContracts.superLedgerConfiguration, allowedExecutors)
            )
        );

        // Validate FlatFeeLedger was deployed
        require(coreContracts.flatFeeLedger != address(0), "FLAT_FEE_LEDGER_DEPLOYMENT_FAILED");
        require(coreContracts.flatFeeLedger.code.length > 0, "FLAT_FEE_LEDGER_NO_CODE");
        console2.log(" FlatFeeLedger deployed and validated");

        // Deploy SuperNativePaymaster - VALIDATED CONSTRUCTOR PARAMETERS
        require(ENTRY_POINT != address(0), "PAYMASTER_ENTRY_POINT_PARAM_ZERO");

        coreContracts.superNativePaymaster = __deployContractIfNeeded(
            SUPER_NATIVE_PAYMASTER_KEY,
            chainId,
            __getSalt(SUPER_NATIVE_PAYMASTER_KEY),
            abi.encodePacked(vm.getCode("script/locked-bytecode/SuperNativePaymaster.json"), abi.encode(ENTRY_POINT))
        );

        // Validate SuperNativePaymaster was deployed
        require(coreContracts.superNativePaymaster != address(0), "SUPER_NATIVE_PAYMASTER_DEPLOYMENT_FAILED");
        require(coreContracts.superNativePaymaster.code.length > 0, "SUPER_NATIVE_PAYMASTER_NO_CODE");
        console2.log(" SuperNativePaymaster deployed and validated");

        console2.log(" All core contracts deployment completed successfully with full validation ");

        // Deploy Hooks
        _deployHooks(chainId);

        // Deploy Mock Contracts (only for development environment)
        if (env == 1) {
            _deployMockContracts(chainId);
        }

        // Deploy Oracles
        _deployOracles(chainId);

        // Setup SuperLedger configuration with oracle mappings - CONDITIONAL BASED ON ENVIRONMENT
        if (env == 1) {
            // VNET environment - setup immediately during deployment using deployed contracts
            _setupSuperLedgerConfiguration(chainId, false, env);
        } else {
            // Production/Staging environments - skip setup, will be done separately via runLedgerConfigurations
            console2.log("Skipping SuperLedger configuration for production/staging environment");
            console2.log("Configuration will be done separately via runLedgerConfigurations script");
        }
    }

    /// @notice Internal function to setup SuperLedger configuration
    /// @dev Can read from deployed contracts or output files based on useFiles parameter
    /// @param chainId Target chain ID
    /// @param useFiles Whether to read contract addresses from output files (true) or deployed contracts (false)
    /// @param env Environment for determining output path (only used if useFiles is true)
    function _setupSuperLedgerConfiguration(uint64 chainId, bool useFiles, uint256 env) private {
        string memory sourceDescription = useFiles ? "output files" : "deployed contracts";
        console2.log("Setting up SuperLedgerConfiguration from", sourceDescription, "with comprehensive validation...");

        // ===== GET CONTRACT ADDRESSES BASED ON SOURCE =====
        address superLedgerConfig;
        address erc4626Oracle;
        address erc7540Oracle;
        address erc5115Oracle;
        address stakingOracle;
        address superLedger;
        address flatFeeLedger;

        if (useFiles) {
            // Read contract addresses from deployment output files
            string memory deploymentJson = _readCoreContractsFromOutput(chainId, env);

            superLedgerConfig = vm.parseJsonAddress(deploymentJson, ".SuperLedgerConfiguration");
            erc4626Oracle = vm.parseJsonAddress(deploymentJson, ".ERC4626YieldSourceOracle");
            erc7540Oracle = vm.parseJsonAddress(deploymentJson, ".ERC7540YieldSourceOracle");
            erc5115Oracle = vm.parseJsonAddress(deploymentJson, ".ERC5115YieldSourceOracle");
            stakingOracle = vm.parseJsonAddress(deploymentJson, ".StakingYieldSourceOracle");
            superLedger = vm.parseJsonAddress(deploymentJson, ".SuperLedger");
            flatFeeLedger = vm.parseJsonAddress(deploymentJson, ".FlatFeeLedger");
        } else {
            // Read contract addresses from deployed contracts registry
            superLedgerConfig = _getContract(chainId, SUPER_LEDGER_CONFIGURATION_KEY);
            erc4626Oracle = _getContract(chainId, ERC4626_YIELD_SOURCE_ORACLE_KEY);
            erc7540Oracle = _getContract(chainId, ERC7540_YIELD_SOURCE_ORACLE_KEY);
            erc5115Oracle = _getContract(chainId, ERC5115_YIELD_SOURCE_ORACLE_KEY);
            stakingOracle = _getContract(chainId, STAKING_YIELD_SOURCE_ORACLE_KEY);
            superLedger = _getContract(chainId, SUPER_LEDGER_KEY);
            flatFeeLedger = _getContract(chainId, FLAT_FEE_LEDGER_KEY);
        }

        // ===== VALIDATE ALL REQUIRED CONTRACTS =====
        require(superLedgerConfig != address(0), "SETUP_SUPER_LEDGER_CONFIG_ZERO");
        require(superLedgerConfig.code.length > 0, "SETUP_SUPER_LEDGER_CONFIG_NO_CODE");

        require(erc4626Oracle != address(0), "SETUP_ERC4626_ORACLE_ZERO");
        require(erc4626Oracle.code.length > 0, "SETUP_ERC4626_ORACLE_NO_CODE");

        require(erc7540Oracle != address(0), "SETUP_ERC7540_ORACLE_ZERO");
        require(erc7540Oracle.code.length > 0, "SETUP_ERC7540_ORACLE_NO_CODE");

        require(erc5115Oracle != address(0), "SETUP_ERC5115_ORACLE_ZERO");
        require(erc5115Oracle.code.length > 0, "SETUP_ERC5115_ORACLE_NO_CODE");

        require(stakingOracle != address(0), "SETUP_STAKING_ORACLE_ZERO");
        require(stakingOracle.code.length > 0, "SETUP_STAKING_ORACLE_NO_CODE");

        require(superLedger != address(0), "SETUP_SUPER_LEDGER_ZERO");
        require(superLedger.code.length > 0, "SETUP_SUPER_LEDGER_NO_CODE");

        require(flatFeeLedger != address(0), "SETUP_FLAT_FEE_LEDGER_ZERO");
        require(flatFeeLedger.code.length > 0, "SETUP_FLAT_FEE_LEDGER_NO_CODE");

        // Validate treasury address is set
        require(configuration.treasury != address(0), "SETUP_TREASURY_ZERO");

        console2.log(" All required contracts validated from", sourceDescription);
        console2.log("  SuperLedgerConfiguration:", superLedgerConfig);
        console2.log("  ERC4626 Oracle:", erc4626Oracle);
        console2.log("  ERC7540 Oracle:", erc7540Oracle);
        console2.log("  ERC5115 Oracle:", erc5115Oracle);
        console2.log("  Staking Oracle:", stakingOracle);
        console2.log("  SuperLedger:", superLedger);
        console2.log("  FlatFeeLedger:", flatFeeLedger);
        console2.log("  Treasury:", configuration.treasury);

        // ===== SETUP CONFIGURATIONS WITH VALIDATED PARAMETERS =====
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](4);

        // Note: Using treasury address from configuration
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: erc4626Oracle,
            feePercent: 0,
            feeRecipient: configuration.treasury,
            ledger: superLedger
        });
        configs[1] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: erc7540Oracle,
            feePercent: 0,
            feeRecipient: configuration.treasury,
            ledger: superLedger
        });
        configs[2] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: erc5115Oracle,
            feePercent: 0,
            feeRecipient: configuration.treasury,
            ledger: flatFeeLedger
        });
        configs[3] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: stakingOracle,
            feePercent: 0,
            feeRecipient: configuration.treasury,
            ledger: superLedger
        });

        // Validate each configuration before setup
        for (uint256 i = 0; i < configs.length; ++i) {
            require(configs[i].yieldSourceOracle != address(0), "CONFIG_YIELD_SOURCE_ORACLE_ZERO");
            require(configs[i].feeRecipient != address(0), "CONFIG_FEE_RECIPIENT_ZERO");
            require(configs[i].ledger != address(0), "CONFIG_LEDGER_ZERO");
            console2.log(" Configuration", i, "validated");
        }

        bytes32[] memory salts = new bytes32[](4);
        salts[0] = bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY));
        salts[1] = bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY));
        salts[2] = bytes32(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY));
        salts[3] = bytes32(bytes(STAKING_YIELD_SOURCE_ORACLE_KEY));

        // Validate salts are not empty
        for (uint256 i = 0; i < salts.length; ++i) {
            require(salts[i] != bytes32(0), "SETUP_SALT_ZERO");
        }

        console2.log(" All salts validated for yield source oracle setup");

        // Execute the configuration setup
        ISuperLedgerConfiguration(superLedgerConfig).setYieldSourceOracles(salts, configs);

        console2.log(" SuperLedgerConfiguration setup completed successfully from", sourceDescription, "! ");
    }

    /// @notice Helper function to read core contract addresses from output files
    /// @dev Similar to _readCoreContracts but for production/staging environments
    /// @param chainId Target chain ID
    /// @param env Environment (0 = prod, 2 = staging)
    /// @return JSON string containing contract addresses
    function _readCoreContractsFromOutput(uint64 chainId, uint256 env) internal view returns (string memory) {
        string memory chainName = chainNames[chainId];
        string memory root = vm.projectRoot();
        string memory envName = env == 0 ? "prod" : "staging";

        // Construct path: script/output/{env}/{chainId}/{ChainName}-latest.json
        string memory outputPath = string(
            abi.encodePacked(
                root, "/script/output/", envName, "/", vm.toString(uint256(chainId)), "/", chainName, "-latest.json"
            )
        );

        console2.log("Reading contracts from:", outputPath);

        // Check if file exists and read it
        if (!vm.exists(outputPath)) {
            revert(string(abi.encodePacked("CONTRACT_FILE_NOT_FOUND: ", outputPath)));
        }

        return vm.readFile(outputPath);
    }

    function _deployHooks(uint64 chainId) private returns (HookAddresses memory hookAddresses) {
        console2.log("Starting hook deployment with comprehensive dependency validation...");

        uint256 len = 33;
        HookDeployment[] memory hooks = new HookDeployment[](len);
        address[] memory addresses = new address[](len);

        // ===== HOOKS WITHOUT DEPENDENCIES =====
        hooks[0] = HookDeployment(APPROVE_ERC20_HOOK_KEY, vm.getCode("script/locked-bytecode/ApproveERC20Hook.json"));
        hooks[1] = HookDeployment(TRANSFER_ERC20_HOOK_KEY, vm.getCode("script/locked-bytecode/TransferERC20Hook.json"));
        hooks[2] = HookDeployment(BATCH_TRANSFER_HOOK_KEY, vm.getCode("script/locked-bytecode/BatchTransferHook.json"));

        // ===== HOOKS WITH VALIDATED DEPENDENCIES =====

        // BatchTransferFromHook - Requires Permit2 (already validated in core deployment)
        require(configuration.permit2s[chainId] != address(0), "BATCH_TRANSFER_FROM_HOOK_PERMIT2_PARAM_ZERO");
        require(configuration.permit2s[chainId].code.length > 0, "BATCH_TRANSFER_FROM_HOOK_PERMIT2_NOT_DEPLOYED");
        hooks[3] = HookDeployment(
            BATCH_TRANSFER_FROM_HOOK_KEY,
            abi.encodePacked(
                vm.getCode("script/locked-bytecode/BatchTransferFromHook.json"),
                abi.encode(configuration.permit2s[chainId])
            )
        );

        // Vault hooks (no external dependencies)
        hooks[4] =
            HookDeployment(DEPOSIT_4626_VAULT_HOOK_KEY, vm.getCode("script/locked-bytecode/Deposit4626VaultHook.json"));
        hooks[5] = HookDeployment(
            APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY,
            vm.getCode("script/locked-bytecode/ApproveAndDeposit4626VaultHook.json")
        );
        hooks[6] =
            HookDeployment(REDEEM_4626_VAULT_HOOK_KEY, vm.getCode("script/locked-bytecode/Redeem4626VaultHook.json"));
        hooks[7] =
            HookDeployment(DEPOSIT_5115_VAULT_HOOK_KEY, vm.getCode("script/locked-bytecode/Deposit5115VaultHook.json"));
        hooks[8] = HookDeployment(
            APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY,
            vm.getCode("script/locked-bytecode/ApproveAndDeposit5115VaultHook.json")
        );
        hooks[9] =
            HookDeployment(REDEEM_5115_VAULT_HOOK_KEY, vm.getCode("script/locked-bytecode/Redeem5115VaultHook.json"));
        hooks[10] = HookDeployment(
            REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY, vm.getCode("script/locked-bytecode/RequestDeposit7540VaultHook.json")
        );
        hooks[11] = HookDeployment(
            APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY,
            vm.getCode("script/locked-bytecode/ApproveAndRequestDeposit7540VaultHook.json")
        );
        hooks[12] = HookDeployment(
            APPROVE_AND_REQUEST_REDEEM_7540_VAULT_HOOK_KEY,
            vm.getCode("script/locked-bytecode/ApproveAndRequestRedeem7540VaultHook.json")
        );
        hooks[13] =
            HookDeployment(REDEEM_7540_VAULT_HOOK_KEY, vm.getCode("script/locked-bytecode/Redeem7540VaultHook.json"));
        hooks[14] = HookDeployment(
            REQUEST_REDEEM_7540_VAULT_HOOK_KEY, vm.getCode("script/locked-bytecode/RequestRedeem7540VaultHook.json")
        );
        hooks[15] =
            HookDeployment(DEPOSIT_7540_VAULT_HOOK_KEY, vm.getCode("script/locked-bytecode/Deposit7540VaultHook.json"));
        hooks[16] = HookDeployment(
            WITHDRAW_7540_VAULT_HOOK_KEY, vm.getCode("script/locked-bytecode/Withdraw7540VaultHook.json")
        );

        // ===== HOOKS WITH EXTERNAL ROUTER DEPENDENCIES =====

        // 1inch Swap Hook - Validate aggregation router (already validated in core deployment)
        require(configuration.aggregationRouters[chainId] != address(0), "SWAP_1INCH_HOOK_ROUTER_PARAM_ZERO");
        require(configuration.aggregationRouters[chainId].code.length > 0, "SWAP_1INCH_HOOK_ROUTER_NOT_DEPLOYED");
        hooks[17] = HookDeployment(
            SWAP_1INCH_HOOK_KEY,
            abi.encodePacked(
                vm.getCode("script/locked-bytecode/Swap1InchHook.json"),
                abi.encode(configuration.aggregationRouters[chainId])
            )
        );

        // ODOS Swap Hooks - Validate ODOS router (already validated in core deployment)
        require(configuration.odosRouters[chainId] != address(0), "SWAP_ODOS_HOOK_ROUTER_PARAM_ZERO");
        require(configuration.odosRouters[chainId].code.length > 0, "SWAP_ODOS_HOOK_ROUTER_NOT_DEPLOYED");
        hooks[18] = HookDeployment(
            SWAP_ODOSV2_HOOK_KEY,
            abi.encodePacked(
                vm.getCode("script/locked-bytecode/SwapOdosV2Hook.json"), abi.encode(configuration.odosRouters[chainId])
            )
        );
        hooks[19] = HookDeployment(
            APPROVE_AND_SWAP_ODOSV2_HOOK_KEY,
            abi.encodePacked(
                vm.getCode("script/locked-bytecode/ApproveAndSwapOdosV2Hook.json"),
                abi.encode(configuration.odosRouters[chainId])
            )
        );

        // Across Bridge Hook - Validate Across Spoke Pool and Merkle Validator
        require(configuration.acrossSpokePoolV3s[chainId] != address(0), "ACROSS_HOOK_SPOKE_POOL_PARAM_ZERO");
        require(configuration.acrossSpokePoolV3s[chainId].code.length > 0, "ACROSS_HOOK_SPOKE_POOL_NOT_DEPLOYED");

        address superMerkleValidator = _getContract(chainId, SUPER_MERKLE_VALIDATOR_KEY);
        require(superMerkleValidator != address(0), "ACROSS_HOOK_MERKLE_VALIDATOR_PARAM_ZERO");
        require(superMerkleValidator.code.length > 0, "ACROSS_HOOK_MERKLE_VALIDATOR_NOT_DEPLOYED");

        hooks[20] = HookDeployment(
            ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY,
            abi.encodePacked(
                vm.getCode("script/locked-bytecode/AcrossSendFundsAndExecuteOnDstHook.json"),
                abi.encode(configuration.acrossSpokePoolV3s[chainId], superMerkleValidator)
            )
        );

        // DeBridge hooks - Validate constants and Merkle Validator
        require(DEBRIDGE_DLN_SRC != address(0), "DEBRIDGE_SEND_HOOK_DLN_SRC_PARAM_ZERO");
        require(DEBRIDGE_DLN_DST != address(0), "DEBRIDGE_CANCEL_HOOK_DLN_DST_PARAM_ZERO");
        require(superMerkleValidator != address(0), "DEBRIDGE_SEND_HOOK_MERKLE_VALIDATOR_PARAM_ZERO");

        hooks[21] = HookDeployment(
            DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY,
            abi.encodePacked(
                vm.getCode("script/locked-bytecode/DeBridgeSendOrderAndExecuteOnDstHook.json"),
                abi.encode(DEBRIDGE_DLN_SRC, superMerkleValidator)
            )
        );
        hooks[22] = HookDeployment(
            DEBRIDGE_CANCEL_ORDER_HOOK_KEY,
            abi.encodePacked(
                vm.getCode("script/locked-bytecode/DeBridgeCancelOrderHook.json"), abi.encode(DEBRIDGE_DLN_DST)
            )
        );

        // Protocol-specific hooks (no external dependencies)
        hooks[23] = HookDeployment(
            ETHENA_COOLDOWN_SHARES_HOOK_KEY, vm.getCode("script/locked-bytecode/EthenaCooldownSharesHook.json")
        );
        hooks[24] = HookDeployment(ETHENA_UNSTAKE_HOOK_KEY, vm.getCode("script/locked-bytecode/EthenaUnstakeHook.json"));
        hooks[25] = HookDeployment(
            CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY, vm.getCode("script/locked-bytecode/CancelDepositRequest7540Hook.json")
        );
        hooks[26] = HookDeployment(
            CANCEL_REDEEM_REQUEST_7540_HOOK_KEY, vm.getCode("script/locked-bytecode/CancelRedeemRequest7540Hook.json")
        );
        hooks[27] = HookDeployment(
            CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY,
            vm.getCode("script/locked-bytecode/ClaimCancelDepositRequest7540Hook.json")
        );
        hooks[28] = HookDeployment(
            CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY,
            vm.getCode("script/locked-bytecode/ClaimCancelRedeemRequest7540Hook.json")
        );
        hooks[29] = HookDeployment(CANCEL_REDEEM_HOOK_KEY, vm.getCode("script/locked-bytecode/CancelRedeemHook.json"));
        hooks[30] = HookDeployment(OFFRAMP_TOKENS_HOOK_KEY, vm.getCode("script/locked-bytecode/OfframpTokensHook.json"));
        hooks[31] = HookDeployment(
            MINT_SUPERPOSITIONS_HOOK_KEY, vm.getCode("script/locked-bytecode/MintSuperPositionsHook.json")
        );
        hooks[32] =
            HookDeployment(MARK_ROOT_AS_USED_HOOK_KEY, vm.getCode("script/locked-bytecode/MarkRootAsUsedHook.json"));

        // ===== DEPLOY ALL HOOKS WITH VALIDATION =====
        console2.log("Deploying", len, "hooks with parameter validation...");
        for (uint256 i = 0; i < len; ++i) {
            HookDeployment memory hook = hooks[i];
            console2.log("Deploying hook:", hook.name);

            addresses[i] = __deployContractIfNeeded(hook.name, chainId, __getSalt(hook.name), hook.creationCode);

            // Validate each hook was deployed successfully
            require(addresses[i] != address(0), string(abi.encodePacked("HOOK_DEPLOYMENT_FAILED_", hook.name)));
            require(addresses[i].code.length > 0, string(abi.encodePacked("HOOK_NO_CODE_", hook.name)));
            console2.log(" Hook deployed and validated:", hook.name, "at", addresses[i]);
        }

        // Assign hook addresses with validation
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
        hookAddresses.markRootAsUsedHook =
            Strings.equal(hooks[32].name, MARK_ROOT_AS_USED_HOOK_KEY) ? addresses[32] : address(0);

        // ===== FINAL VALIDATION OF ALL CRITICAL HOOKS =====
        require(hookAddresses.approveErc20Hook != address(0), "APPROVE_ERC20_HOOK_NOT_ASSIGNED");
        require(hookAddresses.transferErc20Hook != address(0), "TRANSFER_ERC20_HOOK_NOT_ASSIGNED");
        require(hookAddresses.batchTransferHook != address(0), "BATCH_TRANSFER_HOOK_NOT_ASSIGNED");
        require(hookAddresses.batchTransferFromHook != address(0), "BATCH_TRANSFER_FROM_HOOK_NOT_ASSIGNED");
        require(hookAddresses.deposit4626VaultHook != address(0), "DEPOSIT_4626_VAULT_HOOK_NOT_ASSIGNED");
        require(
            hookAddresses.approveAndDeposit4626VaultHook != address(0),
            "APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_NOT_ASSIGNED"
        );
        require(hookAddresses.redeem4626VaultHook != address(0), "REDEEM_4626_VAULT_HOOK_NOT_ASSIGNED");
        require(hookAddresses.deposit5115VaultHook != address(0), "DEPOSIT_5115_VAULT_HOOK_NOT_ASSIGNED");
        require(
            hookAddresses.approveAndDeposit5115VaultHook != address(0),
            "APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_NOT_ASSIGNED"
        );
        require(hookAddresses.redeem5115VaultHook != address(0), "REDEEM_5115_VAULT_HOOK_NOT_ASSIGNED");
        require(hookAddresses.redeem7540VaultHook != address(0), "REDEEM_7540_VAULT_HOOK_NOT_ASSIGNED");
        require(hookAddresses.requestDeposit7540VaultHook != address(0), "REQUEST_DEPOSIT_7540_VAULT_HOOK_NOT_ASSIGNED");
        require(
            hookAddresses.approveAndRequestDeposit7540VaultHook != address(0),
            "APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_NOT_ASSIGNED"
        );
        require(hookAddresses.requestRedeem7540VaultHook != address(0), "REQUEST_REDEEM_7540_VAULT_HOOK_NOT_ASSIGNED");
        require(hookAddresses.deposit7540VaultHook != address(0), "DEPOSIT_7540_VAULT_HOOK_NOT_ASSIGNED");
        require(hookAddresses.withdraw7540VaultHook != address(0), "WITHDRAW_7540_VAULT_HOOK_NOT_ASSIGNED");
        require(
            hookAddresses.approveAndRequestRedeem7540VaultHook != address(0),
            "APPROVE_AND_REQUEST_REDEEM_7540_VAULT_HOOK_NOT_ASSIGNED"
        );
        require(hookAddresses.swap1InchHook != address(0), "SWAP_1INCH_HOOK_NOT_ASSIGNED");
        require(hookAddresses.swapOdosHook != address(0), "SWAP_ODOS_HOOK_NOT_ASSIGNED");
        require(hookAddresses.approveAndSwapOdosHook != address(0), "APPROVE_AND_SWAP_ODOS_HOOK_NOT_ASSIGNED");
        require(
            hookAddresses.acrossSendFundsAndExecuteOnDstHook != address(0),
            "ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_NOT_ASSIGNED"
        );
        require(
            hookAddresses.deBridgeSendOrderAndExecuteOnDstHook != address(0),
            "DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_NOT_ASSIGNED"
        );
        require(
            hookAddresses.cancelDepositRequest7540Hook != address(0), "CANCEL_DEPOSIT_REQUEST_7540_HOOK_NOT_ASSIGNED"
        );
        require(hookAddresses.cancelRedeemRequest7540Hook != address(0), "CANCEL_REDEEM_REQUEST_7540_HOOK_NOT_ASSIGNED");
        require(
            hookAddresses.claimCancelDepositRequest7540Hook != address(0),
            "CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_NOT_ASSIGNED"
        );
        require(
            hookAddresses.claimCancelRedeemRequest7540Hook != address(0),
            "CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_NOT_ASSIGNED"
        );
        require(hookAddresses.cancelRedeemHook != address(0), "CANCEL_REDEEM_HOOK_NOT_ASSIGNED");
        require(hookAddresses.ethenaCooldownSharesHook != address(0), "ETHENA_COOLDOWN_SHARES_HOOK_NOT_ASSIGNED");
        require(hookAddresses.ethenaUnstakeHook != address(0), "ETHENA_UNSTAKE_HOOK_NOT_ASSIGNED");
        require(hookAddresses.offrampTokensHook != address(0), "OFFRAMP_TOKENS_HOOK_NOT_ASSIGNED");
        require(hookAddresses.mintSuperPositionHook != address(0), "MINT_SUPERPOSITION_HOOK_NOT_ASSIGNED");

        require(hookAddresses.markRootAsUsedHook != address(0), "MARK_ROOT_AS_USED_HOOK_NOT_ASSIGNED");

        console2.log(" All hooks deployed and validated successfully with comprehensive dependency checking! ");

        return hookAddresses;
    }

    function _deployOracles(uint64 chainId) private returns (address[] memory oracleAddresses) {
        console2.log("Starting oracle deployment with parameter validation...");

        uint256 len = 7;
        OracleDeployment[] memory oracles = new OracleDeployment[](len);
        oracleAddresses = new address[](len);

        // Validate SuperLedgerConfiguration address before using it
        address superLedgerConfig = _getContract(chainId, SUPER_LEDGER_CONFIGURATION_KEY);
        require(superLedgerConfig != address(0), "ORACLE_SUPER_LEDGER_CONFIG_PARAM_ZERO");
        require(superLedgerConfig.code.length > 0, "ORACLE_SUPER_LEDGER_CONFIG_NOT_DEPLOYED");
        console2.log(" Validated SuperLedgerConfiguration for oracles:", superLedgerConfig);

        // Deploy oracles with validated constructor parameters
        oracles[0] = OracleDeployment(
            ERC4626_YIELD_SOURCE_ORACLE_KEY,
            abi.encodePacked(
                vm.getCode("script/locked-bytecode/ERC4626YieldSourceOracle.json"), abi.encode(superLedgerConfig)
            )
        );
        oracles[1] = OracleDeployment(
            ERC5115_YIELD_SOURCE_ORACLE_KEY,
            abi.encodePacked(
                vm.getCode("script/locked-bytecode/ERC5115YieldSourceOracle.json"), abi.encode(superLedgerConfig)
            )
        );
        oracles[2] = OracleDeployment(
            ERC7540_YIELD_SOURCE_ORACLE_KEY,
            abi.encodePacked(
                vm.getCode("script/locked-bytecode/ERC7540YieldSourceOracle.json"), abi.encode(superLedgerConfig)
            )
        );
        oracles[3] = OracleDeployment(
            PENDLE_PT_YIELD_SOURCE_ORACLE_KEY,
            abi.encodePacked(
                vm.getCode("script/locked-bytecode/PendlePTYieldSourceOracle.json"), abi.encode(superLedgerConfig)
            )
        );
        oracles[4] = OracleDeployment(
            SPECTRA_PT_YIELD_SOURCE_ORACLE_KEY,
            abi.encodePacked(
                vm.getCode("script/locked-bytecode/SpectraPTYieldSourceOracle.json"), abi.encode(superLedgerConfig)
            )
        );
        oracles[5] = OracleDeployment(
            STAKING_YIELD_SOURCE_ORACLE_KEY,
            abi.encodePacked(
                vm.getCode("script/locked-bytecode/StakingYieldSourceOracle.json"), abi.encode(superLedgerConfig)
            )
        );
        oracles[6] = OracleDeployment(
            SUPER_YIELD_SOURCE_ORACLE_KEY, vm.getCode("script/locked-bytecode/SuperYieldSourceOracle.json")
        );

        console2.log("Deploying", len, "oracles with parameter validation...");
        for (uint256 i = 0; i < len; ++i) {
            OracleDeployment memory oracle = oracles[i];
            console2.log("Deploying oracle:", oracle.name);

            oracleAddresses[i] =
                __deployContractIfNeeded(oracle.name, chainId, __getSalt(oracle.name), oracle.creationCode);

            // Validate each oracle was deployed successfully
            require(
                oracleAddresses[i] != address(0), string(abi.encodePacked("ORACLE_DEPLOYMENT_FAILED_", oracle.name))
            );
            require(oracleAddresses[i].code.length > 0, string(abi.encodePacked("ORACLE_NO_CODE_", oracle.name)));
            console2.log(" Oracle deployed and validated:", oracle.name, "at", oracleAddresses[i]);
        }

        console2.log(" All oracles deployed and validated successfully! ");
        return oracleAddresses;
    }

    /// @notice Deploy mock contracts for development environment only
    /// @param chainId The target chain ID
    function _deployMockContracts(uint64 chainId) private {
        console2.log("Starting mock contracts deployment for development environment...");

        // Deploy MockDex first
        address mockDex =
            __deployContractIfNeeded(MOCK_DEX_KEY, chainId, __getSalt(MOCK_DEX_KEY), type(MockDex).creationCode);

        // Validate MockDex deployment
        require(mockDex != address(0), "MOCK_DEX_DEPLOYMENT_FAILED");
        require(mockDex.code.length > 0, "MOCK_DEX_NO_CODE");
        console2.log(" MockDex deployed and validated at:", mockDex);

        // Deploy MockDexHook with MockDex address as constructor parameter
        address mockDexHook = __deployContractIfNeeded(
            MOCK_DEX_HOOK_KEY,
            chainId,
            __getSalt(MOCK_DEX_HOOK_KEY),
            abi.encodePacked(type(MockDexHook).creationCode, abi.encode(mockDex))
        );

        // Validate MockDexHook deployment
        require(mockDexHook != address(0), "MOCK_DEX_HOOK_DEPLOYMENT_FAILED");
        require(mockDexHook.code.length > 0, "MOCK_DEX_HOOK_NO_CODE");
        console2.log(" MockDexHook deployed and validated at:", mockDexHook);

        console2.log(" All mock contracts deployed successfully for development environment! ");
    }
}
