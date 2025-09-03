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
    local across_spoke_pool_v3=""
    local merkl_distributor=""
    local debridge_dst_dln="0xE7351Fd770A37282b91D153Ee690B63579D6dd7f"
    local entry_point="0x0000000071727De22E5E9d8BAf0edAc6f37da032"  # EntryPoint v0.7
    local debridge_dln_src="0xeF4fB24aD0916217251F553c0596F8Edc630EB66"  # Standard DeBridge DLN SRC
    local debridge_dln_dst="0xE7351Fd770A37282b91D153Ee690B63579D6dd7f"  # Standard DeBridge DLN DST
    local gateway_wallet="0x77777777Dcc4d5A8B6E418Fd04D8997ef11000eE"  # Circle Gateway Wallet
    local gateway_minter="0x2222222d7164433c4C09B0b0D809a9b52C04C205"  # Circle Gateway Minter
    
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
        "AcrossSendFundsAndExecuteOnDstHook")
            echo "$(cast abi-encode "constructor(address,address)" "$across_spoke_pool_v3" "$super_merkle_validator")"
            ;;
        "DeBridgeSendOrderAndExecuteOnDstHook")
            echo "$(cast abi-encode "constructor(address,address)" "$debridge_dln_src" "$super_merkle_validator")"
            ;;
        "DeBridgeCancelOrderHook")
            echo "$(cast abi-encode "constructor(address)" "$debridge_dln_dst")"
            ;;
        "MerklClaimRewardHook")
            echo "$(cast abi-encode "constructor(address,address,uint256)" "$merkl_distributor" "0x0E24b0F342F034446Ec814281AD1a7653cBd85e9" "100")"
            ;;
        "CircleGatewayWalletHook"|"CircleGatewayAddDelegateHook"|"CircleGatewayRemoveDelegateHook")
            echo "$(cast abi-encode "constructor(address)" "$gateway_wallet")"
            ;;
        "CircleGatewayMinterHook")
            echo "$(cast abi-encode "constructor(address)" "$gateway_minter")"
            ;;
        
        # Oracles with constructor args  
        "ERC4626YieldSourceOracle"|"ERC5115YieldSourceOracle"|"ERC7540YieldSourceOracle"|"PendlePTYieldSourceOracle"|"SpectraPTYieldSourceOracle"|"StakingYieldSourceOracle")
            echo "$(cast abi-encode "constructor(address)" "$super_ledger_config")"
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
        
        # Hooks - ERC20
        "ApproveERC20Hook") echo "src/hooks/tokens/erc20/ApproveERC20Hook.sol" ;;
        "TransferERC20Hook") echo "src/hooks/tokens/erc20/TransferERC20Hook.sol" ;;
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
        
        # Hooks - Swappers
        "Swap1InchHook") echo "src/hooks/swappers/1inch/Swap1InchHook.sol" ;;
        "SwapOdosV2Hook") echo "src/hooks/swappers/odos/SwapOdosV2Hook.sol" ;;
        "ApproveAndSwapOdosV2Hook") echo "src/hooks/swappers/odos/ApproveAndSwapOdosV2Hook.sol" ;;
        
        # Hooks - Bridges
        "AcrossSendFundsAndExecuteOnDstHook") echo "src/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHook.sol" ;;
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
        
        # Oracles
        "ERC4626YieldSourceOracle") echo "src/accounting/oracles/ERC4626YieldSourceOracle.sol" ;;
        "ERC5115YieldSourceOracle") echo "src/accounting/oracles/ERC5115YieldSourceOracle.sol" ;;
        "ERC7540YieldSourceOracle") echo "src/accounting/oracles/ERC7540YieldSourceOracle.sol" ;;
        "PendlePTYieldSourceOracle") echo "src/accounting/oracles/PendlePTYieldSourceOracle.sol" ;;
        "SpectraPTYieldSourceOracle") echo "src/accounting/oracles/SpectraPTYieldSourceOracle.sol" ;;
        "StakingYieldSourceOracle") echo "src/accounting/oracles/StakingYieldSourceOracle.sol" ;;
        "SuperYieldSourceOracle") echo "src/accounting/oracles/SuperYieldSourceOracle.sol" ;;
        
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
        --etherscan-api-key "$ETHERSCANV2_API_KEY_TEST" \
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
        *) network_suffix="${network_name}-latest" ;;
    esac
    
    local json_file="script/output/$ENVIRONMENT/$chain_id/$network_suffix.json"
    
    if [ ! -f "$json_file" ]; then
        echo -e "${RED}   ❌ Contract addresses file not found: $json_file${NC}"
        return 1
    fi
    
    # Extract contract names from JSON
    local contract_names=($(jq -r 'keys[]' "$json_file"))
    
    for contract_name in "${contract_names[@]}"; do
        local contract_address=$(get_contract_address "$chain_id" "$contract_name")
        
        if [ -z "$contract_address" ] || [ "$contract_address" = "null" ]; then
            echo -e "${YELLOW}   ⚠️  Skipping $contract_name (address not found)${NC}"
            continue
        fi
        
        local constructor_args=$(generate_constructor_args "$contract_name" "$chain_id")
        local source_file=$(get_contract_source "$contract_name")
        
        verify_contract "$chain_id" "$contract_name" "$contract_address" "$constructor_args" "$source_file" "$rpc_url"
    done
    
    echo -e "${GREEN}✅ Network $network_name verification completed${NC}"
}

# Main verification loop
main() {
    # Get chain IDs from the loaded network configuration
    local chains=()
    for network_def in "${NETWORKS[@]}"; do
        IFS=':' read -r network_id _ _ <<< "$network_def"
        chains+=("$network_id")
    done
    
    echo -e "${BLUE}🔍 Starting verification for ${#chains[@]} networks in $ENVIRONMENT environment...${NC}"
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