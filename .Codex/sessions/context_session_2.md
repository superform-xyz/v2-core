# Context Session 2

## Current request
- Create a pull request to `dev` for the accepted partial `SetSlippageHook` / `MarkRootAsUsedHook` production rollout, the corresponding production manifest updates, and the preceding seven-token-hook manifest reconciliation.

## Constraints and approach
- The user explicitly authorized production deployment of only the seven listed hooks on only the five listed missing chains.
- No other hook, adapter, chain, explorer submission, registry upload, or bundler rollout is authorized.
- Runtime comparisons must account for compiler-declared immutable and library-link reference ranges; raw bytecode hashes alone are insufficient for contracts with constructor immutables.
- The previous `context_session_1.md` and two unrelated Aerodrome production-lock artifacts were intentionally deleted at the user's request before this session.

## Production runtime audit result (2026-07-20)
- Checkout: local `dev` at `58198a31`, equal to `origin/dev` before the audit.
- Fresh build: `forge clean && forge build --skip test` succeeded, compiling 701 files with Solc 0.8.30. Only the known duplicate memory-safe assembly annotation and unused `ConfigCore.env` warnings were emitted.
- Manifest audited: `script/output/prod/latest.json`, updated `2026-07-20T10:25:35Z`.
- Scope: 1,572 valid production addresses, 16 chains, 143 unique contract names.
- All 16 RPC endpoints returned the expected chain ID. Every listed address had nonempty runtime code. There were no RPC failures.
- Comparison method: selected the canonical fresh `src/` artifact when names were duplicated, then compared runtime bytecode after zeroing compiler-declared immutable and link-reference ranges in both local and on-chain code. Runtime length differences were always treated as mismatches before normalization.
- Entry results:
  - 96 exact raw runtime matches;
  - 729 matches after immutable/link normalization;
  - 686 runtime mismatches, all of them runtime-length mismatches;
  - 61 not locally comparable: 60 external Nexus entries and Flare `DepositWFLRHook`, which has no fresh local artifact;
  - 0 missing-code, RPC-error, or comparison-error entries.
- Unique-name results among the 138 locally comparable contracts:
  - 64 names are current everywhere they appear in the production manifest;
  - 7 names are current on some networks but stale on five networks;
  - 67 names have a fresh local runtime that differs from the production lock and are not deployed on any manifest network where they appear.

### Current production-lock versions not deployed on five chains
- Chains: Linea, Berachain, Sonic, Gnosis, Worldchain.
- Contracts:
  - `ApproveERC20Hook`
  - `BatchTransferFromHook`
  - `BatchTransferHook`
  - `MerklClaimRewardHook`
  - `OfframpTokensHook`
  - `TransferERC20Hook`
  - `TransferHook`
- These seven fresh artifacts exactly match `script/locked-bytecode`; the listed five chains still point to older runtimes. The other production-manifest chains carrying these contracts match the fresh/current lock version.

### Fresh local source differs from production lock and is nowhere deployed
- Ethereum only:
  - `AaveV4BorrowHook`, `AaveV4RepayAndWithdrawHook`, `AaveV4RepayHook`, `AaveV4SupplyAndBorrowHook`, `AaveV4SupplyHook`, `AaveV4WithdrawHook`, `ApproveAndRequestRedeemDETHHook`, `ClaimAssetsDETHHook`, `RequestRedeemDETHHook`.
- Ethereum, Base, BNB, Arbitrum, Optimism, Polygon, Unichain, Linea, Worldchain, HyperEVM:
  - `AcrossSendFundsAndExecuteOnDstHook`, `AcrossSendFundsAndExecuteOnDstHookV2`, `ApproveAndAcrossSendFundsAndExecuteOnDstHook`, `ApproveAndAcrossSendFundsAndExecuteOnDstHookV2`.
- All 16 production networks:
  - `ApproveAndCCTPSendHook`, `ApproveAndDeposit5115VaultHook`, `ApproveAndStargateSendHook`, `ApproveAndStargateSendHookV2`, `CCTPSendHook`, `CancelDepositRequest7540Hook`, `CancelRedeemRequest7540Hook`, `CircleGatewayAddDelegateHook`, `CircleGatewayMinterHook`, `CircleGatewayRemoveDelegateHook`, `CircleGatewayWalletHook`, `ClaimCancelDepositRequest7540Hook`, `ClaimCancelRedeemRequest7540Hook`, `ClaimFailedTransferHook`, `Deposit5115VaultHook`, `EthenaCooldownSharesHook`, `EthenaUnstakeHook`, `MarkRootAsUsedHook`, `PendlePTYieldSourceOracle`, `RecordPurchasePendlePTAmortizedOracleHook`, `RecordPurchasePendlePTAmortizedOracleHookV2`, `RecordRedemptionPendlePTAmortizedOracleHook`, `RecordRedemptionPendlePTAmortizedOracleHookV2`, `Redeem5115VaultHook`, `Redeem7540VaultHook`, `SetSlippageHook`, `StargateAdapter`, `StargateSendHook`, `StargateSendHookV2`, `Withdraw7540VaultHook`.
- Ethereum, Base, BNB, Arbitrum, Optimism, Polygon, Unichain, Avalanche, Linea, Sonic:
  - `ApproveAndSwapOdosV2Hook`, `SwapOdosV2Hook`.
- Ethereum, Base, BNB, Arbitrum, Optimism, Polygon, Avalanche, Linea, Sonic:
  - `ApproveAndSwapOdosV3Hook`, `SwapOdosV3Hook`.
- Ethereum, Base, BNB, Arbitrum, Optimism, Polygon, Unichain, Avalanche, Linea, Worldchain, Stable:
  - `ApproveAndSwapUniswapV3Router02Hook`, `SwapUniswapV3Router02Hook`.
- Flare only:
  - `ApproveAndSwapUniswapV2Hook`, `ClaimRFLRHook`, `ClaimRFLRV2Hook`, `ClaimWithdrawFirelightVaultHook`, `RedeemFirelightVaultHook`, `SwapUniswapV2Hook`, `WithdrawRFLRHook`, `WithdrawVestedRFLRHook`.
- Ethereum, Base, BNB, Arbitrum, Optimism, Polygon, Avalanche, Linea, Berachain, Sonic, Gnosis, HyperEVM:
  - `DeBridgeCancelOrderHook`, `DeBridgeSendOrderAndExecuteOnDstHook`.
- Ethereum, Base, BNB, Arbitrum, Optimism, Berachain, Sonic, HyperEVM:
  - `PendleRouterRedeemHook`, `PendleRouterSwapHook`, `PendleUnifiedHook`.
- Ethereum and Flare:
  - `WrappedNativeHook`.
- Base only:
  - `ApproveAndSwapSparkPSMExactInHook`, `ApproveAndSwapSparkPSMExactOutHook`, `SwapSparkPSMExactInHook`, `SwapSparkPSMExactOutHook`.

### Production-lock consistency check
- Rechecked all 651 live entries belonging to the 67 source-vs-lock drifted names against their committed `script/locked-bytecode` artifacts.
- 649 match the committed production lock after immutable/link normalization.
- Two do not: `StargateAdapter` on Worldchain (`0xa2cCAA51627cAe4C3EbB129Eb6D81F01273fadF4`) and HyperEVM (`0x636F0fcf76a9333565FE59f0C2143DE207C19f19`). Their live runtimes are 2,487 bytes, while the current production lock is 3,875 bytes and the fresh local runtime is 4,654 bytes. The other 14 chains' `StargateAdapter` runtimes match the current production lock.
- This audit performed no deployment, signing, broadcast, output JSON mutation, explorer submission, or Solidity source change.

## Token-hook deployment reconciliation (2026-07-20)
- Rebuilt/checked the fixed-scope `runTemporaryTokenHookUpgrade` deployment path for production (`env = 0`) on Linea (59144), Berachain (80094), Sonic (146), Gnosis (100), and Worldchain (480).
- Fresh Foundry creation/runtime artifacts for all seven requested hooks exactly match both `script/generated-bytecode` and `script/locked-bytecode`.
- The fixed-scope check reported `selected = 7`, `available = 7`, `deployed = 7`, `missing = 0`, and `unavailable = 0` on every target chain. An independent RPC sweep also confirmed nonempty runtime code at all 35 deterministic addresses and exact equality to the fresh artifacts after normalizing compiler-declared immutable/link ranges.
- Therefore no signing or broadcast was performed and zero deployment transactions were sent: the current hook versions were already deployed on all five chains, while the production manifests still referenced the previous addresses.
- Current deterministic addresses on all five chains:
  - `ApproveERC20Hook`: `0x1851A98471ADE4a115B6FB7bd42934a200e58d9E`
  - `BatchTransferFromHook`: `0x8E835115db46BC688DDB6f4756774468D3716A15`
  - `BatchTransferHook`: `0x6D69433fa474b3A14cB3479c584E61fAE1De7b9F`
  - `MerklClaimRewardHook`: `0x5977c7cA74067f3Bc899B3303ce00B47c815813A`
  - `OfframpTokensHook`: `0x83d8833161Ce1325f581e8C310aBAC2c488f9c69`
  - `TransferERC20Hook`: `0x0234Da531FfB8765397aB8Ee91Db448963F545f2`
  - `TransferHook`: `0x2a2CD39c1b72f85F291d06BD02f1f4CB2de5081A`
- Reconciled the five production per-chain manifests with the fixed-scope entrypoint in no-broadcast mode and regenerated `script/output/prod/latest.json` using `./script/run/tooling/generate_latest_json.sh prod`.
- Modified output files:
  - `script/output/prod/59144/Linea-latest.json`
  - `script/output/prod/80094/Berachain-latest.json`
  - `script/output/prod/146/Sonic-latest.json`
  - `script/output/prod/100/Gnosis-latest.json`
  - `script/output/prod/480/Worldchain-latest.json`
  - `script/output/prod/latest.json`
- Final validation: all six JSON files parse; each per-chain and aggregate network entry contains all seven expected addresses; semantic comparison to `HEAD` shows exactly those seven contract entries changed per target network plus the aggregate `updated_at`; `git diff --check` passes.

## Direct live-code revalidation (2026-07-20)
- At the user's request, independently queried `eth_getCode`/`cast code` for all seven current deterministic addresses on each of the five target-chain RPCs instead of relying on manifests or the deployment script's presence check.
- Verified each RPC's `eth_chainId` first and sampled these blocks: Linea `31453104`, Berachain `23768449`, Sonic `76234703`, Gnosis `47299736`, Worldchain `32608007`.
- All 35 addresses returned nonempty runtime bytecode. Every runtime had the exact compiled length and matched the current fresh artifact after zeroing only the immutable ranges declared in the Foundry artifact. There are no library link references for these seven artifacts.
- Raw runtime hashes were also identical across all five chains for each contract:
  - `ApproveERC20Hook`: 6,218 bytes, `0x1994d35f6b96744a925ac80dcf545ac843275ff0b1e2d21a46f2e8ff8f2f6f60`
  - `BatchTransferFromHook`: 7,348 bytes, `0x35af9a99645c1abc2c09a492fb0c9828b2d3fa83b1b6249a089e6389af25f57b`
  - `BatchTransferHook`: 5,436 bytes, `0xdf01bb3c9255181af7e3fee7f6e78fa563afa72db201937867a789ead9463b02`
  - `MerklClaimRewardHook`: 7,562 bytes, `0xa6481e90d965e591e858a87c9167f5d0e23292a2a038d53240dee4885e8f614d`
  - `OfframpTokensHook`: 5,484 bytes, `0xc00a8f2b3c79ea56e8da75ec74b6e1ef00e1da2de0c9200b99b71623994e29f3`
  - `TransferERC20Hook`: 6,011 bytes, `0xca2564f1da6af667c1b7ce72417b399a5be17cee70c3bd2973d7267d9cd23560`
  - `TransferHook`: 6,295 bytes, `0xedb03d7e66114b8ee4f6ed66de3595c75c9df191e7485d661a132818d72e6755`
- The revalidation was read-only: no signing, transaction broadcast, manifest mutation, or source/output changes were made.

## SetSlippageHook / MarkRootAsUsedHook production deployment preflight (2026-07-20)
- User requested deployment of `SetSlippageHook` and `MarkRootAsUsedHook` on all chains; interpreted “all chains” as all 16 production networks in `script/run/utils/networks-production.sh` and `script/output/prod/latest.json`.
- Fresh compile succeeded with Solc 0.8.30. The fresh artifacts do **not** match the committed generated or locked artifacts:
  - `SetSlippageHook` fresh creation bytecode: 5,018 bytes, hash `0xd073f012cbbcea46ff9678b4132521d6e591445a86a0b77752b753aac6c66fb6`; committed generated/prod-lock/dev-lock: 3,674 bytes, hash `0xbd1e4c54d5cdfce3264392b19072dd666eb40525b9fc05997fc02f656838eb01`.
  - `MarkRootAsUsedHook` fresh creation bytecode: 5,346 bytes, hash `0x43d32bf87965ef690f995230f28c396a05e38a949bdbeee28be0a1975b47aff5`; committed generated/prod-lock/dev-lock: 4,096 bytes, hash `0xf1b5d7812c96185f15b8ef29208788734673be797a353535a775070a62d9158b`.
- With the production namespace `PROD1.0.0`, deterministic addresses are:
  - Fresh `SetSlippageHook`: `0x78Be4075B50dD4AD54044289bA20Ea1d8BFeab2F`; locked/manifest version: `0x6551d0140FFdB28920E5e84DC3DA31f4bfe4364E`.
  - Fresh `MarkRootAsUsedHook`: `0xBE9Ac12c097c7Fd5B654dBb5676edF84f44EcE2c`; locked/manifest version: `0xE61774Aa87a05fB1B5665158F2b5E0E10C71B5e2`.
- Direct batched RPC checks on Ethereum, Base, BNB, Arbitrum, Optimism, Polygon, Unichain, Avalanche, Linea, Berachain, Sonic, Gnosis, Worldchain, HyperEVM, Flare, and Stable confirmed:
  - every RPC reports its expected chain ID;
  - the deterministic deployer exists on every chain (69-byte runtime);
  - the locked `SetSlippageHook` exists on every chain (3,552-byte runtime);
  - the locked `MarkRootAsUsedHook` exists on every chain (3,977-byte runtime);
  - both fresh deterministic addresses have zero code on every chain.
- No production lock was changed and no transaction was signed or broadcast. Deploying the current source versions requires explicit promotion of both fresh artifacts into `script/generated-bytecode`, `script/locked-bytecode-dev`, and `script/locked-bytecode`; otherwise the production deployment guard rejects them. Awaiting confirmation because promoting a build that is not currently production-locked is materially different from deploying the already-approved production lock.

### Promotion and broadcast preparation
- User explicitly authorized promotion and deployment after reviewing the lock distinction.
- Promoted the fresh Foundry artifacts for both contracts into all three required locations: `script/generated-bytecode`, `script/locked-bytecode-dev`, and `script/locked-bytecode`. All six promoted copies exactly match their respective fresh creation-bytecode hashes listed above.
- `forge build --skip test` succeeds. The provided `regenerate_bytecode.sh` and targeted `forge test` commands are blocked during compilation by unrelated existing `view`-mutability errors in `MinimalBaseNexusIntegrationTest.t.sol` and `StargateAdapterE2EFork.t.sol`; the regeneration script failed before copying, so the promotion was performed as a direct mechanical artifact copy from the successful production build.
- Built exact deterministic-deployer calldata for both promoted artifacts and successfully ran `eth_estimateGas` on all 16 production chains. Typical estimates are approximately 1.14M gas for `SetSlippageHook` and 1.21M gas for `MarkRootAsUsedHook`; no simulation reverted.
- The only available Foundry account is the encrypted local keystore `v2-prod-deployer`. Its keystore omits the optional plaintext address field and requires a password; no matching password entry exists in accessible 1Password item titles or macOS Keychain. No signer has been unlocked and no transaction has been signed or broadcast.
- The repository constant `DEPLOYER` (`0x6E3dadcAf328ebB58753e89a3e589F5C5e988dF8`) was used only for preliminary estimate-from/balance checks and must not be assumed to be the keystore address until it is unlocked. That address is funded on Ethereum, Base, and HyperEVM; has a nonzero but currently insufficient estimated balance on Flare; and is zero-funded on the other 12 chains.

## SetSlippageHook / MarkRootAsUsedHook production deployment result (2026-07-20)
- The user authorized using the same 1Password-backed deployment key used in the existing workflow and subsequently accepted a partial rollout. The signer was loaded from the `Backend Team / Deployer pk` 1Password item without printing secret material; its derived address is `0x91489D9c003A65eBd7C351dA60D01be71fA18FC9`.
- The promoted deterministic production addresses are:
  - `SetSlippageHook`: `0x78Be4075B50dD4AD54044289bA20Ea1d8BFeab2F`
  - `MarkRootAsUsedHook`: `0xBE9Ac12c097c7Fd5B654dBb5676edF84f44EcE2c`
- Both contracts were successfully deployed on 11 production chains: Ethereum (1), Base (8453), BNB (56), Arbitrum (42161), Optimism (10), Polygon (137), Unichain (130), Avalanche (43114), HyperEVM (999), Flare (14), and Stable (988).
- Both contracts intentionally remain undeployed on Linea (59144), Berachain (80094), Sonic (146), Gnosis (100), and Worldchain (480). Their production manifest entries retain the previous Set/Mark addresses.
- Post-deployment `eth_getCode` checks found the expected nonempty runtimes at both new addresses on all 11 deployed chains (22/22). Each runtime was compared to the current Foundry artifact after zeroing only compiler-declared immutable ranges and matched exactly. Runtime lengths are 4,896 bytes for `SetSlippageHook` and 5,227 bytes for `MarkRootAsUsedHook`; both addresses returned empty code on all five intentionally omitted chains.
- Transaction hashes:
  - Ethereum: Set `0x6484646d77a9441f25cd93e872c92b08643d6a6a1408c8a6ebba60479c840fd0`; Mark `0x2df13e065a55946d76554d52e21e8924ce5047e3731ce95738591d8db626c18e`.
  - Base: Set `0x397e6a9e594bfe3f03d7a7b6199442ccd2740a2755b7eb4e114cabdbac4f728a`; Mark `0x7d511da1e36a5dec67b754395ff2ebd7e52b5e6fa8780a22384ac3523f256336`.
  - BNB: Set `0xadba8ee31312298b8452764d37f14868b6f6a6a56ac23c530e1507f0243d5f59`; Mark `0x75d15c78eb8fc6af4161ba1b653842d8d35e552be61db0165f5d0094e3dee217`.
  - Arbitrum: Set `0x71286dc6a30176ed3066959e42d7af7a38fe1e310775165d2884acf3c9083d41`; Mark `0xc0f4c266815d3c9914d9f2d7340496c102ec9f27dba7ab69fb14bb03b6454785`.
  - Optimism: Set `0xbc815d8aa6f58d39eeb3ac23a3051628afdc9de7804dac577d5ed5aa6d4cfbac`; Mark `0xd767c6a62ed0e4f6348a7f471ce8320e1bc7cb509bda5fd3cc1c6d0ce2931054`.
  - Polygon: Set `0x38e2a103d9d33351ab271bc80d1e036ffda9a2555cfcc27d46cb2696db4b69ee`; Mark `0xb5aa1a252ca26ba929d3a0f95126a48abce93386b31e1470e038fc2a018a7f4c`.
  - Unichain: Set `0x37408d36d56d4c2942e2a51776031da39bfbf34903900999c5092a7f979b738e`; Mark `0x2afdab01cc607845d775ea57866ecb949f85392a6e44f39027eb35f6689b8482`.
  - Avalanche: Set `0x4df41e7349783c183c1d4dbe78c02329dd207d410d5b1189859b74dedc7e0953`; Mark `0x55f42b3df46f2f19e336b3caa39d761541f53b8f7fd1ea9808ea2c3dce169140`.
  - HyperEVM: Set `0x001e2d331a1ccbc854e2408ef7704fe1b5097c348d7f97f523a5a449aee5c3f4`; Mark `0x2c9a99fe809a1aa0ad3daf815507c243754fae61a7505c272aae3cc81c358d92`.
  - Flare: Set `0x13e5ef449dedd244c7e69e3ef2bd9a25aebb8e5f7a758d0e57210b7140ad220e`; Mark `0x3c7721cac3cefa463a1fd809d367e0f85a008868ddf665d1e83489ddd7be6995`.
  - Stable: Set `0xc6cc81a848ec1a702a5e86ca60654e47c7a7ac1672e257707bad947c0f6845ae`; Mark `0x771e1654777c53554ccd07dd34cce1d733c7513f3a124e1444233e15a8db7a89`.

## Production manifest and PR validation (2026-07-20)
- Updated the 11 deployed-chain production manifests and regenerated `script/output/prod/latest.json`. The semantic diff contains exactly two Set/Mark address changes per deployed chain.
- Preserved the earlier seven-token-hook reconciliation for Linea, Berachain, Sonic, Gnosis, and Worldchain. The semantic diff contains exactly those seven token-hook address changes per chain; no Set/Mark entry changed on these five networks.
- The aggregate file's contracts match all 16 per-chain manifests exactly. All modified JSON files parse, `git diff --check` passes, and the promoted generated/dev-lock/prod-lock bytecode copies exactly match the fresh Foundry artifacts and expected creation-bytecode hashes.
- Final `forge build --skip test` succeeds. Full test compilation remains blocked by pre-existing unrelated `view`-mutability errors around `vm.getRecordedLogs()` in `MinimalBaseNexusIntegrationTest.t.sol` and `StargateAdapterE2EFork.t.sol`.
- The explicitly requested deletion of `.Codex/sessions/context_session_1.md` remains in the change set; this session file replaces it as the current handoff context.
