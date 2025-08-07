# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# only export these env vars if ENVIRONMENT = local
ifeq ($(ENVIRONMENT), local)
	export ETHEREUM_RPC_URL = $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/ETHEREUM_RPC_URL/credential)
	export OPTIMISM_RPC_URL := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/OPTIMISM_RPC_URL/credential)
	export BASE_RPC_URL := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_RPC_URL/credential)
	export ONE_INCH_API_KEY := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/OneInch/credential)
	export SEPOLIA_RPC_URL := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/SEPOLIA_RPC_URL/credential)
	export BASE_SEPOLIA_RPC_URL := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_SEPOLIA_RPC_URL/credential)
	export FUJI_RPC_URL := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/FUJI_RPC_URL/credential)
endif


build :; forge build && $(MAKE) generate

forge-script :; forge script $(SCRIPT) $(ARGS)

forge-test :; forge test --match-test $(TEST) $(ARGS)

ftest :; forge test

ftest-vvv :; forge test -v --jobs 2

ftest-ci :; forge test -v --jobs 2

coverage :; FOUNDRY_PROFILE=coverage forge coverage --jobs 10 --report lcov

coverage-genhtml :; FOUNDRY_PROFILE=coverage forge coverage --jobs 10 --report lcov && genhtml lcov.info --branch-coverage --output-dir coverage --ignore-errors inconsistent,corrupt --exclude 'src/vendor/*' --exclude 'test/*'

test-vvv :; forge test --match-test test_BridgeThroughDifferentAdapters -vvvv --jobs 10

test-integration :; forge test --match-test test_CrossChain_execution -vvvv --jobs 10

test-gas-report-user :; forge test --match-test test_gasReport --gas-report --jobs 10
test-gas-report-2vaults :; forge test --match-test test_gasReport_TwoVaults --gas-report --jobs 10
test-gas-report-3vaults :; forge test --match-test test_gasReport_ThreeVaults --gas-report --jobs 10

.PHONY: generate
generate:
	rm -rf contract_bindings/*
	./script/run/retrieve-abis.sh
	./script/run/generate-contract-bindings.sh