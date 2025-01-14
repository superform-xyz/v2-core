// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { Helpers } from "./utils/Helpers.sol";
import { VmSafe } from "forge-std/Vm.sol";

// Superform interfaces
import { ISuperRbac } from "../src/interfaces/ISuperRbac.sol";
import { ISentinel } from "../src/interfaces/sentinel/ISentinel.sol";
import { ISuperRegistry } from "../src/interfaces/ISuperRegistry.sol";
import { ISuperExecutor } from "../src/interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../src/interfaces/accounting/ISuperLedger.sol";

// Superform contracts
import { SuperRbac } from "../src/settings/SuperRbac.sol";
import { SuperLedger } from "../src/accounting/SuperLedger.sol";
import { SuperRegistry } from "../src/settings/SuperRegistry.sol";
import { SuperExecutor } from "../src/executors/SuperExecutor.sol";
import { SuperMerkleValidator } from "../src/validators/SuperMerkleValidator.sol";
import { AcrossReceiveFundsAndExecuteGateway } from "../src/bridges/AcrossReceiveFundsAndExecuteGateway.sol";
import { IAcrossV3Receiver } from "../src/bridges/interfaces/IAcrossV3Receiver.sol";
import { SuperPositionSentinel } from "../src/sentinels/SuperPositionSentinel.sol";

// hooks

// tokens hooks
// --- erc20
import { ApproveERC20Hook } from "../src/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { TransferERC20Hook } from "../src/hooks/tokens/erc20/TransferERC20Hook.sol";
// vault hooks
// --- erc5115
import { Deposit5115VaultHook } from "../src/hooks/vaults/5115/Deposit5115VaultHook.sol";
import { Withdraw5115VaultHook } from "../src/hooks/vaults/5115/Withdraw5115VaultHook.sol";
// --- erc4626
import { Deposit4626VaultHook } from "../src/hooks/vaults/4626/Deposit4626VaultHook.sol";
import { Withdraw4626VaultHook } from "../src/hooks/vaults/4626/Withdraw4626VaultHook.sol";
// -- erc7540
import { RequestDeposit7540VaultHook } from "../src/hooks/vaults/7540/RequestDeposit7540VaultHook.sol";
import { RequestWithdraw7540VaultHook } from "../src/hooks/vaults/7540/RequestWithdraw7540VaultHook.sol";
// bridges hooks
import { AcrossSendFundsAndExecuteOnDstHook } from "../src/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHook.sol";

// action oracles
import { ERC4626YieldSourceOracle } from "../src/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { ERC5115YieldSourceOracle } from "../src/accounting/oracles/ERC5115YieldSourceOracle.sol";

// external
import { console } from "forge-std/console.sol";
import {
    RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, AccountType, UserOpData
} from "modulekit/ModuleKit.sol";

import { ExecutionReturnData } from "modulekit/test/RhinestoneModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";

import { AcrossV3Helper } from "pigeon/across/AcrossV3Helper.sol";

struct Addresses {
    ISuperRbac superRbac;
    ISuperLedger superLedger;
    ISuperRegistry superRegistry;
    ISuperExecutor superExecutor;
    ISentinel superPositionSentinel;
    AcrossReceiveFundsAndExecuteGateway acrossReceiveFundsAndExecuteGateway;
    ApproveERC20Hook approveErc20Hook;
    TransferERC20Hook transferErc20Hook;
    Deposit4626VaultHook deposit4626VaultHook;
    Withdraw4626VaultHook withdraw4626VaultHook;
    Deposit5115VaultHook deposit5115VaultHook;
    Withdraw5115VaultHook withdraw5115VaultHook;
    RequestDeposit7540VaultHook requestDeposit7540VaultHook;
    RequestWithdraw7540VaultHook requestWithdraw7540VaultHook;
    AcrossSendFundsAndExecuteOnDstHook acrossSendFundsAndExecuteOnDstHook;
    ERC4626YieldSourceOracle erc4626YieldSourceOracle;
    ERC5115YieldSourceOracle erc5115YieldSourceOracle;
    SuperMerkleValidator superMerkleValidator;
}

contract BaseTest is Helpers, RhinestoneModuleKit {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @dev arrays
    uint64 public constant ETH = 1;
    uint64 public constant OP = 10;
    uint64 public constant BASE = 8453;

    uint64[] public chainIds = [ETH, OP, BASE];

    string[] public chainsNames = ["Ethereum", "Optimism", "Base"];

    string[] public underlyingTokens = ["DAI", "USDC", "WETH"];

    address[] public spokePoolV3Addresses = [
        0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5,
        0x6f26Bf09B1C792e3228e5467807a900A503c0281,
        0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64
    ];
    mapping(uint64 chainId => address spokePoolV3Address) public SPOKE_POOL_V3_ADDRESSES;

    /// @dev mappings

    mapping(uint64 chainId => mapping(string underlying => address realAddress)) public existingUnderlyingTokens;

    mapping(
        uint64 chainId
            => mapping(string vaultKind => mapping(string vaultName => mapping(string underlying => address realVault)))
    ) public realVaultAddresses;

    mapping(uint64 chainId => mapping(string contractName => address contractAddress)) public contractAddresses;

    mapping(uint64 chainId => mapping(string hookName => address hook)) public hookAddresses;

    mapping(uint64 chainId => AccountInstance accountInstance) public accountInstances;

    // chainID => FORK
    mapping(uint64 chainId => uint256 fork) public FORKS;

    mapping(uint64 chainId => string forkUrl) public RPC_URLS;

    string public ETHEREUM_RPC_URL_QN = vm.envString("ETHEREUM_RPC_URL_QN"); // Native token: ETH
    string public OPTIMISM_RPC_URL_QN = vm.envString("OPTIMISM_RPC_URL_QN"); // Native token: ETH
    string public BASE_RPC_URL_QN = vm.envString("BASE_RPC_URL_QN"); // Native token: ETH

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        // deploy accounts
        MANAGER = _deployAccount(MANAGER_KEY, "MANAGER");
        ACROSS_RELAYER = _deployAccount(ACROSS_RELAYER_KEY, "ACROSS_RELAYER");
        // Setup forks
        _preDeploymentSetup();

        // Deploy contracts
        _deployContracts();

        // Initialize accounts
        _initializeAccounts();

        // Register on SuperRegistry
        _setSuperRegistryAddresses();

        // Set roles
        _setRoles();

        // Setup SuperLedger
        _setupSuperLedger();

        // Fund underlying tokens
        _fundUSDCTokens(10_000);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _getContract(uint64 chainId, string memory contractName) internal view returns (address) {
        return contractAddresses[chainId][contractName];
    }

    function _getHook(uint64 chainId, string memory hookName) internal view returns (address) {
        return hookAddresses[chainId][hookName];
    }

    function _deployContracts() internal {
        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);

            address acrossV3Helper = address(new AcrossV3Helper());
            vm.allowCheatcodes(acrossV3Helper);
            vm.makePersistent(acrossV3Helper);
            contractAddresses[chainIds[i]]["AcrossV3Helper"] = acrossV3Helper;

            Addresses memory A;
            /// @dev main contracts
            A.superRegistry = ISuperRegistry(address(new SuperRegistry(address(this))));
            vm.label(address(A.superRegistry), "superRegistry");
            contractAddresses[chainIds[i]]["SuperRegistry"] = address(A.superRegistry);

            A.superRbac = ISuperRbac(address(new SuperRbac(address(this))));
            vm.label(address(A.superRbac), "superRbac");
            contractAddresses[chainIds[i]]["SuperRbac"] = address(A.superRbac);

            A.superLedger = ISuperLedger(address(new SuperLedger(address(A.superRegistry))));
            vm.label(address(A.superLedger), "superLedger");
            contractAddresses[chainIds[i]]["SuperLedger"] = address(A.superLedger);

            A.superPositionSentinel = ISentinel(address(new SuperPositionSentinel(address(A.superRegistry))));
            vm.label(address(A.superPositionSentinel), "superPositionSentinel");
            contractAddresses[chainIds[i]]["SuperPositionSentinel"] = address(A.superPositionSentinel);

            A.superExecutor = ISuperExecutor(address(new SuperExecutor(address(A.superRegistry))));
            vm.label(address(A.superExecutor), "superExecutor");
            contractAddresses[chainIds[i]]["SuperExecutor"] = address(A.superExecutor);

            A.superPositionSentinel = ISentinel(address(new SuperPositionSentinel(address(A.superRegistry))));
            vm.label(address(A.superPositionSentinel), "superPositionSentinel");
            contractAddresses[chainIds[i]]["SuperPositionSentinel"] = address(A.superPositionSentinel);

            A.acrossReceiveFundsAndExecuteGateway =
                new AcrossReceiveFundsAndExecuteGateway(address(A.superRegistry), SPOKE_POOL_V3_ADDRESSES[chainIds[i]]);
            vm.label(address(A.acrossReceiveFundsAndExecuteGateway), "acrossReceiveFundsAndExecuteGateway");
            contractAddresses[chainIds[i]]["AcrossReceiveFundsAndExecuteGateway"] =
                address(A.acrossReceiveFundsAndExecuteGateway);

            //A.spokePoolV3Mock.setAcrossBridgeGateway(address(A.acrossBridgeGateway));

            A.superMerkleValidator = new SuperMerkleValidator(address(A.superRegistry));
            vm.label(address(A.superMerkleValidator), "superMerkleValidator");
            contractAddresses[chainIds[i]]["SuperMerkleValidator"] = address(A.superMerkleValidator);

            /// @dev action oracles
            A.erc4626YieldSourceOracle = new ERC4626YieldSourceOracle();
            vm.label(address(A.erc4626YieldSourceOracle), "ERC4626YieldSourceOracle");
            contractAddresses[chainIds[i]]["ERC4626YieldSourceOracle"] = address(A.erc4626YieldSourceOracle);

            A.erc5115YieldSourceOracle = new ERC5115YieldSourceOracle();
            vm.label(address(A.erc5115YieldSourceOracle), "ERC5115YieldSourceOracle");
            contractAddresses[chainIds[i]]["ERC5115YieldSourceOracle"] = address(A.erc5115YieldSourceOracle);

            /// @dev  hooks

            A.approveErc20Hook = new ApproveERC20Hook(address(A.superRegistry), address(this));
            vm.label(address(A.approveErc20Hook), "ApproveERC20Hook");
            hookAddresses[chainIds[i]]["ApproveERC20Hook"] = address(A.approveErc20Hook);

            A.transferErc20Hook = new TransferERC20Hook(address(A.superRegistry), address(this));
            vm.label(address(A.transferErc20Hook), "TransferERC20Hook");
            hookAddresses[chainIds[i]]["TransferERC20Hook"] = address(A.transferErc20Hook);

            A.deposit4626VaultHook = new Deposit4626VaultHook(address(A.superRegistry), address(this));
            vm.label(address(A.deposit4626VaultHook), "Deposit4626VaultHook");
            hookAddresses[chainIds[i]]["Deposit4626VaultHook"] = address(A.deposit4626VaultHook);

            A.withdraw4626VaultHook = new Withdraw4626VaultHook(address(A.superRegistry), address(this));
            vm.label(address(A.withdraw4626VaultHook), "Withdraw4626VaultHook");
            hookAddresses[chainIds[i]]["Withdraw4626VaultHook"] = address(A.withdraw4626VaultHook);

            A.deposit5115VaultHook = new Deposit5115VaultHook(address(A.superRegistry), address(this));
            vm.label(address(A.deposit5115VaultHook), "Deposit5115VaultHook");
            hookAddresses[chainIds[i]]["Deposit5115VaultHook"] = address(A.deposit5115VaultHook);

            A.withdraw5115VaultHook = new Withdraw5115VaultHook(address(A.superRegistry), address(this));
            vm.label(address(A.withdraw5115VaultHook), "Withdraw5115VaultHook");
            hookAddresses[chainIds[i]]["Withdraw5115VaultHook"] = address(A.withdraw5115VaultHook);

            A.requestDeposit7540VaultHook = new RequestDeposit7540VaultHook(address(A.superRegistry), address(this));
            vm.label(address(A.requestDeposit7540VaultHook), "RequestDeposit7540VaultHook");
            hookAddresses[chainIds[i]]["RequestDeposit7540VaultHook"] = address(A.requestDeposit7540VaultHook);

            A.requestWithdraw7540VaultHook = new RequestWithdraw7540VaultHook(address(A.superRegistry), address(this));
            vm.label(address(A.requestWithdraw7540VaultHook), "RequestWithdraw7540VaultHook");
            hookAddresses[chainIds[i]]["RequestWithdraw7540VaultHook"] = address(A.requestWithdraw7540VaultHook);

            A.acrossSendFundsAndExecuteOnDstHook = new AcrossSendFundsAndExecuteOnDstHook(
                address(A.superRegistry), address(this), SPOKE_POOL_V3_ADDRESSES[chainIds[i]]
            );
            vm.label(address(A.acrossSendFundsAndExecuteOnDstHook), "AcrossSendFundsAndExecuteOnDstHook");
            hookAddresses[chainIds[i]]["AcrossSendFundsAndExecuteOnDstHook"] =
                address(A.acrossSendFundsAndExecuteOnDstHook);
        }
    }

    function _initializeAccounts() internal {
        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);

            string memory accountName = "SuperformAccount";
            AccountInstance memory instance = makeAccountInstance(keccak256(abi.encode(accountName)));
            accountInstances[chainIds[i]] = instance;
            instance.installModule({
                moduleTypeId: MODULE_TYPE_EXECUTOR,
                module: _getContract(chainIds[i], "SuperExecutor"),
                data: ""
            });
            vm.label(instance.account, accountName);
        }
    }

    function _preDeploymentSetup() internal {
        mapping(uint64 => uint256) storage forks = FORKS;
        forks[ETH] = vm.createFork(ETHEREUM_RPC_URL_QN);
        forks[OP] = vm.createFork(OPTIMISM_RPC_URL_QN);
        forks[BASE] = vm.createFork(BASE_RPC_URL_QN);

        mapping(uint64 => string) storage rpcURLs = RPC_URLS;
        rpcURLs[ETH] = ETHEREUM_RPC_URL_QN;
        rpcURLs[OP] = OPTIMISM_RPC_URL_QN;
        rpcURLs[BASE] = BASE_RPC_URL_QN;

        mapping(uint64 => address) storage spokePoolV3AddressesMap = SPOKE_POOL_V3_ADDRESSES;
        spokePoolV3AddressesMap[ETH] = spokePoolV3Addresses[0];
        vm.label(spokePoolV3AddressesMap[ETH], "SpokePoolV3ETH");
        spokePoolV3AddressesMap[OP] = spokePoolV3Addresses[1];
        vm.label(spokePoolV3AddressesMap[OP], "SpokePoolV3OP");
        spokePoolV3AddressesMap[BASE] = spokePoolV3Addresses[2];
        vm.label(spokePoolV3AddressesMap[BASE], "SpokePoolV3BASE");

        /// @dev Setup existingUnderlyingTokens
        // Mainnet tokens
        existingUnderlyingTokens[1]["DAI"] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        existingUnderlyingTokens[1]["USDC"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        existingUnderlyingTokens[1]["WETH"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

        // Optimism tokens
        existingUnderlyingTokens[10]["DAI"] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
        existingUnderlyingTokens[10]["USDC"] = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
        existingUnderlyingTokens[10]["WETH"] = 0x4200000000000000000000000000000000000006;

        // Base tokens
        existingUnderlyingTokens[8453]["DAI"] = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
        existingUnderlyingTokens[8453]["USDC"] = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        existingUnderlyingTokens[8453]["WETH"] = 0x4200000000000000000000000000000000000006;

        /// @dev Setup realVaultAddresses
        mapping(
            uint64 chainId
                => mapping(
                    string vaultKind => mapping(string vaultName => mapping(string underlying => address realVault))
                )
        ) storage existingVaults = realVaultAddresses;

        /// @dev Ethereum 4626 vault addresses
        existingVaults[1]["ERC4626"]["AaveVault"]["USDC"] = 0x73edDFa87C71ADdC275c2b9890f5c3a8480bC9E6;
        vm.label(existingVaults[1]["ERC4626"]["AaveVault"]["USDC"], "AaveVault");
        existingVaults[1]["ERC4626"]["FluidVault"]["USDC"] = 0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33;
        vm.label(existingVaults[1]["ERC4626"]["FluidVault"]["USDC"], "FluidVault");
        existingVaults[1]["ERC4626"]["EulerVault"]["USDC"] = 0x797DD80692c3b2dAdabCe8e30C07fDE5307D48a9;
        vm.label(existingVaults[1]["ERC4626"]["EulerVault"]["USDC"], "EulerVault");
        existingVaults[1]["ERC4626"]["MorphoVault"]["USDC"] = 0xdd0f28e19C1780eb6396170735D45153D261490d;
        vm.label(existingVaults[1]["ERC4626"]["MorphoVault"]["USDC"], "MorphoVault");

        /// @dev Optimism 4626vault addresses
        // existingVaults[10][1]["DAI"][0] = address(0);
        existingVaults[10]["ERC4626"]["AloeUSDC"]["USDC"] = 0x462654Cc90C9124A406080EadaF0bA349eaA4AF9;
        vm.label(existingVaults[10]["ERC4626"]["AloeUSDC"]["USDC"], "AloeUSDC");
        // existingVaults[10][1]["WETH"][0] = address(0);

        /// @dev Base 4626 vault addresses
        existingVaults[8453]["ERC4626"]["MorphoGauntletUSDCPrime"]["USDC"] = 0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61;
        vm.label(existingVaults[8453]["ERC4626"]["MorphoGauntletUSDCPrime"]["USDC"], "MorphoGauntletUSDCPrime");
        existingVaults[8453]["ERC4626"]["MorphoGauntletWETHCore"]["WETH"] = 0x6b13c060F13Af1fdB319F52315BbbF3fb1D88844;
        vm.label(existingVaults[8453]["ERC4626"]["MorphoGauntletWETHCore"]["WETH"], "MorphoGauntletWETHCore");

        /// @dev 7540 real centrifuge vaults on mainnet
        existingVaults[1]["ERC7540FullyAsync"]["CentrifugeUSDC"]["USDC"] = 0x1d01Ef1997d44206d839b78bA6813f60F1B3A970;
        vm.label(existingVaults[1]["ERC7540FullyAsync"]["CentrifugeUSDC"]["USDC"], "CentrifugeUSDC");
        //mapping(uint64 chainId => mapping(uint256 market => address realVault)) storage erc5115Vaults =
        // ERC5115_VAULTS;
        //mapping(uint64 chainId => mapping(uint256 market => string name)) storage erc5115VaultsNames =
        //    ERC5115_VAULTS_NAMES;
        //mapping(uint64 chainId => uint256 nVaults) storage numberOf5115s = NUMBER_OF_5115S;
        //mapping(uint64 chainId => mapping(address realVault => ChosenAssets chosenAssets)) storage erc5115ChosenAssets
        // =
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

    function _fundUSDCTokens(uint256 amount) internal {
        for (uint256 j = 0; j < underlyingTokens.length - 1; ++j) {
            for (uint256 i = 0; i < chainIds.length; ++i) {
                vm.selectFork(FORKS[chainIds[i]]);
                if (keccak256(abi.encodePacked(underlyingTokens[j])) == keccak256(abi.encodePacked("USDC"))) {
                    address token = existingUnderlyingTokens[chainIds[i]][underlyingTokens[j]];
                    deal(token, accountInstances[chainIds[i]].account, 1e18 * amount);
                }
            }
        }
    }

    function _setSuperRegistryAddresses() internal {
        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);
            ISuperRegistry superRegistry = ISuperRegistry(_getContract(chainIds[i], "SuperRegistry"));
            SuperRegistry(address(superRegistry)).setAddress(
                superRegistry.SUPER_LEDGER_ID(), _getContract(chainIds[i], "SuperLedger")
            );
            SuperRegistry(address(superRegistry)).setAddress(
                superRegistry.SUPER_POSITION_SENTINEL_ID(), _getContract(chainIds[i], "SuperPositionSentinel")
            );
            SuperRegistry(address(superRegistry)).setAddress(
                superRegistry.SUPER_RBAC_ID(), _getContract(chainIds[i], "SuperRbac")
            );
            SuperRegistry(address(superRegistry)).setAddress(
                superRegistry.ACROSS_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_ID(),
                _getContract(chainIds[i], "AcrossReceiveFundsAndExecuteGateway")
            );
            SuperRegistry(address(superRegistry)).setAddress(
                superRegistry.SUPER_EXECUTOR_ID(), _getContract(chainIds[i], "SuperExecutor")
            );
            SuperRegistry(address(superRegistry)).setAddress(superRegistry.PAYMASTER_ID(), address(0x11111));
            SuperRegistry(address(superRegistry)).setAddress(superRegistry.SUPER_BUNDLER_ID(), address(0x11111));
        }
    }

    function _setRoles() internal {
        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);
            //ISuperRbac superRbac = ISuperRbac(_getContract(chainIds[i], "SuperRbac"));
        }
    }

    function _setupSuperLedger() internal {
        for (uint256 i; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);

            vm.startPrank(MANAGER);
            address[] memory mainHooks = new address[](2);
            mainHooks[0] = _getHook(chainIds[i], "Deposit4626VaultHook");
            mainHooks[1] = _getHook(chainIds[i], "Withdraw4626VaultHook");
            SuperRegistry superRegistry = SuperRegistry(_getContract(chainIds[i], "SuperRegistry"));
            ISuperLedger.HookRegistrationConfig[] memory configs = new ISuperLedger.HookRegistrationConfig[](1);
            configs[0] = ISuperLedger.HookRegistrationConfig({
                mainHooks: mainHooks,
                yieldSourceOracle: _getContract(chainIds[i], "ERC4626YieldSourceOracle"),
                yieldSourceOracleId: bytes32("ERC4626YieldSourceOracle"),
                feePercent: 100,
                vaultShareToken: address(0), // this is auto set because its standardized yield
                feeRecipient: superRegistry.getAddress(superRegistry.PAYMASTER_ID())
            });
            ISuperLedger(_getContract(chainIds[i], "SuperLedger")).setYieldSourceOracles(configs);
            vm.stopPrank();
        }
    }
    /*//////////////////////////////////////////////////////////////
                         HELPERS
    //////////////////////////////////////////////////////////////*/

    modifier addRole(ISuperRbac superRbac, bytes32 role_) {
        superRbac.setRole(address(this), role_, true);
        _;
    }

    modifier addRoleTo(ISuperRbac superRbac, bytes32 role_, address addr_) {
        superRbac.setRole(addr_, role_, true);
        _;
    }

    function _getExecOps(
        AccountInstance memory instance,
        ISuperExecutor superExecutor,
        bytes memory data
    )
        internal
        returns (UserOpData memory)
    {
        return instance.getExecOps(
            address(superExecutor), 0, abi.encodeCall(superExecutor.execute, (data)), address(instance.defaultValidator)
        );
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
        AcrossV3Helper(_getContract(srcChainId, "AcrossV3Helper")).help(
            SPOKE_POOL_V3_ADDRESSES[srcChainId],
            SPOKE_POOL_V3_ADDRESSES[dstChainId],
            ACROSS_RELAYER,
            FORKS[dstChainId],
            dstChainId,
            srcChainId,
            executionData.logs
        );
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

    function _createDepositHookData(
        address receiver,
        bytes32 yieldSourceOracleId,
        address vault,
        uint256 amount,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(receiver, yieldSourceOracleId, vault, amount, usePrevHookAmount);
    }

    function _createWithdrawHookData(
        address receiver,
        bytes32 yieldSourceOracleId,
        address vault,
        address owner,
        uint256 shares,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(receiver, yieldSourceOracleId, vault, owner, shares, usePrevHookAmount);
    }

    function _createAcrossV3ReceiveFundsAndExecuteHookData(
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        uint64 destinationChainId,
        bool usePrevHookAmount,
        address account,
        uint256 intentAmount,
        UserOpData memory userOpData
    )
        internal
        view
        returns (bytes memory hookData)
    {
        bytes memory dstUserOpData = abi.encodePacked(
            account,
            intentAmount,
            userOpData.userOp.sender,
            userOpData.userOp.nonce,
            userOpData.userOp.initCode,
            userOpData.userOp.callData,
            userOpData.userOp.accountGasLimits,
            userOpData.userOp.preVerificationGas,
            userOpData.userOp.gasFees,
            userOpData.userOp.paymasterAndData,
            userOpData.userOp.signature,
            address(userOpData.entrypoint)
        );
        hookData = abi.encodePacked(
            uint256(0),
            _getContract(destinationChainId, "AcrossReceiveFundsAndExecuteGateway"),
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
}
