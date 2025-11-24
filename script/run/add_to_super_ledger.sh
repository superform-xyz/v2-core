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
    echo -e "${CYAN}║${WHITE}               🔧 Add To SuperLedger Configuration Script 🔧                       ${CYAN}║${NC}"
    echo -e "${CYAN}║                                                                                      ║${NC}"
    echo -e "${CYAN}║${WHITE}                        (Production/Staging/VNET Environments)                     ${CYAN}║${NC}"
    echo -e "${CYAN}║                                                                                      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
}

# Function to print section separator
print_separator() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to print network configuration header
print_network_header() {
    local network=$1
    echo -e "${PURPLE}╭─────────────────────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}│${WHITE}                 🔧 Adding Oracle to SuperLedger on ${network} Network 🔧            ${PURPLE}│${NC}"
    echo -e "${PURPLE}╰─────────────────────────────────────────────────────────────────────────────────────╯${NC}"
}

# Logging function for consistent output
log() {
    local level=$1
    shift
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*" >&2
}

# Function to check if output files exist for configuration
check_deployment_files() {
    local environment=$1
    local network_name=$2
    local network_id=$3
    local branch_name=$4

    local contracts_file
    if [ -n "$branch_name" ]; then
        # For vnet with branch name
        contracts_file="script/output/$branch_name/$network_id/$network_name-latest.json"
    else
        # For staging/prod without branch name
        contracts_file="script/output/$environment/$network_id/$network_name-latest.json"
    fi

    if [ ! -f "$contracts_file" ]; then
        log "ERROR" "Deployment file not found: $contracts_file"
        log "ERROR" "Please ensure the core contracts have been deployed first"
        return 1
    fi

    # Validate the file contains required contracts
    if ! jq -e '.SuperLedgerConfiguration' "$contracts_file" >/dev/null 2>&1; then
        log "ERROR" "SuperLedgerConfiguration not found in $contracts_file"
        return 1
    fi

    log "INFO" "Deployment file validated: $contracts_file"
    return 0
}

print_header

# Ensure we're running from the repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Change to repository root if not already there
if [ "$(pwd)" != "$REPO_ROOT" ]; then
    echo -e "${YELLOW}📁 Changing to repository root: $REPO_ROOT${NC}"
    cd "$REPO_ROOT"
fi

# Tenderly Configuration (for vnet)
API_BASE_URL="https://api.tenderly.co/api/v1"
TENDERLY_ACCOUNT="superform"
TENDERLY_PROJECT="v2"

# Function to generate slug for vnet
generate_slug() {
    local network=$1
    local branch=$2
    local output="${branch//\//-}-${network}"
    # Convert to lowercase, replace spaces with hyphens, remove special chars
    output=$(echo "$output" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')
    echo "$output"
}

# Function to get network name slug for Tenderly
get_network_slug() {
    local chain_id=$1
    case "$chain_id" in
        1) echo "ethereum" ;;
        8453) echo "base" ;;
        10) echo "optimism" ;;
        42161) echo "arbitrum" ;;
        137) echo "polygon" ;;
        56) echo "bnb" ;;
        130) echo "unichain" ;;
        43114) echo "avalanche" ;;
        146) echo "sonic" ;;
        100) echo "gnosis" ;;
        480) echo "worldchain" ;;
        *) echo "unknown" ;;
    esac
}

# Function to load RPC URLs from 1Password based on environment
load_rpc_urls_from_1password() {
    local environment=$1

    log "INFO" "Loading RPC URLs from 1Password for $environment environment..."

    # Core networks (all environments)
    ETH_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/ETHEREUM_RPC_URL/credential 2>/dev/null || echo "")
    BASE_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_RPC_URL/credential 2>/dev/null || echo "")
    BSC_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BSC_RPC_URL/credential 2>/dev/null || echo "")
    ARBITRUM_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/ARBITRUM_RPC_URL/credential 2>/dev/null || echo "")
    AVALANCHE_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/AVALANCHE_RPC_URL/credential 2>/dev/null || echo "")

    # Production-only networks
    if [ "$environment" = "prod" ]; then
        OPTIMISM_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/OPTIMISM_RPC_URL/credential 2>/dev/null || echo "")
        POLYGON_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/POLYGON_RPC_URL/credential 2>/dev/null || echo "")
        UNICHAIN_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/UNICHAIN_RPC_URL/credential 2>/dev/null || echo "")
        SONIC_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/SONIC_RPC_URL/credential 2>/dev/null || echo "")
        GNOSIS_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/GNOSIS_RPC_URL/credential 2>/dev/null || echo "")
        WORLDCHAIN_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/WORLDCHAIN_RPC_URL/credential 2>/dev/null || echo "")
    fi

    log "INFO" "RPC URLs loaded from 1Password"
}

# Function to get vnet RPC URL from Tenderly
get_vnet_rpc_url() {
    local branch_name=$1
    local chain_id=$2
    local access_key=$3

    if [ -z "$access_key" ]; then
        log "ERROR" "Tenderly access key not provided"
        return 1
    fi

    local network_slug=$(get_network_slug "$chain_id")
    local slug=$(generate_slug "$network_slug" "$branch_name")

    log "INFO" "Looking up vnet with slug: $slug"

    # Get list of all VNETs from Tenderly
    local vnet_list
    vnet_list=$(curl -s -X GET \
        "${API_BASE_URL}/account/${TENDERLY_ACCOUNT}/project/${TENDERLY_PROJECT}/vnets" \
        -H "X-Access-Key: ${access_key}")

    # Find vnet with matching slug
    local vnet_id
    vnet_id=$(echo "$vnet_list" | jq -r --arg slug "$slug" '.[] | select(.slug==$slug) | .id // empty')

    if [ -z "$vnet_id" ]; then
        log "ERROR" "No vnet found with slug: $slug"
        return 1
    fi

    log "INFO" "Found vnet with ID: $vnet_id"

    # Get vnet details to extract RPC URL
    local vnet_details
    vnet_details=$(curl -s -X GET \
        "${API_BASE_URL}/account/${TENDERLY_ACCOUNT}/project/${TENDERLY_PROJECT}/vnets/${vnet_id}" \
        -H "X-Access-Key: ${access_key}")

    # Extract Admin RPC URL
    local admin_rpc
    admin_rpc=$(echo "$vnet_details" | jq -r '.rpcs[] | select(.name=="Admin RPC") | .url')

    if [ -n "$admin_rpc" ]; then
        log "INFO" "Successfully extracted admin RPC: $admin_rpc"
        echo "$admin_rpc"
        return 0
    else
        log "ERROR" "Could not extract Admin RPC from vnet details"
        return 1
    fi
}

# Check if first argument is "simulate"
if [ "$1" = "simulate" ]; then
    MODE="simulate"
    shift # Remove "simulate" from arguments
else
    MODE="add"
fi

# Check if arguments are provided
if [ $# -lt 4 ]; then
    echo -e "${RED}❌ Error: Missing required arguments${NC}"
    echo -e "${YELLOW}Usage: $0 [simulate] <environment> <chain_id> <network_name> [branch_name] <salts> <oracle_addresses>${NC}"
    echo -e "${CYAN}  simulate: Optional flag to run in simulation mode (no broadcast)${NC}"
    echo -e "${CYAN}  environment: staging, prod, or vnet${NC}"
    echo -e "${CYAN}  chain_id: Network chain ID (e.g., 1 for Ethereum, 8453 for Base)${NC}"
    echo -e "${CYAN}  network_name: Network name (e.g., Ethereum, Base, Optimism)${NC}"
    echo -e "${CYAN}  branch_name: (Optional) Branch name for vnet deployments (e.g., demo, dev, local)${NC}"
    echo -e "${CYAN}  salts: Comma-separated list of salts (e.g., \"SUPER_VAULT_ORACLE,ANOTHER_ORACLE\")${NC}"
    echo -e "${CYAN}  oracle_addresses: Comma-separated list of oracle addresses${NC}"
    echo -e "${CYAN}Examples:${NC}"
    echo -e "${CYAN}  # Staging - Simulate first${NC}"
    echo -e "${CYAN}  $0 simulate staging 1 Ethereum \"SUPER_VAULT_ORACLE\" \"0x1234...\"${NC}"
    echo -e "${CYAN}  # Staging - Actually execute${NC}"
    echo -e "${CYAN}  $0 staging 1 Ethereum \"SUPER_VAULT_ORACLE\" \"0x1234...\"${NC}"
    echo -e "${CYAN}  # VNET - With branch name (demo)${NC}"
    echo -e "${CYAN}  $0 simulate vnet 1 Ethereum demo \"SUPER_VAULT_ORACLE\" \"0x1234...\"${NC}"
    echo -e "${CYAN}  # Multiple oracles${NC}"
    echo -e "${CYAN}  $0 prod 8453 Base \"SUPER_VAULT_ORACLE,PENDLE_ORACLE\" \"0x1234...,0x5678...\"${NC}"
    exit 1
fi

ENVIRONMENT=$1
CHAIN_ID=$2
NETWORK_NAME=$3

###################################################################################
# Authentication Setup
###################################################################################

# Check if 1Password CLI is available
if command -v op >/dev/null 2>&1; then
    HAS_1PASSWORD=true
else
    HAS_1PASSWORD=false
    log "WARN" "1Password CLI not available, will use .env file or environment variables"
fi

# For vnet, we need Tenderly access key from 1Password
if [ "$ENVIRONMENT" = "vnet" ]; then
    if [ "$HAS_1PASSWORD" = true ]; then
        log "INFO" "Loading Tenderly credentials from 1Password..."
        TENDERLY_ACCESS_KEY=$(op read "op://5ylebqljbh3x6zomdxi3qd7tsa/TENDERLY_ACCESS_KEY_V2/credential")
        if [ -z "$TENDERLY_ACCESS_KEY" ]; then
            log "ERROR" "Failed to read Tenderly access key from 1Password"
            exit 1
        fi
        log "INFO" "Successfully loaded Tenderly credentials"
    else
        # Source .env if Tenderly key is missing
        if [ -z "${TENDERLY_ACCESS_KEY:-}" ]; then
            if [ ! -f .env ]; then
                log "ERROR" ".env file is required when TENDERLY_ACCESS_KEY is not set and op command is unavailable"
                exit 1
            fi
            log "INFO" "Loading TENDERLY_ACCESS_KEY from .env file"
            source .env
        fi
    fi

    # Validate Tenderly access key
    if [ -z "${TENDERLY_ACCESS_KEY:-}" ]; then
        log "ERROR" "TENDERLY_ACCESS_KEY is required for vnet environment"
        exit 1
    fi
elif [ "$ENVIRONMENT" = "staging" ] || [ "$ENVIRONMENT" = "prod" ]; then
    # For staging/prod, load RPC URLs from 1Password if available
    if [ "$HAS_1PASSWORD" = true ]; then
        load_rpc_urls_from_1password "$ENVIRONMENT"
    else
        log "WARN" "1Password CLI not available, RPC URLs must be set via environment variables or .env"
        if [ -f .env ]; then
            log "INFO" "Loading configuration from .env file"
            source .env
        fi
    fi
fi

# Check if 4th argument might be a branch name (for vnet) or salts
# Branch names are typically alphabetic (demo, dev, local, etc.)
# While salts often contain underscores or start with quotes
if [ "$ENVIRONMENT" = "vnet" ] && [ $# -ge 6 ] && [[ ! "$4" =~ ^[\"\[] ]]; then
    # 4th argument is branch name for vnet
    BRANCH_NAME=$4
    SALTS_INPUT=$5
    ORACLE_ADDRESSES_INPUT=$6
else
    # No branch name, 4th argument is salts
    BRANCH_NAME=""
    SALTS_INPUT=$4
    ORACLE_ADDRESSES_INPUT=$5
fi

# Validate environment
if [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "prod" ] && [ "$ENVIRONMENT" != "vnet" ]; then
    echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
    echo -e "${YELLOW}Environment must be 'staging', 'prod', or 'vnet'${NC}"
    exit 1
fi

# Set environment variable for forge script
if [ "$ENVIRONMENT" = "staging" ]; then
    FORGE_ENV=2
elif [ "$ENVIRONMENT" = "vnet" ]; then
    FORGE_ENV=1
else
    FORGE_ENV=0
fi

# Set flags based on mode
if [ "$MODE" = "simulate" ]; then
    echo -e "${YELLOW}🔍 Running in simulation mode for $ENVIRONMENT...${NC}"
    echo -e "${CYAN}   - No broadcasting to network${NC}"
    echo -e "${CYAN}   - Configuration will be simulated only${NC}"
    BROADCAST_FLAG=""
else
    echo -e "${GREEN}🚀 Running in add mode for $ENVIRONMENT...${NC}"
    echo -e "${CYAN}   - Broadcasting to network${NC}"
    echo -e "${CYAN}   - Oracle will be added to SuperLedger${NC}"
    BROADCAST_FLAG="--broadcast"
fi

print_separator
echo -e "${BLUE}🔧 Configuration Details...${NC}"
echo -e "${CYAN}   • Environment: $ENVIRONMENT${NC}"
echo -e "${CYAN}   • Chain ID: $CHAIN_ID${NC}"
echo -e "${CYAN}   • Network: $NETWORK_NAME${NC}"
if [ -n "$BRANCH_NAME" ]; then
    echo -e "${CYAN}   • Branch Name: $BRANCH_NAME${NC}"
fi
echo -e "${CYAN}   • Mode: $MODE${NC}"
echo -e "${CYAN}   • Salts: $SALTS_INPUT${NC}"
echo -e "${CYAN}   • Oracle Addresses: $ORACLE_ADDRESSES_INPUT${NC}"
print_separator

# Convert comma-separated strings to arrays
IFS=',' read -ra SALTS_ARRAY <<< "$SALTS_INPUT"
IFS=',' read -ra ORACLE_ADDRESSES_ARRAY <<< "$ORACLE_ADDRESSES_INPUT"

# Validate arrays have same length
if [ ${#SALTS_ARRAY[@]} -ne ${#ORACLE_ADDRESSES_ARRAY[@]} ]; then
    echo -e "${RED}❌ Error: Number of salts (${#SALTS_ARRAY[@]}) does not match number of oracle addresses (${#ORACLE_ADDRESSES_ARRAY[@]})${NC}"
    exit 1
fi

echo -e "${CYAN}   • Number of oracles to add: ${#SALTS_ARRAY[@]}${NC}"

# Build the Forge script arguments
# Convert arrays to bytes32[] and address[] format for Solidity
SALTS_ARG="["
ADDRESSES_ARG="["

for i in "${!SALTS_ARRAY[@]}"; do
    # Convert salt string to bytes32 format
    SALT="${SALTS_ARRAY[$i]}"
    # Trim whitespace
    SALT=$(echo "$SALT" | xargs)

    # Convert to bytes32 (will be handled by the script)
    if [ $i -gt 0 ]; then
        SALTS_ARG+=","
    fi
    SALTS_ARG+="\"$SALT\""

    # Add address
    ADDRESS="${ORACLE_ADDRESSES_ARRAY[$i]}"
    # Trim whitespace
    ADDRESS=$(echo "$ADDRESS" | xargs)

    if [ $i -gt 0 ]; then
        ADDRESSES_ARG+=","
    fi
    ADDRESSES_ARG+="$ADDRESS"
done

SALTS_ARG+="]"
ADDRESSES_ARG+="]"

echo -e "${CYAN}   • Salts Array: $SALTS_ARG${NC}"
echo -e "${CYAN}   • Addresses Array: $ADDRESSES_ARG${NC}"
print_separator

# Check deployment files
echo -e "${BLUE}🔍 Validating deployment files...${NC}"
check_deployment_files "$ENVIRONMENT" "$NETWORK_NAME" "$CHAIN_ID" "$BRANCH_NAME"
if [ $? -ne 0 ]; then
    exit 1
fi
echo -e "${GREEN}✅ Deployment files validated${NC}"
print_separator

# Get RPC URL based on environment and chain ID
get_rpc_url() {
    local chain_id=$1

    # Check if RPC_URL is already set as environment variable
    if [ -n "${RPC_URL:-}" ]; then
        echo "$RPC_URL"
        return
    fi

    # For vnet, try to get from Tenderly or local output
    if [ "$ENVIRONMENT" = "vnet" ] && [ -n "$BRANCH_NAME" ]; then
        # Try to read from local latest.json which may have RPC info
        local latest_file="script/output/$BRANCH_NAME/latest.json"
        if [ -f "$latest_file" ]; then
            local rpc=$(jq -r ".networks[] | select(.chainId==$chain_id) | .rpc" "$latest_file" 2>/dev/null || echo "")
            if [ -n "$rpc" ] && [ "$rpc" != "null" ]; then
                echo "$rpc"
                return
            fi
        fi
    fi

    # Fall back to environment variables (same naming as networks-staging.sh and networks-production.sh)
    case $chain_id in
        1)
            echo "${ETH_MAINNET:-}"
            ;;
        8453)
            echo "${BASE_MAINNET:-}"
            ;;
        10)
            echo "${OPTIMISM_MAINNET:-}"
            ;;
        42161)
            echo "${ARBITRUM_MAINNET:-}"
            ;;
        137)
            echo "${POLYGON_MAINNET:-}"
            ;;
        56)
            echo "${BSC_MAINNET:-}"
            ;;
        130)
            echo "${UNICHAIN_MAINNET:-}"
            ;;
        43114)
            echo "${AVALANCHE_MAINNET:-}"
            ;;
        146)
            echo "${SONIC_MAINNET:-}"
            ;;
        100)
            echo "${GNOSIS_MAINNET:-}"
            ;;
        480)
            echo "${WORLDCHAIN_MAINNET:-}"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Configure authentication based on environment
if [ "$ENVIRONMENT" = "vnet" ]; then
    # For VNET, use the deployer private key
    echo -e "${YELLOW}⚠️  Using local wallet for VNET${NC}"

    # Get salt namespace from environment variable or derive from network
    if [ -z "${SALT_NAMESPACE:-}" ]; then
        case "$CHAIN_ID" in
            1)
                SALT_NAMESPACE=$(grep -oP 'ETH_SALT="\K[^"]+' script/run/deploy_v2_vnet_s3.sh 2>/dev/null || echo "")
                ;;
            8453)
                SALT_NAMESPACE=$(grep -oP 'BASE_SALT="\K[^"]+' script/run/deploy_v2_vnet_s3.sh 2>/dev/null || echo "")
                ;;
            10)
                SALT_NAMESPACE=$(grep -oP 'OPTIMISM_SALT="\K[^"]+' script/run/deploy_v2_vnet_s3.sh 2>/dev/null || echo "")
                ;;
            *)
                SALT_NAMESPACE=""
                ;;
        esac

        # If still empty and we have a branch name, use the branch name as salt namespace
        if [ -z "$SALT_NAMESPACE" ] && [ -n "$BRANCH_NAME" ]; then
            SALT_NAMESPACE="$BRANCH_NAME"
            log "INFO" "Using branch name as salt namespace: $SALT_NAMESPACE"
        fi
    fi

    # Get RPC URL from Tenderly vnet if branch name is provided
    if [ -n "$BRANCH_NAME" ]; then
        echo -e "${CYAN}🔍 Fetching vnet RPC URL from Tenderly...${NC}"
        RPC_URL=$(get_vnet_rpc_url "$BRANCH_NAME" "$CHAIN_ID" "$TENDERLY_ACCESS_KEY")
        if [ $? -ne 0 ] || [ -z "$RPC_URL" ]; then
            echo -e "${RED}❌ Error: Failed to get vnet RPC URL from Tenderly${NC}"
            echo -e "${YELLOW}Falling back to manual RPC URL configuration...${NC}"
            RPC_URL=$(get_rpc_url "$CHAIN_ID")
        fi
    else
        RPC_URL=$(get_rpc_url "$CHAIN_ID")
    fi

    # Validate RPC URL is set
    if [ -z "$RPC_URL" ]; then
        echo -e "${RED}❌ Error: RPC_URL not set for chain ID $CHAIN_ID${NC}"
        echo -e "${YELLOW}Please set the RPC_URL environment variable or ensure 1Password CLI is configured.${NC}"
        echo -e "${CYAN}Options:${NC}"
        echo -e "${CYAN}  1. Use 1Password CLI: op signin${NC}"
        echo -e "${CYAN}  2. Set specific RPC URL: export RPC_URL=\"your-rpc-url\"${NC}"
        echo -e "${CYAN}  3. Set network-specific variable based on chain:${NC}"
        echo -e "${CYAN}     - Chain 1 (Ethereum): export ETH_MAINNET=\"your-rpc\"${NC}"
        echo -e "${CYAN}     - Chain 8453 (Base): export BASE_MAINNET=\"your-rpc\"${NC}"
        echo -e "${CYAN}     - Chain 10 (Optimism): export OPTIMISM_MAINNET=\"your-rpc\"${NC}"
        echo -e "${CYAN}     - Chain 42161 (Arbitrum): export ARBITRUM_MAINNET=\"your-rpc\"${NC}"
        echo -e "${CYAN}     - Chain 137 (Polygon): export POLYGON_MAINNET=\"your-rpc\"${NC}"
        echo -e "${CYAN}     - Chain 56 (BNB): export BSC_MAINNET=\"your-rpc\"${NC}"
        echo -e "${CYAN}     - Chain 130 (Unichain): export UNICHAIN_MAINNET=\"your-rpc\"${NC}"
        echo -e "${CYAN}     - Chain 43114 (Avalanche): export AVALANCHE_MAINNET=\"your-rpc\"${NC}"
        echo -e "${CYAN}     - Chain 146 (Sonic): export SONIC_MAINNET=\"your-rpc\"${NC}"
        echo -e "${CYAN}     - Chain 100 (Gnosis): export GNOSIS_MAINNET=\"your-rpc\"${NC}"
        echo -e "${CYAN}     - Chain 480 (Worldchain): export WORLDCHAIN_MAINNET=\"your-rpc\"${NC}"
        exit 1
    fi

    print_network_header "${NETWORK_NAME^^}"
    echo -e "${CYAN}   Chain ID: ${WHITE}$CHAIN_ID${NC}"
    echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
    echo -e "${CYAN}   Environment: ${WHITE}$ENVIRONMENT${NC}"
    if [ -n "$BRANCH_NAME" ]; then
        echo -e "${CYAN}   Branch Name: ${WHITE}$BRANCH_NAME${NC}"
    fi
    if [ -n "$SALT_NAMESPACE" ]; then
        echo -e "${CYAN}   Salt Namespace: ${WHITE}$SALT_NAMESPACE${NC}"
    fi
    echo -e "${YELLOW}   Executing forge script...${NC}"

    # Always use the unified signature with all parameters (empty strings for optional ones)
    # Set defaults for optional parameters
    SALT_NS="${SALT_NAMESPACE:-}"
    BRANCH="${BRANCH_NAME:-}"

    forge script script/AddToSuperLedgerConfiguration.s.sol:AddToSuperLedgerConfiguration \
        --sig 'run(uint256,uint64,string,string,string[],address[])' $FORGE_ENV $CHAIN_ID "$SALT_NS" "$BRANCH" "$SALTS_ARG" "$ADDRESSES_ARG" \
        --rpc-url "$RPC_URL" \
        $BROADCAST_FLAG \
        -vv
else
    # For production/staging, use Fireblocks
    echo -e "${CYAN}   • Loading Fireblocks credentials...${NC}"
    export FIREBLOCKS_API_KEY=$(op read op://zry2qwhqux2w6qtjitg44xb7b4/V2_SUPERLEDGER_ACTION/credential)
    export FIREBLOCKS_API_PRIVATE_KEY_PATH=$(op read op://zry2qwhqux2w6qtjitg44xb7b4/V2_SUPERLEDGER_SECRET/notesPlain)
    export FIREBLOCKS_VAULT_ACCOUNT_IDS=29  # SuperLedger Config Vault Account

    echo -e "${GREEN}✅ Fireblocks credentials loaded${NC}"
    echo -e "${CYAN}   • Using Fireblocks MPC for transaction signing${NC}"

    RPC_URL=$(get_rpc_url "$CHAIN_ID")
    export FIREBLOCKS_RPC_URL="$RPC_URL"
    export FIREBLOCKS_CHAIN_ID="$CHAIN_ID"

    print_network_header "${NETWORK_NAME^^}"
    echo -e "${CYAN}   Chain ID: ${WHITE}$CHAIN_ID${NC}"
    echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
    echo -e "${CYAN}   Environment: ${WHITE}$ENVIRONMENT${NC}"
    echo -e "${CYAN}   MPC Wallet: ${WHITE}Fireblocks${NC}"
    echo -e "${YELLOW}   Executing forge script via Fireblocks...${NC}"

    # Always use the unified signature with all parameters (empty strings for optional ones)
    SALT_NS="${SALT_NAMESPACE:-}"
    BRANCH="${BRANCH_NAME:-}"

    fireblocks-json-rpc --http -- forge script script/AddToSuperLedgerConfiguration.s.sol:AddToSuperLedgerConfiguration \
        --sig 'run(uint256,uint64,string,string,string[],address[])' $FORGE_ENV $CHAIN_ID "$SALT_NS" "$BRANCH" "$SALTS_ARG" "$ADDRESSES_ARG" \
        --rpc-url {} \
        --sender 0x28b7599f461D104f07D78215Fa6F9B959851f93d \
        $BROADCAST_FLAG \
        --unlocked \
        --slow \
        -vv
fi

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ $NETWORK_NAME configuration completed successfully!${NC}"
else
    echo -e "${RED}❌ Configuration failed!${NC}"
    exit 1
fi

print_separator
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                                                      ║${NC}"
echo -e "${GREEN}║${WHITE}            🎉 Oracle Addition to SuperLedger $MODE Completed! 🎉                  ${GREEN}║${NC}"
echo -e "${GREEN}║                                                                                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"

echo -e "${CYAN}🔧 Added ${#SALTS_ARRAY[@]} oracle(s) to SuperLedger configuration on:${NC}"
echo -e "${CYAN}   • $NETWORK_NAME (Chain ID: $CHAIN_ID)${NC}"
if [ "$ENVIRONMENT" != "vnet" ]; then
    echo -e "${CYAN}🏛️ Transaction signed via Fireblocks MPC wallet${NC}"
fi
print_separator
