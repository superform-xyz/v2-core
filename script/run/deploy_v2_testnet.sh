# Note: How to set defaultKey - https://www.youtube.com/watch?v=VQe7cIpaE54

export BASE_SEPOLIA=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_SEPOLIA_RPC_URL/credential)
export OP_SEPOLIA=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/OP_SEPOLIA_RPC_URL/credential)
export SEPOLIA=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/SEPOLIA_RPC_URL/credential)
export ETHERSCANV2_API_KEY=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/ETHERSCANV2_API_KEY_TEST/credential)



echo Deploy V2 on Base Sepolia: ...
forge script script/DeployV2.s.sol:DeployV2 \
    --sig 'run(uint256,uint64,string)' 2 84532 "DEPLOYSEPOLIATEST1.0.3" \
    --account testnetDeployer \
    --rpc-url $BASE_SEPOLIA \
    --chain 84532 \
    --verify \
    --broadcast \
    --slow
wait

echo Deploy V2 on OP Sepolia: ...
forge script script/DeployV2.s.sol:DeployV2 \
    --sig 'run(uint256,uint64,string)' 2 11155420 "DEPLOYSEPOLIATEST1.0.3" \
    --account testnetDeployer \
    --rpc-url $OP_SEPOLIA \
    --chain 11155420 \
    --verify \
    --broadcast \
    --slow
wait

echo Deploy V2 on ETH Sepolia: ...
forge script script/DeployV2.s.sol:DeployV2 \
    --sig 'run(uint256,uint64,string)' 2 11155111 "DEPLOYSEPOLIATEST1.0.3" \
    --account testnetDeployer \
    --rpc-url $SEPOLIA \
    --chain 11155111 \
    --etherscan-api-key $ETHERSCANV2_API_KEY \
    --verify \
    --broadcast \
    --slow
wait
