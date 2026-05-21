#!/usr/bin/env bash

# ===== CHAIN FILTER CONFIGURATION =====
# Specify which chains to verify (comment out to verify all chains)
# Leave empty array to verify all chains from network configuration
CHAINS_TO_VERIFY=(1 8453 56 42161 43114)

# ===== CONTRACT FILTER CONFIGURATION =====
# Specify which contracts to verify (comment out to verify all contracts)
# Leave empty array to verify all contracts found in deployment JSON
CONTRACTS_TO_VERIFY=("SwapOdosV3Hook" "ApproveAndSwapOdosV3Hook")

# ===== RATE LIMIT CONFIGURATION =====
# Delay in seconds between verification requests (prevents Cloudflare rate limiting)
VERIFY_DELAY=5

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
    echo -e "${CYAN}║${WHITE}                      🔍 V2 Core Production Contract Verification 🔍                   ${CYAN}║${NC}"
    echo -e "${CYAN}║                                                                                      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
}

# Function to print section separator
print_separator() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to print network header
print_network_header() {
    local network=$1
    echo -e "${PURPLE}╭─────────────────────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}│${WHITE}                         🌐 Verifying on ${network} Network 🌐                          ${PURPLE}│${NC}"
    echo -e "${PURPLE}╰─────────────────────────────────────────────────────────────────────────────────────╯${NC}"
}

print_header

# Script directory and project root setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

# Validate environment and source appropriate network configuration
if [ "$ENVIRONMENT" = "staging" ]; then
    echo -e "${CYAN}🌐 Loading staging network configuration...${NC}"
    source "$SCRIPT_DIR/networks-staging.sh"
elif [ "$ENVIRONMENT" = "prod" ]; then
    echo -e "${CYAN}🌐 Loading production network configuration...${NC}"
    source "$SCRIPT_DIR/networks-production.sh"
else
    echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
    echo -e "${YELLOW}Environment must be either 'staging' or 'prod'${NC}"
    exit 1
fi

echo -e "${CYAN}✅ Network configuration loaded for $ENVIRONMENT environment${NC}"
print_network_info

print_separator
echo -e "${BLUE}🔧 Loading Configuration...${NC}"

# Load RPC URLs using network-specific function
echo -e "${CYAN}   • Loading RPC URLs...${NC}"
if ! load_rpc_urls; then
    echo -e "${RED}❌ Failed to load some RPC URLs from credential manager${NC}"
    echo -e "${YELLOW}⚠️  This may cause connectivity issues during verification${NC}"
    echo -e "${YELLOW}   Please ensure all required RPC URLs are configured in 1Password${NC}"
    exit 1
fi

# Load Etherscan V2 API key for verification
echo -e "${CYAN}   • Loading Etherscan V2 API credentials...${NC}"
if ! load_etherscan_api_key; then
    echo -e "${RED}❌ Failed to load Etherscan V2 API key${NC}"
    echo -e "${RED}   Contract verification will not work without this credential${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Configuration loaded successfully${NC}"
echo -e "${CYAN}   • Using Etherscan V2 verification${NC}"
echo -e "${CYAN}   • Environment: $ENVIRONMENT${NC}"

print_separator

# Dynamic network configurations will be built from loaded network files

# Function to load contract addresses from JSON
load_contract_addresses() {
    local chain_id=$1
    local network_name=""
    
    # Get network name from the loaded configuration
    network_name=$(get_network_name "$chain_id")
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Unknown network ID: $chain_id${NC}"
        return 1
    fi
    
    # Convert network name to file suffix format
    case $chain_id in
        "1") network_suffix="Ethereum-latest" ;;
        "8453") network_suffix="Base-latest" ;;
        "56") network_suffix="BNB-latest" ;;
        "42161") network_suffix="Arbitrum-latest" ;;
        "10") network_suffix="Optimism-latest" ;;
        "137") network_suffix="Polygon-latest" ;;
        "130") network_suffix="Unichain-latest" ;;
        "43114") network_suffix="Avalanche-latest" ;;
        "80094") network_suffix="Berachain-latest" ;;
        "146") network_suffix="Sonic-latest" ;;
        "100") network_suffix="Gnosis-latest" ;;
        "480") network_suffix="Worldchain-latest" ;;
        "999") network_suffix="HyperEVM-latest" ;;
        "14") network_suffix="Flare-latest" ;;
        *) network_suffix="${network_name}-latest" ;;
    esac

    local json_file="script/output/$ENVIRONMENT/$chain_id/$network_suffix.json"

    if [ ! -f "$json_file" ]; then
        echo -e "${RED}❌ JSON file not found: $json_file${NC}"
        echo -e "${RED}   Expected path: $json_file${NC}"
        echo -e "${YELLOW}   Make sure contracts have been deployed to this network first${NC}"
        return 1
    fi

    echo -e "${CYAN}   • Loading addresses from: $json_file${NC}"
    return 0
}

# Function to get contract address from JSON
get_contract_address() {
    local chain_id=$1
    local contract_name=$2
    local network_suffix=""
    
    # Convert network name to file suffix format (same as load_contract_addresses)
    case $chain_id in
        "1") network_suffix="Ethereum-latest" ;;
        "8453") network_suffix="Base-latest" ;;
        "56") network_suffix="BNB-latest" ;;
        "42161") network_suffix="Arbitrum-latest" ;;
        "10") network_suffix="Optimism-latest" ;;
        "137") network_suffix="Polygon-latest" ;;
        "130") network_suffix="Unichain-latest" ;;
        "59144") network_suffix="Linea-latest" ;;
        "43114") network_suffix="Avalanche-latest" ;;
        "80094") network_suffix="Berachain-latest" ;;
        "146") network_suffix="Sonic-latest" ;;
        "100") network_suffix="Gnosis-latest" ;;
        "480") network_suffix="Worldchain-latest" ;;
        "999") network_suffix="HyperEVM-latest" ;;
        "14") network_suffix="Flare-latest" ;;
        *)
            local network_name=$(get_network_name "$chain_id")
            network_suffix="${network_name}-latest"
            ;;
    esac

    local json_file="script/output/$ENVIRONMENT/$chain_id/$network_suffix.json"

    if [ -f "$json_file" ]; then
        local address=$(jq -r ".$contract_name // empty" "$json_file")
        echo "$address"
    else
        echo ""
    fi
}

# Function to generate constructor arguments based on deployment logic
generate_constructor_args() {
    local contract_name=$1
    local chain_id=$2
    
    # Get core contract addresses for this chain
    local super_ledger_config=$(get_contract_address "$chain_id" "SuperLedgerConfiguration")
    local super_executor=$(get_contract_address "$chain_id" "SuperExecutor")
    local super_destination_executor=$(get_contract_address "$chain_id" "SuperDestinationExecutor")
    local super_merkle_validator=$(get_contract_address "$chain_id" "SuperValidator")
    local super_destination_validator=$(get_contract_address "$chain_id" "SuperDestinationValidator")
    
    # Network-specific addresses (these would need to be configured per network)
    local permit2=""
    local aggregation_router=""
    local odos_router=""
    local odos_router_v3="0x0D05a7D3448512B78fa8A9e46c4872C88C4a0D05"  # Same CREATE2 on all EVM chains
    local across_spoke_pool_v3=""
    local merkl_distributor=""
    local debridge_dst_dln="0xE7351Fd770A37282b91D153Ee690B63579D6dd7f"
    local entry_point="0x0000000071727De22E5E9d8BAf0edAc6f37da032"  # EntryPoint v0.7
    local debridge_dln_src="0xeF4fB24aD0916217251F553c0596F8Edc630EB66"  # Standard DeBridge DLN SRC
    local debridge_dln_dst="0xE7351Fd770A37282b91D153Ee690B63579D6dd7f"  # Standard DeBridge DLN DST
    local gateway_wallet="0x77777777Dcc4d5A8B6E418Fd04D8997ef11000eE"  # Circle Gateway Wallet
    local gateway_minter="0x2222222d7164433c4C09B0b0D809a9b52C04C205"  # Circle Gateway Minter
    # Pendle PT Amortized Oracle addresses (V1)
    # Staging: 0xE31FD1d26A52B4a958651a8E751e9362B3880524
    # Production: 0xD64089698f82cbCD91ba5e0422aDFa81D247eB62
    local pendle_pt_amortized_oracle=""
    if [ "$ENVIRONMENT" = "staging" ]; then
        pendle_pt_amortized_oracle="0xE31FD1d26A52B4a958651a8E751e9362B3880524"
    else
        pendle_pt_amortized_oracle="0xD64089698f82cbCD91ba5e0422aDFa81D247eB62"
    fi

    # Pendle PT Amortized Oracle V2 addresses
    # Staging: 0x1F32A55b20Ee7bA0bC083671c7723dBA1608D66e
    # Production: TBD
    local pendle_pt_amortized_oracle_v2=""
    if [ "$ENVIRONMENT" = "staging" ]; then
        pendle_pt_amortized_oracle_v2="0x1F32A55b20Ee7bA0bC083671c7723dBA1608D66e"
    else
        pendle_pt_amortized_oracle_v2=""  # TBD - update after prod deployment
    fi
    
    # Network-specific configurations
    case $chain_id in
        "1") # Ethereum Mainnet
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router="0x111111125421cA6dc452d289314280a0f8842A65"  # 1inch
            odos_router="0xcf5540fFFCdC3d510B18bFcA6d2b9987b0772559"
            across_spoke_pool_v3="0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5"
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
        "8453") # Base Mainnet
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router="0x111111125421cA6dc452d289314280a0f8842A65"  # 1inch
            odos_router="0x19cEeAd7105607Cd444F5ad10dd51356436095a1"
            across_spoke_pool_v3="0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64"
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
        "56") # BSC Mainnet
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router="0x111111125421cA6dc452d289314280a0f8842A65"  # 1inch
            odos_router="0x89b8AA89FDd0507a99d334CBe3C808fAFC7d850E"
            across_spoke_pool_v3="0x4e8E101924eDE233C13e2D8622DC8aED2872d505"
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
        "42161") # Arbitrum Mainnet
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router="0x111111125421cA6dc452d289314280a0f8842A65"  # 1inch
            odos_router="0xa32EE1C40594249eb3183c10792BcF573D4Da47C"
            across_spoke_pool_v3="0xe35e9842fceaCA96570B734083f4a58e8F7C5f2A"
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
        "10") # Optimism Mainnet
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router="0x111111125421cA6dc452d289314280a0f8842A65"  # 1inch
            odos_router="0xCa423977156BB05b13A2BA3b76Bc5419E2fE9680"
            across_spoke_pool_v3="0x6f26Bf09B1C792e3228e5467807a900A503c0281"
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
        "137") # Polygon Mainnet
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router="0x111111125421cA6dc452d289314280a0f8842A65"  # 1inch
            odos_router="0x4E3288c9ca110bCC82bf38F09A7b425c095d92Bf"
            across_spoke_pool_v3="0x9295ee1d8C5b022Be115A2AD3c30C72E34e7F096"
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            native_token="0x0000000000000000000000000000000000001010"  # Polygon native token
            ;;
        "130") # Unichain Mainnet
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router="0x111111125421cA6dc452d289314280a0f8842A65"  # 1inch
            odos_router="0x6409722F3a1C4486A3b1FE566cBDd5e9D946A1f3"
            across_spoke_pool_v3="0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64"
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
        "43114") # Avalanche Mainnet
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router="0x111111125421cA6dc452d289314280a0f8842A65"  # 1inch
            odos_router="0x88de50B233052e4Fb783d4F6db78Cc34fEa3e9FC"
            across_spoke_pool_v3=""  # Not available
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
        "80094") # Berachain Mainnet
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router=""  # Not deployed
            odos_router=""  # Not deployed
            across_spoke_pool_v3=""  # Not deployed
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
        "146") # Sonic Mainnet
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router="0x111111125421cA6dc452d289314280a0f8842A65"  # 1inch
            odos_router="0xaC041Df48dF9791B0654f1Dbbf2CC8450C5f2e9D"
            across_spoke_pool_v3=""  # Not deployed
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
        "100") # Gnosis Mainnet
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router="0x111111125421cA6dc452d289314280a0f8842A65"  # 1inch
            odos_router=""  # Not deployed
            across_spoke_pool_v3=""  # Not deployed
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
        "480") # Worldchain Mainnet
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router=""  # Not deployed
            odos_router=""  # Not deployed
            across_spoke_pool_v3="0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64"
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
        "999") # HyperEVM (Hyperliquid)
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router=""  # Not deployed
            odos_router=""  # Not deployed
            across_spoke_pool_v3=""  # Not deployed
            merkl_distributor=""  # Not deployed
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
        "14") # Flare
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router=""  # Not deployed
            odos_router=""  # Not deployed
            across_spoke_pool_v3=""  # Not deployed
            merkl_distributor=""  # Not deployed
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
    esac
    
    # Generate constructor arguments based on contract type
    case $contract_name in
        # Core contracts with no constructor args
        "SuperLedgerConfiguration"|"SuperValidator"|"SuperDestinationValidator"|"SuperYieldSourceOracle")
            echo "$(cast abi-encode "constructor()")"
            ;;
        
        # Core contracts with constructor args
        "SuperExecutor")
            echo "$(cast abi-encode "constructor(address)" "$super_ledger_config")"
            ;;
        "SuperDestinationExecutor")
            echo "$(cast abi-encode "constructor(address,address)" "$super_ledger_config" "$super_destination_validator")"
            ;;
        "AcrossV3Adapter")
            echo "$(cast abi-encode "constructor(address,address)" "$across_spoke_pool_v3" "$super_destination_executor")"
            ;;
        "DebridgeAdapter")
            echo "$(cast abi-encode "constructor(address,address)" "$debridge_dst_dln" "$super_destination_executor")"
            ;;
        "SuperLedger"|"FlatFeeLedger")
            echo "$(cast abi-encode "constructor(address,address[])" "$super_ledger_config" "[$super_executor,$super_destination_executor]")"
            ;;
        "SuperNativePaymaster")
            echo "$(cast abi-encode "constructor(address)" "$entry_point")"
            ;;
        
        # Hooks with constructor args
        "BatchTransferHook")
            # BatchTransferHook takes native token address (network-specific)
            echo "$(cast abi-encode "constructor(address)" "$native_token")"
            ;;
        "BatchTransferFromHook")
            echo "$(cast abi-encode "constructor(address)" "$permit2")"
            ;;
        "Swap1InchHook")
            echo "$(cast abi-encode "constructor(address)" "$aggregation_router")"
            ;;
        "SwapOdosV2Hook"|"ApproveAndSwapOdosV2Hook")
            echo "$(cast abi-encode "constructor(address)" "$odos_router")"
            ;;
        "SwapOdosV3Hook"|"ApproveAndSwapOdosV3Hook")
            echo "$(cast abi-encode "constructor(address)" "$odos_router_v3")"
            ;;
        "AcrossSendFundsAndExecuteOnDstHook")
            echo "$(cast abi-encode "constructor(address,address)" "$across_spoke_pool_v3" "$super_merkle_validator")"
            ;;
        "ApproveAndAcrossSendFundsAndExecuteOnDstHook")
            echo "$(cast abi-encode "constructor(address,address)" "$across_spoke_pool_v3" "$super_merkle_validator")"
            ;;
        "DeBridgeSendOrderAndExecuteOnDstHook")
            echo "$(cast abi-encode "constructor(address,address)" "$debridge_dln_src" "$super_merkle_validator")"
            ;;
        "DeBridgeCancelOrderHook")
            echo "$(cast abi-encode "constructor(address)" "$debridge_dln_dst")"
            ;;
        "MerklClaimRewardHook")
            echo "$(cast abi-encode "constructor(address)" "$merkl_distributor")"
            ;;
        "CircleGatewayWalletHook"|"CircleGatewayAddDelegateHook"|"CircleGatewayRemoveDelegateHook")
            echo "$(cast abi-encode "constructor(address)" "$gateway_wallet")"
            ;;
        "CircleGatewayMinterHook")
            echo "$(cast abi-encode "constructor(address)" "$gateway_minter")"
            ;;
        "RecordPurchasePendlePTAmortizedOracleHook"|"RecordRedemptionPendlePTAmortizedOracleHook")
            echo "$(cast abi-encode "constructor(address)" "$pendle_pt_amortized_oracle")"
            ;;
        "RecordPurchasePendlePTAmortizedOracleHookV2"|"RecordRedemptionPendlePTAmortizedOracleHookV2")
            echo "$(cast abi-encode "constructor(address)" "$pendle_pt_amortized_oracle_v2")"
            ;;

        # Uniswap V3 Hooks
        "SwapUniswapV3Hook"|"ApproveAndSwapUniswapV3Hook")
            local uniswap_v3_router=""
            case $chain_id in
                "999") uniswap_v3_router="0x1EbDFC75FfE3ba3de61E7138a3E8706aC841Af9B" ;;  # HyperEVM
                *) uniswap_v3_router="" ;;  # Not deployed on other chains
            esac
            echo "$(cast abi-encode "constructor(address)" "$uniswap_v3_router")"
            ;;

        # Uniswap V4 Hook
        "SwapUniswapV4Hook")
            local uniswap_v4_pool_manager=""
            case $chain_id in
                "1") uniswap_v4_pool_manager="0x000000000004444c5dc75cB358380D2e3dE08A90" ;;  # Ethereum
                "8453") uniswap_v4_pool_manager="0x498581fF718922c3f8e6A244956aF099B2652b2b" ;;  # Base
                "42161") uniswap_v4_pool_manager="0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32" ;;  # Arbitrum
                "10") uniswap_v4_pool_manager="0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3" ;;  # Optimism
                "137") uniswap_v4_pool_manager="0x67366782805870060151383F4BbFF9daB53e5cD6" ;;  # Polygon
                "130") uniswap_v4_pool_manager="0x1F98400000000000000000000000000000000004" ;;  # Unichain
                "43114") uniswap_v4_pool_manager="0x06380C0e0912312B5150364B9DC4542BA0DbBc85" ;;  # Avalanche
                "480") uniswap_v4_pool_manager="0xb1860D529182ac3BC1F51Fa2ABd56662b7D13f33" ;;  # Worldchain
                *) uniswap_v4_pool_manager="" ;;  # Not deployed
            esac
            echo "$(cast abi-encode "constructor(address)" "$uniswap_v4_pool_manager")"
            ;;

        # TransferHook - takes native token address
        "TransferHook")
            echo "$(cast abi-encode "constructor(address)" "$native_token")"
            ;;

        # Pendle Hooks - PendleUnifiedHook, PendleRouterSwapHook, PendleRouterRedeemHook
        "PendleUnifiedHook"|"PendleRouterSwapHook"|"PendleRouterRedeemHook")
            local pendle_router="0x888888888889758F76e7103c6CbF23ABbF58F946"  # Same for all chains
            echo "$(cast abi-encode "constructor(address)" "$pendle_router")"
            ;;

        # SuperVaultYieldSourceOracle
        "SuperVaultYieldSourceOracle")
            echo "$(cast abi-encode "constructor(address)" "$super_ledger_config")"
            ;;

        # Morpho Hooks (all take Morpho Blue address as constructor arg)
        "MorphoSupplyAndBorrowHook"|"MorphoBorrowHook"|"MorphoRepayHook"|"MorphoRepayAndWithdrawHook"|"MorphoSupplyHook"|"MorphoWithdrawHook"|"MorphoLendHook")
            local morpho_address=""
            case $chain_id in
                "1") morpho_address="0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb" ;;    # Ethereum
                "8453") morpho_address="0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb" ;; # Base
                "10") morpho_address="0xce95AfbB8EA029495c66020883F87aaE8864AF92" ;;    # Optimism
                "42161") morpho_address="0x6c247b1F6182318877311737BaC0844bAa518F5e" ;; # Arbitrum
                "56") morpho_address="0x01b0Bd309AA75547f7a37Ad7B1219A898E67a83a" ;;    # BNB
                *) morpho_address="" ;;
            esac
            if [ -n "$morpho_address" ]; then
                echo "$(cast abi-encode "constructor(address)" "$morpho_address")"
            else
                echo "$(cast abi-encode "constructor()")"
            fi
            ;;

        # All other contracts (no constructor args)
        *)
            echo "$(cast abi-encode "constructor()")"
            ;;
    esac
}

# Function to get contract source file path
get_contract_source() {
    local contract_name=$1
    
    case $contract_name in
        # Core contracts
        "SuperExecutor") echo "src/executors/SuperExecutor.sol" ;;
        "SuperDestinationExecutor") echo "src/executors/SuperDestinationExecutor.sol" ;;
        "AcrossV3Adapter") echo "src/adapters/AcrossV3Adapter.sol" ;;
        "DebridgeAdapter") echo "src/adapters/DebridgeAdapter.sol" ;;
        "SuperLedger") echo "src/accounting/SuperLedger.sol" ;;
        "FlatFeeLedger") echo "src/accounting/FlatFeeLedger.sol" ;;
        "SuperLedgerConfiguration") echo "src/accounting/SuperLedgerConfiguration.sol" ;;
        "SuperValidator") echo "src/validators/SuperValidator.sol" ;;
        "SuperDestinationValidator") echo "src/validators/SuperDestinationValidator.sol" ;;
        "SuperNativePaymaster") echo "src/paymaster/SuperNativePaymaster.sol" ;;
        "SuperSenderCreator") echo "src/executors/helpers/SuperSenderCreator.sol" ;;
        
        # Hooks - ERC20 and Token Transfers
        "ApproveERC20Hook") echo "src/hooks/tokens/erc20/ApproveERC20Hook.sol" ;;
        "TransferERC20Hook") echo "src/hooks/tokens/erc20/TransferERC20Hook.sol" ;;
        "TransferHook") echo "src/hooks/tokens/TransferHook.sol" ;;
        "BatchTransferHook") echo "src/hooks/tokens/BatchTransferHook.sol" ;;
        "BatchTransferFromHook") echo "src/hooks/tokens/permit2/BatchTransferFromHook.sol" ;;
        "OfframpTokensHook") echo "src/hooks/tokens/OfframpTokensHook.sol" ;;
        
        # Hooks - Vaults
        "Deposit4626VaultHook") echo "src/hooks/vaults/4626/Deposit4626VaultHook.sol" ;;
        "ApproveAndDeposit4626VaultHook") echo "src/hooks/vaults/4626/ApproveAndDeposit4626VaultHook.sol" ;;
        "Redeem4626VaultHook") echo "src/hooks/vaults/4626/Redeem4626VaultHook.sol" ;;
        "Deposit5115VaultHook") echo "src/hooks/vaults/5115/Deposit5115VaultHook.sol" ;;
        "ApproveAndDeposit5115VaultHook") echo "src/hooks/vaults/5115/ApproveAndDeposit5115VaultHook.sol" ;;
        "Redeem5115VaultHook") echo "src/hooks/vaults/5115/Redeem5115VaultHook.sol" ;;
        "RequestDeposit7540VaultHook") echo "src/hooks/vaults/7540/RequestDeposit7540VaultHook.sol" ;;
        "ApproveAndRequestDeposit7540VaultHook") echo "src/hooks/vaults/7540/ApproveAndRequestDeposit7540VaultHook.sol" ;;
        "Deposit7540VaultHook") echo "src/hooks/vaults/7540/Deposit7540VaultHook.sol" ;;
        "Redeem7540VaultHook") echo "src/hooks/vaults/7540/Redeem7540VaultHook.sol" ;;
        "RequestRedeem7540VaultHook") echo "src/hooks/vaults/7540/RequestRedeem7540VaultHook.sol" ;;
        "CancelDepositRequest7540Hook") echo "src/hooks/vaults/7540/CancelDepositRequest7540Hook.sol" ;;
        "CancelRedeemRequest7540Hook") echo "src/hooks/vaults/7540/CancelRedeemRequest7540Hook.sol" ;;
        "ClaimCancelDepositRequest7540Hook") echo "src/hooks/vaults/7540/ClaimCancelDepositRequest7540Hook.sol" ;;
        "ClaimCancelRedeemRequest7540Hook") echo "src/hooks/vaults/7540/ClaimCancelRedeemRequest7540Hook.sol" ;;
        "SetOperator7540Hook") echo "src/hooks/vaults/7540/SetOperator7540Hook.sol" ;;
        "SetSlippageHook") echo "src/hooks/vaults/7540/SetSlippageHook.sol" ;;

        # Hooks - Swappers
        "Swap1InchHook") echo "src/hooks/swappers/1inch/Swap1InchHook.sol" ;;
        "SwapOdosV2Hook") echo "src/hooks/swappers/odos/SwapOdosV2Hook.sol" ;;
        "ApproveAndSwapOdosV2Hook") echo "src/hooks/swappers/odos/ApproveAndSwapOdosV2Hook.sol" ;;
        "SwapOdosV3Hook") echo "src/hooks/swappers/odos/SwapOdosV3Hook.sol" ;;
        "ApproveAndSwapOdosV3Hook") echo "src/hooks/swappers/odos/ApproveAndSwapOdosV3Hook.sol" ;;
        "SwapUniswapV3Hook") echo "src/hooks/swappers/uniswap-v3/SwapUniswapV3Hook.sol" ;;
        "ApproveAndSwapUniswapV3Hook") echo "src/hooks/swappers/uniswap-v3/ApproveAndSwapUniswapV3Hook.sol" ;;
        "SwapUniswapV4Hook") echo "src/hooks/swappers/uniswap-v4/SwapUniswapV4Hook.sol" ;;
        "PendleUnifiedHook") echo "src/hooks/swappers/pendle/PendleUnifiedHook.sol" ;;
        "PendleRouterSwapHook") echo "src/hooks/swappers/pendle/PendleRouterSwapHook.sol" ;;
        "PendleRouterRedeemHook") echo "src/hooks/swappers/pendle/PendleRouterRedeemHook.sol" ;;
        
        # Hooks - Bridges
        "AcrossSendFundsAndExecuteOnDstHook") echo "src/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHook.sol" ;;
        "ApproveAndAcrossSendFundsAndExecuteOnDstHook") echo "src/hooks/bridges/across/ApproveAndAcrossSendFundsAndExecuteOnDstHook.sol" ;;
        "DeBridgeSendOrderAndExecuteOnDstHook") echo "src/hooks/bridges/debridge/DeBridgeSendOrderAndExecuteOnDstHook.sol" ;;
        "DeBridgeCancelOrderHook") echo "src/hooks/bridges/debridge/DeBridgeCancelOrderHook.sol" ;;
        
        # Hooks - Protocol Specific
        "EthenaCooldownSharesHook") echo "src/hooks/vaults/ethena/EthenaCooldownSharesHook.sol" ;;
        "EthenaUnstakeHook") echo "src/hooks/vaults/ethena/EthenaUnstakeHook.sol" ;;
        "MarkRootAsUsedHook") echo "src/hooks/superform/MarkRootAsUsedHook.sol" ;;

        # Hooks - Claim
        "MerklClaimRewardHook") echo "src/hooks/claim/merkl/MerklClaimRewardHook.sol" ;;

        # Hooks - Circle Gateway
        "CircleGatewayWalletHook") echo "src/hooks/bridges/circle/CircleGatewayWalletHook.sol" ;;
        "CircleGatewayMinterHook") echo "src/hooks/bridges/circle/CircleGatewayMinterHook.sol" ;;
        "CircleGatewayAddDelegateHook") echo "src/hooks/bridges/circle/CircleGatewayAddDelegateHook.sol" ;;
        "CircleGatewayRemoveDelegateHook") echo "src/hooks/bridges/circle/CircleGatewayRemoveDelegateHook.sol" ;;

        # Hooks - Pendle PT Amortized Oracle
        "RecordPurchasePendlePTAmortizedOracleHook") echo "src/hooks/oracles/pendle/RecordPurchasePendlePTAmortizedOracleHook.sol" ;;
        "RecordRedemptionPendlePTAmortizedOracleHook") echo "src/hooks/oracles/pendle/RecordRedemptionPendlePTAmortizedOracleHook.sol" ;;
        "RecordPurchasePendlePTAmortizedOracleHookV2") echo "src/hooks/oracles/pendle/RecordPurchasePendlePTAmortizedOracleHookV2.sol" ;;
        "RecordRedemptionPendlePTAmortizedOracleHookV2") echo "src/hooks/oracles/pendle/RecordRedemptionPendlePTAmortizedOracleHookV2.sol" ;;

        # Hooks - Firelight Vault
        "RedeemFirelightVaultHook") echo "src/hooks/vaults/firelight/RedeemFirelightVaultHook.sol" ;;
        "ClaimWithdrawFirelightVaultHook") echo "src/hooks/vaults/firelight/ClaimWithdrawFirelightVaultHook.sol" ;;

        # Hooks - Morpho Loan
        "MorphoSupplyAndBorrowHook") echo "src/hooks/loan/morpho/MorphoSupplyAndBorrowHook.sol" ;;
        "MorphoBorrowHook") echo "src/hooks/loan/morpho/MorphoBorrowHook.sol" ;;
        "MorphoRepayHook") echo "src/hooks/loan/morpho/MorphoRepayHook.sol" ;;
        "MorphoRepayAndWithdrawHook") echo "src/hooks/loan/morpho/MorphoRepayAndWithdrawHook.sol" ;;
        "MorphoSupplyHook") echo "src/hooks/loan/morpho/MorphoSupplyHook.sol" ;;
        "MorphoWithdrawHook") echo "src/hooks/loan/morpho/MorphoWithdrawHook.sol" ;;
        "MorphoLendHook") echo "src/hooks/loan/morpho/MorphoLendHook.sol" ;;

        # Oracles
        "ERC4626YieldSourceOracle") echo "src/accounting/oracles/ERC4626YieldSourceOracle.sol" ;;
        "ERC5115YieldSourceOracle") echo "src/accounting/oracles/ERC5115YieldSourceOracle.sol" ;;
        "PendlePTYieldSourceOracle") echo "src/accounting/oracles/PendlePTYieldSourceOracle.sol" ;;
        "SpectraPTYieldSourceOracle") echo "src/accounting/oracles/SpectraPTYieldSourceOracle.sol" ;;
        "StakingYieldSourceOracle") echo "src/accounting/oracles/StakingYieldSourceOracle.sol" ;;
        "SuperYieldSourceOracle") echo "src/accounting/oracles/SuperYieldSourceOracle.sol" ;;
        "SuperVaultYieldSourceOracle") echo "src/accounting/oracles/SuperVaultYieldSourceOracle.sol" ;;
        
        *) echo "src/core/unknown/$contract_name.sol" ;;
    esac
}

# Function to verify a single contract
verify_contract() {
    local chain_id=$1
    local contract_name=$2
    local contract_address=$3
    local constructor_args=$4
    local source_file=$5
    local rpc_url=$6

    echo -e "${YELLOW}   🔍 Verifying $contract_name...${NC}"
    echo -e "${CYAN}      Address: $contract_address${NC}"
    echo -e "${CYAN}      Source: $source_file${NC}"
    echo -e "${CYAN}      Chain ID: $chain_id${NC}"

    forge verify-contract "$contract_address" "$source_file:$contract_name" \
        --constructor-args "$constructor_args" \
        --rpc-url "$rpc_url" \
        --chain "$chain_id" \
        --etherscan-api-key "$ETHERSCANV2_API_KEY" \
        --verifier etherscan

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}   ✅ $contract_name verified successfully${NC}"
    else
        echo -e "${RED}   ❌ $contract_name verification failed${NC}"
    fi

    echo ""
}

# Function to verify all contracts for a network
verify_network() {
    local chain_id=$1
    
    # Get network name and RPC URL from loaded configuration
    local network_name=$(get_network_name "$chain_id")
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Unknown network ID: $chain_id${NC}"
        return 1
    fi
    
    local rpc_url=$(get_rpc_url "$chain_id")
    if [ -z "$rpc_url" ]; then
        echo -e "${RED}❌ RPC URL not found for chain $chain_id${NC}"
        return 1
    fi
    
    print_network_header "$network_name"
    echo -e "${CYAN}   Chain ID: ${WHITE}$chain_id${NC}"
    echo -e "${CYAN}   RPC URL: ${WHITE}$rpc_url${NC}"
    echo -e "${CYAN}   Verification: ${WHITE}Etherscan V2${NC}"
    
    if ! load_contract_addresses "$chain_id"; then
        echo -e "${RED}   ❌ Failed to load contract addresses for chain $chain_id${NC}"
        return 1
    fi
    
    echo -e "${CYAN}   📋 Starting contract verification...${NC}"
    
    # Get network suffix for JSON file
    local network_suffix=""
    case $chain_id in
        "1") network_suffix="Ethereum-latest" ;;
        "8453") network_suffix="Base-latest" ;;
        "56") network_suffix="BNB-latest" ;;
        "42161") network_suffix="Arbitrum-latest" ;;
        "10") network_suffix="Optimism-latest" ;;
        "137") network_suffix="Polygon-latest" ;;
        "130") network_suffix="Unichain-latest" ;;
        "59144") network_suffix="Linea-latest" ;;
        "43114") network_suffix="Avalanche-latest" ;;
        "80094") network_suffix="Berachain-latest" ;;
        "146") network_suffix="Sonic-latest" ;;
        "100") network_suffix="Gnosis-latest" ;;
        "480") network_suffix="Worldchain-latest" ;;
        "999") network_suffix="HyperEVM-latest" ;;
        "14") network_suffix="Flare-latest" ;;
        *) network_suffix="${network_name}-latest" ;;
    esac

    local json_file="script/output/$ENVIRONMENT/$chain_id/$network_suffix.json"

    if [ ! -f "$json_file" ]; then
        echo -e "${RED}   ❌ Contract addresses file not found: $json_file${NC}"
        return 1
    fi
    
    # Extract contract names from JSON
    local all_contract_names=($(jq -r 'keys[]' "$json_file"))
    local contract_names=()
    
    # Apply contract filter if specified
    if [ ${#CONTRACTS_TO_VERIFY[@]} -eq 0 ]; then
        # No filter specified, use all contracts
        contract_names=("${all_contract_names[@]}")
        echo -e "${CYAN}   📋 No contract filter specified, verifying all deployed contracts...${NC}"
    else
        # Use filtered contracts
        echo -e "${CYAN}   📋 Contract filter active, verifying only specified contracts...${NC}"
        echo -e "${CYAN}      Filtered contracts: ${CONTRACTS_TO_VERIFY[*]}${NC}"
        for contract_name in "${CONTRACTS_TO_VERIFY[@]}"; do
            # Check if the contract exists in the deployed contracts
            local found=false
            for deployed_contract in "${all_contract_names[@]}"; do
                if [ "$deployed_contract" = "$contract_name" ]; then
                    contract_names+=("$contract_name")
                    found=true
                    break
                fi
            done
            if [ "$found" = false ]; then
                echo -e "${YELLOW}      ⚠️  Warning: Contract $contract_name not found in deployment, skipping...${NC}"
            fi
        done
    fi
    
    echo -e "${CYAN}   📋 Verifying ${#contract_names[@]} contracts...${NC}"
    
    for contract_name in "${contract_names[@]}"; do
        local contract_address=$(get_contract_address "$chain_id" "$contract_name")
        
        if [ -z "$contract_address" ] || [ "$contract_address" = "null" ]; then
            echo -e "${YELLOW}   ⚠️  Skipping $contract_name (address not found)${NC}"
            continue
        fi
        
        local constructor_args=$(generate_constructor_args "$contract_name" "$chain_id")
        local source_file=$(get_contract_source "$contract_name")
        
        verify_contract "$chain_id" "$contract_name" "$contract_address" "$constructor_args" "$source_file" "$rpc_url"

        # Rate limit protection: wait between verification requests
        if [ "$VERIFY_DELAY" -gt 0 ]; then
            sleep "$VERIFY_DELAY"
        fi
    done
    
    echo -e "${GREEN}✅ Network $network_name verification completed${NC}"
}

# Main verification loop
main() {
    # Get chain IDs from the loaded network configuration or use filter
    local chains=()
    
    if [ ${#CHAINS_TO_VERIFY[@]} -eq 0 ]; then
        # No filter specified, use all chains from network configuration
        echo -e "${CYAN}📋 No chain filter specified, verifying all configured networks...${NC}"
        for network_def in "${NETWORKS[@]}"; do
            IFS=':' read -r network_id _ _ <<< "$network_def"
            chains+=("$network_id")
        done
    else
        # Use filtered chains
        echo -e "${CYAN}📋 Chain filter active, verifying only specified chains...${NC}"
        for chain_id in "${CHAINS_TO_VERIFY[@]}"; do
            # Verify the chain exists in network configuration
            local found=false
            for network_def in "${NETWORKS[@]}"; do
                IFS=':' read -r network_id _ _ <<< "$network_def"
                if [ "$network_id" = "$chain_id" ]; then
                    chains+=("$chain_id")
                    found=true
                    break
                fi
            done
            if [ "$found" = false ]; then
                echo -e "${YELLOW}⚠️  Warning: Chain $chain_id not found in network configuration, skipping...${NC}"
            fi
        done
    fi
    
    echo -e "${BLUE}🔍 Starting verification for ${#chains[@]} networks in $ENVIRONMENT environment...${NC}"
    if [ ${#CHAINS_TO_VERIFY[@]} -gt 0 ]; then
        echo -e "${CYAN}   Filtered chains: ${CHAINS_TO_VERIFY[*]}${NC}"
    fi
    if [ ${#CONTRACTS_TO_VERIFY[@]} -gt 0 ]; then
        echo -e "${CYAN}   Filtered contracts: ${CONTRACTS_TO_VERIFY[*]}${NC}"
    fi
    echo ""
    
    local successful_networks=0
    local failed_networks=0
    
    for chain_id in "${chains[@]}"; do
        if verify_network "$chain_id"; then
            ((successful_networks++))
        else
            ((failed_networks++))
        fi
        print_separator
    done
    
    echo -e "${BLUE}📊 Verification Summary:${NC}"
    echo -e "${GREEN}   • Networks verified successfully: $successful_networks${NC}"
    if [ $failed_networks -gt 0 ]; then
        echo -e "${RED}   • Networks with verification failures: $failed_networks${NC}"
    fi
    echo ""
    
    if [ $failed_networks -eq 0 ]; then
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                                                                                      ║${NC}"
        echo -e "${GREEN}║${WHITE}            🎉 All V2 Core $ENVIRONMENT Contract Verification Completed! 🎉             ${GREEN}║${NC}"
        echo -e "${GREEN}║                                                                                      ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    else
        echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║                                                                                      ║${NC}"
        echo -e "${YELLOW}║${WHITE}               ⚠️  V2 Core $ENVIRONMENT Verification Completed with Issues ⚠️               ${YELLOW}║${NC}"
        echo -e "${YELLOW}║                                                                                      ║${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
        exit 1
    fi
}

# Run the main function
main 