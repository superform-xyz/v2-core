# Context Session 2

## Polygon native-token hook correction plan (2026-07-23)
- User authorized a Polygon mainnet-only redeployment of exactly `BatchTransferHook`, `TransferHook`, `Swap1InchHook`, `SwapKyberSwapHook`, and `ApproveAndSwapKyberSwapHook`.
- Root cause: bundler, 1inch, and Kyber use `0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE` for native assets, while the current Polygon hook constructors use `0x0000000000000000000000000000000000001010`. For Kyber native input this causes the hook to forward zero `msg.value`.
- This is a constructor-argument-only correction. Hook source and bare creation bytecode are unchanged; `script/generated-bytecode`, `script/locked-bytecode-dev`, and `script/locked-bytecode` must not be modified.
- Approved implementation: map Polygon to `NATIVE_TOKEN_DEFAULT`, remove the obsolete Polygon-only constant, add a production/chain-137-only fixed-scope deployment entrypoint for the five hooks, and update verifier constructor arguments.
- Required preflight: fresh artifact equality with generated and production-locked bytecode, Polygon RPC chain ID, deterministic deployer/router/helper code, current manifest code, CREATE2 predictions, gas estimation, signer identity, balance, and nonce.
- Required post-deployment verification: successful receipts, nonempty code, fresh runtime equality after immutable/link normalization, Eeee native getters, correct router/helper getters, exactly five Polygon manifest changes, aggregate regeneration, and public source verification for all five contracts.

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
- Created branch `codex/production-hook-deployments` from `dev` / `origin/dev` at `58198a31` and opened PR [#952](https://github.com/superform-xyz/v2-core/pull/952) targeting `dev` with the deployment scope, intentional five-chain omission, and validation details documented in the PR body.
- Sanitized the local `origin` configuration before pushing. The repository remote now resolves to the normal credential-free HTTPS URL, and the credential-bearing global GitHub URL rewrite entries were removed; GitHub CLI keyring authentication remains configured.

## Public contract verification script inspection (2026-07-20)
- Confirmed the repository has a dedicated public block-explorer verification entrypoint: `script/run/verify/verify_v2_staging_prod.sh`.
- It accepts `staging` or `prod`, loads deployment addresses from the matching per-chain output JSONs, reconstructs constructor arguments, submits source verification through `forge verify-contract`, and performs a post-submission explorer status sweep.
- It uses Etherscan V2 for most networks and Flare Blockscout for chain 14. Credentials/RPCs are loaded through the shared deployment utilities.
- Current defaults are `CHAINS_TO_VERIFY=(1 8453 56 42161 10 137 130 43114 14)`, all contracts, and a five-second submission delay. Setting `CHAINS_TO_VERIFY=()` in the script selects every configured network; `CONTRACTS_TO_VERIFY` can restrict the contract set.
- This inspection was read-only apart from this required session-context update; no verification was submitted.

## SetSlippageHook / MarkRootAsUsedHook public verification (2026-07-21)
- User authorized public source verification of only `SetSlippageHook` and `MarkRootAsUsedHook`.
- Temporarily scoped `script/run/verify/verify_v2_staging_prod.sh` to those two contracts and the 11 production chains carrying their promoted deployments: Ethereum, Base, BNB, Arbitrum, Optimism, Polygon, Unichain, Avalanche, HyperEVM, Flare, and Stable. Restored the script's original filter defaults after the run.
- All 22 `forge verify-contract` submissions were accepted: 11/11 networks passed, 22/22 contracts submitted successfully, with 0 failed and 0 skipped.
- The script's independent post-submission explorer API sweep confirmed all 22 addresses publicly verified: total checked 22, verified 22, unverified 0. Etherscan V2 was used for all applicable chains and Flare Blockscout for Flare.
- The addresses verified on every listed chain were `SetSlippageHook` at `0x78Be4075B50dD4AD54044289bA20Ea1d8BFeab2F` and `MarkRootAsUsedHook` at `0xBE9Ac12c097c7Fd5B654dBb5676edF84f44EcE2c`.

## StargateAdapterV2 public verification (2026-07-21)
- User expanded the verification scope to every production chain whose per-chain manifest contains a `StargateAdapterV2` address. The manifest-derived set contains 14 chains: Ethereum, Base, BNB, Arbitrum, Optimism, Polygon, Unichain, Avalanche, Linea, Berachain, Sonic, Gnosis, Flare, and Stable. Worldchain and HyperEVM were excluded because their production manifests do not contain `StargateAdapterV2`.
- Temporarily scoped `script/run/verify/verify_v2_staging_prod.sh` to `StargateAdapterV2` on those 14 chains. The verifier reconstructed the four constructor parameters from each live adapter, including the chain-specific allowed-OFT array. Restored the script's original filters afterward.
- Submission pass: 14/14 networks passed, 14/14 adapters succeeded, 0 failed, and 0 skipped. Eleven addresses were already publicly verified. Linea (`0x452C812790F572C267FB491C73c0F14D9d137921`), Flare (`0xd9B41FaB7cD36C99F0385758a66925e2a625E5Ed`), and Stable (`0x2d8287BfA75EaC73A9D6Dc2321135BB660c929d3`) were newly submitted and accepted.
- The automated post-submission explorer sweep returned 13 verified and transiently classified Ethereum as unverified even though Forge's preflight said it was already verified. A direct follow-up Etherscan V2 `getsourcecode` query for Ethereum `0x990B8ced8A1f61c4960119062b2d96bDC15140EC` returned status `1`, message `OK`, contract name `StargateAdapterV2`, and 64,260 characters of published source. Final confirmed public verification result is therefore 14/14.

## Production hook public-verification audit (2026-07-21)
- Audited exactly `script/output/prod/latest.json`, selecting every contract entry whose name ends in `Hook` across all 16 network sections.
- Scope: 965 hook deployment entries. Etherscan V2 `getsourcecode` was used for all supported networks and Flare Blockscout for Flare. The audit was read-only and made no verification submissions.
- Initial result: 687 publicly verified and 278 apparently unverified, with 0 API errors. Re-queried all 278 misses at a conservative global request rate; all 278 remained unverified and there were again 0 API errors.
- The 278 unverified deployment entries collapse to 65 distinct hook names.
- Large repeated groups: four hooks are unverified on all 16 networks (`ApproveAndCCTPSendHook`, `CCTPSendHook`, `ClaimFailedTransferHook`, `Withdraw7540VaultHook`); six are unverified on the same 11-network set (`ApproveERC20Hook`, `BatchTransferFromHook`, `BatchTransferHook`, `OfframpTokensHook`, `TransferERC20Hook`, `TransferHook`); `ApproveAndStargateSendHook` and `StargateSendHook` are unverified on 10 networks; `MerklClaimRewardHook` is unverified on a different 10-network set; both Odos V3 hooks are unverified on nine; `PendleRouterRedeemHook` and `PendleUnifiedHook` are unverified on eight; both Uniswap V3 Router02 hooks are unverified on six.
- Fourteen WithId/basic vault hooks are unverified on Stable and HyperEVM. Twenty-one additional hooks are unverified only on Linea, three only on Flare, and four only on HyperEVM. The remaining multi-network groups are documented in the user-facing result for this turn.
- Wrote the grouped audit result to `script/output/prod/unverified-hooks-report.md` at the user's request. The report links to `latest.json`, records the audit methodology and totals, lists all 65 unverified hook names by exact network set, and notes that the unverified Linea Set/Mark entries are the older production addresses.

## Flare-only and HyperEVM-only hook verification (2026-07-21)
- User authorized public verification of the three Flare-only and four HyperEVM-only misses from the production hook audit.
- Added missing verification-script support for `ClaimRFLRV3Hook`: it now shares the deployed Flare RNat constructor argument mapping with Claim RFLR V1/V2 and maps to `src/hooks/claim/flare/ClaimRFLRV3Hook.sol`. This support remains in the script; temporary chain/contract filters were restored after the run.
- All seven submissions were accepted and the independent explorer status sweep confirmed 7/7 publicly verified, 0 unverified, 0 failed, and 0 skipped. Flare Blockscout confirmed its three hooks; Etherscan V2 chain 999 confirmed the four HyperEVM hooks.
- Updated `script/output/prod/unverified-hooks-report.md`: current totals are 694 verified, 271 unverified, and 58 distinct remaining unverified hook names. Removed the two resolved groups from the unverified section and added a completed follow-up section with all seven addresses.

## Pendle hook inventory (2026-07-21)
- Read-only source and production-manifest inspection found seven Pendle-specific hooks:
  - `PendleUnifiedHook`: preferred router hook; supports `swapExactTokenForPt`, `swapExactPtForToken`, and `redeemPyToToken`, including routed redemption output.
  - `PendleRouterSwapHook`: legacy/deprecated token-to-PT and PT-to-token router hook.
  - `PendleRouterRedeemHook`: legacy/deprecated PT+YT redemption hook.
  - Purchase accounting: `RecordPurchasePendlePTAmortizedOracleHook` and `RecordPurchasePendlePTAmortizedOracleHookV2`.
  - Redemption accounting: `RecordRedemptionPendlePTAmortizedOracleHook` and `RecordRedemptionPendlePTAmortizedOracleHookV2`.
- Three generic ERC-5115 hooks directly use Pendle's `IStandardizedYield` and can operate on Pendle SY contracts: `ApproveAndDeposit5115VaultHook`, `Deposit5115VaultHook`, and `Redeem5115VaultHook`.
- In `script/output/prod/latest.json`, all four accounting hooks and all three ERC-5115 hooks are listed on all 16 production networks. The three router hooks are listed on Ethereum, Base, BNB, Arbitrum, Optimism, Berachain, Sonic, and HyperEVM.
- No source, deployment, or manifest changes were made for this inventory; only this required session handoff was appended.

## Selected Pendle hook live-bytecode audit (2026-07-21)
- User asked whether the production JSON addresses for `PendleUnifiedHook`, `RecordPurchasePendlePTAmortizedOracleHook`, and `RecordRedemptionPendlePTAmortizedOracleHook` carry the latest bytecode from current source.
- Ran `forge clean && forge build --skip test`; the fresh Solc 0.8.30 build succeeded with only the known duplicate memory-safe annotation and unused `ConfigCore.env` parameter warnings.
- Queried every production-manifest entry for the three hooks over the configured live RPCs, validating each RPC chain ID first. `PendleUnifiedHook` has 8 manifest entries; each accounting hook has 16, for 40 live comparisons total and no RPC errors.
- Compared live runtimes against both the fresh Foundry artifacts and committed `script/locked-bytecode` artifacts, zeroing only each artifact's compiler-declared immutable/link ranges before comparison. All mismatches to fresh source were already runtime-length mismatches:
  - `PendleUnifiedHook`: 0/8 fresh matches; 8/8 production-lock matches. Live/lock runtime is 11,051 bytes; fresh runtime is 14,231 bytes.
  - `RecordPurchasePendlePTAmortizedOracleHook`: 0/16 fresh matches; 16/16 production-lock matches. Live/lock runtime is 4,360 bytes; fresh runtime is 5,563 bytes.
  - `RecordRedemptionPendlePTAmortizedOracleHook`: 0/16 fresh matches; 16/16 production-lock matches. Live/lock runtime is 4,210 bytes; fresh runtime is 5,421 bytes.
- Conclusion: if “latest” means the current `src/` build, none of these production JSON entries is latest. If “latest” means the committed production lock, every entry is correct and exact.
- Sampled blocks ranged from Ethereum 25,579,897 through the corresponding latest blocks on all 16 networks; exact per-network blocks were emitted by the audit command. No source, lock, deployment, or manifest files were changed; only build outputs were refreshed and this session handoff was appended.

## Pendle selected-hook production deployment plan (superform-hook-master, 2026-07-21)

### Decision and exact scope
- Deploy only the current-source versions of `PendleUnifiedHook`, `RecordPurchasePendlePTAmortizedOracleHook`, and `RecordRedemptionPendlePTAmortizedOracleHook`. Do not deploy either deprecated Pendle router hook, either V2 accounting hook, either Pendle oracle, or any unrelated current lock.
- Preserve current production-manifest coverage rather than expanding protocol availability:
  - `PendleUnifiedHook` on exactly 8 chains where it is already listed and the configured Pendle router is available: Ethereum (1), Base (8453), BNB (56), Arbitrum (42161), Optimism (10), Berachain (80094), Sonic (146), and HyperEVM (999).
  - Both V1 accounting hooks on all 16 production chains: Ethereum (1), Base (8453), BNB (56), Arbitrum (42161), Optimism (10), Polygon (137), Unichain (130), Avalanche (43114), Linea (59144), Berachain (80094), Sonic (146), Gnosis (100), Worldchain (480), HyperEVM (999), Flare (14), and Stable (988).
- This is 40 deterministic deployments at most: 3 contracts on each of the 8 Pendle-router chains and 2 contracts on each of the other 8 chains. Deployment is additive; no existing hook address is mutated or removed.

### Constructor dependencies and deterministic outputs
- `PendleUnifiedHook(address pendleRouterV4_)`: use `0x888888888889758F76e7103c6CbF23ABbF58F946` on all 8 supported chains, as configured in `ConfigCore`. Preflight must require nonzero runtime code and confirm the currently manifested Unified hook exposes the same immutable router.
- Both V1 accounting hooks take `address oracle_`: use the per-chain `PendlePTAmortizedOracle` value from the existing production per-chain JSON. It is currently `0xD64089698f82cbCD91ba5e0422aDFa81D247eB62` on all 16 chains. Preflight must require the manifest entry, nonzero runtime code, and confirm both currently manifested accounting hooks expose the same `ORACLE()` value. Do not recompute or redeploy the oracle.
- Use the existing deterministic deployer `0x4e59b44847b379578588920cA78FbF26c0B4956C`, production salt namespace `PROD1.0.0`, and each existing contract name as its salt name.
- From the current fresh artifacts and those constructor values, the expected cross-chain addresses are:
  - `PendleUnifiedHook`: `0xcaC0E768bF0246D40E09090c6a0141773d6F8288`.
  - `RecordPurchasePendlePTAmortizedOracleHook`: `0x24586fDD3FB9FF366BbAf0706BcEd0b2294bDD8b`.
  - `RecordRedemptionPendlePTAmortizedOracleHook`: `0x190BfE6EADA5a2504dbaf5d9F0B8F52B36981Dc3`.
- Fresh creation artifacts recorded during planning:
  - Unified: 14,554 bytes, hash `0x50f6d692f73c2ba7bb1171b4d632cbdb5c01e50039ca7793232748761a4efc61`; init-code hash with router `0x08a82d65ac0253e7206cdfa4b0ff85c0f2a124e6fc3b66ddc66a38a005b813a2`.
  - Purchase: 5,830 bytes, hash `0x75c13051991e4a681956f903c49ed47a30f91faab45e6f67217e1d451f3ed08a`; init-code hash with oracle `0xe9f2ed0e96dc6b2dc20a71425006123e2c82134bb56511c9f3a60d79c0969b50`.
  - Redemption: 5,688 bytes, hash `0x87614392199640175871413ed9d77494628d56113c073db0dd748bb98ac71c39`; init-code hash with oracle `0xe2817192a0d17d2730c1eacd5e99715f3e92c47553b563424a838a97ddd9d234`.

### Minimal implementation and artifact promotion
1. Start from a clean view of the current `dev` commit while preserving unrelated dirty files. Rebuild with Solidity 0.8.30 and run the focused Pendle tests: the three unit suites, `PendlePTAmortizedOracleHooks.t.sol`, `PendleUnifiedHook.t.sol`, and feasible Pendle integration/E2E suites. Record any pre-existing unrelated full-suite compilation blockers separately.
2. Promote the complete fresh Foundry artifacts for exactly these three names into `script/generated-bytecode/`, `script/locked-bytecode-dev/`, and `script/locked-bytecode/`. After copying, require byte-for-byte creation-code equality and matching ABI/artifact identities across fresh, generated, dev-lock, and production-lock copies. No other lock artifact may change.
3. Do not invoke the broad `run(bool,uint256,uint64)` production path: current promoted locks for other contracts, including the partially deployed Set/Mark rollout, make that entrypoint capable of deploying unrelated contracts.
4. Add a temporary fixed-scope `runTemporaryPendleHookUpgrade(bool check,uint256 env,uint64 chainId)` entrypoint to `DeployV2Core.s.sol`, modeled on `runTemporaryTokenHookUpgrade`. Restrict it to `env == 0`, require `block.chainid == chainId`, validate fresh/generated/prod-lock artifact equality, parse and validate constructor dependencies from configuration/that chain's existing production JSON, derive and log the exact salt/init-code hash/address, and select only the 2 or 3 in-scope hooks according to existing manifest presence. `check=true` must never call `vm.startBroadcast` or write output. `check=false` must deploy only missing predicted addresses and remain idempotent. Output writing should be explicit and merge-only so no unrelated manifest entry can be dropped.

### No-broadcast preflight and signer/funding gate
5. Run the targeted entrypoint with `check=true` against all 16 RPCs. Require: RPC chain ID matches; deterministic deployer has code; every selected constructor dependency has code; manifest dependency values agree with the old hooks' immutables; all three artifact-equality guards pass; selected counts are 3 on the 8 router chains and 2 elsewhere; and every fresh predicted address is either empty or already contains the exact expected runtime. Abort globally on a dependency, address, artifact, RPC, or unexpected-code mismatch.
6. Build exact deterministic-deployer calldata and run `eth_estimateGas` for every missing deployment. Unlock the existing 1Password-backed production signer without printing secret material and verify its derived address remains `0x91489D9c003A65eBd7C351dA60D01be71fA18FC9`. For each chain, check pending nonce, current native balance, gas price/base fee, and a conservative total-cost allowance for its 2 or 3 transactions. Funding is a hard per-chain gate; Linea, Berachain, Sonic, Gnosis, and Worldchain deserve explicit attention because a previous selected-hook rollout intentionally omitted them. Do not broadcast on an underfunded chain; report/fund it or leave that chain on old manifests.

### Broadcast order and partial-rollout behavior
7. Use Base as the canary because it exercises all three constructors at relatively low cost. Broadcast sequentially (`--slow`, batch size 1): Unified, purchase, then redemption. Wait for receipts and complete the runtime/immutable checks below before proceeding.
8. After the Base canary passes, broadcast chain by chain, sequentially within each chain. A practical order is the other 7 three-hook chains first (Optimism, Arbitrum, BNB, Ethereum, HyperEVM, Berachain, Sonic), followed by the 8 accounting-only chains (Polygon, Unichain, Avalanche, Linea, Gnosis, Worldchain, Flare, Stable), subject to live funding/gas conditions. Record every transaction hash and receipt status. Stop a chain after any failure; do not update that chain's manifest.
9. The entrypoint must be resumable/idempotent by checking predicted-address code first. A partial rollout is acceptable operationally because the deployments are additive. There is no on-chain deletion rollback; rollback means retaining/restoring the old manifest address. Any successfully deployed but unpublished new address can remain dormant.

### Post-deployment checks, manifests, and public verification
10. Before changing manifests, query `eth_getCode` directly at every new address on every successfully deployed chain. Compare runtime length and bytecode to the current Foundry runtime after normalizing only compiler-declared immutable/link-reference ranges. Also call `PENDLE_ROUTER_V4()` or `ORACLE()`, `name()`, and relevant interface/version getters to confirm constructor wiring and basic ABI behavior. Require all expected deployments on a chain to pass; otherwise keep that whole chain's old entries.
11. Reconcile only validated chains' per-chain production JSONs through the fixed-scope merge path: update the two accounting-hook keys everywhere successfully completed and the Unified key only on successfully completed router chains. Regenerate `script/output/prod/latest.json` with `./script/run/tooling/generate_latest_json.sh prod`. Semantically assert that the only address changes are these in-scope keys on validated chains plus aggregate `updated_at`; all JSON must parse and `git diff --check` must pass.
12. Scope `script/run/verify/verify_v2_staging_prod.sh` (or a temporary wrapper without overwriting unrelated local edits) to these three contract names and only the chains whose manifests were updated. Its constructor mappings already support the three hooks. Submit verification through Etherscan V2/Flare Blockscout as appropriate, then independently query explorer APIs until every updated address is publicly verified. Restore temporary verifier filters afterward and record final verified counts.
13. Final handoff must include promoted artifact hashes, deterministic addresses, chain-by-chain dependency/preflight result, funding/skipped chains, transaction hashes, normalized runtime results, exact semantic manifest diff, explorer results, and any dormant deployments. Do not perform registry, S3, bundler, strategy, or consumer rollout without separate authorization.

### Approval gate
- This plan is ready for Master Codex review. Per repository instructions, no artifact promotion, deployment-entrypoint edit, signing, broadcast, manifest mutation, or explorer submission should begin until the master approves it.

## Selected Pendle hook deployment preparation (2026-07-21)
- Master Codex reviewed and approved the `superform-hook-master` plan after the user authorized starting deployment. Exact scope remains Unified on its existing 8 production chains and the two V1 accounting hooks on all 16 production chains; no V2, deprecated router, oracle, or unrelated deployment is authorized.
- Promoted the fresh Foundry artifacts for exactly the three selected hooks into `script/generated-bytecode`, `script/locked-bytecode-dev`, and `script/locked-bytecode`. All nine promoted copies are byte-for-byte equal to the fresh artifacts:
  - Unified creation: 14,554 bytes, `0x50f6d692f73c2ba7bb1171b4d632cbdb5c01e50039ca7793232748761a4efc61`.
  - Purchase creation: 5,830 bytes, `0x75c13051991e4a681956f903c49ed47a30f91faab45e6f67217e1d451f3ed08a`.
  - Redemption creation: 5,688 bytes, `0x87614392199640175871413ed9d77494628d56113c073db0dd748bb98ac71c39`.
- Added `runTemporaryPendleHookUpgrade(bool,uint256,uint64)` to `script/DeployV2Core.s.sol`. It is production-only, checks the real chain ID and deterministic deployer, reads current production JSON dependencies, verifies current hook immutable getters, preserves manifest scope, requires fresh/generated/prod-lock equality, calculates deterministic addresses, and deploys only missing selected hooks. Output writing is opt-in and remains disabled.
- `forge build --skip test` succeeds after the entrypoint addition. The focused `PendleUnifiedHook` test invocation is blocked before test execution by the same unrelated existing `view`-mutability errors in `MinimalBaseNexusIntegrationTest.t.sol` and `StargateAdapterE2EFork.t.sol`.
- Ran the fixed-scope entrypoint in `check=true` mode on all 16 production RPCs. All dependency, chain-ID, deployer-code, artifact, constructor-wiring, and address checks passed. All 40 selected predicted addresses are empty: 3 missing on each router chain and 2 missing on each other chain.
- Confirmed deterministic production addresses:
  - Unified: `0xcaC0E768bF0246D40E09090c6a0141773d6F8288`.
  - Purchase: `0x24586fDD3FB9FF366BbAf0706BcEd0b2294bDD8b`.
  - Redemption: `0x190BfE6EADA5a2504dbaf5d9F0B8F52B36981Dc3`.
- Direct `eth_estimateGas` passed for all 40 transactions from signer `0x91489D9c003A65eBd7C351dA60D01be71fA18FC9`. Every chain had equal latest/pending nonces. With a conservative 2x gas-price allowance, 11 chains are funded: Ethereum, Base, BNB, Arbitrum, Optimism, Polygon, Unichain, Avalanche, HyperEVM, Flare, and Stable. Five have zero signer balance and are gated: Linea, Berachain, Sonic, Gnosis, and Worldchain.
- The Base canary has **not** been broadcast. The 1Password CLI session expired before signer loading; two interactive `op signin` attempts timed out awaiting desktop approval, including after foregrounding 1Password. No private key was printed, no transaction was signed or sent, no manifest was changed, and no explorer verification was submitted. Work is paused pending the user unlocking/approving 1Password CLI access.

## Selected Pendle hook production broadcast (2026-07-21)
- The user approved the explicit 1Password request. The unlocked `Deployer pk` still derives to the required production signer `0x91489D9c003A65eBd7C351dA60D01be71fA18FC9`; no secret material was printed.
- Base was used as the canary. All three transactions succeeded, and direct live checks confirmed exact normalized fresh runtime plus correct immutable wiring (router `0x888888888889758F76e7103c6CbF23ABbF58F946`; oracle `0xD64089698f82cbCD91ba5e0422aDFa81D247eB62`). Base transaction hashes: Unified `0xd6ebae5a43a82e6cabf06553f151bef3bfea46da9dce861913ecdf0cc898888c`, purchase `0xb67164b4d54acdc800cb8d8343fa94f7cf7fb2180b98d347e9e11ba09f3213de`, redemption `0xfd1b7eb761fe3cf455e1bbc1084fad431a5d7fd8535d7bd7082cbe7681bd89ea`.
- Sequential broadcasts then succeeded on Optimism, Arbitrum, BNB, and Ethereum for all three hooks, and on Polygon, Unichain, Avalanche, Flare, and Stable for both accounting hooks.
- HyperEVM rejected the first Unified deployment before inclusion: its block gas limit is exactly 3,000,000 while direct `eth_estimateGas` for the Unified deterministic-deployer call is 3,192,921 (Foundry's default padded limit was 4,338,135). No Unified transaction hash or receipt exists and signer latest/pending nonce remained equal after the rejection. Added the explicit `TEMPORARY_PENDLE_HOOK_SKIP_UNIFIED` flag, restricted in the entrypoint to chain 999, rebuilt successfully, and deployed the two viable accounting hooks on HyperEVM. The old Unified manifest entry will remain there.
- Total successful new deployments: 27 across 11 funded chains: Unified on Base, Optimism, Arbitrum, BNB, and Ethereum; purchase and redemption on those five plus HyperEVM, Polygon, Unichain, Avalanche, Flare, and Stable. The five zero-balance chains remain unbroadcast: Linea, Berachain, Sonic, Gnosis, and Worldchain.
- All broadcast JSON receipts inspected during the rollout have success status. Final all-chain live-runtime/wiring validation, selective production-manifest reconciliation, aggregate regeneration, and public explorer verification are still in progress.

## Selected Pendle hook deployment completion and verification (2026-07-21)
- Audited all 27 successful broadcast receipts: every status is `0x1`, and each broadcast JSON contains exactly the intended contract names. Transaction hashes:
  - Ethereum: Unified `0x797e013a6a766cb0374bdceb436a5ba420261d856bfa0a571515e4f909833231`; purchase `0xb6553ca2fdf1904e14945175f42e1a8127b38f5907907295c6c8b48b4129b842`; redemption `0x10617f3127dc715ab97f6b2ed5531c6b2147cf0a904a66e9ae0eea84558b3975`.
  - Base: Unified `0xd6ebae5a43a82e6cabf06553f151bef3bfea46da9dce861913ecdf0cc898888c`; purchase `0xb67164b4d54acdc800cb8d8343fa94f7cf7fb2180b98d347e9e11ba09f3213de`; redemption `0xfd1b7eb761fe3cf455e1bbc1084fad431a5d7fd8535d7bd7082cbe7681bd89ea`.
  - BNB: Unified `0x0af175f6140ef9bf9c3a59b1a5f0638789405dade291488e8829dcffbfe53a1f`; purchase `0x0972904fbec7763d36f5ef14e36506aa744b8da1db98b22cfbfdd994e83bd1fb`; redemption `0xf066a176804e7bb50dc8bb7e6ffa43dc27737682e6231ae175eb376ccb955620`.
  - Arbitrum: Unified `0x2c1babc85f20b6def02cee92dc214345560f7fddac6966c4afb42f2843ef19d4`; purchase `0x535f83795639f4b30a0d0432797eceefc4f07592c42e26825f10b32a6cbd4058`; redemption `0x8a58908fa2b68824c076154a9ef81f2330a88f31f9d6603291f21aa82dc1804e`.
  - Optimism: Unified `0xdd26d72f9387e2a14c8a232dcc5535cf8d52da476257019206ee16cfd5c6bfd0`; purchase `0xee63c9e0c22e3101ca38042ec1afe6cd1198284194c2756c85007f6c19996263`; redemption `0x99b003ab5ad0ee1c28bf8bee5b873c5dbec4dd8838a7663d03b04e025728b604`.
  - Polygon: purchase `0x03a78cc75e6aafeaf21f61dd8981e34c82ba0d4de94d0ac4b86ad180e537ca36`; redemption `0xdf9740bc1483f57dc2829b7e1676dd0d5a4ee104a5184ce9bbc0dbe50168013f`.
  - Unichain: purchase `0x039d3fe994e7bf53356977c797fe9bce284a3b600701cc55b5fbb3c0f5c10fc1`; redemption `0x0b24dc6aed2e230ca92e0b459e26392cd1aef9b3536a269d4deb9cb244981aa6`.
  - Avalanche: purchase `0xc84648b5023ffe3a4d6fc95e71b94f63c3845ccd4ce73e8d54c07e89714311e6`; redemption `0xa5d060140f32fd7be221255246be4ac8bcdbb35b7692d52dc114b474e4a1edea`.
  - HyperEVM: purchase `0x4e7d3b832c7197c429a9ffba00e7662216fe6e119028f44ffe85600996be8568`; redemption `0x5c43930bd5aefe06fc6485b1804e21e76a50ef01dcc27d86a592ba55881153fc`.
  - Flare: purchase `0x7a3517480861f49bd624c37b3d314fa829ebe1c8699df36630edae4a02dfc139`; redemption `0x47e3faa848516a7d2e8bc19680784b4db3f55dd608c8fb1df47e9b420e93dd91`.
  - Stable: purchase `0xbd59cfbd02c810c2961ad6876661a43ecbd03173d1c6aadcc36d2a4327394bf5`; redemption `0xe017c719f9a11db47e47cfe07462c225d0f4bd391392a3a361772ca3fef67f8b`.
- Direct RPC validation passed for all 27 live contracts. Runtime sizes are Unified 14,231 bytes, purchase 5,563 bytes, and redemption 5,421 bytes; every runtime exactly matches the final fresh artifact after zeroing only compiler-declared immutable ranges. `name()` and immutable getters also passed on every target. HyperEVM's fresh Unified address is empty as intended.
- Confirmed every selected fresh address remains empty on all five funding-gated chains: Linea (2 targets), Berachain (3), Sonic (3), Gnosis (2), and Worldchain (2). Their production manifests remain unchanged.
- Updated exactly 27 fields in 11 per-chain production manifests: all three addresses on Ethereum, Base, BNB, Arbitrum, and Optimism; only purchase/redemption on Polygon, Unichain, Avalanche, HyperEVM, Flare, and Stable. HyperEVM Unified remains at the old production address. Regenerated `script/output/prod/latest.json`.
- Semantic manifest validation passed: each updated per-chain file changes only its authorized two or three Pendle keys; the five skipped files have no diff; aggregate `latest.json` changes exactly those 27 contract paths plus `updated_at` (28 scalar paths total). All JSON parses and `git diff --check` passes.
- Submitted public source verification for all 27 new manifest entries without modifying the user's existing verifier filters. All 27 submissions were accepted. An independent explorer sweep confirmed published source at 27/27: Etherscan V2 for applicable chains and Flare Blockscout for chain 14.
- Final artifact promotion is byte-for-byte equal between the final successful Foundry output and all three destinations (`generated-bytecode`, `locked-bytecode-dev`, `locked-bytecode`) for each selected hook. Creation hashes remain Unified `0x50f6d692f73c2ba7bb1171b4d632cbdb5c01e50039ca7793232748761a4efc61`, purchase `0x75c13051991e4a681956f903c49ed47a30f91faab45e6f67217e1d451f3ed08a`, redemption `0x87614392199640175871413ed9d77494628d56113c073db0dd748bb98ac71c39`. Final `forge build --skip test` succeeds with only the two known warnings.
- The temporary fixed-scope deployment entrypoint is intentionally retained so the five unfunded chains can be resumed idempotently later. No registry, S3, bundler, strategy, or consumer rollout was performed.

## Pendle deployment pull request and HyperEVM big-block follow-up (2026-07-21)
- Created a clean worktree from the latest `origin/dev` and opened [PR #954](https://github.com/superform-xyz/v2-core/pull/954) from `codex/pendle-hook-production-deployment`. The original dirty `dev` worktree was not rebased, committed, or cleaned.
- The PR initially contained exactly 22 intended files: the fixed-scope deployment entrypoint, nine promoted artifacts, eleven updated per-chain production manifests, and aggregate `script/output/prod/latest.json`. Commit `0012ef45` is `chore: deploy updated Pendle hooks`.
- CI correctly reported that generated `manifests/hooks.json` was stale after the production-address changes. Regenerated it with `tooling/generate_hook_manifest.py`, validated all 123 hooks with `tooling/lint_hook_manifest.py`, and pushed commit `6c6adf9d` (`chore: regenerate hook manifest`). The PR now contains 23 intended files.
- Local verification-script edits, `script/run/verify/verify_selected_hooks_temp.sh`, `script/output/prod/unverified-hooks-report.md`, and `.Codex` session files remain excluded from the PR. The latest-dev PR worktree passes `forge build --skip test`, hook-manifest lint, JSON parsing/semantic checks, artifact equality checks, and `git diff --check`.
- Official Hyperliquid documentation confirms the dual-block deployment path: normal blocks are limited to about 3M gas on the live RPC, large/slow blocks allow 30M gas, `evmUserModify` with `usingBigBlocks: true` routes an EOA to the large-block mempool, `eth_usingBigBlocks` reports the flag, and `eth_bigBlockGasPrice` reports the next large-block base fee. The flag must be disabled afterward.
- Live HyperEVM preflight for production signer `0x91489D9c003A65eBd7C351dA60D01be71fA18FC9` found big-block mode `false`, a 100,000,000 wei large-block gas price, nonce 11, sufficient HYPE, and no code at the fresh Unified address `0xcaC0E768bF0246D40E09090c6a0141773d6F8288`. The signer had no HyperCore user (`userRole: missing`), which is required before submitting `evmUserModify`.
- Sent the minimum exact HYPE Core unit (`0.00000001 HYPE`) from this signer to the official `0x2222...2222` EVM-to-Core system address to test self-initialization. Transaction `0x0729f54b660e99a8e273789dd78f764921367c85a48e9bfbd9c980e28752af47` succeeded, incrementing the EVM nonce to 12, but HyperCore held it in `evmEscrows` and the role remained `missing`.
- Official activation-fee documentation explains the outcome: a new HyperCore account requires a one-time fee of 1 quote token (for example 1 USDC, USDT, or USDH), regardless of the asset being transferred. The signer has no known EVM quote-token balance. No `evmUserModify` action was submitted, big-block mode remains `false`, and no Unified deployment transaction was signed or broadcast.
- PR #954 therefore still correctly retains the old HyperEVM Unified address while including the two successfully deployed accounting hooks. To finish HyperEVM Unified, first activate the signer by sending 1 quote token to it on HyperCore; then enable big blocks with the official SDK, broadcast only the idempotent missing Unified deployment using the big-block gas price, confirm runtime/wiring and public source verification, disable big blocks, and update the HyperEVM/aggregate/generated manifests plus PR.
- Follow-up activation attempt: the signer held exactly 1 native Circle USDC on HyperEVM at `0xb88339CB7199b77E23DB6E890353E22632Ba630f`. A direct ERC-20 transfer to the token system address reverted because Circle blacklists that address; the failed transaction was `0xbf57225ed0c449fbf2b21a6db510774515e9db0e1fb761ba94df8eb25c118d13` (status `0x0`).
- Used Circle's official HyperCore route instead: approved the mainnet `CoreDepositWallet` `0x6B9E773128f453f5c2C60935Ee2DE2CBc5390A24` for 1 USDC (`0xab075e16189d60da6db11085d053e60b45fe3590874c3dec15cb7bb663b4eb94`) and deposited 1 USDC to the signer’s HyperCore Spot balance (`0x72b7c54a5bbec04f10d0728c81a1f66d67e0f8e8b9add758866a60ba3d2928a4`). Circle documents this as the required `approve` + `deposit(amount, 4294967295)` flow.
- HyperCore still reports `userRole: missing`, with the 1 USDC visible in `evmEscrows` rather than a tradable balance. An attempted self `spotSend` returned `Must deposit before performing actions`. Therefore the signer still cannot submit `evmUserModify`; an already-activated HyperCore account must send an activation transfer to this signer, or the protocol/UI must complete the pending escrow activation. Big-block mode remains false and the Unified target remains empty.

## Production JSON live-bytecode presence audit (2026-07-21)
- User asked what other production JSON contract entries point to addresses without real bytecode.
- Created a temporary RPC cache at `/tmp/v2-core-prod-rpcs.env` with file mode `600`, containing only production RPC URLs loaded from 1Password. No deployer private key was cached and no secret values were printed.
- Audited the current local `script/output/prod/latest.json` against live `eth_getCode` on all 16 configured production networks, validating each RPC chain ID first.
- Scope: 1,572 contract entries and 1,572 unique chain/address pairs. All addresses were valid nonzero EVM addresses.
- Result: 0 missing-code entries across Ethereum, Base, BNB, Arbitrum, Optimism, Polygon, Unichain, Avalanche, Linea, Berachain, Sonic, Gnosis, Worldchain, HyperEVM, Flare, and Stable.
- One Stable batch read initially failed for `SpectraMetaVaultOracle` at `0x7564485A51213443CdCa944B768c56606A028974`; direct retry with `cast codesize` succeeded with code size `6389`, so it was an RPC transient and not a missing deployment.
- Confirmed all per-chain `script/output/prod/<chain>/<Network>-latest.json` contract maps match the aggregate `script/output/prod/latest.json` contract maps exactly.
- No deployment, signing, manifest mutation, PR mutation, or source-code change was performed for this audit.

## Production latest-source bytecode drift audit (2026-07-21)
- User clarified they wanted to know which production JSON entries need the latest version we currently have, not merely which addresses have any bytecode.
- Ran `forge build --skip test`; Foundry reported no files changed and skipped compilation, leaving the current artifacts intact.
- Reused `/tmp/v2-core-prod-rpcs.env` for RPC URLs only. Queried all 16 production networks and compared each manifest address's live runtime against the canonical current `src/` artifact, normalizing compiler-declared immutable and link-reference ranges.
- Scope: 1,572 production entries in `script/output/prod/latest.json`.
- Result: 909 entries already match current `src/` runtime; 602 entries are stale and need latest-source deployment or, if already deployed elsewhere, manifest reconciliation; 0 missing-code entries; 0 RPC errors.
- Not comparable: 61 entries across external/unowned `Nexus`, `NexusAccountFactory`, `NexusBootstrap`, `NexusProxy`, and Flare `DepositWFLRHook`.
- Stale Superform-owned contract names by identical network set:
  - All 16 production networks: `ApproveAndCCTPSendHook`, `ApproveAndDeposit5115VaultHook`, `ApproveAndStargateSendHook`, `ApproveAndStargateSendHookV2`, `CCTPSendHook`, `CancelDepositRequest7540Hook`, `CancelRedeemRequest7540Hook`, `CircleGatewayAddDelegateHook`, `CircleGatewayMinterHook`, `CircleGatewayRemoveDelegateHook`, `CircleGatewayWalletHook`, `ClaimCancelDepositRequest7540Hook`, `ClaimCancelRedeemRequest7540Hook`, `ClaimFailedTransferHook`, `Deposit5115VaultHook`, `EthenaCooldownSharesHook`, `EthenaUnstakeHook`, `PendlePTYieldSourceOracle`, `RecordPurchasePendlePTAmortizedOracleHookV2`, `RecordRedemptionPendlePTAmortizedOracleHookV2`, `Redeem5115VaultHook`, `Redeem7540VaultHook`, `StargateAdapter`, `StargateSendHook`, `StargateSendHookV2`, `Withdraw7540VaultHook`.
  - Ethereum only: `AaveV4BorrowHook`, `AaveV4RepayAndWithdrawHook`, `AaveV4RepayHook`, `AaveV4SupplyAndBorrowHook`, `AaveV4SupplyHook`, `AaveV4WithdrawHook`, `ApproveAndRequestRedeemDETHHook`, `ClaimAssetsDETHHook`, `RequestRedeemDETHHook`.
  - Flare only: `ApproveAndSwapUniswapV2Hook`, `ClaimRFLRHook`, `ClaimRFLRV2Hook`, `ClaimWithdrawFirelightVaultHook`, `RedeemFirelightVaultHook`, `SwapUniswapV2Hook`, `WithdrawRFLRHook`, `WithdrawVestedRFLRHook`.
  - Base only: `ApproveAndSwapSparkPSMExactInHook`, `ApproveAndSwapSparkPSMExactOutHook`, `SwapSparkPSMExactInHook`, `SwapSparkPSMExactOutHook`.
  - Linea, Berachain, Sonic, Gnosis, Worldchain: `MarkRootAsUsedHook`, `RecordPurchasePendlePTAmortizedOracleHook`, `RecordRedemptionPendlePTAmortizedOracleHook`, `SetSlippageHook`.
  - Berachain, Sonic, HyperEVM: `PendleUnifiedHook`.
  - Ethereum, Base, BNB, Arbitrum, Optimism, Berachain, Sonic, HyperEVM: `PendleRouterRedeemHook`, `PendleRouterSwapHook`.
  - Ethereum, Base, BNB, Arbitrum, Optimism, Polygon, Avalanche, Linea, Sonic: `ApproveAndSwapOdosV3Hook`, `SwapOdosV3Hook`.
  - Ethereum, Base, BNB, Arbitrum, Optimism, Polygon, Unichain, Avalanche, Linea, Sonic: `ApproveAndSwapOdosV2Hook`, `SwapOdosV2Hook`.
  - Ethereum, Base, BNB, Arbitrum, Optimism, Polygon, Unichain, Linea, Worldchain, HyperEVM: `AcrossSendFundsAndExecuteOnDstHook`, `AcrossSendFundsAndExecuteOnDstHookV2`, `ApproveAndAcrossSendFundsAndExecuteOnDstHook`, `ApproveAndAcrossSendFundsAndExecuteOnDstHookV2`.
  - Ethereum, Base, BNB, Arbitrum, Optimism, Polygon, Unichain, Avalanche, Linea, Worldchain, Stable: `ApproveAndSwapUniswapV3Router02Hook`, `SwapUniswapV3Router02Hook`.
  - Ethereum, Base, BNB, Arbitrum, Optimism, Polygon, Avalanche, Linea, Berachain, Sonic, Gnosis, HyperEVM: `DeBridgeCancelOrderHook`, `DeBridgeSendOrderAndExecuteOnDstHook`.
  - Ethereum and Flare: `WrappedNativeHook`.
- No deployment, signing, manifest mutation, PR mutation, or source-code change was performed for this audit.

## ERC-7540 hook production deployment and PR (2026-07-21)
- User asked to deploy the ERC-7540-related hooks identified from the latest-source drift audit. Scope used:
  - `CancelDepositRequest7540Hook`
  - `CancelRedeemRequest7540Hook`
  - `ClaimCancelDepositRequest7540Hook`
  - `ClaimCancelRedeemRequest7540Hook`
  - `Redeem7540VaultHook`
  - `Withdraw7540VaultHook`
  - `SetSlippageHook` in the fixed-scope preflight/deployment entrypoint because it lives under `src/hooks/vaults/7540` and was stale on the five previously unfunded chains.
- Promoted fresh current-source artifacts for the six missing ERC-7540 hooks into `script/generated-bytecode`, `script/locked-bytecode-dev`, and `script/locked-bytecode`. `SetSlippageHook` was already promoted/deployed from the earlier Set/Mark rollout.
- Added a temporary production-only `runTemporary7540HookUpgrade(bool check, uint256 env, uint64 chainId)` entrypoint to `script/DeployV2Core.s.sol`. It selects only the seven names above, requires the deterministic deployer to exist, validates current manifest entries have code, validates deterministic predicted addresses, is idempotent, and only writes output if `TEMPORARY_7540_HOOK_WRITE_OUTPUT=true`.
- No-broadcast preflight across all 16 production chains:
  - Ethereum, Base, BNB, Arbitrum, Optimism, Polygon, Unichain, Avalanche, HyperEVM, Flare, Stable: selected 7, deployed 1, missing 6 (`SetSlippageHook` already deployed).
  - Linea, Berachain, Sonic, Gnosis, Worldchain: selected 7, deployed 0, missing 7.
- Signer/funding gate for `0x91489D9c003A65eBd7C351dA60D01be71fA18FC9`:
  - Funded and deployed: Ethereum, Base, BNB, Arbitrum, Optimism, Polygon, Unichain, Avalanche, HyperEVM, Flare, Stable.
  - Zero-funded and skipped: Linea, Berachain, Sonic, Gnosis, Worldchain. Their production manifests remain unchanged for these six hooks and `SetSlippageHook`.
- Broadcasts succeeded on all 11 funded chains, six deployments per chain. HyperEVM used the special low gas-price/no-priority path; receipts succeeded there as well.
- New deterministic addresses on every deployed chain:
  - `CancelDepositRequest7540Hook`: `0x3a61580fc4f7a8c5d97574ca21bcd95656750cb0`
  - `CancelRedeemRequest7540Hook`: `0x60fd46210daca64d91b6bc6d6566238723514c8b`
  - `ClaimCancelDepositRequest7540Hook`: `0xd43dff350ccabfc4c9b3aaac01fff0858b312dc2`
  - `ClaimCancelRedeemRequest7540Hook`: `0x9b00d88cf0ecffa3c8cfb084b063ceeb42605d67`
  - `Redeem7540VaultHook`: `0xaabdd86b2ce655422f319c22765e26cfa6873943`
  - `Withdraw7540VaultHook`: `0xdd4d3e33a2231f4062e1c7df0991bae09b069e4e`
  - `SetSlippageHook`: remains the previously deployed fresh address `0x78Be4075B50dD4AD54044289bA20Ea1d8BFeab2F` on the 11 funded chains.
- Runtime validation passed for all 66 new deployments: direct `eth_getCode` on every deployed address matched the fresh Foundry runtime after normalizing compiler-declared immutable/link-reference ranges.
- Updated exactly the six new ERC-7540 hook addresses in the 11 deployed-chain production JSONs and regenerated `script/output/prod/latest.json`. Regenerated and linted `manifests/hooks.json`.
- Validation run:
  - `forge build --skip test` passed in the main worktree with only the known warnings.
  - Semantic JSON check passed: the 11 funded chains have the six new addresses, the five unfunded chains do not, and aggregate `latest.json` exactly matches per-chain contract maps.
  - Hook manifest generation/lint passed with 123 hooks.
  - `git diff --check` passed.
  - Artifact equality passed across generated/dev-lock/prod-lock and against the fresh build output.
- Public source verification:
  - Initial scoped verifier submitted/accepted 55 of 66 entries. All 11 failures were `Withdraw7540VaultHook`, caused by the verifier missing a 7540 source-path mapping and falling through to `src/core/unknown/Withdraw7540VaultHook.sol`.
  - Immediate explorer sweep confirmed 54 verified, 12 unverified: Withdraw on all 11 deployed chains plus Stable `ClaimCancelDepositRequest7540Hook`, whose submission had been accepted but was not yet visible in the sweep.
  - A corrected Flare-only Blockscout submission for `Withdraw7540VaultHook` succeeded and direct Blockscout status confirmed it verified.
  - Remaining public verification requires Etherscan V2 key access: corrected `Withdraw7540VaultHook` verification on the 10 Etherscan-backed deployed chains, plus a recheck of Stable `ClaimCancelDepositRequest7540Hook`.
  - Two `op signin` attempts for this shell timed out awaiting 1Password approval, so Etherscan-backed verification was left pending. No secret material was printed or cached.
- Created a clean PR worktree from latest `origin/dev` at `/tmp/v2-core-7540-pr-20260721` to avoid carrying local verifier/report/session changes or stale-base Pendle noise. The PR branch is `codex/erc7540-hook-production-deployment`, commit `6010c130` (`chore: deploy updated ERC7540 hooks`).
- Opened [PR #956](https://github.com/superform-xyz/v2-core/pull/956) to `dev`. The PR excludes `.Codex`, `script/run/verify/verify_v2_staging_prod.sh`, `script/run/verify/verify_selected_hooks_temp.sh`, and `script/output/prod/unverified-hooks-report.md`.

## ERC-7540 verification recheck completion (2026-07-21)
- User asked to recheck the remaining ERC-7540 public verification items.
- 1Password CLI auth succeeded. The Etherscan V2 API key was read into process environment only and was not printed or cached.
- Initial status recheck showed Stable `ClaimCancelDepositRequest7540Hook` at `0xd43dff350ccabfc4c9b3aaac01fff0858b312dc2` was now verified. `Withdraw7540VaultHook` at `0xdd4d3e33a2231f4062e1c7df0991bae09b069e4e` was still unverified on the 10 Etherscan-backed deployed chains.
- Submitted corrected source-path verification for `Withdraw7540VaultHook` using `src/hooks/vaults/7540/Withdraw7540VaultHook.sol:Withdraw7540VaultHook` on Ethereum, Base, BNB, Arbitrum, Optimism, Polygon, Unichain, Avalanche, HyperEVM, and Stable. All 10 submissions returned `Response: OK`.
- Final Etherscan V2 status polling confirmed all 11 checked entries are verified:
  - `Withdraw7540VaultHook` on Ethereum, Base, BNB, Arbitrum, Optimism, Polygon, Unichain, Avalanche, HyperEVM, and Stable.
  - Stable `ClaimCancelDepositRequest7540Hook`.
- Combined with the earlier confirmed Flare Blockscout verification, all 66 newly deployed ERC-7540 hook entries are now publicly verified. No repo source, production JSON, or PR branch files were changed during this recheck; only this session context was updated locally.
- Updated PR #956 body to replace the stale verification caveat with the final public verification result: all 66 newly deployed ERC-7540 hook entries are publicly verified.

## ERC-7540 latest-source confirmation after user challenge (2026-07-21)
- User asked whether the deployed addresses are definitely latest contract code and specifically asked if `forge compile` and `git pull` were done first.
- Corrected answer recorded:
  - A `forge build --skip test` was run before the ERC-7540 broadcast and passed with only known warnings.
  - A `git pull`/latest-base update was **not** done before the broadcast. The local `dev` worktree was later found behind `origin/dev`.
  - After the broadcast, a clean PR worktree was created from latest `origin/dev` at that time (`326c8766`) and PR #956 was built from that clean base.
- Current recheck after the user's challenge:
  - Fetched current `origin/dev`, now `fc83209b` (`chore: pinned dependency (#957)`), which advanced after PR #956's base.
  - The six ERC-7540 hook source files deployed in this rollout have no diff versus current `origin/dev`.
  - `foundry.toml`, remappings, and relevant build config have no diff between PR #956 and current `origin/dev`; only the six promoted bytecode artifacts differ as intended.
  - Ran `forge clean && forge build --skip test`; it compiled 701 files with Solc 0.8.30 and succeeded with only the two known warnings.
  - Clean-build creation bytecode for all six deployed ERC-7540 hooks exactly matches PR #956 production-lock artifacts:
    - `CancelDepositRequest7540Hook`: `5eb5d5971459321fb510aead3e7688cb14b09c5a4ef0644ab863446007ae1274`
    - `CancelRedeemRequest7540Hook`: `c6123ab65a5c503c28b71efef5af8b292d5398b53170ff54b3dbd5bb3b2d30b1`
    - `ClaimCancelDepositRequest7540Hook`: `95e9b3a5734ea6f81fc44073e27ef6879f121d0d03d48aa4a33935442fbadb93`
    - `ClaimCancelRedeemRequest7540Hook`: `0f55ad6ceeacafb1a971555bd290012b66924666c215a9d37975341e8a9420fd`
    - `Redeem7540VaultHook`: `da92e27bd6d3b8b9b28c6a9c1f46f0a064494d4e0bbba8cbd248de22b26b0760`
    - `Withdraw7540VaultHook`: `c09fb07e41675d6acddb402dcf0b366881ac27bf8c9501ad6e61b2a8d2c82050`
  - Direct RPC runtime comparison over all 66 deployed addresses confirmed every live runtime matches the just-clean-built runtime after immutable/link-reference normalization:
    - Ethereum, Base, BNB, Arbitrum, Optimism, Polygon, Unichain, Avalanche, HyperEVM, Flare, Stable: each 6/6 matches.
- Conclusion: despite not pulling before broadcast, the deployed ERC-7540 addresses do match the latest current-source clean build for those six hook contracts. PR #956 is based on `326c8766` and should be updated/rebased if reviewers require it to include the later dependency-pinning commit `fc83209b`; that later commit did not alter these hook sources or build configuration.

## Remaining latest-source deployment list response (2026-07-21)
- User asked which contracts from the previously created latest-source drift list still need deployment.
- Answer should be based on the 2026-07-21 1,572-entry drift audit adjusted for completed follow-up work:
  - Seven token hooks on Linea/Berachain/Sonic/Gnosis/Worldchain were already reconciled in manifests because latest code was already live.
  - Selected Pendle V1 accounting hooks were deployed/verified on 11 funded chains; they remain pending on Linea, Berachain, Sonic, Gnosis, and Worldchain.
  - `PendleUnifiedHook` was deployed/verified on Ethereum/Base/BNB/Arbitrum/Optimism; it remains pending on Berachain, Sonic, and HyperEVM. HyperEVM requires the big-block route once signer HyperCore activation is solved.
  - Six ERC-7540 hooks were deployed/verified on 11 funded chains; they remain pending on Linea, Berachain, Sonic, Gnosis, and Worldchain.
  - `SetSlippageHook` and `MarkRootAsUsedHook` were deployed/verified on 11 funded chains; they remain pending on Linea, Berachain, Sonic, Gnosis, and Worldchain.
- No fresh all-contract live drift audit was rerun for this response.

## ClaimFailedTransferHook and Flare RFLR/Firelight hook deployment (2026-07-21)
- User requested deployment of updated `ClaimFailedTransferHook` plus RFLR/Firelight hooks on Flare, with a requirement to make sure Flare deployment was actually needed.
- Work was continued in the clean PR worktree `/tmp/v2-core-7540-pr-20260721` on branch `codex/erc7540-hook-production-deployment`, rebased onto latest `origin/dev` at `fc83209b` (`chore: pinned dependency (#957)`) before compiling.
- Ran `forge clean && forge build --skip test`; the clean build compiled 711 files with Solc 0.8.30 and succeeded with only the known duplicate memory-safe assembly annotation and unused `ConfigCore.env` parameter warnings.
- Latest-source need check:
  - `ClaimFailedTransferHook` was stale on all 16 production chains. The current-source deterministic address was empty everywhere before deployment.
  - Flare RFLR/Firelight hooks stale and therefore deployed: `ClaimRFLRHook`, `ClaimRFLRV2Hook`, `ClaimWithdrawFirelightVaultHook`, `RedeemFirelightVaultHook`, `WithdrawRFLRHook`, and `WithdrawVestedRFLRHook`.
  - Flare hooks already current and not deployed: `ClaimRFLRV3Hook`, `WithdrawRFLRHookV2`, and `WithdrawVestedRFLRHookV2`.
  - `FirelightYieldSourceOracle` was excluded because it is an oracle, not a hook.
- Promoted fresh artifacts for exactly seven names into `script/generated-bytecode`, `script/locked-bytecode-dev`, and `script/locked-bytecode`:
  - `ClaimFailedTransferHook`
  - `ClaimRFLRHook`
  - `ClaimRFLRV2Hook`
  - `ClaimWithdrawFirelightVaultHook`
  - `RedeemFirelightVaultHook`
  - `WithdrawRFLRHook`
  - `WithdrawVestedRFLRHook`
- Added fixed-scope deployment entrypoint `runTemporaryClaimFailedAndFlareHookUpgrade(bool check, uint256 env, uint64 chainId)` to `script/DeployV2Core.s.sol`. It selects `ClaimFailedTransferHook` on every chain and the six stale RFLR/Firelight hooks only on Flare, validates existing manifest entries have live code, validates deterministic deployment targets, and only writes production JSON when `TEMPORARY_CLAIM_FLARE_HOOK_WRITE_OUTPUT=true`.
- Funding gate for signer `0x91489D9c003A65eBd7C351dA60D01be71fA18FC9`:
  - Funded and deployed: Ethereum, Base, BNB, Arbitrum, Optimism, Polygon, Unichain, Avalanche, HyperEVM, Flare, Stable.
  - Insufficient/zero native gas and skipped: Linea, Berachain, Sonic, Gnosis, Worldchain. Their production manifests remain unchanged for `ClaimFailedTransferHook`.
- New deterministic addresses:
  - `ClaimFailedTransferHook`: `0x0975cc0673D208b56c6D135554a3c26420825a45`
  - `ClaimRFLRHook`: `0x8704fAD97ab95d4a8392B0667fE08903a46d102b`
  - `ClaimRFLRV2Hook`: `0xfd0A3e316Ffe711d5302F91a30F02dbB7F35C95A`
  - `ClaimWithdrawFirelightVaultHook`: `0x44874B1fb19d4dA78175c0441295cbcB0A1d6884`
  - `RedeemFirelightVaultHook`: `0x9D573F3018baDD42Dd292d44F8887FBbCf488Dc8`
  - `WithdrawRFLRHook`: `0x45Eb9379f77867560114A398309b6444c51376e6`
  - `WithdrawVestedRFLRHook`: `0x44f6A4014776355B267D4B659a55184Bb968a387`
- Broadcast result:
  - `ClaimFailedTransferHook` deployed on 11 funded chains.
  - The six stale RFLR/Firelight hooks deployed on Flare.
  - HyperEVM succeeded on retry using the legacy low-gas-price route; no big-block route was needed for this contract.
  - Transaction hashes:
    - Ethereum `ClaimFailedTransferHook`: `0xd1946475a288dba22f5d6a18ba08eba317c18e3b38cb7566531e9b6cb239ca5c`
    - Base `ClaimFailedTransferHook`: `0x859cfe1200227c5372ccbd62990b2db9f430e845679a7690bf654af6290edfd8`
    - BNB `ClaimFailedTransferHook`: `0x855fee2ac6276d2e31e740db2113e50140343eba6c159d0182c4891cfd013995`
    - Arbitrum `ClaimFailedTransferHook`: `0xf3fe1d61bace24ca11f03b791690428edc2ed104b76e171c982e1c1ea59a9796`
    - Optimism `ClaimFailedTransferHook`: `0xdfaf7b8eabc9c74bf8d96c2a1dba0612ec6d5ec32db533bade36f3c680a2bd09`
    - Polygon `ClaimFailedTransferHook`: `0xa074edf72d8431faa19eace969e1878ee9d0e83492685fd144395da7d1a7a018`
    - Unichain `ClaimFailedTransferHook`: `0xbaf58e9d2440a12aaf495cdca23ab2209e07a7e4b53c9304dddefc1aa2b9bc2e`
    - Avalanche `ClaimFailedTransferHook`: `0xa842b5c9251ebdeb11c821edecf0f578571c0dcc789249d0a3ce6fbd96f7f586`
    - HyperEVM `ClaimFailedTransferHook`: `0x07803c13fb81d897c4954650080cd270bf655a686b7bd0c0b4ea601f6b3e7617`
    - Stable `ClaimFailedTransferHook`: `0xebbc95a47268f06f29210192cf6a93e26d7bb8875331a60f284019073f84cdda`
    - Flare `ClaimFailedTransferHook`: `0x3961ea044e6d79ec8d2413e50ab7e1c8bc45415860a129c23488076662a4ea45`
    - Flare `ClaimRFLRHook`: `0x21a37a630fb010fb9a7892be100f1bb85e52723b56c9db6d9a69bdb7908a2be5`
    - Flare `ClaimRFLRV2Hook`: `0x45697c77db9e55d7487cdf94cf11a47849a50ca222203603be73fe03a300a622`
    - Flare `ClaimWithdrawFirelightVaultHook`: `0x48b6bde860a7a35953bf5384a17e3275e9ab334613b6a68298f69828e02c0eba`
    - Flare `RedeemFirelightVaultHook`: `0x2e97bbacda41d1a71320283c6da006830dab6b096e4dda1d74cdf71b98bbfb94`
    - Flare `WithdrawRFLRHook`: `0xb3e8b09f70d99c081384910f881648cb172a3037609a5597e33b16e930cb0574`
    - Flare `WithdrawVestedRFLRHook`: `0xdb4eb63432e01c71ee124f2b1accf01f5587888093126a8fbb3433c2a596a742`
- Direct runtime validation passed for all 17 newly deployed entries. `eth_getCode` matched the fresh Foundry runtime after normalizing compiler-declared immutable/link-reference ranges.
- Flare constructor getter validation passed:
  - `ClaimRFLRHook` and `ClaimRFLRV2Hook` use RNAT `0x26d460c3Cf931Fb2014FA436a49e3Af08619810e`.
  - `WithdrawRFLRHook` and `WithdrawVestedRFLRHook` use RNAT `0x26d460c3Cf931Fb2014FA436a49e3Af08619810e` and WFLR `0x1D80c49BbBCd1C0911346656B529DF9E5c2F783d`.
- Public verification result: all 17 newly deployed entries are publicly verified. Etherscan V2 confirmed the 10 Etherscan-backed non-Flare deployments, and Flare Blockscout confirmed all seven Flare deployments.
- Production manifests:
  - Updated `ClaimFailedTransferHook` in the 11 funded-chain production JSONs and in aggregate `script/output/prod/latest.json`.
  - Updated the six stale RFLR/Firelight hook addresses in `script/output/prod/14/Flare-latest.json` and aggregate `script/output/prod/latest.json`.
  - The five skipped chains are unchanged and still point to their previous `ClaimFailedTransferHook` address until native gas is available.
  - Regenerated and linted `manifests/hooks.json`; lint passed with 123 hooks.
- Final local validation:
  - `forge build --skip test` passed from the clean rebased worktree.
  - Artifact equality passed across fresh Foundry output, generated bytecode, dev lock, and prod lock for all seven promoted hooks.
  - Semantic JSON check passed: exactly one changed address on each funded non-Flare chain, exactly seven changed addresses on Flare, no address changes on the five skipped chains, and aggregate `latest.json` matches all per-chain contract maps.
  - `git diff --check` passed.
  - Removed the exact Foundry sensitive-value cache files for `runTemporaryClaimFailedAndFlareHookUpgrade` on the 11 broadcast chains using `/bin/rm`.
- User subsequently requested pushing the JSON changes to the same PR. Committed only `manifests/hooks.json` and `script/output/prod/**/*.json` as `ede38e1e` (`chore: update prod json for claim and flare hooks`) and force-with-lease pushed branch `codex/erc7540-hook-production-deployment` to update [PR #956](https://github.com/superform-xyz/v2-core/pull/956). The PR now has two commits: the rebased ERC-7540 deployment commit and the JSON-only ClaimFailed/RFLR/Firelight manifest update. The PR body was appended with a concise note for this additional JSON-only deployment update.
- Temporary deployment-helper and bytecode-promotion changes for `ClaimFailedTransferHook` and the six Flare RFLR/Firelight hooks remain local and uncommitted in `/tmp/v2-core-7540-pr-20260721`; they were intentionally not pushed because the user asked to push only JSON changes.

## Polygon native hook redeployment - completed 2026-07-23

Updated the Polygon production native-token configuration from the Polygon system-token address (`0x0000000000000000000000000000000000001010`) to the canonical native sentinel (`0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE`) and added a production-only, Polygon-only temporary deployment entrypoint for exactly five hooks.

### Deployments

- `BatchTransferHook`: `0x6D69433fa474b3A14cB3479c584E61fAE1De7b9F`
  - Transaction: `0x5e13c4e431b5e3a32e29ae62519a7277a5eed76070ae05f74b19c25ec04c4b30`
  - Block: `90736487`
- `TransferHook`: `0x2a2CD39c1b72f85F291d06BD02f1f4CB2de5081A`
  - Transaction: `0x8232c22aee79ca9abaaef70ecc3916e1972739a39bc0da0b727cbdda17fc237d`
  - Block: `90736491`
- `Swap1InchHook`: `0xeFA058564f85408D994fC60164e7e32290352D6D`
  - Transaction: `0x1d489d97ee6f434fad143d3347f86e2075207a2e923028efb7c3f8a55e46383d`
  - Block: `90736494`
- `SwapKyberSwapHook`: `0x05c49e05bb8575afdf1142cC95dA6747b069174A`
  - Transaction: `0x8b27f2824cde2fc5daa3b636cd8511ccbc770b14be3aab4214f8f8928c7b46ff`
  - Block: `90736497`
- `ApproveAndSwapKyberSwapHook`: `0xcF5419270C9415E44c97E595c505708cfA334C30`
  - Transaction: `0x3e35b22a2cf57d793ab0e50149194d8fdfb4c9fa183c85825505872fad635b55`
  - Block: `90736499`

Deployment signer was `0x91489D9c003A65eBd7C351dA60D01be71fA18FC9`; total paid was `4.037299371509427188 POL`. The private key and RPC/API credentials were loaded from 1Password without being printed and the temporary encrypted Foundry keystore/cache artifacts were removed.

### Verification

- All five transaction receipts have status `1`.
- Runtime bytecode for all five addresses matches the fresh artifacts after normalizing compiler-declared immutable/link ranges.
- Native-token getters on all five return `0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE`.
- Hook names and dependency getters match the expected 1inch router, Kyber router, and scale helper addresses.
- The repository verification script reports all five contracts verified on the Polygon block explorer (`5` verified, `0` failed/unverified).
- `script/output/prod/137/Polygon-latest.json` and `script/output/prod/latest.json` changed semantically only for these five Polygon addresses (plus aggregate `updated_at`).
- `tooling/generate_hook_manifest.py` regenerated `manifests/hooks.json`; `tooling/lint_hook_manifest.py` passed with `123` hooks validated.
- `forge build --skip test` passed.
- Focused hook test commands remain blocked by unrelated pre-existing Solidity compile errors in `test/integration/MinimalBaseNexusIntegrationTest.t.sol` (`vm.getRecordedLogs()` in `view` functions) and `test/integration/stargate/StargateAdapterE2EFork.t.sol`.
- No generated or locked bytecode artifacts were modified.
