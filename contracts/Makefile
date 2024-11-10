include .env

export ETHEREUM_RPC_URL = $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/ETHEREUM_RPC_URL/credential)
export ARBITRUM_RPC_URL = $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/ARBITRUM_RPC_URL/credential)



deploy-poc:
	forge script script/PoC/Deploy.s.sol --broadcast --legacy --multi --verify

build :; forge build
ftest :; forge test
test-vvv :; forge test -vvvvv