#!/usr/bin/env bash

# Deployment Smoke Test Runner
# Verifies all contracts listed in deployment JSON files are actually deployed on-chain
#
# Usage:
#   ./script/run/smoke_test_deployment.sh prod              # Test all production networks
#   ./script/run/smoke_test_deployment.sh staging            # Test all staging networks
#   ./script/run/smoke_test_deployment.sh prod -n 56         # Test only BSC (prod)
#   ./script/run/smoke_test_deployment.sh prod --verbose     # Verbose output

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Default values
ENVIRONMENT="prod"
FORGE_ENV=0
SPECIFIC_NETWORK=""
VERBOSE=false
DRY_RUN=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 <environment> [OPTIONS]"
    echo ""
    echo "Verify all deployed contracts have code on-chain"
    echo ""
    echo "ARGUMENTS:"
    echo "  environment            Required: 'staging' or 'prod'"
    echo ""
    echo "OPTIONS:"
    echo "  -n, --network CHAIN_ID  Test specific network only"
    echo "  -v, --verbose          Enable verbose output"
    echo "  -d, --dry-run          Show what would be tested without running"
    echo "  -h, --help             Show this help message"
}

parse_args() {
    if [[ $# -lt 1 ]]; then
        echo "Missing required argument: environment"
        usage
        exit 1
    fi

    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        usage
        exit 0
    fi

    ENVIRONMENT="$1"
    shift

    case "$ENVIRONMENT" in
        prod)
            FORGE_ENV=0
            source "$SCRIPT_DIR/networks-production.sh"
            ;;
        staging)
            FORGE_ENV=2
            source "$SCRIPT_DIR/networks-staging.sh"
            ;;
        *)
            echo "Invalid environment: $ENVIRONMENT (must be 'staging' or 'prod')"
            exit 1
            ;;
    esac

    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--network)
                SPECIFIC_NETWORK="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    if [[ -n "$SPECIFIC_NETWORK" ]]; then
        if ! is_network_supported "$SPECIFIC_NETWORK"; then
            echo "Network $SPECIFIC_NETWORK is not supported in $ENVIRONMENT"
            exit 1
        fi
    fi
}

log() {
    local level=$1
    shift
    local message="$*"
    case $level in
        "INFO")    echo -e "${BLUE}ℹ️  $message${NC}" ;;
        "SUCCESS") echo -e "${GREEN}✅ $message${NC}" ;;
        "WARNING") echo -e "${YELLOW}⚠️  $message${NC}" ;;
        "ERROR")   echo -e "${RED}❌ $message${NC}" ;;
        *)         echo "$message" ;;
    esac
}

run_network_test() {
    local network_id=$1
    local network_name=$(get_network_name "$network_id")
    local rpc_url=$(get_rpc_url "$network_id")

    log "INFO" "Testing $network_name (Chain ID: $network_id)"

    if [[ -z "$rpc_url" ]]; then
        log "ERROR" "No RPC URL configured for $network_name"
        return 1
    fi

    local forge_cmd="forge script script/SmokeTestDeployment.s.sol:SmokeTestDeployment"
    forge_cmd="$forge_cmd --sig \"run(uint256,uint64)\" $FORGE_ENV $network_id"
    forge_cmd="$forge_cmd --rpc-url \"$rpc_url\""

    if [[ "$VERBOSE" == "true" ]]; then
        forge_cmd="$forge_cmd -vv"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "Would run: $forge_cmd"
        return 0
    fi

    local start_time=$(date +%s)

    set +e
    local output
    output=$(eval "$forge_cmd" 2>&1)
    local forge_exit_code=$?
    set -e

    echo "$output"

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if echo "$output" | grep -q "DEPLOYMENT SMOKE TEST FAILED"; then
        log "ERROR" "$network_name deployment smoke test FAILED (${duration}s)"
        return 1
    elif echo "$output" | grep -q "DEPLOYMENT SMOKE TEST PASSED"; then
        log "SUCCESS" "$network_name deployment smoke test passed (${duration}s)"
        return 0
    elif [[ $forge_exit_code -eq 0 ]]; then
        log "SUCCESS" "$network_name deployment smoke test passed (${duration}s)"
        return 0
    else
        log "ERROR" "$network_name deployment smoke test failed with exit code $forge_exit_code (${duration}s)"
        return 1
    fi
}

main() {
    parse_args "$@"
    cd "$PROJECT_ROOT"

    log "INFO" "Starting Deployment Smoke Tests"
    log "INFO" "Environment: $(echo "$ENVIRONMENT" | sed 's/prod/Production/;s/staging/Staging/')"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "WARNING" "DRY RUN MODE - No tests will be executed"
    fi

    echo ""

    # Load RPC URLs
    if [[ "$DRY_RUN" != "true" ]]; then
        if [[ "${CI:-}" == "true" ]]; then
            log "INFO" "Loading RPC URLs from environment variables (CI mode)..."
            if type load_rpc_urls_ci &>/dev/null; then
                load_rpc_urls_ci || log "WARNING" "Some RPC URLs failed to load"
            else
                load_rpc_urls || log "WARNING" "Some RPC URLs failed to load"
            fi
        else
            log "INFO" "Loading RPC URLs from credential manager..."
            load_rpc_urls || log "WARNING" "Some RPC URLs failed to load"
        fi
        echo ""
    fi

    # Determine networks to test
    local networks_to_test=()
    if [[ -n "$SPECIFIC_NETWORK" ]]; then
        networks_to_test=("$SPECIFIC_NETWORK")
        log "INFO" "Testing specific network: $(get_network_name "$SPECIFIC_NETWORK")"
    else
        readarray -t networks_to_test < <(get_supported_networks)
        log "INFO" "Testing ${#networks_to_test[@]} networks"
    fi

    echo ""

    local total_networks=${#networks_to_test[@]}
    local passed_tests=0
    local failed_tests=0
    local failed_networks=()

    for network_id in "${networks_to_test[@]}"; do
        echo "----------------------------------------"
        if run_network_test "$network_id"; then
            passed_tests=$((passed_tests + 1))
        else
            failed_tests=$((failed_tests + 1))
            failed_networks+=("$(get_network_name "$network_id") (ID: $network_id)")
        fi
        echo ""
    done

    echo "========================================"
    log "INFO" "Deployment Smoke Test Summary"
    echo "========================================"
    log "INFO" "Total Networks: $total_networks"
    log "SUCCESS" "Passed: $passed_tests"

    if [[ $failed_tests -gt 0 ]]; then
        log "ERROR" "Failed: $failed_tests"
        echo ""
        log "ERROR" "Failed Networks:"
        for failed_network in "${failed_networks[@]}"; do
            echo "  • $failed_network"
        done
        echo ""
        log "ERROR" "Deployment smoke tests completed with failures"
        exit 1
    else
        echo ""
        log "SUCCESS" "All deployment smoke tests passed!"
        exit 0
    fi
}

main "$@"
