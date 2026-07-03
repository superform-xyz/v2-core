# Changes vs `dev` — `feat/hook-sizing-manifest`

158 files changed, 7654 insertions, 362 deletions

---

## Interface (`src/interfaces/ISuperHook.sol`)

- `decodeAmount(bytes) → decodeAmounts(bytes)` — array-based, supports multi-amount hooks
- `replaceCalldataAmount(bytes,uint256) → replaceCalldataAmounts(bytes,uint256[])` — array-based
- Added `Direction` enum (IN, OUT) — distinguish primary vs derived amounts
- Added `Denomination` enum (TOKEN, ASSETS, SHARES) — classify amount type
- Added `AmountMeta` struct (`Direction` + `Denomination`) — per-slot metadata
- Added `amountRoles(bytes) → AmountMeta[]` to `ISuperHookInflowOutflow` — OMS denomination/direction discovery

## Base Contracts

### `BaseHook.sol`
- Added `IERC165` inheritance — ERC-165 support
- Added `INVALID_AMOUNTS_LENGTH()` error — validate array lengths in replaceCalldataAmounts
- Added `supportsInterface(bytes4)` — three-state detection (sized / sizeless / legacy)
- Added `_supportsSizingInterface()` virtual — override pattern for sized hooks

### `BaseLoanHook.sol`
- Added `ISuperHookInflowOutflow` + `ISuperHookOutflow` inheritance — sizing interface
- Added `decodeAmounts()` — returns `[amount]`
- Added `amountRoles()` — returns `[(IN, TOKEN)]`
- Added `replaceCalldataAmounts()` — single-amount at `AMOUNT_POSITION=80`
- Added `_supportsSizingInterface() → true`

### `BaseAaveV4LoanHook.sol`
- Added `ISuperHookInflowOutflow` + `ISuperHookOutflow` inheritance — sizing interface
- Added `decodeAmounts()` — returns `[amount]`
- Added `amountRoles()` — returns `[(IN, TOKEN)]`
- Added `replaceCalldataAmounts()` — single-amount at `AAVE_V4_AMOUNT_OFFSET=124`
- Added `_supportsSizingInterface() → true`

## Hook Source Changes (83 hooks)

### Single-Amount Hooks (65 hooks) — all get the same pattern:
- Added `ISuperHookOutflow` to inheritance — sizing interface
- `decodeAmount() → decodeAmounts()` — returns `uint256[1]`
- Added `amountRoles()` — returns `AmountMeta[1]` with correct denomination
- Added `replaceCalldataAmounts()` — validates length==1, writes at AMOUNT_POSITION
- Added `_supportsSizingInterface() → true`

Affected hooks by denomination:

**TOKEN (IN, TOKEN):**
- Bridges: AcrossSendFundsAndExecuteOnDstHook, AcrossSendFundsAndExecuteOnDstHookV2, ApproveAndAcross (V1+V2), StargateSendHook, StargateSendHookV2, ApproveAndStargate (V1+V2), CCTPSendHook, ApproveAndCCTPSendHook, CircleGatewayWalletHook, DeBridgeSendOrderAndExecuteOnDstHook
- Swappers: SwapUniswapV3Hook, ApproveAndSwapUniswapV3Hook, SwapUniswapV3Router02Hook, ApproveAndSwapUniswapV3Router02Hook, SwapUniswapV2Hook, ApproveAndSwapUniswapV2Hook, SwapUniswapV4Hook, SwapOdosV2Hook, SwapOdosV3Hook, ApproveAndSwapOdosV2Hook, ApproveAndSwapOdosV3Hook, SwapKyberSwapHook, ApproveAndSwapKyberSwapHook, SwapSparkPSMExactInHook, SwapSparkPSMExactOutHook, ApproveAndSwapSparkPSMExactInHook, ApproveAndSwapSparkPSMExactOutHook, SwapAlgebraIntegralHook, ApproveAndSwapAlgebraIntegralHook, SwapOpenOceanSparkDexHook, ApproveAndSwapOpenOceanSparkDexHook, SpectraExchangeRedeemHook, PendleRouterRedeemHook
- Tokens: TransferHook, NativeTransferHook, ApproveERC20Hook, TransferERC20Hook, DepositWETHHook, WithdrawWETHHook
- Stake: FluidStakeHook, FluidUnstakeHook, ApproveAndFluidStakeHook, GearboxStakeHook, GearboxUnstakeHook, ApproveAndGearboxStakeHook
- Other: FetchNativeFeeHook, ClaimFailedTransferHook

**ASSETS (IN, ASSETS):**
- Deposit4626VaultHook, ApproveAndDeposit4626VaultHook
- Deposit5115VaultHook, ApproveAndDeposit5115VaultHook
- Deposit7540VaultHook, RequestDeposit7540VaultHook, ApproveAndRequestDeposit7540VaultHook
- Withdraw7540VaultHook, WithdrawWithId7540VaultHook

**SHARES (IN, SHARES):**
- Redeem4626VaultHook
- Redeem5115VaultHook
- Redeem7540VaultHook, RedeemWithId7540VaultHook, RequestRedeem7540VaultHook
- RequestRedeemDETHHook, ApproveAndRequestRedeemDETHHook
- EthenaCooldownSharesHook
- RedeemFirelightVaultHook
- MintSuperPositionsHook, BurnSuperPositionsHook

### Compound Hooks (dual-amount):

**AaveV4SupplyAndBorrowHook:**
- `decodeAmounts()` returns `[supplyAmount, borrowAmount]`
- `amountRoles()` returns `[(IN, TOKEN), (OUT, TOKEN)]`
- `replaceCalldataAmounts()` validates length==2, writes at offsets 124 and 157

**AaveV4RepayAndWithdrawHook:**
- `decodeAmounts()` returns `[repayAmount, withdrawAmount]`
- `amountRoles()` returns `[(IN, TOKEN), (OUT, TOKEN)]`
- `replaceCalldataAmounts()` validates length==2, writes at offsets 124 and 158

**MorphoWithdrawHook:**
- `decodeAmounts()` returns `[assets, shares]`
- `amountRoles()` returns `[(IN, ASSETS), (IN, SHARES)]`
- `replaceCalldataAmounts()` validates length==2, enforces assets-XOR-shares invariant

### Sizeless Hooks (return empty arrays):

- FluidClaimRewardHook — `decodeAmounts()→[]`, `amountRoles()→[]`, `replaceCalldataAmounts()` rejects non-empty
- GearboxClaimRewardHook — same
- YearnClaimOneRewardHook — same
- MerklClaimRewardHook — same (amounts are merkle-proof-bound)
- BatchTransferFromHook — same (amounts are signature-bound)

### Decode-Only Hooks (no replaceCalldataAmounts):
- ClaimAssetsDETHHook — `decodeAmounts()→[]`, `amountRoles()→[]`, supports ISuperHookInflowOutflow but not ISuperHookOutflow
- ClaimWithdrawFirelightVaultHook — same

## ClaimRFLRHook Data Layout Change

- Removed `month` parameter from hook data — now calls `IRNat(RNAT).getCurrentMonth()` on-chain
- `PROJECT_IDS_LENGTH_POSITION` changed from 32 to 0
- `PROJECT_IDS_START_POSITION` changed from 64 to 32

## New Files

- `hook-sizing-manifest.json` — machine-readable manifest of all hook sizing metadata
- `package.json` — scripts for generating/validating the manifest
- `test/unit/hooks/HookSizingInterface.t.sol` (untracked, 2250 lines) — 146 unit tests for sizing interface
- `test/unit/hooks/HookSizingInterfaceIntegration.t.sol` (untracked, 356 lines) — fork-based integration tests
- `test/unit/hooks/swappers/uniswap-v2/UniswapV2UnitTests.t.sol` — new unit test file
- `test/unit/hooks/swappers/uniswap-v4/UniswapV4UnitTests.t.sol` — new unit test file
- `test/unit/hooks/tokens/NativeTransferHook.t.sol` — new unit test file
- `.claude/sessions/context_session_17.md` — session context

## Test Changes (68 files, +3640/-144)

- All `decodeAmount()` calls → `decodeAmounts()[0]` across ~50 test files
- All `replaceCalldataAmount(data, amt)` calls → `replaceCalldataAmounts(data, _singleAmount(amt))`
- Added `_singleAmount()` and `_dualAmounts()` helpers in `test/utils/Helpers.sol`
- Added decode/replace/fuzz tests in existing test files for hooks that only had basic tests
- Fixed `FlareRFLRHooksE2E.t.sol` tests to match new data layout (no month param)

## Verification Script (`script/run/verify_v2_staging_prod.sh`)

- Added `AcrossV3AdapterV2` constructor args mapping
- Added `AcrossSendFundsAndExecuteOnDstHookV2` constructor args mapping
- Added `ApproveAndAcrossSendFundsAndExecuteOnDstHookV2` constructor args mapping
- Added `StargateSendHookV2` + `ApproveAndStargateSendHookV2` constructor args mapping

## Submodules

- `lib/modulekit` — dirty (local uncommitted changes)
- `lib/nexus` — updated commit hash

## Mock

- `test/mocks/unused-hooks/FluidStakeWithPermitHook.sol` — migrated to array-based interface
