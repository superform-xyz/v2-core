// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { Helpers } from "../utils/Helpers.sol";

// Superform interfaces
import { ISuperRbac } from "../../src/interfaces/ISuperRbac.sol";
import { ISentinel } from "../../src/interfaces/sentinel/ISentinel.sol";
import { ISuperRegistry } from "../../src/interfaces/ISuperRegistry.sol";
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { ISuperActions } from "../../src/interfaces/strategies/ISuperActions.sol";

// Superform contracts
import { SuperRbac } from "../../src/settings/SuperRbac.sol";
import { SharedState } from "../../src/state/SharedState.sol";
import { SpokePoolV3Mock } from "../mocks/SpokePoolV3Mock.sol";
import { SuperActions } from "../../src/strategies/SuperActions.sol";
import { SuperRegistry } from "../../src/settings/SuperRegistry.sol";
import { SuperExecutor } from "../../src/executors/SuperExecutor.sol";
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
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, AccountType } from "modulekit/ModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";

struct Addresses {
    ISuperRbac superRbac;
    SharedState sharedState;
    ISuperActions superActions;
    ISuperRegistry superRegistry;
    ISuperExecutor superExecutor;
    ISentinel superPositionSentinel;
    SpokePoolV3Mock spokePoolV3Mock;
    AcrossBridgeGateway acrossBridgeGateway;
    ApproveERC20Hook approveErc20Hook;
    TransferERC20Hook transferErc20Hook;
    Deposit4626VaultHook deposit4626VaultHook;
    Withdraw4626VaultHook withdraw4626VaultHook;
    Deposit5115VaultHook deposit5115VaultHook;
    Withdraw5115VaultHook withdraw5115VaultHook;
    RequestDeposit7540VaultHook requestDeposit7540VaultHook;
    RequestWithdraw7540VaultHook requestWithdraw7540VaultHook;
    AcrossExecuteOnDestinationHook acrossExecuteOnDestinationHook;
    DepositRedeem4626ActionOracle depositRedeem4626ActionOracle;
    DepositRedeem5115ActionOracle depositRedeem5115ActionOracle;
}

contract ForkedTestBase is Helpers, RhinestoneModuleKit {
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

    address public SUPER_ACTIONS_CONFIGURATOR;

    /// @dev mappings
    mapping(bytes32 name => mapping(uint64 chainId => uint256 actionId)) public ACTION;

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

        // Register actions
        _performRegistrations();

        // Fund underlying tokens
        _fundUnderlyingTokens(10_000);
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
            Addresses memory A;
            /// @dev main contracts
            A.superRegistry = ISuperRegistry(address(new SuperRegistry(address(this))));
            vm.label(address(A.superRegistry), "superRegistry");
            contractAddresses[chainIds[i]]["SuperRegistry"] = address(A.superRegistry);

            A.sharedState = new SharedState();
            vm.label(address(A.sharedState), "sharedState");
            contractAddresses[chainIds[i]]["SharedState"] = address(A.sharedState);

            A.superRbac = ISuperRbac(address(new SuperRbac(address(this))));
            vm.label(address(A.superRbac), "superRbac");
            contractAddresses[chainIds[i]]["SuperRbac"] = address(A.superRbac);

            A.superActions = ISuperActions(address(new SuperActions(address(A.superRegistry))));
            vm.label(address(A.superActions), "superActions");
            contractAddresses[chainIds[i]]["SuperActions"] = address(A.superActions);

            A.superPositionSentinel = ISentinel(address(new SuperPositionSentinel(address(A.superRegistry))));
            vm.label(address(A.superPositionSentinel), "superPositionSentinel");
            contractAddresses[chainIds[i]]["SuperPositionSentinel"] = address(A.superPositionSentinel);

            A.superExecutor = ISuperExecutor(address(new SuperExecutor(address(A.superRegistry))));
            vm.label(address(A.superExecutor), "superExecutor");
            contractAddresses[chainIds[i]]["SuperExecutor"] = address(A.superExecutor);

            A.superPositionSentinel = ISentinel(address(new SuperPositionSentinel(address(A.superRegistry))));
            vm.label(address(A.superPositionSentinel), "superPositionSentinel");
            contractAddresses[chainIds[i]]["SuperPositionSentinel"] = address(A.superPositionSentinel);

            A.spokePoolV3Mock = new SpokePoolV3Mock();
            vm.label(address(A.spokePoolV3Mock), "spokePoolV3Mock");
            contractAddresses[chainIds[i]]["SpokePoolV3Mock"] = address(A.spokePoolV3Mock);

            A.acrossBridgeGateway = new AcrossBridgeGateway(address(A.superRegistry), address(A.spokePoolV3Mock));
            vm.label(address(A.acrossBridgeGateway), "acrossBridgeGateway");
            contractAddresses[chainIds[i]]["AcrossBridgeGateway"] = address(A.acrossBridgeGateway);

            A.spokePoolV3Mock.setAcrossBridgeGateway(address(A.acrossBridgeGateway));

            /// @dev action oracles
            A.depositRedeem4626ActionOracle = new DepositRedeem4626ActionOracle();
            vm.label(address(A.depositRedeem4626ActionOracle), "DepositRedeem4626ActionOracle");
            contractAddresses[chainIds[i]]["DepositRedeem4626ActionOracle"] = address(A.depositRedeem4626ActionOracle);

            A.depositRedeem5115ActionOracle = new DepositRedeem5115ActionOracle();
            vm.label(address(A.depositRedeem5115ActionOracle), "DepositRedeem5115ActionOracle");
            contractAddresses[chainIds[i]]["DepositRedeem5115ActionOracle"] = address(A.depositRedeem5115ActionOracle);

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

            A.acrossExecuteOnDestinationHook =
                new AcrossExecuteOnDestinationHook(address(A.superRegistry), address(this), address(A.spokePoolV3Mock));
            vm.label(address(A.acrossExecuteOnDestinationHook), "AcrossExecuteOnDestinationHook");
            hookAddresses[chainIds[i]]["AcrossExecuteOnDestinationHook"] = address(A.acrossExecuteOnDestinationHook);
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

        /// @dev setup user accounts
        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);

            SUPER_ACTIONS_CONFIGURATOR = _deployAccount(SUPER_ACTIONS_CONFIGURATOR_KEY, "SUPER_ACTIONS_CONFIGURATOR");
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

    function _fundUnderlyingTokens(uint256 amount) internal {
        for (uint256 j = 0; j < underlyingTokens.length - 1; ++j) {
            for (uint256 i = 0; i < chainIds.length; ++i) {
                vm.selectFork(FORKS[chainIds[i]]);
                address token = existingUnderlyingTokens[chainIds[i]][underlyingTokens[j]];
                deal(token, accountInstances[chainIds[i]].account, 1e18 * amount);
            }
        }
    }

    function _createDepositActionData(
        address account,
        address yieldSourceAddress,
        address _underlying,
        uint256 amount
    )
        internal
        pure
        returns (bytes[] memory hooksData)
    {
        hooksData = new bytes[](2);
        hooksData[0] = abi.encode(_underlying, yieldSourceAddress, amount);
        hooksData[1] = abi.encode(yieldSourceAddress, account, amount);
    }

    function _createWithdrawActionData(
        address account,
        address yieldSourceAddress,
        uint256 amount
    )
        internal
        pure
        returns (bytes[] memory hooksData)
    {
        hooksData = new bytes[](1);
        hooksData[0] = abi.encode(yieldSourceAddress, account, account, amount);
    }

    function _createDepositWithdrawActionData(
        address account,
        address yieldSourceAddress,
        address _underlying,
        uint256 amount
    )
        internal
        pure
        returns (bytes[] memory hooksData)
    {
        hooksData = new bytes[](3);
        hooksData[0] = abi.encode(_underlying, yieldSourceAddress, amount);
        hooksData[1] = abi.encode(yieldSourceAddress, account, amount);
        hooksData[2] = abi.encode(yieldSourceAddress, account, account, 100);
    }

    function _setSuperRegistryAddresses() internal {
        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);
            ISuperRegistry superRegistry = ISuperRegistry(_getContract(chainIds[i], "SuperRegistry"));
            SuperRegistry(address(superRegistry)).setAddress(
                superRegistry.SUPER_ACTIONS_ID(), _getContract(chainIds[i], "SuperActions")
            );
            SuperRegistry(address(superRegistry)).setAddress(
                superRegistry.SUPER_POSITION_SENTINEL_ID(), _getContract(chainIds[i], "SuperPositionSentinel")
            );
            SuperRegistry(address(superRegistry)).setAddress(
                superRegistry.SUPER_RBAC_ID(), _getContract(chainIds[i], "SuperRbac")
            );

            SpokePoolV3Mock spokePoolV3Mock = SpokePoolV3Mock(_getContract(chainIds[i], "SpokePoolV3Mock"));
            AcrossBridgeGateway acrossBridgeGateway =
                new AcrossBridgeGateway(address(superRegistry), address(spokePoolV3Mock));
            vm.label(address(acrossBridgeGateway), "acrossBridgeGateway");

            spokePoolV3Mock.setAcrossBridgeGateway(address(acrossBridgeGateway));
            SuperRegistry(address(superRegistry)).setAddress(
                superRegistry.ACROSS_GATEWAY_ID(), _getContract(chainIds[i], "AcrossBridgeGateway")
            );
            SuperRegistry(address(superRegistry)).setAddress(
                superRegistry.SUPER_EXECUTOR_ID(), _getContract(chainIds[i], "SuperExecutor")
            );
            SuperRegistry(address(superRegistry)).setAddress(
                superRegistry.SHARED_STATE_ID(), _getContract(chainIds[i], "SharedState")
            );
            SuperRegistry(address(superRegistry)).setAddress(superRegistry.PAYMASTER_ID(), address(0x11111));
        }
    }

    function _setRoles() internal {
        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);
            ISuperRbac superRbac = ISuperRbac(_getContract(chainIds[i], "SuperRbac"));
            superRbac.setRole(SUPER_ACTIONS_CONFIGURATOR, superRbac.SUPER_ACTIONS_CONFIGURATOR(), true);
        }
    }

    function _performRegistrations() internal {
        console.log("Registration");
        for (uint256 i; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);
            vm.startPrank(SUPER_ACTIONS_CONFIGURATOR);
            // Configure ERC4626 yield source
            ISuperActions.YieldSourceConfig memory erc4626Config = ISuperActions.YieldSourceConfig({
                yieldSourceId: "ERC4626",
                metadataOracle: _getContract(chainIds[i], "DepositRedeem4626ActionOracle"),
                actions: new ISuperActions.ActionConfig[](2)
            });

            // Deposit action (approve + deposit)
            address[] memory depositHooks = new address[](2);
            address approveErc20Hook = _getHook(chainIds[i], "ApproveERC20Hook");
            address deposit4626VaultHook = _getHook(chainIds[i], "Deposit4626VaultHook");
            depositHooks[0] = approveErc20Hook;
            depositHooks[1] = deposit4626VaultHook;

            erc4626Config.actions[0] = ISuperActions.ActionConfig({
                hooks: depositHooks,
                actionType: ISuperActions.ActionType.INFLOW,
                shareDeltaHookIndex: 1 // deposit4626VaultHook provides share delta
             });

            // Withdraw action
            address[] memory withdrawHooks = new address[](1);
            address withdraw4626VaultHook = _getHook(chainIds[i], "Withdraw4626VaultHook");
            withdrawHooks[0] = withdraw4626VaultHook;

            erc4626Config.actions[1] = ISuperActions.ActionConfig({
                hooks: withdrawHooks,
                actionType: ISuperActions.ActionType.OUTFLOW,
                shareDeltaHookIndex: 0 // withdraw4626VaultHook provides share delta
             });

            // Register ERC4626 actions
            uint256[] memory erc4626ActionIds =
                ISuperActions(_getContract(chainIds[i], "SuperActions")).registerYieldSourceAndActions(erc4626Config);

            // Store action IDs in mapping
            ACTION["4626_DEPOSIT"][chainIds[i]] = erc4626ActionIds[0];
            ACTION["4626_WITHDRAW"][chainIds[i]] = erc4626ActionIds[1];

            // Log action IDs
            console.log("4626_DEPOSIT", erc4626ActionIds[0]);
            console.log("4626_WITHDRAW", erc4626ActionIds[1]);

            vm.stopPrank();
        }
    }
}
