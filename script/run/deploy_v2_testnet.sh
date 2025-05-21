# Note: How to set defaultKey - https://www.youtube.com/watch?v=VQe7cIpaE54

export BASE_SEPOLIA=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_SEPOLIA_RPC_URL/credential)
export OP_SEPOLIA=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/OP_SEPOLIA_RPC_URL/credential)
export SEPOLIA=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/SEPOLIA_RPC_URL/credential)
export ETHERSCANV2_API_KEY="JCCB3M2DFJ4CS7BGM3919B444ERUAWU6QB"



echo Deploy V2 on Base Sepolia: ...
forge script script/DeployV2.s.sol:DeployV2 \
    --sig 'run(uint256,uint64,string)' 1 84532 "DEPLOYSEPOLIATEST1.0.0" \
    --account testnetDeployer \
    --verify \
    --rpc-url $BASE_SEPOLIA \
    --etherscan-api-key $ETHERSCANV2_API_KEY \
    --broadcast \
    --slow
wait

echo Deploy V2 on OP Sepolia: ...
forge script script/DeployV2.s.sol:DeployV2 \
    --sig 'run(uint256,uint64,string)' 1 11155420 "DEPLOYSEPOLIATEST1.0.0" \
    --account testnetDeployer \
    --verify \
    --rpc-url $OP_SEPOLIA \
    --etherscan-api-key $ETHERSCANV2_API_KEY \
    --broadcast \
    --slow
wait

echo Deploy V2 on ETH Sepolia: ...
forge script script/DeployV2.s.sol:DeployV2 \
    --sig 'run(uint256,uint64,string)' 1 11155111 "DEPLOYSEPOLIATEST1.0.0" \
    --account testnetDeployer \
    --verify \
    --rpc-url $SEPOLIA \
    --etherscan-api-key $ETHERSCANV2_API_KEY \
    --broadcast \
    --slow
wait
