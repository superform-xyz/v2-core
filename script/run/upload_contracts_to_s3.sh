#!/usr/bin/env bash

# Colors for better visual output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Function to print colored header
print_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                                                      ║${NC}"
    echo -e "${CYAN}║${WHITE}                📤 V2 Core S3 Contract Replace & Upload Script 📤                 ${CYAN}║${NC}"
    echo -e "${CYAN}║                                                                                      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
}

# Function to print section separator
print_separator() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Logging function for consistent output
log() {
    local level=$1
    shift
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*" >&2
}



# Global variable to cache S3 content (fetched once)
S3_CACHED_CONTENT=""
S3_CACHE_LOADED=false

# Function to read latest file from S3 (uses cache after first call)
read_latest_from_s3() {
    local environment=$1

    # Return cached content if already loaded
    if [ "$S3_CACHE_LOADED" = true ]; then
        echo "$S3_CACHED_CONTENT"
        return
    fi

    local latest_file_path="/tmp/latest_s3.json"

    if aws s3 cp "s3://$S3_BUCKET_NAME/$environment/latest.json" "$latest_file_path" --quiet 2>/dev/null; then
        # Read the file and validate JSON
        local content=$(cat "$latest_file_path")

        # Check if content is empty or just whitespace
        if [ -z "$(echo "$content" | tr -d '[:space:]')" ]; then
            content="{\"networks\":{},\"updated_at\":null}"
        elif ! echo "$content" | jq '.' >/dev/null 2>&1; then
            content="{\"networks\":{},\"updated_at\":null}"
        fi
    else
        content="{\"networks\":{},\"updated_at\":null}"
    fi

    # Cache the content
    S3_CACHED_CONTENT="$content"
    S3_CACHE_LOADED=true

    echo "$content"
}

# Function to display current S3 state
show_current_s3_state() {
    local environment=$1
    local content=$(read_latest_from_s3 "$environment")

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                       📦 CURRENT S3 STATE 📦                                        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"

    local updated_at=$(echo "$content" | jq -r '.updated_at // "Never"')
    echo -e "${CYAN}Last Updated: ${WHITE}$updated_at${NC}"
    echo ""

    # Get all networks from S3
    local networks=$(echo "$content" | jq -r '.networks | keys[]' 2>/dev/null)

    if [ -z "$networks" ]; then
        echo -e "${YELLOW}   ⚠️  No contracts currently in S3 for $environment${NC}"
    else
        for network in $networks; do
            local contract_count=$(echo "$content" | jq -r ".networks[\"$network\"].contracts | length")
            local counter=$(echo "$content" | jq -r ".networks[\"$network\"].counter // 0")
            echo -e "${CYAN}   📍 $network: ${WHITE}$contract_count contracts${NC} (version: $counter)"
        done
    fi
    echo ""
}

# Function to get next counter for a network
get_next_counter() {
    local environment=$1
    local network_name=$2

    local content=$(read_latest_from_s3 "$environment")
    local existing_counter=$(echo "$content" | jq -r ".networks[\"$network_name\"].counter // empty")

    if [ -n "$existing_counter" ] && [ "$existing_counter" != "null" ]; then
        echo "$((existing_counter + 1))"
    else
        echo "0"
    fi
}

# Function to check if there are any changes for a network
# Only considers new contracts and updated contracts (not removals since we never remove)
has_contract_changes() {
    local existing_contracts=$1
    local new_contracts=$2

    # Validate JSON inputs
    if ! echo "$existing_contracts" | jq '.' >/dev/null 2>&1; then
        existing_contracts="{}"
    fi
    if ! echo "$new_contracts" | jq '.' >/dev/null 2>&1; then
        return 1
    fi

    # Check for new contracts (contracts that don't exist in S3)
    local new_contract_count=$(echo "$new_contracts" | jq --argjson existing "$existing_contracts" '
        [to_entries[] | select(.key as $k | $existing | has($k) | not)] | length
    ')

    # Check for updated contracts (contracts that exist but with different addresses)
    local updated_contract_count=$(echo "$new_contracts" | jq --argjson existing "$existing_contracts" '
        [to_entries[] | select(.key as $k | .value as $v | $existing | has($k) and (.[$k] != $v))] | length
    ')

    # Return true if there are any new or updated contracts
    local total_changes=$((new_contract_count + updated_contract_count))
    return $([[ $total_changes -gt 0 ]] && echo 0 || echo 1)
}

# Function to show contract differences for a network
show_contract_diff() {
    local network_name=$1
    local existing_contracts=$2
    local new_contracts=$3

    echo -e "${CYAN}╭─────────────────────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${WHITE}  📍 $network_name${NC}"
    echo -e "${CYAN}╰─────────────────────────────────────────────────────────────────────────────────────╯${NC}"

    # Validate JSON inputs
    if ! echo "$existing_contracts" | jq '.' >/dev/null 2>&1; then
        existing_contracts="{}"
    fi
    if ! echo "$new_contracts" | jq '.' >/dev/null 2>&1; then
        echo -e "  ${RED}Error: Invalid JSON for new contracts${NC}"
        return 1
    fi

    local existing_count=$(echo "$existing_contracts" | jq 'length')
    local new_count=$(echo "$new_contracts" | jq 'length')

    # Calculate merged count (existing + new contracts that don't exist yet)
    local new_only_count=$(echo "$new_contracts" | jq --argjson existing "$existing_contracts" '
        [to_entries[] | select(.key as $k | $existing | has($k) | not)] | length
    ')
    local merged_count=$((existing_count + new_only_count))

    echo -e "  ${CYAN}Current in S3: ${WHITE}$existing_count contracts${NC}"
    echo -e "  ${CYAN}After merge: ${WHITE}$merged_count contracts${NC}"
    echo ""

    # Show new contracts (contracts that don't exist in S3)
    local new_contract_names=$(echo "$new_contracts" | jq -r --argjson existing "$existing_contracts" '
        to_entries[] | select(.key as $k | $existing | has($k) | not) | .key
    ' 2>/dev/null | grep -v '^null$' | grep -v '^:' | sort)

    # Show updated contracts (contracts that exist but with different addresses)
    local updated_contract_names=$(echo "$new_contracts" | jq -r --argjson existing "$existing_contracts" '
        to_entries[] | select(.key as $k | .value as $v | $existing | has($k) and (.[$k] != $v)) | .key
    ' 2>/dev/null | grep -v '^null$' | grep -v '^:' | sort)

    # Show unchanged contracts count
    local unchanged_contract_names=$(echo "$new_contracts" | jq -r --argjson existing "$existing_contracts" '
        to_entries[] | select(.key as $k | .value as $v | $existing | has($k) and (.[$k] == $v)) | .key
    ' 2>/dev/null | grep -v '^null$' | grep -v '^:')
    local unchanged_count=$(echo "$unchanged_contract_names" | grep -c . 2>/dev/null || echo "0")

    # Count preserved contracts (in S3 but not in new deployment - will be kept)
    local preserved_count=$(echo "$existing_contracts" | jq --argjson new_contracts "$new_contracts" '
        [to_entries[] | select(.key as $k | $new_contracts | has($k) | not)] | length
    ')

    local changes_shown=false

    # Count and display new contracts
    if [ -n "$new_contract_names" ] && [ "$(echo "$new_contract_names" | tr -d '[:space:]')" != "" ]; then
        new_contract_names=$(echo "$new_contract_names" | tr -d '\r' | sed 's/null//g' | xargs)
        local add_count=$(echo "$new_contract_names" | wc -w | tr -d ' ')
        echo -e "  ${GREEN}➕ NEW ($add_count contracts):${NC}"
        for contract in $new_contract_names; do
            if [ -n "$contract" ]; then
                local addr=$(echo "$new_contracts" | jq -r ".[\"$contract\"]" 2>/dev/null || echo "unknown")
                echo -e "     ${GREEN}$contract${NC}"
                echo -e "       ${WHITE}$addr${NC}"
            fi
        done
        echo ""
        changes_shown=true
    fi

    # Count and display updated contracts
    if [ -n "$updated_contract_names" ] && [ "$(echo "$updated_contract_names" | tr -d '[:space:]')" != "" ]; then
        updated_contract_names=$(echo "$updated_contract_names" | tr -d '\r' | sed 's/null//g' | xargs)
        local upd_count=$(echo "$updated_contract_names" | wc -w | tr -d ' ')
        echo -e "  ${YELLOW}🔄 UPDATED ($upd_count contracts):${NC}"
        for contract in $updated_contract_names; do
            if [ -n "$contract" ]; then
                local old_addr=$(echo "$existing_contracts" | jq -r ".[\"$contract\"]" 2>/dev/null || echo "unknown")
                local new_addr=$(echo "$new_contracts" | jq -r ".[\"$contract\"]" 2>/dev/null || echo "unknown")
                echo -e "     ${YELLOW}$contract${NC}"
                echo -e "       ${RED}- $old_addr${NC}"
                echo -e "       ${GREEN}+ $new_addr${NC}"
            fi
        done
        echo ""
        changes_shown=true
    fi

    # Show unchanged count
    if [ "$unchanged_count" -gt 0 ]; then
        echo -e "  ${CYAN}═ UNCHANGED: $unchanged_count contracts${NC}"
    fi

    # Show preserved count (contracts in S3 not in this deployment - kept as-is)
    if [ "$preserved_count" -gt 0 ]; then
        echo -e "  ${PURPLE}📦 PRESERVED (from S3): $preserved_count contracts${NC}"
    fi

    if [ "$changes_shown" = false ] && [ "$unchanged_count" -eq 0 ]; then
        echo -e "  ${CYAN}No changes detected${NC}"
    fi
    echo ""
}

# Function to batch merge and upload all contract addresses to S3
batch_upload_to_s3() {
    local environment=$1
    shift
    local network_defs=("$@")
    
    # Read existing content from S3 (uses cached value)
    local content=$(read_latest_from_s3 "$environment")
    
    # Process each network and collect all data
    local updated_networks=()
    declare -a update_summary=()
    declare -a network_diffs=()
    local total_networks=0
    local successful_networks=0
    local total_changes=0
    
    for network_def in "${network_defs[@]}"; do
        total_networks=$((total_networks + 1))
        IFS=':' read -r network_id network_name rpc_var verifier_var <<< "$network_def"

        echo -e "${CYAN}📋 Processing $network_name (Chain ID: $network_id)...${NC}"

        # Get counter for this network
        local counter=$(get_next_counter "$environment" "$network_name")

        # Use environment name directly
        local env_folder="$environment"

        # Read deployed contracts from output file
        local contracts_file="$PROJECT_ROOT/script/output/$env_folder/$network_id/$network_name-latest.json"

        if [ ! -f "$contracts_file" ]; then
            echo -e "   ${RED}✗ Contract file not found${NC}"
            update_summary+=("❌ $network_name: Contract file not found")
            continue
        fi

        # Read and validate contracts file
        local contracts=$(tr -d '\r' < "$contracts_file")

        if ! contracts=$(echo "$contracts" | jq -c '.' 2>/dev/null); then
            echo -e "   ${RED}✗ Failed to parse JSON${NC}"
            update_summary+=("❌ $network_name: Failed to parse JSON")
            continue
        fi

        # Check if network already exists in S3
        local network_exists=$(echo "$content" | jq -r ".networks[\"$network_name\"] // empty")
        local existing_contracts="{}"
        local existing_counter=0
        local existing_vnet_id=""

        if [ -n "$network_exists" ] && [ "$network_exists" != "null" ] && [ "$network_exists" != "empty" ]; then
            # Network exists, preserve existing data
            existing_contracts=$(echo "$content" | jq -r ".networks[\"$network_name\"].contracts // {}")
            existing_counter=$(echo "$content" | jq -r ".networks[\"$network_name\"].counter // 0")
            existing_vnet_id=$(echo "$content" | jq -r ".networks[\"$network_name\"].vnet_id // \"\"")
        else
            # New network, use provided counter
            existing_counter=$counter
        fi

        # Check if there are any changes for this network
        if has_contract_changes "$existing_contracts" "$contracts"; then
            total_changes=$((total_changes + 1))
        else
            echo -e "   ${CYAN}⊘ No changes${NC}"
            continue
        fi

        # Merge: existing S3 contracts + new contracts (new contracts override existing ones)
        # This preserves ALL existing contracts and only adds/updates
        local merged_contracts=$(echo "$existing_contracts" | jq --argjson new_contracts "$contracts" '. + $new_contracts')

        # Count contracts
        local existing_contract_count=$(echo "$existing_contracts" | jq 'length')
        local new_contract_count=$(echo "$contracts" | jq 'length')
        local merged_contract_count=$(echo "$merged_contracts" | jq 'length')
        
        content=$(echo "$content" | jq \
            --arg network "$network_name" \
            --arg counter "$existing_counter" \
            --arg vnet_id "$existing_vnet_id" \
            --argjson contracts "$merged_contracts" \
            '.networks[$network] = {
                "counter": ($counter|tonumber),
                "vnet_id": $vnet_id,
                "contracts": $contracts
            }') || {
            echo -e "   ${RED}✗ Failed to merge${NC}"
            update_summary+=("❌ $network_name: Failed to update S3 content")
            continue
        }

        # Store diff information for display (write to temp files for complex JSON data)
        local diff_file="/tmp/diff_${network_name}_$$"
        echo "$existing_contracts" > "${diff_file}_existing.json"
        echo "$contracts" > "${diff_file}_new.json"
        network_diffs+=("$network_name:${diff_file}")

        updated_networks+=("$network_name")
        update_summary+=("✅ $network_name: $existing_contract_count → $merged_contract_count contracts")
        successful_networks=$((successful_networks + 1))
        echo -e "   ${GREEN}✓ Has changes ($existing_contract_count → $merged_contract_count contracts)${NC}"
    done
    
    # Update timestamp
    content=$(echo "$content" | jq --arg time "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '.updated_at = $time') || {
        echo -e "${RED}❌ Failed to update timestamp${NC}"
        return 1
    }
    
    # Display merge summary
    print_separator
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                          📋 BATCH MERGE SUMMARY 📋                                   ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${CYAN}Environment: ${WHITE}$environment${NC}"
    echo -e "${CYAN}Total Networks: ${WHITE}$total_networks${NC}"
    echo -e "${GREEN}Networks with Changes: ${WHITE}$total_changes${NC}"
    echo -e "${GREEN}Successful: ${WHITE}$successful_networks${NC}"
    echo -e "${RED}Failed: ${WHITE}$((total_networks - successful_networks))${NC}"
    echo ""
    
    for summary_line in "${update_summary[@]}"; do
        echo -e "  $summary_line"
    done
    echo ""
    
    if [ $successful_networks -eq 0 ]; then
        echo -e "${RED}❌ No successful merges to upload${NC}"
        return 1
    fi
    
    # Check if there are actually any changes to upload
    if [ $total_changes -eq 0 ]; then
        print_separator
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║                                                                                      ║${NC}"
        echo -e "${CYAN}║${WHITE}                  ✅ No Changes Detected - Nothing to Upload ✅                    ${CYAN}║${NC}"
        echo -e "${CYAN}║                                                                                      ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo -e "${CYAN}🔍 All contracts are already up to date in S3${NC}"
        echo -e "${CYAN}📊 Networks checked: $total_networks${NC}"
        echo -e "${CYAN}💡 No upload needed - terminating script${NC}"
        print_separator
        return 0
    fi
    
    # Display contract differences for confirmation
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}📋 Contract Changes that will be merged to S3:${NC}"
    echo -e "${CYAN}💡 Note: Merge only - existing S3 contracts are preserved, new contracts added, existing ones updated${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Show diffs for each network
    for diff_data in "${network_diffs[@]}"; do
        IFS=':' read -r network_name diff_file <<< "$diff_data"
        
        local existing_contracts_data=$(cat "${diff_file}_existing.json")
        local new_contracts_data=$(cat "${diff_file}_new.json")
        
        show_contract_diff "$network_name" "$existing_contracts_data" "$new_contracts_data"
        
        # Clean up temp files
        rm -f "${diff_file}_existing.json" "${diff_file}_new.json"
    done
    
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Ask for user confirmation ONCE for all networks
    local network_count=${#updated_networks[@]}
    printf "${WHITE}🚀 Do you want to merge and upload changes for ${network_count} networks to S3? (y/n): ${NC}"
    read -r confirmation
    echo ""
    
    if [ "$confirmation" != "y" ] && [ "$confirmation" != "Y" ]; then
        echo -e "${YELLOW}⚠️  Upload cancelled by user${NC}"
        return 1
    fi
    
    # Upload to S3
    local latest_file_path="/tmp/latest_upload.json"
    echo "$content" | jq '.' > "$latest_file_path"

    echo -e "${CYAN}📤 Uploading to S3...${NC}"
    if aws s3 cp "$latest_file_path" "s3://$S3_BUCKET_NAME/$environment/latest.json" --quiet; then
        echo -e "${GREEN}✅ Successfully uploaded to S3${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to upload to S3${NC}"
        return 1
    fi
}

# Cleanup function for temporary files
cleanup_temp_files() {
    if [ -n "$(ls /tmp/diff_*_$$_*.json 2>/dev/null)" ] || [ -n "$(ls /tmp/latest_*.json 2>/dev/null)" ]; then
        echo "" # New line after potential Ctrl+C
        echo "Cleaning up temporary files..."
        rm -f /tmp/diff_*_$$_*.json 2>/dev/null
        rm -f /tmp/latest_*.json 2>/dev/null
        rm -f /tmp/nexus_*.json 2>/dev/null
    fi
}

# Set up trap for cleanup on script exit or interruption
trap 'cleanup_temp_files; exit 130' INT
trap 'cleanup_temp_files' EXIT TERM

print_header

# Source centralized network configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Determine which networks file to use based on environment (passed as first argument)
ENV_ARG="${1:-staging}"
if [[ "$ENV_ARG" == "staging" ]]; then
    NETWORKS_FILE="$SCRIPT_DIR/networks-staging.sh"
else
    echo -e "${RED}❌ Error: Invalid environment '$ENV_ARG'${NC}"
    echo -e "${YELLOW}Expected 'staging'${NC}"
    exit 1
fi

# Check if networks file exists and source it
if [[ ! -f "$NETWORKS_FILE" ]]; then
    echo -e "${RED}❌ Error: Networks file not found: $NETWORKS_FILE${NC}"
    exit 1
fi

source "$NETWORKS_FILE"

# Check if arguments are provided
if [ $# -lt 1 ]; then
    echo -e "${RED}❌ Error: Missing required argument${NC}"
    echo -e "${YELLOW}Usage: $0 <environment>${NC}"
    echo -e "${CYAN}  environment: staging${NC}"
    echo -e "${CYAN}Examples:${NC}"
    echo -e "${CYAN}  $0 staging${NC}"
    exit 1
fi

ENVIRONMENT=$1

# Validate environment
if [ "$ENVIRONMENT" != "staging" ]; then
    echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
    echo -e "${YELLOW}Environment must be 'staging'${NC}"
    exit 1
fi

print_separator
echo -e "${BLUE}🔧 Loading Configuration...${NC}"

# S3 configuration
echo -e "${CYAN}   • Loading S3 configuration...${NC}"
export S3_BUCKET_NAME="superform-deployment-state"

echo -e "${GREEN}✅ Configuration loaded successfully${NC}"
echo -e "${CYAN}   • Environment: $ENVIRONMENT${NC}"
echo -e "${CYAN}   • S3 Bucket: $S3_BUCKET_NAME${NC}"
print_separator

# Show current S3 state first
show_current_s3_state "$ENVIRONMENT"
print_separator

# Use environment name directly
env_folder="$ENVIRONMENT"

echo -e "${BLUE}🔍 Scanning for deployed contracts in output/$env_folder/...${NC}"

FOUND_DEPLOYMENTS=()

# Check which networks have deployments
for network_def in "${NETWORKS[@]}"; do
    IFS=':' read -r network_id network_name rpc_var verifier_var <<< "$network_def"
    
    contracts_file="$PROJECT_ROOT/script/output/$env_folder/$network_id/$network_name-latest.json"
    
    if [ -f "$contracts_file" ]; then
        echo -e "${GREEN}   ✅ Found deployment: $network_name (Chain ID: $network_id)${NC}"
        FOUND_DEPLOYMENTS+=("$network_def")
    else
        echo -e "${YELLOW}   ⚠️  No deployment found: $network_name (Chain ID: $network_id) - $contracts_file${NC}"
    fi
done

if [ ${#FOUND_DEPLOYMENTS[@]} -eq 0 ]; then
    echo -e "${RED}❌ No contract deployments found in output/$env_folder/ directory${NC}"
    echo -e "${YELLOW}Please ensure contracts have been deployed before running this script.${NC}"
    exit 1
fi

print_separator

echo -e "${PURPLE}📤 Processing batch merge and upload of all contracts to S3...${NC}"

TOTAL_COUNT=${#FOUND_DEPLOYMENTS[@]}

echo -e "${PURPLE}╭─────────────────────────────────────────────────────────────────────────────────────╮${NC}"
echo -e "${PURPLE}│${WHITE}                     📤 Batch Merging All Network Contracts 📤                     ${PURPLE}│${NC}"
echo -e "${PURPLE}╰─────────────────────────────────────────────────────────────────────────────────────╯${NC}"

echo -e "${CYAN}   Environment: ${WHITE}$ENVIRONMENT${NC}"
echo -e "${CYAN}   Total Networks: ${WHITE}$TOTAL_COUNT${NC}"
echo -e "${CYAN}   Networks: ${WHITE}$(for net in "${FOUND_DEPLOYMENTS[@]}"; do IFS=':' read -r id name _ _ <<< "$net"; echo -n "$name "; done)${NC}"
echo ""

if batch_upload_to_s3 "$ENVIRONMENT" "${FOUND_DEPLOYMENTS[@]}"; then
    print_separator
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                                      ║${NC}"
    echo -e "${GREEN}║${WHITE}              🎉 All Contract Merges Completed Successfully! 🎉                     ${GREEN}║${NC}"
    echo -e "${GREEN}║                                                                                      ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${CYAN}🔗 Contract addresses merged and uploaded to S3 bucket: $S3_BUCKET_NAME/$ENVIRONMENT/latest.json${NC}"
    echo -e "${CYAN}📊 Successfully merged: $TOTAL_COUNT networks with changes${NC}"
else
    print_separator
    echo -e "${RED}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                                                                                      ║${NC}"
    echo -e "${RED}║${WHITE}                        ❌ Batch Merge Failed ❌                                    ${RED}║${NC}"
    echo -e "${RED}║                                                                                      ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${RED}❌ Failed to upload contracts to S3${NC}"
    exit 1
fi

print_separator