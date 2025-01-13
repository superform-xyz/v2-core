# Note: How to set defaultKey - https://www.youtube.com/watch?v=VQe7cIpaE54

export TENDERLY_ACCESS_KEY=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/TENDERLY_ACCESS_KEY/credential)
export ETH_MAINNET=https://virtual.mainnet.rpc.tenderly.co/68538f23-0cd7-4204-9722-edba9eec8bc8
export BASE_MAINNET=https://virtual.base.rpc.tenderly.co/65bd24b3-534d-480d-8efa-fbfdc5facfdc
export ETH_MAINNET_VERIFIER_URL=$ETH_MAINNET/verify/etherscan
export BASE_MAINNET_VERIFIER_URL=$BASE_MAINNET/verify/etherscan


curl $ETH_MAINNET \
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

echo Deploy SuperDeployer on network 1: ...
forge script script/DeploySuperDeployer.s.sol:DeploySuperDeployer \
--account testDeployer \
--verify \
--verifier-url $ETH_MAINNET_VERIFIER_URL \
--rpc-url $ETH_MAINNET \
--etherscan-api-key $TENDERLY_ACCESS_KEY \
--broadcast
wait

echo Deploy V2 on network 1: ...
forge script script/DeployV2.s.sol:DeployV2 \
    --sig 'run(uint64[])' '[1]' \
    --account testDeployer \
    --verify \
    --verifier-url $ETH_MAINNET_VERIFIER_URL \
    --rpc-url $ETH_MAINNET \
    --etherscan-api-key $TENDERLY_ACCESS_KEY \
    --broadcast \
    --slow
wait

curl $BASE_MAINNET \
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

wait

echo Deploy SuperDeployer on network 2: ...
forge script script/DeploySuperDeployer.s.sol:DeploySuperDeployer \
    --account testDeployer \
    --verify \
    --verifier-url $BASE_MAINNET_VERIFIER_URL \
    --rpc-url $BASE_MAINNET \
    --etherscan-api-key $TENDERLY_ACCESS_KEY \
    --broadcast

wait

echo Deploy V2 on network 2: ...
forge script script/DeployV2.s.sol:DeployV2 \
    --sig 'run(uint64[])' '[8453]' \
    --account testDeployer \
    --verify \
    --verifier-url $BASE_MAINNET_VERIFIER_URL \
    --rpc-url $BASE_MAINNET \
    --etherscan-api-key $TENDERLY_ACCESS_KEY \
    --broadcast \
    --slow
wait