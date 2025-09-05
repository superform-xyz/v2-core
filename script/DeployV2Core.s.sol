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
import { DeterministicDeployerLib } from "../src/vendor/nexus/DeterministicDeployerLib.sol";

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
        address superValidator;
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
        address redeem7540VaultHook;
        address requestRedeem7540VaultHook;
        address acrossSendFundsAndExecuteOnDstHook;
        address swap1InchHook;
        address swapOdosHook;
        address approveAndSwapOdosHook;
        address cancelDepositRequest7540Hook;
        address cancelRedeemRequest7540Hook;
        address claimCancelDepositRequest7540Hook;
        address claimCancelRedeemRequest7540Hook;
        address deBridgeSendOrderAndExecuteOnDstHook;
        address deBridgeCancelOrderHook;
        address ethenaCooldownSharesHook;
        address ethenaUnstakeHook;
        address markRootAsUsedHook;
        address merklClaimRewardHook;
        address circleGatewayWalletHook;
        address circleGatewayMinterHook;
        address circleGatewayAddDelegateHook;
        address circleGatewayRemoveDelegateHook;
    }

    struct HookDeployment {
        string name;
        bytes creationCode;
    }

    struct OracleDeployment {
        string name;
        bytes creationCode;
    }

    struct ContractVerification {
        string name;
        string outputKey;
        string bytecodePath;
        string constructorArgs;
    }

    struct ContractAvailability {
        bool acrossV3Adapter;
        bool debridgeAdapter;
        bool deBridgeSendOrderHook;
        bool deBridgeCancelOrderHook;
        bool swap1InchHook;
        bool swapOdosHooks;
        bool merklClaimRewardHook;
        uint256 expectedAdapters;
        uint256 expectedHooks;
        uint256 expectedTotal;
        string[] skippedContracts;
    }

    uint256 private _deployed;
    uint256 private _total;

    /// @notice Sets up complete configuration for core contracts with hook support
    /// @param env_ Environment (0 is prod, 1 is dev, 2 is staging)
    /// @param saltNamespace_ Salt namespace for deployment (if empty, uses production default)
    function _setConfiguration(uint256 env_, string memory saltNamespace_) internal {
        // Set base configuration (chain names, common addresses)
        _setBaseConfiguration(env_, saltNamespace_);

        // Set core contract dependencies
        _setCoreConfiguration();
    }

    /// @notice Determines which contracts are available for deployment on a specific chain
    /// @param chainId The target chain ID
    /// @return availability ContractAvailability struct with availability flags and expected counts
    function _getContractAvailability(uint64 chainId)
        internal
        view
        returns (ContractAvailability memory availability)
    {
        // Initialize all skipped contracts array
        string[] memory potentialSkips = new string[](8);
        uint256 skipCount = 0;

        // Core contracts (always expected): 10 contracts
        // SuperLedgerConfiguration, SuperValidator, SuperDestinationValidator, SuperExecutor,
        // SuperDestinationExecutor, SuperSenderCreator, SuperLedger, FlatFeeLedger, SuperNativePaymaster
        uint256 expectedCore = 10;

        // Check Adapter availability
        uint256 expectedAdapters = 0;

        // AcrossV3Adapter
        if (configuration.acrossSpokePoolV3s[chainId] != address(0)) {
            availability.acrossV3Adapter = true;
            expectedAdapters++;
        } else {
            potentialSkips[skipCount++] = "AcrossV3Adapter";
        }

        // DebridgeAdapter
        if (configuration.debridgeDstDln[chainId] != address(0)) {
            availability.debridgeAdapter = true;
            expectedAdapters++;
        } else {
            potentialSkips[skipCount++] = "DebridgeAdapter";
        }

        availability.expectedAdapters = expectedAdapters;

        // Check Hook availability
        uint256 expectedHooks = 26; // Base hooks without external dependencies (excluding Across hook)

        // Hooks that depend on external configurations
        if (configuration.acrossSpokePoolV3s[chainId] != address(0)) {
            expectedHooks += 1; // AcrossSendFundsAndExecuteOnDstHook
        } else {
            potentialSkips[skipCount++] = "AcrossSendFundsAndExecuteOnDstHook";
        }

        if (configuration.aggregationRouters[chainId] != address(0)) {
            availability.swap1InchHook = true;
            expectedHooks += 1; // Swap1InchHook
        } else {
            potentialSkips[skipCount++] = "Swap1InchHook";
        }

        if (configuration.odosRouters[chainId] != address(0)) {
            availability.swapOdosHooks = true;
            expectedHooks += 2; // SwapOdosV2Hook + ApproveAndSwapOdosV2Hook
        } else {
            potentialSkips[skipCount++] = "SwapOdosV2Hook";
            potentialSkips[skipCount++] = "ApproveAndSwapOdosV2Hook";
        }

        if (configuration.debridgeSrcDln[chainId] != address(0)) {
            availability.deBridgeSendOrderHook = true;
            expectedHooks += 1; // DeBridgeSendOrderAndExecuteOnDstHook
        } else {
            potentialSkips[skipCount++] = "DeBridgeSendOrderAndExecuteOnDstHook";
        }

        if (configuration.debridgeDstDln[chainId] != address(0)) {
            availability.deBridgeCancelOrderHook = true;
            expectedHooks += 1; // DeBridgeCancelOrderHook
        } else {
            potentialSkips[skipCount++] = "DeBridgeCancelOrderHook";
        }

        if (configuration.merklDistributors[chainId] != address(0)) {
            availability.merklClaimRewardHook = true;
            expectedHooks += 1; // MerklClaimRewardHook
        } else {
            potentialSkips[skipCount++] = "MerklClaimRewardHook";
        }

        availability.expectedHooks = expectedHooks;

        // Oracles (always expected): 7 contracts
        uint256 expectedOracles = 7;

        // Total expected contracts
        availability.expectedTotal = expectedCore + expectedAdapters + expectedHooks + expectedOracles;

        // Create properly sized skipped contracts array
        availability.skippedContracts = new string[](skipCount);
        for (uint256 i = 0; i < skipCount; i++) {
            availability.skippedContracts[i] = potentialSkips[i];
        }

        return availability;
    }

    // this is used by deploy_v2_staging_prod for env 0 and 2
    function run(bool check, uint256 env, uint64 chainId) public broadcast(env) {
        _setConfiguration(env, "");
        console2.log("V2 Core (Early Access) on chainId: ", chainId);

        if (check) {
            _checkV2CoreAddresses(chainId, env);
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

    // used by tenderly vnets for checking contracts with salt namespace (for env 1)
    // this function allows checking contract deployment status on VNETs with custom salt
    function run(bool check, uint256 env, uint64 chainId, string memory saltNamespace) public broadcast(env) {
        _setConfiguration(env, saltNamespace);
        console2.log("V2 Core (Early Access) on chainId: ", chainId);

        if (check) {
            _checkV2CoreAddresses(chainId, env);
        } else {
            console2.log("Deploying V2 Core (Early Access) on chainId: ", chainId);
            // deploy core contracts
            _deployCoreContracts(chainId, env);
            // Write all exported contracts for this chain
            _writeExportedContracts(chainId);
        }
    }

    /// @notice Public function to configure SuperLedger after deployment (for production/staging)
    /// @dev This function reads contract addresses from output files and configures the ledger
    /// @dev Meant to be called by Fireblocks MPC wallet via separate script
    /// @param env Environment (0 = prod, 2 = staging)
    /// @param chainId Target chain ID
    function runLedgerConfigurations(uint256 env, uint64 chainId) public {
        runLedgerConfigurations(env, chainId, "");
    }

    /// @notice Public function to configure SuperLedger after deployment with salt namespace
    /// @dev This function reads contract addresses from output files and configures the ledger
    /// @dev Meant to be called by Fireblocks MPC wallet via separate script
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainId Target chain ID
    /// @param saltNamespace Salt namespace for configuration
    function runLedgerConfigurations(uint256 env, uint64 chainId, string memory saltNamespace) public {
        runLedgerConfigurations(env, chainId, saltNamespace, "");
    }

    /// @notice Public function to configure SuperLedger after deployment with salt namespace and branch name
    /// @dev This function reads contract addresses from output files and configures the ledger
    /// @dev Meant to be called by Fireblocks MPC wallet via separate script
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainId Target chain ID
    /// @param saltNamespace Salt namespace for configuration
    /// @param branchName Branch name for env=1 (VNET) to read contracts from specific branch folder
    function runLedgerConfigurations(
        uint256 env,
        uint64 chainId,
        string memory saltNamespace,
        string memory branchName
    )
        public
        broadcast(env)
    {
        console2.log("====== FOOLPROOF LEDGER CONFIGURATION ======");
        console2.log("Environment:", env == 0 ? "Production" : (env == 1 ? "VNET" : "Staging"));
        console2.log("Chain ID:", chainId);
        console2.log("Salt Namespace:", saltNamespace);
        if (env == 1 && bytes(branchName).length > 0) {
            console2.log("Branch Name:", branchName);
        }
        console2.log("");

        // Set configuration to get correct environment settings
        _setConfiguration(env, saltNamespace);

        // Configure SuperLedger with bytecode verification
        _setupSuperLedgerConfiguration(chainId, env, branchName);

        console2.log("====== LEDGER CONFIGURATION COMPLETED SUCCESSFULLY ======");
    }

    /// @notice Check V2 Core contract addresses before deployment
    /// @param chainId The target chain ID
    /// @param env Environment (1 = vnet/dev, 0/2 = prod/staging)
    function _checkV2CoreAddresses(uint64 chainId, uint256 env) internal {
        console2.log("====== V2 Core Address Verification ======");
        console2.log("Chain ID:", chainId);
        console2.log("Environment:", env);
        console2.log("");

        // Get contract availability for this chain
        ContractAvailability memory availability = _getContractAvailability(chainId);

        // Log availability analysis
        console2.log("=== Contract Availability Analysis ===");
        console2.log("Expected total contracts:", availability.expectedTotal);
        console2.log("  Core contracts: 10");
        console2.log("  Adapters:", availability.expectedAdapters);
        console2.log("  Hooks:", availability.expectedHooks);
        console2.log("  Oracles: 7");

        if (availability.skippedContracts.length > 0) {
            console2.log("");
            console2.log("=== Contracts SKIPPED due to missing configurations ===");
            for (uint256 i = 0; i < availability.skippedContracts.length; i++) {
                console2.log("  SKIPPED:", availability.skippedContracts[i]);
            }
        }
        console2.log("");

        // Reset counters
        deployed = 0;
        total = 0;

        _checkCoreContracts(chainId, env, availability);

        // Override total with the correct expected count for this chain
        total = availability.expectedTotal;

        // Log comprehensive deployment summary
        _logDeploymentSummary(chainId);

        // ===== SUMMARY =====
        console2.log("");
        console2.log("=====> On this chain we have", deployed, "contracts already deployed out of", total);
        console2.log("======================================");
    }

    /// @notice Check core contract addresses
    /// @param chainId The target chain ID
    /// @param env Environment (1 = vnet/dev, 0/2 = prod/staging)
    /// @param availability Contract availability for this chain
    function _checkCoreContracts(uint64 chainId, uint256 env, ContractAvailability memory availability) internal {
        console2.log("=== Core Contracts ===");

        // SuperLedgerConfiguration (no constructor args)
        (, address superLedgerConfig) =
            __checkContract(SUPER_LEDGER_CONFIGURATION_KEY, __getSalt(SUPER_LEDGER_CONFIGURATION_KEY), "", env);

        // SuperValidator (no constructor args)
        (, address superValidator) = __checkContract(SUPER_VALIDATOR_KEY, __getSalt(SUPER_VALIDATOR_KEY), "", env);

        // SuperDestinationValidator (no constructor args)
        (, address superDestValidator) =
            __checkContract(SUPER_DESTINATION_VALIDATOR_KEY, __getSalt(SUPER_DESTINATION_VALIDATOR_KEY), "", env);

        // SuperExecutor (requires superLedgerConfiguration)
        address superExecutor;
        if (superLedgerConfig != address(0)) {
            (, superExecutor) =
                __checkContract(SUPER_EXECUTOR_KEY, __getSalt(SUPER_EXECUTOR_KEY), abi.encode(superLedgerConfig), env);
        } else {
            revert("SUPER_EXECUTOR_CHECK_FAILED_MISSING_SUPER_LEDGER_CONFIG");
        }

        // SuperDestinationExecutor (requires superLedgerConfiguration, superDestinationValidator, nexusFactory)
        address superDestExecutor;
        if (superLedgerConfig != address(0) && superDestValidator != address(0)) {
            (, superDestExecutor) = __checkContract(
                SUPER_DESTINATION_EXECUTOR_KEY,
                __getSalt(SUPER_DESTINATION_EXECUTOR_KEY),
                abi.encode(superLedgerConfig, superDestValidator),
                env
            );
        } else {
            revert("SUPER_DEST_EXECUTOR_CHECK_FAILED_MISSING_DEPENDENCIES");
        }

        // SuperSenderCreator (no constructor args)
        __checkContract(SUPER_SENDER_CREATOR_KEY, __getSalt(SUPER_SENDER_CREATOR_KEY), "", env);

        _checkAdapterContracts(chainId, superDestExecutor, env, availability);
        _checkLedgerContracts(superLedgerConfig, superExecutor, superDestExecutor, env);
        _checkPaymasterContracts(env);
        _checkHookContracts(chainId, superValidator, env, availability);
        _checkOracleContracts(superLedgerConfig, env);
    }

    /// @notice Check adapter contracts
    /// @param chainId The target chain ID
    /// @param superDestExecutor Address of the SuperDestinationExecutor
    /// @param env Environment (1 = vnet/dev, 0/2 = prod/staging)
    /// @param availability Contract availability for this chain
    function _checkAdapterContracts(
        uint64 chainId,
        address superDestExecutor,
        uint256 env,
        ContractAvailability memory availability
    )
        internal
    {
        console2.log("");
        console2.log("=== Adapters ===");

        // AcrossV3Adapter (requires acrossSpokePoolV3 and superDestinationExecutor)
        if (availability.acrossV3Adapter && superDestExecutor != address(0)) {
            __checkContract(
                ACROSS_V3_ADAPTER_KEY,
                __getSalt(ACROSS_V3_ADAPTER_KEY),
                abi.encode(configuration.acrossSpokePoolV3s[chainId], superDestExecutor),
                env
            );
        } else if (!availability.acrossV3Adapter) {
            console2.log("SKIPPED AcrossV3Adapter: Across Spoke Pool not configured for chain", chainId);
        } else {
            revert("ACROSS_V3_ADAPTER_CHECK_FAILED_MISSING_SUPER_DEST_EXECUTOR");
        }

        // DebridgeAdapter (requires debridgeDstDln and superDestinationExecutor)
        if (availability.debridgeAdapter && superDestExecutor != address(0)) {
            __checkContract(
                DEBRIDGE_ADAPTER_KEY,
                __getSalt(DEBRIDGE_ADAPTER_KEY),
                abi.encode(configuration.debridgeDstDln[chainId], superDestExecutor),
                env
            );
        } else if (!availability.debridgeAdapter) {
            console2.log("SKIPPED DebridgeAdapter: DeBridge DLN not configured for chain", chainId);
        } else {
            revert("DEBRIDGE_ADAPTER_CHECK_FAILED_MISSING_SUPER_DEST_EXECUTOR");
        }
    }

    /// @notice Check ledger contracts
    /// @param superLedgerConfig Address of the SuperLedgerConfiguration
    /// @param superExecutor Address of the SuperExecutor
    /// @param superDestExecutor Address of the SuperDestinationExecutor
    /// @param env Environment (1 = vnet/dev, 0/2 = prod/staging)
    function _checkLedgerContracts(
        address superLedgerConfig,
        address superExecutor,
        address superDestExecutor,
        uint256 env
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
                SUPER_LEDGER_KEY, __getSalt(SUPER_LEDGER_KEY), abi.encode(superLedgerConfig, allowedExecutors), env
            );
        } else {
            revert("SUPER_LEDGER_CHECK_FAILED_MISSING_DEPENDENCIES");
        }

        // FlatFeeLedger (requires superLedgerConfiguration and allowedExecutors)
        if (superLedgerConfig != address(0) && superExecutor != address(0) && superDestExecutor != address(0)) {
            __checkContract(
                FLAT_FEE_LEDGER_KEY,
                __getSalt(FLAT_FEE_LEDGER_KEY),
                abi.encode(superLedgerConfig, allowedExecutors),
                env
            );
        } else {
            revert("FLAT_FEE_LEDGER_CHECK_FAILED_MISSING_DEPENDENCIES");
        }
    }

    /// @notice Check paymaster contracts
    /// @param env Environment (1 = vnet/dev, 0/2 = prod/staging)
    function _checkPaymasterContracts(uint256 env) internal {
        // SuperNativePaymaster (requires ENTRY_POINT)
        if (ENTRY_POINT != address(0)) {
            __checkContract(
                SUPER_NATIVE_PAYMASTER_KEY, __getSalt(SUPER_NATIVE_PAYMASTER_KEY), abi.encode(ENTRY_POINT), env
            );
        } else {
            revert("SUPER_NATIVE_PAYMASTER_CHECK_FAILED_MISSING_ENTRY_POINT");
        }
    }

    /// @notice Check hook contracts
    /// @param chainId The target chain ID
    /// @param superValidator Address of the SuperValidator
    /// @param env Environment (1 = vnet/dev, 0/2 = prod/staging)
    /// @param availability Contract availability for this chain
    function _checkHookContracts(
        uint64 chainId,
        address superValidator,
        uint256 env,
        ContractAvailability memory availability
    )
        internal
    {
        console2.log("");
        console2.log("=== Hooks ===");

        // Basic hooks without dependencies
        __checkContract(APPROVE_ERC20_HOOK_KEY, __getSalt(APPROVE_ERC20_HOOK_KEY), "", env);
        __checkContract(TRANSFER_ERC20_HOOK_KEY, __getSalt(TRANSFER_ERC20_HOOK_KEY), "", env);
        __checkContract(
            BATCH_TRANSFER_HOOK_KEY,
            __getSalt(BATCH_TRANSFER_HOOK_KEY),
            abi.encode(configuration.nativeTokens[chainId]),
            env
        );

        // BatchTransferFromHook with Permit2
        if (configuration.permit2s[chainId] != address(0)) {
            __checkContract(
                BATCH_TRANSFER_FROM_HOOK_KEY,
                __getSalt(BATCH_TRANSFER_FROM_HOOK_KEY),
                abi.encode(configuration.permit2s[chainId]),
                env
            );
        } else {
            revert("BATCH_TRANSFER_FROM_HOOK_CHECK_FAILED_MISSING_PERMIT2");
        }

        // 4626 Vault hooks
        __checkContract(DEPOSIT_4626_VAULT_HOOK_KEY, __getSalt(DEPOSIT_4626_VAULT_HOOK_KEY), "", env);
        __checkContract(
            APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY, __getSalt(APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY), "", env
        );
        __checkContract(REDEEM_4626_VAULT_HOOK_KEY, __getSalt(REDEEM_4626_VAULT_HOOK_KEY), "", env);

        // 5115 Vault hooks
        __checkContract(DEPOSIT_5115_VAULT_HOOK_KEY, __getSalt(DEPOSIT_5115_VAULT_HOOK_KEY), "", env);
        __checkContract(
            APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY, __getSalt(APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY), "", env
        );
        __checkContract(REDEEM_5115_VAULT_HOOK_KEY, __getSalt(REDEEM_5115_VAULT_HOOK_KEY), "", env);

        // 7540 Vault hooks
        __checkContract(REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY, __getSalt(REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY), "", env);
        __checkContract(
            APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY,
            __getSalt(APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY),
            "",
            env
        );
        __checkContract(REDEEM_7540_VAULT_HOOK_KEY, __getSalt(REDEEM_7540_VAULT_HOOK_KEY), "", env);
        __checkContract(REQUEST_REDEEM_7540_VAULT_HOOK_KEY, __getSalt(REQUEST_REDEEM_7540_VAULT_HOOK_KEY), "", env);
        __checkContract(DEPOSIT_7540_VAULT_HOOK_KEY, __getSalt(DEPOSIT_7540_VAULT_HOOK_KEY), "", env);
        __checkContract(CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY, __getSalt(CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY), "", env);
        __checkContract(CANCEL_REDEEM_REQUEST_7540_HOOK_KEY, __getSalt(CANCEL_REDEEM_REQUEST_7540_HOOK_KEY), "", env);
        __checkContract(
            CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY, __getSalt(CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY), "", env
        );
        __checkContract(
            CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY, __getSalt(CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY), "", env
        );

        // Swap hooks with router dependencies
        if (availability.swap1InchHook) {
            __checkContract(
                SWAP_1INCH_HOOK_KEY,
                __getSalt(SWAP_1INCH_HOOK_KEY),
                abi.encode(configuration.aggregationRouters[chainId]),
                env
            );
        } else {
            console2.log("SKIPPED Swap1InchHook: 1inch Aggregation Router not configured for chain", chainId);
        }

        if (availability.swapOdosHooks) {
            __checkContract(
                SWAP_ODOSV2_HOOK_KEY,
                __getSalt(SWAP_ODOSV2_HOOK_KEY),
                abi.encode(configuration.odosRouters[chainId]),
                env
            );
            __checkContract(
                APPROVE_AND_SWAP_ODOSV2_HOOK_KEY,
                __getSalt(APPROVE_AND_SWAP_ODOSV2_HOOK_KEY),
                abi.encode(configuration.odosRouters[chainId]),
                env
            );
        } else {
            console2.log(
                "SKIPPED SwapOdosV2Hook & ApproveAndSwapOdosV2Hook: ODOS Router not configured for chain", chainId
            );
        }

        // Bridge hooks
        if (availability.acrossV3Adapter && superValidator != address(0)) {
            __checkContract(
                ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY,
                __getSalt(ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY),
                abi.encode(configuration.acrossSpokePoolV3s[chainId], superValidator),
                env
            );
        } else if (!availability.acrossV3Adapter) {
            console2.log(
                "SKIPPED AcrossSendFundsAndExecuteOnDstHook: Across Spoke Pool not configured for chain", chainId
            );
        } else {
            revert("ACROSS_HOOK_CHECK_FAILED_MISSING_SUPER_VALIDATOR");
        }

        if (availability.deBridgeSendOrderHook && superValidator != address(0)) {
            __checkContract(
                DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY,
                __getSalt(DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY),
                abi.encode(configuration.debridgeSrcDln[chainId], superValidator),
                env
            );
        } else if (!availability.deBridgeSendOrderHook) {
            console2.log("SKIPPED DeBridgeSendOrderAndExecuteOnDstHook: DeBridge DLN SRC not configured");
        } else {
            revert("DEBRIDGE_SEND_HOOK_CHECK_FAILED_MISSING_SUPER_VALIDATOR");
        }

        if (availability.deBridgeCancelOrderHook) {
            __checkContract(
                DEBRIDGE_CANCEL_ORDER_HOOK_KEY,
                __getSalt(DEBRIDGE_CANCEL_ORDER_HOOK_KEY),
                abi.encode(configuration.debridgeDstDln[chainId]),
                env
            );
        } else {
            console2.log("SKIPPED DeBridgeCancelOrderHook: DeBridge DLN DST not configured");
        }

        // Merkl claim reward hook
        if (availability.merklClaimRewardHook) {
            __checkContract(
                MERKL_CLAIM_REWARD_HOOK_KEY,
                __getSalt(MERKL_CLAIM_REWARD_HOOK_KEY),
                abi.encode(
                    configuration.merklDistributors[chainId],
                    configuration.treasury,
                    MERKLE_CLAIM_REWARD_HOOK_FEE_PERCENT
                ),
                env
            );
        } else {
            console2.log("SKIPPED MerklClaimRewardHook: Merkl Distributor not configured for chain", chainId);
        }

        // Protocol-specific hooks
        __checkContract(ETHENA_COOLDOWN_SHARES_HOOK_KEY, __getSalt(ETHENA_COOLDOWN_SHARES_HOOK_KEY), "", env);
        __checkContract(ETHENA_UNSTAKE_HOOK_KEY, __getSalt(ETHENA_UNSTAKE_HOOK_KEY), "", env);
        __checkContract(OFFRAMP_TOKENS_HOOK_KEY, __getSalt(OFFRAMP_TOKENS_HOOK_KEY), "", env);
        __checkContract(MARK_ROOT_AS_USED_HOOK_KEY, __getSalt(MARK_ROOT_AS_USED_HOOK_KEY), "", env);

        // Circle Gateway hooks
        __checkContract(
            CIRCLE_GATEWAY_WALLET_HOOK_KEY, __getSalt(CIRCLE_GATEWAY_WALLET_HOOK_KEY), abi.encode(GATEWAY_WALLET), env
        );
        __checkContract(
            CIRCLE_GATEWAY_MINTER_HOOK_KEY, __getSalt(CIRCLE_GATEWAY_MINTER_HOOK_KEY), abi.encode(GATEWAY_MINTER), env
        );
        __checkContract(
            CIRCLE_GATEWAY_ADD_DELEGATE_HOOK_KEY,
            __getSalt(CIRCLE_GATEWAY_ADD_DELEGATE_HOOK_KEY),
            abi.encode(GATEWAY_WALLET),
            env
        );
        __checkContract(
            CIRCLE_GATEWAY_REMOVE_DELEGATE_HOOK_KEY,
            __getSalt(CIRCLE_GATEWAY_REMOVE_DELEGATE_HOOK_KEY),
            abi.encode(GATEWAY_WALLET),
            env
        );
    }

    /// @notice Check oracle contracts
    /// @param superLedgerConfig Address of the SuperLedgerConfiguration
    /// @param env Environment (1 = vnet/dev, 0/2 = prod/staging)
    function _checkOracleContracts(address superLedgerConfig, uint256 env) internal {
        console2.log("");
        console2.log("=== Oracles ===");

        // Oracles that require superLedgerConfiguration
        if (superLedgerConfig != address(0)) {
            __checkContract(
                ERC4626_YIELD_SOURCE_ORACLE_KEY,
                __getSalt(ERC4626_YIELD_SOURCE_ORACLE_KEY),
                abi.encode(superLedgerConfig),
                env
            );
            __checkContract(
                ERC5115_YIELD_SOURCE_ORACLE_KEY,
                __getSalt(ERC5115_YIELD_SOURCE_ORACLE_KEY),
                abi.encode(superLedgerConfig),
                env
            );
            __checkContract(
                ERC7540_YIELD_SOURCE_ORACLE_KEY,
                __getSalt(ERC7540_YIELD_SOURCE_ORACLE_KEY),
                abi.encode(superLedgerConfig),
                env
            );
            __checkContract(
                PENDLE_PT_YIELD_SOURCE_ORACLE_KEY,
                __getSalt(PENDLE_PT_YIELD_SOURCE_ORACLE_KEY),
                abi.encode(superLedgerConfig),
                env
            );
            __checkContract(
                SPECTRA_PT_YIELD_SOURCE_ORACLE_KEY,
                __getSalt(SPECTRA_PT_YIELD_SOURCE_ORACLE_KEY),
                abi.encode(superLedgerConfig),
                env
            );
            __checkContract(
                STAKING_YIELD_SOURCE_ORACLE_KEY,
                __getSalt(STAKING_YIELD_SOURCE_ORACLE_KEY),
                abi.encode(superLedgerConfig),
                env
            );
        } else {
            revert("ORACLES_CHECK_FAILED_MISSING_SUPER_LEDGER_CONFIG");
        }

        // SuperYieldSourceOracle (no constructor args)
        __checkContract(SUPER_YIELD_SOURCE_ORACLE_KEY, __getSalt(SUPER_YIELD_SOURCE_ORACLE_KEY), "", env);
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

        status = _getContractStatus(chainId, SUPER_VALIDATOR_KEY);
        if (status.isDeployed) coreContracts.superValidator = status.contractAddress;

        status = _getContractStatus(chainId, SUPER_DESTINATION_VALIDATOR_KEY);
        if (status.isDeployed) coreContracts.superDestinationValidator = status.contractAddress;

        status = _getContractStatus(chainId, SUPER_NATIVE_PAYMASTER_KEY);
        if (status.isDeployed) coreContracts.superNativePaymaster = status.contractAddress;
    }

    function _deployCoreContracts(uint64 chainId, uint256 env) internal {
        CoreContracts memory coreContracts;

        // Get contract availability for this chain
        ContractAvailability memory availability = _getContractAvailability(chainId);

        // Pre-populate core contracts with existing deployed addresses
        _populateCoreContractsFromStatus(chainId, coreContracts);

        // ===== VALIDATION PHASE =====
        // Validate critical dependencies before deployment
        console2.log("Validating deployment dependencies for chain:", chainId);

        // Validate treasury address
        require(configuration.treasury != address(0), "TREASURY_ADDRESS_ZERO");
        console2.log(" Treasury:", configuration.treasury);

        // Check Permit2 (required for BatchTransferFromHook)
        require(configuration.permit2s[chainId] != address(0), "PERMIT2_ADDRESS_ZERO");
        require(configuration.permit2s[chainId].code.length > 0, "PERMIT2_NOT_DEPLOYED");
        console2.log(" Permit2:", configuration.permit2s[chainId]);

        // Only validate Across if it's available on this chain
        if (availability.acrossV3Adapter) {
            require(configuration.acrossSpokePoolV3s[chainId] != address(0), "ACROSS_SPOKE_POOL_ADDRESS_ZERO");
            require(configuration.acrossSpokePoolV3s[chainId].code.length > 0, "ACROSS_SPOKE_POOL_NOT_DEPLOYED");
            console2.log(" Across Spoke Pool V3:", configuration.acrossSpokePoolV3s[chainId]);
        } else {
            console2.log(" SKIPPED Across Spoke Pool V3 validation: Not available on chain", chainId);
        }

        // Only validate DeBridge if it's available on this chain
        if (availability.debridgeAdapter) {
            require(configuration.debridgeDstDln[chainId] != address(0), "DEBRIDGE_DLN_ADDRESS_ZERO");
            require(configuration.debridgeDstDln[chainId].code.length > 0, "DEBRIDGE_DLN_NOT_DEPLOYED");
            console2.log(" DeBridge DLN DST:", configuration.debridgeDstDln[chainId]);
        } else {
            console2.log(" SKIPPED DeBridge DLN DST validation: Not available on chain", chainId);
        }

        // Only validate routers if hooks are available
        if (availability.swap1InchHook) {
            require(configuration.aggregationRouters[chainId] != address(0), "AGGREGATION_ROUTER_ADDRESS_ZERO");
            require(configuration.aggregationRouters[chainId].code.length > 0, "AGGREGATION_ROUTER_NOT_DEPLOYED");
            console2.log(" 1inch Aggregation Router:", configuration.aggregationRouters[chainId]);
        } else {
            console2.log(" SKIPPED 1inch Aggregation Router validation: Not available on chain", chainId);
        }

        if (availability.swapOdosHooks) {
            require(configuration.odosRouters[chainId] != address(0), "ODOS_ROUTER_ADDRESS_ZERO");
            require(configuration.odosRouters[chainId].code.length > 0, "ODOS_ROUTER_NOT_DEPLOYED");
            console2.log(" ODOS Router:", configuration.odosRouters[chainId]);
        } else {
            console2.log(" SKIPPED ODOS Router validation: Not available on chain", chainId);
        }

        // Only validate Merkl if it's available
        if (availability.merklClaimRewardHook) {
            require(configuration.merklDistributors[chainId] != address(0), "MERKL_DISTRIBUTOR_ADDRESS_ZERO");
            require(configuration.merklDistributors[chainId].code.length > 0, "MERKL_DISTRIBUTOR_NOT_DEPLOYED");
            console2.log(" Merkl Distributor:", configuration.merklDistributors[chainId]);
        } else {
            console2.log(" SKIPPED Merkl Distributor validation: Not available on chain", chainId);
        }

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
            __getBytecode("SuperLedgerConfiguration", env)
        );

        // Validate SuperLedgerConfiguration was deployed
        require(coreContracts.superLedgerConfiguration != address(0), "SUPER_LEDGER_CONFIGURATION_DEPLOYMENT_FAILED");
        require(coreContracts.superLedgerConfiguration.code.length > 0, "SUPER_LEDGER_CONFIGURATION_NO_CODE");
        console2.log(" SuperLedgerConfiguration deployed and validated");

        // Deploy SuperValidator
        coreContracts.superValidator = __deployContractIfNeeded(
            SUPER_VALIDATOR_KEY, chainId, __getSalt(SUPER_VALIDATOR_KEY), __getBytecode("SuperValidator", env)
        );

        // Validate SuperValidator was deployed
        require(coreContracts.superValidator != address(0), "SUPER_MERKLE_VALIDATOR_DEPLOYMENT_FAILED");
        require(coreContracts.superValidator.code.length > 0, "SUPER_MERKLE_VALIDATOR_NO_CODE");
        console2.log(" SuperValidator deployed and validated");

        // Deploy SuperDestinationValidator
        coreContracts.superDestinationValidator = __deployContractIfNeeded(
            SUPER_DESTINATION_VALIDATOR_KEY,
            chainId,
            __getSalt(SUPER_DESTINATION_VALIDATOR_KEY),
            __getBytecode("SuperDestinationValidator", env)
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
            abi.encodePacked(__getBytecode("SuperExecutor", env), abi.encode(coreContracts.superLedgerConfiguration))
        );

        // Validate SuperExecutor was deployed
        require(coreContracts.superExecutor != address(0), "SUPER_EXECUTOR_DEPLOYMENT_FAILED");
        require(coreContracts.superExecutor.code.length > 0, "SUPER_EXECUTOR_NO_CODE");
        console2.log(" SuperExecutor deployed and validated");

        // Deploy SuperDestinationExecutor - VALIDATED CONSTRUCTOR PARAMETERS
        require(coreContracts.superLedgerConfiguration != address(0), "SUPER_DEST_EXECUTOR_LEDGER_CONFIG_PARAM_ZERO");
        require(coreContracts.superDestinationValidator != address(0), "SUPER_DEST_EXECUTOR_VALIDATOR_PARAM_ZERO");

        coreContracts.superDestinationExecutor = __deployContractIfNeeded(
            SUPER_DESTINATION_EXECUTOR_KEY,
            chainId,
            __getSalt(SUPER_DESTINATION_EXECUTOR_KEY),
            abi.encodePacked(
                __getBytecode("SuperDestinationExecutor", env),
                abi.encode(coreContracts.superLedgerConfiguration, coreContracts.superDestinationValidator)
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
            __getBytecode("SuperSenderCreator", env)
        );

        // Validate SuperSenderCreator was deployed
        require(coreContracts.superSenderCreator != address(0), "SUPER_SENDER_CREATOR_DEPLOYMENT_FAILED");
        require(coreContracts.superSenderCreator.code.length > 0, "SUPER_SENDER_CREATOR_NO_CODE");
        console2.log(" SuperSenderCreator deployed and validated");

        // Deploy AcrossV3Adapter only if available on this chain
        if (availability.acrossV3Adapter) {
            require(configuration.acrossSpokePoolV3s[chainId] != address(0), "ACROSS_ADAPTER_SPOKE_POOL_PARAM_ZERO");
            require(coreContracts.superDestinationExecutor != address(0), "ACROSS_ADAPTER_DEST_EXECUTOR_PARAM_ZERO");

            coreContracts.acrossV3Adapter = __deployContractIfNeeded(
                ACROSS_V3_ADAPTER_KEY,
                chainId,
                __getSalt(ACROSS_V3_ADAPTER_KEY),
                abi.encodePacked(
                    __getBytecode("AcrossV3Adapter", env),
                    abi.encode(configuration.acrossSpokePoolV3s[chainId], coreContracts.superDestinationExecutor)
                )
            );

            // Validate AcrossV3Adapter was deployed
            require(coreContracts.acrossV3Adapter != address(0), "ACROSS_V3_ADAPTER_DEPLOYMENT_FAILED");
            require(coreContracts.acrossV3Adapter.code.length > 0, "ACROSS_V3_ADAPTER_NO_CODE");
            console2.log(" AcrossV3Adapter deployed and validated");
        } else {
            console2.log(" SKIPPED AcrossV3Adapter deployment: Not available on chain", chainId);
        }

        // Deploy DebridgeAdapter only if available on this chain
        if (availability.debridgeAdapter) {
            require(configuration.debridgeDstDln[chainId] != address(0), "DEBRIDGE_ADAPTER_DST_DLN_PARAM_ZERO");
            require(coreContracts.superDestinationExecutor != address(0), "DEBRIDGE_ADAPTER_DEST_EXECUTOR_PARAM_ZERO");

            coreContracts.debridgeAdapter = __deployContractIfNeeded(
                DEBRIDGE_ADAPTER_KEY,
                chainId,
                __getSalt(DEBRIDGE_ADAPTER_KEY),
                abi.encodePacked(
                    __getBytecode("DebridgeAdapter", env),
                    abi.encode(configuration.debridgeDstDln[chainId], coreContracts.superDestinationExecutor)
                )
            );

            // Validate DebridgeAdapter was deployed
            require(coreContracts.debridgeAdapter != address(0), "DEBRIDGE_ADAPTER_DEPLOYMENT_FAILED");
            require(coreContracts.debridgeAdapter.code.length > 0, "DEBRIDGE_ADAPTER_NO_CODE");
            console2.log(" DebridgeAdapter deployed and validated");
        } else {
            console2.log(" SKIPPED DebridgeAdapter deployment: Not available on chain", chainId);
        }

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
                __getBytecode("SuperLedger", env), abi.encode(coreContracts.superLedgerConfiguration, allowedExecutors)
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
                __getBytecode("FlatFeeLedger", env),
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
            abi.encodePacked(__getBytecode("SuperNativePaymaster", env), abi.encode(ENTRY_POINT))
        );

        // Validate SuperNativePaymaster was deployed
        require(coreContracts.superNativePaymaster != address(0), "SUPER_NATIVE_PAYMASTER_DEPLOYMENT_FAILED");
        require(coreContracts.superNativePaymaster.code.length > 0, "SUPER_NATIVE_PAYMASTER_NO_CODE");
        console2.log(" SuperNativePaymaster deployed and validated");

        console2.log(" All core contracts deployment completed successfully with full validation ");

        // Deploy Hooks
        _deployHooks(chainId, env);

        // Deploy Mock Contracts (only for development environment)
        if (env == 1) {
            //_deployMockContracts(chainId);
        }

        // Deploy Oracles
        _deployOracles(chainId, env);

        // Setup SuperLedger configuration with oracle mappings - CONDITIONAL BASED ON ENVIRONMENT
        // All environments - skip setup, will be done separately via runLedgerConfigurations
        console2.log("Skipping SuperLedger configuration for all environments");
        console2.log("Configuration will be done separately via runLedgerConfigurations script");
    }

    /// @notice Internal function to setup SuperLedger configuration
    /// @dev Can read from deployed contracts or output files based on useFiles parameter
    /// @param chainId Target chain ID
    /// @param env Environment for determining output path (only used if useFiles is true)
    function _setupSuperLedgerConfiguration(uint64 chainId, uint256 env) private {
        _setupSuperLedgerConfiguration(chainId, env, "");
    }

    function _setupSuperLedgerConfiguration(uint64 chainId, uint256 env, string memory branchName) private {
        // ===== GET CONTRACT ADDRESSES BASED ON SOURCE =====
        address superLedgerConfig;
        address erc4626Oracle;
        address erc7540Oracle;
        address erc5115Oracle;
        address stakingOracle;
        address superLedger;
        address flatFeeLedger;

        // Read contract addresses from deployment output files
        string memory deploymentJson = _verifyContractAddressesFromBytecode(chainId, env, branchName);

        superLedgerConfig = vm.parseJsonAddress(deploymentJson, ".SuperLedgerConfiguration");
        erc4626Oracle = vm.parseJsonAddress(deploymentJson, ".ERC4626YieldSourceOracle");
        erc7540Oracle = vm.parseJsonAddress(deploymentJson, ".ERC7540YieldSourceOracle");
        erc5115Oracle = vm.parseJsonAddress(deploymentJson, ".ERC5115YieldSourceOracle");
        stakingOracle = vm.parseJsonAddress(deploymentJson, ".StakingYieldSourceOracle");
        superLedger = vm.parseJsonAddress(deploymentJson, ".SuperLedger");
        flatFeeLedger = vm.parseJsonAddress(deploymentJson, ".FlatFeeLedger");

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
        salts[0] = bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_SALT));
        salts[1] = bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_SALT));
        salts[2] = bytes32(bytes(ERC5115_YIELD_SOURCE_ORACLE_SALT));
        salts[3] = bytes32(bytes(STAKING_YIELD_SOURCE_ORACLE_SALT));

        // Validate salts are not empty
        for (uint256 i = 0; i < salts.length; ++i) {
            require(salts[i] != bytes32(0), "SETUP_SALT_ZERO");
        }

        console2.log(" All salts validated for yield source oracle setup");

        // Execute the configuration setup
        ISuperLedgerConfiguration(superLedgerConfig).setYieldSourceOracles(salts, configs);
    }

    /// @notice Local variables struct to avoid stack too deep in bytecode verification
    struct VerificationVars {
        address superLedgerConfig;
        address superExecutor;
        address superDestExecutor;
        address[] allowedExecutors;
        bytes ledgerConstructorArgs;
        uint256 verified;
        uint256 failed;
    }

    /// @notice Verify contract addresses by computing from environment-specific bytecode and comparing with output
    /// files
    /// @dev This provides foolproof verification that deployed addresses match expected bytecode
    /// @param chainId Target chain ID
    /// @param env Environment for determining bytecode and output paths
    function _verifyContractAddressesFromBytecode(
        uint64 chainId,
        uint256 env
    )
        private
        view
        returns (string memory deploymentJson)
    {
        return _verifyContractAddressesFromBytecode(chainId, env, "");
    }

    function _verifyContractAddressesFromBytecode(
        uint64 chainId,
        uint256 env,
        string memory branchName
    )
        private
        view
        returns (string memory deploymentJson)
    {
        console2.log("Verifying contract addresses from environment-specific bytecode...");

        // Read addresses from output files
        deploymentJson = _readCoreContractsFromOutput(chainId, env, branchName);

        // Initialize local variables struct
        VerificationVars memory vars;

        // Get constructor args for ledger contracts
        vars.superLedgerConfig = vm.parseJsonAddress(deploymentJson, ".SuperLedgerConfiguration");
        vars.superExecutor = vm.parseJsonAddress(deploymentJson, ".SuperExecutor");
        vars.superDestExecutor = vm.parseJsonAddress(deploymentJson, ".SuperDestinationExecutor");

        vars.allowedExecutors = new address[](2);
        vars.allowedExecutors[0] = vars.superExecutor;
        vars.allowedExecutors[1] = vars.superDestExecutor;

        vars.ledgerConstructorArgs = abi.encode(vars.superLedgerConfig, vars.allowedExecutors);

        // Define contracts to verify with their corresponding environment-specific bytecode paths and constructor args
        ContractVerification[] memory contracts = new ContractVerification[](7);

        // Core contracts verification - always use locked bytecode

        contracts[0] = ContractVerification({
            name: "SuperLedgerConfiguration",
            outputKey: ".SuperLedgerConfiguration",
            bytecodePath: string(abi.encodePacked(BYTECODE_DIRECTORY, "SuperLedgerConfiguration.json")),
            constructorArgs: ""
        });

        contracts[1] = ContractVerification({
            name: "ERC4626YieldSourceOracle",
            outputKey: ".ERC4626YieldSourceOracle",
            bytecodePath: string(abi.encodePacked(BYTECODE_DIRECTORY, "ERC4626YieldSourceOracle.json")),
            constructorArgs: ""
        });

        contracts[2] = ContractVerification({
            name: "ERC7540YieldSourceOracle",
            outputKey: ".ERC7540YieldSourceOracle",
            bytecodePath: string(abi.encodePacked(BYTECODE_DIRECTORY, "ERC7540YieldSourceOracle.json")),
            constructorArgs: ""
        });

        contracts[3] = ContractVerification({
            name: "ERC5115YieldSourceOracle",
            outputKey: ".ERC5115YieldSourceOracle",
            bytecodePath: string(abi.encodePacked(BYTECODE_DIRECTORY, "ERC5115YieldSourceOracle.json")),
            constructorArgs: ""
        });

        contracts[4] = ContractVerification({
            name: "StakingYieldSourceOracle",
            outputKey: ".StakingYieldSourceOracle",
            bytecodePath: string(abi.encodePacked(BYTECODE_DIRECTORY, "StakingYieldSourceOracle.json")),
            constructorArgs: ""
        });

        contracts[5] = ContractVerification({
            name: "SuperLedger",
            outputKey: ".SuperLedger",
            bytecodePath: string(abi.encodePacked(BYTECODE_DIRECTORY, "SuperLedger.json")),
            constructorArgs: string(vars.ledgerConstructorArgs)
        });

        contracts[6] = ContractVerification({
            name: "FlatFeeLedger",
            outputKey: ".FlatFeeLedger",
            bytecodePath: string(abi.encodePacked(BYTECODE_DIRECTORY, "FlatFeeLedger.json")),
            constructorArgs: string(vars.ledgerConstructorArgs)
        });
        // Verify each contract
        for (uint256 i = 0; i < contracts.length; i++) {
            _verifySingleContract(contracts[i], deploymentJson, vars);
        }

        // Final verification summary
        console2.log("=== BYTECODE VERIFICATION SUMMARY ===");
        console2.log("Verified:", vars.verified);
        console2.log("Failed:  ", vars.failed);
        console2.log("Total:   ", contracts.length);

        require(vars.failed == 0, "BYTECODE_VERIFICATION_FAILED");
        require(vars.verified == contracts.length, "INCOMPLETE_VERIFICATION");

        console2.log("[SUCCESS] All contract addresses verified successfully against locked bytecode!");
    }

    /// @notice Verify a single contract's address against its bytecode
    /// @param contractToVerify The contract verification details
    /// @param deploymentJson The deployment JSON string
    /// @param vars The verification variables struct (modified in place)
    function _verifySingleContract(
        ContractVerification memory contractToVerify,
        string memory deploymentJson,
        VerificationVars memory vars
    )
        private
        view
    {
        console2.log("Verifying:", contractToVerify.name);

        // Get address from output file
        address outputAddress = vm.parseJsonAddress(deploymentJson, contractToVerify.outputKey);
        require(outputAddress != address(0), string(abi.encodePacked("OUTPUT_ADDRESS_ZERO_", contractToVerify.name)));

        // Compute expected address from locked bytecode
        bytes memory bytecode = vm.getCode(contractToVerify.bytecodePath);
        require(bytecode.length > 0, string(abi.encodePacked("BYTECODE_EMPTY_", contractToVerify.name)));

        // Compute address with appropriate constructor args
        address computedAddress;

        // Handle contracts with constructor args
        if (
            Strings.equal(contractToVerify.name, "ERC4626YieldSourceOracle")
                || Strings.equal(contractToVerify.name, "ERC7540YieldSourceOracle")
                || Strings.equal(contractToVerify.name, "ERC5115YieldSourceOracle")
                || Strings.equal(contractToVerify.name, "StakingYieldSourceOracle")
        ) {
            // Oracles need SuperLedgerConfiguration
            bytes memory constructorArgs = abi.encode(vars.superLedgerConfig);
            computedAddress = DeterministicDeployerLib.computeAddress(
                abi.encodePacked(bytecode, constructorArgs), __getSalt(contractToVerify.name)
            );
        } else if (
            Strings.equal(contractToVerify.name, "SuperLedger") || Strings.equal(contractToVerify.name, "FlatFeeLedger")
        ) {
            // Ledgers need SuperLedgerConfiguration and allowedExecutors
            computedAddress = DeterministicDeployerLib.computeAddress(
                abi.encodePacked(bytecode, vars.ledgerConstructorArgs), __getSalt(contractToVerify.name)
            );
        } else {
            // No constructor args
            computedAddress = DeterministicDeployerLib.computeAddress(bytecode, __getSalt(contractToVerify.name));
        }

        // Verify addresses match
        if (outputAddress == computedAddress) {
            console2.log("  [VERIFIED]:", contractToVerify.name);
            console2.log("    Address:", outputAddress);
            vars.verified++;
        } else {
            console2.log("  [MISMATCH]:", contractToVerify.name);
            console2.log("    Output file:", outputAddress);
            console2.log("    Computed:  ", computedAddress);
            vars.failed++;
        }

        // Verify contract has code at the address
        require(outputAddress.code.length > 0, string(abi.encodePacked("NO_CODE_AT_ADDRESS_", contractToVerify.name)));

        console2.log("");
    }

    /// @notice Helper function to read core contract addresses from output files
    /// @dev Similar to _readCoreContracts but for production/staging environments
    /// @param chainId Target chain ID
    /// @param env Environment (0 = prod, 2 = staging)
    /// @return JSON string containing contract addresses
    function _readCoreContractsFromOutput(uint64 chainId, uint256 env) internal view returns (string memory) {
        return _readCoreContractsFromOutput(chainId, env, "");
    }

    function _readCoreContractsFromOutput(
        uint64 chainId,
        uint256 env,
        string memory branchName
    )
        internal
        view
        returns (string memory)
    {
        string memory chainName = chainNames[chainId];
        // Use environment variable for reliable project root, fallback to vm.projectRoot()
        string memory root = vm.envOr("SUPERFORM_PROJECT_ROOT", vm.projectRoot());

        string memory envName;
        if (env == 0) {
            envName = "prod";
        } else if (env == 1) {
            require(bytes(branchName).length > 0, "BRANCH_NAME_REQUIRED_FOR_ENV_1");
            envName = branchName;
        } else {
            envName = "staging"; // env=2
        }

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

    function _deployHooks(uint64 chainId, uint256 env) private returns (HookAddresses memory hookAddresses) {
        console2.log("Starting hook deployment with comprehensive dependency validation...");

        // Get contract availability for this chain
        ContractAvailability memory availability = _getContractAvailability(chainId);

        uint256 len = 34;
        HookDeployment[] memory hooks = new HookDeployment[](len);
        address[] memory addresses = new address[](len);

        // ===== HOOKS WITHOUT DEPENDENCIES =====
        hooks[0] = HookDeployment(APPROVE_ERC20_HOOK_KEY, __getBytecode("ApproveERC20Hook", env));
        hooks[1] = HookDeployment(TRANSFER_ERC20_HOOK_KEY, __getBytecode("TransferERC20Hook", env));

        // ===== HOOKS WITH VALIDATED DEPENDENCIES =====

        // BatchTransferFromHook - Requires Permit2 (already validated in core deployment)
        require(configuration.permit2s[chainId] != address(0), "BATCH_TRANSFER_FROM_HOOK_PERMIT2_PARAM_ZERO");
        require(configuration.permit2s[chainId].code.length > 0, "BATCH_TRANSFER_FROM_HOOK_PERMIT2_NOT_DEPLOYED");

        hooks[2] = HookDeployment(
            BATCH_TRANSFER_HOOK_KEY,
            abi.encodePacked(__getBytecode("BatchTransferHook", env), abi.encode(configuration.nativeTokens[chainId]))
        );
        hooks[3] = HookDeployment(
            BATCH_TRANSFER_FROM_HOOK_KEY,
            abi.encodePacked(__getBytecode("BatchTransferFromHook", env), abi.encode(configuration.permit2s[chainId]))
        );

        // Vault hooks (no external dependencies)
        hooks[4] = HookDeployment(DEPOSIT_4626_VAULT_HOOK_KEY, __getBytecode("Deposit4626VaultHook", env));
        hooks[5] = HookDeployment(
            APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY, __getBytecode("ApproveAndDeposit4626VaultHook", env)
        );
        hooks[6] = HookDeployment(REDEEM_4626_VAULT_HOOK_KEY, __getBytecode("Redeem4626VaultHook", env));
        hooks[7] = HookDeployment(DEPOSIT_5115_VAULT_HOOK_KEY, __getBytecode("Deposit5115VaultHook", env));
        hooks[8] = HookDeployment(
            APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY, __getBytecode("ApproveAndDeposit5115VaultHook", env)
        );
        hooks[9] = HookDeployment(REDEEM_5115_VAULT_HOOK_KEY, __getBytecode("Redeem5115VaultHook", env));
        hooks[10] =
            HookDeployment(REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY, __getBytecode("RequestDeposit7540VaultHook", env));
        hooks[11] = HookDeployment(
            APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY, __getBytecode("ApproveAndRequestDeposit7540VaultHook", env)
        );
        hooks[12] = HookDeployment(REDEEM_7540_VAULT_HOOK_KEY, __getBytecode("Redeem7540VaultHook", env));
        hooks[13] = HookDeployment(REQUEST_REDEEM_7540_VAULT_HOOK_KEY, __getBytecode("RequestRedeem7540VaultHook", env));
        hooks[14] = HookDeployment(DEPOSIT_7540_VAULT_HOOK_KEY, __getBytecode("Deposit7540VaultHook", env));

        // ===== HOOKS WITH EXTERNAL ROUTER DEPENDENCIES =====

        // 1inch Swap Hook - Only deploy if available on this chain
        if (availability.swap1InchHook) {
            require(configuration.aggregationRouters[chainId] != address(0), "SWAP_1INCH_HOOK_ROUTER_PARAM_ZERO");
            require(configuration.aggregationRouters[chainId].code.length > 0, "SWAP_1INCH_HOOK_ROUTER_NOT_DEPLOYED");
            hooks[15] = HookDeployment(
                SWAP_1INCH_HOOK_KEY,
                abi.encodePacked(
                    __getBytecode("Swap1InchHook", env), abi.encode(configuration.aggregationRouters[chainId])
                )
            );
        } else {
            console2.log(" SKIPPED Swap1InchHook deployment: Not available on chain", chainId);
            hooks[15] = HookDeployment("", ""); // Empty deployment
        }

        // ODOS Swap Hooks - Only deploy if available on this chain
        if (availability.swapOdosHooks) {
            require(configuration.odosRouters[chainId] != address(0), "SWAP_ODOS_HOOK_ROUTER_PARAM_ZERO");
            require(configuration.odosRouters[chainId].code.length > 0, "SWAP_ODOS_HOOK_ROUTER_NOT_DEPLOYED");
            hooks[16] = HookDeployment(
                SWAP_ODOSV2_HOOK_KEY,
                abi.encodePacked(__getBytecode("SwapOdosV2Hook", env), abi.encode(configuration.odosRouters[chainId]))
            );
            hooks[17] = HookDeployment(
                APPROVE_AND_SWAP_ODOSV2_HOOK_KEY,
                abi.encodePacked(
                    __getBytecode("ApproveAndSwapOdosV2Hook", env), abi.encode(configuration.odosRouters[chainId])
                )
            );
        } else {
            console2.log(" SKIPPED ODOS Swap Hooks deployment: Not available on chain", chainId);
            hooks[16] = HookDeployment("", ""); // Empty deployment
            hooks[17] = HookDeployment("", ""); // Empty deployment
        }

        address superValidator;
        // Across Bridge Hook - Only deploy if available on this chain
        if (availability.acrossV3Adapter) {
            require(configuration.acrossSpokePoolV3s[chainId] != address(0), "ACROSS_HOOK_SPOKE_POOL_PARAM_ZERO");
            require(configuration.acrossSpokePoolV3s[chainId].code.length > 0, "ACROSS_HOOK_SPOKE_POOL_NOT_DEPLOYED");

            superValidator = _getContract(chainId, SUPER_VALIDATOR_KEY);
            require(superValidator != address(0), "ACROSS_HOOK_MERKLE_VALIDATOR_PARAM_ZERO");
            require(superValidator.code.length > 0, "ACROSS_HOOK_MERKLE_VALIDATOR_NOT_DEPLOYED");

            hooks[18] = HookDeployment(
                ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY,
                abi.encodePacked(
                    __getBytecode("AcrossSendFundsAndExecuteOnDstHook", env),
                    abi.encode(configuration.acrossSpokePoolV3s[chainId], superValidator)
                )
            );
        } else {
            console2.log(" SKIPPED AcrossSendFundsAndExecuteOnDstHook deployment: Not available on chain", chainId);
            hooks[18] = HookDeployment("", ""); // Empty deployment
        }

        // DeBridge hooks - Only deploy if available on this chain
        superValidator = _getContract(chainId, SUPER_VALIDATOR_KEY);
        require(superValidator != address(0), "DEBRIDGE_HOOKS_MERKLE_VALIDATOR_PARAM_ZERO");

        if (availability.deBridgeSendOrderHook) {
            require(configuration.debridgeSrcDln[chainId] != address(0), "DEBRIDGE_SEND_HOOK_DLN_SRC_PARAM_ZERO");
            hooks[19] = HookDeployment(
                DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY,
                abi.encodePacked(
                    __getBytecode("DeBridgeSendOrderAndExecuteOnDstHook", env),
                    abi.encode(configuration.debridgeSrcDln[chainId], superValidator)
                )
            );
        } else {
            console2.log(" SKIPPED DeBridgeSendOrderAndExecuteOnDstHook deployment: Not available on chain", chainId);
            hooks[19] = HookDeployment("", ""); // Empty deployment
        }

        if (availability.deBridgeCancelOrderHook) {
            require(configuration.debridgeDstDln[chainId] != address(0), "DEBRIDGE_CANCEL_HOOK_DLN_DST_PARAM_ZERO");
            hooks[20] = HookDeployment(
                DEBRIDGE_CANCEL_ORDER_HOOK_KEY,
                abi.encodePacked(
                    __getBytecode("DeBridgeCancelOrderHook", env), abi.encode(configuration.debridgeDstDln[chainId])
                )
            );
        } else {
            console2.log(" SKIPPED DeBridgeCancelOrderHook deployment: Not available on chain", chainId);
            hooks[20] = HookDeployment("", ""); // Empty deployment
        }

        // Protocol-specific hooks (no external dependencies)
        hooks[21] = HookDeployment(ETHENA_COOLDOWN_SHARES_HOOK_KEY, __getBytecode("EthenaCooldownSharesHook", env));
        hooks[22] = HookDeployment(ETHENA_UNSTAKE_HOOK_KEY, __getBytecode("EthenaUnstakeHook", env));
        hooks[23] =
            HookDeployment(CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY, __getBytecode("CancelDepositRequest7540Hook", env));
        hooks[24] =
            HookDeployment(CANCEL_REDEEM_REQUEST_7540_HOOK_KEY, __getBytecode("CancelRedeemRequest7540Hook", env));
        hooks[25] = HookDeployment(
            CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY, __getBytecode("ClaimCancelDepositRequest7540Hook", env)
        );
        hooks[26] = HookDeployment(
            CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY, __getBytecode("ClaimCancelRedeemRequest7540Hook", env)
        );
        hooks[27] = HookDeployment(OFFRAMP_TOKENS_HOOK_KEY, __getBytecode("OfframpTokensHook", env));
        hooks[28] = HookDeployment(MARK_ROOT_AS_USED_HOOK_KEY, __getBytecode("MarkRootAsUsedHook", env));
        // Merkl Claim Reward Hook - Only deploy if available on this chain
        if (availability.merklClaimRewardHook) {
            hooks[29] = HookDeployment(
                MERKL_CLAIM_REWARD_HOOK_KEY,
                abi.encodePacked(
                    __getBytecode("MerklClaimRewardHook", env),
                    abi.encode(
                        configuration.merklDistributors[chainId],
                        configuration.treasury,
                        MERKLE_CLAIM_REWARD_HOOK_FEE_PERCENT
                    )
                )
            );
        } else {
            console2.log(" SKIPPED MerklClaimRewardHook deployment: Not available on chain", chainId);
            hooks[29] = HookDeployment("", ""); // Empty deployment
        }

        // ===== CIRCLE GATEWAY HOOKS =====
        // Circle Gateway hooks - Validate gateway addresses
        require(GATEWAY_WALLET != address(0), "CIRCLE_GATEWAY_WALLET_PARAM_ZERO");
        require(GATEWAY_MINTER != address(0), "CIRCLE_GATEWAY_MINTER_PARAM_ZERO");

        hooks[30] = HookDeployment(
            CIRCLE_GATEWAY_WALLET_HOOK_KEY,
            abi.encodePacked(__getBytecode("CircleGatewayWalletHook", env), abi.encode(GATEWAY_WALLET))
        );
        hooks[31] = HookDeployment(
            CIRCLE_GATEWAY_MINTER_HOOK_KEY,
            abi.encodePacked(__getBytecode("CircleGatewayMinterHook", env), abi.encode(GATEWAY_MINTER))
        );
        hooks[32] = HookDeployment(
            CIRCLE_GATEWAY_ADD_DELEGATE_HOOK_KEY,
            abi.encodePacked(__getBytecode("CircleGatewayAddDelegateHook", env), abi.encode(GATEWAY_WALLET))
        );
        hooks[33] = HookDeployment(
            CIRCLE_GATEWAY_REMOVE_DELEGATE_HOOK_KEY,
            abi.encodePacked(__getBytecode("CircleGatewayRemoveDelegateHook", env), abi.encode(GATEWAY_WALLET))
        );

        // ===== DEPLOY ALL HOOKS WITH VALIDATION =====
        console2.log("Deploying hooks with parameter validation...");
        for (uint256 i = 0; i < len; ++i) {
            HookDeployment memory hook = hooks[i];

            // Skip empty deployments (hooks not available on this chain)
            if (bytes(hook.name).length == 0) {
                console2.log("Skipping empty hook deployment at index", i);
                addresses[i] = address(0);
                continue;
            }

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
        hookAddresses.redeem7540VaultHook =
            Strings.equal(hooks[12].name, REDEEM_7540_VAULT_HOOK_KEY) ? addresses[12] : address(0);
        hookAddresses.requestRedeem7540VaultHook =
            Strings.equal(hooks[13].name, REQUEST_REDEEM_7540_VAULT_HOOK_KEY) ? addresses[13] : address(0);
        hookAddresses.deposit7540VaultHook =
            Strings.equal(hooks[14].name, DEPOSIT_7540_VAULT_HOOK_KEY) ? addresses[14] : address(0);
        hookAddresses.swap1InchHook = Strings.equal(hooks[15].name, SWAP_1INCH_HOOK_KEY) ? addresses[15] : address(0);
        hookAddresses.swapOdosHook = Strings.equal(hooks[16].name, SWAP_ODOSV2_HOOK_KEY) ? addresses[16] : address(0);
        hookAddresses.approveAndSwapOdosHook =
            Strings.equal(hooks[17].name, APPROVE_AND_SWAP_ODOSV2_HOOK_KEY) ? addresses[17] : address(0);
        hookAddresses.acrossSendFundsAndExecuteOnDstHook =
            Strings.equal(hooks[18].name, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY) ? addresses[18] : address(0);
        hookAddresses.deBridgeSendOrderAndExecuteOnDstHook =
            Strings.equal(hooks[19].name, DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY) ? addresses[19] : address(0);
        hookAddresses.deBridgeCancelOrderHook =
            Strings.equal(hooks[20].name, DEBRIDGE_CANCEL_ORDER_HOOK_KEY) ? addresses[20] : address(0);
        hookAddresses.ethenaCooldownSharesHook =
            Strings.equal(hooks[21].name, ETHENA_COOLDOWN_SHARES_HOOK_KEY) ? addresses[21] : address(0);
        hookAddresses.ethenaUnstakeHook =
            Strings.equal(hooks[22].name, ETHENA_UNSTAKE_HOOK_KEY) ? addresses[22] : address(0);
        hookAddresses.cancelDepositRequest7540Hook =
            Strings.equal(hooks[23].name, CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY) ? addresses[23] : address(0);
        hookAddresses.cancelRedeemRequest7540Hook =
            Strings.equal(hooks[24].name, CANCEL_REDEEM_REQUEST_7540_HOOK_KEY) ? addresses[24] : address(0);
        hookAddresses.claimCancelDepositRequest7540Hook =
            Strings.equal(hooks[25].name, CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY) ? addresses[25] : address(0);
        hookAddresses.claimCancelRedeemRequest7540Hook =
            Strings.equal(hooks[26].name, CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY) ? addresses[26] : address(0);
        hookAddresses.offrampTokensHook =
            Strings.equal(hooks[27].name, OFFRAMP_TOKENS_HOOK_KEY) ? addresses[27] : address(0);
        hookAddresses.markRootAsUsedHook =
            Strings.equal(hooks[28].name, MARK_ROOT_AS_USED_HOOK_KEY) ? addresses[28] : address(0);
        hookAddresses.merklClaimRewardHook =
            Strings.equal(hooks[29].name, MERKL_CLAIM_REWARD_HOOK_KEY) ? addresses[29] : address(0);
        hookAddresses.circleGatewayWalletHook =
            Strings.equal(hooks[30].name, CIRCLE_GATEWAY_WALLET_HOOK_KEY) ? addresses[30] : address(0);
        hookAddresses.circleGatewayMinterHook =
            Strings.equal(hooks[31].name, CIRCLE_GATEWAY_MINTER_HOOK_KEY) ? addresses[31] : address(0);
        hookAddresses.circleGatewayAddDelegateHook =
            Strings.equal(hooks[32].name, CIRCLE_GATEWAY_ADD_DELEGATE_HOOK_KEY) ? addresses[32] : address(0);
        hookAddresses.circleGatewayRemoveDelegateHook =
            Strings.equal(hooks[33].name, CIRCLE_GATEWAY_REMOVE_DELEGATE_HOOK_KEY) ? addresses[33] : address(0);

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
        // Only validate hooks that should be available on this chain
        if (availability.swap1InchHook) {
            require(hookAddresses.swap1InchHook != address(0), "SWAP_1INCH_HOOK_NOT_ASSIGNED");
        }
        if (availability.swapOdosHooks) {
            require(hookAddresses.swapOdosHook != address(0), "SWAP_ODOS_HOOK_NOT_ASSIGNED");
            require(hookAddresses.approveAndSwapOdosHook != address(0), "APPROVE_AND_SWAP_ODOS_HOOK_NOT_ASSIGNED");
        }
        if (availability.acrossV3Adapter) {
            require(
                hookAddresses.acrossSendFundsAndExecuteOnDstHook != address(0),
                "ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_NOT_ASSIGNED"
            );
        }
        if (availability.deBridgeSendOrderHook) {
            require(
                hookAddresses.deBridgeSendOrderAndExecuteOnDstHook != address(0),
                "DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_NOT_ASSIGNED"
            );
        }
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
        require(hookAddresses.ethenaCooldownSharesHook != address(0), "ETHENA_COOLDOWN_SHARES_HOOK_NOT_ASSIGNED");
        require(hookAddresses.ethenaUnstakeHook != address(0), "ETHENA_UNSTAKE_HOOK_NOT_ASSIGNED");
        require(hookAddresses.offrampTokensHook != address(0), "OFFRAMP_TOKENS_HOOK_NOT_ASSIGNED");

        require(hookAddresses.markRootAsUsedHook != address(0), "MARK_ROOT_AS_USED_HOOK_NOT_ASSIGNED");

        if (availability.merklClaimRewardHook) {
            require(hookAddresses.merklClaimRewardHook != address(0), "MERKL_CLAIM_REWARD_HOOK_NOT_ASSIGNED");
        }
        require(hookAddresses.circleGatewayWalletHook != address(0), "CIRCLE_GATEWAY_WALLET_HOOK_NOT_ASSIGNED");
        require(hookAddresses.circleGatewayMinterHook != address(0), "CIRCLE_GATEWAY_MINTER_HOOK_NOT_ASSIGNED");
        require(
            hookAddresses.circleGatewayAddDelegateHook != address(0), "CIRCLE_GATEWAY_ADD_DELEGATE_HOOK_NOT_ASSIGNED"
        );
        require(
            hookAddresses.circleGatewayRemoveDelegateHook != address(0),
            "CIRCLE_GATEWAY_REMOVE_DELEGATE_HOOK_NOT_ASSIGNED"
        );

        console2.log(" All hooks deployed and validated successfully with comprehensive dependency checking! ");

        return hookAddresses;
    }

    function _deployOracles(uint64 chainId, uint256 env) private returns (address[] memory oracleAddresses) {
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
            abi.encodePacked(__getBytecode("ERC4626YieldSourceOracle", env), abi.encode(superLedgerConfig))
        );
        oracles[1] = OracleDeployment(
            ERC5115_YIELD_SOURCE_ORACLE_KEY,
            abi.encodePacked(__getBytecode("ERC5115YieldSourceOracle", env), abi.encode(superLedgerConfig))
        );
        oracles[2] = OracleDeployment(
            ERC7540_YIELD_SOURCE_ORACLE_KEY,
            abi.encodePacked(__getBytecode("ERC7540YieldSourceOracle", env), abi.encode(superLedgerConfig))
        );
        oracles[3] = OracleDeployment(
            PENDLE_PT_YIELD_SOURCE_ORACLE_KEY,
            abi.encodePacked(__getBytecode("PendlePTYieldSourceOracle", env), abi.encode(superLedgerConfig))
        );
        oracles[4] = OracleDeployment(
            SPECTRA_PT_YIELD_SOURCE_ORACLE_KEY,
            abi.encodePacked(__getBytecode("SpectraPTYieldSourceOracle", env), abi.encode(superLedgerConfig))
        );
        oracles[5] = OracleDeployment(
            STAKING_YIELD_SOURCE_ORACLE_KEY,
            abi.encodePacked(__getBytecode("StakingYieldSourceOracle", env), abi.encode(superLedgerConfig))
        );
        oracles[6] = OracleDeployment(SUPER_YIELD_SOURCE_ORACLE_KEY, __getBytecode("SuperYieldSourceOracle", env));

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
