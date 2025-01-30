// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

abstract contract Constants {
    address public constant ENTRY_POINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;
    
    // chain names
    string public constant ETHEREUM_KEY = "Ethereum";
    string public constant BASE_KEY = "Base";
    string public constant OPTIMISM_KEY = "Optimism";
    string public constant ARBITRUM_KEY = "Arbitrum";
    string public constant SEPOLIA_KEY = "Sepolia";
    string public constant ARB_SEPOLIA_KEY = "Arbitrum_Sepolia";
    string public constant BASE_SEPOLIA_KEY = "Base_Sepolia";
    string public constant OP_SEPOLIA_KEY = "OP_Sepolia";
    string public constant POLYGON_KEY = "Polygon";

    // keys
    string public constant SUPER_REGISTRY_KEY = "SuperRegistry";
    string public constant SUPER_EXECUTOR_KEY = "SuperExecutor";
    string public constant SUPER_RBAC_KEY = "SuperRbac";
    string public constant SUPER_LEDGER_KEY = "SuperLedger";
    string public constant SUPER_POSITION_KEY = "SuperPosition";
    string public constant SUPER_POSITION_SENTINEL_KEY = "SuperPositionSentinel";
    string public constant ACROSS_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_KEY = "AcrossReceiveFundsAndExecuteGateway";
    string public constant DEBRIDGE_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_KEY = "DeBridgeReceiveFundsAndExecuteGateway";
    string public constant MOCK_VALIDATOR_MODULE_KEY = "MockValidatorModule";

    // mainnets
    uint64 public constant MAINNET_CHAIN_ID = 1;
    uint64 public constant BASE_CHAIN_ID = 8453;
    uint64 public constant OPTIMISM_CHAIN_ID = 10;
    uint64 public constant POLYGON_CHAIN_ID = 137;
    uint64 public constant ARBITRUM_CHAIN_ID = 42_161;
    // testnets
    uint64 public constant SEPOLIA_CHAIN_ID = 11_155_111;
    uint64 public constant ARB_SEPOLIA_CHAIN_ID = 421_613;
    uint64 public constant BASE_SEPOLIA_CHAIN_ID = 84_532;
    uint64 public constant OP_SEPOLIA_CHAIN_ID = 11_155_420;

    // Common addresses
    address internal constant SUPER_DEPLOYER = 0x4b38341B1126F45614B26319787CA98aeC1b6f57;
    address internal constant PROD_MULTISIG = 0x76e9b0063546d97A9c2FDbC9682C5FA347B253BA;
    address internal constant TEST_DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    // Across Spoke Pool addresses per chain
    address internal constant ACROSS_SPOKE_POOL_MAINNET = 0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5;
    address internal constant ACROSS_SPOKE_POOL_BASE = 0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64;
    address internal constant ACROSS_SPOKE_POOL_OPTIMISM = 0x6f26Bf09B1C792e3228e5467807a900A503c0281;
    address internal constant ACROSS_SPOKE_POOL_ARB_SEPOLIA = 0x7E63A5f1a8F0B4d0934B2f2327DAED3F6bb2ee75;
    address internal constant ACROSS_SPOKE_POOL_BASE_SEPOLIA = 0x82B564983aE7274c86695917BBf8C99ECb6F0F8F;
    address internal constant ACROSS_SPOKE_POOL_OP_SEPOLIA = 0x4e8E101924eDE233C13e2D8622DC8aED2872d505;

    // DeBridge Gate addresses per chain
    address internal constant DEBRIDGE_GATE_MAINNET = 0x43dE2d77BF8027e25dBD179B491e8d64f38398aA;
    address internal constant DEBRIDGE_GATE_BASE = 0xc1656B63D9EEBa6d114f6bE19565177893e5bCBF;
    address internal constant DEBRIDGE_GATE_OPTIMISM = 0x43dE2d77BF8027e25dBD179B491e8d64f38398aA;
    address internal constant DEBRIDGE_GATE_ARB_SEPOLIA = 0x43dE2d77BF8027e25dBD179B491e8d64f38398aA;
    address internal constant DEBRIDGE_GATE_BASE_SEPOLIA = address(0);
    address internal constant DEBRIDGE_GATE_OP_SEPOLIA = address(0);

    // Hook Keys
    string constant ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY = "AcrossSendFundsAndExecuteOnDstHook";
    string constant DEBRIDGE_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY = "DeBridgeSendFundsAndExecuteOnDstHook";
    string constant FLUID_CLAIM_REWARD_HOOK_KEY = "FluidClaimRewardHook";
    string constant GEARBOX_CLAIM_REWARD_HOOK_KEY = "GearboxClaimRewardHook";
    string constant SOMELIER_CLAIM_ALL_REWARDS_HOOK_KEY = "SomelierClaimAllRewardsHook";
    string constant SOMELIER_CLAIM_ONE_REWARD_HOOK_KEY = "SomelierClaimOneRewardHook";
    string constant YEARN_CLAIM_ALL_REWARDS_HOOK_KEY = "YearnClaimAllRewardsHook";
    string constant YEARN_CLAIM_ONE_REWARD_HOOK_KEY = "YearnClaimOneRewardHook";
    string constant APPROVE_ERC20_HOOK_KEY = "ApproveERC20Hook";
    string constant TRANSFER_ERC20_HOOK_KEY = "TransferERC20Hook";
    string constant DEPOSIT_4626_VAULT_HOOK_KEY = "Deposit4626VaultHook";
    string constant WITHDRAW_4626_VAULT_HOOK_KEY = "Withdraw4626VaultHook";
    string constant DEPOSIT_5115_VAULT_HOOK_KEY = "Deposit5115VaultHook";
    string constant WITHDRAW_5115_VAULT_HOOK_KEY = "Withdraw5115VaultHook";
    string constant REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY = "RequestDeposit7540VaultHook";
    string constant REQUEST_WITHDRAW_7540_VAULT_HOOK_KEY = "RequestWithdraw7540VaultHook";
    string constant GEARBOX_STAKE_HOOK_KEY = "GearboxStakeHook";
    string constant GEARBOX_WITHDRAW_HOOK_KEY = "GearboxWithdrawHook";
    string constant SOMELIER_STAKE_HOOK_KEY = "SomelierStakeHook";
    string constant SOMELIER_UNBOND_ALL_HOOK_KEY = "SomelierUnbondAllHook";
    string constant SOMELIER_UNBOND_HOOK_KEY = "SomelierUnbondHook";
    string constant SOMELIER_UNSTAKE_ALL_HOOK_KEY = "SomelierUnstakeAllHook";
    string constant SOMELIER_UNSTAKE_HOOK_KEY = "SomelierUnstakeHook";
    string constant YEARN_WITHDRAW_HOOK_KEY = "YearnWithdrawHook";
    string constant YIELD_EXIT_HOOK_KEY = "YieldExitHook";

    // oracle keys
    string constant ERC4626_YIELD_SOURCE_ORACLE_KEY = "ERC4626YieldSourceOracle";
    string constant ERC5115_YIELD_SOURCE_ORACLE_KEY = "ERC5115YieldSourceOracle";
}

