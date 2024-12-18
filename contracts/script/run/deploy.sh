# Note: How to set defaultKey - https://www.youtube.com/watch?v=VQe7cIpaE54

export TENDERLY_V2_CORE_INITIAL_API_KEY=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/TENDERLY_V2_CORE_INITIAL_API_KEY/credential)
export VIRTUAL_TESTNET_URL=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/VIRTUAL_TESTNET_URL/credential)
export VIRTUAL_TESTNET_VERIFIER_URL=$VIRTUAL_TESTNET_URL/verify/etherscan

echo Deploy SuperDeployer: ...
forge script script/DeploySuperDeployer.s.sol:DeploySuperDeployer \
    --slow \
    --account default \
    --verify \
    --verifier-url $VIRTUAL_TESTNET_VERIFIER_URL \
    --rpc-url $VIRTUAL_TESTNET_URL \
    --etherscan-api-key $TENDERLY_V2_CORE_INITIAL_API_KEY \
    --broadcast

wait

echo Deploy V2: ...
forge script script/DeployV2.s.sol:DeployV2 \
    --slow \
    --account default \
    --verify \
    --verifier-url $VIRTUAL_TESTNET_VERIFIER_URL \
    --rpc-url $VIRTUAL_TESTNET_URL \
    --etherscan-api-key $TENDERLY_V2_CORE_INITIAL_API_KEY \
    --broadcast

wait
