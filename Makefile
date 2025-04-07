# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# only export these env vars if ENVIRONMENT = local
ifeq ($(ENVIRONMENT), local)
	export ETHEREUM_RPC_URL = $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/ETHEREUM_RPC_URL/credential)
	export OPTIMISM_RPC_URL := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/OPTIMISM_RPC_URL/credential)
	export BASE_RPC_URL := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_RPC_URL/credential)
endif


deploy-poc:
	forge script script/PoC/Deploy.s.sol --broadcast --legacy --multi --verify

build :; forge build && $(MAKE) generate

ftest :; forge test

ftest-vvv :; forge test -vvv

coverage :; FOUNDRY_PROFILE=coverage forge coverage --ir-minimum --report lcov


test-vvv :; forge test --match-test test_BorrowHook -vvvv

test-integration :; forge test --match-test test_CrossChainDepositWithSlippage -vvv

test-gas-report-user :; forge test --match-test test_gasReport --gas-report
test-gas-report-2vaults :; forge test --match-test test_gasReport_TwoVaults --gas-report
test-gas-report-3vaults :; forge test --match-test test_gasReport_ThreeVaults --gas-report

test-cache :; forge test --cache-tests

.PHONY: generate
generate:
	rm -rf contract_bindings/*
	./script/run/retrieve-abis.sh
	abigen --abi out/SuperExecutor.sol/SuperExecutor.abi --pkg contracts --type SuperExecutor --out contract_bindings/SuperExecutor.go
	abigen --abi out/AcrossSendFundsAndExecuteOnDstHook.sol/AcrossSendFundsAndExecuteOnDstHook.abi --pkg contracts --type AcrossSendFundsAndExecuteOnDstHook --out contract_bindings/AcrossSendFundsAndExecuteOnDstHook.go
	abigen --abi out/AcrossReceiveFundsAndExecuteGateway.sol/AcrossReceiveFundsAndExecuteGateway.abi --pkg contracts --type AcrossReceiveFundsAndExecuteGateway --out contract_bindings/AcrossReceiveFundsAndExecuteGateway.go
	abigen --abi out/IAcrossV3Receiver.sol/IAcrossV3Receiver.abi --pkg contracts --type IAcrossV3Receiver --out contract_bindings/IAcrossV3Receiver.go
	abigen --abi out/SuperRegistry.sol/SuperRegistry.abi --pkg contracts --type SuperRegistry --out contract_bindings/SuperRegistry.go
	abigen --abi out/PeripheryRegistry.sol/PeripheryRegistry.abi --pkg contracts --type PeripheryRegistry --out contract_bindings/PeripheryRegistry.go