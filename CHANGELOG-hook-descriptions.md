# Hook Names & Descriptions

Total: **120 hooks**

| Contract | Name | Description |
|----------|------|-------------|
| AaveV4BorrowHook | Aave V4 Borrow | Borrows assets from an Aave V4 lending pool |
| AaveV4RepayHook | Aave V4 Repay | Repays borrowed assets to an Aave V4 lending pool |
| AaveV4RepayAndWithdrawHook | Aave V4 Repay and Withdraw | Repays and withdraws assets from an Aave V4 lending pool |
| AaveV4SupplyHook | Aave V4 Supply | Supplies assets to an Aave V4 lending pool |
| AaveV4SupplyAndBorrowHook | Aave V4 Supply and Borrow | Supplies and borrows assets from an Aave V4 lending pool |
| AaveV4WithdrawHook | Aave V4 Withdraw | Withdraws assets from an Aave V4 lending pool |
| AcrossSendFundsAndExecuteOnDstHook | Across Bridge | Bridges tokens via Across and executes on destination chain |
| AcrossSendFundsAndExecuteOnDstHookV2 | Across Bridge V2 | Bridges tokens via Across V2 and executes on destination chain |
| ApproveERC20Hook | Approve ERC-20 | Approves an ERC-20 token spending allowance |
| ApproveAndAcrossSendFundsAndExecuteOnDstHook | Approve and Across Bridge | Approves and bridges tokens via Across with destination execution |
| ApproveAndAcrossSendFundsAndExecuteOnDstHookV2 | Approve and Across Bridge V2 | Approves and bridges tokens via Across V2 with destination execution |
| ApproveAndCCTPSendHook | Approve and CCTP Send | Approves and bridges USDC via Circle CCTP |
| ApproveAndDeposit4626VaultHook | Approve and Deposit ERC-4626 Vault | Approves and deposits assets into an ERC-4626 vault |
| ApproveAndDeposit5115VaultHook | Approve and Deposit ERC-5115 Vault | Approves and deposits assets into an ERC-5115 vault |
| ApproveAndFluidStakeHook | Approve and Fluid Stake | Approves and stakes tokens in Fluid protocol |
| ApproveAndGearboxStakeHook | Approve and Gearbox Stake | Approves and stakes tokens in Gearbox protocol |
| ApproveAndRequestDeposit7540VaultHook | Approve and Request Deposit ERC-7540 Vault | Approves and requests a deposit into an ERC-7540 async vault |
| ApproveAndRequestRedeemDETHHook | Approve and Request Redeem DETH | Approves and requests a redemption from a DETH vault |
| ApproveAndStargateSendHook | Approve and Stargate Bridge | Approves and bridges tokens via Stargate |
| ApproveAndStargateSendHookV2 | Approve and Stargate Bridge V2 | Approves and bridges tokens via Stargate V2 |
| ApproveAndSwapAlgebraIntegralHook | Approve and Swap Algebra Integral | Approves and swaps tokens via Algebra Integral DEX |
| ApproveAndSwapKyberSwapHook | Approve and Swap KyberSwap | Approves and swaps tokens via KyberSwap aggregator |
| ApproveAndSwapOdosV2Hook | Approve and Swap Odos V2 | Approves and swaps tokens via Odos V2 aggregator |
| ApproveAndSwapOdosV3Hook | Approve and Swap Odos V3 | Approves and swaps tokens via Odos V3 aggregator |
| ApproveAndSwapOpenOceanSparkDexHook | Approve and Swap OpenOcean SparkDex | Approves and swaps tokens via OpenOcean SparkDex aggregator |
| ApproveAndSwapSparkPSMExactInHook | Approve and Swap Spark PSM Exact In | Approves and swaps exact input tokens via Spark PSM |
| ApproveAndSwapSparkPSMExactOutHook | Approve and Swap Spark PSM Exact Out | Approves and swaps for exact output tokens via Spark PSM |
| ApproveAndSwapUniswapV2Hook | Approve and Swap Uniswap V2 | Approves and swaps tokens via Uniswap V2 |
| ApproveAndSwapUniswapV3Hook | Approve and Swap Uniswap V3 | Approves and swaps tokens via Uniswap V3 |
| ApproveAndSwapUniswapV3Router02Hook | Approve and Swap Uniswap V3 Router02 | Approves and swaps tokens via Uniswap V3 Router02 |
| BatchTransferHook | Batch Transfer | Transfers tokens to multiple recipients in a single call |
| BatchTransferFromHook | Batch Transfer From | Batch transfers tokens using Permit2 signatures |
| BurnSuperPositionsHook | Burn SuperPositions | Burns SuperPosition tokens to release vault shares |
| CCTPSendHook | CCTP Send | Bridges USDC via Circle CCTP cross-chain transfer |
| CancelDepositRequest7540Hook | Cancel Deposit Request ERC-7540 | Cancels a pending deposit request on an ERC-7540 vault |
| CancelDepositRequestWithId7540Hook | Cancel Deposit Request with ID ERC-7540 | Cancels a pending deposit request on an ERC-7540 vault using a request ID |
| CancelRedeemRequest7540Hook | Cancel Redeem Request ERC-7540 | Cancels a pending redeem request on an ERC-7540 vault |
| CancelRedeemRequestWithId7540Hook | Cancel Redeem Request with ID ERC-7540 | Cancels a pending redeem request on an ERC-7540 vault using a request ID |
| CircleGatewayAddDelegateHook | Circle Gateway Add Delegate | Adds a delegate to a Circle Gateway wallet |
| CircleGatewayMinterHook | Circle Gateway Minter | Mints tokens via Circle Gateway |
| CircleGatewayRemoveDelegateHook | Circle Gateway Remove Delegate | Removes a delegate from a Circle Gateway wallet |
| CircleGatewayWalletHook | Circle Gateway Wallet | Interacts with Circle Gateway wallet for cross-chain transfers |
| ClaimAssetsDETHHook | Claim Assets DETH | Claims redeemed assets from a DETH vault |
| ClaimCancelDepositRequest7540Hook | Claim Cancel Deposit Request ERC-7540 | Claims assets from a cancelled deposit request on an ERC-7540 vault |
| ClaimCancelDepositRequestWithId7540Hook | Claim Cancel Deposit Request with ID ERC-7540 | Claims assets from a cancelled deposit request on an ERC-7540 vault using a request ID |
| ClaimCancelRedeemRequest7540Hook | Claim Cancel Redeem Request ERC-7540 | Claims shares from a cancelled redeem request on an ERC-7540 vault |
| ClaimCancelRedeemRequestWithId7540Hook | Claim Cancel Redeem Request with ID ERC-7540 | Claims shares from a cancelled redeem request on an ERC-7540 vault using a request ID |
| ClaimFailedTransferHook | Claim Failed Transfer | Claims tokens from a failed Stargate transfer |
| ClaimRFLRHook | Claim RFLR | Claims RFLR rewards from the Flare network |
| ClaimWithdrawFirelightVaultHook | Claim Withdraw Firelight Vault | Claims withdrawn assets from a Firelight vault |
| Deposit4626VaultHook | Deposit ERC-4626 Vault | Deposits assets into an ERC-4626 vault and receives shares |
| Deposit5115VaultHook | Deposit ERC-5115 Vault | Deposits assets into an ERC-5115 vault and receives shares |
| Deposit7540VaultHook | Deposit ERC-7540 Vault | Deposits assets into an ERC-7540 async vault |
| DepositWETHHook | Deposit WETH | Wraps native ETH into WETH |
| EthenaCooldownSharesHook | Ethena Cooldown Shares | Initiates cooldown for Ethena staked shares |
| EthenaUnstakeHook | Ethena Unstake | Unstakes assets from Ethena after cooldown |
| FetchNativeFeeHook | Fetch Native Fee | Fetches native gas fee for sponsored transactions |
| FluidClaimRewardHook | Fluid Claim Reward | Claims reward tokens from Fluid protocol |
| FluidStakeHook | Fluid Stake | Stakes tokens in Fluid protocol |
| FluidUnstakeHook | Fluid Unstake | Unstakes tokens from Fluid protocol |
| ForceDeallocateMorphoHook | Force Deallocate Morpho | Force deallocates liquidity from a Morpho market |
| GearboxClaimRewardHook | Gearbox Claim Reward | Claims reward tokens from Gearbox protocol |
| GearboxStakeHook | Gearbox Stake | Stakes tokens in Gearbox protocol |
| GearboxUnstakeHook | Gearbox Unstake | Unstakes tokens from Gearbox protocol |
| MarkRootAsUsedHook | Mark Root As Used | Marks a Merkle root as used to prevent replay |
| MerklClaimRewardHook | Merkl Claim Reward | Claims reward tokens from Merkl distributor |
| MetaMorphoReallocateHook | MetaMorpho Reallocate | Reallocates liquidity across MetaMorpho vault markets |
| MintSuperPositionsHook | Mint SuperPositions | Mints SuperPosition tokens representing a vault share |
| MorphoBorrowHook | Morpho Borrow | Borrows assets from a Morpho market |
| MorphoLendHook | Morpho Lend | Lends assets to a Morpho market |
| MorphoRepayHook | Morpho Repay | Repays borrowed assets to a Morpho market |
| MorphoRepayAndWithdrawHook | Morpho Repay and Withdraw | Repays borrowed assets and withdraws collateral from a Morpho market |
| MorphoSupplyHook | Morpho Supply | Supplies collateral to a Morpho market |
| MorphoSupplyAndBorrowHook | Morpho Supply and Borrow | Supplies collateral and borrows assets from a Morpho market |
| MorphoWithdrawHook | Morpho Withdraw | Withdraws collateral from a Morpho market |
| NativeTransferHook | Native Transfer | Transfers native ETH to a recipient |
| OfframpTokensHook | Offramp Tokens | Offramps tokens for fiat withdrawal |
| PendleRouterRedeemHook | Pendle Router Redeem | Redeems Pendle PT tokens for underlying assets |
| PendleRouterSwapHook | Pendle Router Swap | Swaps tokens via Pendle router |
| PendleUnifiedHook | Pendle Unified | Executes unified Pendle operations (swap or redeem) |
| RecordPurchasePendlePTAmortizedOracleHook | Record Purchase Pendle PT Oracle | Records a Pendle PT purchase for amortized oracle pricing |
| RecordPurchasePendlePTAmortizedOracleHookV2 | Record Purchase Pendle PT Oracle V2 | Records a Pendle PT purchase for amortized oracle pricing (V2) |
| RecordRedemptionPendlePTAmortizedOracleHook | Record Redemption Pendle PT Oracle | Records a Pendle PT redemption for amortized oracle pricing |
| RecordRedemptionPendlePTAmortizedOracleHookV2 | Record Redemption Pendle PT Oracle V2 | Records a Pendle PT redemption for amortized oracle pricing (V2) |
| Redeem4626VaultHook | Redeem ERC-4626 Vault | Redeems shares from an ERC-4626 vault for underlying assets |
| Redeem5115VaultHook | Redeem ERC-5115 Vault | Redeems shares from an ERC-5115 vault for underlying assets |
| Redeem7540VaultHook | Redeem ERC-7540 Vault | Redeems shares from an ERC-7540 async vault |
| RedeemFirelightVaultHook | Redeem Firelight Vault | Redeems shares from a Firelight vault |
| RedeemWithId7540VaultHook | Redeem with ID ERC-7540 Vault | Redeems shares from an ERC-7540 async vault using a request ID |
| RequestDeposit7540VaultHook | Request Deposit ERC-7540 Vault | Requests a deposit into an ERC-7540 async vault |
| RequestRedeemDETHHook | Request Redeem DETH | Requests a redemption from a DETH vault |
| RequestRedeem7540VaultHook | Request Redeem ERC-7540 Vault | Requests a redemption from an ERC-7540 async vault |
| SetOperator7540Hook | Set Operator ERC-7540 | Sets an operator for an ERC-7540 vault |
| SetSlippageHook | Set Slippage ERC-7540 | Sets slippage tolerance for an ERC-7540 vault operation |
| SpectraExchangeDepositHook | Spectra Exchange Deposit | Deposits into a yield position via Spectra exchange |
| SpectraExchangeRedeemHook | Spectra Exchange Redeem | Redeems principal tokens via Spectra exchange |
| StargateSendHook | Stargate Bridge | Bridges tokens via Stargate cross-chain messaging |
| StargateSendHookV2 | Stargate Bridge V2 | Bridges tokens via Stargate V2 cross-chain messaging |
| Swap1InchHook | Swap 1inch | Swaps tokens via 1inch aggregator |
| SwapAlgebraIntegralHook | Swap Algebra Integral | Swaps tokens via Algebra Integral DEX |
| SwapKyberSwapHook | Swap KyberSwap | Swaps tokens via KyberSwap aggregator |
| SwapOdosV2Hook | Swap Odos V2 | Swaps tokens via Odos V2 aggregator |
| SwapOdosV3Hook | Swap Odos V3 | Swaps tokens via Odos V3 aggregator |
| SwapOpenOceanSparkDexHook | Swap OpenOcean SparkDex | Swaps tokens via OpenOcean SparkDex aggregator |
| SwapSparkPSMExactInHook | Swap Spark PSM Exact In | Swaps exact input tokens via Spark PSM |
| SwapSparkPSMExactOutHook | Swap Spark PSM Exact Out | Swaps for exact output tokens via Spark PSM |
| SwapUniswapV2Hook | Swap Uniswap V2 | Swaps tokens via Uniswap V2 |
| SwapUniswapV3Hook | Swap Uniswap V3 | Swaps tokens via Uniswap V3 exact input single |
| SwapUniswapV3Router02Hook | Swap Uniswap V3 Router02 | Swaps tokens via Uniswap V3 Router02 |
| SwapUniswapV4Hook | Swap Uniswap V4 | Swaps tokens via Uniswap V4 |
| TransferHook | Transfer | Transfers tokens to a recipient |
| TransferERC20Hook | Transfer ERC-20 | Transfers ERC-20 tokens to a recipient |
| Withdraw7540VaultHook | Withdraw ERC-7540 Vault | Withdraws assets from an ERC-7540 async vault |
| WithdrawRFLRHook | Withdraw RFLR | Withdraws RFLR tokens from the Flare network |
| WithdrawVestedRFLRHook | Withdraw Vested RFLR | Withdraws vested RFLR tokens from the Flare network |
| WithdrawWETHHook | Withdraw WETH | Unwraps WETH into native ETH |
| WithdrawWithId7540VaultHook | Withdraw with ID ERC-7540 Vault | Withdraws assets from an ERC-7540 async vault using a request ID |
| YearnClaimOneRewardHook | Yearn Claim Reward | Claims a single reward token from Yearn vault |
| DeBridgeCancelOrderHook | deBridge Cancel Order | Cancels a pending deBridge cross-chain order |
| DeBridgeSendOrderAndExecuteOnDstHook | deBridge Send Order | Sends a cross-chain order via deBridge with destination execution |
