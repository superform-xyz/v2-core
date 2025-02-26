# Note: How to set defaultKey - https://www.youtube.com/watch?v=VQe7cIpaE54

export TENDERLY_ACCESS_KEY=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/TENDERLY_ACCESS_KEY/credential)
export ETH_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/ETH_MAINNET_VNET/credential)
export BASE_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_MAINNET_VNET/credential)
export ETH_MAINNET_VERIFIER_URL="$ETH_MAINNET/verify/etherscan"
export BASE_MAINNET_VERIFIER_URL="$BASE_MAINNET/verify/etherscan"

#ETH_MAINNET="https://eth-mainnet.g.alchemy.com/v2/demo"
#BASE_MAINNET="https://base-mainnet.g.alchemy.com/v2/demo"  
#ETH_MAINNET_VERIFIER_URL="$ETH_MAINNET/verify/etherscan"
#BASE_MAINNET_VERIFIER_URL="$BASE_MAINNET/verify/etherscan"

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

# rpc urls
rpc_urls=("$ETH_MAINNET" "$BASE_MAINNET")

# define files to verify
files_to_verify=(
    "src/settings/SuperRegistry.sol"
    "src/executors/SuperExecutor.sol"
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
    "0x91f9FeB8Ac34C73d8Cfdce57FdB9FEF74E031911" # SuperRegistry
    "0xD86FA74Fd55197Ffd2881710fE44A82748DD09fb" # SuperExecutor
    "0x5f6A49AEF54E10bCeC3551d273024401495e4ee8" # SuperRbac
    "0x5D1894042B19476810Ae0Ea349CD80f838c92f7c" # SuperLedger
    "0xfed243AcF089026092C0E556d27C31a38b1Cce80" # SuperPositionSentinel
    "0x4934d2740C1dE37Af321D2eD6918Df2df1b99039" # AcrossReceiveFundsAndExecuteGateway
    "0x418d6952443471758F3Ef839Bc616B747911E097" # AcrossSendFundsAndExecuteOnDstHook
    "0x87CC50221bA088b3FB78a437641a8B3f13deD85C" # FluidClaimRewardHook
    "0xFa43E739096202D4C6aA0271aEdA9e774E67F1c0" # GearboxClaimRewardHook
    "0x5533437689f7B7E97Fc7A54Ec177fA44834c9bd7" # SomelierClaimAllRewardsHook
    "0x2B5423857655d8665Cf898dadABB6926cf3130E0" # SomelierClaimOneRewardHook
    "0x29E7168DA380133b02CB22694085a3Fb49F45D6d" # YearnClaimAllRewardsHook
    "0x4D2FCb50847940d515168157F5f4AA92CF8cdD40" # YearnClaimOneRewardHook
    "0x53f8a594A848258c65fA9E21bAe63438a2412C05" # GearboxStakeHook
    "0x0a8E782D3996Fa0679b411eDD25bb621A1774641" # GearboxWithdrawHook
    "0xbef985A2ACE26F22d2c58F07F99D5D14BF86A239" # SomelierStakeHook
    "0x104C512736Fdba2D32F2be8F93A13786ee0BE20d" # SomelierUnbondAllHook
    "0x70E5D3e6E28a106C717a45475138a936798d6eF0" # SomelierUnbondHook
    "0xCdD21e5BDeB66a8623406dfF8548f23A2F5178c0" # SomelierUnstakeAllHook
    "0xCd88CA042B37285D1105f1B505c3A01cAc19E7F5" # SomelierUnstakeHook
    "0x066bafD1696A2d94f94c45d12339310daA222f76" # YearnWithdrawHook
    "0xF675E6e725f272a0BB2f3Cd69E9D6136B50Fa00c" # YieldExitHook
)

# define constructor args for each contract
constructor_args=(
    "$owner_arg"  # SuperRegistry
    "$super_registry_arg"  # SuperExecutor
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
    rpc_url="${rpc_urls[$i]}"

    for j in "${!files_to_verify[@]}"; do
        file_name="${files_to_verify[$j]}"
        contract_name="${contract_names[$j]}"
        constructor_arg="${constructor_args[$j]}"
        contract_address="${contract_addresses[$j]}"

        # verify contract
        forge verify-contract $contract_address $contract_name\
            #--num-of-optimizations 10000 \
            #--watch --compiler-version v0.8.28+commit.7893614a \
            --constructor-args "$constructor_arg" \
            #--guess-constructor-args \
            #"$file_name:$contract_name" \
            --rpc-url "$rpc_url" \
            --verifier-url "$verifier_url" \
            --etherscan-api-key "$TENDERLY_ACCESS_KEY" \
            --slow
        return
    done
done