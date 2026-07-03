#!/usr/bin/env bash

###################################################################################
# V2 Core Production/Staging Deployment Script
###################################################################################
# Description:
#   Deploys V2 Core contracts via DeployV2Core.s.sol across configured networks.
#   Thin orchestrator that sources lib_deploy.sh for all shared logic.
#
# Usage:
#   ./script/run/deploy/deploy_v2_staging_prod.sh <environment> <mode> <account> [--slow] [--resume] [--legacy]
#
# Arguments:
#   environment: staging or prod
#   mode: simulate or deploy
#   account: foundry account name (e.g., v2, deployer, main)
#   --slow: (optional) send transactions one at a time
#   --resume: (optional) resume from previous broadcast
#   --legacy: (optional) use legacy transactions with 1 gwei gas price
###################################################################################

# Source shared deployment library
source "$(dirname "${BASH_SOURCE[0]}")/../utils/lib_deploy.sh"

FORGE_SCRIPT="script/DeployV2Core.s.sol:DeployV2Core"

# ── Setup ──────────────────────────────────────────────────────────────────────
print_header "V2 Core Production/Staging Deployment Script"

parse_args "$@"
validate_environment "$ENVIRONMENT"
validate_account "$ACCOUNT"
setup_mode_flags "$MODE"
load_credentials
create_output_directories

# ── Pre-flight: bytecode analysis ──────────────────────────────────────────────
print_separator
echo -e "${BLUE}Analyzing bytecode availability...${NC}"
report_bytecode_availability
echo -e "${GREEN}Bytecode availability analysis completed${NC}"
echo -e "${CYAN}   Deployment will proceed, skipping any contracts with missing bytecode${NC}"

# ── Check phase: scan all networks ─────────────────────────────────────────────
run_check_phase "$FORGE_SCRIPT"

# ── Analyze & confirm ──────────────────────────────────────────────────────────
analyze_and_confirm

# ── Keystore password (after confirmation, before deploy) ──────────────────────
prompt_keystore_password "$ACCOUNT"

# ── Deploy phase ───────────────────────────────────────────────────────────────
run_deploy_phase "$FORGE_SCRIPT"

# ── Post-deployment verification ───────────────────────────────────────────────
verify_deployments

# ── Summary ────────────────────────────────────────────────────────────────────
print_summary "V2 Core"
