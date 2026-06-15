/**
 * Hook Sizing Manifest Generator
 *
 * Generates hook-sizing-manifest.json by:
 * 1. Extracting hook key constants from script/utils/Constants.sol & ConstantsOtherHooks.sol
 * 2. Auto-detecting AMOUNT_POSITION constants from hook source files
 * 3. Detecting replaceCalldataAmount implementations (outflow hooks)
 * 4. Merging with hand-curated overrides for hooks with non-standard layouts
 * 5. Validating completeness and writing the manifest
 */

import * as fs from "fs";
import * as path from "path";

const ROOT = path.resolve(__dirname, "..");

// ─── Types ────────────────────────────────────────────────────────────────────

interface ManifestEntry {
  hookKey: string;
  hookValue: string;
  mode: "offset" | "replaceCalldata" | "sizeless" | "external";
  amountPosition?: number;
  secondaryAmountPosition?: number;
  sizing?: "exclusive-or" | "dual";
  denom?: "assets" | "shares" | "units" | "perIntent" | "assets|shares" | "native" | "token" | "fee";
  track?: string;
  reason?: string; // for external mode: why OMS must not splice
}

interface HookKeyDef {
  constantName: string;
  stringValue: string;
}

// ─── Step 1: Extract hook keys from Constants files ──────────────────────────

function extractHookKeys(filePath: string): HookKeyDef[] {
  const content = fs.readFileSync(filePath, "utf-8");
  const results: HookKeyDef[] = [];

  // Match: string <vis> constant <NAME> = "<value>";
  // Handles multi-line declarations where value is on next line
  const pattern =
    /string\s+(?:internal|public)\s+constant\s+(\w+HOOK\w*KEY)\s*=\s*"([^"]+)"/g;
  let match: RegExpExecArray | null;
  while ((match = pattern.exec(content)) !== null) {
    const constantName = match[1];
    const stringValue = match[2];

    // Skip mock/dev hooks
    if (constantName.includes("MOCK")) continue;

    results.push({ constantName, stringValue });
  }

  return results;
}

// ─── Step 2: Auto-detect AMOUNT_POSITION from hook source ───────────────────

function findAmountPosition(hookSolName: string): number | null {
  const hookDir = path.join(ROOT, "src/hooks");
  const files = findSolFiles(hookDir);

  for (const file of files) {
    if (path.basename(file) !== `${hookSolName}.sol`) continue;
    const content = fs.readFileSync(file, "utf-8");

    // Look for AMOUNT_POSITION constant (exact name, not USE_PREV_HOOK_AMOUNT_POSITION)
    const amtMatch = content.match(
      /uint256\s+(?:private|internal)\s+constant\s+AMOUNT_POSITION\s*=\s*(\d+)/
    );
    if (amtMatch) return parseInt(amtMatch[1], 10);

    // Also check INPUT_AMOUNT_POSITION (used by Odos V3)
    const inputMatch = content.match(
      /uint256\s+(?:private|internal)\s+constant\s+INPUT_AMOUNT_POSITION\s*=\s*(\d+)/
    );
    if (inputMatch) return parseInt(inputMatch[1], 10);
  }
  return null;
}

function hasReplaceCalldataAmount(hookSolName: string): boolean {
  const hookDir = path.join(ROOT, "src/hooks");
  const files = findSolFiles(hookDir);

  for (const file of files) {
    if (path.basename(file) !== `${hookSolName}.sol`) continue;
    const content = fs.readFileSync(file, "utf-8");
    return (
      content.includes("replaceCalldataAmount") &&
      content.includes("decodeAmount")
    );
  }
  return false;
}

function findSolFiles(dir: string): string[] {
  const results: string[] = [];
  try {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        results.push(...findSolFiles(fullPath));
      } else if (entry.name.endsWith(".sol")) {
        results.push(fullPath);
      }
    }
  } catch {
    // directory doesn't exist
  }
  return results;
}

// ─── Step 3: Manual overrides ────────────────────────────────────────────────

// Overrides for hooks where auto-detection doesn't work or special semantics apply
const OVERRIDES: Record<string, Partial<ManifestEntry>> = {
  // == sizeless hooks (truly no amount concept) ==
  SetOperator7540Hook: { mode: "sizeless" },
  SetSlippageHook: { mode: "sizeless" },
  CancelDepositRequest7540Hook: { mode: "sizeless" },
  CancelRedeemRequest7540Hook: { mode: "sizeless" },
  ClaimCancelDepositRequest7540Hook: { mode: "sizeless" },
  ClaimCancelRedeemRequest7540Hook: { mode: "sizeless" },
  CancelDepositRequestWithId7540Hook: { mode: "sizeless" },
  CancelRedeemRequestWithId7540Hook: { mode: "sizeless" },
  ClaimCancelDepositRequestWithId7540Hook: { mode: "sizeless" },
  ClaimCancelRedeemRequestWithId7540Hook: { mode: "sizeless" },
  CancelRedeemHook: { mode: "sizeless" },
  EthenaUnstakeHook: { mode: "sizeless" },       // unstakes everything, no amount param
  MarkRootAsUsedHook: { mode: "sizeless" },
  DeBridgeCancelOrderHook: { mode: "sizeless" },  // cancel by orderId
  OfframpTokensHook: { mode: "sizeless" },         // sends all available
  ClaimRFLRHook: { mode: "sizeless" },             // claims all
  WithdrawRFLRHook: { mode: "sizeless" },          // withdraws all
  WithdrawVestedRFLRHook: { mode: "sizeless" },    // withdraws all vested
  CircleGatewayMinterHook: { mode: "sizeless" },   // governance, no amount
  CircleGatewayAddDelegateHook: { mode: "sizeless" },
  CircleGatewayRemoveDelegateHook: { mode: "sizeless" },
  FluidClaimRewardHook: { mode: "sizeless" },      // decodeAmount returns 0
  GearboxClaimRewardHook: { mode: "sizeless" },    // decodeAmount returns 0
  YearnClaimAllRewardsHook: { mode: "sizeless" },  // claims all
  YearnClaimOneRewardHook: { mode: "sizeless" },   // decodeAmount returns 0
  ClaimWithdrawFirelightVaultHook: { mode: "sizeless" }, // requestId, not amount
  ClaimAssetsDETHHook: { mode: "sizeless" },       // requestId, not amount
  RecordPurchasePendlePTAmortizedOracleHook: { mode: "sizeless" },   // oracle record, uses prevHook
  RecordRedemptionPendlePTAmortizedOracleHook: { mode: "sizeless" }, // oracle record, uses prevHook
  RecordPurchasePendlePTAmortizedOracleHookV2: { mode: "sizeless" },
  RecordRedemptionPendlePTAmortizedOracleHookV2: { mode: "sizeless" },

  // == external hooks (amount exists but not at a static byte offset) ==
  // Amount is embedded in aggregator txData, ABI-encoded structs, or dynamic arrays.
  // OMS must not splice — amount is set off-chain by bundler/aggregator.
  // Priority backlog for replaceCalldataAmount migration.
  Swap1InchHook: { mode: "external", denom: "assets", reason: "amount inside aggregator txData; resize = re-quote" },
  PendleRouterSwapHook: { mode: "external", denom: "assets", reason: "amount inside aggregator txData" },
  PendleRouterRedeemHook: { mode: "external", denom: "shares", reason: "TokenOutput ABI-encoded struct" },
  PendleUnifiedHook: { mode: "external", denom: "assets", reason: "amount inside aggregator txData" },
  BatchTransferHook: { mode: "external", denom: "token", reason: "amounts in variable-length array" },
  BatchTransferFromHook: { mode: "external", denom: "token", reason: "amounts in variable-length array" },
  MerklClaimRewardHook: { mode: "external", denom: "token", reason: "variable-length claim data" },
  MetaMorphoReallocateHook: { mode: "external", denom: "assets", reason: "amounts in MarketAllocation[]" },
  ForceDeallocateMorphoHook: { mode: "external", denom: "assets", reason: "amounts in allocations array" },
  DeBridgeSendOrderAndExecuteOnDstHook: { mode: "external", denom: "assets", reason: "complex variable layout" },

  // == offset hooks with inherited AMOUNT_POSITION from base classes ==
  // Morpho hooks: AMOUNT_POSITION = 80 from BaseLoanHook
  MorphoSupplyHook: { mode: "offset", amountPosition: 80, denom: "assets", track: "deprecate->replaceCalldata" },
  MorphoLendHook: { mode: "offset", amountPosition: 80, denom: "assets", track: "deprecate->replaceCalldata" },
  MorphoBorrowHook: { mode: "offset", amountPosition: 80, denom: "assets", track: "deprecate->replaceCalldata" },
  MorphoRepayHook: { mode: "offset", amountPosition: 80, denom: "assets", track: "deprecate->replaceCalldata" },
  MorphoSupplyAndBorrowHook: { mode: "offset", amountPosition: 80, denom: "assets", track: "deprecate->replaceCalldata" },
  MorphoRepayAndWithdrawHook: { mode: "offset", amountPosition: 80, denom: "assets", track: "deprecate->replaceCalldata" },
  // Aave V4 hooks: amount at 124, from BaseAaveV4LoanHook
  AaveV4SupplyHook: { mode: "offset", amountPosition: 124, denom: "assets", track: "deprecate->replaceCalldata" },
  AaveV4WithdrawHook: { mode: "offset", amountPosition: 124, denom: "assets", track: "deprecate->replaceCalldata" },
  AaveV4BorrowHook: { mode: "offset", amountPosition: 124, denom: "assets", track: "deprecate->replaceCalldata" },
  AaveV4RepayHook: { mode: "offset", amountPosition: 124, denom: "assets", track: "deprecate->replaceCalldata" },
  // Gearbox approve-and-stake: AMOUNT_POSITION = 72
  GearboxApproveAndStakeHook: { mode: "offset", amountPosition: 72, denom: "assets", track: "deprecate->replaceCalldata" },

  // == replaceCalldata hooks (implement both decodeAmount and replaceCalldataAmount for real) ==
  // ClaimFailedTransferHook: real decodeAmount + real replaceCalldataAmount at AMOUNT_POSITION=40
  ClaimFailedTransferHook: { mode: "replaceCalldata", denom: "assets" },
  // Outflow/redeem family: shares-denominated
  Redeem4626VaultHook: { mode: "replaceCalldata", denom: "shares" },
  Redeem5115VaultHook: { mode: "replaceCalldata", denom: "shares" },
  Redeem7540VaultHook: { mode: "replaceCalldata", denom: "shares" },
  Withdraw7540VaultHook: { mode: "replaceCalldata", denom: "assets" },
  RedeemWithId7540VaultHook: { mode: "replaceCalldata", denom: "shares" },
  WithdrawWithId7540VaultHook: { mode: "replaceCalldata", denom: "assets" },

  // == offset hooks with inlined positions (no AMOUNT_POSITION constant) ==
  // All offset entries carry track: "deprecate->replaceCalldata" — offset is the legacy bridge
  SwapOdosV2Hook: { mode: "offset", amountPosition: 20, denom: "assets", track: "deprecate->replaceCalldata" },
  ApproveAndSwapOdosV2Hook: { mode: "offset", amountPosition: 20, denom: "assets", track: "deprecate->replaceCalldata" },
  CCTPSendHook: { mode: "offset", amountPosition: 20, denom: "assets", track: "deprecate->replaceCalldata" },
  ApproveAndCCTPSendHook: { mode: "offset", amountPosition: 20, denom: "assets", track: "deprecate->replaceCalldata" },
  CircleGatewayWalletHook: { mode: "offset", amountPosition: 20, denom: "assets", track: "deprecate->replaceCalldata" },
  ApproveERC20Hook: { mode: "offset", amountPosition: 40, denom: "token", track: "deprecate->replaceCalldata" },
  TransferERC20Hook: { mode: "offset", amountPosition: 40, denom: "token", track: "deprecate->replaceCalldata" },
  TransferHook: { mode: "offset", amountPosition: 40, denom: "native", track: "deprecate->replaceCalldata" },
  AcrossSendFundsAndExecuteOnDstHook: { mode: "offset", amountPosition: 92, denom: "assets", track: "deprecate->replaceCalldata" },
  ApproveAndAcrossSendFundsAndExecuteOnDstHook: { mode: "offset", amountPosition: 92, denom: "assets", track: "deprecate->replaceCalldata" },
  AcrossSendFundsAndExecuteOnDstHookV2: { mode: "offset", amountPosition: 92, denom: "assets", track: "deprecate->replaceCalldata" },
  ApproveAndAcrossSendFundsAndExecuteOnDstHookV2: { mode: "offset", amountPosition: 92, denom: "assets", track: "deprecate->replaceCalldata" },
  StargateSendHook: { mode: "offset", amountPosition: 108, denom: "assets", track: "deprecate->replaceCalldata" },
  ApproveAndStargateSendHook: { mode: "offset", amountPosition: 108, denom: "assets", track: "deprecate->replaceCalldata" },
  StargateSendHookV2: { mode: "offset", amountPosition: 108, denom: "assets", track: "deprecate->replaceCalldata" },
  ApproveAndStargateSendHookV2: { mode: "offset", amountPosition: 108, denom: "assets", track: "deprecate->replaceCalldata" },
  SwapUniswapV4Hook: { mode: "offset", amountPosition: 120, denom: "assets", track: "deprecate->replaceCalldata" },
  SwapUniswapV3Hook: { mode: "offset", amountPosition: 128, denom: "assets", track: "deprecate->replaceCalldata" },
  ApproveAndSwapUniswapV3Hook: { mode: "offset", amountPosition: 128, denom: "assets", track: "deprecate->replaceCalldata" },
  SwapUniswapV3Router02Hook: { mode: "offset", amountPosition: 128, denom: "assets", track: "deprecate->replaceCalldata" },
  ApproveAndSwapUniswapV3Router02Hook: { mode: "offset", amountPosition: 128, denom: "assets", track: "deprecate->replaceCalldata" },
  SwapUniswapV2Hook: { mode: "offset", amountPosition: 72, denom: "assets", track: "deprecate->replaceCalldata" },
  ApproveAndSwapUniswapV2Hook: { mode: "offset", amountPosition: 72, denom: "assets", track: "deprecate->replaceCalldata" },
  SwapAlgebraIntegralHook: { mode: "offset", amountPosition: 144, denom: "assets", track: "deprecate->replaceCalldata" },
  ApproveAndSwapAlgebraIntegralHook: { mode: "offset", amountPosition: 144, denom: "assets", track: "deprecate->replaceCalldata" },
  SwapSparkPSMExactInHook: { mode: "offset", amountPosition: 40, denom: "assets", track: "deprecate->replaceCalldata" },
  ApproveAndSwapSparkPSMExactInHook: { mode: "offset", amountPosition: 40, denom: "assets", track: "deprecate->replaceCalldata" },
  SwapSparkPSMExactOutHook: { mode: "offset", amountPosition: 40, denom: "assets", track: "deprecate->replaceCalldata" },
  ApproveAndSwapSparkPSMExactOutHook: { mode: "offset", amountPosition: 40, denom: "assets", track: "deprecate->replaceCalldata" },
  SwapKyberSwapHook: { mode: "offset", amountPosition: 52, denom: "assets", track: "deprecate->replaceCalldata" },
  ApproveAndSwapKyberSwapHook: { mode: "offset", amountPosition: 52, denom: "assets", track: "deprecate->replaceCalldata" },
  SwapOpenOceanSparkDexHook: { mode: "offset", amountPosition: 52, denom: "assets", track: "deprecate->replaceCalldata" },
  ApproveAndSwapOpenOceanSparkDexHook: { mode: "offset", amountPosition: 52, denom: "assets", track: "deprecate->replaceCalldata" },

  // == special: dual-amount hooks ==
  MorphoWithdrawHook: {
    mode: "offset",
    amountPosition: 112,
    secondaryAmountPosition: 144,
    sizing: "exclusive-or",
    denom: "assets|shares",
    track: "deprecate->replaceCalldata",
  },
  AaveV4SupplyAndBorrowHook: {
    mode: "offset",
    amountPosition: 124,
    secondaryAmountPosition: 157,
    sizing: "dual",
    denom: "assets",
    track: "deprecate->replaceCalldata",
  },
  AaveV4RepayAndWithdrawHook: {
    mode: "offset",
    amountPosition: 124,
    secondaryAmountPosition: 158,
    sizing: "dual",
    denom: "assets",
    track: "deprecate->replaceCalldata",
  },
};

// ─── Step 3b: Denomination inference ─────────────────────────────────────────

// Infer denomination from hook name for auto-detected hooks.
// Static per-hook: deposit family = assets, redeem family = shares, etc.
function inferDenom(hookValue: string): ManifestEntry["denom"] {
  const lc = hookValue.toLowerCase();

  // Redeem / cooldown shares / request redeem → shares
  if (lc.includes("redeem") || lc.includes("cooldownshares")) return "shares";

  // Deposit / supply / lend / repay / borrow / withdraw → assets
  if (lc.includes("deposit") || lc.includes("supply") || lc.includes("lend") ||
      lc.includes("repay") || lc.includes("borrow") || lc.includes("withdraw")) return "assets";

  // Stake / unstake → assets
  if (lc.includes("stake")) return "assets";

  // Swap → assets (input amount)
  if (lc.includes("swap")) return "assets";

  // Bridge sends → assets
  if (lc.includes("send") || lc.includes("across") || lc.includes("stargate") ||
      lc.includes("cctp") || lc.includes("bridge") || lc.includes("gateway")) return "assets";

  // Token transfers → token
  if (lc.includes("transfer") || lc.includes("approve")) return "token";

  // Mint → assets
  if (lc.includes("mint")) return "assets";

  // Fee → fee
  if (lc.includes("fee")) return "fee";

  return undefined;
}

// ─── Step 4: Build manifest ─────────────────────────────────────────────────

function buildManifest(): ManifestEntry[] {
  const constantsPath = path.join(ROOT, "script/utils/Constants.sol");
  const otherHooksPath = path.join(ROOT, "script/utils/ConstantsOtherHooks.sol");

  const hookKeys = [
    ...extractHookKeys(constantsPath),
    ...extractHookKeys(otherHooksPath),
  ];

  // Deduplicate by string value (MORPHO_BORROW_ONLY_HOOK_KEY = MORPHO_BORROW_HOOK_KEY)
  const seen = new Map<string, HookKeyDef>();
  for (const hk of hookKeys) {
    if (!seen.has(hk.stringValue)) {
      seen.set(hk.stringValue, hk);
    }
  }

  const manifest: ManifestEntry[] = [];

  for (const [hookValue, def] of seen) {
    const override = OVERRIDES[hookValue];

    if (override) {
      // Use manual override
      const entry: ManifestEntry = {
        hookKey: def.constantName,
        hookValue,
        mode: override.mode!,
      };
      if (override.amountPosition !== undefined) entry.amountPosition = override.amountPosition;
      if (override.secondaryAmountPosition !== undefined) entry.secondaryAmountPosition = override.secondaryAmountPosition;
      if (override.sizing) entry.sizing = override.sizing;
      if (override.denom) entry.denom = override.denom;
      if (override.track) entry.track = override.track;
      if (override.reason) entry.reason = override.reason;
      manifest.push(entry);
      continue;
    }

    // Try auto-detection
    // First check if it implements replaceCalldataAmount
    if (hasReplaceCalldataAmount(hookValue)) {
      manifest.push({
        hookKey: def.constantName,
        hookValue,
        mode: "replaceCalldata",
        denom: inferDenom(hookValue),
      });
      continue;
    }

    // Try to find AMOUNT_POSITION constant
    const amtPos = findAmountPosition(hookValue);
    if (amtPos !== null) {
      manifest.push({
        hookKey: def.constantName,
        hookValue,
        mode: "offset",
        amountPosition: amtPos,
        denom: inferDenom(hookValue),
        track: "deprecate->replaceCalldata",
      });
      continue;
    }

    // If nothing matched, flag as unknown
    console.error(
      `WARNING: No classification for ${def.constantName} (${hookValue}). Add to OVERRIDES.`
    );
    manifest.push({
      hookKey: def.constantName,
      hookValue,
      mode: "sizeless",
    });
  }

  // Sort by hookKey for stable output
  manifest.sort((a, b) => a.hookKey.localeCompare(b.hookKey));
  return manifest;
}

// ─── Main ───────────────────────────────────────────────────────────────────

const manifest = buildManifest();

// Strip hookValue from output — internal only, not part of the schema
const output = manifest.map(({ hookValue, ...rest }) => rest);

const outPath = path.join(ROOT, "hook-sizing-manifest.json");
fs.writeFileSync(outPath, JSON.stringify(output, null, 2) + "\n");

console.log(`Generated ${outPath}`);
console.log(`  Total entries: ${manifest.length}`);
console.log(
  `  offset: ${manifest.filter((m) => m.mode === "offset").length}`
);
console.log(
  `  replaceCalldata: ${manifest.filter((m) => m.mode === "replaceCalldata").length}`
);
console.log(
  `  external: ${manifest.filter((m) => m.mode === "external").length}`
);
console.log(
  `  sizeless: ${manifest.filter((m) => m.mode === "sizeless").length}`
);
