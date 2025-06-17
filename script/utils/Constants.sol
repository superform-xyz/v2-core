// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

abstract contract Constants {
    address internal constant ENTRY_POINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;
    string internal constant SUPER_DEPLOYER_KEY = "SuperDeployer";
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
    string internal constant SUPER_GOVERNOR_KEY = "SuperGovernor";
    string internal constant SUPER_EXECUTOR_KEY = "SuperExecutor";
    string internal constant SUPER_DESTINATION_EXECUTOR_KEY = "SuperDestinationExecutor";
    string internal constant ACROSS_V3_ADAPTER_KEY = "AcrossV3Adapter";
    string internal constant DEBRIDGE_ADAPTER_KEY = "DebridgeAdapter";
    string internal constant SUPER_LEDGER_KEY = "SuperLedger";
    string internal constant ERC1155_LEDGER_KEY = "ERC5115Ledger";
    string internal constant SUPER_LEDGER_CONFIGURATION_KEY = "SuperLedgerConfiguration";
    string internal constant SUPER_POSITION_KEY = "SuperPosition";
    string internal constant DEBRIDGE_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_KEY = "DeBridgeReceiveFundsAndExecuteGateway";
    string internal constant SUPER_NATIVE_PAYMASTER_KEY = "SuperNativePaymaster";

    string internal constant SUPER_BUNDLER_ID = "SUPER_BUNDLER_ID";
    string internal constant TREASURY_ID = "TREASURY_ID";
    string internal constant DEBRIDGE_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_ID =
        "DEBRIDGE_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_ID";
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

    // Across Spoke Pool addresses per chain
    address internal constant ACROSS_SPOKE_POOL_MAINNET = 0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5;
    address internal constant ACROSS_SPOKE_POOL_BASE = 0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64;
    address internal constant ACROSS_SPOKE_POOL_OPTIMISM = 0x6f26Bf09B1C792e3228e5467807a900A503c0281;
    address internal constant ACROSS_SPOKE_POOL_SEPOLIA = 0x7E63A5f1a8F0B4d0934B2f2327DAED3F6bb2ee75;
    address internal constant ACROSS_SPOKE_POOL_ARB_SEPOLIA = 0x7E63A5f1a8F0B4d0934B2f2327DAED3F6bb2ee75;
    address internal constant ACROSS_SPOKE_POOL_BASE_SEPOLIA = 0x82B564983aE7274c86695917BBf8C99ECb6F0F8F;
    address internal constant ACROSS_SPOKE_POOL_OP_SEPOLIA = 0x4e8E101924eDE233C13e2D8622DC8aED2872d505;

    // DeBridge Gate addresses per chain
    address internal constant DEBRIDGE_DLN_SRC = 0xeF4fB24aD0916217251F553c0596F8Edc630EB66;
    address internal constant DEBRIDGE_DLN_DST = 0xE7351Fd770A37282b91D153Ee690B63579D6dd7f;

    // 1inch Aggregation Router addresses per chain
    // https://portal.1inch.dev/documentation/contracts/aggregation-protocol/aggregation-introduction
    address internal constant AGGREGATION_ROUTER_MAINNET = 0x111111125434b319222CdBf8C261674aDB56F3ae;
    address internal constant AGGREGATION_ROUTER_BASE = 0x111111125434b319222CdBf8C261674aDB56F3ae; //TODO: not the real
    address internal constant AGGREGATION_ROUTER_OPTIMISM = 0x111111125434b319222CdBf8C261674aDB56F3ae; //TODO: not the
    address internal constant AGGREGATION_ROUTER_SEPOLIA = 0x111111125421cA6dc452d289314280a0f8842A65;
    address internal constant AGGREGATION_ROUTER_ARB_SEPOLIA = 0x111111125421cA6dc452d289314280a0f8842A65;
    address internal constant AGGREGATION_ROUTER_BASE_SEPOLIA = 0x111111125421cA6dc452d289314280a0f8842A65;
    address internal constant AGGREGATION_ROUTER_OP_SEPOLIA = 0x111111125421cA6dc452d289314280a0f8842A65;

    address internal constant OKX_ROUTER_MAINNET = 0x1Ef032a3c471a99CC31578c8007F256D95E89896;
    address internal constant OKX_ROUTER_BASE = 0x6b2C0c7be2048Daa9b5527982C29f48062B34D58;
    address internal constant OKX_ROUTER_OPTIMISM = 0xf332761c673b59B21fF6dfa8adA44d78c12dEF09;
    address internal constant OKX_ROUTER_SEPOLIA = 0x1Ef032a3c471a99CC31578c8007F256D95E89896; //TODO: not real
    address internal constant OKX_ROUTER_ARB_SEPOLIA = 0x1Ef032a3c471a99CC31578c8007F256D95E89896; //TODO: not real
    address internal constant OKX_ROUTER_BASE_SEPOLIA = 0x1Ef032a3c471a99CC31578c8007F256D95E89896; //TODO: not real
    address internal constant OKX_ROUTER_OP_SEPOLIA = 0x1Ef032a3c471a99CC31578c8007F256D95E89896; //TODO: not real

    // Odos Router addresses per chain
    address internal constant ODOS_ROUTER_MAINNET = 0xCf5540fFFCdC3d510B18bFcA6d2b9987b0772559;
    address internal constant ODOS_ROUTER_BASE = 0x19cEeAd7105607Cd444F5ad10dd51356436095a1;
    address internal constant ODOS_ROUTER_OPTIMISM = 0xCa423977156BB05b13A2BA3b76Bc5419E2fE9680;
    address internal constant ODOS_ROUTER_SEPOLIA = address(0x1);
    address internal constant ODOS_ROUTER_ARB_SEPOLIA = address(0x1);
    address internal constant ODOS_ROUTER_BASE_SEPOLIA = address(0x1);
    address internal constant ODOS_ROUTER_OP_SEPOLIA = address(0x1);

    // Spectra Router addresses per chain
    address internal constant SPECTRA_ROUTER_MAINNET = 0xD733e545C65d539f588d7c3793147B497403F0d2;
    address internal constant SPECTRA_ROUTER_BASE = 0x0FC2fbd3E8391744426C8bE5228b668481C59532;
    address internal constant SPECTRA_ROUTER_OPTIMISM = 0x7dcDeA738C2765398BaF66e4DbBcD2769F4C00Dc;
    address internal constant SPECTRA_ROUTER_SEPOLIA = address(0x1);
    address internal constant SPECTRA_ROUTER_ARB_SEPOLIA = address(0x1);
    address internal constant SPECTRA_ROUTER_BASE_SEPOLIA = address(0x1);
    address internal constant SPECTRA_ROUTER_OP_SEPOLIA = address(0x1);

    // Pendle Router addresses per chain
    address internal constant PENDLE_ROUTER_MAINNET = 0x888888888889758F76e7103c6CbF23ABbF58F946;
    address internal constant PENDLE_ROUTER_BASE = 0x888888888889758F76e7103c6CbF23ABbF58F946;
    address internal constant PENDLE_ROUTER_OPTIMISM = 0x888888888889758F76e7103c6CbF23ABbF58F946;
    address internal constant PENDLE_ROUTER_SEPOLIA = address(0x1);
    address internal constant PENDLE_ROUTER_ARB_SEPOLIA = address(0x1);
    address internal constant PENDLE_ROUTER_BASE_SEPOLIA = address(0x1);
    address internal constant PENDLE_ROUTER_OP_SEPOLIA = address(0x1);

    // Nexus Factory addresses per chain
    address internal constant NEXUS_FACTORY_MAINNET = 0x000000226cada0d8b36034F5D5c06855F59F6F3A;
    address internal constant NEXUS_FACTORY_BASE = 0x000000226cada0d8b36034F5D5c06855F59F6F3A;
    address internal constant NEXUS_FACTORY_OPTIMISM = 0x000000226cada0d8b36034F5D5c06855F59F6F3A;
    address internal constant NEXUS_FACTORY_SEPOLIA = 0x000000226cada0d8b36034F5D5c06855F59F6F3A;
    address internal constant NEXUS_FACTORY_ARB_SEPOLIA = 0x000000226cada0d8b36034F5D5c06855F59F6F3A;
    address internal constant NEXUS_FACTORY_BASE_SEPOLIA = 0x000000226cada0d8b36034F5D5c06855F59F6F3A;
    address internal constant NEXUS_FACTORY_OP_SEPOLIA = 0x000000226cada0d8b36034F5D5c06855F59F6F3A;

    // Permit2 addresses per chain
    address internal constant PERMIT2_MAINNET = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address internal constant PERMIT2_BASE = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address internal constant PERMIT2_OPTIMISM = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address internal constant PERMIT2_SEPOLIA = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address internal constant PERMIT2_ARB_SEPOLIA = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address internal constant PERMIT2_BASE_SEPOLIA = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address internal constant PERMIT2_OP_SEPOLIA = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    // Polymer Prover addresses per chain
    address internal constant POLYMER_PROVER_MAINNET = 0x441f16587d8a8cACE647352B24E1Aefa55ACEA76;
    address internal constant POLYMER_PROVER_BASE = 0x441f16587d8a8cACE647352B24E1Aefa55ACEA76; // not available
    address internal constant POLYMER_PROVER_OPTIMISM = 0x441f16587d8a8cACE647352B24E1Aefa55ACEA76; // not available
    address internal constant POLYMER_PROVER_SEPOLIA = 0x441f16587d8a8cACE647352B24E1Aefa55ACEA76; // not available
    address internal constant POLYMER_PROVER_ARB_SEPOLIA = 0x441f16587d8a8cACE647352B24E1Aefa55ACEA76; // not available
    address internal constant POLYMER_PROVER_BASE_SEPOLIA = 0x441f16587d8a8cACE647352B24E1Aefa55ACEA76; // not available
    address internal constant POLYMER_PROVER_OP_SEPOLIA = 0x441f16587d8a8cACE647352B24E1Aefa55ACEA76; // not available

    address public constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    // Hook Keys
    string internal constant ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY = "AcrossSendFundsAndExecuteOnDstHook";
    string internal constant FLUID_CLAIM_REWARD_HOOK_KEY = "FluidClaimRewardHook";
    string internal constant GEARBOX_CLAIM_REWARD_HOOK_KEY = "GearboxClaimRewardHook";
    string internal constant SOMELIER_CLAIM_ALL_REWARDS_HOOK_KEY = "SomelierClaimAllRewardsHook";
    string internal constant SOMELIER_CLAIM_ONE_REWARD_HOOK_KEY = "SomelierClaimOneRewardHook";
    string internal constant YEARN_CLAIM_ALL_REWARDS_HOOK_KEY = "YearnClaimAllRewardsHook";
    string internal constant YEARN_CLAIM_ONE_REWARD_HOOK_KEY = "YearnClaimOneRewardHook";
    string internal constant APPROVE_ERC20_HOOK_KEY = "ApproveERC20Hook";
    string internal constant TRANSFER_ERC20_HOOK_KEY = "TransferERC20Hook";
    string internal constant BATCH_TRANSFER_HOOK_KEY = "BatchTransferHook";
    string internal constant BATCH_TRANSFER_FROM_HOOK_KEY = "BatchTransferFromHook";
    string internal constant DEPOSIT_4626_VAULT_HOOK_KEY = "Deposit4626VaultHook";
    string internal constant REDEEM_4626_VAULT_HOOK_KEY = "Redeem4626VaultHook";
    string internal constant DEPOSIT_5115_VAULT_HOOK_KEY = "Deposit5115VaultHook";
    string internal constant REDEEM_5115_VAULT_HOOK_KEY = "Redeem5115VaultHook";
    string internal constant REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY = "RequestDeposit7540VaultHook";
    string internal constant REQUEST_REDEEM_7540_VAULT_HOOK_KEY = "RequestRedeem7540VaultHook";
    string internal constant GEARBOX_STAKE_HOOK_KEY = "GearboxStakeHook";
    string internal constant GEARBOX_UNSTAKE_HOOK_KEY = "GearboxUnstakeHook";
    string internal constant FLUID_STAKE_HOOK_KEY = "FluidStakeHook";
    string internal constant FLUID_UNSTAKE_HOOK_KEY = "FluidUnstakeHook";
    string internal constant SWAP_OKX_HOOK_KEY = "SwapOkxHook";
    string internal constant SWAP_1INCH_HOOK_KEY = "Swap1InchHook";
    string internal constant SWAP_ODOS_HOOK_KEY = "SwapOdosHook";
    string internal constant APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY = "ApproveAndDeposit4626VaultHook";
    string internal constant APPROVE_AND_SWAP_ODOS_HOOK_KEY = "ApproveAndSwapOdosHook";
    string internal constant APPROVE_AND_FLUID_STAKE_HOOK_KEY = "ApproveAndFluidStakeHook";
    string internal constant APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY = "ApproveAndRequestDeposit7540VaultHook";
    string internal constant APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY = "ApproveAndDeposit5115VaultHook";
    string internal constant GEARBOX_APPROVE_AND_STAKE_HOOK_KEY = "GearboxApproveAndStakeHook";
    string internal constant DEPOSIT_7540_VAULT_HOOK_KEY = "Deposit7540VaultHook";
    string internal constant WITHDRAW_7540_VAULT_HOOK_KEY = "Withdraw7540VaultHook";
    string internal constant APPROVE_AND_REDEEM_4626_VAULT_HOOK_KEY = "ApproveAndRedeem4626VaultHook";
    string internal constant APPROVE_AND_REDEEM_5115_VAULT_HOOK_KEY = "ApproveAndRedeem5115VaultHook";
    string internal constant APPROVE_AND_WITHDRAW_7540_VAULT_HOOK_KEY = "ApproveAndWithdraw7540VaultHook";
    string internal constant APPROVE_AND_REDEEM_7540_VAULT_HOOK_KEY = "ApproveAndRedeem7540VaultHook";
    string internal constant DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY = "DeBridgeSendOrderAndExecuteOnDstHook";
    string internal constant ETHENA_COOLDOWN_SHARES_HOOK_KEY = "EthenaCooldownSharesHook";
    string internal constant ETHENA_UNSTAKE_HOOK_KEY = "EthenaUnstakeHook";
    string internal constant SPECTRA_EXCHANGE_HOOK_KEY = "SpectraExchangeHook";
    string internal constant PENDLE_ROUTER_SWAP_HOOK_KEY = "PendleRouterSwapHook";
    string internal constant MORPHO_BORROW_HOOK_KEY = "MorphoBorrowHook";
    string internal constant MORPHO_REPAY_HOOK_KEY = "MorphoRepayHook";
    string internal constant MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY = "MorphoRepayAndWithdrawHook";
    string internal constant PENDLE_ROUTER_REDEEM_HOOK_KEY = "PendleRouterRedeemHook";
    string internal constant CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY = "CancelDepositRequest7540Hook";
    string internal constant CANCEL_REDEEM_REQUEST_7540_HOOK_KEY = "CancelRedeemRequest7540Hook";
    string internal constant CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY = "ClaimCancelDepositRequest7540Hook";
    string internal constant CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY = "ClaimCancelRedeemRequest7540Hook";
    string internal constant CANCEL_REDEEM_HOOK_KEY = "CancelRedeemHook";
    string internal constant SUPER_VAULT_AGGREGATOR_KEY = "SuperVaultAggregator";
    string internal constant SUPER_VAULT_REGISTRY_KEY = "SuperAssetRegistry";
    string internal constant SUPER_VAULT_FACTORY_KEY = "SuperVaultFactory";
    string internal constant HOOK_FACTORY_KEY = "HookRegistry";
    string internal constant SUPER_MERKLE_VALIDATOR_KEY = "SuperMerkleValidator";
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
