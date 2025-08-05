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

# Tenderly configuration for verification
echo -e "${BLUE}🔧 Loading Tenderly Configuration...${NC}"
export TENDERLY_ACCESS_TOKEN=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/TENDERLY_ACCESS_KEY_V2/credential)
export TENDERLY_ACCOUNT="superform"
export TENDERLY_PROJECT="v2"

# Production RPC URLs
export ETH_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/ETHEREUM_RPC_URL/credential)
export BASE_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_RPC_URL/credential)
export BSC_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BSC_RPC_URL/credential)
export ARBITRUM_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/ARBITRUM_RPC_URL/credential)

# Tenderly verification URLs for each network
export ETH_VERIFIER_URL="https://api.tenderly.co/api/v1/account/$TENDERLY_ACCOUNT/project/$TENDERLY_PROJECT/etherscan/verify/network/1"
export BASE_VERIFIER_URL="https://api.tenderly.co/api/v1/account/$TENDERLY_ACCOUNT/project/$TENDERLY_PROJECT/etherscan/verify/network/8453"
export BSC_VERIFIER_URL="https://api.tenderly.co/api/v1/account/$TENDERLY_ACCOUNT/project/$TENDERLY_PROJECT/etherscan/verify/network/56"
export ARBITRUM_VERIFIER_URL="https://api.tenderly.co/api/v1/account/$TENDERLY_ACCOUNT/project/$TENDERLY_PROJECT/etherscan/verify/network/42161"

echo -e "${GREEN}✅ Tenderly configuration loaded${NC}"
echo -e "${CYAN}   • Using Tenderly private verification mode${NC}"
print_separator

# Network configurations
declare -A NETWORKS=(
    ["1"]="ETH_MAINNET"
    ["8453"]="BASE_MAINNET"
    ["56"]="BSC_MAINNET" 
    ["42161"]="ARBITRUM_MAINNET"
)

declare -A RPC_URLS=(
    ["1"]="$ETH_MAINNET"
    ["8453"]="$BASE_MAINNET"
    ["56"]="$BSC_MAINNET"
    ["42161"]="$ARBITRUM_MAINNET"
)

declare -A VERIFIER_URLS=(
    ["1"]="$ETH_VERIFIER_URL"
    ["8453"]="$BASE_VERIFIER_URL"
    ["56"]="$BSC_VERIFIER_URL"
    ["42161"]="$ARBITRUM_VERIFIER_URL"
)

declare -A NETWORK_NAMES=(
    ["1"]="Ethereum Mainnet"
    ["8453"]="Base Mainnet"
    ["56"]="BSC Mainnet"
    ["42161"]="Arbitrum Mainnet"
)

# Function to load contract addresses from JSON
load_contract_addresses() {
    local chain_id=$1
    local network_name=""
    
    case $chain_id in
        "1") network_name="Ethereum-latest" ;;
        "8453") network_name="BASE-latest" ;;
        "56") network_name="BNB-latest" ;;
        "42161") network_name="ARBITRUM-latest" ;;
    esac
    
    local json_file="script/output/prod/$chain_id/$network_name.json"
    
    if [ ! -f "$json_file" ]; then
        echo -e "${RED}❌ JSON file not found: $json_file${NC}"
        return 1
    fi
    
    echo -e "${CYAN}   • Loading addresses from: $json_file${NC}"
    return 0
}

# Function to get contract address from JSON
get_contract_address() {
    local chain_id=$1
    local contract_name=$2
    local network_name=""
    
    case $chain_id in
        "1") network_name="Ethereum-latest" ;;
        "8453") network_name="BASE-latest" ;;
        "56") network_name="BNB-latest" ;;
        "42161") network_name="ARBITRUM-latest" ;;
    esac
    
    local json_file="script/output/prod/$chain_id/$network_name.json"
    
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
    local debridge_dst_dln=""
    local merkl_distributor=""
    local entry_point="0x0000000071727De22E5E9d8BAf0edAc6f37da032"  # EntryPoint v0.7
    local debridge_dln_src="0xeF4fB24aD0916217251F553c0596F8Edc630EB66"  # Standard DeBridge DLN SRC
    local debridge_dln_dst="0xE7351Fd770A37282b91D153Ee690B63579D6dd7f"  # Standard DeBridge DLN DST
    
    # Network-specific configurations
    case $chain_id in
        "1") # Ethereum Mainnet
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router="0x111111125421cA6dc452d289314280a0f8842A65"  # 1inch
            odos_router="0xcf5540fFFCdC3d510B18bFcA6d2b9987b0772559"
            across_spoke_pool_v3="0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5"
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            ;;
        "8453") # Base Mainnet
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router="0x111111125421cA6dc452d289314280a0f8842A65"  # 1inch
            odos_router="0x19cEeAd7105607Cd444F5ad10dd51356436095a1"
            across_spoke_pool_v3="0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64"
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            ;;
        "56") # BSC Mainnet
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router="0x111111125421cA6dc452d289314280a0f8842A65"  # 1inch
            odos_router="0x89b8AA89FDd0507a99d334CBe3C808fAFC7d850E"
            across_spoke_pool_v3="0x4e8E101924eDE233C13e2D8622DC8aED2872d505"
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            ;;
        "42161") # Arbitrum Mainnet
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router="0x111111125421cA6dc452d289314280a0f8842A65"  # 1inch
            odos_router="0xa32EE1C40594249eb3183c10792BcF573D4Da47C"
            across_spoke_pool_v3="0xe35e9842fceaCA96570B734083f4a58e8F7C5f2A"
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
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
            echo "$(cast abi-encode "constructor(address)" "$merkl_distributor")"
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
        "SuperExecutor") echo "src/core/executors/SuperExecutor.sol" ;;
        "SuperDestinationExecutor") echo "src/core/executors/SuperDestinationExecutor.sol" ;;
        "AcrossV3Adapter") echo "src/core/adapters/AcrossV3Adapter.sol" ;;
        "DebridgeAdapter") echo "src/core/adapters/DebridgeAdapter.sol" ;;
        "SuperLedger") echo "src/core/accounting/SuperLedger.sol" ;;
        "FlatFeeLedger") echo "src/core/accounting/FlatFeeLedger.sol" ;;
        "SuperLedgerConfiguration") echo "src/core/accounting/SuperLedgerConfiguration.sol" ;;
        "SuperValidator") echo "src/core/validators/SuperValidator.sol" ;;
        "SuperDestinationValidator") echo "src/core/validators/SuperDestinationValidator.sol" ;;
        "SuperNativePaymaster") echo "src/core/paymaster/SuperNativePaymaster.sol" ;;
        
        # Hooks - ERC20
        "ApproveERC20Hook") echo "src/core/hooks/tokens/erc20/ApproveERC20Hook.sol" ;;
        "TransferERC20Hook") echo "src/core/hooks/tokens/erc20/TransferERC20Hook.sol" ;;
        "BatchTransferHook") echo "src/core/hooks/tokens/BatchTransferHook.sol" ;;
        "BatchTransferFromHook") echo "src/core/hooks/tokens/permit2/BatchTransferFromHook.sol" ;;
        "OfframpTokensHook") echo "src/core/hooks/tokens/OfframpTokensHook.sol" ;;
        
        # Hooks - Vaults
        "Deposit4626VaultHook") echo "src/core/hooks/vaults/4626/Deposit4626VaultHook.sol" ;;
        "ApproveAndDeposit4626VaultHook") echo "src/core/hooks/vaults/4626/ApproveAndDeposit4626VaultHook.sol" ;;
        "Redeem4626VaultHook") echo "src/core/hooks/vaults/4626/Redeem4626VaultHook.sol" ;;
        "Deposit5115VaultHook") echo "src/core/hooks/vaults/5115/Deposit5115VaultHook.sol" ;;
        "ApproveAndDeposit5115VaultHook") echo "src/core/hooks/vaults/5115/ApproveAndDeposit5115VaultHook.sol" ;;
        "Redeem5115VaultHook") echo "src/core/hooks/vaults/5115/Redeem5115VaultHook.sol" ;;
        "RequestDeposit7540VaultHook") echo "src/core/hooks/vaults/7540/RequestDeposit7540VaultHook.sol" ;;
        "ApproveAndRequestDeposit7540VaultHook") echo "src/core/hooks/vaults/7540/ApproveAndRequestDeposit7540VaultHook.sol" ;;
        "ApproveAndRequestRedeem7540VaultHook") echo "src/core/hooks/vaults/7540/ApproveAndRequestRedeem7540VaultHook.sol" ;;
        "Deposit7540VaultHook") echo "src/core/hooks/vaults/7540/Deposit7540VaultHook.sol" ;;
        "Redeem7540VaultHook") echo "src/core/hooks/vaults/7540/Redeem7540VaultHook.sol" ;;
        "RequestRedeem7540VaultHook") echo "src/core/hooks/vaults/7540/RequestRedeem7540VaultHook.sol" ;;
        "CancelDepositRequest7540Hook") echo "src/core/hooks/vaults/7540/CancelDepositRequest7540Hook.sol" ;;
        "CancelRedeemRequest7540Hook") echo "src/core/hooks/vaults/7540/CancelRedeemRequest7540Hook.sol" ;;
        "ClaimCancelDepositRequest7540Hook") echo "src/core/hooks/vaults/7540/ClaimCancelDepositRequest7540Hook.sol" ;;
        "ClaimCancelRedeemRequest7540Hook") echo "src/core/hooks/vaults/7540/ClaimCancelRedeemRequest7540Hook.sol" ;;
        
        # Hooks - Swappers
        "Swap1InchHook") echo "src/core/hooks/swappers/1inch/Swap1InchHook.sol" ;;
        "SwapOdosV2Hook") echo "src/core/hooks/swappers/odos/SwapOdosV2Hook.sol" ;;
        "ApproveAndSwapOdosV2Hook") echo "src/core/hooks/swappers/odos/ApproveAndSwapOdosV2Hook.sol" ;;
        
        # Hooks - Bridges
        "AcrossSendFundsAndExecuteOnDstHook") echo "src/core/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHook.sol" ;;
        "DeBridgeSendOrderAndExecuteOnDstHook") echo "src/core/hooks/bridges/debridge/DeBridgeSendOrderAndExecuteOnDstHook.sol" ;;
        "DeBridgeCancelOrderHook") echo "src/core/hooks/bridges/debridge/DeBridgeCancelOrderHook.sol" ;;
        
        # Hooks - Protocol Specific
        "EthenaCooldownSharesHook") echo "src/core/hooks/vaults/ethena/EthenaCooldownSharesHook.sol" ;;
        "EthenaUnstakeHook") echo "src/core/hooks/vaults/ethena/EthenaUnstakeHook.sol" ;;
        
        # Hooks - Claim
        "MerklClaimRewardHook") echo "src/core/hooks/claim/merkl/MerklClaimRewardHook.sol" ;;
        
        # Oracles
        "ERC4626YieldSourceOracle") echo "src/core/accounting/oracles/ERC4626YieldSourceOracle.sol" ;;
        "ERC5115YieldSourceOracle") echo "src/core/accounting/oracles/ERC5115YieldSourceOracle.sol" ;;
        "ERC7540YieldSourceOracle") echo "src/core/accounting/oracles/ERC7540YieldSourceOracle.sol" ;;
        "PendlePTYieldSourceOracle") echo "src/core/accounting/oracles/PendlePTYieldSourceOracle.sol" ;;
        "SpectraPTYieldSourceOracle") echo "src/core/accounting/oracles/SpectraPTYieldSourceOracle.sol" ;;
        "StakingYieldSourceOracle") echo "src/core/accounting/oracles/StakingYieldSourceOracle.sol" ;;
        "SuperYieldSourceOracle") echo "src/core/accounting/oracles/SuperYieldSourceOracle.sol" ;;
        
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
    local verifier_url=$7
    
    echo -e "${YELLOW}   🔍 Verifying $contract_name...${NC}"
    echo -e "${CYAN}      Address: $contract_address${NC}"
    echo -e "${CYAN}      Source: $source_file${NC}"
    
    forge verify-contract "$contract_address" "$source_file:$contract_name" \
        --constructor-args "$constructor_args" \
        --rpc-url "$rpc_url" \
        --verifier-url "$verifier_url" \
        --etherscan-api-key "$TENDERLY_ACCESS_TOKEN" 
            
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
    local network_name=${NETWORK_NAMES[$chain_id]}
    local rpc_url=${RPC_URLS[$chain_id]}
    local verifier_url=${VERIFIER_URLS[$chain_id]}
    
    print_network_header "$network_name"
    echo -e "${CYAN}   Chain ID: ${WHITE}$chain_id${NC}"
    echo -e "${CYAN}   RPC URL: ${WHITE}$rpc_url${NC}"
    echo -e "${CYAN}   Verifier URL: ${WHITE}$verifier_url${NC}"
    
    if ! load_contract_addresses "$chain_id"; then
        echo -e "${RED}   ❌ Failed to load contract addresses for chain $chain_id${NC}"
        return 1
    fi
    
    echo -e "${CYAN}   📋 Starting contract verification...${NC}"
    
    # Get all contract names from the JSON file
    local network_suffix=""
    case $chain_id in
        "1") network_suffix="Ethereum-latest" ;;
        "8453") network_suffix="BASE-latest" ;;
        "56") network_suffix="BNB-latest" ;;  
        "42161") network_suffix="ARBITRUM-latest" ;;
    esac
    
    local json_file="script/output/prod/$chain_id/$network_suffix.json"
    
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
        
        verify_contract "$chain_id" "$contract_name" "$contract_address" "$constructor_args" "$source_file" "$rpc_url" "$verifier_url"
    done
    
    echo -e "${GREEN}✅ Network $network_name verification completed${NC}"
}

# Main verification loop
main() {
    local chains=("1" "8453" "56" "42161")
    
    for chain_id in "${chains[@]}"; do
        verify_network "$chain_id"
        print_separator
    done
    
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                                      ║${NC}"
    echo -e "${GREEN}║${WHITE}                🎉 All V2 Core Production Contract Verification Completed! 🎉         ${GREEN}║${NC}"
    echo -e "${GREEN}║                                                                                      ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
}

# Run the main function
main 