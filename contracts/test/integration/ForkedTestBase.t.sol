// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { BaseTest } from "../BaseTest.t.sol";

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

    string[] public underlyingTokens = ["DAI", "USDC", "WETH", "ETH"];

    uint256 public deployerPrivateKey;

    address[] public users;
    uint256[] public userKeys;

    address public ownerAddress;
    address public deployer = vm.addr(777);

    //address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // bytes32 public salt;
    mapping(uint64 chainId => uint256 n4626Vaults) public numberOf4626Vaults;
    mapping(uint64 chainId => uint256 n5115Vaults) public numberOf5115Vaults;

    mapping(uint64 chainId => mapping(string underlying => address realAddress)) public existingUnderlyingTokens;

    mapping(uint64 chainId => mapping(address realVaultAddress => ChosenAssets chosenAssets)) public chosen5115Assets;
    
    mapping(uint64 chainId => mapping(string vaultName =>  address realVault)) public realVaultAddresses;

    mapping(uint64 chainId => mapping(bytes32 implementation => address at)) public contracts;

    mapping(string vaultKind => address[] vaults) public vaultsByKind;
    //mapping(uint256 vaultKindIndex => string vaultKind) public vaultKinds;
    
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

    function _preDeploymentSetup(bool pinnedBlock) internal {
        mapping(uint64 => uint256) storage forks = FORKS;
        for (uint256 i = 0; i < chainIds.length; i++) {
            selectedChainIds[chainIds[i]] = true;
        }

        forks[ETH] = selectedChainIds[ETH] = createFork(ETHEREUM_RPC_URL_QN);
        forks[ARBI] = selectedChainIds[ARBI] = createFork(ARBITRUM_RPC_URL_QN);
        forks[OP] = selectedChainIds[OP] = createFork(OPTIMISM_RPC_URL_QN);
        forks[BASE] = selectedChainIds[BASE] = createFork(BASE_RPC_URL_QN);
        forks[SEPOLIA] = selectedChainIds[SEPOLIA] = createFork(SEPOLIA_RPC_URL_QN);

        mapping(uint64 => string) storage rpcURLs = RPC_URLS;
        rpcURLs[ETH] = ETHEREUM_RPC_URL;
        rpcURLs[ARBI] = ARBITRUM_RPC_URL;
        rpcURLs[OP] = OPTIMISM_RPC_URL;
        rpcURLs[BASE] = BASE_RPC_URL;
        rpcURLs[SEPOLIA] = SEPOLIA_RPC_URL_QN;

        /// @dev setup users
        userKeys.push(1);
        userKeys.push(2);
        userKeys.push(3);

        users.push(vm.addr(userKeys[0]));
        users.push(vm.addr(userKeys[1]));
        users.push(vm.addr(userKeys[2]));

        /// @dev populate vaultNames state arg with underlyingTokens + vaultKinds names
        // TODO: update with actual underlyingTokens + vaultKinds
        string[] memory _underlyingTokens = underlyingTokens;
        for (uint256 j = 0; j < _underlyingTokens.length; ++j) {
            vaultNames[j].push(string.concat(underlyingTokens[j], vaultKinds[j]));
        }

        mapping(uint64 chainId => mapping(string underlying => address realAddress)) storage existingTokens =
            existingUnderlyingTokens;

        existingTokens[42_161]["DAI"] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
        existingTokens[42_161]["USDC"] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
        existingTokens[42_161]["WETH"] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        existingTokens[42_161]["wstETH"] = 0x5979D7b546E38E414F7E9822514be443A4800529;

        existingTokens[10]["DAI"] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
        existingTokens[10]["USDC"] = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
        existingTokens[10]["WETH"] = 0x4200000000000000000000000000000000000006;
        existingTokens[10]["wstETH"] = 0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb;

        existingTokens[1]["DAI"] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        existingTokens[1]["USDC"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        existingTokens[1]["WETH"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        existingTokens[1]["sUSDe"] = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;

        existingTokens[8453]["DAI"] = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
        existingTokens[8453]["USDC"] = address(0);
        existingTokens[8453]["WETH"] = address(0);


        existingTokens[11_155_111]["DAI"] = address(0);
        existingTokens[11_155_111]["USDC"] = address(0);
        existingTokens[11_155_111]["WETH"] = address(0);
        existingTokens[11_155_111]["tUSD"] = 0x8503b4452Bf6238cC76CdbEE223b46d7196b1c93;

        existingTokens[80_084]["DAI"] = address(0);
        existingTokens[80_084]["USDC"] = 0xd6D83aF58a19Cd14eF3CF6fe848C9A4d21e5727c;
        existingTokens[80_084]["WETH"] = 0xE28AfD8c634946833e89ee3F122C06d7C537E8A8;

        mapping(
            uint64 chainId
                => mapping(
                    uint32 formImplementationId
                        => mapping(string underlying => mapping(uint256 vaultKindIndex => address realVault))
                )
        ) storage existingVaults = realVaultAddresses;

        existingVaults[42_161][1]["DAI"][0] = address(0);
        existingVaults[42_161][1]["USDC"][0] = address(0);
        existingVaults[42_161][1]["WETH"][0] = 0xe4c2A17f38FEA3Dcb3bb59CEB0aC0267416806e2;

        existingVaults[1][1]["DAI"][0] = address(0);
        existingVaults[1][1]["USDC"][0] = address(0);
        existingVaults[1][1]["WETH"][0] = address(0);
        existingVaults[1][1]["USDe"][0] = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;

        existingVaults[10][1]["DAI"][0] = address(0);
        existingVaults[10][1]["USDC"][0] = address(0);
        existingVaults[10][1]["WETH"][0] = address(0);




        existingVaults[8453][1]["DAI"][0] = 0x88510ced6F82eFd3ddc4599B72ad8ac2fF172043;
        existingVaults[8453][1]["USDC"][0] = address(0);
        existingVaults[8453][1]["WETH"][0] = address(0);

        existingVaults[250][1]["DAI"][0] = address(0);
        existingVaults[250][1]["USDC"][0] = 0xd55C59Da5872DE866e39b1e3Af2065330ea8Acd6;
        existingVaults[250][1]["WETH"][0] = address(0);

        /// @dev 7540 real centrifuge vaults on mainnet & testnet
        existingVaults[1][4]["USDC"][0] = 0x1d01Ef1997d44206d839b78bA6813f60F1B3A970;
        existingVaults[11_155_111][4]["tUSD"][0] = 0x3b33D257E77E018326CCddeCA71cf9350C585A66;

        mapping(uint64 chainId => mapping(uint256 market => address realVault)) storage erc5115Vaults = ERC5115_VAULTS;
        mapping(uint64 chainId => mapping(uint256 market => string name)) storage erc5115VaultsNames =
            ERC5115_VAULTS_NAMES;
        mapping(uint64 chainId => uint256 nVaults) storage numberOf5115s = NUMBER_OF_5115S;
        mapping(uint64 chainId => mapping(address realVault => ChosenAssets chosenAssets)) storage erc5115ChosenAssets =
            ERC5115S_CHOSEN_ASSETS;

        numberOf5115s[1] = 2;
        numberOf5115s[10] = 1;
        numberOf5115s[42_161] = 2;
        numberOf5115s[56] = 1;
        numberOf5115s[8453] = 0;
        numberOf5115s[250] = 0;
        numberOf5115s[137] = 0;
        numberOf5115s[43_114] = 0;

        /// @dev  pendle ethena - market: SUSDE-MAINNET-SEP2024
        /// sUSDe sUSDe
        erc5115Vaults[1][0] = 0x4139cDC6345aFFbaC0692b43bed4D059Df3e6d65;
        erc5115VaultsNames[1][0] = "sUSDe";
        erc5115ChosenAssets[1][0x4139cDC6345aFFbaC0692b43bed4D059Df3e6d65].assetIn =
            0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
        erc5115ChosenAssets[1][0x4139cDC6345aFFbaC0692b43bed4D059Df3e6d65].assetOut =
            0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;

        /// ezETH
        /// @dev pendle renzo - market:  SY ezETH
        erc5115Vaults[1][1] = 0x22E12A50e3ca49FB183074235cB1db84Fe4C716D;
        erc5115VaultsNames[1][1] = "ezETH";
        erc5115ChosenAssets[1][0x22E12A50e3ca49FB183074235cB1db84Fe4C716D].assetIn =
            0xbf5495Efe5DB9ce00f80364C8B423567e58d2110;
        erc5115ChosenAssets[1][0x22E12A50e3ca49FB183074235cB1db84Fe4C716D].assetOut =
            0xbf5495Efe5DB9ce00f80364C8B423567e58d2110;

        /// ezETH
        /// @dev pendle aave usdt - market:  SY aUSDT
        erc5115Vaults[1][2] = 0x8c28D28bAd669afadC37b034A8070D6d7B9dFB74;
        erc5115VaultsNames[1][2] = "aUSDT";
        erc5115ChosenAssets[1][0x8c28D28bAd669afadC37b034A8070D6d7B9dFB74].assetIn =
            0xdAC17F958D2ee523a2206206994597C13D831ec7;
        erc5115ChosenAssets[1][0x8c28D28bAd669afadC37b034A8070D6d7B9dFB74].assetOut =
            0x23878914EFE38d27C4D67Ab83ed1b93A74D4086a;

        /// wstETH
        /// @dev pendle wrapped st ETH from LDO - market:  SY wstETH
        erc5115Vaults[10][0] = 0x96A528f4414aC3CcD21342996c93f2EcdEc24286;
        erc5115VaultsNames[10][0] = "wstETH";
        erc5115ChosenAssets[10][0x96A528f4414aC3CcD21342996c93f2EcdEc24286].assetIn =
            0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb;
        erc5115ChosenAssets[10][0x96A528f4414aC3CcD21342996c93f2EcdEc24286].assetOut =
            0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb;

        /// ezETH
        /// @dev pendle renzo - market: EZETH-BSC-SEP2024
        erc5115Vaults[56][0] = 0xe49269B5D31299BcE407c8CcCf241274e9A93C9A;
        erc5115VaultsNames[56][0] = "ezETH";
        erc5115ChosenAssets[56][0xe49269B5D31299BcE407c8CcCf241274e9A93C9A].assetIn =
            0x2416092f143378750bb29b79eD961ab195CcEea5;
        erc5115ChosenAssets[56][0xe49269B5D31299BcE407c8CcCf241274e9A93C9A].assetOut =
            0x2416092f143378750bb29b79eD961ab195CcEea5;

        /// USDC aARBUsdc
        /// @dev pendle aave - market: SY aUSDC
        erc5115Vaults[42_161][0] = 0x50288c30c37FA1Ec6167a31E575EA8632645dE20;
        erc5115VaultsNames[42_161][0] = "USDC";
        erc5115ChosenAssets[42_161][0x50288c30c37FA1Ec6167a31E575EA8632645dE20].assetIn =
            0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
        erc5115ChosenAssets[42_161][0x50288c30c37FA1Ec6167a31E575EA8632645dE20].assetOut =
            0x724dc807b04555b71ed48a6896b6F41593b8C637;

        /// wstETH
        /// @dev pendle wrapped st ETH from LDO - market: SY wstETH
        erc5115Vaults[42_161][1] = 0x80c12D5b6Cc494632Bf11b03F09436c8B61Cc5Df;
        erc5115VaultsNames[42_161][1] = "wstETH";
        erc5115ChosenAssets[42_161][0x80c12D5b6Cc494632Bf11b03F09436c8B61Cc5Df].assetIn =
            0x5979D7b546E38E414F7E9822514be443A4800529;
        erc5115ChosenAssets[42_161][0x80c12D5b6Cc494632Bf11b03F09436c8B61Cc5Df].assetOut =
            0x5979D7b546E38E414F7E9822514be443A4800529;
    }
}
