// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Helpers } from "./utils/Helpers.sol";
import { Clones } from "openzeppelin-contracts/contracts/proxy/Clones.sol";

import { InternalHelpers } from "./utils/InternalHelpers.sol";
import { SignatureHelper } from "./utils/SignatureHelper.sol";
import { MerkleTreeHelper } from "./utils/MerkleTreeHelper.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
// Superform interfaces
import { ISuperRegistry } from "../src/core/interfaces/ISuperRegistry.sol";
import { ISuperExecutor } from "../src/core/interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../src/core/interfaces/accounting/ISuperLedger.sol";
import { ISuperLedgerConfiguration } from "../src/core/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperDestinationExecutor } from "../src/core/interfaces/ISuperDestinationExecutor.sol";

// Superform contracts coded
import { SuperLedger } from "../src/core/accounting/SuperLedger.sol";
import { ERC5115Ledger } from "../src/core/accounting/ERC5115Ledger.sol";
import { SuperLedgerConfiguration } from "../src/core/accounting/SuperLedgerConfiguration.sol";
import { SuperExecutor } from "../src/core/executors/SuperExecutor.sol";
import { SuperDestinationExecutor } from "../src/core/executors/SuperDestinationExecutor.sol";
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
import { DeBridgeSendOrderAndExecuteOnDstHook } from
    "../src/core/hooks/bridges/debridge/DeBridgeSendOrderAndExecuteOnDstHook.sol";

// Swap hooks
// --- 1inch
import { Swap1InchHook } from "../src/core/hooks/swappers/1inch/Swap1InchHook.sol";

// --- Odos
import { OdosAPIParser } from "./utils/parsers/OdosAPIParser.sol";
import { IOdosRouterV2 } from "../src/vendor/odos/IOdosRouterV2.sol";
import { SwapOdosHook } from "../src/core/hooks/swappers/odos/SwapOdosHook.sol";
import { MockApproveAndSwapOdosHook } from "../test/mocks/unused-hooks/MockApproveAndSwapOdosHook.sol";
import { ApproveAndSwapOdosHook } from "../src/core/hooks/swappers/odos/ApproveAndSwapOdosHook.sol";
import { MockSwapOdosHook } from "../test/mocks/unused-hooks/MockSwapOdosHook.sol";

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

// --- Ethena
import { EthenaCooldownSharesHook } from "../src/core/hooks/vaults/ethena/EthenaCooldownSharesHook.sol";
import { EthenaUnstakeHook } from "../src/core/hooks/vaults/ethena/EthenaUnstakeHook.sol";
import { SpectraExchangeHook } from "../src/core/hooks/swappers/spectra/SpectraExchangeHook.sol";
import { PendleRouterSwapHook } from "../src/core/hooks/swappers/pendle/PendleRouterSwapHook.sol";
import { PendleRouterRedeemHook } from "../src/core/hooks/swappers/pendle/PendleRouterRedeemHook.sol";

// --- Onramp
import { BatchTransferFromHook } from "../src/core/hooks/tokens/permit2/BatchTransferFromHook.sol";

// action oracles
import { ERC4626YieldSourceOracle } from "../src/core/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { ERC5115YieldSourceOracle } from "../src/core/accounting/oracles/ERC5115YieldSourceOracle.sol";
import { SuperOracle } from "../src/periphery/oracles/SuperOracle.sol";
import { ERC7540YieldSourceOracle } from "../src/core/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { StakingYieldSourceOracle } from "../src/core/accounting/oracles/StakingYieldSourceOracle.sol";

// external
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";

import { ExecutionReturnData } from "modulekit/test/RhinestoneModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/kernel/types/Constants.sol";

import { AcrossV3Helper } from "pigeon/across/AcrossV3Helper.sol";
import { DebridgeHelper } from "pigeon/debridge/DebridgeHelper.sol";
import { DebridgeDlnHelper } from "pigeon/debridge/DebridgeDlnHelper.sol";
import { MockOdosRouterV2 } from "./mocks/MockOdosRouterV2.sol";
import { AcrossV3Adapter } from "../src/core/adapters/AcrossV3Adapter.sol";
import { DebridgeAdapter } from "../src/core/adapters/DebridgeAdapter.sol";
import { SuperGovernor } from "../src/periphery/SuperGovernor.sol";
import { SuperBank } from "../src/periphery/SuperBank.sol";

// SuperformNativePaymaster
import { SuperNativePaymaster } from "../src/core/paymaster/SuperNativePaymaster.sol";

// Nexus and Rhinestone overrides to allow for SuperformNativePaymaster
import { IAccountFactory } from "modulekit/accounts/factory/interface/IAccountFactory.sol";
import { getFactory, getHelper, getStorageCompliance } from "modulekit/test/utils/Storage.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";

import { BootstrapConfig, INexusBootstrap } from "../src/vendor/nexus/INexusBootstrap.sol";
import { INexusFactory } from "../src/vendor/nexus/INexusFactory.sol";
import { IERC7484 } from "../src/vendor/nexus/IERC7484.sol";
import { MockRegistry } from "./mocks/MockRegistry.sol";

import { SuperVaultAggregator } from "../src/periphery/SuperVault/SuperVaultAggregator.sol";
import { SuperVault } from "../src/periphery/SuperVault/SuperVault.sol";
import { SuperVaultStrategy } from "../src/periphery/SuperVault/SuperVaultStrategy.sol";
import { SuperVaultEscrow } from "../src/periphery/SuperVault/SuperVaultEscrow.sol";
import { ECDSAPPSOracle } from "../src/periphery/oracles/ECDSAPPSOracle.sol";

import { BaseHook } from "../src/core/hooks/BaseHook.sol";
import { MockSuperExecutor } from "./mocks/MockSuperExecutor.sol";
import { MockLockVault } from "./mocks/MockLockVault.sol";
import { MockTargetExecutor } from "./mocks/MockTargetExecutor.sol";
import { MockBaseHook } from "./mocks/MockBaseHook.sol";

import { DlnExternalCallLib } from "../lib/pigeon/src/debridge/libraries/DlnExternalCallLib.sol";

import "forge-std/console2.sol";

struct Addresses {
    ISuperLedger superLedger;
    ISuperLedger erc1155Ledger;
    ISuperLedgerConfiguration superLedgerConfiguration;
    ISuperRegistry superRegistry;
    ISuperExecutor superExecutor;
    ISuperExecutor superDestinationExecutor;
    AcrossV3Adapter acrossV3Adapter;
    DebridgeAdapter debridgeAdapter;
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
    CancelRedeemHook cancelRedeemHook;
    AcrossSendFundsAndExecuteOnDstHook acrossSendFundsAndExecuteOnDstHook;
    DeBridgeSendOrderAndExecuteOnDstHook deBridgeSendOrderAndExecuteOnDstHook;
    Swap1InchHook swap1InchHook;
    SwapOdosHook swapOdosHook;
    MockSwapOdosHook mockSwapOdosHook;
    MockApproveAndSwapOdosHook mockApproveAndSwapOdosHook;
    GearboxStakeHook gearboxStakeHook;
    GearboxUnstakeHook gearboxUnstakeHook;
    ApproveAndGearboxStakeHook approveAndGearboxStakeHook;
    FluidStakeHook fluidStakeHook;
    FluidUnstakeHook fluidUnstakeHook;
    SpectraExchangeHook spectraExchangeHook;
    PendleRouterSwapHook pendleRouterSwapHook;
    PendleRouterRedeemHook pendleRouterRedeemHook;
    FluidClaimRewardHook fluidClaimRewardHook;
    GearboxClaimRewardHook gearboxClaimRewardHook;
    YearnClaimOneRewardHook yearnClaimOneRewardHook;
    EthenaCooldownSharesHook ethenaCooldownSharesHook;
    EthenaUnstakeHook ethenaUnstakeHook;
    BatchTransferFromHook batchTransferFromHook;
    ERC4626YieldSourceOracle erc4626YieldSourceOracle;
    ERC5115YieldSourceOracle erc5115YieldSourceOracle;
    ERC7540YieldSourceOracle erc7540YieldSourceOracle;
    StakingYieldSourceOracle stakingYieldSourceOracle;
    SuperOracle oracleRegistry;
    SuperMerkleValidator superMerkleValidator;
    SuperDestinationValidator superDestinationValidator;
    SuperGovernor superGovernor;
    SuperNativePaymaster superNativePaymaster;
    SuperVaultAggregator superVaultAggregator;
    ECDSAPPSOracle ecdsappsOracle;
    ISuperExecutor superExecutorWithSPLock;
    MockTargetExecutor mockTargetExecutor;
    SuperBank superBank;
}

contract BaseTest is Helpers, RhinestoneModuleKit, SignatureHelper, MerkleTreeHelper, OdosAPIParser, InternalHelpers {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;
    using Clones for address;

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

    mapping(uint64 chainId => address) public SPOKE_POOL_V3_ADDRESSES;
    mapping(uint64 chainId => address) public DEBRIDGE_DLN_ADDRESSES;
    mapping(uint64 chainId => address) public DEBRIDGE_DLN_ADDRESSES_DST;
    mapping(uint64 chainId => address) public NEXUS_FACTORY_ADDRESSES;
    mapping(uint64 chainId => address) public POLYMER_PROVER;

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
    mapping(uint64 chainId => address spectraRouter) public SPECTRA_ROUTERS;
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
    bool public useRealOdosRouter = false;
    address[] public globalMerkleHooks;
    string[] public globalMerkleHookNames;
    address public globalSVStrategy;
    address public globalSVGearStrategy;
    address public globalRuggableVault;

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
        VALIDATOR = _deployAccount(VALIDATOR_KEY, "VALIDATOR");

        // Setup forks
        _preDeploymentSetup();

        Addresses[] memory A = new Addresses[](chainIds.length);
        // Deploy contracts
        A = _deployContracts(A);

        // Deploy hooks
        A = _deployHooks(A);

        _configureGovernor();

        _registerHooks(A);

        // Initialize accounts
        _initializeAccounts(ACCOUNT_COUNT);

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

    function _setUseRealOdosRouter(bool useRealOdosRouter_) internal {
        useRealOdosRouter = useRealOdosRouter_;
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

            address debridgeDlnHelper = address(new DebridgeDlnHelper());
            vm.allowCheatcodes(debridgeDlnHelper);
            vm.makePersistent(debridgeDlnHelper);
            contractAddresses[chainIds[i]][DEBRIDGE_DLN_HELPER_KEY] = debridgeDlnHelper;

            A[i].superGovernor = new SuperGovernor{ salt: SALT }(
                address(this), address(this), address(this), TREASURY, CHAIN_1_POLYMER_PROVER
            );
            vm.label(address(A[i].superGovernor), SUPER_GOVERNOR_KEY);
            contractAddresses[chainIds[i]][SUPER_GOVERNOR_KEY] = address(A[i].superGovernor);

            A[i].superBank = new SuperBank{ salt: SALT }(address(A[i].superGovernor));
            vm.label(address(A[i].superBank), SUPER_BANK_KEY);
            contractAddresses[chainIds[i]][SUPER_BANK_KEY] = address(A[i].superBank);

            TREASURY = address(A[i].superBank);

            A[i].oracleRegistry = new SuperOracle{ salt: SALT }(
                address(this), new address[](0), new address[](0), new bytes32[](0), new address[](0)
            );
            vm.label(address(A[i].oracleRegistry), SUPER_ORACLE_KEY);
            contractAddresses[chainIds[i]][SUPER_ORACLE_KEY] = address(A[i].oracleRegistry);

            A[i].superLedgerConfiguration =
                ISuperLedgerConfiguration(address(new SuperLedgerConfiguration{ salt: SALT }()));
            vm.label(address(A[i].superLedgerConfiguration), SUPER_LEDGER_CONFIGURATION_KEY);
            contractAddresses[chainIds[i]][SUPER_LEDGER_CONFIGURATION_KEY] = address(A[i].superLedgerConfiguration);

            A[i].superNativePaymaster = new SuperNativePaymaster{ salt: SALT }(IEntryPoint(ENTRYPOINT_ADDR));
            vm.label(address(A[i].superNativePaymaster), SUPER_NATIVE_PAYMASTER_KEY);
            contractAddresses[chainIds[i]][SUPER_NATIVE_PAYMASTER_KEY] = address(A[i].superNativePaymaster);

            A[i].superMerkleValidator = new SuperMerkleValidator();
            vm.label(address(A[i].superMerkleValidator), SUPER_MERKLE_VALIDATOR_KEY);
            contractAddresses[chainIds[i]][SUPER_MERKLE_VALIDATOR_KEY] = address(A[i].superMerkleValidator);

            A[i].superDestinationValidator = new SuperDestinationValidator{ salt: SALT }();
            vm.label(address(A[i].superDestinationValidator), SUPER_DESTINATION_VALIDATOR_KEY);
            contractAddresses[chainIds[i]][SUPER_DESTINATION_VALIDATOR_KEY] = address(A[i].superDestinationValidator);

            A[i].superExecutor =
                ISuperExecutor(address(new SuperExecutor{ salt: SALT }(address(A[i].superLedgerConfiguration))));
            vm.label(address(A[i].superExecutor), SUPER_EXECUTOR_KEY);
            contractAddresses[chainIds[i]][SUPER_EXECUTOR_KEY] = address(A[i].superExecutor);

            MockLockVault lockVault = new MockLockVault();
            vm.label(address(lockVault), "MockLockVault");
            A[i].superExecutorWithSPLock = ISuperExecutor(
                address(new MockSuperExecutor{ salt: SALT }(address(A[i].superLedgerConfiguration), address(lockVault)))
            );
            vm.label(address(A[i].superExecutorWithSPLock), SUPER_EXECUTOR_WITH_SP_LOCK_KEY);
            contractAddresses[chainIds[i]][SUPER_EXECUTOR_WITH_SP_LOCK_KEY] = address(A[i].superExecutorWithSPLock);

            A[i].mockTargetExecutor =
                new MockTargetExecutor{ salt: SALT }(address(A[i].superLedgerConfiguration), address(lockVault));
            vm.label(address(A[i].mockTargetExecutor), MOCK_TARGET_EXECUTOR_KEY);
            contractAddresses[chainIds[i]][MOCK_TARGET_EXECUTOR_KEY] = address(A[i].mockTargetExecutor);

            A[i].superDestinationExecutor = ISuperExecutor(
                address(
                    new SuperDestinationExecutor{ salt: SALT }(
                        address(A[i].superLedgerConfiguration),
                        address(A[i].superDestinationValidator),
                        NEXUS_FACTORY_ADDRESSES[chainIds[i]]
                    )
                )
            );
            vm.label(address(A[i].superDestinationExecutor), SUPER_DESTINATION_EXECUTOR_KEY);
            contractAddresses[chainIds[i]][SUPER_DESTINATION_EXECUTOR_KEY] = address(A[i].superDestinationExecutor);

            A[i].acrossV3Adapter = new AcrossV3Adapter{ salt: SALT }(
                SPOKE_POOL_V3_ADDRESSES[chainIds[i]], address(A[i].superDestinationExecutor)
            );
            vm.label(address(A[i].acrossV3Adapter), ACROSS_V3_ADAPTER_KEY);
            contractAddresses[chainIds[i]][ACROSS_V3_ADAPTER_KEY] = address(A[i].acrossV3Adapter);

            A[i].debridgeAdapter =
                new DebridgeAdapter{ salt: SALT }(DEBRIDGE_DLN_DST, address(A[i].superDestinationExecutor));
            vm.label(address(A[i].debridgeAdapter), DEBRIDGE_ADAPTER_KEY);
            contractAddresses[chainIds[i]][DEBRIDGE_ADAPTER_KEY] = address(A[i].debridgeAdapter);

            address[] memory allowedExecutors = new address[](3);
            allowedExecutors[0] = address(A[i].superExecutor);
            allowedExecutors[1] = address(A[i].superDestinationExecutor);
            allowedExecutors[2] = address(A[i].superExecutorWithSPLock);

            A[i].superLedger = ISuperLedger(
                address(new SuperLedger{ salt: SALT }(address(A[i].superLedgerConfiguration), allowedExecutors))
            );
            vm.label(address(A[i].superLedger), SUPER_LEDGER_KEY);
            contractAddresses[chainIds[i]][SUPER_LEDGER_KEY] = address(A[i].superLedger);

            A[i].erc1155Ledger = ISuperLedger(
                address(new ERC5115Ledger{ salt: SALT }(address(A[i].superLedgerConfiguration), allowedExecutors))
            );
            vm.label(address(A[i].erc1155Ledger), ERC1155_LEDGER_KEY);
            contractAddresses[chainIds[i]][ERC1155_LEDGER_KEY] = address(A[i].erc1155Ledger);

            /// @dev action oracles
            A[i].erc4626YieldSourceOracle = new ERC4626YieldSourceOracle();
            vm.label(address(A[i].erc4626YieldSourceOracle), ERC4626_YIELD_SOURCE_ORACLE_KEY);
            contractAddresses[chainIds[i]][ERC4626_YIELD_SOURCE_ORACLE_KEY] = address(A[i].erc4626YieldSourceOracle);

            A[i].erc5115YieldSourceOracle = new ERC5115YieldSourceOracle();
            vm.label(address(A[i].erc5115YieldSourceOracle), ERC5115_YIELD_SOURCE_ORACLE_KEY);
            contractAddresses[chainIds[i]][ERC5115_YIELD_SOURCE_ORACLE_KEY] = address(A[i].erc5115YieldSourceOracle);

            A[i].erc7540YieldSourceOracle = new ERC7540YieldSourceOracle();
            vm.label(address(A[i].erc7540YieldSourceOracle), ERC7540_YIELD_SOURCE_ORACLE_KEY);
            contractAddresses[chainIds[i]][ERC7540_YIELD_SOURCE_ORACLE_KEY] = address(A[i].erc7540YieldSourceOracle);

            A[i].stakingYieldSourceOracle = new StakingYieldSourceOracle();
            vm.label(address(A[i].stakingYieldSourceOracle), STAKING_YIELD_SOURCE_ORACLE_KEY);
            contractAddresses[chainIds[i]][STAKING_YIELD_SOURCE_ORACLE_KEY] = address(A[i].stakingYieldSourceOracle);

            A[i].ecdsappsOracle = new ECDSAPPSOracle(address(A[i].superGovernor));
            vm.label(address(A[i].ecdsappsOracle), ECDSAPPS_ORACLE_KEY);
            contractAddresses[chainIds[i]][ECDSAPPS_ORACLE_KEY] = address(A[i].ecdsappsOracle);

            // Deploy implementation contracts first
            address vaultImpl = address(new SuperVault());
            address strategyImpl = address(new SuperVaultStrategy());
            address escrowImpl = address(new SuperVaultEscrow());

            A[i].superVaultAggregator =
                new SuperVaultAggregator(address(A[i].superGovernor), vaultImpl, strategyImpl, escrowImpl);
            vm.label(address(A[i].superVaultAggregator), SUPER_VAULT_AGGREGATOR_KEY);
            contractAddresses[chainIds[i]][SUPER_VAULT_AGGREGATOR_KEY] = address(A[i].superVaultAggregator);

            A[i].superGovernor.setActivePPSOracle(address(A[i].ecdsappsOracle));
            A[i].superGovernor.addValidator(VALIDATOR);
        }
        return A;
    }

    function _deployHooks(Addresses[] memory A) internal returns (Addresses[] memory) {
        if (DEBUG) console2.log("---------------- DEPLOYING HOOKS ----------------");
        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);

            address[] memory hooksAddresses = new address[](47);

            A[i].approveErc20Hook = new ApproveERC20Hook{ salt: SALT }();
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

            A[i].transferErc20Hook = new TransferERC20Hook{ salt: SALT }();
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

            A[i].deposit4626VaultHook = new Deposit4626VaultHook{ salt: SALT }();
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

            A[i].approveAndDeposit4626VaultHook = new ApproveAndDeposit4626VaultHook{ salt: SALT }();
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

            A[i].redeem4626VaultHook = new Redeem4626VaultHook{ salt: SALT }();
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

            A[i].approveAndRedeem4626VaultHook = new ApproveAndRedeem4626VaultHook{ salt: SALT }();
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

            A[i].deposit5115VaultHook = new Deposit5115VaultHook{ salt: SALT }();
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

            A[i].approveAndDeposit5115VaultHook = new ApproveAndDeposit5115VaultHook{ salt: SALT }();
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

            A[i].redeem5115VaultHook = new Redeem5115VaultHook{ salt: SALT }();
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

            A[i].approveAndRedeem5115VaultHook = new ApproveAndRedeem5115VaultHook{ salt: SALT }();
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

            A[i].requestDeposit7540VaultHook = new RequestDeposit7540VaultHook{ salt: SALT }();
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

            A[i].approveAndRequestDeposit7540VaultHook = new ApproveAndRequestDeposit7540VaultHook{ salt: SALT }();
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

            A[i].requestRedeem7540VaultHook = new RequestRedeem7540VaultHook{ salt: SALT }();
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

            A[i].deposit7540VaultHook = new Deposit7540VaultHook{ salt: SALT }();
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

            A[i].withdraw7540VaultHook = new Withdraw7540VaultHook{ salt: SALT }();
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
            A[i].approveAndWithdraw7540VaultHook = new ApproveAndWithdraw7540VaultHook{ salt: SALT }();
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

            A[i].approveAndRedeem7540VaultHook = new ApproveAndRedeem7540VaultHook{ salt: SALT }();
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

            A[i].swap1InchHook = new Swap1InchHook{ salt: SALT }(ONE_INCH_ROUTER);
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

            A[i].mockApproveAndSwapOdosHook = new MockApproveAndSwapOdosHook{ salt: SALT }(address(odosRouter));
            vm.label(address(A[i].mockApproveAndSwapOdosHook), MOCK_APPROVE_AND_SWAP_ODOS_HOOK_KEY);
            hookAddresses[chainIds[i]][MOCK_APPROVE_AND_SWAP_ODOS_HOOK_KEY] = address(A[i].mockApproveAndSwapOdosHook);
            hooks[chainIds[i]][MOCK_APPROVE_AND_SWAP_ODOS_HOOK_KEY] = Hook(
                MOCK_APPROVE_AND_SWAP_ODOS_HOOK_KEY,
                HookCategory.Swaps,
                HookCategory.TokenApprovals,
                address(A[i].mockApproveAndSwapOdosHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Swaps].push(
                hooks[chainIds[i]][MOCK_APPROVE_AND_SWAP_ODOS_HOOK_KEY]
            );
            hooksAddresses[18] = address(A[i].mockApproveAndSwapOdosHook);

            A[i].mockSwapOdosHook = new MockSwapOdosHook{ salt: SALT }(address(odosRouter));
            vm.label(address(A[i].mockSwapOdosHook), MOCK_SWAP_ODOS_HOOK_KEY);
            hookAddresses[chainIds[i]][MOCK_SWAP_ODOS_HOOK_KEY] = address(A[i].mockSwapOdosHook);
            hooks[chainIds[i]][MOCK_SWAP_ODOS_HOOK_KEY] = Hook(
                MOCK_SWAP_ODOS_HOOK_KEY,
                HookCategory.Swaps,
                HookCategory.TokenApprovals,
                address(A[i].mockSwapOdosHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Swaps].push(hooks[chainIds[i]][MOCK_SWAP_ODOS_HOOK_KEY]);
            hooksAddresses[19] = address(A[i].mockSwapOdosHook);

            A[i].approveAndSwapOdosHook = new ApproveAndSwapOdosHook{ salt: SALT }(ODOS_ROUTER[chainIds[i]]);
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
            hooksAddresses[20] = address(A[i].approveAndSwapOdosHook);

            A[i].swapOdosHook = new SwapOdosHook{ salt: SALT }(ODOS_ROUTER[chainIds[i]]);
            vm.label(address(A[i].swapOdosHook), SWAP_ODOS_HOOK_KEY);
            hookAddresses[chainIds[i]][SWAP_ODOS_HOOK_KEY] = address(A[i].swapOdosHook);
            hooks[chainIds[i]][SWAP_ODOS_HOOK_KEY] = Hook(
                SWAP_ODOS_HOOK_KEY, HookCategory.Swaps, HookCategory.TokenApprovals, address(A[i].swapOdosHook), ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Swaps].push(hooks[chainIds[i]][SWAP_ODOS_HOOK_KEY]);
            hooksAddresses[21] = address(A[i].swapOdosHook);

            A[i].acrossSendFundsAndExecuteOnDstHook = new AcrossSendFundsAndExecuteOnDstHook{ salt: SALT }(
                SPOKE_POOL_V3_ADDRESSES[chainIds[i]], _getContract(chainIds[i], SUPER_MERKLE_VALIDATOR_KEY)
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
            hooksAddresses[22] = address(A[i].acrossSendFundsAndExecuteOnDstHook);

            A[i].deBridgeSendOrderAndExecuteOnDstHook = new DeBridgeSendOrderAndExecuteOnDstHook{ salt: SALT }(
                DEBRIDGE_DLN_ADDRESSES[chainIds[i]], _getContract(chainIds[i], SUPER_MERKLE_VALIDATOR_KEY)
            );
            vm.label(
                address(A[i].deBridgeSendOrderAndExecuteOnDstHook), DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY
            );
            hookAddresses[chainIds[i]][DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY] =
                address(A[i].deBridgeSendOrderAndExecuteOnDstHook);
            hooks[chainIds[i]][DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY] = Hook(
                DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY,
                HookCategory.Bridges,
                HookCategory.TokenApprovals,
                address(A[i].deBridgeSendOrderAndExecuteOnDstHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Bridges].push(
                hooks[chainIds[i]][DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY]
            );
            hooksAddresses[23] = address(A[i].deBridgeSendOrderAndExecuteOnDstHook);

            A[i].fluidClaimRewardHook = new FluidClaimRewardHook{ salt: SALT }();
            vm.label(address(A[i].fluidClaimRewardHook), FLUID_CLAIM_REWARD_HOOK_KEY);
            hookAddresses[chainIds[i]][FLUID_CLAIM_REWARD_HOOK_KEY] = address(A[i].fluidClaimRewardHook);
            hooks[chainIds[i]][FLUID_CLAIM_REWARD_HOOK_KEY] = Hook(
                FLUID_CLAIM_REWARD_HOOK_KEY,
                HookCategory.Claims,
                HookCategory.None,
                address(A[i].fluidClaimRewardHook),
                ""
            );
            hooksAddresses[24] = address(A[i].fluidClaimRewardHook);

            A[i].fluidStakeHook = new FluidStakeHook{ salt: SALT }();
            vm.label(address(A[i].fluidStakeHook), FLUID_STAKE_HOOK_KEY);
            hookAddresses[chainIds[i]][FLUID_STAKE_HOOK_KEY] = address(A[i].fluidStakeHook);
            hooks[chainIds[i]][FLUID_STAKE_HOOK_KEY] =
                Hook(FLUID_STAKE_HOOK_KEY, HookCategory.Stakes, HookCategory.None, address(A[i].fluidStakeHook), "");
            hooksAddresses[25] = address(A[i].fluidStakeHook);

            A[i].approveAndFluidStakeHook = new ApproveAndFluidStakeHook{ salt: SALT }();
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
            hooksAddresses[26] = address(A[i].approveAndFluidStakeHook);

            A[i].fluidUnstakeHook = new FluidUnstakeHook{ salt: SALT }();
            vm.label(address(A[i].fluidUnstakeHook), FLUID_UNSTAKE_HOOK_KEY);
            hookAddresses[chainIds[i]][FLUID_UNSTAKE_HOOK_KEY] = address(A[i].fluidUnstakeHook);
            hooks[chainIds[i]][FLUID_UNSTAKE_HOOK_KEY] =
                Hook(FLUID_UNSTAKE_HOOK_KEY, HookCategory.Stakes, HookCategory.None, address(A[i].fluidUnstakeHook), "");
            hooksAddresses[27] = address(A[i].fluidUnstakeHook);

            A[i].gearboxClaimRewardHook = new GearboxClaimRewardHook{ salt: SALT }();
            vm.label(address(A[i].gearboxClaimRewardHook), GEARBOX_CLAIM_REWARD_HOOK_KEY);
            hookAddresses[chainIds[i]][GEARBOX_CLAIM_REWARD_HOOK_KEY] = address(A[i].gearboxClaimRewardHook);
            hooks[chainIds[i]][GEARBOX_CLAIM_REWARD_HOOK_KEY] = Hook(
                GEARBOX_CLAIM_REWARD_HOOK_KEY,
                HookCategory.Claims,
                HookCategory.None,
                address(A[i].gearboxClaimRewardHook),
                ""
            );
            hooksAddresses[28] = address(A[i].gearboxClaimRewardHook);

            A[i].gearboxStakeHook = new GearboxStakeHook{ salt: SALT }();
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
            hooksAddresses[29] = address(A[i].gearboxStakeHook);

            A[i].approveAndGearboxStakeHook = new ApproveAndGearboxStakeHook{ salt: SALT }();
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
            hooksAddresses[30] = address(A[i].approveAndGearboxStakeHook);

            A[i].gearboxUnstakeHook = new GearboxUnstakeHook{ salt: SALT }();
            vm.label(address(A[i].gearboxUnstakeHook), GEARBOX_UNSTAKE_HOOK_KEY);
            hookAddresses[chainIds[i]][GEARBOX_UNSTAKE_HOOK_KEY] = address(A[i].gearboxUnstakeHook);
            hooks[chainIds[i]][GEARBOX_UNSTAKE_HOOK_KEY] = Hook(
                GEARBOX_UNSTAKE_HOOK_KEY, HookCategory.Claims, HookCategory.Stakes, address(A[i].gearboxUnstakeHook), ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Claims].push(hooks[chainIds[i]][GEARBOX_UNSTAKE_HOOK_KEY]);
            hooksAddresses[31] = address(A[i].gearboxUnstakeHook);

            A[i].yearnClaimOneRewardHook = new YearnClaimOneRewardHook{ salt: SALT }();
            vm.label(address(A[i].yearnClaimOneRewardHook), YEARN_CLAIM_ONE_REWARD_HOOK_KEY);
            hooks[chainIds[i]][YEARN_CLAIM_ONE_REWARD_HOOK_KEY] = Hook(
                YEARN_CLAIM_ONE_REWARD_HOOK_KEY,
                HookCategory.Claims,
                HookCategory.Stakes,
                address(A[i].yearnClaimOneRewardHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Claims].push(hooks[chainIds[i]][YEARN_CLAIM_ONE_REWARD_HOOK_KEY]);
            hooksAddresses[32] = address(A[i].yearnClaimOneRewardHook);

            A[i].batchTransferFromHook = new BatchTransferFromHook{ salt: SALT }(PERMIT2);
            vm.label(address(A[i].batchTransferFromHook), BATCH_TRANSFER_FROM_HOOK_KEY);
            hookAddresses[chainIds[i]][BATCH_TRANSFER_FROM_HOOK_KEY] = address(A[i].batchTransferFromHook);
            hooks[chainIds[i]][BATCH_TRANSFER_FROM_HOOK_KEY] = Hook(
                BATCH_TRANSFER_FROM_HOOK_KEY,
                HookCategory.TokenApprovals,
                HookCategory.None,
                address(A[i].batchTransferFromHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.TokenApprovals].push(
                hooks[chainIds[i]][BATCH_TRANSFER_FROM_HOOK_KEY]
            );
            hooksAddresses[33] = address(A[i].batchTransferFromHook);

            /// @dev EXPERIMENTAL HOOKS FROM HERE ONWARDS
            A[i].ethenaCooldownSharesHook = new EthenaCooldownSharesHook{ salt: SALT }();
            vm.label(address(A[i].ethenaCooldownSharesHook), ETHENA_COOLDOWN_SHARES_HOOK_KEY);
            hookAddresses[chainIds[i]][ETHENA_COOLDOWN_SHARES_HOOK_KEY] = address(A[i].ethenaCooldownSharesHook);
            hooksAddresses[34] = address(A[i].ethenaCooldownSharesHook);

            A[i].ethenaUnstakeHook = new EthenaUnstakeHook{ salt: SALT }();
            vm.label(address(A[i].ethenaUnstakeHook), ETHENA_UNSTAKE_HOOK_KEY);
            hookAddresses[chainIds[i]][ETHENA_UNSTAKE_HOOK_KEY] = address(A[i].ethenaUnstakeHook);
            hooksAddresses[35] = address(A[i].ethenaUnstakeHook);

            A[i].spectraExchangeHook = new SpectraExchangeHook{ salt: SALT }(SPECTRA_ROUTERS[chainIds[i]]);
            vm.label(address(A[i].spectraExchangeHook), SPECTRA_EXCHANGE_HOOK_KEY);
            hookAddresses[chainIds[i]][SPECTRA_EXCHANGE_HOOK_KEY] = address(A[i].spectraExchangeHook);
            hooksAddresses[36] = address(A[i].spectraExchangeHook);

            A[i].pendleRouterSwapHook = new PendleRouterSwapHook{ salt: SALT }(PENDLE_ROUTERS[chainIds[i]]);
            vm.label(address(A[i].pendleRouterSwapHook), PENDLE_ROUTER_SWAP_HOOK_KEY);
            hookAddresses[chainIds[i]][PENDLE_ROUTER_SWAP_HOOK_KEY] = address(A[i].pendleRouterSwapHook);
            hooksAddresses[37] = address(A[i].pendleRouterSwapHook);

            A[i].pendleRouterRedeemHook = new PendleRouterRedeemHook{ salt: SALT }(PENDLE_ROUTERS[chainIds[i]]);
            vm.label(address(A[i].pendleRouterRedeemHook), PENDLE_ROUTER_REDEEM_HOOK_KEY);
            hookAddresses[chainIds[i]][PENDLE_ROUTER_REDEEM_HOOK_KEY] = address(A[i].pendleRouterRedeemHook);
            hooks[chainIds[i]][PENDLE_ROUTER_REDEEM_HOOK_KEY] = Hook(
                PENDLE_ROUTER_REDEEM_HOOK_KEY,
                HookCategory.Swaps,
                HookCategory.None,
                address(A[i].pendleRouterRedeemHook),
                ""
            );
            hooksByCategory[chainIds[i]][HookCategory.Swaps].push(hooks[chainIds[i]][PENDLE_ROUTER_REDEEM_HOOK_KEY]);
            hooksAddresses[38] = address(A[i].pendleRouterRedeemHook);

            A[i].cancelDepositRequest7540Hook = new CancelDepositRequest7540Hook{ salt: SALT }();
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
            hooksAddresses[39] = address(A[i].cancelDepositRequest7540Hook);

            A[i].cancelRedeemRequest7540Hook = new CancelRedeemRequest7540Hook{ salt: SALT }();
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
            hooksAddresses[40] = address(A[i].cancelRedeemRequest7540Hook);

            A[i].claimCancelDepositRequest7540Hook = new ClaimCancelDepositRequest7540Hook{ salt: SALT }();
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
            hooksAddresses[41] = address(A[i].claimCancelDepositRequest7540Hook);

            A[i].claimCancelRedeemRequest7540Hook = new ClaimCancelRedeemRequest7540Hook{ salt: SALT }();
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
            hooksAddresses[42] = address(A[i].claimCancelRedeemRequest7540Hook);

            A[i].cancelRedeemHook = new CancelRedeemHook{ salt: SALT }();
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
            hooksAddresses[43] = address(A[i].cancelRedeemHook);

            A[i].morphoBorrowHook = new MorphoBorrowHook{ salt: SALT }(MORPHO);
            vm.label(address(A[i].morphoBorrowHook), MORPHO_BORROW_HOOK_KEY);
            hookAddresses[chainIds[i]][MORPHO_BORROW_HOOK_KEY] = address(A[i].morphoBorrowHook);
            hooks[chainIds[i]][MORPHO_BORROW_HOOK_KEY] =
                Hook(MORPHO_BORROW_HOOK_KEY, HookCategory.Loans, HookCategory.None, address(A[i].morphoBorrowHook), "");
            hooksByCategory[chainIds[i]][HookCategory.Loans].push(hooks[chainIds[i]][MORPHO_BORROW_HOOK_KEY]);
            hooksAddresses[44] = address(A[i].morphoBorrowHook);

            A[i].morphoRepayHook = new MorphoRepayHook{ salt: SALT }(MORPHO);
            vm.label(address(A[i].morphoRepayHook), MORPHO_REPAY_HOOK_KEY);
            hookAddresses[chainIds[i]][MORPHO_REPAY_HOOK_KEY] = address(A[i].morphoRepayHook);
            hooks[chainIds[i]][MORPHO_REPAY_HOOK_KEY] =
                Hook(MORPHO_REPAY_HOOK_KEY, HookCategory.Loans, HookCategory.None, address(A[i].morphoRepayHook), "");
            hooksByCategory[chainIds[i]][HookCategory.Loans].push(hooks[chainIds[i]][MORPHO_REPAY_HOOK_KEY]);
            hooksAddresses[45] = address(A[i].morphoRepayHook);

            A[i].morphoRepayAndWithdrawHook = new MorphoRepayAndWithdrawHook{ salt: SALT }(MORPHO);
            vm.label(address(A[i].morphoRepayAndWithdrawHook), MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY);
            hookAddresses[chainIds[i]][MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY] = address(A[i].morphoRepayAndWithdrawHook);
            hooksAddresses[46] = address(A[i].morphoRepayAndWithdrawHook);

            hookListPerChain[chainIds[i]] = hooksAddresses;
            _createHooksTree(chainIds[i], hooksAddresses);

            // Initialize global Merkle hook addresses for later use
            globalMerkleHooks = new address[](5);
            globalMerkleHooks[0] = address(A[i].approveAndRedeem4626VaultHook);
            globalMerkleHooks[1] = address(A[i].approveAndDeposit4626VaultHook);
            globalMerkleHooks[2] = address(A[i].redeem4626VaultHook);
            globalMerkleHooks[3] = address(A[i].approveAndGearboxStakeHook);
            globalMerkleHooks[4] = address(A[i].gearboxUnstakeHook);

            // Initialize corresponding hook names for scalability
            globalMerkleHookNames = new string[](5);
            globalMerkleHookNames[0] = "APPROVE_AND_REDEEM_4626_VAULT_HOOK";
            globalMerkleHookNames[1] = "APPROVE_AND_DEPOSIT_4626_VAULT_HOOK";
            globalMerkleHookNames[2] = "REDEEM_4626_VAULT_HOOK";
            globalMerkleHookNames[3] = "APPROVE_AND_GEARBOX_STAKE_HOOK";
            globalMerkleHookNames[4] = "GEARBOX_UNSTAKE_HOOK";

            if (chainIds[i] == ETH) {
                /// @dev set any new sv addresses here
                address aggregator = _getContract(ETH, SUPER_VAULT_AGGREGATOR_KEY);
                globalSVStrategy = SuperVaultAggregator(aggregator).STRATEGY_IMPLEMENTATION()
                    .predictDeterministicAddress(
                    keccak256(
                        abi.encodePacked(existingUnderlyingTokens[ETH][USDC_KEY], "SuperVault", "SV_USDC", uint256(0))
                    ),
                    aggregator
                );
                globalSVGearStrategy = SuperVaultAggregator(aggregator).STRATEGY_IMPLEMENTATION()
                    .predictDeterministicAddress(
                    keccak256(
                        abi.encodePacked(existingUnderlyingTokens[ETH][USDC_KEY], "SuperVault", "svGearbox", uint256(1))
                    ),
                    aggregator
                );

                globalRuggableVault = SuperVaultAggregator(aggregator).STRATEGY_IMPLEMENTATION()
                    .predictDeterministicAddress(
                    keccak256(
                        abi.encodePacked(
                            existingUnderlyingTokens[ETH][USDC_KEY], "SuperVault", "SV_USDC_RUG", uint256(1)
                        )
                    ),
                    aggregator
                );
            }
        }

        return A;
    }

    /*
    
    
    function _updateAndRegenerateMerkleTree(
        string memory vaultName_,
        address vaultAddress_,
        uint64 chainId_
    )
        internal
    {
        string memory vaultAddressStr = vm.toString(vaultAddress_);
        string memory chainIdStr = vm.toString(chainId_);

        string[] memory cmd = new string[](5);
        cmd[0] = "node";
        cmd[1] = "test/utils/merkle/merkle-js/update-lists.js";
        cmd[2] = vaultName_; // Single vault name (not a number, signals single mode to script)
        cmd[3] = vaultAddressStr;
        cmd[4] = chainIdStr;

        _executeVaultListUpdateScript(cmd, chainId_);
    }


    function _updateAndRegenerateMerkleTreeBatch(
        string[] memory vaultNames_,
        address[] memory vaultAddresses_,
        uint64 chainId_
    )
        internal
    {
    require(vaultNames_.length == vaultAddresses_.length, "Vault names and addresses array lengths must match.");

        uint256 numVaults = vaultNames_.length;
        string memory chainIdStr = vm.toString(chainId_);

        // cmd: node <script_path> <numVaults> <name1> <name2> ... <addr1_str> <addr2_str> ... <chainId_str>
        string[] memory cmd = new string[](3 + numVaults * 2 + 1);
        cmd[0] = "node";
        cmd[1] = "test/utils/merkle/merkle-js/update-lists.js";
        cmd[2] = vm.toString(numVaults); // This signals batch mode to the script

        for (uint256 i = 0; i < numVaults; i++) {
            cmd[3 + i] = vaultNames_[i];
            cmd[3 + numVaults + i] = vm.toString(vaultAddresses_[i]);
        }
        cmd[3 + numVaults * 2] = chainIdStr;

        _executeVaultListUpdateScript(cmd, chainId_);
    }

       function _executeVaultListUpdateScript(string[] memory cmd_, uint64 chainId_) internal {
        bytes memory output = vm.ffi(cmd_);
        string memory outputStr = string(output);
        // Note: _trim was removed. JS script now outputs "true\n" or "false\n".

        bool wasSuccessful = false;
        if (bytes(outputStr).length > 0) {
            // Check if the script output starts with 't', indicating "true\n"
            if (bytes(outputStr)[0] == "t") {
                wasSuccessful = true;
            }
        }

        if (wasSuccessful) {
            console2.log(
                "[DEBUG] update-lists.js executed successfully. Regenerating Merkle tree for chainId:", chainId_
            );
            _generateMerkleTree(chainId_);
        } else {
            // Log details to stderr from the script will provide more context on failure.
            console2.log(
    "[WARN] update-lists.js indicated failure or no changes made. Merkle tree not regenerated. Check stderr for details
    from script."
            );
            if (bytes(outputStr).length == 0) {
                console2.log(
    "[WARN] update-lists.js produced empty output (FFI call might have failed before script execution)."
                );
            }
            // revert("Failed to update token/yield lists.");
        }
    }

    */

    function _configureGovernor() internal {
        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);

            SuperGovernor superGovernor = SuperGovernor(_getContract(chainIds[i], SUPER_GOVERNOR_KEY));

            superGovernor.setAddress(
                superGovernor.SUPER_VAULT_AGGREGATOR(), _getContract(chainIds[i], SUPER_VAULT_AGGREGATOR_KEY)
            );

            superGovernor.setAddress(superGovernor.TREASURY(), TREASURY);
        }
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

            SuperGovernor superGovernor = SuperGovernor(_getContract(chainIds[i], SUPER_GOVERNOR_KEY));

            console2.log("Registering hooks for chain", chainIds[i]);
            if (DEBUG) {
                console2.log("deposit4626VaultHook", address(A[i].deposit4626VaultHook));
                console2.log("redeem4626VaultHook", address(A[i].redeem4626VaultHook));
                console2.log("approveAndRedeem4626VaultHook", address(A[i].approveAndRedeem4626VaultHook));
                console2.log("deposit5115VaultHook", address(A[i].deposit5115VaultHook));
                console2.log("redeem5115VaultHook", address(A[i].redeem5115VaultHook));
                console2.log("requestDeposit7540VaultHook", address(A[i].requestDeposit7540VaultHook));
                console2.log("requestRedeem7540VaultHook", address(A[i].requestRedeem7540VaultHook));
                console2.log("approveAndDeposit4626VaultHook", address(A[i].approveAndDeposit4626VaultHook));
                console2.log("approveAndDeposit5115VaultHook", address(A[i].approveAndDeposit5115VaultHook));
                console2.log("approveAndRedeem5115VaultHook", address(A[i].approveAndRedeem5115VaultHook));
                console2.log(
                    "approveAndRequestDeposit7540VaultHook", address(A[i].approveAndRequestDeposit7540VaultHook)
                );
                console2.log("approveErc20Hook", address(A[i].approveErc20Hook));
                console2.log("transferErc20Hook", address(A[i].transferErc20Hook));
                console2.log("deposit7540VaultHook", address(A[i].deposit7540VaultHook));
                console2.log("withdraw7540VaultHook", address(A[i].withdraw7540VaultHook));
                console2.log("approveAndRedeem7540VaultHook", address(A[i].approveAndRedeem7540VaultHook));
                console2.log("swap1InchHook", address(A[i].swap1InchHook));
                console2.log("swapOdosHook", address(A[i].swapOdosHook));
                console2.log("approveAndSwapOdosHook", address(A[i].approveAndSwapOdosHook));
                console2.log("acrossSendFundsAndExecuteOnDstHook", address(A[i].acrossSendFundsAndExecuteOnDstHook));
                console2.log("fluidClaimRewardHook", address(A[i].fluidClaimRewardHook));
                console2.log("fluidStakeHook", address(A[i].fluidStakeHook));
                console2.log("approveAndFluidStakeHook", address(A[i].approveAndFluidStakeHook));
                console2.log("fluidUnstakeHook", address(A[i].fluidUnstakeHook));
                console2.log("gearboxClaimRewardHook", address(A[i].gearboxClaimRewardHook));
                console2.log("gearboxStakeHook", address(A[i].gearboxStakeHook));
                console2.log("approveAndGearboxStakeHook", address(A[i].approveAndGearboxStakeHook));
                console2.log("gearboxUnstakeHook", address(A[i].gearboxUnstakeHook));
                console2.log("yearnClaimOneRewardHook", address(A[i].yearnClaimOneRewardHook));
                console2.log("ethenaCooldownSharesHook", address(A[i].ethenaCooldownSharesHook));
                console2.log("ethenaUnstakeHook", address(A[i].ethenaUnstakeHook));
                console2.log("cancelDepositRequest7540Hook", address(A[i].cancelDepositRequest7540Hook));
                console2.log("cancelRedeemRequest7540Hook", address(A[i].cancelRedeemRequest7540Hook));
                console2.log("claimCancelDepositRequest7540Hook", address(A[i].claimCancelDepositRequest7540Hook));
                console2.log("claimCancelRedeemRequest7540Hook", address(A[i].claimCancelRedeemRequest7540Hook));
                console2.log("cancelRedeemHook", address(A[i].cancelRedeemHook));
            }

            // Register fulfillRequests hooks
            superGovernor.registerHook(address(A[i].deposit4626VaultHook), true);
            superGovernor.registerHook(address(A[i].redeem4626VaultHook), true);
            superGovernor.registerHook(address(A[i].approveAndRedeem4626VaultHook), true);
            superGovernor.registerHook(address(A[i].deposit5115VaultHook), true);
            superGovernor.registerHook(address(A[i].redeem5115VaultHook), true);
            superGovernor.registerHook(address(A[i].requestDeposit7540VaultHook), false);
            superGovernor.registerHook(address(A[i].requestRedeem7540VaultHook), false);

            // Register remaining hooks
            superGovernor.registerHook(address(A[i].approveAndDeposit4626VaultHook), true);
            superGovernor.registerHook(address(A[i].approveAndDeposit5115VaultHook), true);
            superGovernor.registerHook(address(A[i].approveAndRedeem5115VaultHook), true);
            superGovernor.registerHook(address(A[i].approveAndRequestDeposit7540VaultHook), true);
            superGovernor.registerHook(address(A[i].approveErc20Hook), false);
            superGovernor.registerHook(address(A[i].transferErc20Hook), false);
            superGovernor.registerHook(address(A[i].deposit7540VaultHook), true);
            superGovernor.registerHook(address(A[i].withdraw7540VaultHook), false);
            superGovernor.registerHook(address(A[i].approveAndRedeem7540VaultHook), true);
            superGovernor.registerHook(address(A[i].swap1InchHook), false);
            superGovernor.registerHook(address(A[i].swapOdosHook), false);
            superGovernor.registerHook(address(A[i].approveAndSwapOdosHook), false);
            superGovernor.registerHook(address(A[i].acrossSendFundsAndExecuteOnDstHook), false);
            superGovernor.registerHook(address(A[i].fluidClaimRewardHook), false);
            superGovernor.registerHook(address(A[i].fluidStakeHook), false);
            superGovernor.registerHook(address(A[i].approveAndFluidStakeHook), false);
            superGovernor.registerHook(address(A[i].fluidUnstakeHook), false);
            superGovernor.registerHook(address(A[i].gearboxClaimRewardHook), false);
            superGovernor.registerHook(address(A[i].gearboxStakeHook), false);
            superGovernor.registerHook(address(A[i].approveAndGearboxStakeHook), false);
            superGovernor.registerHook(address(A[i].gearboxUnstakeHook), false);
            superGovernor.registerHook(address(A[i].yearnClaimOneRewardHook), false);
            superGovernor.registerHook(address(A[i].cancelDepositRequest7540Hook), false);
            superGovernor.registerHook(address(A[i].cancelRedeemRequest7540Hook), false);
            superGovernor.registerHook(address(A[i].claimCancelDepositRequest7540Hook), false);
            superGovernor.registerHook(address(A[i].claimCancelRedeemRequest7540Hook), false);
            superGovernor.registerHook(address(A[i].cancelRedeemHook), false);
            // EXPERIMENTAL HOOKS FROM HERE ONWARDS
            superGovernor.registerHook(address(A[i].ethenaCooldownSharesHook), false);
            superGovernor.registerHook(address(A[i].ethenaUnstakeHook), true);
            superGovernor.registerHook(address(A[i].morphoBorrowHook), false);
            superGovernor.registerHook(address(A[i].morphoRepayHook), false);
            superGovernor.registerHook(address(A[i].morphoRepayAndWithdrawHook), false);
            superGovernor.registerHook(address(A[i].pendleRouterRedeemHook), false);
        }

        return A;
    }

    // Hook mocking helpers

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
                module: _getContract(chainIds[i], SUPER_DESTINATION_EXECUTOR_KEY),
                data: ""
            });

            instance.installModule({
                moduleTypeId: MODULE_TYPE_EXECUTOR,
                module: _getContract(chainIds[i], SUPER_EXECUTOR_WITH_SP_LOCK_KEY),
                data: ""
            });
            instance.installModule({
                moduleTypeId: MODULE_TYPE_VALIDATOR,
                module: _getContract(chainIds[i], SUPER_DESTINATION_VALIDATOR_KEY),
                data: abi.encode(validatorSigners[chainIds[i]])
            });
            instance.installModule({
                moduleTypeId: MODULE_TYPE_VALIDATOR,
                module: _getContract(chainIds[i], SUPER_MERKLE_VALIDATOR_KEY),
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
            forks[ETH] = vm.createFork(ETHEREUM_RPC_URL, ETH_BLOCK);
            forks[OP] = vm.createFork(OPTIMISM_RPC_URL, OP_BLOCK);
            forks[BASE] = vm.createFork(BASE_RPC_URL, BASE_BLOCK);
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

        mapping(uint64 => address) storage debridgeDlnSourceAddressesMap = DEBRIDGE_DLN_ADDRESSES;
        debridgeDlnSourceAddressesMap[ETH] = DEBRIDGE_DLN_SOURCE_ADDRESS;
        vm.label(debridgeDlnSourceAddressesMap[ETH], "DebridgeDlnSourceETH");
        debridgeDlnSourceAddressesMap[OP] = DEBRIDGE_DLN_SOURCE_ADDRESS;
        vm.label(debridgeDlnSourceAddressesMap[OP], "DebridgeDlnSourceOP");
        debridgeDlnSourceAddressesMap[BASE] = DEBRIDGE_DLN_SOURCE_ADDRESS;
        vm.label(debridgeDlnSourceAddressesMap[BASE], "DebridgeDlnSourceBASE");

        mapping(uint64 => address) storage debridgeDlnSourceAddressesDstMap = DEBRIDGE_DLN_ADDRESSES_DST;
        debridgeDlnSourceAddressesDstMap[ETH] = DEBRIDGE_DLN_DST;
        vm.label(debridgeDlnSourceAddressesDstMap[ETH], "DebridgeDlnDstETH");
        debridgeDlnSourceAddressesDstMap[OP] = DEBRIDGE_DLN_DST;
        vm.label(debridgeDlnSourceAddressesDstMap[OP], "DebridgeDlnDstOP");
        debridgeDlnSourceAddressesDstMap[BASE] = DEBRIDGE_DLN_DST;
        vm.label(debridgeDlnSourceAddressesDstMap[BASE], "DebridgeDlnDstBASE");

        mapping(uint64 => address) storage pendleRouters = PENDLE_ROUTERS;
        pendleRouters[ETH] = CHAIN_1_PendleRouter;
        vm.label(pendleRouters[ETH], "PendleRouterETH");
        pendleRouters[OP] = CHAIN_10_PendleRouter;
        vm.label(pendleRouters[OP], "PendleRouterOP");
        pendleRouters[BASE] = CHAIN_8453_PendleRouter;
        vm.label(pendleRouters[BASE], "PendleRouterBASE");

        mapping(uint64 => address) storage spectraRouters = SPECTRA_ROUTERS;
        spectraRouters[ETH] = CHAIN_1_SpectraRouter;
        vm.label(spectraRouters[ETH], "SpectraRouterETH");
        spectraRouters[OP] = CHAIN_10_SpectraRouter;
        vm.label(spectraRouters[OP], "SpectraRouterOP");
        spectraRouters[BASE] = CHAIN_8453_SpectraRouter;
        vm.label(spectraRouters[BASE], "SpectraRouterBASE");

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

        mapping(uint64 => address) storage polymerProvers = POLYMER_PROVER;
        polymerProvers[ETH] = CHAIN_1_POLYMER_PROVER;
        vm.label(polymerProvers[ETH], "PolymerProverETH");
        polymerProvers[OP] = CHAIN_10_POLYMER_PROVER;
        // vm.label(polymerProvers[OP], "PolymerProverOP");
        polymerProvers[BASE] = CHAIN_8453_POLYMER_PROVER;
        // vm.label(polymerProvers[BASE], "PolymerProverBASE");

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
        existingVaults[BASE][ERC4626_VAULT_KEY][AAVE_BASE_WETH][WETH_KEY] = CHAIN_8453_MorphoGauntletWETHCore;
        vm.label(existingVaults[BASE][ERC4626_VAULT_KEY][AAVE_BASE_WETH][WETH_KEY], AAVE_BASE_WETH);

        /// @dev 7540 real centrifuge vaults on mainnet
        existingVaults[ETH][ERC7540FullyAsync_KEY][CENTRIFUGE_USDC_VAULT_KEY][USDC_KEY] = CHAIN_1_CentrifugeUSDC;
        vm.label(
            existingVaults[ETH][ERC7540FullyAsync_KEY][CENTRIFUGE_USDC_VAULT_KEY][USDC_KEY], CENTRIFUGE_USDC_VAULT_KEY
        );

        /// @dev 5115 real pendle ethena vault on mainnet
        existingVaults[ETH][ERC5115_VAULT_KEY][PENDLE_ETHENA_KEY][SUSDE_KEY] = CHAIN_1_PendleEthena;
        vm.label(existingVaults[ETH][ERC5115_VAULT_KEY][PENDLE_ETHENA_KEY][SUSDE_KEY], "PendleEthena");

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

    function _setupSuperLedger() internal {
        for (uint256 i; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);

            vm.startPrank(MANAGER);

            SuperGovernor superGovernor = SuperGovernor(_getContract(chainIds[i], SUPER_GOVERNOR_KEY));
            ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
                new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](4);
            configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
                yieldSourceOracleId: bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                yieldSourceOracle: _getContract(chainIds[i], ERC4626_YIELD_SOURCE_ORACLE_KEY),
                feePercent: 100,
                feeRecipient: superGovernor.getAddress(keccak256("TREASURY")),
                ledger: _getContract(chainIds[i], SUPER_LEDGER_KEY)
            });
            configs[1] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
                yieldSourceOracleId: bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)),
                yieldSourceOracle: _getContract(chainIds[i], ERC7540_YIELD_SOURCE_ORACLE_KEY),
                feePercent: 100,
                feeRecipient: superGovernor.getAddress(keccak256("TREASURY")),
                ledger: _getContract(chainIds[i], SUPER_LEDGER_KEY)
            });
            configs[2] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
                yieldSourceOracleId: bytes4(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)),
                yieldSourceOracle: _getContract(chainIds[i], ERC5115_YIELD_SOURCE_ORACLE_KEY),
                feePercent: 100,
                feeRecipient: superGovernor.getAddress(keccak256("TREASURY")),
                ledger: _getContract(chainIds[i], ERC1155_LEDGER_KEY)
            });
            configs[3] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
                yieldSourceOracleId: bytes4(bytes(STAKING_YIELD_SOURCE_ORACLE_KEY)),
                yieldSourceOracle: _getContract(chainIds[i], STAKING_YIELD_SOURCE_ORACLE_KEY),
                feePercent: 100,
                feeRecipient: superGovernor.getAddress(keccak256("TREASURY")),
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

    function _assertFeeDerivation(
        uint256 expectedFee,
        uint256 feeBalanceBefore,
        uint256 feeBalanceAfter
    )
        internal
        pure
    {
        console2.log("feeBalanceAfter", feeBalanceAfter);
        console2.log("expected fee", expectedFee);
        console2.log("feeBalanceBefore", feeBalanceBefore);
        assertEq(feeBalanceAfter, feeBalanceBefore + expectedFee, "Fee derivation failed");
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

    /*//////////////////////////////////////////////////////////////
                    BRIDGE AND DST EXECUTION HELPERS
    //////////////////////////////////////////////////////////////*/
    enum RELAYER_TYPE {
        NOT_ENOUGH_BALANCE,
        ENOUGH_BALANCE,
        NO_HOOKS,
        LOW_LEVEL_FAILED,
        FAILED
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
            vm.expectEmit(true, false, false, false);
            emit ISuperDestinationExecutor.SuperDestinationExecutorReceivedButNotEnoughBalance(
                account, address(0), 0, 0
            );
        } else if (relayerType == RELAYER_TYPE.ENOUGH_BALANCE) {
            vm.expectEmit(true, true, true, true);
            emit ISuperDestinationExecutor.SuperDestinationExecutorExecuted(account);
        } else if (relayerType == RELAYER_TYPE.NO_HOOKS) {
            vm.expectEmit(true, true, true, true);
            emit ISuperDestinationExecutor.SuperDestinationExecutorReceivedButNoHooks(account);
        } else if (relayerType == RELAYER_TYPE.LOW_LEVEL_FAILED) {
            vm.expectEmit(true, false, false, false);
            emit ISuperDestinationExecutor.SuperDestinationExecutorFailedLowLevel(account, "");
        } else if (relayerType == RELAYER_TYPE.FAILED) {
            vm.expectEmit(true, false, false, false);
            emit ISuperDestinationExecutor.SuperDestinationExecutorFailed(account, "");
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

    function _processDebridgeDlnMessage(
        uint64 srcChainId,
        uint64 dstChainId,
        ExecutionReturnData memory executionData
    )
        internal
    {
        DebridgeDlnHelper(_getContract(srcChainId, DEBRIDGE_DLN_HELPER_KEY)).help(
            DEBRIDGE_DLN_ADDRESSES[srcChainId],
            DEBRIDGE_DLN_ADDRESSES_DST[dstChainId],
            FORKS[dstChainId],
            dstChainId,
            executionData.logs
        );
    }

    struct TargetExecutorMessage {
        address[] hooksAddresses;
        bytes[] hooksData;
        address validator;
        address signer;
        uint256 signerPrivateKey;
        address targetAdapter;
        address targetExecutor;
        address nexusFactory;
        address nexusBootstrap;
        uint64 chainId;
        uint256 amount;
        address account;
        address tokenSent;
    }

    function _precomputeTargetExecutorAccount(
        address validator,
        address signer,
        address nexusFactory,
        address nexusBootstrap,
        uint64 chainId
    )
        internal
        returns (address)
    {
        (, address account) = _createAccountCreationData_DestinationExecutor(
            validator, signer, _getContract(chainId, SUPER_DESTINATION_EXECUTOR_KEY), nexusFactory, nexusBootstrap
        );
        return account;
    }

    function _createTargetExecutorMessage(TargetExecutorMessage memory messageData)
        internal
        returns (bytes memory, address)
    {
        bytes memory executionData =
            _createCrosschainExecutionData_DestinationExecutor(messageData.hooksAddresses, messageData.hooksData);

        address accountToUse;
        bytes memory accountCreationData;
        if (messageData.account == address(0)) {
            (accountCreationData, accountToUse) = _createAccountCreationData_DestinationExecutor(
                messageData.validator,
                messageData.signer,
                _getContract(messageData.chainId, SUPER_DESTINATION_EXECUTOR_KEY),
                messageData.nexusFactory,
                messageData.nexusBootstrap
            );
            messageData.account = accountToUse; // prefill the account to use
        } else {
            accountToUse = messageData.account;
            accountCreationData = bytes("");
        }
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = messageData.tokenSent;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = messageData.amount;
        return (
            abi.encode(accountCreationData, executionData, messageData.account, dstTokens, intentAmounts), accountToUse
        );
    }

    struct MerkleContext {
        uint48 validUntil;
        bytes executionData;
        bytes32[] leaves;
        address[] dstTokens;
        uint256[] intentAmounts;
        bytes32[][] merkleProof;
        bytes32 merkleRoot;
        bytes signature;
    }

    function _createMerkleRootAndSignature(
        TargetExecutorMessage memory messageData,
        bytes32 userOpHash,
        address accountToUse,
        uint64 dstChainId
    )
        internal
        view
        returns (bytes memory sig)
    {
        MerkleContext memory ctx;

        ctx.validUntil = uint48(block.timestamp + 100 days);
        ctx.executionData = _createCrosschainExecutionData_DestinationExecutor(
            messageData.hooksAddresses,
            messageData.hooksData
        );

        ctx.leaves = new bytes32[](2);
        ctx.dstTokens = new address[](1);
        ctx.dstTokens[0] = messageData.tokenSent;
        ctx.intentAmounts = new uint256[](1);
        ctx.intentAmounts[0] = messageData.amount;

        ctx.leaves[0] = _createDestinationValidatorLeaf(
            ctx.executionData,
            messageData.chainId,
            accountToUse,
            messageData.targetExecutor,
            ctx.dstTokens,
            ctx.intentAmounts,
            ctx.validUntil
        );
        ctx.leaves[1] = _createSourceValidatorLeaf(userOpHash, ctx.validUntil);

        (ctx.merkleProof, ctx.merkleRoot) = _createValidatorMerkleTree(ctx.leaves);

        ctx.signature = _createSignature(
            SuperValidatorBase(address(messageData.validator)).namespace(),
            ctx.merkleRoot,
            messageData.signer,
            messageData.signerPrivateKey
        );

        SuperValidatorBase.DstProof[] memory proofDst = new SuperValidatorBase.DstProof[](1);
        SuperValidatorBase.DstInfo memory dstInfo = SuperValidatorBase.DstInfo({
            data: ctx.executionData,
            executor: messageData.targetExecutor,
            dstTokens: ctx.dstTokens,
            intentAmounts: ctx.intentAmounts,
            account: accountToUse
        });
        proofDst[0] = SuperValidatorBase.DstProof({proof: ctx.merkleProof[0], dstChainId: dstChainId, info: dstInfo});

        console2.log("---- base test dst data len", ctx.executionData.length);
        console2.log("---- base test targetExecutor", messageData.targetExecutor);
        console2.log("---- base test dstTokens", ctx.dstTokens.length);
        console2.log("---- base test intentAmounts", ctx.intentAmounts.length);
        console2.log("---- base test validUntil", ctx.validUntil);
        console2.log("---- base test merkleRoot");
        console2.logBytes32(ctx.merkleRoot);
        sig = _createSignatureData_DestinationExecutor(
            ctx.validUntil,
            ctx.merkleRoot,
            ctx.merkleProof[1],
            proofDst,
            ctx.signature
        );
    }

    function _createSignatureData_DestinationExecutor(
        uint48 validUntil,
        bytes32 merkleRoot,
        bytes32[] memory merkleProofSrc,
        SuperValidatorBase.DstProof[] memory merkleProofDst,
        bytes memory signature
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(validUntil, merkleRoot, merkleProofSrc, merkleProofDst, signature);
    }

    function _createCrosschainExecutionData_DestinationExecutor(
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

    function _createAccountCreationData_DestinationExecutor(
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
            _getContract(destinationChainId, ACROSS_V3_ADAPTER_KEY),
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

    /**
     * @notice Creates the external call envelope for Debridge DLN V1.
     * @param executorAddress The address of the contract to execute the payload on the destination chain.
     * @param executionFee Fee for the executor.
     * @param fallbackAddress Address to receive funds if execution fails.
     * @param payload The actual data to be executed by the executorAddress.
     * @param allowDelayedExecution Whether delayed execution is allowed.
     * @param requireSuccessfulExecution Whether the external call must succeed.
     * @return The encoded external call envelope V1, prefixed with version byte.
     */
    function _createDebridgeExternalCallEnvelope(
        address executorAddress,
        uint160 executionFee,
        address fallbackAddress,
        bytes memory payload,
        bool allowDelayedExecution,
        bool requireSuccessfulExecution // Note: Keep typo from library 'requireSuccessfullExecution'
    )
        internal
        pure
        returns (bytes memory)
    {
        DlnExternalCallLib.ExternalCallEnvelopV1 memory dataEnvelope = DlnExternalCallLib.ExternalCallEnvelopV1({
            executorAddress: executorAddress,
            executionFee: executionFee,
            fallbackAddress: fallbackAddress,
            payload: payload,
            allowDelayedExecution: allowDelayedExecution,
            requireSuccessfullExecution: requireSuccessfulExecution
        });

        // Prepend version byte (1) to the encoded envelope
        return abi.encodePacked(uint8(1), abi.encode(dataEnvelope));
    }

    struct DebridgeOrderData {
        bool usePrevHookAmount;
        uint256 value;
        address giveTokenAddress;
        uint256 giveAmount;
        uint8 version;
        address fallbackAddress;
        address executorAddress;
        uint256 executionFee;
        bool allowDelayedExecution;
        bool requireSuccessfulExecution;
        bytes payload;
        address takeTokenAddress;
        uint256 takeAmount;
        uint256 takeChainId;
        address receiverDst;
        address givePatchAuthoritySrc;
        bytes orderAuthorityAddressDst;
        bytes allowedTakerDst;
        bytes allowedCancelBeneficiarySrc;
        bytes affiliateFee;
        uint32 referralCode;
    }

    function _createDebridgeSendFundsAndExecuteHookData(DebridgeOrderData memory d)
        internal
        pure
        returns (bytes memory hookData)
    {
        bytes memory part1 = _encodeDebridgePart1(d);
        bytes memory part2 = _encodeDebridgePart2(d);
        bytes memory part3 = _encodeDebridgePart3(d);
        hookData = bytes.concat(part1, part2, part3);
    }

    function _encodeDebridgePart1(DebridgeOrderData memory d) internal pure returns (bytes memory) {
        return abi.encodePacked(
            d.usePrevHookAmount,
            d.value,
            d.giveTokenAddress,
            d.giveAmount,
            d.version,
            d.fallbackAddress,
            d.executorAddress
        );
    }

    function _encodeDebridgePart2(DebridgeOrderData memory d) internal pure returns (bytes memory) {
        return abi.encodePacked(
            d.executionFee,
            d.allowDelayedExecution,
            d.requireSuccessfulExecution,
            d.payload.length,
            d.payload,
            abi.encodePacked(d.takeTokenAddress).length,
            abi.encodePacked(d.takeTokenAddress),
            d.takeAmount,
            d.takeChainId
        );
    }

    function _encodeDebridgePart3(DebridgeOrderData memory d) internal pure returns (bytes memory) {
        return abi.encodePacked(
            abi.encodePacked(d.receiverDst).length,
            abi.encodePacked(d.receiverDst),
            d.givePatchAuthoritySrc,
            d.orderAuthorityAddressDst.length,
            d.orderAuthorityAddressDst,
            d.allowedTakerDst.length,
            d.allowedTakerDst,
            d.allowedCancelBeneficiarySrc.length,
            d.allowedCancelBeneficiarySrc,
            d.affiliateFee.length,
            d.affiliateFee,
            d.referralCode
        );
    }
}
