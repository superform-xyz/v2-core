#!/usr/bin/env bash
#
# lib_deploy.sh — Shared deployment library for Superform V2 deployment scripts
#
# Usage: source this file from deployment orchestrator scripts.
#   source "$(dirname "${BASH_SOURCE[0]}")/../utils/lib_deploy.sh"
#

# ── Guard against double-sourcing ──────────────────────────────────────────────
[[ -n "${_LIB_DEPLOY_LOADED:-}" ]] && return 0
_LIB_DEPLOY_LOADED=1

# ── Colors ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# ── Path setup ─────────────────────────────────────────────────────────────────
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$LIB_DIR"
PROJECT_ROOT="$(cd "$LIB_DIR/../../.." && pwd)"

# ── Global state ───────────────────────────────────────────────────────────────
LOCKED_BYTECODE_PATH=""

# Associative arrays for deployment status tracking (used by check/analyze phase)
declare -A NETWORK_DEPLOYMENT_STATUS
declare -A NETWORK_MISSING_CONTRACTS

# Tracking arrays for check phase
declare -a FAILED_NETWORKS=()
declare -a SUCCESSFUL_NETWORKS=()

# Tracking arrays/counters for deploy phase
declare -a FAILED_DEPLOY_NETWORKS=()
deployed_networks=0
skipped_networks=0

# Chains where forge doesn't support --chain (not in forge's internal registry)
FORGE_UNSUPPORTED_CHAINS=("988")

# Cached deployer address (populated after keystore password is provided)
DEPLOYER_ADDRESS=""

# Deploy lock file path (set by acquire_deploy_lock)
DEPLOY_LOCK_FILE=""

# ── Cleanup ────────────────────────────────────────────────────────────────────

# Unified cleanup handler for all resources (password file, lock file).
# Individual functions set their respective globals; this trap cleans them all.
_lib_deploy_cleanup() {
    rm -f "${PASS_FILE:-}"
    if [[ -n "${DEPLOY_LOCK_FILE:-}" ]]; then
        rm -f "$DEPLOY_LOCK_FILE"
    fi
}
trap '_lib_deploy_cleanup' EXIT

# ── Logging ────────────────────────────────────────────────────────────────────
log() {
    local level=$1
    shift
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*" >&2
}

# ── UI helpers ─────────────────────────────────────────────────────────────────

# Print a colored header box with the given title
print_header() {
    local title=$1
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                                                      ║${NC}"
    echo -e "${CYAN}║${WHITE}                    ${title}                ${CYAN}║${NC}"
    echo -e "${CYAN}║                                                                                      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
}

# Print a section separator line
print_separator() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Print a network deployment header
print_network_header() {
    local network=$1
    echo -e "${PURPLE}╭─────────────────────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}│${WHITE}                           Deploying to ${network} Network                          ${PURPLE}│${NC}"
    echo -e "${PURPLE}╰─────────────────────────────────────────────────────────────────────────────────────╯${NC}"
}

# ── Argument parsing ───────────────────────────────────────────────────────────

# Parse positional and optional flag arguments.
# Sets globals: ENVIRONMENT, MODE, ACCOUNT, SLOW_FLAG, BATCH_SIZE_FLAG,
#               RESUME_FLAG, LEGACY_FLAG, GAS_PRICE_FLAG
# NOTE: --slow is ON by default (sequential txs prevent nonce conflicts).
#       Use --fast to opt out and send transactions in parallel.
parse_args() {
    if [ $# -lt 3 ]; then
        echo -e "${RED}Error: Missing required arguments${NC}"
        echo -e "${YELLOW}Usage: $0 <environment> <mode> <account> [--fast] [--resume] [--legacy]${NC}"
        echo -e "${CYAN}  environment: staging or prod${NC}"
        echo -e "${CYAN}  mode: simulate or deploy${NC}"
        echo -e "${CYAN}  account: foundry account name (e.g., v2, deployer, main)${NC}"
        echo -e "${CYAN}  --fast: (optional) send transactions in parallel (default is sequential/slow)${NC}"
        echo -e "${CYAN}  --resume: (optional) resume from previous broadcast (use after interruption)${NC}"
        echo -e "${CYAN}  --legacy: (optional) use legacy transactions with 1 gwei gas price${NC}"
        echo -e "${CYAN}Examples:${NC}"
        echo -e "${CYAN}  $0 staging simulate v2${NC}"
        echo -e "${CYAN}  $0 prod deploy deployer${NC}"
        echo -e "${CYAN}  $0 prod deploy deployer --resume${NC}"
        echo -e "${CYAN}  $0 prod deploy deployer --fast${NC}"
        echo -e "${CYAN}Available accounts: $(cast wallet list 2>/dev/null | sed 's/ (Local)//' | tr '\n' ' ' || echo 'Run "cast wallet list" to see available accounts')${NC}"
        exit 1
    fi

    ENVIRONMENT=$1
    MODE=$2
    ACCOUNT=$3

    # Default: --slow is ON (sequential transactions prevent nonce conflicts)
    SLOW_FLAG="--slow"
    BATCH_SIZE_FLAG="--batch-size 1"
    RESUME_FLAG=""
    LEGACY_FLAG=""
    GAS_PRICE_FLAG=""
    local fast_mode=false

    for arg in "${@:4}"; do
        case "$arg" in
            --fast)
                fast_mode=true
                ;;
            --slow)
                # Explicit --slow is accepted for backwards compatibility (already the default)
                ;;
            --resume)
                RESUME_FLAG="--resume"
                echo -e "${YELLOW}Resume mode enabled: will continue from previous broadcast${NC}"
                ;;
            --legacy)
                LEGACY_FLAG="--legacy"
                GAS_PRICE_FLAG="--with-gas-price 1gwei"
                echo -e "${YELLOW}Legacy mode enabled: using legacy transactions with 1 gwei gas price${NC}"
                ;;
        esac
    done

    # Apply fast mode (disables default --slow)
    if [[ "$fast_mode" == "true" ]]; then
        SLOW_FLAG=""
        BATCH_SIZE_FLAG=""
        echo -e "${YELLOW}Fast mode: transactions will be sent in parallel (higher nonce conflict risk)${NC}"
    else
        echo -e "${CYAN}Sequential mode (default): transactions sent one at a time (batch-size=1)${NC}"
    fi
}

# ── Validation ─────────────────────────────────────────────────────────────────

# Validate the environment argument, source network configuration, and set up paths.
# Sets globals: LOCKED_BYTECODE_PATH, FORGE_ENV, CI, GITHUB_REF_NAME
validate_environment() {
    local env=$1

    if [ "$env" = "staging" ]; then
        echo -e "${CYAN}Loading staging network configuration...${NC}"
        LOCKED_BYTECODE_PATH="$PROJECT_ROOT/script/locked-bytecode-dev"
        echo -e "${CYAN}Using staging locked bytecode folder: locked-bytecode-dev${NC}"
        source "$SCRIPT_DIR/networks-staging.sh"
        FORGE_ENV=2
        export CI=true
        export GITHUB_REF_NAME="staging"
    elif [ "$env" = "prod" ]; then
        echo -e "${CYAN}Loading production network configuration...${NC}"
        LOCKED_BYTECODE_PATH="$PROJECT_ROOT/script/locked-bytecode"
        echo -e "${CYAN}Using production locked bytecode folder: locked-bytecode${NC}"
        source "$SCRIPT_DIR/networks-production.sh"
        FORGE_ENV=0
        export CI=true
        export GITHUB_REF_NAME="prod"
    else
        echo -e "${RED}Invalid environment: $env${NC}"
        echo -e "${YELLOW}Environment must be either 'staging' or 'prod'${NC}"
        exit 1
    fi

    # Validate that the locked bytecode directory exists
    if [[ ! -d "$LOCKED_BYTECODE_PATH" ]]; then
        echo -e "${RED}Error: Locked bytecode directory does not exist: $LOCKED_BYTECODE_PATH${NC}"
        echo -e "${YELLOW}Please ensure the environment-specific locked bytecode folder exists before deployment.${NC}"
        exit 1
    fi

    # Validate that the network configuration actually loaded networks
    if [[ ${#NETWORKS[@]} -eq 0 ]]; then
        echo -e "${RED}Error: No networks configured for $env environment${NC}"
        echo -e "${YELLOW}Check the NETWORKS array in networks-${env/%prod/production}.sh${NC}"
        exit 1
    fi

    echo -e "${CYAN}Network configuration loaded for $env environment (${#NETWORKS[@]} networks)${NC}"
    print_network_info

    # Change to project root for forge commands
    echo -e "${CYAN}Changing to project root: $PROJECT_ROOT${NC}"
    cd "$PROJECT_ROOT"

    # Export for Solidity scripts
    export SUPERFORM_PROJECT_ROOT="$PROJECT_ROOT"
    echo -e "${CYAN}Exported SUPERFORM_PROJECT_ROOT: $SUPERFORM_PROJECT_ROOT${NC}"
}

# Validate that the account exists in foundry wallet list.
validate_account() {
    local account=$1
    if ! cast wallet list 2>/dev/null | sed 's/ (Local)//' | grep -q "^$account$"; then
        echo -e "${RED}Account '$account' not found in foundry wallet list${NC}"
        echo -e "${YELLOW}Available accounts:${NC}"
        cast wallet list 2>/dev/null | sed 's/ (Local)//' | sed 's/^/  - /' || echo -e "${RED}  No accounts found. Run 'cast wallet import' to add accounts.${NC}"
        exit 1
    fi
}

# Set broadcast/verify flags based on deploy mode.
# Sets globals: BROADCAST_FLAG, VERIFY_FLAG
setup_mode_flags() {
    local mode=$1
    if [ "$mode" = "simulate" ]; then
        echo -e "${YELLOW}Running in simulation mode for $ENVIRONMENT...${NC}"
        echo -e "${CYAN}   - No broadcasting to network${NC}"
        echo -e "${CYAN}   - No contract verification${NC}"
        BROADCAST_FLAG=""
        VERIFY_FLAG=""
    elif [ "$mode" = "deploy" ]; then
        echo -e "${GREEN}Running in deployment mode for $ENVIRONMENT...${NC}"
        echo -e "${CYAN}   - Broadcasting to network${NC}"
        echo -e "${CYAN}   - Tenderly public verification enabled${NC}"
        BROADCAST_FLAG="--broadcast"
        VERIFY_FLAG="--verify"
    else
        echo -e "${RED}Invalid mode: $mode${NC}"
        echo -e "${YELLOW}Mode must be either 'simulate' or 'deploy'${NC}"
        exit 1
    fi
}

# ── Credentials ────────────────────────────────────────────────────────────────

# Load RPC URLs and Etherscan API key using network-specific functions.
# Requires: network config already sourced (via validate_environment).
load_credentials() {
    print_separator
    echo -e "${BLUE}Loading Configuration...${NC}"

    # Load RPC URLs using network-specific function
    echo -e "${CYAN}   - Loading RPC URLs...${NC}"
    if ! load_rpc_urls; then
        echo -e "${RED}Failed to load some RPC URLs from credential manager${NC}"
        echo -e "${YELLOW}This may cause connectivity issues during deployment verification${NC}"
        echo -e "${YELLOW}   Please ensure all required RPC URLs are configured in 1Password${NC}"
        # Continue but with warning - the address checking phase will catch specific failures
    fi

    # Load Etherscan V2 API key for verification
    echo -e "${CYAN}   - Loading Etherscan V2 API credentials...${NC}"
    if ! load_etherscan_api_key; then
        echo -e "${RED}Failed to load Etherscan V2 API key${NC}"
        echo -e "${RED}   Contract verification will not work without this credential${NC}"
        exit 1
    fi

    echo -e "${GREEN}Configuration loaded successfully${NC}"
    echo -e "${CYAN}   - Using Etherscan V2 verification${NC}"
    echo -e "${CYAN}   - Environment: $ENVIRONMENT${NC}"
    echo -e "${CYAN}   - Account: $ACCOUNT${NC}"
}

# ── Output directories ─────────────────────────────────────────────────────────

# Create per-network output directories for the current environment.
create_output_directories() {
    for network_def in "${NETWORKS[@]}"; do
        IFS=':' read -r network_id _ _ <<< "$network_def"
        mkdir -p "$PROJECT_ROOT/script/output/$ENVIRONMENT/$network_id"
    done
    echo -e "${CYAN}   - Created output directories for all networks${NC}"
}

# ── Keystore password ──────────────────────────────────────────────────────────

# Prompt for the keystore password, verify it, and store in a secure temp file.
# Sets globals: PASS_FILE, KEYSTORE_PASSWORD_FLAG
prompt_keystore_password() {
    local account=$1

    print_separator
    echo -e "${WHITE}Enter keystore password for account '${account}' (will be used for all chain deployments):${NC}"
    read -s -p "" KEYSTORE_PASSWORD
    echo ""

    if [[ -z "$KEYSTORE_PASSWORD" ]]; then
        echo -e "${RED}Error: Empty password provided${NC}"
        exit 1
    fi

    # Verify the password works by attempting to access the account
    if ! cast wallet address --account "$account" --password "$KEYSTORE_PASSWORD" &>/dev/null; then
        echo -e "${RED}Error: Invalid password for account '$account'${NC}"
        exit 1
    fi
    echo -e "${GREEN}Keystore password verified successfully${NC}"

    # Store in a temp file (more secure than command-line arg visible in /proc)
    PASS_FILE=$(mktemp)
    chmod 600 "$PASS_FILE"
    echo "$KEYSTORE_PASSWORD" > "$PASS_FILE"
    unset KEYSTORE_PASSWORD
    # PASS_FILE is cleaned up by _lib_deploy_cleanup trap

    KEYSTORE_PASSWORD_FLAG="--password-file $PASS_FILE"

    # Cache the deployer address now that we have the password
    DEPLOYER_ADDRESS=$(cast wallet address --account "$ACCOUNT" --password-file "$PASS_FILE" 2>/dev/null) || true
    if [[ -n "$DEPLOYER_ADDRESS" ]]; then
        echo -e "${CYAN}   Deployer address: $DEPLOYER_ADDRESS${NC}"
    fi
}

# ── Chain support helpers ──────────────────────────────────────────────────────

# Check if a chain ID is in the FORGE_UNSUPPORTED_CHAINS list.
# Returns 0 if the chain is unsupported (should be skipped), 1 otherwise.
is_unsupported_chain() {
    local chain_id=$1
    for unsupported in "${FORGE_UNSUPPORTED_CHAINS[@]}"; do
        if [[ "$chain_id" == "$unsupported" ]]; then
            return 0
        fi
    done
    return 1
}

# ── JSON merge ─────────────────────────────────────────────────────────────────

# Preserve entries in chain output JSON that the forge script doesn't manage
# (e.g., Nexus contracts deployed by a separate process).
preserve_existing_json_entries() {
    local output_file=$1
    local backup_file=$2

    if [[ ! -f "$backup_file" ]] || [[ ! -f "$output_file" ]]; then
        return 0
    fi

    # Merge: start with the new output, then add any keys from the backup that are missing
    local merged
    merged=$(python3 -c "
import json, sys
with open('$output_file') as f:
    new = json.load(f)
with open('$backup_file') as f:
    old = json.load(f)
# Add back any keys from the old file that are missing in the new file
changed = False
for k, v in old.items():
    if k not in new:
        new[k] = v
        changed = True
if changed:
    print(json.dumps(new, indent=2, sort_keys=True))
else:
    sys.exit(1)
" 2>/dev/null) || true

    if [[ -n "$merged" ]]; then
        echo "$merged" > "$output_file"
        echo -e "${CYAN}   Preserved existing entries in output file${NC}"
    fi
}

# ── Bytecode analysis ─────────────────────────────────────────────────────────

# Extract contract names from the specified array in regenerate_bytecode.sh.
extract_contracts_from_regenerate_script() {
    local array_name=$1
    local script_path="$PROJECT_ROOT/script/run/tooling/regenerate_bytecode.sh"

    if [[ ! -f "$script_path" ]]; then
        return 1
    fi

    # Extract contract names from the specified array in regenerate_bytecode.sh
    # Match from "ARRAY_NAME=(" up to the first line containing only ")"
    # Use awk to stop at the first closing paren (sed range is greedy)
    awk "/${array_name}=\\(/{found=1} found{print; if(/^\\)/) exit}" "$script_path" | grep -o '"[^"]*"' | tr -d '"'
}

# Report bytecode availability (sourced from regenerate_bytecode.sh).
report_bytecode_availability() {
    log "INFO" "Analyzing bytecode availability from $LOCKED_BYTECODE_PATH..."

    local script_path="$PROJECT_ROOT/script/run/tooling/regenerate_bytecode.sh"
    if [[ ! -f "$script_path" ]]; then
        echo -e "${RED}Cannot find regenerate_bytecode.sh at: $script_path${NC}"
        return 1
    fi

    local missing_contracts=()
    local available_contracts=()
    local missing_core=()
    local missing_hooks=()
    local missing_oracles=()

    # Extract and check core contracts
    log "INFO" "Checking core contracts from regenerate_bytecode.sh..."
    local core_contracts
    core_contracts=$(extract_contracts_from_regenerate_script "CORE_CONTRACTS")
    for contract in $core_contracts; do
        [[ -z "$contract" ]] && continue
        local file_path="$LOCKED_BYTECODE_PATH/${contract}.json"
        if [ ! -f "$file_path" ]; then
            missing_contracts+=("$contract")
            missing_core+=("$contract")
        else
            available_contracts+=("$contract")
        fi
    done

    # Extract and check hook contracts
    log "INFO" "Checking hook contracts from regenerate_bytecode.sh..."
    local hook_contracts
    hook_contracts=$(extract_contracts_from_regenerate_script "HOOK_CONTRACTS")
    for contract in $hook_contracts; do
        [[ -z "$contract" ]] && continue
        local file_path="$LOCKED_BYTECODE_PATH/${contract}.json"
        if [ ! -f "$file_path" ]; then
            missing_contracts+=("$contract")
            missing_hooks+=("$contract")
        else
            available_contracts+=("$contract")
        fi
    done

    # Extract and check oracle contracts
    log "INFO" "Checking oracle contracts from regenerate_bytecode.sh..."
    local oracle_contracts
    oracle_contracts=$(extract_contracts_from_regenerate_script "ORACLE_CONTRACTS")
    for contract in $oracle_contracts; do
        [[ -z "$contract" ]] && continue
        local file_path="$LOCKED_BYTECODE_PATH/${contract}.json"
        if [ ! -f "$file_path" ]; then
            missing_contracts+=("$contract")
            missing_oracles+=("$contract")
        else
            available_contracts+=("$contract")
        fi
    done

    # Show summary
    local expected_total
    expected_total=$(get_expected_contract_count)
    echo -e "${CYAN}Bytecode Availability Summary${NC}"
    echo -e "${GREEN}   Available contracts: ${#available_contracts[@]}${NC}"
    echo -e "${YELLOW}   Missing contracts: ${#missing_contracts[@]}${NC}"
    echo -e "${BLUE}   Expected total: $expected_total${NC}"
    echo ""

    if [ ${#missing_contracts[@]} -gt 0 ]; then
        echo -e "${YELLOW}Contracts that will be SKIPPED due to missing bytecode:${NC}"

        if [ ${#missing_core[@]} -gt 0 ]; then
            echo -e "${YELLOW}   Core Contracts (${#missing_core[@]}):${NC}"
            for contract in "${missing_core[@]}"; do
                echo -e "${YELLOW}     - $contract${NC}"
            done
        fi

        if [ ${#missing_hooks[@]} -gt 0 ]; then
            echo -e "${YELLOW}   Hook Contracts (${#missing_hooks[@]}):${NC}"
            for contract in "${missing_hooks[@]}"; do
                echo -e "${YELLOW}     - $contract${NC}"
            done
        fi

        if [ ${#missing_oracles[@]} -gt 0 ]; then
            echo -e "${YELLOW}   Oracle Contracts (${#missing_oracles[@]}):${NC}"
            for contract in "${missing_oracles[@]}"; do
                echo -e "${YELLOW}     - $contract${NC}"
            done
        fi

        echo ""
        echo -e "${YELLOW}These contracts are defined in the system but will not be deployed.${NC}"
        echo -e "${YELLOW}   To deploy them, ensure their bytecode artifacts are present in: $LOCKED_BYTECODE_PATH${NC}"
        echo ""
    else
        echo -e "${GREEN}All defined contracts have bytecode available${NC}"
        echo ""
    fi

    # Always return success to allow deployment to continue
    return 0
}

# Get expected contract count from regenerate_bytecode.sh.
get_expected_contract_count() {
    local script_path="$PROJECT_ROOT/script/run/tooling/regenerate_bytecode.sh"

    if [[ ! -f "$script_path" ]]; then
        echo "0"
        return 1
    fi

    local core_count hook_count oracle_count

    # Extract array elements using awk (stops at first closing paren, unlike sed range which is greedy)
    core_count=$(awk '/CORE_CONTRACTS=\(/{found=1} found{print; if(/^\)/) exit}' "$script_path" | grep -o '"[^"]*"' | wc -l)
    hook_count=$(awk '/HOOK_CONTRACTS=\(/{found=1} found{print; if(/^\)/) exit}' "$script_path" | grep -o '"[^"]*"' | wc -l)
    oracle_count=$(awk '/ORACLE_CONTRACTS=\(/{found=1} found{print; if(/^\)/) exit}' "$script_path" | grep -o '"[^"]*"' | wc -l)

    local total_expected=$((core_count + hook_count + oracle_count))
    echo "$total_expected"
}

# ── Check phase (V2 Core) ─────────────────────────────────────────────────────

# Check V2 Core addresses on a network and capture deployment status.
# Stores results in NETWORK_DEPLOYMENT_STATUS and NETWORK_MISSING_CONTRACTS.
check_v2_addresses() {
    local network_id=$1
    local network_name=$2
    local rpc_url_var=$3
    local forge_script=${4:-"script/DeployV2Core.s.sol:DeployV2Core"}

    echo -e "${CYAN}Checking V2 Core addresses for $network_name (Chain ID: $network_id)...${NC}"

    # Check if RPC URL is set
    if [[ -z "${!rpc_url_var}" ]]; then
        echo -e "${RED}  ERROR: RPC URL variable $rpc_url_var is not set or empty${NC}"
        echo -e "${RED}     This indicates a configuration problem with network credentials${NC}"
        return 1
    fi

    # Capture the full output to parse deployment status
    local check_output
    local forge_exit_code

    # Run forge script and capture both output and exit code
    check_output=$(forge script "$forge_script" \
        --sig 'run(bool,uint256,uint64)' true $FORGE_ENV $network_id \
        --rpc-url "${!rpc_url_var}" \
        --chain $network_id \
        -vv 2>&1)
    forge_exit_code=$?

    # Check if forge command failed
    if [[ $forge_exit_code -ne 0 ]]; then
        echo -e "${RED}  ERROR: Forge script failed with exit code $forge_exit_code${NC}"
        echo -e "${RED}     This likely indicates RPC connectivity issues or network problems${NC}"
        echo -e "${YELLOW}  Forge output (last 10 lines):${NC}"
        echo "$check_output" | tail -10 | sed 's/^/     /'
        return 1
    fi

    # Display the relevant output lines (include MISSING contracts and deployment summary)
    echo "$check_output" | grep -e "Addr" -e "already deployed" -e "Code Size" -e "====" -e "====>" -e "MISSING" -e "Already Deployed" -e "Missing/Need Deployment" -e "Total Contracts"

    # Extract deployment counts from the summary line
    local summary_line
    summary_line=$(echo "$check_output" | grep "=====> On this chain we have")

    # Also extract contract availability information
    local availability_info
    availability_info=$(echo "$check_output" | grep -A5 "=== Contract Availability Analysis ===" || true)

    if [[ -n "$availability_info" ]]; then
        echo -e "${CYAN}  Contract Availability Analysis:${NC}"
        echo "$availability_info" | sed 's/^/     /'

        # Check for skipped contracts
        local skipped_info
        skipped_info=$(echo "$check_output" | grep -A10 "=== Contracts SKIPPED due to missing configurations ===" || true)
        if [[ -n "$skipped_info" ]]; then
            echo -e "${YELLOW}  Skipped Contracts:${NC}"
            echo "$skipped_info" | sed 's/^/     /'
        fi
        echo ""
    fi

    if [[ -n "$summary_line" ]]; then
        # Parse: "=====> On this chain we have X contracts already deployed out of Y"
        local deployed_count
        deployed_count=$(echo "$summary_line" | grep -o "have [0-9]\+ contracts" | grep -o "[0-9]\+")
        local total_count
        total_count=$(echo "$summary_line" | grep -o "out of [0-9]\+" | grep -o "[0-9]\+")

        if [[ -n "$deployed_count" && -n "$total_count" ]]; then
            # Store deployment status for this network
            NETWORK_DEPLOYMENT_STATUS["${network_id}"]="${deployed_count}:${total_count}:${network_name}"

            # Extract and store missing contract names
            local missing_contracts
            missing_contracts=$(echo "$check_output" | grep "\[MISSING\]" | sed 's/.*\[MISSING\] //' | sed 's/ needs deployment.*//' | tr '\n' ',' | sed 's/,$//')
            if [[ -n "$missing_contracts" ]]; then
                NETWORK_MISSING_CONTRACTS["${network_id}"]="${missing_contracts}"
            fi

            echo -e "${GREEN}  Successfully checked: ${deployed_count}/${total_count} contracts deployed${NC}"
            return 0
        else
            echo -e "${RED}  ERROR: Could not parse deployment counts from summary line${NC}"
            echo -e "${YELLOW}     Summary line: $summary_line${NC}"
            return 1
        fi
    else
        echo -e "${RED}  ERROR: Could not find deployment summary in forge output${NC}"
        echo -e "${RED}     This indicates the forge script didn't complete successfully${NC}"
        echo -e "${YELLOW}  Full forge output:${NC}"
        echo "$check_output" | sed 's/^/     /'
        return 1
    fi
}

# Analyze deployment status across all networks and determine next steps.
# Returns: 0 = all deployed, 1 = needs deployment, 2 = error
analyze_deployment_status() {
    echo -e "${BLUE}Analyzing deployment status across all networks...${NC}"
    echo ""

    local all_fully_deployed=true
    local needs_deployment=false
    local networks_with_missing=()

    # Get expected contract count from regenerate_bytecode.sh
    local total_expected
    total_expected=$(get_expected_contract_count)

    if [[ $total_expected -eq 0 ]]; then
        echo -e "${RED}Unable to determine expected contract count from regenerate_bytecode.sh${NC}"
        return 2
    fi

    echo -e "${CYAN}Expected contracts vary per network based on available configurations${NC}"
    echo -e "${CYAN}  - Core contracts: ${WHITE}10 (always deployed)${NC}"
    echo -e "${CYAN}  - Adapters: ${WHITE}0-2 (depends on bridge support)${NC}"
    echo -e "${CYAN}  - Hooks: ${WHITE}27-32 (depends on router/protocol support)${NC}"
    echo -e "${CYAN}  - Oracles: ${WHITE}7 (always deployed)${NC}"
    echo ""

    # Analyze each network using their actual expected total (not regenerate_bytecode.sh)
    for network_id in "${!NETWORK_DEPLOYMENT_STATUS[@]}"; do
        IFS=':' read -r deployed actual_expected network_name <<< "${NETWORK_DEPLOYMENT_STATUS[$network_id]}"

        # Use the actual expected total reported by the checking script
        if [[ $deployed -eq $actual_expected ]]; then
            echo -e "${GREEN}$network_name (Chain $network_id): All $deployed/$actual_expected contracts deployed${NC}"
        elif [[ $deployed -lt $actual_expected ]]; then
            local missing=$((actual_expected - deployed))
            echo -e "${YELLOW}$network_name (Chain $network_id): $deployed/$actual_expected contracts deployed (${missing} missing)${NC}"
            # Show which contracts are missing
            if [[ -n "${NETWORK_MISSING_CONTRACTS[$network_id]}" ]]; then
                echo -e "${RED}   Missing contracts: ${NETWORK_MISSING_CONTRACTS[$network_id]}${NC}"
            fi
            all_fully_deployed=false
            needs_deployment=true
            networks_with_missing+=("$network_name")
        elif [[ $deployed -gt $actual_expected ]]; then
            echo -e "${CYAN}$network_name (Chain $network_id): $deployed/$actual_expected contracts deployed (more than expected)${NC}"
            echo -e "${CYAN}    Note: This may include additional contracts not tracked by availability analysis${NC}"
        else
            echo -e "${RED}$network_name (Chain $network_id): Error in deployment status${NC}"
            all_fully_deployed=false
        fi
    done

    echo ""

    # Determine action based on analysis
    if [[ $all_fully_deployed == true ]]; then
        echo -e "${GREEN}EXCELLENT! All contracts are already deployed on all networks!${NC}"
        echo -e "${GREEN}   Status: Fully deployed across all chains (contracts vary per chain based on configurations)${NC}"
        echo -e "${GREEN}   No deployment needed - terminating with success${NC}"
        return 0  # All deployed - skip deployment
    elif [[ $needs_deployment == true ]]; then
        echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║${WHITE}                           DEPLOYMENT REQUIRED                                     ${YELLOW}║${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${CYAN}   Expected contracts vary per network based on available configurations${NC}"
        echo ""
        echo -e "${WHITE}   Summary of missing contracts per network:${NC}"
        echo ""
        for network_id in "${!NETWORK_DEPLOYMENT_STATUS[@]}"; do
            IFS=':' read -r deployed actual_expected network_name <<< "${NETWORK_DEPLOYMENT_STATUS[$network_id]}"
            if [[ $deployed -lt $actual_expected ]]; then
                local missing=$((actual_expected - deployed))
                echo -e "${YELLOW}   $network_name (Chain $network_id): ${missing} missing out of ${actual_expected}${NC}"
                if [[ -n "${NETWORK_MISSING_CONTRACTS[$network_id]:-}" ]]; then
                    # Print each missing contract on its own line for readability
                    IFS=',' read -ra contracts <<< "${NETWORK_MISSING_CONTRACTS[$network_id]}"
                    for contract in "${contracts[@]}"; do
                        contract=$(echo "$contract" | xargs)  # trim whitespace
                        echo -e "${RED}      - $contract${NC}"
                    done
                fi
            fi
        done
        echo ""
        echo -e "${WHITE}   Only missing contracts will be deployed (existing ones will be skipped)${NC}"
        echo -e "${WHITE}   Contracts not available due to missing configurations will be automatically skipped${NC}"
        return 1  # Needs deployment - continue with confirmation
    else
        echo -e "${RED}Unable to determine deployment status${NC}"
        echo -e "${RED}   Please check the output above for specific network issues${NC}"
        return 2  # Error state
    fi
}

# ── Pre-deployment guards ──────────────────────────────────────────────────────

# Acquire a file lock to prevent concurrent deployment runs for the same environment.
# Creates a PID file in /tmp; detects and cleans up stale locks from dead processes.
acquire_deploy_lock() {
    DEPLOY_LOCK_FILE="/tmp/superform_deploy_${ENVIRONMENT}.lock"

    if [[ -f "$DEPLOY_LOCK_FILE" ]]; then
        local lock_pid
        lock_pid=$(cat "$DEPLOY_LOCK_FILE" 2>/dev/null)
        if [[ -n "$lock_pid" ]] && kill -0 "$lock_pid" 2>/dev/null; then
            echo -e "${RED}ERROR: Another deployment is already running for '$ENVIRONMENT' (PID: $lock_pid)${NC}"
            echo -e "${RED}   Lock file: $DEPLOY_LOCK_FILE${NC}"
            echo -e "${YELLOW}   If this is stale, remove the lock file manually: rm $DEPLOY_LOCK_FILE${NC}"
            exit 1
        else
            echo -e "${YELLOW}Removing stale lock file (PID $lock_pid is no longer running)${NC}"
            rm -f "$DEPLOY_LOCK_FILE"
        fi
    fi

    echo $$ > "$DEPLOY_LOCK_FILE"
    echo -e "${CYAN}   Deploy lock acquired (PID $$)${NC}"
}

# Get the cached deployer address (set during prompt_keystore_password).
# Falls back to resolving it if not yet cached.
get_deployer_address() {
    if [[ -z "$DEPLOYER_ADDRESS" && -n "${PASS_FILE:-}" ]]; then
        DEPLOYER_ADDRESS=$(cast wallet address --account "$ACCOUNT" --password-file "$PASS_FILE" 2>/dev/null) || true
    fi
    echo "$DEPLOYER_ADDRESS"
}

# Check for pending transactions (nonce mismatch) on a network before deploying.
# A mismatch between latest and pending nonce means transactions are in-flight,
# which can cause nonce conflicts when forge tries to deploy.
# Returns: 0 = OK, 1 = pending transactions detected (warning only, does not block)
check_deployer_nonce() {
    local network_id=$1
    local network_name=$2
    local rpc_var=$3

    local deployer
    deployer=$(get_deployer_address)
    [[ -z "$deployer" ]] && return 0

    local rpc_url="${!rpc_var:-}"
    [[ -z "$rpc_url" ]] && return 0

    # Get confirmed (latest) and pending nonces
    local latest_nonce pending_nonce
    latest_nonce=$(cast nonce "$deployer" --rpc-url "$rpc_url" 2>/dev/null) || return 0
    pending_nonce=$(cast nonce "$deployer" --rpc-url "$rpc_url" --block pending 2>/dev/null) || return 0

    # Validate outputs are numeric (cast errors can return text)
    if ! [[ "$latest_nonce" =~ ^[0-9]+$ ]] || ! [[ "$pending_nonce" =~ ^[0-9]+$ ]]; then
        echo -e "${YELLOW}   Nonce check: could not determine nonce (RPC may not support pending block)${NC}"
        return 0
    fi

    if [[ "$latest_nonce" != "$pending_nonce" ]]; then
        local stuck=$((pending_nonce - latest_nonce))
        echo -e "${RED}   WARNING: $stuck pending transaction(s) detected for deployer on $network_name${NC}"
        echo -e "${RED}      Latest nonce: $latest_nonce | Pending nonce: $pending_nonce${NC}"
        if [[ -n "$RESUME_FLAG" ]]; then
            echo -e "${CYAN}      --resume is set; pending txs may be from a previous partial deployment${NC}"
        else
            echo -e "${YELLOW}      Pending transactions may cause nonce conflicts during deployment.${NC}"
            echo -e "${YELLOW}      Consider waiting for them to confirm, or use --resume if resuming.${NC}"
        fi
        return 1
    fi

    echo -e "${GREEN}   Nonce OK ($latest_nonce) - no pending transactions${NC}"
    return 0
}

# Check that the deployer has a non-zero native balance on the target chain.
# A zero balance will cause deployment to fail due to insufficient gas.
# Returns: 0 = OK, 1 = zero balance (warning only, does not block)
check_deployer_balance() {
    local network_id=$1
    local network_name=$2
    local rpc_var=$3

    local deployer
    deployer=$(get_deployer_address)
    [[ -z "$deployer" ]] && return 0

    local rpc_url="${!rpc_var:-}"
    [[ -z "$rpc_url" ]] && return 0

    local balance_wei
    balance_wei=$(cast balance "$deployer" --rpc-url "$rpc_url" 2>/dev/null) || return 0

    # Validate output is numeric
    if ! [[ "$balance_wei" =~ ^[0-9]+$ ]]; then
        echo -e "${YELLOW}   Balance check: could not determine balance${NC}"
        return 0
    fi

    if [[ "$balance_wei" == "0" ]]; then
        echo -e "${RED}   WARNING: Deployer has ZERO balance on $network_name${NC}"
        echo -e "${YELLOW}      Deployment will fail due to insufficient gas funds.${NC}"
        echo -e "${YELLOW}      Fund $deployer before deploying to this chain.${NC}"
        return 1
    fi

    # Convert to ether for display
    local balance_eth
    balance_eth=$(cast from-wei "$balance_wei" 2>/dev/null) || balance_eth="$balance_wei wei"

    # Warn if balance is suspiciously low (< 0.01 ETH / ~10^16 wei)
    # Multi-contract deployments typically need 0.05+ ETH
    if [[ ${#balance_wei} -le 16 ]]; then
        echo -e "${YELLOW}   Balance LOW ($balance_eth) - may be insufficient for multi-contract deployment${NC}"
        return 1
    fi

    echo -e "${GREEN}   Balance OK ($balance_eth)${NC}"
    return 0
}

# Check for stale broadcast files from previous runs that might interfere.
# Warns if recent broadcast files exist for the given forge script.
check_stale_broadcasts() {
    local forge_script_base=$1  # e.g., "DeployV2Core" (without .s.sol path)
    local broadcast_dir="$PROJECT_ROOT/broadcast"

    if [[ ! -d "$broadcast_dir" ]]; then
        return 0
    fi

    # Find broadcast run files modified in the last 24 hours
    local stale_count
    stale_count=$(find "$broadcast_dir" -name "run-[0-9]*.json" -path "*${forge_script_base}*" -mmin -1440 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$stale_count" -gt 0 ]]; then
        echo -e "${YELLOW}   Found $stale_count recent broadcast file(s) for $forge_script_base (last 24h)${NC}"
        if [[ -n "$RESUME_FLAG" ]]; then
            echo -e "${CYAN}   --resume is set: will attempt to continue from previous broadcasts${NC}"
        else
            echo -e "${CYAN}   These will not interfere with a fresh deployment (forge creates new run files)${NC}"
        fi
    fi
}

# Run all pre-deployment safety checks for a single network.
# Combines nonce and balance checks. Returns 0 if all pass, 1 if any warn.
preflight_network_checks() {
    local network_id=$1
    local network_name=$2
    local rpc_var=$3
    local has_warnings=false

    # Only run in deploy mode — simulation doesn't broadcast
    if [[ "$MODE" != "deploy" ]]; then
        return 0
    fi

    echo -e "${CYAN}   Pre-flight checks:${NC}"

    if ! check_deployer_nonce "$network_id" "$network_name" "$rpc_var"; then
        has_warnings=true
    fi

    if ! check_deployer_balance "$network_id" "$network_name" "$rpc_var"; then
        has_warnings=true
    fi

    if [[ "$has_warnings" == "true" ]]; then
        return 1
    fi
    return 0
}

# ── Orchestration helpers ──────────────────────────────────────────────────────

# Run the check phase across all configured networks.
# Populates FAILED_NETWORKS, SUCCESSFUL_NETWORKS, NETWORK_DEPLOYMENT_STATUS.
run_check_phase() {
    local forge_script=$1

    print_separator
    echo -e "${BLUE}Checking contract addresses...${NC}"
    echo -e "${CYAN}This will show you which contracts are already deployed and which need to be deployed.${NC}"
    echo ""

    # Reset tracking arrays
    FAILED_NETWORKS=()
    SUCCESSFUL_NETWORKS=()

    # Check addresses on all networks
    for network_def in "${NETWORKS[@]}"; do
        IFS=':' read -r network_id network_name rpc_var <<< "$network_def"

        # Skip chains not supported by forge's --chain flag
        if is_unsupported_chain "$network_id"; then
            echo -e "${YELLOW}Skipping $network_name (Chain $network_id) - not supported by forge --chain${NC}"
            SUCCESSFUL_NETWORKS+=("$network_name (Chain $network_id) [skipped]")
            continue
        fi

        if check_v2_addresses "$network_id" "$network_name" "$rpc_var" "$forge_script"; then
            SUCCESSFUL_NETWORKS+=("$network_name (Chain $network_id)")
        else
            FAILED_NETWORKS+=("$network_name (Chain $network_id)")
            echo -e "${RED}  Failed to check deployment status for $network_name${NC}"
        fi
        echo ""
    done

    echo -e "${GREEN}Check phase completed${NC}"
}

# Analyze check results and get user confirmation to proceed with deployment.
# Exits the script if all deployed, user cancels, or errors detected.
analyze_and_confirm() {
    # Check if any networks failed during the check phase
    if [[ ${#FAILED_NETWORKS[@]} -gt 0 ]]; then
        echo -e "${RED}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║                                                                                      ║${NC}"
        echo -e "${RED}║${WHITE}                    NETWORK CONNECTIVITY ERRORS DETECTED                        ${RED}║${NC}"
        echo -e "${RED}║                                                                                      ║${NC}"
        echo -e "${RED}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${RED}CRITICAL ERROR: Unable to check deployment status on the following networks:${NC}"
        for failed_network in "${FAILED_NETWORKS[@]}"; do
            echo -e "${RED}   - $failed_network${NC}"
        done
        echo ""
        echo -e "${YELLOW}Possible causes:${NC}"
        echo -e "${YELLOW}   - RPC URL credentials not configured in 1Password${NC}"
        echo -e "${YELLOW}   - Network RPC endpoints are down or unreachable${NC}"
        echo -e "${YELLOW}   - Firewall or network connectivity issues${NC}"
        echo -e "${YELLOW}   - Invalid or expired RPC API keys${NC}"
        echo ""
        echo -e "${YELLOW}Recommended actions:${NC}"
        echo -e "${YELLOW}   1. Verify RPC URLs are configured in 1Password vault${NC}"
        echo -e "${YELLOW}   2. Test RPC connectivity manually: curl -X POST <RPC_URL> -H 'Content-Type: application/json' -d '{\"method\":\"eth_chainId\",\"params\":[],\"id\":1,\"jsonrpc\":\"2.0\"}'${NC}"
        echo -e "${YELLOW}   3. Check if the networks are supported in your environment${NC}"
        echo ""

        if [[ ${#SUCCESSFUL_NETWORKS[@]} -gt 0 ]]; then
            echo -e "${GREEN}Successfully checked networks:${NC}"
            for successful_network in "${SUCCESSFUL_NETWORKS[@]}"; do
                echo -e "${GREEN}   + $successful_network${NC}"
            done
            echo ""
        fi

        echo -e "${RED}DEPLOYMENT ABORTED: Cannot proceed without verifying current deployment status${NC}"
        echo -e "${RED}   Please resolve the network connectivity issues before attempting deployment.${NC}"
        exit 1
    fi

    echo -e "${GREEN}Successfully checked all networks for deployment status${NC}"

    print_separator

    # Analyze deployment status and determine next steps
    analyze_deployment_status
    local analysis_result=$?

    case $analysis_result in
        0)
            # All contracts deployed - exit successfully
            print_separator
            echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║                                                                                      ║${NC}"
            echo -e "${GREEN}║${WHITE}                All Contracts Already Deployed! No deployment necessary               ${GREEN}║${NC}"
            echo -e "${GREEN}║                                                                                      ║${NC}"
            echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
            exit 0
            ;;
        1)
            # Some contracts need deployment - ask for confirmation
            echo -e "${WHITE}Do you want to proceed with deploying the missing contracts? (y/n): ${NC}"
            read -r proceed

            if [ "$proceed" != "y" ] && [ "$proceed" != "Y" ]; then
                echo -e "${YELLOW}Deployment cancelled by user${NC}"
                exit 1
            fi
            echo -e "${GREEN}Proceeding with deployment of missing contracts...${NC}"
            ;;
        2)
            # Error in analysis
            echo -e "${RED}Error analyzing deployment status. Please check the output above.${NC}"
            exit 1
            ;;
    esac
}

# Deploy contracts to a single network.
# Uses globals: FORGE_ENV, ACCOUNT, KEYSTORE_PASSWORD_FLAG, ETHERSCANV2_API_KEY,
#               MODE, ENVIRONMENT, BROADCAST_FLAG, VERIFY_FLAG, SLOW_FLAG, etc.
deploy_to_network() {
    local forge_script=$1
    local network_id=$2
    local network_name=$3
    local rpc_var=$4

    # Skip unsupported chains
    if is_unsupported_chain "$network_id"; then
        echo -e "${YELLOW}Skipping ${network_name^^} MAINNET - Chain $network_id not supported by forge --chain${NC}"
        skipped_networks=$((skipped_networks + 1))
        return 0
    fi

    # Check deployment status for this network
    if [[ -n "${NETWORK_DEPLOYMENT_STATUS[$network_id]:-}" ]]; then
        IFS=':' read -r deployed total_expected network_status_name <<< "${NETWORK_DEPLOYMENT_STATUS[$network_id]}"

        # Skip if all contracts are already deployed
        if [[ $deployed -eq $total_expected ]]; then
            echo -e "${GREEN}Skipping ${network_name^^} MAINNET - All $deployed/$total_expected contracts already deployed${NC}"
            skipped_networks=$((skipped_networks + 1))
            return 0
        fi

        # Deploy to networks with missing contracts
        echo -e "${YELLOW}Deploying to ${network_name^^} MAINNET - $deployed/$total_expected contracts deployed ($((total_expected - deployed)) missing)${NC}"
    else
        echo -e "${YELLOW}Deploying to ${network_name^^} MAINNET - No previous deployment status found${NC}"
    fi

    print_network_header "${network_name^^} MAINNET"
    echo -e "${CYAN}   Chain ID: ${WHITE}$network_id${NC}"
    echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
    echo -e "${CYAN}   Environment: ${WHITE}$ENVIRONMENT${NC}"
    echo -e "${CYAN}   Account: ${WHITE}$ACCOUNT${NC}"

    # Skip inline verification for chains with aggressive block explorer rate limiting
    local chain_verify_flag="$VERIFY_FLAG"
    local chain_etherscan_flags="--etherscan-api-key $ETHERSCANV2_API_KEY --verifier etherscan"
    case $network_id in
        14|999) # Flare, HyperEVM - aggressive Cloudflare rate limiting
            chain_verify_flag=""
            chain_etherscan_flags=""
            echo -e "${CYAN}   Verification: ${WHITE}Skipped (rate-limited explorer, use verify script separately)${NC}"
            ;;
        *)
            echo -e "${CYAN}   Verification: ${WHITE}Etherscan V2${NC}"
            ;;
    esac
    # Pre-flight: nonce + balance checks (warnings only, don't block)
    preflight_network_checks "$network_id" "$network_name" "$rpc_var" || true

    echo -e "${YELLOW}   Executing forge script...${NC}"

    # Backup the existing output JSON before forge overwrites it
    local output_json="$PROJECT_ROOT/script/output/$ENVIRONMENT/$network_id/$network_name-latest.json"
    local backup_json="${output_json}.bak"
    if [[ -f "$output_json" ]]; then
        cp "$output_json" "$backup_json"
    fi

    # Retry logic: attempt deployment up to DEPLOY_MAX_RETRIES times for transient failures
    local max_retries=${DEPLOY_MAX_RETRIES:-1}
    local attempt=1
    local deploy_exit_code

    while [[ $attempt -le $max_retries ]]; do
        if [[ $attempt -gt 1 ]]; then
            echo -e "${YELLOW}   Retry attempt $attempt/$max_retries...${NC}"
            sleep 5  # brief pause before retry
        fi

        forge script "$forge_script" \
            --sig 'run(bool,uint256,uint64)' false $FORGE_ENV $network_id \
            --account "$ACCOUNT" \
            $KEYSTORE_PASSWORD_FLAG \
            --rpc-url "${!rpc_var}" \
            --chain $network_id \
            $chain_etherscan_flags \
            $BROADCAST_FLAG \
            $chain_verify_flag \
            $SLOW_FLAG \
            $BATCH_SIZE_FLAG \
            $RESUME_FLAG \
            $LEGACY_FLAG \
            $GAS_PRICE_FLAG \
            --timeout 300 \
            -vv
        deploy_exit_code=$?

        if [[ $deploy_exit_code -eq 0 ]]; then
            break
        fi

        attempt=$((attempt + 1))
    done

    if [[ $deploy_exit_code -ne 0 ]]; then
        echo -e "${RED}ERROR: Forge deployment FAILED for $network_name (Chain $network_id) with exit code $deploy_exit_code${NC}"
        echo -e "${RED}   The deployment script reverted or encountered an error.${NC}"
        echo -e "${YELLOW}   Common causes:${NC}"
        echo -e "${YELLOW}     - A require() check failed (missing dependency, zero address)${NC}"
        echo -e "${YELLOW}     - RPC connectivity issue during deployment${NC}"
        echo -e "${YELLOW}     - Insufficient gas or funds${NC}"
        echo -e "${YELLOW}     - Contract bytecode mismatch${NC}"
        echo -e "${RED}   Restoring previous output file and continuing with next network...${NC}"
        # Restore backup if forge failed (output file may be corrupted or missing)
        if [[ -f "$backup_json" ]]; then
            if ! cp "$backup_json" "$output_json"; then
                echo -e "${RED}   WARNING: Failed to restore backup file${NC}"
            fi
        fi
        rm -f "$backup_json"
        FAILED_DEPLOY_NETWORKS+=("$network_name (Chain $network_id)")
        return 1
    fi

    # Restore any entries that the forge script dropped (e.g., Nexus contracts)
    preserve_existing_json_entries "$output_json" "$backup_json"
    rm -f "$backup_json"

    echo -e "${GREEN}$network_name Mainnet deployment completed successfully!${NC}"
    deployed_networks=$((deployed_networks + 1))
}

# Run the deploy phase across all configured networks.
run_deploy_phase() {
    local forge_script=$1

    print_separator

    # Acquire deploy lock to prevent concurrent runs
    acquire_deploy_lock

    # Extract script base name for broadcast file checks (e.g., "DeployV2Core")
    local script_base
    script_base=$(echo "$forge_script" | sed 's|.*/||' | sed 's|:.*||' | sed 's|\.s\.sol||')
    check_stale_broadcasts "$script_base"

    # Reset deploy tracking
    deployed_networks=0
    skipped_networks=0
    FAILED_DEPLOY_NETWORKS=()

    for network_def in "${NETWORKS[@]}"; do
        IFS=':' read -r network_id network_name rpc_var <<< "$network_def"
        deploy_to_network "$forge_script" "$network_id" "$network_name" "$rpc_var" || true
    done
}

# ── Post-deployment verification ───────────────────────────────────────────────

# Verify that all contracts in output JSONs actually have code deployed on-chain.
# Uses `cast codesize` to check each address.
verify_deployments() {
    # Only verify in deploy mode — simulation doesn't broadcast
    if [[ "$MODE" != "deploy" ]]; then
        echo -e "${CYAN}Skipping on-chain verification (simulation mode)${NC}"
        return 0
    fi

    print_separator
    echo -e "${BLUE}Verifying on-chain deployment for all output JSONs...${NC}"
    local has_failures=false

    for network_def in "${NETWORKS[@]}"; do
        IFS=':' read -r network_id network_name rpc_var <<< "$network_def"
        local output_json="$PROJECT_ROOT/script/output/$ENVIRONMENT/$network_id/$network_name-latest.json"
        [[ ! -f "$output_json" ]] && continue

        # Check if RPC URL is available
        if [[ -z "${!rpc_var:-}" ]]; then
            echo -e "${YELLOW}SKIP: $network_name - RPC URL not available for verification${NC}"
            continue
        fi

        # Extract all contract_name:address pairs from JSON
        local contracts
        contracts=$(python3 -c "
import json, sys
with open('$output_json') as f:
    data = json.load(f)
for name, addr in sorted(data.items()):
    if addr.startswith('0x'):
        print(f'{name}:{addr}')
" 2>/dev/null) || true

        if [[ -z "$contracts" ]]; then
            echo -e "${YELLOW}SKIP: $network_name - no contract addresses found in output JSON${NC}"
            continue
        fi

        local chain_failures=()
        local chain_verified=0
        while IFS=: read -r name addr; do
            [[ -z "$name" || -z "$addr" ]] && continue
            # cast codesize returns a decimal number — faster than fetching full bytecode
            local code_size
            code_size=$(cast codesize "$addr" --rpc-url "${!rpc_var}" 2>/dev/null || echo "0")
            # Validate output is numeric (cast errors can return text)
            if ! [[ "$code_size" =~ ^[0-9]+$ ]]; then
                code_size="0"
            fi
            if [[ "$code_size" == "0" ]]; then
                chain_failures+=("$name ($addr)")
            else
                chain_verified=$((chain_verified + 1))
            fi
        done <<< "$contracts"

        if [[ ${#chain_failures[@]} -gt 0 ]]; then
            has_failures=true
            echo -e "${RED}FAIL: $network_name - ${#chain_failures[@]} contract(s) have no on-chain code:${NC}"
            for f in "${chain_failures[@]}"; do
                echo -e "${RED}  - $f${NC}"
            done
            echo -e "${GREEN}  ($chain_verified contract(s) verified OK)${NC}"
        else
            echo -e "${GREEN}OK: $network_name - all $chain_verified contracts verified on-chain${NC}"
        fi
    done

    echo ""
    if [[ "$has_failures" == "true" ]]; then
        echo -e "${YELLOW}WARNING: Some contracts in output JSON have no on-chain code.${NC}"
        echo -e "${YELLOW}These entries may be stale or from failed broadcasts.${NC}"
        return 1
    else
        echo -e "${GREEN}All deployed contracts verified on-chain${NC}"
    fi
}

# ── Summary ────────────────────────────────────────────────────────────────────

# Print the final deployment summary.
# $1: label (e.g., "V2 Core", "Other Hooks")
print_summary() {
    local label=${1:-"V2"}

    echo ""
    echo -e "${BLUE}Deployment Summary:${NC}"
    echo -e "${GREEN}   - Networks deployed: $deployed_networks${NC}"
    echo -e "${YELLOW}   - Networks skipped: $skipped_networks${NC}"
    if [[ ${#FAILED_DEPLOY_NETWORKS[@]} -gt 0 ]]; then
        echo -e "${RED}   - Networks FAILED: ${#FAILED_DEPLOY_NETWORKS[@]}${NC}"
        for failed in "${FAILED_DEPLOY_NETWORKS[@]}"; do
            echo -e "${RED}     - $failed${NC}"
        done
    fi

    print_separator

    if [[ ${#FAILED_DEPLOY_NETWORKS[@]} -gt 0 ]]; then
        echo -e "${RED}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║                                                                                      ║${NC}"
        echo -e "${RED}║${WHITE}          ${label} $ENVIRONMENT $MODE completed with ERRORS                              ${RED}║${NC}"
        echo -e "${RED}║${WHITE}          ${#FAILED_DEPLOY_NETWORKS[@]} network(s) failed deployment                                    ${RED}║${NC}"
        echo -e "${RED}║                                                                                      ║${NC}"
        echo -e "${RED}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
        print_separator
        exit 1
    else
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                                                                                      ║${NC}"
        echo -e "${GREEN}║${WHITE}                All ${label} $ENVIRONMENT $MODE Operations Completed!                     ${GREEN}║${NC}"
        echo -e "${GREEN}║                                                                                      ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
        print_separator
    fi
}
