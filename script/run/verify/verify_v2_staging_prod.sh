#!/usr/bin/env bash

###################################################################################
# V2 Core Contract Verification Script
###################################################################################
# Description:
#   Verifies deployed V2 Core contracts on block explorers (Etherscan V2, Blockscout).
#   Sources lib_deploy.sh for shared utilities (colors, UI, credentials).
#
# Usage:
#   ./script/run/verify/verify_v2_staging_prod.sh <environment>
#
# Arguments:
#   environment: staging or prod
#
# Configuration:
#   CHAINS_TO_VERIFY:     Array of chain IDs to verify (empty = all configured)
#   CONTRACTS_TO_VERIFY:  Array of contract names to verify (empty = all deployed)
#   VERIFY_DELAY:         Seconds between verification requests (rate limit protection)
###################################################################################

# Source shared deployment library (colors, UI, paths, credentials)
source "$(dirname "${BASH_SOURCE[0]}")/../utils/lib_deploy.sh"

# ===== FILTER CONFIGURATION =====
# Specify which chains to verify (empty = all chains from network configuration)
CHAINS_TO_VERIFY=(1 8453 56 42161 43114 14)

# Specify which contracts to verify (empty = all contracts found in deployment JSON)
CONTRACTS_TO_VERIFY=()

# Delay in seconds between verification requests (prevents Cloudflare rate limiting)
VERIFY_DELAY=5

# ===== TRACKING =====
declare -a VERIFIED_CONTRACTS=()
declare -a FAILED_CONTRACTS=()
declare -a SKIPPED_CONTRACTS=()

# ── Setup ─────────────────────────────────────────────────────────────────────
print_header "V2 Core Contract Verification"

if [ $# -lt 1 ]; then
    echo -e "${RED}Error: Missing required argument${NC}"
    echo -e "${YELLOW}Usage: $0 <environment>${NC}"
    echo -e "${CYAN}  environment: staging or prod${NC}"
    echo -e "${CYAN}Examples:${NC}"
    echo -e "${CYAN}  $0 staging${NC}"
    echo -e "${CYAN}  $0 prod${NC}"
    exit 1
fi

ENVIRONMENT=$1

# Load network configuration (without locked bytecode validation)
if [ "$ENVIRONMENT" = "staging" ]; then
    echo -e "${CYAN}Loading staging network configuration...${NC}"
    source "$SCRIPT_DIR/networks-staging.sh"
elif [ "$ENVIRONMENT" = "prod" ]; then
    echo -e "${CYAN}Loading production network configuration...${NC}"
    source "$SCRIPT_DIR/networks-production.sh"
else
    echo -e "${RED}Invalid environment: $ENVIRONMENT${NC}"
    echo -e "${YELLOW}Environment must be either 'staging' or 'prod'${NC}"
    exit 1
fi

if [[ ${#NETWORKS[@]} -eq 0 ]]; then
    echo -e "${RED}Error: No networks configured for $ENVIRONMENT environment${NC}"
    exit 1
fi

echo -e "${CYAN}Network configuration loaded for $ENVIRONMENT environment (${#NETWORKS[@]} networks)${NC}"
print_network_info
cd "$PROJECT_ROOT"

# Load RPC URLs and Etherscan API key
load_credentials

# ── Helpers ───────────────────────────────────────────────────────────────────

# Get the output JSON file path for a chain (derives filename from network name)
get_output_json() {
    local chain_id=$1
    local network_name
    network_name=$(get_network_name "$chain_id") || return 1
    echo "$PROJECT_ROOT/script/output/$ENVIRONMENT/$chain_id/${network_name}-latest.json"
}

# Get a contract address from the deployment JSON
get_contract_address() {
    local chain_id=$1
    local contract_name=$2
    local json_file
    json_file=$(get_output_json "$chain_id") || return 1
    if [ -f "$json_file" ]; then
        jq -r ".$contract_name // empty" "$json_file"
    fi
}

# ── Constructor Arguments ─────────────────────────────────────────────────────
# Generate constructor arguments for forge verify-contract based on contract type
# and chain-specific addresses.

generate_constructor_args() {
    local contract_name=$1
    local chain_id=$2

    # Get core contract addresses for this chain
    local super_ledger_config=$(get_contract_address "$chain_id" "SuperLedgerConfiguration")
    local super_executor=$(get_contract_address "$chain_id" "SuperExecutor")
    local super_destination_executor=$(get_contract_address "$chain_id" "SuperDestinationExecutor")
    local super_merkle_validator=$(get_contract_address "$chain_id" "SuperValidator")
    local super_destination_validator=$(get_contract_address "$chain_id" "SuperDestinationValidator")

    # Network-specific addresses
    local permit2=""
    local aggregation_router=""
    local odos_router=""
    local odos_router_v3="0x0D05a7D3448512B78fa8A9e46c4872C88C4a0D05"  # Same CREATE2 on all EVM chains
    local openocean_router=""
    local openocean_caller=""
    local across_spoke_pool_v3=""
    local merkl_distributor=""
    local debridge_dst_dln="0xE7351Fd770A37282b91D153Ee690B63579D6dd7f"
    local entry_point="0x0000000071727De22E5E9d8BAf0edAc6f37da032"  # EntryPoint v0.7
    local debridge_dln_src="0xeF4fB24aD0916217251F553c0596F8Edc630EB66"
    local debridge_dln_dst="0xE7351Fd770A37282b91D153Ee690B63579D6dd7f"
    local gateway_wallet="0x77777777Dcc4d5A8B6E418Fd04D8997ef11000eE"
    local gateway_minter="0x2222222d7164433c4C09B0b0D809a9b52C04C205"
    local pendle_pt_amortized_oracle=""
    if [ "$ENVIRONMENT" = "staging" ]; then
        pendle_pt_amortized_oracle="0xE31FD1d26A52B4a958651a8E751e9362B3880524"
    else
        pendle_pt_amortized_oracle="0xD64089698f82cbCD91ba5e0422aDFa81D247eB62"
    fi
    local pendle_pt_amortized_oracle_v2=""
    if [ "$ENVIRONMENT" = "staging" ]; then
        pendle_pt_amortized_oracle_v2="0x1F32A55b20Ee7bA0bC083671c7723dBA1608D66e"
    else
        pendle_pt_amortized_oracle_v2=""  # TBD - update after prod deployment
    fi

    # Common addresses (same on all chains via CREATE2)
    local cctp_v2_token_messenger="0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d"
    local kyber_router="0x6131B5fae19EA4f9D964eAc0408E4408b66337b5"
    local kyber_scale_helper="0x2f577A41BeC1BE1152AeEA12e73b7391d15f655D"
    local deth_foundation="0x97b5e4a707A4D5AB4A58b2c93bc8d249a63Ff153"
    local deployer="0x6E3dadcAf328ebB58753e89a3e589F5C5e988dF8"
    local algebra_integral_router_flare="0x69D57B9D705eaD73a5d2f2476C30c55bD755cc2F"
    local sparkdex_v2_router_flare="0x4a1E5A90e9943467FAd1acea1E7F0e5e88472a1e"
    local spark_psm3_base="0x1601843c5E9bC251A3272907010AFa41Fa18347E"
    local lz_endpoint_v2="0x1a44076050125825900e736c501f859c50fE728c"
    local lz_endpoint_v2_alt="0x6F475642a6e85809B1c36Fa62763669b1b48DD5B"

    # Network-specific configurations
    case $chain_id in
        "1") # Ethereum Mainnet
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router="0x111111125421cA6dc452d289314280a0f8842A65"
            odos_router="0xcf5540fFFCdC3d510B18bFcA6d2b9987b0772559"
            across_spoke_pool_v3="0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5"
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
        "8453") # Base
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router="0x111111125421cA6dc452d289314280a0f8842A65"
            odos_router="0x19cEeAd7105607Cd444F5ad10dd51356436095a1"
            across_spoke_pool_v3="0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64"
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
        "56") # BSC
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router="0x111111125421cA6dc452d289314280a0f8842A65"
            odos_router="0x89b8AA89FDd0507a99d334CBe3C808fAFC7d850E"
            across_spoke_pool_v3="0x4e8E101924eDE233C13e2D8622DC8aED2872d505"
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
        "42161") # Arbitrum
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router="0x111111125421cA6dc452d289314280a0f8842A65"
            odos_router="0xa32EE1C40594249eb3183c10792BcF573D4Da47C"
            across_spoke_pool_v3="0xe35e9842fceaCA96570B734083f4a58e8F7C5f2A"
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
        "10") # Optimism
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router="0x111111125421cA6dc452d289314280a0f8842A65"
            odos_router="0xCa423977156BB05b13A2BA3b76Bc5419E2fE9680"
            across_spoke_pool_v3="0x6f26Bf09B1C792e3228e5467807a900A503c0281"
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
        "137") # Polygon
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router="0x111111125421cA6dc452d289314280a0f8842A65"
            odos_router="0x4E3288c9ca110bCC82bf38F09A7b425c095d92Bf"
            across_spoke_pool_v3="0x9295ee1d8C5b022Be115A2AD3c30C72E34e7F096"
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            native_token="0x0000000000000000000000000000000000001010"
            ;;
        "130") # Unichain
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router="0x111111125421cA6dc452d289314280a0f8842A65"
            odos_router="0x6409722F3a1C4486A3b1FE566cBDd5e9D946A1f3"
            across_spoke_pool_v3="0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64"
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
        "43114") # Avalanche
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router="0x111111125421cA6dc452d289314280a0f8842A65"
            odos_router="0x88de50B233052e4Fb783d4F6db78Cc34fEa3e9FC"
            across_spoke_pool_v3=""
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
        "80094") # Berachain
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router=""
            odos_router=""
            across_spoke_pool_v3=""
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
        "146") # Sonic
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router="0x111111125421cA6dc452d289314280a0f8842A65"
            odos_router="0xaC041Df48dF9791B0654f1Dbbf2CC8450C5f2e9D"
            across_spoke_pool_v3=""
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
        "100") # Gnosis
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router="0x111111125421cA6dc452d289314280a0f8842A65"
            odos_router=""
            across_spoke_pool_v3=""
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
        "480") # Worldchain
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router=""
            odos_router=""
            across_spoke_pool_v3="0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64"
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
        "999") # HyperEVM
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router=""
            odos_router=""
            across_spoke_pool_v3=""
            merkl_distributor=""
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
        "14") # Flare
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router=""
            odos_router=""
            openocean_router="0x6352a56caadc4f1e25cd6c75970fa768a3304e64"
            openocean_caller="0x6dd434082eab5cd134b33719ec1ff05fe985b97b"
            across_spoke_pool_v3=""
            merkl_distributor=""
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
        "988") # Stable
            permit2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
            aggregation_router=""
            odos_router=""
            across_spoke_pool_v3=""
            merkl_distributor="0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
            native_token="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            ;;
    esac

    # Generate constructor arguments based on contract type
    case $contract_name in
        # Core contracts with no constructor args
        "SuperLedgerConfiguration"|"SuperValidator"|"SuperDestinationValidator"|"SuperYieldSourceOracle")
            echo "$(cast abi-encode "constructor()")"
            ;;
        "SuperExecutor")
            echo "$(cast abi-encode "constructor(address)" "$super_ledger_config")"
            ;;
        "SuperDestinationExecutor")
            echo "$(cast abi-encode "constructor(address,address)" "$super_ledger_config" "$super_destination_validator")"
            ;;
        "AcrossV3Adapter"|"AcrossV3AdapterV2")
            echo "$(cast abi-encode "constructor(address,address)" "$across_spoke_pool_v3" "$super_destination_executor")"
            ;;
        "DebridgeAdapter")
            echo "$(cast abi-encode "constructor(address,address)" "$debridge_dst_dln" "$super_destination_executor")"
            ;;
        "SuperLedger"|"FlatFeeLedger")
            echo "$(cast abi-encode "constructor(address,address[])" "$super_ledger_config" "[$super_executor,$super_destination_executor]")"
            ;;
        "SuperNativePaymaster")
            echo "$(cast abi-encode "constructor(address)" "$entry_point")"
            ;;
        "BatchTransferHook")
            echo "$(cast abi-encode "constructor(address)" "$native_token")"
            ;;
        "BatchTransferFromHook")
            echo "$(cast abi-encode "constructor(address)" "$permit2")"
            ;;
        "Swap1InchHook")
            echo "$(cast abi-encode "constructor(address)" "$aggregation_router")"
            ;;
        "SwapOdosV2Hook"|"ApproveAndSwapOdosV2Hook")
            echo "$(cast abi-encode "constructor(address)" "$odos_router")"
            ;;
        "SwapOdosV3Hook"|"ApproveAndSwapOdosV3Hook")
            echo "$(cast abi-encode "constructor(address)" "$odos_router_v3")"
            ;;
        "SwapOpenOceanSparkDexHook"|"ApproveAndSwapOpenOceanSparkDexHook")
            echo "$(cast abi-encode "constructor(address,address,address)" "$openocean_router" "$openocean_caller" "$native_token")"
            ;;
        "AcrossSendFundsAndExecuteOnDstHook"|"AcrossSendFundsAndExecuteOnDstHookV2")
            echo "$(cast abi-encode "constructor(address,address)" "$across_spoke_pool_v3" "$super_merkle_validator")"
            ;;
        "ApproveAndAcrossSendFundsAndExecuteOnDstHook"|"ApproveAndAcrossSendFundsAndExecuteOnDstHookV2")
            echo "$(cast abi-encode "constructor(address,address)" "$across_spoke_pool_v3" "$super_merkle_validator")"
            ;;
        "DeBridgeSendOrderAndExecuteOnDstHook")
            echo "$(cast abi-encode "constructor(address,address)" "$debridge_dln_src" "$super_merkle_validator")"
            ;;
        "DeBridgeCancelOrderHook")
            echo "$(cast abi-encode "constructor(address)" "$debridge_dln_dst")"
            ;;
        "MerklClaimRewardHook")
            echo "$(cast abi-encode "constructor(address)" "$merkl_distributor")"
            ;;
        "StargateSendHook"|"ApproveAndStargateSendHook"|"StargateSendHookV2"|"ApproveAndStargateSendHookV2")
            echo "$(cast abi-encode "constructor(address)" "$super_merkle_validator")"
            ;;
        "ClaimRFLRHook")
            local rnat_flare="0x26d460c3Cf931Fb2014FA436a49e3Af08619810e"
            echo "$(cast abi-encode "constructor(address)" "$rnat_flare")"
            ;;
        "WithdrawRFLRHook"|"WithdrawVestedRFLRHook")
            local rnat_flare="0x26d460c3Cf931Fb2014FA436a49e3Af08619810e"
            local wflr_flare="0x1D80c49BbBCd1C0911346656B529DF9E5c2F783d"
            echo "$(cast abi-encode "constructor(address,address)" "$rnat_flare" "$wflr_flare")"
            ;;
        "FluidClaimRewardHook"|"GearboxClaimRewardHook"|"YearnClaimOneRewardHook")
            echo "$(cast abi-encode "constructor()")"
            ;;
        "CircleGatewayWalletHook"|"CircleGatewayAddDelegateHook"|"CircleGatewayRemoveDelegateHook")
            echo "$(cast abi-encode "constructor(address)" "$gateway_wallet")"
            ;;
        "CircleGatewayMinterHook")
            echo "$(cast abi-encode "constructor(address)" "$gateway_minter")"
            ;;
        "RecordPurchasePendlePTAmortizedOracleHook"|"RecordRedemptionPendlePTAmortizedOracleHook")
            echo "$(cast abi-encode "constructor(address)" "$pendle_pt_amortized_oracle")"
            ;;
        "RecordPurchasePendlePTAmortizedOracleHookV2"|"RecordRedemptionPendlePTAmortizedOracleHookV2")
            echo "$(cast abi-encode "constructor(address)" "$pendle_pt_amortized_oracle_v2")"
            ;;
        "SwapUniswapV3Hook"|"ApproveAndSwapUniswapV3Hook")
            local uniswap_v3_router=""
            case $chain_id in
                "999") uniswap_v3_router="0x1EbDFC75FfE3ba3de61E7138a3E8706aC841Af9B" ;;
            esac
            echo "$(cast abi-encode "constructor(address)" "$uniswap_v3_router")"
            ;;
        "SwapUniswapV3Router02Hook"|"ApproveAndSwapUniswapV3Router02Hook")
            local uniswap_v3_router02=""
            case $chain_id in
                "1") uniswap_v3_router02="0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45" ;;
                "8453") uniswap_v3_router02="0x2626664c2603336E57B271c5C0b26F421741e481" ;;
                "56") uniswap_v3_router02="0xB971eF87ede563556b2ED4b1C0b0019111Dd85d2" ;;
                "42161") uniswap_v3_router02="0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45" ;;
                "10") uniswap_v3_router02="0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45" ;;
                "137") uniswap_v3_router02="0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45" ;;
                "130") uniswap_v3_router02="0x73855d06DE49d0fe4A9c42636Ba96c62da12FF9C" ;;
                "43114") uniswap_v3_router02="0xbb00FF08d01D300023C629E8fFfFcb65A5a578cE" ;;
                "480") uniswap_v3_router02="0x091AD9e2e6e5eD44c1c66dB50e49A601F9f36cF6" ;;
                "988") uniswap_v3_router02="0x32eaf9B5d5F2CD7361c5012890C943D7de84C22a" ;;
            esac
            echo "$(cast abi-encode "constructor(address)" "$uniswap_v3_router02")"
            ;;
        "SwapUniswapV4Hook")
            local uniswap_v4_pool_manager=""
            case $chain_id in
                "1") uniswap_v4_pool_manager="0x000000000004444c5dc75cB358380D2e3dE08A90" ;;
                "8453") uniswap_v4_pool_manager="0x498581fF718922c3f8e6A244956aF099B2652b2b" ;;
                "42161") uniswap_v4_pool_manager="0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32" ;;
                "10") uniswap_v4_pool_manager="0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3" ;;
                "137") uniswap_v4_pool_manager="0x67366782805870060151383F4BbFF9daB53e5cD6" ;;
                "130") uniswap_v4_pool_manager="0x1F98400000000000000000000000000000000004" ;;
                "43114") uniswap_v4_pool_manager="0x06380C0e0912312B5150364B9DC4542BA0DbBc85" ;;
                "480") uniswap_v4_pool_manager="0xb1860D529182ac3BC1F51Fa2ABd56662b7D13f33" ;;
            esac
            echo "$(cast abi-encode "constructor(address)" "$uniswap_v4_pool_manager")"
            ;;
        "TransferHook")
            echo "$(cast abi-encode "constructor(address)" "$native_token")"
            ;;
        "PendleUnifiedHook"|"PendleRouterSwapHook"|"PendleRouterRedeemHook")
            local pendle_router="0x888888888889758F76e7103c6CbF23ABbF58F946"
            echo "$(cast abi-encode "constructor(address)" "$pendle_router")"
            ;;
        "ERC7540YieldSourceOracle"|"SpectraMetaVaultOracle")
            echo "$(cast abi-encode "constructor(address,uint256)" "$super_ledger_config" "0")"
            ;;
        "SuperVaultYieldSourceOracle")
            echo "$(cast abi-encode "constructor(address)" "$super_ledger_config")"
            ;;
        "MorphoSupplyAndBorrowHook"|"MorphoBorrowHook"|"MorphoRepayHook"|"MorphoRepayAndWithdrawHook"|"MorphoSupplyHook"|"MorphoWithdrawHook"|"MorphoLendHook")
            local morpho_address=""
            case $chain_id in
                "1") morpho_address="0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb" ;;
                "8453") morpho_address="0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb" ;;
                "10") morpho_address="0xce95AfbB8EA029495c66020883F87aaE8864AF92" ;;
                "42161") morpho_address="0x6c247b1F6182318877311737BaC0844bAa518F5e" ;;
                "56") morpho_address="0x01b0Bd309AA75547f7a37Ad7B1219A898E67a83a" ;;
            esac
            if [ -n "$morpho_address" ]; then
                echo "$(cast abi-encode "constructor(address)" "$morpho_address")"
            else
                echo "$(cast abi-encode "constructor()")"
            fi
            ;;
        "SuperSponsorshipPaymaster")
            local paymaster_admin="0x22BC97cFac64D6d9BCaDF5dC36e4D01Db9e929c5"
            echo "$(cast abi-encode "constructor(address,address)" "$entry_point" "$paymaster_admin")"
            ;;
        "NativeFeeSponsorship")
            echo "$(cast abi-encode "constructor()")"
            ;;
        "FetchNativeFeeHook")
            local native_fee_sponsorship=$(get_contract_address "$chain_id" "NativeFeeSponsorship")
            echo "$(cast abi-encode "constructor(address)" "$native_fee_sponsorship")"
            ;;
        "AaveV4BorrowHook"|"AaveV4RepayAndWithdrawHook"|"AaveV4RepayHook"|"AaveV4SupplyAndBorrowHook"|"AaveV4SupplyHook"|"AaveV4WithdrawHook")
            echo "$(cast abi-encode "constructor()")"
            ;;
        "CCTPSendHook"|"ApproveAndCCTPSendHook")
            echo "$(cast abi-encode "constructor(address,address)" "$cctp_v2_token_messenger" "$super_merkle_validator")"
            ;;
        "RequestRedeemDETHHook"|"ApproveAndRequestRedeemDETHHook"|"ClaimAssetsDETHHook")
            echo "$(cast abi-encode "constructor()")"
            ;;
        "SwapKyberSwapHook"|"ApproveAndSwapKyberSwapHook")
            echo "$(cast abi-encode "constructor(address,address,address)" "$kyber_router" "$kyber_scale_helper" "$native_token")"
            ;;
        "SwapAlgebraIntegralHook"|"ApproveAndSwapAlgebraIntegralHook")
            local algebra_router=""
            case $chain_id in
                "14") algebra_router="$algebra_integral_router_flare" ;;
            esac
            echo "$(cast abi-encode "constructor(address)" "$algebra_router")"
            ;;
        "SwapSparkPSMExactInHook"|"ApproveAndSwapSparkPSMExactInHook"|"SwapSparkPSMExactOutHook"|"ApproveAndSwapSparkPSMExactOutHook")
            local psm_address=""
            case $chain_id in
                "8453") psm_address="$spark_psm3_base" ;;
            esac
            echo "$(cast abi-encode "constructor(address)" "$psm_address")"
            ;;
        "SwapUniswapV2Hook"|"ApproveAndSwapUniswapV2Hook")
            local uniswap_v2_router=""
            case $chain_id in
                "14") uniswap_v2_router="$sparkdex_v2_router_flare" ;;
            esac
            echo "$(cast abi-encode "constructor(address,address)" "$uniswap_v2_router" "$native_token")"
            ;;
        "CancelDepositRequestWithId7540Hook"|"CancelRedeemRequestWithId7540Hook"|"ClaimCancelDepositRequestWithId7540Hook"|"ClaimCancelRedeemRequestWithId7540Hook"|"RedeemWithId7540VaultHook"|"WithdrawWithId7540VaultHook")
            echo "$(cast abi-encode "constructor()")"
            ;;
        "StargateAdapter"|"StargateAdapterV2")
            local lz_endpoint=""
            local token_messaging=""
            case $chain_id in
                "130"|"146"|"480"|"80094") lz_endpoint="$lz_endpoint_v2_alt" ;;
                *) lz_endpoint="$lz_endpoint_v2" ;;
            esac
            case $chain_id in
                "1") token_messaging="0x6d6620eFa72948C5f68A3C8646d58C00d3f4A980" ;;
                "8453") token_messaging="0x5634c4a5FEd09819E3c46D86A965Dd9447d86e47" ;;
                "56") token_messaging="0x6E3d884C96d640526F273C61dfcF08915eBd7e2B" ;;
                "42161") token_messaging="0x19cFCE47eD54a88614648DC3f19A5980097007dD" ;;
                "43114") token_messaging="0x17E450Be3Ba9557F2378E20d64AD417E59Ef9A34" ;;
                "14") token_messaging="0x45d417612e177672958dC0537C45a8f8d754Ac2E" ;;
                "146") token_messaging="0x2086f755A6d9254045C257ea3d382ef854849B0f" ;;
                "130") token_messaging="0xB1EeAD6959cb5bB9B20417d6689922523B2B86C3" ;;
                "100") token_messaging="0xAf368c91793CB22739386DFCbBb2F1A9e4bCBeBf" ;;
                "80094") token_messaging="0xAf5191B0De278C7286d6C7CC6ab6BB8A73bA2Cd6" ;;
            esac
            echo "$(cast abi-encode "constructor(address,address,address)" "$lz_endpoint" "$token_messaging" "$super_destination_executor")"
            ;;
        "DETHYieldSourceOracle")
            echo "$(cast abi-encode "constructor(address,address)" "$super_ledger_config" "$deth_foundation")"
            ;;
        "FirelightYieldSourceOracle"|"YoYieldSourceOracle")
            echo "$(cast abi-encode "constructor(address)" "$super_ledger_config")"
            ;;
        "PendlePTAmortizedOracle"|"PendlePTAmortizedOracleV2")
            echo "$(cast abi-encode "constructor(address,address)" "$deployer" "$super_ledger_config")"
            ;;
        # All other contracts (no constructor args)
        *)
            echo "$(cast abi-encode "constructor()")"
            ;;
    esac
}

# ── Contract Source Mapping ───────────────────────────────────────────────────
# Maps contract names to their source file paths for forge verify-contract.

get_contract_source() {
    local contract_name=$1

    case $contract_name in
        # Core contracts
        "SuperExecutor") echo "src/executors/SuperExecutor.sol" ;;
        "SuperDestinationExecutor") echo "src/executors/SuperDestinationExecutor.sol" ;;
        "AcrossV3Adapter") echo "src/adapters/AcrossV3Adapter.sol" ;;
        "AcrossV3AdapterV2") echo "src/adapters/AcrossV3AdapterV2.sol" ;;
        "DebridgeAdapter") echo "src/adapters/DebridgeAdapter.sol" ;;
        "SuperLedger") echo "src/accounting/SuperLedger.sol" ;;
        "FlatFeeLedger") echo "src/accounting/FlatFeeLedger.sol" ;;
        "SuperLedgerConfiguration") echo "src/accounting/SuperLedgerConfiguration.sol" ;;
        "SuperValidator") echo "src/validators/SuperValidator.sol" ;;
        "SuperDestinationValidator") echo "src/validators/SuperDestinationValidator.sol" ;;
        "SuperNativePaymaster") echo "src/paymaster/SuperNativePaymaster.sol" ;;
        "SuperSenderCreator") echo "src/executors/helpers/SuperSenderCreator.sol" ;;

        # Hooks - ERC20 and Token Transfers
        "ApproveERC20Hook") echo "src/hooks/tokens/erc20/ApproveERC20Hook.sol" ;;
        "TransferERC20Hook") echo "src/hooks/tokens/erc20/TransferERC20Hook.sol" ;;
        "TransferHook") echo "src/hooks/tokens/TransferHook.sol" ;;
        "BatchTransferHook") echo "src/hooks/tokens/BatchTransferHook.sol" ;;
        "BatchTransferFromHook") echo "src/hooks/tokens/permit2/BatchTransferFromHook.sol" ;;
        "OfframpTokensHook") echo "src/hooks/tokens/OfframpTokensHook.sol" ;;

        # Hooks - Vaults
        "Deposit4626VaultHook") echo "src/hooks/vaults/4626/Deposit4626VaultHook.sol" ;;
        "ApproveAndDeposit4626VaultHook") echo "src/hooks/vaults/4626/ApproveAndDeposit4626VaultHook.sol" ;;
        "Redeem4626VaultHook") echo "src/hooks/vaults/4626/Redeem4626VaultHook.sol" ;;
        "Deposit5115VaultHook") echo "src/hooks/vaults/5115/Deposit5115VaultHook.sol" ;;
        "ApproveAndDeposit5115VaultHook") echo "src/hooks/vaults/5115/ApproveAndDeposit5115VaultHook.sol" ;;
        "Redeem5115VaultHook") echo "src/hooks/vaults/5115/Redeem5115VaultHook.sol" ;;
        "RequestDeposit7540VaultHook") echo "src/hooks/vaults/7540/RequestDeposit7540VaultHook.sol" ;;
        "ApproveAndRequestDeposit7540VaultHook") echo "src/hooks/vaults/7540/ApproveAndRequestDeposit7540VaultHook.sol" ;;
        "Deposit7540VaultHook") echo "src/hooks/vaults/7540/Deposit7540VaultHook.sol" ;;
        "Redeem7540VaultHook") echo "src/hooks/vaults/7540/Redeem7540VaultHook.sol" ;;
        "RequestRedeem7540VaultHook") echo "src/hooks/vaults/7540/RequestRedeem7540VaultHook.sol" ;;
        "CancelDepositRequest7540Hook") echo "src/hooks/vaults/7540/CancelDepositRequest7540Hook.sol" ;;
        "CancelRedeemRequest7540Hook") echo "src/hooks/vaults/7540/CancelRedeemRequest7540Hook.sol" ;;
        "ClaimCancelDepositRequest7540Hook") echo "src/hooks/vaults/7540/ClaimCancelDepositRequest7540Hook.sol" ;;
        "ClaimCancelRedeemRequest7540Hook") echo "src/hooks/vaults/7540/ClaimCancelRedeemRequest7540Hook.sol" ;;
        "SetOperator7540Hook") echo "src/hooks/vaults/7540/SetOperator7540Hook.sol" ;;
        "SetSlippageHook") echo "src/hooks/vaults/7540/SetSlippageHook.sol" ;;

        # Hooks - Swappers
        "Swap1InchHook") echo "src/hooks/swappers/1inch/Swap1InchHook.sol" ;;
        "SwapOdosV2Hook") echo "src/hooks/swappers/odos/SwapOdosV2Hook.sol" ;;
        "ApproveAndSwapOdosV2Hook") echo "src/hooks/swappers/odos/ApproveAndSwapOdosV2Hook.sol" ;;
        "SwapOdosV3Hook") echo "src/hooks/swappers/odos/SwapOdosV3Hook.sol" ;;
        "ApproveAndSwapOdosV3Hook") echo "src/hooks/swappers/odos/ApproveAndSwapOdosV3Hook.sol" ;;
        "SwapOpenOceanSparkDexHook") echo "src/hooks/swappers/openocean/SwapOpenOceanSparkDexHook.sol" ;;
        "ApproveAndSwapOpenOceanSparkDexHook") echo "src/hooks/swappers/openocean/ApproveAndSwapOpenOceanSparkDexHook.sol" ;;
        "SwapUniswapV3Hook") echo "src/hooks/swappers/uniswap-v3/SwapUniswapV3Hook.sol" ;;
        "ApproveAndSwapUniswapV3Hook") echo "src/hooks/swappers/uniswap-v3/ApproveAndSwapUniswapV3Hook.sol" ;;
        "SwapUniswapV3Router02Hook") echo "src/hooks/swappers/uniswap-v3/SwapUniswapV3Router02Hook.sol" ;;
        "ApproveAndSwapUniswapV3Router02Hook") echo "src/hooks/swappers/uniswap-v3/ApproveAndSwapUniswapV3Router02Hook.sol" ;;
        "SwapUniswapV4Hook") echo "src/hooks/swappers/uniswap-v4/SwapUniswapV4Hook.sol" ;;
        "SwapKyberSwapHook") echo "src/hooks/swappers/kyberswap/SwapKyberSwapHook.sol" ;;
        "ApproveAndSwapKyberSwapHook") echo "src/hooks/swappers/kyberswap/ApproveAndSwapKyberSwapHook.sol" ;;
        "SwapAlgebraIntegralHook") echo "src/hooks/swappers/algebra-integral/SwapAlgebraIntegralHook.sol" ;;
        "ApproveAndSwapAlgebraIntegralHook") echo "src/hooks/swappers/algebra-integral/ApproveAndSwapAlgebraIntegralHook.sol" ;;
        "SwapSparkPSMExactInHook") echo "src/hooks/swappers/spark-psm/SwapSparkPSMExactInHook.sol" ;;
        "ApproveAndSwapSparkPSMExactInHook") echo "src/hooks/swappers/spark-psm/ApproveAndSwapSparkPSMExactInHook.sol" ;;
        "SwapSparkPSMExactOutHook") echo "src/hooks/swappers/spark-psm/SwapSparkPSMExactOutHook.sol" ;;
        "ApproveAndSwapSparkPSMExactOutHook") echo "src/hooks/swappers/spark-psm/ApproveAndSwapSparkPSMExactOutHook.sol" ;;
        "SwapUniswapV2Hook") echo "src/hooks/swappers/uniswap-v2/SwapUniswapV2Hook.sol" ;;
        "ApproveAndSwapUniswapV2Hook") echo "src/hooks/swappers/uniswap-v2/ApproveAndSwapUniswapV2Hook.sol" ;;
        "PendleUnifiedHook") echo "src/hooks/swappers/pendle/PendleUnifiedHook.sol" ;;
        "PendleRouterSwapHook") echo "src/hooks/swappers/pendle/PendleRouterSwapHook.sol" ;;
        "PendleRouterRedeemHook") echo "src/hooks/swappers/pendle/PendleRouterRedeemHook.sol" ;;

        # Hooks - Bridges
        "AcrossSendFundsAndExecuteOnDstHook") echo "src/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHook.sol" ;;
        "ApproveAndAcrossSendFundsAndExecuteOnDstHook") echo "src/hooks/bridges/across/ApproveAndAcrossSendFundsAndExecuteOnDstHook.sol" ;;
        "AcrossSendFundsAndExecuteOnDstHookV2") echo "src/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHookV2.sol" ;;
        "ApproveAndAcrossSendFundsAndExecuteOnDstHookV2") echo "src/hooks/bridges/across/ApproveAndAcrossSendFundsAndExecuteOnDstHookV2.sol" ;;
        "DeBridgeSendOrderAndExecuteOnDstHook") echo "src/hooks/bridges/debridge/DeBridgeSendOrderAndExecuteOnDstHook.sol" ;;
        "DeBridgeCancelOrderHook") echo "src/hooks/bridges/debridge/DeBridgeCancelOrderHook.sol" ;;
        "CCTPSendHook") echo "src/hooks/bridges/cctp/CCTPSendHook.sol" ;;
        "ApproveAndCCTPSendHook") echo "src/hooks/bridges/cctp/ApproveAndCCTPSendHook.sol" ;;

        # Hooks - Protocol Specific
        "EthenaCooldownSharesHook") echo "src/hooks/vaults/ethena/EthenaCooldownSharesHook.sol" ;;
        "EthenaUnstakeHook") echo "src/hooks/vaults/ethena/EthenaUnstakeHook.sol" ;;
        "MarkRootAsUsedHook") echo "src/hooks/superform/MarkRootAsUsedHook.sol" ;;

        # Hooks - DETH
        "RequestRedeemDETHHook") echo "src/hooks/vaults/deth/RequestRedeemDETHHook.sol" ;;
        "ApproveAndRequestRedeemDETHHook") echo "src/hooks/vaults/deth/ApproveAndRequestRedeemDETHHook.sol" ;;
        "ClaimAssetsDETHHook") echo "src/hooks/vaults/deth/ClaimAssetsDETHHook.sol" ;;

        # Hooks - 7540 WithId variants
        "CancelDepositRequestWithId7540Hook") echo "src/hooks/vaults/7540/CancelDepositRequestWithId7540Hook.sol" ;;
        "CancelRedeemRequestWithId7540Hook") echo "src/hooks/vaults/7540/CancelRedeemRequestWithId7540Hook.sol" ;;
        "ClaimCancelDepositRequestWithId7540Hook") echo "src/hooks/vaults/7540/ClaimCancelDepositRequestWithId7540Hook.sol" ;;
        "ClaimCancelRedeemRequestWithId7540Hook") echo "src/hooks/vaults/7540/ClaimCancelRedeemRequestWithId7540Hook.sol" ;;
        "RedeemWithId7540VaultHook") echo "src/hooks/vaults/7540/RedeemWithId7540VaultHook.sol" ;;
        "WithdrawWithId7540VaultHook") echo "src/hooks/vaults/7540/WithdrawWithId7540VaultHook.sol" ;;

        # Hooks - AaveV4 Loan
        "AaveV4BorrowHook") echo "src/hooks/loan/aave-v4/AaveV4BorrowHook.sol" ;;
        "AaveV4RepayAndWithdrawHook") echo "src/hooks/loan/aave-v4/AaveV4RepayAndWithdrawHook.sol" ;;
        "AaveV4RepayHook") echo "src/hooks/loan/aave-v4/AaveV4RepayHook.sol" ;;
        "AaveV4SupplyAndBorrowHook") echo "src/hooks/loan/aave-v4/AaveV4SupplyAndBorrowHook.sol" ;;
        "AaveV4SupplyHook") echo "src/hooks/loan/aave-v4/AaveV4SupplyHook.sol" ;;
        "AaveV4WithdrawHook") echo "src/hooks/loan/aave-v4/AaveV4WithdrawHook.sol" ;;

        # Hooks - Bridges (Stargate)
        "StargateSendHook") echo "src/hooks/bridges/stargate/StargateSendHook.sol" ;;
        "ApproveAndStargateSendHook") echo "src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol" ;;
        "StargateSendHookV2") echo "src/hooks/bridges/stargate/StargateSendHookV2.sol" ;;
        "ApproveAndStargateSendHookV2") echo "src/hooks/bridges/stargate/ApproveAndStargateSendHookV2.sol" ;;

        # Hooks - Claim
        "MerklClaimRewardHook") echo "src/hooks/claim/merkl/MerklClaimRewardHook.sol" ;;
        "FluidClaimRewardHook") echo "src/hooks/claim/fluid/FluidClaimRewardHook.sol" ;;
        "GearboxClaimRewardHook") echo "src/hooks/claim/gearbox/GearboxClaimRewardHook.sol" ;;
        "YearnClaimOneRewardHook") echo "src/hooks/claim/yearn/YearnClaimOneRewardHook.sol" ;;
        "ClaimRFLRHook") echo "src/hooks/claim/flare/ClaimRFLRHook.sol" ;;
        "WithdrawRFLRHook") echo "src/hooks/claim/flare/WithdrawRFLRHook.sol" ;;
        "WithdrawVestedRFLRHook") echo "src/hooks/claim/flare/WithdrawVestedRFLRHook.sol" ;;

        # Hooks - Circle Gateway
        "CircleGatewayWalletHook") echo "src/hooks/bridges/circle/CircleGatewayWalletHook.sol" ;;
        "CircleGatewayMinterHook") echo "src/hooks/bridges/circle/CircleGatewayMinterHook.sol" ;;
        "CircleGatewayAddDelegateHook") echo "src/hooks/bridges/circle/CircleGatewayAddDelegateHook.sol" ;;
        "CircleGatewayRemoveDelegateHook") echo "src/hooks/bridges/circle/CircleGatewayRemoveDelegateHook.sol" ;;

        # Hooks - Pendle PT Amortized Oracle
        "RecordPurchasePendlePTAmortizedOracleHook") echo "src/hooks/oracles/pendle/RecordPurchasePendlePTAmortizedOracleHook.sol" ;;
        "RecordRedemptionPendlePTAmortizedOracleHook") echo "src/hooks/oracles/pendle/RecordRedemptionPendlePTAmortizedOracleHook.sol" ;;
        "RecordPurchasePendlePTAmortizedOracleHookV2") echo "src/hooks/oracles/pendle/RecordPurchasePendlePTAmortizedOracleHookV2.sol" ;;
        "RecordRedemptionPendlePTAmortizedOracleHookV2") echo "src/hooks/oracles/pendle/RecordRedemptionPendlePTAmortizedOracleHookV2.sol" ;;

        # Hooks - Firelight Vault
        "RedeemFirelightVaultHook") echo "src/hooks/vaults/firelight/RedeemFirelightVaultHook.sol" ;;
        "ClaimWithdrawFirelightVaultHook") echo "src/hooks/vaults/firelight/ClaimWithdrawFirelightVaultHook.sol" ;;

        # Hooks - Morpho Loan
        "MorphoSupplyAndBorrowHook") echo "src/hooks/loan/morpho/MorphoSupplyAndBorrowHook.sol" ;;
        "MorphoBorrowHook") echo "src/hooks/loan/morpho/MorphoBorrowHook.sol" ;;
        "MorphoRepayHook") echo "src/hooks/loan/morpho/MorphoRepayHook.sol" ;;
        "MorphoRepayAndWithdrawHook") echo "src/hooks/loan/morpho/MorphoRepayAndWithdrawHook.sol" ;;
        "MorphoSupplyHook") echo "src/hooks/loan/morpho/MorphoSupplyHook.sol" ;;
        "MorphoWithdrawHook") echo "src/hooks/loan/morpho/MorphoWithdrawHook.sol" ;;
        "MorphoLendHook") echo "src/hooks/loan/morpho/MorphoLendHook.sol" ;;
        "MetaMorphoReallocateHook") echo "src/hooks/vaults/metamorpho/MetaMorphoReallocateHook.sol" ;;
        "ForceDeallocateMorphoHook") echo "src/hooks/vaults/metamorpho/ForceDeallocateMorphoHook.sol" ;;

        # Sponsorship
        "SuperSponsorshipPaymaster") echo "src/paymaster/SuperSponsorshipPaymaster.sol" ;;
        "NativeFeeSponsorship") echo "src/sponsorship/NativeFeeSponsorship.sol" ;;
        "FetchNativeFeeHook") echo "src/hooks/sponsorship/FetchNativeFeeHook.sol" ;;

        # Adapters
        "StargateAdapter") echo "src/adapters/StargateAdapter.sol" ;;
        "StargateAdapterV2") echo "src/adapters/StargateAdapterV2.sol" ;;

        # Oracles
        "ERC4626YieldSourceOracle") echo "src/accounting/oracles/ERC4626YieldSourceOracle.sol" ;;
        "ERC5115YieldSourceOracle") echo "src/accounting/oracles/ERC5115YieldSourceOracle.sol" ;;
        "ERC7540YieldSourceOracle") echo "src/accounting/oracles/ERC7540YieldSourceOracle.sol" ;;
        "PendlePTYieldSourceOracle") echo "src/accounting/oracles/PendlePTYieldSourceOracle.sol" ;;
        "SpectraPTYieldSourceOracle") echo "src/accounting/oracles/SpectraPTYieldSourceOracle.sol" ;;
        "SpectraMetaVaultOracle") echo "src/accounting/oracles/SpectraMetaVaultOracle.sol" ;;
        "StakingYieldSourceOracle") echo "src/accounting/oracles/StakingYieldSourceOracle.sol" ;;
        "SuperYieldSourceOracle") echo "src/accounting/oracles/SuperYieldSourceOracle.sol" ;;
        "SuperVaultYieldSourceOracle") echo "src/accounting/oracles/SuperVaultYieldSourceOracle.sol" ;;
        "DETHYieldSourceOracle") echo "src/accounting/oracles/DETHYieldSourceOracle.sol" ;;
        "FirelightYieldSourceOracle") echo "src/accounting/oracles/FirelightYieldSourceOracle.sol" ;;
        "YoYieldSourceOracle") echo "src/accounting/oracles/YoYieldSourceOracle.sol" ;;
        "PendlePTAmortizedOracle") echo "src/accounting/oracles/PendlePTAmortizedOracle.sol" ;;
        "PendlePTAmortizedOracleV2") echo "src/accounting/oracles/PendlePTAmortizedOracleV2.sol" ;;

        # Nexus contracts (external library - skip verification from this repo)
        "Nexus"|"NexusAccountFactory"|"NexusBootstrap"|"NexusProxy")
            echo "SKIP_EXTERNAL_LIB"
            ;;

        *) echo "src/core/unknown/$contract_name.sol" ;;
    esac
}

# ── Verification ──────────────────────────────────────────────────────────────

# Verify a single contract on a block explorer.
# Appends to VERIFIED_CONTRACTS, FAILED_CONTRACTS, or SKIPPED_CONTRACTS.
verify_contract() {
    local chain_id=$1
    local contract_name=$2
    local contract_address=$3
    local constructor_args=$4
    local source_file=$5
    local rpc_url=$6

    echo -e "${YELLOW}   Verifying $contract_name...${NC}"
    echo -e "${CYAN}      Address: $contract_address${NC}"
    echo -e "${CYAN}      Source: $source_file${NC}"

    # Skip external library contracts
    if [ "$source_file" = "SKIP_EXTERNAL_LIB" ]; then
        echo -e "${YELLOW}   Skipping $contract_name (external library contract)${NC}"
        SKIPPED_CONTRACTS+=("$contract_name @ chain $chain_id")
        return 0
    fi

    local verify_exit_code=0

    # Chain-specific verifier configuration
    case $chain_id in
        "14")
            # Flare uses Blockscout explorer
            forge verify-contract "$contract_address" "$source_file:$contract_name" \
                --constructor-args "$constructor_args" \
                --verifier blockscout \
                --verifier-url "https://flare-explorer.flare.network/api/" \
                --skip-is-verified-check
            verify_exit_code=$?
            ;;
        "988"|"999"|"80094")
            # Chains not in forge's internal registry: use Etherscan V2 API with chainid
            forge verify-contract "$contract_address" "$source_file:$contract_name" \
                --constructor-args "$constructor_args" \
                --etherscan-api-key "$ETHERSCANV2_API_KEY" \
                --verifier etherscan \
                --verifier-url "https://api.etherscan.io/v2/api?chainid=${chain_id}"
            verify_exit_code=$?
            ;;
        *)
            forge verify-contract "$contract_address" "$source_file:$contract_name" \
                --constructor-args "$constructor_args" \
                --rpc-url "$rpc_url" \
                --chain "$chain_id" \
                --etherscan-api-key "$ETHERSCANV2_API_KEY" \
                --verifier etherscan
            verify_exit_code=$?
            ;;
    esac

    if [ $verify_exit_code -eq 0 ]; then
        echo -e "${GREEN}   $contract_name verified successfully${NC}"
        VERIFIED_CONTRACTS+=("$contract_name @ chain $chain_id")
    else
        echo -e "${RED}   $contract_name verification failed${NC}"
        FAILED_CONTRACTS+=("$contract_name @ chain $chain_id")
    fi

    echo ""
}

# Verify all contracts for a single network.
verify_network() {
    local chain_id=$1

    local network_name
    network_name=$(get_network_name "$chain_id")
    if [ $? -ne 0 ]; then
        echo -e "${RED}Unknown network ID: $chain_id${NC}"
        return 1
    fi

    local rpc_url
    rpc_url=$(get_rpc_url "$chain_id")

    # Blockscout-verified chains don't need RPC
    local uses_blockscout=false
    case $chain_id in
        "14") uses_blockscout=true ;;
    esac
    if [ -z "$rpc_url" ] && [ "$uses_blockscout" = false ]; then
        echo -e "${RED}RPC URL not found for chain $chain_id ($network_name)${NC}"
        return 1
    fi

    print_network_header "$network_name"
    echo -e "${CYAN}   Chain ID: ${WHITE}$chain_id${NC}"
    echo -e "${CYAN}   Verification: ${WHITE}Etherscan V2${NC}"

    # Get JSON file path using network name (no hardcoded suffix mapping needed)
    local json_file
    json_file=$(get_output_json "$chain_id")

    if [ ! -f "$json_file" ]; then
        echo -e "${RED}   Contract addresses file not found: $json_file${NC}"
        echo -e "${YELLOW}   Make sure contracts have been deployed to this network first${NC}"
        return 1
    fi

    echo -e "${CYAN}   Loading addresses from: $json_file${NC}"

    # Extract contract names from JSON
    local all_contract_names
    all_contract_names=($(jq -r 'keys[]' "$json_file"))
    local contract_names=()

    # Apply contract filter if specified
    if [ ${#CONTRACTS_TO_VERIFY[@]} -eq 0 ]; then
        contract_names=("${all_contract_names[@]}")
        echo -e "${CYAN}   Verifying all ${#contract_names[@]} deployed contracts...${NC}"
    else
        echo -e "${CYAN}   Contract filter active: ${CONTRACTS_TO_VERIFY[*]}${NC}"
        for contract_name in "${CONTRACTS_TO_VERIFY[@]}"; do
            local found=false
            for deployed_contract in "${all_contract_names[@]}"; do
                if [ "$deployed_contract" = "$contract_name" ]; then
                    contract_names+=("$contract_name")
                    found=true
                    break
                fi
            done
            if [ "$found" = false ]; then
                echo -e "${YELLOW}      Warning: $contract_name not found in deployment, skipping${NC}"
            fi
        done
    fi

    echo -e "${CYAN}   Verifying ${#contract_names[@]} contracts...${NC}"

    for contract_name in "${contract_names[@]}"; do
        local contract_address
        contract_address=$(jq -r ".$contract_name // empty" "$json_file")

        if [ -z "$contract_address" ] || [ "$contract_address" = "null" ]; then
            echo -e "${YELLOW}   Skipping $contract_name (address not found)${NC}"
            SKIPPED_CONTRACTS+=("$contract_name @ chain $chain_id (no address)")
            continue
        fi

        local constructor_args
        constructor_args=$(generate_constructor_args "$contract_name" "$chain_id")
        local source_file
        source_file=$(get_contract_source "$contract_name")

        verify_contract "$chain_id" "$contract_name" "$contract_address" "$constructor_args" "$source_file" "$rpc_url"

        # Rate limit protection
        if [ "$VERIFY_DELAY" -gt 0 ]; then
            sleep "$VERIFY_DELAY"
        fi
    done

    echo -e "${GREEN}Network $network_name verification completed${NC}"
}

# ── Post-Verification Status Check ────────────────────────────────────────────
# After all forge verify-contract calls, query block explorer APIs to check
# which contracts are actually verified on-chain vs still unverified.

# Check if a single contract is verified on the block explorer.
# Returns 0 if verified, 1 if not verified or unknown.
is_contract_verified() {
    local chain_id=$1
    local address=$2
    local response=""

    case $chain_id in
        "14")
            # Flare uses Blockscout
            response=$(curl -s --max-time 10 \
                "https://flare-explorer.flare.network/api/?module=contract&action=getsourcecode&address=$address" \
                2>/dev/null)
            ;;
        *)
            # All other chains use Etherscan V2 API
            response=$(curl -s --max-time 10 \
                "https://api.etherscan.io/v2/api?chainid=${chain_id}&module=contract&action=getsourcecode&address=${address}&apikey=${ETHERSCANV2_API_KEY}" \
                2>/dev/null)
            ;;
    esac

    if [[ -z "$response" ]]; then
        return 1  # Request failed
    fi

    # Check if SourceCode field is non-empty (verified contract)
    local source_code
    source_code=$(echo "$response" | jq -r '.result[0].SourceCode // empty' 2>/dev/null)

    if [[ -n "$source_code" && "$source_code" != "null" ]]; then
        return 0  # Verified
    else
        return 1  # Not verified
    fi
}

# Sweep all deployed contracts across all chains and report which are still unverified.
# Uses the same chain list and contract filters as the verification run.
check_all_verification_status() {
    local -n chain_list=$1  # nameref to chains array

    print_separator
    echo -e "${BLUE}Checking on-chain verification status for all deployed contracts...${NC}"
    echo ""

    local total_checked=0
    local total_verified=0
    local total_unverified=0
    local total_errors=0
    declare -a UNVERIFIED_REPORT=()
    local has_unverified=false

    for chain_id in "${chain_list[@]}"; do
        local network_name
        network_name=$(get_network_name "$chain_id" 2>/dev/null) || continue

        local json_file
        json_file=$(get_output_json "$chain_id") || continue
        [[ ! -f "$json_file" ]] && continue

        # Get contract list (apply filter if set)
        local all_contract_names
        all_contract_names=($(jq -r 'keys[]' "$json_file" 2>/dev/null))
        local contract_names=()

        if [ ${#CONTRACTS_TO_VERIFY[@]} -eq 0 ]; then
            contract_names=("${all_contract_names[@]}")
        else
            for cn in "${CONTRACTS_TO_VERIFY[@]}"; do
                for deployed in "${all_contract_names[@]}"; do
                    if [ "$deployed" = "$cn" ]; then
                        contract_names+=("$cn")
                        break
                    fi
                done
            done
        fi

        local chain_verified=0
        local chain_unverified=0
        local chain_errors=0
        local chain_unverified_list=()

        echo -e "${CYAN}   Checking $network_name (chain $chain_id) — ${#contract_names[@]} contracts...${NC}"

        for contract_name in "${contract_names[@]}"; do
            local addr
            addr=$(jq -r ".$contract_name // empty" "$json_file" 2>/dev/null)
            [[ -z "$addr" || "$addr" == "null" ]] && continue

            # Skip external library contracts
            local source_file
            source_file=$(get_contract_source "$contract_name")
            if [ "$source_file" = "SKIP_EXTERNAL_LIB" ]; then
                continue
            fi

            total_checked=$((total_checked + 1))

            if is_contract_verified "$chain_id" "$addr"; then
                chain_verified=$((chain_verified + 1))
                total_verified=$((total_verified + 1))
            else
                chain_unverified=$((chain_unverified + 1))
                total_unverified=$((total_unverified + 1))
                chain_unverified_list+=("$contract_name ($addr)")
            fi

            # Rate limit: 1 request per second to avoid API throttling
            sleep 1
        done

        if [ ${#chain_unverified_list[@]} -gt 0 ]; then
            has_unverified=true
            echo -e "${RED}      $network_name: ${chain_unverified} unverified, ${chain_verified} verified${NC}"
            for entry in "${chain_unverified_list[@]}"; do
                echo -e "${RED}        - $entry${NC}"
                UNVERIFIED_REPORT+=("$network_name: $entry")
            done
        else
            echo -e "${GREEN}      $network_name: all ${chain_verified} contracts verified${NC}"
        fi
    done

    # ── Verification Status Report ────────────────────────────────────────────
    echo ""
    print_separator
    echo -e "${BLUE}On-Chain Verification Status Report:${NC}"
    echo -e "${CYAN}   Total checked:    ${WHITE}$total_checked${NC}"
    echo -e "${CYAN}   Verified:         ${GREEN}$total_verified${NC}"
    echo -e "${CYAN}   Unverified:       ${RED}$total_unverified${NC}"

    if [ "$has_unverified" = true ]; then
        echo ""
        echo -e "${RED}   Unverified contracts:${NC}"
        for entry in "${UNVERIFIED_REPORT[@]}"; do
            echo -e "${RED}     - $entry${NC}"
        done
        echo ""
        echo -e "${YELLOW}   These contracts need manual verification or re-running the verify script.${NC}"
        return 1
    else
        echo ""
        echo -e "${GREEN}   All deployed contracts are verified on their respective block explorers.${NC}"
        return 0
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
    local chains=()

    if [ ${#CHAINS_TO_VERIFY[@]} -eq 0 ]; then
        echo -e "${CYAN}No chain filter specified, verifying all configured networks...${NC}"
        for network_def in "${NETWORKS[@]}"; do
            IFS=':' read -r network_id _ _ <<< "$network_def"
            chains+=("$network_id")
        done
    else
        echo -e "${CYAN}Chain filter active: ${CHAINS_TO_VERIFY[*]}${NC}"
        for chain_id in "${CHAINS_TO_VERIFY[@]}"; do
            local found=false
            for network_def in "${NETWORKS[@]}"; do
                IFS=':' read -r network_id _ _ <<< "$network_def"
                if [ "$network_id" = "$chain_id" ]; then
                    chains+=("$chain_id")
                    found=true
                    break
                fi
            done
            if [ "$found" = false ]; then
                echo -e "${YELLOW}Warning: Chain $chain_id not found in network configuration, skipping${NC}"
            fi
        done
    fi

    if [ ${#CONTRACTS_TO_VERIFY[@]} -gt 0 ]; then
        echo -e "${CYAN}Contract filter: ${CONTRACTS_TO_VERIFY[*]}${NC}"
    fi

    echo -e "${BLUE}Starting verification for ${#chains[@]} networks in $ENVIRONMENT environment...${NC}"
    echo ""

    local successful_networks=0
    local failed_networks=0

    for chain_id in "${chains[@]}"; do
        if verify_network "$chain_id"; then
            successful_networks=$((successful_networks + 1))
        else
            failed_networks=$((failed_networks + 1))
        fi
        print_separator
    done

    # ── Summary ───────────────────────────────────────────────────────────────
    print_separator
    echo -e "${BLUE}Verification Summary:${NC}"
    echo -e "${CYAN}   Networks:   ${GREEN}$successful_networks passed${NC}   ${RED}$failed_networks failed${NC}"
    echo -e "${CYAN}   Contracts:  ${GREEN}${#VERIFIED_CONTRACTS[@]} verified${NC}   ${RED}${#FAILED_CONTRACTS[@]} failed${NC}   ${YELLOW}${#SKIPPED_CONTRACTS[@]} skipped${NC}"

    if [ ${#FAILED_CONTRACTS[@]} -gt 0 ]; then
        echo ""
        echo -e "${RED}   Failed contracts:${NC}"
        for failed in "${FAILED_CONTRACTS[@]}"; do
            echo -e "${RED}     - $failed${NC}"
        done
    fi

    if [ ${#SKIPPED_CONTRACTS[@]} -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}   Skipped contracts:${NC}"
        for skipped in "${SKIPPED_CONTRACTS[@]}"; do
            echo -e "${YELLOW}     - $skipped${NC}"
        done
    fi

    echo ""

    # ── Post-verification: check actual on-chain verification status ──────
    local verification_status_ok=true
    check_all_verification_status chains || verification_status_ok=false

    # ── Final result ──────────────────────────────────────────────────────
    echo ""
    if [ $failed_networks -eq 0 ] && [ ${#FAILED_CONTRACTS[@]} -eq 0 ] && [ "$verification_status_ok" = true ]; then
        echo -e "${GREEN}All V2 Core $ENVIRONMENT contract verification completed successfully${NC}"
    else
        echo -e "${YELLOW}V2 Core $ENVIRONMENT verification completed with issues${NC}"
        exit 1
    fi
}

# Run
main
