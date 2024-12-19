# Note: How to set defaultKey - https://www.youtube.com/watch?v=VQe7cIpaE54

export TENDERLY_ACCESS_KEY=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/TENDERLY_ACCESS_KEY/credential)
export V2_TEST_VNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/V2_TEST_VNET/credential)
export VIRTUAL_TESTNET_VERIFIER_URL=$V2_TEST_VNET/verify/etherscan


echo Deploy V2: ...
forge script script/DeployV2.s.sol:DeployV2 \
    --sig 'run(uint64[])' '[1]' \
    --account testDeployer \
    --verify \
    --verifier-url $VIRTUAL_TESTNET_VERIFIER_URL \
    --rpc-url $V2_TEST_VNET \
    --etherscan-api-key $TENDERLY_ACCESS_KEY \
    --broadcast

wait
