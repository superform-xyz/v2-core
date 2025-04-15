// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { Helpers } from "./utils/Helpers.sol";
import { SignatureHelper } from "./utils/SignatureHelper.sol";
import { MerkleTreeHelper } from "./utils/MerkleTreeHelper.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
// Superform interfaces
import { ISuperRegistry } from "../src/core/interfaces/ISuperRegistry.sol";
import { ISuperExecutor } from "../src/core/interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../src/core/interfaces/accounting/ISuperLedger.sol";
import { ISuperLedgerConfiguration } from "../src/core/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { IAcrossTargetExecutor } from "../src/core/interfaces/IAcrossTargetExecutor.sol";

// Superform contracts
import { SuperLedger } from "../src/core/accounting/SuperLedger.sol";
import { ERC5115Ledger } from "../src/core/accounting/ERC5115Ledger.sol";
import { SuperLedgerConfiguration } from "../src/core/accounting/SuperLedgerConfiguration.sol";
import { SuperRegistry } from "../src/core/settings/SuperRegistry.sol";
import { SuperExecutor } from "../src/core/executors/SuperExecutor.sol";
import { AcrossTargetExecutor } from "../src/core/executors/AcrossTargetExecutor.sol";
import { SuperMerkleValidator } from "../src/core/validators/SuperMerkleValidator.sol";
import { SuperDestinationValidator } from "../src/core/validators/SuperDestinationValidator.sol";
import { SuperValidatorBase } from "../src/core/validators/SuperValidatorBase.sol";

// hooks

// token hooks
// --- erc20
import { ApproveERC20Hook } from "../src/core/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { TransferERC20Hook } from "../src/core/hooks/tokens/erc20/TransferERC20Hook.sol";

// loan hooks
import { MorphoRepayAndWithdrawHook } from "../src/core/hooks/loan/morpho/MorphoRepayAndWithdrawHook.sol";
import { MorphoBorrowHook } from "../src/core/hooks/loan/morpho/MorphoBorrowHook.sol";
import { MorphoRepayHook } from "../src/core/hooks/loan/morpho/MorphoRepayHook.sol";

// vault hooks
// --- erc5115
import { Deposit5115VaultHook } from "../src/core/hooks/vaults/5115/Deposit5115VaultHook.sol";
import { ApproveAndDeposit5115VaultHook } from "../src/core/hooks/vaults/5115/ApproveAndDeposit5115VaultHook.sol";
import { Redeem5115VaultHook } from "../src/core/hooks/vaults/5115/Redeem5115VaultHook.sol";
import { ApproveAndRedeem5115VaultHook } from "../src/core/hooks/vaults/5115/ApproveAndRedeem5115VaultHook.sol";
// --- erc4626
import { Deposit4626VaultHook } from "../src/core/hooks/vaults/4626/Deposit4626VaultHook.sol";
import { ApproveAndDeposit4626VaultHook } from "../src/core/hooks/vaults/4626/ApproveAndDeposit4626VaultHook.sol";
import { Redeem4626VaultHook } from "../src/core/hooks/vaults/4626/Redeem4626VaultHook.sol";
import { ApproveAndRedeem4626VaultHook } from "../src/core/hooks/vaults/4626/ApproveAndRedeem4626VaultHook.sol";
// -- erc7540
import { Deposit7540VaultHook } from "../src/core/hooks/vaults/7540/Deposit7540VaultHook.sol";
import { RequestDeposit7540VaultHook } from "../src/core/hooks/vaults/7540/RequestDeposit7540VaultHook.sol";

import { CancelDepositRequest7540Hook } from "../src/core/hooks/vaults/7540/CancelDepositRequest7540Hook.sol";
import { CancelRedeemRequest7540Hook } from "../src/core/hooks/vaults/7540/CancelRedeemRequest7540Hook.sol";
import { ClaimCancelDepositRequest7540Hook } from "../src/core/hooks/vaults/7540/ClaimCancelDepositRequest7540Hook.sol";
import { ClaimCancelRedeemRequest7540Hook } from "../src/core/hooks/vaults/7540/ClaimCancelRedeemRequest7540Hook.sol";
import { CancelDepositHook } from "../src/core/hooks/vaults/super-vault/CancelDepositHook.sol";
import { CancelRedeemHook } from "../src/core/hooks/vaults/super-vault/CancelRedeemHook.sol";
import { ApproveAndRequestDeposit7540VaultHook } from
    "../src/core/hooks/vaults/7540/ApproveAndRequestDeposit7540VaultHook.sol";
import { RequestRedeem7540VaultHook } from "../src/core/hooks/vaults/7540/RequestRedeem7540VaultHook.sol";
import { Withdraw7540VaultHook } from "../src/core/hooks/vaults/7540/Withdraw7540VaultHook.sol";
import { ApproveAndWithdraw7540VaultHook } from "../src/core/hooks/vaults/7540/ApproveAndWithdraw7540VaultHook.sol";
import { ApproveAndRedeem7540VaultHook } from "../src/core/hooks/vaults/7540/ApproveAndRedeem7540VaultHook.sol";
// bridges hooks
import { AcrossSendFundsAndExecuteOnDstHook } from
    "../src/core/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHook.sol";

// Swap hooks
// --- 1inch
import { Swap1InchHook } from "../src/core/hooks/swappers/1inch/Swap1InchHook.sol";

// --- Odos
import { SwapOdosHook } from "../src/core/hooks/swappers/odos/SwapOdosHook.sol";
import { ApproveAndSwapOdosHook } from "../src/core/hooks/swappers/odos/ApproveAndSwapOdosHook.sol";
import { OdosAPIParser } from "./utils/parsers/OdosAPIParser.sol";
import { IOdosRouterV2 } from "../src/vendor/odos/IOdosRouterV2.sol";

// --- Spectra
import { SpectraCommands } from "../src/vendor/spectra/SpectraCommands.sol";
import { ISpectraRouter } from "../src/vendor/spectra/ISpectraRouter.sol";

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

// --- Pendle

import {
    IPendleRouterV4,
    LimitOrderData,
    FillOrderParams,
    TokenInput,
    ApproxParams,
    SwapType,
    SwapData
} from "../src/vendor/pendle/IPendleRouterV4.sol";

// --- Ethena
import { EthenaCooldownSharesHook } from "./mocks/unused-hooks/EthenaCooldownSharesHook.sol";
import { EthenaUnstakeHook } from "./mocks/unused-hooks/EthenaUnstakeHook.sol";
import { SpectraExchangeHook } from "../src/core/hooks/spectra/SpectraExchangeHook.sol";
import { PendleRouterSwapHook } from "../src/core/hooks/pendle/PendleRouterSwapHook.sol";
import { MockSpectraRouter } from "./mocks/MockSpectraRouter.sol";
import { MockPendleRouter } from "./mocks/MockPendleRouter.sol";

// action oracles
import { ERC4626YieldSourceOracle } from "../src/core/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { ERC5115YieldSourceOracle } from "../src/core/accounting/oracles/ERC5115YieldSourceOracle.sol";
import { SuperOracle } from "../src/core/accounting/oracles/SuperOracle.sol";
import { ERC7540YieldSourceOracle } from "../src/core/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { StakingYieldSourceOracle } from "../src/core/accounting/oracles/StakingYieldSourceOracle.sol";

// external
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";

import { ExecutionReturnData } from "modulekit/test/RhinestoneModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/kernel/types/Constants.sol";

import { AcrossV3Helper } from "pigeon/across/AcrossV3Helper.sol";
import { DebridgeHelper } from "pigeon/debridge/DebridgeHelper.sol";
import { MockOdosRouterV2 } from "./mocks/MockOdosRouterV2.sol";
import { MockTargetExecutor } from "./mocks/MockTargetExecutor.sol";
import "../src/vendor/1inch/I1InchAggregationRouterV6.sol";
import { IOdosRouterV2 } from "../src/vendor/odos/IOdosRouterV2.sol";
import { PeripheryRegistry } from "../src/periphery/PeripheryRegistry.sol";

// SuperformNativePaymaster
import { SuperNativePaymaster } from "../src/core/paymaster/SuperNativePaymaster.sol";

// Nexus and Rhinestone overrides to allow for SuperformNativePaymaster
import { IAccountFactory } from "modulekit/accounts/factory/interface/IAccountFactory.sol";
import { getFactory, getHelper, getStorageCompliance } from "modulekit/test/utils/Storage.sol";
import { IEntryPoint } from "@account-abstraction/interfaces/IEntryPoint.sol";

import { BootstrapConfig, INexusBootstrap } from "../src/vendor/nexus/INexusBootstrap.sol";
import { INexusFactory } from "../src/vendor/nexus/INexusFactory.sol";
import { IERC7484 } from "../src/vendor/nexus/IERC7484.sol";
import { MockRegistry } from "./mocks/MockRegistry.sol";

import { BaseHook } from "../src/core/hooks/BaseHook.sol";
import { MockBaseHook } from "./mocks/MockBaseHook.sol";

import "forge-std/console2.sol";

struct Addresses {
    ISuperLedger superLedger;
    ISuperLedger erc1155Ledger;
    ISuperLedgerConfiguration superLedgerConfiguration;
    ISuperRegistry superRegistry;
    ISuperExecutor superExecutor;
    ISuperExecutor acrossTargetExecutor;
    ApproveERC20Hook approveErc20Hook;
    MorphoBorrowHook morphoBorrowHook;
    MorphoRepayHook morphoRepayHook;
    MorphoRepayAndWithdrawHook morphoRepayAndWithdrawHook;
    TransferERC20Hook transferErc20Hook;
    Deposit4626VaultHook deposit4626VaultHook;
    ApproveAndSwapOdosHook approveAndSwapOdosHook;
    ApproveAndFluidStakeHook approveAndFluidStakeHook;
    ApproveAndDeposit4626VaultHook approveAndDeposit4626VaultHook;
    ApproveAndDeposit5115VaultHook approveAndDeposit5115VaultHook;
    ApproveAndRequestDeposit7540VaultHook approveAndRequestDeposit7540VaultHook;
    Redeem4626VaultHook redeem4626VaultHook;
    ApproveAndRedeem4626VaultHook approveAndRedeem4626VaultHook;
    Deposit5115VaultHook deposit5115VaultHook;
    ApproveAndRedeem5115VaultHook approveAndRedeem5115VaultHook;
    Redeem5115VaultHook redeem5115VaultHook;
    Deposit7540VaultHook deposit7540VaultHook;
    RequestDeposit7540VaultHook requestDeposit7540VaultHook;
    RequestRedeem7540VaultHook requestRedeem7540VaultHook;
    Withdraw7540VaultHook withdraw7540VaultHook;
    ApproveAndWithdraw7540VaultHook approveAndWithdraw7540VaultHook;
    ApproveAndRedeem7540VaultHook approveAndRedeem7540VaultHook;
    CancelDepositRequest7540Hook cancelDepositRequest7540Hook;
    CancelRedeemRequest7540Hook cancelRedeemRequest7540Hook;
    ClaimCancelDepositRequest7540Hook claimCancelDepositRequest7540Hook;
    ClaimCancelRedeemRequest7540Hook claimCancelRedeemRequest7540Hook;
    CancelDepositHook cancelDepositHook;
    CancelRedeemHook cancelRedeemHook;
    AcrossSendFundsAndExecuteOnDstHook acrossSendFundsAndExecuteOnDstHook;
    Swap1InchHook swap1InchHook;
    SwapOdosHook swapOdosHook;
    GearboxStakeHook gearboxStakeHook;
    GearboxUnstakeHook gearboxUnstakeHook;
    ApproveAndGearboxStakeHook approveAndGearboxStakeHook;
    FluidStakeHook fluidStakeHook;
    FluidUnstakeHook fluidUnstakeHook;
    SpectraExchangeHook spectraExchangeHook;
    PendleRouterSwapHook pendleRouterSwapHook;
    FluidClaimRewardHook fluidClaimRewardHook;
    GearboxClaimRewardHook gearboxClaimRewardHook;
    YearnClaimOneRewardHook yearnClaimOneRewardHook;
    EthenaCooldownSharesHook ethenaCooldownSharesHook;
    EthenaUnstakeHook ethenaUnstakeHook;
    ERC4626YieldSourceOracle erc4626YieldSourceOracle;
    ERC5115YieldSourceOracle erc5115YieldSourceOracle;
    ERC7540YieldSourceOracle erc7540YieldSourceOracle;
    StakingYieldSourceOracle stakingYieldSourceOracle;
    SuperOracle oracleRegistry;
    SuperMerkleValidator superMerkleValidator;
    SuperDestinationValidator superDestinationValidator;
    PeripheryRegistry peripheryRegistry;
    SuperNativePaymaster superNativePaymaster;
    MockTargetExecutor mockTargetExecutor;
}

contract BaseTest is Helpers, RhinestoneModuleKit, SignatureHelper, MerkleTreeHelper, OdosAPIParser {
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
        Stakes,
        Claims,
        Loans,
        Swaps,
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
    mapping(uint64 chainId => address) public NEXUS_FACTORY_ADDRESSES;

    /// @dev mappings

    mapping(uint64 chainId => mapping(string underlying => address realAddress)) public existingUnderlyingTokens;

    mapping(
        uint64 chainId
            => mapping(string vaultKind => mapping(string vaultName => mapping(string underlying => address realVault)))
    ) public realVaultAddresses;

    mapping(uint64 chainId => mapping(string contractName => address contractAddress)) public contractAddresses;

    mapping(uint64 chainId => mapping(string hookName => address hook)) public hookAddresses;
    mapping(uint64 chainId => address[]) public hookListPerChain;

    mapping(uint64 chainId => mapping(HookCategory category => Hook[] hooksByCategory)) public hooksByCategory;

    mapping(uint64 chainId => mapping(string name => Hook hookInstance)) public hooks;

    mapping(uint64 chainId => AccountInstance accountInstance) public accountInstances;
    mapping(uint64 chainId => AccountInstance[] randomAccountInstances) public randomAccountInstances;

    mapping(uint64 chainId => address mockOdosRouter) public mockOdosRouters;
    mapping(uint64 chainId => address pendleRouter) public PENDLE_ROUTERS;
    mapping(uint64 chainId => address pendleSwap) public PENDLE_SWAP;
    mapping(uint64 chainId => address odosRouter) public ODOS_ROUTER;

    // chainID => FORK
    mapping(uint64 chainId => uint256 fork) public FORKS;

    mapping(uint64 chainId => string forkUrl) public RPC_URLS;

    mapping(uint64 chainId => address validatorSigner) public validatorSigners;
    mapping(uint64 chainId => uint256 validatorSignerPrivateKey) public validatorSignerPrivateKeys;

    string public ETHEREUM_RPC_URL = vm.envString(ETHEREUM_RPC_URL_KEY); // Native token: ETH
    string public OPTIMISM_RPC_URL = vm.envString(OPTIMISM_RPC_URL_KEY); // Native token: ETH
    string public BASE_RPC_URL = vm.envString(BASE_RPC_URL_KEY); // Native token: ETH

    bool constant DEBUG = false;

    string constant DEFAULT_ACCOUNT = "NEXUS";

    bytes32 constant SALT = keccak256("TEST");

    address public mockBaseHook;

    bool public useLatestFork = false;

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
            mockBaseHook = address(new MockBaseHook());
            vm.makePersistent(mockBaseHook);

            address acrossV3Helper = address(new AcrossV3Helper());
            vm.allowCheatcodes(acrossV3Helper);
            vm.makePersistent(acrossV3Helper);
            contractAddresses[chainIds[i]][ACROSS_V3_HELPER_KEY] = acrossV3Helper;

            address debridgeHelper = address(new DebridgeHelper());
            vm.allowCheatcodes(debridgeHelper);
            vm.makePersistent(debridgeHelper);
            contractAddresses[chainIds[i]][DEBRIDGE_HELPER_KEY] = debridgeHelper;

            A[i].superRegistry = ISuperRegistry(address(new SuperRegistry{ salt: SALT }(address(this))));
            vm.label(address(A[i].superRegistry), SUPER_REGISTRY_KEY);
            contractAddresses[chainIds[i]][SUPER_REGISTRY_KEY] = address(A[i].superRegistry);

            A[i].peripheryRegistry = new PeripheryRegistry{ salt: SALT }(address(this), TREASURY);
            vm.label(address(A[i].peripheryRegistry), PERIPHERY_REGISTRY_KEY);
            contractAddresses[chainIds[i]][PERIPHERY_REGISTRY_KEY] = address(A[i].peripheryRegistry);

            A[i].oracleRegistry = new SuperOracle{ salt: SALT }(
                address(this), new address[](0), new address[](0), new bytes32[](0), new address[](0)
            );
            vm.label(address(A[i].oracleRegistry), SUPER_ORACLE_KEY);
            contractAddresses[chainIds[i]][SUPER_ORACLE_KEY] = address(A[i].oracleRegistry);

            A[i].superExecutor = ISuperExecutor(address(new SuperExecutor{ salt: SALT }(address(A[i].superRegistry))));
            vm.label(address(A[i].superExecutor), SUPER_EXECUTOR_KEY);
            contractAddresses[chainIds[i]][SUPER_EXECUTOR_KEY] = address(A[i].superExecutor);

            A[i].mockTargetExecutor = new MockTargetExecutor{ salt: SALT }(address(A[i].superRegistry));
            vm.label(address(A[i].mockTargetExecutor), MOCK_TARGET_EXECUTOR_KEY);
            contractAddresses[chainIds[i]][MOCK_TARGET_EXECUTOR_KEY] = address(A[i].mockTargetExecutor);

            A[i].superLedgerConfiguration = ISuperLedgerConfiguration(
                address(new SuperLedgerConfiguration{ salt: SALT }(address(A[i].superRegistry)))
            );
            vm.label(address(A[i].superLedgerConfiguration), SUPER_LEDGER_CONFIGURATION_KEY);
            contractAddresses[chainIds[i]][SUPER_LEDGER_CONFIGURATION_KEY] = address(A[i].superLedgerConfiguration);

            A[i].superLedger = ISuperLedger(
                address(
                    new SuperLedger{ salt: SALT }(address(A[i].superLedgerConfiguration), address(A[i].superRegistry))
                )
            );
            vm.label(address(A[i].superLedger), SUPER_LEDGER_KEY);
            contractAddresses[chainIds[i]][SUPER_LEDGER_KEY] = address(A[i].superLedger);

            A[i].erc1155Ledger = ISuperLedger(
                address(
                    new ERC5115Ledger{ salt: SALT }(address(A[i].superLedgerConfiguration), address(A[i].superRegistry))
                )
            );
            vm.label(address(A[i].erc1155Ledger), ERC1155_LEDGER_KEY);
            contractAddresses[chainIds[i]][ERC1155_LEDGER_KEY] = address(A[i].erc1155Ledger);

            A[i].superNativePaymaster = new SuperNativePaymaster{ salt: SALT }(IEntryPoint(ENTRYPOINT_ADDR));
            vm.label(address(A[i].superNativePaymaster), SUPER_NATIVE_PAYMASTER_KEY);
            contractAddresses[chainIds[i]][SUPER_NATIVE_PAYMASTER_KEY] = address(A[i].superNativePaymaster);

            A[i].superMerkleValidator = new SuperMerkleValidator();
            vm.label(address(A[i].superMerkleValidator), SUPER_MERKLE_VALIDATOR_KEY);
            contractAddresses[chainIds[i]][SUPER_MERKLE_VALIDATOR_KEY] = address(A[i].superMerkleValidator);

            A[i].superDestinationValidator = new SuperDestinationValidator{ salt: SALT }();
            vm.label(address(A[i].superDestinationValidator), SUPER_DESTINATION_VALIDATOR_KEY);
            contractAddresses[chainIds[i]][SUPER_DESTINATION_VALIDATOR_KEY] = address(A[i].superDestinationValidator);

            A[i].acrossTargetExecutor = ISuperExecutor(
                address(
                    new AcrossTargetExecutor{ salt: SALT }(
                        address(A[i].superRegistry),
                        SPOKE_POOL_V3_ADDRESSES[chainIds[i]],
                        address(A[i].superDestinationValidator),
                        NEXUS_FACTORY_ADDRESSES[chainIds[i]]
                    )
                )
            );
            vm.label(address(A[i].acrossTargetExecutor), ACROSS_TARGET_EXECUTOR_KEY);
            contractAddresses[chainIds[i]][ACROSS_TARGET_EXECUTOR_KEY] = address(A[i].acrossTargetExecutor);

            /// @dev action oracles
            A[i].erc4626YieldSourceOracle = new ERC4626YieldSourceOracle{ salt: SALT }(address(A[i].superRegistry));
            vm.label(address(A[i].erc4626YieldSourceOracle), ERC4626_YIELD_SOURCE_ORACLE_KEY);
            contractAddresses[chainIds[i]][ERC4626_YIELD_SOURCE_ORACLE_KEY] = address(A[i].erc4626YieldSourceOracle);

            A[i].erc5115YieldSourceOracle = new ERC5115YieldSourceOracle{ salt: SALT }(address(A[i].superRegistry));
            vm.label(address(A[i].erc5115YieldSourceOracle), ERC5115_YIELD_SOURCE_ORACLE_KEY);
            contractAddresses[chainIds[i]][ERC5115_YIELD_SOURCE_ORACLE_KEY] = address(A[i].erc5115YieldSourceOracle);

            A[i].erc7540YieldSourceOracle = new ERC7540YieldSourceOracle{ salt: SALT }(address(A[i].superRegistry));
            vm.label(address(A[i].erc7540YieldSourceOracle), ERC7540_YIELD_SOURCE_ORACLE_KEY);
            contractAddresses[chainIds[i]][ERC7540_YIELD_SOURCE_ORACLE_KEY] = address(A[i].erc7540YieldSourceOracle);

            A[i].stakingYieldSourceOracle = new StakingYieldSourceOracle{ salt: SALT }(address(A[i].superRegistry));
            vm.label(address(A[i].stakingYieldSourceOracle), STAKING_YIELD_SOURCE_ORACLE_KEY);
            contractAddresses[chainIds[i]][STAKING_YIELD_SOURCE_ORACLE_KEY] = address(A[i].stakingYieldSourceOracle);
        }
        return A;
    }

    function _deployHooks(Addresses[] memory A) internal returns (Addresses[] memory) {
        if (DEBUG) console2.log("---------------- DEPLOYING HOOKS ----------------");
        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);

            address[] memory hooksAddresses = new address[](41);

            A[i].approveErc20Hook = new ApproveERC20Hook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
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
            hooksAddresses[0] = address(A[i].approveErc20Hook);

            A[i].transferErc20Hook = new TransferERC20Hook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
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
            hooksAddresses[1] = address(A[i].transferErc20Hook);

            A[i].deposit4626VaultHook =
                new Deposit4626VaultHook{ salt: SALT }(_getContract(chainIds[i], "SuperRegistry"));
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
            hooksAddresses[2] = address(A[i].deposit4626VaultHook);

            A[i].approveAndDeposit4626VaultHook =
                new ApproveAndDeposit4626VaultHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
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
            hooksAddresses[3] = address(A[i].approveAndDeposit4626VaultHook);

            A[i].redeem4626VaultHook =
                new Redeem4626VaultHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
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
            hooksAddresses[4] = address(A[i].redeem4626VaultHook);

            A[i].approveAndRedeem4626VaultHook =
                new ApproveAndRedeem4626VaultHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].approveAndRedeem4626VaultHook), APPROVE_AND_REDEEM_4626_VAULT_HOOK_KEY);
            hookAddresses[chainIds[i]][APPROVE_AND_REDEEM_4626_VAULT_HOOK_KEY] =
                address(A[i].approveAndRedeem4626VaultHook);
            hooks[chainIds[i]][APPROVE_AND_REDEEM_4626_VAULT_HOOK_KEY] = Hook(
                APPROVE_AND_REDEEM_4626_VAULT_HOOK_KEY,
                HookCategory.TokenApprovals,
                HookCategory.VaultWithdrawals,
                address(A[i].approveAndRedeem4626VaultHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.VaultWithdrawals].push(
                hooks[chainIds[i]][APPROVE_AND_REDEEM_4626_VAULT_HOOK_KEY]
            );
            hooksAddresses[5] = address(A[i].approveAndRedeem4626VaultHook);

            A[i].deposit5115VaultHook =
                new Deposit5115VaultHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
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
            hooksAddresses[6] = address(A[i].deposit5115VaultHook);

            A[i].approveAndDeposit5115VaultHook =
                new ApproveAndDeposit5115VaultHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
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
            hooksAddresses[7] = address(A[i].approveAndDeposit5115VaultHook);

            A[i].redeem5115VaultHook =
                new Redeem5115VaultHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
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
            hooksAddresses[8] = address(A[i].redeem5115VaultHook);

            A[i].approveAndRedeem5115VaultHook =
                new ApproveAndRedeem5115VaultHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].approveAndRedeem5115VaultHook), APPROVE_AND_REDEEM_5115_VAULT_HOOK_KEY);
            hookAddresses[chainIds[i]][APPROVE_AND_REDEEM_5115_VAULT_HOOK_KEY] =
                address(A[i].approveAndRedeem5115VaultHook);
            hooks[chainIds[i]][APPROVE_AND_REDEEM_5115_VAULT_HOOK_KEY] = Hook(
                APPROVE_AND_REDEEM_5115_VAULT_HOOK_KEY,
                HookCategory.TokenApprovals,
                HookCategory.VaultWithdrawals,
                address(A[i].approveAndRedeem5115VaultHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.VaultWithdrawals].push(
                hooks[chainIds[i]][APPROVE_AND_REDEEM_5115_VAULT_HOOK_KEY]
            );
            hooksAddresses[9] = address(A[i].approveAndRedeem5115VaultHook);

            A[i].requestDeposit7540VaultHook =
                new RequestDeposit7540VaultHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
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
            hooksAddresses[10] = address(A[i].requestDeposit7540VaultHook);

            A[i].approveAndRequestDeposit7540VaultHook =
                new ApproveAndRequestDeposit7540VaultHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
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
            hooksAddresses[11] = address(A[i].approveAndRequestDeposit7540VaultHook);

            A[i].requestRedeem7540VaultHook =
                new RequestRedeem7540VaultHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
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
            hooksAddresses[12] = address(A[i].requestRedeem7540VaultHook);

            A[i].deposit7540VaultHook =
                new Deposit7540VaultHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
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
            hooksAddresses[13] = address(A[i].deposit7540VaultHook);

            A[i].withdraw7540VaultHook =
                new Withdraw7540VaultHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
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
            hooksAddresses[14] = address(A[i].withdraw7540VaultHook);
            A[i].approveAndWithdraw7540VaultHook =
                new ApproveAndWithdraw7540VaultHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].approveAndWithdraw7540VaultHook), APPROVE_AND_WITHDRAW_7540_VAULT_HOOK_KEY);
            hookAddresses[chainIds[i]][APPROVE_AND_WITHDRAW_7540_VAULT_HOOK_KEY] =
                address(A[i].approveAndWithdraw7540VaultHook);
            hooks[chainIds[i]][APPROVE_AND_WITHDRAW_7540_VAULT_HOOK_KEY] = Hook(
                APPROVE_AND_WITHDRAW_7540_VAULT_HOOK_KEY,
                HookCategory.TokenApprovals,
                HookCategory.VaultWithdrawals,
                address(A[i].approveAndWithdraw7540VaultHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.VaultWithdrawals].push(
                hooks[chainIds[i]][APPROVE_AND_WITHDRAW_7540_VAULT_HOOK_KEY]
            );
            hooksAddresses[15] = address(A[i].approveAndWithdraw7540VaultHook);

            A[i].approveAndRedeem7540VaultHook =
                new ApproveAndRedeem7540VaultHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].approveAndRedeem7540VaultHook), APPROVE_AND_REDEEM_7540_VAULT_HOOK_KEY);
            hookAddresses[chainIds[i]][APPROVE_AND_REDEEM_7540_VAULT_HOOK_KEY] =
                address(A[i].approveAndRedeem7540VaultHook);
            hooks[chainIds[i]][APPROVE_AND_REDEEM_7540_VAULT_HOOK_KEY] = Hook(
                APPROVE_AND_REDEEM_7540_VAULT_HOOK_KEY,
                HookCategory.TokenApprovals,
                HookCategory.VaultWithdrawals,
                address(A[i].approveAndRedeem7540VaultHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.VaultWithdrawals].push(
                hooks[chainIds[i]][APPROVE_AND_REDEEM_7540_VAULT_HOOK_KEY]
            );
            hooksAddresses[16] = address(A[i].approveAndRedeem7540VaultHook);

            A[i].swap1InchHook =
                new Swap1InchHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY), ONE_INCH_ROUTER);
            vm.label(address(A[i].swap1InchHook), SWAP_1INCH_HOOK_KEY);
            hookAddresses[chainIds[i]][SWAP_1INCH_HOOK_KEY] = address(A[i].swap1InchHook);
            hooks[chainIds[i]][SWAP_1INCH_HOOK_KEY] = Hook(
                SWAP_1INCH_HOOK_KEY, HookCategory.Swaps, HookCategory.TokenApprovals, address(A[i].swap1InchHook), ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Swaps].push(hooks[chainIds[i]][SWAP_1INCH_HOOK_KEY]);
            hooksAddresses[17] = address(A[i].swap1InchHook);

            MockOdosRouterV2 odosRouter = new MockOdosRouterV2{ salt: SALT }();
            mockOdosRouters[chainIds[i]] = address(odosRouter);
            vm.label(address(odosRouter), "MockOdosRouterV2");
            A[i].swapOdosHook =
                new SwapOdosHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY), address(odosRouter));
            vm.label(address(A[i].swapOdosHook), SWAP_ODOS_HOOK_KEY);
            hookAddresses[chainIds[i]][SWAP_ODOS_HOOK_KEY] = address(A[i].swapOdosHook);
            hooks[chainIds[i]][SWAP_ODOS_HOOK_KEY] = Hook(
                SWAP_ODOS_HOOK_KEY, HookCategory.Swaps, HookCategory.TokenApprovals, address(A[i].swapOdosHook), ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Swaps].push(hooks[chainIds[i]][SWAP_ODOS_HOOK_KEY]);
            hooksAddresses[18] = address(A[i].swapOdosHook);

            A[i].approveAndSwapOdosHook = new ApproveAndSwapOdosHook{ salt: SALT }(
                _getContract(chainIds[i], SUPER_REGISTRY_KEY), address(odosRouter)
            );
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
            hooksAddresses[19] = address(A[i].approveAndSwapOdosHook);

            A[i].acrossSendFundsAndExecuteOnDstHook = new AcrossSendFundsAndExecuteOnDstHook{ salt: SALT }(
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
            hooksAddresses[20] = address(A[i].acrossSendFundsAndExecuteOnDstHook);

            A[i].fluidClaimRewardHook =
                new FluidClaimRewardHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].fluidClaimRewardHook), FLUID_CLAIM_REWARD_HOOK_KEY);
            hookAddresses[chainIds[i]][FLUID_CLAIM_REWARD_HOOK_KEY] = address(A[i].fluidClaimRewardHook);
            hooks[chainIds[i]][FLUID_CLAIM_REWARD_HOOK_KEY] = Hook(
                FLUID_CLAIM_REWARD_HOOK_KEY,
                HookCategory.Claims,
                HookCategory.None,
                address(A[i].fluidClaimRewardHook),
                ""
            );
            hooksAddresses[21] = address(A[i].fluidClaimRewardHook);

            A[i].fluidStakeHook = new FluidStakeHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].fluidStakeHook), FLUID_STAKE_HOOK_KEY);
            hookAddresses[chainIds[i]][FLUID_STAKE_HOOK_KEY] = address(A[i].fluidStakeHook);
            hooks[chainIds[i]][FLUID_STAKE_HOOK_KEY] =
                Hook(FLUID_STAKE_HOOK_KEY, HookCategory.Stakes, HookCategory.None, address(A[i].fluidStakeHook), "");
            hooksAddresses[22] = address(A[i].fluidStakeHook);

            A[i].approveAndFluidStakeHook =
                new ApproveAndFluidStakeHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
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
            hooksAddresses[23] = address(A[i].approveAndFluidStakeHook);

            A[i].fluidUnstakeHook = new FluidUnstakeHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].fluidUnstakeHook), FLUID_UNSTAKE_HOOK_KEY);
            hookAddresses[chainIds[i]][FLUID_UNSTAKE_HOOK_KEY] = address(A[i].fluidUnstakeHook);
            hooks[chainIds[i]][FLUID_UNSTAKE_HOOK_KEY] =
                Hook(FLUID_UNSTAKE_HOOK_KEY, HookCategory.Stakes, HookCategory.None, address(A[i].fluidUnstakeHook), "");
            hooksAddresses[24] = address(A[i].fluidUnstakeHook);

            A[i].gearboxClaimRewardHook =
                new GearboxClaimRewardHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].gearboxClaimRewardHook), GEARBOX_CLAIM_REWARD_HOOK_KEY);
            hookAddresses[chainIds[i]][GEARBOX_CLAIM_REWARD_HOOK_KEY] = address(A[i].gearboxClaimRewardHook);
            hooks[chainIds[i]][GEARBOX_CLAIM_REWARD_HOOK_KEY] = Hook(
                GEARBOX_CLAIM_REWARD_HOOK_KEY,
                HookCategory.Claims,
                HookCategory.None,
                address(A[i].gearboxClaimRewardHook),
                ""
            );
            hooksAddresses[25] = address(A[i].gearboxClaimRewardHook);

            A[i].gearboxStakeHook = new GearboxStakeHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
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
            hooksAddresses[26] = address(A[i].gearboxStakeHook);

            A[i].approveAndGearboxStakeHook =
                new ApproveAndGearboxStakeHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
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
            hooksAddresses[27] = address(A[i].approveAndGearboxStakeHook);

            A[i].gearboxUnstakeHook =
                new GearboxUnstakeHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].gearboxUnstakeHook), GEARBOX_UNSTAKE_HOOK_KEY);
            hookAddresses[chainIds[i]][GEARBOX_UNSTAKE_HOOK_KEY] = address(A[i].gearboxUnstakeHook);
            hooks[chainIds[i]][GEARBOX_UNSTAKE_HOOK_KEY] = Hook(
                GEARBOX_UNSTAKE_HOOK_KEY, HookCategory.Claims, HookCategory.Stakes, address(A[i].gearboxUnstakeHook), ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Claims].push(hooks[chainIds[i]][GEARBOX_UNSTAKE_HOOK_KEY]);
            hooksAddresses[28] = address(A[i].gearboxUnstakeHook);

            A[i].yearnClaimOneRewardHook =
                new YearnClaimOneRewardHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].yearnClaimOneRewardHook), YEARN_CLAIM_ONE_REWARD_HOOK_KEY);
            hooks[chainIds[i]][YEARN_CLAIM_ONE_REWARD_HOOK_KEY] = Hook(
                YEARN_CLAIM_ONE_REWARD_HOOK_KEY,
                HookCategory.Claims,
                HookCategory.Stakes,
                address(A[i].yearnClaimOneRewardHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Claims].push(hooks[chainIds[i]][YEARN_CLAIM_ONE_REWARD_HOOK_KEY]);
            hooksAddresses[29] = address(A[i].yearnClaimOneRewardHook);

            /// @dev EXPERIMENTAL HOOKS FROM HERE ONWARDS
            A[i].ethenaCooldownSharesHook =
                new EthenaCooldownSharesHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].ethenaCooldownSharesHook), ETHENA_COOLDOWN_SHARES_HOOK_KEY);
            hookAddresses[chainIds[i]][ETHENA_COOLDOWN_SHARES_HOOK_KEY] = address(A[i].ethenaCooldownSharesHook);
            hooksAddresses[30] = address(A[i].ethenaCooldownSharesHook);

            A[i].ethenaUnstakeHook = new EthenaUnstakeHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].ethenaUnstakeHook), ETHENA_UNSTAKE_HOOK_KEY);
            hookAddresses[chainIds[i]][ETHENA_UNSTAKE_HOOK_KEY] = address(A[i].ethenaUnstakeHook);
            hooksAddresses[31] = address(A[i].ethenaUnstakeHook);

            A[i].spectraExchangeHook = new SpectraExchangeHook{ salt: SALT }(
                _getContract(chainIds[i], SUPER_REGISTRY_KEY),
                address(CHAIN_1_SpectraRouter) //TODO: update per chain
            );
            vm.label(address(A[i].spectraExchangeHook), SPECTRA_EXCHANGE_HOOK_KEY);
            hookAddresses[chainIds[i]][SPECTRA_EXCHANGE_HOOK_KEY] = address(A[i].spectraExchangeHook);
            hooksAddresses[32] = address(A[i].spectraExchangeHook);

            A[i].pendleRouterSwapHook = new PendleRouterSwapHook{ salt: SALT }(
                _getContract(chainIds[i], SUPER_REGISTRY_KEY), CHAIN_1_PendleRouter
            ); //TODO: update per chain
            vm.label(address(A[i].pendleRouterSwapHook), PENDLE_ROUTER_SWAP_HOOK_KEY);
            hookAddresses[chainIds[i]][PENDLE_ROUTER_SWAP_HOOK_KEY] = address(A[i].pendleRouterSwapHook);
            hooksAddresses[33] = address(A[i].pendleRouterSwapHook);

            A[i].cancelDepositRequest7540Hook =
                new CancelDepositRequest7540Hook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].cancelDepositRequest7540Hook), CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY);
            hookAddresses[chainIds[i]][CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY] =
                address(A[i].cancelDepositRequest7540Hook);
            hooks[chainIds[i]][CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY] = Hook(
                CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY,
                HookCategory.VaultWithdrawals,
                HookCategory.VaultDeposits,
                address(A[i].cancelDepositRequest7540Hook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.VaultWithdrawals].push(
                hooks[chainIds[i]][CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY]
            );
            hooksAddresses[34] = address(A[i].cancelDepositRequest7540Hook);

            A[i].cancelRedeemRequest7540Hook =
                new CancelRedeemRequest7540Hook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].cancelRedeemRequest7540Hook), CANCEL_REDEEM_REQUEST_7540_HOOK_KEY);
            hookAddresses[chainIds[i]][CANCEL_REDEEM_REQUEST_7540_HOOK_KEY] = address(A[i].cancelRedeemRequest7540Hook);
            hooks[chainIds[i]][CANCEL_REDEEM_REQUEST_7540_HOOK_KEY] = Hook(
                CANCEL_REDEEM_REQUEST_7540_HOOK_KEY,
                HookCategory.VaultWithdrawals,
                HookCategory.VaultDeposits,
                address(A[i].cancelRedeemRequest7540Hook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.VaultWithdrawals].push(
                hooks[chainIds[i]][CANCEL_REDEEM_REQUEST_7540_HOOK_KEY]
            );
            hooksAddresses[35] = address(A[i].cancelRedeemRequest7540Hook);

            A[i].claimCancelDepositRequest7540Hook =
                new ClaimCancelDepositRequest7540Hook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].claimCancelDepositRequest7540Hook), CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY);
            hookAddresses[chainIds[i]][CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY] =
                address(A[i].claimCancelDepositRequest7540Hook);
            hooks[chainIds[i]][CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY] = Hook(
                CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY,
                HookCategory.VaultWithdrawals,
                HookCategory.VaultDeposits,
                address(A[i].claimCancelDepositRequest7540Hook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.VaultWithdrawals].push(
                hooks[chainIds[i]][CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY]
            );
            hooksAddresses[36] = address(A[i].claimCancelDepositRequest7540Hook);

            A[i].claimCancelRedeemRequest7540Hook =
                new ClaimCancelRedeemRequest7540Hook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].claimCancelRedeemRequest7540Hook), CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY);
            hookAddresses[chainIds[i]][CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY] =
                address(A[i].claimCancelRedeemRequest7540Hook);
            hooks[chainIds[i]][CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY] = Hook(
                CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY,
                HookCategory.VaultWithdrawals,
                HookCategory.VaultDeposits,
                address(A[i].claimCancelRedeemRequest7540Hook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.VaultWithdrawals].push(
                hooks[chainIds[i]][CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY]
            );
            hooksAddresses[37] = address(A[i].claimCancelRedeemRequest7540Hook);

            A[i].cancelDepositHook = new CancelDepositHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].cancelDepositHook), CANCEL_DEPOSIT_HOOK_KEY);
            hookAddresses[chainIds[i]][CANCEL_DEPOSIT_HOOK_KEY] = address(A[i].cancelDepositHook);
            hooks[chainIds[i]][CANCEL_DEPOSIT_HOOK_KEY] = Hook(
                CANCEL_DEPOSIT_HOOK_KEY,
                HookCategory.VaultWithdrawals,
                HookCategory.VaultDeposits,
                address(A[i].cancelDepositHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.VaultWithdrawals].push(
                hooks[chainIds[i]][CANCEL_DEPOSIT_HOOK_KEY]
            );
            hooksAddresses[38] = address(A[i].cancelDepositHook);

            A[i].cancelRedeemHook = new CancelRedeemHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY));
            vm.label(address(A[i].cancelRedeemHook), CANCEL_REDEEM_HOOK_KEY);
            hookAddresses[chainIds[i]][CANCEL_REDEEM_HOOK_KEY] = address(A[i].cancelRedeemHook);
            hooks[chainIds[i]][CANCEL_REDEEM_HOOK_KEY] = Hook(
                CANCEL_REDEEM_HOOK_KEY,
                HookCategory.VaultWithdrawals,
                HookCategory.VaultDeposits,
                address(A[i].cancelRedeemHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.VaultWithdrawals].push(hooks[chainIds[i]][CANCEL_REDEEM_HOOK_KEY]);
            hooksAddresses[39] = address(A[i].cancelRedeemHook);

            A[i].morphoBorrowHook =
                new MorphoBorrowHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY), MORPHO);
            vm.label(address(A[i].morphoBorrowHook), MORPHO_BORROW_HOOK_KEY);
            hookAddresses[chainIds[i]][MORPHO_BORROW_HOOK_KEY] = address(A[i].morphoBorrowHook);
            hooks[chainIds[i]][MORPHO_BORROW_HOOK_KEY] =
                Hook(MORPHO_BORROW_HOOK_KEY, HookCategory.Loans, HookCategory.None, address(A[i].morphoBorrowHook), "");
            hooksByCategory[chainIds[i]][HookCategory.Loans].push(hooks[chainIds[i]][MORPHO_BORROW_HOOK_KEY]);
            hooksAddresses[38] = address(A[i].morphoBorrowHook);

            A[i].morphoRepayHook =
                new MorphoRepayHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY), MORPHO);
            vm.label(address(A[i].morphoRepayHook), MORPHO_REPAY_HOOK_KEY);
            hookAddresses[chainIds[i]][MORPHO_REPAY_HOOK_KEY] = address(A[i].morphoRepayHook);
            hooks[chainIds[i]][MORPHO_REPAY_HOOK_KEY] =
                Hook(MORPHO_REPAY_HOOK_KEY, HookCategory.Loans, HookCategory.None, address(A[i].morphoRepayHook), "");
            hooksByCategory[chainIds[i]][HookCategory.Loans].push(hooks[chainIds[i]][MORPHO_REPAY_HOOK_KEY]);
            hooksAddresses[39] = address(A[i].morphoRepayHook);

            A[i].morphoRepayAndWithdrawHook =
                new MorphoRepayAndWithdrawHook{ salt: SALT }(_getContract(chainIds[i], SUPER_REGISTRY_KEY), MORPHO);
            vm.label(address(A[i].morphoRepayAndWithdrawHook), MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY);
            hookAddresses[chainIds[i]][MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY] = address(A[i].morphoRepayAndWithdrawHook);
            hooksAddresses[40] = address(A[i].morphoRepayAndWithdrawHook);

            hookListPerChain[chainIds[i]] = hooksAddresses;
            _createHooksTree(chainIds[i], hooksAddresses);
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

            console2.log("Registering hooks for chain", chainIds[i]);
            if (DEBUG) {
                console2.log(address(A[i].deposit4626VaultHook));
                console2.log(address(A[i].redeem4626VaultHook));
                console2.log(address(A[i].approveAndRedeem4626VaultHook));
                console2.log(address(A[i].deposit5115VaultHook));
                console2.log(address(A[i].redeem5115VaultHook));
                console2.log(address(A[i].requestDeposit7540VaultHook));
                console2.log(address(A[i].requestRedeem7540VaultHook));
                console2.log(address(A[i].approveAndDeposit4626VaultHook));
                console2.log(address(A[i].approveAndDeposit5115VaultHook));
                console2.log(address(A[i].approveAndRedeem5115VaultHook));
                console2.log(address(A[i].approveAndRequestDeposit7540VaultHook));
                console2.log(address(A[i].approveErc20Hook));
                console2.log(address(A[i].transferErc20Hook));
                console2.log(address(A[i].deposit7540VaultHook));
                console2.log(address(A[i].withdraw7540VaultHook));
                console2.log(address(A[i].approveAndRedeem7540VaultHook));
                console2.log(address(A[i].swap1InchHook));
                console2.log(address(A[i].swapOdosHook));
                console2.log(address(A[i].approveAndSwapOdosHook));
                console2.log(address(A[i].acrossSendFundsAndExecuteOnDstHook));
                console2.log(address(A[i].fluidClaimRewardHook));
                console2.log(address(A[i].fluidStakeHook));
                console2.log(address(A[i].approveAndFluidStakeHook));
                console2.log(address(A[i].fluidUnstakeHook));
                console2.log(address(A[i].gearboxClaimRewardHook));
                console2.log(address(A[i].gearboxStakeHook));
                console2.log(address(A[i].approveAndGearboxStakeHook));
                console2.log(address(A[i].gearboxUnstakeHook));
                console2.log(address(A[i].yearnClaimOneRewardHook));
                console2.log(address(A[i].ethenaCooldownSharesHook));
                console2.log(address(A[i].ethenaUnstakeHook));
                console2.log(address(A[i].cancelDepositRequest7540Hook));
                console2.log(address(A[i].cancelRedeemRequest7540Hook));
                console2.log(address(A[i].claimCancelDepositRequest7540Hook));
                console2.log(address(A[i].claimCancelRedeemRequest7540Hook));
                console2.log(address(A[i].cancelDepositHook));
                console2.log(address(A[i].cancelRedeemHook));
            }

            // Register fulfillRequests hooks
            peripheryRegistry.registerHook(address(A[i].deposit4626VaultHook), true);
            peripheryRegistry.registerHook(address(A[i].redeem4626VaultHook), true);
            peripheryRegistry.registerHook(address(A[i].approveAndRedeem4626VaultHook), true);
            peripheryRegistry.registerHook(address(A[i].deposit5115VaultHook), true);
            peripheryRegistry.registerHook(address(A[i].redeem5115VaultHook), true);
            peripheryRegistry.registerHook(address(A[i].requestDeposit7540VaultHook), false);
            peripheryRegistry.registerHook(address(A[i].requestRedeem7540VaultHook), false);

            // Register remaining hooks
            peripheryRegistry.registerHook(address(A[i].approveAndDeposit4626VaultHook), true);
            peripheryRegistry.registerHook(address(A[i].approveAndDeposit5115VaultHook), true);
            peripheryRegistry.registerHook(address(A[i].approveAndRedeem5115VaultHook), true);
            peripheryRegistry.registerHook(address(A[i].approveAndRequestDeposit7540VaultHook), true);
            peripheryRegistry.registerHook(address(A[i].approveErc20Hook), false);
            peripheryRegistry.registerHook(address(A[i].transferErc20Hook), false);
            peripheryRegistry.registerHook(address(A[i].deposit7540VaultHook), true);
            peripheryRegistry.registerHook(address(A[i].withdraw7540VaultHook), false);
            peripheryRegistry.registerHook(address(A[i].approveAndRedeem7540VaultHook), true);
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
            peripheryRegistry.registerHook(address(A[i].cancelDepositRequest7540Hook), false);
            peripheryRegistry.registerHook(address(A[i].cancelRedeemRequest7540Hook), false);
            peripheryRegistry.registerHook(address(A[i].claimCancelDepositRequest7540Hook), false);
            peripheryRegistry.registerHook(address(A[i].claimCancelRedeemRequest7540Hook), false);
            peripheryRegistry.registerHook(address(A[i].cancelDepositHook), false);
            peripheryRegistry.registerHook(address(A[i].cancelRedeemHook), false);
            // EXPERIMENTAL HOOKS FROM HERE ONWARDS
            peripheryRegistry.registerHook(address(A[i].ethenaCooldownSharesHook), false);
            peripheryRegistry.registerHook(address(A[i].ethenaUnstakeHook), true);
            peripheryRegistry.registerHook(address(A[i].morphoBorrowHook), false);
            peripheryRegistry.registerHook(address(A[i].morphoRepayHook), false);
            peripheryRegistry.registerHook(address(A[i].morphoRepayAndWithdrawHook), false);
        }

        return A;
    }

    // Hook mocking helpers

    /**
     * @notice Setup hook mocks to clear execution context
     * @param hooks_ Array of hook addresses to mock
     */
    function _setupHookMocks(address[] memory hooks_) internal {
        for (uint256 i = 0; i < hooks_.length; i++) {
            vm.mockCall(hooks_[i], abi.encodeWithSignature("getExecutionCaller()"), abi.encode(address(0)));
        }
    }

    /**
     * @notice Helper to get all hooks for all chains
     * @return hooks Array of all hooks across all chains
     */
    function _getAllHooksForTest() internal view returns (address[] memory) {
        uint256 totalHooks = 0;

        // Count total hooks across all chains
        for (uint256 i = 0; i < chainIds.length; i++) {
            totalHooks += hookListPerChain[chainIds[i]].length;
        }

        // Create array to hold all hooks
        address[] memory allHooks = new address[](totalHooks);
        uint256 currentIndex = 0;

        // Populate array with hooks from all chains
        for (uint256 i = 0; i < chainIds.length; i++) {
            address[] memory chainHooks = hookListPerChain[chainIds[i]];
            for (uint256 j = 0; j < chainHooks.length; j++) {
                allHooks[currentIndex] = chainHooks[j];
                currentIndex++;
            }
        }

        return allHooks;
    }

    /**
     * @notice Modifier to mock hook execution context, allowing the same hook to be used multiple times in a test
     */
    modifier executeWithoutHookRestrictions() {
        // Get all hooks for current chain
        address[] memory hooks_ = _getAllHooksForTest();

        // Setup mocks for all hooks
        for (uint256 i = 0; i < hooks_.length; i++) {
            if (hooks_[i] != address(0)) {
                vm.mockFunction(
                    hooks_[i], address(mockBaseHook), abi.encodeWithSelector(BaseHook.getExecutionCaller.selector)
                );
            }
        }

        // Run the test
        _;

        // Clear all mocks
        vm.clearMockedCalls();
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
            instance.installModule({
                moduleTypeId: MODULE_TYPE_EXECUTOR,
                module: _getContract(chainIds[i], ACROSS_TARGET_EXECUTOR_KEY),
                data: ""
            });
            instance.installModule({
                moduleTypeId: MODULE_TYPE_VALIDATOR,
                module: _getContract(chainIds[i], SUPER_DESTINATION_VALIDATOR_KEY),
                data: abi.encode(validatorSigners[chainIds[i]])
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

        if (useLatestFork) {
            forks[ETH] = vm.createFork(ETHEREUM_RPC_URL);
            forks[OP] = vm.createFork(OPTIMISM_RPC_URL);
            forks[BASE] = vm.createFork(BASE_RPC_URL);
        } else {
            forks[ETH] = vm.createFork(ETHEREUM_RPC_URL, 21_929_476);
            forks[OP] = vm.createFork(OPTIMISM_RPC_URL, 132_481_010);
            forks[BASE] = vm.createFork(BASE_RPC_URL, 26_885_730);
        }

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

        mapping(uint64 => address) storage pendleRouters = PENDLE_ROUTERS;
        pendleRouters[ETH] = CHAIN_1_PendleRouter;
        vm.label(pendleRouters[ETH], "PendleRouterETH");
        pendleRouters[OP] = CHAIN_10_PendleRouter;
        vm.label(pendleRouters[OP], "PendleRouterOP");
        pendleRouters[BASE] = CHAIN_8453_PendleRouter;
        vm.label(pendleRouters[BASE], "PendleRouterBASE");

        mapping(uint64 => address) storage pendleSwaps = PENDLE_SWAP;
        pendleSwaps[ETH] = CHAIN_1_PendleSwap;
        vm.label(pendleSwaps[ETH], "PendleSwapETH");
        pendleSwaps[OP] = CHAIN_10_PendleSwap;
        vm.label(pendleSwaps[OP], "PendleSwapOP");
        pendleSwaps[BASE] = CHAIN_8453_PendleSwap;
        vm.label(pendleSwaps[BASE], "PendleSwapBASE");

        mapping(uint64 => address) storage odosRouters = ODOS_ROUTER;
        odosRouters[ETH] = CHAIN_1_ODOS_ROUTER;
        vm.label(odosRouters[ETH], "OdosRouterETH");
        odosRouters[OP] = CHAIN_10_ODOS_ROUTER;
        vm.label(odosRouters[OP], "OdosRouterOP");
        odosRouters[BASE] = CHAIN_8453_ODOS_ROUTER;
        vm.label(odosRouters[BASE], "OdosRouterBASE");

        mapping(uint64 => address) storage nexusFactoryAddressesMap = NEXUS_FACTORY_ADDRESSES;
        nexusFactoryAddressesMap[ETH] = CHAIN_1_NEXUS_FACTORY;
        vm.label(nexusFactoryAddressesMap[ETH], "NexusFactoryETH");
        nexusFactoryAddressesMap[OP] = CHAIN_10_NEXUS_FACTORY;
        vm.label(nexusFactoryAddressesMap[OP], "NexusFactoryOP");
        nexusFactoryAddressesMap[BASE] = CHAIN_8453_NEXUS_FACTORY;
        vm.label(nexusFactoryAddressesMap[BASE], "NexusFactoryBASE");

        /// @dev Setup existingUnderlyingTokens
        // Mainnet tokens
        existingUnderlyingTokens[ETH][DAI_KEY] = CHAIN_1_DAI;
        existingUnderlyingTokens[ETH][USDC_KEY] = CHAIN_1_USDC;
        existingUnderlyingTokens[ETH][WETH_KEY] = CHAIN_1_WETH;
        existingUnderlyingTokens[ETH][SUSDE_KEY] = CHAIN_1_SUSDE;
        existingUnderlyingTokens[ETH][USDE_KEY] = CHAIN_1_USDE;
        existingUnderlyingTokens[ETH][WST_ETH_KEY] = CHAIN_1_WST_ETH;
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
        existingVaults[ETH][STAKING_YIELD_SOURCE_ORACLE_KEY][GEARBOX_STAKING_KEY][GEAR_KEY] = CHAIN_1_GearboxStaking;
        vm.label(existingVaults[ETH][STAKING_YIELD_SOURCE_ORACLE_KEY][GEARBOX_STAKING_KEY][GEAR_KEY], "GearboxStaking");

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

        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);

            (validatorSigners[chainIds[i]], validatorSignerPrivateKeys[chainIds[i]]) = makeAddrAndKey("The signer");
            vm.label(validatorSigners[chainIds[i]], "The signer");
        }
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
            SuperRegistry(address(superRegistry)).setExecutor(
                keccak256(bytes(SUPER_EXECUTOR_ID)), _getContract(chainIds[i], SUPER_EXECUTOR_KEY)
            );
            SuperRegistry(address(superRegistry)).setExecutor(
                keccak256(bytes(ACROSS_TARGET_EXECUTOR_ID)), _getContract(chainIds[i], ACROSS_TARGET_EXECUTOR_KEY)
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
                yieldSourceOracleId: bytes4(bytes(STAKING_YIELD_SOURCE_ORACLE_KEY)),
                yieldSourceOracle: _getContract(chainIds[i], STAKING_YIELD_SOURCE_ORACLE_KEY),
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

    function _createSourceMerkleTree() internal { }

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
        ENOUGH_BALANCE,
        NO_HOOKS,
        LOW_LEVEL_FAILED
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
            emit IAcrossTargetExecutor.AcrossTargetExecutorReceivedButNotEnoughBalance(account);
        } else if (relayerType == RELAYER_TYPE.ENOUGH_BALANCE) {
            vm.expectEmit(true, true, true, true);
            emit IAcrossTargetExecutor.AcrossTargetExecutorExecuted(account);
        } else if (relayerType == RELAYER_TYPE.NO_HOOKS) {
            vm.expectEmit(true, true, true, true);
            emit IAcrossTargetExecutor.AcrossTargetExecutorReceivedButNoHooks();
        } else if (relayerType == RELAYER_TYPE.LOW_LEVEL_FAILED) {
            vm.expectEmit(true, false, false, false);
            emit IAcrossTargetExecutor.AcrossTargetExecutorFailedLowLevel("");
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
        console2.log("feeBalanceAfter", feeBalanceAfter);
        console2.log("expected fee", feeBalanceBefore + expectedFee);
        assertEq(feeBalanceAfter, feeBalanceBefore + expectedFee, "Fee derivation failed");
    }

    /*//////////////////////////////////////////////////////////////
                                 ACROSS TARGET EXECUTOR HELPERS
    //////////////////////////////////////////////////////////////*/
    struct TargetExecutorMessage {
        address[] hooksAddresses;
        bytes[] hooksData;
        address validator;
        address signer;
        uint256 signerPrivateKey;
        address targetExecutor;
        address nexusFactory;
        address nexusBootstrap;
        uint256 nonce;
        uint64 chainId;
        uint256 amount;
        address account;
        address tokenSent;
    }

    function _precomputeTargetExecutorAccount(
        address validator,
        address signer,
        address targetExecutor,
        address nexusFactory,
        address nexusBootstrap
    )
        internal
        returns (address)
    {
        (, address account) = _createAccountCreationData_AcrossTargetExecutor(
            validator, signer, targetExecutor, nexusFactory, nexusBootstrap
        );
        return account;
    }

    function _createTargetExecutorMessage(TargetExecutorMessage memory messageData)
        internal
        returns (bytes memory, address)
    {
        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory executionData =
            _createExecutionData_AcrossTargetExecutor(messageData.hooksAddresses, messageData.hooksData);

        address accountToUse;
        bytes memory accountCreationData;
        if (messageData.account == address(0)) {
            (accountCreationData, accountToUse) = _createAccountCreationData_AcrossTargetExecutor(
                messageData.validator,
                messageData.signer,
                messageData.targetExecutor,
                messageData.nexusFactory,
                messageData.nexusBootstrap
            );
            messageData.account = accountToUse; // prefill the account to use
        } else {
            accountToUse = messageData.account;
            accountCreationData = bytes("");
        }

        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = _createDestinationValidatorLeaf(
            executionData,
            messageData.chainId,
            accountToUse,
            messageData.nonce,
            messageData.targetExecutor,
            messageData.tokenSent,
            messageData.amount,
            validUntil
        );

        console2.log("---------- messageData.tokenSent", messageData.tokenSent);
        console2.log("---------- messageData.amount", messageData.amount);

        (bytes32[][] memory merkleProof, bytes32 merkleRoot) = _createValidatorMerkleTree(leaves);

        bytes memory signature = _createSignature(
            SuperValidatorBase(address(messageData.validator)).namespace(),
            merkleRoot,
            messageData.signer,
            messageData.signerPrivateKey
        );
        bytes memory signatureData =
            _createSignatureData_AcrossTargetExecutor(validUntil, merkleRoot, merkleProof[0], signature);

        return (
            abi.encode(accountCreationData, executionData, signatureData, messageData.account, messageData.amount),
            accountToUse
        );
    }

    function _createSignatureData_AcrossTargetExecutor(
        uint48 validUntil,
        bytes32 merkleRoot,
        bytes32[] memory merkleProof,
        bytes memory signature
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(validUntil, merkleRoot, merkleProof, signature);
    }

    function _createExecutionData_AcrossTargetExecutor(
        address[] memory hooksAddresses,
        bytes[] memory hooksData
    )
        internal
        pure
        returns (bytes memory)
    {
        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        console2.log(
            "length of execution ",
            (abi.encodeWithSelector(ISuperExecutor.execute.selector, abi.encode(entryToExecute))).length
        );
        return abi.encodeWithSelector(ISuperExecutor.execute.selector, abi.encode(entryToExecute));
    }

    function _createAccountCreationData_AcrossTargetExecutor(
        address validatorOnDestinationChain,
        address theSigner,
        address executorOnDestinationChain,
        address nexusFactory,
        address nexusBootstrap
    )
        internal
        returns (bytes memory, address)
    {
        // create validators
        BootstrapConfig[] memory validators = new BootstrapConfig[](1);
        validators[0] = BootstrapConfig({ module: validatorOnDestinationChain, data: abi.encode(theSigner) });
        // create executors
        BootstrapConfig[] memory executors = new BootstrapConfig[](1);
        executors[0] = BootstrapConfig({ module: address(executorOnDestinationChain), data: "" });
        // create hooks
        BootstrapConfig memory hook = BootstrapConfig({ module: address(0), data: "" });
        // create fallbacks
        BootstrapConfig[] memory fallbacks = new BootstrapConfig[](0);
        address[] memory attesters = new address[](1);
        attesters[0] = address(MANAGER);
        uint8 threshold = 1;
        MockRegistry nexusRegistry = new MockRegistry();
        bytes memory initData = INexusBootstrap(nexusBootstrap).getInitNexusCalldata(
            validators, executors, hook, fallbacks, IERC7484(nexusRegistry), attesters, threshold
        );
        bytes32 initSalt = bytes32(keccak256("SIGNER_SALT"));

        address precomputedAddress = INexusFactory(nexusFactory).computeAccountAddress(initData, initSalt);
        return (abi.encode(initData, initSalt), precomputedAddress);
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

    function _createApproveAndRedeem4626HookData(
        bytes4 yieldSourceOracleId,
        address vault,
        address token,
        address owner,
        uint256 amount,
        bool usePrevHookAmount,
        bool lockForSP
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(yieldSourceOracleId, vault, token, owner, amount, usePrevHookAmount, lockForSP);
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

    function _createApproveAndRedeem5115VaultHookData(
        bytes4 yieldSourceOracleId,
        address vault,
        address tokenIn,
        address tokenOut,
        uint256 shares,
        uint256 minTokenOut,
        bool burnFromInternalBalance,
        bool usePrevHookAmount,
        bool lockForSP
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(
            yieldSourceOracleId,
            vault,
            tokenIn,
            tokenOut,
            shares,
            minTokenOut,
            burnFromInternalBalance,
            usePrevHookAmount,
            lockForSP
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
        bytes memory data
    )
        internal
        view
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(
            uint256(0),
            _getContract(destinationChainId, ACROSS_TARGET_EXECUTOR_KEY),
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

    function _createApproveAndWithdraw7540VaultHookData(
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

    function _createApproveAndRedeem7540VaultHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        address token,
        uint256 shares,
        bool usePrevHookAmount,
        bool lockForSP
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, token, shares, usePrevHookAmount, lockForSP);
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
        bytes memory data,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory _calldata =
            abi.encodeWithSelector(I1InchAggregationRouterV6.swap.selector, IAggregationExecutor(executor), desc, data);

        return abi.encodePacked(dstToken, dstReceiver, uint256(0), usePrevHookAmount, _calldata);
    }

    function _create1InchUnoswapToHookData(
        address dstReceiver,
        address dstToken,
        Address receiverUint256,
        Address fromTokenUint256,
        uint256 decodedFromAmount,
        uint256 minReturn,
        Address dex,
        bool usePrevHookAmount
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

        return abi.encodePacked(dstToken, dstReceiver, uint256(0), usePrevHookAmount, _calldata);
    }

    function _create1InchClipperSwapToHookData(
        address dstReceiver,
        address dstToken,
        address exchange,
        Address srcToken,
        uint256 amount,
        bool usePrevHookAmount
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

        return abi.encodePacked(dstToken, dstReceiver, uint256(0), usePrevHookAmount, _calldata);
    }

    function _createOdosSwap(
        address inputToken,
        uint256 inputAmount,
        address inputReceiver,
        address outputToken,
        uint256 outputQuote,
        uint256 outputMin,
        address account
    )
        internal
        pure
        returns (IOdosRouterV2.swapTokenInfo memory)
    {
        return IOdosRouterV2.swapTokenInfo(
            inputToken, inputAmount, inputReceiver, outputToken, outputQuote, outputMin, account
        );
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
            usePrevHookAmount,
            pathDefinition.length,
            pathDefinition,
            executor,
            referralCode
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
        address yieldSource,
        address token,
        uint256 amount,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(bytes4(bytes("")), yieldSource, token, amount, usePrevHookAmount);
    }

    function _createCancelHookData(address yieldSource) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes4(bytes("")), yieldSource);
    }

    function _createClaimCancelHookData(address yieldSource, address receiver) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes4(bytes("")), yieldSource, receiver);
    }

    function _createMorphoBorrowHookData(
        address loanToken,
        address collateralToken,
        address oracle,
        address irm,
        uint256 amount,
        uint256 lltv,
        bool usePrevHookAmount,
        bool isPositiveFeed
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            loanToken, collateralToken, oracle, irm, amount, lltv, usePrevHookAmount, isPositiveFeed, false
        );
    }

    function _createMorphoRepayHookData(
        address loanToken,
        address collateralToken,
        address oracle,
        address irm,
        uint256 amount,
        uint256 lltv,
        bool usePrevHookAmount,
        bool isFullRepayment,
        bool isPositiveFeed
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            loanToken, collateralToken, oracle, irm, amount, lltv, usePrevHookAmount, isFullRepayment, isPositiveFeed
        );
    }

    function _createMorphoRepayAndWithdrawHookData(
        address loanToken,
        address collateralToken,
        address oracle,
        address irm,
        uint256 amount,
        uint256 lltv,
        bool usePrevHookAmount,
        bool isFullRepayment,
        bool isPositiveFeed
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            loanToken, collateralToken, oracle, irm, amount, lltv, usePrevHookAmount, isFullRepayment, isPositiveFeed
        );
    }

    function _createSpectraExchangeSwapHookData(
        bool usePrevHookAmount,
        uint256 value,
        address ptToken,
        address tokenIn,
        uint256 amount,
        address account
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory txData = _createSpectraExchangeSimpleCommandTxData(ptToken, tokenIn, amount, account);
        return abi.encodePacked(usePrevHookAmount, value, txData);
    }

    function _createSpectraExchangeSimpleCommandTxData(
        address ptToken_,
        address tokenIn_,
        uint256 amount_,
        address account_
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory commandsData = new bytes(2);
        commandsData[0] = bytes1(uint8(SpectraCommands.TRANSFER_FROM));
        commandsData[1] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));

        /// https://dev.spectra.finance/technical-reference/contract-functions/router#deposit_asset_in_pt-command
        // ptToken
        // amount
        // ptRecipient
        // ytRecipient
        // minShares
        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(tokenIn_, amount_);
        inputs[1] = abi.encode(ptToken_, amount_, account_, account_, 1);

        return abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);
    }

    function _createPendleRouterSwapHookDataWithOdos(
        address market,
        address account,
        bool usePrevHookAmount,
        uint256 value,
        bool ptToToken,
        uint256 amount,
        address tokenIn,
        address tokenMint,
        uint64 chainId
    )
        internal
        returns (bytes memory)
    {
        bytes memory pendleTxData;
        if (!ptToToken) {
            // call Odos swapAPI to get the calldata
            // note, odos swap receiver has to be pendle router
            bytes memory odosCalldata =
                _createOdosSwapCalldataRequest(tokenIn, tokenMint, amount, PENDLE_ROUTERS[chainId]);

            decodeOdosSwapCalldata(odosCalldata);

            pendleTxData = _createTokenToPtPendleTxDataWithOdos(
                market, account, tokenIn, 1, amount, tokenMint, odosCalldata, chainId
            );
        } else {
            //TODO: fill with the other
            revert("Not implemented");
        }
        return abi.encodePacked(usePrevHookAmount, value, pendleTxData);
    }

    function _createOdosSwapCalldataRequest(
        address _tokenIn,
        address _tokenOut,
        uint256 _amount,
        address _receiver
    )
        internal
        returns (bytes memory)
    {
        // get pathId
        QuoteInputToken[] memory inputTokens = new QuoteInputToken[](1);
        inputTokens[0] = QuoteInputToken({ tokenAddress: _tokenIn, amount: _amount });
        QuoteOutputToken[] memory outputTokens = new QuoteOutputToken[](1);
        outputTokens[0] = QuoteOutputToken({ tokenAddress: _tokenOut, proportion: 1 });
        string memory pathId = surlCallQuoteV2(inputTokens, outputTokens, _receiver, ETH, true);

        // get assemble data
        string memory swapCompactData = surlCallAssemble(pathId, _receiver);
        return fromHex(swapCompactData);
    }

    function _createTokenToPtPendleTxDataWithOdos(
        address _market,
        address _receiver,
        address _tokenIn,
        uint256 _minPtOut,
        uint256 _amount,
        address _tokenMintSY,
        bytes memory _odosCalldata,
        uint64 chainId
    )
        internal
        view
        returns (bytes memory pendleTxData)
    {
        // no limit order needed
        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(0),
            epsSkipMarket: 0,
            normalFills: new FillOrderParams[](0),
            flashFills: new FillOrderParams[](0),
            optData: "0x"
        });

        // TokenInput
        TokenInput memory input = TokenInput({
            tokenIn: _tokenIn,
            netTokenIn: _amount,
            tokenMintSy: _tokenMintSY, //CHAIN_1_cUSDO,
            pendleSwap: PENDLE_SWAP[chainId],
            swapData: SwapData({
                extRouter: ODOS_ROUTER[chainId],
                extCalldata: _odosCalldata,
                needScale: false,
                swapType: SwapType.ODOS
            })
        });
        /*
        The guessMax and guessOffchain are being set based on the initial USDC _amount (1e6). However, these guesses are
        used for the internal Pendle swap which involves SY and PT tokens, likely with 18 decimals and completely
        different magnitudes. A guessMax of 2e6 wei for an 18-decimal token is extremely small and likely far below the
        actual expected PT output amount. The true value falls outside the provided [guessMin, guessMax] range, causing
        the approximation to fail.
        We need to provide more realistic bounds for the expected PT output. Since 1 USDC is roughly $1 and the PT is
        likely near par, a reasonable very rough guess for the PT amount (18 decimals) might be around 1e18. Let's widen
        the approximation bounds significantly.*/
        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 1,
            guessMax: 1e24,
            guessOffchain: 1e18,
            maxIteration: 30,
            eps: 10_000_000_000_000
        });

        pendleTxData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactTokenForPt.selector, _receiver, _market, _minPtOut, guessPtOut, input, limit
        );
    }

    function _createApproveAndSwapOdosHookData(
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
        returns (bytes memory)
    {
        return abi.encodePacked(
            inputToken,
            inputAmount,
            inputReceiver,
            outputToken,
            outputQuote,
            outputMin,
            usePrevHookAmount,
            pathDefinition.length,
            pathDefinition,
            executor,
            referralCode
        );
    }
}
