# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# only export these env vars if ENVIRONMENT = local
ifeq ($(ENVIRONMENT), local)
	export ETHEREUM_RPC_URL = $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/ETHEREUM_RPC_URL/credential)
	export OPTIMISM_RPC_URL := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/OPTIMISM_RPC_URL/credential)
	export BASE_RPC_URL := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_RPC_URL/credential)
	export ONE_INCH_API_KEY := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/OneInch/credential)
endif


deploy-poc:
	forge script script/PoC/Deploy.s.sol --broadcast --legacy --multi --verify

build :; forge build && $(MAKE) generate

ftest :; forge test

ftest-vvv :; forge test -vvv

coverage :; FOUNDRY_PROFILE=coverage forge coverage --jobs 10 --ir-minimum --report lcov

test-vvv :; forge test --match-test test_UpdateSuperVaultPPS_Integration -vvvv --jobs 10

test-integration :; forge test --match-contract ECDSAPPSOracleTest -vv --jobs 10

test-gas-report-user :; forge test --match-test test_gasReport --gas-report --jobs 10
test-gas-report-2vaults :; forge test --match-test test_gasReport_TwoVaults --gas-report --jobs 10
test-gas-report-3vaults :; forge test --match-test test_gasReport_ThreeVaults --gas-report --jobs 10

test-cache :; forge test --cache-tests

.PHONY: generate
generate:
	rm -rf contract_bindings/*
	./script/run/retrieve-abis.sh
	./script/run/generate-contract-bindings.sh