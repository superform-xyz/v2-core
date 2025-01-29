// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

abstract contract Constants {
    // amounts
    uint256 public constant SMALL = 1 ether;
    uint256 public constant MEDIUM = 5 ether;
    uint256 public constant LARGE = 20 ether;
    uint256 public constant EXTRA_LARGE = 100 ether;

    // keys
    uint256 public constant USER1_KEY = 0x1;
    uint256 public constant USER2_KEY = 0x2;
    uint256 public constant MANAGER_KEY = 0x3;
    uint256 public constant ACROSS_RELAYER_KEY = 0x4;
    // registry
    bytes32 public constant SUPER_ADMIN_ROLE = keccak256("SUPER_ADMIN_ROLE");

    string public constant NEXUS_ACCOUNT_IMPLEMENTATION_ID = "biconomy.nexus.1.0.0";

    // ids
    bytes32 public constant ROLES_ID = keccak256("ROLES");

    uint64 public constant ETH = 1;
    uint64 public constant OP = 10;
    uint64 public constant BASE = 8453;

    address public constant ENTRYPOINT_ADDR = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    address public constant CHAIN_1_NEXUS_FACTORY = 0x000000226cada0d8b36034F5D5c06855F59F6F3A;
    address public constant CHAIN_1_NEXUS_BOOTSTRAP = 0x000000F5b753Fdd20C5CA2D7c1210b3Ab1EA5903;

    address public constant CHAIN_1_DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;   
    address public constant CHAIN_1_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;   
    address public constant CHAIN_1_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;   

    address public constant CHAIN_10_DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;  
    address public constant CHAIN_10_USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;  
    address public constant CHAIN_10_WETH = 0x4200000000000000000000000000000000000006;  

    address public constant CHAIN_8453_DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;  
    address public constant CHAIN_8453_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;  
    address public constant CHAIN_8453_WETH = 0x4200000000000000000000000000000000000006;  

    address public constant CHAIN_1_AaveVault = 0x73edDFa87C71ADdC275c2b9890f5c3a8480bC9E6;
    address public constant CHAIN_1_FluidVault = 0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33;
    address public constant CHAIN_1_EulerVault = 0x797DD80692c3b2dAdabCe8e30C07fDE5307D48a9;
    address public constant CHAIN_1_MorphoVault = 0xdd0f28e19C1780eb6396170735D45153D261490d;
    address public constant CHAIN_1_CentrifugeUSDC = 0x1d01Ef1997d44206d839b78bA6813f60F1B3A970;

    address public constant CHAIN_10_AloeUSDC = 0x462654Cc90C9124A406080EadaF0bA349eaA4AF9;

    address public constant CHAIN_8453_MorphoGauntletUSDCPrime = 0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61;
    address public constant CHAIN_8453_MorphoGauntletWETHCore = 0x6b13c060F13Af1fdB319F52315BbbF3fb1D88844;

    address public constant CHAIN_1_SPOKE_POOL_V3_ADDRESS = 0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5;
    address public constant CHAIN_1_DEBRIDGE_GATE_ADDRESS = 0x43dE2d77BF8027e25dBD179B491e8d64f38398aA;
    address public constant CHAIN_1_DEBRIDGE_GATE_ADMIN_ADDRESS = 0x6bec1faF33183e1Bc316984202eCc09d46AC92D5;

    address public constant CHAIN_10_SPOKE_POOL_V3_ADDRESS = 0x6f26Bf09B1C792e3228e5467807a900A503c0281;
    address public constant CHAIN_10_DEBRIDGE_GATE_ADDRESS = 0x43dE2d77BF8027e25dBD179B491e8d64f38398aA;
    address public constant CHAIN_10_DEBRIDGE_GATE_ADMIN_ADDRESS = 0xA52842cD43fA8c4B6660E443194769531d45b265;

    address public constant CHAIN_8453_SPOKE_POOL_V3_ADDRESS = 0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64;
    address public constant CHAIN_8453_DEBRIDGE_GATE_ADDRESS = 0xc1656B63D9EEBa6d114f6bE19565177893e5bCBF;
    address public constant CHAIN_8453_DEBRIDGE_GATE_ADMIN_ADDRESS = 0xF0A9d50F912D64D1105b276526e21881bF48A29e;
}
