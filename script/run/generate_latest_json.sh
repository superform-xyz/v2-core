#!/bin/bash

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
    echo -e "${CYAN}║${WHITE}                📄 V2 Core Local Latest.json Generator 📄                       ${CYAN}║${NC}"
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

# Function to get next counter for a network
get_next_counter() {
    local environment=$1
    local network_name=$2
    local latest_file="$PROJECT_ROOT/script/output/$environment/latest.json"
    
    log "INFO" "Getting next counter for $network_name in $environment"
    
    if [ -f "$latest_file" ]; then
        local existing_counter=$(cat "$latest_file" | jq -r ".networks[\"$network_name\"].counter // empty")
        
        if [ -n "$existing_counter" ] && [ "$existing_counter" != "null" ]; then
            local new_counter=$((existing_counter + 1))
            log "INFO" "Found existing counter: $existing_counter, new counter: $new_counter for $network_name"
            echo "$new_counter"
        else
            # Generate new counter starting from 0
            local new_counter=0
            log "INFO" "No existing counter found for $network_name, using new counter: $new_counter"
            echo "$new_counter"
        fi
    else
        # No existing file, start from 0
        local new_counter=0
        log "INFO" "No existing latest.json found, using new counter: $new_counter"
        echo "$new_counter"
    fi
}

# Function to check if there are any changes for a network
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
    
    # Check for new contracts (contracts that don't exist in existing)
    local new_contract_count=$(echo "$new_contracts" | jq --argjson existing "$existing_contracts" '
        [to_entries[] | select(.key as $k | $existing | has($k) | not)] | length
    ')
    
    # Check for updated contracts (contracts that exist but with different addresses)
    local updated_contract_count=$(echo "$new_contracts" | jq --argjson existing "$existing_contracts" '
        [to_entries[] | select(.key as $k | .value as $v | $existing | has($k) and (.[$k] != $v))] | length
    ')
    
    # Check for removed contracts (contracts that exist in existing but not in new deployment)
    # Exclude Nexus contracts from being considered removable
    local removed_contract_count=$(echo "$existing_contracts" | jq --argjson new_contracts "$new_contracts" '
        [to_entries[] | select(.key as $k | $new_contracts | has($k) | not and ($k != "Nexus" and $k != "NexusBootstrap" and $k != "NexusAccountFactory"))] | length
    ')
    
    # Return true if there are any new, updated, or removed contracts
    local total_changes=$((new_contract_count + updated_contract_count + removed_contract_count))
    return $([[ $total_changes -gt 0 ]] && echo 0 || echo 1)
}

# Function to show contract differences for a network
show_contract_diff() {
    local network_name=$1
    local existing_contracts=$2
    local new_contracts=$3
    
    echo -e "${CYAN}📍 $network_name Changes:${NC}"
    
    # Validate JSON inputs
    if ! echo "$existing_contracts" | jq '.' >/dev/null 2>&1; then
        existing_contracts="{}"
    fi
    if ! echo "$new_contracts" | jq '.' >/dev/null 2>&1; then
        echo -e "  ${RED}Error: Invalid JSON for new contracts${NC}"
        return 1
    fi
    
    # Show new contracts (contracts that don't exist in existing)
    local new_contract_names=$(echo "$new_contracts" | jq -r --argjson existing "$existing_contracts" '
        to_entries[] | select(.key as $k | $existing | has($k) | not) | .key
    ' | tr '\n' ' ')
    
    # Show updated contracts (contracts that exist but with different addresses)
    local updated_contract_names=$(echo "$new_contracts" | jq -r --argjson existing "$existing_contracts" '
        to_entries[] | select(.key as $k | .value as $v | $existing | has($k) and (.[$k] != $v)) | .key
    ' | tr '\n' ' ')
    
    # Show removed contracts (contracts that exist in existing but not in new deployment)
    # Exclude Nexus contracts from being shown as removed
    local removed_contract_names=$(echo "$existing_contracts" | jq -r --argjson new_contracts "$new_contracts" '
        to_entries[] | select(.key as $k | $new_contracts | has($k) | not and ($k != "Nexus" and $k != "NexusBootstrap" and $k != "NexusAccountFactory")) | .key
    ' | tr '\n' ' ')
    
    local changes_shown=false
    
    if [ -n "$new_contract_names" ] && [ "${new_contract_names// /}" != "" ]; then
        local new_count=$(echo "$new_contract_names" | wc -w | tr -d ' ')
        echo -e "  ${GREEN}+ ${new_count} new contracts${NC}"
        for contract in $new_contract_names; do
            if [ -n "$contract" ]; then
                local addr=$(echo "$new_contracts" | jq -r ".$contract")
                echo -e "    ${GREEN}+ $contract: $addr${NC}"
            fi
        done
        changes_shown=true
    fi
    
    if [ -n "$updated_contract_names" ] && [ "${updated_contract_names// /}" != "" ]; then
        local updated_count=$(echo "$updated_contract_names" | wc -w | tr -d ' ')
        echo -e "  ${YELLOW}~ ${updated_count} updated contracts${NC}"
        for contract in $updated_contract_names; do
            if [ -n "$contract" ]; then
                local old_addr=$(echo "$existing_contracts" | jq -r ".$contract")
                local new_addr=$(echo "$new_contracts" | jq -r ".$contract")
                echo -e "    ${YELLOW}~ $contract: $old_addr → $new_addr${NC}"
            fi
        done
        changes_shown=true
    fi
    
    if [ -n "$removed_contract_names" ] && [ "${removed_contract_names// /}" != "" ]; then
        local removed_count=$(echo "$removed_contract_names" | wc -w | tr -d ' ')
        echo -e "  ${RED}- ${removed_count} removed contracts${NC}"
        for contract in $removed_contract_names; do
            if [ -n "$contract" ]; then
                local old_addr=$(echo "$existing_contracts" | jq -r ".$contract")
                echo -e "    ${RED}- $contract: $old_addr${NC}"
            fi
        done
        changes_shown=true
    fi
    
    if [ "$changes_shown" = false ]; then
        echo -e "  ${CYAN}No changes (all contracts already up to date)${NC}"
    fi
    
    echo ""
}

# Function to check for networks in latest.json that are not in production config
check_and_prompt_for_network_deletion() {
    local environment=$1
    local latest_file="$PROJECT_ROOT/script/output/$environment/latest.json"
    
    if [ ! -f "$latest_file" ]; then
        log "INFO" "No existing latest.json found at $latest_file"
        return 0
    fi
    
    log "INFO" "Checking for networks in latest.json that are not in production config"
    
    # Get networks from latest.json
    local existing_networks=$(cat "$latest_file" | jq -r '.networks | keys[]' 2>/dev/null)
    
    if [ -z "$existing_networks" ]; then
        log "INFO" "No networks found in existing latest.json"
        return 0
    fi
    
    # Get network names from NETWORKS array
    local production_networks=()
    for network_def in "${NETWORKS[@]}"; do
        IFS=':' read -r network_id network_name rpc_var verifier_var <<< "$network_def"
        production_networks+=("$network_name")
    done
    
    # Find networks in latest.json that are NOT in production config
    local networks_to_delete=()
    while IFS= read -r existing_network; do
        if [ -n "$existing_network" ]; then
            local found=false
            for prod_network in "${production_networks[@]}"; do
                if [ "$existing_network" = "$prod_network" ]; then
                    found=true
                    break
                fi
            done
            if [ "$found" = false ]; then
                networks_to_delete+=("$existing_network")
            fi
        fi
    done <<< "$existing_networks"
    
    # If there are networks to potentially delete, prompt user
    if [ ${#networks_to_delete[@]} -gt 0 ]; then
        print_separator
        echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║${WHITE}                    ⚠️  NETWORK CLEANUP REQUIRED ⚠️                                ${YELLOW}║${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo -e "${YELLOW}Found ${#networks_to_delete[@]} network(s) in latest.json that are NOT in the production networks config:${NC}"
        echo ""
        
        for network in "${networks_to_delete[@]}"; do
            echo -e "  ${RED}• $network${NC}"
        done
        
        echo ""
        echo -e "${CYAN}Production networks configured in networks-production.sh:${NC}"
        for prod_network in "${production_networks[@]}"; do
            echo -e "  ${GREEN}• $prod_network${NC}"
        done
        
        echo ""
        echo -e "${YELLOW}Would you like to remove the networks not in production config from latest.json?${NC}"
        echo -e "${YELLOW}This will permanently delete their contract deployment data.${NC}"
        echo ""
        
        read -p "Remove networks not in production? [y/N]: " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "INFO" "User confirmed removal of networks not in production"
            
            # Remove networks from latest.json
            local content=$(cat "$latest_file")
            for network in "${networks_to_delete[@]}"; do
                log "INFO" "Removing network '$network' from latest.json"
                content=$(echo "$content" | jq --arg network "$network" 'del(.networks[$network])')
                echo -e "  ${RED}✗ Removed: $network${NC}"
            done
            
            # Update timestamp
            content=$(echo "$content" | jq --arg time "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '.updated_at = $time')
            
            # Save updated content
            echo "$content" | jq '.' > "$latest_file"
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✅ Successfully removed ${#networks_to_delete[@]} network(s) from latest.json${NC}"
                log "SUCCESS" "Networks removed from latest.json: ${networks_to_delete[*]}"
            else
                echo -e "${RED}❌ Failed to update latest.json after network removal${NC}"
                log "ERROR" "Failed to update latest.json after network removal"
                return 1
            fi
        else
            echo -e "${CYAN}ℹ️  Keeping all networks in latest.json (no changes made)${NC}"
            log "INFO" "User chose not to remove networks - keeping all networks"
        fi
        print_separator
    else
        log "INFO" "All networks in latest.json are present in production config - no cleanup needed"
    fi
    
    return 0
}

# Function to batch merge and generate latest.json locally
batch_generate_latest_json() {
    local environment=$1
    shift
    local network_defs=("$@")
    
    log "INFO" "Starting batch generation for all networks"
    
    # Read existing content from local file if it exists
    local latest_file="$PROJECT_ROOT/script/output/$environment/latest.json"
    local content="{\"networks\":{},\"updated_at\":null}"
    
    if [ -f "$latest_file" ]; then
        local existing_content=$(cat "$latest_file")
        if [ -n "$(echo "$existing_content" | tr -d '[:space:]')" ] && echo "$existing_content" | jq '.' >/dev/null 2>&1; then
            content="$existing_content"
            log "INFO" "Successfully loaded existing latest.json"
        else
            log "WARN" "Existing latest.json is invalid or empty, starting fresh"
        fi
    else
        log "INFO" "No existing latest.json found, creating new one"
    fi
    
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
        
        # Read deployed contracts from output file
        local contracts_file="$PROJECT_ROOT/script/output/$environment/$network_id/$network_name-latest.json"
        
        if [ ! -f "$contracts_file" ]; then
            log "ERROR" "Contract file not found: $contracts_file"
            update_summary+=("❌ $network_name: Contract file not found")
            continue
        fi
        
        log "INFO" "Reading contracts from: $contracts_file"
        
        # Read and validate contracts file
        local contracts=$(tr -d '\r' < "$contracts_file")
        
        if ! contracts=$(echo "$contracts" | jq -c '.' 2>/dev/null); then
            log "ERROR" "Failed to parse JSON from contract file for $network_name"
            update_summary+=("❌ $network_name: Failed to parse JSON")
            continue
        fi
        
        log "INFO" "Successfully parsed contracts JSON for $network_name"
        
        # Preserve existing contracts and merge with new ones
        log "DEBUG" "Merging contracts for network: $network_name, counter: $counter"
        
        # Check if network already exists in local file
        local network_exists=$(echo "$content" | jq -r ".networks[\"$network_name\"] // empty")
        local existing_contracts="{}"
        local existing_counter=0
        local existing_vnet_id=""
        
        if [ -n "$network_exists" ] && [ "$network_exists" != "null" ] && [ "$network_exists" != "empty" ]; then
            # Network exists, preserve existing data
            existing_contracts=$(echo "$content" | jq -r ".networks[\"$network_name\"].contracts // {}")
            existing_counter=$(echo "$content" | jq -r ".networks[\"$network_name\"].counter // 0")
            existing_vnet_id=$(echo "$content" | jq -r ".networks[\"$network_name\"].vnet_id // \"\"")
            log "INFO" "Found existing network $network_name, preserving existing contracts and data"
        else
            # New network, use provided counter
            existing_counter=$counter
            log "INFO" "Creating new network entry for $network_name"
        fi
        
        # Check if there are any changes for this network
        if has_contract_changes "$existing_contracts" "$contracts"; then
            log "INFO" "Changes detected for $network_name"
            total_changes=$((total_changes + 1))
        else
            log "INFO" "No changes detected for $network_name - skipping"
            echo -e "${CYAN}   📋 $network_name: No changes detected, skipping${NC}"
            continue
        fi
        
        # Replace existing contracts with new contracts, but preserve Nexus contracts
        local nexus_contracts=$(echo "$existing_contracts" | jq '{
            Nexus: .Nexus,
            NexusBootstrap: .NexusBootstrap,
            NexusAccountFactory: .NexusAccountFactory
        } | with_entries(select(.value != null))')
        
        local nexus_count=$(echo "$nexus_contracts" | jq 'length')
        if [ "$nexus_count" -gt 0 ]; then
            log "INFO" "Preserving $nexus_count Nexus contracts for $network_name"
        fi
        
        local merged_contracts=$(echo "$contracts" | jq --argjson nexus "$nexus_contracts" '. + $nexus')
        
        # Count contracts that will be added/updated
        local existing_contract_count=$(echo "$existing_contracts" | jq 'length')
        local new_contract_count=$(echo "$contracts" | jq 'length')
        local merged_contract_count=$(echo "$merged_contracts" | jq 'length')
        
        log "INFO" "Contract replacement summary for $network_name: $existing_contract_count existing → $merged_contract_count new (full replacement)"
        
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
            log "ERROR" "Failed to update content with deployment info for $network_name"
            update_summary+=("❌ $network_name: Failed to update content")
            continue
        }
        
        # Store diff information for display (write to temp files for complex JSON data)
        local diff_file="/tmp/diff_${network_name}_$$"
        echo "$existing_contracts" > "${diff_file}_existing.json"
        echo "$contracts" > "${diff_file}_new.json"
        network_diffs+=("$network_name:${diff_file}")
        
        updated_networks+=("$network_name")
        update_summary+=("✅ $network_name: ${new_contract_count} contracts added/updated")
        successful_networks=$((successful_networks + 1))
        echo -e "${GREEN}   ✅ $network_name contracts replaced successfully (${merged_contract_count} total contracts)${NC}"
    done
    
    # Update timestamp
    content=$(echo "$content" | jq --arg time "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '.updated_at = $time') || {
        log "ERROR" "Failed to update timestamp"
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
        echo -e "${RED}❌ No successful merges to generate${NC}"
        return 1
    fi
    
    # Check if there are actually any changes to generate
    if [ $total_changes -eq 0 ]; then
        print_separator
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║                                                                                      ║${NC}"
        echo -e "${CYAN}║${WHITE}                  ✅ No Changes Detected - Nothing to Generate ✅                  ${CYAN}║${NC}"
        echo -e "${CYAN}║                                                                                      ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo -e "${CYAN}🔍 All contracts are already up to date in latest.json${NC}"
        echo -e "${CYAN}📊 Networks checked: $total_networks${NC}"
        echo -e "${CYAN}💡 No generation needed - terminating script${NC}"
        print_separator
        return 0
    fi
    
    # Display contract differences for confirmation
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}📋 Contract Changes that will be saved to latest.json:${NC}"
    echo -e "${CYAN}💡 Note: Full replacement - removed contracts will be deleted (except Nexus contracts)${NC}"
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
    
    # Save to local file
    echo "$content" | jq '.' > "$latest_file"
    
    if [ $? -eq 0 ]; then
        log "SUCCESS" "Successfully generated latest.json locally at: $latest_file"
        return 0
    else
        log "ERROR" "Failed to write latest.json to local file"
        return 1
    fi
}

# Cleanup function for temporary files
cleanup_temp_files() {
    if [ -n "$(ls /tmp/diff_*_$$_*.json 2>/dev/null)" ]; then
        echo "" # New line after potential Ctrl+C
        echo "Cleaning up temporary files..."
        rm -f /tmp/diff_*_$$_*.json 2>/dev/null
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
if [[ "$ENV_ARG" == "prod" ]]; then
    NETWORKS_FILE="$SCRIPT_DIR/networks-production.sh"
elif [[ "$ENV_ARG" == "staging" ]]; then
    NETWORKS_FILE="$SCRIPT_DIR/networks-staging.sh"
else
    echo -e "${RED}❌ Error: Invalid environment '$ENV_ARG'${NC}"
    echo -e "${YELLOW}Expected 'staging' or 'prod'${NC}"
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
    echo -e "${CYAN}  environment: staging or prod${NC}"
    echo -e "${CYAN}Examples:${NC}"
    echo -e "${CYAN}  $0 staging${NC}"
    echo -e "${CYAN}  $0 prod${NC}"
    exit 1
fi

ENVIRONMENT=$1

# Validate environment
if [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "prod" ]; then
    echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
    echo -e "${YELLOW}Environment must be either 'staging' or 'prod'${NC}"
    exit 1
fi

print_separator
echo -e "${BLUE}🔧 Loading Configuration...${NC}"

echo -e "${GREEN}✅ Configuration loaded successfully${NC}"
echo -e "${CYAN}   • Environment: $ENVIRONMENT${NC}"
echo -e "${CYAN}   • Output Directory: $PROJECT_ROOT/script/output/$ENVIRONMENT${NC}"
print_separator

echo -e "${BLUE}🔍 Checking for network cleanup requirements...${NC}"

# Check if any networks in existing latest.json are not in production config
if ! check_and_prompt_for_network_deletion "$ENVIRONMENT"; then
    echo -e "${RED}❌ Network cleanup check failed${NC}"
    exit 1
fi

echo -e "${BLUE}🔍 Scanning for deployed contracts in output/$ENVIRONMENT/...${NC}"

FOUND_DEPLOYMENTS=()

# Check which networks have deployments
for network_def in "${NETWORKS[@]}"; do
    IFS=':' read -r network_id network_name rpc_var verifier_var <<< "$network_def"
    
    contracts_file="$PROJECT_ROOT/script/output/$ENVIRONMENT/$network_id/$network_name-latest.json"
    
    if [ -f "$contracts_file" ]; then
        echo -e "${GREEN}   ✅ Found deployment: $network_name (Chain ID: $network_id)${NC}"
        FOUND_DEPLOYMENTS+=("$network_def")
    else
        echo -e "${YELLOW}   ⚠️  No deployment found: $network_name (Chain ID: $network_id) - $contracts_file${NC}"
    fi
done

if [ ${#FOUND_DEPLOYMENTS[@]} -eq 0 ]; then
    echo -e "${RED}❌ No contract deployments found in output/$ENVIRONMENT/ directory${NC}"
    echo -e "${YELLOW}Please ensure contracts have been deployed before running this script.${NC}"
    exit 1
fi

print_separator

echo -e "${PURPLE}📄 Processing batch generation of latest.json locally...${NC}"

TOTAL_COUNT=${#FOUND_DEPLOYMENTS[@]}

echo -e "${PURPLE}╭─────────────────────────────────────────────────────────────────────────────────────╮${NC}"
echo -e "${PURPLE}│${WHITE}                     📄 Batch Generating Local Latest.json 📄                      ${PURPLE}│${NC}"
echo -e "${PURPLE}╰─────────────────────────────────────────────────────────────────────────────────────╯${NC}"

echo -e "${CYAN}   Environment: ${WHITE}$ENVIRONMENT${NC}"
echo -e "${CYAN}   Total Networks: ${WHITE}$TOTAL_COUNT${NC}"
echo -e "${CYAN}   Networks: ${WHITE}$(for net in "${FOUND_DEPLOYMENTS[@]}"; do IFS=':' read -r id name _ _ <<< "$net"; echo -n "$name "; done)${NC}"
echo ""

if batch_generate_latest_json "$ENVIRONMENT" "${FOUND_DEPLOYMENTS[@]}"; then
    print_separator
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                                      ║${NC}"
    echo -e "${GREEN}║${WHITE}              🎉 Latest.json Generated Successfully! 🎉                           ${GREEN}║${NC}"
    echo -e "${GREEN}║                                                                                      ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${CYAN}📄 Latest.json saved to: $PROJECT_ROOT/script/output/$ENVIRONMENT/latest.json${NC}"
    echo -e "${CYAN}📊 Successfully processed: $TOTAL_COUNT networks with changes${NC}"
else
    print_separator
    echo -e "${RED}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                                                                                      ║${NC}"
    echo -e "${RED}║${WHITE}                        ❌ Generation Failed ❌                                     ${RED}║${NC}"
    echo -e "${RED}║                                                                                      ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${RED}❌ Failed to generate latest.json locally${NC}"
    exit 1
fi

print_separator
