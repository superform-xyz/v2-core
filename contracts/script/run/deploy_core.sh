#!/usr/bin/env bash
# Note: How to set defaultKey - https://www.youtube.com/watch?v=VQe7cIpaE54

export BASE_SEPOLIA_RPC_URL=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_SEPOLIA_RPC_URL/credential)
export SUPER_CHAIN_RPC_URL=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/SUPER_CHAIN_RPC_URL/credential)

export TENDERLY_SUPER_THAI_PROJ_API_KEY=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/TENDERLY_SUPER_THAI_PROJ_API_KEY/credential)

export BASE_SEPOLIA_VERIFIER_URL=https://api.tenderly.co/api/v1/account/superform/project/superthai/etherscan/verify/network/84532
export SUPER_CHAIN_VERIFIER_URL=$SUPER_CHAIN_RPC_URL/verify/etherscan

# Run the script

echo Deploy create3 factory on BaseSepolia: ...
forge script script/DeployV2Core.s.sol:DeployV2Core --sig "deploy(uint64)" 0 \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --slow \
    --account default \
    --sender 0x48aB8AdF869Ba9902Ad483FB1Ca2eFDAb6eabe92 \
    --broadcast

wait

echo Deploy create3 factory on Super Chain: ...
forge script script/DeployV2Core.s.sol:DeployV2Core --sig "deploy(uint64)" 1 \
    --rpc-url $SUPER_CHAIN_RPC_URL \
    --slow \
    --account default \
    --sender 0x48aB8AdF869Ba9902Ad483FB1Ca2eFDAb6eabe92 \
    --etherscan-api-key $TENDERLY_SUPER_THAI_PROJ_API_KEY \
    --broadcast

wait
