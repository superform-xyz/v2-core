# Production Hook Verification Audit

Date: 2026-07-21

Source: [`script/output/prod/latest.json`](./latest.json)

## Summary

- Hook deployment entries checked: **965**
- Publicly verified: **694**
- Unverified: **271**
- Distinct unverified hook names: **58**
- Explorer/API errors: **0**

Every contract entry whose name ends in `Hook` was checked across all 16 network sections in `latest.json`. Etherscan V2 `getsourcecode` was used where applicable, and Flare Blockscout was used for Flare. During the initial read-only audit, every apparent miss was queried a second time; all 278 remained unverified. Seven subsequently requested hook verifications were submitted and independently confirmed by the explorer status APIs, leaving the totals above.

## Completed Follow-up Verifications

The following previously unverified deployments were publicly verified on 2026-07-21:

### Flare

- `ApproveAndSwapAlgebraIntegralHook`: `0x87E8958d0a2Bd030060fa63852770d5bdA303153`
- `ClaimRFLRV3Hook`: `0x2FAa029F0959D53A4E3B73c41fE2AC524432816d`
- `SwapAlgebraIntegralHook`: `0xF7291FD5Ef4c59bc81314BCf2A1546008edF8F41`

### HyperEVM

- `ApproveAndSwapKyberSwapHook`: `0xcF5419270C9415E44c97E595c505708cfA334C30`
- `ApproveAndSwapUniswapV3Hook`: `0xbC4E2d35F616592FEF5B91CD87E617505855eceB`
- `SwapKyberSwapHook`: `0x05c49e05bb8575afdf1142cC95dA6747b069174A`
- `SwapUniswapV3Hook`: `0x650df1F828203224A262f047AcA2D03ADc59fD08`

## Unverified Hooks by Network Set

### All 16 production networks

- `ApproveAndCCTPSendHook`
- `CCTPSendHook`
- `ClaimFailedTransferHook`
- `Withdraw7540VaultHook`

### Ethereum, Optimism, Flare, BNB, Unichain, Polygon, Stable, HyperEVM, Base, Arbitrum, and Avalanche

- `ApproveERC20Hook`
- `BatchTransferFromHook`
- `BatchTransferHook`
- `OfframpTokensHook`
- `TransferERC20Hook`
- `TransferHook`

### Optimism, Gnosis, Unichain, Polygon, Sonic, Worldchain, Stable, HyperEVM, Linea, and Berachain

- `ApproveAndStargateSendHook`
- `StargateSendHook`

### Ethereum, Optimism, BNB, Unichain, Polygon, Stable, HyperEVM, Base, Arbitrum, and Avalanche

- `MerklClaimRewardHook`

### Ethereum, Optimism, BNB, Polygon, Sonic, Base, Arbitrum, Avalanche, and Linea

- `ApproveAndSwapOdosV3Hook`
- `SwapOdosV3Hook`

### Ethereum, Optimism, BNB, Sonic, HyperEVM, Base, Arbitrum, and Berachain

- `PendleRouterRedeemHook`
- `PendleUnifiedHook`

### Optimism, Unichain, Polygon, Worldchain, Stable, and Linea

- `ApproveAndSwapUniswapV3Router02Hook`
- `SwapUniswapV3Router02Hook`

### Optimism, Unichain, Polygon, Worldchain, and Linea

- `ApproveAndAcrossSendFundsAndExecuteOnDstHook`

### Polygon, Worldchain, HyperEVM, Linea, and Berachain

- `RecordPurchasePendlePTAmortizedOracleHook`

### Flare, Stable, and HyperEVM

- `FetchNativeFeeHook`

### Worldchain, Linea, and Berachain

- `RecordRedemptionPendlePTAmortizedOracleHook`

### Stable and HyperEVM

- `ApproveAndDeposit4626VaultHook`
- `ApproveAndRequestDeposit7540VaultHook`
- `CancelDepositRequestWithId7540Hook`
- `CancelRedeemRequestWithId7540Hook`
- `ClaimCancelDepositRequestWithId7540Hook`
- `ClaimCancelRedeemRequestWithId7540Hook`
- `Deposit4626VaultHook`
- `Deposit7540VaultHook`
- `Redeem4626VaultHook`
- `RedeemWithId7540VaultHook`
- `RequestDeposit7540VaultHook`
- `RequestRedeem7540VaultHook`
- `SetOperator7540Hook`
- `WithdrawWithId7540VaultHook`

### Linea only

- `AcrossSendFundsAndExecuteOnDstHook`
- `ApproveAndDeposit5115VaultHook`
- `ApproveAndSwapOdosV2Hook`
- `CancelDepositRequest7540Hook`
- `CancelRedeemRequest7540Hook`
- `CircleGatewayAddDelegateHook`
- `CircleGatewayMinterHook`
- `CircleGatewayRemoveDelegateHook`
- `CircleGatewayWalletHook`
- `ClaimCancelDepositRequest7540Hook`
- `ClaimCancelRedeemRequest7540Hook`
- `DeBridgeCancelOrderHook`
- `DeBridgeSendOrderAndExecuteOnDstHook`
- `Deposit5115VaultHook`
- `EthenaCooldownSharesHook`
- `EthenaUnstakeHook`
- `MarkRootAsUsedHook`
- `Redeem5115VaultHook`
- `Redeem7540VaultHook`
- `SetSlippageHook`
- `SwapOdosV2Hook`

The Linea `SetSlippageHook` and `MarkRootAsUsedHook` entries are the older production addresses, not the newer versions verified during the 2026-07-21 rollout verification.
