# Note: How to set defaultKey - https://www.youtube.com/watch?v=VQe7cIpaE54

export BASE_SEPOLIA=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_SEPOLIA_RPC_URL/credential)
export OP_SEPOLIA=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/OP_SEPOLIA_RPC_URL/credential)
export SEPOLIA=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/SEPOLIA_RPC_URL/credential)

# constructor args; update per chain
empty_arg="$(cast abi-encode "constructor()")"
owner_address="0xc285CEfc89c3c2e7714f3524a68efFE21C00AE55"
treasury_address="0xc285CEfc89c3c2e7714f3524a68efFE21C00AE55"
polymer_prover="0xc285CEfc89c3c2e7714f3524a68efFE21C00AE55"
superDeployer_arg="$empty_arg"
superGovernor_arg="$(cast abi-encode "constructor(address,address,address,address,address)" "$owner_address" "$owner_address" "$owner_address" "$treasury_address" "$polymer_prover")"
superOracle_arg="$(cast abi-encode "constructor(address,address[],address[],uint256[],bytes32[])" "$owner_address" "[]" "[]" "[]" "[]")"
superLedgerConfiguration_arg="$empty_arg"
superMerkleValidator_arg="$empty_arg"
superDestinationValidator_arg="$empty_arg"
superExecutor_arg="$(cast abi-encode "constructor(address)" "0x014E230a31F8e80A299abCFC3aC806663b25a1F6")"
superDestinationExecutor_arg="$(cast abi-encode "constructor(address,address,address)" "0x014E230a31F8e80A299abCFC3aC806663b25a1F6" "0x3B6F3904E2e741FDd54Aa8b1ef3892263A0B7645" "0x0000000000000000000000000000000000000000")"
acrossV3Adapter_arg="$(cast abi-encode "constructor(address,address)" "0x82B564983aE7274c86695917BBf8C99ECb6F0F8F" "0xe03cAed05bCd579AD23bF926f4D935b5aA30aB2b")"
debridgeAdapter_arg="$(cast abi-encode "constructor(address,address)" "0xE7351Fd770A37282b91D153Ee690B63579D6dd7f" "0xe03cAed05bCd579AD23bF926f4D935b5aA30aB2b")"
superLedger_arg="$(cast abi-encode "constructor(address,address[])" "0x014E230a31F8e80A299abCFC3aC806663b25a1F6" "[0x388a367804e93988f376295EfA44beE13b48eb02, 0xe03cAed05bCd579AD23bF926f4D935b5aA30aB2b]")"
erc5115Ledger_arg="$(cast abi-encode "constructor(address,address[])" "0x014E230a31F8e80A299abCFC3aC806663b25a1F6" "[0x388a367804e93988f376295EfA44beE13b48eb02, 0xe03cAed05bCd579AD23bF926f4D935b5aA30aB2b]")"
superNativePaymaster_arg="$(cast abi-encode "constructor(address)" "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789")"
superVaultAggregator_arg="$(cast abi-encode "constructor(address)" "0x5b29e053B647ef36f1976C95A69c90A2A798eF85")"
ecdsappsOracle_arg="$(cast abi-encode "constructor(address)" "0x5b29e053B647ef36f1976C95A69c90A2A798eF85")"
baseHook_arg="$empty_arg"
approveERC20Hook_arg="$baseHook_arg"
transferERC20Hook_arg="$baseHook_arg"
permit2_address="0x000000000022D473030F116dDEE9F6B43aC78BA3"
batchTransferFromHook_arg="$(cast abi-encode "constructor(address)" "$permit2_address")"
deposit4626VaultHook_arg="$baseHook_arg"
approveAndDeposit4626VaultHook_arg="$baseHook_arg"
redeem4626VaultHook_arg="$baseHook_arg"
approveAndRedeem4626VaultHook_arg="$baseHook_arg"
deposit5115VaultHook_arg="$baseHook_arg"
approveAndDeposit5115VaultHook_arg="$baseHook_arg"
redeem5115VaultHook_arg="$baseHook_arg"
approveAndRedeem5115VaultHook_arg="$baseHook_arg"
requestDeposit7540VaultHook_arg="$baseHook_arg"
approveAndRequestDeposit7540VaultHook_arg="$baseHook_arg"
requestRedeem7540VaultHook_arg="$baseHook_arg"
deposit7540VaultHook_arg="$baseHook_arg"
withdraw7540VaultHook_arg="$baseHook_arg"
approveAndRedeem7540VaultHook_arg="$baseHook_arg"
aggregation_router="0x1111111254EEB25477B68fb85Ed929f73A960582"
odos_router="0x4E3288c9ca110bCC82bf38F09A7b425c095d92Bf"
swap1InchHook_arg="$(cast abi-encode "constructor(address)" "$aggregation_router")"
swapOdosHook_arg="$(cast abi-encode "constructor(address)" "$odos_router")"
approveAndSwapOdosHook_arg="$(cast abi-encode "constructor(address)" "$odos_router")"
across_spokepool="0x0000000000000000000000000000000000000000"
debridge_dln="0x0000000000000000000000000000000000000000"
acrossSendFundsAndExecuteOnDstHook_arg="$(cast abi-encode "constructor(address,address)" "$across_spokepool" "0xe10863a904c89bda74c1Eb70Fa83Df57a18eEadA")"
deBridgeSendOrderAndExecuteOnDstHook_arg="$(cast abi-encode "constructor(address,address)" "$debridge_dln" "0xe10863a904c89bda74c1Eb70Fa83Df57a18eEadA")"
fluidClaimRewardHook_arg="$baseHook_arg"
gearboxClaimRewardHook_arg="$baseHook_arg"
fluidStakeHook_arg="$baseHook_arg"
approveAndFluidStakeHook_arg="$baseHook_arg"
fluidUnstakeHook_arg="$baseHook_arg"
gearboxStakeHook_arg="$baseHook_arg"
gearboxApproveAndStakeHook_arg="$baseHook_arg"
gearboxUnstakeHook_arg="$baseHook_arg"
yearnClaimOneRewardHook_arg="$baseHook_arg"
ethenaCooldownSharesHook_arg="$baseHook_arg"
ethenaUnstakeHook_arg="$baseHook_arg"

# Spectra and Pendle Hooks
spectra_router="0x0000000000000000000000000000000000000000"
pendle_router="0x0000000000000000000000000000000000000000"
spectraExchangeHook_arg="$(cast abi-encode "constructor(address)" "$spectra_router")"
pendleRouterSwapHook_arg="$(cast abi-encode "constructor(address)" "$pendle_router")"
pendleRouterRedeemHook_arg="$(cast abi-encode "constructor(address)" "$pendle_router")"

# 7540 Cancel Hooks
cancelDepositRequest7540Hook_arg="$baseHook_arg"
cancelRedeemRequest7540Hook_arg="$baseHook_arg"
claimCancelDepositRequest7540Hook_arg="$baseHook_arg"
claimCancelRedeemRequest7540Hook_arg="$baseHook_arg"
cancelRedeemHook_arg="$baseHook_arg"

# Morpho Hooks
morpho_address="0x64c7044050Ba0431252df24fEd4d9635a275CB41"
morphoBorrowHook_arg="$(cast abi-encode "constructor(address)" "$morpho_address")"
morphoRepayHook_arg="$(cast abi-encode "constructor(address)" "$morpho_address")"
morphoRepayAndWithdrawHook_arg="$(cast abi-encode "constructor(address)" "$morpho_address")"

# Yield Source Oracles
erc4626YieldSourceOracle_arg="$empty_arg"
erc5115YieldSourceOracle_arg="$empty_arg"
erc7540YieldSourceOracle_arg="$empty_arg"
pendlePTYieldSourceOracle_arg="$empty_arg"
spectraPTYieldSourceOracle_arg="$empty_arg"
stakingYieldSourceOracle_arg="$empty_arg"

# networks
networks=(11155111 11155420 84532)  # Sepolia, Op Sepolia, Base Sepolia

# rpc urls
rpc_urls=("$SEPOLIA" "$OP_SEPOLIA" "$BASE_SEPOLIA")

# define files to verify
files_to_verify=(
    "script/utils/SuperDeployer.sol"
    "src/periphery/SuperGovernor.sol"
    "src/periphery/oracles/SuperOracle.sol"
    "src/core/accounting/SuperLedgerConfiguration.sol"
    "src/core/validators/SuperMerkleValidator.sol"
    "src/core/validators/SuperDestinationValidator.sol"
    "src/core/executors/SuperExecutor.sol"
    "src/core/executors/SuperDestinationExecutor.sol"
    "src/core/adapters/AcrossV3Adapter.sol"
    "src/core/adapters/DebridgeAdapter.sol"
    "src/core/accounting/SuperLedger.sol"
    "src/core/accounting/ERC5115Ledger.sol"
    "src/core/paymaster/SuperNativePaymaster.sol"
    "src/periphery/SuperVault/SuperVaultAggregator.sol"
    "src/periphery/oracles/ECDSAPPSOracle.sol"
    "src/core/hooks/tokens/erc20/ApproveERC20Hook.sol"
    "src/core/hooks/tokens/erc20/TransferERC20Hook.sol"
    "src/core/hooks/tokens/permit2/BatchTransferFromHook.sol"
    "src/core/hooks/vaults/4626/Deposit4626VaultHook.sol"
    "src/core/hooks/vaults/4626/ApproveAndDeposit4626VaultHook.sol"
    "src/core/hooks/vaults/4626/Redeem4626VaultHook.sol"
    "src/core/hooks/vaults/4626/ApproveAndRedeem4626VaultHook.sol"
    "src/core/hooks/vaults/5115/Deposit5115VaultHook.sol"
    "src/core/hooks/vaults/5115/ApproveAndDeposit5115VaultHook.sol"
    "src/core/hooks/vaults/5115/Redeem5115VaultHook.sol"
    "src/core/hooks/vaults/5115/ApproveAndRedeem5115VaultHook.sol"
    "src/core/hooks/vaults/7540/RequestDeposit7540VaultHook.sol"
    "src/core/hooks/vaults/7540/ApproveAndRequestDeposit7540VaultHook.sol"
    "src/core/hooks/vaults/7540/RequestRedeem7540VaultHook.sol"
    "src/core/hooks/vaults/7540/Deposit7540VaultHook.sol"
    "src/core/hooks/vaults/7540/Withdraw7540VaultHook.sol"
    "src/core/hooks/vaults/7540/ApproveAndRedeem7540VaultHook.sol"
    "src/core/hooks/swappers/1inch/Swap1InchHook.sol"
    "src/core/hooks/swappers/odos/SwapOdosHook.sol"
    "src/core/hooks/swappers/odos/ApproveAndSwapOdosHook.sol"
    "src/core/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHook.sol"
    "src/core/hooks/bridges/debridge/DeBridgeSendOrderAndExecuteOnDstHook.sol"
    "src/core/hooks/claim/fluid/FluidClaimRewardHook.sol"
    "src/core/hooks/stake/fluid/FluidStakeHook.sol"
    "src/core/hooks/stake/fluid/ApproveAndFluidStakeHook.sol"
    "src/core/hooks/stake/fluid/FluidUnstakeHook.sol"
    "src/core/hooks/claim/gearbox/GearboxClaimRewardHook.sol"
    "src/core/hooks/stake/gearbox/GearboxStakeHook.sol"
    "src/core/hooks/stake/gearbox/ApproveAndGearboxStakeHook.sol"
    "src/core/hooks/stake/gearbox/GearboxUnstakeHook.sol"
    "src/core/hooks/claim/yearn/YearnClaimOneRewardHook.sol"
    "src/core/hooks/vaults/ethena/EthenaCooldownSharesHook.sol"
    "src/core/hooks/vaults/ethena/EthenaUnstakeHook.sol"
    "src/core/hooks/swappers/spectra/SpectraExchangeHook.sol"
    "src/core/hooks/swappers/pendle/PendleRouterSwapHook.sol"
    "src/core/hooks/swappers/pendle/PendleRouterRedeemHook.sol"
    "src/core/hooks/vaults/7540/CancelDepositRequest7540Hook.sol"
    "src/core/hooks/vaults/7540/CancelRedeemRequest7540Hook.sol"
    "src/core/hooks/vaults/7540/ClaimCancelDepositRequest7540Hook.sol"
    "src/core/hooks/vaults/7540/ClaimCancelRedeemRequest7540Hook.sol"
    "src/core/hooks/vaults/super-vault/CancelRedeemHook.sol"
    "src/core/hooks/loan/morpho/MorphoBorrowHook.sol"
    "src/core/hooks/loan/morpho/MorphoRepayHook.sol"
    "src/core/hooks/loan/morpho/MorphoRepayAndWithdrawHook.sol"
    "src/core/accounting/oracles/ERC4626YieldSourceOracle.sol"
    "src/core/accounting/oracles/ERC5115YieldSourceOracle.sol"
    "src/core/accounting/oracles/ERC7540YieldSourceOracle.sol"
    "src/core/accounting/oracles/PendlePTYieldSourceOracle.sol"
    "src/core/accounting/oracles/SpectraPTYieldSourceOracle.sol"
    "src/core/accounting/oracles/StakingYieldSourceOracle.sol"
)

# define contract names
contract_names=(
    "SuperDeployer"
    "SuperGovernor"
    "SuperOracle"
    "SuperLedgerConfiguration"
    "SuperMerkleValidator"
    "SuperDestinationValidator"
    "SuperExecutor"
    "SuperDestinationExecutor"
    "AcrossV3Adapter"
    "DebridgeAdapter"
    "SuperLedger"
    "ERC5115Ledger"
    "SuperNativePaymaster"
    "SuperVaultAggregator"
    "ECDSAPPSOracle"
    "ApproveERC20Hook"
    "TransferERC20Hook"
    "BatchTransferFromHook"
    "Deposit4626VaultHook"
    "ApproveAndDeposit4626VaultHook"
    "Redeem4626VaultHook"
    "ApproveAndRedeem4626VaultHook"
    "Deposit5115VaultHook"
    "ApproveAndDeposit5115VaultHook"
    "Redeem5115VaultHook"
    "ApproveAndRedeem5115VaultHook"
    "RequestDeposit7540VaultHook"
    "ApproveAndRequestDeposit7540VaultHook"
    "RequestRedeem7540VaultHook"
    "Deposit7540VaultHook"
    "Withdraw7540VaultHook"
    "ApproveAndRedeem7540VaultHook"
    "Swap1InchHook"
    "SwapOdosHook"
    "ApproveAndSwapOdosHook"
    "AcrossSendFundsAndExecuteOnDstHook"
    "DeBridgeSendOrderAndExecuteOnDstHook"
    "FluidClaimRewardHook"
    "FluidStakeHook"
    "ApproveAndFluidStakeHook"
    "FluidUnstakeHook"
    "GearboxClaimRewardHook"
    "GearboxStakeHook"
    "ApproveAndGearboxStakeHook"
    "GearboxUnstakeHook"
    "YearnClaimOneRewardHook"
    "EthenaCooldownSharesHook"
    "EthenaUnstakeHook"
    "SpectraExchangeHook"
    "PendleRouterSwapHook"
    "PendleRouterRedeemHook"
    "CancelDepositRequest7540Hook"
    "CancelRedeemRequest7540Hook"
    "ClaimCancelDepositRequest7540Hook"
    "ClaimCancelRedeemRequest7540Hook"
    "CancelRedeemHook"
    "MorphoBorrowHook"
    "MorphoRepayHook"
    "MorphoRepayAndWithdrawHook"
    "ERC4626YieldSourceOracle"
    "ERC5115YieldSourceOracle"
    "ERC7540YieldSourceOracle"
    "PendlePTYieldSourceOracle"
    "SpectraPTYieldSourceOracle"
    "StakingYieldSourceOracle"
)

# define contract addresses
contract_addresses=(
    "0x43A2461DF5f4d6c5CBe78689D1bE50a7A2a53804" # SuperDeployer
    "0x5b29e053B647ef36f1976C95A69c90A2A798eF85" # SuperGovernor
    "0x2c93DE8ADadf92284F23670873C00056cA826d31" # SuperOracle
    "0x014E230a31F8e80A299abCFC3aC806663b25a1F6" # SuperLedgerConfiguration
    "0xe10863a904c89bda74c1Eb70Fa83Df57a18eEadA" # SuperMerkleValidator
    "0x3B6F3904E2e741FDd54Aa8b1ef3892263A0B7645" # SuperDestinationValidator
    "0x388a367804e93988f376295EfA44beE13b48eb02" # SuperExecutor
    "0xe03cAed05bCd579AD23bF926f4D935b5aA30aB2b" # SuperDestinationExecutor
    "0x1c0331c97F1Da45932fe901e88F175b2C57D6B9B" # AcrossV3Adapter
    "0x3C8f8FeF087Dbee4728789dDA4D1D8E2f81a9A04" # DebridgeAdapter
    "0xA7E0557eD620Becb0466A691Ef27C906BA62b28f" # SuperLedger
    "0xdE343C7846E7244C997f8EA9b497F4fcD9FdA0e6" # ERC5115Ledger
    "0xC376f1EA6292b41832ee745f889C7e7819b96090" # SuperNativePaymaster
    "0xb835225410156BcB50c131BA88a2Ff500A48349C" # SuperVaultAggregator
    "0x3C083BA943f1061a65348cc4D0aa791295A6A6A8" # ECDSAPPSOracle
    "0x125aCDBA5746Bf0F41108b42de4A82e4f904ecbA" # ApproveERC20Hook
    "0x1aCA249C4f82443da0aCF959183F9bbDc6De6EC2" # TransferERC20Hook
    "0xfacEE97D87472201b4C65C19B06F3819B8DFDcf1" # BatchTransferFromHook
    "0xCD9d38B0391aE05A51ED691E294A5E8cEc033a52" # Deposit4626VaultHook
    "0x2E72B414c2EEDf42c65875128aE343E2126e4CB4" # ApproveAndDeposit4626VaultHook
    "0x00f349eDe4b741e36342E9Fc7ed457e7F2dEF33D" # Redeem4626VaultHook
    "0x08bFDDab3d9157dA5Bc0301bF1f70f668FE278B5" # ApproveAndRedeem4626VaultHook
    "0x479dbD5e3bA1c44d94E968745433a44E09d71E7d" # Deposit5115VaultHook
    "0x3F9F2CCB42455f81884200ef5BBeF69FA035Ca19" # ApproveAndDeposit5115VaultHook
    "0x9c0CCf25B849f6dcb5B5A0385eA361Bb90B9a762" # Redeem5115VaultHook
    "0xDbDb1826FfFf2C50aF2d2Fe1AA166938292918a7" # ApproveAndRedeem5115VaultHook
    "0xcF3bBB7b3CfeA1Fb66d9FbBCc89FeDF85C5E2F7F" # RequestDeposit7540VaultHook
    "0xDA72eb9cBECf87DcC81b38Cff7C14C3b7A39434a" # ApproveAndRequestDeposit7540VaultHook
    "0x6B150420D4813e6d11498e68f4C12E152b8513f2" # RequestRedeem7540VaultHook
    "0x699f60857A2020f602cA281AE532bF7366E1C92a" # Deposit7540VaultHook
    "0xB77848dcd61d8BC96794497b95D04cc0f5A2587C" # Withdraw7540VaultHook
    "0x13Bbb938f3Bb59825A2C47F12F5aB0116ba571F1" # ApproveAndRedeem7540VaultHook
    "0x2a2a67f4d76306aE11280e46fC5b3e363b8F3c4F" # Swap1InchHook
    "0x1e7DDF9BCc12350336648d30280F63068d17A4d3" # SwapOdosHook
    "0x578A2DafFC9284C5a8E37ec989F731a1a59Aa530" # ApproveAndSwapOdosHook
    "0x4048f1D771bd7c46E1f17935D56EF2Ac1356Ef87" # AcrossSendFundsAndExecuteOnDstHook
    "0xB10cF064445F3632595979e9330615879fC25610" # DeBridgeSendOrderAndExecuteOnDstHook
    "0xeb7c093eb8030F4942eDe7aE5eCA6C3503b4b65d" # FluidClaimRewardHook
    "0xbE4dA42d0799cce9A28F5891C26E260820a36E35" # FluidStakeHook
    "0xA06D2F690153D93E27907722a11351A2CF288A33" # ApproveAndFluidStakeHook
    "0x75ba6F4fC2A02c61E1db0d1380b6b0f1D270D69E" # FluidUnstakeHook
    "0xfa4F25b5912972AfEb236021415953a7cD6BE3dF" # GearboxClaimRewardHook
    "0x1479fdc2280Cf8D2bE9EFd9773AB978107cA90eD" # GearboxStakeHook
    "0x6B76CE994260D5407ebCD967fA3a7F436C5802b7" # ApproveAndGearboxStakeHook
    "0x0Ae5d9aA552f6FcC038703bA89d228Fd749BF7EC" # GearboxUnstakeHook
    "0xaB66108199AFF7Ab209B32AF6E396967c1908106" # YearnClaimOneRewardHook
    "0x3530De6647a976743BA5BaDc94D52BD3BbA2bbff" # EthenaCooldownSharesHook
    "0x0BF2d56acecB0A6c7B856A60354F84509583Ed56" # EthenaUnstakeHook
    "0x46A20Fc9EF4E573b6F312c630c3894E85BD32adA" # SpectraExchangeHook
    "0x1FFC9C93629514724572A88aD2883AB7D8f72290" # PendleRouterSwapHook
    "0x440B45B565ab6d5ebc47a845C02788CEFA47F109" # PendleRouterRedeemHook
    "0x59141B1d9E720481a7B8E91ae9d2180e91D5dc3a" # CancelDepositRequest7540Hook
    "0x5C719D15e186Ad90307130dD20EFf02390986cAe" # CancelRedeemRequest7540Hook
    "0xc543f58E04318B9b68BDc19E076C727D0b176172" # ClaimCancelDepositRequest7540Hook
    "0x9CB16B447d69839EBb561fF0264485A6d44C773e" # ClaimCancelRedeemRequest7540Hook
    "0x60E97F1164eF511bb96C71F4c6Cd1558D7240eD6" # CancelRedeemHook
    "0x502fFC766Ad508AE8107137781137106Fc483d52" # MorphoBorrowHook
    "0x17eF6E153C2310Aa1719A81b5bfEc8Cd24C469ab" # MorphoRepayHook
    "0xB1784769CcF1AF1691f5096B948117547559C2f3" # MorphoRepayAndWithdrawHook
    "0xb8AEF48D60575Ebc117382A30c7e104ab333d529" # ERC4626YieldSourceOracle
    "0x10a97b9787c2629EC2Fb7B135e87a5da31af59c9" # ERC5115YieldSourceOracle
    "0x637B140A07A8F65aB3B04106194131d55f17CB43" # ERC7540YieldSourceOracle
    "0x7C94B460FADDF3c248aA8E25DAC9c5c3cf034749" # PendlePTYieldSourceOracle
    "0xe23B32A3d114Be51d9Ee5B62DB4db66a89073974" # SpectraPTYieldSourceOracle
    "0xd619A2d0488aF05989B8b8B480c4C82F1d620193" # StakingYieldSourceOracle
)

# define constructor args for each contract
constructor_args=(
    "$superDeployer_arg"                        # SuperDeployer
    "$superGovernor_arg"                        # SuperGovernor
    "$superOracle_arg"                          # SuperOracle
    "$superLedgerConfiguration_arg"            # SuperLedgerConfiguration
    "$superMerkleValidator_arg"                # SuperMerkleValidator
    "$superDestinationValidator_arg"          # SuperDestinationValidator
    "$superExecutor_arg"                       # SuperExecutor
    "$superDestinationExecutor_arg"           # SuperDestinationExecutor
    "$acrossV3Adapter_arg"                    # AcrossV3Adapter
    "$debridgeAdapter_arg"                     # DebridgeAdapter
    "$superLedger_arg"                        # SuperLedger
    "$erc5115Ledger_arg"                      # ERC5115Ledger
    "$superNativePaymaster_arg"               # SuperNativePaymaster
    "$superVaultAggregator_arg"               # SuperVaultAggregator
    "$ecdsappsOracle_arg"                     # ECDSAPPSOracle
    "$approveERC20Hook_arg"                   # ApproveERC20Hook
    "$transferERC20Hook_arg"                  # TransferERC20Hook
    "$batchTransferFromHook_arg"              # BatchTransferFromHook
    "$deposit4626VaultHook_arg"               # Deposit4626VaultHook
    "$approveAndDeposit4626VaultHook_arg"     # ApproveAndDeposit4626VaultHook
    "$redeem4626VaultHook_arg"                # Redeem4626VaultHook
    "$approveAndRedeem4626VaultHook_arg"      # ApproveAndRedeem4626VaultHook
    "$deposit5115VaultHook_arg"               # Deposit5115VaultHook
    "$approveAndDeposit5115VaultHook_arg"     # ApproveAndDeposit5115VaultHook
    "$redeem5115VaultHook_arg"                # Redeem5115VaultHook
    "$approveAndRedeem5115VaultHook_arg"      # ApproveAndRedeem5115VaultHook
    "$requestDeposit7540VaultHook_arg"        # RequestDeposit7540VaultHook
    "$approveAndRequestDeposit7540VaultHook_arg" # ApproveAndRequestDeposit7540VaultHook
    "$requestRedeem7540VaultHook_arg"         # RequestRedeem7540VaultHook
    "$deposit7540VaultHook_arg"               # Deposit7540VaultHook
    "$withdraw7540VaultHook_arg"              # Withdraw7540VaultHook
    "$approveAndRedeem7540VaultHook_arg"      # ApproveAndRedeem7540VaultHook
    "$swap1InchHook_arg"                      # Swap1InchHook
    "$swapOdosHook_arg"                       # SwapOdosHook
    "$approveAndSwapOdosHook_arg"             # ApproveAndSwapOdosHook
    "$acrossSendFundsAndExecuteOnDstHook_arg" # AcrossSendFundsAndExecuteOnDstHook
    "$deBridgeSendOrderAndExecuteOnDstHook_arg" # DeBridgeSendOrderAndExecuteOnDstHook
    "$fluidClaimRewardHook_arg"               # FluidClaimRewardHook
    "$fluidStakeHook_arg"                     # FluidStakeHook
    "$approveAndFluidStakeHook_arg"           # ApproveAndFluidStakeHook
    "$fluidUnstakeHook_arg"                   # FluidUnstakeHook
    "$gearboxClaimRewardHook_arg"             # GearboxClaimRewardHook
    "$gearboxStakeHook_arg"                   # GearboxStakeHook
    "$gearboxApproveAndStakeHook_arg"         # ApproveAndGearboxStakeHook
    "$gearboxUnstakeHook_arg"                 # GearboxUnstakeHook
    "$yearnClaimOneRewardHook_arg"            # YearnClaimOneRewardHook
    "$ethenaCooldownSharesHook_arg"           # EthenaCooldownSharesHook
    "$ethenaUnstakeHook_arg"                  # EthenaUnstakeHook
    "$spectraExchangeHook_arg"                # SpectraExchangeHook
    "$pendleRouterSwapHook_arg"               # PendleRouterSwapHook
    "$pendleRouterRedeemHook_arg"             # PendleRouterRedeemHook
    "$cancelDepositRequest7540Hook_arg"       # CancelDepositRequest7540Hook
    "$cancelRedeemRequest7540Hook_arg"        # CancelRedeemRequest7540Hook
    "$claimCancelDepositRequest7540Hook_arg"  # ClaimCancelDepositRequest7540Hook
    "$claimCancelRedeemRequest7540Hook_arg"   # ClaimCancelRedeemRequest7540Hook
    "$cancelRedeemHook_arg"                   # CancelRedeemHook
    "$morphoBorrowHook_arg"                   # MorphoBorrowHook
    "$morphoRepayHook_arg"                    # MorphoRepayHook
    "$morphoRepayAndWithdrawHook_arg"         # MorphoRepayAndWithdrawHook
    "$erc4626YieldSourceOracle_arg"           # ERC4626YieldSourceOracle
    "$erc5115YieldSourceOracle_arg"           # ERC5115YieldSourceOracle
    "$erc7540YieldSourceOracle_arg"           # ERC7540YieldSourceOracle
    "$pendlePTYieldSourceOracle_arg"          # PendlePTYieldSourceOracle
    "$spectraPTYieldSourceOracle_arg"         # SpectraPTYieldSourceOracle
    "$stakingYieldSourceOracle_arg"           # StakingYieldSourceOracle
)

# verify contracts for each network
for i in "${!networks[@]}"; do
    network="${networks[$i]}"
    rpc_url="${rpc_urls[$i]}"
    api_key="${api_keys[$i]}"

    if [ "$network" = "84532" ]; then
        acrossV3Adapter_arg="$(cast abi-encode "constructor(address,address)" "0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64" "0xe03cAed05bCd579AD23bF926f4D935b5aA30aB2b")"
    fi

    if [ "$network" = "11155111" ]; then
        acrossV3Adapter_arg="$(cast abi-encode "constructor(address,address)" "0x7E63A5f1a8F0B4d0934B2f2327DAED3F6bb2ee75" "0xe03cAed05bCd579AD23bF926f4D935b5aA30aB2b")"
    fi

    if [ "$network" = "11155420" ]; then
        acrossV3Adapter_arg="$(cast abi-encode "constructor(address,address)" "0x4e8E101924eDE233C13e2D8622DC8aED2872d505" "0xe03cAed05bCd579AD23bF926f4D935b5aA30aB2b")"
    fi

    for j in "${!files_to_verify[@]}"; do
        contract_name="${contract_names[$j]}"
        constructor_arg="${constructor_args[$j]}"
        contract_address="${contract_addresses[$j]}"
1
        # verify contract
        forge verify-contract $contract_address $contract_name\
            --constructor-args "$constructor_arg" \
            --rpc-url "$rpc_url" \
            --etherscan-api-key "$api_key"

        if [ $? -eq 0 ]; then
            echo "[✓] $contract_name verified successfully."
        else
            echo "[!] Verification skipped or failed for $contract_name."
        fi
    done
done