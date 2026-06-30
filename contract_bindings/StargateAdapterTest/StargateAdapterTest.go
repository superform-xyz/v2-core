// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package StargateAdapterTest

import (
	"errors"
	"math/big"
	"strings"

	ethereum "github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
)

// Reference imports to suppress errors if they are not otherwise used.
var (
	_ = errors.New
	_ = big.NewInt
	_ = strings.NewReader
	_ = ethereum.NotFound
	_ = bind.Bind
	_ = common.Big1
	_ = types.BloomLookup
	_ = event.NewSubscription
	_ = abi.ConvertType
)

// StdInvariantFuzzArtifactSelector is an auto generated low-level Go binding around an user-defined struct.
type StdInvariantFuzzArtifactSelector struct {
	Artifact  string
	Selectors [][4]byte
}

// StdInvariantFuzzInterface is an auto generated low-level Go binding around an user-defined struct.
type StdInvariantFuzzInterface struct {
	Addr      common.Address
	Artifacts []string
}

// StdInvariantFuzzSelector is an auto generated low-level Go binding around an user-defined struct.
type StdInvariantFuzzSelector struct {
	Addr      common.Address
	Selectors [][4]byte
}

// StargateAdapterTestMetaData contains all meta data concerning the StargateAdapterTest contract.
var StargateAdapterTestMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"receive\",\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"AAVE_BASE_WETH\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"AAVE_V4_BLOCK\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"AAVE_V4_CORE_HUB\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"AAVE_V4_MAIN_SPOKE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"AAVE_V4_USDC_RESERVE_ID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"AAVE_V4_USDT_RESERVE_ID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"AAVE_V4_WBTC_RESERVE_ID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"AAVE_V4_WETH_RESERVE_ID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"AAVE_V4_WSTETH_RESERVE_ID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"AAVE_VAULT_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ACCOUNT_COUNT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ACROSS_RELAYER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ACROSS_RELAYER_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ACROSS_V3_ADAPTER_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ACROSS_V3_HELPER_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ALOE_USDC_VAULT_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"APPROVE_AND_FLUID_STAKE_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"APPROVE_AND_SWAP_ALGEBRA_INTEGRAL_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"APPROVE_AND_SWAP_ODOSV2_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"APPROVE_AND_SWAP_OPENOCEAN_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"APPROVE_AND_SWAP_UNISWAP_V3_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"APPROVE_ERC20_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"APPROVE_WITH_PERMIT2_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"BANK_MANAGER_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"BASE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"BASE_BLOCK\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"BASE_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"BASE_RPC_URL_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"BATCH_TRANSFER_FROM_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CANCEL_REDEEM_REQUEST_7540_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CENTRIFUGE_USDC_VAULT_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_10_ALOE_USDC\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_10_DAI\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_10_NEXUS_BOOTSTRAP\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_10_NEXUS_FACTORY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_10_ODOS_ROUTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_10_PENDLE_ROUTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_10_PENDLE_SWAP\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_10_SPECTRA_ROUTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_10_SPOKE_POOL_V3_ADDRESS\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_10_USDC\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_10_USDCE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_10_WETH\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_AAVE_VAULT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_CENTRIFUGE_USDC\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_CUSDO\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_DAI\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_EULER_VAULT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_FLUID_VAULT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_GEAR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_GEARBOX_STAKING\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_GEARBOX_VAULT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_MORPHO_VAULT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_NEXUS_BOOTSTRAP\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_NEXUS_FACTORY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_ODOS_ROUTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_PENDLE_ETHENA\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_PENDLE_ROUTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_PENDLE_SWAP\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_SPECTRA_PTT_TOKEN\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_SPECTRA_PT_IPOR_USDC\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_SPECTRA_ROUTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_SPOKE_POOL_V3_ADDRESS\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_SUSDE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_USDC\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_USDE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_USDO\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_WBTC\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_WETH\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_WST_ETH\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_YEARN_VAULT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_AAVE_BASE_WETH\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_DAI\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_MORPHO_GAUNTLET_USDC_PRIME\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_MORPHO_GAUNTLET_WETH_CORE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_NEXUS_BOOTSTRAP\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_NEXUS_FACTORY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_ODOS_ROUTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_PENDLE_ROUTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_PENDLE_SWAP\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_SPARK_PSM3\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_SPARK_USDC_VAULT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_SPECTRA_ROUTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_SPOKE_POOL_V3_ADDRESS\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_SUPER_USDC_VAULT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_SUSDS\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_USDC\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_USDS\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_WETH\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_YO_BTC_VAULT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_YO_ETH_VAULT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_YO_USD_VAULT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DAI_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DEBRIDGE_ADAPTER_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DEBRIDGE_CANCEL_ORDER_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DEBRIDGE_DLN_DST\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DEBRIDGE_DLN_HELPER_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DEBRIDGE_DLN_SOURCE_ADDRESS\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DEBRIDGE_HELPER_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DEPOSIT_4626_VAULT_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DEPOSIT_5115_VAULT_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DEPOSIT_7540_VAULT_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ENTRYPOINT_ADDR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ERC1155_LEDGER_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ERC4626_VAULT_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ERC4626_YIELD_SOURCE_ORACLE_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ERC5115_VAULT_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ERC5115_YIELD_SOURCE_ORACLE_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ERC7540_FULLY_ASYNC_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ERC7540_YIELD_SOURCE_ORACLE_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ETH\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ETHENA_COOLDOWN_SHARES_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ETHENA_UNSTAKE_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ETHEREUM_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ETHEREUM_RPC_URL_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ETH_BLOCK\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"EULER_VAULT_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"EXTRA_LARGE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FEE_RECIPIENT_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FLARE_ALGEBRA_INTEGRAL_SWAP_ROUTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FLARE_ALGEBRA_POOL_DEPLOYER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FLARE_RNAT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FLARE_SFLR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FLARE_SPRK\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FLARE_WFLR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FLUID_CLAIM_REWARD_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FLUID_STAKE_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FLUID_UNSTAKE_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FLUID_VAULT_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"GEARBOX_APPROVE_AND_STAKE_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"GEARBOX_CLAIM_REWARD_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"GEARBOX_STAKE_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"GEARBOX_STAKING_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"GEARBOX_UNSTAKE_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"GEARBOX_VAULT_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"GEAR_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"IS_TEST\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"LARGE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MAINNET_V2_SWAP_ROUTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MAINNET_V3_SWAP_ROUTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MAINNET_V3_SWAP_ROUTER_02\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MAINNET_V4_POOL_MANAGER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MAINNET_V4_POSITION_MANAGER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MANAGER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MANAGER_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MARK_ROOT_AS_USED_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MEDIUM\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MERKL_CLAIM_REWARD_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MERKL_DISTRIBUTOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MINT_SUPERPOSITIONS_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MOCK_APPROVE_AND_SWAP_ODOS_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MOCK_SWAP_ODOS_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MOCK_TARGET_EXECUTOR_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MORPHO\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MORPHO_BORROW_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MORPHO_GAUNTLET_USDC_PRIME_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MORPHO_GAUNTLET_WETH_CORE_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MORPHO_IRM\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MORPHO_IRM_WBTC_USDC\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MORPHO_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MORPHO_ORACLE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MORPHO_ORACLE_WBTC_USDC\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MORPHO_REPAY_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MORPHO_VAULT_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"NEXUS_ACCOUNT_IMPLEMENTATION_ID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ODOS_ROUTER_V3\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"OFFRAMP_TOKENS_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ONE_INCH_API_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ONE_INCH_ROUTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"OP\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"OPTIMISM_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"OPTIMISM_RPC_URL_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"OP_BLOCK\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"PENDLE_ETHENA_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"PENDLE_ROUTER_REDEEM_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"PENDLE_ROUTER_SWAP_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"PERMIT2\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"PERMIT_WITH_PERMIT2_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"REDEEM_4626_VAULT_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"REDEEM_5115_VAULT_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"REDEEM_7540_VAULT_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"REQUEST_REDEEM_7540_VAULT_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ROLES_ID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SAFE_REGISTRY_ADDR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SMALL\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SOMELIER_STAKE_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SOMELIER_UNBOND_ALL_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SOMELIER_UNBOND_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SOMELIER_UNSTAKE_ALL_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SOMELIER_UNSTAKE_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SPARK_USDC_VAULT_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SPECTRA_EXCHANGE_DEPOSIT_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SPECTRA_EXCHANGE_REDEEM_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"STAKING_YIELD_SOURCE_ORACLE_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"STRATEGIST_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_7702_SENDER_CREATOR_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_BUNDLER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_BUNDLER_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_COLLECTIVE_VAULT_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_DESTINATION_EXECUTOR_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_DESTINATION_VALIDATOR_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_EXECUTOR_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_GAS_TANK_ID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_LEDGER_CONFIGURATION_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_LEDGER_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_MERKLE_VALIDATOR_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_NATIVE_PAYMASTER_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_SENDER_CREATOR_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUSDE_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SWAP_1INCH_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SWAP_ALGEBRA_INTEGRAL_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SWAP_ODOSV2_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SWAP_OPENOCEAN_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SWAP_UNISWAP_V3_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SWAP_UNISWAP_V4_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SWAP_UNISWAP_V4_MULTI_HOP_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"TRANSFER_ERC20_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"TREASURY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"TREASURY_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"USDCE_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"USDC_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"USDE_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"USER1_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"USER2_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"VALIDATOR_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"WETH_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"WITHDRAW_7540_VAULT_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"WST_ETH_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"YEARN_CLAIM_ALL_REWARDS_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"YEARN_CLAIM_ONE_REWARD_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"deployAccounts\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"envOr\",\"inputs\":[{\"name\":\"name\",\"type\":\"string\",\"internalType\":\"string\"},{\"name\":\"defaultValue\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"value\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"envOr\",\"inputs\":[{\"name\":\"name\",\"type\":\"string\",\"internalType\":\"string\"},{\"name\":\"defaultValue\",\"type\":\"string\",\"internalType\":\"string\"}],\"outputs\":[{\"name\":\"value\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"excludeArtifacts\",\"inputs\":[],\"outputs\":[{\"name\":\"excludedArtifacts_\",\"type\":\"string[]\",\"internalType\":\"string[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"excludeContracts\",\"inputs\":[],\"outputs\":[{\"name\":\"excludedContracts_\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"excludeSelectors\",\"inputs\":[],\"outputs\":[{\"name\":\"excludedSelectors_\",\"type\":\"tuple[]\",\"internalType\":\"structStdInvariant.FuzzSelector[]\",\"components\":[{\"name\":\"addr\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"selectors\",\"type\":\"bytes4[]\",\"internalType\":\"bytes4[]\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"excludeSenders\",\"inputs\":[],\"outputs\":[{\"name\":\"excludedSenders_\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"failed\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"mockERC20\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractMockERC20\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"mockNativePool\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractMockStargatePool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"mockPool\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractMockStargatePool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"mockTokenMessaging\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractMockTokenMessaging\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"processBridgedExecution\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"setUp\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"stargateAdapter\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractStargateAdapter\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"startStateDiffRecording\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"targetArtifactSelectors\",\"inputs\":[],\"outputs\":[{\"name\":\"targetedArtifactSelectors_\",\"type\":\"tuple[]\",\"internalType\":\"structStdInvariant.FuzzArtifactSelector[]\",\"components\":[{\"name\":\"artifact\",\"type\":\"string\",\"internalType\":\"string\"},{\"name\":\"selectors\",\"type\":\"bytes4[]\",\"internalType\":\"bytes4[]\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"targetArtifacts\",\"inputs\":[],\"outputs\":[{\"name\":\"targetedArtifacts_\",\"type\":\"string[]\",\"internalType\":\"string[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"targetContracts\",\"inputs\":[],\"outputs\":[{\"name\":\"targetedContracts_\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"targetInterfaces\",\"inputs\":[],\"outputs\":[{\"name\":\"targetedInterfaces_\",\"type\":\"tuple[]\",\"internalType\":\"structStdInvariant.FuzzInterface[]\",\"components\":[{\"name\":\"addr\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"artifacts\",\"type\":\"string[]\",\"internalType\":\"string[]\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"targetSelectors\",\"inputs\":[],\"outputs\":[{\"name\":\"targetedSelectors_\",\"type\":\"tuple[]\",\"internalType\":\"structStdInvariant.FuzzSelector[]\",\"components\":[{\"name\":\"addr\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"selectors\",\"type\":\"bytes4[]\",\"internalType\":\"bytes4[]\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"targetSenders\",\"inputs\":[],\"outputs\":[{\"name\":\"targetedSenders_\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_Constructor\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_Constructor_RevertIf_ZeroEndpoint\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_Constructor_RevertIf_ZeroExecutor\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_Constructor_RevertIf_ZeroTokenMessaging\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_claimFailedTransfer_ERC20\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_claimFailedTransfer_NativeETH\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_claimFailedTransfer_PartialClaim\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_claimFailedTransfer_RevertIf_InsufficientBalance\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_claimFailedTransfer_RevertIf_ZeroAmount\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_lzCompose_ConcurrentComposesIsolated\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_lzCompose_DustRemainsInAdapter\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_lzCompose_ERC20_HappyPath\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_lzCompose_ExecutionFails_DoesNotRevert\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_lzCompose_ExecutionFails_EmitsEvent\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_lzCompose_InvalidInnerDecoding_EmitsAndReturns\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_lzCompose_MessageTooShort_EmitsAndReturns\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_lzCompose_NativeETH_HappyPath\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_lzCompose_NativeETH_NonPayableAccount_StoresForClaim\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_lzCompose_NoPreBalance_NativeETH_NoFailedCredit\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_lzCompose_NoPreBalance_NoFailedCredit\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_lzCompose_NoPreBalance_ZeroAccount_NoFailedCredit\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_lzCompose_RevertIf_InvalidSender\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_lzCompose_TransfersOnlyAmountLD\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_lzCompose_UnregisteredPool_EmitsAndReturns\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_lzCompose_UnregisteredPool_NoTokensTransferred\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_lzCompose_ZeroAmountLD\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_StargateAdapter_receive_AcceptsETH\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"user1\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"user2\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"user3\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"event\",\"name\":\"ExecutionFailed\",\"inputs\":[{\"name\":\"guid\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"FailedTransferClaimed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SlotFound\",\"inputs\":[{\"name\":\"who\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"fsig\",\"type\":\"bytes4\",\"indexed\":false,\"internalType\":\"bytes4\"},{\"name\":\"keysHash\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"slot\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransferFailed\",\"inputs\":[{\"name\":\"guid\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransferSucceeded\",\"inputs\":[{\"name\":\"guid\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"tokenSent\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"WARNING_UninitedSlot\",\"inputs\":[{\"name\":\"who\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"slot\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log\",\"inputs\":[{\"name\":\"\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_address\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_array\",\"inputs\":[{\"name\":\"val\",\"type\":\"uint256[]\",\"indexed\":false,\"internalType\":\"uint256[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_array\",\"inputs\":[{\"name\":\"val\",\"type\":\"int256[]\",\"indexed\":false,\"internalType\":\"int256[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_array\",\"inputs\":[{\"name\":\"val\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_bytes\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"indexed\":false,\"internalType\":\"bytes\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_bytes32\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_int\",\"inputs\":[{\"name\":\"\",\"type\":\"int256\",\"indexed\":false,\"internalType\":\"int256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_named_address\",\"inputs\":[{\"name\":\"key\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"val\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_named_array\",\"inputs\":[{\"name\":\"key\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"val\",\"type\":\"uint256[]\",\"indexed\":false,\"internalType\":\"uint256[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_named_array\",\"inputs\":[{\"name\":\"key\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"val\",\"type\":\"int256[]\",\"indexed\":false,\"internalType\":\"int256[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_named_array\",\"inputs\":[{\"name\":\"key\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"val\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_named_bytes\",\"inputs\":[{\"name\":\"key\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"val\",\"type\":\"bytes\",\"indexed\":false,\"internalType\":\"bytes\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_named_bytes32\",\"inputs\":[{\"name\":\"key\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"val\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_named_decimal_int\",\"inputs\":[{\"name\":\"key\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"val\",\"type\":\"int256\",\"indexed\":false,\"internalType\":\"int256\"},{\"name\":\"decimals\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_named_decimal_uint\",\"inputs\":[{\"name\":\"key\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"val\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"decimals\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_named_int\",\"inputs\":[{\"name\":\"key\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"val\",\"type\":\"int256\",\"indexed\":false,\"internalType\":\"int256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_named_string\",\"inputs\":[{\"name\":\"key\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"val\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_named_uint\",\"inputs\":[{\"name\":\"key\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"val\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_string\",\"inputs\":[{\"name\":\"\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_uint\",\"inputs\":[{\"name\":\"\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"logs\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"indexed\":false,\"internalType\":\"bytes\"}],\"anonymous\":false}]",
}

// StargateAdapterTestABI is the input ABI used to generate the binding from.
// Deprecated: Use StargateAdapterTestMetaData.ABI instead.
var StargateAdapterTestABI = StargateAdapterTestMetaData.ABI

// StargateAdapterTest is an auto generated Go binding around an Ethereum contract.
type StargateAdapterTest struct {
	StargateAdapterTestCaller     // Read-only binding to the contract
	StargateAdapterTestTransactor // Write-only binding to the contract
	StargateAdapterTestFilterer   // Log filterer for contract events
}

// StargateAdapterTestCaller is an auto generated read-only Go binding around an Ethereum contract.
type StargateAdapterTestCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// StargateAdapterTestTransactor is an auto generated write-only Go binding around an Ethereum contract.
type StargateAdapterTestTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// StargateAdapterTestFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type StargateAdapterTestFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// StargateAdapterTestSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type StargateAdapterTestSession struct {
	Contract     *StargateAdapterTest // Generic contract binding to set the session for
	CallOpts     bind.CallOpts        // Call options to use throughout this session
	TransactOpts bind.TransactOpts    // Transaction auth options to use throughout this session
}

// StargateAdapterTestCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type StargateAdapterTestCallerSession struct {
	Contract *StargateAdapterTestCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts              // Call options to use throughout this session
}

// StargateAdapterTestTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type StargateAdapterTestTransactorSession struct {
	Contract     *StargateAdapterTestTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts              // Transaction auth options to use throughout this session
}

// StargateAdapterTestRaw is an auto generated low-level Go binding around an Ethereum contract.
type StargateAdapterTestRaw struct {
	Contract *StargateAdapterTest // Generic contract binding to access the raw methods on
}

// StargateAdapterTestCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type StargateAdapterTestCallerRaw struct {
	Contract *StargateAdapterTestCaller // Generic read-only contract binding to access the raw methods on
}

// StargateAdapterTestTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type StargateAdapterTestTransactorRaw struct {
	Contract *StargateAdapterTestTransactor // Generic write-only contract binding to access the raw methods on
}

// NewStargateAdapterTest creates a new instance of StargateAdapterTest, bound to a specific deployed contract.
func NewStargateAdapterTest(address common.Address, backend bind.ContractBackend) (*StargateAdapterTest, error) {
	contract, err := bindStargateAdapterTest(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTest{StargateAdapterTestCaller: StargateAdapterTestCaller{contract: contract}, StargateAdapterTestTransactor: StargateAdapterTestTransactor{contract: contract}, StargateAdapterTestFilterer: StargateAdapterTestFilterer{contract: contract}}, nil
}

// NewStargateAdapterTestCaller creates a new read-only instance of StargateAdapterTest, bound to a specific deployed contract.
func NewStargateAdapterTestCaller(address common.Address, caller bind.ContractCaller) (*StargateAdapterTestCaller, error) {
	contract, err := bindStargateAdapterTest(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestCaller{contract: contract}, nil
}

// NewStargateAdapterTestTransactor creates a new write-only instance of StargateAdapterTest, bound to a specific deployed contract.
func NewStargateAdapterTestTransactor(address common.Address, transactor bind.ContractTransactor) (*StargateAdapterTestTransactor, error) {
	contract, err := bindStargateAdapterTest(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestTransactor{contract: contract}, nil
}

// NewStargateAdapterTestFilterer creates a new log filterer instance of StargateAdapterTest, bound to a specific deployed contract.
func NewStargateAdapterTestFilterer(address common.Address, filterer bind.ContractFilterer) (*StargateAdapterTestFilterer, error) {
	contract, err := bindStargateAdapterTest(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestFilterer{contract: contract}, nil
}

// bindStargateAdapterTest binds a generic wrapper to an already deployed contract.
func bindStargateAdapterTest(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := StargateAdapterTestMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_StargateAdapterTest *StargateAdapterTestRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _StargateAdapterTest.Contract.StargateAdapterTestCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_StargateAdapterTest *StargateAdapterTestRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.StargateAdapterTestTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_StargateAdapterTest *StargateAdapterTestRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.StargateAdapterTestTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_StargateAdapterTest *StargateAdapterTestCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _StargateAdapterTest.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_StargateAdapterTest *StargateAdapterTestTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_StargateAdapterTest *StargateAdapterTestTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.contract.Transact(opts, method, params...)
}

// AAVEBASEWETH is a free data retrieval call binding the contract method 0x0f5a0790.
//
// Solidity: function AAVE_BASE_WETH() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) AAVEBASEWETH(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "AAVE_BASE_WETH")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// AAVEBASEWETH is a free data retrieval call binding the contract method 0x0f5a0790.
//
// Solidity: function AAVE_BASE_WETH() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) AAVEBASEWETH() (string, error) {
	return _StargateAdapterTest.Contract.AAVEBASEWETH(&_StargateAdapterTest.CallOpts)
}

// AAVEBASEWETH is a free data retrieval call binding the contract method 0x0f5a0790.
//
// Solidity: function AAVE_BASE_WETH() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) AAVEBASEWETH() (string, error) {
	return _StargateAdapterTest.Contract.AAVEBASEWETH(&_StargateAdapterTest.CallOpts)
}

// AAVEV4BLOCK is a free data retrieval call binding the contract method 0x10b7dd31.
//
// Solidity: function AAVE_V4_BLOCK() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCaller) AAVEV4BLOCK(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "AAVE_V4_BLOCK")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// AAVEV4BLOCK is a free data retrieval call binding the contract method 0x10b7dd31.
//
// Solidity: function AAVE_V4_BLOCK() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestSession) AAVEV4BLOCK() (*big.Int, error) {
	return _StargateAdapterTest.Contract.AAVEV4BLOCK(&_StargateAdapterTest.CallOpts)
}

// AAVEV4BLOCK is a free data retrieval call binding the contract method 0x10b7dd31.
//
// Solidity: function AAVE_V4_BLOCK() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) AAVEV4BLOCK() (*big.Int, error) {
	return _StargateAdapterTest.Contract.AAVEV4BLOCK(&_StargateAdapterTest.CallOpts)
}

// AAVEV4COREHUB is a free data retrieval call binding the contract method 0x1bcf118c.
//
// Solidity: function AAVE_V4_CORE_HUB() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) AAVEV4COREHUB(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "AAVE_V4_CORE_HUB")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AAVEV4COREHUB is a free data retrieval call binding the contract method 0x1bcf118c.
//
// Solidity: function AAVE_V4_CORE_HUB() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) AAVEV4COREHUB() (common.Address, error) {
	return _StargateAdapterTest.Contract.AAVEV4COREHUB(&_StargateAdapterTest.CallOpts)
}

// AAVEV4COREHUB is a free data retrieval call binding the contract method 0x1bcf118c.
//
// Solidity: function AAVE_V4_CORE_HUB() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) AAVEV4COREHUB() (common.Address, error) {
	return _StargateAdapterTest.Contract.AAVEV4COREHUB(&_StargateAdapterTest.CallOpts)
}

// AAVEV4MAINSPOKE is a free data retrieval call binding the contract method 0xe6604638.
//
// Solidity: function AAVE_V4_MAIN_SPOKE() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) AAVEV4MAINSPOKE(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "AAVE_V4_MAIN_SPOKE")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AAVEV4MAINSPOKE is a free data retrieval call binding the contract method 0xe6604638.
//
// Solidity: function AAVE_V4_MAIN_SPOKE() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) AAVEV4MAINSPOKE() (common.Address, error) {
	return _StargateAdapterTest.Contract.AAVEV4MAINSPOKE(&_StargateAdapterTest.CallOpts)
}

// AAVEV4MAINSPOKE is a free data retrieval call binding the contract method 0xe6604638.
//
// Solidity: function AAVE_V4_MAIN_SPOKE() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) AAVEV4MAINSPOKE() (common.Address, error) {
	return _StargateAdapterTest.Contract.AAVEV4MAINSPOKE(&_StargateAdapterTest.CallOpts)
}

// AAVEV4USDCRESERVEID is a free data retrieval call binding the contract method 0xe61675eb.
//
// Solidity: function AAVE_V4_USDC_RESERVE_ID() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCaller) AAVEV4USDCRESERVEID(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "AAVE_V4_USDC_RESERVE_ID")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// AAVEV4USDCRESERVEID is a free data retrieval call binding the contract method 0xe61675eb.
//
// Solidity: function AAVE_V4_USDC_RESERVE_ID() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestSession) AAVEV4USDCRESERVEID() (*big.Int, error) {
	return _StargateAdapterTest.Contract.AAVEV4USDCRESERVEID(&_StargateAdapterTest.CallOpts)
}

// AAVEV4USDCRESERVEID is a free data retrieval call binding the contract method 0xe61675eb.
//
// Solidity: function AAVE_V4_USDC_RESERVE_ID() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) AAVEV4USDCRESERVEID() (*big.Int, error) {
	return _StargateAdapterTest.Contract.AAVEV4USDCRESERVEID(&_StargateAdapterTest.CallOpts)
}

// AAVEV4USDTRESERVEID is a free data retrieval call binding the contract method 0xfc2ba9e0.
//
// Solidity: function AAVE_V4_USDT_RESERVE_ID() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCaller) AAVEV4USDTRESERVEID(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "AAVE_V4_USDT_RESERVE_ID")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// AAVEV4USDTRESERVEID is a free data retrieval call binding the contract method 0xfc2ba9e0.
//
// Solidity: function AAVE_V4_USDT_RESERVE_ID() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestSession) AAVEV4USDTRESERVEID() (*big.Int, error) {
	return _StargateAdapterTest.Contract.AAVEV4USDTRESERVEID(&_StargateAdapterTest.CallOpts)
}

// AAVEV4USDTRESERVEID is a free data retrieval call binding the contract method 0xfc2ba9e0.
//
// Solidity: function AAVE_V4_USDT_RESERVE_ID() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) AAVEV4USDTRESERVEID() (*big.Int, error) {
	return _StargateAdapterTest.Contract.AAVEV4USDTRESERVEID(&_StargateAdapterTest.CallOpts)
}

// AAVEV4WBTCRESERVEID is a free data retrieval call binding the contract method 0xe51d6ffa.
//
// Solidity: function AAVE_V4_WBTC_RESERVE_ID() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCaller) AAVEV4WBTCRESERVEID(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "AAVE_V4_WBTC_RESERVE_ID")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// AAVEV4WBTCRESERVEID is a free data retrieval call binding the contract method 0xe51d6ffa.
//
// Solidity: function AAVE_V4_WBTC_RESERVE_ID() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestSession) AAVEV4WBTCRESERVEID() (*big.Int, error) {
	return _StargateAdapterTest.Contract.AAVEV4WBTCRESERVEID(&_StargateAdapterTest.CallOpts)
}

// AAVEV4WBTCRESERVEID is a free data retrieval call binding the contract method 0xe51d6ffa.
//
// Solidity: function AAVE_V4_WBTC_RESERVE_ID() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) AAVEV4WBTCRESERVEID() (*big.Int, error) {
	return _StargateAdapterTest.Contract.AAVEV4WBTCRESERVEID(&_StargateAdapterTest.CallOpts)
}

// AAVEV4WETHRESERVEID is a free data retrieval call binding the contract method 0xbcbd020f.
//
// Solidity: function AAVE_V4_WETH_RESERVE_ID() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCaller) AAVEV4WETHRESERVEID(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "AAVE_V4_WETH_RESERVE_ID")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// AAVEV4WETHRESERVEID is a free data retrieval call binding the contract method 0xbcbd020f.
//
// Solidity: function AAVE_V4_WETH_RESERVE_ID() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestSession) AAVEV4WETHRESERVEID() (*big.Int, error) {
	return _StargateAdapterTest.Contract.AAVEV4WETHRESERVEID(&_StargateAdapterTest.CallOpts)
}

// AAVEV4WETHRESERVEID is a free data retrieval call binding the contract method 0xbcbd020f.
//
// Solidity: function AAVE_V4_WETH_RESERVE_ID() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) AAVEV4WETHRESERVEID() (*big.Int, error) {
	return _StargateAdapterTest.Contract.AAVEV4WETHRESERVEID(&_StargateAdapterTest.CallOpts)
}

// AAVEV4WSTETHRESERVEID is a free data retrieval call binding the contract method 0x120d0a37.
//
// Solidity: function AAVE_V4_WSTETH_RESERVE_ID() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCaller) AAVEV4WSTETHRESERVEID(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "AAVE_V4_WSTETH_RESERVE_ID")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// AAVEV4WSTETHRESERVEID is a free data retrieval call binding the contract method 0x120d0a37.
//
// Solidity: function AAVE_V4_WSTETH_RESERVE_ID() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestSession) AAVEV4WSTETHRESERVEID() (*big.Int, error) {
	return _StargateAdapterTest.Contract.AAVEV4WSTETHRESERVEID(&_StargateAdapterTest.CallOpts)
}

// AAVEV4WSTETHRESERVEID is a free data retrieval call binding the contract method 0x120d0a37.
//
// Solidity: function AAVE_V4_WSTETH_RESERVE_ID() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) AAVEV4WSTETHRESERVEID() (*big.Int, error) {
	return _StargateAdapterTest.Contract.AAVEV4WSTETHRESERVEID(&_StargateAdapterTest.CallOpts)
}

// AAVEVAULTKEY is a free data retrieval call binding the contract method 0x93e98002.
//
// Solidity: function AAVE_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) AAVEVAULTKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "AAVE_VAULT_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// AAVEVAULTKEY is a free data retrieval call binding the contract method 0x93e98002.
//
// Solidity: function AAVE_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) AAVEVAULTKEY() (string, error) {
	return _StargateAdapterTest.Contract.AAVEVAULTKEY(&_StargateAdapterTest.CallOpts)
}

// AAVEVAULTKEY is a free data retrieval call binding the contract method 0x93e98002.
//
// Solidity: function AAVE_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) AAVEVAULTKEY() (string, error) {
	return _StargateAdapterTest.Contract.AAVEVAULTKEY(&_StargateAdapterTest.CallOpts)
}

// ACCOUNTCOUNT is a free data retrieval call binding the contract method 0x14475517.
//
// Solidity: function ACCOUNT_COUNT() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCaller) ACCOUNTCOUNT(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "ACCOUNT_COUNT")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// ACCOUNTCOUNT is a free data retrieval call binding the contract method 0x14475517.
//
// Solidity: function ACCOUNT_COUNT() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestSession) ACCOUNTCOUNT() (*big.Int, error) {
	return _StargateAdapterTest.Contract.ACCOUNTCOUNT(&_StargateAdapterTest.CallOpts)
}

// ACCOUNTCOUNT is a free data retrieval call binding the contract method 0x14475517.
//
// Solidity: function ACCOUNT_COUNT() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ACCOUNTCOUNT() (*big.Int, error) {
	return _StargateAdapterTest.Contract.ACCOUNTCOUNT(&_StargateAdapterTest.CallOpts)
}

// ACROSSRELAYER is a free data retrieval call binding the contract method 0xf50b6fad.
//
// Solidity: function ACROSS_RELAYER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) ACROSSRELAYER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "ACROSS_RELAYER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// ACROSSRELAYER is a free data retrieval call binding the contract method 0xf50b6fad.
//
// Solidity: function ACROSS_RELAYER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) ACROSSRELAYER() (common.Address, error) {
	return _StargateAdapterTest.Contract.ACROSSRELAYER(&_StargateAdapterTest.CallOpts)
}

// ACROSSRELAYER is a free data retrieval call binding the contract method 0xf50b6fad.
//
// Solidity: function ACROSS_RELAYER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ACROSSRELAYER() (common.Address, error) {
	return _StargateAdapterTest.Contract.ACROSSRELAYER(&_StargateAdapterTest.CallOpts)
}

// ACROSSRELAYERKEY is a free data retrieval call binding the contract method 0x90d93a58.
//
// Solidity: function ACROSS_RELAYER_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCaller) ACROSSRELAYERKEY(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "ACROSS_RELAYER_KEY")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// ACROSSRELAYERKEY is a free data retrieval call binding the contract method 0x90d93a58.
//
// Solidity: function ACROSS_RELAYER_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestSession) ACROSSRELAYERKEY() (*big.Int, error) {
	return _StargateAdapterTest.Contract.ACROSSRELAYERKEY(&_StargateAdapterTest.CallOpts)
}

// ACROSSRELAYERKEY is a free data retrieval call binding the contract method 0x90d93a58.
//
// Solidity: function ACROSS_RELAYER_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ACROSSRELAYERKEY() (*big.Int, error) {
	return _StargateAdapterTest.Contract.ACROSSRELAYERKEY(&_StargateAdapterTest.CallOpts)
}

// ACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY is a free data retrieval call binding the contract method 0x378ee239.
//
// Solidity: function ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) ACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY is a free data retrieval call binding the contract method 0x378ee239.
//
// Solidity: function ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) ACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.ACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// ACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY is a free data retrieval call binding the contract method 0x378ee239.
//
// Solidity: function ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.ACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// ACROSSV3ADAPTERKEY is a free data retrieval call binding the contract method 0xfdf58f7e.
//
// Solidity: function ACROSS_V3_ADAPTER_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) ACROSSV3ADAPTERKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "ACROSS_V3_ADAPTER_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ACROSSV3ADAPTERKEY is a free data retrieval call binding the contract method 0xfdf58f7e.
//
// Solidity: function ACROSS_V3_ADAPTER_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) ACROSSV3ADAPTERKEY() (string, error) {
	return _StargateAdapterTest.Contract.ACROSSV3ADAPTERKEY(&_StargateAdapterTest.CallOpts)
}

// ACROSSV3ADAPTERKEY is a free data retrieval call binding the contract method 0xfdf58f7e.
//
// Solidity: function ACROSS_V3_ADAPTER_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ACROSSV3ADAPTERKEY() (string, error) {
	return _StargateAdapterTest.Contract.ACROSSV3ADAPTERKEY(&_StargateAdapterTest.CallOpts)
}

// ACROSSV3HELPERKEY is a free data retrieval call binding the contract method 0x7561a70f.
//
// Solidity: function ACROSS_V3_HELPER_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) ACROSSV3HELPERKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "ACROSS_V3_HELPER_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ACROSSV3HELPERKEY is a free data retrieval call binding the contract method 0x7561a70f.
//
// Solidity: function ACROSS_V3_HELPER_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) ACROSSV3HELPERKEY() (string, error) {
	return _StargateAdapterTest.Contract.ACROSSV3HELPERKEY(&_StargateAdapterTest.CallOpts)
}

// ACROSSV3HELPERKEY is a free data retrieval call binding the contract method 0x7561a70f.
//
// Solidity: function ACROSS_V3_HELPER_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ACROSSV3HELPERKEY() (string, error) {
	return _StargateAdapterTest.Contract.ACROSSV3HELPERKEY(&_StargateAdapterTest.CallOpts)
}

// ALOEUSDCVAULTKEY is a free data retrieval call binding the contract method 0xb8335821.
//
// Solidity: function ALOE_USDC_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) ALOEUSDCVAULTKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "ALOE_USDC_VAULT_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ALOEUSDCVAULTKEY is a free data retrieval call binding the contract method 0xb8335821.
//
// Solidity: function ALOE_USDC_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) ALOEUSDCVAULTKEY() (string, error) {
	return _StargateAdapterTest.Contract.ALOEUSDCVAULTKEY(&_StargateAdapterTest.CallOpts)
}

// ALOEUSDCVAULTKEY is a free data retrieval call binding the contract method 0xb8335821.
//
// Solidity: function ALOE_USDC_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ALOEUSDCVAULTKEY() (string, error) {
	return _StargateAdapterTest.Contract.ALOEUSDCVAULTKEY(&_StargateAdapterTest.CallOpts)
}

// APPROVEANDACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY is a free data retrieval call binding the contract method 0x116b016b.
//
// Solidity: function APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) APPROVEANDACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// APPROVEANDACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY is a free data retrieval call binding the contract method 0x116b016b.
//
// Solidity: function APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) APPROVEANDACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.APPROVEANDACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// APPROVEANDACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY is a free data retrieval call binding the contract method 0x116b016b.
//
// Solidity: function APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) APPROVEANDACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.APPROVEANDACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// APPROVEANDDEPOSIT4626VAULTHOOKKEY is a free data retrieval call binding the contract method 0x357ceba9.
//
// Solidity: function APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) APPROVEANDDEPOSIT4626VAULTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// APPROVEANDDEPOSIT4626VAULTHOOKKEY is a free data retrieval call binding the contract method 0x357ceba9.
//
// Solidity: function APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) APPROVEANDDEPOSIT4626VAULTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.APPROVEANDDEPOSIT4626VAULTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// APPROVEANDDEPOSIT4626VAULTHOOKKEY is a free data retrieval call binding the contract method 0x357ceba9.
//
// Solidity: function APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) APPROVEANDDEPOSIT4626VAULTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.APPROVEANDDEPOSIT4626VAULTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// APPROVEANDDEPOSIT5115VAULTHOOKKEY is a free data retrieval call binding the contract method 0x8496a0c6.
//
// Solidity: function APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) APPROVEANDDEPOSIT5115VAULTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// APPROVEANDDEPOSIT5115VAULTHOOKKEY is a free data retrieval call binding the contract method 0x8496a0c6.
//
// Solidity: function APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) APPROVEANDDEPOSIT5115VAULTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.APPROVEANDDEPOSIT5115VAULTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// APPROVEANDDEPOSIT5115VAULTHOOKKEY is a free data retrieval call binding the contract method 0x8496a0c6.
//
// Solidity: function APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) APPROVEANDDEPOSIT5115VAULTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.APPROVEANDDEPOSIT5115VAULTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// APPROVEANDFLUIDSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xdccd7728.
//
// Solidity: function APPROVE_AND_FLUID_STAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) APPROVEANDFLUIDSTAKEHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "APPROVE_AND_FLUID_STAKE_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// APPROVEANDFLUIDSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xdccd7728.
//
// Solidity: function APPROVE_AND_FLUID_STAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) APPROVEANDFLUIDSTAKEHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.APPROVEANDFLUIDSTAKEHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// APPROVEANDFLUIDSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xdccd7728.
//
// Solidity: function APPROVE_AND_FLUID_STAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) APPROVEANDFLUIDSTAKEHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.APPROVEANDFLUIDSTAKEHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// APPROVEANDREQUESTDEPOSIT7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x8807e778.
//
// Solidity: function APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) APPROVEANDREQUESTDEPOSIT7540VAULTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// APPROVEANDREQUESTDEPOSIT7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x8807e778.
//
// Solidity: function APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) APPROVEANDREQUESTDEPOSIT7540VAULTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.APPROVEANDREQUESTDEPOSIT7540VAULTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// APPROVEANDREQUESTDEPOSIT7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x8807e778.
//
// Solidity: function APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) APPROVEANDREQUESTDEPOSIT7540VAULTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.APPROVEANDREQUESTDEPOSIT7540VAULTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// APPROVEANDSWAPALGEBRAINTEGRALHOOKKEY is a free data retrieval call binding the contract method 0x36851f78.
//
// Solidity: function APPROVE_AND_SWAP_ALGEBRA_INTEGRAL_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) APPROVEANDSWAPALGEBRAINTEGRALHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "APPROVE_AND_SWAP_ALGEBRA_INTEGRAL_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// APPROVEANDSWAPALGEBRAINTEGRALHOOKKEY is a free data retrieval call binding the contract method 0x36851f78.
//
// Solidity: function APPROVE_AND_SWAP_ALGEBRA_INTEGRAL_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) APPROVEANDSWAPALGEBRAINTEGRALHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.APPROVEANDSWAPALGEBRAINTEGRALHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// APPROVEANDSWAPALGEBRAINTEGRALHOOKKEY is a free data retrieval call binding the contract method 0x36851f78.
//
// Solidity: function APPROVE_AND_SWAP_ALGEBRA_INTEGRAL_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) APPROVEANDSWAPALGEBRAINTEGRALHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.APPROVEANDSWAPALGEBRAINTEGRALHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// APPROVEANDSWAPODOSV2HOOKKEY is a free data retrieval call binding the contract method 0x57e9ee36.
//
// Solidity: function APPROVE_AND_SWAP_ODOSV2_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) APPROVEANDSWAPODOSV2HOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "APPROVE_AND_SWAP_ODOSV2_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// APPROVEANDSWAPODOSV2HOOKKEY is a free data retrieval call binding the contract method 0x57e9ee36.
//
// Solidity: function APPROVE_AND_SWAP_ODOSV2_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) APPROVEANDSWAPODOSV2HOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.APPROVEANDSWAPODOSV2HOOKKEY(&_StargateAdapterTest.CallOpts)
}

// APPROVEANDSWAPODOSV2HOOKKEY is a free data retrieval call binding the contract method 0x57e9ee36.
//
// Solidity: function APPROVE_AND_SWAP_ODOSV2_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) APPROVEANDSWAPODOSV2HOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.APPROVEANDSWAPODOSV2HOOKKEY(&_StargateAdapterTest.CallOpts)
}

// APPROVEANDSWAPOPENOCEANHOOKKEY is a free data retrieval call binding the contract method 0x2328f3a1.
//
// Solidity: function APPROVE_AND_SWAP_OPENOCEAN_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) APPROVEANDSWAPOPENOCEANHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "APPROVE_AND_SWAP_OPENOCEAN_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// APPROVEANDSWAPOPENOCEANHOOKKEY is a free data retrieval call binding the contract method 0x2328f3a1.
//
// Solidity: function APPROVE_AND_SWAP_OPENOCEAN_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) APPROVEANDSWAPOPENOCEANHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.APPROVEANDSWAPOPENOCEANHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// APPROVEANDSWAPOPENOCEANHOOKKEY is a free data retrieval call binding the contract method 0x2328f3a1.
//
// Solidity: function APPROVE_AND_SWAP_OPENOCEAN_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) APPROVEANDSWAPOPENOCEANHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.APPROVEANDSWAPOPENOCEANHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// APPROVEANDSWAPUNISWAPV3HOOKKEY is a free data retrieval call binding the contract method 0x0c3c3c64.
//
// Solidity: function APPROVE_AND_SWAP_UNISWAP_V3_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) APPROVEANDSWAPUNISWAPV3HOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "APPROVE_AND_SWAP_UNISWAP_V3_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// APPROVEANDSWAPUNISWAPV3HOOKKEY is a free data retrieval call binding the contract method 0x0c3c3c64.
//
// Solidity: function APPROVE_AND_SWAP_UNISWAP_V3_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) APPROVEANDSWAPUNISWAPV3HOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.APPROVEANDSWAPUNISWAPV3HOOKKEY(&_StargateAdapterTest.CallOpts)
}

// APPROVEANDSWAPUNISWAPV3HOOKKEY is a free data retrieval call binding the contract method 0x0c3c3c64.
//
// Solidity: function APPROVE_AND_SWAP_UNISWAP_V3_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) APPROVEANDSWAPUNISWAPV3HOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.APPROVEANDSWAPUNISWAPV3HOOKKEY(&_StargateAdapterTest.CallOpts)
}

// APPROVEERC20HOOKKEY is a free data retrieval call binding the contract method 0x6aa8f025.
//
// Solidity: function APPROVE_ERC20_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) APPROVEERC20HOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "APPROVE_ERC20_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// APPROVEERC20HOOKKEY is a free data retrieval call binding the contract method 0x6aa8f025.
//
// Solidity: function APPROVE_ERC20_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) APPROVEERC20HOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.APPROVEERC20HOOKKEY(&_StargateAdapterTest.CallOpts)
}

// APPROVEERC20HOOKKEY is a free data retrieval call binding the contract method 0x6aa8f025.
//
// Solidity: function APPROVE_ERC20_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) APPROVEERC20HOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.APPROVEERC20HOOKKEY(&_StargateAdapterTest.CallOpts)
}

// APPROVEWITHPERMIT2HOOKKEY is a free data retrieval call binding the contract method 0xcd858547.
//
// Solidity: function APPROVE_WITH_PERMIT2_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) APPROVEWITHPERMIT2HOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "APPROVE_WITH_PERMIT2_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// APPROVEWITHPERMIT2HOOKKEY is a free data retrieval call binding the contract method 0xcd858547.
//
// Solidity: function APPROVE_WITH_PERMIT2_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) APPROVEWITHPERMIT2HOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.APPROVEWITHPERMIT2HOOKKEY(&_StargateAdapterTest.CallOpts)
}

// APPROVEWITHPERMIT2HOOKKEY is a free data retrieval call binding the contract method 0xcd858547.
//
// Solidity: function APPROVE_WITH_PERMIT2_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) APPROVEWITHPERMIT2HOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.APPROVEWITHPERMIT2HOOKKEY(&_StargateAdapterTest.CallOpts)
}

// BANKMANAGERKEY is a free data retrieval call binding the contract method 0x517f286f.
//
// Solidity: function BANK_MANAGER_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCaller) BANKMANAGERKEY(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "BANK_MANAGER_KEY")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// BANKMANAGERKEY is a free data retrieval call binding the contract method 0x517f286f.
//
// Solidity: function BANK_MANAGER_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestSession) BANKMANAGERKEY() (*big.Int, error) {
	return _StargateAdapterTest.Contract.BANKMANAGERKEY(&_StargateAdapterTest.CallOpts)
}

// BANKMANAGERKEY is a free data retrieval call binding the contract method 0x517f286f.
//
// Solidity: function BANK_MANAGER_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) BANKMANAGERKEY() (*big.Int, error) {
	return _StargateAdapterTest.Contract.BANKMANAGERKEY(&_StargateAdapterTest.CallOpts)
}

// BASE is a free data retrieval call binding the contract method 0xec342ad0.
//
// Solidity: function BASE() view returns(uint64)
func (_StargateAdapterTest *StargateAdapterTestCaller) BASE(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "BASE")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// BASE is a free data retrieval call binding the contract method 0xec342ad0.
//
// Solidity: function BASE() view returns(uint64)
func (_StargateAdapterTest *StargateAdapterTestSession) BASE() (uint64, error) {
	return _StargateAdapterTest.Contract.BASE(&_StargateAdapterTest.CallOpts)
}

// BASE is a free data retrieval call binding the contract method 0xec342ad0.
//
// Solidity: function BASE() view returns(uint64)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) BASE() (uint64, error) {
	return _StargateAdapterTest.Contract.BASE(&_StargateAdapterTest.CallOpts)
}

// BASEBLOCK is a free data retrieval call binding the contract method 0x7bb647db.
//
// Solidity: function BASE_BLOCK() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCaller) BASEBLOCK(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "BASE_BLOCK")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// BASEBLOCK is a free data retrieval call binding the contract method 0x7bb647db.
//
// Solidity: function BASE_BLOCK() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestSession) BASEBLOCK() (*big.Int, error) {
	return _StargateAdapterTest.Contract.BASEBLOCK(&_StargateAdapterTest.CallOpts)
}

// BASEBLOCK is a free data retrieval call binding the contract method 0x7bb647db.
//
// Solidity: function BASE_BLOCK() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) BASEBLOCK() (*big.Int, error) {
	return _StargateAdapterTest.Contract.BASEBLOCK(&_StargateAdapterTest.CallOpts)
}

// BASEKEY is a free data retrieval call binding the contract method 0x57dfb172.
//
// Solidity: function BASE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) BASEKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "BASE_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// BASEKEY is a free data retrieval call binding the contract method 0x57dfb172.
//
// Solidity: function BASE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) BASEKEY() (string, error) {
	return _StargateAdapterTest.Contract.BASEKEY(&_StargateAdapterTest.CallOpts)
}

// BASEKEY is a free data retrieval call binding the contract method 0x57dfb172.
//
// Solidity: function BASE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) BASEKEY() (string, error) {
	return _StargateAdapterTest.Contract.BASEKEY(&_StargateAdapterTest.CallOpts)
}

// BASERPCURLKEY is a free data retrieval call binding the contract method 0x1df36168.
//
// Solidity: function BASE_RPC_URL_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) BASERPCURLKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "BASE_RPC_URL_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// BASERPCURLKEY is a free data retrieval call binding the contract method 0x1df36168.
//
// Solidity: function BASE_RPC_URL_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) BASERPCURLKEY() (string, error) {
	return _StargateAdapterTest.Contract.BASERPCURLKEY(&_StargateAdapterTest.CallOpts)
}

// BASERPCURLKEY is a free data retrieval call binding the contract method 0x1df36168.
//
// Solidity: function BASE_RPC_URL_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) BASERPCURLKEY() (string, error) {
	return _StargateAdapterTest.Contract.BASERPCURLKEY(&_StargateAdapterTest.CallOpts)
}

// BATCHTRANSFERFROMHOOKKEY is a free data retrieval call binding the contract method 0x1a139bb2.
//
// Solidity: function BATCH_TRANSFER_FROM_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) BATCHTRANSFERFROMHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "BATCH_TRANSFER_FROM_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// BATCHTRANSFERFROMHOOKKEY is a free data retrieval call binding the contract method 0x1a139bb2.
//
// Solidity: function BATCH_TRANSFER_FROM_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) BATCHTRANSFERFROMHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.BATCHTRANSFERFROMHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// BATCHTRANSFERFROMHOOKKEY is a free data retrieval call binding the contract method 0x1a139bb2.
//
// Solidity: function BATCH_TRANSFER_FROM_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) BATCHTRANSFERFROMHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.BATCHTRANSFERFROMHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// CANCELDEPOSITREQUEST7540HOOKKEY is a free data retrieval call binding the contract method 0x96d3ae7d.
//
// Solidity: function CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) CANCELDEPOSITREQUEST7540HOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// CANCELDEPOSITREQUEST7540HOOKKEY is a free data retrieval call binding the contract method 0x96d3ae7d.
//
// Solidity: function CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) CANCELDEPOSITREQUEST7540HOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.CANCELDEPOSITREQUEST7540HOOKKEY(&_StargateAdapterTest.CallOpts)
}

// CANCELDEPOSITREQUEST7540HOOKKEY is a free data retrieval call binding the contract method 0x96d3ae7d.
//
// Solidity: function CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CANCELDEPOSITREQUEST7540HOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.CANCELDEPOSITREQUEST7540HOOKKEY(&_StargateAdapterTest.CallOpts)
}

// CANCELREDEEMREQUEST7540HOOKKEY is a free data retrieval call binding the contract method 0x0a039b68.
//
// Solidity: function CANCEL_REDEEM_REQUEST_7540_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) CANCELREDEEMREQUEST7540HOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CANCEL_REDEEM_REQUEST_7540_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// CANCELREDEEMREQUEST7540HOOKKEY is a free data retrieval call binding the contract method 0x0a039b68.
//
// Solidity: function CANCEL_REDEEM_REQUEST_7540_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) CANCELREDEEMREQUEST7540HOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.CANCELREDEEMREQUEST7540HOOKKEY(&_StargateAdapterTest.CallOpts)
}

// CANCELREDEEMREQUEST7540HOOKKEY is a free data retrieval call binding the contract method 0x0a039b68.
//
// Solidity: function CANCEL_REDEEM_REQUEST_7540_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CANCELREDEEMREQUEST7540HOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.CANCELREDEEMREQUEST7540HOOKKEY(&_StargateAdapterTest.CallOpts)
}

// CENTRIFUGEUSDCVAULTKEY is a free data retrieval call binding the contract method 0x78ef1bbd.
//
// Solidity: function CENTRIFUGE_USDC_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) CENTRIFUGEUSDCVAULTKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CENTRIFUGE_USDC_VAULT_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// CENTRIFUGEUSDCVAULTKEY is a free data retrieval call binding the contract method 0x78ef1bbd.
//
// Solidity: function CENTRIFUGE_USDC_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) CENTRIFUGEUSDCVAULTKEY() (string, error) {
	return _StargateAdapterTest.Contract.CENTRIFUGEUSDCVAULTKEY(&_StargateAdapterTest.CallOpts)
}

// CENTRIFUGEUSDCVAULTKEY is a free data retrieval call binding the contract method 0x78ef1bbd.
//
// Solidity: function CENTRIFUGE_USDC_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CENTRIFUGEUSDCVAULTKEY() (string, error) {
	return _StargateAdapterTest.Contract.CENTRIFUGEUSDCVAULTKEY(&_StargateAdapterTest.CallOpts)
}

// CHAIN10ALOEUSDC is a free data retrieval call binding the contract method 0x240a7120.
//
// Solidity: function CHAIN_10_ALOE_USDC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN10ALOEUSDC(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_10_ALOE_USDC")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN10ALOEUSDC is a free data retrieval call binding the contract method 0x240a7120.
//
// Solidity: function CHAIN_10_ALOE_USDC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN10ALOEUSDC() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN10ALOEUSDC(&_StargateAdapterTest.CallOpts)
}

// CHAIN10ALOEUSDC is a free data retrieval call binding the contract method 0x240a7120.
//
// Solidity: function CHAIN_10_ALOE_USDC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN10ALOEUSDC() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN10ALOEUSDC(&_StargateAdapterTest.CallOpts)
}

// CHAIN10DAI is a free data retrieval call binding the contract method 0xa96c0ad7.
//
// Solidity: function CHAIN_10_DAI() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN10DAI(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_10_DAI")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN10DAI is a free data retrieval call binding the contract method 0xa96c0ad7.
//
// Solidity: function CHAIN_10_DAI() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN10DAI() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN10DAI(&_StargateAdapterTest.CallOpts)
}

// CHAIN10DAI is a free data retrieval call binding the contract method 0xa96c0ad7.
//
// Solidity: function CHAIN_10_DAI() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN10DAI() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN10DAI(&_StargateAdapterTest.CallOpts)
}

// CHAIN10NEXUSBOOTSTRAP is a free data retrieval call binding the contract method 0xed0e6baa.
//
// Solidity: function CHAIN_10_NEXUS_BOOTSTRAP() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN10NEXUSBOOTSTRAP(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_10_NEXUS_BOOTSTRAP")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN10NEXUSBOOTSTRAP is a free data retrieval call binding the contract method 0xed0e6baa.
//
// Solidity: function CHAIN_10_NEXUS_BOOTSTRAP() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN10NEXUSBOOTSTRAP() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN10NEXUSBOOTSTRAP(&_StargateAdapterTest.CallOpts)
}

// CHAIN10NEXUSBOOTSTRAP is a free data retrieval call binding the contract method 0xed0e6baa.
//
// Solidity: function CHAIN_10_NEXUS_BOOTSTRAP() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN10NEXUSBOOTSTRAP() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN10NEXUSBOOTSTRAP(&_StargateAdapterTest.CallOpts)
}

// CHAIN10NEXUSFACTORY is a free data retrieval call binding the contract method 0x276bd652.
//
// Solidity: function CHAIN_10_NEXUS_FACTORY() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN10NEXUSFACTORY(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_10_NEXUS_FACTORY")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN10NEXUSFACTORY is a free data retrieval call binding the contract method 0x276bd652.
//
// Solidity: function CHAIN_10_NEXUS_FACTORY() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN10NEXUSFACTORY() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN10NEXUSFACTORY(&_StargateAdapterTest.CallOpts)
}

// CHAIN10NEXUSFACTORY is a free data retrieval call binding the contract method 0x276bd652.
//
// Solidity: function CHAIN_10_NEXUS_FACTORY() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN10NEXUSFACTORY() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN10NEXUSFACTORY(&_StargateAdapterTest.CallOpts)
}

// CHAIN10ODOSROUTER is a free data retrieval call binding the contract method 0xfc63c520.
//
// Solidity: function CHAIN_10_ODOS_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN10ODOSROUTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_10_ODOS_ROUTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN10ODOSROUTER is a free data retrieval call binding the contract method 0xfc63c520.
//
// Solidity: function CHAIN_10_ODOS_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN10ODOSROUTER() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN10ODOSROUTER(&_StargateAdapterTest.CallOpts)
}

// CHAIN10ODOSROUTER is a free data retrieval call binding the contract method 0xfc63c520.
//
// Solidity: function CHAIN_10_ODOS_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN10ODOSROUTER() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN10ODOSROUTER(&_StargateAdapterTest.CallOpts)
}

// CHAIN10PENDLEROUTER is a free data retrieval call binding the contract method 0xe46056b9.
//
// Solidity: function CHAIN_10_PENDLE_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN10PENDLEROUTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_10_PENDLE_ROUTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN10PENDLEROUTER is a free data retrieval call binding the contract method 0xe46056b9.
//
// Solidity: function CHAIN_10_PENDLE_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN10PENDLEROUTER() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN10PENDLEROUTER(&_StargateAdapterTest.CallOpts)
}

// CHAIN10PENDLEROUTER is a free data retrieval call binding the contract method 0xe46056b9.
//
// Solidity: function CHAIN_10_PENDLE_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN10PENDLEROUTER() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN10PENDLEROUTER(&_StargateAdapterTest.CallOpts)
}

// CHAIN10PENDLESWAP is a free data retrieval call binding the contract method 0x88aebdae.
//
// Solidity: function CHAIN_10_PENDLE_SWAP() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN10PENDLESWAP(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_10_PENDLE_SWAP")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN10PENDLESWAP is a free data retrieval call binding the contract method 0x88aebdae.
//
// Solidity: function CHAIN_10_PENDLE_SWAP() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN10PENDLESWAP() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN10PENDLESWAP(&_StargateAdapterTest.CallOpts)
}

// CHAIN10PENDLESWAP is a free data retrieval call binding the contract method 0x88aebdae.
//
// Solidity: function CHAIN_10_PENDLE_SWAP() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN10PENDLESWAP() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN10PENDLESWAP(&_StargateAdapterTest.CallOpts)
}

// CHAIN10SPECTRAROUTER is a free data retrieval call binding the contract method 0x89822ee9.
//
// Solidity: function CHAIN_10_SPECTRA_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN10SPECTRAROUTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_10_SPECTRA_ROUTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN10SPECTRAROUTER is a free data retrieval call binding the contract method 0x89822ee9.
//
// Solidity: function CHAIN_10_SPECTRA_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN10SPECTRAROUTER() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN10SPECTRAROUTER(&_StargateAdapterTest.CallOpts)
}

// CHAIN10SPECTRAROUTER is a free data retrieval call binding the contract method 0x89822ee9.
//
// Solidity: function CHAIN_10_SPECTRA_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN10SPECTRAROUTER() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN10SPECTRAROUTER(&_StargateAdapterTest.CallOpts)
}

// CHAIN10SPOKEPOOLV3ADDRESS is a free data retrieval call binding the contract method 0x4ddf3ce9.
//
// Solidity: function CHAIN_10_SPOKE_POOL_V3_ADDRESS() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN10SPOKEPOOLV3ADDRESS(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_10_SPOKE_POOL_V3_ADDRESS")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN10SPOKEPOOLV3ADDRESS is a free data retrieval call binding the contract method 0x4ddf3ce9.
//
// Solidity: function CHAIN_10_SPOKE_POOL_V3_ADDRESS() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN10SPOKEPOOLV3ADDRESS() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN10SPOKEPOOLV3ADDRESS(&_StargateAdapterTest.CallOpts)
}

// CHAIN10SPOKEPOOLV3ADDRESS is a free data retrieval call binding the contract method 0x4ddf3ce9.
//
// Solidity: function CHAIN_10_SPOKE_POOL_V3_ADDRESS() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN10SPOKEPOOLV3ADDRESS() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN10SPOKEPOOLV3ADDRESS(&_StargateAdapterTest.CallOpts)
}

// CHAIN10USDC is a free data retrieval call binding the contract method 0xcc7612f2.
//
// Solidity: function CHAIN_10_USDC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN10USDC(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_10_USDC")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN10USDC is a free data retrieval call binding the contract method 0xcc7612f2.
//
// Solidity: function CHAIN_10_USDC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN10USDC() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN10USDC(&_StargateAdapterTest.CallOpts)
}

// CHAIN10USDC is a free data retrieval call binding the contract method 0xcc7612f2.
//
// Solidity: function CHAIN_10_USDC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN10USDC() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN10USDC(&_StargateAdapterTest.CallOpts)
}

// CHAIN10USDCE is a free data retrieval call binding the contract method 0xeec6d812.
//
// Solidity: function CHAIN_10_USDCE() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN10USDCE(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_10_USDCE")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN10USDCE is a free data retrieval call binding the contract method 0xeec6d812.
//
// Solidity: function CHAIN_10_USDCE() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN10USDCE() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN10USDCE(&_StargateAdapterTest.CallOpts)
}

// CHAIN10USDCE is a free data retrieval call binding the contract method 0xeec6d812.
//
// Solidity: function CHAIN_10_USDCE() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN10USDCE() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN10USDCE(&_StargateAdapterTest.CallOpts)
}

// CHAIN10WETH is a free data retrieval call binding the contract method 0x5da57f00.
//
// Solidity: function CHAIN_10_WETH() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN10WETH(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_10_WETH")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN10WETH is a free data retrieval call binding the contract method 0x5da57f00.
//
// Solidity: function CHAIN_10_WETH() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN10WETH() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN10WETH(&_StargateAdapterTest.CallOpts)
}

// CHAIN10WETH is a free data retrieval call binding the contract method 0x5da57f00.
//
// Solidity: function CHAIN_10_WETH() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN10WETH() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN10WETH(&_StargateAdapterTest.CallOpts)
}

// CHAIN1AAVEVAULT is a free data retrieval call binding the contract method 0x1ba7c470.
//
// Solidity: function CHAIN_1_AAVE_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1AAVEVAULT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_AAVE_VAULT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1AAVEVAULT is a free data retrieval call binding the contract method 0x1ba7c470.
//
// Solidity: function CHAIN_1_AAVE_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1AAVEVAULT() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1AAVEVAULT(&_StargateAdapterTest.CallOpts)
}

// CHAIN1AAVEVAULT is a free data retrieval call binding the contract method 0x1ba7c470.
//
// Solidity: function CHAIN_1_AAVE_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1AAVEVAULT() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1AAVEVAULT(&_StargateAdapterTest.CallOpts)
}

// CHAIN1CENTRIFUGEUSDC is a free data retrieval call binding the contract method 0xf79a6f90.
//
// Solidity: function CHAIN_1_CENTRIFUGE_USDC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1CENTRIFUGEUSDC(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_CENTRIFUGE_USDC")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1CENTRIFUGEUSDC is a free data retrieval call binding the contract method 0xf79a6f90.
//
// Solidity: function CHAIN_1_CENTRIFUGE_USDC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1CENTRIFUGEUSDC() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1CENTRIFUGEUSDC(&_StargateAdapterTest.CallOpts)
}

// CHAIN1CENTRIFUGEUSDC is a free data retrieval call binding the contract method 0xf79a6f90.
//
// Solidity: function CHAIN_1_CENTRIFUGE_USDC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1CENTRIFUGEUSDC() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1CENTRIFUGEUSDC(&_StargateAdapterTest.CallOpts)
}

// CHAIN1CUSDO is a free data retrieval call binding the contract method 0xc0a7c442.
//
// Solidity: function CHAIN_1_CUSDO() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1CUSDO(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_CUSDO")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1CUSDO is a free data retrieval call binding the contract method 0xc0a7c442.
//
// Solidity: function CHAIN_1_CUSDO() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1CUSDO() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1CUSDO(&_StargateAdapterTest.CallOpts)
}

// CHAIN1CUSDO is a free data retrieval call binding the contract method 0xc0a7c442.
//
// Solidity: function CHAIN_1_CUSDO() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1CUSDO() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1CUSDO(&_StargateAdapterTest.CallOpts)
}

// CHAIN1DAI is a free data retrieval call binding the contract method 0x0f704fee.
//
// Solidity: function CHAIN_1_DAI() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1DAI(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_DAI")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1DAI is a free data retrieval call binding the contract method 0x0f704fee.
//
// Solidity: function CHAIN_1_DAI() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1DAI() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1DAI(&_StargateAdapterTest.CallOpts)
}

// CHAIN1DAI is a free data retrieval call binding the contract method 0x0f704fee.
//
// Solidity: function CHAIN_1_DAI() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1DAI() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1DAI(&_StargateAdapterTest.CallOpts)
}

// CHAIN1EULERVAULT is a free data retrieval call binding the contract method 0x31fca8a2.
//
// Solidity: function CHAIN_1_EULER_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1EULERVAULT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_EULER_VAULT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1EULERVAULT is a free data retrieval call binding the contract method 0x31fca8a2.
//
// Solidity: function CHAIN_1_EULER_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1EULERVAULT() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1EULERVAULT(&_StargateAdapterTest.CallOpts)
}

// CHAIN1EULERVAULT is a free data retrieval call binding the contract method 0x31fca8a2.
//
// Solidity: function CHAIN_1_EULER_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1EULERVAULT() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1EULERVAULT(&_StargateAdapterTest.CallOpts)
}

// CHAIN1FLUIDVAULT is a free data retrieval call binding the contract method 0xe582fe3b.
//
// Solidity: function CHAIN_1_FLUID_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1FLUIDVAULT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_FLUID_VAULT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1FLUIDVAULT is a free data retrieval call binding the contract method 0xe582fe3b.
//
// Solidity: function CHAIN_1_FLUID_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1FLUIDVAULT() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1FLUIDVAULT(&_StargateAdapterTest.CallOpts)
}

// CHAIN1FLUIDVAULT is a free data retrieval call binding the contract method 0xe582fe3b.
//
// Solidity: function CHAIN_1_FLUID_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1FLUIDVAULT() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1FLUIDVAULT(&_StargateAdapterTest.CallOpts)
}

// CHAIN1GEAR is a free data retrieval call binding the contract method 0xc9319814.
//
// Solidity: function CHAIN_1_GEAR() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1GEAR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_GEAR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1GEAR is a free data retrieval call binding the contract method 0xc9319814.
//
// Solidity: function CHAIN_1_GEAR() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1GEAR() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1GEAR(&_StargateAdapterTest.CallOpts)
}

// CHAIN1GEAR is a free data retrieval call binding the contract method 0xc9319814.
//
// Solidity: function CHAIN_1_GEAR() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1GEAR() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1GEAR(&_StargateAdapterTest.CallOpts)
}

// CHAIN1GEARBOXSTAKING is a free data retrieval call binding the contract method 0xb6a20f3f.
//
// Solidity: function CHAIN_1_GEARBOX_STAKING() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1GEARBOXSTAKING(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_GEARBOX_STAKING")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1GEARBOXSTAKING is a free data retrieval call binding the contract method 0xb6a20f3f.
//
// Solidity: function CHAIN_1_GEARBOX_STAKING() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1GEARBOXSTAKING() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1GEARBOXSTAKING(&_StargateAdapterTest.CallOpts)
}

// CHAIN1GEARBOXSTAKING is a free data retrieval call binding the contract method 0xb6a20f3f.
//
// Solidity: function CHAIN_1_GEARBOX_STAKING() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1GEARBOXSTAKING() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1GEARBOXSTAKING(&_StargateAdapterTest.CallOpts)
}

// CHAIN1GEARBOXVAULT is a free data retrieval call binding the contract method 0x6077c7b7.
//
// Solidity: function CHAIN_1_GEARBOX_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1GEARBOXVAULT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_GEARBOX_VAULT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1GEARBOXVAULT is a free data retrieval call binding the contract method 0x6077c7b7.
//
// Solidity: function CHAIN_1_GEARBOX_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1GEARBOXVAULT() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1GEARBOXVAULT(&_StargateAdapterTest.CallOpts)
}

// CHAIN1GEARBOXVAULT is a free data retrieval call binding the contract method 0x6077c7b7.
//
// Solidity: function CHAIN_1_GEARBOX_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1GEARBOXVAULT() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1GEARBOXVAULT(&_StargateAdapterTest.CallOpts)
}

// CHAIN1MORPHOVAULT is a free data retrieval call binding the contract method 0x8bb5a798.
//
// Solidity: function CHAIN_1_MORPHO_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1MORPHOVAULT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_MORPHO_VAULT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1MORPHOVAULT is a free data retrieval call binding the contract method 0x8bb5a798.
//
// Solidity: function CHAIN_1_MORPHO_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1MORPHOVAULT() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1MORPHOVAULT(&_StargateAdapterTest.CallOpts)
}

// CHAIN1MORPHOVAULT is a free data retrieval call binding the contract method 0x8bb5a798.
//
// Solidity: function CHAIN_1_MORPHO_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1MORPHOVAULT() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1MORPHOVAULT(&_StargateAdapterTest.CallOpts)
}

// CHAIN1NEXUSBOOTSTRAP is a free data retrieval call binding the contract method 0x03a48ba8.
//
// Solidity: function CHAIN_1_NEXUS_BOOTSTRAP() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1NEXUSBOOTSTRAP(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_NEXUS_BOOTSTRAP")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1NEXUSBOOTSTRAP is a free data retrieval call binding the contract method 0x03a48ba8.
//
// Solidity: function CHAIN_1_NEXUS_BOOTSTRAP() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1NEXUSBOOTSTRAP() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1NEXUSBOOTSTRAP(&_StargateAdapterTest.CallOpts)
}

// CHAIN1NEXUSBOOTSTRAP is a free data retrieval call binding the contract method 0x03a48ba8.
//
// Solidity: function CHAIN_1_NEXUS_BOOTSTRAP() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1NEXUSBOOTSTRAP() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1NEXUSBOOTSTRAP(&_StargateAdapterTest.CallOpts)
}

// CHAIN1NEXUSFACTORY is a free data retrieval call binding the contract method 0xfeff3a58.
//
// Solidity: function CHAIN_1_NEXUS_FACTORY() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1NEXUSFACTORY(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_NEXUS_FACTORY")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1NEXUSFACTORY is a free data retrieval call binding the contract method 0xfeff3a58.
//
// Solidity: function CHAIN_1_NEXUS_FACTORY() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1NEXUSFACTORY() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1NEXUSFACTORY(&_StargateAdapterTest.CallOpts)
}

// CHAIN1NEXUSFACTORY is a free data retrieval call binding the contract method 0xfeff3a58.
//
// Solidity: function CHAIN_1_NEXUS_FACTORY() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1NEXUSFACTORY() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1NEXUSFACTORY(&_StargateAdapterTest.CallOpts)
}

// CHAIN1ODOSROUTER is a free data retrieval call binding the contract method 0xc2933cd1.
//
// Solidity: function CHAIN_1_ODOS_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1ODOSROUTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_ODOS_ROUTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1ODOSROUTER is a free data retrieval call binding the contract method 0xc2933cd1.
//
// Solidity: function CHAIN_1_ODOS_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1ODOSROUTER() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1ODOSROUTER(&_StargateAdapterTest.CallOpts)
}

// CHAIN1ODOSROUTER is a free data retrieval call binding the contract method 0xc2933cd1.
//
// Solidity: function CHAIN_1_ODOS_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1ODOSROUTER() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1ODOSROUTER(&_StargateAdapterTest.CallOpts)
}

// CHAIN1PENDLEETHENA is a free data retrieval call binding the contract method 0x911d4b7b.
//
// Solidity: function CHAIN_1_PENDLE_ETHENA() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1PENDLEETHENA(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_PENDLE_ETHENA")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1PENDLEETHENA is a free data retrieval call binding the contract method 0x911d4b7b.
//
// Solidity: function CHAIN_1_PENDLE_ETHENA() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1PENDLEETHENA() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1PENDLEETHENA(&_StargateAdapterTest.CallOpts)
}

// CHAIN1PENDLEETHENA is a free data retrieval call binding the contract method 0x911d4b7b.
//
// Solidity: function CHAIN_1_PENDLE_ETHENA() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1PENDLEETHENA() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1PENDLEETHENA(&_StargateAdapterTest.CallOpts)
}

// CHAIN1PENDLEROUTER is a free data retrieval call binding the contract method 0xb6a22dd6.
//
// Solidity: function CHAIN_1_PENDLE_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1PENDLEROUTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_PENDLE_ROUTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1PENDLEROUTER is a free data retrieval call binding the contract method 0xb6a22dd6.
//
// Solidity: function CHAIN_1_PENDLE_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1PENDLEROUTER() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1PENDLEROUTER(&_StargateAdapterTest.CallOpts)
}

// CHAIN1PENDLEROUTER is a free data retrieval call binding the contract method 0xb6a22dd6.
//
// Solidity: function CHAIN_1_PENDLE_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1PENDLEROUTER() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1PENDLEROUTER(&_StargateAdapterTest.CallOpts)
}

// CHAIN1PENDLESWAP is a free data retrieval call binding the contract method 0x52ea38f5.
//
// Solidity: function CHAIN_1_PENDLE_SWAP() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1PENDLESWAP(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_PENDLE_SWAP")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1PENDLESWAP is a free data retrieval call binding the contract method 0x52ea38f5.
//
// Solidity: function CHAIN_1_PENDLE_SWAP() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1PENDLESWAP() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1PENDLESWAP(&_StargateAdapterTest.CallOpts)
}

// CHAIN1PENDLESWAP is a free data retrieval call binding the contract method 0x52ea38f5.
//
// Solidity: function CHAIN_1_PENDLE_SWAP() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1PENDLESWAP() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1PENDLESWAP(&_StargateAdapterTest.CallOpts)
}

// CHAIN1SPECTRAPTTTOKEN is a free data retrieval call binding the contract method 0xdc2f079e.
//
// Solidity: function CHAIN_1_SPECTRA_PTT_TOKEN() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1SPECTRAPTTTOKEN(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_SPECTRA_PTT_TOKEN")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1SPECTRAPTTTOKEN is a free data retrieval call binding the contract method 0xdc2f079e.
//
// Solidity: function CHAIN_1_SPECTRA_PTT_TOKEN() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1SPECTRAPTTTOKEN() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1SPECTRAPTTTOKEN(&_StargateAdapterTest.CallOpts)
}

// CHAIN1SPECTRAPTTTOKEN is a free data retrieval call binding the contract method 0xdc2f079e.
//
// Solidity: function CHAIN_1_SPECTRA_PTT_TOKEN() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1SPECTRAPTTTOKEN() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1SPECTRAPTTTOKEN(&_StargateAdapterTest.CallOpts)
}

// CHAIN1SPECTRAPTIPORUSDC is a free data retrieval call binding the contract method 0xb5cc660e.
//
// Solidity: function CHAIN_1_SPECTRA_PT_IPOR_USDC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1SPECTRAPTIPORUSDC(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_SPECTRA_PT_IPOR_USDC")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1SPECTRAPTIPORUSDC is a free data retrieval call binding the contract method 0xb5cc660e.
//
// Solidity: function CHAIN_1_SPECTRA_PT_IPOR_USDC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1SPECTRAPTIPORUSDC() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1SPECTRAPTIPORUSDC(&_StargateAdapterTest.CallOpts)
}

// CHAIN1SPECTRAPTIPORUSDC is a free data retrieval call binding the contract method 0xb5cc660e.
//
// Solidity: function CHAIN_1_SPECTRA_PT_IPOR_USDC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1SPECTRAPTIPORUSDC() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1SPECTRAPTIPORUSDC(&_StargateAdapterTest.CallOpts)
}

// CHAIN1SPECTRAROUTER is a free data retrieval call binding the contract method 0xb17efd5f.
//
// Solidity: function CHAIN_1_SPECTRA_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1SPECTRAROUTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_SPECTRA_ROUTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1SPECTRAROUTER is a free data retrieval call binding the contract method 0xb17efd5f.
//
// Solidity: function CHAIN_1_SPECTRA_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1SPECTRAROUTER() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1SPECTRAROUTER(&_StargateAdapterTest.CallOpts)
}

// CHAIN1SPECTRAROUTER is a free data retrieval call binding the contract method 0xb17efd5f.
//
// Solidity: function CHAIN_1_SPECTRA_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1SPECTRAROUTER() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1SPECTRAROUTER(&_StargateAdapterTest.CallOpts)
}

// CHAIN1SPOKEPOOLV3ADDRESS is a free data retrieval call binding the contract method 0xcce4da2a.
//
// Solidity: function CHAIN_1_SPOKE_POOL_V3_ADDRESS() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1SPOKEPOOLV3ADDRESS(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_SPOKE_POOL_V3_ADDRESS")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1SPOKEPOOLV3ADDRESS is a free data retrieval call binding the contract method 0xcce4da2a.
//
// Solidity: function CHAIN_1_SPOKE_POOL_V3_ADDRESS() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1SPOKEPOOLV3ADDRESS() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1SPOKEPOOLV3ADDRESS(&_StargateAdapterTest.CallOpts)
}

// CHAIN1SPOKEPOOLV3ADDRESS is a free data retrieval call binding the contract method 0xcce4da2a.
//
// Solidity: function CHAIN_1_SPOKE_POOL_V3_ADDRESS() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1SPOKEPOOLV3ADDRESS() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1SPOKEPOOLV3ADDRESS(&_StargateAdapterTest.CallOpts)
}

// CHAIN1SUSDE is a free data retrieval call binding the contract method 0x46674bfc.
//
// Solidity: function CHAIN_1_SUSDE() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1SUSDE(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_SUSDE")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1SUSDE is a free data retrieval call binding the contract method 0x46674bfc.
//
// Solidity: function CHAIN_1_SUSDE() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1SUSDE() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1SUSDE(&_StargateAdapterTest.CallOpts)
}

// CHAIN1SUSDE is a free data retrieval call binding the contract method 0x46674bfc.
//
// Solidity: function CHAIN_1_SUSDE() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1SUSDE() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1SUSDE(&_StargateAdapterTest.CallOpts)
}

// CHAIN1USDC is a free data retrieval call binding the contract method 0xed9fe105.
//
// Solidity: function CHAIN_1_USDC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1USDC(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_USDC")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1USDC is a free data retrieval call binding the contract method 0xed9fe105.
//
// Solidity: function CHAIN_1_USDC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1USDC() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1USDC(&_StargateAdapterTest.CallOpts)
}

// CHAIN1USDC is a free data retrieval call binding the contract method 0xed9fe105.
//
// Solidity: function CHAIN_1_USDC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1USDC() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1USDC(&_StargateAdapterTest.CallOpts)
}

// CHAIN1USDE is a free data retrieval call binding the contract method 0x309e2478.
//
// Solidity: function CHAIN_1_USDE() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1USDE(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_USDE")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1USDE is a free data retrieval call binding the contract method 0x309e2478.
//
// Solidity: function CHAIN_1_USDE() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1USDE() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1USDE(&_StargateAdapterTest.CallOpts)
}

// CHAIN1USDE is a free data retrieval call binding the contract method 0x309e2478.
//
// Solidity: function CHAIN_1_USDE() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1USDE() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1USDE(&_StargateAdapterTest.CallOpts)
}

// CHAIN1USDO is a free data retrieval call binding the contract method 0x9ba4699d.
//
// Solidity: function CHAIN_1_USDO() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1USDO(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_USDO")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1USDO is a free data retrieval call binding the contract method 0x9ba4699d.
//
// Solidity: function CHAIN_1_USDO() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1USDO() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1USDO(&_StargateAdapterTest.CallOpts)
}

// CHAIN1USDO is a free data retrieval call binding the contract method 0x9ba4699d.
//
// Solidity: function CHAIN_1_USDO() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1USDO() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1USDO(&_StargateAdapterTest.CallOpts)
}

// CHAIN1WBTC is a free data retrieval call binding the contract method 0x5c920b64.
//
// Solidity: function CHAIN_1_WBTC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1WBTC(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_WBTC")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1WBTC is a free data retrieval call binding the contract method 0x5c920b64.
//
// Solidity: function CHAIN_1_WBTC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1WBTC() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1WBTC(&_StargateAdapterTest.CallOpts)
}

// CHAIN1WBTC is a free data retrieval call binding the contract method 0x5c920b64.
//
// Solidity: function CHAIN_1_WBTC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1WBTC() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1WBTC(&_StargateAdapterTest.CallOpts)
}

// CHAIN1WETH is a free data retrieval call binding the contract method 0x57009145.
//
// Solidity: function CHAIN_1_WETH() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1WETH(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_WETH")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1WETH is a free data retrieval call binding the contract method 0x57009145.
//
// Solidity: function CHAIN_1_WETH() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1WETH() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1WETH(&_StargateAdapterTest.CallOpts)
}

// CHAIN1WETH is a free data retrieval call binding the contract method 0x57009145.
//
// Solidity: function CHAIN_1_WETH() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1WETH() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1WETH(&_StargateAdapterTest.CallOpts)
}

// CHAIN1WSTETH is a free data retrieval call binding the contract method 0xff412875.
//
// Solidity: function CHAIN_1_WST_ETH() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1WSTETH(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_WST_ETH")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1WSTETH is a free data retrieval call binding the contract method 0xff412875.
//
// Solidity: function CHAIN_1_WST_ETH() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1WSTETH() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1WSTETH(&_StargateAdapterTest.CallOpts)
}

// CHAIN1WSTETH is a free data retrieval call binding the contract method 0xff412875.
//
// Solidity: function CHAIN_1_WST_ETH() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1WSTETH() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1WSTETH(&_StargateAdapterTest.CallOpts)
}

// CHAIN1YEARNVAULT is a free data retrieval call binding the contract method 0x2c9bf333.
//
// Solidity: function CHAIN_1_YEARN_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN1YEARNVAULT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_1_YEARN_VAULT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1YEARNVAULT is a free data retrieval call binding the contract method 0x2c9bf333.
//
// Solidity: function CHAIN_1_YEARN_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN1YEARNVAULT() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1YEARNVAULT(&_StargateAdapterTest.CallOpts)
}

// CHAIN1YEARNVAULT is a free data retrieval call binding the contract method 0x2c9bf333.
//
// Solidity: function CHAIN_1_YEARN_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN1YEARNVAULT() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN1YEARNVAULT(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453AAVEBASEWETH is a free data retrieval call binding the contract method 0xbd02d736.
//
// Solidity: function CHAIN_8453_AAVE_BASE_WETH() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN8453AAVEBASEWETH(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_8453_AAVE_BASE_WETH")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453AAVEBASEWETH is a free data retrieval call binding the contract method 0xbd02d736.
//
// Solidity: function CHAIN_8453_AAVE_BASE_WETH() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN8453AAVEBASEWETH() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453AAVEBASEWETH(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453AAVEBASEWETH is a free data retrieval call binding the contract method 0xbd02d736.
//
// Solidity: function CHAIN_8453_AAVE_BASE_WETH() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN8453AAVEBASEWETH() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453AAVEBASEWETH(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453DAI is a free data retrieval call binding the contract method 0x907073c2.
//
// Solidity: function CHAIN_8453_DAI() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN8453DAI(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_8453_DAI")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453DAI is a free data retrieval call binding the contract method 0x907073c2.
//
// Solidity: function CHAIN_8453_DAI() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN8453DAI() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453DAI(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453DAI is a free data retrieval call binding the contract method 0x907073c2.
//
// Solidity: function CHAIN_8453_DAI() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN8453DAI() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453DAI(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453MORPHOGAUNTLETUSDCPRIME is a free data retrieval call binding the contract method 0xfa88e2ee.
//
// Solidity: function CHAIN_8453_MORPHO_GAUNTLET_USDC_PRIME() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN8453MORPHOGAUNTLETUSDCPRIME(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_8453_MORPHO_GAUNTLET_USDC_PRIME")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453MORPHOGAUNTLETUSDCPRIME is a free data retrieval call binding the contract method 0xfa88e2ee.
//
// Solidity: function CHAIN_8453_MORPHO_GAUNTLET_USDC_PRIME() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN8453MORPHOGAUNTLETUSDCPRIME() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453MORPHOGAUNTLETUSDCPRIME(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453MORPHOGAUNTLETUSDCPRIME is a free data retrieval call binding the contract method 0xfa88e2ee.
//
// Solidity: function CHAIN_8453_MORPHO_GAUNTLET_USDC_PRIME() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN8453MORPHOGAUNTLETUSDCPRIME() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453MORPHOGAUNTLETUSDCPRIME(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453MORPHOGAUNTLETWETHCORE is a free data retrieval call binding the contract method 0xb67474d2.
//
// Solidity: function CHAIN_8453_MORPHO_GAUNTLET_WETH_CORE() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN8453MORPHOGAUNTLETWETHCORE(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_8453_MORPHO_GAUNTLET_WETH_CORE")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453MORPHOGAUNTLETWETHCORE is a free data retrieval call binding the contract method 0xb67474d2.
//
// Solidity: function CHAIN_8453_MORPHO_GAUNTLET_WETH_CORE() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN8453MORPHOGAUNTLETWETHCORE() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453MORPHOGAUNTLETWETHCORE(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453MORPHOGAUNTLETWETHCORE is a free data retrieval call binding the contract method 0xb67474d2.
//
// Solidity: function CHAIN_8453_MORPHO_GAUNTLET_WETH_CORE() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN8453MORPHOGAUNTLETWETHCORE() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453MORPHOGAUNTLETWETHCORE(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453NEXUSBOOTSTRAP is a free data retrieval call binding the contract method 0x436b1e6e.
//
// Solidity: function CHAIN_8453_NEXUS_BOOTSTRAP() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN8453NEXUSBOOTSTRAP(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_8453_NEXUS_BOOTSTRAP")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453NEXUSBOOTSTRAP is a free data retrieval call binding the contract method 0x436b1e6e.
//
// Solidity: function CHAIN_8453_NEXUS_BOOTSTRAP() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN8453NEXUSBOOTSTRAP() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453NEXUSBOOTSTRAP(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453NEXUSBOOTSTRAP is a free data retrieval call binding the contract method 0x436b1e6e.
//
// Solidity: function CHAIN_8453_NEXUS_BOOTSTRAP() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN8453NEXUSBOOTSTRAP() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453NEXUSBOOTSTRAP(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453NEXUSFACTORY is a free data retrieval call binding the contract method 0x3e9b726b.
//
// Solidity: function CHAIN_8453_NEXUS_FACTORY() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN8453NEXUSFACTORY(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_8453_NEXUS_FACTORY")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453NEXUSFACTORY is a free data retrieval call binding the contract method 0x3e9b726b.
//
// Solidity: function CHAIN_8453_NEXUS_FACTORY() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN8453NEXUSFACTORY() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453NEXUSFACTORY(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453NEXUSFACTORY is a free data retrieval call binding the contract method 0x3e9b726b.
//
// Solidity: function CHAIN_8453_NEXUS_FACTORY() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN8453NEXUSFACTORY() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453NEXUSFACTORY(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453ODOSROUTER is a free data retrieval call binding the contract method 0xeb6d020d.
//
// Solidity: function CHAIN_8453_ODOS_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN8453ODOSROUTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_8453_ODOS_ROUTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453ODOSROUTER is a free data retrieval call binding the contract method 0xeb6d020d.
//
// Solidity: function CHAIN_8453_ODOS_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN8453ODOSROUTER() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453ODOSROUTER(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453ODOSROUTER is a free data retrieval call binding the contract method 0xeb6d020d.
//
// Solidity: function CHAIN_8453_ODOS_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN8453ODOSROUTER() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453ODOSROUTER(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453PENDLEROUTER is a free data retrieval call binding the contract method 0xd63555ac.
//
// Solidity: function CHAIN_8453_PENDLE_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN8453PENDLEROUTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_8453_PENDLE_ROUTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453PENDLEROUTER is a free data retrieval call binding the contract method 0xd63555ac.
//
// Solidity: function CHAIN_8453_PENDLE_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN8453PENDLEROUTER() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453PENDLEROUTER(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453PENDLEROUTER is a free data retrieval call binding the contract method 0xd63555ac.
//
// Solidity: function CHAIN_8453_PENDLE_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN8453PENDLEROUTER() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453PENDLEROUTER(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453PENDLESWAP is a free data retrieval call binding the contract method 0x7f95398a.
//
// Solidity: function CHAIN_8453_PENDLE_SWAP() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN8453PENDLESWAP(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_8453_PENDLE_SWAP")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453PENDLESWAP is a free data retrieval call binding the contract method 0x7f95398a.
//
// Solidity: function CHAIN_8453_PENDLE_SWAP() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN8453PENDLESWAP() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453PENDLESWAP(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453PENDLESWAP is a free data retrieval call binding the contract method 0x7f95398a.
//
// Solidity: function CHAIN_8453_PENDLE_SWAP() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN8453PENDLESWAP() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453PENDLESWAP(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453SPARKPSM3 is a free data retrieval call binding the contract method 0x9a36e478.
//
// Solidity: function CHAIN_8453_SPARK_PSM3() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN8453SPARKPSM3(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_8453_SPARK_PSM3")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453SPARKPSM3 is a free data retrieval call binding the contract method 0x9a36e478.
//
// Solidity: function CHAIN_8453_SPARK_PSM3() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN8453SPARKPSM3() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453SPARKPSM3(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453SPARKPSM3 is a free data retrieval call binding the contract method 0x9a36e478.
//
// Solidity: function CHAIN_8453_SPARK_PSM3() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN8453SPARKPSM3() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453SPARKPSM3(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453SPARKUSDCVAULT is a free data retrieval call binding the contract method 0xca54d672.
//
// Solidity: function CHAIN_8453_SPARK_USDC_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN8453SPARKUSDCVAULT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_8453_SPARK_USDC_VAULT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453SPARKUSDCVAULT is a free data retrieval call binding the contract method 0xca54d672.
//
// Solidity: function CHAIN_8453_SPARK_USDC_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN8453SPARKUSDCVAULT() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453SPARKUSDCVAULT(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453SPARKUSDCVAULT is a free data retrieval call binding the contract method 0xca54d672.
//
// Solidity: function CHAIN_8453_SPARK_USDC_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN8453SPARKUSDCVAULT() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453SPARKUSDCVAULT(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453SPECTRAROUTER is a free data retrieval call binding the contract method 0x421bcedd.
//
// Solidity: function CHAIN_8453_SPECTRA_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN8453SPECTRAROUTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_8453_SPECTRA_ROUTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453SPECTRAROUTER is a free data retrieval call binding the contract method 0x421bcedd.
//
// Solidity: function CHAIN_8453_SPECTRA_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN8453SPECTRAROUTER() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453SPECTRAROUTER(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453SPECTRAROUTER is a free data retrieval call binding the contract method 0x421bcedd.
//
// Solidity: function CHAIN_8453_SPECTRA_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN8453SPECTRAROUTER() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453SPECTRAROUTER(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453SPOKEPOOLV3ADDRESS is a free data retrieval call binding the contract method 0x1da5f587.
//
// Solidity: function CHAIN_8453_SPOKE_POOL_V3_ADDRESS() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN8453SPOKEPOOLV3ADDRESS(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_8453_SPOKE_POOL_V3_ADDRESS")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453SPOKEPOOLV3ADDRESS is a free data retrieval call binding the contract method 0x1da5f587.
//
// Solidity: function CHAIN_8453_SPOKE_POOL_V3_ADDRESS() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN8453SPOKEPOOLV3ADDRESS() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453SPOKEPOOLV3ADDRESS(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453SPOKEPOOLV3ADDRESS is a free data retrieval call binding the contract method 0x1da5f587.
//
// Solidity: function CHAIN_8453_SPOKE_POOL_V3_ADDRESS() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN8453SPOKEPOOLV3ADDRESS() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453SPOKEPOOLV3ADDRESS(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453SUPERUSDCVAULT is a free data retrieval call binding the contract method 0xcf75f681.
//
// Solidity: function CHAIN_8453_SUPER_USDC_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN8453SUPERUSDCVAULT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_8453_SUPER_USDC_VAULT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453SUPERUSDCVAULT is a free data retrieval call binding the contract method 0xcf75f681.
//
// Solidity: function CHAIN_8453_SUPER_USDC_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN8453SUPERUSDCVAULT() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453SUPERUSDCVAULT(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453SUPERUSDCVAULT is a free data retrieval call binding the contract method 0xcf75f681.
//
// Solidity: function CHAIN_8453_SUPER_USDC_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN8453SUPERUSDCVAULT() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453SUPERUSDCVAULT(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453SUSDS is a free data retrieval call binding the contract method 0x16a10836.
//
// Solidity: function CHAIN_8453_SUSDS() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN8453SUSDS(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_8453_SUSDS")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453SUSDS is a free data retrieval call binding the contract method 0x16a10836.
//
// Solidity: function CHAIN_8453_SUSDS() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN8453SUSDS() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453SUSDS(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453SUSDS is a free data retrieval call binding the contract method 0x16a10836.
//
// Solidity: function CHAIN_8453_SUSDS() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN8453SUSDS() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453SUSDS(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453USDC is a free data retrieval call binding the contract method 0xffdd469c.
//
// Solidity: function CHAIN_8453_USDC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN8453USDC(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_8453_USDC")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453USDC is a free data retrieval call binding the contract method 0xffdd469c.
//
// Solidity: function CHAIN_8453_USDC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN8453USDC() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453USDC(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453USDC is a free data retrieval call binding the contract method 0xffdd469c.
//
// Solidity: function CHAIN_8453_USDC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN8453USDC() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453USDC(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453USDS is a free data retrieval call binding the contract method 0x07ba6519.
//
// Solidity: function CHAIN_8453_USDS() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN8453USDS(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_8453_USDS")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453USDS is a free data retrieval call binding the contract method 0x07ba6519.
//
// Solidity: function CHAIN_8453_USDS() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN8453USDS() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453USDS(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453USDS is a free data retrieval call binding the contract method 0x07ba6519.
//
// Solidity: function CHAIN_8453_USDS() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN8453USDS() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453USDS(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453WETH is a free data retrieval call binding the contract method 0x70ac2501.
//
// Solidity: function CHAIN_8453_WETH() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN8453WETH(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_8453_WETH")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453WETH is a free data retrieval call binding the contract method 0x70ac2501.
//
// Solidity: function CHAIN_8453_WETH() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN8453WETH() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453WETH(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453WETH is a free data retrieval call binding the contract method 0x70ac2501.
//
// Solidity: function CHAIN_8453_WETH() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN8453WETH() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453WETH(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453YOBTCVAULT is a free data retrieval call binding the contract method 0xa9810059.
//
// Solidity: function CHAIN_8453_YO_BTC_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN8453YOBTCVAULT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_8453_YO_BTC_VAULT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453YOBTCVAULT is a free data retrieval call binding the contract method 0xa9810059.
//
// Solidity: function CHAIN_8453_YO_BTC_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN8453YOBTCVAULT() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453YOBTCVAULT(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453YOBTCVAULT is a free data retrieval call binding the contract method 0xa9810059.
//
// Solidity: function CHAIN_8453_YO_BTC_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN8453YOBTCVAULT() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453YOBTCVAULT(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453YOETHVAULT is a free data retrieval call binding the contract method 0xddcb4c37.
//
// Solidity: function CHAIN_8453_YO_ETH_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN8453YOETHVAULT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_8453_YO_ETH_VAULT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453YOETHVAULT is a free data retrieval call binding the contract method 0xddcb4c37.
//
// Solidity: function CHAIN_8453_YO_ETH_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN8453YOETHVAULT() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453YOETHVAULT(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453YOETHVAULT is a free data retrieval call binding the contract method 0xddcb4c37.
//
// Solidity: function CHAIN_8453_YO_ETH_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN8453YOETHVAULT() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453YOETHVAULT(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453YOUSDVAULT is a free data retrieval call binding the contract method 0x8753565f.
//
// Solidity: function CHAIN_8453_YO_USD_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) CHAIN8453YOUSDVAULT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CHAIN_8453_YO_USD_VAULT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453YOUSDVAULT is a free data retrieval call binding the contract method 0x8753565f.
//
// Solidity: function CHAIN_8453_YO_USD_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) CHAIN8453YOUSDVAULT() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453YOUSDVAULT(&_StargateAdapterTest.CallOpts)
}

// CHAIN8453YOUSDVAULT is a free data retrieval call binding the contract method 0x8753565f.
//
// Solidity: function CHAIN_8453_YO_USD_VAULT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CHAIN8453YOUSDVAULT() (common.Address, error) {
	return _StargateAdapterTest.Contract.CHAIN8453YOUSDVAULT(&_StargateAdapterTest.CallOpts)
}

// CLAIMCANCELDEPOSITREQUEST7540HOOKKEY is a free data retrieval call binding the contract method 0xa511d386.
//
// Solidity: function CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) CLAIMCANCELDEPOSITREQUEST7540HOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// CLAIMCANCELDEPOSITREQUEST7540HOOKKEY is a free data retrieval call binding the contract method 0xa511d386.
//
// Solidity: function CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) CLAIMCANCELDEPOSITREQUEST7540HOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.CLAIMCANCELDEPOSITREQUEST7540HOOKKEY(&_StargateAdapterTest.CallOpts)
}

// CLAIMCANCELDEPOSITREQUEST7540HOOKKEY is a free data retrieval call binding the contract method 0xa511d386.
//
// Solidity: function CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CLAIMCANCELDEPOSITREQUEST7540HOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.CLAIMCANCELDEPOSITREQUEST7540HOOKKEY(&_StargateAdapterTest.CallOpts)
}

// CLAIMCANCELREDEEMREQUEST7540HOOKKEY is a free data retrieval call binding the contract method 0xe994b12a.
//
// Solidity: function CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) CLAIMCANCELREDEEMREQUEST7540HOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// CLAIMCANCELREDEEMREQUEST7540HOOKKEY is a free data retrieval call binding the contract method 0xe994b12a.
//
// Solidity: function CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) CLAIMCANCELREDEEMREQUEST7540HOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.CLAIMCANCELREDEEMREQUEST7540HOOKKEY(&_StargateAdapterTest.CallOpts)
}

// CLAIMCANCELREDEEMREQUEST7540HOOKKEY is a free data retrieval call binding the contract method 0xe994b12a.
//
// Solidity: function CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) CLAIMCANCELREDEEMREQUEST7540HOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.CLAIMCANCELREDEEMREQUEST7540HOOKKEY(&_StargateAdapterTest.CallOpts)
}

// DAIKEY is a free data retrieval call binding the contract method 0xd0cbbf75.
//
// Solidity: function DAI_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) DAIKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "DAI_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// DAIKEY is a free data retrieval call binding the contract method 0xd0cbbf75.
//
// Solidity: function DAI_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) DAIKEY() (string, error) {
	return _StargateAdapterTest.Contract.DAIKEY(&_StargateAdapterTest.CallOpts)
}

// DAIKEY is a free data retrieval call binding the contract method 0xd0cbbf75.
//
// Solidity: function DAI_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) DAIKEY() (string, error) {
	return _StargateAdapterTest.Contract.DAIKEY(&_StargateAdapterTest.CallOpts)
}

// DEBRIDGEADAPTERKEY is a free data retrieval call binding the contract method 0x3a1fd57e.
//
// Solidity: function DEBRIDGE_ADAPTER_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) DEBRIDGEADAPTERKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "DEBRIDGE_ADAPTER_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// DEBRIDGEADAPTERKEY is a free data retrieval call binding the contract method 0x3a1fd57e.
//
// Solidity: function DEBRIDGE_ADAPTER_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) DEBRIDGEADAPTERKEY() (string, error) {
	return _StargateAdapterTest.Contract.DEBRIDGEADAPTERKEY(&_StargateAdapterTest.CallOpts)
}

// DEBRIDGEADAPTERKEY is a free data retrieval call binding the contract method 0x3a1fd57e.
//
// Solidity: function DEBRIDGE_ADAPTER_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) DEBRIDGEADAPTERKEY() (string, error) {
	return _StargateAdapterTest.Contract.DEBRIDGEADAPTERKEY(&_StargateAdapterTest.CallOpts)
}

// DEBRIDGECANCELORDERHOOKKEY is a free data retrieval call binding the contract method 0xcc7603aa.
//
// Solidity: function DEBRIDGE_CANCEL_ORDER_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) DEBRIDGECANCELORDERHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "DEBRIDGE_CANCEL_ORDER_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// DEBRIDGECANCELORDERHOOKKEY is a free data retrieval call binding the contract method 0xcc7603aa.
//
// Solidity: function DEBRIDGE_CANCEL_ORDER_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) DEBRIDGECANCELORDERHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.DEBRIDGECANCELORDERHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// DEBRIDGECANCELORDERHOOKKEY is a free data retrieval call binding the contract method 0xcc7603aa.
//
// Solidity: function DEBRIDGE_CANCEL_ORDER_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) DEBRIDGECANCELORDERHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.DEBRIDGECANCELORDERHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// DEBRIDGEDLNDST is a free data retrieval call binding the contract method 0x1458a73f.
//
// Solidity: function DEBRIDGE_DLN_DST() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) DEBRIDGEDLNDST(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "DEBRIDGE_DLN_DST")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// DEBRIDGEDLNDST is a free data retrieval call binding the contract method 0x1458a73f.
//
// Solidity: function DEBRIDGE_DLN_DST() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) DEBRIDGEDLNDST() (common.Address, error) {
	return _StargateAdapterTest.Contract.DEBRIDGEDLNDST(&_StargateAdapterTest.CallOpts)
}

// DEBRIDGEDLNDST is a free data retrieval call binding the contract method 0x1458a73f.
//
// Solidity: function DEBRIDGE_DLN_DST() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) DEBRIDGEDLNDST() (common.Address, error) {
	return _StargateAdapterTest.Contract.DEBRIDGEDLNDST(&_StargateAdapterTest.CallOpts)
}

// DEBRIDGEDLNHELPERKEY is a free data retrieval call binding the contract method 0xaa54f472.
//
// Solidity: function DEBRIDGE_DLN_HELPER_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) DEBRIDGEDLNHELPERKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "DEBRIDGE_DLN_HELPER_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// DEBRIDGEDLNHELPERKEY is a free data retrieval call binding the contract method 0xaa54f472.
//
// Solidity: function DEBRIDGE_DLN_HELPER_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) DEBRIDGEDLNHELPERKEY() (string, error) {
	return _StargateAdapterTest.Contract.DEBRIDGEDLNHELPERKEY(&_StargateAdapterTest.CallOpts)
}

// DEBRIDGEDLNHELPERKEY is a free data retrieval call binding the contract method 0xaa54f472.
//
// Solidity: function DEBRIDGE_DLN_HELPER_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) DEBRIDGEDLNHELPERKEY() (string, error) {
	return _StargateAdapterTest.Contract.DEBRIDGEDLNHELPERKEY(&_StargateAdapterTest.CallOpts)
}

// DEBRIDGEDLNSOURCEADDRESS is a free data retrieval call binding the contract method 0x59564f70.
//
// Solidity: function DEBRIDGE_DLN_SOURCE_ADDRESS() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) DEBRIDGEDLNSOURCEADDRESS(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "DEBRIDGE_DLN_SOURCE_ADDRESS")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// DEBRIDGEDLNSOURCEADDRESS is a free data retrieval call binding the contract method 0x59564f70.
//
// Solidity: function DEBRIDGE_DLN_SOURCE_ADDRESS() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) DEBRIDGEDLNSOURCEADDRESS() (common.Address, error) {
	return _StargateAdapterTest.Contract.DEBRIDGEDLNSOURCEADDRESS(&_StargateAdapterTest.CallOpts)
}

// DEBRIDGEDLNSOURCEADDRESS is a free data retrieval call binding the contract method 0x59564f70.
//
// Solidity: function DEBRIDGE_DLN_SOURCE_ADDRESS() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) DEBRIDGEDLNSOURCEADDRESS() (common.Address, error) {
	return _StargateAdapterTest.Contract.DEBRIDGEDLNSOURCEADDRESS(&_StargateAdapterTest.CallOpts)
}

// DEBRIDGEHELPERKEY is a free data retrieval call binding the contract method 0xbdf47558.
//
// Solidity: function DEBRIDGE_HELPER_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) DEBRIDGEHELPERKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "DEBRIDGE_HELPER_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// DEBRIDGEHELPERKEY is a free data retrieval call binding the contract method 0xbdf47558.
//
// Solidity: function DEBRIDGE_HELPER_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) DEBRIDGEHELPERKEY() (string, error) {
	return _StargateAdapterTest.Contract.DEBRIDGEHELPERKEY(&_StargateAdapterTest.CallOpts)
}

// DEBRIDGEHELPERKEY is a free data retrieval call binding the contract method 0xbdf47558.
//
// Solidity: function DEBRIDGE_HELPER_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) DEBRIDGEHELPERKEY() (string, error) {
	return _StargateAdapterTest.Contract.DEBRIDGEHELPERKEY(&_StargateAdapterTest.CallOpts)
}

// DEBRIDGESENDORDERANDEXECUTEONDSTHOOKKEY is a free data retrieval call binding the contract method 0x56769a9c.
//
// Solidity: function DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) DEBRIDGESENDORDERANDEXECUTEONDSTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// DEBRIDGESENDORDERANDEXECUTEONDSTHOOKKEY is a free data retrieval call binding the contract method 0x56769a9c.
//
// Solidity: function DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) DEBRIDGESENDORDERANDEXECUTEONDSTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.DEBRIDGESENDORDERANDEXECUTEONDSTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// DEBRIDGESENDORDERANDEXECUTEONDSTHOOKKEY is a free data retrieval call binding the contract method 0x56769a9c.
//
// Solidity: function DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) DEBRIDGESENDORDERANDEXECUTEONDSTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.DEBRIDGESENDORDERANDEXECUTEONDSTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// DEPOSIT4626VAULTHOOKKEY is a free data retrieval call binding the contract method 0x4d0c825d.
//
// Solidity: function DEPOSIT_4626_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) DEPOSIT4626VAULTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "DEPOSIT_4626_VAULT_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// DEPOSIT4626VAULTHOOKKEY is a free data retrieval call binding the contract method 0x4d0c825d.
//
// Solidity: function DEPOSIT_4626_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) DEPOSIT4626VAULTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.DEPOSIT4626VAULTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// DEPOSIT4626VAULTHOOKKEY is a free data retrieval call binding the contract method 0x4d0c825d.
//
// Solidity: function DEPOSIT_4626_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) DEPOSIT4626VAULTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.DEPOSIT4626VAULTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// DEPOSIT5115VAULTHOOKKEY is a free data retrieval call binding the contract method 0x0ed4cb5d.
//
// Solidity: function DEPOSIT_5115_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) DEPOSIT5115VAULTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "DEPOSIT_5115_VAULT_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// DEPOSIT5115VAULTHOOKKEY is a free data retrieval call binding the contract method 0x0ed4cb5d.
//
// Solidity: function DEPOSIT_5115_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) DEPOSIT5115VAULTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.DEPOSIT5115VAULTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// DEPOSIT5115VAULTHOOKKEY is a free data retrieval call binding the contract method 0x0ed4cb5d.
//
// Solidity: function DEPOSIT_5115_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) DEPOSIT5115VAULTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.DEPOSIT5115VAULTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// DEPOSIT7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x6e53b637.
//
// Solidity: function DEPOSIT_7540_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) DEPOSIT7540VAULTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "DEPOSIT_7540_VAULT_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// DEPOSIT7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x6e53b637.
//
// Solidity: function DEPOSIT_7540_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) DEPOSIT7540VAULTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.DEPOSIT7540VAULTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// DEPOSIT7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x6e53b637.
//
// Solidity: function DEPOSIT_7540_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) DEPOSIT7540VAULTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.DEPOSIT7540VAULTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// ENTRYPOINTADDR is a free data retrieval call binding the contract method 0xc4bb9a07.
//
// Solidity: function ENTRYPOINT_ADDR() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) ENTRYPOINTADDR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "ENTRYPOINT_ADDR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// ENTRYPOINTADDR is a free data retrieval call binding the contract method 0xc4bb9a07.
//
// Solidity: function ENTRYPOINT_ADDR() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) ENTRYPOINTADDR() (common.Address, error) {
	return _StargateAdapterTest.Contract.ENTRYPOINTADDR(&_StargateAdapterTest.CallOpts)
}

// ENTRYPOINTADDR is a free data retrieval call binding the contract method 0xc4bb9a07.
//
// Solidity: function ENTRYPOINT_ADDR() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ENTRYPOINTADDR() (common.Address, error) {
	return _StargateAdapterTest.Contract.ENTRYPOINTADDR(&_StargateAdapterTest.CallOpts)
}

// ERC1155LEDGERKEY is a free data retrieval call binding the contract method 0x0995c88b.
//
// Solidity: function ERC1155_LEDGER_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) ERC1155LEDGERKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "ERC1155_LEDGER_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ERC1155LEDGERKEY is a free data retrieval call binding the contract method 0x0995c88b.
//
// Solidity: function ERC1155_LEDGER_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) ERC1155LEDGERKEY() (string, error) {
	return _StargateAdapterTest.Contract.ERC1155LEDGERKEY(&_StargateAdapterTest.CallOpts)
}

// ERC1155LEDGERKEY is a free data retrieval call binding the contract method 0x0995c88b.
//
// Solidity: function ERC1155_LEDGER_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ERC1155LEDGERKEY() (string, error) {
	return _StargateAdapterTest.Contract.ERC1155LEDGERKEY(&_StargateAdapterTest.CallOpts)
}

// ERC4626VAULTKEY is a free data retrieval call binding the contract method 0x59c528f6.
//
// Solidity: function ERC4626_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) ERC4626VAULTKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "ERC4626_VAULT_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ERC4626VAULTKEY is a free data retrieval call binding the contract method 0x59c528f6.
//
// Solidity: function ERC4626_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) ERC4626VAULTKEY() (string, error) {
	return _StargateAdapterTest.Contract.ERC4626VAULTKEY(&_StargateAdapterTest.CallOpts)
}

// ERC4626VAULTKEY is a free data retrieval call binding the contract method 0x59c528f6.
//
// Solidity: function ERC4626_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ERC4626VAULTKEY() (string, error) {
	return _StargateAdapterTest.Contract.ERC4626VAULTKEY(&_StargateAdapterTest.CallOpts)
}

// ERC4626YIELDSOURCEORACLEKEY is a free data retrieval call binding the contract method 0x3a58da28.
//
// Solidity: function ERC4626_YIELD_SOURCE_ORACLE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) ERC4626YIELDSOURCEORACLEKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "ERC4626_YIELD_SOURCE_ORACLE_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ERC4626YIELDSOURCEORACLEKEY is a free data retrieval call binding the contract method 0x3a58da28.
//
// Solidity: function ERC4626_YIELD_SOURCE_ORACLE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) ERC4626YIELDSOURCEORACLEKEY() (string, error) {
	return _StargateAdapterTest.Contract.ERC4626YIELDSOURCEORACLEKEY(&_StargateAdapterTest.CallOpts)
}

// ERC4626YIELDSOURCEORACLEKEY is a free data retrieval call binding the contract method 0x3a58da28.
//
// Solidity: function ERC4626_YIELD_SOURCE_ORACLE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ERC4626YIELDSOURCEORACLEKEY() (string, error) {
	return _StargateAdapterTest.Contract.ERC4626YIELDSOURCEORACLEKEY(&_StargateAdapterTest.CallOpts)
}

// ERC5115VAULTKEY is a free data retrieval call binding the contract method 0xa85353bc.
//
// Solidity: function ERC5115_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) ERC5115VAULTKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "ERC5115_VAULT_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ERC5115VAULTKEY is a free data retrieval call binding the contract method 0xa85353bc.
//
// Solidity: function ERC5115_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) ERC5115VAULTKEY() (string, error) {
	return _StargateAdapterTest.Contract.ERC5115VAULTKEY(&_StargateAdapterTest.CallOpts)
}

// ERC5115VAULTKEY is a free data retrieval call binding the contract method 0xa85353bc.
//
// Solidity: function ERC5115_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ERC5115VAULTKEY() (string, error) {
	return _StargateAdapterTest.Contract.ERC5115VAULTKEY(&_StargateAdapterTest.CallOpts)
}

// ERC5115YIELDSOURCEORACLEKEY is a free data retrieval call binding the contract method 0x4329fe83.
//
// Solidity: function ERC5115_YIELD_SOURCE_ORACLE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) ERC5115YIELDSOURCEORACLEKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "ERC5115_YIELD_SOURCE_ORACLE_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ERC5115YIELDSOURCEORACLEKEY is a free data retrieval call binding the contract method 0x4329fe83.
//
// Solidity: function ERC5115_YIELD_SOURCE_ORACLE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) ERC5115YIELDSOURCEORACLEKEY() (string, error) {
	return _StargateAdapterTest.Contract.ERC5115YIELDSOURCEORACLEKEY(&_StargateAdapterTest.CallOpts)
}

// ERC5115YIELDSOURCEORACLEKEY is a free data retrieval call binding the contract method 0x4329fe83.
//
// Solidity: function ERC5115_YIELD_SOURCE_ORACLE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ERC5115YIELDSOURCEORACLEKEY() (string, error) {
	return _StargateAdapterTest.Contract.ERC5115YIELDSOURCEORACLEKEY(&_StargateAdapterTest.CallOpts)
}

// ERC7540FULLYASYNCKEY is a free data retrieval call binding the contract method 0x665c8fb6.
//
// Solidity: function ERC7540_FULLY_ASYNC_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) ERC7540FULLYASYNCKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "ERC7540_FULLY_ASYNC_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ERC7540FULLYASYNCKEY is a free data retrieval call binding the contract method 0x665c8fb6.
//
// Solidity: function ERC7540_FULLY_ASYNC_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) ERC7540FULLYASYNCKEY() (string, error) {
	return _StargateAdapterTest.Contract.ERC7540FULLYASYNCKEY(&_StargateAdapterTest.CallOpts)
}

// ERC7540FULLYASYNCKEY is a free data retrieval call binding the contract method 0x665c8fb6.
//
// Solidity: function ERC7540_FULLY_ASYNC_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ERC7540FULLYASYNCKEY() (string, error) {
	return _StargateAdapterTest.Contract.ERC7540FULLYASYNCKEY(&_StargateAdapterTest.CallOpts)
}

// ERC7540YIELDSOURCEORACLEKEY is a free data retrieval call binding the contract method 0x68f007a2.
//
// Solidity: function ERC7540_YIELD_SOURCE_ORACLE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) ERC7540YIELDSOURCEORACLEKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "ERC7540_YIELD_SOURCE_ORACLE_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ERC7540YIELDSOURCEORACLEKEY is a free data retrieval call binding the contract method 0x68f007a2.
//
// Solidity: function ERC7540_YIELD_SOURCE_ORACLE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) ERC7540YIELDSOURCEORACLEKEY() (string, error) {
	return _StargateAdapterTest.Contract.ERC7540YIELDSOURCEORACLEKEY(&_StargateAdapterTest.CallOpts)
}

// ERC7540YIELDSOURCEORACLEKEY is a free data retrieval call binding the contract method 0x68f007a2.
//
// Solidity: function ERC7540_YIELD_SOURCE_ORACLE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ERC7540YIELDSOURCEORACLEKEY() (string, error) {
	return _StargateAdapterTest.Contract.ERC7540YIELDSOURCEORACLEKEY(&_StargateAdapterTest.CallOpts)
}

// ETH is a free data retrieval call binding the contract method 0x8322fff2.
//
// Solidity: function ETH() view returns(uint64)
func (_StargateAdapterTest *StargateAdapterTestCaller) ETH(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "ETH")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// ETH is a free data retrieval call binding the contract method 0x8322fff2.
//
// Solidity: function ETH() view returns(uint64)
func (_StargateAdapterTest *StargateAdapterTestSession) ETH() (uint64, error) {
	return _StargateAdapterTest.Contract.ETH(&_StargateAdapterTest.CallOpts)
}

// ETH is a free data retrieval call binding the contract method 0x8322fff2.
//
// Solidity: function ETH() view returns(uint64)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ETH() (uint64, error) {
	return _StargateAdapterTest.Contract.ETH(&_StargateAdapterTest.CallOpts)
}

// ETHENACOOLDOWNSHARESHOOKKEY is a free data retrieval call binding the contract method 0xcd4a8067.
//
// Solidity: function ETHENA_COOLDOWN_SHARES_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) ETHENACOOLDOWNSHARESHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "ETHENA_COOLDOWN_SHARES_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ETHENACOOLDOWNSHARESHOOKKEY is a free data retrieval call binding the contract method 0xcd4a8067.
//
// Solidity: function ETHENA_COOLDOWN_SHARES_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) ETHENACOOLDOWNSHARESHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.ETHENACOOLDOWNSHARESHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// ETHENACOOLDOWNSHARESHOOKKEY is a free data retrieval call binding the contract method 0xcd4a8067.
//
// Solidity: function ETHENA_COOLDOWN_SHARES_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ETHENACOOLDOWNSHARESHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.ETHENACOOLDOWNSHARESHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// ETHENAUNSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xec774bfe.
//
// Solidity: function ETHENA_UNSTAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) ETHENAUNSTAKEHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "ETHENA_UNSTAKE_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ETHENAUNSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xec774bfe.
//
// Solidity: function ETHENA_UNSTAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) ETHENAUNSTAKEHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.ETHENAUNSTAKEHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// ETHENAUNSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xec774bfe.
//
// Solidity: function ETHENA_UNSTAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ETHENAUNSTAKEHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.ETHENAUNSTAKEHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// ETHEREUMKEY is a free data retrieval call binding the contract method 0xe65d37f7.
//
// Solidity: function ETHEREUM_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) ETHEREUMKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "ETHEREUM_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ETHEREUMKEY is a free data retrieval call binding the contract method 0xe65d37f7.
//
// Solidity: function ETHEREUM_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) ETHEREUMKEY() (string, error) {
	return _StargateAdapterTest.Contract.ETHEREUMKEY(&_StargateAdapterTest.CallOpts)
}

// ETHEREUMKEY is a free data retrieval call binding the contract method 0xe65d37f7.
//
// Solidity: function ETHEREUM_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ETHEREUMKEY() (string, error) {
	return _StargateAdapterTest.Contract.ETHEREUMKEY(&_StargateAdapterTest.CallOpts)
}

// ETHEREUMRPCURLKEY is a free data retrieval call binding the contract method 0x6091ca77.
//
// Solidity: function ETHEREUM_RPC_URL_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) ETHEREUMRPCURLKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "ETHEREUM_RPC_URL_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ETHEREUMRPCURLKEY is a free data retrieval call binding the contract method 0x6091ca77.
//
// Solidity: function ETHEREUM_RPC_URL_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) ETHEREUMRPCURLKEY() (string, error) {
	return _StargateAdapterTest.Contract.ETHEREUMRPCURLKEY(&_StargateAdapterTest.CallOpts)
}

// ETHEREUMRPCURLKEY is a free data retrieval call binding the contract method 0x6091ca77.
//
// Solidity: function ETHEREUM_RPC_URL_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ETHEREUMRPCURLKEY() (string, error) {
	return _StargateAdapterTest.Contract.ETHEREUMRPCURLKEY(&_StargateAdapterTest.CallOpts)
}

// ETHBLOCK is a free data retrieval call binding the contract method 0x007e92d0.
//
// Solidity: function ETH_BLOCK() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCaller) ETHBLOCK(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "ETH_BLOCK")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// ETHBLOCK is a free data retrieval call binding the contract method 0x007e92d0.
//
// Solidity: function ETH_BLOCK() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestSession) ETHBLOCK() (*big.Int, error) {
	return _StargateAdapterTest.Contract.ETHBLOCK(&_StargateAdapterTest.CallOpts)
}

// ETHBLOCK is a free data retrieval call binding the contract method 0x007e92d0.
//
// Solidity: function ETH_BLOCK() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ETHBLOCK() (*big.Int, error) {
	return _StargateAdapterTest.Contract.ETHBLOCK(&_StargateAdapterTest.CallOpts)
}

// EULERVAULTKEY is a free data retrieval call binding the contract method 0x98b32718.
//
// Solidity: function EULER_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) EULERVAULTKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "EULER_VAULT_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// EULERVAULTKEY is a free data retrieval call binding the contract method 0x98b32718.
//
// Solidity: function EULER_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) EULERVAULTKEY() (string, error) {
	return _StargateAdapterTest.Contract.EULERVAULTKEY(&_StargateAdapterTest.CallOpts)
}

// EULERVAULTKEY is a free data retrieval call binding the contract method 0x98b32718.
//
// Solidity: function EULER_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) EULERVAULTKEY() (string, error) {
	return _StargateAdapterTest.Contract.EULERVAULTKEY(&_StargateAdapterTest.CallOpts)
}

// EXTRALARGE is a free data retrieval call binding the contract method 0x2038afcf.
//
// Solidity: function EXTRA_LARGE() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCaller) EXTRALARGE(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "EXTRA_LARGE")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// EXTRALARGE is a free data retrieval call binding the contract method 0x2038afcf.
//
// Solidity: function EXTRA_LARGE() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestSession) EXTRALARGE() (*big.Int, error) {
	return _StargateAdapterTest.Contract.EXTRALARGE(&_StargateAdapterTest.CallOpts)
}

// EXTRALARGE is a free data retrieval call binding the contract method 0x2038afcf.
//
// Solidity: function EXTRA_LARGE() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) EXTRALARGE() (*big.Int, error) {
	return _StargateAdapterTest.Contract.EXTRALARGE(&_StargateAdapterTest.CallOpts)
}

// FEERECIPIENTKEY is a free data retrieval call binding the contract method 0x0f4924f4.
//
// Solidity: function FEE_RECIPIENT_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCaller) FEERECIPIENTKEY(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "FEE_RECIPIENT_KEY")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// FEERECIPIENTKEY is a free data retrieval call binding the contract method 0x0f4924f4.
//
// Solidity: function FEE_RECIPIENT_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestSession) FEERECIPIENTKEY() (*big.Int, error) {
	return _StargateAdapterTest.Contract.FEERECIPIENTKEY(&_StargateAdapterTest.CallOpts)
}

// FEERECIPIENTKEY is a free data retrieval call binding the contract method 0x0f4924f4.
//
// Solidity: function FEE_RECIPIENT_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) FEERECIPIENTKEY() (*big.Int, error) {
	return _StargateAdapterTest.Contract.FEERECIPIENTKEY(&_StargateAdapterTest.CallOpts)
}

// FLAREALGEBRAINTEGRALSWAPROUTER is a free data retrieval call binding the contract method 0x866898e2.
//
// Solidity: function FLARE_ALGEBRA_INTEGRAL_SWAP_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) FLAREALGEBRAINTEGRALSWAPROUTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "FLARE_ALGEBRA_INTEGRAL_SWAP_ROUTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// FLAREALGEBRAINTEGRALSWAPROUTER is a free data retrieval call binding the contract method 0x866898e2.
//
// Solidity: function FLARE_ALGEBRA_INTEGRAL_SWAP_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) FLAREALGEBRAINTEGRALSWAPROUTER() (common.Address, error) {
	return _StargateAdapterTest.Contract.FLAREALGEBRAINTEGRALSWAPROUTER(&_StargateAdapterTest.CallOpts)
}

// FLAREALGEBRAINTEGRALSWAPROUTER is a free data retrieval call binding the contract method 0x866898e2.
//
// Solidity: function FLARE_ALGEBRA_INTEGRAL_SWAP_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) FLAREALGEBRAINTEGRALSWAPROUTER() (common.Address, error) {
	return _StargateAdapterTest.Contract.FLAREALGEBRAINTEGRALSWAPROUTER(&_StargateAdapterTest.CallOpts)
}

// FLAREALGEBRAPOOLDEPLOYER is a free data retrieval call binding the contract method 0x6be0daeb.
//
// Solidity: function FLARE_ALGEBRA_POOL_DEPLOYER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) FLAREALGEBRAPOOLDEPLOYER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "FLARE_ALGEBRA_POOL_DEPLOYER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// FLAREALGEBRAPOOLDEPLOYER is a free data retrieval call binding the contract method 0x6be0daeb.
//
// Solidity: function FLARE_ALGEBRA_POOL_DEPLOYER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) FLAREALGEBRAPOOLDEPLOYER() (common.Address, error) {
	return _StargateAdapterTest.Contract.FLAREALGEBRAPOOLDEPLOYER(&_StargateAdapterTest.CallOpts)
}

// FLAREALGEBRAPOOLDEPLOYER is a free data retrieval call binding the contract method 0x6be0daeb.
//
// Solidity: function FLARE_ALGEBRA_POOL_DEPLOYER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) FLAREALGEBRAPOOLDEPLOYER() (common.Address, error) {
	return _StargateAdapterTest.Contract.FLAREALGEBRAPOOLDEPLOYER(&_StargateAdapterTest.CallOpts)
}

// FLARERNAT is a free data retrieval call binding the contract method 0x8b94e9e6.
//
// Solidity: function FLARE_RNAT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) FLARERNAT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "FLARE_RNAT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// FLARERNAT is a free data retrieval call binding the contract method 0x8b94e9e6.
//
// Solidity: function FLARE_RNAT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) FLARERNAT() (common.Address, error) {
	return _StargateAdapterTest.Contract.FLARERNAT(&_StargateAdapterTest.CallOpts)
}

// FLARERNAT is a free data retrieval call binding the contract method 0x8b94e9e6.
//
// Solidity: function FLARE_RNAT() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) FLARERNAT() (common.Address, error) {
	return _StargateAdapterTest.Contract.FLARERNAT(&_StargateAdapterTest.CallOpts)
}

// FLARESFLR is a free data retrieval call binding the contract method 0xdfe1a5c0.
//
// Solidity: function FLARE_SFLR() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) FLARESFLR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "FLARE_SFLR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// FLARESFLR is a free data retrieval call binding the contract method 0xdfe1a5c0.
//
// Solidity: function FLARE_SFLR() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) FLARESFLR() (common.Address, error) {
	return _StargateAdapterTest.Contract.FLARESFLR(&_StargateAdapterTest.CallOpts)
}

// FLARESFLR is a free data retrieval call binding the contract method 0xdfe1a5c0.
//
// Solidity: function FLARE_SFLR() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) FLARESFLR() (common.Address, error) {
	return _StargateAdapterTest.Contract.FLARESFLR(&_StargateAdapterTest.CallOpts)
}

// FLARESPRK is a free data retrieval call binding the contract method 0x0813e2e6.
//
// Solidity: function FLARE_SPRK() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) FLARESPRK(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "FLARE_SPRK")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// FLARESPRK is a free data retrieval call binding the contract method 0x0813e2e6.
//
// Solidity: function FLARE_SPRK() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) FLARESPRK() (common.Address, error) {
	return _StargateAdapterTest.Contract.FLARESPRK(&_StargateAdapterTest.CallOpts)
}

// FLARESPRK is a free data retrieval call binding the contract method 0x0813e2e6.
//
// Solidity: function FLARE_SPRK() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) FLARESPRK() (common.Address, error) {
	return _StargateAdapterTest.Contract.FLARESPRK(&_StargateAdapterTest.CallOpts)
}

// FLAREWFLR is a free data retrieval call binding the contract method 0x40602604.
//
// Solidity: function FLARE_WFLR() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) FLAREWFLR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "FLARE_WFLR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// FLAREWFLR is a free data retrieval call binding the contract method 0x40602604.
//
// Solidity: function FLARE_WFLR() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) FLAREWFLR() (common.Address, error) {
	return _StargateAdapterTest.Contract.FLAREWFLR(&_StargateAdapterTest.CallOpts)
}

// FLAREWFLR is a free data retrieval call binding the contract method 0x40602604.
//
// Solidity: function FLARE_WFLR() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) FLAREWFLR() (common.Address, error) {
	return _StargateAdapterTest.Contract.FLAREWFLR(&_StargateAdapterTest.CallOpts)
}

// FLUIDCLAIMREWARDHOOKKEY is a free data retrieval call binding the contract method 0x7f927cda.
//
// Solidity: function FLUID_CLAIM_REWARD_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) FLUIDCLAIMREWARDHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "FLUID_CLAIM_REWARD_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// FLUIDCLAIMREWARDHOOKKEY is a free data retrieval call binding the contract method 0x7f927cda.
//
// Solidity: function FLUID_CLAIM_REWARD_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) FLUIDCLAIMREWARDHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.FLUIDCLAIMREWARDHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// FLUIDCLAIMREWARDHOOKKEY is a free data retrieval call binding the contract method 0x7f927cda.
//
// Solidity: function FLUID_CLAIM_REWARD_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) FLUIDCLAIMREWARDHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.FLUIDCLAIMREWARDHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// FLUIDSTAKEHOOKKEY is a free data retrieval call binding the contract method 0x66892cf0.
//
// Solidity: function FLUID_STAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) FLUIDSTAKEHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "FLUID_STAKE_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// FLUIDSTAKEHOOKKEY is a free data retrieval call binding the contract method 0x66892cf0.
//
// Solidity: function FLUID_STAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) FLUIDSTAKEHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.FLUIDSTAKEHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// FLUIDSTAKEHOOKKEY is a free data retrieval call binding the contract method 0x66892cf0.
//
// Solidity: function FLUID_STAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) FLUIDSTAKEHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.FLUIDSTAKEHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// FLUIDUNSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xe1d36abb.
//
// Solidity: function FLUID_UNSTAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) FLUIDUNSTAKEHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "FLUID_UNSTAKE_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// FLUIDUNSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xe1d36abb.
//
// Solidity: function FLUID_UNSTAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) FLUIDUNSTAKEHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.FLUIDUNSTAKEHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// FLUIDUNSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xe1d36abb.
//
// Solidity: function FLUID_UNSTAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) FLUIDUNSTAKEHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.FLUIDUNSTAKEHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// FLUIDVAULTKEY is a free data retrieval call binding the contract method 0x498005f7.
//
// Solidity: function FLUID_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) FLUIDVAULTKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "FLUID_VAULT_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// FLUIDVAULTKEY is a free data retrieval call binding the contract method 0x498005f7.
//
// Solidity: function FLUID_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) FLUIDVAULTKEY() (string, error) {
	return _StargateAdapterTest.Contract.FLUIDVAULTKEY(&_StargateAdapterTest.CallOpts)
}

// FLUIDVAULTKEY is a free data retrieval call binding the contract method 0x498005f7.
//
// Solidity: function FLUID_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) FLUIDVAULTKEY() (string, error) {
	return _StargateAdapterTest.Contract.FLUIDVAULTKEY(&_StargateAdapterTest.CallOpts)
}

// GEARBOXAPPROVEANDSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xa4b5a5f8.
//
// Solidity: function GEARBOX_APPROVE_AND_STAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) GEARBOXAPPROVEANDSTAKEHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "GEARBOX_APPROVE_AND_STAKE_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// GEARBOXAPPROVEANDSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xa4b5a5f8.
//
// Solidity: function GEARBOX_APPROVE_AND_STAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) GEARBOXAPPROVEANDSTAKEHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.GEARBOXAPPROVEANDSTAKEHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// GEARBOXAPPROVEANDSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xa4b5a5f8.
//
// Solidity: function GEARBOX_APPROVE_AND_STAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) GEARBOXAPPROVEANDSTAKEHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.GEARBOXAPPROVEANDSTAKEHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// GEARBOXCLAIMREWARDHOOKKEY is a free data retrieval call binding the contract method 0x5e101704.
//
// Solidity: function GEARBOX_CLAIM_REWARD_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) GEARBOXCLAIMREWARDHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "GEARBOX_CLAIM_REWARD_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// GEARBOXCLAIMREWARDHOOKKEY is a free data retrieval call binding the contract method 0x5e101704.
//
// Solidity: function GEARBOX_CLAIM_REWARD_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) GEARBOXCLAIMREWARDHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.GEARBOXCLAIMREWARDHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// GEARBOXCLAIMREWARDHOOKKEY is a free data retrieval call binding the contract method 0x5e101704.
//
// Solidity: function GEARBOX_CLAIM_REWARD_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) GEARBOXCLAIMREWARDHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.GEARBOXCLAIMREWARDHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// GEARBOXSTAKEHOOKKEY is a free data retrieval call binding the contract method 0x9a14bb34.
//
// Solidity: function GEARBOX_STAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) GEARBOXSTAKEHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "GEARBOX_STAKE_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// GEARBOXSTAKEHOOKKEY is a free data retrieval call binding the contract method 0x9a14bb34.
//
// Solidity: function GEARBOX_STAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) GEARBOXSTAKEHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.GEARBOXSTAKEHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// GEARBOXSTAKEHOOKKEY is a free data retrieval call binding the contract method 0x9a14bb34.
//
// Solidity: function GEARBOX_STAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) GEARBOXSTAKEHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.GEARBOXSTAKEHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// GEARBOXSTAKINGKEY is a free data retrieval call binding the contract method 0x96c407c4.
//
// Solidity: function GEARBOX_STAKING_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) GEARBOXSTAKINGKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "GEARBOX_STAKING_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// GEARBOXSTAKINGKEY is a free data retrieval call binding the contract method 0x96c407c4.
//
// Solidity: function GEARBOX_STAKING_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) GEARBOXSTAKINGKEY() (string, error) {
	return _StargateAdapterTest.Contract.GEARBOXSTAKINGKEY(&_StargateAdapterTest.CallOpts)
}

// GEARBOXSTAKINGKEY is a free data retrieval call binding the contract method 0x96c407c4.
//
// Solidity: function GEARBOX_STAKING_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) GEARBOXSTAKINGKEY() (string, error) {
	return _StargateAdapterTest.Contract.GEARBOXSTAKINGKEY(&_StargateAdapterTest.CallOpts)
}

// GEARBOXUNSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xf858de50.
//
// Solidity: function GEARBOX_UNSTAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) GEARBOXUNSTAKEHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "GEARBOX_UNSTAKE_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// GEARBOXUNSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xf858de50.
//
// Solidity: function GEARBOX_UNSTAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) GEARBOXUNSTAKEHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.GEARBOXUNSTAKEHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// GEARBOXUNSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xf858de50.
//
// Solidity: function GEARBOX_UNSTAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) GEARBOXUNSTAKEHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.GEARBOXUNSTAKEHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// GEARBOXVAULTKEY is a free data retrieval call binding the contract method 0xed385855.
//
// Solidity: function GEARBOX_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) GEARBOXVAULTKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "GEARBOX_VAULT_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// GEARBOXVAULTKEY is a free data retrieval call binding the contract method 0xed385855.
//
// Solidity: function GEARBOX_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) GEARBOXVAULTKEY() (string, error) {
	return _StargateAdapterTest.Contract.GEARBOXVAULTKEY(&_StargateAdapterTest.CallOpts)
}

// GEARBOXVAULTKEY is a free data retrieval call binding the contract method 0xed385855.
//
// Solidity: function GEARBOX_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) GEARBOXVAULTKEY() (string, error) {
	return _StargateAdapterTest.Contract.GEARBOXVAULTKEY(&_StargateAdapterTest.CallOpts)
}

// GEARKEY is a free data retrieval call binding the contract method 0xcb21fd61.
//
// Solidity: function GEAR_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) GEARKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "GEAR_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// GEARKEY is a free data retrieval call binding the contract method 0xcb21fd61.
//
// Solidity: function GEAR_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) GEARKEY() (string, error) {
	return _StargateAdapterTest.Contract.GEARKEY(&_StargateAdapterTest.CallOpts)
}

// GEARKEY is a free data retrieval call binding the contract method 0xcb21fd61.
//
// Solidity: function GEAR_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) GEARKEY() (string, error) {
	return _StargateAdapterTest.Contract.GEARKEY(&_StargateAdapterTest.CallOpts)
}

// ISTEST is a free data retrieval call binding the contract method 0xfa7626d4.
//
// Solidity: function IS_TEST() view returns(bool)
func (_StargateAdapterTest *StargateAdapterTestCaller) ISTEST(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "IS_TEST")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// ISTEST is a free data retrieval call binding the contract method 0xfa7626d4.
//
// Solidity: function IS_TEST() view returns(bool)
func (_StargateAdapterTest *StargateAdapterTestSession) ISTEST() (bool, error) {
	return _StargateAdapterTest.Contract.ISTEST(&_StargateAdapterTest.CallOpts)
}

// ISTEST is a free data retrieval call binding the contract method 0xfa7626d4.
//
// Solidity: function IS_TEST() view returns(bool)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ISTEST() (bool, error) {
	return _StargateAdapterTest.Contract.ISTEST(&_StargateAdapterTest.CallOpts)
}

// LARGE is a free data retrieval call binding the contract method 0xaed9a992.
//
// Solidity: function LARGE() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCaller) LARGE(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "LARGE")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// LARGE is a free data retrieval call binding the contract method 0xaed9a992.
//
// Solidity: function LARGE() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestSession) LARGE() (*big.Int, error) {
	return _StargateAdapterTest.Contract.LARGE(&_StargateAdapterTest.CallOpts)
}

// LARGE is a free data retrieval call binding the contract method 0xaed9a992.
//
// Solidity: function LARGE() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) LARGE() (*big.Int, error) {
	return _StargateAdapterTest.Contract.LARGE(&_StargateAdapterTest.CallOpts)
}

// MAINNETV2SWAPROUTER is a free data retrieval call binding the contract method 0x591431c0.
//
// Solidity: function MAINNET_V2_SWAP_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) MAINNETV2SWAPROUTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MAINNET_V2_SWAP_ROUTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MAINNETV2SWAPROUTER is a free data retrieval call binding the contract method 0x591431c0.
//
// Solidity: function MAINNET_V2_SWAP_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) MAINNETV2SWAPROUTER() (common.Address, error) {
	return _StargateAdapterTest.Contract.MAINNETV2SWAPROUTER(&_StargateAdapterTest.CallOpts)
}

// MAINNETV2SWAPROUTER is a free data retrieval call binding the contract method 0x591431c0.
//
// Solidity: function MAINNET_V2_SWAP_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MAINNETV2SWAPROUTER() (common.Address, error) {
	return _StargateAdapterTest.Contract.MAINNETV2SWAPROUTER(&_StargateAdapterTest.CallOpts)
}

// MAINNETV3SWAPROUTER is a free data retrieval call binding the contract method 0x6db42269.
//
// Solidity: function MAINNET_V3_SWAP_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) MAINNETV3SWAPROUTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MAINNET_V3_SWAP_ROUTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MAINNETV3SWAPROUTER is a free data retrieval call binding the contract method 0x6db42269.
//
// Solidity: function MAINNET_V3_SWAP_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) MAINNETV3SWAPROUTER() (common.Address, error) {
	return _StargateAdapterTest.Contract.MAINNETV3SWAPROUTER(&_StargateAdapterTest.CallOpts)
}

// MAINNETV3SWAPROUTER is a free data retrieval call binding the contract method 0x6db42269.
//
// Solidity: function MAINNET_V3_SWAP_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MAINNETV3SWAPROUTER() (common.Address, error) {
	return _StargateAdapterTest.Contract.MAINNETV3SWAPROUTER(&_StargateAdapterTest.CallOpts)
}

// MAINNETV3SWAPROUTER02 is a free data retrieval call binding the contract method 0x11f0e9ee.
//
// Solidity: function MAINNET_V3_SWAP_ROUTER_02() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) MAINNETV3SWAPROUTER02(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MAINNET_V3_SWAP_ROUTER_02")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MAINNETV3SWAPROUTER02 is a free data retrieval call binding the contract method 0x11f0e9ee.
//
// Solidity: function MAINNET_V3_SWAP_ROUTER_02() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) MAINNETV3SWAPROUTER02() (common.Address, error) {
	return _StargateAdapterTest.Contract.MAINNETV3SWAPROUTER02(&_StargateAdapterTest.CallOpts)
}

// MAINNETV3SWAPROUTER02 is a free data retrieval call binding the contract method 0x11f0e9ee.
//
// Solidity: function MAINNET_V3_SWAP_ROUTER_02() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MAINNETV3SWAPROUTER02() (common.Address, error) {
	return _StargateAdapterTest.Contract.MAINNETV3SWAPROUTER02(&_StargateAdapterTest.CallOpts)
}

// MAINNETV4POOLMANAGER is a free data retrieval call binding the contract method 0xdffb1fe2.
//
// Solidity: function MAINNET_V4_POOL_MANAGER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) MAINNETV4POOLMANAGER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MAINNET_V4_POOL_MANAGER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MAINNETV4POOLMANAGER is a free data retrieval call binding the contract method 0xdffb1fe2.
//
// Solidity: function MAINNET_V4_POOL_MANAGER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) MAINNETV4POOLMANAGER() (common.Address, error) {
	return _StargateAdapterTest.Contract.MAINNETV4POOLMANAGER(&_StargateAdapterTest.CallOpts)
}

// MAINNETV4POOLMANAGER is a free data retrieval call binding the contract method 0xdffb1fe2.
//
// Solidity: function MAINNET_V4_POOL_MANAGER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MAINNETV4POOLMANAGER() (common.Address, error) {
	return _StargateAdapterTest.Contract.MAINNETV4POOLMANAGER(&_StargateAdapterTest.CallOpts)
}

// MAINNETV4POSITIONMANAGER is a free data retrieval call binding the contract method 0xee649c5d.
//
// Solidity: function MAINNET_V4_POSITION_MANAGER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) MAINNETV4POSITIONMANAGER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MAINNET_V4_POSITION_MANAGER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MAINNETV4POSITIONMANAGER is a free data retrieval call binding the contract method 0xee649c5d.
//
// Solidity: function MAINNET_V4_POSITION_MANAGER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) MAINNETV4POSITIONMANAGER() (common.Address, error) {
	return _StargateAdapterTest.Contract.MAINNETV4POSITIONMANAGER(&_StargateAdapterTest.CallOpts)
}

// MAINNETV4POSITIONMANAGER is a free data retrieval call binding the contract method 0xee649c5d.
//
// Solidity: function MAINNET_V4_POSITION_MANAGER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MAINNETV4POSITIONMANAGER() (common.Address, error) {
	return _StargateAdapterTest.Contract.MAINNETV4POSITIONMANAGER(&_StargateAdapterTest.CallOpts)
}

// MANAGER is a free data retrieval call binding the contract method 0x1b2df850.
//
// Solidity: function MANAGER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) MANAGER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MANAGER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MANAGER is a free data retrieval call binding the contract method 0x1b2df850.
//
// Solidity: function MANAGER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) MANAGER() (common.Address, error) {
	return _StargateAdapterTest.Contract.MANAGER(&_StargateAdapterTest.CallOpts)
}

// MANAGER is a free data retrieval call binding the contract method 0x1b2df850.
//
// Solidity: function MANAGER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MANAGER() (common.Address, error) {
	return _StargateAdapterTest.Contract.MANAGER(&_StargateAdapterTest.CallOpts)
}

// MANAGERKEY is a free data retrieval call binding the contract method 0x97d94ca0.
//
// Solidity: function MANAGER_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCaller) MANAGERKEY(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MANAGER_KEY")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// MANAGERKEY is a free data retrieval call binding the contract method 0x97d94ca0.
//
// Solidity: function MANAGER_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestSession) MANAGERKEY() (*big.Int, error) {
	return _StargateAdapterTest.Contract.MANAGERKEY(&_StargateAdapterTest.CallOpts)
}

// MANAGERKEY is a free data retrieval call binding the contract method 0x97d94ca0.
//
// Solidity: function MANAGER_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MANAGERKEY() (*big.Int, error) {
	return _StargateAdapterTest.Contract.MANAGERKEY(&_StargateAdapterTest.CallOpts)
}

// MARKROOTASUSEDHOOKKEY is a free data retrieval call binding the contract method 0x08568475.
//
// Solidity: function MARK_ROOT_AS_USED_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) MARKROOTASUSEDHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MARK_ROOT_AS_USED_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// MARKROOTASUSEDHOOKKEY is a free data retrieval call binding the contract method 0x08568475.
//
// Solidity: function MARK_ROOT_AS_USED_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) MARKROOTASUSEDHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.MARKROOTASUSEDHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// MARKROOTASUSEDHOOKKEY is a free data retrieval call binding the contract method 0x08568475.
//
// Solidity: function MARK_ROOT_AS_USED_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MARKROOTASUSEDHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.MARKROOTASUSEDHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// MEDIUM is a free data retrieval call binding the contract method 0xedee709e.
//
// Solidity: function MEDIUM() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCaller) MEDIUM(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MEDIUM")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// MEDIUM is a free data retrieval call binding the contract method 0xedee709e.
//
// Solidity: function MEDIUM() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestSession) MEDIUM() (*big.Int, error) {
	return _StargateAdapterTest.Contract.MEDIUM(&_StargateAdapterTest.CallOpts)
}

// MEDIUM is a free data retrieval call binding the contract method 0xedee709e.
//
// Solidity: function MEDIUM() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MEDIUM() (*big.Int, error) {
	return _StargateAdapterTest.Contract.MEDIUM(&_StargateAdapterTest.CallOpts)
}

// MERKLCLAIMREWARDHOOKKEY is a free data retrieval call binding the contract method 0x1fb43e65.
//
// Solidity: function MERKL_CLAIM_REWARD_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) MERKLCLAIMREWARDHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MERKL_CLAIM_REWARD_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// MERKLCLAIMREWARDHOOKKEY is a free data retrieval call binding the contract method 0x1fb43e65.
//
// Solidity: function MERKL_CLAIM_REWARD_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) MERKLCLAIMREWARDHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.MERKLCLAIMREWARDHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// MERKLCLAIMREWARDHOOKKEY is a free data retrieval call binding the contract method 0x1fb43e65.
//
// Solidity: function MERKL_CLAIM_REWARD_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MERKLCLAIMREWARDHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.MERKLCLAIMREWARDHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// MERKLDISTRIBUTOR is a free data retrieval call binding the contract method 0x219461ed.
//
// Solidity: function MERKL_DISTRIBUTOR() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) MERKLDISTRIBUTOR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MERKL_DISTRIBUTOR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MERKLDISTRIBUTOR is a free data retrieval call binding the contract method 0x219461ed.
//
// Solidity: function MERKL_DISTRIBUTOR() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) MERKLDISTRIBUTOR() (common.Address, error) {
	return _StargateAdapterTest.Contract.MERKLDISTRIBUTOR(&_StargateAdapterTest.CallOpts)
}

// MERKLDISTRIBUTOR is a free data retrieval call binding the contract method 0x219461ed.
//
// Solidity: function MERKL_DISTRIBUTOR() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MERKLDISTRIBUTOR() (common.Address, error) {
	return _StargateAdapterTest.Contract.MERKLDISTRIBUTOR(&_StargateAdapterTest.CallOpts)
}

// MINTSUPERPOSITIONSHOOKKEY is a free data retrieval call binding the contract method 0x206fe8a5.
//
// Solidity: function MINT_SUPERPOSITIONS_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) MINTSUPERPOSITIONSHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MINT_SUPERPOSITIONS_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// MINTSUPERPOSITIONSHOOKKEY is a free data retrieval call binding the contract method 0x206fe8a5.
//
// Solidity: function MINT_SUPERPOSITIONS_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) MINTSUPERPOSITIONSHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.MINTSUPERPOSITIONSHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// MINTSUPERPOSITIONSHOOKKEY is a free data retrieval call binding the contract method 0x206fe8a5.
//
// Solidity: function MINT_SUPERPOSITIONS_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MINTSUPERPOSITIONSHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.MINTSUPERPOSITIONSHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// MOCKAPPROVEANDSWAPODOSHOOKKEY is a free data retrieval call binding the contract method 0x56a4d4be.
//
// Solidity: function MOCK_APPROVE_AND_SWAP_ODOS_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) MOCKAPPROVEANDSWAPODOSHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MOCK_APPROVE_AND_SWAP_ODOS_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// MOCKAPPROVEANDSWAPODOSHOOKKEY is a free data retrieval call binding the contract method 0x56a4d4be.
//
// Solidity: function MOCK_APPROVE_AND_SWAP_ODOS_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) MOCKAPPROVEANDSWAPODOSHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.MOCKAPPROVEANDSWAPODOSHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// MOCKAPPROVEANDSWAPODOSHOOKKEY is a free data retrieval call binding the contract method 0x56a4d4be.
//
// Solidity: function MOCK_APPROVE_AND_SWAP_ODOS_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MOCKAPPROVEANDSWAPODOSHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.MOCKAPPROVEANDSWAPODOSHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// MOCKSWAPODOSHOOKKEY is a free data retrieval call binding the contract method 0x290c185f.
//
// Solidity: function MOCK_SWAP_ODOS_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) MOCKSWAPODOSHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MOCK_SWAP_ODOS_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// MOCKSWAPODOSHOOKKEY is a free data retrieval call binding the contract method 0x290c185f.
//
// Solidity: function MOCK_SWAP_ODOS_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) MOCKSWAPODOSHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.MOCKSWAPODOSHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// MOCKSWAPODOSHOOKKEY is a free data retrieval call binding the contract method 0x290c185f.
//
// Solidity: function MOCK_SWAP_ODOS_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MOCKSWAPODOSHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.MOCKSWAPODOSHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// MOCKTARGETEXECUTORKEY is a free data retrieval call binding the contract method 0x49307462.
//
// Solidity: function MOCK_TARGET_EXECUTOR_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) MOCKTARGETEXECUTORKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MOCK_TARGET_EXECUTOR_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// MOCKTARGETEXECUTORKEY is a free data retrieval call binding the contract method 0x49307462.
//
// Solidity: function MOCK_TARGET_EXECUTOR_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) MOCKTARGETEXECUTORKEY() (string, error) {
	return _StargateAdapterTest.Contract.MOCKTARGETEXECUTORKEY(&_StargateAdapterTest.CallOpts)
}

// MOCKTARGETEXECUTORKEY is a free data retrieval call binding the contract method 0x49307462.
//
// Solidity: function MOCK_TARGET_EXECUTOR_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MOCKTARGETEXECUTORKEY() (string, error) {
	return _StargateAdapterTest.Contract.MOCKTARGETEXECUTORKEY(&_StargateAdapterTest.CallOpts)
}

// MORPHO is a free data retrieval call binding the contract method 0x3acb5624.
//
// Solidity: function MORPHO() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) MORPHO(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MORPHO")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MORPHO is a free data retrieval call binding the contract method 0x3acb5624.
//
// Solidity: function MORPHO() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) MORPHO() (common.Address, error) {
	return _StargateAdapterTest.Contract.MORPHO(&_StargateAdapterTest.CallOpts)
}

// MORPHO is a free data retrieval call binding the contract method 0x3acb5624.
//
// Solidity: function MORPHO() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MORPHO() (common.Address, error) {
	return _StargateAdapterTest.Contract.MORPHO(&_StargateAdapterTest.CallOpts)
}

// MORPHOBORROWHOOKKEY is a free data retrieval call binding the contract method 0x35a4e139.
//
// Solidity: function MORPHO_BORROW_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) MORPHOBORROWHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MORPHO_BORROW_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// MORPHOBORROWHOOKKEY is a free data retrieval call binding the contract method 0x35a4e139.
//
// Solidity: function MORPHO_BORROW_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) MORPHOBORROWHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.MORPHOBORROWHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// MORPHOBORROWHOOKKEY is a free data retrieval call binding the contract method 0x35a4e139.
//
// Solidity: function MORPHO_BORROW_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MORPHOBORROWHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.MORPHOBORROWHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// MORPHOGAUNTLETUSDCPRIMEKEY is a free data retrieval call binding the contract method 0x7d94dc87.
//
// Solidity: function MORPHO_GAUNTLET_USDC_PRIME_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) MORPHOGAUNTLETUSDCPRIMEKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MORPHO_GAUNTLET_USDC_PRIME_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// MORPHOGAUNTLETUSDCPRIMEKEY is a free data retrieval call binding the contract method 0x7d94dc87.
//
// Solidity: function MORPHO_GAUNTLET_USDC_PRIME_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) MORPHOGAUNTLETUSDCPRIMEKEY() (string, error) {
	return _StargateAdapterTest.Contract.MORPHOGAUNTLETUSDCPRIMEKEY(&_StargateAdapterTest.CallOpts)
}

// MORPHOGAUNTLETUSDCPRIMEKEY is a free data retrieval call binding the contract method 0x7d94dc87.
//
// Solidity: function MORPHO_GAUNTLET_USDC_PRIME_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MORPHOGAUNTLETUSDCPRIMEKEY() (string, error) {
	return _StargateAdapterTest.Contract.MORPHOGAUNTLETUSDCPRIMEKEY(&_StargateAdapterTest.CallOpts)
}

// MORPHOGAUNTLETWETHCOREKEY is a free data retrieval call binding the contract method 0xc55a92a8.
//
// Solidity: function MORPHO_GAUNTLET_WETH_CORE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) MORPHOGAUNTLETWETHCOREKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MORPHO_GAUNTLET_WETH_CORE_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// MORPHOGAUNTLETWETHCOREKEY is a free data retrieval call binding the contract method 0xc55a92a8.
//
// Solidity: function MORPHO_GAUNTLET_WETH_CORE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) MORPHOGAUNTLETWETHCOREKEY() (string, error) {
	return _StargateAdapterTest.Contract.MORPHOGAUNTLETWETHCOREKEY(&_StargateAdapterTest.CallOpts)
}

// MORPHOGAUNTLETWETHCOREKEY is a free data retrieval call binding the contract method 0xc55a92a8.
//
// Solidity: function MORPHO_GAUNTLET_WETH_CORE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MORPHOGAUNTLETWETHCOREKEY() (string, error) {
	return _StargateAdapterTest.Contract.MORPHOGAUNTLETWETHCOREKEY(&_StargateAdapterTest.CallOpts)
}

// MORPHOIRM is a free data retrieval call binding the contract method 0x40158af6.
//
// Solidity: function MORPHO_IRM() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) MORPHOIRM(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MORPHO_IRM")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MORPHOIRM is a free data retrieval call binding the contract method 0x40158af6.
//
// Solidity: function MORPHO_IRM() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) MORPHOIRM() (common.Address, error) {
	return _StargateAdapterTest.Contract.MORPHOIRM(&_StargateAdapterTest.CallOpts)
}

// MORPHOIRM is a free data retrieval call binding the contract method 0x40158af6.
//
// Solidity: function MORPHO_IRM() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MORPHOIRM() (common.Address, error) {
	return _StargateAdapterTest.Contract.MORPHOIRM(&_StargateAdapterTest.CallOpts)
}

// MORPHOIRMWBTCUSDC is a free data retrieval call binding the contract method 0xec788042.
//
// Solidity: function MORPHO_IRM_WBTC_USDC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) MORPHOIRMWBTCUSDC(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MORPHO_IRM_WBTC_USDC")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MORPHOIRMWBTCUSDC is a free data retrieval call binding the contract method 0xec788042.
//
// Solidity: function MORPHO_IRM_WBTC_USDC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) MORPHOIRMWBTCUSDC() (common.Address, error) {
	return _StargateAdapterTest.Contract.MORPHOIRMWBTCUSDC(&_StargateAdapterTest.CallOpts)
}

// MORPHOIRMWBTCUSDC is a free data retrieval call binding the contract method 0xec788042.
//
// Solidity: function MORPHO_IRM_WBTC_USDC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MORPHOIRMWBTCUSDC() (common.Address, error) {
	return _StargateAdapterTest.Contract.MORPHOIRMWBTCUSDC(&_StargateAdapterTest.CallOpts)
}

// MORPHOKEY is a free data retrieval call binding the contract method 0xac5e42bd.
//
// Solidity: function MORPHO_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) MORPHOKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MORPHO_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// MORPHOKEY is a free data retrieval call binding the contract method 0xac5e42bd.
//
// Solidity: function MORPHO_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) MORPHOKEY() (string, error) {
	return _StargateAdapterTest.Contract.MORPHOKEY(&_StargateAdapterTest.CallOpts)
}

// MORPHOKEY is a free data retrieval call binding the contract method 0xac5e42bd.
//
// Solidity: function MORPHO_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MORPHOKEY() (string, error) {
	return _StargateAdapterTest.Contract.MORPHOKEY(&_StargateAdapterTest.CallOpts)
}

// MORPHOORACLE is a free data retrieval call binding the contract method 0xdfe287d3.
//
// Solidity: function MORPHO_ORACLE() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) MORPHOORACLE(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MORPHO_ORACLE")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MORPHOORACLE is a free data retrieval call binding the contract method 0xdfe287d3.
//
// Solidity: function MORPHO_ORACLE() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) MORPHOORACLE() (common.Address, error) {
	return _StargateAdapterTest.Contract.MORPHOORACLE(&_StargateAdapterTest.CallOpts)
}

// MORPHOORACLE is a free data retrieval call binding the contract method 0xdfe287d3.
//
// Solidity: function MORPHO_ORACLE() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MORPHOORACLE() (common.Address, error) {
	return _StargateAdapterTest.Contract.MORPHOORACLE(&_StargateAdapterTest.CallOpts)
}

// MORPHOORACLEWBTCUSDC is a free data retrieval call binding the contract method 0x61f02c02.
//
// Solidity: function MORPHO_ORACLE_WBTC_USDC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) MORPHOORACLEWBTCUSDC(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MORPHO_ORACLE_WBTC_USDC")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MORPHOORACLEWBTCUSDC is a free data retrieval call binding the contract method 0x61f02c02.
//
// Solidity: function MORPHO_ORACLE_WBTC_USDC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) MORPHOORACLEWBTCUSDC() (common.Address, error) {
	return _StargateAdapterTest.Contract.MORPHOORACLEWBTCUSDC(&_StargateAdapterTest.CallOpts)
}

// MORPHOORACLEWBTCUSDC is a free data retrieval call binding the contract method 0x61f02c02.
//
// Solidity: function MORPHO_ORACLE_WBTC_USDC() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MORPHOORACLEWBTCUSDC() (common.Address, error) {
	return _StargateAdapterTest.Contract.MORPHOORACLEWBTCUSDC(&_StargateAdapterTest.CallOpts)
}

// MORPHOREPAYANDWITHDRAWHOOKKEY is a free data retrieval call binding the contract method 0x7473dec6.
//
// Solidity: function MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) MORPHOREPAYANDWITHDRAWHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// MORPHOREPAYANDWITHDRAWHOOKKEY is a free data retrieval call binding the contract method 0x7473dec6.
//
// Solidity: function MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) MORPHOREPAYANDWITHDRAWHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.MORPHOREPAYANDWITHDRAWHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// MORPHOREPAYANDWITHDRAWHOOKKEY is a free data retrieval call binding the contract method 0x7473dec6.
//
// Solidity: function MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MORPHOREPAYANDWITHDRAWHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.MORPHOREPAYANDWITHDRAWHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// MORPHOREPAYHOOKKEY is a free data retrieval call binding the contract method 0x44eaffae.
//
// Solidity: function MORPHO_REPAY_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) MORPHOREPAYHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MORPHO_REPAY_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// MORPHOREPAYHOOKKEY is a free data retrieval call binding the contract method 0x44eaffae.
//
// Solidity: function MORPHO_REPAY_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) MORPHOREPAYHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.MORPHOREPAYHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// MORPHOREPAYHOOKKEY is a free data retrieval call binding the contract method 0x44eaffae.
//
// Solidity: function MORPHO_REPAY_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MORPHOREPAYHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.MORPHOREPAYHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// MORPHOVAULTKEY is a free data retrieval call binding the contract method 0x54fab870.
//
// Solidity: function MORPHO_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) MORPHOVAULTKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "MORPHO_VAULT_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// MORPHOVAULTKEY is a free data retrieval call binding the contract method 0x54fab870.
//
// Solidity: function MORPHO_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) MORPHOVAULTKEY() (string, error) {
	return _StargateAdapterTest.Contract.MORPHOVAULTKEY(&_StargateAdapterTest.CallOpts)
}

// MORPHOVAULTKEY is a free data retrieval call binding the contract method 0x54fab870.
//
// Solidity: function MORPHO_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MORPHOVAULTKEY() (string, error) {
	return _StargateAdapterTest.Contract.MORPHOVAULTKEY(&_StargateAdapterTest.CallOpts)
}

// NEXUSACCOUNTIMPLEMENTATIONID is a free data retrieval call binding the contract method 0xe8a18c2e.
//
// Solidity: function NEXUS_ACCOUNT_IMPLEMENTATION_ID() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) NEXUSACCOUNTIMPLEMENTATIONID(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "NEXUS_ACCOUNT_IMPLEMENTATION_ID")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// NEXUSACCOUNTIMPLEMENTATIONID is a free data retrieval call binding the contract method 0xe8a18c2e.
//
// Solidity: function NEXUS_ACCOUNT_IMPLEMENTATION_ID() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) NEXUSACCOUNTIMPLEMENTATIONID() (string, error) {
	return _StargateAdapterTest.Contract.NEXUSACCOUNTIMPLEMENTATIONID(&_StargateAdapterTest.CallOpts)
}

// NEXUSACCOUNTIMPLEMENTATIONID is a free data retrieval call binding the contract method 0xe8a18c2e.
//
// Solidity: function NEXUS_ACCOUNT_IMPLEMENTATION_ID() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) NEXUSACCOUNTIMPLEMENTATIONID() (string, error) {
	return _StargateAdapterTest.Contract.NEXUSACCOUNTIMPLEMENTATIONID(&_StargateAdapterTest.CallOpts)
}

// ODOSROUTERV3 is a free data retrieval call binding the contract method 0x2b696932.
//
// Solidity: function ODOS_ROUTER_V3() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) ODOSROUTERV3(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "ODOS_ROUTER_V3")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// ODOSROUTERV3 is a free data retrieval call binding the contract method 0x2b696932.
//
// Solidity: function ODOS_ROUTER_V3() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) ODOSROUTERV3() (common.Address, error) {
	return _StargateAdapterTest.Contract.ODOSROUTERV3(&_StargateAdapterTest.CallOpts)
}

// ODOSROUTERV3 is a free data retrieval call binding the contract method 0x2b696932.
//
// Solidity: function ODOS_ROUTER_V3() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ODOSROUTERV3() (common.Address, error) {
	return _StargateAdapterTest.Contract.ODOSROUTERV3(&_StargateAdapterTest.CallOpts)
}

// OFFRAMPTOKENSHOOKKEY is a free data retrieval call binding the contract method 0x8ba28269.
//
// Solidity: function OFFRAMP_TOKENS_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) OFFRAMPTOKENSHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "OFFRAMP_TOKENS_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// OFFRAMPTOKENSHOOKKEY is a free data retrieval call binding the contract method 0x8ba28269.
//
// Solidity: function OFFRAMP_TOKENS_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) OFFRAMPTOKENSHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.OFFRAMPTOKENSHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// OFFRAMPTOKENSHOOKKEY is a free data retrieval call binding the contract method 0x8ba28269.
//
// Solidity: function OFFRAMP_TOKENS_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) OFFRAMPTOKENSHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.OFFRAMPTOKENSHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// ONEINCHAPIKEY is a free data retrieval call binding the contract method 0x375b3e62.
//
// Solidity: function ONE_INCH_API_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) ONEINCHAPIKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "ONE_INCH_API_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ONEINCHAPIKEY is a free data retrieval call binding the contract method 0x375b3e62.
//
// Solidity: function ONE_INCH_API_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) ONEINCHAPIKEY() (string, error) {
	return _StargateAdapterTest.Contract.ONEINCHAPIKEY(&_StargateAdapterTest.CallOpts)
}

// ONEINCHAPIKEY is a free data retrieval call binding the contract method 0x375b3e62.
//
// Solidity: function ONE_INCH_API_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ONEINCHAPIKEY() (string, error) {
	return _StargateAdapterTest.Contract.ONEINCHAPIKEY(&_StargateAdapterTest.CallOpts)
}

// ONEINCHROUTER is a free data retrieval call binding the contract method 0xdd3fd925.
//
// Solidity: function ONE_INCH_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) ONEINCHROUTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "ONE_INCH_ROUTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// ONEINCHROUTER is a free data retrieval call binding the contract method 0xdd3fd925.
//
// Solidity: function ONE_INCH_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) ONEINCHROUTER() (common.Address, error) {
	return _StargateAdapterTest.Contract.ONEINCHROUTER(&_StargateAdapterTest.CallOpts)
}

// ONEINCHROUTER is a free data retrieval call binding the contract method 0xdd3fd925.
//
// Solidity: function ONE_INCH_ROUTER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ONEINCHROUTER() (common.Address, error) {
	return _StargateAdapterTest.Contract.ONEINCHROUTER(&_StargateAdapterTest.CallOpts)
}

// OP is a free data retrieval call binding the contract method 0x7c9c3472.
//
// Solidity: function OP() view returns(uint64)
func (_StargateAdapterTest *StargateAdapterTestCaller) OP(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "OP")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// OP is a free data retrieval call binding the contract method 0x7c9c3472.
//
// Solidity: function OP() view returns(uint64)
func (_StargateAdapterTest *StargateAdapterTestSession) OP() (uint64, error) {
	return _StargateAdapterTest.Contract.OP(&_StargateAdapterTest.CallOpts)
}

// OP is a free data retrieval call binding the contract method 0x7c9c3472.
//
// Solidity: function OP() view returns(uint64)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) OP() (uint64, error) {
	return _StargateAdapterTest.Contract.OP(&_StargateAdapterTest.CallOpts)
}

// OPTIMISMKEY is a free data retrieval call binding the contract method 0xc61154b7.
//
// Solidity: function OPTIMISM_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) OPTIMISMKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "OPTIMISM_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// OPTIMISMKEY is a free data retrieval call binding the contract method 0xc61154b7.
//
// Solidity: function OPTIMISM_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) OPTIMISMKEY() (string, error) {
	return _StargateAdapterTest.Contract.OPTIMISMKEY(&_StargateAdapterTest.CallOpts)
}

// OPTIMISMKEY is a free data retrieval call binding the contract method 0xc61154b7.
//
// Solidity: function OPTIMISM_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) OPTIMISMKEY() (string, error) {
	return _StargateAdapterTest.Contract.OPTIMISMKEY(&_StargateAdapterTest.CallOpts)
}

// OPTIMISMRPCURLKEY is a free data retrieval call binding the contract method 0xd0160791.
//
// Solidity: function OPTIMISM_RPC_URL_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) OPTIMISMRPCURLKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "OPTIMISM_RPC_URL_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// OPTIMISMRPCURLKEY is a free data retrieval call binding the contract method 0xd0160791.
//
// Solidity: function OPTIMISM_RPC_URL_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) OPTIMISMRPCURLKEY() (string, error) {
	return _StargateAdapterTest.Contract.OPTIMISMRPCURLKEY(&_StargateAdapterTest.CallOpts)
}

// OPTIMISMRPCURLKEY is a free data retrieval call binding the contract method 0xd0160791.
//
// Solidity: function OPTIMISM_RPC_URL_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) OPTIMISMRPCURLKEY() (string, error) {
	return _StargateAdapterTest.Contract.OPTIMISMRPCURLKEY(&_StargateAdapterTest.CallOpts)
}

// OPBLOCK is a free data retrieval call binding the contract method 0xc1276b04.
//
// Solidity: function OP_BLOCK() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCaller) OPBLOCK(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "OP_BLOCK")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// OPBLOCK is a free data retrieval call binding the contract method 0xc1276b04.
//
// Solidity: function OP_BLOCK() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestSession) OPBLOCK() (*big.Int, error) {
	return _StargateAdapterTest.Contract.OPBLOCK(&_StargateAdapterTest.CallOpts)
}

// OPBLOCK is a free data retrieval call binding the contract method 0xc1276b04.
//
// Solidity: function OP_BLOCK() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) OPBLOCK() (*big.Int, error) {
	return _StargateAdapterTest.Contract.OPBLOCK(&_StargateAdapterTest.CallOpts)
}

// PENDLEETHENAKEY is a free data retrieval call binding the contract method 0xb203dfce.
//
// Solidity: function PENDLE_ETHENA_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) PENDLEETHENAKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "PENDLE_ETHENA_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// PENDLEETHENAKEY is a free data retrieval call binding the contract method 0xb203dfce.
//
// Solidity: function PENDLE_ETHENA_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) PENDLEETHENAKEY() (string, error) {
	return _StargateAdapterTest.Contract.PENDLEETHENAKEY(&_StargateAdapterTest.CallOpts)
}

// PENDLEETHENAKEY is a free data retrieval call binding the contract method 0xb203dfce.
//
// Solidity: function PENDLE_ETHENA_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) PENDLEETHENAKEY() (string, error) {
	return _StargateAdapterTest.Contract.PENDLEETHENAKEY(&_StargateAdapterTest.CallOpts)
}

// PENDLEROUTERREDEEMHOOKKEY is a free data retrieval call binding the contract method 0x21a99db0.
//
// Solidity: function PENDLE_ROUTER_REDEEM_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) PENDLEROUTERREDEEMHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "PENDLE_ROUTER_REDEEM_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// PENDLEROUTERREDEEMHOOKKEY is a free data retrieval call binding the contract method 0x21a99db0.
//
// Solidity: function PENDLE_ROUTER_REDEEM_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) PENDLEROUTERREDEEMHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.PENDLEROUTERREDEEMHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// PENDLEROUTERREDEEMHOOKKEY is a free data retrieval call binding the contract method 0x21a99db0.
//
// Solidity: function PENDLE_ROUTER_REDEEM_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) PENDLEROUTERREDEEMHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.PENDLEROUTERREDEEMHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// PENDLEROUTERSWAPHOOKKEY is a free data retrieval call binding the contract method 0x2ddd29d1.
//
// Solidity: function PENDLE_ROUTER_SWAP_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) PENDLEROUTERSWAPHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "PENDLE_ROUTER_SWAP_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// PENDLEROUTERSWAPHOOKKEY is a free data retrieval call binding the contract method 0x2ddd29d1.
//
// Solidity: function PENDLE_ROUTER_SWAP_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) PENDLEROUTERSWAPHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.PENDLEROUTERSWAPHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// PENDLEROUTERSWAPHOOKKEY is a free data retrieval call binding the contract method 0x2ddd29d1.
//
// Solidity: function PENDLE_ROUTER_SWAP_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) PENDLEROUTERSWAPHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.PENDLEROUTERSWAPHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// PERMIT2 is a free data retrieval call binding the contract method 0x6afdd850.
//
// Solidity: function PERMIT2() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) PERMIT2(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "PERMIT2")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PERMIT2 is a free data retrieval call binding the contract method 0x6afdd850.
//
// Solidity: function PERMIT2() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) PERMIT2() (common.Address, error) {
	return _StargateAdapterTest.Contract.PERMIT2(&_StargateAdapterTest.CallOpts)
}

// PERMIT2 is a free data retrieval call binding the contract method 0x6afdd850.
//
// Solidity: function PERMIT2() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) PERMIT2() (common.Address, error) {
	return _StargateAdapterTest.Contract.PERMIT2(&_StargateAdapterTest.CallOpts)
}

// PERMITWITHPERMIT2HOOKKEY is a free data retrieval call binding the contract method 0x13fd203c.
//
// Solidity: function PERMIT_WITH_PERMIT2_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) PERMITWITHPERMIT2HOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "PERMIT_WITH_PERMIT2_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// PERMITWITHPERMIT2HOOKKEY is a free data retrieval call binding the contract method 0x13fd203c.
//
// Solidity: function PERMIT_WITH_PERMIT2_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) PERMITWITHPERMIT2HOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.PERMITWITHPERMIT2HOOKKEY(&_StargateAdapterTest.CallOpts)
}

// PERMITWITHPERMIT2HOOKKEY is a free data retrieval call binding the contract method 0x13fd203c.
//
// Solidity: function PERMIT_WITH_PERMIT2_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) PERMITWITHPERMIT2HOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.PERMITWITHPERMIT2HOOKKEY(&_StargateAdapterTest.CallOpts)
}

// REDEEM4626VAULTHOOKKEY is a free data retrieval call binding the contract method 0x6f6d75bb.
//
// Solidity: function REDEEM_4626_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) REDEEM4626VAULTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "REDEEM_4626_VAULT_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// REDEEM4626VAULTHOOKKEY is a free data retrieval call binding the contract method 0x6f6d75bb.
//
// Solidity: function REDEEM_4626_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) REDEEM4626VAULTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.REDEEM4626VAULTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// REDEEM4626VAULTHOOKKEY is a free data retrieval call binding the contract method 0x6f6d75bb.
//
// Solidity: function REDEEM_4626_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) REDEEM4626VAULTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.REDEEM4626VAULTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// REDEEM5115VAULTHOOKKEY is a free data retrieval call binding the contract method 0xdf4dcf31.
//
// Solidity: function REDEEM_5115_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) REDEEM5115VAULTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "REDEEM_5115_VAULT_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// REDEEM5115VAULTHOOKKEY is a free data retrieval call binding the contract method 0xdf4dcf31.
//
// Solidity: function REDEEM_5115_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) REDEEM5115VAULTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.REDEEM5115VAULTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// REDEEM5115VAULTHOOKKEY is a free data retrieval call binding the contract method 0xdf4dcf31.
//
// Solidity: function REDEEM_5115_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) REDEEM5115VAULTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.REDEEM5115VAULTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// REDEEM7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x8b5cc9f1.
//
// Solidity: function REDEEM_7540_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) REDEEM7540VAULTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "REDEEM_7540_VAULT_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// REDEEM7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x8b5cc9f1.
//
// Solidity: function REDEEM_7540_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) REDEEM7540VAULTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.REDEEM7540VAULTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// REDEEM7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x8b5cc9f1.
//
// Solidity: function REDEEM_7540_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) REDEEM7540VAULTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.REDEEM7540VAULTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// REQUESTDEPOSIT7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x67503ae4.
//
// Solidity: function REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) REQUESTDEPOSIT7540VAULTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// REQUESTDEPOSIT7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x67503ae4.
//
// Solidity: function REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) REQUESTDEPOSIT7540VAULTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.REQUESTDEPOSIT7540VAULTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// REQUESTDEPOSIT7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x67503ae4.
//
// Solidity: function REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) REQUESTDEPOSIT7540VAULTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.REQUESTDEPOSIT7540VAULTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// REQUESTREDEEM7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0xa1f9762e.
//
// Solidity: function REQUEST_REDEEM_7540_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) REQUESTREDEEM7540VAULTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "REQUEST_REDEEM_7540_VAULT_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// REQUESTREDEEM7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0xa1f9762e.
//
// Solidity: function REQUEST_REDEEM_7540_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) REQUESTREDEEM7540VAULTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.REQUESTREDEEM7540VAULTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// REQUESTREDEEM7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0xa1f9762e.
//
// Solidity: function REQUEST_REDEEM_7540_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) REQUESTREDEEM7540VAULTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.REQUESTREDEEM7540VAULTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// ROLESID is a free data retrieval call binding the contract method 0x6312d5d0.
//
// Solidity: function ROLES_ID() view returns(bytes32)
func (_StargateAdapterTest *StargateAdapterTestCaller) ROLESID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "ROLES_ID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ROLESID is a free data retrieval call binding the contract method 0x6312d5d0.
//
// Solidity: function ROLES_ID() view returns(bytes32)
func (_StargateAdapterTest *StargateAdapterTestSession) ROLESID() ([32]byte, error) {
	return _StargateAdapterTest.Contract.ROLESID(&_StargateAdapterTest.CallOpts)
}

// ROLESID is a free data retrieval call binding the contract method 0x6312d5d0.
//
// Solidity: function ROLES_ID() view returns(bytes32)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ROLESID() ([32]byte, error) {
	return _StargateAdapterTest.Contract.ROLESID(&_StargateAdapterTest.CallOpts)
}

// SAFEREGISTRYADDR is a free data retrieval call binding the contract method 0x7d452df6.
//
// Solidity: function SAFE_REGISTRY_ADDR() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) SAFEREGISTRYADDR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SAFE_REGISTRY_ADDR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SAFEREGISTRYADDR is a free data retrieval call binding the contract method 0x7d452df6.
//
// Solidity: function SAFE_REGISTRY_ADDR() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) SAFEREGISTRYADDR() (common.Address, error) {
	return _StargateAdapterTest.Contract.SAFEREGISTRYADDR(&_StargateAdapterTest.CallOpts)
}

// SAFEREGISTRYADDR is a free data retrieval call binding the contract method 0x7d452df6.
//
// Solidity: function SAFE_REGISTRY_ADDR() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SAFEREGISTRYADDR() (common.Address, error) {
	return _StargateAdapterTest.Contract.SAFEREGISTRYADDR(&_StargateAdapterTest.CallOpts)
}

// SMALL is a free data retrieval call binding the contract method 0xe8b7c8ad.
//
// Solidity: function SMALL() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCaller) SMALL(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SMALL")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// SMALL is a free data retrieval call binding the contract method 0xe8b7c8ad.
//
// Solidity: function SMALL() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestSession) SMALL() (*big.Int, error) {
	return _StargateAdapterTest.Contract.SMALL(&_StargateAdapterTest.CallOpts)
}

// SMALL is a free data retrieval call binding the contract method 0xe8b7c8ad.
//
// Solidity: function SMALL() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SMALL() (*big.Int, error) {
	return _StargateAdapterTest.Contract.SMALL(&_StargateAdapterTest.CallOpts)
}

// SOMELIERSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xc30c1920.
//
// Solidity: function SOMELIER_STAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SOMELIERSTAKEHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SOMELIER_STAKE_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SOMELIERSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xc30c1920.
//
// Solidity: function SOMELIER_STAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SOMELIERSTAKEHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SOMELIERSTAKEHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// SOMELIERSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xc30c1920.
//
// Solidity: function SOMELIER_STAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SOMELIERSTAKEHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SOMELIERSTAKEHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// SOMELIERUNBONDALLHOOKKEY is a free data retrieval call binding the contract method 0x27348f31.
//
// Solidity: function SOMELIER_UNBOND_ALL_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SOMELIERUNBONDALLHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SOMELIER_UNBOND_ALL_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SOMELIERUNBONDALLHOOKKEY is a free data retrieval call binding the contract method 0x27348f31.
//
// Solidity: function SOMELIER_UNBOND_ALL_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SOMELIERUNBONDALLHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SOMELIERUNBONDALLHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// SOMELIERUNBONDALLHOOKKEY is a free data retrieval call binding the contract method 0x27348f31.
//
// Solidity: function SOMELIER_UNBOND_ALL_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SOMELIERUNBONDALLHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SOMELIERUNBONDALLHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// SOMELIERUNBONDHOOKKEY is a free data retrieval call binding the contract method 0xb92b4b98.
//
// Solidity: function SOMELIER_UNBOND_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SOMELIERUNBONDHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SOMELIER_UNBOND_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SOMELIERUNBONDHOOKKEY is a free data retrieval call binding the contract method 0xb92b4b98.
//
// Solidity: function SOMELIER_UNBOND_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SOMELIERUNBONDHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SOMELIERUNBONDHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// SOMELIERUNBONDHOOKKEY is a free data retrieval call binding the contract method 0xb92b4b98.
//
// Solidity: function SOMELIER_UNBOND_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SOMELIERUNBONDHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SOMELIERUNBONDHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// SOMELIERUNSTAKEALLHOOKKEY is a free data retrieval call binding the contract method 0x9aa397e9.
//
// Solidity: function SOMELIER_UNSTAKE_ALL_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SOMELIERUNSTAKEALLHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SOMELIER_UNSTAKE_ALL_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SOMELIERUNSTAKEALLHOOKKEY is a free data retrieval call binding the contract method 0x9aa397e9.
//
// Solidity: function SOMELIER_UNSTAKE_ALL_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SOMELIERUNSTAKEALLHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SOMELIERUNSTAKEALLHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// SOMELIERUNSTAKEALLHOOKKEY is a free data retrieval call binding the contract method 0x9aa397e9.
//
// Solidity: function SOMELIER_UNSTAKE_ALL_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SOMELIERUNSTAKEALLHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SOMELIERUNSTAKEALLHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// SOMELIERUNSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xa6186e9a.
//
// Solidity: function SOMELIER_UNSTAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SOMELIERUNSTAKEHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SOMELIER_UNSTAKE_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SOMELIERUNSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xa6186e9a.
//
// Solidity: function SOMELIER_UNSTAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SOMELIERUNSTAKEHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SOMELIERUNSTAKEHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// SOMELIERUNSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xa6186e9a.
//
// Solidity: function SOMELIER_UNSTAKE_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SOMELIERUNSTAKEHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SOMELIERUNSTAKEHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// SPARKUSDCVAULTKEY is a free data retrieval call binding the contract method 0x9c86a52c.
//
// Solidity: function SPARK_USDC_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SPARKUSDCVAULTKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SPARK_USDC_VAULT_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SPARKUSDCVAULTKEY is a free data retrieval call binding the contract method 0x9c86a52c.
//
// Solidity: function SPARK_USDC_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SPARKUSDCVAULTKEY() (string, error) {
	return _StargateAdapterTest.Contract.SPARKUSDCVAULTKEY(&_StargateAdapterTest.CallOpts)
}

// SPARKUSDCVAULTKEY is a free data retrieval call binding the contract method 0x9c86a52c.
//
// Solidity: function SPARK_USDC_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SPARKUSDCVAULTKEY() (string, error) {
	return _StargateAdapterTest.Contract.SPARKUSDCVAULTKEY(&_StargateAdapterTest.CallOpts)
}

// SPECTRAEXCHANGEDEPOSITHOOKKEY is a free data retrieval call binding the contract method 0x5a45abc1.
//
// Solidity: function SPECTRA_EXCHANGE_DEPOSIT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SPECTRAEXCHANGEDEPOSITHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SPECTRA_EXCHANGE_DEPOSIT_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SPECTRAEXCHANGEDEPOSITHOOKKEY is a free data retrieval call binding the contract method 0x5a45abc1.
//
// Solidity: function SPECTRA_EXCHANGE_DEPOSIT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SPECTRAEXCHANGEDEPOSITHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SPECTRAEXCHANGEDEPOSITHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// SPECTRAEXCHANGEDEPOSITHOOKKEY is a free data retrieval call binding the contract method 0x5a45abc1.
//
// Solidity: function SPECTRA_EXCHANGE_DEPOSIT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SPECTRAEXCHANGEDEPOSITHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SPECTRAEXCHANGEDEPOSITHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// SPECTRAEXCHANGEREDEEMHOOKKEY is a free data retrieval call binding the contract method 0x8732a9d1.
//
// Solidity: function SPECTRA_EXCHANGE_REDEEM_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SPECTRAEXCHANGEREDEEMHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SPECTRA_EXCHANGE_REDEEM_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SPECTRAEXCHANGEREDEEMHOOKKEY is a free data retrieval call binding the contract method 0x8732a9d1.
//
// Solidity: function SPECTRA_EXCHANGE_REDEEM_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SPECTRAEXCHANGEREDEEMHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SPECTRAEXCHANGEREDEEMHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// SPECTRAEXCHANGEREDEEMHOOKKEY is a free data retrieval call binding the contract method 0x8732a9d1.
//
// Solidity: function SPECTRA_EXCHANGE_REDEEM_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SPECTRAEXCHANGEREDEEMHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SPECTRAEXCHANGEREDEEMHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// STAKINGYIELDSOURCEORACLEKEY is a free data retrieval call binding the contract method 0xdbf8e232.
//
// Solidity: function STAKING_YIELD_SOURCE_ORACLE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) STAKINGYIELDSOURCEORACLEKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "STAKING_YIELD_SOURCE_ORACLE_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// STAKINGYIELDSOURCEORACLEKEY is a free data retrieval call binding the contract method 0xdbf8e232.
//
// Solidity: function STAKING_YIELD_SOURCE_ORACLE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) STAKINGYIELDSOURCEORACLEKEY() (string, error) {
	return _StargateAdapterTest.Contract.STAKINGYIELDSOURCEORACLEKEY(&_StargateAdapterTest.CallOpts)
}

// STAKINGYIELDSOURCEORACLEKEY is a free data retrieval call binding the contract method 0xdbf8e232.
//
// Solidity: function STAKING_YIELD_SOURCE_ORACLE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) STAKINGYIELDSOURCEORACLEKEY() (string, error) {
	return _StargateAdapterTest.Contract.STAKINGYIELDSOURCEORACLEKEY(&_StargateAdapterTest.CallOpts)
}

// STRATEGISTKEY is a free data retrieval call binding the contract method 0x7a67e8c1.
//
// Solidity: function STRATEGIST_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCaller) STRATEGISTKEY(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "STRATEGIST_KEY")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// STRATEGISTKEY is a free data retrieval call binding the contract method 0x7a67e8c1.
//
// Solidity: function STRATEGIST_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestSession) STRATEGISTKEY() (*big.Int, error) {
	return _StargateAdapterTest.Contract.STRATEGISTKEY(&_StargateAdapterTest.CallOpts)
}

// STRATEGISTKEY is a free data retrieval call binding the contract method 0x7a67e8c1.
//
// Solidity: function STRATEGIST_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) STRATEGISTKEY() (*big.Int, error) {
	return _StargateAdapterTest.Contract.STRATEGISTKEY(&_StargateAdapterTest.CallOpts)
}

// SUPER7702SENDERCREATORKEY is a free data retrieval call binding the contract method 0xf5c1ccf6.
//
// Solidity: function SUPER_7702_SENDER_CREATOR_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SUPER7702SENDERCREATORKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SUPER_7702_SENDER_CREATOR_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SUPER7702SENDERCREATORKEY is a free data retrieval call binding the contract method 0xf5c1ccf6.
//
// Solidity: function SUPER_7702_SENDER_CREATOR_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SUPER7702SENDERCREATORKEY() (string, error) {
	return _StargateAdapterTest.Contract.SUPER7702SENDERCREATORKEY(&_StargateAdapterTest.CallOpts)
}

// SUPER7702SENDERCREATORKEY is a free data retrieval call binding the contract method 0xf5c1ccf6.
//
// Solidity: function SUPER_7702_SENDER_CREATOR_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SUPER7702SENDERCREATORKEY() (string, error) {
	return _StargateAdapterTest.Contract.SUPER7702SENDERCREATORKEY(&_StargateAdapterTest.CallOpts)
}

// SUPERBUNDLER is a free data retrieval call binding the contract method 0x4ddbd878.
//
// Solidity: function SUPER_BUNDLER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) SUPERBUNDLER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SUPER_BUNDLER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERBUNDLER is a free data retrieval call binding the contract method 0x4ddbd878.
//
// Solidity: function SUPER_BUNDLER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) SUPERBUNDLER() (common.Address, error) {
	return _StargateAdapterTest.Contract.SUPERBUNDLER(&_StargateAdapterTest.CallOpts)
}

// SUPERBUNDLER is a free data retrieval call binding the contract method 0x4ddbd878.
//
// Solidity: function SUPER_BUNDLER() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SUPERBUNDLER() (common.Address, error) {
	return _StargateAdapterTest.Contract.SUPERBUNDLER(&_StargateAdapterTest.CallOpts)
}

// SUPERBUNDLERKEY is a free data retrieval call binding the contract method 0x5e2592df.
//
// Solidity: function SUPER_BUNDLER_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCaller) SUPERBUNDLERKEY(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SUPER_BUNDLER_KEY")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// SUPERBUNDLERKEY is a free data retrieval call binding the contract method 0x5e2592df.
//
// Solidity: function SUPER_BUNDLER_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestSession) SUPERBUNDLERKEY() (*big.Int, error) {
	return _StargateAdapterTest.Contract.SUPERBUNDLERKEY(&_StargateAdapterTest.CallOpts)
}

// SUPERBUNDLERKEY is a free data retrieval call binding the contract method 0x5e2592df.
//
// Solidity: function SUPER_BUNDLER_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SUPERBUNDLERKEY() (*big.Int, error) {
	return _StargateAdapterTest.Contract.SUPERBUNDLERKEY(&_StargateAdapterTest.CallOpts)
}

// SUPERCOLLECTIVEVAULTKEY is a free data retrieval call binding the contract method 0xb1e80bfc.
//
// Solidity: function SUPER_COLLECTIVE_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SUPERCOLLECTIVEVAULTKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SUPER_COLLECTIVE_VAULT_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SUPERCOLLECTIVEVAULTKEY is a free data retrieval call binding the contract method 0xb1e80bfc.
//
// Solidity: function SUPER_COLLECTIVE_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SUPERCOLLECTIVEVAULTKEY() (string, error) {
	return _StargateAdapterTest.Contract.SUPERCOLLECTIVEVAULTKEY(&_StargateAdapterTest.CallOpts)
}

// SUPERCOLLECTIVEVAULTKEY is a free data retrieval call binding the contract method 0xb1e80bfc.
//
// Solidity: function SUPER_COLLECTIVE_VAULT_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SUPERCOLLECTIVEVAULTKEY() (string, error) {
	return _StargateAdapterTest.Contract.SUPERCOLLECTIVEVAULTKEY(&_StargateAdapterTest.CallOpts)
}

// SUPERDESTINATIONEXECUTORKEY is a free data retrieval call binding the contract method 0xf44c853a.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SUPERDESTINATIONEXECUTORKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SUPER_DESTINATION_EXECUTOR_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SUPERDESTINATIONEXECUTORKEY is a free data retrieval call binding the contract method 0xf44c853a.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SUPERDESTINATIONEXECUTORKEY() (string, error) {
	return _StargateAdapterTest.Contract.SUPERDESTINATIONEXECUTORKEY(&_StargateAdapterTest.CallOpts)
}

// SUPERDESTINATIONEXECUTORKEY is a free data retrieval call binding the contract method 0xf44c853a.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SUPERDESTINATIONEXECUTORKEY() (string, error) {
	return _StargateAdapterTest.Contract.SUPERDESTINATIONEXECUTORKEY(&_StargateAdapterTest.CallOpts)
}

// SUPERDESTINATIONVALIDATORKEY is a free data retrieval call binding the contract method 0x8f66c5f1.
//
// Solidity: function SUPER_DESTINATION_VALIDATOR_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SUPERDESTINATIONVALIDATORKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SUPER_DESTINATION_VALIDATOR_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SUPERDESTINATIONVALIDATORKEY is a free data retrieval call binding the contract method 0x8f66c5f1.
//
// Solidity: function SUPER_DESTINATION_VALIDATOR_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SUPERDESTINATIONVALIDATORKEY() (string, error) {
	return _StargateAdapterTest.Contract.SUPERDESTINATIONVALIDATORKEY(&_StargateAdapterTest.CallOpts)
}

// SUPERDESTINATIONVALIDATORKEY is a free data retrieval call binding the contract method 0x8f66c5f1.
//
// Solidity: function SUPER_DESTINATION_VALIDATOR_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SUPERDESTINATIONVALIDATORKEY() (string, error) {
	return _StargateAdapterTest.Contract.SUPERDESTINATIONVALIDATORKEY(&_StargateAdapterTest.CallOpts)
}

// SUPEREXECUTORKEY is a free data retrieval call binding the contract method 0x6b6df5da.
//
// Solidity: function SUPER_EXECUTOR_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SUPEREXECUTORKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SUPER_EXECUTOR_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SUPEREXECUTORKEY is a free data retrieval call binding the contract method 0x6b6df5da.
//
// Solidity: function SUPER_EXECUTOR_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SUPEREXECUTORKEY() (string, error) {
	return _StargateAdapterTest.Contract.SUPEREXECUTORKEY(&_StargateAdapterTest.CallOpts)
}

// SUPEREXECUTORKEY is a free data retrieval call binding the contract method 0x6b6df5da.
//
// Solidity: function SUPER_EXECUTOR_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SUPEREXECUTORKEY() (string, error) {
	return _StargateAdapterTest.Contract.SUPEREXECUTORKEY(&_StargateAdapterTest.CallOpts)
}

// SUPERGASTANKID is a free data retrieval call binding the contract method 0x32740077.
//
// Solidity: function SUPER_GAS_TANK_ID() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SUPERGASTANKID(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SUPER_GAS_TANK_ID")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SUPERGASTANKID is a free data retrieval call binding the contract method 0x32740077.
//
// Solidity: function SUPER_GAS_TANK_ID() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SUPERGASTANKID() (string, error) {
	return _StargateAdapterTest.Contract.SUPERGASTANKID(&_StargateAdapterTest.CallOpts)
}

// SUPERGASTANKID is a free data retrieval call binding the contract method 0x32740077.
//
// Solidity: function SUPER_GAS_TANK_ID() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SUPERGASTANKID() (string, error) {
	return _StargateAdapterTest.Contract.SUPERGASTANKID(&_StargateAdapterTest.CallOpts)
}

// SUPERLEDGERCONFIGURATIONKEY is a free data retrieval call binding the contract method 0x22ab9837.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SUPERLEDGERCONFIGURATIONKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SUPER_LEDGER_CONFIGURATION_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SUPERLEDGERCONFIGURATIONKEY is a free data retrieval call binding the contract method 0x22ab9837.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SUPERLEDGERCONFIGURATIONKEY() (string, error) {
	return _StargateAdapterTest.Contract.SUPERLEDGERCONFIGURATIONKEY(&_StargateAdapterTest.CallOpts)
}

// SUPERLEDGERCONFIGURATIONKEY is a free data retrieval call binding the contract method 0x22ab9837.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SUPERLEDGERCONFIGURATIONKEY() (string, error) {
	return _StargateAdapterTest.Contract.SUPERLEDGERCONFIGURATIONKEY(&_StargateAdapterTest.CallOpts)
}

// SUPERLEDGERKEY is a free data retrieval call binding the contract method 0xb997902d.
//
// Solidity: function SUPER_LEDGER_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SUPERLEDGERKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SUPER_LEDGER_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SUPERLEDGERKEY is a free data retrieval call binding the contract method 0xb997902d.
//
// Solidity: function SUPER_LEDGER_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SUPERLEDGERKEY() (string, error) {
	return _StargateAdapterTest.Contract.SUPERLEDGERKEY(&_StargateAdapterTest.CallOpts)
}

// SUPERLEDGERKEY is a free data retrieval call binding the contract method 0xb997902d.
//
// Solidity: function SUPER_LEDGER_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SUPERLEDGERKEY() (string, error) {
	return _StargateAdapterTest.Contract.SUPERLEDGERKEY(&_StargateAdapterTest.CallOpts)
}

// SUPERMERKLEVALIDATORKEY is a free data retrieval call binding the contract method 0x77aa7a91.
//
// Solidity: function SUPER_MERKLE_VALIDATOR_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SUPERMERKLEVALIDATORKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SUPER_MERKLE_VALIDATOR_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SUPERMERKLEVALIDATORKEY is a free data retrieval call binding the contract method 0x77aa7a91.
//
// Solidity: function SUPER_MERKLE_VALIDATOR_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SUPERMERKLEVALIDATORKEY() (string, error) {
	return _StargateAdapterTest.Contract.SUPERMERKLEVALIDATORKEY(&_StargateAdapterTest.CallOpts)
}

// SUPERMERKLEVALIDATORKEY is a free data retrieval call binding the contract method 0x77aa7a91.
//
// Solidity: function SUPER_MERKLE_VALIDATOR_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SUPERMERKLEVALIDATORKEY() (string, error) {
	return _StargateAdapterTest.Contract.SUPERMERKLEVALIDATORKEY(&_StargateAdapterTest.CallOpts)
}

// SUPERNATIVEPAYMASTERKEY is a free data retrieval call binding the contract method 0x44328cd5.
//
// Solidity: function SUPER_NATIVE_PAYMASTER_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SUPERNATIVEPAYMASTERKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SUPER_NATIVE_PAYMASTER_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SUPERNATIVEPAYMASTERKEY is a free data retrieval call binding the contract method 0x44328cd5.
//
// Solidity: function SUPER_NATIVE_PAYMASTER_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SUPERNATIVEPAYMASTERKEY() (string, error) {
	return _StargateAdapterTest.Contract.SUPERNATIVEPAYMASTERKEY(&_StargateAdapterTest.CallOpts)
}

// SUPERNATIVEPAYMASTERKEY is a free data retrieval call binding the contract method 0x44328cd5.
//
// Solidity: function SUPER_NATIVE_PAYMASTER_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SUPERNATIVEPAYMASTERKEY() (string, error) {
	return _StargateAdapterTest.Contract.SUPERNATIVEPAYMASTERKEY(&_StargateAdapterTest.CallOpts)
}

// SUPERSENDERCREATORKEY is a free data retrieval call binding the contract method 0x55cb93ba.
//
// Solidity: function SUPER_SENDER_CREATOR_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SUPERSENDERCREATORKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SUPER_SENDER_CREATOR_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SUPERSENDERCREATORKEY is a free data retrieval call binding the contract method 0x55cb93ba.
//
// Solidity: function SUPER_SENDER_CREATOR_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SUPERSENDERCREATORKEY() (string, error) {
	return _StargateAdapterTest.Contract.SUPERSENDERCREATORKEY(&_StargateAdapterTest.CallOpts)
}

// SUPERSENDERCREATORKEY is a free data retrieval call binding the contract method 0x55cb93ba.
//
// Solidity: function SUPER_SENDER_CREATOR_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SUPERSENDERCREATORKEY() (string, error) {
	return _StargateAdapterTest.Contract.SUPERSENDERCREATORKEY(&_StargateAdapterTest.CallOpts)
}

// SUSDEKEY is a free data retrieval call binding the contract method 0x8cf396ee.
//
// Solidity: function SUSDE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SUSDEKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SUSDE_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SUSDEKEY is a free data retrieval call binding the contract method 0x8cf396ee.
//
// Solidity: function SUSDE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SUSDEKEY() (string, error) {
	return _StargateAdapterTest.Contract.SUSDEKEY(&_StargateAdapterTest.CallOpts)
}

// SUSDEKEY is a free data retrieval call binding the contract method 0x8cf396ee.
//
// Solidity: function SUSDE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SUSDEKEY() (string, error) {
	return _StargateAdapterTest.Contract.SUSDEKEY(&_StargateAdapterTest.CallOpts)
}

// SWAP1INCHHOOKKEY is a free data retrieval call binding the contract method 0xddf2a077.
//
// Solidity: function SWAP_1INCH_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SWAP1INCHHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SWAP_1INCH_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SWAP1INCHHOOKKEY is a free data retrieval call binding the contract method 0xddf2a077.
//
// Solidity: function SWAP_1INCH_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SWAP1INCHHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SWAP1INCHHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// SWAP1INCHHOOKKEY is a free data retrieval call binding the contract method 0xddf2a077.
//
// Solidity: function SWAP_1INCH_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SWAP1INCHHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SWAP1INCHHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// SWAPALGEBRAINTEGRALHOOKKEY is a free data retrieval call binding the contract method 0x262ba544.
//
// Solidity: function SWAP_ALGEBRA_INTEGRAL_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SWAPALGEBRAINTEGRALHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SWAP_ALGEBRA_INTEGRAL_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SWAPALGEBRAINTEGRALHOOKKEY is a free data retrieval call binding the contract method 0x262ba544.
//
// Solidity: function SWAP_ALGEBRA_INTEGRAL_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SWAPALGEBRAINTEGRALHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SWAPALGEBRAINTEGRALHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// SWAPALGEBRAINTEGRALHOOKKEY is a free data retrieval call binding the contract method 0x262ba544.
//
// Solidity: function SWAP_ALGEBRA_INTEGRAL_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SWAPALGEBRAINTEGRALHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SWAPALGEBRAINTEGRALHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// SWAPODOSV2HOOKKEY is a free data retrieval call binding the contract method 0x2625b00e.
//
// Solidity: function SWAP_ODOSV2_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SWAPODOSV2HOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SWAP_ODOSV2_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SWAPODOSV2HOOKKEY is a free data retrieval call binding the contract method 0x2625b00e.
//
// Solidity: function SWAP_ODOSV2_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SWAPODOSV2HOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SWAPODOSV2HOOKKEY(&_StargateAdapterTest.CallOpts)
}

// SWAPODOSV2HOOKKEY is a free data retrieval call binding the contract method 0x2625b00e.
//
// Solidity: function SWAP_ODOSV2_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SWAPODOSV2HOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SWAPODOSV2HOOKKEY(&_StargateAdapterTest.CallOpts)
}

// SWAPOPENOCEANHOOKKEY is a free data retrieval call binding the contract method 0x4359f387.
//
// Solidity: function SWAP_OPENOCEAN_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SWAPOPENOCEANHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SWAP_OPENOCEAN_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SWAPOPENOCEANHOOKKEY is a free data retrieval call binding the contract method 0x4359f387.
//
// Solidity: function SWAP_OPENOCEAN_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SWAPOPENOCEANHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SWAPOPENOCEANHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// SWAPOPENOCEANHOOKKEY is a free data retrieval call binding the contract method 0x4359f387.
//
// Solidity: function SWAP_OPENOCEAN_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SWAPOPENOCEANHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SWAPOPENOCEANHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// SWAPUNISWAPV3HOOKKEY is a free data retrieval call binding the contract method 0x5278fef8.
//
// Solidity: function SWAP_UNISWAP_V3_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SWAPUNISWAPV3HOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SWAP_UNISWAP_V3_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SWAPUNISWAPV3HOOKKEY is a free data retrieval call binding the contract method 0x5278fef8.
//
// Solidity: function SWAP_UNISWAP_V3_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SWAPUNISWAPV3HOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SWAPUNISWAPV3HOOKKEY(&_StargateAdapterTest.CallOpts)
}

// SWAPUNISWAPV3HOOKKEY is a free data retrieval call binding the contract method 0x5278fef8.
//
// Solidity: function SWAP_UNISWAP_V3_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SWAPUNISWAPV3HOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SWAPUNISWAPV3HOOKKEY(&_StargateAdapterTest.CallOpts)
}

// SWAPUNISWAPV4HOOKKEY is a free data retrieval call binding the contract method 0xda562b89.
//
// Solidity: function SWAP_UNISWAP_V4_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SWAPUNISWAPV4HOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SWAP_UNISWAP_V4_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SWAPUNISWAPV4HOOKKEY is a free data retrieval call binding the contract method 0xda562b89.
//
// Solidity: function SWAP_UNISWAP_V4_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SWAPUNISWAPV4HOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SWAPUNISWAPV4HOOKKEY(&_StargateAdapterTest.CallOpts)
}

// SWAPUNISWAPV4HOOKKEY is a free data retrieval call binding the contract method 0xda562b89.
//
// Solidity: function SWAP_UNISWAP_V4_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SWAPUNISWAPV4HOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SWAPUNISWAPV4HOOKKEY(&_StargateAdapterTest.CallOpts)
}

// SWAPUNISWAPV4MULTIHOPHOOKKEY is a free data retrieval call binding the contract method 0x4059361b.
//
// Solidity: function SWAP_UNISWAP_V4_MULTI_HOP_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) SWAPUNISWAPV4MULTIHOPHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "SWAP_UNISWAP_V4_MULTI_HOP_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SWAPUNISWAPV4MULTIHOPHOOKKEY is a free data retrieval call binding the contract method 0x4059361b.
//
// Solidity: function SWAP_UNISWAP_V4_MULTI_HOP_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) SWAPUNISWAPV4MULTIHOPHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SWAPUNISWAPV4MULTIHOPHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// SWAPUNISWAPV4MULTIHOPHOOKKEY is a free data retrieval call binding the contract method 0x4059361b.
//
// Solidity: function SWAP_UNISWAP_V4_MULTI_HOP_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) SWAPUNISWAPV4MULTIHOPHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.SWAPUNISWAPV4MULTIHOPHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// TRANSFERERC20HOOKKEY is a free data retrieval call binding the contract method 0x1800af24.
//
// Solidity: function TRANSFER_ERC20_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) TRANSFERERC20HOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "TRANSFER_ERC20_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// TRANSFERERC20HOOKKEY is a free data retrieval call binding the contract method 0x1800af24.
//
// Solidity: function TRANSFER_ERC20_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) TRANSFERERC20HOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.TRANSFERERC20HOOKKEY(&_StargateAdapterTest.CallOpts)
}

// TRANSFERERC20HOOKKEY is a free data retrieval call binding the contract method 0x1800af24.
//
// Solidity: function TRANSFER_ERC20_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) TRANSFERERC20HOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.TRANSFERERC20HOOKKEY(&_StargateAdapterTest.CallOpts)
}

// TREASURY is a free data retrieval call binding the contract method 0x2d2c5565.
//
// Solidity: function TREASURY() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) TREASURY(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "TREASURY")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// TREASURY is a free data retrieval call binding the contract method 0x2d2c5565.
//
// Solidity: function TREASURY() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) TREASURY() (common.Address, error) {
	return _StargateAdapterTest.Contract.TREASURY(&_StargateAdapterTest.CallOpts)
}

// TREASURY is a free data retrieval call binding the contract method 0x2d2c5565.
//
// Solidity: function TREASURY() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) TREASURY() (common.Address, error) {
	return _StargateAdapterTest.Contract.TREASURY(&_StargateAdapterTest.CallOpts)
}

// TREASURYKEY is a free data retrieval call binding the contract method 0xfa3c6254.
//
// Solidity: function TREASURY_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCaller) TREASURYKEY(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "TREASURY_KEY")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// TREASURYKEY is a free data retrieval call binding the contract method 0xfa3c6254.
//
// Solidity: function TREASURY_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestSession) TREASURYKEY() (*big.Int, error) {
	return _StargateAdapterTest.Contract.TREASURYKEY(&_StargateAdapterTest.CallOpts)
}

// TREASURYKEY is a free data retrieval call binding the contract method 0xfa3c6254.
//
// Solidity: function TREASURY_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) TREASURYKEY() (*big.Int, error) {
	return _StargateAdapterTest.Contract.TREASURYKEY(&_StargateAdapterTest.CallOpts)
}

// USDCEKEY is a free data retrieval call binding the contract method 0x5ff2fe61.
//
// Solidity: function USDCE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) USDCEKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "USDCE_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// USDCEKEY is a free data retrieval call binding the contract method 0x5ff2fe61.
//
// Solidity: function USDCE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) USDCEKEY() (string, error) {
	return _StargateAdapterTest.Contract.USDCEKEY(&_StargateAdapterTest.CallOpts)
}

// USDCEKEY is a free data retrieval call binding the contract method 0x5ff2fe61.
//
// Solidity: function USDCE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) USDCEKEY() (string, error) {
	return _StargateAdapterTest.Contract.USDCEKEY(&_StargateAdapterTest.CallOpts)
}

// USDCKEY is a free data retrieval call binding the contract method 0x805485b8.
//
// Solidity: function USDC_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) USDCKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "USDC_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// USDCKEY is a free data retrieval call binding the contract method 0x805485b8.
//
// Solidity: function USDC_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) USDCKEY() (string, error) {
	return _StargateAdapterTest.Contract.USDCKEY(&_StargateAdapterTest.CallOpts)
}

// USDCKEY is a free data retrieval call binding the contract method 0x805485b8.
//
// Solidity: function USDC_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) USDCKEY() (string, error) {
	return _StargateAdapterTest.Contract.USDCKEY(&_StargateAdapterTest.CallOpts)
}

// USDEKEY is a free data retrieval call binding the contract method 0x49201c20.
//
// Solidity: function USDE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) USDEKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "USDE_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// USDEKEY is a free data retrieval call binding the contract method 0x49201c20.
//
// Solidity: function USDE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) USDEKEY() (string, error) {
	return _StargateAdapterTest.Contract.USDEKEY(&_StargateAdapterTest.CallOpts)
}

// USDEKEY is a free data retrieval call binding the contract method 0x49201c20.
//
// Solidity: function USDE_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) USDEKEY() (string, error) {
	return _StargateAdapterTest.Contract.USDEKEY(&_StargateAdapterTest.CallOpts)
}

// USER1KEY is a free data retrieval call binding the contract method 0xe9d2f1e3.
//
// Solidity: function USER1_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCaller) USER1KEY(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "USER1_KEY")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// USER1KEY is a free data retrieval call binding the contract method 0xe9d2f1e3.
//
// Solidity: function USER1_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestSession) USER1KEY() (*big.Int, error) {
	return _StargateAdapterTest.Contract.USER1KEY(&_StargateAdapterTest.CallOpts)
}

// USER1KEY is a free data retrieval call binding the contract method 0xe9d2f1e3.
//
// Solidity: function USER1_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) USER1KEY() (*big.Int, error) {
	return _StargateAdapterTest.Contract.USER1KEY(&_StargateAdapterTest.CallOpts)
}

// USER2KEY is a free data retrieval call binding the contract method 0x60ae3e2e.
//
// Solidity: function USER2_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCaller) USER2KEY(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "USER2_KEY")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// USER2KEY is a free data retrieval call binding the contract method 0x60ae3e2e.
//
// Solidity: function USER2_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestSession) USER2KEY() (*big.Int, error) {
	return _StargateAdapterTest.Contract.USER2KEY(&_StargateAdapterTest.CallOpts)
}

// USER2KEY is a free data retrieval call binding the contract method 0x60ae3e2e.
//
// Solidity: function USER2_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) USER2KEY() (*big.Int, error) {
	return _StargateAdapterTest.Contract.USER2KEY(&_StargateAdapterTest.CallOpts)
}

// VALIDATORKEY is a free data retrieval call binding the contract method 0x91be41d5.
//
// Solidity: function VALIDATOR_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCaller) VALIDATORKEY(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "VALIDATOR_KEY")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// VALIDATORKEY is a free data retrieval call binding the contract method 0x91be41d5.
//
// Solidity: function VALIDATOR_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestSession) VALIDATORKEY() (*big.Int, error) {
	return _StargateAdapterTest.Contract.VALIDATORKEY(&_StargateAdapterTest.CallOpts)
}

// VALIDATORKEY is a free data retrieval call binding the contract method 0x91be41d5.
//
// Solidity: function VALIDATOR_KEY() view returns(uint256)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) VALIDATORKEY() (*big.Int, error) {
	return _StargateAdapterTest.Contract.VALIDATORKEY(&_StargateAdapterTest.CallOpts)
}

// WETHKEY is a free data retrieval call binding the contract method 0x513941b9.
//
// Solidity: function WETH_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) WETHKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "WETH_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// WETHKEY is a free data retrieval call binding the contract method 0x513941b9.
//
// Solidity: function WETH_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) WETHKEY() (string, error) {
	return _StargateAdapterTest.Contract.WETHKEY(&_StargateAdapterTest.CallOpts)
}

// WETHKEY is a free data retrieval call binding the contract method 0x513941b9.
//
// Solidity: function WETH_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) WETHKEY() (string, error) {
	return _StargateAdapterTest.Contract.WETHKEY(&_StargateAdapterTest.CallOpts)
}

// WITHDRAW7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x467019e9.
//
// Solidity: function WITHDRAW_7540_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) WITHDRAW7540VAULTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "WITHDRAW_7540_VAULT_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// WITHDRAW7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x467019e9.
//
// Solidity: function WITHDRAW_7540_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) WITHDRAW7540VAULTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.WITHDRAW7540VAULTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// WITHDRAW7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x467019e9.
//
// Solidity: function WITHDRAW_7540_VAULT_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) WITHDRAW7540VAULTHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.WITHDRAW7540VAULTHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// WSTETHKEY is a free data retrieval call binding the contract method 0x14d8edbe.
//
// Solidity: function WST_ETH_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) WSTETHKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "WST_ETH_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// WSTETHKEY is a free data retrieval call binding the contract method 0x14d8edbe.
//
// Solidity: function WST_ETH_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) WSTETHKEY() (string, error) {
	return _StargateAdapterTest.Contract.WSTETHKEY(&_StargateAdapterTest.CallOpts)
}

// WSTETHKEY is a free data retrieval call binding the contract method 0x14d8edbe.
//
// Solidity: function WST_ETH_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) WSTETHKEY() (string, error) {
	return _StargateAdapterTest.Contract.WSTETHKEY(&_StargateAdapterTest.CallOpts)
}

// YEARNCLAIMALLREWARDSHOOKKEY is a free data retrieval call binding the contract method 0xec850ab2.
//
// Solidity: function YEARN_CLAIM_ALL_REWARDS_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) YEARNCLAIMALLREWARDSHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "YEARN_CLAIM_ALL_REWARDS_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// YEARNCLAIMALLREWARDSHOOKKEY is a free data retrieval call binding the contract method 0xec850ab2.
//
// Solidity: function YEARN_CLAIM_ALL_REWARDS_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) YEARNCLAIMALLREWARDSHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.YEARNCLAIMALLREWARDSHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// YEARNCLAIMALLREWARDSHOOKKEY is a free data retrieval call binding the contract method 0xec850ab2.
//
// Solidity: function YEARN_CLAIM_ALL_REWARDS_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) YEARNCLAIMALLREWARDSHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.YEARNCLAIMALLREWARDSHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// YEARNCLAIMONEREWARDHOOKKEY is a free data retrieval call binding the contract method 0x0e672aa1.
//
// Solidity: function YEARN_CLAIM_ONE_REWARD_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCaller) YEARNCLAIMONEREWARDHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "YEARN_CLAIM_ONE_REWARD_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// YEARNCLAIMONEREWARDHOOKKEY is a free data retrieval call binding the contract method 0x0e672aa1.
//
// Solidity: function YEARN_CLAIM_ONE_REWARD_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestSession) YEARNCLAIMONEREWARDHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.YEARNCLAIMONEREWARDHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// YEARNCLAIMONEREWARDHOOKKEY is a free data retrieval call binding the contract method 0x0e672aa1.
//
// Solidity: function YEARN_CLAIM_ONE_REWARD_HOOK_KEY() view returns(string)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) YEARNCLAIMONEREWARDHOOKKEY() (string, error) {
	return _StargateAdapterTest.Contract.YEARNCLAIMONEREWARDHOOKKEY(&_StargateAdapterTest.CallOpts)
}

// EnvOr is a free data retrieval call binding the contract method 0x4777f3cf.
//
// Solidity: function envOr(string name, bool defaultValue) view returns(bool value)
func (_StargateAdapterTest *StargateAdapterTestCaller) EnvOr(opts *bind.CallOpts, name string, defaultValue bool) (bool, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "envOr", name, defaultValue)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// EnvOr is a free data retrieval call binding the contract method 0x4777f3cf.
//
// Solidity: function envOr(string name, bool defaultValue) view returns(bool value)
func (_StargateAdapterTest *StargateAdapterTestSession) EnvOr(name string, defaultValue bool) (bool, error) {
	return _StargateAdapterTest.Contract.EnvOr(&_StargateAdapterTest.CallOpts, name, defaultValue)
}

// EnvOr is a free data retrieval call binding the contract method 0x4777f3cf.
//
// Solidity: function envOr(string name, bool defaultValue) view returns(bool value)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) EnvOr(name string, defaultValue bool) (bool, error) {
	return _StargateAdapterTest.Contract.EnvOr(&_StargateAdapterTest.CallOpts, name, defaultValue)
}

// EnvOr0 is a free data retrieval call binding the contract method 0xd145736c.
//
// Solidity: function envOr(string name, string defaultValue) view returns(string value)
func (_StargateAdapterTest *StargateAdapterTestCaller) EnvOr0(opts *bind.CallOpts, name string, defaultValue string) (string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "envOr0", name, defaultValue)

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// EnvOr0 is a free data retrieval call binding the contract method 0xd145736c.
//
// Solidity: function envOr(string name, string defaultValue) view returns(string value)
func (_StargateAdapterTest *StargateAdapterTestSession) EnvOr0(name string, defaultValue string) (string, error) {
	return _StargateAdapterTest.Contract.EnvOr0(&_StargateAdapterTest.CallOpts, name, defaultValue)
}

// EnvOr0 is a free data retrieval call binding the contract method 0xd145736c.
//
// Solidity: function envOr(string name, string defaultValue) view returns(string value)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) EnvOr0(name string, defaultValue string) (string, error) {
	return _StargateAdapterTest.Contract.EnvOr0(&_StargateAdapterTest.CallOpts, name, defaultValue)
}

// ExcludeArtifacts is a free data retrieval call binding the contract method 0xb5508aa9.
//
// Solidity: function excludeArtifacts() view returns(string[] excludedArtifacts_)
func (_StargateAdapterTest *StargateAdapterTestCaller) ExcludeArtifacts(opts *bind.CallOpts) ([]string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "excludeArtifacts")

	if err != nil {
		return *new([]string), err
	}

	out0 := *abi.ConvertType(out[0], new([]string)).(*[]string)

	return out0, err

}

// ExcludeArtifacts is a free data retrieval call binding the contract method 0xb5508aa9.
//
// Solidity: function excludeArtifacts() view returns(string[] excludedArtifacts_)
func (_StargateAdapterTest *StargateAdapterTestSession) ExcludeArtifacts() ([]string, error) {
	return _StargateAdapterTest.Contract.ExcludeArtifacts(&_StargateAdapterTest.CallOpts)
}

// ExcludeArtifacts is a free data retrieval call binding the contract method 0xb5508aa9.
//
// Solidity: function excludeArtifacts() view returns(string[] excludedArtifacts_)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ExcludeArtifacts() ([]string, error) {
	return _StargateAdapterTest.Contract.ExcludeArtifacts(&_StargateAdapterTest.CallOpts)
}

// ExcludeContracts is a free data retrieval call binding the contract method 0xe20c9f71.
//
// Solidity: function excludeContracts() view returns(address[] excludedContracts_)
func (_StargateAdapterTest *StargateAdapterTestCaller) ExcludeContracts(opts *bind.CallOpts) ([]common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "excludeContracts")

	if err != nil {
		return *new([]common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new([]common.Address)).(*[]common.Address)

	return out0, err

}

// ExcludeContracts is a free data retrieval call binding the contract method 0xe20c9f71.
//
// Solidity: function excludeContracts() view returns(address[] excludedContracts_)
func (_StargateAdapterTest *StargateAdapterTestSession) ExcludeContracts() ([]common.Address, error) {
	return _StargateAdapterTest.Contract.ExcludeContracts(&_StargateAdapterTest.CallOpts)
}

// ExcludeContracts is a free data retrieval call binding the contract method 0xe20c9f71.
//
// Solidity: function excludeContracts() view returns(address[] excludedContracts_)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ExcludeContracts() ([]common.Address, error) {
	return _StargateAdapterTest.Contract.ExcludeContracts(&_StargateAdapterTest.CallOpts)
}

// ExcludeSelectors is a free data retrieval call binding the contract method 0xb0464fdc.
//
// Solidity: function excludeSelectors() view returns((address,bytes4[])[] excludedSelectors_)
func (_StargateAdapterTest *StargateAdapterTestCaller) ExcludeSelectors(opts *bind.CallOpts) ([]StdInvariantFuzzSelector, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "excludeSelectors")

	if err != nil {
		return *new([]StdInvariantFuzzSelector), err
	}

	out0 := *abi.ConvertType(out[0], new([]StdInvariantFuzzSelector)).(*[]StdInvariantFuzzSelector)

	return out0, err

}

// ExcludeSelectors is a free data retrieval call binding the contract method 0xb0464fdc.
//
// Solidity: function excludeSelectors() view returns((address,bytes4[])[] excludedSelectors_)
func (_StargateAdapterTest *StargateAdapterTestSession) ExcludeSelectors() ([]StdInvariantFuzzSelector, error) {
	return _StargateAdapterTest.Contract.ExcludeSelectors(&_StargateAdapterTest.CallOpts)
}

// ExcludeSelectors is a free data retrieval call binding the contract method 0xb0464fdc.
//
// Solidity: function excludeSelectors() view returns((address,bytes4[])[] excludedSelectors_)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ExcludeSelectors() ([]StdInvariantFuzzSelector, error) {
	return _StargateAdapterTest.Contract.ExcludeSelectors(&_StargateAdapterTest.CallOpts)
}

// ExcludeSenders is a free data retrieval call binding the contract method 0x1ed7831c.
//
// Solidity: function excludeSenders() view returns(address[] excludedSenders_)
func (_StargateAdapterTest *StargateAdapterTestCaller) ExcludeSenders(opts *bind.CallOpts) ([]common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "excludeSenders")

	if err != nil {
		return *new([]common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new([]common.Address)).(*[]common.Address)

	return out0, err

}

// ExcludeSenders is a free data retrieval call binding the contract method 0x1ed7831c.
//
// Solidity: function excludeSenders() view returns(address[] excludedSenders_)
func (_StargateAdapterTest *StargateAdapterTestSession) ExcludeSenders() ([]common.Address, error) {
	return _StargateAdapterTest.Contract.ExcludeSenders(&_StargateAdapterTest.CallOpts)
}

// ExcludeSenders is a free data retrieval call binding the contract method 0x1ed7831c.
//
// Solidity: function excludeSenders() view returns(address[] excludedSenders_)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ExcludeSenders() ([]common.Address, error) {
	return _StargateAdapterTest.Contract.ExcludeSenders(&_StargateAdapterTest.CallOpts)
}

// Failed is a free data retrieval call binding the contract method 0xba414fa6.
//
// Solidity: function failed() view returns(bool)
func (_StargateAdapterTest *StargateAdapterTestCaller) Failed(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "failed")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Failed is a free data retrieval call binding the contract method 0xba414fa6.
//
// Solidity: function failed() view returns(bool)
func (_StargateAdapterTest *StargateAdapterTestSession) Failed() (bool, error) {
	return _StargateAdapterTest.Contract.Failed(&_StargateAdapterTest.CallOpts)
}

// Failed is a free data retrieval call binding the contract method 0xba414fa6.
//
// Solidity: function failed() view returns(bool)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) Failed() (bool, error) {
	return _StargateAdapterTest.Contract.Failed(&_StargateAdapterTest.CallOpts)
}

// MockERC20 is a free data retrieval call binding the contract method 0x5a744d91.
//
// Solidity: function mockERC20() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) MockERC20(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "mockERC20")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MockERC20 is a free data retrieval call binding the contract method 0x5a744d91.
//
// Solidity: function mockERC20() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) MockERC20() (common.Address, error) {
	return _StargateAdapterTest.Contract.MockERC20(&_StargateAdapterTest.CallOpts)
}

// MockERC20 is a free data retrieval call binding the contract method 0x5a744d91.
//
// Solidity: function mockERC20() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MockERC20() (common.Address, error) {
	return _StargateAdapterTest.Contract.MockERC20(&_StargateAdapterTest.CallOpts)
}

// MockNativePool is a free data retrieval call binding the contract method 0x0c7ec981.
//
// Solidity: function mockNativePool() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) MockNativePool(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "mockNativePool")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MockNativePool is a free data retrieval call binding the contract method 0x0c7ec981.
//
// Solidity: function mockNativePool() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) MockNativePool() (common.Address, error) {
	return _StargateAdapterTest.Contract.MockNativePool(&_StargateAdapterTest.CallOpts)
}

// MockNativePool is a free data retrieval call binding the contract method 0x0c7ec981.
//
// Solidity: function mockNativePool() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MockNativePool() (common.Address, error) {
	return _StargateAdapterTest.Contract.MockNativePool(&_StargateAdapterTest.CallOpts)
}

// MockPool is a free data retrieval call binding the contract method 0xc31cc689.
//
// Solidity: function mockPool() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) MockPool(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "mockPool")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MockPool is a free data retrieval call binding the contract method 0xc31cc689.
//
// Solidity: function mockPool() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) MockPool() (common.Address, error) {
	return _StargateAdapterTest.Contract.MockPool(&_StargateAdapterTest.CallOpts)
}

// MockPool is a free data retrieval call binding the contract method 0xc31cc689.
//
// Solidity: function mockPool() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MockPool() (common.Address, error) {
	return _StargateAdapterTest.Contract.MockPool(&_StargateAdapterTest.CallOpts)
}

// MockTokenMessaging is a free data retrieval call binding the contract method 0x14f65199.
//
// Solidity: function mockTokenMessaging() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) MockTokenMessaging(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "mockTokenMessaging")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MockTokenMessaging is a free data retrieval call binding the contract method 0x14f65199.
//
// Solidity: function mockTokenMessaging() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) MockTokenMessaging() (common.Address, error) {
	return _StargateAdapterTest.Contract.MockTokenMessaging(&_StargateAdapterTest.CallOpts)
}

// MockTokenMessaging is a free data retrieval call binding the contract method 0x14f65199.
//
// Solidity: function mockTokenMessaging() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) MockTokenMessaging() (common.Address, error) {
	return _StargateAdapterTest.Contract.MockTokenMessaging(&_StargateAdapterTest.CallOpts)
}

// ProcessBridgedExecution is a free data retrieval call binding the contract method 0xed71d9d1.
//
// Solidity: function processBridgedExecution(address , address , address[] , uint256[] , bytes , bytes , bytes ) pure returns()
func (_StargateAdapterTest *StargateAdapterTestCaller) ProcessBridgedExecution(opts *bind.CallOpts, arg0 common.Address, arg1 common.Address, arg2 []common.Address, arg3 []*big.Int, arg4 []byte, arg5 []byte, arg6 []byte) error {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "processBridgedExecution", arg0, arg1, arg2, arg3, arg4, arg5, arg6)

	if err != nil {
		return err
	}

	return err

}

// ProcessBridgedExecution is a free data retrieval call binding the contract method 0xed71d9d1.
//
// Solidity: function processBridgedExecution(address , address , address[] , uint256[] , bytes , bytes , bytes ) pure returns()
func (_StargateAdapterTest *StargateAdapterTestSession) ProcessBridgedExecution(arg0 common.Address, arg1 common.Address, arg2 []common.Address, arg3 []*big.Int, arg4 []byte, arg5 []byte, arg6 []byte) error {
	return _StargateAdapterTest.Contract.ProcessBridgedExecution(&_StargateAdapterTest.CallOpts, arg0, arg1, arg2, arg3, arg4, arg5, arg6)
}

// ProcessBridgedExecution is a free data retrieval call binding the contract method 0xed71d9d1.
//
// Solidity: function processBridgedExecution(address , address , address[] , uint256[] , bytes , bytes , bytes ) pure returns()
func (_StargateAdapterTest *StargateAdapterTestCallerSession) ProcessBridgedExecution(arg0 common.Address, arg1 common.Address, arg2 []common.Address, arg3 []*big.Int, arg4 []byte, arg5 []byte, arg6 []byte) error {
	return _StargateAdapterTest.Contract.ProcessBridgedExecution(&_StargateAdapterTest.CallOpts, arg0, arg1, arg2, arg3, arg4, arg5, arg6)
}

// StargateAdapter is a free data retrieval call binding the contract method 0x628cda6d.
//
// Solidity: function stargateAdapter() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) StargateAdapter(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "stargateAdapter")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// StargateAdapter is a free data retrieval call binding the contract method 0x628cda6d.
//
// Solidity: function stargateAdapter() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) StargateAdapter() (common.Address, error) {
	return _StargateAdapterTest.Contract.StargateAdapter(&_StargateAdapterTest.CallOpts)
}

// StargateAdapter is a free data retrieval call binding the contract method 0x628cda6d.
//
// Solidity: function stargateAdapter() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) StargateAdapter() (common.Address, error) {
	return _StargateAdapterTest.Contract.StargateAdapter(&_StargateAdapterTest.CallOpts)
}

// TargetArtifactSelectors is a free data retrieval call binding the contract method 0x66d9a9a0.
//
// Solidity: function targetArtifactSelectors() view returns((string,bytes4[])[] targetedArtifactSelectors_)
func (_StargateAdapterTest *StargateAdapterTestCaller) TargetArtifactSelectors(opts *bind.CallOpts) ([]StdInvariantFuzzArtifactSelector, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "targetArtifactSelectors")

	if err != nil {
		return *new([]StdInvariantFuzzArtifactSelector), err
	}

	out0 := *abi.ConvertType(out[0], new([]StdInvariantFuzzArtifactSelector)).(*[]StdInvariantFuzzArtifactSelector)

	return out0, err

}

// TargetArtifactSelectors is a free data retrieval call binding the contract method 0x66d9a9a0.
//
// Solidity: function targetArtifactSelectors() view returns((string,bytes4[])[] targetedArtifactSelectors_)
func (_StargateAdapterTest *StargateAdapterTestSession) TargetArtifactSelectors() ([]StdInvariantFuzzArtifactSelector, error) {
	return _StargateAdapterTest.Contract.TargetArtifactSelectors(&_StargateAdapterTest.CallOpts)
}

// TargetArtifactSelectors is a free data retrieval call binding the contract method 0x66d9a9a0.
//
// Solidity: function targetArtifactSelectors() view returns((string,bytes4[])[] targetedArtifactSelectors_)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) TargetArtifactSelectors() ([]StdInvariantFuzzArtifactSelector, error) {
	return _StargateAdapterTest.Contract.TargetArtifactSelectors(&_StargateAdapterTest.CallOpts)
}

// TargetArtifacts is a free data retrieval call binding the contract method 0x85226c81.
//
// Solidity: function targetArtifacts() view returns(string[] targetedArtifacts_)
func (_StargateAdapterTest *StargateAdapterTestCaller) TargetArtifacts(opts *bind.CallOpts) ([]string, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "targetArtifacts")

	if err != nil {
		return *new([]string), err
	}

	out0 := *abi.ConvertType(out[0], new([]string)).(*[]string)

	return out0, err

}

// TargetArtifacts is a free data retrieval call binding the contract method 0x85226c81.
//
// Solidity: function targetArtifacts() view returns(string[] targetedArtifacts_)
func (_StargateAdapterTest *StargateAdapterTestSession) TargetArtifacts() ([]string, error) {
	return _StargateAdapterTest.Contract.TargetArtifacts(&_StargateAdapterTest.CallOpts)
}

// TargetArtifacts is a free data retrieval call binding the contract method 0x85226c81.
//
// Solidity: function targetArtifacts() view returns(string[] targetedArtifacts_)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) TargetArtifacts() ([]string, error) {
	return _StargateAdapterTest.Contract.TargetArtifacts(&_StargateAdapterTest.CallOpts)
}

// TargetContracts is a free data retrieval call binding the contract method 0x3f7286f4.
//
// Solidity: function targetContracts() view returns(address[] targetedContracts_)
func (_StargateAdapterTest *StargateAdapterTestCaller) TargetContracts(opts *bind.CallOpts) ([]common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "targetContracts")

	if err != nil {
		return *new([]common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new([]common.Address)).(*[]common.Address)

	return out0, err

}

// TargetContracts is a free data retrieval call binding the contract method 0x3f7286f4.
//
// Solidity: function targetContracts() view returns(address[] targetedContracts_)
func (_StargateAdapterTest *StargateAdapterTestSession) TargetContracts() ([]common.Address, error) {
	return _StargateAdapterTest.Contract.TargetContracts(&_StargateAdapterTest.CallOpts)
}

// TargetContracts is a free data retrieval call binding the contract method 0x3f7286f4.
//
// Solidity: function targetContracts() view returns(address[] targetedContracts_)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) TargetContracts() ([]common.Address, error) {
	return _StargateAdapterTest.Contract.TargetContracts(&_StargateAdapterTest.CallOpts)
}

// TargetInterfaces is a free data retrieval call binding the contract method 0x2ade3880.
//
// Solidity: function targetInterfaces() view returns((address,string[])[] targetedInterfaces_)
func (_StargateAdapterTest *StargateAdapterTestCaller) TargetInterfaces(opts *bind.CallOpts) ([]StdInvariantFuzzInterface, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "targetInterfaces")

	if err != nil {
		return *new([]StdInvariantFuzzInterface), err
	}

	out0 := *abi.ConvertType(out[0], new([]StdInvariantFuzzInterface)).(*[]StdInvariantFuzzInterface)

	return out0, err

}

// TargetInterfaces is a free data retrieval call binding the contract method 0x2ade3880.
//
// Solidity: function targetInterfaces() view returns((address,string[])[] targetedInterfaces_)
func (_StargateAdapterTest *StargateAdapterTestSession) TargetInterfaces() ([]StdInvariantFuzzInterface, error) {
	return _StargateAdapterTest.Contract.TargetInterfaces(&_StargateAdapterTest.CallOpts)
}

// TargetInterfaces is a free data retrieval call binding the contract method 0x2ade3880.
//
// Solidity: function targetInterfaces() view returns((address,string[])[] targetedInterfaces_)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) TargetInterfaces() ([]StdInvariantFuzzInterface, error) {
	return _StargateAdapterTest.Contract.TargetInterfaces(&_StargateAdapterTest.CallOpts)
}

// TargetSelectors is a free data retrieval call binding the contract method 0x916a17c6.
//
// Solidity: function targetSelectors() view returns((address,bytes4[])[] targetedSelectors_)
func (_StargateAdapterTest *StargateAdapterTestCaller) TargetSelectors(opts *bind.CallOpts) ([]StdInvariantFuzzSelector, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "targetSelectors")

	if err != nil {
		return *new([]StdInvariantFuzzSelector), err
	}

	out0 := *abi.ConvertType(out[0], new([]StdInvariantFuzzSelector)).(*[]StdInvariantFuzzSelector)

	return out0, err

}

// TargetSelectors is a free data retrieval call binding the contract method 0x916a17c6.
//
// Solidity: function targetSelectors() view returns((address,bytes4[])[] targetedSelectors_)
func (_StargateAdapterTest *StargateAdapterTestSession) TargetSelectors() ([]StdInvariantFuzzSelector, error) {
	return _StargateAdapterTest.Contract.TargetSelectors(&_StargateAdapterTest.CallOpts)
}

// TargetSelectors is a free data retrieval call binding the contract method 0x916a17c6.
//
// Solidity: function targetSelectors() view returns((address,bytes4[])[] targetedSelectors_)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) TargetSelectors() ([]StdInvariantFuzzSelector, error) {
	return _StargateAdapterTest.Contract.TargetSelectors(&_StargateAdapterTest.CallOpts)
}

// TargetSenders is a free data retrieval call binding the contract method 0x3e5e3c23.
//
// Solidity: function targetSenders() view returns(address[] targetedSenders_)
func (_StargateAdapterTest *StargateAdapterTestCaller) TargetSenders(opts *bind.CallOpts) ([]common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "targetSenders")

	if err != nil {
		return *new([]common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new([]common.Address)).(*[]common.Address)

	return out0, err

}

// TargetSenders is a free data retrieval call binding the contract method 0x3e5e3c23.
//
// Solidity: function targetSenders() view returns(address[] targetedSenders_)
func (_StargateAdapterTest *StargateAdapterTestSession) TargetSenders() ([]common.Address, error) {
	return _StargateAdapterTest.Contract.TargetSenders(&_StargateAdapterTest.CallOpts)
}

// TargetSenders is a free data retrieval call binding the contract method 0x3e5e3c23.
//
// Solidity: function targetSenders() view returns(address[] targetedSenders_)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) TargetSenders() ([]common.Address, error) {
	return _StargateAdapterTest.Contract.TargetSenders(&_StargateAdapterTest.CallOpts)
}

// User1 is a free data retrieval call binding the contract method 0xac1717b0.
//
// Solidity: function user1() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) User1(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "user1")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// User1 is a free data retrieval call binding the contract method 0xac1717b0.
//
// Solidity: function user1() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) User1() (common.Address, error) {
	return _StargateAdapterTest.Contract.User1(&_StargateAdapterTest.CallOpts)
}

// User1 is a free data retrieval call binding the contract method 0xac1717b0.
//
// Solidity: function user1() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) User1() (common.Address, error) {
	return _StargateAdapterTest.Contract.User1(&_StargateAdapterTest.CallOpts)
}

// User2 is a free data retrieval call binding the contract method 0xb9edb1af.
//
// Solidity: function user2() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) User2(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "user2")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// User2 is a free data retrieval call binding the contract method 0xb9edb1af.
//
// Solidity: function user2() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) User2() (common.Address, error) {
	return _StargateAdapterTest.Contract.User2(&_StargateAdapterTest.CallOpts)
}

// User2 is a free data retrieval call binding the contract method 0xb9edb1af.
//
// Solidity: function user2() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) User2() (common.Address, error) {
	return _StargateAdapterTest.Contract.User2(&_StargateAdapterTest.CallOpts)
}

// User3 is a free data retrieval call binding the contract method 0x703ce4af.
//
// Solidity: function user3() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCaller) User3(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _StargateAdapterTest.contract.Call(opts, &out, "user3")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// User3 is a free data retrieval call binding the contract method 0x703ce4af.
//
// Solidity: function user3() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestSession) User3() (common.Address, error) {
	return _StargateAdapterTest.Contract.User3(&_StargateAdapterTest.CallOpts)
}

// User3 is a free data retrieval call binding the contract method 0x703ce4af.
//
// Solidity: function user3() view returns(address)
func (_StargateAdapterTest *StargateAdapterTestCallerSession) User3() (common.Address, error) {
	return _StargateAdapterTest.Contract.User3(&_StargateAdapterTest.CallOpts)
}

// DeployAccounts is a paid mutator transaction binding the contract method 0xd9e4deb3.
//
// Solidity: function deployAccounts() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) DeployAccounts(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "deployAccounts")
}

// DeployAccounts is a paid mutator transaction binding the contract method 0xd9e4deb3.
//
// Solidity: function deployAccounts() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) DeployAccounts() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.DeployAccounts(&_StargateAdapterTest.TransactOpts)
}

// DeployAccounts is a paid mutator transaction binding the contract method 0xd9e4deb3.
//
// Solidity: function deployAccounts() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) DeployAccounts() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.DeployAccounts(&_StargateAdapterTest.TransactOpts)
}

// SetUp is a paid mutator transaction binding the contract method 0x0a9254e4.
//
// Solidity: function setUp() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) SetUp(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "setUp")
}

// SetUp is a paid mutator transaction binding the contract method 0x0a9254e4.
//
// Solidity: function setUp() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) SetUp() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.SetUp(&_StargateAdapterTest.TransactOpts)
}

// SetUp is a paid mutator transaction binding the contract method 0x0a9254e4.
//
// Solidity: function setUp() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) SetUp() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.SetUp(&_StargateAdapterTest.TransactOpts)
}

// StartStateDiffRecording is a paid mutator transaction binding the contract method 0xcf22e3c9.
//
// Solidity: function startStateDiffRecording() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) StartStateDiffRecording(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "startStateDiffRecording")
}

// StartStateDiffRecording is a paid mutator transaction binding the contract method 0xcf22e3c9.
//
// Solidity: function startStateDiffRecording() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) StartStateDiffRecording() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.StartStateDiffRecording(&_StargateAdapterTest.TransactOpts)
}

// StartStateDiffRecording is a paid mutator transaction binding the contract method 0xcf22e3c9.
//
// Solidity: function startStateDiffRecording() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) StartStateDiffRecording() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.StartStateDiffRecording(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterConstructor is a paid mutator transaction binding the contract method 0xd02e082f.
//
// Solidity: function test_StargateAdapter_Constructor() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterConstructor(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_Constructor")
}

// TestStargateAdapterConstructor is a paid mutator transaction binding the contract method 0xd02e082f.
//
// Solidity: function test_StargateAdapter_Constructor() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterConstructor() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterConstructor(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterConstructor is a paid mutator transaction binding the contract method 0xd02e082f.
//
// Solidity: function test_StargateAdapter_Constructor() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterConstructor() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterConstructor(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterConstructorRevertIfZeroEndpoint is a paid mutator transaction binding the contract method 0xaea22fdd.
//
// Solidity: function test_StargateAdapter_Constructor_RevertIf_ZeroEndpoint() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterConstructorRevertIfZeroEndpoint(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_Constructor_RevertIf_ZeroEndpoint")
}

// TestStargateAdapterConstructorRevertIfZeroEndpoint is a paid mutator transaction binding the contract method 0xaea22fdd.
//
// Solidity: function test_StargateAdapter_Constructor_RevertIf_ZeroEndpoint() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterConstructorRevertIfZeroEndpoint() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterConstructorRevertIfZeroEndpoint(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterConstructorRevertIfZeroEndpoint is a paid mutator transaction binding the contract method 0xaea22fdd.
//
// Solidity: function test_StargateAdapter_Constructor_RevertIf_ZeroEndpoint() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterConstructorRevertIfZeroEndpoint() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterConstructorRevertIfZeroEndpoint(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterConstructorRevertIfZeroExecutor is a paid mutator transaction binding the contract method 0x6924a03b.
//
// Solidity: function test_StargateAdapter_Constructor_RevertIf_ZeroExecutor() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterConstructorRevertIfZeroExecutor(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_Constructor_RevertIf_ZeroExecutor")
}

// TestStargateAdapterConstructorRevertIfZeroExecutor is a paid mutator transaction binding the contract method 0x6924a03b.
//
// Solidity: function test_StargateAdapter_Constructor_RevertIf_ZeroExecutor() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterConstructorRevertIfZeroExecutor() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterConstructorRevertIfZeroExecutor(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterConstructorRevertIfZeroExecutor is a paid mutator transaction binding the contract method 0x6924a03b.
//
// Solidity: function test_StargateAdapter_Constructor_RevertIf_ZeroExecutor() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterConstructorRevertIfZeroExecutor() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterConstructorRevertIfZeroExecutor(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterConstructorRevertIfZeroTokenMessaging is a paid mutator transaction binding the contract method 0x40dc6df4.
//
// Solidity: function test_StargateAdapter_Constructor_RevertIf_ZeroTokenMessaging() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterConstructorRevertIfZeroTokenMessaging(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_Constructor_RevertIf_ZeroTokenMessaging")
}

// TestStargateAdapterConstructorRevertIfZeroTokenMessaging is a paid mutator transaction binding the contract method 0x40dc6df4.
//
// Solidity: function test_StargateAdapter_Constructor_RevertIf_ZeroTokenMessaging() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterConstructorRevertIfZeroTokenMessaging() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterConstructorRevertIfZeroTokenMessaging(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterConstructorRevertIfZeroTokenMessaging is a paid mutator transaction binding the contract method 0x40dc6df4.
//
// Solidity: function test_StargateAdapter_Constructor_RevertIf_ZeroTokenMessaging() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterConstructorRevertIfZeroTokenMessaging() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterConstructorRevertIfZeroTokenMessaging(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterClaimFailedTransferERC20 is a paid mutator transaction binding the contract method 0x6df0ef4f.
//
// Solidity: function test_StargateAdapter_claimFailedTransfer_ERC20() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterClaimFailedTransferERC20(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_claimFailedTransfer_ERC20")
}

// TestStargateAdapterClaimFailedTransferERC20 is a paid mutator transaction binding the contract method 0x6df0ef4f.
//
// Solidity: function test_StargateAdapter_claimFailedTransfer_ERC20() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterClaimFailedTransferERC20() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterClaimFailedTransferERC20(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterClaimFailedTransferERC20 is a paid mutator transaction binding the contract method 0x6df0ef4f.
//
// Solidity: function test_StargateAdapter_claimFailedTransfer_ERC20() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterClaimFailedTransferERC20() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterClaimFailedTransferERC20(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterClaimFailedTransferNativeETH is a paid mutator transaction binding the contract method 0x60cb1702.
//
// Solidity: function test_StargateAdapter_claimFailedTransfer_NativeETH() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterClaimFailedTransferNativeETH(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_claimFailedTransfer_NativeETH")
}

// TestStargateAdapterClaimFailedTransferNativeETH is a paid mutator transaction binding the contract method 0x60cb1702.
//
// Solidity: function test_StargateAdapter_claimFailedTransfer_NativeETH() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterClaimFailedTransferNativeETH() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterClaimFailedTransferNativeETH(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterClaimFailedTransferNativeETH is a paid mutator transaction binding the contract method 0x60cb1702.
//
// Solidity: function test_StargateAdapter_claimFailedTransfer_NativeETH() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterClaimFailedTransferNativeETH() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterClaimFailedTransferNativeETH(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterClaimFailedTransferPartialClaim is a paid mutator transaction binding the contract method 0xccfc07a3.
//
// Solidity: function test_StargateAdapter_claimFailedTransfer_PartialClaim() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterClaimFailedTransferPartialClaim(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_claimFailedTransfer_PartialClaim")
}

// TestStargateAdapterClaimFailedTransferPartialClaim is a paid mutator transaction binding the contract method 0xccfc07a3.
//
// Solidity: function test_StargateAdapter_claimFailedTransfer_PartialClaim() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterClaimFailedTransferPartialClaim() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterClaimFailedTransferPartialClaim(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterClaimFailedTransferPartialClaim is a paid mutator transaction binding the contract method 0xccfc07a3.
//
// Solidity: function test_StargateAdapter_claimFailedTransfer_PartialClaim() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterClaimFailedTransferPartialClaim() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterClaimFailedTransferPartialClaim(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterClaimFailedTransferRevertIfInsufficientBalance is a paid mutator transaction binding the contract method 0x2be95438.
//
// Solidity: function test_StargateAdapter_claimFailedTransfer_RevertIf_InsufficientBalance() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterClaimFailedTransferRevertIfInsufficientBalance(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_claimFailedTransfer_RevertIf_InsufficientBalance")
}

// TestStargateAdapterClaimFailedTransferRevertIfInsufficientBalance is a paid mutator transaction binding the contract method 0x2be95438.
//
// Solidity: function test_StargateAdapter_claimFailedTransfer_RevertIf_InsufficientBalance() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterClaimFailedTransferRevertIfInsufficientBalance() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterClaimFailedTransferRevertIfInsufficientBalance(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterClaimFailedTransferRevertIfInsufficientBalance is a paid mutator transaction binding the contract method 0x2be95438.
//
// Solidity: function test_StargateAdapter_claimFailedTransfer_RevertIf_InsufficientBalance() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterClaimFailedTransferRevertIfInsufficientBalance() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterClaimFailedTransferRevertIfInsufficientBalance(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterClaimFailedTransferRevertIfZeroAmount is a paid mutator transaction binding the contract method 0x20c8a373.
//
// Solidity: function test_StargateAdapter_claimFailedTransfer_RevertIf_ZeroAmount() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterClaimFailedTransferRevertIfZeroAmount(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_claimFailedTransfer_RevertIf_ZeroAmount")
}

// TestStargateAdapterClaimFailedTransferRevertIfZeroAmount is a paid mutator transaction binding the contract method 0x20c8a373.
//
// Solidity: function test_StargateAdapter_claimFailedTransfer_RevertIf_ZeroAmount() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterClaimFailedTransferRevertIfZeroAmount() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterClaimFailedTransferRevertIfZeroAmount(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterClaimFailedTransferRevertIfZeroAmount is a paid mutator transaction binding the contract method 0x20c8a373.
//
// Solidity: function test_StargateAdapter_claimFailedTransfer_RevertIf_ZeroAmount() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterClaimFailedTransferRevertIfZeroAmount() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterClaimFailedTransferRevertIfZeroAmount(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeConcurrentComposesIsolated is a paid mutator transaction binding the contract method 0x0ca53022.
//
// Solidity: function test_StargateAdapter_lzCompose_ConcurrentComposesIsolated() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterLzComposeConcurrentComposesIsolated(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_lzCompose_ConcurrentComposesIsolated")
}

// TestStargateAdapterLzComposeConcurrentComposesIsolated is a paid mutator transaction binding the contract method 0x0ca53022.
//
// Solidity: function test_StargateAdapter_lzCompose_ConcurrentComposesIsolated() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterLzComposeConcurrentComposesIsolated() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeConcurrentComposesIsolated(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeConcurrentComposesIsolated is a paid mutator transaction binding the contract method 0x0ca53022.
//
// Solidity: function test_StargateAdapter_lzCompose_ConcurrentComposesIsolated() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterLzComposeConcurrentComposesIsolated() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeConcurrentComposesIsolated(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeDustRemainsInAdapter is a paid mutator transaction binding the contract method 0x742195f9.
//
// Solidity: function test_StargateAdapter_lzCompose_DustRemainsInAdapter() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterLzComposeDustRemainsInAdapter(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_lzCompose_DustRemainsInAdapter")
}

// TestStargateAdapterLzComposeDustRemainsInAdapter is a paid mutator transaction binding the contract method 0x742195f9.
//
// Solidity: function test_StargateAdapter_lzCompose_DustRemainsInAdapter() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterLzComposeDustRemainsInAdapter() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeDustRemainsInAdapter(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeDustRemainsInAdapter is a paid mutator transaction binding the contract method 0x742195f9.
//
// Solidity: function test_StargateAdapter_lzCompose_DustRemainsInAdapter() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterLzComposeDustRemainsInAdapter() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeDustRemainsInAdapter(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeERC20HappyPath is a paid mutator transaction binding the contract method 0xac45d5c4.
//
// Solidity: function test_StargateAdapter_lzCompose_ERC20_HappyPath() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterLzComposeERC20HappyPath(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_lzCompose_ERC20_HappyPath")
}

// TestStargateAdapterLzComposeERC20HappyPath is a paid mutator transaction binding the contract method 0xac45d5c4.
//
// Solidity: function test_StargateAdapter_lzCompose_ERC20_HappyPath() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterLzComposeERC20HappyPath() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeERC20HappyPath(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeERC20HappyPath is a paid mutator transaction binding the contract method 0xac45d5c4.
//
// Solidity: function test_StargateAdapter_lzCompose_ERC20_HappyPath() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterLzComposeERC20HappyPath() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeERC20HappyPath(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeExecutionFailsDoesNotRevert is a paid mutator transaction binding the contract method 0x89848c1a.
//
// Solidity: function test_StargateAdapter_lzCompose_ExecutionFails_DoesNotRevert() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterLzComposeExecutionFailsDoesNotRevert(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_lzCompose_ExecutionFails_DoesNotRevert")
}

// TestStargateAdapterLzComposeExecutionFailsDoesNotRevert is a paid mutator transaction binding the contract method 0x89848c1a.
//
// Solidity: function test_StargateAdapter_lzCompose_ExecutionFails_DoesNotRevert() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterLzComposeExecutionFailsDoesNotRevert() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeExecutionFailsDoesNotRevert(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeExecutionFailsDoesNotRevert is a paid mutator transaction binding the contract method 0x89848c1a.
//
// Solidity: function test_StargateAdapter_lzCompose_ExecutionFails_DoesNotRevert() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterLzComposeExecutionFailsDoesNotRevert() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeExecutionFailsDoesNotRevert(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeExecutionFailsEmitsEvent is a paid mutator transaction binding the contract method 0xdf6f4770.
//
// Solidity: function test_StargateAdapter_lzCompose_ExecutionFails_EmitsEvent() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterLzComposeExecutionFailsEmitsEvent(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_lzCompose_ExecutionFails_EmitsEvent")
}

// TestStargateAdapterLzComposeExecutionFailsEmitsEvent is a paid mutator transaction binding the contract method 0xdf6f4770.
//
// Solidity: function test_StargateAdapter_lzCompose_ExecutionFails_EmitsEvent() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterLzComposeExecutionFailsEmitsEvent() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeExecutionFailsEmitsEvent(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeExecutionFailsEmitsEvent is a paid mutator transaction binding the contract method 0xdf6f4770.
//
// Solidity: function test_StargateAdapter_lzCompose_ExecutionFails_EmitsEvent() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterLzComposeExecutionFailsEmitsEvent() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeExecutionFailsEmitsEvent(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeInvalidInnerDecodingEmitsAndReturns is a paid mutator transaction binding the contract method 0x5ccff4d9.
//
// Solidity: function test_StargateAdapter_lzCompose_InvalidInnerDecoding_EmitsAndReturns() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterLzComposeInvalidInnerDecodingEmitsAndReturns(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_lzCompose_InvalidInnerDecoding_EmitsAndReturns")
}

// TestStargateAdapterLzComposeInvalidInnerDecodingEmitsAndReturns is a paid mutator transaction binding the contract method 0x5ccff4d9.
//
// Solidity: function test_StargateAdapter_lzCompose_InvalidInnerDecoding_EmitsAndReturns() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterLzComposeInvalidInnerDecodingEmitsAndReturns() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeInvalidInnerDecodingEmitsAndReturns(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeInvalidInnerDecodingEmitsAndReturns is a paid mutator transaction binding the contract method 0x5ccff4d9.
//
// Solidity: function test_StargateAdapter_lzCompose_InvalidInnerDecoding_EmitsAndReturns() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterLzComposeInvalidInnerDecodingEmitsAndReturns() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeInvalidInnerDecodingEmitsAndReturns(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeMessageTooShortEmitsAndReturns is a paid mutator transaction binding the contract method 0x622b48bd.
//
// Solidity: function test_StargateAdapter_lzCompose_MessageTooShort_EmitsAndReturns() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterLzComposeMessageTooShortEmitsAndReturns(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_lzCompose_MessageTooShort_EmitsAndReturns")
}

// TestStargateAdapterLzComposeMessageTooShortEmitsAndReturns is a paid mutator transaction binding the contract method 0x622b48bd.
//
// Solidity: function test_StargateAdapter_lzCompose_MessageTooShort_EmitsAndReturns() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterLzComposeMessageTooShortEmitsAndReturns() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeMessageTooShortEmitsAndReturns(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeMessageTooShortEmitsAndReturns is a paid mutator transaction binding the contract method 0x622b48bd.
//
// Solidity: function test_StargateAdapter_lzCompose_MessageTooShort_EmitsAndReturns() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterLzComposeMessageTooShortEmitsAndReturns() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeMessageTooShortEmitsAndReturns(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeNativeETHHappyPath is a paid mutator transaction binding the contract method 0x510aab6a.
//
// Solidity: function test_StargateAdapter_lzCompose_NativeETH_HappyPath() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterLzComposeNativeETHHappyPath(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_lzCompose_NativeETH_HappyPath")
}

// TestStargateAdapterLzComposeNativeETHHappyPath is a paid mutator transaction binding the contract method 0x510aab6a.
//
// Solidity: function test_StargateAdapter_lzCompose_NativeETH_HappyPath() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterLzComposeNativeETHHappyPath() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeNativeETHHappyPath(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeNativeETHHappyPath is a paid mutator transaction binding the contract method 0x510aab6a.
//
// Solidity: function test_StargateAdapter_lzCompose_NativeETH_HappyPath() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterLzComposeNativeETHHappyPath() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeNativeETHHappyPath(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeNativeETHNonPayableAccountStoresForClaim is a paid mutator transaction binding the contract method 0x1ae70eff.
//
// Solidity: function test_StargateAdapter_lzCompose_NativeETH_NonPayableAccount_StoresForClaim() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterLzComposeNativeETHNonPayableAccountStoresForClaim(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_lzCompose_NativeETH_NonPayableAccount_StoresForClaim")
}

// TestStargateAdapterLzComposeNativeETHNonPayableAccountStoresForClaim is a paid mutator transaction binding the contract method 0x1ae70eff.
//
// Solidity: function test_StargateAdapter_lzCompose_NativeETH_NonPayableAccount_StoresForClaim() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterLzComposeNativeETHNonPayableAccountStoresForClaim() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeNativeETHNonPayableAccountStoresForClaim(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeNativeETHNonPayableAccountStoresForClaim is a paid mutator transaction binding the contract method 0x1ae70eff.
//
// Solidity: function test_StargateAdapter_lzCompose_NativeETH_NonPayableAccount_StoresForClaim() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterLzComposeNativeETHNonPayableAccountStoresForClaim() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeNativeETHNonPayableAccountStoresForClaim(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeNoPreBalanceNativeETHNoFailedCredit is a paid mutator transaction binding the contract method 0xb52d78a8.
//
// Solidity: function test_StargateAdapter_lzCompose_NoPreBalance_NativeETH_NoFailedCredit() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterLzComposeNoPreBalanceNativeETHNoFailedCredit(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_lzCompose_NoPreBalance_NativeETH_NoFailedCredit")
}

// TestStargateAdapterLzComposeNoPreBalanceNativeETHNoFailedCredit is a paid mutator transaction binding the contract method 0xb52d78a8.
//
// Solidity: function test_StargateAdapter_lzCompose_NoPreBalance_NativeETH_NoFailedCredit() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterLzComposeNoPreBalanceNativeETHNoFailedCredit() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeNoPreBalanceNativeETHNoFailedCredit(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeNoPreBalanceNativeETHNoFailedCredit is a paid mutator transaction binding the contract method 0xb52d78a8.
//
// Solidity: function test_StargateAdapter_lzCompose_NoPreBalance_NativeETH_NoFailedCredit() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterLzComposeNoPreBalanceNativeETHNoFailedCredit() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeNoPreBalanceNativeETHNoFailedCredit(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeNoPreBalanceNoFailedCredit is a paid mutator transaction binding the contract method 0x597b7236.
//
// Solidity: function test_StargateAdapter_lzCompose_NoPreBalance_NoFailedCredit() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterLzComposeNoPreBalanceNoFailedCredit(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_lzCompose_NoPreBalance_NoFailedCredit")
}

// TestStargateAdapterLzComposeNoPreBalanceNoFailedCredit is a paid mutator transaction binding the contract method 0x597b7236.
//
// Solidity: function test_StargateAdapter_lzCompose_NoPreBalance_NoFailedCredit() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterLzComposeNoPreBalanceNoFailedCredit() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeNoPreBalanceNoFailedCredit(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeNoPreBalanceNoFailedCredit is a paid mutator transaction binding the contract method 0x597b7236.
//
// Solidity: function test_StargateAdapter_lzCompose_NoPreBalance_NoFailedCredit() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterLzComposeNoPreBalanceNoFailedCredit() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeNoPreBalanceNoFailedCredit(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeNoPreBalanceZeroAccountNoFailedCredit is a paid mutator transaction binding the contract method 0x8480f1d6.
//
// Solidity: function test_StargateAdapter_lzCompose_NoPreBalance_ZeroAccount_NoFailedCredit() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterLzComposeNoPreBalanceZeroAccountNoFailedCredit(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_lzCompose_NoPreBalance_ZeroAccount_NoFailedCredit")
}

// TestStargateAdapterLzComposeNoPreBalanceZeroAccountNoFailedCredit is a paid mutator transaction binding the contract method 0x8480f1d6.
//
// Solidity: function test_StargateAdapter_lzCompose_NoPreBalance_ZeroAccount_NoFailedCredit() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterLzComposeNoPreBalanceZeroAccountNoFailedCredit() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeNoPreBalanceZeroAccountNoFailedCredit(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeNoPreBalanceZeroAccountNoFailedCredit is a paid mutator transaction binding the contract method 0x8480f1d6.
//
// Solidity: function test_StargateAdapter_lzCompose_NoPreBalance_ZeroAccount_NoFailedCredit() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterLzComposeNoPreBalanceZeroAccountNoFailedCredit() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeNoPreBalanceZeroAccountNoFailedCredit(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeRevertIfInvalidSender is a paid mutator transaction binding the contract method 0x0829170c.
//
// Solidity: function test_StargateAdapter_lzCompose_RevertIf_InvalidSender() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterLzComposeRevertIfInvalidSender(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_lzCompose_RevertIf_InvalidSender")
}

// TestStargateAdapterLzComposeRevertIfInvalidSender is a paid mutator transaction binding the contract method 0x0829170c.
//
// Solidity: function test_StargateAdapter_lzCompose_RevertIf_InvalidSender() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterLzComposeRevertIfInvalidSender() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeRevertIfInvalidSender(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeRevertIfInvalidSender is a paid mutator transaction binding the contract method 0x0829170c.
//
// Solidity: function test_StargateAdapter_lzCompose_RevertIf_InvalidSender() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterLzComposeRevertIfInvalidSender() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeRevertIfInvalidSender(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeTransfersOnlyAmountLD is a paid mutator transaction binding the contract method 0x7d81e6f1.
//
// Solidity: function test_StargateAdapter_lzCompose_TransfersOnlyAmountLD() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterLzComposeTransfersOnlyAmountLD(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_lzCompose_TransfersOnlyAmountLD")
}

// TestStargateAdapterLzComposeTransfersOnlyAmountLD is a paid mutator transaction binding the contract method 0x7d81e6f1.
//
// Solidity: function test_StargateAdapter_lzCompose_TransfersOnlyAmountLD() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterLzComposeTransfersOnlyAmountLD() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeTransfersOnlyAmountLD(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeTransfersOnlyAmountLD is a paid mutator transaction binding the contract method 0x7d81e6f1.
//
// Solidity: function test_StargateAdapter_lzCompose_TransfersOnlyAmountLD() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterLzComposeTransfersOnlyAmountLD() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeTransfersOnlyAmountLD(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeUnregisteredPoolEmitsAndReturns is a paid mutator transaction binding the contract method 0xf5d6c1b8.
//
// Solidity: function test_StargateAdapter_lzCompose_UnregisteredPool_EmitsAndReturns() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterLzComposeUnregisteredPoolEmitsAndReturns(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_lzCompose_UnregisteredPool_EmitsAndReturns")
}

// TestStargateAdapterLzComposeUnregisteredPoolEmitsAndReturns is a paid mutator transaction binding the contract method 0xf5d6c1b8.
//
// Solidity: function test_StargateAdapter_lzCompose_UnregisteredPool_EmitsAndReturns() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterLzComposeUnregisteredPoolEmitsAndReturns() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeUnregisteredPoolEmitsAndReturns(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeUnregisteredPoolEmitsAndReturns is a paid mutator transaction binding the contract method 0xf5d6c1b8.
//
// Solidity: function test_StargateAdapter_lzCompose_UnregisteredPool_EmitsAndReturns() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterLzComposeUnregisteredPoolEmitsAndReturns() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeUnregisteredPoolEmitsAndReturns(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeUnregisteredPoolNoTokensTransferred is a paid mutator transaction binding the contract method 0x309a7a75.
//
// Solidity: function test_StargateAdapter_lzCompose_UnregisteredPool_NoTokensTransferred() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterLzComposeUnregisteredPoolNoTokensTransferred(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_lzCompose_UnregisteredPool_NoTokensTransferred")
}

// TestStargateAdapterLzComposeUnregisteredPoolNoTokensTransferred is a paid mutator transaction binding the contract method 0x309a7a75.
//
// Solidity: function test_StargateAdapter_lzCompose_UnregisteredPool_NoTokensTransferred() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterLzComposeUnregisteredPoolNoTokensTransferred() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeUnregisteredPoolNoTokensTransferred(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeUnregisteredPoolNoTokensTransferred is a paid mutator transaction binding the contract method 0x309a7a75.
//
// Solidity: function test_StargateAdapter_lzCompose_UnregisteredPool_NoTokensTransferred() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterLzComposeUnregisteredPoolNoTokensTransferred() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeUnregisteredPoolNoTokensTransferred(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeZeroAmountLD is a paid mutator transaction binding the contract method 0x1acb720c.
//
// Solidity: function test_StargateAdapter_lzCompose_ZeroAmountLD() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterLzComposeZeroAmountLD(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_lzCompose_ZeroAmountLD")
}

// TestStargateAdapterLzComposeZeroAmountLD is a paid mutator transaction binding the contract method 0x1acb720c.
//
// Solidity: function test_StargateAdapter_lzCompose_ZeroAmountLD() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterLzComposeZeroAmountLD() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeZeroAmountLD(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterLzComposeZeroAmountLD is a paid mutator transaction binding the contract method 0x1acb720c.
//
// Solidity: function test_StargateAdapter_lzCompose_ZeroAmountLD() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterLzComposeZeroAmountLD() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterLzComposeZeroAmountLD(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterReceiveAcceptsETH is a paid mutator transaction binding the contract method 0x5b441e7b.
//
// Solidity: function test_StargateAdapter_receive_AcceptsETH() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) TestStargateAdapterReceiveAcceptsETH(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.Transact(opts, "test_StargateAdapter_receive_AcceptsETH")
}

// TestStargateAdapterReceiveAcceptsETH is a paid mutator transaction binding the contract method 0x5b441e7b.
//
// Solidity: function test_StargateAdapter_receive_AcceptsETH() returns()
func (_StargateAdapterTest *StargateAdapterTestSession) TestStargateAdapterReceiveAcceptsETH() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterReceiveAcceptsETH(&_StargateAdapterTest.TransactOpts)
}

// TestStargateAdapterReceiveAcceptsETH is a paid mutator transaction binding the contract method 0x5b441e7b.
//
// Solidity: function test_StargateAdapter_receive_AcceptsETH() returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) TestStargateAdapterReceiveAcceptsETH() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.TestStargateAdapterReceiveAcceptsETH(&_StargateAdapterTest.TransactOpts)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_StargateAdapterTest *StargateAdapterTestTransactor) Receive(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _StargateAdapterTest.contract.RawTransact(opts, nil) // calldata is disallowed for receive function
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_StargateAdapterTest *StargateAdapterTestSession) Receive() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.Receive(&_StargateAdapterTest.TransactOpts)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_StargateAdapterTest *StargateAdapterTestTransactorSession) Receive() (*types.Transaction, error) {
	return _StargateAdapterTest.Contract.Receive(&_StargateAdapterTest.TransactOpts)
}

// StargateAdapterTestExecutionFailedIterator is returned from FilterExecutionFailed and is used to iterate over the raw logs and unpacked data for ExecutionFailed events raised by the StargateAdapterTest contract.
type StargateAdapterTestExecutionFailedIterator struct {
	Event *StargateAdapterTestExecutionFailed // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestExecutionFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestExecutionFailed)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestExecutionFailed)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestExecutionFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestExecutionFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestExecutionFailed represents a ExecutionFailed event raised by the StargateAdapterTest contract.
type StargateAdapterTestExecutionFailed struct {
	Guid    [32]byte
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterExecutionFailed is a free log retrieval operation binding the contract event 0xc21332d9099f42f480283943357e780b317f316c6e841b2ea8727f2b4d0e1958.
//
// Solidity: event ExecutionFailed(bytes32 indexed guid, address indexed account)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterExecutionFailed(opts *bind.FilterOpts, guid [][32]byte, account []common.Address) (*StargateAdapterTestExecutionFailedIterator, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "ExecutionFailed", guidRule, accountRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestExecutionFailedIterator{contract: _StargateAdapterTest.contract, event: "ExecutionFailed", logs: logs, sub: sub}, nil
}

// WatchExecutionFailed is a free log subscription operation binding the contract event 0xc21332d9099f42f480283943357e780b317f316c6e841b2ea8727f2b4d0e1958.
//
// Solidity: event ExecutionFailed(bytes32 indexed guid, address indexed account)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchExecutionFailed(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestExecutionFailed, guid [][32]byte, account []common.Address) (event.Subscription, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "ExecutionFailed", guidRule, accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestExecutionFailed)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "ExecutionFailed", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseExecutionFailed is a log parse operation binding the contract event 0xc21332d9099f42f480283943357e780b317f316c6e841b2ea8727f2b4d0e1958.
//
// Solidity: event ExecutionFailed(bytes32 indexed guid, address indexed account)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseExecutionFailed(log types.Log) (*StargateAdapterTestExecutionFailed, error) {
	event := new(StargateAdapterTestExecutionFailed)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "ExecutionFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestFailedTransferClaimedIterator is returned from FilterFailedTransferClaimed and is used to iterate over the raw logs and unpacked data for FailedTransferClaimed events raised by the StargateAdapterTest contract.
type StargateAdapterTestFailedTransferClaimedIterator struct {
	Event *StargateAdapterTestFailedTransferClaimed // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestFailedTransferClaimedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestFailedTransferClaimed)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestFailedTransferClaimed)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestFailedTransferClaimedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestFailedTransferClaimedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestFailedTransferClaimed represents a FailedTransferClaimed event raised by the StargateAdapterTest contract.
type StargateAdapterTestFailedTransferClaimed struct {
	Account common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterFailedTransferClaimed is a free log retrieval operation binding the contract event 0x6f65559b767bf231652bb6bbc613c03da1500c2af09834b0c638fc41d4b21616.
//
// Solidity: event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterFailedTransferClaimed(opts *bind.FilterOpts, account []common.Address, token []common.Address) (*StargateAdapterTestFailedTransferClaimedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "FailedTransferClaimed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestFailedTransferClaimedIterator{contract: _StargateAdapterTest.contract, event: "FailedTransferClaimed", logs: logs, sub: sub}, nil
}

// WatchFailedTransferClaimed is a free log subscription operation binding the contract event 0x6f65559b767bf231652bb6bbc613c03da1500c2af09834b0c638fc41d4b21616.
//
// Solidity: event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchFailedTransferClaimed(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestFailedTransferClaimed, account []common.Address, token []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "FailedTransferClaimed", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestFailedTransferClaimed)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "FailedTransferClaimed", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseFailedTransferClaimed is a log parse operation binding the contract event 0x6f65559b767bf231652bb6bbc613c03da1500c2af09834b0c638fc41d4b21616.
//
// Solidity: event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseFailedTransferClaimed(log types.Log) (*StargateAdapterTestFailedTransferClaimed, error) {
	event := new(StargateAdapterTestFailedTransferClaimed)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "FailedTransferClaimed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestSlotFoundIterator is returned from FilterSlotFound and is used to iterate over the raw logs and unpacked data for SlotFound events raised by the StargateAdapterTest contract.
type StargateAdapterTestSlotFoundIterator struct {
	Event *StargateAdapterTestSlotFound // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestSlotFoundIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestSlotFound)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestSlotFound)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestSlotFoundIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestSlotFoundIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestSlotFound represents a SlotFound event raised by the StargateAdapterTest contract.
type StargateAdapterTestSlotFound struct {
	Who      common.Address
	Fsig     [4]byte
	KeysHash [32]byte
	Slot     *big.Int
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterSlotFound is a free log retrieval operation binding the contract event 0x9c9555b1e3102e3cf48f427d79cb678f5d9bd1ed0ad574389461e255f95170ed.
//
// Solidity: event SlotFound(address who, bytes4 fsig, bytes32 keysHash, uint256 slot)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterSlotFound(opts *bind.FilterOpts) (*StargateAdapterTestSlotFoundIterator, error) {

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "SlotFound")
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestSlotFoundIterator{contract: _StargateAdapterTest.contract, event: "SlotFound", logs: logs, sub: sub}, nil
}

// WatchSlotFound is a free log subscription operation binding the contract event 0x9c9555b1e3102e3cf48f427d79cb678f5d9bd1ed0ad574389461e255f95170ed.
//
// Solidity: event SlotFound(address who, bytes4 fsig, bytes32 keysHash, uint256 slot)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchSlotFound(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestSlotFound) (event.Subscription, error) {

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "SlotFound")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestSlotFound)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "SlotFound", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseSlotFound is a log parse operation binding the contract event 0x9c9555b1e3102e3cf48f427d79cb678f5d9bd1ed0ad574389461e255f95170ed.
//
// Solidity: event SlotFound(address who, bytes4 fsig, bytes32 keysHash, uint256 slot)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseSlotFound(log types.Log) (*StargateAdapterTestSlotFound, error) {
	event := new(StargateAdapterTestSlotFound)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "SlotFound", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestTransferFailedIterator is returned from FilterTransferFailed and is used to iterate over the raw logs and unpacked data for TransferFailed events raised by the StargateAdapterTest contract.
type StargateAdapterTestTransferFailedIterator struct {
	Event *StargateAdapterTestTransferFailed // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestTransferFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestTransferFailed)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestTransferFailed)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestTransferFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestTransferFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestTransferFailed represents a TransferFailed event raised by the StargateAdapterTest contract.
type StargateAdapterTestTransferFailed struct {
	Guid    [32]byte
	Account common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterTransferFailed is a free log retrieval operation binding the contract event 0xb33cfcffc3fc1f0f27f335d17c6458c39c9a09f469b404f27632271dcc4c91be.
//
// Solidity: event TransferFailed(bytes32 indexed guid, address indexed account, address indexed token, uint256 amount)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterTransferFailed(opts *bind.FilterOpts, guid [][32]byte, account []common.Address, token []common.Address) (*StargateAdapterTestTransferFailedIterator, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "TransferFailed", guidRule, accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestTransferFailedIterator{contract: _StargateAdapterTest.contract, event: "TransferFailed", logs: logs, sub: sub}, nil
}

// WatchTransferFailed is a free log subscription operation binding the contract event 0xb33cfcffc3fc1f0f27f335d17c6458c39c9a09f469b404f27632271dcc4c91be.
//
// Solidity: event TransferFailed(bytes32 indexed guid, address indexed account, address indexed token, uint256 amount)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchTransferFailed(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestTransferFailed, guid [][32]byte, account []common.Address, token []common.Address) (event.Subscription, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "TransferFailed", guidRule, accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestTransferFailed)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "TransferFailed", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseTransferFailed is a log parse operation binding the contract event 0xb33cfcffc3fc1f0f27f335d17c6458c39c9a09f469b404f27632271dcc4c91be.
//
// Solidity: event TransferFailed(bytes32 indexed guid, address indexed account, address indexed token, uint256 amount)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseTransferFailed(log types.Log) (*StargateAdapterTestTransferFailed, error) {
	event := new(StargateAdapterTestTransferFailed)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "TransferFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestTransferSucceededIterator is returned from FilterTransferSucceeded and is used to iterate over the raw logs and unpacked data for TransferSucceeded events raised by the StargateAdapterTest contract.
type StargateAdapterTestTransferSucceededIterator struct {
	Event *StargateAdapterTestTransferSucceeded // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestTransferSucceededIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestTransferSucceeded)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestTransferSucceeded)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestTransferSucceededIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestTransferSucceededIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestTransferSucceeded represents a TransferSucceeded event raised by the StargateAdapterTest contract.
type StargateAdapterTestTransferSucceeded struct {
	Guid      [32]byte
	Account   common.Address
	TokenSent common.Address
	Amount    *big.Int
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterTransferSucceeded is a free log retrieval operation binding the contract event 0x6db3031dcdf780adbc7169f24efca16f9bfef07c41ad327c22fef61a972461c4.
//
// Solidity: event TransferSucceeded(bytes32 indexed guid, address indexed account, address indexed tokenSent, uint256 amount)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterTransferSucceeded(opts *bind.FilterOpts, guid [][32]byte, account []common.Address, tokenSent []common.Address) (*StargateAdapterTestTransferSucceededIterator, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenSentRule []interface{}
	for _, tokenSentItem := range tokenSent {
		tokenSentRule = append(tokenSentRule, tokenSentItem)
	}

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "TransferSucceeded", guidRule, accountRule, tokenSentRule)
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestTransferSucceededIterator{contract: _StargateAdapterTest.contract, event: "TransferSucceeded", logs: logs, sub: sub}, nil
}

// WatchTransferSucceeded is a free log subscription operation binding the contract event 0x6db3031dcdf780adbc7169f24efca16f9bfef07c41ad327c22fef61a972461c4.
//
// Solidity: event TransferSucceeded(bytes32 indexed guid, address indexed account, address indexed tokenSent, uint256 amount)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchTransferSucceeded(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestTransferSucceeded, guid [][32]byte, account []common.Address, tokenSent []common.Address) (event.Subscription, error) {

	var guidRule []interface{}
	for _, guidItem := range guid {
		guidRule = append(guidRule, guidItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenSentRule []interface{}
	for _, tokenSentItem := range tokenSent {
		tokenSentRule = append(tokenSentRule, tokenSentItem)
	}

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "TransferSucceeded", guidRule, accountRule, tokenSentRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestTransferSucceeded)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "TransferSucceeded", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseTransferSucceeded is a log parse operation binding the contract event 0x6db3031dcdf780adbc7169f24efca16f9bfef07c41ad327c22fef61a972461c4.
//
// Solidity: event TransferSucceeded(bytes32 indexed guid, address indexed account, address indexed tokenSent, uint256 amount)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseTransferSucceeded(log types.Log) (*StargateAdapterTestTransferSucceeded, error) {
	event := new(StargateAdapterTestTransferSucceeded)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "TransferSucceeded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestWARNINGUninitedSlotIterator is returned from FilterWARNINGUninitedSlot and is used to iterate over the raw logs and unpacked data for WARNINGUninitedSlot events raised by the StargateAdapterTest contract.
type StargateAdapterTestWARNINGUninitedSlotIterator struct {
	Event *StargateAdapterTestWARNINGUninitedSlot // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestWARNINGUninitedSlotIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestWARNINGUninitedSlot)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestWARNINGUninitedSlot)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestWARNINGUninitedSlotIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestWARNINGUninitedSlotIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestWARNINGUninitedSlot represents a WARNINGUninitedSlot event raised by the StargateAdapterTest contract.
type StargateAdapterTestWARNINGUninitedSlot struct {
	Who  common.Address
	Slot *big.Int
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterWARNINGUninitedSlot is a free log retrieval operation binding the contract event 0x080fc4a96620c4462e705b23f346413fe3796bb63c6f8d8591baec0e231577a5.
//
// Solidity: event WARNING_UninitedSlot(address who, uint256 slot)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterWARNINGUninitedSlot(opts *bind.FilterOpts) (*StargateAdapterTestWARNINGUninitedSlotIterator, error) {

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "WARNING_UninitedSlot")
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestWARNINGUninitedSlotIterator{contract: _StargateAdapterTest.contract, event: "WARNING_UninitedSlot", logs: logs, sub: sub}, nil
}

// WatchWARNINGUninitedSlot is a free log subscription operation binding the contract event 0x080fc4a96620c4462e705b23f346413fe3796bb63c6f8d8591baec0e231577a5.
//
// Solidity: event WARNING_UninitedSlot(address who, uint256 slot)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchWARNINGUninitedSlot(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestWARNINGUninitedSlot) (event.Subscription, error) {

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "WARNING_UninitedSlot")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestWARNINGUninitedSlot)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "WARNING_UninitedSlot", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseWARNINGUninitedSlot is a log parse operation binding the contract event 0x080fc4a96620c4462e705b23f346413fe3796bb63c6f8d8591baec0e231577a5.
//
// Solidity: event WARNING_UninitedSlot(address who, uint256 slot)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseWARNINGUninitedSlot(log types.Log) (*StargateAdapterTestWARNINGUninitedSlot, error) {
	event := new(StargateAdapterTestWARNINGUninitedSlot)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "WARNING_UninitedSlot", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestLogIterator is returned from FilterLog and is used to iterate over the raw logs and unpacked data for Log events raised by the StargateAdapterTest contract.
type StargateAdapterTestLogIterator struct {
	Event *StargateAdapterTestLog // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestLogIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestLog)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestLog)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestLogIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestLogIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestLog represents a Log event raised by the StargateAdapterTest contract.
type StargateAdapterTestLog struct {
	Arg0 string
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterLog is a free log retrieval operation binding the contract event 0x41304facd9323d75b11bcdd609cb38effffdb05710f7caf0e9b16c6d9d709f50.
//
// Solidity: event log(string arg0)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterLog(opts *bind.FilterOpts) (*StargateAdapterTestLogIterator, error) {

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "log")
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestLogIterator{contract: _StargateAdapterTest.contract, event: "log", logs: logs, sub: sub}, nil
}

// WatchLog is a free log subscription operation binding the contract event 0x41304facd9323d75b11bcdd609cb38effffdb05710f7caf0e9b16c6d9d709f50.
//
// Solidity: event log(string arg0)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchLog(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestLog) (event.Subscription, error) {

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "log")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestLog)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "log", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLog is a log parse operation binding the contract event 0x41304facd9323d75b11bcdd609cb38effffdb05710f7caf0e9b16c6d9d709f50.
//
// Solidity: event log(string arg0)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseLog(log types.Log) (*StargateAdapterTestLog, error) {
	event := new(StargateAdapterTestLog)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "log", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestLogAddressIterator is returned from FilterLogAddress and is used to iterate over the raw logs and unpacked data for LogAddress events raised by the StargateAdapterTest contract.
type StargateAdapterTestLogAddressIterator struct {
	Event *StargateAdapterTestLogAddress // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestLogAddressIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestLogAddress)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestLogAddress)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestLogAddressIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestLogAddressIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestLogAddress represents a LogAddress event raised by the StargateAdapterTest contract.
type StargateAdapterTestLogAddress struct {
	Arg0 common.Address
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterLogAddress is a free log retrieval operation binding the contract event 0x7ae74c527414ae135fd97047b12921a5ec3911b804197855d67e25c7b75ee6f3.
//
// Solidity: event log_address(address arg0)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterLogAddress(opts *bind.FilterOpts) (*StargateAdapterTestLogAddressIterator, error) {

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "log_address")
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestLogAddressIterator{contract: _StargateAdapterTest.contract, event: "log_address", logs: logs, sub: sub}, nil
}

// WatchLogAddress is a free log subscription operation binding the contract event 0x7ae74c527414ae135fd97047b12921a5ec3911b804197855d67e25c7b75ee6f3.
//
// Solidity: event log_address(address arg0)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchLogAddress(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestLogAddress) (event.Subscription, error) {

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "log_address")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestLogAddress)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "log_address", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogAddress is a log parse operation binding the contract event 0x7ae74c527414ae135fd97047b12921a5ec3911b804197855d67e25c7b75ee6f3.
//
// Solidity: event log_address(address arg0)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseLogAddress(log types.Log) (*StargateAdapterTestLogAddress, error) {
	event := new(StargateAdapterTestLogAddress)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "log_address", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestLogArrayIterator is returned from FilterLogArray and is used to iterate over the raw logs and unpacked data for LogArray events raised by the StargateAdapterTest contract.
type StargateAdapterTestLogArrayIterator struct {
	Event *StargateAdapterTestLogArray // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestLogArrayIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestLogArray)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestLogArray)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestLogArrayIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestLogArrayIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestLogArray represents a LogArray event raised by the StargateAdapterTest contract.
type StargateAdapterTestLogArray struct {
	Val []*big.Int
	Raw types.Log // Blockchain specific contextual infos
}

// FilterLogArray is a free log retrieval operation binding the contract event 0xfb102865d50addddf69da9b5aa1bced66c80cf869a5c8d0471a467e18ce9cab1.
//
// Solidity: event log_array(uint256[] val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterLogArray(opts *bind.FilterOpts) (*StargateAdapterTestLogArrayIterator, error) {

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "log_array")
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestLogArrayIterator{contract: _StargateAdapterTest.contract, event: "log_array", logs: logs, sub: sub}, nil
}

// WatchLogArray is a free log subscription operation binding the contract event 0xfb102865d50addddf69da9b5aa1bced66c80cf869a5c8d0471a467e18ce9cab1.
//
// Solidity: event log_array(uint256[] val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchLogArray(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestLogArray) (event.Subscription, error) {

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "log_array")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestLogArray)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "log_array", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogArray is a log parse operation binding the contract event 0xfb102865d50addddf69da9b5aa1bced66c80cf869a5c8d0471a467e18ce9cab1.
//
// Solidity: event log_array(uint256[] val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseLogArray(log types.Log) (*StargateAdapterTestLogArray, error) {
	event := new(StargateAdapterTestLogArray)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "log_array", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestLogArray0Iterator is returned from FilterLogArray0 and is used to iterate over the raw logs and unpacked data for LogArray0 events raised by the StargateAdapterTest contract.
type StargateAdapterTestLogArray0Iterator struct {
	Event *StargateAdapterTestLogArray0 // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestLogArray0Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestLogArray0)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestLogArray0)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestLogArray0Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestLogArray0Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestLogArray0 represents a LogArray0 event raised by the StargateAdapterTest contract.
type StargateAdapterTestLogArray0 struct {
	Val []*big.Int
	Raw types.Log // Blockchain specific contextual infos
}

// FilterLogArray0 is a free log retrieval operation binding the contract event 0x890a82679b470f2bd82816ed9b161f97d8b967f37fa3647c21d5bf39749e2dd5.
//
// Solidity: event log_array(int256[] val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterLogArray0(opts *bind.FilterOpts) (*StargateAdapterTestLogArray0Iterator, error) {

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "log_array0")
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestLogArray0Iterator{contract: _StargateAdapterTest.contract, event: "log_array0", logs: logs, sub: sub}, nil
}

// WatchLogArray0 is a free log subscription operation binding the contract event 0x890a82679b470f2bd82816ed9b161f97d8b967f37fa3647c21d5bf39749e2dd5.
//
// Solidity: event log_array(int256[] val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchLogArray0(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestLogArray0) (event.Subscription, error) {

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "log_array0")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestLogArray0)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "log_array0", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogArray0 is a log parse operation binding the contract event 0x890a82679b470f2bd82816ed9b161f97d8b967f37fa3647c21d5bf39749e2dd5.
//
// Solidity: event log_array(int256[] val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseLogArray0(log types.Log) (*StargateAdapterTestLogArray0, error) {
	event := new(StargateAdapterTestLogArray0)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "log_array0", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestLogArray1Iterator is returned from FilterLogArray1 and is used to iterate over the raw logs and unpacked data for LogArray1 events raised by the StargateAdapterTest contract.
type StargateAdapterTestLogArray1Iterator struct {
	Event *StargateAdapterTestLogArray1 // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestLogArray1Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestLogArray1)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestLogArray1)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestLogArray1Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestLogArray1Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestLogArray1 represents a LogArray1 event raised by the StargateAdapterTest contract.
type StargateAdapterTestLogArray1 struct {
	Val []common.Address
	Raw types.Log // Blockchain specific contextual infos
}

// FilterLogArray1 is a free log retrieval operation binding the contract event 0x40e1840f5769073d61bd01372d9b75baa9842d5629a0c99ff103be1178a8e9e2.
//
// Solidity: event log_array(address[] val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterLogArray1(opts *bind.FilterOpts) (*StargateAdapterTestLogArray1Iterator, error) {

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "log_array1")
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestLogArray1Iterator{contract: _StargateAdapterTest.contract, event: "log_array1", logs: logs, sub: sub}, nil
}

// WatchLogArray1 is a free log subscription operation binding the contract event 0x40e1840f5769073d61bd01372d9b75baa9842d5629a0c99ff103be1178a8e9e2.
//
// Solidity: event log_array(address[] val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchLogArray1(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestLogArray1) (event.Subscription, error) {

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "log_array1")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestLogArray1)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "log_array1", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogArray1 is a log parse operation binding the contract event 0x40e1840f5769073d61bd01372d9b75baa9842d5629a0c99ff103be1178a8e9e2.
//
// Solidity: event log_array(address[] val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseLogArray1(log types.Log) (*StargateAdapterTestLogArray1, error) {
	event := new(StargateAdapterTestLogArray1)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "log_array1", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestLogBytesIterator is returned from FilterLogBytes and is used to iterate over the raw logs and unpacked data for LogBytes events raised by the StargateAdapterTest contract.
type StargateAdapterTestLogBytesIterator struct {
	Event *StargateAdapterTestLogBytes // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestLogBytesIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestLogBytes)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestLogBytes)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestLogBytesIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestLogBytesIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestLogBytes represents a LogBytes event raised by the StargateAdapterTest contract.
type StargateAdapterTestLogBytes struct {
	Arg0 []byte
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterLogBytes is a free log retrieval operation binding the contract event 0x23b62ad0584d24a75f0bf3560391ef5659ec6db1269c56e11aa241d637f19b20.
//
// Solidity: event log_bytes(bytes arg0)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterLogBytes(opts *bind.FilterOpts) (*StargateAdapterTestLogBytesIterator, error) {

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "log_bytes")
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestLogBytesIterator{contract: _StargateAdapterTest.contract, event: "log_bytes", logs: logs, sub: sub}, nil
}

// WatchLogBytes is a free log subscription operation binding the contract event 0x23b62ad0584d24a75f0bf3560391ef5659ec6db1269c56e11aa241d637f19b20.
//
// Solidity: event log_bytes(bytes arg0)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchLogBytes(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestLogBytes) (event.Subscription, error) {

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "log_bytes")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestLogBytes)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "log_bytes", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogBytes is a log parse operation binding the contract event 0x23b62ad0584d24a75f0bf3560391ef5659ec6db1269c56e11aa241d637f19b20.
//
// Solidity: event log_bytes(bytes arg0)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseLogBytes(log types.Log) (*StargateAdapterTestLogBytes, error) {
	event := new(StargateAdapterTestLogBytes)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "log_bytes", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestLogBytes32Iterator is returned from FilterLogBytes32 and is used to iterate over the raw logs and unpacked data for LogBytes32 events raised by the StargateAdapterTest contract.
type StargateAdapterTestLogBytes32Iterator struct {
	Event *StargateAdapterTestLogBytes32 // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestLogBytes32Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestLogBytes32)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestLogBytes32)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestLogBytes32Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestLogBytes32Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestLogBytes32 represents a LogBytes32 event raised by the StargateAdapterTest contract.
type StargateAdapterTestLogBytes32 struct {
	Arg0 [32]byte
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterLogBytes32 is a free log retrieval operation binding the contract event 0xe81699b85113eea1c73e10588b2b035e55893369632173afd43feb192fac64e3.
//
// Solidity: event log_bytes32(bytes32 arg0)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterLogBytes32(opts *bind.FilterOpts) (*StargateAdapterTestLogBytes32Iterator, error) {

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "log_bytes32")
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestLogBytes32Iterator{contract: _StargateAdapterTest.contract, event: "log_bytes32", logs: logs, sub: sub}, nil
}

// WatchLogBytes32 is a free log subscription operation binding the contract event 0xe81699b85113eea1c73e10588b2b035e55893369632173afd43feb192fac64e3.
//
// Solidity: event log_bytes32(bytes32 arg0)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchLogBytes32(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestLogBytes32) (event.Subscription, error) {

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "log_bytes32")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestLogBytes32)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "log_bytes32", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogBytes32 is a log parse operation binding the contract event 0xe81699b85113eea1c73e10588b2b035e55893369632173afd43feb192fac64e3.
//
// Solidity: event log_bytes32(bytes32 arg0)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseLogBytes32(log types.Log) (*StargateAdapterTestLogBytes32, error) {
	event := new(StargateAdapterTestLogBytes32)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "log_bytes32", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestLogIntIterator is returned from FilterLogInt and is used to iterate over the raw logs and unpacked data for LogInt events raised by the StargateAdapterTest contract.
type StargateAdapterTestLogIntIterator struct {
	Event *StargateAdapterTestLogInt // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestLogIntIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestLogInt)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestLogInt)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestLogIntIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestLogIntIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestLogInt represents a LogInt event raised by the StargateAdapterTest contract.
type StargateAdapterTestLogInt struct {
	Arg0 *big.Int
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterLogInt is a free log retrieval operation binding the contract event 0x0eb5d52624c8d28ada9fc55a8c502ed5aa3fbe2fb6e91b71b5f376882b1d2fb8.
//
// Solidity: event log_int(int256 arg0)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterLogInt(opts *bind.FilterOpts) (*StargateAdapterTestLogIntIterator, error) {

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "log_int")
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestLogIntIterator{contract: _StargateAdapterTest.contract, event: "log_int", logs: logs, sub: sub}, nil
}

// WatchLogInt is a free log subscription operation binding the contract event 0x0eb5d52624c8d28ada9fc55a8c502ed5aa3fbe2fb6e91b71b5f376882b1d2fb8.
//
// Solidity: event log_int(int256 arg0)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchLogInt(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestLogInt) (event.Subscription, error) {

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "log_int")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestLogInt)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "log_int", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogInt is a log parse operation binding the contract event 0x0eb5d52624c8d28ada9fc55a8c502ed5aa3fbe2fb6e91b71b5f376882b1d2fb8.
//
// Solidity: event log_int(int256 arg0)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseLogInt(log types.Log) (*StargateAdapterTestLogInt, error) {
	event := new(StargateAdapterTestLogInt)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "log_int", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestLogNamedAddressIterator is returned from FilterLogNamedAddress and is used to iterate over the raw logs and unpacked data for LogNamedAddress events raised by the StargateAdapterTest contract.
type StargateAdapterTestLogNamedAddressIterator struct {
	Event *StargateAdapterTestLogNamedAddress // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestLogNamedAddressIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestLogNamedAddress)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestLogNamedAddress)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestLogNamedAddressIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestLogNamedAddressIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestLogNamedAddress represents a LogNamedAddress event raised by the StargateAdapterTest contract.
type StargateAdapterTestLogNamedAddress struct {
	Key string
	Val common.Address
	Raw types.Log // Blockchain specific contextual infos
}

// FilterLogNamedAddress is a free log retrieval operation binding the contract event 0x9c4e8541ca8f0dc1c413f9108f66d82d3cecb1bddbce437a61caa3175c4cc96f.
//
// Solidity: event log_named_address(string key, address val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterLogNamedAddress(opts *bind.FilterOpts) (*StargateAdapterTestLogNamedAddressIterator, error) {

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "log_named_address")
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestLogNamedAddressIterator{contract: _StargateAdapterTest.contract, event: "log_named_address", logs: logs, sub: sub}, nil
}

// WatchLogNamedAddress is a free log subscription operation binding the contract event 0x9c4e8541ca8f0dc1c413f9108f66d82d3cecb1bddbce437a61caa3175c4cc96f.
//
// Solidity: event log_named_address(string key, address val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchLogNamedAddress(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestLogNamedAddress) (event.Subscription, error) {

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "log_named_address")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestLogNamedAddress)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "log_named_address", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogNamedAddress is a log parse operation binding the contract event 0x9c4e8541ca8f0dc1c413f9108f66d82d3cecb1bddbce437a61caa3175c4cc96f.
//
// Solidity: event log_named_address(string key, address val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseLogNamedAddress(log types.Log) (*StargateAdapterTestLogNamedAddress, error) {
	event := new(StargateAdapterTestLogNamedAddress)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "log_named_address", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestLogNamedArrayIterator is returned from FilterLogNamedArray and is used to iterate over the raw logs and unpacked data for LogNamedArray events raised by the StargateAdapterTest contract.
type StargateAdapterTestLogNamedArrayIterator struct {
	Event *StargateAdapterTestLogNamedArray // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestLogNamedArrayIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestLogNamedArray)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestLogNamedArray)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestLogNamedArrayIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestLogNamedArrayIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestLogNamedArray represents a LogNamedArray event raised by the StargateAdapterTest contract.
type StargateAdapterTestLogNamedArray struct {
	Key string
	Val []*big.Int
	Raw types.Log // Blockchain specific contextual infos
}

// FilterLogNamedArray is a free log retrieval operation binding the contract event 0x00aaa39c9ffb5f567a4534380c737075702e1f7f14107fc95328e3b56c0325fb.
//
// Solidity: event log_named_array(string key, uint256[] val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterLogNamedArray(opts *bind.FilterOpts) (*StargateAdapterTestLogNamedArrayIterator, error) {

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "log_named_array")
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestLogNamedArrayIterator{contract: _StargateAdapterTest.contract, event: "log_named_array", logs: logs, sub: sub}, nil
}

// WatchLogNamedArray is a free log subscription operation binding the contract event 0x00aaa39c9ffb5f567a4534380c737075702e1f7f14107fc95328e3b56c0325fb.
//
// Solidity: event log_named_array(string key, uint256[] val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchLogNamedArray(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestLogNamedArray) (event.Subscription, error) {

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "log_named_array")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestLogNamedArray)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "log_named_array", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogNamedArray is a log parse operation binding the contract event 0x00aaa39c9ffb5f567a4534380c737075702e1f7f14107fc95328e3b56c0325fb.
//
// Solidity: event log_named_array(string key, uint256[] val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseLogNamedArray(log types.Log) (*StargateAdapterTestLogNamedArray, error) {
	event := new(StargateAdapterTestLogNamedArray)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "log_named_array", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestLogNamedArray0Iterator is returned from FilterLogNamedArray0 and is used to iterate over the raw logs and unpacked data for LogNamedArray0 events raised by the StargateAdapterTest contract.
type StargateAdapterTestLogNamedArray0Iterator struct {
	Event *StargateAdapterTestLogNamedArray0 // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestLogNamedArray0Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestLogNamedArray0)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestLogNamedArray0)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestLogNamedArray0Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestLogNamedArray0Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestLogNamedArray0 represents a LogNamedArray0 event raised by the StargateAdapterTest contract.
type StargateAdapterTestLogNamedArray0 struct {
	Key string
	Val []*big.Int
	Raw types.Log // Blockchain specific contextual infos
}

// FilterLogNamedArray0 is a free log retrieval operation binding the contract event 0xa73eda09662f46dde729be4611385ff34fe6c44fbbc6f7e17b042b59a3445b57.
//
// Solidity: event log_named_array(string key, int256[] val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterLogNamedArray0(opts *bind.FilterOpts) (*StargateAdapterTestLogNamedArray0Iterator, error) {

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "log_named_array0")
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestLogNamedArray0Iterator{contract: _StargateAdapterTest.contract, event: "log_named_array0", logs: logs, sub: sub}, nil
}

// WatchLogNamedArray0 is a free log subscription operation binding the contract event 0xa73eda09662f46dde729be4611385ff34fe6c44fbbc6f7e17b042b59a3445b57.
//
// Solidity: event log_named_array(string key, int256[] val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchLogNamedArray0(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestLogNamedArray0) (event.Subscription, error) {

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "log_named_array0")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestLogNamedArray0)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "log_named_array0", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogNamedArray0 is a log parse operation binding the contract event 0xa73eda09662f46dde729be4611385ff34fe6c44fbbc6f7e17b042b59a3445b57.
//
// Solidity: event log_named_array(string key, int256[] val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseLogNamedArray0(log types.Log) (*StargateAdapterTestLogNamedArray0, error) {
	event := new(StargateAdapterTestLogNamedArray0)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "log_named_array0", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestLogNamedArray1Iterator is returned from FilterLogNamedArray1 and is used to iterate over the raw logs and unpacked data for LogNamedArray1 events raised by the StargateAdapterTest contract.
type StargateAdapterTestLogNamedArray1Iterator struct {
	Event *StargateAdapterTestLogNamedArray1 // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestLogNamedArray1Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestLogNamedArray1)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestLogNamedArray1)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestLogNamedArray1Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestLogNamedArray1Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestLogNamedArray1 represents a LogNamedArray1 event raised by the StargateAdapterTest contract.
type StargateAdapterTestLogNamedArray1 struct {
	Key string
	Val []common.Address
	Raw types.Log // Blockchain specific contextual infos
}

// FilterLogNamedArray1 is a free log retrieval operation binding the contract event 0x3bcfb2ae2e8d132dd1fce7cf278a9a19756a9fceabe470df3bdabb4bc577d1bd.
//
// Solidity: event log_named_array(string key, address[] val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterLogNamedArray1(opts *bind.FilterOpts) (*StargateAdapterTestLogNamedArray1Iterator, error) {

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "log_named_array1")
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestLogNamedArray1Iterator{contract: _StargateAdapterTest.contract, event: "log_named_array1", logs: logs, sub: sub}, nil
}

// WatchLogNamedArray1 is a free log subscription operation binding the contract event 0x3bcfb2ae2e8d132dd1fce7cf278a9a19756a9fceabe470df3bdabb4bc577d1bd.
//
// Solidity: event log_named_array(string key, address[] val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchLogNamedArray1(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestLogNamedArray1) (event.Subscription, error) {

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "log_named_array1")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestLogNamedArray1)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "log_named_array1", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogNamedArray1 is a log parse operation binding the contract event 0x3bcfb2ae2e8d132dd1fce7cf278a9a19756a9fceabe470df3bdabb4bc577d1bd.
//
// Solidity: event log_named_array(string key, address[] val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseLogNamedArray1(log types.Log) (*StargateAdapterTestLogNamedArray1, error) {
	event := new(StargateAdapterTestLogNamedArray1)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "log_named_array1", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestLogNamedBytesIterator is returned from FilterLogNamedBytes and is used to iterate over the raw logs and unpacked data for LogNamedBytes events raised by the StargateAdapterTest contract.
type StargateAdapterTestLogNamedBytesIterator struct {
	Event *StargateAdapterTestLogNamedBytes // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestLogNamedBytesIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestLogNamedBytes)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestLogNamedBytes)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestLogNamedBytesIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestLogNamedBytesIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestLogNamedBytes represents a LogNamedBytes event raised by the StargateAdapterTest contract.
type StargateAdapterTestLogNamedBytes struct {
	Key string
	Val []byte
	Raw types.Log // Blockchain specific contextual infos
}

// FilterLogNamedBytes is a free log retrieval operation binding the contract event 0xd26e16cad4548705e4c9e2d94f98ee91c289085ee425594fd5635fa2964ccf18.
//
// Solidity: event log_named_bytes(string key, bytes val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterLogNamedBytes(opts *bind.FilterOpts) (*StargateAdapterTestLogNamedBytesIterator, error) {

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "log_named_bytes")
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestLogNamedBytesIterator{contract: _StargateAdapterTest.contract, event: "log_named_bytes", logs: logs, sub: sub}, nil
}

// WatchLogNamedBytes is a free log subscription operation binding the contract event 0xd26e16cad4548705e4c9e2d94f98ee91c289085ee425594fd5635fa2964ccf18.
//
// Solidity: event log_named_bytes(string key, bytes val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchLogNamedBytes(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestLogNamedBytes) (event.Subscription, error) {

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "log_named_bytes")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestLogNamedBytes)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "log_named_bytes", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogNamedBytes is a log parse operation binding the contract event 0xd26e16cad4548705e4c9e2d94f98ee91c289085ee425594fd5635fa2964ccf18.
//
// Solidity: event log_named_bytes(string key, bytes val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseLogNamedBytes(log types.Log) (*StargateAdapterTestLogNamedBytes, error) {
	event := new(StargateAdapterTestLogNamedBytes)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "log_named_bytes", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestLogNamedBytes32Iterator is returned from FilterLogNamedBytes32 and is used to iterate over the raw logs and unpacked data for LogNamedBytes32 events raised by the StargateAdapterTest contract.
type StargateAdapterTestLogNamedBytes32Iterator struct {
	Event *StargateAdapterTestLogNamedBytes32 // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestLogNamedBytes32Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestLogNamedBytes32)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestLogNamedBytes32)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestLogNamedBytes32Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestLogNamedBytes32Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestLogNamedBytes32 represents a LogNamedBytes32 event raised by the StargateAdapterTest contract.
type StargateAdapterTestLogNamedBytes32 struct {
	Key string
	Val [32]byte
	Raw types.Log // Blockchain specific contextual infos
}

// FilterLogNamedBytes32 is a free log retrieval operation binding the contract event 0xafb795c9c61e4fe7468c386f925d7a5429ecad9c0495ddb8d38d690614d32f99.
//
// Solidity: event log_named_bytes32(string key, bytes32 val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterLogNamedBytes32(opts *bind.FilterOpts) (*StargateAdapterTestLogNamedBytes32Iterator, error) {

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "log_named_bytes32")
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestLogNamedBytes32Iterator{contract: _StargateAdapterTest.contract, event: "log_named_bytes32", logs: logs, sub: sub}, nil
}

// WatchLogNamedBytes32 is a free log subscription operation binding the contract event 0xafb795c9c61e4fe7468c386f925d7a5429ecad9c0495ddb8d38d690614d32f99.
//
// Solidity: event log_named_bytes32(string key, bytes32 val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchLogNamedBytes32(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestLogNamedBytes32) (event.Subscription, error) {

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "log_named_bytes32")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestLogNamedBytes32)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "log_named_bytes32", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogNamedBytes32 is a log parse operation binding the contract event 0xafb795c9c61e4fe7468c386f925d7a5429ecad9c0495ddb8d38d690614d32f99.
//
// Solidity: event log_named_bytes32(string key, bytes32 val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseLogNamedBytes32(log types.Log) (*StargateAdapterTestLogNamedBytes32, error) {
	event := new(StargateAdapterTestLogNamedBytes32)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "log_named_bytes32", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestLogNamedDecimalIntIterator is returned from FilterLogNamedDecimalInt and is used to iterate over the raw logs and unpacked data for LogNamedDecimalInt events raised by the StargateAdapterTest contract.
type StargateAdapterTestLogNamedDecimalIntIterator struct {
	Event *StargateAdapterTestLogNamedDecimalInt // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestLogNamedDecimalIntIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestLogNamedDecimalInt)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestLogNamedDecimalInt)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestLogNamedDecimalIntIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestLogNamedDecimalIntIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestLogNamedDecimalInt represents a LogNamedDecimalInt event raised by the StargateAdapterTest contract.
type StargateAdapterTestLogNamedDecimalInt struct {
	Key      string
	Val      *big.Int
	Decimals *big.Int
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterLogNamedDecimalInt is a free log retrieval operation binding the contract event 0x5da6ce9d51151ba10c09a559ef24d520b9dac5c5b8810ae8434e4d0d86411a95.
//
// Solidity: event log_named_decimal_int(string key, int256 val, uint256 decimals)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterLogNamedDecimalInt(opts *bind.FilterOpts) (*StargateAdapterTestLogNamedDecimalIntIterator, error) {

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "log_named_decimal_int")
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestLogNamedDecimalIntIterator{contract: _StargateAdapterTest.contract, event: "log_named_decimal_int", logs: logs, sub: sub}, nil
}

// WatchLogNamedDecimalInt is a free log subscription operation binding the contract event 0x5da6ce9d51151ba10c09a559ef24d520b9dac5c5b8810ae8434e4d0d86411a95.
//
// Solidity: event log_named_decimal_int(string key, int256 val, uint256 decimals)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchLogNamedDecimalInt(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestLogNamedDecimalInt) (event.Subscription, error) {

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "log_named_decimal_int")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestLogNamedDecimalInt)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "log_named_decimal_int", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogNamedDecimalInt is a log parse operation binding the contract event 0x5da6ce9d51151ba10c09a559ef24d520b9dac5c5b8810ae8434e4d0d86411a95.
//
// Solidity: event log_named_decimal_int(string key, int256 val, uint256 decimals)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseLogNamedDecimalInt(log types.Log) (*StargateAdapterTestLogNamedDecimalInt, error) {
	event := new(StargateAdapterTestLogNamedDecimalInt)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "log_named_decimal_int", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestLogNamedDecimalUintIterator is returned from FilterLogNamedDecimalUint and is used to iterate over the raw logs and unpacked data for LogNamedDecimalUint events raised by the StargateAdapterTest contract.
type StargateAdapterTestLogNamedDecimalUintIterator struct {
	Event *StargateAdapterTestLogNamedDecimalUint // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestLogNamedDecimalUintIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestLogNamedDecimalUint)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestLogNamedDecimalUint)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestLogNamedDecimalUintIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestLogNamedDecimalUintIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestLogNamedDecimalUint represents a LogNamedDecimalUint event raised by the StargateAdapterTest contract.
type StargateAdapterTestLogNamedDecimalUint struct {
	Key      string
	Val      *big.Int
	Decimals *big.Int
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterLogNamedDecimalUint is a free log retrieval operation binding the contract event 0xeb8ba43ced7537421946bd43e828b8b2b8428927aa8f801c13d934bf11aca57b.
//
// Solidity: event log_named_decimal_uint(string key, uint256 val, uint256 decimals)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterLogNamedDecimalUint(opts *bind.FilterOpts) (*StargateAdapterTestLogNamedDecimalUintIterator, error) {

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "log_named_decimal_uint")
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestLogNamedDecimalUintIterator{contract: _StargateAdapterTest.contract, event: "log_named_decimal_uint", logs: logs, sub: sub}, nil
}

// WatchLogNamedDecimalUint is a free log subscription operation binding the contract event 0xeb8ba43ced7537421946bd43e828b8b2b8428927aa8f801c13d934bf11aca57b.
//
// Solidity: event log_named_decimal_uint(string key, uint256 val, uint256 decimals)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchLogNamedDecimalUint(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestLogNamedDecimalUint) (event.Subscription, error) {

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "log_named_decimal_uint")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestLogNamedDecimalUint)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "log_named_decimal_uint", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogNamedDecimalUint is a log parse operation binding the contract event 0xeb8ba43ced7537421946bd43e828b8b2b8428927aa8f801c13d934bf11aca57b.
//
// Solidity: event log_named_decimal_uint(string key, uint256 val, uint256 decimals)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseLogNamedDecimalUint(log types.Log) (*StargateAdapterTestLogNamedDecimalUint, error) {
	event := new(StargateAdapterTestLogNamedDecimalUint)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "log_named_decimal_uint", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestLogNamedIntIterator is returned from FilterLogNamedInt and is used to iterate over the raw logs and unpacked data for LogNamedInt events raised by the StargateAdapterTest contract.
type StargateAdapterTestLogNamedIntIterator struct {
	Event *StargateAdapterTestLogNamedInt // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestLogNamedIntIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestLogNamedInt)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestLogNamedInt)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestLogNamedIntIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestLogNamedIntIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestLogNamedInt represents a LogNamedInt event raised by the StargateAdapterTest contract.
type StargateAdapterTestLogNamedInt struct {
	Key string
	Val *big.Int
	Raw types.Log // Blockchain specific contextual infos
}

// FilterLogNamedInt is a free log retrieval operation binding the contract event 0x2fe632779174374378442a8e978bccfbdcc1d6b2b0d81f7e8eb776ab2286f168.
//
// Solidity: event log_named_int(string key, int256 val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterLogNamedInt(opts *bind.FilterOpts) (*StargateAdapterTestLogNamedIntIterator, error) {

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "log_named_int")
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestLogNamedIntIterator{contract: _StargateAdapterTest.contract, event: "log_named_int", logs: logs, sub: sub}, nil
}

// WatchLogNamedInt is a free log subscription operation binding the contract event 0x2fe632779174374378442a8e978bccfbdcc1d6b2b0d81f7e8eb776ab2286f168.
//
// Solidity: event log_named_int(string key, int256 val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchLogNamedInt(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestLogNamedInt) (event.Subscription, error) {

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "log_named_int")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestLogNamedInt)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "log_named_int", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogNamedInt is a log parse operation binding the contract event 0x2fe632779174374378442a8e978bccfbdcc1d6b2b0d81f7e8eb776ab2286f168.
//
// Solidity: event log_named_int(string key, int256 val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseLogNamedInt(log types.Log) (*StargateAdapterTestLogNamedInt, error) {
	event := new(StargateAdapterTestLogNamedInt)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "log_named_int", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestLogNamedStringIterator is returned from FilterLogNamedString and is used to iterate over the raw logs and unpacked data for LogNamedString events raised by the StargateAdapterTest contract.
type StargateAdapterTestLogNamedStringIterator struct {
	Event *StargateAdapterTestLogNamedString // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestLogNamedStringIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestLogNamedString)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestLogNamedString)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestLogNamedStringIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestLogNamedStringIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestLogNamedString represents a LogNamedString event raised by the StargateAdapterTest contract.
type StargateAdapterTestLogNamedString struct {
	Key string
	Val string
	Raw types.Log // Blockchain specific contextual infos
}

// FilterLogNamedString is a free log retrieval operation binding the contract event 0x280f4446b28a1372417dda658d30b95b2992b12ac9c7f378535f29a97acf3583.
//
// Solidity: event log_named_string(string key, string val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterLogNamedString(opts *bind.FilterOpts) (*StargateAdapterTestLogNamedStringIterator, error) {

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "log_named_string")
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestLogNamedStringIterator{contract: _StargateAdapterTest.contract, event: "log_named_string", logs: logs, sub: sub}, nil
}

// WatchLogNamedString is a free log subscription operation binding the contract event 0x280f4446b28a1372417dda658d30b95b2992b12ac9c7f378535f29a97acf3583.
//
// Solidity: event log_named_string(string key, string val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchLogNamedString(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestLogNamedString) (event.Subscription, error) {

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "log_named_string")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestLogNamedString)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "log_named_string", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogNamedString is a log parse operation binding the contract event 0x280f4446b28a1372417dda658d30b95b2992b12ac9c7f378535f29a97acf3583.
//
// Solidity: event log_named_string(string key, string val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseLogNamedString(log types.Log) (*StargateAdapterTestLogNamedString, error) {
	event := new(StargateAdapterTestLogNamedString)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "log_named_string", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestLogNamedUintIterator is returned from FilterLogNamedUint and is used to iterate over the raw logs and unpacked data for LogNamedUint events raised by the StargateAdapterTest contract.
type StargateAdapterTestLogNamedUintIterator struct {
	Event *StargateAdapterTestLogNamedUint // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestLogNamedUintIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestLogNamedUint)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestLogNamedUint)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestLogNamedUintIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestLogNamedUintIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestLogNamedUint represents a LogNamedUint event raised by the StargateAdapterTest contract.
type StargateAdapterTestLogNamedUint struct {
	Key string
	Val *big.Int
	Raw types.Log // Blockchain specific contextual infos
}

// FilterLogNamedUint is a free log retrieval operation binding the contract event 0xb2de2fbe801a0df6c0cbddfd448ba3c41d48a040ca35c56c8196ef0fcae721a8.
//
// Solidity: event log_named_uint(string key, uint256 val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterLogNamedUint(opts *bind.FilterOpts) (*StargateAdapterTestLogNamedUintIterator, error) {

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "log_named_uint")
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestLogNamedUintIterator{contract: _StargateAdapterTest.contract, event: "log_named_uint", logs: logs, sub: sub}, nil
}

// WatchLogNamedUint is a free log subscription operation binding the contract event 0xb2de2fbe801a0df6c0cbddfd448ba3c41d48a040ca35c56c8196ef0fcae721a8.
//
// Solidity: event log_named_uint(string key, uint256 val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchLogNamedUint(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestLogNamedUint) (event.Subscription, error) {

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "log_named_uint")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestLogNamedUint)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "log_named_uint", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogNamedUint is a log parse operation binding the contract event 0xb2de2fbe801a0df6c0cbddfd448ba3c41d48a040ca35c56c8196ef0fcae721a8.
//
// Solidity: event log_named_uint(string key, uint256 val)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseLogNamedUint(log types.Log) (*StargateAdapterTestLogNamedUint, error) {
	event := new(StargateAdapterTestLogNamedUint)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "log_named_uint", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestLogStringIterator is returned from FilterLogString and is used to iterate over the raw logs and unpacked data for LogString events raised by the StargateAdapterTest contract.
type StargateAdapterTestLogStringIterator struct {
	Event *StargateAdapterTestLogString // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestLogStringIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestLogString)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestLogString)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestLogStringIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestLogStringIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestLogString represents a LogString event raised by the StargateAdapterTest contract.
type StargateAdapterTestLogString struct {
	Arg0 string
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterLogString is a free log retrieval operation binding the contract event 0x0b2e13ff20ac7b474198655583edf70dedd2c1dc980e329c4fbb2fc0748b796b.
//
// Solidity: event log_string(string arg0)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterLogString(opts *bind.FilterOpts) (*StargateAdapterTestLogStringIterator, error) {

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "log_string")
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestLogStringIterator{contract: _StargateAdapterTest.contract, event: "log_string", logs: logs, sub: sub}, nil
}

// WatchLogString is a free log subscription operation binding the contract event 0x0b2e13ff20ac7b474198655583edf70dedd2c1dc980e329c4fbb2fc0748b796b.
//
// Solidity: event log_string(string arg0)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchLogString(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestLogString) (event.Subscription, error) {

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "log_string")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestLogString)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "log_string", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogString is a log parse operation binding the contract event 0x0b2e13ff20ac7b474198655583edf70dedd2c1dc980e329c4fbb2fc0748b796b.
//
// Solidity: event log_string(string arg0)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseLogString(log types.Log) (*StargateAdapterTestLogString, error) {
	event := new(StargateAdapterTestLogString)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "log_string", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestLogUintIterator is returned from FilterLogUint and is used to iterate over the raw logs and unpacked data for LogUint events raised by the StargateAdapterTest contract.
type StargateAdapterTestLogUintIterator struct {
	Event *StargateAdapterTestLogUint // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestLogUintIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestLogUint)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestLogUint)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestLogUintIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestLogUintIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestLogUint represents a LogUint event raised by the StargateAdapterTest contract.
type StargateAdapterTestLogUint struct {
	Arg0 *big.Int
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterLogUint is a free log retrieval operation binding the contract event 0x2cab9790510fd8bdfbd2115288db33fec66691d476efc5427cfd4c0969301755.
//
// Solidity: event log_uint(uint256 arg0)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterLogUint(opts *bind.FilterOpts) (*StargateAdapterTestLogUintIterator, error) {

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "log_uint")
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestLogUintIterator{contract: _StargateAdapterTest.contract, event: "log_uint", logs: logs, sub: sub}, nil
}

// WatchLogUint is a free log subscription operation binding the contract event 0x2cab9790510fd8bdfbd2115288db33fec66691d476efc5427cfd4c0969301755.
//
// Solidity: event log_uint(uint256 arg0)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchLogUint(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestLogUint) (event.Subscription, error) {

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "log_uint")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestLogUint)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "log_uint", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogUint is a log parse operation binding the contract event 0x2cab9790510fd8bdfbd2115288db33fec66691d476efc5427cfd4c0969301755.
//
// Solidity: event log_uint(uint256 arg0)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseLogUint(log types.Log) (*StargateAdapterTestLogUint, error) {
	event := new(StargateAdapterTestLogUint)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "log_uint", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// StargateAdapterTestLogsIterator is returned from FilterLogs and is used to iterate over the raw logs and unpacked data for Logs events raised by the StargateAdapterTest contract.
type StargateAdapterTestLogsIterator struct {
	Event *StargateAdapterTestLogs // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *StargateAdapterTestLogsIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(StargateAdapterTestLogs)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(StargateAdapterTestLogs)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *StargateAdapterTestLogsIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *StargateAdapterTestLogsIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// StargateAdapterTestLogs represents a Logs event raised by the StargateAdapterTest contract.
type StargateAdapterTestLogs struct {
	Arg0 []byte
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterLogs is a free log retrieval operation binding the contract event 0xe7950ede0394b9f2ce4a5a1bf5a7e1852411f7e6661b4308c913c4bfd11027e4.
//
// Solidity: event logs(bytes arg0)
func (_StargateAdapterTest *StargateAdapterTestFilterer) FilterLogs(opts *bind.FilterOpts) (*StargateAdapterTestLogsIterator, error) {

	logs, sub, err := _StargateAdapterTest.contract.FilterLogs(opts, "logs")
	if err != nil {
		return nil, err
	}
	return &StargateAdapterTestLogsIterator{contract: _StargateAdapterTest.contract, event: "logs", logs: logs, sub: sub}, nil
}

// WatchLogs is a free log subscription operation binding the contract event 0xe7950ede0394b9f2ce4a5a1bf5a7e1852411f7e6661b4308c913c4bfd11027e4.
//
// Solidity: event logs(bytes arg0)
func (_StargateAdapterTest *StargateAdapterTestFilterer) WatchLogs(opts *bind.WatchOpts, sink chan<- *StargateAdapterTestLogs) (event.Subscription, error) {

	logs, sub, err := _StargateAdapterTest.contract.WatchLogs(opts, "logs")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(StargateAdapterTestLogs)
				if err := _StargateAdapterTest.contract.UnpackLog(event, "logs", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogs is a log parse operation binding the contract event 0xe7950ede0394b9f2ce4a5a1bf5a7e1852411f7e6661b4308c913c4bfd11027e4.
//
// Solidity: event logs(bytes arg0)
func (_StargateAdapterTest *StargateAdapterTestFilterer) ParseLogs(log types.Log) (*StargateAdapterTestLogs, error) {
	event := new(StargateAdapterTestLogs)
	if err := _StargateAdapterTest.contract.UnpackLog(event, "logs", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
