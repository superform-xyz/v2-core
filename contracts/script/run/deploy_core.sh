#!/usr/bin/env bash
# Note: How to set defaultKey - https://www.youtube.com/watch?v=VQe7cIpaE54

export SUPER_THAI_RPC_URL=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/SUPER_THAI_RPC_URL/credential)
export SUPER_CHAIN_RPC_URL=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/SUPER_CHAIN_RPC_URL/credential)

# Run the script

echo Deploy create3 factory on Super Thai: ...
FOUNDRY_PROFILE=production forge script script/DeployV2Core.s.sol:DeployV2Core --sig "deploy(uint64)" 0 --rpc-url $SUPER_THAI_RPC_URL --slow --account default --unlocked --sender 0x0000000000000000000000000000000000000000

wait

echo Deploy create3 factory on Super Chain: ...
FOUNDRY_PROFILE=production forge script script/DeployV2Core.s.sol:DeployV2Core --sig "deploy(uint64)" 1 --rpc-url $SUPER_CHAIN_RPC_URL --slow --account default --unlocked --sender 0x0000000000000000000000000000000000000000

wait
