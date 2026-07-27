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
        address acrossV3AdapterV2;
        address debridgeAdapter;
        address stargateAdapter;
        address stargateAdapterV2;
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
        address withdraw7540VaultHook;
        address requestDeposit7540VaultHook;
        address approveAndRequestDeposit7540VaultHook;
        address redeem7540VaultHook;
        address requestRedeem7540VaultHook;
        address setOperator7540Hook;
        address setSlippageHook;
        address acrossSendFundsAndExecuteOnDstHook;
        address approveAndAcrossSendFundsAndExecuteOnDstHook;
        address swap1InchHook;
        address swapOdosHook;
        address approveAndSwapOdosHook;
        address pendleRouterSwapHook;
        address pendleRouterRedeemHook;
        address pendleUnifiedHook;
        address recordPurchasePendlePTAmortizedOracleHook;
        address recordRedemptionPendlePTAmortizedOracleHook;
        address recordPurchasePendlePTAmortizedOracleHookV2;
        address recordRedemptionPendlePTAmortizedOracleHookV2;
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
        address swapUniswapV4Hook;
        address swapUniswapV3Hook;
        address approveAndSwapUniswapV3Hook;
        address swapUniswapV3Router02Hook;
        address approveAndSwapUniswapV3Router02Hook;
        address transferHook;
        address swapSparkPsmExactInHook;
        address approveAndSwapSparkPsmExactInHook;
        address swapSparkPsmExactOutHook;
        address approveAndSwapSparkPsmExactOutHook;
        address swapKyberSwapHook;
        address approveAndSwapKyberSwapHook;
        address swapOpenOceanHook;
        address approveAndSwapOpenOceanHook;
        address swapUniswapV2Hook;
        address approveAndSwapUniswapV2Hook;
        address swapOdosV3Hook;
        address approveAndSwapOdosV3Hook;
        address cancelDepositRequestWithId7540Hook;
        address cancelRedeemRequestWithId7540Hook;
        address claimCancelDepositRequestWithId7540Hook;
        address claimCancelRedeemRequestWithId7540Hook;
        address redeemWithId7540VaultHook;
        address withdrawWithId7540VaultHook;
        address stargateSendHook;
        address approveAndStargateSendHook;
        address stargateSendHookV2;
        address approveAndStargateSendHookV2;
        address acrossSendFundsAndExecuteOnDstHookV2;
        address approveAndAcrossSendFundsAndExecuteOnDstHookV2;
        address claimFailedTransferHook;
        address cctpSendHook;
        address approveAndCCTPSendHook;
        address swapAerodromeUniversalRouterHook;
        address approveAndSwapAerodromeUniversalRouterHook;
    }

    struct HookDeployment {
        string name;
        string saltOverride; // Optional custom salt (empty = use name for salt)
        bytes creationCode;
    }

    // TEMPORARY: remove after the selected token-hook production upgrade is complete.
    struct TemporaryTokenHookUpgrade {
        string name;
        string saltName;
        bytes constructorArgs;
        bytes initCode;
        address predictedAddress;
        bool available;
        bool isDeployed;
    }

    error TemporaryHookArtifactMissing(string path);
    error TemporaryHookBytecodeEmpty(string path);
    error TemporaryHookBytecodeMismatch(string hookName, string artifactKind);
    error TemporaryHookAddressMismatch(string hookName, address expected, address actual);

    uint256 private constant TEMPORARY_TOKEN_HOOK_UPGRADE_COUNT = 7;
    uint256 private constant TEMPORARY_POLYGON_NATIVE_HOOK_UPGRADE_COUNT = 5;
    uint256 private constant TEMPORARY_PENDLE_HOOK_UPGRADE_COUNT = 3;
    uint256 private constant TEMPORARY_7540_HOOK_UPGRADE_COUNT = 7;
    address private constant DETERMINISTIC_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    struct OracleDeployment {
        string name;
        bytes creationCode;
    }

    /// @notice Create a HookDeployment struct, checking if bytecode exists first
    /// @param name Contract name/key
    /// @param contractName Contract name for bytecode lookup
    /// @param env Environment (0=prod, 1=dev/staging)
    /// @return HookDeployment struct (empty if bytecode doesn't exist)
    function _createSafeHookDeployment(
        string memory name,
        string memory contractName,
        uint256 env
    )
        internal
        view
        returns (HookDeployment memory)
    {
        if (!__checkBytecodeExists(contractName, env)) {
            console2.log("SKIPPED %s: Bytecode not found", contractName);
            return HookDeployment("", "", ""); // Empty deployment
        }
        return HookDeployment(name, "", __getBytecode(contractName, env));
    }

    /// @notice Create a HookDeployment struct with constructor args, checking if bytecode exists first
    /// @param name Contract name/key
    /// @param contractName Contract name for bytecode lookup
    /// @param env Environment (0=prod, 1=dev/staging)
    /// @param constructorArgs ABI-encoded constructor arguments
    /// @return HookDeployment struct (empty if bytecode doesn't exist)
    function _createSafeHookDeploymentWithArgs(
        string memory name,
        string memory contractName,
        uint256 env,
        bytes memory constructorArgs
    )
        internal
        view
        returns (HookDeployment memory)
    {
        if (!__checkBytecodeExists(contractName, env)) {
            console2.log("SKIPPED %s: Bytecode not found", contractName);
            return HookDeployment("", "", ""); // Empty deployment
        }
        return HookDeployment(name, "", abi.encodePacked(__getBytecode(contractName, env), constructorArgs));
    }

    /// @notice Create a HookDeployment struct with constructor args and custom salt, checking if bytecode exists first
    /// @param name Contract name/key (used for export)
    /// @param contractName Contract name for bytecode lookup
    /// @param saltOverride Custom salt for CREATE2 deployment
    /// @param env Environment (0=prod, 1=dev/staging)
    /// @param constructorArgs ABI-encoded constructor arguments
    /// @return HookDeployment struct (empty if bytecode doesn't exist)
    function _createSafeHookDeploymentWithArgsAndSalt(
        string memory name,
        string memory contractName,
        string memory saltOverride,
        uint256 env,
        bytes memory constructorArgs
    )
        internal
        view
        returns (HookDeployment memory)
    {
        if (!__checkBytecodeExists(contractName, env)) {
            console2.log("SKIPPED %s: Bytecode not found", contractName);
            return HookDeployment("", "", ""); // Empty deployment
        }
        return HookDeployment(name, saltOverride, abi.encodePacked(__getBytecode(contractName, env), constructorArgs));
    }

    /// @notice Create an OracleDeployment struct, checking if bytecode exists first
    /// @param name Contract name/key
    /// @param contractName Contract name for bytecode lookup
    /// @param env Environment (0=prod, 1=dev/staging)
    /// @return OracleDeployment struct (empty if bytecode doesn't exist)
    function _createSafeOracleDeployment(
        string memory name,
        string memory contractName,
        uint256 env
    )
        internal
        view
        returns (OracleDeployment memory)
    {
        if (!__checkBytecodeExists(contractName, env)) {
            console2.log("SKIPPED %s: Bytecode not found", contractName);
            return OracleDeployment("", ""); // Empty deployment
        }
        return OracleDeployment(name, __getBytecode(contractName, env));
    }

    /// @notice Create an OracleDeployment struct with constructor args, checking if bytecode exists first
    /// @param name Contract name/key
    /// @param contractName Contract name for bytecode lookup
    /// @param env Environment (0=prod, 1=dev/staging)
    /// @param constructorArgs ABI-encoded constructor arguments
    /// @return OracleDeployment struct (empty if bytecode doesn't exist)
    function _createSafeOracleDeploymentWithArgs(
        string memory name,
        string memory contractName,
        uint256 env,
        bytes memory constructorArgs
    )
        internal
        view
        returns (OracleDeployment memory)
    {
        if (!__checkBytecodeExists(contractName, env)) {
            console2.log("SKIPPED %s: Bytecode not found", contractName);
            return OracleDeployment("", ""); // Empty deployment
        }
        return OracleDeployment(name, abi.encodePacked(__getBytecode(contractName, env), constructorArgs));
    }

    struct ContractVerification {
        string name;
        string outputKey;
        string bytecodePath;
        string constructorArgs;
    }

    struct ContractAvailability {
        bool acrossV3Adapter;
        bool acrossV3AdapterV2;
        bool debridgeAdapter;
        bool stargateAdapter;
        bool stargateAdapterV2;
        bool deBridgeSendOrderHook;
        bool deBridgeCancelOrderHook;
        bool swap1InchHook;
        bool swapOdosHooks;
        bool swapOdosV3Hooks;
        bool swapAerodromeUniversalRouterHooks;
        bool swapUniswapV4Hook;
        bool swapUniswapV3Hooks;
        bool swapUniswapV3Router02Hooks;
        bool swapSparkPsmHooks;
        bool swapKyberSwapHooks;
        bool swapOpenOceanHooks;
        bool swapUniswapV2Hooks;
        bool pendleRouterHooks;
        bool pendlePTAmortizedOracleHooks;
        bool pendlePTAmortizedOracleHooksV2;
        bool merklClaimRewardHook;
        bool batchTransferFromHook;
        uint256 expectedCore;
        uint256 expectedAdapters;
        uint256 expectedHooks;
        uint256 expectedOracles;
        uint256 expectedTotal;
        string[] skippedContracts;
        string[] missingBytecodeContracts;
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
        _setCoreConfiguration(env_);
    }

    /// @notice Determines which contracts are available for deployment on a specific chain
    /// @param chainId The target chain ID
    /// @param env Environment (0 = prod uses locked-bytecode, 1/2 = dev/staging uses locked-bytecode-dev)
    /// @return availability ContractAvailability struct with availability flags and expected counts
    function _getContractAvailability(
        uint64 chainId,
        uint256 env
    )
        internal
        view
        returns (ContractAvailability memory availability)
    {
        // Initialize all skipped contracts array
        // Includes adapter skips, router-gated hooks, and optional Pendle oracle hooks.
        string[] memory potentialSkips = new string[](42);
        uint256 skipCount = 0;
        // Adapter contracts (5 contracts - conditionally deployed)
        string[5] memory adapterContracts =
            ["AcrossV3Adapter", "AcrossV3AdapterV2", "DebridgeAdapter", "StargateAdapter", "StargateAdapterV2"];

        // Start with all adapters, then decrement for missing configurations
        uint256 expectedAdapters = adapterContracts.length;

        // AcrossV3Adapter + AcrossV3AdapterV2
        if (configuration.acrossSpokePoolV3s[chainId] != address(0)) {
            availability.acrossV3Adapter = true;
            availability.acrossV3AdapterV2 = true;
        } else {
            expectedAdapters -= 2; // AcrossV3Adapter + AcrossV3AdapterV2
            potentialSkips[skipCount++] = "AcrossV3Adapter";
            potentialSkips[skipCount++] = "AcrossV3AdapterV2";
        }

        // DebridgeAdapter
        if (configuration.debridgeDstDln[chainId] != address(0)) {
            availability.debridgeAdapter = true;
        } else {
            expectedAdapters -= 1; // DebridgeAdapter
            potentialSkips[skipCount++] = "DebridgeAdapter";
        }

        // StargateAdapter + StargateAdapterV2 (requires lzEndpointV2 and tokenMessaging)
        if (
            configuration.lzEndpointV2s[chainId] != address(0)
                && configuration.stargateTokenMessagings[chainId] != address(0)
        ) {
            availability.stargateAdapter = true;
            availability.stargateAdapterV2 = true;
        } else {
            expectedAdapters -= 2; // StargateAdapter + StargateAdapterV2
            potentialSkips[skipCount++] = "StargateAdapter";
            potentialSkips[skipCount++] = "StargateAdapterV2";
        }

        availability.expectedAdapters = expectedAdapters;

        // Hook contracts - all hooks from regenerate_bytecode.sh (including V2/V3 versions)
        string[80] memory baseHooks = [
            "ApproveERC20Hook",
            "TransferERC20Hook",
            "BatchTransferHook",
            "BatchTransferFromHook",
            "Deposit4626VaultHook",
            "ApproveAndDeposit4626VaultHook",
            "Redeem4626VaultHook",
            "Deposit5115VaultHook",
            "ApproveAndDeposit5115VaultHook",
            "Redeem5115VaultHook",
            "RequestDeposit7540VaultHook",
            "ApproveAndRequestDeposit7540VaultHook",
            "Redeem7540VaultHook",
            "RequestRedeem7540VaultHook",
            "Deposit7540VaultHook",
            "Withdraw7540VaultHook",
            "SetOperator7540Hook",
            "SetSlippageHook",
            "CancelDepositRequest7540Hook",
            "CancelRedeemRequest7540Hook",
            "ClaimCancelDepositRequest7540Hook",
            "ClaimCancelRedeemRequest7540Hook",
            "CancelDepositRequestWithId7540Hook",
            "CancelRedeemRequestWithId7540Hook",
            "ClaimCancelDepositRequestWithId7540Hook",
            "ClaimCancelRedeemRequestWithId7540Hook",
            "RedeemWithId7540VaultHook",
            "WithdrawWithId7540VaultHook",
            "Swap1InchHook",
            "SwapOdosV2Hook",
            "ApproveAndSwapOdosV2Hook",
            "SwapAerodromeUniversalRouterHook",
            "ApproveAndSwapAerodromeUniversalRouterHook",
            "PendleRouterSwapHook",
            "PendleRouterRedeemHook",
            "PendleUnifiedHook",
            "RecordPurchasePendlePTAmortizedOracleHook",
            "RecordRedemptionPendlePTAmortizedOracleHook",
            "RecordPurchasePendlePTAmortizedOracleHookV2",
            "RecordRedemptionPendlePTAmortizedOracleHookV2",
            "AcrossSendFundsAndExecuteOnDstHook",
            "ApproveAndAcrossSendFundsAndExecuteOnDstHook",
            "DeBridgeSendOrderAndExecuteOnDstHook",
            "DeBridgeCancelOrderHook",
            "EthenaCooldownSharesHook",
            "EthenaUnstakeHook",
            "OfframpTokensHook",
            "MarkRootAsUsedHook",
            "MerklClaimRewardHook",
            "CircleGatewayWalletHook",
            "CircleGatewayMinterHook",
            "CircleGatewayAddDelegateHook",
            "CircleGatewayRemoveDelegateHook",
            "SwapUniswapV4Hook",
            "SwapUniswapV3Hook",
            "ApproveAndSwapUniswapV3Hook",
            "TransferHook",
            "SwapSparkPSMExactInHook",
            "ApproveAndSwapSparkPSMExactInHook",
            "SwapSparkPSMExactOutHook",
            "ApproveAndSwapSparkPSMExactOutHook",
            "SwapKyberSwapHook",
            "ApproveAndSwapKyberSwapHook",
            "SwapOpenOceanHook",
            "ApproveAndSwapOpenOceanHook",
            "SwapUniswapV2Hook",
            "ApproveAndSwapUniswapV2Hook",
            "StargateSendHook",
            "ApproveAndStargateSendHook",
            "StargateSendHookV2",
            "ApproveAndStargateSendHookV2",
            "CCTPSendHook",
            "ApproveAndCCTPSendHook",
            "SwapOdosV3Hook",
            "ApproveAndSwapOdosV3Hook",
            "ClaimFailedTransferHook",
            "SwapUniswapV3Router02Hook",
            "ApproveAndSwapUniswapV3Router02Hook",
            "AcrossSendFundsAndExecuteOnDstHookV2",
            "ApproveAndAcrossSendFundsAndExecuteOnDstHookV2"
        ];

        // Start with all hooks, then decrement for missing configurations
        uint256 expectedHooks = baseHooks.length;

        // Hooks that depend on external configurations - decrement if not available
        if (configuration.acrossSpokePoolV3s[chainId] == address(0)) {
            expectedHooks -= 4; // V1 + V2 Across hooks
            potentialSkips[skipCount++] = "AcrossSendFundsAndExecuteOnDstHook";
            potentialSkips[skipCount++] = "ApproveAndAcrossSendFundsAndExecuteOnDstHook";
            potentialSkips[skipCount++] = "AcrossSendFundsAndExecuteOnDstHookV2";
            potentialSkips[skipCount++] = "ApproveAndAcrossSendFundsAndExecuteOnDstHookV2";
        }

        if (configuration.aggregationRouters[chainId] != address(0)) {
            availability.swap1InchHook = true;
        } else {
            expectedHooks -= 1; // Swap1InchHook
            potentialSkips[skipCount++] = "Swap1InchHook";
        }

        if (configuration.odosRouters[chainId] != address(0)) {
            availability.swapOdosHooks = true;
        } else {
            expectedHooks -= 2; // SwapOdosV2Hook + ApproveAndSwapOdosV2Hook
            potentialSkips[skipCount++] = "SwapOdosV2Hook";
            potentialSkips[skipCount++] = "ApproveAndSwapOdosV2Hook";
        }

        if (configuration.odosRouterV3s[chainId] != address(0)) {
            availability.swapOdosV3Hooks = true;
        } else {
            expectedHooks -= 2; // SwapOdosV3Hook + ApproveAndSwapOdosV3Hook
            potentialSkips[skipCount++] = "SwapOdosV3Hook";
            potentialSkips[skipCount++] = "ApproveAndSwapOdosV3Hook";
        }

        if (configuration.aerodromeUniversalRouters[chainId] != address(0)) {
            availability.swapAerodromeUniversalRouterHooks = true;
        } else {
            expectedHooks -= 2;
            potentialSkips[skipCount++] = "SwapAerodromeUniversalRouterHook";
            potentialSkips[skipCount++] = "ApproveAndSwapAerodromeUniversalRouterHook";
        }

        if (configuration.debridgeSrcDln[chainId] != address(0)) {
            availability.deBridgeSendOrderHook = true;
        } else {
            expectedHooks -= 1; // DeBridgeSendOrderAndExecuteOnDstHook
            potentialSkips[skipCount++] = "DeBridgeSendOrderAndExecuteOnDstHook";
        }

        if (configuration.debridgeDstDln[chainId] != address(0)) {
            availability.deBridgeCancelOrderHook = true;
        } else {
            expectedHooks -= 1; // DeBridgeCancelOrderHook
            potentialSkips[skipCount++] = "DeBridgeCancelOrderHook";
        }

        if (configuration.merklDistributors[chainId] != address(0)) {
            availability.merklClaimRewardHook = true;
        } else {
            expectedHooks -= 1; // MerklClaimRewardHook
            potentialSkips[skipCount++] = "MerklClaimRewardHook";
        }

        if (configuration.permit2s[chainId] != address(0)) {
            availability.batchTransferFromHook = true;
        } else {
            expectedHooks -= 1; // BatchTransferFromHook
            potentialSkips[skipCount++] = "BatchTransferFromHook";
        }

        if (configuration.uniswapV4PoolManagers[chainId] != address(0)) {
            availability.swapUniswapV4Hook = true;
        } else {
            expectedHooks -= 1; // SwapUniswapV4Hook
            potentialSkips[skipCount++] = "SwapUniswapV4Hook";
        }

        if (configuration.uniswapV3SwapRouters[chainId] != address(0)) {
            availability.swapUniswapV3Hooks = true;
        } else {
            expectedHooks -= 2; // SwapUniswapV3Hook + ApproveAndSwapUniswapV3Hook
            potentialSkips[skipCount++] = "SwapUniswapV3Hook";
            potentialSkips[skipCount++] = "ApproveAndSwapUniswapV3Hook";
        }

        if (configuration.uniswapV3SwapRouter02s[chainId] != address(0)) {
            availability.swapUniswapV3Router02Hooks = true;
        } else {
            expectedHooks -= 2; // SwapUniswapV3Router02Hook + ApproveAndSwapUniswapV3Router02Hook
            potentialSkips[skipCount++] = "SwapUniswapV3Router02Hook";
            potentialSkips[skipCount++] = "ApproveAndSwapUniswapV3Router02Hook";
        }

        if (configuration.sparkPsm3s[chainId] != address(0)) {
            availability.swapSparkPsmHooks = true;
        } else {
            expectedHooks -= 4; // All 4 Spark PSM hooks
            potentialSkips[skipCount++] = "SwapSparkPSMExactInHook";
            potentialSkips[skipCount++] = "ApproveAndSwapSparkPSMExactInHook";
            potentialSkips[skipCount++] = "SwapSparkPSMExactOutHook";
            potentialSkips[skipCount++] = "ApproveAndSwapSparkPSMExactOutHook";
        }

        if (configuration.kyberSwapRouters[chainId] != address(0)) {
            availability.swapKyberSwapHooks = true;
        } else {
            expectedHooks -= 2; // SwapKyberSwapHook + ApproveAndSwapKyberSwapHook
            potentialSkips[skipCount++] = "SwapKyberSwapHook";
            potentialSkips[skipCount++] = "ApproveAndSwapKyberSwapHook";
        }

        if (
            configuration.openOceanRouters[chainId] != address(0)
                && configuration.openOceanReferrers[chainId] != address(0)
        ) {
            availability.swapOpenOceanHooks = true;
        } else {
            expectedHooks -= 2; // SwapOpenOceanHook + ApproveAndSwapOpenOceanHook
            potentialSkips[skipCount++] = "SwapOpenOceanHook";
            potentialSkips[skipCount++] = "ApproveAndSwapOpenOceanHook";
        }

        if (configuration.uniswapV2SwapRouters[chainId] != address(0)) {
            availability.swapUniswapV2Hooks = true;
        } else {
            expectedHooks -= 2; // SwapUniswapV2Hook + ApproveAndSwapUniswapV2Hook
            potentialSkips[skipCount++] = "SwapUniswapV2Hook";
            potentialSkips[skipCount++] = "ApproveAndSwapUniswapV2Hook";
        }

        if (configuration.pendleRouters[chainId] != address(0)) {
            availability.pendleRouterHooks = true;
        } else {
            expectedHooks -= 3; // PendleRouterSwapHook + PendleRouterRedeemHook + PendleUnifiedHook
            potentialSkips[skipCount++] = "PendleRouterSwapHook";
            potentialSkips[skipCount++] = "PendleRouterRedeemHook";
            potentialSkips[skipCount++] = "PendleUnifiedHook";
        }

        // PendlePTAmortizedOracle hooks - only enabled if oracle bytecode exists
        // Oracles are deployed via DeployV2Core and config is updated dynamically before hooks are deployed
        if (__checkBytecodeExists("PendlePTAmortizedOracle", env)) {
            availability.pendlePTAmortizedOracleHooks = true;
        } else {
            expectedHooks -= 2; // RecordPurchasePendlePTAmortizedOracleHook +
                // RecordRedemptionPendlePTAmortizedOracleHook
            potentialSkips[skipCount++] = "RecordPurchasePendlePTAmortizedOracleHook";
            potentialSkips[skipCount++] = "RecordRedemptionPendlePTAmortizedOracleHook";
        }

        if (__checkBytecodeExists("PendlePTAmortizedOracleV2", env)) {
            availability.pendlePTAmortizedOracleHooksV2 = true;
        } else {
            expectedHooks -= 2; // RecordPurchasePendlePTAmortizedOracleHookV2 +
                // RecordRedemptionPendlePTAmortizedOracleHookV2
            potentialSkips[skipCount++] = "RecordPurchasePendlePTAmortizedOracleHookV2";
            potentialSkips[skipCount++] = "RecordRedemptionPendlePTAmortizedOracleHookV2";
        }

        availability.expectedHooks = expectedHooks;

        // Create properly sized skipped contracts array
        availability.skippedContracts = new string[](skipCount);
        for (uint256 i = 0; i < skipCount; i++) {
            availability.skippedContracts[i] = potentialSkips[i];
        }

        // Check bytecode existence and collect missing contracts
        string[] memory potentialMissing = new string[](110);
        uint256 missingCount = 0;

        // Pure core contracts (9 contracts - always deployed)
        string[9] memory coreContracts = [
            "SuperExecutor",
            "SuperDestinationExecutor",
            "SuperSenderCreator",
            "SuperLedger",
            "FlatFeeLedger",
            "SuperLedgerConfiguration",
            "SuperValidator",
            "SuperDestinationValidator",
            "SuperNativePaymaster"
        ];

        for (uint256 i = 0; i < coreContracts.length; i++) {
            if (!__checkBytecodeExists(coreContracts[i], env)) {
                potentialMissing[missingCount++] = coreContracts[i];
            }
        }

        // Check adapter contracts for bytecode
        for (uint256 i = 0; i < adapterContracts.length; i++) {
            if (!__checkBytecodeExists(adapterContracts[i], env)) {
                bool alreadySkipped = false;
                for (uint256 j = 0; j < skipCount; j++) {
                    if (Strings.equal(adapterContracts[i], potentialSkips[j])) {
                        alreadySkipped = true;
                        break;
                    }
                }
                if (!alreadySkipped) {
                    potentialMissing[missingCount++] = adapterContracts[i];
                }
            }
        }

        for (uint256 i = 0; i < baseHooks.length; i++) {
            if (!__checkBytecodeExists(baseHooks[i], env)) {
                // Check if this contract was already skipped due to missing configuration
                bool alreadySkipped = false;
                for (uint256 j = 0; j < skipCount; j++) {
                    if (Strings.equal(baseHooks[i], potentialSkips[j])) {
                        alreadySkipped = true;
                        break;
                    }
                }
                // Only count as missing bytecode if it wasn't already skipped for missing config
                if (!alreadySkipped) {
                    potentialMissing[missingCount++] = baseHooks[i];
                }
            }
        }

        // Oracles (12 contracts - always check these)
        // NOTE: Order must match _deployOracles array indices for consistency
        string[18] memory oracleContracts = [
            "ERC4626YieldSourceOracle", // [0]
            "ERC5115YieldSourceOracle", // [1]
            "PendlePTYieldSourceOracle", // [2]
            "SpectraPTYieldSourceOracle", // [3]
            "StakingYieldSourceOracle", // [4]
            "SuperYieldSourceOracle", // [5]
            "SuperVaultYieldSourceOracle", // [6]
            "YoYieldSourceOracle", // [7]
            "PendlePTAmortizedOracle", // [8]
            "PendlePTAmortizedOracleV2", // [9]
            "FirelightYieldSourceOracle", // [10]
            "DETHYieldSourceOracle", // [11]
            "ERC7540YieldSourceOracle", // [12]
            "SpectraMetaVaultOracle", // [13]
            "MorphoBlueMarketRegistry", // [14]
            "MorphoBlueYieldSourceOracle", // [15]
            "UniV3CLPRegistry", // [16]
            "UniV3CLPYieldSourceOracle" // [17]
        ];

        for (uint256 i = 0; i < oracleContracts.length; i++) {
            if (!__checkBytecodeExists(oracleContracts[i], env)) {
                potentialMissing[missingCount++] = oracleContracts[i];
            }
        }

        // Create properly sized missing bytecode contracts array
        availability.missingBytecodeContracts = new string[](missingCount);
        for (uint256 i = 0; i < missingCount; i++) {
            availability.missingBytecodeContracts[i] = potentialMissing[i];
        }

        // Set expected counts from actual array lengths
        availability.expectedCore = coreContracts.length; // 9 pure core contracts
        availability.expectedOracles = oracleContracts.length; // 10 oracle contracts
            // expectedAdapters and expectedHooks already set above based on chain configuration

        // Calculate total expected contracts
        // Total = core + adapters + hooks + oracles - contracts without bytecode
        availability.expectedTotal = availability.expectedCore + availability.expectedAdapters
            + availability.expectedHooks + availability.expectedOracles;

        // Subtract contracts that don't have bytecode from the expected total
        // These contracts are defined in the system but won't be deployed
        availability.expectedTotal -= missingCount;

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

    /// @notice TEMPORARY fixed-scope entrypoint for the current token-hook upgrade.
    /// @dev Remove after the selected production deployment and post-deployment checks are complete.
    function runTemporaryTokenHookUpgrade(bool check, uint256 env, uint64 chainId) public {
        require(env == 0 || env == 2, "TEMPORARY_HOOK_UPGRADE_INVALID_ENV");
        require(block.chainid == chainId, "TEMPORARY_HOOK_UPGRADE_CHAIN_ID_MISMATCH");

        _setConfiguration(env, "");
        TemporaryTokenHookUpgrade[TEMPORARY_TOKEN_HOOK_UPGRADE_COUNT] memory hooks =
            _temporaryTokenHookUpgradePlan(chainId, env);

        uint256 availableCount;
        uint256 deployedCount;

        for (uint256 i = 0; i < hooks.length; ++i) {
            TemporaryTokenHookUpgrade memory hook = hooks[i];
            if (!hook.available) {
                console2.log("[UNAVAILABLE]", hook.name);
                continue;
            }

            (bool isDeployed, address checkedAddress) =
                __checkContract(hook.name, __getSalt(hook.saltName), hook.constructorArgs, env);
            if (checkedAddress != hook.predictedAddress) {
                revert TemporaryHookAddressMismatch(hook.name, hook.predictedAddress, checkedAddress);
            }

            hooks[i].isDeployed = isDeployed;
            availableCount++;
            if (isDeployed) deployedCount++;
        }

        _logDeploymentSummary(chainId);
        console2.log("TEMPORARY_HOOK_UPGRADE_SELECTED", TEMPORARY_TOKEN_HOOK_UPGRADE_COUNT);
        console2.log("TEMPORARY_HOOK_UPGRADE_AVAILABLE", availableCount);
        console2.log("TEMPORARY_HOOK_UPGRADE_DEPLOYED", deployedCount);
        console2.log("TEMPORARY_HOOK_UPGRADE_MISSING", availableCount - deployedCount);
        console2.log("TEMPORARY_HOOK_UPGRADE_UNAVAILABLE", TEMPORARY_TOKEN_HOOK_UPGRADE_COUNT - availableCount);
        console2.log("=====> On this chain we have", deployedCount, "contracts already deployed out of", availableCount);

        if (check) return;

        vm.startBroadcast();
        for (uint256 i = 0; i < hooks.length; ++i) {
            TemporaryTokenHookUpgrade memory hook = hooks[i];
            if (!hook.available || hook.isDeployed) continue;

            address deployedAddress =
                __deployContractIfNeeded(hook.name, chainId, __getSalt(hook.saltName), hook.initCode);
            if (deployedAddress != hook.predictedAddress) {
                revert TemporaryHookAddressMismatch(hook.name, hook.predictedAddress, deployedAddress);
            }
            require(deployedAddress.code.length > 0, "TEMPORARY_HOOK_UPGRADE_NO_CODE");
        }
        vm.stopBroadcast();

        if (vm.envOr("TEMPORARY_TOKEN_HOOK_WRITE_OUTPUT", false)) {
            _writeExportedContracts(chainId);
        }
    }

    /// @notice TEMPORARY fixed-scope entrypoint for correcting Polygon native-token hook configuration.
    /// @dev Remove after the selected production deployment and post-deployment checks are complete.
    function runTemporaryPolygonNativeHookUpgrade(bool check, uint256 env, uint64 chainId) public {
        require(env == 0, "TEMPORARY_POLYGON_NATIVE_HOOK_UPGRADE_INVALID_ENV");
        require(chainId == POLYGON_CHAIN_ID, "TEMPORARY_POLYGON_NATIVE_HOOK_UPGRADE_INVALID_CHAIN");
        require(block.chainid == chainId, "TEMPORARY_POLYGON_NATIVE_HOOK_UPGRADE_CHAIN_ID_MISMATCH");
        require(DETERMINISTIC_DEPLOYER.code.length > 0, "TEMPORARY_POLYGON_NATIVE_HOOK_UPGRADE_DEPLOYER_NO_CODE");

        _setConfiguration(env, "");
        TemporaryTokenHookUpgrade[TEMPORARY_POLYGON_NATIVE_HOOK_UPGRADE_COUNT] memory hooks =
            _temporaryPolygonNativeHookUpgradePlan(chainId, env);

        uint256 deployedCount;
        for (uint256 i = 0; i < hooks.length; ++i) {
            TemporaryTokenHookUpgrade memory hook = hooks[i];
            (bool isDeployed, address checkedAddress) =
                __checkContract(hook.name, __getSalt(hook.saltName), hook.constructorArgs, env);
            if (checkedAddress != hook.predictedAddress) {
                revert TemporaryHookAddressMismatch(hook.name, hook.predictedAddress, checkedAddress);
            }

            hooks[i].isDeployed = isDeployed;
            if (isDeployed) deployedCount++;
        }

        _logDeploymentSummary(chainId);
        console2.log("TEMPORARY_POLYGON_NATIVE_HOOK_UPGRADE_SELECTED", TEMPORARY_POLYGON_NATIVE_HOOK_UPGRADE_COUNT);
        console2.log("TEMPORARY_POLYGON_NATIVE_HOOK_UPGRADE_DEPLOYED", deployedCount);
        console2.log(
            "TEMPORARY_POLYGON_NATIVE_HOOK_UPGRADE_MISSING",
            TEMPORARY_POLYGON_NATIVE_HOOK_UPGRADE_COUNT - deployedCount
        );

        if (check) return;

        vm.startBroadcast();
        for (uint256 i = 0; i < hooks.length; ++i) {
            TemporaryTokenHookUpgrade memory hook = hooks[i];
            if (hook.isDeployed) continue;

            address deployedAddress =
                __deployContractIfNeeded(hook.name, chainId, __getSalt(hook.saltName), hook.initCode);
            if (deployedAddress != hook.predictedAddress) {
                revert TemporaryHookAddressMismatch(hook.name, hook.predictedAddress, deployedAddress);
            }
            require(deployedAddress.code.length > 0, "TEMPORARY_POLYGON_NATIVE_HOOK_UPGRADE_NO_CODE");
        }
        vm.stopBroadcast();

        if (vm.envOr("TEMPORARY_POLYGON_NATIVE_HOOK_WRITE_OUTPUT", false)) {
            _writeExportedContracts(chainId);
        }
    }

    function _temporaryPolygonNativeHookUpgradePlan(
        uint64 chainId,
        uint256 env
    )
        private
        view
        returns (TemporaryTokenHookUpgrade[TEMPORARY_POLYGON_NATIVE_HOOK_UPGRADE_COUNT] memory hooks)
    {
        string memory deploymentJson = _readCoreContractsFromOutput(chainId, env);
        _temporaryRequireManifestCode(deploymentJson, ".BatchTransferHook");
        _temporaryRequireManifestCode(deploymentJson, ".TransferHook");
        _temporaryRequireManifestCode(deploymentJson, ".Swap1InchHook");
        _temporaryRequireManifestCode(deploymentJson, ".SwapKyberSwapHook");
        _temporaryRequireManifestCode(deploymentJson, ".ApproveAndSwapKyberSwapHook");

        address nativeToken = configuration.nativeTokens[chainId];
        require(nativeToken == NATIVE_TOKEN_DEFAULT, "TEMPORARY_POLYGON_NATIVE_HOOK_UPGRADE_NATIVE_TOKEN_MISMATCH");

        address aggregationRouter = configuration.aggregationRouters[chainId];
        require(
            aggregationRouter != address(0) && aggregationRouter.code.length > 0,
            "TEMPORARY_POLYGON_NATIVE_HOOK_UPGRADE_1INCH_ROUTER_INVALID"
        );

        address kyberRouter = configuration.kyberSwapRouters[chainId];
        require(
            kyberRouter != address(0) && kyberRouter.code.length > 0,
            "TEMPORARY_POLYGON_NATIVE_HOOK_UPGRADE_KYBER_ROUTER_INVALID"
        );

        address kyberScaleHelper = configuration.kyberSwapScaleHelpers[chainId];
        require(
            kyberScaleHelper != address(0) && kyberScaleHelper.code.length > 0,
            "TEMPORARY_POLYGON_NATIVE_HOOK_UPGRADE_KYBER_SCALE_HELPER_INVALID"
        );

        hooks[0] = _temporaryTokenHookUpgrade(
            BATCH_TRANSFER_HOOK_KEY, BATCH_TRANSFER_HOOK_KEY, abi.encode(nativeToken), env, true
        );
        hooks[1] =
            _temporaryTokenHookUpgrade(TRANSFER_HOOK_KEY, TRANSFER_HOOK_KEY, abi.encode(nativeToken), env, true);
        hooks[2] = _temporaryTokenHookUpgrade(
            SWAP_1INCH_HOOK_KEY,
            SWAP_1INCH_HOOK_KEY,
            abi.encode(aggregationRouter, nativeToken),
            env,
            true
        );
        hooks[3] = _temporaryTokenHookUpgrade(
            SWAP_KYBERSWAP_HOOK_KEY,
            SWAP_KYBERSWAP_HOOK_KEY,
            abi.encode(kyberRouter, kyberScaleHelper, nativeToken),
            env,
            true
        );
        hooks[4] = _temporaryTokenHookUpgrade(
            APPROVE_AND_SWAP_KYBERSWAP_HOOK_KEY,
            APPROVE_AND_SWAP_KYBERSWAP_HOOK_KEY,
            abi.encode(kyberRouter, kyberScaleHelper, nativeToken),
            env,
            true
        );
    }

    /// @notice TEMPORARY fixed-scope entrypoint for the selected Pendle hook production upgrade.
    /// @dev Remove after the selected production deployment and post-deployment checks are complete.
    function runTemporaryPendleHookUpgrade(bool check, uint256 env, uint64 chainId) public {
        require(env == 0, "TEMPORARY_PENDLE_HOOK_UPGRADE_INVALID_ENV");
        require(block.chainid == chainId, "TEMPORARY_PENDLE_HOOK_UPGRADE_CHAIN_ID_MISMATCH");
        require(DETERMINISTIC_DEPLOYER.code.length > 0, "TEMPORARY_PENDLE_HOOK_UPGRADE_DEPLOYER_NO_CODE");

        _setConfiguration(env, "");
        TemporaryTokenHookUpgrade[TEMPORARY_PENDLE_HOOK_UPGRADE_COUNT] memory hooks =
            _temporaryPendleHookUpgradePlan(chainId, env);

        bool skipUnified = vm.envOr("TEMPORARY_PENDLE_HOOK_SKIP_UNIFIED", false);
        require(!skipUnified || chainId == 999, "TEMPORARY_PENDLE_HOOK_UPGRADE_UNIFIED_SKIP_INVALID_CHAIN");
        if (skipUnified) hooks[0].available = false;

        uint256 availableCount;
        uint256 deployedCount;

        for (uint256 i = 0; i < hooks.length; ++i) {
            TemporaryTokenHookUpgrade memory hook = hooks[i];
            if (!hook.available) {
                console2.log("[UNAVAILABLE]", hook.name);
                continue;
            }

            (bool isDeployed, address checkedAddress) =
                __checkContract(hook.name, __getSalt(hook.saltName), hook.constructorArgs, env);
            if (checkedAddress != hook.predictedAddress) {
                revert TemporaryHookAddressMismatch(hook.name, hook.predictedAddress, checkedAddress);
            }

            hooks[i].isDeployed = isDeployed;
            availableCount++;
            if (isDeployed) deployedCount++;
        }

        _logDeploymentSummary(chainId);
        console2.log("TEMPORARY_PENDLE_HOOK_UPGRADE_SELECTED", availableCount);
        console2.log("TEMPORARY_PENDLE_HOOK_UPGRADE_DEPLOYED", deployedCount);
        console2.log("TEMPORARY_PENDLE_HOOK_UPGRADE_MISSING", availableCount - deployedCount);
        console2.log("TEMPORARY_PENDLE_HOOK_UPGRADE_UNAVAILABLE", TEMPORARY_PENDLE_HOOK_UPGRADE_COUNT - availableCount);

        if (check) return;

        vm.startBroadcast();
        for (uint256 i = 0; i < hooks.length; ++i) {
            TemporaryTokenHookUpgrade memory hook = hooks[i];
            if (!hook.available || hook.isDeployed) continue;

            address deployedAddress =
                __deployContractIfNeeded(hook.name, chainId, __getSalt(hook.saltName), hook.initCode);
            if (deployedAddress != hook.predictedAddress) {
                revert TemporaryHookAddressMismatch(hook.name, hook.predictedAddress, deployedAddress);
            }
            require(deployedAddress.code.length > 0, "TEMPORARY_PENDLE_HOOK_UPGRADE_NO_CODE");
        }
        vm.stopBroadcast();

        if (vm.envOr("TEMPORARY_PENDLE_HOOK_WRITE_OUTPUT", false)) {
            _writeExportedContracts(chainId);
        }
    }

    function _temporaryPendleHookUpgradePlan(
        uint64 chainId,
        uint256 env
    )
        private
        view
        returns (TemporaryTokenHookUpgrade[TEMPORARY_PENDLE_HOOK_UPGRADE_COUNT] memory hooks)
    {
        string memory deploymentJson = _readCoreContractsFromOutput(chainId, env);

        address oracle = _safeParseJsonAddress(deploymentJson, ".PendlePTAmortizedOracle");
        require(oracle != address(0), "TEMPORARY_PENDLE_HOOK_UPGRADE_ORACLE_ZERO");
        require(oracle.code.length > 0, "TEMPORARY_PENDLE_HOOK_UPGRADE_ORACLE_NO_CODE");

        address currentPurchaseHook =
            _safeParseJsonAddress(deploymentJson, ".RecordPurchasePendlePTAmortizedOracleHook");
        address currentRedemptionHook =
            _safeParseJsonAddress(deploymentJson, ".RecordRedemptionPendlePTAmortizedOracleHook");
        _temporaryValidateAddressGetter(currentPurchaseHook, bytes4(keccak256("ORACLE()")), oracle);
        _temporaryValidateAddressGetter(currentRedemptionHook, bytes4(keccak256("ORACLE()")), oracle);

        address router = configuration.pendleRouters[chainId];
        address currentUnifiedHook = _safeParseJsonAddress(deploymentJson, ".PendleUnifiedHook");
        bool unifiedAvailable = currentUnifiedHook != address(0);
        if (unifiedAvailable) {
            require(router != address(0), "TEMPORARY_PENDLE_HOOK_UPGRADE_ROUTER_ZERO");
            require(router.code.length > 0, "TEMPORARY_PENDLE_HOOK_UPGRADE_ROUTER_NO_CODE");
            _temporaryValidateAddressGetter(currentUnifiedHook, bytes4(keccak256("PENDLE_ROUTER_V4()")), router);
        } else {
            require(router == address(0), "TEMPORARY_PENDLE_HOOK_UPGRADE_SCOPE_MISMATCH");
        }

        hooks[0] = _temporaryTokenHookUpgrade(
            PENDLE_UNIFIED_HOOK_KEY, PENDLE_UNIFIED_HOOK_KEY, abi.encode(router), env, unifiedAvailable
        );
        hooks[1] = _temporaryTokenHookUpgrade(
            RECORD_PURCHASE_PENDLE_PT_AMORTIZED_ORACLE_HOOK_KEY,
            RECORD_PURCHASE_PENDLE_PT_AMORTIZED_ORACLE_HOOK_KEY,
            abi.encode(oracle),
            env,
            true
        );
        hooks[2] = _temporaryTokenHookUpgrade(
            RECORD_REDEMPTION_PENDLE_PT_AMORTIZED_ORACLE_HOOK_KEY,
            RECORD_REDEMPTION_PENDLE_PT_AMORTIZED_ORACLE_HOOK_KEY,
            abi.encode(oracle),
            env,
            true
        );
    }

    function _temporaryValidateAddressGetter(address target, bytes4 selector, address expected) private view {
        require(target != address(0), "TEMPORARY_PENDLE_HOOK_UPGRADE_CURRENT_HOOK_ZERO");
        require(target.code.length > 0, "TEMPORARY_PENDLE_HOOK_UPGRADE_CURRENT_HOOK_NO_CODE");
        (bool success, bytes memory result) = target.staticcall(abi.encodeWithSelector(selector));
        require(success && result.length >= 32, "TEMPORARY_PENDLE_HOOK_UPGRADE_GETTER_FAILED");
        require(abi.decode(result, (address)) == expected, "TEMPORARY_PENDLE_HOOK_UPGRADE_DEPENDENCY_MISMATCH");
    }

    /// @notice TEMPORARY fixed-scope entrypoint for the selected ERC-7540 hook production upgrade.
    /// @dev Remove after the selected production deployment and post-deployment checks are complete.
    function runTemporary7540HookUpgrade(bool check, uint256 env, uint64 chainId) public {
        require(env == 0, "TEMPORARY_7540_HOOK_UPGRADE_INVALID_ENV");
        require(block.chainid == chainId, "TEMPORARY_7540_HOOK_UPGRADE_CHAIN_ID_MISMATCH");
        require(DETERMINISTIC_DEPLOYER.code.length > 0, "TEMPORARY_7540_HOOK_UPGRADE_DEPLOYER_NO_CODE");

        _setConfiguration(env, "");
        TemporaryTokenHookUpgrade[TEMPORARY_7540_HOOK_UPGRADE_COUNT] memory hooks =
            _temporary7540HookUpgradePlan(chainId, env);

        uint256 deployedCount;

        for (uint256 i = 0; i < hooks.length; ++i) {
            TemporaryTokenHookUpgrade memory hook = hooks[i];
            (bool isDeployed, address checkedAddress) =
                __checkContract(hook.name, __getSalt(hook.saltName), hook.constructorArgs, env);
            if (checkedAddress != hook.predictedAddress) {
                revert TemporaryHookAddressMismatch(hook.name, hook.predictedAddress, checkedAddress);
            }

            hooks[i].isDeployed = isDeployed;
            if (isDeployed) deployedCount++;
        }

        _logDeploymentSummary(chainId);
        console2.log("TEMPORARY_7540_HOOK_UPGRADE_SELECTED", TEMPORARY_7540_HOOK_UPGRADE_COUNT);
        console2.log("TEMPORARY_7540_HOOK_UPGRADE_DEPLOYED", deployedCount);
        console2.log("TEMPORARY_7540_HOOK_UPGRADE_MISSING", TEMPORARY_7540_HOOK_UPGRADE_COUNT - deployedCount);

        if (check) return;

        vm.startBroadcast();
        for (uint256 i = 0; i < hooks.length; ++i) {
            TemporaryTokenHookUpgrade memory hook = hooks[i];
            if (hook.isDeployed) continue;

            address deployedAddress =
                __deployContractIfNeeded(hook.name, chainId, __getSalt(hook.saltName), hook.initCode);
            if (deployedAddress != hook.predictedAddress) {
                revert TemporaryHookAddressMismatch(hook.name, hook.predictedAddress, deployedAddress);
            }
            require(deployedAddress.code.length > 0, "TEMPORARY_7540_HOOK_UPGRADE_NO_CODE");
        }
        vm.stopBroadcast();

        if (vm.envOr("TEMPORARY_7540_HOOK_WRITE_OUTPUT", false)) {
            _writeExportedContracts(chainId);
        }
    }

    function _temporary7540HookUpgradePlan(
        uint64 chainId,
        uint256 env
    )
        private
        view
        returns (TemporaryTokenHookUpgrade[TEMPORARY_7540_HOOK_UPGRADE_COUNT] memory hooks)
    {
        string memory deploymentJson = _readCoreContractsFromOutput(chainId, env);

        _temporaryRequireManifestCode(deploymentJson, ".CancelDepositRequest7540Hook");
        _temporaryRequireManifestCode(deploymentJson, ".CancelRedeemRequest7540Hook");
        _temporaryRequireManifestCode(deploymentJson, ".ClaimCancelDepositRequest7540Hook");
        _temporaryRequireManifestCode(deploymentJson, ".ClaimCancelRedeemRequest7540Hook");
        _temporaryRequireManifestCode(deploymentJson, ".Redeem7540VaultHook");
        _temporaryRequireManifestCode(deploymentJson, ".Withdraw7540VaultHook");
        _temporaryRequireManifestCode(deploymentJson, ".SetSlippageHook");

        hooks[0] = _temporaryTokenHookUpgrade(
            CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY, CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY, "", env, true
        );
        hooks[1] = _temporaryTokenHookUpgrade(
            CANCEL_REDEEM_REQUEST_7540_HOOK_KEY, CANCEL_REDEEM_REQUEST_7540_HOOK_KEY, "", env, true
        );
        hooks[2] = _temporaryTokenHookUpgrade(
            CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY,
            CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY,
            "",
            env,
            true
        );
        hooks[3] = _temporaryTokenHookUpgrade(
            CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY,
            CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY,
            "",
            env,
            true
        );
        hooks[4] = _temporaryTokenHookUpgrade(REDEEM_7540_VAULT_HOOK_KEY, REDEEM_7540_VAULT_HOOK_KEY, "", env, true);
        hooks[5] =
            _temporaryTokenHookUpgrade(WITHDRAW_7540_VAULT_HOOK_KEY, WITHDRAW_7540_VAULT_HOOK_KEY, "", env, true);
        hooks[6] = _temporaryTokenHookUpgrade(SET_SLIPPAGE_HOOK_KEY, SET_SLIPPAGE_HOOK_KEY, "", env, true);
    }

    function _temporaryRequireManifestCode(string memory deploymentJson, string memory key) private view {
        address currentHook = _safeParseJsonAddress(deploymentJson, key);
        require(currentHook != address(0), "TEMPORARY_7540_HOOK_UPGRADE_CURRENT_HOOK_ZERO");
        require(currentHook.code.length > 0, "TEMPORARY_7540_HOOK_UPGRADE_CURRENT_HOOK_NO_CODE");
    }

    function _temporaryTokenHookUpgradePlan(
        uint64 chainId,
        uint256 env
    )
        private
        view
        returns (TemporaryTokenHookUpgrade[TEMPORARY_TOKEN_HOOK_UPGRADE_COUNT] memory hooks)
    {
        address nativeToken = configuration.nativeTokens[chainId];
        require(nativeToken != address(0), "TEMPORARY_HOOK_UPGRADE_NATIVE_TOKEN_ZERO");

        address permit2 = configuration.permit2s[chainId];
        require(permit2 != address(0), "TEMPORARY_HOOK_UPGRADE_PERMIT2_ZERO");
        require(permit2.code.length > 0, "TEMPORARY_HOOK_UPGRADE_PERMIT2_NO_CODE");

        address merklDistributor = configuration.merklDistributors[chainId];
        if (merklDistributor != address(0)) {
            require(merklDistributor.code.length > 0, "TEMPORARY_HOOK_UPGRADE_MERKL_NO_CODE");
        }

        hooks[0] = _temporaryTokenHookUpgrade(APPROVE_ERC20_HOOK_KEY, APPROVE_ERC20_HOOK_KEY, "", env, true);
        hooks[1] = _temporaryTokenHookUpgrade(TRANSFER_ERC20_HOOK_KEY, TRANSFER_ERC20_HOOK_KEY, "", env, true);
        hooks[2] = _temporaryTokenHookUpgrade(
            BATCH_TRANSFER_HOOK_KEY, BATCH_TRANSFER_HOOK_KEY, abi.encode(nativeToken), env, true
        );
        hooks[3] = _temporaryTokenHookUpgrade(
            BATCH_TRANSFER_FROM_HOOK_KEY, BATCH_TRANSFER_FROM_HOOK_KEY, abi.encode(permit2), env, true
        );
        hooks[4] = _temporaryTokenHookUpgrade(TRANSFER_HOOK_KEY, TRANSFER_HOOK_KEY, abi.encode(nativeToken), env, true);
        hooks[5] = _temporaryTokenHookUpgrade(
            MERKL_CLAIM_REWARD_HOOK_KEY,
            MERKL_CLAIM_REWARD_HOOK_SALT,
            merklDistributor == address(0) ? bytes("") : abi.encode(merklDistributor),
            env,
            merklDistributor != address(0)
        );
        hooks[6] = _temporaryTokenHookUpgrade(OFFRAMP_TOKENS_HOOK_KEY, OFFRAMP_TOKENS_HOOK_KEY, "", env, true);
    }

    function _temporaryTokenHookUpgrade(
        string memory name,
        string memory saltName,
        bytes memory constructorArgs,
        uint256 env,
        bool available
    )
        private
        view
        returns (TemporaryTokenHookUpgrade memory hook)
    {
        bytes memory lockedBytecode = _temporaryValidatedHookBytecode(name, env);
        bytes memory initCode = abi.encodePacked(lockedBytecode, constructorArgs);
        bytes32 salt = __getSalt(saltName);
        address predictedAddress = DeterministicDeployerLib.computeAddress(initCode, salt);

        console2.log("TEMPORARY_HOOK", name);
        console2.log("  saltName", saltName);
        console2.log("  saltNamespace", string(saltNamespace));
        console2.log("  bareCreationCodeHash");
        console2.logBytes32(keccak256(lockedBytecode));
        console2.log("  constructorArgsHash");
        console2.logBytes32(keccak256(constructorArgs));
        console2.log("  initCodeHash");
        console2.logBytes32(keccak256(initCode));
        console2.log("  predictedAddress", predictedAddress);

        hook = TemporaryTokenHookUpgrade({
            name: name,
            saltName: saltName,
            constructorArgs: constructorArgs,
            initCode: initCode,
            predictedAddress: predictedAddress,
            available: available,
            isDeployed: false
        });
    }

    function _temporaryValidatedHookBytecode(
        string memory name,
        uint256 env
    )
        private
        view
        returns (bytes memory lockedBytecode)
    {
        string memory freshPath = string.concat("out/", name, ".sol/", name, ".json");
        string memory generatedPath = string.concat("script/generated-bytecode/", name, ".json");
        string memory lockedPath = __getBytecodeArtifactPath(name, env);

        bytes memory freshBytecode = _temporaryRequiredArtifactBytecode(freshPath);
        bytes memory generatedBytecode = _temporaryRequiredArtifactBytecode(generatedPath);
        lockedBytecode = _temporaryRequiredArtifactBytecode(lockedPath);

        bytes32 freshHash = keccak256(freshBytecode);
        if (freshHash != keccak256(generatedBytecode)) {
            revert TemporaryHookBytecodeMismatch(name, "generated-bytecode");
        }
        if (freshHash != keccak256(lockedBytecode)) {
            revert TemporaryHookBytecodeMismatch(name, env == 0 ? "locked-bytecode" : "locked-bytecode-dev");
        }
    }

    function _temporaryRequiredArtifactBytecode(string memory path) private view returns (bytes memory bytecode) {
        if (!vm.exists(path)) revert TemporaryHookArtifactMissing(path);
        bytecode = vm.getCode(path);
        if (bytecode.length == 0) revert TemporaryHookBytecodeEmpty(path);
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

    /// @notice Public function to configure ONLY SuperVaultYieldSourceOracle after initial deployment
    /// @dev Use this when other oracles are already configured and you only need to add SuperVaultYieldSourceOracle
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainId Target chain ID
    function runSuperVaultOracleConfiguration(uint256 env, uint64 chainId) public {
        runSuperVaultOracleConfiguration(env, chainId, "");
    }

    /// @notice Public function to configure ONLY SuperVaultYieldSourceOracle with branch name
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param chainId Target chain ID
    /// @param branchName Branch name for env=1 (VNET) to read contracts from specific branch folder
    function runSuperVaultOracleConfiguration(
        uint256 env,
        uint64 chainId,
        string memory branchName
    )
        public
        broadcast(env)
    {
        console2.log("====== SUPERVAULT ORACLE CONFIGURATION ======");
        console2.log("Environment:", env == 0 ? "Production" : (env == 1 ? "VNET" : "Staging"));
        console2.log("Chain ID:", chainId);
        console2.log("");

        // Set configuration
        _setConfiguration(env, "");

        // Read deployment JSON
        string memory deploymentJson = _readCoreContractsFromOutput(chainId, env, branchName);

        address superLedgerConfig = vm.parseJsonAddress(deploymentJson, ".SuperLedgerConfiguration");
        address superVaultOracle = _safeParseJsonAddress(deploymentJson, ".SuperVaultYieldSourceOracle");
        address superLedger = vm.parseJsonAddress(deploymentJson, ".SuperLedger");

        require(superLedgerConfig != address(0), "SUPER_LEDGER_CONFIG_ZERO");
        require(superVaultOracle != address(0), "SUPER_VAULT_ORACLE_ZERO");
        require(superVaultOracle.code.length > 0, "SUPER_VAULT_ORACLE_NO_CODE");
        require(superLedger != address(0), "SUPER_LEDGER_ZERO");
        require(configuration.treasury != address(0), "TREASURY_ZERO");

        console2.log("  SuperLedgerConfiguration:", superLedgerConfig);
        console2.log("  SuperVaultYieldSourceOracle:", superVaultOracle);
        console2.log("  SuperLedger:", superLedger);
        console2.log("  Treasury:", configuration.treasury);

        // Configure only SuperVaultYieldSourceOracle
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);

        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: superVaultOracle,
            feePercent: 0,
            feeRecipient: configuration.treasury,
            ledger: superLedger
        });

        bytes32[] memory salts = new bytes32[](1);
        salts[0] = bytes32(bytes(SUPERVAULT_YIELD_SOURCE_ORACLE_SALT));

        console2.log("  Configuring SuperVaultYieldSourceOracle...");
        ISuperLedgerConfiguration(superLedgerConfig).setYieldSourceOracles(salts, configs);

        console2.log("====== SUPERVAULT ORACLE CONFIGURATION COMPLETED ======");
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
        ContractAvailability memory availability = _getContractAvailability(chainId, env);
        _validateAerodromeUniversalRouter(chainId, availability);

        // Log availability analysis
        console2.log("=== Contract Availability Analysis ===");
        console2.log("Expected total contracts:", availability.expectedTotal);
        console2.log("  Core contracts:", availability.expectedCore);
        console2.log("  Adapters:", availability.expectedAdapters);
        console2.log("  Hooks:", availability.expectedHooks);
        console2.log("  Oracles:", availability.expectedOracles);

        if (availability.skippedContracts.length > 0) {
            console2.log("");
            console2.log("=== Contracts SKIPPED due to missing configurations ===");
            for (uint256 i = 0; i < availability.skippedContracts.length; i++) {
                console2.log("  SKIPPED:", availability.skippedContracts[i]);
            }
        }

        if (availability.missingBytecodeContracts.length > 0) {
            console2.log("");
            console2.log("=== Contracts SKIPPED due to missing bytecode ===");
            for (uint256 i = 0; i < availability.missingBytecodeContracts.length; i++) {
                console2.log("  MISSING BYTECODE:", availability.missingBytecodeContracts[i]);
            }
        }
        console2.log("");

        // Reset counters
        deployed = 0;
        total = 0;

        _checkCoreContracts(chainId, env, availability);

        // Log comprehensive deployment summary and get deployed count
        _logDeploymentSummary(chainId);

        // Count deployed contracts from the status tracking (use actual checked count, not expected)
        deployed = _countDeployedContracts(chainId);

        // Use actual total from allContractNames instead of expectedTotal to ensure accuracy
        string[] memory checkedContracts = _getAllContractNames(chainId);
        total = checkedContracts.length;

        // Write the exported contracts JSON so the output file stays in sync
        // even when no new deployment is needed (all contracts already on-chain)
        _writeExportedContracts(chainId);

        // ===== SUMMARY =====
        console2.log("");
        console2.log("=====> On this chain we have", deployed, "contracts already deployed out of", total);
        console2.log("======================================");
    }

    function _validateAerodromeUniversalRouter(
        uint64 chainId,
        ContractAvailability memory availability
    )
        internal
        view
    {
        if (!availability.swapAerodromeUniversalRouterHooks) {
            console2.log(" SKIPPED Aerodrome Universal Router validation: Not available on chain", chainId);
            return;
        }

        address aerodromeRouter = configuration.aerodromeUniversalRouters[chainId];
        require(chainId == BASE_CHAIN_ID, "AERODROME_ROUTER_UNSUPPORTED_CHAIN");
        require(aerodromeRouter == AERODROME_UNIVERSAL_ROUTER_BASE, "AERODROME_ROUTER_ADDRESS_MISMATCH");
        require(aerodromeRouter.code.length > 0, "AERODROME_ROUTER_NOT_DEPLOYED");
        require(
            aerodromeRouter.codehash == AERODROME_UNIVERSAL_ROUTER_BASE_RUNTIME_HASH,
            "AERODROME_ROUTER_RUNTIME_HASH_MISMATCH"
        );

        (bool wethSuccess, bytes memory wethData) = aerodromeRouter.staticcall(abi.encodeWithSignature("WETH9()"));
        require(
            wethSuccess && wethData.length == 32
                && abi.decode(wethData, (address)) == AERODROME_UNIVERSAL_ROUTER_BASE_WETH,
            "AERODROME_ROUTER_WETH_MISMATCH"
        );
        (bool permit2Success, bytes memory permit2Data) =
            aerodromeRouter.staticcall(abi.encodeWithSignature("PERMIT2()"));
        require(
            permit2Success && permit2Data.length == 32
                && abi.decode(permit2Data, (address)) == AERODROME_UNIVERSAL_ROUTER_BASE_PERMIT2,
            "AERODROME_ROUTER_PERMIT2_MISMATCH"
        );
        console2.log(" Aerodrome Universal Router:", aerodromeRouter);
    }

    /// @notice Check core contract addresses
    /// @param chainId The target chain ID
    /// @param env Environment (1 = vnet/dev, 0/2 = prod/staging)
    /// @param availability Contract availability for this chain
    function _checkCoreContracts(
        uint64 chainId,
        uint256 env,
        ContractAvailability memory availability
    )
        internal
    {
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

        // StargateAdapter (requires lzEndpointV2, tokenMessaging, and superDestinationExecutor)
        if (availability.stargateAdapter && superDestExecutor != address(0)) {
            __checkContract(
                STARGATE_ADAPTER_KEY,
                __getSalt(STARGATE_ADAPTER_KEY),
                abi.encode(
                    configuration.lzEndpointV2s[chainId],
                    configuration.stargateTokenMessagings[chainId],
                    superDestExecutor
                ),
                env
            );
        } else if (!availability.stargateAdapter) {
            console2.log("SKIPPED StargateAdapter: LZ EndpointV2 or TokenMessaging not configured for chain", chainId);
        } else {
            revert("STARGATE_ADAPTER_CHECK_FAILED_MISSING_SUPER_DEST_EXECUTOR");
        }

        // StargateAdapterV2 (same dependencies as V1)
        if (availability.stargateAdapterV2 && superDestExecutor != address(0)) {
            __checkContract(
                STARGATE_ADAPTER_V2_KEY,
                __getSalt(STARGATE_ADAPTER_V2_KEY),
                abi.encode(
                    configuration.lzEndpointV2s[chainId],
                    configuration.stargateTokenMessagings[chainId],
                    superDestExecutor,
                    configuration.stargateAllowedOFTs[chainId]
                ),
                env
            );
        } else if (!availability.stargateAdapterV2) {
            console2.log("SKIPPED StargateAdapterV2: LZ EndpointV2 or TokenMessaging not configured for chain", chainId);
        } else {
            revert("STARGATE_ADAPTER_V2_CHECK_FAILED_MISSING_SUPER_DEST_EXECUTOR");
        }

        // AcrossV3AdapterV2 (compact 2-field message format)
        if (availability.acrossV3AdapterV2 && superDestExecutor != address(0)) {
            __checkContract(
                ACROSS_V3_ADAPTER_V2_KEY,
                __getSalt(ACROSS_V3_ADAPTER_V2_KEY),
                abi.encode(configuration.acrossSpokePoolV3s[chainId], superDestExecutor),
                env
            );
        } else if (!availability.acrossV3AdapterV2) {
            console2.log("SKIPPED AcrossV3AdapterV2: Across Spoke Pool not configured for chain", chainId);
        } else {
            revert("ACROSS_V3_ADAPTER_V2_CHECK_FAILED_MISSING_SUPER_DEST_EXECUTOR");
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
        if (availability.batchTransferFromHook) {
            __checkContract(
                BATCH_TRANSFER_FROM_HOOK_KEY,
                __getSalt(BATCH_TRANSFER_FROM_HOOK_KEY),
                abi.encode(configuration.permit2s[chainId]),
                env
            );
        } else {
            console2.log("SKIPPED BatchTransferFromHook: Permit2 not configured for chain", chainId);
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
        __checkContract(SET_OPERATOR_7540_HOOK_KEY, __getSalt(SET_OPERATOR_7540_HOOK_KEY), "", env);
        __checkContract(SET_SLIPPAGE_HOOK_KEY, __getSalt(SET_SLIPPAGE_HOOK_KEY), "", env);
        __checkContract(CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY, __getSalt(CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY), "", env);
        __checkContract(CANCEL_REDEEM_REQUEST_7540_HOOK_KEY, __getSalt(CANCEL_REDEEM_REQUEST_7540_HOOK_KEY), "", env);
        __checkContract(
            CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY, __getSalt(CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY), "", env
        );
        __checkContract(
            CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY, __getSalt(CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY), "", env
        );

        // 7540 WithId hooks
        __checkContract(
            CANCEL_DEPOSIT_REQUEST_WITH_ID_7540_HOOK_KEY,
            __getSalt(CANCEL_DEPOSIT_REQUEST_WITH_ID_7540_HOOK_KEY),
            "",
            env
        );
        __checkContract(
            CANCEL_REDEEM_REQUEST_WITH_ID_7540_HOOK_KEY, __getSalt(CANCEL_REDEEM_REQUEST_WITH_ID_7540_HOOK_KEY), "", env
        );
        __checkContract(
            CLAIM_CANCEL_DEPOSIT_REQUEST_WITH_ID_7540_HOOK_KEY,
            __getSalt(CLAIM_CANCEL_DEPOSIT_REQUEST_WITH_ID_7540_HOOK_KEY),
            "",
            env
        );
        __checkContract(
            CLAIM_CANCEL_REDEEM_REQUEST_WITH_ID_7540_HOOK_KEY,
            __getSalt(CLAIM_CANCEL_REDEEM_REQUEST_WITH_ID_7540_HOOK_KEY),
            "",
            env
        );
        __checkContract(REDEEM_WITH_ID_7540_VAULT_HOOK_KEY, __getSalt(REDEEM_WITH_ID_7540_VAULT_HOOK_KEY), "", env);
        __checkContract(WITHDRAW_WITH_ID_7540_VAULT_HOOK_KEY, __getSalt(WITHDRAW_WITH_ID_7540_VAULT_HOOK_KEY), "", env);

        // Swap hooks with router dependencies
        if (availability.swap1InchHook) {
            __checkContract(
                SWAP_1INCH_HOOK_KEY,
                __getSalt(SWAP_1INCH_HOOK_KEY),
                abi.encode(configuration.aggregationRouters[chainId], configuration.nativeTokens[chainId]),
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

        if (availability.swapOdosV3Hooks) {
            __checkContract(
                SWAP_ODOSV3_HOOK_KEY,
                __getSalt(SWAP_ODOSV3_HOOK_KEY),
                abi.encode(configuration.odosRouterV3s[chainId]),
                env
            );
            __checkContract(
                APPROVE_AND_SWAP_ODOSV3_HOOK_KEY,
                __getSalt(APPROVE_AND_SWAP_ODOSV3_HOOK_KEY),
                abi.encode(configuration.odosRouterV3s[chainId]),
                env
            );
        } else {
            console2.log(
                "SKIPPED SwapOdosV3Hook & ApproveAndSwapOdosV3Hook: ODOS V3 Router not configured for chain", chainId
            );
        }

        if (availability.swapAerodromeUniversalRouterHooks) {
            __checkContract(
                SWAP_AERODROME_UNIVERSAL_ROUTER_HOOK_KEY,
                __getSalt(SWAP_AERODROME_UNIVERSAL_ROUTER_HOOK_KEY),
                abi.encode(configuration.aerodromeUniversalRouters[chainId]),
                env
            );
            __checkContract(
                APPROVE_AND_SWAP_AERODROME_UNIVERSAL_ROUTER_HOOK_KEY,
                __getSalt(APPROVE_AND_SWAP_AERODROME_UNIVERSAL_ROUTER_HOOK_KEY),
                abi.encode(configuration.aerodromeUniversalRouters[chainId]),
                env
            );
        } else {
            console2.log("SKIPPED Aerodrome Universal Router hooks: Router not configured for chain", chainId);
        }

        if (availability.swapKyberSwapHooks) {
            __checkContract(
                SWAP_KYBERSWAP_HOOK_KEY,
                __getSalt(SWAP_KYBERSWAP_HOOK_KEY),
                abi.encode(
                    configuration.kyberSwapRouters[chainId],
                    configuration.kyberSwapScaleHelpers[chainId],
                    configuration.nativeTokens[chainId]
                ),
                env
            );
            __checkContract(
                APPROVE_AND_SWAP_KYBERSWAP_HOOK_KEY,
                __getSalt(APPROVE_AND_SWAP_KYBERSWAP_HOOK_KEY),
                abi.encode(
                    configuration.kyberSwapRouters[chainId],
                    configuration.kyberSwapScaleHelpers[chainId],
                    configuration.nativeTokens[chainId]
                ),
                env
            );
        } else {
            console2.log(
                "SKIPPED SwapKyberSwapHook & ApproveAndSwapKyberSwapHook: KyberSwap Router not configured for chain",
                chainId
            );
        }

        if (availability.swapOpenOceanHooks) {
            __checkContract(
                SWAP_OPENOCEAN_HOOK_KEY,
                __getSalt(SWAP_OPENOCEAN_HOOK_KEY),
                abi.encode(
                    configuration.openOceanRouters[chainId],
                    configuration.openOceanReferrers[chainId],
                    configuration.nativeTokens[chainId]
                ),
                env
            );
            __checkContract(
                APPROVE_AND_SWAP_OPENOCEAN_HOOK_KEY,
                __getSalt(APPROVE_AND_SWAP_OPENOCEAN_HOOK_KEY),
                abi.encode(
                    configuration.openOceanRouters[chainId],
                    configuration.openOceanReferrers[chainId],
                    configuration.nativeTokens[chainId]
                ),
                env
            );
        } else {
            console2.log("SKIPPED OpenOcean hooks: OpenOcean Router/Referrer not configured for chain", chainId);
        }

        if (availability.swapUniswapV2Hooks) {
            __checkContract(
                SWAP_UNISWAPV2_HOOK_KEY,
                __getSalt(SWAP_UNISWAPV2_HOOK_KEY),
                abi.encode(configuration.uniswapV2SwapRouters[chainId], configuration.nativeTokens[chainId]),
                env
            );
            __checkContract(
                APPROVE_AND_SWAP_UNISWAPV2_HOOK_KEY,
                __getSalt(APPROVE_AND_SWAP_UNISWAPV2_HOOK_KEY),
                abi.encode(configuration.uniswapV2SwapRouters[chainId], configuration.nativeTokens[chainId]),
                env
            );
        } else {
            console2.log(
                "SKIPPED SwapUniswapV2Hook & ApproveAndSwapUniswapV2Hook: V2 Router not configured for chain", chainId
            );
        }

        if (availability.pendleRouterHooks) {
            __checkContract(
                PENDLE_ROUTER_SWAP_HOOK_KEY,
                __getSalt(PENDLE_ROUTER_SWAP_HOOK_KEY),
                abi.encode(configuration.pendleRouters[chainId]),
                env
            );
            __checkContract(
                PENDLE_ROUTER_REDEEM_HOOK_KEY,
                __getSalt(PENDLE_ROUTER_REDEEM_HOOK_KEY),
                abi.encode(configuration.pendleRouters[chainId]),
                env
            );
            __checkContract(
                PENDLE_UNIFIED_HOOK_KEY,
                __getSalt(PENDLE_UNIFIED_HOOK_KEY),
                abi.encode(configuration.pendleRouters[chainId]),
                env
            );
        } else {
            console2.log(
                "SKIPPED PendleRouterSwapHook, PendleRouterRedeemHook & PendleUnifiedHook: Pendle Router not configured for chain",
                chainId
            );
        }

        // Pendle PT Amortized Oracle hooks (V1)
        // NOTE: Hook check requires oracle address in config. In check mode before deployment,
        // oracle config is address(0), so we skip hook check (hooks will be deployed after oracles).
        if (availability.pendlePTAmortizedOracleHooks && configuration.pendlePTAmortizedOracles[chainId] != address(0))
        {
            __checkContract(
                RECORD_PURCHASE_PENDLE_PT_AMORTIZED_ORACLE_HOOK_KEY,
                __getSalt(RECORD_PURCHASE_PENDLE_PT_AMORTIZED_ORACLE_HOOK_KEY),
                abi.encode(configuration.pendlePTAmortizedOracles[chainId]),
                env
            );
            __checkContract(
                RECORD_REDEMPTION_PENDLE_PT_AMORTIZED_ORACLE_HOOK_KEY,
                __getSalt(RECORD_REDEMPTION_PENDLE_PT_AMORTIZED_ORACLE_HOOK_KEY),
                abi.encode(configuration.pendlePTAmortizedOracles[chainId]),
                env
            );
        } else if (!availability.pendlePTAmortizedOracleHooks) {
            console2.log(
                "SKIPPED RecordPurchase & RecordRedemption PendlePTAmortizedOracle Hooks (V1): Oracle bytecode not available",
                chainId
            );
        } else {
            console2.log(
                "SKIPPED RecordPurchase & RecordRedemption PendlePTAmortizedOracle Hooks (V1) check: Oracle not yet deployed for chain",
                chainId
            );
        }

        // Pendle PT Amortized Oracle hooks (V2)
        // NOTE: Same as V1 - hook check requires oracle address in config.
        if (
            availability.pendlePTAmortizedOracleHooksV2
                && configuration.pendlePTAmortizedOraclesV2[chainId] != address(0)
        ) {
            __checkContract(
                RECORD_PURCHASE_PENDLE_PT_AMORTIZED_ORACLE_HOOK_V2_KEY,
                __getSalt(RECORD_PURCHASE_PENDLE_PT_AMORTIZED_ORACLE_HOOK_V2_KEY),
                abi.encode(configuration.pendlePTAmortizedOraclesV2[chainId]),
                env
            );
            __checkContract(
                RECORD_REDEMPTION_PENDLE_PT_AMORTIZED_ORACLE_HOOK_V2_KEY,
                __getSalt(RECORD_REDEMPTION_PENDLE_PT_AMORTIZED_ORACLE_HOOK_V2_KEY),
                abi.encode(configuration.pendlePTAmortizedOraclesV2[chainId]),
                env
            );
        } else if (!availability.pendlePTAmortizedOracleHooksV2) {
            console2.log(
                "SKIPPED RecordPurchase & RecordRedemption PendlePTAmortizedOracle Hooks (V2): Oracle V2 bytecode not available",
                chainId
            );
        } else {
            console2.log(
                "SKIPPED RecordPurchase & RecordRedemption PendlePTAmortizedOracle Hooks (V2) check: Oracle V2 not yet deployed for chain",
                chainId
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

        if (availability.acrossV3Adapter && superValidator != address(0)) {
            __checkContract(
                APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY,
                __getSalt(APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY),
                abi.encode(configuration.acrossSpokePoolV3s[chainId], superValidator),
                env
            );
        } else if (!availability.acrossV3Adapter) {
            console2.log(
                "SKIPPED ApproveAndAcrossSendFundsAndExecuteOnDstHook: Across Spoke Pool not configured for chain",
                chainId
            );
        } else {
            revert("APPROVE_AND_ACROSS_HOOK_CHECK_FAILED_MISSING_SUPER_VALIDATOR");
        }

        // Across Bridge Hooks V2 (compact 2-field message format — paired with AcrossV3AdapterV2)
        if (availability.acrossV3AdapterV2 && superValidator != address(0)) {
            __checkContract(
                ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_V2_KEY,
                __getSalt(ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_V2_KEY),
                abi.encode(configuration.acrossSpokePoolV3s[chainId], superValidator),
                env
            );
            __checkContract(
                APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_V2_KEY,
                __getSalt(APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_V2_KEY),
                abi.encode(configuration.acrossSpokePoolV3s[chainId], superValidator),
                env
            );
        } else if (!availability.acrossV3AdapterV2) {
            console2.log(
                "SKIPPED AcrossSendFundsAndExecuteOnDstHookV2 + ApproveAnd: Across Spoke Pool not configured for chain",
                chainId
            );
        } else {
            revert("ACROSS_HOOK_V2_CHECK_FAILED_MISSING_SUPER_VALIDATOR");
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

        // Stargate bridge hooks (V1 + V2)
        if (superValidator != address(0)) {
            __checkContract(STARGATE_SEND_HOOK_KEY, __getSalt(STARGATE_SEND_HOOK_KEY), abi.encode(superValidator), env);
            __checkContract(
                APPROVE_AND_STARGATE_SEND_HOOK_KEY,
                __getSalt(APPROVE_AND_STARGATE_SEND_HOOK_KEY),
                abi.encode(superValidator),
                env
            );
            __checkContract(
                STARGATE_SEND_HOOK_V2_KEY, __getSalt(STARGATE_SEND_HOOK_V2_KEY), abi.encode(superValidator), env
            );
            __checkContract(
                APPROVE_AND_STARGATE_SEND_HOOK_V2_KEY,
                __getSalt(APPROVE_AND_STARGATE_SEND_HOOK_V2_KEY),
                abi.encode(superValidator),
                env
            );
        } else {
            revert("STARGATE_HOOK_CHECK_FAILED_MISSING_SUPER_VALIDATOR");
        }

        // ClaimFailedTransferHook — no constructor args
        __checkContract(CLAIM_FAILED_TRANSFER_HOOK_KEY, __getSalt(CLAIM_FAILED_TRANSFER_HOOK_KEY), "", env);

        // CCTP V2 bridge hooks
        if (superValidator != address(0)) {
            __checkContract(
                CCTP_SEND_HOOK_KEY,
                __getSalt(CCTP_SEND_HOOK_KEY),
                abi.encode(CCTP_V2_TOKEN_MESSENGER, superValidator),
                env
            );
            __checkContract(
                APPROVE_AND_CCTP_SEND_HOOK_KEY,
                __getSalt(APPROVE_AND_CCTP_SEND_HOOK_KEY),
                abi.encode(CCTP_V2_TOKEN_MESSENGER, superValidator),
                env
            );
        } else {
            revert("CCTP_HOOK_CHECK_FAILED_MISSING_SUPER_VALIDATOR");
        }

        // Merkl claim reward hook
        if (availability.merklClaimRewardHook) {
            __checkContract(
                MERKL_CLAIM_REWARD_HOOK_KEY,
                __getSalt(MERKL_CLAIM_REWARD_HOOK_SALT), // Use custom salt for new deployment
                abi.encode(configuration.merklDistributors[chainId]),
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

        // UniswapV4 swap hook
        if (availability.swapUniswapV4Hook) {
            __checkContract(
                SWAP_UNISWAPV4_HOOK_KEY,
                __getSalt(SWAP_UNISWAPV4_HOOK_KEY),
                abi.encode(configuration.uniswapV4PoolManagers[chainId]),
                env
            );
        } else {
            console2.log("SKIPPED SwapUniswapV4Hook: Uniswap V4 PoolManager not configured for chain", chainId);
        }

        // UniswapV3 swap hooks
        if (availability.swapUniswapV3Hooks) {
            __checkContract(
                SWAP_UNISWAPV3_HOOK_KEY,
                __getSalt(SWAP_UNISWAPV3_HOOK_KEY),
                abi.encode(configuration.uniswapV3SwapRouters[chainId]),
                env
            );
            __checkContract(
                APPROVE_AND_SWAP_UNISWAPV3_HOOK_KEY,
                __getSalt(APPROVE_AND_SWAP_UNISWAPV3_HOOK_KEY),
                abi.encode(configuration.uniswapV3SwapRouters[chainId]),
                env
            );
        } else {
            console2.log("SKIPPED SwapUniswapV3Hook: Uniswap V3 SwapRouter not configured for chain", chainId);
            console2.log("SKIPPED ApproveAndSwapUniswapV3Hook: Uniswap V3 SwapRouter not configured for chain", chainId);
        }

        // UniswapV3 SwapRouter02 swap hooks
        if (availability.swapUniswapV3Router02Hooks) {
            __checkContract(
                SWAP_UNISWAPV3_ROUTER02_HOOK_KEY,
                __getSalt(SWAP_UNISWAPV3_ROUTER02_HOOK_KEY),
                abi.encode(configuration.uniswapV3SwapRouter02s[chainId]),
                env
            );
            __checkContract(
                APPROVE_AND_SWAP_UNISWAPV3_ROUTER02_HOOK_KEY,
                __getSalt(APPROVE_AND_SWAP_UNISWAPV3_ROUTER02_HOOK_KEY),
                abi.encode(configuration.uniswapV3SwapRouter02s[chainId]),
                env
            );
        } else {
            console2.log("SKIPPED SwapUniswapV3Router02Hook: Uniswap V3 SwapRouter02 not configured for chain", chainId);
            console2.log(
                "SKIPPED ApproveAndSwapUniswapV3Router02Hook: Uniswap V3 SwapRouter02 not configured for chain", chainId
            );
        }

        // Spark PSM swap hooks
        if (availability.swapSparkPsmHooks) {
            __checkContract(
                SWAP_SPARK_PSM_EXACT_IN_HOOK_KEY,
                __getSalt(SWAP_SPARK_PSM_EXACT_IN_HOOK_KEY),
                abi.encode(configuration.sparkPsm3s[chainId]),
                env
            );
            __checkContract(
                APPROVE_AND_SWAP_SPARK_PSM_EXACT_IN_HOOK_KEY,
                __getSalt(APPROVE_AND_SWAP_SPARK_PSM_EXACT_IN_HOOK_KEY),
                abi.encode(configuration.sparkPsm3s[chainId]),
                env
            );
            __checkContract(
                SWAP_SPARK_PSM_EXACT_OUT_HOOK_KEY,
                __getSalt(SWAP_SPARK_PSM_EXACT_OUT_HOOK_KEY),
                abi.encode(configuration.sparkPsm3s[chainId]),
                env
            );
            __checkContract(
                APPROVE_AND_SWAP_SPARK_PSM_EXACT_OUT_HOOK_KEY,
                __getSalt(APPROVE_AND_SWAP_SPARK_PSM_EXACT_OUT_HOOK_KEY),
                abi.encode(configuration.sparkPsm3s[chainId]),
                env
            );
        } else {
            console2.log("SKIPPED Spark PSM hooks: PSM3 not configured for chain", chainId);
        }

        if (availability.swapKyberSwapHooks) {
            __checkContract(
                SWAP_KYBERSWAP_HOOK_KEY,
                __getSalt(SWAP_KYBERSWAP_HOOK_KEY),
                abi.encode(
                    configuration.kyberSwapRouters[chainId],
                    configuration.kyberSwapScaleHelpers[chainId],
                    configuration.nativeTokens[chainId]
                ),
                env
            );
            __checkContract(
                APPROVE_AND_SWAP_KYBERSWAP_HOOK_KEY,
                __getSalt(APPROVE_AND_SWAP_KYBERSWAP_HOOK_KEY),
                abi.encode(
                    configuration.kyberSwapRouters[chainId],
                    configuration.kyberSwapScaleHelpers[chainId],
                    configuration.nativeTokens[chainId]
                ),
                env
            );
        } else {
            console2.log("SKIPPED KyberSwap hooks: KyberSwap Router not configured for chain", chainId);
        }

        if (availability.swapUniswapV2Hooks) {
            __checkContract(
                SWAP_UNISWAPV2_HOOK_KEY,
                __getSalt(SWAP_UNISWAPV2_HOOK_KEY),
                abi.encode(configuration.uniswapV2SwapRouters[chainId], configuration.nativeTokens[chainId]),
                env
            );
            __checkContract(
                APPROVE_AND_SWAP_UNISWAPV2_HOOK_KEY,
                __getSalt(APPROVE_AND_SWAP_UNISWAPV2_HOOK_KEY),
                abi.encode(configuration.uniswapV2SwapRouters[chainId], configuration.nativeTokens[chainId]),
                env
            );
        } else {
            console2.log("SKIPPED UniswapV2 hooks: V2 Router not configured for chain", chainId);
        }

        // TransferHook
        __checkContract(
            TRANSFER_HOOK_KEY, __getSalt(TRANSFER_HOOK_KEY), abi.encode(configuration.nativeTokens[chainId]), env
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
            __checkContract(
                SUPER_VAULT_YIELD_SOURCE_ORACLE_KEY,
                __getSalt(SUPER_VAULT_YIELD_SOURCE_ORACLE_KEY),
                abi.encode(superLedgerConfig),
                env
            );
            __checkContract(
                YO_YIELD_SOURCE_ORACLE_KEY, __getSalt(YO_YIELD_SOURCE_ORACLE_KEY), abi.encode(superLedgerConfig), env
            );
            // PendlePTAmortizedOracle and V2 (admin + superLedgerConfig)
            __checkContract(
                PENDLE_PT_AMORTIZED_ORACLE_KEY,
                __getSalt(PENDLE_PT_AMORTIZED_ORACLE_KEY),
                abi.encode(DEPLOYER, superLedgerConfig),
                env
            );
            __checkContract(
                PENDLE_PT_AMORTIZED_ORACLE_V2_KEY,
                __getSalt(PENDLE_PT_AMORTIZED_ORACLE_V2_KEY),
                abi.encode(DEPLOYER, superLedgerConfig),
                env
            );
            __checkContract(
                FIRELIGHT_YIELD_SOURCE_ORACLE_KEY,
                __getSalt(FIRELIGHT_YIELD_SOURCE_ORACLE_KEY),
                abi.encode(superLedgerConfig),
                env
            );
            // DETHYieldSourceOracle (superLedgerConfig + foundation) - only if foundation is configured
            if (configuration.dethFoundation != address(0)) {
                __checkContract(
                    DETH_YIELD_SOURCE_ORACLE_KEY,
                    __getSalt(DETH_YIELD_SOURCE_ORACLE_KEY),
                    abi.encode(superLedgerConfig, configuration.dethFoundation),
                    env
                );
            }
            // ERC7540YieldSourceOracle (superLedgerConfig + requestId)
            __checkContract(
                ERC7540_YIELD_SOURCE_ORACLE_KEY,
                __getSalt(ERC7540_YIELD_SOURCE_ORACLE_KEY),
                abi.encode(superLedgerConfig, uint256(0)),
                env
            );
            // SpectraMetaVaultOracle (superLedgerConfig + requestId)
            __checkContract(
                SPECTRA_META_VAULT_ORACLE_KEY,
                __getSalt(SPECTRA_META_VAULT_ORACLE_KEY),
                abi.encode(superLedgerConfig, uint256(0)),
                env
            );
            // MorphoBlueMarketRegistry (admin = DEPLOYER)
            __checkContract(
                MORPHO_BLUE_MARKET_REGISTRY_KEY,
                __getSalt(MORPHO_BLUE_MARKET_REGISTRY_KEY),
                abi.encode(DEPLOYER),
                env
            );
            // MorphoBlueYieldSourceOracle (superLedgerConfig + registry)
            if (__checkBytecodeExists("MorphoBlueMarketRegistry", env)) {
                address morphoRegistryAddr =
                    __computeContractAddress(MORPHO_BLUE_MARKET_REGISTRY_KEY, abi.encode(DEPLOYER), env);
                if (morphoRegistryAddr != address(0) && morphoRegistryAddr.code.length > 0) {
                    __checkContract(
                        MORPHO_BLUE_YIELD_SOURCE_ORACLE_KEY,
                        __getSalt(MORPHO_BLUE_YIELD_SOURCE_ORACLE_KEY),
                        abi.encode(superLedgerConfig, morphoRegistryAddr),
                        env
                    );
                }
            }
            // UniV3CLPRegistry (admin = DEPLOYER)
            __checkContract(
                UNIV3_CLP_REGISTRY_KEY,
                __getSalt(UNIV3_CLP_REGISTRY_KEY),
                abi.encode(DEPLOYER),
                env
            );
            // UniV3CLPYieldSourceOracle (superLedgerConfig + registry)
            if (__checkBytecodeExists("UniV3CLPRegistry", env)) {
                address univ3RegistryAddr =
                    __computeContractAddress(UNIV3_CLP_REGISTRY_KEY, abi.encode(DEPLOYER), env);
                if (univ3RegistryAddr != address(0) && univ3RegistryAddr.code.length > 0) {
                    __checkContract(
                        UNIV3_CLP_YIELD_SOURCE_ORACLE_KEY,
                        __getSalt(UNIV3_CLP_YIELD_SOURCE_ORACLE_KEY),
                        abi.encode(superLedgerConfig, univ3RegistryAddr),
                        env
                    );
                }
            }
        } else {
            revert("ORACLES_CHECK_FAILED_MISSING_SUPER_LEDGER_CONFIG");
        }

        // SuperYieldSourceOracle (no constructor args)
        __checkContract(SUPER_YIELD_SOURCE_ORACLE_KEY, __getSalt(SUPER_YIELD_SOURCE_ORACLE_KEY), "", env);
    }

    /// @notice Populate CoreContracts struct with addresses from deployment status
    /// @param chainId Chain ID
    /// @param coreContracts CoreContracts struct to populate
    function _populateCoreContractsFromStatus(
        uint64 chainId,
        CoreContracts memory coreContracts
    )
        internal
        view
    {
        ContractStatus memory status;

        status = _getContractStatus(chainId, SUPER_EXECUTOR_KEY);
        if (status.isDeployed) coreContracts.superExecutor = status.contractAddress;

        status = _getContractStatus(chainId, ACROSS_V3_ADAPTER_KEY);
        if (status.isDeployed) coreContracts.acrossV3Adapter = status.contractAddress;

        status = _getContractStatus(chainId, ACROSS_V3_ADAPTER_V2_KEY);
        if (status.isDeployed) coreContracts.acrossV3AdapterV2 = status.contractAddress;

        status = _getContractStatus(chainId, DEBRIDGE_ADAPTER_KEY);
        if (status.isDeployed) coreContracts.debridgeAdapter = status.contractAddress;

        status = _getContractStatus(chainId, STARGATE_ADAPTER_KEY);
        if (status.isDeployed) coreContracts.stargateAdapter = status.contractAddress;

        status = _getContractStatus(chainId, STARGATE_ADAPTER_V2_KEY);
        if (status.isDeployed) coreContracts.stargateAdapterV2 = status.contractAddress;

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
        ContractAvailability memory availability = _getContractAvailability(chainId, env);
        _validateAerodromeUniversalRouter(chainId, availability);

        // Pre-populate core contracts with existing deployed addresses
        _populateCoreContractsFromStatus(chainId, coreContracts);

        // ===== VALIDATION PHASE =====
        // Validate critical dependencies before deployment
        console2.log("Validating deployment dependencies for chain:", chainId);

        // Validate treasury address
        require(configuration.treasury != address(0), "TREASURY_ADDRESS_ZERO");
        console2.log(" Treasury:", configuration.treasury);

        // Check Permit2 (required for BatchTransferFromHook)
        if (availability.batchTransferFromHook) {
            require(configuration.permit2s[chainId] != address(0), "PERMIT2_ADDRESS_ZERO");
            require(configuration.permit2s[chainId].code.length > 0, "PERMIT2_NOT_DEPLOYED");
            console2.log(" Permit2:", configuration.permit2s[chainId]);
        } else {
            console2.log(" SKIPPED Permit2 validation: Not available on chain", chainId);
        }

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

        if (availability.swapKyberSwapHooks) {
            require(configuration.kyberSwapRouters[chainId] != address(0), "KYBER_ROUTER_ADDRESS_ZERO");
            require(configuration.kyberSwapRouters[chainId].code.length > 0, "KYBER_ROUTER_NOT_DEPLOYED");
            require(configuration.kyberSwapScaleHelpers[chainId] != address(0), "KYBER_SCALE_HELPER_ADDRESS_ZERO");
            require(configuration.kyberSwapScaleHelpers[chainId].code.length > 0, "KYBER_SCALE_HELPER_NOT_DEPLOYED");
            console2.log(" KyberSwap Router:", configuration.kyberSwapRouters[chainId]);
            console2.log(" KyberSwap ScaleHelper:", configuration.kyberSwapScaleHelpers[chainId]);
        } else {
            console2.log(" SKIPPED KyberSwap Router validation: Not available on chain", chainId);
        }

        if (availability.swapOpenOceanHooks) {
            require(configuration.openOceanRouters[chainId] != address(0), "OPENOCEAN_ROUTER_ADDRESS_ZERO");
            require(configuration.openOceanRouters[chainId].code.length > 0, "OPENOCEAN_ROUTER_NOT_DEPLOYED");
            require(configuration.openOceanReferrers[chainId] != address(0), "OPENOCEAN_REFERRER_ADDRESS_ZERO");
            console2.log(" OpenOcean Router:", configuration.openOceanRouters[chainId]);
            console2.log(" OpenOcean Referrer:", configuration.openOceanReferrers[chainId]);
        } else {
            console2.log(" SKIPPED OpenOcean validation: Not available on chain", chainId);
        }

        if (availability.swapUniswapV2Hooks) {
            require(configuration.uniswapV2SwapRouters[chainId] != address(0), "UNISWAPV2_ROUTER_ADDRESS_ZERO");
            require(configuration.uniswapV2SwapRouters[chainId].code.length > 0, "UNISWAPV2_ROUTER_NOT_DEPLOYED");
            console2.log(" UniswapV2 Router:", configuration.uniswapV2SwapRouters[chainId]);
        } else {
            console2.log(" SKIPPED UniswapV2 Router validation: Not available on chain", chainId);
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

        // Deploy AcrossV3AdapterV2 (compact 2-field message format)
        if (availability.acrossV3AdapterV2) {
            require(configuration.acrossSpokePoolV3s[chainId] != address(0), "ACROSS_ADAPTER_V2_SPOKE_POOL_PARAM_ZERO");
            require(coreContracts.superDestinationExecutor != address(0), "ACROSS_ADAPTER_V2_DEST_EXECUTOR_PARAM_ZERO");

            coreContracts.acrossV3AdapterV2 = __deployContractIfNeeded(
                ACROSS_V3_ADAPTER_V2_KEY,
                chainId,
                __getSalt(ACROSS_V3_ADAPTER_V2_KEY),
                abi.encodePacked(
                    __getBytecode("AcrossV3AdapterV2", env),
                    abi.encode(configuration.acrossSpokePoolV3s[chainId], coreContracts.superDestinationExecutor)
                )
            );

            // Validate AcrossV3AdapterV2 was deployed
            require(coreContracts.acrossV3AdapterV2 != address(0), "ACROSS_V3_ADAPTER_V2_DEPLOYMENT_FAILED");
            require(coreContracts.acrossV3AdapterV2.code.length > 0, "ACROSS_V3_ADAPTER_V2_NO_CODE");
            console2.log(" AcrossV3AdapterV2 deployed and validated");
        } else {
            console2.log(" SKIPPED AcrossV3AdapterV2 deployment: Not available on chain", chainId);
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

        // Deploy StargateAdapter only if available on this chain
        if (availability.stargateAdapter) {
            require(configuration.lzEndpointV2s[chainId] != address(0), "STARGATE_ADAPTER_LZ_ENDPOINT_PARAM_ZERO");
            require(
                configuration.stargateTokenMessagings[chainId] != address(0),
                "STARGATE_ADAPTER_TOKEN_MESSAGING_PARAM_ZERO"
            );
            require(coreContracts.superDestinationExecutor != address(0), "STARGATE_ADAPTER_DEST_EXECUTOR_PARAM_ZERO");

            coreContracts.stargateAdapter = __deployContractIfNeeded(
                STARGATE_ADAPTER_KEY,
                chainId,
                __getSalt(STARGATE_ADAPTER_KEY),
                abi.encodePacked(
                    __getBytecode("StargateAdapter", env),
                    abi.encode(
                        configuration.lzEndpointV2s[chainId],
                        configuration.stargateTokenMessagings[chainId],
                        coreContracts.superDestinationExecutor
                    )
                )
            );

            require(coreContracts.stargateAdapter != address(0), "STARGATE_ADAPTER_DEPLOYMENT_FAILED");
            require(coreContracts.stargateAdapter.code.length > 0, "STARGATE_ADAPTER_NO_CODE");
            console2.log(" StargateAdapter deployed and validated");
        } else {
            console2.log(" SKIPPED StargateAdapter deployment: Not available on chain", chainId);
        }

        // Deploy StargateAdapterV2 (compact 2-field compose format)
        if (availability.stargateAdapterV2) {
            require(configuration.lzEndpointV2s[chainId] != address(0), "STARGATE_ADAPTER_V2_LZ_ENDPOINT_PARAM_ZERO");
            require(
                configuration.stargateTokenMessagings[chainId] != address(0),
                "STARGATE_ADAPTER_V2_TOKEN_MESSAGING_PARAM_ZERO"
            );
            require(
                coreContracts.superDestinationExecutor != address(0), "STARGATE_ADAPTER_V2_DEST_EXECUTOR_PARAM_ZERO"
            );

            coreContracts.stargateAdapterV2 = __deployContractIfNeeded(
                STARGATE_ADAPTER_V2_KEY,
                chainId,
                __getSalt(STARGATE_ADAPTER_V2_KEY),
                abi.encodePacked(
                    __getBytecode("StargateAdapterV2", env),
                    abi.encode(
                        configuration.lzEndpointV2s[chainId],
                        configuration.stargateTokenMessagings[chainId],
                        coreContracts.superDestinationExecutor,
                        configuration.stargateAllowedOFTs[chainId]
                    )
                )
            );

            require(coreContracts.stargateAdapterV2 != address(0), "STARGATE_ADAPTER_V2_DEPLOYMENT_FAILED");
            require(coreContracts.stargateAdapterV2.code.length > 0, "STARGATE_ADAPTER_V2_NO_CODE");
            console2.log(" StargateAdapterV2 deployed and validated");
        } else {
            console2.log(" SKIPPED StargateAdapterV2 deployment: Not available on chain", chainId);
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

        // Deploy Oracles FIRST (hooks depend on oracle addresses)
        _deployOracles(chainId, env);

        // Deploy Hooks (after oracles, since some hooks need oracle addresses)
        _deployHooks(chainId, env);

        // Deploy Mock Contracts (only for development environment)
        if (env == 1) {
            //_deployMockContracts(chainId);
        }

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
        address erc5115Oracle;
        address stakingOracle;
        address pendlePTOracle;
        address superVaultOracle;
        address superLedger;
        address flatFeeLedger;

        // Read contract addresses from deployment output files
        string memory deploymentJson = _verifyContractAddressesFromBytecode(chainId, env, branchName);

        superLedgerConfig = vm.parseJsonAddress(deploymentJson, ".SuperLedgerConfiguration");
        erc4626Oracle = vm.parseJsonAddress(deploymentJson, ".ERC4626YieldSourceOracle");
        erc5115Oracle = vm.parseJsonAddress(deploymentJson, ".ERC5115YieldSourceOracle");
        stakingOracle = vm.parseJsonAddress(deploymentJson, ".StakingYieldSourceOracle");
        pendlePTOracle = _safeParseJsonAddress(deploymentJson, ".PendlePTYieldSourceOracle");
        superVaultOracle = _safeParseJsonAddress(deploymentJson, ".SuperVaultYieldSourceOracle");
        superLedger = vm.parseJsonAddress(deploymentJson, ".SuperLedger");
        flatFeeLedger = vm.parseJsonAddress(deploymentJson, ".FlatFeeLedger");

        // ===== VALIDATE ALL REQUIRED CONTRACTS =====
        require(superLedgerConfig != address(0), "SETUP_SUPER_LEDGER_CONFIG_ZERO");
        require(superLedgerConfig.code.length > 0, "SETUP_SUPER_LEDGER_CONFIG_NO_CODE");

        require(erc4626Oracle != address(0), "SETUP_ERC4626_ORACLE_ZERO");
        require(erc4626Oracle.code.length > 0, "SETUP_ERC4626_ORACLE_NO_CODE");

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

        // Check if optional oracles are deployed
        bool hasPendlePT = pendlePTOracle != address(0) && pendlePTOracle.code.length > 0;
        bool hasSuperVault = superVaultOracle != address(0) && superVaultOracle.code.length > 0;

        console2.log("  SuperLedgerConfiguration:", superLedgerConfig);
        console2.log("  ERC4626 Oracle:", erc4626Oracle);
        console2.log("  ERC5115 Oracle:", erc5115Oracle);
        console2.log("  Staking Oracle:", stakingOracle);
        console2.log("  PendlePT Oracle:", pendlePTOracle);
        console2.log("  PendlePT Available:", hasPendlePT);
        console2.log("  SuperVault Oracle:", superVaultOracle);
        console2.log("  SuperVault Available:", hasSuperVault);
        console2.log("  SuperLedger:", superLedger);
        console2.log("  FlatFeeLedger:", flatFeeLedger);
        console2.log("  Treasury:", configuration.treasury);

        // ===== SETUP CONFIGURATIONS WITH VALIDATED PARAMETERS =====
        // Base: 3 oracles (ERC4626, ERC5115, Staking), plus optional PendlePT and SuperVault
        uint256 configCount = 3 + (hasPendlePT ? 1 : 0) + (hasSuperVault ? 1 : 0);
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](configCount);

        // Note: Using treasury address from configuration
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: erc4626Oracle, feePercent: 0, feeRecipient: configuration.treasury, ledger: superLedger
        });
        configs[1] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: erc5115Oracle, feePercent: 0, feeRecipient: configuration.treasury, ledger: flatFeeLedger
        });
        configs[2] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: stakingOracle, feePercent: 0, feeRecipient: configuration.treasury, ledger: superLedger
        });

        // Track next available index for optional oracles
        uint256 nextConfigIndex = 3;

        if (hasPendlePT) {
            configs[nextConfigIndex] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
                yieldSourceOracle: pendlePTOracle,
                feePercent: 0,
                feeRecipient: configuration.treasury,
                ledger: superLedger
            });
            nextConfigIndex++;
        }

        if (hasSuperVault) {
            configs[nextConfigIndex] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
                yieldSourceOracle: superVaultOracle,
                feePercent: 0,
                feeRecipient: configuration.treasury,
                ledger: superLedger
            });
        }

        // Validate each configuration before setup
        for (uint256 i = 0; i < configs.length; ++i) {
            require(configs[i].yieldSourceOracle != address(0), "CONFIG_YIELD_SOURCE_ORACLE_ZERO");
            require(configs[i].feeRecipient != address(0), "CONFIG_FEE_RECIPIENT_ZERO");
            require(configs[i].ledger != address(0), "CONFIG_LEDGER_ZERO");
            console2.log(" Configuration", i, "validated");
        }

        bytes32[] memory salts = new bytes32[](configCount);
        salts[0] = bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_SALT));
        salts[1] = bytes32(bytes(ERC5115_YIELD_SOURCE_ORACLE_SALT));
        salts[2] = bytes32(bytes(STAKING_YIELD_SOURCE_ORACLE_SALT));

        // Track next available index for optional oracle salts
        uint256 nextSaltIndex = 3;

        if (hasPendlePT) {
            salts[nextSaltIndex] = bytes32(bytes(PENDLE_PT_YIELD_SOURCE_ORACLE_SALT));
            nextSaltIndex++;
        }

        if (hasSuperVault) {
            salts[nextSaltIndex] = bytes32(bytes(SUPERVAULT_YIELD_SOURCE_ORACLE_SALT));
        }

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
        uint256 env;
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
        vars.env = env;

        // Get constructor args for ledger contracts
        vars.superLedgerConfig = vm.parseJsonAddress(deploymentJson, ".SuperLedgerConfiguration");
        vars.superExecutor = vm.parseJsonAddress(deploymentJson, ".SuperExecutor");
        vars.superDestExecutor = vm.parseJsonAddress(deploymentJson, ".SuperDestinationExecutor");

        vars.allowedExecutors = new address[](2);
        vars.allowedExecutors[0] = vars.superExecutor;
        vars.allowedExecutors[1] = vars.superDestExecutor;

        vars.ledgerConstructorArgs = abi.encode(vars.superLedgerConfig, vars.allowedExecutors);

        // Define contracts to verify with their corresponding environment-specific bytecode paths and constructor args
        ContractVerification[] memory contracts = new ContractVerification[](12);

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
            name: "ERC5115YieldSourceOracle",
            outputKey: ".ERC5115YieldSourceOracle",
            bytecodePath: string(abi.encodePacked(BYTECODE_DIRECTORY, "ERC5115YieldSourceOracle.json")),
            constructorArgs: ""
        });

        contracts[3] = ContractVerification({
            name: "StakingYieldSourceOracle",
            outputKey: ".StakingYieldSourceOracle",
            bytecodePath: string(abi.encodePacked(BYTECODE_DIRECTORY, "StakingYieldSourceOracle.json")),
            constructorArgs: ""
        });

        contracts[4] = ContractVerification({
            name: "SuperLedger",
            outputKey: ".SuperLedger",
            bytecodePath: string(abi.encodePacked(BYTECODE_DIRECTORY, "SuperLedger.json")),
            constructorArgs: string(vars.ledgerConstructorArgs)
        });

        contracts[5] = ContractVerification({
            name: "FlatFeeLedger",
            outputKey: ".FlatFeeLedger",
            bytecodePath: string(abi.encodePacked(BYTECODE_DIRECTORY, "FlatFeeLedger.json")),
            constructorArgs: string(vars.ledgerConstructorArgs)
        });

        contracts[6] = ContractVerification({
            name: "ERC7540YieldSourceOracle",
            outputKey: ".ERC7540YieldSourceOracle",
            bytecodePath: string(abi.encodePacked(BYTECODE_DIRECTORY, "ERC7540YieldSourceOracle.json")),
            constructorArgs: ""
        });

        contracts[7] = ContractVerification({
            name: "SpectraMetaVaultOracle",
            outputKey: ".SpectraMetaVaultOracle",
            bytecodePath: string(abi.encodePacked(BYTECODE_DIRECTORY, "SpectraMetaVaultOracle.json")),
            constructorArgs: ""
        });

        contracts[8] = ContractVerification({
            name: "MorphoBlueMarketRegistry",
            outputKey: ".MorphoBlueMarketRegistry",
            bytecodePath: string(abi.encodePacked(BYTECODE_DIRECTORY, "MorphoBlueMarketRegistry.json")),
            constructorArgs: ""
        });

        contracts[9] = ContractVerification({
            name: "MorphoBlueYieldSourceOracle",
            outputKey: ".MorphoBlueYieldSourceOracle",
            bytecodePath: string(abi.encodePacked(BYTECODE_DIRECTORY, "MorphoBlueYieldSourceOracle.json")),
            constructorArgs: ""
        });

        contracts[10] = ContractVerification({
            name: "UniV3CLPRegistry",
            outputKey: ".UniV3CLPRegistry",
            bytecodePath: string(abi.encodePacked(BYTECODE_DIRECTORY, "UniV3CLPRegistry.json")),
            constructorArgs: ""
        });

        contracts[11] = ContractVerification({
            name: "UniV3CLPYieldSourceOracle",
            outputKey: ".UniV3CLPYieldSourceOracle",
            bytecodePath: string(abi.encodePacked(BYTECODE_DIRECTORY, "UniV3CLPYieldSourceOracle.json")),
            constructorArgs: ""
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
                || Strings.equal(contractToVerify.name, "ERC5115YieldSourceOracle")
                || Strings.equal(contractToVerify.name, "StakingYieldSourceOracle")
                || Strings.equal(contractToVerify.name, "FirelightYieldSourceOracle")
        ) {
            // Oracles need SuperLedgerConfiguration
            bytes memory constructorArgs = abi.encode(vars.superLedgerConfig);
            computedAddress = DeterministicDeployerLib.computeAddress(
                abi.encodePacked(bytecode, constructorArgs), __getSalt(contractToVerify.name)
            );
        } else if (Strings.equal(contractToVerify.name, "DETHYieldSourceOracle")) {
            // DETHYieldSourceOracle needs SuperLedgerConfiguration + foundation
            bytes memory constructorArgs = abi.encode(vars.superLedgerConfig, configuration.dethFoundation);
            computedAddress = DeterministicDeployerLib.computeAddress(
                abi.encodePacked(bytecode, constructorArgs), __getSalt(contractToVerify.name)
            );
        } else if (
            Strings.equal(contractToVerify.name, "ERC7540YieldSourceOracle")
                || Strings.equal(contractToVerify.name, "SpectraMetaVaultOracle")
        ) {
            // ERC7540YieldSourceOracle / SpectraMetaVaultOracle need SuperLedgerConfiguration + requestId
            bytes memory constructorArgs = abi.encode(vars.superLedgerConfig, uint256(0));
            computedAddress = DeterministicDeployerLib.computeAddress(
                abi.encodePacked(bytecode, constructorArgs), __getSalt(contractToVerify.name)
            );
        } else if (Strings.equal(contractToVerify.name, "MorphoBlueMarketRegistry")) {
            // MorphoBlueMarketRegistry needs admin (DEPLOYER)
            bytes memory constructorArgs = abi.encode(DEPLOYER);
            computedAddress = DeterministicDeployerLib.computeAddress(
                abi.encodePacked(bytecode, constructorArgs), __getSalt(contractToVerify.name)
            );
        } else if (Strings.equal(contractToVerify.name, "MorphoBlueYieldSourceOracle")) {
            // MorphoBlueYieldSourceOracle needs superLedgerConfig + registry address
            address morphoRegistryAddr =
                __computeContractAddress(MORPHO_BLUE_MARKET_REGISTRY_KEY, abi.encode(DEPLOYER), vars.env);
            bytes memory constructorArgs = abi.encode(vars.superLedgerConfig, morphoRegistryAddr);
            computedAddress = DeterministicDeployerLib.computeAddress(
                abi.encodePacked(bytecode, constructorArgs), __getSalt(contractToVerify.name)
            );
        } else if (Strings.equal(contractToVerify.name, "UniV3CLPRegistry")) {
            // UniV3CLPRegistry needs admin (DEPLOYER)
            bytes memory constructorArgs = abi.encode(DEPLOYER);
            computedAddress = DeterministicDeployerLib.computeAddress(
                abi.encodePacked(bytecode, constructorArgs), __getSalt(contractToVerify.name)
            );
        } else if (Strings.equal(contractToVerify.name, "UniV3CLPYieldSourceOracle")) {
            // UniV3CLPYieldSourceOracle needs superLedgerConfig + registry address
            address univ3RegistryAddr =
                __computeContractAddress(UNIV3_CLP_REGISTRY_KEY, abi.encode(DEPLOYER), vars.env);
            bytes memory constructorArgs = abi.encode(vars.superLedgerConfig, univ3RegistryAddr);
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

    /// @notice Safely parse an address from JSON, returning address(0) if not found
    /// @param json The JSON string to parse
    /// @param key The JSON key to look up
    /// @return The parsed address, or address(0) if not found or invalid
    function _safeParseJsonAddress(string memory json, string memory key) internal pure returns (address) {
        try vm.parseJsonAddress(json, key) returns (address addr) {
            return addr;
        } catch {
            return address(0);
        }
    }

    function _deployHooks(uint64 chainId, uint256 env) private returns (HookAddresses memory hookAddresses) {
        console2.log("Starting hook deployment with comprehensive dependency validation...");

        // Get contract availability for this chain
        ContractAvailability memory availability = _getContractAvailability(chainId, env);

        uint256 len = 80;
        HookDeployment[] memory hooks = new HookDeployment[](len);
        address[] memory addresses = new address[](len);

        // ===== HOOKS WITHOUT DEPENDENCIES =====
        hooks[0] = _createSafeHookDeployment(APPROVE_ERC20_HOOK_KEY, "ApproveERC20Hook", env);
        hooks[1] = _createSafeHookDeployment(TRANSFER_ERC20_HOOK_KEY, "TransferERC20Hook", env);

        // ===== HOOKS WITH VALIDATED DEPENDENCIES =====

        // BatchTransferFromHook - Requires Permit2 (already validated in core deployment)
        require(configuration.permit2s[chainId] != address(0), "BATCH_TRANSFER_FROM_HOOK_PERMIT2_PARAM_ZERO");
        require(configuration.permit2s[chainId].code.length > 0, "BATCH_TRANSFER_FROM_HOOK_PERMIT2_NOT_DEPLOYED");

        hooks[2] = _createSafeHookDeploymentWithArgs(
            BATCH_TRANSFER_HOOK_KEY, "BatchTransferHook", env, abi.encode(configuration.nativeTokens[chainId])
        );
        hooks[3] = _createSafeHookDeploymentWithArgs(
            BATCH_TRANSFER_FROM_HOOK_KEY, "BatchTransferFromHook", env, abi.encode(configuration.permit2s[chainId])
        );

        // Vault hooks (no external dependencies)
        hooks[4] = _createSafeHookDeployment(DEPOSIT_4626_VAULT_HOOK_KEY, "Deposit4626VaultHook", env);
        hooks[5] =
            _createSafeHookDeployment(APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY, "ApproveAndDeposit4626VaultHook", env);
        hooks[6] = _createSafeHookDeployment(REDEEM_4626_VAULT_HOOK_KEY, "Redeem4626VaultHook", env);
        hooks[7] = _createSafeHookDeployment(DEPOSIT_5115_VAULT_HOOK_KEY, "Deposit5115VaultHook", env);
        hooks[8] =
            _createSafeHookDeployment(APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY, "ApproveAndDeposit5115VaultHook", env);
        hooks[9] = _createSafeHookDeployment(REDEEM_5115_VAULT_HOOK_KEY, "Redeem5115VaultHook", env);
        hooks[10] = _createSafeHookDeployment(REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY, "RequestDeposit7540VaultHook", env);
        hooks[11] = _createSafeHookDeployment(
            APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY, "ApproveAndRequestDeposit7540VaultHook", env
        );
        hooks[12] = _createSafeHookDeployment(REDEEM_7540_VAULT_HOOK_KEY, "Redeem7540VaultHook", env);
        hooks[13] = _createSafeHookDeployment(REQUEST_REDEEM_7540_VAULT_HOOK_KEY, "RequestRedeem7540VaultHook", env);
        hooks[14] = _createSafeHookDeployment(DEPOSIT_7540_VAULT_HOOK_KEY, "Deposit7540VaultHook", env);
        hooks[15] = _createSafeHookDeployment(SET_OPERATOR_7540_HOOK_KEY, "SetOperator7540Hook", env);
        hooks[16] = _createSafeHookDeployment(SET_SLIPPAGE_HOOK_KEY, "SetSlippageHook", env);

        // ===== HOOKS WITH EXTERNAL ROUTER DEPENDENCIES =====

        // 1inch Swap Hook - Only deploy if available on this chain
        if (availability.swap1InchHook) {
            require(configuration.aggregationRouters[chainId] != address(0), "SWAP_1INCH_HOOK_ROUTER_PARAM_ZERO");
            require(configuration.aggregationRouters[chainId].code.length > 0, "SWAP_1INCH_HOOK_ROUTER_NOT_DEPLOYED");
            hooks[17] = _createSafeHookDeploymentWithArgs(
                SWAP_1INCH_HOOK_KEY,
                "Swap1InchHook",
                env,
                abi.encode(configuration.aggregationRouters[chainId], configuration.nativeTokens[chainId])
            );
        } else {
            console2.log(" SKIPPED Swap1InchHook deployment: Not available on chain", chainId);
            hooks[17] = HookDeployment("", "", ""); // Empty deployment
        }

        // ODOS Swap Hooks - Only deploy if available on this chain
        if (availability.swapOdosHooks) {
            require(configuration.odosRouters[chainId] != address(0), "SWAP_ODOS_HOOK_ROUTER_PARAM_ZERO");
            require(configuration.odosRouters[chainId].code.length > 0, "SWAP_ODOS_HOOK_ROUTER_NOT_DEPLOYED");
            hooks[18] = _createSafeHookDeploymentWithArgs(
                SWAP_ODOSV2_HOOK_KEY, "SwapOdosV2Hook", env, abi.encode(configuration.odosRouters[chainId])
            );
            hooks[19] = _createSafeHookDeploymentWithArgs(
                APPROVE_AND_SWAP_ODOSV2_HOOK_KEY,
                "ApproveAndSwapOdosV2Hook",
                env,
                abi.encode(configuration.odosRouters[chainId])
            );
        } else {
            console2.log(" SKIPPED ODOS Swap Hooks deployment: Not available on chain", chainId);
            hooks[18] = HookDeployment("", "", ""); // Empty deployment
            hooks[19] = HookDeployment("", "", ""); // Empty deployment
        }

        // Pendle Router Hooks - Only deploy if available on this chain
        if (availability.pendleRouterHooks) {
            require(configuration.pendleRouters[chainId] != address(0), "PENDLE_ROUTER_HOOK_ROUTER_PARAM_ZERO");
            require(configuration.pendleRouters[chainId].code.length > 0, "PENDLE_ROUTER_HOOK_ROUTER_NOT_DEPLOYED");
            hooks[20] = _createSafeHookDeploymentWithArgs(
                PENDLE_ROUTER_SWAP_HOOK_KEY,
                "PendleRouterSwapHook",
                env,
                abi.encode(configuration.pendleRouters[chainId])
            );
            hooks[21] = _createSafeHookDeploymentWithArgs(
                PENDLE_ROUTER_REDEEM_HOOK_KEY,
                "PendleRouterRedeemHook",
                env,
                abi.encode(configuration.pendleRouters[chainId])
            );
        } else {
            console2.log(" SKIPPED Pendle Router Hooks deployment: Not available on chain", chainId);
            hooks[20] = HookDeployment("", "", ""); // Empty deployment
            hooks[21] = HookDeployment("", "", ""); // Empty deployment
        }

        // Pendle PT Amortized Oracle Hooks (V1) - Only deploy if oracle was deployed (config updated by _deployOracles)
        if (
            configuration.pendlePTAmortizedOracles[chainId] != address(0)
                && configuration.pendlePTAmortizedOracles[chainId].code.length > 0
        ) {
            hooks[22] = _createSafeHookDeploymentWithArgs(
                RECORD_PURCHASE_PENDLE_PT_AMORTIZED_ORACLE_HOOK_KEY,
                "RecordPurchasePendlePTAmortizedOracleHook",
                env,
                abi.encode(configuration.pendlePTAmortizedOracles[chainId])
            );
            hooks[23] = _createSafeHookDeploymentWithArgs(
                RECORD_REDEMPTION_PENDLE_PT_AMORTIZED_ORACLE_HOOK_KEY,
                "RecordRedemptionPendlePTAmortizedOracleHook",
                env,
                abi.encode(configuration.pendlePTAmortizedOracles[chainId])
            );
        } else {
            console2.log(" SKIPPED Pendle PT Amortized Oracle Hooks (V1): Oracle not deployed on chain", chainId);
            hooks[22] = HookDeployment("", "", ""); // Empty deployment
            hooks[23] = HookDeployment("", "", ""); // Empty deployment
        }

        // Pendle PT Amortized Oracle Hooks (V2) - Only deploy if oracle V2 was deployed (config updated by
        // _deployOracles)
        if (
            configuration.pendlePTAmortizedOraclesV2[chainId] != address(0)
                && configuration.pendlePTAmortizedOraclesV2[chainId].code.length > 0
        ) {
            hooks[46] = _createSafeHookDeploymentWithArgs(
                RECORD_PURCHASE_PENDLE_PT_AMORTIZED_ORACLE_HOOK_V2_KEY,
                "RecordPurchasePendlePTAmortizedOracleHookV2",
                env,
                abi.encode(configuration.pendlePTAmortizedOraclesV2[chainId])
            );
            hooks[47] = _createSafeHookDeploymentWithArgs(
                RECORD_REDEMPTION_PENDLE_PT_AMORTIZED_ORACLE_HOOK_V2_KEY,
                "RecordRedemptionPendlePTAmortizedOracleHookV2",
                env,
                abi.encode(configuration.pendlePTAmortizedOraclesV2[chainId])
            );
        } else {
            console2.log(" SKIPPED Pendle PT Amortized Oracle Hooks (V2): Oracle not deployed on chain", chainId);
            hooks[46] = HookDeployment("", "", ""); // Empty deployment
            hooks[47] = HookDeployment("", "", ""); // Empty deployment
        }

        address superValidator;
        // Across Bridge Hook - Only deploy if available on this chain
        if (availability.acrossV3Adapter) {
            require(configuration.acrossSpokePoolV3s[chainId] != address(0), "ACROSS_HOOK_SPOKE_POOL_PARAM_ZERO");
            require(configuration.acrossSpokePoolV3s[chainId].code.length > 0, "ACROSS_HOOK_SPOKE_POOL_NOT_DEPLOYED");

            superValidator = _getContract(chainId, SUPER_VALIDATOR_KEY);
            require(superValidator != address(0), "ACROSS_HOOK_MERKLE_VALIDATOR_PARAM_ZERO");
            require(superValidator.code.length > 0, "ACROSS_HOOK_MERKLE_VALIDATOR_NOT_DEPLOYED");

            hooks[24] = _createSafeHookDeploymentWithArgs(
                ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY,
                "AcrossSendFundsAndExecuteOnDstHook",
                env,
                abi.encode(configuration.acrossSpokePoolV3s[chainId], superValidator)
            );
            hooks[25] = _createSafeHookDeploymentWithArgs(
                APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY,
                "ApproveAndAcrossSendFundsAndExecuteOnDstHook",
                env,
                abi.encode(configuration.acrossSpokePoolV3s[chainId], superValidator)
            );
        } else {
            console2.log(" SKIPPED AcrossSendFundsAndExecuteOnDstHook deployment: Not available on chain", chainId);
            console2.log(
                " SKIPPED ApproveAndAcrossSendFundsAndExecuteOnDstHook deployment: Not available on chain", chainId
            );
            hooks[24] = HookDeployment("", "", ""); // Empty deployment
            hooks[25] = HookDeployment("", "", ""); // Empty deployment
        }

        // DeBridge hooks - Only deploy if available on this chain
        superValidator = _getContract(chainId, SUPER_VALIDATOR_KEY);
        require(superValidator != address(0), "DEBRIDGE_HOOKS_MERKLE_VALIDATOR_PARAM_ZERO");

        if (availability.deBridgeSendOrderHook) {
            require(configuration.debridgeSrcDln[chainId] != address(0), "DEBRIDGE_SEND_HOOK_DLN_SRC_PARAM_ZERO");
            hooks[26] = _createSafeHookDeploymentWithArgs(
                DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY,
                "DeBridgeSendOrderAndExecuteOnDstHook",
                env,
                abi.encode(configuration.debridgeSrcDln[chainId], superValidator)
            );
        } else {
            console2.log(" SKIPPED DeBridgeSendOrderAndExecuteOnDstHook deployment: Not available on chain", chainId);
            hooks[26] = HookDeployment("", "", ""); // Empty deployment
        }

        if (availability.deBridgeCancelOrderHook) {
            require(configuration.debridgeDstDln[chainId] != address(0), "DEBRIDGE_CANCEL_HOOK_DLN_DST_PARAM_ZERO");
            hooks[27] = _createSafeHookDeploymentWithArgs(
                DEBRIDGE_CANCEL_ORDER_HOOK_KEY,
                "DeBridgeCancelOrderHook",
                env,
                abi.encode(configuration.debridgeDstDln[chainId])
            );
        } else {
            console2.log(" SKIPPED DeBridgeCancelOrderHook deployment: Not available on chain", chainId);
            hooks[27] = HookDeployment("", "", ""); // Empty deployment
        }

        // Protocol-specific hooks (no external dependencies)
        hooks[28] = _createSafeHookDeployment(ETHENA_COOLDOWN_SHARES_HOOK_KEY, "EthenaCooldownSharesHook", env);
        hooks[29] = _createSafeHookDeployment(ETHENA_UNSTAKE_HOOK_KEY, "EthenaUnstakeHook", env);
        hooks[30] = _createSafeHookDeployment(CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY, "CancelDepositRequest7540Hook", env);
        hooks[31] = _createSafeHookDeployment(CANCEL_REDEEM_REQUEST_7540_HOOK_KEY, "CancelRedeemRequest7540Hook", env);
        hooks[32] = _createSafeHookDeployment(
            CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY, "ClaimCancelDepositRequest7540Hook", env
        );
        hooks[33] = _createSafeHookDeployment(
            CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY, "ClaimCancelRedeemRequest7540Hook", env
        );

        // ERC-7540 WithId hooks (non-zero requestId support)
        hooks[56] = _createSafeHookDeployment(
            CANCEL_DEPOSIT_REQUEST_WITH_ID_7540_HOOK_KEY, "CancelDepositRequestWithId7540Hook", env
        );
        hooks[57] = _createSafeHookDeployment(
            CANCEL_REDEEM_REQUEST_WITH_ID_7540_HOOK_KEY, "CancelRedeemRequestWithId7540Hook", env
        );
        hooks[58] = _createSafeHookDeployment(
            CLAIM_CANCEL_DEPOSIT_REQUEST_WITH_ID_7540_HOOK_KEY, "ClaimCancelDepositRequestWithId7540Hook", env
        );
        hooks[59] = _createSafeHookDeployment(
            CLAIM_CANCEL_REDEEM_REQUEST_WITH_ID_7540_HOOK_KEY, "ClaimCancelRedeemRequestWithId7540Hook", env
        );
        hooks[60] = _createSafeHookDeployment(REDEEM_WITH_ID_7540_VAULT_HOOK_KEY, "RedeemWithId7540VaultHook", env);
        hooks[61] = _createSafeHookDeployment(WITHDRAW_WITH_ID_7540_VAULT_HOOK_KEY, "WithdrawWithId7540VaultHook", env);

        hooks[34] = _createSafeHookDeployment(OFFRAMP_TOKENS_HOOK_KEY, "OfframpTokensHook", env);
        hooks[35] = _createSafeHookDeployment(MARK_ROOT_AS_USED_HOOK_KEY, "MarkRootAsUsedHook", env);
        // Merkl Claim Reward Hook - Only deploy if available on this chain
        if (availability.merklClaimRewardHook) {
            hooks[36] = _createSafeHookDeploymentWithArgsAndSalt(
                MERKL_CLAIM_REWARD_HOOK_KEY,
                MERKL_CLAIM_REWARD_HOOK_KEY,
                MERKL_CLAIM_REWARD_HOOK_SALT,
                env,
                abi.encode(configuration.merklDistributors[chainId])
            );
        } else {
            console2.log(" SKIPPED MerklClaimRewardHook deployment: Not available on chain", chainId);
            hooks[36] = HookDeployment("", "", ""); // Empty deployment
        }

        // ===== CIRCLE GATEWAY HOOKS =====
        // Circle Gateway hooks - Validate gateway addresses
        require(GATEWAY_WALLET != address(0), "CIRCLE_GATEWAY_WALLET_PARAM_ZERO");
        require(GATEWAY_MINTER != address(0), "CIRCLE_GATEWAY_MINTER_PARAM_ZERO");

        hooks[37] = _createSafeHookDeploymentWithArgs(
            CIRCLE_GATEWAY_WALLET_HOOK_KEY, "CircleGatewayWalletHook", env, abi.encode(GATEWAY_WALLET)
        );
        hooks[38] = _createSafeHookDeploymentWithArgs(
            CIRCLE_GATEWAY_MINTER_HOOK_KEY, "CircleGatewayMinterHook", env, abi.encode(GATEWAY_MINTER)
        );
        hooks[39] = _createSafeHookDeploymentWithArgs(
            CIRCLE_GATEWAY_ADD_DELEGATE_HOOK_KEY, "CircleGatewayAddDelegateHook", env, abi.encode(GATEWAY_WALLET)
        );
        hooks[40] = _createSafeHookDeploymentWithArgs(
            CIRCLE_GATEWAY_REMOVE_DELEGATE_HOOK_KEY, "CircleGatewayRemoveDelegateHook", env, abi.encode(GATEWAY_WALLET)
        );

        // UniswapV4 Swap Hook - Only deploy if V4 PoolManager available on this chain
        if (availability.swapUniswapV4Hook) {
            hooks[41] = _createSafeHookDeploymentWithArgs(
                SWAP_UNISWAPV4_HOOK_KEY,
                "SwapUniswapV4Hook",
                env,
                abi.encode(configuration.uniswapV4PoolManagers[chainId])
            );
        } else {
            console2.log("SKIPPED SwapUniswapV4Hook: Uniswap V4 PoolManager not available on chain", chainId);
            hooks[41] = HookDeployment("", "", ""); // Empty deployment
        }

        // UniswapV3 Swap Hooks - Only deploy if V3 SwapRouter available on this chain
        if (availability.swapUniswapV3Hooks) {
            hooks[42] = _createSafeHookDeploymentWithArgs(
                SWAP_UNISWAPV3_HOOK_KEY,
                "SwapUniswapV3Hook",
                env,
                abi.encode(configuration.uniswapV3SwapRouters[chainId])
            );
            hooks[43] = _createSafeHookDeploymentWithArgs(
                APPROVE_AND_SWAP_UNISWAPV3_HOOK_KEY,
                "ApproveAndSwapUniswapV3Hook",
                env,
                abi.encode(configuration.uniswapV3SwapRouters[chainId])
            );
        } else {
            console2.log("SKIPPED SwapUniswapV3Hook: Uniswap V3 SwapRouter not available on chain", chainId);
            console2.log("SKIPPED ApproveAndSwapUniswapV3Hook: Uniswap V3 SwapRouter not available on chain", chainId);
            hooks[42] = HookDeployment("", "", ""); // Empty deployment
            hooks[43] = HookDeployment("", "", ""); // Empty deployment
        }

        // TransferHook
        hooks[44] = _createSafeHookDeploymentWithArgs(
            TRANSFER_HOOK_KEY, "TransferHook", env, abi.encode(configuration.nativeTokens[chainId])
        );

        // PendleUnifiedHook - Only deploy if Pendle router available
        if (availability.pendleRouterHooks) {
            hooks[45] = _createSafeHookDeploymentWithArgs(
                PENDLE_UNIFIED_HOOK_KEY, "PendleUnifiedHook", env, abi.encode(configuration.pendleRouters[chainId])
            );
        } else {
            hooks[45] = HookDeployment("", "", ""); // Empty deployment
        }

        // Spark PSM Hooks - Only deploy if PSM3 available on this chain
        if (availability.swapSparkPsmHooks) {
            hooks[48] = _createSafeHookDeploymentWithArgs(
                SWAP_SPARK_PSM_EXACT_IN_HOOK_KEY,
                "SwapSparkPSMExactInHook",
                env,
                abi.encode(configuration.sparkPsm3s[chainId])
            );
            hooks[49] = _createSafeHookDeploymentWithArgs(
                APPROVE_AND_SWAP_SPARK_PSM_EXACT_IN_HOOK_KEY,
                "ApproveAndSwapSparkPSMExactInHook",
                env,
                abi.encode(configuration.sparkPsm3s[chainId])
            );
            hooks[50] = _createSafeHookDeploymentWithArgs(
                SWAP_SPARK_PSM_EXACT_OUT_HOOK_KEY,
                "SwapSparkPSMExactOutHook",
                env,
                abi.encode(configuration.sparkPsm3s[chainId])
            );
            hooks[51] = _createSafeHookDeploymentWithArgs(
                APPROVE_AND_SWAP_SPARK_PSM_EXACT_OUT_HOOK_KEY,
                "ApproveAndSwapSparkPSMExactOutHook",
                env,
                abi.encode(configuration.sparkPsm3s[chainId])
            );
        } else {
            console2.log("SKIPPED Spark PSM hooks: PSM3 not available on chain", chainId);
            hooks[48] = HookDeployment("", "", ""); // Empty deployment
            hooks[49] = HookDeployment("", "", ""); // Empty deployment
            hooks[50] = HookDeployment("", "", ""); // Empty deployment
            hooks[51] = HookDeployment("", "", ""); // Empty deployment
        }

        // KyberSwap Hooks - Only deploy if available on this chain
        if (availability.swapKyberSwapHooks) {
            require(configuration.kyberSwapRouters[chainId] != address(0), "SWAP_KYBERSWAP_HOOK_ROUTER_PARAM_ZERO");
            require(configuration.kyberSwapRouters[chainId].code.length > 0, "SWAP_KYBERSWAP_HOOK_ROUTER_NOT_DEPLOYED");
            require(
                configuration.kyberSwapScaleHelpers[chainId] != address(0),
                "SWAP_KYBERSWAP_HOOK_SCALE_HELPER_PARAM_ZERO"
            );
            require(
                configuration.kyberSwapScaleHelpers[chainId].code.length > 0,
                "SWAP_KYBERSWAP_HOOK_SCALE_HELPER_NOT_DEPLOYED"
            );
            hooks[52] = _createSafeHookDeploymentWithArgs(
                SWAP_KYBERSWAP_HOOK_KEY,
                "SwapKyberSwapHook",
                env,
                abi.encode(
                    configuration.kyberSwapRouters[chainId],
                    configuration.kyberSwapScaleHelpers[chainId],
                    configuration.nativeTokens[chainId]
                )
            );
            hooks[53] = _createSafeHookDeploymentWithArgs(
                APPROVE_AND_SWAP_KYBERSWAP_HOOK_KEY,
                "ApproveAndSwapKyberSwapHook",
                env,
                abi.encode(
                    configuration.kyberSwapRouters[chainId],
                    configuration.kyberSwapScaleHelpers[chainId],
                    configuration.nativeTokens[chainId]
                )
            );
        } else {
            console2.log(" SKIPPED KyberSwap Hooks deployment: Not available on chain", chainId);
            hooks[52] = HookDeployment("", "", ""); // Empty deployment
            hooks[53] = HookDeployment("", "", ""); // Empty deployment
        }

        // UniswapV2 Swap Hooks - Only deploy if V2 SwapRouter available on this chain (e.g., SparkDex on Flare)
        if (availability.swapUniswapV2Hooks) {
            require(configuration.uniswapV2SwapRouters[chainId] != address(0), "SWAP_UNISWAPV2_HOOK_ROUTER_PARAM_ZERO");
            require(
                configuration.uniswapV2SwapRouters[chainId].code.length > 0, "SWAP_UNISWAPV2_HOOK_ROUTER_NOT_DEPLOYED"
            );
            hooks[54] = _createSafeHookDeploymentWithArgs(
                SWAP_UNISWAPV2_HOOK_KEY,
                "SwapUniswapV2Hook",
                env,
                abi.encode(configuration.uniswapV2SwapRouters[chainId], configuration.nativeTokens[chainId])
            );
            hooks[55] = _createSafeHookDeploymentWithArgs(
                APPROVE_AND_SWAP_UNISWAPV2_HOOK_KEY,
                "ApproveAndSwapUniswapV2Hook",
                env,
                abi.encode(configuration.uniswapV2SwapRouters[chainId], configuration.nativeTokens[chainId])
            );
        } else {
            console2.log("SKIPPED SwapUniswapV2Hook: Uniswap V2 SwapRouter not available on chain", chainId);
            console2.log("SKIPPED ApproveAndSwapUniswapV2Hook: Uniswap V2 SwapRouter not available on chain", chainId);
            hooks[54] = HookDeployment("", "", ""); // Empty deployment
            hooks[55] = HookDeployment("", "", ""); // Empty deployment
        }

        // Stargate Bridge Hooks - Only require SuperValidator (pool address is in user-signed data)
        {
            address stargateValidator = _getContract(chainId, SUPER_VALIDATOR_KEY);
            require(stargateValidator != address(0), "STARGATE_HOOK_VALIDATOR_PARAM_ZERO");
            require(stargateValidator.code.length > 0, "STARGATE_HOOK_VALIDATOR_NOT_DEPLOYED");

            // V1 hooks
            hooks[62] = _createSafeHookDeploymentWithArgs(
                STARGATE_SEND_HOOK_KEY, "StargateSendHook", env, abi.encode(stargateValidator)
            );
            hooks[63] = _createSafeHookDeploymentWithArgs(
                APPROVE_AND_STARGATE_SEND_HOOK_KEY, "ApproveAndStargateSendHook", env, abi.encode(stargateValidator)
            );

            // V2 hooks (compact 2-field compose format — paired with StargateAdapterV2)
            hooks[74] = _createSafeHookDeploymentWithArgs(
                STARGATE_SEND_HOOK_V2_KEY, "StargateSendHookV2", env, abi.encode(stargateValidator)
            );
            hooks[75] = _createSafeHookDeploymentWithArgs(
                APPROVE_AND_STARGATE_SEND_HOOK_V2_KEY,
                "ApproveAndStargateSendHookV2",
                env,
                abi.encode(stargateValidator)
            );
        }

        // ClaimFailedTransferHook — no constructor args
        hooks[70] = _createSafeHookDeployment(CLAIM_FAILED_TRANSFER_HOOK_KEY, "ClaimFailedTransferHook", env);

        // CCTP V2 Bridge hooks (same TokenMessengerV2 address on all chains via CREATE2)
        {
            address cctpValidator = _getContract(chainId, SUPER_VALIDATOR_KEY);
            require(cctpValidator != address(0), "CCTP_HOOK_VALIDATOR_PARAM_ZERO");
            require(cctpValidator.code.length > 0, "CCTP_HOOK_VALIDATOR_NOT_DEPLOYED");

            hooks[64] = _createSafeHookDeploymentWithArgs(
                CCTP_SEND_HOOK_KEY, "CCTPSendHook", env, abi.encode(CCTP_V2_TOKEN_MESSENGER, cctpValidator)
            );
            hooks[65] = _createSafeHookDeploymentWithArgs(
                APPROVE_AND_CCTP_SEND_HOOK_KEY,
                "ApproveAndCCTPSendHook",
                env,
                abi.encode(CCTP_V2_TOKEN_MESSENGER, cctpValidator)
            );
        }

        // ODOS V3 Swap Hooks - Only deploy if available on this chain
        if (availability.swapOdosV3Hooks) {
            require(configuration.odosRouterV3s[chainId] != address(0), "SWAP_ODOSV3_HOOK_ROUTER_PARAM_ZERO");
            require(configuration.odosRouterV3s[chainId].code.length > 0, "SWAP_ODOSV3_HOOK_ROUTER_NOT_DEPLOYED");
            hooks[66] = _createSafeHookDeploymentWithArgs(
                SWAP_ODOSV3_HOOK_KEY, "SwapOdosV3Hook", env, abi.encode(configuration.odosRouterV3s[chainId])
            );
            hooks[67] = _createSafeHookDeploymentWithArgs(
                APPROVE_AND_SWAP_ODOSV3_HOOK_KEY,
                "ApproveAndSwapOdosV3Hook",
                env,
                abi.encode(configuration.odosRouterV3s[chainId])
            );
        } else {
            console2.log(" SKIPPED ODOS V3 Swap Hooks deployment: Not available on chain", chainId);
            hooks[66] = HookDeployment("", "", ""); // Empty deployment
            hooks[67] = HookDeployment("", "", ""); // Empty deployment
        }

        // OpenOcean Hooks - Only deploy if available on this chain
        if (availability.swapOpenOceanHooks) {
            require(configuration.openOceanRouters[chainId] != address(0), "OPENOCEAN_HOOK_ROUTER_PARAM_ZERO");
            require(configuration.openOceanRouters[chainId].code.length > 0, "OPENOCEAN_HOOK_ROUTER_NOT_DEPLOYED");
            require(configuration.openOceanReferrers[chainId] != address(0), "OPENOCEAN_HOOK_REFERRER_PARAM_ZERO");
            hooks[68] = _createSafeHookDeploymentWithArgs(
                SWAP_OPENOCEAN_HOOK_KEY,
                "SwapOpenOceanHook",
                env,
                abi.encode(
                    configuration.openOceanRouters[chainId],
                    configuration.openOceanReferrers[chainId],
                    configuration.nativeTokens[chainId]
                )
            );
            hooks[69] = _createSafeHookDeploymentWithArgs(
                APPROVE_AND_SWAP_OPENOCEAN_HOOK_KEY,
                "ApproveAndSwapOpenOceanHook",
                env,
                abi.encode(
                    configuration.openOceanRouters[chainId],
                    configuration.openOceanReferrers[chainId],
                    configuration.nativeTokens[chainId]
                )
            );
        } else {
            console2.log(" SKIPPED OpenOcean Hooks deployment: Not available on chain", chainId);
            hooks[68] = HookDeployment("", "", ""); // Empty deployment
            hooks[69] = HookDeployment("", "", ""); // Empty deployment
        }

        // UniswapV3 SwapRouter02 Hooks - Only deploy if V3 SwapRouter02 available on this chain
        if (availability.swapUniswapV3Router02Hooks) {
            hooks[71] = _createSafeHookDeploymentWithArgs(
                SWAP_UNISWAPV3_ROUTER02_HOOK_KEY,
                "SwapUniswapV3Router02Hook",
                env,
                abi.encode(configuration.uniswapV3SwapRouter02s[chainId])
            );
            hooks[72] = _createSafeHookDeploymentWithArgs(
                APPROVE_AND_SWAP_UNISWAPV3_ROUTER02_HOOK_KEY,
                "ApproveAndSwapUniswapV3Router02Hook",
                env,
                abi.encode(configuration.uniswapV3SwapRouter02s[chainId])
            );
        } else {
            console2.log("SKIPPED SwapUniswapV3Router02Hook: Uniswap V3 SwapRouter02 not available on chain", chainId);
            console2.log(
                "SKIPPED ApproveAndSwapUniswapV3Router02Hook: Uniswap V3 SwapRouter02 not available on chain", chainId
            );
            hooks[71] = HookDeployment("", "", ""); // Empty deployment
            hooks[72] = HookDeployment("", "", ""); // Empty deployment
        }

        // Withdraw7540VaultHook — no constructor args
        hooks[73] = _createSafeHookDeployment(WITHDRAW_7540_VAULT_HOOK_KEY, "Withdraw7540VaultHook", env);

        // Across Bridge Hooks V2 (compact 2-field message format — paired with AcrossV3AdapterV2)
        if (availability.acrossV3AdapterV2) {
            hooks[76] = _createSafeHookDeploymentWithArgs(
                ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_V2_KEY,
                "AcrossSendFundsAndExecuteOnDstHookV2",
                env,
                abi.encode(configuration.acrossSpokePoolV3s[chainId], superValidator)
            );
            hooks[77] = _createSafeHookDeploymentWithArgs(
                APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_V2_KEY,
                "ApproveAndAcrossSendFundsAndExecuteOnDstHookV2",
                env,
                abi.encode(configuration.acrossSpokePoolV3s[chainId], superValidator)
            );
        } else {
            console2.log(" SKIPPED AcrossSendFundsAndExecuteOnDstHookV2 deployment: Not available on chain", chainId);
            console2.log(
                " SKIPPED ApproveAndAcrossSendFundsAndExecuteOnDstHookV2 deployment: Not available on chain", chainId
            );
            hooks[76] = HookDeployment("", "", ""); // Empty deployment
            hooks[77] = HookDeployment("", "", ""); // Empty deployment
        }

        // Aerodrome Universal Router hooks - Base only
        if (availability.swapAerodromeUniversalRouterHooks) {
            address aerodromeRouter = configuration.aerodromeUniversalRouters[chainId];
            require(aerodromeRouter != address(0), "AERODROME_HOOK_ROUTER_PARAM_ZERO");
            require(aerodromeRouter.code.length > 0, "AERODROME_HOOK_ROUTER_NOT_DEPLOYED");
            require(
                aerodromeRouter.codehash == AERODROME_UNIVERSAL_ROUTER_BASE_RUNTIME_HASH,
                "AERODROME_HOOK_ROUTER_RUNTIME_HASH_MISMATCH"
            );
            hooks[78] = _createSafeHookDeploymentWithArgs(
                SWAP_AERODROME_UNIVERSAL_ROUTER_HOOK_KEY,
                "SwapAerodromeUniversalRouterHook",
                env,
                abi.encode(aerodromeRouter)
            );
            hooks[79] = _createSafeHookDeploymentWithArgs(
                APPROVE_AND_SWAP_AERODROME_UNIVERSAL_ROUTER_HOOK_KEY,
                "ApproveAndSwapAerodromeUniversalRouterHook",
                env,
                abi.encode(aerodromeRouter)
            );
        } else {
            console2.log(" SKIPPED Aerodrome Universal Router hooks deployment: Not available on chain", chainId);
            hooks[78] = HookDeployment("", "", "");
            hooks[79] = HookDeployment("", "", "");
        }

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

            // Use saltOverride if provided, otherwise use name for salt
            string memory saltName = bytes(hook.saltOverride).length > 0 ? hook.saltOverride : hook.name;
            addresses[i] = __deployContractIfNeeded(hook.name, chainId, __getSalt(saltName), hook.creationCode);

            // Check if deployment was skipped due to missing bytecode
            if (addresses[i] == address(0)) {
                console2.log(" Hook deployment skipped (bytecode not found):", hook.name);
                continue;
            }

            // Validate each hook was deployed successfully
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
        hookAddresses.setOperator7540Hook =
            Strings.equal(hooks[15].name, SET_OPERATOR_7540_HOOK_KEY) ? addresses[15] : address(0);
        hookAddresses.setSlippageHook =
            Strings.equal(hooks[16].name, SET_SLIPPAGE_HOOK_KEY) ? addresses[16] : address(0);
        hookAddresses.swap1InchHook = Strings.equal(hooks[17].name, SWAP_1INCH_HOOK_KEY) ? addresses[17] : address(0);
        hookAddresses.swapOdosHook = Strings.equal(hooks[18].name, SWAP_ODOSV2_HOOK_KEY) ? addresses[18] : address(0);
        hookAddresses.approveAndSwapOdosHook =
            Strings.equal(hooks[19].name, APPROVE_AND_SWAP_ODOSV2_HOOK_KEY) ? addresses[19] : address(0);
        hookAddresses.pendleRouterSwapHook =
            Strings.equal(hooks[20].name, PENDLE_ROUTER_SWAP_HOOK_KEY) ? addresses[20] : address(0);
        hookAddresses.pendleRouterRedeemHook =
            Strings.equal(hooks[21].name, PENDLE_ROUTER_REDEEM_HOOK_KEY) ? addresses[21] : address(0);
        hookAddresses.pendleUnifiedHook =
            Strings.equal(hooks[45].name, PENDLE_UNIFIED_HOOK_KEY) ? addresses[45] : address(0);
        hookAddresses.recordPurchasePendlePTAmortizedOracleHook = Strings.equal(
                hooks[22].name, RECORD_PURCHASE_PENDLE_PT_AMORTIZED_ORACLE_HOOK_KEY
            )
            ? addresses[22]
            : address(0);
        hookAddresses.recordRedemptionPendlePTAmortizedOracleHook = Strings.equal(
                hooks[23].name, RECORD_REDEMPTION_PENDLE_PT_AMORTIZED_ORACLE_HOOK_KEY
            )
            ? addresses[23]
            : address(0);
        hookAddresses.recordPurchasePendlePTAmortizedOracleHookV2 = Strings.equal(
                hooks[46].name, RECORD_PURCHASE_PENDLE_PT_AMORTIZED_ORACLE_HOOK_V2_KEY
            )
            ? addresses[46]
            : address(0);
        hookAddresses.recordRedemptionPendlePTAmortizedOracleHookV2 = Strings.equal(
                hooks[47].name, RECORD_REDEMPTION_PENDLE_PT_AMORTIZED_ORACLE_HOOK_V2_KEY
            )
            ? addresses[47]
            : address(0);
        hookAddresses.acrossSendFundsAndExecuteOnDstHook =
            Strings.equal(hooks[24].name, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY) ? addresses[24] : address(0);
        hookAddresses.approveAndAcrossSendFundsAndExecuteOnDstHook = Strings.equal(
                hooks[25].name, APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY
            )
            ? addresses[25]
            : address(0);
        // Across Bridge hooks V2 (compact 2-field message format)
        hookAddresses.acrossSendFundsAndExecuteOnDstHookV2 = Strings.equal(
                hooks[76].name, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_V2_KEY
            )
            ? addresses[76]
            : address(0);
        hookAddresses.approveAndAcrossSendFundsAndExecuteOnDstHookV2 = Strings.equal(
                hooks[77].name, APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_V2_KEY
            )
            ? addresses[77]
            : address(0);
        hookAddresses.deBridgeSendOrderAndExecuteOnDstHook =
            Strings.equal(hooks[26].name, DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY) ? addresses[26] : address(0);
        hookAddresses.deBridgeCancelOrderHook =
            Strings.equal(hooks[27].name, DEBRIDGE_CANCEL_ORDER_HOOK_KEY) ? addresses[27] : address(0);
        hookAddresses.ethenaCooldownSharesHook =
            Strings.equal(hooks[28].name, ETHENA_COOLDOWN_SHARES_HOOK_KEY) ? addresses[28] : address(0);
        hookAddresses.ethenaUnstakeHook =
            Strings.equal(hooks[29].name, ETHENA_UNSTAKE_HOOK_KEY) ? addresses[29] : address(0);
        hookAddresses.cancelDepositRequest7540Hook =
            Strings.equal(hooks[30].name, CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY) ? addresses[30] : address(0);
        hookAddresses.cancelRedeemRequest7540Hook =
            Strings.equal(hooks[31].name, CANCEL_REDEEM_REQUEST_7540_HOOK_KEY) ? addresses[31] : address(0);
        hookAddresses.claimCancelDepositRequest7540Hook =
            Strings.equal(hooks[32].name, CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY) ? addresses[32] : address(0);
        hookAddresses.claimCancelRedeemRequest7540Hook =
            Strings.equal(hooks[33].name, CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY) ? addresses[33] : address(0);
        hookAddresses.offrampTokensHook =
            Strings.equal(hooks[34].name, OFFRAMP_TOKENS_HOOK_KEY) ? addresses[34] : address(0);
        hookAddresses.markRootAsUsedHook =
            Strings.equal(hooks[35].name, MARK_ROOT_AS_USED_HOOK_KEY) ? addresses[35] : address(0);
        hookAddresses.merklClaimRewardHook =
            Strings.equal(hooks[36].name, MERKL_CLAIM_REWARD_HOOK_KEY) ? addresses[36] : address(0);
        hookAddresses.circleGatewayWalletHook =
            Strings.equal(hooks[37].name, CIRCLE_GATEWAY_WALLET_HOOK_KEY) ? addresses[37] : address(0);
        hookAddresses.circleGatewayMinterHook =
            Strings.equal(hooks[38].name, CIRCLE_GATEWAY_MINTER_HOOK_KEY) ? addresses[38] : address(0);
        hookAddresses.circleGatewayAddDelegateHook =
            Strings.equal(hooks[39].name, CIRCLE_GATEWAY_ADD_DELEGATE_HOOK_KEY) ? addresses[39] : address(0);
        hookAddresses.circleGatewayRemoveDelegateHook =
            Strings.equal(hooks[40].name, CIRCLE_GATEWAY_REMOVE_DELEGATE_HOOK_KEY) ? addresses[40] : address(0);
        hookAddresses.swapUniswapV4Hook =
            Strings.equal(hooks[41].name, SWAP_UNISWAPV4_HOOK_KEY) ? addresses[41] : address(0);
        hookAddresses.swapUniswapV3Hook =
            Strings.equal(hooks[42].name, SWAP_UNISWAPV3_HOOK_KEY) ? addresses[42] : address(0);
        hookAddresses.approveAndSwapUniswapV3Hook =
            Strings.equal(hooks[43].name, APPROVE_AND_SWAP_UNISWAPV3_HOOK_KEY) ? addresses[43] : address(0);
        hookAddresses.transferHook = Strings.equal(hooks[44].name, TRANSFER_HOOK_KEY) ? addresses[44] : address(0);
        hookAddresses.swapSparkPsmExactInHook =
            Strings.equal(hooks[48].name, SWAP_SPARK_PSM_EXACT_IN_HOOK_KEY) ? addresses[48] : address(0);
        hookAddresses.approveAndSwapSparkPsmExactInHook =
            Strings.equal(hooks[49].name, APPROVE_AND_SWAP_SPARK_PSM_EXACT_IN_HOOK_KEY) ? addresses[49] : address(0);
        hookAddresses.swapSparkPsmExactOutHook =
            Strings.equal(hooks[50].name, SWAP_SPARK_PSM_EXACT_OUT_HOOK_KEY) ? addresses[50] : address(0);
        hookAddresses.approveAndSwapSparkPsmExactOutHook =
            Strings.equal(hooks[51].name, APPROVE_AND_SWAP_SPARK_PSM_EXACT_OUT_HOOK_KEY) ? addresses[51] : address(0);
        hookAddresses.swapKyberSwapHook =
            Strings.equal(hooks[52].name, SWAP_KYBERSWAP_HOOK_KEY) ? addresses[52] : address(0);
        hookAddresses.approveAndSwapKyberSwapHook =
            Strings.equal(hooks[53].name, APPROVE_AND_SWAP_KYBERSWAP_HOOK_KEY) ? addresses[53] : address(0);
        hookAddresses.swapUniswapV2Hook =
            Strings.equal(hooks[54].name, SWAP_UNISWAPV2_HOOK_KEY) ? addresses[54] : address(0);
        hookAddresses.approveAndSwapUniswapV2Hook =
            Strings.equal(hooks[55].name, APPROVE_AND_SWAP_UNISWAPV2_HOOK_KEY) ? addresses[55] : address(0);
        hookAddresses.swapOdosV3Hook = Strings.equal(hooks[66].name, SWAP_ODOSV3_HOOK_KEY) ? addresses[66] : address(0);
        hookAddresses.approveAndSwapOdosV3Hook =
            Strings.equal(hooks[67].name, APPROVE_AND_SWAP_ODOSV3_HOOK_KEY) ? addresses[67] : address(0);
        hookAddresses.swapOpenOceanHook =
            Strings.equal(hooks[68].name, SWAP_OPENOCEAN_HOOK_KEY) ? addresses[68] : address(0);
        hookAddresses.approveAndSwapOpenOceanHook =
            Strings.equal(hooks[69].name, APPROVE_AND_SWAP_OPENOCEAN_HOOK_KEY) ? addresses[69] : address(0);
        hookAddresses.swapUniswapV3Router02Hook =
            Strings.equal(hooks[71].name, SWAP_UNISWAPV3_ROUTER02_HOOK_KEY) ? addresses[71] : address(0);
        hookAddresses.approveAndSwapUniswapV3Router02Hook =
            Strings.equal(hooks[72].name, APPROVE_AND_SWAP_UNISWAPV3_ROUTER02_HOOK_KEY) ? addresses[72] : address(0);

        // ERC-7540 WithId hooks
        hookAddresses.cancelDepositRequestWithId7540Hook =
            Strings.equal(hooks[56].name, CANCEL_DEPOSIT_REQUEST_WITH_ID_7540_HOOK_KEY) ? addresses[56] : address(0);
        hookAddresses.cancelRedeemRequestWithId7540Hook =
            Strings.equal(hooks[57].name, CANCEL_REDEEM_REQUEST_WITH_ID_7540_HOOK_KEY) ? addresses[57] : address(0);
        hookAddresses.claimCancelDepositRequestWithId7540Hook = Strings.equal(
                hooks[58].name, CLAIM_CANCEL_DEPOSIT_REQUEST_WITH_ID_7540_HOOK_KEY
            )
            ? addresses[58]
            : address(0);
        hookAddresses.claimCancelRedeemRequestWithId7540Hook = Strings.equal(
                hooks[59].name, CLAIM_CANCEL_REDEEM_REQUEST_WITH_ID_7540_HOOK_KEY
            )
            ? addresses[59]
            : address(0);
        hookAddresses.redeemWithId7540VaultHook =
            Strings.equal(hooks[60].name, REDEEM_WITH_ID_7540_VAULT_HOOK_KEY) ? addresses[60] : address(0);
        hookAddresses.withdrawWithId7540VaultHook =
            Strings.equal(hooks[61].name, WITHDRAW_WITH_ID_7540_VAULT_HOOK_KEY) ? addresses[61] : address(0);

        // Stargate Bridge hooks (V1)
        hookAddresses.stargateSendHook =
            Strings.equal(hooks[62].name, STARGATE_SEND_HOOK_KEY) ? addresses[62] : address(0);
        hookAddresses.approveAndStargateSendHook =
            Strings.equal(hooks[63].name, APPROVE_AND_STARGATE_SEND_HOOK_KEY) ? addresses[63] : address(0);
        // Stargate Bridge hooks (V2 — compact compose format)
        hookAddresses.stargateSendHookV2 =
            Strings.equal(hooks[74].name, STARGATE_SEND_HOOK_V2_KEY) ? addresses[74] : address(0);
        hookAddresses.approveAndStargateSendHookV2 =
            Strings.equal(hooks[75].name, APPROVE_AND_STARGATE_SEND_HOOK_V2_KEY) ? addresses[75] : address(0);
        hookAddresses.claimFailedTransferHook =
            Strings.equal(hooks[70].name, CLAIM_FAILED_TRANSFER_HOOK_KEY) ? addresses[70] : address(0);

        // Withdraw7540VaultHook
        hookAddresses.withdraw7540VaultHook =
            Strings.equal(hooks[73].name, WITHDRAW_7540_VAULT_HOOK_KEY) ? addresses[73] : address(0);

        // CCTP V2 Bridge hooks
        hookAddresses.cctpSendHook = Strings.equal(hooks[64].name, CCTP_SEND_HOOK_KEY) ? addresses[64] : address(0);
        hookAddresses.approveAndCCTPSendHook =
            Strings.equal(hooks[65].name, APPROVE_AND_CCTP_SEND_HOOK_KEY) ? addresses[65] : address(0);

        // Aerodrome Universal Router hooks
        hookAddresses.swapAerodromeUniversalRouterHook =
            Strings.equal(hooks[78].name, SWAP_AERODROME_UNIVERSAL_ROUTER_HOOK_KEY) ? addresses[78] : address(0);
        hookAddresses.approveAndSwapAerodromeUniversalRouterHook = Strings.equal(
                hooks[79].name, APPROVE_AND_SWAP_AERODROME_UNIVERSAL_ROUTER_HOOK_KEY
            )
            ? addresses[79]
            : address(0);

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
        require(hookAddresses.setOperator7540Hook != address(0), "SET_OPERATOR_7540_HOOK_NOT_ASSIGNED");
        require(hookAddresses.setSlippageHook != address(0), "SET_SLIPPAGE_HOOK_NOT_ASSIGNED");
        // Only validate hooks that should be available on this chain
        if (availability.swap1InchHook) {
            require(hookAddresses.swap1InchHook != address(0), "SWAP_1INCH_HOOK_NOT_ASSIGNED");
        }
        if (availability.swapOdosHooks) {
            require(hookAddresses.swapOdosHook != address(0), "SWAP_ODOS_HOOK_NOT_ASSIGNED");
            require(hookAddresses.approveAndSwapOdosHook != address(0), "APPROVE_AND_SWAP_ODOS_HOOK_NOT_ASSIGNED");
        }
        if (availability.swapKyberSwapHooks) {
            require(hookAddresses.swapKyberSwapHook != address(0), "SWAP_KYBERSWAP_HOOK_NOT_ASSIGNED");
            require(
                hookAddresses.approveAndSwapKyberSwapHook != address(0), "APPROVE_AND_SWAP_KYBERSWAP_HOOK_NOT_ASSIGNED"
            );
        }
        if (availability.swapUniswapV2Hooks) {
            require(hookAddresses.swapUniswapV2Hook != address(0), "SWAP_UNISWAPV2_HOOK_NOT_ASSIGNED");
            require(
                hookAddresses.approveAndSwapUniswapV2Hook != address(0), "APPROVE_AND_SWAP_UNISWAPV2_HOOK_NOT_ASSIGNED"
            );
        }
        if (availability.swapOdosV3Hooks) {
            require(hookAddresses.swapOdosV3Hook != address(0), "SWAP_ODOSV3_HOOK_NOT_ASSIGNED");
            require(hookAddresses.approveAndSwapOdosV3Hook != address(0), "APPROVE_AND_SWAP_ODOSV3_HOOK_NOT_ASSIGNED");
        }
        if (availability.swapAerodromeUniversalRouterHooks) {
            require(
                hookAddresses.swapAerodromeUniversalRouterHook != address(0),
                "SWAP_AERODROME_UNIVERSAL_ROUTER_HOOK_NOT_ASSIGNED"
            );
            require(
                hookAddresses.approveAndSwapAerodromeUniversalRouterHook != address(0),
                "APPROVE_AND_SWAP_AERODROME_UNIVERSAL_ROUTER_HOOK_NOT_ASSIGNED"
            );
        }
        if (availability.swapOpenOceanHooks) {
            require(hookAddresses.swapOpenOceanHook != address(0), "SWAP_OPENOCEAN_HOOK_NOT_ASSIGNED");
            require(
                hookAddresses.approveAndSwapOpenOceanHook != address(0), "APPROVE_AND_SWAP_OPENOCEAN_HOOK_NOT_ASSIGNED"
            );
        }
        if (availability.acrossV3Adapter) {
            require(
                hookAddresses.acrossSendFundsAndExecuteOnDstHook != address(0),
                "ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_NOT_ASSIGNED"
            );
        }
        if (availability.acrossV3AdapterV2) {
            require(
                hookAddresses.acrossSendFundsAndExecuteOnDstHookV2 != address(0),
                "ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_V2_NOT_ASSIGNED"
            );
            require(
                hookAddresses.approveAndAcrossSendFundsAndExecuteOnDstHookV2 != address(0),
                "APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_V2_NOT_ASSIGNED"
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
        require(
            hookAddresses.cancelDepositRequestWithId7540Hook != address(0),
            "CANCEL_DEPOSIT_REQUEST_WITH_ID_7540_HOOK_NOT_ASSIGNED"
        );
        require(
            hookAddresses.cancelRedeemRequestWithId7540Hook != address(0),
            "CANCEL_REDEEM_REQUEST_WITH_ID_7540_HOOK_NOT_ASSIGNED"
        );
        require(
            hookAddresses.claimCancelDepositRequestWithId7540Hook != address(0),
            "CLAIM_CANCEL_DEPOSIT_REQUEST_WITH_ID_7540_HOOK_NOT_ASSIGNED"
        );
        require(
            hookAddresses.claimCancelRedeemRequestWithId7540Hook != address(0),
            "CLAIM_CANCEL_REDEEM_REQUEST_WITH_ID_7540_HOOK_NOT_ASSIGNED"
        );
        require(hookAddresses.redeemWithId7540VaultHook != address(0), "REDEEM_WITH_ID_7540_VAULT_HOOK_NOT_ASSIGNED");
        require(
            hookAddresses.withdrawWithId7540VaultHook != address(0), "WITHDRAW_WITH_ID_7540_VAULT_HOOK_NOT_ASSIGNED"
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
        require(hookAddresses.transferHook != address(0), "TRANSFER_HOOK_NOT_ASSIGNED");
        require(hookAddresses.claimFailedTransferHook != address(0), "CLAIM_FAILED_TRANSFER_HOOK_NOT_ASSIGNED");

        console2.log(" All hooks deployed and validated successfully with comprehensive dependency checking! ");

        return hookAddresses;
    }

    function _deployOracles(uint64 chainId, uint256 env) private {
        console2.log("Starting oracle deployment with parameter validation...");

        // Oracle array indices - used for config updates after deployment
        // IMPORTANT: If oracle order changes, update these indices AND the validation below
        uint256 pendlePTAmortizedOracleIndex = 8;
        uint256 pendlePTAmortizedOracleV2Index = 9;

        uint256 len = 18;
        OracleDeployment[] memory oracles = new OracleDeployment[](len);
        address[] memory oracleAddresses = new address[](len);

        // Validate SuperLedgerConfiguration address before using it
        address superLedgerConfig = _getContract(chainId, SUPER_LEDGER_CONFIGURATION_KEY);
        require(superLedgerConfig != address(0), "ORACLE_SUPER_LEDGER_CONFIG_PARAM_ZERO");
        require(superLedgerConfig.code.length > 0, "ORACLE_SUPER_LEDGER_CONFIG_NOT_DEPLOYED");
        console2.log(" Validated SuperLedgerConfiguration for oracles:", superLedgerConfig);

        // Deploy MorphoBlueMarketRegistry first (dependency for MorphoBlueYieldSourceOracle)
        address morphoRegistry = address(0);
        if (__checkBytecodeExists("MorphoBlueMarketRegistry", env)) {
            morphoRegistry = __deployContractIfNeeded(
                MORPHO_BLUE_MARKET_REGISTRY_KEY,
                chainId,
                __getSalt(MORPHO_BLUE_MARKET_REGISTRY_KEY),
                abi.encodePacked(__getBytecode("MorphoBlueMarketRegistry", env), abi.encode(DEPLOYER))
            );
            console2.log(" MorphoBlueMarketRegistry deployed:", morphoRegistry);
        }

        // Deploy UniV3CLPRegistry (dependency for UniV3CLPYieldSourceOracle)
        address univ3CLPRegistry = address(0);
        if (__checkBytecodeExists("UniV3CLPRegistry", env)) {
            univ3CLPRegistry = __deployContractIfNeeded(
                UNIV3_CLP_REGISTRY_KEY,
                chainId,
                __getSalt(UNIV3_CLP_REGISTRY_KEY),
                abi.encodePacked(__getBytecode("UniV3CLPRegistry", env), abi.encode(DEPLOYER))
            );
            console2.log(" UniV3CLPRegistry deployed:", univ3CLPRegistry);
        }

        // Deploy oracles with validated constructor parameters
        oracles[0] = _createSafeOracleDeploymentWithArgs(
            ERC4626_YIELD_SOURCE_ORACLE_KEY, "ERC4626YieldSourceOracle", env, abi.encode(superLedgerConfig)
        );
        oracles[1] = _createSafeOracleDeploymentWithArgs(
            ERC5115_YIELD_SOURCE_ORACLE_KEY, "ERC5115YieldSourceOracle", env, abi.encode(superLedgerConfig)
        );
        oracles[2] = _createSafeOracleDeploymentWithArgs(
            PENDLE_PT_YIELD_SOURCE_ORACLE_KEY, "PendlePTYieldSourceOracle", env, abi.encode(superLedgerConfig)
        );
        oracles[3] = _createSafeOracleDeploymentWithArgs(
            SPECTRA_PT_YIELD_SOURCE_ORACLE_KEY, "SpectraPTYieldSourceOracle", env, abi.encode(superLedgerConfig)
        );
        oracles[4] = _createSafeOracleDeploymentWithArgs(
            STAKING_YIELD_SOURCE_ORACLE_KEY, "StakingYieldSourceOracle", env, abi.encode(superLedgerConfig)
        );
        oracles[5] = _createSafeOracleDeployment(SUPER_YIELD_SOURCE_ORACLE_KEY, "SuperYieldSourceOracle", env);
        oracles[6] = _createSafeOracleDeploymentWithArgs(
            SUPER_VAULT_YIELD_SOURCE_ORACLE_KEY, "SuperVaultYieldSourceOracle", env, abi.encode(superLedgerConfig)
        );
        oracles[7] = _createSafeOracleDeploymentWithArgs(
            YO_YIELD_SOURCE_ORACLE_KEY, "YoYieldSourceOracle", env, abi.encode(superLedgerConfig)
        );
        // PendlePTAmortizedOracle and V2 (admin + superLedgerConfig)
        oracles[8] = _createSafeOracleDeploymentWithArgs(
            PENDLE_PT_AMORTIZED_ORACLE_KEY, "PendlePTAmortizedOracle", env, abi.encode(DEPLOYER, superLedgerConfig)
        );
        oracles[9] = _createSafeOracleDeploymentWithArgs(
            PENDLE_PT_AMORTIZED_ORACLE_V2_KEY, "PendlePTAmortizedOracleV2", env, abi.encode(DEPLOYER, superLedgerConfig)
        );
        oracles[10] = _createSafeOracleDeploymentWithArgs(
            FIRELIGHT_YIELD_SOURCE_ORACLE_KEY, "FirelightYieldSourceOracle", env, abi.encode(superLedgerConfig)
        );
        // DETHYieldSourceOracle (superLedgerConfig + foundation)
        // Only deploy if a DETH foundation address is configured for this chain
        if (configuration.dethFoundation != address(0)) {
            oracles[11] = _createSafeOracleDeploymentWithArgs(
                DETH_YIELD_SOURCE_ORACLE_KEY,
                "DETHYieldSourceOracle",
                env,
                abi.encode(superLedgerConfig, configuration.dethFoundation)
            );
        }
        // ERC7540YieldSourceOracle (superLedgerConfig + requestId=0)
        oracles[12] = _createSafeOracleDeploymentWithArgs(
            ERC7540_YIELD_SOURCE_ORACLE_KEY, "ERC7540YieldSourceOracle", env, abi.encode(superLedgerConfig, uint256(0))
        );
        // SpectraMetaVaultOracle (superLedgerConfig + requestId=0)
        oracles[13] = _createSafeOracleDeploymentWithArgs(
            SPECTRA_META_VAULT_ORACLE_KEY, "SpectraMetaVaultOracle", env, abi.encode(superLedgerConfig, uint256(0))
        );
        // MorphoBlueMarketRegistry is deployed above (not via oracle array) — slot 14 stays empty
        // MorphoBlueYieldSourceOracle (superLedgerConfig + registry)
        if (morphoRegistry != address(0)) {
            oracles[15] = _createSafeOracleDeploymentWithArgs(
                MORPHO_BLUE_YIELD_SOURCE_ORACLE_KEY,
                "MorphoBlueYieldSourceOracle",
                env,
                abi.encode(superLedgerConfig, morphoRegistry)
            );
        }
        // UniV3CLPRegistry is deployed above (not via oracle array) — slot 16 stays empty
        // UniV3CLPYieldSourceOracle (superLedgerConfig + registry)
        if (univ3CLPRegistry != address(0)) {
            oracles[17] = _createSafeOracleDeploymentWithArgs(
                UNIV3_CLP_YIELD_SOURCE_ORACLE_KEY,
                "UniV3CLPYieldSourceOracle",
                env,
                abi.encode(superLedgerConfig, univ3CLPRegistry)
            );
        }

        console2.log("Deploying", len, "oracles with parameter validation...");
        for (uint256 i = 0; i < len; ++i) {
            OracleDeployment memory oracle = oracles[i];

            // Skip empty deployments (oracles not available due to missing bytecode)
            if (bytes(oracle.name).length == 0) {
                console2.log("Skipping empty oracle deployment at index", i);
                oracleAddresses[i] = address(0);
                continue;
            }

            console2.log("Deploying oracle:", oracle.name);

            oracleAddresses[i] =
                __deployContractIfNeeded(oracle.name, chainId, __getSalt(oracle.name), oracle.creationCode);

            // Check if deployment was skipped due to missing bytecode
            if (oracleAddresses[i] == address(0)) {
                console2.log(" Oracle deployment skipped (bytecode not found):", oracle.name);
                continue;
            }

            // Validate each oracle was deployed successfully
            require(oracleAddresses[i].code.length > 0, string(abi.encodePacked("ORACLE_NO_CODE_", oracle.name)));
            console2.log(" Oracle deployed and validated:", oracle.name, "at", oracleAddresses[i]);
        }

        console2.log(" All oracles deployed and validated successfully! ");

        // Update configuration with deployed PendlePTAmortizedOracle addresses for hook deployment
        // Only validate and update if oracle was actually created (non-empty name means bytecode existed)
        if (bytes(oracles[pendlePTAmortizedOracleIndex].name).length > 0) {
            // Validate oracle name matches expected index to catch array reordering bugs
            require(
                Strings.equal(oracles[pendlePTAmortizedOracleIndex].name, "PendlePTAmortizedOracle"),
                "ORACLE_INDEX_MISMATCH: Index 8 is not PendlePTAmortizedOracle"
            );
            if (oracleAddresses[pendlePTAmortizedOracleIndex] != address(0)) {
                configuration.pendlePTAmortizedOracles[chainId] = oracleAddresses[pendlePTAmortizedOracleIndex];
                console2.log(
                    " Updated configuration.pendlePTAmortizedOracles for chain",
                    chainId,
                    "to",
                    oracleAddresses[pendlePTAmortizedOracleIndex]
                );
            }
        }

        if (bytes(oracles[pendlePTAmortizedOracleV2Index].name).length > 0) {
            // Validate oracle name matches expected index to catch array reordering bugs
            require(
                Strings.equal(oracles[pendlePTAmortizedOracleV2Index].name, "PendlePTAmortizedOracleV2"),
                "ORACLE_INDEX_MISMATCH: Index 9 is not PendlePTAmortizedOracleV2"
            );
            if (oracleAddresses[pendlePTAmortizedOracleV2Index] != address(0)) {
                configuration.pendlePTAmortizedOraclesV2[chainId] = oracleAddresses[pendlePTAmortizedOracleV2Index];
                console2.log(
                    " Updated configuration.pendlePTAmortizedOraclesV2 for chain",
                    chainId,
                    "to",
                    oracleAddresses[pendlePTAmortizedOracleV2Index]
                );
            }
        }
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
