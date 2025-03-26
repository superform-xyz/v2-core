// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { Helpers } from "./utils/Helpers.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
// Superform interfaces
import { ISuperRegistry } from "../src/core/interfaces/ISuperRegistry.sol";
import { ISuperExecutor } from "../src/core/interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../src/core/interfaces/accounting/ISuperLedger.sol";
import { ISuperLedgerConfiguration } from "../src/core/interfaces/accounting/ISuperLedgerConfiguration.sol";

// Superform contracts
import { SuperLedger } from "../src/core/accounting/SuperLedger.sol";
import { ERC5115Ledger } from "../src/core/accounting/ERC5115Ledger.sol";
import { SuperLedgerConfiguration } from "../src/core/accounting/SuperLedgerConfiguration.sol";
import { SuperRegistry } from "../src/core/settings/SuperRegistry.sol";
import { SuperExecutor } from "../src/core/executors/SuperExecutor.sol";
import { SuperMerkleValidator } from "../src/core/validators/SuperMerkleValidator.sol";
import { AcrossReceiveFundsAndExecuteGateway } from "../src/core/bridges/AcrossReceiveFundsAndExecuteGateway.sol";
import { IAcrossV3Receiver } from "../src/vendor/bridges/across/IAcrossV3Receiver.sol";

// hooks

// token hooks
// --- erc20
import { ApproveERC20Hook } from "../src/core/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { TransferERC20Hook } from "../src/core/hooks/tokens/erc20/TransferERC20Hook.sol";

// vault hooks
// --- erc5115
import { Deposit5115VaultHook } from "../src/core/hooks/vaults/5115/Deposit5115VaultHook.sol";
import { ApproveAndDeposit5115VaultHook } from "../src/core/hooks/vaults/5115/ApproveAndDeposit5115VaultHook.sol";
import { Redeem5115VaultHook } from "../src/core/hooks/vaults/5115/Redeem5115VaultHook.sol";
// --- erc4626
import { Deposit4626VaultHook } from "../src/core/hooks/vaults/4626/Deposit4626VaultHook.sol";
import { ApproveAndDeposit4626VaultHook } from "../src/core/hooks/vaults/4626/ApproveAndDeposit4626VaultHook.sol";
import { Redeem4626VaultHook } from "../src/core/hooks/vaults/4626/Redeem4626VaultHook.sol";
// -- erc7540
import { Deposit7540VaultHook } from "../src/core/hooks/vaults/7540/Deposit7540VaultHook.sol";
import { RequestDeposit7540VaultHook } from "../src/core/hooks/vaults/7540/RequestDeposit7540VaultHook.sol";
import { ApproveAndRequestDeposit7540VaultHook } from
    "../src/core/hooks/vaults/7540/ApproveAndRequestDeposit7540VaultHook.sol";
import { RequestRedeem7540VaultHook } from "../src/core/hooks/vaults/7540/RequestRedeem7540VaultHook.sol";
import { Withdraw7540VaultHook } from "../src/core/hooks/vaults/7540/Withdraw7540VaultHook.sol";

// bridges hooks
import { AcrossSendFundsAndExecuteOnDstHook } from
    "../src/core/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHook.sol";

// Swap hooks
// --- 1inch
import { Swap1InchHook } from "../src/core/hooks/swappers/1inch/Swap1InchHook.sol";

// --- Odos
import { SwapOdosHook } from "../src/core/hooks/swappers/odos/SwapOdosHook.sol";
import { ApproveAndSwapOdosHook } from "../src/core/hooks/swappers/odos/ApproveAndSwapOdosHook.sol";

// Stake hooks
// --- Gearbox
import { GearboxStakeHook } from "../src/core/hooks/stake/gearbox/GearboxStakeHook.sol";
import { GearboxUnstakeHook } from "../src/core/hooks/stake/gearbox/GearboxUnstakeHook.sol";
import { ApproveAndGearboxStakeHook } from "../src/core/hooks/stake/gearbox/ApproveAndGearboxStakeHook.sol";
// --- Fluid
import { ApproveAndFluidStakeHook } from "../src/core/hooks/stake/fluid/ApproveAndFluidStakeHook.sol";
import { FluidStakeHook } from "../src/core/hooks/stake/fluid/FluidStakeHook.sol";
import { FluidUnstakeHook } from "../src/core/hooks/stake/fluid/FluidUnstakeHook.sol";

// Claim Hooks
// --- Fluid
import { FluidClaimRewardHook } from "../src/core/hooks/claim/fluid/FluidClaimRewardHook.sol";

// --- Gearbox
import { GearboxClaimRewardHook } from "../src/core/hooks/claim/gearbox/GearboxClaimRewardHook.sol";

// --- Yearn
import { YearnClaimOneRewardHook } from "../src/core/hooks/claim/yearn/YearnClaimOneRewardHook.sol";

// Experimental hooks

// --- Ethena
import { EthenaCooldownSharesHook } from "./mocks/unused-hooks/EthenaCooldownSharesHook.sol";
import { EthenaUnstakeHook } from "./mocks/unused-hooks/EthenaUnstakeHook.sol";

// action oracles
import { ERC4626YieldSourceOracle } from "../src/core/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { ERC5115YieldSourceOracle } from "../src/core/accounting/oracles/ERC5115YieldSourceOracle.sol";
import { SuperOracle } from "../src/core/accounting/oracles/SuperOracle.sol";
import { ERC7540YieldSourceOracle } from "../src/core/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { FluidYieldSourceOracle } from "../src/core/accounting/oracles/FluidYieldSourceOracle.sol";
import { GearboxYieldSourceOracle } from "../src/core/accounting/oracles/GearboxYieldSourceOracle.sol";

// external
import {
    RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, AccountType, UserOpData
} from "modulekit/ModuleKit.sol";

import { ExecutionReturnData } from "modulekit/test/RhinestoneModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";

import { AcrossV3Helper } from "pigeon/across/AcrossV3Helper.sol";
import { DebridgeHelper } from "pigeon/debridge/DebridgeHelper.sol";
import { MockOdosRouterV2 } from "./mocks/MockOdosRouterV2.sol";
import { MockTargetExecutor } from "./mocks/MockTargetExecutor.sol";
import "../src/vendor/1inch/I1InchAggregationRouterV6.sol";

import { PeripheryRegistry } from "../src/periphery/PeripheryRegistry.sol";

// SuperformNativePaymaster
import { SuperNativePaymaster } from "../src/core/paymaster/SuperNativePaymaster.sol";

import { SuperGasTank } from "../src/core/paymaster/SuperGasTank.sol";

// Nexus and Rhinestone overrides to allow for SuperformNativePaymaster
import { IAccountFactory } from "modulekit/accounts/factory/interface/IAccountFactory.sol";
import { getFactory, getHelper, getStorageCompliance } from "modulekit/test/utils/Storage.sol";
import { IEntryPoint } from "@account-abstraction/interfaces/IEntryPoint.sol";

import "forge-std/console2.sol";

struct Addresses {
    ISuperLedger superLedger;
    ISuperLedger erc1155Ledger;
    ISuperLedgerConfiguration superLedgerConfiguration;
    ISuperRegistry superRegistry;
    ISuperExecutor superExecutor;
    AcrossReceiveFundsAndExecuteGateway acrossReceiveFundsAndExecuteGateway;
    ApproveERC20Hook approveErc20Hook;
    TransferERC20Hook transferErc20Hook;
    Deposit4626VaultHook deposit4626VaultHook;
    ApproveAndSwapOdosHook approveAndSwapOdosHook;
    ApproveAndFluidStakeHook approveAndFluidStakeHook;
    ApproveAndDeposit4626VaultHook approveAndDeposit4626VaultHook;
    ApproveAndDeposit5115VaultHook approveAndDeposit5115VaultHook;
    ApproveAndRequestDeposit7540VaultHook approveAndRequestDeposit7540VaultHook;
    Redeem4626VaultHook redeem4626VaultHook;
    Deposit5115VaultHook deposit5115VaultHook;
    Redeem5115VaultHook redeem5115VaultHook;
    Deposit7540VaultHook deposit7540VaultHook;
    RequestDeposit7540VaultHook requestDeposit7540VaultHook;
    RequestRedeem7540VaultHook requestRedeem7540VaultHook;
    Withdraw7540VaultHook withdraw7540VaultHook;
    AcrossSendFundsAndExecuteOnDstHook acrossSendFundsAndExecuteOnDstHook;
    Swap1InchHook swap1InchHook;
    SwapOdosHook swapOdosHook;
    GearboxStakeHook gearboxStakeHook;
    GearboxUnstakeHook gearboxUnstakeHook;
    ApproveAndGearboxStakeHook approveAndGearboxStakeHook;
    FluidStakeHook fluidStakeHook;
    FluidUnstakeHook fluidUnstakeHook;
    FluidClaimRewardHook fluidClaimRewardHook;
    GearboxClaimRewardHook gearboxClaimRewardHook;
    YearnClaimOneRewardHook yearnClaimOneRewardHook;
    EthenaCooldownSharesHook ethenaCooldownSharesHook;
    EthenaUnstakeHook ethenaUnstakeHook;
    ERC4626YieldSourceOracle erc4626YieldSourceOracle;
    ERC5115YieldSourceOracle erc5115YieldSourceOracle;
    ERC7540YieldSourceOracle erc7540YieldSourceOracle;
    FluidYieldSourceOracle fluidYieldSourceOracle;
    GearboxYieldSourceOracle gearboxYieldSourceOracle;
    SuperOracle oracleRegistry;
    SuperMerkleValidator superMerkleValidator;
    PeripheryRegistry peripheryRegistry;
    SuperNativePaymaster superNativePaymaster;
    SuperGasTank superGasTank;
    MockTargetExecutor mockTargetExecutor;  
}

contract BaseTest is Helpers, RhinestoneModuleKit {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @dev arrays

    enum HookCategory {
        TokenApprovals,
        VaultDeposits,
        VaultWithdrawals,
        Bridges,
        Swaps,
        Stakes,
        Claims,
        None
    }

    struct Hook {
        string name;
        HookCategory category;
        HookCategory dependency; // Dependant category, can be empty
        address hook;
        bytes description;
    }

    uint64[] public chainIds = [ETH, OP, BASE];

    string[] public chainsNames = [ETHEREUM_KEY, OPTIMISM_KEY, BASE_KEY];

    string[] public underlyingTokens = [DAI_KEY, USDC_KEY, WETH_KEY, SUSDE_KEY, USDE_KEY];

    address[] public spokePoolV3Addresses =
        [CHAIN_1_SPOKE_POOL_V3_ADDRESS, CHAIN_10_SPOKE_POOL_V3_ADDRESS, CHAIN_8453_SPOKE_POOL_V3_ADDRESS];
    address[] public deBridgeGateAddresses =
        [CHAIN_1_DEBRIDGE_GATE_ADDRESS, CHAIN_10_DEBRIDGE_GATE_ADDRESS, CHAIN_8453_DEBRIDGE_GATE_ADDRESS];
    address[] public deBridgeGateAdminAddresses = [
        CHAIN_1_DEBRIDGE_GATE_ADMIN_ADDRESS,
        CHAIN_10_DEBRIDGE_GATE_ADMIN_ADDRESS,
        CHAIN_8453_DEBRIDGE_GATE_ADMIN_ADDRESS
    ];
    mapping(uint64 chainId => address) public SPOKE_POOL_V3_ADDRESSES;
    mapping(uint64 chainId => address) public DEBRIDGE_GATE_ADDRESSES;
    mapping(uint64 chainId => address) public DEBRIDGE_ADMIN_ADDRESSES;

    /// @dev mappings

    mapping(uint64 chainId => mapping(string underlying => address realAddress)) public existingUnderlyingTokens;

    mapping(
        uint64 chainId
            => mapping(string vaultKind => mapping(string vaultName => mapping(string underlying => address realVault)))
    ) public realVaultAddresses;

    mapping(uint64 chainId => mapping(string contractName => address contractAddress)) public contractAddresses;

    mapping(uint64 chainId => mapping(string hookName => address hook)) public hookAddresses;

    mapping(uint64 chainId => mapping(HookCategory category => Hook[] hooksByCategory)) public hooksByCategory;

    mapping(uint64 chainId => mapping(string name => Hook hookInstance)) public hooks;

    mapping(uint64 chainId => AccountInstance accountInstance) public accountInstances;
    mapping(uint64 chainId => AccountInstance[] randomAccountInstances) public randomAccountInstances;

    mapping(uint64 chainId => address odosRouter) public odosRouters;

    // chainID => FORK
    mapping(uint64 chainId => uint256 fork) public FORKS;

    mapping(uint64 chainId => string forkUrl) public RPC_URLS;

    string public ETHEREUM_RPC_URL = vm.envString(ETHEREUM_RPC_URL_KEY); // Native token: ETH
    string public OPTIMISM_RPC_URL = vm.envString(OPTIMISM_RPC_URL_KEY); // Native token: ETH
    string public BASE_RPC_URL = vm.envString(BASE_RPC_URL_KEY); // Native token: ETH

    bool constant DEBUG = false;

    string constant DEFAULT_ACCOUNT = "NEXUS";

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        // deploy accounts
        MANAGER = _deployAccount(MANAGER_KEY, "MANAGER");
        TREASURY = _deployAccount(TREASURY_KEY, "TREASURY");
        SUPER_BUNDLER = _deployAccount(SUPER_BUNDLER_KEY, "SUPER_BUNDLER");
        ACROSS_RELAYER = _deployAccount(ACROSS_RELAYER_KEY, "ACROSS_RELAYER");
        SV_MANAGER = _deployAccount(MANAGER_KEY, "SV_MANAGER");
        STRATEGIST = _deployAccount(STRATEGIST_KEY, "STRATEGIST");
        EMERGENCY_ADMIN = _deployAccount(EMERGENCY_ADMIN_KEY, "EMERGENCY_ADMIN");

        // Setup forks
        _preDeploymentSetup();

        Addresses[] memory A = new Addresses[](chainIds.length);
        // Deploy contracts
        A = _deployContracts(A);

        // Deploy hooks
        A = _deployHooks(A);

        _registerHooks(A);

        // Initialize accounts
        _initializeAccounts(ACCOUNT_COUNT);

        // Register on SuperRegistry
        _setSuperRegistryAddresses();

        // Setup SuperLedger
        _setupSuperLedger();

        // Fund underlying tokens
        _fundUnderlyingTokens(1e18);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Helper function to select a fork and warp to a specific timestamp
    /// @param chainId The chain ID to select
    /// @param timestamp The timestamp to warp to
    function SELECT_FORK_AND_WARP(uint64 chainId, uint256 timestamp) internal {
        vm.selectFork(FORKS[chainId]);
        vm.warp(timestamp);
    }

    /// @dev in case we want to make accounts with SuperMerkleValidator
    function _makeAccount(uint64 chainId, string memory accountNameString) internal returns (AccountInstance memory) {
        bytes32 accountName = keccak256(abi.encode(accountNameString));

        // @dev might need to change account type to custom
        IAccountFactory nexusFactory = IAccountFactory(getFactory(DEFAULT_ACCOUNT));
        address validator = _getContract(chainId, SUPER_MERKLE_VALIDATOR_KEY);
        bytes memory initData = nexusFactory.getInitData(validator, abi.encode(address(this)));
        address account = nexusFactory.getAddress(accountName, initData);
        bytes memory initCode =
            abi.encodePacked(address(nexusFactory), abi.encodeCall(nexusFactory.createAccount, (accountName, initData)));

        AccountInstance memory _accInstance =
            makeAccountInstance(accountName, account, initCode, getHelper(DEFAULT_ACCOUNT));

        _installModule({
            instance: _accInstance,
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: _getContract(chainId, SUPER_EXECUTOR_KEY),
            data: "",
            validator: validator
        });
        vm.label(_accInstance.account, accountNameString);
        return _accInstance;
    }

    /// @dev TODO: bake in signature helpers in this file if we wanted
    function _installModule(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module,
        bytes memory data,
        address validator
    )
        internal
        returns (UserOpData memory userOpData)
    {
        // Run preEnvHook
        if (envOr("COMPLIANCE", false) || getStorageCompliance()) {
            // Start state diff recording
            startStateDiffRecording();
        }

        userOpData = instance.getInstallModuleOps(moduleTypeId, module, data, validator);
        // sign userOp with default signature
        userOpData = userOpData.signDefault();
        userOpData.entrypoint = instance.aux.entrypoint;
        // send userOp to entrypoint
        userOpData.execUserOps();
    }

    function _getContract(uint64 chainId, string memory contractName) internal view returns (address) {
        return contractAddresses[chainId][contractName];
    }

    function _getHookAddress(uint64 chainId, string memory hookName) internal view returns (address) {
        return hookAddresses[chainId][hookName];
    }

    function _getHook(uint64 chainId, string memory hookName) internal view returns (Hook memory) {
        return hooks[chainId][hookName];
    }

    function _getHookDependency(uint64 chainId, string memory hookName) internal view returns (HookCategory) {
        return hooks[chainId][hookName].dependency;
    }

    function _getHooksByCategory(uint64 chainId, HookCategory category) internal view returns (Hook[] memory) {
        return hooksByCategory[chainId][category];
    }

    function _deployContracts(Addresses[] memory A) internal returns (Addresses[] memory) {
        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);

            address acrossV3Helper = address(new AcrossV3Helper());
            vm.allowCheatcodes(acrossV3Helper);
            vm.makePersistent(acrossV3Helper);
            contractAddresses[chainIds[i]][ACROSS_V3_HELPER_KEY] = acrossV3Helper;

            address debridgeHelper = address(new DebridgeHelper());
            vm.allowCheatcodes(debridgeHelper);
            vm.makePersistent(debridgeHelper);
            contractAddresses[chainIds[i]][DEBRIDGE_HELPER_KEY] = debridgeHelper;

            A[i].superRegistry = ISuperRegistry(address(new SuperRegistry(address(this))));
            vm.label(address(A[i].superRegistry), SUPER_REGISTRY_KEY);
            contractAddresses[chainIds[i]][SUPER_REGISTRY_KEY] = address(A[i].superRegistry);

            A[i].peripheryRegistry = new PeripheryRegistry(address(this), TREASURY);
            vm.label(address(A[i].peripheryRegistry), PERIPHERY_REGISTRY_KEY);
            contractAddresses[chainIds[i]][PERIPHERY_REGISTRY_KEY] = address(A[i].peripheryRegistry);

            A[i].oracleRegistry = new SuperOracle(address(this), new address[](0), new uint256[](0), new address[](0));
            vm.label(address(A[i].oracleRegistry), SUPER_ORACLE_KEY);
            contractAddresses[chainIds[i]][SUPER_ORACLE_KEY] = address(A[i].oracleRegistry);

            A[i].superExecutor = ISuperExecutor(address(new SuperExecutor(address(A[i].superRegistry))));
            vm.label(address(A[i].superExecutor), SUPER_EXECUTOR_KEY);
            contractAddresses[chainIds[i]][SUPER_EXECUTOR_KEY] = address(A[i].superExecutor);

            A[i].mockTargetExecutor = new MockTargetExecutor(address(A[i].superRegistry));
            vm.label(address(A[i].mockTargetExecutor), MOCK_TARGET_EXECUTOR_KEY);
            contractAddresses[chainIds[i]][MOCK_TARGET_EXECUTOR_KEY] = address(A[i].mockTargetExecutor); 

            A[i].superLedgerConfiguration =
                ISuperLedgerConfiguration(address(new SuperLedgerConfiguration(address(A[i].superRegistry))));
            vm.label(address(A[i].superLedgerConfiguration), SUPER_LEDGER_CONFIGURATION_KEY);
            contractAddresses[chainIds[i]][SUPER_LEDGER_CONFIGURATION_KEY] = address(A[i].superLedgerConfiguration);

            A[i].superLedger = ISuperLedger(address(new SuperLedger(address(A[i].superLedgerConfiguration))));
            vm.label(address(A[i].superLedger), SUPER_LEDGER_KEY);
            contractAddresses[chainIds[i]][SUPER_LEDGER_KEY] = address(A[i].superLedger);

            A[i].erc1155Ledger = ISuperLedger(address(new ERC5115Ledger(address(A[i].superLedgerConfiguration))));
            vm.label(address(A[i].erc1155Ledger), ERC1155_LEDGER_KEY);
            contractAddresses[chainIds[i]][ERC1155_LEDGER_KEY] = address(A[i].erc1155Ledger);

            A[i].superNativePaymaster = new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR));
            vm.label(address(A[i].superNativePaymaster), SUPER_NATIVE_PAYMASTER_KEY);
            contractAddresses[chainIds[i]][SUPER_NATIVE_PAYMASTER_KEY] = address(A[i].superNativePaymaster);

            A[i].superGasTank = new SuperGasTank(address(this));
            vm.label(address(A[i].superGasTank), SUPER_GAS_TANK_KEY);
            contractAddresses[chainIds[i]][SUPER_GAS_TANK_KEY] = address(A[i].superGasTank);
            payable(address(A[i].superGasTank)).transfer(10 ether);

            A[i].acrossReceiveFundsAndExecuteGateway = new AcrossReceiveFundsAndExecuteGateway(
                SPOKE_POOL_V3_ADDRESSES[chainIds[i]], ENTRYPOINT_ADDR, SUPER_BUNDLER, address(A[i].superRegistry)
            );
            vm.label(address(A[i].acrossReceiveFundsAndExecuteGateway), ACROSS_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_KEY);
            contractAddresses[chainIds[i]][ACROSS_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_KEY] =
                address(A[i].acrossReceiveFundsAndExecuteGateway);
            SuperGasTank(payable(A[i].superGasTank)).addToAllowlist(address(this));
            SuperGasTank(payable(A[i].superGasTank)).addToAllowlist(address(A[i].acrossReceiveFundsAndExecuteGateway));

            A[i].superMerkleValidator = new SuperMerkleValidator();
            vm.label(address(A[i].superMerkleValidator), SUPER_MERKLE_VALIDATOR_KEY);
            contractAddresses[chainIds[i]][SUPER_MERKLE_VALIDATOR_KEY] = address(A[i].superMerkleValidator);

            /// @dev action oracles
            A[i].erc4626YieldSourceOracle = new ERC4626YieldSourceOracle(address(A[i].superRegistry));
            vm.label(address(A[i].erc4626YieldSourceOracle), ERC4626_YIELD_SOURCE_ORACLE_KEY);
            contractAddresses[chainIds[i]][ERC4626_YIELD_SOURCE_ORACLE_KEY] = address(A[i].erc4626YieldSourceOracle);

            A[i].erc5115YieldSourceOracle = new ERC5115YieldSourceOracle(address(A[i].superRegistry));
            vm.label(address(A[i].erc5115YieldSourceOracle), ERC5115_YIELD_SOURCE_ORACLE_KEY);
            contractAddresses[chainIds[i]][ERC5115_YIELD_SOURCE_ORACLE_KEY] = address(A[i].erc5115YieldSourceOracle);

            A[i].erc7540YieldSourceOracle = new ERC7540YieldSourceOracle(address(A[i].superRegistry));
            vm.label(address(A[i].erc7540YieldSourceOracle), ERC7540_YIELD_SOURCE_ORACLE_KEY);
            contractAddresses[chainIds[i]][ERC7540_YIELD_SOURCE_ORACLE_KEY] = address(A[i].erc7540YieldSourceOracle);

            A[i].fluidYieldSourceOracle = new FluidYieldSourceOracle(address(A[i].superRegistry));
            vm.label(address(A[i].fluidYieldSourceOracle), FLUID_YIELD_SOURCE_ORACLE_KEY);
            contractAddresses[chainIds[i]][FLUID_YIELD_SOURCE_ORACLE_KEY] = address(A[i].fluidYieldSourceOracle);

            A[i].gearboxYieldSourceOracle = new GearboxYieldSourceOracle(address(A[i].superRegistry));
            vm.label(address(A[i].gearboxYieldSourceOracle), GEARBOX_YIELD_SOURCE_ORACLE_KEY);
            contractAddresses[chainIds[i]][GEARBOX_YIELD_SOURCE_ORACLE_KEY] = address(A[i].gearboxYieldSourceOracle);
        }
        return A;
    }

    function _deployHooks(Addresses[] memory A) internal returns (Addresses[] memory) {
        if (DEBUG) console2.log("---------------- DEPLOYING HOOKS ----------------");
        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);

            A[i].approveErc20Hook = new ApproveERC20Hook(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].approveErc20Hook), APPROVE_ERC20_HOOK_KEY);
            hookAddresses[chainIds[i]][APPROVE_ERC20_HOOK_KEY] = address(A[i].approveErc20Hook);
            hooks[chainIds[i]][APPROVE_ERC20_HOOK_KEY] = Hook(
                APPROVE_ERC20_HOOK_KEY,
                HookCategory.TokenApprovals,
                HookCategory.None,
                address(A[i].approveErc20Hook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.TokenApprovals].push(hooks[chainIds[i]][APPROVE_ERC20_HOOK_KEY]);

            A[i].transferErc20Hook = new TransferERC20Hook(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].transferErc20Hook), TRANSFER_ERC20_HOOK_KEY);
            hookAddresses[chainIds[i]][TRANSFER_ERC20_HOOK_KEY] = address(A[i].transferErc20Hook);
            hooks[chainIds[i]][TRANSFER_ERC20_HOOK_KEY] = Hook(
                TRANSFER_ERC20_HOOK_KEY,
                HookCategory.TokenApprovals,
                HookCategory.TokenApprovals,
                address(A[i].transferErc20Hook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.TokenApprovals].push(hooks[chainIds[i]][TRANSFER_ERC20_HOOK_KEY]);

            A[i].deposit4626VaultHook = new Deposit4626VaultHook(_getContract(chainIds[i], "SuperRegistry"));
            vm.label(address(A[i].deposit4626VaultHook), DEPOSIT_4626_VAULT_HOOK_KEY);
            hookAddresses[chainIds[i]][DEPOSIT_4626_VAULT_HOOK_KEY] = address(A[i].deposit4626VaultHook);
            hooks[chainIds[i]][DEPOSIT_4626_VAULT_HOOK_KEY] = Hook(
                DEPOSIT_4626_VAULT_HOOK_KEY,
                HookCategory.VaultDeposits,
                HookCategory.TokenApprovals,
                address(A[i].deposit4626VaultHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.VaultDeposits].push(
                hooks[chainIds[i]][DEPOSIT_4626_VAULT_HOOK_KEY]
            );

            A[i].approveAndDeposit4626VaultHook =
                new ApproveAndDeposit4626VaultHook(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].approveAndDeposit4626VaultHook), APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);
            hookAddresses[chainIds[i]][APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY] =
                address(A[i].approveAndDeposit4626VaultHook);
            hooks[chainIds[i]][APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY] = Hook(
                APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY,
                HookCategory.TokenApprovals,
                HookCategory.VaultDeposits,
                address(A[i].approveAndDeposit4626VaultHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.VaultDeposits].push(
                hooks[chainIds[i]][APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY]
            );

            A[i].redeem4626VaultHook = new Redeem4626VaultHook(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].redeem4626VaultHook), REDEEM_4626_VAULT_HOOK_KEY);
            hookAddresses[chainIds[i]][REDEEM_4626_VAULT_HOOK_KEY] = address(A[i].redeem4626VaultHook);
            hooks[chainIds[i]][REDEEM_4626_VAULT_HOOK_KEY] = Hook(
                REDEEM_4626_VAULT_HOOK_KEY,
                HookCategory.VaultWithdrawals,
                HookCategory.VaultDeposits,
                address(A[i].redeem4626VaultHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.VaultWithdrawals].push(
                hooks[chainIds[i]][REDEEM_4626_VAULT_HOOK_KEY]
            );

            A[i].deposit5115VaultHook = new Deposit5115VaultHook(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].deposit5115VaultHook), DEPOSIT_5115_VAULT_HOOK_KEY);
            hookAddresses[chainIds[i]][DEPOSIT_5115_VAULT_HOOK_KEY] = address(A[i].deposit5115VaultHook);
            hooks[chainIds[i]][DEPOSIT_5115_VAULT_HOOK_KEY] = Hook(
                DEPOSIT_5115_VAULT_HOOK_KEY,
                HookCategory.VaultDeposits,
                HookCategory.TokenApprovals,
                address(A[i].deposit5115VaultHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.VaultDeposits].push(
                hooks[chainIds[i]][DEPOSIT_5115_VAULT_HOOK_KEY]
            );

            A[i].approveAndDeposit5115VaultHook =
                new ApproveAndDeposit5115VaultHook(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].approveAndDeposit5115VaultHook), APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY);
            hookAddresses[chainIds[i]][APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY] =
                address(A[i].approveAndDeposit5115VaultHook);
            hooks[chainIds[i]][APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY] = Hook(
                APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY,
                HookCategory.TokenApprovals,
                HookCategory.VaultDeposits,
                address(A[i].approveAndDeposit5115VaultHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.VaultDeposits].push(
                hooks[chainIds[i]][APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY]
            );

            A[i].redeem5115VaultHook = new Redeem5115VaultHook(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].redeem5115VaultHook), REDEEM_5115_VAULT_HOOK_KEY);
            hookAddresses[chainIds[i]][REDEEM_5115_VAULT_HOOK_KEY] = address(A[i].redeem5115VaultHook);
            hooks[chainIds[i]][REDEEM_5115_VAULT_HOOK_KEY] = Hook(
                REDEEM_5115_VAULT_HOOK_KEY,
                HookCategory.VaultWithdrawals,
                HookCategory.VaultDeposits,
                address(A[i].redeem5115VaultHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.VaultWithdrawals].push(
                hooks[chainIds[i]][REDEEM_5115_VAULT_HOOK_KEY]
            );

            A[i].requestDeposit7540VaultHook =
                new RequestDeposit7540VaultHook(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].requestDeposit7540VaultHook), REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY);
            hookAddresses[chainIds[i]][REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY] = address(A[i].requestDeposit7540VaultHook);
            hooks[chainIds[i]][REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY] = Hook(
                REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY,
                HookCategory.VaultDeposits,
                HookCategory.TokenApprovals,
                address(A[i].requestDeposit7540VaultHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.VaultDeposits].push(
                hooks[chainIds[i]][REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY]
            );

            A[i].approveAndRequestDeposit7540VaultHook =
                new ApproveAndRequestDeposit7540VaultHook(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(
                address(A[i].approveAndRequestDeposit7540VaultHook), APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY
            );
            hookAddresses[chainIds[i]][APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY] =
                address(A[i].approveAndRequestDeposit7540VaultHook);
            hooks[chainIds[i]][APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY] = Hook(
                APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY,
                HookCategory.TokenApprovals,
                HookCategory.VaultDeposits,
                address(A[i].approveAndRequestDeposit7540VaultHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.VaultDeposits].push(
                hooks[chainIds[i]][APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY]
            );

            A[i].requestRedeem7540VaultHook =
                new RequestRedeem7540VaultHook(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].requestRedeem7540VaultHook), REQUEST_REDEEM_7540_VAULT_HOOK_KEY);
            hookAddresses[chainIds[i]][REQUEST_REDEEM_7540_VAULT_HOOK_KEY] = address(A[i].requestRedeem7540VaultHook);
            hooks[chainIds[i]][REQUEST_REDEEM_7540_VAULT_HOOK_KEY] = Hook(
                REQUEST_REDEEM_7540_VAULT_HOOK_KEY,
                HookCategory.VaultWithdrawals,
                HookCategory.VaultDeposits,
                address(A[i].requestRedeem7540VaultHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.VaultWithdrawals].push(
                hooks[chainIds[i]][REQUEST_REDEEM_7540_VAULT_HOOK_KEY]
            );

            A[i].deposit7540VaultHook = new Deposit7540VaultHook(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].deposit7540VaultHook), DEPOSIT_7540_VAULT_HOOK_KEY);
            hookAddresses[chainIds[i]][DEPOSIT_7540_VAULT_HOOK_KEY] = address(A[i].deposit7540VaultHook);
            hooks[chainIds[i]][DEPOSIT_7540_VAULT_HOOK_KEY] = Hook(
                DEPOSIT_7540_VAULT_HOOK_KEY,
                HookCategory.VaultDeposits,
                HookCategory.TokenApprovals,
                address(A[i].deposit7540VaultHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.VaultDeposits].push(
                hooks[chainIds[i]][DEPOSIT_7540_VAULT_HOOK_KEY]
            );

            A[i].withdraw7540VaultHook = new Withdraw7540VaultHook(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].withdraw7540VaultHook), WITHDRAW_7540_VAULT_HOOK_KEY);
            hookAddresses[chainIds[i]][WITHDRAW_7540_VAULT_HOOK_KEY] = address(A[i].withdraw7540VaultHook);
            hooks[chainIds[i]][WITHDRAW_7540_VAULT_HOOK_KEY] = Hook(
                WITHDRAW_7540_VAULT_HOOK_KEY,
                HookCategory.VaultWithdrawals,
                HookCategory.VaultDeposits,
                address(A[i].withdraw7540VaultHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.VaultWithdrawals].push(
                hooks[chainIds[i]][WITHDRAW_7540_VAULT_HOOK_KEY]
            );

            A[i].swap1InchHook = new Swap1InchHook(_getContract(chainIds[i], SUPER_REGISTRY_KEY), ONE_INCH_ROUTER);
            vm.label(address(A[i].swap1InchHook), SWAP_1INCH_HOOK_KEY);
            hookAddresses[chainIds[i]][SWAP_1INCH_HOOK_KEY] = address(A[i].swap1InchHook);
            hooks[chainIds[i]][SWAP_1INCH_HOOK_KEY] = Hook(
                SWAP_1INCH_HOOK_KEY, HookCategory.Swaps, HookCategory.TokenApprovals, address(A[i].swap1InchHook), ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Swaps].push(hooks[chainIds[i]][SWAP_1INCH_HOOK_KEY]);

            MockOdosRouterV2 odosRouter = new MockOdosRouterV2();
            odosRouters[chainIds[i]] = address(odosRouter);
            vm.label(address(odosRouter), "MockOdosRouterV2");
            A[i].swapOdosHook = new SwapOdosHook(_getContract(chainIds[i], SUPER_REGISTRY_KEY), address(odosRouter));
            vm.label(address(A[i].swapOdosHook), SWAP_ODOS_HOOK_KEY);
            hookAddresses[chainIds[i]][SWAP_ODOS_HOOK_KEY] = address(A[i].swapOdosHook);
            hooks[chainIds[i]][SWAP_ODOS_HOOK_KEY] = Hook(
                SWAP_ODOS_HOOK_KEY, HookCategory.Swaps, HookCategory.TokenApprovals, address(A[i].swapOdosHook), ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Swaps].push(hooks[chainIds[i]][SWAP_ODOS_HOOK_KEY]);

            A[i].approveAndSwapOdosHook =
                new ApproveAndSwapOdosHook(_getContract(chainIds[i], SUPER_REGISTRY_KEY), address(odosRouter));
            vm.label(address(A[i].approveAndSwapOdosHook), APPROVE_AND_SWAP_ODOS_HOOK_KEY);
            hookAddresses[chainIds[i]][APPROVE_AND_SWAP_ODOS_HOOK_KEY] = address(A[i].approveAndSwapOdosHook);
            hooks[chainIds[i]][APPROVE_AND_SWAP_ODOS_HOOK_KEY] = Hook(
                APPROVE_AND_SWAP_ODOS_HOOK_KEY,
                HookCategory.TokenApprovals,
                HookCategory.Swaps,
                address(A[i].approveAndSwapOdosHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Swaps].push(hooks[chainIds[i]][APPROVE_AND_SWAP_ODOS_HOOK_KEY]);

            A[i].acrossSendFundsAndExecuteOnDstHook = new AcrossSendFundsAndExecuteOnDstHook(
                _getContract(chainIds[i], SUPER_REGISTRY_KEY), SPOKE_POOL_V3_ADDRESSES[chainIds[i]]
            );
            vm.label(address(A[i].acrossSendFundsAndExecuteOnDstHook), ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);
            hookAddresses[chainIds[i]][ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY] =
                address(A[i].acrossSendFundsAndExecuteOnDstHook);
            hooks[chainIds[i]][ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY] = Hook(
                ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY,
                HookCategory.Bridges,
                HookCategory.TokenApprovals,
                address(A[i].acrossSendFundsAndExecuteOnDstHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Bridges].push(
                hooks[chainIds[i]][ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY]
            );

            A[i].fluidClaimRewardHook = new FluidClaimRewardHook(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].fluidClaimRewardHook), FLUID_CLAIM_REWARD_HOOK_KEY);
            hookAddresses[chainIds[i]][FLUID_CLAIM_REWARD_HOOK_KEY] = address(A[i].fluidClaimRewardHook);
            hooks[chainIds[i]][FLUID_CLAIM_REWARD_HOOK_KEY] = Hook(
                FLUID_CLAIM_REWARD_HOOK_KEY,
                HookCategory.Claims,
                HookCategory.None,
                address(A[i].fluidClaimRewardHook),
                ""
            );

            A[i].fluidStakeHook = new FluidStakeHook(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].fluidStakeHook), FLUID_STAKE_HOOK_KEY);
            hookAddresses[chainIds[i]][FLUID_STAKE_HOOK_KEY] = address(A[i].fluidStakeHook);
            hooks[chainIds[i]][FLUID_STAKE_HOOK_KEY] =
                Hook(FLUID_STAKE_HOOK_KEY, HookCategory.Stakes, HookCategory.None, address(A[i].fluidStakeHook), "");

            A[i].approveAndFluidStakeHook = new ApproveAndFluidStakeHook(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].approveAndFluidStakeHook), APPROVE_AND_FLUID_STAKE_HOOK_KEY);
            hookAddresses[chainIds[i]][APPROVE_AND_FLUID_STAKE_HOOK_KEY] = address(A[i].approveAndFluidStakeHook);
            hooks[chainIds[i]][APPROVE_AND_FLUID_STAKE_HOOK_KEY] = Hook(
                APPROVE_AND_FLUID_STAKE_HOOK_KEY,
                HookCategory.TokenApprovals,
                HookCategory.Stakes,
                address(A[i].approveAndFluidStakeHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Stakes].push(hooks[chainIds[i]][APPROVE_AND_FLUID_STAKE_HOOK_KEY]);

            A[i].fluidUnstakeHook = new FluidUnstakeHook(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].fluidUnstakeHook), FLUID_UNSTAKE_HOOK_KEY);
            hookAddresses[chainIds[i]][FLUID_UNSTAKE_HOOK_KEY] = address(A[i].fluidUnstakeHook);
            hooks[chainIds[i]][FLUID_UNSTAKE_HOOK_KEY] =
                Hook(FLUID_UNSTAKE_HOOK_KEY, HookCategory.Stakes, HookCategory.None, address(A[i].fluidUnstakeHook), "");

            A[i].gearboxClaimRewardHook = new GearboxClaimRewardHook(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].gearboxClaimRewardHook), GEARBOX_CLAIM_REWARD_HOOK_KEY);
            hookAddresses[chainIds[i]][GEARBOX_CLAIM_REWARD_HOOK_KEY] = address(A[i].gearboxClaimRewardHook);
            hooks[chainIds[i]][GEARBOX_CLAIM_REWARD_HOOK_KEY] = Hook(
                GEARBOX_CLAIM_REWARD_HOOK_KEY,
                HookCategory.Claims,
                HookCategory.None,
                address(A[i].gearboxClaimRewardHook),
                ""
            );

            A[i].gearboxStakeHook = new GearboxStakeHook(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].gearboxStakeHook), GEARBOX_STAKE_HOOK_KEY);
            hookAddresses[chainIds[i]][GEARBOX_STAKE_HOOK_KEY] = address(A[i].gearboxStakeHook);
            hooks[chainIds[i]][GEARBOX_STAKE_HOOK_KEY] = Hook(
                GEARBOX_STAKE_HOOK_KEY,
                HookCategory.Stakes,
                HookCategory.VaultDeposits,
                address(A[i].gearboxStakeHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Stakes].push(hooks[chainIds[i]][GEARBOX_STAKE_HOOK_KEY]);

            A[i].approveAndGearboxStakeHook =
                new ApproveAndGearboxStakeHook(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].approveAndGearboxStakeHook), GEARBOX_APPROVE_AND_STAKE_HOOK_KEY);
            hookAddresses[chainIds[i]][GEARBOX_APPROVE_AND_STAKE_HOOK_KEY] = address(A[i].approveAndGearboxStakeHook);
            hooks[chainIds[i]][GEARBOX_APPROVE_AND_STAKE_HOOK_KEY] = Hook(
                GEARBOX_APPROVE_AND_STAKE_HOOK_KEY,
                HookCategory.TokenApprovals,
                HookCategory.Stakes,
                address(A[i].approveAndGearboxStakeHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Stakes].push(
                hooks[chainIds[i]][GEARBOX_APPROVE_AND_STAKE_HOOK_KEY]
            );

            A[i].gearboxUnstakeHook = new GearboxUnstakeHook(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].gearboxUnstakeHook), GEARBOX_UNSTAKE_HOOK_KEY);
            hookAddresses[chainIds[i]][GEARBOX_UNSTAKE_HOOK_KEY] = address(A[i].gearboxUnstakeHook);
            hooks[chainIds[i]][GEARBOX_UNSTAKE_HOOK_KEY] = Hook(
                GEARBOX_UNSTAKE_HOOK_KEY, HookCategory.Claims, HookCategory.Stakes, address(A[i].gearboxUnstakeHook), ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Claims].push(hooks[chainIds[i]][GEARBOX_UNSTAKE_HOOK_KEY]);

            A[i].yearnClaimOneRewardHook = new YearnClaimOneRewardHook(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].yearnClaimOneRewardHook), YEARN_CLAIM_ONE_REWARD_HOOK_KEY);
            hooks[chainIds[i]][YEARN_CLAIM_ONE_REWARD_HOOK_KEY] = Hook(
                YEARN_CLAIM_ONE_REWARD_HOOK_KEY,
                HookCategory.Claims,
                HookCategory.Stakes,
                address(A[i].yearnClaimOneRewardHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Claims].push(hooks[chainIds[i]][YEARN_CLAIM_ONE_REWARD_HOOK_KEY]);

            /// @dev EXPERIMENTAL HOOKS FROM HERE ONWARDS
            A[i].ethenaCooldownSharesHook = new EthenaCooldownSharesHook(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].ethenaCooldownSharesHook), ETHENA_COOLDOWN_SHARES_HOOK_KEY);
            hookAddresses[chainIds[i]][ETHENA_COOLDOWN_SHARES_HOOK_KEY] = address(A[i].ethenaCooldownSharesHook);

            A[i].ethenaUnstakeHook = new EthenaUnstakeHook(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].ethenaUnstakeHook), ETHENA_UNSTAKE_HOOK_KEY);
            hookAddresses[chainIds[i]][ETHENA_UNSTAKE_HOOK_KEY] = address(A[i].ethenaUnstakeHook);
        }

        return A;
    }

    /**
     * @notice Registers all hooks with the periphery registry
     * @param A Array of Addresses structs containing hook addresses
     * @return A The input Addresses array
     */
    function _registerHooks(Addresses[] memory A) internal returns (Addresses[] memory) {
        if (DEBUG) console2.log("---------------- REGISTERING HOOKS ----------------");
        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);

            PeripheryRegistry peripheryRegistry = PeripheryRegistry(_getContract(chainIds[i], PERIPHERY_REGISTRY_KEY));

            // Register fulfillRequests hooks
            peripheryRegistry.registerHook(address(A[i].deposit4626VaultHook), true);
            peripheryRegistry.registerHook(address(A[i].redeem4626VaultHook), true);
            peripheryRegistry.registerHook(address(A[i].deposit5115VaultHook), true);
            peripheryRegistry.registerHook(address(A[i].redeem5115VaultHook), true);
            peripheryRegistry.registerHook(address(A[i].requestDeposit7540VaultHook), false);
            peripheryRegistry.registerHook(address(A[i].requestRedeem7540VaultHook), false);
            // Register remaining hooks
            peripheryRegistry.registerHook(address(A[i].approveAndDeposit4626VaultHook), true);
            peripheryRegistry.registerHook(address(A[i].approveAndDeposit5115VaultHook), true);
            peripheryRegistry.registerHook(address(A[i].approveAndRequestDeposit7540VaultHook), true);
            peripheryRegistry.registerHook(address(A[i].approveErc20Hook), false);
            peripheryRegistry.registerHook(address(A[i].transferErc20Hook), false);
            peripheryRegistry.registerHook(address(A[i].deposit7540VaultHook), true);
            peripheryRegistry.registerHook(address(A[i].withdraw7540VaultHook), true);
            peripheryRegistry.registerHook(address(A[i].swap1InchHook), false);
            peripheryRegistry.registerHook(address(A[i].swapOdosHook), false);
            peripheryRegistry.registerHook(address(A[i].approveAndSwapOdosHook), false);
            peripheryRegistry.registerHook(address(A[i].acrossSendFundsAndExecuteOnDstHook), false);
            peripheryRegistry.registerHook(address(A[i].fluidClaimRewardHook), false);
            peripheryRegistry.registerHook(address(A[i].fluidStakeHook), false);
            peripheryRegistry.registerHook(address(A[i].approveAndFluidStakeHook), false);
            peripheryRegistry.registerHook(address(A[i].fluidUnstakeHook), false);
            peripheryRegistry.registerHook(address(A[i].gearboxClaimRewardHook), false);
            peripheryRegistry.registerHook(address(A[i].gearboxStakeHook), false);
            peripheryRegistry.registerHook(address(A[i].approveAndGearboxStakeHook), false);
            peripheryRegistry.registerHook(address(A[i].gearboxUnstakeHook), false);
            peripheryRegistry.registerHook(address(A[i].yearnClaimOneRewardHook), false);

            // EXPERIMENTAL HOOKS FROM HERE ONWARDS
            peripheryRegistry.registerHook(address(A[i].ethenaCooldownSharesHook), false);
            peripheryRegistry.registerHook(address(A[i].ethenaUnstakeHook), true);
        }

        return A;
    }

    function _initializeAccounts(uint256 count) internal {
        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);

            // create Superform account
            string memory accountName = "SuperformAccount";
            AccountInstance memory instance = makeAccountInstance(keccak256(abi.encode(accountName)));
            accountInstances[chainIds[i]] = instance;
            instance.installModule({
                moduleTypeId: MODULE_TYPE_EXECUTOR,
                module: _getContract(chainIds[i], SUPER_EXECUTOR_KEY),
                data: ""
            });
            vm.label(instance.account, accountName);

            // create random accounts to be used as users
            for (uint256 j; j < count; ++j) {
                AccountInstance memory _instance = makeAccountInstance(keccak256(abi.encode(block.timestamp, j)));
                randomAccountInstances[chainIds[i]].push(_instance);
                _instance.installModule({
                    moduleTypeId: MODULE_TYPE_EXECUTOR,
                    module: _getContract(chainIds[i], "SuperExecutor"),
                    data: ""
                });
                vm.label(_instance.account, "RandomAccount");
            }
        }
    }

    function _preDeploymentSetup() internal {
        mapping(uint64 => uint256) storage forks = FORKS;
        forks[ETH] = vm.createFork(ETHEREUM_RPC_URL, 21_929_476);
        forks[OP] = vm.createFork(OPTIMISM_RPC_URL, 132_481_010);
        forks[BASE] = vm.createFork(BASE_RPC_URL, 26_885_730);

        mapping(uint64 => string) storage rpcURLs = RPC_URLS;
        rpcURLs[ETH] = ETHEREUM_RPC_URL;
        rpcURLs[OP] = OPTIMISM_RPC_URL;
        rpcURLs[BASE] = BASE_RPC_URL;

        mapping(uint64 => address) storage spokePoolV3AddressesMap = SPOKE_POOL_V3_ADDRESSES;
        spokePoolV3AddressesMap[ETH] = spokePoolV3Addresses[0];
        vm.label(spokePoolV3AddressesMap[ETH], "SpokePoolV3ETH");
        spokePoolV3AddressesMap[OP] = spokePoolV3Addresses[1];
        vm.label(spokePoolV3AddressesMap[OP], "SpokePoolV3OP");
        spokePoolV3AddressesMap[BASE] = spokePoolV3Addresses[2];
        vm.label(spokePoolV3AddressesMap[BASE], "SpokePoolV3BASE");

        mapping(uint64 => address) storage deBridgeGateAddressesMap = DEBRIDGE_GATE_ADDRESSES;
        deBridgeGateAddressesMap[ETH] = deBridgeGateAddresses[0];
        vm.label(deBridgeGateAddressesMap[ETH], "DeBridgeGateETH");
        deBridgeGateAddressesMap[OP] = deBridgeGateAddresses[1];
        vm.label(deBridgeGateAddressesMap[OP], "DeBridgeGateOP");
        deBridgeGateAddressesMap[BASE] = deBridgeGateAddresses[2];
        vm.label(deBridgeGateAddressesMap[BASE], "DeBridgeGateBASE");

        mapping(uint64 => address) storage deBridgeGateAdminAddressesMap = DEBRIDGE_ADMIN_ADDRESSES;
        deBridgeGateAdminAddressesMap[ETH] = deBridgeGateAdminAddresses[0];
        vm.label(deBridgeGateAdminAddressesMap[ETH], "DeBridgeGateAdminETH");
        deBridgeGateAdminAddressesMap[OP] = deBridgeGateAdminAddresses[1];
        vm.label(deBridgeGateAdminAddressesMap[OP], "DeBridgeGateAdminOP");
        deBridgeGateAdminAddressesMap[BASE] = deBridgeGateAdminAddresses[2];
        vm.label(deBridgeGateAdminAddressesMap[BASE], "DeBridgeGateAdminBASE");

        /// @dev Setup existingUnderlyingTokens
        // Mainnet tokens
        existingUnderlyingTokens[ETH][DAI_KEY] = CHAIN_1_DAI;
        existingUnderlyingTokens[ETH][USDC_KEY] = CHAIN_1_USDC;
        existingUnderlyingTokens[ETH][WETH_KEY] = CHAIN_1_WETH;
        existingUnderlyingTokens[ETH][SUSDE_KEY] = CHAIN_1_SUSDE;
        existingUnderlyingTokens[ETH][USDE_KEY] = CHAIN_1_USDE;
        // Optimism tokens
        existingUnderlyingTokens[OP][DAI_KEY] = CHAIN_10_DAI;
        existingUnderlyingTokens[OP][USDC_KEY] = CHAIN_10_USDC;
        existingUnderlyingTokens[OP][WETH_KEY] = CHAIN_10_WETH;
        existingUnderlyingTokens[OP][USDCe_KEY] = CHAIN_10_USDCe;
        existingUnderlyingTokens[ETH][GEAR_KEY] = CHAIN_1_GEAR;
        existingUnderlyingTokens[ETH][SUSDE_KEY] = CHAIN_1_SUSDE;

        // Base tokens
        existingUnderlyingTokens[BASE][DAI_KEY] = CHAIN_8453_DAI;
        existingUnderlyingTokens[BASE][USDC_KEY] = CHAIN_8453_USDC;
        existingUnderlyingTokens[BASE][WETH_KEY] = CHAIN_8453_WETH;

        /// @dev Setup realVaultAddresses
        mapping(
            uint64 chainId
                => mapping(
                    string vaultKind => mapping(string vaultName => mapping(string underlying => address realVault))
                )
        ) storage existingVaults = realVaultAddresses;

        /// @dev Ethereum 4626 vault addresses
        existingVaults[1][ERC4626_VAULT_KEY][AAVE_VAULT_KEY][USDC_KEY] = CHAIN_1_AaveVault;
        vm.label(existingVaults[ETH][ERC4626_VAULT_KEY][AAVE_VAULT_KEY][USDC_KEY], AAVE_VAULT_KEY);
        existingVaults[1][ERC4626_VAULT_KEY][FLUID_VAULT_KEY][USDC_KEY] = CHAIN_1_FluidVault;
        vm.label(existingVaults[ETH][ERC4626_VAULT_KEY][FLUID_VAULT_KEY][USDC_KEY], FLUID_VAULT_KEY);
        existingVaults[1][ERC4626_VAULT_KEY][EULER_VAULT_KEY][USDC_KEY] = CHAIN_1_EulerVault;
        vm.label(existingVaults[ETH][ERC4626_VAULT_KEY][EULER_VAULT_KEY][USDC_KEY], EULER_VAULT_KEY);
        existingVaults[1][ERC4626_VAULT_KEY][MORPHO_VAULT_KEY][USDC_KEY] = CHAIN_1_MorphoVault;
        vm.label(existingVaults[ETH][ERC4626_VAULT_KEY][MORPHO_VAULT_KEY][USDC_KEY], MORPHO_VAULT_KEY);

        /// @dev Optimism 4626vault addresses
        existingVaults[10][ERC4626_VAULT_KEY][ALOE_USDC_VAULT_KEY][USDCe_KEY] = CHAIN_10_AloeUSDC;
        vm.label(existingVaults[OP][ERC4626_VAULT_KEY][ALOE_USDC_VAULT_KEY][USDCe_KEY], ALOE_USDC_VAULT_KEY);
        existingVaults[1][ERC4626_VAULT_KEY][GEARBOX_VAULT_KEY][USDC_KEY] = CHAIN_1_GearboxVault;
        vm.label(existingVaults[ETH][ERC4626_VAULT_KEY][GEARBOX_VAULT_KEY][USDC_KEY], GEARBOX_VAULT_KEY);

        /// @dev Staking real gearbox staking on mainnet
        existingVaults[ETH][GEARBOX_YIELD_SOURCE_ORACLE_KEY][GEARBOX_STAKING_KEY][GEAR_KEY] = CHAIN_1_GearboxStaking;
        vm.label(existingVaults[ETH][GEARBOX_YIELD_SOURCE_ORACLE_KEY][GEARBOX_STAKING_KEY][GEAR_KEY], "GearboxStaking");

        /// @dev Base 4626 vault addresses
        existingVaults[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_USDC_PRIME_KEY][USDC_KEY] =
            CHAIN_8453_MorphoGauntletUSDCPrime;
        vm.label(
            existingVaults[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_USDC_PRIME_KEY][USDC_KEY],
            MORPHO_GAUNTLET_USDC_PRIME_KEY
        );
        existingVaults[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_WETH_CORE_KEY][WETH_KEY] =
            CHAIN_8453_MorphoGauntletWETHCore;
        vm.label(
            existingVaults[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_WETH_CORE_KEY][WETH_KEY],
            MORPHO_GAUNTLET_WETH_CORE_KEY
        );

        /// @dev 7540 real centrifuge vaults on mainnet
        existingVaults[ETH][ERC7540FullyAsync_KEY][CENTRIFUGE_USDC_VAULT_KEY][USDC_KEY] = CHAIN_1_CentrifugeUSDC;
        vm.label(
            existingVaults[ETH][ERC7540FullyAsync_KEY][CENTRIFUGE_USDC_VAULT_KEY][USDC_KEY], CENTRIFUGE_USDC_VAULT_KEY
        );

        /// @dev 5115 real pendle ethena vault on mainnet
        existingVaults[ETH][ERC5115_VAULT_KEY][PENDLE_ETHENA_KEY][SUSDE_KEY] = CHAIN_1_PendleEthena;
        vm.label(existingVaults[ETH][ERC5115_VAULT_KEY][PENDLE_ETHENA_KEY][SUSDE_KEY], "PendleEthena");

        /// wstETH
        /// @dev pendle wrapped st ETH from LDO - market:  SY wstETH
        // erc5115Vaults[10][0] = 0x96A528f4414aC3CcD21342996c93f2EcdEc24286;
        // erc5115VaultsNames[10][0] = "wstETH";
        // erc5115ChosenAssets[10][0x96A528f4414aC3CcD21342996c93f2EcdEc24286].assetIn =
        //     0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb;
        // erc5115ChosenAssets[10][0x96A528f4414aC3CcD21342996c93f2EcdEc24286].assetOut =
        //     0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb;
    }

    function _fundUnderlyingTokens(uint256 amount) internal {
        for (uint256 j = 0; j < underlyingTokens.length; ++j) {
            for (uint256 i = 0; i < chainIds.length; ++i) {
                vm.selectFork(FORKS[chainIds[i]]);
                address token = existingUnderlyingTokens[chainIds[i]][underlyingTokens[j]];
                if (token != address(0)) {
                    deal(
                        token, accountInstances[chainIds[i]].account, amount * (10 ** IERC20Metadata(token).decimals())
                    );
                }
            }
        }
    }

    function _setSuperRegistryAddresses() internal {
        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);
            ISuperRegistry superRegistry = ISuperRegistry(_getContract(chainIds[i], SUPER_REGISTRY_KEY));

            SuperRegistry(address(superRegistry)).setAddress(
                keccak256(bytes(SUPER_LEDGER_CONFIGURATION_ID)),
                _getContract(chainIds[i], SUPER_LEDGER_CONFIGURATION_KEY)
            );
            SuperRegistry(address(superRegistry)).setAddress(
                keccak256(bytes(SUPER_EXECUTOR_ID)), _getContract(chainIds[i], SUPER_EXECUTOR_KEY)
            );
            SuperRegistry(address(superRegistry)).setAddress(
                keccak256(bytes(SUPER_GAS_TANK_ID)), _getContract(chainIds[i], SUPER_GAS_TANK_KEY)
            );
            SuperRegistry(address(superRegistry)).setAddress(
                keccak256(bytes(SUPER_NATIVE_PAYMASTER_ID)), _getContract(chainIds[i], SUPER_NATIVE_PAYMASTER_KEY)
            );
        }
    }

    function _setupSuperLedger() internal {
        for (uint256 i; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);

            vm.startPrank(MANAGER);

            PeripheryRegistry peripheryRegistry = PeripheryRegistry(_getContract(chainIds[i], PERIPHERY_REGISTRY_KEY));
            ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
                new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](4);
            configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
                yieldSourceOracleId: bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                yieldSourceOracle: _getContract(chainIds[i], ERC4626_YIELD_SOURCE_ORACLE_KEY),
                feePercent: 100,
                feeRecipient: peripheryRegistry.getTreasury(),
                ledger: _getContract(chainIds[i], SUPER_LEDGER_KEY)
            });
            configs[1] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
                yieldSourceOracleId: bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)),
                yieldSourceOracle: _getContract(chainIds[i], ERC7540_YIELD_SOURCE_ORACLE_KEY),
                feePercent: 100,
                feeRecipient: peripheryRegistry.getTreasury(),
                ledger: _getContract(chainIds[i], SUPER_LEDGER_KEY)
            });
            configs[2] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
                yieldSourceOracleId: bytes4(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)),
                yieldSourceOracle: _getContract(chainIds[i], ERC5115_YIELD_SOURCE_ORACLE_KEY),
                feePercent: 100,
                feeRecipient: peripheryRegistry.getTreasury(),
                ledger: _getContract(chainIds[i], ERC1155_LEDGER_KEY)
            });
            configs[3] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
                yieldSourceOracleId: bytes4(bytes(GEARBOX_YIELD_SOURCE_ORACLE_KEY)),
                yieldSourceOracle: _getContract(chainIds[i], GEARBOX_YIELD_SOURCE_ORACLE_KEY),
                feePercent: 100,
                feeRecipient: peripheryRegistry.getTreasury(),
                ledger: _getContract(chainIds[i], SUPER_LEDGER_KEY)
            });
            ISuperLedgerConfiguration(_getContract(chainIds[i], SUPER_LEDGER_CONFIGURATION_KEY)).setYieldSourceOracles(
                configs
            );
            vm.stopPrank();
        }
    }
    /*//////////////////////////////////////////////////////////////
                         HELPERS
    //////////////////////////////////////////////////////////////*/

    function _getExecOps(
        AccountInstance memory instance,
        ISuperExecutor superExecutor,
        bytes memory data
    )
        internal
        returns (UserOpData memory userOpData)
    {
        return instance.getExecOps(
            address(superExecutor), 0, abi.encodeCall(superExecutor.execute, (data)), address(instance.defaultValidator)
        );
    }

    function _getExecOps(
        AccountInstance memory instance,
        ISuperExecutor superExecutor,
        bytes memory data,
        address paymaster
    )
        internal
        returns (UserOpData memory userOpData)
    {
        if (paymaster == address(0)) revert("NO_PAYMASTER_SUPPLIED");
        userOpData = instance.getExecOps(
            address(superExecutor), 0, abi.encodeCall(superExecutor.execute, (data)), address(instance.defaultValidator)
        );
        uint128 paymasterVerificationGasLimit = 2e6;
        uint128 postOpGasLimit = 2e6;
        bytes memory extraData = abi.encodePacked(uint128(1000));
        bytes memory paymasterData = abi.encodePacked(uint128(2e6), uint128(1000), extraData); // paymasterData {
            // maxGasLimi = 200000, nodeOperatorPremium = 10 % }
        userOpData.userOp.paymasterAndData =
            abi.encodePacked(paymaster, paymasterVerificationGasLimit, postOpGasLimit, paymasterData);
        return userOpData;
    }

    function exec(
        AccountInstance memory instance,
        ISuperExecutor superExecutor,
        bytes memory data
    )
        internal
        returns (UserOpData memory)
    {
        return instance.exec(address(superExecutor), abi.encodeCall(superExecutor.execute, (data)));
    }

    function executeOp(UserOpData memory userOpData) public returns (ExecutionReturnData memory) {
        return userOpData.execUserOps();
    }

    function _bound(uint256 amount_) internal pure returns (uint256) {
        amount_ = bound(amount_, SMALL, LARGE);
        return amount_;
    }

    enum RELAYER_TYPE {
        NOT_ENOUGH_BALANCE,
        ENOUGH_BALANCE
    }

    function _processAcrossV3Message(
        uint64 srcChainId,
        uint64 dstChainId,
        uint256 warpTimestamp,
        ExecutionReturnData memory executionData,
        RELAYER_TYPE relayerType,
        address account
    )
        internal
    {
        if (relayerType == RELAYER_TYPE.NOT_ENOUGH_BALANCE) {
            vm.expectEmit(true, true, true, true);
            emit IAcrossV3Receiver.AcrossFundsReceivedButNotEnoughBalance(account);
        } else {
            vm.expectEmit(true, true, true, true);
            emit IAcrossV3Receiver.AcrossFundsReceivedAndExecuted(account);
        }
        AcrossV3Helper(_getContract(srcChainId, ACROSS_V3_HELPER_KEY)).help(
            SPOKE_POOL_V3_ADDRESSES[srcChainId],
            SPOKE_POOL_V3_ADDRESSES[dstChainId],
            ACROSS_RELAYER,
            warpTimestamp,
            FORKS[dstChainId],
            dstChainId,
            srcChainId,
            executionData.logs
        );
    }

    function _processAcrossV3MessageWithoutDestinationAccount(
        uint64 srcChainId,
        uint64 dstChainId,
        uint256 warpTimestamp,
        ExecutionReturnData memory executionData
    )
        internal
    {
        AcrossV3Helper(_getContract(srcChainId, ACROSS_V3_HELPER_KEY)).help(
            SPOKE_POOL_V3_ADDRESSES[srcChainId],
            SPOKE_POOL_V3_ADDRESSES[dstChainId],
            ACROSS_RELAYER,
            warpTimestamp,
            FORKS[dstChainId],
            dstChainId,
            srcChainId,
            executionData.logs
        );
    }

    function _processDebridgeMessage(
        uint64 srcChainId,
        uint64 dstChainId,
        ExecutionReturnData memory executionData
    )
        internal
    {
        DebridgeHelper(_getContract(srcChainId, DEBRIDGE_HELPER_KEY)).help(
            DEBRIDGE_ADMIN_ADDRESSES[dstChainId],
            DEBRIDGE_GATE_ADDRESSES[srcChainId],
            DEBRIDGE_GATE_ADDRESSES[dstChainId],
            FORKS[dstChainId],
            dstChainId,
            executionData.logs
        );
    }

    struct FeeParams {
        ISuperLedger.LedgerEntry[] entries;
        uint256 unconsumedEntries;
        uint256 amountAssets;
        uint256 usedShares;
        uint256 feePercent;
        uint256 decimals;
    }

    function _assertFeeDerivation(
        uint256 expectedFee,
        uint256 feeBalanceBefore,
        uint256 feeBalanceAfter
    )
        internal
        pure
    {
        assertEq(feeBalanceAfter, feeBalanceBefore + expectedFee, "Fee derivation failed");
    }

    /*//////////////////////////////////////////////////////////////
                                 HOOK DATA CREATORS
    //////////////////////////////////////////////////////////////*/

    function _createApproveHookData(
        address token,
        address spender,
        uint256 amount,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(token, spender, amount, usePrevHookAmount);
    }

    function _createDeposit4626HookData(
        bytes4 yieldSourceOracleId,
        address vault,
        uint256 amount,
        bool usePrevHookAmount,
        bool lockSP
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(yieldSourceOracleId, vault, amount, usePrevHookAmount, lockSP);
    }

    function _createApproveAndDeposit4626HookData(
        bytes4 yieldSourceOracleId,
        address vault,
        address token,
        uint256 amount,
        bool usePrevHookAmount,
        bool lockForSP
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(yieldSourceOracleId, vault, token, amount, usePrevHookAmount, lockForSP);
    }

    function _create5115DepositHookData(
        bytes4 yieldSourceOracleId,
        address vault,
        address tokenIn,
        uint256 amount,
        uint256 minSharesOut,
        bool usePrevHookAmount,
        bool lockSP
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData =
            abi.encodePacked(yieldSourceOracleId, vault, tokenIn, amount, minSharesOut, usePrevHookAmount, lockSP);
    }

    function _createRedeem4626HookData(
        bytes4 yieldSourceOracleId,
        address vault,
        address owner,
        uint256 shares,
        bool usePrevHookAmount,
        bool lockSP
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(yieldSourceOracleId, vault, owner, shares, usePrevHookAmount, lockSP);
    }

    function _create5115RedeemHookData(
        bytes4 yieldSourceOracleId,
        address vault,
        address tokenOut,
        uint256 shares,
        uint256 minTokenOut,
        bool usePrevHookAmount,
        bool lockSP
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(
            yieldSourceOracleId, vault, tokenOut, shares, minTokenOut, false, usePrevHookAmount, lockSP
        );
    }

    function _createDebridgeSendFundsAndExecuteHookData(
        uint256 value,
        address account,
        address inputToken,
        uint256 inputAmount,
        uint256 chainIdTo,
        uint32 referralCode,
        bool useAssetFee,
        bool usePrevHookAmount,
        uint256 autoParamsLength,
        bytes memory autoParams,
        bytes memory permit
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(
            value,
            account,
            inputToken,
            inputAmount,
            chainIdTo,
            referralCode,
            useAssetFee,
            usePrevHookAmount,
            autoParamsLength,
            autoParams,
            permit
        );
    }

    function _createAcrossV3ReceiveFundsAndExecuteHookData(
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        uint64 destinationChainId,
        bool usePrevHookAmount,
        uint256 intentAmount,
        UserOpData memory userOpData
    )
        internal
        view
        returns (bytes memory hookData)
    {
        bytes memory dstUserOpData = _encodeUserOp(userOpData, intentAmount);
        hookData = abi.encodePacked(
            uint256(0),
            _getContract(destinationChainId, ACROSS_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_KEY),
            inputToken,
            outputToken,
            inputAmount,
            outputAmount,
            uint256(destinationChainId),
            address(0),
            uint32(10 minutes), // this can be a max of 360 minutes
            uint32(0),
            usePrevHookAmount,
            dstUserOpData
        );
    }

    function _createAcrossV3ReceiveFundsAndCreateAccount(
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        uint64 destinationChainId,
        bool usePrevHookAmount,
        bytes memory data //the message to be sent to the target executor
    )
        internal
        view
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(
            uint256(0),
            _getContract(destinationChainId, MOCK_TARGET_EXECUTOR_KEY),
            inputToken,
            outputToken,
            inputAmount,
            outputAmount,
            uint256(destinationChainId),
            address(0),
            uint32(10 minutes), // this can be a max of 360 minutes
            uint32(0),
            usePrevHookAmount,
            data
        );
    }

    function _encodeUserOp(UserOpData memory userOpData, uint256 intentAmount) internal pure returns (bytes memory) {
        return abi.encodePacked(
            userOpData.userOp.sender, // account
            intentAmount,
            userOpData.userOp.sender, // sender
            userOpData.userOp.nonce,
            userOpData.userOp.initCode.length,
            userOpData.userOp.initCode,
            userOpData.userOp.callData.length,
            userOpData.userOp.callData,
            userOpData.userOp.accountGasLimits,
            userOpData.userOp.preVerificationGas,
            userOpData.userOp.gasFees,
            userOpData.userOp.paymasterAndData.length,
            userOpData.userOp.paymasterAndData,
            userOpData.userOp.signature
        );
    }

    function _createRequestDeposit7540VaultHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        uint256 amount,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, usePrevHookAmount);
    }

    function _createDeposit7540VaultHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        uint256 amount,
        bool usePrevHookAmount,
        bool lockForSP
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, usePrevHookAmount, lockForSP);
    }

    function _createRequestRedeem7540VaultHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        uint256 amount,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, usePrevHookAmount);
    }

    function _createWithdraw7540VaultHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        uint256 amount,
        bool usePrevHookAmount,
        bool lockForSP
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, usePrevHookAmount, lockForSP);
    }

    function _createDeposit5115VaultHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        address tokenIn,
        uint256 amount,
        uint256 minSharesOut,
        bool usePrevHookAmount,
        bool lockForSP
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            yieldSourceOracleId, yieldSource, tokenIn, amount, minSharesOut, usePrevHookAmount, lockForSP
        );
    }

    function _createPermitHookData(
        address token,
        address spender,
        uint256 amount,
        uint256 expiration,
        uint256 sigDeadline,
        uint256 nonce
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(token, uint160(amount), uint48(expiration), uint48(nonce), spender, sigDeadline);
    }

    function _create1InchGenericRouterSwapHookData(
        address dstReceiver,
        address dstToken,
        address executor,
        I1InchAggregationRouterV6.SwapDescription memory desc,
        bytes memory permit,
        bytes memory data
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory _calldata = abi.encodeWithSelector(
            I1InchAggregationRouterV6.swap.selector, IAggregationExecutor(executor), desc, permit, data
        );

        return abi.encodePacked(dstToken, dstReceiver, uint256(0), _calldata);
    }

    function _create1InchUnoswapToHookData(
        address dstReceiver,
        address dstToken,
        Address receiverUint256,
        Address fromTokenUint256,
        uint256 decodedFromAmount,
        uint256 minReturn,
        Address dex
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory _calldata = abi.encodeWithSelector(
            I1InchAggregationRouterV6.unoswapTo.selector,
            receiverUint256,
            fromTokenUint256,
            decodedFromAmount,
            minReturn,
            dex
        );

        return abi.encodePacked(dstToken, dstReceiver, uint256(0), _calldata);
    }

    function _create1InchClipperSwapToHookData(
        address dstReceiver,
        address dstToken,
        address exchange,
        Address srcToken,
        uint256 amount
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory _calldata = abi.encodeWithSelector(
            I1InchAggregationRouterV6.clipperSwapTo.selector,
            exchange,
            payable(dstReceiver),
            srcToken,
            dstToken,
            amount,
            amount,
            0,
            bytes32(0),
            bytes32(0)
        );

        return abi.encodePacked(dstToken, dstReceiver, uint256(0), _calldata);
    }

    function _createOdosSwapHookData(
        address inputToken,
        uint256 inputAmount,
        address inputReceiver,
        address outputToken,
        uint256 outputQuote,
        uint256 outputMin,
        bytes memory pathDefinition,
        address executor,
        uint32 referralCode,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(
            inputToken,
            inputAmount,
            inputReceiver,
            outputToken,
            outputQuote,
            outputMin,
            pathDefinition.length,
            pathDefinition,
            executor,
            referralCode,
            usePrevHookAmount
        );
    }

    function _createApproveAndGearboxStakeHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        address token,
        uint256 amount,
        bool usePrevHookAmount,
        bool lockForSP
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, token, amount, usePrevHookAmount, lockForSP);
    }

    function _createGearboxStakeHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        uint256 amount,
        bool usePrevHookAmount,
        bool lockForSP
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, usePrevHookAmount, lockForSP);
    }

    function _createGearboxUnstakeHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        uint256 amount,
        bool usePrevHookAmount,
        bool lockForSP
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, usePrevHookAmount, lockForSP);
    }

    function _createApproveAndDeposit5115VaultHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        address tokenIn,
        uint256 amount,
        uint256 minSharesOut,
        bool usePrevHookAmount,
        bool lockForSP
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            yieldSourceOracleId, yieldSource, tokenIn, amount, minSharesOut, usePrevHookAmount, lockForSP
        );
    }

    function _createApproveAndRequestDeposit7540HookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        address token,
        uint256 amount,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, token, amount, usePrevHookAmount);
    }
}
