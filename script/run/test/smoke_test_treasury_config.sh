#!/usr/bin/env bash

# Treasury Configuration Smoke Test Runner
# This script runs treasury configuration smoke tests across staging or production networks

set -e

# Source shared deployment library (colors, UI, paths)
source "$(dirname "${BASH_SOURCE[0]}")/../utils/lib_deploy.sh"

# Default values
ENVIRONMENT="prod"
FORGE_ENV=0
SPECIFIC_NETWORK=""
VERBOSE=false
DRY_RUN=false

# Usage function
usage() {
    echo "Usage: $0 <environment> [OPTIONS]"
    echo ""
    echo "Run treasury configuration smoke tests across staging or production networks"
    echo ""
    echo "ARGUMENTS:"
    echo "  environment            Required: 'staging' or 'prod'"
    echo ""
    echo "OPTIONS:"
    echo "  -n, --network CHAIN_ID  Test specific network only (optional)"
    echo "  -v, --verbose          Enable verbose output"
    echo "  -d, --dry-run          Show what would be tested without running"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0 prod                       # Test all production networks"
    echo "  $0 staging                    # Test all staging networks"
    echo "  $0 prod --network 1           # Test only Ethereum mainnet (prod)"
    echo "  $0 staging --verbose          # Test staging with verbose output"
    echo ""
    echo "SUPPORTED NETWORKS:"
    print_network_info
}

# Parse command line arguments
parse_smoke_args() {
    # First argument must be environment
    if [[ $# -lt 1 ]]; then
        echo -e "${RED}Missing required argument: environment${NC}"
        usage
        exit 1
    fi

    # Check for help flag first
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        usage
        exit 0
    fi

    # Parse environment
    ENVIRONMENT="$1"
    shift

    # Validate environment and source network config
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
            echo -e "${RED}Invalid environment: $ENVIRONMENT${NC}"
            echo "Environment must be 'staging' or 'prod'"
            exit 1
            ;;
    esac

    # Parse remaining options
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
                echo -e "${RED}Unknown option: $1${NC}"
                usage
                exit 1
                ;;
        esac
    done

    # Validate specific network if provided
    if [[ -n "$SPECIFIC_NETWORK" ]]; then
        if ! is_network_supported "$SPECIFIC_NETWORK"; then
            echo -e "${RED}Network $SPECIFIC_NETWORK is not supported in $ENVIRONMENT${NC}"
            echo "Supported networks:"
            get_supported_networks
            exit 1
        fi
    fi
}

# Log function with colors
log() {
    local level=$1
    shift
    local message="$*"

    case $level in
        "INFO")
            echo -e "${BLUE}$message${NC}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}$message${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}$message${NC}"
            ;;
        "ERROR")
            echo -e "${RED}$message${NC}"
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# Run smoke test for a specific network
run_network_test() {
    local network_id=$1
    local network_name=$(get_network_name "$network_id")
    local rpc_url=$(get_rpc_url "$network_id")

    log "INFO" "Testing $network_name (Chain ID: $network_id)"

    if [[ -z "$rpc_url" ]]; then
        log "ERROR" "No RPC URL configured for $network_name"
        return 1
    fi

    # Build forge command as an array (safer than eval on a string)
    local forge_cmd=(
        forge script script/SmokeTestTreasuryConfig.s.sol:SmokeTestTreasuryConfig
        --sig "run(uint256,uint64)" "$FORGE_ENV" "$network_id"
        --rpc-url "$rpc_url"
    )

    if [[ "$VERBOSE" == "true" ]]; then
        forge_cmd+=(-vv)
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "Would run: ${forge_cmd[*]}"
        return 0
    fi

    # Execute the test
    local start_time=$(date +%s)

    # Temporarily disable set -e to handle forge script exit codes properly
    set +e
    local output
    output=$("${forge_cmd[@]}" 2>&1)
    local forge_exit_code=$?
    set -e

    # Display the output
    echo "$output"

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [[ "$VERBOSE" == "true" ]]; then
        log "INFO" "Forge exit code: $forge_exit_code"
    fi

    # Check for explicit failure/success indicators in the output
    if echo "$output" | grep -q "TREASURY CONFIGURATION SMOKE TEST FAILED"; then
        log "ERROR" "$network_name treasury configuration test FAILED (${duration}s)"
        return 1
    elif echo "$output" | grep -q "TREASURY CONFIGURATION SMOKE TEST PASSED"; then
        log "SUCCESS" "$network_name treasury configuration test passed (${duration}s)"
        return 0
    elif [[ $forge_exit_code -eq 0 ]]; then
        log "SUCCESS" "$network_name treasury configuration test passed (${duration}s)"
        return 0
    else
        log "ERROR" "$network_name treasury configuration test failed with exit code $forge_exit_code (${duration}s)"
        return 1
    fi
}

# Main execution function
main() {
    parse_smoke_args "$@"

    cd "$PROJECT_ROOT"

    log "INFO" "Starting Treasury Configuration Smoke Tests"
    log "INFO" "Environment: $(echo "$ENVIRONMENT" | sed 's/prod/Production/;s/staging/Staging/')"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "WARNING" "DRY RUN MODE - No tests will be executed"
    fi

    echo ""

    # Load RPC URLs if not in dry run mode
    if [[ "$DRY_RUN" != "true" ]]; then
        if [[ "${CI:-}" == "true" ]]; then
            log "INFO" "Loading RPC URLs from environment variables (CI mode)..."
            if ! load_rpc_urls_ci; then
                log "ERROR" "Failed to load RPC URLs from environment. Some tests may fail."
            fi
        else
            log "INFO" "Loading RPC URLs from credential manager..."
            if ! load_rpc_urls; then
                log "ERROR" "Failed to load RPC URLs. Some tests may fail."
            fi
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
        log "INFO" "Testing all ${#networks_to_test[@]} $ENVIRONMENT networks"
    fi

    echo ""

    # Run tests
    local total_networks=${#networks_to_test[@]}
    local passed_tests=0
    local failed_tests=0
    local failed_networks=()

    for network_id in "${networks_to_test[@]}"; do
        print_separator
        if run_network_test "$network_id"; then
            passed_tests=$((passed_tests + 1))
        else
            failed_tests=$((failed_tests + 1))
            failed_networks+=("$(get_network_name "$network_id") (ID: $network_id)")
        fi
        echo ""
    done

    # Summary
    print_separator
    log "INFO" "Treasury Configuration Smoke Test Summary"
    print_separator
    echo -e "${CYAN}   Total Networks: ${WHITE}$total_networks${NC}"
    echo -e "${CYAN}   Passed:         ${GREEN}$passed_tests${NC}"

    if [[ $failed_tests -gt 0 ]]; then
        echo -e "${CYAN}   Failed:         ${RED}$failed_tests${NC}"
        echo ""
        echo -e "${RED}   Failed Networks:${NC}"
        for failed_network in "${failed_networks[@]}"; do
            echo -e "${RED}     - $failed_network${NC}"
        done
        echo ""
        log "ERROR" "Treasury configuration smoke tests completed with failures"
        exit 1
    else
        echo ""
        log "SUCCESS" "All treasury configuration smoke tests passed!"
        exit 0
    fi
}

# Execute main function with all arguments
main "$@"
