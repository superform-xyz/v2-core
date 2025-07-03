#!/bin/bash

# Production RPC URLs
export BASE_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_RPC_URL/credential)
export BSC_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BSC_RPC_URL/credential)
export ARBITRUM_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/ARBITRUM_RPC_URL/credential)

# Etherscan API Keys for verification
export BASESCAN_API_KEY=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASESCAN_API_KEY/credential)
export BSCSCAN_API_KEY=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BSCSCAN_API_KEY/credential)
export ARBISCAN_API_KEY=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/ARBISCAN_API_KEY/credential)

# Deployment parameters
FORGE_ENV=0

echo "Deploy V2 Core on Base Mainnet: ..."
forge script script/DeployV2Core.s.sol:DeployV2Core \
    --sig 'run(uint256,uint64)' $FORGE_ENV 8453 \
    --account v2 \
    --rpc-url $BASE_MAINNET \
    --chain 8453 \
    --etherscan-api-key $BASESCAN_API_KEY \
    --verify \
    --slow \
    -vv
wait

echo "Deploy V2 Core on BSC Mainnet: ..."
forge script script/DeployV2Core.s.sol:DeployV2Core \
    --sig 'run(uint256,uint64)' $FORGE_ENV 56 \
    --account v2 \
    --rpc-url $BSC_MAINNET \
    --chain 56 \
    --etherscan-api-key $BSCSCAN_API_KEY \
    --verify \
    --slow \
    -vv
wait

echo "Deploy V2 Core on Arbitrum Mainnet: ..."
forge script script/DeployV2Core.s.sol:DeployV2Core \
    --sig 'run(uint256,uint64)' $FORGE_ENV 42161 \
    --account v2 \
    --rpc-url $ARBITRUM_MAINNET \
    --chain 42161 \
    --etherscan-api-key $ARBISCAN_API_KEY \
    --verify \
    --slow \
    -vv
wait

echo "All V2 Core production deployments completed!" 