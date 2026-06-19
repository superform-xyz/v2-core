# Session 20: Refactor Deployment Scripts + Post-Deployment Verification

## Status: COMPLETE
- Date: 2026-06-18

## Overview
Refactored `deploy_v2_staging_prod.sh` (849 -> 60 lines), `deploy_v2_other_hooks_staging_prod.sh` (751 -> 574 lines), and `verify_v2_staging_prod.sh` (1121 -> 944 lines) by extracting shared functions into `lib_deploy.sh` (1276 lines). Added new `verify_deployments()` function that checks `code.length > 0` for all deployed contracts via `cast codesize`.

## Files Changed

| File | Action | Lines |
|---|---|---|
| `script/run/lib_deploy.sh` | **Created** — shared library | 1276 |
| `script/run/deploy_v2_staging_prod.sh` | **Rewritten** — thin orchestrator | 60 (was 849) |
| `script/run/deploy_v2_other_hooks_staging_prod.sh` | **Refactored** — uses shared lib | 600 (was 751) |
| `script/run/verify_v2_staging_prod.sh` | **Refactored** — uses shared lib | 944 (was 1121) |

## Changes Made

### Task 1: Created lib_deploy.sh (shared library)
- Extracted all reusable functions from both deploy scripts
- 26 functions organized into logical sections:
  - **UI**: `print_header()` (parameterized), `print_separator()`, `print_network_header()`
  - **Logging**: `log()`
  - **Args**: `parse_args()` — handles environment, mode, account, --slow, --resume, --legacy
  - **Validation**: `validate_environment()`, `validate_account()`, `setup_mode_flags()`
  - **Credentials**: `load_credentials()` — calls network-specific `load_rpc_urls()` + `load_etherscan_api_key()`
  - **Infrastructure**: `create_output_directories()`, `prompt_keystore_password()` (secure temp file), `is_unsupported_chain()`
  - **JSON**: `preserve_existing_json_entries()` — merge logic for Nexus contracts etc.
  - **Bytecode**: `extract_contracts_from_regenerate_script()`, `report_bytecode_availability()`, `get_expected_contract_count()`
  - **Check phase**: `check_v2_addresses()` (parameterized forge script), `analyze_deployment_status()`, `run_check_phase()`, `analyze_and_confirm()`
  - **Deploy phase**: `deploy_to_network()`, `run_deploy_phase()`
  - **NEW: Verification**: `verify_deployments()` — post-deployment `cast codesize` sweep
  - **Summary**: `print_summary()` (parameterized label)
- Guard against double-sourcing via `_LIB_DEPLOY_LOADED` flag
- Global state declarations (NETWORK_DEPLOYMENT_STATUS, NETWORK_MISSING_CONTRACTS, etc.)
- FORGE_UNSUPPORTED_CHAINS list (was duplicated in both scripts)

### Task 2: Rewrote deploy_v2_staging_prod.sh
- Reduced from 849 to 60 lines
- Sources `lib_deploy.sh` for all shared logic
- Clean orchestrator flow: setup -> bytecode analysis -> check phase -> analyze & confirm -> keystore password -> deploy phase -> verify -> summary
- No duplicated code

### Task 3: Refactored deploy_v2_other_hooks_staging_prod.sh
- Reduced from 751 to 581 lines
- Sources `lib_deploy.sh` for shared utilities (colors, logging, parse_args, validation, credentials, password prompt, JSON merge)
- Kept unique hook-specific logic: support check functions, bytecode availability per category, multi-sig deploy loop
- Standardized on `$KEYSTORE_PASSWORD_FLAG` (password-file approach via shared lib)
- Added `verify_deployments()` call after deployment loop
- Added `acquire_deploy_lock`, `check_stale_broadcasts`, `preflight_network_checks` calls
- Uses `$FORGE_SCRIPT` variable instead of hardcoded script path

### Task 4: Syntax verification
- All 3 scripts pass `bash -n` syntax check
- `lib_deploy.sh` made executable with `chmod +x`

### Task 5: Pre-deployment guards (nonce conflicts, concurrent runs, etc.)
Added 6 new guard functions to lib_deploy.sh:
- **`_lib_deploy_cleanup()`** — unified EXIT trap that cleans up password file + lock file
- **`acquire_deploy_lock()`** — PID-file lock in /tmp prevents concurrent deployments for the same environment; detects and cleans stale locks from dead processes
- **`get_deployer_address()`** — cached deployer address resolution via `cast wallet address`
- **`check_deployer_nonce()`** — compares latest vs pending nonce via `cast nonce --block pending`; warns if pending transactions exist that could cause nonce conflicts
- **`check_deployer_balance()`** — verifies deployer has non-zero native balance; warns if zero (deployment will fail)
- **`check_stale_broadcasts()`** — detects recent broadcast files (<24h) from previous runs; notes if `--resume` will use them
- **`preflight_network_checks()`** — orchestrates nonce + balance checks per-network (deploy mode only)

Integration:
- `run_deploy_phase()` calls `acquire_deploy_lock()` + `check_stale_broadcasts()` before deployment loop
- `deploy_to_network()` calls `preflight_network_checks()` before each forge command
- Other hooks script: `acquire_deploy_lock()` + `check_stale_broadcasts()` before loop, `preflight_network_checks()` per-network
- `prompt_keystore_password()` caches deployer address immediately after password verification
- Guards are warnings only (don't block deployment) — operator sees warnings and can ctrl-C if needed

### Task 6: Hardening pass
- **Quoted all `${!rpc_var}` and `$ACCOUNT`** expansions in forge commands (both scripts) — prevents silent failures if values contain spaces/special chars
- **NETWORKS array validation** — `validate_environment()` now fails fast if no networks are configured (catches empty/malformed config)
- **Numeric output validation** — `cast codesize`, `cast nonce`, `cast balance` outputs are validated as `^[0-9]+$` before use; non-numeric results (RPC errors) no longer cause false positives
- **Retry logic** — `deploy_to_network()` now supports `DEPLOY_MAX_RETRIES` env var (default 1 = no retry); retries with 5s backoff for transient failures
- **Low balance warning** — `check_deployer_balance()` warns if balance < ~0.01 ETH (may be insufficient for multi-contract deploys)
- **Backup restoration error handling** — `cp` failure when restoring backup JSON is now reported
- **Other hooks failure tracking** — `FAILED_HOOK_DEPLOYS` array tracks which specific hook+network combos failed; summary reports them and exits with code 1
- **`--slow` is now default** — sequential transactions prevent nonce conflicts; `--fast` flag opts out

## Key Design Decisions
1. **Password handling**: Standardized on `--password-file` temp file approach (more secure than `--password` inline, which is visible in /proc)
2. **verify_deployments()**: Uses `cast codesize` (returns decimal size, faster than fetching full bytecode); only runs in deploy mode (skips in simulation); reports failures but does not auto-remove entries
3. **is_unsupported_chain()**: Replaced duplicated 5-line skip loop with single function call
4. **Guard pattern**: `_LIB_DEPLOY_LOADED` prevents issues from accidental double-sourcing
5. **Arithmetic safety**: Used `$((var + 1))` form instead of `((var++))` to avoid exit-code-1 issue under `set -e` when value is 0
6. **Nonce/balance guards**: Warnings only, not blockers — the operator can decide whether to proceed or cancel after seeing warnings
7. **Deploy lock**: PID-file based (`/tmp/superform_deploy_{env}.lock`) with stale-lock detection; prevents two terminals from deploying to the same environment simultaneously
8. **Unified cleanup trap**: Single `_lib_deploy_cleanup` EXIT trap handles both password file and lock file cleanup, avoiding trap-overwrite issues
9. **--slow by default**: Sequential transaction submission is now the default; use `--fast` to opt out (higher nonce conflict risk)
10. **Retry support**: `DEPLOY_MAX_RETRIES=3 ./deploy.sh ...` enables automatic retry with 5s backoff for transient RPC failures

### Task 7: Refactored verify_v2_staging_prod.sh
- Reduced from 1121 to 944 lines
- Sources `lib_deploy.sh` for colors, UI (`print_header`, `print_separator`, `print_network_header`), path setup, `load_credentials()`
- **Eliminated 3x duplicated `network_suffix` case statement** (was in `load_contract_addresses`, `get_contract_address`, `verify_network`) — replaced with `get_output_json()` helper that uses `get_network_name()` from network config
- Simplified `get_contract_address()` to use `get_output_json()` instead of its own case statement
- Added per-contract tracking arrays: `VERIFIED_CONTRACTS`, `FAILED_CONTRACTS`, `SKIPPED_CONTRACTS`
- Summary now shows contract-level counts (verified/failed/skipped) and lists all failures/skips
- Fixed `verify_contract()` to capture exit code directly instead of checking `$?` after intervening echo commands
- Merged duplicated Stargate constructor arg entries into single case pattern
- Environment loading is done directly (not via `validate_environment()`) since verify doesn't need locked bytecode path or FORGE_ENV
- All verification-specific logic preserved: `generate_constructor_args()`, `get_contract_source()`, chain-specific verifier config (Blockscout for Flare, Etherscan V2 API with chainid for 988/999/80094)
- **NEW: Post-verification status check** — `check_all_verification_status()` queries Etherscan V2 / Blockscout APIs after all forge verify-contract calls to confirm which contracts are actually verified on the block explorer. Reports per-chain verified/unverified counts and lists all unverified contracts. Uses `is_contract_verified()` helper with 1s rate limit between requests. Script exits with code 1 if any contracts remain unverified.

## Verification Checklist
- [x] `bash -n script/run/utils/lib_deploy.sh` — passes
- [x] `bash -n script/run/deploy/deploy_v2_staging_prod.sh` — passes
- [x] `bash -n script/run/deploy/deploy_v2_other_hooks_staging_prod.sh` — passes
- [x] `bash -n script/run/verify/verify_v2_staging_prod.sh` — passes
- [ ] `./script/run/deploy/deploy_v2_staging_prod.sh staging simulate v2` — needs live test
- [ ] `./script/run/deploy/deploy_v2_staging_prod.sh prod simulate v2` — needs live test
- [ ] `./script/run/verify/verify_v2_staging_prod.sh staging` — needs live test
- [ ] Verify post-deployment verification step identifies contracts correctly — needs live test

---

## Follow-up Cleanup (Session 20b): Move shared libs to utils/ + consolidate bytecode folders

### Part 1: Moved shared libs into `script/run/utils/`

Moved 4 shared library files from `script/run/` root into `script/run/utils/`:
- `lib_deploy.sh` — shared deployment library
- `oracle-utils.sh` — oracle utility functions
- `networks-production.sh` — production network configuration
- `networks-staging.sh` — staging network configuration

Updated `lib_deploy.sh` PROJECT_ROOT: `../../..` (was `../..`) to account for the extra directory level.

Updated 4 scripts sourcing `lib_deploy.sh` (changed `/../lib_deploy.sh` to `/../utils/lib_deploy.sh`):
- `deploy/deploy_v2_staging_prod.sh`
- `deploy/deploy_v2_other_hooks_staging_prod.sh`
- `verify/verify_v2_staging_prod.sh`
- `test/smoke_test_treasury_config.sh`

Updated 9 scripts sourcing network/oracle files (changed `/../networks-*.sh` / `/../oracle-utils.sh` to `/../utils/...`):
- `deploy/deploy_super_sponsorship_paymaster.sh`
- `config/config_supervault_oracle.sh`
- `config/config_v2_ledger_staging_prod.sh`
- `config/transfer_sponsorship_paymaster_roles.sh`
- `config/add_to_super_ledger_staging_prod.sh`
- `config/add_to_super_ledger_vnet.sh`
- `tooling/extract_configurable_oracles.sh`
- `tooling/generate_latest_json.sh`
- `tooling/upload_contracts_to_s3.sh`

Scripts inheriting `$SCRIPT_DIR` from lib_deploy.sh (`verify/verify_v2_staging_prod.sh`, `test/smoke_test_treasury_config.sh`) needed no changes — `$SCRIPT_DIR` now resolves to `script/run/utils/` where both network files live.

### Part 2: Consolidated `generated-bytecode-other/` into `generated-bytecode/`

- `tooling/regenerate_bytecode.sh`: Replaced 6 inline copy blocks (~90 lines) with calls to existing `copy_contract()` function. Removed `mkdir -p script/generated-bytecode-other`. Updated comments and summary message.
- `script/DeployV2OtherHooks.s.sol`: Changed staging bytecode path from `script/generated-bytecode-other/` to `script/generated-bytecode/`. Production `locked-bytecode-other/` unchanged.
- `deploy/deploy_v2_other_hooks_staging_prod.sh`: Changed staging bytecode check from `generated-bytecode-other` to `generated-bytecode`.
- Deleted `script/generated-bytecode-other/` directory (24 files — will now be generated into `script/generated-bytecode/`).

### Verification
- All 15 modified shell scripts pass `bash -n` syntax check
- `grep -r "generated-bytecode-other"` in .sh/.sol files returns 0 results (only docs/specs have historical references)
- `grep -r "../lib_deploy|../networks-|../oracle-utils"` in `script/run/` returns 0 results (all updated to `../utils/`)
- `forge build` succeeds
