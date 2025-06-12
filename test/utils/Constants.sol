// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

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
    uint256 public constant STRATEGIST_KEY = 0x5;
    uint256 public constant EMERGENCY_ADMIN_KEY = 0x6;
    uint256 public constant FEE_RECIPIENT_KEY = 0x7;
    uint256 public constant TREASURY_KEY = 0x8;
    uint256 public constant SUPER_BUNDLER_KEY = 0x9;
    uint256 public constant BANK_MANAGER_KEY = 0x10;
    uint256 public constant VALIDATOR_KEY = 0x11;

    // RBAC ids
    bytes32 public constant ROLES_ID = keccak256("ROLES");

    // chains
    string public constant ETHEREUM_KEY = "Ethereum";
    string public constant OPTIMISM_KEY = "Optimism";
    string public constant BASE_KEY = "Base";

    uint64 public constant ETH = 1;
    uint64 public constant OP = 10;
    uint64 public constant BASE = 8453;

    uint256 public constant ETH_BLOCK = 21_929_476;
    uint256 public constant OP_BLOCK = 132_481_010;
    uint256 public constant BASE_BLOCK = 26_885_730;

    uint256 public constant ACCOUNT_COUNT = 4; //should be divisible by 2

    address public constant ENTRYPOINT_ADDR = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    // rpc
    string public constant ETHEREUM_RPC_URL_KEY = "ETHEREUM_RPC_URL"; // Native token: ETH
    string public constant OPTIMISM_RPC_URL_KEY = "OPTIMISM_RPC_URL"; // Native token: ETH
    string public constant BASE_RPC_URL_KEY = "BASE_RPC_URL"; // Native token: ETH

    // api keys
    string public constant ONE_INCH_API_KEY = "ONE_INCH_API_KEY";

    // hooks
    string public constant SWAP_ODOS_HOOK_KEY = "SwapOdosHook";
    string public constant MOCK_SWAP_ODOS_HOOK_KEY = "MockSwapOdosHook";
    string public constant MOCK_APPROVE_AND_SWAP_ODOS_HOOK_KEY = "MockApproveAndSwapOdosHook";
    string public constant APPROVE_ERC20_HOOK_KEY = "ApproveERC20Hook";
    string public constant APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY = "ApproveAndDeposit4626VaultHook";
    string public constant DEPOSIT_4626_VAULT_HOOK_KEY = "Deposit4626VaultHook";
    string public constant REDEEM_4626_VAULT_HOOK_KEY = "Redeem4626VaultHook";
    string public constant APPROVE_AND_REDEEM_4626_VAULT_HOOK_KEY = "ApproveAndRedeem4626VaultHook";
    string public constant TRANSFER_ERC20_HOOK_KEY = "TransferERC20Hook";
    string public constant APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY = "ApproveAndDeposit5115VaultHook";
    string public constant APPROVE_AND_REDEEM_5115_VAULT_HOOK_KEY = "ApproveAndRedeem5115VaultHook";
    string public constant DEPOSIT_5115_VAULT_HOOK_KEY = "Deposit5115VaultHook";
    string public constant REDEEM_5115_VAULT_HOOK_KEY = "Redeem5115VaultHook";
    string public constant REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY = "RequestDeposit7540VaultHook";
    string public constant REQUEST_REDEEM_7540_VAULT_HOOK_KEY = "RequestRedeem7540VaultHook";
    string public constant DEPOSIT_7540_VAULT_HOOK_KEY = "Deposit7540VaultHook";
    string public constant WITHDRAW_7540_VAULT_HOOK_KEY = "Withdraw7540VaultHook";
    string public constant APPROVE_AND_WITHDRAW_7540_VAULT_HOOK_KEY = "ApproveAndWithdraw7540VaultHook";
    string public constant APPROVE_AND_REDEEM_7540_VAULT_HOOK_KEY = "ApproveAndRedeem7540VaultHook";
    string public constant CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY = "CancelDepositRequest7540Hook";
    string public constant CANCEL_REDEEM_REQUEST_7540_HOOK_KEY = "CancelRedeemRequest7540Hook";
    string public constant CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY = "ClaimCancelDepositRequest7540Hook";
    string public constant CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY = "ClaimCancelRedeemRequest7540Hook";
    string public constant CANCEL_REDEEM_HOOK_KEY = "CancelRedeemHook";
    string public constant APPROVE_WITH_PERMIT2_HOOK_KEY = "ApproveWithPermit2Hook";
    string public constant PERMIT_WITH_PERMIT2_HOOK_KEY = "PermitWithPermit2Hook";
    string public constant BATCH_TRANSFER_FROM_HOOK_KEY = "BatchTransferFromHook";
    string public constant SWAP_1INCH_HOOK_KEY = "Swap1InchHook";
    string public constant ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY = "AcrossSendFundsAndExecuteOnDstHook";
    string public constant GEARBOX_STAKE_HOOK_KEY = "GearboxStakeHook";
    string public constant GEARBOX_UNSTAKE_HOOK_KEY = "GearboxUnstakeHook";
    string public constant GEARBOX_CLAIM_REWARD_HOOK_KEY = "GearboxClaimRewardHook";
    string public constant FLUID_CLAIM_REWARD_HOOK_KEY = "FluidClaimRewardHook";
    string public constant FLUID_STAKE_HOOK_KEY = "FluidStakeHook";
    string public constant FLUID_UNSTAKE_HOOK_KEY = "FluidUnstakeHook";
    string public constant SOMELIER_STAKE_HOOK_KEY = "SomelierStakeHook";
    string public constant SOMELIER_UNBOND_ALL_HOOK_KEY = "SomelierUnbondAllHook";
    string public constant SOMELIER_UNBOND_HOOK_KEY = "SomelierUnbondHook";
    string public constant SOMELIER_UNSTAKE_ALL_HOOK_KEY = "SomelierUnstakeAllHook";
    string public constant SOMELIER_UNSTAKE_HOOK_KEY = "SomelierUnstakeHook";
    string public constant YEARN_CLAIM_ONE_REWARD_HOOK_KEY = "YearnClaimOneRewardHook";
    string public constant YEARN_CLAIM_ALL_REWARDS_HOOK_KEY = "YearnClaimAllRewardsHook";
    string public constant GEARBOX_APPROVE_AND_STAKE_HOOK_KEY = "GearboxApproveAndStakeHook";
    string public constant APPROVE_AND_SWAP_ODOS_HOOK_KEY = "ApproveAndSwapOdosHook";
    string public constant APPROVE_AND_FLUID_STAKE_HOOK_KEY = "ApproveAndFluidStakeHook";
    string public constant APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY = "ApproveAndRequestDeposit7540VaultHook";
    string public constant ETHENA_COOLDOWN_SHARES_HOOK_KEY = "EthenaCooldownSharesHook";
    string public constant ETHENA_UNSTAKE_HOOK_KEY = "EthenaUnstakeHook";
    string public constant SPECTRA_EXCHANGE_HOOK_KEY = "SpectraExchangeHook";
    string public constant PENDLE_ROUTER_SWAP_HOOK_KEY = "PendleRouterSwapHook";
    string public constant PENDLE_ROUTER_REDEEM_HOOK_KEY = "PendleRouterRedeemHook";
    string public constant MORPHO_BORROW_HOOK_KEY = "MorphoBorrowHook";
    string public constant MORPHO_REPAY_HOOK_KEY = "MorphoRepayHook";
    string public constant MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY = "MorphoRepayAndWithdrawHook";

    // contracts
    string public constant ACROSS_V3_HELPER_KEY = "AcrossV3Helper";
    string public constant DEBRIDGE_HELPER_KEY = "DebridgeHelper";
    string public constant DEBRIDGE_DLN_HELPER_KEY = "DebridgeDlnHelper";
    string public constant DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY = "DeBridgeSendOrderAndExecuteOnDstHook";
    string public constant SUPER_DESTINATION_EXECUTOR_KEY = "SuperDestinationExecutor";
    string public constant SUPER_LEDGER_KEY = "SuperLedger";
    string public constant ERC1155_LEDGER_KEY = "ERC5115Ledger";
    string public constant SUPER_LEDGER_CONFIGURATION_KEY = "SuperLedgerConfiguration";
    string public constant SUPER_EXECUTOR_KEY = "SuperExecutor";
    string public constant SUPER_EXECUTOR_WITH_SP_LOCK_KEY = "SuperExecutorWithSPLock";
    string public constant MOCK_TARGET_EXECUTOR_KEY = "MockTargetExecutor";
    string public constant ACROSS_V3_ADAPTER_KEY = "AcrossV3Adapter";
    string public constant DEBRIDGE_ADAPTER_KEY = "DebridgeAdapter";
    string public constant SUPER_MERKLE_VALIDATOR_KEY = "SuperMerkleValidator";
    string public constant SUPER_DESTINATION_VALIDATOR_KEY = "SuperDestinationValidator";
    string public constant SUPER_ORACLE_KEY = "SuperOracle";
    string public constant ERC4626_YIELD_SOURCE_ORACLE_KEY = "ERC4626YieldSourceOracle";
    string public constant ERC5115_YIELD_SOURCE_ORACLE_KEY = "ERC5115YieldSourceOracle";
    string public constant ERC7540_YIELD_SOURCE_ORACLE_KEY = "ERC7540YieldSourceOracle";
    string public constant STAKING_YIELD_SOURCE_ORACLE_KEY = "StakingYieldSourceOracle";
    string public constant SUPER_GOVERNOR_KEY = "SuperGovernor";
    string public constant SUPER_BANK_KEY = "SuperBank";
    string public constant SUPER_NATIVE_PAYMASTER_KEY = "SuperNativePaymaster";
    string public constant SUPER_GAS_TANK_KEY = "SuperGasTank";

    // tokens
    string public constant DAI_KEY = "DAI";
    string public constant USDC_KEY = "USDC";
    string public constant WETH_KEY = "WETH";
    string public constant SUSDE_KEY = "SUSDe";
    string public constant USDE_KEY = "USDe";
    string public constant USDCe_KEY = "USDCe";
    string public constant GEAR_KEY = "GEAR";
    string public constant WST_ETH_KEY = "wstETH";

    address public constant CHAIN_1_DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant CHAIN_1_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant CHAIN_1_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant CHAIN_1_SUSDE = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address public constant CHAIN_1_USDE = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address public constant CHAIN_1_GEAR = 0xBa3335588D9403515223F109EdC4eB7269a9Ab5D;
    address public constant CHAIN_1_WST_ETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    address public constant CHAIN_10_DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address public constant CHAIN_10_USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
    address public constant CHAIN_10_WETH = 0x4200000000000000000000000000000000000006;
    address public constant CHAIN_10_USDCe = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;

    address public constant CHAIN_8453_DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
    address public constant CHAIN_8453_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant CHAIN_8453_WETH = 0x4200000000000000000000000000000000000006;

    // permit2
    address public constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    // 1inch
    address public constant ONE_INCH_ROUTER = 0x111111125421cA6dc452d289314280a0f8842A65;

    // odos
    address public constant CHAIN_1_ODOS_ROUTER = 0xCf5540fFFCdC3d510B18bFcA6d2b9987b0772559;
    address public constant CHAIN_10_ODOS_ROUTER = 0xCa423977156BB05b13A2BA3b76Bc5419E2fE9680;
    address public constant CHAIN_8453_ODOS_ROUTER = 0x19cEeAd7105607Cd444F5ad10dd51356436095a1;

    // morpho
    string public constant MORPHO_KEY = "Morpho";
    address public constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    // Base USDC-WETH Market Constants
    address public constant MORPHO_IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address public constant MORPHO_ORACLE = 0xD09048c8B568Dbf5f189302beA26c9edABFC4858;

    // vaults
    string public constant ERC4626_VAULT_KEY = "ERC4626";
    string public constant ERC5115_VAULT_KEY = "ERC5115";
    string public constant AAVE_VAULT_KEY = "AaveVault";
    string public constant ALOE_USDC_VAULT_KEY = "AloeUSDC";
    string public constant FLUID_VAULT_KEY = "FluidVault";
    string public constant EULER_VAULT_KEY = "EulerVault";
    string public constant GEARBOX_VAULT_KEY = "GearboxVault";

    string public constant MORPHO_VAULT_KEY = "MorphoVault";
    string public constant CENTRIFUGE_USDC_VAULT_KEY = "CentrifugeUSDC";
    string public constant MORPHO_GAUNTLET_USDC_PRIME_KEY = "MorphoGauntletUSDCPrime";
    string public constant MORPHO_GAUNTLET_WETH_CORE_KEY = "MorphoGauntletWETHCore";
    string public constant AAVE_BASE_WETH = "AaveBaseWeth";
    string public constant ERC7540FullyAsync_KEY = "ERC7540FullyAsync";
    string public constant PENDLE_ETHENA_KEY = "PendleEthena";

    string public constant SUPER_COLLECTIVE_VAULT_KEY = "SUPER_COLLECTIVE_VAULT_KEY";

    string public constant SUPER_GAS_TANK_ID = "SUPER_GAS_TANK_ID";

    address public constant CHAIN_1_AaveVault = 0x73edDFa87C71ADdC275c2b9890f5c3a8480bC9E6;
    address public constant CHAIN_1_FluidVault = 0x490681095ed277B45377d28cA15Ac41d64583048;
    address public constant CHAIN_1_EulerVault = 0x797DD80692c3b2dAdabCe8e30C07fDE5307D48a9;
    address public constant CHAIN_1_MorphoVault = 0xdd0f28e19C1780eb6396170735D45153D261490d;
    address public constant CHAIN_1_CentrifugeUSDC = 0x1d01Ef1997d44206d839b78bA6813f60F1B3A970;
    address public constant CHAIN_1_YearnVault = 0x028eC7330ff87667b6dfb0D94b954c820195336c;
    address public constant CHAIN_1_PendleEthena = 0x3Ee118EFC826d30A29645eAf3b2EaaC9E8320185;
    address public constant CHAIN_1_GearboxVault = 0xda00000035fef4082F78dEF6A8903bee419FbF8E;
    address public constant CHAIN_1_PendleRouter = 0x888888888889758F76e7103c6CbF23ABbF58F946;
    address public constant CHAIN_1_cUSDO = 0xaD55aebc9b8c03FC43cd9f62260391c13c23e7c0;
    address public constant CHAIN_1_USDO = 0x8238884Ec9668Ef77B90C6dfF4D1a9F4F4823BFe;
    address public constant CHAIN_1_PendleSwap = 0x313e7Ef7d52f5C10aC04ebaa4d33CDc68634c212;
    address public constant CHAIN_1_SpectraRouter = 0xD733e545C65d539f588d7c3793147B497403F0d2;
    address public constant CHAIN_1_SpectraPTToken = 0x3b660B2f136FddF98A081439De483D8712c16ca4; // PT-cUSDO
    address public constant CHAIN_1_SPECTRA_PT_IPOR_USDC = 0xf2C5E30fD95A7363583BCAa932Dbe493765BF74f; // PT-IPOR-USDC
    address public constant CHAIN_10_AloeUSDC = 0x462654Cc90C9124A406080EadaF0bA349eaA4AF9;
    address public constant CHAIN_10_PendleRouter = 0x888888888889758F76e7103c6CbF23ABbF58F946;
    address public constant CHAIN_10_PendleSwap = 0x313e7Ef7d52f5C10aC04ebaa4d33CDc68634c212;
    address public constant CHAIN_10_SpectraRouter = 0x7dcDeA738C2765398BaF66e4DbBcD2769F4C00Dc;

    address public constant CHAIN_8453_MorphoGauntletUSDCPrime = 0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61;
    address public constant CHAIN_8453_MorphoGauntletWETHCore = 0x6b13c060F13Af1fdB319F52315BbbF3fb1D88844;
    address public constant CHAIN_8453_AAveBaseWETH = 0x468973e3264F2aEba0417A8f2cD0Ec397E738898;
    address public constant CHAIN_8453_PendleRouter = 0x888888888889758F76e7103c6CbF23ABbF58F946;
    address public constant CHAIN_8453_PendleSwap = 0x313e7Ef7d52f5C10aC04ebaa4d33CDc68634c212;
    address public constant CHAIN_8453_SpectraRouter = 0x0FC2fbd3E8391744426C8bE5228b668481C59532;

    address public constant CHAIN_1_POLYMER_PROVER = 0x441f16587d8a8cACE647352B24E1Aefa55ACEA76;
    address public constant CHAIN_10_POLYMER_PROVER = address(0); // not available
    address public constant CHAIN_8453_POLYMER_PROVER = address(0); // not available

    // staking protocols
    string public constant GEARBOX_STAKING_KEY = "GearboxStaking";

    address public constant CHAIN_1_GearboxStaking = 0x9ef444a6d7F4A5adcd68FD5329aA5240C90E14d2;

    // bridges

    address public constant CHAIN_1_SPOKE_POOL_V3_ADDRESS = 0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5;

    address public constant CHAIN_10_SPOKE_POOL_V3_ADDRESS = 0x6f26Bf09B1C792e3228e5467807a900A503c0281;

    address public constant CHAIN_8453_SPOKE_POOL_V3_ADDRESS = 0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64;

    address public constant DEBRIDGE_DLN_SOURCE_ADDRESS = 0xeF4fB24aD0916217251F553c0596F8Edc630EB66;
    address public constant DEBRIDGE_DLN_DST = 0xE7351Fd770A37282b91D153Ee690B63579D6dd7f;

    // Nexus
    string public constant NEXUS_ACCOUNT_IMPLEMENTATION_ID = "biconomy.nexus.1.0.0";
    bytes1 constant MODE_VALIDATION = 0x00;

    address public constant CHAIN_1_NEXUS_BOOTSTRAP = 0x000000F5b753Fdd20C5CA2D7c1210b3Ab1EA5903;
    address public constant CHAIN_10_NEXUS_BOOTSTRAP = 0x000000F5b753Fdd20C5CA2D7c1210b3Ab1EA5903;
    address public constant CHAIN_8453_NEXUS_BOOTSTRAP = 0x000000F5b753Fdd20C5CA2D7c1210b3Ab1EA5903;

    address public constant CHAIN_1_NEXUS_FACTORY = 0x000000226cada0d8b36034F5D5c06855F59F6F3A;
    address public constant CHAIN_10_NEXUS_FACTORY = 0x000000226cada0d8b36034F5D5c06855F59F6F3A;
    address public constant CHAIN_8453_NEXUS_FACTORY = 0x000000226cada0d8b36034F5D5c06855F59F6F3A;

    // periphery
    string public constant SUPER_VAULT_AGGREGATOR_KEY = "SUPER_VAULT_AGGREGATOR";
    string public constant SUPER_VAULT_REGISTRY_KEY = "SUPER_VAULT_REGISTRY";
    string public constant SUPER_VAULT_FACTORY_KEY = "SUPER_VAULT_FACTORY";
    string public constant HOOK_FACTORY_KEY = "HOOK_FACTORY";
    string public constant ECDSAPPS_ORACLE_KEY = "ECDSAPPS_ORACLE";
}
