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

    // RBAC ids
    bytes32 public constant ROLES_ID = keccak256("ROLES");

    // chains
    string public constant ETHEREUM_KEY = "Ethereum";
    string public constant OPTIMISM_KEY = "Optimism";
    string public constant BASE_KEY = "Base";

    uint64 public constant ETH = 1;
    uint64 public constant OP = 10;
    uint64 public constant BASE = 8453;

    address public constant ENTRYPOINT_ADDR = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    // rpc
    string public constant ETHEREUM_RPC_URL_KEY = "ETHEREUM_RPC_URL"; // Native token: ETH
    string public constant OPTIMISM_RPC_URL_KEY = "OPTIMISM_RPC_URL"; // Native token: ETH
    string public constant BASE_RPC_URL_KEY = "BASE_RPC_URL"; // Native token: ETH

    // hooks
    string public constant APPROVE_ERC20_HOOK_KEY = "ApproveERC20Hook";
    string public constant DEPOSIT_4626_VAULT_HOOK_KEY = "Deposit4626VaultHook";
    string public constant REDEEM_4626_VAULT_HOOK_KEY = "Redeem4626VaultHook";
    string public constant WITHDRAW_4626_VAULT_HOOK_KEY = "Withdraw4626VaultHook";
    string public constant TRANSFER_ERC20_HOOK_KEY = "TransferERC20Hook";
    string public constant DEPOSIT_5115_VAULT_HOOK_KEY = "Deposit5115VaultHook";
    string public constant WITHDRAW_5115_VAULT_HOOK_KEY = "Withdraw5115VaultHook";
    string public constant REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY = "RequestDeposit7540VaultHook";
    string public constant REQUEST_WITHDRAW_7540_VAULT_HOOK_KEY = "RequestWithdraw7540VaultHook";
    string public constant DEPOSIT_7540_VAULT_HOOK_KEY = "Deposit7540VaultHook";
    string public constant WITHDRAW_7540_VAULT_HOOK_KEY = "Withdraw7540VaultHook";
    string public constant APPROVE_WITH_PERMIT2_HOOK_KEY = "ApproveWithPermit2Hook";
    string public constant PERMIT_WITH_PERMIT2_HOOK_KEY = "PermitWithPermit2Hook";
    string public constant SWAP_1INCH_CLIPPER_ROUTER_HOOK_KEY = "Swap1InchClipperRouterHook";
    string public constant SWAP_1INCH_GENERIC_ROUTER_HOOK_KEY = "Swap1InchGenericRouterHook";
    string public constant SWAP_1INCH_UNOSWAP_HOOK_KEY = "Swap1InchUnoswapHook";
    string public constant ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY = "AcrossSendFundsAndExecuteOnDstHook";
    string public constant DEBRIDGE_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY = "DeBridgeSendFundsAndExecuteOnDstHook";
    string public constant GEARBOX_STAKE_HOOK_KEY = "GearboxStakeHook";
    string public constant GEARBOX_WITHDRAW_HOOK_KEY = "GearboxWithdrawHook";
    string public constant SOMELIER_STAKE_HOOK_KEY = "SomelierStakeHook";
    string public constant SOMELIER_UNBOND_ALL_HOOK_KEY = "SomelierUnbondAllHook";  
    string public constant SOMELIER_UNBOND_HOOK_KEY = "SomelierUnbondHook";
    string public constant SOMELIER_UNSTAKE_ALL_HOOK_KEY = "SomelierUnstakeAllHook";
    string public constant SOMELIER_UNSTAKE_HOOK_KEY = "SomelierUnstakeHook";
    string public constant YEARN_CLAIM_ONE_REWARD_HOOK_KEY = "YearnClaimOneRewardHook";
    string public constant YEARN_CLAIM_ALL_REWARDS_HOOK_KEY = "YearnClaimAllRewardsHook";


    // contracts
    string public constant ACROSS_V3_HELPER_KEY = "AcrossV3Helper";
    string public constant DEBRIDGE_HELPER_KEY = "DebridgeHelper";
    string public constant SUPER_REGISTRY_KEY = "SuperRegistry";
    string public constant SUPER_RBAC_KEY = "SuperRbac";
    string public constant SUPER_LEDGER_KEY = "SuperLedger";
    string public constant SUPER_POSITION_SENTINEL_KEY = "SuperPositionSentinel";
    string public constant SUPER_EXECUTOR_KEY = "SuperExecutor";
    string public constant ACROSS_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_KEY = "AcrossReceiveFundsAndExecuteGateway";
    string public constant DEBRIDGE_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_KEY = "DeBridgeReceiveFundsAndExecuteGateway";
    string public constant SUPER_MERKLE_VALIDATOR_KEY = "SuperMerkleValidator";
    string public constant ERC4626_YIELD_SOURCE_ORACLE_KEY = "ERC4626YieldSourceOracle";
    string public constant ERC5115_YIELD_SOURCE_ORACLE_KEY = "ERC5115YieldSourceOracle";
    string public constant ERC7540_YIELD_SOURCE_ORACLE_KEY = "ERC7540YieldSourceOracle";

    // tokens
    string public constant DAI_KEY = "DAI";
    string public constant USDC_KEY = "USDC";
    string public constant WETH_KEY = "WETH";
    string public constant SUSDE_KEY = "SUSDe";

    address public constant CHAIN_1_DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant CHAIN_1_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant CHAIN_1_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant CHAIN_1_SUSDE = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;

    address public constant CHAIN_10_DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address public constant CHAIN_10_USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
    address public constant CHAIN_10_WETH = 0x4200000000000000000000000000000000000006;

    address public constant CHAIN_8453_DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
    address public constant CHAIN_8453_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant CHAIN_8453_WETH = 0x4200000000000000000000000000000000000006;

    // permit2 
    address public constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    // 1inch
    address public constant ONE_INCH_ROUTER = 0x111111125421cA6dc452d289314280a0f8842A65;

    // vaults
    string public constant ERC4626_VAULT_KEY = "ERC4626";
    string public constant AAVE_VAULT_KEY = "AaveVault";
    string public constant ALOE_USDC_VAULT_KEY = "AloeUSDC";
    string public constant FLUID_VAULT_KEY = "FluidVault";
    string public constant EULER_VAULT_KEY = "EulerVault";
    string public constant MORPHO_VAULT_KEY = "MorphoVault";
    string public constant CENTRIFUGE_USDC_VAULT_KEY = "CentrifugeUSDC";
    string public constant MORPHO_GAUNTLET_USDC_PRIME_KEY = "MorphoGauntletUSDCPrime";
    string public constant MORPHO_GAUNTLET_WETH_CORE_KEY = "MorphoGauntletWETHCore";
    string public constant ERC7540FullyAsync_KEY = "ERC7540FullyAsync";

    address public constant CHAIN_1_AaveVault = 0x73edDFa87C71ADdC275c2b9890f5c3a8480bC9E6;
    address public constant CHAIN_1_FluidVault = 0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33;
    address public constant CHAIN_1_EulerVault = 0x797DD80692c3b2dAdabCe8e30C07fDE5307D48a9;
    address public constant CHAIN_1_MorphoVault = 0xdd0f28e19C1780eb6396170735D45153D261490d;
    address public constant CHAIN_1_CentrifugeUSDC = 0x1d01Ef1997d44206d839b78bA6813f60F1B3A970;
    address public constant CHAIN_1_PendleEthena = 0x4139cDC6345aFFbaC0692b43bed4D059Df3e6d65;
    address public constant CHAIN_10_AloeUSDC = 0x462654Cc90C9124A406080EadaF0bA349eaA4AF9;

    address public constant CHAIN_8453_MorphoGauntletUSDCPrime = 0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61;
    address public constant CHAIN_8453_MorphoGauntletWETHCore = 0x6b13c060F13Af1fdB319F52315BbbF3fb1D88844;

    // bridges
    string public constant DEBRIDGE_GATE_ADDRESS_KEY = "DeBridgeGateAddress";

    address public constant CHAIN_1_SPOKE_POOL_V3_ADDRESS = 0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5;
    address public constant CHAIN_1_DEBRIDGE_GATE_ADDRESS = 0x43dE2d77BF8027e25dBD179B491e8d64f38398aA;
    address public constant CHAIN_1_DEBRIDGE_GATE_ADMIN_ADDRESS = 0x6bec1faF33183e1Bc316984202eCc09d46AC92D5;

    address public constant CHAIN_10_SPOKE_POOL_V3_ADDRESS = 0x6f26Bf09B1C792e3228e5467807a900A503c0281;
    address public constant CHAIN_10_DEBRIDGE_GATE_ADDRESS = 0x43dE2d77BF8027e25dBD179B491e8d64f38398aA;
    address public constant CHAIN_10_DEBRIDGE_GATE_ADMIN_ADDRESS = 0xA52842cD43fA8c4B6660E443194769531d45b265;

    address public constant CHAIN_8453_SPOKE_POOL_V3_ADDRESS = 0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64;
    address public constant CHAIN_8453_DEBRIDGE_GATE_ADDRESS = 0xc1656B63D9EEBa6d114f6bE19565177893e5bCBF;
    address public constant CHAIN_8453_DEBRIDGE_GATE_ADMIN_ADDRESS = 0xF0A9d50F912D64D1105b276526e21881bF48A29e;

    // Nexus
    string public constant NEXUS_ACCOUNT_IMPLEMENTATION_ID = "biconomy.nexus.1.0.0";
    bytes1 constant MODE_VALIDATION = 0x00;
    address public constant CHAIN_1_NEXUS_FACTORY = 0x000000226cada0d8b36034F5D5c06855F59F6F3A;
    address public constant CHAIN_1_NEXUS_BOOTSTRAP = 0x000000F5b753Fdd20C5CA2D7c1210b3Ab1EA5903;

    // Yield sources
}
