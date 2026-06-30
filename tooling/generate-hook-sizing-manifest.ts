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
  pipeMode: "transform" | "passthrough" | "source";
  amountPosition?: number;
  secondaryAmountPosition?: number;
  sizing?: "exclusive-or" | "dual";
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

function detectPipeMode(hookSolName: string): "transform" | "passthrough" | "source" {
  const hookDir = path.join(ROOT, "src/hooks");
  const files = findSolFiles(hookDir);

  for (const file of files) {
    if (path.basename(file) !== `${hookSolName}.sol`) continue;
    const content = fs.readFileSync(file, "utf-8");

    if (content.includes("PipeMode.PASSTHROUGH")) return "passthrough";
    if (content.includes("PipeMode.SOURCE")) return "source";
    return "transform";
  }
  // Hook source not found — default to transform
  return "transform";
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

// Overrides for hooks where auto-detection doesn't work or special semantics apply.
// NOTE: denom is intentionally absent — denomination lives exclusively in manifests/hooks.json
// where it is derived from on-chain amountRoles(). Keeping it here would create a dual-authorship
// contradiction.
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
  ClaimRFLRV2Hook: { mode: "sizeless" },           // claims all
  ClaimRFLRV3Hook: { mode: "sizeless" },           // claims all
  WithdrawRFLRHook: { mode: "sizeless" },          // withdraws all
  WithdrawRFLRHookV2: { mode: "sizeless" },        // withdraws all
  WithdrawVestedRFLRHook: { mode: "sizeless" },    // withdraws all vested
  WithdrawVestedRFLRHookV2: { mode: "sizeless" },  // withdraws all vested
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
  Swap1InchHook: { mode: "external", reason: "amount inside aggregator txData; resize = re-quote" },
  PendleRouterSwapHook: { mode: "external", reason: "amount inside aggregator txData" },
  PendleRouterRedeemHook: { mode: "external", reason: "TokenOutput ABI-encoded struct" },
  PendleUnifiedHook: { mode: "external", reason: "amount inside aggregator txData" },
  BatchTransferHook: { mode: "external", reason: "amounts in variable-length array" },
  BatchTransferFromHook: { mode: "external", reason: "amounts in variable-length array" },
  MerklClaimRewardHook: { mode: "external", reason: "variable-length claim data" },
  MetaMorphoReallocateHook: { mode: "external", reason: "amounts in MarketAllocation[]" },
  ForceDeallocateMorphoHook: { mode: "external", reason: "amounts in allocations array" },
  DeBridgeSendOrderAndExecuteOnDstHook: { mode: "external", reason: "complex variable layout" },

  // == offset hooks with inherited AMOUNT_POSITION from base classes ==
  // Morpho hooks: AMOUNT_POSITION = 80 from BaseLoanHook
  MorphoSupplyHook: { mode: "offset", amountPosition: 80, track: "deprecate->replaceCalldata" },
  MorphoLendHook: { mode: "offset", amountPosition: 80, track: "deprecate->replaceCalldata" },
  MorphoBorrowHook: { mode: "offset", amountPosition: 80, track: "deprecate->replaceCalldata" },
  MorphoRepayHook: { mode: "offset", amountPosition: 80, track: "deprecate->replaceCalldata" },
  MorphoSupplyAndBorrowHook: { mode: "offset", amountPosition: 80, track: "deprecate->replaceCalldata" },
  MorphoRepayAndWithdrawHook: { mode: "offset", amountPosition: 80, track: "deprecate->replaceCalldata" },
  // Aave V4 hooks: amount at 124, from BaseAaveV4LoanHook
  AaveV4SupplyHook: { mode: "offset", amountPosition: 124, track: "deprecate->replaceCalldata" },
  AaveV4WithdrawHook: { mode: "offset", amountPosition: 124, track: "deprecate->replaceCalldata" },
  AaveV4BorrowHook: { mode: "offset", amountPosition: 124, track: "deprecate->replaceCalldata" },
  AaveV4RepayHook: { mode: "offset", amountPosition: 124, track: "deprecate->replaceCalldata" },
  // Gearbox approve-and-stake: AMOUNT_POSITION = 72
  GearboxApproveAndStakeHook: { mode: "offset", amountPosition: 72, track: "deprecate->replaceCalldata" },

  // == replaceCalldata hooks (implement both decodeAmount and replaceCalldataAmount for real) ==
  // ClaimFailedTransferHook: real decodeAmount + real replaceCalldataAmount at AMOUNT_POSITION=40
  ClaimFailedTransferHook: { mode: "replaceCalldata" },
  // Outflow/redeem family: shares-denominated (denomination in manifests/hooks.json)
  Redeem4626VaultHook: { mode: "replaceCalldata" },
  Redeem5115VaultHook: { mode: "replaceCalldata" },
  Redeem7540VaultHook: { mode: "replaceCalldata" },
  Withdraw7540VaultHook: { mode: "replaceCalldata" },
  RedeemWithId7540VaultHook: { mode: "replaceCalldata" },
  WithdrawWithId7540VaultHook: { mode: "replaceCalldata" },

  // == offset hooks with inlined positions (no AMOUNT_POSITION constant) ==
  // All offset entries carry track: "deprecate->replaceCalldata" — offset is the legacy bridge
  SwapOdosV2Hook: { mode: "offset", amountPosition: 20, track: "deprecate->replaceCalldata" },
  ApproveAndSwapOdosV2Hook: { mode: "offset", amountPosition: 20, track: "deprecate->replaceCalldata" },
  CCTPSendHook: { mode: "offset", amountPosition: 20, track: "deprecate->replaceCalldata" },
  ApproveAndCCTPSendHook: { mode: "offset", amountPosition: 20, track: "deprecate->replaceCalldata" },
  CircleGatewayWalletHook: { mode: "offset", amountPosition: 20, track: "deprecate->replaceCalldata" },
  ApproveERC20Hook: { mode: "offset", amountPosition: 40, track: "deprecate->replaceCalldata" },
  TransferERC20Hook: { mode: "offset", amountPosition: 40, track: "deprecate->replaceCalldata" },
  TransferHook: { mode: "offset", amountPosition: 40, track: "deprecate->replaceCalldata" },
  AcrossSendFundsAndExecuteOnDstHook: { mode: "offset", amountPosition: 92, track: "deprecate->replaceCalldata" },
  ApproveAndAcrossSendFundsAndExecuteOnDstHook: { mode: "offset", amountPosition: 92, track: "deprecate->replaceCalldata" },
  AcrossSendFundsAndExecuteOnDstHookV2: { mode: "offset", amountPosition: 92, track: "deprecate->replaceCalldata" },
  ApproveAndAcrossSendFundsAndExecuteOnDstHookV2: { mode: "offset", amountPosition: 92, track: "deprecate->replaceCalldata" },
  StargateSendHook: { mode: "offset", amountPosition: 108, track: "deprecate->replaceCalldata" },
  ApproveAndStargateSendHook: { mode: "offset", amountPosition: 108, track: "deprecate->replaceCalldata" },
  StargateSendHookV2: { mode: "offset", amountPosition: 108, track: "deprecate->replaceCalldata" },
  ApproveAndStargateSendHookV2: { mode: "offset", amountPosition: 108, track: "deprecate->replaceCalldata" },
  SwapUniswapV4Hook: { mode: "offset", amountPosition: 120, track: "deprecate->replaceCalldata" },
  SwapUniswapV3Hook: { mode: "offset", amountPosition: 128, track: "deprecate->replaceCalldata" },
  ApproveAndSwapUniswapV3Hook: { mode: "offset", amountPosition: 128, track: "deprecate->replaceCalldata" },
  SwapUniswapV2Hook: { mode: "offset", amountPosition: 72, track: "deprecate->replaceCalldata" },
  ApproveAndSwapUniswapV2Hook: { mode: "offset", amountPosition: 72, track: "deprecate->replaceCalldata" },
  SwapAlgebraIntegralHook: { mode: "offset", amountPosition: 144, track: "deprecate->replaceCalldata" },
  ApproveAndSwapAlgebraIntegralHook: { mode: "offset", amountPosition: 144, track: "deprecate->replaceCalldata" },
  SwapSparkPSMExactInHook: { mode: "offset", amountPosition: 40, track: "deprecate->replaceCalldata" },
  ApproveAndSwapSparkPSMExactInHook: { mode: "offset", amountPosition: 40, track: "deprecate->replaceCalldata" },
  SwapSparkPSMExactOutHook: { mode: "offset", amountPosition: 40, track: "deprecate->replaceCalldata" },
  ApproveAndSwapSparkPSMExactOutHook: { mode: "offset", amountPosition: 40, track: "deprecate->replaceCalldata" },
  // Note: SwapKyberSwapHook, ApproveAndSwapKyberSwapHook, SwapUniswapV3Router02Hook,
  // ApproveAndSwapUniswapV3Router02Hook removed from OVERRIDES — all implement replaceCalldataAmount
  // and are correctly auto-detected. Previously had stale offset values.
  // Note: SwapOpenOceanSparkDexHook / ApproveAndSwapOpenOceanSparkDexHook removed (renamed to
  // SwapOpenOceanHook / ApproveAndSwapOpenOceanHook) — auto-detected as replaceCalldata from source

  // == special: dual-amount hooks ==
  MorphoWithdrawHook: {
    mode: "offset",
    amountPosition: 112,
    secondaryAmountPosition: 144,
    sizing: "exclusive-or",
    track: "deprecate->replaceCalldata",
  },
  AaveV4SupplyAndBorrowHook: {
    mode: "offset",
    amountPosition: 124,
    secondaryAmountPosition: 157,
    sizing: "dual",
    track: "deprecate->replaceCalldata",
  },
  AaveV4RepayAndWithdrawHook: {
    mode: "offset",
    amountPosition: 124,
    secondaryAmountPosition: 158,
    sizing: "dual",
    track: "deprecate->replaceCalldata",
  },
};

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
        pipeMode: detectPipeMode(hookValue),
      };
      if (override.amountPosition !== undefined) entry.amountPosition = override.amountPosition;
      if (override.secondaryAmountPosition !== undefined) entry.secondaryAmountPosition = override.secondaryAmountPosition;
      if (override.sizing) entry.sizing = override.sizing;
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
        pipeMode: detectPipeMode(hookValue),
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
        pipeMode: detectPipeMode(hookValue),
        amountPosition: amtPos,
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
      pipeMode: detectPipeMode(hookValue),
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
console.log(`  pipeMode: transform=${manifest.filter((m) => m.pipeMode === "transform").length}, passthrough=${manifest.filter((m) => m.pipeMode === "passthrough").length}, source=${manifest.filter((m) => m.pipeMode === "source").length}`);
