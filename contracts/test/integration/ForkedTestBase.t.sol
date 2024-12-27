// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { Helpers } from "../utils/Helpers.sol";
import { console } from "forge-std/console.sol";

// Superform interfaces
import { ISuperRbac } from "../../src/interfaces/ISuperRbac.sol";
import { ISentinel } from "../../src/interfaces/sentinel/ISentinel.sol";
import { ISuperRegistry } from "../../src/interfaces/ISuperRegistry.sol";
import { ISuperExecutorV2 } from "../../src/interfaces/ISuperExecutorV2.sol";
import { ISharedStateReader } from "../../src/interfaces/state/ISharedStateReader.sol";
import { ISharedStateWriter } from "../../src/interfaces/state/ISharedStateWriter.sol";
import { ISuperActions } from "../../src/interfaces/strategies/ISuperActions.sol";

// Superform contracts
import { SuperRbac } from "../../src/settings/SuperRbac.sol";
import { SharedState } from "../../src/state/SharedState.sol";
import { SpokePoolV3Mock } from "../mocks/SpokePoolV3Mock.sol";
import { SuperActions } from "../../src/strategies/SuperActions.sol";
import { SuperRegistry } from "../../src/settings/SuperRegistry.sol";
import { SuperExecutorV2 } from "../../src/executors/SuperExecutorV2.sol";
import { AcrossBridgeGateway } from "../../src/bridges/AcrossBridgeGateway.sol";
import { SuperPositionSentinel } from "../../src/sentinels/SuperPositionSentinel.sol";

// hooks
// tokens hooks
// --- erc20
import { ApproveERC20Hook } from "../../src/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { TransferERC20Hook } from "../../src/hooks/tokens/erc20/TransferERC20Hook.sol";
// vault hooks
// --- erc5115
import { Deposit5115VaultHook } from "../../src/hooks/vaults/5115/Deposit5115VaultHook.sol";
import { Withdraw5115VaultHook } from "../../src/hooks/vaults/5115/Withdraw5115VaultHook.sol";
// --- erc4626
import { Deposit4626VaultHook } from "../../src/hooks/vaults/4626/Deposit4626VaultHook.sol";
import { Withdraw4626VaultHook } from "../../src/hooks/vaults/4626/Withdraw4626VaultHook.sol";
// -- erc7540
import { RequestDeposit7540VaultHook } from "../../src/hooks/vaults/7540/RequestDeposit7540VaultHook.sol";
import { RequestWithdraw7540VaultHook } from "../../src/hooks/vaults/7540/RequestWithdraw7540VaultHook.sol";
// bridges hooks
import { AcrossExecuteOnDestinationHook } from "../../src/hooks/bridges/across/AcrossExecuteOnDestinationHook.sol";

// action oracles
import { DepositRedeem4626ActionOracle } from "../../src/strategies/oracles/DepositRedeem4626ActionOracle.sol";
import { DepositRedeem5115ActionOracle } from "../../src/strategies/oracles/DepositRedeem5115ActionOracle.sol";

// external
import { console } from "forge-std/console.sol";
import { 
  RhinestoneModuleKit, 
  ModuleKitHelpers, 
  AccountInstance
} from "modulekit/ModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";

contract ForkedTestBase is Helpers, RhinestoneModuleKit {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

  /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
  //////////////////////////////////////////////////////////////*/

    // 5115 vault assets
    struct ChosenAssets {
        address assetIn;
        address assetOut;
    }


    string[] public chainsNames = [
        "Ethereum",
        "Arbitrum",
        "Optimism",
        "Sepolia",
        "Base"
    ];

    string[] public vaultKinds = [
        "VaultMock",
        "ERC4626",
        "ERC5115",
        "ERC7540FullyAsync",
        "ERC7540AsyncDeposit",
        "ERC7540AsyncRedeem"
    ];

    string[] public underlyingTokens = [
      "DAI", 
      "USDC", 
      "WETH", 
      "ETH"
    ];
    
    address public user1;
    address public user2;
    address public deployer = vm.addr(777);
    address public SUPER_ACTIONS_CONFIGURATOR;

    uint256 public deployerPrivateKey;

    // core
    ISuperRbac public superRbac;
    SharedState public sharedState;
    ISuperActions public superActions;
    ISuperRegistry public superRegistry;
    ISuperExecutorV2 public superExecutor;
    ISentinel public superPositionSentinel;
    ISharedStateReader public sharedStateReader;
    ISharedStateWriter public sharedStateWriter;

    SpokePoolV3Mock public spokePoolV3Mock;
    AcrossBridgeGateway public acrossBridgeGateway;
    
    AccountInstance public instance;

    mapping(bytes32 name => uint256 actionId) public ACTION;

    address public constant ENTRY_POINT = address(1);

    uint256[] public allActions;

    // hooks
    address public ACTION_ORACLE_TEMP = address(0x111112);
    ApproveERC20Hook public approveErc20Hook;
    TransferERC20Hook public transferErc20Hook;
    Deposit4626VaultHook public deposit4626VaultHook;
    Withdraw4626VaultHook public withdraw4626VaultHook;
    Deposit5115VaultHook public deposit5115VaultHook;
    Withdraw5115VaultHook public withdraw5115VaultHook;
    RequestDeposit7540VaultHook public requestDeposit7540VaultHook;
    RequestWithdraw7540VaultHook public requestWithdraw7540VaultHook;
    AcrossExecuteOnDestinationHook public acrossExecuteOnDestinationHook;
    DepositRedeem4626ActionOracle public depositRedeem4626ActionOracle;
    DepositRedeem5115ActionOracle public depositRedeem5115ActionOracle;

    mapping(uint64 chainId => mapping(string underlying => address realAddress)) public existingUnderlyingTokens;

    mapping(uint64 chainId => mapping(address realVaultAddress => ChosenAssets chosenAssets)) public chosen5115Assets;
    
    mapping(uint64 chainId => mapping(string vaultKind => 
    mapping(string vaultName => mapping (string underlying => 
    address realVault)))) public realVaultAddresses;

    mapping(uint64 chainId => mapping(bytes32 implementation => address at)) public contracts;

    mapping(string vaultKind => address[] vaults) public vaultsByKind;

    // contracts
    mapping(uint64 chainId => address superRegistry) public superRegistries;
    mapping(uint64 chainId => address superRbac) public superRbacAddresses;
    mapping(uint64 chainId => address sharedState) public sharedStatesAddresses;
    mapping(uint64 chainId => address superActions) public superActionsAddresses;
    mapping(uint64 chainId => address superExecutor) public superExecutorsAddresses;
    mapping(uint64 chainId => address superPositionSentinel) public superPositionSentinelsAddresses;
    mapping(uint64 chainId => address spokePoolV3Mock) public spokePoolV3MocksAddresses;
    mapping(uint64 chainId => address acrossBridgeGateway) public acrossBridgeGatewaysAddresses;
    
    /*//////////////////////////////////////////////////////////////
                              RPC VARIABLES
    //////////////////////////////////////////////////////////////*/

    // chainID => FORK
    mapping(uint64 chainId => uint256 fork) public FORKS;
    mapping(uint64 chainId => string forkUrl) public RPC_URLS;

    string public ETHEREUM_RPC_URL_QN = vm.envString("ETHEREUM_RPC_URL_QN"); // Native token: ETH
    string public ARBITRUM_RPC_URL_QN = vm.envString("ARBITRUM_RPC_URL_QN"); // Native token: // ToDo
    string public OPTIMISM_RPC_URL_QN = vm.envString("OPTIMISM_RPC_URL_QN"); // Native token: // ToDo
    string public BASE_RPC_URL_QN = vm.envString("BASE_RPC_URL_QN"); // Native token: // ToDo
    string public SEPOLIA_RPC_URL_QN = vm.envString("SEPOLIA_RPC_URL_QN"); // Native token: ETH

    uint64 public constant ETH = 1;
    uint64 public constant OP = 10;
    uint64 public constant BASE = 8453;
    uint64 public constant ARBI = 42_161;

    uint64[] public chainIds = [1, 42_161, 10, 8453];

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        // Setup forks
        _preDeploymentSetup();

        // Deploy contracts
        _deployContracts();

        // Deploy hooks
        _deployHooks();

        // Initialize the account instance
        instance = makeAccountInstance("SuperformAccount");
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        vm.label(instance.account, "SuperformAccount");
        vm.makePersistent(instance.account);

        // Register on SuperRegistry
        _setSuperRegistryAddresses();

        // Set roles
        _setRoles();

        // Register action
        _performRegistrations();

        // Fund native tokens
        _fundNativeTokens();

        // Fund underlying tokens
        _fundUnderlyingTokens(10_000);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _deployHooks() internal {
      for (uint256 i = 0; i < chainIds.length; ++i) {
        vm.selectFork(FORKS[chainIds[i]]);

        superRegistry = ISuperRegistry(superRegistries[chainIds[i]]);

        approveErc20Hook = new ApproveERC20Hook(address(superRegistry), address(this));
        vm.label(address(approveErc20Hook), "ApproveERC20Hook");
        vm.makePersistent(address(approveErc20Hook));

        transferErc20Hook = new TransferERC20Hook(address(superRegistry), address(this));
        vm.label(address(transferErc20Hook), "TransferERC20Hook");
        vm.makePersistent(address(transferErc20Hook));

        deposit4626VaultHook = new Deposit4626VaultHook(address(superRegistry), address(this));
        vm.label(address(deposit4626VaultHook), "Deposit4626VaultHook");
        vm.makePersistent(address(deposit4626VaultHook));

        withdraw4626VaultHook = new Withdraw4626VaultHook(address(superRegistry), address(this));
        vm.label(address(withdraw4626VaultHook), "Withdraw4626VaultHook");
        vm.makePersistent(address(withdraw4626VaultHook));

        deposit5115VaultHook = new Deposit5115VaultHook(address(superRegistry), address(this));
        vm.label(address(deposit5115VaultHook), "Deposit5115VaultHook");
        vm.makePersistent(address(deposit5115VaultHook));

        withdraw5115VaultHook = new Withdraw5115VaultHook(address(superRegistry), address(this));
        vm.label(address(withdraw5115VaultHook), "Withdraw5115VaultHook");
        vm.makePersistent(address(withdraw5115VaultHook));

        requestDeposit7540VaultHook = new RequestDeposit7540VaultHook(address(superRegistry), address(this));
        vm.label(address(requestDeposit7540VaultHook), "RequestDeposit7540VaultHook");
        vm.makePersistent(address(requestDeposit7540VaultHook));

        requestWithdraw7540VaultHook = new RequestWithdraw7540VaultHook(address(superRegistry), address(this));
        vm.label(address(requestWithdraw7540VaultHook), "RequestWithdraw7540VaultHook");
        vm.makePersistent(address(requestWithdraw7540VaultHook));

        acrossExecuteOnDestinationHook =
            new AcrossExecuteOnDestinationHook(address(superRegistry), address(this), address(spokePoolV3Mock));
        vm.label(address(acrossExecuteOnDestinationHook), "AcrossExecuteOnDestinationHook");
        vm.makePersistent(address(acrossExecuteOnDestinationHook));

        // action oracles
        depositRedeem4626ActionOracle = new DepositRedeem4626ActionOracle();
        vm.label(address(depositRedeem4626ActionOracle), "DepositRedeem4626ActionOracle");
        vm.makePersistent(address(depositRedeem4626ActionOracle));

        depositRedeem5115ActionOracle = new DepositRedeem5115ActionOracle();
        vm.label(address(depositRedeem5115ActionOracle), "DepositRedeem5115ActionOracle");
        vm.makePersistent(address(depositRedeem5115ActionOracle));
      }
    }
    
    function _deployContracts() internal {
        superRegistry = ISuperRegistry(address(new SuperRegistry(address(this))));
        vm.makePersistent(address(superRegistry));

        sharedState = new SharedState();
        vm.makePersistent(address(sharedState));
        vm.label(address(sharedState), "sharedState");
        sharedStateReader = ISharedStateReader(address(sharedState));
        sharedStateWriter = ISharedStateWriter(address(sharedState));

        superRbac = ISuperRbac(address(new SuperRbac(address(this))));
        vm.label(address(superRbac), "superRbac");
        vm.makePersistent(address(superRbac));

        superActions = ISuperActions(address(new SuperActions(address(superRegistry))));
        vm.label(address(superActions), "superActions");
        vm.makePersistent(address(superActions));

        superPositionSentinel = ISentinel(address(new SuperPositionSentinel(address(superRegistry))));
        vm.label(address(superPositionSentinel), "superPositionSentinel");
        vm.makePersistent(address(superPositionSentinel));

        superExecutor = ISuperExecutorV2(address(new SuperExecutorV2(address(superRegistry))));
        vm.label(address(superExecutor), "superExecutor");
        vm.makePersistent(address(superExecutor));

        superPositionSentinel = ISentinel(address(new SuperPositionSentinel(address(superRegistry))));
        vm.label(address(superPositionSentinel), "superPositionSentinel");
        vm.makePersistent(address(superPositionSentinel));

        spokePoolV3Mock = new SpokePoolV3Mock();
        vm.makePersistent(address(spokePoolV3Mock));

        acrossBridgeGateway = new AcrossBridgeGateway(address(superRegistry), address(spokePoolV3Mock));
        vm.makePersistent(address(acrossBridgeGateway));

        spokePoolV3Mock.setAcrossBridgeGateway(address(acrossBridgeGateway));

        for (uint256 i = 0; i < chainIds.length; ++i) {
          superRegistries[chainIds[i]] = address(superRegistry);
          superRbacAddresses[chainIds[i]] = address(superRbac);
          sharedStatesAddresses[chainIds[i]] = address(sharedState);
          superActionsAddresses[chainIds[i]] = address(superActions);
          superExecutorsAddresses[chainIds[i]] = address(superExecutor);
          superPositionSentinelsAddresses[chainIds[i]] = address(superPositionSentinel);
          spokePoolV3MocksAddresses[chainIds[i]] = address(spokePoolV3Mock);
          acrossBridgeGatewaysAddresses[chainIds[i]] = address(acrossBridgeGateway);
        }
    }

    function _preDeploymentSetup() internal {
        mapping(uint64 => uint256) storage forks = FORKS;
        forks[ARBI] = vm.createFork(ARBITRUM_RPC_URL_QN);
        forks[ETH] = vm.createFork(ETHEREUM_RPC_URL_QN);
        forks[OP] = vm.createFork(OPTIMISM_RPC_URL_QN);
        forks[BASE] = vm.createFork(BASE_RPC_URL_QN);

        mapping(uint64 => string) storage rpcURLs = RPC_URLS;
        rpcURLs[ARBI] = ARBITRUM_RPC_URL_QN;
        rpcURLs[ETH] = ETHEREUM_RPC_URL_QN;
        rpcURLs[OP] = OPTIMISM_RPC_URL_QN;
        rpcURLs[BASE] = BASE_RPC_URL_QN;

        /// @dev setup user accounts
        for (uint256 i = 0; i < chainIds.length; ++i) {
          vm.selectFork(FORKS[chainIds[i]]);
          user1 = _deployAccount(USER1_KEY, "USER1");
          vm.makePersistent(user1);
          user2 = _deployAccount(USER2_KEY, "USER2");
          vm.makePersistent(user2);
          SUPER_ACTIONS_CONFIGURATOR = _deployAccount(SUPER_ACTIONS_CONFIGURATOR_KEY, "SUPER_ACTIONS_CONFIGURATOR");
          vm.makePersistent(SUPER_ACTIONS_CONFIGURATOR);
        }
        

        /// @dev Setup existingUnderlyingTokens
        // Mainnet tokens
        existingUnderlyingTokens[1]["DAI"] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        existingUnderlyingTokens[1]["USDC"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        existingUnderlyingTokens[1]["WETH"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

        // Optimism tokens
        existingUnderlyingTokens[10]["DAI"] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
        existingUnderlyingTokens[10]["USDC"] = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
        existingUnderlyingTokens[10]["WETH"] = 0x4200000000000000000000000000000000000006;

        // Arbitrum tokens
        existingUnderlyingTokens[42_161]["DAI"] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
        existingUnderlyingTokens[42_161]["USDC"] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
        existingUnderlyingTokens[42_161]["WETH"] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        
        // Base tokens
        existingUnderlyingTokens[8453]["DAI"] = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
        existingUnderlyingTokens[8453]["USDC"] = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        existingUnderlyingTokens[8453]["WETH"] = 0x4200000000000000000000000000000000000006;

        /// @dev Setup realVaultAddresses
        mapping(uint64 chainId => mapping(string vaultKind => 
        mapping (string vaultName => mapping (string underlying => 
        address realVault)))) storage existingVaults = realVaultAddresses;

        /// @dev Ethereum 4626 vault addresses
        existingVaults[1]["ERC4626"]["AaveVault"]["USDC"] = 0x73edDFa87C71ADdC275c2b9890f5c3a8480bC9E6;
        existingVaults[1]["ERC4626"]["FluidVault"]["USDC"] = 0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33;
        existingVaults[1]["ERC4626"]["EulerVault"]["USDC"] = 0x797DD80692c3b2dAdabCe8e30C07fDE5307D48a9;
        existingVaults[1]["ERC4626"]["MorphoVault"]["USDC"] = 0xdd0f28e19C1780eb6396170735D45153D261490d;
        existingVaults[1]["ERC4626"]["YearnDaiYVault"]["DAI"] = 0xdA816459F1AB5631232FE5e97a05BBBb94970c95;

        /// @dev Arbitrum 4626vault addresses
        existingVaults[42_161]["ERC4626"]["GoatUSDC"]["USDC"] = 0x8a1eF3066553275829d1c0F64EE8D5871D5ce9d3;
        existingVaults[42_161]["ERC4626"]["AaveV3ERC4626Reinvest"]["WETH"] = 0xe4c2A17f38FEA3Dcb3bb59CEB0aC0267416806e2;

        // existingVaults[10][1]["DAI"][0] = address(0);
        existingVaults[10]["ERC4626"]["AloeUSDC"]["USDC"] = 0x462654Cc90C9124A406080EadaF0bA349eaA4AF9;
        // existingVaults[10][1]["WETH"][0] = address(0);

        /// @dev Base 4626 vault addresses
        existingVaults[8453]["ERC4626"]["MorphoGauntletUSDCPrime"]["USDC"] = 0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61;
        existingVaults[8453]["ERC4626"]["MorphoGauntletWETHCore"]["WETH"] = 0x6b13c060F13Af1fdB319F52315BbbF3fb1D88844;


        /// @dev 7540 real centrifuge vaults on mainnet
        existingVaults[1]["ERC7540FullyAsync"]["CentrifugeUSDC"]["USDC"] = 0x1d01Ef1997d44206d839b78bA6813f60F1B3A970;

        //mapping(uint64 chainId => mapping(uint256 market => address realVault)) storage erc5115Vaults = ERC5115_VAULTS;
        //mapping(uint64 chainId => mapping(uint256 market => string name)) storage erc5115VaultsNames =
        //    ERC5115_VAULTS_NAMES;
        //mapping(uint64 chainId => uint256 nVaults) storage numberOf5115s = NUMBER_OF_5115S;
        //mapping(uint64 chainId => mapping(address realVault => ChosenAssets chosenAssets)) storage erc5115ChosenAssets =
        //    ERC5115S_CHOSEN_ASSETS;


        /// @dev  pendle ethena - market: SUSDE-MAINNET-SEP2024
        /// sUSDe sUSDe
        // erc5115Vaults[1][0] = 0x4139cDC6345aFFbaC0692b43bed4D059Df3e6d65;
        // erc5115VaultsNames[1][0] = "sUSDe";
        // erc5115ChosenAssets[1][0x4139cDC6345aFFbaC0692b43bed4D059Df3e6d65].assetIn =
        //     0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
        // erc5115ChosenAssets[1][0x4139cDC6345aFFbaC0692b43bed4D059Df3e6d65].assetOut =
        //     0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;

        /// ezETH
        /// @dev pendle renzo - market:  SY ezETH
        // erc5115Vaults[1][1] = 0x22E12A50e3ca49FB183074235cB1db84Fe4C716D;
        // erc5115VaultsNames[1][1] = "ezETH";
        // erc5115ChosenAssets[1][0x22E12A50e3ca49FB183074235cB1db84Fe4C716D].assetIn =
        //     0xbf5495Efe5DB9ce00f80364C8B423567e58d2110;
        // erc5115ChosenAssets[1][0x22E12A50e3ca49FB183074235cB1db84Fe4C716D].assetOut =
        //     0xbf5495Efe5DB9ce00f80364C8B423567e58d2110;

        /// ezETH
        /// @dev pendle aave usdt - market:  SY aUSDT
        // erc5115Vaults[1][2] = 0x8c28D28bAd669afadC37b034A8070D6d7B9dFB74;
        // erc5115VaultsNames[1][2] = "aUSDT";
        // erc5115ChosenAssets[1][0x8c28D28bAd669afadC37b034A8070D6d7B9dFB74].assetIn =
        //     0xdAC17F958D2ee523a2206206994597C13D831ec7;
        // erc5115ChosenAssets[1][0x8c28D28bAd669afadC37b034A8070D6d7B9dFB74].assetOut =
        //     0x23878914EFE38d27C4D67Ab83ed1b93A74D4086a;

        /// wstETH
        /// @dev pendle wrapped st ETH from LDO - market:  SY wstETH
        // erc5115Vaults[10][0] = 0x96A528f4414aC3CcD21342996c93f2EcdEc24286;
        // erc5115VaultsNames[10][0] = "wstETH";
        // erc5115ChosenAssets[10][0x96A528f4414aC3CcD21342996c93f2EcdEc24286].assetIn =
        //     0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb;
        // erc5115ChosenAssets[10][0x96A528f4414aC3CcD21342996c93f2EcdEc24286].assetOut =
        //     0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb;

        /// ezETH
        /// @dev pendle renzo - market: EZETH-BSC-SEP2024
        // erc5115Vaults[56][0] = 0xe49269B5D31299BcE407c8CcCf241274e9A93C9A;
        // erc5115VaultsNames[56][0] = "ezETH";
        // erc5115ChosenAssets[56][0xe49269B5D31299BcE407c8CcCf241274e9A93C9A].assetIn =
        //     0x2416092f143378750bb29b79eD961ab195CcEea5;
        // erc5115ChosenAssets[56][0xe49269B5D31299BcE407c8CcCf241274e9A93C9A].assetOut =
        //     0x2416092f143378750bb29b79eD961ab195CcEea5;

        /// USDC aARBUsdc
        /// @dev pendle aave - market: SY aUSDC
        // erc5115Vaults[42_161][0] = 0x50288c30c37FA1Ec6167a31E575EA8632645dE20;
        // erc5115VaultsNames[42_161][0] = "USDC";
        // erc5115ChosenAssets[42_161][0x50288c30c37FA1Ec6167a31E575EA8632645dE20].assetIn =
        //     0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
        // erc5115ChosenAssets[42_161][0x50288c30c37FA1Ec6167a31E575EA8632645dE20].assetOut =
        //     0x724dc807b04555b71ed48a6896b6F41593b8C637;

        /// wstETH
        /// @dev pendle wrapped st ETH from LDO - market: SY wstETH
        // erc5115Vaults[42_161][1] = 0x80c12D5b6Cc494632Bf11b03F09436c8B61Cc5Df;
        // erc5115VaultsNames[42_161][1] = "wstETH";
        // erc5115ChosenAssets[42_161][0x80c12D5b6Cc494632Bf11b03F09436c8B61Cc5Df].assetIn =
        //     0x5979D7b546E38E414F7E9822514be443A4800529;
        // erc5115ChosenAssets[42_161][0x80c12D5b6Cc494632Bf11b03F09436c8B61Cc5Df].assetOut =
        //     0x5979D7b546E38E414F7E9822514be443A4800529;
    }

    function _fundNativeTokens() internal {
        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);

            uint256 amountDeployer = 1e24;
            uint256 amountUSER = 1e24;

            vm.deal(deployer, amountDeployer);

            vm.deal(user1, amountUSER);
            vm.deal(user2, amountUSER);
            vm.deal(address(instance.account), amountUSER);
        }
    }

    function _fundUnderlyingTokens(uint256 amount) internal {
        for (uint256 j = 0; j < underlyingTokens.length - 1; ++j) {
            for (uint256 i = 0; i < chainIds.length; ++i) {
                vm.selectFork(FORKS[chainIds[i]]);
                address token = existingUnderlyingTokens[chainIds[i]][underlyingTokens[j]];
                deal(token, deployer, 1e18 * amount);
                deal(token, user1, 1e18 * amount);
                deal(token, user2, 1e18 * amount);
                deal(token, address(instance.account), 1e18 * amount);
            }
        }
    }

    function _createDepositActionData(
        address finalTarget,
        address _underlying,
        uint256 amount
    )
        internal
        view
        returns (bytes[] memory hooksData)
    {
        hooksData = new bytes[](2);
        hooksData[0] = abi.encode(_underlying, finalTarget, amount);
        hooksData[1] = abi.encode(finalTarget, instance.account, amount);
    }

    function _createWithdrawActionData(
        address finalTarget,
        uint256 amount
    )
        internal
        view
        returns (bytes[] memory hooksData)
    {
        hooksData = new bytes[](1);
        hooksData[0] = abi.encode(finalTarget, instance.account, instance.account, amount);
    }

    function _createDepositWithdrawActionData(
        address finalTarget,
        address _underlying,
        uint256 amount
    )
        internal
        view
        returns (bytes[] memory hooksData)
    {
        hooksData = new bytes[](3);
        hooksData[0] = abi.encode(_underlying, finalTarget, amount);
        hooksData[1] = abi.encode(finalTarget, instance.account, amount);
        hooksData[2] = abi.encode(finalTarget, instance.account, instance.account, 100);
    }

    function _setSuperRegistryAddresses() internal {
        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);
            superRegistry = ISuperRegistry(superRegistries[chainIds[i]]);
            SuperRegistry(address(superRegistry)).setAddress(superRegistry.SUPER_ACTIONS_ID(), superActionsAddresses[chainIds[i]]);
            SuperRegistry(address(superRegistry)).setAddress(
                superRegistry.SUPER_POSITION_SENTINEL_ID(), superPositionSentinelsAddresses[chainIds[i]]
            );
            SuperRegistry(address(superRegistry)).setAddress(superRegistry.SUPER_RBAC_ID(), superRbacAddresses[chainIds[i]]);
            acrossBridgeGateway = new AcrossBridgeGateway(address(superRegistry), address(spokePoolV3Mock));
            vm.label(address(acrossBridgeGateway), "acrossBridgeGateway");
            spokePoolV3Mock.setAcrossBridgeGateway(address(acrossBridgeGateway));
            SuperRegistry(address(superRegistry)).setAddress(
            superRegistry.ACROSS_GATEWAY_ID(), acrossBridgeGatewaysAddresses[chainIds[i]]
            );
            SuperRegistry(address(superRegistry)).setAddress(superRegistry.SUPER_EXECUTOR_ID(), superExecutorsAddresses[chainIds[i]]);
            SuperRegistry(address(superRegistry)).setAddress(superRegistry.SHARED_STATE_ID(), sharedStatesAddresses[chainIds[i]]);
            SuperRegistry(address(superRegistry)).setAddress(superRegistry.PAYMASTER_ID(), address(0x11111));
        }
    }

    function _setRoles() internal {
        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);
            superRbac.setRole(SUPER_ACTIONS_CONFIGURATOR, superRbac.SUPER_ACTIONS_CONFIGURATOR(), true);
        }
    }

    function _performRegistrations() internal {
        vm.startPrank(SUPER_ACTIONS_CONFIGURATOR);

        // Configure ERC4626 yield source
        ISuperActions.YieldSourceConfig memory erc4626Config = ISuperActions.YieldSourceConfig({
            yieldSourceId: "ERC4626",
            metadataOracle: address(depositRedeem4626ActionOracle),
            actions: new ISuperActions.ActionConfig[](2)
        });

        // Deposit action (approve + deposit)
        address[] memory depositHooks = new address[](2);
        depositHooks[0] = address(approveErc20Hook);
        depositHooks[1] = address(deposit4626VaultHook);

        erc4626Config.actions[0] = ISuperActions.ActionConfig({
            hooks: depositHooks,
            actionType: ISuperActions.ActionType.INFLOW,
            shareDeltaHookIndex: 1 // deposit4626VaultHook provides share delta
         });

        // Withdraw action
        address[] memory withdrawHooks = new address[](1);
        withdrawHooks[0] = address(withdraw4626VaultHook);

        erc4626Config.actions[1] = ISuperActions.ActionConfig({
            hooks: withdrawHooks,
            actionType: ISuperActions.ActionType.OUTFLOW,
            shareDeltaHookIndex: 0 // withdraw4626VaultHook provides share delta
         });

        // Register ERC4626 actions
        uint256[] memory erc4626ActionIds = superActions.registerYieldSourceAndActions(erc4626Config);

        // Store action IDs in mapping
        ACTION["4626_DEPOSIT"] = erc4626ActionIds[0];
        ACTION["4626_WITHDRAW"] = erc4626ActionIds[1];

        // Add to allActions array
        allActions.push(erc4626ActionIds[0]);
        allActions.push(erc4626ActionIds[1]);

        // Log action IDs
        console.log("4626_DEPOSIT", erc4626ActionIds[0]);
        console.log("4626_WITHDRAW", erc4626ActionIds[1]);

        // approve + 4626 deposit + across
        // uses separate register method because yield source is already registered
        /// @dev WARNING: the last 2 hooks here should not be part of this main action (which is really just
        /// 4626_DEPOSIT) TODO
        address[] memory hooks = new address[](4);
        hooks[0] = address(approveErc20Hook);
        hooks[1] = address(deposit4626VaultHook);
        hooks[2] = address(approveErc20Hook);
        hooks[3] = address(acrossExecuteOnDestinationHook);
        ACTION["4626_DEPOSIT_ACROSS"] =
            superActions.registerAction(hooks, "ERC4626", ISuperActions.ActionType.INFLOW, 1);
        allActions.push(ACTION["4626_DEPOSIT_ACROSS"]);
        console.log("4626_DEPOSIT_ACROSS", ACTION["4626_DEPOSIT_ACROSS"]);
        vm.stopPrank();
    }
}