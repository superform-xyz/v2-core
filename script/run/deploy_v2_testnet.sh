# Note: How to set defaultKey - https://www.youtube.com/watch?v=VQe7cIpaE54

export BASE_SEPOLIA=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_SEPOLIA_RPC_URL/credential)
export OP_SEPOLIA=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/OP_SEPOLIA_RPC_URL/credential)
export SEPOLIA=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/SEPOLIA_RPC_URL/credential)
export ETHERSCANV2_API_KEY="$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/ETHERSCANV2_API_KEY/credential)"



echo Deploy V2 on Base Sepolia: ...
forge script script/DeployV2.s.sol:DeployV2 \
    --sig 'run(uint256,uint64,string)' 1 84532 "DEPLOYSEPOLIA1.0.0" \
    --account testDeployer \
    --verify \
    --rpc-url $BASE_SEPOLIA \
    --etherscan-api-key $ETHERSCANV2_API_KEY \
    --broadcast \
    --slow
wait

echo Deploy V2 on OP Sepolia: ...
forge script script/DeployV2.s.sol:DeployV2 \
    --sig 'run(uint256,uint64,string)' 1 11155420 "DEPLOYSEPOLIA1.0.0" \
    --account testDeployer \
    --verify \
    --rpc-url $OP_SEPOLIA \
    --etherscan-api-key $ETHERSCANV2_API_KEY \
    --broadcast \
    --slow
wait

echo Deploy V2 on ETH Sepolia: ...
forge script script/DeployV2.s.sol:DeployV2 \
    --sig 'run(uint256,uint64,string)' 1 11155111 "DEPLOYSEPOLIA1.0.0" \
    --account testDeployer \
    --verify \
    --rpc-url $SEPOLIA \
    --etherscan-api-key $ETHERSCANV2_API_KEY \
    --broadcast \
    --slow
wait
