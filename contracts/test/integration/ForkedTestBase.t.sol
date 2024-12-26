// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { BaseTest } from "../BaseTest.t.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ForkedTestBase is BaseTest {

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

    address[] public users;
    uint256[] public userKeys;
    uint256 public deployerPrivateKey;

    address public ownerAddress;
    address public deployer = vm.addr(777);

    //address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // bytes32 public salt;
    //mapping(uint256 vaultId => string[] names) public vaultNames;

    mapping(uint64 chainId => mapping(string underlying => address realAddress)) public existingUnderlyingTokens;

    mapping(uint64 chainId => mapping(address realVaultAddress => ChosenAssets chosenAssets)) public chosen5115Assets;
    
    mapping(uint64 chainId => mapping(string vaultKind => 
    mapping(string vaultName => mapping (string underlying => 
    address realVault)))) public realVaultAddresses;

    mapping(uint64 chainId => mapping(bytes32 implementation => address at)) public contracts;

    mapping(string vaultKind => address[] vaults) public vaultsByKind;
    
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
    uint64 public constant SEPOLIA = 11_155_111;

    uint64[] public chainIds = [1, 42_161, 10, 8453, 250, 11_155_111];

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        super.setUp();
        _preDeploymentSetup();
        _fundNativeTokens();
        _fundUnderlyingTokens(1000);
    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function test_test() public {
        assert(true);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _preDeploymentSetup() internal {
        mapping(uint64 => uint256) storage forks = FORKS;
        forks[SEPOLIA] = vm.createFork(SEPOLIA_RPC_URL_QN);
        forks[ARBI] = vm.createFork(ARBITRUM_RPC_URL_QN);
        forks[ETH] = vm.createFork(ETHEREUM_RPC_URL_QN);
        forks[OP] = vm.createFork(OPTIMISM_RPC_URL_QN);
        forks[BASE] = vm.createFork(BASE_RPC_URL_QN);

        mapping(uint64 => string) storage rpcURLs = RPC_URLS;
        rpcURLs[SEPOLIA] = SEPOLIA_RPC_URL_QN;
        rpcURLs[ARBI] = ARBITRUM_RPC_URL_QN;
        rpcURLs[ETH] = ETHEREUM_RPC_URL_QN;
        rpcURLs[OP] = OPTIMISM_RPC_URL_QN;
        rpcURLs[BASE] = BASE_RPC_URL_QN;

        /// @dev setup users
        /// @dev TODO: update with users from BaseTest
        userKeys.push(1);
        userKeys.push(2);
        userKeys.push(3);

        users.push(vm.addr(userKeys[0]));
        users.push(vm.addr(userKeys[1]));
        users.push(vm.addr(userKeys[2]));

        /// @dev Setup existingUnderlyingTokens
        mapping(uint64 chainId => mapping(string underlying => address realAddress)) storage existingTokens = 
        existingUnderlyingTokens;

        // Mainnet tokens
        existingTokens[1]["DAI"] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        existingTokens[1]["USDC"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        existingTokens[1]["WETH"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

        // Optimism tokens
        existingTokens[10]["DAI"] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
        existingTokens[10]["USDC"] = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
        existingTokens[10]["WETH"] = 0x4200000000000000000000000000000000000006;

        // Arbitrum tokens
        existingTokens[42_161]["DAI"] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
        existingTokens[42_161]["USDC"] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
        existingTokens[42_161]["WETH"] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        
        // Base tokens
        existingTokens[8453]["DAI"] = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
        existingTokens[8453]["USDC"] = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        existingTokens[8453]["WETH"] = 0x4200000000000000000000000000000000000006;

        // Sepolia tokens
        existingTokens[11_155_111]["DAI"] = 0x3e622317f8C93f7328350cF0B56d9eD4C620C5d6;
        existingTokens[11_155_111]["USDC"] = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
        existingTokens[11_155_111]["WETH"] = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;

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


        // /// @dev 7540 real centrifuge vaults on mainnet & testnet
        // existingVaults[1][4]["USDC"][0] = 0x1d01Ef1997d44206d839b78bA6813f60F1B3A970;
        // existingVaults[11_155_111][4]["tUSD"][0] = 0x3b33D257E77E018326CCddeCA71cf9350C585A66;

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

            vm.deal(users[0], amountUSER);
            vm.deal(users[1], amountUSER);
            vm.deal(users[2], amountUSER);
        }
    }

    function _fundUnderlyingTokens(uint256 amount) internal {
        for (uint256 j = 0; j < underlyingTokens.length; ++j) {
            for (uint256 i = 0; i < chainIds.length; ++i) {
                vm.selectFork(FORKS[chainIds[i]]);
                address token = existingUnderlyingTokens[chainIds[i]][underlyingTokens[j]];
                ERC20(token).mint(deployer, 1 ether * amount);
                ERC20(token).mint(users[0], 1 ether * amount);
                ERC20(token).mint(users[1], 1 ether * amount);
                ERC20(token).mint(users[2], 1 ether * amount);
            }
        }
    }
}