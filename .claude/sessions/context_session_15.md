# Session 15: Custom Error Selector Mapping for Superlens

## Status: COMPLETE
- Date: 2026-06-04

## Overview
Added error selector → human-readable error name mapping for all custom errors in v2-core and v2-periphery to the Superlens tool (located in v2-monitoring/superlens/).

## Results
- 310 Solidity files scanned
- 613 total error declarations found
- 16 enum types detected and normalized to uint8
- 414 unique error selectors generated

## Files Created/Modified

### New Files
1. `v2-monitoring/superlens/scripts/generate-error-map.ts` — Generation script
   - Globs `*.sol` in v2-core/src/ and v2-periphery/src/
   - Extracts `error Name(...)` declarations via regex
   - Normalizes enum params to uint8
   - Computes 4-byte selectors via `ethers.id()`
   - Deduplicates by selector, tracks all source files

2. `v2-monitoring/superlens/lib/errors.generated.ts` — Generated mapping (414 entries)
   - `CustomErrorEntry` interface: name, signature, params, sources
   - `ERROR_SELECTORS` record keyed by hex selector

3. `v2-monitoring/superlens/lib/error-decoder.ts` — Decode utilities
   - `lookupErrorSelector(selector)` — simple map lookup
   - `decodeCustomError(data)` — full decode with AbiCoder

4. `v2-monitoring/superlens/tests/error-decoder.test.ts` — 10 tests
   - Selector lookup (with/without 0x, case-insensitive)
   - Parameterized error decoding
   - Unknown selector handling
   - Entry count validation

### Modified Files
5. `v2-monitoring/superlens/package.json`
   - Added `tsx` to devDependencies
   - Added `"generate:errors"` script

## Usage
```bash
cd v2-monitoring/superlens
npm run generate:errors   # regenerate after adding new errors
npm test                  # run all tests (120 pass)
```

## Verified Selectors
- `0x538ba4f9` → `ZERO_ADDRESS()`
- `0x23c4784f` → `EXPIRED_DEADLINE(uint256,uint256)`
- `0xb78bd21b` → `INVALID_SENDER()`
