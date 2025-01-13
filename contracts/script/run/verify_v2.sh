# Note: How to set defaultKey - https://www.youtube.com/watch?v=VQe7cIpaE54

export TENDERLY_ACCESS_KEY=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/TENDERLY_ACCESS_KEY/credential)
export ETH_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/ETH_MAINNET_VNET/credential)
export BASE_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_MAINNET_VNET/credential)
export ETH_MAINNET_VERIFIER_URL="$ETH_MAINNET/verify/etherscan"
export BASE_MAINNET_VERIFIER_URL="$BASE_MAINNET/verify/etherscan"

# constructor args
empty_arg="$(cast abi-encode "constructor()")"
owner_arg="$(cast abi-encode "constructor(address)" "0x76e9b0063546d97A9c2FDbC9682C5FA347B253BA")"
super_registry_arg="$(cast abi-encode "constructor(address)" "0x91f9FeB8Ac34C73d8Cfdce57FdB9FEF74E031911")"
acrossReceiveFundsAndExecuteGateway_arg="$(cast abi-encode "constructor(address, address)" "0x91f9FeB8Ac34C73d8Cfdce57FdB9FEF74E031911" "0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5")"
acrossSendFundsAndExecuteOnDstHook_arg="$(cast abi-encode "constructor(address, address, address)" "0x91f9FeB8Ac34C73d8Cfdce57FdB9FEF74E031911" "0x76e9b0063546d97A9c2FDbC9682C5FA347B253BA" "0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5")"
baseHook_arg="$(cast abi-encode "constructor(address, address)" "0x91f9FeB8Ac34C73d8Cfdce57FdB9FEF74E031911" "0x76e9b0063546d97A9c2FDbC9682C5FA347B253BA")"

# networks
networks=(1 8453)  # ETH Mainnet, Base Mainnet

# verifier urls
verifier_urls=("$ETH_MAINNET_VERIFIER_URL" "$BASE_MAINNET_VERIFIER_URL")

# define files to verify
files_to_verify=(
    "src/settings/SuperRegistry.sol"
    "src/executors/SuperExecutor.sol"
    "src/settings/SuperRbac.sol"
    "src/accounting/SuperLedger.sol"
    "src/sentinels/SuperPositionSentinel.sol"
    "src/bridges/AcrossReceiveFundsAndExecuteGateway.sol"
    "src/hooks/bridges/AcrossSendFundsAndExecuteOnDstHook.sol"
    "src/hooks/claim/fluid/FluidClaimRewardHook.sol"
    "src/hooks/claim/gearbox/GearboxClaimRewardHook.sol"
    "src/hooks/claim/somelier/SomelierClaimAllRewardsHook.sol"
    "src/hooks/claim/somelier/SomelierClaimOneRewardHook.sol"
    "src/hooks/claim/yearn/YearnClaimAllRewardsHook.sol"
    "src/hooks/claim/yearn/YearnClaimOneRewardHook.sol"
    "src/hooks/stake/gearbox/GearboxStakeHook.sol"
    "src/hooks/stake/gearbox/GearboxWithdrawHook.sol"
    "src/hooks/stake/somelier/SomelierStakeHook.sol"
    "src/hooks/stake/somelier/SomelierUnbondAllHook.sol"
    "src/hooks/stake/somelier/SomelierUnbondHook.sol"
    "src/hooks/stake/somelier/SomelierUnstakeAllHook.sol"
    "src/hooks/stake/somelier/SomelierUnstakeHook.sol"
    "src/hooks/stake/yearn/YearnWithdrawHook.sol"
    "src/hooks/stake/YieldExitHook.sol"
)

# define contract names
contract_names=(
    "SuperRegistry"
    "SuperExecutor"
    "SuperRbac"
    "SuperLedger"
    "SuperPositionSentinel"
    "AcrossReceiveFundsAndExecuteGateway"
    "AcrossSendFundsAndExecuteOnDstHook"
    "FluidClaimRewardHook"
    "GearboxClaimRewardHook"
    "SomelierClaimAllRewardsHook"
    "SomelierClaimOneRewardHook"
    "YearnClaimAllRewardsHook"
    "YearnClaimOneRewardHook"
    "GearboxStakeHook"
    "GearboxWithdrawHook"
    "SomelierStakeHook"
    "SomelierUnbondAllHook"
    "SomelierUnbondHook"
    "SomelierUnstakeAllHook"
    "SomelierUnstakeHook"
    "YearnWithdrawHook"
    "YieldExitHook"
)

# define contract addresses
contract_addresses=(
    "0x0000000000000000000000000000000000000000" # SuperRegistry
    "0x0000000000000000000000000000000000000000" # SuperExecutor
    "0x0000000000000000000000000000000000000000" # SuperRbac
    "0x0000000000000000000000000000000000000000" # SuperLedger
    "0x0000000000000000000000000000000000000000" # SuperPositionSentinel
    "0x0000000000000000000000000000000000000000" # AcrossReceiveFundsAndExecuteGateway
    "0x0000000000000000000000000000000000000000" # AcrossSendFundsAndExecuteOnDstHook
    "0x0000000000000000000000000000000000000000" # FluidClaimRewardHook
    "0x0000000000000000000000000000000000000000" # GearboxClaimRewardHook
    "0x0000000000000000000000000000000000000000" # SomelierClaimAllRewardsHook
    "0x0000000000000000000000000000000000000000" # SomelierClaimOneRewardHook
    "0x0000000000000000000000000000000000000000" # YearnClaimAllRewardsHook
    "0x0000000000000000000000000000000000000000" # YearnClaimOneRewardHook
    "0x0000000000000000000000000000000000000000" # GearboxStakeHook
    "0x0000000000000000000000000000000000000000" # GearboxWithdrawHook
    "0x0000000000000000000000000000000000000000" # SomelierStakeHook
    "0x0000000000000000000000000000000000000000" # SomelierUnbondAllHook
    "0x0000000000000000000000000000000000000000" # SomelierUnbondHook
    "0x0000000000000000000000000000000000000000" # SomelierUnstakeAllHook
    "0x0000000000000000000000000000000000000000" # SomelierUnstakeHook
    "0x0000000000000000000000000000000000000000" # YearnWithdrawHook
    "0x0000000000000000000000000000000000000000" # YieldExitHook
)

# define constructor args for each contract
constructor_args=(
    "$owner_arg"  # SuperRegistry
    "$super_registry_arg"  # SuperExecutor
    "$owner_arg"  # SuperRbac
    "$super_registry_arg"  # SuperLedger
    "$super_registry_arg"  # SuperPositionSentinel
    "$acrossReceiveFundsAndExecuteGateway_arg"  # AcrossReceiveFundsAndExecuteGateway
    "$acrossSendFundsAndExecuteOnDstHook_arg"  # AcrossSendFundsAndExecuteOnDstHook
    "$baseHook_arg"  # FluidClaimRewardHook
    "$baseHook_arg"  # GearboxClaimRewardHook
    "$baseHook_arg"  # SomelierClaimAllRewardsHook
    "$baseHook_arg"  # SomelierClaimOneRewardHook
    "$baseHook_arg"  # YearnClaimAllRewardsHook
    "$baseHook_arg"  # YearnClaimOneRewardHook
    "$baseHook_arg"  # GearboxStakeHook
    "$baseHook_arg"  # GearboxWithdrawHook
    "$baseHook_arg"  # SomelierStakeHook
    "$baseHook_arg"  # SomelierUnbondAllHook
    "$baseHook_arg"  # SomelierUnbondHook
    "$baseHook_arg"  # SomelierUnstakeAllHook
    "$baseHook_arg"  # SomelierUnstakeHook
    "$baseHook_arg"  # YearnWithdrawHook
    "$baseHook_arg"  # YieldExitHook
)

# verify contracts for each network
for i in "${!networks[@]}"; do
    network="${networks[$i]}"
    verifier_url="${verifier_urls[$i]}"

    for j in "${!files_to_verify[@]}"; do
        file_name="${files_to_verify[$j]}"
        contract_name="${contract_names[$j]}"
        constructor_arg="${constructor_args[$j]}"
        contract_address="${contract_addresses[$j]}"
        # verify contract
        forge verify-contract $contract_address \
            --num-of-optimizations 10000 \
            --watch --compiler-version v0.8.28+commit.1e15a330 \
            #--constructor-args "$constructor_arg" \
            --guess-constructor-args \
            "$file_name:$contract_name" \
            --etherscan-api-key "$TENDERLY_ACCESS_KEY" \
            --verifier-url $verifier_url
    done
done