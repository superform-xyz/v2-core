#!/usr/bin/env bash

###################################################################################
# Deploy RelayAdapterV2 Script
###################################################################################
# Description:
#   Deploys ONLY RelayAdapterV2 across the configured networks, via the scoped
#   `runRelayAdapterV2(bool,uint256,uint64)` entrypoint in DeployV2Core.s.sol.
#
#   Why a scoped script rather than the full core deploy:
#   RelayAdapterV2 ships ALONGSIDE the existing RelayAdapter, which is live on 17 chains
#   with locked bytecode and must keep serving in-flight fills plus any escrowed
#   failedTransfers (those cannot be migrated). The full deploy_v2_staging_prod.sh is
#   idempotent and would also work, but it touches every core contract; this keeps the
#   blast radius to the one new adapter.
#
#   The entrypoint reuses the SuperDestinationExecutor already recorded in this chain's
#   output JSON — it never redeploys it — and skips any chain where the Relay depository
#   is not configured.
#
#   Sources lib_deploy.sh for shared deployment utilities. DEPLOY_SIG overrides the
#   default generic run() signature for both the check and deploy phases.
#
# Usage:
#   ./script/run/deploy/deploy_relay_adapter_v2.sh <environment> <mode> <account> [--slow] [--resume] [--legacy]
#
#   Simulate on staging first:
#     ./script/run/deploy/deploy_relay_adapter_v2.sh staging simulate v2
#   Then deploy:
#     ./script/run/deploy/deploy_relay_adapter_v2.sh staging deploy v2
#
# Arguments:
#   environment: staging or prod
#   mode: simulate or deploy
#   account: foundry account name (e.g., v2, deployer, main)
#   --slow: (optional) send transactions one at a time
#   --resume: (optional) resume from previous broadcast
#   --legacy: (optional) use legacy transactions with 1 gwei gas price
#
# Prerequisites:
#   - script/locked-bytecode/RelayAdapterV2.json must exist and be current.
#     Regenerate with: ./script/run/tooling/regenerate_bytecode.sh RelayAdapterV2
#     then copy it into script/locked-bytecode/ (this copy is manual by design — there is
#     no automated path into the locked set).
#   - SuperDestinationExecutor must already be deployed on each target chain.
#
# Post-deploy:
#   - RelayAdapterV2 gets a NEW address (different initcode => different CREATE2 address).
#     The solver/bundler quote must be pointed at it before it receives any fills.
#   - SuperVault cap-aware flows gate on ICrossChainPositionCapGuard.isApprovedAdapter,
#     so governance must approve the new adapter address per chain.
###################################################################################

set -eo pipefail

# Source shared deployment library
source "$(dirname "${BASH_SOURCE[0]}")/../utils/lib_deploy.sh"

FORGE_SCRIPT="script/DeployV2Core.s.sol:DeployV2Core"

# Scoped entrypoint — overrides the generic run() used by the full core deploy.
export DEPLOY_SIG="runRelayAdapterV2(bool,uint256,uint64)"

# ── Setup ──────────────────────────────────────────────────────────────────────
print_header "RelayAdapterV2 Deployment Script"

parse_args "$@"
validate_environment "$ENVIRONMENT"
validate_account "$ACCOUNT"
setup_mode_flags "$MODE"
load_credentials
create_output_directories

# ── Locked bytecode preflight ──────────────────────────────────────────────────
# All environments deploy from locked-bytecode/. Fail loudly rather than letting the
# Solidity side revert mid-broadcast on a missing artifact.
LOCKED_ARTIFACT="$PROJECT_ROOT/script/locked-bytecode/RelayAdapterV2.json"
if [[ ! -f "$LOCKED_ARTIFACT" ]]; then
    echo "ERROR: missing $LOCKED_ARTIFACT"
    echo "  Run: ./script/run/tooling/regenerate_bytecode.sh RelayAdapterV2"
    echo "  Then copy script/generated-bytecode/RelayAdapterV2.json into script/locked-bytecode/"
    exit 1
fi

# ── Run ────────────────────────────────────────────────────────────────────────
run_check_phase "$FORGE_SCRIPT"
run_deploy_phase "$FORGE_SCRIPT"
verify_deployments
print_summary
