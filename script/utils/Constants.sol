// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.30;

abstract contract Constants {
    address internal constant ENTRY_POINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032; // 0.7

    // chain names
    string internal constant ETHEREUM_KEY = "Ethereum";
    string internal constant BASE_KEY = "Base";
    string internal constant OPTIMISM_KEY = "Optimism";
    string internal constant ARBITRUM_KEY = "Arbitrum";
    string internal constant BNB_KEY = "BNB";
    string internal constant AVALANCHE_KEY = "Avalanche";
    string internal constant SEPOLIA_KEY = "Sepolia";
    string internal constant ARB_SEPOLIA_KEY = "Arbitrum_Sepolia";
    string internal constant BASE_SEPOLIA_KEY = "Base_Sepolia";
    string internal constant OP_SEPOLIA_KEY = "OP_Sepolia";

    // keys
    string internal constant SUPER_GOVERNOR_KEY = "SuperGovernor";
    string internal constant SUPER_EXECUTOR_KEY = "SuperExecutor";
    string internal constant SUPER_DESTINATION_EXECUTOR_KEY = "SuperDestinationExecutor";
    string internal constant ACROSS_V3_ADAPTER_KEY = "AcrossV3Adapter";
    string internal constant DEBRIDGE_ADAPTER_KEY = "DebridgeAdapter";
    string internal constant SUPER_LEDGER_KEY = "SuperLedger";
    string internal constant ERC1155_LEDGER_KEY = "ERC1155Ledger";
    string internal constant FLAT_FEE_LEDGER_KEY = "FlatFeeLedger";
    string internal constant SUPER_LEDGER_CONFIGURATION_KEY = "SuperLedgerConfiguration";
    string internal constant SUPER_POSITION_KEY = "SuperPosition";
    string internal constant DEBRIDGE_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_KEY = "DeBridgeReceiveFundsAndExecuteGateway";
    string internal constant SUPER_NATIVE_PAYMASTER_KEY = "SuperNativePaymaster";
    string internal constant SUPER_SENDER_CREATOR_KEY = "SuperSenderCreator";

    string internal constant SUPER_BUNDLER_ID = "SUPER_BUNDLER_ID";
    string internal constant TREASURY_ID = "TREASURY_ID";
    string internal constant DEBRIDGE_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_ID =
        "DEBRIDGE_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_ID";
    // mainnets
    uint64 internal constant MAINNET_CHAIN_ID = 1;
    uint64 internal constant BASE_CHAIN_ID = 8453;
    uint64 internal constant OPTIMISM_CHAIN_ID = 10;
    uint64 internal constant ARBITRUM_CHAIN_ID = 42_161;
    uint64 internal constant BNB_CHAIN_ID = 56;
    uint64 internal constant POLYGON_CHAIN_ID = 137;
    uint64 internal constant AVALANCHE_CHAIN_ID = 43_114;
    uint64 internal constant UNICHAIN_CHAIN_ID = 130;
    // testnets
    uint64 internal constant SEPOLIA_CHAIN_ID = 11_155_111;
    uint64 internal constant ARB_SEPOLIA_CHAIN_ID = 421_613;
    uint64 internal constant BASE_SEPOLIA_CHAIN_ID = 84_532;
    uint64 internal constant OP_SEPOLIA_CHAIN_ID = 11_155_420;

    // merkle claim reward hook `feePercent`
    uint256 internal constant MERKLE_CLAIM_REWARD_HOOK_FEE_PERCENT = 100; // 0.1%

    // Across Spoke Pool addresses per chain
    address internal constant ACROSS_SPOKE_POOL_MAINNET = 0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5;
    address internal constant ACROSS_SPOKE_POOL_BASE = 0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64;
    address internal constant ACROSS_SPOKE_POOL_OPTIMISM = 0x6f26Bf09B1C792e3228e5467807a900A503c0281;
    address internal constant ACROSS_SPOKE_POOL_ARBITRUM = 0xe35e9842fceaCA96570B734083f4a58e8F7C5f2A;
    address internal constant ACROSS_SPOKE_POOL_BNB = 0x4e8E101924eDE233C13e2D8622DC8aED2872d505;
    address internal constant ACROSS_SPOKE_POOL_POLYGON = 0x9295ee1d8C5b022Be115A2AD3c30C72E34e7F096;
    address internal constant ACROSS_SPOKE_POOL_UNICHAIN = 0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64;

    // DeBridge Gate addresses per chain
    address internal constant DEBRIDGE_DLN_SRC = 0xeF4fB24aD0916217251F553c0596F8Edc630EB66;
    address internal constant DEBRIDGE_DLN_DST = 0xE7351Fd770A37282b91D153Ee690B63579D6dd7f;

    // 1inch Aggregation Router addresses per chain
    // https://portal.1inch.dev/documentation/contracts/aggregation-protocol/aggregation-introduction
    address internal constant AGGREGATION_ROUTER_MAINNET = 0x111111125421cA6dc452d289314280a0f8842A65;
    address internal constant AGGREGATION_ROUTER_BASE = 0x111111125421cA6dc452d289314280a0f8842A65;
    address internal constant AGGREGATION_ROUTER_OPTIMISM = 0x111111125421cA6dc452d289314280a0f8842A65;
    address internal constant AGGREGATION_ROUTER_ARBITRUM = 0x111111125421cA6dc452d289314280a0f8842A65;
    address internal constant AGGREGATION_ROUTER_BNB = 0x111111125421cA6dc452d289314280a0f8842A65;
    address internal constant AGGREGATION_ROUTER_POLYGON = 0x111111125421cA6dc452d289314280a0f8842A65;
    address internal constant AGGREGATION_ROUTER_AVALANCHE = 0x111111125421cA6dc452d289314280a0f8842A65;

    // Odos Router addresses per chain
    address internal constant ODOS_ROUTER_MAINNET = 0xCf5540fFFCdC3d510B18bFcA6d2b9987b0772559;
    address internal constant ODOS_ROUTER_BASE = 0x19cEeAd7105607Cd444F5ad10dd51356436095a1;
    address internal constant ODOS_ROUTER_OPTIMISM = 0xCa423977156BB05b13A2BA3b76Bc5419E2fE9680;
    address internal constant ODOS_ROUTER_ARBITRUM = 0xa669e7A0d4b3e4Fa48af2dE86BD4CD7126Be4e13;
    address internal constant ODOS_ROUTER_BNB = 0x89b8AA89FDd0507a99d334CBe3C808fAFC7d850E;
    address internal constant ODOS_ROUTER_POLYGON = 0x4E3288c9ca110bCC82bf38F09A7b425c095d92Bf;
    address internal constant ODOS_ROUTER_AVALANCHE = 0x88de50B233052e4Fb783d4F6db78Cc34fEa3e9FC;
    address internal constant ODOS_ROUTER_UNICHAIN = 0x6409722F3a1C4486A3b1FE566cBDd5e9D946A1f3;

    // Merkl Distributor addresses per chain
    address internal constant MERKL_DISTRIBUTOR_MAINNET = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;
    address internal constant MERKL_DISTRIBUTOR_BASE = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;
    address internal constant MERKL_DISTRIBUTOR_OPTIMISM = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;
    address internal constant MERKL_DISTRIBUTOR_ARBITRUM = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;
    address internal constant MERKL_DISTRIBUTOR_BNB = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;
    address internal constant MERKL_DISTRIBUTOR_POLYGON = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;
    address internal constant MERKL_DISTRIBUTOR_AVALANCHE = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;
    address internal constant MERKL_DISTRIBUTOR_UNICHAIN = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;

    // Permit2 addresses per chain (Universal standard address)
    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    // Circle Gateway addresses (Universal across all chains)
    address internal constant GATEWAY_WALLET = 0x77777777Dcc4d5A8B6E418Fd04D8997ef11000eE;
    address internal constant GATEWAY_MINTER = 0x2222222d7164433c4C09B0b0D809a9b52C04C205;

    // Hook Keys
    string internal constant ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY = "AcrossSendFundsAndExecuteOnDstHook";
    string internal constant FLUID_CLAIM_REWARD_HOOK_KEY = "FluidClaimRewardHook";
    string internal constant GEARBOX_CLAIM_REWARD_HOOK_KEY = "GearboxClaimRewardHook";
    string internal constant YEARN_CLAIM_ALL_REWARDS_HOOK_KEY = "YearnClaimAllRewardsHook";
    string internal constant YEARN_CLAIM_ONE_REWARD_HOOK_KEY = "YearnClaimOneRewardHook";
    string internal constant APPROVE_ERC20_HOOK_KEY = "ApproveERC20Hook";
    string internal constant TRANSFER_ERC20_HOOK_KEY = "TransferERC20Hook";
    string internal constant BATCH_TRANSFER_HOOK_KEY = "BatchTransferHook";
    string internal constant BATCH_TRANSFER_FROM_HOOK_KEY = "BatchTransferFromHook";
    string internal constant OFFRAMP_TOKENS_HOOK_KEY = "OfframpTokensHook";
    string internal constant MINT_SUPERPOSITIONS_HOOK_KEY = "MintSuperPositionsHook";
    string internal constant DEPOSIT_4626_VAULT_HOOK_KEY = "Deposit4626VaultHook";
    string internal constant REDEEM_4626_VAULT_HOOK_KEY = "Redeem4626VaultHook";
    string internal constant DEPOSIT_5115_VAULT_HOOK_KEY = "Deposit5115VaultHook";
    string internal constant REDEEM_5115_VAULT_HOOK_KEY = "Redeem5115VaultHook";
    string internal constant REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY = "RequestDeposit7540VaultHook";
    string internal constant REDEEM_7540_VAULT_HOOK_KEY = "Redeem7540VaultHook";
    string internal constant REQUEST_REDEEM_7540_VAULT_HOOK_KEY = "RequestRedeem7540VaultHook";
    string internal constant GEARBOX_STAKE_HOOK_KEY = "GearboxStakeHook";
    string internal constant GEARBOX_UNSTAKE_HOOK_KEY = "GearboxUnstakeHook";
    string internal constant FLUID_STAKE_HOOK_KEY = "FluidStakeHook";
    string internal constant FLUID_UNSTAKE_HOOK_KEY = "FluidUnstakeHook";
    string internal constant SWAP_1INCH_HOOK_KEY = "Swap1InchHook";
    string internal constant SWAP_ODOSV2_HOOK_KEY = "SwapOdosV2Hook";
    string internal constant APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY = "ApproveAndDeposit4626VaultHook";
    string internal constant APPROVE_AND_SWAP_ODOSV2_HOOK_KEY = "ApproveAndSwapOdosV2Hook";
    string internal constant APPROVE_AND_FLUID_STAKE_HOOK_KEY = "ApproveAndFluidStakeHook";
    string internal constant APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY = "ApproveAndRequestDeposit7540VaultHook";
    string internal constant APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY = "ApproveAndDeposit5115VaultHook";
    string internal constant GEARBOX_APPROVE_AND_STAKE_HOOK_KEY = "GearboxApproveAndStakeHook";
    string internal constant DEPOSIT_7540_VAULT_HOOK_KEY = "Deposit7540VaultHook";
    string internal constant WITHDRAW_7540_VAULT_HOOK_KEY = "Withdraw7540VaultHook";
    string internal constant DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY = "DeBridgeSendOrderAndExecuteOnDstHook";
    string public constant DEBRIDGE_CANCEL_ORDER_HOOK_KEY = "DeBridgeCancelOrderHook";
    string internal constant ETHENA_COOLDOWN_SHARES_HOOK_KEY = "EthenaCooldownSharesHook";
    string internal constant ETHENA_UNSTAKE_HOOK_KEY = "EthenaUnstakeHook";

    string internal constant MORPHO_BORROW_HOOK_KEY = "MorphoBorrowHook";
    string internal constant MORPHO_REPAY_HOOK_KEY = "MorphoRepayHook";
    string internal constant MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY = "MorphoRepayAndWithdrawHook";
    string internal constant MORPHO_BORROW_ONLY_HOOK_KEY = "MorphoBorrowHook";
    string internal constant MORPHO_SUPPLY_AND_BORROW_HOOK_KEY = "MorphoSupplyAndBorrowHook";
    string internal constant CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY = "CancelDepositRequest7540Hook";
    string internal constant CANCEL_REDEEM_REQUEST_7540_HOOK_KEY = "CancelRedeemRequest7540Hook";
    string internal constant CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY = "ClaimCancelDepositRequest7540Hook";
    string internal constant CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY = "ClaimCancelRedeemRequest7540Hook";
    string internal constant CANCEL_REDEEM_HOOK_KEY = "CancelRedeemHook";
    string internal constant MARK_ROOT_AS_USED_HOOK_KEY = "MarkRootAsUsedHook";
    string internal constant MERKL_CLAIM_REWARD_HOOK_KEY = "MerklClaimRewardHook";

    // Circle Gateway Hook Keys
    string internal constant CIRCLE_GATEWAY_WALLET_HOOK_KEY = "CircleGatewayWalletHook";
    string internal constant CIRCLE_GATEWAY_MINTER_HOOK_KEY = "CircleGatewayMinterHook";
    string internal constant CIRCLE_GATEWAY_ADD_DELEGATE_HOOK_KEY = "CircleGatewayAddDelegateHook";
    string internal constant CIRCLE_GATEWAY_REMOVE_DELEGATE_HOOK_KEY = "CircleGatewayRemoveDelegateHook";

    // Mock hooks (dev environment only)
    string internal constant MOCK_DEX_KEY = "MockDex";
    string internal constant MOCK_DEX_HOOK_KEY = "MockDexHook";

    string internal constant SUPER_VAULT_AGGREGATOR_KEY = "SuperVaultAggregator";
    string internal constant SUPER_VAULT_REGISTRY_KEY = "SuperAssetRegistry";
    string internal constant SUPER_VAULT_FACTORY_KEY = "SuperVaultFactory";
    string internal constant HOOK_FACTORY_KEY = "HookRegistry";
    string internal constant SUPER_VALIDATOR_KEY = "SuperValidator";
    string internal constant SUPER_DESTINATION_VALIDATOR_KEY = "SuperDestinationValidator";
    string internal constant ECDSAPPS_ORACLE_KEY = "ECDSAPPSOracle";
    string internal constant SUPER_YIELD_SOURCE_ORACLE_KEY = "SuperYieldSourceOracle";
    string internal constant SUPER_ORACLE_KEY = "SuperOracle";

    // oracle keys
    string internal constant ERC4626_YIELD_SOURCE_ORACLE_KEY = "ERC4626YieldSourceOracle";
    string internal constant ERC5115_YIELD_SOURCE_ORACLE_KEY = "ERC5115YieldSourceOracle";
    string internal constant ERC7540_YIELD_SOURCE_ORACLE_KEY = "ERC7540YieldSourceOracle";
    string internal constant PENDLE_PT_YIELD_SOURCE_ORACLE_KEY = "PendlePTYieldSourceOracle";
    string internal constant SPECTRA_PT_YIELD_SOURCE_ORACLE_KEY = "SpectraPTYieldSourceOracle";
    string internal constant STAKING_YIELD_SOURCE_ORACLE_KEY = "StakingYieldSourceOracle";
}
