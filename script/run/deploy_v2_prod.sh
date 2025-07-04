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
    echo -e "${CYAN}║${WHITE}                          🚀 V2 Core Production Deployment Script 🚀                 ${CYAN}║${NC}"
    echo -e "${CYAN}║                                                                                      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
}

# Function to print section separator
print_separator() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to print network deployment header
print_network_header() {
    local network=$1
    echo -e "${PURPLE}╭─────────────────────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}│${WHITE}                           🌐 Deploying to ${network} Network 🌐                          ${PURPLE}│${NC}"
    echo -e "${PURPLE}╰─────────────────────────────────────────────────────────────────────────────────────╯${NC}"
}

print_header

# Check if mode argument is provided
if [ $# -eq 0 ]; then
    echo -e "${RED}❌ Error: No mode specified${NC}"
    echo -e "${YELLOW}Usage: $0 [simulate|deploy]${NC}"
    echo -e "${CYAN}  simulate: Run without --verify and --broadcast (simulation mode)${NC}"
    echo -e "${CYAN}  deploy: Run with --verify and --broadcast (deployment mode)${NC}"
    exit 1
fi

MODE=$1

# Set flags based on mode
if [ "$MODE" = "simulate" ]; then
    echo -e "${YELLOW}🔍 Running in simulation mode...${NC}"
    echo -e "${CYAN}   - No broadcasting to network${NC}"
    echo -e "${CYAN}   - No contract verification${NC}"
    BROADCAST_FLAG=""
    VERIFY_FLAG=""
elif [ "$MODE" = "deploy" ]; then
    echo -e "${GREEN}🚀 Running in deployment mode...${NC}"
    echo -e "${CYAN}   - Broadcasting to network${NC}"
    echo -e "${CYAN}   - Contract verification enabled${NC}"
    BROADCAST_FLAG="--broadcast"
    VERIFY_FLAG="--verify"
else
    echo -e "${RED}❌ Invalid mode: $MODE${NC}"
    echo -e "${YELLOW}Usage: $0 [simulate|deploy]${NC}"
    exit 1
fi

print_separator
echo -e "${BLUE}🔧 Loading Configuration...${NC}"

# Production RPC URLs
echo -e "${CYAN}   • Loading RPC URLs...${NC}"
export BASE_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_RPC_URL/credential)
export BSC_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BSC_RPC_URL/credential)
export ARBITRUM_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/ARBITRUM_RPC_URL/credential)

# Etherscan API Keys for verification
echo -e "${CYAN}   • Loading Etherscan API keys...${NC}"
export ETHERSCAN_V2_API_KEY=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/ETHERSCANV2_API_KEY_TEST/credential)

# Deployment parameters
FORGE_ENV=0

echo -e "${GREEN}✅ Configuration loaded successfully${NC}"
print_separator

print_network_header "BASE MAINNET"
echo -e "${CYAN}   Chain ID: ${WHITE}8453${NC}"
echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
echo -e "${YELLOW}   Executing forge script...${NC}"

forge script script/DeployV2Core.s.sol:DeployV2Core \
    --sig 'run(uint256,uint64)' $FORGE_ENV 8453 \
    --account v2 \
    --rpc-url $BASE_MAINNET \
    --chain 8453 \
    --etherscan-api-key $ETHERSCAN_V2_API_KEY \
    $BROADCAST_FLAG \
    $VERIFY_FLAG \
    --slow \
    -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Base Mainnet deployment completed successfully!${NC}"
else
    echo -e "${RED}❌ Base Mainnet deployment failed!${NC}"
    exit 1
fi
wait

print_network_header "BSC MAINNET"
echo -e "${CYAN}   Chain ID: ${WHITE}56${NC}"
echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
echo -e "${YELLOW}   Executing forge script...${NC}"

forge script script/DeployV2Core.s.sol:DeployV2Core \
    --sig 'run(uint256,uint64)' $FORGE_ENV 56 \
    --account v2 \
    --rpc-url $BSC_MAINNET \
    --chain 56 \
    --etherscan-api-key $ETHERSCAN_V2_API_KEY \
    $BROADCAST_FLAG \
    $VERIFY_FLAG \
    --slow \
    -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ BSC Mainnet deployment completed successfully!${NC}"
else
    echo -e "${RED}❌ BSC Mainnet deployment failed!${NC}"
    exit 1
fi
wait

print_network_header "ARBITRUM MAINNET"
echo -e "${CYAN}   Chain ID: ${WHITE}42161${NC}"
echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
echo -e "${YELLOW}   Executing forge script...${NC}"

forge script script/DeployV2Core.s.sol:DeployV2Core \
    --sig 'run(uint256,uint64)' $FORGE_ENV 42161 \
    --account v2 \
    --rpc-url $ARBITRUM_MAINNET \
    --chain 42161 \
    --etherscan-api-key $ETHERSCAN_V2_API_KEY \
    $BROADCAST_FLAG \
    $VERIFY_FLAG \
    --slow \
    -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Arbitrum Mainnet deployment completed successfully!${NC}"
else
    echo -e "${RED}❌ Arbitrum Mainnet deployment failed!${NC}"
    exit 1
fi
wait

print_separator
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                                                      ║${NC}"
echo -e "${GREEN}║${WHITE}                    🎉 All V2 Core Production $MODE Operations Completed! 🎉                ${GREEN}║${NC}"
echo -e "${GREEN}║                                                                                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
print_separator 