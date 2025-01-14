# Note: How to set defaultKey - https://www.youtube.com/watch?v=VQe7cIpaE54

export BASE_SEPOLIA=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_SEPOLIA_RPC_URL/credential)
export BASESCAN_API_KEY=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASESCAN_API_KEY/credential)


echo Deploy V2 on network 1: ...
forge script script/DeployV2.s.sol:DeployV2 \
    --sig 'run(uint64[])' '[84532]' \
    --account testDeployer \
    --verify \
    --rpc-url $BASE_SEPOLIA \
    --etherscan-api-key $BASESCAN_API_KEY \
    --broadcast \
    --slow
wait
