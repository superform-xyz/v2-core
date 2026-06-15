/**
 * Hook Sizing Manifest Validator
 *
 * CI conformance check that verifies:
 * 1. Every *HOOK*KEY in Constants.sol / ConstantsOtherHooks.sol has a manifest entry
 * 2. Every manifest entry references a valid hook key constant
 * 3. For offset entries: amountPosition matches the AMOUNT_POSITION constant in source (where one exists)
 */

import * as fs from "fs";
import * as path from "path";

const ROOT = path.resolve(__dirname, "..");

// ─── Types ────────────────────────────────────────────────────────────────────

interface ManifestEntry {
  hookKey: string;
  mode: "offset" | "replaceCalldata" | "sizeless" | "external";
  amountPosition?: number;
  secondaryAmountPosition?: number;
  sizing?: string;
  denom?: string;
  track?: string;
  reason?: string;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function extractHookKeyConstants(
  filePath: string
): Map<string, string> {
  const content = fs.readFileSync(filePath, "utf-8");
  const result = new Map<string, string>();

  const pattern =
    /string\s+(?:internal|public)\s+constant\s+(\w+HOOK\w*KEY)\s*=\s*"([^"]+)"/g;
  let match: RegExpExecArray | null;
  while ((match = pattern.exec(content)) !== null) {
    const constantName = match[1];
    const stringValue = match[2];
    if (constantName.includes("MOCK")) continue;
    result.set(constantName, stringValue);
  }
  return result;
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

function findAmountPositionInSource(hookSolName: string): number | null {
  const hookDir = path.join(ROOT, "src/hooks");
  const files = findSolFiles(hookDir);

  for (const file of files) {
    if (path.basename(file) !== `${hookSolName}.sol`) continue;
    const content = fs.readFileSync(file, "utf-8");

    // Look for AMOUNT_POSITION constant (not USE_PREV_HOOK_AMOUNT_POSITION)
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

// ─── Main validation ────────────────────────────────────────────────────────

let errors = 0;
let warnings = 0;

function error(msg: string) {
  console.error(`ERROR: ${msg}`);
  errors++;
}

function warn(msg: string) {
  console.warn(`WARN:  ${msg}`);
  warnings++;
}

// Load manifest
const manifestPath = path.join(ROOT, "hook-sizing-manifest.json");
if (!fs.existsSync(manifestPath)) {
  console.error(`FATAL: ${manifestPath} not found. Run generate:hook-sizing first.`);
  process.exit(1);
}

const manifest: ManifestEntry[] = JSON.parse(
  fs.readFileSync(manifestPath, "utf-8")
);

// Load hook key constants from both files
const constantsPath = path.join(ROOT, "script/utils/Constants.sol");
const otherHooksPath = path.join(ROOT, "script/utils/ConstantsOtherHooks.sol");

const allConstants = new Map<string, string>();
for (const [k, v] of extractHookKeyConstants(constantsPath)) {
  allConstants.set(k, v);
}
for (const [k, v] of extractHookKeyConstants(otherHooksPath)) {
  allConstants.set(k, v);
}

// Build lookup maps
const manifestByKey = new Map<string, ManifestEntry>();
for (const entry of manifest) {
  if (manifestByKey.has(entry.hookKey)) {
    error(`Duplicate hookKey in manifest: ${entry.hookKey}`);
  }
  manifestByKey.set(entry.hookKey, entry);
}

// Deduplicate constants by string value (MORPHO_BORROW_ONLY_HOOK_KEY = MORPHO_BORROW_HOOK_KEY)
const uniqueValues = new Map<string, string[]>();
for (const [constName, strValue] of allConstants) {
  const existing = uniqueValues.get(strValue) || [];
  existing.push(constName);
  uniqueValues.set(strValue, existing);
}

// Build reverse map: for each unique string value, which hookKey constant is the "primary"
// (the one that appears in the manifest)?
const manifestKeysByValue = new Map<string, ManifestEntry>();
for (const entry of manifest) {
  const hookValue = allConstants.get(entry.hookKey);
  if (hookValue) manifestKeysByValue.set(hookValue, entry);
}

// Check 1: Every hook key constant has a manifest entry (by string value)
for (const [strValue, constNames] of uniqueValues) {
  if (!manifestKeysByValue.has(strValue)) {
    error(
      `Missing manifest entry for ${constNames.join(" / ")} ("${strValue}")`
    );
  }
}

// Check 2: Every manifest entry references a valid hook key constant
for (const entry of manifest) {
  if (!allConstants.has(entry.hookKey)) {
    error(
      `Manifest entry hookKey "${entry.hookKey}" not found in Constants files`
    );
  }
}

// Check 3: Validate mode-specific fields
for (const entry of manifest) {
  if (entry.mode === "offset") {
    if (entry.amountPosition === undefined) {
      error(`offset entry ${entry.hookKey} missing amountPosition`);
    }
  }
  if (entry.mode === "replaceCalldata" && entry.amountPosition !== undefined) {
    warn(
      `replaceCalldata entry ${entry.hookKey} has amountPosition (ignored by OMS)`
    );
  }
}

// Check 4: Validate denom is present on non-sizeless entries
for (const entry of manifest) {
  if (entry.mode !== "sizeless" && !entry.denom) {
    warn(`${entry.hookKey} (${entry.mode}) missing denom field`);
  }
}

// Check 5: Validate offset entries carry deprecation track
for (const entry of manifest) {
  if (entry.mode === "offset" && !entry.track) {
    warn(`offset entry ${entry.hookKey} missing track field`);
  }
}

// Check 6: Validate external entries carry reason
for (const entry of manifest) {
  if (entry.mode === "external" && !entry.reason) {
    warn(`external entry ${entry.hookKey} missing reason field`);
  }
}

// Check 7: For offset entries, verify amountPosition against source AMOUNT_POSITION constant
for (const entry of manifest) {
  if (entry.mode !== "offset") continue;

  // Resolve hookValue (sol file name) from constants
  const hookValue = allConstants.get(entry.hookKey);
  if (!hookValue) continue;

  const sourcePos = findAmountPositionInSource(hookValue);
  if (sourcePos === null) continue; // No constant in source, skip (uses inline offset)

  if (sourcePos !== entry.amountPosition) {
    error(
      `amountPosition mismatch for ${entry.hookKey}: manifest=${entry.amountPosition}, source AMOUNT_POSITION=${sourcePos}`
    );
  }
}

// Check 5: Validate entry count
console.log(`\nManifest: ${manifest.length} entries`);
console.log(`Constants: ${uniqueValues.size} unique hook key values (${allConstants.size} constants)`);
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

if (manifest.length !== uniqueValues.size) {
  error(
    `Entry count mismatch: manifest has ${manifest.length}, Constants have ${uniqueValues.size} unique values`
  );
}

// Summary
console.log(`\n${errors} errors, ${warnings} warnings`);

if (errors > 0) {
  process.exit(1);
}

console.log("Validation passed!");
