// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

abstract contract Constants {
    address internal constant ENTRY_POINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    // chain names
    string internal constant ETHEREUM_KEY = "Ethereum";
    string internal constant BASE_KEY = "Base";
    string internal constant OPTIMISM_KEY = "Optimism";
    string internal constant ARBITRUM_KEY = "Arbitrum";
    string internal constant SEPOLIA_KEY = "Sepolia";
    string internal constant ARB_SEPOLIA_KEY = "Arbitrum_Sepolia";
    string internal constant BASE_SEPOLIA_KEY = "Base_Sepolia";
    string internal constant OP_SEPOLIA_KEY = "OP_Sepolia";
    string internal constant POLYGON_KEY = "Polygon";

    // keys
    string internal constant SUPER_REGISTRY_KEY = "SuperRegistry";
    string internal constant SUPER_EXECUTOR_KEY = "SuperExecutor";
    string internal constant SUPER_RBAC_KEY = "SuperRbac";
    string internal constant SUPER_LEDGER_KEY = "SuperLedger";
    string internal constant SUPER_POSITION_KEY = "SuperPosition";
    string internal constant SUPER_POSITION_SENTINEL_KEY = "SuperPositionSentinel";
    string internal constant ACROSS_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_KEY = "AcrossReceiveFundsAndExecuteGateway";
    string internal constant DEBRIDGE_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_KEY = "DeBridgeReceiveFundsAndExecuteGateway";
    string internal constant MOCK_VALIDATOR_MODULE_KEY = "MockValidatorModule";

    // mainnets
    uint64 internal constant MAINNET_CHAIN_ID = 1;
    uint64 internal constant BASE_CHAIN_ID = 8453;
    uint64 internal constant OPTIMISM_CHAIN_ID = 10;
    uint64 internal constant POLYGON_CHAIN_ID = 137;
    uint64 internal constant ARBITRUM_CHAIN_ID = 42_161;
    // testnets
    uint64 internal constant SEPOLIA_CHAIN_ID = 11_155_111;
    uint64 internal constant ARB_SEPOLIA_CHAIN_ID = 421_613;
    uint64 internal constant BASE_SEPOLIA_CHAIN_ID = 84_532;
    uint64 internal constant OP_SEPOLIA_CHAIN_ID = 11_155_420;

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
    string internal constant ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY = "AcrossSendFundsAndExecuteOnDstHook";
    string internal constant DEBRIDGE_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY = "DeBridgeSendFundsAndExecuteOnDstHook";
    string internal constant FLUID_CLAIM_REWARD_HOOK_KEY = "FluidClaimRewardHook";
    string internal constant GEARBOX_CLAIM_REWARD_HOOK_KEY = "GearboxClaimRewardHook";
    string internal constant SOMELIER_CLAIM_ALL_REWARDS_HOOK_KEY = "SomelierClaimAllRewardsHook";
    string internal constant SOMELIER_CLAIM_ONE_REWARD_HOOK_KEY = "SomelierClaimOneRewardHook";
    string internal constant YEARN_CLAIM_ALL_REWARDS_HOOK_KEY = "YearnClaimAllRewardsHook";
    string internal constant YEARN_CLAIM_ONE_REWARD_HOOK_KEY = "YearnClaimOneRewardHook";
    string internal constant APPROVE_ERC20_HOOK_KEY = "ApproveERC20Hook";
    string internal constant TRANSFER_ERC20_HOOK_KEY = "TransferERC20Hook";
    string internal constant DEPOSIT_4626_VAULT_HOOK_KEY = "Deposit4626VaultHook";
    string internal constant WITHDRAW_4626_VAULT_HOOK_KEY = "Withdraw4626VaultHook";
    string internal constant DEPOSIT_5115_VAULT_HOOK_KEY = "Deposit5115VaultHook";
    string internal constant WITHDRAW_5115_VAULT_HOOK_KEY = "Withdraw5115VaultHook";
    string internal constant REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY = "RequestDeposit7540VaultHook";
    string internal constant REQUEST_WITHDRAW_7540_VAULT_HOOK_KEY = "RequestWithdraw7540VaultHook";
    string internal constant GEARBOX_STAKE_HOOK_KEY = "GearboxStakeHook";
    string internal constant GEARBOX_UNSTAKE_HOOK_KEY = "GearboxUnstakeHook";
    string internal constant FLUID_STAKE_HOOK_KEY = "FluidStakeHook";
    string internal constant FLUID_STAKE_WITH_PERMIT_HOOK_KEY = "FluidStakeWithPermitHook";
    string internal constant FLUID_UNSTAKE_HOOK_KEY = "FluidUnstakeHook";

    // oracle keys
    string internal constant ERC4626_YIELD_SOURCE_ORACLE_KEY = "ERC4626YieldSourceOracle";
    string internal constant ERC5115_YIELD_SOURCE_ORACLE_KEY = "ERC5115YieldSourceOracle";
}
