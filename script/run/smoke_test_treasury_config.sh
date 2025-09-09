#!/opt/homebrew/bin/bash

# Treasury Configuration Smoke Test Runner
# This script runs treasury configuration smoke tests across all production networks

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the production networks configuration
source "$SCRIPT_DIR/networks-production.sh"

# Default values - Production only
SPECIFIC_NETWORK=""
VERBOSE=false
DRY_RUN=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Run treasury configuration smoke tests across production networks"
    echo ""
    echo "OPTIONS:"
    echo "  -n, --network CHAIN_ID  Test specific network only (optional)"
    echo "  -v, --verbose          Enable verbose output"
    echo "  -d, --dry-run          Show what would be tested without running"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0                            # Test all production networks"
    echo "  $0 --network 1                # Test only Ethereum mainnet"
    echo "  $0 --verbose                  # Test with verbose output"
    echo ""
    echo "SUPPORTED NETWORKS:"
    print_network_info
}

# Parse command line arguments
parse_args() {
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
                echo "❌ Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Validate specific network if provided
    if [[ -n "$SPECIFIC_NETWORK" ]]; then
        if ! is_network_supported "$SPECIFIC_NETWORK"; then
            echo "❌ Network $SPECIFIC_NETWORK is not supported in production"
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
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "ERROR")
            echo -e "${RED}❌ $message${NC}"
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
    
    # Build forge command
    local forge_cmd="forge script script/SmokeTestTreasuryConfig.s.sol:SmokeTestTreasuryConfig"
    
    # Add function signature for production
    forge_cmd="$forge_cmd --sig \"run(uint64)\" $network_id"
    
    # Add RPC URL
    forge_cmd="$forge_cmd --rpc-url \"$rpc_url\""
    
    # Add verbose flag if requested
    if [[ "$VERBOSE" == "true" ]]; then
        forge_cmd="$forge_cmd -vv"
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "Would run: $forge_cmd"
        return 0
    fi
    
    # Execute the test
    local start_time=$(date +%s)
    
    # Temporarily disable set -e for this command to handle forge script exit codes properly
    set +e
    local output
    output=$(eval "$forge_cmd" 2>&1)
    local forge_exit_code=$?
    set -e
    
    # Display the output
    echo "$output"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Debug: Log the actual exit code
    if [[ "$VERBOSE" == "true" ]]; then
        log "INFO" "Forge command exit code: $forge_exit_code"
    fi
    
    # Check for explicit failure indicators in the output
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
        # If we can't determine success/failure from output, treat as failure
        log "ERROR" "$network_name treasury configuration test failed with exit code $forge_exit_code (${duration}s)"
        return 1
    fi
}

# Main execution function
main() {
    parse_args "$@"
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    log "INFO" "Starting Treasury Configuration Smoke Tests"
    log "INFO" "Environment: Production"
    
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
    log "INFO" "DEBUG: About to determine networks to test"
    if [[ -n "$SPECIFIC_NETWORK" ]]; then
        networks_to_test=("$SPECIFIC_NETWORK")
        log "INFO" "Testing specific network: $(get_network_name "$SPECIFIC_NETWORK")"
        log "INFO" "DEBUG: networks_to_test array has ${#networks_to_test[@]} elements: ${networks_to_test[*]}"
    else
        log "INFO" "DEBUG: Getting all supported networks"
        readarray -t networks_to_test < <(get_supported_networks)
        log "INFO" "Testing all $(echo "${networks_to_test[@]}" | wc -w) production networks"
        log "INFO" "DEBUG: networks_to_test array has ${#networks_to_test[@]} elements: ${networks_to_test[*]}"
    fi
    
    echo ""
    
    # Run tests
    local total_networks=${#networks_to_test[@]}
    local passed_tests=0
    local failed_tests=0
    local failed_networks=()
    
    for network_id in "${networks_to_test[@]}"; do
        echo "----------------------------------------"
        log "INFO" "About to test network $network_id ($(get_network_name "$network_id"))"
        if run_network_test "$network_id"; then
            passed_tests=$((passed_tests + 1))
            log "INFO" "Network $network_id test completed successfully, continuing to next network"
        else
            failed_tests=$((failed_tests + 1))
            failed_networks+=("$(get_network_name "$network_id") (ID: $network_id)")
            log "WARNING" "Network $network_id test failed, continuing to next network"
        fi
        echo ""
        log "INFO" "Completed network $network_id, moving to next network"
    done
    
    # Summary
    echo "========================================"
    log "INFO" "Treasury Configuration Smoke Test Summary"
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
