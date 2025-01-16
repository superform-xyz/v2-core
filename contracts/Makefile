# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# only export these env vars if ENVIRONMENT = local
ifeq ($(ENVIRONMENT), local)
	export ETHEREUM_RPC_URL = $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/ETHEREUM_RPC_URL/credential)
	export BSC_RPC_URL := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/BSC_RPC_URL/credential)
	export AVALANCHE_RPC_URL := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/AVALANCHE_RPC_URL/credential)
	export POLYGON_RPC_URL := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/POLYGON_RPC_URL/credential)
	export ARBITRUM_RPC_URL := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/ARBITRUM_RPC_URL/credential)
	export OPTIMISM_RPC_URL := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/OPTIMISM_RPC_URL/credential)
	export BASE_RPC_URL := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_RPC_URL/credential)
	export FANTOM_RPC_URL := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/FANTOM_RPC_URL/credential)
	export LINEA_RPC_URL := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/LINEA_RPC_URL/credential)
	export BLAST_RPC_URL := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/BLAST_RPC_URL/credential)
	export BARTIO_RPC_URL := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/BARTIO_RPC_URL/credential)
	export ETHEREUM_RPC_URL_QN := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/ETHEREUM_RPC_URL/credential)
	export BSC_RPC_URL_QN := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/BSC_RPC_URL/credential)
	export AVALANCHE_RPC_URL_QN := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/AVALANCHE_RPC_URL/credential)
	export POLYGON_RPC_URL_QN := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/POLYGON_RPC_URL/credential)
	export ARBITRUM_RPC_URL_QN := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/ARBITRUM_RPC_URL/credential)
	export OPTIMISM_RPC_URL_QN := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/OPTIMISM_RPC_URL/credential)
	export BASE_RPC_URL_QN := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_RPC_URL/credential)
	export FANTOM_RPC_URL_QN := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/FANTOM_RPC_URL/credential)
	export SEPOLIA_RPC_URL_QN := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/SEPOLIA_RPC_URL/credential)
	export BSC_TESTNET_RPC_URL_QN := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/BSC_TESTNET_RPC_URL/credential)
	export LINEA_RPC_URL_QN := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/LINEA_RPC_URL/credential)
	export BLAST_RPC_URL_QN := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/BLAST_RPC_URL/credential)
	export BARTIO_RPC_URL_QN := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/BARTIO_RPC_URL/credential)
endif



deploy-poc:
	forge script script/PoC/Deploy.s.sol --broadcast --legacy --multi --verify

build :; forge build
ftest :; forge test

test-vvv :; forge test --match-test test_RebalanceCrossChain_4626_Mainnet_Flow -vvvv

test-integration :; forge test --match-contract test_Deposit_Redeem_4626_Mainnet_Flow -vvvv

.PHONY: generate
generate: build 
	chmod +x ./script/run/retrieve-abis.sh
	./script/run/retrieve-abis.sh

	# General
	abigen --abi out/SuperExecutor.sol/SuperExecutor.abi --pkg contracts --type SuperExecutor --out contract_bindings/SuperExecutor.go
	abigen --abi out/ISuperExecutor.sol/ISuperExecutor.abi --pkg contracts --type ISuperExecutor --out contract_bindings/ISuperExecutor.go
	abigen --abi out/AcrossExecuteOnDestinationHook.sol/AcrossExecuteOnDestinationHook.abi --pkg contracts --type AcrossExecuteOnDestinationHook --out contract_bindings/AcrossExecuteOnDestinationHook.go
	abigen --abi out/AcrossReceiveFundsAndExecuteGateway.sol/AcrossReceiveFundsAndExecuteGateway.abi --pkg contracts --type AcrossReceiveFundsAndExecuteGateway --out contract_bindings/AcrossReceiveFundsAndExecuteGateway.go
	abigen --abi out/IAcrossV3Receiver.sol/IAcrossV3Receiver.abi --pkg contracts --type IAcrossV3Receiver --out contract_bindings/IAcrossV3Receiver.go
