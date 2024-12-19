# Note: How to set defaultKey - https://www.youtube.com/watch?v=VQe7cIpaE54

export TENDERLY_ACCESS_KEY=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/TENDERLY_ACCESS_KEY/credential)
export V2_TEST_VNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/V2_TEST_VNET/credential)
export VIRTUAL_TESTNET_VERIFIER_URL=$V2_TEST_VNET/verify/etherscan

curl $V2_TEST_VNET \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{
        "jsonrpc": "2.0",
        "method": "tenderly_setBalance",
        "params": [
        [
          "0x76e9b0063546d97A9c2FDbC9682C5FA347B253BA"
        ],
        "0xDE0B6B3A7640000"
        ],
        "id": "1234"
    }'

echo Deploy SuperDeployer: ...
forge script script/DeploySuperDeployer.s.sol:DeploySuperDeployer \
    --account testDeployer \
    --verify \
    --verifier-url $VIRTUAL_TESTNET_VERIFIER_URL \
    --rpc-url $V2_TEST_VNET \
    --etherscan-api-key $TENDERLY_ACCESS_KEY \
    --broadcast

wait
