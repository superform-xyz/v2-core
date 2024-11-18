#!/usr/bin/env bash

export BASESCAN_API_KEY=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASESCAN_API_KEY/credential)

networks=(
    84532
    # add more networks here if needed
)

api_keys=(
    $BASESCAN_API_KEY
    # add more API keys here if needed
)

## CONTRACTS VERIFICATION
empty_constructor_arg="$(cast abi-encode "constructor()")"
constructor_with_deployer="$(cast abi-encode "constructor(address)" 0x48aB8AdF869Ba9902Ad483FB1Ca2eFDAb6eabe92)"
constructor_with_sr="$(cast abi-encode "constructor(address)" 0x06008e3dbf33a6A1864bDaafce8d8603BBFD3e3d)"
constructor_with_sr_decoder="$(cast abi-encode "constructor(address,address)" 0x06008e3dbf33a6A1864bDaafce8d8603BBFD3e3d 0x39174F2B940f630E1bcC4c111e835EeC389c516f)"
constructor_superVault="$(cast abi-encode "constructor(address,string,string)" 0x4200000000000000000000000000000000000006 SuperWETHVault sWETH)"

file_names=(
    "src/settings/SuperRbac.sol"
    "src/settings/SuperRegistry.sol"
    "src/sentinels/Deposit4626MintSuperPositionsDecoder.sol"
    "src/sentinels/RelayerSentinel.sol"
    "src/modules/Deposit4626Module.sol"
    "src/vault/SuperformVault.sol"
    # Add more file names here if needed
)
contract_addresses=(
    0xBB05856eaaaAD7cbB6E3bb45B1214D369fDB07Eb
    0x06008e3dbf33a6A1864bDaafce8d8603BBFD3e3d
    0x39174F2B940f630E1bcC4c111e835EeC389c516f
    0xc4662509660AB1128811cb7b85A89d868f5ADb18
    0x325e290d5dc8DcDe61695e1A7d12b0b6a57820A2
    0x1984e9478fC16017AA068D83B5ef6B630F4f6621
    # Add more addresses here if needed
)

constructor_args=(
    $constructor_with_deployer
    $constructor_with_deployer
    $empty_constructor_arg
    $constructor_with_sr
    $constructor_with_sr_decoder
    $constructor_superVault
)

contract_names=(
    "SuperRbac"
    "SuperRegistry"
    "Deposit4626MintSuperPositionsDecoder"
    "RelayerSentinel"
    "Deposit4626Module"
    "SuperformVault"
    # Add more contract names here if needed
)

# loop through networks
for i in "${!networks[@]}"; do
    network="${networks[$i]}"
    api_key="${api_keys[$i]}"

    # loop through file_names and contract_names
    for j in "${!file_names[@]}"; do
        file_name="${file_names[$j]}"
        contract_name="${contract_names[$j]}"
        contract_address="${contract_addresses[$j]}"
        constructor_arg="${constructor_args[$j]}"
        # verify the contract

        forge verify-contract $contract_address \
            --chain-id $network \
            --num-of-optimizations 10000 \
            --watch --compiler-version v0.8.28+commit.7893614a \
            --constructor-args "$constructor_arg" \
            "$file_name:$contract_name" \
            --etherscan-api-key "$api_key"
    done
done
